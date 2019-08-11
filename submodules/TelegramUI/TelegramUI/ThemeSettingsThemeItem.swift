import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences

private func generateBorderImage(theme: PresentationTheme, bordered: Bool, selected: Bool) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 30.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.setFillColor(theme.list.itemBlocksBackgroundColor.cgColor)
        context.fill(bounds)
        
        context.setBlendMode(.clear)
        context.fillEllipse(in: bounds)
        context.setBlendMode(.normal)
        
        let lineWidth: CGFloat
        if selected {
            var accentColor = theme.list.itemAccentColor
            if accentColor.rgb == UIColor.white.rgb {
                accentColor = UIColor(rgb: 0x999999)
            }
            context.setStrokeColor(accentColor.cgColor)
            lineWidth = 2.0
        } else {
            context.setStrokeColor(theme.list.disclosureArrowColor.withAlphaComponent(0.4).cgColor)
            lineWidth = 1.0
        }
        
        if bordered || selected {
            context.setLineWidth(lineWidth)
            context.strokeEllipse(in: bounds.insetBy(dx: lineWidth / 2.0, dy: lineWidth / 2.0))
        }
    })?.stretchableImage(withLeftCapWidth: 15, topCapHeight: 15)
}

private func generateThemeIconImage(theme: PresentationThemeReference, accentColor: UIColor?) -> UIImage {
    return generateImage(CGSize(width: 98.0, height: 62.0), rotatedContext: { size, context in
        guard case let .builtin(theme) = theme else {
            return
        }
        let bounds = CGRect(origin: CGPoint(), size: size)
        
        let background: UIColor
        let incomingFill: UIColor
        let outgoingFill: UIColor
        switch theme {
            case .dayClassic:
                background = UIColor(rgb: 0xd6e2ee)
                incomingFill = UIColor(rgb: 0xffffff)
                outgoingFill = UIColor(rgb: 0xe1ffc7)
            case .day:
                background = .white
                incomingFill = UIColor(rgb: 0xd5dde6)
                outgoingFill = accentColor ?? UIColor(rgb: 0x007aff)
            case .night:
                background = UIColor(rgb: 0x000000)
                incomingFill = UIColor(rgb: 0x1f1f1f)
                outgoingFill = accentColor ?? UIColor(rgb: 0x313131)
            case .nightAccent:
                let accentColor = accentColor ?? UIColor(rgb: 0x007aff)
                background = accentColor.withMultiplied(hue: 1.024, saturation: 0.573, brightness: 0.18)
                incomingFill = accentColor.withMultiplied(hue: 1.024, saturation: 0.585, brightness: 0.25)
                outgoingFill = accentColor.withMultiplied(hue: 1.019, saturation: 0.731, brightness: 0.59)
        }
            
        context.setFillColor(background.cgColor)
        context.fill(bounds)
        
        let incoming = generateTintedImage(image: UIImage(bundleImageName: "Settings/ThemeBubble"), color: incomingFill)
        let outgoing = generateTintedImage(image: UIImage(bundleImageName: "Settings/ThemeBubble"), color: outgoingFill)
        
        context.translateBy(x: bounds.width / 2.0, y: bounds.height / 2.0)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: -bounds.width / 2.0, y: -bounds.height / 2.0)
        
        context.draw(incoming!.cgImage!, in: CGRect(x: 9.0, y: 34.0, width: 57.0, height: 16.0))
        
        context.translateBy(x: bounds.width / 2.0, y: bounds.height / 2.0)
        context.scaleBy(x: -1.0, y: 1.0)
        context.translateBy(x: -bounds.width / 2.0, y: -bounds.height / 2.0)
        context.draw(outgoing!.cgImage!, in: CGRect(x: 9.0, y: 12.0, width: 57.0, height: 16.0))
    })!
}

class ThemeSettingsThemeItem: ListViewItem, ItemListItem {
    var sectionId: ItemListSectionId
    
