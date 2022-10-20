import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import ShimmerEffect

class BotCheckoutPriceItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let title: String
    let label: String
    let isFinal: Bool
    let hasSeparator: Bool
    let shimmeringIndex: Int?
    let sectionId: ItemListSectionId
    
    let requestsNoInset: Bool = true
    
    init(theme: PresentationTheme, title: String, label: String, isFinal: Bool, hasSeparator: Bool, shimmeringIndex: Int?, sectionId: ItemListSectionId) {
        self.theme = theme
        self.title = title
        self.label = label
        self.isFinal = isFinal
        self.hasSeparator = hasSeparator
        self.shimmeringIndex = shimmeringIndex
        self.sectionId = sectionId
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = BotCheckoutPriceItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem), previousItem, nextItem)
            
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
            if let nodeValue = node() as? BotCheckoutPriceItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem), previousItem, nextItem)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
    
    let selectable: Bool = false
}

private let titleFont = Font.regular(17.0)
private let finalFont = Font.semibold(17.0)

private func priceItemInsets(_ neighbors: ItemListNeighbors) -> UIEdgeInsets {
    var insets = UIEdgeInsets()
    switch neighbors.top {
        case .otherSection:
            insets.top += 24.0
        case .none, .sameSection:
            break
    }
    switch neighbors.bottom {
        case .none, .otherSection:
            insets.bottom += 24.0
        case .sameSection:
            break
    }
    return insets
}

class BotCheckoutPriceItemNode: ListViewItemNode {
    let titleNode: TextNode
    let labelNode: TextNode

    let backgroundNode: ASDisplayNode
    let separatorNode: ASDisplayNode
    let bottomSeparatorNode: ASDisplayNode
    private let maskNode: ASImageNode

    private var placeholderNode: ShimmerEffectNode?
    private var absoluteLocation: (CGRect, CGSize)?
    
    private var item: BotCheckoutPriceItem?
    
    init() {
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false

        self.backgroundNode = ASDisplayNode()
        self.separatorNode = ASDisplayNode()
        self.bottomSeparatorNode = ASDisplayNode()
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        super.init(layerBacked: false, dynamicBounce: false)

        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.labelNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.bottomSeparatorNode)
    }

    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        var rect = rect
        rect.origin.y += self.insets.top
        self.absoluteLocation = (rect, containerSize)
        if let shimmerNode = self.placeholderNode {
            shimmerNode.updateAbsoluteRect(rect, within: containerSize)
        }
    }
    
    func asyncLayout() -> (_ item: BotCheckoutPriceItem, _ params: ListViewItemLayoutParams, _ insets: ItemListNeighbors, _ previousItem: ListViewItem?, _ nextItem: ListViewItem?) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        
        return { item, params, neighbors, previousItem, nextItem in
            let rightInset: CGFloat = 16.0 + params.rightInset

            let naturalContentHeight: CGFloat
            var verticalOffset: CGFloat = 0.0
            if item.isFinal {
                naturalContentHeight = 44.0
            } else {
                switch neighbors.bottom {
                case .otherSection, .none:
                    naturalContentHeight = 44.0
                default:
                    naturalContentHeight = 34.0
                }
            }
            if let _ = previousItem as? BotCheckoutHeaderItem {
                verticalOffset += 8.0
            }
            
            var contentSize = CGSize(width: params.width, height: naturalContentHeight + verticalOffset)
            if let nextItem = nextItem as? BotCheckoutPriceItem {
                if nextItem.isFinal {
                    contentSize.height += 8.0
                }
            }
            let insets = priceItemInsets(neighbors)
            
            let textFont: UIFont
            let textColor: UIColor
            if item.isFinal {
                textFont = finalFont
                textColor = item.theme.list.itemPrimaryTextColor
            } else {
                textFont = titleFont
                textColor = item.theme.list.itemSecondaryTextColor
            }
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: textFont, textColor: textColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.label, font: textFont, textColor: textColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            return (ListViewItemNodeLayout(contentSize: contentSize, insets: insets), { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    let _ = titleApply()
                    let _ = labelApply()
                    
                    let leftInset: CGFloat = 16.0 + params.leftInset

                    if strongSelf.maskNode.supernode == nil {
                        strongSelf.addSubnode(strongSelf.maskNode)
                    }
                    
                    let hasCorners = itemListHasRoundedBlockLayout(params)
                    var hasTopCorners = false
                    var hasBottomCorners = false
                    switch neighbors.top {
                        case .sameSection(false):
                            break
                        default:
                            hasTopCorners = true
                    }
                    switch neighbors.bottom {
                    case .sameSection(false):
                        strongSelf.bottomSeparatorNode.isHidden = false
                    default:
                        hasBottomCorners = true
                        strongSelf.bottomSeparatorNode.isHidden = !item.isFinal || hasCorners
                    }
                    
                    strongSelf.separatorNode.isHidden = !item.hasSeparator || (hasCorners && hasTopCorners)
                    strongSelf.separatorNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                    strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: CGSize(width: params.width - leftInset, height: UIScreenPixel))
                    
                    strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                    
                    strongSelf.bottomSeparatorNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                    strongSelf.bottomSeparatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: contentSize.height), size: CGSize(width: params.width, height: UIScreenPixel))

                    strongSelf.backgroundNode.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: params.width, height: contentSize.height))
                    strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: verticalOffset + floor((naturalContentHeight - titleLayout.size.height) / 2.0)), size: titleLayout.size)
                    strongSelf.labelNode.frame = CGRect(origin: CGPoint(x: params.width - rightInset - labelLayout.size.width, y: verticalOffset + floor((naturalContentHeight - labelLayout.size.height) / 2.0)), size: labelLayout.size)

                    if let shimmeringIndex = item.shimmeringIndex {
                        let shimmerNode: ShimmerEffectNode
                        if let current = strongSelf.placeholderNode {
                            shimmerNode = current
                        } else {
                            shimmerNode = ShimmerEffectNode()
                            strongSelf.placeholderNode = shimmerNode
                            if strongSelf.separatorNode.supernode != nil {
                                strongSelf.insertSubnode(shimmerNode, belowSubnode: strongSelf.separatorNode)
                            } else {
                                strongSelf.addSubnode(shimmerNode)
                            }
                        }
                        shimmerNode.frame = CGRect(origin: CGPoint(), size: contentSize)
                        if let (rect, size) = strongSelf.absoluteLocation {
                            shimmerNode.updateAbsoluteRect(rect, within: size)
                        }

                        var shapes: [ShimmerEffectNode.Shape] = []

                        let titleLineWidth: CGFloat = (shimmeringIndex % 2 == 0) ? 120.0 : 80.0
                        let lineDiameter: CGFloat = 8.0

                        let titleFrame = strongSelf.titleNode.frame
                        shapes.append(.roundedRectLine(startPoint: CGPoint(x: titleFrame.minX, y: titleFrame.minY + floor((titleFrame.height - lineDiameter) / 2.0)), width: titleLineWidth, diameter: lineDiameter))

                        shimmerNode.update(backgroundColor: item.theme.list.itemBlocksBackgroundColor, foregroundColor: item.theme.list.mediaPlaceholderColor, shimmeringColor: item.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4), shapes: shapes, size: contentSize)
                    } else if let shimmerNode = strongSelf.placeholderNode {
                        strongSelf.placeholderNode = nil
                        shimmerNode.removeFromSupernode()
                    }
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
