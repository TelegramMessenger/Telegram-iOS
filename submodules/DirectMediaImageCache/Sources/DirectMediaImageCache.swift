import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import UIKit
import TinyThumbnail
import Display
import FastBlur
import MozjpegBinding
import Accelerate
import ManagedFile

private func adjustSaturationInContext(context: DrawingContext, saturation: CGFloat) {
    var buffer = vImage_Buffer()
    buffer.data = context.bytes
    buffer.width = UInt(context.size.width * context.scale)
    buffer.height = UInt(context.size.height * context.scale)
    buffer.rowBytes = context.bytesPerRow

    let divisor: Int32 = 0x1000

    let rwgt: CGFloat = 0.3086
    let gwgt: CGFloat = 0.6094
    let bwgt: CGFloat = 0.0820

    let adjustSaturation = saturation

    let a = (1.0 - adjustSaturation) * rwgt + adjustSaturation
    let b = (1.0 - adjustSaturation) * rwgt
    let c = (1.0 - adjustSaturation) * rwgt
    let d = (1.0 - adjustSaturation) * gwgt
    let e = (1.0 - adjustSaturation) * gwgt + adjustSaturation
    let f = (1.0 - adjustSaturation) * gwgt
    let g = (1.0 - adjustSaturation) * bwgt
    let h = (1.0 - adjustSaturation) * bwgt
    let i = (1.0 - adjustSaturation) * bwgt + adjustSaturation

    let satMatrix: [CGFloat] = [
        a, b, c, 0,
        d, e, f, 0,
        g, h, i, 0,
        0, 0, 0, 1
    ]

    var matrix: [Int16] = satMatrix.map { value in
        return Int16(value * CGFloat(divisor))
    }

    vImageMatrixMultiply_ARGB8888(&buffer, &buffer, &matrix, divisor, nil, nil, vImage_Flags(kvImageDoNotTile))
}


private func generateBlurredThumbnail(image: UIImage, adjustSaturation: Bool = false) -> UIImage? {
    let thumbnailContextSize = CGSize(width: 32.0, height: 32.0)
    guard let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0) else {
        return nil
    }

    let filledSize = image.size.aspectFilled(thumbnailContextSize)
    let imageRect = CGRect(origin: CGPoint(x: (thumbnailContextSize.width - filledSize.width) / 2.0, y: (thumbnailContextSize.height - filledSize.height) / 2.0), size: filledSize)

    thumbnailContext.withFlippedContext { c in
        c.draw(image.cgImage!, in: imageRect)
    }
    telegramFastBlurMore(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)

    if adjustSaturation {
        adjustSaturationInContext(context: thumbnailContext, saturation: 1.7)
    }
    
    return thumbnailContext.generateImage()
}

