import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
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

final class PeerInfoHeaderNavigationTransition {
    let sourceNavigationBar: NavigationBar
    let sourceTitleView: ChatTitleView
    let sourceTitleFrame: CGRect
    let sourceSubtitleFrame: CGRect
    let previousAvatarView: UIView?
    let fraction: CGFloat
    
    init(sourceNavigationBar: NavigationBar, sourceTitleView: ChatTitleView, sourceTitleFrame: CGRect, sourceSubtitleFrame: CGRect, previousAvatarView: UIView?, fraction: CGFloat) {
        self.sourceNavigationBar = sourceNavigationBar
        self.sourceTitleView = sourceTitleView
        self.sourceTitleFrame = sourceTitleFrame
        self.sourceSubtitleFrame = sourceSubtitleFrame
        self.previousAvatarView = previousAvatarView
        self.fraction = fraction
    }
}

final class PeerInfoHeaderRegularContentNode: ASDisplayNode {
}

enum PeerInfoHeaderTextFieldNodeKey: Equatable {
    case firstName
    case lastName
    case title
    case description
}

protocol PeerInfoHeaderTextFieldNode: ASDisplayNode {
    var text: String { get }
    
    func update(width: CGFloat, safeInset: CGFloat, isSettings: Bool, hasPrevious: Bool, hasNext: Bool, placeholder: String, isEnabled: Bool, presentationData: PresentationData, updateText: String?) -> CGFloat
}

private let TitleNodeStateRegular = 0
private let TitleNodeStateExpanded = 1

final class PeerInfoHeaderNode: ASDisplayNode {
    private var context: AccountContext
    private let isPremiumDisabled: Bool
    private weak var controller: PeerInfoScreenImpl?
    private var presentationData: PresentationData?
    private var state: PeerInfoState?
    private var peer: Peer?
    private var threadData: MessageHistoryThreadData?
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
    let backgroundNode: NavigationBackgroundNode
    let expandedBackgroundNode: NavigationBackgroundNode
    let separatorNode: ASDisplayNode
    let navigationBackgroundNode: ASDisplayNode
    let navigationBackgroundBackgroundNode: ASDisplayNode
    var navigationTitle: String?
    let navigationTitleNode: ImmediateTextNode
    let navigationSeparatorNode: ASDisplayNode
    let navigationButtonContainer: PeerInfoHeaderNavigationButtonContainerNode
    let editingNavigationBackgroundNode: NavigationBackgroundNode
    let editingNavigationBackgroundSeparator: ASDisplayNode
    
