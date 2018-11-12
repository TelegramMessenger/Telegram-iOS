import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit

enum SetupTwoStepVerificationInitialState {
    case createPassword
    case updatePassword(current: String, hasRecoveryEmail: Bool, hasSecureValues: Bool)
    case addEmail(hadRecoveryEmail: Bool, hasSecureValues: Bool, password: String)
    case confirmEmail(password: String?, hasSecureValues: Bool, pattern: String, codeLength: Int32?)
}

enum SetupTwoStepVerificationStateKind: Int32 {
    case enterPassword
    case confirmPassword
    case enterHint
    case enterEmail
    case confirmEmail
}

private enum CreatePasswordMode: Equatable {
    case create
    case update(current: String, hasRecoveryEmail: Bool, hasSecureValues: Bool)
}

private enum EnterEmailState: Equatable {
    case create(password: String, hint: String)
    case add(hadRecoveryEmail: Bool, hasSecureValues: Bool, password: String)
}

private enum ConfirmEmailState: Equatable {
    case create(password: String, hint: String, email: String)
    case add(password: String, hadRecoveryEmail: Bool, hasSecureValues: Bool, email: String)
    case confirm(password: String?, hasSecureValues: Bool, pattern: String, codeLength: Int32?)
}

private enum SetupTwoStepVerificationState: Equatable {
    case enterPassword(mode: CreatePasswordMode, password: String)
    case confirmPassword(mode: CreatePasswordMode, password: String, confirmation: String)
    case enterHint(mode: CreatePasswordMode, password: String, hint: String)
    case enterEmail(state: EnterEmailState, email: String)
    case confirmEmail(state: ConfirmEmailState, pattern: String, codeLength: Int32?, code: String)
    
    var kind: SetupTwoStepVerificationStateKind {
        switch self {
            case .enterPassword:
                return .enterPassword
            case .confirmPassword:
                return .confirmPassword
            case .enterHint:
                return .enterHint
            case .enterEmail:
                return .enterEmail
            case .confirmEmail:
                return .confirmEmail
        }
    }
    
    mutating func updateInputText(_ text: String) {
        switch self {
            case let .enterPassword(mode, _):
                self = .enterPassword(mode: mode, password: text)
            case let .confirmPassword(mode, password, _):
                self = .confirmPassword(mode: mode, password: password, confirmation: text)
            case let .enterHint(mode, password, _):
                self = .enterHint(mode: mode, password: password, hint: text)
            case let .enterEmail(state, _):
                self = .enterEmail(state: state, email: text)
            case let .confirmEmail(state, pattern, codeLength, _):
                self = .confirmEmail(state: state, pattern: pattern, codeLength: codeLength, code: text)
        }
    }
}

extension SetupTwoStepVerificationState {
    init(initialState: SetupTwoStepVerificationInitialState) {
        switch initialState {
            case .createPassword:
                self = .enterPassword(mode: .create, password: "")
            case let .updatePassword(current, hasRecoveryEmail, hasSecureValues):
                self = .enterPassword(mode: .update(current: current, hasRecoveryEmail: hasRecoveryEmail, hasSecureValues: hasSecureValues), password: "")
            case let .addEmail(hadRecoveryEmail, hasSecureValues, password):
                self = .enterEmail(state: .add(hadRecoveryEmail: hadRecoveryEmail, hasSecureValues: hasSecureValues, password: password), email: "")
            case let .confirmEmail(password, hasSecureValues, pattern, codeLength):
                self = .confirmEmail(state: .confirm(password: password, hasSecureValues: hasSecureValues, pattern: pattern, codeLength: codeLength), pattern: pattern, codeLength: codeLength, code: "")
        }
    }
}

private struct SetupTwoStepVerificationControllerDataState: Equatable {
    var activity: Bool
    var state: SetupTwoStepVerificationState
}

private struct SetupTwoStepVerificationControllerLayoutState: Equatable {
    let layout: ContainerViewLayout
    let navigationHeight: CGFloat
}

private struct SetupTwoStepVerificationControllerInnerState: Equatable {
    var layout: SetupTwoStepVerificationControllerLayoutState?
    var data: SetupTwoStepVerificationControllerDataState
}

private struct SetupTwoStepVerificationControllerState: Equatable {
    var layout: SetupTwoStepVerificationControllerLayoutState
    var data: SetupTwoStepVerificationControllerDataState
}

