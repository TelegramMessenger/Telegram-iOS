import Foundation
import Postbox
import SwiftSignalKit
import Display
import AVFoundation
import ImageIO
import TelegramUIPrivateModule
import TelegramCore

func largestRepresentationForPhoto(_ photo: TelegramMediaImage) -> TelegramMediaImageRepresentation? {
    return photo.representationForDisplayAtSize(CGSize(width: 1280.0, height: 1280.0))
}

private func chatMessagePhotoDatas(account: Account, photo: TelegramMediaImage, fullRepresentationSize: CGSize = CGSize(width: 1280.0, height: 1280.0), autoFetchFullSize: Bool = false) -> Signal<(Data?, Data?, Int), NoError> {
    if let smallestRepresentation = smallestImageRepresentation(photo.representations), let largestRepresentation = photo.representationForDisplayAtSize(fullRepresentationSize), let smallestSize = smallestRepresentation.size, let largestSize = largestRepresentation.size {
        let thumbnailResource = CloudFileMediaResource(location: smallestRepresentation.location, size: smallestSize)
        let fullSizeResource = CloudFileMediaResource(location: largestRepresentation.location, size: largestSize)
        
        let maybeFullSize = account.postbox.mediaBox.resourceData(fullSizeResource)
        
        let signal = maybeFullSize |> take(1) |> mapToSignal { maybeData -> Signal<(Data?, Data?, Int), NoError> in
            if maybeData.size >= fullSizeResource.size {
                let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [])
                
                return .single((nil, loadedData, fullSizeResource.size))
            } else {
                let fetchedThumbnail = account.postbox.mediaBox.fetchedResource(thumbnailResource)
                let fetchedFullSize = account.postbox.mediaBox.fetchedResource(fullSizeResource)
                
                let thumbnail = Signal<Data?, NoError> { subscriber in
                    let fetchedDisposable = fetchedThumbnail.start()
                    let thumbnailDisposable = account.postbox.mediaBox.resourceData(thumbnailResource).start(next: { next in
                        subscriber.putNext(next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []))
                    }, error: subscriber.putError, completed: subscriber.putCompletion)
                    
                    return ActionDisposable {
                        fetchedDisposable.dispose()
                        thumbnailDisposable.dispose()
                    }
                }
                
                let fullSizeData: Signal<Data?, NoError>
                
                if autoFetchFullSize {
                    fullSizeData = Signal<Data?, NoError> { subscriber in
                        let fetchedFullSizeDisposable = fetchedFullSize.start()
                        let fullSizeDisposable = account.postbox.mediaBox.resourceData(fullSizeResource).start(next: { next in
                            subscriber.putNext(next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []))
                        }, error: subscriber.putError, completed: subscriber.putCompletion)
                        
                        return ActionDisposable {
                            fetchedFullSizeDisposable.dispose()
                            fullSizeDisposable.dispose()
                        }
                    }
                } else {
                    fullSizeData = account.postbox.mediaBox.resourceData(fullSizeResource)
                        |> map { next -> Data? in
                            return next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: [])
                        }
                }
                
                
                return thumbnail |> mapToSignal { thumbnailData in
                    return fullSizeData |> map { fullSizeData in
                        return (thumbnailData, fullSizeData, fullSizeResource.size)
                    }
                }
            }
        } |> filter({ $0.0 != nil || $0.1 != nil })
        
        return signal
    } else {
        return .never()
    }
}

