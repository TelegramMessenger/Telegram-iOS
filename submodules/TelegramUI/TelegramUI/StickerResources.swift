import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import Display
import TelegramUIPrivateModule
import TelegramCore

private func imageFromAJpeg(data: Data) -> (UIImage, UIImage)? {
    if let (colorData, alphaData) = data.withUnsafeBytes({ (bytes: UnsafePointer<UInt8>) -> (Data, Data)? in
        var colorSize: Int32 = 0
        memcpy(&colorSize, bytes, 4)
        if colorSize < 0 || Int(colorSize) > data.count - 8 {
            return nil
        }
        var alphaSize: Int32 = 0
        memcpy(&alphaSize, bytes.advanced(by: 4 + Int(colorSize)), 4)
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

func chatMessageStickerResource(file: TelegramMediaFile, small: Bool) -> MediaResource {
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
                    fetch = fetchedMediaResource(postbox: postbox, reference: stickerPackFileReference(file).resourceReference(resource)).start()
                }
                
                var fetchThumbnail: Disposable?
                if !thumbnailResource.id.isEqual(to: resource.id) {
                    fetchThumbnail = fetchedMediaResource(postbox: postbox, reference: stickerPackFileReference(file).resourceReference(thumbnailResource)).start()
                }
                let disposable = (combineLatest(thumbnailData, fullSizeData)
                |> map { thumbnailData, fullSizeData -> Tuple3<Data?, Data?, Bool> in
                    return Tuple(thumbnailData.complete ? try? Data(contentsOf: URL(fileURLWithPath: thumbnailData.path)) : nil, fullSizeData.0, fullSizeData.1)
                }).start(next: { next in
                    subscriber.putNext(next)
                }, error: { error in
                    subscriber.putError(error)
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

func chatMessageAnimatedStickerDatas(postbox: Postbox, file: TelegramMediaFile, small: Bool, size: CGSize, fetched: Bool, onlyFullSize: Bool, synchronousLoad: Bool) -> Signal<Tuple3<Data?, Data?, Bool>, NoError> {
    let thumbnailResource = chatMessageStickerResource(file: file, small: true)
    let resource = chatMessageStickerResource(file: file, small: small)
    
    let maybeFetched = postbox.mediaBox.cachedResourceRepresentation(resource, representation: CachedAnimatedStickerFirstFrameRepresentation(width: Int32(size.width), height: Int32(size.height)), complete: false, fetch: false, attemptSynchronously: synchronousLoad)
    
    return maybeFetched
    |> take(1)
    |> mapToSignal { maybeData in
        if maybeData.complete {
            let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [])
            
            return .single(Tuple(nil, loadedData, true))
        } else {
            let thumbnailData = postbox.mediaBox.cachedResourceRepresentation(thumbnailResource, representation: CachedStickerAJpegRepresentation(size: nil), complete: false)
            let fullSizeData = postbox.mediaBox.cachedResourceRepresentation(resource, representation: CachedAnimatedStickerFirstFrameRepresentation(width: Int32(size.width), height: Int32(size.height)), complete: onlyFullSize)
            |> map { next in
                return (next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: .mappedIfSafe), next.complete)
            }
            
            return Signal { subscriber in
                var fetch: Disposable?
                if fetched {
                    fetch = fetchedMediaResource(postbox: postbox, reference: stickerPackFileReference(file).resourceReference(resource)).start()
                }
                
                var fetchThumbnail: Disposable?
                if !thumbnailResource.id.isEqual(to: resource.id) {
                    fetchThumbnail = fetchedMediaResource(postbox: postbox, reference: stickerPackFileReference(file).resourceReference(thumbnailResource)).start()
                }
                let disposable = (combineLatest(thumbnailData, fullSizeData)
                    |> map { thumbnailData, fullSizeData -> Tuple3<Data?, Data?, Bool> in
                        return Tuple(thumbnailData.complete ? try? Data(contentsOf: URL(fileURLWithPath: thumbnailData.path)) : nil, fullSizeData.0, fullSizeData.1)
                    }).start(next: { next in
                        subscriber.putNext(next)
                    }, error: { error in
                        subscriber.putError(error)
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
                var fetchThumbnail = fetchedMediaResource(postbox: postbox, reference: stickerPackFileReference(file).resourceReference(thumbnailResource)).start()
                
                let disposable = (thumbnailData
                |> map { thumbnailData -> Data? in
                    return thumbnailData.complete ? try? Data(contentsOf: URL(fileURLWithPath: thumbnailData.path)) : nil
                }).start(next: { next in
                    subscriber.putNext(next)
                }, error: { error in
                    subscriber.putError(error)
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

private func chatMessageStickerPackThumbnailData(postbox: Postbox, representation: TelegramMediaImageRepresentation, synchronousLoad: Bool) -> Signal<Data?, NoError> {
    let resource = representation.resource
    let maybeFetched = postbox.mediaBox.cachedResourceRepresentation(resource, representation: CachedStickerAJpegRepresentation(size: CGSize(width: 160.0, height: 160.0)), complete: false, fetch: false, attemptSynchronously: synchronousLoad)
    
    return maybeFetched
    |> take(1)
    |> mapToSignal { maybeData in
        if maybeData.complete {
            let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [])
            return .single(loadedData)
        } else {
            let fullSizeData = postbox.mediaBox.cachedResourceRepresentation(resource, representation: CachedStickerAJpegRepresentation(size: CGSize(width: 160.0, height: 160.0)), complete: false)
            |> map { next in
                return ((next.size == 0 || !next.complete) ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: .mappedIfSafe), next.complete)
            }
            
            return Signal { subscriber in
                let fetch: Disposable? = nil
                let disposable = fullSizeData.start(next: { next in
                    subscriber.putNext(next.0)
                }, error: { error in
                    subscriber.putError(error)
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

func chatMessageAnimationData(postbox: Postbox, resource: MediaResource, width: Int, height: Int, synchronousLoad: Bool) -> Signal<MediaResourceData, NoError> {
    let maybeFetched = postbox.mediaBox.cachedResourceRepresentation(resource, representation: CachedAnimatedStickerRepresentation(width: Int32(width), height: Int32(height)), complete: false, fetch: false, attemptSynchronously: synchronousLoad)
    
    return maybeFetched
    |> take(1)
    |> mapToSignal { maybeData in
        if maybeData.complete {
            return .single(maybeData)
        } else {
            return postbox.mediaBox.cachedResourceRepresentation(resource, representation: CachedAnimatedStickerRepresentation(width: Int32(width), height: Int32(height)), complete: false)
        }
    }
}

func chatMessageAnimatedStrickerBackingData(postbox: Postbox, fileReference: FileMediaReference, synchronousLoad: Bool) -> Signal<Tuple2<Data?, Bool>, NoError> {
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

func chatMessageLegacySticker(account: Account, file: TelegramMediaFile, small: Bool, fitSize: CGSize, fetched: Bool = false, onlyFullSize: Bool = false) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    let signal = chatMessageStickerDatas(postbox: account.postbox, file: file, small: small, fetched: fetched, onlyFullSize: onlyFullSize, synchronousLoad: false)
    return signal |> map { value in
        let thumbnailData = value._0
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

public func chatMessageStickerPackThumbnail(postbox: Postbox, representation: TelegramMediaImageRepresentation, synchronousLoad: Bool = false) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    let signal = chatMessageStickerPackThumbnailData(postbox: postbox, representation: representation, synchronousLoad: synchronousLoad)
    
    return signal
    |> map { fullSizeData in
        return { arguments in
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

public func chatMessageAnimatedSticker(postbox: Postbox, file: TelegramMediaFile, small: Bool, size: CGSize, fetched: Bool = false, onlyFullSize: Bool = false, thumbnail: Bool = false, synchronousLoad: Bool = false) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    let signal: Signal<Tuple3<Data?, Data?, Bool>, NoError>
    if thumbnail {
        signal = chatMessageStickerThumbnailData(postbox: postbox, file: file, synchronousLoad: synchronousLoad)
        |> map { data -> Tuple3<Data?, Data?, Bool> in
            return Tuple(data, nil, false)
        }
    } else {
        signal = chatMessageAnimatedStickerDatas(postbox: postbox, file: file, small: small, size: size, fetched: fetched, onlyFullSize: onlyFullSize, synchronousLoad: synchronousLoad)
    }
    return signal
    |> map { value in
        let thumbnailData = value._0
        let fullSizeData = value._1
        let fullSizeComplete = value._2
        return { arguments in
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
