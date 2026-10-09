import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import ProgressNavigationButtonNode
import SideColumnLayout
import SideColumnBarButtons

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
    case close
    case done
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
    case textWithTabs(String, [String], Int)
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
    /// iPhone Duo: this screen lays out its own side column, back button included.
    override open var placesNavigationButtonInSideColumn: Bool {
        return false
    }
    
    var controllerNode: ItemListControllerNode {
        return (self.displayNode as! ItemListControllerNode)
    }
    
    private let state: Signal<(ItemListControllerState, (ItemListNodeState, Any)), NoError>
    
    private var leftNavigationButtonTitleAndStyle: (ItemListNavigationButtonContent, ItemListNavigationButtonStyle)?
    private var rightNavigationButtonTitleAndStyle: [(ItemListNavigationButtonContent, ItemListNavigationButtonStyle)] = []
    private var backNavigationButton: ItemListBackButton?
    private var tabBarItemInfo: ItemListControllerTabBarItem?
    private var navigationButtonActions: (left: (() -> Void)?, right: (() -> Void)?, secondaryRight: (() -> Void)?) = (nil, nil, nil)
    private var segmentedTitleView: ItemListControllerSegmentedTitleView?
    private var tabsNavigationContentNode: ItemListControllerTabsContentNode?
    
    // iPhone Duo: the bar's buttons as built from the state, in the bar's order; the bar gets the top row's
    // share while the side column shows the rest (docs/iphone-duo-layout.md).
    private var fullLeftBarButtonItem: UIBarButtonItem?
    private var fullRightBarButtonItems: [UIBarButtonItem] = []
    private var sideColumnLeftButton: ItemListNavigationButton?
    private var sideColumnRightButtons: [ItemListNavigationButton] = []
    
    private var presentationData: ItemListPresentationData
    private let hideNavigationBarBackground: Bool
    
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
                self.controllerNode.listNode.experimentalSnapScrollToItem = self.experimentalSnapScrollToItem
            }
        }
    }
    
    public var enableInteractiveDismiss = false {
        didSet {
            if self.isNodeLoaded {
                self.controllerNode.enableInteractiveDismiss = self.enableInteractiveDismiss
            }
        }
    }
    
    public var alwaysSynchronous = false {
        didSet {
            if self.isNodeLoaded {
                self.controllerNode.alwaysSynchronous = self.alwaysSynchronous
            }
        }
    }
    
    public var visibleEntriesUpdated: ((ItemListNodeVisibleEntries) -> Void)? {
        didSet {
            if self.isNodeLoaded {
                self.controllerNode.visibleEntriesUpdated = self.visibleEntriesUpdated
            }
        }
    }
    
    public var beganInteractiveDragging: (() -> Void)? {
        didSet {
            if self.isNodeLoaded {
                self.controllerNode.beganInteractiveDragging = self.beganInteractiveDragging
            }
        }
    }
    
    public var visibleBottomContentOffset: ListViewVisibleContentOffset {
        if self.isNodeLoaded {
            return self.controllerNode.listNode.visibleBottomContentOffset()
        } else {
            return .unknown
        }
    }
    public var visibleBottomContentOffsetChanged: ((ListViewVisibleContentOffset) -> Void)? {
        didSet {
            if self.isNodeLoaded {
                self.controllerNode.visibleBottomContentOffsetChanged = self.visibleBottomContentOffsetChanged
            }
        }
    }
    
    public var contentOffsetChanged: ((ListViewVisibleContentOffset, Bool) -> Void)? {
        didSet {
            if self.isNodeLoaded {
                self.controllerNode.contentOffsetChanged = self.contentOffsetChanged
            }
        }
    }
    
    public var contentScrollingEnded: ((ListView) -> Bool)? {
        didSet {
            if self.isNodeLoaded {
                self.controllerNode.contentScrollingEnded = self.contentScrollingEnded
            }
        }
    }
    
    public var searchActivated: ((Bool) -> Void)? {
        didSet {
            if self.isNodeLoaded {
                self.controllerNode.searchActivated = self.searchActivated
            }
        }
    }
    
    public var didScrollWithOffset: ((CGFloat, ContainedViewLayoutTransition, ListViewItemNode?, Bool) -> Void)? {
        didSet {
            if self.isNodeLoaded {
                self.controllerNode.listNode.didScrollWithOffset = self.didScrollWithOffset
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
                self.controllerNode.reorderEntry = self.reorderEntry
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
                self.controllerNode.reorderCompleted = self.reorderCompleted
            }
        }
    }
    
    public var willDisappear: ((Bool) -> Void)?
    public var didDisappear: ((Bool) -> Void)?
    public var afterTransactionCompleted: (() -> Void)? {
        didSet {
            if self.isNodeLoaded {
                self.controllerNode.afterTransactionCompleted = self.afterTransactionCompleted
            }
        }
    }
    
    public init<ItemGenerationArguments>(
        presentationData: ItemListPresentationData,
        updatedPresentationData: Signal<ItemListPresentationData, NoError>,
        state: Signal<(ItemListControllerState, (ItemListNodeState, ItemGenerationArguments)), NoError>,
        tabBarItem: Signal<ItemListControllerTabBarItem, NoError>?,
        hideNavigationBarBackground: Bool = false
    ) {
        self.state = state
        |> map { controllerState, nodeStateAndArgument -> (ItemListControllerState, (ItemListNodeState, Any)) in
            return (controllerState, (nodeStateAndArgument.0, nodeStateAndArgument.1))
        }
        
        self.presentationData = presentationData
        self.hideNavigationBarBackground = hideNavigationBarBackground
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(rootControllerTheme: presentationData.theme, hideBackground: hideNavigationBarBackground, hideSeparator: hideNavigationBarBackground, style: .glass), strings: NavigationBarStrings(presentationStrings: presentationData.strings)))
        
        self.isOpaqueWhenInOverlay = true
        self.blocksBackgroundWhenInOverlay = true
        self.automaticallyControlPresentationContextLayout = false
        self._hasGlassStyle = true
        
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
                    let isFirstTime = previousState == nil
                    if previousState?.title != controllerState.title {
                        var previousHadContentNode = false
                        switch previousState?.title {
                        case .textWithTabs:
                            previousHadContentNode = true
                        default:
                            break
                        }
                        switch controllerState.title {
                            case let .text(text):
                                strongSelf.title = text
                                strongSelf.navigationItem.titleView = nil
                                strongSelf.segmentedTitleView = nil
                                if previousHadContentNode {
                                    strongSelf.navigationBar?.setContentNode(nil, animated: false)
                                }
                                if strongSelf.isNodeLoaded {
                                    strongSelf.controllerNode.panRecognizer?.isEnabled = false
                                }
                            case let .textWithSubtitle(title, subtitle):
                                strongSelf.title = ""
                                strongSelf.navigationItem.titleView = ItemListTextWithSubtitleTitleView(theme: controllerState.presentationData.theme, title: title, subtitle: subtitle)
                                strongSelf.segmentedTitleView = nil
                                if previousHadContentNode {
                                    strongSelf.navigationBar?.setContentNode(nil, animated: false)
                                }
                                if strongSelf.isNodeLoaded {
                                    strongSelf.controllerNode.panRecognizer?.isEnabled = false
                                }
                            case let .sectionControl(sections, index):
                                strongSelf.title = ""
                                if let segmentedTitleView = strongSelf.segmentedTitleView, segmentedTitleView.segments == sections {
                                    segmentedTitleView.index = index
                                } else {
                                    let segmentedTitleView = ItemListControllerSegmentedTitleView(theme: controllerState.presentationData.theme, segments: sections, selectedIndex: index)
                                    strongSelf.segmentedTitleView = segmentedTitleView
                                    strongSelf.navigationItem.titleView = strongSelf.segmentedTitleView
                                    segmentedTitleView.indexUpdated = { [weak self] index in
                                        if let strongSelf = self {
                                            strongSelf.titleControlValueChanged?(index)
                                        }
                                    }
                                }
                                if previousHadContentNode {
                                    strongSelf.navigationBar?.setContentNode(nil, animated: false)
                                }
                                if strongSelf.isNodeLoaded {
                                    strongSelf.controllerNode.panRecognizer?.isEnabled = false
                                }
                            case let .textWithTabs(title, sections, index):
                                strongSelf.title = title
                                if let tabsNavigationContentNode = strongSelf.tabsNavigationContentNode, tabsNavigationContentNode.segments == sections {
                                    tabsNavigationContentNode.index = index
                                } else {
                                    let tabsNavigationContentNode = ItemListControllerTabsContentNode(theme: controllerState.presentationData.theme, segments: sections, selectedIndex: index)
                                    strongSelf.tabsNavigationContentNode = tabsNavigationContentNode
                                    strongSelf.navigationBar?.setContentNode(tabsNavigationContentNode, animated: false)
                                    tabsNavigationContentNode.indexUpdated = { [weak self] index in
                                        if let strongSelf = self {
                                            strongSelf.titleControlValueChanged?(index)
                                        }
                                    }
                                    if let validLayout = strongSelf.validLayout {
                                        strongSelf.updateNavigationBarLayout(validLayout, transition: .immediate)
                                    }
                                    strongSelf.navigationBar?.updateBackgroundAlpha(1.0, transition: .immediate)
                                }
                                if strongSelf.isNodeLoaded {
                                    strongSelf.controllerNode.panTransitionFractionChanged = { [weak self] transitionFraction in
                                        if let strongSelf = self {
                                            strongSelf.tabsNavigationContentNode?.transitionFraction = transitionFraction
                                        }
                                    }
                                    strongSelf.controllerNode.panGestureAllowedDirections = {
                                        if index == 0 {
                                            return [.leftCenter]
                                        } else if index == sections.count - 1 {
                                            return [.rightCenter]
                                        } else {
                                            return [.leftCenter, .rightCenter]
                                        }
                                    }
                                    strongSelf.controllerNode.panRecognizer?.isEnabled = true
                                }
                        }
                    }
                    strongSelf.navigationButtonActions = (left: controllerState.leftNavigationButton?.action, right: controllerState.rightNavigationButton?.action, secondaryRight: controllerState.secondaryRightNavigationButton?.action)
                    strongSelf.sideColumnLeftButton = controllerState.leftNavigationButton
                    strongSelf.sideColumnRightButtons = [controllerState.secondaryRightNavigationButton, controllerState.rightNavigationButton].compactMap { $0 }
                                        
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
                                    if [.close, .done].contains(icon) {
                                        switch icon {
                                        case .done:
                                            item = UIBarButtonItem(title: "___done", style: leftNavigationButton.style.barButtonItemStyle, target: strongSelf, action: #selector(strongSelf.leftNavigationButtonPressed))
                                        default:
                                            item = UIBarButtonItem(title: "___close", style: leftNavigationButton.style.barButtonItemStyle, target: strongSelf, action: #selector(strongSelf.leftNavigationButtonPressed))
                                        }
                                    } else {
                                        var image: UIImage?
                                        switch icon {
                                        case .search:
                                            image = PresentationResourcesRootController.navigationCompactSearchIcon(controllerState.presentationData.theme)
                                        case .add:
                                            image = PresentationResourcesRootController.navigationAddIcon(controllerState.presentationData.theme)
                                        case .action:
                                            image = PresentationResourcesRootController.navigationShareIcon(controllerState.presentationData.theme)
                                        default:
                                            image = nil
                                        }
                                        item = UIBarButtonItem(image: image, style: leftNavigationButton.style.barButtonItemStyle, target: strongSelf, action: #selector(strongSelf.leftNavigationButtonPressed))
                                    }
                                case let .node(node):
                                    item = UIBarButtonItem(customDisplayNode: node)
                                    item.setCustomAction({ [weak self] in
                                        self?.navigationButtonActions.0?()
                                    })
                            }
                            strongSelf.leftNavigationButtonTitleAndStyle = (leftNavigationButton.content, leftNavigationButton.style)
                            strongSelf.fullLeftBarButtonItem = item
                            item.isEnabled = leftNavigationButton.enabled
                        } else {
                            strongSelf.leftNavigationButtonTitleAndStyle = nil
                            strongSelf.fullLeftBarButtonItem = nil
                        }
                    } else if let barButtonItem = strongSelf.fullLeftBarButtonItem, let leftNavigationButton = controllerState.leftNavigationButton, leftNavigationButton.enabled != barButtonItem.isEnabled {
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
                                        if [.close, .done].contains(icon) {
                                            switch icon {
                                            case .done:
                                                item = UIBarButtonItem(title: "___done", style: style.barButtonItemStyle, target: strongSelf, action: action)
                                            default:
                                                item = UIBarButtonItem(title: "___close", style: style.barButtonItemStyle, target: strongSelf, action: action)
                                            }
                                        } else {
                                            var image: UIImage?
                                            switch icon {
                                            case .search:
                                                image = PresentationResourcesRootController.navigationCompactSearchIcon(controllerState.presentationData.theme)
                                            case .add:
                                                image = PresentationResourcesRootController.navigationAddIcon(controllerState.presentationData.theme)
                                            case .action:
                                                image = PresentationResourcesRootController.navigationShareIcon(controllerState.presentationData.theme)
                                            default:
                                                image = nil
                                            }
                                            item = UIBarButtonItem(image: image, style: style.barButtonItemStyle, target: strongSelf, action: action)
                                        }
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
                        strongSelf.fullRightBarButtonItems = items
                        index = 0
                        for (_, _, enabled) in rightNavigationButtonTitleAndStyle {
                            items[index].isEnabled = enabled
                            index += 1
                        }
                    } else {
                        for i in 0 ..< rightNavigationButtonTitleAndStyle.count {
                            if i < strongSelf.fullRightBarButtonItems.count {
                                strongSelf.fullRightBarButtonItems[i].isEnabled = rightNavigationButtonTitleAndStyle[i].2
                            }
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
                    
                    if strongSelf.presentationData != controllerState.presentationData || isFirstTime {
                        strongSelf.presentationData = controllerState.presentationData
                        
                        strongSelf.navigationBar?.updatePresentationData(NavigationBarPresentationData(theme: NavigationBarTheme(rootControllerTheme: strongSelf.presentationData.theme, hideBackground: strongSelf.hideNavigationBarBackground, hideSeparator: strongSelf.hideNavigationBarBackground, edgeEffectColor: state.0.style == .blocks ? strongSelf.presentationData.theme.list.blocksBackgroundColor : strongSelf.presentationData.theme.list.plainBackgroundColor, style: .glass), strings: NavigationBarStrings(presentationStrings: strongSelf.presentationData.strings)), transition: .immediate)
                        strongSelf.statusBar.updateStatusBarStyle(strongSelf.presentationData.theme.rootController.statusBarStyle.style, animated: true)
                        
                        strongSelf.segmentedTitleView?.theme = controllerState.presentationData.theme
                        
                        if let titleView = strongSelf.navigationItem.titleView as? ItemListTextWithSubtitleTitleView {
                            titleView.updateTheme(theme: controllerState.presentationData.theme)
                        }
                        
                        var items = strongSelf.fullRightBarButtonItems
                        for i in 0 ..< strongSelf.rightNavigationButtonTitleAndStyle.count {
                            if case .activity = strongSelf.rightNavigationButtonTitleAndStyle[i].1 {
                                items[i] = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: controllerState.presentationData.theme.rootController.navigationBar.controlColor))!
                            }
                        }
                        strongSelf.fullRightBarButtonItems = items
                    }
                    
                    strongSelf.updateNavigationButtonPlacement(isLayout: false, transition: .immediate)
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
        displayNode.afterTransactionCompleted = self.afterTransactionCompleted
        displayNode.listNode.experimentalSnapScrollToItem = self.experimentalSnapScrollToItem
        displayNode.listNode.didScrollWithOffset = self.didScrollWithOffset
        displayNode.requestLayout = { [weak self] transition in
            self?.requestLayout(transition: transition)
        }
        self.displayNode = displayNode
        super.displayNodeDidLoad()
        self._ready.set(self.controllerNode.ready)
    }
    
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        // iPhone Duo: the bar's buttons are split before the bar lays out.
        self.updateNavigationButtonPlacement(isLayout: true, transition: transition)
        
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.cleanNavigationHeight, transition: transition, additionalInsets: self.additionalInsets)
    }

    // The navigation container sets this (after the bar's) just before a pushed screen lays out, so the
    // column's back circle is there from the first frame.
    override open var previousItem: NavigationPreviousAction? {
        didSet {
            if self.previousItem != oldValue {
                self.updateNavigationButtonPlacement(isLayout: false, transition: .immediate)
            }
        }
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
    
    // MARK: - iPhone Duo side column
    
    private final func currentSideColumnRegion(layout: ContainerViewLayout) -> SideColumnRegion? {
        if layout.presentedInFormSheet {
            return nil
        }
        return sideColumnRegion(layout: layout, minY: (layout.statusBarHeight ?? 0.0) + 8.0, reservedBelow: (self.parent as? TabBarController)?.verticalTabBarFrame(for: layout))
    }
    
    private final var sideColumnNavigation: SideColumnBarNavigation {
        switch self.previousItem {
        case .none:
            return .none
        case .close?:
            return .close
        case .item?:
            return .back
        }
    }
    
    /// The column for the current buttons and layout, or nil (no strip, nothing to move, or no fit).
    private final func currentSideColumn() -> ItemListSideColumn? {
        guard let layout = self.validLayout, let region = self.currentSideColumnRegion(layout: layout) else {
            return nil
        }
        // Primary first: the bar keeps the secondary button before the primary one.
        let right = Array(self.sideColumnRightButtons.reversed())
        guard let split = sideColumnBarSplit(navigation: self.sideColumnNavigation, left: self.sideColumnLeftButton.map(itemListSideColumnKind), right: right.map(itemListSideColumnKind)) else {
            return nil
        }
        let top = split.top.flatMap { self.sideColumnItem($0, right: right) }
        let capsule = split.capsule.compactMap { self.sideColumnItem($0, right: right) }
        let confirm = split.confirm.flatMap { self.sideColumnItem($0, right: right) }
        guard let itemsLayout = sideColumnItemsLayout(regionLength: region.frame.height, hasBack: top != nil, priorities: capsule.map { _ -> Int? in nil }, hasTrailingCircle: confirm != nil) else {
            return nil
        }
        return ItemListSideColumn(region: region, split: split, itemsLayout: itemsLayout, top: top, capsule: capsule, confirm: confirm, theme: self.presentationData.theme, strings: self.presentationData.strings)
    }
    
    private final func sideColumnItem(_ entry: SideColumnBarEntry, right: [ItemListNavigationButton]) -> SideColumnBarButtonsItem? {
        switch entry {
        case .navigation:
            let action: () -> Void = { [weak self] in
                self?.navigationBar?.backPressed()
            }
            if case .close = self.sideColumnNavigation {
                return .close(action: action)
            }
            return .back(action: action)
        case .left:
            guard let button = self.sideColumnLeftButton else {
                return nil
            }
            return self.sideColumnItem(button: button, action: { [weak self] in
                self?.navigationButtonActions.left?()
            })
        case let .right(index):
            guard index < right.count else {
                return nil
            }
            // `right` is primary first, so with two buttons the second is the secondary one.
            let isSecondary = right.count > 1 && index == 1
            return self.sideColumnItem(button: right[index], action: { [weak self] in
                if isSecondary {
                    self?.navigationButtonActions.secondaryRight?()
                } else {
                    self?.navigationButtonActions.right?()
                }
            })
        }
    }
    
    private final func sideColumnItem(button: ItemListNavigationButton, action: @escaping () -> Void) -> SideColumnBarButtonsItem? {
        let theme = self.presentationData.theme
        switch button.content {
        case .none, .text:
            return nil
        case let .icon(icon):
            switch icon {
            case .close:
                return .close(action: action)
            case .done:
                var isActivity = false
                if case .activity = button.style {
                    isActivity = true
                }
                return .confirm(isEnabled: button.enabled, isActivity: isActivity, action: action)
            case .search:
                return .icon(image: PresentationResourcesRootController.navigationCompactSearchIcon(theme), accessibilityLabel: self.presentationData.strings.Common_Search, isEnabled: button.enabled, action: action)
            case .add:
                return .icon(image: PresentationResourcesRootController.navigationAddIcon(theme), accessibilityLabel: nil, isEnabled: button.enabled, action: action)
            case .action:
                return .icon(image: PresentationResourcesRootController.navigationShareIcon(theme), accessibilityLabel: nil, isEnabled: button.enabled, action: action)
            }
        case let .node(node):
            return .node(node, isEnabled: button.enabled, action: action)
        }
    }
    
    /// iPhone Duo: splits the bar's buttons between the top row and the side column, gives the bar its
    /// share and the node the column. Without a strip, or when the column does not fit, the bar gets every
    /// button. Outside a layout pass the node lays the column out at once.
    private final func updateNavigationButtonPlacement(isLayout: Bool, transition: ContainedViewLayoutTransition) {
        let column = self.currentSideColumn()
        let leftItem: UIBarButtonItem?
        let rightItems: [UIBarButtonItem]
        let hidesBackButton: Bool
        if let column {
            leftItem = column.split.keepsLeftInTopRow ? self.fullLeftBarButtonItem : nil
            // The split's right indices are primary first; the bar's items are secondary first.
            let count = self.fullRightBarButtonItems.count
            let topRowBarIndices = Set(column.split.topRowRightIndices.map { count - 1 - $0 })
            rightItems = self.fullRightBarButtonItems.enumerated().filter { topRowBarIndices.contains($0.offset) }.map { $0.element }
            hidesBackButton = !column.split.keepsLeftInTopRow
        } else {
            leftItem = self.fullLeftBarButtonItem
            rightItems = self.fullRightBarButtonItems
            hidesBackButton = false
        }
        if self.navigationItem.leftBarButtonItem !== leftItem {
            self.navigationItem.setLeftBarButton(leftItem, animated: false)
        }
        let currentRightItems = self.navigationItem.rightBarButtonItems ?? []
        if currentRightItems.count != rightItems.count || zip(currentRightItems, rightItems).contains(where: { $0 !== $1 }) {
            self.navigationItem.setRightBarButtonItems(rightItems, animated: false)
        }
        self.navigationBar?.hidesBackButton = hidesBackButton
        guard self.isNodeLoaded else {
            return
        }
        self.controllerNode.sideColumn = column
        if !isLayout {
            self.controllerNode.updateSideColumnView(transition: transition)
        }
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.viewDidAppear(completion: {})
    }
    
    public func viewDidAppear(completion: @escaping () -> Void) {
        self.controllerNode.listNode.preloadPages = true
        
        if let presentationArguments = self.presentationArguments as? ViewControllerPresentationArguments, !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            if case .modalSheet = presentationArguments.presentationAnimation {
                self.controllerNode.animateIn(completion: {
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
        return self.controllerNode.listNode.insets
    }
    
    public func frameForItemNode(_ predicate: (ListViewItemNode) -> Bool) -> CGRect? {
        var result: CGRect?
        self.controllerNode.listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ListViewItemNode {
                if predicate(itemNode) {
                    result = itemNode.convert(itemNode.bounds, to: self.displayNode)
                }
            }
        }
        return result
    }
    
    public func forEachItemNode(_ f: (ListViewItemNode) -> Void) {
        self.controllerNode.listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ListViewItemNode {
                f(itemNode)
            }
        }
    }
    
    public func itemNode(forTag tag: ItemListItemTag) -> ListViewItemNode? {
        var result: ListViewItemNode?
        self.forEachItemNode { itemNode in
            if result == nil, let taggedItemNode = itemNode as? ItemListItemNode, let itemTag = taggedItemNode.tag, itemTag.isEqual(to: tag) {
                result = itemNode
            }
        }
        return result
    }

    public func ensureItemNodeVisible(_ itemNode: ListViewItemNode, animated: Bool = true, overflow: CGFloat = 0.0, atTop: Bool = false, curve: ListViewAnimationCurve = .Default(duration: 0.25)) {
        self.controllerNode.listNode.ensureItemNodeVisible(itemNode, animated: animated, overflow: overflow, atTop: atTop, curve: curve)
    }
    
    public func afterLayout(_ f: @escaping () -> Void) {
        self.controllerNode.afterLayout(f)
    }
        
    public func clearItemNodesHighlight(animated: Bool = false) {
        self.controllerNode.listNode.clearHighlightAnimated(animated)
    }
    
    public var keyShortcuts: [KeyShortcut] {
        return [KeyShortcut(input: UIKeyCommand.inputEscape, action: { [weak self] in
            if !(self?.navigationController?.topViewController is TabBarController) {
                _ = self?.navigationBar?.executeBack()
            }
        })]
    }
}

/// What an ItemList bar button is, for iPhone Duo's side column.
private func itemListSideColumnKind(_ button: ItemListNavigationButton) -> SideColumnBarButtonKind {
    switch button.content {
    case .none:
        return .spacer
    case .text:
        return .text
    case let .icon(icon):
        switch icon {
        case .close:
            return .close
        case .done:
            return .confirm
        case .search, .add, .action:
            return .icon
        }
    case .node:
        return .icon
    }
}

private final class ItemListTextWithSubtitleTitleView: UIView, NavigationBarTitleView {
    private let titleNode: ImmediateTextNode
    private let subtitleNode: ImmediateTextNode
    
    private var validLayout: CGSize?
    var requestUpdate: ((ContainedViewLayoutTransition) -> Void)?
    
    init(theme: PresentationTheme, title: String, subtitle: String) {
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.isOpaque = false
        
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(17.0), textColor: theme.rootController.navigationBar.primaryTextColor)
        
        self.subtitleNode = ImmediateTextNode()
        self.subtitleNode.displaysAsynchronously = false
        self.subtitleNode.maximumNumberOfLines = 1
        self.subtitleNode.isOpaque = false
        
        self.subtitleNode.attributedText = NSAttributedString(string: subtitle, font: Font.regular(12.0), textColor: theme.rootController.navigationBar.secondaryTextColor)
        
        super.init(frame: CGRect())
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateTheme(theme: PresentationTheme) {
        self.titleNode.attributedText = NSAttributedString(string: self.titleNode.attributedText?.string ?? "", font: Font.semibold(17.0), textColor: theme.rootController.navigationBar.primaryTextColor)
        self.subtitleNode.attributedText = NSAttributedString(string: self.subtitleNode.attributedText?.string ?? "", font: Font.regular(12.0), textColor: theme.rootController.navigationBar.secondaryTextColor)
        if let size = self.validLayout {
            let _ = self.updateLayout(availableSize: size, transition: .immediate)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if let size = self.validLayout {
            let _ = self.updateLayout(availableSize: size, transition: .immediate)
        }
    }
    
    func updateLayout(availableSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let size = availableSize
        
        self.validLayout = size
        
        let titleSize = self.titleNode.updateLayout(size)
        let subtitleSize = self.subtitleNode.updateLayout(size)
        let spacing: CGFloat = 1.0
        let contentHeight = titleSize.height + spacing + subtitleSize.height
        let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: floor((size.height - contentHeight) / 2.0)), size: titleSize)
        let subtitleFrame = CGRect(origin: CGPoint(x: floor((size.width - subtitleSize.width) / 2.0), y: titleFrame.maxY + spacing), size: subtitleSize)
            
        self.titleNode.frame = titleFrame
        self.subtitleNode.frame = subtitleFrame
        
        return availableSize
    }
    
    func animateLayoutTransition() {
    }
}