private func chatMessageFileDatas(account: Account, file: TelegramMediaFile, progressive: Bool = false) -> Signal<(Data?, (Data, String)?, Int), NoError> {
    if let smallestRepresentation = smallestImageRepresentation(file.previewRepresentations), let smallestSize = smallestRepresentation.size {
        let thumbnailResource = CloudFileMediaResource(location: smallestRepresentation.location, size: smallestSize)
        let fullSizeResource = CloudFileMediaResource(location: file.location, size: file.size)
        
        let maybeFullSize = account.postbox.mediaBox.resourceData(fullSizeResource)
        
        let signal = maybeFullSize |> take(1) |> mapToSignal { maybeData -> Signal<(Data?, (Data, String)?, Int), NoError> in
            if maybeData.size >= fullSizeResource.size {
                let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [])
                
                return .single((nil, loadedData == nil ? nil : (loadedData!, maybeData.path), fullSizeResource.size))
            } else {
                let fetchedThumbnail = account.postbox.mediaBox.fetchedResource(thumbnailResource)
                
                let thumbnail = Signal<Data?, NoError> { subscriber in
                    let fetchedDisposable = fetchedThumbnail.start()
                    let thumbnailDisposable = account.postbox.mediaBox.resourceData(thumbnailResource).start(next: { next in
                        subscriber.putNext(next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []))
                        }, error: subscriber.putError, completed: subscriber.putCompletion)
                    
                    return ActionDisposable {
                        fetchedDisposable.dispose()
                        thumbnailDisposable.dispose()
                    }
                }
                
                
                let fullSizeDataAndPath = account.postbox.mediaBox.resourceData(fullSizeResource, complete: !progressive) |> map { next -> (Data, String)? in
                    let data = next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: .mappedIfSafe)
                    return data == nil ? nil : (data!, next.path)
                }
                
                return thumbnail |> mapToSignal { thumbnailData in
                    return fullSizeDataAndPath |> map { dataAndPath in
                        return (thumbnailData, dataAndPath, fullSizeResource.size)
                    }
                }
            }
            } |> filter({ $0.0 != nil || $0.1 != nil })
        
        return signal
    } else {
        return .never()
    }
}

private enum Corner: Hashable {
    case TopLeft(Int), TopRight(Int), BottomLeft(Int), BottomRight(Int)
    
    var hashValue: Int {
        switch self {
            case let .TopLeft(radius):
                return radius | (1 << 24)
            case let .TopRight(radius):
                return radius | (2 << 24)
            case let .BottomLeft(radius):
                return radius | (3 << 24)
            case let .BottomRight(radius):
                return radius | (2 << 24)
        }
    }
    
    var radius: Int {
        switch self {
            case let .TopLeft(radius):
                return radius
            case let .TopRight(radius):
                return radius
            case let .BottomLeft(radius):
                return radius
            case let .BottomRight(radius):
                return radius
        }
    }
}

private func ==(lhs: Corner, rhs: Corner) -> Bool {
    switch lhs {
        case let .TopLeft(lhsRadius):
            switch rhs {
                case let .TopLeft(rhsRadius) where rhsRadius == lhsRadius:
                    return true
                default:
                    return false
            }
        case let .TopRight(lhsRadius):
            switch rhs {
                case let .TopRight(rhsRadius) where rhsRadius == lhsRadius:
                    return true
                default:
                    return false
            }
        case let .BottomLeft(lhsRadius):
            switch rhs {
                case let .BottomLeft(rhsRadius) where rhsRadius == lhsRadius:
                    return true
                default:
                    return false
            }
        case let .BottomRight(lhsRadius):
            switch rhs {
                case let .BottomRight(rhsRadius) where rhsRadius == lhsRadius:
                    return true
                default:
                    return false
            }
    }
}

private enum Tail: Hashable {
    case BottomLeft(Int)
    case BottomRight(Int)
    
    var hashValue: Int {
        switch self {
            case let .BottomLeft(radius):
                return radius | (1 << 24)
            case let .BottomRight(radius):
                return radius | (2 << 24)
        }
    }
    
    var radius: Int {
        switch self {
            case let .BottomLeft(radius):
                return radius
            case let .BottomRight(radius):
                return radius
        }
    }
}

private func ==(lhs: Tail, rhs: Tail) -> Bool {
    switch lhs {
        case let .BottomLeft(lhsRadius):
            switch rhs {
                case let .BottomLeft(rhsRadius) where rhsRadius == lhsRadius:
                    return true
                default:
                    return false
            }
        case let .BottomRight(lhsRadius):
            switch rhs {
                case let .BottomRight(rhsRadius) where rhsRadius == lhsRadius:
                    return true
                default:
                    return false
            }
    }
}

