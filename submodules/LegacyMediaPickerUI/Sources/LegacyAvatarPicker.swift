import Foundation
import UIKit
import Display
import SwiftSignalKit
import LegacyComponents
import TelegramPresentationData
import LegacyUI

public func presentLegacyAvatarPicker(holder: Atomic<NSObject?>, signup: Bool, theme: PresentationTheme, present: (ViewController, Any?) -> Void, openCurrent: (() -> Void)?, completion: @escaping (UIImage) -> Void, videoCompletion: @escaping (UIImage, Any?, TGVideoEditAdjustments?) -> Void = { _, _, _ in}) {
    let legacyController = LegacyController(presentation: .custom, theme: theme)
    legacyController.statusBar.statusBarStyle = .Ignore
    
    let emptyController = LegacyEmptyController(context: legacyController.context)!
    let navigationController = makeLegacyNavigationController(rootController: emptyController)
    navigationController.setNavigationBarHidden(true, animated: false)
    navigationController.navigationBar.transform = CGAffineTransform(translationX: -1000.0, y: 0.0)

    legacyController.bind(controller: navigationController)
    
    present(legacyController, nil)
        
    let mixin = TGMediaAvatarMenuMixin(context: legacyController.context, parentController: emptyController, hasSearchButton: false, hasDeleteButton: false, hasViewButton: openCurrent != nil, personalPhoto: true, isVideo: false, saveEditedPhotos: false, saveCapturedMedia: false, signup: signup)!
    let _ = holder.swap(mixin)
    mixin.didFinishWithImage = { image in
        guard let image = image else {
            return
        }
        completion(image)
    }
    mixin.didFinishWithVideo = { image, asset, adjustments in
        guard let image = image else {
            return
        }
        videoCompletion(image, asset, adjustments)
    }
    mixin.didFinishWithView = {
        openCurrent?()
    }
    mixin.didDismiss = { [weak legacyController] in
        let _ = holder.swap(nil)
        legacyController?.dismiss()
    }
    let menuController = mixin.present()
    if let menuController = menuController {
        menuController.customRemoveFromParentViewController = { [weak legacyController] in
            legacyController?.dismiss()
        }
    }
}
