import Foundation
#if os(macOS)
    import SwiftSignalKitMac
#else
    import SwiftSignalKit
#endif

protocol IncrementalUpgrade {
    func upgrade(from previous: ValueBox, tmpBasePath: String) -> Signal<ValueBox, NoError>
}