private var cachedCorners: [Corner: DrawingContext] = [:]
private let cachedCornersLock = SwiftSignalKit.Lock()
private var cachedTails: [Tail: DrawingContext] = [:]
private let cachedTailsLock = SwiftSignalKit.Lock()

private func cornerContext(_ corner: Corner) -> DrawingContext {
    var cached: DrawingContext?
    cachedCornersLock.locked {
        cached = cachedCorners[corner]
    }
    
    if let cached = cached {
        return cached
    } else {
        let context = DrawingContext(size: CGSize(width: CGFloat(corner.radius), height: CGFloat(corner.radius)), clear: true)
        
        context.withContext { c in
            c.setBlendMode(.copy)
            c.setFillColor(UIColor.black.cgColor)
            let rect: CGRect
            switch corner {
                case let .TopLeft(radius):
                    rect = CGRect(origin: CGPoint(), size: CGSize(width: CGFloat(radius << 1), height: CGFloat(radius << 1)))
                case let .TopRight(radius):
                    rect = CGRect(origin: CGPoint(x: -CGFloat(radius), y: 0.0), size: CGSize(width: CGFloat(radius << 1), height: CGFloat(radius << 1)))
                case let .BottomLeft(radius):
                    rect = CGRect(origin: CGPoint(x: 0.0, y: -CGFloat(radius)), size: CGSize(width: CGFloat(radius << 1), height: CGFloat(radius << 1)))
                case let .BottomRight(radius):
                    rect = CGRect(origin: CGPoint(x: -CGFloat(radius), y: -CGFloat(radius)), size: CGSize(width: CGFloat(radius << 1), height: CGFloat(radius << 1)))
            }
            c.fillEllipse(in: rect)
        }
        
        cachedCornersLock.locked {
            cachedCorners[corner] = context
        }
        return context
    }
}

private func tailContext(_ tail: Tail) -> DrawingContext {
    var cached: DrawingContext?
    cachedTailsLock.locked {
        cached = cachedTails[tail]
    }
    
    if let cached = cached {
        return cached
    } else {
        let context = DrawingContext(size: CGSize(width: CGFloat(tail.radius) + 3.0, height: CGFloat(tail.radius)), clear: true)
        
        context.withContext { c in
            c.setBlendMode(.copy)
            c.setFillColor(UIColor.black.cgColor)
            let rect: CGRect
            switch tail {
                case let .BottomLeft(radius):
                    rect = CGRect(origin: CGPoint(x: 3.0, y: -CGFloat(radius)), size: CGSize(width: CGFloat(radius << 1), height: CGFloat(radius << 1)))
                
                    c.move(to: CGPoint(x: 3.0, y: 0.0))
                    c.addLine(to: CGPoint(x: 3.0, y: 8.7))
                    c.addLine(to: CGPoint(x: 2.0, y: 11.7))
                    c.addLine(to: CGPoint(x: 1.5, y: 12.7))
                    c.addLine(to: CGPoint(x: 0.8, y: 13.7))
                    c.addLine(to: CGPoint(x: 0.2, y: 14.4))
                    c.addLine(to: CGPoint(x: 3.5, y: 13.8))
                    c.addLine(to: CGPoint(x: 5.0, y: 13.2))
                    c.addLine(to: CGPoint(x: 3.0 + CGFloat(radius) - 9.5, y: 11.5))
                    c.closePath()
                    c.fillPath()
                case let .BottomRight(radius):
                    rect = CGRect(origin: CGPoint(x: -CGFloat(radius) + 3.0, y: -CGFloat(radius)), size: CGSize(width: CGFloat(radius << 1), height: CGFloat(radius << 1)))
                
                    /*CGContextMoveToPoint(c, 3.0, 0.0)
                    CGContextAddLineToPoint(c, 3.0, 8.7)
                    CGContextAddLineToPoint(c, 2.0, 11.7)
                    CGContextAddLineToPoint(c, 1.5, 12.7)
                    CGContextAddLineToPoint(c, 0.8, 13.7)
                    CGContextAddLineToPoint(c, 0.2, 14.4)
                    CGContextAddLineToPoint(c, 3.5, 13.8)
                    CGContextAddLineToPoint(c, 5.0, 13.2)
                    CGContextAddLineToPoint(c, 3.0 + CGFloat(radius) - 9.5, 11.5)
                    CGContextClosePath(c)
                    CGContextFillPath(c)*/
            }
            c.fillEllipse(in: rect)
        }
        
        cachedCornersLock.locked {
            cachedTails[tail] = context
        }
        return context
    }
}

