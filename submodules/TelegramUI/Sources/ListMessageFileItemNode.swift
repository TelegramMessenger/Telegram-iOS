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
import SemanticStatusNode
import PhotoResources
import MusicAlbumArtResources
import UniversalMediaPlayer
import ContextUI

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
    return generateImage(CGSize(width: 40.0, height: 40.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(UIColor(rgb: colors.0).cgColor)
        let _ = try? drawSvgPath(context, path: "M6,0 L26.7573593,0 C27.5530088,-8.52837125e-16 28.3160705,0.316070521 28.8786797,0.878679656 L39.1213203,11.1213203 C39.6839295,11.6839295 40,12.4469912 40,13.2426407 L40,34 C40,37.3137085 37.3137085,40 34,40 L6,40 C2.6862915,40 4.05812251e-16,37.3137085 0,34 L0,6 C-4.05812251e-16,2.6862915 2.6862915,6.08718376e-16 6,0 Z ")
        
        context.beginPath()
        let _ = try? drawSvgPath(context, path: "M6,0 L26.7573593,0 C27.5530088,-8.52837125e-16 28.3160705,0.316070521 28.8786797,0.878679656 L39.1213203,11.1213203 C39.6839295,11.6839295 40,12.4469912 40,13.2426407 L40,34 C40,37.3137085 37.3137085,40 34,40 L6,40 C2.6862915,40 4.05812251e-16,37.3137085 0,34 L0,6 C-4.05812251e-16,2.6862915 2.6862915,6.08718376e-16 6,0 ")
        context.clip()
        
        context.setFillColor(UIColor(rgb: colors.0).withMultipliedBrightnessBy(0.85).cgColor)
        context.translateBy(x: 40.0 - 14.0, y: 0.0)
        let _ = try? drawSvgPath(context, path: "M-1,0 L14,0 L14,15 L14,14 C14,12.8954305 13.1045695,12 12,12 L4,12 C2.8954305,12 2,11.1045695 2,10 L2,2 C2,0.8954305 1.1045695,-2.02906125e-16 0,0 L-1,0 L-1,0 Z ")
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
private let extensionFont = Font.with(size: 15.0, design: .round, traits: [.bold])

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
    private let contextSourceNode: ContextExtractedContentContainingNode
    private let containerNode: ContextControllerSourceNode
    private let extractedBackgroundImageNode: ASImageNode
    
    private var extractedRect: CGRect?
    private var nonExtractedRect: CGRect?
    
    private let offsetContainerNode: ASDisplayNode
    
    private let highlightedBackgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    
    private var selectionNode: ItemListSelectableControlNode?
    
    private let titleNode: TextNode
    private let descriptionNode: TextNode
    private let descriptionProgressNode: ImmediateTextNode
    
    private let extensionIconNode: ASImageNode
    private let extensionIconText: TextNode
    private let iconImageNode: TransformImageNode
    private let iconStatusNode: SemanticStatusNode
    
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
    private var linearProgressNode: LinearProgressNode?
    
    private var context: AccountContext?
    private (set) var message: Message?
    
    private var appliedItem: ListMessageItem?
    private var layoutParams: ListViewItemLayoutParams?
    private var contentSizeValue: CGSize?
    private var currentLeftOffset: CGFloat = 0.0
    
    public required init() {
        self.contextSourceNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.displaysAsynchronously = false
        self.separatorNode.isLayerBacked = true
        
        self.extractedBackgroundImageNode = ASImageNode()
        self.extractedBackgroundImageNode.displaysAsynchronously = false
        self.extractedBackgroundImageNode.alpha = 0.0
        
        self.offsetContainerNode = ASDisplayNode()
        
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
        
        self.iconStatusNode = SemanticStatusNode(backgroundNodeColor: .clear, foregroundNodeColor: .white)
        self.iconStatusNode.isUserInteractionEnabled = false
        
        self.downloadStatusIconNode = ASImageNode()
        self.downloadStatusIconNode.isLayerBacked = true
        self.downloadStatusIconNode.displaysAsynchronously = false
        self.downloadStatusIconNode.displayWithoutProcessing = true
        
        super.init()
        
        self.addSubnode(self.separatorNode)
        
        self.containerNode.addSubnode(self.contextSourceNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        self.addSubnode(self.containerNode)
        
        self.contextSourceNode.contentNode.addSubnode(self.extractedBackgroundImageNode)
        self.contextSourceNode.contentNode.addSubnode(self.offsetContainerNode)
        self.offsetContainerNode.addSubnode(self.titleNode)
        self.offsetContainerNode.addSubnode(self.descriptionNode)
        self.offsetContainerNode.addSubnode(self.descriptionProgressNode)
        self.offsetContainerNode.addSubnode(self.extensionIconNode)
        self.offsetContainerNode.addSubnode(self.extensionIconText)
        self.offsetContainerNode.addSubnode(self.iconStatusNode)
        
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let item = strongSelf.item else {
                return
            }
            
            item.controllerInteraction.openMessageContextMenu(item.message, false, strongSelf.contextSourceNode, strongSelf.contextSourceNode.bounds, gesture)
        }
        
        self.contextSourceNode.willUpdateIsExtractedToContextPreview = { [weak self] isExtracted, transition in
            guard let strongSelf = self, let item = strongSelf.item else {
                return
            }
            
            if isExtracted {
                strongSelf.extractedBackgroundImageNode.image = generateStretchableFilledCircleImage(diameter: 28.0, color: item.theme.list.plainBackgroundColor)
            }
            
            if let extractedRect = strongSelf.extractedRect, let nonExtractedRect = strongSelf.nonExtractedRect {
                let rect = isExtracted ? extractedRect : nonExtractedRect
                transition.updateFrame(node: strongSelf.extractedBackgroundImageNode, frame: rect)
            }
            
            transition.updateSublayerTransformOffset(layer: strongSelf.offsetContainerNode.layer, offset: CGPoint(x: isExtracted ? 12.0 : 0.0, y: 0.0))
            transition.updateAlpha(node: strongSelf.extractedBackgroundImageNode, alpha: isExtracted ? 1.0 : 0.0, completion: { _ in
                if !isExtracted {
                    self?.extractedBackgroundImageNode.image = nil
                }
            })
        }
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
            
            let titleFont = Font.semibold(floor(item.fontSize.baseDisplaySize * 16.0 / 17.0))
            let audioTitleFont = Font.semibold(floor(item.fontSize.baseDisplaySize * 16.0 / 17.0))
            let descriptionFont = Font.regular(floor(item.fontSize.baseDisplaySize * 14.0 / 17.0))
            
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
                        if case let .Audio(voice, duration, title, performer, _) = attribute {
                            isAudio = true
                            isVoice = voice
                            
                            titleText = NSAttributedString(string: title ?? (file.fileName ?? "Unknown Track"), font: audioTitleFont, textColor: item.theme.list.itemPrimaryTextColor)
                            
                            let descriptionString: String
                            if let performer = performer {
                                descriptionString = "\(stringForDuration(Int32(duration))) • \(performer)"
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
                            }
                        }
                    }
                    
                    if isInstantVideo || isVoice {
                        let authorName: String
                        if let author = message.forwardInfo?.author {
                            if author.id == item.context.account.peerId {
                                authorName = item.strings.DialogList_You
                            } else {
                                authorName = author.displayTitle(strings: item.strings, displayOrder: .firstLast)
                            }
                        } else if let signature = message.forwardInfo?.authorSignature {
                            authorName = signature
                        } else if let author = message.author {
                            if author.id == item.context.account.peerId {
                                authorName = item.strings.DialogList_You
                            } else {
                                authorName = author.displayTitle(strings: item.strings, displayOrder: .firstLast)
                            }
                        } else {
                            authorName = " "
                        }
                        titleText = NSAttributedString(string: authorName, font: audioTitleFont, textColor: item.theme.list.itemPrimaryTextColor)
                        let dateString = stringForFullDate(timestamp: item.message.timestamp, strings: item.strings, dateTimeFormat: item.dateTimeFormat)
                        let descriptionString: String
                        if let duration = file.duration {
                            descriptionString = "\(stringForDuration(Int32(duration))) • \(dateString)"
                        } else {
                            descriptionString = dateString
                        }
                        
                        descriptionText = NSAttributedString(string: descriptionString, font: descriptionFont, textColor: item.theme.list.itemSecondaryTextColor)
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
            
            let (titleNodeLayout, titleNodeApply) = titleNodeMakeLayout(TextNodeLayoutArguments(attributedString: titleText, backgroundColor: nil, maximumNumberOfLines: 2, truncationType: .middle, constrainedSize: CGSize(width: params.width - leftInset - rightInset - 40.0, height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (descriptionNodeLayout, descriptionNodeApply) = descriptionNodeMakeLayout(TextNodeLayoutArguments(attributedString: descriptionText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset - 12.0 - 40.0, height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (extensionTextLayout, extensionTextApply) = extensionIconTextMakeLayout(TextNodeLayoutArguments(attributedString: extensionText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 38.0, height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var iconImageApply: (() -> Void)?
            if let iconImage = iconImage {
                switch iconImage {
                    case let .imageRepresentation(_, representation):
                        let iconSize = CGSize(width: 40.0, height: 40.0)
                        let imageCorners = ImageCorners(radius: 6.0)
                        let arguments = TransformImageArguments(corners: imageCorners, imageSize: representation.dimensions.cgSize.aspectFilled(iconSize), boundingSize: iconSize, intrinsicInsets: UIEdgeInsets(), emptyColor: item.theme.list.mediaPlaceholderColor)
                        iconImageApply = iconImageLayout(arguments)
                    case .albumArt:
                        let iconSize = CGSize(width: 40.0, height: 40.0)
                        let imageCorners = ImageCorners(radius: iconSize.width / 2.0)
                        let arguments = TransformImageArguments(corners: imageCorners, imageSize: iconSize, boundingSize: iconSize, intrinsicInsets: UIEdgeInsets(), emptyColor: item.theme.list.mediaPlaceholderColor)
                        iconImageApply = iconImageLayout(arguments)
                    case let .roundVideo(file):
                        let iconSize = CGSize(width: 40.0, height: 40.0)
                        let imageCorners = ImageCorners(radius: iconSize.width / 2.0)
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
                            updateIconImageSignal = playerAlbumArt(postbox: item.context.account.postbox, fileReference: .message(message: MessageReference(message), media: file), albumArt: albumArt, thumbnail: true, overlayColor: UIColor(white: 0.0, alpha: 0.3), emptyColor: item.theme.list.itemAccentColor)
                        case let .roundVideo(file):
                            updateIconImageSignal = mediaGridMessageVideo(postbox: item.context.account.postbox, videoReference: FileMediaReference.message(message: MessageReference(message), media: file), autoFetchFullSizeThumbnail: true, overlayColor: UIColor(white: 0.0, alpha: 0.3))
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
                    
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: nodeLayout.contentSize)
                    strongSelf.contextSourceNode.frame = CGRect(origin: CGPoint(), size: nodeLayout.contentSize)
                    strongSelf.offsetContainerNode.frame = CGRect(origin: CGPoint(), size: nodeLayout.contentSize)
                    strongSelf.contextSourceNode.contentNode.frame = CGRect(origin: CGPoint(), size: nodeLayout.contentSize)
                    
                    let nonExtractedRect = CGRect(origin: CGPoint(), size: CGSize(width: nodeLayout.contentSize.width - 16.0, height: nodeLayout.contentSize.height))
                    let extractedRect = CGRect(origin: CGPoint(), size: nodeLayout.contentSize).insetBy(dx: 16.0, dy: 0.0)
                    strongSelf.extractedRect = extractedRect
                    strongSelf.nonExtractedRect = nonExtractedRect
                    
                    if strongSelf.contextSourceNode.isExtractedToContextPreview {
                        strongSelf.extractedBackgroundImageNode.frame = extractedRect
                    } else {
                        strongSelf.extractedBackgroundImageNode.frame = nonExtractedRect
                    }
                    strongSelf.contextSourceNode.contentRect = extractedRect
                    
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
                        strongSelf.linearProgressNode?.updateTheme(theme: item.theme)
                    }
                    
                    if let (selectionWidth, selectionApply) = selectionNodeWidthAndApply {
                        let selectionFrame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: selectionWidth, height: nodeLayout.contentSize.height))
                        let selectionNode = selectionApply(selectionFrame.size, transition.isAnimated)
                        if selectionNode !== strongSelf.selectionNode {
                            strongSelf.selectionNode?.removeFromSupernode()
                            strongSelf.selectionNode = selectionNode
                            strongSelf.contextSourceNode.contentNode.addSubnode(selectionNode)
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
                    
                    transition.updateFrame(node: strongSelf.titleNode, frame: CGRect(origin: CGPoint(x: leftOffset + leftInset, y: 9.0), size: titleNodeLayout.size))
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
                    
                    transition.updateFrame(node: strongSelf.descriptionNode, frame: CGRect(origin: CGPoint(x: leftOffset + leftInset + descriptionOffset, y: strongSelf.titleNode.frame.maxY + 1.0), size: descriptionNodeLayout.size))
                    let _ = descriptionNodeApply()
                    
                    let iconFrame: CGRect
                    if isAudio {
                        let iconSize = CGSize(width: 40.0, height: 40.0)
                        iconFrame = CGRect(origin: CGPoint(x: params.leftInset + leftOffset + 12.0, y: 8.0), size: iconSize)
                    } else {
                        let iconSize = CGSize(width: 40.0, height: 40.0)
                        iconFrame = CGRect(origin: CGPoint(x: params.leftInset + leftOffset + 12.0, y: 8.0), size: iconSize)
                    }
                    transition.updateFrame(node: strongSelf.extensionIconNode, frame: iconFrame)
                    strongSelf.extensionIconNode.image = extensionIconImage
                    transition.updateFrame(node: strongSelf.extensionIconText, frame: CGRect(origin: CGPoint(x: iconFrame.minX + floor((iconFrame.width - extensionTextLayout.size.width) / 2.0), y: iconFrame.minY + 2.0 + floor((iconFrame.height - extensionTextLayout.size.height) / 2.0)), size: extensionTextLayout.size))
                    
                    transition.updateFrame(node: strongSelf.iconStatusNode, frame: iconFrame)
                    
                    let _ = extensionTextApply()
                    
                    strongSelf.currentIconImage = iconImage
                    
                    if let iconImageApply = iconImageApply {
                        if let updateImageSignal = updateIconImageSignal {
                            strongSelf.iconImageNode.setSignal(updateImageSignal)
                        }
                        
                        transition.updateFrame(node: strongSelf.iconImageNode, frame: iconFrame)
                        if strongSelf.iconImageNode.supernode == nil {
                            strongSelf.offsetContainerNode.insertSubnode(strongSelf.iconImageNode, belowSubnode: strongSelf.iconStatusNode)
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
                            strongSelf.offsetContainerNode.insertSubnode(strongSelf.extensionIconNode, belowSubnode: strongSelf.iconStatusNode)
                        }
                        if strongSelf.extensionIconText.supernode == nil {
                            strongSelf.offsetContainerNode.insertSubnode(strongSelf.extensionIconText, belowSubnode: strongSelf.iconStatusNode)
                        }
                    }
                    
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
                    
                    transition.updateFrame(node: strongSelf.downloadStatusIconNode, frame: CGRect(origin: CGPoint(x: leftOffset + leftInset, y: strongSelf.descriptionNode.frame.minY + floor((strongSelf.descriptionNode.frame.height - 12.0) / 2.0)), size: CGSize(width: 12.0, height: 12.0)))
                    
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
        
        var iconStatusState: SemanticStatusNodeState = .none
        var iconStatusBackgroundColor: UIColor = .clear
        var iconStatusForegroundColor: UIColor = .white
        
        if isVoice {
            iconStatusBackgroundColor = item.theme.list.itemAccentColor
            iconStatusForegroundColor = item.theme.list.itemCheckColors.foregroundColor
        }
        
        if !isAudio && !isInstantVideo {
            self.updateProgressFrame(size: contentSize, leftInset: layoutParams.leftInset, rightInset: layoutParams.rightInset, transition: .immediate)
        } else {
            switch status {
                case let .fetchStatus(fetchStatus):
                    switch fetchStatus {
                        case .Fetching:
                            break
                        case .Local:
                            if isAudio || isInstantVideo {
                                iconStatusState = .play
                            }
                        case .Remote:
                            if isAudio || isInstantVideo {
                                iconStatusState = .play
                            }
                    }
                case let .playbackStatus(playbackStatus):
                    switch playbackStatus {
                    case .playing:
                        iconStatusState = .pause
                    case .paused:
                        iconStatusState = .play
                    }
            }
        }
        self.iconStatusNode.backgroundNodeColor = iconStatusBackgroundColor
        self.iconStatusNode.foregroundNodeColor = iconStatusForegroundColor
        self.iconStatusNode.transitionToState(iconStatusState)
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
                    let progressFrame = CGRect(x: self.currentLeftOffset + leftInset + 65.0, y: size.height - 2.0, width: floor((size.width - 65.0 - leftInset - rightInset)), height: 3.0)
                    let linearProgressNode: LinearProgressNode
                    if let current = self.linearProgressNode {
                        linearProgressNode = current
                    } else {
                        linearProgressNode = LinearProgressNode()
                        linearProgressNode.updateTheme(theme: item.theme)
                        self.linearProgressNode = linearProgressNode
                        self.addSubnode(linearProgressNode)
                    }
                    transition.updateFrame(node: linearProgressNode, frame: progressFrame)
                    linearProgressNode.updateProgress(value: CGFloat(progress), completion: {})
                    
                    if self.downloadStatusIconNode.supernode == nil {
                        self.offsetContainerNode.addSubnode(self.downloadStatusIconNode)
                    }
                    self.downloadStatusIconNode.image = PresentationResourcesChat.sharedMediaFileDownloadPauseIcon(item.theme)
                case .Local:
                    if let linearProgressNode = self.linearProgressNode {
                        self.linearProgressNode = nil
                        linearProgressNode.updateProgress(value: 1.0, completion: { [weak linearProgressNode] in
                            linearProgressNode?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { _ in
                                linearProgressNode?.removeFromSupernode()
                            })
                        })
                    }
                    if self.downloadStatusIconNode.supernode != nil {
                        self.downloadStatusIconNode.removeFromSupernode()
                    }
                    self.downloadStatusIconNode.image = nil
                case .Remote:
                    if let linearProgressNode = self.linearProgressNode {
                        self.linearProgressNode = nil
                        linearProgressNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak linearProgressNode] _ in
                            linearProgressNode?.removeFromSupernode()
                        })
                    }
                    if self.downloadStatusIconNode.supernode == nil {
                        self.offsetContainerNode.addSubnode(self.downloadStatusIconNode)
                    }
                    self.downloadStatusIconNode.image = PresentationResourcesChat.sharedMediaFileDownloadStartIcon(item.theme)
                }
        } else {
            if let linearProgressNode = self.linearProgressNode {
                self.linearProgressNode = nil
                linearProgressNode.layer.animateAlpha(from: 1.0, to: 1.0, duration: 0.2, removeOnCompletion: false, completion: { [weak linearProgressNode] _ in
                    linearProgressNode?.removeFromSupernode()
                })
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

private final class LinearProgressNode: ASDisplayNode {
    private let trackingNode: HierarchyTrackingNode
    private let barNode: ASImageNode
    private let shimmerNode: ASImageNode
    private let shimmerClippingNode: ASDisplayNode
    
    private var currentProgress: CGFloat = 0.0
    private var currentProgressAnimation: (from: CGFloat, to: CGFloat, startTime: Double, completion: () -> Void)?
    
    private var shimmerPhase: CGFloat = 0.0
    
    private var inHierarchyValue: Bool = false
    private var shouldAnimate: Bool = false
    
    private let animator: ConstantDisplayLinkAnimator
    
    override init() {
        var updateInHierarchy: ((Bool) -> Void)?
        self.trackingNode = HierarchyTrackingNode { value in
            updateInHierarchy?(value)
        }
        
        var animationStep: (() -> Void)?
        self.animator = ConstantDisplayLinkAnimator {
            animationStep?()
        }
        
        
        self.barNode = ASImageNode()
        self.barNode.isLayerBacked = true
        
        self.shimmerNode = ASImageNode()
        self.shimmerNode.contentMode = .scaleToFill
        self.shimmerClippingNode = ASDisplayNode()
        self.shimmerClippingNode.clipsToBounds = true
        
        super.init()
        
        self.addSubnode(trackingNode)
        self.addSubnode(self.barNode)
        
        self.shimmerClippingNode.addSubnode(self.shimmerNode)
        self.addSubnode(self.shimmerClippingNode)
        
        updateInHierarchy = { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.inHierarchyValue != value {
                strongSelf.inHierarchyValue = value
                strongSelf.updateAnimations()
            }
        }
        
        animationStep = { [weak self] in
            self?.update()
        }
    }
    
    func updateTheme(theme: PresentationTheme) {
        self.barNode.image = generateStretchableFilledCircleImage(diameter: 3.0, color: theme.list.itemAccentColor)
        self.shimmerNode.image = generateImage(CGSize(width: 100.0, height: 3.0), opaque: false, rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            let foregroundColor = theme.list.plainBackgroundColor.withAlphaComponent(0.4)
            
            let transparentColor = foregroundColor.withAlphaComponent(0.0).cgColor
            let peakColor = foregroundColor.cgColor
            
            var locations: [CGFloat] = [0.0, 0.5, 1.0]
            let colors: [CGColor] = [transparentColor, peakColor, transparentColor]
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
            
            context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: size.width, y: 0.0), options: CGGradientDrawingOptions())
        })
    }
    
    func updateProgress(value: CGFloat, completion: @escaping () -> Void = {}) {
        if self.currentProgress.isEqual(to: value) {
            self.currentProgressAnimation = nil
            completion()
        } else {
            self.currentProgressAnimation = (self.currentProgress, value, CACurrentMediaTime(), completion)
        }
    }
    
    private func updateAnimations() {
        let shouldAnimate = self.inHierarchyValue
        if shouldAnimate != self.shouldAnimate {
            self.shouldAnimate = shouldAnimate
            self.animator.isPaused = !shouldAnimate
        }
    }
    
    private func update() {
        if let (fromValue, toValue, startTime, completion) = self.currentProgressAnimation {
            let duration: Double = 0.15
            let timestamp = CACurrentMediaTime()
            let t = CGFloat((timestamp - startTime) / duration)
            if t >= 1.0 {
                self.currentProgress = toValue
                self.currentProgressAnimation = nil
                completion()
            } else {
                let clippedT = max(0.0, t)
                self.currentProgress = (1.0 - clippedT) * fromValue + clippedT * toValue
            }
            
            var progressWidth: CGFloat = self.bounds.width * self.currentProgress
            if progressWidth < 6.0 {
                progressWidth = 0.0
            }
            let progressFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: progressWidth, height: 3.0))
            self.barNode.frame = progressFrame
            self.shimmerClippingNode.frame = progressFrame
        }
        
        self.shimmerPhase += 3.5
        let shimmerWidth: CGFloat = 160.0
        let shimmerOffset = self.shimmerPhase.remainder(dividingBy: self.bounds.width + shimmerWidth / 2.0)
        self.shimmerNode.frame = CGRect(origin: CGPoint(x: shimmerOffset - shimmerWidth / 2.0, y: 0.0), size: CGSize(width: shimmerWidth, height: 3.0))
    }
}
