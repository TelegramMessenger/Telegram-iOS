import Foundation
import UIKit
import AppBundle
import AsyncDisplayKit
import Display
import SolidRoundedButtonNode
import SwiftSignalKit
import OverlayStatusController
import AnimatedStickerNode
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import GZip

public enum FalseBottomSplashMode {
    case hideAccount
    case addOneMoreAccount
    case setMasterPasscode
    case setSecretPasscode
    case disableNotifications
    case lockExplanation
    case accountWasHidden
}

public final class FalseBottomSplashScreen: ViewController {
    private let presentationData: PresentationData
    private let mode: FalseBottomSplashMode
    
    var buttonPressedWithEnabledSwitch: ((Bool) -> Void)?
    var buttonPressed: (() -> Void)?
    var backPressed: (() -> Void)? {
        didSet {
            navigationItem.leftBarButtonItem = UIBarButtonItem(backButtonAppearanceWithTitle: presentationData.strings.Common_Back, target: self, action: #selector(self.didTapBack))
        }
    }
    
    var poppedInteractively: (() -> Void)?
    
    public init(presentationData: PresentationData, mode: FalseBottomSplashMode) {
        self.presentationData = presentationData
        self.mode = mode
        
        let defaultTheme = NavigationBarTheme(rootControllerTheme: self.presentationData.theme)
        let navigationBarTheme = NavigationBarTheme(buttonColor: defaultTheme.buttonColor, disabledButtonColor: defaultTheme.disabledButtonColor, primaryTextColor: defaultTheme.primaryTextColor, backgroundColor: .clear, separatorColor: .clear, badgeBackgroundColor: defaultTheme.badgeBackgroundColor, badgeStrokeColor: defaultTheme.badgeStrokeColor, badgeTextColor: defaultTheme.badgeTextColor)
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: navigationBarTheme, strings: NavigationBarStrings(back: self.presentationData.strings.Common_Back, close: self.presentationData.strings.Common_Close)))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationPresentation = .modalInLargeLayout
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.navigationBar?.intrinsicCanTransitionInline = false
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        self.navigationPresentation = .modalInLargeLayout
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    override public func loadDisplayNode() {
        if mode == .disableNotifications {
            self.displayNode = FalseBottomSwitchScreenNode(presentationData: self.presentationData, action: { [weak self] enabled in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.buttonPressedWithEnabledSwitch?(enabled)
                strongSelf.buttonPressed?()
            })
        } else {
            self.displayNode = FalseBottomSplashScreenNode(presentationData: self.presentationData, mode: self.mode, action: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.buttonPressed?()
            })
        }
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        if let displayNode = self.displayNode as? FalseBottomSplashScreenNode {
            displayNode.containerLayoutUpdated(layout: layout, navigationHeight: self.navigationHeight, transition: transition)
        }
        
        if let displayNode = self.displayNode as? FalseBottomSwitchScreenNode {
            displayNode.containerLayoutUpdated(layout: layout, navigationHeight: self.navigationHeight, transition: transition)
        }
    }
    
    override public func viewDidPopFromNavigationInteractively() {
        poppedInteractively?()
    }
    
    override public func allowInteractivePopFromNavigation() -> Bool {
        return mode != .accountWasHidden
    }
    
    @objc func didTapBack() {
        backPressed?()
    }
}

private final class FalseBottomSwitchScreenNode: ViewControllerTracingNode {
    private let switchNode: BorderSwitchNode
    private let textNode: ImmediateTextNode
    private let subtitleNode: ImmediateTextNode
    private let animationNode: AnimatedStickerNode
    private var animationSize: CGSize = CGSize()
    private let buttonNode: SolidRoundedButtonNode
    
