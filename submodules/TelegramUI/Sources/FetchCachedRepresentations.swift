import Foundation
import LottieSettings
import UIKit
import Postbox
import SwiftSignalKit
import TelegramCore
import ImageIO
import UniformTypeIdentifiers
import Display
import AVFoundation
import WebPBinding
import Lottie
import MediaResources
import PhotoResources
import LocationResources
import ImageBlur
import TelegramAnimatedStickerNode
import WallpaperResources
import GZip
import TelegramUniversalVideoContent
import GradientBackground
import LegacyImpl
import UniversalMediaPlayer
import RangeSet

// The media-representation pipeline has an Account but no AccountContext, so
// the backend is read straight from app configuration — the same shape
// TelegramAccountAuxiliaryMethods uses for
// ios_killswitch_disable_modern_video_pipeline. The Debug Settings switch is
// deliberately not consulted here: there is no SharedAccountContext on this
// path, and a cached representation outlives the toggle anyway.
private func lottieRenderingSettings(postbox: Postbox) -> Signal<LottieRenderingSettings, NoError> {
    return postbox.transaction { transaction -> LottieRenderingSettings in
        let appConfiguration = currentAppConfiguration(transaction: transaction)
        if let data = appConfiguration.data, let _ = data["ios_killswitch_disable_tlottie"] {
            return LottieRenderingSettings(backend: .rlottie)
        }
        return LottieRenderingSettings(backend: .tlottie)
    }
}

