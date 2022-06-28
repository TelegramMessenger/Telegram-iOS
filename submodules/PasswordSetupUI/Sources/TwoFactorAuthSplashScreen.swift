import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SolidRoundedButtonNode
import SwiftSignalKit
import OverlayStatusController
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import TelegramCore

public enum TwoFactorAuthSplashMode {
    public struct Intro {
        public var title: String
        public var text: String
        public var actionText: String
        public var doneText: String
        
        public init(
            title: String,
            text: String,
            actionText: String,
            doneText: String
        ) {
            self.title = title
            self.text = text
            self.actionText = actionText
            self.doneText = doneText
        }
    }
    
    case intro(Intro)
    case done(doneText: String)
    case recoveryDone(recoveredAccountData: RecoveredAccountData?, syncContacts: Bool, isPasswordSet: Bool)
    case remember
}

public final class TwoFactorAuthSplashScreen: ViewController {
    private let sharedContext: SharedAccountContext
    private let engine: SomeTelegramEngine
    private var presentationData: PresentationData
    private var mode: TwoFactorAuthSplashMode
    
    public var dismissConfirmation: ((@escaping () -> Void) -> Bool)?
    
    public init(sharedContext: SharedAccountContext, engine: SomeTelegramEngine, mode: TwoFactorAuthSplashMode, presentation: ViewControllerNavigationPresentation = .modalInLargeLayout) {
        self.sharedContext = sharedContext
        self.engine = engine
        self.mode = mode
        
        self.presentationData = self.sharedContext.currentPresentationData.with { $0 }
        
        let defaultTheme = NavigationBarTheme(rootControllerTheme: self.presentationData.theme)
        let navigationBarTheme = NavigationBarTheme(buttonColor: defaultTheme.buttonColor, disabledButtonColor: defaultTheme.disabledButtonColor, primaryTextColor: defaultTheme.primaryTextColor, backgroundColor: .clear, enableBackgroundBlur: false, separatorColor: .clear, badgeBackgroundColor: defaultTheme.badgeBackgroundColor, badgeStrokeColor: defaultTheme.badgeStrokeColor, badgeTextColor: defaultTheme.badgeTextColor)
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: navigationBarTheme, strings: NavigationBarStrings(back: self.presentationData.strings.Common_Back, close: self.presentationData.strings.Common_Close)))

        self.navigationPresentation = presentation
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.navigationBar?.intrinsicCanTransitionInline = false
        
        let hasBackButton: Bool
        switch mode {
            case .done, .remember:
                hasBackButton = false
            default:
                hasBackButton = true
        }
        if hasBackButton {
            self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        } else {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(customDisplayNode: ASDisplayNode())
        }
        
        self.attemptNavigation = { [weak self] f in
            guard let strongSelf = self, let dismissConfirmation = strongSelf.dismissConfirmation else {
                return true
            }
            
            return dismissConfirmation(f)
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    override public func loadDisplayNode() {
        self.displayNode = TwoFactorAuthSplashScreenNode(sharedContext: self.sharedContext, presentationData: self.presentationData, mode: self.mode, action: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            switch strongSelf.mode {
            case let .intro(intro):
                strongSelf.push(TwoFactorDataInputScreen(sharedContext: strongSelf.sharedContext, engine: strongSelf.engine, mode: .password(doneText: intro.doneText), stateUpdated: { _ in
                }, presentation: strongSelf.navigationPresentation))
            case .done, .remember:
                guard let navigationController = strongSelf.navigationController as? NavigationController else {
                    return
                }
                navigationController.filterController(strongSelf, animated: true)
            case let .recoveryDone(recoveredAccountData, syncContacts, _):
                guard let navigationController = strongSelf.navigationController as? NavigationController else {
                    return
                }
                switch strongSelf.engine {
                case let .unauthorized(engine):
                    if let recoveredAccountData = recoveredAccountData {
                        let _ = loginWithRecoveredAccountData(accountManager: strongSelf.sharedContext.accountManager, account: engine.account, recoveredAccountData: recoveredAccountData, syncContacts: syncContacts).start()
                    }
                case .authorized:
                    navigationController.filterController(strongSelf, animated: true)
                }
            }
        })
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        (self.displayNode as! TwoFactorAuthSplashScreenNode).containerLayoutUpdated(layout: layout, navigationHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}

private final class TwoFactorAuthSplashScreenNode: ViewControllerTracingNode {
    private var presentationData: PresentationData
    private let mode: TwoFactorAuthSplashMode
    
    private var animationSize: CGSize = CGSize()
    private var animationOffset: CGPoint = CGPoint()
    private let animationNode: AnimatedStickerNode
    private let titleNode: ImmediateTextNode
    private let textNodes: [ImmediateTextNode]
    private let textArrowNodes: [ASImageNode]
    let buttonNode: SolidRoundedButtonNode
    
    var inProgress: Bool = false {
        didSet {
            self.buttonNode.isUserInteractionEnabled = !self.inProgress
            self.buttonNode.alpha = self.inProgress ? 0.6 : 1.0
        }
    }
    
    init(sharedContext: SharedAccountContext, presentationData: PresentationData, mode: TwoFactorAuthSplashMode, action: @escaping () -> Void) {
        self.presentationData = presentationData
        self.mode = mode
        
        self.animationNode = DefaultAnimatedStickerNodeImpl()
        
        let title: String
        let texts: [NSAttributedString]
        let buttonText: String
        
        let textFont = Font.regular(16.0)
        let textColor = self.presentationData.theme.list.itemPrimaryTextColor
        
        switch mode {
        case let .intro(intro):
            title = intro.title
            texts = [NSAttributedString(string: intro.text, font: textFont, textColor: textColor)]
            buttonText = intro.actionText
            
            self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "TwoFactorSetupIntro"), width: 248, height: 248, playbackMode: .once, mode: .direct(cachePathPrefix: nil))
            self.animationSize = CGSize(width: 124.0, height: 124.0)
            self.animationNode.visibility = true
        case let .done(doneText):
            title = self.presentationData.strings.TwoFactorSetup_Done_Title
            texts = [NSAttributedString(string: self.presentationData.strings.TwoFactorSetup_Done_Text, font: textFont, textColor: textColor)]
            buttonText = doneText
            
            self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "TwoFactorSetupDone"), width: 248, height: 248, playbackMode: .loop, mode: .direct(cachePathPrefix: nil))
            self.animationSize = CGSize(width: 124.0, height: 124.0)
            self.animationNode.visibility = true
        case let .recoveryDone(_, _, isPasswordSet):
            title = isPasswordSet ? self.presentationData.strings.TwoFactorSetup_ResetDone_Title : self.presentationData.strings.TwoFactorSetup_ResetDone_TitleNoPassword

            let rawText = isPasswordSet ? self.presentationData.strings.TwoFactorSetup_ResetDone_Text : self.presentationData.strings.TwoFactorSetup_ResetDone_TextNoPassword

            var splitTexts: [String] = [""]
            var index = rawText.startIndex
            while index != rawText.endIndex {
                let c = rawText[index]
                if c == ">" {
                    splitTexts.append("")
                } else {
                    splitTexts[splitTexts.count - 1].append(c)
                }
                index = rawText.index(after: index)
            }
            
            texts = splitTexts.map { NSAttributedString(string: $0, font: textFont, textColor: textColor) }
            buttonText = self.presentationData.strings.TwoFactorSetup_ResetDone_Action

            self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: isPasswordSet ? "TwoFactorSetupDone" : "TwoFactorRemovePasswordDone"), width: 248, height: 248, playbackMode: isPasswordSet ? .loop : .once, mode: .direct(cachePathPrefix: nil))
            self.animationSize = CGSize(width: 124.0, height: 124.0)
            self.animationNode.visibility = true
        case .remember:
            title = self.presentationData.strings.TwoFactorRemember_Done_Title
            texts = [NSAttributedString(string: self.presentationData.strings.TwoFactorRemember_Done_Text, font: textFont, textColor: textColor)]
            buttonText = self.presentationData.strings.TwoFactorRemember_Done_Action
            
            self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "TwoFactorSetupRememberSuccess"), width: 248, height: 248, playbackMode: .loop, mode: .direct(cachePathPrefix: nil))
            self.animationSize = CGSize(width: 124.0, height: 124.0)
            self.animationNode.visibility = true
        }
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.bold(32.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.textAlignment = .center
        
        self.textNodes = texts.map { text in
            let textNode = ImmediateTextNode()

            textNode.displaysAsynchronously = false
            textNode.attributedText = text
            textNode.maximumNumberOfLines = 0
            textNode.lineSpacing = 0.1
            textNode.textAlignment = .center

            return textNode
        }

        let arrowImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Search/DownButton"), color: presentationData.theme.list.itemPrimaryTextColor)
        self.textArrowNodes = (0 ..< self.textNodes.count - 1).map { _ in
            let iconNode = ASImageNode()

            iconNode.image = arrowImage
            iconNode.alpha = 0.34

            return iconNode
        }
        
        self.buttonNode = SolidRoundedButtonNode(title: buttonText, theme: SolidRoundedButtonTheme(backgroundColor: self.presentationData.theme.list.itemCheckColors.fillColor, foregroundColor: self.presentationData.theme.list.itemCheckColors.foregroundColor), height: 50.0, cornerRadius: 11.0, gloss: false)
        self.buttonNode.isHidden = buttonText.isEmpty
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        self.addSubnode(self.animationNode)
        self.addSubnode(self.titleNode)
        self.textNodes.forEach(self.addSubnode)
        self.textArrowNodes.forEach(self.addSubnode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.pressed = {
            action()
        }
    }
    
    override func didLoad() {
        super.didLoad()
    }
    
    func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let sideInset: CGFloat = 32.0
        let buttonSideInset: CGFloat = 48.0
        let iconSpacing: CGFloat = 8.0
        let titleSpacing: CGFloat = 19.0
        let buttonHeight: CGFloat = 50.0
        
        let iconSize: CGSize = self.animationSize
        var iconOffset = CGPoint()
        switch self.mode {
        case .done:
            iconOffset.x = 10.0
        default:
            break
        }
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0, height: layout.size.height))
        let textSizes = self.textNodes.map {
            $0.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0, height: layout.size.height))
        }
        var combinedTextHeight: CGFloat = 0.0
        let textSpacing: CGFloat = 32.0
        for textSize in textSizes {
            combinedTextHeight += textSize.height
        }
        combinedTextHeight += CGFloat(max(0, textSizes.count - 1)) * textSpacing
        
        let contentHeight = iconSize.height + iconSpacing + titleSize.height + titleSpacing + combinedTextHeight
        var contentVerticalOrigin = floor((layout.size.height - contentHeight - iconSize.height / 2.0) / 2.0)
        
        let minimalBottomInset: CGFloat = 60.0
        let bottomInset = layout.intrinsicInsets.bottom + minimalBottomInset
        
        let buttonWidth = layout.size.width - buttonSideInset * 2.0
        
        let buttonFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - buttonWidth) / 2.0), y: layout.size.height - bottomInset - buttonHeight), size: CGSize(width: buttonWidth, height: buttonHeight))
        transition.updateFrame(node: self.buttonNode, frame: buttonFrame)
        let _ = self.buttonNode.updateLayout(width: buttonFrame.width, transition: transition)
        
        let maxContentVerticalOrigin = buttonFrame.minY - 12.0 - contentHeight
        
        contentVerticalOrigin = min(contentVerticalOrigin, maxContentVerticalOrigin)
        
        let iconFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - iconSize.width) / 2.0) + self.animationOffset.x, y: contentVerticalOrigin + self.animationOffset.y), size: iconSize).offsetBy(dx: iconOffset.x, dy: iconOffset.y)
        self.animationNode.updateLayout(size: iconFrame.size)
        transition.updateFrameAdditive(node: self.animationNode, frame: iconFrame)
        let titleFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - titleSize.width) / 2.0), y: iconFrame.maxY + iconSpacing), size: titleSize)
        transition.updateFrameAdditive(node: self.titleNode, frame: titleFrame)

        var nextTextOrigin: CGFloat = titleFrame.maxY + titleSpacing
        for i in 0 ..< self.textNodes.count {
            let textFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - textSizes[i].width) / 2.0), y: nextTextOrigin), size: textSizes[i])
            transition.updateFrameAdditive(node: self.textNodes[i], frame: textFrame)

            if i != 0 {
                if let image = self.textArrowNodes[i - 1].image {
                    let scaledImageSize = CGSize(width: floor(image.size.width * 0.7), height: floor(image.size.height * 0.7))
                    self.textArrowNodes[i - 1].frame = CGRect(origin: CGPoint(x: floor((layout.size.width - scaledImageSize.width) / 2.0), y: nextTextOrigin - textSpacing + floor((textSpacing - scaledImageSize.height) / 2.0)), size: scaledImageSize)
                }
            }

            nextTextOrigin = textFrame.maxY + textSpacing
        }
    }
}
