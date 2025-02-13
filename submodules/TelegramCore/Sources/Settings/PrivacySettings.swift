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
    case enableContacts(enableFor: [PeerId: SelectivePrivacyPeer], disableFor: [PeerId: SelectivePrivacyPeer], enableForPremium: Bool, enableForBots: Bool)
    case disableEveryone(enableFor: [PeerId: SelectivePrivacyPeer], enableForCloseFriends: Bool, enableForPremium: Bool, enableForBots: Bool)
    
    public static func ==(lhs: SelectivePrivacySettings, rhs: SelectivePrivacySettings) -> Bool {
        switch lhs {
            case let .enableEveryone(disableFor):
                if case .enableEveryone(disableFor) = rhs {
                    return true
                } else {
                    return false
                }
            case let .enableContacts(enableFor, disableFor, enableForPremium, enableForBots):
                if case .enableContacts(enableFor, disableFor, enableForPremium, enableForBots) = rhs {
                    return true
                } else {
                    return false
                }
            case let .disableEveryone(enableFor, enableForCloseFriends, enableForPremium, enableForBots):
                if case .disableEveryone(enableFor, enableForCloseFriends, enableForPremium, enableForBots) = rhs {
                    return true
                } else {
                    return false
            }
        }
    }
    
    func withEnabledPeers(_ peers: [PeerId: SelectivePrivacyPeer]) -> SelectivePrivacySettings {
        switch self {
            case let .disableEveryone(enableFor, enableForCloseFriends, enableForPremium, enableForBots):
                return .disableEveryone(enableFor: enableFor.merging(peers, uniquingKeysWith: { lhs, rhs in lhs }), enableForCloseFriends: enableForCloseFriends, enableForPremium: enableForPremium, enableForBots: enableForBots)
            case let .enableContacts(enableFor, disableFor, enableForPremium, enableForBots):
                return .enableContacts(enableFor: enableFor.merging(peers, uniquingKeysWith: { lhs, rhs in lhs }), disableFor: disableFor, enableForPremium: enableForPremium, enableForBots: enableForBots)
            case .enableEveryone:
                return self
        }
    }
    
    func withDisabledPeers(_ peers: [PeerId: SelectivePrivacyPeer]) -> SelectivePrivacySettings {
        switch self {
            case .disableEveryone:
                return self
            case let .enableContacts(enableFor, disableFor, enableForPremium, enableForBots):
                return .enableContacts(enableFor: enableFor, disableFor: disableFor.merging(peers, uniquingKeysWith: { lhs, rhs in lhs }), enableForPremium: enableForPremium, enableForBots: enableForBots)
            case let .enableEveryone(disableFor):
                return .enableEveryone(disableFor: disableFor.merging(peers, uniquingKeysWith: { lhs, rhs in lhs }))
        }
    }
    
    func withEnableForPremium(_ enableForPremium: Bool) -> SelectivePrivacySettings {
        switch self {
        case let .disableEveryone(enableFor, enableForCloseFriends, _, enableForBots):
            return .disableEveryone(enableFor: enableFor, enableForCloseFriends: enableForCloseFriends, enableForPremium: enableForPremium, enableForBots: enableForBots)
        case let .enableContacts(enableFor, disableFor, _, enableForBots):
            return .enableContacts(enableFor: enableFor, disableFor: disableFor, enableForPremium: enableForPremium, enableForBots: enableForBots)
        case .enableEveryone:
            return self
        }
    }
    
    func withEnableForCloseFriends(_ enableForCloseFriends: Bool) -> SelectivePrivacySettings {
        switch self {
        case let .disableEveryone(enableFor, _, enableForPremium, enableForBots):
            return .disableEveryone(enableFor: enableFor, enableForCloseFriends: enableForCloseFriends, enableForPremium: enableForPremium, enableForBots: enableForBots)
        case .enableContacts:
            return self
        case .enableEveryone:
            return self
        }
    }
    
    func withEnableForBots(_ enableForBots: Bool?) -> SelectivePrivacySettings {
        switch self {
        case let .disableEveryone(enableFor, enableForCloseFriends, enableForPremium, _):
            return .disableEveryone(enableFor: enableFor, enableForCloseFriends: enableForCloseFriends, enableForPremium: enableForPremium, enableForBots: enableForBots == true)
        case let .enableContacts(enableFor, disableFor, enableForPremium, _):
            return .enableContacts(enableFor: enableFor, disableFor: disableFor, enableForPremium: enableForPremium, enableForBots: enableForBots == true)
        case let .enableEveryone(disableFor):
            return .enableEveryone(disableFor: disableFor)
        }
    }
}

