import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData

enum ItemListNavigationButtonStyle {
    case regular
    case bold
    case activity
    
    var barButtonItemStyle: UIBarButtonItemStyle {
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
}

enum ItemListNavigationButtonContent: Equatable {
    case none
    case text(String)
    case icon(ItemListNavigationButtonContentIcon)
    
    static func ==(lhs: ItemListNavigationButtonContent, rhs: ItemListNavigationButtonContent) -> Bool {
        switch lhs {
            case .none:
                if case .none = rhs {
                    return true
                } else {
                    return false
                }
            case let .text(value):
                if case .text(value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .icon(value):
                if case .icon(value) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

struct ItemListNavigationButton {
    let content: ItemListNavigationButtonContent
    let style: ItemListNavigationButtonStyle
    let enabled: Bool
    let action: () -> Void
}

struct ItemListBackButton: Equatable {
    let title: String
    
    static func ==(lhs: ItemListBackButton, rhs: ItemListBackButton) -> Bool {
        return lhs.title == rhs.title
    }
}

enum ItemListControllerTitle: Equatable {
    case text(String)
    case sectionControl([String], Int)
    
    static func ==(lhs: ItemListControllerTitle, rhs: ItemListControllerTitle) -> Bool {
        switch lhs {
            case let .text(text):
                if case .text(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .sectionControl(lhsSection, lhsIndex):
                if case let .sectionControl(rhsSection, rhsIndex) = rhs, lhsSection == rhsSection, lhsIndex == rhsIndex {
                    return true
                } else {
                    return false
                }
        }
    }
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
    let theme: PresentationTheme
    let title: ItemListControllerTitle
    let leftNavigationButton: ItemListNavigationButton?
    let rightNavigationButton: ItemListNavigationButton?
    let secondaryRightNavigationButton: ItemListNavigationButton?
    let backNavigationButton: ItemListBackButton?
    let tabBarItem: ItemListControllerTabBarItem?
    let animateChanges: Bool
    
    init(theme: PresentationTheme, title: ItemListControllerTitle, leftNavigationButton: ItemListNavigationButton?, rightNavigationButton: ItemListNavigationButton?, secondaryRightNavigationButton: ItemListNavigationButton? = nil, backNavigationButton: ItemListBackButton?, tabBarItem: ItemListControllerTabBarItem? = nil, animateChanges: Bool = true) {
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

class ItemListController<Entry: ItemListNodeEntry>: ViewController, KeyShortcutResponder, PresentableController {
    private let state: Signal<(ItemListControllerState, (ItemListNodeState<Entry>, Entry.ItemGenerationArguments)), NoError>
    
    private var leftNavigationButtonTitleAndStyle: (ItemListNavigationButtonContent, ItemListNavigationButtonStyle)?
    private var rightNavigationButtonTitleAndStyle: [(ItemListNavigationButtonContent, ItemListNavigationButtonStyle)] = []
    private var backNavigationButton: ItemListBackButton?
    private var tabBarItemInfo: ItemListControllerTabBarItem?
    private var navigationButtonActions: (left: (() -> Void)?, right: (() -> Void)?, secondaryRight: (() -> Void)?) = (nil, nil, nil)
    private var segmentedTitleView: ItemListControllerSegmentedTitleView?
    
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    
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
                (self.displayNode as! ItemListControllerNode<Entry>).listNode.experimentalSnapScrollToItem = self.experimentalSnapScrollToItem
            }
        }
    }
    
    var enableInteractiveDismiss = false {
        didSet {
            if self.isNodeLoaded {
                (self.displayNode as! ItemListControllerNode<Entry>).enableInteractiveDismiss = self.enableInteractiveDismiss
            }
        }
    }
    
    var visibleEntriesUpdated: ((ItemListNodeVisibleEntries<Entry>) -> Void)? {
        didSet {
            if self.isNodeLoaded {
                (self.displayNode as! ItemListControllerNode<Entry>).visibleEntriesUpdated = self.visibleEntriesUpdated
            }
        }
    }
    
    var visibleBottomContentOffsetChanged: ((ListViewVisibleContentOffset) -> Void)? {
        didSet {
            if self.isNodeLoaded {
                (self.displayNode as! ItemListControllerNode<Entry>).visibleBottomContentOffsetChanged = self.visibleBottomContentOffsetChanged
            }
        }
    }
    
    var contentOffsetChanged: ((ListViewVisibleContentOffset, Bool) -> Void)? {
        didSet {
            if self.isNodeLoaded {
                (self.displayNode as! ItemListControllerNode<Entry>).contentOffsetChanged = self.contentOffsetChanged
            }
        }
    }
    var contentScrollingEnded: ((ListView) -> Bool)? {
        didSet {
            if self.isNodeLoaded {
                (self.displayNode as! ItemListControllerNode<Entry>).contentScrollingEnded = self.contentScrollingEnded
            }
        }
    }
    
    var searchActivated: ((Bool) -> Void)? {
        didSet {
            if self.isNodeLoaded {
                (self.displayNode as! ItemListControllerNode<Entry>).searchActivated = self.searchActivated
            }
        }
    }
    
    var willScrollToTop: (() -> Void)?
    
    var reorderEntry: ((Int, Int, [Entry]) -> Void)? {
        didSet {
            if self.isNodeLoaded {
                (self.displayNode as! ItemListControllerNode<Entry>).reorderEntry = self.reorderEntry
            }
        }
    }
    
    var previewItemWithTag: ((ItemListItemTag) -> UIViewController?)?
    var commitPreview: ((UIViewController) -> Void)?
    
    var willDisappear: ((Bool) -> Void)?
    var didDisappear: ((Bool) -> Void)?
    
    convenience init(context: AccountContext, state: Signal<(ItemListControllerState, (ItemListNodeState<Entry>, Entry.ItemGenerationArguments)), NoError>, tabBarItem: Signal<ItemListControllerTabBarItem, NoError>? = nil) {
        self.init(sharedContext: context.sharedContext, state: state, tabBarItem: tabBarItem)
    }
    
    convenience init(sharedContext: SharedAccountContext, state: Signal<(ItemListControllerState, (ItemListNodeState<Entry>, Entry.ItemGenerationArguments)), NoError>, tabBarItem: Signal<ItemListControllerTabBarItem, NoError>? = nil) {
        let presentationData = sharedContext.currentPresentationData.with { $0 }
        self.init(theme: presentationData.theme, strings: presentationData.strings, updatedPresentationData: sharedContext.presentationData |> map { ($0.theme, $0.strings) }, state: state, tabBarItem: tabBarItem)
    }
    
    init(theme: PresentationTheme, strings: PresentationStrings, updatedPresentationData: Signal<(theme: PresentationTheme, strings: PresentationStrings), NoError>, state: Signal<(ItemListControllerState, (ItemListNodeState<Entry>, Entry.ItemGenerationArguments)), NoError>, tabBarItem: Signal<ItemListControllerTabBarItem, NoError>?) {
        self.state = state
        
        self.theme = theme
        self.strings = strings
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(rootControllerTheme: theme), strings: NavigationBarStrings(presentationStrings: strings)))
        
        self.isOpaqueWhenInOverlay = true
        self.blocksBackgroundWhenInOverlay = true
        
        self.statusBar.statusBarStyle = theme.rootController.statusBarStyle.style
        
        self.scrollToTop = { [weak self] in
            self?.willScrollToTop?()
            (self?.displayNode as! ItemListControllerNode<Entry>).scrollToTop()
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
                                strongSelf.segmentedTitleView = nil
                            case let .sectionControl(sections, index):
                                strongSelf.title = ""
                                if let segmentedTitleView = strongSelf.segmentedTitleView, segmentedTitleView.segments == sections {
                                    segmentedTitleView.index = index
                                } else {
                                    let segmentedTitleView = ItemListControllerSegmentedTitleView(segments: sections, index: index, color: controllerState.theme.rootController.navigationBar.accentTextColor)
                                    strongSelf.segmentedTitleView = segmentedTitleView
                                    strongSelf.navigationItem.titleView = strongSelf.segmentedTitleView
                                    segmentedTitleView.indexUpdated = { index in
                                        if let strongSelf = self {
                                            strongSelf.titleControlValueChanged?(index)
                                        }
                                    }
                                }
                        }
                    }
                    strongSelf.navigationButtonActions = (left: controllerState.leftNavigationButton?.action, right: controllerState.rightNavigationButton?.action, secondaryRight: controllerState.secondaryRightNavigationButton?.action)
                    
                    if strongSelf.leftNavigationButtonTitleAndStyle?.0 != controllerState.leftNavigationButton?.content || strongSelf.leftNavigationButtonTitleAndStyle?.1 != controllerState.leftNavigationButton?.style {
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
                                            image = PresentationResourcesRootController.navigationCompactSearchIcon(controllerState.theme)
                                        case .add:
                                            image = PresentationResourcesRootController.navigationAddIcon(controllerState.theme)
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
                    
                    if updateRightButtonItems {
                        strongSelf.rightNavigationButtonTitleAndStyle = rightNavigationButtonTitleAndStyle.map { ($0.0, $0.1) }
                        var items: [UIBarButtonItem] = []
                        var index = 0
                        for (content, style, _) in rightNavigationButtonTitleAndStyle {
                            let item: UIBarButtonItem
                            if case .activity = style {
                                item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(theme: controllerState.theme))
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
                                                image = PresentationResourcesRootController.navigationCompactSearchIcon(controllerState.theme)
                                            case .add:
                                                image = PresentationResourcesRootController.navigationAddIcon(controllerState.theme)
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
                        
                        strongSelf.navigationBar?.updatePresentationData(NavigationBarPresentationData(theme: NavigationBarTheme(rootControllerTheme: strongSelf.theme), strings: NavigationBarStrings(presentationStrings: strongSelf.strings)))
                        strongSelf.statusBar.statusBarStyle = strongSelf.theme.rootController.statusBarStyle.style
                        
                        strongSelf.segmentedTitleView?.color = controllerState.theme.rootController.navigationBar.accentTextColor
                        
                        var items = strongSelf.navigationItem.rightBarButtonItems ?? []
                        for i in 0 ..< strongSelf.rightNavigationButtonTitleAndStyle.count {
                            if case .activity = strongSelf.rightNavigationButtonTitleAndStyle[i].1 {
                                items[i] = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(theme: controllerState.theme))!
                            }
                        }
                        strongSelf.navigationItem.setRightBarButtonItems(items, animated: false)
                    }
                }
            }
        } |> map { ($0.theme, $1) }
        let displayNode = ItemListControllerNode<Entry>(controller: self, navigationBar: self.navigationBar!, updateNavigationOffset: { [weak self] offset in
            if let strongSelf = self {
                strongSelf.navigationOffset = offset
            }
        }, state: nodeState)
        displayNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: true, completion: nil)
        }
        displayNode.enableInteractiveDismiss = self.enableInteractiveDismiss
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
        self._ready.set((self.displayNode as! ItemListControllerNode<Entry>).ready)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.validLayout = layout
        
        (self.displayNode as! ItemListControllerNode<Entry>).containerLayoutUpdated(layout, navigationBarHeight: self.navigationInsetHeight, transition: transition)
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
        (self.displayNode as! ItemListControllerNode<Entry>).listNode.preloadPages = true
        
        if let presentationArguments = self.presentationArguments as? ViewControllerPresentationArguments, !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            if case .modalSheet = presentationArguments.presentationAnimation {
                (self.displayNode as! ItemListControllerNode<Entry>).animateIn(completion: {
                    presentationArguments.completion?()
                    completion()
                })
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
    
    override func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            (self.displayNode as! ItemListControllerNode<Entry>).animateOut(completion: completion)
        }
    }
    
    func frameForItemNode(_ predicate: (ListViewItemNode) -> Bool) -> CGRect? {
        var result: CGRect?
        (self.displayNode as! ItemListControllerNode<Entry>).listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ListViewItemNode {
                if predicate(itemNode) {
                    result = itemNode.convert(itemNode.bounds, to: self.displayNode)
                }
            }
        }
        return result
    }
    
    func forEachItemNode(_ f: (ListViewItemNode) -> Void) {
        (self.displayNode as! ItemListControllerNode<Entry>).listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ListViewItemNode {
                f(itemNode)
            }
        }
    }
    
    func ensureItemNodeVisible(_ itemNode: ListViewItemNode) {
        (self.displayNode as! ItemListControllerNode<Entry>).listNode.ensureItemNodeVisible(itemNode)
    }
    
    func afterLayout(_ f: @escaping () -> Void) {
        (self.displayNode as! ItemListControllerNode<Entry>).afterLayout(f)
    }
    
    func previewingController(from sourceView: UIView, for location: CGPoint) -> (UIViewController, CGRect)? {
        guard let layout = self.validLayout else {
            return nil
        }
        
        let boundsSize = self.view.bounds.size
        let contentSize: CGSize
        if let metrics = DeviceMetrics.forScreenSize(layout.size) {
            contentSize = metrics.previewingContentSize(inLandscape: boundsSize.width > boundsSize.height)
        } else {
            contentSize = boundsSize
        }
        
        var selectedNode: ItemListItemNode?
        let listLocation = self.view.convert(location, to:  (self.displayNode as! ItemListControllerNode<Entry>).listNode.view)
        (self.displayNode as! ItemListControllerNode<Entry>).listNode.forEachItemNode { itemNode in
            if itemNode.frame.contains(listLocation), let itemNode = itemNode as? ItemListItemNode {
                selectedNode = itemNode
            }
        }
        if let selectedNode = selectedNode as? (ItemListItemNode & ListViewItemNode), let tag = selectedNode.tag {
            var sourceRect = selectedNode.view.superview!.convert(selectedNode.frame, to: sourceView)
            sourceRect.size.height -= UIScreenPixel
            
            if let controller = self.previewItemWithTag?(tag) {
                if let controller = controller as? ContainableController {
                    controller.containerLayoutUpdated(ContainerViewLayout(size: contentSize, metrics: LayoutMetrics(), intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, standardInputHeight: 216.0, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: .immediate)
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
        (self.displayNode as! ItemListControllerNode<Entry>).listNode.clearHighlightAnimated(animated)
    }
    
    func previewingCommit(_ viewControllerToCommit: UIViewController) {
        self.commitPreview?(viewControllerToCommit)
    }
    
    public var keyShortcuts: [KeyShortcut] {
        return [KeyShortcut(input: UIKeyInputEscape, action: { [weak self] in
            if !(self?.navigationController?.topViewController is TabBarController) {
                _ = self?.navigationBar?.executeBack()
            }
        })]
    }
}
