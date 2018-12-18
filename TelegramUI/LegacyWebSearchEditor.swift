import Foundation
import LegacyComponents
import SwiftSignalKit
import TelegramCore
import Postbox
import SSignalKit
import UIKit
import Display

func presentLegacyWebSearchEditor(account: Account, theme: PresentationTheme, result: ChatContextResult, initialLayout: ContainerViewLayout?, updateHiddenMedia: @escaping (String?) -> Void, transitionHostView: @escaping () -> UIView?, transitionView: @escaping (ChatContextResult) -> UIView?, completed: @escaping (UIImage) -> Void, present: (ViewController, Any?) -> Void) {
    guard let item = legacyWebSearchItem(account: account, result: result) else {
        return
    }
    
    let legacyController = LegacyController(presentation: .custom, theme: theme, initialLayout: initialLayout)
    legacyController.statusBar.statusBarStyle = .Ignore
    
    let controller = TGPhotoEditorController(context: legacyController.context, item: item, intent: TGPhotoEditorControllerAvatarIntent, adjustments: nil, caption: nil, screenImage: nil, availableTabs: TGPhotoEditorController.defaultTabsForAvatarIntent(), selectedTab: .cropTab)!
    legacyController.bind(controller: controller)
    
    controller.editingContext = TGMediaEditingContext()
    controller.didFinishEditing = { [weak controller] _, result, _, hasChanges in
        if !hasChanges {
            return
        }
        if let result = result {
            completed(result)
        }
        controller?.dismiss(animated: true)
    }
    controller.requestThumbnailImage = { _ -> SSignal in
        return item.thumbnailImageSignal()
    }
    controller.requestOriginalScreenSizeImage = { _, position -> SSignal in
        return item.screenImageSignal(position)
    }
    controller.requestOriginalFullSizeImage = { _, position -> SSignal in
        return item.originalImageSignal(position)
    }
    
    let fromView = transitionView(result)!
    let transition = TGMediaAvatarEditorTransition(controller: controller, from: fromView)!
    transition.transitionHostView = transitionHostView()
    transition.referenceFrame = {
        return fromView.frame
    }
    transition.referenceImageSize = {
        return item.dimensions
    }
    transition.referenceScreenImageSignal = {
        return item.screenImageSignal(0.0)
    }
    transition.imageReady = {
        updateHiddenMedia(result.id)
    }
    
    controller.beginCustomTransitionOut = { [weak legacyController] outFrame, outView, completion in
        transition.outReferenceFrame = outFrame
        transition.repView = outView
        transition.dismiss(animated: true, completion: {
            updateHiddenMedia(nil)
            if let completion = completion {
                DispatchQueue.main.async {
                    completion()
                }
            }
            legacyController?.dismiss()
        })
    }
    
    present(legacyController, nil)
    transition.present(animated: true)
}
