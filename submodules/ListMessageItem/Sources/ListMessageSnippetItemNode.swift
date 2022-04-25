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
import TextFormat
import PhotoResources
import WebsiteType
import UrlHandling
import UrlWhitelist
import AccountContext
import TelegramStringFormatting
import WallpaperResources

private let iconFont = Font.with(size: 30.0, design: .round, weight: .bold)

private let iconTextBackgroundImage = generateStretchableFilledCircleImage(radius: 6.0, color: UIColor(rgb: 0xFF9500))

public final class ListMessageSnippetItemNode: ListMessageNode {
    private let contextSourceNode: ContextExtractedContentContainingNode
    private let containerNode: ContextControllerSourceNode
    private let extractedBackgroundImageNode: ASImageNode
    private let offsetContainerNode: ASDisplayNode
    
    private var extractedRect: CGRect?
    private var nonExtractedRect: CGRect?
    
    private let highlightedBackgroundNode: ASDisplayNode
    public let separatorNode: ASDisplayNode
    
    private var selectionNode: ItemListSelectableControlNode?
    
    public let titleNode: TextNode
    let descriptionNode: TextNode
    public let dateNode: TextNode
    private let instantViewIconNode: ASImageNode
    public let linkNode: TextNode
    private var linkHighlightingNode: LinkHighlightingNode?
    public let authorNode: TextNode
    
    private let iconTextBackgroundNode: ASImageNode
    private let iconTextNode: TextNode
    private let iconImageNode: TransformImageNode
    
    private var currentIconImageRepresentation: TelegramMediaImageRepresentation?
    private var currentMedia: Media?
    public var currentPrimaryUrl: String?
    private var currentIsInstantView: Bool?
    
    private var appliedItem: ListMessageItem?
    
    private var cachedChatListSearchResult: CachedChatListSearchResult?
    
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
        
        self.dateNode = TextNode()
        self.dateNode.isUserInteractionEnabled = false
        
        self.instantViewIconNode = ASImageNode()
        self.instantViewIconNode.isLayerBacked = true
        self.instantViewIconNode.displaysAsynchronously = false
        self.instantViewIconNode.displayWithoutProcessing = true
        self.linkNode = TextNode()
        self.linkNode.isUserInteractionEnabled = false
        
        self.iconTextBackgroundNode = ASImageNode()
        self.iconTextBackgroundNode.isLayerBacked = true
        self.iconTextBackgroundNode.displaysAsynchronously = false
        self.iconTextBackgroundNode.displayWithoutProcessing = true
        
        self.iconTextNode = TextNode()
        self.iconTextNode.isUserInteractionEnabled = false
        
        self.iconImageNode = TransformImageNode()
        self.iconImageNode.displaysAsynchronously = false
        
