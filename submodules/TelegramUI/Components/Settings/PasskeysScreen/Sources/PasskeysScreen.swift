import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import ViewControllerComponent
import BundleIconComponent
import BalancedTextComponent
import MultilineTextComponent
import ButtonComponent
import AccountContext
import AuthenticationServices
import PresentationDataUtils

final class PasskeysScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let displaySkip: Bool
    let initialPasskeysData: [TelegramPasskey]?
    let forceCreate: Bool
    let passkeysDataUpdated: ([TelegramPasskey]) -> Void
    let completion: () -> Void
    let cancel: () -> Void
    
    init(
        context: AccountContext,
        displaySkip: Bool,
        initialPasskeysData: [TelegramPasskey]?,
        forceCreate: Bool,
        passkeysDataUpdated: @escaping ([TelegramPasskey]) -> Void,
        completion: @escaping () -> Void,
        cancel: @escaping () -> Void
    ) {
        self.context = context
        self.displaySkip = displaySkip
        self.initialPasskeysData = initialPasskeysData
        self.forceCreate = forceCreate
        self.passkeysDataUpdated = passkeysDataUpdated
        self.completion = completion
        self.cancel = cancel
    }
    
    static func ==(lhs: PasskeysScreenComponent, rhs: PasskeysScreenComponent) -> Bool {
        return true
    }
    
    class View: UIView, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        private var intro: ComponentView<Empty>?
        private var list: ComponentView<Empty>?
        private var activityIndicator: UIActivityIndicatorView?

        private var component: PasskeysScreenComponent?
        private var environment: EnvironmentType?
        private weak var state: EmptyComponentState?

        private var passkeysData: [TelegramPasskey]?
        private var loadPasskeysDataDisposable: Disposable?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.loadPasskeysDataDisposable?.dispose()
        }
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            Task { @MainActor [weak self] in
                guard let self, let component = self.component else {
                    return
                }
                
                let encodeBase64URL: (Data) -> String = { data in
                    var string = data.base64EncodedString()
                    string = string
                        .replacingOccurrences(of: "+", with: "-")
                        .replacingOccurrences(of: "/", with: "_")
                    string = string.replacingOccurrences(of: "=", with: "")
                    return string
                }
                
                if #available(iOS 17.0, *) {
                    if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
                        if let clientData = String(data: credential.rawClientDataJSON, encoding: .utf8), let attestationObject = credential.rawAttestationObject {
                            let passkey = await component.context.engine.auth.requestCreatePasskey(id: encodeBase64URL(credential.credentialID), clientData: clientData, attestationObject: attestationObject).get()
                            if let passkey {
                                if self.passkeysData == nil {
                                    self.passkeysData = []
                                }
                                self.passkeysData?.insert(passkey, at: 0)
                                component.passkeysDataUpdated(self.passkeysData ?? [])
                                self.state?.updated(transition: .easeInOut(duration: 0.25))
                            }
                        }
                    }
                }
            }
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: any Error) {
            
        }
        
        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            guard let windowScene = self.window?.windowScene else {
                preconditionFailure()
            }
            return ASPresentationAnchor(windowScene: windowScene)
        }

        private func createPasskey() {
            if #available(iOS 15.0, *) {
                Task { @MainActor [weak self] in
                    guard let self, let component = self.component else {
                        return
                    }
                    
                    let decodeBase64: (String) -> Data? = { string in
                        var string = string.replacingOccurrences(of: "-", with: "+")
                            .replacingOccurrences(of: "_", with: "/")
                        while string.count % 4 != 0 {
                            string.append("=")
                        }
                        return Data(base64Encoded: string)
                    }
                    
                    guard let registrationData = await component.context.engine.auth.requestPasskeyRegistration().get()?.data(using: .utf8) else {
                        return
                    }
                    guard let params = try? JSONSerialization.jsonObject(with: registrationData) as? [String: Any] else {
                        return
                    }
                    guard let pkDict = params["publicKey"] as? [String: Any] else {
                        return
                    }
                    guard let rp = pkDict["rp"] as? [String: Any] else {
                        return
                    }
                    guard let relyingPartyIdentifier = rp["id"] as? String else {
                        return
                    }
                    guard let challengeBase64 = pkDict["challenge"] as? String else {
                        return
                    }
                    guard let challengeData = decodeBase64(challengeBase64) else {
                        return
                    }
                    guard let user = pkDict["user"] as? [String: Any] else {
                        return
                    }
                    guard let userIdData = user["id"] as? String else {
                        return
                    }
                    guard let userId = decodeBase64(userIdData) else {
                        return
                    }
                    guard let userName = user["name"] as? String else {
                        return
                    }
                    
                    let platformProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: relyingPartyIdentifier)
                    let platformKeyRequest = platformProvider.createCredentialRegistrationRequest(challenge: challengeData, name: userName, userID: userId)
                    let authController = ASAuthorizationController(authorizationRequests: [platformKeyRequest])
                    authController.delegate = self
                    authController.presentationContextProvider = self
                    authController.performRequests()
                    
                    component.completion()
                }
            }
        }
        
        private func displayDeletePasskey(id: String) {
            guard let component = self.component, let environment = self.environment, let controller = environment.controller() else {
                return
            }
            let alertController = textAlertController(
                context: component.context,
                title: environment.strings.Passkeys_DeleteAlert_Title,
                text: environment.strings.Passkeys_DeleteAlert_Text,
                actions: [
                    TextAlertAction(type: .genericAction, title: environment.strings.Common_Cancel, action: {}),
                    TextAlertAction(type: .destructiveAction, title: environment.strings.Passkeys_DeleteAlert_Action, action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.deletePasskey(id: id)
                    })
                ]
            )
            controller.present(alertController, in: .window(.root))
        }
        
        private func deletePasskey(id: String) {
            guard let component = self.component else {
                return
            }
            guard let passkey = self.passkeysData?.first(where: { $0.id == id }) else {
                return
            }
            let _ = component.context.engine.auth.deletePasskey(id: id).startStandalone()
            
            self.passkeysData?.removeAll(where: { $0.id == id })
            component.passkeysDataUpdated(self.passkeysData ?? [])
            self.state?.updated(transition: .spring(duration: 0.4))
            
            if #available(iOS 26.0, *) {
                Task { @MainActor in
                    let updater = ASCredentialUpdater()
                    let decodeBase64: (String) -> Data? = { string in
                        var string = string.replacingOccurrences(of: "-", with: "+")
                            .replacingOccurrences(of: "_", with: "/")
                        while string.count % 4 != 0 {
                            string.append("=")
                        }
                        return Data(base64Encoded: string)
                    }
                    if let credentialId = decodeBase64(passkey.id) {
                        do {
                            try await updater.reportUnknownPublicKeyCredential(relyingPartyIdentifier: "telegram.org", credentialID: credentialId)
                        } catch let e {
                            Logger.shared.log("Passkeys", "reportUnknownPublicKeyCredential error: \(e)")
                        }
                    }
                }
            }
        }
        
        func update(component: PasskeysScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.25)
            
            if self.component == nil {
                self.passkeysData = component.initialPasskeysData
                if self.passkeysData == nil {
                    self.loadPasskeysDataDisposable = (component.context.engine.auth.passkeysData()
                    |> take(1)
                    |> deliverOnMainQueue).startStrict(next: { [weak self] data in
                        guard let self, let component = self.component else {
                            return
                        }
                        self.passkeysData = data
                        component.passkeysDataUpdated(data)
                        self.state?.updated(transition: .easeInOut(duration: 0.25))
                    })
                }
                
                if component.forceCreate {
                    Queue.mainQueue().justDispatch {
                        self.createPasskey()
                    }
                }
            }

            self.component = component
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environment
            self.state = state

            self.backgroundColor = environment.theme.list.plainBackgroundColor

            if let passkeysData = self.passkeysData, passkeysData.isEmpty {
                let intro: ComponentView<Empty>
                var introTransition = transition
                if let current = self.intro {
                    intro = current
                } else {
                    introTransition = transition.withAnimation(.none)
                    intro = ComponentView()
                    self.intro = intro
                }
                let _ = intro.update(
                    transition: introTransition,
                    component: AnyComponent(PasskeysScreenIntroComponent(
                        context: component.context,
                        theme: environment.theme,
                        strings: environment.strings,
                        insets: UIEdgeInsets(top: environment.statusBarHeight + environment.navigationHeight, left: 0.0, bottom: environment.safeInsets.bottom, right: 0.0),
                        displaySkip: component.displaySkip,
                        createPasskeyAction: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.createPasskey()
                        },
                        skipAction: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.cancel()
                            self.environment?.controller()?.dismiss()
                        }
                    )),
                    environment: {},
                    containerSize: availableSize
                )
                if let introView = intro.view {
                    if introView.superview == nil {
                        self.addSubview(introView)
                        introView.alpha = 0.0
                    }
                    transition.setFrame(view: introView, frame: CGRect(origin: CGPoint(), size: availableSize))
                    alphaTransition.setAlpha(view: introView, alpha: 1.0)
                }
            } else {
                if let intro = self.intro {
                    self.intro = nil
                    if let introView = intro.view {
                        alphaTransition.setAlpha(view: introView, alpha: 0.0, completion: { [weak introView] _ in
                            introView?.removeFromSuperview()
                        })
                    }
                }
            }
            
            if let passkeysData = self.passkeysData, !passkeysData.isEmpty {
                let list: ComponentView<Empty>
                var listTransition = transition
                if let current = self.list {
                    list = current
                } else {
                    listTransition = transition.withAnimation(.none)
                    list = ComponentView()
                    self.list = list
                }
                let _ = list.update(
                    transition: listTransition,
                    component: AnyComponent(PasskeysScreenListComponent(
                        context: component.context,
                        theme: environment.theme,
                        strings: environment.strings,
                        insets: UIEdgeInsets(top: environment.statusBarHeight, left: 0.0, bottom: environment.safeInsets.bottom, right: 0.0),
                        passkeys: passkeysData,
                        addPasskeyAction: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.createPasskey()
                        },
                        deletePasskeyAction: { [weak self] id in
                            guard let self else {
                                return
                            }
                            self.displayDeletePasskey(id: id)
                        }
                    )),
                    environment: {},
                    containerSize: availableSize
                )
                if let listView = list.view {
                    if listView.superview == nil {
                        self.addSubview(listView)
                        listView.alpha = 0.0
                    }
                    transition.setFrame(view: listView, frame: CGRect(origin: CGPoint(), size: availableSize))
                    alphaTransition.setAlpha(view: listView, alpha: 1.0)
                }
            } else {
                if let list = self.list {
                    self.list = nil
                    if let listView = list.view {
                        alphaTransition.setAlpha(view: listView, alpha: 0.0, completion: { [weak listView] _ in
                            listView?.removeFromSuperview()
                        })
                    }
                }
            }
            
            if self.passkeysData == nil {
                let activityIndicator: UIActivityIndicatorView
                if let current = self.activityIndicator {
                    activityIndicator = current
                } else {
                    activityIndicator = UIActivityIndicatorView(style: .large)
                    self.activityIndicator = activityIndicator
                    self.addSubview(activityIndicator)
                }
                activityIndicator.tintColor = environment.theme.list.itemPrimaryTextColor
                
                let indicatorSize = activityIndicator.bounds.size
                activityIndicator.frame = CGRect(origin: CGPoint(x: floor((availableSize.width - indicatorSize.width) / 2.0), y: floor((availableSize.height - indicatorSize.height) / 2.0)), size: indicatorSize)
                if !activityIndicator.isAnimating {
                    activityIndicator.startAnimating()
                }
            } else if let activityIndicator = self.activityIndicator {
                self.activityIndicator = nil
                activityIndicator.removeFromSuperview()
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class PasskeysScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    
    public init(
        context: AccountContext,
        displaySkip: Bool,
        initialPasskeysData: [TelegramPasskey]?,
        forceCreate: Bool = false,
        passkeysDataUpdated: @escaping ([TelegramPasskey]) -> Void,
        completion: @escaping () -> Void,
        cancel: @escaping () -> Void
    ) {
        self.context = context
        
        super.init(context: context, component: PasskeysScreenComponent(context: context, displaySkip: displaySkip, initialPasskeysData: initialPasskeysData, forceCreate: forceCreate, passkeysDataUpdated: passkeysDataUpdated, completion: completion, cancel: cancel), navigationBarAppearance: .transparent)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
