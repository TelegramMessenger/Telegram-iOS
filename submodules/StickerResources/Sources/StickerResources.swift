import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import Display
import TelegramCore
import MediaResources
import Tuples
import ImageBlur
import FastBlur

private func imageFromAJpeg(data: Data) -> (UIImage, UIImage)? {
    if let (colorData, alphaData) = data.withUnsafeBytes({ bytes -> (Data, Data)? in
        var colorSize: Int32 = 0
        memcpy(&colorSize, bytes.baseAddress, 4)
        if colorSize < 0 || Int(colorSize) > data.count - 8 {
            return nil
        }
        var alphaSize: Int32 = 0
        memcpy(&alphaSize, bytes.baseAddress?.advanced(by: 4 + Int(colorSize)), 4)
        if alphaSize < 0 || Int(alphaSize) > data.count - Int(colorSize) - 8 {
            return nil
        }
        //let colorData = Data(bytesNoCopy: UnsafeMutablePointer(mutating: bytes).advanced(by: 4), count: Int(colorSize), deallocator: .none)
        //let alphaData = Data(bytesNoCopy: UnsafeMutablePointer(mutating: bytes).advanced(by: 4 + Int(colorSize) + 4), count: Int(alphaSize), deallocator: .none)
        let colorData = data.subdata(in: 4 ..< (4 + Int(colorSize)))
        let alphaData = data.subdata(in: (4 + Int(colorSize) + 4) ..< (4 + Int(colorSize) + 4 + Int(alphaSize)))
        return (colorData, alphaData)
    }) {
        if let colorImage = UIImage(data: colorData), let alphaImage = UIImage(data: alphaData) {
            return (colorImage, alphaImage)
            
            /*return generateImage(CGSize(width: colorImage.size.width * colorImage.scale, height: colorImage.size.height * colorImage.scale), contextGenerator: { size, context in
                colorImage.draw(in: CGRect(origin: CGPoint(), size: size))
            }, scale: 1.0)*/
        }
    }
    return nil
}

public func chatMessageStickerResource(file: TelegramMediaFile, small: Bool) -> MediaResource {
    let resource: MediaResource
    if small, let smallest = largestImageRepresentation(file.previewRepresentations) {
        resource = smallest.resource
    } else {
        resource = file.resource
    }
    return resource
}

private func chatMessageStickerDatas(postbox: Postbox, file: TelegramMediaFile, small: Bool, fetched: Bool, onlyFullSize: Bool, synchronousLoad: Bool) -> Signal<Tuple3<Data?, Data?, Bool>, NoError> {
    let thumbnailResource = chatMessageStickerResource(file: file, small: true)
    let resource = chatMessageStickerResource(file: file, small: small)
    
    let maybeFetched = postbox.mediaBox.cachedResourceRepresentation(resource, representation: CachedStickerAJpegRepresentation(size: small ? CGSize(width: 160.0, height: 160.0) : nil), complete: false, fetch: false, attemptSynchronously: synchronousLoad)
    
    return maybeFetched
    |> take(1)
    |> mapToSignal { maybeData in
        if maybeData.complete {
            let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [])
            
            return .single(Tuple(nil, loadedData, true))
        } else {
            let thumbnailData = postbox.mediaBox.cachedResourceRepresentation(thumbnailResource, representation: CachedStickerAJpegRepresentation(size: nil), complete: false)
            let fullSizeData = postbox.mediaBox.cachedResourceRepresentation(resource, representation: CachedStickerAJpegRepresentation(size: small ? CGSize(width: 160.0, height: 160.0) : nil), complete: onlyFullSize)
            |> map { next in
                return (next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: .mappedIfSafe), next.complete)
            }
            
            return Signal { subscriber in
                var fetch: Disposable?
                if fetched {
                    fetch = fetchedMediaResource(mediaBox: postbox.mediaBox, reference: stickerPackFileReference(file).resourceReference(resource)).start()
                }
                
                var fetchThumbnail: Disposable?
                if thumbnailResource.id != resource.id {
                    fetchThumbnail = fetchedMediaResource(mediaBox: postbox.mediaBox, reference: stickerPackFileReference(file).resourceReference(thumbnailResource)).start()
                }
                let disposable = (combineLatest(thumbnailData, fullSizeData)
                |> map { thumbnailData, fullSizeData -> Tuple3<Data?, Data?, Bool> in
                    return Tuple(thumbnailData.complete ? try? Data(contentsOf: URL(fileURLWithPath: thumbnailData.path)) : nil, fullSizeData.0, fullSizeData.1)
                }).start(next: { next in
                    subscriber.putNext(next)
                }, error: { _ in
                }, completed: {
                    subscriber.putCompletion()
                })
                
                return ActionDisposable {
                    fetch?.dispose()
                    fetchThumbnail?.dispose()
                    disposable.dispose()
                }
            }
        }
    }
}

