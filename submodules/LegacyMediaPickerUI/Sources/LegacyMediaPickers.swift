import Foundation
import UIKit
import LegacyComponents
import SwiftSignalKit
import TelegramCore
import SyncCore
import Postbox
import SSignalKit
import Display
import TelegramPresentationData
import DeviceAccess
import AccountContext
import ImageCompression
import MimeTypes
import LocalMediaResources
import LegacyUI

public func guessMimeTypeByFileExtension(_ ext: String) -> String {
    return TGMimeTypeMap.mimeType(forExtension: ext) ?? "application/binary"
}

public func configureLegacyAssetPicker(_ controller: TGMediaAssetsController, context: AccountContext, peer: Peer, captionsEnabled: Bool = true, storeCreatedAssets: Bool = true, showFileTooltip: Bool = false, initialCaption: String, hasSchedule: Bool, presentWebSearch: (() -> Void)?, presentSelectionLimitExceeded: @escaping () -> Void, presentSchedulePicker: @escaping (@escaping (Int32) -> Void) -> Void) {
    let isSecretChat = peer.id.namespace == Namespaces.Peer.SecretChat
    
    controller.captionsEnabled = captionsEnabled
    controller.inhibitDocumentCaptions = false
    controller.suggestionContext = legacySuggestionContext(context: context, peerId: peer.id)
    if peer.id != context.account.peerId {
        if peer is TelegramUser {
            controller.hasTimer = hasSchedule
        }
        controller.hasSilentPosting = !isSecretChat
    }
    controller.hasSchedule = hasSchedule
    controller.reminder = peer.id == context.account.peerId
    controller.presentScheduleController = { done in
        presentSchedulePicker { time in
            done?(time)
        }
    }
    controller.dismissalBlock = {
    }
    controller.selectionLimitExceeded = {
        presentSelectionLimitExceeded()
    }
    controller.localMediaCacheEnabled = false
    controller.shouldStoreAssets = storeCreatedAssets
    controller.shouldShowFileTipIfNeeded = showFileTooltip
    controller.requestSearchController = presentWebSearch
    
    controller.editingContext.setInitialCaption(initialCaption, entities: [])
}

public func legacyAssetPicker(context: AccountContext, presentationData: PresentationData, editingMedia: Bool, fileMode: Bool, peer: Peer?, saveEditedPhotos: Bool, allowGrouping: Bool, selectionLimit: Int) -> Signal<(LegacyComponentsContext) -> TGMediaAssetsController, Void> {
    let isSecretChat = (peer?.id.namespace ?? 0) == Namespaces.Peer.SecretChat
    
    return Signal { subscriber in
        let intent = fileMode ? TGMediaAssetsControllerSendFileIntent : TGMediaAssetsControllerSendMediaIntent
        let defaultVideoPreset = defaultVideoPresetForContext(context)
        UserDefaults.standard.set(defaultVideoPreset.rawValue as NSNumber, forKey: "TG_preferredVideoPreset_v0")
        
        DeviceAccess.authorizeAccess(to: .mediaLibrary(.send), presentationData: presentationData, present: context.sharedContext.presentGlobalController, openSettings: context.sharedContext.applicationBindings.openSettings, { value in
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
                                let controller = TGMediaAssetsController(context: context, assetGroup: group, intent: intent, recipientName: peer?.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), saveEditedPhotos: !isSecretChat && saveEditedPhotos, allowGrouping: allowGrouping, inhibitSelection: editingMedia, selectionLimit: Int32(selectionLimit))
                                return controller!
                            })
                            subscriber.putCompletion()
                        }
                    }
                })
            } else {
                subscriber.putNext({ context in
                    let controller = TGMediaAssetsController(context: context, assetGroup: nil, intent: intent, recipientName: peer?.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), saveEditedPhotos: !isSecretChat && saveEditedPhotos, allowGrouping: allowGrouping, selectionLimit: Int32(selectionLimit))
                    return controller!
                })
                subscriber.putCompletion()
            }  
        })
        
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
    case image(data: LegacyAssetImageData, thumbnail: UIImage?, caption: String?, stickers: [FileMediaReference])
    case file(data: LegacyAssetImageData, thumbnail: UIImage?, mimeType: String, name: String, caption: String?)
    case video(data: LegacyAssetVideoData, thumbnail: UIImage?, adjustments: TGVideoEditAdjustments?, caption: String?, asFile: Bool, asAnimation: Bool, stickers: [FileMediaReference])
}

