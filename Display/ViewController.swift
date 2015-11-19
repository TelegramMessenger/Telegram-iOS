import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

public func ==(lhs: ViewControllerLayout, rhs: ViewControllerLayout) -> Bool {
    return lhs.size == rhs.size && lhs.insets == rhs.insets && lhs.inputViewHeight == rhs.inputViewHeight
}

@objc public class ViewController: UIViewController, WindowContentController {
    private var _displayNode: ASDisplayNode?
    public final var displayNode: ASDisplayNode {
        get {
            if let value = self._displayNode {
                return value
            }
            else {
                self.loadDisplayNode()
                if self._displayNode == nil {
                    fatalError("displayNode should be initialized after loadDisplayNode()")
                }
                return self._displayNode!
            }
        }
        set(value) {
            self._displayNode = value
        }
    }
    
    public final var isNodeLoaded: Bool {
        return self._displayNode != nil
    }
    
    private let _ready = Promise<Bool>(true)
    public var ready: Promise<Bool> {
        return self._ready
    }
    
    private var updateLayoutOnLayout: (ViewControllerLayout, NSTimeInterval, UInt)?
    private var layout: ViewControllerLayout?
    
    var keyboardFrameObserver: AnyObject?
    
    public init() {
        super.init(nibName: nil, bundle: nil)
        
        self.automaticallyAdjustsScrollViewInsets = false
        
        self.keyboardFrameObserver = NSNotificationCenter.defaultCenter().addObserverForName(UIKeyboardWillChangeFrameNotification, object: nil, queue: nil, usingBlock: { [weak self] notification in
            if let strongSelf = self, _ = strongSelf._displayNode {
                let keyboardFrame: CGRect = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.CGRectValue() ?? CGRect()
                let keyboardHeight = max(0.0, UIScreen.mainScreen().bounds.size.height - keyboardFrame.minY)
                let duration: Double = (notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.0
                let curve: UInt = (notification.userInfo?[UIKeyboardAnimationCurveUserInfoKey] as? NSNumber)?.unsignedIntegerValue ?? UInt(7 << 16)
                
                let previousLayout: ViewControllerLayout?
                var previousDurationAndCurve: (NSTimeInterval, UInt)?
                if let updateLayoutOnLayout = strongSelf.updateLayoutOnLayout {
                    previousLayout = updateLayoutOnLayout.0
                    previousDurationAndCurve = (updateLayoutOnLayout.1, updateLayoutOnLayout.2)
                } else{
                    previousLayout = strongSelf.layout
                }
                let layout = ViewControllerLayout(size: previousLayout?.size ?? CGSize(), insets: previousLayout?.insets ?? UIEdgeInsets(), inputViewHeight: keyboardHeight)
                let updated: Bool
                if let previousLayout = previousLayout {
                    updated = previousLayout != layout
                } else {
                    updated = true
                }
                if updated {
                    print("keyboard layout change: \(layout) rotating: \(strongSelf.view.window?.isRotating())")
                    
                    let durationAndCurve: (NSTimeInterval, UInt) = previousDurationAndCurve ?? (duration > DBL_EPSILON ? 0.5 : 0.0, curve)
                    strongSelf.updateLayoutOnLayout = (layout, durationAndCurve.0, durationAndCurve.1)
                    strongSelf.view.setNeedsLayout()
                }
            }
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let keyboardFrameObserver = keyboardFrameObserver {
            NSNotificationCenter.defaultCenter().removeObserver(keyboardFrameObserver)
        }
    }
    
    public override func loadView() {
        self.view = self.displayNode.view
    }
    
    public func loadDisplayNode() {
        
        self.displayNode = ASDisplayNode()
    }
    
    public func setParentLayout(layout: ViewControllerLayout, duration: NSTimeInterval, curve: UInt) {
        if self._displayNode == nil {
            self.loadDisplayNode()
        }
        let previousLayout: ViewControllerLayout?
        if let updateLayoutOnLayout = self.updateLayoutOnLayout {
            previousLayout = updateLayoutOnLayout.0
        } else {
            previousLayout = self.layout
        }
        
        let layout = ViewControllerLayout(size: layout.size, insets: layout.insets, inputViewHeight: previousLayout?.inputViewHeight ?? 0.0)
        let updated: Bool
        if let previousLayout = previousLayout {
            updated = previousLayout != layout
        } else {
            updated = true
        }
        if updated {
            if previousLayout == nil {
                self.layout = layout
                self.updateLayout(layout, previousLayout: previousLayout, duration: duration, curve: 0)
            } else {
                self.updateLayoutOnLayout = (layout, duration, 0)
                self.view.setNeedsLayout()
            }
        }
    }
    
    public func updateLayout(layout: ViewControllerLayout, previousLayout: ViewControllerLayout?, duration: Double, curve: UInt) {
    }
    
    override public func viewDidLayoutSubviews() {
        if let updateLayoutOnLayout = self.updateLayoutOnLayout {
            if !Window.isDeviceRotating() {
                if !((self.view.window as? Window)?.isUpdatingOrientationLayout ?? false) {
                    //print("\(self) apply inputHeight: \(updateLayoutOnLayout.0.inputViewHeight)")
                    let previousLayout = self.layout
                    self.layout = updateLayoutOnLayout.0
                    self.updateLayout(updateLayoutOnLayout.0, previousLayout: previousLayout, duration: updateLayoutOnLayout.1, curve: updateLayoutOnLayout.2)
                    
                    self.updateLayoutOnLayout = nil
                } else {
                    (self.view.window as? Window)?.addPostUpdateToInterfaceOrientationBlock({ [weak self] in
                        if let strongSelf = self {
                            strongSelf.view.setNeedsLayout()
                        }
                    })
                }
            } else {
                Window.addPostDeviceOrientationDidChangeBlock({ [weak self] in
                    if let strongSelf = self {
                        strongSelf.view.setNeedsLayout()
                    }
                })
            }
        }
    }
}
