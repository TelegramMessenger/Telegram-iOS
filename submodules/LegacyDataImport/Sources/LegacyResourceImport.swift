import Foundation
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import LegacyComponents

func resourceFromLegacyImageUrl(_ fileRef: String) -> TelegramMediaResource? {
    if fileRef.isEmpty {
        return nil
    }
    let components = fileRef.components(separatedBy: "_")
    if components.count != 4 {
        return nil
    }
    
    guard let datacenterId = Int32(components[0]) else {
        return nil
    }
    guard let volumeId = Int64(components[1]) else {
        return nil
    }
    guard let localId = Int32(components[2]) else {
        return nil
    }
    guard let secret = Int64(components[3]) else {
        return nil
    }
    
    return CloudFileMediaResource(datacenterId: Int(datacenterId), volumeId: volumeId, localId: localId, secret: secret, size: nil, fileReference: nil)
}

func pathFromLegacyImageUrl(basePath: String, url: String) -> String {
    let cache = TGCache(cachesPath: basePath + "/Caches")!
    return cache.path(forCachedData: url)
}

func pathFromLegacyVideoUrl(basePath: String, url: String) -> (id: Int64, accessHash: Int64, datacenterId: Int32, path: String)? {
    if !url.hasPrefix("video:") {
        return nil
    }
    //[videoInfo addVideoWithQuality:1 url:[[NSString alloc] initWithFormat:@"video:%lld:%lld:%d:%d", videoMedia.videoId, videoMedia.accessHash, concreteResult.document.datacenterId, concreteResult.document.size] size:concreteResult.document.size];
    let components = url.components(separatedBy: ":")
    if components.count != 5 {
        return nil
    }
    guard let videoId = Int64(components[1]) else {
        return nil
    }
    guard let accessHash = Int64(components[2]) else {
        return nil
    }
    guard let datacenterId = Int32(components[3]) else {
        return nil
    }
    let documentsPath = basePath + "/Documents"
    let videoPath = documentsPath + "/video/remote\(String(videoId, radix: 16)).mov"
    return (videoId, accessHash, datacenterId, videoPath)
}

func pathFromLegacyLocalVideoUrl(basePath: String, url: String) -> String? {
    let documentsPath = basePath + "/Documents"
    if !url.hasPrefix("local-video:") {
        return nil
    }
    let videoPath = documentsPath + "/video/" + String(url[url.index(url.startIndex, offsetBy: "local-video:".count)...])
    return videoPath
}

func pathFromLegacyFile(basePath: String, fileId: Int64, isLocal: Bool, fileName: String) -> String {
    let documentsPath = basePath + "/Documents"
    let filePath = documentsPath + "/files/" + (isLocal ? "local" : "") + "\(String(fileId, radix: 16))/\(fileName)"
    return filePath
}

enum EncryptedFileType {
    case image
    case video
    case document(fileName: String)
    case audio
}

func pathAndResourceFromEncryptedFileUrl(basePath: String, url: String, type: EncryptedFileType) -> (String, TelegramMediaResource)? {
    let cache = TGCache(cachesPath: basePath + "/Caches")!
    
    if url.hasPrefix("encryptedThumbnail:") {
        let path = cache.path(forCachedData: url)!
        return (path, LocalFileMediaResource(fileId: arc4random64()))
    }
    
    if !url.hasPrefix("mt-encrypted-file://?") {
        return nil
    }
    guard let dict = TGStringUtils.argumentDictionary(inUrlString: String(url[url.index(url.startIndex, offsetBy: "mt-encrypted-file://?".count)...])) else {
        return nil
    }
    guard let idString = dict["id"] as? String, let id = Int64(idString) else {
        return nil
    }
    guard let datacenterIdString = dict["dc"] as? String, let datacenterId = Int32(datacenterIdString) else {
        return nil
    }
    guard let accessHashString = dict["accessHash"] as? String, let accessHash = Int64(accessHashString) else {
        return nil
    }
    guard let sizeString = dict["size"] as? String, let size = Int32(sizeString) else {
        return nil
    }
    guard let decryptedSizeString = dict["decryptedSize"] as? String, let decryptedSize = Int32(decryptedSizeString) else {
        return nil
    }
    guard let keyFingerprintString = dict["fingerprint"] as? String, let _ = Int32(keyFingerprintString) else {
        return nil
    }
    guard let keyString = dict["key"] as? String else {
        return nil
    }
    let keyData = dataWithHexString(keyString)
    guard keyData.count == 64 else {
        return nil
    }
    
    let resource = SecretFileMediaResource(fileId: id, accessHash: accessHash, containerSize: size, decryptedSize: decryptedSize, datacenterId: Int(datacenterId), key: SecretFileEncryptionKey(aesKey: keyData.subdata(in: 0 ..< 32), aesIv: keyData.subdata(in: 32 ..< 64)))
    
    let filePath: String
    switch type {
        case .video:
            filePath = basePath + "Documents/video/remote\(String(id, radix: 16)).mov"
        case .image:
            filePath = cache.path(forCachedData: url)
        case let .document(fileName):
            filePath = basePath + "Documents/files/\(String(id, radix: 16))/\(TGDocumentMediaAttachment.safeFileName(forFileName: fileName)!)"
        case .audio:
            filePath = basePath + "Documents/audio/\(String(id, radix: 16))"
    }
    
    return (filePath, resource)
}
