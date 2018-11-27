import Foundation
import AsyncDisplayKit

final class TabBarControllerNode: ASDisplayNode {
    private var theme: TabBarControllerTheme
    let tabBarNode: TabBarNode
    private var toolbarNode: ToolbarNode?
    private let toolbarActionSelected: (Bool) -> Void

    var currentControllerView: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            
            if let currentControllerView = self.currentControllerView {
                self.view.insertSubview(currentControllerView, at: 0)
            }
        }
    }
    
    init(theme: TabBarControllerTheme, itemSelected: @escaping (Int, Bool) -> Void, toolbarActionSelected: @escaping (Bool) -> Void) {
        self.theme = theme
        self.tabBarNode = TabBarNode(theme: theme, itemSelected: itemSelected)
        self.toolbarActionSelected = toolbarActionSelected
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = theme.backgroundColor
        
        self.addSubnode(self.tabBarNode)
    }
    
    func updateTheme(_ theme: TabBarControllerTheme) {
        self.theme = theme
        self.backgroundColor = theme.backgroundColor
        
        self.tabBarNode.updateTheme(theme)
        self.toolbarNode?.updateTheme(theme)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, toolbar: Toolbar?, transition: ContainedViewLayoutTransition) {
        var tabBarHeight: CGFloat
        var options: ContainerViewLayoutInsetOptions = []
        if layout.metrics.widthClass == .regular {
            options.insert(.input)
        }
        let bottomInset: CGFloat = layout.insets(options: options).bottom
        if !layout.safeInsets.left.isZero {
            tabBarHeight = 34.0 + bottomInset
        } else {
            tabBarHeight = 49.0 + bottomInset
        }
        
        let tabBarFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - tabBarHeight), size: CGSize(width: layout.size.width, height: tabBarHeight))
        
        transition.updateFrame(node: self.tabBarNode, frame: tabBarFrame)
        self.tabBarNode.updateLayout(size: layout.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, bottomInset: bottomInset, transition: transition)
        
        if let toolbar = toolbar {
            if let toolbarNode = self.toolbarNode {
                transition.updateFrame(node: toolbarNode, frame: tabBarFrame)
                toolbarNode.updateLayout(size: tabBarFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right,  bottomInset: bottomInset, toolbar: toolbar, transition: transition)
            } else {
                let toolbarNode = ToolbarNode(theme: self.theme, left: { [weak self] in
                    self?.toolbarActionSelected(true)
                }, right: { [weak self] in
                    self?.toolbarActionSelected(false)
                })
                toolbarNode.frame = tabBarFrame
                toolbarNode.updateLayout(size: tabBarFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, bottomInset: bottomInset, toolbar: toolbar, transition: .immediate)
                self.addSubnode(toolbarNode)
                self.toolbarNode = toolbarNode
                if transition.isAnimated {
                    toolbarNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            }
        } else if let toolbarNode = self.toolbarNode {
            self.toolbarNode = nil
            transition.updateAlpha(node: toolbarNode, alpha: 0.0, completion: { [weak toolbarNode] _ in
                toolbarNode?.removeFromSupernode()
            })
        }
    }
}
