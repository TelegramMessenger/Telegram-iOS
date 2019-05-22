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
    
    func withEnabledPeerIds(_ peerIds: Set<PeerId>) -> SelectivePrivacySettings {
        switch self {
            case let .disableEveryone(enableFor):
                return .disableEveryone(enableFor: enableFor.union(peerIds))
            case let .enableContacts(enableFor, disableFor):
                return .enableContacts(enableFor: enableFor.union(peerIds), disableFor: disableFor)
            case .enableEveryone:
                return self
        }
    }
    
    func withDisabledPeerIds(_ peerIds: Set<PeerId>) -> SelectivePrivacySettings {
        switch self {
            case .disableEveryone:
                return self
            case let .enableContacts(enableFor, disableFor):
                return .enableContacts(enableFor: enableFor, disableFor: disableFor.union(peerIds))
            case let .enableEveryone(disableFor):
                return .enableEveryone(disableFor: disableFor.union(peerIds))
        }
    }
}

public struct AccountPrivacySettings: Equatable {
    public let presence: SelectivePrivacySettings
    public let groupInvitations: SelectivePrivacySettings
    public let voiceCalls: SelectivePrivacySettings
    public let voiceCallsP2P: SelectivePrivacySettings
    public let profilePhoto: SelectivePrivacySettings
    public let forwards: SelectivePrivacySettings
    
    public let accountRemovalTimeout: Int32
    
    public init(presence: SelectivePrivacySettings, groupInvitations: SelectivePrivacySettings, voiceCalls: SelectivePrivacySettings, voiceCallsP2P: SelectivePrivacySettings, profilePhoto: SelectivePrivacySettings, forwards: SelectivePrivacySettings, accountRemovalTimeout: Int32) {
        self.presence = presence
        self.groupInvitations = groupInvitations
        self.voiceCalls = voiceCalls
        self.voiceCallsP2P = voiceCallsP2P
        self.profilePhoto = profilePhoto
        self.forwards = forwards
        self.accountRemovalTimeout = accountRemovalTimeout
    }
    
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
        if lhs.voiceCallsP2P != rhs.voiceCallsP2P {
            return false
        }
        if lhs.profilePhoto != rhs.profilePhoto {
            return false
        }
        if lhs.forwards != rhs.forwards {
            return false
        }
        if lhs.accountRemovalTimeout != rhs.accountRemovalTimeout {
            return false
        }
        
        return true
    }
}

extension SelectivePrivacySettings {
    init(apiRules: [Api.PrivacyRule]) {
        var current: SelectivePrivacySettings = .disableEveryone(enableFor: Set())
        
        var disableFor = Set<PeerId>()
        var enableFor = Set<PeerId>()
        
        for rule in apiRules {
            switch rule {
                case .privacyValueAllowAll:
                    current = .enableEveryone(disableFor: Set())
                case .privacyValueAllowContacts:
                    current = .enableContacts(enableFor: Set(), disableFor: Set())
                case let .privacyValueAllowUsers(users):
                    enableFor = Set(users.map { PeerId(namespace: Namespaces.Peer.CloudUser, id: $0) })
                case .privacyValueDisallowAll:
                    //current = .disableEveryone(enableFor: Set())
                    break
                case .privacyValueDisallowContacts:
                    break
                case let .privacyValueDisallowUsers(users):
                    disableFor = Set(users.map { PeerId(namespace: Namespaces.Peer.CloudUser, id: $0) })
            }
        }
        
        self = current.withEnabledPeerIds(enableFor).withDisabledPeerIds(disableFor)
    }
}
