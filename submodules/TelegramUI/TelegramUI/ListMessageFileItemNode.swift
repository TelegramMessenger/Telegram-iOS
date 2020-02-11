import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import TelegramStringFormatting
import AccountContext
import RadialStatusNode
import PhotoResources
import MusicAlbumArtResources
import UniversalMediaPlayer

private let extensionImageCache = Atomic<[UInt32: UIImage]>(value: [:])

private let redColors: (UInt32, UInt32) = (0xf0625d, 0xde524e)
private let greenColors: (UInt32, UInt32) = (0x72ce76, 0x54b658)
private let blueColors: (UInt32, UInt32) = (0x60b0e8, 0x4597d1)
private let yellowColors: (UInt32, UInt32) = (0xf5c565, 0xe5a64e)

private let extensionColorsMap: [String: (UInt32, UInt32)] = [
    "ppt": redColors,
    "pptx": redColors,
    "pdf": redColors,
    "key": redColors,
    
    "xls": greenColors,
    "xlsx": greenColors,
    "csv": greenColors,
    
    "zip": yellowColors,
    "rar": yellowColors,
    "gzip": yellowColors,
    "ai": yellowColors
]

private func generateExtensionImage(colors: (UInt32, UInt32)) -> UIImage? {
    return generateImage(CGSize(width: 42.0, height: 42.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: -size.width / 2.0 + 1.0, y: -size.height / 2.0 + 1.0)
        
        let radius: CGFloat = 2.0
        let cornerSize: CGFloat = 10.0
        let size = CGSize(width: 42.0, height: 42.0)
        
        context.setFillColor(UIColor(rgb: colors.0).cgColor)
        context.beginPath()
        context.move(to: CGPoint(x: 0.0, y: radius))
        if !radius.isZero {
            context.addArc(tangent1End: CGPoint(x: 0.0, y: 0.0), tangent2End: CGPoint(x: radius, y: 0.0), radius: radius)
        }
        context.addLine(to: CGPoint(x: size.width - cornerSize, y: 0.0))
        context.addLine(to: CGPoint(x: size.width - cornerSize + cornerSize / 4.0, y: cornerSize - cornerSize / 4.0))
        context.addLine(to: CGPoint(x: size.width, y: cornerSize))
        context.addLine(to: CGPoint(x: size.width, y: size.height - radius))
        if !radius.isZero {
            context.addArc(tangent1End: CGPoint(x: size.width, y: size.height), tangent2End: CGPoint(x: size.width - radius, y: size.height), radius: radius)
        }
        context.addLine(to: CGPoint(x: radius, y: size.height))
        
        if !radius.isZero {
            context.addArc(tangent1End: CGPoint(x: 0.0, y: size.height), tangent2End: CGPoint(x: 0.0, y: size.height - radius), radius: radius)
        }
        context.closePath()
        context.fillPath()
        
        context.setFillColor(UIColor(rgb: colors.1).cgColor)
        context.beginPath()
        context.move(to: CGPoint(x: size.width - cornerSize, y: 0.0))
        context.addLine(to: CGPoint(x: size.width, y: cornerSize))
        context.addLine(to: CGPoint(x: size.width - cornerSize + radius, y: cornerSize))
        
        if !radius.isZero {
            context.addArc(tangent1End: CGPoint(x: size.width - cornerSize, y: cornerSize), tangent2End: CGPoint(x: size.width - cornerSize, y: cornerSize - radius), radius: radius)
        }
        
        context.closePath()
        context.fillPath()
    })
}

private func extensionImage(fileExtension: String?) -> UIImage? {
    let colors: (UInt32, UInt32)
    if let fileExtension = fileExtension {
        if let extensionColors = extensionColorsMap[fileExtension] {
            colors = extensionColors
        } else {
            colors = blueColors
        }
    } else {
        colors = blueColors
    }
    
    if let cachedImage = (extensionImageCache.with { dict in
        return dict[colors.0]
    }) {
        return cachedImage
    } else if let image = generateExtensionImage(colors: colors) {
        let _ = extensionImageCache.modify { dict in
            var dict = dict
            dict[colors.0] = image
            return dict
        }
        return image
    } else {
        return nil
    }
}
private let extensionFont = Font.medium(13.0)

private struct FetchControls {
    let fetch: () -> Void
    let cancel: () -> Void
}

private enum FileIconImage: Equatable {
    case imageRepresentation(TelegramMediaFile, TelegramMediaImageRepresentation)
    case albumArt(TelegramMediaFile, SharedMediaPlaybackAlbumArt)
    case roundVideo(TelegramMediaFile)
    
