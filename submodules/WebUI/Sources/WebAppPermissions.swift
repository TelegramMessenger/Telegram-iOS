import Foundation
import NaturalLanguage
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramUIPreferences

public struct WebAppPermissionsState: Codable {
    enum CodingKeys: String, CodingKey {
        case location
        case emojiStatus
    }
    
    public struct Location: Codable {
        enum CodingKeys: String, CodingKey {
            case isRequested
            case isAllowed
        }
        
        public let isRequested: Bool
        public let isAllowed: Bool
        
        public init(
            isRequested: Bool,
            isAllowed: Bool
        ) {
            self.isRequested = isRequested
            self.isAllowed = isAllowed
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.isRequested = try container.decode(Bool.self, forKey: .isRequested)
            self.isAllowed = try container.decode(Bool.self, forKey: .isAllowed)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(self.isRequested, forKey: .isRequested)
            try container.encode(self.isAllowed, forKey: .isAllowed)
        }
    }
    
    public struct EmojiStatus: Codable {
        enum CodingKeys: String, CodingKey {
            case isRequested
        }
        
        public let isRequested: Bool
        
        public init(
            isRequested: Bool
        ) {
            self.isRequested = isRequested
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.isRequested = try container.decode(Bool.self, forKey: .isRequested)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(self.isRequested, forKey: .isRequested)
        }
    }
        
    public let location: Location?
    public let emojiStatus: EmojiStatus?
    
    public init(
        location: Location?,
        emojiStatus: EmojiStatus?
    ) {
        self.location = location
        self.emojiStatus = emojiStatus
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.location = try container.decodeIfPresent(WebAppPermissionsState.Location.self, forKey: .location)
        self.emojiStatus = try container.decodeIfPresent(WebAppPermissionsState.EmojiStatus.self, forKey: .emojiStatus)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(self.location, forKey: .location)
        try container.encodeIfPresent(self.emojiStatus, forKey: .emojiStatus)
    }
}

public func webAppPermissionsState(context: AccountContext, peerId: EnginePeer.Id) -> Signal<WebAppPermissionsState?, NoError> {
    let key = EngineDataBuffer(length: 8)
    key.setInt64(0, value: peerId.id._internalGetInt64Value())
    
    return context.engine.data.subscribe(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: ApplicationSpecificItemCacheCollectionId.webAppPermissionsState, id: key))
    |> map { entry -> WebAppPermissionsState? in
        return entry?.get(WebAppPermissionsState.self)
    }
}

private func updateWebAppPermissionsState(context: AccountContext, peerId: EnginePeer.Id, state: WebAppPermissionsState?) -> Signal<Never, NoError> {
    let key = EngineDataBuffer(length: 8)
    key.setInt64(0, value: peerId.id._internalGetInt64Value())
    
    if let state {
        return context.engine.itemCache.put(collectionId: ApplicationSpecificItemCacheCollectionId.webAppPermissionsState, id: key, item: state)
    } else {
        return context.engine.itemCache.remove(collectionId: ApplicationSpecificItemCacheCollectionId.webAppPermissionsState, id: key)
    }
}

public func updateWebAppPermissionsStateInteractively(context: AccountContext, peerId: EnginePeer.Id, _ f: @escaping (WebAppPermissionsState?) -> WebAppPermissionsState?) -> Signal<Never, NoError> {
    let key = EngineDataBuffer(length: 8)
    key.setInt64(0, value: peerId.id._internalGetInt64Value())
    
    return context.engine.data.get(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: ApplicationSpecificItemCacheCollectionId.webAppPermissionsState, id: key))
    |> map { entry -> WebAppPermissionsState? in
        return entry?.get(WebAppPermissionsState.self)
    }
    |> mapToSignal { current -> Signal<Never, NoError> in
        return updateWebAppPermissionsState(context: context, peerId: peerId, state: f(current))
    }
}