public func chatMessageAnimatedStickerDatas(postbox: Postbox, file: TelegramMediaFile, small: Bool, size: CGSize, fitzModifier: EmojiFitzModifier? = nil, fetched: Bool, onlyFullSize: Bool, synchronousLoad: Bool) -> Signal<Tuple3<Data?, Data?, Bool>, NoError> {
    let thumbnailResource = chatMessageStickerResource(file: file, small: true)
    let resource = chatMessageStickerResource(file: file, small: false)
    
    let firstFrameRepresentation = CachedAnimatedStickerFirstFrameRepresentation(width: Int32(size.width), height: Int32(size.height), fitzModifier: fitzModifier)
    let maybeFetched = postbox.mediaBox.cachedResourceRepresentation(resource, representation: firstFrameRepresentation, complete: false, fetch: false, attemptSynchronously: synchronousLoad)
    
    return maybeFetched
    |> take(1)
    |> mapToSignal { maybeData in
        if maybeData.complete {
            let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [])
            
            return .single(Tuple(nil, loadedData, true))
        } else {
            let thumbnailData = postbox.mediaBox.cachedResourceRepresentation(thumbnailResource, representation: CachedStickerAJpegRepresentation(size: nil), complete: false)
            let fullSizeData = postbox.mediaBox.cachedResourceRepresentation(resource, representation: firstFrameRepresentation, complete: onlyFullSize)
            |> map { next in
                return (next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: .mappedIfSafe), next.complete)
            }
            
            return Signal { subscriber in
                var fetch: Disposable?
                if fetched {
                    fetch = fetchedMediaResource(mediaBox: postbox.mediaBox, reference: stickerPackFileReference(file).resourceReference(resource)).start()
                }
                
                var fetchThumbnail: Disposable?
                if thumbnailResource.id != resource.id {
                    fetchThumbnail = fetchedMediaResource(mediaBox: postbox.mediaBox, reference: stickerPackFileReference(file).resourceReference(thumbnailResource)).start()
                }
                let disposable = (combineLatest(thumbnailData, fullSizeData)
                    |> map { thumbnailData, fullSizeData -> Tuple3<Data?, Data?, Bool> in
                        return Tuple(thumbnailData.complete ? try? Data(contentsOf: URL(fileURLWithPath: thumbnailData.path)) : nil, fullSizeData.0, fullSizeData.1)
                    }).start(next: { next in
                        subscriber.putNext(next)
                    }, error: { _ in
                    }, completed: {
                        subscriber.putCompletion()
                    })
                
                return ActionDisposable {
                    fetch?.dispose()
                    fetchThumbnail?.dispose()
                    disposable.dispose()
                }
            }
        }
    }
}

