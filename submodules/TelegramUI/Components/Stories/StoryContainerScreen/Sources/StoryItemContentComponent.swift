import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import TelegramCore
import Postbox
import AsyncDisplayKit
import PhotoResources
import SwiftSignalKit
import UniversalMediaPlayer
import TelegramUniversalVideoContent
import HierarchyTrackingLayer
import ButtonComponent
import MultilineTextComponent
import TelegramPresentationData

final class StoryItemContentComponent: Component {
    typealias EnvironmentType = StoryContentItem.Environment
    
    final class Hint {
        let synchronousLoad: Bool
        
        init(synchronousLoad: Bool) {
            self.synchronousLoad = synchronousLoad
        }
    }
    
	let context: AccountContext
    let peer: EnginePeer
    let item: EngineStoryItem

    init(context: AccountContext, peer: EnginePeer, item: EngineStoryItem) {
		self.context = context
        self.peer = peer
		self.item = item
	}

	static func ==(lhs: StoryItemContentComponent, rhs: StoryItemContentComponent) -> Bool {
		if lhs.context !== rhs.context {
			return false
		}
        if lhs.peer != rhs.peer {
            return false
        }
		if lhs.item != rhs.item {
			return false
		}
		return true
	}

    final class View: StoryContentItem.View {
        private let imageNode: TransformImageNode
        private var videoNode: UniversalVideoNode?
        
        private var currentMessageMedia: EngineMedia?
        private var fetchDisposable: Disposable?
        
        private var component: StoryItemContentComponent?
        private weak var state: EmptyComponentState?
        private var environment: StoryContentItem.Environment?
        
        private var unsupportedText: ComponentView<Empty>?
        private var unsupportedButton: ComponentView<Empty>?
        
        private var isProgressPaused: Bool = true
        private var currentProgressTimer: SwiftSignalKit.Timer?
        private var currentProgressTimerValue: Double = 0.0
        private var videoProgressDisposable: Disposable?
        
        private var markedAsSeen: Bool = false
        private var contentLoaded: Bool = false
        
        private var videoPlaybackStatus: MediaPlayerStatus?
        override var videoPlaybackPosition: Double? {
            return self.videoPlaybackStatus?.timestamp
        }
        
        private let hierarchyTrackingLayer: HierarchyTrackingLayer
        
		override init(frame: CGRect) {
            self.hierarchyTrackingLayer = HierarchyTrackingLayer()
            self.imageNode = TransformImageNode()
            
			super.init(frame: frame)
            
            self.layer.addSublayer(self.hierarchyTrackingLayer)
            
            self.addSubnode(self.imageNode)
            
            self.hierarchyTrackingLayer.isInHierarchyUpdated = { [weak self] value in
                guard let self else {
                    return
                }
                self.updateIsProgressPaused(update: true)
            }
		}
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.fetchDisposable?.dispose()
            self.currentProgressTimer?.invalidate()
            self.videoProgressDisposable?.dispose()
        }
        
        private func performActionAfterImageContentLoaded(update: Bool) {
            self.initializeVideoIfReady(update: update)
        }
        
