import Foundation
import AsyncDisplayKit
import SwiftSignalKit
import Display
import TelegramCore

private let itemSize = CGSize(width: 88.0, height: 88.0)
private let inset: CGFloat = 12.0

final class WallpaperPatternPanelNode: ASDisplayNode {
    private let theme: PresentationTheme
    
    private let backgroundNode: ASDisplayNode
    private let topSeparatorNode: ASDisplayNode
    
    private let scrollNode: ASScrollNode
    
    private var disposable: Disposable?
    
    var patternChanged: ((TelegramWallpaper) -> Void)?

    init(account: Account, theme: PresentationTheme) {
        self.theme = theme
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = theme.chat.inputPanel.panelBackgroundColor
        
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.backgroundColor = theme.chat.inputPanel.panelStrokeColor
     
        self.scrollNode = ASScrollNode()
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.scrollNode)
        
        self.disposable = ((telegramWallpapers(postbox: account.postbox, network: account.network)
        |> map { wallpapers in
            return wallpapers.filter { wallpaper in
                if case let .file(file) = wallpaper, file.isPattern {
                    return true
                } else {
                    return false
                }
            }
        } |> deliverOnMainQueue).start(next: { [weak self] wallpapers in
            if let strongSelf = self {
                if let subnodes = strongSelf.scrollNode.subnodes {
                    for node in subnodes {
                        node.removeFromSupernode()
                    }
                }
                
                var wallpapers = wallpapers
                wallpapers.insert(.color(0xd6e2ee), at: 0)
                
                for wallpaper in wallpapers {
                    let node = SettingsThemeWallpaperNode()
                    
                    var updatedWallpaper = wallpaper
                    var isColor = false
                    if case let .file(file) = updatedWallpaper {
                        let settings = WallpaperSettings(blur: false, motion: false, color: 0xd6e2ee, intensity: 100)
                        updatedWallpaper = .file(id: file.id, accessHash: file.accessHash, isCreator: file.isCreator, isDefault: file.isDefault, isPattern: file.isPattern, slug: file.slug, file: file.file, settings: settings)
                    } else {
                        isColor = true
                    }
                    
                    node.setWallpaper(account: account, wallpaper: updatedWallpaper, selected: isColor, size: itemSize, cornerRadius: 5.0)
                    node.pressed = { [weak self, weak node] in
                        if let strongSelf = self {
                            strongSelf.patternChanged?(updatedWallpaper)
                            if let subnodes = strongSelf.scrollNode.subnodes {
                                for case let subnode as SettingsThemeWallpaperNode in subnodes {
                                    subnode.setSelected(node === subnode)
                                }
                            }
                        }
                    }
                    strongSelf.scrollNode.addSubnode(node)
                }
                strongSelf.scrollNode.view.contentSize = CGSize(width: (itemSize.width + inset) * CGFloat(wallpapers.count) + inset, height: 114.0)
                strongSelf.layoutItemNodes(transition: .immediate)
            }
        }))
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.scrollNode.view.alwaysBounceHorizontal = true
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        let separatorHeight = UIScreenPixel
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
        transition.updateFrame(node: self.topSeparatorNode, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: separatorHeight))
        transition.updateFrame(node: self.scrollNode, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
    
        self.layoutItemNodes(transition: transition)
    }
    
    private func layoutItemNodes(transition: ContainedViewLayoutTransition) {
        var offset: CGFloat = 12.0
        if let subnodes = self.scrollNode.subnodes {
            for node in subnodes {
                transition.updateFrame(node: node, frame: CGRect(x: offset, y: 12.0, width: itemSize.width, height: itemSize.height))
                offset += inset + itemSize.width
            }
        }
    }
}
