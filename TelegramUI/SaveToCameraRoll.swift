import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import Photos
import Display

private enum SaveToCameraRollState {
    case progress(Float)
    case data(MediaResourceData)
}

func saveToCameraRoll(applicationContext: TelegramApplicationContext, postbox: Postbox, mediaReference: AnyMediaReference) -> Signal<Float, NoError> {
    var resource: MediaResource?
    var isImage = true
    var fileExtension: String?
    if let image = mediaReference.media as? TelegramMediaImage {
        if let representation = largestImageRepresentation(image.representations) {
            resource = representation.resource
        }
    } else if let file = mediaReference.media as? TelegramMediaFile {
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
    
    if let resource = resource {
        let fetchedData: Signal<SaveToCameraRollState, NoError> = Signal { subscriber in
            let fetched = fetchedMediaResource(postbox: postbox, reference: mediaReference.resourceReference(resource)).start()
            let status = postbox.mediaBox.resourceStatus(resource).start(next: { status in
                switch status {
                    case .Local:
                        subscriber.putNext(.progress(1.0))
                    case .Remote:
                        subscriber.putNext(.progress(0.0))
                    case let .Fetching(_, progress):
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
        |> mapToSignal { state -> Signal<Float, NoError> in
            switch state {
                case let .progress(value):
                    return .single(value)
                case let .data(data):
                    if data.complete {
                        return Signal<Float, NoError> { subscriber in
                            DeviceAccess.authorizeAccess(to: .mediaLibrary(.save), presentationData: applicationContext.currentPresentationData.with { $0 }, present: { c, a in
                                applicationContext.presentGlobalController(c, a)
                            }, openSettings: applicationContext.applicationBindings.openSettings, { authorized in
                                if !authorized {
                                    subscriber.putCompletion()
                                    return
                                }
                                
                                let tempVideoPath = NSTemporaryDirectory() + "\(arc4random64()).mp4"
                                PHPhotoLibrary.shared().performChanges({
                                    if isImage {
                                        if let fileData = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                                            if #available(iOSApplicationExtension 9.0, *) {
                                                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: fileData, options: nil)
                                            } else {
                                                if let image = UIImage(data: fileData) {
                                                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                                                }
                                            }
                                        }
                                    } else {
                                        if let _ = try? FileManager.default.copyItem(atPath: data.path, toPath: tempVideoPath) {
                                            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: URL(fileURLWithPath: tempVideoPath))
                                        }
                                    }
                                }, completionHandler: { _, error in
                                    if let error = error {
                                        print("\(error)")
                                    }
                                    let _ = try? FileManager.default.removeItem(atPath: tempVideoPath)
                                    subscriber.putNext(1.0)
                                    subscriber.putCompletion()
                                })
                            })
                            
                            return ActionDisposable {
                            }
                        }
                    } else {
                        return .complete()
                    }
            }
        }
    } else {
        return .complete()
    }
}