private func addCorners(_ context: DrawingContext, arguments: TransformImageArguments) {
    let corners = arguments.corners
    let drawingRect = arguments.drawingRect
    
    if case let .Corner(radius) = corners.topLeft, radius > CGFloat(FLT_EPSILON) {
        let corner = cornerContext(.TopLeft(Int(radius)))
        context.blt(corner, at: CGPoint(x: drawingRect.minX, y: drawingRect.minY))
    }
    
    if case let .Corner(radius) = corners.topRight, radius > CGFloat(FLT_EPSILON) {
        let corner = cornerContext(.TopRight(Int(radius)))
        context.blt(corner, at: CGPoint(x: drawingRect.maxX - radius, y: drawingRect.minY))
    }
    
    switch corners.bottomLeft {
        case let .Corner(radius):
            if radius > CGFloat(FLT_EPSILON) {
                let corner = cornerContext(.BottomLeft(Int(radius)))
                context.blt(corner, at: CGPoint(x: drawingRect.minX, y: drawingRect.maxY - radius))
            }
        case let .Tail(radius):
            if radius > CGFloat(FLT_EPSILON) {
                let tail = tailContext(.BottomLeft(Int(radius)))
                let color = context.colorAt(CGPoint(x: drawingRect.minX, y: drawingRect.maxY - 1.0))
                context.withContext { c in
                    c.setFillColor(color.cgColor)
                    c.fill(CGRect(x: 0.0, y: drawingRect.maxY - 6.0, width: 3.0, height: 6.0))
                }
                context.blt(tail, at: CGPoint(x: drawingRect.minX - 3.0, y: drawingRect.maxY - radius))
            }
        
    }
    
    switch corners.bottomRight {
        case let .Corner(radius):
            if radius > CGFloat(FLT_EPSILON) {
                let corner = cornerContext(.BottomRight(Int(radius)))
                context.blt(corner, at: CGPoint(x: drawingRect.maxX - radius, y: drawingRect.maxY - radius))
            }
        case let .Tail(radius):
            if radius > CGFloat(FLT_EPSILON) {
                let tail = tailContext(.BottomRight(Int(radius)))
                context.blt(tail, at: CGPoint(x: drawingRect.maxX - radius - 3.0, y: drawingRect.maxY - radius))
            }
    }
}