public func fetchCachedResourceRepresentation(account: Account, resource: MediaResource, representation: CachedMediaResourceRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    if let representation = representation as? CachedStickerAJpegRepresentation {
        return account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            if !data.complete {
                return .complete()
            }
            return fetchCachedStickerAJpegRepresentation(resource: resource, resourceData: data, representation: representation)
        }
    } else if let representation = representation as? CachedScaledImageRepresentation {
        return account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            if !data.complete {
                return .complete()
            }
            return fetchCachedScaledImageRepresentation(resource: resource, resourceData: data, representation: representation)
        }
    } else if let _ = representation as? CachedVideoFirstFrameRepresentation {
        return Signal { subscriber in
            if let size = resource.size {
                let videoSource = UniversalSoftwareVideoSource(mediaBox: account.postbox.mediaBox, source: .direct(resource: resource, size: size), automaticallyFetchHeader: false, hintVP9: false)
                let disposable = videoSource.takeFrame(at: 0.0).start(next: { value in
                    switch value {
                    case let .image(image):
                        if let image {
                            if let imageData = image.jpegData(compressionQuality: 0.6) {
                                subscriber.putNext(.data(imageData))
                                subscriber.putNext(.done)
                                subscriber.putCompletion()
                            }
                        }
                    case .waitingForData:
                        break
                    }
                })
                
                subscriber.keepAlive(videoSource)
                
                return ActionDisposable {
                    disposable.dispose()
                }
            } else {
                return EmptyDisposable
            }
        }
    } else if let _ = representation as? CachedVideoPrefixFirstFrameRepresentation {
        return Signal { subscriber in
            if let size = resource.size {
                let videoSource = UniversalSoftwareVideoSource(mediaBox: account.postbox.mediaBox, source: .direct(resource: resource, size: size), automaticallyFetchHeader: false, hintVP9: false)
                let disposable = videoSource.takeFrame(at: 0.0).start(next: { value in
                    switch value {
                    case let .image(image):
                        if let image {
                            if let imageData = image.jpegData(compressionQuality: 0.6) {
                                subscriber.putNext(.data(imageData))
                                subscriber.putNext(.done)
                                subscriber.putCompletion()
                            }
                        }
                    case .waitingForData:
                        break
                    }
                })
                
                subscriber.keepAlive(videoSource)
                
                /*let reader = FFMpegFileReader(source: .resource(mediaBox: account.postbox.mediaBox, resource: resource, resourceSize: size, mappedRanges: [0 ..< size]), useHardwareAcceleration: false, selectedStream: .mediaType(.video), seek: nil, maxReadablePts: nil)
                reader?.readFrame()
                
                print("ready to fetch \(representation.prefixLength)")*/
                
                return ActionDisposable {
                    disposable.dispose()
                }
            }
            
            /*let disposable = (account.postbox.mediaBox.resourceRangesStatus(resource)
            |> filter { ranges in
                return ranges.isSuperset(of: RangeSet(0 ..< Int64(representation.prefixLength)))
            }
            |> take(1)).start(next: { _ in
            })
            
            return ActionDisposable {
                disposable.dispose()
            }*/
            return EmptyDisposable
        }
    } else if let representation = representation as? CachedScaledVideoFirstFrameRepresentation {
        return account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            if !data.complete {
                return .complete()
            }
            return fetchCachedScaledVideoFirstFrameRepresentation(account: account, resource: resource, resourceData: data, representation: representation)
        }
    } else if let representation = representation as? CachedBlurredWallpaperRepresentation {
        return account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            if !data.complete {
                return .complete()
            }
            return fetchCachedBlurredWallpaperRepresentation(resource: resource, resourceData: data, representation: representation)
        }
    } else if let representation = representation as? CachedAlbumArtworkRepresentation {
        return account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            if data.complete, let fileData = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
                return fetchCachedAlbumArtworkRepresentation(resource: resource, data: fileData, representation: representation)
                |> `catch` { _ -> Signal<CachedMediaResourceRepresentationResult, NoError> in
                    return .complete()
                }
            } else if let size = resource.size {
                return account.postbox.mediaBox.resourceData(resource, size: size, in: 0 ..< min(size, 256 * 1024))
                |> mapToSignal { result -> Signal<CachedMediaResourceRepresentationResult, NoError> in
                    let (data, _) = result
                    return fetchCachedAlbumArtworkRepresentation(resource: resource, data: data, representation: representation)
                    |> `catch` { error -> Signal<CachedMediaResourceRepresentationResult, NoError> in
                        switch error {
                            case let .moreDataNeeded(targetSize):
                                return account.postbox.mediaBox.resourceData(resource, size: size, in: 0 ..< min(size, Int64(targetSize)))
                                |> mapToSignal { result ->
                                    Signal<CachedMediaResourceRepresentationResult, NoError> in
                                    let (data, _) = result
                                    return fetchCachedAlbumArtworkRepresentation(resource: resource, data: data, representation: representation)
                                    |> `catch` { error -> Signal<CachedMediaResourceRepresentationResult, NoError> in
                                        return .complete()
                                    }
                                }
                        }
                    }
                }
            } else {
                return .complete()
            }
        }
    } else if let representation = representation as? CachedAnimatedStickerRepresentation {
        return lottieRenderingSettings(postbox: account.postbox)
        |> mapToSignal { lottieSettings -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            return account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
            |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
                if !data.complete {
                    return .complete()
                }
                return fetchAnimatedStickerRepresentation(resource: resource, resourceData: data, representation: representation, lottieSettings: lottieSettings)
            }
        }
    } else if let representation = representation as? CachedVideoStickerRepresentation {
        return account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            if !data.complete {
                return .complete()
            }
            return fetchVideoStickerRepresentation(resource: resource, resourceData: data, representation: representation)
        }
    } else if let representation = representation as? CachedAnimatedStickerFirstFrameRepresentation {
        return lottieRenderingSettings(postbox: account.postbox)
        |> mapToSignal { lottieSettings -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            return account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
            |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
                if !data.complete {
                    return .complete()
                }
                return fetchAnimatedStickerFirstFrameRepresentation(resource: resource, resourceData: data, representation: representation, lottieSettings: lottieSettings)
            }
        }
    } else if let resource = resource as? YoutubeEmbedStoryboardMediaResource, let _ = representation as? YoutubeEmbedStoryboardMediaResourceRepresentation {
        return fetchYoutubeEmbedStoryboardResource(resource: resource)
    } else if let representation = representation as? CachedPreparedPatternWallpaperRepresentation {
        return account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            if !data.complete {
                return .complete()
            }
            return fetchPreparedPatternWallpaperRepresentation(resource: resource, resourceData: data, representation: representation)
        }
    } else if let representation = representation as? CachedPreparedSvgRepresentation {
        return account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            if !data.complete {
                return .complete()
            }
            return fetchPreparedSvgRepresentation(resource: resource, resourceData: data, representation: representation)
        }
    }
    return .never()
}