private final class LegacyAssetItemWrapper: NSObject {
    let item: LegacyAssetItem
    let timer: Int?
    let groupedId: Int64?
    
    init(item: LegacyAssetItem, timer: Int?, groupedId: Int64?) {
        self.item = item
        self.timer = timer
        self.groupedId = groupedId
        
        super.init()
    }
}

public func legacyAssetPickerItemGenerator() -> ((Any?, String?, [Any]?, String?) -> [AnyHashable : Any]?) {
    return { anyDict, caption, entities, hash in
        let dict = anyDict as! NSDictionary
        if (dict["type"] as! NSString) == "editedPhoto" || (dict["type"] as! NSString) == "capturedPhoto" {
            let image = dict["image"] as! UIImage
            let thumbnail = dict["previewImage"] as? UIImage
            (dict["stickers"] as? Array<TGDocumentMediaAttachment>).map { element in
            
            }
            
            let stickers = (dict["stickers"] as? [TGDocumentMediaAttachment])?.compactMap { document -> FileMediaReference? in
                if let sticker = stickerFromLegacyDocument(document) {
                    return FileMediaReference.standalone(media: sticker)
                } else {
                    return nil
                }
            } ?? []
            var result: [AnyHashable : Any] = [:]
            result["item" as NSString] = LegacyAssetItemWrapper(item: .image(data: .image(image), thumbnail: thumbnail, caption: caption, stickers: stickers), timer: (dict["timer"] as? NSNumber)?.intValue, groupedId: (dict["groupedId"] as? NSNumber)?.int64Value)
            return result
        } else if (dict["type"] as! NSString) == "cloudPhoto" {
            let asset = dict["asset"] as! TGMediaAsset
            let thumbnail = dict["previewImage"] as? UIImage
            var asFile = false
            if let document = dict["document"] as? NSNumber, document.boolValue {
                asFile = true
            }
            var result: [AnyHashable: Any] = [:]
            if asFile {
                var mimeType = "image/jpeg"
                if let customMimeType = dict["mimeType"] as? String {
                    mimeType = customMimeType
                }
                var name = "image.jpg"
                if let customName = dict["fileName"] as? String {
                    name = customName
                }
                
                result["item" as NSString] = LegacyAssetItemWrapper(item: .file(data: .asset(asset.backingAsset), thumbnail: thumbnail, mimeType: mimeType, name: name, caption: caption), timer: nil, groupedId: nil)
            } else {
                result["item" as NSString] = LegacyAssetItemWrapper(item: .image(data: .asset(asset.backingAsset), thumbnail: thumbnail, caption: caption, stickers: []), timer: (dict["timer"] as? NSNumber)?.intValue, groupedId: (dict["groupedId"] as? NSNumber)?.int64Value)
            }
            return result
        } else if (dict["type"] as! NSString) == "file" {
            if let tempFileUrl = dict["tempFileUrl"] as? URL {
                let thumbnail = dict["previewImage"] as? UIImage
                var mimeType = "application/binary"
                if let customMimeType = dict["mimeType"] as? String {
                    mimeType = customMimeType
                }
                var name = "file"
                if let customName = dict["fileName"] as? String {
                    name = customName
                }
                
                if let isAnimation = dict["isAnimation"] as? NSNumber, isAnimation.boolValue, mimeType == "video/mp4" {
                    var result: [AnyHashable: Any] = [:]
                    
                    let dimensions = (dict["dimensions"]! as AnyObject).cgSizeValue!
                    let duration = (dict["duration"]! as AnyObject).doubleValue!
                    
                    result["item" as NSString] = LegacyAssetItemWrapper(item: .video(data: .tempFile(path: tempFileUrl.path, dimensions: dimensions, duration: duration), thumbnail: thumbnail, adjustments: nil, caption: caption, asFile: false, asAnimation: true, stickers: []), timer: (dict["timer"] as? NSNumber)?.intValue, groupedId: (dict["groupedId"] as? NSNumber)?.int64Value)
                    return result
                }
                
                var result: [AnyHashable: Any] = [:]
                result["item" as NSString] = LegacyAssetItemWrapper(item: .file(data: .tempFile(tempFileUrl.path), thumbnail: thumbnail, mimeType: mimeType, name: name, caption: caption), timer: (dict["timer"] as? NSNumber)?.intValue, groupedId: (dict["groupedId"] as? NSNumber)?.int64Value)
                return result
            }
        } else if (dict["type"] as! NSString) == "video" {
            let thumbnail = dict["previewImage"] as? UIImage
            var asFile = false
            if let document = dict["document"] as? NSNumber, document.boolValue {
                asFile = true
            }
            
            if let asset = dict["asset"] as? TGMediaAsset {
                var result: [AnyHashable: Any] = [:]
                result["item" as NSString] = LegacyAssetItemWrapper(item: .video(data: .asset(asset), thumbnail: thumbnail, adjustments: dict["adjustments"] as? TGVideoEditAdjustments, caption: caption, asFile: asFile, asAnimation: false, stickers: []), timer: (dict["timer"] as? NSNumber)?.intValue, groupedId: (dict["groupedId"] as? NSNumber)?.int64Value)
                return result
            } else if let url = (dict["url"] as? String) ?? (dict["url"] as? URL)?.absoluteString {
                let dimensions = (dict["dimensions"]! as AnyObject).cgSizeValue!
                let duration = (dict["duration"]! as AnyObject).doubleValue!
                var result: [AnyHashable: Any] = [:]
                result["item" as NSString] = LegacyAssetItemWrapper(item: .video(data: .tempFile(path: url, dimensions: dimensions, duration: duration), thumbnail: thumbnail, adjustments: dict["adjustments"] as? TGVideoEditAdjustments, caption: caption, asFile: asFile, asAnimation: false, stickers: []), timer: (dict["timer"] as? NSNumber)?.intValue, groupedId: (dict["groupedId"] as? NSNumber)?.int64Value)
                return result
            }
        } else if (dict["type"] as! NSString) == "cameraVideo" {
            let thumbnail = dict["previewImage"] as? UIImage
            var asFile = false
            if let document = dict["document"] as? NSNumber, document.boolValue {
                asFile = true
            }
            
            let url: String? = (dict["url"] as? String) ?? (dict["url"] as? URL)?.absoluteString
            
            if let url = url, let previewImage = dict["previewImage"] as? UIImage {
                let dimensions = previewImage.pixelSize()
                let duration = (dict["duration"]! as AnyObject).doubleValue!
                var result: [AnyHashable: Any] = [:]
                result["item" as NSString] = LegacyAssetItemWrapper(item: .video(data: .tempFile(path: url, dimensions: dimensions, duration: duration), thumbnail: thumbnail, adjustments: dict["adjustments"] as? TGVideoEditAdjustments, caption: caption, asFile: asFile, asAnimation: false, stickers: []), timer: (dict["timer"] as? NSNumber)?.intValue, groupedId: (dict["groupedId"] as? NSNumber)?.int64Value)
                return result
            }
        }
        return nil
    }
}

