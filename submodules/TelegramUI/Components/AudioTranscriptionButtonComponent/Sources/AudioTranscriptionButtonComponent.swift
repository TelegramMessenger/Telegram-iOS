import Foundation
import UIKit
import ComponentFlow
import AppBundle
import Display
import TelegramPresentationData
import LottieAnimationComponent

public final class AudioTranscriptionButtonComponent: Component {
    public enum TranscriptionState {
        case inProgress
        case expanded
        case collapsed
    }
    
    public let theme: PresentationThemePartedColors
    public let transcriptionState: TranscriptionState
    public let pressed: () -> Void
    
    public init(
        theme: PresentationThemePartedColors,
        transcriptionState: TranscriptionState,
        pressed: @escaping () -> Void
    ) {
        self.theme = theme
        self.transcriptionState = transcriptionState
        self.pressed = pressed
    }
    
    public static func ==(lhs: AudioTranscriptionButtonComponent, rhs: AudioTranscriptionButtonComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.transcriptionState != rhs.transcriptionState {
            return false
        }
        return true
    }
    
    public final class View: UIButton {
        private var component: AudioTranscriptionButtonComponent?
        
        private let backgroundLayer: SimpleLayer
        private var inProgressLayer: SimpleShapeLayer?
        private let animationView: ComponentHostView<Empty>
        
        override init(frame: CGRect) {
            self.backgroundLayer = SimpleLayer()
            self.animationView = ComponentHostView<Empty>()
            self.animationView.isUserInteractionEnabled = false
            
            super.init(frame: frame)
            
            self.backgroundLayer.masksToBounds = true
            self.backgroundLayer.cornerRadius = 10.0
            self.layer.addSublayer(self.backgroundLayer)
            
            self.addSubview(self.animationView)
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            self.component?.pressed()
        }
        
        func update(component: AudioTranscriptionButtonComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            let size = CGSize(width: 30.0, height: 30.0)
            
            let foregroundColor = component.theme.bubble.withWallpaper.reactionActiveBackground
            
            if self.component?.transcriptionState != component.transcriptionState {
                switch component.transcriptionState {
                case .inProgress:
                    if self.inProgressLayer == nil {
                        let inProgressLayer = SimpleShapeLayer()
                        inProgressLayer.isOpaque = false
                        inProgressLayer.backgroundColor = nil
                        inProgressLayer.fillColor = nil
                        inProgressLayer.lineCap = .round
                        inProgressLayer.lineWidth = 1.0
                        
                        let path = UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: CGSize(width: 30.0, height: 30.0)), cornerRadius: 9.0).cgPath
                        inProgressLayer.path = path
                        
                        self.inProgressLayer = inProgressLayer
                        
                        inProgressLayer.didEnterHierarchy = { [weak inProgressLayer] in
                            guard let inProgressLayer = inProgressLayer else {
                                return
                            }
                            let endAnimation = CABasicAnimation(keyPath: "strokeEnd")
                            endAnimation.fromValue = CGFloat(0.0) as NSNumber
                            endAnimation.toValue = CGFloat(1.0) as NSNumber
                            endAnimation.duration = 1.25
                            endAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
                            endAnimation.fillMode = .forwards
                            endAnimation.repeatCount = .infinity
                            inProgressLayer.add(endAnimation, forKey: "strokeEnd")
                            
                            let startAnimation = CABasicAnimation(keyPath: "strokeStart")
                            startAnimation.fromValue = CGFloat(0.0) as NSNumber
                            startAnimation.toValue = CGFloat(1.0) as NSNumber
                            startAnimation.duration = 1.25
                            startAnimation.timingFunction = CAMediaTimingFunction(name: .easeIn)
                            startAnimation.fillMode = .forwards
                            startAnimation.repeatCount = .infinity
                            inProgressLayer.add(startAnimation, forKey: "strokeStart")
                        }
                        
                        self.layer.addSublayer(inProgressLayer)
                    }
                default:
                    if let inProgressLayer = self.inProgressLayer {
                        self.inProgressLayer = nil
                        if case .none = transition.animation {
                            inProgressLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak inProgressLayer] _ in
                                inProgressLayer?.removeFromSuperlayer()
                            })
                        } else {
                            inProgressLayer.removeFromSuperlayer()
                        }
                    }
                }
                
                let animationName: String
                switch component.transcriptionState {
                case .inProgress:
                    animationName = "voiceToText"
                case .collapsed:
                    animationName = "voiceToText"
                case .expanded:
                    animationName = "textToVoice"
                }
                let animationSize = self.animationView.update(
                    transition: transition,
                    component: AnyComponent(LottieAnimationComponent(
                        animation: LottieAnimationComponent.Animation(
                            name: animationName,
                            colors: [
                                "icon.Group 3.Stroke 1": foregroundColor,
                                "icon.Group 1.Stroke 1": foregroundColor,
                                "icon.Group 4.Stroke 1": foregroundColor,
                                "icon.Group 2.Stroke 1": foregroundColor,
                                "Artboard Copy 2 Outlines.Group 5.Stroke 1": foregroundColor,
                                "Artboard Copy 2 Outlines.Group 1.Stroke 1": foregroundColor,
                                "Artboard Copy 2 Outlines.Group 4.Stroke 1": foregroundColor,
                                "Artboard Copy Outlines.Group 1.Stroke 1": foregroundColor,
                            ],
                            mode: .animateTransitionFromPrevious
                        ),
                        size: CGSize(width: 30.0, height: 30.0)
                    )),
                    environment: {},
                    containerSize: CGSize(width: 30.0, height: 30.0)
                )
                self.animationView.frame = CGRect(origin: CGPoint(x: floor((size.width - animationSize.width) / 2.0), y: floor((size.width - animationSize.height) / 2.0)), size: animationSize)
            }
            
            self.backgroundLayer.backgroundColor = component.theme.bubble.withWallpaper.reactionInactiveBackground.cgColor
            self.inProgressLayer?.strokeColor = foregroundColor.cgColor
            
            self.component = component
            
            self.backgroundLayer.frame = CGRect(origin: CGPoint(), size: size)
            if let inProgressLayer = self.inProgressLayer {
                inProgressLayer.frame = CGRect(origin: CGPoint(), size: size)
            }
            
            return CGSize(width: min(availableSize.width, size.width), height: min(availableSize.height, size.height))
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
