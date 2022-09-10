import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramStringFormatting
import PeerOnlineMarkerNode
import SelectablePeerNode
import ContextUI
import AccountContext

public enum HorizontalPeerItemMode {
    case list(compact: Bool)
    case actionSheet
}

private let badgeFont = Font.regular(14.0)

public final class HorizontalPeerItem: ListViewItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let mode: HorizontalPeerItemMode
    let context: AccountContext
    public let peer: EnginePeer
    let action: (EnginePeer) -> Void
    let contextAction: ((EnginePeer, ASDisplayNode, ContextGesture?, CGPoint?) -> Void)?
    let isPeerSelected: (EnginePeer.Id) -> Bool
    let customWidth: CGFloat?
    let presence: EnginePeer.Presence?
    let unreadBadge: (Int32, Bool)?
    
    public init(theme: PresentationTheme, strings: PresentationStrings, mode: HorizontalPeerItemMode, context: AccountContext, peer: EnginePeer, presence: EnginePeer.Presence?, unreadBadge: (Int32, Bool)?, action: @escaping (EnginePeer) -> Void, contextAction: ((EnginePeer, ASDisplayNode, ContextGesture?, CGPoint?) -> Void)?, isPeerSelected: @escaping (EnginePeer.Id) -> Bool, customWidth: CGFloat?) {
        self.theme = theme
        self.strings = strings
        self.mode = mode
        self.context = context
        self.peer = peer
        self.action = action
        self.contextAction = contextAction
        self.isPeerSelected = isPeerSelected
        self.customWidth = customWidth
        self.presence = presence
        self.unreadBadge = unreadBadge
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = HorizontalPeerItemNode()
            let (nodeLayout, apply) = node.asyncLayout()(self, params)
            node.insets = nodeLayout.insets
            node.contentSize = nodeLayout.contentSize
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in
                        apply(false, synchronousLoads)
                    })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            assert(node() is HorizontalPeerItemNode)
            if let nodeValue = node() as? HorizontalPeerItemNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params)
                    Queue.mainQueue().async {
                        completion(nodeLayout, { _ in
                            apply(animation.isAnimated, false)
                        })
                    }
                }
            }
        }
    }
}

public final class HorizontalPeerItemNode: ListViewItemNode {
    private(set) var peerNode: SelectablePeerNode
    let badgeBackgroundNode: ASImageNode
    let badgeTextNode: TextNode
    let onlineNode: PeerOnlineMarkerNode
    public private(set) var item: HorizontalPeerItem?
    
