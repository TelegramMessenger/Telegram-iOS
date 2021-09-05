import Foundation
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData

public enum WallpaperUploadManagerStatus {
    case none
    case uploading(TelegramWallpaper, Float)
    case uploaded(TelegramWallpaper, TelegramWallpaper)
    
    public var wallpaper: TelegramWallpaper? {
        switch self {
        case let .uploading(wallpaper, _), let .uploaded(wallpaper, _):
            return wallpaper
        default:
            return nil
        }
    }
}

public protocol WallpaperUploadManager: AnyObject {
    func stateSignal() -> Signal<WallpaperUploadManagerStatus, NoError>
    func presentationDataUpdated(_ presentationData: PresentationData)
}
