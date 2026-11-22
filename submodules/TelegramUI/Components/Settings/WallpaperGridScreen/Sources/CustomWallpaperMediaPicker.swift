import Foundation
import UIKit
import Display
import Photos
import TelegramUIPreferences
import AccountContext
import MediaPickerUI
import WallpaperGalleryScreen

public func makeCustomWallpaperMediaPicker(context: AccountContext, mode: WallpaperGalleryController.Mode, requiredLevel: Int?, push: @escaping (ViewController) -> Void, apply: @escaping (WallpaperGalleryEntry, WallpaperPresentationOptions, UIImage?, CGRect?, CGFloat?) -> Void) -> ViewController {
    let controller = MediaPickerScreenImpl(context: context, peer: nil, threadTitle: nil, chatLocation: nil, bannedSendPhotos: nil, bannedSendVideos: nil, subject: .assets(nil, .wallpaper))
    controller.customSelection = { _, asset in
        guard let asset = asset as? PHAsset else {
            return
        }
        let controller = WallpaperGalleryController(context: context, source: .asset(asset), mode: mode)
        controller.requiredLevel = requiredLevel
        controller.apply = { wallpaper, options, editedImage, cropRect, brightness, _ in
            apply(wallpaper, options, editedImage, cropRect, brightness)
        }
        push(controller)
    }
    return controller
}
