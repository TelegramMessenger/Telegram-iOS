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
    
    init(decoder: PostboxDecoder) {
    }
    
    func encode(_ encoder: PostboxEncoder) {
    }
    
    func isEqual(to: PendingMessageActionData) -> Bool {
        if let _ = to as? ConsumePersonalMessageAction {
            return true
        } else {
            return false
        }
    }
}
