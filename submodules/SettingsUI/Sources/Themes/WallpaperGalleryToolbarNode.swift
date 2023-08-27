import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

enum WallpaperGalleryToolbarCancelButtonType {
    case cancel
    case discard
}

enum WallpaperGalleryToolbarDoneButtonType {
    case set
    case setPeer
    case proceed
    case apply
    case none
}

protocol WallpaperGalleryToolbar: ASDisplayNode {
    var cancelButtonType: WallpaperGalleryToolbarCancelButtonType { get set }
    var doneButtonType: WallpaperGalleryToolbarDoneButtonType { get set }
    
    var cancel: (() -> Void)? { get set }
    var done: (() -> Void)? { get set }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings)
    
    func updateLayout(size: CGSize, layout: ContainerViewLayout, transition: ContainedViewLayoutTransition)
}

final class WallpaperGalleryToolbarNode: ASDisplayNode, WallpaperGalleryToolbar {
    private var theme: PresentationTheme
    private let strings: PresentationStrings
    
    var cancelButtonType: WallpaperGalleryToolbarCancelButtonType {
        didSet {
            self.updateThemeAndStrings(theme: self.theme, strings: self.strings)
        }
    }
    var doneButtonType: WallpaperGalleryToolbarDoneButtonType {
        didSet {
            self.updateThemeAndStrings(theme: self.theme, strings: self.strings)
        }
    }
    
    var dark: Bool {
        didSet {
            if self.dark != oldValue {
                self.doneButtonBackgroundNode.removeFromSupernode()
                if self.dark {
                    self.doneButtonBackgroundNode = WallpaperOptionBackgroundNode(enableSaturation: true)
                } else {
                    self.doneButtonBackgroundNode = WallpaperLightButtonBackgroundNode()
                }
                self.doneButtonBackgroundNode.cornerRadius = 14.0
                self.insertSubnode(self.doneButtonBackgroundNode, at: 0)
            }
        }
    }
    
    private let doneButton = HighlightTrackingButtonNode()
    private var doneButtonBackgroundNode: ASDisplayNode
    
    private let doneButtonTitleNode: ImmediateTextNode
    
    private let doneButtonSolidBackgroundNode: ASDisplayNode
    private let doneButtonSolidTitleNode: ImmediateTextNode
    
    var cancel: (() -> Void)?
    var done: (() -> Void)?
    
    init(theme: PresentationTheme, strings: PresentationStrings, cancelButtonType: WallpaperGalleryToolbarCancelButtonType = .cancel, doneButtonType: WallpaperGalleryToolbarDoneButtonType = .set) {
        self.theme = theme
        self.strings = strings
        self.cancelButtonType = cancelButtonType
        self.doneButtonType = doneButtonType
        self.dark = false
        
        self.doneButtonBackgroundNode = WallpaperLightButtonBackgroundNode()
        self.doneButtonBackgroundNode.cornerRadius = 14.0
        
        self.doneButtonTitleNode = ImmediateTextNode()
        self.doneButtonTitleNode.displaysAsynchronously = false
        self.doneButtonTitleNode.isUserInteractionEnabled = false
        
        self.doneButtonSolidBackgroundNode = ASDisplayNode()
        self.doneButtonSolidBackgroundNode.alpha = 0.0
        self.doneButtonSolidBackgroundNode.clipsToBounds = true
        self.doneButtonSolidBackgroundNode.layer.cornerRadius = 14.0
        if #available(iOS 13.0, *) {
            self.doneButtonSolidBackgroundNode.layer.cornerCurve = .continuous
        }
        self.doneButtonSolidBackgroundNode.isUserInteractionEnabled = false
        
        self.doneButtonSolidTitleNode = ImmediateTextNode()
        self.doneButtonSolidTitleNode.alpha = 0.0
        self.doneButtonSolidTitleNode.displaysAsynchronously = false
        self.doneButtonSolidTitleNode.isUserInteractionEnabled = false

        super.init()
        
        self.doneButton.isExclusiveTouch = true

        self.addSubnode(self.doneButtonBackgroundNode)
        self.addSubnode(self.doneButtonTitleNode)
        
        self.addSubnode(self.doneButtonSolidBackgroundNode)
        self.addSubnode(self.doneButtonSolidTitleNode)
        
        self.addSubnode(self.doneButton)
        
        self.updateThemeAndStrings(theme: theme, strings: strings)
        
