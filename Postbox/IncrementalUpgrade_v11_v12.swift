import Foundation

#if os(macOS)
    import SwiftSignalKitMac
#else
    import SwiftSignalKit
#endif

final class IncrementalUpgrade_v11_v12: IncrementalUpgrade {
    func upgrade(from previous: ValueBox, tmpBasePath: String) -> Signal<ValueBox, NoError> {
        assertionFailure()
        
        return .never()
    }
}
