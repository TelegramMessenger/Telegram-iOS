import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import TelegramCore
import SyncCore
import TelegramPresentationData
import LegacyComponents
import AccountContext

private let itemSize = CGSize(width: 88.0, height: 88.0)
private let inset: CGFloat = 12.0

final class WallpaperPatternPanelNode: ASDisplayNode {
    private let context: AccountContext
    private var theme: PresentationTheme
    
    private let backgroundNode: ASDisplayNode
    private let topSeparatorNode: ASDisplayNode
    
    private let scrollNode: ASScrollNode
    
    private let titleNode: ImmediateTextNode
    private let labelNode: ImmediateTextNode
    private var sliderView: TGPhotoEditorSliderView?
    
    private var disposable: Disposable?
    var wallpapers: [TelegramWallpaper] = []
    private var currentWallpaper: TelegramWallpaper?
    
    var serviceBackgroundColor: UIColor = UIColor(rgb: 0x748698) {
        didSet {
            guard let nodes = self.scrollNode.subnodes else {
                return
            }
            for case let node as SettingsThemeWallpaperNode in nodes {
                node.setOverlayBackgroundColor(self.serviceBackgroundColor.withAlphaComponent(0.4))
            }
        }
    }
    
    var backgroundColors: (UIColor, UIColor?)? = nil {
        didSet {
            self.updateWallpapers()
        }
    }
    
    private var validLayout: CGSize?
    
    var patternChanged: ((TelegramWallpaper?, Int32?, Bool) -> Void)?

    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings) {
        self.context = context
        self.theme = theme
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = self.theme.chat.inputPanel.panelBackgroundColor
        
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.backgroundColor = self.theme.chat.inputPanel.panelSeparatorColor
     
        self.scrollNode = ASScrollNode()
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.attributedText = NSAttributedString(string: strings.WallpaperPreview_PatternTitle, font: Font.bold(17.0), textColor: theme.rootController.navigationBar.primaryTextColor)
    
        self.labelNode = ImmediateTextNode()
        self.labelNode.attributedText = NSAttributedString(string: strings.WallpaperPreview_PatternIntensity, font: Font.regular(14.0), textColor: theme.rootController.navigationBar.primaryTextColor)
        
        super.init()
        
        self.allowsGroupOpacity = true
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.scrollNode)
        
        self.addSubnode(self.titleNode)
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
                strongSelf.wallpapers = wallpapers
                strongSelf.updateWallpapers()
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
    
    func updateWallpapers() {
        guard let subnodes = self.scrollNode.subnodes else {
            return
        }
        
        for node in subnodes {
            node.removeFromSupernode()
        }
          
        let backgroundColors = self.backgroundColors ?? (UIColor(rgb: 0xd6e2ee), nil)
        
        var selected = true
        for wallpaper in wallpapers {
            let node = SettingsThemeWallpaperNode(overlayBackgroundColor: self.serviceBackgroundColor.withAlphaComponent(0.4))
            node.clipsToBounds = true
            node.cornerRadius = 5.0
            
            var updatedWallpaper = wallpaper
            if case let .file(file) = updatedWallpaper {
                let settings = WallpaperSettings(blur: false, motion: false, color: Int32(bitPattern: backgroundColors.0.rgb), bottomColor: backgroundColors.1.flatMap { Int32(bitPattern: $0.rgb) }, intensity: 100)
                updatedWallpaper = .file(id: file.id, accessHash: file.accessHash, isCreator: file.isCreator, isDefault: file.isDefault, isPattern: file.isPattern, isDark: file.isDark, slug: file.slug, file: file.file, settings: settings)
            }
            
            node.setWallpaper(context: self.context, wallpaper: updatedWallpaper, selected: selected, size: itemSize)
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
            self.scrollNode.addSubnode(node)
            
            selected = false
        }
        
        self.scrollNode.view.contentSize = CGSize(width: (itemSize.width + inset) * CGFloat(wallpapers.count) + inset, height: 112.0)
        self.layoutItemNodes(transition: .immediate)
    }
    
    func updateTheme(_ theme: PresentationTheme) {
        self.theme = theme
        
        self.backgroundNode.backgroundColor = self.theme.chat.inputPanel.panelBackgroundColor
        self.topSeparatorNode.backgroundColor = self.theme.chat.inputPanel.panelSeparatorColor
            
        self.sliderView?.backColor = self.theme.list.disclosureArrowColor
        self.sliderView?.trackColor = self.theme.list.itemAccentColor
        self.titleNode.attributedText = NSAttributedString(string: self.labelNode.attributedText?.string ?? "", font: Font.bold(17.0), textColor: self.theme.rootController.navigationBar.primaryTextColor)
        self.labelNode.attributedText = NSAttributedString(string: self.labelNode.attributedText?.string ?? "", font: Font.regular(14.0), textColor: self.theme.rootController.navigationBar.primaryTextColor)
        
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: .immediate)
        }
    }
    
    @objc func sliderValueChanged() {
        guard let sliderView = self.sliderView else {
            return
        }
        
        if let wallpaper = self.currentWallpaper {
            self.patternChanged?(wallpaper, Int32(sliderView.value), sliderView.isTracking)
        }
    }
    
    func didAppear(initialWallpaper: TelegramWallpaper? = nil) {
        var wallpaper = initialWallpaper ?? self.wallpapers.first
        
        if let wallpaper = wallpaper {
            var selectedFileId: Int64?
            if case let .file(file) = wallpaper {
                selectedFileId = file.id
            }
            
            self.currentWallpaper = wallpaper
            self.sliderView?.value = 40.0
            
            self.scrollNode.view.contentOffset = CGPoint()
            
            if let subnodes = self.scrollNode.subnodes {
                for case let subnode as SettingsThemeWallpaperNode in subnodes {
                    var selected = false
                    if case let .file(file) = subnode.wallpaper, file.id == selectedFileId {
                        selected = true
                    }
                    subnode.setSelected(selected, animated: false)
                }
            }
            
            if initialWallpaper == nil, let wallpaper = self.currentWallpaper, let sliderView = self.sliderView {
                self.patternChanged?(wallpaper, Int32(sliderView.value), false)
            }
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
        transition.updateFrame(node: self.topSeparatorNode, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: UIScreenPixel))
        
        let titleSize = self.titleNode.updateLayout(self.bounds.size)
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floor((self.bounds.width - titleSize.width) / 2.0), y: 19.0), size: titleSize))
        
        let scrollViewFrame = CGRect(x: 0.0, y: 52.0, width: size.width, height: 114.0)
        transition.updateFrame(node: self.scrollNode, frame: scrollViewFrame)
        
        let labelSize = self.labelNode.updateLayout(self.bounds.size)
        var combinedHeight = labelSize.height + 34.0
        
        var originY: CGFloat = scrollViewFrame.maxY + floor((size.height - scrollViewFrame.maxY - combinedHeight) / 2.0)
        transition.updateFrame(node: self.labelNode, frame: CGRect(origin: CGPoint(x: 14.0, y: originY), size: labelSize))
        
        self.sliderView?.frame = CGRect(origin: CGPoint(x: 15.0, y: originY + 8.0), size: CGSize(width: size.width - 15.0 * 2.0, height: 44.0))
        
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
