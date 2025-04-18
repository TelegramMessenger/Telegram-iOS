import Foundation
import UIKit
import TelegramCore
import Postbox
import SwiftSignalKit
import Display
import PhotoResources
import ImageCompression

public func transformOutgoingMessageMedia(postbox: Postbox, network: Network, media: AnyMediaReference, opportunistic: Bool) -> Signal<AnyMediaReference?, NoError> {
    if let paidContent = media.media as? TelegramMediaPaidContent {
        var signals: [Signal<AnyMediaReference?, NoError>] = []
        for case let .full(fullMedia) in paidContent.extendedMedia {
            signals.append(transformOutgoingMessageMedia(postbox: postbox, network: network, media: media.withUpdatedMedia(fullMedia), opportunistic: opportunistic))
        }
        return combineLatest(signals)
        |> mapToSignal { results -> Signal<AnyMediaReference?, NoError> in
            let mediaResults = results.compactMap { $0?.media }
            if mediaResults.count == signals.count {
                return .single(media.withUpdatedMedia(TelegramMediaPaidContent(amount: paidContent.amount, extendedMedia: mediaResults.map { .full(media: $0) })))
            } else if opportunistic {
                return .single(nil)
            } else {
                return .complete()
            }
        }
    }
    
    switch media.media {
        case let file as TelegramMediaFile:
            let signal = Signal<MediaResourceData, NoError> { subscriber in
                let fetch = fetchedMediaResource(mediaBox: postbox.mediaBox, userLocation: .other, userContentType: MediaResourceUserContentType(file: file), reference: media.resourceReference(file.resource)).start()
                let data = postbox.mediaBox.resourceData(file.resource, option: .complete(waitUntilFetchStatus: true)).start(next: { next in
                    subscriber.putNext(next)
                    if next.complete {
                        subscriber.putCompletion()
                    }
                })
                
                return ActionDisposable {
                    fetch.dispose()
                    data.dispose()
                }
            }
            
            let result: Signal<MediaResourceData, NoError>
            if opportunistic {
                result = signal |> take(1)
            } else {
                result = signal
            }
            
            return result
            |> mapToSignal { data -> Signal<AnyMediaReference?, NoError> in
                if data.complete {
                    if file.mimeType.hasPrefix("image/") && !file.mimeType.hasSuffix("/webp") {
                        return Signal { subscriber in
                            if let fullSizeData = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                                let options = NSMutableDictionary()
                                options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                                if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, nil), let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                                    let imageOrientation = imageOrientationFromSource(imageSource)
                                    
                                    let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: imageOrientation)
                            
                                    if let scaledImage = generateImage(image.size.fitted(CGSize(width: 320.0, height: 320.0)), contextGenerator: { size, context in
                                        context.setBlendMode(.copy)
                                        drawImage(context: context, image: image.cgImage!, orientation: image.imageOrientation, in: CGRect(origin: CGPoint(), size: size))
                                    }, scale: 1.0), let thumbnailData = scaledImage.jpegData(compressionQuality: 0.6) {
                                        let imageDimensions = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
                                        
                                        let thumbnailResource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                                        postbox.mediaBox.storeResourceData(thumbnailResource.id, data: thumbnailData)
                                        
                                        let scaledImageSize = CGSize(width: scaledImage.size.width * scaledImage.scale, height: scaledImage.size.height * scaledImage.scale)
                                        
                                        var attributes = file.attributes
                                        loop: for i in 0 ..< attributes.count {
                                            switch attributes[i] {
                                                case .ImageSize:
                                                    attributes.remove(at: i)
                                                    break loop
                                                default:
                                                    break
                                            }
                                        }
                                        attributes.append(.ImageSize(size: PixelDimensions(imageDimensions)))
                                        let updatedFile = file.withUpdatedSize(data.size).withUpdatedPreviewRepresentations([TelegramMediaImageRepresentation(dimensions: PixelDimensions(scaledImageSize), resource: thumbnailResource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)]).withUpdatedAttributes(attributes)
                                        subscriber.putNext(media.withUpdatedMedia(updatedFile))
                                        subscriber.putCompletion()
                                    } else {
                                        let updatedFile = file.withUpdatedSize(data.size)
                                        subscriber.putNext(media.withUpdatedMedia(updatedFile))
                                        subscriber.putCompletion()
                                    }
                                } else {
                                    let updatedFile = file.withUpdatedSize(data.size)
                                    subscriber.putNext(media.withUpdatedMedia(updatedFile))
                                    subscriber.putCompletion()
                                }
                            } else {
                                let updatedFile = file.withUpdatedSize(data.size)
                                subscriber.putNext(media.withUpdatedMedia(updatedFile))
                                subscriber.putCompletion()
                            }
                            
                            return EmptyDisposable
                        } |> runOn(opportunistic ? Queue.mainQueue() : Queue.concurrentDefaultQueue())
                    } else if file.mimeType.hasPrefix("video/") && !file.mimeType.hasSuffix("/webm") {
                        return Signal { subscriber in
                            if let scaledImage = generateVideoFirstFrame(data.path, maxDimensions: CGSize(width: 320.0, height: 320.0)), let thumbnailData = scaledImage.jpegData(compressionQuality: 0.6) {
                                let thumbnailResource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                                postbox.mediaBox.storeResourceData(thumbnailResource.id, data: thumbnailData)
                            
                                let scaledImageSize = CGSize(width: scaledImage.size.width * scaledImage.scale, height: scaledImage.size.height * scaledImage.scale)
                            
                                let updatedFile = file.withUpdatedSize(data.size).withUpdatedPreviewRepresentations([TelegramMediaImageRepresentation(dimensions: PixelDimensions(scaledImageSize), resource: thumbnailResource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)])
                                subscriber.putNext(media.withUpdatedMedia(updatedFile))
                                subscriber.putCompletion()
                            } else {
                                let updatedFile = file.withUpdatedSize(data.size)
                                subscriber.putNext(media.withUpdatedMedia(updatedFile))
                                subscriber.putCompletion()
                            }
                            
                            return EmptyDisposable
                        } |> runOn(opportunistic ? Queue.mainQueue() : Queue.concurrentDefaultQueue())
                    } else {
                        let updatedFile = file.withUpdatedSize(data.size)
                        return .single(media.withUpdatedMedia(updatedFile))
                    }
                } else if opportunistic {
                    return .single(nil)
                } else {
                    return .complete()
                }
            }
        case let image as TelegramMediaImage:
            if let representation = largestImageRepresentation(image.representations) {
                let signal = Signal<MediaResourceData, NoError> { subscriber in
                    let fetch = fetchedMediaResource(mediaBox: postbox.mediaBox, userLocation: .other, userContentType: .image, reference: media.resourceReference(representation.resource)).start()
                    let data = postbox.mediaBox.resourceData(representation.resource, option: .complete(waitUntilFetchStatus: true)).start(next: { next in
                        subscriber.putNext(next)
                        if next.complete {
                            subscriber.putCompletion()
                        }
                    })
                    
                    return ActionDisposable {
                        fetch.dispose()
                        data.dispose()
                    }
                }
                
                let result: Signal<MediaResourceData, NoError>
                if opportunistic {
                    result = signal
                    |> take(1)
                } else {
                    result = signal
                }
                
                return result
                |> mapToSignal { data -> Signal<AnyMediaReference?, NoError> in
                    if data.complete {
                        if let smallest = smallestImageRepresentation(image.representations), smallest.dimensions.width > 100 || smallest.dimensions.height > 100 {
                            let smallestSize = smallest.dimensions.cgSize.fitted(CGSize(width: 320.0, height: 320.0))
                            let tempFile = TempBox.shared.tempFile(fileName: "file")
                            defer {
                                TempBox.shared.dispose(tempFile)
                            }
                            if let fullImage = UIImage(contentsOfFile: data.path), let smallestImage = generateScaledImage(image: fullImage, size: smallestSize, scale: 1.0), let smallestData = compressImageToJPEG(smallestImage, quality: 0.7, tempFilePath: tempFile.path) {
                                var representations = image.representations
                                
                                let thumbnailResource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                                postbox.mediaBox.storeResourceData(thumbnailResource.id, data: smallestData)
                                representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(smallestSize), resource: thumbnailResource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false))
                                let updatedImage = TelegramMediaImage(imageId: image.imageId, representations: representations, immediateThumbnailData: image.immediateThumbnailData, reference: image.reference, partialReference: image.partialReference, flags: [])
                                return .single(media.withUpdatedMedia(updatedImage))
                            }
                        }
                        
                        return .single(nil)
                    } else if opportunistic {
                        return .single(nil)
                    } else {
                        return .complete()
                    }
                }
            } else {
                return .single(nil)
            }
        default:
            return .single(nil)
    }
}
