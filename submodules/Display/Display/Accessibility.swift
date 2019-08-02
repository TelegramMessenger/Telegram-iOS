import Foundation
import UIKit
import AsyncDisplayKit

public func addAccessibilityChildren(of node: ASDisplayNode, container: Any, to list: inout [Any]) {
    if node.isAccessibilityElement {
        let element = UIAccessibilityElement(accessibilityContainer: container)
        element.accessibilityFrame = UIAccessibility.convertToScreenCoordinates(node.bounds, in: node.view)
        element.accessibilityLabel = node.accessibilityLabel
        element.accessibilityValue = node.accessibilityValue
        element.accessibilityTraits = node.accessibilityTraits
        element.accessibilityHint = node.accessibilityHint
        element.accessibilityIdentifier = node.accessibilityIdentifier
        
        //node.accessibilityFrame = UIAccessibilityConvertFrameToScreenCoordinates(node.bounds, node.view)
        list.append(element)
    } else if let accessibilityElements = node.accessibilityElements {
        list.append(contentsOf: accessibilityElements)
    }
}

