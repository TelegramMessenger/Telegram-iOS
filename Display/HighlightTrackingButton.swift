import UIKit

open class HighlightTrackingButton: UIButton {
    public var internalHighligthedChanged: (Bool) -> Void = { _ in }
    public var highligthedChanged: (Bool) -> Void = { _ in }
    
    open override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        self.highligthedChanged(true)
        self.internalHighligthedChanged(true)
        
        return super.beginTracking(touch, with: event)
    }
    
    open override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        self.highligthedChanged(false)
        self.internalHighligthedChanged(false)
        
        super.endTracking(touch, with: event)
    }
    
    open override func cancelTracking(with event: UIEvent?) {
        self.highligthedChanged(false)
        self.internalHighligthedChanged(false)
        
        super.cancelTracking(with: event)
    }
}
