import Foundation
#if os(macOS)
    import SwiftSignalKitMac
#else
    import SwiftSignalKit
#endif

public enum PostboxAuthorizationChallenge {
    case numericPassword(length: Int32)
    case arbitraryPassword()
}

public enum PostboxAccess {
    case unlocked(Postbox)
    case locked(PostboxAuthorizationChallenge)
}

public func accessPostbox(basePath: String, password: String?) -> Signal<PostboxAccess, NoError> {
    return Signal { subscriber in
        return ActionDisposable {
        }
    }
}