func chatMessagePhoto(account: Account, photo: TelegramMediaImage) -> Signal<(TransformImageArguments) -> DrawingContext, NoError> {
    let signal = chatMessagePhotoDatas(account: account, photo: photo)
    
    return signal |> map { (thumbnailData, fullSizeData, fullTotalSize) in
        return { arguments in
            assertNotOnMainThread()
            let context = DrawingContext(size: arguments.drawingSize, clear: true)
            
            let drawingRect = arguments.drawingRect
            let fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize).fitted(arguments.imageSize)
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            
            var fullSizeImage: CGImage?
            if let fullSizeData = fullSizeData {
                if fullSizeData.count >= fullTotalSize {
                    let options = NSMutableDictionary()
                    options.setValue(max(fittedSize.width * context.scale, fittedSize.height * context.scale) as NSNumber, forKey: kCGImageSourceThumbnailMaxPixelSize as String)
                    options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailFromImageAlways as String)
                    if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, nil), let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) {
                        fullSizeImage = image
                    }
                } else {
                    let imageSource = CGImageSourceCreateIncremental(nil)
                    CGImageSourceUpdateData(imageSource, fullSizeData as CFData, fullSizeData.count >= fullTotalSize)
                    
                    let options = NSMutableDictionary()
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                    if let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                        fullSizeImage = image
                    }
                }
            }
            
            var thumbnailImage: CGImage?
            if let thumbnailData = thumbnailData, let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                thumbnailImage = image
            }
            
            var blurredThumbnailImage: UIImage?
            if let thumbnailImage = thumbnailImage {
                let thumbnailSize = CGSize(width: thumbnailImage.width, height: thumbnailImage.height)
                let thumbnailContextSize = thumbnailSize.aspectFitted(CGSize(width: 150.0, height: 150.0))
                let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                thumbnailContext.withFlippedContext { c in
                    c.interpolationQuality = .none
                    c.draw(thumbnailImage, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                }
                telegramFastBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                
                blurredThumbnailImage = thumbnailContext.generateImage()
            }
            
            context.withFlippedContext { c in
                c.setBlendMode(.copy)
                if arguments.boundingSize != arguments.imageSize {
                    c.fill(arguments.drawingRect)
                }
                
                c.setBlendMode(.copy)
                if let blurredThumbnailImage = blurredThumbnailImage, let cgImage = blurredThumbnailImage.cgImage {
                    c.interpolationQuality = .low
                    c.draw(cgImage, in: fittedRect)
                    c.setBlendMode(.normal)
                }
                
                if let fullSizeImage = fullSizeImage {
                    c.interpolationQuality = .medium
                    c.draw(fullSizeImage, in: fittedRect)
                }
            }
            
            addCorners(context, arguments: arguments)
            
            return context
        }
    }
}

func mediaGridMessagePhoto(account: Account, photo: TelegramMediaImage) -> Signal<(TransformImageArguments) -> DrawingContext, NoError> {
    let signal = chatMessagePhotoDatas(account: account, photo: photo, fullRepresentationSize: CGSize(width: 127.0, height: 127.0), autoFetchFullSize: true)
    
    return signal |> map { (thumbnailData, fullSizeData, fullTotalSize) in
        return { arguments in
            assertNotOnMainThread()
            let context = DrawingContext(size: arguments.drawingSize, clear: true)
            
            let drawingRect = arguments.drawingRect
            let fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize).fitted(arguments.imageSize)
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            
            var fullSizeImage: CGImage?
            if let fullSizeData = fullSizeData {
                if fullSizeData.count >= fullTotalSize {
                    let options = NSMutableDictionary()
                    options.setValue(max(fittedSize.width * context.scale, fittedSize.height * context.scale) as NSNumber, forKey: kCGImageSourceThumbnailMaxPixelSize as String)
                    options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailFromImageAlways as String)
                    if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, nil), let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) {
                        fullSizeImage = image
                    }
                } else {
                    let imageSource = CGImageSourceCreateIncremental(nil)
                    CGImageSourceUpdateData(imageSource, fullSizeData as CFData, fullSizeData.count >= fullTotalSize)
                    
                    let options = NSMutableDictionary()
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                    if let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                        fullSizeImage = image
                    }
                }
            }
            
            var thumbnailImage: CGImage?
            if let thumbnailData = thumbnailData, let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                thumbnailImage = image
            }
            
            var blurredThumbnailImage: UIImage?
            if let thumbnailImage = thumbnailImage {
                let thumbnailSize = CGSize(width: thumbnailImage.width, height: thumbnailImage.height)
                let thumbnailContextSize = thumbnailSize.aspectFitted(CGSize(width: 150.0, height: 150.0))
                let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                thumbnailContext.withFlippedContext { c in
                    c.interpolationQuality = .none
                    c.draw(thumbnailImage, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                }
                telegramFastBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                
                blurredThumbnailImage = thumbnailContext.generateImage()
            }
            
            context.withFlippedContext { c in
                c.setBlendMode(.copy)
                if arguments.boundingSize != arguments.imageSize {
                    c.fill(arguments.drawingRect)
                }
                
                c.setBlendMode(.copy)
                if let blurredThumbnailImage = blurredThumbnailImage, let cgImage = blurredThumbnailImage.cgImage {
                    c.interpolationQuality = .low
                    c.draw(cgImage, in: fittedRect)
                    c.setBlendMode(.normal)
                }
                
                if let fullSizeImage = fullSizeImage {
                    c.interpolationQuality = .medium
                    c.draw(fullSizeImage, in: fittedRect)
                }
            }
            
            addCorners(context, arguments: arguments)
            
            return context
        }
    }
}

