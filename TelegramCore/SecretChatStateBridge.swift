import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public enum SecretChatBridgeRole: Int32 {
    case creator
    case participant
}

public struct SecretChatStateBridge {
    public let role:SecretChatBridgeRole
    public init(role: SecretChatBridgeRole) {
        self.role = role
    }
    
    public var state: PeerChatState {
        return SecretChatState(role: SecretChatRole(rawValue: role.rawValue)!, embeddedState: .terminated, keychain: SecretChatKeychain(keys: []), keyFingerprint: nil, messageAutoremoveTimeout: nil)
    }
}
