import Foundation
import UIKit
import CoreText
import Metal
import MetalEngine
import Display
import AccountContext
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import MultilineTextComponent
import BundleIconComponent
import GlassBarButtonComponent
import ButtonComponent
import QrCode
import PremiumDiamondComponent

private final class WalletReceiveQrComponent: Component {
    let address: String
    let theme: PresentationTheme
    let isVisible: Bool

    init(address: String, theme: PresentationTheme, isVisible: Bool) {
        self.address = address
        self.theme = theme
        self.isVisible = isVisible
    }

    static func ==(lhs: WalletReceiveQrComponent, rhs: WalletReceiveQrComponent) -> Bool {
        return lhs.address == rhs.address && lhs.theme === rhs.theme && lhs.isVisible == rhs.isVisible
    }

    final class View: UIView {
        private static let introDelay = 0.03
        private static let qrRevealDuration = 0.5
        private static let diamondIntroSpeed = 1.5
        private static var diamondIntroDuration: Double {
            return Self.introDelay + (InteractiveDiamondIntro.duration - InteractiveDiamondIntro.delay) / Self.diamondIntroSpeed
        }

        private var component: WalletReceiveQrComponent?
        private let imageNode: TransformImageNode
        private let diamond = ComponentView<Empty>()
        private var qrCodeSize: Int?
        private var refractionImage: UIImage?
        private var refractionTexture: MTLTexture?
        private var revealView: WalletReceiveQrRevealView?
        private var revealStartTime: CFTimeInterval?
        private var revealDisplayLink: SharedDisplayLinkDriver.Link?
        private var diamondFrame: CGRect = .zero
        private var didAnimateIn = false
        private var isUpdating = false

        override init(frame: CGRect) {
            self.imageNode = TransformImageNode()

            super.init(frame: frame)

            self.backgroundColor = .white
            self.addSubview(self.imageNode.view)
            self.imageNode.imageUpdated = { [weak self] _ in
                guard let self, !self.isUpdating else {
                    return
                }
                self.updateRevealAnimation()
                self.updateDiamondRefraction()
            }
            NotificationCenter.default.addObserver(self, selector: #selector(self.stopRevealAnimation), name: UIApplication.didEnterBackgroundNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.stopRevealAnimation), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.revealDisplayLink?.invalidate()
            NotificationCenter.default.removeObserver(self)
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()

            self.updateRevealAnimation()
        }

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard self.isUserInteractionEnabled, !self.isHidden, self.alpha > 0.01,
                  self.component?.isVisible == true,
                  let diamondView = self.diamond.view as? InteractiveDiamondComponent.View else {
                return nil
            }
            return diamondView.hitTest(diamondView.convert(point, from: self), with: event)
        }

        private func finishRevealAnimation() {
            self.revealDisplayLink?.invalidate()
            self.revealDisplayLink = nil
            self.revealStartTime = nil
            let revealView = self.revealView
            self.revealView = nil
            revealView?.removeFromSuperview()
            self.imageNode.isHidden = false
            if let diamondView = self.diamond.view as? InteractiveDiamondComponent.View {
                diamondView.updateOpeningScale(nil)
                diamondView.frame = self.diamondFrame
            }
        }

        @objc private func stopRevealAnimation() {
            self.finishRevealAnimation()
        }

        private func updateDiamondIntro() {
            guard let startTime = self.revealStartTime,
                  let diamondView = self.diamond.view as? InteractiveDiamondComponent.View else {
                return
            }
            let elapsed = CACurrentMediaTime() - startTime
            guard elapsed < max(Self.diamondIntroDuration, Self.introDelay + Self.qrRevealDuration),
                  self.window != nil, self.component?.isVisible == true,
                  UIApplication.shared.applicationState != .background,
                  !UIAccessibility.isReduceMotionEnabled else {
                self.finishRevealAnimation()
                return
            }
            let introTime = elapsed + InteractiveDiamondIntro.delay - Self.introDelay
            let intro = InteractiveDiamondIntro(time: introTime, speed: Self.diamondIntroSpeed, damping: 0.64)
            let bounceAmplitude: CGFloat = intro.progress > 1.0 ? 0.49 : 1.0
            let scale = 1.0 + (intro.scale(from: 5.0, allowsOvershoot: true) - 1.0) * bounceAmplitude
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            diamondView.clipsToBounds = false
            diamondView.center = CGPoint(x: self.diamondFrame.midX, y: self.diamondFrame.midY + intro.lift * bounceAmplitude)
            diamondView.updateOpeningScale(elapsed < Self.diamondIntroDuration ? scale : nil)
            CATransaction.commit()
        }

