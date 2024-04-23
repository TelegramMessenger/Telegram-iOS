import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import Markdown
import PremiumUI
import ComponentFlow

final class BoostLevelHeaderItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let count: Int32
    let position: CGFloat
    let activeText: String
    let inactiveText: String
    let sectionId: ItemListSectionId
    
    init(theme: PresentationTheme, count: Int32, position: CGFloat, activeText: String, inactiveText: String, sectionId: ItemListSectionId) {
        self.theme = theme
        self.count = count
        self.position = position
        self.activeText = activeText
        self.inactiveText = inactiveText
        self.sectionId = sectionId
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = IncreaseLimitHeaderItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
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
            guard let nodeValue = node() as? IncreaseLimitHeaderItemNode else {
                assertionFailure()
                return
            }
            
            let makeLayout = nodeValue.asyncLayout()
            
            async {
                let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                Queue.mainQueue().async {
                    completion(layout, { _ in
                        apply()
                    })
                }
            }
        }
    }
}

private let titleFont = Font.semibold(17.0)
private let textFont = Font.regular(15.0)
private let boldTextFont = Font.semibold(15.0)

class IncreaseLimitHeaderItemNode: ListViewItemNode {
    private var hostView: ComponentHostView<Empty>?
    
    private var params: (AnyComponent<Empty>, CGSize, ListViewItemNodeLayout)?
        
    private var item: BoostLevelHeaderItem?
    
    init() {
        super.init(layerBacked: false, dynamicBounce: false)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let hostView = ComponentHostView<Empty>()
        self.hostView = hostView
        self.view.addSubview(hostView)
        
        if let (component, containerSize, layout) = self.params {
            let size = hostView.update(
                transition: .immediate,
                component: component,
                environment: {},
                containerSize: containerSize
            )
            hostView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - size.width) / 2.0), y: -5.0), size: size)
        }
    }
    
    func asyncLayout() -> (_ item: BoostLevelHeaderItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        return { item, params, neighbors in
            let topInset: CGFloat = 2.0
            
            let badgeHeight: CGFloat = 200.0
            let bottomInset: CGFloat = -86.0
            
            let contentSize = CGSize(width: params.width, height: topInset + badgeHeight + bottomInset - 5.0)
            
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    let gradientColors: [UIColor]
                    gradientColors = [
                        UIColor(rgb: 0x0077ff),
                        UIColor(rgb: 0x6b93ff),
                        UIColor(rgb: 0x8878ff),
                        UIColor(rgb: 0xe46ace)
                    ]

                    let component = AnyComponent(PremiumLimitDisplayComponent(
                        inactiveColor: item.theme.list.itemBlocksSeparatorColor.withAlphaComponent(0.5),
                        activeColors: gradientColors,
                        inactiveTitle: item.inactiveText,
                        inactiveValue: "",
                        inactiveTitleColor: item.theme.list.itemPrimaryTextColor,
                        activeTitle: "",
                        activeValue: item.activeText,
                        activeTitleColor: .white,
                        badgeIconName: "Premium/Boost",
                        badgeText: "\(item.count)",
                        badgePosition: item.position,
                        badgeGraphPosition: item.position,
                        invertProgress: true,
                        isPremiumDisabled: false
                    ))
                    let containerSize = CGSize(width: layout.size.width - params.leftInset - params.rightInset, height: 200.0)
                    
                    if let hostView = strongSelf.hostView {
                        let size = hostView.update(
                            transition: .immediate,
                            component: component,
                            environment: {},
                            containerSize: containerSize
                        )
                        hostView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - size.width) / 2.0), y: -5.0), size: size)
                    }
                    
                    strongSelf.params = (component, containerSize, layout)
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
