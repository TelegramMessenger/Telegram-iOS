import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import GlassBackgroundComponent
import ManagedAnimationNode
import MultilineTextComponent
import AppBundle

public final class VideoPlaybackControlsComponent: Component {
    public struct LayoutParams: Equatable {
        public var sideButtonSize: CGFloat
        public var centerButtonSize: CGFloat
        public var spacing: CGFloat

        public init(sideButtonSize: CGFloat, centerButtonSize: CGFloat, spacing: CGFloat) {
            self.sideButtonSize = sideButtonSize
            self.centerButtonSize = centerButtonSize
            self.spacing = spacing
        }
    }
    
    let layoutParams: LayoutParams
    let isVisible: Bool
    let isPlaying: Bool
    let displaySeekControls: Bool
    let togglePlayback: () -> Void
    let seek: (Bool) -> Void
    
    public init(
        layoutParams: LayoutParams,
        isVisible: Bool,
        isPlaying: Bool,
        displaySeekControls: Bool,
        togglePlayback: @escaping () -> Void,
        seek: @escaping (Bool) -> Void
    ) {
        self.layoutParams = layoutParams
        self.isVisible = isVisible
        self.isPlaying = isPlaying
        self.displaySeekControls = displaySeekControls
        self.togglePlayback = togglePlayback
        self.seek = seek
    }
    
