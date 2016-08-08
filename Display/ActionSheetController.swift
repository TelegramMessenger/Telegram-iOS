import Foundation

public class ActionSheetController: ViewController {
    private var actionSheetNode: ActionSheetControllerNode {
        return self.displayNode as! ActionSheetControllerNode
    }
    
    private var groups: [ActionSheetItemGroup] = []
    
    public func dismissAnimated() {
        self.actionSheetNode.animateOut()
    }
    
    public override func loadDisplayNode() {
        self.displayNode = ActionSheetControllerNode()
        self.displayNodeDidLoad()
        self.navigationBar.isHidden = true
        
        self.actionSheetNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: false)
        }
        
        self.actionSheetNode.setGroups(self.groups)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.actionSheetNode.containerLayoutUpdated(layout, transition: transition)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.actionSheetNode.animateIn()
    }
    
    public func setItemGroups(_ groups: [ActionSheetItemGroup]) {
        self.groups = groups
        if self.isViewLoaded {
            self.actionSheetNode.setGroups(groups)
        }
    }
}
