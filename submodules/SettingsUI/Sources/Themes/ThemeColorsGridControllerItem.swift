import Foundation
import UIKit
import Display
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import Postbox
import AccountContext
import GridMessageSelectionNode

final class ThemeColorsGridControllerItem: GridItem {
    let context: AccountContext
    let wallpaper: TelegramWallpaper
    let selected: Bool
    let interaction: ThemeColorsGridControllerInteraction
    
    let section: GridSection? = nil
    
    init(context: AccountContext, wallpaper: TelegramWallpaper, selected: Bool, interaction: ThemeColorsGridControllerInteraction) {
        self.context = context
        self.wallpaper = wallpaper
        self.selected = selected
        self.interaction = interaction
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = ThemeColorsGridControllerItemNode()
        node.setup(context: self.context, wallpaper: self.wallpaper, selected: self.selected, interaction: self.interaction)
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? ThemeColorsGridControllerItemNode else {
            assertionFailure()
            return
        }
        node.setup(context: self.context, wallpaper: self.wallpaper, selected: self.selected, interaction: self.interaction)
    }
}

final class ThemeColorsGridControllerItemNode: GridItemNode {
    private let wallpaperNode: SettingsThemeWallpaperNode
    private var selectionNode: GridMessageSelectionNode?
    
    private var currentState: (AccountContext, TelegramWallpaper, Bool)?
    private var interaction: ThemeColorsGridControllerInteraction?
    
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
    
    func setup(context: AccountContext, wallpaper: TelegramWallpaper, selected: Bool, interaction: ThemeColorsGridControllerInteraction) {
        self.interaction = interaction
        
        if self.currentState == nil || self.currentState!.0 !== context || wallpaper != self.currentState!.1 || selected != self.currentState!.2 {
            self.currentState = (context, wallpaper, selected)
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
        if let (context, wallpaper, selected) = self.currentState {
            self.wallpaperNode.setWallpaper(context: context, wallpaper: wallpaper, selected: selected, size: bounds.size)
            self.selectionNode?.frame = CGRect(origin: CGPoint(), size: bounds.size)
        }
    }
}