private func chatMessageStickerThumbnailData(postbox: Postbox, file: TelegramMediaFile, synchronousLoad: Bool) -> Signal<Data?, NoError> {
    let thumbnailResource = chatMessageStickerResource(file: file, small: true)
    
    let maybeFetched = postbox.mediaBox.cachedResourceRepresentation(thumbnailResource, representation: CachedStickerAJpegRepresentation(size: nil), complete: false, fetch: false, attemptSynchronously: synchronousLoad)
    
    return maybeFetched
    |> take(1)
    |> mapToSignal { maybeData in
        if maybeData.complete {
            let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [])
            return .single(loadedData)
        } else {
            let thumbnailData = postbox.mediaBox.cachedResourceRepresentation(thumbnailResource, representation: CachedStickerAJpegRepresentation(size: nil), complete: false)
            
            return Signal { subscriber in
                let fetchThumbnail = fetchedMediaResource(mediaBox: postbox.mediaBox, reference: stickerPackFileReference(file).resourceReference(thumbnailResource)).start()

                let disposable = (thumbnailData
                |> map { thumbnailData -> Data? in
                    return thumbnailData.complete ? try? Data(contentsOf: URL(fileURLWithPath: thumbnailData.path)) : nil
                }).start(next: { next in
                    subscriber.putNext(next)
                }, error: { _ in
                }, completed: {
                    subscriber.putCompletion()
                })
                
                return ActionDisposable {
                    fetchThumbnail.dispose()
                    disposable.dispose()
                }
            }
        }
    }
}

private func chatMessageStickerPackThumbnailData(postbox: Postbox, resource: MediaResource, animated: Bool, synchronousLoad: Bool) -> Signal<Data?, NoError> {
    let maybeFetched: Signal<MediaResourceData, NoError>
    let representation: CachedMediaResourceRepresentation
    if animated {
        representation = CachedAnimatedStickerFirstFrameRepresentation(width: 160, height: 160)
    } else {
        representation = CachedStickerAJpegRepresentation(size: CGSize(width: 160.0, height: 160.0))
    }
    maybeFetched = postbox.mediaBox.cachedResourceRepresentation(resource, representation: representation, complete: false, fetch: false, attemptSynchronously: synchronousLoad)
    
    return maybeFetched
    |> take(1)
    |> mapToSignal { maybeData in
        if maybeData.complete {
            let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [])
            return .single(loadedData)
        } else {
            let fullSizeData = postbox.mediaBox.cachedResourceRepresentation(resource, representation: representation, complete: false)
            |> map { next in
                return ((next.size == 0 || !next.complete) ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: .mappedIfSafe), next.complete)
            }
            
            return Signal { subscriber in
                let fetch: Disposable? = nil
                let disposable = fullSizeData.start(next: { next in
                    subscriber.putNext(next.0)
                }, error: { _ in
                }, completed: {
                    subscriber.putCompletion()
                })
                
                return ActionDisposable {
                    fetch?.dispose()
                    disposable.dispose()
                }
            }
        }
    }
}

public func chatMessageAnimationData(mediaBox: MediaBox, resource: MediaResource, fitzModifier: EmojiFitzModifier? = nil, isVideo: Bool = false, width: Int, height: Int, synchronousLoad: Bool) -> Signal<MediaResourceData, NoError> {
    let representation: CachedMediaResourceRepresentation = isVideo ? CachedVideoStickerRepresentation(width: Int32(width), height: Int32(height)) : CachedAnimatedStickerRepresentation(width: Int32(width), height: Int32(height), fitzModifier: fitzModifier)
    let maybeFetched = mediaBox.cachedResourceRepresentation(resource, representation: representation, complete: false, fetch: false, attemptSynchronously: synchronousLoad)

    return maybeFetched
    |> take(1)
    |> mapToSignal { maybeData in
        if maybeData.complete {
            return .single(maybeData)
        } else {
            return mediaBox.cachedResourceRepresentation(resource, representation: representation, complete: false)
        }
    }
}

public func chatMessageAnimatedStickerBackingData(postbox: Postbox, fileReference: FileMediaReference, synchronousLoad: Bool) -> Signal<Tuple2<Data?, Bool>, NoError> {
    let resource = fileReference.media.resource
    let maybeFetched = postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false), attemptSynchronously: synchronousLoad)
    return maybeFetched
    |> take(1)
    |> mapToSignal { maybeData in
        if maybeData.complete {
            let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [])
            return .single(Tuple(loadedData, true))
        } else {
            let fullSizeData = postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false), attemptSynchronously: synchronousLoad)
            |> map { next -> Tuple2<Data?, Bool> in
                return Tuple(next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []), next.complete)
            }
            return fullSizeData
        }
    }
}

