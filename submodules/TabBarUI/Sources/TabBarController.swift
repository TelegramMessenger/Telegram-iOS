import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import TelegramPresentationData

public final class TabBarControllerTheme {
    public let backgroundColor: UIColor
    public let tabBarBackgroundColor: UIColor
    public let tabBarSeparatorColor: UIColor
    public let tabBarIconColor: UIColor
    public let tabBarSelectedIconColor: UIColor
    public let tabBarTextColor: UIColor
    public let tabBarSelectedTextColor: UIColor
    public let tabBarBadgeBackgroundColor: UIColor
    public let tabBarBadgeStrokeColor: UIColor
    public let tabBarBadgeTextColor: UIColor
    public let tabBarExtractedIconColor: UIColor
    public let tabBarExtractedTextColor: UIColor

    public init(backgroundColor: UIColor, tabBarBackgroundColor: UIColor, tabBarSeparatorColor: UIColor, tabBarIconColor: UIColor, tabBarSelectedIconColor: UIColor, tabBarTextColor: UIColor, tabBarSelectedTextColor: UIColor, tabBarBadgeBackgroundColor: UIColor, tabBarBadgeStrokeColor: UIColor, tabBarBadgeTextColor: UIColor, tabBarExtractedIconColor: UIColor, tabBarExtractedTextColor: UIColor) {
        self.backgroundColor = backgroundColor
        self.tabBarBackgroundColor = tabBarBackgroundColor
        self.tabBarSeparatorColor = tabBarSeparatorColor
        self.tabBarIconColor = tabBarIconColor
        self.tabBarSelectedIconColor = tabBarSelectedIconColor
        self.tabBarTextColor = tabBarTextColor
        self.tabBarSelectedTextColor = tabBarSelectedTextColor
        self.tabBarBadgeBackgroundColor = tabBarBadgeBackgroundColor
        self.tabBarBadgeStrokeColor = tabBarBadgeStrokeColor
        self.tabBarBadgeTextColor = tabBarBadgeTextColor
        self.tabBarExtractedIconColor = tabBarExtractedIconColor
        self.tabBarExtractedTextColor = tabBarExtractedTextColor
    }
    
    public convenience init(rootControllerTheme: PresentationTheme) {
        let theme = rootControllerTheme.rootController.tabBar
        self.init(backgroundColor: rootControllerTheme.list.plainBackgroundColor, tabBarBackgroundColor: theme.backgroundColor, tabBarSeparatorColor: theme.separatorColor, tabBarIconColor: theme.iconColor, tabBarSelectedIconColor: theme.selectedIconColor, tabBarTextColor: theme.textColor, tabBarSelectedTextColor: theme.selectedTextColor, tabBarBadgeBackgroundColor: theme.badgeBackgroundColor, tabBarBadgeStrokeColor: theme.badgeStrokeColor, tabBarBadgeTextColor: theme.badgeTextColor, tabBarExtractedIconColor: rootControllerTheme.contextMenu.extractedContentTintColor, tabBarExtractedTextColor: rootControllerTheme.contextMenu.extractedContentTintColor)
    }
}

public final class TabBarItemInfo: NSObject {
    public let previewing: Bool
    
    public init(previewing: Bool) {
        self.previewing = previewing
        
        super.init()
    }
    
    override public func isEqual(_ object: Any?) -> Bool {
        if let object = object as? TabBarItemInfo {
            if self.previewing != object.previewing {
                return false
            }
            return true
        } else {
            return false
        }
    }
    
    public static func ==(lhs: TabBarItemInfo, rhs: TabBarItemInfo) -> Bool {
        if lhs.previewing != rhs.previewing {
            return false
        }
        return true
    }
}

public enum TabBarContainedControllerPresentationUpdate {
    case dismiss
    case present
    case progress(CGFloat)
}

public protocol TabBarContainedController {
    func presentTabBarPreviewingController(sourceNodes: [ASDisplayNode])
    func updateTabBarPreviewingControllerPresentation(_ update: TabBarContainedControllerPresentationUpdate)
}

open class TabBarControllerImpl: ViewController, TabBarController {
    private var validLayout: ContainerViewLayout?
    
