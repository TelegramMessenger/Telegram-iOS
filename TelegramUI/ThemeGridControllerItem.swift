import Foundation
import Display
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import Postbox

final class ThemeGridControllerItem: GridItem {
    let account: Account
    let wallpaper: TelegramWallpaper
    let index: Int
    let selected: Bool
    let interaction: ThemeGridControllerInteraction
    
    let section: GridSection? = nil
    
    init(account: Account, wallpaper: TelegramWallpaper, index: Int, selected: Bool, interaction: ThemeGridControllerInteraction) {
        self.account = account
        self.wallpaper = wallpaper
        self.index = index
        self.selected = selected
        self.interaction = interaction
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = ThemeGridControllerItemNode()
        node.setup(account: self.account, wallpaper: self.wallpaper, selected: self.selected, interaction: self.interaction)
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? ThemeGridControllerItemNode else {
            assertionFailure()
            return
        }
        node.setup(account: self.account, wallpaper: self.wallpaper, selected: self.selected, interaction: self.interaction)
    }
}

final class ThemeGridControllerItemNode: GridItemNode {
    private let wallpaperNode: SettingsThemeWallpaperNode
    private var selectionNode: GridMessageSelectionNode?
    
    private var currentState: (Account, TelegramWallpaper, Bool)?
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
    
    func setup(account: Account, wallpaper: TelegramWallpaper, selected: Bool, interaction: ThemeGridControllerInteraction) {
        self.interaction = interaction
        
        if self.currentState == nil || self.currentState!.0 !== account || wallpaper != self.currentState!.1 || selected != self.currentState!.2 {
            self.currentState = (account, wallpaper, selected)
            self.updateSelectionState(animated: false)
            self.setNeedsLayout()
        }
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let (_, wallpaper, _) = self.currentState {
                self.interaction?.openWallpaper(wallpaper)
            }
        }
    }
    
    func updateSelectionState(animated: Bool) {
        if let (account, wallpaper, _) = self.currentState {
            var editing = false
            var id: Int64?
            if case let .file(file) = wallpaper {
                id = file.id
            }
            var selectedIndices = Set<Int64>()
            if let interaction = self.interaction {
                let (active, indices) = interaction.selectionState
                editing = active
                selectedIndices = indices
            }
            if let id = id, editing {
                let selected = selectedIndices.contains(id)
                
                if let selectionNode = self.selectionNode {
                    selectionNode.updateSelected(selected, animated: animated)
                    selectionNode.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
                } else {
                    let theme = account.telegramApplicationContext.currentPresentationData.with { $0 }.theme
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
        if let (account, wallpaper, selected) = self.currentState {
            self.wallpaperNode.setWallpaper(account: account, wallpaper: wallpaper, selected: selected, size: bounds.size)
            self.selectionNode?.frame = CGRect(origin: CGPoint(), size: bounds.size)
        }
    }
}
