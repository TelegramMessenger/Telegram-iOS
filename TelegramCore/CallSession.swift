import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

enum CallSessionState {
    case requested(a: MemoryBuffer, config: SecretChatEncryptionConfig)
    case accepting(gAHash: MemoryBuffer, b: MemoryBuffer, config: SecretChatEncryptionConfig)
    case confirming(a: MemoryBuffer, gB: MemoryBuffer, config: SecretChatEncryptionConfig)
    case active
}

