import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import TextFormat
import AccountContext

public enum ItemListMultilineTextBaseFont {
    case `default`
    case monospace
}

public class ItemListMultilineTextItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let text: String
    let enabledEntityTypes: EnabledEntityTypes
    let font: ItemListMultilineTextBaseFont
    public let sectionId: ItemListSectionId
    let style: ItemListStyle
    let action: (() -> Void)?
    let longTapAction: (() -> Void)?
    let linkItemAction: ((TextLinkItemActionType, TextLinkItem) -> Void)?
    
    let tag: Any?
    
    public let selectable: Bool
    
    public init(presentationData: ItemListPresentationData, text: String, enabledEntityTypes: EnabledEntityTypes, font: ItemListMultilineTextBaseFont = .default, sectionId: ItemListSectionId, style: ItemListStyle, action: (() -> Void)? = nil, longTapAction: (() -> Void)? = nil, linkItemAction: ((TextLinkItemActionType, TextLinkItem) -> Void)? = nil, tag: Any? = nil) {
        self.presentationData = presentationData
        self.text = text
        self.enabledEntityTypes = enabledEntityTypes
        self.font = font
        self.sectionId = sectionId
        self.style = style
        self.action = action
        self.longTapAction = longTapAction
        self.linkItemAction = linkItemAction
        self.tag = tag
        
        self.selectable = action != nil
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ItemListMultilineTextItemNode()
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
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ItemListMultilineTextItemNode {
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
    
    public func selected(listView: ListView){
        listView.clearHighlightAnimated(true)
        self.action?()
    }
}

public class ItemListMultilineTextItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private var linkHighlightingNode: LinkHighlightingNode?
    
    private let textNode: TextNode
    
    private let activateArea: AccessibilityAreaNode
    
    private var item: ItemListMultilineTextItem?
    
    public var tag: Any? {
        return self.item?.tag
    }
    
    override public var canBeLongTapped: Bool {
        return true
    }
    
    public init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        
        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.contentMode = .left
        self.textNode.contentsScale = UIScreen.main.scale
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.activateArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.textNode)
        self.addSubnode(self.activateArea)
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
    
    public func asyncLayout() -> (_ item: ItemListMultilineTextItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            var updatedTheme: PresentationTheme?
            
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            let textColor: UIColor = item.presentationData.theme.list.itemPrimaryTextColor
            
            let leftInset: CGFloat
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            
            switch item.style {
                case .plain:
                    itemBackgroundColor = item.presentationData.theme.list.plainBackgroundColor
                    itemSeparatorColor = item.presentationData.theme.list.itemPlainSeparatorColor
                    leftInset = 16.0 + params.leftInset
                case .blocks:
                    itemBackgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                    itemSeparatorColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                    leftInset = 16.0 + params.rightInset
            }
            
            let fontSize = item.presentationData.fontSize.itemListBaseFontSize
            
            var baseFont = Font.regular(fontSize)
            var linkFont = baseFont
            var boldFont = Font.medium(fontSize)
            var italicFont = Font.italic(fontSize)
            var boldItalicFont = Font.semiboldItalic(fontSize)
            let titleFixedFont = Font.monospace(fontSize)
            if case .monospace = item.font {
                baseFont = Font.monospace(fontSize)
                linkFont = Font.monospace(fontSize)
                boldFont = Font.semiboldMonospace(fontSize)
                italicFont = Font.italicMonospace(fontSize)
                boldItalicFont = Font.semiboldItalicMonospace(fontSize)
            }
            
            let entities = generateTextEntities(item.text, enabledTypes: item.enabledEntityTypes)
            let string = stringWithAppliedEntities(item.text, entities: entities, baseColor: textColor, linkColor: item.presentationData.theme.list.itemAccentColor, baseFont: baseFont, linkFont: linkFont, boldFont: boldFont, italicFont: italicFont, boldItalicFont: boldItalicFont, fixedFont: titleFixedFont, blockQuoteFont: baseFont)
            
            let (titleLayout, titleApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: string, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset * 2.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            switch item.style {
                case .plain:
                    contentSize = CGSize(width: params.width, height: titleLayout.size.height + 22.0)
                    insets = itemListNeighborsPlainInsets(neighbors)
                case .blocks:
                    contentSize = CGSize(width: params.width, height: titleLayout.size.height + 22.0)
                    insets = itemListNeighborsGroupedInsets(neighbors, params)
            }
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                    strongSelf.activateArea.accessibilityLabel = item.text
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                    }
                    
                    let _ = titleApply()
                    
                    switch item.style {
                    case .plain:
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
                                bottomStripeInset = 16.0
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
                        strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                        strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    }
                    
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 11.0), size: titleLayout.size)
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: layout.contentSize.height + UIScreenPixel + UIScreenPixel))
                }
            })
        }
    }
    
    override public func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        if highlighted && self.linkItemAtPoint(point) == nil {
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
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
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
}
