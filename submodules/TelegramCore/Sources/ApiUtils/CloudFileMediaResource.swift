import Foundation
import Postbox
import TelegramApi


protocol TelegramCloudMediaResource: TelegramMediaResource {
    func apiInputLocation(fileReference: Data?) -> Api.InputFileLocation?
}

public func extractMediaResourceDebugInfo(resource: MediaResource) -> String? {
    if let resource = resource as? TelegramCloudMediaResource {
        guard let inputLocation = resource.apiInputLocation(fileReference: nil) else {
            return nil
        }
        return String(describing: inputLocation)
    } else {
        return nil
    }
}

public protocol TelegramMultipartFetchableResource: TelegramMediaResource {
    var datacenterId: Int { get }
}

public protocol TelegramCloudMediaResourceWithFileReference {
    var fileReference: Data? { get }
}

extension CloudFileMediaResource: TelegramCloudMediaResource, TelegramMultipartFetchableResource, TelegramCloudMediaResourceWithFileReference {
    func apiInputLocation(fileReference: Data?) -> Api.InputFileLocation? {
        return Api.InputFileLocation.inputFileLocation(volumeId: self.volumeId, localId: self.localId, secret: self.secret, fileReference: Buffer(data: fileReference ?? Data()))
    }
}

extension CloudPhotoSizeMediaResource: TelegramCloudMediaResource, TelegramMultipartFetchableResource, TelegramCloudMediaResourceWithFileReference {
    func apiInputLocation(fileReference: Data?) -> Api.InputFileLocation? {
        return Api.InputFileLocation.inputPhotoFileLocation(id: self.photoId, accessHash: self.accessHash, fileReference: Buffer(data: fileReference ?? Data()), thumbSize: self.sizeSpec)
    }
}

extension CloudDocumentSizeMediaResource: TelegramCloudMediaResource, TelegramMultipartFetchableResource, TelegramCloudMediaResourceWithFileReference {
    func apiInputLocation(fileReference: Data?) -> Api.InputFileLocation? {
        return Api.InputFileLocation.inputDocumentFileLocation(id: self.documentId, accessHash: self.accessHash, fileReference: Buffer(data: fileReference ?? Data()), thumbSize: self.sizeSpec)
    }
}

extension CloudPeerPhotoSizeMediaResource: TelegramMultipartFetchableResource {
    func apiInputLocation(peerReference: PeerReference) -> Api.InputFileLocation? {
        let flags: Int32
        switch self.sizeSpec {
            case .small:
                flags = 0
            case .fullSize:
                flags = 1 << 0
        }
        if let photoId = self.photoId {
            return Api.InputFileLocation.inputPeerPhotoFileLocation(flags: flags, peer: peerReference.inputPeer, photoId: photoId)
        } else {
            return nil
        }
    }
}

extension CloudStickerPackThumbnailMediaResource: TelegramMultipartFetchableResource {
    func apiInputLocation(packReference: StickerPackReference) -> Api.InputFileLocation? {
        if let thumbVersion = self.thumbVersion {
            return Api.InputFileLocation.inputStickerSetThumb(stickerset: packReference.apiInputStickerSet, thumbVersion: thumbVersion)
        } else {
            return nil
        }
    }
}

extension CloudDocumentMediaResource: TelegramCloudMediaResource, TelegramMultipartFetchableResource, TelegramCloudMediaResourceWithFileReference {
    func apiInputLocation(fileReference: Data?) -> Api.InputFileLocation? {
        return Api.InputFileLocation.inputDocumentFileLocation(id: self.fileId, accessHash: self.accessHash, fileReference: Buffer(data: fileReference ?? Data()), thumbSize: "")
    }
}

extension SecretFileMediaResource: TelegramCloudMediaResource, TelegramMultipartFetchableResource {
    func apiInputLocation(fileReference: Data?) -> Api.InputFileLocation? {
        return .inputEncryptedFileLocation(id: self.fileId, accessHash: self.accessHash)
    }
}

extension WebFileReferenceMediaResource {
    var apiInputLocation: Api.InputWebFileLocation {
        return .inputWebFileLocation(url: self.url, accessHash: self.accessHash)
    }
}
