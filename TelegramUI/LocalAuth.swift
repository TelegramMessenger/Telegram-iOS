import Foundation
import LocalAuthentication
import SwiftSignalKit

enum LocalAuthBiometricAuthentication {
    case touchId
    case faceId
}

struct LocalAuth {
    static let biometricAuthentication: LocalAuthBiometricAuthentication? = {
        let context = LAContext()
        if context.canEvaluatePolicy(LAPolicy(rawValue: Int(kLAPolicyDeviceOwnerAuthenticationWithBiometrics))!, error: nil) {
            if #available(iOSApplicationExtension 11.0, *) {
                switch context.biometryType {
                    case .faceID:
                        return .faceId
                    case .touchID:
                        return .touchId
                    case .none:
                        return nil
                }
            } else {
                return .touchId
            }
        } else {
            return nil
        }
    }()
    
    static func auth(reason: String) -> Signal<Bool, NoError> {
        return Signal { subscriber in
            let context = LAContext()
            
            if LAContext().canEvaluatePolicy(LAPolicy(rawValue: Int(kLAPolicyDeviceOwnerAuthenticationWithBiometrics))!, error: nil) {
                context.evaluatePolicy(LAPolicy(rawValue: Int(kLAPolicyDeviceOwnerAuthenticationWithBiometrics))!, localizedReason: reason, reply: { result, _ in
                    subscriber.putNext(result)
                    subscriber.putCompletion()
                })
            } else {
                subscriber.putNext(false)
                subscriber.putCompletion()
            }
            
            return ActionDisposable {
                if #available(iOSApplicationExtension 9.0, *) {
                    context.invalidate()
                }
            }
        }
    }
}
