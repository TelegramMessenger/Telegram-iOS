import Foundation
import AsyncDisplayKit

public protocol MinimizedContainer: ASDisplayNode {
    var navigationController: NavigationController? { get set }
    var controllers: [MinimizableController] { get }
    var isExpanded: Bool { get }
    
    var willMaximize: (() -> Void)? { get set }
    
    var statusBarStyle: StatusBarStyle { get }
    var statusBarStyleUpdated: (() -> Void)? { get set }
    
    func addController(_ viewController: MinimizableController, beforeMaximize: @escaping (NavigationController, @escaping () -> Void) -> Void, transition: ContainedViewLayoutTransition)
    func maximizeController(_ viewController: MinimizableController, animated: Bool, completion: @escaping (Bool) -> Void)
    func collapse()
    func dismissAll(completion: @escaping () -> Void)
    
    func updateLayout(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition)
    func collapsedHeight(layout: ContainerViewLayout) -> CGFloat
}

public protocol MinimizableController: ViewController {
    var minimizedTopEdgeOffset: CGFloat? { get }
    var minimizedBounds: CGRect? { get }
    var isMinimized: Bool { get set }
    
    func makeContentSnapshotView() -> UIView?
}

public extension MinimizableController {
    var minimizedTopEdgeOffset: CGFloat? {
        return nil
    }
    
    var minimizedBounds: CGRect? {
        return nil
    }
    
    var isMinimized: Bool {
        return false
    }
    
    func makeContentSnapshotView() -> UIView? {
        return self.displayNode.view.snapshotView(afterScreenUpdates: false)
    }
}
