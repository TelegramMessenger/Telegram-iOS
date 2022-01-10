import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import TelegramPresentationData
import TextFormat
import AccountContext
import AlertUI
import PresentationDataUtils
import AppBundle
import Markdown
import PhoneNumberFormat

private final class ChangePhoneNumberIntroControllerNode: ASDisplayNode {
    var presentationData: PresentationData
    
    let iconNode: ASImageNode
    let labelNode: ASTextNode
    let buttonNode: HighlightableButtonNode
    
    var dismiss: (() -> Void)?
    var action: (() -> Void)?
    
    init(presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.iconNode = ASImageNode()
        self.labelNode = ASTextNode()
        self.buttonNode = HighlightableButtonNode()
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Settings/ChangePhoneIntroIcon"), color: presentationData.theme.list.freeMonoIconColor)
        let textColor = self.presentationData.theme.list.freeTextColor
        self.labelNode.attributedText = parseMarkdownIntoAttributedString(self.presentationData.strings.PhoneNumberHelp_Help, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: Font.regular(14.0), textColor: textColor), bold: MarkdownAttributeSet(font: Font.semibold(14.0), textColor: textColor), link: MarkdownAttributeSet(font: Font.regular(14.0), textColor: textColor), linkAttribute: { _ in return nil }), textAlignment: .center)
        self.buttonNode.setTitle(self.presentationData.strings.PhoneNumberHelp_ChangeNumber, with: Font.regular(19.0), with: self.presentationData.theme.list.itemAccentColor, for: .normal)
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.labelNode)
        self.addSubnode(self.buttonNode)
        
        self.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
    }
    
    func animateIn() {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut() {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.dismiss?()
            }
        })
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        var insets = layout.insets(options: [.statusBar])
        insets.top += navigationBarHeight
        let availableHeight = layout.size.height - insets.top - insets.bottom
        
        let largeScreen = availableHeight >= 420.0
        let contentHeight: CGFloat = largeScreen ? 420.0 : 400.0
        
        let iconSize = self.iconNode.measure(CGSize(width: 400.0, height: 400.0))
        let labelSize = self.labelNode.updateLayout(CGSize(width: 295.0, height: CGFloat.greatestFiniteMagnitude))
        let buttonSize = self.buttonNode.measure(CGSize(width: 295.0, height: CGFloat.greatestFiniteMagnitude))
        
        transition.updateFrame(node: self.iconNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - iconSize.width) / 2.0), y: insets.top + floor((availableHeight - contentHeight) / 2.0) + floor(iconSize.height * (largeScreen ? CGFloat(0.2) : CGFloat(0.5)))), size: iconSize))
        
        transition.updateFrame(node: self.labelNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - labelSize.width) / 2.0), y: insets.top + floor((availableHeight - contentHeight) / 2.0) + floor((contentHeight - labelSize.height) / 2.0) + floor((contentHeight - iconSize.height - buttonSize.height) * 0.11)), size: labelSize))
        
        transition.updateFrame(node: self.buttonNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - buttonSize.width) / 2.0), y: insets.top + floor((availableHeight - contentHeight) / 2.0) + contentHeight - buttonSize.height), size: buttonSize))
    }
    
    @objc func buttonPressed() {
        self.action?()
    }
}

public final class ChangePhoneNumberIntroController: ViewController {
    private let context: AccountContext
    private var didPlayPresentationAnimation = false
    
    private var presentationData: PresentationData
    
    public init(context: AccountContext, phoneNumber: String) {
        self.context = context
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        let formattedPhone = formatPhoneNumber(phoneNumber)
        self.title = formattedPhone
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        //self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(self.cancelPressed))
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func loadDisplayNode() {
        self.displayNode = ChangePhoneNumberIntroControllerNode(presentationData: self.presentationData)
        (self.displayNode as! ChangePhoneNumberIntroControllerNode).dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        (self.displayNode as! ChangePhoneNumberIntroControllerNode).action = { [weak self] in
            self?.proceed()
        }
        self.displayNodeDidLoad()
        
        self.navigationBar?.updateBackgroundAlpha(0.0, transition: .immediate)
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        /*if !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            (self.displayNode as! ChangePhoneNumberIntroControllerNode).animateIn()
        }*/
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        (self.displayNode as! ChangePhoneNumberIntroControllerNode).containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    @objc func cancelPressed() {
        (self.displayNode as! ChangePhoneNumberIntroControllerNode).animateOut()
    }
    
    func proceed() {
        self.present(textAlertController(context: self.context, title: nil, text: self.presentationData.strings.PhoneNumberHelp_Alert, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: self.presentationData.strings.TwoFactorSetup_Email_Action, action: { [weak self] in
            if let strongSelf = self {
                (strongSelf.navigationController as? NavigationController)?.replaceTopController(ChangePhoneNumberController(context: strongSelf.context), animated: true)
            }
        })]), in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }
}
