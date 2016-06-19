import Foundation
import AsyncDisplayKit

public class WindowRootViewController: UIViewController {
    public override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .default
    }
    
    public override func prefersStatusBarHidden() -> Bool {
        return false
    }
}

public struct ViewControllerLayout: Equatable {
    public let size: CGSize
    public let insets: UIEdgeInsets
    public let inputViewHeight: CGFloat
    public let statusBarHeight: CGFloat
}

public protocol WindowContentController {
    func setParentLayout(_ layout: ViewControllerLayout, duration: Double, curve: UInt)
    var view: UIView! { get }
}

public func animateRotation(_ view: UIView?, toFrame: CGRect, duration: Double) {
    if let view = view {
        UIView.animate(withDuration: duration, animations: { () -> Void in
            view.frame = toFrame
        })
    }
}

public func animateRotation(view: ASDisplayNode?, toFrame: CGRect, duration: Double) {
    if let view = view {
        CALayer.beginRecordingChanges()
        UIView.animate(withDuration: duration, animations: { () -> Void in
            view.frame = toFrame
        })
        view.layout()
        let states = CALayer.endRecordingChanges() as! [CALayerAnimation]
        let k = Float(UIView.animationDurationFactor())
        var speed: Float = 1.0
        if k != 0 && k != 1 {
            speed = Float(1.0) / k
        }
        for state in states {
            if let layer = state.layer {
                if !state.startBounds.equalTo(state.endBounds) {
                    let boundsAnimation = CABasicAnimation(keyPath: "bounds")
                    boundsAnimation.fromValue = NSValue(cgRect: state.startBounds)
                    boundsAnimation.toValue = NSValue(cgRect: state.endBounds)
                    boundsAnimation.duration = duration
                    boundsAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
                    boundsAnimation.isRemovedOnCompletion = true
                    boundsAnimation.fillMode = kCAFillModeForwards
                    boundsAnimation.speed = speed
                    layer.add(boundsAnimation, forKey: "_rotationBounds")
                }
                
                if !state.startPosition.equalTo(state.endPosition) {
                    let positionAnimation = CABasicAnimation(keyPath: "position")
                    positionAnimation.fromValue = NSValue(cgPoint: state.startPosition)
                    positionAnimation.toValue = NSValue(cgPoint: state.endPosition)
                    positionAnimation.duration = duration
                    positionAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
                    positionAnimation.isRemovedOnCompletion = true
                    positionAnimation.fillMode = kCAFillModeForwards
                    positionAnimation.speed = speed
                    layer.add(positionAnimation, forKey: "_rotationPosition")
                }
            }
        }
    }
}

public class Window: UIWindow {
    private let statusBarManager: StatusBarManager
    
    private var updateViewSizeOnLayout: (Bool, Double) = (false, 0.0)
    public var isUpdatingOrientationLayout = false
    
    private let orientationChangeDuration: Double = {
        UIDevice.current().userInterfaceIdiom == .pad ? 0.4 : 0.3
    }()
    
    public convenience init() {
        self.init(frame: UIScreen.main().bounds)
    }
    
    public override init(frame: CGRect) {
        self.statusBarManager = StatusBarManager()
        
        super.init(frame: frame)
        
        super.rootViewController = WindowRootViewController()
    }
    
    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return self.viewController?.view.hitTest(point, with: event)
    }
    
    public override var frame: CGRect {
        get {
            return super.frame
        }
        set(value) {
            let sizeUpdated = super.frame.size != value.size
            super.frame = value
            
            if sizeUpdated {
                self.updateViewSizeOnLayout = (true, self.isRotating() ? self.orientationChangeDuration : 0.0)
                self.setNeedsLayout()
            }
        }
    }
    
    public override var bounds: CGRect {
        get {
            return super.frame
        }
        set(value) {
            let sizeUpdated = super.bounds.size != value.size
            super.bounds = value
            
            if sizeUpdated {
                self.updateViewSizeOnLayout = (true, self.isRotating() ? self.orientationChangeDuration : 0.0)
                self.setNeedsLayout()
            }
        }
    }
    
    private var _rootViewController: WindowContentController?
    public var viewController: WindowContentController? {
        get {
            return _rootViewController
        }
        set(value) {
            self._rootViewController?.view.removeFromSuperview()
            self._rootViewController = value
            self._rootViewController?.view.frame = self.bounds
            self._rootViewController?.setParentLayout(ViewControllerLayout(size: self.bounds.size, insets: UIEdgeInsets(), inputViewHeight: 0.0, statusBarHeight: 0.0), duration: 0.0, curve: 0)
            
            if let view = self._rootViewController?.view {
                self.addSubview(view)
            }
            
            self.updateStatusBars()
        }
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        if self.updateViewSizeOnLayout.0 {
            self.updateViewSizeOnLayout.0 = false
            
            self._rootViewController?.setParentLayout(ViewControllerLayout(size: self.bounds.size, insets: UIEdgeInsets(), inputViewHeight: 0.0, statusBarHeight: 0.0), duration: updateViewSizeOnLayout.1, curve: 0)
        }
    }
    
    var postUpdateToInterfaceOrientationBlocks: [(Void) -> Void] = []
    
    override public func _update(toInterfaceOrientation arg1: Int32, duration arg2: Double, force arg3: Bool) {
        self.isUpdatingOrientationLayout = true
        super._update(toInterfaceOrientation: arg1, duration: arg2, force: arg3)
        self.isUpdatingOrientationLayout = false
        
        let blocks = self.postUpdateToInterfaceOrientationBlocks
        self.postUpdateToInterfaceOrientationBlocks = []
        for f in blocks {
            f()
        }
    }
    
    public func addPostUpdateToInterfaceOrientationBlock(f: (Void) -> Void) {
        postUpdateToInterfaceOrientationBlocks.append(f)
    }
    
    func updateStatusBars() {
        self.statusBarManager.surfaces = (self._rootViewController as? StatusBarSurfaceProvider)?.statusBarSurfaces() ?? []
    }
}
