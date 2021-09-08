import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import TextFormat
import AppBundle
import Markdown

class ChannelDiscussionGroupSetupHeaderItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let title: String?
    let isGroup: Bool
    let label: String
    let sectionId: ItemListSectionId
    
    let isAlwaysPlain: Bool = true
    
    init(theme: PresentationTheme, strings: PresentationStrings, title: String?, isGroup: Bool, label: String, sectionId: ItemListSectionId) {
        self.theme = theme
        self.strings = strings
        self.title = title
        self.isGroup = isGroup
        self.label = label
        self.sectionId = sectionId
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChannelDiscussionGroupSetupHeaderItemNode()
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
            guard let nodeValue = node() as? ChannelDiscussionGroupSetupHeaderItemNode else {
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

private let iconFont = Font.medium(12.0)
private let titleFont = Font.regular(14.0)
private let titleBoldFont = Font.semibold(14.0)

class ChannelDiscussionGroupSetupHeaderItemNode: ListViewItemNode {
    private let imageNode: ASImageNode
    private let titleNode: TextNode
    private let labelNode: TextNode
    
    private var item: ChannelDiscussionGroupSetupHeaderItem?
    
    init() {
        self.imageNode = ASImageNode()
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        self.labelNode.contentMode = .left
        self.labelNode.contentsScale = UIScreen.main.scale
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.imageNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.labelNode)
    }
    
    func asyncLayout() -> (_ item: ChannelDiscussionGroupSetupHeaderItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        
        let currentItem = self.item
        let currentIconImage = self.imageNode.image
        
        return { item, params, neighbors in
            let topInset: CGFloat = 30.0
            let bottomInset: CGFloat = 0.0
            let iconSpacing: CGFloat = 21.0
            
            let iconImage: UIImage?
            if item.theme !== currentItem?.theme {
                switch item.theme.name {
                    case let .builtin(name):
                        switch name {
                            case .day, .dayClassic:
                                iconImage = UIImage(bundleImageName: "Chat/Info/DiscussDayIcon")?.precomposed()
                            case .nightAccent:
                                iconImage = UIImage(bundleImageName: "Chat/Info/DiscussNightAccentIcon")?.precomposed()
                            case .night:
                                iconImage = UIImage(bundleImageName: "Chat/Info/DiscussNightIcon")?.precomposed()
                        }
                    case .custom:
                        iconImage = UIImage(bundleImageName: "Chat/Info/DiscussDayIcon")?.precomposed()
                }
            } else {
                iconImage = currentIconImage
            }
            
            let body = MarkdownAttributeSet(font: titleFont, textColor: item.theme.list.sectionHeaderTextColor)
            let bold = MarkdownAttributeSet(font: titleBoldFont, textColor: item.theme.list.sectionHeaderTextColor)
            let string: NSAttributedString
            if let title = item.title {
                string = addAttributesToStringWithRanges(item.isGroup ? item.strings.Channel_CommentsGroup_HeaderGroupSet(title)._tuple : item.strings.Channel_CommentsGroup_HeaderSet(title)._tuple, body: body, argumentAttributes: [0: bold])
            } else {
                string = NSAttributedString(string: item.strings.Channel_CommentsGroup_Header, font: titleFont, textColor: item.theme.list.sectionHeaderTextColor)
            }
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: string, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.label, font: iconFont, textColor: item.theme.list.itemAccentColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            let contentSize: CGSize
            var insets = UIEdgeInsets()
            insets.top = topInset
            insets.bottom = bottomInset
            
            contentSize = CGSize(width: params.width, height: (iconImage?.size.height ?? 0.0) + iconSpacing + titleLayout.size.height)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    let _ = titleApply()
                    let _ = labelApply()
                    
                    strongSelf.imageNode.image = iconImage
                    
                    let iconSize = iconImage?.size ?? CGSize()
                    let iconFrame = CGRect(origin: CGPoint(x: floor((params.width - iconSize.width) / 2.0), y: 0.0), size: iconSize)
                    strongSelf.imageNode.frame = iconFrame
                    
                    strongSelf.labelNode.frame = CGRect(origin: CGPoint(x: floor((params.width - labelLayout.size.width) / 2.0), y: iconFrame.minY + 63.0), size: labelLayout.size)
                    
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: floor((params.width - titleLayout.size.width) / 2.0), y: iconFrame.maxY + iconSpacing), size: titleLayout.size)
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
}