    let theme: PresentationTheme
    let strings: PresentationStrings
    let themes: [PresentationThemeReference]
    let themeSpecificAccentColors: [Int64: PresentationThemeAccentColor]
    let currentTheme: PresentationThemeReference
    let updatedTheme: (PresentationThemeReference) -> Void
    let currentColor: PresentationThemeAccentColor?
    let updatedColor: (PresentationThemeAccentColor) -> Void
    let displayColorSlider: Bool
    let tag: ItemListItemTag?
    
    init(theme: PresentationTheme, strings: PresentationStrings, sectionId: ItemListSectionId, themes: [PresentationThemeReference], themeSpecificAccentColors: [Int64: PresentationThemeAccentColor], currentTheme: PresentationThemeReference, updatedTheme: @escaping (PresentationThemeReference) -> Void, currentColor: PresentationThemeAccentColor?, updatedColor: @escaping (PresentationThemeAccentColor) -> Void, displayColorSlider: Bool, tag: ItemListItemTag? = nil) {
        self.theme = theme
        self.strings = strings
        self.themes = themes
        self.themeSpecificAccentColors = themeSpecificAccentColors
        self.currentTheme = currentTheme
        self.updatedTheme = updatedTheme
        self.currentColor = currentColor
        self.updatedColor = updatedColor
        self.displayColorSlider = displayColorSlider
        self.tag = tag
        self.sectionId = sectionId
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = ThemeSettingsThemeItemNode()
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
            if let nodeValue = node() as? ThemeSettingsThemeItemNode {
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

private final class ThemeSettingsThemeItemIconNode : ASDisplayNode {
    private let iconNode: ASImageNode
    private let overlayNode: ASImageNode
    private let textNode: ASTextNode
    private var action: (() -> Void)?
    
    override init() {
        self.iconNode = ASImageNode()
        self.iconNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 98.0, height: 62.0))
        self.iconNode.isLayerBacked = true
        
        self.overlayNode = ASImageNode()
        self.overlayNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 98.0, height: 62.0))
        self.overlayNode.isLayerBacked = true
        
        self.textNode = ASTextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = true
        
        super.init()
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.overlayNode)
        self.addSubnode(self.textNode)
    }
    
    func setup(theme: PresentationTheme, icon: UIImage, title: NSAttributedString, bordered: Bool, selected: Bool, action: @escaping () -> Void) {
        self.iconNode.image = icon
        self.textNode.attributedText = title
        self.overlayNode.image = generateBorderImage(theme: theme, bordered: bordered, selected: selected)
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
        
        let bounds = self.bounds
        
        self.iconNode.frame = CGRect(origin: CGPoint(x: 10.0, y: 14.0), size: CGSize(width: 98.0, height: 62.0))
        self.overlayNode.frame = CGRect(origin: CGPoint(x: 10.0, y: 14.0), size: CGSize(width: 98.0, height: 62.0))
        self.textNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 14.0 + 60.0 + 4.0 + 9.0), size: CGSize(width: bounds.size.width, height: 16.0))
    }
}


private let textFont = Font.regular(12.0)
private let selectedTextFont = Font.bold(12.0)

