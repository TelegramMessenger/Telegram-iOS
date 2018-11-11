import Foundation
import AsyncDisplayKit

public final class AlertControllerTheme {
    public let backgroundColor: UIColor
    public let separatorColor: UIColor
    public let highlightedItemColor: UIColor
    public let primaryColor: UIColor
    public let secondaryColor: UIColor
    public let accentColor: UIColor
    public let destructiveColor: UIColor
    
    public init(backgroundColor: UIColor, separatorColor: UIColor, highlightedItemColor: UIColor, primaryColor: UIColor, secondaryColor: UIColor, accentColor: UIColor, destructiveColor: UIColor) {
        self.backgroundColor = backgroundColor
        self.separatorColor = separatorColor
        self.highlightedItemColor = highlightedItemColor
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.accentColor = accentColor
        self.destructiveColor = destructiveColor
    }
}

open class AlertController: ViewController {
    private var controllerNode: AlertControllerNode {
        return self.displayNode as! AlertControllerNode
    }
    
    private let theme: AlertControllerTheme
    private let contentNode: AlertContentNode
    private let allowInputInset: Bool
    
    public init(theme: AlertControllerTheme, contentNode: AlertContentNode, allowInputInset: Bool = true) {
        self.theme = theme
        self.contentNode = contentNode
        self.allowInputInset = allowInputInset
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func loadDisplayNode() {
        self.displayNode = AlertControllerNode(contentNode: self.contentNode, theme: self.theme, allowInputInset: self.allowInputInset)
        self.displayNodeDidLoad()
        
        self.controllerNode.dismiss = { [weak self] in
            if let strongSelf = self, strongSelf.contentNode.dismissOnOutsideTap {
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
