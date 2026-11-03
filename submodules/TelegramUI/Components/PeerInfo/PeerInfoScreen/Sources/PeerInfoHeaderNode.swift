import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import AvatarNode
import AccountContext
import SwiftSignalKit
import TelegramPresentationData
import PhotoResources
import PeerAvatarGalleryUI
import TelegramStringFormatting
import PhoneNumberFormat
import ActivityIndicator
import TelegramUniversalVideoContent
import GalleryUI
import UniversalMediaPlayer
import RadialStatusNode
import TelegramUIPreferences
import PeerInfoAvatarListNode
import AnimationUI
import ContextUI
import ManagedAnimationNode
import ComponentFlow
import EmojiStatusComponent
import AnimationCache
import MultiAnimationRenderer
import ComponentDisplayAdapters
import ChatTitleView
import AppBundle
import AvatarVideoNode
import PeerInfoVisualMediaPaneNode
import AvatarStoryIndicatorComponent
import ComponentDisplayAdapters
import ChatAvatarNavigationNode
import MultiScaleTextNode
import PeerInfoCoverComponent
import PeerInfoPaneNode
import MultilineTextComponent
import PeerInfoRatingComponent
import UndoUI
import ProfileLevelInfoScreen
import PlainButtonComponent
import BundleIconComponent
import MarqueeComponent
import EdgeEffect

final class PeerInfoHeaderRegularContentNode: SparseNode {
}

enum PeerInfoHeaderTextFieldNodeKey: Equatable {
    case firstName
    case lastName
    case title
    case description
}

protocol PeerInfoHeaderTextFieldNode: ASDisplayNode {
    var text: String { get }
    
    func update(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, isSettings: Bool, hasPrevious: Bool, hasNext: Bool, placeholder: String, isEnabled: Bool, presentationData: PresentationData, updateText: String?) -> CGFloat
}

let TitleNodeStateRegular = 0
let TitleNodeStateExpanded = 1

final class PeerInfoHeaderNode: ASDisplayNode {
    private var context: AccountContext
    private let isPremiumDisabled: Bool
    private weak var controller: PeerInfoScreenImpl?
    private var presentationData: PresentationData?
    private var state: PeerInfoState?
    private var peer: EnginePeer?
    private var threadData: MessageHistoryThreadData?
    private var isSearching: Bool = false
    private var avatarSize: CGFloat?
    
    private let isOpenedFromChat: Bool
    private let isSettings: Bool
    private let isMyProfile: Bool
    private let videoCallsEnabled: Bool
    private let forumTopicThreadId: Int64?
    private let chatLocation: ChatLocation
    
    private(set) var isAvatarExpanded: Bool
    var skipCollapseCompletion = false
    var ignoreCollapse = false
    
    let avatarClippingNode: SparseNode
    let avatarListNode: PeerInfoAvatarListNode
    
    let backgroundBannerView: UIView
    let backgroundCover = ComponentView<Empty>()
    let giftsCover = ComponentView<Empty>()
    var didSetupBackgroundCover = false
    let buttonsContainerNode: SparseNode
    let buttonsBackgroundNode: NavigationBackgroundNode
    let buttonsMaskView: UIView
    let regularContentNode: PeerInfoHeaderRegularContentNode
    let editingContentNode: PeerInfoHeaderEditingContentNode
    let avatarOverlayNode: PeerInfoEditingAvatarOverlayNode
    let titleNodeContainer: ASDisplayNode
    let titleNodeRawContainer: ASDisplayNode
    let titleNode: MultiScaleTextNode
    var standardTitle: ComponentView<Empty>?
    
    let titleCredibilityIconView: ComponentHostView<Empty>
    var credibilityIconSize: CGSize?
    let titleExpandedCredibilityIconView: ComponentHostView<Empty>
    var titleExpandedCredibilityIconSize: CGSize?
    
    let titleVerifiedIconView: ComponentHostView<Empty>
    var verifiedIconSize: CGSize?
    let titleExpandedVerifiedIconView: ComponentHostView<Empty>
    var titleExpandedVerifiedIconSize: CGSize?
    
    let titleStatusIconView: ComponentHostView<Empty>
    var statusIconSize: CGSize?
    let titleExpandedStatusIconView: ComponentHostView<Empty>
    var titleExpandedStatusIconSize: CGSize?
    
    var subtitleRating: ComponentView<Empty>?
    
    let subtitleNodeContainer: ASDisplayNode
    let subtitleNodeRawContainer: ASDisplayNode
    let subtitleNode: MultiScaleTextNode
    var subtitleBackgroundNode: ASDisplayNode?
    var subtitleBackgroundButton: HighlightTrackingButtonNode?
    var subtitleArrowNode: ASImageNode?
    var subtitleBadgeView: PeerInfoSubtitleBadgeView?
    let panelSubtitleNode: MultiScaleTextNode
    let usernameNodeContainer: ASDisplayNode
    let usernameNodeRawContainer: ASDisplayNode
    let usernameNode: MultiScaleTextNode
    var actionButtonNodes: [PeerInfoHeaderButtonKey: PeerInfoHeaderActionButtonNode] = [:]
    var buttonNodes: [PeerInfoHeaderButtonKey: PeerInfoHeaderButtonNode] = [:]
    /// The action buttons in their on-screen order.
    var orderedButtonNodes: [PeerInfoHeaderButtonNode] {
        return self.buttonNodes.values.sorted(by: { $0.frame.minX < $1.frame.minX })
    }
    /// The colour the bar's glass is tinted with (the cover's), nil while it is plain: what an expansion's drops tint
    /// toward.
    private(set) var expansionGlassTint: UIColor?
    /// The round avatar's frame in `avatarClippingNode`, also while the photo is expanded (where it would be).
    private(set) var expansionRoundAvatarFrame: CGRect?
    /// What an expansion fades with the list: the header's decorations around the name, which the prototype's header
    /// does not have — those that move with the status (`expansionStatusFollowerViews`), and the music strip and its
    /// platter, which ride the page.
    var expansionDecorationViews: [UIView] {
        var views = self.expansionStatusFollowerViews
        if let view = self.music?.view {
            views.append(view)
        }
        if let view = self.musicBackground {
            views.append(view)
        }
        return views
    }
    /// The header's part of the page an expansion moves with the status, with the list (the prototype's actions and
    /// music island): the buttons' container, which carries the buttons and their blur, whose mask draws the buttons'
    /// platters and the music strip's (a platter moved on its own is clipped at the blur's frame, sized to the buttons'
    /// row), and the music strip.
    var expansionPageViews: [UIView] {
        var views: [UIView] = [self.buttonsContainerNode.view]
        if let view = self.music?.view {
            views.append(view)
        }
        return views
    }
    /// The decorations an expansion moves with the status: the level badge and rating, the username and the balance.
    var expansionStatusFollowerViews: [UIView] {
        var views: [UIView] = [self.usernameNodeContainer.view]
        if let view = self.subtitleBadgeView {
            views.append(view)
        }
        if let view = self.subtitleRating?.view {
            views.append(view)
        }
        if let view = self.walletBalance?.view {
            views.append(view)
        }
        return views
    }
    let headerEdgeEffectContainer: UIView
    let headerEdgeEffectView: EdgeEffectView
    var navigationTitle: String?
    let searchContainer: ASDisplayNode
    var searchEdgeEffectView: EdgeEffectView?
    let searchBarContainer: SparseNode
    let editingEdgeEffectView: EdgeEffectView
    
    var musicBackground: UIView?
    var music: ComponentView<Empty>?
    var walletBalance: ComponentView<Empty>?
    private var walletBalanceCutoutIcon: (color: UIColor, image: UIImage)?
    var hasBottomStrip: Bool {
        return self.music != nil
    }

    /// The track the music strip shows for `peer` and `screenData` (`peerInfoProfileMusic`): none on Settings and on the
    /// account's own peer opened as a profile.
    func profileMusic(peer: EnginePeer?, screenData: PeerInfoScreenData?) -> TelegramMediaFile? {
        guard let peer, peer.id != self.context.account.peerId || self.isMyProfile, let screenData else {
            return nil
        }
        let list = screenData.savedMusicState.map { state -> (files: [TelegramMediaFile], isLoading: Bool) in
            return (state.files, state.dataState == .loading)
        }
        return peerInfoProfileMusic(list: list, fullUserMusic: (screenData.cachedData as? CachedUserData)?.savedMusic)
    }
    
    var performButtonAction: ((PeerInfoHeaderButtonKey, PeerInfoHeaderButtonNode?, ContextGesture?) -> Void)?
    var requestAvatarExpansion: ((Bool, [AvatarGalleryEntry], AvatarGalleryEntry?, (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?) -> Void)?
    var requestOpenAvatarForEditing: ((Bool) -> Void)?
    var cancelUpload: (() -> Void)?
    var requestUpdateLayout: ((Bool) -> Void)?
    var animateOverlaysFadeIn: (() -> Void)?
    var updateUnderHeaderContentsAlpha: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
    
    var displayAvatarContextMenu: ((ASDisplayNode, ContextGesture?) -> Void)?
    var displayCopyContextMenu: ((ASDisplayNode, Bool, Bool) -> Void)?
    var displayEmojiPackTooltip: (() -> Void)?
    
    var displaySavedMusic: (() -> Void)?
    var openWallet: (() -> Void)?
    
    var displayPremiumIntro: ((UIView, PeerEmojiStatus?, Signal<(TelegramMediaFile, LoadedStickerPack)?, NoError>, Bool) -> Void)?
    var displayStatusPremiumIntro: (() -> Void)?
    var displayUniqueGiftInfo: ((UIView, String) -> Void)?
    var openUniqueGift: ((UIView, String) -> Void)?
    
    var navigateToForum: (() -> Void)?
    
    var backgroundAlpha: CGFloat = 1.0
    var updateHeaderAlpha: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
    /// The glass under the bar's buttons, reported on every update; the screen applies a change.
    var updateNavigationGlass: ((PeerInfoNavigationGlass, ContainedViewLayoutTransition) -> Void)?
    /// Whether the header puts something in the bar's row place (its search, a pane's own navigation content).
    var updateNavigationRowHidden: ((Bool, ContainedViewLayoutTransition) -> Void)?
    /// The bar's right buttons in its row, both sets (the title clears them when the header is collapsed).
    var navigationRowRightButtonCount: Int = 0
    
    private(set) var contentButtonBackgroundColor: UIColor?
    
    let animationCache: AnimationCache
    let animationRenderer: MultiAnimationRenderer
    
    var emojiStatusPackDisposable = MetaDisposable()
    var emojiStatusFileAndPackTitle = Promise<(TelegramMediaFile, LoadedStickerPack)?>()
    
    var customNavigationContentNode: PeerInfoPanelNodeNavigationContentNode?
    private var appliedCustomNavigationContentNode: PeerInfoPanelNodeNavigationContentNode?
    
    private var validLayout: (width: CGFloat, statusBarHeight: CGFloat, deviceMetrics: DeviceMetrics)?
    
    private var currentStarRating: TelegramStarRating?
    private var currentPendingStarRating: TelegramStarPendingRating?
    
    init(context: AccountContext, controller: PeerInfoScreenImpl, avatarInitiallyExpanded: Bool, isOpenedFromChat: Bool, isMediaOnly: Bool, isSettings: Bool, isMyProfile: Bool, forumTopicThreadId: Int64?, chatLocation: ChatLocation) {
        self.context = context
        self.controller = controller
        self.isAvatarExpanded = avatarInitiallyExpanded
        self.isOpenedFromChat = isOpenedFromChat
        self.isSettings = isSettings
        self.isMyProfile = isMyProfile
        self.videoCallsEnabled = true
        self.forumTopicThreadId = forumTopicThreadId
        self.chatLocation = chatLocation
        
        let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
        self.isPremiumDisabled = premiumConfiguration.isPremiumDisabled
        
        self.avatarClippingNode = SparseNode()
        self.avatarClippingNode.alpha = 0.996
        self.avatarClippingNode.clipsToBounds = true
        
        self.avatarListNode = PeerInfoAvatarListNode(context: context, readyWhenGalleryLoads: avatarInitiallyExpanded, isSettings: isSettings)
        
        self.titleNodeContainer = ASDisplayNode()
        self.titleNodeRawContainer = ASDisplayNode()
        self.titleNode = MultiScaleTextNode(stateKeys: [TitleNodeStateRegular, TitleNodeStateExpanded])
        self.titleNode.displaysAsynchronously = false
        
        self.titleCredibilityIconView = ComponentHostView<Empty>()
        self.titleNode.stateNode(forKey: TitleNodeStateRegular)?.view.addSubview(self.titleCredibilityIconView)
        
        self.titleExpandedCredibilityIconView = ComponentHostView<Empty>()
        self.titleNode.stateNode(forKey: TitleNodeStateExpanded)?.view.addSubview(self.titleExpandedCredibilityIconView)
        
        self.titleVerifiedIconView = ComponentHostView<Empty>()
        self.titleNode.stateNode(forKey: TitleNodeStateRegular)?.view.addSubview(self.titleVerifiedIconView)
        
        self.titleExpandedVerifiedIconView = ComponentHostView<Empty>()
        self.titleNode.stateNode(forKey: TitleNodeStateExpanded)?.view.addSubview(self.titleExpandedVerifiedIconView)
        
        self.titleStatusIconView = ComponentHostView<Empty>()
        self.titleNode.stateNode(forKey: TitleNodeStateRegular)?.view.addSubview(self.titleStatusIconView)
        
        self.titleExpandedStatusIconView = ComponentHostView<Empty>()
        self.titleNode.stateNode(forKey: TitleNodeStateExpanded)?.view.addSubview(self.titleExpandedStatusIconView)
        
        self.subtitleNodeContainer = ASDisplayNode()
        self.subtitleNodeRawContainer = ASDisplayNode()
        self.subtitleNode = MultiScaleTextNode(stateKeys: [TitleNodeStateRegular, TitleNodeStateExpanded])
        self.subtitleNode.displaysAsynchronously = false

        self.panelSubtitleNode = MultiScaleTextNode(stateKeys: [TitleNodeStateRegular, TitleNodeStateExpanded])
        self.panelSubtitleNode.displaysAsynchronously = false
        
        self.usernameNodeContainer = ASDisplayNode()
        self.usernameNodeRawContainer = ASDisplayNode()
        self.usernameNode = MultiScaleTextNode(stateKeys: [TitleNodeStateRegular, TitleNodeStateExpanded])
        self.usernameNode.displaysAsynchronously = false
        
        self.backgroundBannerView = UIView()
        self.backgroundBannerView.clipsToBounds = true
        self.backgroundBannerView.isUserInteractionEnabled = false
        self.backgroundBannerView.layer.allowsGroupOpacity = true
        
        self.buttonsContainerNode = SparseNode()
        self.buttonsContainerNode.clipsToBounds = true
        
        self.buttonsBackgroundNode = NavigationBackgroundNode(color: .clear, enableBlur: true, enableSaturation: false)
        self.buttonsBackgroundNode.isUserInteractionEnabled = false
        self.buttonsContainerNode.addSubnode(self.buttonsBackgroundNode)
        self.buttonsMaskView = UIView()
        self.buttonsBackgroundNode.view.mask = self.buttonsMaskView
        
        self.regularContentNode = PeerInfoHeaderRegularContentNode()
        var requestUpdateLayoutImpl: (() -> Void)?
        self.editingContentNode = PeerInfoHeaderEditingContentNode(context: context, requestUpdateLayout: {
            requestUpdateLayoutImpl?()
        })
        self.editingContentNode.alpha = 0.0
        
        self.avatarOverlayNode = PeerInfoEditingAvatarOverlayNode(context: context)
        self.avatarOverlayNode.isUserInteractionEnabled = false
        
        self.searchBarContainer = SparseNode()
        self.searchContainer = ASDisplayNode()
        
        self.headerEdgeEffectView = EdgeEffectView()
        self.headerEdgeEffectView.isUserInteractionEnabled = false
        
        self.headerEdgeEffectContainer = UIView()
        self.headerEdgeEffectContainer.addSubview(self.headerEdgeEffectView)
        
        self.editingEdgeEffectView = EdgeEffectView()
        self.editingEdgeEffectView.isUserInteractionEnabled = false
        
        self.animationCache = context.animationCache
        self.animationRenderer = context.animationRenderer
        
        super.init()
                
        requestUpdateLayoutImpl = { [weak self] in
            self?.requestUpdateLayout?(false)
        }
        
        self.view.addSubview(self.backgroundBannerView)
        self.titleNodeContainer.addSubnode(self.titleNode)
        self.subtitleNodeContainer.addSubnode(self.subtitleNode)
        self.subtitleNodeContainer.addSubnode(self.panelSubtitleNode)
        self.usernameNodeContainer.addSubnode(self.usernameNode)

        self.regularContentNode.addSubnode(self.avatarClippingNode)
        self.avatarClippingNode.addSubnode(self.avatarListNode)
        
        self.regularContentNode.addSubnode(self.avatarListNode.listContainerNode.controlsClippingOffsetNode)
        self.regularContentNode.addSubnode(self.titleNodeContainer)
        self.regularContentNode.addSubnode(self.subtitleNodeContainer)
        self.regularContentNode.addSubnode(self.subtitleNodeRawContainer)
        self.regularContentNode.addSubnode(self.usernameNodeContainer)
        self.regularContentNode.addSubnode(self.usernameNodeRawContainer)
        
        self.addSubnode(self.regularContentNode)
        
        if !isMediaOnly {
            self.regularContentNode.addSubnode(self.buttonsContainerNode)
        }
        
        self.addSubnode(self.editingContentNode)
        self.addSubnode(self.avatarOverlayNode)
        self.view.addSubview(self.editingEdgeEffectView)
        
        self.addSubnode(self.searchContainer)
        self.addSubnode(self.searchBarContainer)
        
        self.avatarListNode.avatarContainerNode.tapped = { [weak self] in
            self?.initiateAvatarExpansion(gallery: false, first: false)
        }
        self.avatarListNode.avatarContainerNode.contextAction = { [weak self] node, gesture in
            self?.displayAvatarContextMenu?(node, gesture)
        }
        self.avatarListNode.avatarContainerNode.emojiTapped = { [weak self] in
            self?.displayEmojiPackTooltip?()
        }
        
        self.editingContentNode.avatarNode.tapped = { [weak self] confirm in
            self?.initiateAvatarExpansion(gallery: true, first: true)
        }
        self.editingContentNode.requestEditing = { [weak self] in
            self?.requestOpenAvatarForEditing?(true)
        }
        
        self.avatarListNode.itemsUpdated = { [weak self] items in
            guard let strongSelf = self, let state = strongSelf.state, let peer = strongSelf.peer, let presentationData = strongSelf.presentationData, let avatarSize = strongSelf.avatarSize else {
                return
            }
            strongSelf.editingContentNode.avatarNode.update(peer: peer, threadData: strongSelf.threadData, chatLocation: chatLocation, item: strongSelf.avatarListNode.item, updatingAvatar: state.updatingAvatar, uploadProgress: state.avatarUploadProgress, theme: presentationData.theme, avatarSize: avatarSize, isEditing: state.isEditing)
        }

        self.avatarListNode.animateOverlaysFadeIn = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.avatarListNode.listContainerNode.topShadowNode.layer.animateAlpha(from: 0.0, to: strongSelf.avatarListNode.listContainerNode.topShadowNode.alpha, duration: 0.25)
            
            strongSelf.avatarListNode.listContainerNode.bottomShadowNode.alpha = 1.0
            strongSelf.avatarListNode.listContainerNode.bottomShadowNode.layer.animateAlpha(from: 0.0, to: strongSelf.avatarListNode.listContainerNode.bottomShadowNode.alpha, duration: 0.25)
            strongSelf.avatarListNode.listContainerNode.controlsContainerNode.layer.animateAlpha(from: 0.0, to: strongSelf.avatarListNode.listContainerNode.controlsContainerNode.alpha, duration: 0.25)
            
            strongSelf.titleNode.layer.animateAlpha(from: 0.0, to: strongSelf.titleNode.alpha, duration: 0.25)
            strongSelf.subtitleNode.layer.animateAlpha(from: 0.0, to: strongSelf.subtitleNode.alpha, duration: 0.25)

            strongSelf.animateOverlaysFadeIn?()
        }
    }
    
