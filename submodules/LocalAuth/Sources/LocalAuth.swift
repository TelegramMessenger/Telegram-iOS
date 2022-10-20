import Foundation
import LocalAuthentication
import SwiftSignalKit

public enum LocalAuthBiometricAuthentication {
    case touchId
    case faceId
}

public struct LocalAuth {
    public static let biometricAuthentication: LocalAuthBiometricAuthentication? = {
        let context = LAContext()
        if context.canEvaluatePolicy(LAPolicy(rawValue: Int(kLAPolicyDeviceOwnerAuthenticationWithBiometrics))!, error: nil) {
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                switch context.biometryType {
                case .faceID:
                    return .faceId
                case .touchID:
                    return .touchId
                case .none:
                    return nil
                @unknown default:
                    return nil
                }
            } else {
                return .touchId
            }
        } else {
            return nil
        }
    }()
    
    public static let evaluatedPolicyDomainState: Data? = {
        let context = LAContext()
        if context.canEvaluatePolicy(LAPolicy(rawValue: Int(kLAPolicyDeviceOwnerAuthenticationWithBiometrics))!, error: nil) {
            if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                return context.evaluatedPolicyDomainState
            } else {
                return Data()
            }
        }
        return nil
    }()
    
    public static func auth(reason: String) -> Signal<(Bool, Data?), NoError> {
        return Signal { subscriber in
            let context = LAContext()
            
            if LAContext().canEvaluatePolicy(LAPolicy(rawValue: Int(kLAPolicyDeviceOwnerAuthenticationWithBiometrics))!, error: nil) {
                context.evaluatePolicy(LAPolicy(rawValue: Int(kLAPolicyDeviceOwnerAuthenticationWithBiometrics))!, localizedReason: reason, reply: { result, _ in
                    let evaluatedPolicyDomainState: Data?
                    if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                        evaluatedPolicyDomainState = context.evaluatedPolicyDomainState
                    } else {
                        evaluatedPolicyDomainState = Data()
                    }
                    subscriber.putNext((result, evaluatedPolicyDomainState))
                    subscriber.putCompletion()
                })
            } else {
                subscriber.putNext((false, nil))
                subscriber.putCompletion()
            }
            
            return ActionDisposable {
                if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                    context.invalidate()
                }
            }
        }
    }
}
