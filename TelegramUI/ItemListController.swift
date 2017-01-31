import Foundation
import Display
import SwiftSignalKit

enum ItemListNavigationButtonStyle {
    case regular
    case bold
    
    var barButtonItemStyle: UIBarButtonItemStyle {
        switch self {
            case .regular:
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
}

final class ItemListController<Entry: ItemListNodeEntry>: ViewController {
    private let state: Signal<(ItemListControllerState, (ItemListNodeState<Entry>, Entry.ItemGenerationArguments)), NoError>
    
    private var leftNavigationButtonTitleAndStyle: (String, ItemListNavigationButtonStyle)?
    private var rightNavigationButtonTitleAndStyle: (String, ItemListNavigationButtonStyle)?
    private var navigationButtonActions: (left: (() -> Void)?, right: (() -> Void)?) = (nil, nil)
    
    init(_ state: Signal<(ItemListControllerState, (ItemListNodeState<Entry>, Entry.ItemGenerationArguments)), NoError>) {
        self.state = state
        
        super.init()
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
                            let item = UIBarButtonItem(title: rightNavigationButton.title, style: rightNavigationButton.style.barButtonItemStyle, target: strongSelf, action: #selector(strongSelf.rightNavigationButtonPressed))
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
        
        if let presentationArguments = self.presentationArguments as? ViewControllerPresentationArguments {
            if case .modalSheet = presentationArguments.presentationAnimation {
                (self.displayNode as! ItemListNode<Entry>).animateIn()
            }
        }
    }
    
    func dismiss() {
        (self.displayNode as! ItemListNode<Entry>).animateOut()
    }
}
