import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import UIKit
import TinyThumbnail
import Display
import FastBlur

private func generateBlurredThumbnail(image: UIImage) -> UIImage? {
    let thumbnailContextSize = CGSize(width: 32.0, height: 32.0)
    let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)

    let filledSize = image.size.aspectFilled(thumbnailContextSize)
    let imageRect = CGRect(origin: CGPoint(x: (thumbnailContextSize.width - filledSize.width) / 2.0, y: (thumbnailContextSize.height - filledSize.height) / 2.0), size: filledSize)

    thumbnailContext.withFlippedContext { c in
        c.draw(image.cgImage!, in: imageRect)
    }
    telegramFastBlurMore(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)

    return thumbnailContext.generateImage()
}

public final class DirectMediaImageCache {
    public final class GetMediaResult {
        public let image: UIImage?
        public let loadSignal: Signal<UIImage?, NoError>?

        init(image: UIImage?, loadSignal: Signal<UIImage?, NoError>?) {
            self.image = image
            self.loadSignal = loadSignal
        }
    }

    private enum ImageType {
        case blurredThumbnail
        case square(width: Int)
    }

    private let account: Account

    public init(account: Account) {
        self.account = account
    }

    private func getCachePath(resourceId: MediaResourceId, imageType: ImageType) -> String {
        let representationId: String
        switch imageType {
        case .blurredThumbnail:
            representationId = "blurred32"
        case let .square(width):
            representationId = "shm\(width)"
        }
        return self.account.postbox.mediaBox.cachedRepresentationPathForId(resourceId.stringRepresentation, representationId: representationId, keepDuration: .general)
    }

    private func getLoadSignal(resource: MediaResourceReference, width: Int) -> Signal<UIImage?, NoError>? {
        let cachePath = self.getCachePath(resourceId: resource.resource.id, imageType: .square(width: width))
        return Signal { subscriber in
            let fetch = fetchedMediaResource(mediaBox: self.account.postbox.mediaBox, reference: resource).start()
            let data = (self.account.postbox.mediaBox.resourceData(resource.resource)
            |> filter { data in
                return data.complete
            }
            |> take(1)).start(next: { data in
                if let dataValue = try? Data(contentsOf: URL(fileURLWithPath: data.path)), let image = UIImage(data: dataValue) {
                    if let scaledImage = generateImage(CGSize(width: CGFloat(width), height: CGFloat(width)), contextGenerator: { size, context in
                        let filledSize = image.size.aspectFilled(size)
                        let imageRect = CGRect(origin: CGPoint(x: (size.width - filledSize.width) / 2.0, y: (size.height - filledSize.height) / 2.0), size: filledSize)
                        context.draw(image.cgImage!, in: imageRect)
                    }, scale: 1.0) {
                        if let resultData = scaledImage.jpegData(compressionQuality: 0.7) {
                            let _ = try? resultData.write(to: URL(fileURLWithPath: cachePath))
                            subscriber.putNext(scaledImage)
                            subscriber.putCompletion()
                        }
                    }
                }
            })

            return ActionDisposable {
                fetch.dispose()
                data.dispose()
            }
        }
    }

    private func getResource(message: Message, image: TelegramMediaImage) -> MediaResourceReference? {
        guard let representation = image.representations.last else {
            return nil
        }
        return MediaReference.message(message: MessageReference(message), media: image).resourceReference(representation.resource)
    }

    private func getResource(message: Message, file: TelegramMediaFile) -> MediaResourceReference? {
        if let representation = file.previewRepresentations.last {
            return MediaReference.message(message: MessageReference(message), media: file).resourceReference(representation.resource)
        } else {
            return nil
        }
    }

    public func getImage(message: Message, media: Media, width: Int) -> GetMediaResult? {
        var immediateThumbnailData: Data?
        var resource: MediaResourceReference?
        if let image = media as? TelegramMediaImage {
            immediateThumbnailData = image.immediateThumbnailData
            resource = self.getResource(message: message, image: image)
        } else if let file = media as? TelegramMediaFile {
            immediateThumbnailData = file.immediateThumbnailData
            resource = self.getResource(message: message, file: file)
        }

        if let resource = resource {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: self.getCachePath(resourceId: resource.resource.id, imageType: .square(width: width)))), let image = UIImage(data: data) {
                return GetMediaResult(image: image, loadSignal: nil)
            }

            var blurredImage: UIImage?
            if let data = try? Data(contentsOf: URL(fileURLWithPath: self.getCachePath(resourceId: resource.resource.id, imageType: .blurredThumbnail))), let image = UIImage(data: data) {
                blurredImage = image
            } else if let data = immediateThumbnailData.flatMap(decodeTinyThumbnail), let image = UIImage(data: data) {
                if let blurredImageValue = generateBlurredThumbnail(image: image) {
                    blurredImage = blurredImageValue
                }
            }

            return GetMediaResult(image: blurredImage, loadSignal: self.getLoadSignal(resource: resource, width: width))
        } else {
            return nil
        }
    }
}
