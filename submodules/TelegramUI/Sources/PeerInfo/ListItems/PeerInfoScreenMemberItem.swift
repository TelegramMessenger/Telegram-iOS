import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ItemListPeerItem
import SwiftSignalKit
import AccountContext
import Postbox
import SyncCore
import TelegramCore
import ItemListUI

enum PeerInfoScreenMemberItemAction {
    case open
    case promote
    case restrict
    case remove
}

final class PeerInfoScreenMemberItem: PeerInfoScreenItem {
    let id: AnyHashable
    let context: AccountContext
    let enclosingPeer: Peer
    let member: PeerInfoMember
    let action: ((PeerInfoScreenMemberItemAction) -> Void)?
    
    init(
        id: AnyHashable,
        context: AccountContext,
        enclosingPeer: Peer,
        member: PeerInfoMember,
        action: ((PeerInfoScreenMemberItemAction) -> Void)?
    ) {
        self.id = id
        self.context = context
        self.enclosingPeer = enclosingPeer
        self.member = member
        self.action = action
    }
    
    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenMemberItemNode()
    }
}

private final class PeerInfoScreenMemberItemNode: PeerInfoScreenItemNode {
    private let selectionNode: PeerInfoScreenSelectableBackgroundNode
    private let bottomSeparatorNode: ASDisplayNode
    
    private var item: PeerInfoScreenMemberItem?
    private var itemNode: ItemListPeerItemNode?
    
    override init() {
        var bringToFrontForHighlightImpl: (() -> Void)?
        self.selectionNode = PeerInfoScreenSelectableBackgroundNode(bringToFrontForHighlight: { bringToFrontForHighlightImpl?() })
        self.selectionNode.isUserInteractionEnabled = false
        
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true
        
        super.init()
        
        bringToFrontForHighlightImpl = { [weak self] in
            self?.bringToFrontForHighlight?()
        }
        
        self.addSubnode(self.bottomSeparatorNode)
        self.addSubnode(self.selectionNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { [weak self] point in
            return .keepWithSingleTap
        }
        recognizer.highlight = { [weak self] point in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateTouchesAtPoint(point)
        }
        self.view.addGestureRecognizer(recognizer)
    }
    
    @objc private func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                switch gesture {
                case .tap:
                    if let item = self.item {
                        item.action?(.open)
                    }
                default:
                    break
                }
            }
        default:
            break
        }
    }
    
    override func update(width: CGFloat, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenMemberItem else {
            return 10.0
        }
        
        self.item = item
        
        self.selectionNode.pressed = item.action.flatMap { action in
            return {
                action(.open)
            }
        }
        
        let sideInset: CGFloat = 16.0
        
        self.bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        let label: String?
        if let rank = item.member.rank {
            label = rank
        } else {
            switch item.member.role {
            case .creator:
                label = presentationData.strings.GroupInfo_LabelOwner
            case .admin:
                label = presentationData.strings.GroupInfo_LabelAdmin
            case .member:
                label = nil
            }
        }
        
        let actions = availableActionsForMemberOfPeer(accountPeerId: item.context.account.peerId, peer: item.enclosingPeer, member: item.member)
        
        var options: [ItemListPeerItemRevealOption] = []
        if actions.contains(.promote) && item.enclosingPeer is TelegramChannel {
            options.append(ItemListPeerItemRevealOption(type: .neutral, title: presentationData.strings.GroupInfo_ActionPromote, action: {
                item.action?(.promote)
            }))
        }
        if actions.contains(.restrict) {
            if item.enclosingPeer is TelegramChannel {
                options.append(ItemListPeerItemRevealOption(type: .warning, title: presentationData.strings.GroupInfo_ActionRestrict, action: {
                    item.action?(.restrict)
                }))
            }
            options.append(ItemListPeerItemRevealOption(type: .destructive, title: presentationData.strings.Common_Delete, action: {
                item.action?(.remove)
            }))
        }
        
        let peerItem = ItemListPeerItem(presentationData: ItemListPresentationData(presentationData), dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, context: item.context, peer: item.member.peer, height: .peerList, presence: item.member.presence, text: .presence, label: label == nil ? .none : .text(label!, .standard), editing: ItemListPeerItemEditing(editable: !options.isEmpty, editing: false, revealed: nil), revealOptions: ItemListPeerItemRevealOptions(options: options), switchValue: nil, enabled: true, selectable: false, sectionId: 0, action: nil, setPeerIdWithRevealedOptions: { lhs, rhs in
            
        }, removePeer: { _ in
            
        }, contextAction: nil, hasTopStripe: false, hasTopGroupInset: false, noInsets: true, displayDecorations: false)
        
        let params = ListViewItemLayoutParams(width: width, leftInset: 0.0, rightInset: 0.0, availableHeight: 1000.0)
        
        let itemNode: ItemListPeerItemNode
        if let current = self.itemNode {
            itemNode = current
            peerItem.updateNode(async: { $0() }, node: {
                return itemNode
            }, params: params, previousItem: nil, nextItem: nil, animation: .None, completion: { (layout, apply) in
                let nodeFrame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: layout.size.height))
                
                itemNode.contentSize = layout.contentSize
                itemNode.insets = layout.insets
                itemNode.frame = nodeFrame
                
                apply(ListViewItemApply(isOnScreen: true))
            })
        } else {
            var itemNodeValue: ListViewItemNode?
            peerItem.nodeConfiguredForParams(async: { $0() }, params: params, synchronousLoads: false, previousItem: nil, nextItem: nil, completion: { node, apply in
                itemNodeValue = node
                apply().1(ListViewItemApply(isOnScreen: true))
            })
            itemNode = itemNodeValue as! ItemListPeerItemNode
            self.itemNode = itemNode
            self.addSubnode(itemNode)
        }
        
        let height = itemNode.contentSize.height
        
        transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(), size: itemNode.bounds.size))
        
        let highlightNodeOffset: CGFloat = topItem == nil ? 0.0 : UIScreenPixel
        self.selectionNode.update(size: CGSize(width: width, height: height + highlightNodeOffset), theme: presentationData.theme, transition: transition)
        transition.updateFrame(node: self.selectionNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -highlightNodeOffset), size: CGSize(width: width, height: height + highlightNodeOffset)))
        
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: sideInset, y: height - UIScreenPixel), size: CGSize(width: width - sideInset, height: UIScreenPixel)))
        transition.updateAlpha(node: self.bottomSeparatorNode, alpha: bottomItem == nil ? 0.0 : 1.0)
        
        return height
    }
    
    private func updateTouchesAtPoint(_ point: CGPoint?) {
        guard let item = self.item else {
            return
        }
        if point != nil && item.context.account.peerId != item.member.id {
            self.selectionNode.updateIsHighlighted(true)
        } else {
            self.selectionNode.updateIsHighlighted(false)
        }
    }
}
