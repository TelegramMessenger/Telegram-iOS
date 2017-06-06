import Foundation
import Display
import SwiftSignalKit
import TelegramCore

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

struct ItemListNavigationButton {
    let title: String
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
    
    init(title: String, image: UIImage?, selectedImage: UIImage?) {
        self.title = title
        self.image = image
        self.selectedImage = selectedImage
    }
    
    static func ==(lhs: ItemListControllerTabBarItem, rhs: ItemListControllerTabBarItem) -> Bool {
        return lhs.title == rhs.title && lhs.image === rhs.image && lhs.selectedImage === rhs.selectedImage
    }
}

struct ItemListControllerState {
    let theme: PresentationTheme
    let title: ItemListControllerTitle
    let leftNavigationButton: ItemListNavigationButton?
    let rightNavigationButton: ItemListNavigationButton?
    let backNavigationButton: ItemListBackButton?
    let tabBarItem: ItemListControllerTabBarItem?
    let animateChanges: Bool
    
    init(theme: PresentationTheme, title: ItemListControllerTitle, leftNavigationButton: ItemListNavigationButton?, rightNavigationButton: ItemListNavigationButton?, backNavigationButton: ItemListBackButton?, tabBarItem: ItemListControllerTabBarItem? = nil, animateChanges: Bool = true) {
        self.theme = theme
        self.title = title
        self.leftNavigationButton = leftNavigationButton
        self.rightNavigationButton = rightNavigationButton
        self.backNavigationButton = backNavigationButton
        self.tabBarItem = tabBarItem
        self.animateChanges = animateChanges
    }
}

final class ItemListController<Entry: ItemListNodeEntry>: ViewController {
    private let state: Signal<(ItemListControllerState, (ItemListNodeState<Entry>, Entry.ItemGenerationArguments)), NoError>
    
    private var leftNavigationButtonTitleAndStyle: (String, ItemListNavigationButtonStyle)?
    private var rightNavigationButtonTitleAndStyle: (String, ItemListNavigationButtonStyle)?
    private var backNavigationButton: ItemListBackButton?
    private var tabBarItemInfo: ItemListControllerTabBarItem?
    private var navigationButtonActions: (left: (() -> Void)?, right: (() -> Void)?) = (nil, nil)
    private var segmentedTitleView: ItemListControllerSegmentedTitleView?
    
    private var theme: PresentationTheme
    
    private var didPlayPresentationAnimation = false
    
    var titleControlValueChanged: ((Int) -> Void)?
    
    private var tabBarItemDisposable: Disposable?
    
    private let _ready = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    
    var visibleEntriesUpdated: ((ItemListNodeVisibleEntries<Entry>) -> Void)? {
        didSet {
            (self.displayNode as! ItemListNode<Entry>).visibleEntriesUpdated = self.visibleEntriesUpdated
        }
    }
    
