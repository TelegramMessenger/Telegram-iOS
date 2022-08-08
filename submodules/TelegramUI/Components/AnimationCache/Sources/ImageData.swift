import Foundation
import UIKit
import ImageDCT
import Accelerate

private func alignUp(size: Int, align: Int) -> Int {
    precondition(((align - 1) & align) == 0, "Align must be a power of two")

    let alignmentMask = align - 1
    return (size + alignmentMask) & ~alignmentMask
}

final class ImagePlane: CustomStringConvertible {
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
    
    var description: String {
        return self.data.withUnsafeBytes { bytes -> String in
            let pixels = bytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
            
            var result = ""
        
            for y in 0 ..< self.height {
                if y != 0 {
                    result.append("\n")
                }
                for x in 0 ..< self.width {
                    if x != 0 {
                        result.append(" ")
                    }
                    result.append(String(format: "%03d", Int(pixels[y * self.bytesPerRow + x])))
                }
            }
            
            return result
        }
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
    
    func subtract(other: DctCoefficientPlane) {
        self.data.withUnsafeMutableBytes { bytes in
            other.data.withUnsafeBytes { otherBytes in
                subtractArraysUInt8Int16(bytes.baseAddress!.assumingMemoryBound(to: UInt8.self), otherBytes.baseAddress!.assumingMemoryBound(to: Int16.self), bytes.baseAddress!.assumingMemoryBound(to: UInt8.self), Int32(bytes.count))
            }
        }
    }
    
    func add(other: DctCoefficientPlane) {
        self.data.withUnsafeMutableBytes { bytes in
            other.data.withUnsafeBytes { otherBytes in
                addArraysUInt8Int16(bytes.baseAddress!.assumingMemoryBound(to: UInt8.self), otherBytes.baseAddress!.assumingMemoryBound(to: Int16.self), bytes.baseAddress!.assumingMemoryBound(to: UInt8.self), Int32(bytes.count))
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

final class DctCoefficientPlane: CustomStringConvertible {
    let width: Int
    let height: Int
    var data: Data
    
    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.data = Data(count: width * 2 * height)
    }
    
    var description: String {
        return self.data.withUnsafeBytes { bytes -> String in
            let pixels = bytes.baseAddress!.assumingMemoryBound(to: Int16.self)
            
            var result = ""
        
            for y in 0 ..< self.height {
                if y != 0 {
                    result.append("\n")
                }
                for x in 0 ..< self.width {
                    if x != 0 {
                        result.append(" ")
                    }
                    result.append(String(format: "%03d", Int(pixels[y * self.width + x])))
                }
            }
            
            return result
        }
    }
    
    func subtract(other: DctCoefficientPlane) {
        self.data.withUnsafeMutableBytes { bytes in
            other.data.withUnsafeBytes { otherBytes in
                subtractArraysInt16(bytes.baseAddress!.assumingMemoryBound(to: Int16.self), otherBytes.baseAddress!.assumingMemoryBound(to: Int16.self), bytes.baseAddress!.assumingMemoryBound(to: Int16.self), Int32(bytes.count / 2))
            }
        }
    }
    
    func add(other: DctCoefficientPlane) {
        self.data.withUnsafeMutableBytes { bytes in
            other.data.withUnsafeBytes { otherBytes in
                addArraysInt16(bytes.baseAddress!.assumingMemoryBound(to: Int16.self), otherBytes.baseAddress!.assumingMemoryBound(to: Int16.self), bytes.baseAddress!.assumingMemoryBound(to: Int16.self), Int32(bytes.count / 2))
            }
        }
    }
}

extension DctCoefficientPlane {
    func toFloatCoefficients(target: FloatCoefficientPlane) {
        self.data.withUnsafeBytes { bytes in
            target.data.withUnsafeMutableBytes { otherBytes in
                vDSP_vflt16(bytes.baseAddress!.assumingMemoryBound(to: Int16.self), 1, otherBytes.baseAddress!.assumingMemoryBound(to: Float32.self), 1, vDSP_Length(bytes.count / 2))
            }
        }
    }
    
    func toUInt8(target: ImagePlane) {
        self.data.withUnsafeBytes { bytes in
            target.data.withUnsafeMutableBytes { otherBytes in
                convertInt16toUInt8(bytes.baseAddress!.assumingMemoryBound(to: Int16.self), otherBytes.baseAddress!.assumingMemoryBound(to: UInt8.self), Int32(bytes.count / 2))
            }
        }
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

final class FloatCoefficientPlane: CustomStringConvertible {
    let width: Int
    let height: Int
    var data: Data
    
    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.data = Data(count: width * 4 * height)
    }
    
    var description: String {
        return self.data.withUnsafeBytes { bytes -> String in
            let pixels = bytes.baseAddress!.assumingMemoryBound(to: Float32.self)
            
            var result = ""
        
            for y in 0 ..< self.height {
                if y != 0 {
                    result.append("\n")
                }
                for x in 0 ..< self.width {
                    if x != 0 {
                        result.append(" ")
                    }
                    result.append(String(format: "%03.02f", Double(pixels[y * self.width + x])))
                }
            }
            
            return result
        }
    }
}

final class FloatCoefficientsYUVA420 {
    let yPlane: FloatCoefficientPlane
    let uPlane: FloatCoefficientPlane
    let vPlane: FloatCoefficientPlane
    let aPlane: FloatCoefficientPlane
    
    init(width: Int, height: Int) {
        self.yPlane = FloatCoefficientPlane(width: width, height: height)
        self.uPlane = FloatCoefficientPlane(width: width / 2, height: height / 2)
        self.vPlane = FloatCoefficientPlane(width: width / 2, height: height / 2)
        self.aPlane = FloatCoefficientPlane(width: width, height: height)
    }
    
    func copy(into other: FloatCoefficientsYUVA420) {
        self.yPlane.copy(into: other.yPlane)
        self.uPlane.copy(into: other.uPlane)
        self.vPlane.copy(into: other.vPlane)
        self.aPlane.copy(into: other.aPlane)
    }
}

extension FloatCoefficientPlane {
    func add(constant: Float32) {
        let buffer = malloc(4 * self.data.count)!
        
        memset(buffer, Int32(bitPattern: constant.bitPattern), 4 * self.data.count)
        defer {
            free(buffer)
        }
        var constant = constant
        self.data.withUnsafeMutableBytes { bytes in
            vDSP_vfill(&constant, buffer.assumingMemoryBound(to: Float32.self), 1, vDSP_Length(bytes.count / 4))
            vDSP_vadd(bytes.baseAddress!.assumingMemoryBound(to: Float32.self), 1, buffer.assumingMemoryBound(to: Float32.self), 1, bytes.baseAddress!.assumingMemoryBound(to: Float32.self), 1, vDSP_Length(bytes.count / 4))
        }
    }
    
    func add(other: FloatCoefficientPlane) {
        self.data.withUnsafeMutableBytes { bytes in
            other.data.withUnsafeBytes { otherBytes in
                vDSP_vadd(bytes.baseAddress!.assumingMemoryBound(to: Float32.self), 1, otherBytes.baseAddress!.assumingMemoryBound(to: Float32.self), 1, bytes.baseAddress!.assumingMemoryBound(to: Float32.self), 1, vDSP_Length(bytes.count / 4))
            }
        }
    }
    
    func subtract(other: FloatCoefficientPlane) {
        self.data.withUnsafeMutableBytes { bytes in
            other.data.withUnsafeBytes { otherBytes in
                vDSP_vsub(bytes.baseAddress!.assumingMemoryBound(to: Float32.self), 1, otherBytes.baseAddress!.assumingMemoryBound(to: Float32.self), 1, bytes.baseAddress!.assumingMemoryBound(to: Float32.self), 1, vDSP_Length(bytes.count / 4))
            }
        }
    }
    
    func clamp() {
        self.data.withUnsafeMutableBytes { bytes in
            let pixels = bytes.baseAddress!.assumingMemoryBound(to: Float32.self)
            var low: Float32 = 0.0
            var high: Float32 = 255.0
            vDSP_vclip(pixels, 1, &low, &high, pixels, 1, vDSP_Length(bytes.count / 4))
        }
    }
    
    func toDctCoefficients(target: DctCoefficientPlane) {
        self.data.withUnsafeBytes { bytes in
            target.data.withUnsafeMutableBytes { otherBytes in
                vDSP_vfix16(bytes.baseAddress!.assumingMemoryBound(to: Float32.self), 1, otherBytes.baseAddress!.assumingMemoryBound(to: Int16.self), 1, vDSP_Length(bytes.count / 4))
            }
        }
    }
    
    func toUInt8(target: ImagePlane) {
        self.data.withUnsafeBytes { bytes in
            target.data.withUnsafeMutableBytes { otherBytes in
                vDSP_vfix8(bytes.baseAddress!.assumingMemoryBound(to: Float32.self), 1, otherBytes.baseAddress!.assumingMemoryBound(to: Int8.self), 1, vDSP_Length(bytes.count / 4))
            }
        }
    }
    
    func copy(into other: FloatCoefficientPlane) {
        assert(self.data.count == other.data.count)
        
        self.data.withUnsafeBytes { bytes in
            other.data.withUnsafeMutableBytes { otherBytes in
                let _ = memcpy(otherBytes.baseAddress!, bytes.baseAddress!, bytes.count)
            }
        }
    }
}

extension FloatCoefficientsYUVA420 {
    func add(constant: Float32) {
        self.yPlane.add(constant: constant)
        self.uPlane.add(constant: constant)
        self.vPlane.add(constant: constant)
        self.aPlane.add(constant: constant)
    }
    
    func add(other: FloatCoefficientsYUVA420) {
        self.yPlane.add(other: other.yPlane)
        self.uPlane.add(other: other.uPlane)
        self.vPlane.add(other: other.vPlane)
        self.aPlane.add(other: other.aPlane)
    }
    
    func subtract(other: FloatCoefficientsYUVA420) {
        self.yPlane.subtract(other: other.yPlane)
        self.uPlane.subtract(other: other.uPlane)
        self.vPlane.subtract(other: other.vPlane)
        self.aPlane.subtract(other: other.aPlane)
    }
    
    func clamp() {
        self.yPlane.clamp()
        self.uPlane.clamp()
        self.vPlane.clamp()
        self.aPlane.clamp()
    }
    
    func toDctCoefficients(target: DctCoefficientsYUVA420) {
        self.yPlane.toDctCoefficients(target: target.yPlane)
        self.uPlane.toDctCoefficients(target: target.uPlane)
        self.vPlane.toDctCoefficients(target: target.vPlane)
        self.aPlane.toDctCoefficients(target: target.aPlane)
    }
    
    func toYUVA420(target: ImageYUVA420) {
        assert(self.yPlane.width == target.yPlane.width && self.yPlane.height == target.yPlane.height)
        
        self.yPlane.toUInt8(target: target.yPlane)
        self.uPlane.toUInt8(target: target.uPlane)
        self.vPlane.toUInt8(target: target.vPlane)
        self.aPlane.toUInt8(target: target.aPlane)
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
                            combineYUVAPlanesIntoARGB(
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
    let lumaTable: ImageDCTTable
    let lumaDct: ImageDCT
    
    let chromaTable: ImageDCTTable
    let chromaDct: ImageDCT
    
    let deltaTable: ImageDCTTable
    let deltaDct: ImageDCT
    
    init?(lumaTable: Data, chromaTable: Data, deltaTable: Data) {
        guard let lumaTableData = ImageDCTTable(data: lumaTable) else {
            return nil
        }
        guard let chromaTableData = ImageDCTTable(data: chromaTable) else {
            return nil
        }
        guard let deltaTableData = ImageDCTTable(data: deltaTable) else {
            return nil
        }
        
        self.lumaTable = lumaTableData
        self.lumaDct = ImageDCT(table: lumaTableData)
        
        self.chromaTable = chromaTableData
        self.chromaDct = ImageDCT(table: chromaTableData)
        
        self.deltaTable = deltaTableData
        self.deltaDct = ImageDCT(table: deltaTableData)
    }
    
    init(generatingTablesAtQualityLuma lumaQuality: Int, chroma chromaQuality: Int, delta deltaQuality: Int) {
        self.lumaTable = ImageDCTTable(quality: lumaQuality, type: .luma)
        self.lumaDct = ImageDCT(table: self.lumaTable)
        
        self.chromaTable = ImageDCTTable(quality: chromaQuality, type: .chroma)
        self.chromaDct = ImageDCT(table: self.chromaTable)
        
        self.deltaTable = ImageDCTTable(quality: deltaQuality, type: .delta)
        self.deltaDct = ImageDCT(table: self.deltaTable)
    }
}

extension ImageYUVA420 {
    func toCoefficients(target: FloatCoefficientsYUVA420) {
        precondition(self.yPlane.width == target.yPlane.width && self.yPlane.height == target.yPlane.height)
        
        for i in 0 ..< 4 {
            let sourcePlane: ImagePlane
            let targetPlane: FloatCoefficientPlane
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
                    let coefficients = bytes.baseAddress!.assumingMemoryBound(to: Float32.self)
                    
                    vDSP_vfltu8(sourcePixels, 1, coefficients, 1, vDSP_Length(sourceBytes.count))
                }
            }
        }
    }
    
    func toCoefficients(target: DctCoefficientsYUVA420) {
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
                    
                    convertUInt8toInt16(sourcePixels, coefficients, Int32(sourceBytes.count))
                }
            }
        }
    }
    
    func dct8x8(dctData: DctData, target: DctCoefficientsYUVA420) {
        precondition(self.yPlane.width == target.yPlane.width && self.yPlane.height == target.yPlane.height)
        
        for i in 0 ..< 4 {
            let sourcePlane: ImagePlane
            let targetPlane: DctCoefficientPlane
            let isChroma: Bool
            switch i {
            case 0:
                sourcePlane = self.yPlane
                targetPlane = target.yPlane
                isChroma = false
            case 1:
                sourcePlane = self.uPlane
                targetPlane = target.uPlane
                isChroma = true
            case 2:
                sourcePlane = self.vPlane
                targetPlane = target.vPlane
                isChroma = true
            case 3:
                sourcePlane = self.aPlane
                targetPlane = target.aPlane
                isChroma = false
            default:
                preconditionFailure()
            }
            
            sourcePlane.data.withUnsafeBytes { sourceBytes in
                let sourcePixels = sourceBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
                
                targetPlane.data.withUnsafeMutableBytes { bytes in
                    let coefficients = bytes.baseAddress!.assumingMemoryBound(to: Int16.self)
                    
                    let dct = isChroma ? dctData.chromaDct : dctData.lumaDct
                    dct.forward(withPixels: sourcePixels, coefficients: coefficients, width: sourcePlane.width, height: sourcePlane.height, bytesPerRow: sourcePlane.bytesPerRow)
                }
            }
        }
    }
    
    func subtract(other: DctCoefficientsYUVA420) {
        self.yPlane.subtract(other: other.yPlane)
        self.uPlane.subtract(other: other.uPlane)
        self.vPlane.subtract(other: other.vPlane)
        self.aPlane.subtract(other: other.aPlane)
    }
    
    func add(other: DctCoefficientsYUVA420) {
        self.yPlane.add(other: other.yPlane)
        self.uPlane.add(other: other.uPlane)
        self.vPlane.add(other: other.vPlane)
        self.aPlane.add(other: other.aPlane)
    }
}

extension DctCoefficientsYUVA420 {
    func idct8x8(dctData: DctData, target: ImageYUVA420) {
        precondition(self.yPlane.width == target.yPlane.width && self.yPlane.height == target.yPlane.height)
        
        for i in 0 ..< 4 {
            let sourcePlane: DctCoefficientPlane
            let targetPlane: ImagePlane
            let isChroma: Bool
            switch i {
            case 0:
                sourcePlane = self.yPlane
                targetPlane = target.yPlane
                isChroma = false
            case 1:
                sourcePlane = self.uPlane
                targetPlane = target.uPlane
                isChroma = true
            case 2:
                sourcePlane = self.vPlane
                targetPlane = target.vPlane
                isChroma = true
            case 3:
                sourcePlane = self.aPlane
                targetPlane = target.aPlane
                isChroma = false
            default:
                preconditionFailure()
            }
            
            sourcePlane.data.withUnsafeBytes { sourceBytes in
                let coefficients = sourceBytes.baseAddress!.assumingMemoryBound(to: Int16.self)
                
                targetPlane.data.withUnsafeMutableBytes { bytes in
                    let pixels = bytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    
                    let dct = isChroma ? dctData.chromaDct : dctData.lumaDct
                    dct.inverse(withCoefficients: coefficients, pixels: pixels, width: sourcePlane.width, height: sourcePlane.height, coefficientsPerRow: targetPlane.width, bytesPerRow: targetPlane.bytesPerRow)
                }
            }
        }
    }
    
    func dct4x4(dctData: DctData, target: DctCoefficientsYUVA420) {
        #if arch(arm64)
        precondition(self.yPlane.width == target.yPlane.width && self.yPlane.height == target.yPlane.height)
        
        for i in 0 ..< 4 {
            let sourcePlane: DctCoefficientPlane
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
                let sourceCoefficients = sourceBytes.baseAddress!.assumingMemoryBound(to: Int16.self)
                
                targetPlane.data.withUnsafeMutableBytes { bytes in
                    let coefficients = bytes.baseAddress!.assumingMemoryBound(to: Int16.self)
                    
                    dctData.deltaDct.forward4x4(sourceCoefficients, coefficients: coefficients, width: sourcePlane.width, height: sourcePlane.height)
                }
            }
        }
        #endif
    }
    
    func idct4x4Add(dctData: DctData, target: DctCoefficientsYUVA420) {
        #if arch(arm64)
        precondition(self.yPlane.width == target.yPlane.width && self.yPlane.height == target.yPlane.height)
        
        for i in 0 ..< 4 {
            let sourcePlane: DctCoefficientPlane
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
                let sourceCoefficients = sourceBytes.baseAddress!.assumingMemoryBound(to: Int16.self)
                
                targetPlane.data.withUnsafeMutableBytes { bytes in
                    let coefficients = bytes.baseAddress!.assumingMemoryBound(to: Int16.self)
                    
                    //memcpy(coefficients, sourceCoefficients, sourceBytes.count)
                    
                    dctData.deltaDct.inverse4x4Add(sourceCoefficients, normalizedCoefficients: coefficients, width: sourcePlane.width, height: sourcePlane.height)
                }
            }
        }
        #endif
    }
    
