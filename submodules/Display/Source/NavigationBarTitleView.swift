import Foundation
import UIKit

public protocol NavigationBarTitleView: UIView {
    var requestUpdate: ((ContainedViewLayoutTransition) -> Void)? { get set }
    
    func animateLayoutTransition()
    
    func updateLayout(availableSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize
}