        private func initializeVideoIfReady(update: Bool) {
            if self.videoNode != nil {
                return
            }
            if self.isProgressPaused {
                return
            }
            
            guard let component = self.component, let environment = self.environment, let currentMessageMedia = self.currentMessageMedia else {
                return
            }
            
            if case let .file(file) = currentMessageMedia, let peerReference = PeerReference(component.peer._asPeer()) {
                if self.videoNode == nil {
                    let videoNode = UniversalVideoNode(
                        postbox: component.context.account.postbox,
                        audioSession: component.context.sharedContext.mediaManager.audioSession,
                        manager: component.context.sharedContext.mediaManager.universalVideoManager,
                        decoration: StoryVideoDecoration(),
                        content: NativeVideoContent(
                            id: .message(0, file.fileId),
                            userLocation: .other,
                            fileReference: .story(peer: peerReference, id: component.item.id, media: file),
                            imageReference: nil,
                            streamVideo: .story,
                            loopVideo: true,
                            enableSound: true,
                            beginWithAmbientSound: environment.sharedState.useAmbientMode,
                            useLargeThumbnail: true,
                            autoFetchFullSizeThumbnail: true,
                            tempFilePath: nil,
                            captureProtected: component.item.isForwardingDisabled,
                            hintDimensions: file.dimensions?.cgSize,
                            storeAfterDownload: nil,
                            displayImage: false
                        ),
                        priority: .gallery
                    )
                    
                    self.videoNode = videoNode
                    self.addSubnode(videoNode)
                    
                    videoNode.playbackCompleted = { [weak self] in
                        guard let self else {
                            return
                        }
                        self.environment?.presentationProgressUpdated(1.0, true)
                    }
                    videoNode.ownsContentNodeUpdated = { [weak self] value in
                        guard let self else {
                            return
                        }
                        if value {
                            self.videoNode?.seek(0.0)
                            self.videoNode?.playOnceWithSound(playAndRecord: false, actionAtEnd: .stop)
                        }
                    }
                    videoNode.canAttachContent = true
                    if update {
                        self.state?.updated(transition: .immediate)
                    }
                }
            }
            
            if let videoNode = self.videoNode {
                if self.videoProgressDisposable == nil {
                    self.videoProgressDisposable = (videoNode.status
                    |> deliverOnMainQueue).start(next: { [weak self] status in
                        guard let self, let status else {
                            return
                        }
                        
                        self.videoPlaybackStatus = status
                        self.updateVideoPlaybackProgress()
                    })
                }
            }
        }
        
        override func setIsProgressPaused(_ isProgressPaused: Bool) {
            if self.isProgressPaused != isProgressPaused {
                self.isProgressPaused = isProgressPaused
                self.updateIsProgressPaused(update: true)
            }
        }
        
        override func rewind() {
            self.currentProgressTimerValue = 0.0
            if let videoNode = self.videoNode {
                if self.contentLoaded {
                    videoNode.seek(0.0)
                }
            }
        }
        
        override func leaveAmbientMode() {
            if let videoNode = self.videoNode {
                videoNode.setSoundEnabled(true)
                videoNode.continueWithOverridingAmbientMode()
            }
        }
        
        override func enterAmbientMode() {
            if let videoNode = self.videoNode {
                videoNode.setSoundEnabled(false)
            }
        }
        
        private func updateIsProgressPaused(update: Bool) {
            if let videoNode = self.videoNode {
                var canPlay = !self.isProgressPaused && self.contentLoaded && self.hierarchyTrackingLayer.isInHierarchy
                if let component = self.component {
                    if component.item.isPending {
                        canPlay = false
                    }
                }
                
                if canPlay {
                    videoNode.play()
                } else {
                    videoNode.pause()
                }
            }
            
            self.initializeVideoIfReady(update: update)
            self.updateVideoPlaybackProgress()
            self.updateProgressTimer()
        }
        
        private func updateProgressTimer() {
            var needsTimer = !self.isProgressPaused && self.contentLoaded && self.hierarchyTrackingLayer.isInHierarchy
            if let component = self.component {
                if component.item.isPending {
                    needsTimer = false
                }
            }
            
            if needsTimer {
                if self.currentProgressTimer == nil {
                    self.currentProgressTimer = SwiftSignalKit.Timer(
                        timeout: 1.0 / 60.0,
                        repeat: true,
                        completion: { [weak self] in
                            guard let self, !self.isProgressPaused, self.contentLoaded, self.hierarchyTrackingLayer.isInHierarchy else {
                                return
                            }
                            
                            if case .file = self.currentMessageMedia {
                                self.updateVideoPlaybackProgress()
                            } else {
                                if !self.markedAsSeen {
                                    self.markedAsSeen = true
                                    if let component = self.component {
                                        self.environment?.markAsSeen(StoryId(peerId: component.peer.id, id: component.item.id))
                                    }
                                }
                                
                                #if DEBUG && true
                                let currentProgressTimerLimit: Double = 10.0
                                #else
                                let currentProgressTimerLimit: Double = 5.0
                                #endif
                                
                                var currentProgressTimerValue = self.currentProgressTimerValue + 1.0 / 60.0
                                currentProgressTimerValue = max(0.0, min(currentProgressTimerLimit, currentProgressTimerValue))
                                self.currentProgressTimerValue = currentProgressTimerValue
                                
                                self.environment?.presentationProgressUpdated(currentProgressTimerValue / currentProgressTimerLimit, true)
                            }
                        }, queue: .mainQueue()
                    )
                    self.currentProgressTimer?.start()
                }
            } else {
                if let currentProgressTimer = self.currentProgressTimer {
                    self.currentProgressTimer = nil
                    currentProgressTimer.invalidate()
                }
            }
        }
        
