import Foundation
import UIKit
import Display
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import Postbox
import AccountContext
import GridMessageSelectionNode
import SettingsThemeWallpaperNode
import TelegramPresentationData

private var cachedBorderImages: [String: UIImage] = [:]
private func generateBorderImage(theme: PresentationTheme, bordered: Bool, selected: Bool) -> UIImage? {
    let key = "\(theme.list.itemBlocksBackgroundColor.hexString)_\(selected ? "s" + theme.list.itemAccentColor.hexString : theme.list.disclosureArrowColor.hexString)"
    if let image = cachedBorderImages[key] {
        return image
    } else {
        let image = generateImage(CGSize(width: 20.0, height: 20.0), rotatedContext: { size, context in
            let bounds = CGRect(origin: CGPoint(), size: size)
            context.clear(bounds)

            let lineWidth: CGFloat
            if selected {
                lineWidth = 2.0
                context.setLineWidth(lineWidth)
                context.setStrokeColor(theme.list.itemBlocksBackgroundColor.cgColor)
                
                context.strokeEllipse(in: bounds.insetBy(dx: 2.0 + lineWidth / 2.0, dy: 2.0 + lineWidth / 2.0))
                
                var accentColor = theme.list.itemAccentColor
                if accentColor.rgb == 0xffffff {
                    accentColor = UIColor(rgb: 0x999999)
                }
                context.setStrokeColor(accentColor.cgColor)
            } else {
                context.setStrokeColor(theme.list.disclosureArrowColor.withAlphaComponent(0.4).cgColor)
                lineWidth = 1.0
            }

            if bordered || selected {
                context.setLineWidth(lineWidth)
                context.strokeEllipse(in: bounds.insetBy(dx: lineWidth / 2.0, dy: lineWidth / 2.0))
            }
        })?.stretchableImage(withLeftCapWidth: 10, topCapHeight: 10)
        cachedBorderImages[key] = image
        return image
    }
}

final class ThemeGridControllerItem: GridItem {
    let context: AccountContext
    let theme: PresentationTheme?
    let wallpaper: TelegramWallpaper
    let wallpaperId: ThemeGridControllerEntry.StableId
    let isEmpty: Bool
    let emojiFile: TelegramMediaFile?
    let channelMode: Bool
    let index: Int
    let editable: Bool
    let selected: Bool
    let interaction: ThemeGridControllerInteraction
    
    let section: GridSection? = nil
    
    init(context: AccountContext, theme: PresentationTheme? = nil, wallpaper: TelegramWallpaper, wallpaperId: ThemeGridControllerEntry.StableId, isEmpty: Bool = false, emojiFile: TelegramMediaFile? = nil, channelMode: Bool = false, index: Int, editable: Bool, selected: Bool, interaction: ThemeGridControllerInteraction) {
        self.context = context
        self.theme = theme
        self.wallpaper = wallpaper
        self.wallpaperId = wallpaperId
        self.isEmpty = isEmpty
        self.emojiFile = emojiFile
        self.channelMode = channelMode
        self.index = index
        self.editable = editable
        self.selected = selected
        self.interaction = interaction
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = ThemeGridControllerItemNode()
        node.setup(item: self, synchronousLoad: synchronousLoad)
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? ThemeGridControllerItemNode else {
            assertionFailure()
            return
        }
        node.setup(item: self, synchronousLoad: false)
    }
}

final class ThemeGridControllerItemNode: GridItemNode {
    private let wallpaperNode: SettingsThemeWallpaperNode
    private var selectionNode: GridMessageSelectionNode?
    private var selectionBorderNode: ASImageNode?
    
    private var textNode: ImmediateTextNode?
    
    private var item: ThemeGridControllerItem?
    
    override init() {
        self.wallpaperNode = SettingsThemeWallpaperNode(displayLoading: false)

        super.init()
        
        self.clipsToBounds = true
        
        self.addSubnode(self.wallpaperNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.layer.cornerRadius = 10.0
        
        self.view.isExclusiveTouch = true
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    func setup(item: ThemeGridControllerItem, synchronousLoad: Bool) {
        self.item = item
        self.updateSelectionState(animated: false)
        
        if item.channelMode, item.selected, let theme = item.theme {
            let selectionBorderNode: ASImageNode
            if let current = self.selectionBorderNode {
                selectionBorderNode = current
            } else {
                selectionBorderNode = ASImageNode()
                selectionBorderNode.displaysAsynchronously = false
                self.selectionBorderNode = selectionBorderNode
                
                self.addSubnode(selectionBorderNode)
            }
            
            selectionBorderNode.image = generateBorderImage(theme: theme, bordered: true, selected: true)
        } else {
            self.selectionBorderNode?.removeFromSupernode()
        }
        
        if item.channelMode, item.isEmpty, let theme = item.theme {
            let textNode: ImmediateTextNode
            if let current = self.textNode {
                textNode = current
            } else {
                textNode = ImmediateTextNode()
                textNode.maximumNumberOfLines = 2
                textNode.textAlignment = .center
                self.textNode = textNode
                
                self.addSubnode(textNode)
            }
            
            let strings = item.context.sharedContext.currentPresentationData.with { $0 }.strings
            textNode.attributedText = NSAttributedString(string: strings.Wallpaper_NoWallpaper, font: Font.regular(15.0), textColor: theme.list.itemSecondaryTextColor)
        }
        
        self.setNeedsLayout()
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let item = self.item, !item.isEmpty {
                item.interaction.openWallpaper(item.wallpaper)
            }
        }
    }
    
    func updateSelectionState(animated: Bool) {
        if let item = self.item {
            let (editing, selectedIds) = item.interaction.selectionState

            if editing && item.editable {
                let selected = selectedIds.contains(item.wallpaperId)
                
                if let selectionNode = self.selectionNode {
                    selectionNode.updateSelected(selected, animated: animated)
                    selectionNode.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
                } else {
                    let theme = item.context.sharedContext.currentPresentationData.with { $0 }.theme
                    let selectionNode = GridMessageSelectionNode(theme: theme, toggle: { [weak self] value in
                        if let strongSelf = self {
                            strongSelf.item?.interaction.toggleWallpaperSelection(item.wallpaperId, value)
                        }
                    })
                    
                    selectionNode.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
                    self.addSubnode(selectionNode)
                    self.selectionNode = selectionNode
                    selectionNode.updateSelected(selected, animated: false)
                    if animated {
                        selectionNode.animateIn()
                    }
                }
            }
            else {
                if let selectionNode = self.selectionNode {
                    self.selectionNode = nil
                    if animated {
                        selectionNode.animateOut { [weak selectionNode] in
                            selectionNode?.removeFromSupernode()
                        }
                    } else {
                        selectionNode.removeFromSupernode()
                    }
                }
            }
        }
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        if let item = self.item {
            self.wallpaperNode.setWallpaper(context: item.context, theme: item.theme, wallpaper: item.wallpaper, isEmpty: item.isEmpty, emojiFile: item.emojiFile, selected: !item.channelMode && item.selected, size: bounds.size, synchronousLoad: false)
            self.selectionNode?.frame = CGRect(origin: CGPoint(), size: bounds.size)
        }
        self.selectionBorderNode?.frame = CGRect(origin: CGPoint(), size: bounds.size)
        
        if let textNode = self.textNode {
            let textSize = textNode.updateLayout(bounds.size)
            textNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((bounds.width - textSize.width) / 2.0), y: floorToScreenPixels((bounds.height - textSize.height) / 2.0) - 18.0), size: textSize)
        }
    }
}
