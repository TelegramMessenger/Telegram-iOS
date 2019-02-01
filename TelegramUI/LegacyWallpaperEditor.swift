import Foundation
import Display
import SwiftSignalKit
import LegacyComponents

private final class LegacyWallpaperEditorController: LegacyController, TGWallpaperControllerDelegate {
    private let completion: (UIImage?) -> Void
    
    init(presentation: LegacyControllerPresentation, theme: PresentationTheme?, completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
        
        super.init(presentation: presentation, theme: theme)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func wallpaperController(_ wallpaperController: TGWallpaperController!, didSelectWallpaperWith wallpaperInfo: TGWallpaperInfo!) {
        self.completion(wallpaperInfo.image())
    }
}

func legacyWallpaperEditor(theme: PresentationTheme, image: UIImage, completion: @escaping (UIImage?) -> Void) -> ViewController {
    var dismissImpl: (() -> Void)?
    let legacyController = LegacyWallpaperEditorController(presentation: .modal(animateIn: true), theme: theme, completion: { image in
        dismissImpl?()
        completion(image)
    })
    
    let wallpaperController = TGWallpaperController(context: legacyController.context, wallpaperInfo: TGCustomImageWallpaperInfo(image: image), thumbnailImage: nil)!
    //wallpaperController.presentation = self.presentation;
    wallpaperController.customDismiss = {
        dismissImpl?()
    }
    wallpaperController.delegate = legacyController
    wallpaperController.enableWallpaperAdjustment = true
    wallpaperController.doNotFlipIfRTL = true
    
    let navigationController = TGNavigationController(controllers: [wallpaperController])!
    wallpaperController.navigation_setDismiss({ [weak legacyController] in
        legacyController?.dismiss()
    }, rootController: nil)
    dismissImpl = { [weak legacyController] in
        legacyController?.dismiss()
    }
    legacyController.bind(controller: navigationController)
    return legacyController
}

func legacyWallpaperPicker(context: AccountContext, presentationData: PresentationData) -> Signal<(LegacyComponentsContext) -> TGMediaAssetsController, Void> {
    return Signal { subscriber in
        let intent = TGMediaAssetsControllerSetCustomWallpaperIntent
        
        DeviceAccess.authorizeAccess(to: .mediaLibrary(.wallpaper), presentationData: presentationData, present: context.sharedContext.presentGlobalController, openSettings: context.sharedContext.applicationBindings.openSettings, { value in
            if !value {
                subscriber.putError(Void())
                return
            }
            
            if TGMediaAssetsLibrary.authorizationStatus() == TGMediaLibraryAuthorizationStatusNotDetermined {
                TGMediaAssetsLibrary.requestAuthorization(for: TGMediaAssetAnyType, completion: { (status, group) in
                    if !LegacyComponentsGlobals.provider().accessChecker().checkPhotoAuthorizationStatus(for: TGPhotoAccessIntentRead, alertDismissCompletion: nil) {
                        subscriber.putError(Void())
                    } else {
                        Queue.mainQueue().async {
                            subscriber.putNext({ context in
                                let controller = TGMediaAssetsController(context: context, assetGroup: group, intent: intent, recipientName: nil, saveEditedPhotos: false, allowGrouping: false)
                                return controller!
                            })
                            subscriber.putCompletion()
                        }
                    }
                })
            } else {
                subscriber.putNext({ context in
                    let controller = TGMediaAssetsController(context: context, assetGroup: nil, intent: intent, recipientName: nil, saveEditedPhotos: false, allowGrouping: false)
                    return controller!
                })
                subscriber.putCompletion()
            }
        })
        
        return ActionDisposable {
            
        }
    }
}
