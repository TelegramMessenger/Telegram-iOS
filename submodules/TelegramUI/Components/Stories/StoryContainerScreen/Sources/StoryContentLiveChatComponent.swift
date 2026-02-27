import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import AccountContext
import Postbox
import TelegramCore
import TelegramPresentationData
import SwiftSignalKit
import TelegramCallsUI
import AsyncListComponent
import AvatarNode
import MultilineTextWithEntitiesComponent
import GlassBackgroundComponent
import MultilineTextComponent
import ContextUI
import StarsParticleEffect
import StoryLiveChatMessageComponent
import AdminUserActionsSheet

final class StoryContentLiveChatComponent: Component {
    final class External {
        fileprivate(set) var isEmpty: Bool = false
        fileprivate(set) var hasUnseenMessages: Bool = false
        
        init() {
        }
    }
    
    let external: External
    let context: AccountContext
    let strings: PresentationStrings
    let theme: PresentationTheme
    let call: PresentationGroupCall
    let storyPeerId: EnginePeer.Id
    let canManageMessagesFromPeers: Set<EnginePeer.Id>
    let insets: UIEdgeInsets
    let isEmbeddedInCamera: Bool
    let minPaidStars: Int?
    let controller: () -> ViewController?
    
    init(
        external: External,
        context: AccountContext,
        strings: PresentationStrings,
        theme: PresentationTheme,
        call: PresentationGroupCall,
        storyPeerId: EnginePeer.Id,
        canManageMessagesFromPeers: Set<EnginePeer.Id>,
        insets: UIEdgeInsets,
        isEmbeddedInCamera: Bool,
        minPaidStars: Int?,
        controller: @escaping () -> ViewController?
    ) {
        self.external = external
        self.context = context
        self.strings = strings
        self.theme = theme
        self.call = call
        self.storyPeerId = storyPeerId
        self.canManageMessagesFromPeers = canManageMessagesFromPeers
        self.insets = insets
        self.isEmbeddedInCamera = isEmbeddedInCamera
        self.minPaidStars = minPaidStars
        self.controller = controller
    }

