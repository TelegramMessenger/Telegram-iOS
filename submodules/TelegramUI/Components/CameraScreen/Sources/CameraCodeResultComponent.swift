import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import MultilineTextComponent
import LottieAnimationComponent
import AvatarNode
import AccountContext

final class CameraCodeResultComponent: Component {
    let context: AccountContext
    let peer: EnginePeer
    let pressed: (EnginePeer) -> Void
    
    init(
        context: AccountContext,
        peer: EnginePeer,
        pressed: @escaping (EnginePeer) -> Void
    ) {
        self.context = context
        self.peer = peer
        self.pressed = pressed
    }
    
    static func ==(lhs: CameraCodeResultComponent, rhs: CameraCodeResultComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private var component: CameraCodeResultComponent?
        
        private let wrapperView = UIView()
        private let backgroundView = BlurredBackgroundView(color: UIColor(rgb: 0x2a2a2a, alpha: 0.65))
        private let highlightedBackgroundView = UIView()
        private let contentView = UIView()
        private let contentWrapperView = UIView()
        private let avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 14.0))
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        private let button = HighlightTrackingButton()
        
        private let contentMaskView = UIView()
        private let animationClippingView = UIView()
        private let maskAnimation = ComponentView<Empty>()
        private let maskBackgroundView = UIView()
                
        init() {
            self.animationClippingView.clipsToBounds = true
            self.maskBackgroundView.backgroundColor = .white
            self.maskBackgroundView.layer.cornerRadius = 12.0
            
            self.highlightedBackgroundView.alpha = 0.0
            self.highlightedBackgroundView.backgroundColor = UIColor(rgb: 0xffffff, alpha: 0.5)
            self.highlightedBackgroundView.isUserInteractionEnabled = false
            
            super.init(frame: CGRect())
            
            self.addSubview(self.wrapperView)
            
            self.wrapperView.mask = self.contentMaskView
            self.wrapperView.addSubview(self.backgroundView)
            self.wrapperView.addSubview(self.highlightedBackgroundView)
            self.wrapperView.addSubview(self.contentView)
            self.wrapperView.addSubview(self.button)
            
            self.contentMaskView.addSubview(self.animationClippingView)
            self.contentMaskView.addSubview(self.maskBackgroundView)
            
            self.contentView.addSubview(self.contentWrapperView)
            self.contentWrapperView.addSubview(self.avatarNode.view)
            
            self.button.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                if highlighted {
                    self.highlightedBackgroundView.layer.removeAnimation(forKey: "opacity")
                    self.highlightedBackgroundView.layer.opacity = 1.0
                } else {
                    self.highlightedBackgroundView.layer.opacity = 0.0
                    self.highlightedBackgroundView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                }
            }
            self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
        }
        
        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }
        
        @objc private func buttonPressed() {
            if let component = self.component {
                component.pressed(component.peer)
            }
        }
        
        func animateIn() {
            if let view = self.maskAnimation.view as? LottieAnimationComponent.View {
                view.playOnce()
                Queue.mainQueue().after(0.016) {
                    view.alpha = 1.0
                }
                view.layer.animatePosition(from: CGPoint(x: 0.0, y: 20.0), to: .zero, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                
                self.maskBackgroundView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.001, delay: 0.29, completion: { _ in
                    view.alpha = 0.0
                })
            }
            
            let overlayLayer = SimpleLayer()
            overlayLayer.frame = CGRect(origin: .zero, size: self.wrapperView.bounds.size)
            overlayLayer.backgroundColor = UIColor.white.cgColor
            overlayLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, delay: 0.15, removeOnCompletion: false, completion: { _ in
                overlayLayer.removeFromSuperlayer()
            })
            self.wrapperView.layer.insertSublayer(overlayLayer, at: 2)
            
            self.maskBackgroundView.layer.animate(from: 27.5, to: 12.0, keyPath: "cornerRadius", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.4, delay: 0.35)
            
            self.maskBackgroundView.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: 0.0, y: 66.0)), to: NSValue(cgPoint: .zero), keyPath: "position", duration: 0.8, delay: 0.2, initialVelocity: 0.0, damping: 64.0, removeOnCompletion: true, additive: true, completion: nil)
            self.maskBackgroundView.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 1.0, delay: 0.0, initialVelocity: 0.0, damping: 64.0, removeOnCompletion: true, completion: nil)
            self.maskBackgroundView.layer.animateSpring(from: NSValue(cgRect: CGRect(origin: .zero, size: CGSize(width: 30.0, height: 55.0))), to: NSValue(cgRect: self.maskBackgroundView.bounds), keyPath: "bounds", duration: 0.85, delay: 0.26, initialVelocity: 0.0, damping: 90.0, removeOnCompletion: true, completion: nil)
            
            self.contentView.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: 0.0, y: 66.0)), to: NSValue(cgPoint: .zero), keyPath: "position", duration: 0.8, delay: 0.2, initialVelocity: 0.0, damping: 64.0, removeOnCompletion: true, additive: true, completion: nil)
            self.contentView.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 1.0, delay: 0.0, initialVelocity: 0.0, damping: 64.0, removeOnCompletion: true, completion: nil)
            
            self.contentWrapperView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, delay: 0.4)
            self.contentWrapperView.layer.animateScale(from: 0.2, to: 1.0, duration: 0.25, delay: 0.35)
        }
            
        func update(component: CameraCodeResultComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let backgroundSize = CGSize(width: 220.0, height: 55.0)
            
            let animationSize = self.maskAnimation.update(
                transition: .immediate,
                component: AnyComponent(
                    LottieAnimationComponent(
                        animation: LottieAnimationComponent.AnimationItem(
                            name: "UserAvatarMask",
                            mode: .still(position: .end),
                            range: (1.0, 0.0),
                            speed: 30.0
                        ),
                        colors: ["__allcolors__": .white],
                        size: CGSize(width: 94.0, height: 120.0)
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            if let view = self.maskAnimation.view {
                if view.superview == nil {
                    view.alpha = 0.0
                    view.transform = CGAffineTransformMakeScale(1.0, -1.0)
                    self.animationClippingView.addSubview(view)
                }
                self.animationClippingView.frame = CGRect(origin: CGPoint(x: floor((availableSize.width - animationSize.width) / 2.0), y: 29.0), size: CGSize(width: animationSize.width, height: animationSize.height - 13.0))
                view.frame = CGRect(origin: .zero, size: animationSize)
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            let avatarSize = CGSize(width: 30.0, height: 30.0)
            self.avatarNode.setPeer(context: component.context, theme: presentationData.theme, peer: component.peer)
            self.avatarNode.frame = CGRect(origin: CGPoint(x: 12.0, y: floorToScreenPixels((backgroundSize.height - avatarSize.height) / 2.0)), size: avatarSize)
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(text: .plain(NSAttributedString(string: component.peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), font: Font.regular(17.0), textColor: .white)))
                ),
                environment: {},
                containerSize: CGSize(width: 140.0, height: availableSize.height)
            )
            if let view = self.title.view {
                if view.superview == nil {
                    self.contentWrapperView.addSubview(view)
                }
                view.frame = CGRect(origin: CGPoint(x: 54.0, y: 9.0), size: titleSize)
            }
            
            let subtitleString = NSMutableAttributedString(string: "\(presentationData.strings.Camera_OpenChat) >", font: Font.regular(15.0), textColor: UIColor(rgb: 0xffffff, alpha: 0.7))
            if let range = subtitleString.string.range(of: ">"), let arrowImage = UIImage(bundleImageName: "Item List/InlineTextRightArrow") {
                subtitleString.addAttribute(.attachment, value: arrowImage, range: NSRange(range, in: subtitleString.string))
                subtitleString.addAttribute(.baselineOffset, value: 1.0, range: NSRange(range, in: subtitleString.string))
            }
            let subtitleSize = self.subtitle.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(text: .plain(subtitleString))
                ),
                environment: {},
                containerSize: CGSize(width: 140.0, height: availableSize.height)
            )
            if let view = self.subtitle.view {
                if view.superview == nil {
                    self.contentWrapperView.addSubview(view)
                }
                view.frame = CGRect(origin: CGPoint(x: 54.0, y: 29.0), size: subtitleSize)
            }
            
            self.contentView.frame = CGRect(origin: CGPoint(x: floor((availableSize.width - backgroundSize.width) / 2.0), y: 54.0 + UIScreenPixel), size: backgroundSize)
            self.contentWrapperView.frame = self.contentView.bounds
            self.maskBackgroundView.frame = self.contentView.frame
            self.button.frame = self.contentView.frame
            self.highlightedBackgroundView.frame = self.contentView.frame
            
            self.wrapperView.frame = CGRect(origin: .zero, size: CGSize(width: availableSize.width, height: animationSize.height + 17.0))
            self.backgroundView.frame = self.wrapperView.bounds
            self.backgroundView.update(size: self.wrapperView.bounds.size, transition: .immediate)
            self.contentMaskView.frame = self.wrapperView.bounds
            
            return CGSize(width: availableSize.width, height: 120.0)
        }
    }
    
    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