    public static func ==(lhs: VideoPlaybackControlsComponent, rhs: VideoPlaybackControlsComponent) -> Bool {
        if lhs.layoutParams != rhs.layoutParams {
            return false
        }
        if lhs.isVisible != rhs.isVisible {
            return false
        }
        if lhs.isPlaying != rhs.isPlaying {
            return false
        }
        if lhs.displaySeekControls != rhs.displaySeekControls {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let backgroundContainer: GlassBackgroundContainerView
        private let leftButtonBackgroundView: GlassBackgroundView
        private let leftIconView: PlaybackIconView
        private let rightButtonBackgroundView: GlassBackgroundView
        private let rightIconView: PlaybackIconView
        private let centerButtonBackgroundView: GlassBackgroundView
        private var centerButtonIconNode: PlayPauseIconNode?
        
        private var component: VideoPlaybackControlsComponent?
        private weak var state: EmptyComponentState?
        
        public override init(frame: CGRect) {
            self.backgroundContainer = GlassBackgroundContainerView()
            
            self.leftButtonBackgroundView = GlassBackgroundView()
            self.leftIconView = PlaybackIconView(isForward: false)
            self.leftIconView.isUserInteractionEnabled = false
            self.leftButtonBackgroundView.contentView.addSubview(self.leftIconView)
            
            self.rightButtonBackgroundView = GlassBackgroundView()
            self.rightIconView = PlaybackIconView(isForward: true)
            self.rightIconView.isUserInteractionEnabled = false
            self.rightButtonBackgroundView.contentView.addSubview(self.rightIconView)
            
            self.centerButtonBackgroundView = GlassBackgroundView()
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundContainer)
            
            self.backgroundContainer.contentView.addSubview(self.leftButtonBackgroundView)
            self.backgroundContainer.contentView.addSubview(self.rightButtonBackgroundView)
            self.backgroundContainer.contentView.addSubview(self.centerButtonBackgroundView)
            
            self.leftButtonBackgroundView.contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.onLeftTapGesture(_:))))
            self.rightButtonBackgroundView.contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.onRightTapGesture(_:))))
            self.centerButtonBackgroundView.contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.onTapGesture(_:))))
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        @objc private func onLeftTapGesture(_ gesture: UITapGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            if case .ended = gesture.state {
                component.seek(false)
            }
        }
        
        @objc private func onRightTapGesture(_ gesture: UITapGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            if case .ended = gesture.state {
                component.seek(true)
            }
        }
        
        @objc private func onTapGesture(_ gesture: UITapGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            if case .ended = gesture.state {
                component.togglePlayback()
            }
        }
        
        func update(component: VideoPlaybackControlsComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let isVisibleChanged = self.component?.isVisible != component.isVisible
            
            self.component = component
            self.state = state
            
            self.isUserInteractionEnabled = component.isVisible
            
            let containerInset: CGFloat = 32.0
            
            let size = CGSize(width: component.layoutParams.sideButtonSize * 2.0 + component.layoutParams.centerButtonSize + component.layoutParams.spacing * 2.0, height: component.layoutParams.centerButtonSize)
            
            let leftButtonFrame = CGRect(origin: CGPoint(x: 0.0, y: floorToScreenPixels((size.height - component.layoutParams.sideButtonSize) * 0.5)), size: CGSize(width: component.layoutParams.sideButtonSize, height: component.layoutParams.sideButtonSize)).offsetBy(dx: containerInset, dy: containerInset)
            let centerButtonFrame = CGRect(origin: CGPoint(x: component.layoutParams.sideButtonSize + component.layoutParams.spacing, y: floorToScreenPixels((size.height - component.layoutParams.centerButtonSize) * 0.5)), size: CGSize(width: component.layoutParams.centerButtonSize, height: component.layoutParams.centerButtonSize)).offsetBy(dx: containerInset, dy: containerInset)
            let rightButtonFrame = CGRect(origin: CGPoint(x: size.width - component.layoutParams.sideButtonSize, y: floorToScreenPixels((size.height - component.layoutParams.sideButtonSize) * 0.5)), size: CGSize(width: component.layoutParams.sideButtonSize, height: component.layoutParams.sideButtonSize)).offsetBy(dx: containerInset, dy: containerInset)
            
            if isVisibleChanged && !transition.animation.isImmediate {
                self.backgroundContainer.isHidden = true
                self.backgroundContainer.isHidden = false
            }
            
            transition.setFrame(view: self.backgroundContainer, frame: CGRect(origin: CGPoint(), size: size).insetBy(dx: -containerInset, dy: -containerInset))
            self.backgroundContainer.update(size: CGSize(width: size.width + containerInset * 2.0, height: size.height + containerInset * 2.0), isDark: true, transition: transition)
            
            let areSideButtonsVisible = component.isVisible && component.displaySeekControls
            let buttonsTintColor: GlassBackgroundView.TintColor = .init(kind: .custom(style: .clear, color: UIColor(white: 0.0, alpha: 0.2)))
            
            transition.setFrame(view: self.leftButtonBackgroundView, frame: leftButtonFrame)
            self.leftButtonBackgroundView.update(size: leftButtonFrame.size, cornerRadius: leftButtonFrame.height * 0.5, isDark: true, tintColor: buttonsTintColor, isInteractive: true, isVisible: areSideButtonsVisible, transition: transition)
            transition.setFrame(view: self.leftIconView, frame: CGRect(origin: CGPoint(), size: leftButtonFrame.size))
            self.leftIconView.update(size: leftButtonFrame.size)
            transition.setAlpha(view: self.leftIconView, alpha: areSideButtonsVisible ? 1.0 : 0.0)
            transition.setBlur(layer: self.leftIconView.layer, radius: areSideButtonsVisible ? 0.0 : 10.0)
            
            transition.setFrame(view: self.rightButtonBackgroundView, frame: rightButtonFrame)
            self.rightButtonBackgroundView.update(size: rightButtonFrame.size, cornerRadius: rightButtonFrame.height * 0.5, isDark: true, tintColor: buttonsTintColor, isInteractive: true, isVisible: areSideButtonsVisible, transition: transition)
            transition.setFrame(view: self.rightIconView, frame: CGRect(origin: CGPoint(), size: rightButtonFrame.size))
            self.rightIconView.update(size: rightButtonFrame.size)
            transition.setAlpha(view: self.rightIconView, alpha: areSideButtonsVisible ? 1.0 : 0.0)
            transition.setBlur(layer: self.rightIconView.layer, radius: areSideButtonsVisible ? 0.0 : 10.0)
            
            transition.setFrame(view: self.centerButtonBackgroundView, frame: centerButtonFrame)
            self.centerButtonBackgroundView.update(size: centerButtonFrame.size, cornerRadius: centerButtonFrame.height * 0.5, isDark: true, tintColor: buttonsTintColor, isInteractive: true, isVisible: component.isVisible, transition: transition)
            
            let centerButtonIconNode: PlayPauseIconNode
            let centerIconFactor: CGFloat = 0.9
            let centerButtonIconSize = CGSize(width: centerButtonFrame.width * centerIconFactor, height: centerButtonFrame.height * centerIconFactor)
            if let current = self.centerButtonIconNode, current.size == centerButtonIconSize {
                centerButtonIconNode = current
            } else {
                centerButtonIconNode = PlayPauseIconNode(size: centerButtonIconSize)
                if let current = self.centerButtonIconNode {
                    centerButtonIconNode.frame = current.frame
                    current.view.removeFromSuperview()
                }
                self.centerButtonIconNode = centerButtonIconNode
                centerButtonIconNode.isUserInteractionEnabled = false
                self.centerButtonBackgroundView.contentView.addSubview(centerButtonIconNode.view)
                centerButtonIconNode.enqueueState(component.isPlaying ? .pause : .play, animated: false)
            }
            transition.setFrame(view: centerButtonIconNode.view, frame: centerButtonIconSize.centered(in: CGRect(origin: CGPoint(), size: centerButtonFrame.size)).offsetBy(dx: component.isPlaying ? 0.0 : 5.0, dy: 0.0))
            centerButtonIconNode.enqueueState(component.isPlaying ? .pause : .play, animated: !transition.animation.isImmediate && component.isVisible && !isVisibleChanged)
            transition.setAlpha(view: centerButtonIconNode.view, alpha: component.isVisible ? 1.0 : 0.0)
            transition.setBlur(layer: centerButtonIconNode.layer, radius: component.isVisible ? 0.0 : 10.0)
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private enum PlayPauseIconNodeState: Equatable {
    case play
    case pause
}

private final class PlayPauseIconNode: ManagedAnimationNode {
    let size: CGSize
    
    private let duration: Double = 0.35
    private var iconState: PlayPauseIconNodeState = .pause
    
    override init(size: CGSize) {
        self.size = size
        
        super.init(size: size)
        
        self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 41, endFrame: 41), duration: 0.01))
    }
    
    func enqueueState(_ state: PlayPauseIconNodeState, animated: Bool) {
        guard self.iconState != state else {
            return
        }
        
        let previousState = self.iconState
        self.iconState = state
        
        switch previousState {
            case .pause:
                switch state {
                    case .play:
                        if animated {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 41, endFrame: 83), duration: self.duration))
                        } else {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.01))
                        }
                    case .pause:
                        break
                }
            case .play:
                switch state {
                    case .pause:
                        if animated {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 0, endFrame: 41), duration: self.duration))
                        } else {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 41, endFrame: 41), duration: 0.01))
                        }
                    case .play:
                        break
                }
        }
    }
}

