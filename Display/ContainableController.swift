import UIKit
import AsyncDisplayKit
import SwiftSignalKit

public protocol ContainableController: class {
    var view: UIView! { get }
    var isViewLoaded: Bool { get }
    var isOpaqueWhenInOverlay: Bool { get }
    var ready: Promise<Bool> { get }
    
    func combinedSupportedOrientations(currentOrientationToLock: UIInterfaceOrientationMask) -> ViewControllerSupportedOrientations
    var deferScreenEdgeGestures: UIRectEdge { get }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition)
    
    func viewWillAppear(_ animated: Bool)
    func viewWillDisappear(_ animated: Bool)
    func viewDidAppear(_ animated: Bool)
    func viewDidDisappear(_ animated: Bool)
}
