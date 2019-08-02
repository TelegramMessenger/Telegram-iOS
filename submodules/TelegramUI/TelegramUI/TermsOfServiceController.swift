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
        self.init(statusBarStyle: presentationTheme.rootController.statusBarStyle.style, navigationBackground: presentationTheme.rootController.navigationBar.backgroundColor, navigationSeparator: presentationTheme.rootController.navigationBar.separatorColor, listBackground: presentationTheme.list.blocksBackgroundColor, itemBackground: presentationTheme.list.itemBlocksBackgroundColor, itemSeparator: presentationTheme.list.itemBlocksSeparatorColor, primary: presentationTheme.list.itemPrimaryTextColor, accent: presentationTheme.list.itemAccentColor, disabled: presentationTheme.rootController.navigationBar.disabledButtonColor)
    }
    
    var presentationTheme: PresentationTheme {
        let theme: PresentationTheme
        switch itemBackground.argb {
            case defaultPresentationTheme.list.itemBlocksBackgroundColor.argb:
                theme = defaultPresentationTheme
            case defaultDarkPresentationTheme.list.itemBlocksBackgroundColor.argb:
                theme = defaultDarkPresentationTheme
            case defaultDarkAccentPresentationTheme.list.itemBlocksBackgroundColor.argb:
                theme = defaultDarkAccentPresentationTheme
            default:
                theme = defaultPresentationTheme
        }
        return theme
    }
}

public class TermsOfServiceController: ViewController {
    private var controllerNode: TermsOfServiceControllerNode {
        return self.displayNode as! TermsOfServiceControllerNode
    }

    private let theme: TermsOfServiceControllerTheme
    private let strings: PresentationStrings
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
                let item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: self.theme.accent))
                self.navigationItem.rightBarButtonItem = item
            } else {
                self.navigationItem.rightBarButtonItem = nil
            }
            self.controllerNode.inProgress = self.inProgress
        }
    }
    
    public init(theme: TermsOfServiceControllerTheme, strings: PresentationStrings, text: String, entities: [MessageTextEntity], ageConfirmation: Int32?, signingUp: Bool, accept: @escaping (String?) -> Void, decline: @escaping () -> Void, openUrl: @escaping (String) -> Void) {
        self.theme = theme
        self.strings = strings
        self.text = text
        self.entities = entities
        self.ageConfirmation = ageConfirmation
        self.signingUp = signingUp
        self.accept = accept
        self.decline = decline
        self.openUrl = openUrl
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(buttonColor: self.theme.accent, disabledButtonColor: self.theme.disabled, primaryTextColor: self.theme.primary, backgroundColor: self.theme.navigationBackground, separatorColor: self.theme.navigationSeparator, badgeBackgroundColor: .clear, badgeStrokeColor: .clear, badgeTextColor: .clear), strings: NavigationBarStrings(back: strings.Common_Back, close: strings.Common_Close)))
        
        self.statusBar.statusBarStyle = self.theme.statusBarStyle
        
        self.title = self.strings.Login_TermsOfServiceHeader
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.strings.Common_Back, style: .plain, target: nil, action: nil)
        
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
        self.displayNode = TermsOfServiceControllerNode(theme: self.theme, strings: self.strings, text: self.text, entities: self.entities, ageConfirmation: self.ageConfirmation, leftAction: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            let text: String
            let declineTitle: String
            if strongSelf.signingUp {
                text = strongSelf.strings.Login_TermsOfServiceSignupDecline
                declineTitle = strongSelf.strings.Login_TermsOfServiceDecline
            } else {
                text = strongSelf.strings.PrivacyPolicy_DeclineMessage
                declineTitle = strongSelf.strings.PrivacyPolicy_DeclineDeclineAndDelete
            }
            let theme: PresentationTheme = strongSelf.theme.presentationTheme
            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: theme), title: strongSelf.strings.PrivacyPolicy_Decline, text: text, actions: [TextAlertAction(type: .destructiveAction, title: declineTitle, action: {
                self?.decline()
            }), TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_Cancel, action: {
            })], actionLayout: .vertical), in: .window(.root))
        }, rightAction: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            if let ageConfirmation = strongSelf.ageConfirmation {
                let theme: PresentationTheme = strongSelf.theme.presentationTheme
                strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: theme), title: strongSelf.strings.PrivacyPolicy_AgeVerificationTitle, text: strongSelf.strings.PrivacyPolicy_AgeVerificationMessage("\(ageConfirmation)").0, actions: [TextAlertAction(type: .genericAction, title: strongSelf.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: strongSelf.strings.PrivacyPolicy_AgeVerificationAgree, action: {
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
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
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
