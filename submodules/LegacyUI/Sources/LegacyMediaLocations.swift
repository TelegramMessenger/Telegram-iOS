import Foundation
import UIKit
import Postbox
import TelegramCore
import SyncCore

public func legacyImageLocationUri(resource: MediaResource) -> String? {
    if let resource = resource as? CloudPeerPhotoSizeMediaResource {
        return resource.id.uniqueId
    }
    return nil
}

private let legacyImageUriExpr = try? NSRegularExpression(pattern: "telegram-peer-photo-size-([-\\d]+)-([-\\d]+)-([-\\d]+)-([-\\d]+)", options: [])

public func resourceFromLegacyImageUri(_ uri: String) -> MediaResource? {
    guard let legacyImageUriExpr = legacyImageUriExpr else {
        return nil
    }
    let matches = legacyImageUriExpr.matches(in: uri, options: [], range: NSRange(location: 0, length: uri.count))
    if let match = matches.first {
        let nsString = uri as NSString
        let datacenterId = nsString.substring(with: match.range(at: 1))
        let size = nsString.substring(with: match.range(at: 2))
        let volumeId = nsString.substring(with: match.range(at: 3))
        let localId = nsString.substring(with: match.range(at: 4))
        
        guard let nDatacenterId = Int32(datacenterId) else {
            return nil
        }
        guard let nSizeSpec = Int32(size), let sizeSpec = CloudPeerPhotoSizeSpec(rawValue: nSizeSpec) else {
            return nil
        }
        guard let nVolumeId = Int64(volumeId) else {
            return nil
        }
        guard let nLocalId = Int32(localId) else {
            return nil
        }
        
        return CloudPeerPhotoSizeMediaResource(datacenterId: nDatacenterId, sizeSpec: sizeSpec, volumeId: nVolumeId, localId: nLocalId)
    }
    return nil
}
