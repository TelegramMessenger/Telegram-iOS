import Foundation
import UIKit
import Display

public let mediaEditorEmbeddedToolRemovalTimeout: Double = 0.6

public func mediaEditorEmbedToolController(_ controller: ViewController, in hostView: UIView, below siblingView: UIView?, layout: ContainerViewLayout, originX: CGFloat = 0.0) {
    controller.view.frame = CGRect(origin: CGPoint(x: originX, y: 0.0), size: layout.size)
    if let siblingView, siblingView.superview === hostView {
        hostView.insertSubview(controller.view, belowSubview: siblingView)
    } else {
        hostView.addSubview(controller.view)
    }
    controller.containerLayoutUpdated(layout, transition: .immediate)
}

public func mediaEditorDismissEmbeddedToolController(_ controller: ViewController, animateOut: (@escaping () -> Void) -> Void, remove: @escaping (ViewController) -> Void) {
    animateOut({
        remove(controller)
    })
    DispatchQueue.main.asyncAfter(deadline: .now() + mediaEditorEmbeddedToolRemovalTimeout, execute: {
        remove(controller)
    })
}

@discardableResult
public func mediaEditorRemoveEmbeddedToolController(_ controller: ViewController, from hostView: UIView) -> Bool {
    guard controller.isViewLoaded, controller.view.superview === hostView else {
        return false
    }
    controller.view.removeFromSuperview()
    return true
}

public func mediaEditorUpdateEmbeddedToolLayout(_ controllers: [ViewController], in hostView: UIView, layout: ContainerViewLayout, originX: CGFloat = 0.0, transition: ContainedViewLayoutTransition) {
    for controller in controllers where controller.isViewLoaded && controller.view.superview === hostView {
        transition.updateFrame(view: controller.view, frame: CGRect(origin: CGPoint(x: originX, y: 0.0), size: layout.size))
        controller.containerLayoutUpdated(layout, transition: transition)
    }
}
