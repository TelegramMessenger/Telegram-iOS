import Foundation
import UIKit
import TelegramCore
import SwiftSignalKit
import Display
import Pdf
import AVFoundation

public struct ICloudFileResourceId {
    public let urlData: String
    public let thumbnail: Bool
    
    public var uniqueId: String {
        if self.thumbnail {
            return "icloud-thumb-\(enginePersistentHash32(self.urlData))"
        } else {
            return "icloud-\(enginePersistentHash32(self.urlData))"
        }
    }
    
    public var hashValue: Int {
        return self.uniqueId.hashValue
    }
}

public class ICloudFileResource: TelegramMediaResource {
    public let urlData: String
    public let thumbnail: Bool
    
    public var size: Int64? {
        return nil
    }
    
    public init(urlData: String, thumbnail: Bool) {
        self.urlData = urlData
        self.thumbnail = thumbnail
    }
    
    public required init(decoder: EnginePostboxDecoder) {
        self.urlData = decoder.decodeStringForKey("url", orElse: "")
        self.thumbnail = decoder.decodeBoolForKey("thumb", orElse: false)
    }
    
    public func encode(_ encoder: EnginePostboxEncoder) {
        encoder.encodeString(self.urlData, forKey: "url")
        encoder.encodeBool(self.thumbnail, forKey: "thumb")
    }
    
    public var id: EngineRawMediaResourceId {
        return EngineRawMediaResourceId(ICloudFileResourceId(urlData: self.urlData, thumbnail: self.thumbnail).uniqueId)
    }

    public func isEqual(to: EngineRawMediaResource) -> Bool {
        if let to = to as? ICloudFileResource {
            if self.urlData != to.urlData || self.thumbnail != to.thumbnail {
                return false
            }
            return true
        } else {
            return false
        }
    }
}

public struct ICloudFileDescription {
    public struct AudioMetadata {
        public let title: String?
        public let performer: String?
        public let duration: Int
        public let hasAudioArtwork: Bool
    }
    
    public let urlData: String
    public let fileName: String
    public let fileSize: Int
    public let audioMetadata: AudioMetadata?
}

private let audioFileExtensions: Set<String> = ["mp3", "m4a", "aac", "flac"]

private func validatedAudioArtworkData(_ data: Data?) -> Data? {
    guard let data, UIImage(data: data) != nil else {
        return nil
    }
    return data
}

private func audioArtworkData(from metadataItem: AVMetadataItem) -> Data? {
    if let data = validatedAudioArtworkData(metadataItem.value(forKey: "dataValue") as? Data) {
        return data
    }
    if let data = metadataItem.value(forKey: "value") as? Data {
        return validatedAudioArtworkData(data)
    }
    if let data = metadataItem.value(forKey: "value") as? NSData {
        return validatedAudioArtworkData(data as Data)
    }
    return nil
}

private func audioArtworkData(from asset: AVURLAsset) -> Data? {
    func firstArtworkData(in metadataItems: [AVMetadataItem]) -> Data? {
        for item in metadataItems {
            if item.commonKey == AVMetadataKey.commonKeyArtwork, let data = audioArtworkData(from: item) {
                return data
            }
        }
        return nil
    }

    if let data = firstArtworkData(in: asset.commonMetadata) {
        return data
    }

    for format in asset.availableMetadataFormats {
        if let data = firstArtworkData(in: asset.metadata(forFormat: format)) {
            return data
        }
    }

    return nil
}

