import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ItemListPeerItem
import SwiftSignalKit
import AccountContext
import TelegramCore
import ItemListUI

private final class PeerInfoMemberAccessibilityAction: UIAccessibilityCustomAction {
    let perform: () -> Void

    init(name: String, target: Any?, selector: Selector, perform: @escaping () -> Void) {
        self.perform = perform
        super.init(name: name, target: target, selector: selector)
    }
}

enum PeerInfoScreenMemberItemAction {
    case open
    case promote
    case restrict
    case remove
}

final class PeerInfoScreenMemberItem: PeerInfoScreenItem {
    let id: AnyHashable
    let context: ItemListPeerItem.Context
    let enclosingPeer: EnginePeer?
    let member: PeerInfoMember
    let badge: String?
    let isAccount: Bool
    let action: ((PeerInfoScreenMemberItemAction) -> Void)?
    let contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?
    let openStories: ((UIView) -> Void)?
    
    init(
        id: AnyHashable,
        context: ItemListPeerItem.Context,
        enclosingPeer: EnginePeer?,
        member: PeerInfoMember,
        badge: String? = nil,
        isAccount: Bool,
        action: ((PeerInfoScreenMemberItemAction) -> Void)?,
        contextAction: ((ASDisplayNode, ContextGesture?) -> Void)? = nil,
        openStories: ((UIView) -> Void)? = nil
    ) {
        self.id = id
        self.context = context
        self.enclosingPeer = enclosingPeer
        self.member = member
        self.badge = badge
        self.isAccount = isAccount
        self.action = action
        self.contextAction = contextAction
        self.openStories = openStories
    }
    
    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenMemberItemNode()
    }
}

private final class PeerInfoScreenMemberItemNode: PeerInfoScreenItemNode {
    private let selectionNode: PeerInfoScreenSelectableBackgroundNode
    private let maskNode: ASImageNode
    private let bottomSeparatorNode: ASDisplayNode
    private let activateArea: AccessibilityAreaNode
    
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

        self.activateArea = AccessibilityAreaNode()
        
        super.init()
        
        bringToFrontForHighlightImpl = { [weak self] in
            self?.bringToFrontForHighlight?()
        }
        
        self.addSubnode(self.bottomSeparatorNode)
        self.addSubnode(self.selectionNode)
        self.addSubnode(self.activateArea)
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
    