extension SetupTwoStepVerificationControllerState {
    init?(_ state: SetupTwoStepVerificationControllerInnerState) {
        guard let layout = state.layout else {
            return nil
        }
        self.init(layout: layout, data: state.data)
    }
}

enum SetupTwoStepVerificationNextAction: Equatable {
    case none
    case activity
    case button(title: String, isEnabled: Bool)
}

enum SetupTwoStepVerificationStateUpdate {
    case noPassword
    case awaitingEmailConfirmation(password: String, pattern: String, codeLength: Int32?)
    case passwordSet(password: String?, hasRecoveryEmail: Bool, hasSecureValues: Bool)
}

final class SetupTwoStepVerificationControllerNode: ViewControllerTracingNode {
    private let account: Account
    private var presentationData: PresentationData
    private let updateBackAction: (Bool) -> Void
    private let updateNextAction: (SetupTwoStepVerificationNextAction) -> Void
    private let stateUpdated: (SetupTwoStepVerificationStateUpdate, Bool) -> Void
    private let present: (ViewController, Any?) -> Void
    private let dismiss: () -> Void
    private var innerState: SetupTwoStepVerificationControllerInnerState
    
    private var contentNode: SetupTwoStepVerificationContentNode?
    private let actionDisposable = MetaDisposable()
    
    init(account: Account, updateBackAction: @escaping (Bool) -> Void, updateNextAction: @escaping (SetupTwoStepVerificationNextAction) -> Void, stateUpdated: @escaping (SetupTwoStepVerificationStateUpdate, Bool) -> Void, present: @escaping (ViewController, Any?) -> Void, dismiss: @escaping () -> Void, initialState: SetupTwoStepVerificationInitialState) {
        self.account = account
        self.updateBackAction = updateBackAction
        self.updateNextAction = updateNextAction
        self.stateUpdated = stateUpdated
        self.present = present
        self.dismiss = dismiss
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        self.innerState = SetupTwoStepVerificationControllerInnerState(layout: nil, data: SetupTwoStepVerificationControllerDataState(activity: false, state: SetupTwoStepVerificationState(initialState: initialState)))
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        self.processStateUpdated()
    }
    
    deinit {
        self.actionDisposable.dispose()
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
    }
    
