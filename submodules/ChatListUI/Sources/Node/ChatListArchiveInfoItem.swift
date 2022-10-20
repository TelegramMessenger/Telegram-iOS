import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import SwiftSignalKit
import TelegramPresentationData
import ListSectionHeaderNode
import AppBundle

class ChatListArchiveInfoItem: ListViewItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    
    let selectable: Bool = false
    
    init(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        self.strings = strings
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ChatListArchiveInfoItemNode()
            
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
            assert(node() is ChatListArchiveInfoItemNode)
            if let nodeValue = node() as? ChatListArchiveInfoItemNode {
                
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

private let titleFont = Font.regular(20.0)
private let textFont = Font.regular(15.0)

private final class InfoPageNode: ASDisplayNode {
    private let iconNodeBase: ASImageNode
    private let iconNodeContent: ASImageNode
    private let titleNode: TextNode
    private let textNode: TextNode
    
    private var theme: PresentationTheme?
    
    override init() {
        self.iconNodeBase = ASImageNode()
        self.iconNodeBase.displaysAsynchronously = false
        self.iconNodeBase.displayWithoutProcessing = true
        
        self.iconNodeContent = ASImageNode()
        self.iconNodeContent.displaysAsynchronously = false
        self.iconNodeContent.displayWithoutProcessing = true
        
        self.titleNode = TextNode()
        self.titleNode.displaysAsynchronously = false
        
        self.textNode = TextNode()
        self.textNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.iconNodeBase)
        self.addSubnode(self.iconNodeContent)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
    }
    
    func asyncLayout() -> (_ theme: PresentationTheme, _ strings: PresentationStrings, _ width: CGFloat, _ index: Int) -> (CGFloat, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        return { [weak self] theme, strings, width, index in
            let title: String
            let text: String
            if index == 0 {
                title = strings.ArchivedChats_IntroTitle1
                text = strings.ArchivedChats_IntroText1
            } else if index == 1 {
                title = strings.ArchivedChats_IntroTitle2
                text = strings.ArchivedChats_IntroText2
            } else {
                title = strings.ArchivedChats_IntroTitle3
                text = strings.ArchivedChats_IntroText3
            }
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: title, font: titleFont, textColor: theme.list.itemPrimaryTextColor, paragraphAlignment: nil), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: min(300.0, width - 16.0), height: .greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: text, font: textFont, textColor: theme.list.itemPrimaryTextColor, paragraphAlignment: nil), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: min(300.0, width - 16.0), height: .greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
            
            let topContentInset: CGFloat = 98.0
            let bottomContentInset: CGFloat = 64.0 + 28.0
            let textSpacing: CGFloat = 6.0
            
            let contentHeight = topContentInset + titleLayout.size.height + textSpacing + textLayout.size.height + bottomContentInset
            
            return (contentHeight, {
                guard let strongSelf = self else {
                    return
                }
                
                if strongSelf.theme !== theme {
                    strongSelf.theme = theme
                    if index == 0 {
                        strongSelf.iconNodeBase.image = generateTintedImage(image: UIImage(bundleImageName: "Chat List/Archive/Intro1Base"), color: theme.list.itemPrimaryTextColor)
                    } else {
                        strongSelf.iconNodeBase.image = generateTintedImage(image: UIImage(bundleImageName: "Chat List/Archive/Intro2Base"), color: theme.list.itemPrimaryTextColor)
                    }
                    if index == 0 {
                        strongSelf.iconNodeContent.image = generateTintedImage(image: UIImage(bundleImageName: "Chat List/Archive/Intro1Content"), color: theme.chatList.unreadBadgeActiveBackgroundColor)
                    } else if index == 1 {
                        strongSelf.iconNodeContent.image = generateTintedImage(image: UIImage(bundleImageName: "Chat List/Archive/Intro2Content"), color: theme.chatList.unreadBadgeInactiveBackgroundColor)
                    } else {
                        strongSelf.iconNodeContent.image = generateTintedImage(image: UIImage(bundleImageName: "Chat List/Archive/Intro3Content"), color: theme.chatList.unreadBadgeActiveBackgroundColor)
                    }
                }
                
                let topIconInset: CGFloat = 110.0
                
                if let baseImage = strongSelf.iconNodeBase.image, let contentImage = strongSelf.iconNodeContent.image {
                    strongSelf.iconNodeBase.frame = CGRect(origin: CGPoint(x: floor((width - baseImage.size.width) / 2.0), y: floor((topIconInset - baseImage.size.height) / 2.0)), size: baseImage.size)
                    strongSelf.iconNodeContent.frame = CGRect(origin: CGPoint(x: floor((width - contentImage.size.width) / 2.0), y: floor((topIconInset - contentImage.size.height) / 2.0)), size: contentImage.size)
                }
                
                let _ = titleApply()
                let _ = textApply()
                
                let titleFrame = CGRect(origin: CGPoint(x: floor((width - titleLayout.size.width) / 2.0), y: topContentInset), size: titleLayout.size)
                strongSelf.titleNode.frame = titleFrame
                strongSelf.textNode.frame = CGRect(origin: CGPoint(x: floor((width - textLayout.size.width) / 2.0), y: titleFrame.maxY + textSpacing), size: textLayout.size)
            })
        }
    }
}

