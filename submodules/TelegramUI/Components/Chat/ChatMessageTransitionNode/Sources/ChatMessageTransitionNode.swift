import Foundation
import UIKit
import AccountContext
import AsyncDisplayKit

public protocol ChatMessageTransitionNodeDecorationItemNode: ASDisplayNode {
    var contentView: UIView { get }
}

public protocol ChatMessageTransitionNode: AnyObject {
    typealias DecorationItemNode = ChatMessageTransitionNodeDecorationItemNode
    
    func add(decorationView: UIView, itemNode: ChatMessageItemNodeProtocol, aboveEverything: Bool) -> DecorationItemNode
    func remove(decorationNode: DecorationItemNode)
}
