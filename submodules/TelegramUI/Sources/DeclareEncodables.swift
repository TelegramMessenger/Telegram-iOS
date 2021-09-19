import Postbox
import TemporaryCachedPeerDataManager
import TelegramUIPreferences
import TelegramNotices
import InstantPageUI
import AccountContext
import LocalMediaResources
import WebSearchUI
import InstantPageCache
import SettingsUI
import WallpaperResources
import MediaResources
import LocationUI
import ChatInterfaceState

private var telegramUIDeclaredEncodables: Void = {
    declareEncodable(VideoLibraryMediaResource.self, f: { VideoLibraryMediaResource(decoder: $0) })
    declareEncodable(LocalFileVideoMediaResource.self, f: { LocalFileVideoMediaResource(decoder: $0) })
    declareEncodable(LocalFileGifMediaResource.self, f: { LocalFileGifMediaResource(decoder: $0) })
    declareEncodable(PhotoLibraryMediaResource.self, f: { PhotoLibraryMediaResource(decoder: $0) })
    declareEncodable(ICloudFileResource.self, f: { ICloudFileResource(decoder: $0) })
    return
}()

public func telegramUIDeclareEncodables() {
    let _ = telegramUIDeclaredEncodables
}
