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
import SyncCore
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
            
            if self.isButtonHidden == hidden || (!slide && self.isSlidOffscreen) {
                return
            }
            self.isButtonHidden = hidden
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
            guard let actionButton = self.controller?.actionButton, let leftButton = self.controller?.audioOutputNode, let rightButton = self.controller?.leaveNode else {
                return
            }
            
            actionButton.update(snap: true, animated: !self.isSlidOffscreen && !self.isButtonHidden)
            if self.isSlidOffscreen {
                leftButton.isHidden = false
                rightButton.isHidden = false
                actionButton.layer.sublayerTransform = CATransform3DMakeTranslation(slideOffset, 0.0, 0.0)
                return
            } else if self.isButtonHidden {
                leftButton.isHidden = false
                rightButton.isHidden = false
                actionButton.isHidden = true
                return
            }
                        
            self.initialLeftButtonPosition = leftButton.position
            self.initialRightButtonPosition = rightButton.position
            
            let center = CGPoint(x: actionButton.frame.width / 2.0, y: actionButton.frame.height / 2.0)
            leftButton.layer.animatePosition(from: leftButton.position, to: center, duration: 0.15, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { [weak leftButton] _ in
                leftButton?.isHidden = true
                leftButton?.layer.removeAllAnimations()
            })
            rightButton.layer.animatePosition(from: rightButton.position, to: center, duration: 0.15, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { [weak rightButton] _ in
                rightButton?.isHidden = true
                rightButton?.layer.removeAllAnimations()
            })
            
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
        func animateOut(reclaim: Bool, completion: @escaping (Bool) -> Void) {
            guard let actionButton = self.controller?.actionButton, let leftButton = self.controller?.audioOutputNode, let rightButton = self.controller?.leaveNode, let layout = self.validLayout else {
                return
            }
            
            if reclaim {
                self.dismissed = true
                let targetPosition = CGPoint(x: layout.size.width / 2.0, y: layout.size.height - layout.intrinsicInsets.bottom - 268.0 / 2.0)
                if self.isSlidOffscreen {
                    self.isSlidOffscreen = false
                    self.isButtonHidden = true
                    actionButton.layer.sublayerTransform = CATransform3DIdentity
                    actionButton.update(snap: false, animated: false)
                    actionButton.position = CGPoint(x: targetPosition.x, y: 268.0 / 2.0)
                    completion(true)
                } else if self.isButtonHidden {
                    actionButton.isHidden = false
                    actionButton.layer.removeAllAnimations()
                    actionButton.layer.sublayerTransform = CATransform3DIdentity
                    actionButton.update(snap: false, animated: false)
                    actionButton.position = CGPoint(x: targetPosition.x, y: 268.0 / 2.0)
                    completion(true)
                } else {
                    self.animating = true
                    let sourcePoint = actionButton.position
                    var midPoint = CGPoint(x: (sourcePoint.x + targetPosition.x) / 2.0 - 25.0, y: (sourcePoint.y + targetPosition.y) / 2.0 + 25.0)
                    if sourcePoint.y < layout.size.height - 100.0 {
                        midPoint.x = (sourcePoint.x + targetPosition.x) / 2.0 + 30.0
                        midPoint.y = (sourcePoint.y + targetPosition.y) / 2.0 + 40.0
                    }
                    
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
                    
                    if let leftButtonPosition = self.initialLeftButtonPosition, let rightButtonPosition = self.initialRightButtonPosition {
                        let center = CGPoint(x: actionButton.frame.width / 2.0, y: actionButton.frame.height / 2.0)
                        
                        leftButton.isHidden = false
                        leftButton.layer.animatePosition(from: center, to: leftButtonPosition, duration: 0.25, delay: 0.1, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false)
                        
                        rightButton.isHidden = false
                        rightButton.layer.animatePosition(from: center, to: rightButtonPosition, duration: 0.25, delay: 0.1, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false)
                    }
                    
                    actionButton.update(snap: false, animated: true)
                    actionButton.position = targetPosition
                    actionButton.layer.animateKeyframes(values: keyframes, duration: 0.37, keyPath: "position", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, completion: { _ in
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
            
            if let actionButton = self.controller?.actionButton, let leftButton = self.controller?.audioOutputNode, let rightButton = self.controller?.leaveNode, !self.animating && !self.dismissed {
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
                    self.addSubnode(actionButton)
                    self.animateIn(from: convertedRect)
                }
            }
        }
    }
    
    private weak var actionButton: VoiceChatActionButton?
    private weak var audioOutputNode: CallControllerButtonItemNode?
    private weak var leaveNode: CallControllerButtonItemNode?
    
    private var controllerNode: Node {
        return self.displayNode as! Node
    }
    
    private var disposable: Disposable?
        
    init(actionButton: VoiceChatActionButton, audioOutputNode: CallControllerButtonItemNode, leaveNode: CallControllerButtonItemNode, navigationController: NavigationController?) {
        self.actionButton = actionButton
        self.audioOutputNode = audioOutputNode
        self.leaveNode = leaveNode
        
        super.init(navigationBarPresentationData: nil)
                         
        self.statusBar.statusBarStyle = .Ignore
        
        if case .active(.cantSpeak) = actionButton.stateValue {
        } else {
            self.additionalSideInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 75.0)
        }
        if let navigationController = navigationController {
            let controllers: Signal<[UIViewController], NoError> = .single([])
            |> then(navigationController.viewControllersSignal)
            let overlayControllers: Signal<[UIViewController], NoError> = .single([])
            |> then(navigationController.overlayControllersSignal)
            
            self.disposable = (combineLatest(queue: Queue.mainQueue(), controllers, overlayControllers, actionButton.state)).start(next: { [weak self] controllers, overlayControllers, state in
                if let strongSelf = self {
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
                        if let chatController = controllers.last as? ChatController, chatController.isSendButtonVisible {
                            slide = false
                            animated = false
                        } else {
                            hidden = false
                        }
                    }
                    if overlayControllersCount > 0 {
                        hidden = true
                    }
                    
                    if case .active(.cantSpeak) = state {
                        hidden = true
                    }
                    if hasVoiceChatController {
                        hidden = false
                        animated = false
                    }
                    
                    strongSelf.controllerNode.update(hidden: hidden, slide: slide, animated: animated)
                    
                    let previousInsets = strongSelf.additionalSideInsets
                    strongSelf.additionalSideInsets = hidden ? UIEdgeInsets() : UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 75.0)
                    
                    if previousInsets != strongSelf.additionalSideInsets {
                        navigationController.requestLayout(transition: .animated(duration: 0.3, curve: .easeInOut))
                    }
                }
            })
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
    
    public override func dismiss(completion: (() -> Void)? = nil) {
        super.dismiss(completion: completion)
        self.presentingViewController?.dismiss(animated: false, completion: nil)
        completion?()
    }
            
    func animateOut(reclaim: Bool, completion: @escaping (Bool) -> Void) {
        self.controllerNode.animateOut(reclaim: reclaim, completion: completion)
    }
    
    public func update(hidden: Bool, slide: Bool, animated: Bool) {
        self.controllerNode.update(hidden: hidden, slide: slide, animated: animated)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, transition: transition)
    }
}
