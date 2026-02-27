import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import BundleIconComponent
import ButtonComponent
import Markdown
import BalancedTextComponent
import AvatarNode
import TextFormat
import TelegramStringFormatting
import StarsAvatarComponent
import EmojiTextAttachmentView
import EmojiStatusComponent
import UndoUI
import ConfettiEffect
import PlainButtonComponent
import CheckComponent
import TooltipUI
import LottieComponent
import ContextUI
import TelegramNotices
import PremiumLockButtonSubtitleComponent
import StarsBalanceOverlayComponent
import BalanceNeededScreen
import GiftItemComponent
import GiftAnimationComponent
import ChatThemeScreen
import ProfileLevelRatingBarComponent
import AnimatedTextComponent
import InfoParagraphComponent
import ChatMessagePaymentAlertController
import TableComponent
import PeerTableCellComponent
import AvatarComponent
import GlassControls
import GlassBarButtonComponent
import GlassBackgroundComponent

private final class GiftViewSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: GiftViewScreen.Subject
    let animateOut: ActionSlot<Action<()>>
    let getController: () -> ViewController?
    
    init(
        context: AccountContext,
        subject: GiftViewScreen.Subject,
        animateOut: ActionSlot<Action<()>>,
        getController: @escaping () -> ViewController?
    ) {
        self.context = context
        self.subject = subject
        self.animateOut = animateOut
        self.getController = getController
    }
    
    static func ==(lhs: GiftViewSheetContent, rhs: GiftViewSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        let controlButtonsTag = GenericComponentViewTag()
        let modelButtonTag = GenericComponentViewTag()
        let backdropButtonTag = GenericComponentViewTag()
        let symbolButtonTag = GenericComponentViewTag()
        let statusTag = GenericComponentViewTag()
        
        private let context: AccountContext
        private(set) var subject: GiftViewScreen.Subject
        var justUpgraded = false
        var revealedAttributes = Set<StarGift.UniqueGift.Attribute.AttributeType>()
        var revealedNumberDigits: Int = 0
        
        private let getController: () -> ViewController?
        
        private var disposable: Disposable?
        var initialized = false
        
        var recipientPeerIdPromise = ValuePromise<EnginePeer.Id?>(nil)
        var recipientPeerId: EnginePeer.Id? {
            didSet {
                self.recipientPeerIdPromise.set(self.recipientPeerId)
            }
        }
        
        var peerMap: [EnginePeer.Id: EnginePeer] = [:]
        var starGiftsMap: [Int64: StarGift.Gift] = [:]
        
        var cachedStarImage: (UIImage, PresentationTheme)?
        var cachedSmallStarImage: (UIImage, PresentationTheme)?
        var cachedSubtitleStarImage: (UIImage, PresentationTheme)?
        var cachedTonImage: (UIImage, PresentationTheme)?
        
        var cachedChevronImage: (UIImage, PresentationTheme)?
        var cachedSmallChevronImage: (UIImage, PresentationTheme)?
        var cachedHiddenImage: (UIImage, PresentationTheme)?
        
        var inProgress = false
        var canSkip = false
        
        var testUpgradeAnimation = !"".isEmpty
                
        var upgradeForm: BotPaymentForm?
        var upgradeFormDisposable: Disposable?
        var upgradeDisposable: Disposable?
        var scheduledUpgradeCommit = false
        
        let levelsDisposable = MetaDisposable()
        var nextGiftToUpgrade: ProfileGiftsContext.State.StarGift?
        
        var giftVariantsDisposable = MetaDisposable()
        
        var buyForm: BotPaymentForm?
        var buyFormDisposable: Disposable?
        var buyDisposable: Disposable?
        var resellTooEarlyTimestamp: Int32?
        
        var inWearPreview = false
        var pendingWear = false
        var pendingTakeOff = false
        
        var inUpgradePreview = false
        var scheduledUpgradePreview = false
        var upgradePreview: StarGiftUpgradePreview?
        let upgradePreviewDisposable = DisposableSet()
        var upgradePreviewTimer: SwiftSignalKit.Timer?
        
        var keepOriginalInfo = false
                
        private var starsTopUpOptionsDisposable: Disposable?
        private(set) var starsTopUpOptions: [StarsTopUpOption] = [] {
            didSet {
                self.starsTopUpOptionsPromise.set(self.starsTopUpOptions)
            }
        }
        private let starsTopUpOptionsPromise = ValuePromise<[StarsTopUpOption]?>(nil)
        
        private let animateOut: ActionSlot<Action<()>>
        
        init(
            context: AccountContext,
            subject: GiftViewScreen.Subject,
            animateOut: ActionSlot<Action<()>>,
            getController: @escaping () -> ViewController?
        ) {
            self.context = context
            self.subject = subject
            self.animateOut = animateOut
            self.getController = getController
            
            super.init()
            
            if let arguments = subject.arguments {
                if let upgradeStars = arguments.upgradeStars, upgradeStars > 0, !arguments.nameHidden && !arguments.upgradeSeparate {
                    self.keepOriginalInfo = true
                }
                
                var peerIds: [EnginePeer.Id] = [context.account.peerId]
                if let peerId = arguments.peerId {
                    peerIds.append(peerId)
                }
                if let fromPeerId = arguments.fromPeerId, !peerIds.contains(fromPeerId) {
                    peerIds.append(fromPeerId)
                }
                if case let .message(message) = subject {
                    for media in message.media {
                        peerIds.append(contentsOf: media.peerIds)
                    }
                }
                
                if case let .unique(gift) = arguments.gift {
                    if let releasedBy = gift.releasedBy {
                        peerIds.append(releasedBy)
                    }
                    if case let .peerId(peerId) = gift.owner {
                        peerIds.append(peerId)
                    }
                    if let peerId = gift.hostPeerId {
                        peerIds.append(peerId)
                    }
                    for attribute in gift.attributes {
                        if case let .originalInfo(senderPeerId, recipientPeerId, _, _, _) = attribute {
                            if let senderPeerId {
                                peerIds.append(senderPeerId)
                            }
                            peerIds.append(recipientPeerId)
                            break
                        }
                    }
                    
                    var isOwn = false
                    var ownerPeerId: EnginePeer.Id?
                    if case let .peerId(peerId) = gift.owner {
                        ownerPeerId = peerId
                    }
                    if arguments.incoming || ownerPeerId == context.account.peerId {
                        isOwn = true
                    }
                    
                    if let _ = arguments.resellAmounts, !isOwn {
                        self.buyFormDisposable = (context.engine.payments.fetchBotPaymentForm(source: .starGiftResale(slug: gift.slug, toPeerId: context.account.peerId, ton: gift.resellForTonOnly), themeParams: nil)
                        |> deliverOnMainQueue).start(next: { [weak self] paymentForm in
                            guard let self else {
                                return
                            }
                            self.buyForm = paymentForm
                            self.updated()
                        }, error: { [weak self] error in
                            guard let self else {
                                return
                            }
                            if case let .starGiftResellTooEarly(remaining) = error {
                                let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                                self.resellTooEarlyTimestamp = currentTime + remaining
                            }
                        })
                    }
                    
                    if self.testUpgradeAnimation {
                        if gift.giftId != 0 {
                            self.upgradePreviewDisposable.add((context.engine.payments.starGiftUpgradePreview(giftId: gift.giftId)
                            |> deliverOnMainQueue).start(next: { [weak self] upgradePreview in
                                guard let self, let upgradePreview else {
                                    return
                                }
                                self.upgradePreview = upgradePreview
                                
                                for attribute in upgradePreview.attributes {
                                    switch attribute {
                                    case let .model(_, file, _, _):
                                        self.upgradePreviewDisposable.add(freeMediaFileResourceInteractiveFetched(account: self.context.account, userLocation: .other, fileReference: .standalone(media: file), resource: file.resource).start())
                                    case let .pattern(_, file, _):
                                        self.upgradePreviewDisposable.add(freeMediaFileResourceInteractiveFetched(account: self.context.account, userLocation: .other, fileReference: .standalone(media: file), resource: file.resource).start())
                                    default:
                                        break
                                    }
                                }
                                
                                self.updated()
                            }))
                        }
                    }
                } else if case let .generic(gift) = arguments.gift {
                    if let releasedBy = gift.releasedBy {
                        peerIds.append(releasedBy)
                    }
                    if arguments.canUpgrade || arguments.upgradeStars != nil || arguments.prepaidUpgradeHash != nil {
                        self.upgradePreviewDisposable.add((context.engine.payments.starGiftUpgradePreview(giftId: gift.id)
                        |> deliverOnMainQueue).start(next: { [weak self] upgradePreview in
                            guard let self, let upgradePreview else {
                                return
                            }
                            self.upgradePreview = upgradePreview
                            
                            for attribute in upgradePreview.attributes {
                                switch attribute {
                                case let .model(_, file, _, _):
                                    self.upgradePreviewDisposable.add(freeMediaFileResourceInteractiveFetched(account: self.context.account, userLocation: .other, fileReference: .standalone(media: file), resource: file.resource).start())
                                case let .pattern(_, file, _):
                                    self.upgradePreviewDisposable.add(freeMediaFileResourceInteractiveFetched(account: self.context.account, userLocation: .other, fileReference: .standalone(media: file), resource: file.resource).start())
                                default:
                                    break
                                }
                            }

                            self.updated()
                            
                            if arguments.upgradeStars == nil {
                                let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                                if let _ = upgradePreview.nextPrices.first(where: { currentTime < $0.date }) {
                                    self.upgradePreviewTimer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
                                        self?.upgradePreviewTimerTick()
                                    }, queue: Queue.mainQueue())
                                    self.upgradePreviewTimer?.start()
                                    self.upgradePreviewTimerTick()
                                }
                            }
                            
                            if self.scheduledUpgradePreview {
                                self.inProgress = false
                                self.scheduledUpgradePreview = false
                                self.requestUpgradePreview()
                            }
                        }))
                        
                        self.fetchUpgradeForm()
                    }
                }
                
                let peerIdsSignal: Signal<[EnginePeer.Id], NoError>
                if case let .uniqueGift(_, recipientPeerIdValue) = subject, let recipientPeerIdValue {
                    self.recipientPeerId = recipientPeerIdValue
                    self.recipientPeerIdPromise.set(recipientPeerIdValue)
                    peerIdsSignal = self.recipientPeerIdPromise.get()
                    |> map { recipientPeerId in
                        var peerIds = peerIds
                        if let recipientPeerId {
                            peerIds.append(recipientPeerId)
                        }
                        return peerIds
                    }
                } else {
                    peerIdsSignal = .single(peerIds)
                }
                                
                self.disposable = combineLatest(queue: Queue.mainQueue(),
                    peerIdsSignal
                    |> distinctUntilChanged
                    |> mapToSignal { peerIds in
                        return context.engine.data.get(EngineDataMap(
                            peerIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.Peer in
                                return TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                            }
                        ))
                    },
                    .single(nil) |> then(context.engine.payments.cachedStarGifts())
                ).startStrict(next: { [weak self] peers, starGifts in
                    if let strongSelf = self {
                        var peersMap: [EnginePeer.Id: EnginePeer] = [:]
                        for (peerId, maybePeer) in peers {
                            if let peer = maybePeer {
                                peersMap[peerId] = peer
                            }
                        }
                        strongSelf.peerMap = peersMap

                        var starGiftsMap: [Int64: StarGift.Gift] = [:]
                        if let starGifts {
                            for gift in starGifts {
                                if case let .generic(gift) = gift {
                                    starGiftsMap[gift.id] = gift
                                }
                            }
                        }
                        strongSelf.starGiftsMap = starGiftsMap
                        
                        strongSelf.initialized = true
                        
                        strongSelf.updated(transition: .immediate)
                    }
                })
            }

            if case let .unique(gift) = subject.arguments?.gift, gift.resellForTonOnly {
                
            } else {
                self.starsTopUpOptionsDisposable = (context.engine.payments.starsTopUpOptions()
                |> deliverOnMainQueue).start(next: { [weak self] options in
                    guard let self else {
                        return
                    }
                    self.starsTopUpOptions = options
                })
            }
        }
        
        deinit {
            self.disposable?.dispose()
            self.upgradePreviewDisposable.dispose()
            self.upgradePreviewTimer?.invalidate()
            self.upgradeFormDisposable?.dispose()
            self.upgradeDisposable?.dispose()
            self.buyFormDisposable?.dispose()
            self.buyDisposable?.dispose()
            self.levelsDisposable.dispose()
            self.starsTopUpOptionsDisposable?.dispose()
            self.giftVariantsDisposable.dispose()
        }

        func openPeer(_ peer: EnginePeer, gifts: Bool = false, dismiss: Bool = true) {
            guard let controller = self.getController() as? GiftViewScreen, let navigationController = controller.navigationController as? NavigationController else {
                return
            }
                        
            controller.dismissAllTooltips()
            
            let context = self.context
            let action = {
                if gifts {
                    let profileGifts = ProfileGiftsContext(account: context.account, peerId: peer.id)
                    let _ = (profileGifts.state
                    |> filter { state in
                        if case .ready = state.dataState {
                            return true
                        }
                        return false
                    }
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { [weak navigationController] _ in
                        if let profileController = context.sharedContext.makePeerInfoController(
                            context: context,
                            updatedPresentationData: nil,
                            peer: peer._asPeer(),
                            mode: peer.id == context.account.peerId ? .myProfileGifts : .gifts,
                            avatarInitiallyExpanded: false,
                            fromChat: false,
                            requestsContext: nil
                        ) {
                            navigationController?.pushViewController(profileController)
                        }
                        let _ = profileGifts
                    })
                } else {
                    context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                        navigationController: navigationController,
                        chatController: nil,
                        context: context,
                        chatLocation: .peer(peer),
                        subject: nil,
                        botStart: nil,
                        updateTextInputState: nil,
                        keepStack: .always,
                        useExisting: true,
                        purposefulAction: nil,
                        scrollToEndIfExists: false,
                        activateMessageSearch: nil,
                        animated: true
                    ))
                }
            }
            
            if dismiss {
                self.dismiss(animated: true)
                Queue.mainQueue().after(0.4, {
                    action()
                })
            } else {
                action()
            }
        }
               
        func openAddress(_ address: String) {
            guard let controller = self.getController() as? GiftViewScreen, let navigationController = controller.navigationController as? NavigationController else  {
                return
            }
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            let configuration = GiftViewConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
            let url = configuration.explorerUrl + address
            
            Queue.mainQueue().after(0.3) {
                self.context.sharedContext.openExternalUrl(
                    context: self.context,
                    urlContext: .generic,
                    url: url,
                    forceExternal: false,
                    presentationData: presentationData,
                    navigationController: navigationController,
                    dismissInput: {}
                )
            }
            
            self.dismiss(animated: true)
        }
        
        func copyAddress(_ address: String) {
            guard let controller = self.getController() as? GiftViewScreen else {
                return
            }
            
            UIPasteboard.general.string = address
            controller.dismissAllTooltips()
            
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            controller.present(
                UndoOverlayController(
                    presentationData: presentationData,
                    content: .copy(text: presentationData.strings.Gift_View_CopiedAddress),
                    position: .bottom,
                    action: { _ in return true }
                ),
                in: .current
            )
            
            HapticFeedback().tap()
        }
        
        func updateSavedToProfile(_ added: Bool) {
            guard let controller = self.getController() as? GiftViewScreen, let arguments = self.subject.arguments, let reference = arguments.reference else {
                return
            }
            
            var animationFile: TelegramMediaFile?
            switch arguments.gift {
            case let .generic(gift):
                animationFile = gift.file
            case let .unique(gift):
                for attribute in gift.attributes {
                    if case let .model(_, file, _, _) = attribute {
                        animationFile = file
                        break
                    }
                }
            }
            
            if let updateSavedToProfile = controller.updateSavedToProfile {
                updateSavedToProfile(reference, added)
            } else {
                let _ = (self.context.engine.payments.updateStarGiftAddedToProfile(reference: reference, added: added)
                |> deliverOnMainQueue).startStandalone()
            }
            
            controller.dismissAnimated()
            
            let giftsPeerId: EnginePeer.Id?
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            let text: String
            
            if case let .peer(peerId, _) = arguments.reference, peerId.namespace == Namespaces.Peer.CloudChannel {
                giftsPeerId = peerId
                text = added ? presentationData.strings.Gift_Displayed_ChannelText : presentationData.strings.Gift_Hidden_ChannelText
            } else {
                giftsPeerId = context.account.peerId
                text = added ? presentationData.strings.Gift_Displayed_NewText : presentationData.strings.Gift_Hidden_NewText
            }
            
            if let navigationController = controller.navigationController as? NavigationController {
                Queue.mainQueue().after(0.5) {
                    if let lastController = navigationController.viewControllers.last as? ViewController, let animationFile {
                        let resultController = UndoOverlayController(
                            presentationData: presentationData,
                            content: .sticker(
                                context: self.context,
                                file: animationFile,
                                loop: false,
                                title: nil,
                                text: text,
                                undoText: presentationData.strings.Gift_Displayed_View,
                                customAction: nil
                            ),
                            elevatedLayout: !(lastController is ChatController),
                            action: { [weak navigationController] action in
                                if case .undo = action, let navigationController, let giftsPeerId {
                                    let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: giftsPeerId))
                                    |> deliverOnMainQueue).start(next: { [weak navigationController] peer in
                                        guard let peer, let navigationController else {
                                            return
                                        }
                                        if let controller = self.context.sharedContext.makePeerInfoController(
                                            context: self.context,
                                            updatedPresentationData: nil,
                                            peer: peer._asPeer(),
                                            mode: giftsPeerId == self.context.account.peerId ? .myProfileGifts : .gifts,
                                            avatarInitiallyExpanded: false,
                                            fromChat: false,
                                            requestsContext: nil
                                        ) {
                                            navigationController.pushViewController(controller, animated: true)
                                        }
                                    })
                                }
                                return true
                            }
                        )
                        lastController.present(resultController, in: .current)
                    }
                }
            }
        }
        
        func convertToStars() {
            guard let controller = self.getController() as? GiftViewScreen, let starsContext = context.starsContext, let arguments = self.subject.arguments, let reference = arguments.reference, let fromPeerName = arguments.fromPeerCompactName, let convertStars = arguments.convertStars, let navigationController = controller.navigationController as? NavigationController else {
                return
            }
            
            let configuration = GiftConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
            let starsConvertMaxDate = arguments.date + configuration.convertToStarsPeriod
            
            var isChannelGift = false
            if case let .peer(peerId, _) = reference, peerId.namespace == Namespaces.Peer.CloudChannel {
                isChannelGift = true
            }
            
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
            
            if currentTime > starsConvertMaxDate {
                let days: Int32 = Int32(ceil(Float(configuration.convertToStarsPeriod) / 86400.0))
                let alertController = textAlertController(
                    context: self.context,
                    title: presentationData.strings.Gift_Convert_Title,
                    text: presentationData.strings.Gift_Convert_Period_Unavailable_Text(presentationData.strings.Gift_Convert_Period_Unavailable_Days(days)).string,
                    actions: [
                        TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
                    ],
                    parseMarkdown: true
                )
                controller.present(alertController, in: .window(.root))
            } else {
                let delta = starsConvertMaxDate - currentTime
                let days: Int32 = Int32(ceil(Float(delta) / 86400.0))
                
                let text = presentationData.strings.Gift_Convert_Period_Text(
                    fromPeerName,
                    presentationData.strings.Gift_Convert_Period_Stars(Int32(clamping: convertStars)),
                    presentationData.strings.Gift_Convert_Period_Days(days)
                ).string
                
                let alertController = textAlertController(
                    context: self.context,
                    title: presentationData.strings.Gift_Convert_Title,
                    text: text,
                    actions: [
                        TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}),
                        TextAlertAction(type: .defaultAction, title: presentationData.strings.Gift_Convert_Convert, action: { [weak self, weak controller, weak navigationController] in
                            guard let self else {
                                return
                            }
                            
                            if let convertToStars = controller?.convertToStars {
                                convertToStars(reference)
                            } else {
                                let _ = (self.context.engine.payments.convertStarGift(reference: reference)
                                |> deliverOnMainQueue).startStandalone()
                            }
                            
                            controller?.dismissAnimated()
                            
                            if let navigationController {
                                Queue.mainQueue().after(2.5) {
                                    starsContext.load(force: true)
                                    
                                    let text: String
                                    if isChannelGift {
                                        text = presentationData.strings.Gift_Convert_Success_ChannelText(
                                            presentationData.strings.Gift_Convert_Success_ChannelText_Stars(Int32(clamping: convertStars))
                                        ).string
                                    } else {
                                        text = presentationData.strings.Gift_Convert_Success_Text(
                                            presentationData.strings.Gift_Convert_Success_Text_Stars(Int32(clamping: convertStars))
                                        ).string
                                        if let starsContext = self.context.starsContext {
                                            navigationController.pushViewController(
                                                self.context.sharedContext.makeStarsTransactionsScreen(
                                                    context: self.context,
                                                    starsContext: starsContext
                                                ),
                                                animated: true
                                            )
                                        }
                                    }
                                    
                                    if let lastController = navigationController.viewControllers.last as? ViewController {
                                        let resultController = UndoOverlayController(
                                            presentationData: presentationData,
                                            content: .universal(
                                                animation: "StarsBuy",
                                                scale: 0.066,
                                                colors: [:],
                                                title: presentationData.strings.Gift_Convert_Success_Title,
                                                text: text,
                                                customUndoText: nil,
                                                timeout: nil
                                            ),
                                            elevatedLayout: !(lastController is ChatController),
                                            action: { _ in return true }
                                        )
                                        lastController.present(resultController, in: .current)
                                    }
                                }
                            }
                        })
                    ],
                    parseMarkdown: true
                )
                controller.present(alertController, in: .window(.root))
            }
        }
        
        func openStarsIntro() {
            guard let controller = self.getController() else {
                return
            }
            let introController = self.context.sharedContext.makeStarsIntroScreen(context: self.context)
            controller.push(introController)
        }
        
        func openDropOriginalDetails() {
            guard let controller = self.getController(), let gift = self.subject.arguments?.gift, case let .unique(uniqueGift) = gift, let price = self.subject.arguments?.dropOriginalDetailsStars else {
                return
            }
            let removeInfoController = giftRemoveInfoAlertController(
                context: self.context,
                gift: uniqueGift,
                peers: self.peerMap,
                removeInfoStars: price,
                navigationController: controller.navigationController as? NavigationController,
                commit: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.commitDropOriginalDetails()
                }
            )
            controller.present(removeInfoController, in: .window(.root))
        }
        
        func commitDropOriginalDetails() {
            guard let arguments = self.subject.arguments, let controller = self.getController() as? GiftViewScreen, let gift = self.subject.arguments?.gift, case let .unique(uniqueGift) = gift, let starsContext = self.context.starsContext, let starsState = starsContext.currentState, let reference = arguments.reference, let price = self.subject.arguments?.dropOriginalDetailsStars else {
                return
            }
            
            let context = self.context
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            let proceed = { [weak self, weak starsContext, weak controller] in
                guard let self, let controller else {
                    return
                }
                let dropOriginalDetailsImpl = controller.dropOriginalDetails
                
                let signal: Signal<Never, DropStarGiftOriginalDetailsError>
                if let dropOriginalDetailsImpl {
                    signal = dropOriginalDetailsImpl(reference)
                } else {
                    signal = context.engine.payments.dropStarGiftOriginalDetails(reference: reference)
                }
                
                self.upgradeDisposable = (signal
                |> deliverOnMainQueue).start(error: { _ in
                }, completed: { [weak self, weak starsContext, weak controller] in
                    guard let self else {
                        return
                    }
                    Queue.mainQueue().after(2.5) {
                        starsContext?.load(force: true)
                    }
                    switch self.subject {
                    case let .profileGift(peerId, gift):
                        let updatedAttributes = uniqueGift.attributes.filter { $0.attributeType != .originalInfo }
                        self.subject = .profileGift(peerId, gift.withGift(.unique(uniqueGift.withAttributes(updatedAttributes))))
                    case let .message(message):
                        if let action = message.media.first(where: { $0 is TelegramMediaAction }) as? TelegramMediaAction, case let .starGiftUnique(gift, isUpgrade, isTransferred, savedToProfile, canExportDate, transferStars, isRefunded, isPrepaidUpgrade, peerId, senderId, savedId, resaleAmount, canTransferDate, canResaleDate, _, assigned, fromOffer, canCraftAt, isCrafted) = action.action, case let .unique(uniqueGift) = gift {
                            let updatedAttributes = uniqueGift.attributes.filter { $0.attributeType != .originalInfo }
                            let updatedMedia: [Media] = [
                                TelegramMediaAction(
                                    action: .starGiftUnique(
                                        gift: .unique(uniqueGift.withAttributes(updatedAttributes)),
                                        isUpgrade: isUpgrade,
                                        isTransferred: isTransferred,
                                        savedToProfile: savedToProfile,
                                        canExportDate: canExportDate,
                                        transferStars: transferStars,
                                        isRefunded: isRefunded,
                                        isPrepaidUpgrade: isPrepaidUpgrade,
                                        peerId: peerId,
                                        senderId: senderId,
                                        savedId: savedId,
                                        resaleAmount: resaleAmount,
                                        canTransferDate: canTransferDate,
                                        canResaleDate: canResaleDate,
                                        dropOriginalDetailsStars: nil,
                                        assigned: assigned,
                                        fromOffer: fromOffer,
                                        canCraftAt: canCraftAt,
                                        isCrafted: isCrafted
                                    )
                                )
                            ]
                            
                            var mappedPeers: [PeerId: EnginePeer] = [:]
                            for (id, peer) in message.peers {
                                mappedPeers[id] = EnginePeer(peer)
                            }

                            var mappedAssociatedMessages: [MessageId: EngineMessage] = [:]
                            for (id, message) in message.associatedMessages {
                                mappedAssociatedMessages[id] = EngineMessage(message)
                            }
                            
                            let updatedMessage = EngineMessage(
                                stableId: message.stableId,
                                stableVersion: message.stableVersion,
                                id: message.id,
                                globallyUniqueId: message.globallyUniqueId,
                                groupingKey: message.groupingKey,
                                groupInfo: message.groupInfo,
                                threadId: message.threadId,
                                timestamp: message.timestamp,
                                flags: message.flags,
                                tags: message.tags,
                                globalTags: message.globalTags,
                                localTags: message.localTags,
                                customTags: message.customTags,
                                forwardInfo: message.forwardInfo,
                                author: message.author,
                                text: message.text,
                                attributes: message.attributes,
                                media: updatedMedia.map { EngineMedia($0) },
                                peers: mappedPeers,
                                associatedMessages: mappedAssociatedMessages,
                                associatedMessageIds: message.associatedMessageIds,
                                associatedMedia: message.associatedMedia,
                                associatedThreadInfo: message.associatedThreadInfo,
                                associatedStories: message.associatedStories
                            )
                            self.subject = .message(updatedMessage)
                        }
                    default:
                        break
                    }
                    self.updated(transition: .spring(duration: 0.3))
                    
                    let giftTitle = "\(uniqueGift.title) #\(formatCollectibleNumber(uniqueGift.number, dateTimeFormat: presentationData.dateTimeFormat))"
                    controller?.present(UndoOverlayController(presentationData: presentationData, content: .actionSucceeded(title: nil, text: presentationData.strings.Gift_RemoveDetails_Success(giftTitle).string, cancel: nil, destructive: false), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                })
            }
            
            if starsState.balance < StarsAmount(value: price, nanos: 0) {
                let _ = (self.starsTopUpOptionsPromise.get()
                |> filter { $0 != nil }
                |> take(1)
                |> deliverOnMainQueue).startStandalone(next: { [weak self] options in
                    guard let self, let controller = self.getController() else {
                        return
                    }
                    let purchaseController = self.context.sharedContext.makeStarsPurchaseScreen(
                        context: self.context,
                        starsContext: starsContext,
                        options: options ?? [],
                        purpose: .removeOriginalDetailsStarGift(requiredStars: price),
                        targetPeerId: nil,
                        customTheme: nil,
                        completion: { [weak self, weak starsContext] stars in
                            guard let self, let starsContext else {
                                return
                            }
                            self.inProgress = true
                            self.updated()
                            
                            starsContext.add(balance: StarsAmount(value: stars, nanos: 0))
                            let _ = (starsContext.onUpdate
                            |> deliverOnMainQueue).start(next: {
                                proceed()
                            })
                        }
                    )
                    controller.push(purchaseController)
                })
            } else {
                proceed()
            }
        }
        
        private var isOpeningValue = false
        func openValue() {
            guard let controller = self.getController(), let gift = self.subject.arguments?.gift, case let .unique(uniqueGift) = gift, !self.isOpeningValue else {
                return
            }
            self.isOpeningValue = true
            
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            let _ = (self.context.engine.payments.getUniqueStarGiftValueInfo(slug: uniqueGift.slug)
            |> deliverOnMainQueue).start(next: { [weak self] valueInfo in
                guard let self else {
                    return
                }
                Queue.mainQueue().after(0.2) {
                    self.isOpeningValue = false
                }
                if let valueInfo {
                    let valueController = GiftValueScreen(context: self.context, gift: gift, valueInfo: valueInfo)
                    controller.push(valueController)
                } else {
                    guard let controller = self.getController() as? GiftViewScreen else {
                        return
                    }
                    let alertController = textAlertController(
                        context: self.context,
                        title: nil,
                        text: presentationData.strings.Login_UnknownError,
                        actions: [
                            TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
                        ],
                        parseMarkdown: true
                    )
                    controller.present(alertController, in: .window(.root))
                }
            })
        }
        
        func sendGift(peerId: EnginePeer.Id) {
            guard let controller = self.getController() else {
                return
            }
            let _ = (self.context.engine.payments.premiumGiftCodeOptions(peerId: nil, onlyCached: true)
            |> filter { !$0.isEmpty }
            |> deliverOnMainQueue).start(next: { [weak self, weak controller] giftOptions in
                guard let self, let controller else {
                    return
                }
                let premiumOptions = giftOptions.filter { $0.users == 1 }.map { CachedPremiumGiftOption(months: $0.months, currency: $0.currency, amount: $0.amount, botUrl: "", storeProductId: $0.storeProductId) }
                let giftController = self.context.sharedContext.makeGiftOptionsController(context: self.context, peerId: peerId, premiumOptions: premiumOptions, hasBirthday: false, completion: nil)
                controller.push(giftController)
            })
            
            Queue.mainQueue().after(0.6, {
                self.dismiss(animated: false)
            })
        }
        
        func shareGift() {
            guard let arguments = self.subject.arguments, case let .unique(gift) = arguments.gift, let controller = self.getController() as? GiftViewScreen else {
                return
            }
            
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            
            var shareStoryImpl: (() -> Void)?
            if let shareStory = controller.shareStory {
                shareStoryImpl = {
                    shareStory(gift)
                }
            }
            let link = "https://t.me/nft/\(gift.slug)"
            let shareController = self.context.sharedContext.makeShareController(
                context: self.context,
                subject: .url(link),
                forceExternal: false,
                shareStory: shareStoryImpl,
                enqueued: { [weak self, weak controller] peerIds, _ in
                    guard let self else {
                        return
                    }
                    let _ = (self.context.engine.data.get(
                        EngineDataList(
                            peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                        )
                    )
                    |> deliverOnMainQueue).startStandalone(next: { [weak self, weak controller] peerList in
                        guard let self else {
                            return
                        }
                        let peers = peerList.compactMap { $0 }
                        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
                        let text: String
                        var savedMessages = false
                        if peerIds.count == 1, let peerId = peerIds.first, peerId == context.account.peerId {
                            text = presentationData.strings.Conversation_ForwardTooltip_SavedMessages_One
                            savedMessages = true
                        } else {
                            if peers.count == 1, let peer = peers.first {
                                var peerName = peer.id == context.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                peerName = peerName.replacingOccurrences(of: "**", with: "")
                                text = presentationData.strings.Conversation_ForwardTooltip_Chat_One(peerName).string
                            } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                                var firstPeerName = firstPeer.id == context.account.peerId ? presentationData.strings.DialogList_SavedMessages : firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                firstPeerName = firstPeerName.replacingOccurrences(of: "**", with: "")
                                var secondPeerName = secondPeer.id == context.account.peerId ? presentationData.strings.DialogList_SavedMessages : secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                secondPeerName = secondPeerName.replacingOccurrences(of: "**", with: "")
                                text = presentationData.strings.Conversation_ForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string
                            } else if let peer = peers.first {
                                var peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                                peerName = peerName.replacingOccurrences(of: "**", with: "")
                                text = presentationData.strings.Conversation_ForwardTooltip_ManyChats_One(peerName, "\(peers.count - 1)").string
                            } else {
                                text = ""
                            }
                        }
                        
                        controller?.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: false, animateInAsReplacement: false, action: { [weak self, weak controller] action in
                            if let self, savedMessages, action == .info {
                                let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId))
                                |> deliverOnMainQueue).start(next: { [weak self, weak controller] peer in
                                    guard let peer else {
                                        return
                                    }
                                    self?.openPeer(peer)
                                    Queue.mainQueue().after(0.6) {
                                        controller?.dismiss(animated: false, completion: nil)
                                    }
                                })
                            }
                            return false
                        }, additionalView: nil), in: .current)
                    })
                },
                actionCompleted: { [weak controller] in
                    controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                }
            )
            controller.present(shareController, in: .window(.root))
        }
        
        func setAsGiftTheme() {
            guard let arguments = self.subject.arguments, let controller = self.getController() as? GiftViewScreen, let navigationController = controller.navigationController as? NavigationController, case let .unique(gift) = arguments.gift else {
                return
            }
            
            let context = self.context
            
            let themePeerId = Promise<EnginePeer.Id?>()
            themePeerId.set(
                .single(gift.themePeerId)
                |> then(
                    context.engine.payments.getUniqueStarGift(slug: gift.slug)
                    |> map(Optional.init)
                    |> `catch` { _ -> Signal<StarGift.UniqueGift?, NoError> in
                        return .single(nil)
                    }
                    |> map { gift in
                        return gift?.themePeerId
                    }
                )
            )
            
            let peerController = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.excludeRecent, .doNotSearchMessages], requestPeerType: [.user(.init(isBot: false, isPremium: nil))], hasContactSelector: false, hasCreation: false))
            peerController.peerSelected = { [weak peerController, weak navigationController] peer, _ in
                if let navigationController {
                    let proceed = {
                        let _ = context.engine.themes.setChatWallpaper(peerId: peer.id, wallpaper: nil, forBoth: true).startStandalone()
                        let _ = context.engine.themes.setChatTheme(peerId: peer.id, chatTheme: .gift(.unique(gift), [])).startStandalone()
                        
                        peerController?.dismiss()
                        
                        context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                            navigationController: navigationController,
                            chatController: nil,
                            context: context,
                            chatLocation: .peer(peer),
                            subject: nil,
                            botStart: nil,
                            updateTextInputState: nil,
                            keepStack: .always,
                            useExisting: true,
                            purposefulAction: nil,
                            scrollToEndIfExists: false,
                            activateMessageSearch: nil,
                            animated: true
                        ))
                    }
                    
                    let _ = (themePeerId.get()
                    |> deliverOnMainQueue
                    |> take(1)).start(next: { [weak navigationController] themePeerId in
                        if let themePeerId, themePeerId != peer.id {
                            let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: themePeerId))
                            |> deliverOnMainQueue).start(next: { [weak navigationController] peer in
                                guard let peer else {
                                    proceed()
                                    return
                                }
                                let controller = giftThemeTransferAlertController(
                                    context: context,
                                    gift: gift,
                                    previousPeer: peer,
                                    commit: {
                                        proceed()
                                    }
                                )
                                (navigationController?.viewControllers.last as? ViewController)?.present(controller, in: .window(.root))
                            })
                        } else {
                            proceed()
                        }
                    })
                }
            }
            self.dismiss(animated: true)
                
            Queue.mainQueue().after(0.4) {
                navigationController.pushViewController(peerController)
            }
        }
        
        func presentActionLockedForHostedGift(gift: StarGift.UniqueGift) {
            guard let controller = self.getController() as? GiftViewScreen else {
                return
            }
            let context = self.context
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let alertController = textAlertController(
                context: context,
                title: presentationData.strings.Gift_UnavailableAction_Title,
                text: presentationData.strings.Gift_UnavailableAction_Text,
                actions: [
                    TextAlertAction(type: .defaultAction, title: presentationData.strings.Gift_UnavailableAction_OpenFragment, action: {
                        context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: "https://fragment.com/gift/\(gift.slug)", forceExternal: true, presentationData: presentationData, navigationController: controller.navigationController as? NavigationController, dismissInput: {})
                    }),
                    TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {})
                ],
                actionLayout: .vertical
            )
            controller.present(alertController, in: .window(.root))
        }
        
        func craftGift() {
            guard let arguments = self.subject.arguments, let controller = self.getController() as? GiftViewScreen, case let .unique(gift) = arguments.gift else {
                return
            }
            
            guard gift.hostPeerId == nil else {
                self.presentActionLockedForHostedGift(gift: gift)
                return
            }
            
            controller.dismissAllTooltips()
            
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            
            let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
            if let canCraftDate = arguments.canCraftDate, currentTime < canCraftDate {
                let dateString = stringForFullDate(timestamp: canCraftDate, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat)
                let alertController = textAlertController(
                    context: self.context,
                    title: presentationData.strings.Gift_Craft_Unavailable_Title,
                    text: presentationData.strings.Gift_Craft_Unavailable_Text(dateString).string,
                    actions: [
                        TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
                    ],
                    parseMarkdown: true
                )
                controller.present(alertController, in: .window(.root))
                return
            }
            
            if let navigationController = controller.navigationController as? NavigationController {
                controller.dismissAnimated()
                
                let craftScreen = self.context.sharedContext.makeGiftCraftScreen(
                    context: self.context,
                    gift: gift,
                    profileGiftsContext: controller.profileGiftsContext
                )
                navigationController.pushViewController(craftScreen)
            }
        }
        
        func transferGift() {
            guard let arguments = self.subject.arguments, let controller = self.getController() as? GiftViewScreen, case let .unique(gift) = arguments.gift, let reference = arguments.reference, let transferStars = arguments.transferStars else {
                return
            }
            
            guard gift.hostPeerId == nil else {
                self.presentActionLockedForHostedGift(gift: gift)
                return
            }
            
            controller.dismissAllTooltips()
            
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            
            let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
            if let canTransferDate = arguments.canTransferDate, currentTime < canTransferDate {
                let dateString = stringForFullDate(timestamp: canTransferDate, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat)
                let alertController = textAlertController(
                    context: self.context,
                    title: presentationData.strings.Gift_Transfer_Unavailable_Title,
                    text: presentationData.strings.Gift_Transfer_Unavailable_Text(dateString).string,
                    actions: [
                        TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
                    ],
                    parseMarkdown: true
                )
                controller.present(alertController, in: .window(.root))
                return
            }
            
            let context = self.context
            let _ = (self.context.account.stateManager.contactBirthdays
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self, weak controller] birthdays in
                guard let self, let controller else {
                    return
                }
                var showSelf = false
                if arguments.peerId?.namespace == Namespaces.Peer.CloudChannel {
                    showSelf = true
                }
                
                let tranfserGiftImpl = controller.transferGift
                
                let transferController = self.context.sharedContext.makePremiumGiftController(context: context, source: .starGiftTransfer(birthdays, reference, gift, transferStars, arguments.canExportDate, showSelf), completion: { peerIds in
                    guard let peerId = peerIds.first else {
                        return .complete()
                    }
                    Queue.mainQueue().after(2.5, {
                        if transferStars > 0 {
                            context.starsContext?.load(force: true)
                        }
                    })
                    
                    if let tranfserGiftImpl {
                        return tranfserGiftImpl(transferStars == 0, reference, peerId)
                    } else {
                        return (context.engine.payments.transferStarGift(prepaid: transferStars == 0, reference: reference, peerId: peerId)
                        |> deliverOnMainQueue)
                    }
                })
                controller.push(transferController)
            })
        }
        
        func resellGift(update: Bool = false) {
            guard let arguments = self.subject.arguments, case let .unique(gift) = arguments.gift, let controller = self.getController() as? GiftViewScreen else {
                return
            }
            
            guard gift.hostPeerId == nil else {
                self.presentActionLockedForHostedGift(gift: gift)
                return
            }
            
            let isTablet = controller.validLayout?.metrics.isTablet ?? false
            
            controller.dismissAllTooltips()
            
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            
            let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
            if let canResaleDate = arguments.canResaleDate, currentTime < canResaleDate {
                let dateString = stringForFullDate(timestamp: canResaleDate, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat)
                let alertController = textAlertController(
                    context: self.context,
                    title: presentationData.strings.Gift_Resale_Unavailable_Title,
                    text: presentationData.strings.Gift_Resale_Unavailable_Text(dateString).string,
                    actions: [
                        TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
                    ],
                    parseMarkdown: true
                )
                controller.present(alertController, in: .window(.root))
                return
            }
            
            let giftTitle = "\(gift.title) #\(formatCollectibleNumber(gift.number, dateTimeFormat: presentationData.dateTimeFormat))"
            let reference = arguments.reference ?? .slug(slug: gift.slug)
            
            if let resellStars = gift.resellAmounts?.first, resellStars.amount.value > 0, !update {
                let alertController = textAlertController(
                    context: self.context,
                    title: presentationData.strings.Gift_View_Resale_Unlist_Title,
                    text: presentationData.strings.Gift_View_Resale_Unlist_Text,
                    actions: [
                        TextAlertAction(type: .defaultAction, title: presentationData.strings.Gift_View_Resale_Unlist_Unlist, action: { [weak self, weak controller] in
                            guard let self, let controller else {
                                return
                            }
                            let _ = ((controller.updateResellStars?(reference, nil) ?? context.engine.payments.updateStarGiftResalePrice(reference: reference, price: nil))
                            |> deliverOnMainQueue).startStandalone(error: { error in
                                
                            }, completed: { [weak self, weak controller] in
                                guard let self, let controller else {
                                    return
                                }
                                switch self.subject {
                                case let .profileGift(peerId, currentSubject):
                                    self.subject = .profileGift(peerId, currentSubject.withGift(.unique(gift.withResellAmounts(nil).withResellForTonOnly(false))))
                                case let .uniqueGift(_, recipientPeerId):
                                    self.subject = .uniqueGift(gift.withResellAmounts(nil).withResellForTonOnly(false), recipientPeerId)
                                default:
                                    break
                                }
                                self.updated(transition: .easeInOut(duration: 0.2))
                                
                                let text = presentationData.strings.Gift_View_Resale_Unlist_Success(giftTitle).string
                                let tooltipController = UndoOverlayController(
                                    presentationData: presentationData,
                                    content: .universalImage(
                                        image: generateTintedImage(image: UIImage(bundleImageName: "Premium/Collectible/Unlist"), color: .white)!,
                                        size: nil,
                                        title: nil,
                                        text: text,
                                        customUndoText: nil,
                                        timeout: 3.0
                                    ),
                                    position: .bottom,
                                    animateInAsReplacement: false,
                                    appearance: isTablet ? nil : UndoOverlayController.Appearance(sideInset: 16.0, bottomInset: 62.0),
                                    action: { action in
                                        return false
                                    }
                                )
                                controller.present(tooltipController, in: isTablet ? .current : .window(.root))
                            })
                        }),
                        TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                        })
                    ],
                    actionLayout: .vertical
                )
                controller.present(alertController, in: .window(.root))
            } else {
                let resellController = self.context.sharedContext.makeStarGiftResellScreen(context: self.context, gift: gift, update: update, completion: { [weak self, weak controller] price in
                    guard let self, let controller else {
                        return
                    }
                                    
                    let _ = ((controller.updateResellStars?(reference, price) ?? self.context.engine.payments.updateStarGiftResalePrice(reference: reference, price: price))
                    |> deliverOnMainQueue).startStandalone(error: { [weak self, weak controller] error in
                        guard let self else {
                            return
                        }
                        
                        let title: String?
                        let text: String
                        switch error {
                        case .generic:
                            title = nil
                            text = presentationData.strings.Gift_Send_ErrorUnknown
                        case let .starGiftResellTooEarly(canResaleDate):
                            let dateString = stringForFullDate(timestamp: currentTime + canResaleDate, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat)
                            title = presentationData.strings.Gift_Resale_Unavailable_Title
                            text = presentationData.strings.Gift_Resale_Unavailable_Text(dateString).string
                        }
                        
                        let alertController = textAlertController(
                            context: self.context,
                            title: title,
                            text: text,
                            actions: [
                                TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
                            ],
                            parseMarkdown: true
                        )
                        controller?.present(alertController, in: .window(.root))
                    }, completed: { [weak self, weak controller] in
                        guard let self, let controller else {
                            return
                        }
                        
                        switch self.subject {
                        case let .profileGift(peerId, currentSubject):
                            self.subject = .profileGift(peerId, currentSubject.withGift(.unique(gift.withResellAmounts([price]).withResellForTonOnly(price.currency == .ton))))
                        case let .uniqueGift(_, recipientPeerId):
                            self.subject = .uniqueGift(gift.withResellAmounts([price]).withResellForTonOnly(price.currency == .ton), recipientPeerId)
                        default:
                            break
                        }
                        self.updated(transition: .easeInOut(duration: 0.2))
                        
                        var text = presentationData.strings.Gift_View_Resale_List_Success(giftTitle).string
                        if update {
                            let priceString: String
                            switch price.currency {
                            case .stars:
                                priceString = presentationData.strings.Gift_View_Resale_Relist_Success_Stars(Int32(clamping: price.amount.value))
                            case .ton:
                                priceString = formatTonAmountText(price.amount.value, dateTimeFormat: presentationData.dateTimeFormat, maxDecimalPositions: nil) + " TON"
                            }
                            text = presentationData.strings.Gift_View_Resale_Relist_Success(giftTitle, priceString).string
                        }
                                         
                        let tooltipController = UndoOverlayController(
                            presentationData: presentationData,
                            content: .universalImage(
                                image: generateTintedImage(image: UIImage(bundleImageName: "Premium/Collectible/Sell"), color: .white)!,
                                size: nil,
                                title: nil,
                                text: text,
                                customUndoText: nil,
                                timeout: 3.0
                            ),
                            position: .bottom,
                            animateInAsReplacement: false,
                            appearance: isTablet ? nil : UndoOverlayController.Appearance(sideInset: 16.0, bottomInset: 62.0),
                            action: { action in
                                return false
                            }
                        )
                        controller.present(tooltipController, in: isTablet ? .current : .window(.root))
                    })
                })
                controller.push(resellController)
            }
        }
        
        func viewUpgradedGift(messageId: EngineMessage.Id, delay: Bool) {
            guard let controller = self.getController(), let navigationController = controller.navigationController as? NavigationController else {
                return
            }
            let _ = (self.context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: messageId.peerId)
            )
            |> deliverOnMainQueue).start(next: { [weak self, weak navigationController] peer in
                guard let self, let navigationController, let peer else {
                    return
                }
                let action = {
                    self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), subject: .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false), keepStack: .always, useExisting: true, purposefulAction: {}, peekData: nil, forceAnimatedScroll: true))
                }
                
                if delay {
                    Queue.mainQueue().after(0.3) {
                        action()
                    }
                } else {
                    action()
                }
            })
        }
        
        
        func openUpgradeVariants(attribute: StarGift.UniqueGift.Attribute? = nil) {
            guard let controller = self.getController() as? GiftViewScreen else {
                return
            }
            
            var gift: StarGift?
            var selectedAttributes: [StarGift.UniqueGift.Attribute]?
            if let arguments = self.subject.arguments {
                gift = arguments.gift
                if case let .unique(uniqueGift) = arguments.gift {
                    selectedAttributes = uniqueGift.attributes
                }
            } else if case let .upgradePreview(genericGift, _, _) = self.subject {
                gift = .generic(genericGift)
            }
            
            guard let gift else {
                return
            }
            
            self.giftVariantsDisposable.set((self.context.engine.payments.getStarGiftUpgradeAttributes(giftId: gift.giftId)
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] attributes in
                guard let self, let attributes else {
                    return
                }
                let variantsController = self.context.sharedContext.makeGiftUpgradeVariantsScreen(
                    context: self.context,
                    gift: gift,
                    crafted: false,
                    attributes: attributes,
                    selectedAttributes: selectedAttributes,
                    focusedAttribute: attribute
                )
                controller.push(variantsController)
            }))
        }
        
        func showAttributeInfo(tag: Any, text: String) {
            guard let controller = self.getController() as? GiftViewScreen else {
                return
            }
            controller.dismissAllTooltips()
            
            guard let sourceView = controller.node.hostView.findTaggedView(tag: tag), let absoluteLocation = sourceView.superview?.convert(sourceView.center, to: controller.view) else {
                return
            }
            
            let location = CGRect(origin: CGPoint(x: absoluteLocation.x, y: absoluteLocation.y - 12.0), size: CGSize())
            let tooltipController = TooltipScreen(account: self.context.account, sharedContext: self.context.sharedContext, text: .plain(text: text), style: .wide, location: .point(location, .bottom), displayDuration: .default, inset: 16.0, shouldDismissOnTouch: { _, _ in
                return .dismiss(consume: false)
            })
            controller.present(tooltipController, in: .current)
        }
        
        func openMore() {
            guard let controller = self.getController() as? GiftViewScreen else {
                return
            }
            guard let controlsView = controller.node.hostView.findTaggedView(tag: self.controlButtonsTag) as? GlassControlPanelComponent.View, let rightItemView = controlsView.rightItemView, let sourceView = rightItemView.itemView(id: AnyHashable("more")) else {
                return
            }
            
            
            guard let arguments = self.subject.arguments, case let .unique(gift) = arguments.gift else {
                return
            }
            
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            let link = "https://t.me/nft/\(gift.slug)"
            
            let _ = (self.context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: arguments.peerId ?? context.account.peerId)
            )
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                guard let self, let controller = self.getController() as? GiftViewScreen else {
                    return
                }
                var items: [ContextMenuItem] = []
                let strings = presentationData.strings
                
                if let reference = arguments.reference, case .unique = arguments.gift, let togglePinnedToTop = controller.togglePinnedToTop, let pinnedToTop = arguments.pinnedToTop {
                    items.append(.action(ContextMenuActionItem(text: pinnedToTop ? strings.PeerInfo_Gifts_Context_Unpin : strings.PeerInfo_Gifts_Context_Pin , icon: { theme in generateTintedImage(image: UIImage(bundleImageName: pinnedToTop ? "Chat/Context Menu/Unpin" : "Chat/Context Menu/Pin"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, f in
                        c?.dismiss(completion: { [weak self, weak controller] in
                            guard let self, let controller else {
                                return
                            }
                            
                            let pinnedToTop = !pinnedToTop
                            if togglePinnedToTop(reference, pinnedToTop) {
                                if pinnedToTop {
                                    controller.dismissAnimated()
                                } else {
                                    let toastText = strings.PeerInfo_Gifts_ToastUnpinned_Text
                                    controller.present(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_toastunpin", scale: 0.06, colors: [:], title: nil, text: toastText, customUndoText: nil, timeout: 5), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                                    if case let .profileGift(peerId, gift) = self.subject {
                                        self.subject = .profileGift(peerId, gift.withPinnedToTop(false))
                                    }
                                }
                            }
                        })
                    })))
                }
                                
                if case let .unique(gift) = arguments.gift, let resellAmount = gift.resellAmounts?.first, resellAmount.amount.value > 0 {
                    if arguments.reference != nil || gift.owner?.peerId == self.context.account.peerId {
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Gift_View_Context_ChangePrice, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/PriceTag"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] c, _ in
                            c?.dismiss(completion: nil)
                            
                            self?.resellGift(update: true)
                        })))
                    }
                }
                
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.Gift_View_Context_CopyLink, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Link"), color: theme.contextMenu.primaryColor)
                }, action: { [weak controller] c, _ in
                    c?.dismiss(completion: nil)
                    
                    UIPasteboard.general.string = link
                    
                    controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                })))
                
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.Gift_View_Context_Share, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] c, _ in
                    c?.dismiss(completion: nil)
                    
                    self?.shareGift()
                })))
                          
                if let _ = arguments.canCraftDate {
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.Gift_View_Context_Craft, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Premium/Craft/Craft"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] c, _ in
                        c?.dismiss(completion: nil)
                        
                        self?.craftGift()
                    })))
                }
                
                if case let .unique(uniqueGift) = arguments.gift, case let .peerId(ownerPeerId) = uniqueGift.owner, ownerPeerId != self.context.account.peerId, uniqueGift.minOfferStars != nil {
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.Gift_View_Context_BuyOffer, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Media Grid/Paid"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] c, _ in
                        c?.dismiss(completion: nil)
                        
                        self?.openGiftBuyOffer()
                    })))
                }
                                
                if gift.flags.contains(.isThemeAvailable) {
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.Gift_View_Context_SetAsTheme, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ApplyTheme"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] c, _ in
                        c?.dismiss(completion: nil)
                        
                        self?.setAsGiftTheme()
                    })))
                }
                
                if let _ = arguments.transferStars {
                    if case let .channel(channel) = peer, !channel.flags.contains(.isCreator) {
                        
                    } else {
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Gift_View_Context_Transfer, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Replace"), color: theme.contextMenu.primaryColor)
                        }, action: { [weak self] c, _ in
                            c?.dismiss(completion: nil)
                            
                            self?.transferGift()
                        })))
                    }
                }
                                
                if let _ = arguments.resellAmounts, case let .uniqueGift(uniqueGift, recipientPeerId) = subject, let _ = recipientPeerId {
                    items.append(.action(ContextMenuActionItem(text: presentationData.strings.Gift_View_Context_ViewInProfile, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Peer Info/ShowIcon"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] c, _ in
                        c?.dismiss(completion: nil)
                        
                        guard let self,  case let .peerId(peerId) = uniqueGift.owner else {
                            return
                        }
                        let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                        |> deliverOnMainQueue).start(next: { [weak self] peer in
                            guard let self, let peer else {
                                return
                            }
                            self.openPeer(peer, gifts: true)
                            Queue.mainQueue().after(0.6) {
                                controller.dismiss(animated: false, completion: nil)
                            }
                        })
                    })))
                }
                
                let contextController = makeContextController(presentationData: presentationData, source: .reference(GiftViewContextReferenceContentSource(controller: controller, sourceView: sourceView)), items: .single(ContextController.Items(content: .list(items))), gesture: nil)
                controller.presentInGlobalOverlay(contextController)
            })
        }
        
        func dismiss(animated: Bool) {
            guard let controller = self.getController() as? GiftViewScreen else {
                return
            }
            if animated {
                controller.dismissAllTooltips()
                controller.dismissBalanceOverlay()
                controller.requestLayout(forceUpdate: true, transition: .easeInOut(duration: 0.3).withUserData(ViewControllerComponentContainer.AnimateOutTransition()))
                self.animateOut.invoke(Action { [weak controller] _ in
                    controller?.dismiss(completion: nil)
                })
            } else {
                controller.dismiss(animated: false)
            }
        }
        
        func requestWearPreview() {
            self.inWearPreview = true
            self.updated(transition: .spring(duration: 0.4))
        }
        
        func commitWear(_ uniqueGift: StarGift.UniqueGift) {
            self.pendingWear = true
            self.pendingTakeOff = false
            self.inWearPreview = false
            self.updated(transition: .spring(duration: 0.4))
            
            if let arguments = self.subject.arguments, let peerId = arguments.peerId, peerId.namespace == Namespaces.Peer.CloudChannel {
                let _ = self.context.engine.peers.updatePeerStarGiftStatus(peerId: peerId, starGift: uniqueGift, expirationDate: nil).startStandalone()
            } else {
                let _ = self.context.engine.accountData.setStarGiftStatus(starGift: uniqueGift, expirationDate: nil).startStandalone()
            }
            
            let _ = ApplicationSpecificNotice.incrementStarGiftWearTips(accountManager: self.context.sharedContext.accountManager).startStandalone()
        }
        
        func commitTakeOff() {
            self.pendingTakeOff = true
            self.pendingWear = false
            self.updated(transition: .spring(duration: 0.4))
            
            if let arguments = self.subject.arguments, let peerId = arguments.peerId, peerId.namespace == Namespaces.Peer.CloudChannel {
                let _ = self.context.engine.peers.updatePeerEmojiStatus(peerId: peerId, fileId: nil, expirationDate: nil).startStandalone()
            } else {
                let _ = self.context.engine.accountData.setEmojiStatus(file: nil, expirationDate: nil).startStandalone()
            }
        }
        
        private func fetchUpgradeForm() {
            guard let reference = self.subject.arguments?.reference else {
                return
            }
            self.upgradeForm = nil
            self.upgradeFormDisposable = (self.context.engine.payments.fetchBotPaymentForm(source: .starGiftUpgrade(keepOriginalInfo: false, reference: reference), themeParams: nil)
            |> deliverOnMainQueue).start(next: { [weak self] paymentForm in
                guard let self else {
                    return
                }
                self.upgradeForm = paymentForm
                self.updated()
                
                if self.scheduledUpgradeCommit {
                    self.scheduledUpgradeCommit = false
                    self.commitUpgrade()
                }
            })
        }
        
        private(set) var effectiveUpgradePrice: StarGiftUpgradePreview.Price?
        private(set) var nextUpgradePrice: StarGiftUpgradePreview.Price?
        
        func upgradePreviewTimerTick() {
            guard let upgradePreview = self.upgradePreview, let gift = self.subject.arguments?.gift, case let .generic(gift) = gift else {
                return
            }
            let context = self.context
            var transition: ComponentTransition = .immediate
            let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
            if let currentPrice = self.effectiveUpgradePrice {
                if let price = upgradePreview.nextPrices.reversed().first(where: { currentTime >= $0.date  }) {
                    if price.stars != currentPrice.stars {
                        self.effectiveUpgradePrice = price
                        if let nextPrice = upgradePreview.nextPrices.first(where: { $0.stars < price.stars }) {
                            self.nextUpgradePrice = nextPrice
                        } else {
                            transition = .spring(duration: 0.4)
                            self.nextUpgradePrice = nil
                        }
                        if upgradePreview.nextPrices[upgradePreview.nextPrices.count - 2] == price {
                            self.upgradePreviewDisposable.add((context.engine.payments.starGiftUpgradePreview(giftId: gift.id)
                            |> deliverOnMainQueue).start(next: { [weak self] nextUpgradePreview in
                                guard let self, let nextUpgradePreview else {
                                    return
                                }
                                self.upgradePreview = nextUpgradePreview.withAttributes(upgradePreview.attributes)
                            }))
                        }
                        
                        self.fetchUpgradeForm()
                    }
                } else {
                    self.upgradePreviewTimer?.invalidate()
                    self.upgradePreviewTimer = nil
                }
            } else if let price = upgradePreview.nextPrices.reversed().first(where: { currentTime >= $0.date}) {
                self.effectiveUpgradePrice = price
                if let nextPrice = upgradePreview.nextPrices.first(where: { $0.stars < price.stars }) {
                    self.nextUpgradePrice = nextPrice
                }
            }
                        
            self.updated(transition: transition)
        }
        
        func requestUpgradePreview() {
            if let _ = self.upgradePreview {
                self.context.starsContext?.load(force: false)
                
                self.inUpgradePreview = true
                self.updated(transition: .spring(duration: 0.4))
                
                if let controller = self.getController() as? GiftViewScreen, self.upgradeForm != nil {
                    controller.showBalance = true
                }
            } else {
                self.scheduledUpgradePreview = true
                
                self.inProgress = true
                self.updated()
            }
        }
        
        func cancelUpgradePreview() {
            self.inUpgradePreview = false
            self.updated(transition: .spring(duration: 0.4))
            
            if let controller = self.getController() as? GiftViewScreen {
                controller.showBalance = false
            }
        }
        
        func commitBuy(acceptedPrice: CurrencyAmount? = nil, skipConfirmation: Bool = false) {
            guard case let .unique(uniqueGift) = self.subject.arguments?.gift, let controller = self.getController() as? GiftViewScreen else {
                return
            }
            
            let context = self.context
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            let giftTitle = "\(uniqueGift.title) #\(formatCollectibleNumber(uniqueGift.number, dateTimeFormat: presentationData.dateTimeFormat))"
            
            if let resellTooEarlyTimestamp = self.resellTooEarlyTimestamp {
                let dateString = stringForFullDate(timestamp: resellTooEarlyTimestamp, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat)
                let alertController = textAlertController(
                    context: context,
                    title: presentationData.strings.Gift_Buy_ErrorTooEarly_Title,
                    text: presentationData.strings.Gift_Buy_ErrorTooEarly_Text(dateString).string,
                    actions: [
                        TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
                    ],
                    parseMarkdown: true
                )
                controller.present(alertController, in: .window(.root))
                return
            }
            
            guard let _ = self.buyForm else {
                let alertController = textAlertController(
                    context: context,
                    title: nil,
                    text: presentationData.strings.Gift_Buy_ErrorUnknown,
                    actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})],
                    parseMarkdown: true
                )
                controller.present(alertController, in: .window(.root))
                return
            }
            
            let recipientPeerId = self.recipientPeerId ?? self.context.account.peerId
            buyStarGiftImpl(
                context: self.context,
                recipientPeerId: recipientPeerId,
                uniqueGift: uniqueGift,
                showAttributes: false,
                acceptedPrice: acceptedPrice,
                skipConfirmation: skipConfirmation,
                starsTopUpOptions: self.starsTopUpOptionsPromise.get(),
                buyGift: controller.buyGift,
                getController: self.getController,
                updateProgress: { [weak self] progress in
                    guard let self else {
                        return
                    }
                    self.inProgress = progress
                    self.updated()
                },
                updateIsBalanceVisible: { [weak controller] isVisible in
                    guard let controller else {
                        return
                    }
                    if let balanceView = controller.balanceOverlay.view {
                        balanceView.isHidden = !isVisible
                    }
                },
                completion: { [weak controller] in
                    guard let controller else {
                        return
                    }
                    
                    var animationFile: TelegramMediaFile?
                    for attribute in uniqueGift.attributes {
                        if case let .model(_, file, _, _) = attribute {
                            animationFile = file
                            break
                        }
                    }
                    
                    if let navigationController = controller.navigationController as? NavigationController {
                        if recipientPeerId == context.account.peerId {
                            controller.dismissAnimated()
                            
                            navigationController.view.addSubview(ConfettiView(frame: navigationController.view.bounds))
                            
                            Queue.mainQueue().after(0.5, {
                                if let lastController = navigationController.viewControllers.last as? ViewController, let animationFile {
                                    let resultController = UndoOverlayController(
                                        presentationData: presentationData,
                                        content: .sticker(context: context, file: animationFile, loop: false, title: presentationData.strings.Gift_View_Resale_SuccessYou_Title, text: presentationData.strings.Gift_View_Resale_SuccessYou_Text(giftTitle).string, undoText: nil, customAction: nil),
                                        elevatedLayout: !(lastController is ChatController),
                                        action: {  _ in
                                            return true
                                        }
                                    )
                                    lastController.present(resultController, in: .current)
                                }
                            })
                        } else {
                            var controllers = Array(navigationController.viewControllers.prefix(1))
                            let chatController = context.sharedContext.makeChatController(context: context, chatLocation: .peer(id: recipientPeerId), subject: nil, botStart: nil, mode: .standard(.default), params: nil)
                            chatController.hintPlayNextOutgoingGift()
                            controllers.append(chatController)
                            navigationController.setViewControllers(controllers, animated: true)
                            
                            Queue.mainQueue().after(0.5, {
                                let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: recipientPeerId))
                                |> deliverOnMainQueue).start(next: { [weak navigationController] peer in
                                    if let peer, let lastController = navigationController?.viewControllers.last as? ViewController, let animationFile {
                                        let resultController = UndoOverlayController(
                                            presentationData: presentationData,
                                            content: .sticker(context: context, file: animationFile, loop: false, title: presentationData.strings.Gift_View_Resale_Success_Title, text: presentationData.strings.Gift_View_Resale_Success_Text(peer.compactDisplayTitle).string, undoText: nil, customAction: nil),
                                            elevatedLayout: !(lastController is ChatController),
                                            action: {  _ in
                                                return true
                                            }
                                        )
                                        lastController.present(resultController, in: .current)
                                    }
                                })
                            })
                        }
                    }
                }
            )
        }
        
        func skipAnimation() {
            guard let arguments = self.subject.arguments, case let .unique(uniqueGift) = arguments.gift else {
                return
            }
            self.canSkip = false
            self.revealedNumberDigits = "\(uniqueGift.number)".count
            self.revealedAttributes.insert(.backdrop)
            self.revealedAttributes.insert(.pattern)
            self.revealedAttributes.insert(.model)
            
            self.updated(transition: .easeInOut(duration: 0.2))
        }
        
        func commitUpgrade() {
            let duration = Double.random(in: 0.85 ..< 2.25)
            let firstFraction = Double.random(in: 0.2 ..< 0.4)
            let secondFraction = Double.random(in: 0.2 ..< 0.4)
            let thirdFraction = 1.0 - firstFraction - secondFraction
            let firstDuration = duration * firstFraction
            let secondDuration = duration * secondFraction
            let thirdDuration = duration * thirdFraction
            
            if self.testUpgradeAnimation, let arguments = self.subject.arguments, case let .unique(uniqueGift) = arguments.gift {
                self.inProgress = true
                self.updated()
                
                if let controller = self.getController() as? GiftViewScreen {
                    controller.showBalance = false
                }
                
                Queue.mainQueue().after(0.5, {
                    self.canSkip = true
                    self.updated(transition: .immediate)
                    
                    self.inProgress = false
                    self.inUpgradePreview = false
                    
                    self.justUpgraded = true
                    self.revealedNumberDigits = -1
                    
                    for i in 0 ..< "\(uniqueGift.number)".count {
                        Queue.mainQueue().after(0.2 + Double(i) * 0.3) {
                            self.revealedNumberDigits += 1
                            self.updated(transition: .immediate)
                        }
                    }
                    
                    Queue.mainQueue().after(firstDuration) {
                        self.revealedAttributes.insert(.backdrop)
                        self.updated(transition: .immediate)
                        
                        Queue.mainQueue().after(secondDuration) {
                            self.revealedAttributes.insert(.pattern)
                            self.updated(transition: .immediate)
                            
                            Queue.mainQueue().after(thirdDuration) {
                                self.revealedAttributes.insert(.model)
                                self.updated(transition: .immediate)

                                Queue.mainQueue().after(0.55) {
                                    self.canSkip = false
                                    self.updated(transition: .easeInOut(duration: 0.2))
                                }
                                
                                Queue.mainQueue().after(0.6) {
                                    if let controller = self.getController() as? GiftViewScreen {
                                        controller.animateSuccess()
                                    }
                                }
                            }
                        }
                    }
                    
                    self.updated(transition: .spring(duration: 0.4))
                })
                return
            }
            
            guard let arguments = self.subject.arguments, let peerId = arguments.peerId, let starsContext = self.context.starsContext, let starsState = starsContext.currentState else {
                return
            }
                        
            let proceed: (Int64?) -> Void = { [weak self] formId in
                guard let self, let controller = self.getController() as? GiftViewScreen else {
                    return
                }
                self.inProgress = true
                self.updated()
                
                controller.showBalance = false
                
                let upgradeGiftImpl: ((Int64?, Bool) -> Signal<ProfileGiftsContext.State.StarGift, UpgradeStarGiftError>)
                if let upgradeGift = controller.upgradeGift {
                    guard let reference = arguments.reference else {
                        return
                    }
                    upgradeGiftImpl = { formId, keepOriginalInfo in
                        return upgradeGift(formId, reference, keepOriginalInfo)
                    }
                } else {
                    guard let reference = arguments.reference else {
                        return
                    }
                    upgradeGiftImpl = { formId, keepOriginalInfo in
                        return self.context.engine.payments.upgradeStarGift(formId: formId, reference: reference, keepOriginalInfo: keepOriginalInfo)
                    }
                }
            
                self.upgradeDisposable = (upgradeGiftImpl(formId, self.keepOriginalInfo)
                |> deliverOnMainQueue).start(next: { [weak self, weak starsContext] result in
                    guard let self, let controller = self.getController() as? GiftViewScreen else {
                        return
                    }
                    self.canSkip = true
                    self.updated(transition: .immediate)
                    
                    self.inProgress = false
                    self.inUpgradePreview = false
                    
                    if let reference = arguments.reference {
                        controller.upgradedGiftReferences.insert(reference)
                        self.nextGiftToUpgrade = controller.nextUpgradableGift
                    }
                     
                    self.justUpgraded = true
                    self.revealedNumberDigits = -1
                    
                    if case let .unique(uniqueGift) = result.gift {
                        for i in 0 ..< "\(uniqueGift.number)".count {
                            Queue.mainQueue().after(0.2 + Double(i) * 0.3) {
                                self.revealedNumberDigits += 1
                                self.updated(transition: .immediate)
                            }
                        }
                    }
                    
                    Queue.mainQueue().after(firstDuration) {
                        self.revealedAttributes.insert(.backdrop)
                        self.updated(transition: .immediate)
                        
                        Queue.mainQueue().after(secondDuration) {
                            self.revealedAttributes.insert(.pattern)
                            self.updated(transition: .immediate)
                            
                            Queue.mainQueue().after(thirdDuration) {
                                self.revealedAttributes.insert(.model)
                                self.updated(transition: .immediate)

                                Queue.mainQueue().after(0.55) {
                                    self.canSkip = false
                                    self.updated(transition: .easeInOut(duration: 0.2))
                                }
                                
                                Queue.mainQueue().after(0.6) {
                                    if let controller = self.getController() as? GiftViewScreen {
                                        controller.animateSuccess()
                                    }
                                }
                            }
                        }
                    }
                    
                    self.subject = .profileGift(peerId, result)
                    self.updated(transition: .spring(duration: 0.4))
                    
                    Queue.mainQueue().after(2.5) {
                        starsContext?.load(force: true)
                    }
                })
            }
            
            if let upgradeStars = arguments.upgradeStars, upgradeStars > 0 {
                proceed(nil)
            } else if let upgradeForm = self.upgradeForm, let price = upgradeForm.invoice.prices.first?.amount {
                if starsState.balance < StarsAmount(value: price, nanos: 0) {
                    let _ = (self.starsTopUpOptionsPromise.get()
                    |> filter { $0 != nil }
                    |> take(1)
                    |> deliverOnMainQueue).startStandalone(next: { [weak self] options in
                        guard let self, let controller = self.getController() else {
                            return
                        }
                        let purchaseController = self.context.sharedContext.makeStarsPurchaseScreen(
                            context: self.context,
                            starsContext: starsContext,
                            options: options ?? [],
                            purpose: .upgradeStarGift(requiredStars: price),
                            targetPeerId: nil,
                            customTheme: nil,
                            completion: { [weak self, weak starsContext] stars in
                                guard let self, let starsContext else {
                                    return
                                }
                                self.inProgress = true
                                self.updated()
                                
                                starsContext.add(balance: StarsAmount(value: stars, nanos: 0))
                                let _ = (starsContext.onUpdate
                                |> deliverOnMainQueue).start(next: {
                                    proceed(upgradeForm.id)
                                })
                            }
                        )
                        controller.push(purchaseController)
                    })
                } else {
                    proceed(upgradeForm.id)
                }
            } else {
                self.scheduledUpgradeCommit = true
                
                self.inProgress = true
                self.updated()
                
                Queue.mainQueue().after(5.0, {
                    if self.scheduledUpgradeCommit {
                        self.scheduledUpgradeCommit = false
                        self.inProgress = false
                        self.updated()
                        
                        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
                        let alertController = textAlertController(
                            context: self.context,
                            title: nil,
                            text: presentationData.strings.Login_UnknownError,
                            actions: [
                                TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
                            ],
                            parseMarkdown: true
                        )
                        if let controller = self.getController() {
                            controller.present(alertController, in: .window(.root))
                        }
                    }
                })
            }
        }
        
        func openUpgradePricePreview() {
            guard let controller = self.getController(), let upgradePreview = self.upgradePreview else {
                return
            }
            let costController = GiftUpgradeCostScreen(context: self.context, upgradePreview: upgradePreview)
            controller.push(costController)
        }
                
        func commitPrepaidUpgrade() {
            guard let arguments = self.subject.arguments, let controller = self.getController() as? GiftViewScreen, let peerId = arguments.peerId, let prepaidUpgradeHash = arguments.prepaidUpgradeHash, let starsContext = self.context.starsContext, let starsState = starsContext.currentState else {
                return
            }
            guard case let .generic(gift) = arguments.gift else {
                return
            }
            guard let gift = self.starGiftsMap[gift.id], let price = gift.upgradeStars else {
                return
            }
            let context = self.context
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let proceed: () -> Void = { [weak self, weak starsContext] in
                guard let self else {
                    return
                }
                self.inProgress = true
                self.updated()
                     
                let source: BotPaymentInvoiceSource = .starGiftPrepaidUpgrade(peerId: peerId, hash: prepaidUpgradeHash)
                let signal = context.engine.payments.fetchBotPaymentForm(source: source, themeParams: nil)
                |> map(Optional.init)
                |> `catch` { _ in
                    return .single(nil)
                }
                |> mapToSignal { paymentForm in
                    if let paymentForm {
                        return context.engine.payments.sendStarsPaymentForm(formId: paymentForm.id, source: source)
                    } else {
                        return .fail(.generic)
                    }
                }
                
                self.upgradeDisposable = (signal
                |> deliverOnMainQueue).start(next: { [weak self, weak controller, weak starsContext] result in
                    guard let self else {
                        return
                    }
                    Queue.mainQueue().after(2.5) {
                        starsContext?.load(force: true)
                    }
                    
                    let navigationController = controller?.navigationController as? NavigationController
                    let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                    |> deliverOnMainQueue).start(next: { [weak self, weak navigationController] peer in
                        guard let self, let peer else {
                            return
                        }
                        self.openPeer(peer, gifts: false, dismiss: true)
                        
                        Queue.mainQueue().after(0.5) {
                            if let lastController = navigationController?.viewControllers.last as? ViewController {
                                let resultController = UndoOverlayController(
                                    presentationData: presentationData,
                                    content: .sticker(
                                        context: context,
                                        file: gift.file,
                                        loop: false,
                                        title: nil,
                                        text: presentationData.strings.Gift_Upgrade_Gift_Sent_Text,
                                        undoText: presentationData.strings.Gift_Upgrade_Gift_Sent_GiftMore,
                                        customAction: nil
                                    ),
                                    elevatedLayout: !(lastController is ChatController),
                                    action: { [weak navigationController] action in
                                        if case .undo = action, let navigationController {
                                            let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                                            |> deliverOnMainQueue).start(next: { [weak navigationController] peer in
                                                guard let peer, let navigationController else {
                                                    return
                                                }
                                                if let controller = context.sharedContext.makePeerInfoController(
                                                    context: context,
                                                    updatedPresentationData: nil,
                                                    peer: peer._asPeer(),
                                                    mode: .upgradableGifts,
                                                    avatarInitiallyExpanded: false,
                                                    fromChat: false,
                                                    requestsContext: nil
                                                ) {
                                                    navigationController.pushViewController(controller, animated: true)
                                                }
                                            })
                                        }
                                        return true
                                    }
                                )
                                lastController.present(resultController, in: .current)
                            }
                        }
                    })
                }, error: { _ in
                    
                })
            }
            
            if starsState.balance < StarsAmount(value: price, nanos: 0) {
                let _ = (self.starsTopUpOptionsPromise.get()
                |> filter { $0 != nil }
                |> take(1)
                |> deliverOnMainQueue).startStandalone(next: { [weak self, weak controller] options in
                    guard let self, let controller else {
                        return
                    }
                    let purchaseController = self.context.sharedContext.makeStarsPurchaseScreen(
                        context: self.context,
                        starsContext: starsContext,
                        options: options ?? [],
                        purpose: .upgradeStarGift(requiredStars: price),
                        targetPeerId: nil,
                        customTheme: nil,
                        completion: { [weak self, weak starsContext] stars in
                            guard let self, let starsContext else {
                                return
                            }
                            self.inProgress = true
                            self.updated()
                            
                            starsContext.add(balance: StarsAmount(value: stars, nanos: 0))
                            let _ = (starsContext.onUpdate
                            |> deliverOnMainQueue).start(next: {
                                proceed()
                            })
                        }
                    )
                    controller.push(purchaseController)
                })
            } else {
                proceed()
            }
        }
        
        func switchToNextUpgradable() {
            if let controller = self.getController() as? GiftViewScreen {
                controller.switchToNextUpgradable()
            }
        }
        
        func openGiftBuyOffer() {
            guard let gift = self.subject.arguments?.gift, case let .unique(uniqueGift) = gift, case let .peerId(ownerPeerId) = uniqueGift.owner, let controller = self.getController() else {
                return
            }
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: ownerPeerId))
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                guard let self, let peer else {
                    return
                }
                let buyController = self.context.sharedContext.makeStarsWithdrawalScreen(context: self.context, subject: .starGiftOffer(peer: peer, gift: uniqueGift, completion: { [weak self] amount, duration in
                    guard let self else {
                        return
                    }
                    
                    let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.SendPaidMessageStars(id: peer.id))
                    |> deliverOnMainQueue).start(next: { [weak self, weak controller] sendPaidMessageStars in
                        guard let self else {
                            return
                        }
                        let action: (Int64?) -> Void = { allowPaidStars in
                            self.commitGiftBuyOffer(peer: peer, price: amount, duration: duration, allowPaidStars: allowPaidStars)
                        }
                        if let sendPaidMessageStars, sendPaidMessageStars.value > 0 {
                            let alertController = chatMessagePaymentAlertController(
                                context: nil,
                                presentationData: presentationData,
                                updatedPresentationData: nil,
                                peers: [EngineRenderedPeer(peer: peer)],
                                count: 1,
                                amount: sendPaidMessageStars,
                                totalAmount: nil,
                                hasCheck: false,
                                navigationController: controller?.navigationController as? NavigationController,
                                completion: { _ in
                                    action(sendPaidMessageStars.value)
                                }
                            )
                            controller?.present(alertController, in: .window(.root))
                        } else {
                            action(nil)
                        }
                    })
                }))
                controller.push(buyController)
            })
        }
        
        func commitGiftBuyOffer(peer: EnginePeer, price: CurrencyAmount, duration: Int32, allowPaidStars: Int64?) {
            guard let gift = self.subject.arguments?.gift, case let .unique(uniqueGift) = gift, let starsContext = self.context.starsContext, let starsState = starsContext.currentState else {
                return
            }
            
            let context = self.context
            let proceed = { [weak self, weak starsContext] in
                guard let self else {
                    return
                }
                self.upgradeDisposable = (context.engine.payments.sendStarGiftOffer(peerId: peer.id, slug: uniqueGift.slug, amount: price, duration: duration, allowPaidStars: allowPaidStars)
                |> deliverOnMainQueue).start(error: { _ in
                }, completed: { [weak self, weak starsContext] in
                    guard let self else {
                        return
                    }
                    Queue.mainQueue().after(2.5) {
                        starsContext?.load(force: true)
                    }
                    self.openPeer(peer, dismiss: true)
                })
            }
            
            if price.currency == .stars, starsState.balance < price.amount {
                let _ = (self.starsTopUpOptionsPromise.get()
                 |> filter { $0 != nil }
                 |> take(1)
                 |> deliverOnMainQueue).startStandalone(next: { [weak self] options in
                    guard let self, let controller = self.getController() else {
                        return
                    }
                    var finalStars = price.amount.value
                    if let allowPaidStars {
                        finalStars += allowPaidStars
                    }
                    let purchaseController = context.sharedContext.makeStarsPurchaseScreen(
                        context: context,
                        starsContext: starsContext,
                        options: options ?? [],
                        purpose: .starGiftOffer(requiredStars: finalStars),
                        targetPeerId: nil,
                        customTheme: nil,
                        completion: { [weak self, weak starsContext] stars in
                            guard let self, let starsContext else {
                                return
                            }
                            self.inProgress = true
                            self.updated()
                            
                            starsContext.add(balance: StarsAmount(value: stars, nanos: 0))
                            let _ = (starsContext.onUpdate
                            |> deliverOnMainQueue).start(next: { [weak self] in
                                guard let self else {
                                    return
                                }
                                Queue.mainQueue().after(0.1, { [weak self] in
                                    guard let self, let starsContext = self.context.starsContext, let starsState = starsContext.currentState else {
                                        return
                                    }
                                    if starsState.balance < price.amount {
                                        self.inProgress = false
                                        self.updated()
                                        
                                        self.commitGiftBuyOffer(peer: peer, price: price, duration: duration, allowPaidStars: allowPaidStars)
                                    } else {
                                        proceed()
                                    }
                                });
                            })
                        }
                    )
                    controller.push(purchaseController)
                })
            } else if price.currency == .ton, let tonState = context.tonContext?.currentState, tonState.balance < price.amount {
                guard let controller = self.getController() else {
                    return
                }
                let needed = price.amount - tonState.balance
                var fragmentUrl = "https://fragment.com/ads/topup"
                if let data = self.context.currentAppConfiguration.with({ $0 }).data, let value = data["ton_topup_url"] as? String {
                    fragmentUrl = value
                }
                controller.push(BalanceNeededScreen(
                    context: self.context,
                    amount: needed,
                    buttonAction: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.context.sharedContext.applicationBindings.openUrl(fragmentUrl)
                    }
                ))
            } else {
                proceed()
            }
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, subject: self.subject, animateOut: self.animateOut, getController: self.getController)
    }
    
    static var body: Body {
        let buttons = Child(GlassControlPanelComponent.self)
        let animation = Child(GiftCompositionComponent.self)
        let title = Child(MultilineTextComponent.self)
        let subtitle = Child(MultilineTextComponent.self)
        
        let descriptionButton = Child(PlainButtonComponent.self)
        let description = Child(MultilineTextComponent.self)
        let animatedDescription = Child(HStack<Empty>.self)
        
        let transferButton = Child(HeaderButtonComponent.self)
        let wearButton = Child(HeaderButtonComponent.self)
        let resellButton = Child(HeaderButtonComponent.self)
        
        let wearAvatar = Child(AvatarComponent.self)
        let wearPeerName = Child(MultilineTextComponent.self)
        let wearTitle = Child(MultilineTextComponent.self)
        let wearDescription = Child(MultilineTextComponent.self)
        let wearPerks = Child(List<Empty>.self)
        
        let hostedDescription = Child(MultilineTextComponent.self)
        let hiddenText = Child(MultilineTextComponent.self)
        let table = Child(TableComponent.self)
        let additionalText = Child(MultilineTextComponent.self)
        let button = Child(ButtonComponent.self)
        let upgradeNextButton = Child(PlainButtonComponent.self)
        
        let upgradeTitle = Child(MultilineTextComponent.self)
        let upgradeDescription = Child(GlassBarButtonComponent.self)
        let upgradePerks = Child(List<Empty>.self)
        let upgradeKeepName = Child(PlainButtonComponent.self)
        let upgradePriceButton = Child(PlainButtonComponent.self)
        let upgradeDescriptionMeasure = Child(MultilineTextComponent.self)
        
        let priceButtonMeasure = Child(MultilineTextWithEntitiesComponent.self)
        let priceButton = Child(GlassBarButtonComponent.self)
    
        let spaceRegex = try? NSRegularExpression(pattern: "\\[(.*?)\\]", options: [])
        
        let giftCompositionExternalState = GiftCompositionComponent.ExternalState()
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            
            let component = context.component
            let theme = environment.theme
            let strings = environment.strings
            let dateTimeFormat = environment.dateTimeFormat
            let nameDisplayOrder = component.context.sharedContext.currentPresentationData.with { $0 }.nameDisplayOrder
            let controller = environment.controller
            
            let state = context.state
            let subject = state.subject
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            
            var titleString: String
            var subtitleString: String?
            var animationFile: TelegramMediaFile?
            let stars: Int64
            let convertStars: Int64?
            let text: String?
            let entities: [MessageTextEntity]?
            var limitRemains: Int32?
            let limitTotal: Int32?
            var incoming = false
            var savedToProfile = false
            var converted = false
            var giftId: Int64 = 0
            var date: Int32?
            var soldOut = false
            var nameHidden = false
            var upgraded = false
            var exported = false
            var canUpgrade = false
            var upgradeStars: Int64?
            var genericGift:  StarGift.Gift?
            var uniqueGift: StarGift.UniqueGift?
            var isSelfGift = false
            var isChannelGift = false
            var isMyOwnedUniqueGift = false
            var isMyHostedUniqueGift = false
            var releasedByPeer: EnginePeer?
            var canGiftUpgrade = false
            var isDismantled = false
            
            if case let .soldOutGift(gift) = subject {
                animationFile = gift.file
                stars = gift.price
                text = nil
                entities = nil
                limitRemains = nil
                limitTotal = gift.availability?.total
                convertStars = nil
                soldOut = true
                titleString = strings.Gift_View_UnavailableTitle
            } else if let arguments = subject.arguments {
                if let toPeerId = arguments.auctionToPeerId {
                    isSelfGift = arguments.messageId?.peerId.isTelegramNotifications == true && toPeerId == component.context.account.peerId
                } else {
                    isSelfGift = arguments.messageId?.peerId == component.context.account.peerId
                }
                switch arguments.gift {
                case let .generic(gift):
                    if let releasedBy = gift.releasedBy, let peer = state.peerMap[releasedBy], let addressName = peer.addressName {
                        subtitleString = strings.Gift_View_ReleasedBy("[@\(addressName)]()").string
                        releasedByPeer = peer
                    }
                    genericGift = gift
                    animationFile = gift.file
                    stars = gift.price
                    text = arguments.text
                    entities = arguments.entities
                    limitRemains = gift.availability?.remains
                    limitTotal = gift.availability?.total
                    convertStars = arguments.convertStars
                    converted = arguments.converted
                    giftId = gift.id
                    date = arguments.date
                    upgraded = arguments.upgraded
                    canUpgrade = arguments.canUpgrade
                    upgradeStars = arguments.upgradeStars
                case let .unique(gift):
                    stars = 0
                    text = nil
                    entities = nil
                    limitRemains = nil
                    limitTotal = nil
                    convertStars = nil
                    uniqueGift = gift
                    if let hostPeerId = gift.hostPeerId {
                        if hostPeerId == component.context.account.peerId {
                            isMyHostedUniqueGift = true
                        } else if let reference = arguments.reference, case let .peer(peerId, _) = reference, peerId.namespace == Namespaces.Peer.CloudChannel, hostPeerId == peerId {
                            isMyHostedUniqueGift = true
                        }
                    }
                }
                savedToProfile = arguments.savedToProfile
                if let reference = arguments.reference, case let .peer(peerId, _) = reference, peerId.namespace == Namespaces.Peer.CloudChannel {
                    isChannelGift = true
                    incoming = true
                } else {
                    if let toPeerId = arguments.auctionToPeerId, toPeerId != component.context.account.peerId {
                        incoming = false
                    } else {
                        incoming = arguments.incoming || arguments.peerId == component.context.account.peerId
                    }
                }
                nameHidden = arguments.nameHidden
                canGiftUpgrade = arguments.prepaidUpgradeHash != nil
                
                if case let .peerId(peerId) = uniqueGift?.owner, peerId == component.context.account.peerId {
                    isMyOwnedUniqueGift = true
                }
                
                if let number = arguments.giftNumber, let title = genericGift?.title {
                    titleString = "\(title) **#\(formatCollectibleNumber(number, dateTimeFormat: environment.dateTimeFormat))**"
                } else if isSelfGift {
                    titleString = strings.Gift_View_Self_Title
                } else {
                    titleString = incoming ? strings.Gift_View_ReceivedTitle : strings.Gift_View_Title
                }
            } else {
                animationFile = nil
                stars = 0
                text = nil
                entities = nil
                limitTotal = nil
                convertStars = nil
                titleString = ""
            }
            
            if let uniqueGift, uniqueGift.owner == nil {
                isDismantled = true
            }
            
            if !canUpgrade, let gift = state.starGiftsMap[giftId], let _ = gift.upgradeStars {
                canUpgrade = true
            }
                                    
            var showUpgradePreview = false
            if state.inUpgradePreview, let _ = state.upgradePreview {
                showUpgradePreview = true
            } else if case .upgradePreview = component.subject {
                showUpgradePreview = true
            }
            
            var showWearPreview = false
            if state.inWearPreview {
                showWearPreview = true
            } else if case .wearPreview = component.subject {
                showWearPreview = true
            }
            
            var originY: CGFloat = 0.0
                        
            let headerHeight: CGFloat
            let headerSubject: GiftCompositionComponent.Subject?
            
            if let uniqueGift, !state.inUpgradePreview {
                if showWearPreview {
                    headerHeight = 200.0
                } else if isMyOwnedUniqueGift || isMyHostedUniqueGift || isChannelGift {
                    headerHeight = 314.0
                } else {
                    headerHeight = 240.0
                }
                headerSubject = .unique(state.justUpgraded ? state.upgradePreview?.attributes : nil, uniqueGift)
            } else if state.inUpgradePreview, let attributes = state.upgradePreview?.attributes {
                headerHeight = 246.0
                headerSubject = .preview(attributes)
            } else if case let .upgradePreview(_, attributes, _) = component.subject {
                headerHeight = 246.0
                headerSubject = .preview(attributes)
            } else if case let .wearPreview(_, attributes) = component.subject, let attributes {
                headerHeight = 200.0
                headerSubject = .preview(attributes)
            } else if let animationFile {
                headerHeight = 210.0
                headerSubject = .generic(animationFile)
            } else {
                headerHeight = 210.0
                headerSubject = nil
            }
            
            var buttonsBackground: GlassControlGroupComponent.Background = .panel
            if let uniqueGift, let backdropAttribute = uniqueGift.attributes.first(where: { attribute in
                if case .backdrop = attribute {
                    return true
                } else {
                    return false
                }
            }), case let .backdrop(_, _, _, outerColor, _, _, _) = backdropAttribute {
                buttonsBackground = .color(UIColor(rgb: UInt32(bitPattern: outerColor)).mixedWith(.white, alpha: 0.2))
            } else if showUpgradePreview, let backgroundColor = giftCompositionExternalState.backgroundColor {
                buttonsBackground = .color(backgroundColor.mixedWith(.white, alpha: 0.2))
            }
            
            var ownerPeerId: EnginePeer.Id?
            if let uniqueGift {
                if case let .peerId(peerId) = uniqueGift.owner {
                    ownerPeerId = peerId
                } else {
                    ownerPeerId = uniqueGift.hostPeerId
                }
            }
            let wearOwnerPeerId = ownerPeerId ?? component.context.account.peerId
            
            var wearPeerNameChild: _UpdatedChildComponent?
            if showWearPreview {
                var peerName = ""
                if let ownerPeer = state.peerMap[wearOwnerPeerId] {
                    peerName = ownerPeer.displayTitle(strings: strings, displayOrder: nameDisplayOrder)
                }
                wearPeerNameChild = wearPeerName.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: peerName,
                            font: Font.bold(20.0),
                            textColor: .white,
                            paragraphAlignment: .center
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 1
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                    transition: .immediate
                )
                
                let giftTitle: String
                if let uniqueGift {
                    if case .wearPreview = component.subject {
                        giftTitle = uniqueGift.title
                    } else {
                        giftTitle = "\(uniqueGift.title) #\(formatCollectibleNumber(uniqueGift.number, dateTimeFormat: environment.dateTimeFormat))"
                    }
                } else if let genericGift {
                    if let number = component.subject.arguments?.giftNumber {
                        giftTitle = "\(genericGift.title ?? "") #\(formatCollectibleNumber(number, dateTimeFormat: environment.dateTimeFormat))"
                    } else {
                        giftTitle = genericGift.title ?? ""
                    }
                } else {
                    giftTitle = ""
                }
                
                let wearTitle = wearTitle.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: strings.Gift_Wear_Wear(giftTitle).string,
                            font: Font.bold(24.0),
                            textColor: theme.actionSheet.primaryTextColor,
                            paragraphAlignment: .center
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 1
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude),
                    transition: .immediate
                )
                let wearDescription = wearDescription.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: strings.Gift_Wear_GetBenefits,
                            font: Font.regular(15.0),
                            textColor: theme.actionSheet.primaryTextColor,
                            paragraphAlignment: .center
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 1,
                        lineSpacing: 0.2
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 50.0, height: CGFloat.greatestFiniteMagnitude),
                    transition: .immediate
                )
                
                var titleOriginY = headerHeight + 10.0
                context.add(wearTitle
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: titleOriginY + wearTitle.size.height))
                    .appear(.default(alpha: true))
                    .disappear(.default(alpha: true))
                )
                titleOriginY += wearTitle.size.height
                titleOriginY += 10.0
                
                context.add(wearDescription
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: titleOriginY + wearDescription.size.height))
                    .appear(.default(alpha: true))
                    .disappear(.default(alpha: true))
                )
            }
            
            var animationOffset: CGPoint?
            var animationScale: CGFloat?
            if let wearPeerNameChild {
                animationOffset = CGPoint(x: wearPeerNameChild.size.width / 2.0 + 20.0 - 12.0, y: 79.0)
                animationScale = 0.19
            }
            
            var headerComponents: [() -> Void] = []
            
            let tableFont = Font.regular(15.0)
            let tableBoldFont = Font.semibold(15.0)
            let tableItalicFont = Font.italic(15.0)
            let tableBoldItalicFont = Font.semiboldItalic(15.0)
            let tableMonospaceFont = Font.monospace(15.0)
            let tableLargeMonospaceFont = Font.monospace(16.0)
            
            let tableTextColor = theme.list.itemPrimaryTextColor
            let tableLinkColor = theme.list.itemAccentColor
            
            var resellAmount: CurrencyAmount?
            var selling = false
            if let uniqueGift {
                if uniqueGift.resellForTonOnly {
                    resellAmount = uniqueGift.resellAmounts?.first(where: { $0.currency == .ton })
                } else {
                    resellAmount = uniqueGift.resellAmounts?.first(where: { $0.currency == .stars })
                }
            }
            
            if let headerSubject {
                let animation = animation.update(
                    component: GiftCompositionComponent(
                        context: component.context,
                        theme: environment.theme,
                        subject: headerSubject,
                        animationOffset: animationOffset,
                        animationScale: animationScale,
                        displayAnimationStars: showWearPreview,
                        revealedAttributes: state.revealedAttributes,
                        externalState: giftCompositionExternalState,
                        requestUpdate: { [weak state] transition in
                            state?.updated(transition: transition)
                        }
                    ),
                    availableSize: CGSize(width: context.availableSize.width, height: headerHeight),
                    transition: context.transition
                )
                headerComponents.append({
                    context.add(animation
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: headerHeight / 2.0))
                    )
                })
            }
            originY += headerHeight
            
            let vibrantColor: UIColor
            if let previewPatternColor = giftCompositionExternalState.previewPatternColor {
                vibrantColor = previewPatternColor.withMultiplied(hue: 1.0, saturation: 1.02, brightness: 1.25).mixedWith(UIColor.white, alpha: 0.3)
            } else {
                vibrantColor = UIColor.white.withAlphaComponent(0.6)
            }
            
            if let wearPeerNameChild {
                if let ownerPeer = state.peerMap[wearOwnerPeerId] {
                    let wearAvatar = wearAvatar.update(
                        component: AvatarComponent(
                            context: component.context,
                            theme: theme,
                            peer: ownerPeer
                        ),
                        environment: {},
                        availableSize: CGSize(width: 100.0, height: 100.0),
                        transition: context.transition
                    )
                    headerComponents.append({
                        context.add(wearAvatar
                            .position(CGPoint(x: context.availableSize.width / 2.0, y: 86.0))
                            .appear(.default(scale: true, alpha: true))
                            .disappear(.default(scale: true, alpha: true))
                        )
                    })
                }
                                                
                headerComponents.append({
                    context.add(wearPeerNameChild
                        .position(CGPoint(x: context.availableSize.width / 2.0 - 12.0, y: 167.0))
                        .appear(.default(alpha: true))
                        .disappear(.default(alpha: true))
                    )
                })
                originY += 91.0
                                
                let textColor = theme.actionSheet.primaryTextColor
                let secondaryTextColor = theme.actionSheet.secondaryTextColor
                let linkColor = theme.actionSheet.controlAccentColor
                
                var items: [AnyComponentWithIdentity<Empty>] = []
                items.append(
                    AnyComponentWithIdentity(
                        id: "badge",
                        component: AnyComponent(InfoParagraphComponent(
                            title: strings.Gift_Wear_Badge_Title,
                            titleColor: textColor,
                            text: isChannelGift ? strings.Gift_Wear_Badge_ChannelText : strings.Gift_Wear_Badge_Text,
                            textColor: secondaryTextColor,
                            accentColor: linkColor,
                            iconName: "Premium/Collectible/Badge",
                            iconColor: linkColor
                        ))
                    )
                )
                items.append(
                    AnyComponentWithIdentity(
                        id: "design",
                        component: AnyComponent(InfoParagraphComponent(
                            title: strings.Gift_Wear_Design_Title,
                            titleColor: textColor,
                            text: isChannelGift ? strings.Gift_Wear_Design_ChannelText : strings.Gift_Wear_Design_Text,
                            textColor: secondaryTextColor,
                            accentColor: linkColor,
                            iconName: "Premium/BoostPerk/CoverColor",
                            iconColor: linkColor
                        ))
                    )
                )
                items.append(
                    AnyComponentWithIdentity(
                        id: "proof",
                        component: AnyComponent(InfoParagraphComponent(
                            title: strings.Gift_Wear_Proof_Title,
                            titleColor: textColor,
                            text: isChannelGift ? strings.Gift_Wear_Proof_ChannelText : strings.Gift_Wear_Proof_Text,
                            textColor: secondaryTextColor,
                            accentColor: linkColor,
                            iconName: "Premium/Collectible/Proof",
                            iconColor: linkColor
                        ))
                    )
                )
                
                let perksSideInset = sideInset + 16.0
                let wearPerks = wearPerks.update(
                    component: List(items),
                    availableSize: CGSize(width: context.availableSize.width - perksSideInset * 2.0, height: 10000.0),
                    transition: context.transition
                )
                
                context.add(wearPerks
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + wearPerks.size.height / 2.0))
                    .appear(.default(alpha: true))
                    .disappear(.default(alpha: true))
                )
            
                originY += wearPerks.size.height
                originY += 16.0
            } else if showUpgradePreview {
                let title: String
                let uniqueText: String
                let tradableText: String
                if !incoming, case let .profileGift(peerId, _) = subject, let peer = state.peerMap[peerId] {
                    var peerName = peer.compactDisplayTitle
                    if peerName.count > 22 {
                        peerName = "\(peerName.prefix(22))…"
                    }
                    title = environment.strings.Gift_Upgrade_GiftTitle
                    uniqueText = strings.Gift_Upgrade_Unique_GiftDescription(peerName).string
                    tradableText = strings.Gift_Upgrade_Tradable_GiftDescription(peerName).string
                } else if case let .upgradePreview(_, _, peerName) = component.subject {
                    var peerName = peerName
                    if peerName.count > 22 {
                        peerName = "\(peerName.prefix(22))…"
                    }
                    title = environment.strings.Gift_Upgrade_IncludeTitle
                    uniqueText = strings.Gift_Upgrade_Unique_IncludeDescription
                    tradableText = strings.Gift_Upgrade_Tradable_IncludeDescription
                } else {
                    title = environment.strings.Gift_Upgrade_Title
                    uniqueText = strings.Gift_Upgrade_Unique_Description
                    tradableText = strings.Gift_Upgrade_Tradable_Description
                }
                
                var variant1: GiftItemComponent.Subject?
                var variant2: GiftItemComponent.Subject?
                var variant3: GiftItemComponent.Subject?
                
                var upgradeAttributes: [StarGift.UniqueGift.Attribute]?
                
                if case let .generic(gift) = component.subject.arguments?.gift {
                    variant1 = .starGift(gift: gift, price: "")
                    variant2 = .starGift(gift: gift, price: "")
                    variant3 = .starGift(gift: gift, price: "")
                }
                
                if let upgradePreview = state.upgradePreview {
                    upgradeAttributes = upgradePreview.attributes
                } else if case let .upgradePreview(_, attributes, _) = component.subject {
                    upgradeAttributes = attributes
                }

                if let upgradeAttributes {
                    var i = 0
                    for attribute in upgradeAttributes {
                        if case .model = attribute {
                            switch i {
                            case 0:
                                variant1 = .preview(attributes: [attribute], rarity: nil)
                            case 1:
                                variant2 = .preview(attributes: [attribute], rarity: nil)
                            case 2:
                                variant3 = .preview(attributes: [attribute], rarity: nil)
                            default:
                                break
                            }
                            i += 1
                        }
                    }
                }
                
                if let variant1, let variant2, let variant3 {
                    var buttonColor: UIColor = UIColor.white.withAlphaComponent(0.16)
                    if let backgroundColor = giftCompositionExternalState.backgroundColor {
                        buttonColor = backgroundColor.mixedWith(.white, alpha: 0.2)
                    }
                    
                    let upgradeDescriptionMeasure = upgradeDescriptionMeasure.update(
                        component: MultilineTextComponent(text: .plain(NSAttributedString(string: strings.Gift_Upgrade_ViewAllVariants, font: Font.semibold(13.0), textColor: .clear))),
                        availableSize: context.availableSize,
                        transition: .immediate
                    )
                    context.add(upgradeDescriptionMeasure
                        .position(CGPoint(x: -10000.0, y: -10000.0))
                    )
                    
                    let variantsButtonSize = CGSize(width: upgradeDescriptionMeasure.size.width + 87.0, height: 24.0)
                       
                    let upgradeTitle = upgradeTitle.update(
                        component: MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: title,
                                font: Font.bold(20.0),
                                textColor: .white,
                                paragraphAlignment: .center
                            )),
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 1
                        ),
                        availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                        transition: .immediate
                    )
                    let upgradeDescription = upgradeDescription.update(
                        component: GlassBarButtonComponent(
                            size: variantsButtonSize,
                            backgroundColor: buttonColor,
                            isDark: true,
                            state: .tintedGlass,
                            component: AnyComponentWithIdentity(id: "content", component: AnyComponent(
                                HStack([
                                    AnyComponentWithIdentity(id: "icon1", component: AnyComponent(
                                        GiftItemComponent(
                                            context: component.context,
                                            theme: theme,
                                            strings: strings,
                                            peer: nil,
                                            subject: variant1,
                                            isPlaceholder: false,
                                            mode: .tableIcon
                                        )
                                    )),
                                    AnyComponentWithIdentity(id: "icon2", component: AnyComponent(
                                        GiftItemComponent(
                                            context: component.context,
                                            theme: theme,
                                            strings: strings,
                                            peer: nil,
                                            subject: variant2,
                                            isPlaceholder: false,
                                            mode: .tableIcon
                                        )
                                    )),
                                    AnyComponentWithIdentity(id: "icon3", component: AnyComponent(
                                        GiftItemComponent(
                                            context: component.context,
                                            theme: theme,
                                            strings: strings,
                                            peer: nil,
                                            subject: variant3,
                                            isPlaceholder: false,
                                            mode: .tableIcon
                                        )
                                    )),
                                    AnyComponentWithIdentity(id: "text", component: AnyComponent(
                                        MultilineTextComponent(text: .plain(NSAttributedString(string: strings.Gift_Upgrade_ViewAllVariants, font: Font.semibold(13.0), textColor: .white)))
                                    )),
                                    AnyComponentWithIdentity(id: "arrow", component: AnyComponent(
                                        BundleIconComponent(name: "Item List/InlineTextRightArrow", tintColor: .white)
                                    ))
                                ], spacing: 3.0)
                            )),
                            action: { [weak state] _ in
                                state?.openUpgradeVariants()
                            }
                        ),
                        availableSize: variantsButtonSize,
                        transition: context.transition
                    )
                  
                    let spacing: CGFloat = 6.0
                    let totalHeight: CGFloat = upgradeTitle.size.height + spacing + upgradeDescription.size.height
                    
                    headerComponents.append({
                        context.add(upgradeTitle
                            .position(CGPoint(x: context.availableSize.width / 2.0, y: floor(194.0 - totalHeight / 2.0 + upgradeTitle.size.height / 2.0)))
                            .appear(.default(alpha: true))
                            .disappear(.default(alpha: true))
                        )
                        
                        context.add(upgradeDescription
                            .position(CGPoint(x: context.availableSize.width / 2.0, y: floor(198.0 + totalHeight / 2.0 - upgradeDescription.size.height / 2.0)))
                            .appear(.default(alpha: true))
                            .disappear(.default(alpha: true))
                        )
                    })
                }
                originY += 24.0
                
                let textColor = theme.actionSheet.primaryTextColor
                let secondaryTextColor = theme.actionSheet.secondaryTextColor
                let linkColor = theme.actionSheet.controlAccentColor
                
                var items: [AnyComponentWithIdentity<Empty>] = []
                items.append(
                    AnyComponentWithIdentity(
                        id: "unique",
                        component: AnyComponent(InfoParagraphComponent(
                            title: strings.Gift_Upgrade_Unique_Title,
                            titleColor: textColor,
                            text: uniqueText,
                            textColor: secondaryTextColor,
                            accentColor: linkColor,
                            iconName: "Premium/Collectible/Unique",
                            iconColor: linkColor
                        ))
                    )
                )
                items.append(
                    AnyComponentWithIdentity(
                        id: "tradable",
                        component: AnyComponent(InfoParagraphComponent(
                            title: strings.Gift_Upgrade_Tradable_Title,
                            titleColor: textColor,
                            text: tradableText,
                            textColor: secondaryTextColor,
                            accentColor: linkColor,
                            iconName: "Premium/Collectible/Tradable",
                            iconColor: linkColor
                        ))
                    )
                )
                items.append(
                    AnyComponentWithIdentity(
                        id: "wearable",
                        component: AnyComponent(InfoParagraphComponent(
                            title: strings.Gift_Upgrade_Wearable_Title,
                            titleColor: textColor,
                            text: strings.Gift_Upgrade_Wearable_Text,
                            textColor: secondaryTextColor,
                            accentColor: linkColor,
                            iconName: "Premium/Collectible/Wearable",
                            iconColor: linkColor
                        ))
                    )
                )
                
                let perksSideInset = sideInset + 16.0
                let upgradePerks = upgradePerks.update(
                    component: List(items),
                    availableSize: CGSize(width: context.availableSize.width - perksSideInset * 2.0, height: 10000.0),
                    transition: context.transition
                )
                context.add(upgradePerks
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + upgradePerks.size.height / 2.0))
                    .appear(.default(alpha: true))
                    .disappear(.default(alpha: true))
                )
                originY += upgradePerks.size.height
                originY += 16.0
                
                if case .upgradePreview = component.subject {
                } else if !incoming {
                } else {
                    let checkTheme = CheckComponent.Theme(
                        backgroundColor: theme.list.itemCheckColors.fillColor,
                        strokeColor: theme.list.itemCheckColors.foregroundColor,
                        borderColor: theme.list.itemCheckColors.strokeColor,
                        overlayBorder: false,
                        hasInset: false,
                        hasShadow: false
                    )
                    let keepInfoText: String
                    if let nameHidden = subject.arguments?.nameHidden, nameHidden {
                        keepInfoText = isChannelGift ? strings.Gift_Upgrade_AddChannelName : strings.Gift_Upgrade_AddMyName
                    } else {
                        keepInfoText = text != nil ? strings.Gift_Upgrade_AddNameAndComment : strings.Gift_Upgrade_AddName
                    }
                    let upgradeKeepName = upgradeKeepName.update(
                        component: PlainButtonComponent(
                            content: AnyComponent(HStack([
                                AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(CheckComponent(
                                    theme: checkTheme,
                                    size: CGSize(width: 18.0, height: 18.0),
                                    selected: state.keepOriginalInfo
                                ))),
                                AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(string: keepInfoText, font: Font.regular(13.0), textColor: theme.list.itemSecondaryTextColor))
                                )))
                            ],
                            spacing: 10.0
                            )),
                            effectAlignment: .center,
                            action: { [weak state] in
                                guard let state else {
                                    return
                                }
                                state.keepOriginalInfo = !state.keepOriginalInfo
                                state.updated(transition: .easeInOut(duration: 0.2))
                            },
                            animateAlpha: false,
                            animateScale: false
                        ),
                        availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 1000.0),
                        transition: context.transition
                    )
                    context.add(upgradeKeepName
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + upgradeKeepName.size.height / 2.0))
                        .appear(.default(alpha: true))
                        .disappear(.default(alpha: true))
                    )
                    originY += upgradeKeepName.size.height
                    originY += 18.0
                }
            } else {
                var descriptionText: String
                var hasDescriptionButton = false
                if let uniqueGift {
                    titleString = uniqueGift.title + " **#\(formatCollectibleNumber(uniqueGift.number, dateTimeFormat: environment.dateTimeFormat))**"
                    descriptionText = "\(strings.Gift_Unique_Collectible) #\(formatCollectibleNumber(uniqueGift.number, dateTimeFormat: environment.dateTimeFormat))"
                    for attribute in uniqueGift.attributes {
                        if case let .model(name, _, _, _) = attribute {
                            descriptionText = name
                        }
                    }
                    if let releasedBy = uniqueGift.releasedBy, let peer = state.peerMap[releasedBy], let addressName = peer.addressName {
                        descriptionText = strings.Gift_View_ReleasedBy("[@\(addressName)]()").string
                        hasDescriptionButton = true
                        releasedByPeer = peer
                    }
                } else if soldOut {
                    descriptionText = strings.Gift_View_UnavailableDescription
                } else if upgraded {
                    descriptionText = strings.Gift_View_UpgradedDescription
                } else if incoming {
                    if let _ = upgradeStars {
                        descriptionText = strings.Gift_View_FreeUpgradeDescription
                    } else if let gift = subject.arguments?.gift, case let .generic(gift) = gift, gift.availability != nil, !upgraded {
                        if canUpgrade || upgradeStars != nil {
                            if let upgradeStars, upgradeStars > 0 {
                                descriptionText = strings.Gift_View_UpgradeFreeDescription
                            } else {
                                descriptionText = strings.Gift_View_UpgradeDescription
                            }
                        } else {
                            descriptionText = strings.Gift_View_NoConvertDescription
                        }
                    } else if let convertStars, !upgraded {
                        if !converted {
                            descriptionText = isChannelGift ? strings.Gift_View_KeepOrConvertDescription_Channel(strings.Gift_View_KeepOrConvertDescription_Stars(Int32(clamping: convertStars))).string : strings.Gift_View_KeepOrConvertDescription(strings.Gift_View_KeepOrConvertDescription_Stars(Int32(clamping: convertStars))).string
                        } else {
                            descriptionText = strings.Gift_View_ConvertedDescription(strings.Gift_View_ConvertedDescription_Stars(Int32(clamping: convertStars))).string
                        }
                    } else {
                        descriptionText = strings.Gift_View_NoConvertDescription
                    }
                } else {
                    let recipientPeerId: EnginePeer.Id?
                    if let toPeerId = subject.arguments?.auctionToPeerId {
                        recipientPeerId = toPeerId
                    } else if let peerId = subject.arguments?.peerId {
                        recipientPeerId = peerId
                    } else {
                        recipientPeerId = nil
                    }
                    
                    if let recipientPeerId, let peer = state.peerMap[recipientPeerId] {
                        if let _ = upgradeStars {
                            descriptionText = strings.Gift_View_FreeUpgradeOtherDescription(peer.compactDisplayTitle).string
                        } else if case .message = subject {
                            if let gift = subject.arguments?.gift, case let .generic(gift) = gift, gift.availability != nil {
                                descriptionText = strings.Gift_View_OtherNoConvertDescription(peer.compactDisplayTitle).string
                            } else if let convertStars {
                                descriptionText = strings.Gift_View_OtherDescription(peer.compactDisplayTitle, strings.Gift_View_OtherDescription_Stars(Int32(clamping: convertStars))).string
                            } else {
                                descriptionText = ""
                            }
                        } else {
                            descriptionText = ""
                        }
                    } else {
                        descriptionText = ""
                    }
                }
                if let spaceRegex {
                    let nsRange = NSRange(descriptionText.startIndex..., in: descriptionText)
                    let matches = spaceRegex.matches(in: descriptionText, options: [], range: nsRange)
                    var modifiedString = descriptionText
                    
                    for match in matches.reversed() {
                        let matchRange = Range(match.range, in: descriptionText)!
                        let matchedSubstring = String(descriptionText[matchRange])
                        let replacedSubstring = matchedSubstring.replacingOccurrences(of: " ", with: "\u{00A0}")
                        modifiedString.replaceSubrange(matchRange, with: replacedSubstring)
                    }
                    descriptionText = modifiedString
                }
                
                let titleFont = Font.bold(20.0)
                let smallTitleFont = Font.bold(15.0)
                let numberFont: UIFont
                if let number = context.component.subject.arguments?.giftNumber, number < 1000 {
                    numberFont = titleFont
                } else {
                    numberFont = smallTitleFont
                }
                let titleAttributedString: NSAttributedString
                if let _ = uniqueGift {
                    titleAttributedString = parseMarkdownIntoAttributedString(titleString, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: titleFont, textColor: .white), bold: MarkdownAttributeSet(font: numberFont, textColor: vibrantColor), link: MarkdownAttributeSet(font: titleFont, textColor: .white), linkAttribute: { _ in return nil }), textAlignment: .center)
                } else {
                    titleAttributedString = parseMarkdownIntoAttributedString(titleString, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: titleFont, textColor: theme.actionSheet.primaryTextColor), bold: MarkdownAttributeSet(font: numberFont, textColor: theme.actionSheet.secondaryTextColor), link: MarkdownAttributeSet(font: titleFont, textColor: theme.actionSheet.primaryTextColor), linkAttribute: { _ in return nil }), textAlignment: .center)
                }
                
                let title = title.update(
                    component: MultilineTextComponent(
                        text: .plain(titleAttributedString),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 1
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                    transition: .immediate
                )
                headerComponents.append({
                    context.add(title
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: uniqueGift != nil ? 190.0 : 173.0))
                        .appear(.default(alpha: true))
                        .disappear(.default(alpha: true))
                    )
                })
                
                var descriptionOffset: CGFloat = 0.0
                if let subtitleString {
                    let textColor = theme.actionSheet.secondaryTextColor
                    let textFont = Font.regular(13.0)
                    let subtitleAttributedString = parseMarkdownIntoAttributedString(
                        subtitleString,
                        attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: textFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: theme.actionSheet.controlAccentColor), linkAttribute: { contents in
                            return (TelegramTextAttributes.URL, contents)
                        }),
                        textAlignment: .center
                    )
                    
                    let subtitle = subtitle.update(
                        component: MultilineTextComponent(
                            text: .plain(subtitleAttributedString),
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 1,
                            highlightColor: theme.actionSheet.controlAccentColor.withAlphaComponent(0.1),
                            highlightAction: { attributes in
                                if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                                    return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                                } else {
                                    return nil
                                }
                            },
                            tapAction: { [weak state] attributes, _ in
                                if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String, let peer = releasedByPeer {
                                    state?.openPeer(peer)
                                }
                            }
                        ),
                        availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                        transition: .immediate
                    )
                    headerComponents.append({
                        context.add(subtitle
                            .position(CGPoint(x: context.availableSize.width / 2.0, y: uniqueGift != nil ? 210.0 : 196.0))
                            .appear(.default(alpha: true))
                            .disappear(.default(alpha: true))
                        )
                    })
                    descriptionOffset += subtitle.size.height
                }
                
                if let resellAmount {
                    if incoming || ownerPeerId == component.context.account.peerId {
                        var valueString = formatCurrencyAmountText(resellAmount, dateTimeFormat: environment.dateTimeFormat)
                        switch resellAmount.currency {
                        case .stars:
                            valueString = "⭐️\(valueString)"
                        case .ton:
                            valueString = "💎\(valueString)"
                        }
                        let priceButtonAttributedString = NSMutableAttributedString(string: strings.Gift_View_OnSale(valueString).string, font: Font.regular(13.0), textColor: .white)
                        let starRange = (priceButtonAttributedString.string as NSString).range(of: "⭐️")
                        if starRange.location != NSNotFound {
                            priceButtonAttributedString.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: true)), range: starRange)
                            priceButtonAttributedString.addAttribute(.baselineOffset, value: 1.0, range: starRange)
                        }
                        let tonRange = (priceButtonAttributedString.string as NSString).range(of: "💎")
                        if tonRange.location != NSNotFound {
                            priceButtonAttributedString.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 1, file: nil, custom: .ton(tinted: true)), range: tonRange)
                            priceButtonAttributedString.addAttribute(.baselineOffset, value: 1.0, range: tonRange)
                        }

                        let priceButtonMeasure = priceButtonMeasure.update(
                            component: MultilineTextWithEntitiesComponent(
                                context: component.context,
                                animationCache: component.context.animationCache,
                                animationRenderer: component.context.animationRenderer,
                                placeholderColor: .white,
                                text: .plain(priceButtonAttributedString)
                            ),
                            availableSize: context.availableSize,
                            transition: context.transition
                        )
                        context.add(priceButtonMeasure
                            .position(CGPoint(x: -10000.0, y: -10000.0))
                        )
                        
                        var buttonColor: UIColor = UIColor(rgb: 0xffffff, alpha: 0.1)
                        if case let .color(color) = buttonsBackground {
                            buttonColor = color
                        }

                        let priceButtonSize = CGSize(width: priceButtonMeasure.size.width + 18.0, height: 19.0)
                        let priceButton = priceButton.update(
                            component: GlassBarButtonComponent(
                                size: priceButtonSize,
                                backgroundColor: buttonColor,
                                isDark: true,
                                state: .tintedGlass,
                                component: AnyComponentWithIdentity(id: "label", component: AnyComponent(
                                    MultilineTextWithEntitiesComponent(
                                        context: component.context,
                                        animationCache: component.context.animationCache,
                                        animationRenderer: component.context.animationRenderer,
                                        placeholderColor: .white,
                                        text: .plain(priceButtonAttributedString)
                                    )
                                )),
                                action: { [weak state] _ in
                                    state?.resellGift(update: true)
                                }
                            ),
                            availableSize: priceButtonSize,
                            transition: context.transition
                        )
                        headerComponents.append({
                            context.add(priceButton
                                .position(CGPoint(x: context.availableSize.width / 2.0, y: 207.0 + descriptionOffset + priceButton.size.height / 2.0))
                                .appear(.default(scale: true, alpha: true))
                                .disappear(.default(scale: true, alpha: true))
                            )
                        })
                        
                        descriptionText = ""
                        originY += 7.0
                    }
                    if case let .uniqueGift(_, recipientPeerId) = component.subject, recipientPeerId != nil {
                    } else if ownerPeerId != component.context.account.peerId {
                        selling = true
                    }
                }
                
                var useDescriptionTint = false
                if !descriptionText.isEmpty {
                    var linkColor = theme.actionSheet.controlAccentColor
                    if hasDescriptionButton {
                        linkColor = UIColor.white
                    }
                    
                    if state.cachedSmallStarImage == nil || state.cachedSmallStarImage?.1 !== environment.theme {
                        state.cachedSmallStarImage = (generateTintedImage(image: UIImage(bundleImageName: "Premium/Stars/ButtonStar"), color: .white)!, theme)
                    }
                    if state.cachedChevronImage == nil || state.cachedChevronImage?.1 !== environment.theme {
                        state.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Settings/TextArrowRight"), color: linkColor)!, theme)
                    }
                    
                    let textFont: UIFont
                    let textColor: UIColor
                    
                    if let _ = uniqueGift {
                        textFont = Font.regular(13.0)
                        if hasDescriptionButton {
                            textColor = vibrantColor.mixedWith(UIColor.white, alpha: 0.4)
                        } else {
                            textColor = vibrantColor
                            useDescriptionTint = true
                        }
                    } else {
                        textFont = soldOut ? Font.medium(15.0) : Font.regular(15.0)
                        textColor = soldOut ? theme.list.itemDestructiveColor : theme.list.itemPrimaryTextColor
                    }
                    let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: useDescriptionTint ? .white : textColor), bold: MarkdownAttributeSet(font: textFont, textColor: useDescriptionTint ? .white : textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
                        return (TelegramTextAttributes.URL, contents)
                    })
                    
                    descriptionText = descriptionText.replacingOccurrences(of: " >]", with: "\u{00A0}>]")
                    let attributedString = parseMarkdownIntoAttributedString(descriptionText, attributes: markdownAttributes, textAlignment: .center).mutableCopy() as! NSMutableAttributedString
                    if let range = attributedString.string.range(of: "*"), let starImage = state.cachedSmallStarImage?.0 {
                        attributedString.addAttribute(.font, value: Font.regular(13.0), range: NSRange(range, in: attributedString.string))
                        attributedString.addAttribute(.attachment, value: starImage, range: NSRange(range, in: attributedString.string))
                        attributedString.addAttribute(.baselineOffset, value: 1.0, range: NSRange(range, in: attributedString.string))
                    }
                    if let range = attributedString.string.range(of: ">"), let chevronImage = state.cachedChevronImage?.0 {
                        attributedString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: attributedString.string))
                    }
                    
                    var descriptionSize = CGSize()
                    if state.justUpgraded {
                        var items: [AnyComponentWithIdentity<Empty>] = [
                            AnyComponentWithIdentity(id: "label", component: AnyComponent(Text(text: "\(strings.Gift_Unique_Collectible) #", font: textFont, color: .white, tintColor: textColor)))
                        ]
                        
                        let numberFont = Font.with(size: 13.0, traits: .monospacedNumbers)
                        let spinningItems: [AnyComponentWithIdentity<Empty>] = [
                            AnyComponentWithIdentity(id: "0", component: AnyComponent(Text(text: "0", font: numberFont, color: textColor))),
                            AnyComponentWithIdentity(id: "1", component: AnyComponent(Text(text: "1", font: numberFont, color: textColor))),
                            AnyComponentWithIdentity(id: "2", component: AnyComponent(Text(text: "2", font: numberFont, color: textColor))),
                            AnyComponentWithIdentity(id: "3", component: AnyComponent(Text(text: "3", font: numberFont, color: textColor))),
                            AnyComponentWithIdentity(id: "4", component: AnyComponent(Text(text: "4", font: numberFont, color: textColor))),
                            AnyComponentWithIdentity(id: "5", component: AnyComponent(Text(text: "5", font: numberFont, color: textColor))),
                            AnyComponentWithIdentity(id: "6", component: AnyComponent(Text(text: "6", font: numberFont, color: textColor))),
                            AnyComponentWithIdentity(id: "7", component: AnyComponent(Text(text: "7", font: numberFont, color: textColor))),
                            AnyComponentWithIdentity(id: "8", component: AnyComponent(Text(text: "8", font: numberFont, color: textColor))),
                            AnyComponentWithIdentity(id: "9", component: AnyComponent(Text(text: "9", font: numberFont, color: textColor)))
                        ]
                        if let numberValue = uniqueGift?.number {
                            let numberString = formatCollectibleNumber(numberValue, dateTimeFormat: environment.dateTimeFormat)
                            var i = 0
                            var index = 0
                            for c in numberString {
                                let s = String(c)
                                if s == "\u{00A0}" {
                                    items.append(AnyComponentWithIdentity(id: "c\(i)", component: AnyComponent(Text(text: s, font: textFont, color: .white, tintColor: textColor)))
                                    )
                                } else if ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"].contains(s) {
                                    items.append(AnyComponentWithIdentity(id: "c\(i)", component: AnyComponent(SlotsComponent(
                                        item: AnyComponent(Text(text: String(c), font: numberFont, color: .white)),
                                        items: spinningItems,
                                        isAnimating: index > state.revealedNumberDigits,
                                        tintColor: textColor,
                                        verticalOffset: -1.0 - UIScreenPixel,
                                        motionBlur: false,
                                        size: CGSize(width: 8.0, height: 14.0))))
                                    )
                                    index += 1
                                } else {
                                    items.append(AnyComponentWithIdentity(id: "c\(i)", component: AnyComponent(Text(text: s, font: numberFont, color: .white, tintColor: textColor)))
                                    )
                                }
                                i += 1
                            }
                        }
                        let animatedDescription = animatedDescription.update(
                            component: HStack(items, spacing: 0.0),
                            availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 50.0, height: CGFloat.greatestFiniteMagnitude),
                            transition: context.transition
                        )
                        descriptionSize = animatedDescription.size
                        headerComponents.append({
                            context.add(animatedDescription
                                .position(CGPoint(x: context.availableSize.width / 2.0, y: 207.0 + descriptionOffset + animatedDescription.size.height / 2.0))
                                .appear(.default(alpha: true))
                                .disappear(.default(alpha: true))
                            )
                        })
                    } else {
                        let descriptionConstrainedWidth = hasDescriptionButton ? context.availableSize.width - sideInset : context.availableSize.width - sideInset * 2.0 - 50.0
                        let description = description.update(
                            component: MultilineTextComponent(
                                text: .plain(attributedString),
                                horizontalAlignment: .center,
                                maximumNumberOfLines: 5,
                                lineSpacing: 0.2,
                                tintColor: useDescriptionTint ? textColor : nil,
                                highlightColor: linkColor.withAlphaComponent(0.1),
                                highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                                highlightAction: { attributes in
                                    if !hasDescriptionButton, let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                                        return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                                    } else {
                                        return nil
                                    }
                                },
                                tapAction: { [weak state] attributes, _ in
                                    if !hasDescriptionButton, let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                                        state?.openStarsIntro()
                                    }
                                }
                            ),
                            availableSize: CGSize(width: descriptionConstrainedWidth, height: CGFloat.greatestFiniteMagnitude),
                            transition: context.transition
                        )
                        descriptionSize = description.size
                        headerComponents.append({
                            context.add(description
                                .position(CGPoint(x: context.availableSize.width / 2.0, y: 207.0 + descriptionOffset + description.size.height / 2.0))
                                .appear(.default(alpha: true))
                                .disappear(.default(alpha: true))
                            )
                        })
                        
                        if hasDescriptionButton {
                            let descriptionButton = descriptionButton.update(
                                component: PlainButtonComponent(
                                    content: AnyComponent(
                                        RoundedRectangle(color: UIColor.white.withAlphaComponent(0.15), cornerRadius: 9.5)
                                    ),
                                    effectAlignment: .center,
                                    action: { [weak state] in
                                        if let releasedByPeer {
                                            state?.openPeer(releasedByPeer)
                                        }
                                    },
                                    animateScale: false
                                ),
                                environment: {},
                                availableSize: CGSize(width: description.size.width + 18.0, height: description.size.height + 1.0),
                                transition: .immediate
                            )
                            headerComponents.append({
                                context.add(descriptionButton
                                    .position(CGPoint(x: context.availableSize.width / 2.0, y: 207.0 + descriptionOffset + description.size.height / 2.0 - 1.0))
                                    .appear(.default(alpha: true))
                                    .disappear(.default(alpha: true))
                                )
                            })
                        }
                    }
                    
                    originY += descriptionOffset
                    
                    if uniqueGift != nil {
                        originY += 16.0
                    } else {
                        originY += descriptionSize.height + 21.0
                        if soldOut {
                            originY -= 7.0
                        }
                    }
                } else {
                    originY += 9.0
                }
                
                if nameHidden && uniqueGift == nil {
                    let textFont = Font.regular(13.0)
                    let textColor = theme.list.itemSecondaryTextColor
                    
                    let hiddenDescription: String
                    if incoming {
                        hiddenDescription = text != nil ? strings.Gift_View_NameAndMessageHidden : strings.Gift_View_NameHidden
                    } else if subject.arguments?.fromPeerId != nil {
                        var recipientPeerId: EnginePeer.Id?
                        if let toPeerId = subject.arguments?.auctionToPeerId {
                            recipientPeerId = toPeerId
                        } else if let peerId = subject.arguments?.peerId {
                            recipientPeerId = peerId
                        }
                        if let recipientPeerId, let peer = state.peerMap[recipientPeerId] {
                            var peerName = peer.compactDisplayTitle
                            if peerName.count > 30 {
                                peerName = "\(peerName.prefix(30))…"
                            }
                            hiddenDescription = text != nil ? strings.Gift_View_Outgoing_NameAndMessageHidden(peerName).string : strings.Gift_View_Outgoing_NameHidden(peerName).string
                        } else {
                            hiddenDescription = ""
                        }
                    } else {
                        hiddenDescription = ""
                    }

                    if !hiddenDescription.isEmpty {
                        let hiddenText = hiddenText.update(
                            component: MultilineTextComponent(
                                text: .plain(NSAttributedString(string: hiddenDescription, font: textFont, textColor: textColor)),
                                horizontalAlignment: .center,
                                maximumNumberOfLines: 2,
                                lineSpacing: 0.2
                            ),
                            availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                            transition: .immediate
                        )
                        context.add(hiddenText
                            .position(CGPoint(x: context.availableSize.width / 2.0, y: originY))
                            .appear(.default(alpha: true))
                            .disappear(.default(alpha: true))
                        )
                        
                        originY += hiddenText.size.height
                        originY += 11.0
                    }
                }
                
                var tableItems: [TableComponent.Item] = []
                
                var isWearing = state.pendingWear
                
                if !soldOut {
                    if let uniqueGift {
                        switch uniqueGift.owner {
                        case let .peerId(peerId):
                            if let peer = state.peerMap[peerId] {
                                let ownerComponent: AnyComponent<Empty>
                                if peer.id == component.context.account.peerId, peer.isPremium {
                                    let animationContent: EmojiStatusComponent.Content
                                    var color: UIColor?
                                    var statusId: Int64 = 1
                                    if state.pendingWear {
                                        var fileId: Int64?
                                        for attribute in uniqueGift.attributes {
                                            if case let .model(_, file, _, _) = attribute {
                                                fileId = file.fileId.id
                                            }
                                            if case let .backdrop(_, _, innerColor, _, _, _, _) = attribute {
                                                color = UIColor(rgb: UInt32(bitPattern: innerColor))
                                            }
                                        }
                                        if let fileId {
                                            statusId = fileId
                                            animationContent = .animation(content: .customEmoji(fileId: fileId), size: CGSize(width: 18.0, height: 18.0), placeholderColor: theme.list.mediaPlaceholderColor, themeColor: tableLinkColor, loopMode: .count(2))
                                        } else {
                                            animationContent = .premium(color: tableLinkColor)
                                        }
                                    } else if let emojiStatus = peer.emojiStatus, !state.pendingTakeOff {
                                        animationContent = .animation(content: .customEmoji(fileId: emojiStatus.fileId), size: CGSize(width: 18.0, height: 18.0), placeholderColor: theme.list.mediaPlaceholderColor, themeColor: tableLinkColor, loopMode: .count(2))
                                        if case let .starGift(id, _, _, _, _, innerColor, _, _, _) = emojiStatus.content {
                                            color = UIColor(rgb: UInt32(bitPattern: innerColor))
                                            if id == uniqueGift.id {
                                                isWearing = true
                                                state.pendingWear = false
                                            }
                                        }
                                    } else {
                                        animationContent = .premium(color: tableLinkColor)
                                        state.pendingTakeOff = false
                                    }
                                    
                                    ownerComponent = AnyComponent(
                                        HStack([
                                            AnyComponentWithIdentity(
                                                id: AnyHashable(0),
                                                component: AnyComponent(Button(
                                                    content: AnyComponent(
                                                        PeerTableCellComponent(
                                                            context: component.context,
                                                            theme: theme,
                                                            strings: strings,
                                                            peer: peer
                                                        )
                                                    ),
                                                    action: { [weak state] in
                                                        state?.openPeer(peer)
                                                    }
                                                ))
                                            ),
                                            AnyComponentWithIdentity(
                                                id: AnyHashable(statusId),
                                                component: AnyComponent(EmojiStatusComponent(
                                                    context: component.context,
                                                    animationCache: component.context.animationCache,
                                                    animationRenderer: component.context.animationRenderer,
                                                    content: animationContent,
                                                    particleColor: color,
                                                    size: CGSize(width: 18.0, height: 18.0),
                                                    isVisibleForAnimations: true,
                                                    action: {
                                                        
                                                    },
                                                    tag: state.statusTag
                                                ))
                                            )
                                        ], spacing: 2.0)
                                    )
                                } else {
                                    ownerComponent = AnyComponent(Button(
                                        content: AnyComponent(
                                            PeerTableCellComponent(
                                                context: component.context,
                                                theme: theme,
                                                strings: strings,
                                                peer: peer
                                            )
                                        ),
                                        action: { [weak state] in
                                            state?.openPeer(peer)
                                        }
                                    ))
                                }
                                tableItems.append(.init(
                                    id: "owner",
                                    title: strings.Gift_Unique_Owner,
                                    component: ownerComponent
                                ))
                            }
                        case let .name(name):
                            tableItems.append(.init(
                                id: "name_owner",
                                title: strings.Gift_Unique_Owner,
                                component: AnyComponent(
                                    MultilineTextComponent(text: .plain(NSAttributedString(string: name, font: tableFont, textColor: tableTextColor)))
                                )
                            ))
                        case let .address(address):
                            exported = true
                            
                            tableItems.append(.init(
                                id: "address_owner",
                                title: strings.Gift_Unique_Owner,
                                component: AnyComponent(
                                    Button(
                                        content: AnyComponent(
                                            MultilineTextComponent(text: .plain(NSAttributedString(string: address, font: tableLargeMonospaceFont, textColor: tableLinkColor)), truncationType: .middle, maximumNumberOfLines: 1, lineSpacing: 0.2)
                                        ),
                                        action: { [weak state] in
                                            state?.copyAddress(address)
                                        }
                                    )
                                )
                            ))
                        default:
                            break
                        }
                        
                        if let peerId = uniqueGift.hostPeerId, let peer = state.peerMap[peerId] {
                            tableItems.append(.init(
                                id: "telegram",
                                title: strings.Gift_Unique_Telegram,
                                component: AnyComponent(Button(
                                    content: AnyComponent(
                                        PeerTableCellComponent(
                                            context: component.context,
                                            theme: theme,
                                            strings: strings,
                                            peer: peer
                                        )
                                    ),
                                    action: { [weak state] in
                                        state?.openPeer(peer)
                                    }
                                ))
                            ))
                        }
                        
                    } else if let peerId = subject.arguments?.fromPeerId, var peer = state.peerMap[peerId] {
                        if let toPeerId = subject.arguments?.auctionToPeerId, toPeerId != component.context.account.peerId, let selfPeer =  state.peerMap[component.context.account.peerId] {
                            peer = selfPeer
                        }
                        var isBot = false
                        if case let .user(user) = peer, user.botInfo != nil {
                            isBot = true
                        }
                        let fromComponent: AnyComponent<Empty>
                        if incoming && !peer.isDeleted && !isBot && !isChannelGift {
                            fromComponent = AnyComponent(
                                HStack([
                                    AnyComponentWithIdentity(
                                        id: AnyHashable(0),
                                        component: AnyComponent(Button(
                                            content: AnyComponent(
                                                PeerTableCellComponent(
                                                    context: component.context,
                                                    theme: theme,
                                                    strings: strings,
                                                    peer: peer
                                                )
                                            ),
                                            action: { [weak state] in
                                                state?.openPeer(peer)
                                            }
                                        ))
                                    ),
                                    AnyComponentWithIdentity(
                                        id: AnyHashable(1),
                                        component: AnyComponent(Button(
                                            content: AnyComponent(ButtonContentComponent(
                                                context: component.context,
                                                text: strings.Gift_View_Send,
                                                color: theme.list.itemAccentColor
                                            )),
                                            action: { [weak state] in
                                                state?.sendGift(peerId: peerId)
                                            }
                                        ))
                                    )
                                ], spacing: 4.0)
                            )
                        } else {
                            fromComponent = AnyComponent(Button(
                                content: AnyComponent(
                                    PeerTableCellComponent(
                                        context: component.context,
                                        theme: theme,
                                        strings: strings,
                                        peer: peer
                                    )
                                ),
                                action: { [weak state] in
                                    state?.openPeer(peer)
                                }
                            ))
                        }
                        if !isSelfGift {
                            tableItems.append(.init(
                                id: "from",
                                title: strings.Gift_View_From,
                                component: fromComponent
                            ))
                        }
                    } else {
                        if !isSelfGift {
                            tableItems.append(.init(
                                id: "from_anon",
                                title: strings.Gift_View_From,
                                component: AnyComponent(
                                    PeerTableCellComponent(
                                        context: component.context,
                                        theme: theme,
                                        strings: strings,
                                        peer: nil
                                    )
                                )
                            ))
                        }
                    }
                }
                
                if let uniqueGift {
                    if isMyOwnedUniqueGift || isMyHostedUniqueGift || isChannelGift {
                        var canTransfer = true
                        var canResell = true
                        
                        if case let .peerId(peerId) = uniqueGift.owner, let peer = state.peerMap[peerId], case let .channel(channel) = peer {
                            if !channel.flags.contains(.isCreator) {
                                canTransfer = false
                            }
                            canResell = false
                        } else if subject.arguments?.transferStars == nil {
                            canTransfer = false
                        }
                        
                        var buttonsCount = 1
                        if canTransfer {
                            buttonsCount += 1
                        }
                        if canResell {
                            buttonsCount += 1
                        }
                        
                        let buttonSpacing: CGFloat = 10.0
                        let buttonWidth = floor(context.availableSize.width - sideInset * 2.0 - buttonSpacing * CGFloat(buttonsCount - 1)) / CGFloat(buttonsCount)
                        let buttonHeight: CGFloat = 58.0
                        
                        var buttonColor: UIColor = UIColor(rgb: 0xffffff, alpha: 0.1)
                        if case let .color(color) = buttonsBackground {
                            buttonColor = color
                        }
                        
                        var buttonOriginX = sideInset
                        if canTransfer {
                            let transferButton = transferButton.update(
                                component: HeaderButtonComponent(
                                    title: strings.Gift_View_Header_Transfer,
                                    buttonColor: buttonColor,
                                    iconName: "Premium/Collectible/Transfer",
                                    isLocked: isMyHostedUniqueGift,
                                    action: { [weak state] in
                                        state?.transferGift()
                                    }
                                ),
                                environment: {},
                                availableSize: CGSize(width: buttonWidth, height: buttonHeight),
                                transition: context.transition
                            )
                            let buttonPosition = buttonOriginX + buttonWidth / 2.0
                            headerComponents.append({
                                context.add(transferButton
                                    .position(CGPoint(x: buttonPosition, y: headerHeight - buttonHeight / 2.0 - 16.0))
                                    .appear(.default(scale: true, alpha: true))
                                    .disappear(.default(scale: true, alpha: true))
                                )
                            })
                            buttonOriginX += buttonWidth + buttonSpacing
                        }
                        
                        let wearButton = wearButton.update(
                            component: HeaderButtonComponent(
                                title: isWearing ? strings.Gift_View_Header_TakeOff : strings.Gift_View_Header_Wear,
                                buttonColor: buttonColor,
                                iconName: isWearing ? "Premium/Collectible/Unwear" : "Premium/Collectible/Wear",
                                action: { [weak state] in
                                    if let state {
                                        if isWearing {
                                            state.commitTakeOff()
                                            
                                            state.showAttributeInfo(tag: state.statusTag, text: strings.Gift_View_TookOff("\(uniqueGift.title) #\(formatCollectibleNumber(uniqueGift.number, dateTimeFormat: environment.dateTimeFormat))").string)
                                        } else {
                                            if let controller = controller() as? GiftViewScreen {
                                                controller.dismissAllTooltips()
                                            }
                                            
                                            let canWear: Bool
                                            if isChannelGift, case let .channel(channel) = state.peerMap[wearOwnerPeerId] {
                                                let premiumConfiguration = PremiumConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
                                                let requiredLevel = Int(BoostSubject.wearGift.requiredLevel(group: false, context: component.context, configuration: premiumConfiguration))
                                                if let boostLevel = channel.approximateBoostLevel {
                                                    canWear = boostLevel >= requiredLevel
                                                } else {
                                                    canWear = false
                                                }
                                            } else {
                                                canWear = component.context.isPremium
                                            }
                                            let _ = (ApplicationSpecificNotice.getStarGiftWearTips(accountManager: component.context.sharedContext.accountManager)
                                                     |> deliverOnMainQueue).start(next: { [weak state] count in
                                                guard let state else {
                                                    return
                                                }
                                                if !canWear || count < 3 {
                                                    state.requestWearPreview()
                                                } else {
                                                    state.commitWear(uniqueGift)
                                                    state.showAttributeInfo(tag: state.statusTag, text: strings.Gift_View_PutOn("\(uniqueGift.title) #\(formatCollectibleNumber(uniqueGift.number, dateTimeFormat: environment.dateTimeFormat))").string)
                                                }
                                            })
                                        }
                                    }
                                }
                            ),
                            environment: {},
                            availableSize: CGSize(width: buttonWidth, height: buttonHeight),
                            transition: context.transition
                        )
                        let buttonPosition = buttonOriginX + buttonWidth / 2.0
                        headerComponents.append({
                            context.add(wearButton
                                .position(CGPoint(x: buttonPosition, y: headerHeight - buttonHeight / 2.0 - 16.0))
                                .appear(.default(scale: true, alpha: true))
                                .disappear(.default(scale: true, alpha: true))
                            )
                        })
                        buttonOriginX += buttonWidth + buttonSpacing
                        
                        if canResell {
                            let resellButton = resellButton.update(
                                component: HeaderButtonComponent(
                                    title: (uniqueGift.resellAmounts ?? []).isEmpty ? strings.Gift_View_Sell : strings.Gift_View_Unlist,
                                    buttonColor: buttonColor,
                                    iconName: (uniqueGift.resellAmounts ?? []).isEmpty ? "Premium/Collectible/Sell" : "Premium/Collectible/Unlist",
                                    isLocked: isMyHostedUniqueGift,
                                    action: { [weak state] in
                                        state?.resellGift()
                                    }
                                ),
                                environment: {},
                                availableSize: CGSize(width: buttonWidth, height: buttonHeight),
                                transition: context.transition
                            )
                            let buttonPosition = buttonOriginX + buttonWidth / 2.0
                            headerComponents.append({
                                context.add(resellButton
                                    .position(CGPoint(x: buttonPosition, y: headerHeight - buttonHeight / 2.0 - 16.0))
                                    .appear(.default(scale: true, alpha: true))
                                    .disappear(.default(scale: true, alpha: true))
                                )
                            })
                        }
                    }
                    
                    if isMyHostedUniqueGift, let address = uniqueGift.giftAddress {
                        let textFont = Font.regular(13.0)
                        let textColor = theme.list.itemSecondaryTextColor
                        let linkColor = theme.actionSheet.controlAccentColor
                        
                        if state.cachedSmallChevronImage == nil || state.cachedSmallChevronImage?.1 !== environment.theme {
                            state.cachedSmallChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextRightArrow"), color: linkColor)!, theme)
                        }
                        
                        let addressToOpen = address
                        var descriptionText = strings.Gift_View_TonGiftAddressInfo
                         
                        let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: textFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
                            return (TelegramTextAttributes.URL, contents)
                        })
                        
                        descriptionText = descriptionText.replacingOccurrences(of: " >]", with: "\u{00A0}>]")
                        let attributedString = parseMarkdownIntoAttributedString(descriptionText, attributes: markdownAttributes, textAlignment: .center).mutableCopy() as! NSMutableAttributedString
                        if let range = attributedString.string.range(of: ">"), let chevronImage = state.cachedSmallChevronImage?.0 {
                            attributedString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: attributedString.string))
                        }
                        
                        originY += 1.0
                        let hostedDescription = hostedDescription.update(
                            component: MultilineTextComponent(
                                text: .plain(attributedString),
                                horizontalAlignment: .center,
                                maximumNumberOfLines: 5,
                                lineSpacing: 0.2,
                                insets: UIEdgeInsets(top: 0.0, left: 2.0, bottom: 0.0, right: 2.0),
                                highlightColor: linkColor.withAlphaComponent(0.1),
                                highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                                highlightAction: { attributes in
                                    if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                                        return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                                    } else {
                                        return nil
                                    }
                                },
                                tapAction: { [weak state] attributes, _ in
                                    if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                                        state?.openAddress(addressToOpen)
                                    }
                                }
                            ),
                            availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                            transition: .immediate
                        )
                        context.add(hostedDescription
                            .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + hostedDescription.size.height / 2.0))
                            .appear(.default(alpha: true))
                            .disappear(.default(alpha: true))
                        )
                        originY += hostedDescription.size.height
                        originY += 14.0
                    }
                                 
                    let order: [StarGift.UniqueGift.Attribute.AttributeType] = [
                        .model, .pattern, .backdrop, .originalInfo
                    ]
                    
                    var attributeMap: [StarGift.UniqueGift.Attribute.AttributeType: StarGift.UniqueGift.Attribute] = [:]
                    for attribute in uniqueGift.attributes {
                        attributeMap[attribute.attributeType] = attribute
                    }
                    
                    var hasOriginalInfo = false
                    for type in order {
                        if let attribute = attributeMap[type] {
                            var id: String
                            let title: String?
                            let value: NSAttributedString
                            let rarity: StarGift.UniqueGift.Attribute.Rarity?
                            let tag: AnyObject?
                            var hasBackground = false
                            
                            var otherValuesAndPercentages: [(value: String, percentage: Float)] = []
                            
                            switch attribute {
                            case let .model(name, _, rarityValue, _):
                                id = "model"
                                title = strings.Gift_Unique_Model
                                value = NSAttributedString(string: name, font: tableFont, textColor: tableTextColor)
                                rarity = rarityValue
                                tag = state.modelButtonTag
                                
                                if state.justUpgraded, let sampleAttributes = state.upgradePreview?.attributes {
                                    for sampleAttribute in sampleAttributes {
                                        if case let .model(name, _, rarity, _) = sampleAttribute {
                                            otherValuesAndPercentages.append((name, Float(rarity.permilleValue) * 0.1))
                                        }
                                    }
                                }
                            case let .backdrop(name, _, _, _, _, _, rarityValue):
                                id = "backdrop"
                                title = strings.Gift_Unique_Backdrop
                                value = NSAttributedString(string: name, font: tableFont, textColor: tableTextColor)
                                rarity = rarityValue
                                tag = state.backdropButtonTag
                                
                                if state.justUpgraded, let sampleAttributes = state.upgradePreview?.attributes {
                                    for sampleAttribute in sampleAttributes {
                                        if case let .backdrop(name, _, _, _, _, _, rarity) = sampleAttribute {
                                            otherValuesAndPercentages.append((name, Float(rarity.permilleValue) * 0.1))
                                        }
                                    }
                                }
                            case let .pattern(name, _, rarityValue):
                                id = "pattern"
                                title = strings.Gift_Unique_Symbol
                                value = NSAttributedString(string: name, font: tableFont, textColor: tableTextColor)
                                rarity = rarityValue
                                tag = state.symbolButtonTag
                                
                                if state.justUpgraded, let sampleAttributes = state.upgradePreview?.attributes {
                                    for sampleAttribute in sampleAttributes {
                                        if case let .pattern(name, _, rarity) = sampleAttribute {
                                            otherValuesAndPercentages.append((name, Float(rarity.permilleValue) * 0.1))
                                        }
                                    }
                                }
                            case let .originalInfo(senderPeerId, recipientPeerId, date, text, entities):
                                id = "originalInfo"
                                title = nil
                                hasBackground = false
                                
                                let tableFont = Font.regular(13.0)
                                let tableBoldFont = Font.semibold(13.0)
                                let tableItalicFont = Font.italic(13.0)
                                let tableBoldItalicFont = Font.semiboldItalic(13.0)
                                let tableMonospaceFont = Font.monospace(13.0)
                                
                                let senderName = (senderPeerId.flatMap { state.peerMap[$0]?.displayTitle(strings: strings, displayOrder: nameDisplayOrder) })
                                let recipientName = state.peerMap[recipientPeerId]?.displayTitle(strings: strings, displayOrder: nameDisplayOrder) ?? ""
                                
                                let dateString = stringForMediumDate(timestamp: date, strings: strings, dateTimeFormat: dateTimeFormat, withTime: false)
                                if let text {
                                    let attributedText = stringWithAppliedEntities(text, entities: entities ?? [], baseColor: tableTextColor, linkColor: tableLinkColor, baseFont: tableFont, linkFont: tableFont, boldFont: tableBoldFont, italicFont: tableItalicFont, boldItalicFont: tableBoldItalicFont, fixedFont: tableMonospaceFont, blockQuoteFont: tableFont, message: nil)
                                    
                                    let format = senderName != nil ? strings.Gift_Unique_OriginalInfoSenderWithText(senderName!, recipientName, dateString, "") : strings.Gift_Unique_OriginalInfoWithText(recipientName, dateString, "")
                                    let string = NSMutableAttributedString(string: format.string, font: tableFont, textColor: tableTextColor)
                                    string.replaceCharacters(in: format.ranges[format.ranges.count - 1].range, with: attributedText)
                                    if let senderPeerId {
                                        string.addAttribute(.foregroundColor, value: tableLinkColor, range: format.ranges[0].range)
                                        string.addAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention), value: TelegramPeerMention(peerId: senderPeerId, mention: ""), range: format.ranges[0].range)
                                        string.addAttribute(.foregroundColor, value: tableLinkColor, range: format.ranges[1].range)
                                        string.addAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention), value: TelegramPeerMention(peerId: recipientPeerId, mention: ""), range: format.ranges[1].range)
                                    } else {
                                        string.addAttribute(.foregroundColor, value: tableLinkColor, range: format.ranges[0].range)
                                        string.addAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention), value: TelegramPeerMention(peerId: recipientPeerId, mention: ""), range: format.ranges[0].range)
                                    }
                                    value = string
                                } else {
                                    let format = senderName != nil ? strings.Gift_Unique_OriginalInfoSender(senderName!, recipientName, dateString) : strings.Gift_Unique_OriginalInfo(recipientName, dateString)
                                    let string = NSMutableAttributedString(string: format.string, font: tableFont, textColor: tableTextColor)
                                    if let senderPeerId {
                                        string.addAttribute(.foregroundColor, value: tableLinkColor, range: format.ranges[0].range)
                                        string.addAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention), value: TelegramPeerMention(peerId: senderPeerId, mention: ""), range: format.ranges[0].range)
                                        string.addAttribute(.foregroundColor, value: tableLinkColor, range: format.ranges[1].range)
                                        string.addAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention), value: TelegramPeerMention(peerId: recipientPeerId, mention: ""), range: format.ranges[1].range)
                                    } else {
                                        string.addAttribute(.foregroundColor, value: tableLinkColor, range: format.ranges[0].range)
                                        string.addAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention), value: TelegramPeerMention(peerId: recipientPeerId, mention: ""), range: format.ranges[0].range)
                                    }
                                    
                                    value = string
                                }
                                rarity = nil
                                tag = nil
                                hasOriginalInfo = true
                            }
                            
                            if !otherValuesAndPercentages.isEmpty {
                                id += "_reel"
                            }
                            
                            var items: [AnyComponentWithIdentity<Empty>] = []
                            items.append(
                                AnyComponentWithIdentity(
                                    id: AnyHashable(0),
                                    component: AnyComponent(
                                        MultilineTextWithEntitiesComponent(
                                            context: component.context,
                                            animationCache: component.context.animationCache,
                                            animationRenderer: component.context.animationRenderer,
                                            placeholderColor: theme.list.mediaPlaceholderColor,
                                            text: .plain(value),
                                            horizontalAlignment: .left,
                                            maximumNumberOfLines: 0,
                                            insets: id == "originalInfo" ? UIEdgeInsets(top: 2.0, left: 0.0, bottom: 2.0, right: 0.0) : .zero,
                                            spoilerColor: tableTextColor,
                                            highlightColor: tableLinkColor.withAlphaComponent(0.1),
                                            handleSpoilers: true,
                                            maxWidth: id == "originalInfo" ? context.availableSize.width - sideInset * 2.0 - 68.0 : nil,
                                            highlightAction: { attributes in
                                                if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] {
                                                    return NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)
                                                } else {
                                                    return nil
                                                }
                                            },
                                            tapAction: { [weak state] attributes, _ in
                                                guard let state else {
                                                    return
                                                }
                                                if let mention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention, let peer = state.peerMap[mention.peerId] {
                                                    state.openPeer(peer)
                                                }
                                            }
                                        )
                                    )
                                )
                            )
                            if let rarity, let tag {
                                let badgeString: String
                                var badgeColor: UIColor = theme.list.itemAccentColor
                                switch rarity {
                                case let .permille(value):
                                    if value == 0 {
                                        badgeString = "<\(formatPercentage(0.1))"
                                    } else {
                                        badgeString = formatPercentage(Float(value) * 0.1)
                                    }
                                case .epic:
                                    badgeString = strings.Gift_Attribute_Epic
                                    badgeColor = UIColor(rgb: 0xaf52de)
                                case .legendary:
                                    badgeString = strings.Gift_Attribute_Legendary
                                    badgeColor = UIColor(rgb: 0xd57e32)
                                case .rare:
                                    badgeString = strings.Gift_Attribute_Rare
                                    badgeColor = UIColor(rgb: 0x25a3b9)
                                case .uncommon:
                                    badgeString = strings.Gift_Attribute_Uncommon
                                    badgeColor = UIColor(rgb: 0x22b447)
                                }
                                items.append(AnyComponentWithIdentity(
                                    id: AnyHashable(1),
                                    component: AnyComponent(Button(
                                        content: AnyComponent(ButtonContentComponent(
                                            context: component.context,
                                            text: badgeString,
                                            color: badgeColor
                                        )),
                                        action: { [weak state] in
                                            state?.openUpgradeVariants(attribute: attribute)
                                        }
                                    ).tagged(tag))
                                ))
                            }
                            
                            var itemAlignment: HStackAlignment = .left
                            var itemSpacing: CGFloat = 4.0
                            if id == "originalInfo", let _ = subject.arguments?.dropOriginalDetailsStars {
                                items.append(AnyComponentWithIdentity(
                                    id: AnyHashable(1),
                                    component: AnyComponent(Button(
                                        content: AnyComponent(BundleIconComponent(name: "Chat/Context Menu/Delete", tintColor: tableLinkColor)),
                                        action: { [weak state] in
                                            state?.openDropOriginalDetails()
                                        }
                                    ))
                                ))
                                itemAlignment = .alternatingLeftRight
                                itemSpacing = 8.0
                            }
                            
                            var itemComponent = AnyComponent(
                                HStack(items, spacing: itemSpacing, alignment: itemAlignment)
                            )
                            
                            if !otherValuesAndPercentages.isEmpty {
                                var subitems: [AnyComponentWithIdentity<Empty>] = []
                                var index = 0
                                
                                for (title, percentage) in otherValuesAndPercentages {
                                    subitems.append(
                                        AnyComponentWithIdentity(id: "anim_\(index)", component: AnyComponent(
                                            HStack([
                                                AnyComponentWithIdentity(id: "label", component: AnyComponent(Text(text: title, font: tableFont, color: tableTextColor))),
                                                AnyComponentWithIdentity(id: "rarity", component: AnyComponent(ButtonContentComponent(
                                                    context: component.context,
                                                    text: formatPercentage(percentage),
                                                    color: theme.list.itemAccentColor
                                                )))
                                            ], spacing: 4.0)
                                        ))
                                    )
                                    index += 1
                                }
                                
                                itemComponent = AnyComponent(
                                    SlotsComponent(
                                        item: itemComponent,
                                        items: subitems,
                                        isAnimating: !state.revealedAttributes.contains(type),
                                        motionBlur: false,
                                        size:  CGSize(width: 160.0, height: 18.0)
                                    )
                                )
                            }
                            
                            tableItems.append(.init(
                                id: id,
                                title: title,
                                hasBackground: hasBackground,
                                component: itemComponent
                            ))
                        }
                    }
                    
                    let issuedString = presentationStringsFormattedNumber(uniqueGift.availability.issued, environment.dateTimeFormat.groupingSeparator)
                    let totalString = presentationStringsFormattedNumber(uniqueGift.availability.total, environment.dateTimeFormat.groupingSeparator)
                    tableItems.insert(.init(
                        id: "availability",
                        title: strings.Gift_Unique_Availability,
                        component: AnyComponent(
                            MultilineTextComponent(text: .plain(NSAttributedString(string: strings.Gift_Unique_Issued("\(issuedString)/\(totalString)").string, font: tableFont, textColor: tableTextColor)))
                        )
                    ), at: hasOriginalInfo ? tableItems.count - 1 : tableItems.count)
                    
                    if let valueAmount = uniqueGift.valueAmount, let valueCurrency = uniqueGift.valueCurrency, !isDismantled {
                        tableItems.insert(.init(
                            id: "fiatValue",
                            title: strings.Gift_Unique_Value,
                            component: AnyComponent(
                                HStack([
                                    AnyComponentWithIdentity(
                                        id: AnyHashable(0),
                                        component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: "~\(formatCurrencyAmount(valueAmount, currency: valueCurrency))", font: tableFont, textColor: tableTextColor))))
                                    ),
                                    AnyComponentWithIdentity(
                                        id: AnyHashable(1),
                                        component: AnyComponent(Button(
                                            content: AnyComponent(ButtonContentComponent(
                                                context: component.context,
                                                text: strings.Gift_Unique_LearnMore,
                                                color: theme.list.itemAccentColor
                                            )),
                                            action: { [weak state] in
                                                state?.openValue()
                                            }
                                        ))
                                    )
                                ], spacing: 4.0)
                            ),
                            insets: UIEdgeInsets(top: 0.0, left: 10.0, bottom: 0.0, right: 12.0)
                        ), at: hasOriginalInfo ? tableItems.count - 1 : tableItems.count)
                    }
                } else {
                    if case let .soldOutGift(gift) = subject, let soldOut = gift.soldOut {
                        tableItems.append(.init(
                            id: "firstDate",
                            title: strings.Gift_View_FirstSale,
                            component: AnyComponent(
                                MultilineTextComponent(text: .plain(NSAttributedString(string: stringForMediumDate(timestamp: soldOut.firstSale, strings: strings, dateTimeFormat: dateTimeFormat), font: tableFont, textColor: tableTextColor)))
                            )
                        ))
                        
                        tableItems.append(.init(
                            id: "lastDate",
                            title: strings.Gift_View_LastSale,
                            component: AnyComponent(
                                MultilineTextComponent(text: .plain(NSAttributedString(string: stringForMediumDate(timestamp: soldOut.lastSale, strings: strings, dateTimeFormat: dateTimeFormat), font: tableFont, textColor: tableTextColor)))
                            )
                        ))
                    } else if let date {
                        tableItems.append(.init(
                            id: "date",
                            title: strings.Gift_View_Date,
                            component: AnyComponent(
                                MultilineTextComponent(text: .plain(NSAttributedString(string: stringForMediumDate(timestamp: date, strings: strings, dateTimeFormat: dateTimeFormat), font: tableFont, textColor: tableTextColor)))
                            )
                        ))
                    }
                    
                    var finalStars = stars
                    if let upgradeStars, upgradeStars > 0 {
                        finalStars += upgradeStars
                    }
                    let valueString = "\(presentationStringsFormattedNumber(abs(Int32(clamping: finalStars)), dateTimeFormat.groupingSeparator))⭐️"
                    let valueAttributedString = NSMutableAttributedString(string: valueString, font: tableFont, textColor: tableTextColor)
                    let range = (valueAttributedString.string as NSString).range(of: "⭐️")
                    if range.location != NSNotFound {
                        valueAttributedString.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: false)), range: range)
                        valueAttributedString.addAttribute(.baselineOffset, value: 1.0, range: range)
                    }
                    
                    var canConvert = true
                    if let reference = subject.arguments?.reference, case let .peer(peerId, _) = reference {
                        if let peer = state.peerMap[peerId], case let .channel(channel) = peer, !channel.flags.contains(.isCreator) {
                            canConvert = false
                        }
                    }
                    
                    if canConvert, let date = subject.arguments?.date {
                        let configuration = GiftConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
                        let starsConvertMaxDate = date + configuration.convertToStarsPeriod
                        
                        let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                        if currentTime > starsConvertMaxDate {
                            canConvert = false
                        }
                    }
                    
                    if let convertStars, incoming && !converted && canConvert {
                        tableItems.append(.init(
                            id: "value_convert",
                            title: strings.Gift_View_Value,
                            component: AnyComponent(
                                HStack([
                                    AnyComponentWithIdentity(
                                        id: AnyHashable(0),
                                        component: AnyComponent(MultilineTextWithEntitiesComponent(
                                            context: component.context,
                                            animationCache: component.context.animationCache,
                                            animationRenderer: component.context.animationRenderer,
                                            placeholderColor: theme.list.mediaPlaceholderColor,
                                            text: .plain(valueAttributedString),
                                            maximumNumberOfLines: 0
                                        ))
                                    ),
                                    AnyComponentWithIdentity(
                                        id: AnyHashable(1),
                                        component: AnyComponent(Button(
                                            content: AnyComponent(ButtonContentComponent(
                                                context: component.context,
                                                text: strings.Gift_View_Sale(strings.Gift_View_Sale_Stars(Int32(clamping: convertStars))).string,
                                                color: theme.list.itemAccentColor
                                            )),
                                            action: { [weak state] in
                                                state?.convertToStars()
                                            }
                                        ))
                                    )
                                ], spacing: 4.0)
                            ),
                            insets: UIEdgeInsets(top: 0.0, left: 10.0, bottom: 0.0, right: 12.0)
                        ))
                    } else {
                        tableItems.append(.init(
                            id: "value",
                            title: strings.Gift_View_Value,
                            component: AnyComponent(MultilineTextWithEntitiesComponent(
                                context: component.context,
                                animationCache: component.context.animationCache,
                                animationRenderer: component.context.animationRenderer,
                                placeholderColor: theme.list.mediaPlaceholderColor,
                                text: .plain(valueAttributedString),
                                maximumNumberOfLines: 0
                            )),
                            insets: UIEdgeInsets(top: 0.0, left: 10.0, bottom: 0.0, right: 12.0)
                        ))
                    }
                                        
                    if let limitTotal {
                        var remains: Int32 = limitRemains ?? 0
                        if let gift = state.starGiftsMap[giftId], let availability = gift.availability {
                            remains = availability.remains
                        }
                        let remainsString = presentationStringsFormattedNumber(remains, environment.dateTimeFormat.groupingSeparator)
                        let totalString = presentationStringsFormattedNumber(limitTotal, environment.dateTimeFormat.groupingSeparator)
                        tableItems.append(.init(
                            id: "availability",
                            title: strings.Gift_View_Availability,
                            component: AnyComponent(
                                MultilineTextComponent(text: .plain(NSAttributedString(string: strings.Gift_View_Availability_NewOf("\(remainsString)", "\(totalString)").string, font: tableFont, textColor: tableTextColor)))
                            )
                        ))
                    }
                    
                    if !soldOut && canUpgrade {
                        tableItems.append(.init(
                            id: "status",
                            title: strings.Gift_View_Status,
                            component: AnyComponent(
                                MultilineTextComponent(text: .plain(NSAttributedString(string: strings.Gift_View_Status_NonUnique, font: tableFont, textColor: tableTextColor)))
                            ),
                            insets: UIEdgeInsets(top: 0.0, left: 10.0, bottom: 0.0, right: 12.0)
                        ))
                    }
                                        
                    if let text {
                        let attributedText = stringWithAppliedEntities(text, entities: entities ?? [], baseColor: tableTextColor, linkColor: tableLinkColor, baseFont: tableFont, linkFont: tableFont, boldFont: tableBoldFont, italicFont: tableItalicFont, boldItalicFont: tableBoldItalicFont, fixedFont: tableMonospaceFont, blockQuoteFont: tableFont, message: nil)
                        
                        tableItems.append(.init(
                            id: "text",
                            title: nil,
                            component: AnyComponent(
                                MultilineTextWithEntitiesComponent(
                                    context: component.context,
                                    animationCache: component.context.animationCache,
                                    animationRenderer: component.context.animationRenderer,
                                    placeholderColor: theme.list.mediaPlaceholderColor,
                                    text: .plain(attributedText),
                                    maximumNumberOfLines: 0,
                                    insets: UIEdgeInsets(top: 1.0, left: 0.0, bottom: 1.0, right: 0.0),
                                    handleSpoilers: true
                                )
                            )
                        ))
                    }
                }
                
                let table = table.update(
                    component: TableComponent(
                        theme: theme,
                        items: tableItems
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude),
                    transition: context.transition
                )
                context.add(table
                    .clipsToBounds(true)
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + table.size.height / 2.0))
                    .appear(.default(alpha: true))
                    .disappear(ComponentTransition.Disappear({ view, transition, completion in
                        view.superview?.insertSubview(view, at: 0)
                        transition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                            completion()
                        })
                    }))
                )
                originY += table.size.height + 23.0
            }
            
            for component in headerComponents {
                component()
            }
                        
            var isChatTheme = false
            if let controller = controller() as? GiftViewScreen, controller.openChatTheme != nil {
                isChatTheme = true
            }
            if ((incoming && !converted && !upgraded) || exported || selling || isChatTheme) && (!showUpgradePreview && !showWearPreview && !isDismantled) {
                let textFont = Font.regular(13.0)
                let textColor = theme.list.itemSecondaryTextColor
                let linkColor = theme.actionSheet.controlAccentColor
                
                if state.cachedSmallChevronImage == nil || state.cachedSmallChevronImage?.1 !== environment.theme {
                    state.cachedSmallChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextRightArrow"), color: linkColor)!, theme)
                }
                if state.cachedHiddenImage == nil || state.cachedHiddenImage?.1 !== environment.theme {
                    state.cachedHiddenImage = (generateTintedImage(image: UIImage(bundleImageName: "Premium/Collectible/Hidden"), color: textColor)!, theme)
                }
                
                var addressToOpen: String?
                var descriptionText: String
                if isChatTheme {
                    descriptionText = strings.Gift_View_OpenChatTheme
                } else if let uniqueGift, selling {
                    let ownerName: String
                    if case let .peerId(peerId) = uniqueGift.owner {
                        ownerName = state.peerMap[peerId]?.compactDisplayTitle ?? ""
                    } else {
                        ownerName = ""
                    }
                    descriptionText = strings.Gift_View_SellingGiftInfo(ownerName).string
                } else if let uniqueGift, let address = uniqueGift.giftAddress, case .address = uniqueGift.owner, !isMyHostedUniqueGift {
                    addressToOpen = address
                    descriptionText = strings.Gift_View_TonGiftAddressInfo
                } else {
                    if canUpgrade || savedToProfile {
                        if isChannelGift {
                            descriptionText = savedToProfile ? strings.Gift_View_DisplayedInfoChannelNew : strings.Gift_View_HiddenInfoChannelNew
                        } else {
                            descriptionText = savedToProfile ? strings.Gift_View_DisplayedInfoNew : strings.Gift_View_HiddenInfoNew
                        }
                    } else {
                        descriptionText = isChannelGift ? strings.Gift_View_UniqueHiddenInfo_Channel : strings.Gift_View_UniqueHiddenInfo
                    }
                    if !savedToProfile {
                        descriptionText = "#   \(descriptionText)"
                    }
                }
                
                let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: textFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
                    return (TelegramTextAttributes.URL, contents)
                })
                
                descriptionText = descriptionText.replacingOccurrences(of: " >]", with: "\u{00A0}>]")
                let attributedString = parseMarkdownIntoAttributedString(descriptionText, attributes: markdownAttributes, textAlignment: .center).mutableCopy() as! NSMutableAttributedString
                if let range = attributedString.string.range(of: ">"), let chevronImage = state.cachedSmallChevronImage?.0 {
                    attributedString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: attributedString.string))
                }
                if let range = attributedString.string.range(of: "#"), let hiddenImage = state.cachedHiddenImage?.0 {
                    attributedString.addAttribute(.attachment, value: hiddenImage, range: NSRange(range, in: attributedString.string))
                    attributedString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: attributedString.string))
                }
                
                originY -= 5.0
                let additionalText = additionalText.update(
                    component: MultilineTextComponent(
                        text: .plain(attributedString),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 5,
                        lineSpacing: 0.2,
                        insets: UIEdgeInsets(top: 0.0, left: 2.0, bottom: 0.0, right: 2.0),
                        highlightColor: linkColor.withAlphaComponent(0.1),
                        highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                        highlightAction: { attributes in
                            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                                return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                            } else {
                                return nil
                            }
                        },
                        tapAction: { [weak state] attributes, _ in
                            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                                if isChatTheme, let controller = controller() as? GiftViewScreen {
                                    state?.dismiss(animated: true)
                                    controller.openChatTheme?()
                                } else if let addressToOpen {
                                    state?.openAddress(addressToOpen)
                                } else {
                                    state?.updateSavedToProfile(!savedToProfile)
                                    Queue.mainQueue().after(0.6, {
                                        state?.dismiss(animated: false)
                                    })
                                }
                            }
                        }
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                    transition: .immediate
                )
                context.add(additionalText
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + additionalText.size.height / 2.0))
                    .appear(.default(alpha: true))
                    .disappear(.default(alpha: true))
                )
                originY += additionalText.size.height
                originY += 16.0
            }
            
            let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: environment.safeInsets.bottom, innerDiameter: 52.0, sideInset: 30.0)
            let buttonSize = CGSize(width: context.availableSize.width - buttonInsets.left - buttonInsets.right, height: 52.0)
            let buttonBackground = ButtonComponent.Background(
                style: .glass,
                color: theme.list.itemCheckColors.fillColor,
                foreground: theme.list.itemCheckColors.foregroundColor,
                pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
            )
                        
            let buttonChild: _UpdatedChildComponent
            if state.canSkip {
                buttonChild = button.update(
                    component: ButtonComponent(
                        background: buttonBackground,
                        content: AnyComponentWithIdentity(
                            id: AnyHashable("skip"),
                            component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: strings.Gift_Upgrade_Skip, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center))))
                        ),
                        isEnabled: true,
                        displaysProgress: state.inProgress,
                        action: { [weak state] in
                            if let state {
                                state.skipAnimation()
                            }
                        }),
                    availableSize: buttonSize,
                    transition: context.transition
                )
            } else if showWearPreview, let uniqueGift {
                let buttonContent: AnyComponentWithIdentity<Empty>
                
                let premiumConfiguration = PremiumConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
                let requiredLevel = Int(BoostSubject.wearGift.requiredLevel(group: false, context: component.context, configuration: premiumConfiguration))
                
                var canWear = true
                if isChannelGift, case let .channel(channel) = state.peerMap[wearOwnerPeerId], (channel.approximateBoostLevel ?? 0) < requiredLevel {
                    canWear = false
                    buttonContent = AnyComponentWithIdentity(
                        id: AnyHashable("wear_channel"),
                        component: AnyComponent(
                            VStack([
                                AnyComponentWithIdentity(
                                    id: AnyHashable("label"),
                                    component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: strings.Gift_Wear_Start, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center))))
                                ),
                                AnyComponentWithIdentity(
                                    id: AnyHashable("level"),
                                    component: AnyComponent(PremiumLockButtonSubtitleComponent(
                                        count: requiredLevel,
                                        theme: theme,
                                        strings: strings
                                    ))
                                )
                            ], spacing: 3.0)
                        )
                    )
                } else if !isChannelGift && !component.context.isPremium {
                    canWear = false
                    buttonContent = AnyComponentWithIdentity(
                        id: AnyHashable("wear_premium"),
                        component: AnyComponent(
                            HStack([
                                AnyComponentWithIdentity(
                                    id: AnyHashable("icon"),
                                    component: AnyComponent(BundleIconComponent(name: "Chat/Stickers/Lock", tintColor: theme.list.itemCheckColors.foregroundColor))
                                ),
                                AnyComponentWithIdentity(
                                    id: AnyHashable("label"),
                                    component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: strings.Gift_Wear_Start, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center))))
                                )
                            ], spacing: 3.0)
                        )
                    )
                } else {
                    buttonContent = AnyComponentWithIdentity(
                        id: AnyHashable("wear"),
                        component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: strings.Gift_Wear_Start, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center))))
                    )
                }
                
                buttonChild = button.update(
                    component: ButtonComponent(
                        background: buttonBackground,
                        content: buttonContent,
                        isEnabled: true,
                        displaysProgress: false,
                        action: { [weak state] in
                            if let state {
                                let context = component.context
                                if !canWear, let controller = controller() as? GiftViewScreen {
                                    controller.dismissAllTooltips()
                                    
                                    if isChannelGift {
                                        state.levelsDisposable.set(combineLatest(
                                            queue: Queue.mainQueue(),
                                            context.engine.peers.getChannelBoostStatus(peerId: wearOwnerPeerId),
                                            context.engine.peers.getMyBoostStatus()
                                        ).startStandalone(next: { [weak controller, weak state] boostStatus, myBoostStatus in
                                            guard let controller, let state, let boostStatus, let myBoostStatus else {
                                                return
                                            }
                                            state.dismiss(animated: true)
                                            
                                            let levelsController = context.sharedContext.makePremiumBoostLevelsController(context: context, peerId: wearOwnerPeerId, subject: .wearGift, boostStatus: boostStatus, myBoostStatus: myBoostStatus, forceDark: false, openStats: nil)
                                            controller.push(levelsController)
                                            
                                            HapticFeedback().impact(.light)
                                        }))
                                    } else {
                                        let isTablet = environment.metrics.isTablet
                                        
                                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                        let text = strings.Gift_View_TooltipPremiumWearing
                                        let tooltipController = UndoOverlayController(
                                            presentationData: presentationData,
                                            content: .premiumPaywall(title: nil, text: text, customUndoText: nil, timeout: nil, linkAction: nil),
                                            position: .bottom,
                                            animateInAsReplacement: false,
                                            appearance: isTablet ? nil : UndoOverlayController.Appearance(sideInset: 16.0, bottomInset: 62.0),
                                            action: { [weak controller, weak state] action in
                                                if case .info = action {
                                                    controller?.dismissAllTooltips()
                                                    let premiumController = context.sharedContext.makePremiumIntroController(context: context, source: .messageEffects, forceDark: false, dismissed: nil)
                                                    controller?.push(premiumController)
                                                    
                                                    Queue.mainQueue().after(0.6, {
                                                        state?.dismiss(animated: false)
                                                    })
                                                }
                                                return false
                                            }
                                        )
                                        controller.present(tooltipController, in: isTablet ? .current : .window(.root))
                                    }
                                } else {
                                    state.commitWear(uniqueGift)
                                    if case .wearPreview = component.subject {
                                        state.dismiss(animated: true)
                                    } else {
                                        Queue.mainQueue().after(0.2) {
                                            state.showAttributeInfo(tag: state.statusTag, text: strings.Gift_View_PutOn("\(uniqueGift.title) #\(formatCollectibleNumber(uniqueGift.number, dateTimeFormat: environment.dateTimeFormat))").string)
                                        }
                                    }
                                }
                            }
                        }),
                    availableSize: buttonSize,
                    transition: context.transition
                )
            } else if state.inUpgradePreview {
                if state.cachedStarImage == nil || state.cachedStarImage?.1 !== theme {
                    state.cachedStarImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/PremiumIcon"), color: theme.list.itemCheckColors.foregroundColor)!, theme)
                }
                var buttonTitleItems: [AnyComponentWithIdentity<Empty>] = []
                var upgradeString = strings.Gift_Upgrade_Upgrade
                if !incoming {
                    let upgradeStars: Int64?
                    if let stars = state.effectiveUpgradePrice?.stars {
                        upgradeStars = stars
                    } else if let gift = state.starGiftsMap[giftId], let stars = gift.upgradeStars {
                        upgradeStars = stars
                    } else {
                        upgradeStars = nil
                    }
                    if let upgradeStars {
                        let priceString = presentationStringsFormattedNumber(Int32(clamping: upgradeStars), environment.dateTimeFormat.groupingSeparator)
                        upgradeString = strings.Gift_Upgrade_GiftUpgrade(" # \(priceString)").string
                    }
                } else if let upgradeStars = state.effectiveUpgradePrice?.stars {
                    let priceString = presentationStringsFormattedNumber(Int32(clamping: upgradeStars), environment.dateTimeFormat.groupingSeparator)
                    upgradeString = strings.Gift_Upgrade_GiftUpgrade(" # \(priceString)").string
                } else if let upgradeForm = state.upgradeForm, let upgradeStars = upgradeForm.invoice.prices.first?.amount {
                    let priceString = presentationStringsFormattedNumber(Int32(clamping: upgradeStars), environment.dateTimeFormat.groupingSeparator)
                    upgradeString = strings.Gift_Upgrade_UpgradeFor(" # \(priceString)").string
                }
                let buttonTitle = subject.arguments?.upgradeStars != nil ? strings.Gift_Upgrade_Confirm : upgradeString
                let buttonAttributedString = NSMutableAttributedString(string: buttonTitle, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center)
                if let range = buttonAttributedString.string.range(of: "#"), let starImage = state.cachedStarImage?.0 {
                    buttonAttributedString.addAttribute(.attachment, value: starImage, range: NSRange(range, in: buttonAttributedString.string))
                    buttonAttributedString.addAttribute(.foregroundColor, value: theme.list.itemCheckColors.foregroundColor, range: NSRange(range, in: buttonAttributedString.string))
                    buttonAttributedString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: buttonAttributedString.string))
                    buttonAttributedString.addAttribute(.kern, value: 2.0, range: NSRange(range, in: buttonAttributedString.string))
                }
                
                if let nextUpgradePrice = state.nextUpgradePrice {
                    let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                    let upgradeTimeout = nextUpgradePrice.date - currentTime
                    
                    if let hashIndex = buttonTitle.firstIndex(of: "#") {
                        var buttonAnimatedTitleItems: [AnimatedTextComponent.Item] = []
                        
                        var prefix = String(buttonTitle[..<hashIndex])
                        if !prefix.isEmpty {
                            prefix.removeLast()
                            buttonAnimatedTitleItems.append(
                                AnimatedTextComponent.Item(
                                    id: AnyHashable(buttonAnimatedTitleItems.count),
                                    content: .text(prefix)
                                )
                            )
                        }
                        
                        buttonAnimatedTitleItems.append(
                            AnimatedTextComponent.Item(
                                id: AnyHashable(buttonAnimatedTitleItems.count),
                                content: .icon("Item List/PremiumIcon", tint: true, offset: CGPoint(x: 1.0, y: 2.0 + UIScreenPixel))
                            )
                        )
                        
                        let suffixStart = buttonTitle.index(after: hashIndex)
                        let suffix = buttonTitle[suffixStart...]
                        
                        var i = suffix.startIndex
                        while i < suffix.endIndex {
                            if suffix[i].isNumber {
                                var j = i
                                while j < suffix.endIndex, suffix[j].isNumber {
                                    j = suffix.index(after: j)
                                }
                                let string = suffix[i..<j]
                                if let value = Int(string) {
                                    buttonAnimatedTitleItems.append(
                                        AnimatedTextComponent.Item(
                                            id: AnyHashable(buttonAnimatedTitleItems.count),
                                            content: .number(value, minDigits: string.count)
                                        )
                                    )
                                }
                                i = j
                            } else {
                                var j = i
                                while j < suffix.endIndex, !suffix[j].isNumber {
                                    j = suffix.index(after: j)
                                }
                                let textRun = String(suffix[i..<j])
                                if !textRun.isEmpty {
                                    buttonAnimatedTitleItems.append(
                                        AnimatedTextComponent.Item(
                                            id: AnyHashable(buttonAnimatedTitleItems.count),
                                            content: .text(textRun)
                                        )
                                    )
                                }
                                i = j
                            }
                        }
                        
                        buttonTitleItems.append(AnyComponentWithIdentity(id: "animated_label", component: AnyComponent(AnimatedTextComponent(
                            font: Font.with(size: 17.0, weight: .semibold, traits: .monospacedNumbers),
                            color: theme.list.itemCheckColors.foregroundColor,
                            items: buttonAnimatedTitleItems,
                            noDelay: true,
                            blur: true
                        ))))
                    } else {
                        buttonTitleItems.append(AnyComponentWithIdentity(id: "static_label", component: AnyComponent(MultilineTextComponent(text: .plain(buttonAttributedString)))))
                    }
                    
                    let minutes = Int(upgradeTimeout / 60)
                    let seconds = Int(upgradeTimeout % 60)
                    
                    let rawString = strings.Gift_Upgrade_PriceWillDecrease
                    var buttonAnimatedTitleItems: [AnimatedTextComponent.Item] = []
                    var startIndex = rawString.startIndex
                    while true {
                        if let range = rawString.range(of: "{", range: startIndex ..< rawString.endIndex) {
                            if range.lowerBound != startIndex {
                                buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: AnyHashable(buttonAnimatedTitleItems.count), content: .text(String(rawString[startIndex ..< range.lowerBound]))))
                            }
                            
                            startIndex = range.upperBound
                            if let endRange = rawString.range(of: "}", range: startIndex ..< rawString.endIndex) {
                                let controlString = rawString[range.upperBound ..< endRange.lowerBound]
                                if controlString == "m" {
                                    buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: AnyHashable(buttonAnimatedTitleItems.count), content: .number(minutes, minDigits: 2)))
                                } else if controlString == "s" {
                                    buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: AnyHashable(buttonAnimatedTitleItems.count), content: .number(seconds, minDigits: 2)))
                                }
                                
                                startIndex = endRange.upperBound
                            }
                        } else {
                            break
                        }
                    }
                    if startIndex != rawString.endIndex {
                        buttonAnimatedTitleItems.append(AnimatedTextComponent.Item(id: AnyHashable(buttonAnimatedTitleItems.count), content: .text(String(rawString[startIndex ..< rawString.endIndex]))))
                    }
                    
                    buttonTitleItems.append(AnyComponentWithIdentity(id: "timer", component: AnyComponent(AnimatedTextComponent(
                        font: Font.with(size: 11.0, weight: .medium, traits: .monospacedNumbers),
                        color: environment.theme.list.itemCheckColors.foregroundColor.withAlphaComponent(0.7),
                        items: buttonAnimatedTitleItems,
                        noDelay: true
                    ))))
                } else {
                    buttonTitleItems.append(AnyComponentWithIdentity(id: "static_label", component: AnyComponent(MultilineTextComponent(text: .plain(buttonAttributedString)))))
                }
                
                buttonChild = button.update(
                    component: ButtonComponent(
                        background: buttonBackground,
                        content: AnyComponentWithIdentity(
                            id: AnyHashable("upgrade"),
                            component: AnyComponent(VStack(buttonTitleItems, spacing: 1.0))
                        ),
                        isEnabled: true,
                        displaysProgress: state.inProgress,
                        action: { [weak state] in
                            if canGiftUpgrade {
                                state?.commitPrepaidUpgrade()
                            } else {
                                state?.commitUpgrade()
                            }
                        }),
                    availableSize: buttonSize,
                    transition: .spring(duration: 0.2)
                )
            } else if upgraded, let arguments = subject.arguments, let upgradeMessageIdId = arguments.upgradeMessageId, let originalMessageId = arguments.messageId, !arguments.upgradeSeparate {
                var delay = false
                var peerId: EnginePeer.Id = originalMessageId.peerId
                if peerId.isTelegramNotifications {
                    peerId = component.context.account.peerId
                    delay = true
                }
                
                let upgradeMessageId = MessageId(peerId: peerId, namespace: originalMessageId.namespace, id: upgradeMessageIdId)
                let buttonTitle = strings.Gift_View_ViewUpgraded
                buttonChild = button.update(
                    component: ButtonComponent(
                        background: buttonBackground,
                        content: AnyComponentWithIdentity(
                            id: AnyHashable("button"),
                            component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: buttonTitle, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center))))
                        ),
                        isEnabled: true,
                        displaysProgress: false,
                        action: { [weak state] in
                            state?.dismiss(animated: true)
                            state?.viewUpgradedGift(messageId: upgradeMessageId, delay: delay)
                        }),
                    availableSize: buttonSize,
                    transition: context.transition
                )
            } else if (incoming && !converted && !upgraded && canUpgrade) || canGiftUpgrade {
                let buttonTitle: String
                if canGiftUpgrade {
                    buttonTitle = strings.Gift_View_GiftUpgrade
                } else if let upgradeStars, upgradeStars > 0 {
                    buttonTitle = strings.Gift_View_UpgradeForFree
                } else {
                    buttonTitle = strings.Gift_View_Upgrade
                }
                buttonChild = button.update(
                    component: ButtonComponent(
                        background: buttonBackground.withIsShimmering(true),
                        content: AnyComponentWithIdentity(
                            id: AnyHashable("previewUpgrade"),
                            component: AnyComponent(HStack([
                                AnyComponentWithIdentity(id: 0, component: AnyComponent(
                                    MultilineTextComponent(text: .plain(NSAttributedString(string: buttonTitle, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center))
                                ))),
                                AnyComponentWithIdentity(id: 1, component: AnyComponent(
                                    LottieComponent(
                                        content: LottieComponent.AppBundleContent(
                                            name: "GiftUpgrade"
                                        ),
                                        size: CGSize(width: 30.0, height: 30.0),
                                        loop: true
                                    )
                                ))
                            ], spacing: 5.0))
                        ),
                        isEnabled: true,
                        displaysProgress: state.inProgress,
                        action: { [weak state] in
                            state?.requestUpgradePreview()
                        }
                    ),
                    availableSize: buttonSize,
                    transition: context.transition
                )
            } else if incoming && !converted && !savedToProfile && !isDismantled {
                let buttonTitle = isChannelGift ? strings.Gift_View_Display_Channel : strings.Gift_View_Display
                buttonChild = button.update(
                    component: ButtonComponent(
                        background: buttonBackground,
                        content: AnyComponentWithIdentity(
                            id: AnyHashable("button"),
                            component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: buttonTitle, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center))))
                        ),
                        isEnabled: true,
                        displaysProgress: state.inProgress,
                        action: { [weak state] in
                            state?.updateSavedToProfile(!savedToProfile)
                        }),
                    availableSize: buttonSize,
                    transition: context.transition
                )
            } else if !incoming, let resellAmount, !isMyOwnedUniqueGift {
                if state.cachedStarImage == nil || state.cachedStarImage?.1 !== theme {
                    state.cachedStarImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/PremiumIcon"), color: theme.list.itemCheckColors.foregroundColor)!, theme)
                }
                if state.cachedTonImage == nil || state.cachedTonImage?.1 !== theme {
                    state.cachedTonImage = (generateTintedImage(image: UIImage(bundleImageName: "Ads/TonAbout"), color: theme.list.itemCheckColors.foregroundColor)!, theme)
                }
                if state.cachedSubtitleStarImage == nil || state.cachedSubtitleStarImage?.1 !== environment.theme {
                    state.cachedSubtitleStarImage = (generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/StarsCount"), color: .white)!, theme)
                }
                var buyString = strings.Gift_View_BuyFor
                
                var buttonAttributedSubtitleString: NSMutableAttributedString?
                let currencySymbol: String
                let currencyAmount: String
                switch resellAmount.currency {
                case .stars:
                    currencySymbol = "#"
                    currencyAmount = formatStarsAmountText(resellAmount.amount, dateTimeFormat: environment.dateTimeFormat)
                case .ton:
                    currencySymbol = "$"
                    currencyAmount = formatTonAmountText(resellAmount.amount.value, dateTimeFormat: environment.dateTimeFormat, maxDecimalPositions: nil)
                    
                    if let starsAmount = uniqueGift?.resellAmounts?.first(where: { $0.currency == .stars }) {
                        buttonAttributedSubtitleString = NSMutableAttributedString(string: strings.Gift_View_EqualsTo(" # \(formatStarsAmountText(starsAmount.amount, dateTimeFormat: environment.dateTimeFormat))").string, font: Font.medium(11.0), textColor: theme.list.itemCheckColors.foregroundColor.withAlphaComponent(0.7), paragraphAlignment: .center)
                    }
                }
                buyString += "  \(currencySymbol) \(currencyAmount)"
                
                let buttonTitle = subject.arguments?.upgradeStars != nil ? strings.Gift_Upgrade_Confirm : buyString
                let buttonAttributedString = NSMutableAttributedString(string: buttonTitle, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center)
                
                
                if let range = buttonAttributedString.string.range(of: "#"), let starImage = state.cachedStarImage?.0 {
                    buttonAttributedString.addAttribute(.attachment, value: starImage, range: NSRange(range, in: buttonAttributedString.string))
                    buttonAttributedString.addAttribute(.foregroundColor, value: theme.list.itemCheckColors.foregroundColor, range: NSRange(range, in: buttonAttributedString.string))
                    buttonAttributedString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: buttonAttributedString.string))
                    buttonAttributedString.addAttribute(.kern, value: 2.0, range: NSRange(range, in: buttonAttributedString.string))
                }
                if let range = buttonAttributedString.string.range(of: "$"), let tonImage = state.cachedTonImage?.0 {
                    buttonAttributedString.addAttribute(.attachment, value: tonImage, range: NSRange(range, in: buttonAttributedString.string))
                    buttonAttributedString.addAttribute(.foregroundColor, value: theme.list.itemCheckColors.foregroundColor, range: NSRange(range, in: buttonAttributedString.string))
                    buttonAttributedString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: buttonAttributedString.string))
                    buttonAttributedString.addAttribute(.kern, value: 2.0, range: NSRange(range, in: buttonAttributedString.string))
                }
                if let buttonAttributedSubtitleString, let range = buttonAttributedSubtitleString.string.range(of: "#"), let starImage = state.cachedSubtitleStarImage?.0 {
                    buttonAttributedSubtitleString.addAttribute(.attachment, value: starImage, range: NSRange(range, in: buttonAttributedSubtitleString.string))
                    buttonAttributedSubtitleString.addAttribute(.foregroundColor, value: theme.list.itemCheckColors.foregroundColor.withAlphaComponent(0.7), range: NSRange(range, in: buttonAttributedSubtitleString.string))
                    buttonAttributedSubtitleString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: buttonAttributedSubtitleString.string))
                    buttonAttributedSubtitleString.addAttribute(.kern, value: 2.0, range: NSRange(range, in: buttonAttributedSubtitleString.string))
                }
                
                var items: [AnyComponentWithIdentity<Empty>] = [
                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(text: .plain(buttonAttributedString))))
                ]
                
                if let buttonAttributedSubtitleString {
                    items.append(AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(text: .plain(buttonAttributedSubtitleString)))))
                }
                
                buttonChild = button.update(
                    component: ButtonComponent(
                        background: buttonBackground,
                        content: AnyComponentWithIdentity(
                            id: AnyHashable("buy"),
                            component: AnyComponent(VStack(items, spacing: 1.0))
                        ),
                        isEnabled: true,
                        displaysProgress: state.inProgress,
                        action: { [weak state] in
                            state?.commitBuy()
                        }),
                    availableSize: buttonSize,
                    transition: context.transition
                )
            } else {
                buttonChild = button.update(
                    component: ButtonComponent(
                        background: buttonBackground,
                        content: AnyComponentWithIdentity(
                            id: AnyHashable("ok"),
                            component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: strings.Common_OK, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center))))
                        ),
                        isEnabled: true,
                        displaysProgress: state.inProgress,
                        action: { [weak state] in
                            if let state {
                                state.dismiss(animated: true)
                            }
                        }),
                    availableSize: buttonSize,
                    transition: context.transition
                )
            }
            let buttonFrame = CGRect(origin: CGPoint(x: buttonInsets.left, y: originY), size: buttonChild.size)
            
            var buttonAlpha: CGFloat = 1.0
            if let nextGiftToUpgrade = state.nextGiftToUpgrade, case let .generic(gift) = nextGiftToUpgrade.gift, !state.canSkip {
                buttonAlpha = 0.0
                
                let upgradeNextButton = upgradeNextButton.update(
                    component: PlainButtonComponent(
                        content: AnyComponent(
                            HStack([
                                AnyComponentWithIdentity(id: "label", component: AnyComponent(
                                    MultilineTextComponent(text: .plain(NSAttributedString(string: strings.Gift_Upgrade_UpgradeNext, font: Font.regular(17.0), textColor: theme.actionSheet.controlAccentColor)))
                                )),
                                AnyComponentWithIdentity(id: "icon", component: AnyComponent(
                                    GiftItemComponent(
                                        context: component.context,
                                        theme: theme,
                                        strings: strings,
                                        peer: nil,
                                        subject: .starGift(gift: gift, price: ""),
                                        mode: .buttonIcon
                                    )
                                )),
                            ], spacing: 5.0)
                        ),
                        action: { [weak state] in
                            state?.switchToNextUpgradable()
                        },
                        animateScale: false
                    ),
                    environment: {},
                    availableSize: buttonChild.size,
                    transition: .immediate
                )
                context.add(upgradeNextButton
                    .position(CGPoint(x: buttonFrame.midX, y: buttonFrame.midY))
                    .appear(.default(scale: true, alpha: true))
                    .disappear(.default(scale: true, alpha: true))
                )
            }
            
            context.add(buttonChild
                .position(CGPoint(x: buttonFrame.midX, y: buttonFrame.midY))
                .opacity(buttonAlpha)
            )
            originY += buttonChild.size.height
            originY += 7.0
            
            if showUpgradePreview, let _ = state.nextUpgradePrice {
                originY += 20.0
                
                if state.cachedSmallChevronImage == nil || state.cachedSmallChevronImage?.1 !== environment.theme {
                    state.cachedSmallChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextRightArrow"), color: theme.actionSheet.controlAccentColor)!, theme)
                }
                let attributedString = NSMutableAttributedString(string: strings.Gift_Upgrade_SeePriceDecrease, font: Font.regular(13.0), textColor: theme.actionSheet.controlAccentColor)
                if let range = attributedString.string.range(of: ">"), let chevronImage = state.cachedSmallChevronImage?.0 {
                    attributedString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: attributedString.string))
                }
                
                let upgradePriceButton = upgradePriceButton.update(
                    component: PlainButtonComponent(
                        content: AnyComponent(
                            MultilineTextComponent(text: .plain(attributedString))
                        ),
                        action: { [weak state] in
                            state?.openUpgradePricePreview()
                        },
                        animateScale: false
                    ),
                    environment: {},
                    availableSize: buttonChild.size,
                    transition: .immediate
                )
                context.add(upgradePriceButton
                    .position(CGPoint(x: buttonFrame.midX, y: originY))
                    .appear(.default(scale: true, alpha: true))
                    .disappear(.default(scale: true, alpha: true))
                )
                originY += upgradePriceButton.size.height
            }
                        
            var isBackButton = false
            if state.inWearPreview || state.inUpgradePreview {
                isBackButton = true
            }
            var leftControlItems: [GlassControlGroupComponent.Item] = []
            leftControlItems.append(GlassControlGroupComponent.Item(
                id: AnyHashable("close"),
                content: .icon(isBackButton ? "Navigation/Back" : "Navigation/Close"),
                action: { [weak state] in
                    guard let state else {
                        return
                    }
                    if state.inWearPreview {
                        if let controller = controller() as? GiftViewScreen {
                            controller.dismissAllTooltips()
                        }
                        state.inWearPreview = false
                        state.updated(transition: .spring(duration: 0.4))
                    } else if state.inUpgradePreview {
                        state.cancelUpgradePreview()
                    } else {
                        state.dismiss(animated: true)
                    }
                }
            ))
            
            var rightControlItems: [GlassControlGroupComponent.Item] = []
            if uniqueGift != nil && !showWearPreview && !isDismantled {
                if let _ = component.subject.arguments?.canCraftDate {
                    rightControlItems.append(GlassControlGroupComponent.Item(
                        id: AnyHashable("craft"),
                        content: .icon("Premium/Craft"),
                        action: { [weak state] in
                            guard let state else {
                                return
                            }
                            state.craftGift()
                        }
                    ))
                }

                rightControlItems.append(GlassControlGroupComponent.Item(
                    id: AnyHashable("more"),
                    content: .animation("anim_morewide"),
                    action: { [weak state] in
                        guard let state else {
                            return
                        }
                        state.openMore()
                    }
                ))
            }
            
            var buttonsIsDark = theme.overallDarkAppearance
            if case .color = buttonsBackground {
                buttonsIsDark = true
            }
            
            let buttons = buttons.update(
                component: GlassControlPanelComponent(
                    theme: theme,
                    leftItem: GlassControlPanelComponent.Item(
                        items: leftControlItems,
                        background: buttonsBackground
                    ),
                    centralItem: nil,
                    rightItem: rightControlItems.isEmpty ? nil : GlassControlPanelComponent.Item(
                        items: rightControlItems,
                        background: buttonsBackground
                    ),
                    centerAlignmentIfPossible: true,
                    isDark: buttonsIsDark,
                    tag: state.controlButtonsTag
                ),
                availableSize: CGSize(width: context.availableSize.width - 16.0 * 2.0, height: 44.0),
                transition: context.transition
            )
            context.add(buttons
                .position(CGPoint(x: context.availableSize.width / 2.0, y: 16.0 + buttons.size.height / 2.0))
            )
            
            let effectiveBottomInset: CGFloat = environment.metrics.isTablet ? 0.0 : environment.safeInsets.bottom
            return CGSize(width: context.availableSize.width, height: originY + 5.0 + effectiveBottomInset)
        }
    }
}

