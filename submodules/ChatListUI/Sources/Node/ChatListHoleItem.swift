import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import ComponentFlow
import LottieComponent

class ChatListHoleItem: ListViewItem {
    let theme: PresentationTheme
    
    let selectable: Bool = false
    
    init(theme: PresentationTheme) {
        self.theme = theme
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatListHoleItemNode()
            node.relativePosition = (first: previousItem == nil, last: nextItem == nil)
            node.insets = ChatListItemNode.insets(first: false, last: false, firstWithHeader: false)
            node.layoutForParams(params, item: self, previousItem: previousItem, nextItem: nextItem)
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            assert(node() is ChatListHoleItemNode)
            if let nodeValue = node() as? ChatListHoleItemNode {
            
                let layout = nodeValue.asyncLayout()
                async {
                    let first = previousItem == nil
                    let last = nextItem == nil
                    
                    let (nodeLayout, apply) = layout(self, params, first, last)
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

class ChatListHoleItemNode: ListViewItemNode {
    var relativePosition: (first: Bool, last: Bool) = (false, false)
    
    required init() {
        super.init(layerBacked: false, dynamicBounce: false)
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        let layout = self.asyncLayout()
        let (_, apply) = layout(item as! ChatListHoleItem, params, self.relativePosition.first, self.relativePosition.last)
        apply()
    }
    
    func asyncLayout() -> (_ item: ChatListHoleItem, _ params: ListViewItemLayoutParams, _ first: Bool, _ last: Bool) -> (ListViewItemNodeLayout, () -> Void) {
        return { item, params, first, last in
            let layout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: 0.0), insets: UIEdgeInsets())
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.relativePosition = (first, last)
                    
                    strongSelf.contentSize = layout.contentSize
                    strongSelf.insets = layout.insets
                }
            })
        }
    }
}

