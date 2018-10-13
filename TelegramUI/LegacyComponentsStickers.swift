import Foundation
import LegacyComponents
import Postbox
import TelegramCore
import SwiftSignalKit

func legacyComponentsStickers(postbox: Postbox, namespace: Int32) -> SSignal {
    return SSignal { subscriber in
        let disposable = (postbox.itemCollectionsView(orderedItemListCollectionIds: [], namespaces: [namespace], aroundIndex: nil, count: 1000)).start(next: { view in
            var stickerPackDocuments: [ItemCollectionId: [Any]] = [:]
            
            for entry in view.entries {
                if let item = entry.item as? StickerPackItem {
                    if stickerPackDocuments[entry.index.collectionId] == nil {
                        stickerPackDocuments[entry.index.collectionId] = []
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
                        imageInfo.addImage(with: thumbnail.dimensions, url: "\(thumbnail.resource)")
                    }
                    var attributes: [Any] = []
                    for attribute in item.file.attributes {
                        switch attribute {
                            case let .Sticker(displayText, _, maskData):
                                attributes.append(TGDocumentAttributeSticker(alt: displayText, packReference: nil, mask: maskData.flatMap {
                                    return TGStickerMaskDescription(n: $0.n, point: CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)), zoom: CGFloat($0.zoom))
                                }))
                            case let .ImageSize(size):
                                attributes.append(TGDocumentAttributeImageSize(size: size))
                            default:
                                break
                        }
                    }
                    document.attributes = attributes
                    stickerPackDocuments[entry.index.collectionId]!.append(document)
                }
            }
            
            let stickerPacks = NSMutableArray()
            for (id, info, _) in view.collectionInfos {
                if let info = info as? StickerPackCollectionInfo {
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
            let highQuality: Bool
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
            
            let fitSize = CGSize(width: CGFloat(width), height: CGFloat(height))
            
            var attributes: [TelegramMediaFileAttribute] = []
            if let originInfoString = args["origin_info"] as? String, let originInfo = TGMediaOriginInfo(stringRepresentation: originInfoString), let stickerPackId = originInfo.stickerPackId?.int64Value, let stickerPackAccessHash = originInfo.stickerPackAccessHash?.int64Value {
                attributes.append(.Sticker(displayText: "", packReference: .id(id: stickerPackId, accessHash: stickerPackAccessHash), maskData: nil))
            }
            
            return LegacyStickerImageDataTask(account: account, file: TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudFile, id: documentId), partialReference: nil, resource: CloudDocumentMediaResource(datacenterId: datacenterId, fileId: documentId, accessHash: accessHash, size: size, fileReference: nil, fileName: fileNameFromFileAttributes(attributes)), previewRepresentations: [], mimeType: "image/webp", size: size, attributes: attributes), small: !highQuality, fitSize: fitSize, completion: { image in
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
