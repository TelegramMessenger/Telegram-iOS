import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import UniversalMediaPlayer
import AppBundle
import ContextUI
import AnimationUI
import ManagedAnimationNode
import ChatPresentationInterfaceState
import ChatSendButtonRadialStatusNode
import AudioWaveformNode
import ChatInputPanelNode
import TooltipUI
import TelegramNotices
import ComponentFlow
import MediaScrubberComponent
import AnimatedCountLabelNode
import ChatRecordingViewOnceButtonNode
import GlassBackgroundComponent
import ComponentFlow
import ComponentDisplayAdapters

#if SWIFT_PACKAGE
extension AudioWaveformNode: CustomMediaPlayerScrubbingForegroundNode {
}
#else
extension AudioWaveformNode: @retroactive CustomMediaPlayerScrubbingForegroundNode {
}
#endif

final class ChatRecordingPreviewViewForOverlayContent: UIView, ChatInputPanelViewForOverlayContent {
    let ignoreHit: (UIView, CGPoint) -> Bool
    
    init(ignoreHit: @escaping (UIView, CGPoint) -> Bool) {
        self.ignoreHit = ignoreHit
        
        super.init(frame: CGRect())
    }
    
    required init(coder: NSCoder) {
        preconditionFailure()
    }
    
    func maybeDismissContent(point: CGPoint) {
        for subview in self.subviews.reversed() {
            if let _ = subview.hitTest(self.convert(point, to: subview), with: nil) {
                return
            }
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for subview in self.subviews.reversed() {
            if let result = subview.hitTest(self.convert(point, to: subview), with: event) {
                return result
            }
        }
        
        if event == nil || self.ignoreHit(self, point) {
            return nil
        }
        
        return nil
    }
}

final class PlayButtonNode: ASDisplayNode {
    let backgroundView: GlassBackgroundView
    let playButton: HighlightableButtonNode
    fileprivate let playPauseIconNode: PlayPauseIconNode
    let durationLabel: MediaPlayerTimeTextNode
    
    var pressed: () -> Void = {}
    
    init(theme: PresentationTheme) {
        self.backgroundView = GlassBackgroundView(frame: CGRect())
        
        self.playButton = HighlightableButtonNode()
        self.playButton.displaysAsynchronously = false
        
        self.playPauseIconNode = PlayPauseIconNode()
        self.playPauseIconNode.enqueueState(.play, animated: false)
        self.playPauseIconNode.customColor = theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.7)
        
        self.durationLabel = MediaPlayerTimeTextNode(textColor: theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.7), textFont: Font.with(size: 13.0, weight: .semibold, traits: .monospacedNumbers))
        self.durationLabel.alignment = .right
        self.durationLabel.mode = .normal
        self.durationLabel.showDurationIfNotStarted = true
        
        super.init()
        
        self.view.addSubview(self.backgroundView)
        self.addSubnode(self.playButton)
        self.backgroundView.contentView.addSubview(self.playPauseIconNode.view)
        self.backgroundView.contentView.addSubview(self.durationLabel.view)
        
        self.playButton.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return self.backgroundView.frame.contains(point)
    }
    
    @objc private func buttonPressed() {
        self.pressed()
    }
    
    func update(theme: PresentationTheme, size: CGSize, transition: ContainedViewLayoutTransition) {
        var buttonSize = CGSize(width: 63.0, height: 22.0)
        if size.width < 70.0 {
            buttonSize.width = 27.0
        }
        
        let backgroundFrame = buttonSize.centered(in: CGRect(origin: .zero, size: size))
        transition.updateFrame(view: self.backgroundView, frame: backgroundFrame)
        self.backgroundView.update(size: backgroundFrame.size, cornerRadius: backgroundFrame.height * 0.5, isDark: theme.overallDarkAppearance, tintColor: .init(kind: .panel, color: theme.chat.inputPanel.inputBackgroundColor.withMultipliedAlpha(0.4)), transition: ComponentTransition(transition))
                
        self.playPauseIconNode.frame = CGRect(origin: CGPoint(x: 3.0, y: 1.0 - UIScreenPixel), size: CGSize(width: 21.0, height: 21.0))
                               
        transition.updateFrame(node: self.durationLabel, frame: CGRect(origin: CGPoint(x: 18.0, y: 3.0), size: CGSize(width: 35.0, height: 20.0)))
        transition.updateAlpha(node: self.durationLabel, alpha: buttonSize.width > 27.0 ? 1.0 : 0.0)
        
        self.playButton.frame = CGRect(origin: .zero, size: size)
    }
}

