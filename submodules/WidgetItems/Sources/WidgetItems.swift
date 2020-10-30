import Foundation

public enum WidgetCodingError: Error {
    case generic
}

public struct WidgetDataPeer: Codable, Equatable {
    public struct Badge: Codable, Equatable {
        public var count: Int
        public var isMuted: Bool
        
        public init(count: Int, isMuted: Bool) {
            self.count = count
            self.isMuted = isMuted
        }
    }
    
    public var id: Int64
    public var name: String
    public var lastName: String?
    public var letters: [String]
    public var avatarPath: String?
    public var badge: Badge?
    
    public init(id: Int64, name: String, lastName: String?, letters: [String], avatarPath: String?, badge: Badge?) {
        self.id = id
        self.name = name
        self.lastName = lastName
        self.letters = letters
        self.avatarPath = avatarPath
        self.badge = badge
    }
}

public struct WidgetDataPeers: Codable, Equatable {
    public var accountPeerId: Int64
    public var peers: [WidgetDataPeer]
    
    public init(accountPeerId: Int64, peers: [WidgetDataPeer]) {
        self.accountPeerId = accountPeerId
        self.peers = peers
    }
}

public struct WidgetPresentationData: Codable, Equatable {
    public var applicationLockedString: String
    public var applicationStartRequiredString: String
    public var widgetGalleryTitle: String
    public var widgetGalleryDescription: String
    
    public init(applicationLockedString: String, applicationStartRequiredString: String, widgetGalleryTitle: String, widgetGalleryDescription: String) {
        self.applicationLockedString = applicationLockedString
        self.applicationStartRequiredString = applicationStartRequiredString
        self.widgetGalleryTitle = widgetGalleryTitle
        self.widgetGalleryDescription = widgetGalleryDescription
    }
}

public func widgetPresentationDataPath(rootPath: String) -> String {
    return rootPath + "/widgetPresentationData.json"
}

public enum WidgetData: Codable, Equatable {
    private enum CodingKeys: CodingKey {
        case discriminator
        case peers
    }
    
    private enum Cases: Int32, Codable {
        case notAuthorized
        case disabled
        case peers
    }
    
    case notAuthorized
    case disabled
    case peers(WidgetDataPeers)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let discriminator = try container.decode(Cases.self, forKey: .discriminator)
        switch discriminator {
        case .notAuthorized:
            self = .notAuthorized
        case .disabled:
            self = .disabled
        case .peers:
            self = .peers(try container.decode(WidgetDataPeers.self, forKey: .peers))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .notAuthorized:
            try container.encode(Cases.notAuthorized, forKey: .discriminator)
        case .disabled:
            try container.encode(Cases.disabled, forKey: .discriminator)
        case let .peers(peers):
            try container.encode(Cases.peers, forKey: .discriminator)
            try container.encode(peers, forKey: .peers)
        }
    }
}
