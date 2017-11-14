import Foundation
import SwiftSignalKit

private let defaultOrientations: UIInterfaceOrientationMask = {
    if UIDevice.current.userInterfaceIdiom == .pad {
        return .all
    } else {
        return .allButUpsideDown
    }
}()

private class WindowRootViewController: UIViewController {
    var presentController: ((UIViewController, PresentationSurfaceLevel, Bool, (() -> Void)?) -> Void)?
    var orientations: UIInterfaceOrientationMask = defaultOrientations {
        didSet {
            if oldValue != self.orientations {
                if self.orientations == .portrait {
                    if UIDevice.current.orientation != .portrait {
                        let value = UIInterfaceOrientation.portrait.rawValue
                        UIDevice.current.setValue(value, forKey: "orientation")
                    }
                } else {
                    UIViewController.attemptRotationToDeviceOrientation()
                }
            }
        }
    }
    
    var gestureEdges: UIRectEdge = [] {
        didSet {
            if oldValue != self.gestureEdges {
                if #available(iOSApplicationExtension 11.0, *) {
                    self.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
                }
            }
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }
    
    override var prefersStatusBarHidden: Bool {
        return false
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return orientations
    }
    
    override func preferredScreenEdgesDeferringSystemGestures() -> UIRectEdge {
        return self.gestureEdges
    }
}

private final class NativeWindow: UIWindow, WindowHost {
    var updateSize: ((CGSize) -> Void)?
    var layoutSubviewsEvent: (() -> Void)?
    var updateIsUpdatingOrientationLayout: ((Bool) -> Void)?
    var updateToInterfaceOrientation: (() -> Void)?
    var presentController: ((ViewController, PresentationSurfaceLevel) -> Void)?
    var hitTestImpl: ((CGPoint, UIEvent?) -> UIView?)?
    var presentNativeImpl: ((UIViewController) -> Void)?
    var invalidateDeferScreenEdgeGestureImpl: (() -> Void)?
    
    private var frameTransition: ContainedViewLayoutTransition?
    
    override var frame: CGRect {
        get {
            return super.frame
        } set(value) {
            let sizeUpdated = super.frame.size != value.size
            if sizeUpdated, let transition = self.frameTransition, case let .animated(duration, curve) = transition {
                let previousFrame = super.frame
                super.frame = value
                self.layer.animateFrame(from: previousFrame, to: value, duration: duration, timingFunction: curve.timingFunction)
            } else {
                super.frame = value
            }
            
            if sizeUpdated {
                self.updateSize?(value.size)
            }
        }
    }
    
    override var bounds: CGRect {
        get {
            return super.bounds
        }
        set(value) {
            let sizeUpdated = super.bounds.size != value.size
            super.bounds = value
            
            if sizeUpdated {
                self.updateSize?(value.size)
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.layoutSubviewsEvent?()
    }
    
    override func _update(toInterfaceOrientation arg1: Int32, duration arg2: Double, force arg3: Bool) {
        self.updateIsUpdatingOrientationLayout?(true)
        if !arg2.isZero {
            self.frameTransition = .animated(duration: arg2, curve: .easeInOut)
        }
        super._update(toInterfaceOrientation: arg1, duration: arg2, force: arg3)
        self.frameTransition = nil
        self.updateIsUpdatingOrientationLayout?(false)
        
        self.updateToInterfaceOrientation?()
    }
    
    func present(_ controller: ViewController, on level: PresentationSurfaceLevel) {
        self.presentController?(controller, level)
    }
    
    func presentNative(_ controller: UIViewController) {
        self.presentNativeImpl?(controller)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return self.hitTestImpl?(point, event)
    }
    
    override func insertSubview(_ view: UIView, at index: Int) {
        super.insertSubview(view, at: index)
    }
    
    override func addSubview(_ view: UIView) {
        super.addSubview(view)
    }
    
    override func insertSubview(_ view: UIView, aboveSubview siblingSubview: UIView) {
        if let transitionClass = NSClassFromString("UITransitionView"), view.isKind(of: transitionClass) {
            super.insertSubview(view, aboveSubview: self.subviews.last!)
        } else {
            super.insertSubview(view, aboveSubview: siblingSubview)
        }
    }
    
    func invalidateDeferScreenEdgeGestures() {
        self.invalidateDeferScreenEdgeGestureImpl?()
    }
}

public func nativeWindowHostView() -> WindowHostView {
    let window = NativeWindow(frame: UIScreen.main.bounds)
    
    let rootViewController = WindowRootViewController()
    window.rootViewController = rootViewController
    rootViewController.viewWillAppear(false)
    rootViewController.viewDidAppear(false)
    rootViewController.view.isHidden = true
    
    let hostView = WindowHostView(view: window, isRotating: {
        return window.isRotating()
    }, updateSupportedInterfaceOrientations: { orientations in
        rootViewController.orientations = orientations
    }, updateDeferScreenEdgeGestures: { edges in
        rootViewController.gestureEdges = edges
    })
    
    window.updateSize = { [weak hostView] size in
        hostView?.updateSize?(size)
    }
    
    window.layoutSubviewsEvent = { [weak hostView] in
        hostView?.layoutSubviews?()
    }
    
    window.updateIsUpdatingOrientationLayout = { [weak hostView] value in
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
    }
    
    window.hitTestImpl = { [weak hostView] point, event in
        return hostView?.hitTest?(point, event)
    }
    
    window.invalidateDeferScreenEdgeGestureImpl = { [weak hostView] in
        return hostView?.invalidateDeferScreenEdgeGesture?()
    }
    
    rootViewController.presentController = { [weak hostView] controller, level, animated, completion in
        if let strongSelf = hostView {
            strongSelf.present?(LegacyPresentedController(legacyController: controller, presentation: .custom), level)
            if let completion = completion {
                completion()
            }
        }
    }
    
    return hostView
}
