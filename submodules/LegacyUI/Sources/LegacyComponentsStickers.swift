import Foundation
import UIKit
import LegacyComponents
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import Display
import StickerResources

public func stickerFromLegacyDocument(_ documentAttachment: TGDocumentMediaAttachment) -> TelegramMediaFile? {
    if documentAttachment.isSticker() {
        for case let sticker as TGDocumentAttributeSticker in documentAttachment.attributes {
            var attributes: [TelegramMediaFileAttribute] = []
            var packReference: StickerPackReference?
            if let legacyPackReference = sticker.packReference as? TGStickerPackIdReference {
                packReference = .id(id: legacyPackReference.packId, accessHash: legacyPackReference.packAccessHash)
            } else if let legacyPackReference = sticker.packReference as? TGStickerPackShortnameReference {
                packReference = .name(legacyPackReference.shortName)
            }
            attributes.append(.Sticker(displayText: sticker.alt, packReference: packReference, maskData: nil))
            
            var fileReference: Data?
            if let originInfo = documentAttachment.originInfo, let data = originInfo.fileReference {
                fileReference = data
            }
            
            return TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudFile, id: documentAttachment.documentId), partialReference: nil, resource: CloudDocumentMediaResource(datacenterId: Int(documentAttachment.datacenterId), fileId: documentAttachment.documentId, accessHash: documentAttachment.accessHash, size: Int(documentAttachment.size), fileReference: fileReference, fileName: documentAttachment.fileName()), previewRepresentations: [], immediateThumbnailData: nil, mimeType: documentAttachment.mimeType, size: Int(documentAttachment.size), attributes: attributes)
        }
    }
    return nil
}

func legacyComponentsStickers(postbox: Postbox, namespace: Int32) -> SSignal {
    return SSignal { subscriber in
        let disposable = (postbox.itemCollectionsView(orderedItemListCollectionIds: [], namespaces: [namespace], aroundIndex: nil, count: 200 * 200)).start(next: { view in
            var stickerPackDocuments: [ItemCollectionId: [Any]] = [:]
            
            for entry in view.entries {
                if let item = entry.item as? StickerPackItem {
                    if item.file.isAnimatedSticker {
                        continue
                    }
                    let document = TGDocumentMediaAttachment()
                    document.documentId = item.file.fileId.id
                    if let resource = item.file.resource as? CloudDocumentMediaResource {
                        document.accessHash = resource.accessHash
                        document.datacenterId = Int32(resource.datacenterId)
                        var stickerPackId: Int64 = 0
                        var accessHash: Int64 = 0
                        for case let .Sticker(sticker) in item.file.attributes {
                            if let packReference = sticker.packReference, case let .id(id, h) = packReference {
                                stickerPackId = id
                                accessHash = h
                            }
                            break
                        }
                        document.originInfo = TGMediaOriginInfo(fileReference: resource.fileReference ?? Data(), fileReferences: [:], stickerPackId: stickerPackId, accessHash: accessHash)
                    }
                    document.mimeType = item.file.mimeType
                    if let size = item.file.size {
                        document.size = Int32(size)
                    }
                    if let thumbnail = item.file.previewRepresentations.first {
                        let imageInfo = TGImageInfo()
                        let encoder = PostboxEncoder()
                        encoder.encodeRootObject(thumbnail.resource)
                        let dataString = encoder.makeData().base64EncodedString(options: [])
                        imageInfo.addImage(with: thumbnail.dimensions.cgSize, url: dataString)
                        document.thumbnailInfo = imageInfo
                    }
                    var attributes: [Any] = []
                    for attribute in item.file.attributes {
                        switch attribute {
                            case let .Sticker(displayText, _, maskData):
                                attributes.append(TGDocumentAttributeSticker(alt: displayText, packReference: nil, mask: maskData.flatMap {
                                    return TGStickerMaskDescription(n: $0.n, point: CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)), zoom: CGFloat($0.zoom))
                                }))
                            case let .ImageSize(size):
                                attributes.append(TGDocumentAttributeImageSize(size: size.cgSize))
                            default:
                                break
                        }
                    }
                    document.attributes = attributes
                    if stickerPackDocuments[entry.index.collectionId] == nil {
                        stickerPackDocuments[entry.index.collectionId] = []
                    }
                    stickerPackDocuments[entry.index.collectionId]!.append(document)
                }
            }
            
            let stickerPacks = NSMutableArray()
            for (id, info, _) in view.collectionInfos {
                if let info = info as? StickerPackCollectionInfo, !info.flags.contains(.isAnimated) {
                    let pack = TGStickerPack(packReference: TGStickerPackIdReference(), title: info.title, stickerAssociations: [], documents: stickerPackDocuments[id] ?? [], packHash: info.hash, hidden: false, isMask: true, isFeatured: false, installedDate: 0)!
                    stickerPacks.add(pack)
                }
            }
            
            var dict: [AnyHashable: Any] = [:]
            dict["packs"] = stickerPacks
            subscriber?.putNext(dict)
        })
        
        return SBlockDisposable {
            disposable.dispose()
        }
    }
}

