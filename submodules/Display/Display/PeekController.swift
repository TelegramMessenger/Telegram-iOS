import Foundation
import UIKit
import AsyncDisplayKit

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

public final class PeekController: ViewController {
    private var controllerNode: PeekControllerNode {
        return self.displayNode as! PeekControllerNode
    }
    
    private let theme: PeekControllerTheme
    private let content: PeekControllerContent
    var sourceNode: () -> ASDisplayNode?
    
    private var animatedIn = false
    
    public init(theme: PeekControllerTheme, content: PeekControllerContent, sourceNode: @escaping () -> ASDisplayNode?) {
        self.theme = theme
        self.content = content
        self.sourceNode = sourceNode
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = PeekControllerNode(theme: self.theme, content: self.content, requestDismiss: { [weak self] in
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
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, transition: transition)
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.animateOut(to: self.getSourceRect(), completion: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        })
    }
}
