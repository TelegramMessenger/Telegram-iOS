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
import GiftAnimationComponent
import LottieComponent
import ContextUI
import TelegramNotices
import PremiumLockButtonSubtitleComponent
import StarsBalanceOverlayComponent

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
        let modelButtonTag = GenericComponentViewTag()
        let backdropButtonTag = GenericComponentViewTag()
        let symbolButtonTag = GenericComponentViewTag()
        let statusTag = GenericComponentViewTag()
        
        private let context: AccountContext
        private(set) var subject: GiftViewScreen.Subject
        
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
        
        var cachedCircleImage: UIImage?
        var cachedStarImage: (UIImage, PresentationTheme)?
        var cachedSmallStarImage: (UIImage, PresentationTheme)?
        
        var cachedChevronImage: (UIImage, PresentationTheme)?
        var cachedSmallChevronImage: (UIImage, PresentationTheme)?
        
        var inProgress = false
        
        var inUpgradePreview = false
        var upgradeForm: BotPaymentForm?
        var upgradeFormDisposable: Disposable?
        var upgradeDisposable: Disposable?
        let levelsDisposable = MetaDisposable()
        
        var buyForm: BotPaymentForm?
        var buyFormDisposable: Disposable?
        var buyDisposable: Disposable?
        var resellTooEarlyTimestamp: Int32?
        
        var inWearPreview = false
        var pendingWear = false
        var pendingTakeOff = false
        
        var sampleGiftAttributes: [StarGift.UniqueGift.Attribute]?
        let sampleDisposable = DisposableSet()
        
        var keepOriginalInfo = false
                
        private var optionsDisposable: Disposable?
        private(set) var options: [StarsTopUpOption] = [] {
            didSet {
                self.optionsPromise.set(self.options)
            }
        }
        private let optionsPromise = ValuePromise<[StarsTopUpOption]?>(nil)
        
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
                if let upgradeStars = arguments.upgradeStars, upgradeStars > 0, !arguments.nameHidden {
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
                    if case let .peerId(peerId) = gift.owner {
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
                    
                    if let _ = arguments.resellStars {
                        self.buyFormDisposable = (context.engine.payments.fetchBotPaymentForm(source: .starGiftResale(slug: gift.slug, toPeerId: context.account.peerId), themeParams: nil)
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
                } else if case let .generic(gift) = arguments.gift {
                    if arguments.canUpgrade || arguments.upgradeStars != nil {
                        self.sampleDisposable.add((context.engine.payments.starGiftUpgradePreview(giftId: gift.id)
                        |> deliverOnMainQueue).start(next: { [weak self] attributes in
                            guard let self else {
                                return
                            }
                            self.sampleGiftAttributes = attributes
                            
                            for attribute in attributes {
                                switch attribute {
                                case let .model(_, file, _):
                                    self.sampleDisposable.add(freeMediaFileResourceInteractiveFetched(account: self.context.account, userLocation: .other, fileReference: .standalone(media: file), resource: file.resource).start())
                                case let .pattern(_, file, _):
                                    self.sampleDisposable.add(freeMediaFileResourceInteractiveFetched(account: self.context.account, userLocation: .other, fileReference: .standalone(media: file), resource: file.resource).start())
                                default:
                                    break
                                }
                            }

                            self.updated()
                        }))
                        
                        if arguments.upgradeStars == nil, let reference = arguments.reference {
                            self.upgradeFormDisposable = (context.engine.payments.fetchBotPaymentForm(source: .starGiftUpgrade(keepOriginalInfo: false, reference: reference), themeParams: nil)
                            |> deliverOnMainQueue).start(next: { [weak self] paymentForm in
                                guard let self else {
                                    return
                                }
                                self.upgradeForm = paymentForm
                                self.updated()
                            })
                        }
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
            
            var minRequiredAmount = StarsAmount(value: 100, nanos: 0)
            if let resellStars = self.subject.arguments?.resellStars {
                minRequiredAmount = StarsAmount(value: resellStars, nanos: 0)
            }
            
            if let starsContext = context.starsContext, let state = starsContext.currentState, state.balance < minRequiredAmount {
                self.optionsDisposable = (context.engine.payments.starsTopUpOptions()
                |> deliverOnMainQueue).start(next: { [weak self] options in
                    guard let self else {
                        return
                    }
                    self.options = options
                })
            }
        }
        
        deinit {
            self.disposable?.dispose()
            self.sampleDisposable.dispose()
            self.upgradeFormDisposable?.dispose()
            self.upgradeDisposable?.dispose()
            self.buyFormDisposable?.dispose()
            self.buyDisposable?.dispose()
            self.levelsDisposable.dispose()
            self.optionsDisposable?.dispose()
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
                    elevatedLayout: false,
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
                    if case let .model(_, file, _) = attribute {
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
                            elevatedLayout: lastController is ChatController,
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
                        lastController.present(resultController, in: .window(.root))
                    }
                }
            }
        }
        
        func convertToStars() {
            guard let controller = self.getController() as? GiftViewScreen, let starsContext = context.starsContext, let arguments = self.subject.arguments, let reference = arguments.reference, let fromPeerName = arguments.fromPeerName, let convertStars = arguments.convertStars, let navigationController = controller.navigationController as? NavigationController else {
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
                    presentationData.strings.Gift_Convert_Period_Stars(Int32(convertStars)),
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
                                convertToStars()
                            } else {
                                let _ = (self.context.engine.payments.convertStarGift(reference: reference)
                                |> deliverOnMainQueue).startStandalone()
                            }
                            
                            controller?.dismissAnimated()
                            
                            if let navigationController {
                                Queue.mainQueue().after(0.5) {
                                    starsContext.load(force: true)
                                    
                                    let text: String
                                    if isChannelGift {
                                        text = presentationData.strings.Gift_Convert_Success_ChannelText(
                                            presentationData.strings.Gift_Convert_Success_ChannelText_Stars(Int32(convertStars))
                                        ).string
                                    } else {
                                        text = presentationData.strings.Gift_Convert_Success_Text(
                                            presentationData.strings.Gift_Convert_Success_Text_Stars(Int32(convertStars))
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
                                            elevatedLayout: lastController is ChatController,
                                            action: { _ in return true }
                                        )
                                        lastController.present(resultController, in: .window(.root))
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
        
        func transferGift() {
            guard let arguments = self.subject.arguments, let controller = self.getController() as? GiftViewScreen, case let .unique(gift) = arguments.gift, let reference = arguments.reference, let transferStars = arguments.transferStars else {
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
                    Queue.mainQueue().after(1.5, {
                        if transferStars > 0 {
                            context.starsContext?.load(force: true)
                        }
                    })
                    
                    if let tranfserGiftImpl {
                        return tranfserGiftImpl(transferStars == 0, peerId)
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
            
            let giftTitle = "\(gift.title) #\(presentationStringsFormattedNumber(gift.number, presentationData.dateTimeFormat.groupingSeparator))"
            let reference = arguments.reference ?? .slug(slug: gift.slug)
            
            if let resellStars = gift.resellStars, resellStars > 0, !update {
                let alertController = textAlertController(
                    context: context,
                    title: presentationData.strings.Gift_View_Resale_Unlist_Title,
                    text: presentationData.strings.Gift_View_Resale_Unlist_Text,
                    actions: [
                        TextAlertAction(type: .defaultAction, title: presentationData.strings.Gift_View_Resale_Unlist_Unlist, action: { [weak self, weak controller] in
                            guard let self, let controller else {
                                return
                            }
                            let _ = ((controller.updateResellStars?(nil) ?? context.engine.payments.updateStarGiftResalePrice(reference: reference, price: nil))
                            |> deliverOnMainQueue).startStandalone(error: { error in
                                
                            }, completed: { [weak self, weak controller] in
                                guard let self, let controller else {
                                    return
                                }
                                switch self.subject {
                                case let .profileGift(peerId, currentSubject):
                                    self.subject = .profileGift(peerId, currentSubject.withGift(.unique(gift.withResellStars(nil))))
                                case let .uniqueGift(_, recipientPeerId):
                                    self.subject = .uniqueGift(gift.withResellStars(nil), recipientPeerId)
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
                                    appearance: UndoOverlayController.Appearance(sideInset: 16.0, bottomInset: 62.0),
                                    action: { action in
                                        return false
                                    }
                                )
                                controller.present(tooltipController, in: .window(.root))
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
                
                    let _ = ((controller.updateResellStars?(price) ?? context.engine.payments.updateStarGiftResalePrice(reference: reference, price: price))
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
                            self.subject = .profileGift(peerId, currentSubject.withGift(.unique(gift.withResellStars(price))))
                        case let .uniqueGift(_, recipientPeerId):
                            self.subject = .uniqueGift(gift.withResellStars(price), recipientPeerId)
                        default:
                            break
                        }
                        self.updated(transition: .easeInOut(duration: 0.2))
                        
                        var text = presentationData.strings.Gift_View_Resale_List_Success(giftTitle).string
                        if update {
                            let starsString = presentationData.strings.Gift_View_Resale_Relist_Success_Stars(Int32(price))
                            text = presentationData.strings.Gift_View_Resale_Relist_Success(giftTitle, starsString).string
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
                            appearance: UndoOverlayController.Appearance(sideInset: 16.0, bottomInset: 62.0),
                            action: { action in
                                return false
                            }
                        )
                        controller.present(tooltipController, in: .window(.root))
                    })
                })
                controller.push(resellController)
            }
        }
        
        func viewUpgradedGift(messageId: EngineMessage.Id) {
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
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), subject: .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false), keepStack: .always, useExisting: true, purposefulAction: {}, peekData: nil, forceAnimatedScroll: true))
            })
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
        
        func openMore(node: ASDisplayNode, gesture: ContextGesture?) {
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
                
                if let _ = arguments.reference, case .unique = arguments.gift, let togglePinnedToTop = controller.togglePinnedToTop, let pinnedToTop = arguments.pinnedToTop {
                    items.append(.action(ContextMenuActionItem(text: pinnedToTop ? strings.PeerInfo_Gifts_Context_Unpin  : strings.PeerInfo_Gifts_Context_Pin , icon: { theme in generateTintedImage(image: UIImage(bundleImageName: pinnedToTop ? "Chat/Context Menu/Unpin" : "Chat/Context Menu/Pin"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, f in
                        c?.dismiss(completion: { [weak self, weak controller] in
                            guard let self, let controller else {
                                return
                            }
                            
                            let pinnedToTop = !pinnedToTop
                            if togglePinnedToTop(pinnedToTop) {
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
                
                if case let .unique(gift) = arguments.gift, let resellStars = gift.resellStars, resellStars > 0 {
                    if arguments.reference != nil || gift.owner.peerId == context.account.peerId {
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
                
                if let _ = arguments.resellStars, case let .uniqueGift(uniqueGift, recipientPeerId) = subject, let _ = recipientPeerId {
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
                
                let contextController = ContextController(presentationData: presentationData, source: .reference(GiftViewContextReferenceContentSource(controller: controller, sourceNode: node)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
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
        
        func requestUpgradePreview() {
            guard let arguments = self.subject.arguments, arguments.canUpgrade || arguments.upgradeStars != nil else {
                return
            }
            self.context.starsContext?.load(force: false)
            
            self.inUpgradePreview = true
            self.updated(transition: .spring(duration: 0.4))
            
            if let controller = self.getController() as? GiftViewScreen {
                controller.showBalance = true
            }
        }
        
        func cancelUpgradePreview() {
            self.inUpgradePreview = false
            self.updated(transition: .spring(duration: 0.4))
            
            if let controller = self.getController() as? GiftViewScreen {
                controller.showBalance = false
            }
        }
        
        func commitBuy(acceptedPrice: Int64? = nil, skipConfirmation: Bool = false) {
            guard let resellStars = self.subject.arguments?.resellStars, let starsContext = self.context.starsContext, let starsState = starsContext.currentState, case let .unique(uniqueGift) = self.subject.arguments?.gift else {
                return
            }
            
            let context = self.context
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            if let resellTooEarlyTimestamp = self.resellTooEarlyTimestamp {
                guard let controller = self.getController() else {
                    return
                }
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
            
            let giftTitle = "\(uniqueGift.title) #\(uniqueGift.number)"
            let recipientPeerId = self.recipientPeerId ?? self.context.account.peerId
                        
            let action = {
                let proceed: () -> Void = {
                    guard let controller = self.getController() as? GiftViewScreen else {
                        return
                    }
                    
                    self.inProgress = true
                    self.updated()
                    
                    let buyGiftImpl: ((String, EnginePeer.Id, Int64?) -> Signal<Never, BuyStarGiftError>)
                    if let buyGift = controller.buyGift {
                        buyGiftImpl = { slug, peerId, price in
                            return buyGift(slug, peerId, price)
                            |> afterCompleted {
                                context.starsContext?.load(force: true)
                            }
                        }
                    } else {
                        buyGiftImpl = { slug, peerId, price in
                            return self.context.engine.payments.buyStarGift(slug: slug, peerId: peerId, price: price)
                            |> afterCompleted {
                                context.starsContext?.load(force: true)
                            }
                        }
                    }
                    
                    self.buyDisposable = (buyGiftImpl(uniqueGift.slug, recipientPeerId, acceptedPrice ?? resellStars)
                    |> deliverOnMainQueue).start(
                        error: { [weak self] error in
                            guard let self, let controller = self.getController() else {
                                return
                            }
                            
                            self.inProgress = false
                            self.updated()
                            
                            switch error {
                            case let .priceChanged(newPrice):
                                let errorTitle = presentationData.strings.Gift_Buy_ErrorPriceChanged_Title
                                let originalPriceString = presentationData.strings.Gift_Buy_ErrorPriceChanged_Text_Stars(Int32(resellStars))
                                let newPriceString = presentationData.strings.Gift_Buy_ErrorPriceChanged_Text_Stars(Int32(newPrice))
                                let errorText = presentationData.strings.Gift_Buy_ErrorPriceChanged_Text(originalPriceString, newPriceString).string
                                
                                let alertController = textAlertController(
                                    context: context,
                                    title: errorTitle,
                                    text: errorText,
                                    actions: [
                                        TextAlertAction(type: .defaultAction, title: presentationData.strings.Gift_Buy_Confirm_BuyFor(Int32(newPrice)), action: { [weak self] in
                                            guard let self else {
                                                return
                                            }
                                            self.commitBuy(acceptedPrice: newPrice, skipConfirmation: true)
                                        }),
                                        TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                                        })
                                    ],
                                    actionLayout: .vertical,
                                    parseMarkdown: true
                                )
                                controller.present(alertController, in: .window(.root))

                                HapticFeedback().error()
                            default:
                                let alertController = textAlertController(context: context, title: nil, text: presentationData.strings.Gift_Buy_ErrorUnknown, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})], parseMarkdown: true)
                                controller.present(alertController, in: .window(.root))
                            }
                        },
                        completed: { [weak self, weak starsContext] in
                            guard let self,
                                  let controller = self.getController() as? GiftViewScreen else {
                            return
                        }
                        self.inProgress = false
                        
                        var animationFile: TelegramMediaFile?
                        for attribute in uniqueGift.attributes {
                            if case let .model(_, file, _) = attribute {
                                animationFile = file
                                break
                            }
                        }
                        
                        if let navigationController = controller.navigationController as? NavigationController {
                            if recipientPeerId == self.context.account.peerId {
                                controller.dismissAnimated()
                                
                                navigationController.view.addSubview(ConfettiView(frame: navigationController.view.bounds))
                                
                                Queue.mainQueue().after(0.5, {
                                    if let lastController = navigationController.viewControllers.last as? ViewController, let animationFile {
                                        let resultController = UndoOverlayController(
                                            presentationData: presentationData,
                                            content: .sticker(context: context, file: animationFile, loop: false, title: presentationData.strings.Gift_View_Resale_SuccessYou_Title, text: presentationData.strings.Gift_View_Resale_SuccessYou_Text(giftTitle).string, undoText: nil, customAction: nil),
                                            elevatedLayout: lastController is ChatController,
                                            action: {  _ in
                                                return true
                                            }
                                        )
                                        lastController.present(resultController, in: .window(.root))
                                    }
                                })
                            } else {
                                var controllers = Array(navigationController.viewControllers.prefix(1))
                                let chatController = self.context.sharedContext.makeChatController(context: context, chatLocation: .peer(id: recipientPeerId), subject: nil, botStart: nil, mode: .standard(.default), params: nil)
                                chatController.hintPlayNextOutgoingGift()
                                controllers.append(chatController)
                                navigationController.setViewControllers(controllers, animated: true)
                                
                                Queue.mainQueue().after(0.5, {
                                    let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: recipientPeerId))
                                    |> deliverOnMainQueue).start(next: { [weak navigationController] peer in
                                        if let peer, let lastController = navigationController?.viewControllers.last as? ViewController, let animationFile {
                                            let resultController = UndoOverlayController(
                                                presentationData: presentationData,
                                                content: .sticker(context: context, file: animationFile, loop: false, title: presentationData.strings.Gift_View_Resale_Success_Title, text: presentationData.strings.Gift_View_Resale_Success_Text(peer.compactDisplayTitle).string, undoText: nil, customAction: nil),
                                                elevatedLayout: lastController is ChatController,
                                                action: {  _ in
                                                    return true
                                                }
                                            )
                                            lastController.present(resultController, in: .window(.root))
                                        }
                                    })
                                })
                            }
                        }
                        
                        self.updated(transition: .spring(duration: 0.4))
                        
                        Queue.mainQueue().after(0.5) {
                            starsContext?.load(force: true)
                        }
                    })
                }
                
                if let buyForm = self.buyForm, let price = buyForm.invoice.prices.first?.amount {
                    if starsState.balance < StarsAmount(value: price, nanos: 0) {
                        if self.options.isEmpty {
                            self.inProgress = true
                            self.updated()
                        }
                        let _ = (self.optionsPromise.get()
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
                                purpose: .buyStarGift(requiredStars: price),
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
                                            if starsState.balance < StarsAmount(value: price, nanos: 0) {
                                                self.inProgress = false
                                                self.updated()
                                                
                                                self.commitBuy(skipConfirmation: true)
                                            } else {
                                                proceed()
                                            }
                                        });
                                    })
                                }
                            )
                            controller.push(purchaseController)
                        })
                    } else {
                        proceed()
                    }
                } else {
                    guard let controller = self.getController() else {
                        return
                    }
                    let alertController = textAlertController(context: context, title: nil, text: presentationData.strings.Gift_Buy_ErrorUnknown, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})], parseMarkdown: true)
                    controller.present(alertController, in: .window(.root))
                }
            }
            
            if skipConfirmation {
                action()
            } else {
                let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: recipientPeerId))
                |> deliverOnMainQueue).start(next: { [weak self] peer in
                    guard let self, let peer else {
                        return
                    }
                    let text: String
                    let starsString = presentationData.strings.Gift_Buy_Confirm_Text_Stars(Int32(resellStars))
                    
                    if recipientPeerId == self.context.account.peerId {
                        text = presentationData.strings.Gift_Buy_Confirm_Text(giftTitle, starsString).string
                    } else {
                        text = presentationData.strings.Gift_Buy_Confirm_GiftText(giftTitle, starsString, peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string
                    }
                    let alertController = textAlertController(
                        context: self.context,
                        title: presentationData.strings.Gift_Buy_Confirm_Title,
                        text: text,
                        actions: [
                            TextAlertAction(type: .defaultAction, title: presentationData.strings.Gift_Buy_Confirm_BuyFor(Int32(resellStars)), action: {
                                action()
                            }),
                            TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                            })
                        ],
                        actionLayout: .vertical,
                        parseMarkdown: true
                    )
                    if let controller = self.getController() as? GiftViewScreen {
                        controller.present(alertController, in: .window(.root))
                    }
                })
            }
        }
        
        func commitUpgrade() {
            guard let arguments = self.subject.arguments, let peerId = arguments.peerId, let starsContext = self.context.starsContext, let starsState = starsContext.currentState else {
                return
            }
            
            let proceed: (Int64?) -> Void = { formId in
                guard let controller = self.getController() as? GiftViewScreen else {
                    return
                }
                self.inProgress = true
                self.updated()
                
                controller.showBalance = false
                
                let context = self.context
                let upgradeGiftImpl: ((Int64?, Bool) -> Signal<ProfileGiftsContext.State.StarGift, UpgradeStarGiftError>)
                if let upgradeGift = controller.upgradeGift {
                    upgradeGiftImpl = { formId, keepOriginalInfo in
                        return upgradeGift(formId, keepOriginalInfo)
                        |> afterCompleted {
                            if formId != nil {
                                context.starsContext?.load(force: true)
                            }
                        }
                    }
                } else {
                    guard let reference = arguments.reference else {
                        return
                    }
                    upgradeGiftImpl = { formId, keepOriginalInfo in
                        return self.context.engine.payments.upgradeStarGift(formId: formId, reference: reference, keepOriginalInfo: keepOriginalInfo)
                        |> afterCompleted {
                            if formId != nil {
                                context.starsContext?.load(force: true)
                            }
                        }
                    }
                }
            
                self.upgradeDisposable = (upgradeGiftImpl(formId, self.keepOriginalInfo)
                |> deliverOnMainQueue).start(next: { [weak self, weak starsContext] result in
                    guard let self, let controller = self.getController() as? GiftViewScreen else {
                        return
                    }
                    self.inProgress = false
                    self.inUpgradePreview = false
                    
                    self.subject = .profileGift(peerId, result)
                    controller.animateSuccess()
                    self.updated(transition: .spring(duration: 0.4))
                    
                    Queue.mainQueue().after(0.5) {
                        starsContext?.load(force: true)
                    }
                })
            }
            
            if let upgradeStars = arguments.upgradeStars, upgradeStars > 0 {
                proceed(nil)
            } else if let upgradeForm = self.upgradeForm, let price = upgradeForm.invoice.prices.first?.amount {
                if starsState.balance < StarsAmount(value: price, nanos: 0) {
                    let _ = (self.optionsPromise.get()
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
            }
            
            if let controller = self.getController() as? GiftViewScreen {
                controller.showBalance = true
            }
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, subject: self.subject, animateOut: self.animateOut, getController: self.getController)
    }
    
    static var body: Body {
        let priceButton = Child(PlainButtonComponent.self)
        
        let buttons = Child(ButtonsComponent.self)
        let animation = Child(GiftCompositionComponent.self)
        let title = Child(MultilineTextComponent.self)
        let description = Child(MultilineTextComponent.self)
        
        let transferButton = Child(PlainButtonComponent.self)
        let wearButton = Child(PlainButtonComponent.self)
        let resellButton = Child(PlainButtonComponent.self)
        
        let wearAvatar = Child(AvatarComponent.self)
        let wearPeerName = Child(MultilineTextComponent.self)
        let wearPeerStatus = Child(MultilineTextComponent.self)
        let wearTitle = Child(MultilineTextComponent.self)
        let wearDescription = Child(MultilineTextComponent.self)
        let wearPerks = Child(List<Empty>.self)
        
        let hiddenText = Child(MultilineTextComponent.self)
        let table = Child(TableComponent.self)
        let additionalText = Child(MultilineTextComponent.self)
        let button = Child(ButtonComponent.self)
        
        let upgradeTitle = Child(MultilineTextComponent.self)
        let upgradeDescription = Child(BalancedTextComponent.self)
        let upgradePerks = Child(List<Empty>.self)
        let upgradeKeepName = Child(PlainButtonComponent.self)
                
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
            var uniqueGift: StarGift.UniqueGift?
            var isSelfGift = false
            var isChannelGift = false
            var isMyUniqueGift = false
            
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
                switch arguments.gift {
                case let .generic(gift):
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
                }
                savedToProfile = arguments.savedToProfile
                if let reference = arguments.reference, case .peer = reference {
                    isChannelGift = true
                    incoming = true
                } else {
                    incoming = arguments.incoming || arguments.peerId == component.context.account.peerId
                }
                nameHidden = arguments.nameHidden
                
                isSelfGift = arguments.messageId?.peerId == component.context.account.peerId
                
                if case let .peerId(peerId) = uniqueGift?.owner, peerId == component.context.account.peerId || isChannelGift {
                    isMyUniqueGift = true
                }
                
                if isSelfGift {
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
            
            if !canUpgrade, let gift = state.starGiftsMap[giftId], let _ = gift.upgradeStars {
                canUpgrade = true
            }
                        
            var showUpgradePreview = false
            if state.inUpgradePreview, let _ = state.sampleGiftAttributes {
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
            
            let buttons = buttons.update(
                component: ButtonsComponent(
                    theme: theme,
                    isOverlay: showUpgradePreview || uniqueGift != nil,
                    showMoreButton: uniqueGift != nil && !showWearPreview,
                    closePressed: { [weak state] in
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
                    },
                    morePressed: { [weak state] node, gesture in
                        state?.openMore(node: node, gesture: gesture)
                    }
                ),
                availableSize: CGSize(width: 30.0, height: 30.0),
                transition: context.transition
            )
                                                            
            var originY: CGFloat = 0.0
                        
            let headerHeight: CGFloat
            let headerSubject: GiftCompositionComponent.Subject?
            if let uniqueGift {
                if showWearPreview {
                    headerHeight = 200.0
                } else if case let .peerId(peerId) = uniqueGift.owner, peerId == component.context.account.peerId || isChannelGift {
                    headerHeight = 314.0
                } else {
                    headerHeight = 240.0
                }
                headerSubject = .unique(uniqueGift)
            } else if state.inUpgradePreview, let attributes = state.sampleGiftAttributes {
                headerHeight = 258.0
                headerSubject = .preview(attributes)
            } else if case let .upgradePreview(attributes, _) = component.subject {
                headerHeight = 258.0
                headerSubject = .preview(attributes)
            } else if let animationFile {
                headerHeight = 210.0
                headerSubject = .generic(animationFile)
            } else {
                headerHeight = 210.0
                headerSubject = nil
            }
            
            var ownerPeerId: EnginePeer.Id?
            if let uniqueGift, case let .peerId(peerId) = uniqueGift.owner {
                ownerPeerId = peerId
            }
            let wearOwnerPeerId = ownerPeerId ?? component.context.account.peerId
            
            var wearPeerNameChild: _UpdatedChildComponent?
            if showWearPreview, let uniqueGift {
                var peerName = ""
                if let ownerPeer = state.peerMap[wearOwnerPeerId] {
                    peerName = ownerPeer.displayTitle(strings: strings, displayOrder: nameDisplayOrder)
                }
                wearPeerNameChild = wearPeerName.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: peerName,
                            font: Font.bold(28.0),
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
                if case .wearPreview = component.subject {
                    giftTitle = uniqueGift.title
                } else {
                    
                    giftTitle = "\(uniqueGift.title) #\(presentationStringsFormattedNumber(uniqueGift.number, environment.dateTimeFormat.groupingSeparator))"
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
                
                var titleOriginY = headerHeight + 18.0
                context.add(wearTitle
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: titleOriginY + wearTitle.size.height))
                    .appear(.default(alpha: true))
                    .disappear(.default(alpha: true))
                )
                titleOriginY += wearTitle.size.height
                titleOriginY += 18.0
                
                context.add(wearDescription
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: titleOriginY + wearDescription.size.height))
                    .appear(.default(alpha: true))
                    .disappear(.default(alpha: true))
                )
            }
            
            var animationOffset: CGPoint?
            var animationScale: CGFloat?
            if let wearPeerNameChild {
                animationOffset = CGPoint(x: wearPeerNameChild.size.width / 2.0 + 20.0 - 12.0, y: 56.0)
                animationScale = 0.19
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
                        externalState: giftCompositionExternalState,
                        requestUpdate: { [weak state] in
                            state?.updated()
                        }
                    ),
                    availableSize: CGSize(width: context.availableSize.width, height: headerHeight),
                    transition: context.transition
                )
                context.add(animation
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: headerHeight / 2.0))
                )
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
                    context.add(wearAvatar
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: 67.0))
                        .appear(.default(scale: true, alpha: true))
                        .disappear(.default(scale: true, alpha: true))
                    )
                }
                
                let wearPeerStatus = wearPeerStatus.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: isChannelGift ? strings.Channel_Status : strings.Presence_online,
                            font: Font.regular(17.0),
                            textColor: vibrantColor,
                            paragraphAlignment: .center
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 5,
                        lineSpacing: 0.2
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 50.0, height: CGFloat.greatestFiniteMagnitude),
                    transition: .immediate
                )
                                
                context.add(wearPeerNameChild
                    .position(CGPoint(x: context.availableSize.width / 2.0 - 12.0, y: 144.0))
                    .appear(.default(alpha: true))
                    .disappear(.default(alpha: true))
                )
                context.add(wearPeerStatus
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: 174.0))
                    .appear(.default(alpha: true))
                    .disappear(.default(alpha: true))
                )
                originY += 18.0
                originY += 28.0
                originY += 18.0
                originY += 20.0
                originY += 24.0
                                
                let textColor = theme.actionSheet.primaryTextColor
                let secondaryTextColor = theme.actionSheet.secondaryTextColor
                let linkColor = theme.actionSheet.controlAccentColor
                
                var items: [AnyComponentWithIdentity<Empty>] = []
                items.append(
                    AnyComponentWithIdentity(
                        id: "badge",
                        component: AnyComponent(ParagraphComponent(
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
                        component: AnyComponent(ParagraphComponent(
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
                        component: AnyComponent(ParagraphComponent(
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
                let description: String
                let uniqueText: String
                let transferableText: String
                let tradableText: String
                if case let .upgradePreview(_, name) = component.subject {
                    title = environment.strings.Gift_Upgrade_IncludeTitle
                    description = environment.strings.Gift_Upgrade_IncludeDescription(name).string
                    uniqueText = strings.Gift_Upgrade_Unique_IncludeDescription
                    transferableText = strings.Gift_Upgrade_Transferable_IncludeDescription
                    tradableText = strings.Gift_Upgrade_Tradable_IncludeDescription
                } else {
                    title = environment.strings.Gift_Upgrade_Title
                    description = environment.strings.Gift_Upgrade_Description
                    uniqueText = strings.Gift_Upgrade_Unique_Description
                    transferableText = strings.Gift_Upgrade_Transferable_Description
                    tradableText = strings.Gift_Upgrade_Tradable_Description
                }
                
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
                    component: BalancedTextComponent(
                        text: .plain(NSAttributedString(
                            string: description,
                            font: Font.regular(13.0),
                            textColor: vibrantColor,
                            paragraphAlignment: .center
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 5,
                        lineSpacing: 0.2
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 50.0, height: CGFloat.greatestFiniteMagnitude),
                    transition: .immediate
                )
                
                let spacing: CGFloat = 6.0
                let totalHeight: CGFloat = upgradeTitle.size.height + spacing + upgradeDescription.size.height
                
                context.add(upgradeTitle
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: floor(212.0 - totalHeight / 2.0 + upgradeTitle.size.height / 2.0)))
                    .appear(.default(alpha: true))
                    .disappear(.default(alpha: true))
                )
               
                context.add(upgradeDescription
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: floor(212.0 + totalHeight / 2.0 - upgradeDescription.size.height / 2.0)))
                    .appear(.default(alpha: true))
                    .disappear(.default(alpha: true))
                )
                originY += 24.0
                
                let textColor = theme.actionSheet.primaryTextColor
                let secondaryTextColor = theme.actionSheet.secondaryTextColor
                let linkColor = theme.actionSheet.controlAccentColor
                
                var items: [AnyComponentWithIdentity<Empty>] = []
                items.append(
                    AnyComponentWithIdentity(
                        id: "unique",
                        component: AnyComponent(ParagraphComponent(
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
                        id: "transferable",
                        component: AnyComponent(ParagraphComponent(
                            title: strings.Gift_Upgrade_Transferable_Title,
                            titleColor: textColor,
                            text: transferableText,
                            textColor: secondaryTextColor,
                            accentColor: linkColor,
                            iconName: "Premium/Collectible/Transferable",
                            iconColor: linkColor
                        ))
                    )
                )
                items.append(
                    AnyComponentWithIdentity(
                        id: "tradable",
                        component: AnyComponent(ParagraphComponent(
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
                if let uniqueGift {
                    titleString = uniqueGift.title
                    descriptionText = "\(strings.Gift_Unique_Collectible) #\(presentationStringsFormattedNumber(uniqueGift.number, environment.dateTimeFormat.groupingSeparator))"
                } else if soldOut {
                    descriptionText = strings.Gift_View_UnavailableDescription
                } else if upgraded {
                    descriptionText = strings.Gift_View_UpgradedDescription
                } else if incoming {
                    if let _ = upgradeStars {
                        descriptionText = strings.Gift_View_FreeUpgradeDescription
                    } else if let convertStars, !upgraded {
                        if !converted {
                            if canUpgrade || upgradeStars != nil {
                                descriptionText = isChannelGift ? strings.Gift_View_KeepUpgradeOrConvertDescription_Channel(strings.Gift_View_KeepOrConvertDescription_Stars(Int32(convertStars))).string : strings.Gift_View_KeepUpgradeOrConvertDescription(strings.Gift_View_KeepOrConvertDescription_Stars(Int32(convertStars))).string
                            } else {
                                descriptionText = isChannelGift ? strings.Gift_View_KeepOrConvertDescription_Channel(strings.Gift_View_KeepOrConvertDescription_Stars(Int32(convertStars))).string : strings.Gift_View_KeepOrConvertDescription(strings.Gift_View_KeepOrConvertDescription_Stars(Int32(convertStars))).string
                            }
                        } else {
                            descriptionText = strings.Gift_View_ConvertedDescription(strings.Gift_View_ConvertedDescription_Stars(Int32(convertStars))).string
                        }
                    } else {
                        descriptionText = strings.Gift_View_BotDescription
                    }
                } else if let peerId = subject.arguments?.peerId, let peer = state.peerMap[peerId] {
                    if let _ = upgradeStars {
                        descriptionText = strings.Gift_View_FreeUpgradeOtherDescription(peer.compactDisplayTitle).string
                    } else if case .message = subject, let convertStars {
                        descriptionText = strings.Gift_View_OtherDescription(peer.compactDisplayTitle, strings.Gift_View_OtherDescription_Stars(Int32(convertStars))).string
                    } else {
                        descriptionText = ""
                    }
                } else {
                    descriptionText = ""
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
                
                let title = title.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: titleString,
                            font: uniqueGift != nil ? Font.bold(20.0) : Font.bold(25.0),
                            textColor: uniqueGift != nil ? .white : theme.actionSheet.primaryTextColor,
                            paragraphAlignment: .center
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 1
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                    transition: .immediate
                )
                context.add(title
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: uniqueGift != nil ? 190.0 : 177.0))
                    .appear(.default(alpha: true))
                    .disappear(.default(alpha: true))
                )
                
                if !descriptionText.isEmpty {
                    let linkColor = theme.actionSheet.controlAccentColor
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
                        textColor = vibrantColor
                    } else {
                        textFont = soldOut ? Font.medium(15.0) : Font.regular(15.0)
                        textColor = soldOut ? theme.list.itemDestructiveColor : theme.list.itemPrimaryTextColor
                    }
                    let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: textFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
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
                    let description = description.update(
                        component: MultilineTextComponent(
                            text: .plain(attributedString),
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 5,
                            lineSpacing: 0.2,
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
                                    state?.openStarsIntro()
                                }
                            }
                        ),
                        availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 50.0, height: CGFloat.greatestFiniteMagnitude),
                        transition: .immediate
                    )
                    context.add(description
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: 207.0 + description.size.height / 2.0))
                        .appear(.default(alpha: true))
                        .disappear(.default(alpha: true))
                    )
                    
                    if uniqueGift != nil {
                        originY += 16.0
                    } else {
                        originY += description.size.height + 21.0
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
                    } else if let peerId = subject.arguments?.peerId, let peer = state.peerMap[peerId], subject.arguments?.fromPeerId != nil {
                        hiddenDescription = text != nil ? strings.Gift_View_Outgoing_NameAndMessageHidden(peer.compactDisplayTitle).string : strings.Gift_View_Outgoing_NameHidden(peer.compactDisplayTitle).string
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
                        )
                        
                        originY += hiddenText.size.height
                        originY += 11.0
                    }
                }
                
                let tableFont = Font.regular(15.0)
                let tableBoldFont = Font.semibold(15.0)
                let tableItalicFont = Font.italic(15.0)
                let tableBoldItalicFont = Font.semiboldItalic(15.0)
                let tableMonospaceFont = Font.monospace(15.0)
                let tableLargeMonospaceFont = Font.monospace(16.0)
                
                let tableTextColor = theme.list.itemPrimaryTextColor
                let tableLinkColor = theme.list.itemAccentColor
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
                                            if case let .model(_, file, _) = attribute {
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
                                                        PeerCellComponent(
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
                                            PeerCellComponent(
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
                            
                            func formatAddress(_ str: String) -> String {
                                guard str.count == 48 && !str.hasSuffix(".ton") else {
                                    return str
                                }
                                var result = str
                                let middleIndex = result.index(result.startIndex, offsetBy: str.count / 2)
                                result.insert("\n", at: middleIndex)
                                return result
                            }
                            
                            tableItems.append(.init(
                                id: "address_owner",
                                title: strings.Gift_Unique_Owner,
                                component: AnyComponent(
                                    Button(
                                        content: AnyComponent(
                                            MultilineTextComponent(text: .plain(NSAttributedString(string: formatAddress(address), font: tableLargeMonospaceFont, textColor: tableLinkColor)), maximumNumberOfLines: 2, lineSpacing: 0.2)
                                        ),
                                        action: { [weak state] in
                                            state?.copyAddress(address)
                                        }
                                    )
                                )
                            ))
                        }
                    } else if let peerId = subject.arguments?.fromPeerId, let peer = state.peerMap[peerId] {
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
                                                PeerCellComponent(
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
                                    PeerCellComponent(
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
                                    PeerCellComponent(
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
                    if isMyUniqueGift, case let .peerId(peerId) = uniqueGift.owner {
                        var canTransfer = true
                        var canResell = true
                        if let peer = state.peerMap[peerId], case let .channel(channel) = peer {
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
                        
                        var buttonOriginX = sideInset
                        if canTransfer {
                            let transferButton = transferButton.update(
                                component: PlainButtonComponent(
                                    content: AnyComponent(
                                        HeaderButtonComponent(
                                            title: strings.Gift_View_Header_Transfer,
                                            iconName: "Premium/Collectible/Transfer"
                                        )
                                    ),
                                    effectAlignment: .center,
                                    action: { [weak state] in
                                        state?.transferGift()
                                    }
                                ),
                                environment: {},
                                availableSize: CGSize(width: buttonWidth, height: buttonHeight),
                                transition: context.transition
                            )
                            context.add(transferButton
                                .position(CGPoint(x: buttonOriginX + buttonWidth / 2.0, y: headerHeight - buttonHeight / 2.0 - 16.0))
                                .appear(.default(scale: true, alpha: true))
                                .disappear(.default(scale: true, alpha: true))
                            )
                            buttonOriginX += buttonWidth + buttonSpacing
                        }
                        
                        let wearButton = wearButton.update(
                            component: PlainButtonComponent(
                                content: AnyComponent(
                                    HeaderButtonComponent(
                                        title: isWearing ? strings.Gift_View_Header_TakeOff : strings.Gift_View_Header_Wear,
                                        iconName: isWearing ? "Premium/Collectible/Unwear" : "Premium/Collectible/Wear"
                                    )
                                ),
                                effectAlignment: .center,
                                action: { [weak state] in
                                    if let state {
                                        if isWearing {
                                            state.commitTakeOff()

                                            state.showAttributeInfo(tag: state.statusTag, text: strings.Gift_View_TookOff("\(uniqueGift.title) #\(presentationStringsFormattedNumber(uniqueGift.number, environment.dateTimeFormat.groupingSeparator))").string)
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
                                                    state.showAttributeInfo(tag: state.statusTag, text: strings.Gift_View_PutOn("\(uniqueGift.title) #\(presentationStringsFormattedNumber(uniqueGift.number, environment.dateTimeFormat.groupingSeparator))").string)
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
                        context.add(wearButton
                            .position(CGPoint(x: buttonOriginX + buttonWidth / 2.0, y: headerHeight - buttonHeight / 2.0 - 16.0))
                            .appear(.default(scale: true, alpha: true))
                            .disappear(.default(scale: true, alpha: true))
                        )
                        buttonOriginX += buttonWidth + buttonSpacing
                        
                        if canResell {
                            let resellButton = resellButton.update(
                                component: PlainButtonComponent(
                                    content: AnyComponent(
                                        HeaderButtonComponent(
                                            title: uniqueGift.resellStars == nil ? strings.Gift_View_Sell : strings.Gift_View_Unlist,
                                            iconName: uniqueGift.resellStars == nil ? "Premium/Collectible/Sell" : "Premium/Collectible/Unlist"
                                        )
                                    ),
                                    effectAlignment: .center,
                                    action: { [weak state] in
                                        state?.resellGift()
                                    }
                                ),
                                environment: {},
                                availableSize: CGSize(width: buttonWidth, height: buttonHeight),
                                transition: context.transition
                            )
                            context.add(resellButton
                                .position(CGPoint(x: buttonOriginX + buttonWidth / 2.0, y: headerHeight - buttonHeight / 2.0 - 16.0))
                                .appear(.default(scale: true, alpha: true))
                                .disappear(.default(scale: true, alpha: true))
                            )
                        }
                    }
                                        
                    let order: [StarGift.UniqueGift.Attribute.AttributeType] = [
                        .model, .backdrop, .pattern, .originalInfo
                    ]
                    
                    var attributeMap: [StarGift.UniqueGift.Attribute.AttributeType: StarGift.UniqueGift.Attribute] = [:]
                    for attribute in uniqueGift.attributes {
                        attributeMap[attribute.attributeType] = attribute
                    }
                    
                    var hasOriginalInfo = false
                    for type in order {
                        if let attribute = attributeMap[type] {
                            let id: String
                            let title: String?
                            let value: NSAttributedString
                            let percentage: Float?
                            let tag: AnyObject?
                            var hasBackground = false
                            
                            switch attribute {
                            case let .model(name, _, rarity):
                                id = "model"
                                title = strings.Gift_Unique_Model
                                value = NSAttributedString(string: name, font: tableFont, textColor: tableTextColor)
                                percentage = Float(rarity) * 0.1
                                tag = state.modelButtonTag
                            case let .backdrop(name, _, _, _, _, _, rarity):
                                id = "backdrop"
                                title = strings.Gift_Unique_Backdrop
                                value = NSAttributedString(string: name, font: tableFont, textColor: tableTextColor)
                                percentage = Float(rarity) * 0.1
                                tag = state.backdropButtonTag
                            case let .pattern(name, _, rarity):
                                id = "pattern"
                                title = strings.Gift_Unique_Symbol
                                value = NSAttributedString(string: name, font: tableFont, textColor: tableTextColor)
                                percentage = Float(rarity) * 0.1
                                tag = state.symbolButtonTag
                            case let .originalInfo(senderPeerId, recipientPeerId, date, text, entities):
                                id = "originalInfo"
                                title = nil
                                hasBackground = true
                                
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
                                percentage = nil
                                tag = nil
                                hasOriginalInfo = true
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
                                            horizontalAlignment: .center,
                                            maximumNumberOfLines: 0,
                                            insets: id == "originalInfo" ? UIEdgeInsets(top: 2.0, left: 0.0, bottom: 2.0, right: 0.0) : .zero,
                                            highlightColor: tableLinkColor.withAlphaComponent(0.1),
                                            handleSpoilers: true,
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
                            if let percentage, let tag {  
                                items.append(AnyComponentWithIdentity(
                                    id: AnyHashable(1),
                                    component: AnyComponent(Button(
                                        content: AnyComponent(ButtonContentComponent(
                                            context: component.context,
                                            text: formatPercentage(percentage),
                                            color: theme.list.itemAccentColor
                                        )),
                                        action: { [weak state] in
                                            state?.showAttributeInfo(tag: tag, text: strings.Gift_Unique_AttributeDescription(formatPercentage(percentage)).string)
                                        }
                                    ).tagged(tag))
                                ))
                            }
                            let itemComponent = AnyComponent(
                                HStack(items, spacing: 4.0)
                            )
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
                    let valueString = "\(presentationStringsFormattedNumber(abs(Int32(finalStars)), dateTimeFormat.groupingSeparator))⭐️"
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
                                                text: strings.Gift_View_Sale(strings.Gift_View_Sale_Stars(Int32(convertStars))).string,
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
                        var items: [AnyComponentWithIdentity<Empty>] = []
                        items.append(
                            AnyComponentWithIdentity(
                                id: AnyHashable(0),
                                component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: strings.Gift_View_Status_NonUnique, font: tableFont, textColor: tableTextColor))))
                            )
                        )
                        if incoming {
                            items.append(
                                AnyComponentWithIdentity(
                                    id: AnyHashable(1),
                                    component: AnyComponent(Button(
                                        content: AnyComponent(ButtonContentComponent(
                                            context: component.context,
                                            text: strings.Gift_View_Status_Upgrade,
                                            color: theme.list.itemAccentColor
                                        )),
                                        action: { [weak state] in
                                            state?.requestUpgradePreview()
                                        }
                                    ))
                                )
                            )
                        }
                        tableItems.append(.init(
                            id: "status",
                            title: strings.Gift_View_Status,
                            component: AnyComponent(
                                HStack(items, spacing: 4.0)
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
                        theme: environment.theme,
                        items: tableItems
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude),
                    transition: context.transition
                )
                context.add(table
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + table.size.height / 2.0))
                    .appear(.default(alpha: true))
                    .disappear(.default(alpha: true))
                )
                originY += table.size.height + 23.0
            }
                        
            var resellStars: Int64?
            var selling = false
            if let uniqueGift {
                resellStars = uniqueGift.resellStars
                
                if let resellStars {
                    if incoming || ownerPeerId == component.context.account.peerId {
                        let priceButton = priceButton.update(
                            component: PlainButtonComponent(
                                content: AnyComponent(
                                    PriceButtonComponent(price: presentationStringsFormattedNumber(Int32(resellStars), environment.dateTimeFormat.groupingSeparator))
                                ),
                                effectAlignment: .center,
                                action: { [weak state] in
                                    state?.resellGift(update: true)
                                },
                                animateScale: false
                            ),
                            availableSize: CGSize(width: 150.0, height: 30.0),
                            transition: context.transition
                        )
                        context.add(priceButton
                            .position(CGPoint(x: environment.safeInsets.left + 16.0 + priceButton.size.width / 2.0, y: 28.0))
                            .appear(.default(scale: true, alpha: true))
                            .disappear(.default(scale: true, alpha: true))
                        )
                    }
                    if case let .uniqueGift(_, recipientPeerId) = component.subject, recipientPeerId != nil {
                    } else if ownerPeerId != component.context.account.peerId {
                        selling = true
                    }
                }
            }
            
            if ((incoming && !converted && !upgraded) || exported || selling) && (!showUpgradePreview && !showWearPreview) {
                let linkColor = theme.actionSheet.controlAccentColor
                if state.cachedSmallChevronImage == nil || state.cachedSmallChevronImage?.1 !== environment.theme {
                    state.cachedSmallChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextRightArrow"), color: linkColor)!, theme)
                }
                var addressToOpen: String?
                var descriptionText: String
                if let uniqueGift, selling {
                    let ownerName: String
                    if case let .peerId(peerId) = uniqueGift.owner {
                        ownerName = state.peerMap[peerId]?.compactDisplayTitle ?? ""
                    } else {
                        ownerName = ""
                    }
                    descriptionText = strings.Gift_View_SellingGiftInfo(ownerName).string
                } else if let uniqueGift, let address = uniqueGift.giftAddress, case .address = uniqueGift.owner {
                    addressToOpen = address
                    descriptionText = strings.Gift_View_TonGiftAddressInfo
                } else if savedToProfile {
                    descriptionText = isChannelGift ? strings.Gift_View_DisplayedInfoHide_Channel : strings.Gift_View_DisplayedInfoHide
                } else if let upgradeStars, upgradeStars > 0 && !upgraded {
                    descriptionText = isChannelGift ? strings.Gift_View_HiddenInfoShow_Channel : strings.Gift_View_HiddenInfoShow
                } else {
                    if let _ = uniqueGift {
                        descriptionText = isChannelGift ? strings.Gift_View_UniqueHiddenInfo_Channel : strings.Gift_View_UniqueHiddenInfo
                    } else {
                        descriptionText = isChannelGift ? strings.Gift_View_HiddenInfo_Channel : strings.Gift_View_HiddenInfo
                    }
                }
                
                let textFont = Font.regular(13.0)
                let textColor = theme.list.itemSecondaryTextColor
                let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: textFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
                    return (TelegramTextAttributes.URL, contents)
                })
                
                descriptionText = descriptionText.replacingOccurrences(of: " >]", with: "\u{00A0}>]")
                let attributedString = parseMarkdownIntoAttributedString(descriptionText, attributes: markdownAttributes, textAlignment: .center).mutableCopy() as! NSMutableAttributedString
                if let range = attributedString.string.range(of: ">"), let chevronImage = state.cachedSmallChevronImage?.0 {
                    attributedString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: attributedString.string))
                }
                
                originY -= 5.0
                let additionalText = additionalText.update(
                    component: MultilineTextComponent(
                        text: .plain(attributedString),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 5,
                        lineSpacing: 0.2,
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
                                if let addressToOpen {
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
            
            let buttonSize = CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0)
            let buttonBackground = ButtonComponent.Background(
                color: theme.list.itemCheckColors.fillColor,
                foreground: theme.list.itemCheckColors.foregroundColor,
                pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
            )
            let buttonChild: _UpdatedChildComponent
            if showWearPreview, let uniqueGift {
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
                                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                        let text = strings.Gift_View_TooltipPremiumWearing
                                        let tooltipController = UndoOverlayController(
                                            presentationData: presentationData,
                                            content: .premiumPaywall(title: nil, text: text, customUndoText: nil, timeout: nil, linkAction: nil),
                                            position: .bottom,
                                            animateInAsReplacement: false,
                                            appearance: UndoOverlayController.Appearance(sideInset: 16.0, bottomInset: 62.0),
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
                                        controller.present(tooltipController, in: .window(.root))
                                    }
                                } else {
                                    state.commitWear(uniqueGift)
                                    if case .wearPreview = component.subject {
                                        state.dismiss(animated: true)
                                    } else {
                                        Queue.mainQueue().after(0.2) {
                                            state.showAttributeInfo(tag: state.statusTag, text: strings.Gift_View_PutOn("\(uniqueGift.title) #\(presentationStringsFormattedNumber(uniqueGift.number, environment.dateTimeFormat.groupingSeparator))").string)
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
                var upgradeString = strings.Gift_Upgrade_Upgrade
                if let upgradeForm = state.upgradeForm, let price = upgradeForm.invoice.prices.first?.amount {
                    upgradeString += "  # \(presentationStringsFormattedNumber(Int32(price), environment.dateTimeFormat.groupingSeparator))"
                }
                let buttonTitle = subject.arguments?.upgradeStars != nil ? strings.Gift_Upgrade_Confirm : upgradeString
                let buttonAttributedString = NSMutableAttributedString(string: buttonTitle, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center)
                if let range = buttonAttributedString.string.range(of: "#"), let starImage = state.cachedStarImage?.0 {
                    buttonAttributedString.addAttribute(.attachment, value: starImage, range: NSRange(range, in: buttonAttributedString.string))
                    buttonAttributedString.addAttribute(.foregroundColor, value: theme.list.itemCheckColors.foregroundColor, range: NSRange(range, in: buttonAttributedString.string))
                    buttonAttributedString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: buttonAttributedString.string))
                    buttonAttributedString.addAttribute(.kern, value: 2.0, range: NSRange(range, in: buttonAttributedString.string))
                }
                buttonChild = button.update(
                    component: ButtonComponent(
                        background: buttonBackground,
                        content: AnyComponentWithIdentity(
                            id: AnyHashable("upgrade"),
                            component: AnyComponent(MultilineTextComponent(text: .plain(buttonAttributedString)))
                        ),
                        isEnabled: true,
                        displaysProgress: state.inProgress,
                        action: { [weak state] in
                            state?.commitUpgrade()
                        }),
                    availableSize: buttonSize,
                    transition: context.transition
                )
            } else if upgraded, let upgradeMessageIdId = subject.arguments?.upgradeMessageId, let originalMessageId = subject.arguments?.messageId {
                let upgradeMessageId = MessageId(peerId: originalMessageId.peerId, namespace: originalMessageId.namespace, id: upgradeMessageIdId)
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
                            state?.viewUpgradedGift(messageId: upgradeMessageId)
                        }),
                    availableSize: buttonSize,
                    transition: context.transition
                )
            } else if incoming && !converted && !upgraded, let upgradeStars, upgradeStars > 0 {
                let buttonTitle = strings.Gift_View_UpgradeForFree
                buttonChild = button.update(
                    component: ButtonComponent(
                        background: buttonBackground.withIsShimmering(true),
                        content: AnyComponentWithIdentity(
                            id: AnyHashable("freeUpgrade"),
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
            } else if incoming && !converted && !savedToProfile {
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
            } else if !incoming, let resellStars, !isMyUniqueGift {
                if state.cachedStarImage == nil || state.cachedStarImage?.1 !== theme {
                    state.cachedStarImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/PremiumIcon"), color: theme.list.itemCheckColors.foregroundColor)!, theme)
                }
                var upgradeString = strings.Gift_View_BuyFor
                upgradeString += "  # \(presentationStringsFormattedNumber(Int32(resellStars), environment.dateTimeFormat.groupingSeparator))"
                
                let buttonTitle = subject.arguments?.upgradeStars != nil ? strings.Gift_Upgrade_Confirm : upgradeString
                let buttonAttributedString = NSMutableAttributedString(string: buttonTitle, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center)
                if let range = buttonAttributedString.string.range(of: "#"), let starImage = state.cachedStarImage?.0 {
                    buttonAttributedString.addAttribute(.attachment, value: starImage, range: NSRange(range, in: buttonAttributedString.string))
                    buttonAttributedString.addAttribute(.foregroundColor, value: theme.list.itemCheckColors.foregroundColor, range: NSRange(range, in: buttonAttributedString.string))
                    buttonAttributedString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: buttonAttributedString.string))
                    buttonAttributedString.addAttribute(.kern, value: 2.0, range: NSRange(range, in: buttonAttributedString.string))
                }
                buttonChild = button.update(
                    component: ButtonComponent(
                        background: buttonBackground,
                        content: AnyComponentWithIdentity(
                            id: AnyHashable("buy"),
                            component: AnyComponent(MultilineTextComponent(text: .plain(buttonAttributedString)))
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
                            state?.dismiss(animated: true)
                        }),
                    availableSize: buttonSize,
                    transition: context.transition
                )
            }
            let buttonFrame = CGRect(origin: CGPoint(x: sideInset, y: originY), size: buttonChild.size)
            context.add(buttonChild
                .position(CGPoint(x: buttonFrame.midX, y: buttonFrame.midY))
                .cornerRadius(10.0)
            )
            originY += buttonChild.size.height
            originY += 7.0
            
            context.add(buttons
                .position(CGPoint(x: context.availableSize.width - environment.safeInsets.left - 16.0 - buttons.size.width / 2.0, y: 28.0))
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
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(GiftViewSheetContent(
                        context: context.component.context,
                        subject: context.component.subject,
                        animateOut: animateOut,
                        getController: controller
                    )),
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
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
                        }
                    }
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            if animated {
                                if let controller = controller() as? GiftViewScreen {
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
                let layout = ContainerViewLayout(
                    size: context.availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: max(environment.safeInsets.bottom, sheetExternalState.contentHeight), right: 0.0),
                    safeInsets: UIEdgeInsets(top: 0.0, left: environment.safeInsets.left, bottom: 0.0, right: environment.safeInsets.right),
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
        case upgradePreview([StarGift.UniqueGift.Attribute], String)
        case wearPreview(StarGift.UniqueGift)
        
        var arguments: (peerId: EnginePeer.Id?, fromPeerId: EnginePeer.Id?, fromPeerName: String?, messageId: EngineMessage.Id?, reference: StarGiftReference?, incoming: Bool, gift: StarGift, date: Int32, convertStars: Int64?, text: String?, entities: [MessageTextEntity]?, nameHidden: Bool, savedToProfile: Bool, pinnedToTop: Bool?, converted: Bool, upgraded: Bool, refunded: Bool, canUpgrade: Bool, upgradeStars: Int64?, transferStars: Int64?, resellStars: Int64?, canExportDate: Int32?, upgradeMessageId: Int32?, canTransferDate: Int32?, canResaleDate: Int32?)? {
            switch self {
            case let .message(message):
                if let action = message.media.first(where: { $0 is TelegramMediaAction }) as? TelegramMediaAction {
                    switch action.action {
                    case let .starGift(gift, convertStars, text, entities, nameHidden, savedToProfile, converted, upgraded, canUpgrade, upgradeStars, isRefunded, upgradeMessageId, peerId, senderId, savedId):
                        var reference: StarGiftReference
                        if let peerId, let savedId {
                            reference = .peer(peerId: peerId, id: savedId)
                        } else {
                            reference = .message(messageId: message.id)
                        }
                        return (message.id.peerId, senderId ?? message.author?.id, message.author?.compactDisplayTitle, message.id, reference, message.flags.contains(.Incoming), gift, message.timestamp, convertStars, text, entities, nameHidden, savedToProfile, nil, converted, upgraded, isRefunded, canUpgrade, upgradeStars, nil, nil, nil, upgradeMessageId, nil, nil)
                    case let .starGiftUnique(gift, isUpgrade, isTransferred, savedToProfile, canExportDate, transferStars, _, peerId, senderId, savedId, _, canTransferDate, canResaleDate):
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
                        
                        var resellStars: Int64?
                        if case let .unique(uniqueGift) = gift {
                            resellStars = uniqueGift.resellStars
                        }
                        return (message.id.peerId, senderId ?? message.author?.id, message.author?.compactDisplayTitle, message.id, reference, incoming, gift, message.timestamp, nil, nil, nil, false, savedToProfile, nil, false, false, false, false, nil, transferStars, resellStars, canExportDate, nil, canTransferDate, canResaleDate)
                    default:
                        return nil
                    }
                }
            case let .uniqueGift(gift, _), let .wearPreview(gift):
                return (nil, nil, nil, nil, nil, false, .unique(gift), 0, nil, nil, nil, false, false, nil, false, false, false, false, nil, nil, gift.resellStars, nil, nil, nil, nil)
            case let .profileGift(peerId, gift):
                var messageId: EngineMessage.Id?
                if case let .message(messageIdValue) = gift.reference {
                    messageId = messageIdValue
                }
                var resellStars: Int64?
                if case let .unique(uniqueGift) = gift.gift {
                    resellStars = uniqueGift.resellStars
                }
                return (peerId, gift.fromPeer?.id, gift.fromPeer?.compactDisplayTitle, messageId, gift.reference, false, gift.gift, gift.date, gift.convertStars, gift.text, gift.entities, gift.nameHidden, gift.savedToProfile, gift.pinnedToTop, false, false, false, gift.canUpgrade, gift.upgradeStars, gift.transferStars, resellStars, gift.canExportDate, nil, gift.canTransferDate, gift.canResaleDate)
            case .soldOutGift:
                return nil
            case .upgradePreview:
                return nil
            }
            return nil
        }
    }
    
    private let context: AccountContext
    private let subject: GiftViewScreen.Subject
    
    fileprivate var showBalance = false {
        didSet {
            self.requestLayout(transition: .immediate)
        }
    }
    private let balanceOverlay = ComponentView<Empty>()
    
    fileprivate let updateSavedToProfile: ((StarGiftReference, Bool) -> Void)?
    fileprivate let convertToStars: (() -> Void)?
    fileprivate let transferGift: ((Bool, EnginePeer.Id) -> Signal<Never, TransferStarGiftError>)?
    fileprivate let upgradeGift: ((Int64?, Bool) -> Signal<ProfileGiftsContext.State.StarGift, UpgradeStarGiftError>)?
    fileprivate let buyGift: ((String, EnginePeer.Id, Int64?) -> Signal<Never, BuyStarGiftError>)?
    fileprivate let updateResellStars: ((Int64?) -> Signal<Never, UpdateStarGiftPriceError>)?
    fileprivate let togglePinnedToTop: ((Bool) -> Bool)?
    fileprivate let shareStory: ((StarGift.UniqueGift) -> Void)?
    
    public var disposed: () -> Void = {}
    
    public init(
        context: AccountContext,
        subject: GiftViewScreen.Subject,
        allSubjects: [GiftViewScreen.Subject]? = nil,
        index: Int? = nil,
        forceDark: Bool = false,
        updateSavedToProfile: ((StarGiftReference, Bool) -> Void)? = nil,
        convertToStars: (() -> Void)? = nil,
        transferGift: ((Bool, EnginePeer.Id) -> Signal<Never, TransferStarGiftError>)? = nil,
        upgradeGift: ((Int64?, Bool) -> Signal<ProfileGiftsContext.State.StarGift, UpgradeStarGiftError>)? = nil,
        buyGift: ((String, EnginePeer.Id, Int64?) -> Signal<Never, BuyStarGiftError>)? = nil,
        updateResellStars: ((Int64?) -> Signal<Never, UpdateStarGiftPriceError>)? = nil,
        togglePinnedToTop: ((Bool) -> Bool)? = nil,
        shareStory: ((StarGift.UniqueGift) -> Void)? = nil
    ) {
        self.context = context
        self.subject = subject
        
        self.updateSavedToProfile = updateSavedToProfile
        self.convertToStars = convertToStars
        self.transferGift = transferGift
        self.upgradeGift = upgradeGift
        self.buyGift = buyGift
        self.updateResellStars = updateResellStars
        self.togglePinnedToTop = togglePinnedToTop
        self.shareStory = shareStory
        
        var items: [GiftPagerComponent.Item] = [GiftPagerComponent.Item(id: 0, subject: subject)]
        if let allSubjects, !allSubjects.isEmpty {
            items.removeAll()
            for i in 0 ..< allSubjects.count {
                items.append(GiftPagerComponent.Item(id: i, subject: allSubjects[i]))
            }
        }
        var dismissTooltipsImpl: (() -> Void)?
        super.init(
            context: context,
            component: GiftPagerComponent(
                context: context,
                items: items,
                index: index ?? 0,
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
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposed()
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
                
        if let arguments = self.subject.arguments, let _ = self.subject.arguments?.resellStars {
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
                        theme: context.sharedContext.currentPresentationData.with { $0 }.theme,
                        action: { [weak self] in
                            guard let self, let starsContext = context.starsContext, let navigationController = self.navigationController as? NavigationController else {
                                return
                            }
                            self.dismissAnimated()
                            
                            let _ = (context.engine.payments.starsTopUpOptions()
                            |> take(1)
                            |> deliverOnMainQueue).startStandalone(next: { options in
                                let controller = context.sharedContext.makeStarsPurchaseScreen(
                                    context: context,
                                    starsContext: starsContext,
                                    options: options,
                                    purpose: .generic,
                                    completion: { _ in }
                                )
                                navigationController.pushViewController(controller)
                            })
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

private func formatPercentage(_ value: Float) -> String {
    return String(format: "%0.1f%%", value).replacingOccurrences(of: ".0%", with: "%").replacingOccurrences(of: ",0%", with: "%")
}



private final class PeerCellComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let peer: EnginePeer?

    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, peer: EnginePeer?) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.peer = peer
    }

    static func ==(lhs: PeerCellComponent, rhs: PeerCellComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        return true
    }

    final class View: UIView {
        private let avatarNode: AvatarNode
        private let text = ComponentView<Empty>()
                
        private var component: PeerCellComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 8.0))
                                         
            super.init(frame: frame)
            
            self.addSubnode(self.avatarNode)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: PeerCellComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
                                    
            let avatarSize = CGSize(width: 22.0, height: 22.0)
            let spacing: CGFloat = 6.0
            
            let peerName: String
            let avatarOverride: AvatarNodeImageOverride?
            if let peerValue = component.peer {
                peerName = peerValue.compactDisplayTitle
                avatarOverride = nil
            } else {
                peerName = component.strings.Gift_View_HiddenName
                avatarOverride = .anonymousSavedMessagesIcon(isColored: true)
            }
            
            let avatarNaturalSize = CGSize(width: 40.0, height: 40.0)
            self.avatarNode.setPeer(context: component.context, theme: component.theme, peer: component.peer, overrideImage: avatarOverride)
            self.avatarNode.bounds = CGRect(origin: .zero, size: avatarNaturalSize)
            
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: peerName, font: Font.regular(15.0), textColor: component.peer != nil ? component.theme.list.itemAccentColor : component.theme.list.itemPrimaryTextColor, paragraphAlignment: .left))
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - avatarSize.width - spacing, height: availableSize.height)
            )
            
            let size = CGSize(width: avatarSize.width + textSize.width + spacing, height: textSize.height)
            
            let avatarFrame = CGRect(origin: CGPoint(x: 0.0, y: floorToScreenPixels((size.height - avatarSize.height) / 2.0)), size: avatarSize)
            self.avatarNode.frame = avatarFrame
            
            if let view = self.text.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                let textFrame = CGRect(origin: CGPoint(x: avatarSize.width + spacing, y: floorToScreenPixels((size.height - textSize.height) / 2.0)), size: textSize)
                transition.setFrame(view: view, frame: textFrame)
            }
            
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

private final class ButtonContentComponent: Component {
    let context: AccountContext
    let text: String
    let color: UIColor
    
    public init(
        context: AccountContext,
        text: String,
        color: UIColor
    ) {
        self.context = context
        self.text = text
        self.color = color
    }

    public static func ==(lhs: ButtonContentComponent, rhs: ButtonContentComponent) -> Bool {
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

    public final class View: UIView {
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

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
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

private final class ParagraphComponent: CombinedComponent {
    let title: String
    let titleColor: UIColor
    let text: String
    let textColor: UIColor
    let accentColor: UIColor
    let iconName: String
    let iconColor: UIColor
    let badge: String?
    let action: () -> Void
    
    public init(
        title: String,
        titleColor: UIColor,
        text: String,
        textColor: UIColor,
        accentColor: UIColor,
        iconName: String,
        iconColor: UIColor,
        badge: String? = nil,
        action: @escaping () -> Void = {}
    ) {
        self.title = title
        self.titleColor = titleColor
        self.text = text
        self.textColor = textColor
        self.accentColor = accentColor
        self.iconName = iconName
        self.iconColor = iconColor
        self.badge = badge
        self.action = action
    }
    
    static func ==(lhs: ParagraphComponent, rhs: ParagraphComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.titleColor != rhs.titleColor {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.textColor != rhs.textColor {
            return false
        }
        if lhs.accentColor != rhs.accentColor {
            return false
        }
        if lhs.iconName != rhs.iconName {
            return false
        }
        if lhs.iconColor != rhs.iconColor {
            return false
        }
        if lhs.badge != rhs.badge {
            return false
        }
        return true
    }
    
    static var body: Body {
        let title = Child(MultilineTextComponent.self)
        let text = Child(MultilineTextComponent.self)
        let icon = Child(BundleIconComponent.self)
        let badgeBackground = Child(RoundedRectangle.self)
        let badgeText = Child(MultilineTextComponent.self)
        
        return { context in
            let component = context.component
            
            let leftInset: CGFloat = 32.0
            let rightInset: CGFloat = 24.0
            let textSideInset: CGFloat = leftInset + 8.0
            let spacing: CGFloat = 5.0
            
            let textTopInset: CGFloat = 9.0
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.title,
                        font: Font.semibold(15.0),
                        textColor: component.titleColor,
                        paragraphAlignment: .natural
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let textColor = component.textColor
            let accentColor = component.accentColor
            let markdownAttributes = MarkdownAttributes(
                body: MarkdownAttributeSet(font: textFont, textColor: textColor),
                bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor),
                link: MarkdownAttributeSet(font: textFont, textColor: accentColor),
                linkAttribute: { contents in
                    return (TelegramTextAttributes.URL, contents)
                }
            )
                        
            let text = text.update(
                component: MultilineTextComponent(
                    text: .markdown(text: component.text, attributes: markdownAttributes),
                    horizontalAlignment: .natural,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2,
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                            return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                        } else {
                            return nil
                        }
                    },
                    tapAction: { _, _ in
                        component.action()
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - leftInset - rightInset, height: context.availableSize.height),
                transition: .immediate
            )
            
            let icon = icon.update(
                component: BundleIconComponent(
                    name: component.iconName,
                    tintColor: component.iconColor
                ),
                availableSize: CGSize(width: context.availableSize.width, height: context.availableSize.height),
                transition: .immediate
            )
         
            context.add(title
                .position(CGPoint(x: textSideInset + title.size.width / 2.0, y: textTopInset + title.size.height / 2.0))
            )
            
            if let badge = component.badge {
                let badgeText = badgeText.update(
                    component: MultilineTextComponent(text: .plain(NSAttributedString(string: badge, font: Font.semibold(11.0), textColor: .white))),
                    availableSize: context.availableSize,
                    transition: context.transition
                )
                
                let badgeWidth = badgeText.size.width + 7.0
                let badgeBackground = badgeBackground.update(
                    component: RoundedRectangle(
                        color: component.accentColor,
                        cornerRadius: 5.0),
                    availableSize: CGSize(width: badgeWidth, height: 16.0),
                    transition: context.transition
                )
                
                context.add(badgeBackground
                    .position(CGPoint(x: textSideInset + title.size.width + badgeWidth / 2.0 + 5.0, y: textTopInset + title.size.height / 2.0))
                )
                
                context.add(badgeText
                    .position(CGPoint(x: textSideInset + title.size.width + badgeWidth / 2.0 + 5.0, y: textTopInset + title.size.height / 2.0))
                )
            }
            
            context.add(text
                .position(CGPoint(x: textSideInset + text.size.width / 2.0, y: textTopInset + title.size.height + spacing + text.size.height / 2.0))
            )
            
            context.add(icon
                .position(CGPoint(x: 15.0, y: textTopInset + 18.0))
            )
        
            return CGSize(width: context.availableSize.width, height: textTopInset + title.size.height + text.size.height + 20.0)
        }
    }
}

private final class GiftViewContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceNode: ASDisplayNode
    
    init(controller: ViewController, sourceNode: ASDisplayNode) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceNode.view, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

private final class HeaderButtonComponent: CombinedComponent {
    let title: String
    let iconName: String
    let isLocked: Bool
    
    public init(
        title: String,
        iconName: String,
        isLocked: Bool = false
    ) {
        self.title = title
        self.iconName = iconName
        self.isLocked = isLocked
    }
    
    static func ==(lhs: HeaderButtonComponent, rhs: HeaderButtonComponent) -> Bool {
        if lhs.title != rhs.title {
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
    
    static var body: Body {
        let background = Child(RoundedRectangle.self)
        let title = Child(MultilineTextComponent.self)
        let icon = Child(BundleIconComponent.self)
        let lockIcon = Child(BundleIconComponent.self)
        
        return { context in
            let component = context.component
            
            let background = background.update(
                component: RoundedRectangle(
                    color: UIColor.white.withAlphaComponent(0.16),
                    cornerRadius: 10.0
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            let icon = icon.update(
                component: BundleIconComponent(
                    name: component.iconName,
                    tintColor: UIColor.white
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )
            context.add(icon
                .position(CGPoint(x: context.availableSize.width / 2.0, y: 22.0))
            )
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.title,
                        font: Font.regular(11.0),
                        textColor: UIColor.white,
                        paragraphAlignment: .natural
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - 16.0, height: context.availableSize.height),
                transition: .immediate
            )
            var totalTitleWidth = title.size.width
            var titleOriginX = context.availableSize.width / 2.0 - totalTitleWidth / 2.0
            if component.isLocked {
                let titleSpacing: CGFloat = 2.0
                let lockIcon = lockIcon.update(
                    component: BundleIconComponent(
                        name: "Chat List/StatusLockIcon",
                        tintColor: UIColor.white
                    ),
                    availableSize: context.availableSize,
                    transition: .immediate
                )
                totalTitleWidth += lockIcon.size.width + titleSpacing
                titleOriginX = context.availableSize.width / 2.0 - totalTitleWidth / 2.0
                context.add(lockIcon
                    .position(CGPoint(x: titleOriginX + lockIcon.size.width / 2.0, y: 42.0))
                )
                titleOriginX += lockIcon.size.width + titleSpacing
            }
            context.add(title
                .position(CGPoint(x: titleOriginX + title.size.width / 2.0, y: 42.0))
            )
            
            return context.availableSize
        }
    }
}

private final class AvatarComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let peer: EnginePeer

    init(context: AccountContext, theme: PresentationTheme, peer: EnginePeer) {
        self.context = context
        self.theme = theme
        self.peer = peer
    }

    static func ==(lhs: AvatarComponent, rhs: AvatarComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        return true
    }

    final class View: UIView {
        private let avatarNode: AvatarNode
        
        private var component: AvatarComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 42.0))
            
            super.init(frame: frame)
            
            self.addSubnode(self.avatarNode)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: AvatarComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            self.avatarNode.frame = CGRect(origin: .zero, size: availableSize)
            self.avatarNode.setPeer(
                context: component.context,
                theme: component.theme,
                peer: component.peer,
                synchronousLoad: true
            )
            
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