    var performButtonAction: ((PeerInfoHeaderButtonKey, ContextGesture?) -> Void)?
    var requestAvatarExpansion: ((Bool, [AvatarGalleryEntry], AvatarGalleryEntry?, (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?) -> Void)?
    var requestOpenAvatarForEditing: ((Bool) -> Void)?
    var cancelUpload: (() -> Void)?
    var requestUpdateLayout: ((Bool) -> Void)?
    var animateOverlaysFadeIn: (() -> Void)?
    
    var displayAvatarContextMenu: ((ASDisplayNode, ContextGesture?) -> Void)?
    var displayCopyContextMenu: ((ASDisplayNode, Bool, Bool) -> Void)?
    var displayEmojiPackTooltip: (() -> Void)?
    
    var displayPremiumIntro: ((UIView, PeerEmojiStatus?, Signal<(TelegramMediaFile, LoadedStickerPack)?, NoError>, Bool) -> Void)?
    var displayStatusPremiumIntro: (() -> Void)?
    var displayUniqueGiftInfo: ((UIView, String) -> Void)?
    var openUniqueGift: ((UIView, String) -> Void)?
    
    var navigateToForum: (() -> Void)?
    
    var navigationTransition: PeerInfoHeaderNavigationTransition?
    
    var backgroundAlpha: CGFloat = 1.0
    var updateHeaderAlpha: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
    
    private(set) var contentButtonBackgroundColor: UIColor?
    
    let animationCache: AnimationCache
    let animationRenderer: MultiAnimationRenderer
    
    var emojiStatusPackDisposable = MetaDisposable()
    var emojiStatusFileAndPackTitle = Promise<(TelegramMediaFile, LoadedStickerPack)?>()
    
    var customNavigationContentNode: PeerInfoPanelNodeNavigationContentNode?
    private var appliedCustomNavigationContentNode: PeerInfoPanelNodeNavigationContentNode?
    
    private var validLayout: (width: CGFloat, statusBarHeight: CGFloat, deviceMetrics: DeviceMetrics)?
    
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
        
        self.navigationBackgroundNode = ASDisplayNode()
        self.navigationBackgroundNode.isHidden = true
        self.navigationBackgroundNode.isUserInteractionEnabled = false

        self.navigationBackgroundBackgroundNode = ASDisplayNode()
        self.navigationBackgroundBackgroundNode.isUserInteractionEnabled = false
        
        self.navigationTitleNode = ImmediateTextNode()
        
        self.navigationSeparatorNode = ASDisplayNode()
        
        self.navigationButtonContainer = PeerInfoHeaderNavigationButtonContainerNode()
        self.editingNavigationBackgroundNode = NavigationBackgroundNode(color: .clear, enableBlur: true)
        self.editingNavigationBackgroundSeparator = ASDisplayNode()
        
        self.backgroundNode = NavigationBackgroundNode(color: .clear)
        self.backgroundNode.isHidden = true
        self.backgroundNode.isUserInteractionEnabled = false
        self.expandedBackgroundNode = NavigationBackgroundNode(color: .clear)
        self.expandedBackgroundNode.isHidden = false
        self.expandedBackgroundNode.isUserInteractionEnabled = false
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.animationCache = context.animationCache
        self.animationRenderer = context.animationRenderer
        
        super.init()
        
        requestUpdateLayoutImpl = { [weak self] in
            self?.requestUpdateLayout?(false)
        }
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.expandedBackgroundNode)
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
        self.addSubnode(self.navigationBackgroundNode)
        self.navigationBackgroundNode.addSubnode(self.navigationBackgroundBackgroundNode)
        self.navigationBackgroundNode.addSubnode(self.navigationTitleNode)
        self.navigationBackgroundNode.addSubnode(self.navigationSeparatorNode)
        self.addSubnode(self.editingNavigationBackgroundNode)
        self.addSubnode(self.editingNavigationBackgroundSeparator)
        self.addSubnode(self.navigationButtonContainer)
        self.addSubnode(self.separatorNode)
        
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
            strongSelf.navigationButtonContainer.layer.animateAlpha(from: 0.0, to: strongSelf.navigationButtonContainer.alpha, duration: 0.25)
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
    func update(width: CGFloat, containerHeight: CGFloat, containerInset: CGFloat, statusBarHeight: CGFloat, navigationHeight: CGFloat, isModalOverlay: Bool, isMediaOnly: Bool, contentOffset: CGFloat, paneContainerY: CGFloat, presentationData: PresentationData, peer: Peer?, cachedData: CachedPeerData?, threadData: MessageHistoryThreadData?, peerNotificationSettings: TelegramPeerNotificationSettings?, threadNotificationSettings: TelegramPeerNotificationSettings?, globalNotificationSettings: EngineGlobalNotificationSettings?, statusData: PeerInfoStatusData?, panelStatusData: (PeerInfoStatusData?, PeerInfoStatusData?, CGFloat?), isSecretChat: Bool, isContact: Bool, isSettings: Bool, state: PeerInfoState, profileGiftsContext: ProfileGiftsContext?, metrics: LayoutMetrics, deviceMetrics: DeviceMetrics, transition: ContainedViewLayoutTransition, additive: Bool, animateHeader: Bool) -> CGFloat {
        if self.appliedCustomNavigationContentNode !== self.customNavigationContentNode {
            if let previous = self.appliedCustomNavigationContentNode {
                transition.updateAlpha(node: previous, alpha: 0.0, completion: { [weak previous] _ in
                    previous?.removeFromSupernode()
                })
            }
            
            self.appliedCustomNavigationContentNode = self.customNavigationContentNode
            if let customNavigationContentNode = self.customNavigationContentNode {
                self.addSubnode(customNavigationContentNode)
                customNavigationContentNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: navigationHeight))
                customNavigationContentNode.alpha = 0.0
                transition.updateAlpha(node: customNavigationContentNode, alpha: 1.0)
            }
        } else if let customNavigationContentNode = self.customNavigationContentNode {
            transition.updateFrame(node: customNavigationContentNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: navigationHeight)))
        }
        
        var threadData = threadData
        if case let .replyThread(replyThreadMessage) = self.chatLocation, replyThreadMessage.peerId == self.context.account.peerId {
            threadData = nil
        }
        
        self.state = state
        self.peer = peer
        self.threadData = threadData
        self.avatarListNode.listContainerNode.peer = peer.flatMap(EnginePeer.init)
        
        let isFirstTime = self.validLayout == nil
        self.validLayout = (width, statusBarHeight, deviceMetrics)
        
        let previousPanelStatusData = self.currentPanelStatusData
        self.currentPanelStatusData = panelStatusData.0
        
        let avatarSize: CGFloat = isModalOverlay ? 200.0 : 100.0
        self.avatarSize = avatarSize
        
        var contentOffset = contentOffset
        
        if isMediaOnly {
            if isModalOverlay {
                contentOffset = 312.0
            } else {
                contentOffset = 212.0
            }
        }
        
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
        if let channel = peer as? TelegramChannel, channel.isForumOrMonoForum {
            isForum = true
        }
        
        transition.updateAlpha(node: self.regularContentNode, alpha: (state.isEditing || self.customNavigationContentNode != nil) ? 0.0 : 1.0)
        if self.navigationTransition == nil {
            transition.updateAlpha(node: self.navigationButtonContainer, alpha: self.customNavigationContentNode != nil ? 0.0 : 1.0)
        }
        
        self.editingContentNode.alpha = state.isEditing ? 1.0 : 0.0
        
        let editingContentHeight = self.editingContentNode.update(width: width, safeInset: containerInset, statusBarHeight: statusBarHeight, navigationHeight: navigationHeight, isModalOverlay: isModalOverlay, peer: state.isEditing ? peer : nil, threadData: threadData, chatLocation: self.chatLocation, cachedData: cachedData, isContact: isContact, isSettings: isSettings || isMyProfile, presentationData: presentationData, transition: transition)
        transition.updateFrame(node: self.editingContentNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -contentOffset), size: CGSize(width: width, height: editingContentHeight)))
        
        let avatarOverlayFarme = self.editingContentNode.convert(self.editingContentNode.avatarNode.frame, to: self)
        transition.updateFrame(node: self.avatarOverlayNode, frame: avatarOverlayFarme)
        
        var transitionSourceHeight: CGFloat = 0.0
        var transitionFraction: CGFloat = 0.0
        var transitionSourceAvatarFrame: CGRect?
        var transitionSourceTitleFrame = CGRect()
        var transitionSourceSubtitleFrame = CGRect()
        
        let avatarFrame = CGRect(origin: CGPoint(x: floor((width - avatarSize) / 2.0), y: statusBarHeight + 22.0), size: CGSize(width: avatarSize, height: avatarSize))
        
        self.backgroundNode.updateColor(color: presentationData.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)

        let headerBackgroundColor: UIColor = presentationData.theme.list.blocksBackgroundColor
        
        let regularNavigationContentsAccentColor: UIColor = peer?.profileColor != nil ? .white : presentationData.theme.list.itemAccentColor
        let collapsedHeaderNavigationContentsAccentColor = presentationData.theme.list.itemAccentColor
        let expandedAvatarNavigationContentsAccentColor: UIColor = .white
        
        let regularNavigationContentsPrimaryColor: UIColor = peer?.profileColor != nil ? .white : presentationData.theme.list.itemPrimaryTextColor
        let collapsedHeaderNavigationContentsPrimaryColor = presentationData.theme.list.itemPrimaryTextColor
        let expandedAvatarNavigationContentsPrimaryColor: UIColor = .white
        
        let regularContentButtonBackgroundColor: UIColor
        let collapsedHeaderContentButtonBackgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        let expandedAvatarContentButtonBackgroundColor: UIColor = UIColor(white: 0.0, alpha: 0.1)
        
        let regularHeaderButtonBackgroundColor: UIColor
        let collapsedHeaderButtonBackgroundColor: UIColor = .clear
        let expandedAvatarHeaderButtonBackgroundColor: UIColor = UIColor(white: 0.0, alpha: 0.1)
        
        let regularContentButtonForegroundColor: UIColor = peer?.profileColor != nil ? UIColor.white : presentationData.theme.list.itemAccentColor
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
            regularContentButtonBackgroundColor = baseButtonBackgroundColor.blendOver(background: secondaryColor.mixedWith(mainColor, alpha: 0.1))
            regularHeaderButtonBackgroundColor = baseButtonBackgroundColor.blendOver(background: secondaryColor.mixedWith(mainColor, alpha: 0.1))
            
            hasCoverColor = true
        } else if let profileColor = peer?.profileColor {
            let backgroundColors = self.context.peerNameColors.getProfile(profileColor, dark: presentationData.theme.overallDarkAppearance)
            regularNavigationContentsSecondaryColor = UIColor(white: 1.0, alpha: 0.6).blitOver(backgroundColors.main.withMultiplied(hue: 1.0, saturation: 2.2, brightness: 1.5), alpha: 1.0)
            
            let baseButtonBackgroundColor: UIColor
            if presentationData.theme.overallDarkAppearance {
                baseButtonBackgroundColor = UIColor(white: 0.0, alpha: 0.25)
            } else {
                baseButtonBackgroundColor = UIColor(white: 1.0, alpha: 0.25)
            }
            regularContentButtonBackgroundColor = baseButtonBackgroundColor.blendOver(background: backgroundColors.main)
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
        
        var panelWithAvatarHeight: CGFloat = 35.0 + avatarSize
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
        
        let editingBackgroundAlpha: CGFloat
        if state.isEditing {
            editingBackgroundAlpha = max(0.0, min(1.0, contentOffset / 20.0))
        } else {
            editingBackgroundAlpha = 0.0
        }
        
        self.editingNavigationBackgroundSeparator.backgroundColor = presentationData.theme.rootController.navigationBar.separatorColor
        self.editingNavigationBackgroundNode.updateColor(color: presentationData.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
        
        let editingNavigationBackgroundFrame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: navigationHeight))
        transition.updateFrame(node: self.editingNavigationBackgroundNode, frame: editingNavigationBackgroundFrame)
        self.editingNavigationBackgroundNode.update(size: editingNavigationBackgroundFrame.size, transition: transition)
        transition.updateFrame(node: self.editingNavigationBackgroundSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: editingNavigationBackgroundFrame.maxY), size: CGSize(width: width, height: UIScreenPixel)))
        
        transition.updateAlpha(node: self.editingNavigationBackgroundNode, alpha: editingBackgroundAlpha)
        transition.updateAlpha(node: self.editingNavigationBackgroundSeparator, alpha: editingBackgroundAlpha)
        
        let backgroundBannerAlpha: CGFloat
        
        var effectiveSeparatorAlpha: CGFloat
        if let navigationTransition = self.navigationTransition {
            transitionSourceHeight = navigationTransition.sourceNavigationBar.backgroundNode.bounds.height
            transitionFraction = navigationTransition.fraction
            
            innerBackgroundTransitionFraction = 0.0
            backgroundBannerAlpha = 1.0
            
            if let avatarNavigationNode = navigationTransition.sourceNavigationBar.rightButtonNode.singleCustomNode as? ChatAvatarNavigationNode {
                if let statusView = avatarNavigationNode.statusView.view {
                    transitionSourceAvatarFrame = statusView.convert(statusView.bounds, to: navigationTransition.sourceNavigationBar.view)
                } else {
                    transitionSourceAvatarFrame = avatarNavigationNode.avatarNode.view.convert(avatarNavigationNode.avatarNode.view.bounds, to: navigationTransition.sourceNavigationBar.view)
                }
                transition.updateAlpha(node: self.avatarListNode.avatarContainerNode.avatarNode, alpha: 1.0 - transitionFraction)
            } else {
                if deviceMetrics.hasDynamicIsland && statusBarHeight > 0.0 && !isLandscape {
                    transitionSourceAvatarFrame = CGRect(origin: CGPoint(x: avatarFrame.minX, y: -20.0), size: avatarFrame.size).insetBy(dx: avatarSize * 0.4, dy: avatarSize * 0.4)
                } else {
                    transitionSourceAvatarFrame = avatarFrame.offsetBy(dx: 0.0, dy: -avatarFrame.maxY).insetBy(dx: avatarSize * 0.4, dy: avatarSize * 0.4)
                }
            }
            transitionSourceTitleFrame = navigationTransition.sourceTitleFrame
            transitionSourceSubtitleFrame = navigationTransition.sourceSubtitleFrame

            transition.updateAlpha(layer: self.backgroundBannerView.layer, alpha: 1.0 - transitionFraction)
            
            self.expandedBackgroundNode.updateColor(color: presentationData.theme.rootController.navigationBar.blurredBackgroundColor.mixedWith(headerBackgroundColor, alpha: 1.0 - transitionFraction), forceKeepBlur: true, transition: transition)
            effectiveSeparatorAlpha = transitionFraction
            
            if self.isAvatarExpanded, case .animated = transition, transitionFraction == 1.0 {
                self.avatarListNode.animateAvatarCollapse(transition: transition)
            }
            self.avatarClippingNode.clipsToBounds = false
        } else {
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
            
            self.expandedBackgroundNode.updateColor(color: presentationData.theme.rootController.navigationBar.opaqueBackgroundColor.mixedWith(headerBackgroundColor, alpha: 1.0 - innerBackgroundTransitionFraction), forceKeepBlur: true, transition: transition)
            navigationTransition.updateAlpha(node: self.expandedBackgroundNode, alpha: state.isEditing ? 0.0 : 1.0)
            
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
            
            effectiveSeparatorAlpha = innerBackgroundTransitionFraction
            
            self.avatarClippingNode.clipsToBounds = true
        }
        
        if state.isEditing {
            navigationContentsAccentColor = collapsedHeaderNavigationContentsAccentColor
            navigationContentsPrimaryColor = collapsedHeaderNavigationContentsPrimaryColor
            navigationContentsSecondaryColor = collapsedHeaderNavigationContentsSecondaryColor
            navigationContentsCanBeExpanded = true
            
            contentButtonBackgroundColor = collapsedHeaderContentButtonBackgroundColor
            contentButtonForegroundColor = collapsedHeaderContentButtonForegroundColor
            
            headerButtonBackgroundColor = collapsedHeaderButtonBackgroundColor
        } else if self.isAvatarExpanded {
            navigationContentsAccentColor = expandedAvatarNavigationContentsAccentColor
            navigationContentsPrimaryColor = expandedAvatarNavigationContentsPrimaryColor
            navigationContentsSecondaryColor = expandedAvatarNavigationContentsSecondaryColor
            contentButtonBackgroundColor = expandedAvatarContentButtonBackgroundColor
            contentButtonForegroundColor = expandedAvatarContentButtonForegroundColor
            
            navigationContentsCanBeExpanded = false
            
            headerButtonBackgroundColor = expandedAvatarHeaderButtonBackgroundColor
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
            
            contentButtonBackgroundColor = regularContentButtonBackgroundColor//.mixedWith(collapsedHeaderContentButtonBackgroundColor, alpha: effectiveTransitionFraction)
            contentButtonForegroundColor = regularContentButtonForegroundColor//.mixedWith(collapsedHeaderContentButtonForegroundColor, alpha: effectiveTransitionFraction)
            
            headerButtonBackgroundColor = regularHeaderButtonBackgroundColor.mixedWith(collapsedHeaderButtonBackgroundColor, alpha: effectiveTransitionFraction)
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
                        
                        if let emojiFile = emojiFile {
                            strongSelf.emojiStatusFileAndPackTitle.set(.never())
                            
                            for attribute in emojiFile.attributes {
                                if case let .CustomEmoji(_, _, _, packReference) = attribute, let packReference = packReference {
                                    strongSelf.emojiStatusPackDisposable.set((strongSelf.context.engine.stickers.loadedStickerPack(reference: packReference, forceActualized: false)
                                    |> filter { result in
                                        if case .result = result {
                                            return true
                                        } else {
                                            return false
                                        }
                                    }
                                    |> mapToSignal { result -> Signal<(TelegramMediaFile, LoadedStickerPack)?, NoError> in
                                        if case let .result(_, items, _) = result {
                                            return .single(items.first.flatMap { ($0.file._parse(), result) })
                                        } else {
                                            return .complete()
                                        }
                                    }).startStrict(next: { fileAndPackTitle in
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        strongSelf.emojiStatusFileAndPackTitle.set(.single(fileAndPackTitle))
                                    }))
                                    break
                                }
                            }
                        } else {
                            strongSelf.emojiStatusFileAndPackTitle.set(.never())
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
        
        self.navigationButtonContainer.updateContentsColor(backgroundContentColor: headerButtonBackgroundColor, contentsColor: navigationContentsAccentColor, canBeExpanded: navigationContentsCanBeExpanded, transition: navigationTransition)
        
        self.titleNode.updateTintColor(color: navigationContentsPrimaryColor, transition: navigationTransition)
        self.subtitleNode.updateTintColor(color: navigationContentsSecondaryColor, transition: navigationTransition)
        self.panelSubtitleNode.updateTintColor(color: navigationContentsSecondaryColor, transition: navigationTransition)
        if let navigationBar = self.controller?.navigationBar {
            if let mainContentNode = navigationBar.backButtonNode.mainContentNode {
                navigationTransition.updateTintColor(layer: mainContentNode.layer, color: navigationContentsAccentColor)
            }
            navigationTransition.updateTintColor(layer: navigationBar.backButtonArrow.layer, color: navigationContentsAccentColor)
            
            if let mainContentNode = navigationBar.leftButtonNode.mainContentNode {
                navigationTransition.updateTintColor(layer: mainContentNode.layer, color: navigationContentsAccentColor)
            }
            
            navigationBar.rightButtonNode.contentsColor = navigationContentsAccentColor
            navigationBar.leftButtonNode.contentsColor = navigationContentsAccentColor
            navigationBar.backButtonNode.contentsColor = navigationContentsAccentColor
        }
        
        var titleBrightness: CGFloat = 0.0
        navigationContentsPrimaryColor.getHue(nil, saturation: nil, brightness: &titleBrightness, alpha: nil)
        self.controller?.setStatusBarStyle(titleBrightness > 0.5 ? .White : .Black, animated: !isFirstTime && animateHeader)
        
        self.avatarListNode.avatarContainerNode.updateTransitionFraction(transitionFraction, transition: transition)
        self.avatarListNode.listContainerNode.currentItemNode?.updateTransitionFraction(transitionFraction, transition: transition)
        self.avatarOverlayNode.updateTransitionFraction(transitionFraction, transition: transition)
        
        if self.navigationTitle != presentationData.strings.EditProfile_Title || themeUpdated {
            self.navigationTitleNode.attributedText = NSAttributedString(string: presentationData.strings.EditProfile_Title, font: Font.semibold(17.0), textColor: .white)
        }
        
        let navigationTitleSize = self.navigationTitleNode.updateLayout(CGSize(width: width, height: navigationHeight))
        self.navigationTitleNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((width - navigationTitleSize.width) / 2.0), y: navigationHeight - 44.0 + floorToScreenPixels((44.0 - navigationTitleSize.height) / 2.0)), size: navigationTitleSize)
        
        self.navigationBackgroundNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: navigationHeight))
        self.navigationBackgroundBackgroundNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: navigationHeight))
        self.navigationSeparatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: navigationHeight), size: CGSize(width: width, height: UIScreenPixel))
        self.navigationBackgroundBackgroundNode.backgroundColor = presentationData.theme.rootController.navigationBar.opaqueBackgroundColor
        self.navigationSeparatorNode.backgroundColor = presentationData.theme.rootController.navigationBar.separatorColor

        let navigationSeparatorAlpha: CGFloat = 0.0
        transition.updateAlpha(node: self.navigationBackgroundBackgroundNode, alpha: 1.0 - navigationSeparatorAlpha)
        transition.updateAlpha(node: self.navigationSeparatorNode, alpha: navigationSeparatorAlpha)

        self.separatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        let expandedAvatarControlsHeight: CGFloat = 61.0
        var expandedAvatarListHeight = min(width, containerHeight - expandedAvatarControlsHeight)
        if self.isSettings || self.isMyProfile {
            expandedAvatarListHeight = expandedAvatarListHeight + 60.0
        } else {
            expandedAvatarListHeight = expandedAvatarListHeight + 98.0
        }
        
        let expandedAvatarListSize = CGSize(width: width, height: expandedAvatarListHeight)
        
        let actionButtonKeys: [PeerInfoHeaderButtonKey] = (self.isSettings || self.isMyProfile) ? [] : peerInfoHeaderActionButtons(peer: peer, isSecretChat: isSecretChat, isContact: isContact)
        let buttonKeys: [PeerInfoHeaderButtonKey] = (self.isSettings || self.isMyProfile) ? [] : peerInfoHeaderButtons(peer: peer, cachedData: cachedData, isOpenedFromChat: self.isOpenedFromChat, isExpanded: true, videoCallsEnabled: width > 320.0 && self.videoCallsEnabled, isSecretChat: isSecretChat, isContact: isContact, threadInfo: threadData?.info)
        
        var isPremium = false
        var isVerified = false
        var isFake = false
        let titleStringText: String
        let smallTitleAttributes: MultiScaleTextState.Attributes
        let titleAttributes: MultiScaleTextState.Attributes
        let subtitleStringText: String
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
                title = EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
            }
            title = title.replacingOccurrences(of: "\u{1160}", with: "").replacingOccurrences(of: "\u{3164}", with: "")
            if title.replacingOccurrences(of: "\u{fe0e}", with: "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                title = "" //"\u{00A0}"
            }
            if title.isEmpty {
                if let peer = peer as? TelegramUser, let phone = peer.phone {
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
            
            if self.isSettings, let user = peer as? TelegramUser {
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
                let subtitleColor: UIColor
                subtitleColor = UIColor.white
                
                let statusText: String
                statusText = peer.debugDisplayTitle
                
                subtitleStringText = statusText
                subtitleAttributes = MultiScaleTextState.Attributes(font: Font.semibold(16.0), color: subtitleColor)
                smallSubtitleAttributes = MultiScaleTextState.Attributes(font: Font.regular(16.0), color: .white, shadowColor: titleShadowColor)
                
                usernameString = ("", MultiScaleTextState.Attributes(font: Font.regular(16.0), color: .white))
                
                subtitleIsButton = true

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
        
        let titleConstrainedSize = CGSize(width: width - textSideInset * 2.0 - (isPremium || isVerified || isFake ? 20.0 : 0.0), height: .greatestFiniteMagnitude)
        
        let titleNodeLayout = self.titleNode.updateLayout(text: titleStringText, states: [
            TitleNodeStateRegular: MultiScaleTextState(attributes: titleAttributes, constrainedSize: titleConstrainedSize),
            TitleNodeStateExpanded: MultiScaleTextState(attributes: smallTitleAttributes, constrainedSize: titleConstrainedSize)
        ], mainState: TitleNodeStateRegular)
        
        let subtitleNodeLayout = self.subtitleNode.updateLayout(text: subtitleStringText, states: [
            TitleNodeStateRegular: MultiScaleTextState(attributes: subtitleAttributes, constrainedSize: titleConstrainedSize),
            TitleNodeStateExpanded: MultiScaleTextState(attributes: smallSubtitleAttributes, constrainedSize: titleConstrainedSize)
        ], mainState: TitleNodeStateRegular)
        self.subtitleNode.accessibilityLabel = subtitleStringText
        
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
                if themeUpdated {
                    subtitleArrowNode.image = generateTintedImage(image: UIImage(bundleImageName: "Item List/DisclosureArrow"), color: .white)?.withRenderingMode(.alwaysTemplate)
                }
            } else {
                subtitleArrowNode = ASImageNode()
                self.subtitleArrowNode = subtitleArrowNode
                self.subtitleNode.insertSubnode(subtitleArrowNode, at: 1)
                
                subtitleArrowNode.image = generateTintedImage(image: UIImage(bundleImageName: "Item List/DisclosureArrow"), color: .white)?.withRenderingMode(.alwaysTemplate)
            }
            subtitleBackgroundNode.backgroundColor = .white.withMultipliedAlpha(0.1)
            let subtitleSize = subtitleNodeLayout[TitleNodeStateRegular]!.size
            var subtitleBackgroundFrame = CGRect(origin: CGPoint(), size: subtitleSize).offsetBy(dx: -subtitleSize.width * 0.5, dy: -subtitleSize.height * 0.5).insetBy(dx: -6.0, dy: -4.0)
            subtitleBackgroundFrame.size.width += 12.0
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
                let direction: CGFloat = previousPanelStatusDataKey.rawValue > currentPanelStatusDataKey.rawValue ? 1.0 : -1.0
                
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
        
        let panelSubtitleNodeLayout = self.panelSubtitleNode.updateLayout(text: panelSubtitleString?.text ?? subtitleStringText, states: [
            TitleNodeStateRegular: MultiScaleTextState(attributes: panelSubtitleString?.attributes ?? subtitleAttributes, constrainedSize: titleConstrainedSize),
            TitleNodeStateExpanded: MultiScaleTextState(attributes: panelSubtitleString?.attributes ?? subtitleAttributes, constrainedSize: titleConstrainedSize)
        ], mainState: TitleNodeStateRegular)
        self.panelSubtitleNode.accessibilityLabel = panelSubtitleString?.text ?? subtitleStringText
        
        let usernameNodeLayout = self.usernameNode.updateLayout(text: usernameString.text, states: [
            TitleNodeStateRegular: MultiScaleTextState(attributes: usernameString.attributes, constrainedSize: CGSize(width: titleConstrainedSize.width, height: titleConstrainedSize.height)),
            TitleNodeStateExpanded: MultiScaleTextState(attributes: usernameString.attributes, constrainedSize: CGSize(width: width - titleNodeLayout[TitleNodeStateExpanded]!.size.width - 8.0, height: titleConstrainedSize.height))
        ], mainState: TitleNodeStateRegular)
        self.usernameNode.accessibilityLabel = usernameString.text
        
        let avatarCenter: CGPoint
        if let transitionSourceAvatarFrame = transitionSourceAvatarFrame {
            avatarCenter = CGPoint(x: (1.0 - transitionFraction) * avatarFrame.midX + transitionFraction * transitionSourceAvatarFrame.midX, y: (1.0 - transitionFraction) * avatarFrame.midY + transitionFraction * transitionSourceAvatarFrame.midY)
        } else {
            avatarCenter = avatarFrame.center
        }
        
        let titleSize = titleNodeLayout[TitleNodeStateRegular]!.size
        let titleExpandedSize = titleNodeLayout[TitleNodeStateExpanded]!.size
        let subtitleSize = subtitleNodeLayout[TitleNodeStateRegular]!.size
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
            
            var collapsedTransitionOffset: CGFloat = 0.0
            if let navigationTransition = self.navigationTransition {
                collapsedTransitionOffset = -10.0 * navigationTransition.fraction
            }
            
            transition.updateFrame(view: self.titleStatusIconView, frame: CGRect(origin: CGPoint(x: leftOffset + collapsedTransitionOffset, y: floor((titleSize.height - statusIconSize.height) / 2.0)), size: statusIconSize))
            transition.updateFrame(view: self.titleExpandedStatusIconView, frame: CGRect(origin: CGPoint(x: leftExpandedOffset, y: floor((titleExpandedSize.height - titleExpandedStatusIconSize.height) / 2.0) + 1.0), size: titleExpandedStatusIconSize))
            
            nextIconX += 4.0 + statusIconSize.width
            nextExpandedIconX += 4.0 + titleExpandedStatusIconSize.width
        }
        
        if let credibilityIconSize = self.credibilityIconSize, let titleExpandedCredibilityIconSize = self.titleExpandedCredibilityIconSize, credibilityIconSize.width > 0.0 {
            let offset = (credibilityIconSize.width + 4.0) / 2.0
           
            let leftOffset: CGFloat = nextIconX + 4.0
            let leftExpandedOffset: CGFloat = nextExpandedIconX + 4.0
            titleHorizontalOffset -= offset
            
            var collapsedTransitionOffset: CGFloat = 0.0
            if let navigationTransition = self.navigationTransition {
                collapsedTransitionOffset = -10.0 * navigationTransition.fraction
            }
            
            transition.updateFrame(view: self.titleCredibilityIconView, frame: CGRect(origin: CGPoint(x: leftOffset + collapsedTransitionOffset, y: floor((titleSize.height - credibilityIconSize.height) / 2.0)), size: credibilityIconSize))
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
           
            var collapsedTransitionOffset: CGFloat = 0.0
            if let navigationTransition = self.navigationTransition {
                collapsedTransitionOffset = -10.0 * navigationTransition.fraction
            }
            
            transition.updateFrame(view: self.titleVerifiedIconView, frame: CGRect(origin: CGPoint(x: leftOffset + collapsedTransitionOffset, y: floor((titleSize.height - verifiedIconSize.height) / 2.0)), size: verifiedIconSize))
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
        
        let titleLockOffset: CGFloat = 7.0 + singleTitleLockOffset
        let titleMaxLockOffset: CGFloat = 7.0
        let titleOffset: CGFloat
        let titleCollapseFraction: CGFloat
        
        if self.isAvatarExpanded {
            let minTitleSize = CGSize(width: titleSize.width * expandedTitleScale, height: titleSize.height * expandedTitleScale)
            var minTitleFrame = CGRect(origin: CGPoint(x: 16.0, y: expandedAvatarHeight - 58.0 - UIScreenPixel + (subtitleSize.height.isZero ? 10.0 : 0.0)), size: minTitleSize)
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
            
            subtitleFrame = CGRect(origin: CGPoint(x: 16.0, y: minTitleFrame.maxY + 2.0), size: subtitleSize)
            usernameFrame = CGRect(origin: CGPoint(x: width - usernameSize.width - 16.0, y: minTitleFrame.midY - usernameSize.height / 2.0), size: usernameSize)
        } else {
            titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((width - titleSize.width) / 2.0), y: avatarFrame.maxY + 9.0 + (subtitleSize.height.isZero ? 11.0 : 0.0)), size: titleSize)
            
            var titleCollapseOffset = titleFrame.midY - statusBarHeight - titleLockOffset
            if case .regular = metrics.widthClass, !isSettings, !isMyProfile {
                titleCollapseOffset -= 7.0
            }
            titleOffset = -min(titleCollapseOffset, contentOffset)
            titleCollapseFraction = max(0.0, min(1.0, contentOffset / titleCollapseOffset))
                        
            var effectiveSubtitleWidth = subtitleSize.width
            if let subtitleBadgeSize {
                effectiveSubtitleWidth += (subtitleBadgeSize.width + 7.0) * (1.0 - titleCollapseFraction)
            }
            
            let totalSubtitleWidth = effectiveSubtitleWidth + usernameSpacing + usernameSize.width
            if usernameSize.width == 0.0 {
                subtitleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((width - effectiveSubtitleWidth) / 2.0), y: titleFrame.maxY + 1.0), size: subtitleSize)
                usernameFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((width - usernameSize.width) / 2.0), y: subtitleFrame.maxY + 1.0), size: usernameSize)
            } else {
                subtitleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((width - totalSubtitleWidth) / 2.0), y: titleFrame.maxY + 1.0), size: subtitleSize)
                usernameFrame = CGRect(origin: CGPoint(x: subtitleFrame.maxX + usernameSpacing, y: titleFrame.maxY + 1.0), size: usernameSize)
            }
        }
        
        let titleMinScale: CGFloat = 0.6
        let subtitleMinScale: CGFloat = 0.8
        let avatarMinScale: CGFloat = 0.55
        
        let apparentTitleLockOffset = (1.0 - titleCollapseFraction) * 0.0 + titleCollapseFraction * titleMaxLockOffset

        let paneAreaExpansionDistance: CGFloat = 32.0
        let effectiveAreaExpansionFraction: CGFloat
        if state.isEditing {
            effectiveAreaExpansionFraction = 0.0
        } else if isSettings || isMyProfile {
            var paneAreaExpansionDelta = (self.frame.maxY - navigationHeight) - contentOffset
            paneAreaExpansionDelta = max(0.0, min(paneAreaExpansionDelta, paneAreaExpansionDistance))
            effectiveAreaExpansionFraction = 1.0 - paneAreaExpansionDelta / paneAreaExpansionDistance
        } else {
            var paneAreaExpansionDelta = (paneContainerY - navigationHeight) - contentOffset
            paneAreaExpansionDelta = max(0.0, min(paneAreaExpansionDelta, paneAreaExpansionDistance))
            effectiveAreaExpansionFraction = 1.0 - paneAreaExpansionDelta / paneAreaExpansionDistance
        }
        
        let secondarySeparatorAlpha = 1.0 - effectiveAreaExpansionFraction
        if self.navigationTransition == nil && !self.isSettings && effectiveSeparatorAlpha == 1.0 && secondarySeparatorAlpha < 1.0 {
            effectiveSeparatorAlpha = secondarySeparatorAlpha
        }
        if self.customNavigationContentNode != nil {
            effectiveSeparatorAlpha = 0.0
        }
        if state.isEditing {
            effectiveSeparatorAlpha = 0.0
        }
        transition.updateAlpha(node: self.separatorNode, alpha: effectiveSeparatorAlpha)
        
        self.titleNode.update(stateFractions: [
            TitleNodeStateRegular: self.isAvatarExpanded ? 0.0 : 1.0,
            TitleNodeStateExpanded: self.isAvatarExpanded ? 1.0 : 0.0
        ], transition: transition)
        
        let subtitleAlpha: CGFloat
        var subtitleOffset: CGFloat = 0.0
        let panelSubtitleAlpha: CGFloat
        var panelSubtitleOffset: CGFloat = 0.0
        if self.isSettings {
            subtitleAlpha = 1.0 - titleCollapseFraction
            panelSubtitleAlpha = 0.0
        } else {
            if (panelSubtitleString?.text ?? subtitleStringText) != subtitleStringText {
                subtitleAlpha = 1.0 - effectiveAreaExpansionFraction
                panelSubtitleAlpha = effectiveAreaExpansionFraction
                
                subtitleOffset = -effectiveAreaExpansionFraction * 5.0
                panelSubtitleOffset = (1.0 - effectiveAreaExpansionFraction) * 5.0
            } else {
                if self.navigationTransition != nil {
                    subtitleAlpha = 1.0
                    panelSubtitleAlpha = 0.0
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
        if self.navigationTransition != nil {
            if let transitionSourceAvatarFrame = transitionSourceAvatarFrame {
                var trueAvatarSize = transitionSourceAvatarFrame.size
                if let storyStats = self.avatarListNode.avatarContainerNode.avatarNode.storyStats, storyStats.unseenCount != 0 {
                    trueAvatarSize.width -= 1.33 * 4.0
                    trueAvatarSize.height -= 1.33 * 4.0
                }
                
                avatarScale = ((1.0 - transitionFraction) * avatarFrame.width + transitionFraction * trueAvatarSize.width) / avatarFrame.width
            } else {
                avatarScale = 1.0
            }
            avatarOffset = 0.0
        } else {
            //
            avatarScale = 1.0 * (1.0 - titleCollapseFraction) + avatarMinScale * titleCollapseFraction
            avatarOffset = apparentTitleLockOffset + 0.0 * (1.0 - titleCollapseFraction) + 10.0 * titleCollapseFraction
        }
        
        if let previousAvatarView = self.navigationTransition?.previousAvatarView, let transitionSourceAvatarFrame {
            let previousScale = ((1.0 - transitionFraction) * avatarFrame.width + transitionFraction * transitionSourceAvatarFrame.width) / transitionSourceAvatarFrame.width
            
            transition.updateAlpha(layer: previousAvatarView.layer, alpha: transitionFraction)
            transition.updateTransformScale(layer: previousAvatarView.layer, scale: previousScale)
            transition.updatePosition(layer: previousAvatarView.layer, position: self.view.convert(CGPoint(x: avatarCenter.x - (27.0 * (1.0 - transitionFraction) + 10 * transitionFraction), y: avatarCenter.y - (2.66 * (1.0 - transitionFraction) + 1.0 * transitionFraction)), to: previousAvatarView.superview))
        }
        
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
            if let transitionSourceAvatarFrame = transitionSourceAvatarFrame {
                var trueAvatarSize = transitionSourceAvatarFrame.size
                if let storyStats = self.avatarListNode.avatarContainerNode.avatarNode.storyStats, storyStats.unseenCount != 0 {
                    trueAvatarSize.width -= 1.33 * 4.0
                    trueAvatarSize.height -= 1.33 * 4.0
                }
                
                transition.updateCornerRadius(node: self.avatarListNode.listContainerNode, cornerRadius: transitionFraction * trueAvatarSize.width / 2.0)
                transition.updateCornerRadius(node: self.avatarListNode.listContainerNode.controlsClippingNode, cornerRadius: transitionFraction * trueAvatarSize.width / 2.0)
            } else {
                transition.updateCornerRadius(node: self.avatarListNode.listContainerNode, cornerRadius: 0.0)
                transition.updateCornerRadius(node: self.avatarListNode.listContainerNode.controlsClippingNode, cornerRadius: 0.0)
            }
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
            transition.updateAlpha(layer: avatarStoryView.layer, alpha: 1.0 - transitionFraction)
        }
        
        var apparentAvatarFrame: CGRect
        var apparentAvatarListFrame: CGRect
        let controlsClippingFrame: CGRect
        if self.isAvatarExpanded {
            let expandedAvatarCenter = CGPoint(x: expandedAvatarListSize.width / 2.0, y: expandedAvatarListSize.width / 2.0 - contentOffset / 2.0)
            apparentAvatarFrame = CGRect(origin: CGPoint(x: expandedAvatarCenter.x * (1.0 - transitionFraction) + transitionFraction * avatarCenter.x, y: expandedAvatarCenter.y * (1.0 - transitionFraction) + transitionFraction * avatarCenter.y), size: CGSize())
            
            let expandedAvatarListCenter = CGPoint(x: expandedAvatarListSize.width / 2.0, y: expandedAvatarListSize.height / 2.0 - contentOffset / 2.0)
            apparentAvatarListFrame = CGRect(origin: CGPoint(x: expandedAvatarListCenter.x * (1.0 - transitionFraction) + transitionFraction * avatarCenter.x, y: expandedAvatarListCenter.y * (1.0 - transitionFraction) + transitionFraction * avatarCenter.y), size: CGSize())
            
            if let transitionSourceAvatarFrame = transitionSourceAvatarFrame {
                var trueAvatarSize = transitionSourceAvatarFrame.size
                if let storyStats = self.avatarListNode.avatarContainerNode.avatarNode.storyStats, storyStats.unseenCount != 0 {
                    trueAvatarSize.width -= 1.33 * 4.0
                    trueAvatarSize.height -= 1.33 * 4.0
                }
                let trueAvatarFrame = trueAvatarSize.centered(around: transitionSourceAvatarFrame.center)
                
                let expandedFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: expandedAvatarListSize)
                controlsClippingFrame = CGRect(origin: CGPoint(x: transitionFraction * trueAvatarFrame.minX + (1.0 - transitionFraction) * expandedFrame.minX, y: transitionFraction * trueAvatarFrame.minY + (1.0 - transitionFraction) * expandedFrame.minY), size: CGSize(width: transitionFraction * trueAvatarFrame.width + (1.0 - transitionFraction) * expandedFrame.width, height: transitionFraction * trueAvatarFrame.height + (1.0 - transitionFraction) * expandedFrame.height))
            } else {
                controlsClippingFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: expandedAvatarListSize)
            }
        } else {
            var trueAvatarSize = avatarFrame.size
            if let storyStats = self.avatarListNode.avatarContainerNode.avatarNode.storyStats, storyStats.totalCount != 0 {
                trueAvatarSize.width -= 3.0 * 4.0
                trueAvatarSize.height -= 3.0 * 4.0
            }
            apparentAvatarFrame = CGRect(origin: CGPoint(x: avatarCenter.x - trueAvatarSize.width / 2.0, y: -contentOffset + avatarOffset + avatarCenter.y - trueAvatarSize.height / 2.0), size: trueAvatarSize)
            apparentAvatarListFrame = apparentAvatarFrame
            controlsClippingFrame = apparentAvatarFrame
        }
        
        let avatarClipOffset: CGFloat = !self.isAvatarExpanded && deviceMetrics.hasDynamicIsland && statusBarHeight > 0.0 && self.avatarClippingNode.clipsToBounds && !isLandscape ? 47.0 : 0.0
        let clippingNodeTransition = ContainedViewLayoutTransition.immediate
        clippingNodeTransition.updateFrame(layer: self.avatarClippingNode.layer, frame: CGRect(origin: CGPoint(x: 0.0, y: avatarClipOffset), size: CGSize(width: width, height: 1000.0)))
        clippingNodeTransition.updateSublayerTransformOffset(layer: self.avatarClippingNode.layer, offset: CGPoint(x: 0.0, y: -avatarClipOffset))
        let clippingNodeRadiusTransition = ContainedViewLayoutTransition.animated(duration: 0.15, curve: .easeInOut)
        clippingNodeRadiusTransition.updateCornerRadius(node: self.avatarClippingNode, cornerRadius: avatarClipOffset > 0.0 ? width / 2.5 : 0.0)
        
        let _ = apparentAvatarListFrame
        transition.updateFrameAdditive(node: self.avatarListNode, frame: CGRect(origin: apparentAvatarFrame.center, size: CGSize()))
        transition.updateFrameAdditive(node: self.avatarOverlayNode, frame: CGRect(origin: apparentAvatarFrame.center, size: CGSize()))
        
        let avatarListContainerFrame: CGRect
        let avatarListContainerScale: CGFloat
        if self.isAvatarExpanded {
            if let transitionSourceAvatarFrame = transitionSourceAvatarFrame {
                let neutralAvatarListContainerSize = expandedAvatarListSize
                var avatarListContainerSize = CGSize(width: neutralAvatarListContainerSize.width * (1.0 - transitionFraction) + transitionSourceAvatarFrame.width * transitionFraction, height: neutralAvatarListContainerSize.height * (1.0 - transitionFraction) + transitionSourceAvatarFrame.height * transitionFraction)
                
                if let storyStats = self.avatarListNode.avatarContainerNode.avatarNode.storyStats, storyStats.unseenCount != 0 {
                    avatarListContainerSize.width -= 1.33 * 5.0
                    avatarListContainerSize.height -= 1.33 * 5.0
                }
                
                avatarListContainerFrame = CGRect(origin: CGPoint(x: -avatarListContainerSize.width / 2.0, y: -avatarListContainerSize.width / 2.0), size: avatarListContainerSize)
            } else {
                avatarListContainerFrame = CGRect(origin: CGPoint(x: -expandedAvatarListSize.width / 2.0, y: -expandedAvatarListSize.width / 2.0), size: expandedAvatarListSize)
            }
            avatarListContainerScale = 1.0 + max(0.0, -contentOffset / avatarListContainerFrame.width)
        } else {
            let expandHeightFraction = expandedAvatarListSize.height / expandedAvatarListSize.width
            avatarListContainerFrame = CGRect(origin: CGPoint(x: -apparentAvatarFrame.width / 2.0, y: -apparentAvatarFrame.width / 2.0 + expandHeightFraction * 0.0 * apparentAvatarFrame.width), size: apparentAvatarFrame.size)
            avatarListContainerScale = avatarScale
        }
        transition.updateFrame(node: self.avatarListNode.listContainerNode, frame: avatarListContainerFrame)
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
        transition.updateAlpha(node: self.avatarListNode.listContainerNode.controlsContainerNode, alpha: self.isAvatarExpanded ? (1.0 - transitionFraction) : 0.0)
        
        if additive {
            transition.updateSublayerTransformScaleAdditive(node: self.avatarListNode.listContainerTransformNode, scale: avatarListContainerScale)
        } else {
            transition.updateSublayerTransformScale(node: self.avatarListNode.listContainerTransformNode, scale: avatarListContainerScale)
        }
        
        if deviceMetrics.hasDynamicIsland && statusBarHeight > 0.0 && self.forumTopicThreadId == nil && self.navigationTransition == nil && !isLandscape {
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
        
        self.avatarListNode.listContainerNode.update(size: expandedAvatarListSize, peer: peer.flatMap(EnginePeer.init), isExpanded: self.isAvatarExpanded, transition: transition)
        if self.avatarListNode.listContainerNode.isCollapsing && !self.ignoreCollapse {
            self.avatarListNode.avatarContainerNode.canAttachVideo = false
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
            height = navigationHeight + max(0.0, expandablePart)
            maxY = navigationHeight + panelWithAvatarHeight - contentOffset
            backgroundHeight = height
        }
        let _ = maxY
        
        let apparentHeight = (1.0 - transitionFraction) * backgroundHeight + transitionFraction * transitionSourceHeight
        let apparentBackgroundHeight = (1.0 - transitionFraction) * backgroundHeight + transitionFraction * transitionSourceHeight
        
        if !titleSize.width.isZero && !titleSize.height.isZero {
            if self.navigationTransition != nil {
                var neutralTitleScale: CGFloat = 1.0
                var neutralSubtitleScale: CGFloat = 1.0
                if self.isAvatarExpanded {
                    neutralTitleScale = expandedTitleScale
                    neutralSubtitleScale = 1.0
                }
                                
                let titleScale = (transitionFraction * transitionSourceTitleFrame.height + (1.0 - transitionFraction) * titleFrame.height * neutralTitleScale) / (titleFrame.height)
                let subtitleScale = max(0.01, min(10.0, (transitionFraction * transitionSourceSubtitleFrame.height + (1.0 - transitionFraction) * subtitleFrame.height * neutralSubtitleScale) / (subtitleFrame.height)))
                
                var titleFrame = titleFrame
                if !self.isAvatarExpanded {
                    titleFrame = titleFrame.offsetBy(dx: titleHorizontalOffset * titleScale, dy: 0.0)
                } else {
                    titleFrame = titleFrame.offsetBy(dx: titleExpandedHorizontalOffset, dy: 0.0)
                }
                
                let titleCenter = CGPoint(x: transitionFraction * transitionSourceTitleFrame.midX + (1.0 - transitionFraction) * titleFrame.midX, y: transitionFraction * transitionSourceTitleFrame.midY + (1.0 - transitionFraction) * titleFrame.midY)
                let subtitleCenter = CGPoint(x: transitionFraction * transitionSourceSubtitleFrame.midX + (1.0 - transitionFraction) * subtitleFrame.midX, y: transitionFraction * transitionSourceSubtitleFrame.midY + (1.0 - transitionFraction) * subtitleFrame.midY)
                
                let rawTitleFrame = CGRect(origin: CGPoint(x: titleCenter.x - titleFrame.size.width * neutralTitleScale / 2.0, y: titleCenter.y - titleFrame.size.height * neutralTitleScale / 2.0), size: CGSize(width: titleFrame.size.width * neutralTitleScale, height: titleFrame.size.height * neutralTitleScale))
                self.titleNodeRawContainer.frame = rawTitleFrame
                transition.updateFrameAdditiveToCenter(node: self.titleNodeContainer, frame: CGRect(origin: rawTitleFrame.center, size: CGSize()))
                transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(), size: CGSize()))
                let rawSubtitleFrame = CGRect(origin: CGPoint(x: subtitleCenter.x - subtitleFrame.size.width / 2.0, y: subtitleCenter.y - subtitleFrame.size.height / 2.0), size: subtitleFrame.size)
                self.subtitleNodeRawContainer.frame = rawSubtitleFrame
                transition.updateFrameAdditiveToCenter(node: self.subtitleNodeContainer, frame: CGRect(origin: rawSubtitleFrame.center, size: CGSize()))
                transition.updateFrame(node: self.subtitleNode, frame: CGRect(origin: CGPoint(x: 0.0, y: subtitleOffset), size: CGSize()))
                transition.updateFrame(node: self.panelSubtitleNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelSubtitleOffset - 1.0), size: CGSize()))
                transition.updateFrame(node: self.usernameNode, frame: CGRect(origin: CGPoint(), size: CGSize()))
                transition.updateSublayerTransformScale(node: self.titleNodeContainer, scale: titleScale)
                transition.updateSublayerTransformScale(node: self.subtitleNodeContainer, scale: subtitleScale)
                transition.updateSublayerTransformScale(node: self.usernameNodeContainer, scale: subtitleScale)
                
                if let subtitleBadgeView = self.subtitleBadgeView, let subtitleBadgeSize {
                    let subtitleBadgeFrame = CGRect(origin: CGPoint(x: (subtitleSize.width + 8.0) * 0.5, y: floor((-subtitleBadgeSize.height) * 0.5)), size: subtitleBadgeSize)
                    transition.updateFrameAdditive(view: subtitleBadgeView, frame: subtitleBadgeFrame)
                    transition.updateAlpha(layer: subtitleBadgeView.layer, alpha: (1.0 - transitionFraction))
                }
            } else {
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
                transition.updateFrame(node: self.subtitleNode, frame: CGRect(origin: CGPoint(x: 0.0, y: subtitleOffset), size: CGSize()))
                transition.updateFrame(node: self.panelSubtitleNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelSubtitleOffset - 1.0), size: CGSize()))
                transition.updateFrame(node: self.usernameNode, frame: CGRect(origin: CGPoint(), size: CGSize()))
                transition.updateSublayerTransformScaleAdditive(node: self.titleNodeContainer, scale: titleScale)
                transition.updateSublayerTransformScaleAdditive(node: self.subtitleNodeContainer, scale: subtitleScale)
                transition.updateSublayerTransformScaleAdditive(node: self.usernameNodeContainer, scale: subtitleScale)
                
                if let subtitleBadgeView = self.subtitleBadgeView, let subtitleBadgeSize {
                    let subtitleBadgeFrame = CGRect(origin: CGPoint(x: (subtitleSize.width + 8.0) * 0.5, y: floor((-subtitleBadgeSize.height) * 0.5)), size: subtitleBadgeSize)
                    transition.updateFrameAdditive(view: subtitleBadgeView, frame: subtitleBadgeFrame)
                    transition.updateAlpha(layer: subtitleBadgeView.layer, alpha: (1.0 - transitionFraction) * subtitleBadgeFraction)
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
        
        let actionButtonWidth = (width - buttonSideInset * 2.0 + buttonSpacing) / CGFloat(actionButtonKeys.count) - buttonSpacing
        let actionButtonSize = CGSize(width: actionButtonWidth, height: 40.0)
        var actionButtonRightOrigin = CGPoint(x: width - buttonSideInset, y: backgroundHeight - 16.0 - actionButtonSize.height)
        
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
        
        let buttonWidth = (width - buttonSideInset * 2.0 + buttonSpacing) / CGFloat(buttonKeys.count) - buttonSpacing
        let buttonSize = CGSize(width: buttonWidth, height: 58.0)
        var buttonRightOrigin = CGPoint(x: width - buttonSideInset, y: backgroundHeight - 16.0 - buttonSize.height)
        if !actionButtonKeys.isEmpty {
            buttonRightOrigin.y += actionButtonSize.height + 24.0
        }
        
        transition.updateFrameAdditive(node: self.buttonsBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: buttonRightOrigin.y), size: CGSize(width: width, height: buttonSize.height)))
        self.buttonsBackgroundNode.update(size: self.buttonsBackgroundNode.bounds.size, transition: transition)
        self.buttonsBackgroundNode.updateColor(color: contentButtonBackgroundColor, enableBlur: true, transition: transition)
        
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
                if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
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
            resolvedRegularHeight = panelWithAvatarHeight + navigationHeight
        }
        
        let backgroundFrame: CGRect
        let separatorFrame: CGRect
        
        var resolvedHeight: CGFloat
        
        if state.isEditing {
            resolvedHeight = editingContentHeight
            backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: -2000.0 + max(navigationHeight, resolvedHeight - contentOffset)), size: CGSize(width: width, height: 2000.0))
            separatorFrame = CGRect(origin: CGPoint(x: 0.0, y: max(navigationHeight, resolvedHeight - contentOffset)), size: CGSize(width: width, height: UIScreenPixel))
        } else {
            resolvedHeight = resolvedRegularHeight
            backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: -2000.0 + apparentHeight), size: CGSize(width: width, height: 2000.0))
            separatorFrame = CGRect(origin: CGPoint(x: 0.0, y: apparentHeight), size: CGSize(width: width, height: UIScreenPixel))
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
            backgroundCoverSubject = .peer(EnginePeer(peer))
            if peer.profileColor != nil {
                hasBackground = true
            }
        } else {
            backgroundCoverSubject = nil
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
                avatarTransitionFraction: max(0.0, min(1.0, titleCollapseFraction + transitionFraction * 2.0)),
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
                    avatarTransitionFraction: max(0.0, min(1.0, titleCollapseFraction + transitionFraction * 2.0)),
                    statusBarHeight: statusBarHeight,
                    topLeftButtonsSize: CGSize(width: (self.isSettings ? 57.0 : 47.0), height: 46.0),
                    topRightButtonsSize: CGSize(width: 76.0 + (self.isMyProfile ? 38.0 : 0.0), height: 46.0),
                    titleWidth: max(140.0, titleFrame.width) + 42.0,
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
        
        if additive {
            transition.updateFrameAdditive(node: self.backgroundNode, frame: backgroundFrame)
            self.backgroundNode.update(size: self.backgroundNode.bounds.size, transition: transition)
            transition.updateFrameAdditive(node: self.expandedBackgroundNode, frame: backgroundFrame)
            self.expandedBackgroundNode.update(size: self.expandedBackgroundNode.bounds.size, transition: transition)
            transition.updateFrameAdditive(node: self.separatorNode, frame: separatorFrame)
        } else {
            transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
            self.backgroundNode.update(size: self.backgroundNode.bounds.size, transition: transition)
            transition.updateFrame(node: self.expandedBackgroundNode, frame: backgroundFrame)
            self.expandedBackgroundNode.update(size: self.expandedBackgroundNode.bounds.size, transition: transition)
            transition.updateFrame(node: self.separatorNode, frame: separatorFrame)
        }
        
        if !state.isEditing {
            if !isSettings && !isMyProfile {
                if self.isAvatarExpanded {
                    resolvedHeight -= 21.0
                } else {
                    resolvedHeight += 79.0
                    
                    if !actionButtonKeys.isEmpty {
                        resolvedHeight += 64.0
                    }
                }
            } else {
                if self.isAvatarExpanded {
                    resolvedHeight -= 21.0
                }
            }
        }
        
        if isFirstTime {
            self.updateAvatarMask(transition: .immediate)
        }
        
        return resolvedHeight
    }
    
    private func buttonPressed(_ buttonNode: PeerInfoHeaderButtonNode, gesture: ContextGesture?) {
        self.performButtonAction?(buttonNode.key, gesture)
    }
    
    private func actionButtonPressed(_ buttonNode: PeerInfoHeaderActionButtonNode, gesture: ContextGesture?) {
        self.performButtonAction?(buttonNode.key, gesture)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        if !self.backgroundNode.frame.contains(point) {
            return nil
        }
        
        if let customNavigationContentNode = self.customNavigationContentNode {
            if let result = customNavigationContentNode.view.hitTest(self.view.convert(point, to: customNavigationContentNode.view), with: event) {
                return result
            }
            return self.view
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
        
        if result.isDescendant(of: self.navigationButtonContainer.view) {
            return result
        }
        
        if self.isSettings {
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

