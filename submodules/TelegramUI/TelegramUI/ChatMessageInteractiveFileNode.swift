import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import Display
import TelegramCore
import SyncCore
import UniversalMediaPlayer
import TelegramPresentationData
import AccountContext
import PhotoResources
import TelegramStringFormatting
import RadialStatusNode
import SemanticStatusNode

private struct FetchControls {
    let fetch: () -> Void
    let cancel: () -> Void
}

final class ChatMessageInteractiveFileNode: ASDisplayNode {
    private let titleNode: TextNode
    private let descriptionNode: TextNode
    private let descriptionMeasuringNode: TextNode
    private let fetchingTextNode: ImmediateTextNode
    private let fetchingCompactTextNode: ImmediateTextNode
    private let waveformNode: AudioWaveformNode
    private let waveformForegroundNode: AudioWaveformNode
    private var waveformScrubbingNode: MediaPlayerScrubbingNode?
    private let dateAndStatusNode: ChatMessageDateAndStatusNode
    private let consumableContentNode: ASImageNode
    
    private var iconNode: TransformImageNode?
    private var statusNode: SemanticStatusNode?
    private var streamingStatusNode: RadialStatusNode?
    private var tapRecognizer: UITapGestureRecognizer?
    
    private let statusDisposable = MetaDisposable()
    private let playbackStatusDisposable = MetaDisposable()
    private let playbackStatus = Promise<MediaPlayerStatus>()
    
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
    
    private let fetchControls = Atomic<FetchControls?>(value: nil)
    private var resourceStatus: FileMediaResourceStatus?
    private var actualFetchStatus: MediaResourceStatus?
    private let fetchDisposable = MetaDisposable()
    
    var activateLocalContent: () -> Void = { }
    var requestUpdateLayout: (Bool) -> Void = { _ in }
    
    private var context: AccountContext?
    private var message: Message?
    private var presentationData: ChatPresentationData?
    private var file: TelegramMediaFile?
    private var progressFrame: CGRect?
    private var streamingCacheStatusFrame: CGRect?
    private var fileIconImage: UIImage?
    private var cloudFetchIconImage: UIImage?
    private var cloudFetchedIconImage: UIImage?
    
