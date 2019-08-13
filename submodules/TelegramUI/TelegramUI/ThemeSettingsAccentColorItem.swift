import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI

private func generateSwatchImage(color: PresentationThemeAccentColor, selected: Bool) -> UIImage? {
    return generateImage(CGSize(width: 40.0, height: 40.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let fillColor = color.color
        var strokeColor = color.baseColor.color
        if strokeColor == .clear {
            strokeColor = fillColor
        }
        
        context.setFillColor(fillColor.cgColor)
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(2.0)
        
        if selected {
            context.fillEllipse(in: bounds.insetBy(dx: 4.0, dy: 4.0))
            context.strokeEllipse(in: bounds.insetBy(dx: 1.0, dy: 1.0))
        } else {
            context.fillEllipse(in: bounds)
        }
    })?.stretchableImage(withLeftCapWidth: 15, topCapHeight: 15)
}

private func generateCustomSwatchImage() -> UIImage? {
    return generateImage(CGSize(width: 42.0, height: 42.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let dotSize = CGSize(width: 10.0, height: 10.0)
        
        context.setFillColor(UIColor(rgb: 0xd33213).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 14.0, y: 16.0), size: dotSize))
        
        context.setFillColor(UIColor(rgb: 0xf08200).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 14.0, y: 0.0), size: dotSize))
        
        context.setFillColor(UIColor(rgb: 0xedb400).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 28.0, y: 8.0), size: dotSize))
        
        context.setFillColor(UIColor(rgb: 0x70bb23).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 28.0, y: 24.0), size: dotSize))
        
        context.setFillColor(UIColor(rgb: 0x5396fa).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 14.0, y: 32.0), size: dotSize))
        
        context.setFillColor(UIColor(rgb: 0x9472ee).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 24.0), size: dotSize))
        
        context.setFillColor(UIColor(rgb: 0xeb6ca4).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 8.0), size: dotSize))
    })
}

class ThemeSettingsAccentColorItem: ListViewItem, ItemListItem {
    var sectionId: ItemListSectionId
    
    let theme: PresentationTheme
    let colors: [PresentationThemeBaseColor]
    let currentColor: PresentationThemeAccentColor
    let updated: (PresentationThemeAccentColor) -> Void
    let openColorPicker: () -> Void
    let tag: ItemListItemTag?
    
    init(theme: PresentationTheme, sectionId: ItemListSectionId, colors: [PresentationThemeBaseColor], currentColor: PresentationThemeAccentColor, updated: @escaping (PresentationThemeAccentColor) -> Void, openColorPicker: @escaping () -> Void, tag: ItemListItemTag? = nil) {
        self.theme = theme
        self.colors = colors
        self.currentColor = currentColor
        self.updated = updated
        self.openColorPicker = openColorPicker
        self.tag = tag
        self.sectionId = sectionId
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ThemeSettingsAccentColorItemNode()
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
            if let nodeValue = node() as? ThemeSettingsAccentColorItemNode {
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

private final class ThemeSettingsAccentColorNode : ASDisplayNode {
    private let iconNode: ASImageNode
    private var action: (() -> Void)?
    
    override init() {
        self.iconNode = ASImageNode()
        self.iconNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 62.0, height: 62.0))
        self.iconNode.isLayerBacked = true
        
        super.init()
        
        self.addSubnode(self.iconNode)
    }
    
    func setup(color: PresentationThemeAccentColor, selected: Bool, action: @escaping () -> Void) {
        self.iconNode.image = generateSwatchImage(color: color, selected: selected)
        self.action = {
            action()
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.action?()
        }
    }
    
    override func layout() {
        super.layout()

        self.iconNode.frame = self.bounds
    }
}


private let textFont = Font.regular(11.0)
private let itemSize = Font.regular(11.0)

class ThemeSettingsAccentColorItemNode: ListViewItemNode, ItemListItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    
    private let scrollNode: ASScrollNode
    private var colorNodes: [ThemeSettingsAccentColorNode] = []
    private let customNode: HighlightableButtonNode
    
    private var item: ThemeSettingsAccentColorItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    var tag: ItemListItemTag? {
        return self.item?.tag
    }
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.scrollNode = ASScrollNode()
        
        self.customNode = HighlightableButtonNode()
        
        super.init(layerBacked: false, dynamicBounce: false)

        self.customNode.setImage(generateCustomSwatchImage(), for: .normal)
        self.customNode.addTarget(self, action: #selector(customPressed), forControlEvents: .touchUpInside)
        
        self.addSubnode(self.scrollNode)
        self.scrollNode.addSubnode(self.customNode)
    }
    
