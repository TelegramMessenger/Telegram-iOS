import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import ContextUI

public final class PeekControllerImpl: ViewController, PeekController, ContextControllerProtocol {
    public var useComplexItemsTransitionAnimation: Bool = false
    public var immediateItemsTransitionAnimation = false

    public func getActionsMinHeight() -> ContextController.ActionsHeight? {
        return nil
    }
    
    public func setItems(_ items: Signal<ContextController.Items, NoError>, minHeight: ContextController.ActionsHeight?, animated: Bool) {
    }

    public func setItems(_ items: Signal<ContextController.Items, NoError>, minHeight: ContextController.ActionsHeight?, previousActionsTransition: ContextController.PreviousActionsTransition) {
    }
    
    public func pushItems(items: Signal<ContextController.Items, NoError>) {
        self.controllerNode.pushItems(items: items)
    }
    
    public func popItems() {
        self.controllerNode.popItems()
    }
    
    private var controllerNode: PeekControllerNode {
        return self.displayNode as! PeekControllerNode
    }
    
    public var contentNode: PeekControllerContentNode & ASDisplayNode {
        return self.controllerNode.contentNode
    }
    
    private let presentationData: PresentationData
    private let content: PeekControllerContent
    public var sourceView: () -> (UIView, CGRect)?
    private let activateImmediately: Bool
    
    public var visibilityUpdated: ((Bool) -> Void)?
    
    public var getOverlayViews: (() -> [UIView])?
    
    public var appeared: (() -> Void)?
    public var disappeared: (() -> Void)?
    
    private var animatedIn = false
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    public init(presentationData: PresentationData, content: PeekControllerContent, sourceView: @escaping () -> (UIView, CGRect)?, activateImmediately: Bool = false) {
        self.presentationData = presentationData
        self.content = content
        self.sourceView = sourceView
        self.activateImmediately = activateImmediately
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = PeekControllerNode(presentationData: self.presentationData, controller: self, content: self.content, requestDismiss: { [weak self] in
            self?.dismiss()
        })
        self.displayNodeDidLoad()
    }
    
    private func getSourceRect() -> CGRect {
        if let (sourceView, sourceRect) = self.sourceView() {
            return sourceView.convert(sourceRect, to: self.view)
        } else {
            let size = self.displayNode.bounds.size
            return CGRect(origin: CGPoint(x: floor((size.width - 10.0) / 2.0), y: floor((size.height - 10.0) / 2.0)), size: CGSize(width: 10.0, height: 10.0))
        }
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatedIn {
            self.animatedIn = true
            self.controllerNode.animateIn(from: self.getSourceRect())
            
            self.visibilityUpdated?(true)
            
            if self.activateImmediately {
                self.controllerNode.activateMenu(immediately: true)
            }
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, transition: transition)
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.visibilityUpdated?(false)
        self.controllerNode.animateOut(to: self.getSourceRect(), completion: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        })
    }
    
    public func dismiss(result: ContextMenuActionResult, completion: (() -> Void)?) {
        self.dismiss(completion: completion)
    }
}
