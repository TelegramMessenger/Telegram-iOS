import Foundation
import Display
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import Postbox

final class ThemeGridControllerItem: GridItem {
    let account: Account
    let wallpaper: TelegramWallpaper
    let interaction: ThemeGridControllerInteraction
    
    let section: GridSection? = nil
    
    init(account: Account, wallpaper: TelegramWallpaper, interaction: ThemeGridControllerInteraction) {
        self.account = account
        self.wallpaper = wallpaper
        self.interaction = interaction
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = ThemeGridControllerItemNode()
        node.setup(account: self.account, wallpaper: self.wallpaper, interaction: self.interaction)
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? ThemeGridControllerItemNode else {
            assertionFailure()
            return
        }
        node.setup(account: self.account, wallpaper: self.wallpaper, interaction: self.interaction)
    }
}

private let avatarFont = Font.medium(18.0)
private let textFont = Font.regular(11.0)

final class ThemeGridControllerItemNode: GridItemNode {
    private let wallpaperNode: SettingsThemeWallpaperNode
    
    private var currentState: (Account, TelegramWallpaper)?
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
    
    func setup(account: Account, wallpaper: TelegramWallpaper, interaction: ThemeGridControllerInteraction) {
        self.interaction = interaction
        
        if self.currentState == nil || self.currentState!.0 !== account || wallpaper != self.currentState!.1 {
            self.currentState = (account, wallpaper)
            self.setNeedsLayout()
        }
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let (_, wallpaper) = self.currentState {
                self.interaction?.openWallpaper(wallpaper)
            }
        }
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        if let (account, wallpaper) = self.currentState {
            self.wallpaperNode.setWallpaper(account: account, wallpaper: wallpaper, size: bounds.size)
        }
    }
}
