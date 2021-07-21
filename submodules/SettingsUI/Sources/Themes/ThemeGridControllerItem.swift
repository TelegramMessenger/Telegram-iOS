import Foundation
import UIKit
import Display
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import Postbox
import AccountContext
import GridMessageSelectionNode

final class ThemeGridControllerItem: GridItem {
    let context: AccountContext
    let wallpaper: TelegramWallpaper
    let wallpaperId: ThemeGridControllerEntry.StableId
    let index: Int
    let editable: Bool
    let selected: Bool
    let interaction: ThemeGridControllerInteraction
    
    let section: GridSection? = nil
    
    init(context: AccountContext, wallpaper: TelegramWallpaper, wallpaperId: ThemeGridControllerEntry.StableId, index: Int, editable: Bool, selected: Bool, interaction: ThemeGridControllerInteraction) {
        self.context = context
        self.wallpaper = wallpaper
        self.wallpaperId = wallpaperId
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
    
    private var item: ThemeGridControllerItem?
    
    override init() {
        self.wallpaperNode = SettingsThemeWallpaperNode(displayLoading: false)

        super.init()
        
        self.addSubnode(self.wallpaperNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.isExclusiveTouch = true
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    func setup(item: ThemeGridControllerItem, synchronousLoad: Bool) {
        self.item = item
        self.updateSelectionState(animated: false)
        self.setNeedsLayout()
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let item = self.item {
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
            self.wallpaperNode.setWallpaper(context: item.context, wallpaper: item.wallpaper, selected: item.selected, size: bounds.size, synchronousLoad: false)
            self.selectionNode?.frame = CGRect(origin: CGPoint(), size: bounds.size)
        }
    }
}
