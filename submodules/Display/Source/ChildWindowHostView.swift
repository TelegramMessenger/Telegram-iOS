import Foundation
import UIKit

final class ChildWindowHostView: UIView, WindowHost {
    var updateSize: ((CGSize) -> Void)?
    var layoutSubviewsEvent: (() -> Void)?
    var hitTestImpl: ((CGPoint, UIEvent?) -> UIView?)?
    var presentController: ((ContainableController, PresentationSurfaceLevel, Bool, @escaping () -> Void) -> Void)?
    var invalidateDeferScreenEdgeGestureImpl: (() -> Void)?
    var invalidatePrefersOnScreenNavigationHiddenImpl: (() -> Void)?
    var invalidateSupportedOrientationsImpl: (() -> Void)?
    var cancelInteractiveKeyboardGesturesImpl: (() -> Void)?
    var forEachControllerImpl: (((ContainableController) -> Void) -> Void)?
    var getAccessibilityElementsImpl: (() -> [Any]?)?
    
    override var frame: CGRect {
        didSet {
            if self.frame.size != oldValue.size {
                self.updateSize?(self.frame.size)
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.layoutSubviewsEvent?()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return self.hitTestImpl?(point, event)
    }
    
    func invalidateDeferScreenEdgeGestures() {
        self.invalidateDeferScreenEdgeGestureImpl?()
    }
    
    func invalidatePrefersOnScreenNavigationHidden() {
        self.invalidatePrefersOnScreenNavigationHiddenImpl?()
    }
    
    func invalidateSupportedOrientations() {
        self.invalidateSupportedOrientationsImpl?()
    }
    
    func cancelInteractiveKeyboardGestures() {
        self.cancelInteractiveKeyboardGesturesImpl?()
    }
    
    func forEachController(_ f: (ContainableController) -> Void) {
        self.forEachControllerImpl?(f)
    }
    
    func present(_ controller: ContainableController, on level: PresentationSurfaceLevel, blockInteraction: Bool, completion: @escaping () -> Void) {
        self.presentController?(controller, level, blockInteraction, completion)
    }
    
    func presentInGlobalOverlay(_ controller: ContainableController) {
        self.presentController?(controller, .root, true, {})
    }
    
    func addGlobalPortalHostView(sourceView: PortalSourceView) {
    }
}

public func childWindowHostView(parent: UIView) -> WindowHostView {
    let view = ChildWindowHostView()
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    
    let hostView = WindowHostView(containerView: view, eventView: view, isRotating: {
        return false
    }, systemUserInterfaceStyle: .single(.light), updateSupportedInterfaceOrientations: { orientations in
    }, updateDeferScreenEdgeGestures: { edges in
    }, updatePrefersOnScreenNavigationHidden: { value in
    })
    
    view.updateSize = { [weak hostView] size in
        hostView?.updateSize?(size, 0.0)
    }
    
    view.layoutSubviewsEvent = { [weak hostView] in
        hostView?.layoutSubviews?()
    }
    
    /*window.updateIsUpdatingOrientationLayout = { [weak hostView] value in
        hostView?.isUpdatingOrientationLayout = value
    }
    
    window.updateToInterfaceOrientation = { [weak hostView] in
        hostView?.updateToInterfaceOrientation?()
    }*/
    
    view.presentController = { [weak hostView] controller, level, block, f in
        hostView?.present?(controller, level, block, f)
    }
    
    /*view.presentNativeImpl = { [weak hostView] controller in
        hostView?.presentNative?(controller)
    }*/
    
    view.hitTestImpl = { [weak hostView] point, event in
        return hostView?.hitTest?(point, event)
    }
    
    view.invalidateDeferScreenEdgeGestureImpl = { [weak hostView] in
        hostView?.invalidateDeferScreenEdgeGesture?()
    }
    
    view.invalidatePrefersOnScreenNavigationHiddenImpl = { [weak hostView] in
        hostView?.invalidatePrefersOnScreenNavigationHidden?()
    }
    
    view.invalidateSupportedOrientationsImpl = { [weak hostView] in
        hostView?.invalidateSupportedOrientations?()
    }
    
    view.cancelInteractiveKeyboardGesturesImpl = { [weak hostView] in
        hostView?.cancelInteractiveKeyboardGestures?()
    }
    
    view.forEachControllerImpl = { [weak hostView] f in
        hostView?.forEachController?(f)
    }
    
    view.getAccessibilityElementsImpl = { [weak hostView] in
        return hostView?.getAccessibilityElements?()
    }
    
    return hostView
}
