import Foundation
import AsyncDisplayKit
import Display

public protocol NotificationItem {
    var groupingKey: AnyHashable? { get }
    
    func node() -> NotificationItemNode
    func tapped()
}

public class NotificationItemNode: ASDisplayNode {
    func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        return 32.0
    }
}
