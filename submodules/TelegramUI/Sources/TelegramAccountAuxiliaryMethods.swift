import Foundation
import TelegramCore
import Postbox
import MediaResources
import PassportUI
import OpenInExternalAppUI
import MusicAlbumArtResources
import LocalMediaResources
import LocationResources
import ChatInterfaceState
import WallpaperResources
import AppBundle
import SwiftSignalKit

public let telegramAccountAuxiliaryMethods = AccountAuxiliaryMethods(fetchResource: { account, resource, ranges, _ in
    if let resource = resource as? VideoLibraryMediaResource {
        return fetchVideoLibraryMediaResource(account: account, resource: resource)
    } else if let resource = resource as? LocalFileVideoMediaResource {
        return fetchLocalFileVideoMediaResource(account: account, resource: resource)
    } else if let resource = resource as? LocalFileGifMediaResource {
        return fetchLocalFileGifMediaResource(resource: resource)
    } else if let photoLibraryResource = resource as? PhotoLibraryMediaResource {
        return fetchPhotoLibraryResource(localIdentifier: photoLibraryResource.localIdentifier)
    } else if let resource = resource as? ICloudFileResource {
        return fetchICloudFileResource(resource: resource)
    } else if let resource = resource as? SecureIdLocalImageResource {
        return fetchSecureIdLocalImageResource(postbox: account.postbox, resource: resource)
    } else if let resource = resource as? EmojiSpriteResource {
        return fetchEmojiSpriteResource(account: account, resource: resource)
    } else if let resource = resource as? BundleResource {
        return Signal { subscriber in
            subscriber.putNext(.reset)
            if let data = try? Data(contentsOf: URL(fileURLWithPath: resource.path), options: .mappedRead) {
                subscriber.putNext(.dataPart(resourceOffset: 0, data: data, range: 0 ..< Int64(data.count), complete: true))
            }
            return EmptyDisposable
        }
    } else if let wallpaperResource = resource as? WallpaperDataResource {
        let builtinWallpapers: [String] = [
            "fqv01SQemVIBAAAApND8LDRUhRU"
        ]
        if builtinWallpapers.contains(wallpaperResource.slug) {
            if let url = getAppBundle().url(forResource: wallpaperResource.slug, withExtension: "tgv") {
                return Signal { subscriber in
                    subscriber.putNext(.reset)
                    if let data = try? Data(contentsOf: url, options: .mappedRead) {
                        subscriber.putNext(.dataPart(resourceOffset: 0, data: data, range: 0 ..< Int64(data.count), complete: true))
                    }

                    return EmptyDisposable
                }
            } else {
                return nil
            }
        }
        return nil
    } else if let cloudDocumentMediaResource = resource as? CloudDocumentMediaResource {
        if cloudDocumentMediaResource.fileId == 5789658100176783156 {
            if let url = getAppBundle().url(forResource: "fqv01SQemVIBAAAApND8LDRUhRU", withExtension: "tgv") {
                return Signal { subscriber in
                    subscriber.putNext(.reset)
                    if let data = try? Data(contentsOf: url, options: .mappedRead) {
                        subscriber.putNext(.dataPart(resourceOffset: 0, data: data, range: 0 ..< Int64(data.count), complete: true))
                    }

                    return EmptyDisposable
                }
            } else {
                return nil
            }
        }
    } else if let cloudDocumentSizeMediaResource = resource as? CloudDocumentSizeMediaResource {
        if cloudDocumentSizeMediaResource.documentId == 5789658100176783156 && cloudDocumentSizeMediaResource.sizeSpec == "m" {
            if let url = getAppBundle().url(forResource: "5789658100176783156-m", withExtension: "resource") {
                return Signal { subscriber in
                    subscriber.putNext(.reset)
                    if let data = try? Data(contentsOf: url, options: .mappedRead) {
                        subscriber.putNext(.dataPart(resourceOffset: 0, data: data, range: 0 ..< Int64(data.count), complete: true))
                    }

                    return EmptyDisposable
                }
            } else {
                return nil
            }
        }
        return nil
    }
    return nil
}, fetchResourceMediaReferenceHash: { resource in
    if let resource = resource as? VideoLibraryMediaResource {
        return fetchVideoLibraryMediaResourceHash(resource: resource)
    }
    return .single(nil)
}, prepareSecretThumbnailData: { data in
    return prepareSecretThumbnailData(data).flatMap { size, data in
        return (PixelDimensions(size), data)
    }
})
