import UIKit
import Display
import TelegramPresentationData
import GlassBackgroundComponent

public final class WalletSendCommentBackgroundView: UIView {
    private struct Parameters: Equatable {
        let size: CGSize
        let scale: CGFloat
        let maxCornerRadius: CGFloat
        let minCornerRadius: CGFloat
        let incoming: Bool
        let hasTail: Bool
        let backgroundColor: UIColor
        let primaryTextColor: UIColor
        let isDark: Bool
    }

    private let imageView = UIImageView()
    private let glassHighlightRecognizer = GlassHighlightGestureRecognizer(target: nil, action: nil)
    private var parameters: Parameters?

    override public var isUserInteractionEnabled: Bool {
        didSet {
            self.glassHighlightRecognizer.isEnabled = self.isUserInteractionEnabled
            if !self.isUserInteractionEnabled {
                self.layer.removeAnimation(forKey: "sublayerTransform")
                self.layer.sublayerTransform = CATransform3DIdentity
            }
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)

        self.imageView.contentMode = .scaleToFill
        self.addSubview(self.imageView)
        self.addGestureRecognizer(self.glassHighlightRecognizer)
        self.isUserInteractionEnabled = false
    }

    required public init?(coder: NSCoder) {
        preconditionFailure()
    }

    public func update(size: CGSize, maxCornerRadius: CGFloat, minCornerRadius: CGFloat, theme: PresentationTheme, incoming: Bool = false, hasTail: Bool = true) {
        guard size.width > 0.0, size.height > 0.0 else { return }
        self.imageView.frame = CGRect(origin: .zero, size: size)
        // Keep the rounded ends and their glow fixed while the center stretches.
        let glowPadding = ceil(min(10.0, size.height * 0.24) * 2.0)
        let imageSize = CGSize(width: hasTail ? size.width : min(size.width, maxCornerRadius * 2.0 + glowPadding * 2.0 + 1.0), height: size.height)
        let parameters = Parameters(
            size: imageSize,
            scale: self.window?.screen.scale ?? UIScreen.main.scale,
            maxCornerRadius: maxCornerRadius,
            minCornerRadius: minCornerRadius,
            incoming: incoming,
            hasTail: hasTail,
            backgroundColor: theme.list.modalPlainBackgroundColor,
            primaryTextColor: theme.list.itemPrimaryTextColor,
            isDark: theme.overallDarkAppearance
        )
        guard self.parameters != parameters else { return }
        if let image = Self.generateImage(parameters: parameters) {
            self.parameters = parameters
            if hasTail {
                self.imageView.image = image
            } else {
                let capWidth = max(0.0, (imageSize.width - 1.0) * 0.5)
                self.imageView.image = image.resizableImage(withCapInsets: UIEdgeInsets(top: 0.0, left: capWidth, bottom: 0.0, right: capWidth), resizingMode: .stretch)
            }
        }
    }

