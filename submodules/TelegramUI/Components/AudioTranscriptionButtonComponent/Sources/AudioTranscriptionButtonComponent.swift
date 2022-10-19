import Foundation
import UIKit
import ComponentFlow
import AppBundle
import Display
import TelegramPresentationData
import LottieAnimationComponent

public final class AudioTranscriptionButtonComponent: Component {
    public enum Theme: Equatable {
        public static func == (lhs: AudioTranscriptionButtonComponent.Theme, rhs: AudioTranscriptionButtonComponent.Theme) -> Bool {
            switch lhs {
            case let .bubble(lhsTheme):
                if case let .bubble(rhsTheme) = rhs {
                    return lhsTheme === rhsTheme
                } else {
                    return false
                }
            case let .freeform(lhsFreeform):
                if case let .freeform(rhsFreeform) = rhs, lhsFreeform == rhsFreeform {
                    return true
                } else {
                    return false
                }
            }
        }
        
        case bubble(PresentationThemePartedColors)
        case freeform((UIColor, Bool))
    }
    
    public enum TranscriptionState {
        case inProgress
        case expanded
        case collapsed
    }
    
    public let theme: AudioTranscriptionButtonComponent.Theme
    public let transcriptionState: TranscriptionState
    public let pressed: () -> Void
    
    public init(
        theme: AudioTranscriptionButtonComponent.Theme,
        transcriptionState: TranscriptionState,
        pressed: @escaping () -> Void
    ) {
        self.theme = theme
        self.transcriptionState = transcriptionState
        self.pressed = pressed
    }
    
    public static func ==(lhs: AudioTranscriptionButtonComponent, rhs: AudioTranscriptionButtonComponent) -> Bool {
        if lhs.theme != rhs.theme {
            return false
        }
        if lhs.transcriptionState != rhs.transcriptionState {
            return false
        }
        return true
    }
    
    public final class View: UIButton {
        private var component: AudioTranscriptionButtonComponent?
        
        private let blurredBackgroundNode: NavigationBackgroundNode
        private let backgroundLayer: SimpleLayer
        private let animationView: ComponentHostView<Empty>
        
        private var progressAnimationView: ComponentHostView<Empty>?
        
        override init(frame: CGRect) {
            self.blurredBackgroundNode = NavigationBackgroundNode(color: .clear)
            self.backgroundLayer = SimpleLayer()
            self.animationView = ComponentHostView<Empty>()
            
            super.init(frame: frame)
            
            self.backgroundLayer.masksToBounds = true
            self.backgroundLayer.cornerRadius = 10.0
            self.layer.addSublayer(self.backgroundLayer)
            
            self.animationView.isUserInteractionEnabled = false
            
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
            
            let foregroundColor: UIColor
            let backgroundColor: UIColor
            switch component.theme {
            case let .bubble(theme):
                foregroundColor = theme.bubble.withWallpaper.reactionActiveBackground
                backgroundColor = theme.bubble.withWallpaper.reactionInactiveBackground
            case let .freeform(colorAndBlur):
                foregroundColor = UIColor.white
                backgroundColor = .clear
                if self.blurredBackgroundNode.view.superview == nil {
                    self.insertSubview(self.blurredBackgroundNode.view, at: 0)
                }
                self.blurredBackgroundNode.updateColor(color: colorAndBlur.0, enableBlur: colorAndBlur.1, transition: .immediate)
                self.blurredBackgroundNode.update(size: size, cornerRadius: 10.0, transition: .immediate)
                self.blurredBackgroundNode.frame = CGRect(origin: .zero, size: size)
            }
            
            if self.component?.transcriptionState != component.transcriptionState {
                switch component.transcriptionState {
                case .inProgress:
                    if self.progressAnimationView == nil {
                        let progressAnimationView = ComponentHostView<Empty>()
                        self.progressAnimationView = progressAnimationView
                        self.addSubview(progressAnimationView)
                    }
                default:
                    if let progressAnimationView = self.progressAnimationView {
                        self.progressAnimationView = nil
                        if case .none = transition.animation {
                            progressAnimationView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak progressAnimationView] _ in
                                progressAnimationView?.removeFromSuperview()
                            })
                        } else {
                            progressAnimationView.removeFromSuperview()
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
                        animation: LottieAnimationComponent.AnimationItem(
                            name: animationName,
                            mode: .animateTransitionFromPrevious
                        ),
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
                        size: CGSize(width: 30.0, height: 30.0)
                    )),
                    environment: {},
                    containerSize: CGSize(width: 30.0, height: 30.0)
                )
                self.animationView.frame = CGRect(origin: CGPoint(x: floor((size.width - animationSize.width) / 2.0), y: floor((size.width - animationSize.height) / 2.0)), size: animationSize)
            }
            
            self.backgroundLayer.backgroundColor = backgroundColor.cgColor
            
            self.component = component
            
            self.backgroundLayer.frame = CGRect(origin: CGPoint(), size: size)
            if let progressAnimationView = self.progressAnimationView {
                let progressFrame = CGRect(origin: CGPoint(), size: size).insetBy(dx: -1.0, dy: -1.0)
                let _ = progressAnimationView.update(
                    transition: transition,
                    component: AnyComponent(LottieAnimationComponent(
                        animation: LottieAnimationComponent.AnimationItem(
                            name: "voicets_progress",
                            mode: .animating(loop: true)
                        ),
                        colors: [
                            "Rectangle 60.Rectangle 60.Stroke 1": foregroundColor
                        ],
                        size: progressFrame.size
                    )),
                    environment: {},
                    containerSize: progressFrame.size
                )
                
                progressAnimationView.frame = progressFrame
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
