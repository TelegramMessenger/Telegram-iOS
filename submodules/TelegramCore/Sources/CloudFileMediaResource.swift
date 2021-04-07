import Foundation
import Postbox
import TelegramApi

import SyncCore

protocol TelegramCloudMediaResource: TelegramMediaResource {
    func apiInputLocation(fileReference: Data?) -> Api.InputFileLocation?
}

protocol TelegramMultipartFetchableResource: TelegramMediaResource {
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

extension CloudPeerPhotoSizeMediaResource:  TelegramMultipartFetchableResource {
    func apiInputLocation(peerReference: PeerReference) -> Api.InputFileLocation? {
        let flags: Int32
        switch self.sizeSpec {
            case .small:
                flags = 0
            case .fullSize:
                flags = 1 << 0
        }
        return Api.InputFileLocation.inputPeerPhotoFileLocation(flags: flags, peer: peerReference.inputPeer, volumeId: self.volumeId, localId: self.localId)
    }
}

extension CloudStickerPackThumbnailMediaResource:  TelegramMultipartFetchableResource {
    func apiInputLocation(packReference: StickerPackReference) -> Api.InputFileLocation? {
        return Api.InputFileLocation.inputStickerSetThumb(stickerset: packReference.apiInputStickerSet, volumeId: self.volumeId, localId: self.localId)
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
