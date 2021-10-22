import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import UIKit
import TinyThumbnail
import Display
import FastBlur
import MozjpegBinding

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

private func storeImage(context: DrawingContext, to path: String) -> UIImage? {
    if context.size.width <= 70.0 && context.size.height <= 70.0 {
        guard let file = ManagedFile(queue: nil, path: path, mode: .readwrite) else {
            return nil
        }
        var header: UInt32 = 0xcaf1
        let _ = file.write(&header, count: 4)
        var width: UInt16 = UInt16(context.size.width)
        let _ = file.write(&width, count: 2)
        var height: UInt16 = UInt16(context.size.height)
        let _ = file.write(&height, count: 2)
        var bytesPerRow: UInt16 = UInt16(context.bytesPerRow)
        let _ = file.write(&bytesPerRow, count: 2)

        let _ = file.write(context.bytes, count: context.length)

        return context.generateImage()
    } else {
        guard let image = context.generateImage(), let resultData = image.jpegData(compressionQuality: 0.7) else {
            return nil
        }
        let _ = try? resultData.write(to: URL(fileURLWithPath: path))
        return image
    }
}

private func loadImage(data: Data) -> UIImage? {
    if data.count > 4 + 2 + 2 + 2 {
        var header: UInt32 = 0
        withUnsafeMutableBytes(of: &header, { header in
            data.copyBytes(to: header.baseAddress!.assumingMemoryBound(to: UInt8.self), from: 0 ..< 4)
        })
        if header == 0xcaf1 {
            var width: UInt16 = 0
            withUnsafeMutableBytes(of: &width, { width in
                data.copyBytes(to: width.baseAddress!.assumingMemoryBound(to: UInt8.self), from: 4 ..< (4 + 2))
            })
            var height: UInt16 = 0
            withUnsafeMutableBytes(of: &height, { height in
                data.copyBytes(to: height.baseAddress!.assumingMemoryBound(to: UInt8.self), from: (4 + 2) ..< (4 + 2 + 2))
            })
            var bytesPerRow: UInt16 = 0
            withUnsafeMutableBytes(of: &bytesPerRow, { bytesPerRow in
                data.copyBytes(to: bytesPerRow.baseAddress!.assumingMemoryBound(to: UInt8.self), from: (4 + 2 + 2) ..< (4 + 2 + 2 + 2))
            })

            let imageData = data.subdata(in: (4 + 2 + 2 + 2) ..< data.count)
            guard let dataProvider = CGDataProvider(data: imageData as CFData) else {
                return nil
            }

            if let image = CGImage(
                width: Int(width),
                height: Int(height),
                bitsPerComponent: DeviceGraphicsContextSettings.shared.bitsPerComponent,
                bitsPerPixel: DeviceGraphicsContextSettings.shared.bitsPerPixel,
                bytesPerRow: Int(bytesPerRow),
                space: DeviceGraphicsContextSettings.shared.colorSpace,
                bitmapInfo: DeviceGraphicsContextSettings.shared.opaqueBitmapInfo,
                provider: dataProvider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            ) {
                return UIImage(cgImage: image, scale: 1.0, orientation: .up)
            } else {
                return nil
            }
        }
    }
    
    if let decompressedImage = decompressImage(data) {
        return decompressedImage
    }

    return UIImage(data: data)
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
                    let scaledSize = CGSize(width: CGFloat(width), height: CGFloat(width))
                    let scaledContext = DrawingContext(size: scaledSize, scale: 1.0, opaque: true)
                    scaledContext.withFlippedContext { context in
                        let filledSize = image.size.aspectFilled(scaledSize)
                        let imageRect = CGRect(origin: CGPoint(x: (scaledSize.width - filledSize.width) / 2.0, y: (scaledSize.height - filledSize.height) / 2.0), size: filledSize)
                        context.draw(image.cgImage!, in: imageRect)
                    }

                    if let scaledImage = storeImage(context: scaledContext, to: cachePath) {
                        subscriber.putNext(scaledImage)
                        subscriber.putCompletion()
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
            if let data = try? Data(contentsOf: URL(fileURLWithPath: self.getCachePath(resourceId: resource.resource.id, imageType: .square(width: width)))), let image = loadImage(data: data) {
                return GetMediaResult(image: image, loadSignal: nil)
            }

            var blurredImage: UIImage?
            if let data = try? Data(contentsOf: URL(fileURLWithPath: self.getCachePath(resourceId: resource.resource.id, imageType: .blurredThumbnail))), let image = loadImage(data: data) {
                blurredImage = image
            } else if let data = immediateThumbnailData.flatMap(decodeTinyThumbnail), let image = loadImage(data: data) {
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
