import Foundation
import UIKit
import ComponentFlow
import AppBundle
import Display
import TelegramPresentationData
import LottieAnimationComponent
import BundleIconComponent

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
            case let .custom(lhsBackgroundColor, lhsForegroundColor):
                if case let .custom(rhsBackgroundColor, rhsForegroundColor) = rhs {
                    return lhsBackgroundColor == rhsBackgroundColor && lhsForegroundColor == rhsForegroundColor
                } else {
                    return false
                }
            case let .freeform(lhsFreeform, lhsForeground):
                if case let .freeform(rhsFreeform, rhsForeground) = rhs, lhsFreeform == rhsFreeform, lhsForeground == rhsForeground {
                    return true
                } else {
                    return false
                }
            }
        }
        
        case bubble(PresentationThemePartedColors)
        case custom(UIColor, UIColor)
        case freeform((UIColor, Bool), UIColor)
    }
    
    public enum TranscriptionState {
        case inProgress
        case expanded
        case collapsed
        case locked
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
        private var iconView: ComponentView<Empty>?
        private var animationView: ComponentView<Empty>?
        
        private var progressAnimationView: ComponentHostView<Empty>?
        
        override init(frame: CGRect) {
            self.blurredBackgroundNode = NavigationBackgroundNode(color: .clear)
            self.backgroundLayer = SimpleLayer()
            
            super.init(frame: frame)
            
            self.backgroundLayer.masksToBounds = true
            self.backgroundLayer.cornerRadius = 10.0
            self.layer.addSublayer(self.backgroundLayer)
                        
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func pressed() {
            self.component?.pressed()
        }
        
        func update(component: AudioTranscriptionButtonComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            let size = CGSize(width: 30.0, height: 30.0)
            
            let foregroundColor: UIColor
            let backgroundColor: UIColor
            switch component.theme {
            case let .bubble(theme):
                foregroundColor = theme.bubble.withWallpaper.reactionActiveBackground
                backgroundColor = theme.bubble.withWallpaper.reactionInactiveBackground
            case let .custom(backgroundColorValue, foregroundColorValue):
                foregroundColor = foregroundColorValue
                backgroundColor = backgroundColorValue
            case let .freeform(colorAndBlur, color):
                foregroundColor = color
                backgroundColor = .clear
                if self.blurredBackgroundNode.view.superview == nil {
                    self.insertSubview(self.blurredBackgroundNode.view, at: 0)
                }
                self.blurredBackgroundNode.updateColor(color: colorAndBlur.0, enableBlur: colorAndBlur.1, transition: .immediate)
                self.blurredBackgroundNode.update(size: size, cornerRadius: 10.0, transition: .immediate)
                self.blurredBackgroundNode.frame = CGRect(origin: .zero, size: size)
            }
            
            if self.component?.transcriptionState != component.transcriptionState {
                if case .locked = component.transcriptionState {
                    if let animationView = self.animationView {
                        self.animationView = nil
                        if let view = animationView.view {
                            view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                                view.removeFromSuperview()
                            })
                        }
                    }
                    
                    let iconView: ComponentView<Empty>
                    if let current = self.iconView {
                        iconView = current
                    } else {
                        iconView = ComponentView<Empty>()
                        self.iconView = iconView
                    }
                    
                    let iconSize = iconView.update(
                        transition: transition,
                        component: AnyComponent(BundleIconComponent(
                            name: "Chat/Message/TranscriptionLocked",
                            tintColor: foregroundColor
                        )),
                        environment: {},
                        containerSize: CGSize(width: 30.0, height: 30.0)
                    )
                    
                    if let view = iconView.view {
                        if view.superview == nil {
                            view.isUserInteractionEnabled = false
                            self.addSubview(view)
                        }
                        view.frame = CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) / 2.0), y: floor((size.width - iconSize.height) / 2.0)), size: iconSize)
                    }
                } else {
                    if let iconView = self.iconView {
                        self.iconView = nil
                        if let view = iconView.view {
                            view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                                view.removeFromSuperview()
                            })
                        }
                    }
                    
                    let animationView: ComponentView<Empty>
                    if let current = self.animationView {
                        animationView = current
                    } else {
                        animationView = ComponentView<Empty>()
                        self.animationView = animationView
                    }
                    
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
                    case .locked:
                        animationName = "voiceToText"
                    }
                    let animationSize = animationView.update(
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
                    if let view = animationView.view {
                        if view.superview == nil {
                            view.isUserInteractionEnabled = false
                            self.addSubview(view)
                        }
                        view.frame = CGRect(origin: CGPoint(x: floor((size.width - animationSize.width) / 2.0), y: floor((size.width - animationSize.height) / 2.0)), size: animationSize)
                    }
                }
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
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
