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
    public let audioRecorder: ManagedAudioRecorder?
    public let videoRecordingStatus: InstantVideoControllerRecordingStatus?
    public let cancelFraction: CGFloat
    
    public init(
        audioRecorder: ManagedAudioRecorder?,
        videoRecordingStatus: InstantVideoControllerRecordingStatus?,
        cancelFraction: CGFloat
    ) {
        self.audioRecorder = audioRecorder
        self.videoRecordingStatus = videoRecordingStatus
        self.cancelFraction = cancelFraction
    }
    
    public static func ==(lhs: MediaRecordingPanelComponent, rhs: MediaRecordingPanelComponent) -> Bool {
        if lhs.audioRecorder !== rhs.audioRecorder {
            return false
        }
        if lhs.videoRecordingStatus !== rhs.videoRecordingStatus {
            return false
        }
        if lhs.cancelFraction != rhs.cancelFraction {
            return false
        }
        return true
    }
    
    public final class View: UIView {        
        private var component: MediaRecordingPanelComponent?
        private weak var state: EmptyComponentState?
        
        private let trackingLayer: HierarchyTrackingLayer
        
        private let indicator = ComponentView<Empty>()
        
        private let cancelContainerView: UIView
        private let cancelIconView: UIImageView
        private let cancelText = ComponentView<Empty>()
        
        private let timerFont: UIFont
        private let timerText = ComponentView<Empty>()
        
        private var timerTextDisposable: Disposable?
        
        private var timerTextValue: String = "0:00,00"
        
        override init(frame: CGRect) {
            self.trackingLayer = HierarchyTrackingLayer()
            self.cancelIconView = UIImageView()
            
            self.timerFont = Font.with(size: 15.0, design: .camera, traits: .monospacedNumbers)
            
            self.cancelContainerView = UIView()
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.trackingLayer)
            
            self.cancelContainerView.addSubview(self.cancelIconView)
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
            if self.cancelContainerView.layer.animation(forKey: "recording") == nil {
                let animation = CAKeyframeAnimation(keyPath: "position.x")
                animation.values = [-5.0 as NSNumber, 5.0 as NSNumber, 0.0 as NSNumber]
                animation.keyTimes = [0.0 as NSNumber, 0.4546 as NSNumber, 0.9091 as NSNumber, 1 as NSNumber]
                animation.duration = 1.5
                animation.autoreverses = true
                animation.isAdditive = true
                animation.repeatCount = Float.infinity
                
                self.cancelContainerView.layer.add(animation, forKey: "recording")
            }
        }
        
        public func animateIn() {
            if let indicatorView = self.indicator.view {
                indicatorView.layer.animatePosition(from: CGPoint(x: -20.0, y: 0.0), to: CGPoint(), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            }
            if let timerTextView = self.timerText.view {
                timerTextView.layer.animatePosition(from: CGPoint(x: -20.0, y: 0.0), to: CGPoint(), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            }
            self.cancelContainerView.layer.animatePosition(from: CGPoint(x: self.bounds.width, y: 0.0), to: CGPoint(), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        }
        
        public func animateOut(dismissRecording: Bool, completion: @escaping () -> Void) {
            if let indicatorView = self.indicator.view as? LottieComponent.View {
                if let _ = indicatorView.layer.animation(forKey: "recording") {
                    let fromAlpha = indicatorView.layer.presentation()?.opacity ?? indicatorView.layer.opacity
                    indicatorView.layer.removeAnimation(forKey: "recording")
                    indicatorView.layer.animateAlpha(from: CGFloat(fromAlpha), to: 1.0, duration: 0.2)
                    
                    indicatorView.playOnce(completion: { [weak indicatorView] in
                        if let indicatorView {
                            let transition = Transition(animation: .curve(duration: 0.3, curve: .spring))
                            transition.setScale(view: indicatorView, scale: 0.001)
                        }
                        
                        completion()
                    })
                }
            } else {
                completion()
            }
            
            
            let transition = Transition(animation: .curve(duration: 0.3, curve: .spring))
            if let timerTextView = self.timerText.view {
                transition.setAlpha(view: timerTextView, alpha: 0.0)
                transition.setScale(view: timerTextView, scale: 0.001)
            }
            
            transition.setAlpha(view: self.cancelContainerView, alpha: 0.0)
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
                transition.setFrame(view: indicatorView, frame: CGRect(origin: CGPoint(x: 3.0, y: floor((availableSize.height - indicatorSize.height) * 0.5)), size: indicatorSize))
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
                let timerTextFrame = CGRect(origin: CGPoint(x: 38.0, y: floor((availableSize.height - timerTextSize.height) * 0.5)), size: timerTextSize)
                transition.setPosition(view: timerTextView, position: CGPoint(x: timerTextFrame.minX, y: timerTextFrame.midY))
                timerTextView.bounds = CGRect(origin: CGPoint(), size: timerTextFrame.size)
            }
            
            if self.cancelIconView.image == nil {
                self.cancelIconView.image = UIImage(bundleImageName: "Chat/Input/Text/AudioRecordingCancelArrow")?.withRenderingMode(.alwaysTemplate)
            }
            
            self.cancelIconView.tintColor = UIColor(white: 1.0, alpha: 0.4)
            
            let cancelTextSize = self.cancelText.update(
                transition: .immediate,
                component: AnyComponent(Text(text: "Slide to cancel", font: Font.regular(15.0), color: UIColor(white: 1.0, alpha: 0.4))),
                environment: {},
                containerSize: CGSize(width: max(30.0, availableSize.width - 100.0), height: 44.0)
            )
            
            var textFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - cancelTextSize.width) * 0.5), y: floor((availableSize.height - cancelTextSize.height) * 0.5)), size: cancelTextSize)
            
            let bandingStart: CGFloat = 0.0
            let bandedOffset = abs(component.cancelFraction) - bandingStart
            let range: CGFloat = 300.0
            let coefficient: CGFloat = 0.4
            let mappedCancelFraction = bandingStart + (1.0 - (1.0 / ((bandedOffset * coefficient / range) + 1.0))) * range
            
            textFrame.origin.x -= mappedCancelFraction * 0.5
            
            if let cancelTextView = self.cancelText.view {
                if cancelTextView.superview == nil {
                    self.cancelContainerView.addSubview(cancelTextView)
                }
                transition.setFrame(view: cancelTextView, frame: textFrame)
            }
            if let image = self.cancelIconView.image {
                transition.setFrame(view: self.cancelIconView, frame: CGRect(origin: CGPoint(x: textFrame.minX - 4.0 - image.size.width, y: textFrame.minY + floor((textFrame.height - image.size.height) * 0.5)), size: image.size))
            }
            
            self.updateAnimations()
            
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