final class GiftViewSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: GiftViewScreen.Subject
    
    init(
        context: AccountContext,
        subject: GiftViewScreen.Subject
    ) {
        self.context = context
        self.subject = subject
    }
    
    static func ==(lhs: GiftViewSheetComponent, rhs: GiftViewSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        return true
    }
    
    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        let sheetExternalState = SheetComponent<EnvironmentType>.ExternalState()
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller
            
            var headerContent: AnyComponent<Empty>?
            if let arguments = context.component.subject.arguments, case .unique = arguments.gift, let fromPeerId = arguments.fromPeerId, var fromPeerName = arguments.fromPeerName, arguments.fromPeerId != context.component.context.account.peerId && !(arguments.fromPeerId?.isTelegramNotifications ?? false) {
                var showSenderInfo = false
                if arguments.incoming {
                    showSenderInfo = true
                } else if arguments.peerId == context.component.context.account.peerId {
                    showSenderInfo = true
                }
                if showSenderInfo {
                    let dateString = stringForMediumDate(timestamp: arguments.date, strings: environment.strings, dateTimeFormat: environment.dateTimeFormat, withTime: false)
                    
                    if fromPeerName.count > 25 {
                        fromPeerName = "\(fromPeerName.prefix(25))…"
                    }
                    let rawString = environment.strings.Gift_View_SenderInfo(fromPeerName, dateString).string
                    let attributedString = parseMarkdownIntoAttributedString(rawString, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: .white), bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: .white), link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: .white), linkAttribute: { _ in return nil }))
                    
                    let context = context.component.context
                    headerContent = AnyComponent(
                        PlainButtonComponent(content: AnyComponent(HeaderContentComponent(attributedText: attributedString)), action: {
                            if let controller = controller(), let navigationController = controller.navigationController as? NavigationController {
                                let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: fromPeerId))
                                         |> deliverOnMainQueue).start(next: { [weak navigationController] peer in
                                    guard let peer, let navigationController else {
                                        return
                                    }
                                    context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                                        navigationController: navigationController,
                                        chatController: nil,
                                        context: context,
                                        chatLocation: .peer(peer),
                                        subject: nil,
                                        botStart: nil,
                                        updateTextInputState: nil,
                                        keepStack: .always,
                                        useExisting: true,
                                        purposefulAction: nil,
                                        scrollToEndIfExists: false,
                                        activateMessageSearch: nil,
                                        animated: true
                                    ))
                                })
                            }
                        })
                    )
                }
            }
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(GiftViewSheetContent(
                        context: context.component.context,
                        subject: context.component.subject,
                        animateOut: animateOut,
                        getController: controller
                    )),
                    headerContent: headerContent,
                    style: .glass,
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    hasDimView: false,
                    autoAnimateOut: false,
                    externalState: sheetExternalState,
                    animateOut: animateOut,
                    onPan: {
                        if let controller = controller() as? GiftViewScreen {
                            controller.dismissAllTooltips()
                        }
                    },
                    willDismiss: {
                        if let controller = controller() as? GiftViewScreen {
                            controller.dismissBalanceOverlay()
                            controller.requestLayout(forceUpdate: true, transition: .easeInOut(duration: 0.3).withUserData(ViewControllerComponentContainer.AnimateOutTransition()))
                        }
                    }
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            if animated {
                                if let controller = controller() as? GiftViewScreen {
                                    controller.requestLayout(forceUpdate: true, transition: .easeInOut(duration: 0.3).withUserData(ViewControllerComponentContainer.AnimateOutTransition()))
                                    controller.dismissAllTooltips()
                                    controller.dismissBalanceOverlay()
                                    animateOut.invoke(Action { _ in
                                        controller.dismiss(completion: nil)
                                    })
                                }
                            } else {
                                if let controller = controller() as? GiftViewScreen {
                                    controller.dismissAllTooltips()
                                    controller.dismissBalanceOverlay()
                                    controller.dismiss(completion: nil)
                                }
                            }
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(sheet
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            if let controller = controller(), !controller.automaticallyControlPresentationContextLayout {
                var sideInset: CGFloat = 0.0
                var bottomInset: CGFloat = max(environment.safeInsets.bottom, sheetExternalState.contentHeight)
                if case .regular = environment.metrics.widthClass {
                    sideInset = floor((context.availableSize.width - 430.0) / 2.0) - 12.0
                    bottomInset = (context.availableSize.height - sheetExternalState.contentHeight) / 2.0 + sheetExternalState.contentHeight
                }
                
                let layout = ContainerViewLayout(
                    size: context.availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomInset, right: 0.0),
                    safeInsets: UIEdgeInsets(top: 0.0, left: max(sideInset, environment.safeInsets.left), bottom: 0.0, right: max(sideInset, environment.safeInsets.right)),
                    additionalInsets: .zero,
                    statusBarHeight: environment.statusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(layout, transition: context.transition.containedViewLayoutTransition)
            }
            
            return context.availableSize
        }
    }
}

