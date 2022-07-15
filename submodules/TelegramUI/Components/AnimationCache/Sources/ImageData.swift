import Foundation
import UIKit
import ImageDCT

private func alignUp(size: Int, align: Int) -> Int {
    precondition(((align - 1) & align) == 0, "Align must be a power of two")

    let alignmentMask = align - 1
    return (size + alignmentMask) & ~alignmentMask
}

final class ImagePlane {
    let width: Int
    let height: Int
    let bytesPerRow: Int
    let rowAlignment: Int
    let components: Int
    var data: Data
    
    init(width: Int, height: Int, components: Int, rowAlignment: Int?) {
        self.width = width
        self.height = height
        self.rowAlignment = rowAlignment ?? 1
        self.bytesPerRow = alignUp(size: width * components, align: self.rowAlignment)
        self.components = components
        self.data = Data(count: self.bytesPerRow * height)
    }
}

extension ImagePlane {
    func copyScaled(fromPlane plane: AnimationCacheItemFrame.Plane) {
        self.data.withUnsafeMutableBytes { destBytes in
            plane.data.withUnsafeBytes { srcBytes in
                scaleImagePlane(destBytes.baseAddress!.assumingMemoryBound(to: UInt8.self), Int32(self.width), Int32(self.height), Int32(self.bytesPerRow), srcBytes.baseAddress!.assumingMemoryBound(to: UInt8.self), Int32(plane.width), Int32(plane.height), Int32(plane.bytesPerRow))
            }
        }
    }
}

final class ImageARGB {
    let argbPlane: ImagePlane
    
    init(width: Int, height: Int, rowAlignment: Int?) {
        self.argbPlane = ImagePlane(width: width, height: height, components: 4, rowAlignment: rowAlignment)
    }
}

final class ImageYUVA420 {
    let yPlane: ImagePlane
    let uPlane: ImagePlane
    let vPlane: ImagePlane
    let aPlane: ImagePlane
    
    init(width: Int, height: Int, rowAlignment: Int?) {
        self.yPlane = ImagePlane(width: width, height: height, components: 1, rowAlignment: rowAlignment)
        self.uPlane = ImagePlane(width: width / 2, height: height / 2, components: 1, rowAlignment: rowAlignment)
        self.vPlane = ImagePlane(width: width / 2, height: height / 2, components: 1, rowAlignment: rowAlignment)
        self.aPlane = ImagePlane(width: width, height: height, components: 1, rowAlignment: rowAlignment)
    }
}

final class DctCoefficientPlane {
    let width: Int
    let height: Int
    var data: Data
    
    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.data = Data(count: width * 2 * height)
    }
}

final class DctCoefficientsYUVA420 {
    let yPlane: DctCoefficientPlane
    let uPlane: DctCoefficientPlane
    let vPlane: DctCoefficientPlane
    let aPlane: DctCoefficientPlane
    
    init(width: Int, height: Int) {
        self.yPlane = DctCoefficientPlane(width: width, height: height)
        self.uPlane = DctCoefficientPlane(width: width / 2, height: height / 2)
        self.vPlane = DctCoefficientPlane(width: width / 2, height: height / 2)
        self.aPlane = DctCoefficientPlane(width: width, height: height)
    }
}

extension ImageARGB {
    func toYUVA420(target: ImageYUVA420) {
        precondition(self.argbPlane.width == target.yPlane.width && self.argbPlane.height == target.yPlane.height)
        
        self.argbPlane.data.withUnsafeBytes { argbBuffer -> Void in
            target.yPlane.data.withUnsafeMutableBytes { yBuffer -> Void in
                target.uPlane.data.withUnsafeMutableBytes { uBuffer -> Void in
                    target.vPlane.data.withUnsafeMutableBytes { vBuffer -> Void in
                        target.aPlane.data.withUnsafeMutableBytes { aBuffer -> Void in
                            splitRGBAIntoYUVAPlanes(
                                argbBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self),
                                yBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self),
                                uBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self),
                                vBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self),
                                aBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self),
                                Int32(self.argbPlane.width),
                                Int32(self.argbPlane.height),
                                Int32(self.argbPlane.bytesPerRow)
                            )
                        }
                    }
                }
            }
        }
    }
    
    func toYUVA420(rowAlignment: Int?) -> ImageYUVA420 {
        let resultImage = ImageYUVA420(width: self.argbPlane.width, height: self.argbPlane.height, rowAlignment: rowAlignment)
        self.toYUVA420(target: resultImage)
        return resultImage
    }
}

