import Foundation
import UIKit
import Display
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import TelegramPresentationData
import TelegramStringFormatting
import SelectablePeerNode
import PeerPresenceStatusManager
import AccountContext
import ShimmerEffect

final class ShareControllerInteraction {
    var foundPeers: [(peer: EngineRenderedPeer, requiresPremiumForMessaging: Bool)] = []
    var selectedPeerIds = Set<EnginePeer.Id>()
    var selectedPeers: [EngineRenderedPeer] = []
    
    var selectedTopics: [EnginePeer.Id: (Int64, MessageHistoryThreadData?)] = [:]
    
    let togglePeer: (EngineRenderedPeer, Bool) -> Void
    let selectTopic: (EngineRenderedPeer, Int64, MessageHistoryThreadData?) -> Void
    let shareStory: (() -> Void)?
    let disabledPeerSelected: (EngineRenderedPeer) -> Void
    
    init(togglePeer: @escaping (EngineRenderedPeer, Bool) -> Void, selectTopic: @escaping (EngineRenderedPeer, Int64, MessageHistoryThreadData?) -> Void, shareStory: (() -> Void)?, disabledPeerSelected: @escaping (EngineRenderedPeer) -> Void) {
        self.togglePeer = togglePeer
        self.selectTopic = selectTopic
        self.shareStory = shareStory
        self.disabledPeerSelected = disabledPeerSelected
    }
}

final class ShareControllerGridSection: GridSection {
    let height: CGFloat = 33.0
    
    private let title: String
    private let theme: PresentationTheme
    
    var hashValue: Int {
        return 1
    }
    
    init(title: String, theme: PresentationTheme) {
        self.title = title
        self.theme = theme
    }
    
    func isEqual(to: GridSection) -> Bool {
        if let to = to as? ShareControllerGridSection {
            return self.title == to.title && self.theme === to.theme
        } else {
            return false
        }
    }
    
    func node() -> ASDisplayNode {
        return ShareControllerGridSectionNode(title: self.title, theme: self.theme)
    }
}

private let sectionTitleFont = Font.bold(13.0)

final class ShareControllerGridSectionNode: ASDisplayNode {
    let backgroundNode: ASDisplayNode
    let titleNode: ASTextNode
    
    init(title: String, theme: PresentationTheme) {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = theme.chatList.sectionHeaderFillColor
        
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.attributedText = NSAttributedString(string: title.uppercased(), font: sectionTitleFont, textColor: theme.chatList.sectionHeaderTextColor)
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationMode = .byTruncatingTail
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.titleNode)
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        
        self.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: bounds.size.width, height: 27.0))
        
        let titleSize = self.titleNode.measure(CGSize(width: bounds.size.width - 24.0, height: CGFloat.greatestFiniteMagnitude))
        self.titleNode.frame = CGRect(origin: CGPoint(x: 16.0, y: 6.0 + UIScreenPixel), size: titleSize)
    }
}

final class ShareControllerPeerGridItem: GridItem {
    enum ShareItem: Equatable {
        enum StoryMode {
            case createStory
            case repostStory
            case repostMessage
        }
        
        case peer(peer: EngineRenderedPeer, presence: EnginePeer.Presence?, topicId: Int64?, threadData: MessageHistoryThreadData?, requiresPremiumForMessaging: Bool, requiresStars: Int64?)
        case story(mode: StoryMode)
        
        var peerId: EnginePeer.Id? {
            if case let .peer(peer, _, _, _, _, _) = self {
                return peer.peerId
            } else {
                return nil
            }
        }
    }
    
    let environment: ShareControllerEnvironment
    let context: ShareControllerAccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let item: ShareItem?
    let controllerInteraction: ShareControllerInteraction
    let search: Bool
    
    let section: GridSection?
    
    init(environment: ShareControllerEnvironment, context: ShareControllerAccountContext, theme: PresentationTheme, strings: PresentationStrings, item: ShareItem?, controllerInteraction: ShareControllerInteraction, sectionTitle: String? = nil, search: Bool = false) {
        self.environment = environment
        self.context = context
        self.theme = theme
        self.strings = strings
        self.item = item
        self.controllerInteraction = controllerInteraction
        self.search = search
        
        if let sectionTitle = sectionTitle {
            self.section = ShareControllerGridSection(title: sectionTitle, theme: self.theme)
        } else {
            self.section = nil
        }
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = ShareControllerPeerGridItemNode()
        node.controllerInteraction = self.controllerInteraction
        node.setup(environment: self.environment, context: self.context, theme: self.theme, strings: self.strings, item: self.item, search: self.search, synchronousLoad: synchronousLoad, force: false)
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? ShareControllerPeerGridItemNode else {
            assertionFailure()
            return
        }
        node.controllerInteraction = self.controllerInteraction
        node.setup(environment: self.environment, context: self.context, theme: self.theme, strings: self.strings, item: self.item, search: self.search, synchronousLoad: false, force: false)
    }
}