        private func updateRevealAnimation() {
            guard let component = self.component else {
                return
            }
            guard self.window != nil, component.isVisible, UIApplication.shared.applicationState != .background else {
                self.finishRevealAnimation()
                return
            }
            if UIAccessibility.isReduceMotionEnabled {
                self.didAnimateIn = true
                self.finishRevealAnimation()
                return
            }
            guard !self.didAnimateIn, let image = self.imageNode.image, let qrCodeSize = self.qrCodeSize,
                  self.diamond.view is InteractiveDiamondComponent.View,
                  self.imageNode.bounds.width > 0.0 else {
                return
            }
            self.didAnimateIn = true

            let revealView = WalletReceiveQrRevealView(image: image, moduleCount: qrCodeSize)
            revealView.frame = self.imageNode.frame
            self.revealView = revealView
            self.insertSubview(revealView, aboveSubview: self.imageNode.view)
            self.imageNode.isHidden = true
            self.revealStartTime = CACurrentMediaTime()
            revealView.animateIn(delay: Self.introDelay, duration: Self.qrRevealDuration)
            self.updateDiamondIntro()
            self.revealDisplayLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] _ in
                self?.updateDiamondIntro()
            })
        }

        private func updateDiamondRefraction() {
            guard let diamondView = self.diamond.view as? InteractiveDiamondComponent.View else { return }
            guard diamondView.isExpanded, let image = self.imageNode.image, let cgImage = image.cgImage else {
                diamondView.updateRefractionSource(nil)
                return
            }
            if self.refractionImage !== image {
                self.refractionTexture = nil
                self.refractionImage = nil
                let width = cgImage.width
                let height = cgImage.height
                guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue),
                    let bytes = context.data else {
                    diamondView.updateRefractionSource(nil)
                    return
                }
                context.translateBy(x: 0.0, y: CGFloat(height))
                context.scaleBy(x: 1.0, y: -1.0)
                UIGraphicsPushContext(context)
                image.draw(in: CGRect(x: 0.0, y: 0.0, width: CGFloat(width), height: CGFloat(height)))
                UIGraphicsPopContext()

                // Black modules with transparent gaps, including their antialiased edges.
                // The QR's white backing should not cover the diamond's facets.
                let pixels = bytes.assumingMemoryBound(to: UInt8.self)
                for y in 0 ..< height {
                    for x in 0 ..< width {
                        let offset = y * context.bytesPerRow + x * 4
                        let alpha = 255 - pixels[offset + 2]
                        pixels[offset] = 0
                        pixels[offset + 1] = 0
                        pixels[offset + 2] = 0
                        pixels[offset + 3] = alpha
                    }
                }
                let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
                descriptor.storageMode = .shared
                descriptor.usage = .shaderRead
                guard let texture = MetalEngine.shared.device.makeTexture(descriptor: descriptor) else {
                    diamondView.updateRefractionSource(nil)
                    return
                }
                texture.label = "Wallet receive QR refraction"
                texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: bytes, bytesPerRow: context.bytesPerRow)
                self.refractionImage = image
                self.refractionTexture = texture
            }
            guard let texture = self.refractionTexture else { return }
            let rect = self.imageNode.view.convert(self.imageNode.bounds, to: diamondView)
                .offsetBy(dx: -diamondView.bounds.midX, dy: -diamondView.bounds.midY)
            diamondView.updateRefractionSource(InteractiveDiamondComponent.RefractionSource(
                texture: texture, uv: SIMD4(0.0, 0.0, 1.0, 1.0), rect: rect, preservesColors: true
            ))
        }

        func update(
            component: WalletReceiveQrComponent,
            availableSize: CGSize
        ) -> CGSize {
            self.isUpdating = true
            let previousComponent = self.component
            self.component = component

            if previousComponent?.address != component.address {
                self.finishRevealAnimation()
                self.didAnimateIn = false
                self.qrCodeSize = nil
                self.refractionImage = nil
                self.refractionTexture = nil
                (self.diamond.view as? InteractiveDiamondComponent.View)?.updateRefractionSource(nil)
                self.imageNode.reset()
                self.imageNode.setSignal(
                    qrCode(
                        string: "ton://transfer/\(component.address)",
                        color: .black,
                        backgroundColor: .white,
                        icon: .cutout,
                        ecl: "Q"
                    )
                    |> beforeNext { [weak self] size, _ in
                        self?.qrCodeSize = size
                    }
                    |> map { $0.1 },
                    attemptSynchronously: true
                )
            }

            let side = min(availableSize.width, availableSize.height)
            let size = CGSize(width: side, height: side)
            let imageInset = min(6.0, max(0.0, (side - 1.0) / 2.0))
            let imageSide = max(1.0, side - imageInset * 2.0)
            let imageSize = CGSize(width: imageSide, height: imageSide)
            if self.imageNode.bounds.size != imageSize {
                self.finishRevealAnimation()
            }

            let makeImageLayout = self.imageNode.asyncLayout()
            let imageApply = makeImageLayout(TransformImageArguments(
                corners: ImageCorners(),
                imageSize: imageSize,
                boundingSize: imageSize,
                intrinsicInsets: .zero,
                emptyColor: nil
            ))
            let _ = imageApply()
            self.imageNode.frame = CGRect(
                origin: CGPoint(x: imageInset, y: imageInset),
                size: imageSize
            )

            if let qrCodeSize = self.qrCodeSize {
                let (_, cutoutFrame, _) = qrCodeCutout(size: qrCodeSize, dimensions: imageSize, scale: nil)
                let _ = self.diamond.update(
                    transition: .immediate,
                    component: AnyComponent(InteractiveDiamondComponent(
                        size: cutoutFrame.size,
                        diamondWidth: cutoutFrame.width * 0.72,
                        isVisible: component.isVisible,
                        theme: component.theme,
                        animationMode: .continuous
                    )),
                    environment: {},
                    containerSize: cutoutFrame.size
                )
                if let diamondView = self.diamond.view as? InteractiveDiamondComponent.View {
                    if diamondView.superview == nil {
                        diamondView.clipsToBounds = false
                        diamondView.onExpansionChanged = { [weak self] expanded in
                            guard let self else { return }
                            if expanded, self.revealStartTime != nil {
                                self.finishRevealAnimation()
                            }
                            self.updateDiamondRefraction()
                        }
                        self.addSubview(diamondView)
                    }
                    self.diamondFrame = cutoutFrame.offsetBy(dx: imageInset, dy: imageInset)
                    diamondView.frame = self.diamondFrame
                    self.updateDiamondIntro()
                }
            }

            self.isUpdating = false
            self.updateRevealAnimation()
            self.updateDiamondRefraction()

            return size
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<Empty>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(component: self, availableSize: availableSize)
    }
}

private final class WalletReceiveAddressRingComponent: Component {
    let address: String
    let color: UIColor
    let cardSize: CGSize
    let cardCornerRadius: CGFloat
    let pathOffset: CGFloat

    init(
        address: String,
        color: UIColor,
        cardSize: CGSize,
        cardCornerRadius: CGFloat,
        pathOffset: CGFloat
    ) {
        self.address = address
        self.color = color
        self.cardSize = cardSize
        self.cardCornerRadius = cardCornerRadius
        self.pathOffset = pathOffset
    }

    static func ==(lhs: WalletReceiveAddressRingComponent, rhs: WalletReceiveAddressRingComponent) -> Bool {
        if lhs.address != rhs.address {
            return false
        }
        if lhs.color != rhs.color {
            return false
        }
        if lhs.cardSize != rhs.cardSize {
            return false
        }
        if lhs.cardCornerRadius != rhs.cardCornerRadius {
            return false
        }
        if lhs.pathOffset != rhs.pathOffset {
            return false
        }
        return true
    }

    final class View: UIView {
        private static let animationSpeed: CGFloat = 18.0

        private struct RoundedRectPerimeter {
            struct Sample {
                let point: CGPoint
                let tangent: CGVector
            }

            let rect: CGRect
            let radius: CGFloat
            let horizontalLength: CGFloat
            let verticalLength: CGFloat
            let cornerLength: CGFloat
            let length: CGFloat

            init?(rect inputRect: CGRect, radius proposedRadius: CGFloat) {
                guard inputRect.origin.x.isFinite, inputRect.origin.y.isFinite,
                      inputRect.width.isFinite, inputRect.height.isFinite,
                      proposedRadius.isFinite else {
                    return nil
                }

                let rect = inputRect.standardized
                guard rect.width > 0.0, rect.height > 0.0 else {
                    return nil
                }

                let radius = min(max(0.0, proposedRadius), min(rect.width, rect.height) * 0.5)
                let horizontalLength = max(0.0, rect.width - radius * 2.0)
                let verticalLength = max(0.0, rect.height - radius * 2.0)
                let cornerLength = CGFloat.pi * radius * 0.5
                let length = horizontalLength * 2.0 + verticalLength * 2.0 + cornerLength * 4.0
                guard length.isFinite, length > 0.0 else {
                    return nil
                }

                self.rect = rect
                self.radius = radius
                self.horizontalLength = horizontalLength
                self.verticalLength = verticalLength
                self.cornerLength = cornerLength
                self.length = length
            }

            private func arcSample(center: CGPoint, angle: CGFloat) -> Sample {
                let sine = sin(angle)
                let cosine = cos(angle)
                return Sample(
                    point: CGPoint(
                        x: center.x + self.radius * cosine,
                        y: center.y + self.radius * sine
                    ),
                    tangent: CGVector(dx: -sine, dy: cosine)
                )
            }

