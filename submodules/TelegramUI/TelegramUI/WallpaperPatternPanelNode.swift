import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import TelegramCore
import TelegramPresentationData
import LegacyComponents

private let itemSize = CGSize(width: 88.0, height: 88.0)
private let inset: CGFloat = 12.0

final class WallpaperPatternPanelNode: ASDisplayNode {
    private let theme: PresentationTheme
    
    private let backgroundNode: ASDisplayNode
    private let topSeparatorNode: ASDisplayNode
    
    private let scrollNode: ASScrollNode
    
    private let labelNode: ASTextNode
    private var sliderView: TGPhotoEditorSliderView?
    
    private var disposable: Disposable?
    private var wallpapers: [TelegramWallpaper] = []
    private var currentWallpaper: TelegramWallpaper?
    
    var patternChanged: ((TelegramWallpaper, Int32?, Bool) -> Void)?

    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = theme.chat.inputPanel.panelBackgroundColor
        
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.backgroundColor = theme.chat.inputPanel.panelSeparatorColor
     
        self.scrollNode = ASScrollNode()
        
        self.labelNode = ASTextNode()
        self.labelNode.attributedText = NSAttributedString(string: strings.WallpaperPreview_PatternIntensity, font: Font.regular(14.0), textColor: theme.rootController.navigationBar.primaryTextColor)
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.scrollNode)
        
        self.addSubnode(self.labelNode)
        
        self.disposable = ((telegramWallpapers(postbox: context.account.postbox, network: context.account.network)
        |> map { wallpapers in
            return wallpapers.filter { wallpaper in
                if case let .file(file) = wallpaper, file.isPattern, file.file.mimeType != "image/webp" {
                    return true
                } else {
                    return false
                }
            }
        }
        |> deliverOnMainQueue).start(next: { [weak self] wallpapers in
            if let strongSelf = self {
                if let subnodes = strongSelf.scrollNode.subnodes {
                    for node in subnodes {
                        node.removeFromSupernode()
                    }
                }
                
                var selected = true
                for wallpaper in wallpapers {
                    let node = SettingsThemeWallpaperNode(overlayBackgroundColor: UIColor(rgb: 0x748698, alpha: 0.4))
                    node.clipsToBounds = true
                    node.cornerRadius = 5.0
                    
                    var updatedWallpaper = wallpaper
                    if case let .file(file) = updatedWallpaper {
                        let settings = WallpaperSettings(blur: false, motion: false, color: 0xd6e2ee, intensity: 100)
                        updatedWallpaper = .file(id: file.id, accessHash: file.accessHash, isCreator: file.isCreator, isDefault: file.isDefault, isPattern: file.isPattern, isDark: file.isDark, slug: file.slug, file: file.file, settings: settings)
                    }
                    
                    node.setWallpaper(context: context, wallpaper: updatedWallpaper, selected: selected, size: itemSize)
                    node.pressed = { [weak self, weak node] in
                        if let strongSelf = self {
                            strongSelf.currentWallpaper = updatedWallpaper
                            if let sliderView = strongSelf.sliderView {
                                strongSelf.patternChanged?(updatedWallpaper, Int32(sliderView.value), false)
                            }
                            if let subnodes = strongSelf.scrollNode.subnodes {
                                for case let subnode as SettingsThemeWallpaperNode in subnodes {
                                    subnode.setSelected(node === subnode, animated: true)
                                }
                            }
                        }
                    }
                    strongSelf.scrollNode.addSubnode(node)
                    
                    selected = false
                }
                strongSelf.scrollNode.view.contentSize = CGSize(width: (itemSize.width + inset) * CGFloat(wallpapers.count) + inset, height: 112.0)
                strongSelf.layoutItemNodes(transition: .immediate)
                
                strongSelf.wallpapers = wallpapers
            }
        }))
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.showsVerticalScrollIndicator = false
        self.scrollNode.view.alwaysBounceHorizontal = true
        
        let sliderView = TGPhotoEditorSliderView()
        sliderView.trackCornerRadius = 1.0
        sliderView.lineSize = 2.0
        sliderView.minimumValue = 0.0
        sliderView.startValue = 0.0
        sliderView.maximumValue = 100.0
        sliderView.value = 40.0
        sliderView.disablesInteractiveTransitionGestureRecognizer = true
        sliderView.backgroundColor = .clear
        sliderView.backColor = self.theme.list.disclosureArrowColor
        sliderView.trackColor = self.theme.list.itemAccentColor
        
        self.view.addSubview(sliderView)
        sliderView.addTarget(self, action: #selector(self.sliderValueChanged), for: .valueChanged)
        self.sliderView = sliderView
    }
    
    @objc func sliderValueChanged() {
        guard let sliderView = self.sliderView else {
            return
        }
        
        if let wallpaper = self.currentWallpaper {
            self.patternChanged?(wallpaper, Int32(sliderView.value), sliderView.isTracking)
        }
    }
    
    func didAppear() {
        if let wallpaper = self.wallpapers.first {
            self.currentWallpaper = wallpaper
            self.sliderView?.value = 40.0
            
            self.scrollNode.view.contentOffset = CGPoint()
            
            var selected = true
            if let subnodes = self.scrollNode.subnodes {
                for case let subnode as SettingsThemeWallpaperNode in subnodes {
                    subnode.setSelected(selected, animated: false)
                    selected = false
                }
            }
            
            if let wallpaper = self.currentWallpaper, let sliderView = self.sliderView {
                self.patternChanged?(wallpaper, Int32(sliderView.value), false)
            }
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        let separatorHeight = UIScreenPixel
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
        transition.updateFrame(node: self.topSeparatorNode, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: separatorHeight))
        transition.updateFrame(node: self.scrollNode, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: 114.0))
        
        let labelSize = self.labelNode.measure(self.bounds.size)
        transition.updateFrame(node: labelNode, frame: CGRect(origin: CGPoint(x: 14.0, y: 128.0), size: labelSize))
        
        self.sliderView?.frame = CGRect(origin: CGPoint(x: 15.0, y: 136.0), size: CGSize(width: size.width - 15.0 * 2.0, height: 44.0))
        
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