private func storeImage(context: DrawingContext, to path: String) -> UIImage? {
    if context.size.width <= 70.0 && context.size.height <= 70.0 {
        guard let file = ManagedFile(queue: nil, path: path, mode: .readwrite) else {
            return nil
        }
        var header: UInt32 = 0xcaf2
        let _ = file.write(&header, count: 4)
        var width: UInt16 = UInt16(context.size.width)
        let _ = file.write(&width, count: 2)
        var height: UInt16 = UInt16(context.size.height)
        let _ = file.write(&height, count: 2)

        var source = vImage_Buffer()
        source.width = UInt(context.size.width)
        source.height = UInt(context.size.height)
        source.rowBytes = context.bytesPerRow
        source.data = context.bytes

        var target = vImage_Buffer()
        target.width = UInt(context.size.width)
        target.height = UInt(context.size.height)
        target.rowBytes = Int(context.size.width) * 2
        let targetLength = Int(target.height) * target.rowBytes
        let targetData = malloc(targetLength)!
        defer {
            free(targetData)
        }
        target.data = targetData

        vImageConvert_BGRA8888toRGB565(&source, &target, vImage_Flags(kvImageDoNotTile))

        let _ = file.write(targetData, count: targetLength)

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
        } else if header == 0xcaf2 {
            var width: UInt16 = 0
            withUnsafeMutableBytes(of: &width, { width in
                data.copyBytes(to: width.baseAddress!.assumingMemoryBound(to: UInt8.self), from: 4 ..< (4 + 2))
            })
            var height: UInt16 = 0
            withUnsafeMutableBytes(of: &height, { height in
                data.copyBytes(to: height.baseAddress!.assumingMemoryBound(to: UInt8.self), from: (4 + 2) ..< (4 + 2 + 2))
            })

            return data.withUnsafeBytes { data -> UIImage? in
                let sourceBytes = data.baseAddress!

                var source = vImage_Buffer()
                source.width = UInt(width)
                source.height = UInt(height)
                source.rowBytes = Int(width * 2)
                source.data = UnsafeMutableRawPointer(mutating: sourceBytes.advanced(by: 4 + 2 + 2))

                guard let context = DrawingContext(size: CGSize(width: CGFloat(width), height: CGFloat(height)), scale: 1.0, opaque: true, clear: false) else {
                    return nil
                }

                var target = vImage_Buffer()
                target.width = UInt(width)
                target.height = UInt(height)
                target.rowBytes = context.bytesPerRow
                target.data = context.bytes

                vImageConvert_RGB565toBGRA8888(0xff, &source, &target, vImage_Flags(kvImageDoNotTile))

                return context.generateImage()
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
        public let blurredImage: UIImage?
        public let loadSignal: Signal<UIImage?, NoError>?

        init(image: UIImage?, blurredImage: UIImage? = nil, loadSignal: Signal<UIImage?, NoError>?) {
            self.image = image
            self.blurredImage = blurredImage
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

    private func getLoadSignal(width: Int, userLocation: MediaResourceUserLocation, userContentType: MediaResourceUserContentType, resource: MediaResourceReference, resourceSizeLimit: Int64) -> Signal<UIImage?, NoError>? {
        return Signal { subscriber in
            let cachePath = self.getCachePath(resourceId: resource.resource.id, imageType: .square(width: width))

            let fetch = fetchedMediaResource(
                mediaBox: self.account.postbox.mediaBox,
                userLocation: userLocation,
                userContentType: userContentType,
                reference: resource,
                ranges: [(0 ..< resourceSizeLimit, .default)],
                statsCategory: .image,
                reportResultStatus: false,
                preferBackgroundReferenceRevalidation: false,
                continueInBackground: false
            ).start()

            let dataSignal: Signal<Data?, NoError>
            if resourceSizeLimit < Int64.max {
                dataSignal = self.account.postbox.mediaBox.resourceData(resource.resource, size: resourceSizeLimit, in: 0 ..< resourceSizeLimit)
                |> map { data, _ -> Data? in
                    return data
                }
            } else {
                dataSignal = self.account.postbox.mediaBox.resourceData(resource.resource)
                |> filter { data in
                    return data.complete
                }
                |> take(1)
                |> map { data -> Data? in
                    return try? Data(contentsOf: URL(fileURLWithPath: data.path))
                }
            }

            let data = dataSignal.start(next: { data in
                if let data = data, let image = UIImage(data: data) {
                    let scaledSize = CGSize(width: CGFloat(width), height: CGFloat(width))
                    guard let scaledContext = DrawingContext(size: scaledSize, scale: 1.0, opaque: true) else {
                        subscriber.putNext(nil)
                        subscriber.putCompletion()
                        return
                    }
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

    private func getProgressiveSize(mediaReference: AnyMediaReference, width: Int, representations: [TelegramMediaImageRepresentation]) -> (resource: MediaResourceReference, size: Int64)? {
        if let representation = representations.first(where: { !$0.progressiveSizes.isEmpty }) {
            let selectedSize: Int64
            let progressiveSizes = representation.progressiveSizes
            if progressiveSizes.count > 0 && width <= 64 {
                selectedSize = Int64(progressiveSizes[0])
            } else if progressiveSizes.count > 2 && width <= 160 {
                selectedSize = Int64(progressiveSizes[2])
            } else if progressiveSizes.count > 4 && width <= 400 {
                selectedSize = Int64(progressiveSizes[4])
            } else {
                selectedSize = Int64.max
            }
            return (mediaReference.resourceReference(representation.resource), selectedSize)
        } else {
            for representation in representations.sorted(by: { $0.dimensions.width < $1.dimensions.width }) {
                if Int(Float(representation.dimensions.width) * 1.2) >= width {
                    return (mediaReference.resourceReference(representation.resource), Int64.max)
                }
            }
            if let representation = representations.last {
                return (mediaReference.resourceReference(representation.resource), Int64.max)
            }
            return nil
        }
    }

    private func getResource(message: Message, image: TelegramMediaImage, width: Int) -> (resource: MediaResourceReference, size: Int64)? {
        return self.getProgressiveSize(mediaReference: MediaReference.message(message: MessageReference(message), media: image).abstract, width: width, representations: image.representations)
    }

    private func getResource(message: Message, file: TelegramMediaFile, width: Int) -> (resource: MediaResourceReference, size: Int64)? {
        return self.getProgressiveSize(mediaReference: MediaReference.message(message: MessageReference(message), media: file).abstract, width: width, representations: file.previewRepresentations)
    }

    private func getImageSynchronous(message: Message, userLocation: MediaResourceUserLocation, media: Media, width: Int, possibleWidths: [Int], includeBlurred: Bool) -> GetMediaResult? {
        var immediateThumbnailData: Data?
        var resource: (resource: MediaResourceReference, size: Int64)?
        if let image = media as? TelegramMediaImage {
            immediateThumbnailData = image.immediateThumbnailData
            resource = self.getResource(message: message, image: image, width: width)
        } else if let file = media as? TelegramMediaFile {
            immediateThumbnailData = file.immediateThumbnailData
            resource = self.getResource(message: message, file: file, width: width)
        }

        guard let resource = resource else {
            return nil
        }
        
        
        var blurredImage: UIImage?
        if includeBlurred, let data = immediateThumbnailData.flatMap(decodeTinyThumbnail), let image = loadImage(data: data), let blurredImageValue = generateBlurredThumbnail(image: image, adjustSaturation: true) {
            blurredImage = blurredImageValue
        }
        
        var resultImage: UIImage?
        for otherWidth in possibleWidths.reversed() {
            if otherWidth == width {
                if let data = try? Data(contentsOf: URL(fileURLWithPath: self.getCachePath(resourceId: resource.resource.resource.id, imageType: .square(width: otherWidth)))), let image = loadImage(data: data) {
                    return GetMediaResult(image: image, blurredImage: blurredImage, loadSignal: nil)
                }
            } else {
                if let data = try? Data(contentsOf: URL(fileURLWithPath: self.getCachePath(resourceId: resource.resource.resource.id, imageType: .square(width: otherWidth)))), let image = loadImage(data: data) {
                    resultImage = image
                }
            }
        }

        if resultImage == nil {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: self.getCachePath(resourceId: resource.resource.resource.id, imageType: .blurredThumbnail))), let image = loadImage(data: data) {
                resultImage = image
            } else if let data = immediateThumbnailData.flatMap(decodeTinyThumbnail), let image = loadImage(data: data) {
                if let blurredImageValue = generateBlurredThumbnail(image: image) {
                    resultImage = blurredImageValue
                }
            }
        }
        
        return GetMediaResult(image: resultImage, blurredImage: blurredImage, loadSignal: self.getLoadSignal(width: width, userLocation: userLocation, userContentType: .image, resource: resource.resource, resourceSizeLimit: resource.size))
    }

    public func getImage(message: Message, media: Media, width: Int, possibleWidths: [Int], includeBlurred: Bool = false, synchronous: Bool) -> GetMediaResult? {
        if synchronous {
            return self.getImageSynchronous(message: message, userLocation: .peer(message.id.peerId), media: media, width: width, possibleWidths: possibleWidths, includeBlurred: includeBlurred)
        } else {
            var immediateThumbnailData: Data?
            if let image = media as? TelegramMediaImage {
                immediateThumbnailData = image.immediateThumbnailData
            } else if let file = media as? TelegramMediaFile {
                immediateThumbnailData = file.immediateThumbnailData
            }
            var blurredImage: UIImage?
            if includeBlurred, let data = immediateThumbnailData.flatMap(decodeTinyThumbnail), let image = loadImage(data: data), let blurredImageValue = generateBlurredThumbnail(image: image, adjustSaturation: true) {
                blurredImage = blurredImageValue
            }
            return GetMediaResult(image: nil, blurredImage: blurredImage, loadSignal: Signal { subscriber in
                let result = self.getImageSynchronous(message: message, userLocation: .peer(message.id.peerId), media: media, width: width, possibleWidths: possibleWidths, includeBlurred: includeBlurred)
                guard let result = result else {
                    subscriber.putNext(nil)
                    subscriber.putCompletion()

                    return EmptyDisposable
                }

                if let image = result.image {
                    subscriber.putNext(image)
                }

                if let signal = result.loadSignal {
                    return signal.start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
                } else {
                    subscriber.putCompletion()

                    return EmptyDisposable
                }
            }
            |> runOn(.concurrentDefaultQueue()))
        }
    }
}