    init(account: Account, state: Signal<(ItemListControllerState, (ItemListNodeState<Entry>, Entry.ItemGenerationArguments)), NoError>, tabBarItem: Signal<ItemListControllerTabBarItem, NoError>? = nil) {
        self.state = state
        
        self.theme = (account.telegramApplicationContext.currentPresentationData.with { $0 }).theme
        
        super.init(navigationBarTheme: NavigationBarTheme(rootControllerTheme: self.theme))
        
        self.statusBar.statusBarStyle = (account.telegramApplicationContext.currentPresentationData.with { $0 }).theme.rootController.statusBar.style.style
        
        self.scrollToTop = { [weak self] in
            (self?.displayNode as! ItemListNode<Entry>).scrollToTop()
        }
        
        if let tabBarItem = tabBarItem {
            self.tabBarItemDisposable = (tabBarItem |> deliverOnMainQueue).start(next: { [weak self] tabBarItemInfo in
                if let strongSelf = self {
                    if strongSelf.tabBarItemInfo != tabBarItemInfo {
                        strongSelf.tabBarItemInfo = tabBarItemInfo
                        
                        strongSelf.tabBarItem.title = tabBarItemInfo.title
                        strongSelf.tabBarItem.image = tabBarItemInfo.image
                        strongSelf.tabBarItem.selectedImage = tabBarItemInfo.selectedImage
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
        let nodeState = self.state |> deliverOnMainQueue |> afterNext { [weak self] controllerState, state in
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
                    strongSelf.navigationButtonActions = (left: controllerState.leftNavigationButton?.action, right: controllerState.rightNavigationButton?.action)
                    
                    if strongSelf.leftNavigationButtonTitleAndStyle?.0 != controllerState.leftNavigationButton?.title || strongSelf.leftNavigationButtonTitleAndStyle?.1 != controllerState.leftNavigationButton?.style {
                        if let leftNavigationButton = controllerState.leftNavigationButton {
                            let item = UIBarButtonItem(title: leftNavigationButton.title, style: leftNavigationButton.style.barButtonItemStyle, target: strongSelf, action: #selector(strongSelf.leftNavigationButtonPressed))
                            strongSelf.leftNavigationButtonTitleAndStyle = (leftNavigationButton.title, leftNavigationButton.style)
                            strongSelf.navigationItem.setLeftBarButton(item, animated: false)
                            item.isEnabled = leftNavigationButton.enabled
                        } else {
                            strongSelf.leftNavigationButtonTitleAndStyle = nil
                            strongSelf.navigationItem.setLeftBarButton(nil, animated: false)
                        }
                    } else if let barButtonItem = strongSelf.navigationItem.leftBarButtonItem, let leftNavigationButton = controllerState.leftNavigationButton, leftNavigationButton.enabled != barButtonItem.isEnabled {
                        barButtonItem.isEnabled = leftNavigationButton.enabled
                    }
                    
                    if strongSelf.rightNavigationButtonTitleAndStyle?.0 != controllerState.rightNavigationButton?.title || strongSelf.rightNavigationButtonTitleAndStyle?.1 != controllerState.rightNavigationButton?.style {
                        if let rightNavigationButton = controllerState.rightNavigationButton {
                            let item: UIBarButtonItem
                            if case .activity = rightNavigationButton.style {
                                item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(theme: controllerState.theme))
                            } else {
                                item = UIBarButtonItem(title: rightNavigationButton.title, style: rightNavigationButton.style.barButtonItemStyle, target: strongSelf, action: #selector(strongSelf.rightNavigationButtonPressed))
                            }
                            strongSelf.rightNavigationButtonTitleAndStyle = (rightNavigationButton.title, rightNavigationButton.style)
                            strongSelf.navigationItem.setRightBarButton(item, animated: false)
                            item.isEnabled = rightNavigationButton.enabled
                        } else {
                            strongSelf.rightNavigationButtonTitleAndStyle = nil
                            strongSelf.navigationItem.setRightBarButton(nil, animated: false)
                        }
                    }  else if let barButtonItem = strongSelf.navigationItem.rightBarButtonItem, let rightNavigationButton = controllerState.rightNavigationButton, rightNavigationButton.enabled != barButtonItem.isEnabled {
                        barButtonItem.isEnabled = rightNavigationButton.enabled
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
                        
                        strongSelf.navigationBar?.updateTheme(NavigationBarTheme(rootControllerTheme: strongSelf.theme))
                        strongSelf.statusBar.statusBarStyle = strongSelf.theme.rootController.statusBar.style.style
                        
                        strongSelf.segmentedTitleView?.color = controllerState.theme.rootController.navigationBar.accentTextColor
                        
                        if let rightNavigationButton = controllerState.rightNavigationButton {
                            if case .activity = rightNavigationButton.style {
                                let item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(theme: controllerState.theme))!
                                
                                strongSelf.rightNavigationButtonTitleAndStyle = (rightNavigationButton.title, rightNavigationButton.style)
                                strongSelf.navigationItem.setRightBarButton(item, animated: false)
                                item.isEnabled = rightNavigationButton.enabled
                            }
                        }
                    }
                }
            }
        } |> map { ($0.theme, $1) }
        let displayNode = ItemListNode<Entry>(state: nodeState)
        displayNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: true, completion: nil)
        }
        self.displayNode = displayNode
        super.displayNodeDidLoad()
        self._ready.set((self.displayNode as! ItemListNode<Entry>).ready)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        (self.displayNode as! ItemListNode<Entry>).containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }

    @objc func leftNavigationButtonPressed() {
        self.navigationButtonActions.left?()
    }
    
    @objc func rightNavigationButtonPressed() {
        self.navigationButtonActions.right?()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        (self.displayNode as! ItemListNode<Entry>).listNode.preloadPages = true
        
        if let presentationArguments = self.presentationArguments as? ViewControllerPresentationArguments, !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            if case .modalSheet = presentationArguments.presentationAnimation {
                (self.displayNode as! ItemListNode<Entry>).animateIn()
            }
        }
    }
    
    override func dismiss(completion: (() -> Void)? = nil) {
        (self.displayNode as! ItemListNode<Entry>).animateOut(completion: completion)
    }
    
    func frameForItemNode(_ predicate: (ListViewItemNode) -> Bool) -> CGRect? {
        var result: CGRect?
        (self.displayNode as! ItemListNode<Entry>).listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ListViewItemNode {
                if predicate(itemNode) {
                    result = itemNode.convert(itemNode.bounds, to: self.displayNode)
                }
            }
        }
        return result
    }
    
    func forEachItemNode(_ f: (ListViewItemNode) -> Void) {
        (self.displayNode as! ItemListNode<Entry>).listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ListViewItemNode {
                f(itemNode)
            }
        }
    }
}
