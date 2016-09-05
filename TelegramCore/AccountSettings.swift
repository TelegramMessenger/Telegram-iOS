import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public struct AutomaticDownloadSettings {
    public let downloadPhoto: Bool
    public let downloadVideo: Bool
    public let downloadAudio: Bool
}

public struct AccountSettings {
    public let oneToOneChatsAutomaticDownloadSettings: AutomaticDownloadSettings
    public let groupChatsAutomaticDownloadSettings: AutomaticDownloadSettings
}

func defaultAccountSettings() -> AccountSettings {
    return AccountSettings(oneToOneChatsAutomaticDownloadSettings: AutomaticDownloadSettings(downloadPhoto: true, downloadVideo: false, downloadAudio: true), groupChatsAutomaticDownloadSettings: AutomaticDownloadSettings(downloadPhoto: true, downloadVideo: false, downloadAudio: true))
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
