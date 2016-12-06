import Foundation
import UIKit
import AsyncDisplayKit

open class HighlightableButton: HighlightTrackingButton {
    override public init(frame: CGRect) {
        super.init(frame: frame)
        
        self.adjustsImageWhenHighlighted = false
        self.adjustsImageWhenDisabled = false
        self.internalHighligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.layer.removeAnimation(forKey: "opacity")
                    strongSelf.alpha = 0.4
                } else {
                    strongSelf.alpha = 1.0
                    strongSelf.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

open class HighlightTrackingButtonNode: ASButtonNode {
    public var highligthedChanged: (Bool) -> Void = { _ in }
    
    open override func beginTracking(with touch: UITouch, with event: UIEvent?) -> Bool {
        self.highligthedChanged(true)
        
        return super.beginTracking(with: touch, with: event)
    }
    
    open override func endTracking(with touch: UITouch?, with event: UIEvent?) {
        self.highligthedChanged(false)
        
        super.endTracking(with: touch, with: event)
    }
    
    open override func cancelTracking(with event: UIEvent?) {
        self.highligthedChanged(false)
        
        super.cancelTracking(with: event)
    }
}

open class HighlightableButtonNode: HighlightTrackingButtonNode {
    override public init() {
        super.init()
        
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.layer.removeAnimation(forKey: "opacity")
                    strongSelf.alpha = 0.4
                } else {
                    strongSelf.alpha = 1.0
                    strongSelf.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
    }
}
