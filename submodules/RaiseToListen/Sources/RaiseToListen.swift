import Foundation

import RaiseToListenImpl

public final class RaiseToListenManager {
    private let activator: RaiseToListenActivator
    
    public var enabled: Bool = false {
        didSet {
            self.activator.enabled = self.enabled
        }
    }
    
    public init(shouldActivate: @escaping () -> Bool, activate: @escaping () -> Void, deactivate: @escaping () -> Void) {
        self.activator = RaiseToListenActivator(shouldActivate: {
            return shouldActivate()
        }, activate: {
            return activate()
        }, deactivate: {
            return deactivate()
        })
    }
    
    public func activateBasedOnProximity(delay: Double) {
        self.activator.activateBasedOnProximity(withDelay: delay)
    }
    
    public func applicationResignedActive() {
        self.activator.applicationResignedActive()
    }
}
