import UIKit
import AsyncDisplayKit

public class NavigationButtonNode: ASTextNode {
    private func fontForCurrentState() -> UIFont {
        return self.bold ? UIFont.boldSystemFont(ofSize: 17.0) : UIFont.systemFont(ofSize: 17.0)
    }
    
    private func attributesForCurrentState() -> [String : AnyObject] {
        return [
            NSFontAttributeName: self.fontForCurrentState(),
            NSForegroundColorAttributeName: self.isEnabled ? self.color : UIColor.gray()
        ]
    }
    
    private var _text: String?
    public var text: String {
        get {
            return _text ?? ""
        }
        set(value) {
            _text = value
            
            self.attributedString = AttributedString(string: text, attributes: self.attributesForCurrentState())
        }
    }
    
    public var color: UIColor = UIColor(0x1195f2) {
        didSet {
            if let text = self._text {
                self.attributedString = AttributedString(string: text, attributes: self.attributesForCurrentState())
            }
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
                
                self.attributedString = AttributedString(string: text, attributes: self.attributesForCurrentState())
            }
        }
    }
    
    private var touchCount = 0
    public var pressed: () -> () = { }
    public var highlightChanged: (Bool) -> () = { _ in }
    
    public override init() {
        super.init()
        
        self.isUserInteractionEnabled = true
        self.isExclusiveTouch = true
        self.hitTestSlop = UIEdgeInsets(top: -16.0, left: -10.0, bottom: -16.0, right: -10.0)
        self.displaysAsynchronously = false
    }
    
    private func touchInsideApparentBounds(_ touch: UITouch) -> Bool {
        var apparentBounds = self.bounds
        let hitTestSlop = self.hitTestSlop
        apparentBounds.origin.x += hitTestSlop.left
        apparentBounds.size.width -= hitTestSlop.left + hitTestSlop.right
        apparentBounds.origin.y += hitTestSlop.top
        apparentBounds.size.height -= hitTestSlop.top + hitTestSlop.bottom
        
        return apparentBounds.contains(touch.location(in: self.view))
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        self.touchCount += touches.count
        self.updateHighlightedState(true, animated: false)
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        self.updateHighlightedState(self.touchInsideApparentBounds(touches.first!), animated: true)
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        self.updateHighlightedState(false, animated: false)
        
        let previousTouchCount = self.touchCount
        self.touchCount = max(0, self.touchCount - touches.count)
        
        if previousTouchCount != 0 && self.touchCount == 0 && self.isEnabled && self.touchInsideApparentBounds(touches.first!) {
            self.pressed()
        }
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        
        self.touchCount = max(0, self.touchCount - (touches?.count ?? 0))
        self.updateHighlightedState(false, animated: false)
    }
    
    private var _highlighted = false
    private func updateHighlightedState(_ highlighted: Bool, animated: Bool) {
        if _highlighted != highlighted {
            _highlighted = highlighted
            
            let alpha: CGFloat = !self.isEnabled ? 1.0 : (highlighted ? 0.4 : 1.0)
            
            /*if animated {
                UIView.animate(withDuration: 0.3, delay: 0.0, options: UIViewAnimationOptions.beginFromCurrentState, animations: { () -> Void in
                    self.alpha = alpha
                }, completion: nil)
            }
            else {*/
                self.alpha = alpha
                self.highlightChanged(highlighted)
            //}
        }
    }
    
    public override var isEnabled: Bool {
        get {
            return super.isEnabled
        }
        set(value) {
            if self.isEnabled != value {
                super.isEnabled = value

                self.attributedString = AttributedString(string: text, attributes: self.attributesForCurrentState())
            }
        }
    }
}