final class ShareControllerPeerGridItemNode: GridItemNode {
    private var currentState: (environment: ShareControllerEnvironment, accountContext: ShareControllerAccountContext, theme: PresentationTheme, strings: PresentationStrings, item: ShareControllerPeerGridItem.ShareItem?, search: Bool)?
    private let peerNode: SelectablePeerNode
    private var presenceManager: PeerPresenceStatusManager?
    
    var controllerInteraction: ShareControllerInteraction?
    
    private var placeholderNode: ShimmerEffectNode?
    private var absoluteLocation: (CGRect, CGSize)?
    
    var peerId: EnginePeer.Id? {
        if let item = self.currentState?.item, case let .peer(peer, _, _, _, _, _) = item {
            return peer.peerId
        } else {
            return nil
        }
    }
    
    override init() {
        self.peerNode = SelectablePeerNode()
        
        super.init()
        
        self.peerNode.toggleSelection = { [weak self] isDisabled in
            if let strongSelf = self {
                if let (_, _, _, _, maybeItem, search) = strongSelf.currentState, let item = maybeItem {
                    if case let .peer(peer, _, _, _, _, _) = item, let _ = peer.peers[peer.peerId] {
                        if isDisabled {
                            strongSelf.controllerInteraction?.disabledPeerSelected(peer)
                        } else {
                            strongSelf.controllerInteraction?.togglePeer(peer, search)
                        }
                    } else if case .story = item {
                        strongSelf.controllerInteraction?.shareStory?()
                    }
                }
            }
        }
        self.addSubnode(self.peerNode)
        self.presenceManager = PeerPresenceStatusManager(update: { [weak self] in
            guard let strongSelf = self, let currentState = strongSelf.currentState else {
                return
            }
            strongSelf.setup(environment: currentState.0, context: currentState.1, theme: currentState.2, strings: currentState.3, item: currentState.4, search: currentState.5, synchronousLoad: false, force: true)
        })
    }
    
    override func updateAbsoluteRect(_ absoluteRect: CGRect, within containerSize: CGSize) {
        let rect = absoluteRect
        self.absoluteLocation = (rect, containerSize)
        if let shimmerNode = self.placeholderNode {
            shimmerNode.updateAbsoluteRect(rect, within: containerSize)
        }
    }
    
