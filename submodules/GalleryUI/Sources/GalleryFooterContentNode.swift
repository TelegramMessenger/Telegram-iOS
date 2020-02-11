import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit

public final class GalleryControllerInteraction {
    public let presentController: (ViewController, ViewControllerPresentationArguments?) -> Void
    public let dismissController: () -> Void
    public let replaceRootController: (ViewController, ValuePromise<Bool>?) -> Void
    
    public init(presentController: @escaping (ViewController, ViewControllerPresentationArguments?) -> Void, dismissController: @escaping () -> Void, replaceRootController: @escaping (ViewController, ValuePromise<Bool>?) -> Void) {
        self.presentController = presentController
        self.dismissController = dismissController
        self.replaceRootController = replaceRootController
    }
}

open class GalleryFooterContentNode: ASDisplayNode {
    public var requestLayout: ((ContainedViewLayoutTransition) -> Void)?
    public var controllerInteraction: GalleryControllerInteraction?
    
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
    
    open func updateLayout(size: CGSize, metrics: LayoutMetrics, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) {
    }

    open func animateIn(previousContentNode: GalleryOverlayContentNode?, transition: ContainedViewLayoutTransition) {
    }
    
    open func animateOut(nextContentNode: GalleryOverlayContentNode?, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        completion()
    }
}
