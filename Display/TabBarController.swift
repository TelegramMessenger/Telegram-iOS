import Foundation
import UIKit
import AsyncDisplayKit

open class TabBarController: ViewController {
    private var containerLayout = ContainerViewLayout()
    
    private var tabBarControllerNode: TabBarControllerNode {
        get {
            return super.displayNode as! TabBarControllerNode
        }
    }
    
    public var controllers: [ViewController] = [] {
        didSet {
            self.tabBarControllerNode.tabBarNode.tabBarItems = self.controllers.map({ $0.tabBarItem })
            
            if oldValue.count == 0 && self.controllers.count != 0 {
                self.updateSelectedIndex()
            }
        }
    }
    
    private var _selectedIndex: Int = 1
    public var selectedIndex: Int {
        get {
            return _selectedIndex
        } set(value) {
            let index = max(0, min(self.controllers.count - 1, value))
            if _selectedIndex != index {
                _selectedIndex = index
                
                self.updateSelectedIndex()
            }
        }
    }
    
    var currentController: ViewController?
    
    override public init(navigationBar: NavigationBar = NavigationBar()) {
        super.init(navigationBar: navigationBar)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func loadDisplayNode() {
        self.displayNode = TabBarControllerNode(itemSelected: { [weak self] index in
            if let strongSelf = self {
                strongSelf.selectedIndex = index
            }
        })
        
        self.updateSelectedIndex()
        self.displayNodeDidLoad()
    }
    
    private func updateSelectedIndex() {
        if !self.isNodeLoaded {
            return
        }
        
        self.tabBarControllerNode.tabBarNode.selectedIndex = self.selectedIndex
        
        if let currentController = self.currentController {
            currentController.willMove(toParentViewController: nil)
            self.tabBarControllerNode.currentControllerView = nil
            currentController.removeFromParentViewController()
            currentController.didMove(toParentViewController: nil)
            
            self.currentController = nil
        }
        
        if self._selectedIndex < self.controllers.count {
            self.currentController = self.controllers[self._selectedIndex]
        }
        
        var displayNavigationBar = false
        if let currentController = self.currentController {
            currentController.willMove(toParentViewController: self)
            currentController.containerLayoutUpdated(self.containerLayout.addedInsets(insets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 49.0, right: 0.0)), transition: .immediate)
            self.tabBarControllerNode.currentControllerView = currentController.view
            currentController.navigationBar.isHidden = true
            self.addChildViewController(currentController)
            currentController.didMove(toParentViewController: self)
            
            self.navigationItem.title = currentController.navigationItem.title
            self.navigationItem.leftBarButtonItem = currentController.navigationItem.leftBarButtonItem
            self.navigationItem.rightBarButtonItem = currentController.navigationItem.rightBarButtonItem
            displayNavigationBar = currentController.displayNavigationBar
        } else {
            self.navigationItem.title = nil
            self.navigationItem.leftBarButtonItem = nil
            self.navigationItem.rightBarButtonItem = nil
            displayNavigationBar = false
        }
        if self.displayNavigationBar != displayNavigationBar {
            self.setDisplayNavigationBar(displayNavigationBar)
        }
    }
    
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.containerLayout = layout
        
        self.tabBarControllerNode.containerLayoutUpdated(layout, transition: transition)
        
        if let currentController = self.currentController {
            currentController.view.frame = CGRect(origin: CGPoint(), size: layout.size)
            
            currentController.containerLayoutUpdated(layout.addedInsets(insets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 49.0, right: 0.0)), transition: transition)
        }
    }
}
