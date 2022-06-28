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
        private let animationView: ComponentHostView<Empty>
        
        private var progressAnimationView: ComponentHostView<Empty>?
        
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
            
            self.component = component
            
            self.backgroundLayer.frame = CGRect(origin: CGPoint(), size: size)
            if let progressAnimationView = self.progressAnimationView {
                let progressFrame = CGRect(origin: CGPoint(), size: size).insetBy(dx: -1.0, dy: -1.0)
                let _ = progressAnimationView.update(
                    transition: transition,
                    component: AnyComponent(LottieAnimationComponent(
                        animation: LottieAnimationComponent.AnimationItem(
                            name: "voicets_progress",
                            colors: [
                                "Rectangle 60.Rectangle 60.Stroke 1": foregroundColor
                            ],
                            mode: .animating(loop: true)
                        ),
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
