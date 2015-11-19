import Foundation
import AsyncDisplayKit

public class WindowRootViewController: UIViewController {
    public override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .Default
    }
    
    public override func prefersStatusBarHidden() -> Bool {
        return false
    }
}

public struct ViewControllerLayout: Equatable {
    public let size: CGSize
    public let insets: UIEdgeInsets
    public let inputViewHeight: CGFloat
}

public protocol WindowContentController {
    func setParentLayout(layout: ViewControllerLayout, duration: NSTimeInterval, curve: UInt)
    var view: UIView! { get }
}

public func animateRotation(view: UIView?, toFrame: CGRect, duration: NSTimeInterval) {
    if let view = view {
        UIView.animateWithDuration(duration, animations: { () -> Void in
            view.frame = toFrame
        })
    }
}

public func animateRotation(view: ASDisplayNode?, toFrame: CGRect, duration: NSTimeInterval) {
    if let view = view {
        CALayer.beginRecordingChanges()
        UIView.animateWithDuration(duration, animations: { () -> Void in
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
                if !CGRectEqualToRect(state.startBounds, state.endBounds) {
                    let boundsAnimation = CABasicAnimation(keyPath: "bounds")
                    boundsAnimation.fromValue = NSValue(CGRect: state.startBounds)
                    boundsAnimation.toValue = NSValue(CGRect: state.endBounds)
                    boundsAnimation.duration = duration
                    boundsAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
                    boundsAnimation.removedOnCompletion = true
                    boundsAnimation.fillMode = kCAFillModeForwards
                    boundsAnimation.speed = speed
                    layer.addAnimation(boundsAnimation, forKey: "_rotationBounds")
                }
                
                if !CGPointEqualToPoint(state.startPosition, state.endPosition) {
                    let positionAnimation = CABasicAnimation(keyPath: "position")
                    positionAnimation.fromValue = NSValue(CGPoint: state.startPosition)
                    positionAnimation.toValue = NSValue(CGPoint: state.endPosition)
                    positionAnimation.duration = duration
                    positionAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
                    positionAnimation.removedOnCompletion = true
                    positionAnimation.fillMode = kCAFillModeForwards
                    positionAnimation.speed = speed
                    layer.addAnimation(positionAnimation, forKey: "_rotationPosition")
                }
            }
        }
    }
}

public class Window: UIWindow {
    //public let textField: UITextField
    
    private var updateViewSizeOnLayout: (Bool, NSTimeInterval) = (false, 0.0)
    public var isUpdatingOrientationLayout = false
    
    private let orientationChangeDuration: NSTimeInterval = {
        UIDevice.currentDevice().userInterfaceIdiom == .Pad ? 0.4 : 0.3
    }()
    
    public convenience init() {
        self.init(frame: UIScreen.mainScreen().bounds)
    }
    
    public override init(frame: CGRect) {
        //self.textField = UITextField(frame: CGRect(x: -110.0, y: 0.0, width: 100.0, height: 50.0))
        
        super.init(frame: frame)
        
        //self.addSubview(self.textField)
        
        super.rootViewController = WindowRootViewController()
    }
    
    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func hitTest(point: CGPoint, withEvent event: UIEvent?) -> UIView? {
        return self.viewController?.view.hitTest(point, withEvent: event)
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
            self._rootViewController?.setParentLayout(ViewControllerLayout(size: self.bounds.size, insets: UIEdgeInsets(), inputViewHeight: 0.0), duration: 0.0, curve: 0)
            
            if let view = self._rootViewController?.view {
                self.addSubview(view)
            }
        }
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        if self.updateViewSizeOnLayout.0 {
            self.updateViewSizeOnLayout.0 = false
            
            self._rootViewController?.setParentLayout(ViewControllerLayout(size: self.bounds.size, insets: UIEdgeInsets(), inputViewHeight: 0.0), duration: updateViewSizeOnLayout.1, curve: 0)
        }
    }
    
    var postUpdateToInterfaceOrientationBlocks: [Void -> Void] = []
    
    override public func _updateToInterfaceOrientation(arg1: Int32, duration arg2: Double, force arg3: Bool) {
        self.isUpdatingOrientationLayout = true
        super._updateToInterfaceOrientation(arg1, duration: arg2, force: arg3)
        self.isUpdatingOrientationLayout = false
        
        let blocks = self.postUpdateToInterfaceOrientationBlocks
        self.postUpdateToInterfaceOrientationBlocks = []
        for f in blocks {
            f()
        }
    }
    
    public func addPostUpdateToInterfaceOrientationBlock(f: Void -> Void) {
        postUpdateToInterfaceOrientationBlocks.append(f)
    }
}
