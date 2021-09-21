import Foundation
import UIKit
import Display
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import Postbox
import TelegramPresentationData
import TelegramStringFormatting
import SelectablePeerNode
import PeerPresenceStatusManager
import AccountContext
import ShimmerEffect

final class ShareControllerInteraction {
    var foundPeers: [RenderedPeer] = []
    var selectedPeerIds = Set<PeerId>()
    var selectedPeers: [RenderedPeer] = []
    let togglePeer: (RenderedPeer, Bool) -> Void
    
    init(togglePeer: @escaping (RenderedPeer, Bool) -> Void) {
        self.togglePeer = togglePeer
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
            return self.title == to.title
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
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let peer: RenderedPeer?
    let presence: PeerPresence?
    let controllerInteraction: ShareControllerInteraction
    let search: Bool
    
    let section: GridSection?
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, peer: RenderedPeer?, presence: PeerPresence?, controllerInteraction: ShareControllerInteraction, sectionTitle: String? = nil, search: Bool = false) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.peer = peer
        self.presence = presence
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
        node.setup(context: self.context, theme: self.theme, strings: self.strings, peer: self.peer, presence: self.presence, search: self.search, synchronousLoad: synchronousLoad, force: false)
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? ShareControllerPeerGridItemNode else {
            assertionFailure()
            return
        }
        node.controllerInteraction = self.controllerInteraction
        node.setup(context: self.context, theme: self.theme, strings: self.strings, peer: self.peer, presence: self.presence, search: self.search, synchronousLoad: false, force: false)
    }
}

final class ShareControllerPeerGridItemNode: GridItemNode {
    private var currentState: (AccountContext, PresentationTheme, PresentationStrings, RenderedPeer?, Bool, PeerPresence?)?
    private let peerNode: SelectablePeerNode
    private var presenceManager: PeerPresenceStatusManager?
    
    var controllerInteraction: ShareControllerInteraction?
    
    private var placeholderNode: ShimmerEffectNode?
    private var absoluteLocation: (CGRect, CGSize)?
    
    override init() {
        self.peerNode = SelectablePeerNode()
        
        super.init()
        
        self.peerNode.toggleSelection = { [weak self] in
            if let strongSelf = self {
                if let (_, _, _, maybePeer, search, _) = strongSelf.currentState, let peer = maybePeer {
                    if let _ = peer.peers[peer.peerId] {
                        strongSelf.controllerInteraction?.togglePeer(peer, search)
                    }
                }
            }
        }
        self.addSubnode(self.peerNode)
        self.presenceManager = PeerPresenceStatusManager(update: { [weak self] in
            guard let strongSelf = self, let currentState = strongSelf.currentState else {
                return
            }
            strongSelf.setup(context: currentState.0, theme: currentState.1, strings: currentState.2, peer: currentState.3, presence: currentState.5, search: currentState.4, synchronousLoad: false, force: true)
        })
    }
    
    override func updateAbsoluteRect(_ absoluteRect: CGRect, within containerSize: CGSize) {
        let rect = absoluteRect
        self.absoluteLocation = (rect, containerSize)
        if let shimmerNode = self.placeholderNode {
            shimmerNode.updateAbsoluteRect(rect, within: containerSize)
        }
    }
    
    func setup(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, peer: RenderedPeer?, presence: PeerPresence?, search: Bool, synchronousLoad: Bool, force: Bool) {
        if force || self.currentState == nil || self.currentState!.0 !== context || self.currentState!.3 != peer || !arePeerPresencesEqual(self.currentState!.5, presence) {
            let itemTheme = SelectablePeerNodeTheme(textColor: theme.actionSheet.primaryTextColor, secretTextColor: theme.chatList.secretTitleColor, selectedTextColor: theme.actionSheet.controlAccentColor, checkBackgroundColor: theme.actionSheet.opaqueItemBackgroundColor, checkFillColor: theme.actionSheet.controlAccentColor, checkColor: theme.actionSheet.checkContentColor, avatarPlaceholderColor: theme.list.mediaPlaceholderColor)
            
            let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
            var online = false
            if let peer = peer?.peer as? TelegramUser, let presence = presence as? TelegramUserPresence, !isServicePeer(peer) && !peer.flags.contains(.isSupport) && peer.id != context.account.peerId  {
                let relativeStatus = relativeUserPresenceStatus(EnginePeer.Presence(presence), relativeTo: timestamp)
                if case .online = relativeStatus {
                    online = true
                }
            }
            
            self.peerNode.theme = itemTheme
            if let peer = peer {
                self.peerNode.setup(context: context, theme: theme, strings: strings, peer: EngineRenderedPeer(peer), online: online, synchronousLoad: synchronousLoad)
                if let shimmerNode = self.placeholderNode {
                    self.placeholderNode = nil
                    shimmerNode.removeFromSupernode()
                }
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
            self.currentState = (context, theme, strings, peer, search, presence)
            self.setNeedsLayout()
            if let presence = presence as? TelegramUserPresence {
                self.presenceManager?.reset(presence: EnginePeer.Presence(presence))
            }
        }
        self.updateSelection(animated: false)
    }
    
    func updateSelection(animated: Bool) {
        var selected = false
        if let controllerInteraction = self.controllerInteraction, let (_, _, _, maybePeer, _, _) = self.currentState, let peer = maybePeer {
            selected = controllerInteraction.selectedPeerIds.contains(peer.peerId)
        }
        
        self.peerNode.updateSelection(selected: selected, animated: animated)
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        self.peerNode.frame = bounds
        self.placeholderNode?.frame = bounds
        
        if let (_, theme, _, _, _, _) = self.currentState, let shimmerNode = self.placeholderNode {
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
