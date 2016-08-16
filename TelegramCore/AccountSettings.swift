import Foundation
import Postbox

struct AutomaticDownloadSettings {
    let downloadPhoto: Bool
    let downloadVideo: Bool
    let downloadAudio: Bool
}

struct AccountSettings {
    let oneToOneChatsAutomaticDownloadSettings: AutomaticDownloadSettings
    let groupChatsAutomaticDownloadSettings: AutomaticDownloadSettings
}

func defaultAccountSettings() -> AccountSettings {
    return AccountSettings(oneToOneChatsAutomaticDownloadSettings: AutomaticDownloadSettings(downloadPhoto: true, downloadVideo: false, downloadAudio: true), groupChatsAutomaticDownloadSettings: AutomaticDownloadSettings(downloadPhoto: true, downloadVideo: false, downloadAudio: true))
}

extension AccountSettings {
    func automaticDownloadSettingsForPeerId(_ peerId: PeerId) -> AutomaticDownloadSettings {
        if peerId.namespace == Namespaces.Peer.CloudUser {
            return self.oneToOneChatsAutomaticDownloadSettings
        } else {
            return self.groupChatsAutomaticDownloadSettings
        }
    }
}
