import Foundation
import UIKit
import Display
import SwiftSignalKit
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

private final class CustomWallpaperMediaPickerReference {
    weak var controller: ViewController?
}

func presentCustomWallpaperPicker(context: AccountContext, present: @escaping (ViewController) -> Void, push: @escaping (ViewController) -> Void) {
    if context.routesToChatMediaEditorV2(.wallpaperPhotoPicker) {
        let pickerReference = CustomWallpaperMediaPickerReference()
        let controller = makeCustomWallpaperMediaPicker(context: context, mode: .default, requiredLevel: nil, push: push, apply: { wallpaper, options, editedImage, cropRect, brightness in
            uploadCustomWallpaper(context: context, wallpaper: wallpaper, mode: options, editedImage: editedImage, cropRect: cropRect, brightness: brightness, completion: {
                guard let navigationController = pickerReference.controller?.navigationController as? NavigationController else {
                    return
                }
                let controllers = navigationController.viewControllers.filter({ controller in
                    if controller is WallpaperGalleryController || controller is MediaPickerScreen {
                        return false
                    }
                    return true
                })
                navigationController.setViewControllers(controllers, animated: true)
            })
        })
        pickerReference.controller = controller
        push(controller)
        return
    }
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
