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
        
        private let indicatorView: UIImageView
        
        private let cancelIconView: UIImageView
        private let cancelText = ComponentView<Empty>()
        private let timerText = ComponentView<Empty>()
        
        private var timerTextDisposable: Disposable?
        
        private var timerTextValue: String = "0:00,00"
        
        override init(frame: CGRect) {
            self.indicatorView = UIImageView()
            self.cancelIconView = UIImageView()
            
            super.init(frame: frame)
            
            self.addSubview(self.indicatorView)
            self.addSubview(self.cancelIconView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.timerTextDisposable?.dispose()
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
            
            if self.indicatorView.image == nil {
                self.indicatorView.image = generateFilledCircleImage(diameter: 10.0, color: UIColor(rgb: 0xFF3B30))
            }
            if let image = self.indicatorView.image {
                transition.setFrame(view: self.indicatorView, frame: CGRect(origin: CGPoint(x: 10.0, y: floor((availableSize.height - image.size.height) * 0.5)), size: image.size))
            }
            
            let timerTextSize = self.timerText.update(
                transition: .immediate,
                component: AnyComponent(Text(text: self.timerTextValue, font: Font.regular(15.0), color: .white)),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            if let timerTextView = self.timerText.view {
                if timerTextView.superview == nil {
                    self.addSubview(timerTextView)
                    timerTextView.layer.anchorPoint = CGPoint()
                }
                let timerTextFrame = CGRect(origin: CGPoint(x: 28.0, y: floor((availableSize.height - timerTextSize.height) * 0.5)), size: timerTextSize)
                transition.setPosition(view: timerTextView, position: timerTextFrame.origin)
                timerTextView.bounds = CGRect(origin: CGPoint(), size: timerTextFrame.size)
            }
            
            if self.cancelIconView.image == nil {
                self.cancelIconView.image = UIImage(bundleImageName: "Chat/Input/Text/AudioRecordingCancelArrow")?.withRenderingMode(.alwaysTemplate)
            }
            
            self.cancelIconView.tintColor = UIColor(white: 1.0, alpha: 0.3)
            
            let cancelTextSize = self.cancelText.update(
                transition: .immediate,
                component: AnyComponent(Text(text: "Slide to cancel", font: Font.regular(15.0), color: UIColor(white: 1.0, alpha: 0.3))),
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
                    self.addSubview(cancelTextView)
                }
                transition.setFrame(view: cancelTextView, frame: textFrame)
            }
            if let image = self.cancelIconView.image {
                transition.setFrame(view: self.cancelIconView, frame: CGRect(origin: CGPoint(x: textFrame.minX - 4.0 - image.size.width, y: textFrame.minY + floor((textFrame.height - image.size.height) * 0.5)), size: image.size))
            }
            
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
