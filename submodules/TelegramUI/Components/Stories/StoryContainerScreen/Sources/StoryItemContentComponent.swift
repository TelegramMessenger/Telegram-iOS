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
import TelegramCallsUI

final class StoryItemContentComponent: Component {
    typealias EnvironmentType = StoryContentItem.Environment
    
    final class Hint {
        let synchronousLoad: Bool
        
        init(synchronousLoad: Bool) {
            self.synchronousLoad = synchronousLoad
        }
    }
    
	let context: AccountContext
    let strings: PresentationStrings
    let peer: EnginePeer
    let item: EngineStoryItem
    let availableReactions: StoryAvailableReactions?
    let entityFiles: [MediaId: TelegramMediaFile]
    let audioMode: StoryContentItem.AudioMode
    let baseRate: Double
    let isVideoBuffering: Bool
    let isCurrent: Bool
    let isUIHidden: Bool
    let preferHighQuality: Bool
    let isEmbeddedInCamera: Bool
    let canManageLiveChatMessagesFromPeers: Set<EnginePeer.Id>
    let activateReaction: (UIView, MessageReaction.Reaction) -> Void
    let controller: () -> ViewController?
    
    init(context: AccountContext, strings: PresentationStrings, peer: EnginePeer, item: EngineStoryItem, availableReactions: StoryAvailableReactions?, entityFiles: [MediaId: TelegramMediaFile], audioMode: StoryContentItem.AudioMode, baseRate: Double, isVideoBuffering: Bool, isCurrent: Bool, isUIHidden: Bool, preferHighQuality: Bool, isEmbeddedInCamera: Bool, canManageLiveChatMessagesFromPeers: Set<EnginePeer.Id>, activateReaction: @escaping (UIView, MessageReaction.Reaction) -> Void, controller: @escaping () -> ViewController?) {
		self.context = context
        self.strings = strings
        self.peer = peer
		self.item = item
        self.entityFiles = entityFiles
        self.availableReactions = availableReactions
        self.audioMode = audioMode
        self.baseRate = baseRate
        self.isVideoBuffering = isVideoBuffering
        self.isCurrent = isCurrent
        self.isUIHidden = isUIHidden
        self.preferHighQuality = preferHighQuality
        self.isEmbeddedInCamera = isEmbeddedInCamera
        self.canManageLiveChatMessagesFromPeers = canManageLiveChatMessagesFromPeers
        self.activateReaction = activateReaction
        self.controller = controller
	}

	static func ==(lhs: StoryItemContentComponent, rhs: StoryItemContentComponent) -> Bool {
		if lhs.context !== rhs.context {
			return false
		}
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
		if lhs.item != rhs.item {
			return false
		}
        if lhs.availableReactions != rhs.availableReactions {
            return false
        }
        if lhs.entityFiles.keys != rhs.entityFiles.keys {
            return false
        }
        if lhs.baseRate != rhs.baseRate {
            return false
        }
        if lhs.isVideoBuffering != rhs.isVideoBuffering {
            return false
        }
        if lhs.isCurrent != rhs.isCurrent {
            return false
        }
        if lhs.isUIHidden != rhs.isUIHidden {
            return false
        }
        if lhs.isEmbeddedInCamera != rhs.isEmbeddedInCamera {
            return false
        }
        if lhs.canManageLiveChatMessagesFromPeers != rhs.canManageLiveChatMessagesFromPeers {
            return false
        }
        if lhs.preferHighQuality != rhs.preferHighQuality {
            return false
        }
		return true
	}
    
    struct StarStats {
        var myStars: Int64
        var pendingMyStars: Int64
        var totalStars: Int64
        var topItems: [GroupCallMessagesContext.TopStarsItem]
        
        init(myStars: Int64, pendingMyStars: Int64, totalStars: Int64, topItems: [GroupCallMessagesContext.TopStarsItem]) {
            self.myStars = myStars
            self.pendingMyStars = pendingMyStars
            self.totalStars = totalStars
            self.topItems = topItems
        }
    }
    
    struct LiveChatState {
        var isExpanded: Bool
        var isEmpty: Bool
        var hasUnseenMessages: Bool
        var areMessagesEnabled: Bool
        var minMessagePrice: Int64?
        var starStats: StarStats?
        var isAdmin: Bool
        var defaultSendAs: EnginePeer.Id?
        var isUnifiedStream: Bool
        
        init(isExpanded: Bool, isEmpty: Bool, hasUnseenMessages: Bool, areMessagesEnabled: Bool, minMessagePrice: Int64?, starStats: StarStats?, isAdmin: Bool, defaultSendAs: EnginePeer.Id?, isUnifiedStream: Bool) {
            self.isExpanded = isExpanded
            self.isEmpty = isEmpty
            self.hasUnseenMessages = hasUnseenMessages
            self.areMessagesEnabled = areMessagesEnabled
            self.minMessagePrice = minMessagePrice
            self.starStats = starStats
            self.isAdmin = isAdmin
            self.defaultSendAs = defaultSendAs
            self.isUnifiedStream = isUnifiedStream
        }
    }
    
    private struct MediaStreamCallState: Equatable {
        var areMessagesEnabled: Bool
        var minMessagePrice: Int64?
        var isAdmin: Bool
        var defaultSendAs: EnginePeer.Id?
        var isUnifiedStream: Bool
        
        init(areMessagesEnabled: Bool, minMessagePrice: Int64?, isAdmin: Bool, defaultSendAs: EnginePeer.Id?, isUnifiedStream: Bool) {
            self.areMessagesEnabled = areMessagesEnabled
            self.minMessagePrice = minMessagePrice
            self.isAdmin = isAdmin
            self.defaultSendAs = defaultSendAs
            self.isUnifiedStream = isUnifiedStream
        }
    }
    
    private struct MediaStreamCallVideoState: Equatable {
        var videoEndpointId: String?
        
