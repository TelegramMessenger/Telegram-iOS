import Foundation
import Display
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import Postbox

final class ThemeGridControllerItem: GridItem {
    let context: AccountContext
    let wallpaper: TelegramWallpaper
    let index: Int
    let selected: Bool
    let interaction: ThemeGridControllerInteraction
    
    let section: GridSection? = nil
    
    init(context: AccountContext, wallpaper: TelegramWallpaper, index: Int, selected: Bool, interaction: ThemeGridControllerInteraction) {
        self.context = context
        self.wallpaper = wallpaper
        self.index = index
        self.selected = selected
        self.interaction = interaction
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = ThemeGridControllerItemNode()
        node.setup(context: self.context, wallpaper: self.wallpaper, index: self.index, selected: self.selected, interaction: self.interaction)
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? ThemeGridControllerItemNode else {
            assertionFailure()
            return
        }
        node.setup(context: self.context, wallpaper: self.wallpaper, index: self.index, selected: self.selected, interaction: self.interaction)
    }
}

final class ThemeGridControllerItemNode: GridItemNode {
    private let wallpaperNode: SettingsThemeWallpaperNode
    private var selectionNode: GridMessageSelectionNode?
    
    private var currentState: (AccountContext, TelegramWallpaper, Int, Bool)?
    private var interaction: ThemeGridControllerInteraction?
    
    override init() {
        self.wallpaperNode = SettingsThemeWallpaperNode()
        super.init()
        
        self.addSubnode(self.wallpaperNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    func setup(context: AccountContext, wallpaper: TelegramWallpaper, index: Int, selected: Bool, interaction: ThemeGridControllerInteraction) {
        self.interaction = interaction
        
        if self.currentState == nil || self.currentState!.0 !== context || wallpaper != self.currentState!.1 || index != self.currentState!.2 || selected != self.currentState!.3 {
            self.currentState = (context, wallpaper, index, selected)
            self.setNeedsLayout()
        }
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let (_, wallpaper, _, _) = self.currentState {
                self.interaction?.openWallpaper(wallpaper)
            }
        }
    }
    
    func updateSelectionState(animated: Bool) {
        if let (context, wallpaper, index, _) = self.currentState {
            var editing = false
            var selectable = false
            if case .file = wallpaper {
                selectable = true
            }
            var selectedIndices = Set<Int>()
            if let interaction = self.interaction {
                let (active, indices) = interaction.selectionState
                editing = active
                selectedIndices = indices
            }
            if editing && selectable {
                let selected = selectedIndices.contains(index)
                
                if let selectionNode = self.selectionNode {
                    selectionNode.updateSelected(selected, animated: animated)
                    selectionNode.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
                } else {
                    let theme = context.currentPresentationData.with { $0 }.theme
                    let selectionNode = GridMessageSelectionNode(theme: theme, toggle: { [weak self] value in
                        if let strongSelf = self {
                            strongSelf.interaction?.toggleWallpaperSelection(index, value)
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
        if let (context, wallpaper, _, selected) = self.currentState {
            self.wallpaperNode.setWallpaper(context: context, wallpaper: wallpaper, selected: selected, size: bounds.size)
            self.selectionNode?.frame = CGRect(origin: CGPoint(), size: bounds.size)
        }
    }
}