func chatMessagePhotoStatus(account: Account, photo: TelegramMediaImage) -> Signal<MediaResourceStatus, NoError> {
    if let largestRepresentation = largestRepresentationForPhoto(photo), let largestSize = largestRepresentation.size {
        let fullSizeResource = CloudFileMediaResource(location: largestRepresentation.location, size: largestSize)
        return account.postbox.mediaBox.resourceStatus(fullSizeResource)
    } else {
        return .never()
    }
}

func chatMessagePhotoInteractiveFetched(account: Account, photo: TelegramMediaImage) -> Signal<Void, NoError> {
    if let largestRepresentation = largestRepresentationForPhoto(photo), let largestSize = largestRepresentation.size {
        let fullSizeResource = CloudFileMediaResource(location: largestRepresentation.location, size: largestSize)
        return account.postbox.mediaBox.fetchedResource(fullSizeResource)
    } else {
        return .never()
    }
}

func chatMessagePhotoCancelInteractiveFetch(account: Account, photo: TelegramMediaImage) {
    if let largestRepresentation = largestRepresentationForPhoto(photo), let largestSize = largestRepresentation.size {
        let fullSizeResource = CloudFileMediaResource(location: largestRepresentation.location, size: largestSize)
        return account.postbox.mediaBox.cancelInteractiveResourceFetch(fullSizeResource)
    }
}

func chatWebpageSnippetPhotoData(account: Account, photo: TelegramMediaImage) -> Signal<Data?, NoError> {
    if let closestRepresentation = photo.representationForDisplayAtSize(CGSize(width: 120.0, height: 120.0)) {
        let resource = CloudFileMediaResource(location: closestRepresentation.location, size: closestRepresentation.size ?? 0)
        let resourceData = account.postbox.mediaBox.resourceData(resource) |> map { next in
            return next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: .mappedIfSafe)
        }
        
        return Signal { subscriber in
            let disposable = DisposableSet()
            disposable.add(resourceData.start(next: { data in
                subscriber.putNext(data)
            }, error: { error in
                subscriber.putError(error)
            }, completed: {
                subscriber.putCompletion()
            }))
            disposable.add(account.postbox.mediaBox.fetchedResource(resource).start())
            return disposable
        }
    } else {
        return .never()
    }
}

func chatWebpageSnippetPhoto(account: Account, photo: TelegramMediaImage) -> Signal<(TransformImageArguments) -> DrawingContext, NoError> {
    let signal = chatWebpageSnippetPhotoData(account: account, photo: photo)
    
    return signal |> map { fullSizeData in
        return { arguments in
            assertNotOnMainThread()
            let context = DrawingContext(size: arguments.drawingSize, clear: true)
            
            let drawingRect = arguments.drawingRect
            let fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize).fitted(arguments.imageSize)
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            
            var fullSizeImage: CGImage?
            if let fullSizeData = fullSizeData {
                let options = NSMutableDictionary()
                options.setValue(max(fittedSize.width * context.scale, fittedSize.height * context.scale) as NSNumber, forKey: kCGImageSourceThumbnailMaxPixelSize as String)
                options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailFromImageAlways as String)
                if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, nil), let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) {
                    fullSizeImage = image
                }
            }
            
            context.withFlippedContext { c in
                c.setBlendMode(.copy)
                if arguments.boundingSize.width > arguments.imageSize.width || arguments.boundingSize.height > arguments.imageSize.height {
                    c.fill(arguments.drawingRect)
                }
                
                if let fullSizeImage = fullSizeImage {
                    c.interpolationQuality = .medium
                    c.draw(fullSizeImage, in: fittedRect)
                }
            }
            
            addCorners(context, arguments: arguments)
            
            return context
        }
    }
}

