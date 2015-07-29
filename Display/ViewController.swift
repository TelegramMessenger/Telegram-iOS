import Foundation
import UIKit
import AsyncDisplayKit

@objc public class ViewController: UIViewController, WindowContentController {
    private var _displayNode: ASDisplayNode?
    public var displayNode: ASDisplayNode {
        get {
            if let value = self._displayNode {
                return value
            }
            else {
                self.loadDisplayNode()
                if self._displayNode == nil {
                    fatalError("displayNode should be initialized after loadDisplayNode()")
                }
                return self._displayNode!
            }
        }
        set(value) {
            self._displayNode = value
        }
    }
    
    public init() {
        super.init(nibName: nil, bundle: nil)
        
        self.automaticallyAdjustsScrollViewInsets = false
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func loadView() {
        self.view = self.displayNode.view
    }
    
    public func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
    }
    
    public func setViewSize(toSize: CGSize, duration: NSTimeInterval) {
        if duration > DBL_EPSILON {
            animateRotation(self.displayNode, toFrame: CGRect(x: 0.0, y: 0.0, width: toSize.width, height: toSize.height), duration: duration)
        }
        else {
            self.displayNode.frame = CGRect(x: 0.0, y: 0.0, width: toSize.width, height: toSize.height)
        }
    }
}
