import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore

import LegacyComponents

final class AuthorizationSequenceSignUpController: ViewController {
    private var controllerNode: AuthorizationSequenceSignUpControllerNode {
        return self.displayNode as! AuthorizationSequenceSignUpControllerNode
    }
    
    private let strings: PresentationStrings
    private let theme: AuthorizationTheme
    
    var initialName: (String, String) = ("", "")
    private var termsOfService: UnauthorizedAccountTermsOfService?
    
    var signUpWithName: ((String, String, Data?) -> Void)?
    
    private let hapticFeedback = HapticFeedback()
    
    var inProgress: Bool = false {
        didSet {
            if self.inProgress {
                let item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: self.theme.accentColor))
                self.navigationItem.rightBarButtonItem = item
            } else {
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.strings.Common_Next, style: .done, target: self, action: #selector(self.nextPressed))
            }
            self.controllerNode.inProgress = self.inProgress
        }
    }
    
    init(strings: PresentationStrings, theme: AuthorizationTheme) {
        self.strings = strings
        self.theme = theme
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: AuthorizationSequenceController.navigationBarTheme(theme), strings: NavigationBarStrings(presentationStrings: strings)))
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.statusBar.statusBarStyle = self.theme.statusBarStyle
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.strings.Common_Next, style: .done, target: self, action: #selector(self.nextPressed))
        
        self.attemptNavigation = { [weak self] f in
            guard let strongSelf = self else {
                return true
            }
            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(authTheme: theme), title: nil, text: strings.Login_CancelSignUpConfirmation, actions: [TextAlertAction(type: .genericAction, title: strings.Login_CancelPhoneVerificationContinue, action: {
            }), TextAlertAction(type: .defaultAction, title: strings.Login_CancelPhoneVerificationStop, action: {
                f()
            })]), in: .window(.root))
            return false
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        let currentAvatarMixin = Atomic<NSObject?>(value: nil)
        
        self.displayNode = AuthorizationSequenceSignUpControllerNode(theme: self.theme, strings: self.strings, addPhoto: { [weak self] in
            presentLegacyAvatarPicker(holder: currentAvatarMixin, signup: true, theme: defaultPresentationTheme, present: { c, a in
                self?.view.endEditing(true)
                self?.present(c, in: .window(.root), with: a)
            }, completion: { image in
                self?.controllerNode.currentPhoto = image
            })
        })
        self.displayNodeDidLoad()
        
        self.controllerNode.signUpWithName = { [weak self] _, _ in
            self?.nextPressed()
        }
        self.controllerNode.openTermsOfService = { [weak self] in
            guard let strongSelf = self, let termsOfService = strongSelf.termsOfService else {
                return
            }
            strongSelf.view.endEditing(true)
            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: defaultPresentationTheme), title: strongSelf.strings.Login_TermsOfServiceHeader, text: termsOfService.text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_OK, action: {})]), in: .window(.root))
        }
        
        self.controllerNode.updateData(firstName: self.initialName.0, lastName: self.initialName.1, hasTermsOfService: self.termsOfService != nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.controllerNode.activateInput()
    }
    
    func updateData(firstName: String, lastName: String, termsOfService: UnauthorizedAccountTermsOfService?) {
        if self.isNodeLoaded {
            if (firstName, lastName) != self.controllerNode.currentName || self.termsOfService != termsOfService {
                self.termsOfService = termsOfService
                self.controllerNode.updateData(firstName: firstName, lastName: lastName, hasTermsOfService: termsOfService != nil)
            }
        } else {
            self.initialName = (firstName, lastName)
            self.termsOfService = termsOfService
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    @objc func nextPressed() {
        if self.controllerNode.currentName.0.isEmpty {
            hapticFeedback.error()
            self.controllerNode.animateError()
        } else {
            let name = self.controllerNode.currentName
            
            self.signUpWithName?(name.0, name.1, self.controllerNode.currentPhoto.flatMap({ image in
                return compressImageToJPEG(image, quality: 0.7)
            }))
        }
    }
}
