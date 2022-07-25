import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import TextFormat
import AccountContext

public enum ItemListTextWithLabelItemTextColor {
    case primary
    case accent
    case highlighted
}

public final class ItemListTextWithLabelItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    public let label: String
    public let text: String
    let style: ItemListStyle
    let labelColor: ItemListTextWithLabelItemTextColor
    let textColor: ItemListTextWithLabelItemTextColor
    let enabledEntityTypes: EnabledEntityTypes
    let multiline: Bool
    let selected: Bool?
    public let sectionId: ItemListSectionId
    let action: (() -> Void)?
    let longTapAction: (() -> Void)?
    let linkItemAction: ((TextLinkItemActionType, TextLinkItem) -> Void)?
    
    public let tag: Any?
    
    public init(presentationData: ItemListPresentationData, label: String, text: String, style: ItemListStyle = .plain, labelColor: ItemListTextWithLabelItemTextColor = .primary, textColor: ItemListTextWithLabelItemTextColor = .primary, enabledEntityTypes: EnabledEntityTypes, multiline: Bool, selected: Bool? = nil, sectionId: ItemListSectionId, action: (() -> Void)?, longTapAction: (() -> Void)? = nil, linkItemAction: ((TextLinkItemActionType, TextLinkItem) -> Void)? = nil, tag: Any? = nil) {
        self.presentationData = presentationData
        self.label = label
        self.text = text
        self.style = style
        self.labelColor = labelColor
        self.textColor = textColor
        self.enabledEntityTypes = enabledEntityTypes
        self.multiline = multiline
        self.selected = selected
        self.sectionId = sectionId
        self.action = action
        self.longTapAction = longTapAction
        self.linkItemAction = linkItemAction
        self.tag = tag
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ItemListTextWithLabelItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply(.None) })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ItemListTextWithLabelItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(animation)
                        })
                    }
                }
            }
        }
    }
    
    public var selectable: Bool {
        return self.action != nil
    }
    
    public func selected(listView: ListView) {
        listView.clearHighlightAnimated(true)
        self.action?()
    }
}

public class ItemListTextWithLabelItemNode: ListViewItemNode {
    let labelNode: TextNode
    let textNode: TextNode
    
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private var linkHighlightingNode: LinkHighlightingNode?
    private var selectionNode: ItemListSelectableControlNode?
    private let maskNode: ASImageNode
    
    public var item: ItemListTextWithLabelItem?
    
    override public var canBeLongTapped: Bool {
        return true
    }
    
    public init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        self.labelNode.contentMode = .left
        self.labelNode.contentsScale = UIScreen.main.scale
        
        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.contentMode = .left
        self.textNode.contentsScale = UIScreen.main.scale
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.isAccessibilityElement = true
        
