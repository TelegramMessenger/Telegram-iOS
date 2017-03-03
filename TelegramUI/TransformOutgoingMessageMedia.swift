import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import Display

public func transformOutgoingMessageMedia(postbox: Postbox, network: Network, media: Media, opportunistic: Bool) -> Signal<Media?, NoError> {
    switch media {
        case let file as TelegramMediaFile:
            let signal = Signal<MediaResourceData, NoError> { subscriber in
                let fetch = postbox.mediaBox.fetchedResource(file.resource).start()
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
                                if let image = UIImage(contentsOfFile: data.path), let scaledImage = generateImage(image.size.fitted(CGSize(width: 90.0, height: 90.0)), context: { size, context in
                                    context.setBlendMode(.copy)
                                    context.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: size))
                                }), let thumbnailData = UIImageJPEGRepresentation(scaledImage, 0.6) {
                                    let thumbnailResource = LocalFileMediaResource(fileId: arc4random64())
                                    postbox.mediaBox.storeResourceData(thumbnailResource.id, data: thumbnailData)
                                    
                                    let scaledImageSize = CGSize(width: scaledImage.size.width * scaledImage.scale, height: scaledImage.size.height * scaledImage.scale)
                                    
                                    subscriber.putNext(file.withUpdatedSize(data.size).withUpdatedPreviewRepresentations([TelegramMediaImageRepresentation(dimensions: scaledImageSize, resource: thumbnailResource)]))
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
        default:
            return .single(nil)
    }
}
