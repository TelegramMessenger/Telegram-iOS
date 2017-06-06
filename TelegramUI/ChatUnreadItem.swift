import Foundation
import UIKit
import Postbox
import AsyncDisplayKit
import Display
import SwiftSignalKit

private let titleFont = UIFont.systemFont(ofSize: 13.0)

class ChatUnreadItem: ListViewItem {
    let index: MessageIndex
    let theme: PresentationTheme
    let strings: PresentationStrings
    let header: ChatMessageDateHeader
    
    init(index: MessageIndex, theme: PresentationTheme, strings: PresentationStrings) {
        self.index = index
        self.theme = theme
        self.strings = strings
        self.header = ChatMessageDateHeader(timestamp: index.timestamp, theme: theme, strings: strings)
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        async {
            let node = ChatUnreadItemNode()
            node.layoutForWidth(width, item: self, previousItem: previousItem, nextItem: nextItem)
            completion(node, {
                return (nil, {})
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        completion(ListViewItemNodeLayout(contentSize: node.contentSize, insets: node.insets), {
        })
    }
}

class ChatUnreadItemNode: ListViewItemNode {
    var item: ChatUnreadItem?
    let backgroundNode: ASImageNode
    let labelNode: TextNode
    
    private var theme: PresentationTheme?
    
    private let layoutConstants = ChatMessageItemLayoutConstants()
    
    init() {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displayWithoutProcessing = true
        
        self.labelNode = TextNode()
        self.labelNode.isLayerBacked = true
        
        super.init(layerBacked: true, dynamicBounce: true, rotated: true)
        
        self.addSubnode(self.backgroundNode)
        
        self.addSubnode(self.labelNode)
        
        self.transform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
        
        self.scrollPositioningInsets = UIEdgeInsets(top: 5.0, left: 0.0, bottom: 6.0, right: 0.0)
        self.canBeUsedAsScrollToItemAnchor = false
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        super.animateInsertion(currentTimestamp, duration: duration, short: short)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func layoutForWidth(_ width: CGFloat, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
            if let item = item as? ChatUnreadItem {
            let dateAtBottom = !chatItemsHaveCommonDateHeader(item, nextItem)
            let (layout, apply) = self.asyncLayout()(item, width, dateAtBottom)
            apply()
            self.contentSize = layout.contentSize
            self.insets = layout.insets
        }
    }
    
    func asyncLayout() -> (_ item: ChatUnreadItem, _ width: CGFloat, _ dateAtBottom: Bool) -> (ListViewItemNodeLayout, () -> Void) {
        let labelLayout = TextNode.asyncLayout(self.labelNode)
        let layoutConstants = self.layoutConstants
        let currentTheme = self.theme
        
        return { item, width, dateAtBottom in
            var updatedBackgroundImage: UIImage?
            if currentTheme !== item.theme {
                updatedBackgroundImage = PresentationResourcesChat.chatUnreadBarBackgroundImage(item.theme)
            }
            
            let (size, apply) = labelLayout(NSAttributedString(string: item.strings.Conversation_UnreadMessages, font: titleFont, textColor: item.theme.chat.serviceMessage.unreadBarTextColor), nil, 1, .end, CGSize(width: width, height: CGFloat.greatestFiniteMagnitude), .natural, nil, UIEdgeInsets())
            
            let backgroundSize = CGSize(width: width, height: 25.0)
            
            return (ListViewItemNodeLayout(contentSize: CGSize(width: width, height: 25.0), insets: UIEdgeInsets(top: 6.0 + (dateAtBottom ? layoutConstants.timestampHeaderHeight : 0.0), left: 0.0, bottom: 5.0, right: 0.0)), { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.theme = item.theme
                    
                    if let updatedBackgroundImage = updatedBackgroundImage {
                        strongSelf.backgroundNode.image = updatedBackgroundImage
                    }
                    
                    let _ = apply()
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: backgroundSize)
                    strongSelf.labelNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((backgroundSize.width - size.size.width) / 2.0), y: floorToScreenPixels((backgroundSize.height - size.size.height) / 2.0) - 1.0), size: size.size)
                }
            })
        }
    }
    
    override public func header() -> ListViewItemHeader? {
        if let item = self.item {
            return item.header
        } else {
            return nil
        }
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        super.animateRemoved(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
}