        private func updateVideoPlaybackProgress() {
            guard let videoPlaybackStatus = self.videoPlaybackStatus else {
                return
            }
            var isPlaying = false
            var timestampAndDuration: (timestamp: Double?, duration: Double)?
            switch videoPlaybackStatus.status {
            case .playing:
                isPlaying = true
            default:
                break
            }
            
            let effectiveDuration: Double
            if videoPlaybackStatus.duration > 0.0 {
                effectiveDuration = videoPlaybackStatus.duration
            } else if case let .file(file) = self.currentMessageMedia, let duration = file.duration {
                effectiveDuration = Double(max(1, duration))
            } else {
                effectiveDuration = 1.0
            }
            
            if case .buffering(true, _, _, _) = videoPlaybackStatus.status {
                timestampAndDuration = (nil, effectiveDuration)
            } else if effectiveDuration > 0.0 {
                timestampAndDuration = (videoPlaybackStatus.timestamp, effectiveDuration)
            }
            
            var currentProgress: Double = 0.0
            
            if let (maybeTimestamp, duration) = timestampAndDuration, let timestamp = maybeTimestamp, duration > 0.01, let videoPlaybackStatus = self.videoPlaybackStatus {
                var actualTimestamp: Double
                if videoPlaybackStatus.generationTimestamp.isZero || !isPlaying {
                    actualTimestamp = timestamp
                } else {
                    let currentTimestamp = CACurrentMediaTime()
                    actualTimestamp = timestamp + (currentTimestamp - videoPlaybackStatus.generationTimestamp) * videoPlaybackStatus.baseRate
                }
                
                var progress = CGFloat(actualTimestamp / duration)
                if progress.isNaN || !progress.isFinite {
                    progress = 0.0
                }
                progress = min(1.0, progress)
                
                currentProgress = progress
                
                if isPlaying {
                    if !self.markedAsSeen {
                        self.markedAsSeen = true
                        if let component = self.component {
                            self.environment?.markAsSeen(StoryId(peerId: component.peer.id, id: component.item.id))
                        }
                    }
                }
            }
            
            let clippedProgress = max(0.0, min(1.0, currentProgress))
            self.environment?.presentationProgressUpdated(clippedProgress, false)
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if let unsupportedButtonView = self.unsupportedButton?.view {
                if let result = unsupportedButtonView.hitTest(self.convert(point, to: unsupportedButtonView), with: event) {
                    return result
                }
            }
            return nil
        }
        