    init(presentationData: PresentationData, action: @escaping (Bool) -> Void) {
        let textFont = Font.regular(16.0)
        let textColor = presentationData.theme.list.itemPrimaryTextColor

        let subtitleFont = Font.regular(12.0)
        let subtitleColor = UIColor(rgb: 0x8D8E93)
        
        let switchOnColorForLightBackground = UIColor(rgb: 0xA6A6A6)
        let switchOnColorForDarkBackground = UIColor(rgb: 0x494949)
        
        let text = NSAttributedString(string: presentationData.strings.FalseBottom_DisableNotifications_Text, font: textFont, textColor: textColor)
        let subtitle = NSAttributedString(string: presentationData.strings.FalseBottom_DisableNotifications_Subtitle, font: subtitleFont, textColor: subtitleColor)
        let buttonText = presentationData.strings.Common_Next
        let source = FalseBottomAnimationSource(mode: .disableNotifications)
        
        self.animationNode = AnimatedStickerNode()
        if let source = source {
            self.animationNode.setup(source: source, width: 528, height: 348, playbackMode: .loop, mode: .direct(cachePathPrefix: nil))
            self.animationSize = CGSize(width: 264.0, height: 174.0)
            self.animationNode.visibility = true
        }
        
        self.buttonNode = SolidRoundedButtonNode(title: buttonText, theme: SolidRoundedButtonTheme(backgroundColor: presentationData.theme.list.itemCheckColors.fillColor, foregroundColor: presentationData.theme.list.itemCheckColors.foregroundColor), height: 50.0, cornerRadius: 10.0, gloss: false)
        
        self.switchNode = BorderSwitchNode()
        self.switchNode.contentColor = presentationData.theme.list.plainBackgroundColor.isDark ? switchOnColorForDarkBackground : switchOnColorForLightBackground
        self.switchNode.isOn = true
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.attributedText = text
        self.textNode.maximumNumberOfLines = 0
        self.textNode.textAlignment = .center
        
        self.subtitleNode = ImmediateTextNode()
        self.subtitleNode.displaysAsynchronously = false
        self.subtitleNode.attributedText = subtitle
        self.subtitleNode.maximumNumberOfLines = 0
        self.subtitleNode.textAlignment = .center
        
        super.init()
        
        self.backgroundColor = presentationData.theme.list.plainBackgroundColor
        
        self.addSubnode(self.animationNode)
        self.addSubnode(self.subtitleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.switchNode)
        
        self.buttonNode.pressed = { [weak self] in
            guard let self = self else { return }

            action(self.switchNode.isOn)
        }
    }
    
    func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let isIphone4s = layout.size.height <= 480
        
        let textWidth: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 426.0 : 270.0
        let buttonSideInset: CGFloat = 48.0
        let iconSpacing: CGFloat = 19.0
        let switchSpacing: CGFloat = 32.0
        let textSpacing: CGFloat = 10.0
        let buttonHeight: CGFloat = 50.0
        let titleCenterOffset: CGFloat = UIScreen.main.isNarrowDevice ? -9.0 : -38.0
        let iconSize: CGSize = self.animationSize
        
        let switchSize = self.switchNode.frame.size
        let textSize = self.textNode.updateLayout(CGSize(width: textWidth, height: layout.size.height))
        let subtitleSize = self.subtitleNode.updateLayout(CGSize(width: textWidth, height: layout.size.height))
        
        let minimalBottomInset: CGFloat = 60.0
        let bottomInset = layout.intrinsicInsets.bottom + (isIphone4s ? 23.0 : minimalBottomInset)
        
        let buttonWidth = layout.size.width - buttonSideInset * 2.0
        
        let buttonFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - buttonWidth) / 2.0), y: layout.size.height - bottomInset - buttonHeight), size: CGSize(width: buttonWidth, height: buttonHeight))
        transition.updateFrame(node: self.buttonNode, frame: buttonFrame)
        self.buttonNode.updateLayout(width: buttonFrame.width, transition: transition)
        
        let switchFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - switchSize.width) / 2.0), y: floor(layout.size.height / 2.0) + titleCenterOffset), size: switchSize)
        transition.updateFrameAdditive(node: self.switchNode, frame: switchFrame)
        
        let iconFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - iconSize.width) / 2.0), y: switchFrame.origin.y - (iconSize.height + iconSpacing)), size: iconSize)
        self.animationNode.updateLayout(size: iconFrame.size)
        transition.updateFrameAdditive(node: self.animationNode, frame: iconFrame)
        
        let textFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - textSize.width) / 2.0), y: switchFrame.maxY + switchSpacing), size: textSize)
        transition.updateFrameAdditive(node: self.textNode, frame: textFrame)
        
        let subtitleFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - subtitleSize.width) / 2.0), y: textFrame.maxY + textSpacing), size: subtitleSize)
        transition.updateFrameAdditive(node: self.subtitleNode, frame: subtitleFrame)
    }
}

private final class FalseBottomSplashScreenNode: ViewControllerTracingNode {
    private let presentationData: PresentationData
    private let mode: FalseBottomSplashMode
    
    private var animationSize: CGSize = CGSize()
    private let animationNode: AnimatedStickerNode
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    let buttonNode: SolidRoundedButtonNode
    
    var inProgress: Bool = false {
        didSet {
            self.buttonNode.isUserInteractionEnabled = !self.inProgress
            self.buttonNode.alpha = self.inProgress ? 0.6 : 1.0
        }
    }
    
