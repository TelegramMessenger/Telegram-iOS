import Foundation
import AsyncDisplayKit
import Display

final class ThemeGalleryToolbarNode: ASDisplayNode {
    private let cancelButton = HighlightableButtonNode()
    private let doneButton = HighlightableButtonNode()
    private let separatorNode = ASDisplayNode()
    private let topSeparatorNode = ASDisplayNode()
    
    var cancel: (() -> Void)?
    var done: (() -> Void)?
    
    init(theme: PresentationTheme, strings: PresentationStrings) {
        super.init()
        
        self.addSubnode(self.cancelButton)
        self.addSubnode(self.doneButton)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.topSeparatorNode)
        
        self.updateThemeAndStrings(theme: theme, strings: strings)
        
        self.cancelButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.cancelButton.backgroundColor = UIColor(rgb: 0xd4d4d4)
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
                    strongSelf.doneButton.backgroundColor = UIColor(rgb: 0xd4d4d4)
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
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
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
        self.done?()
    }
}
