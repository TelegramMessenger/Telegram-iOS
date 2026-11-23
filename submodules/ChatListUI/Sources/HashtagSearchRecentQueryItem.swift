import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import TelegramCore
import TelegramPresentationData
import ItemListUI

private enum HashtagSearchRecentQueryRevealOptionKey: Int32 {
    case delete
}

public class HashtagSearchRecentQueryItem: ListViewItem {
    public var neighborDescriptor: AnyEquatable {
        return AnyEquatable(HeaderNeighborDescriptor(headerId: nil, headerFamily: .hashtagSearchRecentQuery))
    }

    let theme: PresentationTheme
    let strings: PresentationStrings
    let account: Account
    let query: String
    let clear: Bool
    let tapped: (String) -> Void
    let deleted: (String) -> Void
    
    let header: ListViewItemHeader? = nil
    
    public init(account: Account, theme: PresentationTheme, strings: PresentationStrings, query: String, clear: Bool, tapped: @escaping (String) -> Void, deleted: @escaping (String) -> Void) {
        self.theme = theme
        self.strings = strings
        self.account = account
        self.query = query
        self.clear = clear
        self.tapped = tapped
        self.deleted = deleted
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = HashtagSearchRecentQueryItemNode()
            let makeLayout = node.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(self, params, neighbors.next == nil, !(neighbors.previous?.base(HeaderNeighborFacet.self)?.headerFamily == .hashtagSearchRecentQuery))
            node.contentSize = nodeLayout.contentSize
            node.insets = nodeLayout.insets
            
            completion(node, nodeApply)
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? HashtagSearchRecentQueryItemNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params, neighbors.next == nil, !(neighbors.previous?.base(HeaderNeighborFacet.self)?.headerFamily == .hashtagSearchRecentQuery))
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

final class HashtagSearchRecentQueryItemNode: ItemListRevealOptionsItemNode {
    private let backgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private var textNode: TextNode?
    private let iconNode: ASImageNode
    
    private var item: HashtagSearchRecentQueryItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    required init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        
        super.init(layerBacked: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.iconNode)
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, neighbors: ListViewItemNeighbors) {
        if let item = self.item {
            let makeLayout = self.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(item, params, neighbors.next == nil, neighbors.previous == nil)
            self.contentSize = nodeLayout.contentSize
            self.insets = nodeLayout.insets
            let _ = nodeApply()
        }
    }
    

    
    func asyncLayout() -> (_ item: HashtagSearchRecentQueryItem, _ params: ListViewItemLayoutParams, _ last: Bool, _ firstWithHeader: Bool) -> (ListViewItemNodeLayout, () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) {
        let currentItem = self.item
        
        let textLayout = TextNode.asyncLayout(self.textNode)
        
        return { [weak self] item, params, last, firstWithHeader in
            
            let leftInset: CGFloat = 62.0 + params.leftInset
            let rightInset: CGFloat = params.rightInset
            
            let attributedString = NSAttributedString(string: item.query, font: Font.regular(17.0), textColor: item.clear ? item.theme.list.itemAccentColor : item.theme.list.itemPrimaryTextColor)
            let textApply = textLayout(TextNodeLayoutArguments(attributedString: attributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset - 15.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: 44.0), insets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0))
            
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
                            if item.clear {
                                strongSelf.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Hashtag/ClearRecent"), color: item.theme.list.itemAccentColor)
                            } else {
                                strongSelf.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Hashtag/RecentHashtag"), color: item.theme.list.itemSecondaryTextColor)
                            }
                        }
                        
                        let (textLayout, textApply) = textApply
                        let textNode = textApply()
                        if strongSelf.textNode == nil {
                            strongSelf.textNode = textNode
                            strongSelf.addSubnode(textNode)
                        }
                        
                        let textFrame = CGRect(origin: CGPoint(x: leftInset + strongSelf.revealOffset, y: floorToScreenPixels((nodeLayout.contentSize.height - textLayout.size.height) / 2.0)), size: textLayout.size)
                        textNode.frame = textFrame
                        
                        if let icon = strongSelf.iconNode.image {
                            strongSelf.iconNode.frame = CGRect(origin: CGPoint(x: textFrame.minX - icon.size.width - 16.0 + strongSelf.revealOffset, y: floorToScreenPixels((nodeLayout.contentSize.height - icon.size.height) / 2.0)), size: icon.size)
                        }
                        
                        let separatorHeight = UIScreenPixel
                        let topHighlightInset: CGFloat = separatorHeight
                        
                        strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: nodeLayout.contentSize.width, height: nodeLayout.contentSize.height))
                        strongSelf.updateRevealOptionsHighlightedBackgroundFrame(strongSelf.highlightedBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -nodeLayout.insets.top - topHighlightInset), size: CGSize(width: nodeLayout.size.width, height: nodeLayout.size.height + topHighlightInset)), aboveNodes: [strongSelf.separatorNode, strongSelf.backgroundNode])
                        strongSelf.updateRevealOptionsSeparatorNodes(top: nil, bottom: strongSelf.separatorNode, topIsHidden: true, bottomIsHidden: last)
                        strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: leftInset, y: nodeLayout.contentSize.height - separatorHeight), size: CGSize(width: nodeLayout.size.width, height: separatorHeight))
                        
                        strongSelf.updateLayout(size: nodeLayout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                        
                        if item.clear {
                            strongSelf.setRevealOptions((left: [], right: []))
                        } else {
                            strongSelf.setRevealOptions((left: [], right: [ItemListRevealOption(key: HashtagSearchRecentQueryRevealOptionKey.delete.rawValue, title: item.strings.Common_Delete, icon: .none, color: item.theme.list.itemDisclosureActions.destructive.fillColor, iconColor: item.theme.list.itemDisclosureActions.destructive.foregroundColor, textColor: item.theme.list.itemSecondaryTextColor, isDestructive: true)]))
                        }
                    }
                })
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
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
            let leftInset: CGFloat = 62.0 + params.leftInset
            
            var textFrame = textNode.frame
            textFrame.origin.x = leftInset + offset
            transition.updateFrame(node: textNode, frame: textFrame)
            
            var iconFrame = self.iconNode.frame
            iconFrame.origin.x = textFrame.minX - iconFrame.width - 16.0
            transition.updateFrame(node: self.iconNode, frame: iconFrame)
        }
    }
    
    override func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        if let item = self.item {
            switch option.key {
                case HashtagSearchRecentQueryRevealOptionKey.delete.rawValue:
                    item.deleted(item.query)
                default:
                    break
            }
        }
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()
    }
}

public extension ListViewItemHeaderFamily {
    static let hashtagSearchRecentQuery = ListViewItemHeaderFamily("hashtagSearchRecentQuery")
}