public class GiftViewScreen: ViewControllerComponentContainer {
    public enum Subject: Equatable {
        case message(EngineMessage)
        case uniqueGift(StarGift.UniqueGift, EnginePeer.Id?)
        case profileGift(EnginePeer.Id, ProfileGiftsContext.State.StarGift)
        case soldOutGift(StarGift.Gift)
        case upgradePreview(StarGift.Gift, [StarGift.UniqueGift.Attribute], String)
        case wearPreview(StarGift, [StarGift.UniqueGift.Attribute]?)
        
        var arguments: (
            peerId: EnginePeer.Id?,
            fromPeerId: EnginePeer.Id?,
            fromPeerName: String?,
            fromPeerCompactName: String?,
            messageId: EngineMessage.Id?,
            reference: StarGiftReference?,
            incoming: Bool,
            gift: StarGift,
            date: Int32,
            convertStars: Int64?,
            text: String?,
            entities: [MessageTextEntity]?,
            nameHidden: Bool,
            savedToProfile: Bool,
            pinnedToTop: Bool?,
            converted: Bool,
            upgraded: Bool,
            refunded: Bool,
            canUpgrade: Bool,
            upgradeStars: Int64?,
            transferStars: Int64?,
            resellAmounts: [CurrencyAmount]?,
            canExportDate: Int32?,
            upgradeMessageId: Int32?,
            canTransferDate: Int32?,
            canResaleDate: Int32?,
            prepaidUpgradeHash: String?,
            upgradeSeparate: Bool,
            dropOriginalDetailsStars: Int64?,
            auctionToPeerId: EnginePeer.Id?,
            giftNumber: Int32?,
            canCraftDate: Int32?
        )? {
            switch self {
            case let .message(message):
                if let action = message.media.first(where: { $0 is TelegramMediaAction }) as? TelegramMediaAction {
                    switch action.action {
                    case let .starGift(gift, convertStars, text, entities, nameHidden, savedToProfile, converted, upgraded, canUpgrade, upgradeStars, isRefunded, _, upgradeMessageId, peerId, senderId, savedId, prepaidUpgradeHash, giftMessageId, upgradeSeparate, _, toPeerId, number):
                        var reference: StarGiftReference
                        if let peerId, let giftMessageId {
                            reference = .message(messageId: EngineMessage.Id(peerId: peerId, namespace: Namespaces.Message.Cloud, id: giftMessageId))
                        } else if let peerId, let savedId {
                            reference = .peer(peerId: peerId, id: savedId)
                        } else {
                            reference = .message(messageId: message.id)
                        }
                        
                        let fromPeerId = senderId ?? message.author?.id
                        return (message.id.peerId, fromPeerId, message.author?.debugDisplayTitle, message.author?.compactDisplayTitle, message.id, reference, message.flags.contains(.Incoming), gift, message.timestamp, convertStars, text, entities, nameHidden, savedToProfile, nil, converted, upgraded, isRefunded, canUpgrade, upgradeStars, nil, nil, nil, upgradeMessageId, nil, nil, prepaidUpgradeHash, upgradeSeparate, nil, toPeerId, number, nil)
                    case let .starGiftUnique(gift, isUpgrade, isTransferred, savedToProfile, canExportDate, transferStars, _, _, peerId, senderId, savedId, _, canTransferDate, canResaleDate, dropOriginalDetailsStars, _, _, canCraftDate, _):
                        var reference: StarGiftReference
                        if let peerId, let savedId {
                            reference = .peer(peerId: peerId, id: savedId)
                        } else {
                            reference = .message(messageId: message.id)
                        }
                        var incoming = false
                        if isUpgrade {
                            if message.author?.id != message.id.peerId {
                                incoming = true
                            }
                        } else if isTransferred {
                            if message.author?.id != message.id.peerId {
                                incoming = true
                            }
                        } else {
                            incoming = message.flags.contains(.Incoming)
                        }
                        
                        var resellAmounts: [CurrencyAmount]?
                        var number: Int32?
                        if case let .unique(uniqueGift) = gift {
                            resellAmounts = uniqueGift.resellAmounts
                            number = uniqueGift.number
                        }
                        return (message.id.peerId, senderId ?? message.author?.id, message.author?.debugDisplayTitle, message.author?.compactDisplayTitle, message.id, reference, incoming, gift, message.timestamp, nil, nil, nil, false, savedToProfile, nil, false, false, false, false, nil, transferStars, resellAmounts, canExportDate, nil, canTransferDate, canResaleDate, nil, false, dropOriginalDetailsStars, nil, number, canCraftDate)
                    case let .starGiftPurchaseOffer(gift, _, _, _, _), let .starGiftPurchaseOfferDeclined(gift, _, _):
                        if case let .unique(gift) = gift {
                            return (nil, nil, nil, nil, nil, nil, false, .unique(gift), 0, nil, nil, nil, false, false, nil, false, false, false, false, nil, nil, gift.resellAmounts, nil, nil, nil, nil, nil, false, nil, nil, nil, nil)
                        } else {
                            return nil
                        }
                    default:
                        return nil
                    }
                }
            case let .uniqueGift(gift, _):
                return (nil, nil, nil, nil, nil, nil, false, .unique(gift), 0, nil, nil, nil, false, false, nil, false, false, false, false, nil, nil, gift.resellAmounts, nil, nil, nil, nil, nil, false, nil, nil, gift.number, nil)
            case let .profileGift(peerId, gift):
                var messageId: EngineMessage.Id?
                if case let .message(messageIdValue) = gift.reference {
                    messageId = messageIdValue
                }
                var resellAmounts: [CurrencyAmount]?
                if case let .unique(uniqueGift) = gift.gift {
                    resellAmounts = uniqueGift.resellAmounts
                }
                
                var number: Int32?
                if case let .unique(uniqueGift) = gift.gift {
                    number = uniqueGift.number
                } else if let numberValue = gift.number {
                    number = numberValue
                }
                return (peerId, gift.fromPeer?.id, gift.fromPeer?.debugDisplayTitle, gift.fromPeer?.compactDisplayTitle, messageId, gift.reference, false, gift.gift, gift.date, gift.convertStars, gift.text, gift.entities, gift.nameHidden, gift.savedToProfile, gift.pinnedToTop, false, false, false, gift.canUpgrade, gift.upgradeStars, gift.transferStars, resellAmounts, gift.canExportDate, nil, gift.canTransferDate, gift.canResaleDate, gift.prepaidUpgradeHash, gift.upgradeSeparate, gift.dropOriginalDetailsStars, nil, number, gift.canCraftAt)
            case .soldOutGift:
                return nil
            case .upgradePreview:
                return nil
            case let .wearPreview(gift, _):
                return (nil, nil, nil, nil, nil, nil, false, gift, 0, nil, nil, nil, false, false, nil, false, false, false, false, nil, nil, nil, nil, nil, nil, nil, nil, false, nil, nil, nil, nil)
            }
            return nil
        }
    }
    