public func chatMessageLegacySticker(account: Account, file: TelegramMediaFile, small: Bool, fitSize: CGSize, fetched: Bool = false, onlyFullSize: Bool = false) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    let signal = chatMessageStickerDatas(postbox: account.postbox, file: file, small: small, fetched: fetched, onlyFullSize: onlyFullSize, synchronousLoad: false)
    return signal |> map { value in
        let fullSizeData = value._1
        let fullSizeComplete = value._2
        return { preArguments in
            var fullSizeImage: (UIImage, UIImage)?
            if let fullSizeData = fullSizeData, fullSizeComplete {
                if let image = imageFromAJpeg(data: fullSizeData) {
                    fullSizeImage = image
                }
            }
            
            if let fullSizeImage = fullSizeImage {
                var updatedFitSize = fitSize
                if updatedFitSize.width.isEqual(to: 1.0) {
                    updatedFitSize = fullSizeImage.0.size
                }
                
                let contextSize = fullSizeImage.0.size.aspectFitted(updatedFitSize)
                
                let arguments = TransformImageArguments(corners: preArguments.corners, imageSize: contextSize, boundingSize: contextSize, intrinsicInsets: preArguments.intrinsicInsets)
                
                let context = DrawingContext(size: arguments.drawingSize, clear: true)
                
                let thumbnailImage: CGImage? = nil
                
                var blurredThumbnailImage: UIImage?
                if let thumbnailImage = thumbnailImage {
                    let thumbnailSize = CGSize(width: thumbnailImage.width, height: thumbnailImage.height)
                    let thumbnailContextSize = thumbnailSize.aspectFitted(CGSize(width: 150.0, height: 150.0))
                    let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                    thumbnailContext.withFlippedContext { c in
                        c.interpolationQuality = .none
                        c.draw(thumbnailImage, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                    }
                    imageFastBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                    
                    blurredThumbnailImage = thumbnailContext.generateImage()
                }
                
                context.withFlippedContext { c in
                    c.setBlendMode(.copy)
                    if let blurredThumbnailImage = blurredThumbnailImage {
                        c.interpolationQuality = .low
                        c.draw(blurredThumbnailImage.cgImage!, in: arguments.drawingRect)
                    }
                    
                    if let cgImage = fullSizeImage.0.cgImage, let cgImageAlpha = fullSizeImage.1.cgImage {
                        c.setBlendMode(.normal)
                        c.interpolationQuality = .medium
                        
                        let mask = CGImage(maskWidth: cgImageAlpha.width, height: cgImageAlpha.height, bitsPerComponent: cgImageAlpha.bitsPerComponent, bitsPerPixel: cgImageAlpha.bitsPerPixel, bytesPerRow: cgImageAlpha.bytesPerRow, provider: cgImageAlpha.dataProvider!, decode: nil, shouldInterpolate: true)
                        
                        c.draw(cgImage.masking(mask!)!, in: arguments.drawingRect)
                    }
                }
                
                return context
            } else {
                return nil
            }
        }
    }
}

public func chatMessageSticker(account: Account, file: TelegramMediaFile, small: Bool, fetched: Bool = false, onlyFullSize: Bool = false, thumbnail: Bool = false, synchronousLoad: Bool = false) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    return chatMessageSticker(postbox: account.postbox, file: file, small: small, fetched: fetched, onlyFullSize: onlyFullSize, thumbnail: thumbnail, synchronousLoad: synchronousLoad)
}

