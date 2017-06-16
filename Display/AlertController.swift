import Foundation
import AsyncDisplayKit

open class AlertController: ViewController {
    private var controllerNode: AlertControllerNode {
        return self.displayNode as! AlertControllerNode
    }
    
    private let contentNode: AlertContentNode
    
    public init(contentNode: AlertContentNode) {
        self.contentNode = contentNode
        
        super.init(navigationBarTheme: nil)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func loadDisplayNode() {
        self.displayNode = AlertControllerNode(contentNode: self.contentNode)
        self.displayNodeDidLoad()
        
        self.controllerNode.dismiss = { [weak self] in
            if let strongSelf = self {
                strongSelf.controllerNode.animateOut {
                    self?.dismiss()
                }
            }
        }
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.controllerNode.animateIn()
    }
    
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, transition: transition)
    }
    
    override open func dismiss(completion: (() -> Void)? = nil) {
        self.presentingViewController?.dismiss(animated: false, completion: completion)
    }
    
    public func dismissAnimated() {
        self.controllerNode.animateOut { [weak self] in
            self?.dismiss()
        }
    }
}
