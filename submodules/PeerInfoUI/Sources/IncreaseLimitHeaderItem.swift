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

class IncreaseLimitHeaderItem: ListViewItem, ItemListItem {
    enum Icon {
        case group
        case link
    }
    
    let theme: PresentationTheme
    let strings: PresentationStrings
    let icon: Icon
    let count: Int32
    let limit: Int32
    let premiumCount: Int32
    let text: String
    let isPremiumDisabled: Bool
    let sectionId: ItemListSectionId
    
    init(theme: PresentationTheme, strings: PresentationStrings, icon: Icon, count: Int32, limit: Int32, premiumCount: Int32, text: String, isPremiumDisabled: Bool, sectionId: ItemListSectionId) {
        self.theme = theme
        self.strings = strings
        self.icon = icon
        self.count = count
        self.limit = limit
        self.premiumCount = premiumCount
        self.text = text
        self.isPremiumDisabled = isPremiumDisabled
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
    
    private var params: (AnyComponent<Empty>, CGSize, ListViewItemNodeLayout, CGSize)?
    
    private let titleNode: TextNode
    private let textNode: TextNode
    
    private var item: IncreaseLimitHeaderItem?
    
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
        
        if let (component, containerSize, layout, textSize) = self.params {
            var size = hostView.update(
                transition: .immediate,
                component: component,
                environment: {},
                containerSize: containerSize
            )
            hostView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - size.width) / 2.0), y: -30.0), size: size)
            
            if let item = self.item, item.isPremiumDisabled {
                size.height -= 54.0
            }
            
            let textSpacing: CGFloat = -6.0
            self.textNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - textSize.width) / 2.0), y: size.height + textSpacing), size: textSize)
        }
    }
    
    func asyncLayout() -> (_ item: IncreaseLimitHeaderItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        
        return { item, params, neighbors in
            let topInset: CGFloat = 2.0
            
            let badgeHeight: CGFloat = 200.0
            let textSpacing: CGFloat = -6.0
            let bottomInset: CGFloat = -86.0
            
            let textColor = item.theme.list.freeTextColor
            let attributedText = parseMarkdownIntoAttributedString(item.text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: titleFont, textColor: textColor), linkAttribute: { _ in
                return nil
            }))
            
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, lineSpacing: 0.1, cutout: nil, insets: UIEdgeInsets()))
            
            var contentSize = CGSize(width: params.width, height: topInset + badgeHeight + textSpacing + textLayout.size.height + bottomInset)
            if item.isPremiumDisabled {
                contentSize.height -= 54.0
            }
            
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.accessibilityLabel = attributedText.string
                    
                    let badgeIconName: String
                    switch item.icon {
                    case .group:
                        badgeIconName = "Premium/Group"
                    case .link:
                        badgeIconName = "Premium/Link"
                    }
                    
                    let gradientColors: [UIColor]
                    if item.isPremiumDisabled {
                        gradientColors = [
                            UIColor(rgb: 0x007afe),
                            UIColor(rgb: 0x5494ff)
                        ]
                    } else {
                        gradientColors = [
                            UIColor(rgb: 0x0077ff),
                            UIColor(rgb: 0x6b93ff),
                            UIColor(rgb: 0x8878ff),
                            UIColor(rgb: 0xe46ace)
                        ]
                    }
                    
                    let component = AnyComponent(PremiumLimitDisplayComponent(
                        inactiveColor: item.theme.list.itemBlocksSeparatorColor.withAlphaComponent(0.5),
                        activeColors: gradientColors,
                        inactiveTitle: item.strings.Premium_Free,
                        inactiveValue: item.count > item.limit ? "\(item.limit)" : "",
                        inactiveTitleColor: item.theme.list.itemPrimaryTextColor,
                        activeTitle: item.strings.Premium_Premium,
                        activeValue: item.count >= item.premiumCount ? "" : "\(item.premiumCount)",
                        activeTitleColor: .white,
                        badgeIconName: badgeIconName,
                        badgeText: "\(item.count)",
                        badgePosition: CGFloat(item.count) / CGFloat(item.premiumCount),
                        isPremiumDisabled: item.isPremiumDisabled
                    ))
                    let containerSize = CGSize(width: layout.size.width - params.leftInset - params.rightInset, height: 200.0)
                    
                    let _ = textApply()
                    
                    if let hostView = strongSelf.hostView {
                        var size = hostView.update(
                            transition: .immediate,
                            component: component,
                            environment: {},
                            containerSize: containerSize
                        )
                        if item.isPremiumDisabled {
                            size.height -= 54.0
                        }
                        hostView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - size.width) / 2.0), y: -30.0), size: size)
                        strongSelf.textNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - textLayout.size.width) / 2.0), y: size.height + textSpacing), size: textLayout.size)
                    }
                    
                    strongSelf.params = (component, containerSize, layout, textLayout.size)
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