private func descriptionWithUrl(_ url: URL) -> ICloudFileDescription? {
    if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
        guard url.startAccessingSecurityScopedResource() else {
            return nil
        }
        
        guard let urlData = try? url.bookmarkData(options: URL.BookmarkCreationOptions.suitableForBookmarkFile, includingResourceValuesForKeys: nil, relativeTo: nil) else {
            return nil
        }
        
        guard let values = try? url.resourceValues(forKeys: Set([.fileSizeKey])), let fileSize = values.fileSize else {
            return nil
        }
        
        guard let fileName = (url.lastPathComponent as NSString).removingPercentEncoding else {
            return nil
        }
        
        var audioMetadata: ICloudFileDescription.AudioMetadata?
        let fileExtension = url.pathExtension.lowercased()
        var hasAudioArtwork = false
        let audioAsset: AVURLAsset?
        if audioFileExtensions.contains(fileExtension) {
            let asset = AVURLAsset(url: url)
            audioAsset = asset
            hasAudioArtwork = audioArtworkData(from: asset) != nil
        } else {
            audioAsset = nil
        }
        if ["mp3", "m4a"].contains(fileExtension), let asset = audioAsset {
            let title = AVMetadataItem.metadataItems(from: asset.commonMetadata, withKey: AVMetadataKey.commonKeyTitle, keySpace: AVMetadataKeySpace.common).first?.stringValue
            let performer = AVMetadataItem.metadataItems(from: asset.commonMetadata, withKey: AVMetadataKey.commonKeyArtist, keySpace: AVMetadataKeySpace.common).first?.stringValue
            let duration = CMTimeGetSeconds(asset.duration)
            if duration > 0 {
                audioMetadata = ICloudFileDescription.AudioMetadata(title: title, performer: performer, duration: Int(duration), hasAudioArtwork: hasAudioArtwork)
            }
        } else if fileExtension == "flac", let asset = audioAsset {
            var title: String?
            var performer: String?
            let vorbisComment = AVMetadataFormat(rawValue: "org.xiph.vorbis-comment")
            if asset.availableMetadataFormats.contains(vorbisComment) {
                let items = asset.metadata(forFormat: vorbisComment)
                for item in items {
                    if item.commonKey == AVMetadataKey.commonKeyTitle {
                        title = item.stringValue
                    }
                    if item.commonKey == AVMetadataKey.commonKeyArtist {
                        performer = item.stringValue
                    }
                }
            }
            let duration = CMTimeGetSeconds(asset.duration)
            if duration > 0 {
                audioMetadata = ICloudFileDescription.AudioMetadata(title: title, performer: performer, duration: Int(duration), hasAudioArtwork: hasAudioArtwork)
            }
        }
        
        let result = ICloudFileDescription(
            urlData: urlData.base64EncodedString(),
            fileName: fileName,
            fileSize: fileSize,
            audioMetadata: audioMetadata
        )
        
        url.stopAccessingSecurityScopedResource()
        
        return result
    } else {
        return nil
    }
}

public func iCloudFileDescription(_ url: URL) -> Signal<ICloudFileDescription?, NoError> {
    return Signal { subscriber in
        var isRemote = false
        var isCurrent = true
        
        if let values = try? url.resourceValues(forKeys: Set([URLResourceKey.ubiquitousItemDownloadingStatusKey])), let status = values.ubiquitousItemDownloadingStatus {
            isRemote = true
            if status != URLUbiquitousItemDownloadingStatus.current {
                isCurrent = false
            }
        }
        
        if !isRemote || isCurrent {
            subscriber.putNext(descriptionWithUrl(url))
            subscriber.putCompletion()
            return EmptyDisposable
        } else {
            final class WrappedQuery {
                let query = NSMetadataQuery()
            }
            
            let query = WrappedQuery()
            query.query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope, NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope]
            query.query.predicate = NSPredicate(format: "%K.lastPathComponent == %@", NSMetadataItemFSNameKey, url.lastPathComponent)
            query.query.valueListAttributes = [NSMetadataItemFSSizeKey]
            
            let observer = NotificationCenter.default.addObserver(forName: NSNotification.Name.NSMetadataQueryDidFinishGathering, object: query, queue: OperationQueue.main, using: { notification in
                query.query.disableUpdates()
                
                guard let metadataItem = query.query.results.first as? NSMetadataItem else {
                    query.query.enableUpdates()
                    return
                }
                
                query.query.stop()
                
                guard let fileSize = metadataItem.value(forAttribute: NSMetadataItemFSSizeKey) as? NSNumber, fileSize != 0 else {
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                    return
                }
                
                subscriber.putNext(descriptionWithUrl(url))
                subscriber.putCompletion()
            })
            
            query.query.start()
            
            return ActionDisposable {
                Queue.mainQueue().async {
                    query.query.stop()
                    NotificationCenter.default.removeObserver(observer)
                }
            }
        }
    }
}

