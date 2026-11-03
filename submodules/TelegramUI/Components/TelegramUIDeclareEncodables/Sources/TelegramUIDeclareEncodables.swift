import TelegramCore
import TemporaryCachedPeerDataManager
import TelegramUIPreferences
import TelegramNotices
import InstantPageUI
import AccountContext
import LocalMediaResources
import InstantPageCache
import SettingsUI
import WallpaperResources
import MediaResources
import LocationUI
import ChatInterfaceState
import ICloudResources

private var telegramUIDeclaredEncodables: Void = {
    engineDeclareEncodable(VideoLibraryMediaResource.self, f: { VideoLibraryMediaResource(decoder: $0) })
    engineDeclareEncodable(LocalFileVideoMediaResource.self, f: { LocalFileVideoMediaResource(decoder: $0) })
    engineDeclareEncodable(LocalFileAudioMediaResource.self, f: { LocalFileAudioMediaResource(decoder: $0) })
    engineDeclareEncodable(LocalFileGifMediaResource.self, f: { LocalFileGifMediaResource(decoder: $0) })
    engineDeclareEncodable(PhotoLibraryMediaResource.self, f: { PhotoLibraryMediaResource(decoder: $0) })
    engineDeclareEncodable(ICloudFileResource.self, f: { ICloudFileResource(decoder: $0) })
    return
}()

public func telegramUIDeclareEncodables() {
    let _ = telegramUIDeclaredEncodables
}
