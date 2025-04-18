import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import TextFormat
import Markdown
import TextNodeWithEntities
import AccountContext

public enum ItemListTextItemText {
    case plain(String)
    case large(String)
    case markdown(String)
    case custom(context: AccountContext, string: NSAttributedString)
    
    var text: String {
        switch self {
        case let .plain(text), let .large(text), let .markdown(text):
            return text
        case let .custom(_, string):
            return string.string
        }
    }
}

public enum ItemListTextItemLinkAction {
    case tap(String)
}

public enum ItemListTextItemTextAlignment {
    case natural
    case center
    
    var textAlignment: NSTextAlignment {
        switch self {
        case .natural:
            return .natural
        case .center:
            return .center
        }
    }
}

public enum ItemListTextItemTextSize {
    case generic
    case larger
}

public class ItemListTextItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let text: ItemListTextItemText
    public let sectionId: ItemListSectionId
    let linkAction: ((ItemListTextItemLinkAction) -> Void)?
    let style: ItemListStyle
    let textSize: ItemListTextItemTextSize
    let textAlignment: ItemListTextItemTextAlignment
    let trimBottomInset: Bool
    let additionalInsets: UIEdgeInsets
    public let isAlwaysPlain: Bool = true
    public let tag: ItemListItemTag?
    
    public init(presentationData: ItemListPresentationData, text: ItemListTextItemText, sectionId: ItemListSectionId, linkAction: ((ItemListTextItemLinkAction) -> Void)? = nil, style: ItemListStyle = .blocks, textSize: ItemListTextItemTextSize = .generic, textAlignment: ItemListTextItemTextAlignment = .natural, tag: ItemListItemTag? = nil, trimBottomInset: Bool = false, additionalInsets: UIEdgeInsets = .zero) {
        self.presentationData = presentationData
        self.text = text
        self.sectionId = sectionId
        self.linkAction = linkAction
        self.style = style
        self.textSize = textSize
        self.textAlignment = textAlignment
        self.trimBottomInset = trimBottomInset
        self.additionalInsets = additionalInsets
        self.tag = tag
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ItemListTextItemNode()
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
            guard let nodeValue = node() as? ItemListTextItemNode else {
                assertionFailure()
                return
            }
        
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

public class ItemListTextItemNode: ListViewItemNode, ItemListItemNode {
    private let textNode: TextNodeWithEntities
    private var linkHighlightingNode: LinkHighlightingNode?
    private let activateArea: AccessibilityAreaNode
    
    private var item: ItemListTextItem?
    
    private var chevronImage: UIImage?
    
    public var tag: ItemListItemTag? {
        return self.item?.tag
    }
    
    public init() {
        self.textNode = TextNodeWithEntities()
        self.textNode.textNode.isUserInteractionEnabled = false
        self.textNode.textNode.contentMode = .left
        self.textNode.textNode.contentsScale = UIScreen.main.scale
        
        self.activateArea = AccessibilityAreaNode()
        self.activateArea.accessibilityTraits = .staticText
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.textNode.textNode)
        self.addSubnode(self.activateArea)
    }
    
    override public func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { _ in
            return .waitForSingleTap
        }
        recognizer.highlight = { [weak self] point in
            if let strongSelf = self {
                strongSelf.updateTouchesAtPoint(point)
            }
        }
        self.view.addGestureRecognizer(recognizer)
    }
    
    public func asyncLayout() -> (_ item: ItemListTextItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNodeWithEntities.asyncLayout(self.textNode)
        let currentChevronImage = self.chevronImage
        let currentItem = self.item
        
        return { [weak self] item, params, neighbors in
            let leftInset: CGFloat = 15.0
            var topInset: CGFloat = 7.0
            var bottomInset: CGFloat = 7.0
            
            var titleFont = Font.regular(item.presentationData.fontSize.itemListBaseHeaderFontSize)
            var textColor: UIColor = item.presentationData.theme.list.freeTextColor
            if case .large = item.text {
                titleFont = Font.semibold(floor(item.presentationData.fontSize.itemListBaseFontSize))
            } else if case .larger = item.textSize {
                titleFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize / 17.0 * 15.0))
                textColor = item.presentationData.theme.list.itemSecondaryTextColor
            }
            let titleBoldFont = Font.semibold(item.presentationData.fontSize.itemListBaseHeaderFontSize)
                        
            var themeUpdated = false
            var chevronImage = currentChevronImage
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                themeUpdated = true
            }
            
            let attributedText: NSAttributedString
            switch item.text {
            case let .plain(text):
                attributedText = NSAttributedString(string: text, font: titleFont, textColor: item.presentationData.theme.list.freeTextColor)
            case let .large(text):
                attributedText = NSAttributedString(string: text, font: titleFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor)
            case let .markdown(text):
                let mutableAttributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: titleFont, textColor: textColor), bold: MarkdownAttributeSet(font: titleBoldFont, textColor: textColor), link: MarkdownAttributeSet(font: titleFont, textColor: item.presentationData.theme.list.itemAccentColor), linkAttribute: { contents in
                    return (TelegramTextAttributes.URL, contents)
                }), textAlignment: item.textAlignment.textAlignment).mutableCopy() as! NSMutableAttributedString
                if let _ = text.range(of: ">]"), let range = mutableAttributedText.string.range(of: ">") {
                    if themeUpdated || currentChevronImage == nil {
                        switch item.textSize {
                        case .generic:
                            chevronImage = generateTintedImage(image: UIImage(bundleImageName: "Contact List/SubtitleArrow"), color: item.presentationData.theme.list.itemAccentColor)
                        case .larger:
                            chevronImage = generateTintedImage(image: UIImage(bundleImageName: "Settings/TextArrowRight"), color: item.presentationData.theme.list.itemAccentColor)
                        }
                    }
                    if let chevronImage {
                        mutableAttributedText.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: mutableAttributedText.string))
                    }
                }
                attributedText = mutableAttributedText
            case let .custom(_, string):
                attributedText = string
            }
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset * 2.0 - params.leftInset - params.rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: item.textAlignment.textAlignment, cutout: nil, insets: UIEdgeInsets()))
            
            let contentSize: CGSize
            
            var insets = itemListNeighborsGroupedInsets(neighbors, params)
            switch item.text {
            case .large, .custom:
                insets.top = 14.0
                bottomInset = -6.0
            default:
                break
            }
            
            topInset += item.additionalInsets.top
            bottomInset += item.additionalInsets.bottom
            
            contentSize = CGSize(width: params.width, height: titleLayout.size.height + topInset + bottomInset)
            
            if item.trimBottomInset {
                insets.bottom -= 44.0
            }
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, {
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.chevronImage = chevronImage
                    
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                    strongSelf.activateArea.accessibilityLabel = attributedText.string
                    
                    var textArguments: TextNodeWithEntities.Arguments?
                    if case let .custom(context, _) = item.text {
                        textArguments = TextNodeWithEntities.Arguments(
                            context: context,
                            cache: context.animationCache,
                            renderer: context.animationRenderer,
                            placeholderColor: item.presentationData.theme.list.mediaPlaceholderColor,
                            attemptSynchronous: true
                        )
                    }
                    let _ = titleApply(textArguments)
                    
                    let titleOrigin: CGFloat
                    switch item.textAlignment {
                    case .natural:
                        titleOrigin = leftInset + params.leftInset
                    case .center:
                        titleOrigin = floorToScreenPixels((contentSize.width - titleLayout.size.width) / 2.0)
                    }

                    strongSelf.textNode.textNode.frame = CGRect(origin: CGPoint(x: titleOrigin, y: topInset), size: titleLayout.size)
                }
            })
        }
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
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
                        case .tap:
                            let titleFrame = self.textNode.textNode.frame
                            if let item = self.item, titleFrame.contains(location) {
                                if let (_, attributes) = self.textNode.textNode.attributesAtPoint(CGPoint(x: location.x - titleFrame.minX, y: location.y - titleFrame.minY)) {
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
                let textNodeFrame = self.textNode.textNode.frame
                if let (index, attributes) = self.textNode.textNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
                    let possibleNames: [String] = [
                        TelegramTextAttributes.URL,
                        TelegramTextAttributes.PeerMention,
                        TelegramTextAttributes.PeerTextMention,
                        TelegramTextAttributes.BotCommand,
                        TelegramTextAttributes.Hashtag
                    ]
                    for name in possibleNames {
                        if let _ = attributes[NSAttributedString.Key(rawValue: name)] {
                            rects = self.textNode.textNode.attributeRects(name: name, at: index)
                            break
                        }
                    }
                }
            }
            
            if var rects {
                let linkHighlightingNode: LinkHighlightingNode
                if let current = self.linkHighlightingNode {
                    linkHighlightingNode = current
                } else {
                    linkHighlightingNode = LinkHighlightingNode(color: item.presentationData.theme.list.itemAccentColor.withAlphaComponent(0.2))
                    self.linkHighlightingNode = linkHighlightingNode
                    self.insertSubnode(linkHighlightingNode, belowSubnode: self.textNode.textNode)
                }
                if item.text.text.contains(">]"), var lastRect = rects.last {
                    lastRect.size.width += 8.0
                    rects[rects.count - 1] = lastRect
                }
                linkHighlightingNode.frame = self.textNode.textNode.frame
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
