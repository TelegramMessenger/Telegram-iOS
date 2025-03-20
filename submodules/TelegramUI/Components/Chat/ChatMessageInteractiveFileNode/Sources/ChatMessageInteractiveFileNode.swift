import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import Display
import TelegramCore
import UniversalMediaPlayer
import TelegramPresentationData
import AccountContext
import PhotoResources
import TelegramStringFormatting
import SemanticStatusNode
import FileMediaResourceStatus
import CheckNode
import MusicAlbumArtResources
import AudioBlob
import ContextUI
import ChatPresentationInterfaceState
import ComponentFlow
import AudioTranscriptionButtonComponent
import AudioWaveformComponent
import ShimmerEffect
import ConvertOpusToAAC
import LocalAudioTranscription
import TextSelectionNode
import AudioTranscriptionPendingIndicatorComponent
import UndoUI
import TelegramNotices
import ChatControllerInteraction
import ChatMessageDateAndStatusNode
import ChatHistoryEntry
import ChatMessageItemCommon
import TelegramStringFormatting
import AnimatedCountLabelNode
import AudioWaveform
import DeviceProximity

private struct FetchControls {
    let fetch: (Bool) -> Void
    let cancel: () -> Void
}

public final class ChatMessageInteractiveFileNode: ASDisplayNode {
    public final class Arguments {
        public let context: AccountContext
        public let presentationData: ChatPresentationData
        public let customTintColor: UIColor?
        public let message: Message
        public let topMessage: Message
        public let associatedData: ChatMessageItemAssociatedData
        public let chatLocation: ChatLocation
        public let attributes: ChatMessageEntryAttributes
        public let isPinned: Bool
        public let forcedIsEdited: Bool
        public let file: TelegramMediaFile
        public let automaticDownload: Bool
        public let incoming: Bool
        public let isRecentActions: Bool
        public let forcedResourceStatus: FileMediaResourceStatus?
        public let dateAndStatusType: ChatMessageDateAndStatusType?
        public let displayReactions: Bool
        public let messageSelection: Bool?
        public let isAttachedContentBlock: Bool
        public let layoutConstants: ChatMessageItemLayoutConstants
        public let constrainedSize: CGSize
        public let controllerInteraction: ChatControllerInteraction
        
        public init(
            context: AccountContext,
            presentationData: ChatPresentationData,
            customTintColor: UIColor?,
            message: Message,
            topMessage: Message,
            associatedData: ChatMessageItemAssociatedData,
            chatLocation: ChatLocation,
            attributes: ChatMessageEntryAttributes,
            isPinned: Bool,
            forcedIsEdited: Bool,
            file: TelegramMediaFile,
            automaticDownload: Bool,
            incoming: Bool,
            isRecentActions: Bool,
            forcedResourceStatus: FileMediaResourceStatus?,
            dateAndStatusType: ChatMessageDateAndStatusType?,
            displayReactions: Bool,
            messageSelection: Bool?,
            isAttachedContentBlock: Bool,
            layoutConstants: ChatMessageItemLayoutConstants,
            constrainedSize: CGSize,
            controllerInteraction: ChatControllerInteraction
        ) {
            self.context = context
            self.presentationData = presentationData
            self.customTintColor = customTintColor
            self.message = message
            self.topMessage = topMessage
            self.associatedData = associatedData
            self.chatLocation = chatLocation
            self.attributes = attributes
            self.isPinned = isPinned
            self.forcedIsEdited = forcedIsEdited
            self.file = file
            self.automaticDownload = automaticDownload
            self.incoming = incoming
            self.isRecentActions = isRecentActions
            self.forcedResourceStatus = forcedResourceStatus
            self.dateAndStatusType = dateAndStatusType
            self.displayReactions = displayReactions
            self.messageSelection = messageSelection
            self.isAttachedContentBlock = isAttachedContentBlock
            self.layoutConstants = layoutConstants
            self.constrainedSize = constrainedSize
            self.controllerInteraction = controllerInteraction
        }
    }
    
    private var selectionNode: FileMessageSelectionNode?
    
    private let titleNode: TextNode
    private let descriptionNode: TextNode
    private let descriptionMeasuringNode: TextNode
    public let fetchingTextNode: ImmediateTextNode
    public let fetchingCompactTextNode: ImmediateTextNode
    private let countNode: ImmediateAnimatedCountLabelNode
    
    public var waveformView: ComponentHostView<Empty>?
    
    public var audioTranscriptionButton: ComponentHostView<Empty>?
    private var transcriptionPendingIndicator: ComponentHostView<Empty>?
    public let textNode: TextNode
    public let textClippingNode: ASDisplayNode
    private var textSelectionNode: TextSelectionNode?
    
    public var updateIsTextSelectionActive: ((Bool) -> Void)?
    
    public let dateAndStatusNode: ChatMessageDateAndStatusNode
    private let consumableContentNode: ASImageNode
    
    private var iconNode: TransformImageNode?
    public let statusContainerNode: ContextExtractedContentContainingNode
    public var statusNode: SemanticStatusNode?
    private var playbackAudioLevelNode: VoiceBlobNode?
    private var streamingStatusNode: SemanticStatusNode?
    private var tapRecognizer: UITapGestureRecognizer?
    
    private let statusDisposable = MetaDisposable()
    private let playbackStatusDisposable = MetaDisposable()
    private let playbackStatus = Promise<MediaPlayerStatus>()
    
    private let audioLevelEventsDisposable = MetaDisposable()
    
    private var playerUpdateTimer: SwiftSignalKit.Timer?
    private var playerStatus: MediaPlayerStatus? {
        didSet {
            if self.playerStatus != oldValue {
                if let playerStatus = playerStatus, case .playing = playerStatus.status {
                    self.ensureHasTimer()
                } else {
                    self.stopTimer()
                }
                self.updateStatus(animated: true)
            }
        }
    }
    
    private var inputAudioLevel: CGFloat = 0.0
    private var currentAudioLevel: CGFloat = 0.0
    
    public var visibility: Bool = false {
        didSet {
            guard self.visibility != oldValue else { return }
            
            if !self.visibility {
                self.playbackAudioLevelNode?.stopAnimating()
            }
        }
    }
    
    private let fetchControls = Atomic<FetchControls?>(value: nil)
    private var resourceStatus: FileMediaResourceStatus?
    private var actualFetchStatus: MediaResourceStatus?
    private let fetchDisposable = MetaDisposable()
    
    public var toggleSelection: (Bool) -> Void = { _ in }
    public var activateLocalContent: () -> Void = { }
    public var requestUpdateLayout: (Bool) -> Void = { _ in }
    public var displayImportedTooltip: (ASDisplayNode) -> Void = { _ in }
    
    public var updateTranscriptionExpanded: ((AudioTranscriptionButtonComponent.TranscriptionState) -> Void)?
    
    private var context: AccountContext?
    private var message: Message?
    private var arguments: Arguments?
    private var presentationData: ChatPresentationData?
    private var file: TelegramMediaFile?
    private var progressFrame: CGRect?
    private var streamingCacheStatusFrame: CGRect?
    private var fileIconImage: UIImage?
    private var viewOnceIconImage: UIImage?
    
    public var audioTranscriptionState: AudioTranscriptionButtonComponent.TranscriptionState = .collapsed
    public var forcedAudioTranscriptionText: TranscribedText?
    private var transcribeDisposable: Disposable?
    public var hasExpandedAudioTranscription: Bool {
        if case .expanded = audioTranscriptionState {
            return true
        } else {
            return false
        }
    }
    private var isWaitingForCollapse: Bool = false
    
    private var hapticFeedback: HapticFeedback?
    
