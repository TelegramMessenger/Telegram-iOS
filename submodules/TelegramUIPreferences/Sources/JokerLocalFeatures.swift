import Foundation

public struct JokerQuickReply: Codable, Equatable {
    public let id: String
    public let text: String

    public init(id: String, text: String) {
        self.id = id
        self.text = text
    }

    public static func ==(lhs: JokerQuickReply, rhs: JokerQuickReply) -> Bool {
        return lhs.id == rhs.id && lhs.text == rhs.text
    }
}

public enum JokerLocalFeatureKeys {
    public static let quickReplies = "joker_quick_replies_json"
    public static let greetingEnabled = "joker_greeting_enabled"
    public static let greetingText = "joker_greeting_text"
    public static let greetedPeers = "joker_greeting_sent_peers"
}

public func getJokerLocalQuickReplies() -> [JokerQuickReply] {
    guard let data = UserDefaults.standard.data(forKey: JokerLocalFeatureKeys.quickReplies) else {
        return []
    }
    return (try? JSONDecoder().decode([JokerQuickReply].self, from: data)) ?? []
}

public func saveJokerLocalQuickReplies(_ replies: [JokerQuickReply]) {
    let data = try? JSONEncoder().encode(replies)
    UserDefaults.standard.set(data, forKey: JokerLocalFeatureKeys.quickReplies)
    UserDefaults.standard.synchronize()
}

public func getJokerLocalGreeting() -> (enabled: Bool, text: String) {
    let enabled = UserDefaults.standard.bool(forKey: JokerLocalFeatureKeys.greetingEnabled)
    let text = UserDefaults.standard.string(forKey: JokerLocalFeatureKeys.greetingText) ?? ""
    return (enabled, text)
}

public func setJokerLocalGreeting(enabled: Bool, text: String) {
    UserDefaults.standard.set(enabled, forKey: JokerLocalFeatureKeys.greetingEnabled)
    UserDefaults.standard.set(text, forKey: JokerLocalFeatureKeys.greetingText)
    UserDefaults.standard.synchronize()
}

public func isJokerPeerGreeted(_ peerId: Int64) -> Bool {
    let peers = UserDefaults.standard.array(forKey: JokerLocalFeatureKeys.greetedPeers) as? [Int64] ?? []
    return peers.contains(peerId)
}

public func markJokerPeerGreeted(_ peerId: Int64) {
    var peers = UserDefaults.standard.array(forKey: JokerLocalFeatureKeys.greetedPeers) as? [Int64] ?? []
    if !peers.contains(peerId) {
        peers.append(peerId)
        UserDefaults.standard.set(peers, forKey: JokerLocalFeatureKeys.greetedPeers)
        UserDefaults.standard.synchronize()
    }
}
