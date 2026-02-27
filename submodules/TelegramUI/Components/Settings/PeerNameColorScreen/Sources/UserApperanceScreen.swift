import Foundation
import UIKit
import Photos
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import UndoUI
import EntityKeyboard
import PremiumUI
import ComponentFlow
import BundleIconComponent
import AnimatedTextComponent
import ViewControllerComponent
import ButtonComponent
import ListItemComponentAdaptor
import ListSectionComponent
import MultilineTextComponent
import ListActionItemComponent
import EmojiStatusSelectionComponent
import EmojiStatusComponent
import DynamicCornerRadiusView
import ComponentDisplayAdapters
import BundleIconComponent
import Markdown
import PeerNameColorItem
import EmojiActionIconComponent
import TabSelectorComponent
import WallpaperResources
import EdgeEffect
import TextFormat
import TelegramStringFormatting
import GiftViewScreen
import BalanceNeededScreen

private let giftListTag = GenericComponentViewTag()
private let addIconsTag = GenericComponentViewTag()
private let useGiftTag = GenericComponentViewTag()

public enum UserAppearanceEntryTag {
    case profile
    case profileAddIcons
    case profileUseGift
    case name
    case nameAddIcons
    case nameUseGift
}

final class UserAppearanceScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    public final class TransitionHint {
        public let animateTabChange: Bool
        public let forceGiftsUpdate: Bool
        
