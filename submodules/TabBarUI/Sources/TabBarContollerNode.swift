import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import TabBarComponent

private extension ToolbarTheme {
    convenience init(theme: PresentationTheme) {
        self.init(barBackgroundColor: theme.rootController.tabBar.backgroundColor, barSeparatorColor: .clear, barTextColor: theme.rootController.tabBar.textColor, barSelectedTextColor: theme.rootController.tabBar.selectedTextColor)
    }
}

final class TabBarControllerNode: ASDisplayNode {
    private struct Params: Equatable {
        let layout: ContainerViewLayout
        let toolbar: Toolbar?
        
        init(
            layout: ContainerViewLayout,
            toolbar: Toolbar?
        ) {
            self.layout = layout
            self.toolbar = toolbar
        }
    }
    
    private struct LayoutResult {
        let params: Params
        let bottomInset: CGFloat
        
        init(params: Params, bottomInset: CGFloat) {
            self.params = params
            self.bottomInset = bottomInset
        }
    }
    
    private final class View: UIView {
        var onLayout: (() -> Void)?
        
        override func layoutSubviews() {
            super.layoutSubviews()
            
            self.onLayout?()
        }
    }
    
    private var theme: PresentationTheme
    private let itemSelected: (Int, Bool, [ASDisplayNode]) -> Void
    private let contextAction: (Int, ContextExtractedContentContainingView, ContextGesture) -> Void
    
    private let tabBarView = ComponentView<Empty>()
    
    private let disabledOverlayNode: ASDisplayNode
    private var toolbarNode: ToolbarNode?
    private let toolbarActionSelected: (ToolbarActionOption) -> Void
    private let disabledPressed: () -> Void
    
    private(set) var tabBarItems: [TabBarNodeItem] = []
    private(set) var selectedIndex: Int = 0

    private(set) var currentControllerNode: ASDisplayNode?
    
    private var layoutResult: LayoutResult?
    private var isUpdateRequested: Bool = false
    private var isChangingSelectedIndex: Bool = false
    
    func setCurrentControllerNode(_ node: ASDisplayNode?) -> () -> Void {
        guard node !== self.currentControllerNode else {
            return {}
        }
        
        let previousNode = self.currentControllerNode
        self.currentControllerNode = node
        if let currentControllerNode = self.currentControllerNode {
            if let previousNode {
                self.insertSubnode(currentControllerNode, aboveSubnode: previousNode)
            } else {
                self.insertSubnode(currentControllerNode, at: 0)
            }
            if let tabBarView = self.tabBarView.view {
                self.view.bringSubviewToFront(tabBarView)
            }
        }
        
        return { [weak self, weak previousNode] in
            if previousNode !== self?.currentControllerNode {
                previousNode?.removeFromSupernode()
            }
        }
    }
    
    init(theme: PresentationTheme, itemSelected: @escaping (Int, Bool, [ASDisplayNode]) -> Void, contextAction: @escaping (Int, ContextExtractedContentContainingView, ContextGesture) -> Void, swipeAction: @escaping (Int, TabBarItemSwipeDirection) -> Void, toolbarActionSelected: @escaping (ToolbarActionOption) -> Void, disabledPressed: @escaping () -> Void) {
        self.theme = theme
        self.itemSelected = itemSelected
        self.contextAction = contextAction
        self.disabledOverlayNode = ASDisplayNode()
        self.disabledOverlayNode.backgroundColor = theme.rootController.tabBar.backgroundColor.withAlphaComponent(0.5)
        self.disabledOverlayNode.alpha = 0.0
        self.toolbarActionSelected = toolbarActionSelected
        self.disabledPressed = disabledPressed
        
        super.init()
        
        self.setViewBlock({
            return View(frame: CGRect())
        })
        
        (self.view as? View)?.onLayout = { [weak self] in
            guard let self else {
                return
            }
            if self.isUpdateRequested {
                self.isUpdateRequested = false
                if let layoutResult = self.layoutResult {
                    let _ = self.updateImpl(params: layoutResult.params, transition: .immediate)
                }
            }
        }
        
        self.backgroundColor = theme.list.plainBackgroundColor
        
        //self.addSubnode(self.tabBarNode)
        //self.addSubnode(self.disabledOverlayNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.disabledOverlayNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.disabledTapGesture(_:))))
    }
    