    override func didLoad() {
        super.didLoad()
        self.scrollNode.view.disablesInteractiveTransitionGestureRecognizer = true
        self.scrollNode.view.showsHorizontalScrollIndicator = false
    }
    
    @objc func customPressed() {
        self.item?.openColorPicker()
    }
    
    private func scrollToNode(_ node: ThemeSettingsAccentColorNode, animated: Bool) {
        let bounds = self.scrollNode.view.bounds
        let frame = node.frame.insetBy(dx: -48.0, dy: 0.0)
        
        if frame.minX < bounds.minX || frame.maxX > bounds.maxX {
            self.scrollNode.view.scrollRectToVisible(frame, animated: animated)
        }
    }
    
    func asyncLayout() -> (_ item: ThemeSettingsAccentColorItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let currentItem = self.item
        
        return { item, params, neighbors in
            var themeUpdated = false
            if currentItem?.theme !== item.theme {
                themeUpdated = true
            }
            
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            contentSize = CGSize(width: params.width, height: 60.0)
            insets = itemListNeighborsGroupedInsets(neighbors)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.layoutParams = params
                    
                    strongSelf.scrollNode.view.contentInset = UIEdgeInsets(top: 0.0, left: params.leftInset, bottom: 0.0, right: params.rightInset)
                    strongSelf.backgroundNode.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                    strongSelf.topStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                    strongSelf.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                    
                    if strongSelf.backgroundNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                    }
                    if strongSelf.topStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                    }
                    switch neighbors.top {
                        case .sameSection(false):
                            strongSelf.topStripeNode.isHidden = true
                        default:
                            strongSelf.topStripeNode.isHidden = false
                    }
                    let bottomStripeInset: CGFloat
                    let bottomStripeOffset: CGFloat
                    switch neighbors.bottom {
                        case .sameSection(false):
                            bottomStripeInset = params.leftInset + 16.0
                            bottomStripeOffset = -separatorHeight
                        default:
                            bottomStripeInset = 0.0
                            bottomStripeOffset = 0.0
                    }
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight))
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight))
                    
                    strongSelf.scrollNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layoutSize.width, height: layoutSize.height))
                    
                    let nodeInset: CGFloat = 15.0
                    let nodeSize = CGSize(width: 40.0, height: 40.0)
                    var nodeOffset = nodeInset
                    
                    var updated = false
                    var selectedNode: ThemeSettingsAccentColorNode?
                    
                    var i = 0
                    for color in item.colors {
                        let imageNode: ThemeSettingsAccentColorNode
                        if strongSelf.colorNodes.count > i {
                            imageNode = strongSelf.colorNodes[i]
                        } else {
                            imageNode = ThemeSettingsAccentColorNode()
                            strongSelf.colorNodes.append(imageNode)
                            strongSelf.scrollNode.addSubnode(imageNode)
                            updated = true
                        }
                        
                        let accentColor: PresentationThemeAccentColor
                        let selected = item.currentColor.baseColor == color
                        if selected {
                            accentColor = item.currentColor
                            selectedNode = imageNode
                        } else {
                            accentColor = PresentationThemeAccentColor(baseColor: color)
                        }
                        
                        imageNode.setup(color: accentColor, selected: selected, action: { [weak self, weak imageNode] in
                            item.updated(accentColor)
                            if let imageNode = imageNode {
                                self?.scrollToNode(imageNode, animated: true)
                            }
                        })
                        
                        imageNode.frame = CGRect(origin: CGPoint(x: nodeOffset, y: 10.0), size: nodeSize)
                        nodeOffset += nodeSize.width + 18.0
                        
                        i += 1
                    }
                    
                    strongSelf.customNode.frame = CGRect(origin: CGPoint(x: nodeOffset, y: 9.0), size: CGSize(width: 42.0, height: 42.0))
                    
                    for k in (i ..< strongSelf.colorNodes.count).reversed() {
                        let node = strongSelf.colorNodes[k]
                        strongSelf.colorNodes.remove(at: k)
                        node.removeFromSupernode()
                    }
                
                    let contentSize = CGSize(width: strongSelf.customNode.frame.maxX + nodeInset, height: strongSelf.scrollNode.frame.height)
                    if strongSelf.scrollNode.view.contentSize != contentSize {
                        strongSelf.scrollNode.view.contentSize = contentSize
                    }
                    
                    if updated, let selectedNode = selectedNode {
                        strongSelf.scrollToNode(selectedNode, animated: false)
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

