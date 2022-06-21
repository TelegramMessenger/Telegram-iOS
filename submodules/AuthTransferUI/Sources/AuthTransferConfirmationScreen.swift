import Foundation
import UIKit
import AppBundle
import AsyncDisplayKit
import Display
import SolidRoundedButtonNode
import SwiftSignalKit
import OverlayStatusController
import AnimationUI
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import TelegramCore
import Markdown
import DeviceAccess
import QrCodeUI

private func transformedWithTheme(data: Data, theme: PresentationTheme) -> Data {
    return transformedWithColors(data: data, colors: [(UIColor(rgb: 0x333333), theme.list.itemPrimaryTextColor.mixedWith(.white, alpha: 0.2)), (UIColor(rgb: 0xFFFFFF), theme.list.plainBackgroundColor), (UIColor(rgb: 0x50A7EA), theme.list.itemAccentColor), (UIColor(rgb: 0x212121), theme.list.plainBackgroundColor)])
}

public final class AuthDataTransferSplashScreen: ViewController {
    private let context: AccountContext
    private let activeSessionsContext: ActiveSessionsContext
    private var presentationData: PresentationData
    
    public init(context: AccountContext, activeSessionsContext: ActiveSessionsContext) {
        self.context = context
        self.activeSessionsContext = activeSessionsContext
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let defaultTheme = NavigationBarTheme(rootControllerTheme: self.presentationData.theme)
        let navigationBarTheme = NavigationBarTheme(buttonColor: defaultTheme.buttonColor, disabledButtonColor: defaultTheme.disabledButtonColor, primaryTextColor: defaultTheme.primaryTextColor, backgroundColor: .clear, enableBackgroundBlur: false, separatorColor: .clear, badgeBackgroundColor: defaultTheme.badgeBackgroundColor, badgeStrokeColor: defaultTheme.badgeStrokeColor, badgeTextColor: defaultTheme.badgeTextColor)
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: navigationBarTheme, strings: NavigationBarStrings(back: self.presentationData.strings.Common_Back, close: self.presentationData.strings.Common_Close)))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationPresentation = .modalInLargeLayout
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.navigationBar?.intrinsicCanTransitionInline = false
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    override public func loadDisplayNode() {
        self.displayNode = AuthDataTransferSplashScreenNode(context: self.context, presentationData: self.presentationData, action: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            DeviceAccess.authorizeAccess(to: .camera(.qrCode), presentationData: strongSelf.presentationData, present: { c, a in
                guard let strongSelf = self else {
                    return
                }
                c.presentationArguments = a
                strongSelf.context.sharedContext.mainWindow?.present(c, on: .root)
            }, openSettings: {
                self?.context.sharedContext.applicationBindings.openSettings()
            }, { granted in
                guard let strongSelf = self else {
                    return
                }
                guard granted else {
                    return
                }
                (strongSelf.navigationController as? NavigationController)?.replaceController(strongSelf, with: QrCodeScanScreen(context: strongSelf.context, subject: .authTransfer(activeSessionsContext: strongSelf.activeSessionsContext)), animated: true)
            })
        })
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        (self.displayNode as! AuthDataTransferSplashScreenNode).containerLayoutUpdated(layout: layout, navigationHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}

private final class AuthDataTransferSplashScreenNode: ViewControllerTracingNode {
    private var presentationData: PresentationData
    
    private var animationSize: CGSize = CGSize()
    private var animationOffset: CGPoint = CGPoint()
    private let animationNode: AnimationNode?
    private let titleNode: ImmediateTextNode
    private let badgeBackgroundNodes: [ASImageNode]
    private let badgeTextNodes: [ImmediateTextNode]
    private let textNodes: [ImmediateTextNode]
    let buttonNode: SolidRoundedButtonNode
    
    private let hierarchyTrackingNode: HierarchyTrackingNode
    
    var inProgress: Bool = false {
        didSet {
            self.buttonNode.isUserInteractionEnabled = !self.inProgress
            self.buttonNode.alpha = self.inProgress ? 0.6 : 1.0
        }
    }
    
    private var validLayout: ContainerViewLayout?
    