private final class ClippedWaveformNode: ASDisplayNode, CustomMediaPlayerScrubbingForegroundNode {
    let waveformNode: AudioWaveformNode
    let waveformLeftMaskView: UIImageView
    let waveformRightMaskView: UIImageView
    let waveformMaskView: UIView
    let foregroundClippingContainer: ASDisplayNode
    let foregroundWaveformNode: AudioWaveformNode
    
    var progress: CGFloat? {
        didSet {
            if self.progress != oldValue {
                self.waveformNode.progress = self.progress
                self.foregroundWaveformNode.progress = self.progress
            }
        }
    }
    
    override var frame: CGRect {
        didSet {
            self.updateLayout()
        }
    }
    
    override var bounds: CGRect {
        didSet {
            self.updateLayout()
        }
    }
    
    override init() {
        self.waveformNode = AudioWaveformNode()
        
        self.waveformMaskView = UIView()
        self.waveformLeftMaskView = UIImageView()
        self.waveformLeftMaskView.layer.anchorPoint = CGPoint(x: 1.0, y: 0.0)
        self.waveformLeftMaskView.backgroundColor = .white
        self.waveformMaskView.addSubview(self.waveformLeftMaskView)
        self.waveformRightMaskView = UIImageView()
        self.waveformRightMaskView.layer.anchorPoint = CGPoint()
        self.waveformRightMaskView.backgroundColor = .white
        self.waveformMaskView.addSubview(self.waveformRightMaskView)
        
        self.foregroundClippingContainer = ASDisplayNode()
        self.foregroundClippingContainer.clipsToBounds = true
        self.foregroundClippingContainer.anchorPoint = CGPoint()
        
        self.foregroundWaveformNode = AudioWaveformNode()
        self.foregroundWaveformNode.isLayerBacked = true
        self.foregroundClippingContainer.addSubnode(self.foregroundWaveformNode)
        
        super.init()
        
        self.addSubnode(self.waveformNode)
        self.waveformNode.view.mask = self.waveformMaskView
        self.addSubnode(self.foregroundClippingContainer)
    }
    
    private func updateLayout() {
        self.waveformNode.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
        self.foregroundWaveformNode.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
        
        self.waveformLeftMaskView.bounds = CGRect(origin: CGPoint(), size: self.bounds.size)
        self.waveformRightMaskView.bounds = CGRect(origin: CGPoint(), size: self.bounds.size)
    }
    
    func updateClipping(minX: CGFloat, maxX: CGFloat, transition: ContainedViewLayoutTransition) {
        let clippingFrame = CGRect(origin: CGPoint(x: minX, y: 0.0), size: CGSize(width: max(0.0, maxX - minX), height: 40.0 - 2.0 * 2.0))
        transition.updatePosition(node: self.foregroundClippingContainer, position: clippingFrame.origin)
        transition.updateBounds(node: self.foregroundClippingContainer, bounds: CGRect(origin: CGPoint(x: minX, y: 0.0), size: clippingFrame.size))
        
        transition.updatePosition(layer: self.waveformLeftMaskView.layer, position: CGPoint(x: minX, y: 0.0))
        transition.updatePosition(layer: self.waveformRightMaskView.layer, position: CGPoint(x: maxX, y: 0.0))
    }
}

