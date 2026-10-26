import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import AccountContext
import MediaEditor
import MediaEditorScreen
import ItemListAvatarAndNameInfoItem
import Photos
import AVFoundation

struct CreatePendingPeerAvatar {
    let previewRepresentation: TelegramMediaImageRepresentation
    let isLoadingPreview: Bool
    let uploadedPhoto: Signal<UploadedPeerPhotoData, NoError>
    let uploadedVideo: Signal<UploadedPeerPhotoData?, NoError>?
    let videoStartTimestamp: Double?
    let markup: UploadPeerPhotoMarkup?
    
    var updatingAvatar: ItemListAvatarAndNameInfoItemUpdatingAvatar {
        return .image(self.previewRepresentation, self.isLoadingPreview)
    }
}

enum CreatePeerAvatarSetup {
    private static func makePhotoRepresentation(context: AccountContext, image: UIImage) -> (LocalFileMediaResource, TelegramMediaImageRepresentation)? {
        guard let data = image.jpegData(compressionQuality: 0.6) else {
            return nil
        }
        
        let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
        context.engine.resources.storeResourceData(id: EngineMediaResource.Id(resource.id), data: data)
        let representation = TelegramMediaImageRepresentation(
            dimensions: PixelDimensions(width: 640, height: 640),
            resource: resource,
            progressiveSizes: [],
            immediateThumbnailData: nil,
            hasVideo: false,
            isPersonal: false
        )
        return (resource, representation)
    }
    
    static func photo(context: AccountContext, image: UIImage) -> CreatePendingPeerAvatar? {
        guard let (resource, representation) = self.makePhotoRepresentation(context: context, image: image) else {
            return nil
        }
        
        return CreatePendingPeerAvatar(
            previewRepresentation: representation,
            isLoadingPreview: false,
            uploadedPhoto: context.engine.peers.uploadedPeerPhoto(resource: EngineMediaResource(resource)),
            uploadedVideo: nil,
            videoStartTimestamp: nil,
            markup: nil
        )
    }
    
    static func video(
        context: AccountContext,
        image: UIImage,
        video: MediaEditorScreenImpl.MediaResult.VideoResult?,
        values: MediaEditorValues?,
        markup: UploadPeerPhotoMarkup?,
        didCompleteLoadingPreview: @escaping (CreatePendingPeerAvatar) -> Void = { _ in }
    ) -> CreatePendingPeerAvatar? {
        var shouldUploadVideo = true
        if markup != nil {
            if let data = context.currentAppConfiguration.with({ $0 }).data, let uploadVideoValue = data["upload_markup_video"] as? Bool, uploadVideoValue {
                shouldUploadVideo = true
            } else {
                shouldUploadVideo = false
            }
        }
        
        guard let (photoResource, representation) = self.makePhotoRepresentation(context: context, image: image) else {
            return nil
        }
        
        let uploadedPhoto = context.engine.peers.uploadedPeerPhoto(resource: EngineMediaResource(photoResource))
        
        var videoStartTimestamp: Double? = nil
        if let values, let coverImageTimestamp = values.coverImageTimestamp, coverImageTimestamp > 0.0 {
            videoStartTimestamp = coverImageTimestamp - (values.videoTrimRange?.lowerBound ?? 0.0)
        }
        
        let hasVideoUpload = shouldUploadVideo && video != nil && values != nil
        guard hasVideoUpload, let video, let values else {
            return CreatePendingPeerAvatar(
                previewRepresentation: representation,
                isLoadingPreview: false,
                uploadedPhoto: uploadedPhoto,
                uploadedVideo: nil,
                videoStartTimestamp: videoStartTimestamp,
                markup: markup
            )
        }
        
        let account = context.account
        let videoResource: Signal<TelegramMediaResource?, UploadPeerPhotoError>
        
        var exportSubject: Signal<(MediaEditorVideoExport.Subject, Double), NoError>?
        switch video {
        case let .imageFile(path):
            if let image = UIImage(contentsOfFile: path) {
                exportSubject = .single((.image(image: image), 3.0))
            }
        case let .videoFile(path):
            let asset = AVURLAsset(url: NSURL(fileURLWithPath: path) as URL)
            exportSubject = .single((.video(asset: asset, isStory: false), asset.duration.seconds))
        case let .asset(localIdentifier):
            exportSubject = Signal { subscriber in
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
                if fetchResult.count != 0 {
                    let asset = fetchResult.object(at: 0)
                    if asset.mediaType == .video {
                        PHImageManager.default().requestAVAsset(forVideo: asset, options: nil) { avAsset, _, _ in
                            if let avAsset {
                                subscriber.putNext((.video(asset: avAsset, isStory: true), avAsset.duration.seconds))
                                subscriber.putCompletion()
                            }
                        }
                    } else {
                        let options = PHImageRequestOptions()
                        options.deliveryMode = .highQualityFormat
                        PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: options) { image, _ in
                            if let image {
                                subscriber.putNext((.image(image: image), 3.0))
                                subscriber.putCompletion()
                            }
                        }
                    }
                }
                return EmptyDisposable
            }
        }
        
