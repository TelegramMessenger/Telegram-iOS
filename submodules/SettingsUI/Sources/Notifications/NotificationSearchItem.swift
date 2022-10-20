import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import SearchBarNode

private let searchBarFont = Font.regular(14.0)

class NotificationSearchItem: ListViewItem, ItemListItem {
    let selectable: Bool = false
    
    var sectionId: ItemListSectionId {
        return 0
    }
    var tag: ItemListItemTag? {
        return nil
    }
    var requestsNoInset: Bool {
        return true
    }
    
    let theme: PresentationTheme
    private let placeholder: String
    private let activate: () -> Void
    
    init(theme: PresentationTheme, placeholder: String, activate: @escaping () -> Void) {
        self.theme = theme
        self.placeholder = placeholder
        self.activate = activate
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = NotificationSearchItemNode()
            node.placeholder = self.placeholder
            
            let makeLayout = node.asyncLayout()
            let (layout, apply) = makeLayout(self, params)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            node.activate = self.activate
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in
                        apply(false)
                    })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? NotificationSearchItemNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params)
                    Queue.mainQueue().async {
                        completion(nodeLayout, { _ in
                            apply(animation.isAnimated)
                        })
                    }
                }
            }
        }
    }
}

class NotificationSearchItemNode: ListViewItemNode {
    let searchBarNode: SearchBarPlaceholderNode
    var placeholder: String?
    
    fileprivate var activate: (() -> Void)? {
        didSet {
            self.searchBarNode.activate = self.activate
        }
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    required init() {
        self.searchBarNode = SearchBarPlaceholderNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.searchBarNode)
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        let makeLayout = self.asyncLayout()
        let (layout, apply) = makeLayout(item as! NotificationSearchItem, params)
        apply(false)
        self.contentSize = layout.contentSize
        self.insets = layout.insets
    }
    
    func asyncLayout() -> (_ item: NotificationSearchItem, _ params: ListViewItemLayoutParams) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let searchBarNodeLayout = self.searchBarNode.asyncLayout()
        let placeholder = self.placeholder
        
        return { item, params in
            let baseWidth = params.width - params.leftInset - params.rightInset
            
            let backgroundColor = item.theme.chatList.itemBackgroundColor
            
            let placeholderString = NSAttributedString(string: placeholder ?? "", font: searchBarFont, textColor: UIColor(rgb: 0x8e8e93))
            let (_, searchBarApply) = searchBarNodeLayout(placeholderString, placeholderString, CGSize(width: baseWidth - 16.0, height: 28.0), 1.0, UIColor(rgb: 0x8e8e93), item.theme.chatList.regularSearchBarColor, backgroundColor, .immediate)
            
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
