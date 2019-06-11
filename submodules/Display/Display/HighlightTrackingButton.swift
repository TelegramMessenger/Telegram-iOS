import UIKit

open class HighlightTrackingButton: UIButton {
    private var internalHighlighted = false
    
    public var internalHighligthedChanged: (Bool) -> Void = { _ in }
    public var highligthedChanged: (Bool) -> Void = { _ in }
    
    open override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        if !self.internalHighlighted {
            self.internalHighlighted = true
            self.highligthedChanged(true)
            self.internalHighligthedChanged(true)
        }
        
        return super.beginTracking(touch, with: event)
    }
    
    open override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        if self.internalHighlighted {
            self.internalHighlighted = false
            self.highligthedChanged(false)
            self.internalHighligthedChanged(false)
        }
        
        super.endTracking(touch, with: event)
    }
    
    open override func cancelTracking(with event: UIEvent?) {
        if self.internalHighlighted {
            self.internalHighlighted = false
            self.highligthedChanged(false)
            self.internalHighligthedChanged(false)
        }
        
        super.cancelTracking(with: event)
    }
    
    open override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if self.internalHighlighted {
            self.internalHighlighted = false
            self.highligthedChanged(false)
            self.internalHighligthedChanged(false)
        }
        
        super.touchesCancelled(touches, with: event)
    }
}