    override public init() {
        self.titleNode = TextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.isUserInteractionEnabled = false
        
        self.descriptionNode = TextNode()
        self.descriptionNode.displaysAsynchronously = false
        self.descriptionNode.isUserInteractionEnabled = false
        
        self.countNode = ImmediateAnimatedCountLabelNode()
        self.countNode.alwaysOneDirection = true
        
        self.descriptionMeasuringNode = TextNode()
        
        self.fetchingTextNode = ImmediateTextNode()
        self.fetchingTextNode.displaysAsynchronously = false
        self.fetchingTextNode.isUserInteractionEnabled = false
        self.fetchingTextNode.maximumNumberOfLines = 1
        self.fetchingTextNode.contentMode = .left
        self.fetchingTextNode.contentsScale = UIScreenScale
        self.fetchingTextNode.isHidden = true
        
        self.fetchingCompactTextNode = ImmediateTextNode()
        self.fetchingCompactTextNode.displaysAsynchronously = false
        self.fetchingCompactTextNode.isUserInteractionEnabled = false
        self.fetchingCompactTextNode.maximumNumberOfLines = 1
        self.fetchingCompactTextNode.contentMode = .left
        self.fetchingCompactTextNode.contentsScale = UIScreenScale
        self.fetchingCompactTextNode.isHidden = true
        
        /*self.waveformNode = AudioWaveformNode()
        self.waveformNode.isLayerBacked = true
        self.waveformForegroundNode = AudioWaveformNode()
        self.waveformForegroundNode.isLayerBacked = true*/
        
        self.textNode = TextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.isUserInteractionEnabled = false
        
        self.textClippingNode = ASDisplayNode()
        self.textClippingNode.clipsToBounds = true
        self.textClippingNode.addSubnode(self.textNode)
        
        self.dateAndStatusNode = ChatMessageDateAndStatusNode()
        
        self.consumableContentNode = ASImageNode()

        self.statusContainerNode = ContextExtractedContentContainingNode()
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.descriptionNode)
        self.addSubnode(self.fetchingTextNode)
        self.addSubnode(self.fetchingCompactTextNode)
        self.addSubnode(self.statusContainerNode)
    }
    
    deinit {
        self.statusDisposable.dispose()
        self.playbackStatusDisposable.dispose()
        self.fetchDisposable.dispose()
        self.audioLevelEventsDisposable.dispose()
        self.transcribeDisposable?.dispose()
    }
    
    override public func didLoad() {
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.fileTap(_:)))
        self.view.addGestureRecognizer(tapRecognizer)
        self.tapRecognizer = tapRecognizer
    }
    
    @objc private func cacheProgressPressed() {
        guard let resourceStatus = self.resourceStatus else {
            return
        }
        switch resourceStatus.fetchStatus {
            case .Fetching:
                if let cancel = self.fetchControls.with({ return $0?.cancel }) {
                    cancel()
                }
            case .Remote, .Paused:
                if let fetch = self.fetchControls.with({ return $0?.fetch }) {
                    fetch(true)
                }
            case .Local:
                break
        }
    }
    
    @objc private func progressPressed() {
        if let _ = self.arguments?.attributes.updatingMedia {
            if let message = self.message {
                self.context?.account.pendingUpdateMessageManager.cancel(messageId: message.id)
            }
        }
        else if let resourceStatus = self.resourceStatus {
            switch resourceStatus.mediaStatus {
            case let .fetchStatus(fetchStatus):
                if let context = self.context, let message = self.message, message.flags.isSending {
                    let _ = context.engine.messages.deleteMessagesInteractively(messageIds: [message.id], type: .forEveryone).startStandalone()
                } else {
                    switch fetchStatus {
                    case .Fetching:
                        if let cancel = self.fetchControls.with({ return $0?.cancel }) {
                            cancel()
                        }
                    case .Remote, .Paused:
                        if let fetch = self.fetchControls.with({ return $0?.fetch }) {
                            fetch(true)
                        }
                    case .Local:
                        self.activateLocalContent()
                    }
                }
            case .playbackStatus:
                if let context = self.context, let message = self.message, let type = peerMessageMediaPlayerType(EngineMessage(message)) {
                    context.sharedContext.mediaManager.playlistControl(.playback(.togglePlayPause), type: type)
                }
            }
        }
    }
    
    @objc private func fileTap(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let streamingCacheStatusFrame = self.streamingCacheStatusFrame, streamingCacheStatusFrame.contains(recognizer.location(in: self.view)) {
                self.cacheProgressPressed()
            } else {
                self.progressPressed()
            }
        }
    }
    
    private func transcribe() {
        guard let arguments = self.arguments, let context = self.context, let message = self.message else {
            return
        }
        
        if !context.isPremium, case .inProgress = self.audioTranscriptionState {
            return
        }
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let premiumConfiguration = PremiumConfiguration.with(appConfiguration: arguments.context.currentAppConfiguration.with { $0 })
        
        let transcriptionText = self.forcedAudioTranscriptionText ?? transcribedText(message: message)
        if transcriptionText == nil && !arguments.associatedData.alwaysDisplayTranscribeButton.providedByGroupBoost {
            if premiumConfiguration.audioTransciptionTrialCount > 0 {
                if !arguments.associatedData.isPremium {
                    if self.presentAudioTranscriptionTooltip(finished: false) {
                        return
                    }
                }
            } else {
                guard arguments.associatedData.isPremium else {
                    if self.hapticFeedback == nil {
                        self.hapticFeedback = HapticFeedback()
                    }
                    self.hapticFeedback?.impact(.medium)
                    
                    let tipController = UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_voiceToText", scale: 0.065, colors: [:], title: nil, text: presentationData.strings.Message_AudioTranscription_SubscribeToPremium, customUndoText: presentationData.strings.Message_AudioTranscription_SubscribeToPremiumAction, timeout: nil), elevatedLayout: false, position: .top, animateInAsReplacement: false, action: { action in
                        if case .undo = action {
                            var replaceImpl: ((ViewController) -> Void)?
                            let controller = context.sharedContext.makePremiumDemoController(context: context, subject: .voiceToText, forceDark: false, action: {
                                let controller = context.sharedContext.makePremiumIntroController(context: context, source: .settings, forceDark: false, dismissed: nil)
                                replaceImpl?(controller)
                            }, dismissed: nil)
                            replaceImpl = { [weak controller] c in
                                controller?.replace(with: c)
                            }
                            arguments.controllerInteraction.navigationController()?.pushViewController(controller, animated: true)
                            
                            let _ = ApplicationSpecificNotice.incrementAudioTranscriptionSuggestion(accountManager: context.sharedContext.accountManager).startStandalone()
                        }
                        return false })
                    arguments.controllerInteraction.presentControllerInCurrent(tipController, nil)
                    return
                }
            }
        }
        
        var shouldBeginTranscription = false
        var shouldExpandNow = false
        
        if case .expanded = self.audioTranscriptionState {
            shouldExpandNow = true
        } else {
            if let result = transcribedText(message: message) {
                shouldExpandNow = true
                
                if case let .success(_, isPending) = result {
                    shouldBeginTranscription = isPending
                } else {
                    shouldBeginTranscription = true
                }
            } else {
                shouldBeginTranscription = true
            }
        }
        
        if shouldBeginTranscription {
            if self.transcribeDisposable == nil {
                self.audioTranscriptionState = .inProgress
                self.requestUpdateLayout(true)
                
                if context.sharedContext.immediateExperimentalUISettings.localTranscription {
                    let appLocale = presentationData.strings.baseLanguageCode
                    
                    let signal: Signal<LocallyTranscribedAudio?, NoError> = context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: message.id))
                    |> mapToSignal { message -> Signal<String?, NoError> in
                        guard let message = message else {
                            return .single(nil)
                        }
                        guard let file = message.media.first(where: { $0 is TelegramMediaFile }) as? TelegramMediaFile else {
                            return .single(nil)
                        }
                        return context.account.postbox.mediaBox.resourceData(id: file.resource.id)
                        |> take(1)
                        |> mapToSignal { data -> Signal<String?, NoError> in
                            if !data.complete {
                                return .single(nil)
                            }
                            return .single(data.path)
                        }
                    }
                    |> mapToSignal { result -> Signal<String?, NoError> in
                        guard let result = result else {
                            return .single(nil)
                        }
                        return convertOpusToAAC(sourcePath: result, allocateTempFile: {
                            return TempBox.shared.tempFile(fileName: "audio.m4a").path
                        })
                    }
                    |> mapToSignal { result -> Signal<LocallyTranscribedAudio?, NoError> in
                        guard let result = result else {
                            return .single(nil)
                        }
                        return transcribeAudio(path: result, appLocale: appLocale)
                    }
                    
                    self.transcribeDisposable = (signal
                    |> deliverOnMainQueue).startStrict(next: { [weak self] result in
                        guard let strongSelf = self, let arguments = strongSelf.arguments else {
                            return
                        }
                        
                        if let result = result {
                            let _ = arguments.context.engine.messages.storeLocallyTranscribedAudio(messageId: arguments.message.id, text: result.text, isFinal: result.isFinal, error: nil).startStandalone()
                        } else {
                            strongSelf.audioTranscriptionState = .collapsed
                            strongSelf.requestUpdateLayout(true)
                        }
                    }, completed: { [weak self] in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.transcribeDisposable?.dispose()
                        strongSelf.transcribeDisposable = nil
                    })
                } else {
                    self.transcribeDisposable = (context.engine.messages.transcribeAudio(messageId: message.id)
                    |> deliverOnMainQueue).startStrict(next: { [weak self] result in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.transcribeDisposable?.dispose()
                        strongSelf.transcribeDisposable = nil
                        
                        if let arguments = strongSelf.arguments, !arguments.associatedData.isPremium && !arguments.associatedData.alwaysDisplayTranscribeButton.providedByGroupBoost {
                            Queue.mainQueue().after(0.1, {
                                let _ = strongSelf.presentAudioTranscriptionTooltip(finished: true)
                            })
                        }
                    })
                }
            }
        }
        
        if shouldExpandNow {
            switch self.audioTranscriptionState {
            case .expanded:
                self.audioTranscriptionState = .collapsed
                self.isWaitingForCollapse = true
                self.requestUpdateLayout(true)
                self.updateTranscriptionExpanded?(self.audioTranscriptionState)
            case .collapsed:
                self.audioTranscriptionState = .inProgress
                self.requestUpdateLayout(true)
            default:
                break
            }
        }
    }
    
    private func presentAudioTranscriptionTooltip(finished: Bool) -> Bool {
        guard let arguments = self.arguments, !arguments.associatedData.isPremium else {
            return false
        }
        
        let presentationData = arguments.context.sharedContext.currentPresentationData.with { $0 }
        var text: String?
        var timeout: Double = 5.0
        
        let currentTime = Int32(Date().timeIntervalSince1970)
        if let cooldownUntilTime = arguments.associatedData.audioTranscriptionTrial.cooldownUntilTime, cooldownUntilTime > currentTime {
            let premiumConfiguration = PremiumConfiguration.with(appConfiguration: arguments.context.currentAppConfiguration.with { $0 })
            
            let time = stringForMediumDate(timestamp: cooldownUntilTime, strings: arguments.presentationData.strings, dateTimeFormat: arguments.presentationData.dateTimeFormat)
            let usedString = arguments.presentationData.strings.Conversation_FreeTranscriptionCooldownTooltip(premiumConfiguration.audioTransciptionTrialCount)
            let waitString = arguments.presentationData.strings.Conversation_FreeTranscriptionWaitOrSubscribe(time).string
            let fullString = "\(usedString) \(waitString)"
            text = fullString
            
            if self.hapticFeedback == nil {
                self.hapticFeedback = HapticFeedback()
            }
            self.hapticFeedback?.impact(.medium)
            timeout = 7.0
        } else if finished {
            let remainingCount = arguments.associatedData.audioTranscriptionTrial.remainingCount
            text = arguments.presentationData.strings.Conversation_FreeTranscriptionLimitTooltip(remainingCount)
        }
        
        guard let text else {
            return false
        }
        let context = arguments.context
        let tipController = UndoOverlayController(presentationData: presentationData, content: .universal(animation: "Transcribe", scale: 0.06, colors: [:], title: nil, text: text, customUndoText: nil, timeout: timeout), elevatedLayout: false, position: .top, animateInAsReplacement: false, action: { action in
            if case .info = action {
                var replaceImpl: ((ViewController) -> Void)?
                let controller = context.sharedContext.makePremiumDemoController(context: context, subject: .voiceToText, forceDark: false, action: {
                    let controller = context.sharedContext.makePremiumIntroController(context: context, source: .settings, forceDark: false, dismissed: nil)
                    replaceImpl?(controller)
                }, dismissed: nil)
                replaceImpl = { [weak controller] c in
                    controller?.replace(with: c)
                }
                arguments.controllerInteraction.navigationController()?.pushViewController(controller, animated: true)
                return true
            }
            return false
        })
        arguments.controllerInteraction.presentControllerInCurrent(tipController, nil)
        return true
    }
    
    public func asyncLayout() -> (Arguments) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, (Bool, ListViewItemUpdateAnimation, ListViewItemApply?) -> Void))) {
        let currentFile = self.file
        
        let titleAsyncLayout = TextNode.asyncLayout(self.titleNode)
        let descriptionAsyncLayout = TextNode.asyncLayout(self.descriptionNode)
        let descriptionMeasuringAsyncLayout = TextNode.asyncLayout(self.descriptionMeasuringNode)
        let textAsyncLayout = TextNode.asyncLayout(self.textNode)
        let statusLayout = self.dateAndStatusNode.asyncLayout()
        
        let currentMessage = self.message
        let audioTranscriptionState = self.audioTranscriptionState
        let forcedAudioTranscriptionText = self.forcedAudioTranscriptionText
        
        return { arguments in
            return (CGFloat.greatestFiniteMagnitude, { constrainedSize in
                let titleFont = Font.regular(floor(arguments.presentationData.fontSize.baseDisplaySize * 16.0 / 17.0))
                let descriptionFont = Font.with(size: floor(arguments.presentationData.fontSize.baseDisplaySize * 13.0 / 17.0), design: .regular, weight: .regular, traits: [.monospacedNumbers])
                let durationFont = Font.regular(floor(arguments.presentationData.fontSize.baseDisplaySize * 11.0 / 17.0))
                
                var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
                var updatedStatusSignal: Signal<(FileMediaResourceStatus, MediaResourceStatus?), NoError>?
                var updatedAudioLevelEventsSignal: Signal<Float, NoError>?
                var updatedPlaybackStatusSignal: Signal<MediaPlayerStatus, NoError>?
                var updatedFetchControls: FetchControls?
                
                var mediaUpdated = false
                if let currentFile = currentFile {
                    mediaUpdated = arguments.file != currentFile
                } else {
                    mediaUpdated = true
                }
                
                var statusUpdated = mediaUpdated
                if currentMessage?.id != arguments.message.id || currentMessage?.flags != arguments.message.flags {
                    statusUpdated = true
                }
                
                var hasThumbnail = (!arguments.file.previewRepresentations.isEmpty || arguments.file.immediateThumbnailData != nil) && !arguments.file.isMusic && !arguments.file.isVoice && !arguments.file.isInstantVideo
                var hasThumbnailImage = !arguments.file.previewRepresentations.isEmpty || arguments.file.immediateThumbnailData != nil
                if case let .update(media) = arguments.attributes.updatingMedia?.media, let file = media.media as? TelegramMediaFile {
                    hasThumbnail = largestImageRepresentation(file.previewRepresentations) != nil || file.immediateThumbnailData != nil || file.mimeType.hasPrefix("image/")
                    hasThumbnailImage = hasThumbnail
                }
                
                if mediaUpdated {
                    if hasThumbnailImage {
                        updateImageSignal = chatMessageImageFile(account: arguments.context.account, userLocation: .peer(arguments.message.id.peerId), fileReference: .message(message: MessageReference(arguments.message), media: arguments.file), thumbnail: true)
                    }
                    
                    updatedFetchControls = FetchControls(fetch: { [weak self] userInitiated in
                        if let strongSelf = self {
                            strongSelf.fetchDisposable.set(messageMediaFileInteractiveFetched(context: arguments.context, message: arguments.message, file: arguments.file, userInitiated: userInitiated).startStrict())
                        }
                    }, cancel: {
                        messageMediaFileCancelInteractiveFetch(context: arguments.context, messageId: arguments.message.id, file: arguments.file)
                    })
                }
                
                if statusUpdated {
                    if arguments.message.flags.isSending {
                        updatedStatusSignal = combineLatest(messageFileMediaResourceStatus(context: arguments.context, file: arguments.file, message: EngineMessage(arguments.message), isRecentActions: arguments.isRecentActions), messageMediaFileStatus(context: arguments.context, messageId: arguments.message.id, file: arguments.file))
                        |> map { resourceStatus, actualFetchStatus -> (FileMediaResourceStatus, MediaResourceStatus?) in
                            return (resourceStatus, actualFetchStatus)
                        }
                        updatedAudioLevelEventsSignal = messageFileMediaPlaybackAudioLevelEvents(context: arguments.context, file: arguments.file, message: EngineMessage(arguments.message), isRecentActions: arguments.isRecentActions, isGlobalSearch: false, isDownloadList: false)
                    } else {
                        updatedStatusSignal = messageFileMediaResourceStatus(context: arguments.context, file: arguments.file, message: EngineMessage(arguments.message), isRecentActions: arguments.isRecentActions)
                        |> map { resourceStatus -> (FileMediaResourceStatus, MediaResourceStatus?) in
                            return (resourceStatus, nil)
                        }
                        updatedAudioLevelEventsSignal = messageFileMediaPlaybackAudioLevelEvents(context: arguments.context, file: arguments.file, message: EngineMessage(arguments.message), isRecentActions: arguments.isRecentActions, isGlobalSearch: false, isDownloadList: false)
                    }
                    updatedPlaybackStatusSignal = messageFileMediaPlaybackStatus(context: arguments.context, file: arguments.file, message: EngineMessage(arguments.message), isRecentActions: arguments.isRecentActions, isGlobalSearch: false, isDownloadList: false)
                }
                                
                var isAudio = false
                var audioWaveform: AudioWaveform?
                var isVoice = false
                var audioDuration: Int32 = 0
                var isConsumed: Bool?
                
                var consumableContentIcon: UIImage?
                for attribute in arguments.message.attributes {
                    if let attribute = attribute as? ConsumableContentMessageAttribute {
                        if !attribute.consumed {
                            if arguments.incoming {
                                consumableContentIcon = PresentationResourcesChat.chatBubbleConsumableContentIncomingIcon(arguments.presentationData.theme.theme)
                            } else {
                                consumableContentIcon = PresentationResourcesChat.chatBubbleConsumableContentOutgoingIcon(arguments.presentationData.theme.theme)
                            }
                        }
                        isConsumed = attribute.consumed
                        break
                    }
                }
                                
                var candidateTitleString: NSAttributedString?
                var candidateDescriptionString: NSAttributedString?
                
                let messageTheme = arguments.incoming ? arguments.presentationData.theme.theme.chat.message.incoming : arguments.presentationData.theme.theme.chat.message.outgoing
                let isInstantVideo = arguments.file.isInstantVideo
                for attribute in arguments.file.attributes {
                    if case let .Video(videoDuration, _, flags, _, _, _) = attribute, flags.contains(.instantRoundVideo) {
                        isAudio = true
                        isVoice = true
                        
                        let durationString = stringForDuration(Int32(videoDuration))
                        candidateDescriptionString = NSAttributedString(string: durationString, font: durationFont, textColor: messageTheme.fileDurationColor)
                    }
                    if case let .Audio(voice, duration, title, performer, waveform) = attribute {
                        isAudio = true
                        
                        let voice = voice || isInstantVideo
                        
                        if let forcedResourceStatus = arguments.forcedResourceStatus, statusUpdated {
                            updatedStatusSignal = .single((forcedResourceStatus, nil))
                        } else if let currentUpdatedStatusSignal = updatedStatusSignal {
                            updatedStatusSignal = currentUpdatedStatusSignal
                            |> map { status, _ in
                                switch status.mediaStatus {
                                    case let .fetchStatus(fetchStatus):
                                        if !voice && !arguments.message.flags.isSending {
                                            return (FileMediaResourceStatus(mediaStatus: .fetchStatus(.Local), fetchStatus: status.fetchStatus), nil)
                                        } else {
                                            return (FileMediaResourceStatus(mediaStatus: .fetchStatus(fetchStatus), fetchStatus: status.fetchStatus), nil)
                                        }
                                    case .playbackStatus:
                                        return (status, nil)
                                }
                            }
                        }
                        
                        audioDuration = Int32(duration)
                        if voice {
                            isVoice = true
                            let durationString = stringForDuration(audioDuration)
                            candidateDescriptionString = NSAttributedString(string: durationString, font: durationFont, textColor: messageTheme.fileDurationColor)
                            if let waveform = waveform {
                                audioWaveform = AudioWaveform(bitstream: waveform, bitsPerSample: 5)
                            }
                        } else {
                            candidateTitleString = NSAttributedString(string: title ?? (arguments.file.fileName ?? "Unknown Track"), font: titleFont, textColor: arguments.customTintColor ?? messageTheme.fileTitleColor)
                            let descriptionText: String
                            if let performer = performer {
                                descriptionText = performer.trimmingTrailingSpaces()
                            } else if let size = arguments.file.size, size > 0 && size != .max {
                                descriptionText = dataSizeString(size, formatting: DataSizeStringFormatting(chatPresentationData: arguments.presentationData))
                            } else {
                                descriptionText = ""
                            }
                            candidateDescriptionString = NSAttributedString(string: descriptionText, font: descriptionFont, textColor: messageTheme.fileDescriptionColor)
                        }
                    }
                }
                
                if isInstantVideo && audioWaveform == nil {
                    let waveformBase64 = "DAAOAAkACQAGAAwADwAMABAADQAPABsAGAALAA0AGAAfABoAHgATABgAGQAYABQADAAVABEAHwANAA0ACQAWABkACQAOAAwACQAfAAAAGQAVAAAAEwATAAAACAAfAAAAHAAAABwAHwAAABcAGQAAABQADgAAABQAHwAAAB8AHwAAAAwADwAAAB8AEwAAABoAFwAAAB8AFAAAAAAAHwAAAAAAHgAAAAAAHwAAAAAAHwAAAAAAHwAAAAAAHwAAAAAAHwAAAAAAAAA="
                    audioWaveform = AudioWaveform(bitstream: Data(base64Encoded: waveformBase64)!, bitsPerSample: 5)
                }
                                
                var titleString: NSAttributedString?
                var descriptionString: NSAttributedString?
                
                if let candidateTitleString = candidateTitleString {
                    titleString = candidateTitleString
                } else if !isVoice {
                    titleString = NSAttributedString(string: arguments.file.fileName ?? "File", font: titleFont, textColor: arguments.customTintColor ?? messageTheme.fileTitleColor)
                }
                
                if let candidateDescriptionString = candidateDescriptionString {
                    descriptionString = candidateDescriptionString
                } else if !isVoice {
                    let descriptionText: String
                    if let size = arguments.file.size, size > 0 && size != .max {
                        descriptionText = dataSizeString(size, formatting: DataSizeStringFormatting(chatPresentationData: arguments.presentationData))
                    } else {
                        descriptionText = ""
                    }
                    descriptionString = NSAttributedString(string: descriptionText, font: descriptionFont, textColor: messageTheme.fileDescriptionColor)
                }
                
                var textConstrainedSize = CGSize(width: constrainedSize.width - 44.0 - 8.0, height: constrainedSize.height)
                if hasThumbnail {
                    textConstrainedSize.width -= 80.0
                }
                
                let streamingProgressDiameter: CGFloat = 20.0
                
                let (titleLayout, titleApply) = titleAsyncLayout(TextNodeLayoutArguments(attributedString: titleString, backgroundColor: nil, maximumNumberOfLines: hasThumbnail ? 2 : 1, truncationType: .middle, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                let (descriptionLayout, descriptionApply) = descriptionAsyncLayout(TextNodeLayoutArguments(attributedString: descriptionString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .middle, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                let isViewOnceMessage = isVoice && arguments.message.minAutoremoveOrClearTimeout == viewOnceTimeout
                
                let fileSizeString: String
                if let _ = arguments.file.size {
                    fileSizeString = "000.0 MB"
                } else {
                    fileSizeString = ""
                }
                let (descriptionMeasuringLayout, descriptionMeasuringApply) = descriptionMeasuringAsyncLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "\(fileSizeString) / \(fileSizeString)", font: descriptionFont, textColor: .black), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .middle, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                let descriptionMaxWidth = max(descriptionLayout.size.width, descriptionMeasuringLayout.size.width)
                let textFont = arguments.presentationData.messageFont
                var textString: NSAttributedString?
                var updatedAudioTranscriptionState: AudioTranscriptionButtonComponent.TranscriptionState?
                
                var displayTranscribe = false
                if Namespaces.Message.allNonRegular.contains(arguments.message.id.namespace) {
                    displayTranscribe = false
                } else if arguments.message.id.peerId.namespace != Namespaces.Peer.SecretChat && !isViewOnceMessage && !arguments.presentationData.isPreview {
                    let premiumConfiguration = PremiumConfiguration.with(appConfiguration: arguments.context.currentAppConfiguration.with { $0 })
                    if arguments.associatedData.isPremium {
                        displayTranscribe = true
                    } else if premiumConfiguration.audioTransciptionTrialCount > 0 {
                        if arguments.incoming {
                            if audioDuration < premiumConfiguration.audioTransciptionTrialMaxDuration {
                                displayTranscribe = true
                            }
                        }
                    } else if arguments.associatedData.alwaysDisplayTranscribeButton.canBeDisplayed {
                        if audioDuration >= 60 {
                            displayTranscribe = true
                        } else if arguments.incoming && isConsumed == false && arguments.associatedData.alwaysDisplayTranscribeButton.displayForNotConsumed {
                            displayTranscribe = true
                        }
                    } else if arguments.associatedData.alwaysDisplayTranscribeButton.providedByGroupBoost {
                        displayTranscribe = true
                    }
                }
                
                let transcribedText = forcedAudioTranscriptionText ?? transcribedText(message: arguments.message)
                
                switch audioTranscriptionState {
                case .inProgress:
                    if transcribedText != nil {
                        updatedAudioTranscriptionState = .expanded
                    }
                default:
                    break
                }
                
                let currentTime = Int32(Date().timeIntervalSince1970)
                if transcribedText == nil, let cooldownUntilTime = arguments.associatedData.audioTranscriptionTrial.cooldownUntilTime, cooldownUntilTime > currentTime {
                    updatedAudioTranscriptionState = .locked
                }
                
                let effectiveAudioTranscriptionState = updatedAudioTranscriptionState ?? audioTranscriptionState
                
                var displayTrailingAnimatedDots = false
                
                if let transcribedText = transcribedText, case .expanded = effectiveAudioTranscriptionState {
                    switch transcribedText {
                    case let .success(text, isPending):
                        textString = NSAttributedString(string: text, font: textFont, textColor: messageTheme.primaryTextColor)
                        
                        /*#if DEBUG
                        var isPending = isPending
                        if "".isEmpty {
                            isPending = true
                        }
                        #endif*/
                        
                        if isPending {
                            let modifiedString = NSMutableAttributedString(attributedString: textString!)
                            modifiedString.append(NSAttributedString(string: "...", font: textFont, textColor: .clear))
                            displayTrailingAnimatedDots = true
                            textString = modifiedString
                        }
                    case let .error(error):
                        let errorTextFont = Font.regular(floor(arguments.presentationData.fontSize.baseDisplaySize * 15.0 / 17.0))
                        let errorText: String
                        switch error {
                        case .generic:
                            errorText = arguments.presentationData.strings.Message_AudioTranscription_ErrorEmpty
                        case .tooLong:
                            errorText = arguments.presentationData.strings.Message_AudioTranscription_ErrorTooLong
                        }
                        textString = NSAttributedString(string: errorText, font: errorTextFont, textColor: messageTheme.secondaryTextColor)
                    }
                } else {
                    textString = nil
                }
                
                let horizontalInset: CGFloat = (arguments.layoutConstants.bubble.edgeInset + arguments.layoutConstants.bubble.borderInset) * 2.0
                let inlineTextConstrainedSize = CGSize(width: constrainedSize.width, height: constrainedSize.height)
                let (textLayout, textApply) = textAsyncLayout(TextNodeLayoutArguments(attributedString: textString, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: inlineTextConstrainedSize.width - horizontalInset, height: .greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                let minVoiceWidth: CGFloat = 120.0
                let maxVoiceWidth = constrainedSize.width - 36.0
                let maxVoiceLength: CGFloat = 30.0
                let minVoiceLength: CGFloat = 2.0
                
                let progressDiameter: CGFloat = 44.0
                
                var iconFrame: CGRect?
                let progressFrame: CGRect
                let controlAreaWidth: CGFloat
                
                if hasThumbnail {
                    let currentIconFrame: CGRect
                    if arguments.isAttachedContentBlock {
                        currentIconFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 59.0, height: 59.0))
                        controlAreaWidth = 71.0
                    } else {
                        currentIconFrame = CGRect(origin: CGPoint(x: -1.0, y: -7.0), size: CGSize(width: 74.0, height: 74.0))
                        controlAreaWidth = 86.0
                    }
                    iconFrame = currentIconFrame
                    progressFrame = CGRect(
                        origin: CGPoint(
                            x: currentIconFrame.minX + floor((currentIconFrame.size.width - progressDiameter) / 2.0),
                            y: currentIconFrame.minY + floor((currentIconFrame.size.height - progressDiameter) / 2.0)
                        ),
                        size: CGSize(width: progressDiameter, height: progressDiameter)
                    )
                } else {
                    if arguments.isAttachedContentBlock {
                        progressFrame = CGRect(
                            origin: CGPoint(x: 3.0, y: 0.0),
                            size: CGSize(width: progressDiameter, height: progressDiameter)
                        )
                        controlAreaWidth = progressFrame.maxX + 8.0
                    } else {
                        progressFrame = CGRect(
                            origin: CGPoint(x: 3.0, y: isVoice ? -3.0 : 0.0),
                            size: CGSize(width: progressDiameter, height: progressDiameter)
                        )
                        controlAreaWidth = progressFrame.maxX + 8.0
                    }
                }
                
                var statusSuggestedWidthAndContinue: (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))?
                if let statusType = arguments.dateAndStatusType {
                    var edited = false
                    if arguments.attributes.updatingMedia != nil {
                        edited = true
                    }
                    var viewCount: Int?
                    var dateReplies = 0
                    var dateReactionsAndPeers = mergedMessageReactionsAndPeers(accountPeerId: arguments.context.account.peerId, accountPeer: arguments.associatedData.accountPeer, message: arguments.topMessage)
                    if arguments.topMessage.isRestricted(platform: "ios", contentSettings: arguments.context.currentContentSettings.with { $0 }) || arguments.presentationData.isPreview {
                        dateReactionsAndPeers = ([], [])
                    }
                    for attribute in arguments.message.attributes {
                        if let attribute = attribute as? EditedMessageAttribute {
                            edited = !attribute.isHidden
                        } else if let attribute = attribute as? ViewCountMessageAttribute {
                            viewCount = attribute.count
                        } else if let attribute = attribute as? ReplyThreadMessageAttribute, case .peer = arguments.chatLocation {
                            if let channel = arguments.message.peers[arguments.message.id.peerId] as? TelegramChannel, case .group = channel.info {
                                dateReplies = Int(attribute.count)
                            }
                        }
                    }
                    if arguments.forcedIsEdited {
                        edited = true
                    }
                    
                    let dateFormat: MessageTimestampStatusFormat
                    if arguments.presentationData.isPreview {
                        dateFormat = .full
                    } else {
                        dateFormat = .regular
                    }
                    let dateText = stringForMessageTimestampStatus(accountPeerId: arguments.context.account.peerId, message: arguments.message, dateTimeFormat: arguments.presentationData.dateTimeFormat, nameDisplayOrder: arguments.presentationData.nameDisplayOrder, strings: arguments.presentationData.strings, format: dateFormat, associatedData: arguments.associatedData)
                    
                    let displayReactionsInline = shouldDisplayInlineDateReactions(message: arguments.message, isPremium: arguments.associatedData.isPremium, forceInline: arguments.associatedData.forceInlineReactions)
                    var reactionSettings: ChatMessageDateAndStatusNode.TrailingReactionSettings?
                    
                    if displayReactionsInline || arguments.displayReactions {
                        reactionSettings = ChatMessageDateAndStatusNode.TrailingReactionSettings(displayInline: displayReactionsInline, preferAdditionalInset: !displayReactionsInline)
                    }
                    
                    let statusLayoutInput: ChatMessageDateAndStatusNode.LayoutInput
                    if let _ = textString {
                        statusLayoutInput = .trailingContent(contentWidth: textLayout.hasRTL ? 1000.0 : textLayout.trailingLineWidth, reactionSettings: reactionSettings)
                    } else {
                        statusLayoutInput = .trailingContent(contentWidth: iconFrame == nil ? 1000.0 : controlAreaWidth, reactionSettings: reactionSettings)
                    }
                    
                    statusSuggestedWidthAndContinue = statusLayout(ChatMessageDateAndStatusNode.Arguments(
                        context: arguments.context,
                        presentationData: arguments.presentationData,
                        edited: edited && !arguments.presentationData.isPreview,
                        impressionCount: !arguments.presentationData.isPreview ? viewCount : nil,
                        dateText: dateText,
                        type: statusType,
                        layoutInput: statusLayoutInput,
                        constrainedSize: constrainedSize,
                        availableReactions: arguments.associatedData.availableReactions,
                        savedMessageTags: arguments.associatedData.savedMessageTags,
                        reactions: dateReactionsAndPeers.reactions,
                        reactionPeers: dateReactionsAndPeers.peers,
                        displayAllReactionPeers: arguments.message.id.peerId.namespace == Namespaces.Peer.CloudUser,
                        areReactionsTags: arguments.message.areReactionsTags(accountPeerId: arguments.context.account.peerId),
                        messageEffect: arguments.message.messageEffect(availableMessageEffects: arguments.associatedData.availableMessageEffects),
                        replyCount: dateReplies,
                        isPinned: arguments.isPinned && !arguments.associatedData.isInPinnedListMode,
                        hasAutoremove: arguments.message.isSelfExpiring,
                        canViewReactionList: canViewMessageReactionList(message: arguments.topMessage),
                        animationCache: arguments.controllerInteraction.presentationContext.animationCache,
                        animationRenderer: arguments.controllerInteraction.presentationContext.animationRenderer
                    ))
                }
                
                var minLayoutWidth: CGFloat
                if hasThumbnail {
                    minLayoutWidth = max(titleLayout.size.width, descriptionMaxWidth) + 86.0
                } else if isVoice {
                    let descriptionAndStatusWidth = descriptionLayout.size.width
                    
                    let calcDuration = max(minVoiceLength, min(maxVoiceLength, CGFloat(audioDuration)))
                    minLayoutWidth = minVoiceWidth + (maxVoiceWidth - minVoiceWidth) * (calcDuration - minVoiceLength) / (maxVoiceLength - minVoiceLength)
                    if displayTranscribe {
                        minLayoutWidth += 30.0 + 8.0
                    }
                    minLayoutWidth = max(descriptionAndStatusWidth + 56, minLayoutWidth)
                } else {
                    minLayoutWidth = max(titleLayout.size.width, descriptionMaxWidth) + 44.0 + 8.0
                }
                
                var statusHeightAddition: CGFloat = 0.0
                if let statusSuggestedWidthAndContinue = statusSuggestedWidthAndContinue {
                    if statusSuggestedWidthAndContinue.0 > minLayoutWidth {
                        statusHeightAddition = 6.0
                    }
                    minLayoutWidth = max(minLayoutWidth, statusSuggestedWidthAndContinue.0)
                }
                
                minLayoutWidth = max(minLayoutWidth, textLayout.size.width + horizontalInset)
                                
                let fileIconImage: UIImage?
                var viewOnceIconImage: UIImage?
                if hasThumbnail {
                    fileIconImage = nil
                } else {
                    let principalGraphics = PresentationResourcesChat.principalGraphics(theme: arguments.presentationData.theme.theme, wallpaper: arguments.presentationData.theme.wallpaper, bubbleCorners: arguments.presentationData.chatBubbleCorners)
                    
                    fileIconImage = arguments.incoming ? principalGraphics.radialIndicatorFileIconIncoming : principalGraphics.radialIndicatorFileIconOutgoing
                    viewOnceIconImage = principalGraphics.radialIndicatorViewOnceIcon
                }
                
                return (minLayoutWidth, { boundingWidth in
                    let titleAndDescriptionHeight = titleLayout.size.height - 1.0 + descriptionLayout.size.height
                    
                    let normHeight: CGFloat
                    if hasThumbnail {
                        if arguments.isAttachedContentBlock {
                            normHeight = 58.0
                        } else {
                            normHeight = 64.0
                        }
                    } else {
                        normHeight = 44.0
                    }
                    let titleFrame = CGRect(origin: CGPoint(x: controlAreaWidth, y: floor((normHeight - titleAndDescriptionHeight) / 2.0)), size: titleLayout.size)
                    
                    let descriptionFrame: CGRect
                    if isVoice {
                        descriptionFrame = CGRect(origin: CGPoint(x: 56.0, y: 22.0), size: descriptionLayout.size)
                    } else {
                        descriptionFrame = CGRect(origin: CGPoint(x: titleFrame.minX, y: titleFrame.maxY - 1.0), size: descriptionLayout.size)
                    }
                    
                    var fittedLayoutSize: CGSize
                    if hasThumbnail {
                        let textSizes = titleFrame.union(descriptionFrame).size
                        fittedLayoutSize = CGSize(width: textSizes.width + controlAreaWidth, height: 59.0)
                    } else if isVoice {
                        fittedLayoutSize = CGSize(width: minLayoutWidth, height: 38.0)
                    } else {
                        let unionSize = titleFrame.union(descriptionFrame).union(progressFrame).size
                        fittedLayoutSize = CGSize(width: unionSize.width, height: unionSize.height)
                    }
                    
                    if textString != nil {
                        fittedLayoutSize.width = max(fittedLayoutSize.width + horizontalInset, textLayout.size.width)
                        fittedLayoutSize.height += textLayout.size.height + 5.0
                    }
                    
                    var statusSizeAndApply: (CGSize, (ListViewItemUpdateAnimation) -> Void)?
                    if let statusSuggestedWidthAndContinue = statusSuggestedWidthAndContinue {
                        statusSizeAndApply = statusSuggestedWidthAndContinue.1(boundingWidth)
                    }
                    var statusOffset: CGFloat = 0.0
                    if let statusSizeAndApply = statusSizeAndApply {
                        fittedLayoutSize.width = max(fittedLayoutSize.width, statusSizeAndApply.0.width)
                        fittedLayoutSize.height += statusSizeAndApply.0.height
                        if textString == nil {
                            if !statusSizeAndApply.0.height.isZero && iconFrame == nil {
                                statusOffset = -10.0
                                fittedLayoutSize.height += statusOffset
                            }
                            fittedLayoutSize.height += statusHeightAddition
                        }
                    }
                    
                    let streamingCacheStatusFrame: CGRect
                    if (isAudio && !isVoice) || arguments.file.previewRepresentations.isEmpty {
                        streamingCacheStatusFrame = CGRect(origin: CGPoint(x: progressFrame.maxX - streamingProgressDiameter + 2.0, y: progressFrame.maxY - streamingProgressDiameter + 2.0), size: CGSize(width: streamingProgressDiameter, height: streamingProgressDiameter))
                    } else {
                        streamingCacheStatusFrame = CGRect()
                    }
                    
                    return (fittedLayoutSize, { [weak self] synchronousLoads, animation, info in
                        if let strongSelf = self {
                            strongSelf.context = arguments.context
                            strongSelf.presentationData = arguments.presentationData
                            strongSelf.message = arguments.message
                            strongSelf.arguments = arguments
                            strongSelf.file = arguments.file
                            
                            let _ = titleApply()
                            let _ = descriptionApply()
                            let _ = descriptionMeasuringApply()
                            
                            strongSelf.titleNode.frame = titleFrame
                            strongSelf.descriptionNode.frame = descriptionFrame
                            strongSelf.descriptionMeasuringNode.frame = CGRect(origin: CGPoint(), size: descriptionMeasuringLayout.size)
                                    
                            if let updatedAudioTranscriptionState = updatedAudioTranscriptionState {
                                strongSelf.audioTranscriptionState = updatedAudioTranscriptionState
                            }
                                
                            switch updatedAudioTranscriptionState {
                                case .expanded:
                                    info?.setInvertOffsetDirection()
                                default:
                                    if strongSelf.isWaitingForCollapse {
                                        strongSelf.isWaitingForCollapse = false
                                        info?.setInvertOffsetDirection()
                                    }
                            }
                            
                            if let consumableContentIcon = consumableContentIcon {
                                if strongSelf.consumableContentNode.supernode == nil {
                                    strongSelf.addSubnode(strongSelf.consumableContentNode)
                                }
                                if strongSelf.consumableContentNode.image !== consumableContentIcon {
                                    strongSelf.consumableContentNode.image = consumableContentIcon
                                }
                                strongSelf.consumableContentNode.frame = CGRect(origin: CGPoint(x: descriptionFrame.maxX + 5.0, y: descriptionFrame.minY + 5.0), size: consumableContentIcon.size)
                            } else if strongSelf.consumableContentNode.supernode != nil {
                                strongSelf.consumableContentNode.removeFromSupernode()
                            }
                            
                            let statusReferenceFrame: CGRect
                            if let iconFrame = iconFrame {
                                statusReferenceFrame = iconFrame
                            } else {
                                statusReferenceFrame = progressFrame.offsetBy(dx: 0.0, dy: 8.0)
                            }
                            
                            if textString == nil, strongSelf.textNode.supernode != nil, animation.isAnimated {
                                if let snapshotView = strongSelf.textNode.view.snapshotContentTree() {
                                    snapshotView.frame = strongSelf.textNode.frame
                                    strongSelf.textClippingNode.view.insertSubview(snapshotView, aboveSubview: strongSelf.textNode.view)
                                    
                                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                                        snapshotView?.removeFromSuperview()
                                    })
                                }
                            }
                            
                            let _ = textApply()
                            let textFrame = CGRect(origin: CGPoint(x: arguments.layoutConstants.text.bubbleInsets.left - arguments.layoutConstants.file.bubbleInsets.left, y: statusReferenceFrame.maxY + 1.0), size: textLayout.size)
                            let textClippingFrame = CGRect(origin: textFrame.origin, size: CGSize(width: textFrame.width, height: textFrame.height + 8.0))
                            if textString != nil {
                                if strongSelf.textClippingNode.supernode == nil {
                                    strongSelf.textClippingNode.frame = textClippingFrame
                                    strongSelf.textNode.frame = CGRect(origin: CGPoint(), size: textFrame.size)
                                    
                                    strongSelf.addSubnode(strongSelf.textClippingNode)
                                    if animation.isAnimated {
                                        strongSelf.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                                        
                                        strongSelf.textClippingNode.frame = CGRect(origin: textClippingFrame.origin, size: CGSize(width: textClippingFrame.width, height: 0.0))
                                        animation.animator.updateFrame(layer: strongSelf.textClippingNode.layer, frame: textClippingFrame, completion: nil)
                                        
                                        if let maskImage = generateGradientImage(size: CGSize(width: 8.0, height: 10.0), colors: [UIColor.black, UIColor.black, UIColor.clear], locations: [0.0, 0.1, 1.0], direction: .vertical) {
                                            let maskView = UIImageView(image: maskImage.stretchableImage(withLeftCapWidth: 0, topCapHeight: 1))
                                            strongSelf.textClippingNode.view.mask = maskView
                                            
                                            maskView.frame = CGRect(origin: CGPoint(), size: CGSize(width: textClippingFrame.width, height: maskImage.size.height))
                                            animation.animator.updateFrame(layer: maskView.layer, frame: CGRect(origin: CGPoint(), size: textClippingFrame.size), completion: { [weak maskView] _ in
                                                maskView?.removeFromSuperview()
                                                guard let strongSelf = self else {
                                                    return
                                                }
                                                strongSelf.textClippingNode.view.mask = nil
                                            })
                                        }
                                    }
                                } else if animation.isAnimated && strongSelf.textClippingNode.bounds.size.height != textClippingFrame.size.height {
                                    if let maskImage = generateGradientImage(size: CGSize(width: 8.0, height: 10.0), colors: [UIColor.black, UIColor.black, UIColor.clear], locations: [0.0, 0.1, 1.0], direction: .vertical) {
                                        let maskView = UIImageView(image: maskImage.stretchableImage(withLeftCapWidth: 0, topCapHeight: 1))
                                        strongSelf.textClippingNode.view.mask = maskView
                                        
                                        maskView.frame = CGRect(origin: CGPoint(), size: CGSize(width: strongSelf.textClippingNode.bounds.width, height: strongSelf.textClippingNode.bounds.height))
                                        animation.animator.updateFrame(layer: maskView.layer, frame: CGRect(origin: CGPoint(), size: textClippingFrame.size), completion: { [weak maskView] _ in
                                            maskView?.removeFromSuperview()
                                            guard let strongSelf = self else {
                                                return
                                            }
                                            strongSelf.textClippingNode.view.mask = nil
                                        })
                                        
                                        animation.animator.updateFrame(layer: strongSelf.textClippingNode.layer, frame: textClippingFrame, completion: nil)
                                        strongSelf.textNode.frame = CGRect(origin: CGPoint(), size: textFrame.size)
                                    } else {
                                        strongSelf.textClippingNode.frame = textClippingFrame
                                        strongSelf.textNode.frame = CGRect(origin: CGPoint(), size: textFrame.size)
                                    }
                                } else {
                                    strongSelf.textClippingNode.frame = textClippingFrame
                                    strongSelf.textNode.frame = CGRect(origin: CGPoint(), size: textFrame.size)
                                }
                            } else {
                                if strongSelf.textClippingNode.supernode != nil {
                                    if animation.isAnimated {
                                        if let maskImage = generateGradientImage(size: CGSize(width: 8.0, height: 10.0), colors: [UIColor.black, UIColor.black, UIColor.clear], locations: [0.0, 0.1, 1.0], direction: .vertical) {
                                            let maskView = UIImageView(image: maskImage.stretchableImage(withLeftCapWidth: 0, topCapHeight: 1))
                                            maskView.frame = CGRect(origin: CGPoint(), size: strongSelf.textClippingNode.bounds.size)
                                            
                                            strongSelf.textClippingNode.view.mask = maskView
                                            
                                            animation.animator.updateFrame(layer: maskView.layer, frame: CGRect(origin: CGPoint(), size: CGSize(width: strongSelf.textClippingNode.bounds.width, height: maskImage.size.height)), completion: { [weak maskView] _ in
                                                maskView?.removeFromSuperview()
                                                guard let strongSelf = self else {
                                                    return
                                                }
                                                strongSelf.textClippingNode.view.mask = nil
                                            })
                                        }
                                        
                                        animation.animator.updateFrame(layer: strongSelf.textClippingNode.layer, frame: CGRect(origin: strongSelf.textClippingNode.frame.origin, size: CGSize(width: strongSelf.textClippingNode.bounds.width, height: 0.0)), completion: nil)
                                        
                                        strongSelf.textNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { completed in
                                            guard let strongSelf = self, completed else {
                                                return
                                            }
                                            
                                            strongSelf.textClippingNode.removeFromSupernode()
                                            strongSelf.textNode.layer.removeAllAnimations()
                                        })
                                    } else {
                                        strongSelf.textClippingNode.removeFromSupernode()
                                    }
                                }
                            }
                            
                            if displayTrailingAnimatedDots {
                                let transcriptionPendingIndicator: ComponentHostView<Empty>
                                if let current = strongSelf.transcriptionPendingIndicator {
                                    transcriptionPendingIndicator = current
                                } else {
                                    transcriptionPendingIndicator = ComponentHostView<Empty>()
                                    strongSelf.transcriptionPendingIndicator = transcriptionPendingIndicator
                                    strongSelf.textClippingNode.view.addSubview(transcriptionPendingIndicator)
                                }
                                
                                let indicatorComponent: AnyComponent<Empty>
                                indicatorComponent = AnyComponent(AudioTranscriptionPendingLottieIndicatorComponent(color: messageTheme.primaryTextColor, font: textFont))
                                //indicatorComponent = AnyComponent(AudioTranscriptionPendingIndicatorComponent(color: messageTheme.primaryTextColor, font: textFont))
                                
                                let indicatorSize = transcriptionPendingIndicator.update(
                                    transition: .immediate,
                                    component: indicatorComponent,
                                    environment: {},
                                    containerSize: CGSize(width: 100.0, height: 100.0)
                                )
                                
                                transcriptionPendingIndicator.frame = CGRect(origin: CGPoint(x: strongSelf.textNode.frame.minX + textLayout.trailingLineWidth - indicatorSize.width + 1.0, y: strongSelf.textNode.frame.maxY - indicatorSize.height - 6.0), size: indicatorSize)
                            } else {
                                if let transcriptionPendingIndicator = strongSelf.transcriptionPendingIndicator {
                                    strongSelf.transcriptionPendingIndicator = nil
                                    transcriptionPendingIndicator.removeFromSuperview()
                                }
                            }
                            
                            if let textSelectionNode = strongSelf.textSelectionNode {
                                let shouldUpdateLayout = textSelectionNode.frame.size != textFrame.size
                                textSelectionNode.frame = CGRect(origin: CGPoint(), size: textFrame.size)
                                textSelectionNode.highlightAreaNode.frame = CGRect(origin: CGPoint(), size: textFrame.size)
                                if shouldUpdateLayout {
                                    textSelectionNode.updateLayout()
                                }
                            }
                            
                            if let statusSizeAndApply = statusSizeAndApply {
                                let statusFrame: CGRect
                                if textString != nil {
                                    statusFrame = CGRect(origin: CGPoint(x: fittedLayoutSize.width - 6.0 - statusSizeAndApply.0.width, y: textFrame.maxY + 4.0), size: statusSizeAndApply.0)
                                } else {
                                    statusFrame = CGRect(origin: CGPoint(x: statusReferenceFrame.minX, y: statusReferenceFrame.maxY + statusOffset + statusHeightAddition), size: statusSizeAndApply.0)
                                }
                                if strongSelf.dateAndStatusNode.supernode == nil {
                                    strongSelf.dateAndStatusNode.frame = statusFrame
                                    strongSelf.addSubnode(strongSelf.dateAndStatusNode)
                                } else {
                                    animation.animator.updateFrame(layer: strongSelf.dateAndStatusNode.layer, frame: statusFrame, completion: nil)
                                }
                                statusSizeAndApply.1(animation)
                            } else if strongSelf.dateAndStatusNode.supernode != nil {
                                strongSelf.dateAndStatusNode.removeFromSupernode()
                            }
                            
                            if isVoice {
                                var scrubbingFrame = CGRect(origin: CGPoint(x: 57.0, y: 1.0), size: CGSize(width: boundingWidth - 60.0, height: 18.0))
                                if displayTranscribe {
                                    scrubbingFrame.size.width -= 30.0 + 4.0
                                }
                                
                                let waveformView: ComponentHostView<Empty>
                                let waveformTransition: ComponentTransition
                                if let current = strongSelf.waveformView {
                                    waveformView = current
                                    switch animation.transition {
                                    case .immediate:
                                        waveformTransition = .immediate
                                    case let .animated(duration, _):
                                        waveformTransition = .easeInOut(duration: duration)
                                    }
                                } else {
                                    waveformView = ComponentHostView<Empty>()
                                    strongSelf.waveformView = waveformView
                                    strongSelf.view.addSubview(waveformView)
                                    waveformTransition = .immediate
                                }
                                
                                let waveformColor: UIColor
                                if arguments.incoming {
                                    if consumableContentIcon != nil {
                                        waveformColor = messageTheme.mediaActiveControlColor
                                    } else {
                                        waveformColor = messageTheme.mediaInactiveControlColor
                                    }
                                } else {
                                    waveformColor = messageTheme.mediaInactiveControlColor
                                }
                                
                                var isTranscriptionInProgress = false
                                if case .inProgress = effectiveAudioTranscriptionState {
                                    isTranscriptionInProgress = true
                                }
                                
                                let _ = waveformView.update(
                                    transition: waveformTransition.withUserData(ComponentHostViewSkipSettingFrame()),
                                    component: AnyComponent(AudioWaveformComponent(
                                        backgroundColor: isTranscriptionInProgress ? messageTheme.mediaInactiveControlColor : waveformColor,
                                        foregroundColor: messageTheme.mediaActiveControlColor,
                                        shimmerColor: isTranscriptionInProgress ? messageTheme.mediaActiveControlColor : nil,
                                        style: .bottom,
                                        samples: audioWaveform?.samples ?? Data(),
                                        peak: audioWaveform?.peak ?? 0,
                                        status: strongSelf.playbackStatus.get(),
                                        isViewOnceMessage: isViewOnceMessage,
                                        seek: { timestamp in
                                            if let strongSelf = self, let context = strongSelf.context, let message = strongSelf.message, let type = peerMessageMediaPlayerType(EngineMessage(message)) {
                                                context.sharedContext.mediaManager.playlistControl(.seek(timestamp), type: type)
                                            }
                                        },
                                        updateIsSeeking: nil
                                    )),
                                    environment: {},
                                    containerSize: scrubbingFrame.size
                                )
                                
                                animation.animator.updateFrame(layer: waveformView.layer, frame: scrubbingFrame, completion: nil)
                                animation.animator.updateFrame(layer: waveformView.componentView!.layer, frame: CGRect(origin: CGPoint(), size: scrubbingFrame.size), completion: nil)
                                
                                if displayTranscribe {
                                    var added = false
                                    let audioTranscriptionButton: ComponentHostView<Empty>
                                    if let current = strongSelf.audioTranscriptionButton {
                                        audioTranscriptionButton = current
                                    } else {
                                        audioTranscriptionButton = ComponentHostView<Empty>()
                                        strongSelf.audioTranscriptionButton = audioTranscriptionButton
                                        strongSelf.view.addSubview(audioTranscriptionButton)
                                        added = true
                                    }
                                    let buttonTheme: AudioTranscriptionButtonComponent.Theme
                                    if let customTintColor = arguments.customTintColor {
                                        buttonTheme = .custom(customTintColor.withMultipliedAlpha(0.1), customTintColor)
                                    } else {
                                        buttonTheme = .bubble(arguments.incoming ? arguments.presentationData.theme.theme.chat.message.incoming : arguments.presentationData.theme.theme.chat.message.outgoing)
                                    }
                                    let audioTranscriptionButtonSize = audioTranscriptionButton.update(
                                        transition: animation.isAnimated ? .easeInOut(duration: 0.3) : .immediate,
                                        component: AnyComponent(AudioTranscriptionButtonComponent(
                                            theme: buttonTheme,
                                            transcriptionState: effectiveAudioTranscriptionState,
                                            pressed: {
                                                guard let strongSelf = self else {
                                                    return
                                                }
                                                strongSelf.transcribe()
                                            }
                                        )),
                                        environment: {},
                                        containerSize: CGSize(width: 30.0, height: 30.0)
                                    )
                                    
                                    let audioTranscriptionButtonFrame = CGRect(origin: CGPoint(x: boundingWidth - 30.0 + 3.0, y: -6.0), size: audioTranscriptionButtonSize)
                                    if added {
                                        audioTranscriptionButton.layer.frame = audioTranscriptionButtonFrame
                                        audioTranscriptionButton.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                                    } else {
                                        animation.animator.updateFrame(layer: audioTranscriptionButton.layer, frame: audioTranscriptionButtonFrame, completion: nil)
                                    }
                                } else {
                                    if let audioTranscriptionButton = strongSelf.audioTranscriptionButton {
                                        strongSelf.audioTranscriptionButton = nil
                                        audioTranscriptionButton.removeFromSuperview()
                                    }
                                }
                            } else {
                                if let waveformView = strongSelf.waveformView {
                                    strongSelf.waveformView = nil
                                    waveformView.removeFromSuperview()
                                }
                                if let audioTranscriptionButton = strongSelf.audioTranscriptionButton {
                                    strongSelf.audioTranscriptionButton = nil
                                    audioTranscriptionButton.removeFromSuperview()
                                }
                            }
                            
                            if let iconFrame = iconFrame {
                                let iconNode: TransformImageNode
                                if let current = strongSelf.iconNode {
                                    iconNode = current
                                } else {
                                    iconNode = TransformImageNode()
                                    strongSelf.iconNode = iconNode
                                    strongSelf.insertSubnode(iconNode, at: 0)
                                    let arguments = TransformImageArguments(corners: ImageCorners(radius: 8.0), imageSize: CGSize(width: 74.0, height: 74.0), boundingSize: CGSize(width: 74.0, height: 74.0), intrinsicInsets: UIEdgeInsets(), emptyColor: messageTheme.mediaPlaceholderColor)
                                    let apply = iconNode.asyncLayout()(arguments)
                                    apply()
                                }
                                if let updateImageSignal = updateImageSignal {
                                    iconNode.setSignal(updateImageSignal)
                                }
                                iconNode.frame = iconFrame
                            } else if let iconNode = strongSelf.iconNode {
                                iconNode.removeFromSupernode()
                                strongSelf.iconNode = nil
                            }
                            
                            if let streamingStatusNode = strongSelf.streamingStatusNode {
                                streamingStatusNode.frame = streamingCacheStatusFrame
                            }
                            
                            if var updatedStatusSignal = updatedStatusSignal {
                                if strongSelf.file?.isInstantVideo == true {
                                    updatedStatusSignal = updatedStatusSignal
                                    |> mapToThrottled { next -> Signal<(FileMediaResourceStatus, MediaResourceStatus?), NoError> in
                                        return .single(next) |> then(.complete() |> delay(0.1, queue: Queue.concurrentDefaultQueue()))
                                    }
                                }
                                strongSelf.statusDisposable.set((updatedStatusSignal |> deliverOnMainQueue).startStrict(next: { [weak strongSelf] status, actualFetchStatus in
                                    displayLinkDispatcher.dispatch {
                                        if let strongSelf = strongSelf {
                                            let firstTime = strongSelf.resourceStatus == nil
                                            strongSelf.resourceStatus = status
                                            strongSelf.actualFetchStatus = actualFetchStatus
                                            strongSelf.updateStatus(animated: !synchronousLoads || !firstTime)
                                        }
                                    }
                                }))
                            }
                            
                            if let updatedAudioLevelEventsSignal = updatedAudioLevelEventsSignal {
                                strongSelf.audioLevelEventsDisposable.set((updatedAudioLevelEventsSignal
                                |> deliverOnMainQueue).startStrict(next: { value in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.inputAudioLevel = CGFloat(value)
                                    strongSelf.playbackAudioLevelNode?.updateLevel(CGFloat(value))
                                }))
                            }
                            
                            if let updatedPlaybackStatusSignal = updatedPlaybackStatusSignal {
                                strongSelf.playbackStatus.set(updatedPlaybackStatusSignal)
                                strongSelf.playbackStatusDisposable.set((updatedPlaybackStatusSignal |> deliverOnMainQueue).startStrict(next: { [weak strongSelf] status in
                                    displayLinkDispatcher.dispatch {
                                        if let strongSelf = strongSelf {
                                            strongSelf.playerStatus = status
                                        }
                                    }
                                }))
                            }
                                                        
                            strongSelf.statusNode?.displaysAsynchronously = !arguments.presentationData.isPreview
                            strongSelf.statusNode?.frame = CGRect(origin: CGPoint(), size: progressFrame.size)

                            strongSelf.statusContainerNode.frame = progressFrame
                            strongSelf.statusContainerNode.contentRect = CGRect(origin: CGPoint(), size: progressFrame.size)
                            strongSelf.statusContainerNode.contentNode.frame = CGRect(origin: CGPoint(), size: progressFrame.size)

                            strongSelf.playbackAudioLevelNode?.frame = progressFrame.insetBy(dx: -12.0, dy: -12.0)
                            strongSelf.progressFrame = progressFrame
                            strongSelf.streamingCacheStatusFrame = streamingCacheStatusFrame
                            strongSelf.fileIconImage = fileIconImage
                            strongSelf.viewOnceIconImage = viewOnceIconImage
                            
                            if let updatedFetchControls = updatedFetchControls {
                                let _ = strongSelf.fetchControls.swap(updatedFetchControls)
                                if arguments.automaticDownload {
                                    updatedFetchControls.fetch(false)
                                }
                            }
                            
                            let isAnimated = !synchronousLoads
                            let transition: ContainedViewLayoutTransition = isAnimated ? .animated(duration: 0.2, curve: .spring) : .immediate
                            if let selection = arguments.messageSelection {
                                if let streamingStatusNode = strongSelf.streamingStatusNode {
                                    transition.updateAlpha(node: streamingStatusNode, alpha: 0.0)
                                    transition.updateTransformScale(node: streamingStatusNode, scale: 0.2)
                                }
                                let selectionFrame = CGRect(origin: CGPoint(), size: fittedLayoutSize)
                                if let selectionNode = strongSelf.selectionNode {
                                    selectionNode.frame = selectionFrame
                                    selectionNode.updateSelected(selection, animated: isAnimated)
                                } else {
                                    let type: FileMessageSelectionNode.NodeType
                                    if arguments.file.isVoice {
                                        type = .voice
                                    } else if arguments.file.isMusic || arguments.file.previewRepresentations.isEmpty {
                                        type = .file
                                    } else {
                                        type = .media
                                    }
                                    let selectionNode = FileMessageSelectionNode(theme: arguments.presentationData.theme.theme, incoming: arguments.incoming, type: type, toggle: { [weak self] value in
                                        self?.toggleSelection(value)
                                    })
                                    strongSelf.selectionNode = selectionNode
                                    strongSelf.addSubnode(selectionNode)
                                    selectionNode.frame = selectionFrame
                                    selectionNode.updateSelected(selection, animated: false)
                                    if isAnimated {
                                        selectionNode.animateIn()
                                    }
                                }
                            } else {
                                if let streamingStatusNode = strongSelf.streamingStatusNode {
                                    transition.updateAlpha(node: streamingStatusNode, alpha: 1.0)
                                    transition.updateTransformScale(node: streamingStatusNode, scale: 1.0)
                                }
                                if let selectionNode = strongSelf.selectionNode {
                                    strongSelf.selectionNode = nil
                                    if isAnimated {
                                        selectionNode.animateOut(completion: { [weak selectionNode] in
                                            selectionNode?.removeFromSupernode()
                                        })
                                    } else {
                                        selectionNode.removeFromSupernode()
                                    }
                                }
                            }
                            
                            strongSelf.updateStatus(animated: isAnimated)
                            
                            if let forwardInfo = arguments.message.forwardInfo, forwardInfo.flags.contains(.isImported) {
                                strongSelf.dateAndStatusNode.pressed = {
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.displayImportedTooltip(strongSelf.dateAndStatusNode)
                                }
                            } else {
                                strongSelf.dateAndStatusNode.pressed = nil
                            }
                        }
                    })
                })
            })
        }
    }
    
    private func updateStatus(animated: Bool) {
        guard let resourceStatus = self.resourceStatus else {
            return
        }
        guard let message = self.message else {
            return
        }
        guard let context = self.context else {
            return
        }
        guard let presentationData = self.presentationData else {
            return
        }
        guard let progressFrame = self.progressFrame, let streamingCacheStatusFrame = self.streamingCacheStatusFrame else {
            return
        }
        guard let file = self.file else {
            return
        }
        guard let arguments = self.arguments else {
            return
        }
        
        var animated = animated
        if DeviceProximityManager.shared().currentValue() {
            animated = false
        }
        
        let incoming = message.effectivelyIncoming(context.account.peerId)
        let messageTheme = incoming ? presentationData.theme.theme.chat.message.incoming : presentationData.theme.theme.chat.message.outgoing
        
        var isAudio = false
        var isVoice = false
        var audioDuration: Int32?
        for attribute in file.attributes {
            if case let .Video(duration, _, flags, _, _, _) = attribute, flags.contains(.instantRoundVideo) {
                isAudio = true
                isVoice = true
                audioDuration = Int32(duration)
            } else if case let .Audio(voice, duration, _, _, _) = attribute {
                isAudio = true
                if voice {
                    isVoice = true
                    audioDuration = Int32(duration)
                }
            }
        }
        let isViewOnceMessage = isVoice && message.minAutoremoveOrClearTimeout == viewOnceTimeout
        
        var state: SemanticStatusNodeState
        var streamingState: SemanticStatusNodeState = .none
        
        let isSending = message.flags.isSending
        
        var downloadingStrings: (String, String, UIFont)?
        
        var playbackState: (position: Double, duration: Double, generationTimestamp: Double) = (0.0, 0.0, 0.0)
        if !isAudio {
            var fetchStatus: MediaResourceStatus?
            if let actualFetchStatus = self.actualFetchStatus, message.forwardInfo != nil {
                fetchStatus = actualFetchStatus
            } else if case let .fetchStatus(status) = resourceStatus.mediaStatus {
                fetchStatus = status._asStatus()
            }

            if let fetchStatus = fetchStatus {
                switch fetchStatus {
                    case let .Fetching(_, progress):
                        if let size = file.size, size > 0 && size != .max {
                            let progress = max(0.0, min(1.0, progress))
                            let compactString = dataSizeString(Int(Float(size) * progress), forceDecimal: true, formatting: DataSizeStringFormatting(chatPresentationData: presentationData))
                            let descriptionFont = Font.with(size: floor(presentationData.fontSize.baseDisplaySize * 13.0 / 17.0), design: .regular, weight: .regular, traits: [.monospacedNumbers])
                            downloadingStrings = ("\(compactString) / \(dataSizeString(size, forceDecimal: true, formatting: DataSizeStringFormatting(chatPresentationData: presentationData)))", compactString, descriptionFont)
                        }
                    default:
                        break
                }
            }
        } else if isVoice {
            if let playerStatus = self.playerStatus {
                var playerPosition: Double?
                var playerDuration: Double = 0.0
                if !playerStatus.generationTimestamp.isZero, case .playing = playerStatus.status {
                    playerPosition = playerStatus.timestamp + (CACurrentMediaTime() - playerStatus.generationTimestamp)
                } else {
                    playerPosition = playerStatus.timestamp
                }
                playerDuration = playerStatus.duration
                
                let effectiveDuration = playerDuration > 0 ? playerDuration : Double(audioDuration ?? 0)
                
                let durationString = stringForDuration(Int32(effectiveDuration), position: playerPosition.flatMap { Int32($0) })
                let durationFont = Font.regular(floor(presentationData.fontSize.baseDisplaySize * 11.0 / 17.0))
                downloadingStrings = (durationString, durationString, durationFont)
                
                playbackState = (playerStatus.timestamp, playerDuration, playerStatus.generationTimestamp)
            }
        }
        
        if let updatingMedia = arguments.attributes.updatingMedia, case .update = updatingMedia.media {
            let adjustedProgress = max(CGFloat(updatingMedia.progress), 0.027)
            state = .progress(value: CGFloat(adjustedProgress), cancelEnabled: true, appearance: nil)
        } else {
            switch resourceStatus.mediaStatus {
            case var .fetchStatus(fetchStatus):
                if self.message?.forwardInfo != nil {
                    fetchStatus = resourceStatus.fetchStatus
                }
                (self.waveformView?.componentView as? AudioWaveformComponent.View)?.enableScrubbing = false
                
                switch fetchStatus {
                case let .Fetching(_, progress):
                    let adjustedProgress = max(progress, 0.027)
                    var wasCheck = false
                    if let statusNode = self.statusNode, case .check = statusNode.state {
                        wasCheck = true
                    }
                    
                    if isAudio && !isVoice && !isSending {
                        state = .play
                    } else {
                        if message.groupingKey != nil, adjustedProgress.isEqual(to: 1.0), (message.flags.contains(.Unsent) || wasCheck) {
                            state = .check(appearance: nil)
                        } else {
                            state = .progress(value: CGFloat(adjustedProgress), cancelEnabled: true, appearance: nil)
                        }
                    }
                case .Local:
                    if isAudio  {
                        state = .play
                    } else if let fileIconImage = self.fileIconImage {
                        state = .customIcon(fileIconImage)
                    } else {
                        state = .none
                    }
                case .Remote, .Paused:
                    if isAudio && !isVoice {
                        state = .play
                    } else {
                        state = .download
                    }
                }
            case let .playbackStatus(playbackStatus):
                (self.waveformView?.componentView as? AudioWaveformComponent.View)?.enableScrubbing = !isViewOnceMessage
                
                if isViewOnceMessage && playbackStatus == .playing {
                    state = .secretTimeout(position: playbackState.position, duration: playbackState.duration, generationTimestamp: playbackState.generationTimestamp, appearance: .init(inset: 1.0 + UIScreenPixel, lineWidth: 2.0 - UIScreenPixel))
                    if incoming {
                        self.consumableContentNode.isHidden = true
                    }
                } else {
                    switch playbackStatus {
                    case .playing:
                        state = .pause
                    case .paused:
                        state = .play
                    }
                }
            }
        }
        
        if isViewOnceMessage, let viewOnceIconImage = self.viewOnceIconImage, state == .play {
            streamingState = .customIcon(viewOnceIconImage)
        } else {
            if isAudio && !isVoice && !isSending && state != .pause {
                switch resourceStatus.fetchStatus {
                case let .Fetching(_, progress):
                    let adjustedProgress = max(progress, 0.027)
                    streamingState = .progress(value: CGFloat(adjustedProgress), cancelEnabled: true, appearance: .init(inset: 1.0, lineWidth: 2.0))
                case .Local:
                    streamingState = .none
                case .Remote, .Paused:
                    streamingState = .download
                }
            } else {
                streamingState = .none
            }
        }
        
        if isSending {
            streamingState = .none
            
            if case .progress = state {
            } else if case .check = state {
            } else {
                let adjustedProgress: CGFloat = 0.027
                state = .progress(value: CGFloat(adjustedProgress), cancelEnabled: true, appearance: .init(inset: 1.0, lineWidth: 2.0))
            }
        }
        
        let backgroundNodeColor: UIColor
        let foregroundNodeColor: UIColor
        if self.iconNode != nil {
            backgroundNodeColor = presentationData.theme.theme.chat.message.mediaOverlayControlColors.fillColor
            foregroundNodeColor = .white
        } else {
            backgroundNodeColor = arguments.customTintColor ?? messageTheme.mediaActiveControlColor
            if incoming && messageTheme.mediaActiveControlColor.rgb != 0xffffff {
                foregroundNodeColor = .white
            } else {
                foregroundNodeColor = .clear
            }
        }

        if state != .none && self.statusNode == nil {
            var image: Signal<(TransformImageArguments) -> DrawingContext?, NoError>? = nil
                        
            if file.isMusic || file.isInstantVideo {
                if file.fileName?.lowercased().hasSuffix(".ogg") == true {
                } else {
                    var title: String?
                    var performer: String?
                    
                    for attribute in file.attributes {
                        if case let .Audio(_, _, titleValue, performerValue, _) = attribute {
                            title = titleValue
                            performer = performerValue
                            break
                        }
                    }
                    
                    image = playerAlbumArt(postbox: context.account.postbox, engine: context.engine, fileReference: .message(message: MessageReference(message), media: file), albumArt: .init(thumbnailResource: ExternalMusicAlbumArtResource(file: .message(message: MessageReference(message), media: file), title: title ?? "", performer: performer ?? "", isThumbnail: true), fullSizeResource: ExternalMusicAlbumArtResource(file: .message(message: MessageReference(message), media: file), title: title ?? "", performer: performer ?? "", isThumbnail: false)), thumbnail: true, overlayColor: UIColor(white: 0.0, alpha: 0.3), drawPlaceholderWhenEmpty: false, attemptSynchronously: !animated)
                }
            }
            let statusNode = SemanticStatusNode(backgroundNodeColor: backgroundNodeColor, foregroundNodeColor: foregroundNodeColor, image: image, overlayForegroundNodeColor: presentationData.theme.theme.chat.message.mediaOverlayControlColors.foregroundColor)
            if presentationData.isPreview {
                statusNode.displaysAsynchronously = false
            }
            self.statusNode = statusNode

            self.statusContainerNode.contentNode.insertSubnode(statusNode, at: 0)
            self.statusContainerNode.frame = progressFrame
            self.statusContainerNode.contentRect = CGRect(origin: CGPoint(), size: progressFrame.size)
            self.statusContainerNode.contentNode.frame = CGRect(origin: CGPoint(), size: progressFrame.size)
            statusNode.frame = CGRect(origin: CGPoint(), size: progressFrame.size)
        } else if let statusNode = self.statusNode {
            statusNode.backgroundNodeColor = backgroundNodeColor
        }
        
        let effectsEnabled = self.context?.sharedContext.energyUsageSettings.fullTranslucency ?? true
        var showBlobs = false
        if case .pause = state {
            showBlobs = true
        } else if case .secretTimeout = state {
            showBlobs = true
        }
        if showBlobs, isVoice, self.playbackAudioLevelNode == nil, effectsEnabled {
            let blobFrame = progressFrame.insetBy(dx: -12.0, dy: -12.0)
            let playbackAudioLevelNode = VoiceBlobNode(
                maxLevel: 0.3,
                smallBlobRange: (0, 0),
                mediumBlobRange: (0.7, 0.8),
                bigBlobRange: (0.8, 0.9)
            )
            playbackAudioLevelNode.isUserInteractionEnabled = false
            playbackAudioLevelNode.frame = blobFrame
            self.playbackAudioLevelNode = playbackAudioLevelNode
            self.insertSubnode(playbackAudioLevelNode, belowSubnode: self.statusContainerNode)
            
            let maskRect = CGRect(origin: .zero, size: blobFrame.size)
            let playbackMaskLayer = CAShapeLayer()
            playbackMaskLayer.frame = maskRect
            playbackMaskLayer.fillRule = .evenOdd
            let maskPath = UIBezierPath()
            maskPath.append(UIBezierPath(roundedRect: maskRect.insetBy(dx: 12, dy: 12), cornerRadius: 22))
            maskPath.append(UIBezierPath(rect: maskRect))
            playbackMaskLayer.path = maskPath.cgPath
            playbackAudioLevelNode.layer.mask = playbackMaskLayer
        }
        self.playbackAudioLevelNode?.setColor(arguments.customTintColor ?? messageTheme.mediaActiveControlColor)
        
        if streamingState != .none && self.streamingStatusNode == nil {
            let streamingStatusNode = SemanticStatusNode(backgroundNodeColor: backgroundNodeColor, foregroundNodeColor: foregroundNodeColor)
            self.streamingStatusNode = streamingStatusNode
            streamingStatusNode.frame = streamingCacheStatusFrame
            self.addSubnode(streamingStatusNode)
            
            if isViewOnceMessage {
                streamingStatusNode.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2, timingFunction: CAMediaTimingFunctionName.linear.rawValue)
                streamingStatusNode.layer.animateAlpha(from: 0.1, to: 1.0, duration: 0.2, timingFunction: CAMediaTimingFunctionName.linear.rawValue)
            }
        } else if let streamingStatusNode = self.streamingStatusNode {
            streamingStatusNode.backgroundNodeColor = backgroundNodeColor
        }
        
        if let statusNode = self.statusNode {
            if state == .none {
                self.statusNode = nil
                if animated {
                    statusNode.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2, removeOnCompletion: false)
                    statusNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                }
            }
            statusNode.transitionToState(state, animated: animated, synchronous: presentationData.theme.theme.preview, completion: { [weak statusNode] in
                if state == .none {
                    statusNode?.removeFromSupernode()
                }
            })
            
            if showBlobs {
                self.playbackAudioLevelNode?.startAnimating()
            } else {
                self.playbackAudioLevelNode?.stopAnimating()
            }
        }
        
        if let streamingStatusNode = self.streamingStatusNode {
            if streamingState == .none {
                self.streamingStatusNode = nil
                if isViewOnceMessage {
                    streamingStatusNode.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2, timingFunction: CAMediaTimingFunctionName.linear.rawValue, removeOnCompletion: false)
                }
                streamingStatusNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, timingFunction: CAMediaTimingFunctionName.linear.rawValue, removeOnCompletion: false, completion: { [weak streamingStatusNode] _ in
                    if streamingState == .none {
                        streamingStatusNode?.removeFromSupernode()
                    }
                })
            } else {
                streamingStatusNode.transitionToState(streamingState)
            }
        }
        
        var cutoutFrame = streamingCacheStatusFrame.insetBy(dx: -(1.0 + UIScreenPixel), dy: -(1.0 + UIScreenPixel)).offsetBy(dx: progressFrame.minX - 6.0, dy: progressFrame.minY)
        if file.isVoice {
            cutoutFrame.origin.y += 6.0
        }
        
        if (streamingState == .none && self.selectionNode == nil) || presentationData.isPreview {
            self.statusNode?.setCutout(nil, animated: animated)
        } else if let statusNode = self.statusNode, (self.iconNode?.isHidden ?? true) {
            statusNode.setCutout(cutoutFrame, animated: true)
        }
        
        var displayingCountdown = false
        if let (expandedString, compactString, font) = downloadingStrings {
            self.fetchingTextNode.attributedText = NSAttributedString(string: expandedString, font: font, textColor: messageTheme.fileDurationColor)
            self.fetchingCompactTextNode.attributedText = NSAttributedString(string: compactString, font: font, textColor: messageTheme.fileDurationColor)
            
            if isViewOnceMessage {
                var segments: [AnimatedCountLabelNode.Segment] = []
                var textCount = 0
                for char in expandedString {
                    if let intValue = Int(String(char)) {
                        segments.append(.number(intValue, NSAttributedString(string: String(char), font: font, textColor: messageTheme.fileDurationColor)))
                    } else {
                        segments.append(.text(textCount, NSAttributedString(string: String(char), font: font, textColor: messageTheme.fileDurationColor)))
                        textCount += 1
                    }
                }
                if self.countNode.supernode == nil {
                    self.addSubnode(self.countNode)
                }
                self.countNode.segments = segments
                displayingCountdown = true
            } else if self.countNode.supernode != nil {
                self.countNode.removeFromSupernode()
            }
        } else {
            self.fetchingTextNode.attributedText = nil
            self.fetchingCompactTextNode.attributedText = nil
        }
        
        let maxFetchingStatusWidth = max(self.titleNode.frame.width, self.descriptionMeasuringNode.frame.width) + 2.0
        let fetchingInfo = self.fetchingTextNode.updateLayoutInfo(CGSize(width: maxFetchingStatusWidth, height: CGFloat.greatestFiniteMagnitude))
        let fetchingCompactSize = self.fetchingCompactTextNode.updateLayout(CGSize(width: maxFetchingStatusWidth, height: CGFloat.greatestFiniteMagnitude))
        let countSize = self.countNode.updateLayout(size: CGSize(width: maxFetchingStatusWidth, height: CGFloat.greatestFiniteMagnitude), animated: true)
        
        if displayingCountdown {
            self.fetchingTextNode.isHidden = true
            self.fetchingCompactTextNode.isHidden = true
            self.descriptionNode.isHidden = true
        } else {
            if downloadingStrings != nil {
                self.descriptionNode.isHidden = true
                if fetchingInfo.truncated {
                    self.fetchingTextNode.isHidden = true
                    self.fetchingCompactTextNode.isHidden = false
                } else {
                    self.fetchingTextNode.isHidden = false
                    self.fetchingCompactTextNode.isHidden = true
                }
            } else {
                self.descriptionNode.isHidden = false
                self.fetchingTextNode.isHidden = true
                self.fetchingCompactTextNode.isHidden = true
            }
        }
        
        self.fetchingTextNode.frame = CGRect(origin: self.descriptionNode.frame.origin, size: fetchingInfo.size)
        self.fetchingCompactTextNode.frame = CGRect(origin: self.descriptionNode.frame.origin, size: fetchingCompactSize)
        self.countNode.frame = CGRect(origin: self.descriptionNode.frame.origin, size: countSize)
    }
    
    public typealias Apply = (Bool, ListViewItemUpdateAnimation, ListViewItemApply?) -> ChatMessageInteractiveFileNode
    public typealias FinalizeLayout = (CGFloat) -> (CGSize, Apply)
    public typealias ContinueLayout = (CGSize) -> (CGFloat, FinalizeLayout)
    public typealias AsyncLayout = (Arguments) -> (CGFloat, ContinueLayout)
    public static func asyncLayout(_ node: ChatMessageInteractiveFileNode?) -> AsyncLayout {
        let currentAsyncLayout = node?.asyncLayout()
        
        return { arguments in
            var fileNode: ChatMessageInteractiveFileNode
            var fileLayout: (Arguments) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, (Bool, ListViewItemUpdateAnimation, ListViewItemApply?) -> Void)))
            
            if let node = node, let currentAsyncLayout = currentAsyncLayout {
                fileNode = node
                fileLayout = currentAsyncLayout
            } else {
                fileNode = ChatMessageInteractiveFileNode()
                fileLayout = fileNode.asyncLayout()
            }
            
            let (initialWidth, continueLayout) = fileLayout(arguments)
            
            return (initialWidth, { constrainedSize in
                let (finalWidth, finalLayout) = continueLayout(constrainedSize)
                
                return (finalWidth, { boundingWidth in
                    let (finalSize, apply) = finalLayout(boundingWidth)
                    
                    return (finalSize, { synchronousLoads, animation, applyInfo in
                        apply(synchronousLoads, animation, applyInfo)
                        return fileNode
                    })
                })
            })
        }
    }
    
    public func willUpdateIsExtractedToContextPreview(_ value: Bool) {
        if !value {
            if let textSelectionNode = self.textSelectionNode {
                self.textSelectionNode = nil
                textSelectionNode.highlightAreaNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                textSelectionNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak textSelectionNode] _ in
                    textSelectionNode?.highlightAreaNode.removeFromSupernode()
                    textSelectionNode?.removeFromSupernode()
                })
            }
        }
    }
    
    public func updateIsExtractedToContextPreview(_ value: Bool) {
        if value {
            if self.textSelectionNode == nil, self.textClippingNode.supernode != nil, let item = self.arguments, !item.associatedData.isCopyProtectionEnabled && !item.message.isCopyProtected(), let rootNode = item.controllerInteraction.chatControllerNode() {
                let selectionColor: UIColor
                let knobColor: UIColor
                if item.message.effectivelyIncoming(item.context.account.peerId) {
                    selectionColor = item.presentationData.theme.theme.chat.message.incoming.textSelectionColor
                    knobColor = item.presentationData.theme.theme.chat.message.incoming.textSelectionKnobColor
                } else {
                    selectionColor = item.presentationData.theme.theme.chat.message.outgoing.textSelectionColor
                    knobColor = item.presentationData.theme.theme.chat.message.outgoing.textSelectionKnobColor
                }
                
                let textSelectionNode = TextSelectionNode(theme: TextSelectionTheme(selection: selectionColor, knob: knobColor, isDark: item.presentationData.theme.theme.overallDarkAppearance), strings: item.presentationData.strings, textNode: self.textNode, updateIsActive: { [weak self] value in
                    self?.updateIsTextSelectionActive?(value)
                }, present: { [weak self] c, a in
                    self?.arguments?.controllerInteraction.presentGlobalOverlayController(c, a)
                }, rootNode: { [weak rootNode] in
                    return rootNode
                }, performAction: { [weak self] text, action in
                    guard let strongSelf = self, let item = strongSelf.arguments else {
                        return
                    }
                    item.controllerInteraction.performTextSelectionAction(item.message, true, text, action)
                })
                textSelectionNode.enableQuote = false
                self.textSelectionNode = textSelectionNode
                self.textClippingNode.addSubnode(textSelectionNode)
                self.textClippingNode.insertSubnode(textSelectionNode.highlightAreaNode, belowSubnode: self.textNode)
                textSelectionNode.frame = self.textNode.frame
                textSelectionNode.highlightAreaNode.frame = self.textNode.frame
            }
        } else {
            if let textSelectionNode = self.textSelectionNode {
                self.textSelectionNode = nil
                self.updateIsTextSelectionActive?(false)
                textSelectionNode.highlightAreaNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                textSelectionNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak textSelectionNode] _ in
                    textSelectionNode?.highlightAreaNode.removeFromSupernode()
                    textSelectionNode?.removeFromSupernode()
                })
            }
        }
    }
    
    public func transitionNode(media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        if let iconNode = self.iconNode, let file = self.file, file.isEqual(to: media) {
            return (iconNode, iconNode.bounds, { [weak iconNode] in
                return (iconNode?.view.snapshotContentTree(unhide: true), nil)
            })
        } else {
            return nil
        }
    }
    
    public func updateHiddenMedia(_ media: [Media]?) -> Bool {
        var isHidden = false
        if let file = self.file, let media = media {
            for m in media {
                if file.isEqual(to: m) {
                    isHidden = true
                    break
                }
            }
        }
        self.iconNode?.isHidden = isHidden
        return isHidden
    }
    
    private func ensureHasTimer() {
        if self.playerUpdateTimer == nil {
            let timer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
                self?.updateStatus(animated: true)
            }, queue: Queue.mainQueue())
            self.playerUpdateTimer = timer
            timer.start()
        }
    }
    
    private func stopTimer() {
        self.playerUpdateTimer?.invalidate()
        self.playerUpdateTimer = nil
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.dateAndStatusNode.supernode != nil {
            if let result = self.dateAndStatusNode.hitTest(self.view.convert(point, to: self.dateAndStatusNode.view), with: event) {
                return result
            }
            if !self.dateAndStatusNode.frame.height.isZero {
                if self.dateAndStatusNode.frame.contains(point) {
                    return nil
                }
            }
        }
        if let audioTranscriptionButton = self.audioTranscriptionButton {
            if let result = audioTranscriptionButton.hitTest(self.view.convert(point, to: self.audioTranscriptionButton), with: event) {
                return result
            }
        }
        return super.hitTest(point, with: event)
    }
    
    public func hasTapAction(at point: CGPoint) -> Bool {
        if let _ = self.dateAndStatusNode.hitTest(self.view.convert(point, to: self.dateAndStatusNode.view), with: nil) {
            return true
        }
        return false
    }
    
    public func animateSent() {
        if let view = self.waveformView?.componentView as? AudioWaveformComponent.View {
            view.animateIn()
        }
    }
}