func chatMessageVideo(account: Account, video: TelegramMediaFile) -> Signal<(TransformImageArguments) -> DrawingContext, NoError> {
    let signal = chatMessageFileDatas(account: account, file: video)
    
    return signal |> map { (thumbnailData, fullSizeDataAndPath, fullTotalSize) in
        return { arguments in
            assertNotOnMainThread()
            let context = DrawingContext(size: arguments.drawingSize, clear: true)
            if arguments.drawingSize.width.isLessThanOrEqualTo(0.0) || arguments.drawingSize.height.isLessThanOrEqualTo(0.0) {
                return context
            }
            
            let drawingRect = arguments.drawingRect
            let fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize).fitted(arguments.imageSize)
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            
            var fullSizeImage: CGImage?
            if let fullSizeDataAndPath = fullSizeDataAndPath {
                if fullSizeDataAndPath.0.count >= fullTotalSize {
                    if video.mimeType.hasPrefix("video/") {
                        let tempFilePath = NSTemporaryDirectory() + "\(arc4random()).mov"
                        
                        _ = try? FileManager.default.removeItem(atPath: tempFilePath)
                        _ = try? FileManager.default.linkItem(atPath: fullSizeDataAndPath.1, toPath: tempFilePath)
                        
                        let asset = AVAsset(url: URL(fileURLWithPath: tempFilePath))
                        let imageGenerator = AVAssetImageGenerator(asset: asset)
                        imageGenerator.maximumSize = CGSize(width: 800.0, height: 800.0)
                        imageGenerator.appliesPreferredTrackTransform = true
                        if let image = try? imageGenerator.copyCGImage(at: CMTime(seconds: 0.0, preferredTimescale: asset.duration.timescale), actualTime: nil) {
                            fullSizeImage = image
                        }
                    }
                    /*let options: [NSString: NSObject] = [
                        kCGImageSourceThumbnailMaxPixelSize: max(fittedSize.width * context.scale, fittedSize.height * context.scale),
                        kCGImageSourceCreateThumbnailFromImageAlways: true
                    ]
                    if let imageSource = CGImageSourceCreateWithData(fullSizeData, nil), image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options) {
                        fullSizeImage = image
                    }*/
                } else {
                    /*let imageSource = CGImageSourceCreateIncremental(nil)
                    CGImageSourceUpdateData(imageSource, fullSizeData as CFDataRef, fullSizeData.length >= fullTotalSize)
                    
                    var options: [NSString : NSObject!] = [:]
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                    if let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionaryRef) {
                        fullSizeImage = image
                    }*/
                }
            }
            
            var thumbnailImage: CGImage?
            if let thumbnailData = thumbnailData, let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                thumbnailImage = image
            }
            
            var blurredThumbnailImage: UIImage?
            if let thumbnailImage = thumbnailImage {
                let thumbnailSize = CGSize(width: thumbnailImage.width, height: thumbnailImage.height)
                let thumbnailContextSize = thumbnailSize.aspectFitted(CGSize(width: 150.0, height: 150.0))
                let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                thumbnailContext.withFlippedContext { c in
                    c.interpolationQuality = .none
                    c.draw(thumbnailImage, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                }
                telegramFastBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                
                blurredThumbnailImage = thumbnailContext.generateImage()
            }
            
            context.withFlippedContext { c in
                c.setBlendMode(.copy)
                if arguments.boundingSize != arguments.imageSize {
                    c.fill(arguments.drawingRect)
                }
                
                c.setBlendMode(.copy)
                if let blurredThumbnailImage = blurredThumbnailImage, let cgImage = blurredThumbnailImage.cgImage {
                    c.interpolationQuality = .low
                    c.draw(cgImage, in: fittedRect)
                }
                
                if let fullSizeImage = fullSizeImage {
                    c.setBlendMode(.normal)
                    c.interpolationQuality = .medium
                    c.draw(fullSizeImage, in: fittedRect)
                }
            }
            
            addCorners(context, arguments: arguments)
            
            return context
        }
    }
}