public struct AccountPrivacySettings: Equatable {
    public var presence: SelectivePrivacySettings
    public var groupInvitations: SelectivePrivacySettings
    public var voiceCalls: SelectivePrivacySettings
    public var voiceCallsP2P: SelectivePrivacySettings
    public var profilePhoto: SelectivePrivacySettings
    public var forwards: SelectivePrivacySettings
    public var phoneNumber: SelectivePrivacySettings
    public var phoneDiscoveryEnabled: Bool
    public var voiceMessages: SelectivePrivacySettings
    public var bio: SelectivePrivacySettings
    public var birthday: SelectivePrivacySettings
    public var giftsAutoSave: SelectivePrivacySettings
    public var noPaidMessages: SelectivePrivacySettings
    
    public var globalSettings: GlobalPrivacySettings
    public var accountRemovalTimeout: Int32
    public var messageAutoremoveTimeout: Int32?
    
    public init(presence: SelectivePrivacySettings, groupInvitations: SelectivePrivacySettings, voiceCalls: SelectivePrivacySettings, voiceCallsP2P: SelectivePrivacySettings, profilePhoto: SelectivePrivacySettings, forwards: SelectivePrivacySettings, phoneNumber: SelectivePrivacySettings, phoneDiscoveryEnabled: Bool, voiceMessages: SelectivePrivacySettings, bio: SelectivePrivacySettings, birthday: SelectivePrivacySettings, giftsAutoSave: SelectivePrivacySettings, noPaidMessages: SelectivePrivacySettings, globalSettings: GlobalPrivacySettings, accountRemovalTimeout: Int32, messageAutoremoveTimeout: Int32?) {
        self.presence = presence
        self.groupInvitations = groupInvitations
        self.voiceCalls = voiceCalls
        self.voiceCallsP2P = voiceCallsP2P
        self.profilePhoto = profilePhoto
        self.forwards = forwards
        self.phoneNumber = phoneNumber
        self.phoneDiscoveryEnabled = phoneDiscoveryEnabled
        self.voiceMessages = voiceMessages
        self.bio = bio
        self.birthday = birthday
        self.giftsAutoSave = giftsAutoSave
        self.noPaidMessages = noPaidMessages
        self.globalSettings = globalSettings
        self.accountRemovalTimeout = accountRemovalTimeout
        self.messageAutoremoveTimeout = messageAutoremoveTimeout
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
        if lhs.bio != rhs.bio {
            return false
        }
        if lhs.birthday != rhs.birthday {
            return false
        }
        if lhs.giftsAutoSave != rhs.giftsAutoSave {
            return false
        }
        if lhs.noPaidMessages != rhs.noPaidMessages {
            return false
        }
        if lhs.globalSettings != rhs.globalSettings {
            return false
        }
        if lhs.accountRemovalTimeout != rhs.accountRemovalTimeout {
            return false
        }
        if lhs.messageAutoremoveTimeout != rhs.messageAutoremoveTimeout {
            return false
        }
        
        return true
    }
}

extension SelectivePrivacySettings {
    init(apiRules: [Api.PrivacyRule], peers: [PeerId: SelectivePrivacyPeer]) {
        var current: SelectivePrivacySettings = .disableEveryone(enableFor: [:], enableForCloseFriends: false, enableForPremium: false, enableForBots: false)
        
        var disableFor: [PeerId: SelectivePrivacyPeer] = [:]
        var enableFor: [PeerId: SelectivePrivacyPeer] = [:]
        var enableForCloseFriends: Bool = false
        var enableForPremium: Bool = false
        var enableForBots: Bool?
        
        for rule in apiRules {
            switch rule {
                case .privacyValueAllowAll:
                    current = .enableEveryone(disableFor: [:])
                case .privacyValueAllowContacts:
                    current = .enableContacts(enableFor: [:], disableFor: [:], enableForPremium: false, enableForBots: false)
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
                case .privacyValueAllowCloseFriends:
                    enableForCloseFriends = true
                case .privacyValueAllowPremium:
                    enableForPremium = true
                case .privacyValueAllowBots:
                    enableForBots = true
                case .privacyValueDisallowBots:
                    break
            }
        }
        
        self = current.withEnabledPeers(enableFor).withDisabledPeers(disableFor).withEnableForCloseFriends(enableForCloseFriends).withEnableForPremium(enableForPremium).withEnableForBots(enableForBots)
    }
}