        self.authorNode = TextNode()
        self.authorNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.separatorNode)
        
        self.containerNode.addSubnode(self.contextSourceNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        self.addSubnode(self.containerNode)
        
        self.contextSourceNode.contentNode.addSubnode(self.extractedBackgroundImageNode)
        self.contextSourceNode.contentNode.addSubnode(self.offsetContainerNode)
        self.offsetContainerNode.addSubnode(self.titleNode)
        self.offsetContainerNode.addSubnode(self.descriptionNode)
        self.offsetContainerNode.addSubnode(self.dateNode)
        self.offsetContainerNode.addSubnode(self.linkNode)
        self.offsetContainerNode.addSubnode(self.instantViewIconNode)
        self.offsetContainerNode.addSubnode(self.iconImageNode)
        self.offsetContainerNode.addSubnode(self.authorNode)
        
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let item = strongSelf.item, let message = item.message else {
                return
            }
            
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
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { [weak self] point in
            if let strongSelf = self, let _ = strongSelf.urlAtPoint(point) {
                return .waitForSingleTap
            }
            return .fail
        }
        recognizer.highlight = { [weak self] point in
            if let strongSelf = self {
                strongSelf.updateTouchesAtPoint(point)
            }
        }
        self.view.addGestureRecognizer(recognizer)
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
    
    override public func asyncLayout() -> (_ item: ListMessageItem, _ params: ListViewItemLayoutParams, _ mergedTop: Bool, _ mergedBottom: Bool, _ dateHeaderAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let titleNodeMakeLayout = TextNode.asyncLayout(self.titleNode)
        let descriptionNodeMakeLayout = TextNode.asyncLayout(self.descriptionNode)
        let linkNodeMakeLayout = TextNode.asyncLayout(self.linkNode)
        let dateNodeMakeLayout = TextNode.asyncLayout(self.dateNode)
        let iconTextMakeLayout = TextNode.asyncLayout(self.iconTextNode)
        let iconImageLayout = self.iconImageNode.asyncLayout()
        let authorNodeMakeLayout = TextNode.asyncLayout(self.authorNode)
    
        let currentIconImageRepresentation = self.currentIconImageRepresentation
        
        let currentItem = self.appliedItem
        let currentChatListSearchResult = self.cachedChatListSearchResult
        
        let selectionNodeLayout = ItemListSelectableControlNode.asyncLayout(self.selectionNode)
        
        return { [weak self] item, params, _, _, dateHeaderAtBottom in
            var updatedTheme: PresentationTheme?
            
            if currentItem?.presentationData.theme.theme !== item.presentationData.theme.theme {
                updatedTheme = item.presentationData.theme.theme
            }
            
            let titleFont = Font.semibold(floor(item.presentationData.fontSize.baseDisplaySize * 16.0 / 17.0))
            let descriptionFont = Font.regular(floor(item.presentationData.fontSize.baseDisplaySize * 14.0 / 17.0))
            let dateFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 14.0 / 17.0))
            let authorFont = Font.regular(floor(item.presentationData.fontSize.baseDisplaySize * 14.0 / 17.0))
            
            let leftInset: CGFloat = 65.0 + params.leftInset
            
            var leftOffset: CGFloat = 0.0
            var selectionNodeWidthAndApply: (CGFloat, (CGSize, Bool) -> ItemListSelectableControlNode)?
            if case let .selectable(selected) = item.selection {
                let (selectionWidth, selectionApply) = selectionNodeLayout(item.presentationData.theme.theme.list.itemCheckColors.strokeColor, item.presentationData.theme.theme.list.itemCheckColors.fillColor, item.presentationData.theme.theme.list.itemCheckColors.foregroundColor, selected, false)
                selectionNodeWidthAndApply = (selectionWidth, selectionApply)
                leftOffset += selectionWidth
            }
            
            var title: NSAttributedString?
            var descriptionText: NSAttributedString?
            var linkText: NSAttributedString?
            var iconText: NSAttributedString?
            
            var iconImageReferenceAndRepresentation: (AnyMediaReference, TelegramMediaImageRepresentation)?
            var updateIconImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            
            let applyIconTextBackgroundImage = iconTextBackgroundImage
            
            var primaryUrl: String?
            
            var isInstantView = false

            var previewWallpaper: TelegramWallpaper?
            var previewWallpaperFileReference: FileMediaReference?
            
            var selectedMedia: TelegramMediaWebpage?
            var processed = false
            
            if let message = item.message {
                for media in message.media {
                    if let webpage = media as? TelegramMediaWebpage {
                        selectedMedia = webpage
                        
                        if case let .Loaded(content) = webpage.content {
                            if content.instantPage != nil && instantPageType(of: content) != .album {
                                isInstantView = true
                            }
                            
                            let (parsedUrl, _) = parseUrl(url: content.url, wasConcealed: false)
                            
                            primaryUrl = parsedUrl
                            
                            processed = true
                            var hostName: String = ""
                            if let url = URL(string: parsedUrl), let host = url.host, !host.isEmpty {
                                hostName = host
                                iconText = NSAttributedString(string: host[..<host.index(after: host.startIndex)].uppercased(), font: iconFont, textColor: UIColor.white)
                            }
                            
                            title = NSAttributedString(string: content.title ?? content.websiteName ?? hostName, font: titleFont, textColor: item.presentationData.theme.theme.list.itemPrimaryTextColor)
                            
                            if let image = content.image {
                                if let representation = imageRepresentationLargerThan(image.representations, size: PixelDimensions(width: 80, height: 80)) {
                                    iconImageReferenceAndRepresentation = (.message(message: MessageReference(message), media: image), representation)
                                }
                            } else if let file = content.file {
                                if content.type == "telegram_background" {
                                    if let wallpaper = parseWallpaperUrl(content.url) {
                                        switch wallpaper {
                                        case let .slug(slug, _, colors, intensity, angle):
                                            previewWallpaperFileReference = .message(message: MessageReference(message), media: file)
                                            previewWallpaper = .file(TelegramWallpaper.File(id: file.fileId.id, accessHash: 0, isCreator: false, isDefault: false, isPattern: true, isDark: false, slug: slug, file: file, settings: WallpaperSettings(blur: false, motion: false, colors: colors, intensity: intensity, rotation: angle)))
                                        default:
                                            break
                                        }
                                    }
                                }
                                if let representation = smallestImageRepresentation(file.previewRepresentations) {
                                    iconImageReferenceAndRepresentation = (.message(message: MessageReference(message), media: file), representation)
                                }
                            }
                            
                            let mutableDescriptionText = NSMutableAttributedString()
                            if let text = content.text, !item.isGlobalSearchResult {
                                mutableDescriptionText.append(NSAttributedString(string: text + "\n", font: descriptionFont, textColor: item.presentationData.theme.theme.list.itemSecondaryTextColor))
                            }
                            
                            let plainUrlString = NSAttributedString(string: content.url.replacingOccurrences(of: "https://", with: ""), font: descriptionFont, textColor: item.presentationData.theme.theme.list.itemAccentColor)
                            let urlString = NSMutableAttributedString()
                            urlString.append(plainUrlString)
                            urlString.addAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.URL), value: content.url, range: NSMakeRange(0, urlString.length))
                            linkText = urlString
                            
                            descriptionText = mutableDescriptionText
                        }
                        
                        break
                    }
                }
            
                if !processed {
                    var messageEntities: [MessageTextEntity]?
                    for attribute in message.attributes {
                        if let attribute = attribute as? TextEntitiesMessageAttribute {
                            messageEntities = attribute.entities
                            break
                        }
                    }
                    
                    for media in message.media {
                        if let image = media as? TelegramMediaImage {
                            if let representation = imageRepresentationLargerThan(image.representations, size: PixelDimensions(width: 80, height: 80)) {
                                iconImageReferenceAndRepresentation = (.message(message: MessageReference(message), media: image), representation)
                            }
                            break
                        }
                        if let file = media as? TelegramMediaFile {
                            if let representation = smallestImageRepresentation(file.previewRepresentations) {
                                iconImageReferenceAndRepresentation = (.message(message: MessageReference(message), media: file), representation)
                            }
                            break
                        }
                    }
                    
                    var entities: [MessageTextEntity]?
                    
                    entities = messageEntities
                    if entities == nil {
                        let parsedEntities = generateTextEntities(message.text, enabledTypes: .all)
                        if !parsedEntities.isEmpty {
                            entities = parsedEntities
                        }
                    }
                    
                    if let entities = entities {
                        loop: for entity in entities {
                            switch entity.type {
                                case .Url, .Email:
                                    var range = NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound)
                                    let nsString = message.text as NSString
                                    if range.location + range.length > nsString.length {
                                        range.location = max(0, nsString.length - range.length)
                                        range.length = nsString.length - range.location
                                    }
                                    let tempUrlString = nsString.substring(with: range)
                                    
                                    var (urlString, concealed) = parseUrl(url: tempUrlString, wasConcealed: false)
                                    
                                    let rawUrlString = urlString
                                    var parsedUrl = URL(string: urlString)
                                    if (parsedUrl == nil || parsedUrl!.host == nil || parsedUrl!.host!.isEmpty) && !urlString.contains("@") {
                                        urlString = "http://" + urlString
                                        parsedUrl = URL(string: urlString)
                                    }
                                    var host: String? = concealed ? urlString : parsedUrl?.host
                                    if host == nil {
                                        host = urlString
                                    }
                                    if let url = parsedUrl, let host = host {
                                        primaryUrl = urlString
                                        if url.path.hasPrefix("/addstickers/") {
                                            title = NSAttributedString(string: urlString, font: titleFont, textColor: item.presentationData.theme.theme.list.itemPrimaryTextColor)
                                            
                                            iconText = NSAttributedString(string: "S", font: iconFont, textColor: UIColor.white)
                                        } else {
                                            iconText = NSAttributedString(string: host[..<host.index(after: host.startIndex)].uppercased(), font: iconFont, textColor: UIColor.white)
                                            
                                            title = NSAttributedString(string: host, font: titleFont, textColor: item.presentationData.theme.theme.list.itemPrimaryTextColor)
                                        }
                                        let mutableDescriptionText = NSMutableAttributedString()
                                        
                                        let (messageTextUrl, _) = parseUrl(url: message.text, wasConcealed: false)
                                        
                                        if messageTextUrl != rawUrlString, !item.isGlobalSearchResult {
                                            mutableDescriptionText.append(NSAttributedString(string: message.text + "\n", font: descriptionFont, textColor: item.presentationData.theme.theme.list.itemSecondaryTextColor))
                                        }
                                        
                                        let urlAttributedString = NSMutableAttributedString()
                                        urlAttributedString.append(NSAttributedString(string: urlString.replacingOccurrences(of: "https://", with: ""), font: descriptionFont, textColor: item.presentationData.theme.theme.list.itemAccentColor))
                                        if item.presentationData.theme.theme.list.itemAccentColor.isEqual(item.presentationData.theme.theme.list.itemPrimaryTextColor) {
                                            urlAttributedString.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: NSMakeRange(0, urlAttributedString.length))
                                        }
                                        urlAttributedString.addAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.URL), value: urlString, range: NSMakeRange(0, urlAttributedString.length))
                                        linkText = urlAttributedString

                                        descriptionText = mutableDescriptionText
                                    }
                                    break loop
                                case let .TextUrl(url):
                                    var range = NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound)
                                    let nsString = message.text as NSString
                                    if range.location + range.length > nsString.length {
                                        range.location = max(0, nsString.length - range.length)
                                        range.length = nsString.length - range.location
                                    }
                                    let tempTitleString = (nsString.substring(with: range) as String).trimmingCharacters(in: .whitespacesAndNewlines)
                                   
                                    var (urlString, concealed) = parseUrl(url: url, wasConcealed: false)
                                    let rawUrlString = urlString
                                    var parsedUrl = URL(string: urlString)
                                    if (parsedUrl == nil || parsedUrl!.host == nil || parsedUrl!.host!.isEmpty) && !urlString.contains("@") {
                                        urlString = "http://" + urlString
                                        parsedUrl = URL(string: urlString)
                                    }
                                    let host: String? = concealed ? urlString : parsedUrl?.host
                                    if let url = parsedUrl, let host = host {
                                        primaryUrl = urlString
                                        title = NSAttributedString(string: tempTitleString as String, font: titleFont, textColor: item.presentationData.theme.theme.list.itemPrimaryTextColor)
                                        if url.path.hasPrefix("/addstickers/") {
                                            iconText = NSAttributedString(string: "S", font: iconFont, textColor: UIColor.white)
                                        } else {
                                            iconText = NSAttributedString(string: host[..<host.index(after: host.startIndex)].uppercased(), font: iconFont, textColor: UIColor.white)
                                        }
                                        let mutableDescriptionText = NSMutableAttributedString()
                                        
                                        let (messageTextUrl, _) = parseUrl(url: message.text, wasConcealed: false)
                                        
                                        if messageTextUrl != rawUrlString, !item.isGlobalSearchResult {
                                            mutableDescriptionText.append(NSAttributedString(string: message.text + "\n", font: descriptionFont, textColor: item.presentationData.theme.theme.list.itemSecondaryTextColor))
                                        }
                                        
                                        let urlAttributedString = NSMutableAttributedString()
                                        urlAttributedString.append(NSAttributedString(string: urlString.replacingOccurrences(of: "https://", with: ""), font: descriptionFont, textColor: item.presentationData.theme.theme.list.itemAccentColor))
                                        if item.presentationData.theme.theme.list.itemAccentColor.isEqual(item.presentationData.theme.theme.list.itemPrimaryTextColor) {
                                            urlAttributedString.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue as NSNumber, range: NSMakeRange(0, urlAttributedString.length))
                                        }
                                        urlAttributedString.addAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.URL), value: urlString, range: NSMakeRange(0, urlAttributedString.length))
                                        linkText = urlAttributedString
                                        
                                        descriptionText = mutableDescriptionText
                                    }
                                    break loop
                                default:
                                    break
                            }
                        }
                    }
                }
            }
            
            var chatListSearchResult: CachedChatListSearchResult?
            if let searchQuery = item.interaction.searchTextHighightState, let message = item.message {
                if let cached = currentChatListSearchResult, cached.matches(text: message.text, searchQuery: searchQuery) {
                    chatListSearchResult = cached
                } else {
                    let (ranges, text) = findSubstringRanges(in: message.text, query: searchQuery)
                    chatListSearchResult = CachedChatListSearchResult(text: text, searchQuery: searchQuery, resultRanges: ranges)
                }
            } else {
                chatListSearchResult = nil
            }
            
            var descriptionMaxNumberOfLines = 3
            if let chatListSearchResult = chatListSearchResult, let firstRange = chatListSearchResult.resultRanges.first, let message = item.message {
                var text = NSMutableAttributedString(string: message.text, font: descriptionFont, textColor: item.presentationData.theme.theme.list.itemSecondaryTextColor)
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
                
                descriptionText = text
                descriptionMaxNumberOfLines = 2
            }
            
            let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
            let dateText = stringForRelativeTimestamp(strings: item.presentationData.strings, relativeTimestamp: item.message?.timestamp ?? 0, relativeTo: timestamp, dateTimeFormat: item.presentationData.dateTimeFormat)
            let dateAttributedString = NSAttributedString(string: dateText, font: dateFont, textColor: item.presentationData.theme.theme.list.itemSecondaryTextColor)
            
            let (dateNodeLayout, dateNodeApply) = dateNodeMakeLayout(TextNodeLayoutArguments(attributedString: dateAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - params.rightInset - 12.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (titleNodeLayout, titleNodeApply) = titleNodeMakeLayout(TextNodeLayoutArguments(attributedString: title, backgroundColor: nil, maximumNumberOfLines: 2, truncationType: .middle, constrainedSize: CGSize(width: params.width - leftInset - leftOffset - 8.0 - params.rightInset - 16.0 - dateNodeLayout.size.width, height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (descriptionNodeLayout, descriptionNodeApply) = descriptionNodeMakeLayout(TextNodeLayoutArguments(attributedString: descriptionText, backgroundColor: nil, maximumNumberOfLines: descriptionMaxNumberOfLines, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 8.0 - params.rightInset - 16.0 - 8.0, height: CGFloat.infinity), alignment: .natural, lineSpacing: 0.3, cutout: nil, insets: UIEdgeInsets(top: 1.0, left: 1.0, bottom: 1.0, right: 1.0)))
            
            let (linkNodeLayout, linkNodeApply) = linkNodeMakeLayout(TextNodeLayoutArguments(attributedString: linkText, backgroundColor: nil, maximumNumberOfLines: 4, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 8.0 - params.rightInset - 16.0 - 8.0, height: CGFloat.infinity), alignment: .natural, lineSpacing: 0.3, cutout: isInstantView ? TextNodeCutout(topLeft: CGSize(width: 14.0, height: 8.0)) : nil, insets: UIEdgeInsets(top: 1.0, left: 1.0, bottom: 1.0, right: 1.0)))
            var instantViewImage: UIImage?
            if isInstantView {
                 instantViewImage = PresentationResourcesChat.sharedMediaInstantViewIcon(item.presentationData.theme.theme)
            }
            
            let (iconTextLayout, iconTextApply) = iconTextMakeLayout(TextNodeLayoutArguments(attributedString: iconText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 38.0, height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var iconImageApply: (() -> Void)?
            if let iconImageReferenceAndRepresentation = iconImageReferenceAndRepresentation {
                let iconSize = CGSize(width: 40.0, height: 40.0)
                let imageCorners = ImageCorners(radius: 6.0)
                let arguments = TransformImageArguments(corners: imageCorners, imageSize: iconImageReferenceAndRepresentation.1.dimensions.cgSize.aspectFilled(iconSize), boundingSize: iconSize, intrinsicInsets: UIEdgeInsets(), emptyColor: item.presentationData.theme.theme.list.mediaPlaceholderColor)
                iconImageApply = iconImageLayout(arguments)
            }
            
            if currentIconImageRepresentation != iconImageReferenceAndRepresentation?.1 {
                if let previewWallpaper = previewWallpaper, let fileReference = previewWallpaperFileReference {
                    updateIconImageSignal = wallpaperThumbnail(account: item.context.account, accountManager: item.context.sharedContext.accountManager, fileReference: fileReference, wallpaper: previewWallpaper, synchronousLoad: false)
                } else if let iconImageReferenceAndRepresentation = iconImageReferenceAndRepresentation {
                    if let imageReference = iconImageReferenceAndRepresentation.0.concrete(TelegramMediaImage.self) {
                        updateIconImageSignal = chatWebpageSnippetPhoto(account: item.context.account, photoReference: imageReference)
                    } else if let fileReference = iconImageReferenceAndRepresentation.0.concrete(TelegramMediaFile.self) {
                        updateIconImageSignal = chatWebpageSnippetFile(account: item.context.account, mediaReference: fileReference.abstract, representation: iconImageReferenceAndRepresentation.1)
                    }
                } else {
                    updateIconImageSignal = .complete()
                }
            }
            
            var authorString = ""
            if item.isGlobalSearchResult, let message = item.message {
                authorString = stringForFullAuthorName(message: EngineMessage(message), strings: item.presentationData.strings, nameDisplayOrder: item.presentationData.nameDisplayOrder, accountPeerId: item.context.account.peerId)
            }
            
            let authorText = NSAttributedString(string: authorString, font: authorFont, textColor: item.presentationData.theme.theme.list.itemSecondaryTextColor)
            
            let (authorNodeLayout, authorNodeApply) = authorNodeMakeLayout(TextNodeLayoutArguments(attributedString: authorText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - params.rightInset - 30.0, height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var contentHeight = 9.0 + titleNodeLayout.size.height + 10.0 + descriptionNodeLayout.size.height + linkNodeLayout.size.height
            if item.isGlobalSearchResult {
                contentHeight += authorNodeLayout.size.height
            }
            
            var insets = UIEdgeInsets()
            if dateHeaderAtBottom, let header = item.header {
                insets.top += header.height
            }
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: contentHeight), insets: insets)
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
                    strongSelf.contextSourceNode.contentNode.frame = CGRect(origin: CGPoint(), size: nodeLayout.contentSize)
                    strongSelf.offsetContainerNode.frame = CGRect(origin: CGPoint(), size: nodeLayout.contentSize)
                    
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
                    
                    strongSelf.appliedItem = item
                    strongSelf.currentMedia = selectedMedia
                    strongSelf.currentPrimaryUrl = primaryUrl
                    strongSelf.currentIsInstantView = isInstantView
                    
                    if let _ = updatedTheme {
                        strongSelf.separatorNode.backgroundColor = item.presentationData.theme.theme.list.itemPlainSeparatorColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.theme.list.itemHighlightedBackgroundColor
                    }
                    
                    if let (selectionWidth, selectionApply) = selectionNodeWidthAndApply {
                        let selectionFrame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: selectionWidth, height: contentHeight))
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
                    
                    transition.updateFrame(node: strongSelf.separatorNode, frame: CGRect(origin: CGPoint(x: leftOffset + leftInset, y: contentHeight - UIScreenPixel), size: CGSize(width: params.width - leftInset - leftOffset, height: UIScreenPixel)))
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: contentHeight + UIScreenPixel))
                    
                    transition.updateFrame(node: strongSelf.titleNode, frame: CGRect(origin: CGPoint(x: leftOffset + leftInset, y: 9.0), size: titleNodeLayout.size))
                    let _ = titleNodeApply()
                    
                    let descriptionFrame = CGRect(origin: CGPoint(x: leftOffset + leftInset, y: strongSelf.titleNode.frame.maxY + 1.0), size: descriptionNodeLayout.size)
                    transition.updateFrame(node: strongSelf.descriptionNode, frame: descriptionFrame)
                    let _ = descriptionNodeApply()
                    
                    let _ = dateNodeApply()
                    transition.updateFrame(node: strongSelf.dateNode, frame: CGRect(origin: CGPoint(x: params.width - params.rightInset - dateNodeLayout.size.width - 8.0, y: 11.0), size: dateNodeLayout.size))
                    strongSelf.dateNode.isHidden = !item.isGlobalSearchResult
                    
                    let linkFrame = CGRect(origin: CGPoint(x: leftOffset + leftInset - 1.0, y: descriptionFrame.maxY), size: linkNodeLayout.size)
                    transition.updateFrame(node: strongSelf.linkNode, frame: linkFrame)
                    let _ = linkNodeApply()
                    
                    let _ = authorNodeApply()
                    transition.updateFrame(node: strongSelf.authorNode, frame: CGRect(origin: CGPoint(x: leftOffset + leftInset, y: linkFrame.maxY + 1.0), size: authorNodeLayout.size))
                    strongSelf.authorNode.isHidden = !item.isGlobalSearchResult
                    
                    if let image = instantViewImage {
                        strongSelf.instantViewIconNode.image = image
                        transition.updateFrame(node: strongSelf.instantViewIconNode, frame: CGRect(origin: linkFrame.origin.offsetBy(dx: 0.0, dy: 4.0), size: image.size))
                    }
                    
                    let iconFrame = CGRect(origin: CGPoint(x: params.leftInset + leftOffset + 12.0, y: 12.0), size: CGSize(width: 40.0, height: 40.0))
                    transition.updateFrame(node: strongSelf.iconTextNode, frame: CGRect(origin: CGPoint(x: iconFrame.minX + floorToScreenPixels((iconFrame.width - iconTextLayout.size.width) / 2.0), y: iconFrame.minY + floorToScreenPixels((iconFrame.height - iconTextLayout.size.height) / 2.0) + 2.0), size: iconTextLayout.size))
                    
                    let _ = iconTextApply()
                    
                    strongSelf.currentIconImageRepresentation = iconImageReferenceAndRepresentation?.1
                    
                    if let iconImageApply = iconImageApply {
                        if let updateImageSignal = updateIconImageSignal {
                            strongSelf.iconImageNode.setSignal(updateImageSignal)
                        }
                        
                        if strongSelf.iconImageNode.supernode == nil {
                            strongSelf.offsetContainerNode.addSubnode(strongSelf.iconImageNode)
                            strongSelf.iconImageNode.frame = iconFrame
                        } else {
                            transition.updateFrame(node: strongSelf.iconImageNode, frame: iconFrame)
                        }
                        
                        iconImageApply()
                        
                        if strongSelf.iconTextBackgroundNode.supernode != nil {
                            strongSelf.iconTextBackgroundNode.removeFromSupernode()
                        }
                        if strongSelf.iconTextNode.supernode != nil {
                            strongSelf.iconTextNode.removeFromSupernode()
                        }
                    } else {
                        if strongSelf.iconImageNode.supernode != nil {
                            strongSelf.iconImageNode.removeFromSupernode()
                        }
                        
                        if strongSelf.iconTextBackgroundNode.supernode == nil {
                            strongSelf.iconTextBackgroundNode.image = applyIconTextBackgroundImage
                            strongSelf.offsetContainerNode.addSubnode(strongSelf.iconTextBackgroundNode)
                            strongSelf.iconTextBackgroundNode.frame = iconFrame
                        } else {
                            transition.updateFrame(node: strongSelf.iconTextBackgroundNode, frame: iconFrame)
                        }
                        if strongSelf.iconTextNode.supernode == nil {
                            strongSelf.offsetContainerNode.addSubnode(strongSelf.iconTextNode)
                        }
                    }
                    
                    strongSelf.iconTextBackgroundNode.isHidden = iconText == nil
                    strongSelf.iconTextNode.isHidden = iconText == nil
                }
            })
        }
    }
    
    override public func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        if highlighted, let item = self.item, case .none = item.selection, self.urlAtPoint(point) == nil {
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
    
    override public func transitionNode(id: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        if let item = self.item, item.message?.id == id, self.iconImageNode.supernode != nil {
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
    
    func activateMedia() {
        if let item = self.item, let message = item.message, let currentPrimaryUrl = self.currentPrimaryUrl {
            if let webpage = self.currentMedia as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                if content.instantPage != nil {
                    if websiteType(of: content.websiteName) == .instagram {
                        if !item.interaction.openMessage(message, .default) {
                            item.interaction.openInstantPage(message, nil)
                        }
                    } else {
                        item.interaction.openInstantPage(message, nil)
                    }
                } else {
                    if isTelegramMeLink(content.url) || !item.interaction.openMessage(message, .link) {
                        item.interaction.openUrl(currentPrimaryUrl, false, false, nil)
                    }
                }
            } else {
                item.interaction.openUrl(currentPrimaryUrl, false, false, nil)
            }
        }
    }
    
    override public func headers() -> [ListViewItemHeader]? {
        if let item = self.item {
            return item.header.flatMap { [$0] }
        } else {
            return nil
        }
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let item = self.item, case .selectable = item.selection {
            if self.bounds.contains(point) {
                return self.view
            }
        }
        if let _ = self.urlAtPoint(point) {
            return self.view
        }
        return super.hitTest(point, with: event)
    }
    
    private func urlAtPoint(_ point: CGPoint) -> String? {
        let textNodeFrame = self.linkNode.frame
        if let (_, attributes) = self.linkNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
            let possibleNames: [String] = [
                TelegramTextAttributes.URL,
            ]
            for name in possibleNames {
                if let value = attributes[NSAttributedString.Key(rawValue: name)] as? String {
                    return value
                }
            }
        }
        return nil
    }
    
    @objc func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
            case .began:
                break
            case .ended:
                if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                    switch gesture {
                        case .tap, .longTap:
                            if let item = self.item, let message = item.message, let url = self.urlAtPoint(location) {
                                if case .longTap = gesture {
                                    item.interaction.longTap(ChatControllerInteractionLongTapAction.url(url), message)
                                } else if url == self.currentPrimaryUrl {
                                    if !item.interaction.openMessage(message, .default) {
                                        item.interaction.openUrl(url, false, false, nil)
                                    }
                                } else {
                                    item.interaction.openUrl(url, false, true, nil)
                                }
                            }
                        case .hold, .doubleTap:
                            break
                    }
                }
            case .cancelled:
                break
            default:
                break
        }
    }
    
    private func updateTouchesAtPoint(_ point: CGPoint?) {
        if let item = self.item, let message = item.message {
            var rects: [CGRect]?
            if let point = point {
                let textNodeFrame = self.linkNode.frame
                if let (index, attributes) = self.linkNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
                    let possibleNames: [String] = [
                        TelegramTextAttributes.URL
                    ]
                    for name in possibleNames {
                        if let _ = attributes[NSAttributedString.Key(rawValue: name)] {
                            rects = self.linkNode.attributeRects(name: name, at: index)
                            break
                        }
                    }
                }
            }
            
            if let rects = rects {
                let linkHighlightingNode: LinkHighlightingNode
                if let current = self.linkHighlightingNode {
                    linkHighlightingNode = current
                } else {
                    linkHighlightingNode = LinkHighlightingNode(color: message.effectivelyIncoming(item.context.account.peerId) ? item.presentationData.theme.theme.chat.message.incoming.linkHighlightColor : item.presentationData.theme.theme.chat.message.outgoing.linkHighlightColor)
                    self.linkHighlightingNode = linkHighlightingNode
                    self.offsetContainerNode.insertSubnode(linkHighlightingNode, belowSubnode: self.linkNode)
                }
                linkHighlightingNode.frame = self.linkNode.frame.offsetBy(dx: 0.0, dy: 0.0)
                linkHighlightingNode.updateRects(rects.map { $0.insetBy(dx: -1.0, dy: -1.0) })
            } else if let linkHighlightingNode = self.linkHighlightingNode {
                self.linkHighlightingNode = nil
                linkHighlightingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak linkHighlightingNode] _ in
                    linkHighlightingNode?.removeFromSupernode()
                })
            }
        }
    }
}
