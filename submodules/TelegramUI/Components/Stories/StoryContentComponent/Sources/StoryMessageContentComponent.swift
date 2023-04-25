import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import TelegramCore
import AsyncDisplayKit
import PhotoResources
import SwiftSignalKit
import UniversalMediaPlayer
import TelegramUniversalVideoContent
import StoryContainerScreen
import HierarchyTrackingLayer

final class StoryMessageContentComponent: Component {
    typealias EnvironmentType = StoryContentItem.Environment
    
	let context: AccountContext
	let message: EngineMessage

	init(context: AccountContext, message: EngineMessage) {
		self.context = context
		self.message = message
	}

	static func ==(lhs: StoryMessageContentComponent, rhs: StoryMessageContentComponent) -> Bool {
		if lhs.context !== rhs.context {
			return false
		}
		if lhs.message != rhs.message {
			return false
		}
		return true
	}
    
    static func preload(context: AccountContext, message: EngineMessage) -> Signal<Never, NoError> {
        var messageMedia: EngineMedia?
        for media in message.media {
            switch media {
            case let image as TelegramMediaImage:
                messageMedia = .image(image)
            case let file as TelegramMediaFile:
                messageMedia = .file(file)
            default:
                break
            }
        }
        
        guard let messageMedia else {
            return .complete()
        }
        
        var fetchSignal: Signal<Never, NoError>?
        switch messageMedia {
        case let .image(image):
            if let representation = image.representations.last {
                fetchSignal = fetchedMediaResource(
                    mediaBox: context.account.postbox.mediaBox,
                    userLocation: .peer(message.id.peerId),
                    userContentType: .image,
                    reference: ImageMediaReference.message(message: MessageReference(message._asMessage()), media: image).resourceReference(representation.resource)
                )
                |> ignoreValues
                |> `catch` { _ -> Signal<Never, NoError> in
                    return .complete()
                }
            }
        case let .file(file):
            fetchSignal = fetchedMediaResource(
                mediaBox: context.account.postbox.mediaBox,
                userLocation: .peer(message.id.peerId),
                userContentType: .image,
                reference: FileMediaReference.message(message: MessageReference(message._asMessage()), media: file).resourceReference(file.resource)
            )
            |> ignoreValues
            |> `catch` { _ -> Signal<Never, NoError> in
                return .complete()
            }
        default:
            break
        }
        
        return fetchSignal ?? .complete()
    }

    final class View: StoryContentItem.View {
        private let imageNode: TransformImageNode
        private var videoNode: UniversalVideoNode?
        
        private var currentMessageMedia: EngineMedia?
        private var fetchDisposable: Disposable?
        
        private var component: StoryMessageContentComponent?
        private weak var state: EmptyComponentState?
        private var environment: StoryContentItem.Environment?
        
        private var isProgressPaused: Bool = false
        private var currentProgressTimer: SwiftSignalKit.Timer?
        private var currentProgressTimerValue: Double = 0.0
        private var videoProgressDisposable: Disposable?
        
        private var videoPlaybackStatus: MediaPlayerStatus?
        
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
                self.updateIsProgressPaused()
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
            guard let component = self.component, let currentMessageMedia = self.currentMessageMedia else {
                return
            }
            
            if case let .file(file) = currentMessageMedia {
                if self.videoNode == nil {
                    let videoNode = UniversalVideoNode(
                        postbox: component.context.account.postbox,
                        audioSession: component.context.sharedContext.mediaManager.audioSession,
                        manager: component.context.sharedContext.mediaManager.universalVideoManager,
                        decoration: StoryVideoDecoration(),
                        content: NativeVideoContent(
                            id: .message(component.message.stableId, file.fileId),
                            userLocation: .peer(component.message.id.peerId),
                            fileReference: .message(message: MessageReference(component.message._asMessage()), media: file),
                            imageReference: nil,
                            loopVideo: true,
                            enableSound: true,
                            tempFilePath: nil,
                            captureProtected: component.message._asMessage().isCopyProtected(),
                            storeAfterDownload: nil
                        ),
                        priority: .gallery
                    )
                    
                    self.videoNode = videoNode
                    self.addSubnode(videoNode)
                    
                    videoNode.ownsContentNodeUpdated = { [weak self] value in
                        guard let self else {
                            return
                        }
                        if value {
                            self.videoNode?.seek(0.0)
                            self.videoNode?.playOnceWithSound(playAndRecord: false)
                        }
                    }
                    videoNode.canAttachContent = true
                    if update {
                        self.state?.updated(transition: .immediate)
                    }
                }
            }
        }
        
        override func setIsProgressPaused(_ isProgressPaused: Bool) {
            if self.isProgressPaused != isProgressPaused {
                self.isProgressPaused = isProgressPaused
                self.updateIsProgressPaused()
            }
        }
        
