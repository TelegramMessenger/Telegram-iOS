import Foundation
import UIKit
import Display
import AsyncDisplayKit

public func createGradientBackgroundNode(useSharedAnimationPhase: Bool = false) -> GradientBackgroundNode {
    return GradientBackgroundNode(useSharedAnimationPhase: useSharedAnimationPhase)
}
