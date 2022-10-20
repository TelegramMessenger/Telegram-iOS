import Foundation
import UIKit
import Display
import SwiftSignalKit
import LegacyComponents
import TelegramPresentationData
import DeviceAccess
import AccountContext

public func legacyWallpaperPicker(context: AccountContext, presentationData: PresentationData, subject: DeviceAccessMediaLibrarySubject = .wallpaper) -> Signal<(LegacyComponentsContext) -> TGMediaAssetsController, Void> {
    return Signal { subscriber in
        let intent = TGMediaAssetsControllerSetCustomWallpaperIntent
        
        DeviceAccess.authorizeAccess(to: .mediaLibrary(subject), presentationData: presentationData, present: context.sharedContext.presentGlobalController, openSettings: context.sharedContext.applicationBindings.openSettings, { value in
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
                                let controller = TGMediaAssetsController(context: context, assetGroup: group, intent: intent, recipientName: nil, saveEditedPhotos: false, allowGrouping: false, selectionLimit: 1)
                                return controller!
                            })
                            subscriber.putCompletion()
                        }
                    }
                })
            } else {
                subscriber.putNext({ context in
                    let controller = TGMediaAssetsController(context: context, assetGroup: nil, intent: intent, recipientName: nil, saveEditedPhotos: false, allowGrouping: false, selectionLimit: 1)
                    return controller!
                })
                subscriber.putCompletion()
            }
        })
        
        return ActionDisposable {
            
        }
    }
}
