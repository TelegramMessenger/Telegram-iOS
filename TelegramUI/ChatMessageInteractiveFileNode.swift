import Foundation
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import Display
import TelegramCore

private struct FetchControls {
    let fetch: () -> Void
    let cancel: () -> Void
}

private let titleFont = Font.regular(16.0)
private let descriptionFont = Font.regular(13.0)
private let durationFont = Font.regular(11.0)

final class ChatMessageInteractiveFileNode: ASDisplayNode {
    private let titleNode: TextNode
    private let descriptionNode: TextNode
    private let waveformNode: AudioWaveformNode
    private let waveformForegroundNode: AudioWaveformNode
    private var waveformScrubbingNode: MediaPlayerScrubbingNode?
    private let dateAndStatusNode: ChatMessageDateAndStatusNode
    private let consumableContentNode: ASImageNode
    
    private var iconNode: TransformImageNode?
    private var statusNode: RadialStatusNode?
    private var tapRecognizer: UITapGestureRecognizer?
    
    private let statusDisposable = MetaDisposable()
    private let playbackStatusDisposable = MetaDisposable()
    private let playbackStatus = Promise<MediaPlayerStatus>()
    private let fetchControls = Atomic<FetchControls?>(value: nil)
    private var resourceStatus: FileMediaResourceStatus?
    private let fetchDisposable = MetaDisposable()
    
    var activateLocalContent: () -> Void = { }
    
    private var account: Account?
    private var message: Message?
    private var themeAndStrings: (ChatPresentationThemeData, PresentationStrings)?
    private var file: TelegramMediaFile?
    
    override init() {
        self.titleNode = TextNode()
        self.titleNode.displaysAsynchronously = true
        self.titleNode.isLayerBacked = true
        
        self.descriptionNode = TextNode()
        self.descriptionNode.displaysAsynchronously = true
        self.descriptionNode.isLayerBacked = true
        
        self.waveformNode = AudioWaveformNode()
        self.waveformNode.isLayerBacked = true
        self.waveformForegroundNode = AudioWaveformNode()
        self.waveformForegroundNode.isLayerBacked = true
        
        self.dateAndStatusNode = ChatMessageDateAndStatusNode()
        
        self.consumableContentNode = ASImageNode()
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.descriptionNode)
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
    