private func videoFirstFrameData(account: Account, resource: MediaResource, chunkSize: Int64) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    if let size = resource.size {
        return account.postbox.mediaBox.resourceData(resource, size: size, in: 0 ..< min(size, chunkSize))
        |> mapToSignal { _ -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            return account.postbox.mediaBox.resourceData(resource, option: .incremental(waitUntilFetchStatus: false), attemptSynchronously: false)
                |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
                    return fetchCachedVideoFirstFrameRepresentation(resource: resource, resourceData: data)
                    |> `catch` { _ -> Signal<CachedMediaResourceRepresentationResult, NoError> in
                        if chunkSize > size {
                            return .complete()
                        } else {
                            return videoFirstFrameData(account: account, resource: resource, chunkSize: chunkSize + chunkSize)
                        }
                    }
            }
        }
    } else {
        return .complete()
    }
}

private func fetchCachedStickerAJpegRepresentation(resource: MediaResource, resourceData: MediaResourceData, representation: CachedStickerAJpegRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal({ subscriber in
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
            var image: UIImage?
            if let webpImage = WebP.convert(fromWebP: data) {
                image = webpImage
            } else if let pngImage = UIImage(data: data) {
                image = pngImage
            }
            if let image = image {
                let path = NSTemporaryDirectory() + "\(Int64.random(in: Int64.min ... Int64.max))"
                let url = URL(fileURLWithPath: path)
                
                let colorData = NSMutableData()
                let alphaData = NSMutableData()
                
                let size = representation.size != nil ? image.size.aspectFitted(representation.size!) : CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
                
                let colorImage: UIImage?
                if let _ = representation.size {
                    colorImage = generateImage(size, contextGenerator: { size, context in
                        context.setBlendMode(.copy)
                        context.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: size))
                    }, scale: 1.0)
                } else {
                    colorImage = image
                }
                
                let alphaImage = generateImage(size, contextGenerator: { size, context in
                    context.setFillColor(UIColor.white.cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: size))
                    if let colorImage = colorImage {
                        context.clip(to: CGRect(origin: CGPoint(), size: size), mask: colorImage.cgImage!)
                    }
                    context.setFillColor(UIColor.black.cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: size))
                }, scale: 1.0)
                
                if let alphaImage = alphaImage, let colorDestination = CGImageDestinationCreateWithData(colorData as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil), let alphaDestination = CGImageDestinationCreateWithData(alphaData as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) {
                    CGImageDestinationSetProperties(colorDestination, NSDictionary() as CFDictionary)
                    CGImageDestinationSetProperties(alphaDestination, NSDictionary() as CFDictionary)
                    
                    let colorQuality: Float
                    let alphaQuality: Float
                    if representation.size == nil {
                        colorQuality = 0.6
                        alphaQuality = 0.6
                    } else {
                        colorQuality = 0.5
                        alphaQuality = 0.4
                    }
                    
                    let options = NSMutableDictionary()
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    
                    let optionsAlpha = NSMutableDictionary()
                    optionsAlpha.setObject(alphaQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    
                    if let colorImage = colorImage {
                        CGImageDestinationAddImage(colorDestination, colorImage.cgImage!, options as CFDictionary)
                    }
                    CGImageDestinationAddImage(alphaDestination, alphaImage.cgImage!, optionsAlpha as CFDictionary)
                    if CGImageDestinationFinalize(colorDestination) && CGImageDestinationFinalize(alphaDestination) {
                        let finalData = NSMutableData()
                        var colorSize: Int32 = Int32(colorData.length)
                        finalData.append(&colorSize, length: 4)
                        finalData.append(colorData as Data)
                        var alphaSize: Int32 = Int32(alphaData.length)
                        finalData.append(&alphaSize, length: 4)
                        finalData.append(alphaData as Data)
                        
                        let _ = try? finalData.write(to: url, options: [.atomic])
                        
                        subscriber.putNext(.temporaryPath(path))
                        subscriber.putCompletion()
                    }
                }
            }
        }
        return EmptyDisposable
    }) |> runOn(Queue.concurrentDefaultQueue())
}

