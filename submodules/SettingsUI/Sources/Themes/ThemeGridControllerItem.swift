import Foundation
import UIKit
import Display
import TelegramCore
import SyncCore
import SwiftSignalKit
import AsyncDisplayKit
import Postbox
import AccountContext
import GridMessageSelectionNode

final class ThemeGridControllerItem: GridItem {
    let context: AccountContext
    let wallpaper: TelegramWallpaper
    let index: Int
    let editable: Bool
    let selected: Bool
    let interaction: ThemeGridControllerInteraction
    
    let section: GridSection? = nil
    
    init(context: AccountContext, wallpaper: TelegramWallpaper, index: Int, editable: Bool, selected: Bool, interaction: ThemeGridControllerInteraction) {
        self.context = context
        self.wallpaper = wallpaper
        self.index = index
        self.editable = editable
        self.selected = selected
        self.interaction = interaction
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = ThemeGridControllerItemNode()
        node.setup(context: self.context, wallpaper: self.wallpaper, editable: self.editable, selected: self.selected, interaction: self.interaction, synchronousLoad: synchronousLoad)
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? ThemeGridControllerItemNode else {
            assertionFailure()
            return
        }
        node.setup(context: self.context, wallpaper: self.wallpaper, editable: self.editable, selected: self.selected, interaction: self.interaction, synchronousLoad: false)
    }
}

final class ThemeGridControllerItemNode: GridItemNode {
    private let wallpaperNode: SettingsThemeWallpaperNode
    private var selectionNode: GridMessageSelectionNode?
    
    private var currentState: (AccountContext, TelegramWallpaper, Bool, Bool, Bool)?
    private var interaction: ThemeGridControllerInteraction?
    
    override init() {
        self.wallpaperNode = SettingsThemeWallpaperNode()
        super.init()
        
        self.addSubnode(self.wallpaperNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.isExclusiveTouch = true
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    func setup(context: AccountContext, wallpaper: TelegramWallpaper, editable: Bool, selected: Bool, interaction: ThemeGridControllerInteraction, synchronousLoad: Bool) {
        self.interaction = interaction
        
        if self.currentState == nil || self.currentState!.0 !== context || wallpaper != self.currentState!.1 || selected != self.currentState!.2 || synchronousLoad != self.currentState!.3 || editable != self.currentState!.4 {
            self.currentState = (context, wallpaper, selected, synchronousLoad, editable)
            self.updateSelectionState(animated: false)
            self.setNeedsLayout()
        }
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let (_, wallpaper, _, _, _) = self.currentState {
                self.interaction?.openWallpaper(wallpaper)
            }
        }
    }
    
    func updateSelectionState(animated: Bool) {
        if let (context, wallpaper, _, _, editable) = self.currentState {
            var editing = false
            var id: Int64?
            if case let .file(file) = wallpaper {
                id = file.id
            } else if case .image = wallpaper {
                id = 0
            }
            var selectedIndices = Set<Int64>()
            if let interaction = self.interaction {
                let (active, indices) = interaction.selectionState
                editing = active
                selectedIndices = indices
            }
            if let id = id, editing && editable {
                let selected = selectedIndices.contains(id)
                
                if let selectionNode = self.selectionNode {
                    selectionNode.updateSelected(selected, animated: animated)
                    selectionNode.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
                } else {
                    let theme = context.sharedContext.currentPresentationData.with { $0 }.theme
                    let selectionNode = GridMessageSelectionNode(theme: theme, toggle: { [weak self] value in
                        if let strongSelf = self {
                            strongSelf.interaction?.toggleWallpaperSelection(id, value)
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
        if let (context, wallpaper, selected, synchronousLoad, _) = self.currentState {
            self.wallpaperNode.setWallpaper(context: context, wallpaper: wallpaper, selected: selected, size: bounds.size, synchronousLoad: synchronousLoad)
            self.selectionNode?.frame = CGRect(origin: CGPoint(), size: bounds.size)
        }
    }
}