    init(context: AccountContext, presentationData: PresentationData, action: @escaping () -> Void) {
        self.presentationData = presentationData
        
        if let url = getAppBundle().url(forResource: "anim_qr", withExtension: "json"), let data = try? Data(contentsOf: url) {
            self.animationNode = AnimationNode(animationData: transformedWithTheme(data: data, theme: presentationData.theme))
        } else {
            self.animationNode = nil
        }
        
        let buttonText: String
        
        let badgeFont = Font.with(size: 13.0, design: .round, weight: .bold)
        let textFont = Font.regular(16.0)
        let textColor = self.presentationData.theme.list.itemPrimaryTextColor
        
        var badgeBackgroundNodes: [ASImageNode] = []
        var badgeTextNodes: [ImmediateTextNode] = []
        var textNodes: [ImmediateTextNode] = []
        
        let badgeBackground = generateFilledCircleImage(diameter: 20.0, color: self.presentationData.theme.list.itemCheckColors.fillColor)
        
        for i in 0 ..< 3 {
            let badgeBackgroundNode = ASImageNode()
            badgeBackgroundNode.displaysAsynchronously = false
            badgeBackgroundNode.displayWithoutProcessing = true
            badgeBackgroundNode.image = badgeBackground
            badgeBackgroundNodes.append(badgeBackgroundNode)
            
            let badgeTextNode = ImmediateTextNode()
            badgeTextNode.displaysAsynchronously = false
            badgeTextNode.attributedText = NSAttributedString(string: "\(i + 1)", font: badgeFont, textColor: self.presentationData.theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .natural)
            badgeTextNode.maximumNumberOfLines = 0
            badgeTextNode.lineSpacing = 0.1
            badgeTextNodes.append(badgeTextNode)
            
            let string: String
            switch i {
            case 0:
                string = self.presentationData.strings.AuthSessions_AddDeviceIntro_Text1
            case 1:
                string = self.presentationData.strings.AuthSessions_AddDeviceIntro_Text2
            default:
                string = self.presentationData.strings.AuthSessions_AddDeviceIntro_Text3
            }
            
            let body = MarkdownAttributeSet(font: textFont, textColor: textColor)
            let link = MarkdownAttributeSet(font: textFont, textColor: self.presentationData.theme.list.itemAccentColor, additionalAttributes: ["URL": true as NSNumber])
            
            let text = parseMarkdownIntoAttributedString(string, attributes: MarkdownAttributes(body: body, bold: body, link: link, linkAttribute: { _ in
                return nil
            }))
            
            let textNode = ImmediateTextNode()
            textNode.displaysAsynchronously = false
            textNode.attributedText = text
            textNode.maximumNumberOfLines = 0
            textNode.lineSpacing = 0.1
            textNodes.append(textNode)
        }
        
        self.badgeBackgroundNodes = badgeBackgroundNodes
        self.badgeTextNodes = badgeTextNodes
        self.textNodes = textNodes
            
        buttonText = self.presentationData.strings.AuthSessions_AddDeviceIntro_Action
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: self.presentationData.strings.AuthSessions_AddDeviceIntro_Title, font: Font.bold(24.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.textAlignment = .center
        
        self.buttonNode = SolidRoundedButtonNode(title: buttonText, theme: SolidRoundedButtonTheme(backgroundColor: self.presentationData.theme.list.itemCheckColors.fillColor, foregroundColor: self.presentationData.theme.list.itemCheckColors.foregroundColor), height: 50.0, cornerRadius: 10.0, gloss: false)
        self.buttonNode.isHidden = buttonText.isEmpty
        
        var updateInHierarchy: ((Bool) -> Void)?
        self.hierarchyTrackingNode = HierarchyTrackingNode({ value in
            updateInHierarchy?(value)
        })
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        self.addSubnode(self.hierarchyTrackingNode)
        
        if let animationNode = self.animationNode {
            self.addSubnode(animationNode)
        }
        self.addSubnode(self.titleNode)
        
        self.badgeBackgroundNodes.forEach(self.addSubnode)
        self.badgeTextNodes.forEach(self.addSubnode)
        self.textNodes.forEach(self.addSubnode)
        
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.pressed = {
            action()
        }
        
        for textNode in self.textNodes {
            textNode.linkHighlightColor = self.presentationData.theme.list.itemAccentColor.withAlphaComponent(0.5)
            textNode.highlightAttributeAction = { attributes in
                if let _ = attributes[NSAttributedString.Key(rawValue: "URL")] {
                    return NSAttributedString.Key(rawValue: "URL")
                } else {
                    return nil
                }
            }
            textNode.tapAttributeAction = { attributes, _ in
                if let _ = attributes[NSAttributedString.Key(rawValue: "URL")] {
                    context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: "https://desktop.telegram.org", forceExternal: true, presentationData: context.sharedContext.currentPresentationData.with { $0 }, navigationController: nil, dismissInput: {})
                }
            }
        }
        
        updateInHierarchy = { [weak self] value in
            if value {
                self?.animationNode?.play()
            } else {
                self?.animationNode?.reset()
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
    }
    
    func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let firstTime = self.validLayout == nil
        self.validLayout = layout
        
        let sideInset: CGFloat = 22.0
        let textSideInset: CGFloat = 54.0
        let buttonSideInset: CGFloat = 16.0
        let titleSpacing: CGFloat = 25.0
        let buttonHeight: CGFloat = 50.0
        let buttonSpacing: CGFloat = 16.0
        let textSpacing: CGFloat = 25.0
        let badgeSize: CGFloat = 20.0
        
        let animationFitSize = CGSize(width: min(500.0, layout.size.width - sideInset + 20.0), height: 500.0)
        let animationSize = self.animationNode?.preferredSize()?.fitted(animationFitSize) ?? animationFitSize
        let iconSize: CGSize = animationSize
        let iconOffset = CGPoint()
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0, height: layout.size.height))
        