    public init() {
        self.peerNode = SelectablePeerNode()
        self.badgeBackgroundNode = ASImageNode()
        self.badgeBackgroundNode.isLayerBacked = true
        self.badgeBackgroundNode.displaysAsynchronously = false
        self.badgeBackgroundNode.displayWithoutProcessing = true
        
        self.badgeTextNode = TextNode()
        self.badgeTextNode.isUserInteractionEnabled = false
        self.badgeTextNode.displaysAsynchronously = true
        
        self.onlineNode = PeerOnlineMarkerNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.peerNode)
        self.addSubnode(self.badgeBackgroundNode)
        self.addSubnode(self.badgeTextNode)
        self.addSubnode(self.onlineNode)
        self.peerNode.toggleSelection = { [weak self] in
            if let item = self?.item {
                item.action(item.peer)
            }
        }
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.layer.sublayerTransform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
    }
    
    public func asyncLayout() -> (HorizontalPeerItem, ListViewItemLayoutParams) -> (ListViewItemNodeLayout, (Bool, Bool) -> Void) {
        let badgeTextLayout = TextNode.asyncLayout(self.badgeTextNode)
        let onlineLayout = self.onlineNode.asyncLayout()
        
        let currentItem = self.item

        return { [weak self] item, params in
            let itemLayout = ListViewItemNodeLayout(contentSize: CGSize(width: 92.0, height: item.customWidth ?? 80.0), insets: UIEdgeInsets())
            
            let itemTheme: SelectablePeerNodeTheme
            switch item.mode {
                case .list:
                    itemTheme = SelectablePeerNodeTheme(textColor: item.theme.list.itemPrimaryTextColor, secretTextColor: item.theme.chatList.secretTitleColor, selectedTextColor: item.theme.list.itemAccentColor, checkBackgroundColor: item.theme.list.plainBackgroundColor, checkFillColor: item.theme.list.itemAccentColor, checkColor: item.theme.list.plainBackgroundColor, avatarPlaceholderColor: item.theme.list.mediaPlaceholderColor)
                case .actionSheet:
                    itemTheme = SelectablePeerNodeTheme(textColor: item.theme.actionSheet.primaryTextColor, secretTextColor: item.theme.chatList.secretTitleColor, selectedTextColor: item.theme.actionSheet.controlAccentColor, checkBackgroundColor: item.theme.actionSheet.opaqueItemBackgroundColor, checkFillColor: item.theme.actionSheet.controlAccentColor, checkColor: item.theme.actionSheet.opaqueItemBackgroundColor, avatarPlaceholderColor: item.theme.list.mediaPlaceholderColor)
            }
            let currentBadgeBackgroundImage: UIImage?
            let badgeAttributedString: NSAttributedString
            if let unreadBadge = item.unreadBadge {
                let badgeTextColor: UIColor
                let (unreadCount, isMuted) = unreadBadge
                if isMuted {
                    currentBadgeBackgroundImage = PresentationResourcesChatList.badgeBackgroundInactive(item.theme, diameter: 20.0)
                    badgeTextColor = item.theme.chatList.unreadBadgeInactiveTextColor
                } else {
                    currentBadgeBackgroundImage = PresentationResourcesChatList.badgeBackgroundActive(item.theme, diameter: 20.0)
                    badgeTextColor = item.theme.chatList.unreadBadgeActiveTextColor
                }
                badgeAttributedString = NSAttributedString(string: unreadCount > 0 ? "\(unreadCount)" : " ", font: badgeFont, textColor: badgeTextColor)
                
               
            } else {
                currentBadgeBackgroundImage = nil
                badgeAttributedString = NSAttributedString()
            }
            
            var online = false
            let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
            if case let .user(peer) = item.peer, let presence = item.presence, !item.peer.isService, !peer.flags.contains(.isSupport) {
                let relativeStatus = relativeUserPresenceStatus(presence, relativeTo: Int32(timestamp))
                if case .online = relativeStatus {
                    online = true
                }
            }
            
            let (badgeLayout, badgeApply) = badgeTextLayout(TextNodeLayoutArguments(attributedString: badgeAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 50.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var badgeSize: CGFloat = 0.0
            if let currentBadgeBackgroundImage = currentBadgeBackgroundImage {
                badgeSize += max(currentBadgeBackgroundImage.size.width, badgeLayout.size.width + 10.0) + 5.0
            }
            
            let (onlineLayout, onlineApply) = onlineLayout(online, false)
            var animateContent = false
            if let currentItem = currentItem, currentItem.peer.id == item.peer.id {
                animateContent = true
            }
            
            return (itemLayout, { animated, synchronousLoads in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.peerNode.theme = itemTheme
                    if case let .list(compact) = item.mode {
                        strongSelf.peerNode.compact = compact
                    } else {
                        strongSelf.peerNode.compact = false
                    }
                    strongSelf.peerNode.setup(context: item.context, theme: item.theme, strings: item.strings, peer: EngineRenderedPeer(peer: item.peer), numberOfLines: 1, synchronousLoad: synchronousLoads)
                    strongSelf.peerNode.frame = CGRect(origin: CGPoint(), size: itemLayout.size)
                    strongSelf.peerNode.updateSelection(selected: item.isPeerSelected(item.peer.id), animated: false)
                    
                    if let contextAction = item.contextAction {
                        strongSelf.peerNode.contextAction = { [weak item] node, gesture, location in
                            if let item = item {
                                contextAction(item.peer, node, gesture, location)
                            }
                        }
                    } else {
                        strongSelf.peerNode.contextAction = nil
                    }
                    
                    let badgeBackgroundWidth: CGFloat
                    if let currentBadgeBackgroundImage = currentBadgeBackgroundImage {
                        strongSelf.badgeBackgroundNode.image = currentBadgeBackgroundImage
                        strongSelf.badgeBackgroundNode.isHidden = false
                        
                        badgeBackgroundWidth = max(badgeLayout.size.width + 10.0, currentBadgeBackgroundImage.size.width)
                        let badgeBackgroundFrame = CGRect(x: itemLayout.size.width - floorToScreenPixels(badgeBackgroundWidth * 1.8), y: 2.0, width: badgeBackgroundWidth, height: currentBadgeBackgroundImage.size.height)
                        let badgeTextFrame = CGRect(origin: CGPoint(x: badgeBackgroundFrame.midX - badgeLayout.size.width / 2.0, y: badgeBackgroundFrame.minY + 2.0), size: badgeLayout.size)
                        
                        strongSelf.badgeTextNode.frame = badgeTextFrame
                        strongSelf.badgeBackgroundNode.frame = badgeBackgroundFrame
                    } else {
                        badgeBackgroundWidth = 0.0
                        strongSelf.badgeBackgroundNode.image = nil
                        strongSelf.badgeBackgroundNode.isHidden = true
                    }
                    
                    var verticalOffset: CGFloat = 0.0
                    let state: RecentStatusOnlineIconState
                    if case .actionSheet = item.mode {
                        state = .panel
                        verticalOffset -= 9.0
                    } else {
                        state = .regular
                    }
                    
                    strongSelf.onlineNode.setImage(PresentationResourcesChatList.recentStatusOnlineIcon(item.theme, state: state), color: nil, transition: .immediate)
                    strongSelf.onlineNode.frame = CGRect(x: itemLayout.size.width - onlineLayout.width - 18.0, y: itemLayout.size.height - onlineLayout.height - 18.0 + verticalOffset, width: onlineLayout.width, height: onlineLayout.height)
                    
                    let _ = badgeApply()
                    let _ = onlineApply(animateContent)
                }
            })
        }
    }
    
    public func updateSelection(animated: Bool) {
        if let item = self.item {
            self.peerNode.updateSelection(selected: item.isPeerSelected(item.peer.id), animated: animated)
        }
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        super.animateInsertion(currentTimestamp, duration: duration, short: short)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        super.animateRemoved(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        super.animateAdded(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
}