    private let context: AccountContext
    private let subject: GiftViewScreen.Subject
    
    private var upgradableGiftsContext: ProfileGiftsContext?
    fileprivate private(set) var upgradableGifts: [ProfileGiftsContext.State.StarGift]?
    fileprivate var upgradedGiftReferences = Set<StarGiftReference>()
    private var upgradableDisposable: Disposable?
    fileprivate var nextUpgradableGift: ProfileGiftsContext.State.StarGift? {
        if let upgradableGifts = self.upgradableGifts {
            return upgradableGifts.first(where: { gift in
                if let reference = gift.reference {
                    if !self.upgradedGiftReferences.contains(reference) {
                        return true
                    }
                }
                return false
            })
        }
        return nil
    }
    
    fileprivate var showBalance = false {
        didSet {
            self.requestLayout(transition: .immediate)
        }
    }
    fileprivate var balanceCurrency: CurrencyAmount.Currency
    
    fileprivate let balanceOverlay = ComponentView<Empty>()
    
    fileprivate let profileGiftsContext: ProfileGiftsContext?
    fileprivate let updateSavedToProfile: ((StarGiftReference, Bool) -> Void)?
    fileprivate let convertToStars: ((StarGiftReference) -> Void)?
    fileprivate let dropOriginalDetails: ((StarGiftReference) -> Signal<Never, DropStarGiftOriginalDetailsError>)?
    fileprivate let transferGift: ((Bool, StarGiftReference, EnginePeer.Id) -> Signal<Never, TransferStarGiftError>)?
    fileprivate let upgradeGift: ((Int64?, StarGiftReference, Bool) -> Signal<ProfileGiftsContext.State.StarGift, UpgradeStarGiftError>)?
    fileprivate let buyGift: ((String, EnginePeer.Id, CurrencyAmount?) -> Signal<Never, BuyStarGiftError>)?
    fileprivate let updateResellStars: ((StarGiftReference, CurrencyAmount?) -> Signal<Never, UpdateStarGiftPriceError>)?
    fileprivate let togglePinnedToTop: ((StarGiftReference, Bool) -> Bool)?
    fileprivate let shareStory: ((StarGift.UniqueGift) -> Void)?
    fileprivate let openChatTheme: (() -> Void)?
    