    override func update(context: AccountContext, width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
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
        
        var labelColor = presentationData.theme.list.itemSecondaryTextColor
        var labelBackground = false
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
                var canEditRank = false
                if item.member.id == item.context.accountPeerId {
                    if case let .channel(channel) = item.enclosingPeer, channel.hasPermission(.editRank) {
                        canEditRank = true
                    } else if case let .legacyGroup(group) = item.enclosingPeer, !group.hasBannedPermission(.banEditRank) {
                        canEditRank = true
                    }
                }
                if canEditRank {
                    label = presentationData.strings.GroupInfo_AddRank
                    labelColor = presentationData.theme.list.itemAccentColor
                } else {
                    label = nil
                }
            }
        }
        
        switch item.member.role {
        case .creator:
            labelBackground = true
            labelColor = UIColor(rgb: 0x956ac8)
        case .admin:
            labelBackground = true
            labelColor = UIColor(rgb: 0x49a355)
        default:
            break
        }
        
        let actions = availableActionsForMemberOfPeer(accountPeerId: item.context.accountPeerId, peer: item.enclosingPeer, member: item.member)
        
        var options: [ItemListPeerItemRevealOption] = []
        if actions.contains(.promote), case .channel = item.enclosingPeer {
            options.append(ItemListPeerItemRevealOption(type: .neutral, title: presentationData.strings.GroupInfo_ActionPromote, action: {
                item.action?(.promote)
            }))
        }
        if actions.contains(.restrict) {
            if case .channel = item.enclosingPeer {
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
            itemLabel = .text(label, .standard, labelColor, labelBackground)
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
        
        let peerItem = ItemListPeerItem(presentationData: ItemListPresentationData(presentationData), systemStyle: .glass, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, context: item.context, peer: item.member.peer, height: itemHeight, presence: item.member.presence.flatMap(EnginePeer.Presence.init), text: itemText, label: itemLabel, editing: ItemListPeerItemEditing(editable: !options.isEmpty, editing: false, revealed: nil), revealOptions: ItemListPeerItemRevealOptions(options: options), switchValue: nil, enabled: true, selectable: false, animateFirstAvatarTransition: !item.isAccount, sectionId: 0, action: nil, setPeerIdWithRevealedOptions: { lhs, rhs in
            
        }, removePeer: { _ in
            
        }, contextAction: item.contextAction, hasTopStripe: false, hasTopGroupInset: false, noInsets: true, noCorners: true, displayDecorations: false, storyStats: item.member.storyStats, openStories: { [weak self] sourceView in
            guard let self, let item = self.item else {
                return
            }
            item.openStories?(sourceView)
        })
        
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
        itemNode.isAccessibilityElement = false

        self.activateArea.accessibilityLabel = itemNode.accessibilityLabel
        self.activateArea.accessibilityValue = itemNode.accessibilityValue
        if let action = item.action {
            self.activateArea.accessibilityTraits = [.button]
            self.activateArea.activate = {
                action(.open)
                return true
            }
        } else {
            self.activateArea.accessibilityTraits = [.staticText]
            self.activateArea.activate = nil
        }

        var accessibilityActions: [UIAccessibilityCustomAction] = []
        if let memberAction = item.action, actions.contains(.promote), case .channel = item.enclosingPeer {
            accessibilityActions.append(PeerInfoMemberAccessibilityAction(name: presentationData.strings.GroupInfo_ActionPromote, target: self, selector: #selector(self.performAccessibilityAction(_:)), perform: {
                memberAction(.promote)
            }))
        }
        if let memberAction = item.action, actions.contains(.restrict), case .channel = item.enclosingPeer {
            accessibilityActions.append(PeerInfoMemberAccessibilityAction(name: presentationData.strings.GroupInfo_ActionRestrict, target: self, selector: #selector(self.performAccessibilityAction(_:)), perform: {
                memberAction(.restrict)
            }))
        }
        if let memberAction = item.action, actions.contains(.restrict) {
            accessibilityActions.append(PeerInfoMemberAccessibilityAction(name: presentationData.strings.Common_Delete, target: self, selector: #selector(self.performAccessibilityAction(_:)), perform: {
                memberAction(.remove)
            }))
        } else if let memberAction = item.action, actions.contains(.logout) {
            accessibilityActions.append(PeerInfoMemberAccessibilityAction(name: presentationData.strings.Settings_Context_Logout, target: self, selector: #selector(self.performAccessibilityAction(_:)), perform: {
                memberAction(.remove)
            }))
        }
        self.activateArea.accessibilityCustomActions = accessibilityActions.isEmpty ? nil : accessibilityActions
        
        let height = itemNode.contentSize.height
        
        transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(), size: itemNode.bounds.size))
        
        
        let hasCorners = hasCorners && (topItem == nil || bottomItem == nil)
        let hasTopCorners = hasCorners && topItem == nil
        let hasBottomCorners = hasCorners && bottomItem == nil
        
        self.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners, glass: true) : nil
        self.maskNode.frame = CGRect(origin: CGPoint(x: safeInsets.left, y: 0.0), size: CGSize(width: width - safeInsets.left - safeInsets.right, height: height))
        self.bottomSeparatorNode.isHidden = hasBottomCorners
        
        if self.maskNode.supernode == nil {
            self.addSubnode(self.maskNode)
        }
        
        let highlightNodeOffset: CGFloat = topItem == nil ? 0.0 : UIScreenPixel
        self.selectionNode.update(size: CGSize(width: width, height: height + highlightNodeOffset), theme: presentationData.theme, transition: transition)
        transition.updateFrame(node: self.selectionNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -highlightNodeOffset), size: CGSize(width: width, height: height + highlightNodeOffset)))
        self.activateArea.frame = CGRect(origin: .zero, size: CGSize(width: width, height: height))
        
        var separatorInset: CGFloat = sideInset
        if bottomItem != nil {
            separatorInset += 49.0
        }
        
        let separatorRightInset: CGFloat = 16.0
        
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: separatorInset, y: height - UIScreenPixel), size: CGSize(width: width - separatorInset - separatorRightInset, height: UIScreenPixel)))
        transition.updateAlpha(node: self.bottomSeparatorNode, alpha: bottomItem == nil ? 0.0 : 1.0)
        
        return height
    }

    @objc private func performAccessibilityAction(_ action: UIAccessibilityCustomAction) -> Bool {
        guard let action = action as? PeerInfoMemberAccessibilityAction else {
            return false
        }
        action.perform()
        return true
    }
    
    private func updateTouchesAtPoint(_ point: CGPoint?) {
        guard let item = self.item else {
            return
        }
        var highlight = point != nil
        if case .account = item.member {
        } else if item.context.accountPeerId == item.member.id {
            highlight = false
        }
        if let point, let itemNode = self.itemNode, let value = itemNode.view.hitTest(self.view.convert(point, to: itemNode.view), with: nil), value is UIControl {
            highlight = false
        }
        if highlight {
            self.selectionNode.updateIsHighlighted(true)
        } else {
            self.selectionNode.updateIsHighlighted(false)
        }
    }
}