extension ImageYUVA420 {
    func toARGB(target: ImageARGB) {
        precondition(self.yPlane.width == target.argbPlane.width && self.yPlane.height == target.argbPlane.height)
        
        self.yPlane.data.withUnsafeBytes { yBuffer -> Void in
            self.uPlane.data.withUnsafeBytes { uBuffer -> Void in
                self.vPlane.data.withUnsafeBytes { vBuffer -> Void in
                    self.aPlane.data.withUnsafeBytes { aBuffer -> Void in
                        target.argbPlane.data.withUnsafeMutableBytes { argbBuffer -> Void in
                            combineYUVAPlanesIntoARBB(
                                argbBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self),
                                yBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self),
                                uBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self),
                                vBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self),
                                aBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self),
                                Int32(target.argbPlane.width),
                                Int32(target.argbPlane.height),
                                Int32(target.argbPlane.bytesPerRow)
                            )
                        }
                    }
                }
            }
        }
    }
    
    func toARGB(rowAlignment: Int?) -> ImageARGB {
        let resultImage = ImageARGB(width: self.yPlane.width, height: self.yPlane.height, rowAlignment: rowAlignment)
        self.toARGB(target: resultImage)
        return resultImage
    }
}

final class DctData {
    let quality: Int
    let dct: ImageDCT
    
    init(quality: Int) {
        self.quality = quality
        self.dct = ImageDCT(quality: quality)
    }
}

extension ImageYUVA420 {
    func dct(dctData: DctData, target: DctCoefficientsYUVA420) {
        precondition(self.yPlane.width == target.yPlane.width && self.yPlane.height == target.yPlane.height)
        
        for i in 0 ..< 4 {
            let sourcePlane: ImagePlane
            let targetPlane: DctCoefficientPlane
            switch i {
            case 0:
                sourcePlane = self.yPlane
                targetPlane = target.yPlane
            case 1:
                sourcePlane = self.uPlane
                targetPlane = target.uPlane
            case 2:
                sourcePlane = self.vPlane
                targetPlane = target.vPlane
            case 3:
                sourcePlane = self.aPlane
                targetPlane = target.aPlane
            default:
                preconditionFailure()
            }
            
            sourcePlane.data.withUnsafeBytes { sourceBytes in
                let sourcePixels = sourceBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
                
                targetPlane.data.withUnsafeMutableBytes { bytes in
                    let coefficients = bytes.baseAddress!.assumingMemoryBound(to: Int16.self)
                    
                    dctData.dct.forward(withPixels: sourcePixels, coefficients: coefficients, width: sourcePlane.width, height: sourcePlane.height, bytesPerRow: sourcePlane.bytesPerRow)
                }
            }
        }
    }
    
    func dct(dctData: DctData) -> DctCoefficientsYUVA420 {
        let results = DctCoefficientsYUVA420(width: self.yPlane.width, height: self.yPlane.height)
        self.dct(dctData: dctData, target: results)
        return results
    }
}

extension DctCoefficientsYUVA420 {
    func idct(dctData: DctData, target: ImageYUVA420) {
        precondition(self.yPlane.width == target.yPlane.width && self.yPlane.height == target.yPlane.height)
        
        for i in 0 ..< 4 {
            let sourcePlane: DctCoefficientPlane
            let targetPlane: ImagePlane
            switch i {
            case 0:
                sourcePlane = self.yPlane
                targetPlane = target.yPlane
            case 1:
                sourcePlane = self.uPlane
                targetPlane = target.uPlane
            case 2:
                sourcePlane = self.vPlane
                targetPlane = target.vPlane
            case 3:
                sourcePlane = self.aPlane
                targetPlane = target.aPlane
            default:
                preconditionFailure()
            }
            
            sourcePlane.data.withUnsafeBytes { sourceBytes in
                let coefficients = sourceBytes.baseAddress!.assumingMemoryBound(to: Int16.self)
                
                targetPlane.data.withUnsafeMutableBytes { bytes in
                    let pixels = bytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    
                    dctData.dct.inverse(withCoefficients: coefficients, pixels: pixels, width: sourcePlane.width, height: sourcePlane.height, coefficientsPerRow: targetPlane.width, bytesPerRow: targetPlane.bytesPerRow)
                }
            }
        }
    }
    
    func idct(dctData: DctData, rowAlignment: Int?) -> ImageYUVA420 {
        let resultImage = ImageYUVA420(width: self.yPlane.width, height: self.yPlane.height, rowAlignment: rowAlignment)
        self.idct(dctData: dctData, target: resultImage)
        return resultImage
    }
}
