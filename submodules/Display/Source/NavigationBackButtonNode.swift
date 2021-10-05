import UIKit
import AsyncDisplayKit
import AppBundle

public class NavigationBackButtonNode: ASControlNode {
    private func fontForCurrentState() -> UIFont {
        return UIFont.systemFont(ofSize: 17.0)
    }
    
    private func attributesForCurrentState() -> [NSAttributedString.Key : AnyObject] {
        return [
            NSAttributedString.Key.font: self.fontForCurrentState(),
            NSAttributedString.Key.foregroundColor: self.isEnabled ? self.color : self.disabledColor
        ]
    }
    
    let arrow: ASDisplayNode
    let label: ImmediateTextNode
    
    private let arrowSpacing: CGFloat = 4.0
    
    private var _text: String = ""
    public var text: String {
        get {
            return self._text
        }
        set(value) {
            self._text = value
            self.label.attributedText = NSAttributedString(string: text, attributes: self.attributesForCurrentState())
            self.invalidateCalculatedLayout()
        }
    }
    
    public var color: UIColor = UIColor(rgb: 0x007aff) {
        didSet {
            self.label.attributedText = NSAttributedString(string: self._text, attributes: self.attributesForCurrentState())
        }
    }
    
    public var disabledColor: UIColor = UIColor(rgb: 0xd0d0d0) {
        didSet {
            self.label.attributedText = NSAttributedString(string: self._text, attributes: self.attributesForCurrentState())
        }
    }
    
    private var touchCount = 0
    var pressed: () -> () = {}
    
    override public init() {
        self.arrow = ASDisplayNode()
        self.label = ImmediateTextNode()
        
        super.init()
        
        self.isUserInteractionEnabled = true
        self.isExclusiveTouch = true
        self.hitTestSlop = UIEdgeInsets(top: -16.0, left: -10.0, bottom: -16.0, right: -10.0)
        self.displaysAsynchronously = false
        
        self.arrow.displaysAsynchronously = false
        self.label.displaysAsynchronously = false
        
        self.addSubnode(self.arrow)
        let arrowImage = UIImage(named: "NavigationBackArrowLight", in: getAppBundle(), compatibleWith: nil)?.precomposed()
        self.arrow.contents = arrowImage?.cgImage
        self.arrow.frame = CGRect(origin: CGPoint(), size: arrowImage?.size ?? CGSize())
        
        self.addSubnode(self.label)
    }
    
    public override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let _ = self.label.updateLayout(CGSize(width: max(0.0, constrainedSize.width - self.arrow.frame.size.width - self.arrowSpacing), height: constrainedSize.height))
        
        return CGSize(width: self.arrow.frame.size.width + self.arrowSpacing + self.label.calculatedSize.width, height: max(self.arrow.frame.size.height, self.label.calculatedSize.height))
    }
    
    var labelFrame: CGRect {
        get {
            return CGRect(x: self.arrow.frame.size.width + self.arrowSpacing, y: floor((self.frame.size.height - self.label.calculatedSize.height) / 2.0), width: self.label.calculatedSize.width, height: self.label.calculatedSize.height)
        }
    }
    
    public override func layout() {
        super.layout()
        
        self.arrow.frame = CGRect(x: 0.0, y: floor((self.frame.size.height - arrow.frame.size.height) / 2.0), width: self.arrow.frame.size.width, height: self.arrow.frame.size.height)
        
        self.label.frame = self.labelFrame
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
            
            if animated {
                UIView.animate(withDuration: 0.3, delay: 0.0, options: UIView.AnimationOptions.beginFromCurrentState, animations: { () -> Void in
                    self.alpha = alpha
                    }, completion: nil)
            }
            else {
                self.alpha = alpha
            }
        }
    }
}