    private var tabBarControllerNode: TabBarControllerNode {
        get {
            return super.displayNode as! TabBarControllerNode
        }
    }
    
    open override func updateNavigationCustomData(_ data: Any?, progress: CGFloat, transition: ContainedViewLayoutTransition) {
        for controller in self.controllers {
            controller.updateNavigationCustomData(data, progress: progress, transition: transition)
        }
    }
    
    public private(set) var controllers: [ViewController] = []
    
    private let _ready = Promise<Bool>()
    override open var ready: Promise<Bool> {
        return self._ready
    }
    
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
            if self._selectedIndex != index {
                self._selectedIndex = index
                
                self.updateSelectedIndex(animated: true)
            }
        }
    }
    
    public var currentController: ViewController?
    
    override public var transitionNavigationBar: NavigationBar? {
        return self.currentController?.navigationBar
    }
    
    private let pendingControllerDisposable = MetaDisposable()
    
    private var navigationBarPresentationData: NavigationBarPresentationData
    private var theme: TabBarControllerTheme
    
    public var cameraItemAndAction: (item: UITabBarItem, action: () -> Void)?
    
    public init(navigationBarPresentationData: NavigationBarPresentationData, theme: TabBarControllerTheme) {
        self.navigationBarPresentationData = navigationBarPresentationData
        self.theme = theme
        
        super.init(navigationBarPresentationData: nil)
        
        self.scrollToTop = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if let controller = strongSelf.currentController {
                controller.scrollToTop?()
            }
        }
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.pendingControllerDisposable.dispose()
    }
    
    public func updateTheme(navigationBarPresentationData: NavigationBarPresentationData, theme: TabBarControllerTheme) {
        if self.theme !== theme {
            self.theme = theme
            self.navigationBarPresentationData = navigationBarPresentationData
            if self.isNodeLoaded {
                self.tabBarControllerNode.updateTheme(theme, navigationBarPresentationData: navigationBarPresentationData)
            }
        }
    }
    
    private var debugTapCounter: (Double, Int) = (0.0, 0)
    
    public func sourceNodesForController(at index: Int) -> [ASDisplayNode]? {
        return self.tabBarControllerNode.tabBarNode.sourceNodesForController(at: index)
    }
    
    public func viewForCameraItem() -> UIView? {
        if let (cameraItem, _) = self.cameraItemAndAction {
            if let cameraItemIndex = self.tabBarControllerNode.tabBarNode.tabBarItems.firstIndex(where: { $0.item === cameraItem }) {
                return self.tabBarControllerNode.tabBarNode.viewForControllerTab(at: cameraItemIndex)
            }
        }
        return nil
    }
    
    public func frameForControllerTab(controller: ViewController) -> CGRect? {
        if let index = self.controllers.firstIndex(of: controller) {
            var index = index
            if let (cameraItem, _) = self.cameraItemAndAction {
                if let cameraItemIndex = self.tabBarControllerNode.tabBarNode.tabBarItems.firstIndex(where: { $0.item === cameraItem }) {
                    if index == cameraItemIndex {
                        
                    } else if index > cameraItemIndex {
                        index -= 1
                    }
                }
            }
            return self.tabBarControllerNode.tabBarNode.frameForControllerTab(at: index).flatMap { self.tabBarControllerNode.tabBarNode.view.convert($0, to: self.view) }
        } else {
            return nil
        }
    }
    
    public func isPointInsideContentArea(point: CGPoint) -> Bool {
        if point.y < self.tabBarControllerNode.tabBarNode.frame.minY {
            return true
        }
        return false
    }
    
    public func updateIsTabBarEnabled(_ value: Bool, transition: ContainedViewLayoutTransition) {
        self.tabBarControllerNode.updateIsTabBarEnabled(value, transition: transition)
    }
    
    public func updateIsTabBarHidden(_ value: Bool, transition: ContainedViewLayoutTransition) {
        self.tabBarControllerNode.tabBarHidden = value
        if let layout = self.validLayout {
            self.containerLayoutUpdated(layout, transition: .animated(duration: 0.4, curve: .slide))
        }
    }
    
    override open func loadDisplayNode() {
        self.displayNode = TabBarControllerNode(theme: self.theme, navigationBarPresentationData: self.navigationBarPresentationData, itemSelected: { [weak self] index, longTap, itemNodes in
            if let strongSelf = self {
                var index = index
                if let (cameraItem, cameraAction) = strongSelf.cameraItemAndAction {
                    if let cameraItemIndex = strongSelf.tabBarControllerNode.tabBarNode.tabBarItems.firstIndex(where: { $0.item === cameraItem }) {
                        if index == cameraItemIndex {
                            cameraAction()
                            return
                        } else if index > cameraItemIndex {
                            index -= 1
                        }
                    }
                }
                if longTap, let controller = strongSelf.controllers[index] as? TabBarContainedController {
                    controller.presentTabBarPreviewingController(sourceNodes: itemNodes)
                    return
                }

                let timestamp = CACurrentMediaTime()
                if strongSelf.debugTapCounter.0 < timestamp - 0.4 {
                    strongSelf.debugTapCounter.0 = timestamp
                    strongSelf.debugTapCounter.1 = 0
                }
                    
                if strongSelf.debugTapCounter.0 >= timestamp - 0.4 {
                    strongSelf.debugTapCounter.0 = timestamp
                    strongSelf.debugTapCounter.1 += 1
                }
                
                if strongSelf.debugTapCounter.1 >= 10 {
                    strongSelf.debugTapCounter.1 = 0
                    
                    strongSelf.controllers[index].tabBarItemDebugTapAction?()
                }
                
                if let validLayout = strongSelf.validLayout {
                    var updatedLayout = validLayout
                    
                    var tabBarHeight: CGFloat
                    var options: ContainerViewLayoutInsetOptions = []
                    if validLayout.metrics.widthClass == .regular {
                        options.insert(.input)
                    }
                    let bottomInset: CGFloat = validLayout.insets(options: options).bottom
                    if !validLayout.safeInsets.left.isZero {
                        tabBarHeight = 34.0 + bottomInset
                    } else {
                        tabBarHeight = 49.0 + bottomInset
                    }
                    updatedLayout.intrinsicInsets.bottom = tabBarHeight
                    
                    strongSelf.controllers[index].containerLayoutUpdated(updatedLayout, transition: .immediate)
                }
                let startTime = CFAbsoluteTimeGetCurrent()
                strongSelf.pendingControllerDisposable.set((strongSelf.controllers[index].ready.get()
                |> deliverOnMainQueue).start(next: { _ in
                    if let strongSelf = self {
                        let readyTime = CFAbsoluteTimeGetCurrent() - startTime
                        if readyTime > 0.5 {
                            print("TabBarController: controller took \(readyTime) to become ready")
                        }
                        
                        if strongSelf.selectedIndex == index {
                            if let controller = strongSelf.currentController {
                                if longTap {
                                    controller.longTapWithTabBar?()
                                } else {
                                    controller.scrollToTopWithTabBar?()
                                }
                            }
                        } else {
                            strongSelf.selectedIndex = index
                        }
                    }
                }))
            }
        }, contextAction: { [weak self] index, node, gesture in
            guard let strongSelf = self else {
                return
            }
            if index >= 0 && index < strongSelf.tabBarControllerNode.tabBarNode.tabBarItems.count {
                var index = index
                if let (cameraItem, _) = strongSelf.cameraItemAndAction {
                    if let cameraItemIndex = strongSelf.tabBarControllerNode.tabBarNode.tabBarItems.firstIndex(where: { $0.item === cameraItem }) {
                        if index == cameraItemIndex {
                            return
                        } else if index > cameraItemIndex {
                            index -= 1
                        }
                    }
                }
                strongSelf.controllers[index].tabBarItemContextAction(sourceNode: node, gesture: gesture)
            }
        }, swipeAction: { [weak self] index, direction in
            guard let strongSelf = self else {
                return
            }
            if index >= 0 && index < strongSelf.tabBarControllerNode.tabBarNode.tabBarItems.count {
                var index = index
                if let (cameraItem, _) = strongSelf.cameraItemAndAction {
                    if let cameraItemIndex = strongSelf.tabBarControllerNode.tabBarNode.tabBarItems.firstIndex(where: { $0.item === cameraItem }) {
                        if index == cameraItemIndex {
                            return
                        } else if index > cameraItemIndex {
                            index -= 1
                        }
                    }
                }
                strongSelf.controllers[index].tabBarItemSwipeAction(direction: direction)
            }
        }, toolbarActionSelected: { [weak self] action in
            self?.currentController?.toolbarActionSelected(action: action)
        }, disabledPressed: { [weak self] in
            self?.currentController?.tabBarDisabledAction()
        })
        
        self.updateSelectedIndex()
        self.displayNodeDidLoad()
    }
    
    public func updateBackgroundAlpha(_ alpha: CGFloat, transition: ContainedViewLayoutTransition) {
        let alpha = max(0.0, min(1.0, alpha))
        transition.updateAlpha(node: self.tabBarControllerNode.tabBarNode.backgroundNode, alpha: alpha, delay: 0.1)
        transition.updateAlpha(node: self.tabBarControllerNode.tabBarNode.separatorNode, alpha: alpha, delay: 0.1)
    }
    
    private func updateSelectedIndex(animated: Bool = false) {
        if !self.isNodeLoaded {
            return
        }
        
        var animated = animated
        if let layout = self.validLayout, case .regular = layout.metrics.widthClass {
            animated = false
        }
        
        var tabBarSelectedIndex = self.selectedIndex
        if let (cameraItem, _) = self.cameraItemAndAction {
            if let cameraItemIndex = self.tabBarControllerNode.tabBarNode.tabBarItems.firstIndex(where: { $0.item === cameraItem }) {
                if tabBarSelectedIndex >= cameraItemIndex {
                    tabBarSelectedIndex += 1
                }
            }
        }
        self.tabBarControllerNode.tabBarNode.selectedIndex = tabBarSelectedIndex
        
        var transitionScale: CGFloat = 0.998
        if let currentView = self.currentController?.view {
            transitionScale = (currentView.frame.height - 3.0) / currentView.frame.height
        }
        if let currentController = self.currentController {
            currentController.willMove(toParent: nil)
            //self.tabBarControllerNode.currentControllerNode = nil
            
            if animated {
                currentController.view.layer.animateScale(from: 1.0, to: transitionScale, duration: 0.12, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { completed in
                    if completed {
                        currentController.view.layer.removeAllAnimations()
                    }
                })
            }
            currentController.removeFromParent()
            currentController.didMove(toParent: nil)
            
            self.currentController = nil
        }
        
        if let _selectedIndex = self._selectedIndex, _selectedIndex < self.controllers.count {
            self.currentController = self.controllers[_selectedIndex]
        }

        if let currentController = self.currentController {
            currentController.willMove(toParent: self)
            self.addChild(currentController)
            
            let commit = self.tabBarControllerNode.setCurrentControllerNode(currentController.displayNode)
            if animated {
                currentController.view.layer.animateScale(from: transitionScale, to: 1.0, duration: 0.15, delay: 0.1, timingFunction: kCAMediaTimingFunctionSpring)
                currentController.view.layer.allowsGroupOpacity = true
                currentController.view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1, completion: { completed in
                    if completed {
                        currentController.view.layer.allowsGroupOpacity = false
                    }
                    commit()
                })
            } else {
                commit()
            }
            currentController.didMove(toParent: self)

            currentController.displayNode.recursivelyEnsureDisplaySynchronously(true)
            self.statusBar.statusBarStyle = currentController.statusBar.statusBarStyle
        }
        
        if let layout = self.validLayout {
            self.containerLayoutUpdated(layout, transition: .immediate)
        }
    }
    
    public func updateLayout(transition: ContainedViewLayoutTransition = .immediate) {
        if let layout = self.validLayout {
            self.containerLayoutUpdated(layout, transition: transition)
        }
    }
    
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.validLayout = layout
        
        self.tabBarControllerNode.containerLayoutUpdated(layout, toolbar: self.currentController?.toolbar, transition: transition)
        
        if let currentController = self.currentController {
            currentController.view.frame = CGRect(origin: CGPoint(), size: layout.size)
            
            var updatedLayout = layout
            
            var tabBarHeight: CGFloat
            var options: ContainerViewLayoutInsetOptions = []
            if updatedLayout.metrics.widthClass == .regular {
                options.insert(.input)
            }
            let bottomInset: CGFloat = updatedLayout.insets(options: options).bottom
            if !updatedLayout.safeInsets.left.isZero {
                tabBarHeight = 34.0 + bottomInset
            } else {
                tabBarHeight = 49.0 + bottomInset
            }
            if !self.tabBarControllerNode.tabBarHidden {
                updatedLayout.intrinsicInsets.bottom = tabBarHeight
            }
            
            currentController.containerLayoutUpdated(updatedLayout, transition: transition)
        }
    }
    
    public func updateControllerLayout(controller: ViewController) {
        guard let layout = self.validLayout else {
            return
        }
        if self.controllers.contains(where: { $0 === controller }) {
            let currentController = controller
            currentController.view.frame = CGRect(origin: CGPoint(), size: layout.size)
            
            var updatedLayout = layout
            
            var tabBarHeight: CGFloat
            var options: ContainerViewLayoutInsetOptions = []
            if updatedLayout.metrics.widthClass == .regular {
                options.insert(.input)
            }
            let bottomInset: CGFloat = updatedLayout.insets(options: options).bottom
            if !updatedLayout.safeInsets.left.isZero {
                tabBarHeight = 34.0 + bottomInset
            } else {
                tabBarHeight = 49.0 + bottomInset
            }
            if !self.tabBarControllerNode.tabBarHidden {
                updatedLayout.intrinsicInsets.bottom = tabBarHeight
            }
            
            currentController.containerLayoutUpdated(updatedLayout, transition: .immediate)
        }
    }
    
    override open func navigationStackConfigurationUpdated(next: [ViewController]) {
        super.navigationStackConfigurationUpdated(next: next)
        for controller in self.controllers {
            controller.navigationStackConfigurationUpdated(next: next)
        }
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        if let currentController = self.currentController {
            currentController.viewWillDisappear(animated)
        }
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        if let currentController = self.currentController {
            currentController.viewWillAppear(animated)
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
            if let index = controllers.firstIndex(where: { $0 === self.controllers[selectedIndex] }) {
                updatedSelectedIndex = index
            } else {
                updatedSelectedIndex = 0
            }
        }
        self.controllers = controllers
        
        var tabBarItems = self.controllers.map({ TabBarNodeItem(item: $0.tabBarItem, contextActionType: $0.tabBarItemContextActionType) })
        if let (cameraItem, _) = self.cameraItemAndAction {
            tabBarItems.insert(TabBarNodeItem(item: cameraItem, contextActionType: .none), at: Int(floor(CGFloat(controllers.count) / 2)))
        }
        
        self.tabBarControllerNode.tabBarNode.tabBarItems = tabBarItems
        
        let signals = combineLatest(self.controllers.map({ $0.tabBarItem }).map { tabBarItem -> Signal<Bool, NoError> in
            if let tabBarItem = tabBarItem, tabBarItem.image == nil {
                return Signal { [weak tabBarItem] subscriber in
                    let index = tabBarItem?.addSetImageListener({ image in
                        if image != nil {
                            subscriber.putNext(true)
                            subscriber.putCompletion()
                        }
                    })
                    return ActionDisposable {
                        Queue.mainQueue().async {
                            if let index = index {
                                tabBarItem?.removeSetImageListener(index)
                            }
                        }
                    }
                }
                |> runOn(.mainQueue())
            } else {
                return .single(true)
            }
        })
        |> map { items -> Bool in
            for item in items {
                if !item {
                    return false
                }
            }
            return true
        }
        |> filter { $0 }
        |> take(1)
        
        let allReady = signals
        |> deliverOnMainQueue
        |> mapToSignal { _ -> Signal<Bool, NoError> in
            // wait for tab bar items to be applied
            return .single(true)
            |> delay(0.0, queue: Queue.mainQueue())
        }
        
        self._ready.set(allReady)
        
        if let updatedSelectedIndex = updatedSelectedIndex {
            self.selectedIndex = updatedSelectedIndex
            self.updateSelectedIndex()
        }
    }
}
