import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore
import ImageIO
import MobileCoreServices
import Display
import UIKit
import AVFoundation

public func fetchCachedResourceRepresentation(account: Account, resource: MediaResource, representation: CachedMediaResourceRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    if let representation = representation as? CachedStickerAJpegRepresentation {
        return account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            if !data.complete {
                return .complete()
            }
            return fetchCachedStickerAJpegRepresentation(account: account, resource: resource, resourceData: data,  representation: representation)
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
        /*return fetchPartialVideoThumbnail(postbox: account.postbox, resource: resource)
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            var randomId: Int64 = 0
            arc4random_buf(&randomId, 8)
            let path = NSTemporaryDirectory() + "\(randomId)"
            if let data = data, let _ = try? data.write(to: URL(fileURLWithPath: path)) {
                return .single(CachedMediaResourceRepresentationResult(temporaryPath: path))
            } else {
                return .complete()
            }
        }*/
        return account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            if !data.complete {
                return .complete()
            }
            return fetchCachedVideoFirstFrameRepresentation(account: account, resource: resource, resourceData: data)
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
    } else if let representation = representation as? CachedPatternWallpaperMaskRepresentation {
        return account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            if !data.complete {
                return .complete()
            }
            return fetchCachedPatternWallpaperMaskRepresentation(resource: resource, resourceData: data, representation: representation)
        }
    } else if let representation = representation as? CachedPatternWallpaperRepresentation {
        return account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            if !data.complete {
                return .complete()
            }
            return fetchCachedPatternWallpaperRepresentation(account: account, resource: resource, resourceData: data, representation: representation)
        }
    }
    return .never()
}

private func fetchCachedStickerAJpegRepresentation(account: Account, resource: MediaResource, resourceData: MediaResourceData, representation: CachedStickerAJpegRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal({ subscriber in
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
            if let image = UIImage.convert(fromWebP: data) {
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                let path = NSTemporaryDirectory() + "\(randomId)"
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
                
                if let alphaImage = alphaImage, let colorDestination = CGImageDestinationCreateWithData(colorData as CFMutableData, kUTTypeJPEG, 1, nil), let alphaDestination = CGImageDestinationCreateWithData(alphaData as CFMutableData, kUTTypeJPEG, 1, nil) {
                    CGImageDestinationSetProperties(colorDestination, [:] as CFDictionary)
                    CGImageDestinationSetProperties(alphaDestination, [:] as CFDictionary)
                    
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
                        
                        subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
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
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                let path = NSTemporaryDirectory() + "\(randomId)"
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
                
                if let colorDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) {
                    CGImageDestinationSetProperties(colorDestination, [:] as CFDictionary)
                    
                    let colorQuality: Float = 0.5
                    
                    let options = NSMutableDictionary()
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    
                    CGImageDestinationAddImage(colorDestination, colorImage.cgImage!, options as CFDictionary)
                    if CGImageDestinationFinalize(colorDestination) {
                        subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
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

private func fetchCachedVideoFirstFrameRepresentation(account: Account, resource: MediaResource, resourceData: MediaResourceData) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal { subscriber in
        if resourceData.complete {
            let tempFilePath = NSTemporaryDirectory() + "\(arc4random()).mov"
            
            do {
                let _ = try? FileManager.default.removeItem(atPath: tempFilePath)
                try FileManager.default.linkItem(atPath: resourceData.path, toPath: tempFilePath)
                
                let asset = AVAsset(url: URL(fileURLWithPath: tempFilePath))
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.maximumSize = CGSize(width: 800.0, height: 800.0)
                imageGenerator.appliesPreferredTrackTransform = true
                let fullSizeImage = try imageGenerator.copyCGImage(at: CMTime(seconds: 0.0, preferredTimescale: asset.duration.timescale), actualTime: nil)
                
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                let path = NSTemporaryDirectory() + "\(randomId)"
                let url = URL(fileURLWithPath: path)
                
                if let colorDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) {
                    CGImageDestinationSetProperties(colorDestination, [:] as CFDictionary)
                    
                    let colorQuality: Float = 0.6
                    
                    let options = NSMutableDictionary()
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    
                    CGImageDestinationAddImage(colorDestination, fullSizeImage, options as CFDictionary)
                    if CGImageDestinationFinalize(colorDestination) {
                        subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
                        subscriber.putCompletion()
                    }
                }
                
                subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
                subscriber.putCompletion()
            } catch (let e) {
                print("\(e)")
            }
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
                        var randomId: Int64 = 0
                        arc4random_buf(&randomId, 8)
                        let path = NSTemporaryDirectory() + "\(randomId)"
                        let url = URL(fileURLWithPath: path)
                        
                        let size = representation.size
                        
                        let colorImage = generateImage(size, contextGenerator: { size, context in
                            context.setBlendMode(.copy)
                            context.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: size))
                        }, scale: 1.0)!
                        
                        if let colorDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) {
                            CGImageDestinationSetProperties(colorDestination, [:] as CFDictionary)
                            
                            let colorQuality: Float = 0.5
                            
                            let options = NSMutableDictionary()
                            options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                            
                            CGImageDestinationAddImage(colorDestination, colorImage.cgImage!, options as CFDictionary)
                            if CGImageDestinationFinalize(colorDestination) {
                                subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
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
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                let path = NSTemporaryDirectory() + "\(randomId)"
                let url = URL(fileURLWithPath: path)
                
                if let colorImage = blurredImage(image, radius: 45.0), let colorDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) {
                    CGImageDestinationSetProperties(colorDestination, [:] as CFDictionary)
                    
                    let colorQuality: Float = 0.5
                    
                    let options = NSMutableDictionary()
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    
                    CGImageDestinationAddImage(colorDestination, colorImage.cgImage!, options as CFDictionary)
                    if CGImageDestinationFinalize(colorDestination) {
                        subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
                        subscriber.putCompletion()
                    }
                }
            }
        }
        return EmptyDisposable
    }) |> runOn(Queue.concurrentDefaultQueue())
}

