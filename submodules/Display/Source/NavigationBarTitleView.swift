import Foundation
import UIKit

public protocol NavigationBarTitleView: UIView {
    var requestUpdate: ((ContainedViewLayoutTransition) -> Void)? { get set }
    
    func animateLayoutTransition()
    
    func updateLayout(availableSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize
}

/// A title view drawn on a glass pill (the chat header). In a navigation transition the pill is its bar's second right
/// platter: the transition draws the pill's glass and shows its contents, lent live, while the view hides both.
public protocol NavigationBarGlassPillTitleView: NavigationBarTitleView {
    /// The pill's frame in the view, nil when it shows none.
    var glassPillFrame: CGRect? { get }
    /// What the pill shows, lent live to the transition that draws the pill while it is detached: the same view for the
    /// whole detachment, taken back when `isGlassPillDetached` turns false.
    func lendGlassPillContent() -> UIView?
    /// While true the view hides its pill and its contents (a transition draws them).
    var isGlassPillDetached: Bool { get set }
}
