import Foundation
import Display
import SwiftSignalKit

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

struct ItemListControllerState {
    let title: String
    let leftNavigationButton: ItemListNavigationButton?
    let rightNavigationButton: ItemListNavigationButton?
    let animateChanges: Bool
    
    init(title: String, leftNavigationButton: ItemListNavigationButton?, rightNavigationButton: ItemListNavigationButton?, animateChanges: Bool = true) {
        self.title = title
        self.leftNavigationButton = leftNavigationButton
        self.rightNavigationButton = rightNavigationButton
        self.animateChanges = animateChanges
    }
}

final class ItemListController<Entry: ItemListNodeEntry>: ViewController {
    private let state: Signal<(ItemListControllerState, (ItemListNodeState<Entry>, Entry.ItemGenerationArguments)), NoError>
    
    private var leftNavigationButtonTitleAndStyle: (String, ItemListNavigationButtonStyle)?
    private var rightNavigationButtonTitleAndStyle: (String, ItemListNavigationButtonStyle)?
    private var navigationButtonActions: (left: (() -> Void)?, right: (() -> Void)?) = (nil, nil)
    
    private var didPlayPresentationAnimation = false
    
    private let _ready = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    
    var visibleEntriesUpdated: ((ItemListNodeVisibleEntries<Entry>) -> Void)? {
        didSet {
            (self.displayNode as! ItemListNode<Entry>).visibleEntriesUpdated = self.visibleEntriesUpdated
        }
    }
    
    init(_ state: Signal<(ItemListControllerState, (ItemListNodeState<Entry>, Entry.ItemGenerationArguments)), NoError>) {
        self.state = state
        
        super.init()
        
        self.scrollToTop = { [weak self] in
            (self?.displayNode as! ItemListNode<Entry>).scrollToTop()
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadDisplayNode() {
        let previousControllerState = Atomic<ItemListControllerState?>(value: nil)
        let nodeState = self.state |> deliverOnMainQueue |> afterNext { [weak self] controllerState, state in
            Queue.mainQueue().async {
                if let strongSelf = self {
                    let previousState = previousControllerState.swap(controllerState)
                    if previousState?.title != controllerState.title {
                        strongSelf.title = controllerState.title
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
                                item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode())
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
                }
            }
        } |> map { $1 }
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
    
    override func dismiss() {
        (self.displayNode as! ItemListNode<Entry>).animateOut()
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
}
