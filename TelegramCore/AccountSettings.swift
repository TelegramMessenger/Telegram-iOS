import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public struct AutomaticDownloadSettings {
    public let downloadPhotos: Bool
    public let downloadVoiceMessages: Bool
    public let downloadGifs: Bool
}

public struct AccountSettings {
    public let oneToOneChatsAutomaticDownloadSettings: AutomaticDownloadSettings
    public let groupChatsAutomaticDownloadSettings: AutomaticDownloadSettings
}

func defaultAccountSettings() -> AccountSettings {
    return AccountSettings(oneToOneChatsAutomaticDownloadSettings: AutomaticDownloadSettings(downloadPhotos: true, downloadVoiceMessages: true, downloadGifs: true), groupChatsAutomaticDownloadSettings: AutomaticDownloadSettings(downloadPhotos: true, downloadVoiceMessages: true, downloadGifs: true))
}

public extension AccountSettings {
    public func automaticDownloadSettingsForPeerId(_ peerId: PeerId) -> AutomaticDownloadSettings {
        if peerId.namespace == Namespaces.Peer.CloudUser {
            return self.oneToOneChatsAutomaticDownloadSettings
        } else {
            return self.groupChatsAutomaticDownloadSettings
        }
    }
}
