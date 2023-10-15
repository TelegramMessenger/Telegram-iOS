import Foundation
import UIKit
import ChatMessageItemView
import AsyncDisplayKit

public protocol ChatMessageTransitionNodeDecorationItemNode: ASDisplayNode {
    var contentView: UIView { get }
}

public protocol ChatMessageTransitionNode: AnyObject {
    typealias DecorationItemNode = ChatMessageTransitionNodeDecorationItemNode
    
    func add(decorationView: UIView, itemNode: ChatMessageItemView) -> DecorationItemNode
    func remove(decorationNode: DecorationItemNode)
}
