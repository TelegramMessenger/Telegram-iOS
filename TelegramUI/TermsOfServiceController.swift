import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import Display
import AsyncDisplayKit

public class TermsOfServiceController: ViewController {
    private var controllerNode: TermsOfServiceControllerNode {
        return self.displayNode as! TermsOfServiceControllerNode
    }

    private let theme: PresentationTheme
    private let strings: PresentationStrings
    private let text: String
    private let entities: [MessageTextEntity]
    private let ageConfirmation: Int32?
    private let signingUp: Bool
    private let accept: () -> Void
    private let decline: () -> Void
    private let openUrl: (String) -> Void
    
    private var didPlayPresentationAnimation = false
    
    public var inProgress: Bool = false {
        didSet {
            if self.inProgress {
                let item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: self.theme.rootController.navigationBar.accentTextColor))
                self.navigationItem.rightBarButtonItem = item
            } else {
                self.navigationItem.rightBarButtonItem = nil
            }
            self.controllerNode.inProgress = self.inProgress
        }
    }
    
    public init(theme: PresentationTheme, strings: PresentationStrings, text: String, entities: [MessageTextEntity], ageConfirmation: Int32?, signingUp: Bool, accept: @escaping () -> Void, decline: @escaping () -> Void, openUrl: @escaping (String) -> Void) {
        self.theme = theme
        self.strings = strings
        self.text = text
        self.entities = entities
        self.ageConfirmation = ageConfirmation
        self.signingUp = signingUp
        self.accept = accept
        self.decline = decline
        self.openUrl = openUrl
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(rootControllerTheme: theme), strings: NavigationBarStrings(back: strings.Common_Back, close: strings.Common_Close)))
        
        self.statusBar.statusBarStyle = self.theme.rootController.statusBar.style.style
        
        self.title = self.strings.TermsOfService_Title
        
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
                text = strongSelf.strings.TermsOfService_DeclineUnauthorized
                declineTitle = strongSelf.strings.TermsOfService_Decline
            } else {
                text = strongSelf.strings.TermsOfService_DeclineAuthorized
                declineTitle = strongSelf.strings.TermsOfService_DeclineAndDelete
            }
            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.theme), title: strongSelf.strings.TermsOfService_Decline, text: text, actions: [TextAlertAction(type: .destructiveAction, title: declineTitle, action: {
                self?.decline()
            }), TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_Cancel, action: {
            })], actionLayout: .vertical), in: .window(.root))
        }, rightAction: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            if let ageConfirmation = strongSelf.ageConfirmation {
                strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.theme), title: strongSelf.strings.TermsOfService_AgeVerificationTitle, text: strongSelf.strings.TermsOfService_AgeVerificationText(Int(ageConfirmation)).0, actions: [TextAlertAction(type: .genericAction, title: strongSelf.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: strongSelf.strings.TermsOfService_Confirm, action: {
                    self?.accept()
                })]), in: .window(.root))
            } else {
                strongSelf.accept()
            }
        }, openUrl: self.openUrl, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
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