public func legacyEnqueueGifMessage(account: Account, data: Data) -> Signal<EnqueueMessage, Void> {
    return Signal { subscriber in
        if let previewImage = UIImage(data: data) {
            let dimensions = previewImage.size
            var previewRepresentations: [TelegramMediaImageRepresentation] = []
            
            let thumbnailSize = dimensions.aspectFitted(CGSize(width: 320.0, height: 320.0))
            let thumbnailImage = TGScaleImageToPixelSize(previewImage, thumbnailSize)!
            if let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.4) {
                let resource = LocalFileMediaResource(fileId: arc4random64())
                account.postbox.mediaBox.storeResourceData(resource.id, data: thumbnailData)
                previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(thumbnailSize), resource: resource))
            }
            
            var randomId: Int64 = 0
            arc4random_buf(&randomId, 8)
            let tempFilePath = NSTemporaryDirectory() + "\(randomId).gif"
            
            let _ = try? FileManager.default.removeItem(atPath: tempFilePath)
            let _ = try? data.write(to: URL(fileURLWithPath: tempFilePath), options: [.atomic])
        
            let resource = LocalFileGifMediaResource(randomId: arc4random64(), path: tempFilePath)
            let fileName: String = "video.mp4"
            
            let finalDimensions = TGMediaVideoConverter.dimensions(for: dimensions, adjustments: nil, preset: TGMediaVideoConversionPresetAnimation)
            
            var fileAttributes: [TelegramMediaFileAttribute] = []
            fileAttributes.append(.Video(duration: Int(0), size: PixelDimensions(finalDimensions), flags: [.supportsStreaming]))
            fileAttributes.append(.FileName(fileName: fileName))
            fileAttributes.append(.Animated)
            
            let media = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: arc4random64()), partialReference: nil, resource: resource, previewRepresentations: previewRepresentations, immediateThumbnailData: nil, mimeType: "video/mp4", size: nil, attributes: fileAttributes)
            subscriber.putNext(.message(text: "", attributes: [], mediaReference: .standalone(media: media), replyToMessageId: nil, localGroupingKey: nil))
            subscriber.putCompletion()
        } else {
            subscriber.putError(Void())
        }
        
        return EmptyDisposable
    } |> runOn(Queue.concurrentDefaultQueue())
}

