import UIKit

private let walletCardTextureSize = CGSize(width: 361.0, height: 220.0)
private let walletCardTextureSourceSize = CGSize(width: 370.0, height: 220.0)

enum WalletCardTextures {
    private static let cachedStars = makeStarsImage()
    private static let cachedNoise = makeNoiseImage()
    private static let cachedQR = makeQRImage()

    static func starsImage() -> UIImage {
        return self.cachedStars
    }

    static func noiseImage() -> UIImage {
        return self.cachedNoise
    }

    static func qrImage() -> UIImage {
        return self.cachedQR
    }

    private static func makeQRImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.preferredRange = .standard
        format.scale = 8.0
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: 22.0, height: 22.0), format: format).image { context in
            let cg = context.cgContext
            cg.translateBy(x: -282.5, y: -90.0)
            cg.setFillColor(UIColor.white.cgColor)
            for origin in [CGPoint(x: 284.25, y: 91.75), CGPoint(x: 294.5, y: 91.75), CGPoint(x: 284.25, y: 102.0)] {
                let outer = CGRect(origin: origin, size: CGSize(width: 8.25, height: 8.25))
                let inner = outer.insetBy(dx: 1.375, dy: 1.375)
                let path = CGMutablePath()
                path.addRoundedRect(in: outer, cornerWidth: 2.4, cornerHeight: 2.4)
                path.addRoundedRect(in: inner, cornerWidth: 1.1, cornerHeight: 1.1)
                cg.addPath(path)
                cg.fillPath(using: .evenOdd)
            }
            for origin in [CGPoint(x: 295.0, y: 103.0), CGPoint(x: 300.12, y: 103.0), CGPoint(x: 297.6, y: 105.3),
                           CGPoint(x: 295.0, y: 108.15), CGPoint(x: 300.12, y: 108.15)] {
                let dot = CGRect(origin: origin, size: CGSize(width: 2.12, height: 2.1))
                cg.addPath(CGPath(roundedRect: dot, cornerWidth: 0.45, cornerHeight: 0.45, transform: nil))
                cg.fillPath()
            }
        }
    }

    private static func makeStarsImage() -> UIImage {
        let centers: [CGPoint] = [
            CGPoint(x: 87.12, y: 47.0),
            CGPoint(x: 312.6, y: 156.0),
            CGPoint(x: 29.72, y: 22.0),
            CGPoint(x: 249.06, y: 195.0),
            CGPoint(x: 121.97, y: 62.0),
            CGPoint(x: 227.53, y: 138.0),
            CGPoint(x: 248.03, y: 164.0),
            CGPoint(x: 69.69, y: 20.0),
            CGPoint(x: 127.09, y: 36.0),
            CGPoint(x: 56.37, y: 67.0),
            CGPoint(x: 177.0, y: 24.0),
            CGPoint(x: 219.0, y: 53.0),
            CGPoint(x: 284.0, y: 28.0),
            CGPoint(x: 338.0, y: 48.0),
            CGPoint(x: 330.0, y: 112.0),
            CGPoint(x: 292.0, y: 132.0),
            CGPoint(x: 181.0, y: 151.0),
            CGPoint(x: 142.0, y: 172.0),
            CGPoint(x: 47.0, y: 145.0),
            CGPoint(x: 95.0, y: 112.0),
        ]
        let phases: [CGFloat] = [
            0.05, 0.63, 0.22, 0.87, 0.42, 0.12, 0.74, 0.33, 0.55, 0.94,
            0.18, 0.69, 0.38, 0.81, 0.27, 0.58, 0.96, 0.47, 0.07, 0.76,
        ]
        let scaleX = walletCardTextureSize.width / walletCardTextureSourceSize.width
        let scaleY = walletCardTextureSize.height / walletCardTextureSourceSize.height

        let format = UIGraphicsImageRendererFormat()
        format.preferredRange = .standard
        format.scale = 3.0
        format.opaque = false

        return UIGraphicsImageRenderer(size: walletCardTextureSize, format: format).image { context in
            let cgContext = context.cgContext
            for (index, sourceCenter) in centers.enumerated() {
                let center = CGPoint(x: sourceCenter.x * scaleX, y: sourceCenter.y * scaleY)
                let phase = phases[index]
                cgContext.setFillColor(UIColor(red: 1.0, green: phase, blue: 0.0, alpha: 1.0).cgColor)
                cgContext.addPath(self.starPath(
                    center: center,
                    outerRadius: 4.05 * min(scaleX, scaleY),
                    innerRadius: 1.215 * min(scaleX, scaleY)
                ))
                cgContext.fillPath()
            }
        }
    }

    private static func starPath(center: CGPoint, outerRadius: CGFloat, innerRadius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for index in 0 ..< 8 {
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = -CGFloat.pi / 2.0 + CGFloat(index) * CGFloat.pi / 4.0
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    private static func makeNoiseImage() -> UIImage {
        let dimension = 256
        var seed: UInt64 = 0x2545_F491_4F6C_DD1D

        func random() -> Float {
            seed ^= seed << 13
            seed ^= seed >> 7
            seed ^= seed << 17
            return Float(seed & 0xffff) / Float(0xffff)
        }

        let base = (0 ..< dimension * dimension).map { _ in random() }
        let radius = 9
        var pixels = [UInt8](repeating: 0, count: dimension * dimension)

        for y in 0 ..< dimension {
            for x in 0 ..< dimension {
                var accumulator: Float = 0.0
                for offset in -radius ... radius {
                    accumulator += base[y * dimension + ((x + offset + dimension) % dimension)]
                }
                var value = accumulator / Float(2 * radius + 1)
                value = 0.5 + (value - 0.5) * 3.4
                let combined = 0.68 * value + 0.32 * random()
                pixels[y * dimension + x] = UInt8(max(0.0, min(255.0, combined * 255.0)))
            }
        }

        let grayImage: CGImage = pixels.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress,
                width: dimension,
                height: dimension,
                bitsPerComponent: 8,
                bytesPerRow: dimension,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            )!
            return context.makeImage()!
        }

        let format = UIGraphicsImageRendererFormat()
        format.preferredRange = .standard
        format.scale = 1.0
        format.opaque = true
        let size = CGSize(width: dimension, height: dimension)

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIImage(cgImage: grayImage).draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
