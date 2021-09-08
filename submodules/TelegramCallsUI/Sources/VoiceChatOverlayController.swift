import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import TelegramVoip
import TelegramAudio
import AccountContext
import Postbox
import TelegramCore
import AppBundle
import ContextUI
import PresentationDataUtils
import TooltipUI

private let slideOffset: CGFloat = 80.0 + 44.0

public final class VoiceChatOverlayController: ViewController {
    private final class Node: ViewControllerTracingNode, UIGestureRecognizerDelegate {
        private weak var controller: VoiceChatOverlayController?
        
        private var validLayout: ContainerViewLayout?
    
        init(controller: VoiceChatOverlayController) {
            self.controller = controller
            
            super.init()
            
            self.clipsToBounds = true
        }
        
        private var isButtonHidden = false
        private var isSlidOffscreen = false
        func update(hidden: Bool, slide: Bool, animated: Bool) {
            guard let actionButton = self.controller?.actionButton else {
                return
            }
            
            if self.isButtonHidden == hidden {
                return
            }
            self.isButtonHidden = hidden
            
            var slide = slide
            if self.isSlidOffscreen && !hidden {
                slide = true
            }
            
            self.isSlidOffscreen = hidden && slide
            
            guard actionButton.supernode === self else {
                return
            }
            
            if animated {
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.4, curve: .spring)
                if hidden {
                    if slide {
                        actionButton.isHidden = false
                        transition.updateSublayerTransformOffset(layer: actionButton.layer, offset: CGPoint(x: slideOffset, y: 0.0))
                    } else {
                        actionButton.layer.removeAllAnimations()
                        actionButton.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { [weak actionButton] finished in
                            if finished {
                                actionButton?.isHidden = true
                            }
                        })
                    }
                } else {
                    actionButton.isHidden = false
                    actionButton.layer.removeAllAnimations()
                    if slide {
                        transition.updateSublayerTransformOffset(layer: actionButton.layer, offset: CGPoint())
                    } else {
                        actionButton.layer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4)
                    }
                }
            } else {
                actionButton.isHidden = hidden
                actionButton.layer.removeAllAnimations()
                if hidden {
                    if slide {
                        actionButton.layer.sublayerTransform = CATransform3DMakeTranslation(slideOffset, 0.0, 0.0)
                    }
                } else {
                    if slide {
                        actionButton.layer.sublayerTransform = CATransform3DIdentity
                    }
                }
            }
        }
        
        private var initialLeftButtonPosition: CGPoint?
        private var initialRightButtonPosition: CGPoint?
        
        func animateIn(from: CGRect) {
            guard let controller = self.controller, let actionButton = controller.actionButton, let audioOutputNode = controller.audioOutputNode, let cameraNode = controller.cameraNode,  let rightButton = controller.leaveNode else {
                return
            }
            let leftButton: CallControllerButtonItemNode
            if audioOutputNode.alpha.isZero {
                leftButton = cameraNode
            } else {
                leftButton = audioOutputNode
            }
            
            self.initialLeftButtonPosition = leftButton.position
            self.initialRightButtonPosition = rightButton.position
            
            actionButton.update(snap: true, animated: !self.isSlidOffscreen && !self.isButtonHidden)
            if self.isSlidOffscreen {
                leftButton.isHidden = true
                rightButton.isHidden = true
                actionButton.layer.sublayerTransform = CATransform3DMakeTranslation(slideOffset, 0.0, 0.0)
                return
            } else if self.isButtonHidden {
                leftButton.isHidden = true
                rightButton.isHidden = true
                actionButton.isHidden = true
                return
            }
            
            let center = CGPoint(x: actionButton.frame.width / 2.0, y: actionButton.frame.height / 2.0)
            leftButton.layer.animatePosition(from: leftButton.position, to: center, duration: 0.15, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { [weak leftButton] _ in
                leftButton?.isHidden = true
                leftButton?.textNode.layer.removeAllAnimations()
                leftButton?.layer.removeAllAnimations()
            })
            leftButton.layer.animateScale(from: 1.0, to: 0.5, duration: 0.15, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
            rightButton.layer.animatePosition(from: rightButton.position, to: center, duration: 0.15, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { [weak rightButton] _ in
                rightButton?.isHidden = true
                rightButton?.textNode.layer.removeAllAnimations()
                rightButton?.layer.removeAllAnimations()
            })
            rightButton.layer.animateScale(from: 1.0, to: 0.5, duration: 0.15, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
            leftButton.textNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.1, removeOnCompletion: false)
            rightButton.textNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.1, removeOnCompletion: false)
            
            let targetPosition = actionButton.position
            let sourcePoint = CGPoint(x: from.midX, y: from.midY)
            let midPoint = CGPoint(x: (sourcePoint.x + targetPosition.x) / 2.0, y: sourcePoint.y + 90.0)
            
            let x1 = sourcePoint.x
            let y1 = sourcePoint.y
            let x2 = midPoint.x
            let y2 = midPoint.y
            let x3 = targetPosition.x
            let y3 = targetPosition.y
            
            let a = (x3 * (y2 - y1) + x2 * (y1 - y3) + x1 * (y3 - y2)) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
            let b = (x1 * x1 * (y2 - y3) + x3 * x3 * (y1 - y2) + x2 * x2 * (y3 - y1)) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
            let c = (x2 * x2 * (x3 * y1 - x1 * y3) + x2 * (x1 * x1 * y3 - x3 * x3 * y1) + x1 * x3 * (x3 - x1) * y2) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
            
            var keyframes: [AnyObject] = []
            for i in 0 ..< 10 {
                let k = CGFloat(i) / CGFloat(10 - 1)
                let x = sourcePoint.x * (1.0 - k) + targetPosition.x * k
                let y = a * x * x + b * x + c
                keyframes.append(NSValue(cgPoint: CGPoint(x: x, y: y)))
            }
            
            actionButton.layer.animateKeyframes(values: keyframes, duration: 0.2, keyPath: "position", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, completion: { _ in
            })
        }
        
        private var animating = false
        private var dismissed = false
        func animateOut(reclaim: Bool, targetPosition: CGPoint, completion: @escaping (Bool) -> Void) {
            guard let controller = self.controller, let actionButton = controller.actionButton, let audioOutputNode = controller.audioOutputNode, let cameraNode = controller.cameraNode,  let rightButton = controller.leaveNode else {
                return
            }
            let leftButton: CallControllerButtonItemNode
            if audioOutputNode.alpha.isZero {
                leftButton = cameraNode
            } else {
                leftButton = audioOutputNode
            }
            
            if reclaim {
                self.dismissed = true
                if self.isSlidOffscreen {
                    self.isSlidOffscreen = false
                    self.isButtonHidden = true
                    actionButton.layer.sublayerTransform = CATransform3DIdentity
                    actionButton.update(snap: false, animated: false)
                    actionButton.position = CGPoint(x: targetPosition.x, y: bottomAreaHeight / 2.0)
                    
                    leftButton.isHidden = false
                    rightButton.isHidden = false
                    if let leftButtonPosition = self.initialLeftButtonPosition {
                        leftButton.position = CGPoint(x: actionButton.position.x + leftButtonPosition.x, y: actionButton.position.y)
                    }
                    if let rightButtonPosition = self.initialRightButtonPosition {
                        rightButton.position = CGPoint(x: actionButton.position.x + rightButtonPosition.x, y: actionButton.position.y)
                    }
                    completion(true)
                } else if self.isButtonHidden {
                    actionButton.isHidden = false
                    actionButton.layer.removeAllAnimations()
                    actionButton.layer.sublayerTransform = CATransform3DIdentity
                    actionButton.update(snap: false, animated: false)
                    actionButton.position = CGPoint(x: targetPosition.x, y: bottomAreaHeight / 2.0)
                   
                    leftButton.isHidden = false
                    rightButton.isHidden = false
                    if let leftButtonPosition = self.initialLeftButtonPosition {
                        leftButton.position = CGPoint(x: actionButton.position.x + leftButtonPosition.x, y: actionButton.position.y)
                    }
                    if let rightButtonPosition = self.initialRightButtonPosition {
                        rightButton.position = CGPoint(x: actionButton.position.x + rightButtonPosition.x, y: actionButton.position.y)
                    }
                    completion(true)
                } else {
                    self.animating = true
                    
                    let sourcePoint = actionButton.position
                    let transitionNode = ASDisplayNode()
                    transitionNode.position = sourcePoint
                    transitionNode.addSubnode(actionButton)
                    actionButton.position = CGPoint()
                    self.addSubnode(transitionNode)
                     
                    if let leftButtonPosition = self.initialLeftButtonPosition, let rightButtonPosition = self.initialRightButtonPosition {
                        let center = CGPoint(x: actionButton.frame.width / 2.0, y: actionButton.frame.height / 2.0)
                        
                        leftButton.isHidden = false
                        rightButton.isHidden = false
                        
                        leftButton.layer.animatePosition(from: center, to: leftButtonPosition, duration: 0.26, delay: 0.07, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false)
                        rightButton.layer.animatePosition(from: center, to: rightButtonPosition, duration: 0.26, delay: 0.07, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false)
                        
                        leftButton.layer.animateScale(from: 0.55, to: 1.0, duration: 0.26, delay: 0.06, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
                        rightButton.layer.animateScale(from: 0.55, to: 1.0, duration: 0.26, delay: 0.06, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
                        
                        leftButton.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1, delay: 0.05)
                        rightButton.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1, delay: 0.05)
                    }
                    
                    actionButton.update(snap: false, animated: true)
                    actionButton.position = CGPoint(x: targetPosition.x - sourcePoint.x, y: 80.0)
                    
                    let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                    transition.animateView {
                        transitionNode.position = CGPoint(x: transitionNode.position.x, y: targetPosition.y - 80.0)
                    }
                    
                    actionButton.layer.animatePosition(from: CGPoint(), to: actionButton.position, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, completion: { _ in
                        self.animating = false
                        completion(false)
                    })
                }
            } else {
                actionButton.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { [weak self, weak actionButton] _ in
                    actionButton?.removeFromSupernode()
                    self?.controller?.dismiss()
                })
            }
        }
                
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if let actionButton = self.controller?.actionButton, actionButton.supernode === self && !self.isButtonHidden {
                let actionButtonSize = CGSize(width: 84.0, height: 84.0)
                let actionButtonFrame = CGRect(origin: CGPoint(x: actionButton.position.x - actionButtonSize.width / 2.0, y: actionButton.position.y - actionButtonSize.height / 2.0), size: actionButtonSize)
                if actionButtonFrame.contains(point) {
                    return actionButton.hitTest(self.view.convert(point, to: actionButton.view), with: event)
                }
            }
            return nil
        }
        
        private var didAnimateIn = false
        func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
            self.validLayout = layout
            
            if let controller = self.controller, let actionButton = controller.actionButton, let audioOutputNode = controller.audioOutputNode, let cameraNode = controller.cameraNode, let rightButton = controller.leaveNode, !self.animating && !self.dismissed {
                let leftButton: CallControllerButtonItemNode
                if audioOutputNode.alpha.isZero {
                    leftButton = cameraNode
                } else {
                    leftButton = audioOutputNode
                }
                
                let convertedRect = actionButton.view.convert(actionButton.bounds, to: self.view)
                let insets = layout.insets(options: [.input])
                
                if !self.didAnimateIn {
                    let leftButtonFrame = leftButton.view.convert(leftButton.bounds, to: actionButton.bottomNode.view)
                    actionButton.bottomNode.addSubnode(leftButton)
                    leftButton.frame = leftButtonFrame
                    
                    let rightButtonFrame = rightButton.view.convert(rightButton.bounds, to: actionButton.bottomNode.view)
                    actionButton.bottomNode.addSubnode(rightButton)
                    rightButton.frame = rightButtonFrame
                }
                
                transition.updatePosition(node: actionButton, position: CGPoint(x: layout.size.width - layout.safeInsets.right - 21.0, y: layout.size.height - insets.bottom - 22.0))
                
                if actionButton.supernode !== self && !self.didAnimateIn {
                    self.didAnimateIn = true
                    actionButton.ignoreHierarchyChanges = true
                    self.addSubnode(actionButton)
                    var hidden = false
                    if let initiallyHidden = self.controller?.initiallyHidden, initiallyHidden {
                        hidden = initiallyHidden
                    }
                    if hidden {
                        self.update(hidden: true, slide: true, animated: false)
                    }
                    self.animateIn(from: convertedRect)
                    if hidden {
                        self.controller?.setupVisibilityUpdates()
                    }
                    actionButton.ignoreHierarchyChanges = false
                }
            }
        }
    }
    
    private weak var actionButton: VoiceChatActionButton?
    private weak var cameraNode: CallControllerButtonItemNode?
    private weak var audioOutputNode: CallControllerButtonItemNode?
    private weak var leaveNode: CallControllerButtonItemNode?
    
    private var controllerNode: Node {
        return self.displayNode as! Node
    }
    
    private var disposable: Disposable?
    
    private weak var parentNavigationController: NavigationController?
    private var currentParams: ([UIViewController], [UIViewController], VoiceChatActionButton.State)?
    fileprivate var initiallyHidden: Bool
    
    init(actionButton: VoiceChatActionButton, audioOutputNode: CallControllerButtonItemNode, cameraNode: CallControllerButtonItemNode, leaveNode: CallControllerButtonItemNode, navigationController: NavigationController?, initiallyHidden: Bool) {
        self.actionButton = actionButton
        self.audioOutputNode = audioOutputNode
        self.cameraNode = cameraNode
        self.leaveNode = leaveNode
        self.parentNavigationController = navigationController
        self.initiallyHidden = initiallyHidden
        
        super.init(navigationBarPresentationData: nil)
                         
        self.statusBar.statusBarStyle = .Ignore
        
        if case .active(.cantSpeak) = actionButton.stateValue {
        } else if !initiallyHidden {
            self.additionalSideInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 75.0)
        }
        
        if !self.initiallyHidden {
            self.setupVisibilityUpdates()
        }
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(controller: self)
        self.displayNodeDidLoad()
    }
    
    private func setupVisibilityUpdates() {
        if let navigationController = self.parentNavigationController, let actionButton = self.actionButton {
            let controllers: Signal<[UIViewController], NoError> = .single([])
            |> then(navigationController.viewControllersSignal)
            let overlayControllers: Signal<[UIViewController], NoError> = .single([])
            |> then(navigationController.overlayControllersSignal)
            
            self.disposable = (combineLatest(queue: Queue.mainQueue(), controllers, overlayControllers, actionButton.state)).start(next: { [weak self] controllers, overlayControllers, state in
                if let strongSelf = self {
                    strongSelf.currentParams = (controllers, overlayControllers, state)
                    strongSelf.updateVisibility()
                }
            })
        }
    }
    
    public override func dismiss(completion: (() -> Void)? = nil) {
        super.dismiss(completion: completion)
        self.presentingViewController?.dismiss(animated: false, completion: nil)
        completion?()
    }
            
    func animateOut(reclaim: Bool, targetPosition: CGPoint, completion: @escaping (Bool) -> Void) {
        self.controllerNode.animateOut(reclaim: reclaim, targetPosition: targetPosition, completion: completion)
    }
    
    public func updateVisibility() {
        guard let (controllers, overlayControllers, state) = self.currentParams else {
            return
        }
        var hasVoiceChatController = false
        var overlayControllersCount = 0
        for controller in controllers {
            if controller is VoiceChatController {
                hasVoiceChatController = true
            }
        }
        for controller in overlayControllers {
            if controller is TooltipController || controller is TooltipScreen || controller is AlertController {
            } else {
                overlayControllersCount += 1
            }
        }
        
        var slide = true
        var hidden = true
        var animated = true

        if controllers.count == 1 || controllers.last is ChatController {
            if let chatController = controllers.last as? ChatController {
                slide = false
                if !chatController.isSendButtonVisible {
                   hidden = false
                }
            } else {
                hidden = false
            }
        }
        if let tabBarController = controllers.last as? TabBarController {
            if let chatListController = tabBarController.controllers[tabBarController.selectedIndex] as? ChatListController, chatListController.isSearchActive {
                hidden = true
            }
        }
        if overlayControllersCount > 0 {
            hidden = true
        }
        
        switch state {
            case .active(.cantSpeak), .button, .scheduled:
                hidden = true
            default:
                break
        }

        if hasVoiceChatController {
            hidden = false
            animated = self.initiallyHidden
            self.initiallyHidden = false
        }
        
        self.controllerNode.update(hidden: hidden, slide: slide, animated: animated)
        
        let previousInsets = self.additionalSideInsets
        self.additionalSideInsets = hidden ? UIEdgeInsets() : UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 75.0)
        if previousInsets != self.additionalSideInsets {
            self.parentNavigationController?.requestLayout(transition: .animated(duration: 0.3, curve: .easeInOut))
        }
    }
    
    private let hiddenPromise = ValuePromise<Bool>()
    public func update(hidden: Bool, slide: Bool, animated: Bool) {
        self.hiddenPromise.set(hidden)
        self.controllerNode.update(hidden: hidden, slide: slide, animated: animated)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, transition: transition)
    }
}
