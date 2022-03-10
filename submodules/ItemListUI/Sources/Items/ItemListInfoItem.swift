import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import TextFormat
import Markdown

public enum InfoListItemText {
    case plain(String)
    case markdown(String)
}

public enum InfoListItemLinkAction {
    case tap(String)
}

public class InfoListItem: ListViewItem {
    public let selectable: Bool = false
    
    let presentationData: ItemListPresentationData
    let title: String
    let text: InfoListItemText
    let style: ItemListStyle
    let hasDecorations: Bool
    let linkAction: ((InfoListItemLinkAction) -> Void)?
    let closeAction: (() -> Void)?
    
    public init(presentationData: ItemListPresentationData, title: String, text: InfoListItemText, style: ItemListStyle, hasDecorations: Bool = true, linkAction: ((InfoListItemLinkAction) -> Void)? = nil, closeAction: (() -> Void)?) {
        self.presentationData = presentationData
        self.title = title
        self.text = text
        self.style = style
        self.hasDecorations = hasDecorations
        self.linkAction = linkAction
        self.closeAction = closeAction
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = InfoItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, nil)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? InfoItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params, nil)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
}

public class ItemListInfoItem: InfoListItem, ItemListItem {
    public let sectionId: ItemListSectionId
    
    public init(presentationData: ItemListPresentationData, title: String, text: InfoListItemText, style: ItemListStyle, sectionId: ItemListSectionId, linkAction: ((InfoListItemLinkAction) -> Void)? = nil, closeAction: (() -> Void)?) {
        self.sectionId = sectionId
        super.init(presentationData: presentationData, title: title, text: text, style: style, linkAction: linkAction, closeAction: closeAction)
    }
    
    override public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = InfoItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }
    
    override public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? InfoItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
}

