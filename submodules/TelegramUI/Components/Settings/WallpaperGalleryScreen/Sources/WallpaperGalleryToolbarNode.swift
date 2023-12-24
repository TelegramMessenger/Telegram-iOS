import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ManagedAnimationNode
import ComponentFlow
import PremiumLockButtonSubtitleComponent

public enum WallpaperGalleryToolbarCancelButtonType {
    case cancel
    case discard
}

public enum WallpaperGalleryToolbarDoneButtonType {
    case set
    case setPeer(String, Bool)
    case setChannel
    case proceed
    case apply
    case none
}

public protocol WallpaperGalleryToolbar: ASDisplayNode {
    var cancelButtonType: WallpaperGalleryToolbarCancelButtonType { get set }
    var doneButtonType: WallpaperGalleryToolbarDoneButtonType { get set }
    
    var cancel: (() -> Void)? { get set }
    var done: ((Bool) -> Void)? { get set }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings)
    
    func updateLayout(size: CGSize, layout: ContainerViewLayout, transition: ContainedViewLayoutTransition)
}

public final class WallpaperGalleryToolbarNode: ASDisplayNode, WallpaperGalleryToolbar {
    class ButtonNode: ASDisplayNode {
        private let strings: PresentationStrings
        
        private let doneButton = HighlightTrackingButtonNode()
        private var doneButtonBackgroundNode: ASDisplayNode
        private let doneButtonTitleNode: ImmediateTextNode
        private var doneButtonSubtitle: ComponentView<Empty>?
        
        private let doneButtonSolidBackgroundNode: ASDisplayNode
        private let doneButtonSolidTitleNode: ImmediateTextNode
        
        private let animationNode: SimpleAnimationNode
        
        var action: () -> Void = {}
        
        var isLocked: Bool = false {
            didSet {
                self.animationNode.isHidden = !self.isLocked
            }
        }
        
        var requiredLevel: Int?
        
