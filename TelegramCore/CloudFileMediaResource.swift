import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public class CloudFileMediaResource: MediaResource {
    public var id: String {
        return self.location.uniqueId
    }
    public let location: TelegramMediaLocation
    public let size: Int
    
    public init(location: TelegramMediaLocation, size: Int) {
        self.location = location
        self.size = size
    }
}
