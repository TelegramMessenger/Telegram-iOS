import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import SwiftSignalKit
import TelegramPresentationData
import ListSectionHeaderNode
import AppBundle
import ItemListUI

class ChatListStorageInfoItem: ListViewItem {
    enum Action {
        case activate
        case hide
    }
    
    let theme: PresentationTheme
    let strings: PresentationStrings
    let notice: ChatListNotice
    let action: (Action) -> Void
    
    let selectable: Bool = true
    
    init(theme: PresentationTheme, strings: PresentationStrings, notice: ChatListNotice, action: @escaping (Action) -> Void) {
        self.theme = theme
        self.strings = strings
        self.notice = notice
        self.action = action
    }
    
    func selected(listView: ListView) {
        listView.clearHighlightAnimated(true)
        
        self.action(.activate)
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

class ChatListStorageInfoItemNode: ItemListRevealOptionsItemNode {
    private let contentContainer: ASDisplayNode
    private let titleNode: TextNode
    private let textNode: TextNode
    private let arrowNode: ASImageNode
    private let separatorNode: ASDisplayNode
    
    private var item: ChatListStorageInfoItem?
    
    required init() {
        self.contentContainer = ASDisplayNode()
        
        self.titleNode = TextNode()
        self.textNode = TextNode()
        self.arrowNode = ASImageNode()
        self.separatorNode = ASDisplayNode()
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.clipsToBounds = true
        
        self.addSubnode(self.separatorNode)
        self.contentContainer.addSubnode(self.titleNode)
        self.contentContainer.addSubnode(self.textNode)
        self.contentContainer.addSubnode(self.arrowNode)
        
        self.addSubnode(self.contentContainer)
        
        self.zPosition = 1.0
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
            let rightInset: CGFloat = sideInset + 24.0
            let verticalInset: CGFloat = 8.0
            let spacing: CGFloat = 0.0
            
            let themeUpdated = item.theme !== previousItem?.theme
            
            let titleString: NSAttributedString
            let textString: NSAttributedString
            
            switch item.notice {
            case let .clearStorage(sizeFraction):
                let sizeString = dataSizeString(Int64(sizeFraction), formatting: DataSizeStringFormatting(strings: item.strings, decimalSeparator: "."))
                let rawTitleString = item.strings.ChatList_StorageHintTitle(sizeString)
                let titleStringValue = NSMutableAttributedString(attributedString: NSAttributedString(string: rawTitleString.string, font: titleFont, textColor: item.theme.rootController.navigationBar.primaryTextColor))
                if let range = rawTitleString.ranges.first {
                    titleStringValue.addAttribute(.foregroundColor, value: item.theme.rootController.navigationBar.accentTextColor, range: range.range)
                }
                titleString = titleStringValue
                
                textString = NSAttributedString(string: item.strings.ChatList_StorageHintText, font: textFont, textColor: item.theme.rootController.navigationBar.secondaryTextColor)
            case .setupPassword:
                titleString = NSAttributedString(string: item.strings.Settings_SuggestSetupPasswordTitle, font: titleFont, textColor: item.theme.rootController.navigationBar.primaryTextColor)
                textString = NSAttributedString(string: item.strings.Settings_SuggestSetupPasswordText, font: textFont, textColor: item.theme.rootController.navigationBar.secondaryTextColor)
            case let .premiumUpgrade(discount):
                let discountString = "\(discount)%"
                let rawTitleString = item.strings.ChatList_PremiumAnnualUpgradeTitle(discountString)
                let titleStringValue = NSMutableAttributedString(attributedString: NSAttributedString(string: rawTitleString.string, font: titleFont, textColor: item.theme.rootController.navigationBar.primaryTextColor))
                if let range = rawTitleString.ranges.first {
                    titleStringValue.addAttribute(.foregroundColor, value: item.theme.rootController.navigationBar.accentTextColor, range: range.range)
                }
                titleString = titleStringValue
                
                textString = NSAttributedString(string: item.strings.ChatList_PremiumAnnualUpgradeText, font: textFont, textColor: item.theme.rootController.navigationBar.secondaryTextColor)
            case let .premiumAnnualDiscount(discount):
                let discountString = "\(discount)%"
                let rawTitleString = item.strings.ChatList_PremiumAnnualDiscountTitle(discountString)
                let titleStringValue = NSMutableAttributedString(attributedString: NSAttributedString(string: rawTitleString.string, font: titleFont, textColor: item.theme.rootController.navigationBar.primaryTextColor))
                if let range = rawTitleString.ranges.first {
                    titleStringValue.addAttribute(.foregroundColor, value: item.theme.rootController.navigationBar.accentTextColor, range: range.range)
                }
                titleString = titleStringValue
                
                textString = NSAttributedString(string: item.strings.ChatList_PremiumAnnualDiscountText, font: textFont, textColor: item.theme.rootController.navigationBar.secondaryTextColor)
            case let .premiumRestore(discount):
                let discountString = "\(discount)%"
                let rawTitleString = item.strings.ChatList_PremiumRestoreDiscountTitle(discountString)
                let titleStringValue = NSMutableAttributedString(attributedString: NSAttributedString(string: rawTitleString.string, font: titleFont, textColor: item.theme.rootController.navigationBar.primaryTextColor))
                if let range = rawTitleString.ranges.first {
                    titleStringValue.addAttribute(.foregroundColor, value: item.theme.rootController.navigationBar.accentTextColor, range: range.range)
                }
                titleString = titleStringValue
                
                textString = NSAttributedString(string: item.strings.ChatList_PremiumRestoreDiscountText, font: textFont, textColor: item.theme.rootController.navigationBar.secondaryTextColor)
            case let .chatFolderUpdates(count):
                let rawTitleString = item.strings.ChatList_ChatFolderUpdateHintTitle(item.strings.ChatList_ChatFolderUpdateCount(Int32(count)))
                let titleStringValue = NSMutableAttributedString(attributedString: NSAttributedString(string: rawTitleString.string, font: titleFont, textColor: item.theme.rootController.navigationBar.primaryTextColor))
                if let range = rawTitleString.ranges.first {
                    titleStringValue.addAttribute(.foregroundColor, value: item.theme.rootController.navigationBar.accentTextColor, range: range.range)
                }
                titleString = titleStringValue
                
                textString = NSAttributedString(string: item.strings.ChatList_ChatFolderUpdateHintText, font: textFont, textColor: item.theme.rootController.navigationBar.secondaryTextColor)
            }
            
            let titleLayout = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleString, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - sideInset - rightInset, height: 100.0)))
            
