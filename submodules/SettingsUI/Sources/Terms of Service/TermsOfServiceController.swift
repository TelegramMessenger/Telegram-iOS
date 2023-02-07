import Foundation
import UIKit
import TelegramCore
import Postbox
import SwiftSignalKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import TelegramUIPreferences
import ProgressNavigationButtonNode

public class TermsOfServiceControllerTheme {
    public let statusBarStyle: StatusBarStyle
    public let navigationBackground: UIColor
    public let navigationSeparator: UIColor
    public let listBackground: UIColor
    public let itemBackground: UIColor
    public let itemSeparator: UIColor
    public let primary: UIColor
    public let accent: UIColor
    public let disabled: UIColor
    
    public init(statusBarStyle: StatusBarStyle, navigationBackground: UIColor, navigationSeparator: UIColor, listBackground: UIColor, itemBackground: UIColor, itemSeparator: UIColor, primary: UIColor, accent: UIColor, disabled: UIColor) {
        self.statusBarStyle = statusBarStyle
        self.navigationBackground = navigationBackground
        self.navigationSeparator = navigationSeparator
        self.listBackground = listBackground
        self.itemBackground = itemBackground
        self.itemSeparator = itemSeparator
        self.primary = primary
        self.accent = accent
        self.disabled = disabled
    }
}

public extension TermsOfServiceControllerTheme {
    convenience init(presentationTheme: PresentationTheme) {
        self.init(statusBarStyle: presentationTheme.rootController.statusBarStyle.style, navigationBackground: presentationTheme.rootController.navigationBar.opaqueBackgroundColor, navigationSeparator: presentationTheme.rootController.navigationBar.separatorColor, listBackground: presentationTheme.list.blocksBackgroundColor, itemBackground: presentationTheme.list.itemBlocksBackgroundColor, itemSeparator: presentationTheme.list.itemBlocksSeparatorColor, primary: presentationTheme.list.itemPrimaryTextColor, accent: presentationTheme.list.itemAccentColor, disabled: presentationTheme.rootController.navigationBar.disabledButtonColor)
    }
}

public class TermsOfServiceController: ViewController, StandalonePresentableController {
    private var controllerNode: TermsOfServiceControllerNode {
        return self.displayNode as! TermsOfServiceControllerNode
    }

    private let presentationData: PresentationData
    private let text: String
    private let entities: [MessageTextEntity]
    private let ageConfirmation: Int32?
    private let signingUp: Bool
    private let accept: (String?) -> Void
    private let decline: () -> Void
    private let openUrl: (String) -> Void
    private var proccessBotNameAfterAccept: String? = nil
    
    private var didPlayPresentationAnimation = false
    
    public var inProgress: Bool = false {
        didSet {
            if self.inProgress {
                let item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: self.presentationData.theme.list.itemAccentColor))
                self.navigationItem.rightBarButtonItem = item
            } else {
                self.navigationItem.rightBarButtonItem = nil
            }
            self.controllerNode.inProgress = self.inProgress
        }
    }
    
    public init(presentationData: PresentationData, text: String, entities: [MessageTextEntity], ageConfirmation: Int32?, signingUp: Bool, accept: @escaping (String?) -> Void, decline: @escaping () -> Void, openUrl: @escaping (String) -> Void) {
        self.presentationData = presentationData
        self.text = text
        self.entities = entities
        self.ageConfirmation = ageConfirmation
        self.signingUp = signingUp
        self.accept = accept
        self.decline = decline
        self.openUrl = openUrl
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(rootControllerTheme: presentationData.theme), strings: NavigationBarStrings(back: presentationData.strings.Common_Back, close: presentationData.strings.Common_Close)))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.title = self.presentationData.strings.Login_TermsOfServiceHeader
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.scrollToTop = { [weak self] in
            self?.controllerNode.scrollToTop()
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    override public func loadDisplayNode() {
        self.displayNode = TermsOfServiceControllerNode(presentationData: self.presentationData, text: self.text, entities: self.entities, ageConfirmation: self.ageConfirmation, leftAction: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            let text: String
            let declineTitle: String
            if strongSelf.signingUp {
                text = strongSelf.presentationData.strings.Login_TermsOfServiceSignupDecline
                declineTitle = strongSelf.presentationData.strings.Login_TermsOfServiceDecline
            } else {
                text = strongSelf.presentationData.strings.PrivacyPolicy_DeclineMessage
                declineTitle = strongSelf.presentationData.strings.PrivacyPolicy_DeclineDeclineAndDelete
            }
            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: strongSelf.presentationData.strings.PrivacyPolicy_Decline, text: text, actions: [TextAlertAction(type: .destructiveAction, title: declineTitle, action: {
                self?.decline()
            }), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {
            })], actionLayout: .vertical), in: .window(.root))
        }, rightAction: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            if let ageConfirmation = strongSelf.ageConfirmation {
                strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: strongSelf.presentationData.strings.PrivacyPolicy_AgeVerificationTitle, text: strongSelf.presentationData.strings.PrivacyPolicy_AgeVerificationMessage("\(ageConfirmation)").string, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.PrivacyPolicy_AgeVerificationAgree, action: {
                    self?.accept(self?.proccessBotNameAfterAccept)
                })]), in: .window(.root))
            } else {
                strongSelf.accept(self?.proccessBotNameAfterAccept)
            }
        }, openUrl: self.openUrl, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        }, setToProcceedBot: { [weak self] botName in
            self?.proccessBotNameAfterAccept = botName
        })
        
        self.displayNodeDidLoad()
    }
    
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            self.controllerNode.animateIn()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.animateOut(completion: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
            completion?()
        })
    }
}
