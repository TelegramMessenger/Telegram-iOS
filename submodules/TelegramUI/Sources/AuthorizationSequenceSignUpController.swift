import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import LegacyComponents
import ProgressNavigationButtonNode
import ImageCompression
import LegacyMediaPickerUI

final class AuthorizationSequenceSignUpController: ViewController {
    private var controllerNode: AuthorizationSequenceSignUpControllerNode {
        return self.displayNode as! AuthorizationSequenceSignUpControllerNode
    }
    
    private let presentationData: PresentationData
    private let back: () -> Void
    
    var initialName: (String, String) = ("", "")
    private var termsOfService: UnauthorizedAccountTermsOfService?
    
    var signUpWithName: ((String, String, Data?, Any?, TGVideoEditAdjustments?) -> Void)?
    
    var avatarAsset: Any?
    var avatarAdjustments: TGVideoEditAdjustments?
    
    private let hapticFeedback = HapticFeedback()
    
    var inProgress: Bool = false {
        didSet {
            if self.inProgress {
                let item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: self.presentationData.theme.rootController.navigationBar.accentTextColor))
                self.navigationItem.rightBarButtonItem = item
            } else {
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Next, style: .done, target: self, action: #selector(self.nextPressed))
            }
            self.controllerNode.inProgress = self.inProgress
        }
    }
    
    init(presentationData: PresentationData, back: @escaping () -> Void, displayCancel: Bool) {
        self.presentationData = presentationData
        self.back = back
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: AuthorizationSequenceController.navigationBarTheme(presentationData.theme), strings: NavigationBarStrings(presentationStrings: presentationData.strings)))
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.statusBar.statusBarStyle = presentationData.theme.intro.statusBarStyle.style
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Next, style: .done, target: self, action: #selector(self.nextPressed))
        
        self.attemptNavigation = { _ in
            return false
        }
        self.navigationBar?.backPressed = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: presentationData.strings.Login_CancelSignUpConfirmation, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Login_CancelPhoneVerificationContinue, action: {
            }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Login_CancelPhoneVerificationStop, action: {
                back()
            })]), in: .window(.root))
        }
        
        if displayCancel {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func cancelPressed() {
        self.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: self.presentationData), title: nil, text: self.presentationData.strings.Login_CancelSignUpConfirmation, actions: [TextAlertAction(type: .genericAction, title: self.presentationData.strings.Login_CancelPhoneVerificationContinue, action: {
        }), TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Login_CancelPhoneVerificationStop, action: { [weak self] in
            self?.back()
        })]), in: .window(.root))
    }
    
    override public func loadDisplayNode() {
        let currentAvatarMixin = Atomic<NSObject?>(value: nil)
        
        self.displayNode = AuthorizationSequenceSignUpControllerNode(theme: self.presentationData.theme, strings: self.presentationData.strings, addPhoto: { [weak self] in
            presentLegacyAvatarPicker(holder: currentAvatarMixin, signup: false, theme: defaultPresentationTheme, present: { c, a in
                self?.view.endEditing(true)
                self?.present(c, in: .window(.root), with: a)
            }, openCurrent: nil, completion: { image in
                self?.controllerNode.currentPhoto = image
                self?.avatarAsset = nil
                self?.avatarAdjustments = nil
            }, videoCompletion: { image, asset, adjustments in
                self?.controllerNode.currentPhoto = image
                self?.avatarAsset = asset
                self?.avatarAdjustments = adjustments
            })
        })
        self.displayNodeDidLoad()
        
        self.controllerNode.view.disableAutomaticKeyboardHandling = [.forward, .backward]
        
        self.controllerNode.signUpWithName = { [weak self] _, _ in
            self?.nextPressed()
        }
        self.controllerNode.openTermsOfService = { [weak self] in
            guard let strongSelf = self, let termsOfService = strongSelf.termsOfService else {
                return
            }
            strongSelf.view.endEditing(true)
            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: strongSelf.presentationData.strings.Login_TermsOfServiceHeader, text: termsOfService.text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
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
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    @objc func nextPressed() {
        let firstName = self.controllerNode.currentName.0.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastName = self.controllerNode.currentName.1.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var name: (String, String)?
        if firstName.isEmpty && lastName.isEmpty {
            self.hapticFeedback.error()
            self.controllerNode.animateError()
            return
        } else if firstName.isEmpty && !lastName.isEmpty {
            name = (lastName, "")
        } else {
            name = (firstName, lastName)
        }
        
        if let name = name {
            self.signUpWithName?(name.0, name.1, self.controllerNode.currentPhoto.flatMap({ image in
                return compressImageToJPEG(image, quality: 0.7)
            }), self.avatarAsset, self.avatarAdjustments)
        }
    }
}
