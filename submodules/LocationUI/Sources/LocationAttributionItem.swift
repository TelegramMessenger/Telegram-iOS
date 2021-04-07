import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import AppBundle

enum LocationAttribution: Equatable {
    case foursquare
    case google
}

class LocationAttributionItem: ListViewItem {
    let presentationData: ItemListPresentationData
    let attribution: LocationAttribution
    
    public init(presentationData: ItemListPresentationData, attribution: LocationAttribution) {
        self.presentationData = presentationData
        self.attribution = attribution
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = LocationAttributionItemNode()
            let makeLayout = node.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(self, params)
            node.contentSize = nodeLayout.contentSize
            node.insets = nodeLayout.insets
            
            completion(node, nodeApply)
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? LocationAttributionItemNode {
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

private class LocationAttributionItemNode: ListViewItemNode {
    private var imageNode: ASImageNode
    
    private var item: LocationAttributionItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    required init() {
        self.imageNode = ASImageNode()
        self.imageNode.displaysAsynchronously = false
        self.imageNode.displayWithoutProcessing = true
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.imageNode)
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
    
    func asyncLayout() -> (_ item: LocationAttributionItem, _ params: ListViewItemLayoutParams) -> (ListViewItemNodeLayout, () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) {
        let currentItem = self.item
    
        return { [weak self] item, params in
            let contentSize = CGSize(width: params.width, height: 55.0)
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
                        
                        if let _ = updatedTheme {
                            switch item.attribution {
                                case .foursquare:
                                    strongSelf.imageNode.image = generateTintedImage(image: UIImage(bundleImageName: "Location/FoursquareAttribution"), color: item.presentationData.theme.list.itemSecondaryTextColor)
                                case .google:
                                    if item.presentationData.theme.overallDarkAppearance {
                                        strongSelf.imageNode.image = generateTintedImage(image: UIImage(bundleImageName: "Location/GoogleAttribution"), color: item.presentationData.theme.list.itemSecondaryTextColor)
                                    } else {
                                        strongSelf.imageNode.image = UIImage(bundleImageName: "Location/GoogleAttribution")
                                    }
                            }
                        }
                        
                        if let image = strongSelf.imageNode.image {
                            strongSelf.imageNode.frame = CGRect(x: floor((params.width - image.size.width) / 2.0), y: floor((contentSize.height - image.size.height) / 2.0), width: image.size.width, height: image.size.height)
                        }
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
