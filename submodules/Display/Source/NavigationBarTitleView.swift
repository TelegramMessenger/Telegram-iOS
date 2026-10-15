import Foundation
import UIKit

public protocol NavigationBarTitleView: UIView {
    var requestUpdate: ((ContainedViewLayoutTransition) -> Void)? { get set }
    
    func animateLayoutTransition()
    
    func updateLayout(availableSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize
}

/// A title view drawn on a glass pill (the chat header). In a navigation transition the pill is its bar's second right
/// platter: the transition draws the pill's glass and a still copy of its contents, and the view hides both meanwhile.
public protocol NavigationBarGlassPillTitleView: NavigationBarTitleView {
    /// The pill's frame in the view, nil when it shows none.
    var glassPillFrame: CGRect? { get }
    /// A still copy of what the pill shows, without its glass, at the pill's size.
    func makeGlassPillContentCopy() -> UIView?
    /// While true the view hides its pill and its contents (a transition draws them).
    var isGlassPillDetached: Bool { get set }
}
