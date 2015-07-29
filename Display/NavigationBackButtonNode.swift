import UIKit
import AsyncDisplayKit

public class NavigationBackButtonNode: ASControlNode {
    private func fontForCurrentState() -> UIFont {
        return UIFont.systemFontOfSize(17.0)
    }
    
    private func attributesForCurrentState() -> [String : AnyObject] {
        return [
            NSFontAttributeName: self.fontForCurrentState(),
            NSForegroundColorAttributeName: self.enabled ? UIColor.blueColor() : UIColor.grayColor()
        ]
    }
    
    var suspendLayout = false
    
    let arrow: ASDisplayNode
    let label: ASTextNode
    
    private let arrowSpacing: CGFloat = 4.0
    
    private var _text: String = ""
    var text: String {
        get {
            return self._text
        }
        set(value) {
            self._text = value
            self.label.attributedString = NSAttributedString(string: text, attributes: self.attributesForCurrentState())
            self.invalidateCalculatedLayout()
        }
    }
    
    private var touchCount = 0
    var pressed: () -> () = {}
    
    override init() {
        self.arrow = ASDisplayNode()
        self.label = ASTextNode()
        
        super.init()
        
        self.userInteractionEnabled = true
        self.exclusiveTouch = true
        self.hitTestSlop = UIEdgeInsets(top: -16.0, left: -10.0, bottom: -16.0, right: -10.0)
        self.displaysAsynchronously = false
        
        self.arrow.displaysAsynchronously = false
        self.label.displaysAsynchronously = false
        
        self.addSubnode(self.arrow)
        let arrowImage = UIImage(named: "NavigationBackArrowLight", inBundle: NSBundle(forClass: NavigationBackButtonNode.self), compatibleWithTraitCollection: nil)
        self.arrow.contents = arrowImage?.CGImage
        self.arrow.frame = CGRect(origin: CGPoint(), size: arrowImage?.size ?? CGSize())
        
        self.addSubnode(self.label)
    }
    
    public override func calculateSizeThatFits(constrainedSize: CGSize) -> CGSize {
        self.label.measure(CGSize(width: max(0.0, constrainedSize.width - self.arrow.frame.size.width - self.arrowSpacing), height: constrainedSize.height))
        
        return CGSize(width: self.arrow.frame.size.width + self.arrowSpacing + self.label.calculatedSize.width, height: max(self.arrow.frame.size.height, self.label.calculatedSize.height))
    }
    
    var labelFrame: CGRect {
        get {
            return CGRect(x: self.arrow.frame.size.width + self.arrowSpacing, y: floor((self.frame.size.height - self.label.calculatedSize.height) / 2.0), width: self.label.calculatedSize.width, height: self.label.calculatedSize.height)
        }
    }
    
    public override func layout() {
        super.layout()
        
        if self.suspendLayout {
            return
        }
        
        self.arrow.frame = CGRect(x: 0.0, y: floor((self.frame.size.height - arrow.frame.size.height) / 2.0), width: self.arrow.frame.size.width, height: self.arrow.frame.size.height)
        
        self.label.frame = self.labelFrame
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
}