    init(presentationData: PresentationData, mode: FalseBottomSplashMode, action: @escaping () -> Void) {
        self.presentationData = presentationData
        self.mode = mode
        
        self.animationNode = AnimatedStickerNode()
        
        let title: String
        let text: NSAttributedString
        let buttonText: String
        
        let textFont = Font.regular(16.0)
        let textColor = self.presentationData.theme.list.itemPrimaryTextColor
        let source = FalseBottomAnimationSource(mode: mode)
        
        self.animationSize = UIScreen.main.isIphone4 ? CGSize(width: 211.0, height: 139.0) : CGSize(width: 264.0, height: 174.0)

        switch mode {
        case .hideAccount:
            title = presentationData.strings.FalseBottom_HideAccount_Title
            text = NSAttributedString(string: presentationData.strings.FalseBottom_HideAccount_Text, font: textFont, textColor: textColor)
            buttonText = presentationData.strings.FalseBottom_HideAccount_Button
            
        case .addOneMoreAccount:
            title = presentationData.strings.FalseBottom_AddOneMoreAccount_Title
            text = NSAttributedString(string: presentationData.strings.FalseBottom_AddOneMoreAccount_Text, font: textFont, textColor: textColor)
            buttonText = presentationData.strings.FalseBottom_AddOneMoreAccount_Button
            
            if let source = source {
                self.animationSize = UIScreen.main.isIphone4 ? CGSize(width: 70.0, height: 139.0) : CGSize(width: 87.0, height: 174.0)
        }
            
        case .setMasterPasscode:
            title = presentationData.strings.FalseBottom_SetMasterPasscode_Title
            text = NSAttributedString(string: presentationData.strings.FalseBottom_SetMasterPasscode_Text, font: textFont, textColor: textColor)
            buttonText = presentationData.strings.FalseBottom_SetMasterPasscode_Button
            
        case .setSecretPasscode:
            title = presentationData.strings.FalseBottom_SetSecretPasscode_Title
            text = NSAttributedString(string: presentationData.strings.FalseBottom_SetSecretPasscode_Text, font: textFont, textColor: textColor)
            buttonText = presentationData.strings.FalseBottom_SetSecretPasscode_Button
            
        case .disableNotifications:
            title = ""
            text = NSAttributedString()
            buttonText = ""
            
        case .lockExplanation:
            title = presentationData.strings.FalseBottom_LockExplanation_Title
            text = NSAttributedString(string: presentationData.strings.FalseBottom_LockExplanation_Text, font: textFont, textColor: textColor)
            buttonText = presentationData.strings.FalseBottom_LockExplanation_Button

        case .accountWasHidden:
            title = presentationData.strings.FalseBottom_AccountWasHidden_Title
            text = NSAttributedString(string: presentationData.strings.FalseBottom_AccountWasHidden_Text, font: textFont, textColor: textColor)
            buttonText = presentationData.strings.FalseBottom_AccountWasHidden_Button
        }
        
        if let source = source {
            self.animationNode.visibility = true
            self.animationNode.setup(source: source, width: Int(self.animationSize.width * 2.0), height: Int(self.animationSize.height * 2.0), playbackMode: .loop, mode: .direct(cachePathPrefix: nil))
        }
        
        let titleSize: CGFloat = UIScreen.main.isNarrowDevice ? 28.0 : 32.0
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.bold(titleSize), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.textAlignment = .center
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.attributedText = text
        self.textNode.maximumNumberOfLines = 0
        self.textNode.lineSpacing = 0.1
        self.textNode.textAlignment = .center
        
        self.buttonNode = SolidRoundedButtonNode(title: buttonText, theme: SolidRoundedButtonTheme(backgroundColor: self.presentationData.theme.list.itemCheckColors.fillColor, foregroundColor: self.presentationData.theme.list.itemCheckColors.foregroundColor), height: 50.0, cornerRadius: 10.0, gloss: false)
        self.buttonNode.isHidden = buttonText.isEmpty
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        self.addSubnode(self.animationNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.pressed = {
            action()
        }
    }
    
    override func didLoad() {
        super.didLoad()
    }
    
    func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let isIphone4s = layout.size.height <= 480
        
        let textWidth: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 426.0 : 270.0
        let buttonSideInset: CGFloat = 48.0
        let iconSpacing: CGFloat = 27.0
        let titleSpacing: CGFloat = 20.0
        let buttonHeight: CGFloat = 50.0
        let titleCenterOffset: CGFloat = UIScreen.main.isNarrowDevice ? 0.0 : -32.0
        let iconSize: CGSize = self.animationSize
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: textWidth, height: layout.size.height))
        let textSize = self.textNode.updateLayout(CGSize(width: textWidth, height: layout.size.height))
        
        let minimalBottomInset: CGFloat = isIphone4s ? 23.0 : 60.0
        let bottomInset = layout.intrinsicInsets.bottom + minimalBottomInset
        
        let buttonWidth = layout.size.width - buttonSideInset * 2.0
        
        let buttonFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - buttonWidth) / 2.0), y: layout.size.height - bottomInset - buttonHeight), size: CGSize(width: buttonWidth, height: buttonHeight))
        transition.updateFrame(node: self.buttonNode, frame: buttonFrame)
        self.buttonNode.updateLayout(width: buttonFrame.width, transition: transition)
        
        let titleFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - titleSize.width) / 2.0), y: floor((layout.size.height) / 2.0 + titleCenterOffset)), size: titleSize)
        transition.updateFrameAdditive(node: self.titleNode, frame: titleFrame)
        
        let iconFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - iconSize.width) / 2.0), y: titleFrame.origin.y - iconSpacing - iconSize.height), size: iconSize)
        self.animationNode.updateLayout(size: iconFrame.size)
        transition.updateFrameAdditive(node: self.animationNode, frame: iconFrame)
        
        let textFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - textSize.width) / 2.0), y: titleFrame.maxY + titleSpacing), size: textSize)
        transition.updateFrameAdditive(node: self.textNode, frame: textFrame)
    }
}