public final class FileMessageSelectionNode: ASDisplayNode {
    public enum NodeType {
        case media
        case file
        case voice
    }
    private let toggle: (Bool) -> Void
    
    private var selected = false
    private let checkNode: CheckNode
    private let type: NodeType
    
    public init(theme: PresentationTheme, incoming: Bool, type: NodeType, toggle: @escaping (Bool) -> Void) {
        self.type = type
        self.toggle = toggle
        self.checkNode = CheckNode(theme: type != .media ? CheckNodeTheme(backgroundColor: theme.list.itemCheckColors.fillColor, strokeColor: theme.list.itemCheckColors.foregroundColor, borderColor: incoming ? theme.chat.message.incoming.mediaPlaceholderColor : theme.chat.message.outgoing.mediaPlaceholderColor, overlayBorder: false, hasInset: false, hasShadow: false) : CheckNodeTheme(theme: theme, style: .overlay))
        self.checkNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.checkNode)
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    public func animateIn() {
        self.checkNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
        self.checkNode.layer.animateScale(from: 0.2, to: 1.0, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    public func animateOut(completion: @escaping () -> Void) {
        self.checkNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        self.checkNode.layer.animateScale(from: 1.0, to: 0.2, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            completion()
        })
    }
    
    public func updateSelected(_ selected: Bool, animated: Bool) {
        if self.selected != selected {
            self.selected = selected
            self.checkNode.setSelected(selected, animated: animated)
        }
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.toggle(!self.selected)
        }
    }
    
    override public func layout() {
        super.layout()
        
        let checkSize: CGSize
        let checkOrigin: CGPoint
        switch self.type {
            case .media:
                checkSize = CGSize(width: 28.0, height: 28.0)
                checkOrigin = CGPoint(x: 41.0, y: -3.0)
            case .file:
                checkSize = CGSize(width: 20.0, height: 20.0)
                checkOrigin = CGPoint(x: 29.0, y: 26.0)
            case .voice:
                checkSize = CGSize(width: 20.0, height: 20.0)
                checkOrigin = CGPoint(x: 29.0, y: 23.0)
        }
        self.checkNode.frame = CGRect(origin: checkOrigin, size: checkSize)
    }
}

