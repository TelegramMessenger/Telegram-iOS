import Foundation
import UIKit

enum NavigationBarTransitionRole {
    case top
    case bottom
}

final class NavigationBarTransitionState {
    weak var navigationBar: NavigationBar?
    let transition: NavigationTransition
    let role: NavigationBarTransitionRole
    let progress: CGFloat
    
    init(navigationBar: NavigationBar, transition: NavigationTransition, role: NavigationBarTransitionRole, progress: CGFloat) {
        self.navigationBar = navigationBar
        self.transition = transition
        self.role = role
        self.progress = progress
    }
}
