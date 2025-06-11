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

private let giftListTag = GenericComponentViewTag()

final class UserAppearanceScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext

    init(
        context: AccountContext
    ) {
        self.context = context
    }

    static func ==(lhs: UserAppearanceScreenComponent, rhs: UserAppearanceScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    private final class ContentsData {
        let peer: EnginePeer?
        let gifts: [StarGift.UniqueGift]
        
        init(
            peer: EnginePeer?,
            gifts: [StarGift.UniqueGift]
        ) {
            self.peer = peer
            self.gifts = gifts
        }
        
        static func get(context: AccountContext) -> Signal<ContentsData, NoError> {
            return combineLatest(
                context.engine.data.subscribe(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)
                ),
                context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudUniqueStarGifts], namespaces: [Namespaces.ItemCollection.CloudDice], aroundIndex: nil, count: 10000000)
            )
            |> map { peer, view -> ContentsData in
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
                    gifts: gifts
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
        
        var nameColor: PeerNameColor
        var profileColor: PeerNameColor?
        var replyFileId: Int64?
        var backgroundFileId: Int64?
        var emojiStatus: PeerEmojiStatus?
        
        var changes: Changes
        
        init(
            nameColor: PeerNameColor,
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
        private let topOverscrollLayer = SimpleLayer()
        private let scrollView: ScrollView
        private let actionButton = ComponentView<Empty>()
        private let bottomPanelBackgroundView: BlurredBackgroundView
        private let bottomPanelSeparator: SimpleLayer
        
        private let backButton = PeerInfoHeaderNavigationButton()
        
        private let tabSelector = ComponentView<Empty>()
        
        private let previewSection = ComponentView<Empty>()
        private let boostSection = ComponentView<Empty>()
        private let bannerSection = ComponentView<Empty>()
        private let replySection = ComponentView<Empty>()
        private let wallpaperSection = ComponentView<Empty>()
        private let resetColorSection = ComponentView<Empty>()
        private let giftsSection = ComponentView<Empty>()
                
        private var isUpdating: Bool = false
        
        private var component: UserAppearanceScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        let isReady = ValuePromise<Bool>(false, ignoreRepeated: true)
        private var contentsData: ContentsData?
        private var contentsDataDisposable: Disposable?
        
        private var cachedIconFiles: [Int64: TelegramMediaFile] = [:]
        
        private var updatedPeerNameColor: PeerNameColor?
        private var updatedPeerNameEmoji: Int64??
        
        private var updatedPeerProfileColor: PeerNameColor??
        private var updatedPeerProfileEmoji: Int64??
        private var updatedPeerStatus: PeerEmojiStatus??
        
        private var currentTheme: PresentationThemeReference?
        private var resolvedCurrentTheme: (reference: PresentationThemeReference, isDark: Bool, theme: PresentationTheme, wallpaper: TelegramWallpaper?)?
        private var resolvingCurrentTheme: (reference: PresentationThemeReference, isDark: Bool, disposable: Disposable)?
                
        private var isApplyingSettings: Bool = false
        private var applyDisposable: Disposable?
        
        private weak var emojiStatusSelectionController: ViewController?
        
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
            
            self.bottomPanelBackgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            self.bottomPanelSeparator = SimpleLayer()
            
            super.init(frame: frame)
            
            self.scrollView.delegate = self
            self.addSubview(self.scrollView)
            
            self.scrollView.layer.addSublayer(self.topOverscrollLayer)
            
            self.addSubview(self.bottomPanelBackgroundView)
            self.layer.addSublayer(self.bottomPanelSeparator)
            
            self.backButton.action = { [weak self] _, _ in
                if let self, let controller = self.environment?.controller() {
                    controller.navigationController?.popViewController(animated: true)
                }
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.contentsDataDisposable?.dispose()
            self.applyDisposable?.dispose()
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
                self.environment?.controller()?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: presentationData.strings.Channel_Appearance_UnsavedChangesAlertTitle, text: presentationData.strings.Channel_Appearance_UnsavedChangesAlertText, actions: [
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
                ]), in: .window(.root))
                
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
                    self.state?.updated()
                }
            }
                        
            let bottomNavigationAlphaDistance: CGFloat = 16.0
            let bottomNavigationAlpha: CGFloat = max(0.0, min(1.0, (self.scrollView.contentSize.height - self.scrollView.bounds.maxY) / bottomNavigationAlphaDistance))
            
            transition.setAlpha(view: self.bottomPanelBackgroundView, alpha: bottomNavigationAlpha)
            transition.setAlpha(layer: self.bottomPanelSeparator, alpha: bottomNavigationAlpha)
            
            if let giftListView = self.giftsSection.findTaggedView(tag: giftListTag) as? GiftListItemComponent.View {
                let rect = self.scrollView.convert(self.scrollView.bounds, to: giftListView)
                let visibleRect = giftListView.bounds.intersection(rect)
                giftListView.updateVisibleBounds(visibleRect)
            }
        }
        
        private func resolveState() -> ResolvedState? {
            guard let contentsData = self.contentsData, let peer = contentsData.peer else {
                return nil
            }
            
            var changes: ResolvedState.Changes = []
            
            let nameColor: PeerNameColor
            if let updatedPeerNameColor = self.updatedPeerNameColor {
                nameColor = updatedPeerNameColor
            } else if let peerNameColor = peer.nameColor {
                nameColor = peerNameColor
            } else {
                nameColor = .blue
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
            
            self.isApplyingSettings = true
            self.state?.updated(transition: .immediate)
            
            self.applyDisposable?.dispose()
                        
            enum ApplyError {
                case generic
            }
            
            var signals: [Signal<Never, ApplyError>] = []
            if !resolvedState.changes.intersection([.nameColor, .replyFileId, .profileColor, .backgroundFileId]).isEmpty {
                signals.append(component.context.engine.accountData.updateNameColorAndEmoji(nameColor: resolvedState.nameColor, backgroundEmojiId: resolvedState.replyFileId, profileColor: resolvedState.profileColor, profileBackgroundEmojiId: resolvedState.backgroundFileId)
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
                                title: title,
                                number: number,
                                slug: slug,
                                owner: .peerId(component.context.account.peerId),
                                attributes: [
                                    .model(name: "", file: file, rarity: 0),
                                    .pattern(name: "", file: patternFile, rarity: 0),
                                    .backdrop(name: "", id: 0, innerColor: innerColor, outerColor: outerColor, patternColor: patternColor, textColor: textColor, rarity: 0)
                                ],
                                availability: StarGift.UniqueGift.Availability(issued: 0, total: 0),
                                giftAddress: nil,
                                resellStars: nil
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
                self.environment?.controller()?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                
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
        
        func update(component: UserAppearanceScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
            
            self.component = component
            self.state = state
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            if themeUpdated {
                self.backgroundColor = environment.theme.list.blocksBackgroundColor
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
                                    
            let headerColor: UIColor
            if let profileColor = resolvedState.profileColor {
                let headerBackgroundColors = component.context.peerNameColors.getProfile(profileColor, dark: environment.theme.overallDarkAppearance, subject: .background)
                headerColor = headerBackgroundColors.secondary ?? headerBackgroundColors.main
            } else {
                headerColor = .clear
            }
            self.topOverscrollLayer.backgroundColor = headerColor.cgColor
            
            let backSize = self.backButton.update(key: .back, presentationData: component.context.sharedContext.currentPresentationData.with { $0 }, height: 44.0)

            var hasHeaderColor = false
            if resolvedState.profileColor != nil {
                hasHeaderColor = true
            }
            if case .starGift = resolvedState.emojiStatus?.content {
                hasHeaderColor = true
            }
            if let controller = self.environment?.controller() as? UserAppearanceScreen {
                controller.statusBar.updateStatusBarStyle(hasHeaderColor ? .White : .Ignore, animated: true)
            }
            
            self.backButton.updateContentsColor(backgroundColor: hasHeaderColor ? UIColor(white: 1.0, alpha: 0.1) : .clear, contentsColor: hasHeaderColor ? .white : environment.theme.rootController.navigationBar.accentTextColor, canBeExpanded: !hasHeaderColor, transition: .animated(duration: 0.2, curve: .easeInOut))
            self.backButton.frame = CGRect(origin: CGPoint(x: environment.safeInsets.left + 16.0, y: environment.navigationHeight - 44.0), size: backSize)
            if self.backButton.view.superview == nil {
                if let controller = self.environment?.controller(), let navigationBar = controller.navigationBar {
                    navigationBar.view.addSubview(self.backButton.view)
                }
            }
                        
            let bottomContentInset: CGFloat = 24.0
            let bottomInset: CGFloat = 8.0
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let sectionSpacing: CGFloat = 32.0
            
            let listItemParams = ListViewItemLayoutParams(width: availableSize.width - sideInset * 2.0, leftInset: 0.0, rightInset: 0.0, availableHeight: 10000.0, isStandalone: true)
            
            var contentHeight: CGFloat = 0.0
            
            let sectionTransition = transition
                    
            let previewSectionSize = self.previewSection.update(
                transition: sectionTransition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    background: .none(clipped: false),
                    header: nil,
                    footer: nil,
                    items: [
                        AnyComponentWithIdentity(id: 0, component: AnyComponent(ListItemComponentAdaptor(
                            itemGenerator: PeerNameColorProfilePreviewItem(
                                context: component.context,
                                theme: environment.theme,
                                componentTheme: environment.theme,
                                strings: environment.strings,
                                topInset: environment.statusBarHeight,
                                sectionId: 0,
                                peer: peer,
                                subtitleString: environment.strings.Presence_online,
                                files: self.cachedIconFiles,
                                nameDisplayOrder: presentationData.nameDisplayOrder,
                                showBackground: !self.scrolledUp
                            ),
                            params: ListViewItemLayoutParams(width: availableSize.width, leftInset: 0.0, rightInset: 0.0, availableHeight: 10000.0, isStandalone: true)
                        ))),
                    ],
                    displaySeparators: false,
                    extendsItemHighlightToSection: true
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 1000.0)
            )
            let previewSectionFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: previewSectionSize)
            if let previewSectionView = self.previewSection.view {
                if previewSectionView.superview == nil {
                    self.addSubview(previewSectionView)
                }
                sectionTransition.setFrame(view: previewSectionView, frame: previewSectionFrame)
            }
            contentHeight += previewSectionSize.height
            contentHeight += sectionSpacing - 15.0
            
            var profileLogoContents: [AnyComponentWithIdentity<Empty>] = []
            profileLogoContents.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(
                    string: environment.strings.NameColor_AddProfileIcons,
                    font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                    textColor: environment.theme.list.itemPrimaryTextColor
                )),
                maximumNumberOfLines: 0
            ))))
            let bannerSectionSize = self.bannerSection.update(
                transition: sectionTransition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    background: .all,
                    header: nil,
                    footer: nil,
                    items: [
                        AnyComponentWithIdentity(id: 1, component: AnyComponent(ListItemComponentAdaptor(
                            itemGenerator: PeerNameColorItem(
                                theme: environment.theme,
                                colors: component.context.peerNameColors,
                                mode: .profile,
                                currentColor: resolvedState.profileColor,
                                updated: { [weak self] value in
                                    guard let self, let value, let resolvedState = self.resolveState() else {
                                        return
                                    }
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
                        AnyComponentWithIdentity(id: 2, component: AnyComponent(ListActionItemComponent(
                            theme: environment.theme,
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
                            }
                        )))
                    ],
                    displaySeparators: true,
                    extendsItemHighlightToSection: false
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            let bannerSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: bannerSectionSize)
            if let bannerSectionView = self.bannerSection.view {
                if bannerSectionView.superview == nil {
                    self.scrollView.addSubview(bannerSectionView)
                }
                sectionTransition.setFrame(view: bannerSectionView, frame: bannerSectionFrame)
            }
            contentHeight += bannerSectionSize.height
            contentHeight += sectionSpacing
            
            let resetColorSectionSize = self.resetColorSection.update(
                transition: sectionTransition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: nil,
                    footer: nil,
                    items: [
                        AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                            theme: environment.theme,
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
            
            let resetColorSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: resetColorSectionSize)
            if let resetColorSectionView = self.resetColorSection.view {
                if resetColorSectionView.superview == nil {
                    self.scrollView.addSubview(resetColorSectionView)
                }
                sectionTransition.setPosition(view: resetColorSectionView, position: resetColorSectionFrame.center)
                sectionTransition.setBounds(view: resetColorSectionView, bounds: CGRect(origin: CGPoint(), size: resetColorSectionFrame.size))
                sectionTransition.setScale(view: resetColorSectionView, scale: displayResetProfileColor ? 1.0 : 0.001)
                sectionTransition.setAlpha(view: resetColorSectionView, alpha: displayResetProfileColor ? 1.0 : 0.0)
            }
            if displayResetProfileColor {
                contentHeight += resetColorSectionSize.height
                contentHeight += sectionSpacing
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
            let replySectionSize = self.replySection.update(
                transition: sectionTransition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
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
                            params: listItemParams
                        ))),
                        AnyComponentWithIdentity(id: 1, component: AnyComponent(ListItemComponentAdaptor(
                            itemGenerator: PeerNameColorItem(
                                theme: environment.theme,
                                colors: component.context.peerNameColors,
                                mode: .name,
                                currentColor: resolvedState.nameColor,
                                updated: { [weak self] value in
                                    guard let self, let value else {
                                        return
                                    }
                                    self.updatedPeerNameColor = value
                                    self.state?.updated(transition: .spring(duration: 0.4))
                                },
                                sectionId: 0
                            ),
                            params: listItemParams
                        ))),
                        AnyComponentWithIdentity(id: 2, component: AnyComponent(ListActionItemComponent(
                            theme: environment.theme,
                            title: AnyComponent(HStack(replyLogoContents, spacing: 6.0)),
                            icon: ListActionItemComponent.Icon(component: AnyComponentWithIdentity(id: 0, component: AnyComponent(EmojiActionIconComponent(
                                context: component.context,
                                color: component.context.peerNameColors.get(resolvedState.nameColor, dark: environment.theme.overallDarkAppearance).main,
                                fileId: resolvedState.replyFileId,
                                file: resolvedState.replyFileId.flatMap { self.cachedIconFiles[$0] }
                            )))),
                            action: { [weak self] view in
                                guard let self, let resolvedState = self.resolveState(), let view = view as? ListActionItemComponent.View, let iconView = view.iconView else {
                                    return
                                }
                                
                                self.openEmojiSetup(sourceView: iconView, currentFileId: resolvedState.replyFileId, color: component.context.peerNameColors.get(resolvedState.nameColor, dark: environment.theme.overallDarkAppearance).main, subject: .reply)
                            }
                        )))
                    ],
                    displaySeparators: true,
                    extendsItemHighlightToSection: false
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            let replySectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: replySectionSize)
            if let replySectionView = self.replySection.view {
                if replySectionView.superview == nil {
                    self.scrollView.addSubview(replySectionView)
                }
                sectionTransition.setFrame(view: replySectionView, frame: replySectionFrame)
            }
            contentHeight += replySectionSize.height
            contentHeight += sectionSpacing
            
            if !contentsData.gifts.isEmpty {
                var selectedGiftId: Int64?
                if let status = resolvedState.emojiStatus, case let .starGift(id, _, _, _, _, _, _, _, _) = status.content {
                    selectedGiftId = id
                }
                let giftsSectionSize = self.giftsSection.update(
                    transition: sectionTransition,
                    component: AnyComponent(ListSectionComponent(
                        theme: environment.theme,
                        header: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.NameColor_GiftTitle,
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        footer: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.NameColor_GiftInfo,
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        items: [
                            AnyComponentWithIdentity(id: 0, component: AnyComponent(
                                GiftListItemComponent(
                                    context: component.context,
                                    theme: environment.theme,
                                    gifts: contentsData.gifts,
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
                                            case let .model(_, file, _):
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
                                            self.updatedPeerProfileColor = .some(nil)
                                            self.updatedPeerProfileEmoji = .some(nil)
                                            self.updatedPeerStatus = .some(PeerEmojiStatus(content: .starGift(id: gift.id, fileId: fileId, title: gift.title, slug: gift.slug, patternFileId: patternFileId, innerColor: innerColor, outerColor: outerColor, patternColor: patternColor, textColor: textColor), expirationDate: nil))
                                            self.state?.updated(transition: .spring(duration: 0.4))
                                        }
                                    },
                                    tag: giftListTag
                                )
                            )),
                        ],
                        displaySeparators: false
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
                )
                let giftsSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: giftsSectionSize)
                if let giftsSectionView = self.giftsSection.view {
                    if giftsSectionView.superview == nil {
                        self.scrollView.addSubview(giftsSectionView)
                    }
                    sectionTransition.setFrame(view: giftsSectionView, frame: giftsSectionFrame)
                }
                contentHeight += giftsSectionSize.height
                contentHeight += sectionSpacing
            }
            
            contentHeight += bottomContentInset
            
            var buttonTitle = environment.strings.Channel_Appearance_ApplyButton
            if let emojiStatus = resolvedState.emojiStatus, case .starGift = emojiStatus.content, resolvedState.changes.contains(.emojiStatus) {
                buttonTitle = environment.strings.NameColor_WearCollectible
            }
            
            var buttonContents: [AnyComponentWithIdentity<Empty>] = []
            buttonContents.append(AnyComponentWithIdentity(id: AnyHashable(buttonTitle), component: AnyComponent(
                Text(text: buttonTitle, font: Font.semibold(17.0), color: environment.theme.list.itemCheckColors.foregroundColor)
            )))
             
            let buttonSize = self.actionButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
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
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 50.0)
            )
            contentHeight += buttonSize.height
            
            contentHeight += bottomInset
            contentHeight += environment.safeInsets.bottom
            
            let buttonY = availableSize.height - bottomInset - environment.safeInsets.bottom - buttonSize.height
            
            let buttonFrame = CGRect(origin: CGPoint(x: sideInset, y: buttonY), size: buttonSize)
            if let buttonView = self.actionButton.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                transition.setFrame(view: buttonView, frame: buttonFrame)
                transition.setAlpha(view: buttonView, alpha: 1.0)
            }
            
            let bottomPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: buttonY - 8.0), size: CGSize(width: availableSize.width, height: availableSize.height - buttonY + 8.0))
            transition.setFrame(view: self.bottomPanelBackgroundView, frame: bottomPanelFrame)
            self.bottomPanelBackgroundView.updateColor(color: environment.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
            self.bottomPanelBackgroundView.update(size: bottomPanelFrame.size, transition: transition.containedViewLayoutTransition)
            
            self.bottomPanelSeparator.backgroundColor = environment.theme.rootController.navigationBar.separatorColor.cgColor
            transition.setFrame(layer: self.bottomPanelSeparator, frame: CGRect(origin: CGPoint(x: bottomPanelFrame.minX, y: bottomPanelFrame.minY), size: CGSize(width: bottomPanelFrame.width, height: UIScreenPixel)))
            
            let previousBounds = self.scrollView.bounds
            let contentSize = CGSize(width: availableSize.width, height: contentHeight)
            if self.scrollView.frame != CGRect(origin: CGPoint(), size: availableSize) {
                self.scrollView.frame = CGRect(origin: CGPoint(), size: availableSize)
            }
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollInsets = UIEdgeInsets(top: environment.navigationHeight, left: 0.0, bottom: availableSize.height - bottomPanelFrame.minY, right: 0.0)
            if self.scrollView.verticalScrollIndicatorInsets != scrollInsets {
                self.scrollView.verticalScrollIndicatorInsets = scrollInsets
            }
                        
            if !previousBounds.isEmpty, !transition.animation.isImmediate {
                let bounds = self.scrollView.bounds
                if bounds.maxY != previousBounds.maxY {
                    let offsetY = previousBounds.maxY - bounds.maxY
                    transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: offsetY), to: CGPoint(), additive: true)
                }
            }
            
            self.topOverscrollLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: -3000.0), size: CGSize(width: availableSize.width, height: 3000.0))
            
            self.updateScrolling(transition: transition)
            
            if let controller = environment.controller(), !controller.automaticallyControlPresentationContextLayout {
                let layout = ContainerViewLayout(
                    size: availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomPanelFrame.height, right: 0.0),
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
    
    private var didSetReady: Bool = false
    
    public init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil
    ) {
        self.context = context
        
        super.init(context: context, component: UserAppearanceScreenComponent(
            context: context
        ), navigationBarAppearance: .default, theme: .default, updatedPresentationData: updatedPresentationData)
        
        self.automaticallyControlPresentationContextLayout = false
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.title = ""
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
        
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
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
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
