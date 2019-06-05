import Foundation
import UIKit
import AsyncDisplayKit

final class AlertControllerNode: ASDisplayNode {
    private let dimmingNode: ASDisplayNode
    private let containerNode: ASDisplayNode
    private let effectNode: ASDisplayNode
    private let contentNode: AlertContentNode
    private let allowInputInset: Bool
    
    private var containerLayout: ContainerViewLayout?
    
    var dismiss: (() -> Void)?
    
    init(contentNode: AlertContentNode, theme: AlertControllerTheme, allowInputInset: Bool) {
        self.allowInputInset = allowInputInset
        self.dimmingNode = ASDisplayNode()
        self.dimmingNode.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        
        self.containerNode = ASDisplayNode()
        self.containerNode.backgroundColor = theme.backgroundColor
        self.containerNode.layer.cornerRadius = 14.0
        self.containerNode.layer.masksToBounds = true
        
        self.effectNode = ASDisplayNode(viewBlock: {
            let view = UIView()
            return view
        })
        
        self.contentNode = contentNode
        
        super.init()
        
        self.addSubnode(self.dimmingNode)
        
        self.addSubnode(self.effectNode)
        
        self.containerNode.addSubnode(self.contentNode)
        self.addSubnode(self.containerNode)
        
        self.contentNode.requestLayout = { [weak self] transition in
            if let strongSelf = self, let containerLayout = self?.containerLayout {
                strongSelf.containerLayoutUpdated(containerLayout, transition: transition)
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.dimmingNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimmingNodeTapGesture(_:))))
    }
    
    func updateTheme(_ theme: AlertControllerTheme) {
        self.containerNode.backgroundColor = theme.backgroundColor
        self.contentNode.updateTheme(theme)
    }
    
    func animateIn() {
        self.dimmingNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        self.containerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
        self.containerNode.layer.animateSpring(from: 0.8 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5, initialVelocity: 0.0, removeOnCompletion: true, additive: false, completion: nil)
    }
    
    func animateOut(completion: @escaping () -> Void) {
        self.dimmingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        self.containerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        self.containerNode.layer.animateScale(from: 1.0, to: 0.8, duration: 0.4, removeOnCompletion: false, completion: { _ in
            completion()
        })
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.containerLayout = layout
        
        transition.updateFrame(node: self.dimmingNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        var insetOptions: ContainerViewLayoutInsetOptions = [.statusBar]
        if self.allowInputInset {
            insetOptions.insert(.input)
        }
        var insets = layout.insets(options: insetOptions)
        let maxWidth = min(240.0, layout.size.width - 70.0)
        insets.left = floor((layout.size.width - maxWidth) / 2.0)
        insets.right = floor((layout.size.width - maxWidth) / 2.0)
        let contentAvailableFrame = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: CGSize(width: layout.size.width - insets.right, height: layout.size.height - insets.top - insets.bottom))
        let contentSize = self.contentNode.updateLayout(size: contentAvailableFrame.size, transition: transition)
        let containerSize = CGSize(width: contentSize.width, height: contentSize.height)
        let containerFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - containerSize.width) / 2.0), y: contentAvailableFrame.minY + floor((contentAvailableFrame.size.height - containerSize.height) / 2.0)), size: containerSize)
        
        transition.updateFrame(node: self.containerNode, frame: containerFrame)
        transition.updateFrame(node: self.effectNode, frame: containerFrame)
        transition.updateFrame(node: self.contentNode, frame: CGRect(origin: CGPoint(), size: containerFrame.size))
    }
    
    @objc func dimmingNodeTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.dismiss?()
        }
    }
}