    public var disposed: () -> Void = {}
    
    public init(
        context: AccountContext,
        subject: GiftViewScreen.Subject,
        allSubjects: [GiftViewScreen.Subject]? = nil,
        index: Int? = nil,
        forceDark: Bool = false,
        profileGiftsContext: ProfileGiftsContext? = nil,
        updateSavedToProfile: ((StarGiftReference, Bool) -> Void)? = nil,
        convertToStars: ((StarGiftReference) -> Void)? = nil,
        dropOriginalDetails: ((StarGiftReference) -> Signal<Never, DropStarGiftOriginalDetailsError>)? = nil,
        transferGift: ((Bool, StarGiftReference, EnginePeer.Id) -> Signal<Never, TransferStarGiftError>)? = nil,
        upgradeGift: ((Int64?, StarGiftReference, Bool) -> Signal<ProfileGiftsContext.State.StarGift, UpgradeStarGiftError>)? = nil,
        buyGift: ((String, EnginePeer.Id, CurrencyAmount?) -> Signal<Never, BuyStarGiftError>)? = nil,
        updateResellStars: ((StarGiftReference, CurrencyAmount?) -> Signal<Never, UpdateStarGiftPriceError>)? = nil,
        togglePinnedToTop: ((StarGiftReference, Bool) -> Bool)? = nil,
        shareStory: ((StarGift.UniqueGift) -> Void)? = nil,
        openChatTheme: (() -> Void)? = nil
    ) {
        self.context = context
        self.subject = subject
        
        self.profileGiftsContext = profileGiftsContext
        self.updateSavedToProfile = updateSavedToProfile
        self.convertToStars = convertToStars
        self.dropOriginalDetails = dropOriginalDetails
        self.transferGift = transferGift
        self.upgradeGift = upgradeGift
        self.buyGift = buyGift
        self.updateResellStars = updateResellStars
        self.togglePinnedToTop = togglePinnedToTop
        self.shareStory = shareStory
        self.openChatTheme = openChatTheme
        
        if case let .unique(gift) = subject.arguments?.gift, gift.resellForTonOnly {
            self.balanceCurrency = .ton
        } else {
            self.balanceCurrency = .stars
        }
        
        var items: [GiftPagerComponent.Item] = [GiftPagerComponent.Item(id: 0, subject: subject)]
        if let allSubjects, !allSubjects.isEmpty {
            items.removeAll()
            for i in 0 ..< allSubjects.count {
                var id: AnyHashable
                if case let .profileGift(_, starGift) = allSubjects[i], let reference = starGift.reference {
                    id = reference.stringValue
                } else {
                    id = i
                }
                items.append(GiftPagerComponent.Item(id: id, subject: allSubjects[i]))
            }
        }
        var dismissTooltipsImpl: (() -> Void)?
        super.init(
            context: context,
            component: GiftPagerComponent(
                context: context,
                items: items,
                index: index ?? 0,
                itemSpacing: 10.0,
                updated: { _, _ in
                    dismissTooltipsImpl?()
                }
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: forceDark ? .dark : .default
        )
        dismissTooltipsImpl = { [weak self] in
            self?.dismissAllTooltips()
        }
        
        self.navigationPresentation = .flatModal
        self.automaticallyControlPresentationContextLayout = false
        
        if let gift = subject.arguments?.gift, case .generic = gift {
            let upgradableGiftsContext = ProfileGiftsContext(account: context.account, peerId: context.account.peerId, collectionId: nil, sorting: .date, filter: [.displayed, .hidden, .limitedUpgradable], limit: 50)
            self.upgradableDisposable = (upgradableGiftsContext.state
            |> deliverOnMainQueue).start(next: { [weak self] state in
                guard let self else {
                    return
                }
                self.upgradableGifts = state.filteredGifts
            })
            self.upgradableGiftsContext = upgradableGiftsContext
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposed()
        self.upgradableDisposable?.dispose()
    }
    
    fileprivate func switchToNextUpgradable() {
        guard let upgradableGifts = self.upgradableGifts else {
            return
        }
        let peerId: EnginePeer.Id
        if case let .profileGift(peerIdValue, _) = self.subject {
            peerId = peerIdValue
        } else {
            peerId = self.context.account.peerId
        }
        var effectiveUpgradableGifts: [ProfileGiftsContext.State.StarGift] = []
        for gift in upgradableGifts {
            if let reference = gift.reference {
                if !self.upgradedGiftReferences.contains(reference) {
                    effectiveUpgradableGifts.append(gift)
                }
            }
        }
        
        guard !effectiveUpgradableGifts.isEmpty else {
            return
        }
        
        var items: [GiftPagerComponent.Item] = []
        for i in 0 ..< effectiveUpgradableGifts.count {
            let gift = effectiveUpgradableGifts[i]
            var id: AnyHashable
            if let reference = gift.reference {
                id = reference.stringValue
            } else {
                id = i
            }
            items.append(GiftPagerComponent.Item(id: id, subject: .profileGift(peerId, gift)))
        }
        
        self.updateComponent(
            component: AnyComponent(GiftPagerComponent(
                context: self.context,
                items: items,
                index: 0,
                itemSpacing: 10.0,
                updated: { [weak self] _, _ in
                    self?.dismissAllTooltips()
                }
            )),
            transition: .spring(duration: 0.3)
        )
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
                
        if let arguments = self.subject.arguments, let resellAmounts = self.subject.arguments?.resellAmounts, !resellAmounts.isEmpty {
            if case let .unique(uniqueGift) = arguments.gift, case .peerId(self.context.account.peerId) = uniqueGift.owner {
            } else {
                self.showBalance = true
            }
        }
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.dismissAllTooltips()
    }
    
    fileprivate func animateSuccess() {
        self.navigationController?.view.addSubview(ConfettiView(frame: self.view.bounds))
        
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        self.present(UndoOverlayController(presentationData: presentationData, content: .universal(
            animation: "GiftUpgraded",
            scale: 0.066,
            colors: [:],
            title: presentationData.strings.Gift_Upgrade_Succeed_Title,
            text: presentationData.strings.Gift_Upgrade_Succeed_Text,
            customUndoText: nil,
            timeout: 4.0
        ), elevatedLayout: false, position: .bottom, action: { _ in return true }), in: .current)
    }
    
    public func dismissAnimated() {
        self.dismissAllTooltips()

        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
        
        self.dismissBalanceOverlay()
    }
    
    fileprivate func dismissBalanceOverlay() {
        if let view = self.balanceOverlay.view, view.superview != nil {
            view.layer.animateScale(from: 1.0, to: 0.8, duration: 0.4, removeOnCompletion: false)
            view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        }
    }
        
    fileprivate func dismissAllTooltips() {
        self.window?.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss(inPlace: false)
            }
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss(inPlace: false)
            }
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
            return true
        })
    }
        
    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        if self.showBalance {
            let context = self.context
            let insets = layout.insets(options: .statusBar)
            let balanceSize = self.balanceOverlay.update(
                transition: .immediate,
                component: AnyComponent(
                    StarsBalanceOverlayComponent(
                        context: context,
                        peerId: context.account.peerId,
                        theme: context.sharedContext.currentPresentationData.with { $0 }.theme,
                        currency: self.balanceCurrency,
                        action: { [weak self] in
                            guard let self, let starsContext = context.starsContext, let navigationController = self.navigationController as? NavigationController else {
                                return
                            }
                            switch self.balanceCurrency {
                            case .stars:
                                let _ = (context.engine.payments.starsTopUpOptions()
                                |> take(1)
                                |> deliverOnMainQueue).startStandalone(next: { options in
                                    let controller = context.sharedContext.makeStarsPurchaseScreen(
                                        context: context,
                                        starsContext: starsContext,
                                        options: options,
                                        purpose: .generic,
                                        targetPeerId: nil,
                                        customTheme: nil,
                                        completion: { _ in }
                                    )
                                    navigationController.pushViewController(controller)
                                })
                            case .ton:
                                var fragmentUrl = "https://fragment.com/ads/topup"
                                if let data = context.currentAppConfiguration.with({ $0 }).data, let value = data["ton_topup_url"] as? String {
                                    fragmentUrl = value
                                }
                                context.sharedContext.applicationBindings.openUrl(fragmentUrl)
                            }
                            self.dismissAnimated()
                        }
                    )
                ),
                environment: {},
                containerSize: layout.size
            )
            if let view = self.balanceOverlay.view {
                if view.superview == nil {
                    self.view.addSubview(view)
                    
                    view.layer.animatePosition(from: CGPoint(x: 0.0, y: -64.0), to: .zero, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                    view.layer.animateSpring(from: 0.8 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5, initialVelocity: 0.0, removeOnCompletion: true, additive: false, completion: nil)
                    view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                }
                view.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - balanceSize.width) / 2.0), y: insets.top + 5.0), size: balanceSize)
            }
        } else if let view = self.balanceOverlay.view, view.superview != nil {
            view.alpha = 0.0
            view.layer.animateScale(from: 1.0, to: 0.8, duration: 0.4)
            view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, completion: { _ in
                view.removeFromSuperview()
                view.alpha = 1.0
            })
        }
    }
}

