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
    public let maxCaptionLength: Int32
    public let maxUploadFileParts: Int32
    public let maxAboutLength: Int32
    public let maxAnimatedEmojisInText: Int32
    
    public static var defaultValue: UserLimitsConfiguration {
        return UserLimitsConfiguration(
            maxPinnedChatCount: 5,
            maxChannelsCount: 500,
            maxPublicLinksCount: 10,
            maxSavedGifCount: 200,
            maxFavedStickerCount: 5,
            maxFoldersCount: 10,
            maxFolderChatsCount: 100,
            maxCaptionLength: 1024,
            maxUploadFileParts: 4000,
            maxAboutLength: 70,
            maxAnimatedEmojisInText: 10
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
        maxCaptionLength: Int32,
        maxUploadFileParts: Int32,
        maxAboutLength: Int32,
        maxAnimatedEmojisInText: Int32
    ) {
        self.maxPinnedChatCount = maxPinnedChatCount
        self.maxChannelsCount = maxChannelsCount
        self.maxPublicLinksCount = maxPublicLinksCount
        self.maxSavedGifCount = maxSavedGifCount
        self.maxFavedStickerCount = maxFavedStickerCount
        self.maxFoldersCount = maxFoldersCount
        self.maxFolderChatsCount = maxFolderChatsCount
        self.maxCaptionLength = maxCaptionLength
        self.maxUploadFileParts = maxUploadFileParts
        self.maxAboutLength = maxAboutLength
        self.maxAnimatedEmojisInText = maxAnimatedEmojisInText
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
        
        func getGeneralValue(_ key: String, orElse defaultValue: Int32) -> Int32 {
            if let value = appConfiguration.data?[key] as? Double {
                return Int32(value)
            } else {
                return defaultValue
            }
        }
        
        self.maxPinnedChatCount = getValue("dialogs_pinned_limit", orElse: defaultValue.maxPinnedChatCount)
        self.maxChannelsCount = getValue("channels_limit", orElse: defaultValue.maxChannelsCount)
        self.maxPublicLinksCount = getValue("channels_public_limit", orElse: defaultValue.maxPublicLinksCount)
        self.maxSavedGifCount = getValue("saved_gifs_limit", orElse: defaultValue.maxSavedGifCount)
        self.maxFavedStickerCount = getValue("stickers_faved_limit", orElse: defaultValue.maxFavedStickerCount)
        self.maxFoldersCount = getValue("dialog_filters_limit", orElse: defaultValue.maxFoldersCount)
        self.maxFolderChatsCount = getValue("dialog_filters_chats_limit", orElse: defaultValue.maxFolderChatsCount)
        self.maxCaptionLength = getValue("caption_length_limit", orElse: defaultValue.maxCaptionLength)
        self.maxUploadFileParts = getValue("upload_max_fileparts", orElse: defaultValue.maxUploadFileParts)
        self.maxAboutLength = getValue("about_length_limit", orElse: defaultValue.maxAboutLength)
        self.maxAnimatedEmojisInText = getGeneralValue("message_animated_emoji_max", orElse: defaultValue.maxAnimatedEmojisInText)
    }
}