    override init() {
        self.titleNode = TextNode()
        self.titleNode.displaysAsynchronously = true
        self.titleNode.isUserInteractionEnabled = false
        
        self.descriptionNode = TextNode()
        self.descriptionNode.displaysAsynchronously = true
        self.descriptionNode.isUserInteractionEnabled = false
        
        self.descriptionMeasuringNode = TextNode()
        
        self.fetchingTextNode = ImmediateTextNode()
        self.fetchingTextNode.displaysAsynchronously = true
        self.fetchingTextNode.isUserInteractionEnabled = false
        self.fetchingTextNode.maximumNumberOfLines = 1
        self.fetchingTextNode.contentMode = .left
        self.fetchingTextNode.contentsScale = UIScreenScale
        self.fetchingTextNode.isHidden = true
        
        self.fetchingCompactTextNode = ImmediateTextNode()
        self.fetchingCompactTextNode.displaysAsynchronously = true
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
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.descriptionNode)
        self.addSubnode(self.fetchingTextNode)
        self.addSubnode(self.fetchingCompactTextNode)
    }
    
    deinit {
        self.statusDisposable.dispose()
        self.playbackStatusDisposable.dispose()
        self.fetchDisposable.dispose()
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
            case .Remote:
                if let fetch = self.fetchControls.with({ return $0?.fetch }) {
                    fetch()
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
                            deleteMessages(transaction: transaction, mediaBox: context.account.postbox.mediaBox, ids: [message.id])
                        }).start()
                    } else {
                        switch fetchStatus {
                            case .Fetching:
                                if let cancel = self.fetchControls.with({ return $0?.cancel }) {
                                    cancel()
                                }
                            case .Remote:
                                if let fetch = self.fetchControls.with({ return $0?.fetch }) {
                                    fetch()
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
    
    func asyncLayout() -> (_ context: AccountContext, _ presentationData: ChatPresentationData, _ message: Message, _ attributes: ChatMessageEntryAttributes, _ file: TelegramMediaFile, _ automaticDownload: Bool, _ incoming: Bool, _ isRecentActions: Bool, _ forcedResourceStatus: FileMediaResourceStatus?, _ dateAndStatusType: ChatMessageDateAndStatusType?, _ constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, (Bool) -> Void))) {
        let currentFile = self.file
        
        let titleAsyncLayout = TextNode.asyncLayout(self.titleNode)
        let descriptionAsyncLayout = TextNode.asyncLayout(self.descriptionNode)
        let descriptionMeasuringAsyncLayout = TextNode.asyncLayout(self.descriptionMeasuringNode)
        let statusLayout = self.dateAndStatusNode.asyncLayout()
        
        let currentMessage = self.message
        
        return { context, presentationData, message, attributes, file, automaticDownload, incoming, isRecentActions, forcedResourceStatus, dateAndStatusType, constrainedSize in
            return (CGFloat.greatestFiniteMagnitude, { constrainedSize in
                let titleFont = Font.regular(floor(presentationData.fontSize.baseDisplaySize * 16.0 / 17.0))
                let descriptionFont = Font.regular(floor(presentationData.fontSize.baseDisplaySize * 13.0 / 17.0))
                let durationFont = Font.regular(floor(presentationData.fontSize.baseDisplaySize * 11.0 / 17.0))
                
                var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
                var updatedStatusSignal: Signal<(FileMediaResourceStatus, MediaResourceStatus?), NoError>?
                var updatedPlaybackStatusSignal: Signal<MediaPlayerStatus, NoError>?
                var updatedFetchControls: FetchControls?
                
                var mediaUpdated = false
                if let currentFile = currentFile {
                    mediaUpdated = file != currentFile
                } else {
                    mediaUpdated = true
                }
                
                var statusUpdated = mediaUpdated
                if currentMessage?.id != message.id || currentMessage?.flags != message.flags {
                    statusUpdated = true
                }
                
                let hasThumbnail = (!file.previewRepresentations.isEmpty || file.immediateThumbnailData != nil) && !file.isMusic && !file.isVoice
                
                if mediaUpdated {
                    if largestImageRepresentation(file.previewRepresentations) != nil || file.immediateThumbnailData != nil {
                        updateImageSignal = chatMessageImageFile(account: context.account, fileReference: .message(message: MessageReference(message), media: file), thumbnail: true)
                    }
                    
                    updatedFetchControls = FetchControls(fetch: { [weak self] in
                        if let strongSelf = self {
                            strongSelf.fetchDisposable.set(messageMediaFileInteractiveFetched(context: context, message: message, file: file, userInitiated: true).start())
                        }
                    }, cancel: {
                        messageMediaFileCancelInteractiveFetch(context: context, messageId: message.id, file: file)
                    })
                }
                
                if statusUpdated {
                    if message.flags.isSending {
                        updatedStatusSignal = combineLatest(messageFileMediaResourceStatus(context: context, file: file, message: message, isRecentActions: isRecentActions), messageMediaFileStatus(context: context, messageId: message.id, file: file))
                        |> map { resourceStatus, actualFetchStatus -> (FileMediaResourceStatus, MediaResourceStatus?) in
                            return (resourceStatus, actualFetchStatus)
                        }
                    } else {
                        updatedStatusSignal = messageFileMediaResourceStatus(context: context, file: file, message: message, isRecentActions: isRecentActions)
                        |> map { resourceStatus -> (FileMediaResourceStatus, MediaResourceStatus?) in
                            return (resourceStatus, nil)
                        }
                    }
                    updatedPlaybackStatusSignal = messageFileMediaPlaybackStatus(context: context, file: file, message: message, isRecentActions: isRecentActions)
                }
                
                var statusSize: CGSize?
                var statusApply: ((Bool) -> Void)?
                
                var consumableContentIcon: UIImage?
                for attribute in message.attributes {
                    if let attribute = attribute as? ConsumableContentMessageAttribute {
                        if !attribute.consumed {
                            if incoming {
                                consumableContentIcon = PresentationResourcesChat.chatBubbleConsumableContentIncomingIcon(presentationData.theme.theme)
                            } else {
                                consumableContentIcon = PresentationResourcesChat.chatBubbleConsumableContentOutgoingIcon(presentationData.theme.theme)
                            }
                        }
                        break
                    }
                }
                
                if let statusType = dateAndStatusType {
                    var edited = false
                    if attributes.updatingMedia != nil {
                        edited = true
                    }
                    var viewCount: Int?
                    for attribute in message.attributes {
                        if let attribute = attribute as? EditedMessageAttribute {
                            edited = !attribute.isHidden
                        } else if let attribute = attribute as? ViewCountMessageAttribute {
                            viewCount = attribute.count
                        }
                    }
                    
                    var dateReactions: [MessageReaction] = []
                    var dateReactionCount = 0
                    if let reactionsAttribute = mergedMessageReactions(attributes: message.attributes), !reactionsAttribute.reactions.isEmpty {
                        for reaction in reactionsAttribute.reactions {
                            if reaction.isSelected {
                                dateReactions.insert(reaction, at: 0)
                            } else {
                                dateReactions.append(reaction)
                            }
                            dateReactionCount += Int(reaction.count)
                        }
                    }
                    
                    let dateText = stringForMessageTimestampStatus(accountPeerId: context.account.peerId, message: message, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, strings: presentationData.strings, reactionCount: dateReactionCount)
                    
                    let (size, apply) = statusLayout(context, presentationData, edited, viewCount, dateText, statusType, constrainedSize, dateReactions)
                    statusSize = size
                    statusApply = apply
                }
                
                var candidateTitleString: NSAttributedString?
                var candidateDescriptionString: NSAttributedString?
                
                var isAudio = false
                var audioWaveform: AudioWaveform?
                var isVoice = false
                var audioDuration: Int32 = 0
                
                let messageTheme = incoming ? presentationData.theme.theme.chat.message.incoming : presentationData.theme.theme.chat.message.outgoing
                
                for attribute in file.attributes {
                    if case let .Audio(voice, duration, title, performer, waveform) = attribute {
                        isAudio = true
                        
                        if let forcedResourceStatus = forcedResourceStatus, statusUpdated {
                            updatedStatusSignal = .single((forcedResourceStatus, nil))
                        } else if let currentUpdatedStatusSignal = updatedStatusSignal {
                            updatedStatusSignal = currentUpdatedStatusSignal
                            |> map { status, _ in
                                switch status.mediaStatus {
                                    case let .fetchStatus(fetchStatus):
                                        if !voice && !message.flags.isSending {
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
                                waveform.withDataNoCopy { data in
                                    audioWaveform = AudioWaveform(bitstream: data, bitsPerSample: 5)
                                }
                            }
                        } else {
                            candidateTitleString = NSAttributedString(string: title ?? (file.fileName ?? "Unknown Track"), font: titleFont, textColor: messageTheme.fileTitleColor)
                            let descriptionText: String
                            if let performer = performer {
                                descriptionText = performer
                            } else if let size = file.size {
                                descriptionText = dataSizeString(size, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)
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
                    titleString = NSAttributedString(string: file.fileName ?? "File", font: titleFont, textColor: messageTheme.fileTitleColor)
                }
                
                if let candidateDescriptionString = candidateDescriptionString {
                    descriptionString = candidateDescriptionString
                } else if !isVoice {
                    let descriptionText: String
                    if let size = file.size {
                        descriptionText = dataSizeString(size, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)
                    } else {
                        descriptionText = ""
                    }
                    descriptionString = NSAttributedString(string: descriptionText, font: descriptionFont, textColor: messageTheme.fileDescriptionColor)
                }
                
                var textConstrainedSize = CGSize(width: constrainedSize.width - 44.0 - 8.0, height: constrainedSize.height)
                if hasThumbnail {
                    textConstrainedSize.width -= 80.0
                }
                
                let streamingProgressDiameter: CGFloat = 28.0
                var hasStreamingProgress = false
                if isAudio && !isVoice {
                    hasStreamingProgress = true
                    
                    if hasStreamingProgress {
                        textConstrainedSize.width -= streamingProgressDiameter + 4.0
                    }
                }
                
                let (titleLayout, titleApply) = titleAsyncLayout(TextNodeLayoutArguments(attributedString: titleString, backgroundColor: nil, maximumNumberOfLines: hasThumbnail ? 2 : 1, truncationType: .middle, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                let (descriptionLayout, descriptionApply) = descriptionAsyncLayout(TextNodeLayoutArguments(attributedString: descriptionString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .middle, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                let fileSizeString: String
                if let _ = file.size {
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
                
                var minLayoutWidth: CGFloat
                if hasThumbnail {
                    minLayoutWidth = max(titleLayout.size.width, descriptionMaxWidth) + 86.0
                } else if isVoice {
                    let calcDuration = max(minVoiceLength, min(maxVoiceLength, CGFloat(audioDuration)))
                    minLayoutWidth = minVoiceWidth + (maxVoiceWidth - minVoiceWidth) * (calcDuration - minVoiceLength) / (maxVoiceLength - minVoiceLength)
                } else {
                    minLayoutWidth = max(titleLayout.size.width, descriptionMaxWidth) + 44.0 + 8.0
                }
                
                if let statusSize = statusSize {
                    minLayoutWidth = max(minLayoutWidth, statusSize.width)
                }
                
                var cloudFetchIconImage: UIImage?
                var cloudFetchedIconImage: UIImage?
                if hasStreamingProgress {
                    minLayoutWidth += streamingProgressDiameter + 4.0
                    cloudFetchIconImage = incoming ? PresentationResourcesChat.chatBubbleFileCloudFetchIncomingIcon(presentationData.theme.theme) : PresentationResourcesChat.chatBubbleFileCloudFetchOutgoingIcon(presentationData.theme.theme)
                    cloudFetchedIconImage = incoming ? PresentationResourcesChat.chatBubbleFileCloudFetchedIncomingIcon(presentationData.theme.theme) : PresentationResourcesChat.chatBubbleFileCloudFetchedOutgoingIcon(presentationData.theme.theme)
                }
                
                let fileIconImage: UIImage?
                if hasThumbnail {
                    fileIconImage = nil
                } else {
                    let principalGraphics = PresentationResourcesChat.principalGraphics(mediaBox: context.account.postbox.mediaBox, knockoutWallpaper: context.sharedContext.immediateExperimentalUISettings.knockoutWallpaper, theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
                    
                    fileIconImage = incoming ? principalGraphics.radialIndicatorFileIconIncoming : principalGraphics.radialIndicatorFileIconOutgoing
                }
                
                return (minLayoutWidth, { boundingWidth in
                    let progressDiameter: CGFloat = (isVoice && !hasThumbnail) ? 37.0 : 44.0
                    
                    var iconFrame: CGRect?
                    let progressFrame: CGRect
                    let streamingCacheStatusFrame: CGRect
                    let controlAreaWidth: CGFloat
                    
                    if hasThumbnail {
                        let currentIconFrame = CGRect(origin: CGPoint(x: -1.0, y: -7.0), size: CGSize(width: 74.0, height: 74.0))
                        iconFrame = currentIconFrame
                        progressFrame = CGRect(origin: CGPoint(x: currentIconFrame.minX + floor((currentIconFrame.size.width - progressDiameter) / 2.0), y: currentIconFrame.minY + floor((currentIconFrame.size.height - progressDiameter) / 2.0)), size: CGSize(width: progressDiameter, height: progressDiameter))
                        controlAreaWidth = 86.0
                    } else {
                        progressFrame = CGRect(origin: CGPoint(x: 0.0, y: isVoice ? -5.0 : 0.0), size: CGSize(width: progressDiameter, height: progressDiameter))
                        controlAreaWidth = progressFrame.maxX + 8.0
                    }
                    
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
                        descriptionFrame = CGRect(origin: CGPoint(x: 43.0, y: 19.0), size: descriptionLayout.size)
                    } else {
                        descriptionFrame = CGRect(origin: CGPoint(x: titleFrame.minX, y: titleFrame.maxY - 1.0), size: descriptionLayout.size)
                    }
                    
                    var fittedLayoutSize: CGSize
                    if hasThumbnail {
                        let textSizes = titleFrame.union(descriptionFrame).size
                        fittedLayoutSize = CGSize(width: textSizes.width + controlAreaWidth, height: 59.0)
                    } else if isVoice {
                        fittedLayoutSize = CGSize(width: minLayoutWidth, height: 27.0)
                    } else {
                        let unionSize = titleFrame.union(descriptionFrame).union(progressFrame).size
                        fittedLayoutSize = CGSize(width: unionSize.width, height: unionSize.height + 6.0)
                    }
                    
                    var statusFrame: CGRect?
                    if let statusSize = statusSize {
                        fittedLayoutSize.width = max(fittedLayoutSize.width, statusSize.width)
                        statusFrame = CGRect(origin: CGPoint(x: boundingWidth - statusSize.width, y: fittedLayoutSize.height - statusSize.height + 10.0), size: statusSize)
                    }
                    
                    if let statusFrameValue = statusFrame, descriptionFrame.intersects(statusFrameValue)  {
                        fittedLayoutSize.height += statusFrameValue.height
                        statusFrame = statusFrameValue.offsetBy(dx: 0.0, dy: statusFrameValue.height)
                    }
                    if let statusFrameValue = statusFrame, let iconFrame = iconFrame, iconFrame.intersects(statusFrameValue) {
                        fittedLayoutSize.height += 15.0
                        statusFrame = statusFrameValue.offsetBy(dx: 0.0, dy: 15.0)
                    }
                    
                    if isAudio && !isVoice {
                        streamingCacheStatusFrame = CGRect(origin: CGPoint(x: boundingWidth - streamingProgressDiameter + 1.0, y: 8.0), size: CGSize(width: streamingProgressDiameter, height: streamingProgressDiameter))
                        if hasStreamingProgress {
                            fittedLayoutSize.width += streamingProgressDiameter + 6.0
                        }
                        fittedLayoutSize.width = max(fittedLayoutSize.width, boundingWidth + 2.0)
                    } else {
                        streamingCacheStatusFrame = CGRect()
                    }
                    
                    return (fittedLayoutSize, { [weak self] synchronousLoads in
                        if let strongSelf = self {
                            strongSelf.context = context
                            strongSelf.presentationData = presentationData
                            strongSelf.message = message
                            strongSelf.file = file
                            
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
                            
                            if let statusApply = statusApply, let statusFrame = statusFrame {
                                if strongSelf.dateAndStatusNode.supernode == nil {
                                   strongSelf.addSubnode(strongSelf.dateAndStatusNode)
                                }
                                
                                strongSelf.dateAndStatusNode.frame = statusFrame
                                statusApply(false)
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
                                strongSelf.waveformScrubbingNode?.frame = CGRect(origin: CGPoint(x: 43.0, y: -1.0), size: CGSize(width: boundingWidth - 41.0, height: 12.0))
                                let waveformColor: UIColor
                                if incoming {
                                    if consumableContentIcon != nil {
                                        waveformColor = messageTheme.mediaActiveControlColor
                                    } else {
                                        waveformColor = messageTheme.mediaInactiveControlColor
                                    }
                                } else {
                                    waveformColor = messageTheme.mediaInactiveControlColor
                                }
                                strongSelf.waveformNode.setup(color: waveformColor, waveform: audioWaveform)
                                strongSelf.waveformForegroundNode.setup(color: messageTheme.mediaActiveControlColor, waveform: audioWaveform)
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
                            
                            strongSelf.waveformNode.displaysAsynchronously = !presentationData.isPreview
                            strongSelf.statusNode?.displaysAsynchronously = !presentationData.isPreview
                            strongSelf.statusNode?.frame = progressFrame
                            strongSelf.progressFrame = progressFrame
                            strongSelf.streamingCacheStatusFrame = streamingCacheStatusFrame
                            strongSelf.fileIconImage = fileIconImage
                            strongSelf.cloudFetchIconImage = cloudFetchIconImage
                            strongSelf.cloudFetchedIconImage = cloudFetchedIconImage
                            
                            if let updatedFetchControls = updatedFetchControls {
                                let _ = strongSelf.fetchControls.swap(updatedFetchControls)
                                if automaticDownload {
                                    updatedFetchControls.fetch()
                                }
                            }
                            
                            strongSelf.updateStatus(animated: !synchronousLoads)
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
        var streamingState: RadialStatusNodeState = .none
        
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
                            let compactString = dataSizeString(Int(Float(size) * progress), forceDecimal: true, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)
                            let descriptionFont = Font.regular(floor(presentationData.fontSize.baseDisplaySize * 13.0 / 17.0))
                            downloadingStrings = ("\(compactString) / \(dataSizeString(size, forceDecimal: true, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator))", compactString, descriptionFont)
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
        
        if isAudio && !isVoice && !isSending {
            let streamingStatusForegroundColor: UIColor = messageTheme.accentControlColor
            let streamingStatusBackgroundColor: UIColor = messageTheme.mediaInactiveControlColor
            switch resourceStatus.fetchStatus {
                case let .Fetching(_, progress):
                    let adjustedProgress = max(progress, 0.027)
                    streamingState = .cloudProgress(color: streamingStatusForegroundColor, strokeBackgroundColor: streamingStatusBackgroundColor, lineWidth: 2.0, value: CGFloat(adjustedProgress))
                case .Local:
                    if let cloudFetchedIconImage = self.cloudFetchedIconImage {
                        streamingState = .customIcon(cloudFetchedIconImage)
                    } else {
                        streamingState = .none
                    }
                case .Remote:
                    if let cloudFetchIconImage = self.cloudFetchIconImage {
                        streamingState = .customIcon(cloudFetchIconImage)
                    } else {
                        streamingState = .none
                    }
            }
        } else {
            streamingState = .none
        }
        
        let statusForegroundColor: UIColor
        if self.iconNode != nil {
            statusForegroundColor = presentationData.theme.theme.chat.message.mediaOverlayControlColors.foregroundColor
        } else {
            statusForegroundColor = incoming ? presentationData.theme.theme.chat.message.incoming.mediaControlInnerBackgroundColor : presentationData.theme.theme.chat.message.outgoing.mediaControlInnerBackgroundColor
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
                        state = .progress(value: CGFloat(adjustedProgress), cancelEnabled: true)
                    case .Local:
                        if isAudio {
                            state = .play
                        } else if let fileIconImage = self.fileIconImage {
                            state = .customIcon(fileIconImage)
                        } else {
                            state = .none
                        }
                    case .Remote:
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
            let statusNode = SemanticStatusNode(backgroundNodeColor: backgroundNodeColor, foregroundNodeColor: foregroundNodeColor)
            self.statusNode = statusNode
            statusNode.frame = progressFrame
            self.addSubnode(statusNode)
        } else if let statusNode = self.statusNode {
            statusNode.backgroundNodeColor = backgroundNodeColor
        }
        
        if streamingState != .none && self.streamingStatusNode == nil {
            let streamingStatusNode = RadialStatusNode(backgroundNodeColor: .clear)
            self.streamingStatusNode = streamingStatusNode
            streamingStatusNode.frame = streamingCacheStatusFrame
            self.addSubnode(streamingStatusNode)
        }
        
        if let statusNode = self.statusNode {
            if state == .none {
                self.statusNode = nil
            }
            statusNode.transitionToState(state, animated: animated, synchronous: presentationData.theme.theme.preview, completion: { [weak statusNode] in
                if state == .none {
                    statusNode?.removeFromSupernode()
                }
            })
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
    
    static func asyncLayout(_ node: ChatMessageInteractiveFileNode?) -> (_ context: AccountContext, _ presentationData: ChatPresentationData, _ message: Message, _ attributes: ChatMessageEntryAttributes, _ file: TelegramMediaFile, _ automaticDownload: Bool, _ incoming: Bool, _ isRecentActions: Bool, _ forcedResourceStatus: FileMediaResourceStatus?, _ dateAndStatusType: ChatMessageDateAndStatusType?, _ constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, (Bool) -> ChatMessageInteractiveFileNode))) {
        let currentAsyncLayout = node?.asyncLayout()
        
        return { context, presentationData, message, attributes, file, automaticDownload, incoming, isRecentActions, forcedResourceStatus, dateAndStatusType, constrainedSize in
            var fileNode: ChatMessageInteractiveFileNode
            var fileLayout: (_ context: AccountContext, _ presentationData: ChatPresentationData, _ message: Message, _ attributes: ChatMessageEntryAttributes, _ file: TelegramMediaFile, _ automaticDownload: Bool, _ incoming: Bool, _ isRecentActions: Bool, _ forcedResourceStatus: FileMediaResourceStatus?, _ dateAndStatusType: ChatMessageDateAndStatusType?, _ constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, (Bool) -> Void)))
            
            if let node = node, let currentAsyncLayout = currentAsyncLayout {
                fileNode = node
                fileLayout = currentAsyncLayout
            } else {
                fileNode = ChatMessageInteractiveFileNode()
                fileLayout = fileNode.asyncLayout()
            }
            
            let (initialWidth, continueLayout) = fileLayout(context, presentationData, message, attributes, file, automaticDownload, incoming, isRecentActions, forcedResourceStatus, dateAndStatusType, constrainedSize)
            
            return (initialWidth, { constrainedSize in
                let (finalWidth, finalLayout) = continueLayout(constrainedSize)
                
                return (finalWidth, { boundingWidth in
                    let (finalSize, apply) = finalLayout(boundingWidth)
                    
                    return (finalSize, { synchronousLoads in
                        apply(synchronousLoads)
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
    
    func reactionTargetNode(value: String) -> (ASDisplayNode, Int)? {
        if !self.dateAndStatusNode.isHidden {
            return self.dateAndStatusNode.reactionNode(value: value)
        }
        return nil
    }
}
