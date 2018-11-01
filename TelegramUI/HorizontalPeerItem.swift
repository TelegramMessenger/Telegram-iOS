import Foundation
import Display
import Postbox
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit

enum HorizontalPeerItemMode {
    case list
    case actionSheet
}
private let badgeFont = Font.regular(14.0)


final class HorizontalPeerItem: ListViewItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let mode: HorizontalPeerItemMode
    let account: Account
    let peer: Peer
    let action: (Peer) -> Void
    let longTapAction: (Peer) -> Void
    let isPeerSelected: (PeerId) -> Bool
    let customWidth: CGFloat?
    let unreadBadge: UnreadSearchBadge?
    init(theme: PresentationTheme, strings: PresentationStrings, mode: HorizontalPeerItemMode, account: Account, peer: Peer, unreadBadge: UnreadSearchBadge?, action: @escaping (Peer) -> Void, longTapAction: @escaping (Peer) -> Void, isPeerSelected: @escaping (PeerId) -> Bool, customWidth: CGFloat?) {
        self.theme = theme
        self.strings = strings
        self.mode = mode
        self.account = account
        self.peer = peer
        self.action = action
        self.longTapAction = longTapAction
        self.isPeerSelected = isPeerSelected
        self.customWidth = customWidth
        self.unreadBadge = unreadBadge
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        async {
            let node = HorizontalPeerItemNode()
            
            let (nodeLayout, apply) = node.asyncLayout()(self, params)
            
            node.insets = nodeLayout.insets
            node.contentSize = nodeLayout.contentSize
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, {
                        apply(false)
                    })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        Queue.mainQueue().async {
            assert(node() is HorizontalPeerItemNode)
            if let nodeValue = node() as? HorizontalPeerItemNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params)
                    Queue.mainQueue().async {
                        completion(nodeLayout, {
                            apply(animation.isAnimated)
                        })
                    }
                }
            }
        }
    }
}

final class HorizontalPeerItemNode: ListViewItemNode {
    private(set) var peerNode: SelectablePeerNode
    let badgeBackgroundNode: ASImageNode
    let badgeTextNode: TextNode
    private(set) var item: HorizontalPeerItem?
    
