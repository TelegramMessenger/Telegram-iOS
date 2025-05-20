import Foundation
import UIKit
import AsyncDisplayKit

final class ChatControllerTitlePanelNodeContainer: ASDisplayNode {
    var hitTestExcludeInsets = UIEdgeInsets()
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if point.x < self.hitTestExcludeInsets.left {
            return nil
        }
        
        for subview in self.view.subviews {
            if let result = subview.hitTest(self.view.convert(point, to: subview), with: event) {
                return result
            }
        }
        return nil
    }
}
