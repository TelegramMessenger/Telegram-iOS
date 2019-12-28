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
import TextFormat
import PhotoResources
import WebsiteType
import UrlHandling

private let iconFont = Font.medium(22.0)

private let iconTextBackgroundImage = generateStretchableFilledCircleImage(radius: 2.0, color: UIColor(rgb: 0xdfdfdf))

final class ListMessageSnippetItemNode: ListMessageNode {
    private let highlightedBackgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    
    private var selectionNode: ItemListSelectableControlNode?
    
    private let titleNode: TextNode
    private let descriptionNode: TextNode
    private let instantViewIconNode: ASImageNode
    private let linkNode: TextNode
    private var linkHighlightingNode: LinkHighlightingNode?
    
    private let iconTextBackgroundNode: ASImageNode
    private let iconTextNode: TextNode
    private let iconImageNode: TransformImageNode
    
    private var currentIconImageRepresentation: TelegramMediaImageRepresentation?
    private var currentMedia: Media?
    private var currentPrimaryUrl: String?
    private var currentIsInstantView: Bool?
    
    private var appliedItem: ListMessageItem?
    
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
        
        super.init()
        
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.descriptionNode)
        self.addSubnode(self.linkNode)
        self.addSubnode(self.instantViewIconNode)
        self.addSubnode(self.iconImageNode)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didLoad() {
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
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    override func asyncLayout() -> (_ item: ListMessageItem, _ params: ListViewItemLayoutParams, _ mergedTop: Bool, _ mergedBottom: Bool, _ dateHeaderAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let titleNodeMakeLayout = TextNode.asyncLayout(self.titleNode)
        let descriptionNodeMakeLayout = TextNode.asyncLayout(self.descriptionNode)
        let linkNodeMakeLayout = TextNode.asyncLayout(self.linkNode)
        let iconTextMakeLayout = TextNode.asyncLayout(self.iconTextNode)
        let iconImageLayout = self.iconImageNode.asyncLayout()
        
        let currentIconImageRepresentation = self.currentIconImageRepresentation
        
        let currentItem = self.appliedItem
        
        let selectionNodeLayout = ItemListSelectableControlNode.asyncLayout(self.selectionNode)
        
        return { [weak self] item, params, _, _, dateHeaderAtBottom in
            var updatedTheme: PresentationTheme?
            
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
            }
            
            let titleFont = Font.medium(floor(item.fontSize.baseDisplaySize * 16.0 / 17.0))
            let descriptionFont = Font.regular(floor(item.fontSize.baseDisplaySize * 14.0 / 17.0))
            
            let leftInset: CGFloat = 65.0 + params.leftInset
            
            var leftOffset: CGFloat = 0.0
            var selectionNodeWidthAndApply: (CGFloat, (CGSize, Bool) -> ItemListSelectableControlNode)?
            if case let .selectable(selected) = item.selection {
                let (selectionWidth, selectionApply) = selectionNodeLayout(item.theme.list.itemCheckColors.strokeColor, item.theme.list.itemCheckColors.fillColor, item.theme.list.itemCheckColors.foregroundColor, selected, false)
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
            
            var selectedMedia: TelegramMediaWebpage?
            var processed = false
            for media in item.message.media {
                if let webpage = media as? TelegramMediaWebpage {
                    selectedMedia = webpage
                    
                    if case let .Loaded(content) = webpage.content {
                        if content.instantPage != nil && instantPageType(of: content) != .album {
                            isInstantView = true
                        }
                        
                        primaryUrl = content.url
                        
                        processed = true
                        var hostName: String = ""
                        if let url = URL(string: content.url), let host = url.host, !host.isEmpty {
                            hostName = host
                            iconText = NSAttributedString(string: host[..<host.index(after: host.startIndex)].uppercased(), font: iconFont, textColor: UIColor.white)
                        }
                        
                        title = NSAttributedString(string: content.title ?? content.websiteName ?? hostName, font: titleFont, textColor: item.theme.list.itemPrimaryTextColor)
                        
                        if let image = content.image {
                            if let representation = imageRepresentationLargerThan(image.representations, size: PixelDimensions(width: 80, height: 80)) {
                                iconImageReferenceAndRepresentation = (.message(message: MessageReference(item.message), media: image), representation)
                            }
                        } else if let file = content.file {
                            if let representation = smallestImageRepresentation(file.previewRepresentations) {
                                iconImageReferenceAndRepresentation = (.message(message: MessageReference(item.message), media: file), representation)
                            }
                        }
                        
                        let mutableDescriptionText = NSMutableAttributedString()
                        if let text = content.text {
                            mutableDescriptionText.append(NSAttributedString(string: text + "\n", font: descriptionFont, textColor: item.theme.list.itemPrimaryTextColor))
                        }
                        
                        let plainUrlString = NSAttributedString(string: content.displayUrl, font: descriptionFont, textColor: item.theme.list.itemAccentColor)
                        let urlString = NSMutableAttributedString()
                        urlString.append(plainUrlString)
                        urlString.addAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.URL), value: content.displayUrl, range: NSMakeRange(0, urlString.length))
                        linkText = urlString
                        
                        descriptionText = mutableDescriptionText
                    }
                    
                    break
                }
            }
            
            if !processed {
                var messageEntities: [MessageTextEntity]?
                for attribute in item.message.attributes {
                    if let attribute = attribute as? TextEntitiesMessageAttribute {
                        messageEntities = attribute.entities
                        break
                    }
                }
                
                var entities: [MessageTextEntity]?
                
                entities = messageEntities
                if entities == nil {
                    let parsedEntities = generateTextEntities(item.message.text, enabledTypes: .all)
                    if !parsedEntities.isEmpty {
                        entities = parsedEntities
                    }
                }
                
                if let entities = entities {
                    loop: for entity in entities {
                        switch entity.type {
                            case .Url, .Email:
                                var range = NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound)
                                let nsString = item.message.text as NSString
                                if range.location + range.length > nsString.length {
                                    range.location = max(0, nsString.length - range.length)
                                    range.length = nsString.length - range.location
                                }
                                var urlString = nsString.substring(with: range)
                                var parsedUrl = URL(string: urlString)
                                if parsedUrl == nil || parsedUrl!.host == nil || parsedUrl!.host!.isEmpty {
                                    urlString = "http://" + urlString
                                    parsedUrl = URL(string: urlString)
                                }
                                if let url = parsedUrl, let host = url.host {
                                    primaryUrl = urlString
                                    
                                    iconText = NSAttributedString(string: host[..<host.index(after: host.startIndex)].uppercased(), font: iconFont, textColor: UIColor.white)
                                    
                                    title = NSAttributedString(string: host, font: titleFont, textColor: item.theme.list.itemPrimaryTextColor)
                                    let mutableDescriptionText = NSMutableAttributedString()
                                    if item.message.text != urlString {
                                       mutableDescriptionText.append(NSAttributedString(string: item.message.text + "\n", font: descriptionFont, textColor: item.theme.list.itemPrimaryTextColor))
                                    }
                                    
                                    let urlAttributedString = NSMutableAttributedString()
                                    urlAttributedString.append(NSAttributedString(string: urlString, font: descriptionFont, textColor: item.theme.list.itemAccentColor))
                                    if item.theme.list.itemAccentColor.isEqual(item.theme.list.itemPrimaryTextColor) {
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
            
            let (titleNodeLayout, titleNodeApply) = titleNodeMakeLayout(TextNodeLayoutArguments(attributedString: title, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .middle, constrainedSize: CGSize(width: params.width - leftInset - 8.0 - params.rightInset, height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (descriptionNodeLayout, descriptionNodeApply) = descriptionNodeMakeLayout(TextNodeLayoutArguments(attributedString: descriptionText, backgroundColor: nil, maximumNumberOfLines: 3, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 8.0 - params.rightInset - 12.0, height: CGFloat.infinity), alignment: .natural, lineSpacing: 0.3, cutout: nil, insets: UIEdgeInsets(top: 1.0, left: 1.0, bottom: 1.0, right: 1.0)))
            
            let (linkNodeLayout, linkNodeApply) = linkNodeMakeLayout(TextNodeLayoutArguments(attributedString: linkText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 8.0 - params.rightInset - 12.0, height: CGFloat.infinity), alignment: .natural, lineSpacing: 0.3, cutout: isInstantView ? TextNodeCutout(topLeft: CGSize(width: 14.0, height: 8.0)) : nil, insets: UIEdgeInsets(top: 1.0, left: 1.0, bottom: 1.0, right: 1.0)))
            var instantViewImage: UIImage?
            if isInstantView {
                 instantViewImage = PresentationResourcesChat.sharedMediaInstantViewIcon(item.theme)
            }
            
            let (iconTextLayout, iconTextApply) = iconTextMakeLayout(TextNodeLayoutArguments(attributedString: iconText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 38.0, height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var iconImageApply: (() -> Void)?
            if let iconImageReferenceAndRepresentation = iconImageReferenceAndRepresentation {
                let iconSize = CGSize(width: 42.0, height: 42.0)
                let imageCorners = ImageCorners(topLeft: .Corner(2.0), topRight: .Corner(2.0), bottomLeft: .Corner(2.0), bottomRight: .Corner(2.0))
                let arguments = TransformImageArguments(corners: imageCorners, imageSize: iconImageReferenceAndRepresentation.1.dimensions.cgSize.aspectFilled(iconSize), boundingSize: iconSize, intrinsicInsets: UIEdgeInsets(), emptyColor: item.theme.list.mediaPlaceholderColor)
                iconImageApply = iconImageLayout(arguments)
            }
            
            if currentIconImageRepresentation != iconImageReferenceAndRepresentation?.1 {
                if let iconImageReferenceAndRepresentation = iconImageReferenceAndRepresentation {
                    if let imageReference = iconImageReferenceAndRepresentation.0.concrete(TelegramMediaImage.self) {
                        updateIconImageSignal = chatWebpageSnippetPhoto(account: item.context.account, photoReference: imageReference)
                    } else if let fileReference = iconImageReferenceAndRepresentation.0.concrete(TelegramMediaFile.self) {
                        updateIconImageSignal = chatWebpageSnippetFile(account: item.context.account, fileReference: fileReference, representation: iconImageReferenceAndRepresentation.1)
                    }
                } else {
                    updateIconImageSignal = .complete()
                }
            }
            
            let contentHeight = 9.0 + titleNodeLayout.size.height + 10.0 + descriptionNodeLayout.size.height + linkNodeLayout.size.height
            
            var insets = UIEdgeInsets()
            if dateHeaderAtBottom, let header = item.header {
                insets.top += header.height
            }
            
            return (ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: contentHeight), insets: insets), { animation in
                if let strongSelf = self {
                    let transition: ContainedViewLayoutTransition
                    if animation.isAnimated {
                        transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                    } else {
                        transition = .immediate
                    }
                    
                    strongSelf.appliedItem = item
                    strongSelf.currentMedia = selectedMedia
                    strongSelf.currentPrimaryUrl = primaryUrl
                    strongSelf.currentIsInstantView = isInstantView
                    
                    if let _ = updatedTheme {
                        strongSelf.separatorNode.backgroundColor = item.theme.list.itemPlainSeparatorColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.theme.list.itemHighlightedBackgroundColor
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
                    
                    let descriptionFrame = CGRect(origin: CGPoint(x: leftOffset + leftInset - 1.0, y: strongSelf.titleNode.frame.maxY + 3.0), size: descriptionNodeLayout.size)
                    transition.updateFrame(node: strongSelf.descriptionNode, frame: descriptionFrame)
                    let _ = descriptionNodeApply()
                    
                    let linkFrame = CGRect(origin: CGPoint(x: leftOffset + leftInset - 1.0, y: descriptionFrame.maxY), size: linkNodeLayout.size)
                    transition.updateFrame(node: strongSelf.linkNode, frame: linkFrame)
                    let _ = linkNodeApply()
                    
                    if let image = instantViewImage {
                        strongSelf.instantViewIconNode.image = image
                        transition.updateFrame(node: strongSelf.instantViewIconNode, frame: CGRect(origin: linkFrame.origin.offsetBy(dx: 0.0, dy: 4.0), size: image.size))
                    }
                    
                    let iconFrame = CGRect(origin: CGPoint(x: params.leftInset + leftOffset + 9.0, y: 12.0), size: CGSize(width: 42.0, height: 42.0))
                    transition.updateFrame(node: strongSelf.iconTextNode, frame: CGRect(origin: CGPoint(x: iconFrame.minX + floor((42.0 - iconTextLayout.size.width) / 2.0), y: iconFrame.minY + floor((42.0 - iconTextLayout.size.height) / 2.0) + 3.0), size: iconTextLayout.size))
                    
                    let _ = iconTextApply()
                    
                    strongSelf.currentIconImageRepresentation = iconImageReferenceAndRepresentation?.1
                    
                    if let iconImageApply = iconImageApply {
                        if let updateImageSignal = updateIconImageSignal {
                            strongSelf.iconImageNode.setSignal(updateImageSignal)
                        }
                        
                        if strongSelf.iconImageNode.supernode == nil {
                            strongSelf.addSubnode(strongSelf.iconImageNode)
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
                            strongSelf.addSubnode(strongSelf.iconTextBackgroundNode)
                            strongSelf.iconTextBackgroundNode.frame = iconFrame
                        } else {
                            transition.updateFrame(node: strongSelf.iconTextBackgroundNode, frame: iconFrame)
                        }
                        if strongSelf.iconTextNode.supernode == nil {
                            strongSelf.addSubnode(strongSelf.iconTextNode)
                        }
                    }
                }
            })
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
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
    
    func activateMedia() {
        if let item = self.item, let currentPrimaryUrl = self.currentPrimaryUrl {
            if let webpage = self.currentMedia as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                if content.instantPage != nil {
                    if websiteType(of: content.websiteName) == .instagram {
                        if !item.controllerInteraction.openMessage(item.message, .default) {
                            item.controllerInteraction.openInstantPage(item.message, nil)
                        }
                    } else {
                        item.controllerInteraction.openInstantPage(item.message, nil)
                    }
                } else {
                    if isTelegramMeLink(content.url) || !item.controllerInteraction.openMessage(item.message, .link) {
                        item.controllerInteraction.openUrl(currentPrimaryUrl, false, false, nil)
                    }
                }
            } else {
                if !item.controllerInteraction.openMessage(item.message, .default) {
                    item.controllerInteraction.openUrl(currentPrimaryUrl, false, false, nil)
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
                            if let item = self.item, let url = self.urlAtPoint(location) {
                                if case .longTap = gesture {
                                    item.controllerInteraction.longTap(ChatControllerInteractionLongTapAction.url(url), item.message)
                                } else if url == self.currentPrimaryUrl {
                                    if !item.controllerInteraction.openMessage(item.message, .default) {
                                        item.controllerInteraction.openUrl(url, false, false, nil)
                                    }
                                } else {
                                    item.controllerInteraction.openUrl(url, false, true, nil)
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
        if let item = self.item {
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
                    linkHighlightingNode = LinkHighlightingNode(color: item.message.effectivelyIncoming(item.context.account.peerId) ? item.theme.chat.message.incoming.linkHighlightColor : item.theme.chat.message.outgoing.linkHighlightColor)
                    self.linkHighlightingNode = linkHighlightingNode
                    self.insertSubnode(linkHighlightingNode, belowSubnode: self.linkNode)
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
    
    override func longTapped() {
        if let item = self.item {
            item.controllerInteraction.openMessageContextMenu(item.message, false, self, self.bounds, nil)
        }
    }
}
