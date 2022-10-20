import Foundation
import UIKit
import AsyncDisplayKit
import Display

public protocol NotificationItem {
    var groupingKey: AnyHashable? { get }
    
    func node(compact: Bool) -> NotificationItemNode
    func tapped(_ take: @escaping () -> (ASDisplayNode?, () -> Void))
    func canBeExpanded() -> Bool
    func expand(_ take: @escaping () -> (ASDisplayNode?, () -> Void))
}

public class NotificationItemNode: ASDisplayNode {
    func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        return 32.0
    }
}
