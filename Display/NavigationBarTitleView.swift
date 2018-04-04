import Foundation
import UIKit

public protocol NavigationBarTitleView {
    func animateLayoutTransition()
    
    func updateLayout(size: CGSize, clearBounds: CGRect, transition: ContainedViewLayoutTransition)
}