private func fetchCachedScaledImageRepresentation(resource: MediaResource, resourceData: MediaResourceData, representation: CachedScaledImageRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal({ subscriber in
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
            if let image = UIImage(data: data) {
                let path = NSTemporaryDirectory() + "\(Int64.random(in: Int64.min ... Int64.max))"
                let url = URL(fileURLWithPath: path)

                let size: CGSize
                switch representation.mode {
                    case .fill:
                        size = representation.size
                    case .aspectFit:
                        size = image.size.fitted(representation.size)
                }
                
                let colorImage = generateImage(size, contextGenerator: { size, context in
                    context.setBlendMode(.copy)
                    drawImage(context: context, image: image.cgImage!, orientation: image.imageOrientation, in: CGRect(origin: CGPoint(), size: size))
                }, scale: 1.0)!
                
                if let colorDestination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) {
                    CGImageDestinationSetProperties(colorDestination, NSDictionary() as CFDictionary)
                    
                    let colorQuality: Float = 0.5
                    
                    let options = NSMutableDictionary()
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    
                    CGImageDestinationAddImage(colorDestination, colorImage.cgImage!, options as CFDictionary)
                    if CGImageDestinationFinalize(colorDestination) {
                        subscriber.putNext(.temporaryPath(path))
                        subscriber.putCompletion()
                    }
                }
            }
        }
        return EmptyDisposable
    }) |> runOn(Queue.concurrentDefaultQueue())
}

func generateVideoFirstFrame(_ path: String, maxDimensions: CGSize) -> UIImage? {
    let tempFilePath = NSTemporaryDirectory() + "\(arc4random()).mov"
    
    do {
        let _ = try? FileManager.default.removeItem(atPath: tempFilePath)
        try FileManager.default.linkItem(atPath: path, toPath: tempFilePath)
        
        let asset = AVAsset(url: URL(fileURLWithPath: tempFilePath))
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.maximumSize = maxDimensions
        imageGenerator.appliesPreferredTrackTransform = true
        let fullSizeImage = try imageGenerator.copyCGImage(at: CMTime(seconds: 0.0, preferredTimescale: asset.duration.timescale), actualTime: nil)
        let _ = try? FileManager.default.removeItem(atPath: tempFilePath)
        return UIImage(cgImage: fullSizeImage)
    } catch {
        return nil
    }
}

public enum FetchVideoFirstFrameError {
    case generic
}

private func fetchCachedVideoFirstFrameRepresentation(resource: MediaResource, resourceData: MediaResourceData) -> Signal<CachedMediaResourceRepresentationResult, FetchVideoFirstFrameError> {
    return Signal { subscriber in
            let tempFilePath = NSTemporaryDirectory() + "\(arc4random()).mov"
            do {
                let _ = try? FileManager.default.removeItem(atPath: tempFilePath)
                try FileManager.default.linkItem(atPath: resourceData.path, toPath: tempFilePath)
                
                let asset = AVAsset(url: URL(fileURLWithPath: tempFilePath))
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.maximumSize = CGSize(width: 800.0, height: 800.0)
                imageGenerator.appliesPreferredTrackTransform = true
                
                let fullSizeImage = try imageGenerator.copyCGImage(at: CMTime(seconds: 0.0, preferredTimescale: asset.duration.timescale), actualTime: nil)
                
                let path = NSTemporaryDirectory() + "\(Int64.random(in: Int64.min ... Int64.max))"
                let url = URL(fileURLWithPath: path)
                
                if let colorDestination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) {
                    CGImageDestinationSetProperties(colorDestination, NSDictionary() as CFDictionary)
                    
                    let colorQuality: Float = 0.6
                    
                    let options = NSMutableDictionary()
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    
                    CGImageDestinationAddImage(colorDestination, fullSizeImage, options as CFDictionary)
                    if CGImageDestinationFinalize(colorDestination) {
                        subscriber.putNext(.temporaryPath(path))
                        subscriber.putCompletion()
                    }
                }
                
                let _ = try? FileManager.default.removeItem(atPath: tempFilePath)
            } catch  _ {
                let _ = try? FileManager.default.removeItem(atPath: tempFilePath)
                subscriber.putError(.generic)
                subscriber.putCompletion()
            }
        return EmptyDisposable
    } |> runOn(Queue.concurrentDefaultQueue())
}

