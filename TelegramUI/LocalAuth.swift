import Foundation
import LocalAuthentication
import SwiftSignalKit

struct LocalAuth {
    static let isTouchIDAvailable: Bool = {
        return LAContext().canEvaluatePolicy(LAPolicy(rawValue: Int(kLAPolicyDeviceOwnerAuthenticationWithBiometrics))!, error: nil)
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
