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
import CheckNode

public final class FalseBottomRequirementsScreen: ViewController {
    private let presentationData: PresentationData
    
    var buttonPressed: (() -> Void)?
    var setMasterPassword: (() -> Void)?
    var createAnotherAccount: (() -> Void)?
    
    public init(presentationData: PresentationData) {
        self.presentationData = presentationData
        
        let defaultTheme = NavigationBarTheme(rootControllerTheme: self.presentationData.theme)
        let navigationBarTheme = NavigationBarTheme(buttonColor: defaultTheme.buttonColor, disabledButtonColor: defaultTheme.disabledButtonColor, primaryTextColor: defaultTheme.primaryTextColor, backgroundColor: .clear, separatorColor: .clear, badgeBackgroundColor: defaultTheme.badgeBackgroundColor, badgeStrokeColor: defaultTheme.badgeStrokeColor, badgeTextColor: defaultTheme.badgeTextColor)
        
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
        self.displayNode = FalseBottomRequirementsScreenNode(presentationData: self.presentationData, action: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.buttonPressed?()
        })
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        (self.displayNode as! FalseBottomRequirementsScreenNode).containerLayoutUpdated(layout: layout, navigationHeight: self.navigationHeight, transition: transition)
    }
}

private final class FalseBottomRequirementsScreenNode: ViewControllerTracingNode {
    private let presentationData: PresentationData
    
    private let openAccountTextNode: ImmediateTextNode
    private let masterPasscodeTextNode: ImmediateTextNode
    let openAccountCheckNode: CheckNode
    let masterPasswordCheckNode: CheckNode
    let buttonNode: SolidRoundedButtonNode
    
    var inProgress: Bool = false {
        didSet {
            self.buttonNode.isUserInteractionEnabled = !self.inProgress
            self.buttonNode.alpha = self.inProgress ? 0.6 : 1.0
        }
    }
    
    init(presentationData: PresentationData, action: @escaping () -> Void) {
        self.presentationData = presentationData
        
        let title: NSAttributedString
        let text: NSAttributedString
        let buttonText: String
        
        let textFont = Font.regular(16.0)
        let textColor = self.presentationData.theme.list.itemPrimaryTextColor

        title = NSAttributedString(string: "There is at least one open account on this device", font: textFont, textColor: textColor)
        text = NSAttributedString(string: "Master passcode is set up", font: textFont, textColor: textColor)
        buttonText = "Continue"
        
        self.openAccountTextNode = ImmediateTextNode()
        self.openAccountTextNode.displaysAsynchronously = false
        self.openAccountTextNode.attributedText = title
        self.openAccountTextNode.maximumNumberOfLines = 0
        self.openAccountTextNode.lineSpacing = 0.1
        self.openAccountTextNode.textAlignment = .left
        
        self.masterPasscodeTextNode = ImmediateTextNode()
        self.masterPasscodeTextNode.displaysAsynchronously = false
        self.masterPasscodeTextNode.attributedText = text
        self.masterPasscodeTextNode.maximumNumberOfLines = 0
        self.masterPasscodeTextNode.lineSpacing = 0.1
        self.masterPasscodeTextNode.textAlignment = .left
        
        self.buttonNode = SolidRoundedButtonNode(title: buttonText, theme: SolidRoundedButtonTheme(backgroundColor: self.presentationData.theme.list.itemCheckColors.fillColor, foregroundColor: self.presentationData.theme.list.itemCheckColors.foregroundColor), height: 50.0, cornerRadius: 10.0, gloss: false)
        self.buttonNode.isHidden = buttonText.isEmpty
        
        self.openAccountCheckNode = CheckNode(strokeColor: presentationData.theme.list.itemCheckColors.strokeColor, fillColor: presentationData.theme.list.itemSwitchColors.positiveColor, foregroundColor: presentationData.theme.list.itemCheckColors.foregroundColor, style: .plain)
        
        self.masterPasswordCheckNode = CheckNode(strokeColor: presentationData.theme.list.itemCheckColors.strokeColor, fillColor: presentationData.theme.list.itemSwitchColors.positiveColor, foregroundColor: presentationData.theme.list.itemCheckColors.foregroundColor, style: .plain)
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        self.addSubnode(self.openAccountTextNode)
        self.addSubnode(self.masterPasscodeTextNode)
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.openAccountCheckNode)
        self.addSubnode(self.masterPasswordCheckNode)
        
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
        let titleSpacing: CGFloat = 19.0
        let buttonHeight: CGFloat = 50.0
        let checkSize = CGSize(width: 32.0, height: 32.0)
        
        let titleSize = self.openAccountTextNode.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0 - checkSize.width, height: layout.size.height))
        let textSize = self.masterPasscodeTextNode.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0 - checkSize.width, height: layout.size.height))
        
        let contentHeight = titleSize.height + titleSpacing + textSize.height
        var contentVerticalOrigin = floor((layout.size.height - contentHeight / 2.0) / 2.0)
        
        let minimalBottomInset: CGFloat = 60.0
        let bottomInset = layout.intrinsicInsets.bottom + minimalBottomInset
        
        let buttonWidth = layout.size.width - buttonSideInset * 2.0
        
        let buttonFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - buttonWidth) / 2.0), y: layout.size.height - bottomInset - buttonHeight), size: CGSize(width: buttonWidth, height: buttonHeight))
        transition.updateFrame(node: self.buttonNode, frame: buttonFrame)
        self.buttonNode.updateLayout(width: buttonFrame.width, transition: transition)
        
        var maxContentVerticalOrigin = buttonFrame.minY - 12.0 - contentHeight
        
        contentVerticalOrigin = min(contentVerticalOrigin, maxContentVerticalOrigin)
        
        
        let titleFrame = CGRect(origin: CGPoint(x: sideInset + checkSize.width, y: contentVerticalOrigin), size: titleSize)
        transition.updateFrameAdditive(node: self.openAccountTextNode, frame: titleFrame)
        
        let textFrame = CGRect(origin: CGPoint(x: sideInset + checkSize.width, y: titleFrame.maxY + titleSpacing), size: textSize)
        transition.updateFrameAdditive(node: self.masterPasscodeTextNode, frame: textFrame)
        
        let openAccountCheckFrame = CGRect(origin: CGPoint(x: sideInset, y: titleFrame.midY - checkSize.width / 2), size: checkSize)
        transition.updateFrameAdditive(node: self.openAccountCheckNode, frame: openAccountCheckFrame)
        
        let masterPasswordCheckFrame = CGRect(origin: CGPoint(x: sideInset, y: textFrame.midY - checkSize.width / 2), size: checkSize)
        transition.updateFrameAdditive(node: self.masterPasswordCheckNode, frame: masterPasswordCheckFrame)
    }
}
