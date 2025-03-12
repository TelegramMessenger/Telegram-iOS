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

private let modelButtonTag = GenericComponentViewTag()
private let backdropButtonTag = GenericComponentViewTag()
private let symbolButtonTag = GenericComponentViewTag()
private let statusTag = GenericComponentViewTag()

private final class GiftViewSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: GiftViewScreen.Subject
    let cancel: (Bool) -> Void
    let openPeer: (EnginePeer) -> Void
    let openAddress: (String) -> Void
    let copyAddress: (String) -> Void
    let updateSavedToProfile: (Bool) -> Void
    let convertToStars: () -> Void
    let openStarsIntro: () -> Void
    let sendGift: (EnginePeer.Id) -> Void
    let openMyGifts: () -> Void
    let transferGift: () -> Void
    let upgradeGift: ((Int64?, Bool) -> Signal<ProfileGiftsContext.State.StarGift, UpgradeStarGiftError>)
    let shareGift: () -> Void
    let showAttributeInfo: (Any, String) -> Void
    let viewUpgraded: (EngineMessage.Id) -> Void
    let openMore: (ASDisplayNode, ContextGesture?) -> Void
    let getController: () -> ViewController?
    
    init(
        context: AccountContext,
        subject: GiftViewScreen.Subject,
        cancel: @escaping (Bool) -> Void,
        openPeer: @escaping (EnginePeer) -> Void,
        openAddress: @escaping (String) -> Void,
        copyAddress: @escaping (String) -> Void,
        updateSavedToProfile: @escaping (Bool) -> Void,
        convertToStars: @escaping () -> Void,
        openStarsIntro: @escaping () -> Void,
    	sendGift: @escaping (EnginePeer.Id) -> Void,
    	openMyGifts: @escaping () -> Void,
        transferGift: @escaping () -> Void,
        upgradeGift: @escaping ((Int64?, Bool) -> Signal<ProfileGiftsContext.State.StarGift, UpgradeStarGiftError>),
        shareGift: @escaping () -> Void,
        showAttributeInfo: @escaping (Any, String) -> Void,
        viewUpgraded: @escaping (EngineMessage.Id) -> Void,
        openMore: @escaping (ASDisplayNode, ContextGesture?) -> Void,
        getController: @escaping () -> ViewController?
    ) {
        self.context = context
        self.subject = subject
        self.cancel = cancel
        self.openPeer = openPeer
        self.openAddress = openAddress
        self.copyAddress = copyAddress
        self.updateSavedToProfile = updateSavedToProfile
        self.convertToStars = convertToStars
        self.openStarsIntro = openStarsIntro
        self.sendGift = sendGift
        self.openMyGifts = openMyGifts
        self.transferGift = transferGift
        self.upgradeGift = upgradeGift
        self.shareGift = shareGift
        self.showAttributeInfo = showAttributeInfo
        self.viewUpgraded = viewUpgraded
        self.openMore = openMore
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
        private let context: AccountContext
        private(set) var subject: GiftViewScreen.Subject
        private let upgradeGift: ((Int64?, Bool) -> Signal<ProfileGiftsContext.State.StarGift, UpgradeStarGiftError>)
        private let getController: () -> ViewController?
        
        private var disposable: Disposable?
        var initialized = false
        
        var peerMap: [EnginePeer.Id: EnginePeer] = [:]
        var starGiftsMap: [Int64: StarGift.Gift] = [:]
        
        var cachedCircleImage: UIImage?
        var cachedStarImage: (UIImage, PresentationTheme)?
        
        var cachedChevronImage: (UIImage, PresentationTheme)?
        var cachedSmallChevronImage: (UIImage, PresentationTheme)?
        
        var inProgress = false
        
        var inUpgradePreview = false
        var upgradeForm: BotPaymentForm?
        var upgradeFormDisposable: Disposable?
        var upgradeDisposable: Disposable?
        let levelsDisposable = MetaDisposable()
        
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
                
        init(
            context: AccountContext,
            subject: GiftViewScreen.Subject,
            upgradeGift: @escaping ((Int64?, Bool) -> Signal<ProfileGiftsContext.State.StarGift, UpgradeStarGiftError>),
            getController: @escaping () -> ViewController?
        ) {
            self.context = context
            self.subject = subject
            self.upgradeGift = upgradeGift
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
                
                self.disposable = combineLatest(queue: Queue.mainQueue(),
                    context.engine.data.get(EngineDataMap(
                        peerIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.Peer in
                            return TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                        }
                    )),
                    .single(nil) |> then(context.engine.payments.cachedStarGifts())
                ).startStrict(next: { [weak self] peers, starGifts in
                    if let strongSelf = self {
                        var peersMap: [EnginePeer.Id: EnginePeer] = [:]
                        for peerId in peerIds {
                            if let maybePeer = peers[peerId], let peer = maybePeer {
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
            
            if let starsContext = context.starsContext, let state = starsContext.currentState, state.balance < StarsAmount(value: 100, nanos: 0) {
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
            self.levelsDisposable.dispose()
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
        
        func commitUpgrade() {
            guard let arguments = self.subject.arguments, let peerId = arguments.peerId, let starsContext = self.context.starsContext, let starsState = starsContext.currentState else {
                return
            }
            
            let proceed: (Int64?) -> Void = { formId in
                self.inProgress = true
                self.updated()
                
                self.upgradeDisposable = (self.upgradeGift(formId, self.keepOriginalInfo)
                |> deliverOnMainQueue).start(next: { [weak self] result in
                    guard let self, let controller = self.getController() as? GiftViewScreen else {
                        return
                    }
                    self.inProgress = false
                    self.inUpgradePreview = false
                    
                    self.subject = .profileGift(peerId, result)
                    controller.subject = self.subject
                    controller.animateSuccess()
                    self.updated(transition: .spring(duration: 0.4))
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
                            completion: { [weak starsContext] stars in
                                starsContext?.add(balance: StarsAmount(value: stars, nanos: 0))
                                Queue.mainQueue().after(2.0) {
                                    proceed(upgradeForm.id)
                                }
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
        return State(context: self.context, subject: self.subject, upgradeGift: self.upgradeGift, getController: self.getController)
    }
    
    static var body: Body {
        let buttons = Child(ButtonsComponent.self)
        let animation = Child(GiftCompositionComponent.self)
        let title = Child(MultilineTextComponent.self)
        let description = Child(MultilineTextComponent.self)
        
        let transferButton = Child(PlainButtonComponent.self)
        let wearButton = Child(PlainButtonComponent.self)
        let shareButton = Child(PlainButtonComponent.self)
        
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
            
            if case let .soldOutGift(gift) = subject {
                animationFile = gift.file
                stars = gift.price
                text = nil
                entities = nil
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
            
            let cancel = component.cancel
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
                            cancel(true)
                        }
                    },
                    morePressed: { node, gesture in
                        component.openMore(node, gesture)
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
            
            var ownerPeerId: EnginePeer.Id
            if let uniqueGift, case let .peerId(peerId) = uniqueGift.owner {
                ownerPeerId = peerId
            } else {
                ownerPeerId = component.context.account.peerId
            }
            
            var wearPeerNameChild: _UpdatedChildComponent?
            if showWearPreview, let uniqueGift {
                var peerName = ""
                if let ownerPeer = state.peerMap[ownerPeerId] {
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
                if let ownerPeer = state.peerMap[ownerPeerId] {
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
                            tapAction: { attributes, _ in
                                if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                                    component.openStarsIntro()
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
                                            if case let .backdrop(_, innerColor, _, _, _, _) = attribute {
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
                                                    action: {
                                                        component.openPeer(peer)
                                                        Queue.mainQueue().after(0.6, {
                                                            component.cancel(false)
                                                        })
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
                                                    tag: statusTag
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
                                        action: {
                                            component.openPeer(peer)
                                            Queue.mainQueue().after(0.6, {
                                                component.cancel(false)
                                            })
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
                                        action: {
                                            component.copyAddress(address)
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
                                            action: {
                                                component.openPeer(peer)
                                                Queue.mainQueue().after(0.6, {
                                                    component.cancel(false)
                                                })
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
                                            action: {
                                                component.sendGift(peerId)
                                                Queue.mainQueue().after(0.6, {
                                                    component.cancel(false)
                                                })
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
                                action: {
                                    component.openPeer(peer)
                                    Queue.mainQueue().after(0.6, {
                                        component.cancel(false)
                                    })
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
                    if case let .peerId(peerId) = uniqueGift.owner, peerId == component.context.account.peerId || isChannelGift {
                        var canTransfer = true
                        if let peer = state.peerMap[peerId], case let .channel(channel) = peer, !channel.flags.contains(.isCreator) {
                            canTransfer = false
                        } else if subject.arguments?.transferStars == nil {
                            canTransfer = false
                        }
                        
                        let buttonsCount = canTransfer ? 3 : 2
                        
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
                                    action: {
                                        component.transferGift()
                                        Queue.mainQueue().after(0.6, {
                                            component.cancel(false)
                                        })
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

                                            component.showAttributeInfo(statusTag, strings.Gift_View_TookOff("\(uniqueGift.title) #\(presentationStringsFormattedNumber(uniqueGift.number, environment.dateTimeFormat.groupingSeparator))").string)
                                        } else {
                                            if let controller = controller() as? GiftViewScreen {
                                                controller.dismissAllTooltips()
                                            }
                                            
                                            let canWear: Bool
                                            if isChannelGift, case let .channel(channel) = state.peerMap[ownerPeerId] {
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
                                                    component.showAttributeInfo(statusTag, strings.Gift_View_PutOn("\(uniqueGift.title) #\(presentationStringsFormattedNumber(uniqueGift.number, environment.dateTimeFormat.groupingSeparator))").string)
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
                        
                        let shareButton = shareButton.update(
                            component: PlainButtonComponent(
                                content: AnyComponent(
                                    HeaderButtonComponent(
                                        title: strings.Gift_View_Header_Share,
                                        iconName: "Premium/Collectible/Share"
                                    )
                                ),
                                effectAlignment: .center,
                                action: {
                                    component.shareGift()
                                }
                            ),
                            environment: {},
                            availableSize: CGSize(width: buttonWidth, height: buttonHeight),
                            transition: context.transition
                        )
                        context.add(shareButton
                            .position(CGPoint(x: buttonOriginX + buttonWidth / 2.0, y: headerHeight - buttonHeight / 2.0 - 16.0))
                            .appear(.default(scale: true, alpha: true))
                            .disappear(.default(scale: true, alpha: true))
                        )
                    }
                    
                    let showAttributeInfo = component.showAttributeInfo
                    
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
                                tag = modelButtonTag
                            case let .backdrop(name, _, _, _, _, rarity):
                                id = "backdrop"
                                title = strings.Gift_Unique_Backdrop
                                value = NSAttributedString(string: name, font: tableFont, textColor: tableTextColor)
                                percentage = Float(rarity) * 0.1
                                tag = backdropButtonTag
                            case let .pattern(name, _, rarity):
                                id = "pattern"
                                title = strings.Gift_Unique_Symbol
                                value = NSAttributedString(string: name, font: tableFont, textColor: tableTextColor)
                                percentage = Float(rarity) * 0.1
                                tag = symbolButtonTag
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
                                                    component.openPeer(peer)
                                                    Queue.mainQueue().after(0.6, {
                                                        component.cancel(false)
                                                    })
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
                                        action: {
                                            showAttributeInfo(tag, strings.Gift_Unique_AttributeDescription(formatPercentage(percentage)).string)
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
                                            action: {
                                                component.convertToStars()
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
                        var remains: Int32 = 0
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
            
            if ((incoming && !converted && !upgraded) || exported) && (!showUpgradePreview && !showWearPreview) {
                let linkColor = theme.actionSheet.controlAccentColor
                if state.cachedSmallChevronImage == nil || state.cachedSmallChevronImage?.1 !== environment.theme {
                    state.cachedSmallChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextRightArrow"), color: linkColor)!, theme)
                }
                var addressToOpen: String?
                var descriptionText: String
                if let uniqueGift, let address = uniqueGift.giftAddress {
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
                        tapAction: { attributes, _ in
                            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                                if let addressToOpen {
                                    component.openAddress(addressToOpen)
                                    component.cancel(true)
                                } else {
                                    component.updateSavedToProfile(!savedToProfile)
                                    Queue.mainQueue().after(0.6, {
                                        component.cancel(false)
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
                if isChannelGift, case let .channel(channel) = state.peerMap[ownerPeerId], (channel.approximateBoostLevel ?? 0) < requiredLevel {
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
                                            context.engine.peers.getChannelBoostStatus(peerId: ownerPeerId),
                                            context.engine.peers.getMyBoostStatus()
                                        ).startStandalone(next: { [weak controller] boostStatus, myBoostStatus in
                                            guard let controller, let boostStatus, let myBoostStatus else {
                                                return
                                            }
                                            component.cancel(true)
                                            
                                            let levelsController = context.sharedContext.makePremiumBoostLevelsController(context: context, peerId: ownerPeerId, subject: .wearGift, boostStatus: boostStatus, myBoostStatus: myBoostStatus, forceDark: false, openStats: nil)
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
                                            action: { [weak controller] action in
                                                if case .info = action {
                                                    controller?.dismissAllTooltips()
                                                    let premiumController = context.sharedContext.makePremiumIntroController(context: context, source: .messageEffects, forceDark: false, dismissed: nil)
                                                    controller?.push(premiumController)
                                                    Queue.mainQueue().after(0.6, {
                                                        component.cancel(false)
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
                                        component.cancel(true)
                                    } else {
                                        Queue.mainQueue().after(0.2) {
                                            component.showAttributeInfo(statusTag, strings.Gift_View_PutOn("\(uniqueGift.title) #\(presentationStringsFormattedNumber(uniqueGift.number, environment.dateTimeFormat.groupingSeparator))").string)
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
                    upgradeString += "   #  \(presentationStringsFormattedNumber(Int32(price), environment.dateTimeFormat.groupingSeparator))"
                }
                let buttonTitle = subject.arguments?.upgradeStars != nil ? strings.Gift_Upgrade_Confirm : upgradeString
                let buttonAttributedString = NSMutableAttributedString(string: buttonTitle, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center)
                if let range = buttonAttributedString.string.range(of: "#"), let starImage = state.cachedStarImage?.0 {
                    buttonAttributedString.addAttribute(.attachment, value: starImage, range: NSRange(range, in: buttonAttributedString.string))
                    buttonAttributedString.addAttribute(.foregroundColor, value: environment.theme.list.itemCheckColors.foregroundColor, range: NSRange(range, in: buttonAttributedString.string))
                    buttonAttributedString.addAttribute(.baselineOffset, value: 1.0, range: NSRange(range, in: buttonAttributedString.string))
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
                        action: {
                            component.cancel(true)
                            component.viewUpgraded(upgradeMessageId)
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
                        action: {
                            component.updateSavedToProfile(!savedToProfile)
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
                        action: {
                            component.cancel(true)
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
            
            let contentSize = CGSize(width: context.availableSize.width, height: originY + 5.0 + environment.safeInsets.bottom)
        
            return contentSize
        }
    }
}

private final class GiftViewSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: GiftViewScreen.Subject
    let openPeer: (EnginePeer) -> Void
    let openAddress: (String) -> Void
    let copyAddress: (String) -> Void
    let updateSavedToProfile: (Bool) -> Void
    let convertToStars: () -> Void
    let openStarsIntro: () -> Void
    let sendGift: (EnginePeer.Id) -> Void
    let openMyGifts: () -> Void
    let transferGift: () -> Void
    let upgradeGift: ((Int64?, Bool) -> Signal<ProfileGiftsContext.State.StarGift, UpgradeStarGiftError>)
    let shareGift: () -> Void
    let viewUpgraded: (EngineMessage.Id) -> Void
    let openMore: (ASDisplayNode, ContextGesture?) -> Void
    let showAttributeInfo: (Any, String) -> Void
    
    init(
        context: AccountContext,
        subject: GiftViewScreen.Subject,
        openPeer: @escaping (EnginePeer) -> Void,
        openAddress: @escaping (String) -> Void,
        copyAddress: @escaping (String) -> Void,
        updateSavedToProfile: @escaping (Bool) -> Void,
        convertToStars: @escaping () -> Void,
        openStarsIntro: @escaping () -> Void,
        sendGift: @escaping (EnginePeer.Id) -> Void,
        openMyGifts: @escaping () -> Void,
        transferGift: @escaping () -> Void,
        upgradeGift: @escaping ((Int64?, Bool) -> Signal<ProfileGiftsContext.State.StarGift, UpgradeStarGiftError>),
        shareGift: @escaping () -> Void,
        viewUpgraded: @escaping (EngineMessage.Id) -> Void,
        openMore: @escaping (ASDisplayNode, ContextGesture?) -> Void,
        showAttributeInfo: @escaping (Any, String) -> Void
    ) {
        self.context = context
        self.subject = subject
        self.openPeer = openPeer
        self.openAddress = openAddress
        self.copyAddress = copyAddress
        self.updateSavedToProfile = updateSavedToProfile
        self.convertToStars = convertToStars
        self.openStarsIntro = openStarsIntro
        self.sendGift = sendGift
        self.openMyGifts = openMyGifts
        self.transferGift = transferGift
        self.upgradeGift = upgradeGift
        self.shareGift = shareGift
        self.viewUpgraded = viewUpgraded
        self.openMore = openMore
        self.showAttributeInfo = showAttributeInfo
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
                        cancel: { animate in
                            if animate {
                                if let controller = controller() as? GiftViewScreen {
                                    controller.dismissAllTooltips()
                                    animateOut.invoke(Action { [weak controller] _ in
                                        controller?.dismiss(completion: nil)
                                    })
                                }
                            } else if let controller = controller() {
                                controller.dismiss(animated: false, completion: nil)
                            }
                        },
                        openPeer: context.component.openPeer,
                        openAddress: context.component.openAddress,
                        copyAddress: context.component.copyAddress,
                        updateSavedToProfile: context.component.updateSavedToProfile,
                        convertToStars: context.component.convertToStars,
                        openStarsIntro: context.component.openStarsIntro,
                        sendGift: context.component.sendGift,
                        openMyGifts: context.component.openMyGifts,
                        transferGift: context.component.transferGift,
                        upgradeGift: context.component.upgradeGift,
                        shareGift: context.component.shareGift,
                        showAttributeInfo: context.component.showAttributeInfo,
                        viewUpgraded: context.component.viewUpgraded,
                        openMore: context.component.openMore,
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
                                    animateOut.invoke(Action { _ in
                                        controller.dismiss(completion: nil)
                                    })
                                }
                            } else {
                                if let controller = controller() as? GiftViewScreen {
                                    controller.dismissAllTooltips()
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
        case uniqueGift(StarGift.UniqueGift)
        case profileGift(EnginePeer.Id, ProfileGiftsContext.State.StarGift)
        case soldOutGift(StarGift.Gift)
        case upgradePreview([StarGift.UniqueGift.Attribute], String)
        case wearPreview(StarGift.UniqueGift)
        
        var arguments: (peerId: EnginePeer.Id?, fromPeerId: EnginePeer.Id?, fromPeerName: String?, messageId: EngineMessage.Id?, reference: StarGiftReference?, incoming: Bool, gift: StarGift, date: Int32, convertStars: Int64?, text: String?, entities: [MessageTextEntity]?, nameHidden: Bool, savedToProfile: Bool, converted: Bool, upgraded: Bool, canUpgrade: Bool, upgradeStars: Int64?, transferStars: Int64?, canExportDate: Int32?, upgradeMessageId: Int32?)? {
            switch self {
            case let .message(message):
                if let action = message.media.first(where: { $0 is TelegramMediaAction }) as? TelegramMediaAction {
                    switch action.action {
                    case let .starGift(gift, convertStars, text, entities, nameHidden, savedToProfile, converted, upgraded, canUpgrade, upgradeStars, _, upgradeMessageId, peerId, senderId, savedId):
                        var reference: StarGiftReference
                        if let peerId, let savedId {
                            reference = .peer(peerId: peerId, id: savedId)
                        } else {
                            reference = .message(messageId: message.id)
                        }
                        return (message.id.peerId, senderId ?? message.author?.id, message.author?.compactDisplayTitle, message.id, reference, message.flags.contains(.Incoming), gift, message.timestamp, convertStars, text, entities, nameHidden, savedToProfile, converted, upgraded, canUpgrade, upgradeStars, nil, nil, upgradeMessageId)
                    case let .starGiftUnique(gift, isUpgrade, isTransferred, savedToProfile, canExportDate, transferStars, _, peerId, senderId, savedId):
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
                        return (message.id.peerId, senderId ?? message.author?.id, message.author?.compactDisplayTitle, message.id, reference, incoming, gift, message.timestamp, nil, nil, nil, false, savedToProfile, false, false, false, nil, transferStars, canExportDate, nil)
                    default:
                        return nil
                    }
                }
            case let .uniqueGift(gift), let .wearPreview(gift):
                return (nil, nil, nil, nil, nil, false, .unique(gift), 0, nil, nil, nil, false, false, false, false, false, nil, nil, nil, nil)
            case let .profileGift(peerId, gift):
                var messageId: EngineMessage.Id?
                if case let .message(messageIdValue) = gift.reference {
                    messageId = messageIdValue
                }
                return (peerId, gift.fromPeer?.id, gift.fromPeer?.compactDisplayTitle, messageId, gift.reference, false, gift.gift, gift.date, gift.convertStars, gift.text, gift.entities, gift.nameHidden, gift.savedToProfile, false, false, gift.canUpgrade, gift.upgradeStars, gift.transferStars, gift.canExportDate, nil)
            case .soldOutGift:
                return nil
            case .upgradePreview:
                return nil
            }
            return nil
        }
    }
    
    private let context: AccountContext
    fileprivate var subject: GiftViewScreen.Subject
    public var disposed: () -> Void = {}
    
    fileprivate var showBalance = false {
        didSet {
            self.requestLayout(transition: .immediate)
        }
    }
    private let balanceOverlay = ComponentView<Empty>()
    
    private let hapticFeedback = HapticFeedback()
    
    public init(
        context: AccountContext,
        subject: GiftViewScreen.Subject,
        forceDark: Bool = false,
        updateSavedToProfile: ((StarGiftReference, Bool) -> Void)? = nil,
        convertToStars: (() -> Void)? = nil,
        transferGift: ((Bool, EnginePeer.Id) -> Void)? = nil,
        upgradeGift: ((Int64?, Bool) -> Signal<ProfileGiftsContext.State.StarGift, UpgradeStarGiftError>)? = nil,
        shareStory: ((StarGift.UniqueGift) -> Void)? = nil
    ) {
        self.context = context
        self.subject = subject
        
        var openPeerImpl: ((EnginePeer) -> Void)?
        var openAddressImpl: ((String) -> Void)?
        var copyAddressImpl: ((String) -> Void)?
        var updateSavedToProfileImpl: ((Bool) -> Void)?
        var convertToStarsImpl: (() -> Void)?
        var openStarsIntroImpl: (() -> Void)?
        var sendGiftImpl: ((EnginePeer.Id) -> Void)?
        var openMyGiftsImpl: (() -> Void)?
        var transferGiftImpl: (() -> Void)?
        var upgradeGiftImpl: ((Int64?, Bool) -> Signal<ProfileGiftsContext.State.StarGift, UpgradeStarGiftError>)?
        var shareGiftImpl: (() -> Void)?
        var openMoreImpl: ((ASDisplayNode, ContextGesture?) -> Void)?
        var showAttributeInfoImpl: ((Any, String) -> Void)?
        var viewUpgradedImpl: ((EngineMessage.Id) -> Void)?
        
        super.init(
            context: context,
            component: GiftViewSheetComponent(
                context: context,
                subject: subject,
                openPeer: { peerId in
                    openPeerImpl?(peerId)
                },
                openAddress: { address in
                    openAddressImpl?(address)
                },
                copyAddress: { address in
                    copyAddressImpl?(address)
                },
                updateSavedToProfile: { added in
                    updateSavedToProfileImpl?(added)
                },
                convertToStars: {
                    convertToStarsImpl?()
                },
                openStarsIntro: {
                    openStarsIntroImpl?()
                },
                sendGift: { peerId in
                    sendGiftImpl?(peerId)
                },
                openMyGifts: {
                    openMyGiftsImpl?()
                },
                transferGift: {
                    transferGiftImpl?()
                },
                upgradeGift: { formId, keepOriginalInfo in
                    return upgradeGiftImpl?(formId, keepOriginalInfo) ?? .complete()
                },
                shareGift: {
                    shareGiftImpl?()
                },
                viewUpgraded: { messageId in
                    viewUpgradedImpl?(messageId)
                },
                openMore: { node, gesture in
                    openMoreImpl?(node, gesture)
                },
                showAttributeInfo: { tag, text in
                    showAttributeInfoImpl?(tag, text)
                }
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: forceDark ? .dark : .default
        )
        
        self.navigationPresentation = .flatModal
        self.automaticallyControlPresentationContextLayout = false
        
        openPeerImpl = { [weak self] peer in
            guard let self, let navigationController = self.navigationController as? NavigationController else {
                return
            }
            self.dismissAllTooltips()
            
            let _ = (context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: peer.id)
            )
            |> deliverOnMainQueue).start(next: { peer in
                guard let peer else {
                    return
                }
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, chatController: nil, context: context, chatLocation: .peer(peer), subject: nil, botStart: nil, updateTextInputState: nil, keepStack: .always, useExisting: true, purposefulAction: nil, scrollToEndIfExists: false, activateMessageSearch: nil, animated: true))
            })
        }
        
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        openAddressImpl = { [weak self] address in
            if let navigationController = self?.navigationController as? NavigationController {
                let configuration = GiftViewConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
                let url = configuration.explorerUrl + address
                Queue.mainQueue().after(0.3) {
                    context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: url, forceExternal: false, presentationData: presentationData, navigationController: navigationController, dismissInput: {})
                }
            }
        }
        copyAddressImpl = { [weak self] address in
            guard let self else {
                return
            }
            UIPasteboard.general.string = address
            
            self.dismissAllTooltips()
            
            self.present(UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.Gift_View_CopiedAddress), elevatedLayout: false, position: .bottom, action: { _ in return true }), in: .current)
            
            HapticFeedback().tap()
        }
        updateSavedToProfileImpl = { [weak self] added in
            guard let self, let arguments = self.subject.arguments, let reference = arguments.reference else {
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
            
            if let updateSavedToProfile {
                updateSavedToProfile(reference, added)
            } else {
                let _ = (context.engine.payments.updateStarGiftAddedToProfile(reference: reference, added: added)
                |> deliverOnMainQueue).startStandalone()
            }
            
            self.dismissAnimated()
            
            let giftsPeerId: EnginePeer.Id?
            let text: String
            if case let .peer(peerId, _) = arguments.reference, peerId.namespace == Namespaces.Peer.CloudChannel {
                giftsPeerId = peerId
                text = added ? presentationData.strings.Gift_Displayed_ChannelText : presentationData.strings.Gift_Hidden_ChannelText
            } else {
                giftsPeerId = context.account.peerId
                text = added ? presentationData.strings.Gift_Displayed_NewText : presentationData.strings.Gift_Hidden_NewText
            }
            
            if let navigationController = self.navigationController as? NavigationController {
                Queue.mainQueue().after(0.5) {
                    if let lastController = navigationController.viewControllers.last as? ViewController, let animationFile {
                        let resultController = UndoOverlayController(
                            presentationData: presentationData,
                            content: .sticker(context: context, file: animationFile, loop: false, title: nil, text: text, undoText: updateSavedToProfile == nil ? presentationData.strings.Gift_Displayed_View : nil, customAction: nil),
                            elevatedLayout: lastController is ChatController,
                            action: { [weak navigationController] action in
                                if case .undo = action, let navigationController, let giftsPeerId {
                                    let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: giftsPeerId))
                                    |> deliverOnMainQueue).start(next: { [weak navigationController] peer in
                                        guard let peer, let navigationController else {
                                            return
                                        }
                                        if let controller = context.sharedContext.makePeerInfoController(
                                            context: context,
                                            updatedPresentationData: nil,
                                            peer: peer._asPeer(),
                                            mode: giftsPeerId == context.account.peerId ? .myProfileGifts : .gifts,
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
        
        convertToStarsImpl = { [weak self] in
            guard let self, let starsContext = context.starsContext, let arguments = self.subject.arguments, let reference = arguments.reference, let fromPeerName = arguments.fromPeerName, let convertStars = arguments.convertStars, let navigationController = self.navigationController as? NavigationController else {
                return
            }
            
            let configuration = GiftConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
            let starsConvertMaxDate = arguments.date + configuration.convertToStarsPeriod
            
            var isChannelGift = false
            if case let .peer(peerId, _) = reference, peerId.namespace == Namespaces.Peer.CloudChannel {
                isChannelGift = true
            }
            
            let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
            if currentTime > starsConvertMaxDate {
                let days: Int32 = Int32(ceil(Float(configuration.convertToStarsPeriod) / 86400.0))
                let controller = textAlertController(
                    context: self.context,
                    title: presentationData.strings.Gift_Convert_Title,
                    text: presentationData.strings.Gift_Convert_Period_Unavailable_Text(presentationData.strings.Gift_Convert_Period_Unavailable_Days(days)).string,
                    actions: [
                        TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
                    ],
                    parseMarkdown: true
                )
                self.present(controller, in: .window(.root))
            } else {
                let delta = starsConvertMaxDate - currentTime
                let days: Int32 = Int32(ceil(Float(delta) / 86400.0))
                
                let text = presentationData.strings.Gift_Convert_Period_Text(fromPeerName, presentationData.strings.Gift_Convert_Period_Stars(Int32(convertStars)), presentationData.strings.Gift_Convert_Period_Days(days)).string
                let controller = textAlertController(
                    context: self.context,
                    title: presentationData.strings.Gift_Convert_Title,
                    text: text,
                    actions: [
                        TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}),
                        TextAlertAction(type: .defaultAction, title: presentationData.strings.Gift_Convert_Convert, action: { [weak self, weak navigationController] in
                            if let convertToStars {
                                convertToStars()
                            } else {
                                let _ = (context.engine.payments.convertStarGift(reference: reference)
                                |> deliverOnMainQueue).startStandalone()
                            }
                            self?.dismissAnimated()
                            
                            if let navigationController {
                                Queue.mainQueue().after(0.5) {
                                    starsContext.load(force: true)
                                    
                                    let text: String
                                    if isChannelGift {
                                        text = presentationData.strings.Gift_Convert_Success_ChannelText(presentationData.strings.Gift_Convert_Success_ChannelText_Stars(Int32(convertStars))).string
                                    } else {
                                        text = presentationData.strings.Gift_Convert_Success_Text(presentationData.strings.Gift_Convert_Success_Text_Stars(Int32(convertStars))).string
                                        if let starsContext = context.starsContext {
                                            navigationController.pushViewController(context.sharedContext.makeStarsTransactionsScreen(context: context, starsContext: starsContext), animated: true)
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
                                            action: { _ in return true}
                                        )
                                        lastController.present(resultController, in: .window(.root))
                                    }
                                }
                            }
                        })
                    ],
                    parseMarkdown: true
                )
                self.present(controller, in: .window(.root))
            }
        }
        
        openStarsIntroImpl = { [weak self] in
            guard let self else {
                return
            }
            let introController = context.sharedContext.makeStarsIntroScreen(context: context)
            self.push(introController)
        }
        
        sendGiftImpl = { [weak self] peerId in
            guard let self else {
                return
            }
            let _ = (context.engine.payments.premiumGiftCodeOptions(peerId: nil, onlyCached: true)
            |> filter { !$0.isEmpty }
            |> deliverOnMainQueue).start(next: { giftOptions in
                let premiumOptions = giftOptions.filter { $0.users == 1 }.map { CachedPremiumGiftOption(months: $0.months, currency: $0.currency, amount: $0.amount, botUrl: "", storeProductId: $0.storeProductId) }
                let controller = context.sharedContext.makeGiftOptionsController(context: context, peerId: peerId, premiumOptions: premiumOptions, hasBirthday: false, completion: nil)
                self.push(controller)
            })
        }
        
        openMyGiftsImpl = { [weak self] in
            guard let self, let navigationController = self.navigationController as? NavigationController else {
                return
            }
            let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
            |> deliverOnMainQueue).start(next: { [weak navigationController] peer in
                guard let peer, let navigationController else {
                    return
                }
                if let controller = context.sharedContext.makePeerInfoController(
                    context: context,
                    updatedPresentationData: nil,
                    peer: peer._asPeer(),
                    mode: .myProfileGifts,
                    avatarInitiallyExpanded: false,
                    fromChat: false,
                    requestsContext: nil
                ) {
                    navigationController.pushViewController(controller, animated: true)
                }
            })
        }
        
        transferGiftImpl = { [weak self] in
            guard let self, let arguments = self.subject.arguments, let navigationController = self.navigationController as? NavigationController, case let .unique(gift) = arguments.gift, let reference = arguments.reference, let transferStars = arguments.transferStars else {
                return
            }
            let _ = (context.account.stateManager.contactBirthdays
            |> take(1)
            |> deliverOnMainQueue).start(next: { birthdays in
                var showSelf = false
                if arguments.peerId?.namespace == Namespaces.Peer.CloudChannel {
                    showSelf = true
                }
                let controller = context.sharedContext.makePremiumGiftController(context: context, source: .starGiftTransfer(birthdays, reference, gift, transferStars, arguments.canExportDate, showSelf), completion: { peerIds in
                    guard let peerId = peerIds.first else {
                        return
                    }
                    if let transferGift {
                        transferGift(transferStars == 0, peerId)
                    } else {
                        let _ = (context.engine.payments.transferStarGift(prepaid: transferStars == 0, reference: reference, peerId: peerId)
                        |> deliverOnMainQueue).start()
                    }
                    Queue.mainQueue().after(1.0, {
                        if transferStars > 0 {
                            context.starsContext?.load(force: true)
                        }
                    })
                })
                navigationController.pushViewController(controller)
            })
        }
        
        upgradeGiftImpl = { [weak self] formId, keepOriginalInfo in
            guard let self, let arguments = self.subject.arguments, let reference = arguments.reference else {
                return .complete()
            }
            if let upgradeGift {
                return upgradeGift(formId, keepOriginalInfo)
            } else {
                return self.context.engine.payments.upgradeStarGift(formId: formId, reference: reference, keepOriginalInfo: keepOriginalInfo)
                |> afterCompleted {
                    if formId != nil {
                        context.starsContext?.load(force: true)
                    }
                }
            }
        }
        
        shareGiftImpl = { [weak self] in
            guard let self, let arguments = self.subject.arguments, case let .unique(gift) = arguments.gift else {
                return
            }
            
            var shareStoryImpl: (() -> Void)?
            if let shareStory {
                shareStoryImpl = {
                    shareStory(gift)
                }
            }
            let link = "https://t.me/nft/\(gift.slug)"
            let shareController = context.sharedContext.makeShareController(
                context: context,
                subject: .url(link),
                forceExternal: false,
                shareStory: shareStoryImpl,
                enqueued: { peerIds, _ in
                    let _ = (context.engine.data.get(
                        EngineDataList(
                            peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                        )
                    )
                    |> deliverOnMainQueue).startStandalone(next: { [weak self] peerList in
                        let peers = peerList.compactMap { $0 }
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
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
                        
                        self?.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: false, animateInAsReplacement: false, action: { action in
                            if savedMessages, action == .info {
                                let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                                |> deliverOnMainQueue).start(next: { peer in
                                    guard let peer else {
                                        return
                                    }
                                    openPeerImpl?(peer)
                                    Queue.mainQueue().after(0.6) {
                                        self?.dismiss(animated: false, completion: nil)
                                    }
                                })
                            }
                            return false
                        }, additionalView: nil), in: .current)
                    })
                },
                actionCompleted: { [weak self] in
                    self?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                }
            )
            self.present(shareController, in: .window(.root))
        }
        
        viewUpgradedImpl = { [weak self] messageId in
            guard let self, let navigationController = self.navigationController as? NavigationController else {
                return
            }
            let _ = (context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: messageId.peerId)
            )
            |> deliverOnMainQueue).start(next: { [weak navigationController] peer in
                guard let peer, let navigationController else {
                    return
                }
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), subject: .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false), keepStack: .always, useExisting: true, purposefulAction: {}, peekData: nil, forceAnimatedScroll: true))
            })
        }
        
        showAttributeInfoImpl = { [weak self] tag, text in
            guard let self else {
                return
            }
            self.dismissAllTooltips()
            
            guard let sourceView = self.node.hostView.findTaggedView(tag: tag), let absoluteLocation = sourceView.superview?.convert(sourceView.center, to: self.view) else {
                return
            }
            
            let location = CGRect(origin: CGPoint(x: absoluteLocation.x, y: absoluteLocation.y - 12.0), size: CGSize())
            let controller = TooltipScreen(account: self.context.account, sharedContext: self.context.sharedContext, text: .plain(text: text), style: .wide, location: .point(location, .bottom), displayDuration: .default, inset: 16.0, shouldDismissOnTouch: { _, _ in
                return .ignore
            })
            self.present(controller, in: .current)
        }
        
        openMoreImpl = { [weak self] node, gesture in
            guard let self, let arguments = self.subject.arguments, case let .unique(gift) = arguments.gift else {
                return
            }
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let link = "https://t.me/nft/\(gift.slug)"
            
            let _ = (context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: arguments.peerId ?? context.account.peerId)
            )
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                guard let self else {
                    return
                }
                var items: [ContextMenuItem] = []
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.Gift_View_Context_CopyLink, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Link"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] c, _ in
                    c?.dismiss(completion: nil)
                    
                    guard let self else {
                        return
                    }
                    
                    UIPasteboard.general.string = link
                    
                    self.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                })))
                
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.Gift_View_Context_Share, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor)
                }, action: { c, _ in
                    c?.dismiss(completion: nil)
                    
                    shareGiftImpl?()
                })))
                
                if let _ = arguments.transferStars {
                    if case let .channel(channel) = peer, !channel.flags.contains(.isCreator) {
                        
                    } else {
                        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Gift_View_Context_Transfer, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Replace"), color: theme.contextMenu.primaryColor)
                        }, action: { c, _ in
                            c?.dismiss(completion: nil)
                            
                            transferGiftImpl?()
                        })))
                    }
                }
                
                let contextController = ContextController(presentationData: presentationData, source: .reference(GiftViewContextReferenceContentSource(controller: self, sourceNode: node)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
                self.presentInGlobalOverlay(contextController)
            })
        }
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

private final class TableComponent: CombinedComponent {
    class Item: Equatable {
        public let id: AnyHashable
        public let title: String?
        public let hasBackground: Bool
        public let component: AnyComponent<Empty>
        public let insets: UIEdgeInsets?

        public init<IdType: Hashable>(id: IdType, title: String?, hasBackground: Bool = false, component: AnyComponent<Empty>, insets: UIEdgeInsets? = nil) {
            self.id = AnyHashable(id)
            self.title = title
            self.hasBackground = hasBackground
            self.component = component
            self.insets = insets
        }

        public static func == (lhs: Item, rhs: Item) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.title != rhs.title {
                return false
            }
            if lhs.hasBackground != rhs.hasBackground {
                return false
            }
            if lhs.component != rhs.component {
                return false
            }
            if lhs.insets != rhs.insets {
                return false
            }
            return true
        }
    }
    
    private let theme: PresentationTheme
    private let items: [Item]

    public init(theme: PresentationTheme, items: [Item]) {
        self.theme = theme
        self.items = items
    }

    public static func ==(lhs: TableComponent, rhs: TableComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var cachedBorderImage: (UIImage, PresentationTheme)?
    }
    
    func makeState() -> State {
        return State()
    }

    public static var body: Body {
        let leftColumnBackground = Child(Rectangle.self)
        let lastBackground = Child(Rectangle.self)
        let verticalBorder = Child(Rectangle.self)
        let titleChildren = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        let valueChildren = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        let borderChildren = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        let outerBorder = Child(Image.self)

        return { context in
            let verticalPadding: CGFloat = 11.0
            let horizontalPadding: CGFloat = 12.0
            let borderWidth: CGFloat = 1.0
            
            let backgroundColor = context.component.theme.actionSheet.opaqueItemBackgroundColor
            let borderColor = backgroundColor.mixedWith(context.component.theme.list.itemBlocksSeparatorColor, alpha: 0.6)
            let secondaryBackgroundColor = context.component.theme.overallDarkAppearance ? context.component.theme.list.itemModalBlocksBackgroundColor : context.component.theme.list.itemInputField.backgroundColor
            
            var leftColumnWidth: CGFloat = 0.0
            
            var updatedTitleChildren: [Int: _UpdatedChildComponent] = [:]
            var updatedValueChildren: [(_UpdatedChildComponent, UIEdgeInsets)] = []
            var updatedBorderChildren: [_UpdatedChildComponent] = []
            
            var i = 0
            for item in context.component.items {
                guard let title = item.title else {
                    i += 1
                    continue
                }
                let titleChild = titleChildren[item.id].update(
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: title, font: Font.regular(15.0), textColor: context.component.theme.list.itemPrimaryTextColor))
                    )),
                    availableSize: context.availableSize,
                    transition: context.transition
                )
                updatedTitleChildren[i] = titleChild
                
                if titleChild.size.width > leftColumnWidth {
                    leftColumnWidth = titleChild.size.width
                }
                i += 1
            }
            
            leftColumnWidth = max(100.0, leftColumnWidth + horizontalPadding * 2.0)
            let rightColumnWidth = context.availableSize.width - leftColumnWidth
            
            i = 0
            var rowHeights: [Int: CGFloat] = [:]
            var totalHeight: CGFloat = 0.0
            var innerTotalHeight: CGFloat = 0.0
            var hasLastBackground = false
            
            for item in context.component.items {
                let insets: UIEdgeInsets
                if let customInsets = item.insets {
                    insets = customInsets
                } else {
                    insets = UIEdgeInsets(top: 0.0, left: horizontalPadding, bottom: 0.0, right: horizontalPadding)
                }
                
                var titleHeight: CGFloat = 0.0
                if let titleChild = updatedTitleChildren[i] {
                    titleHeight = titleChild.size.height
                }
                
                let availableValueWidth: CGFloat
                if titleHeight > 0.0 {
                    availableValueWidth = rightColumnWidth
                } else {
                    availableValueWidth = context.availableSize.width
                }
                
                let valueChild = valueChildren[item.id].update(
                    component: item.component,
                    availableSize: CGSize(width: availableValueWidth - insets.left - insets.right, height: context.availableSize.height),
                    transition: context.transition
                )
                updatedValueChildren.append((valueChild, insets))
               
                let rowHeight = max(40.0, max(titleHeight, valueChild.size.height) + verticalPadding * 2.0)
                rowHeights[i] = rowHeight
                totalHeight += rowHeight
                if titleHeight > 0.0 {
                    innerTotalHeight += rowHeight
                }
                
                if i < context.component.items.count - 1 {
                    let borderChild = borderChildren[item.id].update(
                        component: AnyComponent(Rectangle(color: borderColor)),
                        availableSize: CGSize(width: context.availableSize.width, height: borderWidth),
                        transition: context.transition
                    )
                    updatedBorderChildren.append(borderChild)
                }
                
                if item.hasBackground {
                    hasLastBackground = true
                }
                
                i += 1
            }
            
            if hasLastBackground {
                let lastRowHeight = rowHeights[i - 1] ?? 0
                let lastBackground = lastBackground.update(
                    component: Rectangle(color: secondaryBackgroundColor),
                    availableSize: CGSize(width: context.availableSize.width, height: lastRowHeight),
                    transition: context.transition
                )
                context.add(
                    lastBackground
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: totalHeight - lastRowHeight / 2.0))
                )
            }
            
            let leftColumnBackground = leftColumnBackground.update(
                component: Rectangle(color: secondaryBackgroundColor),
                availableSize: CGSize(width: leftColumnWidth, height: innerTotalHeight),
                transition: context.transition
            )
            context.add(
                leftColumnBackground
                    .position(CGPoint(x: leftColumnWidth / 2.0, y: innerTotalHeight / 2.0))
            )
            
            let borderImage: UIImage
            if let (currentImage, theme) = context.state.cachedBorderImage, theme === context.component.theme {
                borderImage = currentImage
            } else {
                let borderRadius: CGFloat = 10.0
                borderImage = generateImage(CGSize(width: 24.0, height: 24.0), rotatedContext: { size, context in
                    let bounds = CGRect(origin: .zero, size: size)
                    context.setFillColor(backgroundColor.cgColor)
                    context.fill(bounds)
                    
                    let path = CGPath(roundedRect: bounds.insetBy(dx: borderWidth / 2.0, dy: borderWidth / 2.0), cornerWidth: borderRadius, cornerHeight: borderRadius, transform: nil)
                    context.setBlendMode(.clear)
                    context.addPath(path)
                    context.fillPath()
                    
                    context.setBlendMode(.normal)
                    context.setStrokeColor(borderColor.cgColor)
                    context.setLineWidth(borderWidth)
                    context.addPath(path)
                    context.strokePath()
                })!.stretchableImage(withLeftCapWidth: 10, topCapHeight: 10)
                context.state.cachedBorderImage = (borderImage, context.component.theme)
            }
            
            let outerBorder = outerBorder.update(
                component: Image(image: borderImage),
                availableSize: CGSize(width: context.availableSize.width, height: totalHeight),
                transition: context.transition
            )
            context.add(outerBorder
                .position(CGPoint(x: context.availableSize.width / 2.0, y: totalHeight / 2.0))
            )
            
            let verticalBorder = verticalBorder.update(
                component: Rectangle(color: borderColor),
                availableSize: CGSize(width: borderWidth, height: innerTotalHeight),
                transition: context.transition
            )
            context.add(
                verticalBorder
                    .position(CGPoint(x: leftColumnWidth - borderWidth / 2.0, y: innerTotalHeight / 2.0))
            )
            
            i = 0
            var originY: CGFloat = 0.0
            for (valueChild, valueInsets) in updatedValueChildren {
                let rowHeight = rowHeights[i] ?? 0.0
                
                let valueFrame: CGRect
                if let titleChild = updatedTitleChildren[i] {
                    let titleFrame = CGRect(origin: CGPoint(x: horizontalPadding, y: originY + verticalPadding), size: titleChild.size)
                    context.add(titleChild
                        .position(titleFrame.center)
                    )
                    valueFrame = CGRect(origin: CGPoint(x: leftColumnWidth + valueInsets.left, y: originY + verticalPadding), size: valueChild.size)
                } else {
                    if hasLastBackground {
                        valueFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((context.availableSize.width - valueChild.size.width) / 2.0), y: originY + verticalPadding), size: valueChild.size)
                    } else {
                        valueFrame = CGRect(origin: CGPoint(x: horizontalPadding, y: originY + verticalPadding), size: valueChild.size)
                    }
                }
                
                context.add(valueChild
                    .position(valueFrame.center)
                )
                
                if i < updatedBorderChildren.count {
                    let borderChild = updatedBorderChildren[i]
                    context.add(borderChild
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + rowHeight - borderWidth / 2.0))
                    )
                }
                
                originY += rowHeight
                i += 1
            }
            
            return CGSize(width: context.availableSize.width, height: totalHeight)
        }
    }
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
