import Foundation
import TelegramLegacyComponents
import SwiftSignalKit
import TelegramCore
import Postbox
import SSignalKit
import UIKit
import Display

func configureLegacyAssetPicker(_ controller: TGMediaAssetsController, captionsEnabled: Bool = true, storeCreatedAssets: Bool = true, showFileTooltip: Bool = false) {
    controller.captionsEnabled = false//captionsEnabled
    controller.inhibitDocumentCaptions = false
    controller.suggestionContext = nil
    controller.dismissalBlock = {
        
    }
    controller.localMediaCacheEnabled = false
    controller.shouldStoreAssets = storeCreatedAssets
    controller.shouldShowFileTipIfNeeded = showFileTooltip
}

func legacyAssetPicker() -> Signal<(@escaping (UIViewController) -> (() -> Void)) -> TGMediaAssetsController, NoError> {
    return Signal { subscriber in
        let intent = TGMediaAssetsControllerSendMediaIntent
    
        if TGMediaAssetsLibrary.authorizationStatus() == TGMediaLibraryAuthorizationStatusNotDetermined {
            TGMediaAssetsLibrary.requestAuthorization(for: TGMediaAssetAnyType, completion: { (status, group) in
                if !TGLegacyComponentsAccessChecker().checkPhotoAuthorizationStatus(for: TGPhotoAccessIntentRead, alertDismissCompletion: nil) {
                    subscriber.putError(NoError())
                } else {
                    Queue.mainQueue().async {
                        subscriber.putNext({ present in
                            let controller = TGMediaAssetsController(assetGroup: group, intent: intent, presentOverlayController: { controller in
                                return present(controller!)
                            })
                            return controller!
                        })
                        subscriber.putCompletion()
                    }
                }
            })
        } else {
            subscriber.putNext({ present in
                let controller = TGMediaAssetsController(assetGroup: nil, intent: intent, presentOverlayController: { controller in
                    return present(controller!)
                })
                return controller!
            })
            subscriber.putCompletion()
        }
        
        return ActionDisposable {
            
        }
    }
}

private enum LegacyAssetItem {
    case image(UIImage)
    case asset(PHAsset)
}

private final class LegacyAssetItemWrapper: NSObject {
    let item: LegacyAssetItem
    
    init(item: LegacyAssetItem) {
        self.item = item
        
        super.init()
    }
}

func legacyAssetPickerItemGenerator() -> ((Any?, String?, String?) -> [AnyHashable : Any]?) {
    return { anyDict, caption, hash in
        let dict = anyDict as! NSDictionary
        if (dict["type"] as! NSString) == "editedPhoto" || (dict["type"] as! NSString) == "capturedPhoto" {
            let image = dict["image"] as! UIImage
            var result: [AnyHashable : Any] = [:]
            result["item" as NSString] = LegacyAssetItemWrapper(item: .image(image))
            return result
        } else if (dict["type"] as! NSString) == "cloudPhoto" {
            let asset = dict["asset"] as! TGMediaAsset
            var result: [AnyHashable : Any] = [:]
            result["item" as NSString] = LegacyAssetItemWrapper(item: .asset(asset.backingAsset))
            return result
        }
        return nil
    }
}

func legacyAssetPickerEnqueueMessages(account: Account, peerId: PeerId, signals: [Any]) -> Signal<[EnqueueMessage], NoError> {
    return Signal { subscriber in
        let disposable = SSignal.combineSignals(signals).start(next: { anyValues in
            var messages: [EnqueueMessage] = []
            
            for item in (anyValues as! NSArray) {
                if let item = (item as? NSDictionary)?.object(forKey: "item") as? LegacyAssetItemWrapper {
                    switch item.item {
                        case let .image(image):
                            var randomId: Int64 = 0
                            arc4random_buf(&randomId, 8)
                            let tempFilePath = NSTemporaryDirectory() + "\(randomId).jpeg"
                            let scaledSize = image.size.aspectFitted(CGSize(width: 1280.0, height: 1280.0))
                            if let scaledImage = generateImage(scaledSize, contextGenerator: { size, context in
                                context.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: size))
                            }, opaque: true) {
                                if let scaledImageData = UIImageJPEGRepresentation(image, 0.52) {
                                    let _ = try? scaledImageData.write(to: URL(fileURLWithPath: tempFilePath))
                                    let resource = LocalFileReferenceMediaResource(localFilePath: tempFilePath, randomId: randomId)
                                    let media = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: randomId), representations: [TelegramMediaImageRepresentation(dimensions: scaledSize, resource: resource)])
                                    messages.append(.message(text: "", media: media, replyToMessageId: nil))
                                }
                            }
                        case let .asset(asset):
                            var randomId: Int64 = 0
                            arc4random_buf(&randomId, 8)
                            let size = CGSize(width: CGFloat(asset.pixelWidth), height: CGFloat(asset.pixelHeight))
                            let scaledSize = size.aspectFitted(CGSize(width: 1280.0, height: 1280.0))
                            let resource = PhotoLibraryMediaResource(localIdentifier: asset.localIdentifier)
                            
                            let media = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: randomId), representations: [TelegramMediaImageRepresentation(dimensions: scaledSize, resource: resource)])
                            messages.append(.message(text: "", media: media, replyToMessageId: nil))
                    }
                }
            }
            
            subscriber.putNext(messages)
            subscriber.putCompletion()
        }, error: { _ in
            subscriber.putError(NoError())
        }, completed: nil)
        
        return ActionDisposable {
            disposable?.dispose()
        }
    }
}
