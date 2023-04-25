import Foundation
import UIKit
import Display
import ComponentFlow
import ViewControllerComponent
import AccountContext
import SwiftSignalKit
import AppBundle
import MessageInputPanelComponent
import ShareController
import TelegramCore
import UndoUI
import AttachmentUI
import TelegramUIPreferences
import MediaPickerUI
import LegacyMediaPickerUI
import LocationUI
import ChatEntityKeyboardInputNode
import WebUI
import ChatScheduleTimeController
import TextFormat
import PhoneNumberFormat
import ComposePollUI
import TelegramIntents
import LegacyUI
import WebSearchUI
import ChatTimerScreen
import PremiumUI
import ICloudResources
import LegacyComponents
import LegacyCamera
import StoryFooterPanelComponent

private func hasFirstResponder(_ view: UIView) -> Bool {
    if view.isFirstResponder {
        return true
    }
    for subview in view.subviews {
        if hasFirstResponder(subview) {
            return true
        }
    }
    return false
}

private final class StoryContainerScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let initialContent: StoryContentItemSlice
    
    init(
        context: AccountContext,
        initialContent: StoryContentItemSlice
    ) {
        self.context = context
        self.initialContent = initialContent
    }
    
    static func ==(lhs: StoryContainerScreenComponent, rhs: StoryContainerScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.initialContent !== rhs.initialContent {
            return false
        }
        return true
    }
    
    private final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
        
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    private struct ItemLayout {
        var size: CGSize
        
        init(size: CGSize) {
            self.size = size
        }
    }
    
    private final class VisibleItem {
        let externalState = StoryContentItem.ExternalState()
        let view = ComponentView<StoryContentItem.Environment>()
        var currentProgress: Double = 0.0
        var requestedNext: Bool = false
        
        init() {
        }
    }
    
    private final class InfoItem {
        let component: AnyComponent<Empty>
        let view = ComponentView<Empty>()
        
        init(component: AnyComponent<Empty>) {
            self.component = component
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let scrollView: ScrollView
        
        private let contentContainerView: UIView
        private let topContentGradientLayer: SimpleGradientLayer
        private let bottomContentGradientLayer: SimpleGradientLayer
        private let contentDimLayer: SimpleLayer
        
        private let closeButton: HighlightableButton
        private let closeButtonIconView: UIImageView
        
        private let navigationStrip = ComponentView<MediaNavigationStripComponent.EnvironmentType>()
        private let inlineActions = ComponentView<Empty>()
        
        private var centerInfoItem: InfoItem?
        private var rightInfoItem: InfoItem?
        
        private let inputPanel = ComponentView<Empty>()
        private let footerPanel = ComponentView<Empty>()
        private let inputPanelExternalState = MessageInputPanelComponent.ExternalState()
        
        private weak var attachmentController: AttachmentController?
        private let controllerNavigationDisposable = MetaDisposable()
        private let enqueueMediaMessageDisposable = MetaDisposable()
        
        private var component: StoryContainerScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?
        
        private var itemLayout: ItemLayout?
        private var ignoreScrolling: Bool = false
        
        private var focusedItemId: AnyHashable?
        private var currentSlice: StoryContentItemSlice?
        private var currentSliceDisposable: Disposable?
        
        private var visibleItems: [AnyHashable: VisibleItem] = [:]
        
        private var preloadContexts: [AnyHashable: Disposable] = [:]
        
        override init(frame: CGRect) {
            self.scrollView = ScrollView()
            
            self.contentContainerView = UIView()
            self.contentContainerView.clipsToBounds = true
            self.contentContainerView.isUserInteractionEnabled = false
            
            self.topContentGradientLayer = SimpleGradientLayer()
            self.bottomContentGradientLayer = SimpleGradientLayer()
            self.contentDimLayer = SimpleLayer()
            
            self.closeButton = HighlightableButton()
            self.closeButtonIconView = UIImageView()
            
            super.init(frame: frame)
            
            self.backgroundColor = .black
            
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.clipsToBounds = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.alwaysBounceVertical = true
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = true
            
            self.addSubview(self.contentContainerView)
            self.layer.addSublayer(self.contentDimLayer)
            self.layer.addSublayer(self.topContentGradientLayer)
            self.layer.addSublayer(self.bottomContentGradientLayer)
            
            self.closeButton.addSubview(self.closeButtonIconView)
            self.addSubview(self.closeButton)
            self.closeButton.addTarget(self, action: #selector(self.closePressed), for: .touchUpInside)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.currentSliceDisposable?.dispose()
            self.controllerNavigationDisposable.dispose()
            self.enqueueMediaMessageDisposable.dispose()
        }
        
        @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state, let currentSlice = self.currentSlice, let focusedItemId = self.focusedItemId, let currentIndex = currentSlice.items.firstIndex(where: { $0.id == focusedItemId }), let itemLayout = self.itemLayout {
                if hasFirstResponder(self) {
                    self.endEditing(true)
                } else {
                    let point = recognizer.location(in: self)
                    
                    var nextIndex: Int
                    if point.x < itemLayout.size.width * 0.5 {
                        nextIndex = currentIndex + 1
                    } else {
                        nextIndex = currentIndex - 1
                    }
                    nextIndex = max(0, min(nextIndex, currentSlice.items.count - 1))
                    if nextIndex != currentIndex {
                        let focusedItemId = currentSlice.items[nextIndex].id
                        self.focusedItemId = focusedItemId
                        self.state?.updated(transition: .immediate)
                        
                        self.currentSliceDisposable?.dispose()
                        self.currentSliceDisposable = (currentSlice.update(
                            currentSlice,
                            focusedItemId
                        )
                        |> deliverOnMainQueue).start(next: { [weak self] contentSlice in
                            guard let self else {
                                return
                            }
                            self.currentSlice = contentSlice
                            self.state?.updated(transition: .immediate)
                        })
                    }
                }
            }
        }
        
        @objc private func closePressed() {
            guard let environment = self.environment, let controller = environment.controller() else {
                return
            }
            controller.dismiss()
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
        
        private func updateScrolling(transition: Transition) {
            guard let itemLayout = self.itemLayout else {
                return
            }
            
            var validIds: [AnyHashable] = []
            if let focusedItemId = self.focusedItemId, let focusedItem = self.currentSlice?.items.first(where: { $0.id == focusedItemId }) {
                validIds.append(focusedItemId)
                
                var itemTransition = transition
                let visibleItem: VisibleItem
                if let current = self.visibleItems[focusedItemId] {
                    visibleItem = current
                } else {
                    itemTransition = .immediate
                    visibleItem = VisibleItem()
                    self.visibleItems[focusedItemId] = visibleItem
                }
                
                let _ = visibleItem.view.update(
                    transition: itemTransition,
                    component: focusedItem.component,
                    environment: {
                        StoryContentItem.Environment(
                            externalState: visibleItem.externalState,
                            presentationProgressUpdated: { [weak self, weak visibleItem] progress in
                                guard let self = self else {
                                    return
                                }
                                guard let visibleItem else {
                                    return
                                }
                                visibleItem.currentProgress = progress
                                
                                if let navigationStripView = self.navigationStrip.view as? MediaNavigationStripComponent.View {
                                    navigationStripView.updateCurrentItemProgress(value: progress, transition: .immediate)
                                }
                                if progress >= 1.0 && !visibleItem.requestedNext {
                                    visibleItem.requestedNext = true
                                    
                                    if let currentSlice = self.currentSlice, let focusedItemId = self.focusedItemId, let currentIndex = currentSlice.items.firstIndex(where: { $0.id == focusedItemId }) {
                                        var nextIndex = currentIndex - 1
                                        nextIndex = max(0, min(nextIndex, currentSlice.items.count - 1))
                                        if nextIndex != currentIndex {
                                            let focusedItemId = currentSlice.items[nextIndex].id
                                            self.focusedItemId = focusedItemId
                                            self.state?.updated(transition: .immediate)
                                            
                                            self.currentSliceDisposable?.dispose()
                                            self.currentSliceDisposable = (currentSlice.update(
                                                currentSlice,
                                                focusedItemId
                                            )
                                            |> deliverOnMainQueue).start(next: { [weak self] contentSlice in
                                                guard let self else {
                                                    return
                                                }
                                                self.currentSlice = contentSlice
                                                self.state?.updated(transition: .immediate)
                                            })
                                        } else {
                                            self.environment?.controller()?.dismiss()
                                        }
                                    }
                                }
                            }
                        )
                    },
                    containerSize: itemLayout.size
                )
                if let view = visibleItem.view.view {
                    if view.superview == nil {
                        self.contentContainerView.addSubview(view)
                    }
                    itemTransition.setFrame(view: view, frame: CGRect(origin: CGPoint(), size: itemLayout.size))
                }
            }
            
            var removeIds: [AnyHashable] = []
            for (id, visibleItem) in self.visibleItems {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    if let view = visibleItem.view.view {
                        view.removeFromSuperview()
                    }
                }
            }
            for id in removeIds {
                self.visibleItems.removeValue(forKey: id)
            }
        }
        
        func animateIn() {
            self.layer.allowsGroupOpacity = true
            self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, completion: { [weak self] _ in
                guard let self else {
                    return
                }
                self.layer.allowsGroupOpacity = false
            })
        }
        
        func animateOut(completion: @escaping () -> Void) {
            self.layer.allowsGroupOpacity = true
            self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                completion()
            })
        }
        
        private func performSendMessageAction() {
            guard let component = self.component else {
                return
            }
            guard let focusedItemId = self.focusedItemId, let focusedItem = self.currentSlice?.items.first(where: { $0.id == focusedItemId }) else {
                return
            }
            guard let targetMessageId = focusedItem.targetMessageId else {
                return
            }
            guard let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View else {
                return
            }
            
            switch inputPanelView.getSendMessageInput() {
            case let .text(text):
                if !text.isEmpty {
                    component.context.engine.messages.enqueueOutgoingMessage(
                        to: targetMessageId.peerId,
                        replyTo: targetMessageId,
                        content: .text(text)
                    )
                    inputPanelView.clearSendMessageInput()
                    
                    if let controller = self.environment?.controller() {
                        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                        controller.present(UndoOverlayController(
                            presentationData: presentationData,
                            content: .succeed(text: "Message Sent"),
                            elevatedLayout: false,
                            animateInAsReplacement: false,
                            action: { _ in return false }
                        ), in: .current)
                    }
                }
            }
        }
        
        private func performInlineAction(item: StoryActionsComponent.Item) {
            guard let component = self.component else {
                return
            }
            guard let focusedItemId = self.focusedItemId, let focusedItem = self.currentSlice?.items.first(where: { $0.id == focusedItemId }) else {
                return
            }
            guard let targetMessageId = focusedItem.targetMessageId else {
                return
            }
            
            switch item.kind {
            case .like:
                if item.isActivated {
                    component.context.engine.messages.setMessageReactions(
                        id: targetMessageId,
                        reactions: [
                        ]
                    )
                } else {
                    component.context.engine.messages.setMessageReactions(
                        id: targetMessageId,
                        reactions: [
                            .builtin("❤")
                        ]
                    )
                }
            case .share:
                let _ = (component.context.engine.data.get(
                    TelegramEngine.EngineData.Item.Messages.Message(id: targetMessageId)
                )
                |> deliverOnMainQueue).start(next: { [weak self] message in
                    guard let self, let message, let component = self.component, let controller = self.environment?.controller() else {
                        return
                    }
                    let shareController = ShareController(
                        context: component.context,
                        subject: .messages([message._asMessage()]),
                        externalShare: false,
                        immediateExternalShare: false,
                        updatedPresentationData: (component.context.sharedContext.currentPresentationData.with({ $0 }),
                        component.context.sharedContext.presentationData)
                    )
                    controller.present(shareController, in: .window(.root))
                })
            }
        }
        
        private func clearInputText() {
            guard let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View else {
                return
            }
            inputPanelView.clearSendMessageInput()
        }
        
        private enum AttachMenuSubject {
            case `default`
        }
        
        private func presentAttachmentMenu(subject: AttachMenuSubject) {
            guard let component = self.component else {
                return
            }
            guard let focusedItemId = self.focusedItemId, let focusedItem = self.currentSlice?.items.first(where: { $0.id == focusedItemId }) else {
                return
            }
            guard let targetMessageId = focusedItem.targetMessageId else {
                return
            }
            guard let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View else {
                return
            }
            
            var inputText = NSAttributedString(string: "")
            switch inputPanelView.getSendMessageInput() {
            case let .text(text):
                inputText = NSAttributedString(string: text)
            }
            
            let _ = (component.context.engine.data.get(
                TelegramEngine.EngineData.Item.Messages.Message(id: targetMessageId)
            )
            |> deliverOnMainQueue).start(next: { [weak self] targetMessage in
                guard let self, let component = self.component else {
                    return
                }
                guard let targetMessage, let peer = targetMessage.author else {
                    return
                }
                
                let inputIsActive = !"".isEmpty
                
                self.endEditing(true)
                        
                var banSendText: (Int32, Bool)?
                var bannedSendPhotos: (Int32, Bool)?
                var bannedSendVideos: (Int32, Bool)?
                var bannedSendFiles: (Int32, Bool)?
                
                let _ = bannedSendFiles
                
                var canSendPolls = true
                if case let .user(peer) = peer, peer.botInfo == nil {
                    canSendPolls = false
                } else if case .secretChat = peer {
                    canSendPolls = false
                } else if case let .channel(channel) = peer {
                    if let value = channel.hasBannedPermission(.banSendPhotos) {
                        bannedSendPhotos = value
                    }
                    if let value = channel.hasBannedPermission(.banSendVideos) {
                        bannedSendVideos = value
                    }
                    if let value = channel.hasBannedPermission(.banSendFiles) {
                        bannedSendFiles = value
                    }
                    if let value = channel.hasBannedPermission(.banSendText) {
                        banSendText = value
                    }
                    if channel.hasBannedPermission(.banSendPolls) != nil {
                        canSendPolls = false
                    }
                } else if case let .legacyGroup(group) = peer {
                    if group.hasBannedPermission(.banSendPhotos) {
                        bannedSendPhotos = (Int32.max, false)
                    }
                    if group.hasBannedPermission(.banSendVideos) {
                        bannedSendVideos = (Int32.max, false)
                    }
                    if group.hasBannedPermission(.banSendFiles) {
                        bannedSendFiles = (Int32.max, false)
                    }
                    if group.hasBannedPermission(.banSendText) {
                        banSendText = (Int32.max, false)
                    }
                    if group.hasBannedPermission(.banSendPolls) {
                        canSendPolls = false
                    }
                }
                
                var availableButtons: [AttachmentButtonType] = [.gallery, .file]
                if banSendText == nil {
                    availableButtons.append(.location)
                    availableButtons.append(.contact)
                }
                if canSendPolls {
                    availableButtons.insert(.poll, at: max(0, availableButtons.count - 1))
                }
                
                let isScheduledMessages = !"".isEmpty
                
                var peerType: AttachMenuBots.Bot.PeerFlags = []
                if case let .user(user) = peer {
                    if let _ = user.botInfo {
                        peerType.insert(.bot)
                    } else {
                        peerType.insert(.user)
                    }
                } else if case .legacyGroup = peer {
                    peerType = .group
                } else if case let .channel(channel) = peer {
                    if case .broadcast = channel.info {
                        peerType = .channel
                    } else {
                        peerType = .group
                    }
                }
                
                let buttons: Signal<([AttachmentButtonType], [AttachmentButtonType], AttachmentButtonType?), NoError>
                if !isScheduledMessages {
                    buttons = component.context.engine.messages.attachMenuBots()
                    |> map { attachMenuBots in
                        var buttons = availableButtons
                        var allButtons = availableButtons
                        var initialButton: AttachmentButtonType?
                        switch subject {
                        case .default:
                            initialButton = .gallery
                        /*case .edit:
                            break
                        case .gift:
                            initialButton = .gift*/
                        }
                        
                        for bot in attachMenuBots.reversed() {
                            var peerType = peerType
                            if bot.peer.id == peer.id {
                                peerType.insert(.sameBot)
                                peerType.remove(.bot)
                            }
                            let button: AttachmentButtonType = .app(bot.peer, bot.shortName, bot.icons)
                            if !bot.peerTypes.intersection(peerType).isEmpty {
                                buttons.insert(button, at: 1)
                                
                                /*if case let .bot(botId, _, _) = subject {
                                    if initialButton == nil && bot.peer.id == botId {
                                        initialButton = button
                                    }
                                }*/
                            }
                            allButtons.insert(button, at: 1)
                        }
                        
                        return (buttons, allButtons, initialButton)
                    }
                } else {
                    buttons = .single((availableButtons, availableButtons, .gallery))
                }
                            
                let dataSettings = component.context.sharedContext.accountManager.transaction { transaction -> GeneratedMediaStoreSettings in
                    let entry = transaction.getSharedData(ApplicationSpecificSharedDataKeys.generatedMediaStoreSettings)?.get(GeneratedMediaStoreSettings.self)
                    return entry ?? GeneratedMediaStoreSettings.defaultSettings
                }
                
                let premiumConfiguration = PremiumConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
                let premiumGiftOptions: [CachedPremiumGiftOption]
                if !premiumConfiguration.isPremiumDisabled && premiumConfiguration.showPremiumGiftInAttachMenu, case let .user(user) = peer, !user.isPremium && !user.isDeleted && user.botInfo == nil && !user.flags.contains(.isSupport) {
                    premiumGiftOptions = []//self.presentationInterfaceState.premiumGiftOptions
                    //TODO:premium gift options
                } else {
                    premiumGiftOptions = []
                }
                
                let _ = combineLatest(queue: Queue.mainQueue(), buttons, dataSettings).start(next: { [weak self] buttonsAndInitialButton, dataSettings in
                    guard let self, let component = self.component else {
                        return
                    }
                    
                    var (buttons, allButtons, initialButton) = buttonsAndInitialButton
                    if !premiumGiftOptions.isEmpty {
                        buttons.insert(.gift, at: 1)
                    }
                    let _ = allButtons
                    
                    guard let initialButton = initialButton else {
                        /*if case let .bot(botId, botPayload, botJustInstalled) = subject {
                            if let button = allButtons.first(where: { button in
                                if case let .app(botPeer, _, _) = button, botPeer.id == botId {
                                    return true
                                } else {
                                    return false
                                }
                            }), case let .app(_, botName, _) = button {
                                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                                self.environment?.controller().present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: botJustInstalled ? presentationData.strings.WebApp_AddToAttachmentSucceeded(botName).string : presentationData.strings.WebApp_AddToAttachmentAlreadyAddedError, timeout: nil), elevatedLayout: false, action: { _ in return false }), in: .current)
                            } else {
                                let _ = (context.engine.messages.getAttachMenuBot(botId: botId)
                                |> deliverOnMainQueue).start(next: { [weak self] bot in
                                    guard let self, let component = self.component else {
                                        return
                                    }
                                    
                                    let peer = EnginePeer(bot.peer)
                                                       
                                    let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                                    let controller = addWebAppToAttachmentController(context: context, peerName: peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), icons: bot.icons, requestWriteAccess: bot.flags.contains(.requiresWriteAccess), completion: { allowWrite in
                                        let _ = (context.engine.messages.addBotToAttachMenu(botId: botId, allowWrite: allowWrite)
                                        |> deliverOnMainQueue).start(error: { _ in
                                        }, completed: {
                                            //TODO:present attachment bot
                                            //strongSelf.presentAttachmentBot(botId: botId, payload: botPayload, justInstalled: true)
                                        })
                                    })
                                    self.environment?.controller().present(controller, in: .window(.root))
                                }, error: { [weak self] _ in
                                    guard let self, let component = self.component else {
                                        return
                                    }
                                    let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                                    self.environment?.controller().present(textAlertController(context: context, updatedPresentationData: nil, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                })
                            }
                        }*/
                        return
                    }
                    
                    let currentMediaController = Atomic<MediaPickerScreen?>(value: nil)
                    let currentFilesController = Atomic<AttachmentFileController?>(value: nil)
                    let currentLocationController = Atomic<LocationPickerController?>(value: nil)
                    
                    let attachmentController = AttachmentController(
                        context: component.context,
                        updatedPresentationData: nil,
                        chatLocation: .peer(id: peer.id),
                        buttons: buttons,
                        initialButton: initialButton,
                        makeEntityInputView: { [weak self] in
                            guard let self, let component = self.component else {
                                return nil
                            }
                            return EntityInputView(
                                context: component.context,
                                isDark: true,
                                areCustomEmojiEnabled: true //TODO:check custom emoji
                            )
                        }
                    )
                    attachmentController.didDismiss = { [weak self] in
                        guard let self else {
                            return
                        }
                        self.attachmentController = nil
                    }
                    attachmentController.getSourceRect = { [weak self] in
                        guard let self else {
                            return nil
                        }
                        guard let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View else {
                            return nil
                        }
                        guard let attachmentButtonView = inputPanelView.getAttachmentButtonView() else {
                            return nil
                        }
                        return attachmentButtonView.convert(attachmentButtonView.bounds, to: self)
                    }
                    attachmentController.requestController = { [weak self, weak attachmentController] type, completion in
                        guard let self else {
                            return
                        }
                        switch type {
                        case .gallery:
                            self.controllerNavigationDisposable.set(nil)
                            let existingController = currentMediaController.with { $0 }
                            if let controller = existingController {
                                completion(controller, controller.mediaPickerContext)
                                controller.prepareForReuse()
                                return
                            }
                            self.presentMediaPicker(
                                peer: peer,
                                replyToMessageId: targetMessageId,
                                saveEditedPhotos: dataSettings.storeEditedPhotos,
                                bannedSendPhotos: bannedSendPhotos,
                                bannedSendVideos: bannedSendVideos,
                                present: { controller, mediaPickerContext in
                                    let _ = currentMediaController.swap(controller)
                                    if !inputText.string.isEmpty {
                                        mediaPickerContext?.setCaption(inputText)
                                    }
                                    completion(controller, mediaPickerContext)
                                }, updateMediaPickerContext: { [weak attachmentController] mediaPickerContext in
                                    attachmentController?.mediaPickerContext = mediaPickerContext
                                }, completion: { [weak self] signals, silentPosting, scheduleTime, getAnimatedTransitionSource, completion in
                                    guard let self else {
                                        return
                                    }
                                    if !inputText.string.isEmpty {
                                        self.clearInputText()
                                    }
                                    self.enqueueMediaMessages(peer: peer, replyToMessageId: targetMessageId, signals: signals, silentPosting: silentPosting, scheduleTime: scheduleTime, getAnimatedTransitionSource: getAnimatedTransitionSource, completion: completion)
                                }
                            )
                        case .file:
                            self.controllerNavigationDisposable.set(nil)
                            let existingController = currentFilesController.with { $0 }
                            if let controller = existingController as? AttachmentContainable, let mediaPickerContext = controller.mediaPickerContext {
                                completion(controller, mediaPickerContext)
                                controller.prepareForReuse()
                                return
                            }
                            let controller = component.context.sharedContext.makeAttachmentFileController(context: component.context, updatedPresentationData: nil, bannedSendMedia: bannedSendFiles, presentGallery: { [weak self, weak attachmentController] in
                                guard let self else {
                                    return
                                }
                                attachmentController?.dismiss(animated: true)
                                self.presentFileGallery(peer: peer, replyMessageId: targetMessageId)
                            }, presentFiles: { [weak self, weak attachmentController] in
                                guard let self else {
                                    return
                                }
                                attachmentController?.dismiss(animated: true)
                                self.presentICloudFileGallery(peer: peer, replyMessageId: targetMessageId)
                            }, send: { [weak self] mediaReference in
                                guard let self, let component = self.component else {
                                    return
                                }
                                let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: mediaReference, replyToMessageId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                                let _ = (enqueueMessages(account: component.context.account, peerId: peer.id, messages: [message.withUpdatedReplyToMessageId(targetMessageId)])
                                |> deliverOnMainQueue).start()
                                
                                if let controller = self.environment?.controller() {
                                    let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                                    controller.present(UndoOverlayController(
                                        presentationData: presentationData,
                                        content: .succeed(text: "Message Sent"),
                                        elevatedLayout: false,
                                        animateInAsReplacement: false,
                                        action: { _ in return false }
                                    ), in: .current)
                                }
                            })
                            let _ = currentFilesController.swap(controller)
                            if let controller = controller as? AttachmentContainable, let mediaPickerContext = controller.mediaPickerContext {
                                completion(controller, mediaPickerContext)
                            }
                        case .location:
                            self.controllerNavigationDisposable.set(nil)
                            let existingController = currentLocationController.with { $0 }
                            if let controller = existingController {
                                completion(controller, controller.mediaPickerContext)
                                controller.prepareForReuse()
                                return
                            }
                            let selfPeerId: EnginePeer.Id
                            if case let .channel(peer) = peer, case .broadcast = peer.info {
                                selfPeerId = peer.id
                            } else if case let .channel(peer) = peer, case .group = peer.info, peer.hasPermission(.canBeAnonymous) {
                                selfPeerId = peer.id
                            } else {
                                selfPeerId = component.context.account.peerId
                            }
                            let _ = (component.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: selfPeerId))
                            |> deliverOnMainQueue).start(next: { [weak self] selfPeer in
                                guard let self, let component = self.component, let selfPeer else {
                                    return
                                }
                                let hasLiveLocation = peer.id.namespace != Namespaces.Peer.SecretChat && peer.id != component.context.account.peerId
                                let controller = LocationPickerController(context: component.context, updatedPresentationData: nil, mode: .share(peer: peer, selfPeer: selfPeer, hasLiveLocation: hasLiveLocation), completion: { [weak self] location, _ in
                                    guard let self else {
                                        return
                                    }
                                    let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: location), replyToMessageId: targetMessageId, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                                    self.sendMessages(peer: peer, messages: [message])
                                })
                                completion(controller, controller.mediaPickerContext)
                                
                                let _ = currentLocationController.swap(controller)
                            })
                        case .contact:
                            let contactsController = component.context.sharedContext.makeContactSelectionController(ContactSelectionControllerParams(context: component.context, updatedPresentationData: nil, title: { $0.Contacts_Title }, displayDeviceContacts: true, multipleSelection: true))
                            contactsController.presentScheduleTimePicker = { [weak self] completion in
                                guard let self else {
                                    return
                                }
                                self.presentScheduleTimePicker(peer: peer, completion: completion)
                            }
                            contactsController.navigationPresentation = .modal
                            if let contactsController = contactsController as? AttachmentContainable, let mediaPickerContext = contactsController.mediaPickerContext {
                                completion(contactsController, mediaPickerContext)
                            }
                            self.controllerNavigationDisposable.set((contactsController.result
                            |> deliverOnMainQueue).start(next: { [weak self] peers in
                                guard let self, let (peers, _, silent, scheduleTime, text) = peers else {
                                    return
                                }
                                
                                let targetPeer = peer
                                
                                var textEnqueueMessage: EnqueueMessage?
                                if let text = text, text.length > 0 {
                                    var attributes: [EngineMessage.Attribute] = []
                                    let entities = generateTextEntities(text.string, enabledTypes: .all, currentEntities: generateChatInputTextEntities(text))
                                    if !entities.isEmpty {
                                        attributes.append(TextEntitiesMessageAttribute(entities: entities))
                                    }
                                    textEnqueueMessage = .message(text: text.string, attributes: attributes, inlineStickers: [:], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                                }
                                if peers.count > 1 {
                                    var enqueueMessages: [EnqueueMessage] = []
                                    if let textEnqueueMessage = textEnqueueMessage {
                                        enqueueMessages.append(textEnqueueMessage)
                                    }
                                    for peer in peers {
                                        var media: TelegramMediaContact?
                                        switch peer {
                                        case let .peer(contact, _, _):
                                            guard let contact = contact as? TelegramUser, let phoneNumber = contact.phone else {
                                                continue
                                            }
                                            let contactData = DeviceContactExtendedData(basicData: DeviceContactBasicData(firstName: contact.firstName ?? "", lastName: contact.lastName ?? "", phoneNumbers: [DeviceContactPhoneNumberData(label: "_$!<Mobile>!$_", value: phoneNumber)]), middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [], note: "")
                                            
                                            let phone = contactData.basicData.phoneNumbers[0].value
                                            media = TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: contact.id, vCardData: nil)
                                        case let .deviceContact(_, basicData):
                                            guard !basicData.phoneNumbers.isEmpty else {
                                                continue
                                            }
                                            let contactData = DeviceContactExtendedData(basicData: basicData, middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [], note: "")
                                            
                                            let phone = contactData.basicData.phoneNumbers[0].value
                                            media = TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: nil, vCardData: nil)
                                        }
                                        
                                        if let media = media {
                                            let replyMessageId = targetMessageId
                                            /*strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                                if let strongSelf = self {
                                                    strongSelf.chatDisplayNode.collapseInput()
                                                    
                                                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                                        $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                                                    })
                                                }
                                            }, nil)*/
                                            let message = EnqueueMessage.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: media), replyToMessageId: replyMessageId, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                                            enqueueMessages.append(message)
                                        }
                                    }
                                    
                                    self.sendMessages(peer: peer, messages: self.transformEnqueueMessages(messages: enqueueMessages, silentPosting: silent, scheduleTime: scheduleTime))
                                } else if let peer = peers.first {
                                    let dataSignal: Signal<(EnginePeer?, DeviceContactExtendedData?), NoError>
                                    switch peer {
                                    case let .peer(contact, _, _):
                                        guard let contact = contact as? TelegramUser, let phoneNumber = contact.phone else {
                                            return
                                        }
                                        let contactData = DeviceContactExtendedData(basicData: DeviceContactBasicData(firstName: contact.firstName ?? "", lastName: contact.lastName ?? "", phoneNumbers: [DeviceContactPhoneNumberData(label: "_$!<Mobile>!$_", value: phoneNumber)]), middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [], note: "")
                                        let context = component.context
                                        dataSignal = (component.context.sharedContext.contactDataManager?.basicData() ?? .single([:]))
                                        |> take(1)
                                        |> mapToSignal { basicData -> Signal<(EnginePeer?,  DeviceContactExtendedData?), NoError> in
                                            var stableId: String?
                                            let queryPhoneNumber = formatPhoneNumber(context: context, number: phoneNumber)
                                            outer: for (id, data) in basicData {
                                                for phoneNumber in data.phoneNumbers {
                                                    if formatPhoneNumber(context: context, number: phoneNumber.value) == queryPhoneNumber {
                                                        stableId = id
                                                        break outer
                                                    }
                                                }
                                            }
                                            
                                            if let stableId = stableId {
                                                return (context.sharedContext.contactDataManager?.extendedData(stableId: stableId) ?? .single(nil))
                                                |> take(1)
                                                |> map { extendedData -> (EnginePeer?,  DeviceContactExtendedData?) in
                                                    return (EnginePeer(contact), extendedData)
                                                }
                                            } else {
                                                return .single((EnginePeer(contact), contactData))
                                            }
                                        }
                                    case let .deviceContact(id, _):
                                        dataSignal = (component.context.sharedContext.contactDataManager?.extendedData(stableId: id) ?? .single(nil))
                                        |> take(1)
                                        |> map { extendedData -> (EnginePeer?,  DeviceContactExtendedData?) in
                                            return (nil, extendedData)
                                        }
                                    }
                                    self.controllerNavigationDisposable.set((dataSignal
                                    |> deliverOnMainQueue).start(next: { [weak self] peerAndContactData in
                                        guard let self, let contactData = peerAndContactData.1, contactData.basicData.phoneNumbers.count != 0 else {
                                            return
                                        }
                                        if contactData.isPrimitive {
                                            let phone = contactData.basicData.phoneNumbers[0].value
                                            let media = TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: peerAndContactData.0?.id, vCardData: nil)
                                            let replyMessageId = targetMessageId
                                            /*strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                                if let strongSelf = self {
                                                    strongSelf.chatDisplayNode.collapseInput()
                                                    
                                                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                                        $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                                                    })
                                                }
                                            }, nil)*/
                                            
                                            var enqueueMessages: [EnqueueMessage] = []
                                            if let textEnqueueMessage = textEnqueueMessage {
                                                enqueueMessages.append(textEnqueueMessage)
                                            }
                                            enqueueMessages.append(.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: media), replyToMessageId: replyMessageId, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))
                                            
                                            self.sendMessages(peer: targetPeer, messages: self.transformEnqueueMessages(messages: enqueueMessages, silentPosting: silent, scheduleTime: scheduleTime))
                                        } else {
                                            let contactController = component.context.sharedContext.makeDeviceContactInfoController(context: component.context, subject: .filter(peer: peerAndContactData.0?._asPeer(), contactId: nil, contactData: contactData, completion: { [weak self] peer, contactData in
                                                guard let self else {
                                                    return
                                                }
                                                if contactData.basicData.phoneNumbers.isEmpty {
                                                    return
                                                }
                                                let phone = contactData.basicData.phoneNumbers[0].value
                                                if let vCardData = contactData.serializedVCard() {
                                                    let media = TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: peer?.id, vCardData: vCardData)
                                                    let replyMessageId = targetMessageId
                                                    /*strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                                        if let strongSelf = self {
                                                            strongSelf.chatDisplayNode.collapseInput()
                                                            
                                                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                                                $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                                                            })
                                                        }
                                                    }, nil)*/
                                                    
                                                    var enqueueMessages: [EnqueueMessage] = []
                                                    if let textEnqueueMessage = textEnqueueMessage {
                                                        enqueueMessages.append(textEnqueueMessage)
                                                    }
                                                    enqueueMessages.append(.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: media), replyToMessageId: replyMessageId, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))
                                                    
                                                    self.sendMessages(peer: targetPeer, messages: self.transformEnqueueMessages(messages: enqueueMessages, silentPosting: silent, scheduleTime: scheduleTime))
                                                }
                                            }), completed: nil, cancelled: nil)
                                            self.environment?.controller()?.push(contactController)
                                        }
                                    }))
                                }
                            }))
                        case .poll:
                            let controller = self.configurePollCreation(peer: peer, targetMessageId: targetMessageId)
                            completion(controller, controller?.mediaPickerContext)
                            self.controllerNavigationDisposable.set(nil)
                        case .gift:
                            /*let premiumGiftOptions = strongSelf.presentationInterfaceState.premiumGiftOptions
                            if !premiumGiftOptions.isEmpty {
                                let controller = PremiumGiftScreen(context: context, peerId: peer.id, options: premiumGiftOptions, source: .attachMenu, pushController: { [weak self] c in
                                    if let strongSelf = self {
                                        strongSelf.push(c)
                                    }
                                }, completion: { [weak self] in
                                    if let strongSelf = self {
                                        strongSelf.hintPlayNextOutgoingGift()
                                        strongSelf.attachmentController?.dismiss(animated: true)
                                    }
                                })
                                completion(controller, controller.mediaPickerContext)
                                strongSelf.controllerNavigationDisposable.set(nil)
                                
                                let _ = ApplicationSpecificNotice.incrementDismissedPremiumGiftSuggestion(accountManager: context.sharedContext.accountManager, peerId: peer.id).start()
                            }*/
                            //TODO:gift controller
                            break
                        case let .app(bot, botName, _):
                            var payload: String?
                            var fromAttachMenu = true
                            /*if case let .bot(_, botPayload, _) = subject {
                                payload = botPayload
                                fromAttachMenu = false
                            }*/
                            payload = nil
                            fromAttachMenu = true
                            let params = WebAppParameters(peerId: peer.id, botId: bot.id, botName: botName, url: nil, queryId: nil, payload: payload, buttonText: nil, keepAliveSignal: nil, fromMenu: false, fromAttachMenu: fromAttachMenu, isInline: false, isSimple: false)
                            let replyMessageId = targetMessageId
                            let controller = WebAppController(context: component.context, updatedPresentationData: nil, params: params, replyToMessageId: replyMessageId, threadId: nil)
                            controller.openUrl = { [weak self] url in
                                guard let self else {
                                    return
                                }
                                let _ = self
                                //self?.openUrl(url, concealed: true, forceExternal: true)
                            }
                            controller.getNavigationController = { [weak self] in
                                guard let self, let controller = self.environment?.controller() else {
                                    return nil
                                }
                                return controller.navigationController as? NavigationController
                            }
                            controller.completion = { [weak self] in
                                guard let self else {
                                    return
                                }
                                let _ = self
                                /*if let strongSelf = self {
                                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                        $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                                    })
                                    strongSelf.chatDisplayNode.historyNode.scrollToEndOfHistory()
                                }*/
                            }
                            completion(controller, controller.mediaPickerContext)
                            self.controllerNavigationDisposable.set(nil)
                        default:
                            break
                        }
                    }
                    let present = { [weak self] in
                        guard let self, let controller = self.environment?.controller() else {
                            return
                        }
                        attachmentController.navigationPresentation = .flatModal
                        controller.push(attachmentController)
                        self.attachmentController = attachmentController
                    }
                    
                    if inputIsActive {
                        Queue.mainQueue().after(0.15, {
                            present()
                        })
                    } else {
                        present()
                    }
                })
            })
        }
        
        private func presentMediaPicker(
            peer: EnginePeer,
            replyToMessageId: EngineMessage.Id?,
            subject: MediaPickerScreen.Subject = .assets(nil, .default),
            saveEditedPhotos: Bool,
            bannedSendPhotos: (Int32, Bool)?,
            bannedSendVideos: (Int32, Bool)?,
            present: @escaping (MediaPickerScreen, AttachmentMediaPickerContext?) -> Void,
            updateMediaPickerContext: @escaping (AttachmentMediaPickerContext?) -> Void,
            completion: @escaping ([Any], Bool, Int32?, @escaping (String) -> UIView?, @escaping () -> Void) -> Void
        ) {
            guard let component = self.component else {
                return
            }
            let controller = MediaPickerScreen(context: component.context, updatedPresentationData: nil, peer: peer, threadTitle: nil, chatLocation: .peer(id: peer.id), bannedSendPhotos: bannedSendPhotos, bannedSendVideos: bannedSendVideos, subject: subject, saveEditedPhotos: saveEditedPhotos)
            let mediaPickerContext = controller.mediaPickerContext
            controller.openCamera = { [weak self] cameraView in
                guard let self else {
                    return
                }
                self.openCamera(peer: peer, replyToMessageId: replyToMessageId, cameraView: cameraView)
            }
            controller.presentWebSearch = { [weak self, weak controller] mediaGroups, activateOnDisplay in
                guard let self, let controller else {
                    return
                }
                self.presentWebSearch(editingMessage: false, attachment: true, activateOnDisplay: activateOnDisplay, present: { [weak controller] c, a in
                    controller?.present(c, in: .current)
                    if let webSearchController = c as? WebSearchController {
                        webSearchController.searchingUpdated = { [weak mediaGroups] searching in
                            if let mediaGroups = mediaGroups, mediaGroups.isNodeLoaded {
                                let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
                                transition.updateAlpha(node: mediaGroups.displayNode, alpha: searching ? 0.0 : 1.0)
                                mediaGroups.displayNode.isUserInteractionEnabled = !searching
                            }
                        }
                        webSearchController.present(mediaGroups, in: .current)
                        webSearchController.dismissed = {
                            updateMediaPickerContext(mediaPickerContext)
                        }
                        controller?.webSearchController = webSearchController
                        updateMediaPickerContext(webSearchController.mediaPickerContext)
                    }
                })
            }
            controller.presentSchedulePicker = { [weak self] media, done in
                guard let self else {
                    return
                }
                self.presentScheduleTimePicker(peer: peer, style: media ? .media : .default, completion: { time in
                    done(time)
                })
            }
            controller.presentTimerPicker = { [weak self] done in
                guard let self else {
                    return
                }
                self.presentTimerPicker(peer: peer, style: .media, completion: { time in
                    done(time)
                })
            }
            controller.getCaptionPanelView = { [weak self] in
                guard let self else {
                    return nil
                }
                return self.getCaptionPanelView(peer: peer)
            }
            controller.legacyCompletion = { signals, silently, scheduleTime, getAnimatedTransitionSource, sendCompletion in
                completion(signals, silently, scheduleTime, getAnimatedTransitionSource, sendCompletion)
            }
            present(controller, mediaPickerContext)
        }
        
        private func presentOldMediaPicker(peer: EnginePeer, replyMessageId: EngineMessage.Id?, fileMode: Bool, editingMedia: Bool, present: @escaping (AttachmentContainable, AttachmentMediaPickerContext) -> Void, completion: @escaping ([Any], Bool, Int32) -> Void) {
            guard let component = self.component else {
                return
            }
            guard let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View else {
                return
            }
            var inputText = NSAttributedString(string: "")
            switch inputPanelView.getSendMessageInput() {
            case let .text(text):
                inputText = NSAttributedString(string: text)
            }
            
            let engine = component.context.engine
            let _ = (component.context.sharedContext.accountManager.transaction { transaction -> Signal<(GeneratedMediaStoreSettings, EngineConfiguration.SearchBots), NoError> in
                let entry = transaction.getSharedData(ApplicationSpecificSharedDataKeys.generatedMediaStoreSettings)?.get(GeneratedMediaStoreSettings.self)
                
                return engine.data.get(TelegramEngine.EngineData.Item.Configuration.SearchBots())
                |> map { configuration -> (GeneratedMediaStoreSettings, EngineConfiguration.SearchBots) in
                    return (entry ?? GeneratedMediaStoreSettings.defaultSettings, configuration)
                }
            }
            |> switchToLatest
            |> deliverOnMainQueue).start(next: { [weak self] settings, searchBotsConfiguration in
                guard let strongSelf = self, let component = strongSelf.component else {
                    return
                }
                var selectionLimit: Int = 100
                var slowModeEnabled = false
                if case let .channel(channel) = peer, channel.isRestrictedBySlowmode {
                    selectionLimit = 10
                    slowModeEnabled = true
                }
                
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                
                let _ = legacyAssetPicker(context: component.context, presentationData: presentationData, editingMedia: editingMedia, fileMode: fileMode, peer: peer._asPeer(), threadTitle: nil, saveEditedPhotos: settings.storeEditedPhotos, allowGrouping: true, selectionLimit: selectionLimit).start(next: { generator in
                    if let strongSelf = self, let component = strongSelf.component, let controller = strongSelf.environment?.controller() {
                        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                        
                        let legacyController = LegacyController(presentation: fileMode ? .navigation : .custom, theme: presentationData.theme, initialLayout: controller.currentlyAppliedLayout)
                        legacyController.navigationPresentation = .modal
                        legacyController.statusBar.statusBarStyle = presentationData.theme.rootController.statusBarStyle.style
                        legacyController.controllerLoaded = { [weak legacyController] in
                            legacyController?.view.disablesInteractiveTransitionGestureRecognizer = true
                            legacyController?.view.disablesInteractiveModalDismiss = true
                        }
                        let controller = generator(legacyController.context)
                        
                        legacyController.bind(controller: controller)
                        legacyController.deferScreenEdgeGestures = [.top]
                                            
                        configureLegacyAssetPicker(controller, context: component.context, peer: peer._asPeer(), chatLocation: .peer(id: peer.id), initialCaption: inputText, hasSchedule: peer.id.namespace != Namespaces.Peer.SecretChat, presentWebSearch: editingMedia ? nil : { [weak legacyController] in
                            if let strongSelf = self, let component = strongSelf.component {
                                let controller = WebSearchController(context: component.context, updatedPresentationData: nil, peer: peer, chatLocation: .peer(id: peer.id), configuration: searchBotsConfiguration, mode: .media(attachment: false, completion: { results, selectionState, editingState, silentPosting in
                                    if let legacyController = legacyController {
                                        legacyController.dismiss()
                                    }
                                    legacyEnqueueWebSearchMessages(selectionState, editingState, enqueueChatContextResult: { result in
                                        if let strongSelf = self {
                                            strongSelf.enqueueChatContextResult(peer: peer, replyMessageId: replyMessageId, results: results, result: result, hideVia: true)
                                        }
                                    }, enqueueMediaMessages: { signals in
                                        if let strongSelf = self {
                                            if editingMedia {
                                                strongSelf.editMessageMediaWithLegacySignals(signals)
                                            } else {
                                                strongSelf.enqueueMediaMessages(peer: peer, replyToMessageId: replyMessageId, signals: signals, silentPosting: silentPosting)
                                            }
                                        }
                                    })
                                }))
                                controller.getCaptionPanelView = {
                                    guard let self else {
                                        return nil
                                    }
                                    return self.getCaptionPanelView(peer: peer)
                                }
                                strongSelf.environment?.controller()?.push(controller)
                            }
                        }, presentSelectionLimitExceeded: {
                            guard let strongSelf = self else {
                                return
                            }
                            
                            let text: String
                            if slowModeEnabled {
                                text = presentationData.strings.Chat_SlowmodeAttachmentLimitReached
                            } else {
                                text = presentationData.strings.Chat_AttachmentLimitReached
                            }
                            
                            strongSelf.environment?.controller()?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        }, presentSchedulePicker: { media, done in
                            if let strongSelf = self {
                                strongSelf.presentScheduleTimePicker(peer: peer, style: media ? .media : .default, completion: { time in
                                     done(time)
                                })
                            }
                        }, presentTimerPicker: { done in
                            if let strongSelf = self {
                                strongSelf.presentTimerPicker(peer: peer, style: .media, completion: { time in
                                    done(time)
                                })
                            }
                        }, getCaptionPanelView: {
                            guard let self else {
                                return nil
                            }
                            return self.getCaptionPanelView(peer: peer)
                        })
                        controller.descriptionGenerator = legacyAssetPickerItemGenerator()
                        controller.completionBlock = { [weak legacyController] signals, silentPosting, scheduleTime in
                            if let legacyController = legacyController {
                                legacyController.dismiss(animated: true)
                                completion(signals!, silentPosting, scheduleTime)
                            }
                        }
                        controller.dismissalBlock = { [weak legacyController] in
                            if let legacyController = legacyController {
                                legacyController.dismiss(animated: true)
                            }
                        }
                        strongSelf.endEditing(true)
                        present(legacyController, LegacyAssetPickerContext(controller: controller))
                    }
                })
            })
        }
        
        private func presentFileGallery(peer: EnginePeer, replyMessageId: EngineMessage.Id?, editingMessage: Bool = false) {
            self.presentOldMediaPicker(peer: peer, replyMessageId: replyMessageId, fileMode: true, editingMedia: editingMessage, present: { [weak self] c, _ in
                self?.environment?.controller()?.push(c)
            }, completion: { [weak self] signals, silentPosting, scheduleTime in
                if editingMessage {
                    self?.editMessageMediaWithLegacySignals(signals)
                } else {
                    self?.enqueueMediaMessages(peer: peer, replyToMessageId: replyMessageId, signals: signals, silentPosting: silentPosting, scheduleTime: scheduleTime > 0 ? scheduleTime : nil)
                }
            })
        }
        
        private func presentICloudFileGallery(peer: EnginePeer, replyMessageId: EngineMessage.Id?) {
            guard let component = self.component else {
                return
            }
            let _ = (component.context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: component.context.account.peerId),
                TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: false),
                TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: true)
            )
            |> deliverOnMainQueue).start(next: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                let (accountPeer, limits, premiumLimits) = result
                let isPremium = accountPeer?.isPremium ?? false
                
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                
                strongSelf.environment?.controller()?.present(legacyICloudFilePicker(theme: presentationData.theme, completion: { [weak self] urls in
                    if let strongSelf = self, !urls.isEmpty {
                        var signals: [Signal<ICloudFileDescription?, NoError>] = []
                        for url in urls {
                            signals.append(iCloudFileDescription(url))
                        }
                        strongSelf.enqueueMediaMessageDisposable.set((combineLatest(signals)
                        |> deliverOnMainQueue).start(next: { results in
                            if let strongSelf = self, let component = strongSelf.component {
                                for item in results {
                                    if let item = item {
                                        if item.fileSize > Int64(premiumLimits.maxUploadFileParts) * 512 * 1024 {
                                            let controller = PremiumLimitScreen(context: component.context, subject: .files, count: 4, action: {
                                            })
                                            strongSelf.environment?.controller()?.push(controller)
                                            return
                                        } else if item.fileSize > Int64(limits.maxUploadFileParts) * 512 * 1024 && !isPremium {
                                            let context = component.context
                                            var replaceImpl: ((ViewController) -> Void)?
                                            let controller = PremiumLimitScreen(context: context, subject: .files, count: 2, action: {
                                                replaceImpl?(PremiumIntroScreen(context: context, source: .upload))
                                            })
                                            replaceImpl = { [weak controller] c in
                                                controller?.replace(with: c)
                                            }
                                            strongSelf.environment?.controller()?.push(controller)
                                            return
                                        }
                                    }
                                }
                                
                                var groupingKey: Int64?
                                var fileTypes: (music: Bool, other: Bool) = (false, false)
                                if results.count > 1 {
                                    for item in results {
                                        if let item = item {
                                            let pathExtension = (item.fileName as NSString).pathExtension.lowercased()
                                            if ["mp3", "m4a"].contains(pathExtension) {
                                                fileTypes.music = true
                                            } else {
                                                fileTypes.other = true
                                            }
                                        }
                                    }
                                }
                                if fileTypes.music != fileTypes.other {
                                    groupingKey = Int64.random(in: Int64.min ... Int64.max)
                                }
                                
                                var messages: [EnqueueMessage] = []
                                for item in results {
                                    if let item = item {
                                        let fileId = Int64.random(in: Int64.min ... Int64.max)
                                        let mimeType = guessMimeTypeByFileExtension((item.fileName as NSString).pathExtension)
                                        var previewRepresentations: [TelegramMediaImageRepresentation] = []
                                        if mimeType.hasPrefix("image/") || mimeType == "application/pdf" {
                                            previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 320, height: 320), resource: ICloudFileResource(urlData: item.urlData, thumbnail: true), progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false))
                                        }
                                        var attributes: [TelegramMediaFileAttribute] = []
                                        attributes.append(.FileName(fileName: item.fileName))
                                        if let audioMetadata = item.audioMetadata {
                                            attributes.append(.Audio(isVoice: false, duration: audioMetadata.duration, title: audioMetadata.title, performer: audioMetadata.performer, waveform: nil))
                                        }
                                        
                                        let file = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: fileId), partialReference: nil, resource: ICloudFileResource(urlData: item.urlData, thumbnail: false), previewRepresentations: previewRepresentations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: mimeType, size: Int64(item.fileSize), attributes: attributes)
                                        let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), replyToMessageId: replyMessageId, localGroupingKey: groupingKey, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                                        messages.append(message)
                                    }
                                    if let _ = groupingKey, messages.count % 10 == 0 {
                                        groupingKey = Int64.random(in: Int64.min ... Int64.max)
                                    }
                                }
                                
                                if !messages.isEmpty {
                                    strongSelf.sendMessages(peer: peer, messages: messages)
                                }
                            }
                        }))
                    }
                }), in: .window(.root))
            })
        }
        
        private func enqueueChatContextResult(peer: EnginePeer, replyMessageId: EngineMessage.Id?, results: ChatContextResultCollection, result: ChatContextResult, hideVia: Bool = false, closeMediaInput: Bool = false, silentPosting: Bool = false, resetTextInputState: Bool = true) {
            if !canSendMessagesToPeer(peer._asPeer()) {
                return
            }
            
            let sendMessage: (Int32?) -> Void = { [weak self] scheduleTime in
                guard let self, let component = self.component else {
                    return
                }
                if component.context.engine.messages.enqueueOutgoingMessageWithChatContextResult(to: peer.id, threadId: nil, botId: results.botId, result: result, replyToMessageId: replyMessageId, hideVia: hideVia, silentPosting: silentPosting, scheduleTime: scheduleTime) {
                }
            }
            
            sendMessage(nil)
        }
        
        private func presentWebSearch(editingMessage: Bool, attachment: Bool, activateOnDisplay: Bool = true, present: @escaping (ViewController, Any?) -> Void) {
            /*guard let peer = self.presentationInterfaceState.renderedPeer?.peer else {
                return
            }
            
            let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Configuration.SearchBots())
            |> deliverOnMainQueue).start(next: { [weak self] configuration in
                if let strongSelf = self {
                    let controller = WebSearchController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, peer: EnginePeer(peer), chatLocation: strongSelf.chatLocation, configuration: configuration, mode: .media(attachment: attachment, completion: { [weak self] results, selectionState, editingState, silentPosting in
                        self?.attachmentController?.dismiss(animated: true, completion: nil)
                        legacyEnqueueWebSearchMessages(selectionState, editingState, enqueueChatContextResult: { [weak self] result in
                            if let strongSelf = self {
                                strongSelf.enqueueChatContextResult(results, result, hideVia: true)
                            }
                        }, enqueueMediaMessages: { [weak self] signals in
                            if let strongSelf = self, !signals.isEmpty {
                                if editingMessage {
                                    strongSelf.editMessageMediaWithLegacySignals(signals)
                                } else {
                                    strongSelf.enqueueMediaMessages(signals: signals, silentPosting: silentPosting)
                                }
                            }
                        })
                    }), activateOnDisplay: activateOnDisplay)
                    controller.attemptItemSelection = { [weak strongSelf] item in
                        guard let strongSelf, let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer else {
                            return false
                        }
                        
                        enum ItemType {
                            case gif
                            case image
                            case video
                        }
                        
                        var itemType: ItemType?
                        switch item {
                        case let .internalReference(reference):
                            if reference.type == "gif" {
                                itemType = .gif
                            } else if reference.type == "photo" {
                                itemType = .image
                            } else if reference.type == "video" {
                                itemType = .video
                            }
                        case let .externalReference(reference):
                            if reference.type == "gif" {
                                itemType = .gif
                            } else if reference.type == "photo" {
                                itemType = .image
                            } else if reference.type == "video" {
                                itemType = .video
                            }
                        }
                        
                        var bannedSendPhotos: (Int32, Bool)?
                        var bannedSendVideos: (Int32, Bool)?
                        var bannedSendGifs: (Int32, Bool)?
                        
                        if let channel = peer as? TelegramChannel {
                            if let value = channel.hasBannedPermission(.banSendPhotos) {
                                bannedSendPhotos = value
                            }
                            if let value = channel.hasBannedPermission(.banSendVideos) {
                                bannedSendVideos = value
                            }
                            if let value = channel.hasBannedPermission(.banSendGifs) {
                                bannedSendGifs = value
                            }
                        } else if let group = peer as? TelegramGroup {
                            if group.hasBannedPermission(.banSendPhotos) {
                                bannedSendPhotos = (Int32.max, false)
                            }
                            if group.hasBannedPermission(.banSendVideos) {
                                bannedSendVideos = (Int32.max, false)
                            }
                            if group.hasBannedPermission(.banSendGifs) {
                                bannedSendGifs = (Int32.max, false)
                            }
                        }
                        
                        if let itemType {
                            switch itemType {
                            case .image:
                                if bannedSendPhotos != nil {
                                    strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: strongSelf.restrictedSendingContentsText(), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                    
                                    return false
                                }
                            case .video:
                                if bannedSendVideos != nil {
                                    strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: strongSelf.restrictedSendingContentsText(), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                    
                                    return false
                                }
                            case .gif:
                                if bannedSendGifs != nil {
                                    strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: strongSelf.restrictedSendingContentsText(), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                    
                                    return false
                                }
                            }
                        }
                        
                        return true
                    }
                    controller.getCaptionPanelView = { [weak strongSelf] in
                        return strongSelf?.getCaptionPanelView()
                    }
                    present(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                }
            })*/
        }
        
        private func getCaptionPanelView(peer: EnginePeer) -> TGCaptionPanelView? {
            guard let component = self.component else {
                return nil
            }
            //TODO:self.presentationInterfaceState.customEmojiAvailable
            return component.context.sharedContext.makeGalleryCaptionPanelView(context: component.context, chatLocation: .peer(id: peer.id), customEmojiAvailable: true, present: { [weak self] c in
                guard let self else {
                    return
                }
                self.environment?.controller()?.present(c, in: .window(.root))
            }, presentInGlobalOverlay: { [weak self] c in
                guard let self else {
                    return
                }
                self.environment?.controller()?.presentInGlobalOverlay(c)
            }) as? TGCaptionPanelView
        }
        
        private func openCamera(peer: EnginePeer, replyToMessageId: EngineMessage.Id?, cameraView: TGAttachmentCameraView? = nil) {
            guard let component = self.component else {
                return
            }
            guard let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View else {
                return
            }
            
            var inputText = NSAttributedString(string: "")
            switch inputPanelView.getSendMessageInput() {
            case let .text(text):
                inputText = NSAttributedString(string: text)
            }
            
            let _ = (component.context.sharedContext.accountManager.transaction { transaction -> GeneratedMediaStoreSettings in
                let entry = transaction.getSharedData(ApplicationSpecificSharedDataKeys.generatedMediaStoreSettings)?.get(GeneratedMediaStoreSettings.self)
                return entry ?? GeneratedMediaStoreSettings.defaultSettings
            }
            |> deliverOnMainQueue).start(next: { [weak self] settings in
                guard let self, let component = self.component, let parentController = self.environment?.controller() else {
                    return
                }
                
                var enablePhoto = true
                var enableVideo = true
                
                if let callManager = component.context.sharedContext.callManager, callManager.hasActiveCall {
                    enableVideo = false
                }
                
                var bannedSendPhotos: (Int32, Bool)?
                var bannedSendVideos: (Int32, Bool)?
                
                if case let .channel(channel) = peer {
                    if let value = channel.hasBannedPermission(.banSendPhotos) {
                        bannedSendPhotos = value
                    }
                    if let value = channel.hasBannedPermission(.banSendVideos) {
                        bannedSendVideos = value
                    }
                } else if case let .legacyGroup(group) = peer {
                    if group.hasBannedPermission(.banSendPhotos) {
                        bannedSendPhotos = (Int32.max, false)
                    }
                    if group.hasBannedPermission(.banSendVideos) {
                        bannedSendVideos = (Int32.max, false)
                    }
                }
                
                if bannedSendPhotos != nil {
                    enablePhoto = false
                }
                if bannedSendVideos != nil {
                    enableVideo = false
                }
                
                let storeCapturedMedia = peer.id.namespace != Namespaces.Peer.SecretChat
                
                presentedLegacyCamera(context: component.context, peer: peer._asPeer(), chatLocation: .peer(id: peer.id), cameraView: cameraView, menuController: nil, parentController: parentController, attachmentController: self.attachmentController, editingMedia: false, saveCapturedPhotos: storeCapturedMedia, mediaGrouping: true, initialCaption: inputText, hasSchedule: peer.id.namespace != Namespaces.Peer.SecretChat, enablePhoto: enablePhoto, enableVideo: enableVideo, sendMessagesWithSignals: { [weak self] signals, silentPosting, scheduleTime in
                    guard let self else {
                        return
                    }
                    self.enqueueMediaMessages(peer: peer, replyToMessageId: replyToMessageId, signals: signals, silentPosting: silentPosting, scheduleTime: scheduleTime > 0 ? scheduleTime : nil)
                    if !inputText.string.isEmpty {
                        self.clearInputText()
                    }
                }, recognizedQRCode: { _ in
                }, presentSchedulePicker: { [weak self] _, done in
                    guard let self else {
                        return
                    }
                    self.presentScheduleTimePicker(peer: peer, style: .media, completion: { time in
                        done(time)
                    })
                }, presentTimerPicker: { [weak self] done in
                    guard let self else {
                        return
                    }
                    self.presentTimerPicker(peer: peer, style: .media, completion: { time in
                        done(time)
                    })
                }, getCaptionPanelView: { [weak self] in
                    guard let self else {
                        return nil
                    }
                    return self.getCaptionPanelView(peer: peer)
                }, dismissedWithResult: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.attachmentController?.dismiss(animated: false, completion: nil)
                }, finishedTransitionIn: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.attachmentController?.scrollToTop?()
                })
            })
        }
        
        private func presentScheduleTimePicker(
            peer: EnginePeer,
            style: ChatScheduleTimeControllerStyle = .default,
            selectedTime: Int32? = nil,
            dismissByTapOutside: Bool = true,
            completion: @escaping (Int32) -> Void
        ) {
            guard let component = self.component else {
                return
            }
            let _ = (component.context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Presence(id: peer.id)
            )
            |> deliverOnMainQueue).start(next: { [weak self] presence in
                guard let self, let component = self.component else {
                    return
                }
                
                var sendWhenOnlineAvailable = false
                if let presence, case .present = presence.status {
                    sendWhenOnlineAvailable = true
                }
                if peer.id.namespace == Namespaces.Peer.CloudUser && peer.id.id._internalGetInt64Value() == 777000 {
                    sendWhenOnlineAvailable = false
                }
                
                let mode: ChatScheduleTimeControllerMode
                if peer.id == component.context.account.peerId {
                    mode = .reminders
                } else {
                    mode = .scheduledMessages(sendWhenOnlineAvailable: sendWhenOnlineAvailable)
                }
                let controller = ChatScheduleTimeController(context: component.context, updatedPresentationData: nil, peerId: peer.id, mode: mode, style: style, currentTime: selectedTime, minimalTime: nil, dismissByTapOutside: dismissByTapOutside, completion: { time in
                    completion(time)
                })
                self.endEditing(true)
                self.environment?.controller()?.present(controller, in: .window(.root))
            })
        }
        
        private func presentTimerPicker(peer: EnginePeer, style: ChatTimerScreenStyle = .default, selectedTime: Int32? = nil, dismissByTapOutside: Bool = true, completion: @escaping (Int32) -> Void) {
            guard let component = self.component else {
                return
            }
            let controller = ChatTimerScreen(context: component.context, updatedPresentationData: nil, style: style, currentTime: selectedTime, dismissByTapOutside: dismissByTapOutside, completion: { time in
                completion(time)
            })
            self.endEditing(true)
            self.environment?.controller()?.present(controller, in: .window(.root))
        }
        
        private func configurePollCreation(peer: EnginePeer, targetMessageId: EngineMessage.Id, isQuiz: Bool? = nil) -> CreatePollControllerImpl? {
            guard let component = self.component else {
                return nil
            }
            return createPollController(context: component.context, updatedPresentationData: nil, peer: peer, isQuiz: isQuiz, completion: { [weak self] poll in
                guard let self else {
                    return
                }
                let replyMessageId = targetMessageId
                /*strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                    if let strongSelf = self {
                        strongSelf.chatDisplayNode.collapseInput()
                        
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                        })
                    }
                }, nil)*/
                let message: EnqueueMessage = .message(
                    text: "",
                    attributes: [],
                    inlineStickers: [:],
                    mediaReference: .standalone(media: TelegramMediaPoll(
                        pollId: EngineMedia.Id(namespace: Namespaces.Media.LocalPoll, id: Int64.random(in: Int64.min ... Int64.max)),
                        publicity: poll.publicity,
                        kind: poll.kind,
                        text: poll.text,
                        options: poll.options,
                        correctAnswers: poll.correctAnswers,
                        results: poll.results,
                        isClosed: false,
                        deadlineTimeout: poll.deadlineTimeout
                    )),
                    replyToMessageId: nil,
                    localGroupingKey: nil,
                    correlationId: nil,
                    bubbleUpEmojiOrStickersets: []
                )
                self.sendMessages(peer: peer, messages: [message.withUpdatedReplyToMessageId(replyMessageId)])
            })
        }
        
        private func transformEnqueueMessages(messages: [EnqueueMessage], silentPosting: Bool, scheduleTime: Int32? = nil) -> [EnqueueMessage] {
            guard let focusedItemId = self.focusedItemId, let focusedItem = self.currentSlice?.items.first(where: { $0.id == focusedItemId }) else {
                return []
            }
            guard let targetMessageId = focusedItem.targetMessageId else {
                return []
            }
            
            let defaultReplyMessageId: EngineMessage.Id? = targetMessageId
            
            return messages.map { message in
                var message = message
                
                if let defaultReplyMessageId = defaultReplyMessageId {
                    switch message {
                    case let .message(text, attributes, inlineStickers, mediaReference, replyToMessageId, localGroupingKey, correlationId, bubbleUpEmojiOrStickersets):
                        if replyToMessageId == nil {
                            message = .message(text: text, attributes: attributes, inlineStickers: inlineStickers, mediaReference: mediaReference, replyToMessageId: defaultReplyMessageId, localGroupingKey: localGroupingKey, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)
                        }
                    case .forward:
                        break
                    }
                }
                
                return message.withUpdatedAttributes { attributes in
                    var attributes = attributes
                    if silentPosting || scheduleTime != nil {
                        for i in (0 ..< attributes.count).reversed() {
                            if attributes[i] is NotificationInfoMessageAttribute {
                                attributes.remove(at: i)
                            } else if let _ = scheduleTime, attributes[i] is OutgoingScheduleInfoMessageAttribute {
                                attributes.remove(at: i)
                            }
                        }
                        if silentPosting {
                            attributes.append(NotificationInfoMessageAttribute(flags: .muted))
                        }
                        if let scheduleTime = scheduleTime {
                             attributes.append(OutgoingScheduleInfoMessageAttribute(scheduleTime: scheduleTime))
                        }
                    }
                    return attributes
                }
            }
        }
        
        private func sendMessages(peer: EnginePeer, messages: [EnqueueMessage], media: Bool = false, commit: Bool = false) {
            guard let component = self.component else {
                return
            }
            let _ = (enqueueMessages(account: component.context.account, peerId: peer.id, messages: self.transformEnqueueMessages(messages: messages, silentPosting: false))
            |> deliverOnMainQueue).start()
            
            donateSendMessageIntent(account: component.context.account, sharedContext: component.context.sharedContext, intentContext: .chat, peerIds: [peer.id])
            
            if let controller = self.environment?.controller() {
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                controller.present(UndoOverlayController(
                    presentationData: presentationData,
                    content: .succeed(text: "Message Sent"),
                    elevatedLayout: false,
                    animateInAsReplacement: false,
                    action: { _ in return false }
                ), in: .current)
            }
        }
        
        private func enqueueMediaMessages(peer: EnginePeer, replyToMessageId: EngineMessage.Id?, signals: [Any]?, silentPosting: Bool, scheduleTime: Int32? = nil, getAnimatedTransitionSource: ((String) -> UIView?)? = nil, completion: @escaping () -> Void = {}) {
            guard let component = self.component else {
                return
            }
            
            self.enqueueMediaMessageDisposable.set((legacyAssetPickerEnqueueMessages(context: component.context, account: component.context.account, signals: signals!)
            |> deliverOnMainQueue).start(next: { [weak self] items in
                if let strongSelf = self {
                    var mappedMessages: [EnqueueMessage] = []
                    var addedTransitions: [(Int64, [String], () -> Void)] = []
                    
                    var groupedCorrelationIds: [Int64: Int64] = [:]
                    
                    var skipAddingTransitions = false
                    
                    for item in items {
                        var message = item.message
                        if message.groupingKey != nil {
                            if items.count > 10 {
                                skipAddingTransitions = true
                            }
                        } else if items.count > 3 {
                            skipAddingTransitions = true
                        }
                        
                        if let uniqueId = item.uniqueId, !item.isFile && !skipAddingTransitions {
                            let correlationId: Int64
                            var addTransition = scheduleTime == nil
                            if let groupingKey = message.groupingKey {
                                if let existing = groupedCorrelationIds[groupingKey] {
                                    correlationId = existing
                                    addTransition = false
                                } else {
                                    correlationId = Int64.random(in: 0 ..< Int64.max)
                                    groupedCorrelationIds[groupingKey] = correlationId
                                }
                            } else {
                                correlationId = Int64.random(in: 0 ..< Int64.max)
                            }
                            message = message.withUpdatedCorrelationId(correlationId)

                            if addTransition {
                                addedTransitions.append((correlationId, [uniqueId], addedTransitions.isEmpty ? completion : {}))
                            } else {
                                if let index = addedTransitions.firstIndex(where: { $0.0 == correlationId }) {
                                    var (correlationId, uniqueIds, completion) = addedTransitions[index]
                                    uniqueIds.append(uniqueId)
                                    addedTransitions[index] = (correlationId, uniqueIds, completion)
                                }
                            }
                        }
                        mappedMessages.append(message)
                    }
                                                        
                    let messages = strongSelf.transformEnqueueMessages(messages: mappedMessages, silentPosting: silentPosting, scheduleTime: scheduleTime)

                    strongSelf.sendMessages(peer: peer, messages: messages.map { $0.withUpdatedReplyToMessageId(replyToMessageId) }, media: true)
                    
                    if let _ = scheduleTime {
                        completion()
                    }
                }
            }))
        }
        
        private func editMessageMediaWithLegacySignals(_ signals: [Any]) {
            guard let component = self.component else {
                return
            }
            let _ = (legacyAssetPickerEnqueueMessages(context: component.context, account: component.context.account, signals: signals)
            |> deliverOnMainQueue).start()
        }
        
        private func updatePreloads() {
            var validIds: [AnyHashable] = []
            if let currentSlice = self.currentSlice, let focusedItemId = self.focusedItemId, let currentIndex = currentSlice.items.firstIndex(where: { $0.id == focusedItemId }) {
                for i in 0 ..< 2 {
                    var nextIndex: Int = currentIndex - 1 - i
                    nextIndex = max(0, min(nextIndex, currentSlice.items.count - 1))
                    if nextIndex != currentIndex {
                        let nextItem = currentSlice.items[nextIndex]
                        
                        validIds.append(nextItem.id)
                        if self.preloadContexts[nextItem.id] == nil {
                            if let signal = nextItem.preload {
                                self.preloadContexts[nextItem.id] = signal.start()
                            }
                        }
                    }
                }
            }
            
            var removeIds: [AnyHashable] = []
            for (id, disposable) in self.preloadContexts {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    disposable.dispose()
                }
            }
            for id in removeIds {
                self.preloadContexts.removeValue(forKey: id)
            }
        }
        
        func update(component: StoryContainerScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
            let isFirstTime = self.component == nil
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            
            if self.component == nil {
                self.focusedItemId = component.initialContent.focusedItemId
                self.currentSlice = component.initialContent
                
                self.currentSliceDisposable?.dispose()
                self.currentSliceDisposable = (component.initialContent.update(
                    component.initialContent,
                    component.initialContent.focusedItemId
                )
                |> deliverOnMainQueue).start(next: { [weak self] contentSlice in
                    guard let self else {
                        return
                    }
                    self.currentSlice = contentSlice
                    self.state?.updated(transition: .immediate)
                })
            }
            
            if self.topContentGradientLayer.colors == nil {
                var locations: [NSNumber] = []
                var colors: [CGColor] = []
                let numStops = 4
                let baseAlpha: CGFloat = 0.5
                for i in 0 ..< numStops {
                    let step = 1.0 - CGFloat(i) / CGFloat(numStops - 1)
                    locations.append((1.0 - step) as NSNumber)
                    let alphaStep: CGFloat = pow(step, 1.5)
                    colors.append(UIColor.black.withAlphaComponent(alphaStep * baseAlpha).cgColor)
                }
                
                self.topContentGradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
                self.topContentGradientLayer.endPoint = CGPoint(x: 0.0, y: 1.0)
                
                self.topContentGradientLayer.locations = locations
                self.topContentGradientLayer.colors = colors
                self.topContentGradientLayer.type = .axial
            }
            if self.bottomContentGradientLayer.colors == nil {
                var locations: [NSNumber] = []
                var colors: [CGColor] = []
                let numStops = 10
                let baseAlpha: CGFloat = 0.7
                for i in 0 ..< numStops {
                    let step = 1.0 - CGFloat(i) / CGFloat(numStops - 1)
                    locations.append((1.0 - step) as NSNumber)
                    let alphaStep: CGFloat = pow(step, 1.5)
                    colors.append(UIColor.black.withAlphaComponent(alphaStep * baseAlpha).cgColor)
                }
                
                self.bottomContentGradientLayer.startPoint = CGPoint(x: 0.0, y: 1.0)
                self.bottomContentGradientLayer.endPoint = CGPoint(x: 0.0, y: 0.0)
                
                self.bottomContentGradientLayer.locations = locations
                self.bottomContentGradientLayer.colors = colors
                self.bottomContentGradientLayer.type = .axial
                
                self.contentDimLayer.backgroundColor = UIColor(white: 0.0, alpha: 0.3).cgColor
            }
            
            if let focusedItemId = self.focusedItemId {
                if let currentSlice = self.currentSlice {
                    if !currentSlice.items.contains(where: { $0.id == focusedItemId }) {
                        self.focusedItemId = currentSlice.items.first?.id
                    }
                } else {
                    self.focusedItemId = nil
                }
            }
            
            self.updatePreloads()
            
            self.component = component
            self.state = state
            self.environment = environment
            
            var bottomContentInset: CGFloat
            if !environment.safeInsets.bottom.isZero {
                bottomContentInset = environment.safeInsets.bottom + 5.0
            } else {
                bottomContentInset = 0.0
            }
            
            self.inputPanel.parentState = state
            let inputPanelSize = self.inputPanel.update(
                transition: transition,
                component: AnyComponent(MessageInputPanelComponent(
                    externalState: self.inputPanelExternalState,
                    sendMessageAction: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.performSendMessageAction()
                    },
                    attachmentAction: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.presentAttachmentMenu(subject: .default)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 200.0)
            )
            
            let footerPanelSize = self.footerPanel.update(
                transition: transition,
                component: AnyComponent(StoryFooterPanelComponent(
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 200.0)
            )
            
            let bottomContentInsetWithoutInput = bottomContentInset
            
            let inputPanelBottomInset: CGFloat
            let inputPanelIsOverlay: Bool
            if environment.inputHeight < bottomContentInset + inputPanelSize.height {
                inputPanelBottomInset = bottomContentInset
                bottomContentInset += inputPanelSize.height
                inputPanelIsOverlay = false
            } else {
                bottomContentInset += 44.0
                inputPanelBottomInset = environment.inputHeight
                inputPanelIsOverlay = true
            }
            
            let contentFrame = CGRect(origin: CGPoint(x: 0.0, y: environment.statusBarHeight), size: CGSize(width: availableSize.width, height: availableSize.height - environment.statusBarHeight - bottomContentInset))
            transition.setFrame(view: self.contentContainerView, frame: contentFrame)
            transition.setCornerRadius(layer: self.contentContainerView.layer, cornerRadius: 14.0)
            
            if self.closeButtonIconView.image == nil {
                self.closeButtonIconView.image = UIImage(bundleImageName: "Media Gallery/Close")?.withRenderingMode(.alwaysTemplate)
                self.closeButtonIconView.tintColor = .white
            }
            if let image = self.closeButtonIconView.image {
                let closeButtonFrame = CGRect(origin: CGPoint(x: contentFrame.minX, y: contentFrame.minY), size: CGSize(width: 50.0, height: 64.0))
                transition.setFrame(view: self.closeButton, frame: closeButtonFrame)
                transition.setFrame(view: self.closeButtonIconView, frame: CGRect(origin: CGPoint(x: floor((closeButtonFrame.width - image.size.width) * 0.5), y: floor((closeButtonFrame.height - image.size.height) * 0.5)), size: image.size))
            }
            
            var focusedItem: StoryContentItem?
            if let currentSlice = self.currentSlice, let item = currentSlice.items.first(where: { $0.id == self.focusedItemId }) {
                focusedItem = item
            }
            
            var currentRightInfoItem: InfoItem?
            if let currentSlice = self.currentSlice, let item = currentSlice.items.first(where: { $0.id == self.focusedItemId }) {
                if let rightInfoComponent = item.rightInfoComponent {
                    if let rightInfoItem = self.rightInfoItem, rightInfoItem.component == item.rightInfoComponent {
                        currentRightInfoItem = rightInfoItem
                    } else {
                        currentRightInfoItem = InfoItem(component: rightInfoComponent)
                    }
                }
            }
            
            if let rightInfoItem = self.rightInfoItem, currentRightInfoItem?.component != rightInfoItem.component {
                self.rightInfoItem = nil
                if let view = rightInfoItem.view.view {
                    view.layer.animateScale(from: 1.0, to: 0.5, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                    view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak view] _ in
                        view?.removeFromSuperview()
                    })
                }
            }
            
            var currentCenterInfoItem: InfoItem?
            if let currentSlice = self.currentSlice, let item = currentSlice.items.first(where: { $0.id == self.focusedItemId }) {
                if let centerInfoComponent = item.centerInfoComponent {
                    if let centerInfoItem = self.centerInfoItem, centerInfoItem.component == item.centerInfoComponent {
                        currentCenterInfoItem = centerInfoItem
                    } else {
                        currentCenterInfoItem = InfoItem(component: centerInfoComponent)
                    }
                }
            }
            
            if let centerInfoItem = self.centerInfoItem, currentCenterInfoItem?.component != centerInfoItem.component {
                self.centerInfoItem = nil
                if let view = centerInfoItem.view.view {
                    view.removeFromSuperview()
                    /*view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak view] _ in
                        view?.removeFromSuperview()
                    })*/
                }
            }
            
            if let currentRightInfoItem {
                self.rightInfoItem = currentRightInfoItem
                
                let rightInfoItemSize = currentRightInfoItem.view.update(
                    transition: .immediate,
                    component: currentRightInfoItem.component,
                    environment: {},
                    containerSize: CGSize(width: 36.0, height: 36.0)
                )
                if let view = currentRightInfoItem.view.view {
                    var animateIn = false
                    if view.superview == nil {
                        self.addSubview(view)
                        animateIn = true
                    }
                    transition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: contentFrame.maxX - 6.0 - rightInfoItemSize.width, y: contentFrame.minY + 14.0), size: rightInfoItemSize))
                    
                    if animateIn, !isFirstTime {
                        view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        view.layer.animateScale(from: 0.5, to: 1.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                    }
                }
            }
            
            if let currentCenterInfoItem {
                self.centerInfoItem = currentCenterInfoItem
                
                let centerInfoItemSize = currentCenterInfoItem.view.update(
                    transition: .immediate,
                    component: currentCenterInfoItem.component,
                    environment: {},
                    containerSize: CGSize(width: contentFrame.width, height: 44.0)
                )
                if let view = currentCenterInfoItem.view.view {
                    var animateIn = false
                    if view.superview == nil {
                        view.isUserInteractionEnabled = false
                        self.addSubview(view)
                        animateIn = true
                    }
                    transition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: contentFrame.minX, y: contentFrame.minY + 10.0), size: centerInfoItemSize))
                    
                    if animateIn, !isFirstTime {
                        //view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                }
            }
            
            if let currentSlice = self.currentSlice, let focusedItemId = self.focusedItemId, let visibleItem = self.visibleItems[focusedItemId] {
                let navigationStripSideInset: CGFloat = 8.0
                let navigationStripTopInset: CGFloat = 8.0
                
                let index = currentSlice.items.first(where: { $0.id == self.focusedItemId })?.position ?? 0
                
                let _ = self.navigationStrip.update(
                    transition: transition,
                    component: AnyComponent(MediaNavigationStripComponent(
                        index: max(0, min(currentSlice.totalCount - 1 - index, currentSlice.totalCount - 1)),
                        count: currentSlice.totalCount
                    )),
                    environment: {
                        MediaNavigationStripComponent.EnvironmentType(
                            currentProgress: visibleItem.currentProgress
                        )
                    },
                    containerSize: CGSize(width: availableSize.width - navigationStripSideInset * 2.0, height: 2.0)
                )
                if let navigationStripView = self.navigationStrip.view {
                    if navigationStripView.superview == nil {
                        self.addSubview(navigationStripView)
                    }
                    transition.setFrame(view: navigationStripView, frame: CGRect(origin: CGPoint(x: contentFrame.minX + navigationStripSideInset, y: contentFrame.minY + navigationStripTopInset), size: CGSize(width: availableSize.width - navigationStripSideInset * 2.0, height: 2.0)))
                }
                
                if let focusedItemId = self.focusedItemId, let focusedItem = self.currentSlice?.items.first(where: { $0.id == focusedItemId }) {
                    var items: [StoryActionsComponent.Item] = []
                    if !focusedItem.isMy {
                        items.append(StoryActionsComponent.Item(
                            kind: .like,
                            isActivated: focusedItem.hasLike
                        ))
                    }
                    items.append(StoryActionsComponent.Item(
                        kind: .share,
                        isActivated: false
                    ))
                    
                    let inlineActionsSize = self.inlineActions.update(
                        transition: transition,
                        component: AnyComponent(StoryActionsComponent(
                            items: items,
                            action: { [weak self] item in
                                guard let self else {
                                    return
                                }
                                self.performInlineAction(item: item)
                            }
                        )),
                        environment: {},
                        containerSize: contentFrame.size
                    )
                    if let inlineActionsView = self.inlineActions.view {
                        if inlineActionsView.superview == nil {
                            self.addSubview(inlineActionsView)
                        }
                        transition.setFrame(view: inlineActionsView, frame: CGRect(origin: CGPoint(x: contentFrame.maxX - 10.0 - inlineActionsSize.width, y: contentFrame.maxY - 20.0 - inlineActionsSize.height), size: inlineActionsSize))
                        transition.setAlpha(view: inlineActionsView, alpha: inputPanelIsOverlay ? 0.0 : 1.0)
                    }
                }
            }
            
            let gradientHeight: CGFloat = 74.0
            transition.setFrame(layer: self.topContentGradientLayer, frame: CGRect(origin: CGPoint(x: contentFrame.minX, y: contentFrame.minY), size: CGSize(width: contentFrame.width, height: gradientHeight)))
            
            let itemLayout = ItemLayout(size: CGSize(width: contentFrame.width, height: availableSize.height - environment.statusBarHeight - 44.0 - bottomContentInsetWithoutInput))
            self.itemLayout = itemLayout
            
            let inputPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - inputPanelBottomInset - inputPanelSize.height), size: inputPanelSize)
            if let inputPanelView = self.inputPanel.view {
                if inputPanelView.superview == nil {
                    self.addSubview(inputPanelView)
                }
                transition.setFrame(view: inputPanelView, frame: inputPanelFrame)
                transition.setAlpha(view: inputPanelView, alpha: focusedItem?.isMy == true ? 0.0 : 1.0)
            }
            
            let footerPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - inputPanelBottomInset - footerPanelSize.height), size: footerPanelSize)
            if let footerPanelView = self.footerPanel.view {
                if footerPanelView.superview == nil {
                    self.addSubview(footerPanelView)
                }
                transition.setFrame(view: footerPanelView, frame: footerPanelFrame)
                transition.setAlpha(view: footerPanelView, alpha: focusedItem?.isMy == true ? 1.0 : 0.0)
            }
            
            let bottomGradientHeight = inputPanelSize.height + 32.0
            transition.setFrame(layer: self.bottomContentGradientLayer, frame: CGRect(origin: CGPoint(x: contentFrame.minX, y: availableSize.height - environment.inputHeight - bottomGradientHeight), size: CGSize(width: contentFrame.width, height: bottomGradientHeight)))
            transition.setAlpha(layer: self.bottomContentGradientLayer, alpha: inputPanelIsOverlay ? 1.0 : 0.0)
            
            if let controller = environment.controller() {
                let subLayout = ContainerViewLayout(
                    size: availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: availableSize.height - min(inputPanelFrame.minY, contentFrame.maxY), right: 0.0),
                    safeInsets: UIEdgeInsets(),
                    additionalInsets: UIEdgeInsets(),
                    statusBarHeight: nil,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(subLayout, transition: transition.containedViewLayoutTransition)
            }
            
            transition.setFrame(layer: self.contentDimLayer, frame: contentFrame)
            transition.setAlpha(layer: self.contentDimLayer, alpha: inputPanelIsOverlay ? 1.0 : 0.0)
            
            self.ignoreScrolling = true
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: availableSize.height)))
            let contentSize = availableSize
            if contentSize != self.scrollView.contentSize {
                self.scrollView.contentSize = contentSize
            }
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class StoryContainerScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    private var isDismissed: Bool = false
    
    public init(
        context: AccountContext,
        initialContent: StoryContentItemSlice
    ) {
        self.context = context
        
        super.init(context: context, component: StoryContainerScreenComponent(
            context: context,
            initialContent: initialContent
        ), navigationBarAppearance: .none)
        
        self.statusBar.statusBarStyle = .White
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
        self.automaticallyControlPresentationContextLayout = false
        
        self.context.sharedContext.hasPreloadBlockingContent.set(.single(true))
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.context.sharedContext.hasPreloadBlockingContent.set(.single(false))
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.view.disablesInteractiveModalDismiss = true
        
        if let componentView = self.node.hostView.componentView as? StoryContainerScreenComponent.View {
            componentView.animateIn()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            
            self.statusBar.updateStatusBarStyle(.Ignore, animated: true)
            
            if let componentView = self.node.hostView.componentView as? StoryContainerScreenComponent.View {
                componentView.endEditing(true)
                
                componentView.animateOut(completion: { [weak self] in
                    completion?()
                    self?.dismiss(animated: false)
                })
            } else {
                self.dismiss(animated: false)
            }
        }
    }
}