class ChatListArchiveInfoItemNode: ListViewItemNode, UIScrollViewDelegate {
    private var item: ChatListArchiveInfoItem?
    
    private let scrollNode: ASScrollNode
    private let pageControlNode: PageControlNode
    private var headerNode: ListSectionHeaderNode?
    private let infoPageNodes: [InfoPageNode]
    
    required init() {
        self.scrollNode = ASScrollNode()
        
        self.pageControlNode = PageControlNode(dotSize: 7.0, dotSpacing: 9.0, dotColor: .blue, inactiveDotColor: .gray)
        
        self.infoPageNodes = (0 ..< 3).map({ _ in InfoPageNode() })
        self.pageControlNode.pagesCount = self.infoPageNodes.count
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.scrollNode)
        self.infoPageNodes.forEach(self.scrollNode.addSubnode)
        
        self.addSubnode(self.pageControlNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
        
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.isPagingEnabled = true
        self.scrollNode.view.delegate = self
        self.pageControlNode.setPage(0.0)
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        let layout = self.asyncLayout()
        let (_, apply) = layout(item as! ChatListArchiveInfoItem, params, nextItem == nil)
        apply()
    }
    
    func asyncLayout() -> (_ item: ChatListArchiveInfoItem, _ params: ListViewItemLayoutParams, _ isLast: Bool) -> (ListViewItemNodeLayout, () -> Void) {
        let previousItem = self.item
        
        let makeInfoPageLayouts = self.infoPageNodes.map({ $0.asyncLayout() })
        
        return { item, params, last in
            let baseWidth = params.width - params.leftInset - params.rightInset
            let bottomInset: CGFloat = 22.0 + 28.0
            
            let themeUpdated = previousItem?.theme !== item.theme
            
            var infoPageLayoutsAndApply: [(CGFloat, () -> Void)] = []
            var maxHeight: CGFloat = 0.0
            for i in 0 ..< makeInfoPageLayouts.count {
                let sizeAndApply = makeInfoPageLayouts[i](item.theme, item.strings, baseWidth, i)
                maxHeight = max(maxHeight, sizeAndApply.0)
                infoPageLayoutsAndApply.append(sizeAndApply)
            }
            
            let layout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: maxHeight), insets: UIEdgeInsets())
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    if themeUpdated {
                        strongSelf.pageControlNode.dotColor = item.theme.chatList.unreadBadgeActiveBackgroundColor
                        strongSelf.pageControlNode.inactiveDotColor = item.theme.list.pageIndicatorInactiveColor
                    }
                    
                    let resetOffset = !strongSelf.scrollNode.frame.width.isEqual(to: baseWidth)
                    strongSelf.scrollNode.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: baseWidth, height: layout.contentSize.height))
                    strongSelf.scrollNode.view.contentSize = CGSize(width: baseWidth * CGFloat(infoPageLayoutsAndApply.count), height: layout.contentSize.height)
                    if resetOffset {
                        strongSelf.scrollNode.view.contentOffset = CGPoint(x: 0.0, y: 0.0)
                    }
                    for i in 0 ..< infoPageLayoutsAndApply.count {
                        strongSelf.infoPageNodes[i].frame = CGRect(origin: CGPoint(x: baseWidth * CGFloat(i), y: 0.0), size: CGSize(width: baseWidth, height: layout.contentSize.height))
                        infoPageLayoutsAndApply[i].1()
                    }
                    
                    let pageControlSize = strongSelf.pageControlNode.measure(CGSize(width: baseWidth, height: 100.0))
                    strongSelf.pageControlNode.frame = CGRect(origin: CGPoint(x: floor((params.width - pageControlSize.width) / 2.0), y: layout.contentSize.height - bottomInset - pageControlSize.height), size: pageControlSize)
                    
                    if strongSelf.headerNode == nil {
                        let headerNode = ListSectionHeaderNode(theme: item.theme)
                        headerNode.title = item.strings.ChatList_ArchivedChatsTitle.uppercased()
                        strongSelf.addSubnode(headerNode)
                        strongSelf.headerNode = headerNode
                    }
                    
                    if let headerNode = strongSelf.headerNode {
                        if themeUpdated {
                            headerNode.updateTheme(theme: item.theme)
                        }
                        headerNode.frame = CGRect(origin: CGPoint(x: 0.0, y: layout.contentSize.height - 28.0), size: CGSize(width: params.width, height: 28.0))
                        headerNode.updateLayout(size: CGSize(width: params.width, height: 28.0), leftInset: params.leftInset, rightInset: params.rightInset)
                    }
                    
                    strongSelf.contentSize = layout.contentSize
                    strongSelf.insets = layout.insets
                }
            })
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let bounds = scrollView.bounds
        if !bounds.width.isZero {
            self.pageControlNode.setPage(scrollView.contentOffset.x / bounds.width)
        }
    }
}
