import Foundation
import TelegramCore
import SwiftSignalKit

/// How the News tab draws a post row.
public enum NewsFeedDisplayMode: Int32, Codable, Equatable {
    /// The channel line, up to three lines of text and a thumbnail on the right.
    case compact = 0
    /// A full post, as a feed in Threads or X: the message bubble's content, its media in a horizontal
    /// gallery under the text.
    case expanded = 1
}

public struct NewsFeedSettings: Codable, Equatable {
    public var displayMode: NewsFeedDisplayMode

    public static var defaultSettings: NewsFeedSettings {
        return NewsFeedSettings(displayMode: .compact)
    }

    public init(displayMode: NewsFeedDisplayMode) {
        self.displayMode = displayMode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.displayMode = NewsFeedDisplayMode(rawValue: try container.decodeIfPresent(Int32.self, forKey: "displayMode") ?? 0) ?? .compact
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(self.displayMode.rawValue, forKey: "displayMode")
    }

    public func withUpdatedDisplayMode(_ displayMode: NewsFeedDisplayMode) -> NewsFeedSettings {
        return NewsFeedSettings(displayMode: displayMode)
    }
}

public func updateNewsFeedSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (NewsFeedSettings) -> NewsFeedSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.newsFeedSettings, { entry in
            let currentSettings: NewsFeedSettings
            if let entry = entry?.get(NewsFeedSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = NewsFeedSettings.defaultSettings
            }
            return SharedPreferencesEntry(f(currentSettings))
        })
    }
}
