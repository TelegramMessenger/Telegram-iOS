import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public enum SelectivePrivacySettings: Equatable {
    case enableEveryone(disableFor: Set<PeerId>)
    case enableContacts(enableFor: Set<PeerId>, disableFor: Set<PeerId>)
    case disableEveryone(enableFor: Set<PeerId>)
    
    public static func ==(lhs: SelectivePrivacySettings, rhs: SelectivePrivacySettings) -> Bool {
        switch lhs {
            case let .enableEveryone(disableFor):
                if case .enableEveryone(disableFor) = rhs {
                    return true
                } else {
                    return false
                }
            case let .enableContacts(enableFor, disableFor):
                if case .enableContacts(enableFor, disableFor) = rhs {
                    return true
                } else {
                    return false
                }
            case let .disableEveryone(enableFor):
                if case .disableEveryone(enableFor) = rhs {
                    return true
                } else {
                    return false
            }
        }
    }
}

public struct AccountPrivacySettings: Equatable {
    public let presence: SelectivePrivacySettings
    public let groupInvitations: SelectivePrivacySettings
    public let voiceCalls: SelectivePrivacySettings
    
    public let accountRemovalTimeout: Int32
    
    public static func ==(lhs: AccountPrivacySettings, rhs: AccountPrivacySettings) -> Bool {
        if lhs.presence != rhs.presence {
            return false
        }
        if lhs.groupInvitations != rhs.groupInvitations {
            return false
        }
        if lhs.voiceCalls != rhs.voiceCalls {
            return false
        }
        
        if lhs.accountRemovalTimeout != rhs.accountRemovalTimeout {
            return false
        }
        
        return true
    }
}
