import Foundation
import AsyncDisplayKit

public protocol MinimizedContainer: ASDisplayNode {
    var navigationController: NavigationController? { get set }
    var controllers: [ViewController] { get }
    
    var willMaximize: (() -> Void)? { get set }
    
    func addController(_ viewController: ViewController, transition: ContainedViewLayoutTransition)
    func maximizeController(_ viewController: ViewController, animated: Bool, completion: @escaping (Bool) -> Void)
    func dismissAll(completion: @escaping () -> Void)
    
    func updateLayout(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition)
    func collapsedHeight(layout: ContainerViewLayout) -> CGFloat
}
