import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import Photos
import Display
import MobileCoreServices
import DeviceAccess
import AccountContext
import LegacyComponents

public enum FetchMediaDataState {
    case progress(Float)
    case data(MediaResourceData)
}

public func fetchMediaData(context: AccountContext, postbox: Postbox, userLocation: MediaResourceUserLocation, customUserContentType: MediaResourceUserContentType? = nil, mediaReference: AnyMediaReference, forceVideo: Bool = false) -> Signal<(FetchMediaDataState, Bool), NoError> {
    var resource: MediaResource?
    var isImage = true
    var fileExtension: String?
    var userContentType: MediaResourceUserContentType = .other
    if let image = mediaReference.media as? TelegramMediaImage {
        userContentType = .image
        if let video = image.videoRepresentations.last, forceVideo {
            resource = video.resource
            isImage = false
        } else if let representation = largestImageRepresentation(image.representations) {
            resource = representation.resource
        }
    } else if let file = mediaReference.media as? TelegramMediaFile {
        userContentType = MediaResourceUserContentType(file: file)
        resource = file.resource
        if file.isVideo || file.mimeType.hasPrefix("video/") {
            isImage = false
        }
        let maybeExtension = ((file.fileName ?? "") as NSString).pathExtension
        if !maybeExtension.isEmpty {
            fileExtension = maybeExtension
        }
    } else if let webpage = mediaReference.media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
        if let file = content.file {
            resource = file.resource
            if file.isVideo {
                isImage = false
            }
        } else if let image = content.image {
            if let representation = largestImageRepresentation(image.representations) {
                resource = representation.resource
            }
        }
    }
    if let customUserContentType {
        userContentType = customUserContentType
    }
    
    if let resource = resource {
        let fetchedData: Signal<FetchMediaDataState, NoError> = Signal { subscriber in
            let fetched = fetchedMediaResource(mediaBox: postbox.mediaBox, userLocation: userLocation, userContentType: userContentType, reference: mediaReference.resourceReference(resource)).start()
            let status = postbox.mediaBox.resourceStatus(resource).start(next: { status in
                switch status {
                    case .Local:
                        subscriber.putNext(.progress(1.0))
                    case .Remote:
                        subscriber.putNext(.progress(0.0))
                    case let .Fetching(_, progress):
                        subscriber.putNext(.progress(progress))
                    case let .Paused(progress):
                        subscriber.putNext(.progress(progress))
                }
            })
            let data = postbox.mediaBox.resourceData(resource, pathExtension: fileExtension, option: .complete(waitUntilFetchStatus: true)).start(next: { next in
                subscriber.putNext(.data(next))
            }, completed: {
                subscriber.putCompletion()
            })
            return ActionDisposable {
                fetched.dispose()
                status.dispose()
                data.dispose()
            }
        }
        return fetchedData
        |> map { data in
            return (data, isImage)
        }
    } else {
        return .complete()
    }
}

public func saveToCameraRoll(context: AccountContext, postbox: Postbox, userLocation: MediaResourceUserLocation, customUserContentType: MediaResourceUserContentType? = nil, mediaReference: AnyMediaReference, video: AnyMediaReference? = nil) -> Signal<Float, NoError> {
    let mediaData: Signal<(FetchMediaDataState, Bool), NoError> = fetchMediaData(context: context, postbox: postbox, userLocation: userLocation, customUserContentType: customUserContentType, mediaReference: mediaReference)
    let videoData: Signal<FetchMediaDataState?, NoError>
    if let video {
        videoData = fetchMediaData(context: context, postbox: postbox, userLocation: userLocation, customUserContentType: customUserContentType, mediaReference: video)
        |> map { state, _ in
            return state
        }
        |> map(Optional.init)
    } else {
        videoData = .single(nil)
    }
    
    return combineLatest(
        queue: Queue.mainQueue(),
        mediaData,
        videoData
    )
    |> mapToSignal { stateAndIsImage, videoStateAndIsImage -> Signal<Float, NoError> in
        let isImage = stateAndIsImage.1
        var mainData: MediaResourceData?
        var videoData: MediaResourceData?
        var waitForVideo = false
        if let videoState = videoStateAndIsImage {
            switch videoState {
            case let .progress(value):
                return .single(value * 0.95)
            case let .data(data):
                videoData = data
            }
            switch stateAndIsImage.0 {
            case let .progress(value):
                return .single(0.95 + 0.05 * value)
            case let .data(data):
                mainData = data
            }
            waitForVideo = true
        } else {
            switch stateAndIsImage.0 {
            case let .progress(value):
                return .single(value)
            case let .data(data):
                mainData = data
            }
        }
        if let mainData, mainData.complete, videoData != nil || !waitForVideo {
            return Signal<Float, NoError> { subscriber in
                DeviceAccess.authorizeAccess(to: .mediaLibrary(.save), presentationData: context.sharedContext.currentPresentationData.with { $0 }, present: { c, a in
                    context.sharedContext.presentGlobalController(c, a)
                }, openSettings: context.sharedContext.applicationBindings.openSettings, { authorized in
                    if !authorized {
                        subscriber.putCompletion()
                        return
                    }
                    
                    let tempVideoPath = NSTemporaryDirectory() + "\(Int64.random(in: Int64.min ... Int64.max)).mp4"
                    if isImage, let videoData, let imageData = try? Data(contentsOf: URL(fileURLWithPath: mainData.path)) {
                        let id = UUID().uuidString

                        let jpegWithID = addAssetIdentifierToJPEG(imageData, assetIdentifier: id)!
                        let outputVideoURL = URL(fileURLWithPath: NSTemporaryDirectory() + "\(id).mov")
                        
                        try? FileManager.default.copyItem(atPath: videoData.path, toPath: tempVideoPath)
                        
                        addAssetIdentifierToVideo(inputURL: URL(fileURLWithPath: tempVideoPath), outputURL: outputVideoURL, assetIdentifier: id) { success in
                            guard success else { return }

                            PHPhotoLibrary.shared().performChanges({
                                let request = PHAssetCreationRequest.forAsset()

                                request.addResource(with: .photo, data: jpegWithID, options: nil)
                                request.addResource(with: .pairedVideo, fileURL: outputVideoURL, options: nil)
                            }, completionHandler: { _, error in
                                let _ = try? FileManager.default.removeItem(atPath: tempVideoPath)
                                subscriber.putNext(1.0)
                                subscriber.putCompletion()
                            })
                        }
                    } else {
                        PHPhotoLibrary.shared().performChanges({
                            if isImage {
                                if let imageData = try? Data(contentsOf: URL(fileURLWithPath: mainData.path)) {
                                    PHAssetCreationRequest.forAsset().addResource(with: .photo, data: imageData, options: nil)
                                }
                            } else {
                                if let _ = try? FileManager.default.copyItem(atPath: mainData.path, toPath: tempVideoPath) {
                                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: URL(fileURLWithPath: tempVideoPath))
                                }
                            }
                        }, completionHandler: { _, error in
                            if let error {
                                print("\(error)")
                            }
                            let _ = try? FileManager.default.removeItem(atPath: tempVideoPath)
                            subscriber.putNext(1.0)
                            subscriber.putCompletion()
                        })
                    }
                })
                
                return ActionDisposable {
                }
            }
        } else {
            return .complete()
        }
    }
}

