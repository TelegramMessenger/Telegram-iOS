import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ActivityIndicator
import AccountContext
import AlertUI
import PresentationDataUtils

public enum SetupTwoStepVerificationInitialState {
    case automatic
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
    init?(initialState: SetupTwoStepVerificationInitialState) {
        switch initialState {
            case .automatic:
                return nil
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
    var state: SetupTwoStepVerificationState?
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

public enum SetupTwoStepVerificationStateUpdate {
    case noPassword
    case awaitingEmailConfirmation(password: String, pattern: String, codeLength: Int32?)
    case passwordSet(password: String?, hasRecoveryEmail: Bool, hasSecureValues: Bool)
    case pendingPasswordReset
}

final class SetupTwoStepVerificationControllerNode: ViewControllerTracingNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    private let updateBackAction: (Bool) -> Void
    private let updateNextAction: (SetupTwoStepVerificationNextAction) -> Void
    private let stateUpdated: (SetupTwoStepVerificationStateUpdate, Bool) -> Void
    private let present: (ViewController, Any?) -> Void
    private let dismiss: () -> Void
    private var innerState: SetupTwoStepVerificationControllerInnerState
    
    private let activityIndicator: ActivityIndicator
    private var contentNode: SetupTwoStepVerificationContentNode?
    private let actionDisposable = MetaDisposable()
    
    init(context: AccountContext, updateBackAction: @escaping (Bool) -> Void, updateNextAction: @escaping (SetupTwoStepVerificationNextAction) -> Void, stateUpdated: @escaping (SetupTwoStepVerificationStateUpdate, Bool) -> Void, present: @escaping (ViewController, Any?) -> Void, dismiss: @escaping () -> Void, initialState: SetupTwoStepVerificationInitialState) {
        self.context = context
        self.updateBackAction = updateBackAction
        self.updateNextAction = updateNextAction
        self.stateUpdated = stateUpdated
        self.present = present
        self.dismiss = dismiss
        self.presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        self.innerState = SetupTwoStepVerificationControllerInnerState(layout: nil, data: SetupTwoStepVerificationControllerDataState(activity: false, state: SetupTwoStepVerificationState(initialState: initialState)))
        self.activityIndicator = ActivityIndicator(type: .custom(self.presentationData.theme.list.itemAccentColor, 22.0, 2.0, false))
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        self.processStateUpdated()
        
        if self.innerState.data.state == nil {
            self.actionDisposable.set((self.context.engine.auth.twoStepAuthData()
            |> deliverOnMainQueue).start(next: { [weak self] data in
                guard let strongSelf = self else {
                    return
                }
                if data.currentPasswordDerivation != nil {
                    strongSelf.stateUpdated(.passwordSet(password: nil, hasRecoveryEmail: data.hasRecovery, hasSecureValues: data.hasSecretValues), true)
                } else {
                    strongSelf.updateState({ state in
                        var state = state
                        if let unconfirmedEmailPattern = data.unconfirmedEmailPattern {
                            state.data.state = .confirmEmail(state: .confirm(password: nil, hasSecureValues: data.hasSecretValues, pattern: unconfirmedEmailPattern, codeLength: nil), pattern: unconfirmedEmailPattern, codeLength: nil, code: "")
                        } else {
                            state.data.state = .enterPassword(mode: .create, password: "")
                        }
                        return state
                    }, transition: .animated(duration: 0.3, curve: .easeInOut))
                }
            }))
        }
    }
    
    deinit {
        self.actionDisposable.dispose()
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        self.contentNode?.updatePresentationData(presentationData)
    }
    
    func animateIn(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, completion: { _ in
            completion?()
        })
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { _ in
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
        } else if let state = self.innerState.data.state {
            switch state {
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
        } else {
            nextAction = .none
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
        let indicatorSize = CGSize(width: 22.0, height: 22.0)
        self.activityIndicator.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - indicatorSize.width) / 2.0), y: floor((layout.size.height - indicatorSize.height) / 2.0)), size: indicatorSize)
    }
    
    private func transition(state: SetupTwoStepVerificationControllerState, transition: ContainedViewLayoutTransition) {
        var insets = state.layout.layout.insets(options: [.statusBar])
        let visibleInsets = state.layout.layout.insets(options: [.statusBar, .input])
        if let inputHeight = state.layout.layout.inputHeight {
            insets.bottom += max(inputHeight, state.layout.layout.standardInputHeight)
        }
        let contentFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: state.layout.layout.size.width, height: state.layout.layout.size.height))
        if state.data.state?.kind != self.contentNode?.kind {
            if let dataState = state.data.state {
                let title: String
                let subtitle: String
                let inputType: SetupTwoStepVerificationInputType
                let inputPlaceholder: String
                let inputText: String
                let isPassword: Bool
                var leftAction: SetupTwoStepVerificationContentAction?
                var rightAction: SetupTwoStepVerificationContentAction?
                switch dataState {
                    case let .enterPassword(mode, password):
                        switch mode {
                            case .create:
                                title = self.presentationData.strings.TwoStepAuth_SetupPasswordTitle
                                subtitle = self.presentationData.strings.TwoStepAuth_SetupPasswordDescription
                            case .update:
                                title = self.presentationData.strings.TwoStepAuth_ChangePassword
                                subtitle = self.presentationData.strings.TwoStepAuth_ChangePasswordDescription
                        }
                        inputType = .password
                        inputPlaceholder = self.presentationData.strings.LoginPassword_PasswordPlaceholder
                        inputText = password
                        isPassword = true
                    case let .confirmPassword(_, _, confirmation):
                        title = self.presentationData.strings.TwoStepAuth_ReEnterPasswordTitle
                        subtitle = self.presentationData.strings.TwoStepAuth_ReEnterPasswordDescription
                        inputType = .password
                        inputPlaceholder = self.presentationData.strings.LoginPassword_PasswordPlaceholder
                        inputText = confirmation
                        isPassword = true
                    case let .enterHint(_, _, hint):
                        title = self.presentationData.strings.TwoStepAuth_AddHintTitle
                        subtitle = self.presentationData.strings.TwoStepAuth_AddHintDescription
                        inputType = .text
                        inputPlaceholder = self.presentationData.strings.TwoStepAuth_HintPlaceholder
                        inputText = hint
                        isPassword = false
                    case let .enterEmail(enterState, email):
                        title = self.presentationData.strings.TwoStepAuth_RecoveryEmailTitle
                        switch enterState {
                            case let .add(hadRecoveryEmail, _, _) where hadRecoveryEmail:
                                subtitle = self.presentationData.strings.TwoStepAuth_RecoveryEmailChangeDescription
                            default:
                                subtitle = self.presentationData.strings.TwoStepAuth_RecoveryEmailAddDescription
                        }
                        inputType = .email
                        inputPlaceholder = self.presentationData.strings.TwoStepAuth_EmailPlaceholder
                        inputText = email
                        isPassword = false
                    case let .confirmEmail(confirmState, _, _, code):
                        title = self.presentationData.strings.TwoStepAuth_RecoveryEmailTitle
                        let emailPattern: String
                        switch confirmState {
                            case let .create(password, hint, email):
                                emailPattern = email
                                leftAction = SetupTwoStepVerificationContentAction(title: self.presentationData.strings.TwoStepAuth_ChangeEmail, action: { [weak self] in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.updateState({ state in
                                        var state = state
                                        state.data.activity = true
                                        return state
                                    }, transition: .animated(duration: 0.5, curve: .spring))
                                    strongSelf.actionDisposable.set((strongSelf.context.engine.auth.updateTwoStepVerificationPassword(currentPassword: nil, updatedPassword: .none)
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
                                        strongSelf.present(textAlertController(sharedContext: strongSelf.context.sharedContext, title: nil, text: strongSelf.presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), nil)
                                        strongSelf.updateState({ state in
                                            var state = state
                                            state.data.activity = false
                                            return state
                                        }, transition: .animated(duration: 0.5, curve: .spring))
                                    }))
                                })
                            case let .add(password, hadRecoveryEmail, hasSecureValues, email):
                                emailPattern = email
                                leftAction = SetupTwoStepVerificationContentAction(title: self.presentationData.strings.TwoStepAuth_ChangeEmail, action: { [weak self] in
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
                        subtitle = self.presentationData.strings.TwoStepAuth_ConfirmEmailDescription(emailPattern).string
                        inputType = .code
                        inputPlaceholder = self.presentationData.strings.TwoStepAuth_ConfirmEmailCodePlaceholder
                        inputText = code
                        isPassword = true
                        rightAction = SetupTwoStepVerificationContentAction(title: self.presentationData.strings.TwoStepAuth_ConfirmEmailResendCode, action: { [weak self] in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.updateState({ state in
                                var state = state
                                state.data.activity = true
                                return state
                            }, transition: .animated(duration: 0.5, curve: .spring))
                            strongSelf.actionDisposable.set((strongSelf.context.engine.auth.resendTwoStepRecoveryEmail()
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
                                strongSelf.present(textAlertController(sharedContext: strongSelf.context.sharedContext, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), nil)
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
                let contentNode = SetupTwoStepVerificationContentNode(theme: self.presentationData.theme, kind: dataState.kind, title: title, subtitle: subtitle, inputType: inputType, placeholder: inputPlaceholder, text: inputText, isPassword: isPassword, textUpdated: { [weak self] text in
                    guard let strongSelf = self else {
                        return
                    }
                    var inplicitelyActivateNextAction = false
                    if case let .confirmEmail(_, _, codeLength?, code)? = strongSelf.innerState.data.state, code.count != codeLength, text.count == codeLength {
                        inplicitelyActivateNextAction = true
                    }
                    strongSelf.updateState({ state in
                        var state = state
                        state.data.state?.updateInputText(text)
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
                } else if transition.isAnimated {
                    contentNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                }
                if self.activityIndicator.supernode != nil {
                    transition.updateAlpha(node: self.activityIndicator, alpha: 0.0, completion: { [weak self] _ in
                        self?.activityIndicator.removeFromSupernode()
                    })
                }
                self.contentNode = contentNode
            } else if let currentContentNode = self.contentNode {
                transition.updateAlpha(node: currentContentNode, alpha: 0.0, completion: { [weak currentContentNode] _ in
                    currentContentNode?.removeFromSupernode()
                })
                if self.activityIndicator.supernode == nil {
                    self.addSubnode(self.activityIndicator)
                    transition.updateAlpha(node: self.activityIndicator, alpha: 1.0)
                }
                self.contentNode = nil
            }
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
            if let dataState = state.data.state {
                switch dataState {
                    case let .confirmPassword(mode, _, _):
                        state.data.state = .enterPassword(mode: mode, password: "")
                    case let .enterHint(mode, _, _):
                        state.data.state = .enterPassword(mode: mode, password: "")
                    default:
                        break
                }
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
                guard let dataState = state.data.state else {
                    return state
                }
                var state = state
                
                switch dataState {
                    case let .enterPassword(mode, password):
                        state.data.state = .confirmPassword(mode: mode, password: password, confirmation: "")
                    case let .confirmPassword(mode, password, confirmation):
                        if password == confirmation {
                            state.data.state = .enterHint(mode: mode, password: password, hint: "")
                        } else {
                            strongSelf.present(textAlertController(sharedContext: strongSelf.context.sharedContext, title: nil, text: strongSelf.presentationData.strings.TwoStepAuth_SetupPasswordConfirmFailed, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), nil)
                        }
                    case let .enterHint(mode, password, hint):
                        switch mode {
                            case .create:
                                state.data.state = .enterEmail(state: .create(password: password, hint: hint), email: "")
                            case let .update(current, hasRecoveryEmail, hasSecureValues):
                                state.data.activity = true
                                strongSelf.actionDisposable.set((strongSelf.context.engine.auth.updateTwoStepVerificationPassword(currentPassword: current, updatedPassword: .password(password: password, hint: hint, email: nil))
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
                                    strongSelf.present(textAlertController(sharedContext: strongSelf.context.sharedContext, title: nil, text: strongSelf.presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), nil)
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
                                strongSelf.actionDisposable.set((strongSelf.context.engine.auth.updateTwoStepVerificationPassword(currentPassword: nil, updatedPassword: .password(password: password, hint: hint, email: email))
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
                                    strongSelf.present(textAlertController(sharedContext: strongSelf.context.sharedContext, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), nil)
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
                                strongSelf.actionDisposable.set((strongSelf.context.engine.auth.updateTwoStepVerificationEmail(currentPassword: password, updatedEmail: email)
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
                                    strongSelf.present(textAlertController(sharedContext: strongSelf.context.sharedContext, title: nil, text: strongSelf.presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), nil)
                                    strongSelf.updateState({ state in
                                        var state = state
                                        state.data.activity = false
                                        return state
                                    }, transition: .animated(duration: 0.5, curve: .spring))
                                }))
                        }
                    case let .confirmEmail(confirmState, _, _, code):
                        state.data.activity = true
                        strongSelf.actionDisposable.set((strongSelf.context.engine.auth.confirmTwoStepRecoveryEmail(code: code)
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
                            strongSelf.present(textAlertController(sharedContext: strongSelf.context.sharedContext, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), nil)
                            
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
        if case let .enterEmail(enterEmailState, enterEmailEmail)? = self.innerState.data.state, case .create = enterEmailState, enterEmailEmail.isEmpty {
            self.present(textAlertController(sharedContext: self.context.sharedContext, title: nil, text: self.presentationData.strings.TwoStepAuth_EmailSkipAlert, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .destructiveAction, title: self.presentationData.strings.TwoStepAuth_EmailSkip, action: {
                continueImpl()
            })]), nil)
        } else {
            continueImpl()
        }
    }
}
