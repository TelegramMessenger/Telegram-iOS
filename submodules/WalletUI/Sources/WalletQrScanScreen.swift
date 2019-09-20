import Foundation
import UIKit
import AppBundle
import AccountContext
import TelegramPresentationData
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import AlertUI

public final class WalletQrScanScreen: ViewController {
    private let context: AccountContext
    private let tonContext: TonContext
    private var presentationData: PresentationData
    
    public init(context: AccountContext, tonContext: TonContext) {
        self.context = context
        self.tonContext = tonContext
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let defaultNavigationPresentationData = NavigationBarPresentationData(presentationTheme: self.presentationData.theme, presentationStrings: self.presentationData.strings)
        let navigationBarTheme = NavigationBarTheme(buttonColor: defaultNavigationPresentationData.theme.buttonColor, disabledButtonColor: defaultNavigationPresentationData.theme.disabledButtonColor, primaryTextColor: defaultNavigationPresentationData.theme.primaryTextColor, backgroundColor: .clear, separatorColor: .clear, badgeBackgroundColor: defaultNavigationPresentationData.theme.badgeBackgroundColor, badgeStrokeColor: defaultNavigationPresentationData.theme.badgeStrokeColor, badgeTextColor: defaultNavigationPresentationData.theme.badgeTextColor)
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: navigationBarTheme, strings: defaultNavigationPresentationData.strings))
        
        self.navigationPresentation = .modalInLargeLayout
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.navigationBar?.intrinsicCanTransitionInline = false
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func backPressed() {
        self.dismiss()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = WalletQrScanScreenNode(presentationData: self.presentationData)
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        (self.displayNode as! WalletQrScanScreenNode).containerLayoutUpdated(layout: layout, navigationHeight: self.navigationHeight, transition: transition)
    }
}

private final class WalletQrScanScreenNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private var presentationData: PresentationData
    
    private let navigationBackgroundNode: ASDisplayNode
    private let navigationSeparatorNode: ASDisplayNode
    private let navigationTitleNode: ImmediateTextNode
    private let scrollNode: ASScrollNode
    private let iconNode: ASImageNode
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    
    private var navigationHeight: CGFloat?
    
    init(presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.navigationBackgroundNode = ASDisplayNode()
        self.navigationBackgroundNode.backgroundColor = self.presentationData.theme.rootController.navigationBar.backgroundColor
        self.navigationBackgroundNode.alpha = 0.0
        self.navigationSeparatorNode = ASDisplayNode()
        self.navigationSeparatorNode.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
        
        self.scrollNode = ASScrollNode()
        
        self.iconNode = ASImageNode()
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        
        let title: String = "24 Secret Words"
        let text: String = "Write down these 24 words in the correct order and store them in a secret place.\n\nUse these secret words to restore access to your wallet if you lose your passcode or Telegram account."
        let buttonText: String = "Done"
        
        self.iconNode.image = UIImage(bundleImageName: "Settings/Wallet/WordsDisplayIcon")
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.bold(32.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.textAlignment = .center
        
        self.navigationTitleNode = ImmediateTextNode()
        self.navigationTitleNode.displaysAsynchronously = false
        self.navigationTitleNode.attributedText = NSAttributedString(string: title, font: Font.bold(17.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        self.navigationTitleNode.maximumNumberOfLines = 0
        self.navigationTitleNode.textAlignment = .center
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(16.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        self.textNode.maximumNumberOfLines = 0
        self.textNode.lineSpacing = 0.1
        self.textNode.textAlignment = .center
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        self.addSubnode(self.scrollNode)
        
        self.scrollNode.addSubnode(self.iconNode)
        self.scrollNode.addSubnode(self.titleNode)
        self.scrollNode.addSubnode(self.textNode)

        self.navigationBackgroundNode.addSubnode(self.navigationSeparatorNode)
        self.navigationBackgroundNode.addSubnode(self.navigationTitleNode)
        self.addSubnode(self.navigationBackgroundNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.scrollNode.view.alwaysBounceVertical = false
        self.scrollNode.view.showsVerticalScrollIndicator = false
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        self.scrollNode.view.delegate = self
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let navigationHeight = self.navigationHeight ?? 0.0
        let alpha: CGFloat = scrollView.contentOffset.y >= (self.titleNode.frame.maxY - navigationHeight) ? 1.0 : 0.0
        if self.navigationBackgroundNode.alpha != alpha {
            let transition: ContainedViewLayoutTransition = .animated(duration: 0.12, curve: .easeInOut)
            transition.updateAlpha(node: self.navigationBackgroundNode, alpha: alpha, beginWithCurrentState: true)
        }
    }
    
    func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.navigationHeight = navigationHeight
        
        let sideInset: CGFloat = 32.0
        let buttonSideInset: CGFloat = 48.0
        let iconSpacing: CGFloat = 5.0
        let titleSpacing: CGFloat = 19.0
        let textSpacing: CGFloat = 37.0
        let buttonHeight: CGFloat = 50.0
        let buttonSpacing: CGFloat = 45.0
        let wordSpacing: CGFloat = 12.0
        let indexSpacing: CGFloat = 4.0
        
        transition.updateFrame(node: self.navigationBackgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: navigationHeight)))
        transition.updateFrame(node: self.navigationSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationHeight), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
        
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let iconSize = self.iconNode.image?.size ?? CGSize(width: 50.0, height: 50.0)
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0, height: layout.size.height))
        let navigationTitleSize = self.navigationTitleNode.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0, height: layout.size.height))
        let textSize = self.textNode.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0, height: layout.size.height))
        
        var contentHeight: CGFloat = 0.0
        
        let contentVerticalOrigin = navigationHeight + 10.0
        
        let iconFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - iconSize.width) / 2.0), y: contentVerticalOrigin), size: iconSize)
        transition.updateFrameAdditive(node: self.iconNode, frame: iconFrame)
        let titleFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - titleSize.width) / 2.0), y: iconFrame.maxY + iconSpacing), size: titleSize)
        transition.updateFrameAdditive(node: self.titleNode, frame: titleFrame)
        let textFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - textSize.width) / 2.0), y: titleFrame.maxY + titleSpacing), size: textSize)
        transition.updateFrameAdditive(node: self.textNode, frame: textFrame)
        
        transition.updateFrameAdditive(node: self.navigationTitleNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - navigationTitleSize.width) / 2.0), y: navigationHeight - 44.0 + floor((44.0 - navigationTitleSize.height) / 2.0)), size: navigationTitleSize))
        
        contentHeight = textFrame.maxY + textSpacing
    }
}