        init(strings: PresentationStrings) {
            self.strings = strings
            
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
            
            self.animationNode = SimpleAnimationNode(animationName: "premium_unlock", size: CGSize(width: 30.0, height: 30.0))
            self.animationNode.customColor = .white
            self.animationNode.isHidden = true
            
            super.init()
            
            self.doneButton.isExclusiveTouch = true

            self.addSubnode(self.doneButtonBackgroundNode)
            self.addSubnode(self.doneButtonTitleNode)
            
            self.addSubnode(self.doneButtonSolidBackgroundNode)
            self.addSubnode(self.doneButtonSolidTitleNode)
            
            self.addSubnode(self.animationNode)
            
            self.addSubnode(self.doneButton)
            
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
                            
                            strongSelf.doneButtonSubtitle?.view?.layer.removeAnimation(forKey: "opacity")
                            strongSelf.doneButtonSubtitle?.view?.alpha = 0.55
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
                            
                            strongSelf.doneButtonSubtitle?.view?.alpha = 1.0
                            strongSelf.doneButtonSubtitle?.view?.layer.animateAlpha(from: 0.55, to: 1.0, duration: 0.2)
                        }
                    }
                }
            }
            
            self.doneButton.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
        }
        
        func setEnabled(_ enabled: Bool) {
            self.doneButton.alpha = enabled ? 1.0 : 0.4
            self.doneButton.isUserInteractionEnabled = enabled
        }
        
        private var isSolid = false
        func setIsSolid(_ isSolid: Bool, transition: ContainedViewLayoutTransition) {
            guard self.isSolid != isSolid else {
                return
            }
            self.isSolid = isSolid
            
            transition.updateAlpha(node: self.doneButtonBackgroundNode, alpha: isSolid ? 0.0 : 1.0)
            transition.updateAlpha(node: self.doneButtonSolidBackgroundNode, alpha: isSolid ? 1.0 : 0.0)
            transition.updateAlpha(node: self.doneButtonTitleNode, alpha: isSolid ? 0.0 : 1.0)
            transition.updateAlpha(node: self.doneButtonSolidTitleNode, alpha: isSolid ? 1.0 : 0.0)
        }
        
        func updateTitle(_ title: String, theme: PresentationTheme) {
            self.doneButtonTitleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(17.0), textColor: .white)
            
            self.doneButtonSolidBackgroundNode.backgroundColor = theme.list.itemCheckColors.fillColor
            self.doneButtonSolidTitleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor)
        }
        
        func updateSize(_ size: CGSize) {
            let bounds = CGRect(origin: .zero, size: size)
            self.doneButtonBackgroundNode.frame = bounds
            if let backgroundNode = self.doneButtonBackgroundNode as? WallpaperOptionBackgroundNode {
                backgroundNode.updateLayout(size: size)
            } else if let backgroundNode = self.doneButtonBackgroundNode as? WallpaperLightButtonBackgroundNode {
                backgroundNode.updateLayout(size: size)
            }
            self.doneButtonSolidBackgroundNode.frame = bounds
            
            let constrainedSize = CGSize(width: size.width - 44.0, height: size.height)
            let iconSize = CGSize(width: 30.0, height: 30.0)
            let doneTitleSize = self.doneButtonTitleNode.updateLayout(constrainedSize)
            
            var totalWidth = doneTitleSize.width
            if self.isLocked {
                totalWidth += iconSize.width + 1.0
            }
            let titleOriginX = floorToScreenPixels((bounds.width - totalWidth) / 2.0)
            
            self.animationNode.frame = CGRect(origin: CGPoint(x: titleOriginX, y: floorToScreenPixels((bounds.height - iconSize.height) / 2.0)), size: iconSize)
            
            var titleFrame = CGRect(origin: CGPoint(x: titleOriginX + totalWidth - doneTitleSize.width, y: floorToScreenPixels((bounds.height - doneTitleSize.height) / 2.0)), size: doneTitleSize).offsetBy(dx: bounds.minX, dy: bounds.minY)
            
            if let requiredLevel = self.requiredLevel {
                let subtitle: ComponentView<Empty>
                if let current = self.doneButtonSubtitle {
                    subtitle = current
                } else {
                    subtitle = ComponentView<Empty>()
                    self.doneButtonSubtitle = subtitle
                }
                
                let subtitleSize = subtitle.update(
                    transition: .immediate,
                    component: AnyComponent(
                        PremiumLockButtonSubtitleComponent(
                            count: requiredLevel,
                            color: UIColor(rgb: 0xffffff, alpha: 0.7),
                            strings: self.strings
                        )
                    ),
                    environment: {},
                    containerSize: size
                )
                
                if let view = subtitle.view {
                    if view.superview == nil {
                        view.isUserInteractionEnabled = false
                        self.view.addSubview(view)
                    }
                    
                    titleFrame.origin.y -= 8.0
                    
                    let subtitleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((bounds.width - subtitleSize.width) / 2.0), y: titleFrame.maxY + 3.0), size: subtitleSize)
                    view.frame = subtitleFrame
                }
            }
            
            self.doneButtonTitleNode.frame = titleFrame
            
            let _ = self.doneButtonSolidTitleNode.updateLayout(constrainedSize)
            self.doneButtonSolidTitleNode.frame = self.doneButtonTitleNode.frame
            
            self.doneButton.frame = bounds
        }
        
        var dark: Bool = false {
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
        
        private var previousActionTime: Double?
        @objc func pressed() {
            let currentTime = CACurrentMediaTime()
            if let previousActionTime = self.previousActionTime, currentTime < previousActionTime + 1.0 {
                return
            }
            self.previousActionTime = currentTime
            self.action()
        }
    }
    
    private var theme: PresentationTheme
    private let strings: PresentationStrings
    
    public var cancelButtonType: WallpaperGalleryToolbarCancelButtonType {
        didSet {
            self.updateThemeAndStrings(theme: self.theme, strings: self.strings)
        }
    }
    public var doneButtonType: WallpaperGalleryToolbarDoneButtonType {
        didSet {
            self.updateThemeAndStrings(theme: self.theme, strings: self.strings)
        }
    }
    
    public var dark: Bool = false {
        didSet {
            self.applyButton.dark = self.dark
            self.applyForBothButton.dark = self.dark
        }
    }
    
    private let applyButton: ButtonNode
    private let applyForBothButton: ButtonNode
    
    public var cancel: (() -> Void)?
    public var done: ((Bool) -> Void)?
    
    var requiredLevel: Int? {
        didSet {
            self.applyButton.requiredLevel = self.requiredLevel
        }
    }
    
    public init(theme: PresentationTheme, strings: PresentationStrings, cancelButtonType: WallpaperGalleryToolbarCancelButtonType = .cancel, doneButtonType: WallpaperGalleryToolbarDoneButtonType = .set) {
        self.theme = theme
        self.strings = strings
        self.cancelButtonType = cancelButtonType
        self.doneButtonType = doneButtonType
        
        self.applyButton = ButtonNode(strings: strings)
        self.applyForBothButton = ButtonNode(strings: strings)
        
        super.init()
        
        self.addSubnode(self.applyButton)
        if case .setPeer = doneButtonType {
            self.addSubnode(self.applyForBothButton)
        }
        
        self.updateThemeAndStrings(theme: theme, strings: strings)
        
        self.applyButton.action = { [weak self] in
            if let self {
                self.done?(false)
            }
        }
        self.applyForBothButton.action = { [weak self] in
            if let self {
                self.done?(true)
            }
        }
    }
    
    public func setDoneEnabled(_ enabled: Bool) {
        self.applyButton.setEnabled(enabled)
        self.applyForBothButton.setEnabled(enabled)
    }
    
    private var isSolid = false
    public func setDoneIsSolid(_ isSolid: Bool, transition: ContainedViewLayoutTransition) {
        guard self.isSolid != isSolid else {
            return
        }
        
        self.isSolid = isSolid
        self.applyButton.setIsSolid(isSolid, transition: transition)
        self.applyForBothButton.setIsSolid(isSolid, transition: transition)
    }
    
    public func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
                
        let applyTitle: String
        var applyForBothTitle: String? = nil
        var applyForBothLocked = false
        switch self.doneButtonType {
        case .set:
            applyTitle = strings.Wallpaper_ApplyForAll
        case let .setPeer(name, isPremium):
            applyTitle = strings.Wallpaper_ApplyForMe
            applyForBothTitle = strings.Wallpaper_ApplyForBoth(name).string
            applyForBothLocked = !isPremium
        case .setChannel:
            applyTitle = strings.Wallpaper_ApplyForChannel
        case .proceed:
            applyTitle = strings.Theme_Colors_Proceed
        case .apply:
            applyTitle = strings.WallpaperPreview_PatternPaternApply
        case .none:
            applyTitle = ""
            self.applyButton.isUserInteractionEnabled = false
        }
        
        self.applyButton.updateTitle(applyTitle, theme: theme)
        if let applyForBothTitle {
            self.applyForBothButton.updateTitle(applyForBothTitle, theme: theme)
        }
        self.applyForBothButton.isLocked = applyForBothLocked
    }
    
    public func updateLayout(size: CGSize, layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        let inset: CGFloat = 16.0
        let buttonHeight: CGFloat = 50.0
        
        let spacing: CGFloat = 8.0
        
        let applyFrame = CGRect(origin: CGPoint(x: inset, y: 2.0), size: CGSize(width: size.width - inset * 2.0, height: buttonHeight))
        let applyForBothFrame = CGRect(origin: CGPoint(x: inset, y: applyFrame.maxY + spacing), size: CGSize(width: size.width - inset * 2.0, height: buttonHeight))
        
        var showApplyForBothButton = false
        if case .setPeer = self.doneButtonType {
            showApplyForBothButton = true
        }
        transition.updateAlpha(node: self.applyForBothButton, alpha: showApplyForBothButton ? 1.0 : 0.0)
        
        self.applyButton.frame = applyFrame
        self.applyButton.updateSize(applyFrame.size)
        self.applyForBothButton.frame = applyForBothFrame
        self.applyForBothButton.updateSize(applyForBothFrame.size)
    }
    
    @objc func cancelPressed() {
        self.cancel?()
    }
}

public final class WallpaperGalleryOldToolbarNode: ASDisplayNode, WallpaperGalleryToolbar {
    private var theme: PresentationTheme
    private let strings: PresentationStrings
    
    public var cancelButtonType: WallpaperGalleryToolbarCancelButtonType {
        didSet {
            self.updateThemeAndStrings(theme: self.theme, strings: self.strings)
        }
    }
    public var doneButtonType: WallpaperGalleryToolbarDoneButtonType {
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
    
    public var cancel: (() -> Void)?
    public var done: ((Bool) -> Void)?
    
    public init(theme: PresentationTheme, strings: PresentationStrings, cancelButtonType: WallpaperGalleryToolbarCancelButtonType = .cancel, doneButtonType: WallpaperGalleryToolbarDoneButtonType = .set) {
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
    
    public func setDoneEnabled(_ enabled: Bool) {
        self.doneButton.alpha = enabled ? 1.0 : 0.4
        self.doneButton.isUserInteractionEnabled = enabled
    }
    
    public func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
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
            case .set, .setPeer, .setChannel:
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
    
    public func updateLayout(size: CGSize, layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
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
        self.done?(false)
    }
}
