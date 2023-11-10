import Foundation
import UIKit

public final class ManagedAnimations {
    private var displayLinkSubscription: SharedDisplayLink.Subscription?
    
    private var properties: [AnyAnimatedProperty] = []
    
    public var updated: (() -> Void)?
    
    public init() {
    }
    
    public func add(property: AnyAnimatedProperty) {
        self.properties.append(property)
        property.didStartAnimation = { [weak self] in
            guard let self else {
                return
            }
            self.updateNeedAnimations()
        }
    }
    
    private func updateNeedAnimations() {
        if self.displayLinkSubscription == nil {
            self.displayLinkSubscription = SharedDisplayLink.shared.add { [weak self] in
                guard let self else {
                    return
                }
                self.update()
            }
        }
    }
    
    private func update() {
        var hasRunningAnimations = false
        for property in self.properties {
            property.update()
            if property.hasRunningAnimation {
                hasRunningAnimations = true
            }
        }
        
        if !hasRunningAnimations {
            self.displayLinkSubscription = nil
        }
        
        self.updated?()
    }
}
