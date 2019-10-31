import Foundation
import UIKit
import Display
import SwiftSignalKit
import ProgressNavigationButtonNode

enum ItemListNavigationButtonStyle {
    case regular
    case bold
    case activity
    
    var barButtonItemStyle: UIBarButtonItem.Style {
        switch self {
        case .regular, .activity:
            return .plain
        case .bold:
            return .done
        }
    }
}

enum ItemListNavigationButtonContentIcon {
    case search
    case add
    case action
}

enum ItemListNavigationButtonContent: Equatable {
    case none
    case text(String)
    case icon(ItemListNavigationButtonContentIcon)
}

struct ItemListNavigationButton {
    let content: ItemListNavigationButtonContent
    let style: ItemListNavigationButtonStyle
    let enabled: Bool
    let action: () -> Void
    
    init(content: ItemListNavigationButtonContent, style: ItemListNavigationButtonStyle, enabled: Bool, action: @escaping () -> Void) {
        self.content = content
        self.style = style
        self.enabled = enabled
        self.action = action
    }
}

struct ItemListBackButton: Equatable {
    let title: String
    
    init(title: String) {
        self.title = title
    }
}

enum ItemListControllerTitle: Equatable {
    case text(String)
}

final class ItemListControllerTabBarItem: Equatable {
    let title: String
    let image: UIImage?
    let selectedImage: UIImage?
    let tintImages: Bool
    let badgeValue: String?
    
    init(title: String, image: UIImage?, selectedImage: UIImage?, tintImages: Bool = true, badgeValue: String? = nil) {
        self.title = title
        self.image = image
        self.selectedImage = selectedImage
        self.tintImages = tintImages
        self.badgeValue = badgeValue
    }
    
    static func ==(lhs: ItemListControllerTabBarItem, rhs: ItemListControllerTabBarItem) -> Bool {
        return lhs.title == rhs.title && lhs.image === rhs.image && lhs.selectedImage === rhs.selectedImage && lhs.tintImages == rhs.tintImages && lhs.badgeValue == rhs.badgeValue
    }
}

struct ItemListControllerState {
    let theme: WalletTheme
    let title: ItemListControllerTitle
    let leftNavigationButton: ItemListNavigationButton?
    let rightNavigationButton: ItemListNavigationButton?
    let secondaryRightNavigationButton: ItemListNavigationButton?
    let backNavigationButton: ItemListBackButton?
    let tabBarItem: ItemListControllerTabBarItem?
    let animateChanges: Bool
    
    init(theme: WalletTheme, title: ItemListControllerTitle, leftNavigationButton: ItemListNavigationButton?, rightNavigationButton: ItemListNavigationButton?, secondaryRightNavigationButton: ItemListNavigationButton? = nil, backNavigationButton: ItemListBackButton?, tabBarItem: ItemListControllerTabBarItem? = nil, animateChanges: Bool = true) {
        self.theme = theme
        self.title = title
        self.leftNavigationButton = leftNavigationButton
        self.rightNavigationButton = rightNavigationButton
        self.secondaryRightNavigationButton = secondaryRightNavigationButton
        self.backNavigationButton = backNavigationButton
        self.tabBarItem = tabBarItem
        self.animateChanges = animateChanges
    }
}

class ItemListController: ViewController, KeyShortcutResponder, PresentableController {
    private let state: Signal<(ItemListControllerState, (ItemListNodeState, Any)), NoError>
    
    private var leftNavigationButtonTitleAndStyle: (ItemListNavigationButtonContent, ItemListNavigationButtonStyle)?
    private var rightNavigationButtonTitleAndStyle: [(ItemListNavigationButtonContent, ItemListNavigationButtonStyle)] = []
    private var backNavigationButton: ItemListBackButton?
    private var tabBarItemInfo: ItemListControllerTabBarItem?
    private var navigationButtonActions: (left: (() -> Void)?, right: (() -> Void)?, secondaryRight: (() -> Void)?) = (nil, nil, nil)
    
    private var theme: WalletTheme
    private var strings: WalletStrings
    private var hasNavigationBarSeparator: Bool
    
