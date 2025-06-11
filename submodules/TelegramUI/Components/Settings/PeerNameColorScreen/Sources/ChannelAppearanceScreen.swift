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
import PremiumLockButtonSubtitleComponent
import ListItemComponentAdaptor
import ListSectionComponent
import MultilineTextComponent
import ThemeCarouselItem
import ListActionItemComponent
import EmojiStatusSelectionComponent
import EmojiStatusComponent
import DynamicCornerRadiusView
import ComponentDisplayAdapters
import WallpaperResources
import MediaPickerUI
import WallpaperGalleryScreen
import WallpaperGridScreen
import BoostLevelIconComponent
import BundleIconComponent
import Markdown
import GroupStickerPackSetupController
import PeerNameColorItem
import EmojiActionIconComponent

final class ChannelAppearanceScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let peerId: EnginePeer.Id
    let boostStatus: ChannelBoostStatus?

    init(
        context: AccountContext,
        peerId: EnginePeer.Id,
        boostStatus: ChannelBoostStatus?
    ) {
        self.context = context
        self.peerId = peerId
        self.boostStatus = boostStatus
    }

    static func ==(lhs: ChannelAppearanceScreenComponent, rhs: ChannelAppearanceScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }

        return true
    }
    
    private final class ContentsData {
        let peer: EnginePeer?
        let peerWallpaper: TelegramWallpaper?
        let peerEmojiPack: StickerPackCollectionInfo?
        let canSetStickerPack: Bool
        let peerStickerPack: StickerPackCollectionInfo?
        let subscriberCount: Int?
        let availableThemes: [TelegramTheme]
        
        init(peer: EnginePeer?, peerWallpaper: TelegramWallpaper?, peerEmojiPack: StickerPackCollectionInfo?, canSetStickerPack: Bool, peerStickerPack: StickerPackCollectionInfo?, subscriberCount: Int?, availableThemes: [TelegramTheme]) {
            self.peer = peer
            self.peerWallpaper = peerWallpaper
            self.peerEmojiPack = peerEmojiPack
            self.canSetStickerPack = canSetStickerPack
            self.peerStickerPack = peerStickerPack
            self.subscriberCount = subscriberCount
            self.availableThemes = availableThemes
        }
        
        static func get(context: AccountContext, peerId: EnginePeer.Id) -> Signal<ContentsData, NoError> {
            return combineLatest(
                context.engine.data.subscribe(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
                    TelegramEngine.EngineData.Item.Peer.ParticipantCount(id: peerId),
                    TelegramEngine.EngineData.Item.Peer.EmojiPack(id: peerId),
                    TelegramEngine.EngineData.Item.Peer.CanSetStickerPack(id: peerId),
                    TelegramEngine.EngineData.Item.Peer.StickerPack(id: peerId),
                    TelegramEngine.EngineData.Item.Peer.Wallpaper(id: peerId)
                ),
                telegramThemes(postbox: context.account.postbox, network: context.account.network, accountManager: context.sharedContext.accountManager)
            )
            |> map { peerData, cloudThemes -> ContentsData in
                let (peer, subscriberCount, emojiPack, canSetStickerPack, stickerPack, wallpaper) = peerData
                return ContentsData(
                    peer: peer,
                    peerWallpaper: wallpaper,
                    peerEmojiPack: emojiPack,
                    canSetStickerPack: canSetStickerPack,
                    peerStickerPack: stickerPack,
                    subscriberCount: subscriberCount,
                    availableThemes: cloudThemes
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
            static let wallpaper = Changes(rawValue: 1 << 5)
            static let emojiPack = Changes(rawValue: 1 << 6)
        }
        
        var nameColor: PeerNameColor
        var profileColor: PeerNameColor?
        var replyFileId: Int64?
        var backgroundFileId: Int64?
        var emojiStatus: PeerEmojiStatus?
        var wallpaper: TelegramWallpaper?
        var emojiPack: StickerPackCollectionInfo?
        
        var changes: Changes
        
        init(
            nameColor: PeerNameColor,
            profileColor: PeerNameColor?,
            replyFileId: Int64?,
            backgroundFileId: Int64?,
            emojiStatus: PeerEmojiStatus?,
            wallpaper: TelegramWallpaper?,
            emojiPack: StickerPackCollectionInfo?,
            changes: Changes
        ) {
            self.nameColor = nameColor
            self.profileColor = profileColor
            self.replyFileId = replyFileId
            self.backgroundFileId = backgroundFileId
            self.emojiStatus = emojiStatus
            self.wallpaper = wallpaper
            self.emojiPack = emojiPack
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
        private let navigationTitle = ComponentView<Empty>()
        
        private let previewSection = ComponentView<Empty>()
        private let boostSection = ComponentView<Empty>()
        private let bannerSection = ComponentView<Empty>()
        private let replySection = ComponentView<Empty>()
        private let wallpaperSection = ComponentView<Empty>()
        private let resetColorSection = ComponentView<Empty>()
        private let emojiStatusSection = ComponentView<Empty>()
        private let emojiPackSection = ComponentView<Empty>()
        private let stickerPackSection = ComponentView<Empty>()
                
        private var isUpdating: Bool = false
        
        private var component: ChannelAppearanceScreenComponent?
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
        private var updatedPeerWallpaper: WallpaperSelectionResult?
        private var updatedPeerEmojiPack: StickerPackCollectionInfo??
        private var temporaryPeerWallpaper: TelegramWallpaper?
        
        private var requiredBoostSubject: BoostSubject?
        
        private var currentTheme: PresentationThemeReference?
        private var resolvedCurrentTheme: (reference: PresentationThemeReference, isDark: Bool, theme: PresentationTheme, wallpaper: TelegramWallpaper?)?
        private var resolvingCurrentTheme: (reference: PresentationThemeReference, isDark: Bool, disposable: Disposable)?
        
        private var premiumConfiguration: PremiumConfiguration?
        private var boostLevel: Int?
        private var boostStatus: ChannelBoostStatus?
        private var myBoostStatus: MyBoostStatus?
        private var boostStatusDisposable: Disposable?
        
        private var isApplyingSettings: Bool = false
        private var applyDisposable: Disposable?
        
        private weak var emojiStatusSelectionController: ViewController?
        
        override init(frame: CGRect) {
            self.scrollView = ScrollView()
            self.scrollView.showsVerticalScrollIndicator = true
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
            self.boostStatusDisposable?.dispose()
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
                if let premiumConfiguration = self.premiumConfiguration, let requiredBoostSubject = self.requiredBoostSubject {
                    let requiredLevel = requiredBoostSubject.requiredLevel(group: self.isGroup, context: component.context, configuration: premiumConfiguration)
                    if let boostLevel = self.boostLevel, requiredLevel > boostLevel {
                        return true
                    }
                }
                
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
                transition.setAlpha(layer: navigationBar.backgroundNode.layer, alpha: navigationAlpha)
                transition.setAlpha(layer: navigationBar.stripeNode.layer, alpha: navigationAlpha)
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
            
            if let navigationTitleView = self.navigationTitle.view {
                transition.setAlpha(view: navigationTitleView, alpha: navigationAlpha)
            }
            
            let bottomNavigationAlphaDistance: CGFloat = 16.0
            let bottomNavigationAlpha: CGFloat = max(0.0, min(1.0, (self.scrollView.contentSize.height - self.scrollView.bounds.maxY) / bottomNavigationAlphaDistance))
            
            transition.setAlpha(view: self.bottomPanelBackgroundView, alpha: bottomNavigationAlpha)
            transition.setAlpha(layer: self.bottomPanelSeparator, alpha: bottomNavigationAlpha)
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
            
            let emojiPack: StickerPackCollectionInfo?
            if case let .some(value) = self.updatedPeerEmojiPack {
                emojiPack = value
            } else {
                emojiPack = contentsData.peerEmojiPack
            }
            if emojiPack != contentsData.peerEmojiPack {
                changes.insert(.emojiPack)
            }
            
            let wallpaper: TelegramWallpaper?
            if let updatedPeerWallpaper = self.updatedPeerWallpaper {
                switch updatedPeerWallpaper {
                case .remove:
                    wallpaper = nil
                case let .emoticon(emoticon):
                    wallpaper = .emoticon(emoticon)
                case .custom:
                    wallpaper = self.temporaryPeerWallpaper
                }
                changes.insert(.wallpaper)
            } else {
                wallpaper = contentsData.peerWallpaper
            }
            
            return ResolvedState(
                nameColor: nameColor,
                profileColor: profileColor,
                replyFileId: replyFileId,
                backgroundFileId: backgroundFileId,
                emojiStatus: emojiStatus,
                wallpaper: wallpaper,
                emojiPack: emojiPack,
                changes: changes
            )
        }
        
        private func applySettings() {
            guard let component = self.component, let resolvedState = self.resolveState(), let premiumConfiguration = self.premiumConfiguration, let requiredBoostSubject = self.requiredBoostSubject else {
                return
            }
            if self.isApplyingSettings {
                return
            }
            if resolvedState.changes.isEmpty {
                self.environment?.controller()?.dismiss()
                return
            }
            
            let requiredLevel = requiredBoostSubject.requiredLevel(group: self.isGroup, context: component.context, configuration: premiumConfiguration)
            if let boostLevel = self.boostLevel, requiredLevel > boostLevel {
                self.displayBoostLevels(subject: requiredBoostSubject)
                return
            }
                        
            self.isApplyingSettings = true
            self.state?.updated(transition: .immediate)
            
            self.applyDisposable?.dispose()
            
            let statusFileId = resolvedState.emojiStatus?.fileId
            
            enum ApplyError {
                case generic
            }
            
            var signals: [Signal<Never, ApplyError>] = []
            if !resolvedState.changes.intersection([.nameColor, .replyFileId]).isEmpty {
                signals.append(component.context.engine.peers.updatePeerNameColor(peerId: component.peerId, nameColor: resolvedState.nameColor, backgroundEmojiId: resolvedState.replyFileId)
                |> ignoreValues
                |> mapError { _ -> ApplyError in
                    return .generic
                })
            }
            if !resolvedState.changes.intersection([.profileColor, .backgroundFileId]).isEmpty {
                signals.append(component.context.engine.peers.updatePeerProfileColor(peerId: component.peerId, profileColor: resolvedState.profileColor, profileBackgroundEmojiId: resolvedState.backgroundFileId)
                |> ignoreValues
                |> mapError { _ -> ApplyError in
                    return .generic
                })
            }
            if resolvedState.changes.contains(.emojiStatus) {
                signals.append(component.context.engine.peers.updatePeerEmojiStatus(peerId: component.peerId, fileId: statusFileId, expirationDate: nil)
                |> ignoreValues
                |> mapError { _ -> ApplyError in
                    return .generic
                })
            }
            if resolvedState.changes.contains(.emojiPack) {
                signals.append(component.context.engine.peers.updateGroupSpecificEmojiset(peerId: component.peerId, info: resolvedState.emojiPack)
                |> ignoreValues
                |> mapError { _ -> ApplyError in
                    return .generic
                })
            }
            if resolvedState.changes.contains(.wallpaper) {
                if let updatedPeerWallpaper {
                    switch updatedPeerWallpaper {
                    case .remove:
                        signals.append(component.context.engine.themes.setChatWallpaper(peerId: component.peerId, wallpaper: nil, forBoth: false)
                        |> ignoreValues
                        |> mapError { _ -> ApplyError in
                            return .generic
                        })
                    case let .emoticon(emoticon):
                        signals.append(component.context.engine.themes.setChatWallpaper(peerId: component.peerId, wallpaper: .emoticon(emoticon), forBoth: false)
                        |> ignoreValues
                        |> mapError { _ -> ApplyError in
                            return .generic
                        })
                    case let .custom(wallpaperEntry, options, editedImage, cropRect, brightness):
                        uploadCustomPeerWallpaper(context: component.context, wallpaper: wallpaperEntry, mode: options, editedImage: editedImage, cropRect: cropRect, brightness: brightness, peerId: component.peerId, forBoth: false, completion: {})
                    }
                }
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
                    let tipController = UndoOverlayController(presentationData: presentationData, content: .actionSucceeded(title: nil, text: presentationData.strings.Channel_Appearance_ToastAppliedText, cancel: nil, destructive: false), elevatedLayout: false, position: .bottom, animateInAsReplacement: false, action: { _ in return false })
                    lastController.present(tipController, in: .window(.root))
                }
            })
        }
        
        private func displayBoostLevels(subject: BoostSubject?) {
            guard let component = self.component, let status = self.boostStatus else {
                return
            }
            
            let controller = PremiumBoostLevelsScreen(
                context: component.context,
                peerId: component.peerId,
                mode: .owner(subject: subject),
                status: status,
                myBoostStatus: myBoostStatus,
                openStats: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.openBoostStats()
                },
                openGift: { [weak self] in
                    guard let self, let component = self.component else {
                        return
                    }
                    let controller = createGiveawayController(context: component.context, peerId: component.peerId, subject: .generic)
                    self.environment?.controller()?.push(controller)
                }
            )
            controller.boostStatusUpdated = { [weak self] boostStatus, myBoostStatus in
                if let self {
                    self.boostStatus = boostStatus
                    self.boostLevel = boostStatus.level
                    self.myBoostStatus = myBoostStatus
                    self.state?.updated(transition: .immediate)
                }
            }
            self.environment?.controller()?.push(controller)
            
            HapticFeedback().impact(.light)
        }
        
        private func openBoostStats() {
            guard let component = self.component, let boostStatus = self.boostStatus else {
                return
            }
            let statsController = component.context.sharedContext.makeChannelStatsController(context: component.context, updatedPresentationData: nil, peerId: component.peerId, boosts: true, boostStatus: boostStatus)
            self.environment?.controller()?.push(statsController)
        }
        
        private func openCustomWallpaperSetup() {
            guard let component = self.component, let contentsData = self.contentsData, let peer = contentsData.peer, let premiumConfiguration = self.premiumConfiguration, let boostStatus = self.boostStatus else {
                return
            }
            
            let level = boostStatus.level
            let requiredCustomWallpaperLevel = Int(BoostSubject.customWallpaper.requiredLevel(group: self.isGroup, context: component.context, configuration: premiumConfiguration))
            
            let controller = MediaPickerScreenImpl(context: component.context, peer: nil, threadTitle: nil, chatLocation: nil, bannedSendPhotos: nil, bannedSendVideos: nil, subject: .assets(nil, .wallpaper))
            controller.customSelection = { [weak self] _, asset in
                guard let self, let asset = asset as? PHAsset else {
                    return
                }
                let controller = WallpaperGalleryController(context: component.context, source: .asset(asset), mode: .peer(peer, false))
                controller.requiredLevel = level < requiredCustomWallpaperLevel ? requiredCustomWallpaperLevel : nil
                controller.apply = { [weak self] wallpaperEntry, options, editedImage, cropRect, brightness, _ in
                    if let self {
                        self.updatedPeerWallpaper = .custom(wallpaperEntry: wallpaperEntry, options: options, editedImage: editedImage, cropRect: cropRect, brightness: brightness)
                        
                        let _ = (getTemporaryCustomPeerWallpaper(context: component.context, wallpaper: wallpaperEntry, mode: options, editedImage: editedImage, cropRect: cropRect, brightness: brightness)
                        |> deliverOnMainQueue).startStandalone(next: { [weak self] wallpaper in
                            self?.temporaryPeerWallpaper = wallpaper
                            self?.state?.updated(transition: .immediate)
                        })
                        self.currentTheme = nil
                        self.state?.updated(transition: .immediate)
                        
                        Queue.mainQueue().after(0.15) {
                            if let navigationController = self.environment?.controller()?.navigationController as? NavigationController {
                                var controllers = navigationController.viewControllers.filter({ controller in
                                    if controller is MediaPickerScreen {
                                        return false
                                    }
                                    return true
                                })
                                navigationController.setViewControllers(controllers, animated: false)
                                controllers = navigationController.viewControllers.filter({ controller in
                                    if controller is WallpaperGalleryController {
                                        return false
                                    }
                                    return true
                                })
                                navigationController.setViewControllers(controllers, animated: true)
                            }
                        }
                    }
                }
                self.environment?.controller()?.push(controller)
            }
            self.environment?.controller()?.push(controller)
        }
        
        private func openStickerPackSetup() {
            guard let component = self.component, let environment = self.environment, let contentsData = self.contentsData else {
                return
            }
            
            let controller = groupStickerPackSetupController(context: component.context, peerId: component.peerId, currentPackInfo: contentsData.peerStickerPack)
            environment.controller()?.push(controller)
        }
        
        private func openEmojiPackSetup() {
            guard let component = self.component, let environment = self.environment, let resolvedState = self.resolveState() else {
                return
            }
            let controller = groupStickerPackSetupController(context: component.context, peerId: component.peerId, isEmoji: true, currentPackInfo: resolvedState.emojiPack, completion: { [weak self] emojiPack in
                if let self {
                    self.updatedPeerEmojiPack = emojiPack
                    self.state?.updated(transition: .spring(duration: 0.4))
                }
            })
            environment.controller()?.push(controller)
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
                    guard let self else {
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
        
        func update(component: ChannelAppearanceScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
            
            self.component = component
            self.state = state
            
            if themeUpdated {
                self.backgroundColor = environment.theme.list.blocksBackgroundColor
            }
            
            let premiumConfiguration: PremiumConfiguration
            if let current = self.premiumConfiguration {
                premiumConfiguration = current
            } else {
                premiumConfiguration = PremiumConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
                self.premiumConfiguration = premiumConfiguration
            }

            if self.contentsDataDisposable == nil {
                self.contentsDataDisposable = (ContentsData.get(context: component.context, peerId: component.peerId)
                |> deliverOnMainQueue).start(next: { [weak self] contentsData in
                    guard let self, let component = self.component else {
                        return
                    }
                    if self.contentsData == nil && self.boostStatus == nil {
                        if let boostStatus = component.boostStatus {
                            self.boostStatus = boostStatus
                            self.boostLevel = boostStatus.level
                        } else if case let .channel(channel) = contentsData.peer {
                            self.boostLevel = channel.approximateBoostLevel.flatMap(Int.init)
                        }
                    }
                    if self.contentsData == nil, let peerWallpaper = contentsData.peerWallpaper {
                        for cloudTheme in contentsData.availableThemes {
                            if case let .emoticon(emoticon) = peerWallpaper, cloudTheme.emoticon?.strippedEmoji == emoticon.strippedEmoji {
                                self.currentTheme = .cloud(PresentationCloudTheme(theme: cloudTheme, resolvedWallpaper: nil, creatorAccountId: cloudTheme.isCreator ? component.context.account.id : nil))
                                break
                            }
                        }
                    }
                    self.contentsData = contentsData
                    
                    if !self.isUpdating {
                        self.state?.updated(transition: .immediate)
                    }
                    self.isReady.set(true)
                })
            }
            if self.boostStatusDisposable == nil {
                self.boostStatusDisposable = combineLatest(queue: Queue.mainQueue(),
                    component.context.engine.peers.getChannelBoostStatus(peerId: component.peerId),
                    component.context.engine.peers.getMyBoostStatus()
                ).start(next: { [weak self] boostStatus, myBoostStatus in
                    guard let self else {
                        return
                    }
                    self.boostLevel = boostStatus?.level
                    self.boostStatus = boostStatus
                    self.myBoostStatus = myBoostStatus
                    
                    if !self.isUpdating {
                        self.state?.updated(transition: .immediate)
                    }
                })
            }
            
            guard let contentsData = self.contentsData, var peer = contentsData.peer, let resolvedState = self.resolveState() else {
                return availableSize
            }
            
            let isGroup = self.isGroup
            
            var requiredBoostSubjects: [BoostSubject] = []
            if !isGroup {
                requiredBoostSubjects.append(.nameColors(colors: resolvedState.nameColor))
            }
            let replyFileId = resolvedState.replyFileId
            if replyFileId != nil {
                requiredBoostSubjects.append(.nameIcon)
            }
            
            let profileColor = resolvedState.profileColor
            if let profileColor {
                requiredBoostSubjects.append(.profileColors(colors: profileColor))
            }
            
            let backgroundFileId = resolvedState.backgroundFileId
            if backgroundFileId != nil {
                requiredBoostSubjects.append(.profileIcon)
            }
            
            let emojiStatus = resolvedState.emojiStatus
            if emojiStatus != nil {
                requiredBoostSubjects.append(.emojiStatus)
            }
            
            let emojiPack = resolvedState.emojiPack
            if emojiPack != nil {
                requiredBoostSubjects.append(.emojiPack)
            }
            
            let statusFileId = emojiStatus?.fileId
            
            let cloudThemes: [PresentationThemeReference] = contentsData.availableThemes.map { .cloud(PresentationCloudTheme(theme: $0, resolvedWallpaper: nil, creatorAccountId: $0.isCreator ? component.context.account.id : nil)) }
            let chatThemes = cloudThemes.filter { $0.emoticon != nil }
                        
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
                    if let temporaryPeerWallpaper = self.temporaryPeerWallpaper {
                        resolvedWallpaper = .single(temporaryPeerWallpaper)
                    } else if case let .file(file) = presentationTheme.chat.defaultWallpaper, file.id == 0 {
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
            
            if let wallpaper = resolvedState.wallpaper {
                if wallpaper.isEmoticon {
                    requiredBoostSubjects.append(.wallpaper)
                } else {
                    requiredBoostSubjects.append(.customWallpaper)
                }
            }
            
            if case let .user(user) = peer {
                peer = .user(user
                    .withUpdatedNameColor(resolvedState.nameColor)
                    .withUpdatedProfileColor(profileColor)
                    .withUpdatedEmojiStatus(emojiStatus)
                    .withUpdatedBackgroundEmojiId(replyFileId)
                    .withUpdatedProfileBackgroundEmojiId(backgroundFileId)
                )
            } else if case let .channel(channel) = peer {
                peer = .channel(channel
                    .withUpdatedNameColor(resolvedState.nameColor)
                    .withUpdatedProfileColor(profileColor)
                    .withUpdatedEmojiStatus(emojiStatus)
                    .withUpdatedBackgroundEmojiId(replyFileId)
                    .withUpdatedProfileBackgroundEmojiId(backgroundFileId)
                )
            }
            
            let replyIconLevel = Int(BoostSubject.nameIcon.requiredLevel(group: isGroup, context: component.context, configuration: premiumConfiguration))
            let profileIconLevel = Int(BoostSubject.profileIcon.requiredLevel(group: isGroup, context: component.context, configuration: premiumConfiguration))
            let emojiStatusLevel = Int(BoostSubject.emojiStatus.requiredLevel(group: isGroup, context: component.context, configuration: premiumConfiguration))
            let emojiPackLevel = Int(BoostSubject.emojiPack.requiredLevel(group: isGroup, context: component.context, configuration: premiumConfiguration))
            let customWallpaperLevel = Int(BoostSubject.customWallpaper.requiredLevel(group: isGroup, context: component.context, configuration: premiumConfiguration))
            
            let requiredBoostSubject: BoostSubject
            if let maxBoostSubject = requiredBoostSubjects.max(by: { $0.requiredLevel(group: isGroup, context: component.context, configuration: premiumConfiguration) < $1.requiredLevel(group: isGroup, context: component.context, configuration: premiumConfiguration) }) {
                requiredBoostSubject = maxBoostSubject
            } else {
                requiredBoostSubject = .nameColors(colors: resolvedState.nameColor)
            }
            self.requiredBoostSubject = requiredBoostSubject
            
            
            let headerColor: UIColor
            if let profileColor {
                let headerBackgroundColors = component.context.peerNameColors.getProfile(profileColor, dark: environment.theme.overallDarkAppearance, subject: .background)
                headerColor = headerBackgroundColors.secondary ?? headerBackgroundColors.main
            } else {
                headerColor = .clear
            }
            self.topOverscrollLayer.backgroundColor = headerColor.cgColor
            
            let backSize = self.backButton.update(key: .back, presentationData: component.context.sharedContext.currentPresentationData.with { $0 }, height: 44.0)
            var scrolledUp = self.scrolledUp
            if profileColor == nil {
                scrolledUp = false
            }
            
            if let controller = self.environment?.controller() as? ChannelAppearanceScreen {
                controller.statusBar.updateStatusBarStyle(scrolledUp ? .White : .Ignore, animated: true)
            }

            self.backButton.updateContentsColor(backgroundColor: scrolledUp ? UIColor(white: 0.0, alpha: 0.1) : .clear, contentsColor: scrolledUp ? .white : environment.theme.rootController.navigationBar.accentTextColor, canBeExpanded: !scrolledUp, transition: .animated(duration: 0.2, curve: .easeInOut))
            self.backButton.frame = CGRect(origin: CGPoint(x: environment.safeInsets.left + 16.0, y: environment.navigationHeight - 44.0), size: backSize)
            if self.backButton.view.superview == nil {
                if let controller = self.environment?.controller(), let navigationBar = controller.navigationBar {
                    navigationBar.view.addSubview(self.backButton.view)
                }
            }
            
            let navigationTitleSize = self.navigationTitle.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: environment.strings.Channel_Appearance_Title, font: Font.semibold(17.0), textColor: environment.theme.rootController.navigationBar.primaryTextColor)),
                    horizontalAlignment: .center
                )),
                environment: {},
                containerSize: availableSize
            )
            let navigationTitleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - navigationTitleSize.width) / 2.0), y: environment.statusBarHeight + floor((environment.navigationHeight - environment.statusBarHeight - navigationTitleSize.height) / 2.0)), size: navigationTitleSize)
            if let navigationTitleView = self.navigationTitle.view {
                if navigationTitleView.superview == nil {
                    if let controller = self.environment?.controller(), let navigationBar = controller.navigationBar {
                        navigationBar.view.addSubview(navigationTitleView)
                    }
                }
                transition.setFrame(view: navigationTitleView, frame: navigationTitleFrame)
            }
            
            let bottomContentInset: CGFloat = 24.0
            let bottomInset: CGFloat = 8.0
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let sectionSpacing: CGFloat = 32.0
            
            let listItemParams = ListViewItemLayoutParams(width: availableSize.width - sideInset * 2.0, leftInset: 0.0, rightInset: 0.0, availableHeight: 10000.0, isStandalone: true)
            
            var contentHeight: CGFloat = 0.0
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                        
            let previewSectionSize = self.previewSection.update(
                transition: transition,
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
                                subtitleString: contentsData.subscriberCount.flatMap {
                                    isGroup ? environment.strings.Conversation_StatusMembers(Int32($0)) : environment.strings.Conversation_StatusSubscribers(Int32($0))
                                },
                                files: self.cachedIconFiles,
                                nameDisplayOrder: presentationData.nameDisplayOrder,
                                showBackground: false
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
                    self.scrollView.addSubview(previewSectionView)
                }
                transition.setFrame(view: previewSectionView, frame: previewSectionFrame)
            }
            contentHeight += previewSectionSize.height
            contentHeight += sectionSpacing - 15.0
            
            var boostContents: [AnyComponentWithIdentity<Empty>] = []
            boostContents.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(BundleIconComponent(
                name: "Premium/Boost",
                tintColor: environment.theme.list.itemAccentColor
            ))))
            boostContents.append(AnyComponentWithIdentity(id: 1, component: AnyComponent(MultilineTextComponent(
                text: .markdown(
                    text: isGroup ? environment.strings.Group_Appearance_BoostInfo : environment.strings.Channel_Appearance_BoostInfo,
                    attributes: MarkdownAttributes(
                        body: MarkdownAttributeSet(font: Font.regular(presentationData.listsFontSize.baseDisplaySize / 17.0 * 14.0), textColor: environment.theme.list.itemPrimaryTextColor),
                        bold: MarkdownAttributeSet(font: Font.semibold(presentationData.listsFontSize.baseDisplaySize / 17.0 * 14.0), textColor: environment.theme.list.itemPrimaryTextColor),
                        link: MarkdownAttributeSet(font: Font.regular(presentationData.listsFontSize.baseDisplaySize / 17.0 * 14.0), textColor: environment.theme.list.itemAccentColor),
                        linkAttribute: { _ in
                            return nil
                        }
                    )
                ),
                maximumNumberOfLines: 0
            ))))
            let boostSectionSize = self.boostSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    background: .all,
                    header: nil,
                    footer: nil,
                    items: [
                        AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                            theme: environment.theme,
                            title: AnyComponent(HStack(boostContents, spacing: 12.0)),
                            icon: nil,
                            action: { [weak self] _ in
                                self?.displayBoostLevels(subject: nil)
                            }
                        )))
                    ],
                    displaySeparators: false,
                    extendsItemHighlightToSection: true
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            let boostSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: boostSectionSize)
            if let boostSectionView = self.boostSection.view {
                if boostSectionView.superview == nil {
                    self.scrollView.addSubview(boostSectionView)
                }
                transition.setFrame(view: boostSectionView, frame: boostSectionFrame)
            }
            contentHeight += boostSectionSize.height
            contentHeight += sectionSpacing - 8.0
            
            var profileLogoContents: [AnyComponentWithIdentity<Empty>] = []
            profileLogoContents.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(
                    string: environment.strings.Channel_Appearance_ProfileIcon,
                    font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                    textColor: environment.theme.list.itemPrimaryTextColor
                )),
                maximumNumberOfLines: 0
            ))))
            if let boostLevel = self.boostLevel, boostLevel < (isGroup ? premiumConfiguration.minGroupProfileIconLevel : premiumConfiguration.minChannelProfileIconLevel) {
                profileLogoContents.append(AnyComponentWithIdentity(id: 1, component: AnyComponent(BoostLevelIconComponent(
                    strings: environment.strings,
                    level: profileIconLevel
                ))))
            }
            let bannerSectionSize = self.bannerSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    background: .all,
                    header: nil,
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: isGroup ? environment.strings.Group_Appearance_ProfileFooter : environment.strings.Channel_Appearance_ProfileFooter,
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    items: [
                        AnyComponentWithIdentity(id: 1, component: AnyComponent(ListItemComponentAdaptor(
                            itemGenerator: PeerNameColorItem(
                                theme: environment.theme,
                                colors: component.context.peerNameColors,
                                mode: .profile,
                                currentColor: profileColor,
                                updated: { [weak self] value in
                                    guard let self, let value else {
                                        return
                                    }
                                    self.updatedPeerProfileColor = value
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
                                color: profileColor.flatMap { profileColor in
                                    component.context.peerNameColors.getProfile(profileColor, dark: environment.theme.overallDarkAppearance, subject: .palette).main
                                } ?? environment.theme.list.itemAccentColor,
                                fileId: backgroundFileId,
                                file: backgroundFileId.flatMap { self.cachedIconFiles[$0] }
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
                    displaySeparators: false,
                    extendsItemHighlightToSection: true
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            let bannerSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: bannerSectionSize)
            if let bannerSectionView = self.bannerSection.view {
                if bannerSectionView.superview == nil {
                    self.scrollView.addSubview(bannerSectionView)
                }
                transition.setFrame(view: bannerSectionView, frame: bannerSectionFrame)
            }
            contentHeight += bannerSectionSize.height
            contentHeight += sectionSpacing
                        
            let resetColorSectionSize = self.resetColorSection.update(
                transition: transition,
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
                                guard let self else {
                                    return
                                }
                                
                                self.updatedPeerProfileColor = .some(nil)
                                self.updatedPeerProfileEmoji = .some(nil)
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
            
            let displayResetProfileColor = profileColor != nil || backgroundFileId != nil
            
            let resetColorSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: resetColorSectionSize)
            if let resetColorSectionView = self.resetColorSection.view {
                if resetColorSectionView.superview == nil {
                    self.scrollView.addSubview(resetColorSectionView)
                }
                transition.setPosition(view: resetColorSectionView, position: resetColorSectionFrame.center)
                transition.setBounds(view: resetColorSectionView, bounds: CGRect(origin: CGPoint(), size: resetColorSectionFrame.size))
                transition.setScale(view: resetColorSectionView, scale: displayResetProfileColor ? 1.0 : 0.001)
                transition.setAlpha(view: resetColorSectionView, alpha: displayResetProfileColor ? 1.0 : 0.0)
            }
            if displayResetProfileColor {
                contentHeight += resetColorSectionSize.height
                contentHeight += sectionSpacing
            }
            
            if isGroup {
                var emojiPackContents: [AnyComponentWithIdentity<Empty>] = []
                emojiPackContents.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: environment.strings.Group_Appearance_GroupEmoji,
                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                        textColor: environment.theme.list.itemPrimaryTextColor
                    )),
                    maximumNumberOfLines: 0
                ))))
                if let boostLevel = self.boostLevel, boostLevel < premiumConfiguration.minGroupEmojiPackLevel {
                    emojiPackContents.append(AnyComponentWithIdentity(id: 1, component: AnyComponent(BoostLevelIconComponent(
                        strings: environment.strings,
                        level: emojiPackLevel
                    ))))
                }
                
                var emojiPackFile: TelegramMediaFile?
                if let thumbnail = emojiPack?.thumbnail {
                    emojiPackFile = TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), partialReference: nil, resource: thumbnail.resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: thumbnail.immediateThumbnailData, mimeType: "", size: nil, attributes: [], alternativeRepresentations: [])
                }
                
                let emojiPackSectionSize = self.emojiPackSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: environment.theme,
                        header: nil,
                        footer: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.Group_Appearance_GroupEmojiFooter,
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        items: [
                            AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                                theme: environment.theme,
                                title: AnyComponent(HStack(emojiPackContents, spacing: 6.0)),
                                icon: ListActionItemComponent.Icon(component: AnyComponentWithIdentity(id: 0, component: AnyComponent(EmojiActionIconComponent(
                                    context: component.context,
                                    color: environment.theme.list.itemAccentColor,
                                    fileId: emojiPack?.thumbnailFileId,
                                    file: emojiPackFile
                                )))),
                                action: { [weak self] view in
                                    guard let self, let resolvedState = self.resolveState() else {
                                        return
                                    }
                                    let _ = resolvedState
                                    self.openEmojiPackSetup()
                                }
                            )))
                        ],
                        displaySeparators: false,
                        extendsItemHighlightToSection: true
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
                )
                let emojiPackSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: emojiPackSectionSize)
                if let emojiPackSectionView = self.emojiPackSection.view {
                    if emojiPackSectionView.superview == nil {
                        self.scrollView.addSubview(emojiPackSectionView)
                    }
                    transition.setFrame(view: emojiPackSectionView, frame: emojiPackSectionFrame)
                }
                contentHeight += emojiPackSectionSize.height
                contentHeight += sectionSpacing
            }
            
            var emojiStatusContents: [AnyComponentWithIdentity<Empty>] = []
            emojiStatusContents.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(
                    string: isGroup ? environment.strings.Group_Appearance_Status : environment.strings.Channel_Appearance_Status,
                    font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                    textColor: environment.theme.list.itemPrimaryTextColor
                )),
                maximumNumberOfLines: 0
            ))))
            if let boostLevel = self.boostLevel, boostLevel < (isGroup ? premiumConfiguration.minGroupEmojiStatusLevel : premiumConfiguration.minChannelEmojiStatusLevel) {
                emojiStatusContents.append(AnyComponentWithIdentity(id: 1, component: AnyComponent(BoostLevelIconComponent(
                    strings: environment.strings,
                    level: emojiStatusLevel
                ))))
            }
            let emojiStatusSectionSize = self.emojiStatusSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: nil,
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: isGroup ? environment.strings.Group_Appearance_StatusFooter : environment.strings.Channel_Appearance_StatusFooter,
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    items: [
                        AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                            theme: environment.theme,
                            title: AnyComponent(HStack(emojiStatusContents, spacing: 6.0)),
                            icon: ListActionItemComponent.Icon(component: AnyComponentWithIdentity(id: 0, component: AnyComponent(EmojiActionIconComponent(
                                context: component.context,
                                color: environment.theme.list.itemAccentColor,
                                fileId: statusFileId,
                                file: statusFileId.flatMap { self.cachedIconFiles[$0] }
                            )))),
                            action: { [weak self] view in
                                guard let self, let resolvedState = self.resolveState(), let view = view as? ListActionItemComponent.View, let iconView = view.iconView else {
                                    return
                                }
                                
                                self.openEmojiSetup(sourceView: iconView, currentFileId: resolvedState.emojiStatus?.fileId, color: nil, subject: .status)
                            }
                        )))
                    ],
                    displaySeparators: false,
                    extendsItemHighlightToSection: true
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            let emojiStatusSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: emojiStatusSectionSize)
            if let emojiStatusSectionView = self.emojiStatusSection.view {
                if emojiStatusSectionView.superview == nil {
                    self.scrollView.addSubview(emojiStatusSectionView)
                }
                transition.setFrame(view: emojiStatusSectionView, frame: emojiStatusSectionFrame)
            }
            contentHeight += emojiStatusSectionSize.height
            contentHeight += sectionSpacing
    
            if isGroup && contentsData.canSetStickerPack {
                var stickerPackContents: [AnyComponentWithIdentity<Empty>] = []
                stickerPackContents.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: environment.strings.Stickers_GroupStickers,
                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                        textColor: environment.theme.list.itemPrimaryTextColor
                    )),
                    maximumNumberOfLines: 0
                ))))
                
                var stickerPackFile: TelegramMediaFile?
                if let peerStickerPack = contentsData.peerStickerPack, let thumbnail = peerStickerPack.thumbnail {
                    stickerPackFile = TelegramMediaFile(fileId: MediaId(namespace: 0, id: peerStickerPack.id.id), partialReference: nil, resource: thumbnail.resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: thumbnail.immediateThumbnailData, mimeType: "", size: nil, attributes: [], alternativeRepresentations: [])
                }
                
                let stickerPackSectionSize = self.stickerPackSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: environment.theme,
                        header: nil,
                        footer: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.Stickers_GroupStickersHelp,
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        items: [
                            AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                                theme: environment.theme,
                                title: AnyComponent(HStack(stickerPackContents, spacing: 6.0)),
                                icon: ListActionItemComponent.Icon(component: AnyComponentWithIdentity(id: 0, component: AnyComponent(EmojiActionIconComponent(
                                    context: component.context,
                                    color: environment.theme.list.itemAccentColor,
                                    fileId: nil,
                                    file: stickerPackFile
                                )))),
                                action: { [weak self] view in
                                    guard let self else {
                                        return
                                    }
                                    self.openStickerPackSetup()
                                }
                            )))
                        ],
                        displaySeparators: false,
                        extendsItemHighlightToSection: true
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
                )
                let stickerPackSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: stickerPackSectionSize)
                if let stickerPackSectionView = self.stickerPackSection.view {
                    if stickerPackSectionView.superview == nil {
                        self.scrollView.addSubview(stickerPackSectionView)
                    }
                    transition.setFrame(view: stickerPackSectionView, frame: stickerPackSectionFrame)
                }
                contentHeight += stickerPackSectionSize.height
                contentHeight += sectionSpacing
            }
            
            var chatPreviewTheme: PresentationTheme = environment.theme
            var chatPreviewWallpaper: TelegramWallpaper = presentationData.chatWallpaper
            if let updatedWallpaper = self.updatedPeerWallpaper, case .remove = updatedWallpaper {
            } else if let temporaryPeerWallpaper = self.temporaryPeerWallpaper {
                chatPreviewWallpaper = temporaryPeerWallpaper
            } else if let resolvedCurrentTheme = self.resolvedCurrentTheme {
                chatPreviewTheme = resolvedCurrentTheme.theme
                if let wallpaper = resolvedCurrentTheme.wallpaper {
                    chatPreviewWallpaper = wallpaper
                }
            } else if let initialWallpaper = contentsData.peerWallpaper, !initialWallpaper.isEmoticon {
                chatPreviewWallpaper = initialWallpaper
            }
            
            if !isGroup {
                let messageItem = PeerNameColorChatPreviewItem.MessageItem(
                    outgoing: false,
                    peerId: EnginePeer.Id(namespace: peer.id.namespace, id: PeerId.Id._internalFromInt64Value(0)),
                    author: peer.compactDisplayTitle,
                    photo: peer.profileImageRepresentations,
                    nameColor: resolvedState.nameColor,
                    backgroundEmojiId: replyFileId,
                    reply: (peer.compactDisplayTitle, environment.strings.Channel_Appearance_ExampleReplyText, resolvedState.nameColor),
                    linkPreview: (environment.strings.Channel_Appearance_ExampleLinkWebsite, environment.strings.Channel_Appearance_ExampleLinkTitle, environment.strings.Channel_Appearance_ExampleLinkText),
                    text: environment.strings.Channel_Appearance_ExampleText
                )
                
                var replyLogoContents: [AnyComponentWithIdentity<Empty>] = []
                replyLogoContents.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: environment.strings.Channel_Appearance_NameIcon,
                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                        textColor: environment.theme.list.itemPrimaryTextColor
                    )),
                    maximumNumberOfLines: 0
                ))))
                if let boostLevel = self.boostLevel, boostLevel < premiumConfiguration.minChannelNameIconLevel {
                    replyLogoContents.append(AnyComponentWithIdentity(id: 1, component: AnyComponent(BoostLevelIconComponent(
                        strings: environment.strings,
                        level: replyIconLevel
                    ))))
                }
                                
                let replySectionSize = self.replySection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: environment.theme,
                        header: nil,
                        footer: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.Channel_Appearance_NameColorFooter,
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
                                    fileId: replyFileId,
                                    file: replyFileId.flatMap { self.cachedIconFiles[$0] }
                                )))),
                                action: { [weak self] view in
                                    guard let self, let resolvedState = self.resolveState(), let view = view as? ListActionItemComponent.View, let iconView = view.iconView else {
                                        return
                                    }
                                    
                                    self.openEmojiSetup(sourceView: iconView, currentFileId: resolvedState.replyFileId, color: component.context.peerNameColors.get(resolvedState.nameColor, dark: environment.theme.overallDarkAppearance).main, subject: .reply)
                                }
                            )))
                        ],
                        displaySeparators: false,
                        extendsItemHighlightToSection: true
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
                )
                let replySectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: replySectionSize)
                if let replySectionView = self.replySection.view {
                    if replySectionView.superview == nil {
                        self.scrollView.addSubview(replySectionView)
                    }
                    transition.setFrame(view: replySectionView, frame: replySectionFrame)
                }
                contentHeight += replySectionSize.height
                contentHeight += sectionSpacing
            }
            
            if !chatThemes.isEmpty {
                var wallpaperLogoContents: [AnyComponentWithIdentity<Empty>] = []
                wallpaperLogoContents.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: environment.strings.Group_Appearance_ChooseFromGallery,
                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                        textColor: environment.theme.list.itemPrimaryTextColor
                    )),
                    maximumNumberOfLines: 0
                ))))
                if let boostLevel = self.boostLevel, boostLevel < (isGroup ? premiumConfiguration.minGroupCustomWallpaperLevel : premiumConfiguration.minChannelCustomWallpaperLevel) {
                    wallpaperLogoContents.append(AnyComponentWithIdentity(id: 1, component: AnyComponent(BoostLevelIconComponent(
                        strings: environment.strings,
                        level: customWallpaperLevel
                    ))))
                }
                
                var currentTheme = self.currentTheme
                var selectedWallpaper: TelegramWallpaper?
                if currentTheme == nil, let wallpaper = resolvedState.wallpaper, !wallpaper.isEmoticon {
                    let theme: PresentationThemeReference = .builtin(.day)
                    currentTheme = theme
                    selectedWallpaper = wallpaper
                }
                
                var wallpaperItems: [AnyComponentWithIdentity<Empty>] = []
                if isGroup {
                    let incomingMessageItem = PeerNameColorChatPreviewItem.MessageItem(
                        outgoing: false,
                        peerId: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(0)),
                        author: environment.strings.Group_Appearance_PreviewAuthor,
                        photo: [],
                        nameColor: .red,
                        backgroundEmojiId: 5301072507598550489,
                        reply: (environment.strings.Appearance_PreviewReplyAuthor, environment.strings.Appearance_PreviewReplyText, .violet),
                        linkPreview: nil,
                        text: environment.strings.Appearance_PreviewIncomingText
                    )
                    
                    let outgoingMessageItem = PeerNameColorChatPreviewItem.MessageItem(
                        outgoing: true,
                        peerId: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1)),
                        author: peer.compactDisplayTitle,
                        photo: peer.profileImageRepresentations,
                        nameColor: .blue,
                        backgroundEmojiId: nil,
                        reply: nil,
                        linkPreview: nil,
                        text: environment.strings.Appearance_PreviewOutgoingText
                    )
                    
                    wallpaperItems.append(
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
                                messageItems: [incomingMessageItem, outgoingMessageItem]
                            ),
                            params: listItemParams
                        )))
                    )
                }
                wallpaperItems.append(
                    AnyComponentWithIdentity(id: 1, component: AnyComponent(ListItemComponentAdaptor(
                        itemGenerator: ThemeCarouselThemeItem(
                            context: component.context,
                            theme: environment.theme,
                            strings: environment.strings,
                            sectionId: 0,
                            themes: chatThemes,
                            hasNoTheme: true,
                            animatedEmojiStickers: component.context.animatedEmojiStickersValue,
                            themeSpecificAccentColors: [:],
                            themeSpecificChatWallpapers: [:],
                            nightMode: environment.theme.overallDarkAppearance,
                            channelMode: true,
                            selectedWallpaper: selectedWallpaper,
                            currentTheme: currentTheme,
                            updatedTheme: { [weak self] value in
                                guard let self, value != .builtin(.day) else {
                                    return
                                }
                                self.currentTheme = value
                                self.temporaryPeerWallpaper = nil
                                if let value {
                                    self.updatedPeerWallpaper = .emoticon(value.emoticon ?? "")
                                } else {
                                    self.updatedPeerWallpaper = .remove
                                }
                                self.state?.updated(transition: .spring(duration: 0.4))
                            },
                            contextAction: nil
                        ),
                        params: listItemParams
                    )))
                )
                
                wallpaperItems.append(
                    AnyComponentWithIdentity(id: 2, component: AnyComponent(ListActionItemComponent(
                        theme: environment.theme,
                        title: AnyComponent(HStack(wallpaperLogoContents, spacing: 6.0)),
                        icon: nil,
                        action: { [weak self] view in
                            guard let self else {
                                return
                            }
                            self.openCustomWallpaperSetup()
                        }
                    )))
                )
                
                let wallpaperSectionSize = self.wallpaperSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: environment.theme,
                        header: nil,
                        footer: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: isGroup ? environment.strings.Group_Appearance_WallpaperFooter : environment.strings.Channel_Appearance_WallpaperFooter,
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        items: wallpaperItems,
                        displaySeparators: false,
                        extendsItemHighlightToSection: true
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
                )
                let wallpaperSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: wallpaperSectionSize)
                if let wallpaperSectionView = self.wallpaperSection.view {
                    if wallpaperSectionView.superview == nil {
                        self.scrollView.addSubview(wallpaperSectionView)
                    }
                    transition.setFrame(view: wallpaperSectionView, frame: wallpaperSectionFrame)
                }
                contentHeight += wallpaperSectionSize.height
                contentHeight += sectionSpacing
            }
                        
            contentHeight += bottomContentInset
            
            var buttonContents: [AnyComponentWithIdentity<Empty>] = []
            buttonContents.append(AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(
                Text(text: environment.strings.Channel_Appearance_ApplyButton, font: Font.semibold(17.0), color: environment.theme.list.itemCheckColors.foregroundColor)
            )))
            
            let requiredLevel = requiredBoostSubject.requiredLevel(group: isGroup, context: component.context, configuration: premiumConfiguration)
            if let boostLevel = self.boostLevel, requiredLevel > boostLevel && !resolvedState.changes.isEmpty {
                buttonContents.append(AnyComponentWithIdentity(id: AnyHashable(1 as Int), component: AnyComponent(PremiumLockButtonSubtitleComponent(
                    count: Int(requiredLevel),
                    theme: environment.theme,
                    strings: environment.strings
                ))))
            }
            
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

public class ChannelAppearanceScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    
    private var didSetReady: Bool = false
    
    public init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?,
        peerId: EnginePeer.Id,
        boostStatus: ChannelBoostStatus?
    ) {
        self.context = context
        
        super.init(context: context, component: ChannelAppearanceScreenComponent(
            context: context,
            peerId: peerId,
            boostStatus: boostStatus
        ), navigationBarAppearance: .default, theme: .default, updatedPresentationData: updatedPresentationData)
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.title = ""
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
        
        self.ready.set(.never())
        
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? ChannelAppearanceScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
        
        self.attemptNavigation = { [weak self] complete in
            guard let self, let componentView = self.node.hostView.componentView as? ChannelAppearanceScreenComponent.View else {
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
        
        if let componentView = self.node.hostView.componentView as? ChannelAppearanceScreenComponent.View {
            if !self.didSetReady {
                self.didSetReady = true
                self.ready.set(componentView.isReady.get())
            }
        }
    }
}
