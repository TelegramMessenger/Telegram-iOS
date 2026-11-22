import UIKit
import Display
import QrCode

// Mirrors QrStudioCodeView.playReveal: modules grow out of the center as rounded windows
// over the final raster, and the finder eyes scale in on the same front.
final class WalletReceiveQrRevealView: UIView {
    static let revealTime: Double = 0.6

    private struct Cell {
        let center: CGPoint
        let distance: Double
    }

    private let image: UIImage
    private let moduleCount: Int

    private let revealMask = CAShapeLayer()
    private var cells: [Cell] = []
    private var eyes: [(layer: CALayer, distance: Double)] = []
    private var unit: CGFloat = 0.0

    init(image: UIImage, moduleCount: Int) {
        self.image = image
        self.moduleCount = moduleCount

        super.init(frame: CGRect(origin: .zero, size: image.size))

        self.isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func backOut(_ x: Double) -> Double {
        let c1 = 1.70158
        let c3 = c1 + 1.0
        let u = x - 1.0
        return 1.0 + c3 * u * u * u + c1 * u * u
    }

    private static func clamp01(_ x: Double) -> Double {
        return min(1.0, max(0.0, x))
    }

    private static func darkModules(cgImage: CGImage, imageSize: CGSize, centers: [CGPoint]) -> [Bool]? {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0, let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ), let bytes = context.data else {
            return nil
        }
        context.setFillColor(gray: 1.0, alpha: 1.0)
        context.fill(CGRect(x: 0.0, y: 0.0, width: CGFloat(width), height: CGFloat(height)))
        context.draw(cgImage, in: CGRect(x: 0.0, y: 0.0, width: CGFloat(width), height: CGFloat(height)))
        let pixels = bytes.assumingMemoryBound(to: UInt8.self)
        let scaleX = CGFloat(width) / imageSize.width
        let scaleY = CGFloat(height) / imageSize.height
        return centers.map { point in
            let x = min(width - 1, max(0, Int(point.x * scaleX)))
            let y = min(height - 1, max(0, Int(point.y * scaleY)))
            return pixels[y * context.bytesPerRow + x] < 128
        }
    }

    func prepare() -> Bool {
        let imageSize = self.image.size
        let (_, _, moduleSide) = qrCodeCutout(size: self.moduleCount, dimensions: imageSize, scale: self.image.scale)
        guard let cgImage = self.image.cgImage, moduleSide > 0.0, self.moduleCount >= 21 else {
            return false
        }
        let n = self.moduleCount
        let padding = round((imageSize.width - moduleSide * CGFloat(n)) * 0.5 * self.image.scale) / self.image.scale
        let center = Double(n - 1) / 2.0
        let reach = hypot(center, center)
        self.unit = moduleSide

        var candidates: [(x: Int, y: Int)] = []
        var centers: [CGPoint] = []
        for y in 0 ..< n {
            for x in 0 ..< n where !QrCodeMatrix.isEye(x: x, y: y, size: n) {
                candidates.append((x, y))
                centers.append(CGPoint(x: padding + (CGFloat(x) + 0.5) * moduleSide, y: padding + (CGFloat(y) + 0.5) * moduleSide))
            }
        }
        guard let dark = Self.darkModules(cgImage: cgImage, imageSize: imageSize, centers: centers) else {
            return false
        }
        self.cells = []
        for i in 0 ..< candidates.count where dark[i] {
            let cell = candidates[i]
            self.cells.append(Cell(center: centers[i], distance: hypot(Double(cell.x) - center, Double(cell.y) - center) / reach))
        }

        let codeLayer = CALayer()
        codeLayer.frame = CGRect(origin: .zero, size: imageSize)
        codeLayer.contents = cgImage
        codeLayer.contentsScale = self.image.scale
        self.layer.addSublayer(codeLayer)

        // The eyes' modules are left out of the mask and grow as whole layers instead.
        self.revealMask.frame = codeLayer.bounds
        self.revealMask.path = nil
        codeLayer.mask = self.revealMask

        for (eyeX, eyeY) in [(0, 0), (n - 7, 0), (0, n - 7)] {
            let frame = CGRect(
                x: padding + CGFloat(eyeX) * moduleSide,
                y: padding + CGFloat(eyeY) * moduleSide,
                width: 7.0 * moduleSide,
                height: 7.0 * moduleSide
            )
            let eyeLayer = CALayer()
            eyeLayer.frame = frame
            eyeLayer.contents = cgImage
            eyeLayer.contentsScale = self.image.scale
            eyeLayer.contentsRect = CGRect(
                x: frame.minX / imageSize.width,
                y: frame.minY / imageSize.height,
                width: frame.width / imageSize.width,
                height: frame.height / imageSize.height
            )
            eyeLayer.transform = CATransform3DMakeScale(0.001, 0.001, 1.0)
            self.layer.addSublayer(eyeLayer)
            self.eyes.append((eyeLayer, hypot(Double(eyeX) + 3.0 - center, Double(eyeY) + 3.0 - center) / reach))
        }
        return true
    }

    func update(time: Double) {
        let k = Self.clamp01(time / Self.revealTime)
        func grow(_ distance: Double) -> Double {
            return Self.backOut(Self.clamp01((k - 0.5 * distance) / 0.5))
        }
        let unit = self.unit
        let windows = CGMutablePath()
        for cell in self.cells {
            let s = grow(cell.distance)
            guard s > 0.01 else {
                continue
            }
            let w = unit * 1.5 * CGFloat(s)
            let r = min(w * 0.5, w * 0.5 * CGFloat(1.0 - 0.7 * Self.clamp01(s)))
            windows.addRoundedRect(in: CGRect(x: cell.center.x - w * 0.5, y: cell.center.y - w * 0.5, width: w, height: w), cornerWidth: r, cornerHeight: r)
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.revealMask.path = windows
        for eye in self.eyes {
            let s = max(0.001, CGFloat(grow(eye.distance)))
            eye.layer.transform = CATransform3DMakeScale(s, s, 1.0)
        }
        CATransaction.commit()
    }
}
