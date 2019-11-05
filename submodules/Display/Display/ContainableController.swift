import UIKit
import AsyncDisplayKit
import SwiftSignalKit

public protocol PresentableController: class {
    func viewDidAppear(completion: @escaping () -> Void)
}

public protocol ContainableController: class {
    var view: UIView! { get }
    var displayNode: ASDisplayNode { get }
    var isViewLoaded: Bool { get }
    var isOpaqueWhenInOverlay: Bool { get }
    var isModalWhenInOverlay: Bool { get }
    var blocksBackgroundWhenInOverlay: Bool { get }
    var ready: Promise<Bool> { get }
    var updateTransitionWhenPresentedAsModal: ((CGFloat, ContainedViewLayoutTransition) -> Void)? { get set }
    
    func combinedSupportedOrientations(currentOrientationToLock: UIInterfaceOrientationMask) -> ViewControllerSupportedOrientations
    var deferScreenEdgeGestures: UIRectEdge { get }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition)
    func updateToInterfaceOrientation(_ orientation: UIInterfaceOrientation)
    func updateModalTransition(_ value: CGFloat, transition: ContainedViewLayoutTransition)
    
    func viewWillAppear(_ animated: Bool)
    func viewWillDisappear(_ animated: Bool)
    func viewDidAppear(_ animated: Bool)
    func viewDidDisappear(_ animated: Bool)
}