public final class ChatRecordingPreviewInputPanelNodeImpl: ChatInputPanelNode {
    private let waveformButton: ASButtonNode
    let waveformBackgroundNodeImpl: ASImageNode
    var waveformBackgroundNode: ASDisplayNode {
        return self.waveformBackgroundNodeImpl
    }
    
    let trimViewImpl: TrimView
    var trimView: UIView {
        return self.trimViewImpl
    }
    let playButtonNodeImpl: PlayButtonNode
    var playButtonNode: ASDisplayNode {
        return self.playButtonNodeImpl
    }
    
    let scrubber = ComponentView<Empty>()

    private let waveformNode: ClippedWaveformNode
    private let tintWaveformNode: AudioWaveformNode
    private let waveformForegroundNode: AudioWaveformNode
    let waveformScrubberNodeImpl: MediaPlayerScrubbingNode
    var waveformScrubberNode: ASDisplayNode {
        return self.waveformScrubberNodeImpl
    }
    
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    private var mediaPlayer: MediaPlayer?
    
    private var statusValue: MediaPlayerStatus?
    private let statusDisposable = MetaDisposable()
    private var scrubbingDisposable: Disposable?
    
    private var positionTimer: SwiftSignalKit.Timer?
    
    private(set) var gestureRecognizer: ContextGesture?
    
    public let tintMaskView: UIView = UIView()
    
    public init(theme: PresentationTheme) {
        self.waveformBackgroundNodeImpl = ASImageNode()
        self.waveformBackgroundNodeImpl.isLayerBacked = true
        self.waveformBackgroundNodeImpl.displaysAsynchronously = false
        self.waveformBackgroundNodeImpl.displayWithoutProcessing = true
        self.waveformBackgroundNodeImpl.image = generateStretchableFilledCircleImage(diameter: 40.0 - 2.0 * 2.0, color: theme.list.itemCheckColors.fillColor)
        
        self.waveformButton = ASButtonNode()
        self.waveformButton.accessibilityTraits.insert(.startsMediaSession)
        
        self.waveformNode = ClippedWaveformNode()
        self.waveformForegroundNode = AudioWaveformNode()
        self.waveformForegroundNode.isLayerBacked = true
        
        self.tintWaveformNode = AudioWaveformNode()
        self.tintWaveformNode.isLayerBacked = true
        
        self.waveformScrubberNodeImpl = MediaPlayerScrubbingNode(content: .custom(backgroundNode: self.waveformNode, foregroundContentNode: self.waveformForegroundNode))
        
        self.trimViewImpl = TrimView(frame: .zero)
        self.trimViewImpl.isHollow = true
        self.playButtonNodeImpl = PlayButtonNode(theme: theme)
        
        super.init()
        
        self.tintMaskView.layer.addSublayer(self.tintWaveformNode.layer)
        
        self.viewForOverlayContent = ChatRecordingPreviewViewForOverlayContent(
            ignoreHit: { [weak self] view, point in
                guard let strongSelf = self else {
                    return false
                }
                if strongSelf.view.hitTest(view.convert(point, to: strongSelf.view), with: nil) != nil {
                    return true
                }
                if view.convert(point, to: strongSelf.view).y > strongSelf.view.bounds.maxY {
                    return true
                }
                return false
            }
        )
        
        self.addSubnode(self.waveformBackgroundNodeImpl)
        self.addSubnode(self.waveformScrubberNode)
        //self.addSubnode(self.waveformButton)
        
        self.view.addSubview(self.trimViewImpl)
        self.addSubnode(self.playButtonNodeImpl)
        
        self.playButtonNodeImpl.pressed = { [weak self] in
            guard let self else {
                return
            }
            self.waveformPressed()
        }
                
        self.waveformScrubberNodeImpl.seek = { [weak self] timestamp in
            guard let self else {
                return
            }
            var timestamp = timestamp
            if let recordedMediaPreview = self.presentationInterfaceState?.interfaceState.mediaDraftState, case let .audio(audio) = recordedMediaPreview, let trimRange = audio.trimRange {
                timestamp = max(trimRange.lowerBound, min(timestamp, trimRange.upperBound))
            }
            self.mediaPlayer?.seek(timestamp: timestamp)
        }
        
        self.scrubbingDisposable = (self.waveformScrubberNodeImpl.scrubbingPosition
        |> deliverOnMainQueue).startStrict(next: { [weak self] value in
            guard let self else {
                return
            }
            let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .easeInOut)
            transition.updateAlpha(node: self.playButtonNodeImpl, alpha: value != nil ? 0.0 : 1.0)
        })
        