    @objc func progressPressed() {
        if let resourceStatus = self.resourceStatus {
            switch resourceStatus {
                case let .fetchStatus(fetchStatus):
                    if let account = self.account, let message = self.message, message.flags.isSending {
                        let _ = account.postbox.transaction({ transaction -> Void in
                            deleteMessages(transaction: transaction, mediaBox: account.postbox.mediaBox, ids: [message.id])
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
                    if let account = self.account, let applicationContext = account.applicationContext as? TelegramApplicationContext, let message = self.message, let type = peerMessageMediaPlayerType(message) {
                        applicationContext.mediaManager?.playlistControl(.playback(.togglePlayPause), type: type)
                    }
            }
        }
    }
    
    @objc func fileTap(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.progressPressed()
        }
    }
    
    func asyncLayout() -> (_ account: Account, _ presentationData: ChatPresentationData, _ message: Message, _ file: TelegramMediaFile, _ automaticDownload: Bool, _ incoming: Bool, _ isRecentActions: Bool, _ dateAndStatusType: ChatMessageDateAndStatusType?, _ constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, () -> Void))) {
        let currentFile = self.file
        
        let titleAsyncLayout = TextNode.asyncLayout(self.titleNode)
        let descriptionAsyncLayout = TextNode.asyncLayout(self.descriptionNode)
        let statusLayout = self.dateAndStatusNode.asyncLayout()
        
        let currentMessage = self.message
        let currentTheme = self.themeAndStrings?.0
        
        return { account, presentationData, message, file, automaticDownload, incoming, isRecentActions, dateAndStatusType, constrainedSize in
            var updatedTheme: ChatPresentationThemeData?
            
            if presentationData.theme != currentTheme {
                updatedTheme = presentationData.theme
            }
            
            return (CGFloat.greatestFiniteMagnitude, { constrainedSize in
                var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
                var updatedStatusSignal: Signal<FileMediaResourceStatus, NoError>?
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
                
                let hasThumbnail = !file.previewRepresentations.isEmpty && !file.isMusic && !file.isVoice
                
                if mediaUpdated {
                    if let _ = largestImageRepresentation(file.previewRepresentations) {
                        updateImageSignal = chatMessageImageFile(account: account, fileReference: .message(message: MessageReference(message), media: file), thumbnail: true)
                    }
                    
                    updatedFetchControls = FetchControls(fetch: { [weak self] in
                        if let strongSelf = self {
                            strongSelf.fetchDisposable.set(messageMediaFileInteractiveFetched(account: account, message: message, file: file, userInitiated: true).start())
                        }
                    }, cancel: {
                        messageMediaFileCancelInteractiveFetch(account: account, messageId: message.id, file: file)
                    })
                }
                
                if statusUpdated {
                    updatedStatusSignal = messageFileMediaResourceStatus(account: account, file: file, message: message, isRecentActions: isRecentActions)
                    updatedPlaybackStatusSignal = messageFileMediaPlaybackStatus(account: account, file: file, message: message, isRecentActions: isRecentActions)
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
                    var sentViaBot = false
                    var viewCount: Int?
                    for attribute in message.attributes {
                        if let _ = attribute as? EditedMessageAttribute {
                            edited = true
                        } else if let attribute = attribute as? ViewCountMessageAttribute {
                            viewCount = attribute.count
                        } else if let _ = attribute as? InlineBotMessageAttribute {
                            sentViaBot = true
                        }
                    }
                    if let author = message.author as? TelegramUser, author.botInfo != nil {
                        sentViaBot = true
                    }
                    
                    let dateText = stringForMessageTimestampStatus(message: message, dateTimeFormat: presentationData.dateTimeFormat, strings: presentationData.strings)
                    
                    let (size, apply) = statusLayout(presentationData.theme, presentationData.strings, edited && !sentViaBot, viewCount, dateText, statusType, constrainedSize)
                    statusSize = size
                    statusApply = apply
                }
                
                var candidateTitleString: NSAttributedString?
                var candidateDescriptionString: NSAttributedString?
                
                var isAudio = false
                var audioWaveform: AudioWaveform?
                var isVoice = false
                var audioDuration: Int32 = 0
                
                let bubbleTheme = presentationData.theme.theme.chat.bubble
                
                for attribute in file.attributes {
                    if case let .Audio(voice, duration, title, performer, waveform) = attribute {
                        isAudio = true
                        if let currentUpdatedStatusSignal = updatedStatusSignal {
                            updatedStatusSignal = currentUpdatedStatusSignal |> map { status in
                                switch status {
                                    case let .fetchStatus(fetchStatus):
                                        if !voice {
                                            return .fetchStatus(.Local)
                                        } else {
                                            return .fetchStatus(fetchStatus)
                                        }
                                    case .playbackStatus:
                                        return status
                                }
                            }
                        }
                        
                        audioDuration = Int32(duration)
                        if voice {
                            isVoice = true
                            candidateDescriptionString = NSAttributedString(string: String(format: "%d:%02d", duration / 60, duration % 60), font: durationFont, textColor:incoming ? bubbleTheme.incomingFileDurationColor : bubbleTheme.outgoingFileDurationColor)
                            if let waveform = waveform {
                                waveform.withDataNoCopy { data in
                                    audioWaveform = AudioWaveform(bitstream: data, bitsPerSample: 5)
                                }
                            }
                        } else {
                            candidateTitleString = NSAttributedString(string: title ?? (file.fileName ?? "Unknown Track"), font: titleFont, textColor: incoming ? bubbleTheme.incomingFileTitleColor : bubbleTheme.outgoingFileTitleColor)
                            let descriptionText: String
                            if let performer = performer {
                                descriptionText = performer
                            } else if let size = file.size {
                                descriptionText = dataSizeString(size)
                            } else {
                                descriptionText = ""
                            }
                            candidateDescriptionString = NSAttributedString(string: descriptionText, font: descriptionFont, textColor:incoming ? bubbleTheme.incomingFileDescriptionColor : bubbleTheme.outgoingFileDescriptionColor)
                        }
                        break
                    }
                }
                
                var titleString: NSAttributedString?
                var descriptionString: NSAttributedString?
                
                if let candidateTitleString = candidateTitleString {
                    titleString = candidateTitleString
                } else if !isVoice {
                    titleString = NSAttributedString(string: file.fileName ?? "File", font: titleFont, textColor: incoming ? bubbleTheme.incomingFileTitleColor : bubbleTheme.outgoingFileTitleColor)
                }
                
                if let candidateDescriptionString = candidateDescriptionString {
                    descriptionString = candidateDescriptionString
                } else if !isVoice {
                    let descriptionText: String
                    if let size = file.size {
                        descriptionText = dataSizeString(size)
                    } else {
                        descriptionText = ""
                    }
                    descriptionString = NSAttributedString(string: descriptionText, font: descriptionFont, textColor:incoming ? bubbleTheme.incomingFileDescriptionColor : bubbleTheme.outgoingFileDescriptionColor)
                }
                
                var textConstrainedSize = CGSize(width: constrainedSize.width - 44.0 - 8.0, height: constrainedSize.height)
                if hasThumbnail {
                    textConstrainedSize.width -= 80.0
                }
                
                let (titleLayout, titleApply) = titleAsyncLayout(TextNodeLayoutArguments(attributedString: titleString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .middle, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                let (descriptionLayout, descriptionApply) = descriptionAsyncLayout(TextNodeLayoutArguments(attributedString: descriptionString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .middle, constrainedSize: textConstrainedSize, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                let minVoiceWidth: CGFloat = 120.0
                let maxVoiceWidth = constrainedSize.width
                let maxVoiceLength: CGFloat = 30.0
                let minVoiceLength: CGFloat = 2.0
                
                var minLayoutWidth: CGFloat
                if hasThumbnail {
                    minLayoutWidth = max(titleLayout.size.width, descriptionLayout.size.width) + 86.0
                } else if isVoice {
                    let calcDuration = max(minVoiceLength, min(maxVoiceLength, CGFloat(audioDuration)))
                    minLayoutWidth = minVoiceWidth + (maxVoiceWidth - minVoiceWidth) * (calcDuration - minVoiceLength) / (maxVoiceLength - minVoiceLength)
                } else {
                    minLayoutWidth = max(titleLayout.size.width, descriptionLayout.size.width) + 44.0 + 8.0
                }
                
                if let statusSize = statusSize {
                    minLayoutWidth = max(minLayoutWidth, statusSize.width)
                }
                
                let fileIconImage: UIImage?
                if hasThumbnail {
                    fileIconImage = nil
                } else {
                    let principalGraphics = PresentationResourcesChat.principalGraphics(presentationData.theme.theme, wallpaper: !presentationData.theme.wallpaper.isEmpty)
                    
                    fileIconImage = incoming ? principalGraphics.radialIndicatorFileIconIncoming : principalGraphics.radialIndicatorFileIconOutgoing
                }
                
                return (minLayoutWidth, { boundingWidth in
                    let progressDiameter: CGFloat = (isVoice && !hasThumbnail) ? 37.0 : 44.0
                    
                    var iconFrame: CGRect?
                    let progressFrame: CGRect
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
                        fittedLayoutSize = CGSize(width: unionSize.width, height: unionSize.height + 4.0)
                    }
                    
                    var statusFrame: CGRect?
                    if let statusSize = statusSize {
                        fittedLayoutSize.width = max(fittedLayoutSize.width, statusSize.width)
                        statusFrame = CGRect(origin: CGPoint(x: boundingWidth - statusSize.width, y: fittedLayoutSize.height - statusSize.height + 10.0), size: statusSize)
                    }
                    
                    if let statusFrameValue = statusFrame, descriptionFrame.intersects(statusFrameValue) {
                        fittedLayoutSize.height += 10.0
                        statusFrame = statusFrameValue.offsetBy(dx: 0.0, dy: 10.0)
                    }
                    
                    return (fittedLayoutSize, { [weak self] in
                        if let strongSelf = self {
                            strongSelf.account = account
                            strongSelf.themeAndStrings = (presentationData.theme, presentationData.strings)
                            strongSelf.message = message
                            strongSelf.file = file
                            
                            let _ = titleApply()
                            let _ = descriptionApply()
                            
                            strongSelf.titleNode.frame = titleFrame
                            strongSelf.descriptionNode.frame = descriptionFrame
                            
                            if let consumableContentIcon = consumableContentIcon {
                                if strongSelf.consumableContentNode.supernode == nil {
                                    strongSelf.addSubnode(strongSelf.consumableContentNode)
                                }
                                if strongSelf.consumableContentNode.image !== consumableContentIcon {
                                    strongSelf.consumableContentNode.image = consumableContentIcon
                                }
                                strongSelf.consumableContentNode.frame = CGRect(origin: CGPoint(x: descriptionFrame.maxX + 2.0, y: descriptionFrame.minY + 5.0), size: consumableContentIcon.size)
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
                                    waveformScrubbingNode.hitTestSlop = UIEdgeInsetsMake(-10.0, 0.0, -10.0, 0.0)
                                    waveformScrubbingNode.seek = { timestamp in
                                        if let strongSelf = self, let account = strongSelf.account, let message = strongSelf.message, let type = peerMessageMediaPlayerType(message) {
                                            account.telegramApplicationContext.mediaManager?.playlistControl(.seek(timestamp), type: type)
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
                                        waveformColor = bubbleTheme.incomingMediaActiveControlColor
                                    } else {
                                        waveformColor = bubbleTheme.incomingMediaInactiveControlColor
                                    }
                                } else {
                                    waveformColor = bubbleTheme.outgoingMediaInactiveControlColor
                                }
                                strongSelf.waveformNode.setup(color: waveformColor, waveform: audioWaveform)
                                strongSelf.waveformForegroundNode.setup(color: incoming ? bubbleTheme.incomingMediaActiveControlColor : bubbleTheme.outgoingMediaActiveControlColor, waveform: audioWaveform)
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
                                    let arguments = TransformImageArguments(corners: ImageCorners(radius: 8.0), imageSize: CGSize(width: 74.0, height: 74.0), boundingSize: CGSize(width: 74.0, height: 74.0), intrinsicInsets: UIEdgeInsets())
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
                            
                            if let updatedStatusSignal = updatedStatusSignal {
                                strongSelf.statusDisposable.set((updatedStatusSignal |> deliverOnMainQueue).start(next: { [weak strongSelf] status in
                                    displayLinkDispatcher.dispatch {
                                        if let strongSelf = strongSelf {
                                            strongSelf.resourceStatus = status
                                            
                                            if strongSelf.statusNode == nil {
                                                let backgroundNodeColor: UIColor
                                                if strongSelf.iconNode != nil {
                                                    backgroundNodeColor = bubbleTheme.mediaOverlayControlBackgroundColor
                                                } else if incoming {
                                                    backgroundNodeColor = bubbleTheme.incomingMediaActiveControlColor
                                                } else {
                                                    backgroundNodeColor = bubbleTheme.outgoingMediaActiveControlColor
                                                }
                                                let statusNode = RadialStatusNode(backgroundNodeColor: backgroundNodeColor)
                                                strongSelf.statusNode = statusNode
                                                statusNode.frame = progressFrame
                                                strongSelf.addSubnode(statusNode)
                                            } else if let _ = updatedTheme {
                                                //strongSelf.progressNode?.updateTheme(RadialProgressTheme(backgroundColor: incoming ? bubbleTheme.incomingAccentColor : bubbleTheme.outgoingAccentColor, foregroundColor: incoming ? bubbleTheme.incomingFillColor : bubbleTheme.outgoingFillColor, icon: fileIconImage))
                                            }
                                            
                                            let state: RadialStatusNodeState
                                            let statusForegroundColor: UIColor
                                            if strongSelf.iconNode != nil {
                                                statusForegroundColor = bubbleTheme.mediaOverlayControlForegroundColor
                                            } else if incoming {
                                                statusForegroundColor = presentationData.theme.wallpaper.isEmpty ? bubbleTheme.incoming.withoutWallpaper.fill : bubbleTheme.incoming.withWallpaper.fill
                                            } else {
                                                statusForegroundColor = presentationData.theme.wallpaper.isEmpty ? bubbleTheme.outgoing.withoutWallpaper.fill : bubbleTheme.outgoing.withWallpaper.fill
                                            }
                                            switch status {
                                                case let .fetchStatus(fetchStatus):
                                                    strongSelf.waveformScrubbingNode?.enableScrubbing = false
                                                    switch fetchStatus {
                                                        case let .Fetching(isActive, progress):
                                                            var adjustedProgress = progress
                                                            if isActive {
                                                                adjustedProgress = max(adjustedProgress, 0.027)
                                                            }
                                                            state = .progress(color: statusForegroundColor, lineWidth: nil, value: CGFloat(adjustedProgress), cancelEnabled: true)
                                                        case .Local:
                                                            if isAudio {
                                                                state = .play(statusForegroundColor)
                                                            } else if let fileIconImage = fileIconImage {
                                                                state = .customIcon(fileIconImage)
                                                            } else {
                                                                state = .none
                                                            }
                                                        case .Remote:
                                                            if isAudio && !isVoice {
                                                                state = .play(statusForegroundColor)
                                                            } else {
                                                                state = .download(statusForegroundColor)
                                                            }
                                                    }
                                                case let .playbackStatus(playbackStatus):
                                                    strongSelf.waveformScrubbingNode?.enableScrubbing = true
                                                    switch playbackStatus {
                                                        case .playing:
                                                            state = .pause(statusForegroundColor)
                                                        case .paused:
                                                            state = .play(statusForegroundColor)
                                                    }
                                            }
                                            
                                            if let statusNode = strongSelf.statusNode {
                                                if state == .none {
                                                    strongSelf.statusNode = nil
                                                }
                                                statusNode.transitionToState(state, completion: { [weak statusNode] in
                                                    if state == .none {
                                                        statusNode?.removeFromSupernode()
                                                    }
                                                })
                                            }
                                        }
                                    }
                                }))
                            }
                            
                            if let updatedPlaybackStatusSignal = updatedPlaybackStatusSignal {
                                strongSelf.playbackStatus.set(updatedPlaybackStatusSignal)
                            }
                            
                            strongSelf.statusNode?.frame = progressFrame
                            
                            if let updatedFetchControls = updatedFetchControls {
                                let _ = strongSelf.fetchControls.swap(updatedFetchControls)
                                if automaticDownload {
                                    updatedFetchControls.fetch()
                                }
                            }
                        }
                    })
                })
            })
        }
    }
    
    static func asyncLayout(_ node: ChatMessageInteractiveFileNode?) -> (_ account: Account, _ presentationData: ChatPresentationData, _ message: Message, _ file: TelegramMediaFile, _ automaticDownload: Bool, _ incoming: Bool, _ isRecentActions: Bool, _ dateAndStatusType: ChatMessageDateAndStatusType?, _ constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, () -> ChatMessageInteractiveFileNode))) {
        let currentAsyncLayout = node?.asyncLayout()
        
        return { account, presentationData, message, file, automaticDownload, incoming, isRecentActions, dateAndStatusType, constrainedSize in
            var fileNode: ChatMessageInteractiveFileNode
            var fileLayout: (_ account: Account, _ presentationData: ChatPresentationData, _ message: Message, _ file: TelegramMediaFile, _ automaticDownload: Bool, _ incoming: Bool, _ isRecentActions: Bool, _ dateAndStatusType: ChatMessageDateAndStatusType?, _ constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, () -> Void)))
            
            if let node = node, let currentAsyncLayout = currentAsyncLayout {
                fileNode = node
                fileLayout = currentAsyncLayout
            } else {
                fileNode = ChatMessageInteractiveFileNode()
                fileLayout = fileNode.asyncLayout()
            }
            
            let (initialWidth, continueLayout) = fileLayout(account, presentationData, message, file, automaticDownload, incoming, isRecentActions, dateAndStatusType, constrainedSize)
            
            return (initialWidth, { constrainedSize in
                let (finalWidth, finalLayout) = continueLayout(constrainedSize)
                
                return (finalWidth, { boundingWidth in
                    let (finalSize, apply) = finalLayout(boundingWidth)
                    
                    return (finalSize, {
                        apply()
                        return fileNode
                    })
                })
            })
        }
    }
    
    func transitionNode(media: Media) -> (ASDisplayNode, () -> UIView?)? {
        if let iconNode = self.iconNode, let file = self.file, file.isEqual(to: media) {
            return (iconNode, { [weak iconNode] in
                return iconNode?.view.snapshotContentTree(unhide: true)
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
}