        init(videoEndpointId: String?) {
            self.videoEndpointId = videoEndpointId
        }
    }

    final class View: StoryContentItem.View {
        private let imageView: StoryItemImageView
        private let overlaysView: StoryItemOverlaysView
        private var videoNode: UniversalVideoNode?
        private(set) var mediaStreamCall: PresentationGroupCallImpl?
        private var mediaStreamCallState: MediaStreamCallState?
        private var mediaStreamCallVideoState: MediaStreamCallVideoState?
        private var liveCallStateDisposable: Disposable?
        private var liveCallStatsDisposable: Disposable?
        private var mediaStream: ComponentView<Empty>?
        private let activatePictureInPictureAction = ActionSlot<Action<Void>>()
        private let deactivatePictureInPictureAction = ActionSlot<Void>()
        private var restorePictureInPicture: ((@escaping () -> Void) -> Void)?
        private var dismissWhileInPictureInPicture: (() -> Void)?
        private var loadingEffectView: StoryItemLoadingEffectView?
        private var loadingEffectAppearanceTimer: SwiftSignalKit.Timer?
        
        private let liveChatExternal = StoryContentLiveChatComponent.External()
        private var liveChat: ComponentView<Empty>?
        
        private var mediaAreasEffectView: StoryItemLoadingEffectView?
        
        private var currentMessageMedia: EngineMedia?
        private var currentMessageMetadataMedia: EngineMedia?
        private var fetchDisposable: Disposable?
        private var priorityDisposable: Disposable?
        
        private var component: StoryItemContentComponent?
        private weak var state: EmptyComponentState?
        private var environment: StoryContentItem.Environment?
        private var isUpdating: Bool = false
        
        private var unsupportedText: ComponentView<Empty>?
        private var unsupportedButton: ComponentView<Empty>?
        
        private var progressMode: (mode: StoryContentItem.ProgressMode, isCentral: Bool) = (.pause, false)
        private var currentProgressTimer: SwiftSignalKit.Timer?
        private var currentProgressTimerValue: Double = 0.0
        private var videoProgressDisposable: Disposable?
        
        private var ignoreBufferingTimestamp: Double = 0.0
        
        private var markedAsSeen: Bool = false
        private var contentLoaded: Bool = false
        
        private var videoPlaybackStatus: MediaPlayerStatus?
        override var videoPlaybackPosition: Double? {
            return self.videoPlaybackStatus?.timestamp
        }
        
        var customSubtitle: String?

        private let hierarchyTrackingLayer: HierarchyTrackingLayer
        
        private var fetchPriorityResourceId: String?
        private var currentFetchPriority: (isMain: Bool, disposable: Disposable)?
        
        public var liveChatState: LiveChatState? {
            guard let liveChatView = self.liveChat?.view as? StoryContentLiveChatComponent.View else {
                return nil
            }
            
            let currentInfo = liveChatView.currentInfo
            let mediaStreamCallState = self.mediaStreamCallState
            
            let starStats = currentInfo.starStats.flatMap { starStats in
                return StarStats(
                    myStars: starStats.myStars,
                    pendingMyStars: starStats.pendingMyStars,
                    totalStars: starStats.totalStars,
                    topItems: starStats.topItems
                )
            }
            
            return LiveChatState(
                isExpanded: currentInfo.isChatExpanded,
                isEmpty: self.liveChatExternal.isEmpty,
                hasUnseenMessages: self.liveChatExternal.hasUnseenMessages,
                areMessagesEnabled: mediaStreamCallState?.areMessagesEnabled ?? false,
                minMessagePrice: mediaStreamCallState?.minMessagePrice,
                starStats: starStats,
                isAdmin: mediaStreamCallState?.isAdmin ?? false,
                defaultSendAs: mediaStreamCallState?.defaultSendAs,
                isUnifiedStream: mediaStreamCallState?.isUnifiedStream ?? false
            )
        }
        
        public func toggleLiveChatExpanded() {
            guard let liveChatView = self.liveChat?.view as? StoryContentLiveChatComponent.View else {
                return
            }
            return liveChatView.toggleLiveChatExpanded()
        }
        
		override init(frame: CGRect) {
            self.hierarchyTrackingLayer = HierarchyTrackingLayer()
            self.imageView = StoryItemImageView()
            self.overlaysView = StoryItemOverlaysView()
            
			super.init(frame: frame)
            
            self.layer.addSublayer(self.hierarchyTrackingLayer)
            
            self.addSubview(self.imageView)
            self.addSubview(self.overlaysView)
            
            self.hierarchyTrackingLayer.isInHierarchyUpdated = { [weak self] value in
                guard let self else {
                    return
                }
                self.updateProgressMode(update: true)
            }
            
            self.overlaysView.activate = { [weak self] view, reaction in
                guard let self, let component = self.component else {
                    return
                }
                component.activateReaction(view, reaction)
            }
            self.overlaysView.requestUpdate = { [weak self] in
                guard let self else {
                    return
                }
                self.state?.updated(transition: .immediate, isLocal: true)
            }
		}
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.fetchDisposable?.dispose()
            self.priorityDisposable?.dispose()
            self.currentProgressTimer?.invalidate()
            self.videoProgressDisposable?.dispose()
            self.currentFetchPriority?.disposable.dispose()
            self.liveCallStateDisposable?.dispose()
            self.liveCallStatsDisposable?.dispose()
        }
        
        func allowsInstantPauseOnTouch(point: CGPoint) -> Bool {
            if let _ = self.overlaysView.hitTest(self.convert(self.convert(point, to: self.overlaysView), to: self.overlaysView), with: nil) {
                return false
            }
            if self.liveChat != nil {
                return false
            }
            return true
        }
        
        private func performActionAfterImageContentLoaded(update: Bool) {
            self.initializeVideoIfReady(update: update)
        }
        