        private func updateIsProgressPaused() {
            if let videoNode = self.videoNode {
                if !self.isProgressPaused && self.hierarchyTrackingLayer.isInHierarchy {
                    videoNode.play()
                } else {
                    videoNode.pause()
                }
            }
            
            self.updateVideoPlaybackProgress()
            self.updateProgressTimer()
        }
        
        private func updateProgressTimer() {
            let needsTimer = !self.isProgressPaused && self.hierarchyTrackingLayer.isInHierarchy
            
            if needsTimer {
                if self.currentProgressTimer == nil {
                    self.currentProgressTimer = SwiftSignalKit.Timer(
                        timeout: 1.0 / 60.0,
                        repeat: true,
                        completion: { [weak self] in
                            guard let self, !self.isProgressPaused, self.hierarchyTrackingLayer.isInHierarchy else {
                                return
                            }
                            
                            if self.videoNode != nil {
                                self.updateVideoPlaybackProgress()
                            } else {
                                let currentProgressTimerLimit: Double = 5.0
                                var currentProgressTimerValue = self.currentProgressTimerValue + 1.0 / 60.0
                                currentProgressTimerValue = max(0.0, min(currentProgressTimerLimit, currentProgressTimerValue))
                                self.currentProgressTimerValue = currentProgressTimerValue
                                
                                self.environment?.presentationProgressUpdated(currentProgressTimerValue / currentProgressTimerLimit)
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
            var isPlaying = false
            var timestampAndDuration: (timestamp: Double?, duration: Double)?
            if let videoPlaybackStatus = self.videoPlaybackStatus {
                switch videoPlaybackStatus.status {
                case .playing:
                    isPlaying = true
                default:
                    break
                }
                if case .buffering(true, _, _, _) = videoPlaybackStatus.status {
                    timestampAndDuration = (nil, videoPlaybackStatus.duration)
                } else if Double(0.0).isLess(than: videoPlaybackStatus.duration) {
                    timestampAndDuration = (videoPlaybackStatus.timestamp, videoPlaybackStatus.duration)
                }
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
            }
            
            let clippedProgress = max(0.0, min(1.0, currentProgress))
            self.environment?.presentationProgressUpdated(clippedProgress)
        }
        
        func update(component: StoryMessageContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<StoryContentItem.Environment>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            self.environment = environment[StoryContentItem.Environment.self].value
            
            var messageMedia: EngineMedia?
            for media in component.message.media {
                switch media {
                case let image as TelegramMediaImage:
                    messageMedia = .image(image)
                case let file as TelegramMediaFile:
                    messageMedia = .file(file)
                default:
                    break
                }
            }
            
            var reloadMedia = false
            if self.currentMessageMedia?.id != messageMedia?.id {
                self.currentMessageMedia = messageMedia
                reloadMedia = true
            }
            
            if reloadMedia, let messageMedia {
                var signal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
                var fetchSignal: Signal<Never, NoError>?
                switch messageMedia {
                case let .image(image):
                    signal = chatMessagePhoto(
                        postbox: component.context.account.postbox,
                        userLocation: .peer(component.message.id.peerId),
                        photoReference: .message(message: MessageReference(component.message._asMessage()), media: image),
                        synchronousLoad: true,
                        highQuality: true
                    )
                    if let representation = image.representations.last {
                        fetchSignal = fetchedMediaResource(
                            mediaBox: component.context.account.postbox.mediaBox,
                            userLocation: .peer(component.message.id.peerId),
                            userContentType: .image,
                            reference: ImageMediaReference.message(message: MessageReference(component.message._asMessage()), media: image).resourceReference(representation.resource)
                        )
                        |> ignoreValues
                        |> `catch` { _ -> Signal<Never, NoError> in
                            return .complete()
                        }
                    }
                case let .file(file):
                    signal = chatMessageVideo(
                        postbox: component.context.account.postbox,
                        userLocation: .peer(component.message.id.peerId),
                        videoReference: .message(message: MessageReference(component.message._asMessage()), media: file),
                        synchronousLoad: true
                    )
                    fetchSignal = fetchedMediaResource(
                        mediaBox: component.context.account.postbox.mediaBox,
                        userLocation: .peer(component.message.id.peerId),
                        userContentType: .image,
                        reference: FileMediaReference.message(message: MessageReference(component.message._asMessage()), media: file).resourceReference(file.resource)
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
                
                self.fetchDisposable?.dispose()
                self.fetchDisposable = nil
                if let fetchSignal {
                    self.fetchDisposable = fetchSignal.start()
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
                    let apply = self.imageNode.asyncLayout()(TransformImageArguments(
                        corners: ImageCorners(),
                        imageSize: dimensions.aspectFilled(availableSize),
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
            self.updateProgressTimer()
            
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
