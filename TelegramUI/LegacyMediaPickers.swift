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

func legacyAssetPicker(fileMode: Bool) -> Signal<(@escaping (UIViewController) -> (() -> Void)) -> TGMediaAssetsController, NoError> {
    return Signal { subscriber in
        let intent = fileMode ? TGMediaAssetsControllerSendFileIntent : TGMediaAssetsControllerSendMediaIntent
    
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

private enum LegacyAssetData {
    case image(UIImage)
    case asset(PHAsset)
    case tempFile(String)
}

private enum LegacyAssetItem {
    case image(LegacyAssetData)
    case file(LegacyAssetData, mimeType: String, name: String)
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
            result["item" as NSString] = LegacyAssetItemWrapper(item: .image(.image(image)))
            return result
        } else if (dict["type"] as! NSString) == "cloudPhoto" {
            let asset = dict["asset"] as! TGMediaAsset
            var asFile = false
            if let document = dict["document"] as? NSNumber, document.boolValue {
                asFile = true
            }
            var result: [AnyHashable : Any] = [:]
            if asFile {
                //result["item" as NSString] = LegacyAssetItemWrapper(item: .file(.asset(asset.backingAsset)))
                return nil
            } else {
                result["item" as NSString] = LegacyAssetItemWrapper(item: .image(.asset(asset.backingAsset)))
            }
            return result
        } else if (dict["type"] as! NSString) == "file" {
            if let tempFileUrl = dict["tempFileUrl"] as? URL {
                var mimeType = "application/binary"
                if let customMimeType = dict["mimeType"] as? String {
                    mimeType = customMimeType
                }
                var name = "file"
                if let customName = dict["fileName"] as? String {
                    name = customName
                }
                
                var result: [AnyHashable : Any] = [:]
                result["item" as NSString] = LegacyAssetItemWrapper(item: .file(.tempFile(tempFileUrl.path), mimeType: mimeType, name: name))
                return result
            }
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
                        case let .image(data):
                            switch data {
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
                                            messages.append(.message(text: "", attributes: [], media: media, replyToMessageId: nil))
                                        }
                                    }
                                case let .asset(asset):
                                    var randomId: Int64 = 0
                                    arc4random_buf(&randomId, 8)
                                    let size = CGSize(width: CGFloat(asset.pixelWidth), height: CGFloat(asset.pixelHeight))
                                    let scaledSize = size.aspectFitted(CGSize(width: 1280.0, height: 1280.0))
                                    let resource = PhotoLibraryMediaResource(localIdentifier: asset.localIdentifier)
                                    
                                    let media = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: randomId), representations: [TelegramMediaImageRepresentation(dimensions: scaledSize, resource: resource)])
                                    messages.append(.message(text: "", attributes: [], media: media, replyToMessageId: nil))
                                case .tempFile:
                                    break
                            }
                        case let .file(data, mimeType, name):
                            switch data {
                                case let .tempFile(path):
                                    var randomId: Int64 = 0
                                    arc4random_buf(&randomId, 8)
                                    let resource = LocalFileReferenceMediaResource(localFilePath: path, randomId: randomId)
                                    let media = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), resource: resource, previewRepresentations: [], mimeType: mimeType, size: nil, attributes: [.FileName(fileName: name)])
                                    messages.append(.message(text: "", attributes: [], media: media, replyToMessageId: nil))
                                default:
                                    break
                            }
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
