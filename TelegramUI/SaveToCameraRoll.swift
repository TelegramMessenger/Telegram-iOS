import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import Photos

func saveToCameraRoll(postbox: Postbox, media: Media) -> Signal<Void, NoError> {
    var resource: MediaResource?
    var isImage = true
    if let image = media as? TelegramMediaImage {
        if let representation = largestImageRepresentation(image.representations) {
            resource = representation.resource
        }
    } else if let file = media as? TelegramMediaFile {
        resource = file.resource
        if file.isVideo {
            isImage = false
        }
    } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
        if let image = content.image {
            if let representation = largestImageRepresentation(image.representations) {
                resource = representation.resource
            }
        } else if let file = content.file {
            resource = file.resource
            if file.isVideo {
                isImage = false
            }
        }
    }
    
    if let resource = resource {
        let fetchedData: Signal<MediaResourceData, NoError> = Signal { subscriber in
            let fetched = postbox.mediaBox.fetchedResource(resource, tag: nil).start()
            let data = postbox.mediaBox.resourceData(resource, pathExtension: nil, option: .complete(waitUntilFetchStatus: true)).start(next: { next in
                subscriber.putNext(next)
            }, completed: {
                subscriber.putCompletion()
            })
            return ActionDisposable {
                fetched.dispose()
                data.dispose()
            }
        }
        return fetchedData
            |> mapToSignal { data -> Signal<Void, NoError> in
                if data.complete {
                    return Signal<Void, NoError> { subscriber in
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
                            subscriber.putNext(Void())
                            subscriber.putCompletion()
                        })
                        
                        return ActionDisposable {
                        }
                    }
                } else {
                    return .complete()
                }
            } |> take(1) |> mapToSignal { _ -> Signal<Void, NoError> in return .complete() }
    } else {
        return .complete()
    }
}