public func chatMessageStickerPackThumbnail(postbox: Postbox, resource: MediaResource, animated: Bool = false, synchronousLoad: Bool = false, nilIfEmpty: Bool = false) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    let signal = chatMessageStickerPackThumbnailData(postbox: postbox, resource: resource, animated: animated, synchronousLoad: synchronousLoad)
    
    return signal
    |> map { fullSizeData in
        return { arguments in
            if nilIfEmpty {
                if fullSizeData == nil {
                    return nil
                }
            }
            
            let context = DrawingContext(size: arguments.drawingSize, scale: arguments.scale ?? 0.0, clear: arguments.emptyColor == nil)
            
            let drawingRect = arguments.drawingRect
            let fittedSize = arguments.imageSize
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            
            var fullSizeImage: (UIImage, UIImage)?
            if let fullSizeData = fullSizeData {
                if let image = imageFromAJpeg(data: fullSizeData) {
                    fullSizeImage = image
                }
            }
            
            context.withFlippedContext { c in
                if let color = arguments.emptyColor {
                    c.setBlendMode(.normal)
                    c.setFillColor(color.cgColor)
                    c.fill(drawingRect)
                } else {
                    c.setBlendMode(.copy)
                }
                
                if let fullSizeImage = fullSizeImage, let cgImage = fullSizeImage.0.cgImage, let cgImageAlpha = fullSizeImage.1.cgImage {
                    c.setBlendMode(.normal)
                    c.interpolationQuality = .medium
                    
                    let mask = CGImage(maskWidth: cgImageAlpha.width, height: cgImageAlpha.height, bitsPerComponent: cgImageAlpha.bitsPerComponent, bitsPerPixel: cgImageAlpha.bitsPerPixel, bytesPerRow: cgImageAlpha.bytesPerRow, provider: cgImageAlpha.dataProvider!, decode: nil, shouldInterpolate: true)
                    
                    c.draw(cgImage.masking(mask!)!, in: fittedRect)
                }
            }
            
            addCorners(context, arguments: arguments)
            
            return context
        }
    }
}