            func sample(at distance: CGFloat) -> Sample {
                var normalizedDistance: CGFloat
                if distance.isFinite {
                    normalizedDistance = distance.truncatingRemainder(dividingBy: self.length)
                } else {
                    normalizedDistance = 0.0
                }
                if normalizedDistance < 0.0 {
                    normalizedDistance += self.length
                }

                var segmentDistance = normalizedDistance + self.horizontalLength * 0.5
                if segmentDistance >= self.length {
                    segmentDistance -= self.length
                }

                if self.horizontalLength > 0.0 && segmentDistance < self.horizontalLength {
                    return Sample(
                        point: CGPoint(
                            x: self.rect.minX + self.radius + segmentDistance,
                            y: self.rect.minY
                        ),
                        tangent: CGVector(dx: 1.0, dy: 0.0)
                    )
                }
                segmentDistance -= self.horizontalLength

                if self.cornerLength > 0.0 && segmentDistance < self.cornerLength {
                    return self.arcSample(
                        center: CGPoint(x: self.rect.maxX - self.radius, y: self.rect.minY + self.radius),
                        angle: -.pi * 0.5 + segmentDistance / self.radius
                    )
                }
                segmentDistance -= self.cornerLength

                if self.verticalLength > 0.0 && segmentDistance < self.verticalLength {
                    return Sample(
                        point: CGPoint(
                            x: self.rect.maxX,
                            y: self.rect.minY + self.radius + segmentDistance
                        ),
                        tangent: CGVector(dx: 0.0, dy: 1.0)
                    )
                }
                segmentDistance -= self.verticalLength

                if self.cornerLength > 0.0 && segmentDistance < self.cornerLength {
                    return self.arcSample(
                        center: CGPoint(x: self.rect.maxX - self.radius, y: self.rect.maxY - self.radius),
                        angle: segmentDistance / self.radius
                    )
                }
                segmentDistance -= self.cornerLength

                if self.horizontalLength > 0.0 && segmentDistance < self.horizontalLength {
                    return Sample(
                        point: CGPoint(
                            x: self.rect.maxX - self.radius - segmentDistance,
                            y: self.rect.maxY
                        ),
                        tangent: CGVector(dx: -1.0, dy: 0.0)
                    )
                }
                segmentDistance -= self.horizontalLength

                if self.cornerLength > 0.0 && segmentDistance < self.cornerLength {
                    return self.arcSample(
                        center: CGPoint(x: self.rect.minX + self.radius, y: self.rect.maxY - self.radius),
                        angle: .pi * 0.5 + segmentDistance / self.radius
                    )
                }
                segmentDistance -= self.cornerLength

                if self.verticalLength > 0.0 && segmentDistance < self.verticalLength {
                    return Sample(
                        point: CGPoint(
                            x: self.rect.minX,
                            y: self.rect.maxY - self.radius - segmentDistance
                        ),
                        tangent: CGVector(dx: 0.0, dy: -1.0)
                    )
                }
                segmentDistance -= self.verticalLength

                if self.cornerLength > 0.0 && segmentDistance < self.cornerLength {
                    return self.arcSample(
                        center: CGPoint(x: self.rect.minX + self.radius, y: self.rect.minY + self.radius),
                        angle: .pi + segmentDistance / self.radius
                    )
                }

                return Sample(
                    point: CGPoint(x: self.rect.minX + self.radius, y: self.rect.minY),
                    tangent: CGVector(dx: 1.0, dy: 0.0)
                )
            }
        }

        private struct GlyphItem {
            let path: CGPath?
            let position: CGPoint
            let advance: CGFloat
        }

        private struct GlyphLayout {
            let items: [GlyphItem]
            let width: CGFloat
        }

        private var component: WalletReceiveAddressRingComponent?
        private var availableSize: CGSize = .zero
        private var cachedGlyphLayout: (text: String, fontSize: CGFloat, layout: GlyphLayout)?
        private var animationOffset: CGFloat = 0.0
        private var animationCycleLength: CGFloat?
        private var displayLink: SharedDisplayLinkDriver.Link?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.isOpaque = false
            self.backgroundColor = .clear
            self.contentMode = .redraw
            self.isUserInteractionEnabled = false
            self.isAccessibilityElement = false
            self.accessibilityElementsHidden = true

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.reduceMotionStatusDidChange),
                name: UIAccessibility.reduceMotionStatusDidChangeNotification,
                object: nil
            )
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.stopAnimation()
            NotificationCenter.default.removeObserver(self)
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()

            self.updateAnimationState()
        }

        private func updateAnimationState() {
            let shouldAnimate = self.window != nil
                && self.component?.address.isEmpty == false
                && !UIAccessibility.isReduceMotionEnabled
            if shouldAnimate {
                if self.displayLink == nil {
                    self.displayLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .fps(60), { [weak self] deltaTime in
                        self?.advanceAnimation(deltaTime: deltaTime)
                    })
                }
            } else {
                self.stopAnimation()
            }
        }

        private func stopAnimation() {
            self.displayLink?.invalidate()
            self.displayLink = nil
        }

        private func advanceAnimation(deltaTime: CGFloat) {
            guard deltaTime.isFinite, deltaTime > 0.0 else {
                return
            }

            self.animationOffset += deltaTime * Self.animationSpeed
            if let animationCycleLength = self.animationCycleLength, animationCycleLength > 0.0 {
                self.animationOffset = self.animationOffset.truncatingRemainder(dividingBy: animationCycleLength)
            }
            self.setNeedsDisplay()
        }

        @objc private func reduceMotionStatusDidChange() {
            self.updateAnimationState()
        }

        private static func groupedAddress(_ address: String) -> [String] {
            var result: [String] = []
            var index = address.startIndex
            while index < address.endIndex {
                let endIndex = address.index(index, offsetBy: 4, limitedBy: address.endIndex) ?? address.endIndex
                result.append(String(address[index ..< endIndex]))
                index = endIndex
            }
            return result
        }

        private static func glyphLayout(text: String, font: UIFont) -> GlyphLayout? {
            let line = CTLineCreateWithAttributedString(NSAttributedString(
                string: text,
                attributes: [.font: font]
            ))

            var items: [GlyphItem] = []
            let glyphRuns = CTLineGetGlyphRuns(line) as NSArray
            for runValue in glyphRuns {
                let run = runValue as! CTRun
                let glyphCount = CTRunGetGlyphCount(run)
                if glyphCount == 0 {
                    continue
                }

                var glyphs = [CGGlyph](repeating: 0, count: glyphCount)
                var positions = [CGPoint](repeating: .zero, count: glyphCount)
                var advances = [CGSize](repeating: .zero, count: glyphCount)
                let range = CFRangeMake(0, glyphCount)
                CTRunGetGlyphs(run, range, &glyphs)
                CTRunGetPositions(run, range, &positions)
                CTRunGetAdvances(run, range, &advances)

                let attributes = CTRunGetAttributes(run) as NSDictionary
                guard let runFont = attributes[kCTFontAttributeName] as! CTFont? else {
                    continue
                }

                let baselineOffset = (CTFontGetDescent(runFont) - CTFontGetAscent(runFont)) * 0.5
                for index in 0 ..< glyphCount {
                    let advance = max(0.0, advances[index].width)
                    var transform = CGAffineTransform(translationX: -advance * 0.5, y: baselineOffset)
                    let path = CTFontCreatePathForGlyph(runFont, glyphs[index], &transform)
                    items.append(GlyphItem(
                        path: path,
                        position: positions[index],
                        advance: advance
                    ))
                }
            }

            items.sort { lhs, rhs in
                return lhs.position.x < rhs.position.x
            }
            guard !items.isEmpty else {
                return nil
            }

            var width: CGFloat = 0.0
            for item in items {
                width = max(width, item.position.x + item.advance)
            }
            guard width.isFinite, width > 0.0 else {
                return nil
            }

            return GlyphLayout(items: items, width: width)
        }

        override func draw(_ rect: CGRect) {
            guard let component = self.component, !component.address.isEmpty,
                  let graphicsContext = UIGraphicsGetCurrentContext() else {
                return
            }

            let bounds = self.bounds
            guard bounds.origin.x.isFinite, bounds.origin.y.isFinite,
                  bounds.width.isFinite, bounds.height.isFinite,
                  bounds.width > 0.0, bounds.height > 0.0,
                  component.cardSize.width.isFinite, component.cardSize.height.isFinite,
                  component.cardCornerRadius.isFinite, component.pathOffset.isFinite else {
                return
            }

            let groupedAddress = Self.groupedAddress(component.address)
                .joined(separator: " ")
                .uppercased()
            guard !groupedAddress.isEmpty else {
                return
            }

            let baseFontSize: CGFloat = max(8.0, min(11.0, bounds.width / 31.0)) * 1.2
            let baseFont = Font.with(size: baseFontSize, design: .monospace, weight: .semibold)

            let cardSize = CGSize(
                width: max(0.0, component.cardSize.width),
                height: max(0.0, component.cardSize.height)
            )
            let cardRect = CGRect(
                x: bounds.midX - cardSize.width * 0.5,
                y: bounds.midY - cardSize.height * 0.5,
                width: cardSize.width,
                height: cardSize.height
            )
            let pathOffset = max(0.0, component.pathOffset)
            let desiredPathRect = cardRect.insetBy(dx: -pathOffset, dy: -pathOffset)

            let glyphInset = ceil(baseFont.lineHeight * 0.5)
            let safeInsetX = min(glyphInset, max(0.0, (bounds.width - 1.0) * 0.5))
            let safeInsetY = min(glyphInset, max(0.0, (bounds.height - 1.0) * 0.5))
            let safeBounds = bounds.insetBy(dx: safeInsetX, dy: safeInsetY)
            let pathRect = desiredPathRect.intersection(safeBounds)
            guard !pathRect.isNull, !pathRect.isEmpty else {
                return
            }

            let cardCornerRadius = min(
                max(0.0, component.cardCornerRadius),
                min(cardRect.width, cardRect.height) * 0.5
            )
            guard let perimeter = RoundedRectPerimeter(
                rect: pathRect,
                radius: cardCornerRadius + pathOffset
            ) else {
                return
            }

            let halfLength = perimeter.length * 0.5
            guard halfLength.isFinite, halfLength > 0.0 else {
                return
            }

            let unitText = "· \(groupedAddress) "
            let glyphLayout: GlyphLayout
            if let cachedGlyphLayout = self.cachedGlyphLayout,
               cachedGlyphLayout.text == unitText,
               cachedGlyphLayout.fontSize == baseFontSize {
                glyphLayout = cachedGlyphLayout.layout
            } else {
                guard let updatedGlyphLayout = Self.glyphLayout(text: unitText, font: baseFont) else {
                    return
                }
                self.cachedGlyphLayout = (unitText, baseFontSize, updatedGlyphLayout)
                glyphLayout = updatedGlyphLayout
            }
            let glyphScale: CGFloat
            if glyphLayout.width > halfLength {
                glyphScale = halfLength / glyphLayout.width * 0.99
            } else {
                glyphScale = 1.0
            }
            guard glyphScale.isFinite, glyphScale > 0.0 else {
                return
            }

            let tracking = max(
                0.0,
                (halfLength - glyphLayout.width * glyphScale) / CGFloat(glyphLayout.items.count)
            )
            guard let firstItem = glyphLayout.items.first else {
                return
            }
            let firstCenter = (firstItem.position.x + firstItem.advance * 0.5) * glyphScale
            self.animationCycleLength = halfLength
            self.animationOffset = self.animationOffset.truncatingRemainder(dividingBy: halfLength)

            graphicsContext.saveGState()
            graphicsContext.setFillColor(component.color.cgColor)
            graphicsContext.setAllowsAntialiasing(true)
            graphicsContext.setShouldAntialias(true)

            for copyIndex in 0 ..< 2 {
                let copyOffset = CGFloat(copyIndex) * halfLength
                for index in 0 ..< glyphLayout.items.count {
                    let item = glyphLayout.items[index]
                    guard let path = item.path else {
                        continue
                    }
                    let centerOffset = (item.position.x + item.advance * 0.5) * glyphScale - firstCenter
                    let distance = self.animationOffset + copyOffset + centerOffset + CGFloat(index) * tracking
                    let sample = perimeter.sample(at: distance)
                    let angle = atan2(sample.tangent.dy, sample.tangent.dx)

                    graphicsContext.saveGState()
                    graphicsContext.translateBy(x: sample.point.x, y: sample.point.y)
                    graphicsContext.rotate(by: angle)
                    graphicsContext.scaleBy(x: glyphScale, y: -glyphScale)
                    graphicsContext.addPath(path)
                    graphicsContext.fillPath()
                    graphicsContext.restoreGState()
                }
            }

            graphicsContext.restoreGState()
        }

        func update(
            component: WalletReceiveAddressRingComponent,
            availableSize: CGSize
        ) -> CGSize {
            let needsDisplay: Bool
            if let currentComponent = self.component {
                needsDisplay = currentComponent != component || self.availableSize != availableSize
            } else {
                needsDisplay = true
            }

            self.component = component
            self.availableSize = availableSize
            self.updateAnimationState()
            if needsDisplay {
                self.setNeedsDisplay()
            }

            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<Empty>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(component: self, availableSize: availableSize)
    }
}

