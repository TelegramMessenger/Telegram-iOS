import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Markdown

enum ItemListTextItemText {
    case plain(String)
    case markdown(String)
}

enum ItemListTextItemLinkAction {
    case tap(String)
}

class ItemListTextItem: ListViewItem, ItemListItem {
    let theme: WalletTheme
    let text: ItemListTextItemText
    let sectionId: ItemListSectionId
    let linkAction: ((ItemListTextItemLinkAction) -> Void)?
    let style: ItemListStyle
    let isAlwaysPlain: Bool = true
    
    init(theme: WalletTheme, text: ItemListTextItemText, sectionId: ItemListSectionId, linkAction: ((ItemListTextItemLinkAction) -> Void)? = nil, style: ItemListStyle = .blocks) {
        self.theme = theme
        self.text = text
        self.sectionId = sectionId
        self.linkAction = linkAction
        self.style = style
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
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
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
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

private let titleFont = Font.regular(14.0)
private let titleBoldFont = Font.semibold(14.0)

class ItemListTextItemNode: ListViewItemNode {
    private let titleNode: TextNode
    private let activateArea: AccessibilityAreaNode
    
    private var item: ItemListTextItem?
    
    init() {
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
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { _ in
            return .waitForSingleTap
        }
        self.view.addGestureRecognizer(recognizer)
    }
    
    func asyncLayout() -> (_ item: ItemListTextItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        
        return { item, params, neighbors in
            let leftInset: CGFloat = 15.0 + params.leftInset
            let verticalInset: CGFloat = 7.0
            
            let attributedText: NSAttributedString
            switch item.text {
                case let .plain(text):
                    attributedText = NSAttributedString(string: text, font: titleFont, textColor: item.theme.list.freeTextColor)
                case let .markdown(text):
                    attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: titleFont, textColor: item.theme.list.freeTextColor), bold: MarkdownAttributeSet(font: titleBoldFont, textColor: item.theme.list.freeTextColor), link: MarkdownAttributeSet(font: titleFont, textColor: item.theme.list.itemAccentColor), linkAttribute: { contents in
                        return ("URL", contents)
                    }))
            }
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - params.rightInset - leftInset * 2.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let contentSize: CGSize
            
            contentSize = CGSize(width: params.width, height: titleLayout.size.height + verticalInset + verticalInset)
            let insets = itemListNeighborsGroupedInsets(neighbors)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                    strongSelf.activateArea.accessibilityLabel = attributedText.string
                    
                    strongSelf.accessibilityLabel = attributedText.string
                    
                    let _ = titleApply()
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: verticalInset), size: titleLayout.size)
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
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
                                    if let url = attributes[NSAttributedString.Key(rawValue: "URL")] as? String {
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