        guard let exportSubject else {
            return CreatePendingPeerAvatar(
                previewRepresentation: representation,
                isLoadingPreview: false,
                uploadedPhoto: uploadedPhoto,
                uploadedVideo: nil,
                videoStartTimestamp: videoStartTimestamp,
                markup: markup
            )
        }
        
        videoResource = exportSubject
        |> castError(UploadPeerPhotoError.self)
        |> mapToSignal { exportSubject, duration in
            return Signal<TelegramMediaResource?, UploadPeerPhotoError> { subscriber in
                let configuration = recommendedVideoExportConfiguration(values: values, duration: duration, forceFullHd: true, frameRate: 60.0, isAvatar: true)
                let tempFile = EngineTempBox.shared.tempFile(fileName: "video.mp4")
                let videoExport = MediaEditorVideoExport(postbox: context.account.postbox, subject: exportSubject, configuration: configuration, outputPath: tempFile.path, textScale: 2.0)
                let _ = (videoExport.status
                |> deliverOnMainQueue).startStandalone(next: { status in
                    switch status {
                    case .completed:
                        if let data = try? Data(contentsOf: URL(fileURLWithPath: tempFile.path), options: .mappedIfSafe) {
                            let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                            TelegramEngine(account: account).resources.storeResourceData(id: EngineMediaResource.Id(resource.id), data: data, synchronous: true)
                            subscriber.putNext(resource)
                            subscriber.putCompletion()
                        }
                        EngineTempBox.shared.dispose(tempFile)
                    case .progress:
                        break
                    default:
                        break
                    }
                })
                
                return EmptyDisposable
            }
        }
        
        var completedAvatar: CreatePendingPeerAvatar?
        let uploadedVideo = (videoResource
        |> `catch` { _ -> Signal<TelegramMediaResource?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { resource -> Signal<UploadedPeerPhotoData?, NoError> in
            if let resource {
                return context.engine.peers.uploadedPeerVideo(resource: EngineMediaResource(resource))
                |> map(Optional.init)
            } else {
                return .single(nil)
            }
        }
        |> afterNext { next in
            if let next, next.isCompleted, let completedAvatar {
                didCompleteLoadingPreview(completedAvatar)
            }
        })
        
        let pendingAvatar = CreatePendingPeerAvatar(
            previewRepresentation: representation,
            isLoadingPreview: true,
            uploadedPhoto: uploadedPhoto,
            uploadedVideo: uploadedVideo,
            videoStartTimestamp: videoStartTimestamp,
            markup: markup
        )
        completedAvatar = CreatePendingPeerAvatar(
            previewRepresentation: representation,
            isLoadingPreview: false,
            uploadedPhoto: uploadedPhoto,
            uploadedVideo: uploadedVideo,
            videoStartTimestamp: videoStartTimestamp,
            markup: markup
        )
        
        return pendingAvatar
    }
}
