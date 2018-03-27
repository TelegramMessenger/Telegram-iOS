import Foundation
import Postbox
import TelegramCore

struct SecureIdEncryptedFormData {
    let form: EncryptedSecureIdForm
    let accountPeer: Peer
    let servicePeer: Peer
}

enum SecureIdAuthPasswordChallengeState {
    case none
    case checking
    case invalid
}

enum SecureIdAuthControllerVerificationState: Equatable {
    case noChallenge
    case passwordChallenge(SecureIdAuthPasswordChallengeState)
    case verified(SecureIdAccessContext)
    
    static func ==(lhs: SecureIdAuthControllerVerificationState, rhs: SecureIdAuthControllerVerificationState) -> Bool {
        switch lhs {
            case .noChallenge:
                if case .noChallenge = rhs {
                    return true
                } else {
                    return false
                }
            case let .passwordChallenge(state):
                if case .passwordChallenge(state) = rhs {
                    return true
                } else {
                    return false
                }
            case .verified:
                if case .verified = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

struct SecureIdAuthControllerState: Equatable {
    var encryptedFormData: SecureIdEncryptedFormData?
    var formData: SecureIdForm?
    var verificationState: SecureIdAuthControllerVerificationState?
    
    static func ==(lhs: SecureIdAuthControllerState, rhs: SecureIdAuthControllerState) -> Bool {
        if (lhs.formData != nil) != (rhs.formData != nil) {
            return false
        }
        
        if (lhs.encryptedFormData != nil) != (rhs.encryptedFormData != nil) {
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
        
        return true
    }
}
