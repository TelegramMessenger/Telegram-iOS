import Foundation
import UIKit
import AsyncDisplayKit

public protocol ActionSheetGroupOverlayNode: ASDisplayNode {
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition)
}

open class ActionSheetController: ViewController, PresentableController, StandalonePresentableController {
    private var actionSheetNode: ActionSheetControllerNode {
        return self.displayNode as! ActionSheetControllerNode
    }
    
    public var theme: ActionSheetControllerTheme {
        didSet {
            if oldValue != self.theme {
                self.actionSheetNode.theme = self.theme
            }
        }
    }
    
    private var groups: [ActionSheetItemGroup] = []
    
    private var isDismissed: Bool = false
    
    public var dismissed: ((Bool) -> Void)?
    
    private var allowInputInset: Bool
    
    public init(theme: ActionSheetControllerTheme, allowInputInset: Bool = false) {
        self.theme = theme
        self.allowInputInset = allowInputInset
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
        self.blocksBackgroundWhenInOverlay = true
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func dismissAnimated() {
        if !self.isDismissed {
            self.isDismissed = true
            self.actionSheetNode.animateOut(cancelled: false)
        }
    }
    
    open override func loadDisplayNode() {
        self.displayNode = ActionSheetControllerNode(theme: self.theme, allowInputInset: self.allowInputInset)
        self.displayNodeDidLoad()
        
        self.actionSheetNode.dismiss = { [weak self] cancelled in
            self?.dismissed?(cancelled)
            self?.presentingViewController?.dismiss(animated: false)
        }
        
        self.actionSheetNode.setGroups(self.groups)
    }
    
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.actionSheetNode.containerLayoutUpdated(layout, transition: transition)
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.viewDidAppear(completion: {})
    }
    
    public func viewDidAppear(completion: @escaping () -> Void) {
        self.actionSheetNode.animateIn(completion: completion)
    }
    
    public func setItemGroups(_ groups: [ActionSheetItemGroup]) {
        self.groups = groups
        if self.isViewLoaded {
            self.actionSheetNode.setGroups(groups)
        }
    }
    
    public func updateItem(groupIndex: Int, itemIndex: Int, _ f: (ActionSheetItem) -> ActionSheetItem) {
        if self.isViewLoaded {
            self.actionSheetNode.updateItem(groupIndex: groupIndex, itemIndex: itemIndex, f)
        }
    }
    
    public func setItemGroupOverlayNode(groupIndex: Int, node: ActionSheetGroupOverlayNode) {
        if self.isViewLoaded {
            self.actionSheetNode.setItemGroupOverlayNode(groupIndex: groupIndex, node: node)
        }
    }
}
