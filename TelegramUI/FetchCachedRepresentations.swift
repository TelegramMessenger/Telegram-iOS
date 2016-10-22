import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore
import ImageIO
import MobileCoreServices
import Display
import UIKit

public func fetchCachedResourceRepresentation(account: Account, resource: MediaResource, resourceData: MediaResourceData, representation: CachedMediaResourceRepresentation) -> Signal<CachedMediaResourceRepresentationResult, NoError> {
    if let representation = representation as? CachedStickerAJpegRepresentation {
        return fetchCachedStickerAJpegRepresentation(account: account, resource: resource, resourceData: resourceData, representation: representation)
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
                
                let size = representation.size ?? CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
                
                let colorImage: UIImage
                if let _ = representation.size {
                    colorImage = generateImage(size, contextGenerator: { size, context in
                        context.setBlendMode(.copy)
                        context.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: size))
                    }, scale: 1.0)!
                } else {
                    colorImage = image
                }
                
                let alphaImage = generateImage(size, contextGenerator: { size, context in
                    context.setFillColor(UIColor.white.cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: size))
                    context.clip(to: CGRect(origin: CGPoint(), size: size), mask: colorImage.cgImage!)
                    context.setFillColor(UIColor.black.cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: size))
                }, scale: 1.0)
                
                if let alphaImage = alphaImage, let colorDestination = CGImageDestinationCreateWithData(colorData as CFMutableData, kUTTypeJPEG, 1, nil), let alphaDestination = CGImageDestinationCreateWithData(alphaData as CFMutableData, kUTTypeJPEG, 1, nil) {
                    CGImageDestinationSetProperties(colorDestination, nil)
                    CGImageDestinationSetProperties(alphaDestination, nil)
                    
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
                    
                    CGImageDestinationAddImage(colorDestination, colorImage.cgImage!, options as CFDictionary)
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
    }) |> runOn(account.graphicsThreadPool)
}