            let textLayout = makeTextLayout(TextNodeLayoutArguments(attributedString: textString, maximumNumberOfLines: 5, truncationType: .end, constrainedSize: CGSize(width: params.width - sideInset - rightInset, height: 100.0)))
            
            let layout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: verticalInset * 2.0 + titleLayout.0.size.height + textLayout.0.size.height), insets: UIEdgeInsets())
            
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
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: sideInset, y: verticalInset), size: titleLayout.0.size)
                    
                    let _ = textLayout.1()
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: sideInset, y: strongSelf.titleNode.frame.maxY + spacing), size: textLayout.0.size)
                    
                    if let image = strongSelf.arrowNode.image {
                        strongSelf.arrowNode.frame = CGRect(origin: CGPoint(x: layout.size.width - sideInset - image.size.width + 8.0, y: floor((layout.size.height - image.size.height) / 2.0)), size: image.size)
                    }
                    
                    strongSelf.contentSize = layout.contentSize
                    strongSelf.insets = layout.insets
                    
                    strongSelf.updateLayout(size: layout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                    
                    strongSelf.contentContainer.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                    
                    switch item.notice {
                    case .chatFolderUpdates:
                        strongSelf.setRevealOptions((left: [], right: [ItemListRevealOption(key: 0, title: item.strings.ChatList_HideAction, icon: .none, color: item.theme.list.itemDisclosureActions.destructive.fillColor, textColor: item.theme.list.itemDisclosureActions.destructive.foregroundColor)]))
                    default:
                        strongSelf.setRevealOptions((left: [], right: []))
                    }
                }
            })
        }
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        super.animateInsertion(currentTimestamp, duration: duration, short: short)
        
        //self.transitionOffset = self.bounds.size.height * 1.6
        //self.addTransitionOffsetAnimation(0.0, duration: duration, beginAt: currentTimestamp)
    }
    
    override public func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        transition.updateSublayerTransformOffset(layer: self.contentContainer.layer, offset: CGPoint(x: offset, y: 0.0))
    }
    
    override public func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        if let item = self.item {
            item.action(.hide)
        }
        
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()
    }
}
