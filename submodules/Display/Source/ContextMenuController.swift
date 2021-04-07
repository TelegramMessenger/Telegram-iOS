import Foundation
import UIKit
import AsyncDisplayKit

public final class ContextMenuControllerPresentationArguments {
    fileprivate let sourceNodeAndRect: () -> (ASDisplayNode, CGRect, ASDisplayNode, CGRect)?
    fileprivate let bounce: Bool
    
    public init(sourceNodeAndRect: @escaping () -> (ASDisplayNode, CGRect, ASDisplayNode, CGRect)?, bounce: Bool = true) {
        self.sourceNodeAndRect = sourceNodeAndRect
        self.bounce = bounce
    }
}

public final class ContextMenuController: ViewController, KeyShortcutResponder, StandalonePresentableController {
    private var contextMenuNode: ContextMenuNode {
        return self.displayNode as! ContextMenuNode
    }
    
    public var keyShortcuts: [KeyShortcut] {
        return [KeyShortcut(input: UIKeyCommand.inputEscape, action: { [weak self] in
            if let strongSelf = self {
                strongSelf.dismiss()
            }
        })]
    }
    private let actions: [ContextMenuAction]
    private let catchTapsOutside: Bool
    private let hasHapticFeedback: Bool
    
    private var layout: ContainerViewLayout?
    
    public var dismissed: (() -> Void)?
    
    public init(actions: [ContextMenuAction], catchTapsOutside: Bool = false, hasHapticFeedback: Bool = false) {
        self.actions = actions
        self.catchTapsOutside = catchTapsOutside
        self.hasHapticFeedback = hasHapticFeedback
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ContextMenuNode(actions: self.actions, dismiss: { [weak self] in
            self?.dismissed?()
            self?.contextMenuNode.animateOut(bounce: (self?.presentationArguments as? ContextMenuControllerPresentationArguments)?.bounce ?? true, completion: {
                self?.presentingViewController?.dismiss(animated: false)
            })
        }, catchTapsOutside: self.catchTapsOutside, hasHapticFeedback: self.hasHapticFeedback)
        self.displayNodeDidLoad()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.contextMenuNode.animateIn(bounce: (self.presentationArguments as? ContextMenuControllerPresentationArguments)?.bounce ?? true)
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.dismissed?()
        self.contextMenuNode.animateOut(bounce: (self.presentationArguments as? ContextMenuControllerPresentationArguments)?.bounce ?? true, completion: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false)
        })
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        if self.layout != nil && self.layout! != layout {
            self.dismissed?()
            self.contextMenuNode.animateOut(bounce: (self.presentationArguments as? ContextMenuControllerPresentationArguments)?.bounce ?? true, completion: { [weak self] in
                self?.presentingViewController?.dismiss(animated: false)
            })
        } else {
            self.layout = layout
            
            if let presentationArguments = self.presentationArguments as? ContextMenuControllerPresentationArguments, let (sourceNode, sourceRect, containerNode, containerRect) = presentationArguments.sourceNodeAndRect() {
                self.contextMenuNode.sourceRect = sourceNode.view.convert(sourceRect, to: nil)
                self.contextMenuNode.containerRect = containerNode.view.convert(containerRect, to: nil)
            } else {
                self.contextMenuNode.sourceRect = nil
                self.contextMenuNode.containerRect = nil
            }
            
            self.contextMenuNode.containerLayoutUpdated(layout, transition: transition)
        }
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
}
