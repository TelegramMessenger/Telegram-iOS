import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
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
import FileMediaResourceStatus
import ManagedAnimationNode
import ShimmerEffect

private let extensionImageCache = Atomic<[UInt32: UIImage]>(value: [:])

private let redColors: (UInt32, UInt32) = (0xed6b7b, 0xe63f45)
private let greenColors: (UInt32, UInt32) = (0x99de6f, 0x5fb84f)
private let blueColors: (UInt32, UInt32) = (0x72d5fd, 0x2a9ef1)
private let yellowColors: (UInt32, UInt32) = (0xffa24b, 0xed705c)

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
        
        context.saveGState()
        context.beginPath()
        let _ = try? drawSvgPath(context, path: "M6,0 L26.7573593,0 C27.5530088,-8.52837125e-16 28.3160705,0.316070521 28.8786797,0.878679656 L39.1213203,11.1213203 C39.6839295,11.6839295 40,12.4469912 40,13.2426407 L40,34 C40,37.3137085 37.3137085,40 34,40 L6,40 C2.6862915,40 4.05812251e-16,37.3137085 0,34 L0,6 C-4.05812251e-16,2.6862915 2.6862915,6.08718376e-16 6,0 ")
        context.clip()
        
        let gradientColors = [UIColor(rgb: colors.0).cgColor, UIColor(rgb: colors.1).cgColor] as CFArray
        var locations: [CGFloat] = [0.0, 1.0]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        
        context.restoreGState()
        
        context.beginPath()
        let _ = try? drawSvgPath(context, path: "M6,0 L26.7573593,0 C27.5530088,-8.52837125e-16 28.3160705,0.316070521 28.8786797,0.878679656 L39.1213203,11.1213203 C39.6839295,11.6839295 40,12.4469912 40,13.2426407 L40,34 C40,37.3137085 37.3137085,40 34,40 L6,40 C2.6862915,40 4.05812251e-16,37.3137085 0,34 L0,6 C-4.05812251e-16,2.6862915 2.6862915,6.08718376e-16 6,0 ")
        context.clip()
        
        context.setFillColor(UIColor(rgb: 0xffffff, alpha: 0.2).cgColor)
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
private let extensionFont = Font.with(size: 15.0, design: .round, weight: .bold)
private let mediumExtensionFont = Font.with(size: 14.0, design: .round, weight: .bold)
private let smallExtensionFont = Font.with(size: 12.0, design: .round, weight: .bold)

private struct FetchControls {
    let fetch: () -> Void
    let cancel: () -> Void
}

private enum FileIconImage: Equatable {
    case imageRepresentation(Media, TelegramMediaImageRepresentation)
    case albumArt(TelegramMediaFile, SharedMediaPlaybackAlbumArt)
    case roundVideo(TelegramMediaFile)
    
