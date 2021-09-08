//
//  GImage+Utils.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/8/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import Foundation
#if os(macOS)
import Cocoa
#else
import UIKit
#endif

#if os(iOS)
public typealias GImage = UIImage
#else
public typealias GImage = NSImage
#endif

#if os(macOS)
internal let deviceColorSpace: CGColorSpace = {
    if #available(OSX 10.11.2, *) {
        if let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) {
            return colorSpace
        } else {
            return CGColorSpaceCreateDeviceRGB()
        }
    } else {
        return CGColorSpaceCreateDeviceRGB()
    }
}()
#else
internal let deviceColorSpace: CGColorSpace = {
    if #available(iOSApplicationExtension 9.3, iOS 9.3, *) {
        if let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) {
            return colorSpace
        } else {
            return CGColorSpaceCreateDeviceRGB()
        }
    } else {
        return CGColorSpaceCreateDeviceRGB()
    }
}()
#endif

var deviceScale: CGFloat {
    #if os(macOS)
    return NSScreen.main?.backingScaleFactor ?? 1.0
    #else
    return UIScreen.main.scale
    #endif
}

func generateImage(_ size: CGSize, contextGenerator: (CGSize, CGContext) -> Void, opaque: Bool = false, scale: CGFloat? = nil) -> GImage? {
    let selectedScale = scale ?? deviceScale
    let scaledSize = CGSize(width: size.width * selectedScale, height: size.height * selectedScale)
    let bytesPerRow = (4 * Int(scaledSize.width) + 31) & (~31)
    let length = bytesPerRow * Int(scaledSize.height)
    let bytes = malloc(length)!.assumingMemoryBound(to: Int8.self)
    
    guard let provider = CGDataProvider(dataInfo: bytes, data: bytes, size: length, releaseData: { bytes, _, _ in
        free(bytes)
    })
        else {
            return nil
    }
    
    let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | (opaque ? CGImageAlphaInfo.noneSkipFirst.rawValue : CGImageAlphaInfo.premultipliedFirst.rawValue))
    
    guard let context = CGContext(data: bytes, width: Int(scaledSize.width), height: Int(scaledSize.height), bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: deviceColorSpace, bitmapInfo: bitmapInfo.rawValue) else {
        return nil
    }
    
    context.scaleBy(x: selectedScale, y: selectedScale)
    
    contextGenerator(size, context)
    
    guard let image = CGImage(width: Int(scaledSize.width), height: Int(scaledSize.height), bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow, space: deviceColorSpace, bitmapInfo: bitmapInfo, provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else {
            return nil
    }
    #if os(macOS)
    return GImage(cgImage: image, size: size)
    #else
    return GImage(cgImage: image, scale: selectedScale, orientation: .up)
    #endif
}