    init() {
        self.peerNode = SelectablePeerNode()
        self.badgeBackgroundNode = ASImageNode()
        self.badgeBackgroundNode.isLayerBacked = true
        self.badgeBackgroundNode.displaysAsynchronously = false
        self.badgeBackgroundNode.displayWithoutProcessing = true
        
        
        self.badgeTextNode = TextNode()
        self.badgeTextNode.isLayerBacked = true
        self.badgeTextNode.displaysAsynchronously = true
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.peerNode)
        addSubnode(badgeBackgroundNode)
        addSubnode(badgeTextNode)
        self.peerNode.toggleSelection = { [weak self] in
            if let item = self?.item {
                item.action(item.peer)
            }
        }
        self.peerNode.longTapAction = { [weak self] in
            if let item = self?.item {
                item.longTapAction(item.peer)
            }
        }
        
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.layer.sublayerTransform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
    }
    
    func asyncLayout() -> (HorizontalPeerItem, ListViewItemLayoutParams) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let badgeTextLayout = TextNode.asyncLayout(self.badgeTextNode)

        return { [weak self] item, params in
            let itemLayout = ListViewItemNodeLayout(contentSize: CGSize(width: 92.0, height: item.customWidth ?? 80.0), insets: UIEdgeInsets())
            
            let itemTheme: SelectablePeerNodeTheme
            switch item.mode {
                case .list:
                    itemTheme = SelectablePeerNodeTheme(textColor: item.theme.list.itemPrimaryTextColor, secretTextColor: .green, selectedTextColor: item.theme.list.itemAccentColor, checkBackgroundColor: item.theme.list.plainBackgroundColor, checkFillColor: item.theme.list.itemAccentColor, checkColor: item.theme.list.plainBackgroundColor)
                case .actionSheet:
                    itemTheme = SelectablePeerNodeTheme(textColor: item.theme.actionSheet.primaryTextColor, secretTextColor: .green, selectedTextColor: item.theme.actionSheet.controlAccentColor, checkBackgroundColor: item.theme.actionSheet.opaqueItemBackgroundColor, checkFillColor: item.theme.actionSheet.controlAccentColor, checkColor: item.theme.actionSheet.opaqueItemBackgroundColor)
            }
            let currentBadgeBackgroundImage: UIImage?
            let badgeAttributedString: NSAttributedString
            if let unreadBadge = item.unreadBadge {
                let badgeTextColor: UIColor
                let unreadCount: Int32
                let isMuted: Bool
                switch unreadBadge {
                case let .muted(_count):
                    unreadCount = _count
                    isMuted = true
                case let .unmuted(_count):
                    unreadCount = _count
                    isMuted = false
                }
                if isMuted {
                    currentBadgeBackgroundImage = PresentationResourcesChatList.badgeBackgroundInactive(item.theme)
                    badgeTextColor = item.theme.chatList.unreadBadgeInactiveTextColor
                } else {
                    currentBadgeBackgroundImage = PresentationResourcesChatList.badgeBackgroundActive(item.theme)
                    badgeTextColor = item.theme.chatList.unreadBadgeActiveTextColor
                }
                badgeAttributedString = NSAttributedString(string: unreadCount > 0 ? "\(unreadCount)" : " ", font: badgeFont, textColor: badgeTextColor)
                
               
            } else {
                currentBadgeBackgroundImage = nil
                badgeAttributedString = NSAttributedString()
            }
            
            let (badgeLayout, badgeApply) = badgeTextLayout(TextNodeLayoutArguments(attributedString: badgeAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 50.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var badgeSize: CGFloat = 0.0
            if let currentBadgeBackgroundImage = currentBadgeBackgroundImage {
                badgeSize += max(currentBadgeBackgroundImage.size.width, badgeLayout.size.width + 10.0) + 5.0
            }

            return (itemLayout, { animated in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.peerNode.theme = itemTheme
                    strongSelf.peerNode.setup(account: item.account, strings: item.strings, peer: RenderedPeer(peer: item.peer), numberOfLines: 1)
                    strongSelf.peerNode.frame = CGRect(origin: CGPoint(), size: itemLayout.size)
                    strongSelf.peerNode.updateSelection(selected: item.isPeerSelected(item.peer.id), animated: false)
                    
                    let badgeBackgroundWidth: CGFloat
                    if let currentBadgeBackgroundImage = currentBadgeBackgroundImage {
                        strongSelf.badgeBackgroundNode.image = currentBadgeBackgroundImage
                        strongSelf.badgeBackgroundNode.isHidden = false
                        
                        badgeBackgroundWidth = max(badgeLayout.size.width + 10.0, currentBadgeBackgroundImage.size.width)
                        let badgeBackgroundFrame = CGRect(x: itemLayout.size.width - badgeBackgroundWidth * 2, y: 0, width: badgeBackgroundWidth, height: currentBadgeBackgroundImage.size.height)
                        let badgeTextFrame = CGRect(origin: CGPoint(x: badgeBackgroundFrame.midX - badgeLayout.size.width / 2.0, y: badgeBackgroundFrame.minY + 2.0), size: badgeLayout.size)
                        
                        strongSelf.badgeTextNode.frame = badgeTextFrame
                        strongSelf.badgeBackgroundNode.frame = badgeBackgroundFrame
                    } else {
                        badgeBackgroundWidth = 0.0
                        strongSelf.badgeBackgroundNode.image = nil
                        strongSelf.badgeBackgroundNode.isHidden = true
                    }
                    
                    let _ = badgeApply()
                    
                }
            })
        }
    }
    
    func updateSelection(animated: Bool) {
        if let item = self.item {
            self.peerNode.updateSelection(selected: item.isPeerSelected(item.peer.id), animated: animated)
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        super.animateInsertion(currentTimestamp, duration: duration, short: short)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        super.animateRemoved(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        super.animateAdded(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
}

