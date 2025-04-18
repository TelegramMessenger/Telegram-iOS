import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences
import Postbox

public final class MediaPlaybackStoredState: Codable {
    public let timestamp: Double
    public let playbackRate: AudioPlaybackRate
    
    public init(timestamp: Double, playbackRate: AudioPlaybackRate) {
        self.timestamp = timestamp
        self.playbackRate = playbackRate
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.timestamp = try container.decode(Double.self, forKey: "timestamp")
        self.playbackRate = AudioPlaybackRate(rawValue: try container.decode(Int32.self, forKey: "playbackRate"))
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.timestamp, forKey: "timestamp")
        try container.encode(self.playbackRate.rawValue, forKey: "playbackRate")
    }
}

public func mediaPlaybackStoredState(engine: TelegramEngine, messageId: EngineMessage.Id) -> Signal<MediaPlaybackStoredState?, NoError> {
    return engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: messageId))
    |> map { message -> MediaPlaybackStoredState? in
        guard let message else {
            return nil
        }
        for attribute in message.attributes {
            if let attribute = attribute as? DerivedDataMessageAttribute {
                return attribute.data["mps"]?.get(MediaPlaybackStoredState.self)
            }
        }
        return nil
    }
}

public func updateMediaPlaybackStoredStateInteractively(engine: TelegramEngine, messageId: EngineMessage.Id, state: MediaPlaybackStoredState?) -> Signal<Never, NoError> {
    return engine.messages.updateLocallyDerivedData(messageId: messageId, update: { data in
        var data = data
        if let state, let entry = CodableEntry(state) {
            data["mps"] = entry
        } else {
            data.removeValue(forKey: "mps")
        }
        return data
    })
}
