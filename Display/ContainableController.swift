import UIKit
import AsyncDisplayKit

public protocol ContainableController: class {
    var view: UIView! { get }
    
    func combinedSupportedOrientations() -> ViewControllerSupportedOrientations
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition)
}