private final class ICloudFileResourceCopyItem: EngineRawMediaResourceDataFetchCopyLocalItem {
    private let url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    deinit {
        self.url.stopAccessingSecurityScopedResource()
    }
    
    func copyTo(url: URL) -> Bool {
        var success = true
        do {
            try FileManager.default.copyItem(at: self.url, to: url)
        } catch {
            success = false
        }
        return success
    }
}

public func fetchICloudFileResource(resource: ICloudFileResource) -> Signal<EngineMediaResourceDataFetchResult, EngineMediaResourceDataFetchError> {
    return Signal { subscriber in
        subscriber.putNext(.reset)
        
        guard let urlData = Data(base64Encoded: resource.urlData) else {
            subscriber.putCompletion()
            return EmptyDisposable
        }
        
        var bookmarkDataIsStale = false
        guard let url = try? URL(resolvingBookmarkData: urlData, bookmarkDataIsStale: &bookmarkDataIsStale) else {
            subscriber.putCompletion()
            return EmptyDisposable
        }
        
        var isRemote = false
        var isCurrent = true
        
        if let values = try? url.resourceValues(forKeys: Set([URLResourceKey.ubiquitousItemDownloadingStatusKey])), let status = values.ubiquitousItemDownloadingStatus {
            isRemote = true
            if status != URLUbiquitousItemDownloadingStatus.current {
                isCurrent = false
            }
        }
        
        guard url.startAccessingSecurityScopedResource() else {
            subscriber.putCompletion()
            return EmptyDisposable
        }
        
        let complete = {
            if resource.thumbnail {
                let tempFile = EngineTempBox.shared.tempFile(fileName: "thumb.jpg")
                var data = Data()
                let fileExtension = url.pathExtension.lowercased()
                let isAudioFile = audioFileExtensions.contains(fileExtension)

                if isAudioFile, let artworkData = audioArtworkData(from: AVURLAsset(url: url)), let originalImage = UIImage(data: artworkData), let image = generateScaledImage(image: originalImage, size: originalImage.size.fitted(CGSize(width: 256, height: 256.0))), let jpegData = image.jpegData(compressionQuality: 0.5) {
                    data = jpegData
                } else if !isAudioFile {
                    if let imageData = try? Data(contentsOf: url, options: .mappedIfSafe), let originalImage = UIImage(data: imageData), let image = generateScaledImage(image: originalImage, size: originalImage.size.fitted(CGSize(width: 256, height: 256.0))), let jpegData = image.jpegData(compressionQuality: 0.5) {
                        data = jpegData
                    } else if let image = generatePdfPreviewImage(url: url, size: CGSize(width: 256, height: 256.0)), let jpegData = image.jpegData(compressionQuality: 0.5) {
                        data = jpegData
                    }
                }
                if let _ = try? data.write(to: URL(fileURLWithPath: tempFile.path)) {
                    subscriber.putNext(.moveTempFile(file: tempFile))
                }
            } else {
                subscriber.putNext(.copyLocalItem(ICloudFileResourceCopyItem(url: url)))
            }
            subscriber.putCompletion()
        }
        
        if !isRemote || isCurrent {
            //url.stopAccessingSecurityScopedResource()
            complete()
            return EmptyDisposable
        }
        
        let fileCoordinator = NSFileCoordinator(filePresenter: nil)
        let fileAccessIntent = NSFileAccessIntent.readingIntent(with: url, options: [.withoutChanges])
        fileCoordinator.coordinate(with: [fileAccessIntent], queue: OperationQueue.main, byAccessor: { error in
            if error == nil {
                //url.stopAccessingSecurityScopedResource()
                complete()
            } else {
                subscriber.putCompletion()
            }
        })
        
        return ActionDisposable {
            fileCoordinator.cancel()
        }
    }
}
