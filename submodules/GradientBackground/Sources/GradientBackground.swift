import Foundation
import UIKit
import Display
import AsyncDisplayKit

public protocol GradientBackgroundNode: ASDisplayNode {
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition)
    func animateEvent(transition: ContainedViewLayoutTransition)
}

public func createGradientBackgroundNode() -> GradientBackgroundNode {
    return SoftwareGradientBackgroundNode()
}
