import Foundation
import AsyncDisplayKit

final class PeekControllerNode: ViewControllerTracingNode {
    private let requestDismiss: () -> Void
    
    private let theme: PeekControllerTheme
    
    private let blurView: UIView
    private let dimNode: ASDisplayNode
    private let containerBackgroundNode: ASImageNode
    private let containerNode: ASDisplayNode
    
    private var validLayout: ContainerViewLayout?
    private var containerOffset: CGFloat = 0.0
    
    private let content: PeekControllerContent
    private let contentNode: PeekControllerContentNode & ASDisplayNode
    
    private let menuNode: PeekControllerMenuNode?
    private var displayingMenu = false
    
    init(theme: PeekControllerTheme, content: PeekControllerContent, requestDismiss: @escaping () -> Void) {
        self.theme = theme
        self.requestDismiss = requestDismiss
        
        self.dimNode = ASDisplayNode()
        self.blurView = UIVisualEffectView(effect: UIBlurEffect(style: theme.isDark ? .dark : .light))
        self.blurView.isUserInteractionEnabled = false
        
        switch content.menuActivation() {
            case .drag:
                self.dimNode.backgroundColor = nil
                self.blurView.alpha = 1.0
            case .press:
                self.dimNode.backgroundColor = UIColor(white: theme.isDark ? 0.0 : 1.0, alpha: 0.5)
                self.blurView.alpha = 0.0
        }
        
        self.containerBackgroundNode = ASImageNode()
        self.containerBackgroundNode.isLayerBacked = true
        self.containerBackgroundNode.displayWithoutProcessing = true
        self.containerBackgroundNode.displaysAsynchronously = false
        
        self.containerNode = ASDisplayNode()
        self.containerNode.clipsToBounds = true
        self.containerNode.cornerRadius = 16.0
        
        self.content = content
        self.contentNode = content.node()
        
        var activatedActionImpl: (() -> Void)?
        let menuItems = content.menuItems()
        if menuItems.isEmpty {
            self.menuNode = nil
        } else {
            self.menuNode = PeekControllerMenuNode(theme: theme, items: menuItems, activatedAction: {
                activatedActionImpl?()
            })
        }
        
        super.init()
        
        self.addSubnode(self.dimNode)
        self.view.addSubview(self.blurView)
        self.containerNode.addSubnode(self.contentNode)
        self.addSubnode(self.containerNode)
        
        if let menuNode = self.menuNode {
            self.addSubnode(menuNode)
        }
        
        activatedActionImpl = { [weak self] in
            self?.requestDismiss()
        }
    }
    
    deinit {
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimNodeTap(_:))))
        self.view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:))))
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(view: self.blurView, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let layoutInsets = layout.insets(options: [])
        let maxContainerSize = CGSize(width: layout.size.width - 14.0 * 2.0, height: layout.size.height - layoutInsets.top - layoutInsets.bottom - 90.0)
        
        var menuSize: CGSize?
        
        let contentSize = self.contentNode.updateLayout(size: maxContainerSize, transition: transition)
        transition.updateFrame(node: self.contentNode, frame: CGRect(origin: CGPoint(), size: contentSize))
        
        var containerFrame: CGRect
        switch self.content.presentation() {
            case .contained:
                containerFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - contentSize.width) / 2.0), y: self.containerOffset + floor((layout.size.height - contentSize.height) / 2.0)), size: contentSize)
            case .freeform:
                containerFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - contentSize.width) / 2.0), y: self.containerOffset + floor((layout.size.height - contentSize.height) / 4.0)), size: contentSize)
        }
        
        if let menuNode = self.menuNode {
            let menuWidth = layout.size.width - layoutInsets.left - layoutInsets.right - 14.0 * 2.0
            let menuHeight = menuNode.updateLayout(width: menuWidth, transition: transition)
            menuSize = CGSize(width: menuWidth, height: menuHeight)
            
            if self.displayingMenu {
                containerFrame.origin.y = min(containerFrame.origin.y, layout.size.height - layoutInsets.bottom - menuHeight - 14.0 * 2.0 - containerFrame.height)
                
                transition.updateAlpha(layer: self.blurView.layer, alpha: 1.0)
            }
        }
        
        transition.updateFrame(node: self.containerNode, frame: containerFrame)
        
        if let menuNode = self.menuNode, let menuSize = menuSize {
            let menuY: CGFloat
            if self.displayingMenu {
                menuY = max(containerFrame.maxY + 14.0, layout.size.height - layoutInsets.bottom - 14.0 - menuSize.height)
            } else {
                menuY = layout.size.height + 14.0
            }
            
            transition.updateFrame(node: menuNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - menuSize.width) / 2.0), y: menuY), size: menuSize))
        }
    }
    
    func animateIn(from rect: CGRect) {
        self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        self.blurView.layer.animateAlpha(from: 0.0, to: self.blurView.alpha, duration: 0.3)
        
        self.containerNode.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: rect.midX - self.containerNode.position.x, y: rect.midY - self.containerNode.position.y)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: 0.4, initialVelocity: 0.0, damping: 110.0, additive: true)
        self.containerNode.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4, initialVelocity: 0.0, damping: 110.0)
        self.containerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
    }
    
    func animateOut(to rect: CGRect, completion: @escaping () -> Void) {
        self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.blurView.layer.animateAlpha(from: self.blurView.alpha, to: 0.0, duration: 0.25, removeOnCompletion: false)
        self.containerNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: rect.midX - self.containerNode.position.x, y: rect.midY - self.containerNode.position.y), duration: 0.25, timingFunction: kCAMediaTimingFunctionEaseInEaseOut, removeOnCompletion: false, additive: true, force: true, completion: { _ in
            completion()
        })
        self.containerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.containerNode.layer.animateScale(from: 1.0, to: 0.1, duration: 0.25, removeOnCompletion: false)
        if let menuNode = self.menuNode {
            menuNode.layer.animatePosition(from: menuNode.position, to: CGPoint(x: menuNode.position.x, y: self.bounds.size.height + menuNode.bounds.size.height / 2.0), duration: 0.25, timingFunction: kCAMediaTimingFunctionEaseInEaseOut, removeOnCompletion: false)
        }
    }
    
    @objc func dimNodeTap(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.requestDismiss()
        }
    }
    
    @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
            case .changed:
                break
            case .cancelled, .ended:
                break
            default:
                break
        }
    }
    
    func applyDraggingOffset(_ offset: CGFloat) {
        self.containerOffset = min(0.0, offset)
        if self.containerOffset < -25.0 {
            //self.displayingMenu = true
        } else {
            //self.displayingMenu = false
        }
        if let layout = self.validLayout {
            self.containerLayoutUpdated(layout, transition: .immediate)
        }
    }
    
    func activateMenu() {
        if let layout = self.validLayout {
            self.displayingMenu = true
            self.containerOffset = 0.0
            self.containerLayoutUpdated(layout, transition: .animated(duration: 0.18, curve: .spring))
        }
    }
    
    func endDraggingWithVelocity(_ velocity: CGFloat) {
        if let _ = self.menuNode, velocity < -600.0 || self.containerOffset < -38.0 {
            if let layout = self.validLayout {
                self.displayingMenu = true
                self.containerOffset = 0.0
                self.containerLayoutUpdated(layout, transition: .animated(duration: 0.18, curve: .spring))
            }
        } else {
            self.requestDismiss()
        }
    }
}