private final class WalletReceiveAddressGridComponent: Component {
    let address: String

    init(address: String) {
        self.address = address
    }

    static func ==(lhs: WalletReceiveAddressGridComponent, rhs: WalletReceiveAddressGridComponent) -> Bool {
        return lhs.address == rhs.address
    }

    final class View: UIView {
        private var labels: [UILabel] = []

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private static func groupedAddress(_ address: String) -> [String] {
            var result: [String] = []
            var index = address.startIndex
            while index < address.endIndex {
                let endIndex = address.index(index, offsetBy: 4, limitedBy: address.endIndex) ?? address.endIndex
                result.append(String(address[index ..< endIndex]))
                index = endIndex
            }
            return result
        }

        func update(
            component: WalletReceiveAddressGridComponent,
            availableSize: CGSize,
            transition: ComponentTransition
        ) -> CGSize {
            let groups = Self.groupedAddress(component.address)
            while self.labels.count < groups.count {
                let label = UILabel()
                label.backgroundColor = .clear
                label.font = Font.with(size: 17.0, design: .monospace, weight: .semibold)
                label.textAlignment = .center
                self.labels.append(label)
                self.addSubview(label)
            }

            let columnCount = 3
            let rowCount = Int(ceil(CGFloat(groups.count) / CGFloat(columnCount)))
            let width = min(192.0, max(1.0, availableSize.width))
            let rowHeight: CGFloat = 26.0
            let cellWidth = width / CGFloat(columnCount)

            for index in 0 ..< self.labels.count {
                let label = self.labels[index]
                guard index < groups.count else {
                    label.isHidden = true
                    continue
                }
                label.isHidden = false
                label.text = groups[index]
                label.textColor = index.isMultiple(of: 2) ? .black : UIColor(rgb: 0x8e8e93)

                let column = index % columnCount
                let row = index / columnCount
                transition.setFrame(
                    view: label,
                    frame: CGRect(
                        x: CGFloat(column) * cellWidth,
                        y: CGFloat(row) * rowHeight,
                        width: cellWidth,
                        height: rowHeight
                    )
                )
            }

            return CGSize(width: width, height: CGFloat(rowCount) * rowHeight)
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<Empty>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

private final class WalletReceiveSheetContent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let address: String
    let containerHeight: CGFloat
    let isPurchaseInProgress: Bool
    let isOpeningPurchase: Bool
    let animateOut: ActionSlot<Action<Void>>
    let getController: () -> ViewController?
    let buy: () -> Void

    init(
        context: AccountContext,
        address: String,
        containerHeight: CGFloat,
        isPurchaseInProgress: Bool,
        isOpeningPurchase: Bool,
        animateOut: ActionSlot<Action<Void>>,
        getController: @escaping () -> ViewController?,
        buy: @escaping () -> Void
    ) {
        self.context = context
        self.address = address
        self.containerHeight = containerHeight
        self.isPurchaseInProgress = isPurchaseInProgress
        self.isOpeningPurchase = isOpeningPurchase
        self.animateOut = animateOut
        self.getController = getController
        self.buy = buy
    }

    static func ==(lhs: WalletReceiveSheetContent, rhs: WalletReceiveSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.address != rhs.address {
            return false
        }
        if lhs.containerHeight != rhs.containerHeight {
            return false
        }
        if lhs.isPurchaseInProgress != rhs.isPurchaseInProgress {
            return false
        }
        if lhs.isOpeningPurchase != rhs.isOpeningPurchase {
            return false
        }
        return true
    }

    final class View: UIView {
        private static let cardFlipDuration: Double = 0.4
        private static let cardFlipMinimumScale: CGFloat = 0.9
        private static let cardFlipShadeColor = UIColor(rgb: 0x003a80)
        private static let cardFlipMaximumShadeOpacity: CGFloat = 0.55

        private let background = ComponentView<Empty>()
        private let closeButton = ComponentView<Empty>()
        private let addressRing = ComponentView<Empty>()
        private let cardContainerView = UIView()
        private let cardView = UIView()
        private let cardBackground = ComponentView<Empty>()
        private let qrCode = ComponentView<Empty>()
        private let addressGrid = ComponentView<Empty>()
        private let copiedStatus = ComponentView<Empty>()
        private let copyButton = ComponentView<Empty>()
        private let explanation = ComponentView<Empty>()
        private let buyButton = ComponentView<Empty>()

        private var component: WalletReceiveSheetContent?
        private weak var state: EmptyComponentState?
        private let hapticFeedback = HapticFeedback()
        private var displaysAddress = false
        private var appliedDisplaysAddress: Bool?
        private var cardFlipView: UIView?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.cardView.clipsToBounds = true
            self.cardContainerView.addSubview(self.cardView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()

            if self.window == nil {
                self.finishCardFlip()
            }
        }

        private func finishCardFlip() {
            guard let flipView = self.cardFlipView else {
                return
            }
            self.cardFlipView = nil
            self.cardContainerView.addSubview(self.cardView)
            self.cardView.frame = self.cardContainerView.bounds
            self.cardView.isUserInteractionEnabled = true
            flipView.layer.removeAllAnimations()
            for faceView in flipView.subviews {
                faceView.layer.removeAllAnimations()
                for layer in faceView.layer.sublayers ?? [] {
                    layer.removeAllAnimations()
                }
            }
            flipView.removeFromSuperview()
        }

        private func animateCardFlip(from previousSnapshot: UIView) {
            self.cardView.layoutIfNeeded()

            let flipView = UIView(frame: self.cardContainerView.bounds)
            flipView.isUserInteractionEnabled = false
            flipView.accessibilityElementsHidden = true
            flipView.layer.rasterizationScale = UIScreenScale
            flipView.layer.shouldRasterize = true
            flipView.layer.allowsEdgeAntialiasing = true

            var perspective = CATransform3DIdentity
            perspective.m34 = -1.0 / 650.0
            flipView.layer.sublayerTransform = perspective

            self.cardFlipView = flipView
            self.cardContainerView.addSubview(flipView)
            self.cardView.isUserInteractionEnabled = false

            let shadeValues: [AnyObject] = (0 ... 60).map { index in
                let progress = CGFloat(index) / 60.0
                return NSNumber(value: Double(sin(progress * .pi) * Self.cardFlipMaximumShadeOpacity))
            }
            let scaleValues: [AnyObject] = (0 ... 60).map { index in
                let progress = CGFloat(index) / 60.0
                return NSNumber(value: Double(1.0 - sin(progress * .pi) * (1.0 - Self.cardFlipMinimumScale)))
            }
            let timingFunction = CAMediaTimingFunctionName.easeOut.rawValue
            flipView.layer.animateKeyframes(
                values: scaleValues,
                duration: Self.cardFlipDuration,
                keyPath: "transform.scale",
                timingFunction: timingFunction
            )
            for (index, contentView) in [previousSnapshot, self.cardView].enumerated() {
                let faceView = UIView(frame: flipView.bounds)
                faceView.clipsToBounds = true
                faceView.layer.cornerRadius = self.cardView.layer.cornerRadius
                faceView.layer.isDoubleSided = false
                contentView.frame = faceView.bounds
                faceView.addSubview(contentView)
                flipView.addSubview(faceView)

                let shadeLayer = CALayer()
                shadeLayer.frame = faceView.bounds
                shadeLayer.cornerRadius = faceView.layer.cornerRadius
                shadeLayer.backgroundColor = Self.cardFlipShadeColor.cgColor
                shadeLayer.opacity = 0.0
                faceView.layer.addSublayer(shadeLayer)
                shadeLayer.animateKeyframes(
                    values: shadeValues,
                    duration: Self.cardFlipDuration,
                    keyPath: "opacity",
                    timingFunction: timingFunction
                )

                let isOutgoing = index == 0
                let fromAngle: CGFloat = isOutgoing ? 0.0 : -.pi
                let toAngle: CGFloat = isOutgoing ? .pi : 0.0
                faceView.layer.transform = CATransform3DMakeRotation(toAngle, 0.0, 1.0, 0.0)
                faceView.layer.animate(
                    from: fromAngle,
                    to: toAngle,
                    keyPath: "transform.rotation.y",
                    timingFunction: timingFunction,
                    duration: Self.cardFlipDuration,
                    completion: { [weak self, weak flipView] _ in
                        guard !isOutgoing, let self, let flipView, self.cardFlipView === flipView else {
                            return
                        }
                        self.finishCardFlip()
                    }
                )
            }
        }

        private func dismiss(animated: Bool) {
            guard let component = self.component,
                  let controller = component.getController() as? WalletReceiveScreen else {
                return
            }
            self.finishCardFlip()
            if animated {
                component.animateOut.invoke(Action { [weak controller] _ in
                    controller?.dismiss(completion: nil)
                })
            } else {
                controller.dismiss(animated: false)
            }
        }

        private func copyAddress() {
            guard self.cardFlipView == nil, let component = self.component else {
                return
            }
            UIPasteboard.general.string = component.address
            self.hapticFeedback.success()
            if !self.displaysAddress {
                self.displaysAddress = true
                self.state?.updated(transition: .immediate)
            }
        }

        private func showQrCode() {
            guard self.cardFlipView == nil, self.displaysAddress else {
                return
            }
            self.displaysAddress = false
            self.state?.updated(transition: .immediate)
        }

        func update(
            component: WalletReceiveSheetContent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<EnvironmentType>,
            transition: ComponentTransition
        ) -> CGSize {
            if self.component?.address != component.address || UIAccessibility.isReduceMotionEnabled {
                self.finishCardFlip()
            }
            self.component = component
            self.state = state

            let environment = environment[EnvironmentType.self].value

            let availableWidth = availableSize.width
            let horizontalInset: CGFloat = 30.0 + max(environment.safeInsets.left, environment.safeInsets.right)
            let widthLimitedCardWidth = max(1.0, availableWidth - 104.0)
            let heightLimitedCardWidth = max(1.0, component.containerHeight - 338.0)
            let minimumReadableCardWidth = min(216.0, widthLimitedCardWidth)
            let cardWidth = min(
                256.0,
                widthLimitedCardWidth,
                max(minimumReadableCardWidth, heightLimitedCardWidth)
            )
            let qrSize = max(1.0, cardWidth - 20.0)
            let copyButtonHeight: CGFloat = 28.0
            let cardHeight = qrSize + copyButtonHeight + 24.0
            let cardCornerRadius: CGFloat = 28.0
            let ringPathOffset: CGFloat = 14.0
            let ringSize = CGSize(
                width: max(1.0, min(max(1.0, availableWidth - 32.0), cardWidth + 76.0)),
                height: cardHeight + 56.0
            )

            let cardTop: CGFloat = cardWidth < 230.0 ? 58.0 : 70.0
            let cardFrame = CGRect(
                x: floor((availableWidth - cardWidth) / 2.0),
                y: cardTop,
                width: cardWidth,
                height: cardHeight
            )
            if self.cardContainerView.frame != cardFrame {
                self.finishCardFlip()
            }
            let ringFrame = CGRect(
                x: floor((availableWidth - ringSize.width) / 2.0),
                y: cardFrame.minY - 28.0,
                width: ringSize.width,
                height: ringSize.height
            )

            let addressRingSize = self.addressRing.update(
                transition: transition,
                component: AnyComponent(WalletReceiveAddressRingComponent(
                    address: component.address,
                    color: UIColor(rgb: 0x0052b3).withAlphaComponent(0.48),
                    cardSize: cardFrame.size,
                    cardCornerRadius: cardCornerRadius,
                    pathOffset: ringPathOffset
                )),
                environment: {},
                containerSize: ringSize
            )

            let cardBackgroundSize = self.cardBackground.update(
                transition: transition,
                component: AnyComponent(RoundedRectangle(
                    color: .white,
                    cornerRadius: cardCornerRadius,
                    size: cardFrame.size
                )),
                environment: {},
                containerSize: cardFrame.size
            )

            let copyButtonContent: AnyComponentWithIdentity<Empty>
            let copyButtonAction: () -> Void
            if self.displaysAddress {
                copyButtonContent = AnyComponentWithIdentity(
                    id: "showQr",
                    component: AnyComponent(Text(
                        text: environment.strings.Wallet_Receive_ShowQR,
                        font: Font.semibold(14.0),
                        color: UIColor(rgb: 0x087cff)
                    ))
                )
                copyButtonAction = { [weak self] in
                    self?.showQrCode()
                }
            } else {
                copyButtonContent = AnyComponentWithIdentity(
                    id: "copy",
                    component: AnyComponent(HStack<Empty>([
                        AnyComponentWithIdentity(
                            id: "icon",
                            component: AnyComponent(BundleIconComponent(
                                name: "Wallet/ReceiveCopy",
                                tintColor: UIColor(rgb: 0x087cff)
                            ))
                        ),
                        AnyComponentWithIdentity(
                            id: "title",
                            component: AnyComponent(Text(
                                text: environment.strings.Wallet_Receive_CopyAddress,
                                font: Font.semibold(14.0),
                                color: UIColor(rgb: 0x087cff)
                            ))
                        )
                    ], spacing: 2.0))
                )
                copyButtonAction = { [weak self] in
                    self?.copyAddress()
                }
            }

            let closeButtonSize = self.closeButton.update(
                transition: .immediate,
                component: AnyComponent(GlassBarButtonComponent(
                    size: CGSize(width: 44.0, height: 44.0),
                    backgroundColor: UIColor(rgb: 0x1883fc),
                    isDark: false,
                    state: .tintedGlass,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Close",
                            tintColor: .white
                        )
                    )),
                    action: { [weak self] _ in
                        self?.dismiss(animated: true)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 44.0, height: 44.0)
            )

            let explanationSize = self.explanation.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: environment.strings.Wallet_Receive_Text,
                        font: Font.regular(15.0),
                        textColor: .white
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 2,
                    lineSpacing: 0.2
                )),
                environment: {},
                containerSize: CGSize(
                    width: max(1.0, availableWidth - horizontalInset * 2.0),
                    height: 100.0
                )
            )
            let explanationTop = ringFrame.maxY + (cardWidth < 230.0 ? 12.0 : 20.0)

