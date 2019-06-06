import Foundation
import UIKit
import Postbox
import TelegramCore

struct SecureIdEncryptedFormData {
    let form: EncryptedSecureIdForm
    let primaryLanguageByCountry: [String: String]
    let accountPeer: Peer
    let servicePeer: Peer
}

enum SecureIdAuthPasswordChallengeState {
    case none
    case checking
    case invalid
}

enum SecureIdAuthControllerVerificationNoChallengeState: Equatable {
    case notSet
    case awaitingConfirmation(password: String?, emailPattern: String, codeLength: Int32?)
}

enum SecureIdAuthControllerVerificationState: Equatable {
    case noChallenge(SecureIdAuthControllerVerificationNoChallengeState)
    case passwordChallenge(hint: String, state: SecureIdAuthPasswordChallengeState, hasRecoveryEmail: Bool)
    case verified(SecureIdAccessContext)
}

struct SecureIdAuthControllerFormState: Equatable {
    var twoStepEmail: String?
    var encryptedFormData: SecureIdEncryptedFormData?
    var formData: SecureIdForm?
    var verificationState: SecureIdAuthControllerVerificationState?
    var removingValues: Bool = false
    
    static func ==(lhs: SecureIdAuthControllerFormState, rhs: SecureIdAuthControllerFormState) -> Bool {
        if let lhsTwoStepEmail = lhs.twoStepEmail, let rhsTwoStepEmail = rhs.twoStepEmail, lhsTwoStepEmail != rhsTwoStepEmail {
            return false
        } else if (lhs.twoStepEmail != nil) != (rhs.twoStepEmail != nil) {
            return false
        }
        if (lhs.encryptedFormData != nil) != (rhs.encryptedFormData != nil) {
            return false
        }
        if (lhs.formData != nil) != (rhs.formData != nil) {
            return false
        }
        if let lhsFormData = lhs.formData, let rhsFormData = rhs.formData {
            if lhsFormData != rhsFormData {
                return false
            }
        } else if (lhs.formData != nil) != (rhs.formData != nil) {
            return false
        }
        if lhs.verificationState != rhs.verificationState {
            return false
        }
        if lhs.removingValues != rhs.removingValues {
            return false
        }
        return true
    }
}

struct SecureIdAuthControllerListState: Equatable {
    var accountPeer: Peer?
    var twoStepEmail: String?
    var verificationState: SecureIdAuthControllerVerificationState?
    var encryptedValues: EncryptedAllSecureIdValues?
    var primaryLanguageByCountry: [String: String]?
    var values: [SecureIdValueWithContext]?
    var removingValues: Bool = false
    
    static func ==(lhs: SecureIdAuthControllerListState, rhs: SecureIdAuthControllerListState) -> Bool {
        if !arePeersEqual(lhs.accountPeer, rhs.accountPeer) {
            return false
        }
        if let lhsTwoStepEmail = lhs.twoStepEmail, let rhsTwoStepEmail = rhs.twoStepEmail, lhsTwoStepEmail != rhsTwoStepEmail {
            return false
        } else if (lhs.twoStepEmail != nil) != (rhs.twoStepEmail != nil) {
            return false
        }
        if lhs.verificationState != rhs.verificationState {
            return false
        }
        if (lhs.encryptedValues != nil) != (rhs.encryptedValues != nil) {
            return false
        }
        if lhs.primaryLanguageByCountry != rhs.primaryLanguageByCountry {
            return false
        }
        if lhs.values != rhs.values {
            return false
        }
        if lhs.removingValues != rhs.removingValues {
            return false
        }
        return true
    }
}

enum SecureIdAuthControllerState: Equatable {
    case form(SecureIdAuthControllerFormState)
    case list(SecureIdAuthControllerListState)
    
    var twoStepEmail: String? {
        get {
            switch self {
                case let .form(form):
                    return form.twoStepEmail
                case let .list(list):
                    return list.twoStepEmail
            }
        } set(value) {
            switch self {
                case var .form(form):
                    form.twoStepEmail = value
                    self = .form(form)
                case var .list(list):
                    list.twoStepEmail = value
                    self = .list(list)
            }
        }
    }
    
    var verificationState: SecureIdAuthControllerVerificationState? {
        get {
            switch self {
                case let .form(form):
                    return form.verificationState
                case let .list(list):
                    return list.verificationState
            }
        } set(value) {
            switch self {
                case var .form(form):
                    form.verificationState = value
                    self = .form(form)
                case var .list(list):
                    list.verificationState = value
                    self = .list(list)
            }
        }
    }
    
    var removingValues: Bool {
        switch self {
            case let .form(form):
                return form.removingValues
            case let .list(list):
                return list.removingValues
        }
    }
}
