import Foundation
import UIKit

private final class ChildWindowHostView: UIView {
    var updateSize: ((CGSize) -> Void)?
    var layoutSubviewsEvent: (() -> Void)?
    var hitTestImpl: ((CGPoint, UIEvent?) -> UIView?)?
    
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
}

public func childWindowHostView(parent: UIView) -> WindowHostView {
    let view = ChildWindowHostView()
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    
    let hostView = WindowHostView(view: view, isRotating: {
        return false
    }, updateSupportedInterfaceOrientations: { orientations in
        //rootViewController.orientations = orientations
    }, updateDeferScreenEdgeGestures: { edges in
    })
    
    view.updateSize = { [weak hostView] size in
        hostView?.updateSize?(size)
    }
    
    view.layoutSubviewsEvent = { [weak hostView] in
        hostView?.layoutSubviews?()
    }
    
    /*window.updateIsUpdatingOrientationLayout = { [weak hostView] value in
        hostView?.isUpdatingOrientationLayout = value
    }
    
    window.updateToInterfaceOrientation = { [weak hostView] in
        hostView?.updateToInterfaceOrientation?()
    }
    
    window.presentController = { [weak hostView] controller, level in
        hostView?.present?(controller, level)
    }
    
    window.presentNativeImpl = { [weak hostView] controller in
        hostView?.presentNative?(controller)
    }*/
    
    view.hitTestImpl = { [weak hostView] point, event in
        return hostView?.hitTest?(point, event)
    }
    
    /*rootViewController.presentController = { [weak hostView] controller, level, animated, completion in
        if let strongSelf = hostView {
            strongSelf.present?(LegacyPresentedController(legacyController: controller, presentation: .custom), level)
            if let completion = completion {
                completion()
            }
        }
    }*/
    
    return hostView
}
