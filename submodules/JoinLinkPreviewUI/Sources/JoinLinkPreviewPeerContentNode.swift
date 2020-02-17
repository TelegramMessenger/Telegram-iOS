import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import AvatarNode
import AccountContext
import SelectablePeerNode
import ShareController

private let avatarFont = avatarPlaceholderFont(size: 26.0)

private final class MoreNode: ASDisplayNode {
    private let avatarNode = AvatarNode(font: Font.regular(24.0))
    
    init(count: Int) {
        super.init()
        
        self.addSubnode(self.avatarNode)
        self.avatarNode.setCustomLetters(["+\(count)"])
    }
    
    func updateLayout(size: CGSize) {
        self.avatarNode.frame = CGRect(origin: CGPoint(x: floor((size.width - 60.0) / 2.0), y: 4.0), size: CGSize(width: 60.0, height: 60.0))
    }
}

final class JoinLinkPreviewPeerContentNode: ASDisplayNode, ShareContentContainerNode {
    private var contentOffsetUpdated: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
    
    private let avatarNode: AvatarNode
    private let titleNode: ASTextNode
    private let countNode: ASTextNode
    private let peersScrollNode: ASScrollNode
    
    private let peerNodes: [SelectablePeerNode]
    private let moreNode: MoreNode?
    
    init(context: AccountContext, image: TelegramMediaImageRepresentation?, title: String, memberCount: Int32, members: [Peer], isGroup: Bool, theme: PresentationTheme, strings: PresentationStrings) {
        self.avatarNode = AvatarNode(font: avatarFont)
        self.titleNode = ASTextNode()
        self.countNode = ASTextNode()
        self.peersScrollNode = ASScrollNode()
        self.peersScrollNode.view.showsHorizontalScrollIndicator = false
        
        let itemTheme = SelectablePeerNodeTheme(textColor: theme.actionSheet.primaryTextColor, secretTextColor: .green, selectedTextColor: theme.actionSheet.controlAccentColor, checkBackgroundColor: theme.actionSheet.opaqueItemBackgroundColor, checkFillColor: theme.actionSheet.controlAccentColor, checkColor: theme.actionSheet.opaqueItemBackgroundColor, avatarPlaceholderColor: theme.list.mediaPlaceholderColor)
        
        self.peerNodes = members.map { peer in
            let node = SelectablePeerNode()
            node.setup(context: context, theme: theme, strings: strings, peer: RenderedPeer(peer: peer), synchronousLoad: false)
            node.theme = itemTheme
            return node
        }
        
        if members.count < Int(memberCount) {
            self.moreNode = MoreNode(count: Int(memberCount) - members.count)
        } else {
            self.moreNode = nil
        }
        
        super.init()
        
        let peer = TelegramGroup(id: PeerId(namespace: 0, id: 0), title: title, photo: image.flatMap { [$0] } ?? [], participantCount: Int(memberCount), role: .member, membership: .Left, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0)
        
        self.addSubnode(self.avatarNode)
        self.avatarNode.setPeer(context: context, theme: theme, peer: peer, emptyColor: theme.list.mediaPlaceholderColor)
        
        self.addSubnode(self.titleNode)
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(16.0), textColor: theme.actionSheet.primaryTextColor)
        
        self.addSubnode(self.countNode)
        let membersString: String
        if isGroup {
            if !members.isEmpty {
                membersString = strings.Invitation_Members(memberCount)
            } else {
                membersString = strings.Conversation_StatusMembers(memberCount)
            }
        } else {
            membersString = strings.Conversation_StatusSubscribers(memberCount)
        }

        self.countNode.attributedText = NSAttributedString(string: membersString, font: Font.regular(16.0), textColor: theme.actionSheet.secondaryTextColor)
        
        if !self.peerNodes.isEmpty {
            for peerNode in peerNodes {
                self.peersScrollNode.addSubnode(peerNode)
            }
            self.addSubnode(self.peersScrollNode)
        }
        self.moreNode.flatMap(self.peersScrollNode.addSubnode)
    }
    
    func activate() {
    }
    
    func deactivate() {
    }
    
    func setEnsurePeerVisibleOnLayout(_ peerId: PeerId?) {
    }
    
    func setContentOffsetUpdated(_ f: ((CGFloat, ContainedViewLayoutTransition) -> Void)?) {
        self.contentOffsetUpdated = f
    }
    
    func updateLayout(size: CGSize, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let nodeHeight: CGFloat = self.peerNodes.isEmpty ? 224.0 : 324.0
        
        let verticalOrigin = size.height - nodeHeight
        
        let avatarSize: CGFloat = 75.0
        
        transition.updateFrame(node: self.avatarNode, frame: CGRect(origin: CGPoint(x: floor((size.width - avatarSize) / 2.0), y: verticalOrigin + 22.0), size: CGSize(width: avatarSize, height: avatarSize)))
        
        let titleSize = self.titleNode.measure(size)
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: verticalOrigin + 22.0 + avatarSize + 15.0), size: titleSize))
        
        let countSize = self.countNode.measure(size)
        transition.updateFrame(node: self.countNode, frame: CGRect(origin: CGPoint(x: floor((size.width - countSize.width) / 2.0), y: verticalOrigin + 22.0 + avatarSize + 15.0 + titleSize.height + 1.0), size: countSize))
        
        let peerSize = CGSize(width: 85.0, height: 95.0)
        let peerInset: CGFloat = 10.0
        
        var peerOffset = peerInset
        for node in self.peerNodes {
            node.frame = CGRect(origin: CGPoint(x: peerOffset, y: 0.0), size: peerSize)
            peerOffset += peerSize.width
        }
        
        if let moreNode = self.moreNode {
            moreNode.updateLayout(size: peerSize)
            moreNode.frame = CGRect(origin: CGPoint(x: peerOffset, y: 0.0), size: peerSize)
            peerOffset += peerSize.width
        }
        
        self.peersScrollNode.view.contentSize = CGSize(width: CGFloat(self.peerNodes.count) * peerSize.width + (self.moreNode != nil ? peerSize.width : 0.0) + peerInset * 2.0, height: peerSize.height)
        transition.updateFrame(node: self.peersScrollNode, frame: CGRect(origin: CGPoint(x: 0.0, y: verticalOrigin + 168.0), size: CGSize(width: size.width, height: peerSize.height)))
        
        self.contentOffsetUpdated?(-size.height + nodeHeight - 64.0, transition)
    }
    
    func updateSelectedPeers() {
    }
}