public func copyToPasteboard(context: AccountContext, postbox: Postbox, userLocation: MediaResourceUserLocation, mediaReference: AnyMediaReference) -> Signal<Void, NoError> {
    return fetchMediaData(context: context, postbox: postbox, userLocation: userLocation, mediaReference: mediaReference)
    |> mapToSignal { state, isImage -> Signal<Void, NoError> in
        if case let .data(data) = state, data.complete {
            return Signal<Void, NoError> { subscriber in
                let pasteboard = UIPasteboard.general
                
                if mediaReference.media is TelegramMediaImage {
                    if let fileData = try? Data(contentsOf: URL(fileURLWithPath: data.path), options: .mappedIfSafe) {
                        pasteboard.setData(fileData, forPasteboardType: kUTTypeJPEG as String)
                    }
                }
                subscriber.putNext(Void())
                subscriber.putCompletion()
                
                return EmptyDisposable
            }
        } else {
            return .complete()
        }
    }
    |> mapToSignal { _ -> Signal<Void, NoError> in return .complete() }
}

private func addAssetIdentifierToJPEG(_ imageData: Data, assetIdentifier: String) -> Data? {
    guard let source = CGImageSourceCreateWithData(imageData as CFData, nil), let uti = CGImageSourceGetType(source), let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        return nil
    }

    let mutableData = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(mutableData, uti, 1, nil) else {
        return nil
    }

    var metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]

    var maker = metadata[kCGImagePropertyMakerAppleDictionary as String] as? [String: Any] ?? [:]
    maker["17"] = assetIdentifier
    metadata[kCGImagePropertyMakerAppleDictionary as String] = maker

    CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)
    CGImageDestinationFinalize(destination)

    return mutableData as Data
}

private func addAssetIdentifierToVideo(inputURL: URL, outputURL: URL, assetIdentifier: String, completion: @escaping (Bool) -> Void) {
    let asset = AVAsset(url: inputURL)

    guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
        completion(false)
        return
    }

    let identifierItem = AVMutableMetadataItem()
    identifierItem.keySpace = .quickTimeMetadata
    identifierItem.key = AVMetadataKey.quickTimeMetadataKeyContentIdentifier as NSString
    identifierItem.value = assetIdentifier as NSString

    let stillImageTimeItem = AVMutableMetadataItem()
    let keyStillImageTime = "com.apple.quicktime.still-image-time"
    let keySpaceQuickTimeMetadata = "mdta"
    stillImageTimeItem.key = keyStillImageTime as (NSCopying & NSObjectProtocol)?
    stillImageTimeItem.keySpace = AVMetadataKeySpace(rawValue: keySpaceQuickTimeMetadata)
    stillImageTimeItem.value = 0 as (NSCopying & NSObjectProtocol)?
    stillImageTimeItem.dataType = "com.apple.metadata.datatype.int8"

    exportSession.outputURL = outputURL
    exportSession.outputFileType = .mov
    exportSession.metadata = [identifierItem, stillImageTimeItem]
    exportSession.shouldOptimizeForNetworkUse = true

    exportSession.exportAsynchronously {
        completion(exportSession.status == .completed)
    }
}