class ThemeSettingsThemeItemNode: ListViewItemNode, ItemListItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    
    private let scrollNode: ASScrollNode
    private var nodes: [ThemeSettingsThemeItemIconNode] = []
    
    private let colorSlider: ThemeSettingsColorSliderNode
    
    private var item: ThemeSettingsThemeItem?
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
        
        self.colorSlider = ThemeSettingsColorSliderNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.scrollNode)
        self.addSubnode(self.colorSlider)
    }
    
    override func didLoad() {
        super.didLoad()
        self.scrollNode.view.disablesInteractiveTransitionGestureRecognizer = true
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        
        self.colorSlider.view.disablesInteractiveTransitionGestureRecognizer = true
        
        self.colorSlider.valueChanged = { [weak self] value in
            if let strongSelf = self, let item = strongSelf.item, let currentColor = item.currentColor {
                item.updatedColor(PresentationThemeAccentColor(baseColor: currentColor.baseColor, value: value))
            }
        }
    }
    
    private func scrollToNode(_ node: ThemeSettingsThemeItemIconNode, animated: Bool) {
        let bounds = self.scrollNode.view.bounds
        let frame = node.frame.insetBy(dx: -48.0, dy: 0.0)
        
        if frame.minX < bounds.minX || frame.maxX > bounds.maxX {
            self.scrollNode.view.scrollRectToVisible(frame, animated: animated)
        }
    }
    
    func asyncLayout() -> (_ item: ThemeSettingsThemeItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let currentItem = self.item
        
        return { item, params, neighbors in
            let contentSize: CGSize
            let insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            contentSize = CGSize(width: params.width, height: 116.0)
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
                    
                    strongSelf.scrollNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 2.0), size: CGSize(width: layoutSize.width, height: layoutSize.height))
                    strongSelf.colorSlider.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layoutSize.width, height: layoutSize.height))
                    strongSelf.colorSlider.updateLayout(size: strongSelf.colorSlider.frame.size, transition: .immediate)
                    
                    let nodeInset: CGFloat = 4.0
                    let nodeSize = CGSize(width: 116.0, height: 112.0)
                    var nodeOffset = nodeInset
                    
                    var updated = false
                    var selectedNode: ThemeSettingsThemeItemIconNode?
                    
                    var i = 0
                    for theme in item.themes {
                        let imageNode: ThemeSettingsThemeItemIconNode
                        if strongSelf.nodes.count > i {
                            imageNode = strongSelf.nodes[i]
                        } else {
                            imageNode = ThemeSettingsThemeItemIconNode()
                            strongSelf.nodes.append(imageNode)
                            strongSelf.scrollNode.addSubnode(imageNode)
                            updated = true
                        }

                        let selected = theme == item.currentTheme
                        if selected {
                            selectedNode = imageNode
                        }
                        
                        let name: String?
                        if case let .builtin(theme) = theme {
                            switch theme {
                                case .dayClassic:
                                    name = item.strings.Appearance_ThemeCarouselClassic
                                case .day:
                                    name = item.strings.Appearance_ThemeCarouselDay
                                case .night:
                                    name = item.strings.Appearance_ThemeCarouselNewNight
                                case .nightAccent:
                                    name = item.strings.Appearance_ThemeCarouselTintedNight
                            }
                        } else {
                            name = nil
                        }
                        
                        if let name = name {
                            imageNode.setup(theme: item.theme, icon: generateThemeIconImage(theme: theme, accentColor: item.themeSpecificAccentColors[theme.index]?.color), title: NSAttributedString(string: name, font: selected ?  selectedTextFont : textFont, textColor: selected ? item.theme.list.itemAccentColor : item.theme.list.itemPrimaryTextColor, paragraphAlignment: .center), bordered: true, selected: selected, action: { [weak self, weak imageNode] in
                                item.updatedTheme(theme)
                                if let imageNode = imageNode {
                                    self?.scrollToNode(imageNode, animated: true)
                                }
                            })
                            
                            imageNode.frame = CGRect(origin: CGPoint(x: nodeOffset, y: 0.0), size: nodeSize)
                            nodeOffset += nodeSize.width + 2.0
                        }
                        
                        i += 1
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
                    
                    let transition: ContainedViewLayoutTransition
                    if currentItem == nil {
                        transition = .immediate
                    } else {
                        transition = .animated(duration: 0.3, curve: .easeInOut)
                    }
                    
                    let previousBaseColor = strongSelf.colorSlider.baseColor
                    let newBaseColor = item.currentColor?.baseColor ?? .blue
                    if newBaseColor != .black && newBaseColor != .white {
                        strongSelf.colorSlider.baseColor = newBaseColor
                    }
                    if previousBaseColor != newBaseColor {
                        strongSelf.colorSlider.value = item.currentColor?.value ?? 0.5
                    }
                    
                    strongSelf.scrollNode.allowsGroupOpacity = true
                    transition.updateAlpha(node: strongSelf.scrollNode, alpha: item.displayColorSlider ? 0.0 : 1.0, completion: { [weak self] finished in
                        if let strongSelf = self, finished {
                            strongSelf.scrollNode.allowsGroupOpacity = false
                        }
                    })
                    transition.updateAlpha(node: strongSelf.colorSlider, alpha: item.displayColorSlider ? 1.0 : 0.0)
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