        self.doneButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    if strongSelf.isSolid {
                        strongSelf.doneButtonSolidBackgroundNode.layer.removeAnimation(forKey: "opacity")
                        strongSelf.doneButtonSolidBackgroundNode.alpha = 0.55
                        strongSelf.doneButtonSolidTitleNode.layer.removeAnimation(forKey: "opacity")
                        strongSelf.doneButtonSolidTitleNode.alpha = 0.55
                    } else {
                        strongSelf.doneButtonBackgroundNode.layer.removeAnimation(forKey: "opacity")
                        strongSelf.doneButtonBackgroundNode.alpha = 0.55
                        strongSelf.doneButtonTitleNode.layer.removeAnimation(forKey: "opacity")
                        strongSelf.doneButtonTitleNode.alpha = 0.55
                    }
                } else {
                    if strongSelf.isSolid {
                        strongSelf.doneButtonSolidBackgroundNode.alpha = 1.0
                        strongSelf.doneButtonSolidBackgroundNode.layer.animateAlpha(from: 0.55, to: 1.0, duration: 0.2)
                        strongSelf.doneButtonSolidTitleNode.alpha = 1.0
                        strongSelf.doneButtonSolidTitleNode.layer.animateAlpha(from: 0.55, to: 1.0, duration: 0.2)
                    } else {
                        strongSelf.doneButtonBackgroundNode.alpha = 1.0
                        strongSelf.doneButtonBackgroundNode.layer.animateAlpha(from: 0.55, to: 1.0, duration: 0.2)
                        strongSelf.doneButtonTitleNode.alpha = 1.0
                        strongSelf.doneButtonTitleNode.layer.animateAlpha(from: 0.55, to: 1.0, duration: 0.2)
                    }
                }
            }
        }
        
        self.doneButton.addTarget(self, action: #selector(self.donePressed), forControlEvents: .touchUpInside)
    }
    
    func setDoneEnabled(_ enabled: Bool) {
        self.doneButton.alpha = enabled ? 1.0 : 0.4
        self.doneButton.isUserInteractionEnabled = enabled
    }
    
    private var isSolid = false
    func setDoneIsSolid(_ isSolid: Bool, transition: ContainedViewLayoutTransition) {
        guard self.isSolid != isSolid else {
            return
        }
        self.isSolid = isSolid
        
        transition.updateAlpha(node: self.doneButtonBackgroundNode, alpha: isSolid ? 0.0 : 1.0)
        transition.updateAlpha(node: self.doneButtonSolidBackgroundNode, alpha: isSolid ? 1.0 : 0.0)
        transition.updateAlpha(node: self.doneButtonTitleNode, alpha: isSolid ? 0.0 : 1.0)
        transition.updateAlpha(node: self.doneButtonSolidTitleNode, alpha: isSolid ? 1.0 : 0.0)
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
                
        let doneTitle: String
        switch self.doneButtonType {
            case .set:
                doneTitle = strings.Wallpaper_ApplyForAll
            case .setPeer:
                doneTitle = strings.Wallpaper_ApplyForChat
            case .proceed:
                doneTitle = strings.Theme_Colors_Proceed
            case .apply:
                doneTitle = strings.WallpaperPreview_PatternPaternApply
            case .none:
                doneTitle = ""
                self.doneButton.isUserInteractionEnabled = false
        }
        self.doneButtonTitleNode.attributedText = NSAttributedString(string: doneTitle, font: Font.semibold(17.0), textColor: .white)
        
        self.doneButtonSolidBackgroundNode.backgroundColor = theme.list.itemCheckColors.fillColor
        self.doneButtonSolidTitleNode.attributedText = NSAttributedString(string: doneTitle, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor)
    }
    
    func updateLayout(size: CGSize, layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        let inset: CGFloat = 16.0
        let buttonHeight: CGFloat = 50.0
        
        let doneFrame = CGRect(origin: CGPoint(x: inset, y: 2.0), size: CGSize(width: size.width - inset * 2.0, height: buttonHeight))
        self.doneButton.frame = doneFrame
        self.doneButtonBackgroundNode.frame = doneFrame
        if let backgroundNode = self.doneButtonBackgroundNode as? WallpaperOptionBackgroundNode {
            backgroundNode.updateLayout(size: doneFrame.size)
        } else if let backgroundNode = self.doneButtonBackgroundNode as? WallpaperLightButtonBackgroundNode {
            backgroundNode.updateLayout(size: doneFrame.size)
        }
        self.doneButtonSolidBackgroundNode.frame = doneFrame
        
        let doneTitleSize = self.doneButtonTitleNode.updateLayout(doneFrame.size)
        self.doneButtonTitleNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((doneFrame.width - doneTitleSize.width) / 2.0), y: floorToScreenPixels((doneFrame.height - doneTitleSize.height) / 2.0)), size: doneTitleSize).offsetBy(dx: doneFrame.minX, dy: doneFrame.minY)
        
        let _ = self.doneButtonSolidTitleNode.updateLayout(doneFrame.size)
        self.doneButtonSolidTitleNode.frame = self.doneButtonTitleNode.frame
    }
    
    @objc func cancelPressed() {
        self.cancel?()
    }
    
    @objc func donePressed() {
        self.done?()
    }
}

final class WallpaperGalleryOldToolbarNode: ASDisplayNode, WallpaperGalleryToolbar {
    private var theme: PresentationTheme
    private let strings: PresentationStrings
    
