import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public protocol TelegramMediaResource: MediaResource, PostboxCoding {
}
