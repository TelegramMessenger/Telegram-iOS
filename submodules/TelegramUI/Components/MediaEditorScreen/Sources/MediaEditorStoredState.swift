import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences
import MediaEditor

public final class MediaEditorStoredTextSettings: Codable {
    private enum CodingKeys: String, CodingKey {
        case style
        case font
        case fontSize
        case alignment
    }
    
    public let style: DrawingTextEntity.Style
    public let font: DrawingTextEntity.Font
    public let fontSize: CGFloat
    public let alignment: DrawingTextEntity.Alignment
    
    public init(
        style: DrawingTextEntity.Style,
        font: DrawingTextEntity.Font,
        fontSize: CGFloat,
        alignment: DrawingTextEntity.Alignment
    ) {
        self.style = style
        self.font = font
        self.fontSize = fontSize
        self.alignment = alignment
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.style = try container.decode(DrawingTextEntity.Style.self, forKey: .style)
        self.font = try container.decode(DrawingTextEntity.Font.self, forKey: .font)
        self.fontSize = try container.decode(CGFloat.self, forKey: .fontSize)
        self.alignment = try container.decode(DrawingTextEntity.Alignment.self, forKey: .alignment)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.style, forKey: .style)
        try container.encode(self.font, forKey: .font)
        try container.encode(self.fontSize, forKey: .fontSize)
        try container.encode(self.alignment, forKey: .alignment)
    }
}

public final class MediaEditorStoredState: Codable {
    private enum CodingKeys: String, CodingKey {
        case privacy
        case textSettings
    }
    
    public let privacy: MediaEditorResultPrivacy?
    public let textSettings: MediaEditorStoredTextSettings?
    
    public init(privacy: MediaEditorResultPrivacy?, textSettings: MediaEditorStoredTextSettings?) {
        self.privacy = privacy
        self.textSettings = textSettings
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let data = try container.decodeIfPresent(Data.self, forKey: .privacy), let privacy = try? JSONDecoder().decode(MediaEditorResultPrivacy.self, from: data) {
            self.privacy = privacy
        } else {
            self.privacy = nil
        }
        if let data = try container.decodeIfPresent(Data.self, forKey: .textSettings), let privacy = try? JSONDecoder().decode(MediaEditorStoredTextSettings.self, from: data) {
            self.textSettings = privacy
        } else {
            self.textSettings = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if let privacy = self.privacy {
            if let data = try? JSONEncoder().encode(privacy) {
                try container.encode(data, forKey: .privacy)
            } else {
                try container.encodeNil(forKey: .privacy)
            }
        } else {
            try container.encodeNil(forKey: .privacy)
        }
        
        if let textSettings = self.textSettings {
            if let data = try? JSONEncoder().encode(textSettings) {
                try container.encode(data, forKey: .textSettings)
            } else {
                try container.encodeNil(forKey: .textSettings)
            }
        } else {
            try container.encodeNil(forKey: .textSettings)
        }
    }
    
    public func withUpdatedPrivacy(_ privacy: MediaEditorResultPrivacy) -> MediaEditorStoredState {
        return MediaEditorStoredState(privacy: privacy, textSettings: self.textSettings)
    }
    
    public func withUpdatedTextSettings(_ textSettings: MediaEditorStoredTextSettings) -> MediaEditorStoredState {
        return MediaEditorStoredState(privacy: self.privacy, textSettings: textSettings)
    }
}

func mediaEditorStoredState(engine: TelegramEngine) -> Signal<MediaEditorStoredState?, NoError> {
    let key = EngineDataBuffer(length: 4)
    key.setInt32(0, value: 0)
    
    return engine.data.get(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: ApplicationSpecificItemCacheCollectionId.mediaEditorState, id: key))
    |> map { entry -> MediaEditorStoredState? in
        return entry?.get(MediaEditorStoredState.self)
    }
}

func updateMediaEditorStoredStateInteractively(engine: TelegramEngine, _ f: @escaping (MediaEditorStoredState?) -> MediaEditorStoredState?) -> Signal<Never, NoError> {
    let key = EngineDataBuffer(length: 4)
    key.setInt32(0, value: 0)
    
    return engine.data.get(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: ApplicationSpecificItemCacheCollectionId.mediaEditorState, id: key))
    |> map { entry -> MediaEditorStoredState? in
        return entry?.get(MediaEditorStoredState.self)
    }
    |> mapToSignal { state -> Signal<Never, NoError> in
        if let updatedState = f(state) {
            return engine.itemCache.put(collectionId: ApplicationSpecificItemCacheCollectionId.mediaEditorState, id: key, item: updatedState)
        } else {
            return engine.itemCache.remove(collectionId: ApplicationSpecificItemCacheCollectionId.mediaEditorState, id: key)
        }
    }
}
