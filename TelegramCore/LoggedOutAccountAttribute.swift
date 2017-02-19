import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public final class LoggedOutAccountAttribute: AccountRecordAttribute {
    public init() {
    }
    
    public init(decoder: Decoder) {
    }
    
    public func encode(_ encoder: Encoder) {
    }
    
    public func isEqual(to: AccountRecordAttribute) -> Bool {
        return to is LoggedOutAccountAttribute
    }
}
