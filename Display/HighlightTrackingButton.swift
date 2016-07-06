import UIKit

public class HighlightTrackingButton: UIButton {
    public var highligthedChanged: (Bool) -> Void = { _ in }
    
    public override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        self.highligthedChanged(true)
        
        return super.beginTracking(touch, with: event)
    }
    
    public override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        self.highligthedChanged(false)
        
        super.endTracking(touch, with: event)
    }
    
    public override func cancelTracking(with event: UIEvent?) {
        self.highligthedChanged(false)
        
        super.cancelTracking(with: event)
    }
}