    var cancelButtonType: WallpaperGalleryToolbarCancelButtonType {
        didSet {
            self.updateThemeAndStrings(theme: self.theme, strings: self.strings)
        }
    }
    var doneButtonType: WallpaperGalleryToolbarDoneButtonType {
        didSet {
            self.updateThemeAndStrings(theme: self.theme, strings: self.strings)
        }
    }
    
    private let cancelButton = HighlightTrackingButtonNode()
    private let cancelHighlightBackgroundNode = ASDisplayNode()
    private let doneButton = HighlightTrackingButtonNode()
    private let doneHighlightBackgroundNode = ASDisplayNode()
    private let backgroundNode = NavigationBackgroundNode(color: .clear)
    private let separatorNode = ASDisplayNode()
    private let topSeparatorNode = ASDisplayNode()
    
    var cancel: (() -> Void)?
    var done: (() -> Void)?
    
    init(theme: PresentationTheme, strings: PresentationStrings, cancelButtonType: WallpaperGalleryToolbarCancelButtonType = .cancel, doneButtonType: WallpaperGalleryToolbarDoneButtonType = .set) {
        self.theme = theme
        self.strings = strings
        self.cancelButtonType = cancelButtonType
        self.doneButtonType = doneButtonType
        
        self.cancelHighlightBackgroundNode.alpha = 0.0
        self.doneHighlightBackgroundNode.alpha = 0.0
        
        super.init()

        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.cancelHighlightBackgroundNode)
        self.addSubnode(self.cancelButton)
        self.addSubnode(self.doneHighlightBackgroundNode)
        self.addSubnode(self.doneButton)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.topSeparatorNode)
        
        self.updateThemeAndStrings(theme: theme, strings: strings)
        
        self.cancelButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.cancelHighlightBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.cancelHighlightBackgroundNode.alpha = 1.0
                } else {
                    strongSelf.cancelHighlightBackgroundNode.alpha = 0.0
                    strongSelf.cancelHighlightBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                }
            }
        }
        
        self.doneButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.doneHighlightBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.doneHighlightBackgroundNode.alpha = 1.0
                } else {
                    strongSelf.doneHighlightBackgroundNode.alpha = 0.0
                    strongSelf.doneHighlightBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
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
        self.backgroundNode.updateColor(color: theme.rootController.tabBar.backgroundColor, transition: .immediate)
        self.separatorNode.backgroundColor = theme.rootController.tabBar.separatorColor
        self.topSeparatorNode.backgroundColor = theme.rootController.tabBar.separatorColor
        self.cancelHighlightBackgroundNode.backgroundColor = theme.list.itemHighlightedBackgroundColor
        self.doneHighlightBackgroundNode.backgroundColor = theme.list.itemHighlightedBackgroundColor
        
        let cancelTitle: String
        switch self.cancelButtonType {
            case .cancel:
                cancelTitle = strings.Common_Cancel
            case .discard:
                cancelTitle = strings.WallpaperPreview_PatternPaternDiscard
        }
        let doneTitle: String
        switch self.doneButtonType {
            case .set, .setPeer:
                doneTitle = strings.Wallpaper_Set
            case .proceed:
                doneTitle = strings.Theme_Colors_Proceed
            case .apply:
                doneTitle = strings.WallpaperPreview_PatternPaternApply
            case .none:
                doneTitle = ""
                self.doneButton.isUserInteractionEnabled = false
        }
        self.cancelButton.setTitle(cancelTitle, with: Font.regular(17.0), with: theme.list.itemPrimaryTextColor, for: [])
        self.doneButton.setTitle(doneTitle, with: Font.regular(17.0), with: theme.list.itemPrimaryTextColor, for: [])
    }
    
    func updateLayout(size: CGSize, layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.cancelButton.frame = CGRect(origin: CGPoint(), size: CGSize(width: floor(size.width / 2.0), height: size.height))
        self.cancelHighlightBackgroundNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: floor(size.width / 2.0), height: size.height))
        self.doneButton.frame = CGRect(origin: CGPoint(x: floor(size.width / 2.0), y: 0.0), size: CGSize(width: size.width - floor(size.width / 2.0), height: size.height))
        self.doneHighlightBackgroundNode.frame = CGRect(origin: CGPoint(x: floor(size.width / 2.0), y: 0.0), size: CGSize(width: size.width - floor(size.width / 2.0), height: size.height))
        self.separatorNode.frame = CGRect(origin: CGPoint(x: floor(size.width / 2.0), y: 0.0), size: CGSize(width: UIScreenPixel, height: size.height + layout.intrinsicInsets.bottom))
        self.topSeparatorNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: UIScreenPixel))
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: size)
        self.backgroundNode.update(size: CGSize(width: size.width, height: size.height + layout.intrinsicInsets.bottom), transition: .immediate)
    }
    
    @objc func cancelPressed() {
        self.cancel?()
    }
    
    @objc func donePressed() {
        self.done?()
    }
}
