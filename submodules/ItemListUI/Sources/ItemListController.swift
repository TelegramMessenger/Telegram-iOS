import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import ProgressNavigationButtonNode

public enum ItemListNavigationButtonStyle {
    case regular
    case bold
    case activity
    
    public var barButtonItemStyle: UIBarButtonItem.Style {
        switch self {
        case .regular, .activity:
            return .plain
        case .bold:
            return .done
        }
    }
}

public enum ItemListNavigationButtonContentIcon {
    case search
    case add
    case action
}

public enum ItemListNavigationButtonContent: Equatable {
    case none
    case text(String)
    case icon(ItemListNavigationButtonContentIcon)
    case node(ASDisplayNode)
}

public struct ItemListNavigationButton {
    public let content: ItemListNavigationButtonContent
    public let style: ItemListNavigationButtonStyle
    public let enabled: Bool
    public let action: () -> Void
    
    public init(content: ItemListNavigationButtonContent, style: ItemListNavigationButtonStyle, enabled: Bool, action: @escaping () -> Void) {
        self.content = content
        self.style = style
        self.enabled = enabled
        self.action = action
    }
}

public struct ItemListBackButton: Equatable {
    public let title: String
    
    public init(title: String) {
        self.title = title
    }
}

public enum ItemListControllerTitle: Equatable {
    case text(String)
    case textWithSubtitle(String, String)
    case sectionControl([String], Int)
}

public final class ItemListControllerTabBarItem: Equatable {
    let title: String
    let image: UIImage?
    let selectedImage: UIImage?
    let tintImages: Bool
    let badgeValue: String?
    
    public init(title: String, image: UIImage?, selectedImage: UIImage?, tintImages: Bool = true, badgeValue: String? = nil) {
        self.title = title
        self.image = image
        self.selectedImage = selectedImage
        self.tintImages = tintImages
        self.badgeValue = badgeValue
    }
    
    public static func ==(lhs: ItemListControllerTabBarItem, rhs: ItemListControllerTabBarItem) -> Bool {
        return lhs.title == rhs.title && lhs.image === rhs.image && lhs.selectedImage === rhs.selectedImage && lhs.tintImages == rhs.tintImages && lhs.badgeValue == rhs.badgeValue
    }
}

public struct ItemListControllerState {
    let presentationData: ItemListPresentationData
    let title: ItemListControllerTitle
    let leftNavigationButton: ItemListNavigationButton?
    let rightNavigationButton: ItemListNavigationButton?
    let secondaryRightNavigationButton: ItemListNavigationButton?
    let backNavigationButton: ItemListBackButton?
    let tabBarItem: ItemListControllerTabBarItem?
    let animateChanges: Bool
    
    public init(presentationData: ItemListPresentationData, title: ItemListControllerTitle, leftNavigationButton: ItemListNavigationButton?, rightNavigationButton: ItemListNavigationButton?, secondaryRightNavigationButton: ItemListNavigationButton? = nil, backNavigationButton: ItemListBackButton?, tabBarItem: ItemListControllerTabBarItem? = nil, animateChanges: Bool = true) {
        self.presentationData = presentationData
        self.title = title
        self.leftNavigationButton = leftNavigationButton
        self.rightNavigationButton = rightNavigationButton
        self.secondaryRightNavigationButton = secondaryRightNavigationButton
        self.backNavigationButton = backNavigationButton
        self.tabBarItem = tabBarItem
        self.animateChanges = animateChanges
    }
}

open class ItemListController: ViewController, KeyShortcutResponder, PresentableController {
    private let state: Signal<(ItemListControllerState, (ItemListNodeState, Any)), NoError>
    
