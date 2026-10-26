import UIKit
import Display
import QrCode

final class WalletReceiveQrRevealView: UIView {
    private let image: UIImage
    private let moduleCount: Int

    init(image: UIImage, moduleCount: Int) {
        self.image = image
        self.moduleCount = moduleCount

        super.init(frame: CGRect(origin: .zero, size: image.size))

        self.isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func animateIn(delay: Double, duration: Double) {
        let imageSize = self.image.size
        let (_, _, moduleSide) = qrCodeCutout(size: self.moduleCount, dimensions: imageSize, scale: self.image.scale)
        guard let cgImage = self.image.cgImage, moduleSide > 0.0, self.moduleCount >= 21 else {
            return
        }
        let padding = round((imageSize.width - moduleSide * CGFloat(self.moduleCount)) * 0.5 * self.image.scale) / self.image.scale

        // Include each finder's white separator so the rounded marker can grow as one piece.
        let markerModuleCount = 9
        let markerOrigins = [
            CGPoint(x: 0.0, y: 0.0),
            CGPoint(x: CGFloat(self.moduleCount - markerModuleCount), y: 0.0),
            CGPoint(x: 0.0, y: CGFloat(self.moduleCount - markerModuleCount))
        ]
        let markerFrames = markerOrigins.map { origin in
            return CGRect(
                x: padding + origin.x * moduleSide,
                y: padding + origin.y * moduleSide,
                width: CGFloat(markerModuleCount) * moduleSide,
                height: CGFloat(markerModuleCount) * moduleSide
            )
        }

        let codeLayer = CALayer()
        codeLayer.frame = CGRect(origin: .zero, size: imageSize)
        codeLayer.contents = cgImage
        codeLayer.contentsScale = self.image.scale
        self.layer.addSublayer(codeLayer)

        let revealMask = CALayer()
        revealMask.frame = codeLayer.bounds
        revealMask.contentsScale = self.image.scale
        codeLayer.mask = revealMask

        // Keep every module at its final position and size; only fade its mask in.
        // Using the original raster preserves both rounded corners and concave joins.
        let batchCount = 48
        var batches = Array(repeating: [CGRect](), count: batchCount)
        let center = CGFloat(self.moduleCount - 1) * 0.5
        for y in 0 ..< self.moduleCount {
            for x in 0 ..< self.moduleCount {
                if (y < markerModuleCount && (x < markerModuleCount || x >= self.moduleCount - markerModuleCount))
                    || (y >= self.moduleCount - markerModuleCount && x < markerModuleCount) {
                    continue
                }
                let frame = CGRect(
                    x: padding + CGFloat(x) * moduleSide,
                    y: padding + CGFloat(y) * moduleSide,
                    width: moduleSide,
                    height: moduleSide
                )
                // Sweep inward while winding the reveal clockwise around the stone.
                // Keep a little jitter so individual modules appear organically.
                let distanceToEdge = min(min(x, y), min(self.moduleCount - 1 - x, self.moduleCount - 1 - y))
                let inwardProgress = Double(CGFloat(distanceToEdge) / center)
                let dx = Double(CGFloat(x) - center)
                let dy = Double(CGFloat(y) - center)
                let angle = (atan2(dy, dx) + Double.pi) / (2.0 * Double.pi)
                let radius = hypot(dx, dy) / Double(center)
                let spiralPosition = angle + radius * 1.25
                let spiralPhase = spiralPosition - floor(spiralPosition)
                let phase = inwardProgress * 0.55 + spiralPhase * 0.4 + Double.random(in: 0.0 ... 0.05)
                let batchIndex = min(batchCount - 1, Int(phase * Double(batchCount - 1)))
                batches[batchIndex].append(frame)
            }
        }

        for (index, frames) in batches.enumerated() {
            let path = CGMutablePath()
            for frame in frames {
                path.addRect(frame)
            }

            let batchLayer = CAShapeLayer()
            batchLayer.frame = revealMask.bounds
            batchLayer.contentsScale = self.image.scale
            batchLayer.fillColor = UIColor.black.cgColor
            batchLayer.path = path
            revealMask.addSublayer(batchLayer)
            batchLayer.animateAlpha(
                from: 0.0,
                to: 1.0,
                duration: 0.12,
                delay: delay + Double(index) / Double(batchCount - 1) * max(0.0, duration - 0.12),
                timingFunction: CAMediaTimingFunctionName.easeOut.rawValue
            )
        }

        for frame in markerFrames {
            let markerLayer = CALayer()
            markerLayer.frame = frame
            markerLayer.contents = cgImage
            markerLayer.contentsScale = self.image.scale
            markerLayer.contentsRect = CGRect(
                x: frame.minX / imageSize.width,
                y: frame.minY / imageSize.height,
                width: frame.width / imageSize.width,
                height: frame.height / imageSize.height
            )
            self.layer.addSublayer(markerLayer)

            markerLayer.animateScale(from: 0.01, to: 1.0, duration: 0.5, delay: delay, timingFunction: kCAMediaTimingFunctionSpring)
            markerLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.12, delay: delay)
        }
    }
}
