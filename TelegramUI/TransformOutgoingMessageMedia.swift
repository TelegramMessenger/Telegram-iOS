import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import Display

public func transformOutgoingMessageMedia(postbox: Postbox, network: Network, media: Media, opportunistic: Bool) -> Signal<Media?, NoError> {
    switch media {
        case let file as TelegramMediaFile:
            let signal = Signal<MediaResourceData, NoError> { subscriber in
                let fetch = postbox.mediaBox.fetchedResource(file.resource, tag: TelegramMediaResourceFetchTag(statsCategory: statsCategoryForFileWithAttributes(file.attributes))).start()
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
                |> mapToSignal { data -> Signal<Media?, NoError> in
                    if data.complete {
                        if file.mimeType.hasPrefix("image/") {
                            return Signal { subscriber in
                                if let image = UIImage(contentsOfFile: data.path), let scaledImage = generateImage(image.size.fitted(CGSize(width: 90.0, height: 90.0)), contextGenerator: { size, context in
                                    context.setBlendMode(.copy)
                                    context.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: size))
                                }, scale: 1.0), let thumbnailData = UIImageJPEGRepresentation(scaledImage, 0.6) {
                                    let imageDimensions = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
                                    
                                    let thumbnailResource = LocalFileMediaResource(fileId: arc4random64())
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
                                    attributes.append(.ImageSize(size: imageDimensions))
                                    subscriber.putNext(file.withUpdatedSize(data.size).withUpdatedPreviewRepresentations([TelegramMediaImageRepresentation(dimensions: scaledImageSize, resource: thumbnailResource)]).withUpdatedAttributes(attributes))
                                    subscriber.putCompletion()
                                } else {
                                    subscriber.putNext(file.withUpdatedSize(data.size))
                                    subscriber.putCompletion()
                                }
                                
                                return EmptyDisposable
                            } |> runOn(opportunistic ? Queue.mainQueue() : Queue.concurrentDefaultQueue())
                        } else {
                            return .single(file.withUpdatedSize(data.size))
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
                    let fetch = postbox.mediaBox.fetchedResource(representation.resource, tag: TelegramMediaResourceFetchTag(statsCategory: .image)).start()
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
                    result = signal |> take(1)
                } else {
                    result = signal
                }
                
                return result
                    |> mapToSignal { data -> Signal<Media?, NoError> in
                        if data.complete {
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