    private var leftNavigationButtonTitleAndStyle: (ItemListNavigationButtonContent, ItemListNavigationButtonStyle)?
    private var rightNavigationButtonTitleAndStyle: [(ItemListNavigationButtonContent, ItemListNavigationButtonStyle)] = []
    private var backNavigationButton: ItemListBackButton?
    private var tabBarItemInfo: ItemListControllerTabBarItem?
    private var navigationButtonActions: (left: (() -> Void)?, right: (() -> Void)?, secondaryRight: (() -> Void)?) = (nil, nil, nil)
    private var segmentedTitleView: ItemListControllerSegmentedTitleView?
    
    private var presentationData: ItemListPresentationData
    
    private var validLayout: ContainerViewLayout?
    
    public var additionalInsets: UIEdgeInsets = UIEdgeInsets()
    
    private var didPlayPresentationAnimation = false
    public private(set) var didAppearOnce = false
    public var didAppear: ((Bool) -> Void)?
    private var isDismissed = false
    
    public var titleControlValueChanged: ((Int) -> Void)?
    
    private var tabBarItemDisposable: Disposable?
    
    private let _ready = Promise<Bool>()
    override open var ready: Promise<Bool> {
        return self._ready
    }
    
    public var experimentalSnapScrollToItem: Bool = false {
        didSet {
            if self.isNodeLoaded {
                (self.displayNode as! ItemListControllerNode).listNode.experimentalSnapScrollToItem = self.experimentalSnapScrollToItem
            }
        }
    }
    
    public var enableInteractiveDismiss = false {
        didSet {
            if self.isNodeLoaded {
                (self.displayNode as! ItemListControllerNode).enableInteractiveDismiss = self.enableInteractiveDismiss
            }
        }
    }
    
    public var alwaysSynchronous = false {
        didSet {
            if self.isNodeLoaded {
                (self.displayNode as! ItemListControllerNode).alwaysSynchronous = self.alwaysSynchronous
            }
        }
    }
    
    public var visibleEntriesUpdated: ((ItemListNodeVisibleEntries) -> Void)? {
        didSet {
            if self.isNodeLoaded {
                (self.displayNode as! ItemListControllerNode).visibleEntriesUpdated = self.visibleEntriesUpdated
            }
        }
    }
    
    public var beganInteractiveDragging: (() -> Void)? {
        didSet {
            if self.isNodeLoaded {
                (self.displayNode as! ItemListControllerNode).beganInteractiveDragging = self.beganInteractiveDragging
            }
        }
    }
    
    public var visibleBottomContentOffset: ListViewVisibleContentOffset {
        if self.isNodeLoaded {
            return (self.displayNode as! ItemListControllerNode).listNode.visibleBottomContentOffset()
        } else {
            return .unknown
        }
    }
    public var visibleBottomContentOffsetChanged: ((ListViewVisibleContentOffset) -> Void)? {
        didSet {
            if self.isNodeLoaded {
                (self.displayNode as! ItemListControllerNode).visibleBottomContentOffsetChanged = self.visibleBottomContentOffsetChanged
            }
        }
    }
    
    public var contentOffsetChanged: ((ListViewVisibleContentOffset, Bool) -> Void)? {
        didSet {
            if self.isNodeLoaded {
                (self.displayNode as! ItemListControllerNode).contentOffsetChanged = self.contentOffsetChanged
            }
        }
    }
    
    public var contentScrollingEnded: ((ListView) -> Bool)? {
        didSet {
            if self.isNodeLoaded {
                (self.displayNode as! ItemListControllerNode).contentScrollingEnded = self.contentScrollingEnded
            }
        }
    }
    
    public var searchActivated: ((Bool) -> Void)? {
        didSet {
            if self.isNodeLoaded {
                (self.displayNode as! ItemListControllerNode).searchActivated = self.searchActivated
            }
        }
    }
    
    public var didScrollWithOffset: ((CGFloat, ContainedViewLayoutTransition, ListViewItemNode?) -> Void)? {
        didSet {
            if self.isNodeLoaded {
                (self.displayNode as! ItemListControllerNode).listNode.didScrollWithOffset = self.didScrollWithOffset
            }
        }
    }
    
