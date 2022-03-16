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
import RadialStatusNode
import SemanticStatusNode
import FileMediaResourceStatus
import CheckNode
import MusicAlbumArtResources
import AudioBlob
import ContextUI
import ChatPresentationInterfaceState

private struct FetchControls {
    let fetch: (Bool) -> Void
    let cancel: () -> Void
}

final class ChatMessageInteractiveFileNode: ASDisplayNode {
    final class Arguments {
        let context: AccountContext
        let presentationData: ChatPresentationData
        let message: Message
        let topMessage: Message
        let associatedData: ChatMessageItemAssociatedData
        let chatLocation: ChatLocation
        let attributes: ChatMessageEntryAttributes
        let isPinned: Bool
        let forcedIsEdited: Bool
        let file: TelegramMediaFile
        let automaticDownload: Bool
        let incoming: Bool
        let isRecentActions: Bool
        let forcedResourceStatus: FileMediaResourceStatus?
        let dateAndStatusType: ChatMessageDateAndStatusType?
        let displayReactions: Bool
        let messageSelection: Bool?
        let constrainedSize: CGSize
        
        init(
            context: AccountContext,
            presentationData: ChatPresentationData,
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
            constrainedSize: CGSize
        ) {
            self.context = context
            self.presentationData = presentationData
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
            self.constrainedSize = constrainedSize
        }
    }
    
    private var selectionNode: FileMessageSelectionNode?
    
    private let titleNode: TextNode
    private let descriptionNode: TextNode
    private let descriptionMeasuringNode: TextNode
    private let fetchingTextNode: ImmediateTextNode
    private let fetchingCompactTextNode: ImmediateTextNode
    private let waveformNode: AudioWaveformNode
    private let waveformForegroundNode: AudioWaveformNode
    private var waveformScrubbingNode: MediaPlayerScrubbingNode?
    let dateAndStatusNode: ChatMessageDateAndStatusNode
    private let consumableContentNode: ASImageNode
    
    private var iconNode: TransformImageNode?
    let statusContainerNode: ContextExtractedContentContainingNode
    private var statusNode: SemanticStatusNode?
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
    