public class InfoItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let closeButton: HighlightableButtonNode
    private let maskNode: ASImageNode
    
    private let badgeNode: ASImageNode
    private let labelNode: TextNode
    private let titleNode: TextNode
    private let textNode: TextNode
    private var linkHighlightingNode: LinkHighlightingNode?
    
    private let activateArea: AccessibilityAreaNode
    
    private var item: InfoListItem?
    
    public override var canBeSelected: Bool {
        return false
    }
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        
        self.badgeNode = ASImageNode()
        self.badgeNode.displayWithoutProcessing = true
        self.badgeNode.displaysAsynchronously = false
        self.badgeNode.isLayerBacked = true
        
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        
        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        
        self.activateArea = AccessibilityAreaNode()
        self.activateArea.accessibilityTraits = .staticText
        
        self.closeButton = HighlightableButtonNode()
        self.closeButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        self.closeButton.displaysAsynchronously = false
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.badgeNode)
        self.addSubnode(self.labelNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.activateArea)
        self.addSubnode(self.closeButton)
        
        self.closeButton.addTarget(self, action: #selector(self.closeButtonPressed), forControlEvents: .touchUpInside)
    }
    
    public override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { [weak self] point in
            if let strongSelf = self, !strongSelf.closeButton.frame.contains(point) {
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
    
    func asyncLayout() -> (_ item: InfoListItem, _ params: ListViewItemLayoutParams, _ insets: ItemListNeighbors?) -> (ListViewItemNodeLayout, () -> Void) {
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            let leftInset: CGFloat = 16.0 + params.leftInset
            let rightInset: CGFloat = 16.0 + params.rightInset
            
            let titleFont = Font.medium(item.presentationData.fontSize.itemListBaseFontSize)
            let textFont = Font.regular(item.presentationData.fontSize.itemListBaseLabelFontSize / 14.0 * 16.0)
            let textBoldFont = Font.semibold(item.presentationData.fontSize.itemListBaseLabelFontSize / 14.0 * 16.0)
            let badgeFont = Font.regular(15.0)
    
            var updatedTheme: PresentationTheme?
            var updatedBadgeImage: UIImage?
            
            var updatedCloseIcon: UIImage?
            
            let badgeDiameter: CGFloat = 22.0
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
                updatedBadgeImage = generateStretchableFilledCircleImage(diameter: badgeDiameter, color: item.presentationData.theme.list.itemDestructiveColor)
                updatedCloseIcon = PresentationResourcesItemList.itemListCloseIconImage(item.presentationData.theme)
            }
            
            let insets: UIEdgeInsets
            if let neighbors = neighbors {
                insets = itemListNeighborsGroupedInsets(neighbors, params)
            } else {
                insets = UIEdgeInsets()
            }
            let separatorHeight = UIScreenPixel
            
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            
            switch item.style {
            case .plain:
                itemBackgroundColor = item.presentationData.theme.list.plainBackgroundColor
                itemSeparatorColor = item.presentationData.theme.list.itemPlainSeparatorColor
            case .blocks:
                itemBackgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                itemSeparatorColor = item.presentationData.theme.list.itemBlocksSeparatorColor
            }
            
            let attributedText: NSAttributedString
            switch item.text {
            case let .plain(text):
                attributedText = NSAttributedString(string: text, font: textFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor)
            case let .markdown(text):
                attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), bold: MarkdownAttributeSet(font: textBoldFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), link: MarkdownAttributeSet(font: textFont, textColor: item.presentationData.theme.list.itemAccentColor), linkAttribute: { contents in
                    return (TelegramTextAttributes.URL, contents)
                }))
            }
            
            let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "!", font: badgeFont, textColor: item.presentationData.theme.list.itemCheckColors.foregroundColor), backgroundColor: nil, maximumNumberOfLines: 3, truncationType: .end, constrainedSize: CGSize(width: badgeDiameter, height: badgeDiameter), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: titleFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 2, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset - badgeDiameter - 8.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let contentSize = CGSize(width: params.width, height: titleLayout.size.height + textLayout.size.height + 38.0)
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.accessibilityLabel = "\(item.title)\n\(attributedText.string)"
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                    strongSelf.activateArea.accessibilityLabel = strongSelf.accessibilityLabel
                
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                    }
                    
                    let _ = labelApply()
                    let _ = titleApply()
                    let _ = textApply()
                    
                    if strongSelf.backgroundNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                    }
                    if strongSelf.topStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                    }
                    if strongSelf.maskNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.maskNode, at: 3)
                    }
                    
                    let hasCorners = itemListHasRoundedBlockLayout(params)
                    var hasTopCorners = false
                    var hasBottomCorners = false
                    if let neighbors = neighbors {
                        switch neighbors.top {
                            case .sameSection(false):
                                strongSelf.topStripeNode.isHidden = true
                            default:
                                hasTopCorners = true
                                strongSelf.topStripeNode.isHidden = hasCorners || !item.hasDecorations
                        }
                    }
                    let bottomStripeInset: CGFloat
                    if let neighbors = neighbors {
                        switch neighbors.bottom {
                            case .sameSection(false):
                                bottomStripeInset = leftInset
                                strongSelf.bottomStripeNode.isHidden = false
                            default:
                                bottomStripeInset = 0.0
                                hasBottomCorners = true
                                strongSelf.bottomStripeNode.isHidden = hasCorners || !item.hasDecorations
                        }
                    } else {
                        bottomStripeInset = leftInset
                        if !item.hasDecorations {
                            strongSelf.topStripeNode.isHidden = true
                        }
                    }
                    
                    strongSelf.closeButton.isHidden = item.closeAction == nil
                    
                    strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: separatorHeight))
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - bottomStripeInset, height: separatorHeight))
                    
                    if let updateBadgeImage = updatedBadgeImage {
                        if strongSelf.badgeNode.supernode == nil {
                            strongSelf.insertSubnode(strongSelf.badgeNode, belowSubnode: strongSelf.labelNode)
                        }
                        strongSelf.badgeNode.image = updateBadgeImage
                    }
                    
                    if let updatedCloseIcon = updatedCloseIcon {
                        strongSelf.closeButton.setImage(updatedCloseIcon, for: [])
                    }
                    
                    strongSelf.badgeNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 15.0), size: CGSize(width: badgeDiameter, height: badgeDiameter))
                    
                    strongSelf.labelNode.frame = CGRect(origin: CGPoint(x: strongSelf.badgeNode.frame.midX - labelLayout.size.width / 2.0, y: strongSelf.badgeNode.frame.minY + 2.0 + UIScreenPixel), size: labelLayout.size)
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: strongSelf.badgeNode.frame.maxX + 8.0, y: 16.0), size: titleLayout.size)
                    
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: leftInset, y: strongSelf.titleNode.frame.maxY + 9.0), size: textLayout.size)
                    
                    strongSelf.closeButton.frame = CGRect(x: params.width - rightInset - 26.0, y: 10.0, width: 32.0, height: 32.0)
                }
            })
        }
    }

    public override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    public override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    public override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    @objc func closeButtonPressed() {
        if let item = self.item {
            item.closeAction?()
        }
    }
    
    @objc func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
            case .ended:
                if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                    switch gesture {
                        case .tap:
                            let titleFrame = self.textNode.frame
                            if let item = self.item, titleFrame.contains(location) {
                                if let (_, attributes) = self.textNode.attributesAtPoint(CGPoint(x: location.x - titleFrame.minX, y: location.y - titleFrame.minY)) {
                                    if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                                        item.linkAction?(.tap(url))
                                    }
                                }
                            }
                        default:
                            break
                    }
                }
            default:
                break
        }
    }
    
    private func updateTouchesAtPoint(_ point: CGPoint?) {
        if let item = self.item {
            var rects: [CGRect]?
            if let point = point {
                let textNodeFrame = self.textNode.frame
                if let (index, attributes) = self.textNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
                    let possibleNames: [String] = [
                        TelegramTextAttributes.URL,
                        TelegramTextAttributes.PeerMention,
                        TelegramTextAttributes.PeerTextMention,
                        TelegramTextAttributes.BotCommand,
                        TelegramTextAttributes.Hashtag
                    ]
                    for name in possibleNames {
                        if let _ = attributes[NSAttributedString.Key(rawValue: name)] {
                            rects = self.textNode.attributeRects(name: name, at: index)
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
                    linkHighlightingNode = LinkHighlightingNode(color: item.presentationData.theme.list.itemAccentColor.withAlphaComponent(0.5))
                    self.linkHighlightingNode = linkHighlightingNode
                    self.insertSubnode(linkHighlightingNode, belowSubnode: self.textNode)
                }
                linkHighlightingNode.frame = self.textNode.frame
                linkHighlightingNode.updateRects(rects)
            } else if let linkHighlightingNode = self.linkHighlightingNode {
                self.linkHighlightingNode = nil
                linkHighlightingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak linkHighlightingNode] _ in
                    linkHighlightingNode?.removeFromSupernode()
                })
            }
        }
    }
}