    static func ==(lhs: FileIconImage, rhs: FileIconImage) -> Bool {
        switch lhs {
        case let .imageRepresentation(lhsMedia, lhsValue):
            if case let .imageRepresentation(rhsMedia, rhsValue) = rhs, lhsMedia.isEqual(to: rhsMedia), lhsValue == rhsValue {
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

final class CachedChatListSearchResult {
    let text: String
    let searchQuery: String
    let resultRanges: [Range<String.Index>]
    
    init(text: String, searchQuery: String, resultRanges: [Range<String.Index>]) {
        self.text = text
        self.searchQuery = searchQuery
        self.resultRanges = resultRanges
    }
    
    func matches(text: String, searchQuery: String) -> Bool {
        if self.text != text {
            return false
        }
        if self.searchQuery != searchQuery {
            return false
        }
        return true
    }
}

public final class ListMessageFileItemNode: ListMessageNode {
    private let contextSourceNode: ContextExtractedContentContainingNode
    private let containerNode: ContextControllerSourceNode
    private let extractedBackgroundImageNode: ASImageNode
    
    private var extractedRect: CGRect?
    private var nonExtractedRect: CGRect?
    
    private let offsetContainerNode: ASDisplayNode
    
    private var backgroundNode: ASDisplayNode?
    private let highlightedBackgroundNode: ASDisplayNode
    public let separatorNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private var selectionNode: ItemListSelectableControlNode?
    
    public let titleNode: TextNode
    public let textNode: TextNode
    public let descriptionNode: TextNode
    private let descriptionProgressNode: ImmediateTextNode
    public let dateNode: TextNode
    
    public let extensionIconNode: ASImageNode
    private let extensionIconText: TextNode
    public let iconImageNode: TransformImageNode
    private let iconStatusNode: SemanticStatusNode
    
    private let restrictionNode: ASDisplayNode
    
    private var currentIconImage: FileIconImage?
    public var currentMedia: Media?
    
    private let statusDisposable = MetaDisposable()
    private let fetchControls = Atomic<FetchControls?>(value: nil)
    private var fetchStatus: MediaResourceStatus?
    private var resourceStatus: FileMediaResourceMediaStatus?
    private let fetchDisposable = MetaDisposable()
    private let playbackStatusDisposable = MetaDisposable()
    private let playbackStatus = Promise<MediaPlayerStatus>()
    
    private var downloadStatusIconNode: DownloadIconNode?
    private var linearProgressNode: LinearProgressNode?
    
    private var placeholderNode: ShimmerEffectNode?
    private var absoluteLocation: (CGRect, CGSize)?
    
    private var context: AccountContext?
    private (set) var message: Message?
    
    private var appliedItem: ListMessageItem?
    private var layoutParams: ListViewItemLayoutParams?
    private var contentSizeValue: CGSize?
    private var currentLeftOffset: CGFloat = 0.0
    
    private var currentIsRestricted = false
    private var cachedSearchResult: CachedChatListSearchResult?
    
    public required init() {
        self.contextSourceNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.displaysAsynchronously = false
        self.separatorNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        self.extractedBackgroundImageNode = ASImageNode()
        self.extractedBackgroundImageNode.displaysAsynchronously = false
        self.extractedBackgroundImageNode.alpha = 0.0
        
        self.offsetContainerNode = ASDisplayNode()
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.titleNode = TextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.isUserInteractionEnabled = false

        self.textNode = TextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.isUserInteractionEnabled = false
        
        self.descriptionNode = TextNode()
        self.descriptionNode.displaysAsynchronously = false
        self.descriptionNode.isUserInteractionEnabled = false
        
        self.descriptionProgressNode = ImmediateTextNode()
        self.descriptionProgressNode.displaysAsynchronously = false
        self.descriptionProgressNode.isUserInteractionEnabled = false
        self.descriptionProgressNode.maximumNumberOfLines = 1
        
        self.dateNode = TextNode()
        self.dateNode.isUserInteractionEnabled = false
        
        self.extensionIconNode = ASImageNode()
        self.extensionIconNode.isLayerBacked = true
        self.extensionIconNode.displaysAsynchronously = false
        self.extensionIconNode.displayWithoutProcessing = true
        
        self.extensionIconText = TextNode()
        self.extensionIconText.displaysAsynchronously = false
        self.extensionIconText.isUserInteractionEnabled = false
        
        self.iconImageNode = TransformImageNode()
        self.iconImageNode.displaysAsynchronously = false
        self.iconImageNode.contentAnimations = .subsequentUpdates
        
        self.iconStatusNode = SemanticStatusNode(backgroundNodeColor: .clear, foregroundNodeColor: .white)
        self.iconStatusNode.isUserInteractionEnabled = false
        
        self.restrictionNode = ASDisplayNode()
        self.restrictionNode.isHidden = true
        
        super.init()
        
        self.containerNode.addSubnode(self.contextSourceNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        self.addSubnode(self.containerNode)
        
        self.contextSourceNode.contentNode.addSubnode(self.extractedBackgroundImageNode)
        self.contextSourceNode.contentNode.addSubnode(self.offsetContainerNode)
        self.offsetContainerNode.addSubnode(self.titleNode)
        self.offsetContainerNode.addSubnode(self.textNode)
        self.offsetContainerNode.addSubnode(self.descriptionNode)
        self.offsetContainerNode.addSubnode(self.descriptionProgressNode)
        self.offsetContainerNode.addSubnode(self.dateNode)
        self.offsetContainerNode.addSubnode(self.extensionIconNode)
        self.offsetContainerNode.addSubnode(self.extensionIconText)
        self.offsetContainerNode.addSubnode(self.iconStatusNode)
        
        self.addSubnode(self.restrictionNode)
        self.addSubnode(self.separatorNode)
        
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let item = strongSelf.item, let message = item.message else {
                return
            }

            cancelParentGestures(view: strongSelf.view)
            
            item.interaction.openMessageContextMenu(message, false, strongSelf.contextSourceNode, strongSelf.contextSourceNode.bounds, gesture)
        }
        
        self.contextSourceNode.willUpdateIsExtractedToContextPreview = { [weak self] isExtracted, transition in
            guard let strongSelf = self, let item = strongSelf.item else {
                return
            }
            
            if isExtracted {
                strongSelf.extractedBackgroundImageNode.image = generateStretchableFilledCircleImage(diameter: 28.0, color: item.presentationData.theme.theme.list.plainBackgroundColor)
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
            transition.updateAlpha(node: strongSelf.dateNode, alpha: isExtracted ? 0.0 : 1.0)
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
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        var rect = rect
        rect.origin.y += self.insets.top
        self.absoluteLocation = (rect, containerSize)
        if let shimmerNode = self.placeholderNode {
            shimmerNode.updateAbsoluteRect(rect, within: containerSize)
        }
    }
    
    override public func asyncLayout() -> (_ item: ListMessageItem, _ params: ListViewItemLayoutParams, _ mergedTop: Bool, _ mergedBottom: Bool, _ dateHeaderAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let titleNodeMakeLayout = TextNode.asyncLayout(self.titleNode)
        let textNodeMakeLayout = TextNode.asyncLayout(self.textNode)
        let descriptionNodeMakeLayout = TextNode.asyncLayout(self.descriptionNode)
        let extensionIconTextMakeLayout = TextNode.asyncLayout(self.extensionIconText)
        let dateNodeMakeLayout = TextNode.asyncLayout(self.dateNode)
        let iconImageLayout = self.iconImageNode.asyncLayout()
        
        let currentMedia = self.currentMedia
        let currentMessage = self.message
        let currentIconImage = self.currentIconImage
        let currentSearchResult = self.cachedSearchResult
        
        let currentItem = self.appliedItem
        
        let selectionNodeLayout = ItemListSelectableControlNode.asyncLayout(self.selectionNode)
        
        return { [weak self] item, params, mergedTop, mergedBottom, dateHeaderAtBottom in
            var updatedTheme: PresentationTheme?
            
            if currentItem?.presentationData.theme.theme !== item.presentationData.theme.theme {
                updatedTheme = item.presentationData.theme.theme
            }
            
            let titleFont = Font.semibold(floor(item.presentationData.fontSize.baseDisplaySize * 16.0 / 17.0))
            let audioTitleFont = Font.semibold(floor(item.presentationData.fontSize.baseDisplaySize * 16.0 / 17.0))
            let descriptionFont = Font.regular(floor(item.presentationData.fontSize.baseDisplaySize * 14.0 / 17.0))
            let dateFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 14.0 / 17.0))
            
            let leftInset: CGFloat = 65.0 + params.leftInset
            let rightInset: CGFloat = 8.0 + params.rightInset
            
            var leftOffset: CGFloat = 0.0
            var selectionNodeWidthAndApply: (CGFloat, (CGSize, Bool) -> ItemListSelectableControlNode)?
            if case let .selectable(selected) = item.selection {
                let (selectionWidth, selectionApply) = selectionNodeLayout(item.presentationData.theme.theme.list.itemCheckColors.strokeColor, item.presentationData.theme.theme.list.itemCheckColors.fillColor, item.presentationData.theme.theme.list.itemCheckColors.foregroundColor, selected, false)
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
            
            var isRestricted = false
            
            let message = item.message
            
            var selectedMedia: Media?
            if let message = message {
                for media in message.media {
                    if let file = media as? TelegramMediaFile {
                        selectedMedia = file
                        
                        isInstantVideo = file.isInstantVideo
                        
                        for attribute in file.attributes {
                            if case let .Audio(voice, duration, title, performer, _) = attribute {
                                isAudio = true
                                isVoice = voice
                                
                                titleText = NSAttributedString(string: title ?? (file.fileName ?? "Unknown Track"), font: audioTitleFont, textColor: item.presentationData.theme.theme.list.itemPrimaryTextColor)
                                
                                var descriptionString: String
                                if let performer = performer {
                                    if item.isGlobalSearchResult || item.isDownloadList {
                                        descriptionString = performer
                                    } else {
                                        descriptionString = "\(stringForDuration(Int32(duration))) • \(performer)"
                                    }
                                } else if let size = file.size {
                                    descriptionString = dataSizeString(size, formatting: DataSizeStringFormatting(chatPresentationData: item.presentationData))
                                } else {
                                    descriptionString = ""
                                }
                                
                                if item.isGlobalSearchResult || item.isDownloadList {
                                    let authorString = stringForFullAuthorName(message: EngineMessage(message), strings: item.presentationData.strings, nameDisplayOrder: item.presentationData.nameDisplayOrder, accountPeerId: item.context.account.peerId)
                                    if descriptionString.isEmpty {
                                        descriptionString = authorString
                                    } else {
                                        descriptionString = "\(descriptionString) • \(authorString)"
                                    }
                                }
                                
                                descriptionText = NSAttributedString(string: descriptionString, font: descriptionFont, textColor: item.presentationData.theme.theme.list.itemSecondaryTextColor)
                                
                                if !voice {
                                    if file.fileName?.lowercased().hasSuffix(".ogg") == true {
                                        iconImage = .albumArt(file, SharedMediaPlaybackAlbumArt(thumbnailResource: ExternalMusicAlbumArtResource(file: .message(message: MessageReference(message), media: file), title: "", performer: "", isThumbnail: true), fullSizeResource: ExternalMusicAlbumArtResource(file: .message(message: MessageReference(message), media: file), title: "", performer: "", isThumbnail: false)))
                                    } else {
                                        iconImage = .albumArt(file, SharedMediaPlaybackAlbumArt(thumbnailResource: ExternalMusicAlbumArtResource(file: .message(message: MessageReference(message), media: file), title: title ?? "", performer: performer ?? "", isThumbnail: true), fullSizeResource: ExternalMusicAlbumArtResource(file: .message(message: MessageReference(message), media: file), title: title ?? "", performer: performer ?? "", isThumbnail: false)))
                                    }
                                } else {
                                    titleText = NSAttributedString(string: " ", font: audioTitleFont, textColor: item.presentationData.theme.theme.list.itemPrimaryTextColor)
                                    descriptionText = NSAttributedString(string: message.author.flatMap(EnginePeer.init)?.displayTitle(strings: item.presentationData.strings, displayOrder: .firstLast) ?? " ", font: descriptionFont, textColor: item.presentationData.theme.theme.list.itemSecondaryTextColor)
                                }
                            }
                        }
                        
                        if isInstantVideo || isVoice {
                            var authorName: String
                            if let author = message.forwardInfo?.author {
                                if author.id == item.context.account.peerId {
                                    authorName = item.presentationData.strings.DialogList_You
                                } else {
                                    authorName = EnginePeer(author).displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                                }
                            } else if let signature = message.forwardInfo?.authorSignature {
                                authorName = signature
                            } else if let author = message.author {
                                if author.id == item.context.account.peerId {
                                    authorName = item.presentationData.strings.DialogList_You
                                } else {
                                    authorName = EnginePeer(author).displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                                }
                            } else {
                                authorName = " "
                            }
                            
                            if item.isGlobalSearchResult || item.isDownloadList {
                                authorName = stringForFullAuthorName(message: EngineMessage(message), strings: item.presentationData.strings, nameDisplayOrder: item.presentationData.nameDisplayOrder, accountPeerId: item.context.account.peerId)
                            }
                            
                            titleText = NSAttributedString(string: authorName, font: audioTitleFont, textColor: item.presentationData.theme.theme.list.itemPrimaryTextColor)
                            let dateString = stringForFullDate(timestamp: message.timestamp, strings: item.presentationData.strings, dateTimeFormat: item.presentationData.dateTimeFormat)
                            var descriptionString: String = ""
                            if let duration = file.duration {
                                if item.isGlobalSearchResult || item.isDownloadList || !item.displayFileInfo {
                                    descriptionString = stringForDuration(Int32(duration))
                                } else {
                                    descriptionString = "\(stringForDuration(Int32(duration))) • \(dateString)"
                                }
                            } else {
                                if !(item.isGlobalSearchResult || item.isDownloadList) {
                                    descriptionString = dateString
                                }
                            }
                            
                            descriptionText = NSAttributedString(string: descriptionString, font: descriptionFont, textColor: item.presentationData.theme.theme.list.itemSecondaryTextColor)
                            iconImage = .roundVideo(file)
                        } else if !isAudio {
                            var fileName: String = file.fileName ?? "File"
                            if file.isVideo {
                                fileName = item.presentationData.strings.Message_Video
                            }
                            titleText = NSAttributedString(string: fileName, font: titleFont, textColor: item.presentationData.theme.theme.list.itemPrimaryTextColor)
                            
                            var fileExtension: String?
                            if let range = fileName.range(of: ".", options: [.backwards]) {
                                fileExtension = fileName[range.upperBound...].lowercased()
                            }
                            extensionIconImage = extensionImage(fileExtension: fileExtension)
                            if let fileExtension = fileExtension {
                                extensionText = NSAttributedString(string: fileExtension, font: fileExtension.count > 3 ? mediumExtensionFont : extensionFont, textColor: UIColor.white)
                            }
                            
                            if let representation = smallestImageRepresentation(file.previewRepresentations) {
                                iconImage = .imageRepresentation(file, representation)
                            }
                            
                            let dateString = stringForFullDate(timestamp: message.timestamp, strings: item.presentationData.strings, dateTimeFormat: item.presentationData.dateTimeFormat)
                            
                            var descriptionString: String = ""
                            if let size = file.size {
                                if item.isGlobalSearchResult || item.isDownloadList || !item.displayFileInfo {
                                    descriptionString = dataSizeString(size, formatting: DataSizeStringFormatting(chatPresentationData: item.presentationData))
                                } else {
                                    descriptionString = "\(dataSizeString(size, formatting: DataSizeStringFormatting(chatPresentationData: item.presentationData))) • \(dateString)"
                                }
                            } else {
                                if !(item.isGlobalSearchResult || item.isDownloadList) {
                                    descriptionString = "\(dateString)"
                                }
                            }
                            
                            if item.isGlobalSearchResult || item.isDownloadList {
                                let authorString = stringForFullAuthorName(message: EngineMessage(message), strings: item.presentationData.strings, nameDisplayOrder: item.presentationData.nameDisplayOrder, accountPeerId: item.context.account.peerId)
                                if descriptionString.isEmpty {
                                    descriptionString = authorString
                                } else {
                                    descriptionString = "\(descriptionString) • \(authorString)"
                                }
                            }
                        
                            descriptionText = NSAttributedString(string: descriptionString, font: descriptionFont, textColor: item.presentationData.theme.theme.list.itemSecondaryTextColor)
                        }
                        
                        break
                    } else if let image = media as? TelegramMediaImage {
                        selectedMedia = image
                        
                        let fileName: String = item.presentationData.strings.Message_Photo
                        titleText = NSAttributedString(string: fileName, font: titleFont, textColor: item.presentationData.theme.theme.list.itemPrimaryTextColor)
                        
                        if let representation = smallestImageRepresentation(image.representations) {
                            iconImage = .imageRepresentation(image, representation)
                        }
                        
                        let dateString = stringForFullDate(timestamp: message.timestamp, strings: item.presentationData.strings, dateTimeFormat: item.presentationData.dateTimeFormat)
                        
                        var descriptionString: String = ""
                        if !(item.isGlobalSearchResult || item.isDownloadList) {
                            descriptionString = "\(dateString)"
                        }
                        
                        if item.isGlobalSearchResult || item.isDownloadList {
                            let authorString = stringForFullAuthorName(message: EngineMessage(message), strings: item.presentationData.strings, nameDisplayOrder: item.presentationData.nameDisplayOrder, accountPeerId: item.context.account.peerId)
                            if descriptionString.isEmpty {
                                descriptionString = authorString
                            } else {
                                descriptionString = "\(descriptionString) • \(authorString)"
                            }
                        }
                    
                        descriptionText = NSAttributedString(string: descriptionString, font: descriptionFont, textColor: item.presentationData.theme.theme.list.itemSecondaryTextColor)
                    }
                }
    
                for attribute in message.attributes {
                    if let attribute = attribute as? RestrictedContentMessageAttribute, attribute.platformText(platform: "ios", contentSettings: item.context.currentContentSettings.with { $0 }) != nil {
                        isRestricted = true
                        break
                    }
                }
            } else {
                titleText = NSAttributedString(string: " ", font: titleFont, textColor: item.presentationData.theme.theme.list.itemPrimaryTextColor)
                descriptionText = NSAttributedString(string: " ", font: descriptionFont, textColor: item.presentationData.theme.theme.list.itemSecondaryTextColor)
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
            if currentMessage?.id != message?.id || currentMessage?.flags != message?.flags {
                statusUpdated = true
            }
            
            if let message = message, let selectedMedia = selectedMedia {
                if mediaUpdated {
                    let context = item.context
                    updatedFetchControls = FetchControls(fetch: { [weak self] in
                        if let strongSelf = self {
                            if let file = selectedMedia as? TelegramMediaFile {
                                strongSelf.fetchDisposable.set(messageMediaFileInteractiveFetched(context: context, message: message, file: file, userInitiated: true).start())
                            } else if let image = selectedMedia as? TelegramMediaImage, let representation = image.representations.last {
                                strongSelf.fetchDisposable.set(messageMediaImageInteractiveFetched(context: context, message: message, image: image, resource: representation.resource, userInitiated: true, storeToDownloadsPeerType: nil).start())
                            }
                        }
                    }, cancel: {
                        if let file = selectedMedia as? TelegramMediaFile {
                            if item.isDownloadList {
                                context.fetchManager.toggleInteractiveFetchPaused(resourceId: file.resource.id.stringRepresentation, isPaused: true)
                            } else {
                                messageMediaFileCancelInteractiveFetch(context: context, messageId: message.id, file: file)
                            }
                        } else if let image = selectedMedia as? TelegramMediaImage, let representation = image.representations.last {
                            if item.isDownloadList {
                                context.fetchManager.toggleInteractiveFetchPaused(resourceId: representation.resource.id.stringRepresentation, isPaused: true)
                            } else {
                                messageMediaImageCancelInteractiveFetch(context: context, messageId: message.id, image: image, resource: representation.resource)
                            }
                        }
                    })
                }
                
                if statusUpdated && item.displayFileInfo {
                    if let file = selectedMedia as? TelegramMediaFile {
                        updatedStatusSignal = messageFileMediaResourceStatus(context: item.context, file: file, message: message, isRecentActions: false, isSharedMedia: true, isGlobalSearch: item.isGlobalSearchResult, isDownloadList: item.isDownloadList)
                        |> mapToSignal { value -> Signal<FileMediaResourceStatus, NoError> in
                            if case .Fetching = value.fetchStatus, !item.isDownloadList {
                                return .single(value) |> delay(0.1, queue: Queue.concurrentDefaultQueue())
                            } else {
                                return .single(value)
                            }
                        }
                        
                        if isAudio || isInstantVideo {
                            if let currentUpdatedStatusSignal = updatedStatusSignal {
                                updatedStatusSignal = currentUpdatedStatusSignal
                                |> map { status in
                                    switch status.mediaStatus {
                                    case .fetchStatus:
                                        if item.isDownloadList {
                                            return FileMediaResourceStatus(mediaStatus: .fetchStatus(status.fetchStatus), fetchStatus: status.fetchStatus)
                                        } else {
                                            return FileMediaResourceStatus(mediaStatus: .fetchStatus(.Local), fetchStatus: status.fetchStatus)
                                        }
                                    case .playbackStatus:
                                        return status
                                    }
                                }
                            }
                        }
                        if isVoice {
                            updatedPlaybackStatusSignal = messageFileMediaPlaybackStatus(context: item.context, file: file, message: message, isRecentActions: false, isGlobalSearch: item.isGlobalSearchResult, isDownloadList: item.isDownloadList)
                        }
                    } else if let image = selectedMedia as? TelegramMediaImage {
                        updatedStatusSignal = messageImageMediaResourceStatus(context: item.context, image: image, message: message, isRecentActions: false, isSharedMedia: true, isGlobalSearch: item.isGlobalSearchResult || item.isDownloadList)
                        |> mapToSignal { value -> Signal<FileMediaResourceStatus, NoError> in
                            if case .Fetching = value.fetchStatus, !item.isDownloadList {
                                return .single(value) |> delay(0.1, queue: Queue.concurrentDefaultQueue())
                            } else {
                                return .single(value)
                            }
                        }
                    }
                }
            }
            
            var chatListSearchResult: CachedChatListSearchResult?
            let messageText = foldLineBreaks(item.message?.text ?? "")
            
            if let searchQuery = item.interaction.searchTextHighightState {
                if let cached = currentSearchResult, cached.matches(text: messageText, searchQuery: searchQuery) {
                    chatListSearchResult = cached
                } else {
                    let (ranges, text) = findSubstringRanges(in: messageText, query: searchQuery)
                    chatListSearchResult = CachedChatListSearchResult(text: text, searchQuery: searchQuery, resultRanges: ranges)
                }
            } else {
                chatListSearchResult = nil
            }
            
            var captionText: NSMutableAttributedString?
            if let chatListSearchResult = chatListSearchResult, let firstRange = chatListSearchResult.resultRanges.first {
                var text = NSMutableAttributedString(string: messageText, font: descriptionFont, textColor: item.presentationData.theme.theme.list.itemSecondaryTextColor)
                for range in chatListSearchResult.resultRanges {
                    let stringRange = NSRange(range, in: chatListSearchResult.text)
                    if stringRange.location >= 0 && stringRange.location + stringRange.length <= text.length {
                        text.addAttribute(.foregroundColor, value: item.presentationData.theme.theme.chatList.messageHighlightedTextColor, range: stringRange)
                    }
                }
                
                let firstRangeOrigin = chatListSearchResult.text.distance(from: chatListSearchResult.text.startIndex, to: firstRange.lowerBound)
                if firstRangeOrigin > 24 {
                    var leftOrigin: Int = 0
                    (text.string as NSString).enumerateSubstrings(in: NSMakeRange(0, firstRangeOrigin), options: [.byWords, .reverse]) { (str, range1, _, _) in
                        let distanceFromEnd = firstRangeOrigin - range1.location
                        if (distanceFromEnd > 12 || range1.location == 0) && leftOrigin == 0 {
                            leftOrigin = range1.location
                        }
                    }
                    text = text.attributedSubstring(from: NSMakeRange(leftOrigin, text.length - leftOrigin)).mutableCopy() as! NSMutableAttributedString
                    text.insert(NSAttributedString(string: "\u{2026}", attributes: [NSAttributedString.Key.font: descriptionFont, NSAttributedString.Key.foregroundColor: item.presentationData.theme.theme.list.itemSecondaryTextColor]), at: 0)
                }
                
                captionText = text
            }
            
            let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
            let dateText = stringForRelativeTimestamp(strings: item.presentationData.strings, relativeTimestamp: item.message?.timestamp ?? 0, relativeTo: timestamp, dateTimeFormat: item.presentationData.dateTimeFormat)
            let dateAttributedString = NSAttributedString(string: dateText, font: dateFont, textColor: item.presentationData.theme.theme.list.itemSecondaryTextColor)
            
            let (dateNodeLayout, dateNodeApply) = dateNodeMakeLayout(TextNodeLayoutArguments(attributedString: dateAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset - 12.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (titleNodeLayout, titleNodeApply) = titleNodeMakeLayout(TextNodeLayoutArguments(attributedString: titleText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .middle, constrainedSize: CGSize(width: params.width - leftInset - leftOffset - rightInset - dateNodeLayout.size.width - 4.0, height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (textNodeLayout, textNodeApply) = textNodeMakeLayout(TextNodeLayoutArguments(attributedString: captionText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset - 30.0, height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (descriptionNodeLayout, descriptionNodeApply) = descriptionNodeMakeLayout(TextNodeLayoutArguments(attributedString: descriptionText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset - 30.0, height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var (extensionTextLayout, extensionTextApply) = extensionIconTextMakeLayout(TextNodeLayoutArguments(attributedString: extensionText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 38.0, height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            if extensionTextLayout.truncated, let text = extensionText?.string  {
                extensionText = NSAttributedString(string: text, font: smallExtensionFont, textColor: .white, paragraphAlignment: .center)
                (extensionTextLayout, extensionTextApply) = extensionIconTextMakeLayout(TextNodeLayoutArguments(attributedString: extensionText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 38.0, height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            }
            
            var iconImageApply: (() -> Void)?
            if let iconImage = iconImage {
                switch iconImage {
                    case let .imageRepresentation(_, representation):
                        let iconSize = CGSize(width: 40.0, height: 40.0)
                        let imageCorners = ImageCorners(radius: 6.0)
                        let arguments = TransformImageArguments(corners: imageCorners, imageSize: representation.dimensions.cgSize.aspectFilled(iconSize), boundingSize: iconSize, intrinsicInsets: UIEdgeInsets(), emptyColor: item.presentationData.theme.theme.list.mediaPlaceholderColor)
                        iconImageApply = iconImageLayout(arguments)
                    case .albumArt:
                        let iconSize = CGSize(width: 40.0, height: 40.0)
                        let imageCorners = ImageCorners(radius: iconSize.width / 2.0)
                        let arguments = TransformImageArguments(corners: imageCorners, imageSize: iconSize, boundingSize: iconSize, intrinsicInsets: UIEdgeInsets(), emptyColor: item.presentationData.theme.theme.list.mediaPlaceholderColor)
                        iconImageApply = iconImageLayout(arguments)
                    case let .roundVideo(file):
                        let iconSize = CGSize(width: 40.0, height: 40.0)
                        let imageCorners = ImageCorners(radius: iconSize.width / 2.0)
                        let arguments = TransformImageArguments(corners: imageCorners, imageSize: (file.dimensions ?? PixelDimensions(width: 320, height: 320)).cgSize.aspectFilled(iconSize), boundingSize: iconSize, intrinsicInsets: UIEdgeInsets(), emptyColor: item.presentationData.theme.theme.list.mediaPlaceholderColor)
                        iconImageApply = iconImageLayout(arguments)
                }
            }
            
            if let message = message {
                if currentIconImage != iconImage {
                    if let iconImage = iconImage {
                        switch iconImage {
                            case let .imageRepresentation(media, representation):
                                if let file = media as? TelegramMediaFile {
                                    updateIconImageSignal = chatWebpageSnippetFile(account: item.context.account, mediaReference: FileMediaReference.message(message: MessageReference(message), media: file).abstract, representation: representation)
                                } else if let image = media as? TelegramMediaImage {
                                    updateIconImageSignal = mediaGridMessagePhoto(account: item.context.account, photoReference: ImageMediaReference.message(message: MessageReference(message), media: image))
                                } else {
                                    updateIconImageSignal = .complete()
                                }
                            case let .albumArt(file, albumArt):
                                updateIconImageSignal = playerAlbumArt(postbox: item.context.account.postbox, engine: item.context.engine, fileReference: .message(message: MessageReference(message), media: file), albumArt: albumArt, thumbnail: true, overlayColor: UIColor(white: 0.0, alpha: 0.3), emptyColor: item.presentationData.theme.theme.list.itemAccentColor)
                            case let .roundVideo(file):
                                updateIconImageSignal = mediaGridMessageVideo(postbox: item.context.account.postbox, videoReference: FileMediaReference.message(message: MessageReference(message), media: file), autoFetchFullSizeThumbnail: true, overlayColor: UIColor(white: 0.0, alpha: 0.3))
                        }
                    } else {
                        updateIconImageSignal = .complete()
                    }
                }
            }
            
            var insets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
            if dateHeaderAtBottom, let header = item.header {
                insets.top += header.height
            }
            if !mergedBottom, case .blocks = item.style {
                insets.bottom += 35.0
            }
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: 8.0 * 2.0 + titleNodeLayout.size.height + 3.0 + descriptionNodeLayout.size.height + (textNodeLayout.size.height > 0.0 ? textNodeLayout.size.height + 3.0 : 0.0)), insets: insets)
            
            return (nodeLayout, { animation in
                if let strongSelf = self {
                    if strongSelf.downloadStatusIconNode == nil {
                        strongSelf.downloadStatusIconNode = DownloadIconNode(theme: item.presentationData.theme.theme)
                    }

                    let transition: ContainedViewLayoutTransition
                    if animation.isAnimated && currentItem?.message != nil {
                        transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                    } else {
                        transition = .immediate
                    }
                    
                    strongSelf.restrictionNode.isHidden = !isRestricted
                    
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: nodeLayout.contentSize)
                    strongSelf.contextSourceNode.frame = CGRect(origin: CGPoint(), size: nodeLayout.contentSize)
                    strongSelf.offsetContainerNode.frame = CGRect(origin: CGPoint(), size: nodeLayout.contentSize)
                    strongSelf.contextSourceNode.contentNode.frame = CGRect(origin: CGPoint(), size: nodeLayout.contentSize)
                    strongSelf.restrictionNode.frame = CGRect(origin: CGPoint(), size: nodeLayout.contentSize)
                    
                    let nonExtractedRect = CGRect(origin: CGPoint(), size: CGSize(width: nodeLayout.contentSize.width - 16.0, height: nodeLayout.contentSize.height))
                    let extractedRect = CGRect(origin: CGPoint(), size: nodeLayout.contentSize).insetBy(dx: 16.0 + params.leftInset, dy: 0.0)
                    strongSelf.extractedRect = extractedRect
                    strongSelf.nonExtractedRect = nonExtractedRect
                    
                    if strongSelf.contextSourceNode.isExtractedToContextPreview {
                        strongSelf.extractedBackgroundImageNode.frame = extractedRect
                    } else {
                        strongSelf.extractedBackgroundImageNode.frame = nonExtractedRect
                    }
                    strongSelf.contextSourceNode.contentRect = extractedRect
                    strongSelf.containerNode.isGestureEnabled = item.displayFileInfo
                    
                    strongSelf.currentIsRestricted = isRestricted || item.message == nil
                    strongSelf.currentMedia = selectedMedia
                    strongSelf.message = message
                    strongSelf.context = item.context
                    strongSelf.appliedItem = item
                    strongSelf.layoutParams = params
                    strongSelf.contentSizeValue = nodeLayout.contentSize
                    strongSelf.currentLeftOffset = leftOffset
                    
                    if let _ = updatedTheme {
                        if item.displayBackground {
                            let backgroundNode: ASDisplayNode
                            if let current = strongSelf.backgroundNode {
                                backgroundNode = current
                            } else {
                                backgroundNode = ASDisplayNode()
                                strongSelf.backgroundNode = backgroundNode
                                strongSelf.insertSubnode(backgroundNode, at: 0)
                            }
                            backgroundNode.backgroundColor = item.presentationData.theme.theme.list.itemBlocksBackgroundColor
                        }
                        
                        strongSelf.separatorNode.backgroundColor = item.presentationData.theme.theme.list.itemPlainSeparatorColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.theme.list.itemHighlightedBackgroundColor
                        strongSelf.linearProgressNode?.updateTheme(theme: item.presentationData.theme.theme)
                        
                        strongSelf.restrictionNode.backgroundColor = item.presentationData.theme.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.6)

                        strongSelf.downloadStatusIconNode?.updateTheme(theme: item.presentationData.theme.theme)
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
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -nodeLayout.insets.top - UIScreenPixel), size: CGSize(width: params.width, height: nodeLayout.size.height + UIScreenPixel - nodeLayout.insets.bottom))
                    
                    if let backgroundNode = strongSelf.backgroundNode {
                        backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -nodeLayout.insets.top), size: CGSize(width: params.width, height: nodeLayout.size.height - nodeLayout.insets.bottom))
                    }
                    
                    switch item.style {
                    case .plain:
                        if strongSelf.maskNode.supernode != nil {
                            strongSelf.maskNode.removeFromSupernode()
                        }
                    case .blocks:
                        if strongSelf.maskNode.supernode == nil {
                            strongSelf.addSubnode(strongSelf.maskNode)
                        }
                        
                        let hasCorners = itemListHasRoundedBlockLayout(params)
                        var hasTopCorners = false
                        var hasBottomCorners = false
                        
                        if !mergedTop {
                            hasTopCorners = true
                        }
                        if !mergedBottom {
                            hasBottomCorners = true
                            strongSelf.separatorNode.isHidden = hasCorners
                        } else {
                            strongSelf.separatorNode.isHidden = false
                        }

                        strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.presentationData.theme.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                        if let backgroundNode = strongSelf.backgroundNode {
                            strongSelf.maskNode.frame = backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                        }
                    }
                    
                    transition.updateFrame(node: strongSelf.titleNode, frame: CGRect(origin: CGPoint(x: leftOffset + leftInset, y: 9.0), size: titleNodeLayout.size))
                    let _ = titleNodeApply()
                    
                    var descriptionOffset: CGFloat = 0.0
                    if let resourceStatus = strongSelf.resourceStatus {
                        switch resourceStatus {
                            case .playbackStatus:
                                break
                            case let .fetchStatus(fetchStatus):
                                switch fetchStatus {
                                    case .Remote, .Fetching, .Paused:
                                        descriptionOffset = 14.0
                                    case .Local:
                                        break
                                }
                        }
                    }
                    
                    transition.updateFrame(node: strongSelf.textNode, frame: CGRect(origin: CGPoint(x: leftOffset + leftInset + descriptionOffset, y: strongSelf.titleNode.frame.maxY + 1.0), size: textNodeLayout.size))
                    let _ = textNodeApply()
                    
                    transition.updateFrame(node: strongSelf.descriptionNode, frame: CGRect(origin: CGPoint(x: leftOffset + leftInset + descriptionOffset, y: strongSelf.titleNode.frame.maxY + 1.0 + (textNodeLayout.size.height > 0.0 ? textNodeLayout.size.height + 3.0 : 0.0)), size: descriptionNodeLayout.size))
                    let _ = descriptionNodeApply()
                    
                    let _ = dateNodeApply()
                    transition.updateFrame(node: strongSelf.dateNode, frame: CGRect(origin: CGPoint(x: params.width - rightInset - dateNodeLayout.size.width, y: 11.0), size: dateNodeLayout.size))
                    strongSelf.dateNode.isHidden = !item.isGlobalSearchResult
                    
                    let iconSize = CGSize(width: 40.0, height: 40.0)
                    let iconFrame = CGRect(origin: CGPoint(x: params.leftInset + leftOffset + 12.0, y: 8.0), size: iconSize)
                    transition.updateFrame(node: strongSelf.extensionIconNode, frame: iconFrame)
                    strongSelf.extensionIconNode.image = extensionIconImage
                    transition.updateFrame(node: strongSelf.extensionIconText, frame: CGRect(origin: CGPoint(x: iconFrame.minX + floor((iconFrame.width - extensionTextLayout.size.width) / 2.0), y: iconFrame.minY + 7.0 + floor((iconFrame.height - extensionTextLayout.size.height) / 2.0)), size: extensionTextLayout.size))
                    
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

                    if let downloadStatusIconNode = strongSelf.downloadStatusIconNode {
                        transition.updateFrame(node: downloadStatusIconNode, frame: CGRect(origin: CGPoint(x: leftOffset + leftInset - 3.0, y: strongSelf.descriptionNode.frame.minY + floor((strongSelf.descriptionNode.frame.height - 18.0) / 2.0)), size: CGSize(width: 18.0, height: 18.0)))
                    }
                    
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
                    
                    if item.message == nil {
                        let shimmerNode: ShimmerEffectNode
                        if let current = strongSelf.placeholderNode {
                            shimmerNode = current
                        } else {
                            shimmerNode = ShimmerEffectNode()
                            strongSelf.placeholderNode = shimmerNode
                            if strongSelf.separatorNode.supernode != nil {
                                strongSelf.insertSubnode(shimmerNode, belowSubnode: strongSelf.separatorNode)
                            } else {
                                strongSelf.addSubnode(shimmerNode)
                            }
                        }
                        shimmerNode.frame = CGRect(origin: CGPoint(), size: nodeLayout.contentSize)
                        if let (rect, size) = strongSelf.absoluteLocation {
                            shimmerNode.updateAbsoluteRect(rect, within: size)
                        }

                        var shapes: [ShimmerEffectNode.Shape] = []

                        let titleLineWidth: CGFloat = 120.0
                        let descriptionLineWidth: CGFloat = 60.0
                        let lineDiameter: CGFloat = 8.0

                        let titleFrame = strongSelf.titleNode.frame
                        shapes.append(.roundedRectLine(startPoint: CGPoint(x: titleFrame.minX, y: titleFrame.minY + floor((titleFrame.height - lineDiameter) / 2.0)), width: titleLineWidth, diameter: lineDiameter))
                        
                        let descriptionFrame = strongSelf.descriptionNode.frame
                        shapes.append(.roundedRectLine(startPoint: CGPoint(x: descriptionFrame.minX, y: descriptionFrame.minY + floor((descriptionFrame.height - lineDiameter) / 2.0)), width: descriptionLineWidth, diameter: lineDiameter))
                        
                        if let media = selectedMedia as? TelegramMediaFile, media.isInstantVideo {
                            shapes.append(.circle(iconFrame))
                        } else {
                            shapes.append(.roundedRect(rect: iconFrame, cornerRadius: 6.0))
                        }
                            
                        shimmerNode.update(backgroundColor: item.presentationData.theme.theme.list.itemBlocksBackgroundColor, foregroundColor: item.presentationData.theme.theme.list.mediaPlaceholderColor, shimmeringColor: item.presentationData.theme.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4), shapes: shapes, size: nodeLayout.contentSize)
                    } else if let shimmerNode = strongSelf.placeholderNode {
                        strongSelf.placeholderNode = nil
                        shimmerNode.removeFromSupernode()
                    }
                }
            })
        }
    }
    
    private func updateStatus(transition: ContainedViewLayoutTransition) {
        guard let item = self.item, let media = self.currentMedia, let _ = self.fetchStatus, let status = self.resourceStatus, let layoutParams = self.layoutParams, let contentSize = self.contentSizeValue else {
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
            iconStatusBackgroundColor = item.presentationData.theme.theme.list.itemAccentColor
            iconStatusForegroundColor = item.presentationData.theme.theme.list.itemCheckColors.foregroundColor
        } else if isAudio {
            iconStatusBackgroundColor = item.presentationData.theme.theme.list.itemAccentColor
            iconStatusForegroundColor = item.presentationData.theme.theme.list.itemCheckColors.foregroundColor
        }
        
        if !isAudio && !isInstantVideo {
            self.updateProgressFrame(size: contentSize, leftInset: layoutParams.leftInset, rightInset: layoutParams.rightInset, transition: .immediate)
        } else {
            if item.isDownloadList {
                self.updateProgressFrame(size: contentSize, leftInset: layoutParams.leftInset, rightInset: layoutParams.rightInset, transition: .immediate)
            }
            switch status {
            case let .fetchStatus(fetchStatus):
                switch fetchStatus {
                case let .Fetching(_, progress):
                    if item.isDownloadList {
                        iconStatusState = .progress(value: CGFloat(progress), cancelEnabled: true, appearance: nil)
                    }
                case .Local:
                    if isAudio || isInstantVideo {
                        iconStatusState = .play
                    }
                case .Remote, .Paused:
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
        self.iconStatusNode.overlayForegroundNodeColor = .white
        self.iconStatusNode.transitionToState(iconStatusState)
    }
    
    override public func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        if highlighted, let item = self.item, case .none = item.selection {
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                if let backgroundNode = self.backgroundNode {
                    self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: backgroundNode)
                } else {
                    self.insertSubnode(self.highlightedBackgroundNode, at: 0)
                }
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
    
    override public func transitionNode(id: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        if let item = self.item, let message = item.message, message.id == id, self.iconImageNode.supernode != nil {
            let iconImageNode = self.iconImageNode
            return (self.iconImageNode, self.iconImageNode.bounds, { [weak iconImageNode] in
                return (iconImageNode?.view.snapshotContentTree(unhide: true), nil)
            })
        }
        return nil
    }
    
    override public func updateHiddenMedia() {
        if let interaction = self.interaction, let item = self.item, let message = item.message, interaction.getHiddenMedia()[message.id] != nil {
            self.iconImageNode.isHidden = true
        } else {
            self.iconImageNode.isHidden = false
        }
    }
    
    override public func updateSelectionState(animated: Bool) {
    }

    public func cancelPreviewGesture() {
        self.containerNode.cancelGesture()
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
            }
            
            if item.isDownloadList, let fetchStatus = self.fetchStatus {
                maybeFetchStatus = fetchStatus
            }
            
            switch maybeFetchStatus {
            case .Fetching(_, let progress), .Paused(let progress):
                if let file = self.currentMedia as? TelegramMediaFile, let size = file.size {
                    downloadingString = "\(dataSizeString(Int(Float(size) * progress), forceDecimal: true, formatting: DataSizeStringFormatting(chatPresentationData: item.presentationData))) / \(dataSizeString(size, forceDecimal: true, formatting: DataSizeStringFormatting(chatPresentationData: item.presentationData)))"
                }
                descriptionOffset = 14.0
            case .Remote:
                descriptionOffset = 14.0
            case .Local:
                break
            }
            
            switch maybeFetchStatus {
                case .Fetching(_, let progress), .Paused(let progress):
                    let progressFrame = CGRect(x: self.currentLeftOffset + leftInset + 65.0, y: size.height - 3.0, width: floor((size.width - 65.0 - leftInset - rightInset)), height: 3.0)
                    let linearProgressNode: LinearProgressNode
                    if let current = self.linearProgressNode {
                        linearProgressNode = current
                    } else {
                        linearProgressNode = LinearProgressNode()
                        linearProgressNode.updateTheme(theme: item.presentationData.theme.theme)
                        self.linearProgressNode = linearProgressNode
                        self.addSubnode(linearProgressNode)
                    }
                    transition.updateFrame(node: linearProgressNode, frame: progressFrame)
                    linearProgressNode.updateProgress(value: CGFloat(progress), completion: {})
                    
                    var animated = true
                    if let downloadStatusIconNode = self.downloadStatusIconNode {
                        if downloadStatusIconNode.supernode == nil {
                            animated = false
                            self.offsetContainerNode.addSubnode(downloadStatusIconNode)
                        }
                        if case .Paused = maybeFetchStatus {
                            downloadStatusIconNode.enqueueState(.download, animated: animated)
                        } else {
                            downloadStatusIconNode.enqueueState(.pause, animated: animated)
                        }
                    }
                case .Local:
                    if let linearProgressNode = self.linearProgressNode {
                        self.linearProgressNode = nil
                        linearProgressNode.updateProgress(value: 1.0, completion: { [weak linearProgressNode] in
                            linearProgressNode?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { _ in
                                linearProgressNode?.removeFromSupernode()
                            })
                        })
                    }
                    if let downloadStatusIconNode = self.downloadStatusIconNode {
                        if downloadStatusIconNode.supernode != nil {
                            downloadStatusIconNode.removeFromSupernode()
                        }
                    }
                case .Remote:
                    if let linearProgressNode = self.linearProgressNode {
                        self.linearProgressNode = nil
                        linearProgressNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak linearProgressNode] _ in
                            linearProgressNode?.removeFromSupernode()
                        })
                    }
                    if let downloadStatusIconNode = self.downloadStatusIconNode {
                        var animated = true
                        if downloadStatusIconNode.supernode == nil {
                            animated = false
                            self.offsetContainerNode.addSubnode(downloadStatusIconNode)
                        }
                        downloadStatusIconNode.enqueueState(.download, animated: animated)
                    }
                }
        } else {
            if let linearProgressNode = self.linearProgressNode {
                self.linearProgressNode = nil
                linearProgressNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak linearProgressNode] _ in
                    linearProgressNode?.removeFromSupernode()
                })
            }
            if let downloadStatusIconNode = self.downloadStatusIconNode {
                if downloadStatusIconNode.supernode != nil {
                    downloadStatusIconNode.removeFromSupernode()
                }
            }
        }
        
        var descriptionFrame = self.descriptionNode.frame
        let originX = self.titleNode.frame.minX + descriptionOffset
        if !descriptionFrame.origin.x.isEqual(to: originX) {
            descriptionFrame.origin.x = originX
            transition.updateFrame(node: self.descriptionNode, frame: descriptionFrame)
        }
        
        let alphaTransition: ContainedViewLayoutTransition
        if item.isDownloadList {
            alphaTransition = .immediate
        } else {
            alphaTransition = .animated(duration: 0.3, curve: .easeInOut)
        }
        if downloadingString != nil {
            alphaTransition.updateAlpha(node: self.descriptionProgressNode, alpha: 1.0)
            alphaTransition.updateAlpha(node: self.descriptionNode, alpha: 0.0)
        } else {
            alphaTransition.updateAlpha(node: self.descriptionProgressNode, alpha: 0.0)
            alphaTransition.updateAlpha(node: self.descriptionNode, alpha: 1.0)
        }
        
        let descriptionFont = Font.with(size: floor(item.presentationData.fontSize.baseDisplaySize * 13.0 / 17.0), design: .regular, weight: .regular, traits: [.monospacedNumbers])
        self.descriptionProgressNode.attributedText = NSAttributedString(string: downloadingString ?? "", font: descriptionFont, textColor: item.presentationData.theme.theme.list.itemSecondaryTextColor)
        let descriptionSize = self.descriptionProgressNode.updateLayout(CGSize(width: size.width - 14.0, height: size.height))
        transition.updateFrame(node: self.descriptionProgressNode, frame: CGRect(origin: self.descriptionNode.frame.origin, size: descriptionSize))
    }
    
    public func activateMedia() {
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
                        case .Remote, .Paused:
                            if let fetch = self.fetchControls.with({ return $0?.fetch }) {
                                fetch()
                            }
                        case .Local:
                            if let item = self.item, let message = item.message, let interaction = self.interaction {
                                let _ = interaction.openMessage(message, .default)
                            }
                        }
                case .playbackStatus:
                    if let context = self.context {
                        context.sharedContext.mediaManager.playlistControl(.playback(.togglePlayPause), type: nil)
                    }
            }
        }
    }
    
    override public func headers() -> [ListViewItemHeader]? {
        return self.item?.header.flatMap { [$0] }
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
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
            case .Remote, .Paused:
                if let fetch = self.fetchControls.with({ return $0?.fetch }) {
                    fetch()
                }
            case .Local:
                break
        }
    }
    
    public override var canBeSelected: Bool {
        return !self.currentIsRestricted
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

private enum DownloadIconNodeState: Equatable {
    case download
    case pause
}

private func generateDownloadIcon(color: UIColor) -> UIImage? {
    let animation = ManagedAnimationNode(size: CGSize(width: 18.0, height: 18.0))
    animation.customColor = color
    animation.trackTo(item: ManagedAnimationItem(source: .local("anim_shareddownload"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.01))
    return animation.image
}

private final class DownloadIconNode: ASImageNode {
    private var customColor: UIColor
    private let duration: Double = 0.3
    private var iconState: DownloadIconNodeState = .download
    private var animationNode: ManagedAnimationNode?
    
    init(theme: PresentationTheme) {
        self.customColor = theme.list.itemAccentColor

        super.init()

        self.image = PresentationResourcesChat.sharedMediaFileDownloadStartIcon(theme, generate: {
            return generateDownloadIcon(color: theme.list.itemAccentColor)
        })
        self.contentMode = .center
    }

    func updateTheme(theme: PresentationTheme) {
        if self.image != nil {
            self.image = PresentationResourcesChat.sharedMediaFileDownloadStartIcon(theme, generate: {
                return generateDownloadIcon(color: theme.list.itemAccentColor)
            })
        }
        self.customColor = theme.list.itemAccentColor
        self.animationNode?.customColor = self.customColor
    }
    
    func enqueueState(_ state: DownloadIconNodeState, animated: Bool) {
        guard self.iconState != state else {
            return
        }

        if self.animationNode == nil {
            let animationNode = ManagedAnimationNode(size: CGSize(width: 18.0, height: 18.0))
            self.animationNode = animationNode
            animationNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 18.0, height: 18.0))
            animationNode.trackTo(item: ManagedAnimationItem(source: .local("anim_shareddownload"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.01))
            self.addSubnode(animationNode)
            self.image = nil
        }

        guard let animationNode = self.animationNode else {
            return
        }
        
        let previousState = self.iconState
        self.iconState = state
        
        switch previousState {
            case .pause:
                switch state {
                    case .download:
                        if animated {
                            animationNode.trackTo(item: ManagedAnimationItem(source: .local("anim_shareddownload"), frames: .range(startFrame: 100, endFrame: 120), duration: self.duration))
                        } else {
                            animationNode.trackTo(item: ManagedAnimationItem(source: .local("anim_shareddownload"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.01))
                        }
                    case .pause:
                        break
                }
            case .download:
                switch state {
                    case .pause:
                        if animated {
                            animationNode.trackTo(item: ManagedAnimationItem(source: .local("anim_shareddownload"), frames: .range(startFrame: 0, endFrame: 20), duration: self.duration))
                        } else {
                            animationNode.trackTo(item: ManagedAnimationItem(source: .local("anim_shareddownload"), frames: .range(startFrame: 60, endFrame: 60), duration: 0.01))
                        }
                    case .download:
                        break
                }
        }
    }
}
