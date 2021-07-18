import Foundation
import AVFoundation
import UIKit
import MozjpegBinding

public func extractImageExtraScans(_ data: Data) -> [Int] {
    return extractJPEGDataScans(data).map { item in
        return item.intValue
    }
}

public func compressImageToJPEG(_ image: UIImage, quality: Float) -> Data? {
    if let result = compressJPEGData(image) {
        return result
    }
    
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, "public.jpeg" as CFString, 1, nil) else {
        return nil
    }
    
    let options = NSMutableDictionary()
    options.setObject(quality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
    
    guard let cgImage = image.cgImage else {
        return nil
    }
    CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
    CGImageDestinationFinalize(destination)
    
    if data.length == 0 {
        return nil
    }
    
    return data as Data
}

@available(iOSApplicationExtension 11.0, iOS 11.0, *)
public func compressImage(_ image: UIImage, quality: Float) -> Data? {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, AVFileType.heic as CFString, 1, nil) else {
        return nil
    }
    
    let options = NSMutableDictionary()
    options.setObject(quality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
    
    guard let cgImage = image.cgImage else {
        return nil
    }
    CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
    CGImageDestinationFinalize(destination)
    
    if data.length == 0 {
        return nil
    }
    
    return data as Data
}

public enum MiniThumbnailType {
    case image
    case avatar
}

public func compressImageMiniThumbnail(_ image: UIImage, type: MiniThumbnailType = .image) -> Data? {
    switch type {
    case .image:
        return compressMiniThumbnail(image, CGSize(width: 40.0, height: 40.0))
    case .avatar:
        var size: CGFloat = 8.0
        var data = compressMiniThumbnail(image, CGSize(width: size, height: size))
        while true {
            size += 1.0
            if let candidateData = compressMiniThumbnail(image, CGSize(width: size, height: size)) {
                if candidateData.count >= 32 {
                    break
                } else {
                    data = candidateData
                }
            } else {
                break
            }
        }

        return data
    }
}
