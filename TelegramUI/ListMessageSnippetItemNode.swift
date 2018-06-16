import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

private let titleFont = Font.medium(16.0)
private let descriptionFont = Font.regular(14.0)
private let iconFont = Font.medium(22.0)

private let iconTextBackgroundImage = generateStretchableFilledCircleImage(radius: 2.0, color: UIColor(rgb: 0xdfdfdf))

final class ListMessageSnippetItemNode: ListMessageNode {
    private let highlightedBackgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    
    private var selectionNode: ItemListSelectableControlNode?
    
    private let titleNode: TextNode
    private let descriptionNode: TextNode
    private var linkHighlightingNode: LinkHighlightingNode?
    
    private let iconTextBackgroundNode: ASImageNode
    private let iconTextNode: TextNode
    private let iconImageNode: TransformImageNode
    
    private var currentIconImageRepresentation: TelegramMediaImageRepresentation?
    private var currentMedia: Media?
    private var currentPrimaryUrl: String?
    
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
        self.titleNode.isLayerBacked = true
        
        self.descriptionNode = TextNode()
        self.descriptionNode.isLayerBacked = true
        
        self.iconTextBackgroundNode = ASImageNode()
        self.iconTextBackgroundNode.isLayerBacked = true
        self.iconTextBackgroundNode.displaysAsynchronously = false
        self.iconTextBackgroundNode.displayWithoutProcessing = true
        
        self.iconTextNode = TextNode()
        self.iconTextNode.isLayerBacked = true
        
