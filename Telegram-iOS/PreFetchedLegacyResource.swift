import Foundation
import Postbox
import TelegramCore

import LegacyComponents

func preFetchedLegacyResourcePath(basePath: String, resource: MediaResource, cache: TGCache) -> String? {
    
    if let resource = resource as? CloudDocumentMediaResource {
        let videoPath = "\(basePath)/Documents/video/remote\(String(resource.fileId, radix: 16)).mov"
        if FileManager.default.fileExists(atPath: videoPath) {
            return videoPath
        }
        let fileName = resource.fileName?.replacingOccurrences(of: "/", with: "_") ?? "file"
        return pathFromLegacyFile(basePath: basePath, fileId: resource.fileId, isLocal: false, fileName: fileName)
    } else if let resource = resource as? CloudFileMediaResource {
        return cache.path(forCachedData: "\(resource.datacenterId)_\(resource.volumeId)_\(resource.localId)_\(resource.secret)")
    }
    return nil
}
