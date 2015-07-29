import UIKit
import AsyncDisplayKit

public class NavigationButtonNode: ASTextNode {
    private func fontForCurrentState() -> UIFont {
        return self.bold ? UIFont.boldSystemFontOfSize(17.0) : UIFont.systemFontOfSize(17.0)
    }
    
    private func attributesForCurrentState() -> [String : AnyObject] {
        return [
            NSFontAttributeName: self.fontForCurrentState(),
            NSForegroundColorAttributeName: self.enabled ? UIColor.blueColor() : UIColor.grayColor()
        ]
    }
    
    private var _text: String?
    public var text: String {
        get {
            return _text ?? ""
        }
        set(value) {
            _text = value
            
            self.attributedString = NSAttributedString(string: text, attributes: self.attributesForCurrentState())
        }
    }
    
    private var _bold: Bool = false
    public var bold: Bool {
        get {
            return _bold
        }
        set(value) {
            if _bold != value {
                _bold = value
                
                self.attributedString = NSAttributedString(string: text, attributes: self.attributesForCurrentState())
            }
        }
    }
    
    private var touchCount = 0
    public var pressed: () -> () = {}
    
    public override init() {
        super.init()
        
        self.userInteractionEnabled = true
        self.exclusiveTouch = true
        self.hitTestSlop = UIEdgeInsets(top: -16.0, left: -10.0, bottom: -16.0, right: -10.0)
        self.displaysAsynchronously = false
    }
    
    private func touchInsideApparentBounds(touch: UITouch) -> Bool {
        var apparentBounds = self.bounds
        let hitTestSlop = self.hitTestSlop
        apparentBounds.origin.x += hitTestSlop.left
        apparentBounds.size.width -= hitTestSlop.left + hitTestSlop.right
        apparentBounds.origin.y += hitTestSlop.top
        apparentBounds.size.height -= hitTestSlop.top + hitTestSlop.bottom
        
        return CGRectContainsPoint(apparentBounds, touch.locationInView(self.view))
    }
    
    public override func touchesBegan(touches: Set<NSObject>!, withEvent event: UIEvent!) {
        super.touchesBegan(touches, withEvent: event)
        self.touchCount += touches.count
        self.updateHighlightedState(true, animated: false)
    }
    
    public override func touchesMoved(touches: Set<NSObject>!, withEvent event: UIEvent!) {
        super.touchesMoved(touches, withEvent: event)
        
        self.updateHighlightedState(self.touchInsideApparentBounds(touches.first as! UITouch), animated: true)
    }
    
    public override func touchesEnded(touches: Set<NSObject>!, withEvent event: UIEvent!) {
        super.touchesEnded(touches, withEvent: event)
        self.updateHighlightedState(false, animated: false)
        
        let previousTouchCount = self.touchCount
        self.touchCount = max(0, self.touchCount - touches.count)
        
        if previousTouchCount != 0 && self.touchCount == 0 && self.enabled && self.touchInsideApparentBounds(touches.first as! UITouch) {
            self.pressed()
        }
    }
    
    public override func touchesCancelled(touches: Set<NSObject>!, withEvent event: UIEvent!) {
        super.touchesCancelled(touches, withEvent: event)
        
        self.touchCount = max(0, self.touchCount - touches.count)
        self.updateHighlightedState(false, animated: false)
    }
    
    private var _highlighted = false
    private func updateHighlightedState(highlighted: Bool, animated: Bool) {
        if _highlighted != highlighted {
            _highlighted = highlighted
            
            let alpha: CGFloat = !enabled ? 1.0 : (highlighted ? 0.4 : 1.0)
            
            if animated {
                UIView.animateWithDuration(0.3, delay: 0.0, options: UIViewAnimationOptions.BeginFromCurrentState, animations: { () -> Void in
                    self.alpha = alpha
                }, completion: nil)
            }
            else {
                self.alpha = alpha
            }
        }
    }
    
    public override var enabled: Bool {
        get {
            return super.enabled
        }
        set(value) {
            if self.enabled != value {
                super.enabled = value

                self.attributedString = NSAttributedString(string: text, attributes: self.attributesForCurrentState())
            }
        }
    }
}
