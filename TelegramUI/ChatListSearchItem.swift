import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import SwiftSignalKit

private let searchBarFont = Font.regular(14.0)

class ChatListSearchItem: ListViewItem {
    let selectable: Bool = false
    
    let theme: PresentationTheme
    private let placeholder: String
    private let activate: () -> Void
    
    init(theme: PresentationTheme, placeholder: String, activate: @escaping () -> Void) {
        self.theme = theme
        self.placeholder = placeholder
        self.activate = activate
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        async {
            let node = ChatListSearchItemNode()
            node.placeholder = self.placeholder
            
            let makeLayout = node.asyncLayout()
            var nextIsPinned = false
            if let nextItem = nextItem as? ChatListItem, nextItem.index.pinningIndex != nil {
                nextIsPinned = true
            }
            let (layout, apply) = makeLayout(self, params, nextIsPinned)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            node.activate = self.activate
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, {
                        apply(false)
                    })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? ChatListSearchItemNode {
                nodeValue.placeholder = self.placeholder
                let layout = nodeValue.asyncLayout()
                async {
                    var nextIsPinned = false
                    if let nextItem = nextItem as? ChatListItem, nextItem.index.pinningIndex != nil {
                        nextIsPinned = true
                    }
                    let (nodeLayout, apply) = layout(self, params, nextIsPinned)
                    Queue.mainQueue().async {
                        completion(nodeLayout, {
                            apply(animation.isAnimated)
                        })
                    }
                }
            }
        }
    }
}

class ChatListSearchItemNode: ListViewItemNode {
    let searchBarNode: SearchBarPlaceholderNode
    var placeholder: String?
    
    fileprivate var activate: (() -> Void)? {
        didSet {
            self.searchBarNode.activate = self.activate
        }
    }
    
    required init() {
        self.searchBarNode = SearchBarPlaceholderNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.searchBarNode)
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        let makeLayout = self.asyncLayout()
        var nextIsPinned = false
        if let nextItem = nextItem as? ChatListItem, nextItem.index.pinningIndex != nil {
            nextIsPinned = true
        }
        let (layout, apply) = makeLayout(item as! ChatListSearchItem, params, nextIsPinned)
        apply(false)
        self.contentSize = layout.contentSize
        self.insets = layout.insets
    }
    
    func asyncLayout() -> (_ item: ChatListSearchItem, _ params: ListViewItemLayoutParams, _ nextIsPinned: Bool) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let searchBarNodeLayout = self.searchBarNode.asyncLayout()
        let placeholder = self.placeholder
        
        return { item, params, nextIsPinned in
            let baseWidth = params.width - params.leftInset - params.rightInset
            
            let backgroundColor = nextIsPinned ? item.theme.chatList.pinnedItemBackgroundColor : item.theme.chatList.itemBackgroundColor
            
            let searchBarApply = searchBarNodeLayout(NSAttributedString(string: placeholder ?? "", font: searchBarFont, textColor: UIColor(rgb: 0x8e8e93)), CGSize(width: baseWidth - 16.0, height: CGFloat.greatestFiniteMagnitude), UIColor(rgb: 0x8e8e93), nextIsPinned ? item.theme.chatList.pinnedSearchBarColor : item.theme.chatList.regularSearchBarColor, backgroundColor)
            
            let layout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: 44.0), insets: UIEdgeInsets())
            
            return (layout, { [weak self] animated in
                if let strongSelf = self {
                    let transition: ContainedViewLayoutTransition
                    if animated {
                        transition = .animated(duration: 0.3, curve: .easeInOut)
                    } else {
                        transition = .immediate
                    }
                    
                    strongSelf.searchBarNode.frame = CGRect(origin: CGPoint(x: params.leftInset + 8.0, y: 8.0), size: CGSize(width: baseWidth - 16.0, height: 28.0))
                    searchBarApply()
                    
                    strongSelf.searchBarNode.bounds = CGRect(origin: CGPoint(), size: CGSize(width: baseWidth - 16.0, height: 28.0))
                    
                    transition.updateBackgroundColor(node: strongSelf, color: backgroundColor)
                }
            })
        }
    }
}