private func fetchCachedScaledVideoFirstFrameRepresentation(account: Account, resource: MediaResource, resourceData: MediaResourceData, representation: CachedScaledVideoFirstFrameRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return account.postbox.mediaBox.cachedResourceRepresentation(resource, representation: CachedVideoFirstFrameRepresentation(), complete: true)
    |> mapToSignal { firstFrame -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            return Signal({ subscriber in
                if let data = try? Data(contentsOf: URL(fileURLWithPath: firstFrame.path), options: [.mappedIfSafe]) {
                    if let image = UIImage(data: data) {
                        let path = NSTemporaryDirectory() + "\(Int64.random(in: Int64.min ... Int64.max))"
                        let url = URL(fileURLWithPath: path)
                        
                        let size = representation.size
                        
                        let colorImage = generateImage(size, contextGenerator: { size, context in
                            context.setBlendMode(.copy)
                            context.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: size))
                        }, scale: 1.0)!
                        
                        if let colorDestination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) {
                            CGImageDestinationSetProperties(colorDestination, NSDictionary() as CFDictionary)
                            
                            let colorQuality: Float = 0.5
                            
                            let options = NSMutableDictionary()
                            options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                            
                            CGImageDestinationAddImage(colorDestination, colorImage.cgImage!, options as CFDictionary)
                            if CGImageDestinationFinalize(colorDestination) {
                                subscriber.putNext(.temporaryPath(path))
                                subscriber.putCompletion()
                            }
                        }
                    }
                }
                return EmptyDisposable
            }) |> runOn(Queue.concurrentDefaultQueue())
    }
}

private func fetchCachedBlurredWallpaperRepresentation(resource: MediaResource, resourceData: MediaResourceData, representation: CachedBlurredWallpaperRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal({ subscriber in
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
            if let image = UIImage(data: data) {
                let path = NSTemporaryDirectory() + "\(Int64.random(in: Int64.min ... Int64.max))"
                let url = URL(fileURLWithPath: path)
                
                if let colorImage = blurredImage(image, radius: 30.0), let colorDestination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) {
                    CGImageDestinationSetProperties(colorDestination, NSDictionary() as CFDictionary)

                    let colorQuality: Float = 0.5
                    
                    let options = NSMutableDictionary()
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    
                    CGImageDestinationAddImage(colorDestination, colorImage.cgImage!, options as CFDictionary)
                    if CGImageDestinationFinalize(colorDestination) {
                        subscriber.putNext(.temporaryPath(path))
                        subscriber.putCompletion()
                    }
                }
            }
        }
        return EmptyDisposable
    }) |> runOn(Queue.concurrentDefaultQueue())
}

public func fetchCachedSharedResourceRepresentation(accountManager: AccountManager<TelegramAccountManagerTypes>, resource: MediaResource, representation: CachedMediaResourceRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    if let representation = representation as? CachedScaledImageRepresentation {
        return accountManager.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            if !data.complete {
                return .complete()
            }
            return fetchCachedScaledImageRepresentation(resource: resource, resourceData: data, representation: representation)
        }
    } else if let representation = representation as? CachedBlurredWallpaperRepresentation {
        return accountManager.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            if !data.complete {
                return .complete()
            }
            return fetchCachedBlurredWallpaperRepresentation(resource: resource, resourceData: data, representation: representation)
        }
    } else {
        return .never()
    }
}

public enum FetchAlbumArtworkError {
    case moreDataNeeded(Int)
}

private func fetchCachedAlbumArtworkRepresentation(resource: MediaResource, data: Data, representation: CachedAlbumArtworkRepresentation) -> Signal<CachedMediaResourceRepresentationResult, FetchAlbumArtworkError> {
    return Signal({ subscriber in
        let result = readAlbumArtworkData(data)
        switch result {
            case let .artworkData(data):
                if let image = UIImage(data: data) {
                    let path = NSTemporaryDirectory() + "\(Int64.random(in: Int64.min ... Int64.max))"
                    let url = URL(fileURLWithPath: path)
                    
                    var size = image.size
                    if let targetSize = representation.size {
                        size = size.aspectFilled(targetSize)
                    }
                    
                    let colorImage = generateImage(size, contextGenerator: { size, context in
                        context.setBlendMode(.copy)
                        drawImage(context: context, image: image.cgImage!, orientation: image.imageOrientation, in: CGRect(origin: CGPoint(), size: size))
                    })!
                    
                    if let colorDestination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) {
                        CGImageDestinationSetProperties(colorDestination, NSDictionary() as CFDictionary)
                        
                        let colorQuality: Float = 0.5
                        
                        let options = NSMutableDictionary()
                        options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                        
                        CGImageDestinationAddImage(colorDestination, colorImage.cgImage!, options as CFDictionary)
                        if CGImageDestinationFinalize(colorDestination) {
                            subscriber.putNext(.temporaryPath(path))
                        }
                    }
                }
            case let .moreDataNeeded(size):
                subscriber.putError(.moreDataNeeded(size))
            default:
                break
        }
        subscriber.putCompletion()
        return EmptyDisposable
    }) |> runOn(Queue.concurrentDefaultQueue())
}