private final class LegacyStickerImageDataTask: NSObject {
    private let disposable = DisposableSet()
    
    init(account: Account, file: TelegramMediaFile, small: Bool, fitSize: CGSize, completion: @escaping (UIImage?) -> Void) {
        super.init()
        
        self.disposable.add(chatMessageLegacySticker(account: account, file: file, small: small, fitSize: fitSize, fetched: true, onlyFullSize: true).start(next: { generator in
            if let image = generator(TransformImageArguments(corners: ImageCorners(), imageSize: fitSize, boundingSize: fitSize, intrinsicInsets: UIEdgeInsets()))?.generateImage() {
                completion(image)
            }
        }))
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    func cancel() {
        self.disposable.dispose()
    }
}

private let sharedImageCache = TGMemoryImageCache(softMemoryLimit: 2 * 1024 * 1024, hardMemoryLimit: 3 * 1024 * 1024)!

final class LegacyStickerImageDataSource: TGImageDataSource {
    private let account: () -> Account?
    
    init(account: @escaping () -> Account?) {
        self.account = account
        
        super.init()
    }
    
    override func canHandleUri(_ uri: String!) -> Bool {
        if let uri = uri {
            if uri.hasPrefix("sticker-preview://") {
                return true
            } else if uri.hasPrefix("sticker://") {
                return true
            }
        }
        return false
    }
    
    override func loadDataSync(withUri uri: String!, canWait: Bool, acceptPartialData: Bool, asyncTaskId: AutoreleasingUnsafeMutablePointer<AnyObject?>!, progress: ((Float) -> Void)!, partialCompletion: ((TGDataResource?) -> Void)!, completion: ((TGDataResource?) -> Void)!) -> TGDataResource! {
        if let image = sharedImageCache.image(forKey: uri, attributes: nil) {
            return TGDataResource(image: image, decoded: true)
        }
        return nil
    }
    
    override func loadDataAsync(withUri uri: String!, progress: ((Float) -> Void)!, partialCompletion: ((TGDataResource?) -> Void)!, completion: ((TGDataResource?) -> Void)!) -> Any! {
        if let account = self.account() {
            let args: [AnyHashable : Any]
            var highQuality: Bool
            if uri.hasPrefix("sticker-preview://") {
                let argumentsString = String(uri[uri.index(uri.startIndex, offsetBy: "sticker-preview://?".count)...])
                args = TGStringUtils.argumentDictionary(inUrlString: argumentsString)!
                highQuality = Int((args["highQuality"] as! String))! != 0
            } else if uri.hasPrefix("sticker://") {
                let argumentsString = String(uri[uri.index(uri.startIndex, offsetBy: "sticker://?".count)...])
                args = TGStringUtils.argumentDictionary(inUrlString: argumentsString)!
                highQuality = true
            } else {
                return nil
            }
            
            let documentId = Int64((args["documentId"] as! String))!
            let datacenterId = Int((args["datacenterId"] as! String))!
            let accessHash = Int64((args["accessHash"] as! String))!
            let size: Int? = nil
            
            let width = Int((args["width"] as! String))!
            let height = Int((args["height"] as! String))!
            
            if width < 128 {
                highQuality = false
            }
            
            let fitSize = CGSize(width: CGFloat(width), height: CGFloat(height))
            
            var attributes: [TelegramMediaFileAttribute] = []
            if let originInfoString = args["origin_info"] as? String, let originInfo = TGMediaOriginInfo(stringRepresentation: originInfoString), let stickerPackId = originInfo.stickerPackId?.int64Value, let stickerPackAccessHash = originInfo.stickerPackAccessHash?.int64Value {
                attributes.append(.Sticker(displayText: "", packReference: .id(id: stickerPackId, accessHash: stickerPackAccessHash), maskData: nil))
            }
            
            var previewRepresentations: [TelegramMediaImageRepresentation] = []
            if let legacyThumbnailUri = args["legacyThumbnailUri"] as? String, let data = Data(base64Encoded: legacyThumbnailUri, options: []) {
                if let resource = PostboxDecoder(buffer: MemoryBuffer(data: data)).decodeRootObject() as? TelegramMediaResource {
                    previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 140, height: 140), resource: resource))
                }
            }
            
            return LegacyStickerImageDataTask(account: account, file: TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudFile, id: documentId), partialReference: nil, resource: CloudDocumentMediaResource(datacenterId: datacenterId, fileId: documentId, accessHash: accessHash, size: size, fileReference: nil, fileName: fileNameFromFileAttributes(attributes)), previewRepresentations: previewRepresentations, immediateThumbnailData: nil, mimeType: "image/webp", size: size, attributes: attributes), small: !highQuality, fitSize: fitSize, completion: { image in
                if let image = image {
                    sharedImageCache.setImage(image, forKey: uri, attributes: nil)
                    completion?(TGDataResource(image: image, decoded: true))
                }
            })
        } else {
            return nil
        }
    }
    
    override func cancelTask(byId taskId: Any!) {
        if let task = taskId as? LegacyStickerImageDataTask {
            task.cancel()
        }
    }
}