        private func initializeVideoIfReady(update: Bool) {
            if self.videoNode != nil {
                return
            }
            if case .pause = self.progressMode.mode {
                return
            }
            
            guard let component = self.component, let currentMessageMedia = self.currentMessageMedia else {
                return
            }
            
            if case let .file(file) = currentMessageMedia, let peerReference = PeerReference(component.peer._asPeer()) {
                if self.videoNode == nil {
                    let videoNode = UniversalVideoNode(
                        context: component.context,
                        postbox: component.context.account.postbox,
                        audioSession: component.context.sharedContext.mediaManager.audioSession,
                        manager: component.context.sharedContext.mediaManager.universalVideoManager,
                        decoration: StoryVideoDecoration(),
                        content: NativeVideoContent(
                            id: .contextResult(0, "\(UInt64.random(in: 0 ... UInt64.max))"),
                            userLocation: .peer(peerReference.id),
                            fileReference: .story(peer: peerReference, id: component.item.id, media: file),
                            imageReference: nil,
                            streamVideo: .story,
                            loopVideo: true,
                            enableSound: true,
                            soundMuted: component.audioMode == .off,
                            beginWithAmbientSound: component.audioMode == .ambient,
                            mixWithOthers: true,
                            useLargeThumbnail: false,
                            autoFetchFullSizeThumbnail: false,
                            tempFilePath: nil,
                            captureProtected: component.item.isForwardingDisabled,
                            hintDimensions: file.dimensions?.cgSize,
                            storeAfterDownload: nil,
                            displayImage: false,
                            hasSentFramesToDisplay: { [weak self] in
                                guard let self else {
                                    return
                                }
                                self.videoNode?.isHidden = false
                            }
                        ),
                        priority: .gallery
                    )
                    videoNode.isHidden = true
                    videoNode.setBaseRate(component.baseRate)
                    
                    self.videoNode = videoNode
                    self.insertSubview(videoNode.view, aboveSubview: self.imageView)
                    
                    videoNode.playbackCompleted = { [weak self] in
                        guard let self else {
                            return
                        }
                        
                        var shouldLoop = false
                        if self.progressMode.mode == .blurred {
                            shouldLoop = true
                        } else if let component = self.component, component.item.isPending {
                            shouldLoop = true
                        }
                        
                        if shouldLoop {
                            self.rewind()
                            
                            if let videoNode = self.videoNode {
                                if self.contentLoaded {
                                    videoNode.play()
                                }
                            }
                        } else {
                            self.environment?.presentationProgressUpdated(1.0, false, true)
                        }
                    }
                    videoNode.ownsContentNodeUpdated = { [weak self] value in
                        guard let self, let component = self.component else {
                            return
                        }
                        if value {
                            self.videoNode?.seek(0.0)
                            if component.audioMode != .off {
                                self.videoNode?.playOnceWithSound(playAndRecord: false, actionAtEnd: .stop)
                            } else {
                                self.videoNode?.play()
                            }
                        }
                    }
                    videoNode.canAttachContent = true
                    if update && !self.isUpdating {
                        self.state?.updated(transition: .immediate, isLocal: true)
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
                        if !self.isSeeking {
                            self.updateVideoPlaybackProgress()
                        }
                    })
                }
            }
            
            if case let .liveStream(liveStream) = currentMessageMedia {
                let mediaStreamCall: PresentationGroupCallImpl
                if let current = self.mediaStreamCall {
                    mediaStreamCall = current
                } else {
                    let initialCall = EngineGroupCallDescription(
                        id: liveStream.call.id,
                        accessHash: liveStream.call.accessHash,
                        title: nil,
                        scheduleTimestamp: nil,
                        subscribedToScheduled: false,
                        isStream: true
                    )
                    let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })
                    mediaStreamCall = PresentationGroupCallImpl(
                        accountContext: component.context,
                        audioSession: component.context.sharedContext.mediaManager.audioSession,
                        callKitIntegration: nil,
                        getDeviceAccessData: {
                            (
                                presentationData: presentationData,
                                present: { c, a in
                                    
                                },
                                openSettings: {
                                    
                                }
                            )
                        },
                        initialCall: (initialCall, .id(id: liveStream.call.id, accessHash: liveStream.call.accessHash)),
                        internalId: CallSessionInternalId(),
                        peerId: nil,
                        isChannel: false,
                        invite: nil,
                        joinAsPeerId: nil,
                        isStream: !(component.isEmbeddedInCamera && liveStream.kind == .rtc),
                        streamPeerId: component.peer.id,
                        keyPair: nil,
                        conferenceSourceId: nil,
                        isConference: false,
                        beginWithVideo: false,
                        sharedAudioContext: nil,
                        unmuteByDefault: false
                    )
                    self.mediaStreamCall = mediaStreamCall
                    
