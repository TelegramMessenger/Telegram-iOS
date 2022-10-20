import Foundation
import UIKit
import AsyncDisplayKit
import Display

struct SecureIdAuthContentLayout {
    let height: CGFloat
    let centerOffset: CGFloat
}

protocol SecureIdAuthContentNode {
    func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> SecureIdAuthContentLayout
    func willDisappear()
    func didAppear()
    func animateIn()
    func animateOut(completion: @escaping () -> Void)
}
