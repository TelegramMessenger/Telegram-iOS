import UIKit
import AppBundle
import AsyncDisplayKit

enum NavigationTransition {
    case Push
    case Pop
}

private let shadowWidth: CGFloat = 16.0

private func generateShadow() -> UIImage? {
    return generateImage(CGSize(width: 16.0, height: 1.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(UIColor.black.cgColor)
        context.setShadow(offset: CGSize(), blur: 16.0, color: UIColor(white: 0.0, alpha: 0.5).cgColor)
        context.fill(CGRect(origin: CGPoint(x: size.width, y: 0.0), size: CGSize(width: 16.0, height: 1.0)))
    })
}

private let shadowImage = generateShadow()

public protocol CustomNavigationTransitionNode: ASDisplayNode {
    func setup(topNavigationBar: NavigationBar, bottomNavigationBar: NavigationBar)
    func update(containerSize: CGSize, fraction: CGFloat, transition: ContainedViewLayoutTransition)
    func restore()
}

final class NavigationTransitionCoordinator {
    private var _progress: CGFloat = 0.0
    var progress: CGFloat {
        get {
            return self._progress
        }
    }
    
    private let container: NavigationContainer
    private let transition: NavigationTransition
    let isInteractive: Bool
    let topNode: ASDisplayNode
    let bottomNode: ASDisplayNode
    private let topNavigationBar: NavigationBar?
    private let bottomNavigationBar: NavigationBar?
    private let dimNode: ASDisplayNode
    private let shadowNode: ASImageNode
    private let customTransitionNode: CustomNavigationTransitionNode?
    
    private let inlineNavigationBarTransition: Bool
    
    private(set) var animatingCompletion = false
    private var currentCompletion: (() -> Void)?
    private var didUpdateProgress: ((CGFloat, ContainedViewLayoutTransition, CGRect, CGRect) -> Void)?
    
    init(transition: NavigationTransition, isInteractive: Bool, container: NavigationContainer, topNode: ASDisplayNode, topNavigationBar: NavigationBar?, bottomNode: ASDisplayNode, bottomNavigationBar: NavigationBar?, didUpdateProgress: ((CGFloat, ContainedViewLayoutTransition, CGRect, CGRect) -> Void)? = nil) {
        self.transition = transition
        self.isInteractive = isInteractive
        self.container = container
        self.didUpdateProgress = didUpdateProgress
        self.topNode = topNode
        self.bottomNode = bottomNode
        self.topNavigationBar = topNavigationBar
        self.bottomNavigationBar = bottomNavigationBar
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor.black
        self.shadowNode = ASImageNode()
        self.shadowNode.displaysAsynchronously = false
        self.shadowNode.image = shadowImage
        
        if let topNavigationBar = topNavigationBar, let bottomNavigationBar = bottomNavigationBar {
            if let customTransitionNode = topNavigationBar.makeCustomTransitionNode?(bottomNavigationBar, isInteractive) {
                self.inlineNavigationBarTransition = false
                customTransitionNode.setup(topNavigationBar: topNavigationBar, bottomNavigationBar: bottomNavigationBar)
                self.customTransitionNode = customTransitionNode
            } else if let customTransitionNode = bottomNavigationBar.makeCustomTransitionNode?(topNavigationBar, isInteractive) {
                self.inlineNavigationBarTransition = false
                customTransitionNode.setup(topNavigationBar: topNavigationBar, bottomNavigationBar: bottomNavigationBar)
                self.customTransitionNode = customTransitionNode
            } else if !topNavigationBar.isHidden, !bottomNavigationBar.isHidden, topNavigationBar.canTransitionInline, bottomNavigationBar.canTransitionInline, topNavigationBar.item?.leftBarButtonItem == nil {
                var topFrame = topNavigationBar.view.convert(topNavigationBar.bounds, to: container.view)
                var bottomFrame = bottomNavigationBar.view.convert(bottomNavigationBar.bounds, to: container.view)
                topFrame.origin.x = 0.0
                bottomFrame.origin.x = 0.0
                self.inlineNavigationBarTransition = true
                self.customTransitionNode = nil
            } else {
                self.inlineNavigationBarTransition = false
                self.customTransitionNode = nil
            }
        } else {
            self.inlineNavigationBarTransition = false
            self.customTransitionNode = nil
        }
        
        switch transition {
        case .Push:
            self.container.addSubnode(topNode)
        case .Pop:
            self.container.insertSubnode(bottomNode, belowSubnode: topNode)
        }
        
        self.container.insertSubnode(self.dimNode, belowSubnode: topNode)
        self.container.insertSubnode(self.shadowNode, belowSubnode: self.dimNode)
        if let customTransitionNode = self.customTransitionNode {
            self.container.addSubnode(customTransitionNode)
        }
        
        self.maybeCreateNavigationBarTransition()
        self.updateProgress(0.0, transition: .immediate, completion: {})
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateProgress(_ progress: CGFloat, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        self._progress = progress
        
        let position: CGFloat
        switch self.transition {
        case .Push:
            position = 1.0 - progress
        case .Pop:
            position = progress
        }
        
        var dimInset: CGFloat = 0.0
        if let bottomNavigationBar = self.bottomNavigationBar , self.inlineNavigationBarTransition {
            if self.bottomNavigationBar?.isBackgroundVisible == false || self.topNavigationBar?.isBackgroundVisible == false {
                
            } else {
                dimInset = bottomNavigationBar.frame.maxY
            }
        }
        
        let containerSize = self.container.bounds.size
        
        let topFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(position * containerSize.width), y: 0.0), size: containerSize)
        let bottomFrame = CGRect(origin: CGPoint(x: ((position - 1.0) * containerSize.width * 0.3), y: 0.0), size: containerSize)
        
