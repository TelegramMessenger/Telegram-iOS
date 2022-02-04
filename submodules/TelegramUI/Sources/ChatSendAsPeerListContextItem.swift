import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AppBundle
import ContextUI
import TelegramStringFormatting
import AvatarNode
import AccountContext

final class ChatSendAsPeerListContextItem: ContextMenuCustomItem {
    let context: AccountContext
    let chatPeerId: PeerId
    let peers: [FoundPeer]
    let selectedPeerId: PeerId?
    
    init(context: AccountContext, chatPeerId: PeerId, peers: [FoundPeer], selectedPeerId: PeerId?) {
        self.context = context
        self.chatPeerId = chatPeerId
        self.peers = peers
        self.selectedPeerId = selectedPeerId
    }
    
    func node(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) -> ContextMenuCustomNode {
        return ChatSendAsPeerListContextItemNode(presentationData: presentationData, item: self, getController: getController, actionSelected: actionSelected)
    }
}

private final class ChatSendAsPeerListContextItemNode: ASDisplayNode, ContextMenuCustomNode, ContextActionNodeProtocol, UIScrollViewDelegate {
    private let item: ChatSendAsPeerListContextItem
    private let presentationData: PresentationData
    private let getController: () -> ContextControllerProtocol?
    private let actionSelected: (ContextMenuActionResult) -> Void
    
    private let scrollNode: ASScrollNode
    private let actionNodes: [ContextActionNode]
    private let separatorNodes: [ASDisplayNode]
    private let selectedItemIndex: Int
    private var initialized = false
    
    init(presentationData: PresentationData, item: ChatSendAsPeerListContextItem, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) {
        self.item = item
        self.presentationData = presentationData
        self.getController = getController
        self.actionSelected = actionSelected
        
        self.scrollNode = ASScrollNode()
                
        let avatarSize = CGSize(width: 30.0, height: 30.0)
        
        var actionNodes: [ContextActionNode] = []
        var separatorNodes: [ASDisplayNode] = []
        
        var selectedItemIndex = 0
        var i = 0
        for peer in item.peers {
            var subtitle: String?
            if peer.peer.id.namespace == Namespaces.Peer.CloudUser {
                subtitle = presentationData.strings.VoiceChat_PersonalAccount
            } else if let subscribers = peer.subscribers {
                if let peer = peer.peer as? TelegramChannel {
                    if case .broadcast = peer.info {
                        subtitle = presentationData.strings.Conversation_StatusSubscribers(subscribers)
                    } else {
                        subtitle = presentationData.strings.VoiceChat_DiscussionGroup
                    }
                } else {
                    subtitle = presentationData.strings.Conversation_StatusMembers(subscribers)
                }
            }

            let isSelected = peer.peer.id == item.selectedPeerId
            if isSelected {
                selectedItemIndex = i
            }
            let extendedAvatarSize = CGSize(width: 35.0, height: 35.0)
            let avatarSignal = peerAvatarCompleteImage(account: item.context.account, peer: EnginePeer(peer.peer), size: avatarSize)
            |> map { image -> UIImage? in
                if isSelected, let image = image {
                    return generateImage(extendedAvatarSize, rotatedContext: { size, context in
                        let bounds = CGRect(origin: CGPoint(), size: size)
                        context.clear(bounds)
                        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                        context.scaleBy(x: 1.0, y: -1.0)
                        context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                        context.draw(image.cgImage!, in: CGRect(x: (extendedAvatarSize.width - avatarSize.width) / 2.0, y: (extendedAvatarSize.height - avatarSize.height) / 2.0, width: avatarSize.width, height: avatarSize.height))

                        let lineWidth = 1.0 + UIScreenPixel
                        context.setLineWidth(lineWidth)
                        context.setStrokeColor(presentationData.theme.actionSheet.controlAccentColor.cgColor)
                        context.strokeEllipse(in: bounds.insetBy(dx: lineWidth / 2.0, dy: lineWidth / 2.0))
                    })
                } else {
                    return image
                }
            }
            
            let action = ContextMenuActionItem(text: EnginePeer(peer.peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), textLayout: subtitle.flatMap { .secondLineWithValue($0) } ?? .singleLine, icon: { _ in nil }, iconSource: ContextMenuActionItemIconSource(size: isSelected ? extendedAvatarSize : avatarSize, signal: avatarSignal), action: { _, f in
                f(.default)

                if peer.peer.id != item.selectedPeerId {
                    let _ = item.context.engine.peers.updatePeerSendAsPeer(peerId: item.chatPeerId, sendAs: peer.peer.id).start()
                }
            })
            let actionNode = ContextActionNode(presentationData: presentationData, action: action, getController: getController, actionSelected: actionSelected, requestLayout: {}, requestUpdateAction: { _, _ in
            })
            actionNodes.append(actionNode)
            if actionNodes.count != item.peers.count {
                let separatorNode = ASDisplayNode()
                separatorNode.backgroundColor = presentationData.theme.contextMenu.itemSeparatorColor
                separatorNodes.append(separatorNode)
            }
            i += 1
        }
        self.actionNodes = actionNodes
        self.separatorNodes = separatorNodes
        self.selectedItemIndex = selectedItemIndex
        
        super.init()
        
        self.addSubnode(self.scrollNode)
        for separatorNode in self.separatorNodes {
            self.scrollNode.addSubnode(separatorNode)
        }
        for actionNode in self.actionNodes {
            self.scrollNode.addSubnode(actionNode)
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.scrollNode.view.delegate = self
        self.scrollNode.view.alwaysBounceVertical = false
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.scrollIndicatorInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 5.0, right: 0.0)
    }

    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let minActionsWidth: CGFloat = 250.0
        let maxActionsWidth: CGFloat = 300.0
        let constrainedWidth = min(constrainedWidth, maxActionsWidth)
        var maxWidth: CGFloat = 0.0
        var contentHeight: CGFloat = 0.0
        var heightsAndCompletions: [(CGFloat, (CGSize, ContainedViewLayoutTransition) -> Void)?] = []
        for i in 0 ..< self.actionNodes.count {
            let itemNode = self.actionNodes[i]
            let previous: ContextActionSibling
            let next: ContextActionSibling
            if i == 0 {
                previous = .none
            } else {
                previous = .item
            }
            if i == self.actionNodes.count - 1 {
                next = .none
            } else {
                next = .item
            }
            let (minSize, complete) = itemNode.updateLayout(constrainedWidth: constrainedWidth, previous: previous, next: next)
            maxWidth = max(maxWidth, minSize.width)
            heightsAndCompletions.append((minSize.height, complete))
            contentHeight += minSize.height
        }
        