    func subtract(other: DctCoefficientsYUVA420) {
        self.yPlane.subtract(other: other.yPlane)
        self.uPlane.subtract(other: other.uPlane)
        self.vPlane.subtract(other: other.vPlane)
        self.aPlane.subtract(other: other.aPlane)
    }
    
    func add(other: DctCoefficientsYUVA420) {
        self.yPlane.add(other: other.yPlane)
        self.uPlane.add(other: other.uPlane)
        self.vPlane.add(other: other.vPlane)
        self.aPlane.add(other: other.aPlane)
    }
    
    func toFloatCoefficients(target: FloatCoefficientsYUVA420) {
        self.yPlane.toFloatCoefficients(target: target.yPlane)
        self.uPlane.toFloatCoefficients(target: target.uPlane)
        self.vPlane.toFloatCoefficients(target: target.vPlane)
        self.aPlane.toFloatCoefficients(target: target.aPlane)
    }
    
    func toYUVA420(target: ImageYUVA420) {
        assert(self.yPlane.width == target.yPlane.width && self.yPlane.height == target.yPlane.height)
        
        self.yPlane.toUInt8(target: target.yPlane)
        self.uPlane.toUInt8(target: target.uPlane)
        self.vPlane.toUInt8(target: target.vPlane)
        self.aPlane.toUInt8(target: target.aPlane)
    }
}