private func fetchCachedPatternWallpaperMaskRepresentation(resource: MediaResource, resourceData: MediaResourceData, representation: CachedPatternWallpaperMaskRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal({ subscriber in
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
            if let image = UIImage(data: data) {
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                let path = NSTemporaryDirectory() + "\(randomId)"
                let url = URL(fileURLWithPath: path)
                
                let size = representation.size != nil ? image.size.aspectFitted(representation.size!) : CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
                
                let alphaImage = generateImage(size, contextGenerator: { size, context in
                    context.setFillColor(UIColor.black.cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: size))
                    context.clip(to: CGRect(origin: CGPoint(), size: size), mask: image.cgImage!)
                    context.setFillColor(UIColor.white.cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: size))
                }, scale: 1.0)
                   
                if let alphaImage = alphaImage, let alphaDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) {
                    CGImageDestinationSetProperties(alphaDestination, [:] as CFDictionary)
                    
                    let colorQuality: Float = 0.87
                    
                    let options = NSMutableDictionary()
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    
                    CGImageDestinationAddImage(alphaDestination, alphaImage.cgImage!, options as CFDictionary)
                    if CGImageDestinationFinalize(alphaDestination) {
                        subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
                        subscriber.putCompletion()
                    }
                }
            }
        }
        return EmptyDisposable
    }) |> runOn(Queue.concurrentDefaultQueue())
}

private func fetchCachedPatternWallpaperRepresentation(resource: MediaResource, resourceData: MediaResourceData, representation: CachedPatternWallpaperRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal({ subscriber in
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
            if let image = UIImage(data: data) {
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                let path = NSTemporaryDirectory() + "\(randomId)"
                let url = URL(fileURLWithPath: path)
                
                let size = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
                
                let backgroundColor = UIColor(rgb: UInt32(bitPattern: representation.color))
                let foregroundColor = patternColor(for: backgroundColor, intensity: CGFloat(representation.intensity) / 100.0)
                
                let colorImage = generateImage(size, contextGenerator: { size, c in
                    let rect = CGRect(origin: CGPoint(), size: size)
                    c.setBlendMode(.copy)
                    c.setFillColor(backgroundColor.cgColor)
                    c.fill(rect)
                    
                    c.setBlendMode(.normal)
                    if let cgImage = image.cgImage {
                        c.clip(to: rect, mask: cgImage)
                    }
                    c.setFillColor(foregroundColor.cgColor)
                    c.fill(rect)
                }, scale: 1.0)
                
                if let colorImage = colorImage, let colorDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) {
                    CGImageDestinationSetProperties(colorDestination, [:] as CFDictionary)
                    
                    let colorQuality: Float = 0.9
                    
                    let options = NSMutableDictionary()
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    
                    CGImageDestinationAddImage(colorDestination, colorImage.cgImage!, options as CFDictionary)
                    if CGImageDestinationFinalize(colorDestination) {
                        subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
                        subscriber.putCompletion()
                    }
                }
            }
        }
        return EmptyDisposable
    }) |> runOn(Queue.concurrentDefaultQueue())
}