    static func ==(lhs: FileIconImage, rhs: FileIconImage) -> Bool {
        switch lhs {
            case let .imageRepresentation(file, value):
                if case .imageRepresentation(file, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .albumArt(file, value):
                if case .albumArt(file, value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .roundVideo(file):
                if case .roundVideo(file) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

final class ListMessageFileItemNode: ListMessageNode {
    private let highlightedBackgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    
    private var selectionNode: ItemListSelectableControlNode?
    
    private let titleNode: TextNode
    private let descriptionNode: TextNode
    private let descriptionProgressNode: ImmediateTextNode
    
    private let extensionIconNode: ASImageNode
    private let extensionIconText: TextNode
    private let iconImageNode: TransformImageNode
    private let statusButtonNode: HighlightTrackingButtonNode
    private let statusNode: RadialStatusNode
    
    private var waveformNode: AudioWaveformNode?
    private var waveformForegroundNode: AudioWaveformNode?
    private var waveformScrubbingNode: MediaPlayerScrubbingNode?
    
    private var currentIconImage: FileIconImage?
    private var currentMedia: Media?
    
    private let statusDisposable = MetaDisposable()
    private let fetchControls = Atomic<FetchControls?>(value: nil)
    private var fetchStatus: MediaResourceStatus?
    private var resourceStatus: FileMediaResourceMediaStatus?
    private let fetchDisposable = MetaDisposable()
    private let playbackStatusDisposable = MetaDisposable()
    private let playbackStatus = Promise<MediaPlayerStatus>()
    
    private var downloadStatusIconNode: ASImageNode
    private var linearProgressNode: ASDisplayNode
    
    private let progressNode: RadialProgressNode
    private var playbackOverlayNode: ListMessagePlaybackOverlayNode?
    
    private var context: AccountContext?
    private (set) var message: Message?
    
    private var appliedItem: ListMessageItem?
    private var layoutParams: ListViewItemLayoutParams?
    private var contentSizeValue: CGSize?
    private var currentLeftOffset: CGFloat = 0.0
    
    override var canBeLongTapped: Bool {
        return true
    }
    
    public required init() {
        self.separatorNode = ASDisplayNode()
        self.separatorNode.displaysAsynchronously = false
        self.separatorNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        
        self.descriptionNode = TextNode()
        self.descriptionNode.isUserInteractionEnabled = false
        
        self.descriptionProgressNode = ImmediateTextNode()
        self.descriptionProgressNode.isUserInteractionEnabled = false
        self.descriptionProgressNode.maximumNumberOfLines = 1
        
        self.extensionIconNode = ASImageNode()
        self.extensionIconNode.isLayerBacked = true
        self.extensionIconNode.displaysAsynchronously = false
        self.extensionIconNode.displayWithoutProcessing = true
        
        self.extensionIconText = TextNode()
        self.extensionIconText.isUserInteractionEnabled = false
        
        self.iconImageNode = TransformImageNode()
        self.iconImageNode.displaysAsynchronously = false
        self.iconImageNode.contentAnimations = .subsequentUpdates
        
        self.statusButtonNode = HighlightTrackingButtonNode()
        self.statusNode = RadialStatusNode(backgroundNodeColor: .clear)
        self.statusNode.isUserInteractionEnabled = false
        
        self.downloadStatusIconNode = ASImageNode()
        self.downloadStatusIconNode.isLayerBacked = true
        self.downloadStatusIconNode.displaysAsynchronously = false
        self.downloadStatusIconNode.displayWithoutProcessing = true
        
        self.progressNode = RadialProgressNode(theme: RadialProgressTheme(backgroundColor: .black, foregroundColor: .white, icon: nil))
        //self.progressNode.isLayerBacked = true
        
        self.linearProgressNode = ASDisplayNode()
        self.linearProgressNode.isLayerBacked = true
        
        super.init()
        
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.progressNode)
        self.addSubnode(self.descriptionNode)
        self.addSubnode(self.descriptionProgressNode)
        self.addSubnode(self.extensionIconNode)
        self.addSubnode(self.extensionIconText)
        self.addSubnode(self.statusNode)
        self.addSubnode(self.statusButtonNode)
        
        self.statusButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.statusNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.statusNode.alpha = 0.4
                } else {
                    strongSelf.statusNode.alpha = 1.0
                    strongSelf.statusNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        self.statusButtonNode.addTarget(self, action: #selector(self.statusPressed), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.statusDisposable.dispose()
        self.fetchDisposable.dispose()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setupItem(_ item: ListMessageItem) {
        self.item = item
    }
    
    override public func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = item as? ListMessageItem {
            let doLayout = self.asyncLayout()
            let merged = (top: false, bottom: false, dateAtBottom: item.getDateAtBottom(top: previousItem, bottom: nextItem))
            let (layout, apply) = doLayout(item, params, merged.top, merged.bottom, merged.dateAtBottom)
            self.contentSize = layout.contentSize
            self.insets = layout.insets
            apply(.None)
        }
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        super.animateInsertion(currentTimestamp, duration: duration, short: short)
        
        self.transitionOffset = self.bounds.size.height * 1.6
        self.addTransitionOffsetAnimation(0.0, duration: duration, beginAt: currentTimestamp)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    override func asyncLayout() -> (_ item: ListMessageItem, _ params: ListViewItemLayoutParams, _ mergedTop: Bool, _ mergedBottom: Bool, _ dateHeaderAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let titleNodeMakeLayout = TextNode.asyncLayout(self.titleNode)
        let descriptionNodeMakeLayout = TextNode.asyncLayout(self.descriptionNode)
        let extensionIconTextMakeLayout = TextNode.asyncLayout(self.extensionIconText)
        let iconImageLayout = self.iconImageNode.asyncLayout()
        
        let currentMedia = self.currentMedia
        let currentMessage = self.message
        let currentIconImage = self.currentIconImage
        
        let currentItem = self.appliedItem
        
        let selectionNodeLayout = ItemListSelectableControlNode.asyncLayout(self.selectionNode)
        
        return { [weak self] item, params, _, _, dateHeaderAtBottom in
            var updatedTheme: PresentationTheme?
            
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
            }
            
            let titleFont = Font.medium(floor(item.fontSize.baseDisplaySize * 16.0 / 17.0))
            let audioTitleFont = Font.regular(floor(item.fontSize.baseDisplaySize * 16.0 / 17.0))
            let descriptionFont = Font.regular(floor(item.fontSize.baseDisplaySize * 13.0 / 17.0))
            
            var leftInset: CGFloat = 65.0 + params.leftInset
            let rightInset: CGFloat = 8.0 + params.rightInset
            
            var leftOffset: CGFloat = 0.0
            var selectionNodeWidthAndApply: (CGFloat, (CGSize, Bool) -> ItemListSelectableControlNode)?
            if case let .selectable(selected) = item.selection {
                let (selectionWidth, selectionApply) = selectionNodeLayout(item.theme.list.itemCheckColors.strokeColor, item.theme.list.itemCheckColors.fillColor, item.theme.list.itemCheckColors.foregroundColor, selected, false)
                selectionNodeWidthAndApply = (selectionWidth, selectionApply)
                leftOffset += selectionWidth
            }
            
            var extensionIconImage: UIImage?
            var titleText: NSAttributedString?
            var descriptionText: NSAttributedString?
            var extensionText: NSAttributedString?
            
            var iconImage: FileIconImage?
            var updateIconImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            var updatedStatusSignal: Signal<FileMediaResourceStatus, NoError>?
            var updatedPlaybackStatusSignal: Signal<MediaPlayerStatus, NoError>?
            var updatedFetchControls: FetchControls?
            var waveform: AudioWaveform?
            
            var isAudio = false
            var isVoice = false
            var isInstantVideo = false
            
            let message = item.message
            
            var selectedMedia: TelegramMediaFile?
            for media in message.media {
                if let file = media as? TelegramMediaFile {
                    selectedMedia = file
                    
                    isInstantVideo = file.isInstantVideo
                    
                    for attribute in file.attributes {
                        if case let .Audio(voice, _, title, performer, waveformValue) = attribute {
                            isAudio = true
                            isVoice = voice
                            
                            titleText = NSAttributedString(string: title ?? (file.fileName ?? "Unknown Track"), font: audioTitleFont, textColor: item.theme.list.itemPrimaryTextColor)
                            
                            let descriptionString: String
                            if let performer = performer {
                                descriptionString = performer
                            } else if let size = file.size {
                                descriptionString = dataSizeString(size, decimalSeparator: item.dateTimeFormat.decimalSeparator)
                            } else {
                                descriptionString = ""
                            }
                            
                            descriptionText = NSAttributedString(string: descriptionString, font: descriptionFont, textColor: item.theme.list.itemSecondaryTextColor)
                            
                            if !voice {
                                iconImage = .albumArt(file, SharedMediaPlaybackAlbumArt(thumbnailResource: ExternalMusicAlbumArtResource(title: title ?? "", performer: performer ?? "", isThumbnail: true), fullSizeResource: ExternalMusicAlbumArtResource(title: title ?? "", performer: performer ?? "", isThumbnail: false)))
                            } else {
                                titleText = NSAttributedString(string: " ", font: audioTitleFont, textColor: item.theme.list.itemPrimaryTextColor)
                                descriptionText = NSAttributedString(string: item.message.author?.displayTitle(strings: item.strings, displayOrder: .firstLast) ?? " ", font: descriptionFont, textColor: item.theme.list.itemSecondaryTextColor)
                                waveformValue?.withDataNoCopy { data in
                                    waveform = AudioWaveform(bitstream: data, bitsPerSample: 5)
                                }
                            }
                        }
                    }
                    
                    if isInstantVideo {
                        titleText = NSAttributedString(string: item.strings.Message_VideoMessage, font: audioTitleFont, textColor: item.theme.list.itemPrimaryTextColor)
                        descriptionText = NSAttributedString(string: item.message.author?.displayTitle(strings: item.strings, displayOrder: .firstLast) ?? " ", font: descriptionFont, textColor: item.theme.list.itemSecondaryTextColor)
                        iconImage = .roundVideo(file)
                    } else if !isAudio {
                        let fileName: String = file.fileName ?? ""
                        titleText = NSAttributedString(string: fileName, font: titleFont, textColor: item.theme.list.itemPrimaryTextColor)
                        
                        var fileExtension: String?
                        if let range = fileName.range(of: ".", options: [.backwards]) {
                            fileExtension = fileName[range.upperBound...].lowercased()
                        }
                        extensionIconImage = extensionImage(fileExtension: fileExtension)
                        if let fileExtension = fileExtension {
                            extensionText = NSAttributedString(string: fileExtension, font: extensionFont, textColor: UIColor.white)
                        }
                        
                        if let representation = smallestImageRepresentation(file.previewRepresentations) {
                            iconImage = .imageRepresentation(file, representation)
                        }
                        
                        let dateString = stringForFullDate(timestamp: item.message.timestamp, strings: item.strings, dateTimeFormat: item.dateTimeFormat)
                        
                        let descriptionString: String
                        if let size = file.size {
                            descriptionString = "\(dataSizeString(size, decimalSeparator: item.dateTimeFormat.decimalSeparator)) • \(dateString)"
                        } else {
                            descriptionString = "\(dateString)"
                        }
                    
                        descriptionText = NSAttributedString(string: descriptionString, font: descriptionFont, textColor: item.theme.list.itemSecondaryTextColor)
                    }
                    
                    break
                }
            }
            
            if isAudio && !isVoice {
                leftInset += 14.0
            }
            
            var mediaUpdated = false
            if let currentMedia = currentMedia {
                if let selectedMedia = selectedMedia {
                    mediaUpdated = !selectedMedia.isEqual(to: currentMedia)
                } else {
                    mediaUpdated = true
                }
            } else {
                mediaUpdated = selectedMedia != nil
            }
            
            var statusUpdated = mediaUpdated
            if currentMessage?.id != message.id || currentMessage?.flags != message.flags {
                statusUpdated = true
            }
            
            if let selectedMedia = selectedMedia {
                if mediaUpdated {
                    let context = item.context
                    updatedFetchControls = FetchControls(fetch: { [weak self] in
                        if let strongSelf = self {
                            strongSelf.fetchDisposable.set(messageMediaFileInteractiveFetched(context: context, message: message, file: selectedMedia, userInitiated: true).start())
                        }
                    }, cancel: {
                        messageMediaFileCancelInteractiveFetch(context: context, messageId: message.id, file: selectedMedia)
                    })
                }
                
                if statusUpdated {
                    updatedStatusSignal = messageFileMediaResourceStatus(context: item.context, file: selectedMedia, message: message, isRecentActions: false, isSharedMedia: true)
                    
                    if isAudio || isInstantVideo {
                        if let currentUpdatedStatusSignal = updatedStatusSignal {
                            updatedStatusSignal = currentUpdatedStatusSignal
                            |> map { status in
                                switch status.mediaStatus {
                                    case .fetchStatus:
                                        return FileMediaResourceStatus(mediaStatus: .fetchStatus(.Local), fetchStatus: status.fetchStatus)
                                    case .playbackStatus:
                                        return status
                                }
                            }
                        }
                    }
                    if isVoice {
                        updatedPlaybackStatusSignal = messageFileMediaPlaybackStatus(context: item.context, file: selectedMedia, message: message, isRecentActions: false)
                    }
                }
            }
            
            let (titleNodeLayout, titleNodeApply) = titleNodeMakeLayout(TextNodeLayoutArguments(attributedString: titleText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .middle, constrainedSize: CGSize(width: params.width - leftInset - rightInset - 40.0, height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (descriptionNodeLayout, descriptionNodeApply) = descriptionNodeMakeLayout(TextNodeLayoutArguments(attributedString: descriptionText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset - 12.0 - 40.0, height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (extensionTextLayout, extensionTextApply) = extensionIconTextMakeLayout(TextNodeLayoutArguments(attributedString: extensionText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 38.0, height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var iconImageApply: (() -> Void)?
            if let iconImage = iconImage {
                switch iconImage {
                    case let .imageRepresentation(_, representation):
                        let iconSize = CGSize(width: 42.0, height: 42.0)
                        let imageCorners = ImageCorners(topLeft: .Corner(4.0), topRight: .Corner(4.0), bottomLeft: .Corner(4.0), bottomRight: .Corner(4.0))
                        let arguments = TransformImageArguments(corners: imageCorners, imageSize: representation.dimensions.cgSize.aspectFilled(iconSize), boundingSize: iconSize, intrinsicInsets: UIEdgeInsets(), emptyColor: item.theme.list.mediaPlaceholderColor)
                        iconImageApply = iconImageLayout(arguments)
                    case .albumArt:
                        let iconSize = CGSize(width: 46.0, height: 46.0)
                        let imageCorners = ImageCorners(topLeft: .Corner(4.0), topRight: .Corner(4.0), bottomLeft: .Corner(4.0), bottomRight: .Corner(4.0))
                        let arguments = TransformImageArguments(corners: imageCorners, imageSize: iconSize, boundingSize: iconSize, intrinsicInsets: UIEdgeInsets(), emptyColor: item.theme.list.mediaPlaceholderColor)
                        iconImageApply = iconImageLayout(arguments)
                    case let .roundVideo(file):
                        let iconSize = CGSize(width: 42.0, height: 42.0)
                        let imageCorners = ImageCorners(topLeft: .Corner(iconSize.width / 2.0), topRight: .Corner(iconSize.width / 2.0), bottomLeft: .Corner(iconSize.width / 2.0), bottomRight: .Corner(iconSize.width / 2.0))
                        let arguments = TransformImageArguments(corners: imageCorners, imageSize: (file.dimensions ?? PixelDimensions(width: 320, height: 320)).cgSize.aspectFilled(iconSize), boundingSize: iconSize, intrinsicInsets: UIEdgeInsets(), emptyColor: item.theme.list.mediaPlaceholderColor)
                        iconImageApply = iconImageLayout(arguments)
                }
            }
            
            if currentIconImage != iconImage {
                if let iconImage = iconImage {
                    switch iconImage {
                        case let .imageRepresentation(file, representation):
                            updateIconImageSignal = chatWebpageSnippetFile(account: item.context.account, fileReference: .message(message: MessageReference(message), media: file), representation: representation)
                        case let .albumArt(file, albumArt):
                            updateIconImageSignal = playerAlbumArt(postbox: item.context.account.postbox, fileReference: .message(message: MessageReference(message), media: file), albumArt: albumArt, thumbnail: true)
                        case let .roundVideo(file):
                            updateIconImageSignal = mediaGridMessageVideo(postbox: item.context.account.postbox, videoReference: FileMediaReference.message(message: MessageReference(message), media: file), autoFetchFullSizeThumbnail: true)
                    }
                } else {
                    updateIconImageSignal = .complete()
                }
            }
            
            var insets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
            if dateHeaderAtBottom, let header = item.header {
                insets.top += header.height
            }
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: 8.0 * 2.0 + titleNodeLayout.size.height + 3.0 + descriptionNodeLayout.size.height), insets: insets)
            
            return (nodeLayout, { animation in
                if let strongSelf = self {
                    let transition: ContainedViewLayoutTransition
                    if animation.isAnimated {
                        transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                    } else {
                        transition = .immediate
                    }
                    
                    strongSelf.currentMedia = selectedMedia
                    strongSelf.message = message
                    strongSelf.context = item.context
                    strongSelf.appliedItem = item
                    strongSelf.layoutParams = params
                    strongSelf.contentSizeValue = nodeLayout.contentSize
                    strongSelf.currentLeftOffset = leftOffset
                    
                    if let _ = updatedTheme {
                        strongSelf.separatorNode.backgroundColor = item.theme.list.itemPlainSeparatorColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.theme.list.itemHighlightedBackgroundColor
                        
                        strongSelf.progressNode.updateTheme(RadialProgressTheme(backgroundColor: item.theme.list.itemAccentColor, foregroundColor: item.theme.list.plainBackgroundColor, icon: nil))
                        strongSelf.linearProgressNode.backgroundColor = item.theme.list.itemAccentColor
                    }
                    
                    if let (selectionWidth, selectionApply) = selectionNodeWidthAndApply {
                        let selectionFrame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: selectionWidth, height: nodeLayout.contentSize.height))
                        let selectionNode = selectionApply(selectionFrame.size, transition.isAnimated)
                        if selectionNode !== strongSelf.selectionNode {
                            strongSelf.selectionNode?.removeFromSupernode()
                            strongSelf.selectionNode = selectionNode
                            strongSelf.addSubnode(selectionNode)
                            selectionNode.frame = selectionFrame
                            transition.animatePosition(node: selectionNode, from: CGPoint(x: -selectionFrame.size.width / 2.0, y: selectionFrame.midY))
                        } else {
                            transition.updateFrame(node: selectionNode, frame: selectionFrame)
                        }
                    } else if let selectionNode = strongSelf.selectionNode {
                        strongSelf.selectionNode = nil
                        let selectionFrame = selectionNode.frame
                        transition.updatePosition(node: selectionNode, position: CGPoint(x: -selectionFrame.size.width / 2.0, y: selectionFrame.midY), completion: { [weak selectionNode] _ in
                            selectionNode?.removeFromSupernode()
                        })
                    }
                    
                    transition.updateFrame(node: strongSelf.separatorNode, frame: CGRect(origin: CGPoint(x: leftInset + leftOffset, y: nodeLayout.contentSize.height - UIScreenPixel), size: CGSize(width: params.width - leftInset - leftOffset, height: UIScreenPixel)))
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel - nodeLayout.insets.top), size: CGSize(width: params.width, height: nodeLayout.size.height + UIScreenPixel))
                    
                    transition.updateFrame(node: strongSelf.titleNode, frame: CGRect(origin: CGPoint(x: leftOffset + leftInset, y: 8.0), size: titleNodeLayout.size))
                    let _ = titleNodeApply()
                    
                    var descriptionOffset: CGFloat = 0.0
                    if let resourceStatus = strongSelf.resourceStatus {
                        switch resourceStatus {
                            case .playbackStatus:
                                break
                            case let .fetchStatus(fetchStatus):
                                switch fetchStatus {
                                    case .Remote, .Fetching:
                                        descriptionOffset = 14.0
                                    case .Local:
                                        break
                                }
                        }
                    }
                    
                    transition.updateFrame(node: strongSelf.descriptionNode, frame: CGRect(origin: CGPoint(x: leftOffset + leftInset + descriptionOffset, y: strongSelf.titleNode.frame.maxY + 3.0), size: descriptionNodeLayout.size))
                    let _ = descriptionNodeApply()
                    
                    let iconFrame: CGRect
                    if isAudio {
                        let iconSize = CGSize(width: 48.0, height: 48.0)
                        iconFrame = CGRect(origin: CGPoint(x: params.leftInset + leftOffset + 12.0, y: 5.0), size: iconSize)
                    } else {
                        let iconSize = CGSize(width: 42.0, height: 42.0)
                        iconFrame = CGRect(origin: CGPoint(x: params.leftInset + leftOffset + 12.0, y: 8.0), size: iconSize)
                    }
                    transition.updateFrame(node: strongSelf.extensionIconNode, frame: iconFrame)
                    strongSelf.extensionIconNode.image = extensionIconImage
                    transition.updateFrame(node: strongSelf.extensionIconText, frame: CGRect(origin: CGPoint(x: leftOffset + 12.0 + floor((42.0 - extensionTextLayout.size.width) / 2.0), y: 8.0 + floor((42.0 - extensionTextLayout.size.height) / 2.0)), size: extensionTextLayout.size))
                    
                    let _ = extensionTextApply()
                    
                    strongSelf.currentIconImage = iconImage
                    
                    if isVoice {
                        let waveformNode: AudioWaveformNode
                        let waveformForegroundNode: AudioWaveformNode
                        let waveformScrubbingNode: MediaPlayerScrubbingNode
                        if let current = strongSelf.waveformNode {
                            waveformNode = current
                        } else {
                            waveformNode = AudioWaveformNode()
                            waveformNode.isLayerBacked = true
                            strongSelf.waveformNode = waveformNode
                            strongSelf.addSubnode(waveformNode)
                        }
                        if let current = strongSelf.waveformForegroundNode {
                            waveformForegroundNode = current
                        } else {
                            waveformForegroundNode = AudioWaveformNode()
                            waveformForegroundNode.isLayerBacked = true
                            strongSelf.waveformForegroundNode = waveformForegroundNode
                            strongSelf.addSubnode(waveformForegroundNode)
                        }
                        if let current = strongSelf.waveformScrubbingNode {
                            waveformScrubbingNode = current
                        } else {
                            waveformScrubbingNode = MediaPlayerScrubbingNode(content: .custom(backgroundNode: waveformNode, foregroundContentNode: waveformForegroundNode))
                            waveformScrubbingNode.hitTestSlop = UIEdgeInsets(top: -10.0, left: 0.0, bottom: -10.0, right: 0.0)
                            waveformScrubbingNode.seek = { timestamp in
                                if let strongSelf = self, let context = strongSelf.context, let message = strongSelf.message, let type = peerMessageMediaPlayerType(message) {
                                    context.sharedContext.mediaManager.playlistControl(.seek(timestamp), type: type)
                                }
                            }
                            waveformScrubbingNode.enableScrubbing = false
                            waveformScrubbingNode.status = strongSelf.playbackStatus.get()
                            strongSelf.waveformScrubbingNode = waveformScrubbingNode
                            strongSelf.addSubnode(waveformScrubbingNode)
                        }
                        
                        transition.updateFrame(node: waveformScrubbingNode, frame: CGRect(origin: CGPoint(x: leftOffset + leftInset, y: 10.0), size: CGSize(width: params.width - leftInset - 16.0, height: 12.0)))
                        
                        waveformNode.setup(color: item.theme.list.controlSecondaryColor, waveform: waveform)
                        waveformForegroundNode.setup(color: item.theme.list.itemAccentColor, waveform: waveform)
                    }
                    
                    if let iconImageApply = iconImageApply {
                        if let updateImageSignal = updateIconImageSignal {
                            strongSelf.iconImageNode.setSignal(updateImageSignal)
                        }
                        
                        transition.updateFrame(node: strongSelf.iconImageNode, frame: iconFrame)
                        if strongSelf.iconImageNode.supernode == nil {
                            strongSelf.addSubnode(strongSelf.iconImageNode)
                        }
                        
                        iconImageApply()
                        
                        if strongSelf.extensionIconNode.supernode != nil {
                            strongSelf.extensionIconNode.removeFromSupernode()
                        }
                        if strongSelf.extensionIconText.supernode != nil {
                            strongSelf.extensionIconText.removeFromSupernode()
                        }
                    } else if strongSelf.iconImageNode.supernode != nil {
                        strongSelf.iconImageNode.removeFromSupernode()
                        
                        if strongSelf.extensionIconNode.supernode == nil {
                            strongSelf.addSubnode(strongSelf.extensionIconNode)
                        }
                        if strongSelf.extensionIconText.supernode == nil {
                            strongSelf.addSubnode(strongSelf.extensionIconText)
                        }
                    }
                    
                    if let playbackOverlayNode = strongSelf.playbackOverlayNode {
                        transition.updateFrame(node: playbackOverlayNode, frame: iconFrame)
                    }
                    
                    let statusSize = CGSize(width: 28.0, height: 28.0)
                    transition.updateFrame(node: strongSelf.statusNode, frame: CGRect(origin: CGPoint(x: params.width - params.rightInset - rightInset - statusSize.width + leftOffset, y: floor((nodeLayout.contentSize.height - statusSize.height) / 2.0)), size: statusSize))
                    
                    strongSelf.statusButtonNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - rightInset - 40.0 + leftOffset, y: 0.0), size: CGSize(width: 40.0, height: nodeLayout.contentSize.height))
                    
                    if let updatedStatusSignal = updatedStatusSignal {
                        strongSelf.statusDisposable.set((updatedStatusSignal
                        |> deliverOnMainQueue).start(next: { [weak strongSelf] fileStatus in
                            if let strongSelf = strongSelf {
                                strongSelf.fetchStatus = fileStatus.fetchStatus
                                strongSelf.resourceStatus = fileStatus.mediaStatus
                                strongSelf.updateStatus(transition: .immediate)
                            }
                        }))
                    }
                    
                    transition.updateFrame(node: strongSelf.downloadStatusIconNode, frame: CGRect(origin: CGPoint(x: leftOffset + leftInset, y: strongSelf.descriptionNode.frame.minY + floor((strongSelf.descriptionNode.frame.height - 11.0) / 2.0)), size: CGSize(width: 11.0, height: 11.0)))
                    
                    let progressSize: CGFloat = 40.0
                    transition.updateFrame(node: strongSelf.progressNode, frame: CGRect(origin: CGPoint(x: leftOffset + params.leftInset + floor((leftInset - params.leftInset - progressSize) / 2.0), y: floor((nodeLayout.contentSize.height - progressSize) / 2.0)), size: CGSize(width: progressSize, height: progressSize)))
                    
                    if let updatedFetchControls = updatedFetchControls {
                        let _ = strongSelf.fetchControls.swap(updatedFetchControls)
                    }
                    
                    if let updatedPlaybackStatusSignal = updatedPlaybackStatusSignal {
                        strongSelf.playbackStatus.set(updatedPlaybackStatusSignal)
                        /*strongSelf.playbackStatusDisposable.set((updatedPlaybackStatusSignal |> deliverOnMainQueue).start(next: { [weak strongSelf] status in
                            displayLinkDispatcher.dispatch {
                                if let strongSelf = strongSelf {
                                    strongSelf.playerStatus = status
                                }
                            }
                        }))*/
                    }
                    
                    strongSelf.updateStatus(transition: transition)
                }
            })
        }
    }
    
    private func updateStatus(transition: ContainedViewLayoutTransition) {
        guard let item = self.item, let media = self.currentMedia, let fetchStatus = self.fetchStatus, let status = self.resourceStatus, let layoutParams = self.layoutParams, let contentSize = self.contentSizeValue else {
            return
        }
        
        var isAudio = false
        var isVoice = false
        var isInstantVideo = false
        if let file = media as? TelegramMediaFile {
            isAudio = file.isMusic || file.isVoice
            isVoice = file.isVoice
            isInstantVideo = file.isInstantVideo
        }
        
        self.progressNode.isHidden = !isVoice
        
        var enableScrubbing = false
        var musicIsPlaying: Bool?
        var statusState: RadialStatusNodeState = .none
        if !isAudio && !isInstantVideo {
            self.updateProgressFrame(size: contentSize, leftInset: layoutParams.leftInset, rightInset: layoutParams.rightInset, transition: .immediate)
        } else {
            if !isVoice && !isInstantVideo {
                switch fetchStatus {
                    case let .Fetching(_, progress):
                        let adjustedProgress = max(progress, 0.027)
                        statusState = .cloudProgress(color: item.theme.list.itemAccentColor, strokeBackgroundColor: item.theme.list.itemAccentColor.withAlphaComponent(0.5), lineWidth: 2.0, value: CGFloat(adjustedProgress))
                    case .Local:
                        break
                    case .Remote:
                        if let image = PresentationResourcesItemList.cloudFetchIcon(item.theme) {
                            statusState = .customIcon(image)
                        }
                }
            }
            self.statusNode.transitionToState(statusState, completion: {})
            self.statusButtonNode.isUserInteractionEnabled = statusState != .none
            
            switch status {
                case let .fetchStatus(fetchStatus):
                    switch fetchStatus {
                        case let .Fetching(_, progress):
                            let adjustedProgress = max(progress, 0.027)
                            self.progressNode.state = .Fetching(progress: adjustedProgress)
                        case .Local:
                            if isAudio {
                                self.progressNode.state = .Play
                            } else {
                                self.progressNode.state = .Icon
                            }
                        case .Remote:
                            if isAudio {
                                self.progressNode.state = .Play
                            } else {
                                self.progressNode.state = .Remote
                            }
                    }
                case let .playbackStatus(playbackStatus):
                    enableScrubbing = true
                    switch playbackStatus {
                        case .playing:
                            musicIsPlaying = true
                            self.progressNode.state = .Pause
                        case .paused:
                            musicIsPlaying = false
                            self.progressNode.state = .Play
                    }
            }
        }
        self.waveformScrubbingNode?.enableScrubbing = enableScrubbing
        if let musicIsPlaying = musicIsPlaying, !isVoice, !isInstantVideo {
            if self.playbackOverlayNode == nil {
                let playbackOverlayNode = ListMessagePlaybackOverlayNode()
                playbackOverlayNode.frame = self.iconImageNode.frame
                self.playbackOverlayNode = playbackOverlayNode
                self.addSubnode(playbackOverlayNode)
            }
            self.playbackOverlayNode?.isPlaying = musicIsPlaying
        } else if let playbackOverlayNode = self.playbackOverlayNode {
            self.playbackOverlayNode = nil
            playbackOverlayNode.removeFromSupernode()
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        if highlighted, let item = self.item, case .none = item.selection {
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: self.separatorNode)
            }
        } else {
            if self.highlightedBackgroundNode.supernode != nil {
                if animated {
                    self.highlightedBackgroundNode.layer.animateAlpha(from: self.highlightedBackgroundNode.alpha, to: 0.0, duration: 0.4, completion: { [weak self] completed in
                        if let strongSelf = self {
                            if completed {
                                strongSelf.highlightedBackgroundNode.removeFromSupernode()
                            }
                        }
                    })
                    self.highlightedBackgroundNode.alpha = 0.0
                } else {
                    self.highlightedBackgroundNode.removeFromSupernode()
                }
            }
        }
    }
    
    override func transitionNode(id: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        if let item = self.item, item.message.id == id, self.iconImageNode.supernode != nil {
            let iconImageNode = self.iconImageNode
            return (self.iconImageNode, self.iconImageNode.bounds, { [weak iconImageNode] in
                return (iconImageNode?.view.snapshotContentTree(unhide: true), nil)
            })
        }
        return nil
    }
    
    override func updateHiddenMedia() {
        if let controllerInteraction = self.controllerInteraction, let item = self.item, controllerInteraction.hiddenMedia[item.message.id] != nil {
            self.iconImageNode.isHidden = true
        } else {
            self.iconImageNode.isHidden = false
        }
    }
    
    override func updateSelectionState(animated: Bool) {
    }
    
    private func updateProgressFrame(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        guard let item = self.appliedItem else {
            return
        }
        var descriptionOffset: CGFloat = 0.0
        
        var downloadingString: String?
        if let resourceStatus = self.resourceStatus {
            var maybeFetchStatus: MediaResourceStatus = .Local
            switch resourceStatus {
                case .playbackStatus:
                    break
                case let .fetchStatus(fetchStatus):
                    maybeFetchStatus = fetchStatus
                    switch fetchStatus {
                        case let .Fetching(_, progress):
                            if let file = self.currentMedia as? TelegramMediaFile, let size = file.size {
                                downloadingString = "\(dataSizeString(Int(Float(size) * progress), forceDecimal: true, decimalSeparator: item.dateTimeFormat.decimalSeparator)) / \(dataSizeString(size, forceDecimal: true, decimalSeparator: item.dateTimeFormat.decimalSeparator))"
                            }
                            descriptionOffset = 14.0
                        case .Remote:
                            descriptionOffset = 14.0
                        case .Local:
                            break
                    }
            }
            
            switch maybeFetchStatus {
                case let .Fetching(_, progress):
                    let progressFrame = CGRect(x: self.currentLeftOffset + leftInset + 65.0, y: size.height - 2.0, width: floor((size.width - 65.0 - leftInset - rightInset) * CGFloat(progress)), height: 2.0)
                    if self.linearProgressNode.supernode == nil {
                        self.addSubnode(self.linearProgressNode)
                    }
                    transition.updateFrame(node: self.linearProgressNode, frame: progressFrame)
                    if self.downloadStatusIconNode.supernode == nil {
                        self.addSubnode(self.downloadStatusIconNode)
                    }
                    self.downloadStatusIconNode.image = PresentationResourcesChat.sharedMediaFileDownloadPauseIcon(item.theme)
                case .Local:
                    if self.linearProgressNode.supernode != nil {
                        self.linearProgressNode.removeFromSupernode()
                    }
                    if self.downloadStatusIconNode.supernode != nil {
                        self.downloadStatusIconNode.removeFromSupernode()
                    }
                    self.downloadStatusIconNode.image = nil
                case .Remote:
                    if self.linearProgressNode.supernode != nil {
                        self.linearProgressNode.removeFromSupernode()
                    }
                    if self.downloadStatusIconNode.supernode == nil {
                        self.addSubnode(self.downloadStatusIconNode)
                    }
                    self.downloadStatusIconNode.image = PresentationResourcesChat.sharedMediaFileDownloadStartIcon(item.theme)
                }
        } else {
            if self.linearProgressNode.supernode != nil {
                self.linearProgressNode.removeFromSupernode()
            }
            if self.downloadStatusIconNode.supernode != nil {
                self.downloadStatusIconNode.removeFromSupernode()
            }
        }
        
        var descriptionFrame = self.descriptionNode.frame
        let originX = self.titleNode.frame.minX + descriptionOffset
        if !descriptionFrame.origin.x.isEqual(to: originX) {
            descriptionFrame.origin.x = originX
            transition.updateFrame(node: self.descriptionNode, frame: descriptionFrame)
        }
        
        if downloadingString != nil {
            self.descriptionProgressNode.isHidden = false
            self.descriptionNode.isHidden = true
        } else {
            self.descriptionProgressNode.isHidden = true
            self.descriptionNode.isHidden = false
        }
        let descriptionFont = Font.regular(floor(item.fontSize.baseDisplaySize * 13.0 / 17.0))
        self.descriptionProgressNode.attributedText = NSAttributedString(string: downloadingString ?? "", font: descriptionFont, textColor: item.theme.list.itemSecondaryTextColor)
        let descriptionSize = self.descriptionProgressNode.updateLayout(CGSize(width: size.width - 14.0, height: size.height))
        transition.updateFrame(node: self.descriptionProgressNode, frame: CGRect(origin: self.descriptionNode.frame.origin, size: descriptionSize))
        
    }
    
    func activateMedia() {
        self.progressPressed()
    }
    
    func progressPressed() {
        if let resourceStatus = self.resourceStatus {
            switch resourceStatus {
                case let .fetchStatus(fetchStatus):
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
                            if let item = self.item, let controllerInteraction = self.controllerInteraction {
                                let _ = controllerInteraction.openMessage(item.message, .default)
                            }
                        }
                case .playbackStatus:
                    if let context = self.context {
                        context.sharedContext.mediaManager.playlistControl(.playback(.togglePlayPause), type: nil)
                    }
            }
        }
    }
    
    override func header() -> ListViewItemHeader? {
        return self.item?.header
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let item = self.item, case .selectable = item.selection {
            if self.bounds.contains(point) {
                return self.view
            }
        }
        return super.hitTest(point, with: event)
    }
    
    override func longTapped() {
        if let item = self.item {
            item.controllerInteraction.openMessageContextMenu(item.message, false, self, self.bounds, nil)
        }
    }
    
    @objc private func statusPressed() {
        guard let _ = self.item, let fetchStatus = self.fetchStatus else {
            return
        }
        
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
                break
        }
    }
}
