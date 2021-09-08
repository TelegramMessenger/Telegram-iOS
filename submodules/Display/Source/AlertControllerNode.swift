import Foundation
import UIKit
import AsyncDisplayKit

final class AlertControllerNode: ASDisplayNode {
    var existingAlertControllerNode: AlertControllerNode?
    
    private let centerDimView: UIImageView
    private let topDimView: UIView
    private let bottomDimView: UIView
    private let leftDimView: UIView
    private let rightDimView: UIView
    
    private let containerNode: ASDisplayNode
    private let effectNode: ASDisplayNode
    private let backgroundNode: ASDisplayNode
    private let contentNode: AlertContentNode
    private let allowInputInset: Bool
    
    private var containerLayout: ContainerViewLayout?
    
    var dismiss: (() -> Void)?
    
    init(contentNode: AlertContentNode, theme: AlertControllerTheme, allowInputInset: Bool) {
        self.allowInputInset = allowInputInset
        
        let dimColor = UIColor(white: 0.0, alpha: 0.5)
        
        self.centerDimView = UIImageView()
        self.centerDimView.backgroundColor = dimColor
        
        self.topDimView = UIView()
        self.topDimView.backgroundColor = dimColor
        
        self.bottomDimView = UIView()
        self.bottomDimView.backgroundColor = dimColor
        
        self.leftDimView = UIView()
        self.leftDimView.backgroundColor = dimColor
        
        self.rightDimView = UIView()
        self.rightDimView.backgroundColor = dimColor
        
        self.containerNode = ASDisplayNode()
        self.containerNode.layer.cornerRadius = 14.0
        self.containerNode.layer.masksToBounds = true
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = theme.backgroundColor
        
        self.effectNode = ASDisplayNode(viewBlock: {
            return UIVisualEffectView(effect: UIBlurEffect(style: theme.backgroundType == .light ? .light : .dark))
        })
        
        self.contentNode = contentNode
        
        super.init()
        
        self.view.addSubview(self.centerDimView)
        self.view.addSubview(self.topDimView)
        self.view.addSubview(self.bottomDimView)
        self.view.addSubview(self.leftDimView)
        self.view.addSubview(self.rightDimView)
        
        self.containerNode.addSubnode(self.effectNode)
        self.containerNode.addSubnode(self.backgroundNode)
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
        
        self.topDimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimmingNodeTapGesture(_:))))
        self.bottomDimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimmingNodeTapGesture(_:))))
        self.leftDimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimmingNodeTapGesture(_:))))
        self.rightDimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimmingNodeTapGesture(_:))))
    }
    
    func updateTheme(_ theme: AlertControllerTheme) {
        if let effectView = self.effectNode.view as? UIVisualEffectView {
            effectView.effect = UIBlurEffect(style: theme.backgroundType == .light ? .light : .dark)
        }
        self.backgroundNode.backgroundColor = theme.backgroundColor
        self.contentNode.updateTheme(theme)
    }
    
    func animateIn() {
        if let previousNode = self.existingAlertControllerNode {
            let transition =  ContainedViewLayoutTransition.animated(duration: 0.3, curve: .spring)
            
            previousNode.position = previousNode.position.offsetBy(dx: -previousNode.frame.width, dy: 0.0)
            self.addSubnode(previousNode)
        
            let position = self.position
            self.position = position.offsetBy(dx: self.frame.width, dy: 0.0)
            transition.animateView {
                self.position = position
            } completion: { _ in
                previousNode.removeFromSupernode()
            }

            self.existingAlertControllerNode = nil
        } else {
            self.centerDimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            self.topDimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            self.bottomDimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            self.leftDimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            self.rightDimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            self.containerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, completion: { [weak self] finished in
                if finished {
                    self?.centerDimView.backgroundColor = nil
                    self?.centerDimView.image = generateStretchableFilledCircleImage(radius: 16.0, color: nil, backgroundColor: UIColor(white: 0.0, alpha: 0.5))
                }
            })
            self.containerNode.layer.animateSpring(from: 0.8 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5, initialVelocity: 0.0, removeOnCompletion: true, additive: false, completion: nil)
        }
    }
    
    func animateOut(completion: @escaping () -> Void) {
        self.containerNode.layer.removeAllAnimations()
        self.centerDimView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        self.centerDimView.image = nil
        
        self.centerDimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        self.topDimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        self.bottomDimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        self.leftDimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        self.rightDimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        self.containerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        self.containerNode.layer.animateScale(from: 1.0, to: 0.8, duration: 0.4, removeOnCompletion: false, completion: { _ in
            completion()
        })
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.containerLayout = layout
        
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
        
        transition.updateFrame(view: self.centerDimView, frame: containerFrame)
        transition.updateFrame(view: self.topDimView, frame: CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: containerFrame.minY)))
        transition.updateFrame(view: self.bottomDimView, frame: CGRect(origin: CGPoint(x: 0.0, y: containerFrame.maxY), size: CGSize(width: layout.size.width, height: layout.size.height - containerFrame.maxY)))
        transition.updateFrame(view: self.leftDimView, frame: CGRect(origin: CGPoint(x: 0.0, y: containerFrame.minY), size: CGSize(width: containerFrame.minX, height: containerFrame.height)))
        transition.updateFrame(view: self.rightDimView, frame: CGRect(origin: CGPoint(x: containerFrame.maxX, y: containerFrame.minY), size: CGSize(width: layout.size.width - containerFrame.maxX, height: containerFrame.height)))
        
        transition.updateFrame(node: self.containerNode, frame: containerFrame)
        transition.updateFrame(node: self.effectNode, frame: CGRect(origin: CGPoint(), size: containerFrame.size))
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: containerFrame.size))
        transition.updateFrame(node: self.contentNode, frame: CGRect(origin: CGPoint(), size: containerFrame.size))
    }
    
    @objc func dimmingNodeTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.dismiss?()
        }
    }
}
