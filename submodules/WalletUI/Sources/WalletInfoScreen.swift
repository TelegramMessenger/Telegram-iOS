import Foundation
import UIKit
import AppBundle
import AccountContext
import TelegramPresentationData
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SolidRoundedButtonNode
import AnimationUI
import SwiftSignalKit

public final class WalletInfoScreen: ViewController {
    private let context: AccountContext
    private let tonContext: TonContext
    private let walletInfo: WalletInfo
    private let address: String
    
    private var presentationData: PresentationData
    
    public init(context: AccountContext, tonContext: TonContext, walletInfo: WalletInfo, address: String) {
        self.context = context
        self.tonContext = tonContext
        self.walletInfo = walletInfo
        self.address = address
        
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
        self.displayNode = WalletInfoScreenNode(account: self.context.account, tonContext: self.tonContext, presentationData: self.presentationData, walletInfo: self.walletInfo, address: self.address, exportAction: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            let _ = (walletRestoreWords(network: strongSelf.context.account.network, walletInfo: strongSelf.walletInfo, tonInstance: strongSelf.tonContext.instance, keychain: strongSelf.tonContext.keychain)
            |> deliverOnMainQueue).start(next: { wordList in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.push(WalletWordDisplayScreen(context: strongSelf.context, tonContext: strongSelf.tonContext, walletInfo: strongSelf.walletInfo, wordList: wordList))
            }, error: { _ in
                guard let strongSelf = self else {
                    return
                }
            })
        })
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        (self.displayNode as! WalletInfoScreenNode).containerLayoutUpdated(layout: layout, navigationHeight: self.navigationHeight, transition: transition)
    }
}

private final class WalletInfoScreenNode: ViewControllerTracingNode {
    private var presentationData: PresentationData
    private let walletInfo: WalletInfo
    private let exportAction: () -> Void
    
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let buttonNode: SolidRoundedButtonNode
    
    var inProgress: Bool = false {
        didSet {
            self.buttonNode.isUserInteractionEnabled = !self.inProgress
            self.buttonNode.alpha = self.inProgress ? 0.6 : 1.0
        }
    }
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    private let balanceDisposable = MetaDisposable()
    
    init(account: Account, tonContext: TonContext, presentationData: PresentationData, walletInfo: WalletInfo, address: String, exportAction: @escaping () -> Void) {
        self.presentationData = presentationData
        self.walletInfo = walletInfo
        self.exportAction = exportAction
        
        let addressString = Data(base64Encoded: walletInfo.publicKey.rawValue).flatMap({ String(data: $0, encoding: .utf8) }) ?? ""
        
        let title: String = address
        let text: String = "..."
        let buttonText: String = "Export"
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.bold(32.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.textAlignment = .center
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(16.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        self.textNode.maximumNumberOfLines = 0
        self.textNode.textAlignment = .center
        
        self.buttonNode = SolidRoundedButtonNode(title: buttonText, theme: self.presentationData.theme, height: 50.0, cornerRadius: 10.0, gloss: true)
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.pressed = {
            exportAction()
        }
        
        self.balanceDisposable.set((currentWalletBalance(publicKey: walletInfo.publicKey, tonInstance: tonContext.instance)
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            strongSelf.textNode.attributedText = NSAttributedString(string: "\(value)", font: Font.regular(16.0), textColor: strongSelf.presentationData.theme.list.itemPrimaryTextColor)
            if let (layout, navigationHeight) = strongSelf.validLayout {
                strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate)
            }
        }))
    }
    
    func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationHeight)
        
        let sideInset: CGFloat = 32.0
        let buttonSideInset: CGFloat = 48.0
        let titleSpacing: CGFloat = 10.0
        let termsSpacing: CGFloat = 10.0
        let buttonHeight: CGFloat = 50.0
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0, height: layout.size.height))
        let textSize = self.textNode.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0, height: layout.size.height))
        
        let contentHeight = titleSize.height + titleSpacing + textSize.height
        let contentVerticalOrigin = floor((layout.size.height - contentHeight) / 2.0)
        
        let titleFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - titleSize.width) / 2.0), y: contentVerticalOrigin), size: titleSize)
        transition.updateFrameAdditive(node: self.titleNode, frame: titleFrame)
        let textFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - textSize.width) / 2.0), y: titleFrame.maxY + titleSpacing), size: textSize)
        transition.updateFrameAdditive(node: self.textNode, frame: textFrame)
        
        let minimalBottomInset: CGFloat = 60.0
        let bottomInset = layout.intrinsicInsets.bottom + minimalBottomInset
        
        let buttonWidth = layout.size.width - buttonSideInset * 2.0
        
        let buttonFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - buttonWidth) / 2.0), y: layout.size.height - bottomInset - buttonHeight), size: CGSize(width: buttonWidth, height: buttonHeight))
        transition.updateFrame(node: self.buttonNode, frame: buttonFrame)
        self.buttonNode.updateLayout(width: buttonFrame.width, transition: transition)
    }
}
