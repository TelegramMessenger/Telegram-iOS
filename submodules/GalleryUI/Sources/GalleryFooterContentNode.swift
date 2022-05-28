import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox

public final class GalleryControllerInteraction {
    public let presentController: (ViewController, ViewControllerPresentationArguments?) -> Void
    public let pushController: (ViewController) -> Void
    public let dismissController: () -> Void
    public let replaceRootController: (ViewController, Promise<Bool>?) -> Void
    public let editMedia: (MessageId) -> Void
    
    public init(presentController: @escaping (ViewController, ViewControllerPresentationArguments?) -> Void, pushController: @escaping (ViewController) -> Void, dismissController: @escaping () -> Void, replaceRootController: @escaping (ViewController, Promise<Bool>?) -> Void, editMedia: @escaping (MessageId) -> Void) {
        self.presentController = presentController
        self.pushController = pushController
        self.dismissController = dismissController
        self.replaceRootController = replaceRootController
        self.editMedia = editMedia
    }
}

open class GalleryFooterContentNode: ASDisplayNode {
    public var requestLayout: ((ContainedViewLayoutTransition) -> Void)?
    public var controllerInteraction: GalleryControllerInteraction?
    
    var visibilityAlpha: CGFloat = 1.0
    open func setVisibilityAlpha(_ alpha: CGFloat, animated: Bool) {
        self.visibilityAlpha = alpha
        self.alpha = alpha
    }
    
    open func updateLayout(size: CGSize, metrics: LayoutMetrics, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, contentInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        return 0.0
    }
    
    open func animateIn(fromHeight: CGFloat, previousContentNode: GalleryFooterContentNode, transition: ContainedViewLayoutTransition) {
    }
    
    open func animateOut(toHeight: CGFloat, nextContentNode: GalleryFooterContentNode, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        completion()
    }
}

open class GalleryOverlayContentNode: ASDisplayNode {
    var visibilityAlpha: CGFloat = 1.0
    open func setVisibilityAlpha(_ alpha: CGFloat) {
        self.visibilityAlpha = alpha
    }
    
    open func updateLayout(size: CGSize, metrics: LayoutMetrics, insets: UIEdgeInsets, isHidden: Bool, transition: ContainedViewLayoutTransition) {
    }

    open func animateIn(previousContentNode: GalleryOverlayContentNode?, transition: ContainedViewLayoutTransition) {
    }
    
    open func animateOut(nextContentNode: GalleryOverlayContentNode?, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        completion()
    }
}
