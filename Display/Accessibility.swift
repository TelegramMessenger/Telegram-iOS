import Foundation
import UIKit
import AsyncDisplayKit

public func addAccessibilityChildren(of node: ASDisplayNode, to list: inout [Any]) {
    if node.isAccessibilityElement {
        node.accessibilityFrame = UIAccessibilityConvertFrameToScreenCoordinates(node.bounds, node.view)
        list.append(node)
    } else if let accessibilityElements = node.accessibilityElements {
        list.append(contentsOf: accessibilityElements)
    }
}

