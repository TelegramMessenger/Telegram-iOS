import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public enum SelectivePrivacySettings {
    case enableEveryone(disableFor: [PeerId])
    case enableContacts(enableFor: [PeerId], disableFor: [PeerId])
    case disableEveryone(enableFor: [PeerId])
}

public struct AccountPrivacySettings {
    public let presence: SelectivePrivacySettings
    public let groupInvitations: SelectivePrivacySettings
}
