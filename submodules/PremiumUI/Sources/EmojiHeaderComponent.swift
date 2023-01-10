import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import SceneKit
import GZip
import AppBundle
import LegacyComponents
import AvatarNode
import AccountContext
import TelegramCore
import AnimationCache
import MultiAnimationRenderer
import EmojiStatusComponent

private let sceneVersion: Int = 3

class EmojiHeaderComponent: Component {
    let context: AccountContext
    let animationCache: AnimationCache
    let animationRenderer: MultiAnimationRenderer
    let placeholderColor: UIColor
    let accentColor: UIColor
    let fileId: Int64
    let isVisible: Bool
    let hasIdleAnimations: Bool
        
    init(
        context: AccountContext,
        animationCache: AnimationCache,
        animationRenderer: MultiAnimationRenderer,
        placeholderColor: UIColor,
        accentColor: UIColor,
        fileId: Int64,
        isVisible: Bool,
        hasIdleAnimations: Bool
    ) {
        self.context = context
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        self.placeholderColor = placeholderColor
        self.accentColor = accentColor
        self.fileId = fileId
        self.isVisible = isVisible
        self.hasIdleAnimations = hasIdleAnimations
    }
    
    static func ==(lhs: EmojiHeaderComponent, rhs: EmojiHeaderComponent) -> Bool {
        return lhs.placeholderColor == rhs.placeholderColor && lhs.accentColor == rhs.accentColor && lhs.fileId == rhs.fileId && lhs.isVisible == rhs.isVisible && lhs.hasIdleAnimations == rhs.hasIdleAnimations
    }
    
    final class View: UIView, SCNSceneRendererDelegate, ComponentTaggedView {
        final class Tag {
        }
        
        func matches(tag: Any) -> Bool {
            if let _ = tag as? Tag {
                return true
            }
            return false
        }
        
        private var _ready = Promise<Bool>(true)
        var ready: Signal<Bool, NoError> {
            return self._ready.get()
        }
        
        weak var animateFrom: UIView?
        weak var containerView: UIView?
        
        let statusView: ComponentHostView<Empty>
        
        private var hasIdleAnimations = false
        
        override init(frame: CGRect) {
            self.statusView = ComponentHostView<Empty>()
        
            super.init(frame: frame)
        
            self.statusView.isHidden = true
            self.addSubview(self.statusView)
                        
            self.disablesInteractiveModalDismiss = true
            self.disablesInteractiveTransitionGestureRecognizer = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        var scheduledAnimateIn = false
        override func didMoveToWindow() {
            super.didMoveToWindow()
            
            if self.scheduledAnimateIn {
                self.animateIn()
                self.scheduledAnimateIn = false
            }
        }
         
        func animateIn() {
            guard let animateFrom = self.animateFrom, var containerView = self.containerView else {
                return
            }
            
            guard let _ = self.window else {
                self.scheduledAnimateIn = true
                return
            }
                        
            self.statusView.isHidden = false
            containerView = containerView.subviews[1].subviews[1]
            
            let initialPosition = self.statusView.center
            let targetPosition = self.statusView.superview!.convert(self.statusView.center, to: containerView)
            let sourcePosition = animateFrom.superview!.convert(animateFrom.center, to: containerView).offsetBy(dx: 0.0, dy: 0.0)
            
            containerView.addSubview(self.statusView)
            self.statusView.center = targetPosition
            
            animateFrom.alpha = 0.0
            self.statusView.layer.animateScale(from: 0.24, to: 1.0, duration: 0.3, timingFunction: CAMediaTimingFunctionName.linear.rawValue)

            self.statusView.layer.animatePosition(from: sourcePosition, to: targetPosition, duration: 0.55, timingFunction: kCAMediaTimingFunctionSpring)
            
            Queue.mainQueue().after(0.55, {
                self.addSubview(self.statusView)
                self.statusView.center = initialPosition
            })
            
            Queue.mainQueue().after(0.4, {
                animateFrom.alpha = 1.0
            })
            
            self.animateFrom = nil
            self.containerView = nil
        }
        
        func update(component: EmojiHeaderComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.hasIdleAnimations = component.hasIdleAnimations
            
            let size = self.statusView.update(
                transition: .immediate,
                component: AnyComponent(EmojiStatusComponent(
                    context: component.context,
                    animationCache: component.animationCache,
                    animationRenderer: component.animationRenderer,
                    content: .animation(
                        content: .customEmoji(fileId: component.fileId),
                        size: CGSize(width: 100.0, height: 100.0),
                        placeholderColor: component.placeholderColor,
                        themeColor: component.accentColor,
                        loopMode: .forever
                    ),
                    isVisibleForAnimations: true,
                    action: nil
                )),
                environment: {},
                containerSize: CGSize(width: 96.0, height: 96.0)
            )
            self.statusView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - size.width) / 2.0), y: 63.0), size: size)
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

private func generateParabollicMotionKeyframes(from sourcePoint: CGPoint, to targetPosition: CGPoint, elevation: CGFloat) -> [CGPoint] {
    let midPoint = CGPoint(x: (sourcePoint.x + targetPosition.x) / 2.0, y: sourcePoint.y - elevation)
    
    let x1 = sourcePoint.x
    let y1 = sourcePoint.y
    let x2 = midPoint.x
    let y2 = midPoint.y
    let x3 = targetPosition.x
    let y3 = targetPosition.y
    
    var keyframes: [CGPoint] = []
    if abs(y1 - y3) < 5.0 && abs(x1 - x3) < 5.0 {
        for i in 0 ..< 10 {
            let k = CGFloat(i) / CGFloat(10 - 1)
            let x = sourcePoint.x * (1.0 - k) + targetPosition.x * k
            let y = sourcePoint.y * (1.0 - k) + targetPosition.y * k
            keyframes.append(CGPoint(x: x, y: y))
        }
    } else {
        let a = (x3 * (y2 - y1) + x2 * (y1 - y3) + x1 * (y3 - y2)) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
        let b = (x1 * x1 * (y2 - y3) + x3 * x3 * (y1 - y2) + x2 * x2 * (y3 - y1)) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
        let c = (x2 * x2 * (x3 * y1 - x1 * y3) + x2 * (x1 * x1 * y3 - x3 * x3 * y1) + x1 * x3 * (x3 - x1) * y2) / ((x1 - x2) * (x1 - x3) * (x2 - x3))
        
        for i in 0 ..< 10 {
            let k = CGFloat(i) / CGFloat(10 - 1)
            let x = sourcePoint.x * (1.0 - k) + targetPosition.x * k
            let y = a * x * x + b * x + c
            keyframes.append(CGPoint(x: x, y: y))
        }
    }
    
    return keyframes
}