            let buyContent = HStack<Empty>([
                AnyComponentWithIdentity(
                    id: "icon",
                    component: AnyComponent(BundleIconComponent(name: "Wallet/ButtonBuy", tintColor: UIColor(rgb: 0x087cff)))
                ),
                AnyComponentWithIdentity(
                    id: "title",
                    component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(
                        string: availableWidth < 390.0 ? environment.strings.Wallet_Receive_BuyShort : environment.strings.Wallet_Receive_Buy,
                        font: Font.semibold(17.0),
                        textColor: UIColor(rgb: 0x087cff)
                    ))))
                )
            ], spacing: 10.0)
            let buyButtonSize = self.buyButton.update(
                transition: .immediate,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .legacy,
                        color: .white,
                        foreground: UIColor(rgb: 0x087cff),
                        pressedColor: UIColor(white: 0.92, alpha: 1.0),
                        cornerRadius: 26.0
                    ),
                    content: AnyComponentWithIdentity(id: "buy", component: AnyComponent(buyContent)),
                    isEnabled: !component.isPurchaseInProgress,
                    tintWhenDisabled: false,
                    displaysProgress: component.isOpeningPurchase,
                    action: { [weak self] in
                        self?.component?.buy()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: max(1.0, availableWidth - horizontalInset * 2.0), height: 52.0)
            )
            let buyButtonTop = explanationTop + explanationSize.height + (cardWidth < 230.0 ? 18.0 : 30.0)

            let contentHeight = buyButtonTop + buyButtonSize.height + max(22.0, environment.safeInsets.bottom + 12.0)
            let backgroundSize = self.background.update(
                transition: transition,
                component: AnyComponent(RoundedRectangle(
                    colors: [
                        UIColor(rgb: 0x0079ff),
                        UIColor(rgb: 0x46b2ff),
                        UIColor(rgb: 0x46b2ff),
                        UIColor(rgb: 0x067eff)
                    ],
                    cornerRadius: 0.0,
                    gradientDirection: .vertical,
                    size: CGSize(width: availableWidth * 2.0, height: contentHeight)
                )),
                environment: {},
                containerSize: CGSize(width: availableWidth * 2.0, height: contentHeight)
            )
            if let backgroundView = self.background.view {
                if backgroundView.superview !== self {
                    backgroundView.removeFromSuperview()
                    self.addSubview(backgroundView)
                }
                transition.setFrame(view: backgroundView, frame: CGRect(origin: .zero, size: backgroundSize))
            }
            if let addressRingView = self.addressRing.view {
                if addressRingView.superview !== self {
                    addressRingView.removeFromSuperview()
                    self.addSubview(addressRingView)
                }
                transition.setFrame(view: addressRingView, frame: CGRect(origin: ringFrame.origin, size: addressRingSize))
            }

            if self.cardContainerView.superview !== self {
                self.cardContainerView.removeFromSuperview()
                self.addSubview(self.cardContainerView)
            }
            self.cardView.layer.cornerRadius = cardCornerRadius
            transition.setFrame(view: self.cardContainerView, frame: cardFrame)
            transition.setFrame(view: self.cardView, frame: CGRect(origin: .zero, size: cardFrame.size))
            if let cardBackgroundView = self.cardBackground.view {
                if cardBackgroundView.superview == nil {
                    self.cardView.addSubview(cardBackgroundView)
                }
                transition.setFrame(view: cardBackgroundView, frame: CGRect(origin: .zero, size: cardBackgroundSize))
            }

            let shouldAnimateCardFlip = self.appliedDisplaysAddress != nil
                && self.appliedDisplaysAddress != self.displaysAddress
            let cardContentTransition: ComponentTransition = shouldAnimateCardFlip ? .immediate : transition
            var previousCardSnapshot: UIView?
            if shouldAnimateCardFlip {
                self.finishCardFlip()
                if !UIAccessibility.isReduceMotionEnabled, self.window != nil {
                    previousCardSnapshot = self.cardView.snapshotView(afterScreenUpdates: false)
                }
            }
            let updateCardContents = {
                let copiedStatusSize = self.copiedStatus.update(
                    transition: .immediate,
                    component: AnyComponent(HStack<Empty>([
                        AnyComponentWithIdentity(
                            id: "check",
                            component: AnyComponent(Text(
                                text: "✓",
                                font: Font.semibold(14.0),
                                color: UIColor(rgb: 0x087cff)
                            ))
                        ),
                        AnyComponentWithIdentity(
                            id: "title",
                            component: AnyComponent(Text(
                                text: environment.strings.Wallet_AddressCopied,
                                font: Font.semibold(14.0),
                                color: UIColor(rgb: 0x087cff)
                            ))
                        )
                    ], spacing: 6.0)),
                    environment: {},
                    containerSize: CGSize(width: max(1.0, cardWidth - 40.0), height: 28.0)
                )
                if let copiedStatusView = self.copiedStatus.view, copiedStatusView.superview == nil {
                    copiedStatusView.alpha = self.displaysAddress ? 1.0 : 0.0
                    self.cardView.addSubview(copiedStatusView)
                }

                if self.displaysAddress {
                    let addressGridSize = self.addressGrid.update(
                        transition: cardContentTransition,
                        component: AnyComponent(WalletReceiveAddressGridComponent(address: component.address)),
                        environment: {},
                        containerSize: CGSize(width: max(1.0, cardWidth - 52.0), height: cardHeight)
                    )
                    let addressGridTop = cardWidth < 230.0 ? 34.0 : 54.0
                    if let addressGridView = self.addressGrid.view {
                        if addressGridView.superview == nil {
                            self.cardView.addSubview(addressGridView)
                        }
                        cardContentTransition.setFrame(
                            view: addressGridView,
                            frame: CGRect(
                                x: (cardWidth - addressGridSize.width) / 2.0,
                                y: addressGridTop,
                                width: addressGridSize.width,
                                height: addressGridSize.height
                            )
                        )
                    }

                    let copiedStatusTop = addressGridTop + addressGridSize.height + (cardWidth < 230.0 ? 8.0 : 16.0)
                    if let copiedStatusView = self.copiedStatus.view {
                        ComponentTransition.immediate.setFrame(
                            view: copiedStatusView,
                            frame: CGRect(
                                x: (cardWidth - copiedStatusSize.width) / 2.0,
                                y: copiedStatusTop,
                                width: copiedStatusSize.width,
                                height: copiedStatusSize.height
                            )
                        )
                    }
                    self.qrCode.view?.removeFromSuperview()
                } else {
                    let qrCodeSize = self.qrCode.update(
                        transition: cardContentTransition,
                        component: AnyComponent(WalletReceiveQrComponent(
                            address: component.address,
                            theme: environment.theme,
                            isVisible: environment.isVisible
                        )),
                        environment: {},
                        containerSize: CGSize(width: qrSize, height: qrSize)
                    )
                    if let qrCodeView = self.qrCode.view {
                        if qrCodeView.superview == nil {
                            qrCodeView.removeFromSuperview()
                            self.cardView.addSubview(qrCodeView)
                        }
                        cardContentTransition.setFrame(
                            view: qrCodeView,
                            frame: CGRect(
                                x: (cardWidth - qrCodeSize.width) / 2.0,
                                y: 10.0,
                                width: qrCodeSize.width,
                                height: qrCodeSize.height
                            )
                        )
                    }
                    self.addressGrid.view?.removeFromSuperview()
                }
                if let copiedStatusView = self.copiedStatus.view {
                    cardContentTransition.setAlpha(
                        view: copiedStatusView,
                        alpha: self.displaysAddress ? 1.0 : 0.0
                    )
                }

                let copyButtonSize = self.copyButton.update(
                    transition: .immediate,
                    component: AnyComponent(ButtonComponent(
                        background: ButtonComponent.Background(
                            style: .glass,
                            color: UIColor(rgb: 0x087cff, alpha: 0.1),
                            foreground: UIColor(rgb: 0x087cff),
                            pressedColor: UIColor(rgb: 0xc8e4ff),
                            cornerRadius: copyButtonHeight / 2.0
                        ),
                        content: copyButtonContent,
                        restrictContentAnimations: true,
                        contentInsets: UIEdgeInsets(top: 0.0, left: 14.0, bottom: 0.0, right: 14.0),
                        fitToContentWidth: true,
                        isEnabled: true,
                        displaysProgress: false,
                        action: copyButtonAction
                    )),
                    environment: {},
                    containerSize: CGSize(width: max(1.0, cardWidth - 32.0), height: copyButtonHeight)
                )
                if let copyButtonView = self.copyButton.view {
                    if copyButtonView.superview == nil {
                        copyButtonView.removeFromSuperview()
                        self.cardView.addSubview(copyButtonView)
                    }
                    ComponentTransition.immediate.setFrame(
                        view: copyButtonView,
                        frame: CGRect(
                            x: (cardWidth - copyButtonSize.width) / 2.0,
                            y: cardHeight - 16.0 - copyButtonSize.height,
                            width: copyButtonSize.width,
                            height: copyButtonSize.height
                        )
                    )
                    self.cardView.bringSubviewToFront(copyButtonView)
                }
            }

            updateCardContents()
            if let previousCardSnapshot {
                self.animateCardFlip(from: previousCardSnapshot)
            }
            self.appliedDisplaysAddress = self.displaysAddress

            if let explanationView = self.explanation.view {
                if explanationView.superview !== self {
                    explanationView.removeFromSuperview()
                    self.addSubview(explanationView)
                }
                transition.setFrame(
                    view: explanationView,
                    frame: CGRect(
                        x: (availableWidth - explanationSize.width) / 2.0,
                        y: explanationTop,
                        width: explanationSize.width,
                        height: explanationSize.height
                    )
                )
            }
            if let buyButtonView = self.buyButton.view {
                if buyButtonView.superview !== self {
                    buyButtonView.removeFromSuperview()
                    self.addSubview(buyButtonView)
                }
                transition.setFrame(
                    view: buyButtonView,
                    frame: CGRect(
                        x: (availableWidth - buyButtonSize.width) / 2.0,
                        y: buyButtonTop,
                        width: buyButtonSize.width,
                        height: buyButtonSize.height
                    )
                )
            }
            if let closeButtonView = self.closeButton.view {
                if closeButtonView.superview !== self {
                    closeButtonView.removeFromSuperview()
                    self.addSubview(closeButtonView)
                }
                transition.setFrame(
                    view: closeButtonView,
                    frame: CGRect(
                        x: 16.0,
                        y: 16.0,
                        width: closeButtonSize.width,
                        height: closeButtonSize.height
                    )
                )
            }

            return CGSize(width: availableWidth, height: contentHeight)
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<EnvironmentType>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(
            component: self,
            availableSize: availableSize,
            state: state,
            environment: environment,
            transition: transition
        )
    }
}

