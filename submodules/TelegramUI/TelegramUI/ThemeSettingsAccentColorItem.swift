import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences

private func generateSwatchImage(color: PresentationThemeAccentColor, selected: Bool) -> UIImage? {
    return generateImage(CGSize(width: 40.0, height: 40.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        
        context.clear(bounds)
        
        let fillColor = color.color
        let strokeColor = color.baseColor.color
        
        context.setFillColor(fillColor.cgColor)
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(2.0)
        
        if selected {
            context.fillEllipse(in: bounds.insetBy(dx: 4.0, dy: 4.0))
            context.strokeEllipse(in: bounds.insetBy(dx: 1.0, dy: 1.0))
            
            if false, color.baseColor != .white && color.baseColor != .black {
                context.setFillColor(UIColor.white.cgColor)
                context.fillEllipse(in: CGRect(x: 11.0, y: 18.0, width: 4.0, height: 4.0))
                context.fillEllipse(in: CGRect(x: 18.0, y: 18.0, width: 4.0, height: 4.0))
                context.fillEllipse(in: CGRect(x: 25.0, y: 18.0, width: 4.0, height: 4.0))
            }
        } else {
            context.fillEllipse(in: bounds)
        }
    })?.stretchableImage(withLeftCapWidth: 15, topCapHeight: 15)
}

class ThemeSettingsAccentColorItem: ListViewItem, ItemListItem {
    var sectionId: ItemListSectionId
    
    let theme: PresentationTheme
    let colors: [PresentationThemeBaseColor]
    let currentColor: PresentationThemeAccentColor
    let updated: (PresentationThemeAccentColor) -> Void
    let toggleSlider: (PresentationThemeBaseColor) -> Void
    let tag: ItemListItemTag?
    
    init(theme: PresentationTheme, sectionId: ItemListSectionId, colors: [PresentationThemeBaseColor], currentColor: PresentationThemeAccentColor, updated: @escaping (PresentationThemeAccentColor) -> Void, toggleSlider: @escaping (PresentationThemeBaseColor) -> Void, tag: ItemListItemTag? = nil) {
        self.theme = theme
        self.colors = colors
        self.currentColor = currentColor
        self.updated = updated
        self.toggleSlider = toggleSlider
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

        self.iconNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 40.0, height: 40.0))
    }
}


private let textFont = Font.regular(11.0)
private let itemSize = Font.regular(11.0)

class ThemeSettingsAccentColorItemNode: ListViewItemNode, ItemListItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    
    private let scrollNode: ASScrollNode
    private var nodes: [ThemeSettingsAccentColorNode] = []
    
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
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.scrollNode)
    }
    
    override func didLoad() {
        super.didLoad()
        self.scrollNode.view.disablesInteractiveTransitionGestureRecognizer = true
        self.scrollNode.view.showsHorizontalScrollIndicator = false
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
                    
                    strongSelf.scrollNode.view.contentInset = UIEdgeInsetsMake(0.0, params.leftInset, 0.0, params.rightInset)
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
                        if strongSelf.nodes.count > i {
                            imageNode = strongSelf.nodes[i]
                        } else {
                            imageNode = ThemeSettingsAccentColorNode()
                            strongSelf.nodes.append(imageNode)
                            strongSelf.scrollNode.addSubnode(imageNode)
                            updated = true
                        }
                        
                        let accentColor: PresentationThemeAccentColor
                        let selected = item.currentColor.baseColor == color
                        if selected {
                            accentColor = item.currentColor
                            selectedNode = imageNode
                        } else {
                            accentColor = PresentationThemeAccentColor(baseColor: color, value: 0.5)
                        }
                        
                        imageNode.setup(color: accentColor, selected: selected, action: { [weak self, weak imageNode, weak selectedNode] in
                            item.updated(accentColor)
                            if let imageNode = imageNode {
                                self?.scrollToNode(imageNode, animated: true)
                            }
                            
                            if imageNode == selectedNode {
                                item.toggleSlider(accentColor.baseColor)
                            }
                        })
                        
                        imageNode.frame = CGRect(origin: CGPoint(x: nodeOffset, y: 10.0), size: nodeSize)
                        nodeOffset += nodeSize.width + 18.0
                        
                        i += 1
                    }
                    
                    for k in (i ..< strongSelf.nodes.count).reversed() {
                        let node = strongSelf.nodes[k]
                        strongSelf.nodes.remove(at: k)
                        node.removeFromSupernode()
                    }
                    
                    if let lastNode = strongSelf.nodes.last {
                        let contentSize = CGSize(width: lastNode.frame.maxX + nodeInset, height: strongSelf.scrollNode.frame.height)
                        if strongSelf.scrollNode.view.contentSize != contentSize {
                            strongSelf.scrollNode.view.contentSize = contentSize
                        }
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