    var visibility: Bool = false {
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
    
    var toggleSelection: (Bool) -> Void = { _ in }
    var activateLocalContent: () -> Void = { }
    var requestUpdateLayout: (Bool) -> Void = { _ in }
    var displayImportedTooltip: (ASDisplayNode) -> Void = { _ in }
    
    private var context: AccountContext?
    private var message: Message?
    private var presentationData: ChatPresentationData?
    private var file: TelegramMediaFile?
    private var progressFrame: CGRect?
    private var streamingCacheStatusFrame: CGRect?
    private var fileIconImage: UIImage?
    
    override init() {
        self.titleNode = TextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.isUserInteractionEnabled = false
        
        self.descriptionNode = TextNode()
        self.descriptionNode.displaysAsynchronously = false
        self.descriptionNode.isUserInteractionEnabled = false
        
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
        
        self.waveformNode = AudioWaveformNode()
        self.waveformNode.isLayerBacked = true
        self.waveformForegroundNode = AudioWaveformNode()
        self.waveformForegroundNode.isLayerBacked = true
        
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
    }
    
    override func didLoad() {
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.fileTap(_:)))
        self.view.addGestureRecognizer(tapRecognizer)
        self.tapRecognizer = tapRecognizer
    }
    
    @objc func cacheProgressPressed() {
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
    
    @objc func progressPressed() {
        if let resourceStatus = self.resourceStatus {
            switch resourceStatus.mediaStatus {
                case let .fetchStatus(fetchStatus):
                    if let context = self.context, let message = self.message, message.flags.isSending {
                        let _ = context.account.postbox.transaction({ transaction -> Void in
                            context.engine.messages.deleteMessages(transaction: transaction, ids: [message.id])
                        }).start()
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
                    if let context = self.context, let message = self.message, let type = peerMessageMediaPlayerType(message) {
                        context.sharedContext.mediaManager.playlistControl(.playback(.togglePlayPause), type: type)
                    }
            }
        }
    }
    
    @objc func fileTap(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let streamingCacheStatusFrame = self.streamingCacheStatusFrame, streamingCacheStatusFrame.contains(recognizer.location(in: self.view)) {
                self.cacheProgressPressed()
            } else {
                self.progressPressed()
            }
        }
    }
    
    func asyncLayout() -> (Arguments) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, (Bool, ListViewItemUpdateAnimation) -> Void))) {
        let currentFile = self.file
        
        let titleAsyncLayout = TextNode.asyncLayout(self.titleNode)
        let descriptionAsyncLayout = TextNode.asyncLayout(self.descriptionNode)
        let descriptionMeasuringAsyncLayout = TextNode.asyncLayout(self.descriptionMeasuringNode)
        let statusLayout = self.dateAndStatusNode.asyncLayout()
        
        let currentMessage = self.message
        
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
                
                let hasThumbnail = (!arguments.file.previewRepresentations.isEmpty || arguments.file.immediateThumbnailData != nil) && !arguments.file.isMusic && !arguments.file.isVoice
                
                if mediaUpdated {
                    if largestImageRepresentation(arguments.file.previewRepresentations) != nil || arguments.file.immediateThumbnailData != nil {
                        updateImageSignal = chatMessageImageFile(account: arguments.context.account, fileReference: .message(message: MessageReference(arguments.message), media: arguments.file), thumbnail: true)
                    }
                    
                    updatedFetchControls = FetchControls(fetch: { [weak self] userInitiated in
                        if let strongSelf = self {
                            strongSelf.fetchDisposable.set(messageMediaFileInteractiveFetched(context: arguments.context, message: arguments.message, file: arguments.file, userInitiated: userInitiated).start())
                        }
                    }, cancel: {
                        messageMediaFileCancelInteractiveFetch(context: arguments.context, messageId: arguments.message.id, file: arguments.file)
                    })
                }
                
                if statusUpdated {
                    if arguments.message.flags.isSending {
                        updatedStatusSignal = combineLatest(messageFileMediaResourceStatus(context: arguments.context, file: arguments.file, message: arguments.message, isRecentActions: arguments.isRecentActions), messageMediaFileStatus(context: arguments.context, messageId: arguments.message.id, file: arguments.file))
                        |> map { resourceStatus, actualFetchStatus -> (FileMediaResourceStatus, MediaResourceStatus?) in
                            return (resourceStatus, actualFetchStatus)
                        }
                        updatedAudioLevelEventsSignal = messageFileMediaPlaybackAudioLevelEvents(context: arguments.context, file: arguments.file, message: arguments.message, isRecentActions: arguments.isRecentActions, isGlobalSearch: false, isDownloadList: false)
                    } else {
                        updatedStatusSignal = messageFileMediaResourceStatus(context: arguments.context, file: arguments.file, message: arguments.message, isRecentActions: arguments.isRecentActions)
                        |> map { resourceStatus -> (FileMediaResourceStatus, MediaResourceStatus?) in
                            return (resourceStatus, nil)
                        }
                        updatedAudioLevelEventsSignal = messageFileMediaPlaybackAudioLevelEvents(context: arguments.context, file: arguments.file, message: arguments.message, isRecentActions: arguments.isRecentActions, isGlobalSearch: false, isDownloadList: false)
                    }
                    updatedPlaybackStatusSignal = messageFileMediaPlaybackStatus(context: arguments.context, file: arguments.file, message: arguments.message, isRecentActions: arguments.isRecentActions, isGlobalSearch: false, isDownloadList: false)
                }
                
                var consumableContentIcon: UIImage?
                for attribute in arguments.message.attributes {
                    if let attribute = attribute as? ConsumableContentMessageAttribute {
                        let isConsumed = attribute.consumed
                        if !isConsumed {
                            if arguments.incoming {
                                consumableContentIcon = PresentationResourcesChat.chatBubbleConsumableContentIncomingIcon(arguments.presentationData.theme.theme)
                            } else {
                                consumableContentIcon = PresentationResourcesChat.chatBubbleConsumableContentOutgoingIcon(arguments.presentationData.theme.theme)
                            }
                        }
                        break
                    }
                }
                
                var candidateTitleString: NSAttributedString?
                var candidateDescriptionString: NSAttributedString?
                
                var isAudio = false
                var audioWaveform: AudioWaveform?
                var isVoice = false
                var audioDuration: Int32 = 0
                
                let messageTheme = arguments.incoming ? arguments.presentationData.theme.theme.chat.message.incoming : arguments.presentationData.theme.theme.chat.message.outgoing
                
                for attribute in arguments.file.attributes {
                    if case let .Audio(voice, duration, title, performer, waveform) = attribute {
                        isAudio = true
                        
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
                            candidateTitleString = NSAttributedString(string: title ?? (arguments.file.fileName ?? "Unknown Track"), font: titleFont, textColor: messageTheme.fileTitleColor)
                            let descriptionText: String
                            if let performer = performer {
                                descriptionText = performer
                            } else if let size = arguments.file.size {
                                descriptionText = dataSizeString(size, formatting: DataSizeStringFormatting(chatPresentationData: arguments.presentationData))
                            } else {
                                descriptionText = ""
                            }
                            candidateDescriptionString = NSAttributedString(string: descriptionText, font: descriptionFont, textColor: messageTheme.fileDescriptionColor)
                        }
                        break
                    }
                }
                
                var titleString: NSAttributedString?
                var descriptionString: NSAttributedString?
                
                if let candidateTitleString = candidateTitleString {
                    titleString = candidateTitleString
                } else if !isVoice {
                    titleString = NSAttributedString(string: arguments.file.fileName ?? "File", font: titleFont, textColor: messageTheme.fileTitleColor)
                }
                
                if let candidateDescriptionString = candidateDescriptionString {
                    descriptionString = candidateDescriptionString
                } else if !isVoice {
                    let descriptionText: String
                    if let size = arguments.file.size {
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
                
                let fileSizeString: String
                if let _ = arguments.file.size {
                    fileSizeString = "000.0 MB"
                } else {
                    fileSizeString = ""
                }
                let (descriptionMeasuringLayout, descriptionMeasuringApply) = descriptionMeasuringAsyncLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "\(fileSizeString) / \(fileSizeString)", font: descriptionFont, textColor: .black), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .middle, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                let descriptionMaxWidth = max(descriptionLayout.size.width, descriptionMeasuringLayout.size.width)
                
                let minVoiceWidth: CGFloat = 120.0
                let maxVoiceWidth = constrainedSize.width
                let maxVoiceLength: CGFloat = 30.0
                let minVoiceLength: CGFloat = 2.0
                
                let progressDiameter: CGFloat = 44.0
                
                var iconFrame: CGRect?
                let progressFrame: CGRect
                let controlAreaWidth: CGFloat
                
                if hasThumbnail {
                    let currentIconFrame = CGRect(origin: CGPoint(x: -1.0, y: -7.0), size: CGSize(width: 74.0, height: 74.0))
                    iconFrame = currentIconFrame
                    progressFrame = CGRect(
                        origin: CGPoint(
                            x: currentIconFrame.minX + floor((currentIconFrame.size.width - progressDiameter) / 2.0),
                            y: currentIconFrame.minY + floor((currentIconFrame.size.height - progressDiameter) / 2.0)
                        ),
                        size: CGSize(width: progressDiameter, height: progressDiameter)
                    )
                    controlAreaWidth = 86.0
                } else {
                    progressFrame = CGRect(
                        origin: CGPoint(x: 3.0, y: isVoice ? -3.0 : 0.0),
                        size: CGSize(width: progressDiameter, height: progressDiameter)
                    )
                    controlAreaWidth = progressFrame.maxX + 8.0
                }
                
                var statusSuggestedWidthAndContinue: (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))?
                if let statusType = arguments.dateAndStatusType {
                    var edited = false
                    if arguments.attributes.updatingMedia != nil {
                        edited = true
                    }
                    var viewCount: Int?
                    var dateReplies = 0
                    let dateReactionsAndPeers = mergedMessageReactionsAndPeers(message: arguments.topMessage)
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
                    
                    let dateText = stringForMessageTimestampStatus(accountPeerId: arguments.context.account.peerId, message: arguments.message, dateTimeFormat: arguments.presentationData.dateTimeFormat, nameDisplayOrder: arguments.presentationData.nameDisplayOrder, strings: arguments.presentationData.strings)
                    
                    let displayReactionsInline = shouldDisplayInlineDateReactions(message: arguments.message)
                    var reactionSettings: ChatMessageDateAndStatusNode.TrailingReactionSettings?
                    
                    if displayReactionsInline || arguments.displayReactions {
                        reactionSettings = ChatMessageDateAndStatusNode.TrailingReactionSettings(displayInline: displayReactionsInline, preferAdditionalInset: !displayReactionsInline)
                    }
                    
                    statusSuggestedWidthAndContinue = statusLayout(ChatMessageDateAndStatusNode.Arguments(
                        context: arguments.context,
                        presentationData: arguments.presentationData,
                        edited: edited,
                        impressionCount: viewCount,
                        dateText: dateText,
                        type: statusType,
                        layoutInput: .trailingContent(contentWidth: iconFrame == nil ? 1000.0 : controlAreaWidth, reactionSettings: reactionSettings),
                        constrainedSize: constrainedSize,
                        availableReactions: arguments.associatedData.availableReactions,
                        reactions: dateReactionsAndPeers.reactions,
                        reactionPeers: dateReactionsAndPeers.peers,
                        replyCount: dateReplies,
                        isPinned: arguments.isPinned && !arguments.associatedData.isInPinnedListMode,
                        hasAutoremove: arguments.message.isSelfExpiring,
                        canViewReactionList: canViewMessageReactionList(message: arguments.message)
                    ))
                }
                
                var minLayoutWidth: CGFloat
                if hasThumbnail {
                    minLayoutWidth = max(titleLayout.size.width, descriptionMaxWidth) + 86.0
                } else if isVoice {
                    let descriptionAndStatusWidth = descriptionLayout.size.width
                    
                    let calcDuration = max(minVoiceLength, min(maxVoiceLength, CGFloat(audioDuration)))
                    minLayoutWidth = minVoiceWidth + (maxVoiceWidth - minVoiceWidth) * (calcDuration - minVoiceLength) / (maxVoiceLength - minVoiceLength)
                    minLayoutWidth = max(descriptionAndStatusWidth + 56, minLayoutWidth)
                } else {
                    minLayoutWidth = max(titleLayout.size.width, descriptionMaxWidth) + 44.0 + 8.0
                }
                
                if let statusSuggestedWidthAndContinue = statusSuggestedWidthAndContinue {
                    minLayoutWidth = max(minLayoutWidth, statusSuggestedWidthAndContinue.0)
                }
                                
                let fileIconImage: UIImage?
                if hasThumbnail {
                    fileIconImage = nil
                } else {
                    let principalGraphics = PresentationResourcesChat.principalGraphics(theme: arguments.presentationData.theme.theme, wallpaper: arguments.presentationData.theme.wallpaper, bubbleCorners: arguments.presentationData.chatBubbleCorners)
                    
                    fileIconImage = arguments.incoming ? principalGraphics.radialIndicatorFileIconIncoming : principalGraphics.radialIndicatorFileIconOutgoing
                }
                
                return (minLayoutWidth, { boundingWidth in
                    let titleAndDescriptionHeight = titleLayout.size.height - 1.0 + descriptionLayout.size.height
                    
                    let normHeight: CGFloat
                    if hasThumbnail {
                        normHeight = 64.0
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
                    
                    var statusSizeAndApply: (CGSize, (ListViewItemUpdateAnimation) -> Void)?
                    if let statusSuggestedWidthAndContinue = statusSuggestedWidthAndContinue {
                        statusSizeAndApply = statusSuggestedWidthAndContinue.1(boundingWidth)
                    }
                    var statusOffset: CGFloat = 0.0
                    if let statusSizeAndApply = statusSizeAndApply {
                        fittedLayoutSize.width = max(fittedLayoutSize.width, statusSizeAndApply.0.width)
                        fittedLayoutSize.height += statusSizeAndApply.0.height
                        if !statusSizeAndApply.0.height.isZero && iconFrame == nil {
                            statusOffset = -10.0
                            fittedLayoutSize.height += statusOffset
                        }
                    }
                    
                    let streamingCacheStatusFrame: CGRect
                    if (isAudio && !isVoice) || arguments.file.previewRepresentations.isEmpty {
                        streamingCacheStatusFrame = CGRect(origin: CGPoint(x: progressFrame.maxX - streamingProgressDiameter + 2.0, y: progressFrame.maxY - streamingProgressDiameter + 2.0), size: CGSize(width: streamingProgressDiameter, height: streamingProgressDiameter))
                    } else {
                        streamingCacheStatusFrame = CGRect()
                    }
                    
                    return (fittedLayoutSize, { [weak self] synchronousLoads, animation in
                        if let strongSelf = self {
                            strongSelf.context = arguments.context
                            strongSelf.presentationData = arguments.presentationData
                            strongSelf.message = arguments.message
                            strongSelf.file = arguments.file
                            
                            let _ = titleApply()
                            let _ = descriptionApply()
                            let _ = descriptionMeasuringApply()
                            
                            strongSelf.titleNode.frame = titleFrame
                            strongSelf.descriptionNode.frame = descriptionFrame
                            strongSelf.descriptionMeasuringNode.frame = CGRect(origin: CGPoint(), size: descriptionMeasuringLayout.size)
                            
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
                            if let statusSizeAndApply = statusSizeAndApply {
                                let statusFrame = CGRect(origin: CGPoint(x: statusReferenceFrame.minX, y: statusReferenceFrame.maxY + statusOffset), size: statusSizeAndApply.0)
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
                                if strongSelf.waveformScrubbingNode == nil {
                                    let waveformScrubbingNode = MediaPlayerScrubbingNode(content: .custom(backgroundNode: strongSelf.waveformNode, foregroundContentNode: strongSelf.waveformForegroundNode))
                                    waveformScrubbingNode.hitTestSlop = UIEdgeInsets(top: -10.0, left: 0.0, bottom: -10.0, right: 0.0)
                                    waveformScrubbingNode.seek = { timestamp in
                                        if let strongSelf = self, let context = strongSelf.context, let message = strongSelf.message, let type = peerMessageMediaPlayerType(message) {
                                            context.sharedContext.mediaManager.playlistControl(.seek(timestamp), type: type)
                                        }
                                    }
                                    waveformScrubbingNode.status = strongSelf.playbackStatus.get()
                                    strongSelf.waveformScrubbingNode = waveformScrubbingNode
                                    strongSelf.addSubnode(waveformScrubbingNode)
                                }
                                strongSelf.waveformScrubbingNode?.frame = CGRect(origin: CGPoint(x: 57.0, y: 1.0), size: CGSize(width: boundingWidth - 60.0, height: 15.0))
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
                                strongSelf.waveformNode.setup(color: waveformColor, gravity: .bottom, waveform: audioWaveform)
                                strongSelf.waveformForegroundNode.setup(color: messageTheme.mediaActiveControlColor, gravity: .bottom, waveform: audioWaveform)
                            } else if let waveformScrubbingNode = strongSelf.waveformScrubbingNode {
                                strongSelf.waveformScrubbingNode = nil
                                waveformScrubbingNode.removeFromSupernode()
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
                            
                            if let updatedStatusSignal = updatedStatusSignal {
                                strongSelf.statusDisposable.set((updatedStatusSignal |> deliverOnMainQueue).start(next: { [weak strongSelf] status, actualFetchStatus in
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
                                |> deliverOnMainQueue).start(next: { value in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.inputAudioLevel = CGFloat(value)
                                    strongSelf.playbackAudioLevelNode?.updateLevel(CGFloat(value))
                                }))
                            }
                            
                            if let updatedPlaybackStatusSignal = updatedPlaybackStatusSignal {
                                strongSelf.playbackStatus.set(updatedPlaybackStatusSignal)
                                strongSelf.playbackStatusDisposable.set((updatedPlaybackStatusSignal |> deliverOnMainQueue).start(next: { [weak strongSelf] status in
                                    displayLinkDispatcher.dispatch {
                                        if let strongSelf = strongSelf {
                                            strongSelf.playerStatus = status
                                        }
                                    }
                                }))
                            }
                                                        
                            strongSelf.waveformNode.displaysAsynchronously = !arguments.presentationData.isPreview
                            strongSelf.statusNode?.displaysAsynchronously = !arguments.presentationData.isPreview
                            strongSelf.statusNode?.frame = CGRect(origin: CGPoint(), size: progressFrame.size)

                            strongSelf.statusContainerNode.frame = progressFrame
                            strongSelf.statusContainerNode.contentRect = CGRect(origin: CGPoint(), size: progressFrame.size)
                            strongSelf.statusContainerNode.contentNode.frame = CGRect(origin: CGPoint(), size: progressFrame.size)

                            strongSelf.playbackAudioLevelNode?.frame = progressFrame.insetBy(dx: -12.0, dy: -12.0)
                            strongSelf.progressFrame = progressFrame
                            strongSelf.streamingCacheStatusFrame = streamingCacheStatusFrame
                            strongSelf.fileIconImage = fileIconImage

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
        let incoming = message.effectivelyIncoming(context.account.peerId)
        let messageTheme = incoming ? presentationData.theme.theme.chat.message.incoming : presentationData.theme.theme.chat.message.outgoing
        
        var isAudio = false
        var isVoice = false
        var audioDuration: Int32?
        for attribute in file.attributes {
            if case let .Audio(voice, duration, _, _, _) = attribute {
                isAudio = true
                if voice {
                    isVoice = true
                    audioDuration = Int32(duration)
                }
                break
            }
        }
        
        let state: SemanticStatusNodeState
        var streamingState: SemanticStatusNodeState = .none
        
        let isSending = message.flags.isSending
        
        var downloadingStrings: (String, String, UIFont)?
        
        if !isAudio {
            var fetchStatus: MediaResourceStatus?
            if let actualFetchStatus = self.actualFetchStatus, message.forwardInfo != nil {
                fetchStatus = actualFetchStatus
            } else if case let .fetchStatus(status) = resourceStatus.mediaStatus {
                fetchStatus = status
            }

            if let fetchStatus = fetchStatus {
                switch fetchStatus {
                    case let .Fetching(_, progress):
                        if let size = file.size {
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
                var playerPosition: Int32?
                var playerDuration: Int32 = 0
                if !playerStatus.generationTimestamp.isZero, case .playing = playerStatus.status {
                    playerPosition = Int32(playerStatus.timestamp + (CACurrentMediaTime() - playerStatus.generationTimestamp))
                } else {
                    playerPosition = Int32(playerStatus.timestamp)
                }
                playerDuration = Int32(playerStatus.duration)
                
                let durationString = stringForDuration(playerDuration > 0 ? playerDuration : (audioDuration ?? 0), position: playerPosition)
                let durationFont = Font.regular(floor(presentationData.fontSize.baseDisplaySize * 11.0 / 17.0))
                downloadingStrings = (durationString, durationString, durationFont)
            }
        }
        
        switch resourceStatus.mediaStatus {
            case var .fetchStatus(fetchStatus):
                if self.message?.forwardInfo != nil {
                    fetchStatus = resourceStatus.fetchStatus
                }
                self.waveformScrubbingNode?.enableScrubbing = false
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
                        if isAudio {
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
                self.waveformScrubbingNode?.enableScrubbing = true
                switch playbackStatus {
                    case .playing:
                        state = .pause
                    case .paused:
                        state = .play
                }
        }
        
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
        
        let backgroundNodeColor: UIColor
        let foregroundNodeColor: UIColor
        if self.iconNode != nil {
            backgroundNodeColor = presentationData.theme.theme.chat.message.mediaOverlayControlColors.fillColor
            foregroundNodeColor = .white
        } else {
            backgroundNodeColor = messageTheme.mediaActiveControlColor
            foregroundNodeColor = .clear
        }

        if state != .none && self.statusNode == nil {
            var image: Signal<(TransformImageArguments) -> DrawingContext?, NoError>? = nil
                        
            if file.isMusic {
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
                    
                    image = playerAlbumArt(postbox: context.account.postbox, engine: context.engine, fileReference: .message(message: MessageReference(message), media: file), albumArt: .init(thumbnailResource: ExternalMusicAlbumArtResource(title: title ?? "", performer: performer ?? "", isThumbnail: true), fullSizeResource: ExternalMusicAlbumArtResource(title: title ?? "", performer: performer ?? "", isThumbnail: false)), thumbnail: true, overlayColor: UIColor(white: 0.0, alpha: 0.3), drawPlaceholderWhenEmpty: false, attemptSynchronously: !animated)
                }
            }
            let statusNode = SemanticStatusNode(backgroundNodeColor: backgroundNodeColor, foregroundNodeColor: foregroundNodeColor, image: image, overlayForegroundNodeColor:  presentationData.theme.theme.chat.message.mediaOverlayControlColors.foregroundColor)
            self.statusNode = statusNode

            self.statusContainerNode.contentNode.insertSubnode(statusNode, at: 0)
            self.statusContainerNode.frame = progressFrame
            self.statusContainerNode.contentRect = CGRect(origin: CGPoint(), size: progressFrame.size)
            self.statusContainerNode.contentNode.frame = CGRect(origin: CGPoint(), size: progressFrame.size)
            statusNode.frame = CGRect(origin: CGPoint(), size: progressFrame.size)
        } else if let statusNode = self.statusNode {
            statusNode.backgroundNodeColor = backgroundNodeColor
        }
        
        if case .pause = state, isVoice, self.playbackAudioLevelNode == nil {
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
        self.playbackAudioLevelNode?.setColor(messageTheme.mediaActiveControlColor)
        
        if streamingState != .none && self.streamingStatusNode == nil {
            let streamingStatusNode = SemanticStatusNode(backgroundNodeColor: backgroundNodeColor, foregroundNodeColor: foregroundNodeColor)
            self.streamingStatusNode = streamingStatusNode
            streamingStatusNode.frame = streamingCacheStatusFrame
            self.addSubnode(streamingStatusNode)
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
            
            switch state {
            case .pause:
                self.playbackAudioLevelNode?.startAnimating()
            default:
                self.playbackAudioLevelNode?.stopAnimating()
            }
        }
        
        if let streamingStatusNode = self.streamingStatusNode {
            if streamingState == .none {
                self.streamingStatusNode = nil
                streamingStatusNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak streamingStatusNode] _ in
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
        
        if streamingState == .none && self.selectionNode == nil {
            self.statusNode?.setCutout(nil, animated: animated)
        } else if let statusNode = self.statusNode, (self.iconNode?.isHidden ?? true) {
            statusNode.setCutout(cutoutFrame, animated: true)
        }
        
        if let (expandedString, compactString, font) = downloadingStrings {
            self.fetchingTextNode.attributedText = NSAttributedString(string: expandedString, font: font, textColor: messageTheme.fileDurationColor)
            self.fetchingCompactTextNode.attributedText = NSAttributedString(string: compactString, font: font, textColor: messageTheme.fileDurationColor)
        } else {
            self.fetchingTextNode.attributedText = nil
            self.fetchingCompactTextNode.attributedText = nil
        }
        
        let maxFetchingStatusWidth = max(self.titleNode.frame.width, self.descriptionMeasuringNode.frame.width) + 2.0
        let fetchingInfo = self.fetchingTextNode.updateLayoutInfo(CGSize(width: maxFetchingStatusWidth, height: CGFloat.greatestFiniteMagnitude))
        let fetchingCompactSize = self.fetchingCompactTextNode.updateLayout(CGSize(width: maxFetchingStatusWidth, height: CGFloat.greatestFiniteMagnitude))
        
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
        
        self.fetchingTextNode.frame = CGRect(origin: self.descriptionNode.frame.origin, size: fetchingInfo.size)
        self.fetchingCompactTextNode.frame = CGRect(origin: self.descriptionNode.frame.origin, size: fetchingCompactSize)
    }
    
    static func asyncLayout(_ node: ChatMessageInteractiveFileNode?) -> (Arguments) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, (Bool, ListViewItemUpdateAnimation) -> ChatMessageInteractiveFileNode))) {
        let currentAsyncLayout = node?.asyncLayout()
        
        return { arguments in
            var fileNode: ChatMessageInteractiveFileNode
            var fileLayout: (Arguments) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, (Bool, ListViewItemUpdateAnimation) -> Void)))
            
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
                    
                    return (finalSize, { synchronousLoads, animation in
                        apply(synchronousLoads, animation)
                        return fileNode
                    })
                })
            })
        }
    }
    
    func transitionNode(media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        if let iconNode = self.iconNode, let file = self.file, file.isEqual(to: media) {
            return (iconNode, iconNode.bounds, { [weak iconNode] in
                return (iconNode?.view.snapshotContentTree(unhide: true), nil)
            })
        } else {
            return nil
        }
    }
    
    func updateHiddenMedia(_ media: [Media]?) -> Bool {
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
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
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
        return super.hitTest(point, with: event)
    }
    
    func hasTapAction(at point: CGPoint) -> Bool {
        if let _ = self.dateAndStatusNode.hitTest(self.view.convert(point, to: self.dateAndStatusNode.view), with: nil) {
            return true
        }
        return false
    }
}


final class FileMessageSelectionNode: ASDisplayNode {
    enum NodeType {
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