func formatPercentage(_ value: Float) -> String {
    return String(format: "%0.1f", value).replacingOccurrences(of: ".0", with: "").replacingOccurrences(of: ",0", with: "") + "%"
}

final class HeaderContentComponent: Component {
    let attributedText: NSAttributedString
    
    init(
        attributedText: NSAttributedString
    ) {
        self.attributedText = attributedText
    }

    static func ==(lhs: HeaderContentComponent, rhs: HeaderContentComponent) -> Bool {
        if lhs.attributedText != rhs.attributedText {
            return false
        }
        return true
    }

    final class View: UIView {
        private var component: HeaderContentComponent?
        
        private let backgroundView: BlurredBackgroundView
        private let title = ComponentView<Empty>()
                
        override init(frame: CGRect) {
            self.backgroundView = BlurredBackgroundView(color: UIColor.black.withAlphaComponent(0.2))
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: HeaderContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
                        
            let padding: CGFloat = 10.0
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(component.attributedText),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 2
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - padding * 4.0, height: availableSize.height)
            )
            
            let size = CGSize(width: titleSize.width + padding * 2.0, height: titleSize.height + 4.0)
                        
            let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: floorToScreenPixels((size.height - titleSize.height) / 2.0) - UIScreenPixel), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            self.backgroundView.update(size: size, cornerRadius: 9.5, transition: transition.containedViewLayoutTransition)
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: .zero, size: size))
                        
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class ButtonContentComponent: Component {
    let context: AccountContext
    let text: String
    let color: UIColor
    
    init(
        context: AccountContext,
        text: String,
        color: UIColor
    ) {
        self.context = context
        self.text = text
        self.color = color
    }

    static func ==(lhs: ButtonContentComponent, rhs: ButtonContentComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.color != rhs.color {
            return false
        }
        return true
    }

    final class View: UIView {
        private var component: ButtonContentComponent?
        private weak var componentState: EmptyComponentState?
        
        private let backgroundLayer = SimpleLayer()
        private let title = ComponentView<Empty>()
                
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.layer.addSublayer(self.backgroundLayer)
            self.backgroundLayer.masksToBounds = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ButtonContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.componentState = state
                        
            let attributedText = NSAttributedString(string: component.text, font: Font.regular(11.0), textColor: component.color)
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(
                    MultilineTextWithEntitiesComponent(
                        context: component.context,
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        placeholderColor: .white,
                        text: .plain(attributedText)
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            
            let padding: CGFloat = 6.0
            let size = CGSize(width: titleSize.width + padding * 2.0, height: 18.0)
                        
            let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: floorToScreenPixels((size.height - titleSize.height) / 2.0)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            let backgroundColor = component.color.withAlphaComponent(0.1)
            self.backgroundLayer.backgroundColor = backgroundColor.cgColor
            transition.setFrame(layer: self.backgroundLayer, frame: CGRect(origin: .zero, size: size))
            self.backgroundLayer.cornerRadius = size.height / 2.0
                        
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private struct GiftConfiguration {
    static var defaultValue: GiftConfiguration {
        return GiftConfiguration(convertToStarsPeriod: 90 * 86400)
    }
    
    let convertToStarsPeriod: Int32
    
    fileprivate init(convertToStarsPeriod: Int32) {
        self.convertToStarsPeriod = convertToStarsPeriod
    }
    
    static func with(appConfiguration: AppConfiguration) -> GiftConfiguration {
        if let data = appConfiguration.data {
            var convertToStarsPeriod: Int32?
            if let value = data["stargifts_convert_period_max"] as? Double {
                convertToStarsPeriod = Int32(value)
            }
            return GiftConfiguration(convertToStarsPeriod: convertToStarsPeriod ?? GiftConfiguration.defaultValue.convertToStarsPeriod)
        } else {
            return .defaultValue
        }
    }
}

private final class GiftViewContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceView: UIView
    
    init(controller: ViewController, sourceView: UIView) {
        self.controller = controller
        self.sourceView = sourceView
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

private final class HeaderButtonComponent: Component {
    let title: String
    let buttonColor: UIColor
    let iconName: String
    let isLocked: Bool
    let action: () -> Void
    
    public init(
        title: String,
        buttonColor: UIColor,
        iconName: String,
        isLocked: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.buttonColor = buttonColor
        self.iconName = iconName
        self.isLocked = isLocked
        self.action = action
    }
    
    static func ==(lhs: HeaderButtonComponent, rhs: HeaderButtonComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.buttonColor != rhs.buttonColor {
            return false
        }
        if lhs.iconName != rhs.iconName {
            return false
        }
        if lhs.isLocked != rhs.isLocked {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private var component: HeaderButtonComponent?
        private weak var componentState: EmptyComponentState?
        
        private let backgroundView = GlassBackgroundView()
        private let title = ComponentView<Empty>()
        private let icon = ComponentView<Empty>()
        private let lockIcon = ComponentView<Empty>()
        private let button = HighlightTrackingButton()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            self.backgroundView.contentView.addSubview(self.button)
            
            self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func buttonPressed() {
            if let component = self.component {
                component.action()
            }
        }
        
        func update(component: HeaderButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.componentState = state
            
            let bounds = CGRect(origin: .zero, size: availableSize)
            
            self.backgroundView.update(size: bounds.size, cornerRadius: 16.0, isDark: true, tintColor: .init(kind: .custom(style: .default, color: component.buttonColor)), isInteractive: true, transition: transition)
            transition.setFrame(view: self.backgroundView, frame: bounds)
            
            let iconSize = self.icon.update(
                transition: transition,
                component: AnyComponent(
                    BundleIconComponent(
                        name: component.iconName,
                        tintColor: UIColor.white
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    iconView.isUserInteractionEnabled = false
                    self.backgroundView.contentView.addSubview(iconView)
                }
                iconView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - iconSize.width) / 2.0), y: floorToScreenPixels(22.0 - iconSize.height * 0.5)), size: iconSize)
            }
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: component.title,
                            font: Font.regular(11.0),
                            textColor: UIColor.white,
                            paragraphAlignment: .natural
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 1
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 16.0, height: availableSize.height)
            )
            
            var totalTitleWidth = titleSize.width
            var titleOriginX = availableSize.width / 2.0 - totalTitleWidth / 2.0
            if component.isLocked {
                let titleSpacing: CGFloat = 3.0
                
                let lockIconSize = self.lockIcon.update(
                    transition: transition,
                    component: AnyComponent(
                        BundleIconComponent(
                            name: "Chat List/StatusLockIcon",
                            tintColor: .white
                        )
                    ),
                    environment: {},
                    containerSize: availableSize
                )
                totalTitleWidth += lockIconSize.width + titleSpacing
                titleOriginX = availableSize.width / 2.0 - totalTitleWidth / 2.0
                
                if let lockIconView = self.lockIcon.view {
                    if lockIconView.superview == nil {
                        lockIconView.isUserInteractionEnabled = false
                        self.backgroundView.contentView.addSubview(lockIconView)
                    }
                    lockIconView.frame = CGRect(origin: CGPoint(x: titleOriginX, y: floorToScreenPixels(42.0 - lockIconSize.height * 0.5)), size: lockIconSize)
                }
                titleOriginX += lockIconSize.width + titleSpacing
            }
            
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.backgroundView.contentView.addSubview(titleView)
                }
                titleView.frame = CGRect(origin: CGPoint(x: titleOriginX, y: floorToScreenPixels(42.0 - titleSize.height * 0.5)), size: titleSize)
            }
            
            self.button.frame = bounds
        
            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
    
//    static var body: Body {
//        let background = Child(RoundedRectangle.self)
//        let title = Child(MultilineTextComponent.self)
//        let icon = Child(BundleIconComponent.self)
//        let lockIcon = Child(BundleIconComponent.self)
//        
//        return { context in
//            let component = context.component
//            
//            let background = background.update(
//                component: RoundedRectangle(
//                    color: UIColor.white.withAlphaComponent(0.16),
//                    cornerRadius: 16.0
//                ),
//                availableSize: context.availableSize,
//                transition: .immediate
//            )
//            context.add(background
//                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
//            )
//            
//            let icon = icon.update(
//                component: BundleIconComponent(
//                    name: component.iconName,
//                    tintColor: UIColor.white
//                ),
//                availableSize: context.availableSize,
//                transition: .immediate
//            )
//            context.add(icon
//                .position(CGPoint(x: context.availableSize.width / 2.0, y: 22.0))
//            )
//            
//            let title = title.update(
//                component: MultilineTextComponent(
//                    text: .plain(NSAttributedString(
//                        string: component.title,
//                        font: Font.regular(11.0),
//                        textColor: UIColor.white,
//                        paragraphAlignment: .natural
//                    )),
//                    horizontalAlignment: .center,
//                    maximumNumberOfLines: 1
//                ),
//                availableSize: CGSize(width: context.availableSize.width - 16.0, height: context.availableSize.height),
//                transition: .immediate
//            )
//            var totalTitleWidth = title.size.width
//            var titleOriginX = context.availableSize.width / 2.0 - totalTitleWidth / 2.0
//            if component.isLocked {
//                let titleSpacing: CGFloat = 3.0
//                let lockIcon = lockIcon.update(
//                    component: BundleIconComponent(
//                        name: "Chat List/StatusLockIcon",
//                        tintColor: UIColor.white
//                    ),
//                    availableSize: context.availableSize,
//                    transition: .immediate
//                )
//                totalTitleWidth += lockIcon.size.width + titleSpacing
//                titleOriginX = context.availableSize.width / 2.0 - totalTitleWidth / 2.0
//                context.add(lockIcon
//                    .position(CGPoint(x: titleOriginX + lockIcon.size.width / 2.0, y: 42.0))
//                )
//                titleOriginX += lockIcon.size.width + titleSpacing
//            }
//            context.add(title
//                .position(CGPoint(x: titleOriginX + title.size.width / 2.0, y: 42.0))
//            )
//            
//            return context.availableSize
//        }
//    }
}

private struct GiftViewConfiguration {
    public static var defaultValue: GiftViewConfiguration {
        return GiftViewConfiguration(explorerUrl: "https://tonviewer.com")
    }
    
    public let explorerUrl: String
    
    fileprivate init(explorerUrl: String) {
        self.explorerUrl = explorerUrl
    }
    
    public static func with(appConfiguration: AppConfiguration) -> GiftViewConfiguration {
        if let data = appConfiguration.data, let value = data["ton_blockchain_explorer_url"] as? String {
            return GiftViewConfiguration(explorerUrl: value)
        } else {
            return .defaultValue
        }
    }
}

private extension StarGiftReference {
    var stringValue: String {
        switch self {
        case let .message(messageId):
            return "m_\(messageId.id)"
        case let .peer(peerId, id):
            return "p_\(peerId.toInt64())_\(id)"
        case let .slug(slug):
            return "s_\(slug)"
        }
    }
}
