import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

public final class TabBarControllerTheme {
    public let backgroundColor: UIColor
    public let tabBarBackgroundColor: UIColor
    public let tabBarSeparatorColor: UIColor
    public let tabBarTextColor: UIColor
    public let tabBarSelectedTextColor: UIColor
    public let tabBarBadgeBackgroundColor: UIColor
    public let tabBarBadgeStrokeColor: UIColor
    public let tabBarBadgeTextColor: UIColor
    
    public init(backgroundColor: UIColor, tabBarBackgroundColor: UIColor, tabBarSeparatorColor: UIColor, tabBarTextColor: UIColor, tabBarSelectedTextColor: UIColor, tabBarBadgeBackgroundColor: UIColor, tabBarBadgeStrokeColor: UIColor, tabBarBadgeTextColor: UIColor) {
        self.backgroundColor = backgroundColor
        self.tabBarBackgroundColor = tabBarBackgroundColor
        self.tabBarSeparatorColor = tabBarSeparatorColor
        self.tabBarTextColor = tabBarTextColor
        self.tabBarSelectedTextColor = tabBarSelectedTextColor
        self.tabBarBadgeBackgroundColor = tabBarBadgeBackgroundColor
        self.tabBarBadgeStrokeColor = tabBarBadgeStrokeColor
        self.tabBarBadgeTextColor = tabBarBadgeTextColor
    }
}

open class TabBarController: ViewController {
    private var containerLayout = ContainerViewLayout()
    
    private var tabBarControllerNode: TabBarControllerNode {
        get {
            return super.displayNode as! TabBarControllerNode
        }
    }
    
    private var controllers: [ViewController] = []
    
    private var _selectedIndex: Int?
    public var selectedIndex: Int {
        get {
            if let _selectedIndex = self._selectedIndex {
                return _selectedIndex
            } else {
                return 0
            }
        } set(value) {
            let index = max(0, min(self.controllers.count - 1, value))
            if _selectedIndex != index {
                _selectedIndex = index
                
                self.updateSelectedIndex()
            } else {
                if let controller = self.currentController {
                    controller.scrollToTop?()
                }
            }
        }
    }
    
    var currentController: ViewController?
    
    private let pendingControllerDisposable = MetaDisposable()
    
    private var theme: TabBarControllerTheme
    
    public init(navigationBarTheme: NavigationBarTheme, theme: TabBarControllerTheme) {
        self.theme = theme
        
        super.init(navigationBarTheme: navigationBarTheme)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.pendingControllerDisposable.dispose()
    }
    
    public func updateTheme(navigationBarTheme: NavigationBarTheme, theme: TabBarControllerTheme) {
        self.navigationBar?.updateTheme(navigationBarTheme)
        if self.theme !== theme {
            self.theme = theme
            if self.isNodeLoaded {
                self.tabBarControllerNode.updateTheme(theme)
            }
        }
    }
    
    override open func loadDisplayNode() {
        self.displayNode = TabBarControllerNode(theme: self.theme, itemSelected: { [weak self] index in
            if let strongSelf = self {
                strongSelf.controllers[index].containerLayoutUpdated(strongSelf.containerLayout.addedInsets(insets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 49.0, right: 0.0)), transition: .immediate)
                strongSelf.pendingControllerDisposable.set((strongSelf.controllers[index].ready.get() |> deliverOnMainQueue).start(next: { _ in
                    if let strongSelf = self {
                        strongSelf.selectedIndex = index
                    }
                }))
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
        
        if let _selectedIndex = self._selectedIndex, _selectedIndex < self.controllers.count {
            self.currentController = self.controllers[_selectedIndex]
        }
        
        var displayNavigationBar = false
        if let currentController = self.currentController {
            currentController.willMove(toParentViewController: self)
            currentController.containerLayoutUpdated(self.containerLayout.addedInsets(insets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 49.0, right: 0.0)), transition: .immediate)
            self.tabBarControllerNode.currentControllerView = currentController.view
            currentController.navigationBar?.isHidden = true
            self.addChildViewController(currentController)
            currentController.didMove(toParentViewController: self)
            
            currentController.navigationItem.setTarget(self.navigationItem)
            displayNavigationBar = currentController.displayNavigationBar
            currentController.displayNode.recursivelyEnsureDisplaySynchronously(true)
            self.statusBar.statusBarStyle = currentController.statusBar.statusBarStyle
        } else {
            self.navigationItem.title = nil
            self.navigationItem.leftBarButtonItem = nil
            self.navigationItem.rightBarButtonItem = nil
            self.navigationItem.titleView = nil
            self.navigationItem.backBarButtonItem = nil
            displayNavigationBar = false
        }
        if self.displayNavigationBar != displayNavigationBar {
            self.setDisplayNavigationBar(displayNavigationBar)
        }
        
        self.tabBarControllerNode.containerLayoutUpdated(self.containerLayout, transition: .immediate)
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
    
    override open func viewDidAppear(_ animated: Bool) {
        if let currentController = self.currentController {
            currentController.viewDidAppear(animated)
        }
    }
    
    override open func viewDidDisappear(_ animated: Bool) {
        if let currentController = self.currentController {
            currentController.viewDidDisappear(animated)
        }
    }
    
    public func setControllers(_ controllers: [ViewController], selectedIndex: Int?) {
        var updatedSelectedIndex: Int? = selectedIndex
        if updatedSelectedIndex == nil, let selectedIndex = self._selectedIndex, selectedIndex < self.controllers.count {
            if let index = controllers.index(where: { $0 === self.controllers[selectedIndex] }) {
                updatedSelectedIndex = index
            } else {
                updatedSelectedIndex = 0
            }
        }
        self.controllers = controllers
        self.tabBarControllerNode.tabBarNode.tabBarItems = self.controllers.map({ $0.tabBarItem })
        
        if let updatedSelectedIndex = updatedSelectedIndex {
            self.selectedIndex = updatedSelectedIndex
            self.updateSelectedIndex()
        }
    }
}