class ChatListSearchEmptyFooterItem: ListViewItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let searchQuery: String?
    let searchAllMessages: (() -> Void)?
    
    let header: ListViewItemHeader?
    let selectable: Bool = false
    
    init(theme: PresentationTheme, strings: PresentationStrings, header: ListViewItemHeader?, searchQuery: String?, searchAllMessages: (() -> Void)?) {
        self.theme = theme
        self.strings = strings
        self.header = header
        self.searchQuery = searchQuery
        self.searchAllMessages = searchAllMessages
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatListSearchEmptyFooterItemNode()
            let (layout, apply) = node.asyncLayout()(self, params)
            
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
            assert(node() is ChatListSearchEmptyFooterItemNode)
            if let nodeValue = node() as? ChatListSearchEmptyFooterItemNode {
            
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params)
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

class ChatListSearchEmptyFooterItemNode: ListViewItemNode {
    private let contentNode: ASDisplayNode
    private let titleNode: TextNode
    private let textNode: TextNode
    private let searchAllMessagesButton: HighlightableButtonNode
    private let searchAllMessagesTitle: TextNode
    
    private let icon = ComponentView<Empty>()
    
    private var item: ChatListSearchEmptyFooterItem?
    
    required init() {
        self.contentNode = ASDisplayNode()
        self.titleNode = TextNode()
        self.textNode = TextNode()
        
        self.searchAllMessagesButton = HighlightableButtonNode()
        self.searchAllMessagesTitle = TextNode()
        self.searchAllMessagesTitle.isUserInteractionEnabled = false
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.contentNode)
        self.contentNode.addSubnode(self.titleNode)
        self.contentNode.addSubnode(self.textNode)
        
        self.contentNode.addSubnode(self.searchAllMessagesButton)
        self.searchAllMessagesButton.addSubnode(self.searchAllMessagesTitle)
        
        self.searchAllMessagesButton.addTarget(self, action: #selector(self.searchAllMessagesButtonPressed), forControlEvents: .touchUpInside)
        
        self.wantsTrailingItemSpaceUpdates = true
    }
    
    @objc private func searchAllMessagesButtonPressed() {
        self.item?.searchAllMessages?()
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        let layout = self.asyncLayout()
        let (_, apply) = layout(item as! ChatListSearchEmptyFooterItem, params)
        apply()
    }
    
    override func headers() -> [ListViewItemHeader]? {
        if let item = self.item {
            return item.header.flatMap { [$0] }
        } else {
            return nil
        }
    }
    
    override func updateTrailingItemSpace(_ trailingItemSpace: CGFloat, transition: ContainedViewLayoutTransition) {
        var contentFrame = self.contentNode.frame
        contentFrame.origin.y = max(0.0, floor(trailingItemSpace * 0.5))
        self.contentNode.frame = contentFrame
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if let contentResult = self.contentNode.view.hitTest(self.view.convert(point, to: self.contentNode.view), with: event), contentResult === self.searchAllMessagesButton.view {
            return contentResult
        }
        return result
    }
    
    func asyncLayout() -> (_ item: ChatListSearchEmptyFooterItem, _ params: ListViewItemLayoutParams) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleNodeLayout = TextNode.asyncLayout(self.titleNode)
        let makeTextNodeLayout = TextNode.asyncLayout(self.textNode)
        let makeSearchAllMessagesTitleLayout = TextNode.asyncLayout(self.searchAllMessagesTitle)
        
        return { [weak self] item, params in
            let titleLayout = makeTitleNodeLayout(TextNodeLayoutArguments(
                attributedString: NSAttributedString(string: item.strings.ChatList_Search_NoResults, font: Font.semibold(17.0), textColor: item.theme.list.freeTextColor),
                maximumNumberOfLines: 1,
                truncationType: .end,
                constrainedSize: CGSize(width: params.width - params.leftInset * 2.0 - 12.0 * 2.0, height: 1000.0)
            ))
            
            let textValue: String
            if let searchQuery = item.searchQuery {
                textValue = item.strings.ChatList_Search_NoResultsQueryDescription(searchQuery).string
            } else {
                textValue = item.strings.ChatList_Search_NoResults
            }
            
            let textLayout = makeTextNodeLayout(TextNodeLayoutArguments(
                attributedString: NSAttributedString(string: textValue, font: Font.regular(16.0), textColor: item.theme.list.freeTextColor),
                maximumNumberOfLines: 0,
                truncationType: .end,
                constrainedSize: CGSize(width: params.width - params.leftInset * 2.0 - 12.0 * 2.0, height: 1000.0),
                alignment: .center,
                lineSpacing: 0.1
            ))
            
            let searchAllMessagesTitleLayout = makeSearchAllMessagesTitleLayout(TextNodeLayoutArguments(
                attributedString: NSAttributedString(string: item.strings.ChatList_EmptyResult_SearchInAll, font: Font.regular(17.0), textColor: item.theme.list.itemAccentColor),
                maximumNumberOfLines: 1,
                truncationType: .end,
                constrainedSize: CGSize(width: params.width - params.leftInset * 2.0 - 12.0 * 2.0, height: 1000.0)
            ))
            
            var contentHeight: CGFloat = 0.0
            
            let topInset: CGFloat = 40.0
            let bottomInset: CGFloat = 10.0
            let iconSpacing: CGFloat = 20.0
            let titleSpacing: CGFloat = 6.0
            
            let buttonSpacing: CGFloat = 14.0
            let buttonInset: CGFloat = 11.0
            
            let iconSize = CGSize(width: 128.0, height: 128.0)
            
            contentHeight += topInset
            contentHeight += iconSize.height
            contentHeight += iconSpacing
            contentHeight += titleLayout.0.size.height
            contentHeight += titleSpacing
            contentHeight += textLayout.0.size.height
            
            if item.searchAllMessages != nil {
                contentHeight += buttonSpacing
                contentHeight += buttonInset
                contentHeight += searchAllMessagesTitleLayout.0.size.height
                contentHeight += buttonInset
            }
            
            contentHeight += bottomInset
            
            let layout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: contentHeight), insets: UIEdgeInsets())
            
            return (layout, { [weak self] in
                guard let self else {
                    return
                }
                
                self.item = item
                self.contentSize = layout.contentSize
                self.insets = layout.insets
                
                let _ = titleLayout.1()
                let _ = textLayout.1()
                let _ = searchAllMessagesTitleLayout.1()
                
                var contentY: CGFloat = 0.0
                contentY += topInset
                
                let _ = self.icon.update(
                    transition: .immediate,
                    component: AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(
                            name: "ChatListNoResults"
                        ),
                        color: nil,
                        placeholderColor: nil,
                        startingPosition: .begin,
                        size: iconSize,
                        renderingScale: nil,
                        loop: false,
                        playOnce: nil
                    )),
                    environment: {}, containerSize: iconSize
                )
                let iconFrame = CGRect(origin: CGPoint(x: floor((params.width - iconSize.width) * 0.5), y: contentY), size: iconSize)
                if let iconView = self.icon.view {
                    if iconView.superview == nil {
                        self.contentNode.view.addSubview(iconView)
                    }
                    iconView.frame = iconFrame
                }
                
                contentY += iconSize.height
                contentY += iconSpacing
                
                let titleFrame = CGRect(origin: CGPoint(x: floor((params.width - titleLayout.0.size.width) * 0.5), y: contentY), size: titleLayout.0.size)
                self.titleNode.frame = titleFrame
                contentY += titleLayout.0.size.height
                contentY += titleSpacing
                
                let textFrame = CGRect(origin: CGPoint(x: floor((params.width - textLayout.0.size.width) * 0.5), y: contentY), size: textLayout.0.size)
                self.textNode.frame = textFrame
                contentY += textLayout.0.size.height
                
                if item.searchAllMessages != nil {
                    contentY += buttonSpacing
                    let searchAllMessagesButtonFrame = CGRect(origin: CGPoint(x: floor((params.width - searchAllMessagesTitleLayout.0.size.width) * 0.5), y: contentY), size: CGSize(width: searchAllMessagesTitleLayout.0.size.width, height: searchAllMessagesTitleLayout.0.size.height + buttonInset * 2.0))
                    contentY += searchAllMessagesTitleLayout.0.size.height + buttonInset * 2.0
                    
                    self.searchAllMessagesButton.frame = searchAllMessagesButtonFrame
                    self.searchAllMessagesTitle.frame = CGRect(origin: CGPoint(x: 0.0, y: buttonInset), size: searchAllMessagesTitleLayout.0.size)
                    contentY += buttonInset
                    contentY += searchAllMessagesTitleLayout.0.size.height
                    contentY += buttonInset
                }
                
                contentY += bottomInset
                
                let contentFrame = CGRect(origin: CGPoint(x: 0.0, y: self.contentNode.frame.minY), size: CGSize(width: params.width, height: contentHeight))
                self.contentNode.frame = contentFrame
            })
        }
    }
}