private let circleDiameter: CGFloat = 80.0

private final class PlaybackIconView: HighlightTrackingButton {
    let backgroundIconView: UIImageView
    let text = ComponentView<Empty>()
    
    let isForward: Bool

    var isPressing = false {
        didSet {
            if self.isPressing != oldValue && !self.isPressing {
                self.highligthedChanged(false)
            }
        }
    }
    
    init(isForward: Bool) {
        self.isForward = isForward
        
        self.backgroundIconView = UIImageView(image: UIImage(bundleImageName: isForward ? "Media Gallery/ForwardButton" : "Media Gallery/BackwardButton"))
        
        super.init(frame: CGRect())
        
        self.addSubview(self.backgroundIconView)
        
        self.highligthedChanged = { [weak self] highlighted in
            guard let self else {
                return
            }
            if highlighted {
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.18, curve: .linear)
                let angle = CGFloat.pi / 4.0 + 0.226
                transition.updateTransformRotation(view: self.backgroundIconView, angle: self.isForward ? angle : -angle)
            } else if !self.isPressing {
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .linear)
                transition.updateTransformRotation(view: self.backgroundIconView, angle: 0.0)
            }
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(size: CGSize) {
        if let image = self.backgroundIconView.image {
            let factor: CGFloat = 1.4
            self.backgroundIconView.frame = CGSize(width: floor(image.size.width * factor), height: floor(image.size.height * factor)).centered(in: CGRect(origin: CGPoint(), size: size))
        }
        
        let textSize = self.text.update(
            transition: .immediate,
            component: AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(string: "15", font: Font.with(size: 16.0, design: .round, weight: .semibold, traits: []), textColor: .white))
            )),
            environment: {},
            containerSize: size
        )
        if let textView = self.text.view {
            if textView.superview == nil {
                self.addSubview(textView)
            }
            textView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: floorToScreenPixels((size.height - textSize.height) / 2.0) + UIScreenPixel), size: textSize)
        }
    }
}
