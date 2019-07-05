import Foundation
import UIKit
import Display
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import Postbox
import TelegramPresentationData

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
    let account: Account
    let theme: PresentationTheme
    let strings: PresentationStrings
    let peer: RenderedPeer
    let presence: PeerPresence?
    let controllerInteraction: ShareControllerInteraction
    let search: Bool
    
    let section: GridSection?
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings, peer: RenderedPeer, presence: PeerPresence?, controllerInteraction: ShareControllerInteraction, sectionTitle: String? = nil, search: Bool = false) {
        self.account = account
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
        node.setup(account: self.account, theme: self.theme, strings: self.strings, peer: self.peer, presence: self.presence, search: self.search, synchronousLoad: synchronousLoad)
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? ShareControllerPeerGridItemNode else {
            assertionFailure()
            return
        }
        node.controllerInteraction = self.controllerInteraction
        node.setup(account: self.account, theme: self.theme, strings: self.strings, peer: self.peer, presence: self.presence, search: self.search, synchronousLoad: false)
    }
}

final class ShareControllerPeerGridItemNode: GridItemNode {
    private var currentState: (Account, RenderedPeer, Bool)?
    private let peerNode: SelectablePeerNode
    
    var controllerInteraction: ShareControllerInteraction?
    
    override init() {
        self.peerNode = SelectablePeerNode()
        
        super.init()
        
        self.peerNode.toggleSelection = { [weak self] in
            if let strongSelf = self {
                if let (_, peer, search) = strongSelf.currentState {
                    if let actualPeer = peer.peers[peer.peerId] {
                        strongSelf.controllerInteraction?.togglePeer(peer, search)
                    }
                }
            }
        }
        self.addSubnode(self.peerNode)
    }
    
    func setup(account: Account, theme: PresentationTheme, strings: PresentationStrings, peer: RenderedPeer, presence: PeerPresence?, search: Bool, synchronousLoad: Bool) {
        if self.currentState == nil || self.currentState!.0 !== account || self.currentState!.1 != peer {
            let itemTheme = SelectablePeerNodeTheme(textColor: theme.actionSheet.primaryTextColor, secretTextColor: theme.chatList.secretTitleColor, selectedTextColor: theme.actionSheet.controlAccentColor, checkBackgroundColor: theme.actionSheet.opaqueItemBackgroundColor, checkFillColor: theme.actionSheet.controlAccentColor, checkColor: theme.actionSheet.checkContentColor, avatarPlaceholderColor: theme.list.mediaPlaceholderColor)
            
            let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
            var online = false
            if let peer = peer.peer as? TelegramUser, let presence = presence as? TelegramUserPresence, !isServicePeer(peer) && !peer.flags.contains(.isSupport) && peer.id != account.peerId  {
                let relativeStatus = relativeUserPresenceStatus(presence, relativeTo: timestamp)
                if case .online = relativeStatus {
                    online = true
                }
            }
            
            self.peerNode.theme = itemTheme
            self.peerNode.setup(account: account, theme: theme, strings: strings, peer: peer, online: online, synchronousLoad: synchronousLoad)
            self.currentState = (account, peer, search)
            self.setNeedsLayout()
        }
        self.updateSelection(animated: false)
    }
    
    func updateSelection(animated: Bool) {
        var selected = false
        if let controllerInteraction = self.controllerInteraction, let (_, peer, _) = self.currentState {
            selected = controllerInteraction.selectedPeerIds.contains(peer.peerId)
        }
        
        self.peerNode.updateSelection(selected: selected, animated: animated)
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        self.peerNode.frame = bounds
    }
}
