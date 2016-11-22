import Foundation
import UIKit

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
