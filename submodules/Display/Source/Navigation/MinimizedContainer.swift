import Foundation
import UIKit
import AsyncDisplayKit

public protocol MinimizedContainer: ASDisplayNode {
    var navigationController: NavigationController? { get set }
    var controllers: [MinimizableController] { get }
    var isExpanded: Bool { get }
    
    var willMaximize: ((MinimizedContainer) -> Void)? { get set }
    var willDismiss: ((MinimizedContainer) -> Void)? { get set }
    var didDismiss: ((MinimizedContainer) -> Void)? { get set }
    
    var statusBarStyle: StatusBarStyle { get }
    var statusBarStyleUpdated: (() -> Void)? { get set }
    
    func addController(_ viewController: MinimizableController, topEdgeOffset: CGFloat?, beforeMaximize: @escaping (NavigationController, @escaping () -> Void) -> Void, transition: ContainedViewLayoutTransition)
    func removeController(_ viewController: MinimizableController)
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
    var isMinimizable: Bool { get }
    var minimizedIcon: UIImage? { get }
    var minimizedProgress: Float? { get }
    var isFullscreen: Bool { get }
    
    func requestMinimize(topEdgeOffset: CGFloat?, initialVelocity: CGFloat?)
    func makeContentSnapshotView() -> UIView?
    
    func prepareContentSnapshotView()
    func resetContentSnapshotView()
    
    func shouldDismissImmediately() -> Bool
}

public extension MinimizableController {
    var isFullscreen: Bool {
        return false
    }
    
    var minimizedTopEdgeOffset: CGFloat? {
        return nil
    }
    
    var minimizedBounds: CGRect? {
        return nil
    }
    
    var isMinimized: Bool {
        return false
    }
    
    var isMinimizable: Bool {
        return false
    }
    
    var minimizedIcon: UIImage? {
        return nil
    }
    
    var minimizedProgress: Float? {
        return nil
    }
    
    func requestMinimize(topEdgeOffset: CGFloat?, initialVelocity: CGFloat?) {
        
    }
    
    func makeContentSnapshotView() -> UIView? {
        return self.displayNode.view.snapshotView(afterScreenUpdates: false)
    }
    
    func prepareContentSnapshotView() {
        
    }
    
    func resetContentSnapshotView() {
        
    }
        
    func shouldDismissImmediately() -> Bool {
        return true
    }
}