private func fetchAnimatedStickerFirstFrameRepresentation(resource: MediaResource, resourceData: MediaResourceData, representation: CachedAnimatedStickerFirstFrameRepresentation, lottieSettings: LottieRenderingSettings) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal({ subscriber in
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
            return fetchCompressedLottieFirstFrameAJpeg(data: data, size: CGSize(width: CGFloat(representation.width), height: CGFloat(representation.height)), fitzModifier: representation.fitzModifier, cacheKey: "\(resource.id.stringRepresentation)-\(representation.uniqueId)", lottieSettings: lottieSettings).start(next: { file in
                subscriber.putNext(.tempFile(file))
                subscriber.putCompletion()
            })
        } else {
            return EmptyDisposable
        }
    })
    |> runOn(Queue.concurrentDefaultQueue())
}

private func fetchAnimatedStickerRepresentation(resource: MediaResource, resourceData: MediaResourceData, representation: CachedAnimatedStickerRepresentation, lottieSettings: LottieRenderingSettings) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal({ subscriber in
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
            return cacheAnimatedStickerFrames(data: data, size: CGSize(width: CGFloat(representation.width), height: CGFloat(representation.height)), fitzModifier: representation.fitzModifier, cacheKey: "\(resource.id.stringRepresentation)-\(representation.uniqueId)", lottieSettings: lottieSettings).start(next: { value in
                subscriber.putNext(value)
            }, completed: {
                subscriber.putCompletion()
            })
        } else {
            return EmptyDisposable
        }
    })
    |> runOn(Queue.concurrentDefaultQueue())
}

private func fetchVideoStickerRepresentation(resource: MediaResource, resourceData: MediaResourceData, representation: CachedVideoStickerRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal({ subscriber in
        return cacheVideoStickerFrames(path: resourceData.path, size: CGSize(width: CGFloat(representation.width), height: CGFloat(representation.height)), cacheKey: "\(resource.id.stringRepresentation)-\(representation.uniqueId)").start(next: { value in
            subscriber.putNext(value)
        }, completed: {
            subscriber.putCompletion()
        })
    })
    |> runOn(Queue.concurrentDefaultQueue())
}

private func fetchPreparedPatternWallpaperRepresentation(resource: MediaResource, resourceData: MediaResourceData, representation: CachedPreparedPatternWallpaperRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal({ subscriber in
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
            if let unpackedData = TGGUnzipData(data, 2 * 1024 * 1024), let data = prepareSvgImage(unpackedData, true) {
                let path = NSTemporaryDirectory() + "\(Int64.random(in: Int64.min ... Int64.max))"
                let url = URL(fileURLWithPath: path)
                let _ = try? data.write(to: url)
                subscriber.putNext(.temporaryPath(path))
                subscriber.putCompletion()
            }
        }
        return EmptyDisposable
    }) |> runOn(Queue.concurrentDefaultQueue())
}

private func fetchPreparedSvgRepresentation(resource: MediaResource, resourceData: MediaResourceData, representation: CachedPreparedSvgRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal({ subscriber in
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
            if let data = prepareSvgImage(data, true) {
                let path = NSTemporaryDirectory() + "\(Int64.random(in: Int64.min ... Int64.max))"
                let url = URL(fileURLWithPath: path)
                let _ = try? data.write(to: url)
                subscriber.putNext(.temporaryPath(path))
                subscriber.putCompletion()
            }
        }
        return EmptyDisposable
    }) |> runOn(Queue.concurrentDefaultQueue())
}