        maxWidth = max(maxWidth, minActionsWidth)
        
        let maxHeight: CGFloat = min(380.0, constrainedHeight - 108.0)
        
        return (CGSize(width: maxWidth, height: min(maxHeight, contentHeight)), { size, transition in
            var verticalOffset: CGFloat = 0.0
            for i in 0 ..< heightsAndCompletions.count {
                let itemNode = self.actionNodes[i]
                if let (itemHeight, itemCompletion) = heightsAndCompletions[i] {
                    let itemSize = CGSize(width: maxWidth, height: itemHeight)
                    transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: verticalOffset), size: itemSize))
                    itemCompletion(itemSize, transition)
                    verticalOffset += itemHeight
                }
                
                if i < self.actionNodes.count - 1 {
                    let separatorNode = self.separatorNodes[i]
                    separatorNode.frame = CGRect(x: 0, y: verticalOffset, width: size.width, height: UIScreenPixel)
                }
            }
            transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: size))
            self.scrollNode.view.contentSize = CGSize(width: size.width, height: contentHeight)
            
            if !self.initialized {
                self.initialized = true
                
                let rect = self.actionNodes[self.selectedItemIndex].frame.insetBy(dx: 0.0, dy: -20.0)
                self.scrollNode.view.scrollRectToVisible(rect, animated: false)
            }
        })
    }
    
    func updateTheme(presentationData: PresentationData) {
        for actionNode in self.actionNodes {
            actionNode.updateTheme(presentationData: presentationData)
        }
    }
    
    var isActionEnabled: Bool {
        return true
    }
    
    func performAction() {
    }
    
    func setIsHighlighted(_ value: Bool) {
    }
    
    func canBeHighlighted() -> Bool {
        return self.isActionEnabled
    }
    
    func updateIsHighlighted(isHighlighted: Bool) {
        self.setIsHighlighted(isHighlighted)
    }
    
    func actionNode(at point: CGPoint) -> ContextActionNodeProtocol {
        for actionNode in self.actionNodes {
            let frame = actionNode.convert(actionNode.bounds, to: self)
            if frame.contains(point) {
                return actionNode
            }
        }
        return self
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        for actionNode in self.actionNodes {
            actionNode.setIsHighlighted(false)
        }
    }
}