                    if update && !self.isUpdating {
                        self.state?.updated(transition: .immediate, isLocal: true)
                    }
                }
            }
        }
        
        override func setProgressMode(mode: StoryContentItem.ProgressMode, isCentral: Bool) {
            if self.progressMode.mode != mode || self.progressMode.isCentral != isCentral {
                self.progressMode = (mode, isCentral)
                self.updateProgressMode(update: true)
                
                if let component = self.component, !self.overlaysView.bounds.isEmpty {
                    self.updateOverlays(component: component, size: self.overlaysView.bounds.size, synchronousLoad: false, transition: .immediate)
                }
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
                self.ignoreBufferingTimestamp = CFAbsoluteTimeGetCurrent()
                videoNode.setSoundMuted(soundMuted: false)
                videoNode.continueWithOverridingAmbientMode(isAmbient: false)
            }
        }
        
        override func enterAmbientMode(ambient: Bool) {
            if let videoNode = self.videoNode {
                self.ignoreBufferingTimestamp = CFAbsoluteTimeGetCurrent()
                if ambient {
                    videoNode.continueWithOverridingAmbientMode(isAmbient: true)
                } else {
                    videoNode.setSoundMuted(soundMuted: true)
                }
            }
        }
        
        override func setBaseRate(_ baseRate: Double) {
            if let videoNode = self.videoNode {
                videoNode.setBaseRate(baseRate)
            }
        }
        
        private func updateProgressMode(update: Bool) {
            if let videoNode = self.videoNode {
                var canPlay = self.contentLoaded && self.hierarchyTrackingLayer.isInHierarchy
                if case .pause = self.progressMode.mode {
                    canPlay = false
                }
                if canPlay {
                    videoNode.play()
                } else {
                    videoNode.pause()
                }
            }
            
            var shouldUpdate = false
            if let mediaStreamCall = self.mediaStreamCall {
                //print("call progressMode: \(self.progressMode)")
                var canPlay = true
                if case .pause = self.progressMode.mode, (!self.progressMode.isCentral || (!self.hierarchyTrackingLayer.isInHierarchy && self.restorePictureInPicture == nil)) {
                    canPlay = false
                }
                if !canPlay {
                    self.mediaStreamCall = nil
                    shouldUpdate = true
                    
                    let _ = mediaStreamCall.leave(terminateIfPossible: false).startStandalone()
                }
            }
            
            self.initializeVideoIfReady(update: update)
            self.updateVideoPlaybackProgress()
            self.updateProgressTimer()
            
            if shouldUpdate {
                self.state?.updated(transition: .immediate, isLocal: true)
            }
        }
        
        private func updateProgressTimer() {
            var needsTimer = self.progressMode.mode != .pause && self.contentLoaded && self.hierarchyTrackingLayer.isInHierarchy
            if let component = self.component {
                if component.item.isPending {
                    if case .file = self.currentMessageMedia {
                    } else {
                        needsTimer = false
                    }
                }
            }
            
            if needsTimer {
                if self.currentProgressTimer == nil {
                    self.currentProgressTimer = SwiftSignalKit.Timer(
                        timeout: 1.0 / 60.0,
                        repeat: true,
                        completion: { [weak self] in
                            guard let self, self.progressMode.mode != .pause, self.contentLoaded, self.hierarchyTrackingLayer.isInHierarchy else {
                                return
                            }
                            
                            if case .file = self.currentMessageMedia {
                                if !self.isSeeking {
                                    self.updateVideoPlaybackProgress()
                                }
                            } else if case .liveStream = self.currentMessageMedia {
                                if !self.isSeeking {
                                    self.updateVideoPlaybackProgress()
                                }
                            } else {
                                if !self.markedAsSeen {
                                    self.markedAsSeen = true
                                    if let component = self.component {
                                        self.environment?.markAsSeen(StoryId(peerId: component.peer.id, id: component.item.id))
                                    }
                                }
                                
                                if self.progressMode.mode != .play {
                                    return
                                }
                                
                                #if DEBUG && true
                                let currentProgressTimerLimit: Double = 10.0
                                #else
                                let currentProgressTimerLimit: Double = 5.0
                                #endif
                                
                                var currentProgressTimerValue = self.currentProgressTimerValue + 1.0 / 60.0
                                currentProgressTimerValue = max(0.0, min(currentProgressTimerLimit, currentProgressTimerValue))
                                self.currentProgressTimerValue = currentProgressTimerValue
                                
                                self.environment?.presentationProgressUpdated(currentProgressTimerValue / currentProgressTimerLimit, false, true)
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
        
        var effectiveTimestamp: Double {
            guard let videoPlaybackStatus = self.videoPlaybackStatus else {
                return 0.0
            }
            return videoPlaybackStatus.timestamp
        }
        
        var effectiveDuration: Double {
            let effectiveDuration: Double
            if let videoPlaybackStatus, videoPlaybackStatus.duration > 0.0 {
                effectiveDuration = videoPlaybackStatus.duration
            } else if case let .file(file) = self.currentMessageMedia, let duration = file.duration {
                effectiveDuration = Double(max(1, duration))
            } else if case let .file(file) = self.currentMessageMetadataMedia, let duration = file.duration {
                effectiveDuration = Double(max(1, duration))
            } else {
                effectiveDuration = 1.0
            }
            return effectiveDuration
        }
        
        private func updateVideoPlaybackProgress(_ scrubbingTimestamp: Double? = nil) {
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
            } else if case let .file(file) = self.currentMessageMetadataMedia, let duration = file.duration {
                effectiveDuration = Double(max(1, duration))
            } else {
                effectiveDuration = 1.0
            }
            
            var isBuffering = false
            if case .buffering(false, true, _, _) = videoPlaybackStatus.status {
                isBuffering = true
            }
            
            if isBuffering {
                if CFAbsoluteTimeGetCurrent() - self.ignoreBufferingTimestamp < 0.3 {
                    isBuffering = false
                } else {
                    self.ignoreBufferingTimestamp = 0.0
                }
            } else {
                self.ignoreBufferingTimestamp = 0.0
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
                
                if actualTimestamp < 0.3 {
                    isBuffering = false
                }
                
                currentProgress = progress
                
                if isPlaying {
                    if !self.markedAsSeen {
                        self.markedAsSeen = true
                        if let component = self.component {
                            self.environment?.markAsSeen(StoryId(peerId: component.peer.id, id: component.item.id))
                        }
                    }
                    
                    if !self.contentLoaded {
                        self.contentLoaded = true
                        self.state?.updated(transition: .immediate, isLocal: true)
                    }
                }
            }
            
            if let scrubbingTimestamp {
                currentProgress = CGFloat(scrubbingTimestamp / effectiveDuration)
                if currentProgress.isNaN || !currentProgress.isFinite {
                    currentProgress = 0.0
                }
            }
            
            let clippedProgress = max(0.0, min(1.0, currentProgress))
            self.environment?.presentationProgressUpdated(clippedProgress, isBuffering, false)
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if let liveChatView = self.liveChat?.view {
                if let result = liveChatView.hitTest(self.convert(point, to: liveChatView), with: event) {
                    return result
                }
            }
            if let unsupportedButtonView = self.unsupportedButton?.view {
                if let result = unsupportedButtonView.hitTest(self.convert(point, to: unsupportedButtonView), with: event) {
                    return result
                }
            }
            if let result = self.overlaysView.hitTest(self.convert(point, to: self.overlaysView), with: event) {
                return result
            }
            return nil
        }
        
        private func updateOverlays(component: StoryItemContentComponent, size: CGSize, synchronousLoad: Bool, transition: ComponentTransition) {
            self.overlaysView.update(
                context: component.context,
                strings: component.strings,
                peer: component.peer,
                story: component.item,
                availableReactions: component.availableReactions,
                entityFiles: component.entityFiles,
                size: size,
                isCaptureProtected: component.item.isForwardingDisabled,
                attemptSynchronous: synchronousLoad,
                isActive: self.progressMode.mode == .play,
                transition: transition
            )
        }
        
        private var isSeeking = false
        func seekTo(_ timestamp: Double, apply: Bool) {
            guard let videoNode = self.videoNode else {
                return
            }
            if apply {
                videoNode.seek(min(timestamp, self.effectiveDuration - 0.3))
            }
            self.isSeeking = true
            self.updateVideoPlaybackProgress(timestamp)
        }
        
        func seekEnded() {
            self.isSeeking = false
        }
        
        func beginPictureInPicture(dismissController: @escaping () -> (restore: (@escaping () -> Void) -> Void, dismissWhilePictureInPicture: () -> Void)) {
            self.activatePictureInPictureAction.invoke(Action { [weak self] in
                guard let self else {
                    return
                }
                var restorePictureInPictureImpl: ((restore: (@escaping () -> Void) -> Void, dismissWhilePictureInPicture: () -> Void))?
                self.restorePictureInPicture = { f in
                    restorePictureInPictureImpl?.restore(f)
                }
                self.dismissWhileInPictureInPicture = {
                    restorePictureInPictureImpl?.dismissWhilePictureInPicture()
                }
                restorePictureInPictureImpl = dismissController()
            })
        }
        
        func scheduleScrollLiveChatToBottom() {
            guard let liveChatView = self.liveChat?.view as? StoryContentLiveChatComponent.View else {
                return
            }
            liveChatView.scheduleScrollLiveChatToBottom()
        }

        func update(component: StoryItemContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<StoryContentItem.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let previousItem = self.component?.item
            
            self.component = component
            self.state = state
            let environment = environment[StoryContentItem.Environment.self].value
            self.environment = environment
            
            var synchronousLoad = false
            if let hint = transition.userData(Hint.self) {
                synchronousLoad = hint.synchronousLoad
            }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            let peerReference = PeerReference(component.peer._asPeer())
            
            let selectedMedia: EngineMedia
            var messageMedia: EngineMedia?
            if case .liveStream = component.item.media {
                selectedMedia = component.item.media
                messageMedia = selectedMedia
                
                if self.customSubtitle == nil {
                    self.customSubtitle = component.strings.LiveStream_LoadingStatus
                }
            } else if !component.preferHighQuality, !component.item.isMy, let alternativeMediaValue = component.item.alternativeMediaList.first {
                selectedMedia = alternativeMediaValue
                
                switch alternativeMediaValue {
                case let .image(image):
                    messageMedia = .image(image)
                case let .file(file):
                    messageMedia = .file(file)
                case .unsupported:
                    self.contentLoaded = true
                default:
                    break
                }
            } else {
                selectedMedia = component.item.media
                
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
            }
            
            var reloadMedia = false
            if self.currentMessageMedia?.id != messageMedia?.id || (self.currentMessageMedia == nil) != (messageMedia == nil) {
                self.currentMessageMedia = messageMedia
                reloadMedia = true
                
                if let videoNode = self.videoNode {
                    self.videoProgressDisposable?.dispose()
                    self.videoProgressDisposable = nil
                    
                    self.videoNode = nil
                    videoNode.view.removeFromSuperview()
                }
            }
            self.currentMessageMetadataMedia = component.item.media
            
            var fetchPriorityResourceId: String?
            switch messageMedia {
            case let .image(image):
                if let representation = largestImageRepresentation(image.representations) {
                    fetchPriorityResourceId = representation.resource.id.stringRepresentation
                }
            case let .file(file):
                fetchPriorityResourceId = file.resource.id.stringRepresentation
            default:
                break
            }
            
            if self.fetchPriorityResourceId != fetchPriorityResourceId || self.currentFetchPriority?.0 != component.isCurrent {
                self.fetchPriorityResourceId = fetchPriorityResourceId
                self.currentFetchPriority?.disposable.dispose()
                
                if let fetchPriorityResourceId {
                    self.currentFetchPriority = (component.isCurrent, component.context.engine.resources.pushPriorityDownload(resourceId: fetchPriorityResourceId, priority: component.isCurrent ? 2 : 1))
                }
            }
            
            if reloadMedia, let messageMedia, let peerReference {
                self.priorityDisposable?.dispose()
                self.priorityDisposable = nil
                
                var fetchSignal: Signal<Never, NoError>?
                switch messageMedia {
                case let .image(image):
                    if let representation = largestImageRepresentation(image.representations) {
                        self.priorityDisposable = component.context.engine.resources.pushPriorityDownload(resourceId: representation.resource.id.stringRepresentation)
                    }
                case let .file(file):
                    self.priorityDisposable = component.context.engine.resources.pushPriorityDownload(resourceId: file.resource.id.stringRepresentation)
                    
                    fetchSignal = fetchedMediaResource(
                        mediaBox: component.context.account.postbox.mediaBox,
                        userLocation: .other,
                        userContentType: .story,
                        reference: FileMediaReference.story(peer: peerReference, id: component.item.id, media: file).resourceReference(file.resource)
                    )
                    |> ignoreValues
                    |> `catch` { _ -> Signal<Never, NoError> in
                        return .complete()
                    }
                default:
                    break
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
                            self.state?.updated(transition: .immediate, isLocal: true)
                        }
                    })
                }
            }
            
            if let messageMedia, case .liveStream = messageMedia {
                if component.isEmbeddedInCamera {
                    self.imageView.isHidden = true
                } else {
                    self.imageView.update(
                        context: component.context,
                        strings: component.strings,
                        peer: component.peer,
                        storyId: component.item.id,
                        media: messageMedia,
                        size: availableSize,
                        isCaptureProtected: component.item.isForwardingDisabled,
                        attemptSynchronous: synchronousLoad,
                        transition: transition
                    )
                    if !self.contentLoaded || component.isVideoBuffering {
                        self.imageView.isHidden = false
                    } else {
                        self.imageView.isHidden = true
                    }
                }
            }
            
            if case let .liveStream(liveStream) = messageMedia, let mediaStreamCall = self.mediaStreamCall {
                var mediaStreamTransition = transition
                let mediaStream: ComponentView<Empty>
                if let current = self.mediaStream {
                    mediaStream = current
                } else {
                    mediaStreamTransition = mediaStreamTransition.withAnimation(.none)
                    mediaStream = ComponentView()
                    self.mediaStream = mediaStream
                }
                
                let liveChat: ComponentView<Empty>
                if let current = self.liveChat {
                    liveChat = current
                } else {
                    liveChat = ComponentView()
                    self.liveChat = liveChat
                }
                
                var minPaidStars: Int?
                if let mediaStreamCallState = self.mediaStreamCallState {
                    minPaidStars = mediaStreamCallState.minMessagePrice.flatMap(Int.init)
                }
                
                let _ = liveChat.update(
                    transition: mediaStreamTransition,
                    component: AnyComponent(StoryContentLiveChatComponent(
                        external: self.liveChatExternal,
                        context: component.context,
                        strings: component.strings,
                        theme: environment.theme,
                        call: mediaStreamCall,
                        storyPeerId: component.peer.id,
                        canManageMessagesFromPeers: component.canManageLiveChatMessagesFromPeers,
                        insets: environment.containerInsets,
                        isEmbeddedInCamera: component.isEmbeddedInCamera,
                        minPaidStars: minPaidStars,
                        controller: { [weak self] in
                            guard let self, let component = self.component else {
                                return nil
                            }
                            return component.controller()
                        }
                    )),
                    environment: {},
                    containerSize: availableSize
                )
                let liveChatFrame = CGRect(origin: CGPoint(), size: availableSize)
                if let liveChatView = liveChat.view {
                    if liveChatView.superview == nil {
                        liveChat.parentState = state
                        liveChatView.layer.allowsGroupOpacity = true
                        self.insertSubview(liveChatView, aboveSubview: self.imageView)
                    }
                    mediaStreamTransition.setFrame(view: liveChatView, frame: liveChatFrame)
                    mediaStreamTransition.setAlpha(view: liveChatView, alpha: component.isUIHidden ? 0.0 : 1.0)
                }
                
                if case .rtc = liveStream.kind, component.isEmbeddedInCamera {
                } else if let mediaStreamCallState = self.mediaStreamCallState {
                    var videoEndpointId: String?
                    if mediaStreamCallState.isUnifiedStream {
                        videoEndpointId = "unified"
                    } else if let mediaStreamCallVideoState = self.mediaStreamCallVideoState {
                        videoEndpointId = mediaStreamCallVideoState.videoEndpointId
                    }
                    
                    if let videoEndpointId {
                        let _ = mediaStream.update(
                            transition: mediaStreamTransition,
                            component: AnyComponent(MediaStreamVideoComponent(
                                call: mediaStreamCall,
                                videoEndpointId: videoEndpointId,
                                isVisible: true,
                                isAdmin: false,
                                peerTitle: "",
                                addInset: false,
                                isFullscreen: false,
                                videoLoading: false,
                                callPeer: nil,
                                enablePictureInPicture: true,
                                activatePictureInPicture: self.activatePictureInPictureAction,
                                deactivatePictureInPicture: self.deactivatePictureInPictureAction,
                                bringBackControllerForPictureInPictureDeactivation: { [weak self] f in
                                    guard let self else {
                                        return
                                    }
                                    self.dismissWhileInPictureInPicture = nil
                                    if let restorePictureInPicture = self.restorePictureInPicture {
                                        self.restorePictureInPicture = nil
                                        restorePictureInPicture(f)
                                    } else {
                                        f()
                                    }
                                },
                                pictureInPictureClosed: { [weak self] in
                                    guard let self else {
                                        return
                                    }
                                    self.restorePictureInPicture = nil
                                    if let dismissWhileInPictureInPicture = self.dismissWhileInPictureInPicture {
                                        self.dismissWhileInPictureInPicture = nil
                                        dismissWhileInPictureInPicture()
                                    }
                                },
                                onVideoSizeRetrieved: { _ in
                                },
                                onVideoPlaybackLiveChange: { [weak self] isLive in
                                    guard let self else {
                                        return
                                    }
                                    self.videoPlaybackStatus = MediaPlayerStatus(
                                        generationTimestamp: CACurrentMediaTime(),
                                        duration: .infinity,
                                        dimensions: CGSize(),
                                        timestamp: 0.0,
                                        baseRate: 1.0,
                                        seekId: 0,
                                        status: isLive ? .playing : .buffering(initial: false, whilePlaying: true, progress: 0.0, display: true),
                                        soundEnabled: true
                                    )
                                    if !self.isSeeking {
                                        self.updateVideoPlaybackProgress()
                                    }
                                }
                            )),
                            environment: {},
                            containerSize: availableSize
                        )
                        let mediaStreamFrame = CGRect(origin: CGPoint(), size: availableSize)
                        if let mediaStreamView = mediaStream.view {
                            if mediaStreamView.superview == nil {
                                self.insertSubview(mediaStreamView, aboveSubview: self.imageView)
                            }
                            mediaStreamTransition.setFrame(view: mediaStreamView, frame: mediaStreamFrame)
                        }
                    }
                }
            } else {
                if let mediaStream = self.mediaStream {
                    self.mediaStream = nil
                    mediaStream.view?.removeFromSuperview()
                }
                
                if let liveChat = self.liveChat {
                    self.liveChat = nil
                    liveChat.view?.removeFromSuperview()
                }
                
                if let messageMedia {
                    var applyState = false
                    self.imageView.didLoadContents = { [weak self] in
                        guard let self else {
                            return
                        }
                        self.contentLoaded = true
                        if applyState {
                            self.state?.updated(transition: .immediate, isLocal: true)
                        }
                    }
                    self.imageView.update(
                        context: component.context,
                        strings: component.strings,
                        peer: component.peer,
                        storyId: component.item.id,
                        media: messageMedia,
                        size: availableSize,
                        isCaptureProtected: component.item.isForwardingDisabled,
                        attemptSynchronous: synchronousLoad,
                        transition: transition
                    )
                    self.updateOverlays(component: component, size: availableSize, synchronousLoad: synchronousLoad, transition: transition)
                    applyState = true
                    if self.imageView.isContentLoaded {
                        self.contentLoaded = true
                    }
                    transition.setFrame(view: self.imageView, frame: CGRect(origin: CGPoint(), size: availableSize))
                    transition.setFrame(view: self.overlaysView, frame: CGRect(origin: CGPoint(), size: availableSize))
                    
                    var dimensions: CGSize?
                    switch messageMedia {
                    case let .image(image):
                        dimensions = image.representations.last?.dimensions.cgSize
                    case let .file(file):
                        dimensions = file.dimensions?.cgSize
                    default:
                        break
                    }
                    if dimensions == nil {
                        switch component.item.media {
                        case let .image(image):
                            dimensions = image.representations.last?.dimensions.cgSize
                        case let .file(file):
                            dimensions = file.dimensions?.cgSize
                        default:
                            break
                        }
                    }
                    
                    if let dimensions {
                        var imageSize = dimensions.aspectFilled(availableSize)
                        if imageSize.width < availableSize.width && imageSize.width >= availableSize.width - 5.0 {
                            imageSize.width = availableSize.width
                        }
                        if imageSize.height < availableSize.height && imageSize.height >= availableSize.height - 5.0 {
                            imageSize.height = availableSize.height
                        }
                        let _ = imageSize
                        
                        if let videoNode = self.videoNode {
                            let videoSize = dimensions.aspectFilled(availableSize)
                            videoNode.frame = CGRect(origin: CGPoint(x: floor((availableSize.width - videoSize.width) * 0.5), y: floor((availableSize.height - videoSize.height) * 0.5)), size: videoSize)
                            videoNode.updateLayout(size: videoSize, transition: .immediate)
                        }
                    }
                }
            }
            
            if let mediaStreamCall = self.mediaStreamCall {
                if self.liveCallStateDisposable == nil {
                    self.liveCallStateDisposable = (mediaStreamCall.state
                    |> deliverOnMainQueue).startStrict(next: { [weak self] state in
                        guard let self else {
                            return
                        }
                        
                        let mappedState = MediaStreamCallState(
                            areMessagesEnabled: state.messagesAreEnabled,
                            minMessagePrice: state.sendPaidMessageStars,
                            isAdmin: state.canManageCall,
                            defaultSendAs: state.defaultSendAs,
                            isUnifiedStream: state.isUnifiedStream
                        )
                        if self.mediaStreamCallState != mappedState {
                            self.mediaStreamCallState = mappedState
                            if !self.isUpdating {
                                self.state?.updated(transition: .spring(duration: 0.4))
                            }
                        }
                    })
                }
                
                if self.liveCallStatsDisposable == nil {
                    self.liveCallStatsDisposable = (mediaStreamCall.members
                    |> deliverOnMainQueue).startStandalone(next: { [weak self] members in
                        guard let self, let component = self.component, let environment = self.environment else {
                            return
                        }
                        let subtitle: String
                        if let members {
                            var totalCount = members.totalCount
                            if component.isEmbeddedInCamera {
                                totalCount -= 1
                            }
                            if totalCount == 0 && component.isEmbeddedInCamera {
                                subtitle = component.strings.LiveStream_StoryViewerEmpty
                            } else {
                                subtitle = component.strings.LiveStream_StoryViewerCount(Int32(max(1, totalCount)))
                            }
                        } else {
                            subtitle = component.strings.LiveStream_LoadingStatus
                        }
                        if self.customSubtitle != subtitle {
                            self.customSubtitle = subtitle
                            if !self.isUpdating {
                                environment.customItemSubtitleUpdated()
                            }
                        }
                        
                        var video: PresentationGroupCallRequestedVideo?
                        if let members {
                            if let participant = members.participants.first(where: { $0.videoEndpointId != nil }), let videoValue = participant.requestedVideoChannel(minQuality: .full, maxQuality: .full) {
                                video = videoValue
                            }
                        }
                        let mediaStreamCallVideoState = MediaStreamCallVideoState(videoEndpointId: video?.endpointId)
                        if self.mediaStreamCallVideoState != mediaStreamCallVideoState {
                            self.mediaStreamCallVideoState = mediaStreamCallVideoState
                            
                            if let mediaStreamCall = self.mediaStreamCall {
                                if let video {
                                    mediaStreamCall.setRequestedVideoList(items: [video])
                                } else {
                                    mediaStreamCall.setRequestedVideoList(items: [])
                                }
                            }
                            
                            if !self.isUpdating {
                                self.state?.updated(transition: .immediate)
                            }
                        }
                    })
                }
            } else {
                if let liveCallStateDisposable = self.liveCallStateDisposable {
                    self.liveCallStateDisposable = nil
                    liveCallStateDisposable.dispose()
                }
                if let liveCallStatsDisposable = self.liveCallStatsDisposable {
                    self.liveCallStatsDisposable = nil
                    liveCallStatsDisposable.dispose()
                }
            }
            
            switch selectedMedia {
            case .image, .file, .liveStream:
                if let unsupportedText = self.unsupportedText {
                    self.unsupportedText = nil
                    unsupportedText.view?.removeFromSuperview()
                }
                if let unsupportedButton = self.unsupportedButton {
                    self.unsupportedButton = nil
                    unsupportedButton.view?.removeFromSuperview()
                }
                if component.isEmbeddedInCamera, case let .liveStream(liveStream) = messageMedia, case .rtc = liveStream.kind {
                } else {
                    self.backgroundColor = .black
                }
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
                
                let unsupportedTextSize = unsupportedText.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: component.strings.Story_UnsupportedText, font: Font.regular(17.0), textColor: .white)),
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
                        content: AnyComponentWithIdentity(id: AnyHashable(""), component: AnyComponent(Text(text: component.strings.Story_UnsupportedAction, font: Font.semibold(17.0), color: environment.theme.list.itemCheckColors.foregroundColor
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
            
            self.updateProgressMode(update: false)
            
            if reloadMedia && synchronousLoad {
                let _ = startTime
                #if DEBUG
                print("\(CFAbsoluteTimeGetCurrent()) Synchronous: \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
                #endif
            }
            
            if component.isEmbeddedInCamera, case let .liveStream(liveStream) = messageMedia, case .rtc = liveStream.kind {
            } else if !self.contentLoaded || component.isVideoBuffering {
                let loadingEffectView: StoryItemLoadingEffectView
                if let current = self.loadingEffectView {
                    loadingEffectView = current
                } else {
                    loadingEffectView = StoryItemLoadingEffectView(effectAlpha: 0.1, borderAlpha: 0.2, duration: 1.0, hasCustomBorder: false, playOnce: false)
                    loadingEffectView.alpha = 0.0
                    self.loadingEffectView = loadingEffectView
                    self.addSubview(loadingEffectView)
                    
                    if self.loadingEffectAppearanceTimer == nil {
                        let timer = SwiftSignalKit.Timer(timeout: 0.2, repeat: false, completion: { [weak self] in
                            guard let self else {
                                return
                            }
                            if let loadingEffectView = self.loadingEffectView {
                                loadingEffectView.alpha = 1.0
                                loadingEffectView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.18)
                            }
                            self.loadingEffectAppearanceTimer = nil
                        }, queue: Queue.mainQueue())
                        timer.start()
                        self.loadingEffectAppearanceTimer = timer
                    }
                }
                loadingEffectView.update(size: availableSize, transition: transition)
            } else if let loadingEffectView = self.loadingEffectView {
                self.loadingEffectAppearanceTimer?.invalidate()
                self.loadingEffectAppearanceTimer = nil
                self.loadingEffectView = nil
                loadingEffectView.layer.animateAlpha(from: loadingEffectView.alpha, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak loadingEffectView] _ in
                    loadingEffectView?.removeFromSuperview()
                })
            }
            
            if self.contentLoaded {
                if let previousItem, previousItem.mediaAreas != component.item.mediaAreas {
                    if let mediaAreasEffectView = self.mediaAreasEffectView {
                        self.mediaAreasEffectView = nil
                        mediaAreasEffectView.removeFromSuperview()
                    }
                }
                
                var shimmeringMediaAreas: [MediaArea] = component.item.mediaAreas.filter { mediaArea in
                    if case .link = mediaArea {
                        return true
                    } else if case .venue = mediaArea {
                        return true
                    } else {
                        return false
                    }
                }
                
                if component.peer.id.isTelegramNotifications {
                    shimmeringMediaAreas = []
                }
                
                if !shimmeringMediaAreas.isEmpty {
                    let mediaAreasEffectView: StoryItemLoadingEffectView
                    if let current = self.mediaAreasEffectView {
                        mediaAreasEffectView = current
                    } else {
                        mediaAreasEffectView = StoryItemLoadingEffectView(effectAlpha: 0.35, borderAlpha: 0.45, gradientWidth: 150.0, duration: 1.2, hasCustomBorder: false, playOnce: true)
                        self.mediaAreasEffectView = mediaAreasEffectView
                        self.addSubview(mediaAreasEffectView)
                    }
                    mediaAreasEffectView.update(size: availableSize, transition: transition)
                    
                    let maskLayer: MediaAreaMaskLayer
                    if let current = mediaAreasEffectView.layer.mask as? MediaAreaMaskLayer {
                        maskLayer = current
                    } else {
                        maskLayer = MediaAreaMaskLayer()
                        mediaAreasEffectView.layer.mask = maskLayer
                    }
                    maskLayer.update(referenceSize: availableSize, mediaAreas: shimmeringMediaAreas, borderMaskLayer: mediaAreasEffectView.borderMaskLayer)
                } else if let mediaAreasEffectView = self.mediaAreasEffectView {
                    self.mediaAreasEffectView = nil
                    mediaAreasEffectView.removeFromSuperview()
                }
            }
            
            return availableSize
        }
	}

	func makeView() -> View {
		return View(frame: CGRect())
	}

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<StoryContentItem.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
