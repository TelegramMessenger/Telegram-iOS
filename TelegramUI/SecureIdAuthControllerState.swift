import Foundation
import Postbox
import TelegramCore

struct SecureIdFormData {
    let form: SecureIdForm
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
    case verified
    
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
    var formData: SecureIdFormData?
    var verificationState: SecureIdAuthControllerVerificationState?
    
    static func ==(lhs: SecureIdAuthControllerState, rhs: SecureIdAuthControllerState) -> Bool {
        if (lhs.formData != nil) != (rhs.formData != nil) {
            return false
        }
        
        if lhs.verificationState != rhs.verificationState {
            return false
        }
        
        return true
    }
}
