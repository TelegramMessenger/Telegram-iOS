import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import SwiftSignalKit

private let searchBarFont = Font.regular(15.0)

class ChatListSearchItem: ListViewItem {
    let selectable: Bool = false
    
    private let placeholder: String
    private let activate: () -> Void
    
    init(placeholder: String, activate: () -> Void) {
        self.placeholder = placeholder
        self.activate = activate
    }
    
    func nodeConfiguredForWidth(async: (() -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: (ListViewItemNode, () -> Void) -> Void) {
        async {
            let node = ChatListSearchItemNode()
            node.placeholder = self.placeholder
            
            let makeLayout = node.asyncLayout()
            let (layout, apply) = makeLayout(width: width)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            node.activate = self.activate
            completion(node, {
                apply()
            })
        }
    }
    
    func updateNode(async: (() -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: (ListViewItemNodeLayout, () -> Void) -> Void) {
        if let node = node as? ChatListSearchItemNode {
            Queue.mainQueue().async {
                let layout = node.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(width: width)
                    Queue.mainQueue().async {
                        completion(nodeLayout, {
                            apply()
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
    
    private var activate: (() -> Void)? {
        didSet {
            self.searchBarNode.activate = self.activate
        }
    }
    
    required init() {
        self.searchBarNode = SearchBarPlaceholderNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.searchBarNode)
    }
    
    override func layoutForWidth(_ width: CGFloat, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        let makeLayout = self.asyncLayout()
        let (layout, apply) = makeLayout(width: width)
        apply()
        self.contentSize = layout.contentSize
        self.insets = layout.insets
    }
    
    func asyncLayout() -> (width: CGFloat) -> (ListViewItemNodeLayout, () -> Void) {
        let searchBarNodeLayout = self.searchBarNode.asyncLayout()
        let placeholder = self.placeholder
        
        return { width in
            let searchBarApply = searchBarNodeLayout(placeholderString: NSAttributedString(string: placeholder ?? "Search", font: searchBarFont, textColor: UIColor(0x8e8e93)), constrainedSize: CGSize(width: width - 16.0, height: CGFloat.greatestFiniteMagnitude))
            
            let layout = ListViewItemNodeLayout(contentSize: CGSize(width: width, height: 44.0), insets: UIEdgeInsets())
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.searchBarNode.frame = CGRect(origin: CGPoint(x: 8.0, y: 8.0), size: CGSize(width: width - 16.0, height: 28.0))
                    searchBarApply()
                    
                    strongSelf.searchBarNode.bounds = CGRect(origin: CGPoint(), size: CGSize(width: width - 16.0, height: 28.0))
                }
            })
        }
    }
}
