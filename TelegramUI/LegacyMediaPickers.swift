import Foundation
import TelegramLegacyComponents
import SwiftSignalKit
import TelegramCore
import Postbox
import SSignalKit
import UIKit
import Display

func configureLegacyAssetPicker(_ controller: TGMediaAssetsController, captionsEnabled: Bool = true, storeCreatedAssets: Bool = true, showFileTooltip: Bool = false) {
    controller.captionsEnabled = captionsEnabled
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

private enum LegacyAssetImageData {
    case image(UIImage)
    case asset(PHAsset)
    case tempFile(String)
}

private enum LegacyAssetVideoData {
    case asset(TGMediaAsset)
    case tempFile(path: String, dimensions: CGSize, duration: Double)
}

private enum LegacyAssetItem {
    case image(data: LegacyAssetImageData, caption: String?)
    case file(data: LegacyAssetImageData, mimeType: String, name: String, caption: String?)
    case video(data: LegacyAssetVideoData, previewImage: UIImage?, adjustments: TGVideoEditAdjustments?, caption: String?)
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
            result["item" as NSString] = LegacyAssetItemWrapper(item: .image(data: .image(image), caption: caption))
            return result
        } else if (dict["type"] as! NSString) == "cloudPhoto" {
            let asset = dict["asset"] as! TGMediaAsset
            var asFile = false
            if let document = dict["document"] as? NSNumber, document.boolValue {
                asFile = true
            }
            var result: [AnyHashable: Any] = [:]
            if asFile {
                //result["item" as NSString] = LegacyAssetItemWrapper(item: .file(.asset(asset.backingAsset)))
                return nil
            } else {
                result["item" as NSString] = LegacyAssetItemWrapper(item: .image(data: .asset(asset.backingAsset), caption: caption))
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
                
                var result: [AnyHashable: Any] = [:]
                result["item" as NSString] = LegacyAssetItemWrapper(item: .file(data: .tempFile(tempFileUrl.path), mimeType: mimeType, name: name, caption: caption))
                return result
            }
        } else if (dict["type"] as! NSString) == "video" {
            if let asset = dict["asset"] as? TGMediaAsset {
                var result: [AnyHashable: Any] = [:]
                result["item" as NSString] = LegacyAssetItemWrapper(item: .video(data: .asset(asset), previewImage: dict["previewImage"] as? UIImage, adjustments: dict["adjustments"] as? TGVideoEditAdjustments, caption: caption))
                return result
            } else if let url = dict["url"] as? String {
                let dimensions = (dict["dimensions"]! as AnyObject).cgSizeValue!
                let duration = (dict["duration"]! as AnyObject).doubleValue!
                var result: [AnyHashable: Any] = [:]
                result["item" as NSString] = LegacyAssetItemWrapper(item: .video(data: .tempFile(path: url, dimensions: dimensions, duration: duration), previewImage: dict["previewImage"] as? UIImage, adjustments: dict["adjustments"] as? TGVideoEditAdjustments, caption: caption))
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
                        case let .image(data, caption):
                            switch data {
                                case let .image(image):
                                    var randomId: Int64 = 0
                                    arc4random_buf(&randomId, 8)
                                    let tempFilePath = NSTemporaryDirectory() + "\(randomId).jpeg"
                                    let scaledSize = image.size.aspectFitted(CGSize(width: 1280.0, height: 1280.0))
                                    if let scaledImage = generateImage(scaledSize, contextGenerator: { size, context in
                                        context.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: size))
                                    }, opaque: true) {
                                        if let scaledImageData = UIImageJPEGRepresentation(scaledImage, 0.52) {
                                            let _ = try? scaledImageData.write(to: URL(fileURLWithPath: tempFilePath))
                                            let resource = LocalFileReferenceMediaResource(localFilePath: tempFilePath, randomId: randomId)
                                            let media = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: randomId), representations: [TelegramMediaImageRepresentation(dimensions: scaledSize, resource: resource)])
                                            messages.append(.message(text: caption ?? "", attributes: [], media: media, replyToMessageId: nil))
                                        }
                                    }
                                case let .asset(asset):
                                    var randomId: Int64 = 0
                                    arc4random_buf(&randomId, 8)
                                    let size = CGSize(width: CGFloat(asset.pixelWidth), height: CGFloat(asset.pixelHeight))
                                    let scaledSize = size.aspectFitted(CGSize(width: 1280.0, height: 1280.0))
                                    let resource = PhotoLibraryMediaResource(localIdentifier: asset.localIdentifier)
                                    
                                    let media = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: randomId), representations: [TelegramMediaImageRepresentation(dimensions: scaledSize, resource: resource)])
                                    messages.append(.message(text: caption ?? "", attributes: [], media: media, replyToMessageId: nil))
                                case .tempFile:
                                    break
                            }
                        case let .file(data, mimeType, name, caption):
                            switch data {
                                case let .tempFile(path):
                                    var randomId: Int64 = 0
                                    arc4random_buf(&randomId, 8)
                                    let resource = LocalFileReferenceMediaResource(localFilePath: path, randomId: randomId)
                                    let media = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), resource: resource, previewRepresentations: [], mimeType: mimeType, size: nil, attributes: [.FileName(fileName: name)])
                                    messages.append(.message(text: caption ?? "", attributes: [], media: media, replyToMessageId: nil))
                                default:
                                    break
                            }
                        case let .video(data, previewImage, adjustments, caption):
                            var finalDimensions: CGSize
                            var finalDuration: Double
                            switch data {
                                case let .asset(asset):
                                    finalDimensions = asset.dimensions
                                    finalDuration = asset.videoDuration
                                case let .tempFile(_, dimensions, duration):
                                    finalDimensions = dimensions
                                    finalDuration = duration
                            }
                            
                            finalDimensions = TGFitSize(finalDimensions, CGSize(width: 848.0, height: 848.0))
                            
                            var previewRepresentations: [TelegramMediaImageRepresentation] = []
                            if let previewImage = previewImage {
                                let resource = LocalFileMediaResource(fileId: arc4random64())
                                let thumbnailSize = finalDimensions.aspectFitted(CGSize(width: 90.0, height: 90.0))
                                let thumbnailImage = TGScaleImageToPixelSize(previewImage, thumbnailSize)!
                                if let thumbnailData = UIImageJPEGRepresentation(thumbnailImage, 0.4) {
                                    account.postbox.mediaBox.storeResourceData(resource.id, data: thumbnailData)
                                    previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: thumbnailSize, resource: resource))
                                }
                            }
                            
                            finalDimensions = TGMediaVideoConverter.dimensions(for: finalDimensions, adjustments: adjustments, preset: TGMediaVideoConversionPresetCompressedMedium)
                            
                            var resourceAdjustments: VideoMediaResourceAdjustments?
                            if let adjustments = adjustments {
                                if adjustments.trimApplied() {
                                    finalDuration = adjustments.trimEndValue - adjustments.trimStartValue
                                }
                                
                                let adjustmentsData = MemoryBuffer(data: NSKeyedArchiver.archivedData(withRootObject: adjustments.dictionary()))
                                let digest = MemoryBuffer(data: adjustmentsData.md5Digest())
                                resourceAdjustments = VideoMediaResourceAdjustments(data: adjustmentsData, digest: digest)
                            }
                            
                            let resource: TelegramMediaResource
                            switch data {
                                case let .asset(asset):
                                    resource = VideoLibraryMediaResource(localIdentifier: asset.backingAsset.localIdentifier, adjustments: resourceAdjustments)
                                case let .tempFile(path, _, _):
                                    resource = LocalFileVideoMediaResource(randomId: arc4random64(), path: path, adjustments: resourceAdjustments)
                            }
                            
                            let media = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: arc4random64()), resource: resource, previewRepresentations: previewRepresentations, mimeType: "video/mp4", size: nil, attributes: [.FileName(fileName: "video.mp4"), .Video(duration: Int(finalDuration), size: finalDimensions)])
                            messages.append(.message(text: caption ?? "", attributes: [], media: media, replyToMessageId: nil))
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
