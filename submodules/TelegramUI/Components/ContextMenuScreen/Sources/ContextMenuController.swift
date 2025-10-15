import Foundation
import UIKit
import Display

public final class ContextMenuControllerImpl: ViewController, KeyShortcutResponder, ContextMenuController {
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
    private let blurred: Bool
    private let skipCoordnateConversion: Bool
    private let isDark: Bool
    
    private var layout: ContainerViewLayout?
    
    public var centerHorizontally = false
    public var dismissed: (() -> Void)?
    
    public var dismissOnTap: ((UIView, CGPoint) -> Bool)?
    
    public init(_ arguments: ContextMenuControllerArguments) {
        self.actions = arguments.actions
        self.catchTapsOutside = arguments.catchTapsOutside
        self.hasHapticFeedback = arguments.hasHapticFeedback
        self.blurred = arguments.blurred
        self.skipCoordnateConversion = arguments.skipCoordnateConversion
        self.isDark = arguments.isDark
        
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
        }, dismissOnTap: { [weak self] view, point in
            guard let self, let dismissOnTap = self.dismissOnTap else {
                return false
            }
            return dismissOnTap(view, point)
        }, catchTapsOutside: self.catchTapsOutside, hasHapticFeedback: self.hasHapticFeedback, blurred: self.blurred, isDark: self.isDark)
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
        
        self.contextMenuNode.centerHorizontally = self.centerHorizontally
        if self.layout != nil && self.layout! != layout {
            self.dismissed?()
            self.contextMenuNode.animateOut(bounce: (self.presentationArguments as? ContextMenuControllerPresentationArguments)?.bounce ?? true, completion: { [weak self] in
                self?.presentingViewController?.dismiss(animated: false)
            })
        } else {
            self.layout = layout
            
            if let presentationArguments = self.presentationArguments as? ContextMenuControllerPresentationArguments, let (sourceNode, sourceRect, containerNode, containerRect) = presentationArguments.sourceNodeAndRect() {
                if self.skipCoordnateConversion {
                    self.contextMenuNode.sourceRect = sourceRect
                    self.contextMenuNode.containerRect = containerRect
                } else {
                    self.contextMenuNode.sourceRect = sourceNode.view.convert(sourceRect, to: nil)
                    self.contextMenuNode.containerRect = containerNode.view.convert(containerRect, to: nil)
                }
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