    private var validLayout: ContainerViewLayout?
    
    private var didPlayPresentationAnimation = false
    private(set) var didAppearOnce = false
    var didAppear: ((Bool) -> Void)?
    private var isDismissed = false
    
    var titleControlValueChanged: ((Int) -> Void)?
    
    private var tabBarItemDisposable: Disposable?
    
    private let _ready = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    
    var experimentalSnapScrollToItem: Bool = false {
        didSet {
            if self.isNodeLoaded {
                (self.displayNode as! ItemListControllerNode).listNode.experimentalSnapScrollToItem = self.experimentalSnapScrollToItem
            }
        }
    }
    
    var enableInteractiveDismiss = false {
        didSet {
            if self.isNodeLoaded {
                (self.displayNode as! ItemListControllerNode).enableInteractiveDismiss = self.enableInteractiveDismiss
            }
        }
    }
    
    var alwaysSynchronous = false {
        didSet {
            if self.isNodeLoaded {
                (self.displayNode as! ItemListControllerNode).alwaysSynchronous = self.alwaysSynchronous
            }
        }
    }
    
    var visibleEntriesUpdated: ((ItemListNodeVisibleEntries) -> Void)? {
        didSet {
            if self.isNodeLoaded {
                (self.displayNode as! ItemListControllerNode).visibleEntriesUpdated = self.visibleEntriesUpdated
            }
        }
    }
    
    var visibleBottomContentOffsetChanged: ((ListViewVisibleContentOffset) -> Void)? {
        didSet {
            if self.isNodeLoaded {
                (self.displayNode as! ItemListControllerNode).visibleBottomContentOffsetChanged = self.visibleBottomContentOffsetChanged
            }
        }
    }
    
    var contentOffsetChanged: ((ListViewVisibleContentOffset, Bool) -> Void)? {
        didSet {
            if self.isNodeLoaded {
                (self.displayNode as! ItemListControllerNode).contentOffsetChanged = self.contentOffsetChanged
            }
        }
    }
    
    var contentScrollingEnded: ((ListView) -> Bool)? {
        didSet {
            if self.isNodeLoaded {
                (self.displayNode as! ItemListControllerNode).contentScrollingEnded = self.contentScrollingEnded
            }
        }
    }
    
    var searchActivated: ((Bool) -> Void)? {
        didSet {
            if self.isNodeLoaded {
                (self.displayNode as! ItemListControllerNode).searchActivated = self.searchActivated
            }
        }
    }
    
    var willScrollToTop: (() -> Void)?
    
    func setReorderEntry<T: ItemListNodeEntry>(_ f: @escaping (Int, Int, [T]) -> Void) {
        self.reorderEntry = { a, b, list in
            f(a, b, list.map { $0 as! T })
        }
    }
    private var reorderEntry: ((Int, Int, [ItemListNodeAnyEntry]) -> Void)? {
        didSet {
            if self.isNodeLoaded {
                (self.displayNode as! ItemListControllerNode).reorderEntry = self.reorderEntry
            }
        }
    }
    
    var previewItemWithTag: ((ItemListItemTag) -> UIViewController?)?
    var commitPreview: ((UIViewController) -> Void)?
    
    var willDisappear: ((Bool) -> Void)?
    var didDisappear: ((Bool) -> Void)?
    
