import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import ListSectionHeaderNode
import ItemListUI

class LocationSectionHeaderItem: ListViewItem {
    let presentationData: ItemListPresentationData
    let title: String
    
    public init(presentationData: ItemListPresentationData, title: String) {
        self.presentationData = presentationData
        self.title = title
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = LocationSectionHeaderItemNode()
            let makeLayout = node.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(self, params)
            node.contentSize = nodeLayout.contentSize
            node.insets = nodeLayout.insets
            
            completion(node, nodeApply)
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? LocationSectionHeaderItemNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params)
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
        return false
    }
}

private class LocationSectionHeaderItemNode: ListViewItemNode {
    private var headerNode: ListSectionHeaderNode?
    
    private var item: LocationSectionHeaderItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    required init() {
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = self.item {
            let makeLayout = self.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(item, params)
            self.contentSize = nodeLayout.contentSize
            self.insets = nodeLayout.insets
            let _ = nodeApply()
        }
    }
    
    func asyncLayout() -> (_ item: LocationSectionHeaderItem, _ params: ListViewItemLayoutParams) -> (ListViewItemNodeLayout, () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) {
        let currentItem = self.item
    
        return { [weak self] item, params in
            let contentSize = CGSize(width: params.width, height: 28.0)
            let nodeLayout = ListViewItemNodeLayout(contentSize: contentSize, insets: UIEdgeInsets())
            
            return (nodeLayout, { [weak self] in
                var updatedTheme: PresentationTheme?
                if currentItem?.presentationData.theme !== item.presentationData.theme {
                    updatedTheme = item.presentationData.theme
                }
                
                return (nil, { _ in
                    if let strongSelf = self {
                        strongSelf.item = item
                        strongSelf.layoutParams = params
                         
                        let headerNode: ListSectionHeaderNode
                        if let currentHeaderNode = strongSelf.headerNode {
                            headerNode = currentHeaderNode
                            
                            if let _ = updatedTheme {
                                headerNode.updateTheme(theme: item.presentationData.theme)
                            }
                        } else {
                            headerNode = ListSectionHeaderNode(theme: item.presentationData.theme)
                            headerNode.title = item.title
                            strongSelf.addSubnode(headerNode)
                            strongSelf.headerNode = headerNode
                        }

                        headerNode.frame = CGRect(origin: CGPoint(), size: contentSize)
                        headerNode.updateLayout(size: contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
                    }
                })
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.5, removeOnCompletion: false)
    }
}
