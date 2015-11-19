import Foundation
import UIKit
import AsyncDisplayKit

public class TabBarController: ViewController {
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
    
    private var layout: ViewControllerLayout?
    private var currentController: ViewController?
    
    override public init() {
        super.init()
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = TabBarControllerNode()
        
        self.updateSelectedIndex()
    }
    
    private func updateSelectedIndex() {
        if !self.isNodeLoaded {
            return
        }
        
        if let currentController = self.currentController {
            currentController.willMoveToParentViewController(nil)
            self.tabBarControllerNode.currentControllerView = nil
            currentController.removeFromParentViewController()
            currentController.didMoveToParentViewController(nil)
            
            self.currentController = nil
        }
        
        if self._selectedIndex < self.controllers.count {
            self.currentController = self.controllers[self._selectedIndex]
        }
        
        if let currentController = self.currentController {
            currentController.willMoveToParentViewController(self)
            if let layout = self.layout {
                currentController.view.frame = CGRect(origin: CGPoint(), size: layout.size)
                
                currentController.setParentLayout(self.childControllerLayoutForLayout(layout), duration: 0.0, curve: 0)
            }
            self.tabBarControllerNode.currentControllerView = currentController.view
            self.addChildViewController(currentController)
            currentController.didMoveToParentViewController(self)
        }
    }
    
    private func childControllerLayoutForLayout(layout: ViewControllerLayout) -> ViewControllerLayout {
        var insets = layout.insets
        insets.bottom += 49.0
        return ViewControllerLayout(size: layout.size, insets: insets, inputViewHeight: layout.inputViewHeight)
    }
    
    override public func updateLayout(layout: ViewControllerLayout, previousLayout: ViewControllerLayout?, duration: Double, curve: UInt) {
        super.updateLayout(layout, previousLayout: previousLayout, duration: duration, curve: curve)
        
        self.tabBarControllerNode.updateLayout(layout, previousLayout: previousLayout, duration: duration, curve: curve)
        
        self.layout = layout
        if let currentController = self.currentController {
            currentController.view.frame = CGRect(origin: CGPoint(), size: layout.size)
            currentController.setParentLayout(self.childControllerLayoutForLayout(layout), duration: duration, curve: curve)
        }
    }
}
