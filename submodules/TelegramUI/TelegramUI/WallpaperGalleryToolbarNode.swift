import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

final class WallpaperGalleryToolbarNode: ASDisplayNode {
    private var theme: PresentationTheme
    
    private let cancelButton = HighlightableButtonNode()
    private let doneButton = HighlightableButtonNode()
    private let separatorNode = ASDisplayNode()
    private let topSeparatorNode = ASDisplayNode()
    
    var cancel: (() -> Void)?
    var done: (() -> Void)?
    
    init(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        
        super.init()
        
        self.addSubnode(self.cancelButton)
        self.addSubnode(self.doneButton)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.topSeparatorNode)
        
        self.updateThemeAndStrings(theme: theme, strings: strings)
        
        self.cancelButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.cancelButton.backgroundColor = strongSelf.theme.list.itemHighlightedBackgroundColor
                } else {
                    UIView.animate(withDuration: 0.3, animations: {
                        strongSelf.cancelButton.backgroundColor = .clear
                    })
                }
            }
        }
        
        self.doneButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.doneButton.backgroundColor = strongSelf.theme.list.itemHighlightedBackgroundColor
                } else {
                    UIView.animate(withDuration: 0.3, animations: {
                        strongSelf.doneButton.backgroundColor = .clear
                    })
                }
            }
        }
        
        self.cancelButton.addTarget(self, action: #selector(self.cancelPressed), forControlEvents: .touchUpInside)
        self.doneButton.addTarget(self, action: #selector(self.donePressed), forControlEvents: .touchUpInside)
    }
    
    func setDoneEnabled(_ enabled: Bool) {
        self.doneButton.alpha = enabled ? 1.0 : 0.4
        self.doneButton.isUserInteractionEnabled = enabled
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        self.backgroundColor = theme.rootController.tabBar.backgroundColor
        self.separatorNode.backgroundColor = theme.rootController.tabBar.separatorColor
        self.topSeparatorNode.backgroundColor = theme.rootController.tabBar.separatorColor
        
        self.cancelButton.setTitle(strings.Common_Cancel, with: Font.regular(17.0), with: theme.rootController.navigationBar.primaryTextColor, for: [])
        self.doneButton.setTitle(strings.Wallpaper_Set, with: Font.regular(17.0), with: theme.rootController.navigationBar.primaryTextColor, for: [])
    }
    
    func updateLayout(size: CGSize, layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.cancelButton.frame = CGRect(origin: CGPoint(), size: CGSize(width: floor(size.width / 2.0), height: size.height))
        self.doneButton.frame = CGRect(origin: CGPoint(x: floor(size.width / 2.0), y: 0.0), size: CGSize(width: size.width - floor(size.width / 2.0), height: size.height))
        self.separatorNode.frame = CGRect(origin: CGPoint(x: floor(size.width / 2.0), y: 0.0), size: CGSize(width: UIScreenPixel, height: size.height + layout.intrinsicInsets.bottom))
        self.topSeparatorNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: UIScreenPixel))
    }
    
    @objc func cancelPressed() {
        self.cancel?()
    }
    
    @objc func donePressed() {
        self.doneButton.isUserInteractionEnabled = false
        self.done?()
    }
}