public func fetchCachedSharedResourceRepresentation(accountManager: AccountManager, resource: MediaResource, representation: CachedMediaResourceRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
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
    } else if let representation = representation as? CachedPatternWallpaperMaskRepresentation {
        return accountManager.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            if !data.complete {
                return .complete()
            }
            return fetchCachedPatternWallpaperMaskRepresentation(resource: resource, resourceData: data, representation: representation)
        }
    } else if let representation = representation as? CachedPatternWallpaperRepresentation {
        return accountManager.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false))
        |> mapToSignal { data -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            if !data.complete {
                return .complete()
            }
            return fetchCachedPatternWallpaperRepresentation(resource: resource, resourceData: data, representation: representation)
        }
    } else {
        return .never()
    }
}

private func fetchCachedBlurredWallpaperRepresentation(account: Account, resource: MediaResource, resourceData: MediaResourceData, representation: CachedBlurredWallpaperRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal({ subscriber in
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
            if let image = UIImage(data: data) {
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                let path = NSTemporaryDirectory() + "\(randomId)"
                let url = URL(fileURLWithPath: path)
                
                if let colorImage = blurredImage(image, radius: 45.0), let colorDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) {
                    CGImageDestinationSetProperties(colorDestination, [:] as CFDictionary)
                    
                    let colorQuality: Float = 0.5
                    
                    let options = NSMutableDictionary()
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    
                    CGImageDestinationAddImage(colorDestination, colorImage.cgImage!, options as CFDictionary)
                    if CGImageDestinationFinalize(colorDestination) {
                        subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
                        subscriber.putCompletion()
                    }
                }
            }
        }
        return EmptyDisposable
    }) |> runOn(Queue.concurrentDefaultQueue())
}

private func fetchCachedPatternWallpaperMaskRepresentation(account: Account, resource: MediaResource, resourceData: MediaResourceData, representation: CachedPatternWallpaperMaskRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal({ subscriber in
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
            if let image = UIImage(data: data) {
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                let path = NSTemporaryDirectory() + "\(randomId)"
                let url = URL(fileURLWithPath: path)
                
                let size = representation.size != nil ? image.size.aspectFitted(representation.size!) : CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
                
                let alphaImage = generateImage(size, contextGenerator: { size, context in
                    context.setFillColor(UIColor.black.cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: size))
                    context.clip(to: CGRect(origin: CGPoint(), size: size), mask: image.cgImage!)
                    context.setFillColor(UIColor.white.cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: size))
                }, scale: 1.0)
                
                if let alphaImage = alphaImage, let alphaDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) {
                    CGImageDestinationSetProperties(alphaDestination, [:] as CFDictionary)
                    
                    let colorQuality: Float = 0.87
                    
                    let options = NSMutableDictionary()
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    
                    CGImageDestinationAddImage(alphaDestination, alphaImage.cgImage!, options as CFDictionary)
                    if CGImageDestinationFinalize(alphaDestination) {
                        subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
                        subscriber.putCompletion()
                    }
                }
            }
        }
        return EmptyDisposable
    }) |> runOn(Queue.concurrentDefaultQueue())
}

private func fetchCachedPatternWallpaperRepresentation(account: Account, resource: MediaResource, resourceData: MediaResourceData, representation: CachedPatternWallpaperRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    return Signal({ subscriber in
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.mappedIfSafe]) {
            if let image = UIImage(data: data) {
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                let path = NSTemporaryDirectory() + "\(randomId)"
                let url = URL(fileURLWithPath: path)
                
                let size = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
                
                let backgroundColor = UIColor(rgb: UInt32(bitPattern: representation.color))
                let foregroundColor = patternColor(for: backgroundColor, intensity: CGFloat(representation.intensity) / 100.0)
                
                let colorImage = generateImage(size, contextGenerator: { size, c in
                    let rect = CGRect(origin: CGPoint(), size: size)
                    c.setBlendMode(.copy)
                    c.setFillColor(backgroundColor.cgColor)
                    c.fill(rect)
                    
                    c.setBlendMode(.normal)
                    if let cgImage = image.cgImage {
                        c.clip(to: rect, mask: cgImage)
                    }
                    c.setFillColor(foregroundColor.cgColor)
                    c.fill(rect)
                }, scale: 1.0)
                
                if let colorImage = colorImage, let colorDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeJPEG, 1, nil) {
                    CGImageDestinationSetProperties(colorDestination, [:] as CFDictionary)
                    
                    let colorQuality: Float = 0.9
                    
                    let options = NSMutableDictionary()
                    options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                    
                    CGImageDestinationAddImage(colorDestination, colorImage.cgImage!, options as CFDictionary)
                    if CGImageDestinationFinalize(colorDestination) {
                        subscriber.putNext(CachedMediaResourceRepresentationResult(temporaryPath: path))
                        subscriber.putCompletion()
                    }
                }
            }
        }
        return EmptyDisposable
    }) |> runOn(Queue.concurrentDefaultQueue())
}