public func chatMessageSticker(postbox: Postbox, file: TelegramMediaFile, small: Bool, fetched: Bool = false, onlyFullSize: Bool = false, thumbnail: Bool = false, synchronousLoad: Bool = false) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    let signal: Signal<Tuple3<Data?, Data?, Bool>, NoError>
    if thumbnail {
        signal = chatMessageStickerThumbnailData(postbox: postbox, file: file, synchronousLoad: synchronousLoad)
        |> map { data -> Tuple3<Data?, Data?, Bool>in
            return Tuple3(data, nil, false)
        }
    } else {
        signal = chatMessageStickerDatas(postbox: postbox, file: file, small: small, fetched: fetched, onlyFullSize: onlyFullSize, synchronousLoad: synchronousLoad)
    }
    return signal |> map { value in
        let thumbnailData = value._0
        let fullSizeData = value._1
        let fullSizeComplete = value._2
        return { arguments in
            if thumbnailData == nil && fullSizeData == nil {
                return nil
            }
            
            if file.immediateThumbnailData != nil && thumbnailData == nil && fullSizeData == nil {
                return nil
            }
            
            let context = DrawingContext(size: arguments.drawingSize, scale: arguments.scale ?? 0.0, clear: arguments.emptyColor == nil)
            
            let drawingRect = arguments.drawingRect
            let fittedSize = arguments.imageSize
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            //let fittedRect = arguments.drawingRect
            
            var fullSizeImage: (UIImage, UIImage)?
            if let fullSizeData = fullSizeData, fullSizeComplete {
                if let image = imageFromAJpeg(data: fullSizeData) {
                    fullSizeImage = image
                }
            }
            
            var thumbnailImage: (UIImage, UIImage)?
            if fullSizeImage == nil, let thumbnailData = thumbnailData {
                if let image = imageFromAJpeg(data: thumbnailData) {
                    thumbnailImage = image
                }
            }
            
            var blurredThumbnailImage: UIImage?
            let thumbnailInset: CGFloat = 10.0
            if let thumbnailImage = thumbnailImage {
                let thumbnailSize = thumbnailImage.0.size
                var thumbnailContextSize = thumbnailSize.aspectFitted(CGSize(width: 150.0, height: 150.0))
                let thumbnailDrawingSize = thumbnailContextSize
                thumbnailContextSize.width += thumbnailInset * 2.0
                thumbnailContextSize.height += thumbnailInset * 2.0
                let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0, clear: true)
                thumbnailContext.withFlippedContext { c in
                    if let cgImage = thumbnailImage.0.cgImage, let cgImageAlpha = thumbnailImage.1.cgImage {
                        c.setBlendMode(.normal)
                        c.interpolationQuality = .medium
                        
                        let mask = CGImage(maskWidth: cgImageAlpha.width, height: cgImageAlpha.height, bitsPerComponent: cgImageAlpha.bitsPerComponent, bitsPerPixel: cgImageAlpha.bitsPerPixel, bytesPerRow: cgImageAlpha.bytesPerRow, provider: cgImageAlpha.dataProvider!, decode: nil, shouldInterpolate: true)
                        
                        c.draw(cgImage.masking(mask!)!, in: CGRect(origin: CGPoint(x: thumbnailInset, y: thumbnailInset), size: thumbnailDrawingSize))
                    }
                }
                stickerThumbnailAlphaBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                
                blurredThumbnailImage = thumbnailContext.generateImage()
            }
            
            context.withFlippedContext { c in
                if let color = arguments.emptyColor {
                    c.setBlendMode(.normal)
                    c.setFillColor(color.cgColor)
                    c.fill(drawingRect)
                } else {
                    c.setBlendMode(.copy)
                }
                
                if let blurredThumbnailImage = blurredThumbnailImage {
                    c.interpolationQuality = .low
                    let thumbnailScaledInset = thumbnailInset * (fittedRect.width / blurredThumbnailImage.size.width)
                    c.draw(blurredThumbnailImage.cgImage!, in: fittedRect.insetBy(dx: -thumbnailScaledInset, dy: -thumbnailScaledInset))
                }
                
                if let fullSizeImage = fullSizeImage, let cgImage = fullSizeImage.0.cgImage, let cgImageAlpha = fullSizeImage.1.cgImage {
                    c.setBlendMode(.normal)
                    c.interpolationQuality = .medium
                    
                    let mask = CGImage(maskWidth: cgImageAlpha.width, height: cgImageAlpha.height, bitsPerComponent: cgImageAlpha.bitsPerComponent, bitsPerPixel: cgImageAlpha.bitsPerPixel, bytesPerRow: cgImageAlpha.bytesPerRow, provider: cgImageAlpha.dataProvider!, decode: nil, shouldInterpolate: true)
                    
                    c.draw(cgImage.masking(mask!)!, in: fittedRect)
                }
            }
            
            return context
        }
    }
}

