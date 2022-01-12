import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils

struct StorageUsageCategory: Equatable {
    let title: String
    let size: Int64
    let fraction: CGFloat
    let color: UIColor
}

final class StorageUsageItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let dateTimeFormat: PresentationDateTimeFormat
    let categories: [StorageUsageCategory]
    let sectionId: ItemListSectionId
    
    init(theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, categories: [StorageUsageCategory], sectionId: ItemListSectionId) {
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.categories = categories
        self.sectionId = sectionId
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = StorageUsageItemNode()
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
            if let nodeValue = node() as? StorageUsageItemNode {
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
}

private func generateDotImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 8.0, height: 8.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: bounds)
    })
}

private func generateLineMaskImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 8.0, height: 8.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.setFillColor(color.cgColor)
        context.fill(bounds)

        context.setBlendMode(.clear)
        context.setFillColor(UIColor.clear.cgColor)
        context.fillEllipse(in: bounds)
    })?.stretchableImage(withLeftCapWidth: 4, topCapHeight: 4)
}

private final class StorageUsageItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let lineMaskNode: ASImageNode
    private var lineNodes: [ASDisplayNode]
    private var descriptionNodes: [(ASImageNode, TextNode)]

    private var item: StorageUsageItem?
    private var layoutParams: ListViewItemLayoutParams?

    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.maskNode = ASImageNode()
        
        self.lineMaskNode = ASImageNode()
        self.lineMaskNode.displaysAsynchronously = false
        self.lineMaskNode.displayWithoutProcessing = true
        self.lineMaskNode.contentMode = .scaleToFill
        
        self.lineNodes = []
        self.descriptionNodes = []
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.lineMaskNode)
    }
    
    func asyncLayout() -> (_ item: StorageUsageItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let currentItem = self.item
        
        return { [weak self] item, params, neighbors in
            if let strongSelf = self, strongSelf.lineNodes.count != item.categories.count {
                for node in strongSelf.lineNodes {
                    node.removeFromSupernode()
                }
                
                strongSelf.lineNodes = []
                
                for pair in strongSelf.descriptionNodes {
                    pair.0.removeFromSupernode()
                    pair.1.removeFromSupernode()
                }
                
                strongSelf.descriptionNodes = []
                
                for _ in item.categories {
                    let lineNode = ASDisplayNode()
                    strongSelf.insertSubnode(lineNode, belowSubnode: strongSelf.lineMaskNode)
                    strongSelf.lineNodes.append(lineNode)
                    
                    let dotNode = ASImageNode()
                    dotNode.displaysAsynchronously = false
                    dotNode.displayWithoutProcessing = true
                    strongSelf.addSubnode(dotNode)
                    
                    let textNode = TextNode()
                    strongSelf.addSubnode(textNode)
                    
                    strongSelf.descriptionNodes.append((dotNode, textNode))
                }
            }
            
            var makeNodesLayout: [(TextNodeLayoutArguments) -> (TextNodeLayout, () -> TextNode)] = []
            if let strongSelf = self {
                for nodes in strongSelf.descriptionNodes {
                    let makeTextLayout = TextNode.asyncLayout(nodes.1)
                    makeNodesLayout.append(makeTextLayout)
                }
            }
            
            var themeUpdated = false
            if currentItem?.theme !== item.theme {
                themeUpdated = true
            }
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
                        
            var textFramesApplies: [(CGRect, () -> TextNode)] = []
            
            let inset: CGFloat = 16.0
            let horizontalSpacing: CGFloat = 32.0
            let verticalSpacing: CGFloat = 22.0
            var textOrigin: CGPoint = CGPoint(x: params.leftInset + horizontalSpacing, y: 52.0)
            
            for i in 0 ..< item.categories.count {
                let makeTextLayout = makeNodesLayout[i]
                let category = item.categories[i]
                
                let attributedString = NSMutableAttributedString(string: category.title, font: Font.regular(14.0), textColor: item.theme.list.itemPrimaryTextColor, paragraphAlignment: .natural)
                attributedString.append(NSAttributedString(string: " • \(dataSizeString(category.size, forceDecimal: true, formatting: DataSizeStringFormatting(strings: item.strings, decimalSeparator: item.dateTimeFormat.decimalSeparator)))", font: Font.bold(14.0), textColor: item.theme.list.itemPrimaryTextColor))
                
                let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: attributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - 60.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                
                var textFrame = CGRect(origin: textOrigin, size: textLayout.size)
                if textFrame.maxX > params.width - params.rightInset - inset {
                    textFrame.origin = CGPoint(x: params.leftInset + horizontalSpacing, y: textOrigin.y + verticalSpacing)
                }
 
                textOrigin = CGPoint(x: textFrame.maxX + horizontalSpacing, y: textFrame.minY)
                
                textFramesApplies.append((textFrame, textApply))
            }
            
            contentSize = CGSize(width: params.width, height: textOrigin.y + 34.0)
            insets = itemListNeighborsGroupedInsets(neighbors, params)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.layoutParams = params
                    
                    strongSelf.backgroundNode.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                    strongSelf.topStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                    strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                    
                    if themeUpdated {
                        strongSelf.lineMaskNode.image = generateLineMaskImage(color: item.theme.list.itemBlocksBackgroundColor)
                    }
                    
                    for (_, textApply) in textFramesApplies {
                        let _ = textApply()
                    }
                    
                    if strongSelf.backgroundNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                    }
                    if strongSelf.topStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                    }
                    if strongSelf.maskNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.maskNode, at: 3)
                    }
                    
                    let hasCorners = itemListHasRoundedBlockLayout(params)
                    var hasTopCorners = false
                    var hasBottomCorners = false
                    switch neighbors.top {
                        case .sameSection(false):
                            strongSelf.topStripeNode.isHidden = true
                        default:
                            hasTopCorners = true
                            strongSelf.topStripeNode.isHidden = hasCorners
                    }
                    let bottomStripeInset: CGFloat
                    let bottomStripeOffset: CGFloat
                    switch neighbors.bottom {
                        case .sameSection(false):
                            bottomStripeInset = 0.0
                            bottomStripeOffset = -separatorHeight
                            strongSelf.bottomStripeNode.isHidden = false
                        default:
                            bottomStripeInset = 0.0
                            bottomStripeOffset = 0.0
                            hasBottomCorners = true
                            strongSelf.bottomStripeNode.isHidden = hasCorners
                    }
                    
                    strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
                    
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    
                    let lineInset: CGFloat = params.leftInset + 12.0
                    var lineOrigin = CGPoint(x: lineInset, y: 16.0)
                    let lineWidth = params.width - lineOrigin.x * 2.0
                    
                    strongSelf.lineMaskNode.frame = CGRect(origin: lineOrigin, size: CGSize(width: lineWidth, height: 21.0))
                    
                    for i in 0 ..< strongSelf.lineNodes.count {
                        let lineNode = strongSelf.lineNodes[i]
                        let category = item.categories[i]
                        
                        lineNode.backgroundColor = category.color
                        
                        var categoryWidth = max(floor(lineWidth * category.fraction), 2.0)
                        if i == strongSelf.lineNodes.count - 1 {
                            categoryWidth = max(0.0, lineWidth - (lineOrigin.x - lineInset))
                        }
                        
                        let lineRect = CGRect(origin: lineOrigin, size: CGSize(width: categoryWidth, height: 21.0))
                        lineNode.frame = lineRect
                        
                        lineOrigin.x += lineRect.width + 1.0
                    }
                    
                    for i in 0 ..< strongSelf.descriptionNodes.count {
                        let dotNode = strongSelf.descriptionNodes[i].0
                        let textNode = strongSelf.descriptionNodes[i].1
                        let textFrame = textFramesApplies[i].0
                        let category = item.categories[i]
                        
                        if dotNode.image == nil || themeUpdated {
                            dotNode.image = generateDotImage(color: category.color)
                        }
                        dotNode.frame = CGRect(x: textFrame.minX - 16.0, y: textFrame.minY + 4.0, width: 8.0, height: 8.0)
                        
                        textNode.frame = textFrame
                    }
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
