import Foundation
import AsyncDisplayKit
import Display

private final class CheckNodeParameters: NSObject {
    let progress: CGFloat

    init(progress: CGFloat) {
        self.progress = progress
    }
}

class ModernCheckNode: ASDisplayNode {
    private var displayProgress: CGFloat = 0.0
    
    func setSelected(_ selected: Bool, animated: Bool) {
        if animated {
            
        } else {
            self.displayProgress = selected ? 1.0 : 0.0
        }
    }

    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return CheckNodeParameters(progress: self.displayProgress)
    }
    
    @objc override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        
    }
    
}
