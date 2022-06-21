import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils

private enum RevealOptionKey: Int32 {
    case delete
}

public class WebSearchRecentQueryItem: ListViewItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let account: Account
    let query: String
    let tapped: (String) -> Void
    let deleted: (String) -> Void
    
    let header: ListViewItemHeader?
    
    public init(account: Account, theme: PresentationTheme, strings: PresentationStrings, query: String, tapped: @escaping (String) -> Void, deleted: @escaping (String) -> Void, header: ListViewItemHeader) {
        self.theme = theme
        self.strings = strings
        self.account = account
        self.query = query
        self.tapped = tapped
        self.deleted = deleted
        self.header = header
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = WebSearchRecentQueryItemNode()
            let makeLayout = node.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(self, params, nextItem == nil, !(previousItem is WebSearchRecentQueryItem))
            node.contentSize = nodeLayout.contentSize
            node.insets = nodeLayout.insets
            
            completion(node, nodeApply)
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? WebSearchRecentQueryItemNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params, nextItem == nil, !(previousItem is WebSearchRecentQueryItem))
                    Queue.mainQueue().async {
                        completion(nodeLayout, { info in
                            apply().1(info)
                        })
                    }
                }
            }
        }
    }
    
    public var selectable: Bool {
        return true
    }
    
    public func selected(listView: ListView) {
        listView.clearHighlightAnimated(true)
        self.tapped(self.query)
    }
}

class WebSearchRecentQueryItemNode: ItemListRevealOptionsItemNode {
    private let backgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private var textNode: TextNode?
    
    private var item: WebSearchRecentQueryItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    required init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = self.item {
            let makeLayout = self.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(item, params, nextItem == nil, previousItem == nil)
            self.contentSize = nodeLayout.contentSize
            self.insets = nodeLayout.insets
            let _ = nodeApply()
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        if highlighted {
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
    
    func asyncLayout() -> (_ item: WebSearchRecentQueryItem, _ params: ListViewItemLayoutParams, _ last: Bool, _ firstWithHeader: Bool) -> (ListViewItemNodeLayout, () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) {
        let currentItem = self.item
        
        let textLayout = TextNode.asyncLayout(self.textNode)
        
        return { [weak self] item, params, last, firstWithHeader in
            
            let leftInset: CGFloat = 15.0 + params.leftInset
            let rightInset: CGFloat = params.rightInset
            
            let attributedString = NSAttributedString(string: item.query, font: Font.regular(17.0), textColor: item.theme.list.itemPrimaryTextColor)
            let textApply = textLayout(TextNodeLayoutArguments(attributedString: attributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset - 15.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: 44.0), insets: UIEdgeInsets(top: firstWithHeader ? 29.0 : 0.0, left: 0.0, bottom: 0.0, right: 0.0))
            
            return (nodeLayout, { [weak self] in
                var updatedTheme: PresentationTheme?
                if currentItem?.theme !== item.theme {
                    updatedTheme = item.theme
                }
                
                return (nil, { _ in
                    if let strongSelf = self {
                        strongSelf.item = item
                        strongSelf.layoutParams = params
                        
                        if let _ = updatedTheme {
                            strongSelf.separatorNode.backgroundColor = item.theme.list.itemPlainSeparatorColor
                            strongSelf.backgroundNode.backgroundColor = item.theme.list.plainBackgroundColor
                            strongSelf.highlightedBackgroundNode.backgroundColor = item.theme.list.itemHighlightedBackgroundColor
                        }
                        
                        let (textLayout, textApply) = textApply
                        let textNode = textApply()
                        if strongSelf.textNode == nil {
                            strongSelf.textNode = textNode
                            strongSelf.addSubnode(textNode)
                        }
                        
                        let textFrame = CGRect(origin: CGPoint(x: leftInset, y: floorToScreenPixels((44.0 - textLayout.size.height) / 2.0)), size: textLayout.size)
                        textNode.frame = textFrame

                        let separatorHeight = UIScreenPixel
                        let topHighlightInset: CGFloat = (firstWithHeader || !nodeLayout.insets.top.isZero) ? 0.0 : separatorHeight
                        
                        strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: nodeLayout.contentSize.width, height: nodeLayout.contentSize.height))
                        strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -nodeLayout.insets.top - topHighlightInset), size: CGSize(width: nodeLayout.size.width, height: nodeLayout.size.height + topHighlightInset))
                        strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: leftInset, y: nodeLayout.contentSize.height - separatorHeight), size: CGSize(width: nodeLayout.size.width, height: separatorHeight))
                        strongSelf.separatorNode.isHidden = last
                        
                        strongSelf.updateLayout(size: nodeLayout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                        
                        strongSelf.setRevealOptions((left: [], right: [ItemListRevealOption(key: RevealOptionKey.delete.rawValue, title: item.strings.Common_Delete, icon: .none, color: item.theme.list.itemDisclosureActions.destructive.fillColor, textColor: item.theme.list.itemDisclosureActions.destructive.foregroundColor)]))
                    }
                })
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.5, removeOnCompletion: false)
    }
    
    override public func headers() -> [ListViewItemHeader]? {
        if let item = self.item {
            return item.header.flatMap { [$0] }
        } else {
            return nil
        }
    }
    
    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        if let params = self.layoutParams, let textNode = self.textNode {
            let leftInset: CGFloat = 15.0 + params.leftInset
            
            var textFrame = textNode.frame
            textFrame.origin.x = leftInset + offset
            transition.updateFrame(node: textNode, frame: textFrame)
        }
    }
    
    override func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        if let item = self.item {
            switch option.key {
                case RevealOptionKey.delete.rawValue:
                    item.deleted(item.query)
                default:
                    break
            }
        }
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()
    }
}