        var canInvokeCompletion = false
        var hadEarlyCompletion = false
        transition.updateFrame(node: self.topNode, frame: topFrame, completion: { _ in
            if canInvokeCompletion {
                completion()
            } else {
                hadEarlyCompletion = true
            }
        })
        canInvokeCompletion = true
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(x: 0.0, y: dimInset), size: CGSize(width: max(0.0, topFrame.minX + self.container.overflowInset), height: self.container.bounds.size.height - dimInset)))
        transition.updateFrame(node: self.shadowNode, frame: CGRect(origin: CGPoint(x: self.dimNode.frame.maxX - shadowWidth, y: dimInset), size: CGSize(width: shadowWidth, height: containerSize.height - dimInset)))
        transition.updateAlpha(node: self.dimNode, alpha: (1.0 - position) * 0.15)
        transition.updateAlpha(node: self.shadowNode, alpha: (1.0 - position) * 0.9)
        
        transition.updateFrame(node: self.bottomNode, frame: bottomFrame)
        
        self.updateNavigationBarTransition(transition: transition)
        
        if let customTransitionNode = self.customTransitionNode {
            customTransitionNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: containerSize.width, height: containerSize.height))
            customTransitionNode.update(containerSize: containerSize, fraction: position, transition: transition)
        }
        
        self.didUpdateProgress?(self.progress, transition, topFrame, bottomFrame)
        
        if hadEarlyCompletion {
            completion()
        }
    }
    
    private func updateNavigationBarTransition(transition: ContainedViewLayoutTransition) {
        if let topNavigationBar = self.topNavigationBar, let bottomNavigationBar = self.bottomNavigationBar, self.inlineNavigationBarTransition {
            let position: CGFloat
            switch self.transition {
                case .Push:
                    position = 1.0 - progress
                case .Pop:
                    position = progress
            }
            
            transition.animateView {
                topNavigationBar.transitionState = NavigationBarTransitionState(navigationBar: bottomNavigationBar, transition: self.transition, role: .top, progress: position)
                bottomNavigationBar.transitionState = NavigationBarTransitionState(navigationBar: topNavigationBar, transition: self.transition, role: .bottom, progress: position)
            }
        }
    }
    
    func maybeCreateNavigationBarTransition() {
        if let topNavigationBar = self.topNavigationBar, let bottomNavigationBar = self.bottomNavigationBar, self.inlineNavigationBarTransition {
            let position: CGFloat
            switch self.transition {
                case .Push:
                    position = 1.0 - progress
                case .Pop:
                    position = progress
            }
            
            topNavigationBar.transitionState = NavigationBarTransitionState(navigationBar: bottomNavigationBar, transition: self.transition, role: .top, progress: position)
            bottomNavigationBar.transitionState = NavigationBarTransitionState(navigationBar: topNavigationBar, transition: self.transition, role: .bottom, progress: position)
        }
    }
    
    func endNavigationBarTransition() {
        if let topNavigationBar = self.topNavigationBar, let bottomNavigationBar = self.bottomNavigationBar, self.inlineNavigationBarTransition {
            topNavigationBar.transitionState = nil
            bottomNavigationBar.transitionState = nil
        }
    }
    
    func animateCancel(_ completion: @escaping () -> ()) {
        self.currentCompletion = completion
        
        self.updateProgress(0.0, transition: .animated(duration: 0.1, curve: .easeInOut), completion: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            switch strongSelf.transition {
            case .Push:
                strongSelf.topNode.removeFromSupernode()
            case .Pop:
                strongSelf.bottomNode.removeFromSupernode()
            }
            
            strongSelf.dimNode.removeFromSupernode()
            strongSelf.shadowNode.removeFromSupernode()
            
            strongSelf.customTransitionNode?.restore()
            strongSelf.customTransitionNode?.removeFromSupernode()
            
            strongSelf.endNavigationBarTransition()
            
            if let currentCompletion = strongSelf.currentCompletion {
                strongSelf.currentCompletion = nil
                currentCompletion()
            }
        })
    }
    
    func complete() {
        self.animatingCompletion = true
        
        self._progress = 1.0
        
        self.dimNode.removeFromSupernode()
        self.shadowNode.removeFromSupernode()
        
        self.customTransitionNode?.restore()
        self.customTransitionNode?.removeFromSupernode()
        
        self.endNavigationBarTransition()
        
        if let currentCompletion = self.currentCompletion {
            self.currentCompletion = nil
            currentCompletion()
        }
    }
    
    func performCompletion(completion: @escaping () -> ()) {
        self.updateProgress(1.0, transition: .immediate, completion: { [weak self] in
            if let strongSelf = self {
                strongSelf.dimNode.removeFromSupernode()
                strongSelf.shadowNode.removeFromSupernode()
                
                strongSelf.customTransitionNode?.restore()
                strongSelf.customTransitionNode?.removeFromSupernode()
                
                strongSelf.endNavigationBarTransition()
                
                if let currentCompletion = strongSelf.currentCompletion {
                    strongSelf.currentCompletion = nil
                    currentCompletion()
                }
            }
            completion()
        })
    }
    
    func animateCompletion(_ velocity: CGFloat, completion: @escaping () -> ()) {
        self.animatingCompletion = true
        let distance = (1.0 - self.progress) * self.container.bounds.size.width
        self.currentCompletion = completion
        let f = {
            self.dimNode.removeFromSupernode()
            self.shadowNode.removeFromSupernode()
            
            self.customTransitionNode?.restore()
            self.customTransitionNode?.removeFromSupernode()
            
            self.endNavigationBarTransition()
            
            if let currentCompletion = self.currentCompletion {
                self.currentCompletion = nil
                currentCompletion()
            }
        }
        
        if abs(velocity) < CGFloat.ulpOfOne && abs(self.progress) < CGFloat.ulpOfOne {
            self.updateProgress(1.0, transition: .animated(duration: 0.5, curve: .spring), completion: {
                f()
            })
        } else {
            self.updateProgress(1.0, transition: .animated(duration: Double(max(0.05, min(0.2, abs(distance / velocity)))), curve: .easeInOut), completion: {
                f()
            })
        }
    }
}
