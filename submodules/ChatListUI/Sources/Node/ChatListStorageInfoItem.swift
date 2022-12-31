import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import SwiftSignalKit
import TelegramPresentationData
import ListSectionHeaderNode
import AppBundle

class ChatListStorageInfoItem: ListViewItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let sizeFraction: Double
    let action: () -> Void
    
    let selectable: Bool = true
    
    init(theme: PresentationTheme, strings: PresentationStrings, sizeFraction: Double, action: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings
        self.sizeFraction = sizeFraction
        self.action = action
    }
    
    func selected(listView: ListView) {
        listView.clearHighlightAnimated(true)
        
        self.action()
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatListStorageInfoItemNode()
            
            let (nodeLayout, apply) = node.asyncLayout()(self, params, false)
            
            node.insets = nodeLayout.insets
            node.contentSize = nodeLayout.contentSize
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in
                        apply()
                    })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            assert(node() is ChatListStorageInfoItemNode)
            if let nodeValue = node() as? ChatListStorageInfoItemNode {
                
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params, nextItem == nil)
                    Queue.mainQueue().async {
                        completion(nodeLayout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
}

private let separatorHeight = 1.0 / UIScreen.main.scale

private let titleFont = Font.semibold(15.0)
private let textFont = Font.regular(15.0)

class ChatListStorageInfoItemNode: ListViewItemNode {
    private let titleNode: TextNode
    private let textNode: TextNode
    private let arrowNode: ASImageNode
    private let separatorNode: ASDisplayNode
    
    private var item: ChatListStorageInfoItem?
    
    required init() {
        self.titleNode = TextNode()
        self.textNode = TextNode()
        self.arrowNode = ASImageNode()
        self.separatorNode = ASDisplayNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.arrowNode)
    }
    
    override func didLoad() {
        super.didLoad()
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        let layout = self.asyncLayout()
        let (_, apply) = layout(item as! ChatListStorageInfoItem, params, nextItem == nil)
        apply()
    }
    
    func asyncLayout() -> (_ item: ChatListStorageInfoItem, _ params: ListViewItemLayoutParams, _ isLast: Bool) -> (ListViewItemNodeLayout, () -> Void) {
        let previousItem = self.item
        
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        
        return { item, params, last in
            let baseWidth = params.width - params.leftInset - params.rightInset
            let _ = baseWidth
            
            let sideInset: CGFloat = params.leftInset + 16.0
            let height: CGFloat = 54.0
            let rightInset: CGFloat = sideInset + 24.0
            
            let themeUpdated = item.theme !== previousItem?.theme
            
            let sizeString = dataSizeString(Int64(item.sizeFraction), formatting: DataSizeStringFormatting(strings: item.strings, decimalSeparator: "."))
            let rawTitleString = item.strings.ChatList_StorageHintTitle(sizeString)
            let titleString = NSMutableAttributedString(attributedString: NSAttributedString(string: rawTitleString.string, font: titleFont, textColor: item.theme.rootController.navigationBar.primaryTextColor))
            if let range = rawTitleString.ranges.first {
                titleString.addAttribute(.foregroundColor, value: item.theme.rootController.navigationBar.accentTextColor, range: range.range)
            }
            
            let titleLayout = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleString, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - sideInset - rightInset, height: 100.0)))
            
            let textLayout = makeTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.strings.ChatList_StorageHintText, font: textFont, textColor: item.theme.rootController.navigationBar.secondaryTextColor), maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - sideInset - rightInset, height: 100.0)))
            
            let layout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: height), insets: UIEdgeInsets())
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    if themeUpdated {
                        strongSelf.backgroundColor = item.theme.chatList.pinnedItemBackgroundColor
                        strongSelf.separatorNode.backgroundColor = item.theme.chatList.itemSeparatorColor
                        strongSelf.arrowNode.image = PresentationResourcesItemList.disclosureArrowImage(item.theme)
                    }
                    
                    strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - UIScreenPixel), size: CGSize(width: layout.size.width, height: UIScreenPixel))
                    
                    let _ = titleLayout.1()
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: sideInset, y: 9.0), size: titleLayout.0.size)
                    
                    let _ = textLayout.1()
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: sideInset, y: strongSelf.titleNode.frame.maxY - 0.0), size: textLayout.0.size)
                    
                    if let image = strongSelf.arrowNode.image {
                        strongSelf.arrowNode.frame = CGRect(origin: CGPoint(x: layout.size.width - sideInset - image.size.width + 8.0, y: floor((layout.size.height - image.size.height) / 2.0)), size: image.size)
                    }
                    
                    strongSelf.contentSize = layout.contentSize
                    strongSelf.insets = layout.insets
                }
            })
        }
    }
}