    static func ==(lhs: StoryContentLiveChatComponent, rhs: StoryContentLiveChatComponent) -> Bool {
        if lhs.external !== rhs.external {
            return false
        }
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.call !== rhs.call {
            return false
        }
        if lhs.storyPeerId != rhs.storyPeerId {
            return false
        }
        if lhs.canManageMessagesFromPeers != rhs.canManageMessagesFromPeers {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        if lhs.isEmbeddedInCamera != rhs.isEmbeddedInCamera {
            return false
        }
        if lhs.minPaidStars != rhs.minPaidStars {
            return false
        }
        return true
    }
    
    struct StarStats {
        var myStars: Int64
        var pendingMyStars: Int64
        var totalStars: Int64
        var topItems: [GroupCallMessagesContext.TopStarsItem]
        
        init(myStars: Int64, pendingMyStars: Int64, totalStars: Int64, topItems: [GroupCallMessagesContext.TopStarsItem]) {
            self.myStars = myStars
            self.pendingMyStars = pendingMyStars
            self.totalStars = totalStars
            self.topItems = topItems
        }
    }
    
    struct Info {
        var starStats: StarStats?
        var isChatEmpty: Bool
        var isChatExpanded: Bool
        
        init(starStats: StarStats?, isChatEmpty: Bool, isChatExpanded: Bool) {
            self.starStats = starStats
            self.isChatEmpty = isChatEmpty
            self.isChatExpanded = isChatExpanded
        }
    }

    final class View: UIView {
        private let listContainer: UIView
        private let listMaskContainer: UIView
        private let maskGradientView: UIImageView

        private let pinnedBar = ComponentView<Empty>()
        
        private let listState = AsyncListComponent.ExternalState()
        private var isScrollToBottomScheduled: Bool = false
        private let list = ComponentView<Empty>()
        private let listShadowView: UIView
        
        private var reactionStreamView: LiveChatReactionStreamView?

        private var component: StoryContentLiveChatComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        private var messagesState: GroupCallMessagesContext.State?
        private var stateDisposable: Disposable?
        
        private var currentListIsEmpty: Bool = true
        private var isMessageContextMenuOpen: Bool = false
        
        private var isChatExpanded: Bool = false
        
        public var currentInfo: Info {
            var starStats: StoryContentLiveChatComponent.StarStats?
            var isChatEmpty = true
            if let messagesState = self.messagesState {
                isChatEmpty = messagesState.messages.isEmpty
                
                var myStars: Int64 = 0
                if let item = messagesState.topStars.first(where: { $0.isMy }) {
                    myStars = item.amount
                }
                starStats = StoryContentLiveChatComponent.StarStats(myStars: myStars + messagesState.pendingMyStars, pendingMyStars: messagesState.pendingMyStars, totalStars: messagesState.totalStars + messagesState.pendingMyStars, topItems: messagesState.topStars)
            }
            
            return Info(
                starStats: starStats,
                isChatEmpty: isChatEmpty,
                isChatExpanded: self.isChatExpanded
            )
        }
        
        override init(frame: CGRect) {
            self.listContainer = UIView()

            self.listMaskContainer = UIView()
            self.listContainer.mask = self.listMaskContainer

            self.maskGradientView = UIImageView()
            do {
                let height: CGFloat = 40.0
                let baseGradientAlpha: CGFloat = 1.0
                let numSteps = 8
                let firstStep = 0
                let firstLocation = 0.0
                let colors = (0 ..< numSteps).map { i -> UIColor in
                    if i < firstStep {
                        return UIColor(white: 1.0, alpha: 1.0)
                    } else {
                        let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                        let value: CGFloat = 1.0 - bezierPoint(0.42, 0.0, 0.58, 1.0, step)
                        return UIColor(white: 1.0, alpha: baseGradientAlpha * value)
                    }
                }
                let locations = (0 ..< numSteps).map { i -> CGFloat in
                    if i < firstStep {
                        return 0.0
                    } else {
                        let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                        return (firstLocation + (1.0 - firstLocation) * step)
                    }
                }
                
                let image = generateGradientImage(size: CGSize(width: 8.0, height: height), colors: colors.reversed(), locations: locations.reversed().map { 1.0 - $0 })!
                self.maskGradientView.image = generateImage(CGSize(width: image.size.width, height: image.size.height * 2.0), rotatedContext: { size, context in
                    UIGraphicsPushContext(context)
                    defer {
                        UIGraphicsPopContext()
                    }
                    
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    
                    image.draw(in: CGRect(origin: CGPoint(), size: image.size))
                    
                    let bottomFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height - image.size.height), size: image.size)
                    context.translateBy(x: bottomFrame.midX, y: bottomFrame.midY)
                    context.scaleBy(x: 1.0, y: -1.0)
                    context.translateBy(x: -bottomFrame.midX, y: -bottomFrame.midY)
                    
                    image.draw(in: bottomFrame)
                })!.stretchableImage(withLeftCapWidth: 0, topCapHeight: Int(height - 1.0))
            }
            self.listMaskContainer.addSubview(self.maskGradientView)
            
            self.listShadowView = UIView()
            self.listShadowView.isUserInteractionEnabled = false

            super.init(frame: frame)
            
            self.addSubview(self.listShadowView)
            self.addSubview(self.listContainer)
            
            self.isChatExpanded = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.stateDisposable?.dispose()
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            
            guard let result = super.hitTest(point, with: event) else {
                return nil
            }
            
            if let listView = self.list.view as? AsyncListComponent.View, result.isDescendant(of: listView), let listComponent = listView.component {
                let localPoint = self.convert(point, to: listView)
                if localPoint.y > listView.bounds.height - listComponent.insets.bottom {
                    return nil
                }
                if let visibleItems = listView.visibleItems() {
                    var maxItemY: CGFloat?
                    for visibleItem in visibleItems {
                        if let maxItemYValue = maxItemY {
                            maxItemY = max(maxItemYValue, visibleItem.frame.maxY)
                        } else {
                            maxItemY = visibleItem.frame.maxY
                        }
                    }
                    if let maxItemY {
                        if self.convert(point, to: listView).y >= maxItemY {
                            return nil
                        }
                    } else {
                        return nil
                    }
                } else {
                    return nil
                }
            }
            
            if let component = self.component, component.isEmbeddedInCamera && result === self.listContainer {
                return nil
            }
            
            return result
        }
        
