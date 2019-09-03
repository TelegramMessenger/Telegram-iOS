import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import WallpaperResources
import AccountContext

private var borderImages: [String: UIImage] = [:]

private func generateBorderImage(theme: PresentationTheme, bordered: Bool, selected: Bool) -> UIImage? {
    let key = "\(theme.list.itemBlocksBackgroundColor.hexString)_\(selected ? "s" + theme.list.itemAccentColor.hexString : theme.list.disclosureArrowColor.hexString)"
    if let image = borderImages[key] {
        return image
    } else {
        let image = generateImage(CGSize(width: 32.0, height: 32.0), rotatedContext: { size, context in
            let bounds = CGRect(origin: CGPoint(), size: size)
            context.setFillColor(theme.list.itemBlocksBackgroundColor.cgColor)
            context.fill(bounds)
            
            context.setBlendMode(.clear)
            context.fillEllipse(in: bounds.insetBy(dx: 1.0, dy: 1.0))
            context.setBlendMode(.normal)
            
            let lineWidth: CGFloat
            if selected {
                var accentColor = theme.list.itemAccentColor
                if accentColor.rgb == 0xffffff {
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
                context.strokeEllipse(in: bounds.insetBy(dx: 1.0 + lineWidth / 2.0, dy: 1.0 + lineWidth / 2.0))
            }
        })?.stretchableImage(withLeftCapWidth: 16, topCapHeight: 16)
        borderImages[key] = image
        return image
    }
}

private func createThemeImage(theme: PresentationTheme) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    return .single(theme)
    |> map { theme -> (TransformImageArguments) -> DrawingContext? in
        return { arguments in
            let context = DrawingContext(size: arguments.drawingSize, scale: arguments.scale ?? 0.0, clear: false)
            let drawingRect = arguments.drawingRect
            
            context.withContext { c in
                c.setFillColor(theme.list.itemBlocksBackgroundColor.cgColor)
                c.fill(drawingRect)
                
                c.translateBy(x: drawingRect.width / 2.0, y: drawingRect.height / 2.0)
                c.scaleBy(x: 1.0, y: -1.0)
                c.translateBy(x: -drawingRect.width / 2.0, y: -drawingRect.height / 2.0)
                
                if let icon = generateTintedImage(image: UIImage(bundleImageName: "Settings/CreateThemeIcon"), color: theme.list.itemAccentColor) {
                    c.draw(icon.cgImage!, in: CGRect(origin: CGPoint(x: floor((drawingRect.width - icon.size.width) / 2.0) - 3.0, y: floor((drawingRect.height - icon.size.height) / 2.0)), size: icon.size))
                }
            }
            
            return context
        }
    }
}


