import Foundation
import UIKit
import AsyncDisplayKit

open class UITracingLayerView: UIView {
    private var scheduledWithLayout: (() -> Void)?
    
    open func schedule(layout f: @escaping () -> Void) {
        self.scheduledWithLayout = f
        self.setNeedsLayout()
    }
    
    override open var autoresizingMask: UIView.AutoresizingMask {
        get {
            return []
        } set(value) {
        }
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        
        if let scheduledWithLayout = self.scheduledWithLayout {
            self.scheduledWithLayout = nil
            scheduledWithLayout()
        }
    }
}
