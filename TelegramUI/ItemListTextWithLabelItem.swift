import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit

final class ItemListTextWithLabelItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let label: String
    let text: String
    let enabledEntitiyTypes: EnabledEntityTypes
    let multiline: Bool
    let sectionId: ItemListSectionId
    let action: (() -> Void)?
    let longTapAction: (() -> Void)?
    let linkItemAction: ((TextLinkItemActionType, TextLinkItem) -> Void)?
    
    let tag: Any?
    
    init(theme: PresentationTheme, label: String, text: String, enabledEntitiyTypes: EnabledEntityTypes, multiline: Bool, sectionId: ItemListSectionId, action: (() -> Void)?, longTapAction: (() -> Void)? = nil, linkItemAction: ((TextLinkItemActionType, TextLinkItem) -> Void)? = nil, tag: Any? = nil) {
        self.theme = theme
        self.label = label
        self.text = text
        self.enabledEntitiyTypes = enabledEntitiyTypes
        self.multiline = multiline
        self.sectionId = sectionId
        self.action = action
        self.longTapAction = longTapAction
        self.linkItemAction = linkItemAction
        self.tag = tag
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        async {
            let node = ItemListTextWithLabelItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                return (nil, { apply() })
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        if let node = node as? ItemListTextWithLabelItemNode {
            Queue.mainQueue().async {
                let makeLayout = node.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, {
                            apply()
                        })
                    }
                }
            }
        }
    }
    
    var selectable: Bool {
        return self.action != nil
    }
    
    func selected(listView: ListView) {
        listView.clearHighlightAnimated(true)
        self.action?()
    }
}

private let labelFont = Font.regular(14.0)
private let textFont = Font.regular(17.0)
private let textBoldFont = Font.medium(17.0)
private let textItalicFont = Font.italic(17.0)
private let textFixedFont = Font.regular(17.0)

class ItemListTextWithLabelItemNode: ListViewItemNode {
    let labelNode: TextNode
    let textNode: TextNode
    
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private var linkHighlightingNode: LinkHighlightingNode?
    
    var item: ItemListTextWithLabelItem?
    
    override var canBeLongTapped: Bool {
        return true
    }
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.labelNode = TextNode()
        self.labelNode.isLayerBacked = true
        self.labelNode.contentMode = .left
        self.labelNode.contentsScale = UIScreen.main.scale
        
        self.textNode = TextNode()
        self.textNode.isLayerBacked = true
        self.textNode.contentMode = .left
        self.textNode.contentsScale = UIScreen.main.scale
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.labelNode)
        self.addSubnode(self.textNode)
    }
    
    override func didLoad() {
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
    
    func asyncLayout() -> (_ item: ItemListTextWithLabelItem, _ params: ListViewItemLayoutParams, _ insets: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        
        let currentItem = self.item
        
        return { item, params, neighbors in
            var updatedTheme: PresentationTheme?
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
            }
            
            let insets = itemListNeighborsPlainInsets(neighbors)
            let leftInset: CGFloat = 35.0 + params.leftInset
            let rightInset: CGFloat = 8.0 + params.rightInset
            let separatorHeight = UIScreenPixel
            
            let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.label, font: labelFont, textColor: item.theme.list.itemAccentColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let entities = generateTextEntities(item.text, enabledTypes: item.enabledEntitiyTypes)
            let string = stringWithAppliedEntities(item.text, entities: entities, baseColor: item.theme.list.itemPrimaryTextColor, linkColor: item.theme.list.itemAccentColor, baseFont: textFont, linkFont: textFont, boldFont: textBoldFont, italicFont: textItalicFont, fixedFont: textFixedFont)
            
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: string, backgroundColor: nil, maximumNumberOfLines: item.multiline ? 0 : 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let contentSize = CGSize(width: params.width, height: textLayout.size.height + 39.0)
            let nodeLayout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            return (nodeLayout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = item.theme.list.itemPlainSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemPlainSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = item.theme.list.plainBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.theme.list.itemHighlightedBackgroundColor
                    }
                    
                    let _ = labelApply()
                    let _ = textApply()
                    
                    strongSelf.labelNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 11.0), size: labelLayout.size)
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 31.0), size: textLayout.size)
                    
                    let leftInset: CGFloat
                    let style = ItemListStyle.plain
                    switch style {
                        case .plain:
                            leftInset = 35.0 + params.leftInset
                            
                            if strongSelf.backgroundNode.supernode != nil {
                                strongSelf.backgroundNode.removeFromSupernode()
                            }
                            if strongSelf.topStripeNode.supernode != nil {
                                strongSelf.topStripeNode.removeFromSupernode()
                            }
                            if strongSelf.bottomStripeNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 0)
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
                            switch neighbors.top {
                                case .sameSection(false):
                                    strongSelf.topStripeNode.isHidden = true
                                default:
                                    strongSelf.topStripeNode.isHidden = false
                            }
                            let bottomStripeInset: CGFloat
                            let bottomStripeOffset: CGFloat
                            switch neighbors.bottom {
                                case .sameSection(false):
                                    bottomStripeInset = 16.0 + params.leftInset
                                    bottomStripeOffset = -separatorHeight
                                default:
                                    bottomStripeInset = 0.0
                                    bottomStripeOffset = 0.0
                            }
                            strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                            strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: separatorHeight))
                            strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: params.width - bottomStripeInset, height: separatorHeight))
                    }
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: contentSize.height + UIScreenPixel + UIScreenPixel))
                }
            })
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
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
    
    @objc func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
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
            if let url = attributes[NSAttributedStringKey(rawValue: TextNode.UrlAttribute)] as? String {
                return .url(url)
            } else if let peerName = attributes[NSAttributedStringKey(rawValue: TextNode.TelegramPeerTextMentionAttribute)] as? String {
                return .mention(peerName)
            } else if let hashtag = attributes[NSAttributedStringKey(rawValue: TextNode.TelegramHashtagAttribute)] as? TelegramHashtag {
                return .hashtag(hashtag.peerName, hashtag.hashtag)
            } else {
                return nil
            }
        }
        return nil
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    override func longTapped() {
        self.item?.longTapAction?()
    }
    
    private func updateTouchesAtPoint(_ point: CGPoint?) {
        if let item = self.item {
            var rects: [CGRect]?
            if let point = point {
                let textNodeFrame = self.textNode.frame
                if let (index, attributes) = self.textNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
                    let possibleNames: [String] = [
                        TextNode.UrlAttribute,
                        TextNode.TelegramPeerMentionAttribute,
                        TextNode.TelegramPeerTextMentionAttribute,
                        TextNode.TelegramBotCommandAttribute,
                        TextNode.TelegramHashtagAttribute
                    ]
                    for name in possibleNames {
                        if let _ = attributes[NSAttributedStringKey(rawValue: name)] {
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
                    linkHighlightingNode = LinkHighlightingNode(color: item.theme.list.itemAccentColor.withAlphaComponent(0.5))
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
    
    var tag: Any? {
        return self.item?.tag
    }
}