        self.iconImageNode = TransformImageNode()
        self.iconImageNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.descriptionNode)
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
        //self.layer.animateBoundsOriginYAdditive(from: -self.bounds.size.height * 1.4, to: 0.0, duration: duration)
    }
    
    override func asyncLayout() -> (_ item: ListMessageItem, _ params: ListViewItemLayoutParams, _ mergedTop: Bool, _ mergedBottom: Bool, _ dateHeaderAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let titleNodeMakeLayout = TextNode.asyncLayout(self.titleNode)
        let descriptionNodeMakeLayout = TextNode.asyncLayout(self.descriptionNode)
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
            
            let leftInset: CGFloat = 65.0 + params.leftInset
            
            var leftOffset: CGFloat = 0.0
            var selectionNodeWidthAndApply: (CGFloat, (CGSize, Bool) -> ItemListSelectableControlNode)?
            if case let .selectable(selected) = item.selection {
                let (selectionWidth, selectionApply) = selectionNodeLayout(item.theme.list.itemCheckColors.strokeColor, item.theme.list.itemCheckColors.fillColor, item.theme.list.itemCheckColors.foregroundColor, selected)
                selectionNodeWidthAndApply = (selectionWidth, selectionApply)
                leftOffset += selectionWidth
            }
            
            var title: NSAttributedString?
            var descriptionText: NSAttributedString?
            var iconText: NSAttributedString?
            
            var iconImageRepresentation: TelegramMediaImageRepresentation?
            var updateIconImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            
            let applyIconTextBackgroundImage = iconTextBackgroundImage
            
            var primaryUrl: String?
            
            var selectedMedia: TelegramMediaWebpage?
            var processed = false
            for media in item.message.media {
                if let webpage = media as? TelegramMediaWebpage {
                    selectedMedia = webpage
                    
                    if case let .Loaded(content) = webpage.content {
                        primaryUrl = content.url
                        
                        processed = true
                        var hostName: String = ""
                        if let url = URL(string: content.url), let host = url.host, !host.isEmpty {
                            hostName = host
                            iconText = NSAttributedString(string: host[..<host.index(after: host.startIndex)].uppercased(), font: iconFont, textColor: UIColor.white)
                        }
                        
                        title = NSAttributedString(string: content.title ?? content.websiteName ?? hostName, font: titleFont, textColor: item.theme.list.itemPrimaryTextColor)
                        
                        if let image = content.image {
                            iconImageRepresentation = imageRepresentationLargerThan(image.representations, size: CGSize(width: 80.0, height: 80.0))
                        } else if let file = content.file {
                            iconImageRepresentation = smallestImageRepresentation(file.previewRepresentations)
                        }
                        
                        let mutableDescriptionText = NSMutableAttributedString()
                        if let text = content.text {
                            mutableDescriptionText.append(NSAttributedString(string: text + "\n", font: descriptionFont, textColor: item.theme.list.itemPrimaryTextColor))
                        }
                        
                        let plainUrlString = NSAttributedString(string: content.displayUrl, font: descriptionFont, textColor: item.theme.list.itemAccentColor)
                        let urlString = NSMutableAttributedString()
                        urlString.append(plainUrlString)
                        urlString.addAttribute(NSAttributedStringKey(rawValue: TelegramTextAttributes.Url), value: content.displayUrl, range: NSMakeRange(0, urlString.length))
                        mutableDescriptionText.append(urlString)
                        
                        descriptionText = mutableDescriptionText
                    }
                    
                    break
                }
            }
            
            if !processed {
                loop: for entity in generateTextEntities(item.message.text, enabledTypes: .all) {
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
                                    urlAttributedString.addAttribute(NSAttributedStringKey.underlineStyle, value: NSUnderlineStyle.styleSingle.rawValue as NSNumber, range: NSMakeRange(0, urlAttributedString.length))
                                }
                                urlAttributedString.addAttribute(NSAttributedStringKey(rawValue: TelegramTextAttributes.Url), value: urlString, range: NSMakeRange(0, urlAttributedString.length))
                                mutableDescriptionText.append(urlAttributedString)

                                descriptionText = mutableDescriptionText
                            }
                            break loop
                        default:
                            break
                    }
                }
            }
            
            let (titleNodeLayout, titleNodeApply) = titleNodeMakeLayout(TextNodeLayoutArguments(attributedString: title, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .middle, constrainedSize: CGSize(width: params.width - leftInset - 8.0 - params.rightInset, height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (descriptionNodeLayout, descriptionNodeApply) = descriptionNodeMakeLayout(TextNodeLayoutArguments(attributedString: descriptionText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 8.0 - params.rightInset - 12.0, height: CGFloat.infinity), alignment: .natural, lineSpacing: 0.3, cutout: nil, insets: UIEdgeInsets(top: 1.0, left: 1.0, bottom: 1.0, right: 1.0)))
            
            let (iconTextLayout, iconTextApply) = iconTextMakeLayout(TextNodeLayoutArguments(attributedString: iconText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 38.0, height: CGFloat.infinity), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var iconImageApply: (() -> Void)?
            if let iconImageRepresentation = iconImageRepresentation {
                let iconSize = CGSize(width: 42.0, height: 42.0)
                let imageCorners = ImageCorners(topLeft: .Corner(2.0), topRight: .Corner(2.0), bottomLeft: .Corner(2.0), bottomRight: .Corner(2.0))
                let arguments = TransformImageArguments(corners: imageCorners, imageSize: iconImageRepresentation.dimensions.aspectFilled(iconSize), boundingSize: iconSize, intrinsicInsets: UIEdgeInsets())
                iconImageApply = iconImageLayout(arguments)
            }
            
            if currentIconImageRepresentation != iconImageRepresentation {
                if let iconImageRepresentation = iconImageRepresentation {
                    let tmpImage = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [iconImageRepresentation], reference: nil)
                    updateIconImageSignal = chatWebpageSnippetPhoto(account: item.account, photo: tmpImage)
                } else {
                    updateIconImageSignal = .complete()
                }
            }
            
            let contentHeight = 40.0 + descriptionNodeLayout.size.height
            
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
                    
                    transition.updateFrame(node: strongSelf.descriptionNode, frame: CGRect(origin: CGPoint(x: leftOffset + leftInset - 1.0, y: 32.0), size: descriptionNodeLayout.size))
                    let _ = descriptionNodeApply()
                    
                    let iconFrame = CGRect(origin: CGPoint(x: params.leftInset + leftOffset + 9.0, y: 12.0), size: CGSize(width: 42.0, height: 42.0))
                    transition.updateFrame(node: strongSelf.iconTextNode, frame: CGRect(origin: CGPoint(x: iconFrame.minX + floor((42.0 - iconTextLayout.size.width) / 2.0), y: iconFrame.minY + floor((42.0 - iconTextLayout.size.height) / 2.0) + 3.0), size: iconTextLayout.size))
                    
                    let _ = iconTextApply()
                    
                    strongSelf.currentIconImageRepresentation = iconImageRepresentation
                    
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
    
    override func transitionNode(id: MessageId, media: Media) -> (ASDisplayNode, () -> UIView?)? {
        if let item = self.item, item.message.id == id, self.iconImageNode.supernode != nil {
            let iconImageNode = self.iconImageNode
            return (self.iconImageNode, { [weak iconImageNode] in
                return iconImageNode?.view.snapshotContentTree(unhide: true)
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
            if let webpage = self.currentMedia as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content, content.instantPage != nil {
                if websiteType(of: content) == .instagram {
                    if !item.controllerInteraction.openMessage(item.message) {
                        item.controllerInteraction.openInstantPage(item.message)
                    }
                } else {
                    item.controllerInteraction.openInstantPage(item.message)
                }
            } else {
                if !item.controllerInteraction.openMessage(item.message) {
                    item.controllerInteraction.openUrl(currentPrimaryUrl)
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
        let textNodeFrame = self.descriptionNode.frame
        if let (_, attributes) = self.descriptionNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
            let possibleNames: [String] = [
                TelegramTextAttributes.Url,
            ]
            for name in possibleNames {
                if let value = attributes[NSAttributedStringKey(rawValue: name)] as? String {
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
                                    item.controllerInteraction.longTap(ChatControllerInteractionLongTapAction.url(url))
                                } else if url == self.currentPrimaryUrl {
                                    if !item.controllerInteraction.openMessage(item.message) {
                                        item.controllerInteraction.openUrl(url)
                                    }
                                } else {
                                    item.controllerInteraction.openUrl(url)
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
                let textNodeFrame = self.descriptionNode.frame
                if let (index, attributes) = self.descriptionNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
                    let possibleNames: [String] = [
                        TelegramTextAttributes.Url
                    ]
                    for name in possibleNames {
                        if let _ = attributes[NSAttributedStringKey(rawValue: name)] {
                            rects = self.descriptionNode.attributeRects(name: name, at: index)
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
                    linkHighlightingNode = LinkHighlightingNode(color: item.message.effectivelyIncoming(item.account.peerId) ? item.theme.chat.bubble.incomingLinkHighlightColor : item.theme.chat.bubble.outgoingLinkHighlightColor)
                    self.linkHighlightingNode = linkHighlightingNode
                    self.insertSubnode(linkHighlightingNode, belowSubnode: self.descriptionNode)
                }
                linkHighlightingNode.frame = self.descriptionNode.frame.offsetBy(dx: 0.0, dy: -4.0)
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
            item.controllerInteraction.openMessageContextMenu(item.message, self, self.bounds)
        }
    }
}
