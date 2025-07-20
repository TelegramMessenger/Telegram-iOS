import Foundation
import UIKit
import Display
import SSignalKit
import SwiftSignalKit
import TelegramCore
import LegacyComponents
import TelegramPresentationData
import DeviceAccess
import AccountContext
import LocalMediaResources
import Photos

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

public class LegacyWallpaperItem: NSObject, TGMediaEditableItem, TGMediaSelectableItem {
    public var isVideo: Bool {
        return false
    }
    
    public var uniqueIdentifier: String! {
        return self.asset.localIdentifier
    }
    
    let asset: PHAsset
    let screenImage: UIImage
    private(set) var thumbnailResource: TelegramMediaResource?
    private(set) var imageResource: TelegramMediaResource?
    let dimensions: CGSize

    public init(asset: PHAsset, screenImage: UIImage, dimensions: CGSize) {
        self.asset = asset
        self.screenImage = screenImage
        self.dimensions = dimensions
    }
    
    public var originalSize: CGSize {
        return self.dimensions
    }
    
    public func thumbnailImageSignal() -> SSignal! {
        return SSignal.complete()
//        return SSignal(generator: { subscriber -> SDisposable? in
//            let disposable = self.thumbnailImage.start(next: { image in
//                subscriber.putNext(image)
//                subscriber.putCompletion()
//            })
//
//            return SBlockDisposable(block: {
//                disposable.dispose()
//            })
//        })
    }
    
    public func screenImageSignal(_ position: TimeInterval) -> SSignal! {
        return SSignal.single(self.screenImage)
    }
    
    public var originalImage: Signal<UIImage, NoError> {
        return fetchPhotoLibraryImage(localIdentifier: self.asset.localIdentifier, thumbnail: false)
        |> filter { value in
            return !(value?.1 ?? true)
        }
        |> mapToSignal { result -> Signal<UIImage, NoError> in
            if let result = result {
                return .single(result.0)
            } else {
                return .complete()
            }
        }
    }
    
    public func originalImageSignal(_ position: TimeInterval) -> SSignal! {
        return SSignal(generator: { subscriber -> SDisposable? in
            let disposable = self.originalImage.start(next: { image in
                subscriber.putNext(image)
                if !image.degraded() {
                    subscriber.putCompletion()
                }
            })
            
            return SBlockDisposable(block: {
                disposable.dispose()
            })
        })
    }
}
