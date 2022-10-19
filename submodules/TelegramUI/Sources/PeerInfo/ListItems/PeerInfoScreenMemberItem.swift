import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ItemListPeerItem
import SwiftSignalKit
import AccountContext
import Postbox
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
    let enclosingPeer: Peer?
    let member: PeerInfoMember
    let badge: String?
    let action: ((PeerInfoScreenMemberItemAction) -> Void)?
    let contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?
    
    init(
        id: AnyHashable,
        context: AccountContext,
        enclosingPeer: Peer?,
        member: PeerInfoMember,
        badge: String? = nil,
        action: ((PeerInfoScreenMemberItemAction) -> Void)?,
        contextAction: ((ASDisplayNode, ContextGesture?) -> Void)? = nil
    ) {
        self.id = id
        self.context = context
        self.enclosingPeer = enclosingPeer
        self.member = member
        self.badge = badge
        self.action = action
        self.contextAction = contextAction
    }
    
    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenMemberItemNode()
    }
}

private final class PeerInfoScreenMemberItemNode: PeerInfoScreenItemNode {
    private let selectionNode: PeerInfoScreenSelectableBackgroundNode
    private let maskNode: ASImageNode
    private let bottomSeparatorNode: ASDisplayNode
    
    private var item: PeerInfoScreenMemberItem?
    private var itemNode: ItemListPeerItemNode?
    
    override init() {
        var bringToFrontForHighlightImpl: (() -> Void)?
        self.selectionNode = PeerInfoScreenSelectableBackgroundNode(bringToFrontForHighlight: { bringToFrontForHighlightImpl?() })
        self.selectionNode.isUserInteractionEnabled = false
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
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
        recognizer.tapActionAtPoint = { point in
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
            if let (gesture, _) = recognizer.lastRecognizedGestureAndLocation {
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
    
    override func update(width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenMemberItem else {
            return 10.0
        }
        
        self.item = item
        
        self.selectionNode.pressed = item.action.flatMap { action in
            return {
                action(.open)
            }
        }
        
        let sideInset: CGFloat = 16.0 + safeInsets.left
        
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
        if actions.contains(.logout) {
            options.append(ItemListPeerItemRevealOption(type: .destructive, title: presentationData.strings.Settings_Context_Logout, action: {
                item.action?(.remove)
            }))
        }
        
        let itemLabel: ItemListPeerItemLabel
        if let label = label {
            itemLabel = .text(label, .standard)
        } else if let badge = item.badge {
            itemLabel = .badge(badge)
        } else {
            itemLabel = .none
        }
        
        let itemHeight: ItemListPeerItemHeight
        let itemText: ItemListPeerItemText
        var synchronousLoads = false
        if case .account = item.member {
            itemHeight = .generic
            itemText = .none
            synchronousLoads = true
        } else {
            itemHeight = .peerList
            itemText = .presence
        }
        
        let peerItem = ItemListPeerItem(presentationData: ItemListPresentationData(presentationData), dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, context: item.context, peer: EnginePeer(item.member.peer), height: itemHeight, presence: item.member.presence.flatMap(EnginePeer.Presence.init), text: itemText, label: itemLabel, editing: ItemListPeerItemEditing(editable: !options.isEmpty, editing: false, revealed: nil), revealOptions: ItemListPeerItemRevealOptions(options: options), switchValue: nil, enabled: true, selectable: false, sectionId: 0, action: nil, setPeerIdWithRevealedOptions: { lhs, rhs in
            
        }, removePeer: { _ in
            
        }, contextAction: item.contextAction, hasTopStripe: false, hasTopGroupInset: false, noInsets: true, noCorners: true, displayDecorations: false)
        
        let params = ListViewItemLayoutParams(width: width, leftInset: safeInsets.left, rightInset: safeInsets.right, availableHeight: 1000.0)
        
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
            peerItem.nodeConfiguredForParams(async: { $0() }, params: params, synchronousLoads: synchronousLoads, previousItem: nil, nextItem: nil, completion: { node, apply in
                itemNodeValue = node
                apply().1(ListViewItemApply(isOnScreen: true))
            })
            itemNode = itemNodeValue as! ItemListPeerItemNode
            self.itemNode = itemNode
            self.addSubnode(itemNode)
        }
        
        itemNode.visibility = .visible(1.0, .infinite)
        
        let height = itemNode.contentSize.height
        
        transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(), size: itemNode.bounds.size))
        
        
        let hasCorners = hasCorners && (topItem == nil || bottomItem == nil)
        let hasTopCorners = hasCorners && topItem == nil
        let hasBottomCorners = hasCorners && bottomItem == nil
        
        self.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
        self.maskNode.frame = CGRect(origin: CGPoint(x: safeInsets.left, y: 0.0), size: CGSize(width: width - safeInsets.left - safeInsets.right, height: height))
        self.bottomSeparatorNode.isHidden = hasBottomCorners
        
        if self.maskNode.supernode == nil {
            self.addSubnode(self.maskNode)
        }
        
        let highlightNodeOffset: CGFloat = topItem == nil ? 0.0 : UIScreenPixel
        self.selectionNode.update(size: CGSize(width: width, height: height + highlightNodeOffset), theme: presentationData.theme, transition: transition)
        transition.updateFrame(node: self.selectionNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -highlightNodeOffset), size: CGSize(width: width, height: height + highlightNodeOffset)))
        
        var separatorInset: CGFloat = sideInset
        if bottomItem != nil {
            separatorInset += 49.0
        }
        
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: separatorInset, y: height - UIScreenPixel), size: CGSize(width: width - sideInset, height: UIScreenPixel)))
        transition.updateAlpha(node: self.bottomSeparatorNode, alpha: bottomItem == nil ? 0.0 : 1.0)
        
        return height
    }
    
    private func updateTouchesAtPoint(_ point: CGPoint?) {
        guard let item = self.item else {
            return
        }
        var highlight = point != nil
        if case .account = item.member {
        } else if item.context.account.peerId == item.member.id {
            highlight = false
        }
        if highlight {
            self.selectionNode.updateIsHighlighted(true)
        } else {
            self.selectionNode.updateIsHighlighted(false)
        }
    }
}