    init<ItemGenerationArguments>(theme: WalletTheme, strings: WalletStrings, updatedPresentationData: Signal<(theme: WalletTheme, strings: WalletStrings), NoError>, state: Signal<(ItemListControllerState, (ItemListNodeState, ItemGenerationArguments)), NoError>, tabBarItem: Signal<ItemListControllerTabBarItem, NoError>?, hasNavigationBarSeparator: Bool = true) {
        self.state = state
        |> map { controllerState, nodeStateAndArgument -> (ItemListControllerState, (ItemListNodeState, Any)) in
            return (controllerState, (nodeStateAndArgument.0, nodeStateAndArgument.1))
        }
        
        self.theme = theme
        self.strings = strings
        self.hasNavigationBarSeparator = hasNavigationBarSeparator
        
        let navigationBarTheme: NavigationBarTheme
        if hasNavigationBarSeparator {
            navigationBarTheme = theme.navigationBar
        } else {
            navigationBarTheme = NavigationBarTheme(buttonColor: theme.navigationBar.buttonColor, disabledButtonColor: theme.navigationBar.disabledButtonColor, primaryTextColor: theme.navigationBar.primaryTextColor, backgroundColor: theme.list.itemBlocksBackgroundColor, separatorColor: theme.list.itemBlocksBackgroundColor, badgeBackgroundColor: theme.navigationBar.badgeBackgroundColor, badgeStrokeColor: theme.navigationBar.badgeStrokeColor, badgeTextColor: theme.navigationBar.badgeTextColor)
        }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: navigationBarTheme, strings: NavigationBarStrings(back: strings.Wallet_Navigation_Back, close: strings.Wallet_Navigation_Close)))
        
        self.isOpaqueWhenInOverlay = true
        self.blocksBackgroundWhenInOverlay = true
        
        self.statusBar.statusBarStyle = theme.statusBarStyle
        
        self.scrollToTop = { [weak self] in
            self?.willScrollToTop?()
            (self?.displayNode as! ItemListControllerNode).scrollToTop()
        }
        
        if let tabBarItem = tabBarItem {
            self.tabBarItemDisposable = (tabBarItem |> deliverOnMainQueue).start(next: { [weak self] tabBarItemInfo in
                if let strongSelf = self {
                    if strongSelf.tabBarItemInfo != tabBarItemInfo {
                        strongSelf.tabBarItemInfo = tabBarItemInfo
                        
                        strongSelf.tabBarItem.title = tabBarItemInfo.title
                        strongSelf.tabBarItem.image = tabBarItemInfo.image
                        strongSelf.tabBarItem.selectedImage = tabBarItemInfo.selectedImage
                        strongSelf.tabBarItem.badgeValue = tabBarItemInfo.badgeValue
                    }
                }
            })
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.tabBarItemDisposable?.dispose()
    }
    
    override func loadDisplayNode() {
        let previousControllerState = Atomic<ItemListControllerState?>(value: nil)
        let nodeState = self.state
        |> deliverOnMainQueue
        |> afterNext { [weak self] controllerState, state in
            Queue.mainQueue().async {
                if let strongSelf = self {
                    let previousState = previousControllerState.swap(controllerState)
                    if previousState?.title != controllerState.title {
                        switch controllerState.title {
                            case let .text(text):
                                strongSelf.title = text
                                strongSelf.navigationItem.titleView = nil
                        }
                    }
                    strongSelf.navigationButtonActions = (left: controllerState.leftNavigationButton?.action, right: controllerState.rightNavigationButton?.action, secondaryRight: controllerState.secondaryRightNavigationButton?.action)
                    
                    let themeUpdated = strongSelf.theme !== controllerState.theme
                    if strongSelf.leftNavigationButtonTitleAndStyle?.0 != controllerState.leftNavigationButton?.content || strongSelf.leftNavigationButtonTitleAndStyle?.1 != controllerState.leftNavigationButton?.style || themeUpdated {
                        if let leftNavigationButton = controllerState.leftNavigationButton {
                            let item: UIBarButtonItem
                            switch leftNavigationButton.content {
                                case .none:
                                    item = UIBarButtonItem(title: "", style: leftNavigationButton.style.barButtonItemStyle, target: strongSelf, action: #selector(strongSelf.leftNavigationButtonPressed))
                                case let .text(value):
                                    item = UIBarButtonItem(title: value, style: leftNavigationButton.style.barButtonItemStyle, target: strongSelf, action: #selector(strongSelf.leftNavigationButtonPressed))
                                case let .icon(icon):
                                    var image: UIImage?
                                    switch icon {
                                        case .search:
                                            image = nil
                                        case .add:
                                            image = nil
                                        case .action:
                                            image = nil
                                    }
                                    item = UIBarButtonItem(image: image, style: leftNavigationButton.style.barButtonItemStyle, target: strongSelf, action: #selector(strongSelf.leftNavigationButtonPressed))
                            }
                            strongSelf.leftNavigationButtonTitleAndStyle = (leftNavigationButton.content, leftNavigationButton.style)
                            strongSelf.navigationItem.setLeftBarButton(item, animated: false)
                            item.isEnabled = leftNavigationButton.enabled
                        } else {
                            strongSelf.leftNavigationButtonTitleAndStyle = nil
                            strongSelf.navigationItem.setLeftBarButton(nil, animated: false)
                        }
                    } else if let barButtonItem = strongSelf.navigationItem.leftBarButtonItem, let leftNavigationButton = controllerState.leftNavigationButton, leftNavigationButton.enabled != barButtonItem.isEnabled {
                        barButtonItem.isEnabled = leftNavigationButton.enabled
                    }
                    
                    var rightNavigationButtonTitleAndStyle: [(ItemListNavigationButtonContent, ItemListNavigationButtonStyle, Bool)] = []
                    if let secondaryRightNavigationButton = controllerState.secondaryRightNavigationButton {
                        rightNavigationButtonTitleAndStyle.append((secondaryRightNavigationButton.content, secondaryRightNavigationButton.style, secondaryRightNavigationButton.enabled))
                    }
                    if let rightNavigationButton = controllerState.rightNavigationButton {
                        rightNavigationButtonTitleAndStyle.append((rightNavigationButton.content, rightNavigationButton.style, rightNavigationButton.enabled))
                    }
                    
                    var updateRightButtonItems = false
                    if rightNavigationButtonTitleAndStyle.count != strongSelf.rightNavigationButtonTitleAndStyle.count {
                        updateRightButtonItems = true
                    } else {
                        for i in 0 ..< rightNavigationButtonTitleAndStyle.count {
                            if rightNavigationButtonTitleAndStyle[i].0 != strongSelf.rightNavigationButtonTitleAndStyle[i].0 || rightNavigationButtonTitleAndStyle[i].1 != strongSelf.rightNavigationButtonTitleAndStyle[i].1 {
                                updateRightButtonItems = true
                            }
                        }
                    }
                    
                    if updateRightButtonItems || themeUpdated {
                        strongSelf.rightNavigationButtonTitleAndStyle = rightNavigationButtonTitleAndStyle.map { ($0.0, $0.1) }
                        var items: [UIBarButtonItem] = []
                        var index = 0
                        for (content, style, _) in rightNavigationButtonTitleAndStyle {
                            let item: UIBarButtonItem
                            if case .activity = style {
                                item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: strongSelf.theme.navigationBar.buttonColor))
                            } else {
                                let action: Selector = (index == 0 && rightNavigationButtonTitleAndStyle.count > 1) ? #selector(strongSelf.secondaryRightNavigationButtonPressed) : #selector(strongSelf.rightNavigationButtonPressed)
                                switch content {
                                    case .none:
                                        item = UIBarButtonItem(title: "", style: style.barButtonItemStyle, target: strongSelf, action: action)
                                    case let .text(value):
                                        item = UIBarButtonItem(title: value, style: style.barButtonItemStyle, target: strongSelf, action: action)
                                    case let .icon(icon):
                                        var image: UIImage?
                                        switch icon {
                                            case .search:
                                                image = nil
                                            case .add:
                                                image = nil
                                            case .action:
                                                image = nil
                                        }
                                        item = UIBarButtonItem(image: image, style: style.barButtonItemStyle, target: strongSelf, action: action)
                                }
                            }
                            items.append(item)
                            index += 1
                        }
                        strongSelf.navigationItem.setRightBarButtonItems(items, animated: false)
                        index = 0
                        for (_, _, enabled) in rightNavigationButtonTitleAndStyle {
                            items[index].isEnabled = enabled
                            index += 1
                        }
                    } else {
                        for i in 0 ..< rightNavigationButtonTitleAndStyle.count {
                            strongSelf.navigationItem.rightBarButtonItems?[i].isEnabled = rightNavigationButtonTitleAndStyle[i].2
                        }
                    }
                    
                    if strongSelf.backNavigationButton != controllerState.backNavigationButton {
                        strongSelf.backNavigationButton = controllerState.backNavigationButton
                        
                        if let backNavigationButton = strongSelf.backNavigationButton {
                            strongSelf.navigationItem.backBarButtonItem = UIBarButtonItem(title: backNavigationButton.title, style: .plain, target: nil, action: nil)
                        } else {
                            strongSelf.navigationItem.backBarButtonItem = nil
                        }
                    }
                    
                    if strongSelf.theme !== controllerState.theme {
                        strongSelf.theme = controllerState.theme
                        
                        let navigationBarTheme: NavigationBarTheme
                        if strongSelf.hasNavigationBarSeparator {
                            navigationBarTheme = strongSelf.theme.navigationBar
                        } else {
                            navigationBarTheme = NavigationBarTheme(buttonColor: strongSelf.theme.navigationBar.buttonColor, disabledButtonColor: strongSelf.theme.navigationBar.disabledButtonColor, primaryTextColor: strongSelf.theme.navigationBar.primaryTextColor, backgroundColor: strongSelf.theme.list.itemBlocksBackgroundColor, separatorColor: strongSelf.theme.list.itemBlocksBackgroundColor, badgeBackgroundColor: strongSelf.theme.navigationBar.badgeBackgroundColor, badgeStrokeColor: strongSelf.theme.navigationBar.badgeStrokeColor, badgeTextColor: strongSelf.theme.navigationBar.badgeTextColor)
                        }
                        
                        strongSelf.navigationBar?.updatePresentationData(NavigationBarPresentationData(theme: navigationBarTheme, strings: NavigationBarStrings(back: strongSelf.strings.Wallet_Navigation_Back, close: strongSelf.strings.Wallet_Navigation_Close)))
                        strongSelf.statusBar.statusBarStyle = strongSelf.theme.statusBarStyle
                        
                        var items = strongSelf.navigationItem.rightBarButtonItems ?? []
                        for i in 0 ..< strongSelf.rightNavigationButtonTitleAndStyle.count {
                            if case .activity = strongSelf.rightNavigationButtonTitleAndStyle[i].1 {
                                items[i] = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: strongSelf.theme.navigationBar.buttonColor))!
                            }
                        }
                        strongSelf.navigationItem.setRightBarButtonItems(items, animated: false)
                    }
                }
            }
        } |> map { ($0.theme, $1) }
        let displayNode = ItemListControllerNode(controller: self, navigationBar: self.navigationBar!, updateNavigationOffset: { [weak self] offset in
            if let strongSelf = self {
                strongSelf.navigationOffset = offset
            }
        }, state: nodeState)
        displayNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: true, completion: nil)
        }
        displayNode.enableInteractiveDismiss = self.enableInteractiveDismiss
        displayNode.alwaysSynchronous = self.alwaysSynchronous
        displayNode.visibleEntriesUpdated = self.visibleEntriesUpdated
        displayNode.visibleBottomContentOffsetChanged = self.visibleBottomContentOffsetChanged
        displayNode.contentOffsetChanged = self.contentOffsetChanged
        displayNode.contentScrollingEnded = self.contentScrollingEnded
        displayNode.searchActivated = self.searchActivated
        displayNode.reorderEntry = self.reorderEntry
        displayNode.listNode.experimentalSnapScrollToItem = self.experimentalSnapScrollToItem
        displayNode.requestLayout = { [weak self] transition in
            self?.requestLayout(transition: transition)
        }
        self.displayNode = displayNode
        super.displayNodeDidLoad()
        self._ready.set((self.displayNode as! ItemListControllerNode).ready)
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.validLayout = layout
        
        (self.displayNode as! ItemListControllerNode).containerLayoutUpdated(layout, navigationBarHeight: self.navigationInsetHeight, transition: transition)
    }

    @objc func leftNavigationButtonPressed() {
        self.navigationButtonActions.left?()
    }
    
    @objc func rightNavigationButtonPressed() {
        self.navigationButtonActions.right?()
    }
    
    @objc func secondaryRightNavigationButtonPressed() {
        self.navigationButtonActions.secondaryRight?()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.viewDidAppear(completion: {})
    }
    
    func viewDidAppear(completion: @escaping () -> Void) {
        (self.displayNode as! ItemListControllerNode).listNode.preloadPages = true
        
        if let presentationArguments = self.presentationArguments as? ViewControllerPresentationArguments, !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            if case .modalSheet = presentationArguments.presentationAnimation {
                (self.displayNode as! ItemListControllerNode).animateIn(completion: {
                    presentationArguments.completion?()
                    completion()
                })
                self.updateTransitionWhenPresentedAsModal?(1.0, .animated(duration: 0.5, curve: .spring))
            } else {
                completion()
            }
        } else {
            completion()
        }
        
        let firstTime = !self.didAppearOnce
        self.didAppearOnce = true
        self.didAppear?(firstTime)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.willDisappear?(animated)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.didDisappear?(animated)
    }
    
    func frameForItemNode(_ predicate: (ListViewItemNode) -> Bool) -> CGRect? {
        var result: CGRect?
        (self.displayNode as! ItemListControllerNode).listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ListViewItemNode {
                if predicate(itemNode) {
                    result = itemNode.convert(itemNode.bounds, to: self.displayNode)
                }
            }
        }
        return result
    }
    
    func forEachItemNode(_ f: (ListViewItemNode) -> Void) {
        (self.displayNode as! ItemListControllerNode).listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ListViewItemNode {
                f(itemNode)
            }
        }
    }
    
    func ensureItemNodeVisible(_ itemNode: ListViewItemNode, animated: Bool = true) {
        (self.displayNode as! ItemListControllerNode).listNode.ensureItemNodeVisible(itemNode, animated: animated)
    }
    
    func afterLayout(_ f: @escaping () -> Void) {
        (self.displayNode as! ItemListControllerNode).afterLayout(f)
    }
    
    func previewingController(from sourceView: UIView, for location: CGPoint) -> (UIViewController, CGRect)? {
        guard let layout = self.validLayout, case .phone = layout.deviceMetrics.type else {
            return nil
        }
        
        let boundsSize = self.view.bounds.size
        let contentSize: CGSize
        if case .unknown = layout.deviceMetrics {
            contentSize = boundsSize
        } else {
            contentSize = layout.deviceMetrics.previewingContentSize(inLandscape: boundsSize.width > boundsSize.height)
        }
        
        var selectedNode: ItemListItemNode?
        let listLocation = self.view.convert(location, to:  (self.displayNode as! ItemListControllerNode).listNode.view)
        (self.displayNode as! ItemListControllerNode).listNode.forEachItemNode { itemNode in
            if itemNode.frame.contains(listLocation), let itemNode = itemNode as? ItemListItemNode {
                selectedNode = itemNode
            }
        }
        if let selectedNode = selectedNode as? (ItemListItemNode & ListViewItemNode), let tag = selectedNode.tag {
            var sourceRect = selectedNode.view.superview!.convert(selectedNode.frame, to: sourceView)
            sourceRect.size.height -= UIScreenPixel
            
            if let controller = self.previewItemWithTag?(tag) {
                if let controller = controller as? ContainableController {
                    controller.containerLayoutUpdated(ContainerViewLayout(size: contentSize, metrics: LayoutMetrics(), deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: .immediate)
                }
                return (controller, sourceRect)
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    func clearItemNodesHighlight(animated: Bool = false) {
        (self.displayNode as! ItemListControllerNode).listNode.clearHighlightAnimated(animated)
    }
    
    func previewingCommit(_ viewControllerToCommit: UIViewController) {
        self.commitPreview?(viewControllerToCommit)
    }
    
    var keyShortcuts: [KeyShortcut] {
        return [KeyShortcut(input: UIKeyCommand.inputEscape, action: { [weak self] in
            if !(self?.navigationController?.topViewController is TabBarController) {
                _ = self?.navigationBar?.executeBack()
            }
        })]
    }
}