        func toggleLiveChatExpanded() {
            guard let component = self.component else {
                return
            }
            self.isChatExpanded = !self.isChatExpanded
            if self.isChatExpanded {
                component.external.hasUnseenMessages = false
            }
            self.state?.updated(transition: .spring(duration: 0.4))
        }
        
        private func displayDeleteMessageConfirmation(id: GroupCallMessagesContext.Message.Id) {
            guard let component = self.component else {
                return
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
            let actionSheet = ActionSheetController(presentationData: presentationData)
            
            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: component.strings.Chat_DeleteMessagesConfirmation(1), color: .destructive, action: { [weak self, weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        
                        guard let self, let component = self.component, let call = component.call as? PresentationGroupCallImpl else {
                            return
                        }
                        call.deleteMessage(id: id, reportSpam: false)
                    })
                ]),
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])
            ])
            
            component.controller()?.view.endEditing(true)
            component.controller()?.present(actionSheet, in: .window(.root))
        }
        
        private func displayDeleteMessageAndBan(id: GroupCallMessagesContext.Message.Id) {
            Task { @MainActor [weak self] in
                guard let self, let component = self.component else {
                    return
                }
                guard let chatPeer = await component.context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: component.storyPeerId)
                ).get() else {
                    return
                }
                guard let messagesState = self.messagesState, let message = messagesState.messages.first(where: { $0.id == id }) else {
                    return
                }
                if message.isFromAdmin {
                    self.displayDeleteMessageConfirmation(id: id)
                    return
                }
                guard let author = message.author else {
                    return
                }
                var totalCount = 0
                for message in messagesState.messages {
                    if message.author?.id == author.id {
                        totalCount += 1
                    }
                }
                guard let controller = component.controller() else {
                    return
                }
                controller.push(AdminUserActionsSheet(
                    context: component.context,
                    chatPeer: chatPeer,
                    peers: [RenderedChannelParticipant(
                        participant: .member(
                            id: author.id,
                            invitedAt: 0,
                            adminInfo: nil,
                            banInfo: nil,
                            rank: nil,
                            subscriptionUntilDate: nil
                        ),
                        peer: author._asPeer()
                    )],
                    mode: .liveStream(
                        messageCount: 1,
                        deleteAllMessageCount: totalCount,
                        completion: { [weak self] result in
                            guard let self, let component = self.component, let call = component.call as? PresentationGroupCallImpl else {
                                return
                            }
                            
                            if result.deleteAll {
                                call.deleteAllMessages(authorId: author.id, reportSpam: result.reportSpam)
                            } else {
                                call.deleteMessage(id: id, reportSpam: result.reportSpam)
                            }
                            
                            if result.ban {
                                if component.storyPeerId == component.context.account.peerId {
                                    let _ = component.context.engine.privacy.requestUpdatePeerIsBlocked(peerId: author.id, isBlocked: true).startStandalone()
                                } else {
                                    let _ = component.context.engine.peers.updateChannelMemberBannedRights(peerId: component.storyPeerId, memberId: author.id, rights: TelegramChatBannedRights(flags: .banReadMessages, untilDate: Int32.max)).startStandalone()
                                }
                            }
                        }
                    ),
                    customTheme: defaultDarkColorPresentationTheme
                ))
            }
        }
        
        @discardableResult private func scrollToMessage(id: GroupCallMessagesContext.Message.Id, highlight: Bool) -> Bool {
            guard let messagesState = self.messagesState, let message = messagesState.messages.first(where: { $0.id == id }) else {
                return false
            }
            self.listState.resetScrolling(id: AnyHashable(message.stableId))
            self.state?.updated(transition: .spring(duration: 0.4), isLocal: true)
            
            if highlight {
                if let listView = self.list.view as? AsyncListComponent.View, let itemView = listView.visibleItemView(id: AnyHashable(message.stableId)) as? StoryLiveChatMessageComponent.View {
                    itemView.flashHighlight()
                }
            }
            
            return true
        }
        
        private func openMessageContextMenu(id: GroupCallMessagesContext.Message.Id, isPinned: Bool, gesture: ContextGesture, sourceNode: ContextExtractedContentContainingNode) {
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                guard let component = self.component else {
                    return
                }
                let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
                
                if let listView = self.list.view as? AsyncListComponent.View {
                    listView.stopScrolling()
                }
                
                var items: [ContextMenuItem] = []
                if !isPinned, let messagesState = self.messagesState, let message = messagesState.messages.first(where: { $0.id == id }), !message.text.isEmpty {
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_ContextMenuCopy, textColor: .primary, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                        guard let self else {
                            return
                        }
                        
                        c?.dismiss(completion: { [weak self] in
                            guard let self else {
                                return
                            }
                            if let messagesState = self.messagesState, let message = messagesState.messages.first(where: { $0.id == id }) {
                                UIPasteboard.general.string = message.text
                            }
                        })
                    })))
                }
                
                let state = await (component.call.state |> take(1)).get()
                
                var isAdmin = false
                isAdmin = state.canManageCall
                var canDelete = isAdmin
                var isMyMessage = false
                guard let messagesState = self.messagesState, let message = messagesState.messages.first(where: { $0.id == id }) else {
                    return
                }
                if message.author?.id == component.context.account.peerId {
                    isMyMessage = true
                    canDelete = true
                }
                if let author = message.author, component.canManageMessagesFromPeers.contains(author.id) {
                    isMyMessage = true
                    canDelete = true
                }
                var isMessageFromAdmin = false
                if message.isFromAdmin {
                    isMessageFromAdmin = true
                } else if message.author?.id == component.storyPeerId {
                    isMessageFromAdmin = true
                }
                
                if !isMyMessage, let author = message.author {
                    let openProfileString: String
                    if case .channel = author {
                        openProfileString = presentationData.strings.Conversation_ContextMenuOpenChannel
                    } else {
                        openProfileString = presentationData.strings.Conversation_ContextMenuOpenProfile
                    }
                    items.append(.action(ContextMenuActionItem(text: openProfileString, textColor: .primary, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/User"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                        guard let self else {
                            return
                        }
                        
                        c?.dismiss(completion: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            guard let controller = component.controller(), let navigationController = controller.navigationController as? NavigationController else {
                                return
                            }
                            component.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                                navigationController: navigationController,
                                context: component.context,
                                chatLocation: .peer(author),
                                keepStack: .always
                            ))
                        })
                    })))
                }
                
                if canDelete {
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.ChatList_Context_Delete, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { [weak self] c, _ in
                        guard let self else {
                            return
                        }
                        
                        c?.dismiss(completion: { [weak self] in
                            guard let self else {
                                return
                            }
                            if isAdmin && !isMyMessage && !isMessageFromAdmin {
                                self.displayDeleteMessageAndBan(id: id)
                            } else {
                                self.displayDeleteMessageConfirmation(id: id)
                            }
                        })
                    })))
                }
                
                let contextController = makeContextController(
                    presentationData: presentationData,
                    source: .extracted(ItemExtractedContentSource(
                        sourceNode: sourceNode,
                        containerView: self,
                        keepInPlace: false
                    )),
                    items: .single(ContextController.Items(content: .list(items))),
                    recognizer: nil,
                    gesture: gesture
                )
                contextController.dismissed = { [weak self] in
                    guard let self else {
                        return
                    }
                    self.isMessageContextMenuOpen = false
                    if !self.isUpdating {
                        self.state?.updated(transition: .easeInOut(duration: 0.2), isLocal: true)
                    }
                }
                
                self.isMessageContextMenuOpen = true
                if !self.isUpdating {
                    self.state?.updated(transition: .easeInOut(duration: 0.2), isLocal: true)
                }
                
                component.controller()?.presentInGlobalOverlay(contextController)
            }
        }
        
        func scheduleScrollLiveChatToBottom() {
            self.isScrollToBottomScheduled = true
        }
        
        func update(component: StoryContentLiveChatComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.2)

            if self.component?.call !== component.call {
                self.stateDisposable?.dispose()
                if let call = component.call as? PresentationGroupCallImpl {
                    self.stateDisposable = (call.messagesState
                    |> deliverOnMainQueue).startStrict(next: { [weak self] state in
                        guard let self else {
                            return
                        }
                        var updateTransition: ComponentTransition = .easeInOut(duration: 0.2)
                        if self.messagesState == nil {
                            updateTransition = .immediate
                        }
                        
                        if let component = self.component, let previousMessagesState = self.messagesState {
                            if !self.isChatExpanded {
                                var hasNewMessages = false
                                for message in state.messages {
                                    if message.isIncoming {
                                        if !previousMessagesState.messages.contains(where: { $0.id == message.id }) {
                                            hasNewMessages = true
                                        }
                                        
                                        if let paidStars = message.paidStars, let author = message.author {
                                            self.reactionStreamView?.add(peer: author, count: Int(paidStars))
                                        }
                                    }
                                }
                                if hasNewMessages {
                                    component.external.hasUnseenMessages = true
                                }
                            }
                            
                            for message in state.messages {
                                if message.isIncoming {
                                    if !previousMessagesState.messages.contains(where: { $0.id == message.id }) {
                                        if let paidStars = message.paidStars, let author = message.author {
                                            self.reactionStreamView?.add(peer: author, count: Int(paidStars))
                                        }
                                    }
                                }
                            }
                            
                            if state.pendingMyStars > previousMessagesState.pendingMyStars, let message = state.messages.first(where: { $0.paidStars != nil && !$0.isIncoming }), let peer = message.author {
                                self.reactionStreamView?.add(peer: peer, count: Int(state.pendingMyStars - previousMessagesState.pendingMyStars))
                            }
                        }
                        component.external.isEmpty = state.messages.isEmpty
                        self.messagesState = state
                        
                        if !self.isUpdating {
                            self.state?.updated(transition: updateTransition)
                        }
                    })
                }
            }
            
            self.component = component
            self.state = state
            
            if self.isChatExpanded {
                component.external.hasUnseenMessages = false
            }
            
            let previousListIsEmpty = self.currentListIsEmpty
            
            var listItems: [AnyComponentWithIdentity<Empty>] = []
            var topMessageByPeerId: [EnginePeer.Id: GroupCallMessagesContext.Message] = [:]
            if let messagesState = self.messagesState {
                for message in messagesState.messages.reversed() {
                    let messageId = message.id
                    var topPlace = self.messagesState?.topStars.firstIndex(where: { $0.peerId != nil && $0.peerId == message.author?.id })
                    if let topPlaceValue = topPlace, topPlaceValue >= 3 {
                        topPlace = nil
                    }
                    listItems.append(AnyComponentWithIdentity(id: message.stableId, component: AnyComponent(StoryLiveChatMessageComponent(
                        context: component.context,
                        strings: component.strings,
                        theme: component.theme,
                        layout: StoryLiveChatMessageComponent.Layout(
                            isFlipped: true,
                            insets: UIEdgeInsets(top: 9.0, left: 24.0, bottom: 9.0, right: 20.0),
                            fitToWidth: false,
                            transparentBackground: true
                        ),
                        message: message,
                        topPlace: topPlace,
                        contextGesture: { [weak self] gesture, sourceNode in
                            guard let self else {
                                return
                            }
                            self.openMessageContextMenu(id: messageId, isPinned: false, gesture: gesture, sourceNode: sourceNode)
                        }
                    ))))
                }
                
                for message in messagesState.pinnedMessages.reversed() {
                    if let author = message.author, let paidStars = message.paidStars {
                        if let minPaidStars = component.minPaidStars {
                            if Int(paidStars) < minPaidStars {
                                continue
                            }
                        }
                        
                        if let current = topMessageByPeerId[author.id] {
                            if let currentPaidStars = current.paidStars, currentPaidStars < paidStars {
                                topMessageByPeerId[author.id] = message
                            }
                        } else {
                            topMessageByPeerId[author.id] = message
                        }
                    }
                }
            }
            let topMessages: [GroupCallMessagesContext.Message] = topMessageByPeerId.values.sorted(by: { lhs, rhs in
                let lhsValue = lhs.paidStars ?? 0
                let rhsValue = rhs.paidStars ?? 0
                if lhsValue != rhsValue {
                    return lhsValue > rhsValue
                }
                return lhs.date > rhs.date
            })
            
            var topIndices: [EnginePeer.Id: Int] = [:]
            if let messagesState = self.messagesState {
                for topMessage in topMessages {
                    if let author = topMessage.author, topIndices[author.id] == nil {
                        if let index = messagesState.topStars.firstIndex(where: { $0.peerId != nil && $0.peerId == author.id }), index < 3 {
                            topIndices[author.id] = index
                        }
                    }
                }
            }
            
            self.currentListIsEmpty = listItems.isEmpty
            
            let pinnedBarSize = self.pinnedBar.update(
                transition: transition,
                component: AnyComponent(PinnedBarComponent(
                    context: component.context,
                    strings: component.strings,
                    theme: component.theme,
                    isExpanded: self.isChatExpanded,
                    messages: topMessages,
                    topIndices: topIndices,
                    action: { [weak self] message in
                        guard let self else {
                            return
                        }
                        self.isChatExpanded = true
                        if !self.scrollToMessage(id: message.id, highlight: true) {
                            if !self.isUpdating {
                                self.state?.updated(transition: .spring(duration: 0.4))
                            }
                        }
                    },
                    contextGesture: { [weak self] message, gesture, sourceNode in
                        guard let self else {
                            return
                        }
                        self.openMessageContextMenu(id: message.id, isPinned: true, gesture: gesture, sourceNode: sourceNode)
                    }
                )),
                environment: {},
                containerSize: availableSize
            )
            let pinnedBarFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - component.insets.bottom - pinnedBarSize.height - 4.0), size: pinnedBarSize)
            if let pinnedBarView = self.pinnedBar.view {
                if pinnedBarView.superview == nil {
                    self.addSubview(pinnedBarView)
                }
                transition.setFrame(view: pinnedBarView, frame: pinnedBarFrame)
                
                let pinnedBarAlpha: CGFloat
                if self.isMessageContextMenuOpen {
                    pinnedBarAlpha = 0.25
                } else {
                    pinnedBarAlpha = topMessages.isEmpty ? 0.0 : 1.0
                }
                transition.setAlpha(view: pinnedBarView, alpha: pinnedBarAlpha)
            }
            
            var listInsets = UIEdgeInsets(top: component.insets.bottom + 12.0, left: component.insets.right, bottom: component.insets.top + 8.0, right: component.insets.left)
            if component.insets.bottom == 0.0 {
                listInsets.bottom = floor(availableSize.height * 0.5)
            }
            if !topMessages.isEmpty {
                listInsets.top = availableSize.height - pinnedBarFrame.minY
            }
            listInsets.top += 1.0
            
            var listTransition = transition
            if previousListIsEmpty != self.currentListIsEmpty {
                listTransition = listTransition.withAnimation(.none)
            }
            
            if self.isScrollToBottomScheduled {
                self.isScrollToBottomScheduled = false
                if let firstItem = listItems.first {
                    self.listState.resetScrolling(id: firstItem.id)
                }
            }
            
            let _ = self.list.update(
                transition: listTransition,
                component: AnyComponent(AsyncListComponent(
                    externalState: self.listState,
                    items: listItems,
                    itemSetId: AnyHashable(0),
                    direction: .vertical,
                    insets: listInsets
                )),
                environment: {},
                containerSize: availableSize
            )
            let listFrame = CGRect(origin: CGPoint(), size: availableSize)
            if let listView = self.list.view as? AsyncListComponent.View {
                if listView.superview == nil {
                    listView.transform = CGAffineTransformMakeRotation(CGFloat.pi)
                    self.listContainer.addSubview(listView)
                }
                transition.setPosition(view: listView, position: listFrame.offsetBy(dx: 0.0, dy: self.isChatExpanded ? 0.0 : listFrame.height).center)
                transition.setBounds(view: listView, bounds: CGRect(origin: CGPoint(), size: listFrame.size))
                
                let listAlpha: CGFloat
                if self.isMessageContextMenuOpen {
                    listAlpha = 0.25
                } else {
                    listAlpha = listItems.isEmpty ? 0.0 : 1.0
                }
                if previousListIsEmpty && !listItems.isEmpty && !alphaTransition.animation.isImmediate {
                    listView.alpha = 1.0
                    var delay: Double = 0.0
                    let delayIncrement: Double = 0.014
                    for itemView in listView.visibleItemViews() {
                        if let itemView = itemView as? StoryLiveChatMessageComponent.View {
                            itemView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, delay: delay)
                            itemView.layer.animateScale(from: 0.95, to: 1.0, duration: 0.2, delay: delay)
                            delay += delayIncrement
                        }
                    }
                } else {
                    alphaTransition.setAlpha(view: listView, alpha: listAlpha)
                }
            }
            
            transition.setFrame(view: self.listContainer, frame: CGRect(origin: CGPoint(), size: availableSize))
            transition.setFrame(view: self.listMaskContainer, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            let maskTopInset: CGFloat = listInsets.bottom - 20.0
            let maskBottomInset: CGFloat = listInsets.top - 26.0
            transition.setFrame(view: self.maskGradientView, frame: CGRect(origin: CGPoint(x: 0.0, y: maskTopInset), size: CGSize(width: availableSize.width, height: max(0.0, availableSize.height - maskTopInset - maskBottomInset))))
            
            transition.setFrame(view: self.listShadowView, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            self.listShadowView.backgroundColor = UIColor(white: 0.0, alpha: 0.3)
            transition.setAlpha(view: self.listShadowView, alpha: self.isChatExpanded ? 1.0 : 0.0)
            
            let reactionStreamView: LiveChatReactionStreamView
            if let current = self.reactionStreamView {
                reactionStreamView = current
            } else {
                reactionStreamView = LiveChatReactionStreamView(context: component.context)
                self.reactionStreamView = reactionStreamView
                self.addSubview(reactionStreamView)
            }
            reactionStreamView.update(size: availableSize, sourcePoint: CGPoint(x: availableSize.width, y: availableSize.height), transition: transition)
            
            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class ItemExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool
    let ignoreContentTouches: Bool = true
    let blurBackground: Bool = false
    let adjustContentForSideInset: Bool = true
    
    private let sourceNode: ContextExtractedContentContainingNode
    private weak var containerView: UIView?
    
    init(sourceNode: ContextExtractedContentContainingNode, containerView: UIView, keepInPlace: Bool) {
        self.sourceNode = sourceNode
        self.containerView = containerView
        self.keepInPlace = keepInPlace
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        var contentArea: CGRect?
        if let containerView = self.containerView {
            contentArea = containerView.convert(containerView.bounds, to: nil)
        }
        
        return ContextControllerTakeViewInfo(
            containingItem: .node(self.sourceNode),
            contentAreaInScreenSpace: contentArea ?? UIScreen.main.bounds
        )
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
