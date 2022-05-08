import Postbox
import SwiftSignalKit

public struct UserLimitsConfiguration: Equatable {
    public let maxPinnedChatCount: Int32
    public let maxChannelsCount: Int32
    public let maxPublicLinksCount: Int32
    public let maxSavedGifCount: Int32
    public let maxFavedStickerCount: Int32
    public let maxFoldersCount: Int32
    public let maxFolderChatsCount: Int32
    public let maxTextLengthCount: Int32
    
    public static var defaultValue: UserLimitsConfiguration {
        return UserLimitsConfiguration(
            maxPinnedChatCount: 5,
            maxChannelsCount: 500,
            maxPublicLinksCount: 10,
            maxSavedGifCount: 200,
            maxFavedStickerCount: 5,
            maxFoldersCount: 10,
            maxFolderChatsCount: 100,
            maxTextLengthCount: 4096
        )
    }

    public init(
        maxPinnedChatCount: Int32,
        maxChannelsCount: Int32,
        maxPublicLinksCount: Int32,
        maxSavedGifCount: Int32,
        maxFavedStickerCount: Int32,
        maxFoldersCount: Int32,
        maxFolderChatsCount: Int32,
        maxTextLengthCount: Int32
    ) {
        self.maxPinnedChatCount = maxPinnedChatCount
        self.maxChannelsCount = maxChannelsCount
        self.maxPublicLinksCount = maxPublicLinksCount
        self.maxSavedGifCount = maxSavedGifCount
        self.maxFavedStickerCount = maxFavedStickerCount
        self.maxFoldersCount = maxFoldersCount
        self.maxFolderChatsCount = maxFolderChatsCount
        self.maxTextLengthCount = maxTextLengthCount
    }
}

extension UserLimitsConfiguration {
    init(appConfiguration: AppConfiguration, isPremium: Bool) {
        let keySuffix = isPremium ? "_premium" : "_default"
        let defaultValue = UserLimitsConfiguration.defaultValue
        
        func getValue(_ key: String, orElse defaultValue: Int32) -> Int32 {
            if let value = appConfiguration.data?[key + keySuffix] as? Double {
                return Int32(value)
            } else {
                return defaultValue
            }
        }
        
        self.maxPinnedChatCount = getValue("dialogs_pinned_limit", orElse: defaultValue.maxPinnedChatCount)
        self.maxChannelsCount = getValue("channels_limit", orElse: defaultValue.maxPinnedChatCount)
        self.maxPublicLinksCount = getValue("channels_public_limit", orElse: defaultValue.maxPinnedChatCount)
        self.maxSavedGifCount = getValue("saved_gifs_limit", orElse: defaultValue.maxPinnedChatCount)
        self.maxFavedStickerCount = getValue("stickers_faved_limit", orElse: defaultValue.maxPinnedChatCount)
        self.maxFoldersCount = getValue("dialog_filters_limit", orElse: defaultValue.maxPinnedChatCount)
        self.maxFolderChatsCount = getValue("dialog_filters_chats_limit", orElse: defaultValue.maxPinnedChatCount)
        self.maxTextLengthCount = getValue("message_text_length_limit", orElse: defaultValue.maxPinnedChatCount)
    }
}

public func getUserLimits(postbox: Postbox) -> Signal<Never, NoError> {
    return postbox.preferencesView(keys: [PreferencesKeys.appConfiguration])
    |> mapToSignal { preferencesView -> Signal<Never, NoError> in
        let appConfiguration: AppConfiguration = preferencesView.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) ?? .defaultValue
        let configuration = UserLimitsConfiguration(appConfiguration: appConfiguration, isPremium: false)
        print(configuration)
        return .never()
    }
}