        func update(component: StoryItemContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<StoryContentItem.Environment>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            let environment = environment[StoryContentItem.Environment.self].value
            self.environment = environment
            
            var synchronousLoad = false
            if let hint = transition.userData(Hint.self) {
                synchronousLoad = hint.synchronousLoad
            }
            
            let peerReference = PeerReference(component.peer._asPeer())
            
            var messageMedia: EngineMedia?
            switch component.item.media {
            case let .image(image):
                messageMedia = .image(image)
            case let .file(file):
                messageMedia = .file(file)
            case .unsupported:
                self.contentLoaded = true
            default:
                break
            }
            
            var reloadMedia = false
            if self.currentMessageMedia?.id != messageMedia?.id {
                self.currentMessageMedia = messageMedia
                reloadMedia = true
                
                if let videoNode = self.videoNode {
                    self.videoNode = nil
                    videoNode.view.removeFromSuperview()
                }
            }
            
            if reloadMedia, let messageMedia, let peerReference {
                var signal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
                var fetchSignal: Signal<Never, NoError>?
                switch messageMedia {
                case let .image(image):
                    signal = chatMessagePhoto(
                        postbox: component.context.account.postbox,
                        userLocation: .other,
                        photoReference: .story(peer: peerReference, id: component.item.id, media: image),
                        synchronousLoad: synchronousLoad,
                        highQuality: true
                    )
                    if let representation = image.representations.last {
                        fetchSignal = fetchedMediaResource(
                            mediaBox: component.context.account.postbox.mediaBox,
                            userLocation: .other,
                            userContentType: .image,
                            reference: ImageMediaReference.story(peer: peerReference, id: component.item.id, media: image).resourceReference(representation.resource)
                        )
                        |> ignoreValues
                        |> `catch` { _ -> Signal<Never, NoError> in
                            return .complete()
                        }
                    }
                case let .file(file):
                    self.contentLoaded = true
                    
                    signal = mediaGridMessageVideo(
                        postbox: component.context.account.postbox,
                        userLocation: .other,
                        videoReference: .story(peer: peerReference, id: component.item.id, media: file),
                        onlyFullSize: false,
                        useLargeThumbnail: true,
                        synchronousLoad: synchronousLoad,
                        autoFetchFullSizeThumbnail: true,
                        overlayColor: nil,
                        nilForEmptyResult: false,
                        useMiniThumbnailIfAvailable: false,
                        blurred: false
                    )
                    fetchSignal = fetchedMediaResource(
                        mediaBox: component.context.account.postbox.mediaBox,
                        userLocation: .other,
                        userContentType: .image,
                        reference: FileMediaReference.story(peer: peerReference, id: component.item.id, media: file).resourceReference(file.resource)
                    )
                    |> ignoreValues
                    |> `catch` { _ -> Signal<Never, NoError> in
                        return .complete()
                    }
                default:
                    break
                }
                
                if let signal {
                    var wasSynchronous = true
                    self.imageNode.setSignal(signal |> afterCompleted { [weak self] in
                        Queue.mainQueue().async {
                            guard let self else {
                                return
                            }
                            
                            self.performActionAfterImageContentLoaded(update: !wasSynchronous)
                        }
                    }, attemptSynchronously: true)
                    wasSynchronous = false
                }
                
                self.performActionAfterImageContentLoaded(update: false)
                
                self.fetchDisposable?.dispose()
                self.fetchDisposable = nil
                if let fetchSignal {
                    self.fetchDisposable = (fetchSignal |> deliverOnMainQueue).start(completed: { [weak self] in
                        guard let self else {
                            return
                        }
                        if !self.contentLoaded {
                            self.contentLoaded = true
                            self.state?.updated(transition: .immediate)
                        }
                    })
                }
            }
            
            if let messageMedia {
                var dimensions: CGSize?
                switch messageMedia {
                case let .image(image):
                    dimensions = image.representations.last?.dimensions.cgSize
                case let .file(file):
                    dimensions = file.dimensions?.cgSize
                default:
                    break
                }
                
                if let dimensions {
                    var imageSize = dimensions.aspectFilled(availableSize)
                    if imageSize.width < availableSize.width && imageSize.width >= availableSize.width - 5.0 {
                        imageSize.width = availableSize.width
                    }
                    if imageSize.height < availableSize.height && imageSize.height >= availableSize.height - 5.0 {
                        imageSize.height = availableSize.height
                    }
                    self.imageNode.captureProtected = component.item.isForwardingDisabled
                    let apply = self.imageNode.asyncLayout()(TransformImageArguments(
                        corners: ImageCorners(),
                        imageSize: imageSize,
                        boundingSize: availableSize,
                        intrinsicInsets: UIEdgeInsets()
                    ))
                    apply()
                    
                    if let videoNode = self.videoNode {
                        let videoSize = dimensions.aspectFilled(availableSize)
                        videoNode.frame = CGRect(origin: CGPoint(x: floor((availableSize.width - videoSize.width) * 0.5), y: floor((availableSize.height - videoSize.height) * 0.5)), size: videoSize)
                        videoNode.updateLayout(size: videoSize, transition: .immediate)
                    }
                }
                self.imageNode.frame = CGRect(origin: CGPoint(), size: availableSize)
            }
            
            switch component.item.media {
            case .image, .file:
                if let unsupportedText = self.unsupportedText {
                    self.unsupportedText = nil
                    unsupportedText.view?.removeFromSuperview()
                }
                if let unsupportedButton = self.unsupportedButton {
                    self.unsupportedButton = nil
                    unsupportedButton.view?.removeFromSuperview()
                }
                
                self.backgroundColor = .black
            default:
                var unsuportedTransition = transition
                
                let unsupportedText: ComponentView<Empty>
                if let current = self.unsupportedText {
                    unsupportedText = current
                } else {
                    unsuportedTransition = .immediate
                    unsupportedText = ComponentView()
                    self.unsupportedText = unsupportedText
                }
                
                let unsupportedButton: ComponentView<Empty>
                if let current = self.unsupportedButton {
                    unsupportedButton = current
                } else {
                    unsuportedTransition = .immediate
                    unsupportedButton = ComponentView()
                    self.unsupportedButton = unsupportedButton
                }
                
                //TODO:localize
                let unsupportedTextSize = unsupportedText.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: "This story is not supported by\nyour version of Telegram.", font: Font.regular(17.0), textColor: .white)),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - 16.0 * 2.0, height: availableSize.height)
                )
                let unsupportedButtonSize = unsupportedButton.update(
                    transition: unsuportedTransition,
                    component: AnyComponent(ButtonComponent(
                        background: ButtonComponent.Background(
                            color: environment.theme.list.itemCheckColors.fillColor,
                            foreground: environment.theme.list.itemCheckColors.foregroundColor,
                            pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.7)
                        ),
                        content: AnyComponentWithIdentity(id: AnyHashable(""), component: AnyComponent(Text(text: "Update Telegram", font: Font.semibold(17.0), color: environment.theme.list.itemCheckColors.foregroundColor
                        ))),
                        isEnabled: true,
                        displaysProgress: false,
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.context.sharedContext.applicationBindings.openAppStorePage()
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: 240.0, height: 50.0)
                )
                
                let spacing: CGFloat = 24.0
                let contentHeight = unsupportedTextSize.height + unsupportedButtonSize.height + spacing
                var contentY = floor((availableSize.height - contentHeight) * 0.5)
                
                let unsupportedTextFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - unsupportedTextSize.width) * 0.5), y: contentY), size: unsupportedTextSize)
                contentY += unsupportedTextSize.height + spacing
                
                let unsupportedButtonFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - unsupportedButtonSize.width) * 0.5), y: contentY), size: unsupportedButtonSize)
                
                if let unsupportedTextView = unsupportedText.view {
                    if unsupportedTextView.superview == nil {
                        self.addSubview(unsupportedTextView)
                    }
                    unsuportedTransition.setPosition(view: unsupportedTextView, position: unsupportedTextFrame.center)
                    unsupportedTextView.bounds = CGRect(origin: CGPoint(), size: unsupportedTextFrame.size)
                }
                if let unsupportedButtonView = unsupportedButton.view {
                    if unsupportedButtonView.superview == nil {
                        self.addSubview(unsupportedButtonView)
                    }
                    unsuportedTransition.setFrame(view: unsupportedButtonView, frame: unsupportedButtonFrame)
                }
                
                self.backgroundColor = UIColor(rgb: 0x181818)
            }
            
            self.updateIsProgressPaused(update: false)
            
            return availableSize
        }
	}

	func makeView() -> View {
		return View(frame: CGRect())
	}

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<StoryContentItem.Environment>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
