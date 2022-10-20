import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import TextFormat
import Markdown

public enum ItemListTextItemText {
    case plain(String)
    case large(String)
    case markdown(String)
}

public enum ItemListTextItemLinkAction {
    case tap(String)
}

public class ItemListTextItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let text: ItemListTextItemText
    public let sectionId: ItemListSectionId
    let linkAction: ((ItemListTextItemLinkAction) -> Void)?
    let style: ItemListStyle
    let trimBottomInset: Bool
    public let isAlwaysPlain: Bool = true
    public let tag: ItemListItemTag?
    
    public init(presentationData: ItemListPresentationData, text: ItemListTextItemText, sectionId: ItemListSectionId, linkAction: ((ItemListTextItemLinkAction) -> Void)? = nil, style: ItemListStyle = .blocks, tag: ItemListItemTag? = nil, trimBottomInset: Bool = false) {
        self.presentationData = presentationData
        self.text = text
        self.sectionId = sectionId
        self.linkAction = linkAction
        self.style = style
        self.trimBottomInset = trimBottomInset
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
    private let titleNode: TextNode
    private let activateArea: AccessibilityAreaNode
    
    private var item: ItemListTextItem?
    
    public var tag: ItemListItemTag? {
        return self.item?.tag
    }
    
    public init() {
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.activateArea = AccessibilityAreaNode()
        self.activateArea.accessibilityTraits = .staticText
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.activateArea)
    }
    
    override public func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { _ in
            return .waitForSingleTap
        }
        self.view.addGestureRecognizer(recognizer)
    }
    
    public func asyncLayout() -> (_ item: ItemListTextItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        
        return { item, params, neighbors in
            let leftInset: CGFloat = 15.0
            let topInset: CGFloat = 7.0
            var bottomInset: CGFloat = 7.0
            
            let titleFont = Font.regular(item.presentationData.fontSize.itemListBaseHeaderFontSize)
            let largeTitleFont = Font.semibold(floor(item.presentationData.fontSize.itemListBaseFontSize))
            let titleBoldFont = Font.semibold(item.presentationData.fontSize.itemListBaseHeaderFontSize)
            
            let attributedText: NSAttributedString
            switch item.text {
            case let .plain(text):
                attributedText = NSAttributedString(string: text, font: titleFont, textColor: item.presentationData.theme.list.freeTextColor)
            case let .large(text):
                attributedText = NSAttributedString(string: text, font: largeTitleFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor)
            case let .markdown(text):
                attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: titleFont, textColor: item.presentationData.theme.list.freeTextColor), bold: MarkdownAttributeSet(font: titleBoldFont, textColor: item.presentationData.theme.list.freeTextColor), link: MarkdownAttributeSet(font: titleFont, textColor: item.presentationData.theme.list.itemAccentColor), linkAttribute: { contents in
                    return (TelegramTextAttributes.URL, contents)
                }))
            }
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset * 2.0 - params.leftInset - params.rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let contentSize: CGSize
            
            var insets = itemListNeighborsGroupedInsets(neighbors, params)
            if case .large = item.text {
                insets.top = 14.0
                bottomInset = -6.0
            }
            contentSize = CGSize(width: params.width, height: titleLayout.size.height + topInset + bottomInset)
            
            if item.trimBottomInset {
                insets.bottom -= 44.0
            }
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                    strongSelf.activateArea.accessibilityLabel = attributedText.string
                    
                    let _ = titleApply()
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset + params.leftInset, y: topInset), size: titleLayout.size)
                }
            })
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
                        case .tap:
                            let titleFrame = self.titleNode.frame
                            if let item = self.item, titleFrame.contains(location) {
                                if let (_, attributes) = self.titleNode.attributesAtPoint(CGPoint(x: location.x - titleFrame.minX, y: location.y - titleFrame.minY)) {
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
}