        var badgeTextSizes: [CGSize] = []
        var textSizes: [CGSize] = []
        var textContentHeight: CGFloat = 0.0
        for i in 0 ..< self.badgeTextNodes.count {
            let badgeTextSize = self.badgeTextNodes[i].updateLayout(CGSize(width: 100.0, height: .greatestFiniteMagnitude))
            badgeTextSizes.append(badgeTextSize)
            let textSize = self.textNodes[i].updateLayout(CGSize(width: layout.size.width - sideInset * 2.0 - 40.0, height: .greatestFiniteMagnitude))
            textSizes.append(textSize)
            
            if i != 0 {
                textContentHeight += textSpacing
            }
            textContentHeight += textSize.height
        }
        
        var contentHeight = iconSize.height + titleSize.height + titleSpacing + textContentHeight
        
        let bottomInset = layout.intrinsicInsets.bottom + 20.0
        let contentTopInset = navigationHeight
        let contentBottomInset = bottomInset + buttonHeight + buttonSpacing
        
        let iconSpacing: CGFloat = max(20.0, min(61.0, layout.size.height - contentTopInset - contentBottomInset - contentHeight - 40.0))
        
        contentHeight += iconSpacing
        
        var contentVerticalOrigin = contentTopInset + floor((layout.size.height - contentTopInset - contentBottomInset - contentHeight) / 2.0)
        
        let buttonWidth = layout.size.width - buttonSideInset * 2.0
        
        let buttonFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - buttonWidth) / 2.0), y: layout.size.height - bottomInset - buttonHeight), size: CGSize(width: buttonWidth, height: buttonHeight))
        transition.updateFrame(node: self.buttonNode, frame: buttonFrame)
        let _ = self.buttonNode.updateLayout(width: buttonFrame.width, transition: transition)
        
        let maxContentVerticalOrigin = buttonFrame.minY - 12.0 - contentHeight
        
        contentVerticalOrigin = min(contentVerticalOrigin, maxContentVerticalOrigin)
        
        var contentY = contentVerticalOrigin
        let iconFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - iconSize.width) / 2.0) + self.animationOffset.x, y: contentY), size: iconSize).offsetBy(dx: iconOffset.x, dy: iconOffset.y)
        contentY += iconSize.height + iconSpacing
        if let animationNode = self.animationNode {
            transition.updateFrameAdditive(node: animationNode, frame: iconFrame)
            if iconFrame.minY < 0.0 {
                transition.updateAlpha(node: animationNode, alpha: 0.0)
            } else {
                transition.updateAlpha(node: animationNode, alpha: 1.0)
            }
        }
        
        let titleFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - titleSize.width) / 2.0), y: contentY), size: titleSize)
        transition.updateFrameAdditive(node: self.titleNode, frame: titleFrame)
        contentY += titleSize.height + titleSpacing
        
        for i in 0 ..< self.badgeTextNodes.count {
            if i != 0 {
                contentY += textSpacing
            }
            
            let badgeTextSize = badgeTextSizes[i]
            let textSize = textSizes[i]
            
            let textFrame = CGRect(origin: CGPoint(x: textSideInset, y: contentY), size: textSize)
            transition.updateFrameAdditive(node: self.textNodes[i], frame: textFrame)
            
            let badgeFrame = CGRect(origin: CGPoint(x: sideInset, y: textFrame.minY), size: CGSize(width: badgeSize, height: badgeSize))
            transition.updateFrameAdditive(node: self.badgeBackgroundNodes[i], frame: badgeFrame)
            
            let badgeTextOffsetX: CGFloat
            if i == 0 {
                badgeTextOffsetX = 0.5
            } else {
                badgeTextOffsetX = 1.0
            }
            
            transition.updateFrameAdditive(node: self.badgeTextNodes[i], frame: CGRect(origin: CGPoint(x: badgeFrame.minX + floor((badgeFrame.width - badgeTextSize.width) / 2.0) + badgeTextOffsetX, y: badgeFrame.minY + floor((badgeFrame.height - badgeTextSize.height) / 2.0) + 0.5), size: badgeTextSize))
            
            contentY += textSize.height
        }
        
        if firstTime {
            self.animationNode?.play()
        }
    }
}