    func setup(environment: ShareControllerEnvironment, context: ShareControllerAccountContext, theme: PresentationTheme, strings: PresentationStrings, item: ShareControllerPeerGridItem.ShareItem?, search: Bool, synchronousLoad: Bool, force: Bool) {
        if force || self.currentState == nil || self.currentState!.1 !== context || self.currentState!.3 !== theme || self.currentState!.item != item {
            let itemTheme = SelectablePeerNodeTheme(textColor: theme.actionSheet.primaryTextColor, secretTextColor: theme.chatList.secretTitleColor, selectedTextColor: theme.actionSheet.controlAccentColor, checkBackgroundColor: theme.actionSheet.opaqueItemBackgroundColor, checkFillColor: theme.actionSheet.controlAccentColor, checkColor: theme.actionSheet.checkContentColor, avatarPlaceholderColor: theme.list.mediaPlaceholderColor)
            
            var effectivePresence: EnginePeer.Presence?
            let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
            self.peerNode.theme = itemTheme
            if let item, case let .peer(renderedPeer, presence, _, threadData, requiresPremiumForMessaging, requiresStars) = item, let peer = renderedPeer.peer {
                effectivePresence = presence
                var isOnline = false
                var isSupport = false
                if case let .user(user) = peer, user.flags.contains(.isSupport) {
                    isSupport = true
                }
                if let presence, !peer.isService && !isSupport && peer.id != context.accountPeerId {
                    let relativeStatus = relativeUserPresenceStatus(presence, relativeTo: timestamp)
                    if case .online = relativeStatus {
                        isOnline = true
                    }
                }
                
                let resolveInlineStickers = context.resolveInlineStickers
                self.peerNode.setup(
                    accountPeerId: context.accountPeerId,
                    postbox: context.stateManager.postbox,
                    network: context.stateManager.network,
                    energyUsageSettings: environment.energyUsageSettings,
                    contentSettings: context.contentSettings,
                    animationCache: context.animationCache,
                    animationRenderer: context.animationRenderer,
                    resolveInlineStickers: { fileIds in
                        return resolveInlineStickers(fileIds)
                    },
                    theme: theme,
                    strings: strings,
                    peer: renderedPeer,
                    requiresPremiumForMessaging: requiresPremiumForMessaging,
                    requiresStars: requiresStars,
                    customTitle: threadData?.info.title,
                    iconId: threadData?.info.icon,
                    iconColor: threadData?.info.iconColor ?? 0,
                    online: isOnline,
                    synchronousLoad: synchronousLoad
                )
                if let shimmerNode = self.placeholderNode {
                    self.placeholderNode = nil
                    shimmerNode.removeFromSupernode()
                }
            } else if let item, case let .story(mode) = item {
                let storyMode: SelectablePeerNode.StoryMode
                switch mode {
                case .createStory:
                    storyMode = .createStory
                case .repostStory:
                    storyMode = .repostStory
                case .repostMessage:
                    storyMode = .repostMessage
                }
                self.peerNode.setupStoryRepost(
                    accountPeerId: context.accountPeerId,
                    postbox: context.stateManager.postbox,
                    network: context.stateManager.network,
                    theme: theme,
                    strings: strings,
                    synchronousLoad: synchronousLoad,
                    storyMode: storyMode
                )
            } else {
                let shimmerNode: ShimmerEffectNode
                if let current = self.placeholderNode {
                    shimmerNode = current
                } else {
                    shimmerNode = ShimmerEffectNode()
                    self.placeholderNode = shimmerNode
                    self.addSubnode(shimmerNode)
                }
                shimmerNode.frame = self.bounds
                if let (rect, size) = self.absoluteLocation {
                    shimmerNode.updateAbsoluteRect(rect, within: size)
                }
                
                var shapes: [ShimmerEffectNode.Shape] = []
                
                let titleLineWidth: CGFloat = 56.0
                let lineDiameter: CGFloat = 10.0
                
                let iconFrame = CGRect(x: 13.0, y: 4.0, width: 60.0, height: 60.0)
                shapes.append(.circle(iconFrame))
                
                let titleFrame = CGRect(x: 15.0, y: 70.0, width: 56.0, height: 10.0)
                shapes.append(.roundedRectLine(startPoint: CGPoint(x: titleFrame.minX, y: titleFrame.minY + floor((titleFrame.height - lineDiameter) / 2.0)), width: titleLineWidth, diameter: lineDiameter))
                
                shimmerNode.update(backgroundColor: theme.list.itemBlocksBackgroundColor, foregroundColor: theme.list.mediaPlaceholderColor, shimmeringColor: theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4), shapes: shapes, horizontal: true, size: self.bounds.size)
            }
            self.currentState = (environment, context, theme, strings, item, search)
            self.setNeedsLayout()
            if let effectivePresence {
                self.presenceManager?.reset(presence: effectivePresence)
            }
        }
        self.updateSelection(animated: false)
    }
    
    func updateSelection(animated: Bool) {
        var selected = false
        if let controllerInteraction = self.controllerInteraction, let (_, _, _, _, maybeItem, _) = self.currentState, let item = maybeItem {
            if case let .peer(peer, _, _, _, _, _) = item {
                selected = controllerInteraction.selectedPeerIds.contains(peer.peerId)
            }
        }
        
        self.peerNode.updateSelection(selected: selected, animated: animated)
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        self.peerNode.frame = bounds
        self.placeholderNode?.frame = bounds
        
        if let theme = self.currentState?.theme, let shimmerNode = self.placeholderNode {
            var shapes: [ShimmerEffectNode.Shape] = []
            
            let titleLineWidth: CGFloat = 56.0
            let lineDiameter: CGFloat = 10.0
            
            let iconFrame = CGRect(x: (bounds.width - 60.0) / 2.0, y: 4.0, width: 60.0, height: 60.0)
            shapes.append(.circle(iconFrame))
            
            let titleFrame = CGRect(x: (bounds.width - titleLineWidth) / 2.0, y: 70.0, width: titleLineWidth, height: 10.0)
            shapes.append(.roundedRectLine(startPoint: CGPoint(x: titleFrame.minX, y: titleFrame.minY + floor((titleFrame.height - lineDiameter) / 2.0)), width: titleLineWidth, diameter: lineDiameter))
            
            shimmerNode.update(backgroundColor: theme.list.itemBlocksBackgroundColor, foregroundColor: theme.list.mediaPlaceholderColor, shimmeringColor: theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4), shapes: shapes, horizontal: true, size: self.bounds.size)
        }
    }
}