    public var willScrollToTop: (() -> Void)?
    
    public func setReorderEntry<T: ItemListNodeEntry>(_ f: @escaping (Int, Int, [T]) -> Signal<Bool, NoError>) {
        self.reorderEntry = { a, b, list in
            return f(a, b, list.map { $0 as! T })
        }
    }
    private var reorderEntry: ((Int, Int, [ItemListNodeAnyEntry]) -> Signal<Bool, NoError>)? {
        didSet {
            if self.isNodeLoaded {
                (self.displayNode as! ItemListControllerNode).reorderEntry = self.reorderEntry
            }
        }
    }
    
    public func setReorderCompleted<T: ItemListNodeEntry>(_ f: @escaping ([T]) -> Void) {
        self.reorderCompleted = { list in
            f(list.map { $0 as! T })
        }
    }
    private var reorderCompleted: (([ItemListNodeAnyEntry]) -> Void)? {
        didSet {
            if self.isNodeLoaded {
                (self.displayNode as! ItemListControllerNode).reorderCompleted = self.reorderCompleted
            }
        }
    }
    
    public var willDisappear: ((Bool) -> Void)?
    public var didDisappear: ((Bool) -> Void)?
    
    public init<ItemGenerationArguments>(presentationData: ItemListPresentationData, updatedPresentationData: Signal<ItemListPresentationData, NoError>, state: Signal<(ItemListControllerState, (ItemListNodeState, ItemGenerationArguments)), NoError>, tabBarItem: Signal<ItemListControllerTabBarItem, NoError>?) {
        self.state = state
        |> map { controllerState, nodeStateAndArgument -> (ItemListControllerState, (ItemListNodeState, Any)) in
            return (controllerState, (nodeStateAndArgument.0, nodeStateAndArgument.1))
        }
        
        self.presentationData = presentationData
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(rootControllerTheme: presentationData.theme), strings: NavigationBarStrings(presentationStrings: presentationData.strings)))
        
        self.isOpaqueWhenInOverlay = true
        self.blocksBackgroundWhenInOverlay = true
        
        self.statusBar.statusBarStyle = presentationData.theme.rootController.statusBarStyle.style
        
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
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.tabBarItemDisposable?.dispose()
    }
    
    override open func loadDisplayNode() {
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
                            case let .textWithSubtitle(title, subtitle):
                                strongSelf.title = ""
                                strongSelf.navigationItem.titleView = ItemListTextWithSubtitleTitleView(theme: controllerState.presentationData.theme, title: title, subtitle: subtitle)
                                strongSelf.segmentedTitleView = nil
                            case let .sectionControl(sections, index):
                                strongSelf.title = ""
                                if let segmentedTitleView = strongSelf.segmentedTitleView, segmentedTitleView.segments == sections {
                                    segmentedTitleView.index = index
                                } else {
                                    let segmentedTitleView = ItemListControllerSegmentedTitleView(theme: controllerState.presentationData.theme, segments: sections, selectedIndex: index)
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
                    
                    let themeUpdated = strongSelf.presentationData != controllerState.presentationData
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
                                            image = PresentationResourcesRootController.navigationCompactSearchIcon(controllerState.presentationData.theme)
                                        case .add:
                                            image = PresentationResourcesRootController.navigationAddIcon(controllerState.presentationData.theme)
                                        case .action:
                                            image = PresentationResourcesRootController.navigationShareIcon(controllerState.presentationData.theme)
                                    }
                                    item = UIBarButtonItem(image: image, style: leftNavigationButton.style.barButtonItemStyle, target: strongSelf, action: #selector(strongSelf.leftNavigationButtonPressed))
                                case let .node(node):
                                    item = UIBarButtonItem(customDisplayNode: node)
                                    item.setCustomAction({ [weak self] in
                                        self?.navigationButtonActions.0?()
                                    })
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
                                item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: controllerState.presentationData.theme.rootController.navigationBar.controlColor))
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
                                                image = PresentationResourcesRootController.navigationCompactSearchIcon(controllerState.presentationData.theme)
                                            case .add:
                                                image = PresentationResourcesRootController.navigationAddIcon(controllerState.presentationData.theme)
                                            case .action:
                                                image = PresentationResourcesRootController.navigationShareIcon(controllerState.presentationData.theme)
                                        }
                                        item = UIBarButtonItem(image: image, style: style.barButtonItemStyle, target: strongSelf, action: action)
                                    case let .node(node):
                                        item = UIBarButtonItem(customDisplayNode: node)
                                        item.setCustomAction({ [weak self] in
                                            self?.navigationButtonActions.1?()
                                        })
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
                    
                    if strongSelf.presentationData != controllerState.presentationData {
                        strongSelf.presentationData = controllerState.presentationData
                        
                        strongSelf.navigationBar?.updatePresentationData(NavigationBarPresentationData(theme: NavigationBarTheme(rootControllerTheme: strongSelf.presentationData.theme), strings: NavigationBarStrings(presentationStrings: strongSelf.presentationData.strings)))
                        strongSelf.statusBar.updateStatusBarStyle(strongSelf.presentationData.theme.rootController.statusBarStyle.style, animated: true)
                        
                        strongSelf.segmentedTitleView?.theme = controllerState.presentationData.theme
                        
                        if let titleView = strongSelf.navigationItem.titleView as? ItemListTextWithSubtitleTitleView {
                            titleView.updateTheme(theme: controllerState.presentationData.theme)
                        }
                        
                        var items = strongSelf.navigationItem.rightBarButtonItems ?? []
                        for i in 0 ..< strongSelf.rightNavigationButtonTitleAndStyle.count {
                            if case .activity = strongSelf.rightNavigationButtonTitleAndStyle[i].1 {
                                items[i] = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: controllerState.presentationData.theme.rootController.navigationBar.controlColor))!
                            }
                        }
                        strongSelf.navigationItem.setRightBarButtonItems(items, animated: false)
                    }
                }
            }
        }
        |> map { ($0.presentationData, $1) }
        
        let displayNode = ItemListControllerNode(controller: self, navigationBar: self.navigationBar!, state: nodeState)
        displayNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: true, completion: nil)
        }
        displayNode.enableInteractiveDismiss = self.enableInteractiveDismiss
        displayNode.alwaysSynchronous = self.alwaysSynchronous
        displayNode.visibleEntriesUpdated = self.visibleEntriesUpdated
        displayNode.beganInteractiveDragging = self.beganInteractiveDragging
        displayNode.visibleBottomContentOffsetChanged = self.visibleBottomContentOffsetChanged
        displayNode.contentOffsetChanged = self.contentOffsetChanged
        displayNode.contentScrollingEnded = self.contentScrollingEnded
        displayNode.searchActivated = self.searchActivated
        displayNode.reorderEntry = self.reorderEntry
        displayNode.reorderCompleted = self.reorderCompleted
        displayNode.listNode.experimentalSnapScrollToItem = self.experimentalSnapScrollToItem
        displayNode.listNode.didScrollWithOffset = self.didScrollWithOffset
        displayNode.requestLayout = { [weak self] transition in
            self?.requestLayout(transition: transition)
        }
        self.displayNode = displayNode
        super.displayNodeDidLoad()
        self._ready.set((self.displayNode as! ItemListControllerNode).ready)
    }
    
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.validLayout = layout
        
        (self.displayNode as! ItemListControllerNode).containerLayoutUpdated(layout, navigationBarHeight: self.cleanNavigationHeight, transition: transition, additionalInsets: self.additionalInsets)
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
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.viewDidAppear(completion: {})
    }
    
    public func viewDidAppear(completion: @escaping () -> Void) {
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
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.willDisappear?(animated)
    }
    
    override open func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.didDisappear?(animated)
    }
    
    public var listInsets: UIEdgeInsets {
        return (self.displayNode as! ItemListControllerNode).listNode.insets
    }
    
    public func frameForItemNode(_ predicate: (ListViewItemNode) -> Bool) -> CGRect? {
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
    
    public func forEachItemNode(_ f: (ListViewItemNode) -> Void) {
        (self.displayNode as! ItemListControllerNode).listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ListViewItemNode {
                f(itemNode)
            }
        }
    }
    
    public func ensureItemNodeVisible(_ itemNode: ListViewItemNode, animated: Bool = true, curve: ListViewAnimationCurve = .Default(duration: 0.25)) {
        (self.displayNode as! ItemListControllerNode).listNode.ensureItemNodeVisible(itemNode, animated: animated, curve: curve)
    }
    
    public func afterLayout(_ f: @escaping () -> Void) {
        (self.displayNode as! ItemListControllerNode).afterLayout(f)
    }
        
    public func clearItemNodesHighlight(animated: Bool = false) {
        (self.displayNode as! ItemListControllerNode).listNode.clearHighlightAnimated(animated)
    }
    
    public var keyShortcuts: [KeyShortcut] {
        return [KeyShortcut(input: UIKeyCommand.inputEscape, action: { [weak self] in
            if !(self?.navigationController?.topViewController is TabBarController) {
                _ = self?.navigationBar?.executeBack()
            }
        })]
    }
}

