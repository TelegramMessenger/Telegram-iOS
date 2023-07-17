import Foundation
import UIKit
import Display
import ComponentFlow
import AppBundle
import TextFieldComponent
import BundleIconComponent
import AccountContext
import TelegramPresentationData
import ChatPresentationInterfaceState
import SwiftSignalKit
import LottieComponent
import HierarchyTrackingLayer

public final class MediaRecordingPanelComponent: Component {
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let audioRecorder: ManagedAudioRecorder?
    public let videoRecordingStatus: InstantVideoControllerRecordingStatus?
    public let isRecordingLocked: Bool
    public let cancelFraction: CGFloat
    public let inputInsets: UIEdgeInsets
    public let insets: UIEdgeInsets
    public let cancelAction: () -> Void
    
    public init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        audioRecorder: ManagedAudioRecorder?,
        videoRecordingStatus: InstantVideoControllerRecordingStatus?,
        isRecordingLocked: Bool,
        cancelFraction: CGFloat,
        inputInsets: UIEdgeInsets,
        insets: UIEdgeInsets,
        cancelAction: @escaping () -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.audioRecorder = audioRecorder
        self.videoRecordingStatus = videoRecordingStatus
        self.isRecordingLocked = isRecordingLocked
        self.cancelFraction = cancelFraction
        self.inputInsets = inputInsets
        self.insets = insets
        self.cancelAction = cancelAction
    }
    
    public static func ==(lhs: MediaRecordingPanelComponent, rhs: MediaRecordingPanelComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.audioRecorder !== rhs.audioRecorder {
            return false
        }
        if lhs.videoRecordingStatus !== rhs.videoRecordingStatus {
            return false
        }
        if lhs.isRecordingLocked != rhs.isRecordingLocked {
            return false
        }
        if lhs.cancelFraction != rhs.cancelFraction {
            return false
        }
        if lhs.inputInsets != rhs.inputInsets {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        return true
    }
    
    public final class View: UIView {        
        private var component: MediaRecordingPanelComponent?
        private weak var state: EmptyComponentState?
        
        public let vibrancyContainer: UIView
        
        private let trackingLayer: HierarchyTrackingLayer
        
        private let indicator = ComponentView<Empty>()
        
        private let cancelContainerView: UIView
        private let vibrancyCancelContainerView: UIView
        private let cancelIconView: UIImageView
        private let vibrancyCancelIconView: UIImageView
        private let vibrancyCancelText = ComponentView<Empty>()
        private let cancelText = ComponentView<Empty>()
        private let vibrancyCancelButtonText = ComponentView<Empty>()
        private let cancelButtonText = ComponentView<Empty>()
        private var cancelButton: HighlightableButton?
        
        private let timerFont: UIFont
        private let timerText = ComponentView<Empty>()
        
        private var timerTextDisposable: Disposable?
        
        private var timerTextValue: String = "0:00,00"
        
        override init(frame: CGRect) {
            self.trackingLayer = HierarchyTrackingLayer()
            self.cancelIconView = UIImageView()
            self.vibrancyCancelIconView = UIImageView()
            
            self.timerFont = Font.with(size: 15.0, design: .camera, traits: .monospacedNumbers)
            
            self.vibrancyContainer = UIView()
            
            self.cancelContainerView = UIView()
            self.vibrancyCancelContainerView = UIView()
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.trackingLayer)
            
            self.cancelContainerView.addSubview(self.cancelIconView)
            self.vibrancyCancelContainerView.addSubview(self.vibrancyCancelIconView)
            
            self.vibrancyContainer.addSubview(self.vibrancyCancelContainerView)
            self.addSubview(self.cancelContainerView)
            
            self.trackingLayer.didEnterHierarchy = { [weak self] in
                guard let self else {
                    return
                }
                self.updateAnimations()
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.timerTextDisposable?.dispose()
        }
        
        private func updateAnimations() {
            guard let component = self.component else {
                return
            }
            
            if let indicatorView = self.indicator.view {
                if indicatorView.layer.animation(forKey: "recording") == nil {
                    let animation = CAKeyframeAnimation(keyPath: "opacity")
                    animation.values = [1.0 as NSNumber, 1.0 as NSNumber, 0.0 as NSNumber]
                    animation.keyTimes = [0.0 as NSNumber, 0.4546 as NSNumber, 0.9091 as NSNumber, 1 as NSNumber]
                    animation.duration = 0.5
                    animation.autoreverses = true
                    animation.repeatCount = Float.infinity
                    
                    indicatorView.layer.add(animation, forKey: "recording")
                }
            }
            if !component.isRecordingLocked, self.cancelContainerView.layer.animation(forKey: "recording") == nil {
                let animation = CAKeyframeAnimation(keyPath: "position.x")
                animation.values = [-5.0 as NSNumber, 5.0 as NSNumber, 0.0 as NSNumber]
                animation.keyTimes = [0.0 as NSNumber, 0.4546 as NSNumber, 0.9091 as NSNumber, 1 as NSNumber]
                animation.duration = 1.5
                animation.autoreverses = true
                animation.isAdditive = true
                animation.repeatCount = Float.infinity
                
                self.cancelContainerView.layer.add(animation, forKey: "recording")
                self.vibrancyCancelContainerView.layer.add(animation, forKey: "recording")
            }
        }
        
        public func animateIn() {
            guard let component = self.component else {
                return
            }
            if let indicatorView = self.indicator.view {
                indicatorView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                indicatorView.layer.animatePosition(from: CGPoint(x: component.inputInsets.left - component.insets.left, y: 0.0), to: CGPoint(), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            }
            if let timerTextView = self.timerText.view {
                timerTextView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                timerTextView.layer.animatePosition(from: CGPoint(x: component.inputInsets.left - component.insets.left, y: 0.0), to: CGPoint(), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            }
            self.cancelContainerView.layer.animatePosition(from: CGPoint(x: self.bounds.width, y: 0.0), to: CGPoint(), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.vibrancyCancelContainerView.layer.animatePosition(from: CGPoint(x: self.bounds.width, y: 0.0), to: CGPoint(), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        }
        
        public func animateOut(transition: Transition, dismissRecording: Bool, completion: @escaping () -> Void) {
            guard let component = self.component else {
                completion()
                return
            }
            
            if let indicatorView = self.indicator.view as? LottieComponent.View, let _ = indicatorView.layer.animation(forKey: "recording") {
                let fromAlpha = indicatorView.layer.presentation()?.opacity ?? indicatorView.layer.opacity
                indicatorView.layer.removeAnimation(forKey: "recording")
                indicatorView.layer.animateAlpha(from: CGFloat(fromAlpha), to: 1.0, duration: 0.2)
            }
            
            if dismissRecording {
                if let indicatorView = self.indicator.view as? LottieComponent.View {
                    indicatorView.playOnce(completion: { [weak indicatorView] in
                        if let indicatorView {
                            let transition = Transition(animation: .curve(duration: 0.3, curve: .spring))
                            transition.setScale(view: indicatorView, scale: 0.001)
                        }
                        
                        completion()
                    })
                } else {
                    completion()
                }
            } else {
                if let indicatorView = self.indicator.view as? LottieComponent.View {
                    transition.setPosition(view: indicatorView, position: indicatorView.center.offsetBy(dx: component.inputInsets.left - component.insets.left, dy: 0.0))
                    transition.setAlpha(view: indicatorView, alpha: 0.0)
                }
            }
            
            if let timerTextView = self.timerText.view {
                transition.setAlpha(view: timerTextView, alpha: 0.0, completion: { _ in
                    if !dismissRecording {
                        completion()
                    }
                })
                transition.setScale(view: timerTextView, scale: 0.001)
                transition.setPosition(view: timerTextView, position: timerTextView.center.offsetBy(dx: component.inputInsets.left - component.insets.left, dy: 0.0))
            }
            
            transition.setAlpha(view: self.cancelContainerView, alpha: 0.0)
            transition.setAlpha(view: self.vibrancyCancelContainerView, alpha: 0.0)
        }
        
        @objc private func cancelButtonPressed() {
            guard let component = self.component else {
                return
            }
            component.cancelAction()
        }
        
        func update(component: MediaRecordingPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            self.state = state
            
            if previousComponent?.audioRecorder !== component.audioRecorder || previousComponent?.videoRecordingStatus !== component.videoRecordingStatus {
                self.timerTextDisposable?.dispose()
                
                if let audioRecorder = component.audioRecorder {
                    var updateNow = false
                    self.timerTextDisposable = audioRecorder.recordingState.start(next: { [weak self] state in
                        Queue.mainQueue().async {
                            guard let self else {
                                return
                            }
                            switch state {
                            case .paused(let duration), .recording(let duration, _):
                                let currentAudioDurationSeconds = Int(duration)
                                let currentAudioDurationMilliseconds = Int(duration * 100.0) % 100
                                let text: String
                                if currentAudioDurationSeconds >= 60 * 60 {
                                    text = String(format: "%d:%02d:%02d,%02d", currentAudioDurationSeconds / 3600, currentAudioDurationSeconds / 60 % 60, currentAudioDurationSeconds % 60, currentAudioDurationMilliseconds)
                                } else {
                                    text = String(format: "%d:%02d,%02d", currentAudioDurationSeconds / 60, currentAudioDurationSeconds % 60, currentAudioDurationMilliseconds)
                                }
                                if self.timerTextValue != text {
                                    self.timerTextValue = text
                                }
                                if updateNow {
                                    self.state?.updated(transition: .immediate)
                                }
                            case .stopped:
                                break
                            }
                        }
                    })
                    updateNow = true
                } else if let videoRecordingStatus = component.videoRecordingStatus {
                    var updateNow = false
                    self.timerTextDisposable = videoRecordingStatus.duration.start(next: { [weak self] duration in
                        Queue.mainQueue().async {
                            guard let self else {
                                return
                            }
                            let currentAudioDurationSeconds = Int(duration)
                            let currentAudioDurationMilliseconds = Int(duration * 100.0) % 100
                            let text: String
                            if currentAudioDurationSeconds >= 60 * 60 {
                                text = String(format: "%d:%02d:%02d,%02d", currentAudioDurationSeconds / 3600, currentAudioDurationSeconds / 60 % 60, currentAudioDurationSeconds % 60, currentAudioDurationMilliseconds)
                            } else {
                                text = String(format: "%d:%02d,%02d", currentAudioDurationSeconds / 60, currentAudioDurationSeconds % 60, currentAudioDurationMilliseconds)
                            }
                            if self.timerTextValue != text {
                                self.timerTextValue = text
                            }
                            if updateNow {
                                self.state?.updated(transition: .immediate)
                            }
                        }
                    })
                    updateNow = true
                }
            }
            
            let indicatorSize = self.indicator.update(
                transition: .immediate,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: "BinRed"),
                    color: UIColor(rgb: 0xFF3B30),
                    startingPosition: .begin
                )),
                environment: {},
                containerSize: CGSize(width: 40.0, height: 40.0)
            )
            if let indicatorView = self.indicator.view {
                if indicatorView.superview == nil {
                    self.addSubview(indicatorView)
                }
                transition.setFrame(view: indicatorView, frame: CGRect(origin: CGPoint(x: 5.0, y: component.insets.top + floor((availableSize.height - component.insets.top - component.insets.bottom - indicatorSize.height) * 0.5)), size: indicatorSize))
            }
            
            let timerTextSize = self.timerText.update(
                transition: .immediate,
                component: AnyComponent(Text(text: self.timerTextValue, font: self.timerFont, color: .white)),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            if let timerTextView = self.timerText.view {
                if timerTextView.superview == nil {
                    self.addSubview(timerTextView)
                    timerTextView.layer.anchorPoint = CGPoint(x: 0.0, y: 0.5)
                }
                let timerTextFrame = CGRect(origin: CGPoint(x: 40.0, y: component.insets.top + floor((availableSize.height - component.insets.top - component.insets.bottom - timerTextSize.height) * 0.5)), size: timerTextSize)
                transition.setPosition(view: timerTextView, position: CGPoint(x: timerTextFrame.minX, y: timerTextFrame.midY))
                timerTextView.bounds = CGRect(origin: CGPoint(), size: timerTextFrame.size)
            }
            
            if self.cancelIconView.image == nil {
                let image = UIImage(bundleImageName: "Chat/Input/Text/AudioRecordingCancelArrow")?.withRenderingMode(.alwaysTemplate)
                self.cancelIconView.image = image
                self.vibrancyCancelIconView.image = image
            }
            
            self.cancelIconView.tintColor = UIColor(white: 1.0, alpha: 0.3)
            self.vibrancyCancelIconView.tintColor = .white
            
            let cancelTextSize = self.cancelText.update(
                transition: .immediate,
                component: AnyComponent(Text(text: component.strings.Conversation_SlideToCancel, font: Font.regular(15.0), color: UIColor(rgb: 0xffffff, alpha: 0.3))),
                environment: {},
                containerSize: CGSize(width: max(30.0, availableSize.width - 100.0), height: 44.0)
            )
            let _ = self.vibrancyCancelText.update(
                transition: .immediate,
                component: AnyComponent(Text(text: component.strings.Conversation_SlideToCancel, font: Font.regular(15.0), color: .white)),
                environment: {},
                containerSize: CGSize(width: max(30.0, availableSize.width - 100.0), height: 44.0)
            )
            
            let cancelButtonTextSize = self.cancelButtonText.update(
                transition: .immediate,
                component: AnyComponent(Text(text: component.strings.Common_Cancel, font: Font.regular(17.0), color: .white)),
                environment: {},
                containerSize: CGSize(width: max(30.0, availableSize.width - 100.0), height: 44.0)
            )
            let _ = self.vibrancyCancelButtonText.update(
                transition: .immediate,
                component: AnyComponent(Text(text: component.strings.Common_Cancel, font: Font.regular(17.0), color: .clear)),
                environment: {},
                containerSize: CGSize(width: max(30.0, availableSize.width - 100.0), height: 44.0)
            )
            
            var textFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - cancelTextSize.width) * 0.5), y: component.insets.top + floor((availableSize.height - component.insets.top - component.insets.bottom - cancelTextSize.height) * 0.5)), size: cancelTextSize)
            let cancelButtonTextFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - cancelButtonTextSize.width) * 0.5), y: component.insets.top + floor((availableSize.height - component.insets.top - component.insets.bottom - cancelButtonTextSize.height) * 0.5)), size: cancelButtonTextSize)
            
            let bandingStart: CGFloat = 0.0
            let bandedOffset = abs(component.cancelFraction) - bandingStart
            let range: CGFloat = 300.0
            let coefficient: CGFloat = 0.4
            let mappedCancelFraction = bandingStart + (1.0 - (1.0 / ((bandedOffset * coefficient / range) + 1.0))) * range
            
            textFrame.origin.x -= mappedCancelFraction * 0.5
            
            if component.isRecordingLocked {
                if self.cancelContainerView.layer.animation(forKey: "recording") != nil {
                    if let presentation = self.cancelContainerView.layer.presentation() {
                        transition.animatePosition(view: self.cancelContainerView, from: presentation.position, to: CGPoint())
                        transition.animatePosition(view: self.vibrancyCancelContainerView, from: presentation.position, to: CGPoint())
                    }
                    self.cancelContainerView.layer.removeAnimation(forKey: "recording")
                    self.vibrancyCancelContainerView.layer.removeAnimation(forKey: "recording")
                }
            }
            
            if let cancelTextView = self.cancelText.view {
                if cancelTextView.superview == nil {
                    self.cancelContainerView.addSubview(cancelTextView)
                }
                transition.setPosition(view: cancelTextView, position: textFrame.center)
                transition.setBounds(view: cancelTextView, bounds: CGRect(origin: CGPoint(), size: textFrame.size))
                transition.setAlpha(view: cancelTextView, alpha: !component.isRecordingLocked ? 1.0 : 0.0)
                transition.setScale(view: cancelTextView, scale: !component.isRecordingLocked ? 1.0 : 0.001)
            }
            if let vibrancyCancelTextView = self.vibrancyCancelText.view {
                if vibrancyCancelTextView.superview == nil {
                    self.vibrancyCancelContainerView.addSubview(vibrancyCancelTextView)
                }
                transition.setPosition(view: vibrancyCancelTextView, position: textFrame.center)
                transition.setBounds(view: vibrancyCancelTextView, bounds: CGRect(origin: CGPoint(), size: textFrame.size))
                transition.setAlpha(view: vibrancyCancelTextView, alpha: !component.isRecordingLocked ? 1.0 : 0.0)
                transition.setScale(view: vibrancyCancelTextView, scale: !component.isRecordingLocked ? 1.0 : 0.001)
            }
            
            if let cancelButtonTextView = self.cancelButtonText.view {
                if cancelButtonTextView.superview == nil {
                    self.cancelContainerView.addSubview(cancelButtonTextView)
                }
                transition.setPosition(view: cancelButtonTextView, position: cancelButtonTextFrame.center)
                transition.setBounds(view: cancelButtonTextView, bounds: CGRect(origin: CGPoint(), size: cancelButtonTextFrame.size))
                transition.setAlpha(view: cancelButtonTextView, alpha: component.isRecordingLocked ? 1.0 : 0.0)
                transition.setScale(view: cancelButtonTextView, scale: component.isRecordingLocked ? 1.0 : 0.001)
            }
            if let vibrancyCancelButtonTextView = self.vibrancyCancelButtonText.view {
                if vibrancyCancelButtonTextView.superview == nil {
                    self.vibrancyCancelContainerView.addSubview(vibrancyCancelButtonTextView)
                }
                transition.setPosition(view: vibrancyCancelButtonTextView, position: cancelButtonTextFrame.center)
                transition.setBounds(view: vibrancyCancelButtonTextView, bounds: CGRect(origin: CGPoint(), size: cancelButtonTextFrame.size))
                transition.setAlpha(view: vibrancyCancelButtonTextView, alpha: component.isRecordingLocked ? 1.0 : 0.0)
                transition.setScale(view: vibrancyCancelButtonTextView, scale: component.isRecordingLocked ? 1.0 : 0.001)
            }
            
            if component.isRecordingLocked {
                let cancelButton: HighlightableButton
                if let current = self.cancelButton {
                    cancelButton = current
                } else {
                    cancelButton = HighlightableButton()
                    self.cancelButton = cancelButton
                    self.addSubview(cancelButton)
                    
                    cancelButton.highligthedChanged = { [weak self] highlighted in
                        guard let self else {
                            return
                        }
                        if highlighted {
                            self.cancelContainerView.alpha = 0.6
                            self.vibrancyCancelContainerView.alpha = 0.6
                        } else {
                            self.cancelContainerView.alpha = 1.0
                            self.vibrancyCancelContainerView.alpha = 1.0
                            self.cancelContainerView.layer.animateAlpha(from: 0.6, to: 1.0, duration: 0.2)
                            self.vibrancyCancelContainerView.layer.animateAlpha(from: 0.6, to: 1.0, duration: 0.2)
                        }
                    }
                    
                    cancelButton.addTarget(self, action: #selector(self.cancelButtonPressed), for: .touchUpInside)
                }
                
                cancelButton.frame = CGRect(origin: CGPoint(x: cancelButtonTextFrame.minX - 8.0, y: 0.0), size: CGSize(width: cancelButtonTextFrame.width + 8.0 * 2.0, height: availableSize.height))
            } else if let cancelButton = self.cancelButton {
                cancelButton.removeFromSuperview()
            }
            
            if let image = self.cancelIconView.image {
                let iconFrame = CGRect(origin: CGPoint(x: textFrame.minX - 4.0 - image.size.width, y: textFrame.minY + floor((textFrame.height - image.size.height) * 0.5)), size: image.size)
                
                transition.setPosition(view: self.cancelIconView, position: iconFrame.center)
                transition.setBounds(view: self.cancelIconView, bounds: CGRect(origin: CGPoint(), size: iconFrame.size))
                transition.setAlpha(view: self.cancelIconView, alpha: !component.isRecordingLocked ? 1.0 : 0.0)
                transition.setScale(view: self.cancelIconView, scale: !component.isRecordingLocked ? 1.0 : 0.001)
                
                transition.setPosition(view: self.vibrancyCancelIconView, position: iconFrame.center)
                transition.setBounds(view: self.vibrancyCancelIconView, bounds: CGRect(origin: CGPoint(), size: iconFrame.size))
                transition.setAlpha(view: self.vibrancyCancelIconView, alpha: !component.isRecordingLocked ? 1.0 : 0.0)
                transition.setScale(view: self.vibrancyCancelIconView, scale: !component.isRecordingLocked ? 1.0 : 0.001)
            }
            
            self.updateAnimations()
            
            transition.setFrame(view: self.vibrancyContainer, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
