import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import LegacyComponents
import TelegramUIPreferences
import MediaResources
import AccountContext
import LegacyUI
import LegacyMediaPickerUI
import LegacyComponents
import LocalMediaResources
import ImageBlur
import WallpaperGridScreen
import WallpaperGalleryScreen

func presentCustomWallpaperPicker(context: AccountContext, present: @escaping (ViewController) -> Void, push: @escaping (ViewController) -> Void) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let _ = legacyWallpaperPicker(context: context, presentationData: presentationData).start(next: { generator in
        let legacyController = LegacyController(presentation: .modal(animateIn: true), theme: presentationData.theme)
        legacyController.statusBar.statusBarStyle = presentationData.theme.rootController.statusBarStyle.style
        
        let controller = generator(legacyController.context)
        legacyController.bind(controller: controller)
        legacyController.deferScreenEdgeGestures = [.top]
        controller.selectionBlock = { [weak legacyController] asset, _ in
            if let asset = asset {
                let controller = WallpaperGalleryController(context: context, source: .asset(asset.backingAsset))
                controller.apply = { [weak legacyController, weak controller] wallpaper, mode, editedImage, cropRect, brightness, _ in
                    if let legacyController = legacyController, let controller = controller {
                        uploadCustomWallpaper(context: context, wallpaper: wallpaper, mode: mode, editedImage: nil, cropRect: cropRect, brightness: brightness, completion: { [weak legacyController, weak controller] in
                            if let legacyController = legacyController, let controller = controller {
                                legacyController.dismiss()
                                controller.dismiss(forceAway: true)
                            }
                        })
                    }
                }
                push(controller)
            }
        }
        controller.dismissalBlock = { [weak legacyController] in
            if let legacyController = legacyController {
                legacyController.dismiss()
            }
        }
        present(legacyController)
    })
}
