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

final class VoiceChatOverlayController: ViewController {
    private final class Node: ViewControllerTracingNode, UIGestureRecognizerDelegate {
        private weak var controller: VoiceChatOverlayController?
        
        private var validLayout: ContainerViewLayout?
    
        init(controller: VoiceChatOverlayController) {
            self.controller = controller
        }
    
        func animateIn(from: CGRect) {
            guard let actionButton = self.controller?.actionButton else {
                return
            }
            
            let targetPosition = actionButton.position
            let sourcePoint = CGPoint(x: from.midX, y: from.midY)
            let midPoint = CGPoint(x: (sourcePoint.x + targetPosition.x) / 2.0, y: sourcePoint.y + 120.0)
            
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
            
            actionButton.layer.animateKeyframes(values: keyframes, duration: 0.3, keyPath: "position", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, completion: { [weak self] _ in
            })
        }
        
        func animateOut(reclaim: Bool, completion: @escaping () -> Void) {
            guard let actionButton = self.controller?.actionButton, let layout = self.validLayout else {
                return
            }
            
            if reclaim {
                let targetPosition = CGPoint(x: layout.size.width / 2.0, y: layout.size.height - layout.intrinsicInsets.bottom - 268.0 / 2.0)
                let sourcePoint = actionButton.position
                let midPoint = CGPoint(x: (sourcePoint.x + targetPosition.x) / 2.0 - 20.0, y: sourcePoint.y + 10.0)
                
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
                
                actionButton.update(snap: false)
                actionButton.position = targetPosition
                actionButton.layer.animateKeyframes(values: keyframes, duration: 0.4, keyPath: "position", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, completion: { [weak self] _ in
                    completion()
                    self?.controller?.dismiss()
                })
            } else {
                actionButton.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { [weak self, weak actionButton] _ in
                    actionButton?.removeFromSupernode()
                    self?.controller?.dismiss()
                })
            }
        }
                
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if let actionButton = self.controller?.actionButton, actionButton.supernode === self, actionButton.frame.contains(point) {
                return actionButton.hitTest(self.view.convert(point, to: actionButton.view), with: event)
            } else {
                return nil
            }
        }
        
        func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
            self.validLayout = layout
            
            if let actionButton = self.controller?.actionButton {
                let convertedRect = actionButton.view.convert(actionButton.bounds, to: self.view)
                let insets = layout.insets(options: [.input])                
                transition.updatePosition(node: actionButton, position: CGPoint(x: layout.size.width - layout.safeInsets.right - 21.0, y: layout.size.height - insets.bottom - 22.0))
                
                if actionButton.supernode !== self {
                    self.addSubnode(actionButton)
                    
                    actionButton.update(snap: true)
                    self.animateIn(from: convertedRect)
                }
            }
        }
    }
    
    private weak var actionButton: VoiceChatActionButton?
    
    private var controllerNode: Node {
        return self.displayNode as! Node
    }
    
    init(actionButton: VoiceChatActionButton) {
        self.actionButton = actionButton
        
        super.init(navigationBarPresentationData: nil)
                         
        self.statusBar.statusBarStyle = .Ignore
        self.additionalSideInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 75.0)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(controller: self)
        self.displayNodeDidLoad()
    }
    
    override func dismiss(completion: (() -> Void)? = nil) {
        super.dismiss(completion: completion)
        self.presentingViewController?.dismiss(animated: false, completion: nil)
        completion?()
    }
            
    func animateOut(reclaim: Bool, completion: @escaping () -> Void) {
        self.controllerNode.animateOut(reclaim: reclaim, completion: completion)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, transition: transition)
    }
}
