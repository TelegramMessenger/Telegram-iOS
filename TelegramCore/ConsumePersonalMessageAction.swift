import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

final class ConsumePersonalMessageAction: PendingMessageActionData {
    init() {
    }
    
    init(decoder: Decoder) {
    }
    
    func encode(_ encoder: Encoder) {
    }
    
    func isEqual(to: PendingMessageActionData) -> Bool {
        if let _ = to as? ConsumePersonalMessageAction {
            return true
        } else {
            return false
        }
    }
}
