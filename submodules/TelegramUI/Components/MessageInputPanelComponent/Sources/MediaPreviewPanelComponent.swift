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
import ManagedAnimationNode
import AudioWaveformComponent
import UniversalMediaPlayer

private final class PlayPauseIconNode: ManagedAnimationNode {
    enum State: Equatable {
        case play
        case pause
    }
    
    private let duration: Double = 0.35
    private var iconState: State = .pause
    
    init() {
        super.init(size: CGSize(width: 28.0, height: 28.0))
        
        self.enqueueState(.play, animated: false)
    }
    
    func enqueueState(_ state: State, animated: Bool) {
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

private func textForDuration(seconds: Int32) -> String {
    if seconds >= 60 * 60 {
        return String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60)
    } else {
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

public final class MediaPreviewPanelComponent: Component {
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let mediaPreview: ChatRecordedMediaPreview
    public let insets: UIEdgeInsets
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        mediaPreview: ChatRecordedMediaPreview,
        insets: UIEdgeInsets
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.mediaPreview = mediaPreview
        self.insets = insets
    }
    
    public static func ==(lhs: MediaPreviewPanelComponent, rhs: MediaPreviewPanelComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.mediaPreview !== rhs.mediaPreview {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        return true
    }
    
    public final class View: UIView {        
        private var component: MediaPreviewPanelComponent?
        private weak var state: EmptyComponentState?
        
        public let vibrancyContainer: UIView
        
        private let trackingLayer: HierarchyTrackingLayer
                
        private let timerFont: UIFont
        private let timerText = ComponentView<Empty>()
        
        private var timerTextValue: String = "0:00"
        
        private let playPauseIconButton: HighlightableButton
        private let playPauseIconNode: PlayPauseIconNode
        
        private let waveform = ComponentView<Empty>()
        private let vibrancyWaveform = ComponentView<Empty>()
        
        private var mediaPlayer: MediaPlayer?
        private let mediaPlayerStatus = Promise<MediaPlayerStatus?>(nil)
        private var mediaPlayerStatusDisposable: Disposable?
        
        override init(frame: CGRect) {
            self.trackingLayer = HierarchyTrackingLayer()
            
            self.timerFont = Font.with(size: 15.0, design: .camera, traits: .monospacedNumbers)
            
            self.vibrancyContainer = UIView()
            
            self.playPauseIconButton = HighlightableButton()
            self.playPauseIconNode = PlayPauseIconNode()
            self.playPauseIconNode.isUserInteractionEnabled = false
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.trackingLayer)
            self.playPauseIconButton.addSubview(self.playPauseIconNode.view)
            self.addSubview(self.playPauseIconButton)
            
            self.playPauseIconButton.addTarget(self, action: #selector(self.playPauseButtonPressed), for: .touchUpInside)
            
            self.mediaPlayerStatusDisposable = (self.mediaPlayerStatus.get()
            |> deliverOnMainQueue).start(next: { [weak self] status in
                guard let self else {
                    return
                }
                
                if let status {
                    switch status.status {
                    case .playing, .buffering(_, true, _, _):
                        self.playPauseIconNode.enqueueState(.play, animated: true)
                    default:
                        self.playPauseIconNode.enqueueState(.pause, animated: true)
                    }
                    
                    //self.timerTextValue = textForDuration(seconds: component.mediaPreview.duration)
                } else {
                    self.playPauseIconNode.enqueueState(.play, animated: true)
                }
            })
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.mediaPlayerStatusDisposable?.dispose()
        }
        
        public func animateIn() {
            self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
        }
        
        public func animateOut(transition: Transition, completion: @escaping () -> Void) {
            let vibrancyContainer = self.vibrancyContainer
            transition.setAlpha(view: vibrancyContainer, alpha: 0.0, completion: { [weak vibrancyContainer] _ in
                vibrancyContainer?.removeFromSuperview()
            })
            transition.setAlpha(view: self, alpha: 0.0, completion: { _ in
                completion()
            })
        }
        
        @objc private func playPauseButtonPressed() {
            guard let component = self.component else {
                return
            }
            
            if let mediaPlayer = self.mediaPlayer {
                mediaPlayer.togglePlayPause()
            } else {
                let mediaManager = component.context.sharedContext.mediaManager
                let mediaPlayer = MediaPlayer(
                    audioSessionManager: mediaManager.audioSession,
                    postbox: component.context.account.postbox,
                    userLocation: .other,
                    userContentType: .audio,
                    resourceReference: .standalone(resource: component.mediaPreview.resource),
                    streamable: .none,
                    video: false,
                    preferSoftwareDecoding: false,
                    enableSound: true,
                    fetchAutomatically: true
                )
                mediaPlayer.actionAtEnd = .action { [weak mediaPlayer] in
                    mediaPlayer?.seek(timestamp: 0.0)
                }
                self.mediaPlayer = mediaPlayer
                
                self.mediaPlayerStatus.set(mediaPlayer.status |> map(Optional.init))
                
                mediaPlayer.play()
            }
        }
        
        func update(component: MediaPreviewPanelComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            if self.component == nil {
                self.timerTextValue = textForDuration(seconds: component.mediaPreview.duration)
            }
            
            self.component = component
            self.state = state
            
            let timerTextSize = self.timerText.update(
                transition: .immediate,
                component: AnyComponent(Text(text: self.timerTextValue, font: self.timerFont, color: .white)),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            if let timerTextView = self.timerText.view {
                if timerTextView.superview == nil {
                    self.addSubview(timerTextView)
                    timerTextView.layer.anchorPoint = CGPoint(x: 1.0, y: 0.5)
                }
                let timerTextFrame = CGRect(origin: CGPoint(x: availableSize.width - component.insets.right - 8.0, y: component.insets.top + floor((availableSize.height - component.insets.top - component.insets.bottom - timerTextSize.height) * 0.5)), size: timerTextSize)
                transition.setPosition(view: timerTextView, position: CGPoint(x: timerTextFrame.minX, y: timerTextFrame.midY))
                timerTextView.bounds = CGRect(origin: CGPoint(), size: timerTextFrame.size)
            }
            
            let playPauseSize = CGSize(width: 28.0, height: 28.0)
            var playPauseFrame = CGRect(origin: CGPoint(x: component.insets.left + 8.0, y: component.insets.top + floor((availableSize.height - component.insets.top - component.insets.bottom - playPauseSize.height) * 0.5)), size: playPauseSize)
            let playPauseButtonFrame = playPauseFrame.insetBy(dx: -8.0, dy: -8.0)
            playPauseFrame = playPauseFrame.offsetBy(dx: -playPauseButtonFrame.minX, dy: -playPauseButtonFrame.minY)
            transition.setFrame(view: self.playPauseIconButton, frame: playPauseButtonFrame)
            transition.setFrame(view: self.playPauseIconNode.view, frame: playPauseFrame)
            
            let waveformFrame = CGRect(origin: CGPoint(x: component.insets.left + 47.0, y: component.insets.top + floor((availableSize.height - component.insets.top - component.insets.bottom - 24.0) * 0.5)), size: CGSize(width: availableSize.width - component.insets.right - 47.0 - (component.insets.left + 47.0), height: 24.0))
            
            let _ = self.waveform.update(
                transition: transition,
                component: AnyComponent(AudioWaveformComponent(
                    backgroundColor: UIColor.white.withAlphaComponent(0.1),
                    foregroundColor: UIColor.white.withAlphaComponent(1.0),
                    shimmerColor: nil,
                    style: .middle,
                    samples: component.mediaPreview.waveform.samples,
                    peak: component.mediaPreview.waveform.peak,
                    status: self.mediaPlayerStatus.get() |> map { value -> MediaPlayerStatus in
                        if let value {
                            return value
                        } else {
                            return MediaPlayerStatus(
                                generationTimestamp: 0.0,
                                duration: 0.0,
                                dimensions: CGSize(),
                                timestamp: 0.0,
                                baseRate: 1.0,
                                seekId: 0,
                                status: .paused,
                                soundEnabled: true
                            )
                        }
                    },
                    seek: { [weak self] timestamp in
                        guard let self, let mediaPlayer = self.mediaPlayer else {
                            return
                        }
                        mediaPlayer.seek(timestamp: timestamp)
                    },
                    updateIsSeeking: { [weak self] isSeeking in
                        guard let self, let mediaPlayer = self.mediaPlayer else {
                            return
                        }
                        if isSeeking {
                            mediaPlayer.pause()
                        } else {
                            mediaPlayer.play()
                        }
                    }
                )),
                environment: {},
                containerSize: waveformFrame.size
            )
            let _ = self.vibrancyWaveform.update(
                transition: transition,
                component: AnyComponent(AudioWaveformComponent(
                    backgroundColor: .white,
                    foregroundColor: .white,
                    shimmerColor: nil,
                    style: .middle,
                    samples: component.mediaPreview.waveform.samples,
                    peak: component.mediaPreview.waveform.peak,
                    status: .complete(),
                    seek: nil,
                    updateIsSeeking: nil
                )),
                environment: {},
                containerSize: waveformFrame.size
            )
            
            if let waveformView = self.waveform.view as? AudioWaveformComponent.View {
                if waveformView.superview == nil {
                    waveformView.enableScrubbing = true
                    self.addSubview(waveformView)
                }
                transition.setFrame(view: waveformView, frame: waveformFrame)
            }
            if let vibrancyWaveformView = self.vibrancyWaveform.view {
                if vibrancyWaveformView.superview == nil {
                    self.vibrancyContainer.addSubview(vibrancyWaveformView)
                }
                transition.setFrame(view: vibrancyWaveformView, frame: waveformFrame)
            }
            
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