private extension UIColor {
    var lottieColor: String {
        let (r, g, b, _) = rgba
        return "\(r),\(g),\(b),1"
    }
    
    func interpolated(to color: UIColor, percentage: CGFloat) -> UIColor {
        let fromHSBA = hsba
        let toHSBA = color.hsba
        let h = fromHSBA.h.interpolated(to: toHSBA.h, percentage: percentage)
        let s = fromHSBA.s.interpolated(to: toHSBA.s, percentage: percentage)
        let b = fromHSBA.b.interpolated(to: toHSBA.b, percentage: percentage)
        let a = fromHSBA.a.interpolated(to: toHSBA.a, percentage: percentage)
        return UIColor(hue: h, saturation: s, brightness:b, alpha: a)
    }
    
    var hsba: (h: CGFloat, s: CGFloat, b: CGFloat, a: CGFloat) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness:&b, alpha: &a)
        return (h, s, b, a)
    }
    
    var rgba: (h: CGFloat, s: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue:&b, alpha: &a)
        return (r, g, b, a)
    }
    
    var grayscale: UIColor {
        let (r, g, b, a) = rgba
        return UIColor(white: 0.299 * r + 0.587 * g + 0.114 * b, alpha: a)
    }
    
    var complement: UIColor {
        let (h, s, b, a) = hsba
        var newHue = h > 0.5 ? h - 0.5 : h + 0.5
        return UIColor(hue: newHue, saturation: s, brightness:b, alpha: a)
    }
    
    var isDark: Bool {
        let color = CIColor(color: self)
        
        let red = color.red * 255
        let green = color.green * 255
        let blue = color.blue * 255
        
        var luma = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        
        return luma < 40
    }
}

private extension CGFloat {
    func interpolated(to value: CGFloat, percentage: CGFloat) -> CGFloat {
        let delta = value - self
        return self + delta * percentage
    }
}

private final class FalseBottomAnimationSource: AnimatedStickerNodeSource {
    public let path: String
    
    public init?(mode: FalseBottomSplashMode) {
        let fileName: String
        
        switch mode {
        case .hideAccount:
            fileName = "FalseBottomHideAccount"
            
        case .addOneMoreAccount:
            fileName = "FalseBottomAddOneMoreAccount"
            
        case .setMasterPasscode:
            fileName = "FalseBottomSetMasterPasscode"
            
        case .setSecretPasscode:
            fileName = "FalseBottomHiddenPassword"
            
        case .disableNotifications:
            fileName = "FalseBottomNotifications_part_1"
            
        case .lockExplanation:
            fileName = "FalseBottomLocking"
            
        case .accountWasHidden:
            fileName = "FalseBottomAccountIsHidden"
        }
        
        guard let path = getAppBundle().path(forResource: fileName, ofType: "tgs") else { return nil }
        
        self.path = path
    }
    
    public func directDataPath() -> Signal<String, NoError> {
        return .single(self.path)
    }
    
    public func cachedDataPath(width: Int, height: Int) -> Signal<(String, Bool), NoError> {
        return .never()
    }
}

fileprivate extension UIScreen {
    var isNarrowDevice: Bool {
        bounds.width <= 320
    }
    
    var isIphone4: Bool {
        isNarrowDevice && bounds.height <= 480
    }
}