        public init(animateTabChange: Bool = false, forceGiftsUpdate: Bool = false) {
            self.animateTabChange = animateTabChange
            self.forceGiftsUpdate = forceGiftsUpdate
        }
    }
    
    let context: AccountContext
    let overNavigationContainer: UIView

    init(
        context: AccountContext,
        overNavigationContainer: UIView
    ) {
        self.context = context
        self.overNavigationContainer = overNavigationContainer
    }

    static func ==(lhs: UserAppearanceScreenComponent, rhs: UserAppearanceScreenComponent) -> Bool {
        return true
    }
    
    private final class ContentsData {
        let peer: EnginePeer?
        let gifts: [StarGift.UniqueGift]
        let starGifts: [StarGift]
        
        init(
            peer: EnginePeer?,
            gifts: [StarGift.UniqueGift],
            starGifts: [StarGift]
        ) {
            self.peer = peer
            self.gifts = gifts
            self.starGifts = starGifts
        }
        
        static func get(context: AccountContext) -> Signal<ContentsData, NoError> {
            return combineLatest(
                context.engine.data.subscribe(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)
                ),
                context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudUniqueStarGifts], namespaces: [Namespaces.ItemCollection.CloudDice], aroundIndex: nil, count: 10000000),
                context.engine.payments.cachedStarGifts()
            )
            |> map { peer, view, starGifts -> ContentsData in
                var gifts: [StarGift.UniqueGift] = []
                for orderedView in view.orderedItemListsViews {
                    if orderedView.collectionId == Namespaces.OrderedItemList.CloudUniqueStarGifts {
                        for item in orderedView.items {
                            guard let item = item.contents.get(RecentStarGiftItem.self) else {
                                continue
                            }
                            gifts.append(item.starGift)
                        }
                    }
                }
                return ContentsData(
                    peer: peer,
                    gifts: gifts,
                    starGifts: starGifts ?? []
                )
            }
        }
    }
    
    private final class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    private struct ResolvedState {
        struct Changes: OptionSet {
            var rawValue: Int32
            
            init(rawValue: Int32) {
                self.rawValue = rawValue
            }
            
            static let nameColor = Changes(rawValue: 1 << 0)
            static let profileColor = Changes(rawValue: 1 << 1)
            static let replyFileId = Changes(rawValue: 1 << 2)
            static let backgroundFileId = Changes(rawValue: 1 << 3)
            static let emojiStatus = Changes(rawValue: 1 << 4)
        }
        
        var nameColor: PeerColor
        var profileColor: PeerNameColor?
        var replyFileId: Int64?
        var backgroundFileId: Int64?
        var emojiStatus: PeerEmojiStatus?
        
        var changes: Changes
        
        init(
            nameColor: PeerColor,
            profileColor: PeerNameColor?,
            replyFileId: Int64?,
            backgroundFileId: Int64?,
            emojiStatus: PeerEmojiStatus?,
            changes: Changes
        ) {
            self.nameColor = nameColor
            self.profileColor = profileColor
            self.replyFileId = replyFileId
            self.backgroundFileId = backgroundFileId
            self.emojiStatus = emojiStatus
            self.changes = changes
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let containerView = UIView()
        private let topOverscrollLayer = SimpleLayer()
        private let scrollView: ScrollView
        private let actionButton = ComponentView<Empty>()
        private let edgeEffectView: EdgeEffectView
        
        private let tabSelector = ComponentView<Empty>()
        enum Section: Int32 {
            case profile
            case name
        }
        private var currentSection: Section = .profile
                
        private let previewShadowView = UIImageView(image: generatePreviewShadowImage())
        
        private let profilePreview = ComponentView<Empty>()
        private let profileColorSection = ComponentView<Empty>()
        private let profileResetColorSection = ComponentView<Empty>()
        private let profileGiftsSection = ComponentView<Empty>()
        
        private let namePreview = ComponentView<Empty>()
        private let nameColorSection = ComponentView<Empty>()
        private let nameGiftsSection = ComponentView<Empty>()
        
        private var isUpdating: Bool = false
        
        private var component: UserAppearanceScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        let isReady = ValuePromise<Bool>(false, ignoreRepeated: true)
        private var contentsData: ContentsData?
        private var contentsDataDisposable: Disposable?
        
        private var starGiftsContext: ProfileGiftsContext?
        private var starGiftsDisposable: Disposable?
        private var starGifts: [StarGift.UniqueGift] = []
        
        private var cachedIconFiles: [Int64: TelegramMediaFile] = [:]
        
        private var selectedNameGift: StarGift.UniqueGift?
        private var updatedPeerNameColor: PeerColor?
        private var updatedPeerNameEmoji: Int64??
        
        private var selectedProfileGift: StarGift.UniqueGift?
        private var updatedPeerProfileColor: PeerNameColor??
        private var updatedPeerProfileEmoji: Int64??
        private var updatedPeerStatus: PeerEmojiStatus??
        
        private var currentTheme: PresentationThemeReference?
        private var resolvedCurrentTheme: (reference: PresentationThemeReference, isDark: Bool, theme: PresentationTheme, wallpaper: TelegramWallpaper?)?
        private var resolvingCurrentTheme: (reference: PresentationThemeReference, isDark: Bool, disposable: Disposable)?
                
        private var isApplyingSettings: Bool = false
        private var applyDisposable: Disposable?
        
        private var buyDisposable: Disposable?
        
        private var starsTopUpOptionsDisposable: Disposable?
        private(set) var starsTopUpOptions: [StarsTopUpOption] = [] {
            didSet {
                self.starsTopUpOptionsPromise.set(self.starsTopUpOptions)
            }
        }
        private let starsTopUpOptionsPromise = ValuePromise<[StarsTopUpOption]?>(nil)
        
        private weak var emojiStatusSelectionController: ViewController?
        
        private var cachedChevronImage: (UIImage, PresentationTheme)?
        private var cachedStarImage: (UIImage, PresentationTheme)?
        private var cachedSubtitleStarImage: (UIImage, PresentationTheme)?
        private var cachedTonImage: (UIImage, PresentationTheme)?
        
        override init(frame: CGRect) {
            self.scrollView = ScrollView()
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.alwaysBounceVertical = true
            
            self.edgeEffectView = EdgeEffectView()
            self.edgeEffectView.isUserInteractionEnabled = false
            
            super.init(frame: frame)
            
            self.addSubview(self.containerView)
            
            self.scrollView.delegate = self
            self.containerView.addSubview(self.scrollView)
            
            self.scrollView.layer.addSublayer(self.topOverscrollLayer)
            
            self.containerView.addSubview(self.previewShadowView)
            
            self.addSubview(self.edgeEffectView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.contentsDataDisposable?.dispose()
            self.starGiftsDisposable?.dispose()
            self.applyDisposable?.dispose()
            self.buyDisposable?.dispose()
            self.starsTopUpOptionsDisposable?.dispose()
            self.resolvingCurrentTheme?.disposable.dispose()
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }
        
        func attemptNavigation(complete: @escaping () -> Void) -> Bool {
            guard let component = self.component, let resolvedState = self.resolveState() else {
                return true
            }
            if self.isApplyingSettings {
                return false
            }
            
            if !resolvedState.changes.isEmpty {
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                
                let alertController = textAlertController(
                    context: component.context,
                    title: presentationData.strings.Channel_Appearance_UnsavedChangesAlertTitle,
                    text: presentationData.strings.Channel_Appearance_UnsavedChangesAlertText,
                    actions: [
                        TextAlertAction(type: .genericAction, title: presentationData.strings.Channel_Appearance_UnsavedChangesAlertDiscard, action: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.environment?.controller()?.dismiss()
                        }),
                        TextAlertAction(type: .defaultAction, title: presentationData.strings.Channel_Appearance_UnsavedChangesAlertApply, action: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.applySettings()
                        })
                    ]
                )
                self.environment?.controller()?.present(alertController, in: .window(.root))

                return false
            }
            
            return true
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            self.updateScrolling(transition: .immediate)
        }
        
        var scrolledUp = true
        private func updateScrolling(transition: ComponentTransition) {
            let navigationAlphaDistance: CGFloat = 16.0
            let navigationAlpha: CGFloat = max(0.0, min(1.0, self.scrollView.contentOffset.y / navigationAlphaDistance))
            if let controller = self.environment?.controller(), let navigationBar = controller.navigationBar {
                navigationBar.backgroundNode.alpha = 0.0
                navigationBar.stripeNode.alpha = 0.0
            }
            
            var scrolledUp = false
            if navigationAlpha < 0.5 {
                scrolledUp = true
            } else if navigationAlpha > 0.5 {
                scrolledUp = false
            }
            
            if self.scrolledUp != scrolledUp {
                self.scrolledUp = scrolledUp
                if !self.isUpdating {
                    self.state?.updated(transition: .easeInOut(duration: 0.3))
                }
            }
                        
            switch self.currentSection {
            case .profile:
                if let giftListView = self.profileGiftsSection.findTaggedView(tag: giftListTag) as? GiftListItemComponent.View {
                    let rect = self.scrollView.convert(self.scrollView.bounds, to: giftListView)
                    let visibleRect = giftListView.bounds.intersection(rect)
                    if !self.isUpdating {
                        giftListView.updateVisibleBounds(visibleRect)
                    } else if giftListView.visibleBounds == nil {
                        Queue.mainQueue().justDispatch {
                            giftListView.updateVisibleBounds(visibleRect)
                        }
                    }
                }
            case .name:
                if let giftListView = self.nameGiftsSection.findTaggedView(tag: giftListTag) as? GiftListItemComponent.View {
                    let rect = self.scrollView.convert(self.scrollView.bounds, to: giftListView)
                    let visibleRect = giftListView.bounds.intersection(rect)
                    if !self.isUpdating {
                        giftListView.updateVisibleBounds(visibleRect)
                    } else if giftListView.visibleBounds == nil {
                        Queue.mainQueue().justDispatch {
                            giftListView.updateVisibleBounds(visibleRect)
                        }
                    }
                    
                    let bottomContentOffset = max(0.0, self.scrollView.contentSize.height - self.scrollView.contentOffset.y - self.scrollView.frame.height)
                    if bottomContentOffset < 320.0 {
                        if !giftListView.loadMore() {
                            self.starGiftsContext?.loadMore()
                        }
                    }
                }
            }
        }
        
        private func resolveState() -> ResolvedState? {
            guard let contentsData = self.contentsData, let peer = contentsData.peer else {
                return nil
            }
            
            var changes: ResolvedState.Changes = []
            
            let nameColor: PeerColor
            if let updatedPeerNameColor = self.updatedPeerNameColor {
                nameColor = updatedPeerNameColor
            } else if let peerNameColor = peer.nameColor {
                nameColor = peerNameColor
            } else {
                nameColor = .preset(.blue)
            }
            if nameColor != peer.nameColor {
                changes.insert(.nameColor)
            }
            
            let profileColor: PeerNameColor?
            if case let .some(value) = self.updatedPeerProfileColor {
                profileColor = value
            } else if let peerProfileColor = peer.profileColor {
                profileColor = peerProfileColor
            } else {
                profileColor = nil
            }
            if profileColor != peer.profileColor {
                changes.insert(.profileColor)
            }
            
            let replyFileId: Int64?
            if case let .some(value) = self.updatedPeerNameEmoji {
                replyFileId = value
            } else {
                replyFileId = peer.backgroundEmojiId
            }
            if replyFileId != peer.backgroundEmojiId {
                changes.insert(.replyFileId)
            }
            
            let backgroundFileId: Int64?
            if case let .some(value) = self.updatedPeerProfileEmoji {
                backgroundFileId = value
            } else {
                backgroundFileId = peer.profileBackgroundEmojiId
            }
            if backgroundFileId != peer.profileBackgroundEmojiId {
                changes.insert(.backgroundFileId)
            }
            
            let emojiStatus: PeerEmojiStatus?
            if case let .some(value) = self.updatedPeerStatus {
                emojiStatus = value
            } else {
                emojiStatus = peer.emojiStatus
            }
            if emojiStatus != peer.emojiStatus {
                changes.insert(.emojiStatus)
            }
                        
            return ResolvedState(
                nameColor: nameColor,
                profileColor: profileColor,
                replyFileId: replyFileId,
                backgroundFileId: backgroundFileId,
                emojiStatus: emojiStatus,
                changes: changes
            )
        }
        
        private func commitBuy(acceptedPrice: CurrencyAmount? = nil, skipConfirmation: Bool = false) {
            guard let component = self.component, let environment = self.environment, let controller = environment.controller() else {
                return
            }
            
            var uniqueGift: StarGift.UniqueGift?
            if let gift = self.selectedProfileGift {
                uniqueGift = gift
            } else if let gift = self.selectedNameGift {
                uniqueGift = gift
            }
            
            guard let uniqueGift else {
                return
            }
            
            if self.starsTopUpOptionsDisposable == nil {
                self.starsTopUpOptionsDisposable = (component.context.engine.payments.starsTopUpOptions()
                |> deliverOnMainQueue).start(next: { [weak self] options in
                    guard let self else {
                        return
                    }
                    self.starsTopUpOptions = options
                })
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let action: (CurrencyAmount.Currency) -> Void = { [weak self, weak controller] currency in
                guard let self, let resellAmount = uniqueGift.resellAmounts?.first(where: { $0.currency == currency }) else {
                    guard let controller else {
                        return
                    }
                    let alertController = textAlertController(context: component.context, title: nil, text: presentationData.strings.Gift_Buy_ErrorUnknown, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})], parseMarkdown: true)
                    controller.present(alertController, in: .window(.root))
                    return
                }
                
                let proceed: () -> Void = {
                    self.isApplyingSettings = true
                    self.state?.updated()
                    
                    let finalPrice = acceptedPrice ?? resellAmount
                    let signal = component.context.engine.payments.buyStarGift(slug: uniqueGift.slug, peerId: component.context.account.peerId, price: finalPrice)
                    self.buyDisposable = (signal
                    |> deliverOnMainQueue).start(error: { [weak self, weak controller] error in
                        guard let self, let controller else {
                            return
                        }
                        
                        self.isApplyingSettings = false
                        self.state?.updated()
                        
                        HapticFeedback().error()
                        
                        switch error {
                        case .serverProvided:
                            return
                        case let .priceChanged(newPrice):
                            let errorTitle = presentationData.strings.Gift_Buy_ErrorPriceChanged_Title
                            let originalPriceString: String
                            switch resellAmount.currency {
                            case .stars:
                                originalPriceString = presentationData.strings.Gift_Buy_ErrorPriceChanged_Text_Stars(Int32(clamping: resellAmount.amount.value))
                            case .ton:
                                originalPriceString = formatTonAmountText(resellAmount.amount.value, dateTimeFormat: presentationData.dateTimeFormat, maxDecimalPositions: nil) + " TON"
                            }
                            
                            let newPriceString: String
                            let buttonText: String
                            switch newPrice.currency {
                            case .stars:
                                newPriceString = presentationData.strings.Gift_Buy_ErrorPriceChanged_Text_Stars(Int32(clamping: newPrice.amount.value))
                                buttonText = presentationData.strings.Gift_Buy_Confirm_BuyFor(Int32(newPrice.amount.value))
                            case .ton:
                                let tonValueString = formatTonAmountText(newPrice.amount.value, dateTimeFormat: presentationData.dateTimeFormat, maxDecimalPositions: nil)
                                newPriceString = tonValueString + " TON"
                                buttonText = presentationData.strings.Gift_Buy_Confirm_BuyForTon(tonValueString).string
                            }
                            let errorText = presentationData.strings.Gift_Buy_ErrorPriceChanged_Text(originalPriceString, newPriceString).string
                            
                            let alertController = textAlertController(
                                context: component.context,
                                title: errorTitle,
                                text: errorText,
                                actions: [
                                    TextAlertAction(type: .defaultAction, title: buttonText, action: { [weak self] in
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
                        default:
                            let alertController = textAlertController(context: component.context, title: nil, text: presentationData.strings.Gift_Buy_ErrorUnknown, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})], parseMarkdown: true)
                            controller.present(alertController, in: .window(.root))
                        }
                    }, completed: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.selectedNameGift = nil
                        self.selectedProfileGift = nil
                        
                        self.isApplyingSettings = false
                        self.applySettings()
                        
                        Queue.mainQueue().after(2.5) {
                            switch finalPrice.currency {
                            case .stars:
                                component.context.starsContext?.load(force: true)
                            case .ton:
                                component.context.tonContext?.load(force: true)
                            }
                        }
                    })
                }
                
                if resellAmount.currency == .stars, let starsContext = component.context.starsContext, let starsState = starsContext.currentState, starsState.balance < resellAmount.amount {
                    if self.starsTopUpOptions.isEmpty {
                        self.isApplyingSettings = true
                        self.state?.updated()
                    }
                    let _ = (self.starsTopUpOptionsPromise.get()
                    |> filter { $0 != nil }
                    |> take(1)
                    |> deliverOnMainQueue).startStandalone(next: { [weak self, weak controller] options in
                        guard let self, let controller else {
                            return
                        }
                        let purchaseController = component.context.sharedContext.makeStarsPurchaseScreen(
                            context: component.context,
                            starsContext: starsContext,
                            options: options ?? [],
                            purpose: .buyStarGift(requiredStars: resellAmount.amount.value),
                            targetPeerId: nil,
                            customTheme: nil,
                            completion: { [weak self, weak starsContext] stars in
                                guard let self, let starsContext else {
                                    return
                                }
                                self.isApplyingSettings = true
                                self.state?.updated()
                                
                                starsContext.add(balance: StarsAmount(value: stars, nanos: 0))
                                let _ = (starsContext.onUpdate
                                |> deliverOnMainQueue).start(next: { [weak self, weak starsContext] in
                                    guard let self else {
                                        return
                                    }
                                    Queue.mainQueue().after(0.1, { [weak self] in
                                        guard let self, let starsContext, let starsState = starsContext.currentState else {
                                            return
                                        }
                                        if starsState.balance < resellAmount.amount {
                                            self.isApplyingSettings = false
                                            self.state?.updated()
                                            
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
                } else if resellAmount.currency == .ton, let tonState = component.context.tonContext?.currentState, tonState.balance < resellAmount.amount {
                    guard let controller else {
                        return
                    }
                    let needed = resellAmount.amount - tonState.balance
                    var fragmentUrl = "https://fragment.com/ads/topup"
                    if let data = component.context.currentAppConfiguration.with({ $0 }).data, let value = data["ton_topup_url"] as? String {
                        fragmentUrl = value
                    }
                    controller.push(BalanceNeededScreen(
                        context: component.context,
                        amount: needed,
                        buttonAction: {
                            component.context.sharedContext.applicationBindings.openUrl(fragmentUrl)
                        }
                    ))
                } else {
                    proceed()
                }
            }
            
            if skipConfirmation {
                action(acceptedPrice?.currency ?? .stars)
            } else {
                let _ = (component.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: component.context.account.peerId))
                |> deliverOnMainQueue).start(next: { [weak controller] peer in
                    guard let controller, let peer else {
                        return
                    }
                    let alertController = giftPurchaseAlertController(
                        context: component.context,
                        gift: uniqueGift,
                        showAttributes: true,
                        peer: peer,
                        animateBalanceOverlay: true,
                        navigationController: controller.navigationController as? NavigationController,
                        commit: { currency in
                            action(currency)
                        },
                        dismissed: {
                        }
                    )
                    controller.present(alertController, in: .window(.root))
                })
            }
        }
        
        private func applySettings() {
            guard let component = self.component, let environment = self.environment, let resolvedState = self.resolveState() else {
                return
            }
            if self.isApplyingSettings {
                return
            }
            if resolvedState.changes.isEmpty {
                self.environment?.controller()?.dismiss()
                return
            } else if !component.context.isPremium {
                HapticFeedback().impact(.light)
                
                let toastController = UndoOverlayController(
                    presentationData: component.context.sharedContext.currentPresentationData.with { $0 },
                    content: .premiumPaywall(
                        title: nil,
                        text: environment.strings.NameColor_TooltipPremium_Account,
                        customUndoText: nil,
                        timeout: nil,
                        linkAction: nil
                    ),
                    elevatedLayout: false,
                    action: { [weak environment] action in
                        if case .info = action {
                            var replaceImpl: ((ViewController) -> Void)?
                            let controller = component.context.sharedContext.makePremiumDemoController(context: component.context, subject: .colors, forceDark: false, action: {
                                let controller = component.context.sharedContext.makePremiumIntroController(context: component.context, source: .nameColor, forceDark: false, dismissed: nil)
                                replaceImpl?(controller)
                            }, dismissed: nil)
                            replaceImpl = { [weak controller] c in
                                controller?.replace(with: c)
                            }
                            environment?.controller()?.push(controller)
                        }
                        return true
                    }
                )
                environment.controller()?.present(toastController, in: .current)
                return
            }
            
            if self.selectedProfileGift != nil || self.selectedNameGift != nil {
                self.commitBuy()
                return
            }
            
            self.isApplyingSettings = true
            self.state?.updated(transition: .immediate)
            
            self.applyDisposable?.dispose()
                        
            enum ApplyError {
                case generic
            }
            
            var signals: [Signal<Never, ApplyError>] = []
            if !resolvedState.changes.intersection([.nameColor, .replyFileId, .profileColor, .backgroundFileId]).isEmpty {
                let nameColor: UpdateNameColor
                switch resolvedState.nameColor {
                case let .preset(peerNameColor):
                    nameColor = .preset(color: peerNameColor, backgroundEmojiId: resolvedState.replyFileId)
                case let .collectible(peerCollectibleColor):
                    nameColor = .collectible(peerCollectibleColor)
                }
                signals.append(component.context.engine.accountData.updateNameColorAndEmoji(nameColor: nameColor, profileColor: resolvedState.profileColor, profileBackgroundEmojiId: resolvedState.backgroundFileId)
                |> ignoreValues
                |> mapError { _ -> ApplyError in
                    return .generic
                })
            }
            if resolvedState.changes.contains(.emojiStatus) {
                let signal: Signal<Never, NoError>
                if let emojiStatus = resolvedState.emojiStatus {
                    switch emojiStatus.content {
                    case let .emoji(fileId):
                        if let file = self.cachedIconFiles[fileId] {
                            signal = component.context.engine.accountData.setEmojiStatus(file: file, expirationDate: emojiStatus.expirationDate)
                        } else {
                            signal = .complete()
                        }
                    case let .starGift(id, fileId, title, slug, patternFileId, innerColor, outerColor, patternColor, textColor):
                        let slugComponents = slug.components(separatedBy: "-")
                        if let file = self.cachedIconFiles[fileId], let patternFile = self.cachedIconFiles[patternFileId], let numberString = slugComponents.last, let number = Int32(numberString) {
                            let gift = StarGift.UniqueGift(
                                id: id,
                                giftId: 0,
                                title: title,
                                number: number,
                                slug: slug,
                                owner: .peerId(component.context.account.peerId),
                                attributes: [
                                    .model(name: "", file: file, rarity: .rare, crafted: false),
                                    .pattern(name: "", file: patternFile, rarity: .rare),
                                    .backdrop(name: "", id: 0, innerColor: innerColor, outerColor: outerColor, patternColor: patternColor, textColor: textColor, rarity: .rare)
                                ],
                                availability: StarGift.UniqueGift.Availability(issued: 0, total: 0),
                                giftAddress: nil,
                                resellAmounts: nil,
                                resellForTonOnly: false,
                                releasedBy: nil,
                                valueAmount: nil,
                                valueCurrency: nil,
                                valueUsdAmount: nil,
                                flags: [],
                                themePeerId: nil,
                                peerColor: nil,
                                hostPeerId: nil,
                                minOfferStars: nil,
                                craftChancePermille: nil
                            )
                            signal = component.context.engine.accountData.setStarGiftStatus(starGift: gift, expirationDate: emojiStatus.expirationDate)
                        } else {
                            signal = .complete()
                        }
                    }
                } else {
                    signal = component.context.engine.accountData.setEmojiStatus(file: nil, expirationDate: nil)
                }
                signals.append(signal
                |> castError(ApplyError.self))
            }
            
            self.applyDisposable = (combineLatest(signals)
            |> deliverOnMainQueue).start(error: { [weak self] _ in
                guard let self, let component = self.component else {
                    return
                }
                
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                
                let alertController = textAlertController(
                    context: component.context,
                    title: nil,
                    text: presentationData.strings.Login_UnknownError,
                    actions: [
                        TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
                    ]
                )
                self.environment?.controller()?.present(alertController, in: .window(.root))
                
                self.isApplyingSettings = false
                self.state?.updated(transition: .immediate)
            }, completed: { [weak self] in
                guard let self else {
                    return
                }
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                let navigationController: NavigationController? = self.environment?.controller()?.navigationController as? NavigationController
                
                self.environment?.controller()?.dismiss()
                
                if let lastController = navigationController?.viewControllers.last as? ViewController {
                    let tipController = UndoOverlayController(presentationData: presentationData, content: .actionSucceeded(title: nil, text: presentationData.strings.ProfileColorSetup_ToastAccountColorUpdated, cancel: nil, destructive: false), elevatedLayout: false, position: .bottom, animateInAsReplacement: false, action: { _ in return false })
                    lastController.present(tipController, in: .window(.root))
                }
            })
        }
                        
        private enum EmojiSetupSubject {
            case reply
            case profile
            case status
        }
                
        private var previousEmojiSetupTimestamp: Double?
        private func openEmojiSetup(sourceView: UIView, currentFileId: Int64?, color: UIColor?, subject: EmojiSetupSubject) {
            guard let component = self.component, let environment = self.environment else {
                return
            }
                        
            let currentTimestamp = CACurrentMediaTime()
            if let previousTimestamp = self.previousEmojiSetupTimestamp, currentTimestamp < previousTimestamp + 1.0 {
                return
            }
            self.previousEmojiSetupTimestamp = currentTimestamp
            
            self.emojiStatusSelectionController?.dismiss()
            var selectedItems = Set<MediaId>()
            if let currentFileId {
                selectedItems.insert(MediaId(namespace: Namespaces.Media.CloudFile, id: currentFileId))
            }
            
            let mappedSubject: EmojiPagerContentComponent.Subject
            switch subject {
            case .reply, .profile:
                mappedSubject = .backgroundIcon
            case .status:
                mappedSubject = .channelStatus
            }
            
            let mappedMode: EmojiStatusSelectionController.Mode
            switch subject {
            case .status:
                mappedMode = .customStatusSelection(completion: { [weak self] result, timestamp in
                    guard let self else {
                        return
                    }
                    if let result {
                        self.cachedIconFiles[result.fileId.id] = result
                    }
           
                    if let result {
                        self.updatedPeerStatus = PeerEmojiStatus(content: .emoji(fileId: result.fileId.id), expirationDate: timestamp)
                    } else {
                        self.updatedPeerStatus = .some(nil)
                    }
                    self.state?.updated(transition: .spring(duration: 0.4))
                })
            default:
                mappedMode = .backgroundSelection(completion: { [weak self] result in
                    guard let self, let resolvedState = self.resolveState() else {
                        return
                    }
                    if let result {
                        self.cachedIconFiles[result.fileId.id] = result
                    }
                    switch subject {
                    case .reply:
                        if case .collectible = resolvedState.nameColor {
                            self.updatedPeerNameColor = .preset(.blue)
                        }
                        self.selectedNameGift = nil
                        if let result {
                            self.updatedPeerNameEmoji = result.fileId.id
                        } else {
                            self.updatedPeerNameEmoji = .some(nil)
                        }
                    case .profile:
                        if let result {
                            self.updatedPeerProfileEmoji = result.fileId.id
                            if case .starGift = resolvedState.emojiStatus?.content {
                                self.updatedPeerStatus = .some(nil)
                            }
                        } else {
                            self.updatedPeerProfileEmoji = .some(nil)
                            if case .starGift = resolvedState.emojiStatus?.content {
                                self.updatedPeerStatus = .some(nil)
                            }
                        }
                    default:
                        break
                    }
                    self.state?.updated(transition: .spring(duration: 0.4))
                })
            }
            
            let controller = EmojiStatusSelectionController(
                context: component.context,
                mode: mappedMode,
                sourceView: sourceView,
                emojiContent: EmojiPagerContentComponent.emojiInputData(
                    context: component.context,
                    animationCache: component.context.animationCache,
                    animationRenderer: component.context.animationRenderer,
                    isStandalone: false,
                    subject: mappedSubject,
                    hasTrending: false,
                    topReactionItems: [],
                    areUnicodeEmojiEnabled: false,
                    areCustomEmojiEnabled: true,
                    chatPeerId: component.context.account.peerId,
                    selectedItems: selectedItems,
                    topStatusTitle: nil,
                    backgroundIconColor: color
                ),
                currentSelection: currentFileId,
                color: color,
                destinationItemView: { [weak sourceView] in
                    guard let sourceView else {
                        return nil
                    }
                    return sourceView
                }
            )
            self.emojiStatusSelectionController = controller
            environment.controller()?.present(controller, in: .window(.root))
        }
        
        private var isGroup: Bool {
            guard let contentsData = self.contentsData, let peer = contentsData.peer else {
                return false
            }
            if case let .channel(channel) = peer, case .group = channel.info {
                return true
            }
            return false
        }
        
        func openEmojiSetup() {
            guard let component = self.component, let environment = self.environment, let resolvedState = self.resolveState() else {
                return
            }
            
            switch self.currentSection {
            case .profile:
                if let view = self.profileColorSection.findTaggedView(tag: addIconsTag) as? ListActionItemComponent.View, let iconView = view.iconView {
                    self.openEmojiSetup(sourceView: iconView, currentFileId: resolvedState.backgroundFileId, color: resolvedState.profileColor.flatMap {
                        component.context.peerNameColors.getProfile($0, dark: environment.theme.overallDarkAppearance, subject: .palette).main
                    } ?? environment.theme.list.itemAccentColor, subject: .profile)
                }
            case .name:
                var replyColor: UIColor
                switch resolvedState.nameColor {
                case let .preset(nameColor):
                    replyColor = component.context.peerNameColors.get(nameColor, dark: environment.theme.overallDarkAppearance).main
                case let .collectible(collectibleColor):
                    replyColor = collectibleColor.mainColor(dark: environment.theme.overallDarkAppearance)
                }
                if let view = self.nameColorSection.findTaggedView(tag: addIconsTag) as? ListActionItemComponent.View, let iconView = view.iconView {
                    self.openEmojiSetup(sourceView: iconView, currentFileId: resolvedState.replyFileId, color: replyColor, subject: .reply)
                }
            }
        }
        
        func update(component: UserAppearanceScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
                        
            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
                       
            if self.component == nil {
                if let controller = environment.controller() as? UserAppearanceScreen, let focusOnItemTag = controller.focusOnItemTag {
                    switch focusOnItemTag {
                    case .profile:
                        self.currentSection = .profile
                    case .profileAddIcons:
                        self.currentSection = .profile
                        Queue.mainQueue().after(0.1) {
                            self.openEmojiSetup()
                        }
                    case .profileUseGift:
                        self.currentSection = .profile
                    case .name:
                        self.currentSection = .name
                    case .nameAddIcons:
                        self.currentSection = .name
                        Queue.mainQueue().after(0.1) {
                            self.openEmojiSetup()
                        }
                    case .nameUseGift:
                        self.currentSection = .name
                    }
                }
            }
            
            self.component = component
            self.state = state
            
            transition.setFrame(view: component.overNavigationContainer, frame: CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: environment.navigationHeight)))
            
            let theme = environment.theme
            
            var animateTabChange = false
            var forceGiftsUpdate = false
            if let hint = transition.userData(TransitionHint.self) {
                animateTabChange = hint.animateTabChange
                forceGiftsUpdate = hint.forceGiftsUpdate
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            if themeUpdated {
                self.backgroundColor = environment.theme.list.blocksBackgroundColor
                self.scrollView.backgroundColor = environment.theme.list.blocksBackgroundColor
            }
            
            if self.cachedChevronImage == nil || self.cachedChevronImage?.1 !== environment.theme {
                self.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextRightArrow"), color: environment.theme.list.itemAccentColor)!, environment.theme)
            }
            
            if self.contentsDataDisposable == nil {
                self.contentsDataDisposable = (ContentsData.get(context: component.context)
                |> deliverOnMainQueue).start(next: { [weak self] contentsData in
                    guard let self else {
                        return
                    }
                    self.contentsData = contentsData
                    
                    if !self.isUpdating {
                        self.state?.updated(transition: .immediate)
                    }
                    self.isReady.set(true)
                })
                
                let starGiftsContext = ProfileGiftsContext(account: component.context.account, peerId: component.context.account.peerId, collectionId: nil, filter: .peerColor, limit: 30)
                self.starGiftsContext = starGiftsContext
                self.starGiftsDisposable = (starGiftsContext.state
                |> deliverOnMainQueue).start(next: { [weak self] state in
                    guard let self else {
                        return
                    }
                    var uniqueGifts: [StarGift.UniqueGift] = []
                    for gift in state.gifts {
                        if case let .unique(uniqueGift) = gift.gift {
                            uniqueGifts.append(uniqueGift)
                        }
                    }
                    self.starGifts = uniqueGifts
                    
                    if !self.isUpdating {
                        self.state?.updated()
                    }
                })
            }
            
            guard let contentsData = self.contentsData, var peer = contentsData.peer, let resolvedState = self.resolveState() else {
                return availableSize
            }
            
            if let currentTheme = self.currentTheme, (self.resolvedCurrentTheme?.reference != currentTheme || self.resolvedCurrentTheme?.isDark != environment.theme.overallDarkAppearance), (self.resolvingCurrentTheme?.reference != currentTheme || self.resolvingCurrentTheme?.isDark != environment.theme.overallDarkAppearance) {
                self.resolvingCurrentTheme?.disposable.dispose()
                
                let disposable = MetaDisposable()
                self.resolvingCurrentTheme = (currentTheme, environment.theme.overallDarkAppearance, disposable)
                
                var presentationTheme: PresentationTheme?
                switch currentTheme {
                case .builtin:
                    presentationTheme = makePresentationTheme(mediaBox: component.context.sharedContext.accountManager.mediaBox, themeReference: .builtin(environment.theme.overallDarkAppearance ? .night : .dayClassic))
                case let .cloud(cloudTheme):
                    presentationTheme = makePresentationTheme(cloudTheme: cloudTheme.theme, dark: environment.theme.overallDarkAppearance)
                default:
                    presentationTheme = makePresentationTheme(mediaBox: component.context.sharedContext.accountManager.mediaBox, themeReference: currentTheme)
                }
                if let presentationTheme {
                    let resolvedWallpaper: Signal<TelegramWallpaper?, NoError>
                    if case let .file(file) = presentationTheme.chat.defaultWallpaper, file.id == 0 {
                        resolvedWallpaper = cachedWallpaper(account: component.context.account, slug: file.slug, settings: file.settings)
                        |> map { wallpaper -> TelegramWallpaper? in
                            return wallpaper?.wallpaper
                        }
                    } else {
                        resolvedWallpaper = .single(presentationTheme.chat.defaultWallpaper)
                    }
                    disposable.set((resolvedWallpaper
                    |> deliverOnMainQueue).startStrict(next: { [weak self] resolvedWallpaper in
                        guard let self, let environment = self.environment else {
                            return
                        }
                        self.resolvedCurrentTheme = (currentTheme, environment.theme.overallDarkAppearance, presentationTheme, resolvedWallpaper)
                        if !self.isUpdating {
                            self.state?.updated(transition: .immediate)
                        }
                    }))
                }
            } else if self.currentTheme == nil {
                self.resolvingCurrentTheme?.disposable.dispose()
                self.resolvingCurrentTheme = nil
                self.resolvedCurrentTheme = nil
            }
                        
            if case let .user(user) = peer {
                peer = .user(user
                    .withUpdatedNameColor(resolvedState.nameColor)
                    .withUpdatedProfileColor(resolvedState.profileColor)
                    .withUpdatedEmojiStatus(resolvedState.emojiStatus)
                    .withUpdatedBackgroundEmojiId(resolvedState.replyFileId)
                    .withUpdatedProfileBackgroundEmojiId(resolvedState.backgroundFileId)
                )
            }
            
            var previewTransition = transition
            let transitionScale = (availableSize.height - 3.0) / availableSize.height
            if animateTabChange, let snapshotView = self.containerView.snapshotView(afterScreenUpdates: false) {
                self.insertSubview(snapshotView, belowSubview: self.containerView)
                snapshotView.layer.animateScale(from: 1.0, to: transitionScale, duration: 0.12, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { completed in
                    snapshotView.removeFromSuperview()
                })
                
                self.scrollView.contentOffset = CGPoint(x: 0.0, y: 0.0)
                
                self.containerView.layer.animateScale(from: transitionScale, to: 1.0, duration: 0.15, delay: 0.1, timingFunction: kCAMediaTimingFunctionSpring)
                self.containerView.layer.allowsGroupOpacity = true
                self.containerView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1, completion: { completed in
                    self.containerView.layer.allowsGroupOpacity = false
                })
                previewTransition = .immediate
            }
            
            let tabSelectorSize = self.tabSelector.update(
                transition: transition,
                component: AnyComponent(
                    TabSelectorComponent(
                        colors: TabSelectorComponent.Colors(
                            foreground: environment.theme.list.itemAccentColor,
                            selection: environment.theme.list.itemAccentColor.withMultipliedAlpha(0.1),
                            normal: environment.theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.78),
                            simple: true
                        ),
                        theme: environment.theme,
                        customLayout: TabSelectorComponent.CustomLayout(font: Font.semibold(16.0)),
                        items: [
                            TabSelectorComponent.Item(id: Section.profile.rawValue, title: environment.strings.ProfileColorSetup_TitleProfile),
                            TabSelectorComponent.Item(id: Section.name.rawValue, title: environment.strings.ProfileColorSetup_TitleName)
                        ],
                        selectedId: self.currentSection.rawValue,
                        setSelectedId: { [weak self] value in
                            guard let self else {
                                return
                            }
                            if let intValue = value.base as? Int32 {
                                let updatedSection = Section(rawValue: intValue) ?? .profile
                                if self.currentSection != updatedSection {
                                    if (updatedSection == .name && self.selectedProfileGift != nil) || (updatedSection == .profile && self.selectedNameGift != nil) {
                                        switch updatedSection {
                                        case .profile:
                                            self.selectedNameGift = nil
                                            self.updatedPeerNameColor = nil
                                            self.updatedPeerNameEmoji = nil
                                        case .name:
                                            self.selectedProfileGift = nil
                                            self.updatedPeerProfileColor = nil
                                            self.updatedPeerProfileEmoji = nil
                                            self.updatedPeerStatus = nil
                                        }
                                    }
                                    self.currentSection = updatedSection
                                    self.state?.updated(transition: .easeInOut(duration: 0.3).withUserData(TransitionHint(animateTabChange: true)))
                                }
                            }
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 44.0)
            )
            let tabSelectorFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - tabSelectorSize.width) / 2.0), y: environment.statusBarHeight + 2.0 + floorToScreenPixels((environment.navigationHeight - environment.statusBarHeight - tabSelectorSize.height) / 2.0)), size: tabSelectorSize)
            if let tabSelectorView = self.tabSelector.view {
                if tabSelectorView.superview == nil {
                    component.overNavigationContainer.addSubview(tabSelectorView)
                }
                transition.setFrame(view: tabSelectorView, frame: tabSelectorFrame)
            }
                        
            let bottomContentInset: CGFloat = 24.0
            let bottomInset: CGFloat = 8.0
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let sectionSpacing: CGFloat = 32.0
            
            let listItemParams = ListViewItemLayoutParams(width: availableSize.width - sideInset * 2.0, leftInset: 0.0, rightInset: 0.0, availableHeight: 10000.0, isStandalone: true)
            
            var contentHeight: CGFloat = 0.0
                         
            let itemCornerRadius: CGFloat = 26.0
            
            transition.setTintColor(view: self.previewShadowView, color: environment.theme.list.itemBlocksBackgroundColor)
            
            switch self.currentSection {
            case .profile:
                var transition = transition
                if self.profilePreview.view == nil {
                    transition = .immediate
                }
                
                if let namePreviewView = self.namePreview.view, namePreviewView.superview != nil {
                    namePreviewView.removeFromSuperview()
                }
                if let nameColorSectionView = self.nameColorSection.view, nameColorSectionView.superview != nil {
                    nameColorSectionView.removeFromSuperview()
                }
                if let nameGiftsSectionView = self.nameGiftsSection.view, nameGiftsSectionView.superview != nil {
                    nameGiftsSectionView.removeFromSuperview()
                }
                   
                let profilePreviewSize = self.profilePreview.update(
                    transition: previewTransition,
                    component: AnyComponent(TopBottomCornersComponent(topCornerRadius: itemCornerRadius, bottomCornerRadius: !self.scrolledUp ? itemCornerRadius : 0.0, component: AnyComponent(ListItemComponentAdaptor(
                        itemGenerator: PeerNameColorProfilePreviewItem(
                            context: component.context,
                            theme: environment.theme,
                            componentTheme: environment.theme,
                            strings: environment.strings,
                            topInset: 28.0,
                            bottomInset: 15.0 + UIScreenPixel,
                            sectionId: 0,
                            peer: peer,
                            subtitleString: environment.strings.Presence_online,
                            files: self.cachedIconFiles,
                            nameDisplayOrder: presentationData.nameDisplayOrder,
                            showBackground: true
                        ),
                        params: ListViewItemLayoutParams(width: availableSize.width - sideInset * 2.0, leftInset: 0.0, rightInset: 0.0, availableHeight: 10000.0, isStandalone: true)
                    )))),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
                )
                let profilePreviewFrame = CGRect(origin: CGPoint(x: sideInset, y: environment.navigationHeight + 12.0), size: profilePreviewSize)
                if let profilePreviewView = self.profilePreview.view {
                    if profilePreviewView.superview == nil {
                        profilePreviewView.isUserInteractionEnabled = false
                        self.containerView.addSubview(profilePreviewView)
                    }
                    transition.setFrame(view: profilePreviewView, frame: profilePreviewFrame)
                }
                contentHeight += profilePreviewSize.height - 38.0
                
                transition.setFrame(view: self.previewShadowView, frame: profilePreviewFrame.insetBy(dx: -45.0, dy: -45.0))
                previewTransition.setAlpha(view: self.previewShadowView, alpha: !self.scrolledUp ? 1.0 : 0.0)
                
                var profileLogoContents: [AnyComponentWithIdentity<Empty>] = []
                profileLogoContents.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: environment.strings.NameColor_AddProfileIcons,
                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                        textColor: environment.theme.list.itemPrimaryTextColor
                    )),
                    maximumNumberOfLines: 0
                ))))
                
                let footerAttributes = MarkdownAttributes(
                    body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.freeTextColor),
                    bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: environment.theme.list.freeTextColor),
                    link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: environment.theme.list.itemAccentColor),
                    linkAttribute: { contents in
                        return (TelegramTextAttributes.URL, contents)
                    }
                )
                let previewFooterText = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(environment.strings.ProfileColorSetup_ProfileColorPreviewInfo, attributes: footerAttributes))
                if let range = previewFooterText.string.range(of: ">"), let chevronImage = self.cachedChevronImage?.0 {
                    previewFooterText.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: previewFooterText.string))
                }
                
                let profileColorSectionSize = self.profileColorSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: environment.theme,
                        style: .glass,
                        header: nil,
                        footer: AnyComponent(MultilineTextComponent(
                            text: .plain(previewFooterText),
                            maximumNumberOfLines: 0,
                            highlightColor: environment.theme.list.itemAccentColor.withAlphaComponent(0.1),
                            highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                            highlightAction: { attributes in
                                if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                                    return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                                } else {
                                    return nil
                                }
                            },
                            tapAction: { [weak self] _, _ in
                                guard let self else {
                                    return
                                }
                                if self.selectedProfileGift != nil {
                                    self.selectedProfileGift = nil
                                    self.updatedPeerProfileColor = nil
                                    self.updatedPeerProfileEmoji = nil
                                    self.updatedPeerStatus = nil
                                }
                                self.currentSection = .name
                                self.state?.updated(transition: .easeInOut(duration: 0.3).withUserData(TransitionHint(animateTabChange: true)))
                            }
                        )),
                        items: [
                            AnyComponentWithIdentity(id: 0, component: AnyComponent(ListItemComponentAdaptor(
                                itemGenerator: PeerNameColorItem(
                                    theme: environment.theme,
                                    systemStyle: .glass,
                                    colors: component.context.peerNameColors,
                                    mode: .profile,
                                    currentColor: resolvedState.profileColor,
                                    updated: { [weak self] value in
                                        guard let self, let value, let resolvedState = self.resolveState() else {
                                            return
                                        }
                                        self.selectedProfileGift = nil
                                        self.updatedPeerProfileColor = value
                                        if case .starGift = resolvedState.emojiStatus?.content {
                                            self.updatedPeerStatus = .some(nil)
                                        }
                                        self.state?.updated(transition: .spring(duration: 0.4))
                                    },
                                    sectionId: 0
                                ),
                                params: listItemParams
                            ))),
                            AnyComponentWithIdentity(id: 1, component: AnyComponent(ListActionItemComponent(
                                theme: environment.theme,
                                style: .glass,
                                title: AnyComponent(HStack(profileLogoContents, spacing: 6.0)),
                                icon: ListActionItemComponent.Icon(component: AnyComponentWithIdentity(id: 0, component: AnyComponent(EmojiActionIconComponent(
                                    context: component.context,
                                    color: resolvedState.profileColor.flatMap { profileColor in
                                        component.context.peerNameColors.getProfile(profileColor, dark: environment.theme.overallDarkAppearance, subject: .palette).main
                                    } ?? environment.theme.list.itemAccentColor,
                                    fileId: resolvedState.backgroundFileId,
                                    file: resolvedState.backgroundFileId.flatMap { self.cachedIconFiles[$0] }
                                )))),
                                action: { [weak self] view in
                                    guard let self, let resolvedState = self.resolveState(), let view = view as? ListActionItemComponent.View, let iconView = view.iconView else {
                                        return
                                    }
                                    
                                    self.openEmojiSetup(sourceView: iconView, currentFileId: resolvedState.backgroundFileId, color: resolvedState.profileColor.flatMap {
                                        component.context.peerNameColors.getProfile($0, dark: environment.theme.overallDarkAppearance, subject: .palette).main
                                    } ?? environment.theme.list.itemAccentColor, subject: .profile)
                                },
                                tag: addIconsTag
                            )))
                        ],
                        displaySeparators: true,
                        extendsItemHighlightToSection: false
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
                )
                let profileColorSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: profileColorSectionSize)
                if let profileColorSectionView = self.profileColorSection.view {
                    if profileColorSectionView.superview == nil {
                        self.scrollView.addSubview(profileColorSectionView)
                    }
                    transition.setFrame(view: profileColorSectionView, frame: profileColorSectionFrame)
                }
                contentHeight += profileColorSectionSize.height
                contentHeight += sectionSpacing
                
                let profileResetColorSectionSize = self.profileResetColorSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: environment.theme,
                        style: .glass,
                        header: nil,
                        footer: nil,
                        items: [
                            AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                                theme: environment.theme,
                                style: .glass,
                                title: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: environment.strings.Channel_Appearance_ResetProfileColor,
                                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                        textColor: environment.theme.list.itemAccentColor
                                    )),
                                    maximumNumberOfLines: 0
                                )),
                                icon: nil,
                                accessory: nil,
                                action: { [weak self] view in
                                    guard let self, let resolvedState = self.resolveState() else {
                                        return
                                    }
                                    self.selectedProfileGift = nil
                                    self.updatedPeerProfileColor = .some(nil)
                                    self.updatedPeerProfileEmoji = .some(nil)
                                    if case .starGift = resolvedState.emojiStatus?.content {
                                        self.updatedPeerStatus = .some(nil)
                                    }
                                    self.state?.updated(transition: .spring(duration: 0.4))
                                }
                            )))
                        ],
                        displaySeparators: false,
                        extendsItemHighlightToSection: true
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
                )
                
                var displayResetProfileColor = resolvedState.profileColor != nil || resolvedState.backgroundFileId != nil
                if case .starGift = resolvedState.emojiStatus?.content {
                    displayResetProfileColor = true
                }
                
                let profileResetColorSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: profileResetColorSectionSize)
                if let profileResetColorSectionView = self.profileResetColorSection.view {
                    if profileResetColorSectionView.superview == nil {
                        self.scrollView.addSubview(profileResetColorSectionView)
                    }
                    transition.setPosition(view: profileResetColorSectionView, position: profileResetColorSectionFrame.center)
                    transition.setBounds(view: profileResetColorSectionView, bounds: CGRect(origin: CGPoint(), size: profileResetColorSectionFrame.size))
                    transition.setScale(view: profileResetColorSectionView, scale: displayResetProfileColor ? 1.0 : 0.001)
                    transition.setAlpha(view: profileResetColorSectionView, alpha: displayResetProfileColor ? 1.0 : 0.0)
                }
                if displayResetProfileColor {
                    contentHeight += profileResetColorSectionSize.height
                    contentHeight += sectionSpacing
                }
                
                var selectedGiftId: Int64?
                if let status = resolvedState.emojiStatus, case let .starGift(id, _, _, _, _, _, _, _, _) = status.content {
                    selectedGiftId = id
                }
                
                let listTransition = transition.withUserData(ListSectionComponent.TransitionHint(forceUpdate: forceGiftsUpdate))
                let giftsSectionSize = self.profileGiftsSection.update(
                    transition: listTransition,
                    component: AnyComponent(ListSectionComponent(
                        theme: environment.theme,
                        style: .glass,
                        header: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.NameColor_GiftTitle.uppercased(),
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        footer: nil,
                        items: [
                            AnyComponentWithIdentity(id: 0, component: AnyComponent(
                                GiftListItemComponent(
                                    context: component.context,
                                    theme: environment.theme,
                                    strings: environment.strings,
                                    subject: .profile,
                                    gifts: contentsData.gifts,
                                    starGifts: contentsData.starGifts,
                                    selectedId: selectedGiftId,
                                    selectionUpdated: { [weak self] gift in
                                        guard let self else {
                                            return
                                        }
                                        var fileId: Int64?
                                        var patternFileId: Int64?
                                        var innerColor: Int32?
                                        var outerColor: Int32?
                                        var patternColor: Int32?
                                        var textColor: Int32?
                                        for attribute in gift.attributes {
                                            switch attribute {
                                            case let .model(_, file, _, _):
                                                fileId = file.fileId.id
                                                self.cachedIconFiles[file.fileId.id] = file
                                            case let .pattern(_, file, _):
                                                patternFileId = file.fileId.id
                                                self.cachedIconFiles[file.fileId.id] = file
                                            case let .backdrop(_, _, innerColorValue, outerColorValue, patternColorValue, textColorValue, _):
                                                innerColor = innerColorValue
                                                outerColor = outerColorValue
                                                patternColor = patternColorValue
                                                textColor = textColorValue
                                            default:
                                                break
                                            }
                                        }
                                        if let fileId, let patternFileId, let innerColor, let outerColor, let patternColor, let textColor {
                                            if let resellAmounts = gift.resellAmounts, !resellAmounts.isEmpty {
                                                self.selectedProfileGift = gift
                                            } else {
                                                self.selectedProfileGift = nil
                                            }
                                            self.updatedPeerProfileColor = .some(nil)
                                            self.updatedPeerProfileEmoji = .some(nil)
                                            self.updatedPeerStatus = .some(PeerEmojiStatus(content: .starGift(id: gift.id, fileId: fileId, title: gift.title, slug: gift.slug, patternFileId: patternFileId, innerColor: innerColor, outerColor: outerColor, patternColor: patternColor, textColor: textColor), expirationDate: nil))
                                            self.state?.updated(transition: .spring(duration: 0.4))
                                        }
                                    },
                                    onTabChange: { [weak self] in
                                        guard let self else {
                                            return
                                        }
                                        if let sectionView = self.profileGiftsSection.view {
                                            self.scrollView.setContentOffset(CGPoint(x: 0.0, y: sectionView.frame.minY - 240.0), animated: true)
                                        }
                                    },
                                    tag: giftListTag,
                                    updated: { [weak self] transition in
                                        if let self, !self.isUpdating {
                                            self.state?.updated(transition: transition.withUserData(TransitionHint(forceGiftsUpdate: true)))
                                        }
                                    }
                                )
                            )),
                        ],
                        displaySeparators: false
                    )),
                    environment: {},
                    forceUpdate: forceGiftsUpdate,
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude)
                )
                let giftsSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: giftsSectionSize)
                if let giftsSectionView = self.profileGiftsSection.view {
                    if giftsSectionView.superview == nil {
                        self.scrollView.addSubview(giftsSectionView)
                    }
                    transition.setFrame(view: giftsSectionView, frame: giftsSectionFrame)
                }
                contentHeight += giftsSectionSize.height
                contentHeight += sectionSpacing
            case .name:
                var transition = transition
                if self.namePreview.view == nil {
                    transition = .immediate
                }
                
                if let profilePreviewView = self.profilePreview.view, profilePreviewView.superview != nil {
                    profilePreviewView.removeFromSuperview()
                }
                if let profileColorSectionView = self.profileColorSection.view, profileColorSectionView.superview != nil {
                    profileColorSectionView.removeFromSuperview()
                }
                if let resetColorSectionView = self.profileResetColorSection.view, resetColorSectionView.superview != nil {
                    resetColorSectionView.removeFromSuperview()
                }
                if let profileGiftsSectionView = self.profileGiftsSection.view, profileGiftsSectionView.superview != nil {
                    profileGiftsSectionView.removeFromSuperview()
                }
                
                var chatPreviewTheme: PresentationTheme = environment.theme
                var chatPreviewWallpaper: TelegramWallpaper = presentationData.chatWallpaper
                if let resolvedCurrentTheme = self.resolvedCurrentTheme {
                    chatPreviewTheme = resolvedCurrentTheme.theme
                    if let wallpaper = resolvedCurrentTheme.wallpaper {
                        chatPreviewWallpaper = wallpaper
                    }
                }
                
                let messageItem = PeerNameColorChatPreviewItem.MessageItem(
                    outgoing: false,
                    peerId: EnginePeer.Id(namespace: peer.id.namespace, id: PeerId.Id._internalFromInt64Value(0)),
                    author: peer.compactDisplayTitle,
                    photo: peer.profileImageRepresentations,
                    nameColor: resolvedState.nameColor,
                    backgroundEmojiId: resolvedState.replyFileId,
                    reply: (peer.compactDisplayTitle, environment.strings.NameColor_ChatPreview_ReplyText_Account, resolvedState.nameColor),
                    linkPreview: (environment.strings.NameColor_ChatPreview_LinkSite, environment.strings.NameColor_ChatPreview_LinkTitle, environment.strings.NameColor_ChatPreview_LinkText),
                    text: environment.strings.NameColor_ChatPreview_MessageText_Account
                )
                
                var replyLogoContents: [AnyComponentWithIdentity<Empty>] = []
                replyLogoContents.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: environment.strings.NameColor_AddRepliesIcons,
                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                        textColor: environment.theme.list.itemPrimaryTextColor
                    )),
                    maximumNumberOfLines: 0
                ))))
                
                
                var replyColor: UIColor
                switch resolvedState.nameColor {
                case let .preset(nameColor):
                    replyColor = component.context.peerNameColors.get(nameColor, dark: environment.theme.overallDarkAppearance).main
                case let .collectible(collectibleColor):
                    replyColor = collectibleColor.mainColor(dark: environment.theme.overallDarkAppearance)
                }
                
                let namePreviewSize = self.namePreview.update(
                    transition: previewTransition,
                    component: AnyComponent(TopBottomCornersComponent(topCornerRadius: itemCornerRadius, bottomCornerRadius: !self.scrolledUp ? itemCornerRadius : 0.0, component: AnyComponent(ListItemComponentAdaptor(
                        itemGenerator: PeerNameColorChatPreviewItem(
                            context: component.context,
                            theme: chatPreviewTheme,
                            componentTheme: chatPreviewTheme,
                            strings: environment.strings,
                            sectionId: 0,
                            fontSize: presentationData.chatFontSize,
                            chatBubbleCorners: presentationData.chatBubbleCorners,
                            wallpaper: chatPreviewWallpaper,
                            dateTimeFormat: environment.dateTimeFormat,
                            nameDisplayOrder: presentationData.nameDisplayOrder,
                            messageItems: [messageItem]
                        ),
                        params: ListViewItemLayoutParams(width: availableSize.width - sideInset * 2.0, leftInset: 0.0, rightInset: 0.0, availableHeight: 10000.0, isStandalone: true)
                    )))),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
                )
                let namePreviewFrame = CGRect(origin: CGPoint(x: sideInset, y: environment.navigationHeight + 12.0), size: namePreviewSize)
                if let namePreviewView = self.namePreview.view {
                    if namePreviewView.superview == nil {
                        namePreviewView.isUserInteractionEnabled = false
                        self.containerView.addSubview(namePreviewView)
                    }
                    transition.setFrame(view: namePreviewView, frame: namePreviewFrame)
                }
                contentHeight += namePreviewSize.height - 38.0
                
                transition.setFrame(view: self.previewShadowView, frame: namePreviewFrame.insetBy(dx: -45.0, dy: -45.0))
                previewTransition.setAlpha(view: self.previewShadowView, alpha: !self.scrolledUp ? 1.0 : 0.0)
                
                let nameColorSectionSize = self.nameColorSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: environment.theme,
                        style: .glass,
                        background: .range(from: 0, corners: DynamicCornerRadiusView.Corners(minXMinY: 0.0, maxXMinY: 0.0, minXMaxY: itemCornerRadius, maxXMaxY: itemCornerRadius)),
                        header: nil,
                        footer: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.NameColor_ChatPreview_Description_Account,
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        items: [
                            AnyComponentWithIdentity(id: 0, component: AnyComponent(ListItemComponentAdaptor(
                                itemGenerator: PeerNameColorItem(
                                    theme: environment.theme,
                                    systemStyle: .glass,
                                    colors: component.context.peerNameColors,
                                    mode: .name,
                                    currentColor: resolvedState.nameColor.nameColor,
                                    updated: { [weak self] value in
                                        guard let self, let resolvedState = self.resolveState(), let value else {
                                            return
                                        }
                                        if case .collectible = resolvedState.nameColor {
                                            self.updatedPeerNameEmoji = .some(nil)
                                        }
                                        self.updatedPeerNameColor = .preset(value)
                                        self.selectedNameGift = nil
                                        self.state?.updated(transition: .spring(duration: 0.4))
                                    },
                                    sectionId: 0
                                ),
                                params: listItemParams
                            ))),
                            AnyComponentWithIdentity(id: 1, component: AnyComponent(ListActionItemComponent(
                                theme: environment.theme,
                                style: .glass,
                                title: AnyComponent(HStack(replyLogoContents, spacing: 6.0)),
                                icon: ListActionItemComponent.Icon(component: AnyComponentWithIdentity(id: 0, component: AnyComponent(EmojiActionIconComponent(
                                    context: component.context,
                                    color: replyColor,
                                    fileId: resolvedState.replyFileId,
                                    file: resolvedState.replyFileId.flatMap { self.cachedIconFiles[$0] }
                                )))),
                                action: { [weak self] view in
                                    guard let self, let resolvedState = self.resolveState(), let view = view as? ListActionItemComponent.View, let iconView = view.iconView else {
                                        return
                                    }
                                    
                                    self.openEmojiSetup(sourceView: iconView, currentFileId: resolvedState.replyFileId, color: replyColor, subject: .reply)
                                },
                                tag: addIconsTag
                            )))
                        ],
                        displaySeparators: true,
                        extendsItemHighlightToSection: false
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
                )
                let nameColorSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: nameColorSectionSize)
                if let nameColorSectionView = self.nameColorSection.view {
                    if nameColorSectionView.superview == nil {
                        self.scrollView.addSubview(nameColorSectionView)
                    }
                    transition.setFrame(view: nameColorSectionView, frame: nameColorSectionFrame)
                }
                contentHeight += nameColorSectionSize.height
                contentHeight += sectionSpacing
                
                var selectedGiftId: Int64?
                if case let .collectible(collectibleColor) = resolvedState.nameColor {
                    selectedGiftId = collectibleColor.collectibleId
                }
                
                var peerColorStarGifts: [StarGift] = []
                for gift in contentsData.starGifts {
                    if case let .generic(genericGift) = gift, genericGift.flags.contains(.peerColorAvailable), let resale = genericGift.availability?.resale, resale > 0 {
                        peerColorStarGifts.append(gift)
                    }
                }
                
                let listTransition = transition.withUserData(ListSectionComponent.TransitionHint(forceUpdate: forceGiftsUpdate))
                let giftsSectionSize = self.nameGiftsSection.update(
                    transition: listTransition,
                    component: AnyComponent(ListSectionComponent(
                        theme: environment.theme,
                        style: .glass,
                        header: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.NameColor_GiftTitle.uppercased(),
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        footer: nil,
                        items: [
                            AnyComponentWithIdentity(id: 0, component: AnyComponent(
                                GiftListItemComponent(
                                    context: component.context,
                                    theme: environment.theme,
                                    strings: environment.strings,
                                    subject: .name,
                                    gifts: self.starGifts,
                                    starGifts: peerColorStarGifts,
                                    selectedId: selectedGiftId,
                                    selectionUpdated: { [weak self] gift in
                                        guard let self, let peerColor = gift.peerColor else {
                                            return
                                        }
                                        if let resellAmounts = gift.resellAmounts, !resellAmounts.isEmpty {
                                            self.selectedNameGift = gift
                                        } else {
                                            self.selectedNameGift = nil
                                        }
                                        self.updatedPeerNameColor = .collectible(peerColor)
                                        self.updatedPeerNameEmoji = peerColor.backgroundEmojiId
                                        self.state?.updated(transition: .spring(duration: 0.4))
                                    },
                                    onTabChange: { [weak self] in
                                        guard let self else {
                                            return
                                        }
                                        if let sectionView = self.nameGiftsSection.view {
                                            self.scrollView.setContentOffset(CGPoint(x: 0.0, y: sectionView.frame.minY - 240.0), animated: true)
                                        }
                                    },
                                    tag: giftListTag,
                                    updated: { [weak self] transition in
                                        if let self, !self.isUpdating {
                                            self.state?.updated(transition: transition.withUserData(TransitionHint(forceGiftsUpdate: true)))
                                        }
                                    }
                                )
                            )),
                        ],
                        displaySeparators: false
                    )),
                    environment: {},
                    forceUpdate: forceGiftsUpdate,
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude)
                )
                let giftsSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: giftsSectionSize)
                if let giftsSectionView = self.nameGiftsSection.view {
                    if giftsSectionView.superview == nil {
                        self.scrollView.addSubview(giftsSectionView)
                    }
                    transition.setFrame(view: giftsSectionView, frame: giftsSectionFrame)
                }
                contentHeight += giftsSectionSize.height
                contentHeight += sectionSpacing
            }
                    
            contentHeight += bottomContentInset
            
            let buttonSideInset: CGFloat = environment.safeInsets.left + 36.0
            var buttonTitle = environment.strings.ProfileColorSetup_ApplyStyle
            var buttonAttributedSubtitleString: NSMutableAttributedString?
            
            let selectedGift: StarGift.UniqueGift?
            if let gift = self.selectedProfileGift {
                selectedGift = gift
            } else if let gift = self.selectedNameGift {
                selectedGift = gift
            } else {
                selectedGift = nil
            }
            
            if let gift = selectedGift, let resellAmounts = gift.resellAmounts, let starsAmount = resellAmounts.first(where: { $0.currency == .stars }) {
                let resellAmount: CurrencyAmount
                if gift.resellForTonOnly {
                    resellAmount = resellAmounts.first(where: { $0.currency == .ton }) ?? starsAmount
                } else {
                    resellAmount = starsAmount
                }
                
                if self.cachedStarImage == nil || self.cachedStarImage?.1 !== theme {
                    self.cachedStarImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/PremiumIcon"), color: theme.list.itemCheckColors.foregroundColor)!, theme)
                }
                if self.cachedTonImage == nil || self.cachedTonImage?.1 !== theme {
                    self.cachedTonImage = (generateTintedImage(image: UIImage(bundleImageName: "Ads/TonAbout"), color: theme.list.itemCheckColors.foregroundColor)!, theme)
                }
                if self.cachedSubtitleStarImage == nil || self.cachedSubtitleStarImage?.1 !== environment.theme {
                    self.cachedSubtitleStarImage = (generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/StarsCount"), color: .white)!, theme)
                }
                
                var buyString = environment.strings.Gift_View_BuyFor
                let currencySymbol: String
                let currencyAmount: String
                switch resellAmount.currency {
                case .stars:
                    currencySymbol = "#"
                    currencyAmount = formatStarsAmountText(resellAmount.amount, dateTimeFormat: environment.dateTimeFormat)
                case .ton:
                    currencySymbol = "$"
                    currencyAmount = formatTonAmountText(resellAmount.amount.value, dateTimeFormat: environment.dateTimeFormat, maxDecimalPositions: nil)
                    
                    buttonAttributedSubtitleString = NSMutableAttributedString(string: environment.strings.Gift_View_EqualsTo(" # \(formatStarsAmountText(starsAmount.amount, dateTimeFormat: environment.dateTimeFormat))").string, font: Font.medium(11.0), textColor: theme.list.itemCheckColors.foregroundColor.withAlphaComponent(0.7), paragraphAlignment: .center)
                    
                }
                buyString += "  \(currencySymbol) \(currencyAmount)"
                buttonTitle = buyString
            }
            
            let buttonAttributedString = NSMutableAttributedString(string: buttonTitle, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center)
            if let range = buttonAttributedString.string.range(of: "#"), let starImage = self.cachedStarImage?.0 {
                buttonAttributedString.addAttribute(.attachment, value: starImage, range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.foregroundColor, value: theme.list.itemCheckColors.foregroundColor, range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.kern, value: 2.0, range: NSRange(range, in: buttonAttributedString.string))
            }
            if let range = buttonAttributedString.string.range(of: "$"), let tonImage = self.cachedTonImage?.0 {
                buttonAttributedString.addAttribute(.attachment, value: tonImage, range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.foregroundColor, value: theme.list.itemCheckColors.foregroundColor, range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: buttonAttributedString.string))
                buttonAttributedString.addAttribute(.kern, value: 2.0, range: NSRange(range, in: buttonAttributedString.string))
            }
            if let buttonAttributedSubtitleString, let range = buttonAttributedSubtitleString.string.range(of: "#"), let starImage = self.cachedSubtitleStarImage?.0 {
                buttonAttributedSubtitleString.addAttribute(.attachment, value: starImage, range: NSRange(range, in: buttonAttributedSubtitleString.string))
                buttonAttributedSubtitleString.addAttribute(.foregroundColor, value: theme.list.itemCheckColors.foregroundColor.withAlphaComponent(0.7), range: NSRange(range, in: buttonAttributedSubtitleString.string))
                buttonAttributedSubtitleString.addAttribute(.baselineOffset, value: 1.5, range: NSRange(range, in: buttonAttributedSubtitleString.string))
                buttonAttributedSubtitleString.addAttribute(.kern, value: 2.0, range: NSRange(range, in: buttonAttributedSubtitleString.string))
            }
            
            var buttonContents: [AnyComponentWithIdentity<Empty>] = [
                AnyComponentWithIdentity(id: AnyHashable(buttonTitle), component: AnyComponent(MultilineTextComponent(text: .plain(buttonAttributedString))))
            ]
            if let buttonAttributedSubtitleString {
                buttonContents.append(AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(text: .plain(buttonAttributedSubtitleString)))))
            }
            
            let buttonSize = self.actionButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: environment.theme.list.itemCheckColors.fillColor,
                        foreground: environment.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.8)
                    ),
                    content: AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(
                        VStack(buttonContents, spacing: 3.0)
                    )),
                    isEnabled: true,
                    tintWhenDisabled: false,
                    displaysProgress: self.isApplyingSettings,
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.applySettings()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - buttonSideInset * 2.0, height: 52.0)
            )
            contentHeight += buttonSize.height
            
            contentHeight += bottomInset
            contentHeight += environment.safeInsets.bottom
            
            let buttonY = availableSize.height - bottomInset - environment.safeInsets.bottom - buttonSize.height
            
            let buttonFrame = CGRect(origin: CGPoint(x: buttonSideInset, y: buttonY), size: buttonSize)
            if let buttonView = self.actionButton.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                transition.setFrame(view: buttonView, frame: buttonFrame)
                transition.setAlpha(view: buttonView, alpha: 1.0)
            }
            
            let edgeEffectHeight: CGFloat = availableSize.height - buttonY + 36.0
            let edgeEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - edgeEffectHeight), size: CGSize(width: availableSize.width, height: edgeEffectHeight))
            transition.setFrame(view: self.edgeEffectView, frame: edgeEffectFrame)
            self.edgeEffectView.update(content: environment.theme.list.blocksBackgroundColor, alpha: 1.0, rect: edgeEffectFrame, edge: .bottom, edgeSize: edgeEffectFrame.height, transition: transition)
              
            let previousBounds = self.scrollView.bounds
            let contentSize = CGSize(width: availableSize.width, height: contentHeight)
            let scrollViewFrame = CGRect(origin: CGPoint(x: 0.0, y: environment.navigationHeight + 50.0), size: CGSize(width: availableSize.width, height: availableSize.height - environment.navigationHeight - 50.0))
            if self.scrollView.frame != scrollViewFrame {
                self.scrollView.frame = scrollViewFrame
            }
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }

            transition.setFrame(view: self.containerView, frame: CGRect(origin: .zero, size: availableSize))
                        
            if !previousBounds.isEmpty, !transition.animation.isImmediate {
                let bounds = self.scrollView.bounds
                if bounds.maxY != previousBounds.maxY {
                    let offsetY = previousBounds.maxY - bounds.maxY
                    transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: offsetY), to: CGPoint(), additive: true)
                }
            }
            
            self.topOverscrollLayer.backgroundColor = environment.theme.list.itemBlocksBackgroundColor.cgColor
            self.topOverscrollLayer.frame = CGRect(origin: CGPoint(x: sideInset, y: -1000.0), size: CGSize(width: availableSize.width - sideInset * 2.0, height: 1340.0))
            
            self.updateScrolling(transition: transition)
            
            if let controller = environment.controller(), !controller.automaticallyControlPresentationContextLayout {
                let layout = ContainerViewLayout(
                    size: availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: availableSize.height - buttonFrame.minY, right: 0.0),
                    safeInsets: UIEdgeInsets(top: 0.0, left: environment.safeInsets.left, bottom: 0.0, right: environment.safeInsets.right),
                    additionalInsets: .zero,
                    statusBarHeight: environment.statusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(layout, transition: transition.containedViewLayoutTransition)
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class UserAppearanceScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    fileprivate let focusOnItemTag: UserAppearanceEntryTag?
    
    private let overNavigationContainer: UIView
    
    private var didSetReady: Bool = false
    
    public init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
        focusOnItemTag: UserAppearanceEntryTag? = nil
    ) {
        self.context = context
        self.focusOnItemTag = focusOnItemTag
        
        self.overNavigationContainer = SparseContainerView()
        
        super.init(context: context, component: UserAppearanceScreenComponent(
            context: context,
            overNavigationContainer: self.overNavigationContainer
        ), navigationBarAppearance: .default, theme: .default, updatedPresentationData: updatedPresentationData)
        
        self.automaticallyControlPresentationContextLayout = false
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.title = ""
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.ready.set(.never())
        
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? UserAppearanceScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
        
        self.attemptNavigation = { [weak self] complete in
            guard let self, let componentView = self.node.hostView.componentView as? UserAppearanceScreenComponent.View else {
                return true
            }
            
            return componentView.attemptNavigation(complete: complete)
        }
        
        if let navigationBar = self.navigationBar {
            navigationBar.customOverBackgroundContentView.insertSubview(self.overNavigationContainer, at: 0)
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    fileprivate func backPressed() {
        if self.attemptNavigation({ [weak self] in
            self?.dismiss()
        }) {
            self.dismiss()
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        if let componentView = self.node.hostView.componentView as? UserAppearanceScreenComponent.View {
            if !self.didSetReady {
                self.didSetReady = true
                self.ready.set(componentView.isReady.get())
            }
        }
    }
}

private extension PeerColor {
    var nameColor: PeerNameColor? {
        switch self {
        case let .preset(nameColor):
            return nameColor
        default:
            return nil
        }
    }
}


final class TopBottomCornersComponent: Component {
    private let topCornerRadius: CGFloat
    private let bottomCornerRadius: CGFloat
    private let component: AnyComponent<Empty>
    
    public init(
        topCornerRadius: CGFloat,
        bottomCornerRadius: CGFloat,
        component: AnyComponent<Empty>
    ) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
        self.component = component
    }
    
    public static func == (lhs: TopBottomCornersComponent, rhs: TopBottomCornersComponent) -> Bool {
        if lhs.topCornerRadius != rhs.topCornerRadius {
            return false
        }
        if lhs.bottomCornerRadius != rhs.bottomCornerRadius {
            return false
        }
        if lhs.component != rhs.component {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let containerView: UIView
        private let hostView: ComponentHostView<Empty>
        
        public override init(frame: CGRect) {
            self.containerView = UIView()
            self.hostView = ComponentHostView<Empty>()
            
            super.init(frame: frame)
            
            self.clipsToBounds = true
            self.containerView.clipsToBounds = true
            
            self.addSubview(self.containerView)
            self.containerView.addSubview(self.hostView)
        }
        
        public required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        func update(component: TopBottomCornersComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            
            let size = self.hostView.update(
                transition: transition,
                component: component.component,
                environment: {},
                containerSize: availableSize
            )
            
            transition.setCornerRadius(layer: self.containerView.layer, cornerRadius: component.topCornerRadius)
            transition.setCornerRadius(layer: self.layer, cornerRadius: component.bottomCornerRadius)
            transition.setFrame(view: self.containerView, frame: CGRect(origin: .zero, size: CGSize(width: availableSize.width, height: availableSize.height + component.bottomCornerRadius)))
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private func generatePreviewShadowImage() -> UIImage {
    let cornerRadius: CGFloat = 26.0
    let shadowInset: CGFloat = 45.0
    
    let side = (cornerRadius + 5.0) * 2.0
    let fullSide = shadowInset * 2.0 + side
    
    return generateImage(CGSize(width: fullSide, height: fullSide), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        let edgeHeight = shadowInset + cornerRadius + 11.0
        context.clip(to: CGRect(x: shadowInset, y: size.height - edgeHeight, width: side, height: edgeHeight))
        
        let rect = CGRect(origin: .zero, size: CGSize(width: fullSide, height: fullSide)).insetBy(dx: shadowInset + 1.0, dy: shadowInset + 2.0)
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        
        let drawShadow = {
            context.addPath(path)
            context.setShadow(offset: CGSize(), blur: 80.0, color: UIColor.black.cgColor)
            context.setFillColor(UIColor.black.cgColor)
            context.fillPath()
        }
        
        drawShadow()
        drawShadow()
        drawShadow()
    })!.stretchableImage(withLeftCapWidth: Int(shadowInset + cornerRadius + 5), topCapHeight: Int(shadowInset + cornerRadius + 5)).withRenderingMode(.alwaysTemplate)
}
