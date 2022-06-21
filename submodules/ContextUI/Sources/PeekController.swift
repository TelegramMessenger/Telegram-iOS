import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData

public final class PeekControllerTheme {
    public let isDark: Bool
    public let menuBackgroundColor: UIColor
    public let menuItemHighligtedColor: UIColor
    public let menuItemSeparatorColor: UIColor
    public let accentColor: UIColor
    public let destructiveColor: UIColor
    
    public init(isDark: Bool, menuBackgroundColor: UIColor, menuItemHighligtedColor: UIColor, menuItemSeparatorColor: UIColor, accentColor: UIColor, destructiveColor: UIColor) {
        self.isDark = isDark
        self.menuBackgroundColor = menuBackgroundColor
        self.menuItemHighligtedColor = menuItemHighligtedColor
        self.menuItemSeparatorColor = menuItemSeparatorColor
        self.accentColor = accentColor
        self.destructiveColor = destructiveColor
    }
}

extension PeekControllerTheme {
    convenience public init(presentationTheme: PresentationTheme) {
        let actionSheet = presentationTheme.actionSheet
        self.init(isDark: actionSheet.backgroundType == .dark, menuBackgroundColor: actionSheet.opaqueItemBackgroundColor, menuItemHighligtedColor: actionSheet.opaqueItemHighlightedBackgroundColor, menuItemSeparatorColor: actionSheet.opaqueItemSeparatorColor, accentColor: actionSheet.controlAccentColor, destructiveColor: actionSheet.destructiveActionTextColor)
    }
}

public final class PeekController: ViewController, ContextControllerProtocol {
    public var useComplexItemsTransitionAnimation: Bool = false
    public var immediateItemsTransitionAnimation = false

    public func getActionsMinHeight() -> ContextController.ActionsHeight? {
        return nil
    }
    
    public func setItems(_ items: Signal<ContextController.Items, NoError>, minHeight: ContextController.ActionsHeight?) {
    }

    public func setItems(_ items: Signal<ContextController.Items, NoError>, minHeight: ContextController.ActionsHeight?, previousActionsTransition: ContextController.PreviousActionsTransition) {
    }
    
    public func pushItems(items: Signal<ContextController.Items, NoError>) {
    }
    
    public func popItems() {
    }
    
    private var controllerNode: PeekControllerNode {
        return self.displayNode as! PeekControllerNode
    }
    
    public var contentNode: PeekControllerContentNode & ASDisplayNode {
        return self.controllerNode.contentNode
    }
    
    private let presentationData: PresentationData
    private let content: PeekControllerContent
    var sourceNode: () -> ASDisplayNode?
    
    public var visibilityUpdated: ((Bool) -> Void)?
    
    private var animatedIn = false
    
    public init(presentationData: PresentationData, content: PeekControllerContent, sourceNode: @escaping () -> ASDisplayNode?) {
        self.presentationData = presentationData
        self.content = content
        self.sourceNode = sourceNode
        
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
        if let sourceNode = self.sourceNode() {
            return sourceNode.view.convert(sourceNode.bounds, to: self.view)
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
}