class ThemeSettingsThemeItem: ListViewItem, ItemListItem {
    var sectionId: ItemListSectionId
    
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let themes: [PresentationThemeReference]
    let themeSpecificAccentColors: [Int64: PresentationThemeAccentColor]
    let currentTheme: PresentationThemeReference
    let updatedTheme: (PresentationThemeReference) -> Void
    let longTapped: (PresentationThemeReference) -> Void
    let tag: ItemListItemTag?
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, sectionId: ItemListSectionId, themes: [PresentationThemeReference], themeSpecificAccentColors: [Int64: PresentationThemeAccentColor], currentTheme: PresentationThemeReference, updatedTheme: @escaping (PresentationThemeReference) -> Void, longTapped: @escaping (PresentationThemeReference) -> Void, tag: ItemListItemTag? = nil) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.themes = themes
        self.themeSpecificAccentColors = themeSpecificAccentColors
        self.currentTheme = currentTheme
        self.updatedTheme = updatedTheme
        self.longTapped = longTapped
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
    private let imageNode: TransformImageNode
    private let overlayNode: ASImageNode
    private let textNode: ASTextNode
    private var action: (() -> Void)?
    private var longTapAction: (() -> Void)?
    
    private var theme: PresentationThemeReference?
    private var currentTheme: PresentationTheme?
    private var accentColor: UIColor?
    private var bordered: Bool?
    private var selected: Bool?
    
    override init() {
        self.imageNode = TransformImageNode()
        self.imageNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 98.0, height: 62.0))
        self.imageNode.isLayerBacked = true
        
        self.overlayNode = ASImageNode()
        self.overlayNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 100.0, height: 64.0))
        self.overlayNode.isLayerBacked = true
        
        self.textNode = ASTextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = true
        
        super.init()
        
        self.addSubnode(self.imageNode)
        self.addSubnode(self.overlayNode)
        self.addSubnode(self.textNode)
    }
    
    func setup(context: AccountContext, theme: PresentationThemeReference, accentColor: UIColor?, currentTheme: PresentationTheme, title: NSAttributedString, bordered: Bool, selected: Bool, action: @escaping () -> Void, longTapAction: @escaping () -> Void) {
        let updatedTheme = self.currentTheme == nil || currentTheme !== self.currentTheme!
        if case let .cloud(theme) = theme, theme.theme.file == nil {
            if updatedTheme || accentColor != self.accentColor {
                self.imageNode.setSignal(createThemeImage(theme: currentTheme))
                self.currentTheme = currentTheme
                self.accentColor = accentColor
            }
        } else {
            if theme != self.theme || accentColor != self.accentColor {
                self.imageNode.setSignal(themeIconImage(account: context.account, accountManager: context.sharedContext.accountManager, theme: theme, accentColor: accentColor))
                self.theme = theme
                self.accentColor = accentColor
            }
        }
        if updatedTheme || bordered != self.bordered || selected != self.selected {
            self.overlayNode.image = generateBorderImage(theme: currentTheme, bordered: bordered, selected: selected)
            self.currentTheme = currentTheme
            self.bordered = bordered
            self.selected = selected
        }
        self.textNode.attributedText = title
        self.action = {
            action()
        }
        self.longTapAction = {
            longTapAction()
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.delaysTouchesBegan = false
        recognizer.tapActionAtPoint = { point in
            return .waitForSingleTap
        }
        self.view.addGestureRecognizer(recognizer)
    }
    
    @objc private func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
            case .ended:
                if let (gesture, _) = recognizer.lastRecognizedGestureAndLocation {
                    switch gesture {
                        case .tap:
                            self.action?()
                        case .longTap:
                            self.longTapAction?()
                        default:
                            break
                    }
                }
            default:
                break
        }
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        
        let imageSize = CGSize(width: 98.0, height: 62.0)
        self.imageNode.frame = CGRect(origin: CGPoint(x: 10.0, y: 14.0), size: imageSize)
        let makeLayout = self.imageNode.asyncLayout()
        let applyLayout = makeLayout(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), emptyColor: .clear))
        applyLayout()
        
        self.overlayNode.frame = CGRect(origin: CGPoint(x: 9.0, y: 13.0), size: CGSize(width: 100.0, height: 64.0))
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
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.scrollNode)
    }
    
    override func didLoad() {
        super.didLoad()
        self.scrollNode.view.disablesInteractiveTransitionGestureRecognizer = true
        self.scrollNode.view.showsHorizontalScrollIndicator = false
    }
    
    private func scrollToNode(_ node: ThemeSettingsThemeItemIconNode, animated: Bool) {
        let bounds = self.scrollNode.view.bounds
        let frame = node.frame.insetBy(dx: -48.0, dy: 0.0)
        
        if frame.minX < bounds.minX || frame.maxX > bounds.maxX {
            self.scrollNode.view.scrollRectToVisible(frame, animated: animated)
        }
    }
    
    func asyncLayout() -> (_ item: ThemeSettingsThemeItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
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
                    
                    strongSelf.scrollNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 2.0), size: CGSize(width: layoutSize.width, height: layoutSize.height))
                    
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

                        let selected = theme.index == item.currentTheme.index
                        if selected {
                            selectedNode = imageNode
                        }
                        
                        let name = themeDisplayName(strings: item.strings, reference: theme)
                        imageNode.setup(context: item.context, theme: theme, accentColor: item.themeSpecificAccentColors[theme.index]?.color, currentTheme: item.theme, title: NSAttributedString(string: name, font: selected ? selectedTextFont : textFont, textColor: selected ? item.theme.list.itemAccentColor : item.theme.list.itemPrimaryTextColor, paragraphAlignment: .center), bordered: true, selected: selected, action: { [weak self, weak imageNode] in
                            item.updatedTheme(theme)
                            if let imageNode = imageNode {
                                self?.scrollToNode(imageNode, animated: true)
                            }
                        }, longTapAction: {
                            item.longTapped(theme)
                        })
                        
                        imageNode.frame = CGRect(origin: CGPoint(x: nodeOffset, y: 0.0), size: nodeSize)
                        nodeOffset += nodeSize.width + 2.0
                        
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