        self.addSubnode(self.labelNode)
        self.addSubnode(self.textNode)
    }
    
    override public func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { [weak self] point in
            if let strongSelf = self, strongSelf.linkItemAtPoint(point) != nil {
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
    
    public func asyncLayout() -> (_ item: ItemListTextWithLabelItem, _ params: ListViewItemLayoutParams, _ insets: ItemListNeighbors) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        
        let currentItem = self.item
        
        let selectionNodeLayout = ItemListSelectableControlNode.asyncLayout(self.selectionNode)
        
        return { item, params, neighbors in
            var updatedTheme: PresentationTheme?
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            let insets = itemListNeighborsPlainInsets(neighbors)
            let leftInset: CGFloat = 16.0 + params.leftInset
            let rightInset: CGFloat = 8.0 + params.rightInset
            let separatorHeight = UIScreenPixel
            
            let labelFont = Font.regular(item.presentationData.fontSize.itemListBaseLabelFontSize)
            let textFont = Font.regular(item.presentationData.fontSize.itemListBaseFontSize)
            let textBoldFont = Font.medium(item.presentationData.fontSize.itemListBaseFontSize)
            let textItalicFont = Font.italic(item.presentationData.fontSize.itemListBaseFontSize)
            let textBoldItalicFont = Font.semiboldItalic(item.presentationData.fontSize.itemListBaseFontSize)
            let textFixedFont = Font.regular(item.presentationData.fontSize.itemListBaseFontSize)
            
            var leftOffset: CGFloat = 0.0
            var selectionNodeWidthAndApply: (CGFloat, (CGSize, Bool) -> ItemListSelectableControlNode)?
            if let selected = item.selected {
                let (selectionWidth, selectionApply) = selectionNodeLayout(item.presentationData.theme.list.itemCheckColors.strokeColor, item.presentationData.theme.list.itemCheckColors.fillColor, item.presentationData.theme.list.itemCheckColors.foregroundColor, selected, false)
                selectionNodeWidthAndApply = (selectionWidth, selectionApply)
                leftOffset += selectionWidth - 8.0
            }
            
            let labelColor: UIColor
            switch item.labelColor {
            case .primary:
                labelColor = item.presentationData.theme.list.itemPrimaryTextColor
            case .accent:
                labelColor = item.presentationData.theme.list.itemAccentColor
            case .highlighted:
                labelColor = item.presentationData.theme.list.itemHighlightedColor
            }
            let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.label, font: labelFont, textColor: labelColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftOffset - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let entities = generateTextEntities(item.text, enabledTypes: item.enabledEntityTypes)
            let baseColor: UIColor
            switch item.textColor {
            case .primary:
                baseColor = item.presentationData.theme.list.itemPrimaryTextColor
            case .accent:
                baseColor = item.presentationData.theme.list.itemAccentColor
            case .highlighted:
                baseColor = item.presentationData.theme.list.itemHighlightedColor
            }
            let string = stringWithAppliedEntities(item.text, entities: entities, baseColor: baseColor, linkColor: item.presentationData.theme.list.itemAccentColor, baseFont: textFont, linkFont: textFont, boldFont: textBoldFont, italicFont: textItalicFont, boldItalicFont: textBoldItalicFont, fixedFont: textFixedFont, blockQuoteFont: textFont, message: nil)
            
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: string, backgroundColor: nil, maximumNumberOfLines: item.multiline ? 0 : 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftOffset - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let contentSize = CGSize(width: params.width, height: textLayout.size.height + labelLayout.size.height + 22.0)
            let nodeLayout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            return (nodeLayout, { [weak self] animation in
                if let strongSelf = self {
                    let transition: ContainedViewLayoutTransition
                    if animation.isAnimated {
                        transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                    } else {
                        transition = .immediate
                    }
                    
                    strongSelf.item = item
                    
                    strongSelf.accessibilityLabel = item.label
                    strongSelf.accessibilityValue = item.text
                    
                    if let _ = updatedTheme {
                        switch item.style {
                        case .plain:
                            strongSelf.topStripeNode.backgroundColor = item.presentationData.theme.list.itemPlainSeparatorColor
                            strongSelf.bottomStripeNode.backgroundColor = item.presentationData.theme.list.itemPlainSeparatorColor
                            strongSelf.backgroundNode.backgroundColor = item.presentationData.theme.list.plainBackgroundColor
                        case .blocks:
                            strongSelf.topStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                            strongSelf.bottomStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                            strongSelf.backgroundNode.backgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                        }
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                    }
                    
                    let _ = labelApply()
                    let _ = textApply()
                    
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
                    
                    let labelFrame = CGRect(origin: CGPoint(x: leftOffset + leftInset, y: 11.0), size: labelLayout.size)
                    strongSelf.labelNode.frame = labelFrame
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: leftOffset + leftInset, y: labelFrame.maxY + 3.0), size: textLayout.size)
                    
                    let leftInset: CGFloat
                    switch item.style {
                        case .plain:
                            leftInset = 16.0 + params.leftInset + leftOffset
                            
                            if strongSelf.backgroundNode.supernode != nil {
                                strongSelf.backgroundNode.removeFromSupernode()
                            }
                            if strongSelf.topStripeNode.supernode != nil {
                                strongSelf.topStripeNode.removeFromSupernode()
                            }
                            if strongSelf.bottomStripeNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 0)
                            }
                            if strongSelf.maskNode.supernode != nil {
                                strongSelf.maskNode.removeFromSupernode()
                            }
                            strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: leftInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - leftInset, height: separatorHeight))
                        case .blocks:
                            leftInset = 16.0 + params.leftInset
                            
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
                            switch neighbors.top {
                                case .sameSection(false):
                                    strongSelf.topStripeNode.isHidden = true
                                default:
                                    hasTopCorners = true
                                    strongSelf.topStripeNode.isHidden = hasCorners
                            }
                            let bottomStripeInset: CGFloat
                            let bottomStripeOffset: CGFloat
                            switch neighbors.bottom {
                                case .sameSection(false):
                                    bottomStripeInset = 16.0 + params.leftInset
                                    bottomStripeOffset = -separatorHeight
                                    strongSelf.bottomStripeNode.isHidden = false
                                default:
                                    bottomStripeInset = 0.0
                                    bottomStripeOffset = 0.0
                                    hasBottomCorners = true
                                    strongSelf.bottomStripeNode.isHidden = hasCorners
                            }
                        
                            strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                        
                            strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                            strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                            strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: separatorHeight))
                            strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: params.width - bottomStripeInset, height: separatorHeight))
                    }
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: contentSize.height + UIScreenPixel + UIScreenPixel))
                }
            })
        }
    }
    
    override public func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        if highlighted && self.linkItemAtPoint(point) == nil && self.selectionNode == nil {
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                var anchorNode: ASDisplayNode?
                if self.bottomStripeNode.supernode != nil {
                    anchorNode = self.bottomStripeNode
                } else if self.topStripeNode.supernode != nil {
                    anchorNode = self.topStripeNode
                } else if self.backgroundNode.supernode != nil {
                    anchorNode = self.backgroundNode
                }
                if let anchorNode = anchorNode {
                    self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: anchorNode)
                } else {
                    self.addSubnode(self.highlightedBackgroundNode)
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
    
    @objc private func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                switch gesture {
                case .tap, .longTap:
                    if let item = self.item, let linkItem = self.linkItemAtPoint(location) {
                        item.linkItemAction?(gesture == .tap ? .tap : .longTap, linkItem)
                    }
                default:
                    break
                }
            }
        default:
            break
        }
    }
    
    private func linkItemAtPoint(_ point: CGPoint) -> TextLinkItem? {
        let textNodeFrame = self.textNode.frame
        if let (_, attributes) = self.textNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
            if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                return .url(url: url, concealed: false)
            } else if let peerName = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                return .mention(peerName)
            } else if let hashtag = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
                return .hashtag(hashtag.peerName, hashtag.hashtag)
            } else {
                return nil
            }
        }
        return nil
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    override public func longTapped() {
        self.item?.longTapAction?()
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
    
    public var tag: Any? {
        return self.item?.tag
    }
}
