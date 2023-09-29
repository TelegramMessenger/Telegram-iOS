import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import Markdown
import ComponentFlow

final class CreateGiveawayHeaderItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let title: String
    let text: String
    let sectionId: ItemListSectionId
    
    init(theme: PresentationTheme, title: String, text: String, sectionId: ItemListSectionId) {
        self.theme = theme
        self.title = title
        self.text = text
        self.sectionId = sectionId
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = CreateGiveawayHeaderItemNode()
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
            guard let nodeValue = node() as? CreateGiveawayHeaderItemNode else {
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

private let titleFont = Font.semibold(20.0)
private let textFont = Font.regular(15.0)

class CreateGiveawayHeaderItemNode: ListViewItemNode {
    private let titleNode: TextNode
    private let textNode: TextNode
    
    private var hostView: ComponentHostView<Empty>?
    
    private var params: (AnyComponent<Empty>, CGSize, ListViewItemNodeLayout)?
        
    private var item: CreateGiveawayHeaderItem?
    
    init() {
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.contentMode = .left
        self.textNode.contentsScale = UIScreen.main.scale
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
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
            hostView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - size.width) / 2.0), y: -121.0), size: size)
        }
    }
    
    func asyncLayout() -> (_ item: CreateGiveawayHeaderItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        
        return { item, params, neighbors in
            let topInset: CGFloat = 2.0
            let leftInset: CGFloat = 24.0 + params.leftInset
        
            let attributedTitle = NSAttributedString(string: item.title, font: titleFont, textColor: item.theme.list.itemPrimaryTextColor, paragraphAlignment: .center)
            let attributedText = NSAttributedString(string: item.text, font: textFont, textColor: item.theme.list.freeTextColor, paragraphAlignment: .center)
                        
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: attributedTitle, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset * 2.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset * 2.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            let contentSize = CGSize(width: params.width, height: topInset + titleLayout.size.height + textLayout.size.height + 80.0)
            
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    let component = AnyComponent(PremiumStarComponent(isIntro: true, isVisible: true, hasIdleAnimations: true))
                    let containerSize = CGSize(width: min(414.0, layout.size.width), height: 220.0)
                    
                    if let hostView = strongSelf.hostView {
                        let size = hostView.update(
                            transition: .immediate,
                            component: component,
                            environment: {},
                            containerSize: containerSize
                        )
                        hostView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - size.width) / 2.0), y: -121.0), size: size)
                    }
                    
                    var origin: CGFloat = 78.0
                    let _ = titleApply()
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - titleLayout.size.width) / 2.0), y: origin), size: titleLayout.size)
                    
                    origin += titleLayout.size.height + 10.0
                    
                    let _ = textApply()
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - textLayout.size.width) / 2.0), y: origin), size: textLayout.size)
                    
                    strongSelf.params = (component, containerSize, layout)
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
