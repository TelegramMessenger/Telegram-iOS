import Foundation
import Postbox
import TelegramApi


public final class SelectivePrivacyPeer: Equatable {
    public let peer: Peer
    public let participantCount: Int32?
    
    public init(peer: Peer, participantCount: Int32?) {
        self.peer = peer
        self.participantCount = participantCount
    }
    
    public static func ==(lhs: SelectivePrivacyPeer, rhs: SelectivePrivacyPeer) -> Bool {
        if !lhs.peer.isEqual(rhs.peer) {
            return false
        }
        if lhs.participantCount != rhs.participantCount {
            return false
        }
        return true
    }
    
    public var userCount: Int {
        if let participantCount = self.participantCount {
            return Int(participantCount)
        } else if let group = self.peer as? TelegramGroup {
            return group.participantCount
        } else {
            return 1
        }
    }
}

public enum SelectivePrivacySettings: Equatable {
    case enableEveryone(disableFor: [PeerId: SelectivePrivacyPeer])
    case enableContacts(enableFor: [PeerId: SelectivePrivacyPeer], disableFor: [PeerId: SelectivePrivacyPeer])
    case disableEveryone(enableFor: [PeerId: SelectivePrivacyPeer])
    
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
    
    func withEnabledPeers(_ peers: [PeerId: SelectivePrivacyPeer]) -> SelectivePrivacySettings {
        switch self {
            case let .disableEveryone(enableFor):
                return .disableEveryone(enableFor: enableFor.merging(peers, uniquingKeysWith: { lhs, rhs in lhs }))
            case let .enableContacts(enableFor, disableFor):
                return .enableContacts(enableFor: enableFor.merging(peers, uniquingKeysWith: { lhs, rhs in lhs }), disableFor: disableFor)
            case .enableEveryone:
                return self
        }
    }
    
    func withDisabledPeers(_ peers: [PeerId: SelectivePrivacyPeer]) -> SelectivePrivacySettings {
        switch self {
            case .disableEveryone:
                return self
            case let .enableContacts(enableFor, disableFor):
                return .enableContacts(enableFor: enableFor, disableFor: disableFor.merging(peers, uniquingKeysWith: { lhs, rhs in lhs }))
            case let .enableEveryone(disableFor):
                return .enableEveryone(disableFor: disableFor.merging(peers, uniquingKeysWith: { lhs, rhs in lhs }))
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
    public let phoneNumber: SelectivePrivacySettings
    public let phoneDiscoveryEnabled: Bool
    public let voiceMessages: SelectivePrivacySettings
    
    public let automaticallyArchiveAndMuteNonContacts: Bool
    public let accountRemovalTimeout: Int32
    
    public init(presence: SelectivePrivacySettings, groupInvitations: SelectivePrivacySettings, voiceCalls: SelectivePrivacySettings, voiceCallsP2P: SelectivePrivacySettings, profilePhoto: SelectivePrivacySettings, forwards: SelectivePrivacySettings, phoneNumber: SelectivePrivacySettings, phoneDiscoveryEnabled: Bool, voiceMessages: SelectivePrivacySettings, automaticallyArchiveAndMuteNonContacts: Bool, accountRemovalTimeout: Int32) {
        self.presence = presence
        self.groupInvitations = groupInvitations
        self.voiceCalls = voiceCalls
        self.voiceCallsP2P = voiceCallsP2P
        self.profilePhoto = profilePhoto
        self.forwards = forwards
        self.phoneNumber = phoneNumber
        self.phoneDiscoveryEnabled = phoneDiscoveryEnabled
        self.voiceMessages = voiceMessages
        self.automaticallyArchiveAndMuteNonContacts = automaticallyArchiveAndMuteNonContacts
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
        if lhs.phoneNumber != rhs.phoneNumber {
            return false
        }
        if lhs.phoneDiscoveryEnabled != rhs.phoneDiscoveryEnabled {
            return false
        }
        if lhs.voiceMessages != rhs.voiceMessages {
            return false
        }
        if lhs.automaticallyArchiveAndMuteNonContacts != rhs.automaticallyArchiveAndMuteNonContacts {
            return false
        }
        if lhs.accountRemovalTimeout != rhs.accountRemovalTimeout {
            return false
        }
        
        return true
    }
}

extension SelectivePrivacySettings {
    init(apiRules: [Api.PrivacyRule], peers: [PeerId: SelectivePrivacyPeer]) {
        var current: SelectivePrivacySettings = .disableEveryone(enableFor: [:])
        
        var disableFor: [PeerId: SelectivePrivacyPeer] = [:]
        var enableFor: [PeerId: SelectivePrivacyPeer] = [:]
        
        for rule in apiRules {
            switch rule {
                case .privacyValueAllowAll:
                    current = .enableEveryone(disableFor: [:])
                case .privacyValueAllowContacts:
                    current = .enableContacts(enableFor: [:], disableFor: [:])
                case let .privacyValueAllowUsers(users):
                    for id in users {
                        if let peer = peers[PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id))] {
                            enableFor[peer.peer.id] = peer
                        }
                    }
                case .privacyValueDisallowAll:
                    break
                case .privacyValueDisallowContacts:
                    break
                case let .privacyValueDisallowUsers(users):
                    for id in users {
                        if let peer = peers[PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id))] {
                            disableFor[peer.peer.id] = peer
                        }
                    }
                case let .privacyValueAllowChatParticipants(chats):
                    for id in chats {
                        for possibleId in [PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(id)), PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(id))] {
                            if let peer = peers[possibleId] {
                                enableFor[peer.peer.id] = peer
                            }
                        }
                    }
                case let .privacyValueDisallowChatParticipants(chats):
                    for id in chats {
                        for possibleId in [PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(id)), PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(id))] {
                            if let peer = peers[possibleId] {
                                disableFor[peer.peer.id] = peer
                            }
                        }
                    }
            }
        }
        
        self = current.withEnabledPeers(enableFor).withDisabledPeers(disableFor)
    }
}