private final class ItemListTextWithSubtitleTitleView: UIView, NavigationBarTitleView {
    private let titleNode: ImmediateTextNode
    private let subtitleNode: ImmediateTextNode
    
    private var validLayout: (CGSize, CGRect)?
    
    init(theme: PresentationTheme, title: String, subtitle: String) {
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.isOpaque = false
        
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.medium(17.0), textColor: theme.rootController.navigationBar.primaryTextColor)
        
        self.subtitleNode = ImmediateTextNode()
        self.subtitleNode.displaysAsynchronously = false
        self.subtitleNode.maximumNumberOfLines = 1
        self.subtitleNode.isOpaque = false
        
        self.subtitleNode.attributedText = NSAttributedString(string: subtitle, font: Font.regular(13.0), textColor: theme.rootController.navigationBar.secondaryTextColor)
        
        super.init(frame: CGRect())
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateTheme(theme: PresentationTheme) {
        self.titleNode.attributedText = NSAttributedString(string: self.titleNode.attributedText?.string ?? "", font: Font.medium(17.0), textColor: theme.rootController.navigationBar.primaryTextColor)
        self.subtitleNode.attributedText = NSAttributedString(string: self.subtitleNode.attributedText?.string ?? "", font: Font.regular(13.0), textColor: theme.rootController.navigationBar.secondaryTextColor)
        if let (size, clearBounds) = self.validLayout {
            self.updateLayout(size: size, clearBounds: clearBounds, transition: .immediate)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if let (size, clearBounds) = self.validLayout {
            self.updateLayout(size: size, clearBounds: clearBounds, transition: .immediate)
        }
    }
    
    func updateLayout(size: CGSize, clearBounds: CGRect, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, clearBounds)
        
        let titleSize = self.titleNode.updateLayout(size)
        let subtitleSize = self.subtitleNode.updateLayout(size)
        let spacing: CGFloat = 0.0
        let contentHeight = titleSize.height + spacing + subtitleSize.height
        let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: floor((size.height - contentHeight) / 2.0)), size: titleSize)
        let subtitleFrame = CGRect(origin: CGPoint(x: floor((size.width - subtitleSize.width) / 2.0), y: titleFrame.maxY + spacing), size: subtitleSize)
            
        self.titleNode.frame = titleFrame
        self.subtitleNode.frame = subtitleFrame
    }
    
    func animateLayoutTransition() {
    }
}
