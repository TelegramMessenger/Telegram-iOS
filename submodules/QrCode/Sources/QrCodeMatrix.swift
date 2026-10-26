import Foundation
import CoreImage
import CoreGraphics

public struct QrCodeMatrix: Equatable {
    public let size: Int
    private let bits: [Bool]

    public init?(size: Int, bits: [Bool]) {
        guard size > 0, bits.count == size * size else {
            return nil
        }
        self.size = size
        self.bits = bits
    }

    public subscript(x: Int, y: Int) -> Bool {
        return x >= 0 && y >= 0 && x < self.size && y < self.size && self.bits[y * self.size + x]
    }

    public func isEye(x: Int, y: Int) -> Bool {
        return QrCodeMatrix.isEye(x: x, y: y, size: self.size)
    }

    public static func isEye(x: Int, y: Int, size: Int) -> Bool {
        return (x < 7 && y < 7) || (x >= size - 7 && y < 7) || (x < 7 && y >= size - 7)
    }

    public var eyes: [(x: Int, y: Int)] {
        return [(0, 0), (self.size - 7, 0), (0, self.size - 7)]
    }
}

private let matrixContext = CIContext(options: [.useSoftwareRenderer: true, .workingColorSpace: NSNull()])

public func qrCodeMatrix(string: String, ecl: String) -> QrCodeMatrix? {
    guard let data = string.data(using: .isoLatin1, allowLossyConversion: false), let filter = CIFilter(name: "CIQRCodeGenerator") else {
        return nil
    }
    filter.setValue(data, forKey: "inputMessage")
    filter.setValue(ecl, forKey: "inputCorrectionLevel")
    guard let output = filter.outputImage else {
        return nil
    }
    let width = Int(output.extent.width)
    let height = Int(output.extent.height)
    guard width > 0, height > 0 else {
        return nil
    }
    let bytesPerRow = width * 4
    var pixels = [UInt8](repeating: 255, count: bytesPerRow * height)
    pixels.withUnsafeMutableBytes { buffer in
        if let baseAddress = buffer.baseAddress {
            matrixContext.render(output, toBitmap: baseAddress, rowBytes: bytesPerRow, bounds: output.extent, format: .RGBA8, colorSpace: nil)
        }
    }
    func isDark(_ x: Int, _ y: Int) -> Bool {
        return pixels[y * bytesPerRow + x * 4] < 128
    }
    var minX = width, minY = height, maxX = -1, maxY = -1
    for y in 0 ..< height {
        for x in 0 ..< width where isDark(x, y) {
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)
        }
    }
    guard maxX >= minX, maxY >= minY, maxX - minX == maxY - minY else {
        return nil
    }
    let size = maxX - minX + 1
    var bits = [Bool](repeating: false, count: size * size)
    for y in 0 ..< size {
        for x in 0 ..< size {
            bits[y * size + x] = isDark(minX + x, minY + y)
        }
    }
    return QrCodeMatrix(size: size, bits: bits)
}