    @objc private func disabledTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.disabledPressed()
        }
    }
    
    func updateTheme(_ theme: PresentationTheme) {
        self.theme = theme
        self.backgroundColor = theme.list.plainBackgroundColor
        
        self.disabledOverlayNode.backgroundColor = theme.rootController.tabBar.backgroundColor.withAlphaComponent(0.5)
        self.toolbarNode?.updateTheme(ToolbarTheme(theme: theme))
        self.requestUpdate()
    }
    
    func updateIsTabBarEnabled(_ value: Bool, transition: ContainedViewLayoutTransition) {
        transition.updateAlpha(node: self.disabledOverlayNode, alpha: value ? 0.0 : 1.0)
    }
    
    var tabBarHidden = false {
        didSet {
            if self.tabBarHidden != oldValue {
                self.requestUpdate()
            }
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, toolbar: Toolbar?, transition: ContainedViewLayoutTransition) -> CGFloat {
        let params = Params(layout: layout, toolbar: toolbar)
        if let layoutResult = self.layoutResult, layoutResult.params == params {
            return layoutResult.bottomInset
        } else {
            let bottomInset = self.updateImpl(params: params, transition: transition)
            self.layoutResult = LayoutResult(params: params, bottomInset: bottomInset)
            return bottomInset
        }
    }
    
    private func requestUpdate() {
        self.isUpdateRequested = true
        self.view.setNeedsLayout()
    }
    
    private func updateImpl(params: Params, transition: ContainedViewLayoutTransition) -> CGFloat {
        var options: ContainerViewLayoutInsetOptions = []
        if params.layout.metrics.widthClass == .regular {
            options.insert(.input)
        }
        
        var bottomInset: CGFloat = params.layout.insets(options: options).bottom
        if bottomInset == 0.0 {
            bottomInset = 8.0
        } else {
            bottomInset = max(bottomInset, 8.0)
        }
        let sideInset: CGFloat = 20.0
        
        var selectedId: AnyHashable?
        if self.selectedIndex < self.tabBarItems.count {
            selectedId = ObjectIdentifier(self.tabBarItems[self.selectedIndex].item)
        }
        var tabBarTransition = ComponentTransition(transition)
        if self.isChangingSelectedIndex {
            self.isChangingSelectedIndex = false
            tabBarTransition = .spring(duration: 0.4)
        }
        if self.tabBarView.view == nil {
            tabBarTransition = .immediate
        }
        let tabBarSize = self.tabBarView.update(
            transition: tabBarTransition,
            component: AnyComponent(TabBarComponent(
                theme: self.theme,
                items: self.tabBarItems.map { item in
                    let itemId = AnyHashable(ObjectIdentifier(item.item))
                    return TabBarComponent.Item(
                        item: item.item,
                        action: { [weak self] isLongTap in
                            guard let self else {
                                return
                            }
                            if let index = self.tabBarItems.firstIndex(where: { AnyHashable(ObjectIdentifier($0.item)) == itemId }) {
                                self.itemSelected(index, isLongTap, [])
                            }
                        },
                        contextAction: { [weak self] gesture, sourceView in
                            guard let self else {
                                return
                            }
                            if let index = self.tabBarItems.firstIndex(where: { AnyHashable(ObjectIdentifier($0.item)) == itemId }) {
                                self.contextAction(index, sourceView, gesture)
                            }
                        }
                    )
                },
                selectedId: selectedId,
                isTablet: params.layout.metrics.isTablet
            )),
            environment: {},
            containerSize: CGSize(width: params.layout.size.width - sideInset * 2.0, height: 100.0)
        )
        let tabBarFrame = CGRect(origin: CGPoint(x: floor((params.layout.size.width - tabBarSize.width) * 0.5), y: params.layout.size.height - (self.tabBarHidden ? 0.0 : (tabBarSize.height + bottomInset))), size: tabBarSize)
        
        if let tabBarComponentView = self.tabBarView.view {
            if tabBarComponentView.superview == nil {
                self.view.addSubview(tabBarComponentView)
            }
            transition.updateFrame(view: tabBarComponentView, frame: tabBarFrame)
            transition.updateAlpha(layer: tabBarComponentView.layer, alpha: params.toolbar == nil ? 1.0 : 0.0)
        }
        
        transition.updateFrame(node: self.disabledOverlayNode, frame: tabBarFrame)
        
        let toolbarHeight = 50.0 + params.layout.insets(options: options).bottom
        let toolbarFrame = CGRect(origin: CGPoint(x: 0.0, y: params.layout.size.height - toolbarHeight), size: CGSize(width: params.layout.size.width, height: toolbarHeight))
        
        if let toolbar = params.toolbar {
            if let toolbarNode = self.toolbarNode {
                transition.updateFrame(node: toolbarNode, frame: toolbarFrame)
                toolbarNode.updateLayout(size: toolbarFrame.size, leftInset: params.layout.safeInsets.left, rightInset: params.layout.safeInsets.right, additionalSideInsets: params.layout.additionalInsets, bottomInset: bottomInset, toolbar: toolbar, transition: transition)
            } else {
                let toolbarNode = ToolbarNode(theme: ToolbarTheme(theme: self.theme), displaySeparator: true, left: { [weak self] in
                    self?.toolbarActionSelected(.left)
                }, right: { [weak self] in
                    self?.toolbarActionSelected(.right)
                }, middle: { [weak self] in
                    self?.toolbarActionSelected(.middle)
                })
                toolbarNode.frame = toolbarFrame
                toolbarNode.updateLayout(size: toolbarFrame.size, leftInset: params.layout.safeInsets.left, rightInset: params.layout.safeInsets.right, additionalSideInsets: params.layout.additionalInsets, bottomInset: bottomInset, toolbar: toolbar, transition: .immediate)
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
        
        return params.layout.size.height - tabBarFrame.minY
    }
    
    func frameForControllerTab(at index: Int) -> CGRect? {
        guard let tabBarView = self.tabBarView.view as? TabBarComponent.View else {
            return nil
        }
        guard let itemFrame = tabBarView.frameForItem(at: index) else {
            return nil
        }
        return self.view.convert(itemFrame, from: tabBarView)
    }
    
    func isPointInsideContentArea(point: CGPoint) -> Bool {
        guard let tabBarView = self.tabBarView.view else {
            return false
        }
        if point.y < tabBarView.frame.minY {
            return true
        }
        return false
    }
    
    func updateTabBarItems(items: [TabBarNodeItem]) {
        self.tabBarItems = items
        self.requestUpdate()
    }
    
    func updateSelectedIndex(index: Int) {
        self.selectedIndex = index
        self.isChangingSelectedIndex = true
        self.requestUpdate()
    }
}
