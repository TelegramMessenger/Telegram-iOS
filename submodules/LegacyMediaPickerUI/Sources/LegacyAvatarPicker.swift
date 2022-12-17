import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import LegacyComponents
import TelegramPresentationData
import LegacyUI
import AccountContext
import SaveToCameraRoll

public func presentLegacyAvatarPicker(holder: Atomic<NSObject?>, signup: Bool, theme: PresentationTheme, present: (ViewController, Any?) -> Void, openCurrent: (() -> Void)?, completion: @escaping (UIImage) -> Void, videoCompletion: @escaping (UIImage, Any?, TGVideoEditAdjustments?) -> Void = { _, _, _ in}) {
    let legacyController = LegacyController(presentation: .custom, theme: theme)
    legacyController.statusBar.statusBarStyle = .Ignore
    
    let emptyController = LegacyEmptyController(context: legacyController.context)!
    let navigationController = makeLegacyNavigationController(rootController: emptyController)
    navigationController.setNavigationBarHidden(true, animated: false)
    navigationController.navigationBar.transform = CGAffineTransform(translationX: -1000.0, y: 0.0)

    legacyController.bind(controller: navigationController)
    
    present(legacyController, nil)
        
    let mixin = TGMediaAvatarMenuMixin(context: legacyController.context, parentController: emptyController, hasSearchButton: false, hasDeleteButton: false, hasViewButton: openCurrent != nil, personalPhoto: true, isVideo: false, saveEditedPhotos: false, saveCapturedMedia: false, signup: signup, forum: false, title: nil, isSuggesting: false)!
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

public func legacyAvatarEditor(context: AccountContext, media: AnyMediaReference, transitionView: UIView?, senderName: String? = nil, present: @escaping (ViewController, Any?) -> Void, imageCompletion: @escaping (UIImage) -> Void, videoCompletion: @escaping (UIImage, URL, TGVideoEditAdjustments) -> Void) {
    let isVideo = !((media.media as? TelegramMediaImage)?.videoRepresentations.isEmpty ?? true)
    
    let imageSignal = fetchMediaData(context: context, postbox: context.account.postbox, userLocation: .other, mediaReference: media, forceVideo: false)
    |> map { (value, _) -> (UIImage?, Bool) in
        if case let .data(data) = value, data.complete {
            return (UIImage(contentsOfFile: data.path), true)
        } else {
            return (nil, false)
        }
    }
    
    let videoSignal = isVideo ? fetchMediaData(context: context, postbox: context.account.postbox, userLocation: .other, mediaReference: media, forceVideo: true)
    |> map { (value, isImage) -> (URL?, Bool) in
        if case let .data(data) = value, data.complete && !isImage {
            return (URL(fileURLWithPath: data.path), true)
        } else {
            return (nil, false)
        }
    } : .single((nil, true))
    
    let signals = combineLatest(queue: Queue.mainQueue(),
        imageSignal,
        videoSignal
    )
    |> filter { image, video in
        return image.1 && video.1
    }
    
    let _ = signals.start(next: { image, video in
        if image.0 == nil && video.0 == nil {
            return
        }
        
        let paintStickersContext = LegacyPaintStickersContext(context: context)
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }

        let legacyController = LegacyController(presentation: .custom, theme: presentationData.theme, initialLayout: nil)
        legacyController.blocksBackgroundWhenInOverlay = true
        legacyController.acceptsFocusWhenInOverlay = true
        legacyController.statusBar.statusBarStyle = .Ignore
        legacyController.controllerLoaded = { [weak legacyController] in
            legacyController?.view.disablesInteractiveTransitionGestureRecognizer = true
        }

        let emptyController = LegacyEmptyController(context: legacyController.context)!
        emptyController.navigationBarShouldBeHidden = true
        let navigationController = makeLegacyNavigationController(rootController: emptyController)
        navigationController.setNavigationBarHidden(true, animated: false)
        legacyController.bind(controller: navigationController)

        legacyController.enableSizeClassSignal = true
        
        present(legacyController, nil)
        
        TGPhotoVideoEditor.present(with: legacyController.context, parentController: emptyController, image: image.0, video: video.0, stickersContext: paintStickersContext, transitionView: transitionView, senderName: senderName, didFinishWithImage: { image in
            if let image = image {
                imageCompletion(image)
            }
        }, didFinishWithVideo: { image, url, adjustments in
            if let image = image, let url = url, let adjustments = adjustments {
                videoCompletion(image, url, adjustments)
            }
        }, dismissed: { [weak legacyController] in
            legacyController?.dismiss()
        })
    })
}
