import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import Markdown

class IncreaseLimitHeaderItem: ListViewItem, ItemListItem {
    enum Icon {
        case group
        case link
    }
    
    let theme: PresentationTheme
    let icon: Icon
    let count: Int
    let title: String
    let text: String
    let sectionId: ItemListSectionId
    
    init(theme: PresentationTheme, icon: Icon, count: Int, title: String, text: String, sectionId: ItemListSectionId) {
        self.theme = theme
        self.icon = icon
        self.count = count
        self.title = title
        self.text = text
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
private let textFont = Font.regular(14.0)
private let boldTextFont = Font.semibold(13.0)

class IncreaseLimitHeaderItemNode: ListViewItemNode {
    private var backgroundNode: ASImageNode
    private var iconNode: ASImageNode
    private var countNode: TextNode
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
                        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.clipsToBounds = true
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.image = generateGradientImage(size: CGSize(width: 100.0, height: 47.0), colors: [UIColor(rgb: 0xa44ece), UIColor(rgb: 0xff7924)], locations: [0.0, 1.0], direction: .horizontal)
        self.backgroundNode.cornerRadius = 23.5
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        
        self.countNode = TextNode()
        self.countNode.isUserInteractionEnabled = false
        self.countNode.contentMode = .left
        self.countNode.contentsScale = UIScreen.main.scale
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.countNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        if #available(iOS 13.0, *) {
            self.backgroundNode.layer.cornerCurve = .continuous
        }
    }
    
    func asyncLayout() -> (_ item: IncreaseLimitHeaderItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeCountLayout = TextNode.asyncLayout(self.countNode)
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        
        return { item, params, neighbors in
            let leftInset: CGFloat = 32.0 + params.leftInset
            let topInset: CGFloat = 2.0
            
            let badgeHeight: CGFloat = 47.0
            let titleSpacing: CGFloat = 19.0
            let textSpacing: CGFloat = 15.0
            let bottomInset: CGFloat = 2.0
            
            let countAttributedText = NSAttributedString(string: "\(item.count)", font: Font.with(size: 24.0, design: .round, weight: .semibold, traits: []), textColor: .white)
            let (countLayout, countApply) = makeCountLayout(TextNodeLayoutArguments(attributedString: countAttributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - params.rightInset - leftInset * 2.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            let titleAttributedText = NSAttributedString(string: item.title, font: titleFont, textColor: item.theme.list.itemPrimaryTextColor)
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - params.rightInset - leftInset * 2.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            let textColor = item.theme.list.freeTextColor
            let attributedText = parseMarkdownIntoAttributedString(item.text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: titleFont, textColor: textColor), linkAttribute: { _ in
                return nil
            }))
            
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - params.rightInset - leftInset * 2.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            let contentSize = CGSize(width: params.width, height: topInset + badgeHeight + titleSpacing + titleLayout.size.height + textSpacing + textLayout.size.height + bottomInset)
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.accessibilityLabel = attributedText.string
                    
                    if strongSelf.iconNode.image == nil {
                        let image: UIImage?
                        switch item.icon {
                            case .group:
                                image = UIImage(bundleImageName: "Premium/Group")
                            case .link:
                                image = UIImage(bundleImageName: "Premium/Link")
                        }
                        strongSelf.iconNode.image = generateTintedImage(image: image, color: .white)
                    }
                                        
                    let countBackgroundWidth: CGFloat = countLayout.size.width + 67.0
                    let countBackgroundFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - countBackgroundWidth) / 2.0), y: topInset), size: CGSize(width: countBackgroundWidth, height: badgeHeight))
                    strongSelf.backgroundNode.frame = countBackgroundFrame
                    
                    let _ = countApply()
                    strongSelf.countNode.frame = CGRect(origin: CGPoint(x: countBackgroundFrame.maxX - countLayout.size.width - 15.0, y: countBackgroundFrame.minY + floorToScreenPixels((countBackgroundFrame.height - countLayout.size.height) / 2.0)), size: countLayout.size)
                    
                    if let image = strongSelf.iconNode.image {
                        strongSelf.iconNode.frame = CGRect(origin: CGPoint(x: countBackgroundFrame.minX + 18.0, y: countBackgroundFrame.minY + floorToScreenPixels((countBackgroundFrame.height - image.size.height) / 2.0)), size: image.size)
                    }
                    
                    let _ = titleApply()
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - titleLayout.size.width) / 2.0), y: countBackgroundFrame.maxY + titleSpacing), size: titleLayout.size)
                    
                    let _ = textApply()
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - textLayout.size.width) / 2.0), y: countBackgroundFrame.maxY + titleSpacing + titleLayout.size.height + textSpacing), size: textLayout.size)
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