public func chatMessageAnimatedSticker(postbox: Postbox, file: TelegramMediaFile, small: Bool, size: CGSize, fitzModifier: EmojiFitzModifier? = nil, fetched: Bool = false, onlyFullSize: Bool = false, thumbnail: Bool = false, synchronousLoad: Bool = false) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    let signal: Signal<Tuple3<Data?, Data?, Bool>, NoError>
    if thumbnail {
        signal = chatMessageStickerThumbnailData(postbox: postbox, file: file, synchronousLoad: synchronousLoad)
        |> map { data -> Tuple3<Data?, Data?, Bool> in
            return Tuple(data, nil, false)
        }
    } else {
        signal = chatMessageAnimatedStickerDatas(postbox: postbox, file: file, small: small, size: size, fitzModifier: fitzModifier, fetched: fetched, onlyFullSize: onlyFullSize, synchronousLoad: synchronousLoad)
    }
    return signal
    |> map { value in
        let thumbnailData = value._0
        let fullSizeData = value._1
        let fullSizeComplete = value._2
        return { arguments in
            if thumbnailData == nil && fullSizeData == nil {
                return nil
            }
            
            let context = DrawingContext(size: arguments.drawingSize, scale: arguments.scale ?? 0.0, clear: true)
            
            let drawingRect = arguments.drawingRect
            let fittedSize = arguments.imageSize
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            
            var fullSizeImage: (UIImage, UIImage)?
            if let fullSizeData = fullSizeData, fullSizeComplete {
                if let image = imageFromAJpeg(data: fullSizeData) {
                    fullSizeImage = image
                }
            }
            
            var thumbnailImage: (UIImage, UIImage)?
            if fullSizeImage == nil, let thumbnailData = thumbnailData, fitzModifier == nil {
                if let image = imageFromAJpeg(data: thumbnailData) {
                    thumbnailImage = image
                }
            }
            
            var blurredThumbnailImage: UIImage?
            let thumbnailInset: CGFloat = 10.0
            if let thumbnailImage = thumbnailImage {
                let thumbnailSize = thumbnailImage.0.size
                var thumbnailContextSize = thumbnailSize.aspectFitted(CGSize(width: 150.0, height: 150.0))
                let thumbnailDrawingSize = thumbnailContextSize
                thumbnailContextSize.width += thumbnailInset * 2.0
                thumbnailContextSize.height += thumbnailInset * 2.0
                let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0, clear: true)
                thumbnailContext.withFlippedContext { c in
                    if let cgImage = thumbnailImage.0.cgImage, let cgImageAlpha = thumbnailImage.1.cgImage {
                        c.setBlendMode(.normal)
                        c.interpolationQuality = .medium
                        
                        let mask = CGImage(maskWidth: cgImageAlpha.width, height: cgImageAlpha.height, bitsPerComponent: cgImageAlpha.bitsPerComponent, bitsPerPixel: cgImageAlpha.bitsPerPixel, bytesPerRow: cgImageAlpha.bytesPerRow, provider: cgImageAlpha.dataProvider!, decode: nil, shouldInterpolate: true)
                        
                        c.draw(cgImage.masking(mask!)!, in: CGRect(origin: CGPoint(x: thumbnailInset, y: thumbnailInset), size: thumbnailDrawingSize))
                    }
                }
                stickerThumbnailAlphaBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                
                blurredThumbnailImage = thumbnailContext.generateImage()
            }
            
            context.withFlippedContext { c in
                if let color = arguments.emptyColor {
                    c.setBlendMode(.normal)
                    c.setFillColor(color.cgColor)
                    c.fill(drawingRect)
                } else {
                    c.setBlendMode(.copy)
                }
                
                if let blurredThumbnailImage = blurredThumbnailImage {
                    c.interpolationQuality = .low
                    let thumbnailFittedSize = blurredThumbnailImage.size.aspectFilled(fittedRect.size)
                    let thumbnailFittedRect = CGRect(origin: CGPoint(x: fittedRect.origin.x - (thumbnailFittedSize.width - fittedRect.width) / 2.0, y: fittedRect.origin.y - (thumbnailFittedSize.height - fittedRect.height) / 2.0), size: thumbnailFittedSize)
                    let thumbnailScaledInset = thumbnailInset * (fittedRect.width / blurredThumbnailImage.size.width)
                    c.draw(blurredThumbnailImage.cgImage!, in: thumbnailFittedRect.insetBy(dx: -thumbnailScaledInset, dy: -thumbnailScaledInset))
                }
                
                if let fullSizeImage = fullSizeImage, let cgImage = fullSizeImage.0.cgImage, let cgImageAlpha = fullSizeImage.1.cgImage {
                    c.setBlendMode(.normal)
                    c.interpolationQuality = .medium
                    
                    let mask = CGImage(maskWidth: cgImageAlpha.width, height: cgImageAlpha.height, bitsPerComponent: cgImageAlpha.bitsPerComponent, bitsPerPixel: cgImageAlpha.bitsPerPixel, bytesPerRow: cgImageAlpha.bytesPerRow, provider: cgImageAlpha.dataProvider!, decode: nil, shouldInterpolate: true)
                    
                    c.draw(cgImage.masking(mask!)!, in: fittedRect)
                }
            }
            
            return context
        }
    }
}