    func animateIn() {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseInEaseOut, removeOnCompletion: false, completion: { _ in
            completion?()
        })
    }
    
    private func updateState(_ f: (SetupTwoStepVerificationControllerInnerState) -> SetupTwoStepVerificationControllerInnerState, transition: ContainedViewLayoutTransition) {
        let updatedState = f(self.innerState)
        if updatedState != self.innerState {
            self.innerState = updatedState
            self.processStateUpdated()
            if let state = SetupTwoStepVerificationControllerState(updatedState) {
                self.transition(state: state, transition: transition)
            }
        }
    }
    
    private func processStateUpdated() {
        var backAction = false
        let nextAction: SetupTwoStepVerificationNextAction
        if self.innerState.data.activity {
            nextAction = .activity
        } else {
            switch self.innerState.data.state {
                case let .enterPassword(_, password):
                    nextAction = .button(title: self.presentationData.strings.Common_Next, isEnabled: !password.isEmpty)
                case let .confirmPassword(_, _, confirmation):
                    nextAction = .button(title: self.presentationData.strings.Common_Next, isEnabled: !confirmation.isEmpty)
                    backAction = true
                case let .enterHint(_, _, hint):
                    nextAction = .button(title: hint.isEmpty ? self.presentationData.strings.TwoStepAuth_EmailSkip :  self.presentationData.strings.Common_Next, isEnabled: true)
                    backAction = true
                case let .enterEmail(enterState, email):
                    switch enterState {
                        case .create:
                            nextAction = .button(title: email.isEmpty ? self.presentationData.strings.TwoStepAuth_EmailSkip :  self.presentationData.strings.Common_Next, isEnabled: true)
                        case .add:
                            nextAction = .button(title: self.presentationData.strings.Common_Next, isEnabled: !email.isEmpty)
                    }
                case let .confirmEmail(_, _, _, code):
                    nextAction = .button(title: self.presentationData.strings.Common_Next, isEnabled: !code.isEmpty)
            }
        }
        self.updateBackAction(backAction)
        self.updateNextAction(nextAction)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.updateState({ state in
            var state = state
            state.layout = SetupTwoStepVerificationControllerLayoutState(layout: layout, navigationHeight: navigationBarHeight)
            return state
        }, transition: transition)
    }
    
    private func transition(state: SetupTwoStepVerificationControllerState, transition: ContainedViewLayoutTransition) {
        var insets = state.layout.layout.insets(options: [.statusBar])
        let visibleInsets = state.layout.layout.insets(options: [.statusBar, .input])
        if let inputHeight = state.layout.layout.inputHeight {
            if inputHeight.isEqual(to: state.layout.layout.standardInputHeight - 44.0) {
                insets.bottom += state.layout.layout.standardInputHeight
            } else {
                insets.bottom += inputHeight
            }
        }
        let contentFrame = CGRect(origin: CGPoint(x: 0.0, y: 0), size: CGSize(width: state.layout.layout.size.width, height: state.layout.layout.size.height))
        if state.data.state.kind != self.contentNode?.kind {
            let title: String
            let subtitle: String
            let inputType: SetupTwoStepVerificationInputType
            let inputPlaceholder: String
            let inputText: String
            let isPassword: Bool
            var leftAction: SetupTwoStepVerificationContentAction?
            var rightAction: SetupTwoStepVerificationContentAction?
            switch state.data.state {
                case let .enterPassword(mode, password):
                    switch mode {
                        case .create:
                            title = "Create a Password"
                            subtitle = "Please create a password which will be used to protect your data."
                        case .update:
                            title = "Change Password"
                            subtitle = "Please enter a new password which will be used to protect your data."
                    }
                    inputType = .password
                    inputPlaceholder = "Password"
                    inputText = password
                    isPassword = true
                case let .confirmPassword(_, _, confirmation):
                    title = "Re-enter your Password"
                    subtitle = "Please confirm your password."
                    inputType = .password
                    inputPlaceholder = "Password"
                    inputText = confirmation
                    isPassword = true
                case let .enterHint(_, _, hint):
                    title = "Add a Hint"
                    subtitle = "You can create an optional hint for your password."
                    inputType = .text
                    inputPlaceholder = "Hint"
                    inputText = hint
                    isPassword = false
                case let .enterEmail(enterState, email):
                    title = "Recovery Email"
                    switch enterState {
                        case let .add(hadRecoveryEmail, _, _) where hadRecoveryEmail:
                            subtitle = "Please enter your new recovery email. It is the only way to recover a forgotten password."
                        default:
                            subtitle = "Please add your valid e-mail. It is the only way to recover a forgotten password."
                    }
                    inputType = .email
                    inputPlaceholder = "Email"
                    inputText = email
                    isPassword = false
                case let .confirmEmail(confirmState, _, _, code):
                    title = "Recovery Email"
                    let emailPattern: String
                    switch confirmState {
                        case let .create(password, hint, email):
                            emailPattern = email
                            leftAction = SetupTwoStepVerificationContentAction(title: "Change E-Mail", action: { [weak self] in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.updateState({ state in
                                    var state = state
                                    state.data.activity = true
                                    return state
                                }, transition: .animated(duration: 0.5, curve: .spring))
                                strongSelf.actionDisposable.set((updateTwoStepVerificationPassword(network: strongSelf.account.network, currentPassword: nil, updatedPassword: .none)
                                |> deliverOnMainQueue).start(next: { _ in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.updateState({ state in
                                        var state = state
                                        state.data.activity = false
                                        state.data.state = .enterEmail(state: .create(password: password, hint: hint), email: "")
                                        return state
                                    }, transition: .animated(duration: 0.5, curve: .spring))
                                    strongSelf.stateUpdated(.noPassword, false)
                                }, error: { _ in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.presentationData.theme), title: nil, text: strongSelf.presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), nil)
                                    strongSelf.updateState({ state in
                                        var state = state
                                        state.data.activity = false
                                        return state
                                    }, transition: .animated(duration: 0.5, curve: .spring))
                                }))
                            })
                        case let .add(password, hadRecoveryEmail, hasSecureValues, email):
                            emailPattern = email
                            leftAction = SetupTwoStepVerificationContentAction(title: "Change E-Mail", action: { [weak self] in
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.updateState({ state in
                                    var state = state
                                    state.data.state = .enterEmail(state: .add(hadRecoveryEmail: hadRecoveryEmail, hasSecureValues: hasSecureValues, password: password), email: "")
                                    return state
                                }, transition: .animated(duration: 0.5, curve: .spring))
                            })
                        case let .confirm(_, _, pattern, _):
                            emailPattern = pattern
                    }
                    subtitle = "Please enter the code we've just emailed at \(emailPattern)."
                    inputType = .code
                    inputPlaceholder = "Code"
                    inputText = code
                    isPassword = true
                    rightAction = SetupTwoStepVerificationContentAction(title: "Resend Code", action: { [weak self] in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.updateState({ state in
                            var state = state
                            state.data.activity = true
                            return state
                        }, transition: .animated(duration: 0.5, curve: .spring))
                        strongSelf.actionDisposable.set((resendTwoStepRecoveryEmail(network: strongSelf.account.network)
                        |> deliverOnMainQueue).start(error: { error in
                            guard let strongSelf = self else {
                                return
                            }
                            let text: String
                            switch error {
                                case .flood:
                                    text = strongSelf.presentationData.strings.TwoStepAuth_FloodError
                                case .generic:
                                    text = strongSelf.presentationData.strings.Login_UnknownError
                            }
                            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.presentationData.theme), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), nil)
                            strongSelf.updateState({ state in
                                var state = state
                                state.data.activity = false
                                return state
                            }, transition: .animated(duration: 0.5, curve: .spring))
                        }, completed: {
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.updateState({ state in
                                var state = state
                                state.data.activity = false
                                return state
                            }, transition: .animated(duration: 0.5, curve: .spring))
                        }))
                    })
            }
            let contentNode = SetupTwoStepVerificationContentNode(theme: self.presentationData.theme, kind: state.data.state.kind, title: title, subtitle: subtitle, inputType: inputType, placeholder: inputPlaceholder, text: inputText, isPassword: isPassword, textUpdated: { [weak self] text in
                guard let strongSelf = self else {
                    return
                }
                var inplicitelyActivateNextAction = false
                if case let .confirmEmail(confirmEmail) = strongSelf.innerState.data.state, let codeLength = confirmEmail.codeLength, confirmEmail.code.count != codeLength, text.count == codeLength {
                    inplicitelyActivateNextAction = true
                }
                strongSelf.updateState({ state in
                    var state = state
                    state.data.state.updateInputText(text)
                    return state
                }, transition: .immediate)
                if inplicitelyActivateNextAction {
                    strongSelf.activateNextAction()
                }
            }, returnPressed: { [weak self] in
                self?.activateNextAction()
            }, leftAction: leftAction, rightAction: rightAction)
            self.insertSubnode(contentNode, at: 0)
            contentNode.updateIsEnabled(!state.data.activity)
            contentNode.updateLayout(size: contentFrame.size, insets: insets, visibleInsets: visibleInsets, transition: .immediate)
            contentNode.frame = contentFrame
            contentNode.activate()
            if let currentContentNode = self.contentNode {
                if currentContentNode.kind.rawValue < contentNode.kind.rawValue {
                    transition.updatePosition(node: currentContentNode, position: CGPoint(x: -contentFrame.size.width / 2.0, y: contentFrame.midY), completion: { [weak currentContentNode] _ in
                        currentContentNode?.removeFromSupernode()
                    })
                    transition.animateHorizontalOffsetAdditive(node: contentNode, offset: -contentFrame.width)
                } else {
                    transition.updatePosition(node: currentContentNode, position: CGPoint(x: contentFrame.size.width + contentFrame.size.width / 2.0, y: contentFrame.midY), completion: { [weak currentContentNode] _ in
                        currentContentNode?.removeFromSupernode()
                    })
                    transition.animateHorizontalOffsetAdditive(node: contentNode, offset: contentFrame.width)
                }
            }
            self.contentNode = contentNode
        } else if let contentNode = self.contentNode {
            contentNode.updateIsEnabled(!state.data.activity)
            transition.updateFrame(node: contentNode, frame: contentFrame)
            contentNode.updateLayout(size: contentFrame.size, insets: insets, visibleInsets: visibleInsets, transition: transition)
        }
    }
    
    func activateBackAction() {
        if self.innerState.data.activity {
            return
        }
        self.updateState({ state in
            var state = state
            switch state.data.state {
                case let .confirmPassword(mode, _, _):
                    state.data.state = .enterPassword(mode: mode, password: "")
                case let .enterHint(mode, _, _):
                    state.data.state = .enterPassword(mode: mode, password: "")
                default:
                    break
            }
            return state
        }, transition: .animated(duration: 0.5, curve: .spring))
    }
    
    func activateNextAction() {
        if self.innerState.data.activity {
            return
        }
        let continueImpl: () -> Void = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateState({ state in
                var state = state
                switch state.data.state {
                    case let .enterPassword(mode, password):
                        state.data.state = .confirmPassword(mode: mode, password: password, confirmation: "")
                    case let .confirmPassword(mode, password, confirmation):
                        if password == confirmation {
                            state.data.state = .enterHint(mode: mode, password: password, hint: "")
                        } else {
                            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.presentationData.theme), title: nil, text: strongSelf.presentationData.strings.TwoStepAuth_SetupPasswordConfirmFailed, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), nil)
                        }
                    case let .enterHint(mode, password, hint):
                        switch mode {
                            case .create:
                                state.data.state = .enterEmail(state: .create(password: password, hint: hint), email: "")
                            case let .update(current, hasRecoveryEmail, hasSecureValues):
                                state.data.activity = true
                                strongSelf.actionDisposable.set((updateTwoStepVerificationPassword(network: strongSelf.account.network, currentPassword: current, updatedPassword: .password(password: password, hint: hint, email: nil))
                                |> deliverOnMainQueue).start(next: { result in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.updateState({ state in
                                        var state = state
                                        state.data.activity = false
                                        switch result {
                                            case let .password(password, pendingEmail):
                                                if let pendingEmail = pendingEmail {
                                                    strongSelf.stateUpdated(.awaitingEmailConfirmation(password: password, pattern: pendingEmail.pattern, codeLength: pendingEmail.codeLength), true)
                                                } else {
                                                    strongSelf.stateUpdated(.passwordSet(password: password, hasRecoveryEmail: hasRecoveryEmail, hasSecureValues: hasSecureValues), true)
                                                }
                                            case .none:
                                                strongSelf.dismiss()
                                        }
                                        return state
                                    }, transition: .animated(duration: 0.5, curve: .spring))
                                }, error: { error in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.presentationData.theme), title: nil, text: strongSelf.presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), nil)
                                    strongSelf.updateState({ state in
                                        var state = state
                                        state.data.activity = false
                                        return state
                                    }, transition: .animated(duration: 0.5, curve: .spring))
                                }))
                        }
                    case let .enterEmail(enterState, email):
                        state.data.activity = true
                        switch enterState {
                            case let .create(password, hint):
                                strongSelf.actionDisposable.set((updateTwoStepVerificationPassword(network: strongSelf.account.network, currentPassword: nil, updatedPassword: .password(password: password, hint: hint, email: email))
                                |> deliverOnMainQueue).start(next: { result in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.updateState({ state in
                                        var state = state
                                        switch result {
                                            case let .password(password, pendingEmail):
                                                if let pendingEmail = pendingEmail {
                                                    state.data.activity = false
                                                    state.data.state = .confirmEmail(state: .create(password: password, hint: hint, email: email), pattern: pendingEmail.pattern, codeLength: pendingEmail.codeLength, code: "")
                                                    strongSelf.stateUpdated(.awaitingEmailConfirmation(password: password, pattern: pendingEmail.pattern, codeLength: pendingEmail.codeLength), false)
                                                } else {
                                                    strongSelf.stateUpdated(.passwordSet(password: password, hasRecoveryEmail: false, hasSecureValues: false), true)
                                                }
                                            case .none:
                                                break
                                        }
                                        return state
                                    }, transition: .animated(duration: 0.5, curve: .spring))
                                }, error: { error in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    let text: String
                                    switch error {
                                        case .invalidEmail:
                                            text = strongSelf.presentationData.strings.TwoStepAuth_EmailInvalid
                                        case .generic:
                                            text = strongSelf.presentationData.strings.Login_UnknownError
                                    }
                                    strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.presentationData.theme), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), nil)
                                    strongSelf.updateState({ state in
                                        var state = state
                                        state.data.activity = false
                                        if case .invalidEmail = error {
                                            state.data.state = .enterEmail(state: .create(password: password, hint: hint), email: "")
                                        }
                                        return state
                                    }, transition: .animated(duration: 0.5, curve: .spring))
                                }))
                            case let .add(hadRecoveryEmail, hasSecureValues, password):
                                strongSelf.updateState({ state in
                                    var state = state
                                    state.data.activity = true
                                    return state
                                }, transition: .animated(duration: 0.5, curve: .spring))
                                strongSelf.actionDisposable.set((updateTwoStepVerificationEmail(account: strongSelf.account, currentPassword: password, updatedEmail: email)
                                |> deliverOnMainQueue).start(next: { result in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.updateState({ state in
                                        var state = state
                                        state.data.activity = false
                                        switch result {
                                            case .none:
                                                assertionFailure()
                                                break
                                            case let .password(password, pendingEmail):
                                                if let pendingEmail = pendingEmail {
                                                    state.data.state = .confirmEmail(state: .add(password: password, hadRecoveryEmail: hadRecoveryEmail, hasSecureValues: hasSecureValues, email: email), pattern: pendingEmail.pattern, codeLength: pendingEmail.codeLength, code: "")
                                                    strongSelf.stateUpdated(.awaitingEmailConfirmation(password: password, pattern: pendingEmail.pattern, codeLength: pendingEmail.codeLength), false)
                                                } else {
                                                    strongSelf.stateUpdated(.passwordSet(password: password, hasRecoveryEmail: true, hasSecureValues: hasSecureValues), true)
                                                }
                                        }
                                        return state
                                    }, transition: .animated(duration: 0.5, curve: .spring))
                                }, error: { _ in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.presentationData.theme), title: nil, text: strongSelf.presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), nil)
                                    strongSelf.updateState({ state in
                                        var state = state
                                        state.data.activity = false
                                        return state
                                    }, transition: .animated(duration: 0.5, curve: .spring))
                                }))
                        }
                    case let .confirmEmail(confirmState, _, _, code):
                        strongSelf.updateState({ state in
                            var state = state
                            state.data.activity = true
                            return state
                        }, transition: .animated(duration: 0.5, curve: .spring))
                        strongSelf.actionDisposable.set((confirmTwoStepRecoveryEmail(network: strongSelf.account.network, code: code)
                        |> deliverOnMainQueue).start(error: { error in
                            guard let strongSelf = self else {
                                return
                            }
                            let text: String
                            switch error {
                                case .invalidEmail:
                                    text = strongSelf.presentationData.strings.TwoStepAuth_EmailInvalid
                                case .invalidCode:
                                    text = strongSelf.presentationData.strings.Login_InvalidCodeError
                                    strongSelf.contentNode?.dataEntryError()
                                case .expired:
                                    text = strongSelf.presentationData.strings.TwoStepAuth_EmailCodeExpired
                                case .flood:
                                    text = strongSelf.presentationData.strings.TwoStepAuth_FloodError
                                case .generic:
                                    text = strongSelf.presentationData.strings.Login_UnknownError
                            }
                            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.presentationData.theme), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), nil)
                            
                            strongSelf.updateState({ state in
                                var state = state
                                state.data.activity = false
                                return state
                            }, transition: .animated(duration: 0.5, curve: .spring))
                        }, completed: {
                            guard let strongSelf = self else {
                                return
                            }
                            switch confirmState {
                                case let .create(password, _, _):
                                    strongSelf.stateUpdated(.passwordSet(password: password, hasRecoveryEmail: true, hasSecureValues: false), true)
                                case let .add(password, _, hasSecureValues, email):
                                    strongSelf.stateUpdated(.passwordSet(password: password, hasRecoveryEmail: !email.isEmpty, hasSecureValues: hasSecureValues), true)
                                case let .confirm(password, hasSecureValues, _, _):
                                    strongSelf.stateUpdated(.passwordSet(password: password, hasRecoveryEmail: true, hasSecureValues: hasSecureValues), true)
                            }
                        }))
                }
                return state
            }, transition: .animated(duration: 0.5, curve: .spring))
        }
        if case let .enterEmail(enterEmail) = self.innerState.data.state, case .create = enterEmail.state, enterEmail.email.isEmpty {
            self.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: self.presentationData.theme), title: nil, text: self.presentationData.strings.TwoStepAuth_EmailSkipAlert, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .destructiveAction, title: self.presentationData.strings.TwoStepAuth_EmailSkip, action: {
                continueImpl()
            })]), nil)
        } else {
            continueImpl()
        }
    }
}