public struct GlobalMessageAutoremoveTimeoutSettings: Equatable, Codable {
    public static var `default` = GlobalMessageAutoremoveTimeoutSettings(
        messageAutoremoveTimeout: nil
    )

    public var messageAutoremoveTimeout: Int32?

    public init(messageAutoremoveTimeout: Int32?) {
        self.messageAutoremoveTimeout = messageAutoremoveTimeout
    }
}

func updateGlobalMessageAutoremoveTimeoutSettings(transaction: Transaction, _ f: (GlobalMessageAutoremoveTimeoutSettings) -> GlobalMessageAutoremoveTimeoutSettings) {
    transaction.updatePreferencesEntry(key: PreferencesKeys.globalMessageAutoremoveTimeoutSettings, { current in
        let previous = current?.get(GlobalMessageAutoremoveTimeoutSettings.self) ?? GlobalMessageAutoremoveTimeoutSettings.default
        let updated = f(previous)
        return PreferencesEntry(updated)
    })
}

public struct GlobalPrivacySettings: Equatable, Codable {
    public enum NonContactChatsPrivacy: Equatable, Codable {
        case everybody
        case requirePremium
        case paidMessages(StarsAmount)
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: StringCodingKey.self)

            switch (try? container.decode(Int32.self, forKey: "t")) ?? 0 {
            case 0:
                self = .everybody
            case 1:
                self = .requirePremium
            case 2:
                self = .paidMessages(StarsAmount(value: try container.decodeIfPresent(Int64.self, forKey: "stars") ?? 0, nanos: 0))
            default:
                assertionFailure()
                self = .everybody
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: StringCodingKey.self)
            switch self {
            case .everybody:
                try container.encode(0 as Int32, forKey: "t")
            case .requirePremium:
                try container.encode(1 as Int32, forKey: "t")
            case let .paidMessages(amount):
                try container.encode(2 as Int32, forKey: "t")
                try container.encode(amount.value, forKey: "stars")
            }
        }
    }
    
    public static var `default` = GlobalPrivacySettings(
        automaticallyArchiveAndMuteNonContacts: false,
        keepArchivedUnmuted: true,
        keepArchivedFolders: true,
        hideReadTime: false,
        nonContactChatsPrivacy: .everybody
    )

    public var automaticallyArchiveAndMuteNonContacts: Bool
    public var keepArchivedUnmuted: Bool
    public var keepArchivedFolders: Bool
    public var hideReadTime: Bool
    public var nonContactChatsPrivacy: NonContactChatsPrivacy

    public init(
        automaticallyArchiveAndMuteNonContacts: Bool,
        keepArchivedUnmuted: Bool,
        keepArchivedFolders: Bool,
        hideReadTime: Bool,
        nonContactChatsPrivacy: NonContactChatsPrivacy
    ) {
        self.automaticallyArchiveAndMuteNonContacts = automaticallyArchiveAndMuteNonContacts
        self.keepArchivedUnmuted = keepArchivedUnmuted
        self.keepArchivedFolders = keepArchivedFolders
        self.hideReadTime = hideReadTime
        self.nonContactChatsPrivacy = nonContactChatsPrivacy
    }
}

func fetchGlobalPrivacySettings(transaction: Transaction) -> GlobalPrivacySettings {
    return transaction.getPreferencesEntry(key: PreferencesKeys.globalPrivacySettings)?.get(GlobalPrivacySettings.self) ?? GlobalPrivacySettings.default
}

func updateGlobalPrivacySettings(transaction: Transaction, _ f: (GlobalPrivacySettings) -> GlobalPrivacySettings) {
    transaction.updatePreferencesEntry(key: PreferencesKeys.globalPrivacySettings, { current in
        let previous = current?.get(GlobalPrivacySettings.self) ?? GlobalPrivacySettings.default
        let updated = f(previous)
        return PreferencesEntry(updated)
    })
}
