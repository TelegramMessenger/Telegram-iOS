import Foundation
import Display
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import Postbox

final class ThemeColorsGridControllerItem: GridItem {
    let account: Account
    let wallpaper: TelegramWallpaper
    let selected: Bool
    let interaction: ThemeColorsGridControllerInteraction
    
    let section: GridSection? = nil
    
    init(account: Account, wallpaper: TelegramWallpaper, selected: Bool, interaction: ThemeColorsGridControllerInteraction) {
        self.account = account
        self.wallpaper = wallpaper
        self.selected = selected
        self.interaction = interaction
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = ThemeColorsGridControllerItemNode()
        node.setup(account: self.account, wallpaper: self.wallpaper, selected: self.selected, interaction: self.interaction)
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? ThemeColorsGridControllerItemNode else {
            assertionFailure()
            return
        }
        node.setup(account: self.account, wallpaper: self.wallpaper, selected: self.selected, interaction: self.interaction)
    }
}

final class ThemeColorsGridControllerItemNode: GridItemNode {
    private let wallpaperNode: SettingsThemeWallpaperNode
    private var selectionNode: GridMessageSelectionNode?
    
    private var currentState: (Account, TelegramWallpaper, Bool)?
    private var interaction: ThemeColorsGridControllerInteraction?
    
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
    
    func setup(account: Account, wallpaper: TelegramWallpaper, selected: Bool, interaction: ThemeColorsGridControllerInteraction) {
        self.interaction = interaction
        
        if self.currentState == nil || self.currentState!.0 !== account || wallpaper != self.currentState!.1 || selected != self.currentState!.2 {
            self.currentState = (account, wallpaper, selected)
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
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        if let (account, wallpaper, selected) = self.currentState {
            self.wallpaperNode.setWallpaper(account: account, wallpaper: wallpaper, selected: selected, size: bounds.size)
            self.selectionNode?.frame = CGRect(origin: CGPoint(), size: bounds.size)
        }
    }
}
