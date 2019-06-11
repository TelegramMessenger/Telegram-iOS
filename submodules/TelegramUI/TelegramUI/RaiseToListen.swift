import Foundation

import TelegramUIPrivateModule

final class RaiseToListenManager {
    private let activator: RaiseToListenActivator
    
    var enabled: Bool = false {
        didSet {
            self.activator.enabled = self.enabled
        }
    }
    
    init(shouldActivate: @escaping () -> Bool, activate: @escaping () -> Void, deactivate: @escaping () -> Void) {
        self.activator = RaiseToListenActivator(shouldActivate: {
            return shouldActivate()
        }, activate: {
            return activate()
        }, deactivate: {
            return deactivate()
        })
    }
    
    func activateBasedOnProximity(delay: Double) {
        self.activator.activateBasedOnProximity(withDelay: delay)
    }
    
    func applicationResignedActive() {
        self.activator.applicationResignedActive()
    }
}