    deinit {
        self.emojiStatusPackDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        let usernameGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handleUsernameLongPress(_:)))
        self.usernameNodeRawContainer.view.addGestureRecognizer(usernameGestureRecognizer)
        
        let phoneGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handlePhoneLongPress(_:)))
        self.subtitleNodeRawContainer.view.addGestureRecognizer(phoneGestureRecognizer)
    }
    
    @objc private func handleUsernameLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state == .began {
            self.displayCopyContextMenu?(self.usernameNodeRawContainer, !self.isAvatarExpanded, true)
        }
    }
    
    @objc private func handlePhoneLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state == .began {
            self.displayCopyContextMenu?(self.subtitleNodeRawContainer, true, !self.isAvatarExpanded)
        }
    }
    
    @objc private func subtitleBackgroundPressed() {
        self.navigateToForum?()
    }
    
    func invokeDisplayPremiumIntro() {
        self.displayPremiumIntro?(self.isAvatarExpanded ? self.titleExpandedCredibilityIconView : self.titleCredibilityIconView, nil, .never(), self.isAvatarExpanded)
    }
    
    func invokeDisplayGiftInfo() {
        guard case let .emojiStatus(status) = self.currentStatusIcon, case let .starGift(_, _, title, _, _, _, _, _, _) = status.content else {
            return
        }
        self.displayUniqueGiftInfo?(self.isAvatarExpanded ? self.titleExpandedStatusIconView : self.titleStatusIconView, title)
    }
    
    func initiateAvatarExpansion(gallery: Bool, first: Bool) {
        if let peer = self.peer, peer.profileImageRepresentations.isEmpty && gallery {
            self.requestOpenAvatarForEditing?(false)
            return
        }
        if self.isAvatarExpanded || gallery {
            if let currentEntry = self.avatarListNode.listContainerNode.currentEntry, let firstEntry = self.avatarListNode.listContainerNode.galleryEntries.first {
                let entry = first ? firstEntry : currentEntry
                self.requestAvatarExpansion?(true, self.avatarListNode.listContainerNode.galleryEntries, entry, self.avatarTransitionArguments(entry: currentEntry))
            }
        } else if let entry = self.avatarListNode.listContainerNode.galleryEntries.first {
            self.requestAvatarExpansion?(false, self.avatarListNode.listContainerNode.galleryEntries, nil, self.avatarTransitionArguments(entry: entry))
        } else if let storyParams = self.avatarListNode.listContainerNode.storyParams, storyParams.count != 0 {
            self.requestAvatarExpansion?(false, self.avatarListNode.listContainerNode.galleryEntries, nil, nil)
        } else {
            self.cancelUpload?()
        }
    }
    
    func avatarTransitionArguments(entry: AvatarGalleryEntry) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        if self.isAvatarExpanded {
            if let avatarNode = self.avatarListNode.listContainerNode.currentItemNode?.imageNode {
                return (avatarNode, avatarNode.bounds, { [weak avatarNode] in
                    return (avatarNode?.view.snapshotContentTree(unhide: true), nil)
                })
            } else {
                return nil
            }
        } else if entry == self.avatarListNode.listContainerNode.galleryEntries.first {
            let avatarNode = self.avatarListNode.avatarContainerNode.avatarNode
            return (avatarNode, avatarNode.bounds, { [weak avatarNode] in
                return (avatarNode?.view.snapshotContentTree(unhide: true), nil)
            })
        } else {
            return nil
        }
    }
    
    func addToAvatarTransitionSurface(view: UIView) {
        if self.isAvatarExpanded {
            self.avatarListNode.listContainerNode.view.addSubview(view)
        } else {
            self.view.addSubview(view)
        }
    }
    
    func updateAvatarIsHidden(entry: AvatarGalleryEntry?) {
        if let entry = entry {
            self.avatarListNode.avatarContainerNode.containerNode.isHidden = entry == self.avatarListNode.listContainerNode.galleryEntries.first
            self.editingContentNode.avatarNode.isHidden = entry == self.avatarListNode.listContainerNode.galleryEntries.first
        } else {
            self.avatarListNode.avatarContainerNode.containerNode.isHidden = false
            self.editingContentNode.avatarNode.isHidden = false
        }
        self.avatarListNode.listContainerNode.updateEntryIsHidden(entry: entry)
    }
        
    private enum CredibilityIcon: Equatable {
        case none
        case premium
        case verified
        case fake
        case scam
        case emojiStatus(PeerEmojiStatus)
    }
    
    private var currentCredibilityIcon: CredibilityIcon?
    private var currentVerifiedIcon: CredibilityIcon?
    private var currentStatusIcon: CredibilityIcon?
    
    private var currentPanelStatusData: PeerInfoStatusData?
    func update(width: CGFloat, containerHeight: CGFloat, containerInset: CGFloat, sideInsets: PeerInfoSideInsets, statusBarHeight: CGFloat, navigationHeight: CGFloat, presentedInFormSheet: Bool, isMediaOnly: Bool, contentOffset: CGFloat, paneContainerY: CGFloat, presentationData: PresentationData, peer: EnginePeer?, cachedData: EngineCachedPeerData?, threadData: MessageHistoryThreadData?, peerNotificationSettings: TelegramPeerNotificationSettings?, threadNotificationSettings: TelegramPeerNotificationSettings?, globalNotificationSettings: EngineGlobalNotificationSettings?, statusData: PeerInfoStatusData?, panelStatusData: (PeerInfoStatusData?, PeerInfoStatusData?, CGFloat?), isSecretChat: Bool, isContact: Bool, isSettings: Bool, state: PeerInfoState, profileGiftsContext: ProfileGiftsContext?, screenData: PeerInfoScreenData?, isSearching: Bool, metrics: LayoutMetrics, deviceMetrics: DeviceMetrics, transition: ContainedViewLayoutTransition, additive: Bool, animateHeader: Bool) -> CGFloat {
        // iPhone Duo: keep the header out of the side strip; without one every expression below is today's.
        let stripLeft = sideInsets.stripLeft
        let stripRight = sideInsets.stripRight
        let hasStrip = stripLeft > 0.0 || stripRight > 0.0
        // With a strip, the avatar, title, subtitle and username are centered in the band between the strip
        // and the other edge (the action buttons' and sections' axis), kept `margin` inside it when they do
        // not fit.
        func bandCenteredOrigin(width elementWidth: CGFloat, margin: CGFloat) -> CGFloat {
            let bandWidth = width - stripLeft - stripRight
            return stripLeft + horizontallyCenteredOrigin(width: elementWidth, containerWidth: bandWidth, minX: margin, maxX: bandWidth - margin)
        }
        self.avatarListNode.listContainerNode.stripSideInsets = UIEdgeInsets(top: 0.0, left: stripLeft, bottom: 0.0, right: stripRight)
        if self.appliedCustomNavigationContentNode !== self.customNavigationContentNode {
            if let previous = self.appliedCustomNavigationContentNode {
                ComponentTransition(transition).setAlpha(view: previous.view, alpha: 0.0, completion: { [weak previous] _ in
                    previous?.removeFromSupernode()
                })
            }
            
            self.appliedCustomNavigationContentNode = self.customNavigationContentNode
            if let customNavigationContentNode = self.customNavigationContentNode {
                self.searchBarContainer.addSubnode(customNavigationContentNode)
                customNavigationContentNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width - sideInsets.navigationLeft - sideInsets.navigationRight, height: navigationHeight))
                customNavigationContentNode.alpha = 0.0
                ComponentTransition(transition).setAlpha(view: customNavigationContentNode.view, alpha: 1.0)
            }
        } else if let customNavigationContentNode = self.customNavigationContentNode {
            transition.updateFrame(node: customNavigationContentNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width - sideInsets.navigationLeft - sideInsets.navigationRight, height: navigationHeight)))
        }
        
        var threadData = threadData
        if case let .replyThread(replyThreadMessage) = self.chatLocation, replyThreadMessage.peerId == self.context.account.peerId {
            threadData = nil
        }
        
        // A suspicious peer's emoji status is not shown, as in their chat's title: neither the icon nor
        // the cover and colours a collectible status brings.
        var peer = peer
        if case let .user(user) = peer, user.emojiStatus != nil, (cachedData as? CachedUserData)?.isSuspiciousPeer == true {
            peer = .user(user.withUpdatedEmojiStatus(nil))
        }
        
        self.state = state
        self.peer = peer
        self.threadData = threadData
        self.isSearching = isSearching
        self.avatarListNode.listContainerNode.peer = peer
        
        let isFirstTime = self.validLayout == nil
        self.validLayout = (width, statusBarHeight, deviceMetrics)
        
        self.searchBarContainer.isUserInteractionEnabled = isSearching
        self.searchContainer.isUserInteractionEnabled = isSearching
        
        let previousPanelStatusData = self.currentPanelStatusData
        self.currentPanelStatusData = panelStatusData.0
        
        let avatarSize: CGFloat = presentedInFormSheet ? 200.0 : 100.0
        self.avatarSize = avatarSize
        
        var contentOffset = contentOffset
        
        if isMediaOnly {
            if presentedInFormSheet {
                contentOffset = 312.0
            } else {
                contentOffset = 212.0
            }
        }
        
        let actionButtonKeys: [PeerInfoHeaderButtonKey] = (self.isSettings || self.isMyProfile) ? [] : peerInfoHeaderActionButtons(peer: peer, isSecretChat: isSecretChat, isContact: isContact)
        let buttonKeys: [PeerInfoHeaderButtonKey] = (self.isSettings || self.isMyProfile) ? [] : peerInfoHeaderButtons(peer: peer, cachedData: cachedData, isOpenedFromChat: self.isOpenedFromChat, isExpanded: true, videoCallsEnabled: width > 320.0 && self.videoCallsEnabled, isSecretChat: isSecretChat, isContact: isContact, threadInfo: threadData?.info)
        
        let backgroundCoverSubject: PeerInfoCoverComponent.Subject?
        var backgroundCoverAnimateIn = false
        var backgroundDefaultHeight: CGFloat = 254.0
        var hasBackground = false
        if let status = peer?.emojiStatus, case .starGift = status.content {
            backgroundCoverSubject = .status(status)
            if !self.didSetupBackgroundCover {
                if !self.isSettings {
                    backgroundCoverAnimateIn = true
                }
                self.didSetupBackgroundCover = true
            }
            if !buttonKeys.isEmpty {
                backgroundDefaultHeight = 327.0
                if metrics.isTablet {
                    backgroundDefaultHeight += 60.0
                }
            }
            hasBackground = true
        } else if let peer {
            backgroundCoverSubject = .peer(peer)
            if peer.effectiveProfileColor != nil {
                hasBackground = true
            }
        } else {
            backgroundCoverSubject = nil
        }
        
        let currentSavedMusic = self.profileMusic(peer: peer, screenData: screenData)
        let currentWalletBalance: Int64?
        if !self.isSettings, let balance = (screenData?.cachedData as? CachedUserData)?.walletCard?.balance, balance >= 100_000_000 {
            currentWalletBalance = balance
        } else {
            currentWalletBalance = nil
        }
        let musicHeight: CGFloat = hasBackground || self.isAvatarExpanded ? 24.0 : 16.0
        let bottomInset: CGFloat = currentSavedMusic != nil ? musicHeight : 0.0
        let balanceInset: CGFloat = currentWalletBalance != nil ? 32.0 : 0.0
        
        let isLandscape = containerInset > 16.0
        
        let themeUpdated = self.presentationData?.theme !== presentationData.theme
        self.presentationData = presentationData
        
        let premiumConfiguration = PremiumConfiguration.with(appConfiguration: self.context.currentAppConfiguration.with { $0 })
        var credibilityIcon: CredibilityIcon = .none
        var verifiedIcon: CredibilityIcon = .none
        var statusIcon: CredibilityIcon = .none
        if let peer {
            if peer.id == self.context.account.peerId && !self.isSettings && !self.isMyProfile {
                credibilityIcon = .none
            } else if peer.isFake {
                credibilityIcon = .fake
            } else if peer.isScam {
                credibilityIcon = .scam
            } else if let emojiStatus = peer.emojiStatus {
                statusIcon = .emojiStatus(emojiStatus)
            } else if peer.isPremium && !premiumConfiguration.isPremiumDisabled && (peer.id != self.context.account.peerId || self.isSettings || self.isMyProfile) {
                credibilityIcon = .premium
            } else {
                credibilityIcon = .none
            }
            if peer.isVerified {
                credibilityIcon = .verified
            }
            if let verificationIconFileId = peer.verificationIconFileId {
                verifiedIcon = .emojiStatus(PeerEmojiStatus(content: .emoji(fileId: verificationIconFileId), expirationDate: nil))
            }
        }
        
        var isForum = false
        if case let .channel(channel) = peer, channel.isForumOrMonoForum {
            isForum = true
        }
        
        transition.updateAlpha(node: self.regularContentNode, alpha: (state.isEditing || self.customNavigationContentNode != nil) ? 0.0 : 1.0)
        self.updateNavigationRowHidden?(self.customNavigationContentNode != nil || isSearching, transition)
        
        self.editingContentNode.alpha = state.isEditing ? 1.0 : 0.0
        
        let editingContentHeight = self.editingContentNode.update(width: width, leftInset: sideInsets.sectionLeft, rightInset: sideInsets.sectionRight, statusBarHeight: statusBarHeight, navigationHeight: navigationHeight, presentedInFormSheet: presentedInFormSheet, peer: state.isEditing ? peer : nil, threadData: threadData, chatLocation: self.chatLocation, cachedData: cachedData, isContact: isContact, isSettings: isSettings || isMyProfile, presentationData: presentationData, transition: transition)
        transition.updateFrame(node: self.editingContentNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -contentOffset), size: CGSize(width: width, height: editingContentHeight)))
        
        let avatarOverlayFarme = self.editingContentNode.convert(self.editingContentNode.avatarNode.frame, to: self)
        transition.updateFrame(node: self.avatarOverlayNode, frame: avatarOverlayFarme)
        
        let avatarFrame = CGRect(origin: CGPoint(x: hasStrip ? bandCenteredOrigin(width: avatarSize, margin: 16.0) : floor((width - avatarSize) / 2.0), y: statusBarHeight + 22.0), size: CGSize(width: avatarSize, height: avatarSize))
        
        let regularNavigationContentsAccentColor: UIColor = peer?.effectiveProfileColor != nil ? .white : presentationData.theme.list.itemAccentColor
        let collapsedHeaderNavigationContentsAccentColor = presentationData.theme.list.itemAccentColor
        let expandedAvatarNavigationContentsAccentColor: UIColor = .white
        
        let regularNavigationContentsPrimaryColor: UIColor = peer?.effectiveProfileColor != nil ? .white : presentationData.theme.list.itemPrimaryTextColor
        let collapsedHeaderNavigationContentsPrimaryColor = presentationData.theme.list.itemPrimaryTextColor
        let expandedAvatarNavigationContentsPrimaryColor: UIColor = .white
        
        let regularContentButtonBackgroundColor: UIColor
        let collapsedHeaderContentButtonBackgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        let expandedAvatarContentButtonBackgroundColor: UIColor = UIColor(white: 1.0, alpha: 0.1)
        
        let regularHeaderButtonBackgroundColor: UIColor
        let collapsedHeaderButtonBackgroundColor: UIColor = .clear
        let expandedAvatarHeaderButtonBackgroundColor: UIColor = UIColor(white: 0.0, alpha: 0.5)
        
        let regularContentButtonForegroundColor: UIColor = peer?.effectiveProfileColor != nil ? UIColor.white : presentationData.theme.list.itemAccentColor
        let collapsedHeaderContentButtonForegroundColor = presentationData.theme.list.itemAccentColor
        let expandedAvatarContentButtonForegroundColor: UIColor = .white
        
        var hasCoverColor = false
        let regularNavigationContentsSecondaryColor: UIColor
        if let emojiStatus = peer?.emojiStatus, case let .starGift(_, _, _, _, _, innerColor, outerColor, _, _) = emojiStatus.content {
            let mainColor = UIColor(rgb: UInt32(bitPattern: innerColor))
            let secondaryColor = UIColor(rgb: UInt32(bitPattern: outerColor))
            regularNavigationContentsSecondaryColor = UIColor(white: 1.0, alpha: 0.6).blitOver(mainColor.withMultiplied(hue: 1.0, saturation: 2.2, brightness: 1.5), alpha: 1.0)
            
            let baseButtonBackgroundColor: UIColor
            if presentationData.theme.overallDarkAppearance {
                baseButtonBackgroundColor = UIColor(white: 0.0, alpha: 0.25)
            } else {
                baseButtonBackgroundColor = UIColor(white: 1.0, alpha: 0.25)
            }
            let baseContentButtonBackgroundColor = presentationData.theme.overallDarkAppearance ? baseButtonBackgroundColor : UIColor(white: 1.0, alpha: 0.35)
            regularContentButtonBackgroundColor = baseContentButtonBackgroundColor.blendOver(background: secondaryColor.mixedWith(mainColor, alpha: 0.1))
            regularHeaderButtonBackgroundColor = baseButtonBackgroundColor.blendOver(background: secondaryColor.mixedWith(mainColor, alpha: 0.1))
            
            hasCoverColor = true
        } else if let profileColor = peer?.effectiveProfileColor {
            let backgroundColors = self.context.peerNameColors.getProfile(profileColor, dark: presentationData.theme.overallDarkAppearance)
            regularNavigationContentsSecondaryColor = UIColor(white: 1.0, alpha: 0.6).blitOver(backgroundColors.main.withMultiplied(hue: 1.0, saturation: 2.2, brightness: 1.5), alpha: 1.0)
            
            let baseButtonBackgroundColor: UIColor
            if presentationData.theme.overallDarkAppearance {
                baseButtonBackgroundColor = UIColor(white: 0.0, alpha: 0.25)
            } else {
                baseButtonBackgroundColor = UIColor(white: 1.0, alpha: 0.25)
            }
            let baseContentButtonBackgroundColor = presentationData.theme.overallDarkAppearance ? baseButtonBackgroundColor : UIColor(white: 1.0, alpha: 0.35)
            regularContentButtonBackgroundColor = baseContentButtonBackgroundColor.blendOver(background: backgroundColors.main)
            regularHeaderButtonBackgroundColor = baseButtonBackgroundColor.blendOver(background: (backgroundColors.secondary ?? backgroundColors.main).mixedWith(backgroundColors.main, alpha: 0.1))
            
            hasCoverColor = true
        } else {
            regularNavigationContentsSecondaryColor = presentationData.theme.list.itemSecondaryTextColor
            regularContentButtonBackgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
            regularHeaderButtonBackgroundColor = .clear
        }
        self.contentButtonBackgroundColor = regularNavigationContentsSecondaryColor.mixedWith(regularContentButtonBackgroundColor, alpha: 0.5)
        
        let collapsedHeaderNavigationContentsSecondaryColor = presentationData.theme.list.itemSecondaryTextColor
        let expandedAvatarNavigationContentsSecondaryColor: UIColor = .white
        
        let navigationContentsAccentColor: UIColor
        let navigationContentsPrimaryColor: UIColor
        let navigationContentsSecondaryColor: UIColor
        let navigationContentsCanBeExpanded: Bool
        
        let contentButtonBackgroundColor: UIColor
        let contentButtonForegroundColor: UIColor
        
        let headerButtonBackgroundColor: UIColor
        
        var panelWithAvatarHeight: CGFloat = 35.0 + avatarSize + balanceInset
        if threadData != nil {
            panelWithAvatarHeight += 10.0
        }
        
        let innerBackgroundTransitionFraction: CGFloat
        
        let navigationTransition: ContainedViewLayoutTransition
        if transition.isAnimated {
            navigationTransition = transition
        } else {
            navigationTransition = animateHeader ? .animated(duration: 0.2, curve: .easeInOut) : .immediate
        }
        
        let editingEdgeEffectHeight: CGFloat = 40.0
        let editingEdgeEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: navigationHeight + 10.0))
        transition.updateFrame(view: self.editingEdgeEffectView, frame: editingEdgeEffectFrame)
        self.editingEdgeEffectView.update(content: presentationData.theme.list.blocksBackgroundColor, blur: true, rect: editingEdgeEffectFrame, edge: .top, edgeSize: editingEdgeEffectHeight, transition: ComponentTransition(transition))
        let editingBackgroundAlpha: CGFloat
        if state.isEditing {
            editingBackgroundAlpha = max(0.0, min(1.0, contentOffset / 20.0))
        } else {
            editingBackgroundAlpha = 0.0
        }
        ComponentTransition(transition).setAlpha(view: self.editingEdgeEffectView, alpha: editingBackgroundAlpha)
        
        if isSearching {
            let searchNavigationHeight: CGFloat
            if isSettings {
                searchNavigationHeight = statusBarHeight + 10.0
            } else {
                searchNavigationHeight = navigationHeight + 10.0
            }
            
            let searchEdgeEffectHeight: CGFloat = min(40.0, searchNavigationHeight)
            let searchEdgeEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: searchNavigationHeight))
            
            let searchEdgeEffectView: EdgeEffectView
            var searchEdgeEffectTransition = ComponentTransition(transition)
            if let current = self.searchEdgeEffectView {
                searchEdgeEffectView = current
            } else {
                searchEdgeEffectTransition = .immediate
                searchEdgeEffectView = EdgeEffectView()
                self.searchEdgeEffectView = searchEdgeEffectView
                self.searchContainer.view.superview?.insertSubview(searchEdgeEffectView, aboveSubview: self.searchContainer.view)
                if transition.isAnimated {
                    searchEdgeEffectView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            }
            
            transition.updateFrame(view: searchEdgeEffectView, frame: searchEdgeEffectFrame)
            searchEdgeEffectView.update(content: presentationData.theme.list.plainBackgroundColor, blur: true, rect: searchEdgeEffectFrame, edge: .top, edgeSize: searchEdgeEffectHeight, transition: searchEdgeEffectTransition)
        } else if let searchEdgeEffectView = self.searchEdgeEffectView {
            self.searchEdgeEffectView = nil
            transition.updateAlpha(layer: searchEdgeEffectView.layer, alpha: 0.0, completion: { [weak searchEdgeEffectView] _ in
                searchEdgeEffectView?.removeFromSuperview()
            })
        }
        
        let backgroundBannerAlpha: CGFloat
        
        do {
            let backgroundTransitionStepDistance: CGFloat = 50.0
            var backgroundTransitionDistance: CGFloat = navigationHeight + panelWithAvatarHeight - backgroundTransitionStepDistance
            if self.isSettings || self.isMyProfile {
                backgroundTransitionDistance -= 100.0
            }
            if isMediaOnly {
                innerBackgroundTransitionFraction = 1.0
            } else {
                let contentOffset = max(0.0, contentOffset - backgroundTransitionDistance)
                innerBackgroundTransitionFraction = max(0.0, min(1.0, contentOffset / backgroundTransitionStepDistance))
            }
            
            if state.isEditing {
                backgroundBannerAlpha = 0.0
            } else {
                if 1.0 - innerBackgroundTransitionFraction < 0.5 {
                    backgroundBannerAlpha = 0.0
                } else {
                    backgroundBannerAlpha = 1.0
                }
            }
            navigationTransition.updateAlpha(layer: self.backgroundBannerView.layer, alpha: backgroundBannerAlpha)
            
            self.avatarClippingNode.clipsToBounds = true
        }
        
        let accentRatingBackgroundColor: UIColor
        if let currentStarRating = self.currentStarRating, currentStarRating.level < 0 {
            accentRatingBackgroundColor = UIColor(rgb: 0xFF3B30)
        } else {
            accentRatingBackgroundColor = presentationData.theme.list.itemCheckColors.fillColor
        }
        
        let ratingBackgroundColor: UIColor
        let ratingBorderColor: UIColor
        let ratingForegroundColor: UIColor
        
        if state.isEditing {
            navigationContentsAccentColor = collapsedHeaderNavigationContentsAccentColor
            navigationContentsPrimaryColor = collapsedHeaderNavigationContentsPrimaryColor
            navigationContentsSecondaryColor = collapsedHeaderNavigationContentsSecondaryColor
            navigationContentsCanBeExpanded = true
            
            contentButtonBackgroundColor = collapsedHeaderContentButtonBackgroundColor
            contentButtonForegroundColor = collapsedHeaderContentButtonForegroundColor
            
            headerButtonBackgroundColor = collapsedHeaderButtonBackgroundColor
            
            ratingBackgroundColor = accentRatingBackgroundColor
            ratingBorderColor = .clear
            ratingForegroundColor = presentationData.theme.list.itemCheckColors.foregroundColor
        } else if self.isAvatarExpanded {
            navigationContentsAccentColor = expandedAvatarNavigationContentsAccentColor
            navigationContentsPrimaryColor = expandedAvatarNavigationContentsPrimaryColor
            navigationContentsSecondaryColor = expandedAvatarNavigationContentsSecondaryColor
            contentButtonBackgroundColor = expandedAvatarContentButtonBackgroundColor
            contentButtonForegroundColor = expandedAvatarContentButtonForegroundColor
            
            navigationContentsCanBeExpanded = false
            
            headerButtonBackgroundColor = expandedAvatarHeaderButtonBackgroundColor
            
            ratingBackgroundColor = .white
            ratingBorderColor = .clear
            ratingForegroundColor = .clear
        } else {
            let effectiveTransitionFraction: CGFloat = innerBackgroundTransitionFraction < 0.5 ? 0.0 : 1.0
            
            navigationContentsAccentColor = regularNavigationContentsAccentColor.mixedWith(collapsedHeaderNavigationContentsAccentColor, alpha: effectiveTransitionFraction)
            navigationContentsPrimaryColor = regularNavigationContentsPrimaryColor.mixedWith(collapsedHeaderNavigationContentsPrimaryColor, alpha: effectiveTransitionFraction)
            navigationContentsSecondaryColor = regularNavigationContentsSecondaryColor.mixedWith(collapsedHeaderNavigationContentsSecondaryColor, alpha: effectiveTransitionFraction)
            
            if hasCoverColor {
                navigationContentsCanBeExpanded = effectiveTransitionFraction == 1.0
            } else {
                navigationContentsCanBeExpanded = true
            }
            
            contentButtonBackgroundColor = regularContentButtonBackgroundColor
            contentButtonForegroundColor = regularContentButtonForegroundColor
            
            headerButtonBackgroundColor = regularHeaderButtonBackgroundColor.mixedWith(collapsedHeaderButtonBackgroundColor, alpha: effectiveTransitionFraction)
            
            if let status = peer?.emojiStatus, case let .starGift(_, _, _, _, _, innerColor, outerColor, patternColorValue, _) = status.content {
                let _ = innerColor
                ratingBackgroundColor = UIColor(white: 1.0, alpha: 1.0).mixedWith(accentRatingBackgroundColor, alpha: effectiveTransitionFraction)
                
                let innerColor = UIColor(rgb: UInt32(bitPattern: innerColor))
                let outerColor = UIColor(rgb: UInt32(bitPattern: outerColor))
                let backgroundColor = innerColor.mixedWith(outerColor, alpha: 0.8)

                let patternColor = UIColor(rgb: UInt32(bitPattern: patternColorValue))
                ratingBorderColor = patternColor.withAlphaComponent(0.1).blendOver(background: backgroundColor).mixedWith(.clear, alpha: effectiveTransitionFraction)
                ratingForegroundColor = ratingBorderColor.mixedWith(presentationData.theme.list.itemCheckColors.foregroundColor, alpha: effectiveTransitionFraction)
            } else if let profileColor = peer?.effectiveProfileColor {
                ratingBackgroundColor = UIColor(white: 1.0, alpha: 1.0).mixedWith(presentationData.theme.list.itemCheckColors.fillColor, alpha: effectiveTransitionFraction)
                
                let backgroundColors = self.context.peerNameColors.getProfile(profileColor, dark: presentationData.theme.overallDarkAppearance)
                
                let innerColor = backgroundColors.main
                let outerColor = backgroundColors.secondary ?? backgroundColors.main
                let backgroundColor = innerColor.mixedWith(outerColor, alpha: 0.8)

                let patternColor = UIColor(white: 0.0, alpha: 0.6)
                ratingBorderColor = patternColor.withAlphaComponent(0.1).blendOver(background: backgroundColor).mixedWith(.clear, alpha: effectiveTransitionFraction)
                ratingForegroundColor = ratingBorderColor.mixedWith(presentationData.theme.list.itemCheckColors.foregroundColor, alpha: effectiveTransitionFraction)
            } else {
                ratingBackgroundColor = accentRatingBackgroundColor
                ratingBorderColor = UIColor.clear
                ratingForegroundColor = presentationData.theme.list.itemCheckColors.foregroundColor
            }
        }
        
        do {
            self.currentCredibilityIcon = credibilityIcon
            
            var emojiStatusSize: CGSize?
            var currentEmojiStatus: PeerEmojiStatus?
            let emojiRegularStatusContent: EmojiStatusComponent.Content
            let emojiExpandedStatusContent: EmojiStatusComponent.Content
            switch credibilityIcon {
            case .none:
                emojiRegularStatusContent = .none
                emojiExpandedStatusContent = .none
            case .premium:
                emojiRegularStatusContent = .premium(color: navigationContentsAccentColor)
                emojiExpandedStatusContent = .premium(color: navigationContentsAccentColor)
                emojiStatusSize = CGSize(width: 30.0, height: 30.0)
            case .verified:
                emojiRegularStatusContent = .verified(fillColor: presentationData.theme.list.itemCheckColors.fillColor, foregroundColor: presentationData.theme.list.itemCheckColors.foregroundColor, sizeType: .large)
                emojiExpandedStatusContent = .verified(fillColor: navigationContentsAccentColor, foregroundColor: .clear, sizeType: .large)
            case .fake:
                emojiRegularStatusContent = .text(color: presentationData.theme.chat.message.incoming.scamColor, string: presentationData.strings.Message_FakeAccount.uppercased())
                emojiExpandedStatusContent = emojiRegularStatusContent
            case .scam:
                emojiRegularStatusContent = .text(color: presentationData.theme.chat.message.incoming.scamColor, string: presentationData.strings.Message_ScamAccount.uppercased())
                emojiExpandedStatusContent = emojiRegularStatusContent
            case let .emojiStatus(emojiStatus):
                currentEmojiStatus = emojiStatus
                emojiRegularStatusContent = .animation(content: .customEmoji(fileId: emojiStatus.fileId), size: CGSize(width: 80.0, height: 80.0), placeholderColor: presentationData.theme.list.mediaPlaceholderColor, themeColor: navigationContentsAccentColor, loopMode: .forever)
                emojiExpandedStatusContent = .animation(content: .customEmoji(fileId: emojiStatus.fileId), size: CGSize(width: 80.0, height: 80.0), placeholderColor: navigationContentsAccentColor, themeColor: navigationContentsAccentColor, loopMode: .forever)
            }
            
            let iconSize = self.titleCredibilityIconView.update(
                transition: ComponentTransition(navigationTransition),
                component: AnyComponent(EmojiStatusComponent(
                    context: self.context,
                    animationCache: self.animationCache,
                    animationRenderer: self.animationRenderer,
                    content: emojiRegularStatusContent,
                    size: emojiStatusSize,
                    isVisibleForAnimations: true,
                    useSharedAnimation: true,
                    action: { [weak self] in
                        guard let strongSelf = self else {
                            return
                        }
                        if case .premium = strongSelf.currentCredibilityIcon {
                            strongSelf.displayPremiumIntro?(strongSelf.titleCredibilityIconView, currentEmojiStatus, strongSelf.emojiStatusFileAndPackTitle.get(), false)
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 26.0, height: 26.0)
            )
            let expandedIconSize = self.titleExpandedCredibilityIconView.update(
                transition: ComponentTransition(navigationTransition),
                component: AnyComponent(EmojiStatusComponent(
                    context: self.context,
                    animationCache: self.animationCache,
                    animationRenderer: self.animationRenderer,
                    content: emojiExpandedStatusContent,
                    size: emojiStatusSize,
                    isVisibleForAnimations: true,
                    useSharedAnimation: true,
                    action: { [weak self] in
                        guard let strongSelf = self else {
                            return
                        }
                        if case .premium = strongSelf.currentCredibilityIcon {
                            strongSelf.displayPremiumIntro?(strongSelf.titleExpandedCredibilityIconView, currentEmojiStatus, strongSelf.emojiStatusFileAndPackTitle.get(), true)
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 26.0, height: 26.0)
            )
            
            self.credibilityIconSize = iconSize
            self.titleExpandedCredibilityIconSize = expandedIconSize
        }
        
        do {
            self.currentStatusIcon = statusIcon
            
            var currentEmojiStatus: PeerEmojiStatus?
            var particleColor: UIColor?
            var uniqueGiftSlug: String?
            
            let emojiRegularStatusContent: EmojiStatusComponent.Content
            let emojiExpandedStatusContent: EmojiStatusComponent.Content
            switch statusIcon {
            case let .emojiStatus(emojiStatus):
                currentEmojiStatus = emojiStatus
                emojiRegularStatusContent = .animation(content: .customEmoji(fileId: emojiStatus.fileId), size: CGSize(width: 80.0, height: 80.0), placeholderColor: presentationData.theme.list.mediaPlaceholderColor, themeColor: navigationContentsAccentColor, loopMode: .forever)
                emojiExpandedStatusContent = .animation(content: .customEmoji(fileId: emojiStatus.fileId), size: CGSize(width: 80.0, height: 80.0), placeholderColor: navigationContentsAccentColor, themeColor: navigationContentsAccentColor, loopMode: .forever)
                if case let .starGift(_, _, _, slug, _, _, _, _, _) = emojiStatus.content {
                    particleColor = UIColor.white
                    uniqueGiftSlug = slug
                }
            default:
                emojiRegularStatusContent = .none
                emojiExpandedStatusContent = .none
            }
            
            let iconSize = self.titleStatusIconView.update(
                transition: ComponentTransition(navigationTransition),
                component: AnyComponent(EmojiStatusComponent(
                    context: self.context,
                    animationCache: self.animationCache,
                    animationRenderer: self.animationRenderer,
                    content: emojiRegularStatusContent,
                    particleColor: particleColor,
                    isVisibleForAnimations: true,
                    useSharedAnimation: true,
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        if let uniqueGiftSlug, !self.isSettings {
                            self.openUniqueGift?(self.titleStatusIconView, uniqueGiftSlug)
                        } else {
                            self.displayPremiumIntro?(self.titleStatusIconView, currentEmojiStatus, self.emojiStatusFileAndPackTitle.get(), false)
                        }
                    },
                    emojiFileUpdated: { [weak self] emojiFile in
                        guard let strongSelf = self else {
                            return
                        }
                        
                        // `.never()` until the pack is known; nil once it is known there is none (the
                        // emoji names no pack, or its owner deleted it), so a tap still opens the screen.
                        if let emojiFile = emojiFile {
                            strongSelf.emojiStatusFileAndPackTitle.set(.never())
                            
                            strongSelf.emojiStatusPackDisposable.set((strongSelf.context.engine.stickers.customEmojiPack(file: emojiFile)
                            |> map { pack -> (TelegramMediaFile, LoadedStickerPack)? in
                                if let pack, case let .result(_, items, _) = pack {
                                    return items.first.flatMap { ($0.file._parse(), pack) }
                                } else {
                                    return nil
                                }
                            }).startStrict(next: { fileAndPackTitle in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.emojiStatusFileAndPackTitle.set(.single(fileAndPackTitle))
                            }))
                        } else {
                            strongSelf.emojiStatusPackDisposable.set(nil)
                            strongSelf.emojiStatusFileAndPackTitle.set(.single(nil))
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 26.0, height: 26.0)
            )
            let expandedIconSize = self.titleExpandedStatusIconView.update(
                transition: ComponentTransition(navigationTransition),
                component: AnyComponent(EmojiStatusComponent(
                    context: self.context,
                    animationCache: self.animationCache,
                    animationRenderer: self.animationRenderer,
                    content: emojiExpandedStatusContent,
                    particleColor: particleColor,
                    isVisibleForAnimations: true,
                    useSharedAnimation: true,
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        if let uniqueGiftSlug, !self.isSettings {
                            self.openUniqueGift?(self.titleExpandedStatusIconView, uniqueGiftSlug)
                        } else {
                            self.displayPremiumIntro?(self.titleExpandedStatusIconView, currentEmojiStatus, self.emojiStatusFileAndPackTitle.get(), true)
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 26.0, height: 26.0)
            )
            
            self.statusIconSize = iconSize
            self.titleExpandedStatusIconSize = expandedIconSize
        }
        
        do {
            self.currentVerifiedIcon = verifiedIcon
            
            let emojiRegularStatusContent: EmojiStatusComponent.Content
            let emojiExpandedStatusContent: EmojiStatusComponent.Content
            switch verifiedIcon {
            case .verified:
                emojiRegularStatusContent = .verified(fillColor: presentationData.theme.list.itemCheckColors.fillColor, foregroundColor: presentationData.theme.list.itemCheckColors.foregroundColor, sizeType: .large)
                emojiExpandedStatusContent = .verified(fillColor: navigationContentsAccentColor, foregroundColor: .clear, sizeType: .large)
            case let .emojiStatus(emojiStatus):
                emojiRegularStatusContent = .animation(content: .customEmoji(fileId: emojiStatus.fileId), size: CGSize(width: 80.0, height: 80.0), placeholderColor: presentationData.theme.list.mediaPlaceholderColor, themeColor: navigationContentsAccentColor, loopMode: .forever)
                emojiExpandedStatusContent = .animation(content: .customEmoji(fileId: emojiStatus.fileId), size: CGSize(width: 80.0, height: 80.0), placeholderColor: navigationContentsAccentColor, themeColor: navigationContentsAccentColor, loopMode: .forever)
            default:
                emojiRegularStatusContent = .none
                emojiExpandedStatusContent = .none
            }
            
            let iconSize = self.titleVerifiedIconView.update(
                transition: ComponentTransition(navigationTransition),
                component: AnyComponent(EmojiStatusComponent(
                    context: self.context,
                    animationCache: self.animationCache,
                    animationRenderer: self.animationRenderer,
                    content: emojiRegularStatusContent,
                    isVisibleForAnimations: true,
                    useSharedAnimation: true,
                    action: nil,
                    emojiFileUpdated: nil
                )),
                environment: {},
                containerSize: CGSize(width: 26.0, height: 26.0)
            )
            let expandedIconSize = self.titleExpandedVerifiedIconView.update(
                transition: ComponentTransition(navigationTransition),
                component: AnyComponent(EmojiStatusComponent(
                    context: self.context,
                    animationCache: self.animationCache,
                    animationRenderer: self.animationRenderer,
                    content: emojiExpandedStatusContent,
                    isVisibleForAnimations: true,
                    useSharedAnimation: true,
                    action: {}
                )),
                environment: {},
                containerSize: CGSize(width: 26.0, height: 26.0)
            )
            
            self.verifiedIconSize = iconSize
            self.titleExpandedVerifiedIconSize = expandedIconSize
        }
        
        self.expansionGlassTint = navigationContentsCanBeExpanded ? nil : headerButtonBackgroundColor
        self.updateNavigationGlass?(navigationContentsCanBeExpanded ? .plain : .tinted(headerButtonBackgroundColor), navigationTransition)
        
        self.titleNode.updateTintColor(color: navigationContentsPrimaryColor, transition: navigationTransition)
        self.subtitleNode.updateTintColor(color: navigationContentsSecondaryColor, transition: navigationTransition)
        self.panelSubtitleNode.updateTintColor(color: navigationContentsSecondaryColor, transition: navigationTransition)
        var titleBrightness: CGFloat = 0.0
        navigationContentsPrimaryColor.getHue(nil, saturation: nil, brightness: &titleBrightness, alpha: nil)
        if isSearching {
            self.controller?.setStatusBarStyle(presentationData.theme.overallDarkAppearance ? .White : .Black, animated: !isFirstTime && animateHeader)
        } else {
            self.controller?.setStatusBarStyle(titleBrightness > 0.5 ? .White : .Black, animated: !isFirstTime && animateHeader)
        }
        
        self.avatarListNode.avatarContainerNode.updateTransitionFraction(0.0, transition: transition)
        self.avatarListNode.listContainerNode.currentItemNode?.updateTransitionFraction(0.0, transition: transition)
        self.avatarOverlayNode.updateTransitionFraction(0.0, transition: transition)
        
        let expandedAvatarControlsHeight: CGFloat = 61.0
        var expandedAvatarListHeight = min(width, containerHeight - expandedAvatarControlsHeight)
        if self.isSettings || self.isMyProfile {
            expandedAvatarListHeight = expandedAvatarListHeight + 60.0
        } else {
            expandedAvatarListHeight = expandedAvatarListHeight + 98.0
        }
        
        let expandedAvatarListSize = CGSize(width: width, height: expandedAvatarListHeight)
                
        var isPremium = false
        var isVerified = false
        var isFake = false
        let titleStringText: String
        let smallTitleAttributes: MultiScaleTextState.Attributes
        let titleAttributes: MultiScaleTextState.Attributes
        let subtitleStringText: String
        var subtitleAttributedText: NSAttributedString?
        let smallSubtitleAttributes: MultiScaleTextState.Attributes
        let subtitleAttributes: MultiScaleTextState.Attributes
        var subtitleIsButton: Bool = false
        var panelSubtitleString: (text: String, attributes: MultiScaleTextState.Attributes)?
        let usernameString: (text: String, attributes: MultiScaleTextState.Attributes)
        if let peer = peer {
            isPremium = peer.isPremium
            isVerified = peer.isVerified
            isFake = peer.isFake || peer.isScam
        }
        
        let titleShadowColor: UIColor? = nil
        
        var displayStandardTitle = false
        
        if let peer = peer {
            var title: String
            if peer.id == self.context.account.peerId && !self.isSettings && !self.isMyProfile {
                if case .replyThread = self.chatLocation {
                    title = presentationData.strings.Conversation_MyNotes
                } else {
                    displayStandardTitle = true
                    title = presentationData.strings.Conversation_SavedMessages
                }
            } else if peer.id.isAnonymousSavedMessages {
                title = presentationData.strings.ChatList_AuthorHidden
            } else if let threadData = threadData {
                title = threadData.info.title
            } else {
                title = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
            }
            title = title.replacingOccurrences(of: "\u{1160}", with: "").replacingOccurrences(of: "\u{3164}", with: "")
            if title.replacingOccurrences(of: "\u{fe0e}", with: "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                title = "" //"\u{00A0}"
            }
            if title.isEmpty {
                if case let .user(user) = peer, let phone = user.phone {
                    title = formatPhoneNumber(context: self.context, number: phone)
                } else if let addressName = peer.addressName {
                    title = "@\(addressName)"
                } else {
                    title = "_"
                }
            }

            titleStringText = title
            titleAttributes = MultiScaleTextState.Attributes(font: Font.medium(28.0), color: .white)
            smallTitleAttributes = MultiScaleTextState.Attributes(font: Font.medium(28.0), color: .white, shadowColor: titleShadowColor)
            
            if self.isSettings, case let .user(user) = peer {
                var subtitle = formatPhoneNumber(context: self.context, number: user.phone ?? "")
                
                if let mainUsername = user.addressName, !mainUsername.isEmpty {
                    subtitle = "\(subtitle) • @\(mainUsername)"
                }
                subtitleStringText = subtitle
                subtitleAttributes = MultiScaleTextState.Attributes(font: Font.regular(17.0), color: .white)
                smallSubtitleAttributes = MultiScaleTextState.Attributes(font: Font.regular(16.0), color: .white, shadowColor: titleShadowColor)
                
                usernameString = ("", MultiScaleTextState.Attributes(font: Font.regular(16.0), color: .white))
            } else if self.isMyProfile {
                let subtitleColor: UIColor
                subtitleColor = .white
                
                subtitleStringText = presentationData.strings.Presence_online
                subtitleAttributes = MultiScaleTextState.Attributes(font: Font.regular(17.0), color: subtitleColor)
                smallSubtitleAttributes = MultiScaleTextState.Attributes(font: Font.regular(16.0), color: .white, shadowColor: titleShadowColor)
                
                usernameString = ("", MultiScaleTextState.Attributes(font: Font.regular(16.0), color: .white))

                let (maybePanelStatusData, _, _) = panelStatusData
                if let panelStatusData = maybePanelStatusData {
                    let subtitleColor: UIColor
                    if panelStatusData.isActivity {
                        subtitleColor = UIColor.white
                    } else {
                        subtitleColor = UIColor.white
                    }
                    panelSubtitleString = (panelStatusData.text, MultiScaleTextState.Attributes(font: Font.regular(17.0), color: subtitleColor))
                }
            } else if let _ = threadData {
                let subtitleColor: UIColor = .white
                
                let statusText: String
                if case let .user(user) = peer, user.isForum {
                    statusText = " "
                } else {
                    statusText = peer.debugDisplayTitle
                    subtitleIsButton = true
                }
                
                subtitleStringText = statusText
                subtitleAttributes = MultiScaleTextState.Attributes(font: Font.semibold(16.0), color: subtitleColor)
                smallSubtitleAttributes = MultiScaleTextState.Attributes(font: Font.regular(16.0), color: .white, shadowColor: titleShadowColor)
                
                usernameString = ("", MultiScaleTextState.Attributes(font: Font.regular(16.0), color: .white))

                let (maybePanelStatusData, _, _) = panelStatusData
                if let panelStatusData = maybePanelStatusData {
                    let subtitleColor: UIColor
                    if panelStatusData.isActivity {
                        subtitleColor = UIColor.white
                    } else {
                        subtitleColor = UIColor.white
                    }
                    panelSubtitleString = (panelStatusData.text, MultiScaleTextState.Attributes(font: Font.regular(17.0), color: subtitleColor))
                }
            } else if let statusData = statusData {
                let subtitleColor: UIColor
                if statusData.isActivity {
                    subtitleColor = UIColor.white
                } else {
                    subtitleColor = UIColor.white
                }
                
                subtitleStringText = statusData.text
                subtitleAttributes = MultiScaleTextState.Attributes(font: Font.regular(17.0), color: subtitleColor)
                smallSubtitleAttributes = MultiScaleTextState.Attributes(font: Font.regular(16.0), color: .white, shadowColor: titleShadowColor)
                if statusData.hasHiddenCommunityPrefix {
                    let icon = UIImage(bundleImageName: "Chat List/HiddenIcon")?.withRenderingMode(.alwaysTemplate)
                    if let icon {
                        let result = NSMutableAttributedString(string: " #  \(statusData.text)")
                        result.addAttribute(.attachment, value: icon, range: NSRange(location: 1, length: 1))
                        result.addAttribute(.baselineOffset, value: 1.0, range: NSRange(location: 1, length: 1))
                        subtitleAttributedText = result
                    } else {
                        subtitleAttributedText = NSAttributedString(string: statusData.text)
                    }
                }
                
                usernameString = ("", MultiScaleTextState.Attributes(font: Font.regular(16.0), color: .white))

                let (maybePanelStatusData, _, _) = panelStatusData
                if let panelStatusData = maybePanelStatusData {
                    let subtitleColor: UIColor
                    if panelStatusData.isActivity {
                        subtitleColor = UIColor.white
                    } else {
                        subtitleColor = UIColor.white
                    }
                    panelSubtitleString = (panelStatusData.text, MultiScaleTextState.Attributes(font: Font.regular(17.0), color: subtitleColor))
                }
            } else {
                subtitleStringText = " "
                subtitleAttributes = MultiScaleTextState.Attributes(font: Font.regular(16.0), color: .white)
                smallSubtitleAttributes = MultiScaleTextState.Attributes(font: Font.regular(16.0), color: .white, shadowColor: titleShadowColor)
                
                usernameString = ("", MultiScaleTextState.Attributes(font: Font.regular(16.0), color: .white))
                
                let (maybePanelStatusData, _, _) = panelStatusData
                if let panelStatusData = maybePanelStatusData {
                    let subtitleColor: UIColor
                    if panelStatusData.isActivity {
                        subtitleColor = UIColor.white
                    } else {
                        subtitleColor = UIColor.white
                    }
                    panelSubtitleString = (panelStatusData.text, MultiScaleTextState.Attributes(font: Font.regular(17.0), color: subtitleColor))
                }
            }
        } else {
            titleStringText = " "
            titleAttributes = MultiScaleTextState.Attributes(font: Font.regular(24.0), color: .white)
            smallTitleAttributes = MultiScaleTextState.Attributes(font: Font.regular(24.0), color: .white, shadowColor: titleShadowColor)
            
            subtitleStringText = " "
            subtitleAttributes = MultiScaleTextState.Attributes(font: Font.regular(16.0), color: .white)
            smallSubtitleAttributes = MultiScaleTextState.Attributes(font: Font.regular(16.0), color: .white, shadowColor: titleShadowColor)
            
            usernameString = ("", MultiScaleTextState.Attributes(font: Font.regular(16.0), color: .white))
        }
        
        let textSideInset: CGFloat = 36.0
        let expandedAvatarHeight: CGFloat = expandedAvatarListSize.height
        
        var titleConstrainedSize = CGSize(width: width - stripLeft - stripRight - textSideInset * 2.0 - (isPremium || isVerified || isFake ? 20.0 : 0.0), height: .greatestFiniteMagnitude)
        if self.navigationRowRightButtonCount > 1 {
            titleConstrainedSize.width -= 60.0
        }
        
        let titleNodeLayout = self.titleNode.updateLayout(text: titleStringText, states: [
            TitleNodeStateRegular: MultiScaleTextState(attributes: titleAttributes, constrainedSize: titleConstrainedSize),
            TitleNodeStateExpanded: MultiScaleTextState(attributes: smallTitleAttributes, constrainedSize: titleConstrainedSize)
        ], mainState: TitleNodeStateRegular)
        
        var subtitleRatingSize: CGSize?

        if let cachedData = cachedData as? CachedUserData, let starRating = cachedData.starRating {
            self.currentStarRating = starRating
            self.currentPendingStarRating = cachedData.pendingStarRating
        } else {
            self.currentStarRating = nil
            self.currentPendingStarRating = nil
        }

        #if DEBUG && false
        if "".isEmpty {
            let starRating: TelegramStarRating

            if self.context.account.peerId.id._internalGetInt64Value() == 654152421 {
                starRating = TelegramStarRating(level: -1, currentLevelStars: -1, stars: -100, nextLevelStars: 0)
            } else {
                starRating = TelegramStarRating(level: 2, currentLevelStars: 1000, stars: 2000, nextLevelStars: 3000)
            }
            self.currentStarRating = starRating

            if let _ = starRating.nextLevelStars {
                //self.currentPendingStarRating = TelegramStarPendingRating(rating: TelegramStarRating(level: starRating.level, currentLevelStars: starRating.currentLevelStars, stars: starRating.stars + 234, nextLevelStars: starRating.nextLevelStars), timestamp: Int32(Date().timeIntervalSince1970) + 60 * 60 * 24 * 3)
                self.currentPendingStarRating = TelegramStarPendingRating(rating: TelegramStarRating(level: starRating.level + 2, currentLevelStars: starRating.nextLevelStars!, stars: max(500, starRating.nextLevelStars! + starRating.nextLevelStars! / 2 - starRating.nextLevelStars! / 4), nextLevelStars: max(1000, starRating.nextLevelStars! * 2)), timestamp: Int32(Date().timeIntervalSince1970) + 60 * 60 * 24 * 3)
            }
        }
        #endif

        if let starRating = self.currentStarRating {
            let subtitleRating: ComponentView<Empty>
            var subtitleRatingTransition = ComponentTransition(transition)
            if let current = self.subtitleRating {
                subtitleRating = current
            } else {
                subtitleRatingTransition = .immediate
                subtitleRating = ComponentView()
                self.subtitleRating = subtitleRating
            }

            subtitleRatingSize = subtitleRating.update(
                transition: subtitleRatingTransition,
                component: AnyComponent(PeerInfoRatingComponent(
                    backgroundColor: ratingBackgroundColor,
                    borderColor: ratingBorderColor,
                    foregroundColor: ratingForegroundColor,
                    level: Int(starRating.level),
                    action: { [weak self] in
                        guard let self, let peer = self.peer, let currentStarRating = self.currentStarRating else {
                            return
                        }
                        self.controller?.push(ProfileLevelInfoScreen(
                            context: self.context,
                            peer: peer,
                            starRating: currentStarRating,
                            pendingStarRating: self.currentPendingStarRating,
                            customTheme: self.presentationData?.theme
                        ))
                    },
                    debugLevel: self.context.sharedContext.immediateExperimentalUISettings.debugRatingLayout
                )),
                environment: {},
                containerSize: CGSize(width: width - 12.0 * 2.0 - stripLeft - stripRight, height: 100.0)
            )
            if let subtitleRatingView = subtitleRating.view {
                if subtitleRatingView.superview == nil {
                    self.subtitleNodeContainer.view.addSubview(subtitleRatingView)
                }
            }
        } else {
            if let subtitleRating = self.subtitleRating {
                self.subtitleRating = nil
                subtitleRating.view?.removeFromSuperview()
            }
        }

        // The rating is positioned with a 1 pt overlap at the text's leading edge.
        let subtitleRatingInset = subtitleRatingSize.map { $0.width - 1.0 } ?? 0.0
        let subtitleConstrainedSize: CGSize
        let expandedSubtitleConstrainedSize: CGSize
        if self.isSettings {
            subtitleConstrainedSize = CGSize(width: max(0.0, width - stripLeft - stripRight - textSideInset * 2.0 - subtitleRatingInset), height: .greatestFiniteMagnitude)
            expandedSubtitleConstrainedSize = CGSize(width: max(0.0, width - stripLeft - stripRight - 16.0 * 2.0 - subtitleRatingInset), height: .greatestFiniteMagnitude)
        } else {
            subtitleConstrainedSize = CGSize(width: max(0.0, titleConstrainedSize.width - subtitleRatingInset), height: titleConstrainedSize.height)
            expandedSubtitleConstrainedSize = subtitleConstrainedSize
        }
        let subtitleMainState = self.isSettings && self.isAvatarExpanded ? TitleNodeStateExpanded : TitleNodeStateRegular

        let subtitleStates: [AnyHashable: MultiScaleTextState] = [
            TitleNodeStateRegular: MultiScaleTextState(attributes: subtitleAttributes, constrainedSize: subtitleConstrainedSize),
            TitleNodeStateExpanded: MultiScaleTextState(attributes: smallSubtitleAttributes, constrainedSize: expandedSubtitleConstrainedSize)
        ]
        let subtitleNodeLayout: [AnyHashable: MultiScaleTextLayout]
        if let subtitleAttributedText {
            subtitleNodeLayout = self.subtitleNode.updateLayout(attributedText: subtitleAttributedText, accessibilityText: subtitleStringText, states: subtitleStates, mainState: subtitleMainState)
        } else {
            subtitleNodeLayout = self.subtitleNode.updateLayout(text: subtitleStringText, states: subtitleStates, mainState: subtitleMainState)
        }
        self.subtitleNode.accessibilityLabel = subtitleStringText
        
        var subtitleButtonHorizontalOffset: CGFloat = 0.0
        if subtitleIsButton {
            let subtitleBackgroundNode: ASDisplayNode
            if let current = self.subtitleBackgroundNode {
                subtitleBackgroundNode = current
            } else {
                subtitleBackgroundNode = ASDisplayNode()
                self.subtitleBackgroundNode = subtitleBackgroundNode
                self.subtitleNode.insertSubnode(subtitleBackgroundNode, at: 0)
            }
            
            let subtitleBackgroundButton: HighlightTrackingButtonNode
            if let current = self.subtitleBackgroundButton {
                subtitleBackgroundButton = current
            } else {
                subtitleBackgroundButton = HighlightTrackingButtonNode()
                self.subtitleBackgroundButton = subtitleBackgroundButton
                self.subtitleNode.addSubnode(subtitleBackgroundButton)
                
                subtitleBackgroundButton.addTarget(self, action: #selector(self.subtitleBackgroundPressed), forControlEvents: .touchUpInside)
                subtitleBackgroundButton.highligthedChanged = { [weak self] highlighted in
                    guard let self else {
                        return
                    }
                    if highlighted {
                        self.subtitleNode.layer.removeAnimation(forKey: "opacity")
                        self.subtitleNode.alpha = 0.4
                    } else {
                        self.subtitleNode.alpha = 1.0
                        self.subtitleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    }
                }
            }
            
            let subtitleArrowNode: ASImageNode
            if let current = self.subtitleArrowNode {
                subtitleArrowNode = current
            } else {
                subtitleArrowNode = ASImageNode()
                self.subtitleArrowNode = subtitleArrowNode
                self.subtitleNode.insertSubnode(subtitleArrowNode, at: 1)
            }
            if subtitleArrowNode.image == nil || themeUpdated {
                subtitleArrowNode.image = generateTintedImage(image: UIImage(bundleImageName: "Item List/DisclosureArrow"), color: presentationData.theme.list.itemSecondaryTextColor)
            }
            self.subtitleNode.updateTintColor(color: presentationData.theme.list.itemSecondaryTextColor, transition: navigationTransition)
            
            transition.updateBackgroundColor(node: subtitleBackgroundNode, color: contentButtonBackgroundColor)
            let subtitleSize = subtitleNodeLayout[TitleNodeStateRegular]!.size
            var subtitleBackgroundFrame = CGRect(origin: CGPoint(), size: subtitleSize).offsetBy(dx: -subtitleSize.width * 0.5, dy: -subtitleSize.height * 0.5).insetBy(dx: -8.0, dy: -4.0)
            subtitleBackgroundFrame.size.width += 12.0
            subtitleButtonHorizontalOffset = subtitleBackgroundFrame.midX
            transition.updateFrame(node: subtitleBackgroundNode, frame: subtitleBackgroundFrame)
            transition.updateCornerRadius(node: subtitleBackgroundNode, cornerRadius: subtitleBackgroundFrame.height * 0.5)
            
            transition.updateFrame(node: subtitleBackgroundButton, frame: subtitleBackgroundFrame)
            
            if let arrowImage = subtitleArrowNode.image {
                let scaleFactor: CGFloat = 0.8
                let arrowSize = CGSize(width: floorToScreenPixels(arrowImage.size.width * scaleFactor), height: floorToScreenPixels(arrowImage.size.height * scaleFactor))
                subtitleArrowNode.frame = CGRect(origin: CGPoint(x: subtitleBackgroundFrame.maxX - arrowSize.width - 1.0, y: subtitleBackgroundFrame.minY + floor((subtitleBackgroundFrame.height - arrowSize.height) / 2.0)), size: arrowSize)
            }
        } else {
            if let subtitleBackgroundNode = self.subtitleBackgroundNode {
                self.subtitleBackgroundNode = nil
                subtitleBackgroundNode.removeFromSupernode()
            }
            if let subtitleArrowNode = self.subtitleArrowNode {
                self.subtitleArrowNode = nil
                subtitleArrowNode.removeFromSupernode()
            }
            if let subtitleBackgroundButton = self.subtitleBackgroundButton {
                self.subtitleBackgroundButton = nil
                subtitleBackgroundButton.removeFromSupernode()
            }
        }
        
        if let previousPanelStatusData = previousPanelStatusData, let currentPanelStatusData = panelStatusData.0, let previousPanelStatusDataKey = previousPanelStatusData.key, let currentPanelStatusDataKey = currentPanelStatusData.key, previousPanelStatusDataKey != currentPanelStatusDataKey {
            if let snapshotView = self.panelSubtitleNode.view.snapshotContentTree() {
                let previousIndex = screenData?.availablePanes.firstIndex(of: previousPanelStatusDataKey)
                let currentIndex = screenData?.availablePanes.firstIndex(of: currentPanelStatusDataKey)
                
                let direction: CGFloat
                if let previousIndex, let currentIndex {
                    direction = previousIndex > currentIndex ? 1.0 : -1.0
                } else {
                    direction = previousPanelStatusDataKey.rawValue > currentPanelStatusDataKey.rawValue ? 1.0 : -1.0
                }
                
                self.panelSubtitleNode.view.superview?.addSubview(snapshotView)
                snapshotView.frame = self.panelSubtitleNode.frame
                snapshotView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 100.0 * direction, y: 0.0), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true, completion: { [weak snapshotView] _ in
                    snapshotView?.removeFromSuperview()
                })
                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
                
                self.panelSubtitleNode.layer.animatePosition(from: CGPoint(x: 100.0 * direction * -1.0, y: 0.0), to: CGPoint(), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                self.panelSubtitleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            }
        }
        
        let panelSubtitleStates: [AnyHashable: MultiScaleTextState] = [
            TitleNodeStateRegular: MultiScaleTextState(attributes: panelSubtitleString?.attributes ?? subtitleAttributes, constrainedSize: subtitleConstrainedSize),
            TitleNodeStateExpanded: MultiScaleTextState(attributes: panelSubtitleString?.attributes ?? subtitleAttributes, constrainedSize: expandedSubtitleConstrainedSize)
        ]
        let panelSubtitleNodeLayout: [AnyHashable: MultiScaleTextLayout]
        if panelSubtitleString == nil, let subtitleAttributedText {
            panelSubtitleNodeLayout = self.panelSubtitleNode.updateLayout(attributedText: subtitleAttributedText, accessibilityText: subtitleStringText, states: panelSubtitleStates, mainState: subtitleMainState)
        } else {
            panelSubtitleNodeLayout = self.panelSubtitleNode.updateLayout(text: panelSubtitleString?.text ?? subtitleStringText, states: panelSubtitleStates, mainState: subtitleMainState)
        }
        self.panelSubtitleNode.accessibilityLabel = panelSubtitleString?.text ?? subtitleStringText
        
        let usernameNodeLayout = self.usernameNode.updateLayout(text: usernameString.text, states: [
            TitleNodeStateRegular: MultiScaleTextState(attributes: usernameString.attributes, constrainedSize: CGSize(width: titleConstrainedSize.width, height: titleConstrainedSize.height)),
            TitleNodeStateExpanded: MultiScaleTextState(attributes: usernameString.attributes, constrainedSize: CGSize(width: width - titleNodeLayout[TitleNodeStateExpanded]!.size.width - 8.0, height: titleConstrainedSize.height))
        ], mainState: TitleNodeStateRegular)
        self.usernameNode.accessibilityLabel = usernameString.text
        
        let avatarCenter = avatarFrame.center
        
        let titleSize = titleNodeLayout[TitleNodeStateRegular]!.size
        let titleExpandedSize = titleNodeLayout[TitleNodeStateExpanded]!.size
        let subtitleSize = subtitleNodeLayout[subtitleMainState]!.size
        var subtitleBadgeSize: CGSize?
        let _ = panelSubtitleNodeLayout[TitleNodeStateRegular]!.size
        let usernameSize = usernameNodeLayout[TitleNodeStateRegular]!.size
        
        if let statusData, statusData.isHiddenStatus, !self.isPremiumDisabled {
            let subtitleBadgeView: PeerInfoSubtitleBadgeView
            if let current = self.subtitleBadgeView {
                subtitleBadgeView = current
            } else {
                subtitleBadgeView = PeerInfoSubtitleBadgeView(action: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.displayStatusPremiumIntro?()
                })
                self.subtitleBadgeView = subtitleBadgeView
                self.subtitleNodeContainer.view.addSubview(subtitleBadgeView)
            }
            
            subtitleBadgeSize = subtitleBadgeView.update(title: presentationData.strings.PeerInfo_HiddenStatusBadge, fillColor: contentButtonBackgroundColor, foregroundColor: contentButtonForegroundColor)
        } else if let subtitleBadgeView = self.subtitleBadgeView {
            subtitleBadgeView.removeFromSuperview()
        }
        
        var titleHorizontalOffset: CGFloat = 0.0
        var titleExpandedHorizontalOffset: CGFloat = 0.0
        var nextIconX: CGFloat = titleSize.width
        var nextExpandedIconX: CGFloat = titleExpandedSize.width
        
        if let statusIconSize = self.statusIconSize, let titleExpandedStatusIconSize = self.titleExpandedStatusIconSize, statusIconSize.width > 0.0 {
            let offset = (statusIconSize.width + 4.0) / 2.0
           
            let leftOffset: CGFloat = nextIconX + 4.0
            let leftExpandedOffset: CGFloat = nextExpandedIconX + 4.0
            titleHorizontalOffset -= offset
            
            transition.updateFrame(view: self.titleStatusIconView, frame: CGRect(origin: CGPoint(x: leftOffset, y: floor((titleSize.height - statusIconSize.height) / 2.0)), size: statusIconSize))
            transition.updateFrame(view: self.titleExpandedStatusIconView, frame: CGRect(origin: CGPoint(x: leftExpandedOffset, y: floor((titleExpandedSize.height - titleExpandedStatusIconSize.height) / 2.0) + 1.0), size: titleExpandedStatusIconSize))
            
            nextIconX += 4.0 + statusIconSize.width
            nextExpandedIconX += 4.0 + titleExpandedStatusIconSize.width
        }
        
        if let credibilityIconSize = self.credibilityIconSize, let titleExpandedCredibilityIconSize = self.titleExpandedCredibilityIconSize, credibilityIconSize.width > 0.0 {
            let offset = (credibilityIconSize.width + 4.0) / 2.0
           
            let leftOffset: CGFloat = nextIconX + 4.0
            let leftExpandedOffset: CGFloat = nextExpandedIconX + 4.0
            titleHorizontalOffset -= offset
            
            transition.updateFrame(view: self.titleCredibilityIconView, frame: CGRect(origin: CGPoint(x: leftOffset, y: floor((titleSize.height - credibilityIconSize.height) / 2.0)), size: credibilityIconSize))
            transition.updateFrame(view: self.titleExpandedCredibilityIconView, frame: CGRect(origin: CGPoint(x: leftExpandedOffset, y: floor((titleExpandedSize.height - titleExpandedCredibilityIconSize.height) / 2.0) + 1.0), size: titleExpandedCredibilityIconSize))
            
            nextIconX += 4.0 + credibilityIconSize.width
            nextExpandedIconX += 4.0 + titleExpandedCredibilityIconSize.width
        }
                
        if let verifiedIconSize = self.verifiedIconSize, let titleExpandedVerifiedIconSize = self.titleExpandedVerifiedIconSize, verifiedIconSize.width > 0.0 {
            let leftOffset: CGFloat
            let leftExpandedOffset: CGFloat
            if case .verified = verifiedIcon {
                titleHorizontalOffset -= (verifiedIconSize.width + 4.0) / 2.0
                
                leftOffset = nextIconX + 4.0
                leftExpandedOffset = nextExpandedIconX + 4.0
            } else {
                titleHorizontalOffset += (verifiedIconSize.width + 4.0) / 2.0
                titleExpandedHorizontalOffset += titleExpandedVerifiedIconSize.width - 2.0
                
                leftOffset = -verifiedIconSize.width - 4.0
                leftExpandedOffset = -titleExpandedVerifiedIconSize.width - 4.0
            }
           
            transition.updateFrame(view: self.titleVerifiedIconView, frame: CGRect(origin: CGPoint(x: leftOffset, y: floor((titleSize.height - verifiedIconSize.height) / 2.0)), size: verifiedIconSize))
            transition.updateFrame(view: self.titleExpandedVerifiedIconView, frame: CGRect(origin: CGPoint(x: leftExpandedOffset, y: floor((titleExpandedSize.height - titleExpandedVerifiedIconSize.height) / 2.0) + 1.0), size: titleExpandedVerifiedIconSize))
            
            if case .verified = verifiedIcon {
                nextIconX += 4.0 + verifiedIconSize.width
                nextExpandedIconX += 4.0 + titleExpandedVerifiedIconSize.width
            }
        }
        
        var titleFrame: CGRect
        var subtitleFrame: CGRect
        let usernameFrame: CGRect
        let usernameSpacing: CGFloat = 4.0
        
        let expandedTitleScale: CGFloat = 0.8
        
        var bottomShadowHeight: CGFloat = 88.0
        if !self.isSettings && !self.isMyProfile {
            bottomShadowHeight += 100.0
        }
        let bottomShadowFrame = CGRect(origin: CGPoint(x: 0.0, y: expandedAvatarHeight - bottomShadowHeight), size: CGSize(width: width, height: bottomShadowHeight))
        transition.updateFrame(node: self.avatarListNode.listContainerNode.bottomShadowNode, frame: bottomShadowFrame, beginWithCurrentState: true)
        self.avatarListNode.listContainerNode.bottomShadowNode.update(size: bottomShadowFrame.size, transition: transition)
        
        let singleTitleLockOffset: CGFloat = ((peer?.id == self.context.account.peerId && !self.isMyProfile) || subtitleSize.height.isZero) ? 8.0 : 0.0
        
        let titleLockOffset: CGFloat = 16.0 + singleTitleLockOffset
        let titleMaxLockOffset: CGFloat = 7.0
        let titleOffset: CGFloat
        let titleCollapseFraction: CGFloat
        
        if self.isAvatarExpanded {
            let minTitleSize = CGSize(width: titleSize.width * expandedTitleScale, height: titleSize.height * expandedTitleScale)
            var minTitleFrame = CGRect(origin: CGPoint(x: 16.0 + stripLeft, y: expandedAvatarHeight - bottomInset - 58.0 - UIScreenPixel + (subtitleSize.height.isZero ? 10.0 : 0.0)), size: minTitleSize)
            if !self.isSettings && !self.isMyProfile {
                minTitleFrame.origin.y -= 83.0
            }

            titleFrame = CGRect(origin: CGPoint(x: minTitleFrame.midX - titleSize.width / 2.0, y: minTitleFrame.midY - titleSize.height / 2.0), size: titleSize)
            
            var titleCollapseOffset = titleFrame.midY - statusBarHeight - titleLockOffset
            if case .regular = metrics.widthClass, !isSettings, !isMyProfile {
                titleCollapseOffset -= 7.0
            }
            titleOffset = -min(titleCollapseOffset, contentOffset)
            titleCollapseFraction = max(0.0, min(1.0, contentOffset / titleCollapseOffset))
            
            subtitleFrame = CGRect(origin: CGPoint(x: 16.0 + stripLeft - subtitleButtonHorizontalOffset * (1.0 - titleCollapseFraction), y: minTitleFrame.maxY + 2.0), size: subtitleSize)
            subtitleFrame.origin.x += subtitleRatingInset
            if let ratingView = self.subtitleRating?.view as? PeerInfoRatingComponent.View {
                subtitleFrame.origin.x -= ratingView.visibleLeftInset
            }
            usernameFrame = CGRect(origin: CGPoint(x: width - usernameSize.width - 16.0 - stripRight, y: minTitleFrame.midY - usernameSize.height / 2.0), size: usernameSize)
        } else {
            titleFrame = CGRect(origin: CGPoint(x: hasStrip ? bandCenteredOrigin(width: titleSize.width, margin: textSideInset) : floorToScreenPixels((width - titleSize.width) / 2.0), y: avatarFrame.maxY + 9.0 + (subtitleSize.height.isZero ? 11.0 : 0.0)), size: titleSize)
            
            var titleCollapseOffset = titleFrame.midY - statusBarHeight - titleLockOffset
            if case .regular = metrics.widthClass, !isSettings, !isMyProfile {
                titleCollapseOffset -= 7.0
            }
            titleOffset = -min(titleCollapseOffset, contentOffset)
            titleCollapseFraction = max(0.0, min(1.0, contentOffset / titleCollapseOffset))
                        
            let subtitleLeadingInset = subtitleRatingInset
            var effectiveSubtitleWidth = subtitleLeadingInset + subtitleSize.width
            if let subtitleBadgeSize {
                effectiveSubtitleWidth += (subtitleBadgeSize.width + 7.0) * (1.0 - titleCollapseFraction)
            }
            
            let totalSubtitleWidth = effectiveSubtitleWidth + usernameSpacing + usernameSize.width
            if usernameSize.width == 0.0 {
                subtitleFrame = CGRect(origin: CGPoint(x: (hasStrip ? bandCenteredOrigin(width: effectiveSubtitleWidth, margin: 16.0) : floorToScreenPixels((width - effectiveSubtitleWidth) / 2.0)) + subtitleLeadingInset - subtitleButtonHorizontalOffset * (1.0 - titleCollapseFraction), y: titleFrame.maxY + 1.0), size: subtitleSize)
                usernameFrame = CGRect(origin: CGPoint(x: hasStrip ? bandCenteredOrigin(width: usernameSize.width, margin: 16.0) : floorToScreenPixels((width - usernameSize.width) / 2.0), y: subtitleFrame.maxY + 1.0), size: usernameSize)
            } else {
                subtitleFrame = CGRect(origin: CGPoint(x: (hasStrip ? bandCenteredOrigin(width: totalSubtitleWidth, margin: 16.0) : floorToScreenPixels((width - totalSubtitleWidth) / 2.0)) + subtitleLeadingInset - subtitleButtonHorizontalOffset * (1.0 - titleCollapseFraction), y: titleFrame.maxY + 1.0), size: subtitleSize)
                usernameFrame = CGRect(origin: CGPoint(x: subtitleFrame.maxX + usernameSpacing, y: titleFrame.maxY + 1.0), size: usernameSize)
            }
        }
        
        let titleMinScale: CGFloat = 0.6
        let subtitleMinScale: CGFloat = 0.8
        let avatarMinScale: CGFloat = 0.55
        
        let apparentTitleLockOffset = (1.0 - titleCollapseFraction) * 0.0 + titleCollapseFraction * titleMaxLockOffset

        let paneAreaExpansionDistance: CGFloat = 32.0
        let effectiveAreaExpansionFraction: CGFloat
        let realAreaExpansionFraction: CGFloat
        if state.isEditing {
            effectiveAreaExpansionFraction = 0.0
            realAreaExpansionFraction = effectiveAreaExpansionFraction
        } else if isSettings || isMyProfile {
            var paneAreaExpansionDelta = (self.frame.maxY - navigationHeight) - contentOffset
            paneAreaExpansionDelta = max(0.0, min(paneAreaExpansionDelta, paneAreaExpansionDistance))
            effectiveAreaExpansionFraction = 1.0 - paneAreaExpansionDelta / paneAreaExpansionDistance
            
            do {
                var paneAreaExpansionDelta = (paneContainerY - navigationHeight) - contentOffset
                paneAreaExpansionDelta = max(0.0, min(paneAreaExpansionDelta, paneAreaExpansionDistance))
                realAreaExpansionFraction = 1.0 - paneAreaExpansionDelta / paneAreaExpansionDistance
            }
        } else {
            var paneAreaExpansionDelta = (paneContainerY - navigationHeight) - contentOffset
            paneAreaExpansionDelta = max(0.0, min(paneAreaExpansionDelta, paneAreaExpansionDistance))
            effectiveAreaExpansionFraction = 1.0 - paneAreaExpansionDelta / paneAreaExpansionDistance
            realAreaExpansionFraction = effectiveAreaExpansionFraction
        }
        
        self.titleNode.update(stateFractions: [
            TitleNodeStateRegular: self.isAvatarExpanded ? 0.0 : 1.0,
            TitleNodeStateExpanded: self.isAvatarExpanded ? 1.0 : 0.0
        ], transition: transition)
        
        transition.updateAlpha(node: self.titleNode, alpha: isSearching ? 0.0 : 1.0)
        
        var subtitleAlpha: CGFloat
        var panelSubtitleAlpha: CGFloat
        var panelSubtitleOffset: CGFloat = 0.0
        if self.isSettings {
            subtitleAlpha = 1.0 - titleCollapseFraction
            panelSubtitleAlpha = 0.0
        } else {
            if (panelSubtitleString?.text ?? subtitleStringText) != subtitleStringText {
                subtitleAlpha = 1.0 - effectiveAreaExpansionFraction
                panelSubtitleAlpha = effectiveAreaExpansionFraction
                
                panelSubtitleOffset = (1.0 - effectiveAreaExpansionFraction) * 5.0
            } else {
                if effectiveAreaExpansionFraction == 1.0 {
                    subtitleAlpha = 0.0
                    panelSubtitleAlpha = 1.0
                } else {
                    subtitleAlpha = 1.0
                    panelSubtitleAlpha = 0.0
                }
            }
        }
        
        if isSearching {
            subtitleAlpha = 0.0
            panelSubtitleAlpha = 0.0
        }
        
        self.subtitleNode.update(stateFractions: [
            TitleNodeStateRegular: self.isAvatarExpanded ? 0.0 : 1.0,
            TitleNodeStateExpanded: self.isAvatarExpanded ? 1.0 : 0.0
        ], alpha: subtitleAlpha, transition: transition)

        self.panelSubtitleNode.update(stateFractions: [
            TitleNodeStateRegular: self.isAvatarExpanded ? 0.0 : 1.0,
            TitleNodeStateExpanded: self.isAvatarExpanded ? 1.0 : 0.0
        ], alpha: panelSubtitleAlpha, transition: transition)
        
        self.usernameNode.update(stateFractions: [
            TitleNodeStateRegular: self.isAvatarExpanded ? 0.0 : 1.0,
            TitleNodeStateExpanded: self.isAvatarExpanded ? 1.0 : 0.0
        ], alpha: subtitleAlpha, transition: transition)
        
        let avatarScale: CGFloat
        let avatarOffset: CGFloat
        //
        avatarScale = 1.0 * (1.0 - titleCollapseFraction) + avatarMinScale * titleCollapseFraction
        avatarOffset = apparentTitleLockOffset + 0.0 * (1.0 - titleCollapseFraction) + 10.0 * titleCollapseFraction
        
        if subtitleIsButton {
            subtitleFrame.origin.y += 11.0 * (1.0 - titleCollapseFraction)
            if let subtitleBackgroundButton = self.subtitleBackgroundButton {
                transition.updateAlpha(node: subtitleBackgroundButton, alpha: (1.0 - titleCollapseFraction))
            }
            if let subtitleBackgroundNode = self.subtitleBackgroundNode {
                transition.updateAlpha(node: subtitleBackgroundNode, alpha: (1.0 - titleCollapseFraction))
            }
            if let subtitleArrowNode = self.subtitleArrowNode {
                transition.updateAlpha(node: subtitleArrowNode, alpha: (1.0 - titleCollapseFraction))
            }
        }
                
        let avatarCornerRadius: CGFloat = isForum ? floor(avatarSize * 0.25) : avatarSize / 2.0
 
        if self.isAvatarExpanded {
            self.avatarListNode.listContainerNode.isHidden = false
            transition.updateCornerRadius(node: self.avatarListNode.listContainerNode, cornerRadius: 0.0)
            transition.updateCornerRadius(node: self.avatarListNode.listContainerNode.controlsClippingNode, cornerRadius: 0.0)
        } else if self.avatarListNode.listContainerNode.cornerRadius != avatarCornerRadius {
            transition.updateCornerRadius(node: self.avatarListNode.listContainerNode.controlsClippingNode, cornerRadius: avatarCornerRadius)
            transition.updateCornerRadius(node: self.avatarListNode.listContainerNode, cornerRadius: avatarCornerRadius, completion: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.avatarListNode.avatarContainerNode.canAttachVideo = true
                strongSelf.avatarListNode.listContainerNode.isHidden = true
                if !strongSelf.skipCollapseCompletion {
                    DispatchQueue.main.async {
                        strongSelf.avatarListNode.listContainerNode.isCollapsing = false
                    }
                }
            })
        }
        
        self.avatarListNode.update(size: CGSize(), avatarSize: avatarSize, isExpanded: self.isAvatarExpanded, peer: peer, isForum: isForum, threadId: self.forumTopicThreadId, threadInfo: threadData?.info, theme: presentationData.theme, transition: transition)
        self.editingContentNode.avatarNode.update(peer: peer, threadData: threadData, chatLocation: self.chatLocation, item: self.avatarListNode.item, updatingAvatar: state.updatingAvatar, uploadProgress: state.avatarUploadProgress, theme: presentationData.theme, avatarSize: avatarSize, isEditing: state.isEditing)
        self.avatarOverlayNode.update(peer: peer, threadData: threadData, chatLocation: self.chatLocation, item: self.avatarListNode.item, updatingAvatar: state.updatingAvatar, uploadProgress: state.avatarUploadProgress, theme: presentationData.theme, avatarSize: avatarSize, isEditing: state.isEditing)
        if additive {
            transition.updateSublayerTransformScaleAdditive(node: self.avatarListNode.avatarContainerNode, scale: avatarScale)
            transition.updateSublayerTransformScaleAdditive(node: self.avatarOverlayNode, scale: avatarScale)
        } else {
            transition.updateSublayerTransformScale(node: self.avatarListNode.avatarContainerNode, scale: avatarScale)
            transition.updateSublayerTransformScale(node: self.avatarOverlayNode, scale: avatarScale)
        }
        
        if let avatarStoryView = self.avatarListNode.avatarContainerNode.avatarStoryView?.view {
            transition.updateAlpha(layer: avatarStoryView.layer, alpha: 1.0)
        }
        
        // Where the round avatar is, or would be with the photo collapsed (an expansion's circle flies there on its way
        // into the expanded photo).
        var roundAvatarSize = avatarFrame.size
        if let storyStats = self.avatarListNode.avatarContainerNode.avatarNode.storyStats, storyStats.totalCount != 0 {
            roundAvatarSize.width -= 3.0 * 4.0
            roundAvatarSize.height -= 3.0 * 4.0
        }
        let roundAvatarFrame = CGRect(origin: CGPoint(x: avatarCenter.x - roundAvatarSize.width / 2.0, y: -contentOffset + avatarOffset + avatarCenter.y - roundAvatarSize.height / 2.0), size: roundAvatarSize)
        self.expansionRoundAvatarFrame = roundAvatarFrame

        var apparentAvatarFrame: CGRect
        var apparentAvatarListFrame: CGRect
        let controlsClippingFrame: CGRect
        if self.isAvatarExpanded {
            let expandedAvatarCenter = CGPoint(x: expandedAvatarListSize.width / 2.0, y: expandedAvatarListSize.width / 2.0 - contentOffset / 2.0)
            apparentAvatarFrame = CGRect(origin: expandedAvatarCenter, size: CGSize())
            
            let expandedAvatarListCenter = CGPoint(x: expandedAvatarListSize.width / 2.0, y: expandedAvatarListSize.height / 2.0 - contentOffset / 2.0)
            apparentAvatarListFrame = CGRect(origin: expandedAvatarListCenter, size: CGSize())
            
            controlsClippingFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: expandedAvatarListSize)
        } else {
            apparentAvatarFrame = roundAvatarFrame
            apparentAvatarListFrame = apparentAvatarFrame
            controlsClippingFrame = apparentAvatarFrame
        }
                
        let _ = apparentAvatarListFrame
        transition.updateFrameAdditive(node: self.avatarListNode, frame: CGRect(origin: apparentAvatarFrame.center, size: CGSize()))
        transition.updateFrameAdditive(node: self.avatarOverlayNode, frame: CGRect(origin: apparentAvatarFrame.center, size: CGSize()))
        
        var avatarListContainerFrame: CGRect
        let avatarListContainerScale: CGFloat
        var avatarListVerticalOffset: CGFloat = 0.0
        if self.isAvatarExpanded {
            avatarListContainerFrame = CGRect(origin: CGPoint(x: -expandedAvatarListSize.width / 2.0, y: -expandedAvatarListSize.width / 2.0), size: expandedAvatarListSize)
            avatarListContainerScale = 1.0 + max(0.0, -contentOffset / avatarListContainerFrame.width)
            // Keep the scaled avatar's bottom edge aligned with the stretched header.
            avatarListVerticalOffset = (avatarListContainerFrame.width - avatarListContainerFrame.height) * (avatarListContainerScale - 1.0)
        } else {
            let expandHeightFraction = expandedAvatarListSize.height / expandedAvatarListSize.width
            avatarListContainerFrame = CGRect(origin: CGPoint(x: -apparentAvatarFrame.width / 2.0, y: -apparentAvatarFrame.width / 2.0 + expandHeightFraction * 0.0 * apparentAvatarFrame.width), size: apparentAvatarFrame.size)
            avatarListContainerScale = avatarScale
        }
        transition.updateFrame(node: self.avatarListNode.listContainerNode, frame: avatarListContainerFrame)
        
        let avatarClipOffset: CGFloat = !self.isAvatarExpanded && deviceMetrics.hasDynamicIsland && statusBarHeight > 0.0 && self.avatarClippingNode.clipsToBounds && !isLandscape ? 47.0 : 0.0
        let clippingNodeTransition = ContainedViewLayoutTransition.immediate
        clippingNodeTransition.updateFrame(layer: self.avatarClippingNode.layer, frame: CGRect(origin: CGPoint(x: 0.0, y: avatarClipOffset + avatarListVerticalOffset), size: CGSize(width: width, height: 1000.0)))
        clippingNodeTransition.updateSublayerTransformOffset(layer: self.avatarClippingNode.layer, offset: CGPoint(x: 0.0, y: -avatarClipOffset))
        let clippingNodeRadiusTransition = ContainedViewLayoutTransition.animated(duration: 0.15, curve: .easeInOut)
        clippingNodeRadiusTransition.updateCornerRadius(node: self.avatarClippingNode, cornerRadius: avatarClipOffset > 0.0 ? width / 2.5 : 0.0)
        
        let innerScale = avatarListContainerFrame.width / expandedAvatarListSize.width
        let innerDeltaX = (avatarListContainerFrame.width - expandedAvatarListSize.width) / 2.0
        var innerDeltaY = (avatarListContainerFrame.height - expandedAvatarListSize.height) / 2.0
        if !self.isAvatarExpanded {
            innerDeltaY += (expandedAvatarListSize.height - expandedAvatarListSize.width) * 0.5
        }
        transition.updateSublayerTransformScale(node: self.avatarListNode.listContainerNode, scale: innerScale)
        transition.updateFrameAdditive(node: self.avatarListNode.listContainerNode.contentNode, frame: CGRect(origin: CGPoint(x: innerDeltaX + expandedAvatarListSize.width / 2.0, y: innerDeltaY + expandedAvatarListSize.height / 2.0), size: CGSize()))
        self.avatarListNode.listContainerNode.contentNode.update(size: expandedAvatarListSize)
        
        transition.updateFrameAdditive(node: self.avatarListNode.listContainerNode.controlsClippingOffsetNode, frame: CGRect(origin: controlsClippingFrame.center, size: CGSize()))
        transition.updateFrame(node: self.avatarListNode.listContainerNode.controlsClippingNode, frame: CGRect(origin: CGPoint(x: -controlsClippingFrame.width / 2.0, y: -controlsClippingFrame.height / 2.0), size: controlsClippingFrame.size))
        transition.updateFrameAdditive(node: self.avatarListNode.listContainerNode.controlsContainerNode, frame: CGRect(origin: CGPoint(x: -controlsClippingFrame.minX, y: -controlsClippingFrame.minY), size: CGSize(width: expandedAvatarListSize.width, height: expandedAvatarListSize.height)))
        
        transition.updateFrame(node: self.avatarListNode.listContainerNode.topShadowNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: expandedAvatarListSize.width, height: navigationHeight + 20.0)))
        transition.updateFrame(node: self.avatarListNode.listContainerNode.stripContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: statusBarHeight < 25.0 ? (statusBarHeight + 2.0) : (statusBarHeight - 3.0)), size: CGSize(width: expandedAvatarListSize.width, height: 2.0)))
        transition.updateFrame(node: self.avatarListNode.listContainerNode.highlightContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: expandedAvatarListSize.width, height: expandedAvatarListSize.height)))
        transition.updateAlpha(node: self.avatarListNode.listContainerNode.controlsContainerNode, alpha: self.isAvatarExpanded ? 1.0 : 0.0)
        
        if additive {
            transition.updateSublayerTransformScaleAdditive(node: self.avatarListNode.listContainerTransformNode, scale: avatarListContainerScale)
        } else {
            transition.updateSublayerTransformScale(node: self.avatarListNode.listContainerTransformNode, scale: avatarListContainerScale)
        }
        
        if deviceMetrics.hasDynamicIsland && statusBarHeight > 0.0 && self.forumTopicThreadId == nil && !isLandscape {
            let maskValue = max(0.0, min(1.0, contentOffset / 120.0))
            self.avatarListNode.containerNode.view.mask = self.avatarListNode.maskNode.view
            if maskValue > 0.03 {
                self.avatarListNode.bottomCoverNode.isHidden = false
                self.avatarListNode.topCoverNode.isHidden = false
                self.avatarListNode.maskNode.backgroundColor = .clear
            } else {
                self.avatarListNode.bottomCoverNode.isHidden = true
                self.avatarListNode.topCoverNode.isHidden = true
                self.avatarListNode.maskNode.backgroundColor = .white
            }
            self.avatarListNode.topCoverNode.update(maskValue)
            self.avatarListNode.maskNode.update(maskValue)
            self.avatarListNode.bottomCoverNode.backgroundColor = UIColor(white: 0.0, alpha: maskValue)
            
            self.avatarListNode.listContainerNode.topShadowNode.isHidden = !self.isAvatarExpanded
            
            var avatarMaskOffset: CGFloat = 0.0
            if contentOffset < 0.0 {
                avatarMaskOffset -= contentOffset
            }
            
            self.avatarListNode.maskNode.position = CGPoint(x: 0.0, y: -self.avatarListNode.frame.minY + 48.0 + 85.0 + avatarMaskOffset)
            self.avatarListNode.maskNode.bounds = CGRect(origin: .zero, size: CGSize(width: 171.0, height: 171.0))
            
            self.avatarListNode.bottomCoverNode.position = self.avatarListNode.maskNode.position
            self.avatarListNode.bottomCoverNode.bounds = self.avatarListNode.maskNode.bounds
            
            self.avatarListNode.topCoverNode.position = self.avatarListNode.maskNode.position
            self.avatarListNode.topCoverNode.bounds = self.avatarListNode.maskNode.bounds
        } else {
            self.avatarListNode.bottomCoverNode.isHidden = true
            self.avatarListNode.topCoverNode.isHidden = true
            self.avatarListNode.containerNode.view.mask = nil
        }
        
        self.avatarListNode.listContainerNode.update(size: expandedAvatarListSize, peer: peer, isExpanded: self.isAvatarExpanded, transition: transition)
        if self.avatarListNode.listContainerNode.isCollapsing && !self.ignoreCollapse {
            self.avatarListNode.avatarContainerNode.canAttachVideo = false
        }
        
        if currentWalletBalance != nil && !self.isAvatarExpanded && !self.isSettings {
            let balanceBottom = max(subtitleFrame.maxY, usernameFrame.maxY) + 8.0 + 20.0
            let contentBelowBalance: CGFloat = self.isMyProfile ? 16.0 : 12.0 + 58.0 + 16.0
            let existingHeaderExtension: CGFloat = self.isMyProfile ? 20.0 : 99.0
            panelWithAvatarHeight = balanceBottom + contentBelowBalance - navigationHeight - existingHeaderExtension
        }

        let rawHeight: CGFloat
        let height: CGFloat
        let maxY: CGFloat
        let backgroundHeight: CGFloat
        if self.isAvatarExpanded {
            rawHeight = expandedAvatarHeight
            height = max(navigationHeight, rawHeight - contentOffset)
            maxY = height - 98.0
            backgroundHeight = height
        } else {
            rawHeight = navigationHeight + panelWithAvatarHeight
            var expandablePart: CGFloat = panelWithAvatarHeight - contentOffset
            if self.isSettings || self.isMyProfile {
                expandablePart += 20.0
            } else {
                if case let .replyThread(replyThreadMessage) = self.chatLocation, replyThreadMessage.peerId == self.context.account.peerId {
                    expandablePart = 0.0
                } else if peer?.id == self.context.account.peerId && !self.isMyProfile {
                    expandablePart = 0.0
                } else {
                    expandablePart += 99.0
                }
            }
            expandablePart += bottomInset
            height = navigationHeight + max(0.0, expandablePart)
            maxY = navigationHeight + panelWithAvatarHeight - contentOffset
            backgroundHeight = height
        }
        let _ = maxY
        
        let apparentHeight = backgroundHeight
        let apparentBackgroundHeight = backgroundHeight
        
        if !titleSize.width.isZero && !titleSize.height.isZero {
            let titleScale: CGFloat
            let subtitleScale: CGFloat
            var subtitleOffset: CGFloat = 0.0
            let subtitleBadgeFraction: CGFloat
            if self.isAvatarExpanded {
                titleScale = expandedTitleScale
                subtitleScale = 1.0
                subtitleBadgeFraction = 1.0
            } else {
                titleScale = (1.0 - titleCollapseFraction) * 1.0 + titleCollapseFraction * titleMinScale
                subtitleScale = (1.0 - titleCollapseFraction) * 1.0 + titleCollapseFraction * subtitleMinScale
                subtitleOffset = titleCollapseFraction * -1.0
                subtitleBadgeFraction = (1.0 - titleCollapseFraction)
            }
            
            let rawTitleFrame = titleFrame.offsetBy(dx: self.isAvatarExpanded ? titleExpandedHorizontalOffset : titleHorizontalOffset * titleScale, dy: 0.0)
            self.titleNodeRawContainer.frame = rawTitleFrame
            transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(), size: CGSize()))
            let rawSubtitleFrame = subtitleFrame
            self.subtitleNodeRawContainer.frame = rawSubtitleFrame
            let rawUsernameFrame = usernameFrame
            self.usernameNodeRawContainer.frame = rawUsernameFrame
            if self.isAvatarExpanded {
                transition.updateFrameAdditive(node: self.titleNodeContainer, frame: CGRect(origin: rawTitleFrame.center, size: CGSize()).offsetBy(dx: 0.0, dy: titleOffset + apparentTitleLockOffset))
                transition.updateFrameAdditive(node: self.subtitleNodeContainer, frame: CGRect(origin: rawSubtitleFrame.center, size: CGSize()).offsetBy(dx: 0.0, dy: titleOffset))
                transition.updateFrameAdditive(node: self.usernameNodeContainer, frame: CGRect(origin: rawUsernameFrame.center, size: CGSize()).offsetBy(dx: 0.0, dy: titleOffset))
            } else {
                transition.updateFrameAdditiveToCenter(node: self.titleNodeContainer, frame: CGRect(origin: rawTitleFrame.center, size: CGSize()).offsetBy(dx: 0.0, dy: titleOffset + apparentTitleLockOffset))
                
                var subtitleCenter = rawSubtitleFrame.center
                subtitleCenter.x = rawTitleFrame.center.x + (subtitleCenter.x - rawTitleFrame.center.x) * subtitleScale
                subtitleCenter.y += subtitleOffset
                transition.updateFrameAdditiveToCenter(node: self.subtitleNodeContainer, frame: CGRect(origin: subtitleCenter, size: CGSize()).offsetBy(dx: 0.0, dy: titleOffset))
                
                var usernameCenter = rawUsernameFrame.center
                usernameCenter.x = rawTitleFrame.center.x + (usernameCenter.x - rawTitleFrame.center.x) * subtitleScale
                transition.updateFrameAdditiveToCenter(node: self.usernameNodeContainer, frame: CGRect(origin: usernameCenter, size: CGSize()).offsetBy(dx: 0.0, dy: titleOffset))
            }
            transition.updatePosition(node: self.subtitleNode, position: CGPoint(x: 0.0, y: subtitleOffset))
            transition.updateFrame(node: self.panelSubtitleNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelSubtitleOffset - 1.0), size: CGSize()))
            transition.updateFrame(node: self.usernameNode, frame: CGRect(origin: CGPoint(), size: CGSize()))
            transition.updateSublayerTransformScaleAdditive(node: self.titleNodeContainer, scale: titleScale)
            transition.updateSublayerTransformScaleAdditive(node: self.subtitleNodeContainer, scale: subtitleScale)
            transition.updateSublayerTransformScaleAdditive(node: self.usernameNodeContainer, scale: subtitleScale)
            
            if let subtitleBadgeView = self.subtitleBadgeView, let subtitleBadgeSize {
                let subtitleBadgeFrame = CGRect(origin: CGPoint(x: (subtitleSize.width + 8.0) * 0.5, y: floor((-subtitleBadgeSize.height) * 0.5)), size: subtitleBadgeSize)
                transition.updateFrameAdditive(view: subtitleBadgeView, frame: subtitleBadgeFrame)
                transition.updateAlpha(layer: subtitleBadgeView.layer, alpha: subtitleBadgeFraction)
            }
            
            if let subtitleRatingView = self.subtitleRating?.view, let subtitleRatingSize {
                let subtitleBadgeFrame = CGRect(origin: CGPoint(x: (-subtitleSize.width) * 0.5 - subtitleRatingInset, y: floor((-subtitleRatingSize.height) * 0.5)), size: subtitleRatingSize)
                
                if subtitleRatingView.frame.isEmpty {
                    subtitleRatingView.frame = subtitleBadgeFrame
                    subtitleRatingView.alpha = subtitleAlpha
                } else {
                    transition.updateFrameAdditive(view: subtitleRatingView, frame: subtitleBadgeFrame)
                    transition.updateAlpha(layer: subtitleRatingView.layer, alpha: subtitleAlpha)
                }
            }
        }
        
        if displayStandardTitle {
            self.titleNode.isHidden = true
            
            let standardTitle: ComponentView<Empty>
            if let current = self.standardTitle {
                standardTitle = current
            } else {
                standardTitle = ComponentView()
                self.standardTitle = standardTitle
            }
            
            let titleSize = standardTitle.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleStringText, font: Font.semibold(17.0), textColor: navigationContentsPrimaryColor))
                )),
                environment: {},
                containerSize: CGSize(width: width, height: navigationHeight)
            )
            if let standardTitleView = standardTitle.view {
                if standardTitleView.superview == nil {
                    self.regularContentNode.view.addSubview(standardTitleView)
                }
                let standardTitleFrame = titleSize.centered(in: self.titleNodeContainer.frame).offsetBy(dx: 2.0, dy: 0.0)
                standardTitleView.frame = standardTitleFrame
            }
        } else {
            if let standardTitle = self.standardTitle {
                self.standardTitle = nil
                standardTitle.view?.removeFromSuperview()
                
                self.titleNode.isHidden = false
            }
        }
        
        let buttonsTransitionDistance: CGFloat = -min(0.0, apparentBackgroundHeight - backgroundHeight)
        let buttonsTransitionDistanceNorm: CGFloat = 40.0
        
        let innerContentOffset = max(0.0, contentOffset - 140.0)
        let backgroundTransitionFraction: CGFloat = 1.0 - max(0.0, min(1.0, innerContentOffset / 30.0))
        
        let innerButtonsTransitionStepDistance: CGFloat = 58.0
        let innerButtonsTransitionStepInset: CGFloat = 28.0
        let innerButtonsTransitionDistance: CGFloat = navigationHeight + panelWithAvatarHeight - innerButtonsTransitionStepDistance - innerButtonsTransitionStepInset
        let innerButtonsContentOffset = max(0.0, contentOffset - innerButtonsTransitionDistance)
        let innerButtonsTransitionFraction = max(0.0, min(1.0, innerButtonsContentOffset / innerButtonsTransitionStepDistance))
        
        let buttonsTransitionFraction: CGFloat = 1.0 - max(0.0, min(1.0, buttonsTransitionDistance / buttonsTransitionDistanceNorm))
        
        let buttonSpacing: CGFloat = 8.0
        let buttonSideInset = max(16.0, containerInset)
        
        let actionButtonWidth = (width - stripLeft - stripRight - buttonSideInset * 2.0 + buttonSpacing) / CGFloat(actionButtonKeys.count) - buttonSpacing
        let actionButtonSize = CGSize(width: actionButtonWidth, height: 40.0)
        var actionButtonRightOrigin = CGPoint(x: width - stripRight - buttonSideInset, y: backgroundHeight - 16.0 - actionButtonSize.height)
        
        for buttonKey in actionButtonKeys.reversed() {
            let buttonNode: PeerInfoHeaderActionButtonNode
            var wasAdded = false
            if let current = self.actionButtonNodes[buttonKey] {
                buttonNode = current
            } else {
                wasAdded = true
                buttonNode = PeerInfoHeaderActionButtonNode(key: buttonKey, action: { [weak self] buttonNode, gesture in
                    self?.actionButtonPressed(buttonNode, gesture: gesture)
                })
                self.actionButtonNodes[buttonKey] = buttonNode
                self.buttonsContainerNode.addSubnode(buttonNode)
            }
            
            let buttonFrame = CGRect(origin: CGPoint(x: actionButtonRightOrigin.x - actionButtonSize.width, y: actionButtonRightOrigin.y), size: actionButtonSize)
            let buttonTransition: ContainedViewLayoutTransition = wasAdded ? .immediate : transition
            
            if additive {
                buttonTransition.updateFrameAdditiveToCenter(node: buttonNode, frame: buttonFrame)
            } else {
                buttonTransition.updateFrame(node: buttonNode, frame: buttonFrame)
            }
            let buttonText: String
            switch buttonKey {
            case .message:
                buttonText = "Message"
            case .addContact:
                buttonText = "Add"
            default:
                fatalError()
            }
            
            buttonNode.update(size: buttonFrame.size, text: buttonText, presentationData: presentationData, transition: buttonTransition)
            
            if wasAdded {
                buttonNode.alpha = 0.0
            }
            transition.updateAlpha(node: buttonNode, alpha: 1.0)
            actionButtonRightOrigin.x -= actionButtonSize.width + buttonSpacing
        }
        
        for key in self.actionButtonNodes.keys {
            if !actionButtonKeys.contains(key) {
                if let buttonNode = self.actionButtonNodes[key] {
                    self.actionButtonNodes.removeValue(forKey: key)
                    transition.updateAlpha(node: buttonNode, alpha: 0.0) { [weak buttonNode] _ in
                        buttonNode?.removeFromSupernode()
                    }
                }
            }
        }
        
        let buttonWidth = (width - stripLeft - stripRight - buttonSideInset * 2.0 + buttonSpacing) / CGFloat(buttonKeys.count) - buttonSpacing
        let buttonSize = CGSize(width: buttonWidth, height: 58.0)
        var buttonRightOrigin = CGPoint(x: width - stripRight - buttonSideInset, y: backgroundHeight - bottomInset - 16.0 - buttonSize.height)
        if !actionButtonKeys.isEmpty {
            buttonRightOrigin.y += actionButtonSize.height + 24.0
        }
        
        transition.updateFrameAdditive(node: self.buttonsBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: buttonRightOrigin.y), size: CGSize(width: width, height: buttonSize.height + 40.0)))
        self.buttonsBackgroundNode.update(size: self.buttonsBackgroundNode.bounds.size, transition: transition)
        self.buttonsBackgroundNode.updateColor(color: contentButtonBackgroundColor, enableBlur: true, transition: transition)
        if isReduceTransparencyEnabled() {
            self.buttonsBackgroundNode.alpha = 0.1
        }
        
        for buttonKey in buttonKeys.reversed() {
            let buttonNode: PeerInfoHeaderButtonNode
            var wasAdded = false
            if let current = self.buttonNodes[buttonKey] {
                buttonNode = current
            } else {
                wasAdded = true
                buttonNode = PeerInfoHeaderButtonNode(key: buttonKey, action: { [weak self] buttonNode, gesture in
                    self?.buttonPressed(buttonNode, gesture: gesture)
                })
                self.buttonNodes[buttonKey] = buttonNode
                self.buttonsContainerNode.addSubnode(buttonNode)
                self.buttonsMaskView.addSubview(buttonNode.backgroundContainerView)
                buttonNode.contextMenuSourceContainer = self.buttonsContainerNode.view
            }
            
            let buttonFrame = CGRect(origin: CGPoint(x: buttonRightOrigin.x - buttonSize.width, y: buttonRightOrigin.y), size: buttonSize)
            let buttonTransition: ContainedViewLayoutTransition = wasAdded ? .immediate : transition
            
            if additive {
                buttonTransition.updateFrameAdditiveToCenter(node: buttonNode, frame: buttonFrame)
            } else {
                buttonTransition.updateFrame(node: buttonNode, frame: buttonFrame)
            }
            buttonTransition.updateFrame(view: buttonNode.backgroundContainerView, frame: buttonFrame.offsetBy(dx: 0.0, dy: -buttonFrame.minY))
            
            let buttonText: String
            let buttonIcon: PeerInfoHeaderButtonIcon
            switch buttonKey {
            case .message:
                buttonText = presentationData.strings.PeerInfo_ButtonMessage
                buttonIcon = .message
            case .discussion:
                buttonText = presentationData.strings.PeerInfo_ButtonDiscuss
                buttonIcon = .message
            case .call:
                buttonText = presentationData.strings.PeerInfo_ButtonCall
                buttonIcon = .call
            case .videoCall:
                buttonText = presentationData.strings.PeerInfo_ButtonVideoCall
                buttonIcon = .videoCall
            case .voiceChat:
                if case let .channel(channel) = peer, case .broadcast = channel.info {
                    buttonText = presentationData.strings.PeerInfo_ButtonLiveStream
                } else {
                    buttonText = presentationData.strings.PeerInfo_ButtonVoiceChat
                }
                buttonIcon = .voiceChat
            case .mute:
                let chatIsMuted = peerInfoIsChatMuted(peer: peer, peerNotificationSettings: peerNotificationSettings, threadNotificationSettings: threadNotificationSettings, globalNotificationSettings: globalNotificationSettings)
                if chatIsMuted {
                    buttonText = presentationData.strings.PeerInfo_ButtonUnmute
                    buttonIcon = .unmute
                } else {
                    buttonText = presentationData.strings.PeerInfo_ButtonMute
                    buttonIcon = .mute
                }
            case .more:
                buttonText = presentationData.strings.PeerInfo_ButtonMore
                buttonIcon = .more
            case .addMember:
                buttonText = presentationData.strings.PeerInfo_ButtonAddMember
                buttonIcon = .addMember
            case .search:
                buttonText = presentationData.strings.PeerInfo_ButtonSearch
                buttonIcon = .search
            case .leave:
                buttonText = presentationData.strings.PeerInfo_ButtonLeave
                buttonIcon = .leave
            case .stop:
                buttonText = presentationData.strings.PeerInfo_ButtonStop
                buttonIcon = .stop
            case .addContact:
                fatalError()
            }
            
            var isActive = true
            if let highlightedButton = state.highlightedButton {
                isActive = buttonKey == highlightedButton
            }
            
            buttonNode.update(size: buttonFrame.size, text: buttonText, icon: buttonIcon, isActive: isActive, presentationData: presentationData, backgroundColor: contentButtonBackgroundColor, foregroundColor: contentButtonForegroundColor, fraction: 1.0 - innerButtonsTransitionFraction, transition: buttonTransition)
            
            if wasAdded {
                buttonNode.alpha = 0.0
                buttonNode.backgroundContainerView.alpha = 0.0
            }
            transition.updateAlpha(node: buttonNode, alpha: buttonsTransitionFraction)
            transition.updateAlpha(layer: buttonNode.backgroundContainerView.layer, alpha: buttonsTransitionFraction)
            
            if case .mute = buttonKey, buttonNode.containerNode.alpha.isZero, additive {
                if case let .animated(duration, curve) = transition {
                    ContainedViewLayoutTransition.animated(duration: duration * 0.3, curve: curve).updateAlpha(node: buttonNode.containerNode, alpha: 1.0)
                } else {
                    transition.updateAlpha(node: buttonNode.containerNode, alpha: 1.0)
                }
            } else {
                transition.updateAlpha(node: buttonNode.containerNode, alpha: 1.0)
            }
            buttonRightOrigin.x -= buttonSize.width + buttonSpacing
        }
        
        for key in self.buttonNodes.keys {
            if !buttonKeys.contains(key) {
                if let buttonNode = self.buttonNodes[key] {
                    self.buttonNodes.removeValue(forKey: key)
                    transition.updateAlpha(layer: buttonNode.backgroundContainerView.layer, alpha: 0.0)
                    transition.updateAlpha(node: buttonNode, alpha: 0.0) { [weak buttonNode] _ in
                        buttonNode?.backgroundContainerView.removeFromSuperview()
                        buttonNode?.removeFromSupernode()
                    }
                }
            }
        }
        
        let resolvedRegularHeight: CGFloat
        if self.isAvatarExpanded {
            resolvedRegularHeight = expandedAvatarListSize.height
        } else {
            resolvedRegularHeight = panelWithAvatarHeight + navigationHeight + bottomInset
        }
        
        let backgroundFrame: CGRect
        
        var resolvedHeight: CGFloat
        
        if state.isEditing {
            resolvedHeight = editingContentHeight
            backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: -2000.0 + max(navigationHeight, resolvedHeight - contentOffset)), size: CGSize(width: width, height: 2000.0))
        } else {
            resolvedHeight = resolvedRegularHeight
            backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: -2000.0 + apparentHeight), size: CGSize(width: width, height: 2000.0))
        }
        
        transition.updateFrame(node: self.regularContentNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: resolvedHeight)))
        
        transition.updateFrameAdditive(node: self.buttonsContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: apparentBackgroundHeight - backgroundHeight), size: CGSize(width: width, height: 1000.0)))
        
        navigationTransition.updateAlpha(node: self.buttonsContainerNode, alpha: backgroundBannerAlpha)
        
        let bannerInset: CGFloat = 3.0
        let bannerFrame = CGRect(origin: CGPoint(x: -bannerInset, y: -2000.0 + apparentBackgroundHeight), size: CGSize(width: width + bannerInset * 2.0, height: 2000.0))
        
        if additive {
            transition.updateFrameAdditive(view: self.backgroundBannerView, frame: bannerFrame)
        } else {
            transition.updateFrame(view: self.backgroundBannerView, frame: bannerFrame)
        }
                        
        let backgroundCoverSize = self.backgroundCover.update(
            transition: ComponentTransition(transition),
            component: AnyComponent(PeerInfoCoverComponent(
                context: self.context,
                subject: backgroundCoverSubject,
                files: [:],
                isDark: presentationData.theme.overallDarkAppearance,
                avatarCenter: apparentAvatarFrame.center.offsetBy(dx: bannerInset, dy: 0.0),
                avatarSize: apparentAvatarFrame.size,
                avatarScale: avatarScale,
                defaultHeight: backgroundDefaultHeight,
                gradientCenter: CGPoint(x: 0.5, y: buttonKeys.isEmpty ? 0.5 : 0.45),
                avatarTransitionFraction: max(0.0, min(1.0, titleCollapseFraction)),
                patternTransitionFraction: buttonsTransitionFraction * backgroundTransitionFraction
            )),
            environment: {},
            containerSize: CGSize(width: width + bannerInset * 2.0, height: apparentBackgroundHeight + bannerInset)
        )
        if let backgroundCoverView = self.backgroundCover.view as? PeerInfoCoverComponent.View {
            if backgroundCoverView.superview == nil {
                self.backgroundBannerView.addSubview(backgroundCoverView)
            }
            if additive {
                transition.updateFrameAdditive(view: backgroundCoverView, frame: CGRect(origin: CGPoint(x: -bannerInset, y: bannerFrame.height - backgroundCoverSize.height), size: backgroundCoverSize))
            } else {
                transition.updateFrame(view: backgroundCoverView, frame: CGRect(origin: CGPoint(x: -bannerInset, y: bannerFrame.height - backgroundCoverSize.height), size: backgroundCoverSize))
            }
            if backgroundCoverAnimateIn {
                if !self.isAvatarExpanded {
                    backgroundCoverView.willAnimateIn()
                    Queue.mainQueue().after(0.2) {
                        backgroundCoverView.animateIn()
                    }
                }
                Queue.mainQueue().after(0.5) {
                    self.invokeDisplayGiftInfo()
                }
            }
        }
        
        if let profileGiftsContext, let peer {
            let giftsCoverSize = self.giftsCover.update(
                transition: ComponentTransition(transition),
                component: AnyComponent(PeerInfoGiftsCoverComponent(
                    context: self.context,
                    peerId: peer.id,
                    giftsContext: profileGiftsContext,
                    hasBackground: hasBackground,
                    avatarCenter: apparentAvatarFrame.center,
                    avatarSize: apparentAvatarFrame.size,
                    defaultHeight: backgroundDefaultHeight,
                    avatarTransitionFraction: max(0.0, min(1.0, titleCollapseFraction)),
                    statusBarHeight: statusBarHeight,
                    topLeftButtonsSize: CGSize(width: (self.isSettings ? 57.0 : 47.0), height: 46.0),
                    topRightButtonsSize: CGSize(width: 76.0 + (self.isMyProfile ? 38.0 : 0.0), height: 46.0),
                    titleWidth: max(140.0, titleFrame.width) + 42.0,
                    titleCenterX: hasStrip ? titleFrame.midX : nil,
                    sideInsets: sideInsets,
                    bottomHeight: !buttonKeys.isEmpty ? 81.0 : 30.0,
                    action: { [weak self] gift in
                        guard let self, case let .unique(gift) = gift.gift else {
                            return
                        }
                        self.openUniqueGift?(self.view, gift.slug)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: width, height: apparentBackgroundHeight)
            )
            if let giftsCoverView = self.giftsCover.view as? PeerInfoGiftsCoverComponent.View {
                if giftsCoverView.superview == nil {
                    self.view.insertSubview(giftsCoverView, aboveSubview: self.backgroundBannerView)
                }
                if additive {
                    transition.updateFrameAdditive(view: giftsCoverView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: giftsCoverSize))
                } else {
                    transition.updateFrame(view: giftsCoverView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: giftsCoverSize))
                }
                navigationTransition.updateAlpha(layer: giftsCoverView.layer, alpha: backgroundBannerAlpha)
                if backgroundCoverAnimateIn {
                    if !self.isAvatarExpanded {
                        giftsCoverView.willAnimateIn()
                        Queue.mainQueue().after(0.2) {
                            giftsCoverView.animateIn()
                        }
                    }
                }
            }
        }
        
        let edgeEffectHeight: CGFloat = 60.0
        var edgeEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: -50.0), size: CGSize(width: backgroundFrame.width, height: navigationHeight + 18.0 + 50.0))
        edgeEffectFrame.origin.y += floorToScreenPixels(realAreaExpansionFraction * 50.0)
        
        if additive {
            transition.updateFrameAdditive(layer: self.headerEdgeEffectView.layer, frame: edgeEffectFrame)
        } else {
            transition.updateFrame(view: self.headerEdgeEffectView, frame: edgeEffectFrame)
        }
        
        if !isSettings {
            self.updateUnderHeaderContentsAlpha?(1.0 - realAreaExpansionFraction, transition)
        }
        
        self.headerEdgeEffectView.update(content: presentationData.theme.list.plainBackgroundColor, blur: true, rect: edgeEffectFrame, edge: .top, edgeSize: edgeEffectHeight, transition: ComponentTransition(transition))
        
        navigationTransition.updateAlpha(layer: self.headerEdgeEffectView.layer, alpha: state.isEditing ? 0.0 : 1.0)
        
        if !state.isEditing {
            if !isSettings && !isMyProfile {
                if self.isAvatarExpanded {
                    resolvedHeight -= currentSavedMusic != nil ? 20.0 : 21.0
                } else {
                    resolvedHeight += 79.0
                    
                    if !actionButtonKeys.isEmpty {
                        resolvedHeight += 64.0
                    }
                }
            } else {
                if self.isAvatarExpanded {
                    resolvedHeight -= currentSavedMusic != nil ? 20.0 : 21.0
                }
            }
        }
        
        if let currentWalletBalance {
            let balance = self.walletBalance ?? {
                let componentView = ComponentView<Empty>()
                self.walletBalance = componentView
                return componentView
            }()
            let formattedBalance = formatTonAmountText(currentWalletBalance, dateTimeFormat: presentationData.dateTimeFormat, maxDecimalPositions: 2)
            let decimalSeparator = presentationData.dateTimeFormat.decimalSeparator
            let isOverlay = self.isAvatarExpanded || hasBackground
            let primaryColor = isOverlay ? UIColor.white : presentationData.theme.list.itemPrimaryTextColor
            let isColoredBackground = hasBackground && !self.isAvatarExpanded
            let iconColor: UIColor
            if isColoredBackground {
                iconColor = UIColor(white: 1.0, alpha: 0.3)
            } else if isOverlay {
                iconColor = navigationContentsSecondaryColor.mixedWith(.white, alpha: 0.45)
            } else {
                iconColor = presentationData.theme.list.itemAccentColor
            }
            let balanceTitle = presentationData.strings.Wallet_Send_Balance("").string.trimmingCharacters(in: .whitespacesAndNewlines)
            // Shrink unusually long amounts/localizations to fit the profile band.
            let maximumBalanceWidth = max(1.0, width - stripLeft - stripRight - 32.0)
            let titleWidth = (balanceTitle as NSString).size(withAttributes: [.font: Font.regular(12.0)]).width
            let amountWidth = (formattedBalance as NSString).size(withAttributes: [.font: Font.semibold(12.0)]).width
            let textScale = min(1.0, max(1.0, maximumBalanceWidth - 52.0) / max(1.0, titleWidth + amountWidth))
            let amountText = tonAmountAttributedString(formattedBalance, integralFont: Font.semibold(12.0 * textScale), fractionalFont: Font.semibold(9.0 * textScale), color: primaryColor, decimalSeparator: decimalSeparator)
            let balanceSize = balance.update(
                transition: .immediate,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(HStack([
                        AnyComponentWithIdentity(
                            id: "title",
                            component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: balanceTitle, font: Font.regular(12.0 * textScale), textColor: primaryColor))))
                        ),
                        AnyComponentWithIdentity(
                            id: self.isAvatarExpanded ? "iconCutout" : "iconWithStar",
                            component: self.isAvatarExpanded ? AnyComponent(Image(image: self.walletBalanceCutoutIcon(color: iconColor), size: CGSize(width: 14.0, height: 14.0), contentMode: .center)) : AnyComponent(ZStack([
                                AnyComponentWithIdentity(
                                    id: "base",
                                    component: AnyComponent(BundleIconComponent(name: "Wallet/TopGram", tintColor: iconColor, maxSize: CGSize(width: 14.0, height: 14.0)))
                                ),
                                AnyComponentWithIdentity(
                                    id: "star",
                                    component: AnyComponent(BundleIconComponent(name: "Wallet/TransactionGramHighlight", tintColor: .white, maxSize: CGSize(width: 14.0, height: 14.0)))
                                )
                            ]))
                        ),
                        AnyComponentWithIdentity(
                            id: "amount",
                            component: AnyComponent(MultilineTextComponent(text: .plain(amountText)))
                        ),
                        AnyComponentWithIdentity(
                            id: "arrow",
                            component: AnyComponent(BundleIconComponent(name: "Item List/InlineTextRightArrow", tintColor: primaryColor))
                        )
                    ], spacing: 4.0)),
                    background: AnyComponent(RoundedRectangle(color: contentButtonBackgroundColor, cornerRadius: 10.0)),
                    minSize: CGSize(width: 0.0, height: 20.0),
                    contentInsets: UIEdgeInsets(top: 1.0, left: 8.0, bottom: 1.0, right: 8.0),
                    action: { [weak self] in
                        self?.openWallet?()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: maximumBalanceWidth, height: 20.0)
            )
            let balanceFrame: CGRect
            if self.isAvatarExpanded {
                let lastRowFrame = usernameFrame.maxY > subtitleFrame.maxY ? usernameFrame : subtitleFrame
                balanceFrame = CGRect(origin: CGPoint(
                    x: width - stripRight - 16.0 - balanceSize.width,
                    y: floor(lastRowFrame.midY + titleOffset - balanceSize.height * 0.5)
                ), size: balanceSize)
            } else {
                balanceFrame = CGRect(origin: CGPoint(
                    x: stripLeft + floor((width - stripLeft - stripRight - balanceSize.width) * 0.5),
                    y: max(subtitleFrame.maxY, usernameFrame.maxY) + titleOffset + 8.0
                ), size: balanceSize)
            }
            if let balanceView = balance.view {
                balanceView.isAccessibilityElement = true
                balanceView.accessibilityLabel = presentationData.strings.Wallet_Send_Balance(formattedBalance).string
                balanceView.accessibilityTraits = .button
                if balanceView.superview == nil {
                    // Newly loaded balance fades in at its final position.
                    ContainedViewLayoutTransition.immediate.updateFrame(view: balanceView, frame: balanceFrame)
                    self.regularContentNode.view.addSubview(balanceView)
                    if transition.isAnimated {
                        balanceView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                } else if additive {
                    transition.updateFrameAdditiveToCenter(view: balanceView, frame: balanceFrame)
                } else {
                    transition.updateFrame(view: balanceView, frame: balanceFrame)
                }
                ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut).updateAlpha(layer: balanceView.layer, alpha: backgroundBannerAlpha * (1.0 - titleCollapseFraction))
            }
        }

        if currentSavedMusic != nil {
            var musicTransition = transition
            if hasBackground || self.isAvatarExpanded {
                if self.musicBackground == nil {
                    musicTransition = .immediate
                }
                let musicBackground = self.musicBackground ?? {
                    let musicBackground = UIView()
                    musicBackground.backgroundColor = .white
                    self.buttonsMaskView.addSubview(musicBackground)
                    self.musicBackground = musicBackground
                    if transition.isAnimated {
                        musicBackground.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                    return musicBackground
                }()
                musicTransition.updateFrame(view: musicBackground, frame: CGRect(origin: CGPoint(x: 0.0, y: backgroundHeight - 24.0 - buttonRightOrigin.y), size: CGSize(width: backgroundFrame.width, height: 24.0)))

                musicTransition.updateAlpha(layer: musicBackground.layer, alpha: 1.0)
            } else if let musicBackground = self.musicBackground {
                self.musicBackground = nil
                if transition.isAnimated {
                    musicBackground.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                        musicBackground.removeFromSuperview()
                    })
                } else {
                    musicBackground.removeFromSuperview()
                }
            }

            let isOverlay = self.isAvatarExpanded || hasBackground
            let stripSecondaryColor = hasCoverColor ? navigationContentsSecondaryColor.mixedWith(.white, alpha: 0.45) : navigationContentsSecondaryColor
            let musicBandWidth = max(0.0, backgroundFrame.width - stripLeft - stripRight)
            if let currentSavedMusic {
                var artist = presentationData.strings.MediaPlayer_UnknownArtist
                var track: String?
                for attribute in currentSavedMusic.attributes {
                    if case let  .Audio(_, _, title, performer, _) = attribute {
                        artist = performer ?? artist
                        track = title
                        break
                    }
                }
                if track == nil {
                    if let fileName = currentSavedMusic.fileName {
                        track = fileName
                    } else {
                        track = presentationData.strings.MediaPlayer_UnknownTrack
                    }
                }

                let music = self.music ?? {
                    let componentView = ComponentView<Empty>()
                    self.music = componentView
                    return componentView
                }()

                let musicString = NSMutableAttributedString()
                // Keep music inside the profile band, including when a side strip is visible.
                musicString.append(NSAttributedString(string: track ?? "", font: Font.semibold(12.0), textColor: isOverlay ? .white : presentationData.theme.list.itemAccentColor))
                let artistSeparatorIndex = musicString.length
                musicString.append(NSAttributedString(string: " \(artist)", font: Font.regular(12.0), textColor: stripSecondaryColor))
                musicString.addAttribute(.kern, value: CGFloat(2.0), range: NSRange(location: artistSeparatorIndex, length: 1))

                let musicSize = music.update(
                    transition: .immediate,
                    component: AnyComponent(
                        PlainButtonComponent(
                            content: AnyComponent(
                                HStack([
                                    AnyComponentWithIdentity(
                                        id: "icon",
                                        component: AnyComponent(BundleIconComponent(name: "Media Editor/SmallAudio", tintColor: isOverlay ? .white : presentationData.theme.list.itemAccentColor))
                                    ),
                                    AnyComponentWithIdentity(
                                        id: "label",
                                        component: AnyComponent(MarqueeComponent(attributedText: musicString, maxWidth: max(1.0, musicBandWidth - 96.0)))
                                    ),
                                    AnyComponentWithIdentity(
                                        id: "arrow",
                                        component: AnyComponent(BundleIconComponent(name: "Item List/InlineTextRightArrow", tintColor: stripSecondaryColor))
                                    )
                                ], spacing: 4.0)
                            ),
                            minSize: CGSize(width: musicBandWidth, height: musicHeight),
                            action: { [weak self] in
                                self?.displaySavedMusic?()
                            }
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: musicBandWidth, height: musicHeight)
                )
                let musicFrame = CGRect(origin: CGPoint(x: stripLeft, y: (apparentBackgroundHeight - backgroundHeight) + backgroundHeight - musicHeight - (hasBackground || self.isAvatarExpanded ? 0.0 : 4.0) + 1.0 - UIScreenPixel), size: musicSize)
                if let musicView = music.view {
                    if musicView.superview == nil {
                        // A newly loaded strip item fades in at its final position.
                        ContainedViewLayoutTransition.immediate.updateFrame(view: musicView, frame: musicFrame)
                        self.regularContentNode.view.addSubview(musicView)
                        if transition.isAnimated {
                            musicView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        }
                    } else if additive {
                        musicTransition.updateFrameAdditiveToCenter(view: musicView, frame: musicFrame)
                    } else {
                        musicTransition.updateFrame(view: musicView, frame: musicFrame)
                    }

                    ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut).updateAlpha(layer: musicView.layer, alpha: backgroundBannerAlpha)
                }
            }
        } else {
            if let musicBackground = self.musicBackground {
                self.musicBackground = nil
                if transition.isAnimated {
                    musicBackground.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                        musicBackground.removeFromSuperview()
                    })
                } else {
                    musicBackground.removeFromSuperview()
                }
            }
        }
        if currentSavedMusic == nil {
            if let music = self.music {
                self.music = nil
                music.view?.isUserInteractionEnabled = false
                if transition.isAnimated {
                    music.view?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                        music.view?.removeFromSuperview()
                    })
                } else {
                    music.view?.removeFromSuperview()
                }
            }
        }
        if currentWalletBalance == nil, let balance = self.walletBalance {
            self.walletBalance = nil
            balance.view?.isUserInteractionEnabled = false
            if transition.isAnimated {
                balance.view?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                    balance.view?.removeFromSuperview()
                })
            } else {
                balance.view?.removeFromSuperview()
            }
        }

        if isFirstTime {
            self.updateAvatarMask(transition: .immediate)
        }
        
        return resolvedHeight
    }
    
    private func buttonPressed(_ buttonNode: PeerInfoHeaderButtonNode, gesture: ContextGesture?) {
        self.performButtonAction?(buttonNode.key, buttonNode, gesture)
    }
    
    private func actionButtonPressed(_ buttonNode: PeerInfoHeaderActionButtonNode, gesture: ContextGesture?) {
        self.performButtonAction?(buttonNode.key, nil, gesture)
    }
    
    private func walletBalanceCutoutIcon(color: UIColor) -> UIImage? {
        if let current = self.walletBalanceCutoutIcon, current.color == color {
            return current.image
        }
        guard let base = UIImage(bundleImageName: "Wallet/TopGram"), let highlight = UIImage(bundleImageName: "Wallet/TransactionGramHighlight") else {
            return nil
        }
        let maxSize = CGSize(width: 14.0, height: 14.0)
        let size = base.size.aspectFitted(maxSize)
        let highlightSize = highlight.size.aspectFitted(maxSize)
        guard let image = generateImage(size, rotatedContext: { size, context in
            context.clear(CGRect(origin: .zero, size: size))
            UIGraphicsPushContext(context)
            generateTintedImage(image: base, color: color)?.draw(in: CGRect(origin: .zero, size: size))
            highlight.draw(in: CGRect(origin: CGPoint(x: (size.width - highlightSize.width) * 0.5, y: (size.height - highlightSize.height) * 0.5), size: highlightSize), blendMode: .destinationOut, alpha: 1.0)
            UIGraphicsPopContext()
        }) else {
            return nil
        }
        self.walletBalanceCutoutIcon = (color, image)
        return image
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        var result = super.point(inside: point, with: event)
        for stripView in [self.music?.view, self.walletBalance?.view].compactMap({ $0 }) {
            if stripView.alpha > 0.0, stripView.bounds.contains(self.view.convert(point, to: stripView)) {
                result = true
            }
        }
        return result
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        
        if self.isSearching {
            if !result.isDescendant(of: self.searchBarContainer.view) && !result.isDescendant(of: self.searchContainer.view) {
                return self.view
            }
            
            return result
        }
        
        if let customNavigationContentNode = self.customNavigationContentNode {
            if let result = customNavigationContentNode.view.hitTest(self.view.convert(point, to: customNavigationContentNode.view), with: event) {
                return result
            }
        }
        
        let setByFrame = self.avatarListNode.listContainerNode.setByYouNode.view.convert(self.avatarListNode.listContainerNode.setByYouNode.bounds, to: self.view).insetBy(dx: -44.0, dy: 0.0)
        if self.avatarListNode.listContainerNode.setByYouNode.alpha > 0.0, setByFrame.contains(point) {
            return self.avatarListNode.listContainerNode.setByYouNode.view
        }
        
        if !(self.state?.isEditing ?? false) {
            switch self.currentCredibilityIcon {
            case .premium:
                let iconFrame = self.titleCredibilityIconView.convert(self.titleCredibilityIconView.bounds, to: self.view)
                let expandedIconFrame = self.titleExpandedCredibilityIconView.convert(self.titleExpandedCredibilityIconView.bounds, to: self.view)
                if expandedIconFrame.contains(point) && self.isAvatarExpanded {
                    return self.titleExpandedCredibilityIconView.hitTest(self.view.convert(point, to: self.titleExpandedCredibilityIconView), with: event)
                } else if iconFrame.contains(point) {
                    return self.titleCredibilityIconView.hitTest(self.view.convert(point, to: self.titleCredibilityIconView), with: event)
                }
            default:
                break
            }
            switch self.currentStatusIcon {
            case .emojiStatus:
                let iconFrame = self.titleStatusIconView.convert(self.titleStatusIconView.bounds, to: self.view)
                let expandedIconFrame = self.titleExpandedStatusIconView.convert(self.titleExpandedStatusIconView.bounds, to: self.view)
                if expandedIconFrame.contains(point) && self.isAvatarExpanded {
                    return self.titleExpandedStatusIconView.hitTest(self.view.convert(point, to: self.titleExpandedStatusIconView), with: event)
                } else if iconFrame.contains(point) {
                    return self.titleStatusIconView.hitTest(self.view.convert(point, to: self.titleStatusIconView), with: event)
                }
            default:
                break
            }
        }
        
        if let subtitleBackgroundButton = self.subtitleBackgroundButton, subtitleBackgroundButton.view.convert(subtitleBackgroundButton.bounds, to: self.view).contains(point) {
            if let result = subtitleBackgroundButton.view.hitTest(self.view.convert(point, to: subtitleBackgroundButton.view), with: event) {
                return result
            }
        }
        
        if let subtitleBadgeView = self.subtitleBadgeView, let result = subtitleBadgeView.hitTest(self.view.convert(point, to: subtitleBadgeView), with: event) {
            return result
        }
        
        if let subtitleRatingView = self.subtitleRating?.view, let result = subtitleRatingView.hitTest(self.view.convert(point, to: subtitleRatingView), with: event) {
            return result
        }
        
        if self.isSettings && self.buttonsContainerNode.alpha != 0.0 {
            if self.subtitleNodeRawContainer.bounds.contains(self.view.convert(point, to: self.subtitleNodeRawContainer.view)) {
                return self.subtitleNodeRawContainer.view
            }
        }
        
        if let result = self.buttonsContainerNode.view.hitTest(self.view.convert(point, to: self.buttonsContainerNode.view), with: event) {
            return result
        }
        
        if let giftsCoverView = self.giftsCover.view, giftsCoverView.alpha > 0.0, giftsCoverView.point(inside: self.view.convert(point, to: giftsCoverView), with: event) {
            return giftsCoverView
        }
        
        if let balanceView = self.walletBalance?.view, let result = balanceView.hitTest(self.view.convert(point, to: balanceView), with: event) {
            return result
        }

        if let musicView = self.music?.view, let result = musicView.hitTest(self.view.convert(point, to: musicView), with: event) {
            return result
        }
        
        if result == self.view || result == self.regularContentNode.view || result == self.editingContentNode.view {
            return nil
        }
        
        return result
    }
    
    func updateIsAvatarExpanded(_ isAvatarExpanded: Bool, transition: ContainedViewLayoutTransition) {
        if self.isAvatarExpanded != isAvatarExpanded {
            self.isAvatarExpanded = isAvatarExpanded
            if isAvatarExpanded {
                self.avatarListNode.listContainerNode.selectFirstItem()
            }
            if case .animated = transition, !isAvatarExpanded {
                self.avatarListNode.animateAvatarCollapse(transition: transition)
            }
            
            self.updateAvatarMask(transition: transition)
        }
    }
    
    private func updateAvatarMask(transition: ContainedViewLayoutTransition) {
        guard let (width, statusBarHeight, deviceMetrics) = self.validLayout, deviceMetrics.hasDynamicIsland && statusBarHeight > 0.0 else {
            return
        }
        let maskScale: CGFloat = isAvatarExpanded ? width / 100.0 : 1.0
        transition.updateTransformScale(layer: self.avatarListNode.maskNode.layer, scale: maskScale)
        transition.updateTransformScale(layer: self.avatarListNode.bottomCoverNode.layer, scale: maskScale)
        transition.updateTransformScale(layer: self.avatarListNode.topCoverNode.layer, scale: maskScale)
        
        let maskAnchorPoint = CGPoint(x: 0.5, y: self.isAvatarExpanded ? 0.37 : 0.5)
        transition.updateAnchorPoint(layer: self.avatarListNode.maskNode.layer, anchorPoint: maskAnchorPoint)
    }
}