private final class WalletReceiveSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let address: String

    init(context: AccountContext, address: String) {
        self.context = context
        self.address = address
    }

    static func ==(lhs: WalletReceiveSheetComponent, rhs: WalletReceiveSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.address != rhs.address {
            return false
        }
        return true
    }

    final class State: ComponentState {
        private let context: AccountContext
        private let onrampProvidersDisposable = MetaDisposable()
        private let createSessionDisposable = MetaDisposable()
        private let openBotAppDisposable = MetaDisposable()

        private var isLoadingProviders = true
        private var isWalletAvailable = false
        fileprivate var isOpeningPurchase = false

        fileprivate var isPurchaseInProgress: Bool {
            return self.isLoadingProviders || self.isOpeningPurchase
        }

        init(context: AccountContext) {
            self.context = context

            super.init()

            self.onrampProvidersDisposable.set((context.engine.payments.getOnrampProviders(cryptoCurrency: "gram")
            |> deliverOnMainQueue).start(next: { [weak self] providers in
                guard let self else {
                    return
                }
                self.isWalletAvailable = providers.contains(where: { $0.id == "wallet" })
                self.isLoadingProviders = false
                self.updated(transition: .easeInOut(duration: 0.2))
            }, error: { [weak self] _ in
                guard let self else {
                    return
                }
                self.isWalletAvailable = false
                self.isLoadingProviders = false
                self.updated(transition: .easeInOut(duration: 0.2))
            }))
        }

        deinit {
            self.onrampProvidersDisposable.dispose()
            self.createSessionDisposable.dispose()
            self.openBotAppDisposable.dispose()
        }

        fileprivate func createOnrampSession(
            address: String,
            getController: @escaping () -> ViewController?
        ) {
            guard !self.isPurchaseInProgress else {
                return
            }
            guard self.isWalletAvailable else {
                self.presentPurchaseAlert(
                    title: self.context.sharedContext.currentPresentationData.with { $0 }.strings.Wallet_Receive_PurchaseUnavailableTitle,
                    text: self.context.sharedContext.currentPresentationData.with { $0 }.strings.Wallet_Receive_PurchaseUnavailableText,
                    getController: getController
                )
                return
            }

            self.isOpeningPurchase = true
            self.updated(transition: .easeInOut(duration: 0.2))

            self.createSessionDisposable.set((self.context.engine.payments.createOnrampSession(
                provider: "wallet",
                cryptoCurrency: "gram",
                address: address,
                paymentMethod: nil
            )
            |> deliverOnMainQueue).start(next: { [weak self] session in
                guard let self else {
                    return
                }
                self.openBotAppDisposable.set((self.context.sharedContext.resolveUrl(
                    context: self.context,
                    peerId: nil,
                    url: session.url,
                    skipUrlAuth: true
                )
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak self] result in
                    guard let self else {
                        return
                    }
                    guard case let .peer(peer, .withBotApp(botAppStart)) = result, let botPeer = peer.flatMap(EnginePeer.init) else {
                        self.presentOnrampError(getController: getController)
                        return
                    }
                    let context = self.context
                    guard let controller = getController() else {
                        return
                    }
                    let navigationController = (controller.navigationController as? NavigationController)
                        ?? (context.sharedContext.mainWindow?.viewController as? NavigationController)
                    guard let parentController = navigationController?.viewControllers.last as? ViewController else {
                        self.presentOnrampError(getController: getController)
                        return
                    }
                    var didBeginAnimatedDismiss = false
                    context.sharedContext.openBotApp(
                        context: context,
                        parentController: parentController,
                        botApp: botAppStart.botApp,
                        botPeer: botPeer,
                        payload: botAppStart.payload,
                        mode: botAppStart.mode,
                        isOnramp: true,
                        willOpen: { [weak controller] in
                            guard !didBeginAnimatedDismiss, let controller = controller as? WalletReceiveScreen else {
                                return
                            }
                            if let view = controller.node.hostView.findTaggedView(
                                tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()
                            ) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
                                view.setDimHidden(true, animated: true)
                            }
                            if controller.validLayout?.metrics.widthClass == .regular {
                                didBeginAnimatedDismiss = true
                                controller.dismissAnimated()
                            }
                        },
                        completion: { [weak controller] in
                            if !didBeginAnimatedDismiss {
                                controller?.dismiss(animated: false)
                            }
                        }
                    )
                }))
            }, error: { [weak self] _ in
                self?.presentOnrampError(getController: getController)
            }))
        }

        private func presentOnrampError(getController: @escaping () -> ViewController?) {
            self.isOpeningPurchase = false
            self.updated(transition: .easeInOut(duration: 0.2))

            self.presentPurchaseAlert(
                title: self.context.sharedContext.currentPresentationData.with { $0 }.strings.Wallet_Receive_PurchaseFailedTitle,
                text: self.context.sharedContext.currentPresentationData.with { $0 }.strings.Wallet_Receive_PurchaseFailedText,
                getController: getController
            )
        }

        private func presentPurchaseAlert(title: String, text: String, getController: @escaping () -> ViewController?) {
            guard let controller = getController() else {
                return
            }
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            controller.present(textAlertController(
                context: self.context,
                title: title,
                text: text,
                actions: [
                    TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                    })
                ]
            ), in: .window(.root))
        }
    }

    func makeState() -> State {
        return State(context: self.context)
    }

    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        let sheetExternalState = SheetComponent<EnvironmentType>.ExternalState()

        return { context in
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller
            let componentState = context.state

            let address = context.component.address

            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent(WalletReceiveSheetContent(
                        context: context.component.context,
                        address: address,
                        containerHeight: context.availableSize.height,
                        isPurchaseInProgress: componentState.isPurchaseInProgress,
                        isOpeningPurchase: componentState.isOpeningPurchase,
                        animateOut: animateOut,
                        getController: controller,
                        buy: { [weak componentState] in
                            componentState?.createOnrampSession(
                                address: address,
                                getController: controller
                            )
                        }
                    )),
                    style: .glass,
                    backgroundColor: .color(UIColor(rgb: 0x0079ff)),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    autoAnimateOut: false,
                    externalState: sheetExternalState,
                    animateOut: animateOut,
                    didAppear: {
                        (controller() as? WalletReceiveScreen)?.completeAppearance()
                    },
                    onPan: {
                    },
                    willDismiss: {
                    }
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            guard let controller = controller() as? WalletReceiveScreen else {
                                return
                            }
                            if animated {
                                animateOut.invoke(Action { _ in
                                    controller.completeAnimatedDismiss()
                                })
                            } else {
                                controller.completeAnimatedDismiss()
                            }
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            context.add(sheet.position(CGPoint(
                x: context.availableSize.width / 2.0,
                y: context.availableSize.height / 2.0
            )))

            if let controller = controller(), !controller.automaticallyControlPresentationContextLayout {
                var sideInset: CGFloat = 0.0
                var bottomInset: CGFloat = max(environment.safeInsets.bottom, sheetExternalState.contentHeight)
                if case .regular = environment.metrics.widthClass {
                    sideInset = floor((context.availableSize.width - 430.0) / 2.0) - 12.0
                    bottomInset = (context.availableSize.height - sheetExternalState.contentHeight) / 2.0 + sheetExternalState.contentHeight
                }

                let layout = ContainerViewLayout(
                    size: context.availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomInset, right: 0.0),
                    safeInsets: UIEdgeInsets(
                        top: 0.0,
                        left: max(sideInset, environment.safeInsets.left),
                        bottom: 0.0,
                        right: max(sideInset, environment.safeInsets.right)
                    ),
                    additionalInsets: .zero,
                    statusBarHeight: environment.statusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false,
                    presentedInFormSheet: false
                )
                controller.presentationContext.containerLayoutUpdated(
                    layout,
                    transition: context.transition.containedViewLayoutTransition
                )
            }

            return context.availableSize
        }
    }
}

public final class WalletReceiveScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    private var appeared: (() -> Void)?
    private var animatedDismissCompletion: (() -> Void)?

    public init(context: AccountContext, address: String, appeared: (() -> Void)? = nil) {
        self.context = context
        self.appeared = appeared

        super.init(
            context: context,
            component: WalletReceiveSheetComponent(context: context, address: address),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )

        self.navigationPresentation = .flatModal
        self.automaticallyControlPresentationContextLayout = false
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.view.disablesInteractiveModalDismiss = true
    }

    fileprivate func completeAppearance() {
        let appeared = self.appeared
        self.appeared = nil
        appeared?()
    }

    fileprivate func completeAnimatedDismiss() {
        let completion = self.animatedDismissCompletion
        self.animatedDismissCompletion = nil
        self.dismiss(completion: completion)
    }

    public func dismissAnimated(completion: (() -> Void)? = nil) {
        self.animatedDismissCompletion = completion
        if let view = self.node.hostView.findTaggedView(
            tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()
        ) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        } else {
            self.completeAnimatedDismiss()
        }
    }
}