        self.waveformButton.addTarget(self, action: #selector(self.waveformPressed), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.mediaPlayer?.pause()
        self.statusDisposable.dispose()
        self.scrubbingDisposable?.dispose()
        self.positionTimer?.invalidate()
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
    }
    
    private func ensureHasTimer() {
        if self.positionTimer == nil {
            let timer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
                self?.checkPosition()
            }, queue: Queue.mainQueue())
            self.positionTimer = timer
            timer.start()
        }
    }
    
    func checkPosition() {
        guard let statusValue = self.statusValue, let recordedMediaPreview = self.presentationInterfaceState?.interfaceState.mediaDraftState, case let .audio(audio) = recordedMediaPreview, let trimRange = audio.trimRange, let mediaPlayer = self.mediaPlayer else {
            return
        }
        let timestampSeconds: Double
        if !statusValue.generationTimestamp.isZero {
            timestampSeconds = statusValue.timestamp + (CACurrentMediaTime() - statusValue.generationTimestamp)
        } else {
            timestampSeconds = statusValue.timestamp
        }
        if timestampSeconds >= trimRange.upperBound {
            mediaPlayer.seek(timestamp: trimRange.lowerBound, play: false)
        }
    }
    
    private func stopTimer() {
        self.positionTimer?.invalidate()
        self.positionTimer = nil
    }
    
    private func maybePresentViewOnceTooltip() {
        /*guard let context = self.context else {
            return
        }
        let _ = (ApplicationSpecificNotice.getVoiceMessagesPlayOnceSuggestion(accountManager: context.sharedContext.accountManager)
        |> deliverOnMainQueue).startStandalone(next: { [weak self] counter in
            guard let self, let interfaceState = self.presentationInterfaceState else {
                return
            }
            if counter >= 3 {
                return
            }

            Queue.mainQueue().after(0.3) {
                self.displayViewOnceTooltip(text: interfaceState.strings.Chat_TapToPlayVoiceMessageOnceTooltip, hasIcon: true)
            }
        
            let _ = ApplicationSpecificNotice.incrementVoiceMessagesPlayOnceSuggestion(accountManager: context.sharedContext.accountManager).startStandalone()
        })*/
    }
    
    override public func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, maxOverlayHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics, isMediaInputExpanded: Bool) -> CGFloat {
        let waveformBackgroundFrame = CGRect(origin: CGPoint(x: 3.0, y: 3.0), size: CGSize(width: width - 3.0 * 2.0, height: 40.0 - 3.0 * 2.0))
        
        if self.presentationInterfaceState != interfaceState {
            var updateWaveform = false
            if self.presentationInterfaceState?.interfaceState.mediaDraftState != interfaceState.interfaceState.mediaDraftState {
                updateWaveform = true
            }
            if self.presentationInterfaceState?.strings !== interfaceState.strings {
                self.waveformButton.accessibilityLabel = interfaceState.strings.VoiceOver_Chat_RecordPreviewVoiceMessage
            }
            
            self.presentationInterfaceState = interfaceState
                    
            if let recordedMediaPreview = interfaceState.interfaceState.mediaDraftState, let context = self.context {
                switch recordedMediaPreview {
                case let .audio(audio):
                    self.waveformButton.isHidden = false
                    self.waveformBackgroundNodeImpl.isHidden = false
                    self.waveformForegroundNode.isHidden = false
                    self.waveformScrubberNodeImpl.isHidden = false
                    self.playButtonNodeImpl.isHidden = false
                    
                    if let view = self.scrubber.view, view.superview != nil {
                        view.removeFromSuperview()
                    }
                    
                    if updateWaveform {
                        self.waveformNode.waveformNode.setup(color: interfaceState.theme.chat.inputPanel.panelControlColor.withMultipliedAlpha(0.4), gravity: .center, waveform: audio.waveform)
                        self.waveformNode.foregroundWaveformNode.setup(color: interfaceState.theme.list.itemCheckColors.foregroundColor.withMultipliedAlpha(0.5), gravity: .center, waveform: audio.waveform)
                        self.tintWaveformNode.setup(color: UIColor(white: 0.0, alpha: 0.5), gravity: .center, waveform: audio.waveform)
                        self.waveformForegroundNode.setup(color: interfaceState.theme.list.itemCheckColors.foregroundColor, gravity: .center, waveform: audio.waveform)
                        if self.mediaPlayer != nil {
                            self.mediaPlayer?.pause()
                        }
                        let mediaManager = context.sharedContext.mediaManager
                        let mediaPlayer = MediaPlayer(audioSessionManager: mediaManager.audioSession, postbox: context.account.postbox, userLocation: .other, userContentType: .audio, resourceReference: .standalone(resource: audio.resource), streamable: .none, video: false, preferSoftwareDecoding: false, enableSound: true, fetchAutomatically: true)
                        mediaPlayer.actionAtEnd = .action { [weak self] in
                            guard let self else {
                                return
                            }
                            Queue.mainQueue().async {
                                guard let interfaceState = self.presentationInterfaceState else {
                                    return
                                }
                                var timestamp: Double = 0.0
                                if let recordedMediaPreview = interfaceState.interfaceState.mediaDraftState, case let .audio(audio) = recordedMediaPreview, let trimRange = audio.trimRange {
                                    timestamp = trimRange.lowerBound
                                }
                                self.mediaPlayer?.seek(timestamp: timestamp, play: false)
                            }
                        }
                        self.mediaPlayer = mediaPlayer
                        self.playButtonNodeImpl.durationLabel.defaultDuration = Double(audio.duration)
                        self.playButtonNodeImpl.durationLabel.status = mediaPlayer.status
                        self.playButtonNodeImpl.durationLabel.trimRange = audio.trimRange
                        self.waveformScrubberNodeImpl.status = mediaPlayer.status
                        
                        self.statusDisposable.set((mediaPlayer.status
                        |> deliverOnMainQueue).startStrict(next: { [weak self] status in
                            if let self {
                                switch status.status {
                                case .playing, .buffering(_, true, _, _):
                                    self.statusValue = status
                                    if let recordedMediaPreview = self.presentationInterfaceState?.interfaceState.mediaDraftState, case let .audio(audio) = recordedMediaPreview, let _ = audio.trimRange {
                                        self.ensureHasTimer()
                                    }
                                    self.playButtonNodeImpl.playPauseIconNode.enqueueState(.pause, animated: true)
                                default:
                                    self.statusValue = nil
                                    self.stopTimer()
                                    self.playButtonNodeImpl.playPauseIconNode.enqueueState(.play, animated: true)
                                }
                            }
                        }))
                    }
                    
                    let minDuration = max(1.0, 56.0 * audio.duration / waveformBackgroundFrame.size.width)
                    let (leftHandleFrame, rightHandleFrame) = self.trimViewImpl.update(
                        style: .voiceMessage,
                        theme: interfaceState.theme,
                        visualInsets: .zero,
                        scrubberSize: waveformBackgroundFrame.size,
                        duration: audio.duration,
                        startPosition: audio.trimRange?.lowerBound ?? 0.0,
                        endPosition: audio.trimRange?.upperBound ?? Double(audio.duration),
                        position: 0.0,
                        minDuration: minDuration,
                        maxDuration: Double(audio.duration),
                        transition: .immediate
                    )
                    
                    let waveformForegroundFrame = CGRect(origin: CGPoint(x: 3.0 + leftHandleFrame.minX, y: 3.0), size: CGSize(width: rightHandleFrame.maxX - leftHandleFrame.minX, height: 40.0 - 3.0 * 2.0))
                    transition.updateFrame(node: self.waveformBackgroundNodeImpl, frame: waveformForegroundFrame)
                    
                    self.waveformNode.updateClipping(minX: leftHandleFrame.minX - 19.0, maxX: rightHandleFrame.maxX - 19.0, transition: transition)
                    
                    self.trimViewImpl.trimUpdated = { [weak self] start, end, updatedEnd, apply in
                        if let self {
                            self.mediaPlayer?.pause()
                            self.interfaceInteraction?.updateRecordingTrimRange(start, end, updatedEnd, apply)
                            if apply {
                                if !updatedEnd {
                                    self.mediaPlayer?.seek(timestamp: start, play: true)
                                } else {
                                    self.mediaPlayer?.seek(timestamp: max(0.0, end - 1.0), play: true)
                                }
                                self.playButtonNodeImpl.durationLabel.isScrubbing = false
                                Queue.mainQueue().after(0.1) {
                                    self.waveformForegroundNode.alpha = 1.0
                                }
                            } else {
                                self.playButtonNodeImpl.durationLabel.isScrubbing = true
                                self.waveformForegroundNode.alpha = 0.0
                            }
                            
                            let startFraction = start / Double(audio.duration)
                            let endFraction = end / Double(audio.duration)
                            self.waveformForegroundNode.trimRange = startFraction ..< endFraction
                        }
                    }
                    self.trimViewImpl.frame = waveformBackgroundFrame
                    self.trimViewImpl.isHidden = audio.duration < 2.0
                    
                    let playButtonSize = CGSize(width: max(0.0, rightHandleFrame.minX - leftHandleFrame.maxX), height: waveformBackgroundFrame.height)
                    self.playButtonNodeImpl.update(theme: interfaceState.theme, size: playButtonSize, transition: transition)
                    transition.updateFrame(node: self.playButtonNodeImpl, frame: CGRect(origin: CGPoint(x: waveformBackgroundFrame.minX + leftHandleFrame.maxX, y: waveformBackgroundFrame.minY), size: playButtonSize))
                case let .video(video):
                    self.waveformButton.isHidden = true
                    self.waveformBackgroundNodeImpl.isHidden = true
                    self.waveformForegroundNode.isHidden = true
                    self.waveformScrubberNodeImpl.isHidden = true
                    self.playButtonNodeImpl.isHidden = true
                    
                    let scrubberSize = self.scrubber.update(
                        transition: .immediate,
                        component: AnyComponent(
                            MediaScrubberComponent(
                                context: context,
                                style: .videoMessage,
                                theme: interfaceState.theme,
                                generationTimestamp: 0,
                                position: 0,
                                minDuration: 1.0,
                                maxDuration: 60.0,
                                isPlaying: false,
                                tracks: [
                                    MediaScrubberComponent.Track(
                                        id: 0,
                                        content: .video(frames: video.frames, framesUpdateTimestamp: video.framesUpdateTimestamp),
                                        duration: Double(video.duration),
                                        trimRange: video.trimRange,
                                        offset: nil,
                                        isMain: true
                                    )
                                ],
                                isCollage: false,
                                positionUpdated: { _, _ in },
                                trackTrimUpdated: { [weak self] _, start, end, updatedEnd, apply in
                                    if let self {
                                        self.interfaceInteraction?.updateRecordingTrimRange(start, end, updatedEnd, apply)
                                    }
                                },
                                trackOffsetUpdated: { _, _, _ in },
                                trackLongPressed: { _, _ in }
                            )
                        ),
                        environment: {},
                        forceUpdate: false,
                        containerSize: CGSize(width: waveformBackgroundFrame.width, height: 44.0)
                    )

                    if let view = self.scrubber.view {
                        if view.superview == nil {
                            self.view.addSubview(view)
                        }
                        view.frame = CGRect(origin: CGPoint(x: 3.0, y: 3.0), size: scrubberSize)
                    }
                }
            }
        }
                
        let panelHeight = 40.0
        
        transition.updateFrame(node: self.waveformButton, frame: waveformBackgroundFrame)
        
        let waveformScrubberFrame = CGRect(origin: CGPoint(x: 21.0, y: floor((40.0 - 13.0) / 2.0)), size: CGSize(width: width - 21.0 * 2.0, height: 13.0))
        transition.updateFrame(node: self.waveformScrubberNodeImpl, frame: waveformScrubberFrame)
        transition.updateFrame(node: self.tintWaveformNode, frame: waveformScrubberFrame)
        
        return panelHeight
    }
    
    override public func canHandleTransition(from prevInputPanelNode: ChatInputPanelNode?) -> Bool {
        return false
    }
    
    @objc private func deletePressed() {
        self.tooltipController?.dismiss()
        
        self.mediaPlayer?.pause()
        self.interfaceInteraction?.deleteRecordedMedia()
    }
    
    private weak var tooltipController: TooltipScreen?
    
    @objc private func recordMorePressed() {
        self.tooltipController?.dismiss()
        
        self.interfaceInteraction?.resumeMediaRecording()
    }
    
    /*private func displayViewOnceTooltip(text: String, hasIcon: Bool) {
        guard let context = self.context, let parentController = self.interfaceInteraction?.chatController() else {
            return
        }
        
        let absoluteFrame = self.viewOnceButton.view.convert(self.viewOnceButton.bounds, to: parentController.view)
        let location = CGRect(origin: CGPoint(x: absoluteFrame.midX - 20.0, y: absoluteFrame.midY), size: CGSize())
        
        let tooltipController = TooltipScreen(
            account: context.account,
            sharedContext: context.sharedContext,
            text: .markdown(text: text),
            balancedTextLayout: true,
            constrainWidth: 240.0,
            style: .customBlur(UIColor(rgb: 0x18181a), 0.0),
            arrowStyle: .small,
            icon: hasIcon ? .animation(name: "anim_autoremove_on", delay: 0.1, tintColor: nil) : nil,
            location: .point(location, .right),
            displayDuration: .default,
            inset: 8.0,
            cornerRadius: 8.0,
            shouldDismissOnTouch: { _, _ in
                return .ignore
            }
        )
        self.tooltipController = tooltipController
        
        parentController.present(tooltipController, in: .current)
    }*/
    
    @objc private func waveformPressed() {
        guard let mediaPlayer = self.mediaPlayer else {
            return
        }
        if let recordedMediaPreview = self.presentationInterfaceState?.interfaceState.mediaDraftState, case let .audio(audio) = recordedMediaPreview, let trimRange = audio.trimRange {
            let _ = (mediaPlayer.status
            |> map(Optional.init)
            |> timeout(0.3, queue: Queue.mainQueue(), alternate: .single(nil))
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] status in
                guard let self, let mediaPlayer = self.mediaPlayer else {
                    return
                }
                if let status {
                    if case .playing = status.status {
                        mediaPlayer.pause()
                    } else if status.timestamp <= trimRange.lowerBound {
                        mediaPlayer.seek(timestamp: trimRange.lowerBound, play: true)
                    } else {
                        mediaPlayer.play()
                    }
                } else {
                    mediaPlayer.seek(timestamp: trimRange.lowerBound, play: true)
                }
            })
        } else {
            mediaPlayer.togglePlayPause()
        }
    }
    
    override public func minimalHeight(interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        return defaultHeight(metrics: metrics)
    }
}

private enum PlayPauseIconNodeState: Equatable {
    case play
    case pause
}

private final class PlayPauseIconNode: ManagedAnimationNode {
    private let duration: Double = 0.35
    private var iconState: PlayPauseIconNodeState = .pause
    
    init() {
        super.init(size: CGSize(width: 21.0, height: 21.0))
        
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