    private static func generateImage(parameters: Parameters) -> UIImage? {
        let size = parameters.size
        let bounds = CGRect(origin: .zero, size: size)
        func roundedRectMask(inset: CGFloat) -> UIImage? {
            return Display.generateImage(size, scale: parameters.scale, rotatedContext: { _, context in
                context.clear(bounds)
                let cornerRadius = max(0.0, min(parameters.maxCornerRadius, min(size.width, size.height) * 0.5) - inset)
                context.addPath(CGPath(roundedRect: bounds.insetBy(dx: inset, dy: inset), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
                context.setFillColor(UIColor.white.cgColor)
                context.fillPath()
            })
        }
        let shapeMask: UIImage?
        if parameters.hasTail {
            let bubble = messageBubbleImage(
                maxCornerRadius: parameters.maxCornerRadius,
                minCornerRadius: parameters.minCornerRadius,
                incoming: parameters.incoming,
                fillColor: .white,
                strokeColor: .clear,
                neighbors: .none,
                shadow: nil,
                wallpaper: .color(0),
                knockout: false,
                mask: true
            )
            shapeMask = Display.generateImage(size, scale: parameters.scale, rotatedContext: { _, context in
                context.clear(bounds)
                UIGraphicsPushContext(context)
                bubble.draw(in: bounds)
                UIGraphicsPopContext()
            })
        } else {
            shapeMask = roundedRectMask(inset: 0.0)
        }
        guard let mask = shapeMask else { return nil }

        func insetMask(by inset: CGFloat) -> UIImage? {
            if !parameters.hasTail {
                return roundedRectMask(inset: inset)
            }
            return Display.generateImage(size, scale: parameters.scale, rotatedContext: { _, context in
                context.clear(bounds)
                UIGraphicsPushContext(context)
                mask.draw(in: bounds)
                for index in 0 ..< 8 {
                    let angle = CGFloat(index) * .pi / 4.0
                    mask.draw(
                        in: bounds.offsetBy(dx: cos(angle) * inset, dy: sin(angle) * inset),
                        blendMode: .destinationIn,
                        alpha: 1.0
                    )
                }
                UIGraphicsPopContext()
            })
        }
        let contourScale: CGFloat = parameters.isDark ? 0.5 : 1.0
        guard let borderMask = insetMask(by: contourScale / parameters.scale),
              let rimMask = insetMask(by: 0.65 * contourScale),
              let innerMask = insetMask(by: 1.4 * contourScale) else { return nil }

        let glowRadius = min(10.0, size.height * 0.24)
        let padding = ceil(glowRadius * 2.0)
        let outsideSize = CGSize(width: size.width + padding * 2.0, height: size.height + padding * 2.0)
        guard let outsideMask = Display.generateImage(outsideSize, scale: parameters.scale, rotatedContext: { _, context in
            context.setFillColor(UIColor.white.cgColor)
            context.fill(CGRect(origin: .zero, size: outsideSize))
            UIGraphicsPushContext(context)
            mask.draw(in: bounds.offsetBy(dx: padding, dy: padding), blendMode: .destinationOut, alpha: 1.0)
            UIGraphicsPopContext()
        }) else { return nil }

        let fillLocations: [CGFloat] = [0.0, 0.10, 0.23, 0.40, 0.54, 0.70, 0.82, 1.0]
        let fillColors: [CGColor]
        if parameters.isDark {
            let fillAmounts: [CGFloat] = [0.048, 0.026, 0.013, 0.013, 0.018, 0.018, 0.022, 0.048]
            fillColors = fillAmounts.map { amount in
                parameters.backgroundColor.mixedWith(parameters.primaryTextColor, alpha: amount).cgColor
            }
        } else {
            let fillShades: [UInt32] = [0xfafafb, 0xf9f9fa, 0xf6f6f7, 0xf4f4f5, 0xf6f6f7, 0xf8f8f9, 0xf9f9fa, 0xfafafb]
            fillColors = fillShades.map { UIColor(rgb: $0).cgColor }
        }
        guard let fillGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: fillColors as CFArray, locations: fillLocations) else { return nil }
        let highlightColor: UIColor
        if parameters.isDark {
            var hue: CGFloat = 0.0
            var saturation: CGFloat = 0.0
            parameters.backgroundColor.getHue(&hue, saturation: &saturation, brightness: nil, alpha: nil)
            highlightColor = UIColor(hue: hue, saturation: saturation * 0.65, brightness: parameters.primaryTextColor.brightness, alpha: 1.0)
        } else {
            highlightColor = .white
        }

        let borderLocations: [CGFloat] = [0.0, 0.20, 0.50, 0.80, 1.0]
        let borderAmounts: [CGFloat] = parameters.isDark ? [0.26, 0.075, 0.013, 0.075, 0.26] : [0.10, 0.24, 0.33, 0.24, 0.11]
        let borderColors = borderAmounts.map { amount in
            parameters.backgroundColor.mixedWith(parameters.isDark ? highlightColor : parameters.primaryTextColor, alpha: amount).cgColor
        }
        guard let borderGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: borderColors as CFArray, locations: borderLocations) else { return nil }
        let glowColor = highlightColor.withAlphaComponent(parameters.isDark ? 0.025 : 0.9)
        let highlightAmounts: [CGFloat] = parameters.isDark ? [0.14, 0.03, 0.0, 0.03, 0.14] : [0.94, 0.94, 0.94, 0.94, 0.94]
        let highlightColors = highlightAmounts.map { highlightColor.withAlphaComponent($0).cgColor }
        guard let highlightGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: highlightColors as CFArray, locations: borderLocations) else { return nil }

        return Display.generateImage(size, scale: parameters.scale, rotatedContext: { _, context in
            let fillInset = parameters.hasTail ? min(2.0, size.height * 0.1) : 0.0
            context.drawLinearGradient(
                fillGradient,
                start: CGPoint(x: 0.0, y: fillInset),
                end: CGPoint(x: 0.0, y: size.height - fillInset),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
            UIGraphicsPushContext(context)

            context.saveGState()
            context.setShadow(offset: .zero, blur: glowRadius, color: glowColor.cgColor)
            outsideMask.draw(in: CGRect(x: -padding, y: -padding, width: outsideSize.width, height: outsideSize.height))
            context.restoreGState()
            mask.draw(in: bounds, blendMode: .destinationIn, alpha: 1.0)

            func drawRing(outer: UIImage, inner: UIImage, fill: () -> Void) {
                context.saveGState()
                context.beginTransparencyLayer(auxiliaryInfo: nil)
                outer.draw(in: bounds)
                inner.draw(in: bounds, blendMode: .destinationOut, alpha: 1.0)
                context.setBlendMode(.sourceIn)
                fill()
                context.setBlendMode(.normal)
                context.endTransparencyLayer()
                context.restoreGState()
            }
            drawRing(outer: mask, inner: borderMask) {
                context.drawLinearGradient(
                    borderGradient,
                    start: CGPoint(x: 0.0, y: fillInset),
                    end: CGPoint(x: 0.0, y: size.height - fillInset),
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                )
            }
            drawRing(outer: rimMask, inner: innerMask) {
                context.drawLinearGradient(
                    highlightGradient,
                    start: CGPoint(x: 0.0, y: fillInset),
                    end: CGPoint(x: 0.0, y: size.height - fillInset),
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                )
            }
            UIGraphicsPopContext()
        })
    }
}