func chatMessageImageFile(account: Account, file: TelegramMediaFile, progressive: Bool = false) -> Signal<(TransformImageArguments) -> DrawingContext, NoError> {
    let signal = chatMessageFileDatas(account: account, file: file, progressive: progressive)
    
    return signal |> map { (thumbnailData, fullSizeDataAndPath, fullTotalSize) in
        return { arguments in
            assertNotOnMainThread()
            let context = DrawingContext(size: arguments.drawingSize, clear: true)
            
            let drawingRect = arguments.drawingRect
            let fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize).fitted(arguments.imageSize)
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            
            var fullSizeImage: CGImage?
            if let fullSizeDataAndPath = fullSizeDataAndPath {
                if fullSizeDataAndPath.0.count >= fullTotalSize {
                    let options = NSMutableDictionary()
                    options.setValue(max(fittedSize.width * context.scale, fittedSize.height * context.scale) as NSNumber, forKey: kCGImageSourceThumbnailMaxPixelSize as String)
                    options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailFromImageAlways as String)
                    if let imageSource = CGImageSourceCreateWithData(fullSizeDataAndPath.0 as CFData, nil), let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options) {
                        fullSizeImage = image
                    }
                } else if progressive {
                    let imageSource = CGImageSourceCreateIncremental(nil)
                    CGImageSourceUpdateData(imageSource, fullSizeDataAndPath.0 as CFData, fullSizeDataAndPath.0.count >= fullTotalSize)
                    
                    let options = NSMutableDictionary()
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                    if let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                        fullSizeImage = image
                    }
                }
            }
            
            var thumbnailImage: CGImage?
            if let thumbnailData = thumbnailData, let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                thumbnailImage = image
            }
            
            var blurredThumbnailImage: UIImage?
            if let thumbnailImage = thumbnailImage {
                let thumbnailSize = CGSize(width: thumbnailImage.width, height: thumbnailImage.height)
                let thumbnailContextSize = thumbnailSize.aspectFitted(CGSize(width: 150.0, height: 150.0))
                let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                thumbnailContext.withFlippedContext { c in
                    c.interpolationQuality = .none
                    c.draw(thumbnailImage, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                }
                telegramFastBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                
                blurredThumbnailImage = thumbnailContext.generateImage()
            }
            
            context.withFlippedContext { c in
                c.setBlendMode(.copy)
                if arguments.boundingSize != arguments.imageSize {
                    c.fill(arguments.drawingRect)
                }
                
                c.setBlendMode(.copy)
                if let blurredThumbnailImage = blurredThumbnailImage, let cgImage = blurredThumbnailImage.cgImage {
                    c.interpolationQuality = .low
                    c.draw(cgImage, in: fittedRect)
                }
                
                if let fullSizeImage = fullSizeImage {
                    c.setBlendMode(.normal)
                    c.interpolationQuality = .medium
                    c.draw(fullSizeImage, in: fittedRect)
                }
            }
            
            addCorners(context, arguments: arguments)
            
            return context
        }
    }
}

func chatMessageFileStatus(account: Account, file: TelegramMediaFile) -> Signal<MediaResourceStatus, NoError> {
    let fullSizeResource = CloudFileMediaResource(location: file.location, size: file.size)
    return account.postbox.mediaBox.resourceStatus(fullSizeResource)
}

func chatMessageFileInteractiveFetched(account: Account, file: TelegramMediaFile) -> Signal<Void, NoError> {
    let fullSizeResource = CloudFileMediaResource(location: file.location, size: file.size)
    return account.postbox.mediaBox.fetchedResource(fullSizeResource)
}

func chatMessageFileCancelInteractiveFetch(account: Account, file: TelegramMediaFile) {
    let fullSizeResource = CloudFileMediaResource(location: file.location, size: file.size)
    return account.postbox.mediaBox.cancelInteractiveResourceFetch(fullSizeResource)
}