public func legacyAssetPickerEnqueueMessages(account: Account, signals: [Any]) -> Signal<[EnqueueMessage], Void> {
    return Signal { subscriber in
        let disposable = SSignal.combineSignals(signals).start(next: { anyValues in
            var messages: [EnqueueMessage] = []
            
            outer: for item in (anyValues as! NSArray) {
                if let item = (item as? NSDictionary)?.object(forKey: "item") as? LegacyAssetItemWrapper {
                    switch item.item {
                        case let .image(data, thumbnail, caption, stickers):
                            var representations: [TelegramMediaImageRepresentation] = []
                            if let thumbnail = thumbnail {
                                let resource = LocalFileMediaResource(fileId: arc4random64())
                                let thumbnailSize = thumbnail.size.aspectFitted(CGSize(width: 320.0, height: 320.0))
                                let thumbnailImage = TGScaleImageToPixelSize(thumbnail, thumbnailSize)!
                                if let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.4) {
                                    account.postbox.mediaBox.storeResourceData(resource.id, data: thumbnailData)
                                    representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(thumbnailSize), resource: resource))
                                }
                            }
                            switch data {
                                case let .image(image):
                                    var randomId: Int64 = 0
                                    arc4random_buf(&randomId, 8)
                                    let tempFilePath = NSTemporaryDirectory() + "\(randomId).jpeg"
                                    let scaledSize = image.size.aspectFittedOrSmaller(CGSize(width: 1280.0, height: 1280.0))
                                    if let scaledImage = TGScaleImageToPixelSize(image, scaledSize) {
                                        if let scaledImageData = compressImageToJPEG(scaledImage, quality: 0.6) {
                                            let _ = try? scaledImageData.write(to: URL(fileURLWithPath: tempFilePath))
                                            #if DEBUG
                                                if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                                                    if false, let heicData = compressImage(scaledImage, quality: 0.65) {
                                                        print("scaledImageData \(scaledImageData.count), heicData \(heicData.count)")
                                                        var randomId: Int64 = 0
                                                        arc4random_buf(&randomId, 8)
                                                        let _ = try? heicData.write(to: URL(fileURLWithPath: tempFilePath + ".heic"))
                                                        let resource = LocalFileReferenceMediaResource(localFilePath: tempFilePath + ".heic", randomId: randomId)
                                                        let media = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), partialReference: nil, resource: resource, previewRepresentations: [], immediateThumbnailData: nil, mimeType: "image/heic", size: nil, attributes: [.FileName(fileName: "image.heic")])
                                                        var attributes: [MessageAttribute] = []
                                                        if let timer = item.timer, timer > 0 && timer <= 60 {
                                                            attributes.append(AutoremoveTimeoutMessageAttribute(timeout: Int32(timer), countdownBeginTime: nil))
                                                        }
                                                        messages.append(.message(text: caption ?? "", attributes: attributes, mediaReference: .standalone(media: media), replyToMessageId: nil, localGroupingKey: item.groupedId))
                                                    }
                                                }
                                            #endif

                                            let resource = LocalFileReferenceMediaResource(localFilePath: tempFilePath, randomId: randomId)
                                            representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(scaledSize), resource: resource))
                                            
                                            var imageFlags: TelegramMediaImageFlags = []
                                            
                                            var stickerFiles: [TelegramMediaFile] = []
                                            if !stickers.isEmpty {
                                                for fileReference in stickers {
                                                    stickerFiles.append(fileReference.media)
                                                }
                                            }
                                            
                                            var attributes: [MessageAttribute] = []
                                            
                                            if !stickerFiles.isEmpty {
                                                attributes.append(EmbeddedMediaStickersMessageAttribute(files: stickerFiles))
                                                imageFlags.insert(.hasStickers)
                                            }

                                            let media = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: randomId), representations: representations, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: imageFlags)
                                            if let timer = item.timer, timer > 0 && timer <= 60 {
                                                attributes.append(AutoremoveTimeoutMessageAttribute(timeout: Int32(timer), countdownBeginTime: nil))
                                            }
                                            
                                            var text = caption ?? ""                                            
                                            messages.append(.message(text: text, attributes: attributes, mediaReference: .standalone(media: media), replyToMessageId: nil, localGroupingKey: item.groupedId))
                                        }
                                    }
                                case let .asset(asset):
                                    var randomId: Int64 = 0
                                    arc4random_buf(&randomId, 8)
                                    let size = CGSize(width: CGFloat(asset.pixelWidth), height: CGFloat(asset.pixelHeight))
                                    let scaledSize = size.aspectFittedOrSmaller(CGSize(width: 1280.0, height: 1280.0))
                                    let resource = PhotoLibraryMediaResource(localIdentifier: asset.localIdentifier, uniqueId: arc4random64())
                                    representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(scaledSize), resource: resource))
                                    
                                    let media = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: randomId), representations: representations, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                                    var attributes: [MessageAttribute] = []
                                    if let timer = item.timer, timer > 0 && timer <= 60 {
                                        attributes.append(AutoremoveTimeoutMessageAttribute(timeout: Int32(timer), countdownBeginTime: nil))
                                    }
                                    messages.append(.message(text: caption ?? "", attributes: attributes, mediaReference: .standalone(media: media), replyToMessageId: nil, localGroupingKey: item.groupedId))
                                case .tempFile:
                                    break
                            }
                        case let .file(data, thumbnail, mimeType, name, caption):
                            switch data {
                                case let .tempFile(path):
                                    var randomId: Int64 = 0
                                    arc4random_buf(&randomId, 8)
                                    let resource = LocalFileReferenceMediaResource(localFilePath: path, randomId: randomId)
                                    let media = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), partialReference: nil, resource: resource, previewRepresentations: [], immediateThumbnailData: nil, mimeType: mimeType, size: nil, attributes: [.FileName(fileName: name)])
                                    messages.append(.message(text: caption ?? "", attributes: [], mediaReference: .standalone(media: media), replyToMessageId: nil, localGroupingKey: item.groupedId))
                                case let .asset(asset):
                                    var randomId: Int64 = 0
                                    arc4random_buf(&randomId, 8)
                                    let resource = PhotoLibraryMediaResource(localIdentifier: asset.localIdentifier, uniqueId: arc4random64())
                                    let media = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), partialReference: nil, resource: resource, previewRepresentations: [], immediateThumbnailData: nil, mimeType: mimeType, size: nil, attributes: [.FileName(fileName: name)])
                                    messages.append(.message(text: caption ?? "", attributes: [], mediaReference: .standalone(media: media), replyToMessageId: nil, localGroupingKey: item.groupedId))
                                default:
                                    break
                            }
                        case let .video(data, thumbnail, adjustments, caption, asFile, asAnimation, stickers):
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
                            
                            if !asAnimation {
                                finalDimensions = TGFitSize(finalDimensions, CGSize(width: 848.0, height: 848.0))
                            }
                            
                            var previewRepresentations: [TelegramMediaImageRepresentation] = []
                            if let thumbnail = thumbnail {
                                let resource = LocalFileMediaResource(fileId: arc4random64())
                                let thumbnailSize = finalDimensions.aspectFitted(CGSize(width: 320.0, height: 320.0))
                                let thumbnailImage = TGScaleImageToPixelSize(thumbnail, thumbnailSize)!
                                if let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.4) {
                                    account.postbox.mediaBox.storeResourceData(resource.id, data: thumbnailData)
                                    previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(thumbnailSize), resource: resource))
                                }
                            }
                            
                            if !asAnimation {
                                finalDimensions = TGMediaVideoConverter.dimensions(for: finalDimensions, adjustments: adjustments, preset: TGMediaVideoConversionPresetCompressedMedium)
                            }
                            
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
                            var fileName: String = "video.mp4"
                            switch data {
                                case let .asset(asset):
                                    if let assetFileName = asset.fileName, !assetFileName.isEmpty {
                                        fileName = (assetFileName as NSString).lastPathComponent
                                    }
                                    resource = VideoLibraryMediaResource(localIdentifier: asset.backingAsset.localIdentifier, conversion: asFile ? .passthrough : .compress(resourceAdjustments))
                                case let .tempFile(path, _, _):
                                    if asFile || asAnimation {
                                        if let size = fileSize(path) {
                                            resource = LocalFileMediaResource(fileId: arc4random64(), size: size)
                                            account.postbox.mediaBox.moveResourceData(resource.id, fromTempPath: path)
                                        } else {
                                            continue outer
                                        }
                                    } else {
                                        resource = LocalFileVideoMediaResource(randomId: arc4random64(), path: path, adjustments: resourceAdjustments)
                                    }
                            }
                            
                            var fileAttributes: [TelegramMediaFileAttribute] = []
                            fileAttributes.append(.FileName(fileName: fileName))
                            if asAnimation {
                                fileAttributes.append(.Animated)
                            }
                            if !asFile {
                                fileAttributes.append(.Video(duration: Int(finalDuration), size: PixelDimensions(finalDimensions), flags: [.supportsStreaming]))
                                if let adjustments = adjustments {
                                    if adjustments.sendAsGif {
                                        fileAttributes.append(.Animated)
                                    }
                                }
                            }
                            
                            let media = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: arc4random64()), partialReference: nil, resource: resource, previewRepresentations: previewRepresentations, immediateThumbnailData: nil, mimeType: "video/mp4", size: nil, attributes: fileAttributes)
                            var attributes: [MessageAttribute] = []
                            if let timer = item.timer, timer > 0 && timer <= 60 {
                                attributes.append(AutoremoveTimeoutMessageAttribute(timeout: Int32(timer), countdownBeginTime: nil))
                            }
                            messages.append(.message(text: caption ?? "", attributes: attributes, mediaReference: .standalone(media: media), replyToMessageId: nil, localGroupingKey: item.groupedId))
                    }
                }
            }
            
            subscriber.putNext(messages)
            subscriber.putCompletion()
        }, error: { _ in
            subscriber.putError(Void())
        }, completed: nil)
        
        return ActionDisposable {
            disposable?.dispose()
        }
    }
}
