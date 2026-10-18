import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import GlassBackgroundComponent

private final class QrStudioSheetClipView: UIView {
    private let topClipView = UIView()
    let contentView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.clipsToBounds = true
        if CALayer.cornerRadiiSupported {
            self.addSubview(self.contentView)
        } else {
            self.topClipView.clipsToBounds = true
            self.addSubview(self.topClipView)
            self.topClipView.addSubview(self.contentView)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var contentLayer: CALayer {
        return self.contentView.layer
    }

    var topClipLayer: CALayer {
        return self.topClipView.layer
    }

    func addCornerAnimations(sizes: [CGSize], tops: [CGFloat], bottoms: [CGFloat], duration: Double, add: (CALayer, String, [Any]) -> Void) {
        let bounds = sizes.map { NSValue(cgRect: CGRect(origin: CGPoint(), size: $0)) }
        let centers = sizes.map { NSValue(cgPoint: CGPoint(x: $0.width * 0.5, y: $0.height * 0.5)) }
        if CALayer.cornerRadiiSupported {
            var radii: [Any] = []
            for i in 0 ..< tops.count {
                radii.append(CornerRadii(topLeft: tops[i], topRight: tops[i], bottomLeft: bottoms[i], bottomRight: bottoms[i]).boxedValue)
            }
            add(self.layer, self.layer.cornerRadiiKeyPath, radii)
        } else {
            add(self.layer, "cornerRadius", bottoms.map { NSNumber(value: Double($0)) })
            add(self.topClipView.layer, "bounds", bounds)
            add(self.topClipView.layer, "position", centers)
            add(self.topClipView.layer, "cornerRadius", tops.map { NSNumber(value: Double($0)) })
        }
        add(self.contentView.layer, "bounds", bounds)
        add(self.contentView.layer, "position", centers)
    }

    func update(size: CGSize, top: CGFloat, bottom: CGFloat) {
        let bounds = CGRect(origin: CGPoint(), size: size)
        if CALayer.cornerRadiiSupported {
            self.layer.setCornerRadii(CornerRadii(topLeft: top, topRight: top, bottomLeft: bottom, bottomRight: bottom))
            self.contentView.frame = bounds
        } else {
            self.layer.cornerRadius = bottom
            self.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            self.topClipView.frame = bounds
            self.topClipView.layer.cornerRadius = top
            self.topClipView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            self.contentView.frame = bounds
        }
    }
}

final class QrStudioSheetView: UIView, UIGestureRecognizerDelegate {
    let motion = QrStudioSheetMotion()
    private(set) var geometry: QrStudioSheetGeometry?

    var requestOpenTab: ((QrStudioLook.Kind) -> Void)?
    var progressUpdated: (() -> Void)?

    private let capsuleGlass = GlassBackgroundView()
    private let iconsContainer = UIView()
    private var iconViews: [QrStudioLook.Kind: UIImageView] = [:]
    private var kinds: [QrStudioLook.Kind] = []

    private let clipView = QrStudioSheetClipView()
    private let backgroundContainer = UIView()
    private let blurView = BlurredBackgroundView(color: .black, enableBlur: true)
    private let tintView = UIView()
    private let tintMaskView = UIView()
    private let tintMaskContentView = UIView()
    private var tintMaskContainers: [QrStudioLook.Kind: UIView] = [:]
    private let shadeView = UIView()
    private let contentContainer = UIView()

    private var contents: [QrStudioLook.Kind: UIView] = [:]
    private(set) var currentTab: QrStudioLook.Kind?

    private struct Layout {
        var frame: CGRect
        var top: CGFloat
        var bottom: CGFloat
        var glassAlpha: CGFloat
        var iconsAlpha: CGFloat
        var backgroundAlpha: CGFloat
        var contentAlpha: CGFloat
        var zoom: CGFloat
    }

    private struct Playback {
        let start: Double
        let samples: [QrStudioSheetMotion.Sample]
        let glassUntil: Double

        var duration: Double {
            return Double(max(0, self.samples.count - 1)) * QrStudioSheetView.sampleStep
        }

        func position(at time: Double) -> (index: Int, fraction: CGFloat) {
            let t = max(0.0, time - self.start) / QrStudioSheetView.sampleStep
            let index = min(Int(t), max(0, self.samples.count - 1))
            return (index, CGFloat(t - Double(index)))
        }

        func sample(at time: Double) -> QrStudioSheetMotion.Sample {
            let (index, fraction) = self.position(at: time)
            guard index + 1 < self.samples.count else {
                return self.samples[self.samples.count - 1]
            }
            let a = self.samples[index]
            let b = self.samples[index + 1]
            return QrStudioSheetMotion.Sample(rise: a.rise + (b.rise - a.rise) * fraction, spread: a.spread + (b.spread - a.spread) * fraction, pull: a.pull + (b.pull - a.pull) * fraction, search: a.search + (b.search - a.search) * fraction, height: a.height + (b.height - a.height) * fraction)
        }

        func velocity(at time: Double) -> QrStudioSheetMotion.Sample {
            let (index, _) = self.position(at: time)
            guard index + 1 < self.samples.count else {
                return QrStudioSheetMotion.Sample(rise: 0.0, spread: 0.0, pull: 0.0, search: 0.0)
            }
            let a = self.samples[index]
            let b = self.samples[index + 1]
            let k = CGFloat(1.0 / QrStudioSheetView.sampleStep)
            return QrStudioSheetMotion.Sample(rise: (b.rise - a.rise) * k, spread: (b.spread - a.spread) * k, pull: (b.pull - a.pull) * k, search: (b.search - a.search) * k, height: (b.height - a.height) * k)
        }
    }

    static let sampleStep: Double = 1.0 / 120.0
    private static let animationKey = "qrSheetMotion"

    private var playback: Playback?
    private var playbackToken = 0
    private var glassLink: SharedDisplayLinkDriver.Link?
    var progressAnimated: ((_ samples: [QrStudioSheetMotion.Sample], _ duration: Double) -> Void)?
    var progressInterrupted: (() -> Void)?
    private var isDark = true
    private var appliedGlyphColor: UIColor?
    private var appliedThemeIsDark: Bool?
    private var glassTint = GlassBackgroundView.TintColor(kind: .clear)
    private(set) var keyboardHeight: CGFloat = 0.0
    private var inputHeight: CGFloat = 0.0
    private let hapticFeedback = HapticFeedback()

    private var panAnchor: CGFloat = 0.0
    private weak var trackedScrollView: UIScrollView?
    private var scrollPullAnchor: CGFloat?
    private var isScrollPulling = false

    static let iconSide: CGFloat = 30.0
    static let iconSpacing: CGFloat = 24.0
    static let iconInset: CGFloat = 7.0

    static func capsuleWidth(count: Int) -> CGFloat {
        let count = CGFloat(max(1, count))
        return self.iconInset * 2.0 + self.iconSide * count + self.iconSpacing * (count - 1.0)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.addSubview(self.capsuleGlass)
        self.iconsContainer.isUserInteractionEnabled = false
        self.capsuleGlass.contentView.addSubview(self.iconsContainer)

        self.addSubview(self.clipView)
        self.clipView.contentView.addSubview(self.backgroundContainer)
        self.backgroundContainer.addSubview(self.blurView)
        self.backgroundContainer.addSubview(self.shadeView)
        self.backgroundContainer.addSubview(self.tintView)
        self.tintMaskView.backgroundColor = .white
        if let filter = CALayer.luminanceToAlpha() {
            self.tintMaskView.layer.filters = [filter]
        }
        self.tintMaskContentView.layer.anchorPoint = CGPoint(x: 0.5, y: 0.0)
        self.tintMaskView.addSubview(self.tintMaskContentView)
        self.tintView.mask = self.tintMaskView
        self.contentContainer.layer.anchorPoint = CGPoint(x: 0.5, y: 0.0)
        self.clipView.contentView.addSubview(self.contentContainer)
        self.clipView.isHidden = true

        self.capsuleGlass.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.handleCapsuleTap(_:))))

        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
        panRecognizer.delegate = self
        self.clipView.addGestureRecognizer(panRecognizer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var isOpen: Bool {
        return self.motion.isOpen
    }

    var presentedSample: QrStudioSheetMotion.Sample {
        if let playback = self.playback {
            return playback.sample(at: CACurrentMediaTime())
        }
        return self.motion.sample
    }

    var modelSample: QrStudioSheetMotion.Sample {
        if let playback = self.playback, let last = playback.samples.last {
            return last
        }
        return self.motion.sample
    }

    var openness: CGFloat {
        guard let geometry = self.geometry else {
            return 0.0
        }
        return self.presentedSample.openness(travel: geometry.sheet.height)
    }

    var search: CGFloat {
        return self.presentedSample.search
    }

    var searchLift: CGFloat {
        return self.searchLift(self.presentedSample)
    }

    private func searchLift(_ sample: QrStudioSheetMotion.Sample) -> CGFloat {
        guard let geometry = self.geometry else {
            return 0.0
        }
        return sample.search * geometry.searchLift(keyboard: self.keyboardHeight)
    }

    var sheetSize: CGSize {
        return self.geometry?.sheet.size ?? CGSize()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let geometry = self.geometry else {
            return nil
        }
        let sample = self.presentedSample
        let frame = self.frame(geometry: geometry, sample: sample)
        guard frame.contains(point) else {
            return nil
        }
        if !self.motion.isOpen && sample.rise < 0.001 {
            return self.capsuleGlass
        }
        if let result = super.hitTest(point, with: event), result !== self {
            return result
        }
        return self.clipView
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let panRecognizer = gestureRecognizer as? UIPanGestureRecognizer else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
        let velocity = panRecognizer.velocity(in: self)
        return abs(velocity.y) > abs(velocity.x)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let scrollView = otherGestureRecognizer.view as? UIScrollView, otherGestureRecognizer === scrollView.panGestureRecognizer {
            return true
        }
        return false
    }

    func update(size: CGSize, safeBottom: CGFloat, bottomCornerRadius: CGFloat, inputHeight: CGFloat, kinds: [QrStudioLook.Kind], isDark: Bool, glassTint: GlassBackgroundView.TintColor, theme: PresentationTheme) {
        self.glassTint = glassTint
        let geometry = QrStudioSheetGeometry(screen: size, safeBottom: safeBottom, capsuleWidth: QrStudioSheetView.capsuleWidth(count: kinds.count), bottomCornerRadius: bottomCornerRadius)
        let geometryChanged = self.geometry != geometry
        self.geometry = geometry
        if self.isDark != isDark && self.appliedGlyphColor != nil && !self.capsuleGlass.isHidden {
            qrStudioCrossfadeGlass(self.capsuleGlass)
        }
        self.isDark = isDark

        if self.kinds != kinds {
            self.kinds = kinds
            for (_, iconView) in self.iconViews {
                iconView.removeFromSuperview()
            }
            self.iconViews.removeAll()
            for kind in kinds {
                let iconView = UIImageView(image: UIImage(bundleImageName: QrStudioSheetView.iconName(kind))?.withRenderingMode(.alwaysTemplate))
                self.iconsContainer.addSubview(iconView)
                self.iconViews[kind] = iconView
            }
        }
        let glyphColor = isDark ? UIColor(white: 0.96, alpha: 1.0) : UIColor(white: 0.1, alpha: 1.0)
        if let appliedGlyphColor = self.appliedGlyphColor, appliedGlyphColor != glyphColor {
            UIView.transition(with: self.iconsContainer, duration: 0.35, options: [.transitionCrossDissolve, .allowUserInteraction], animations: {
                for (_, iconView) in self.iconViews {
                    iconView.tintColor = glyphColor
                }
            }, completion: nil)
        }
        self.appliedGlyphColor = glyphColor
        var iconX = QrStudioSheetView.iconInset
        for kind in kinds {
            if let iconView = self.iconViews[kind] {
                if iconView.tintColor != glyphColor {
                    iconView.tintColor = glyphColor
                }
                iconView.frame = CGRect(x: iconX, y: (geometry.capsule.height - QrStudioSheetView.iconSide) * 0.5, width: QrStudioSheetView.iconSide, height: QrStudioSheetView.iconSide)
            }
            iconX += QrStudioSheetView.iconSide + QrStudioSheetView.iconSpacing
        }
        self.iconsContainer.bounds = CGRect(origin: CGPoint(), size: geometry.capsule.size)

        if let appliedThemeIsDark = self.appliedThemeIsDark, appliedThemeIsDark != theme.overallDarkAppearance, !self.clipView.isHidden {
            qrStudioCrossfadeGlass(self.clipView, duration: 0.35)
        }
        self.appliedThemeIsDark = theme.overallDarkAppearance
        let panelColor = theme.chat.inputMediaPanel.backgroundColor
        if theme.overallDarkAppearance {
            self.tintView.backgroundColor = panelColor
            self.shadeView.backgroundColor = UIColor(white: 0.0, alpha: 0.05)
        } else {
            self.tintView.backgroundColor = panelColor.withAlphaComponent(min(1.0, panelColor.alpha + 0.1))
            self.shadeView.backgroundColor = UIColor(white: 0.0, alpha: 0.4)
        }

        if geometryChanged {
            let sheetSize = geometry.sheet.size
            let backgroundSize = CGSize(width: sheetSize.width, height: sheetSize.height + 80.0)
            self.blurView.frame = CGRect(origin: CGPoint(), size: backgroundSize)
            self.blurView.updateColor(color: .clear, forceKeepBlur: true, transition: .immediate)
            self.blurView.update(size: backgroundSize, transition: .immediate)
            self.tintView.frame = CGRect(origin: CGPoint(), size: backgroundSize)
            self.tintMaskView.frame = CGRect(origin: CGPoint(), size: backgroundSize)
            self.tintMaskContentView.bounds = CGRect(origin: CGPoint(), size: sheetSize)
            for (_, container) in self.tintMaskContainers {
                container.frame = CGRect(origin: CGPoint(), size: sheetSize)
            }
            self.shadeView.frame = CGRect(origin: CGPoint(), size: backgroundSize)
            self.backgroundContainer.bounds = CGRect(origin: CGPoint(), size: backgroundSize)
            self.contentContainer.bounds = CGRect(origin: CGPoint(), size: sheetSize)
            for (_, view) in self.contents {
                view.frame = CGRect(origin: CGPoint(), size: sheetSize)
            }
        }

        let targetHeight = self.targetHeight(geometry: geometry)
        if self.motion.height != targetHeight && self.playback == nil {
            self.motion.setHeight(targetHeight, animated: self.motion.isOpen && !geometryChanged)
            if self.motion.isOpen && !geometryChanged && self.inputHeight == inputHeight {
                self.runMotion()
                return
            }
        }

        if self.inputHeight != inputHeight {
            self.inputHeight = inputHeight
            self.syncPlayback()
            if inputHeight > 0.0 {
                self.keyboardHeight = inputHeight
            }
            self.motion.setSearch(inputHeight > 0.0 && self.motion.isOpen)
            self.runMotion()
        } else if self.playback == nil {
            self.applyImmediately()
        }
    }

    private static func iconName(_ kind: QrStudioLook.Kind) -> String {
        switch kind {
        case .color:
            return "QrStudio/TabColor"
        case .emoji:
            return "QrStudio/TabEmoji"
        case .gift:
            return "QrStudio/TabGift"
        }
    }

    func tintMaskContainer(for kind: QrStudioLook.Kind) -> UIView {
        if let current = self.tintMaskContainers[kind] {
            return current
        }
        let container = UIView()
        container.isUserInteractionEnabled = false
        container.frame = CGRect(origin: CGPoint(), size: self.sheetSize)
        container.isHidden = kind != self.currentTab
        self.tintMaskContentView.addSubview(container)
        self.tintMaskContainers[kind] = container
        return container
    }

    func setContent(_ view: UIView, for kind: QrStudioLook.Kind) {
        if let current = self.contents[kind], current !== view {
            current.removeFromSuperview()
        }
        self.contents[kind] = view
        view.frame = CGRect(origin: CGPoint(), size: self.sheetSize)
        view.isHidden = kind != self.currentTab
        self.updateAttachedContent()
    }

    private func updateAttachedContent() {
        let isShown = self.motion.isOpen || self.presentedSample.rise > 0.001
        for (kind, view) in self.contents {
            let attached = isShown && kind == self.currentTab
            if attached {
                if view.superview !== self.contentContainer {
                    self.contentContainer.addSubview(view)
                }
            } else if view.superview != nil {
                view.removeFromSuperview()
            }
        }
    }

    var compactHeights: [QrStudioLook.Kind: CGFloat] = [:]

    private func targetHeight(geometry: QrStudioSheetGeometry) -> CGFloat {
        if let tab = self.currentTab, let height = self.compactHeights[tab] {
            return min(height, geometry.sheet.height)
        }
        return geometry.sheet.height
    }

    func open(tab: QrStudioLook.Kind) {
        let wasOpen = self.motion.isOpen
        self.currentTab = tab
        for (kind, view) in self.contents {
            view.isHidden = kind != tab
        }
        for (kind, container) in self.tintMaskContainers {
            container.isHidden = kind != tab
        }
        self.syncPlayback()
        if let geometry = self.geometry {
            self.motion.setHeight(self.targetHeight(geometry: geometry), animated: wasOpen)
        }
        self.motion.open(animated: true)
        self.updateAttachedContent()
        self.runMotion()
    }

    func close() {
        guard self.motion.isOpen else {
            return
        }
        self.endEditing(true)
        self.syncPlayback()
        self.motion.setSearch(false)
        self.motion.close(velocity: 0.0, travel: 1.0)
        self.runMotion()
    }

    func attachScrollView(_ scrollView: UIScrollView) {
        scrollView.panGestureRecognizer.addTarget(self, action: #selector(self.handleScrollPan(_:)))
    }

    @objc private func handleCapsuleTap(_ recognizer: UITapGestureRecognizer) {
        guard case .ended = recognizer.state, !self.kinds.isEmpty else {
            return
        }
        let location = recognizer.location(in: self.capsuleGlass)
        var closest: (QrStudioLook.Kind, CGFloat)?
        for kind in self.kinds {
            guard let iconView = self.iconViews[kind] else {
                continue
            }
            let distance = abs(iconView.frame.midX - location.x)
            if closest == nil || distance < closest!.1 {
                closest = (kind, distance)
            }
        }
        if let closest {
            self.hapticFeedback.tap()
            self.requestOpenTab?(closest.0)
        }
    }

    private func releaseTravel(geometry: QrStudioSheetGeometry) -> CGFloat {
        return geometry.capsule.minY - (geometry.sheetFrame(height: self.motion.height).minY + self.motion.pull)
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let geometry = self.geometry else {
            return
        }
        let translation = recognizer.translation(in: self).y
        self.syncPlayback()
        switch recognizer.state {
        case .began:
            self.panAnchor = self.motion.pull
            self.motion.drag(self.panAnchor + translation)
        case .changed:
            self.motion.drag(self.panAnchor + translation)
        case .ended, .cancelled, .failed:
            self.motion.release(velocity: recognizer.velocity(in: self).y, travel: self.releaseTravel(geometry: geometry))
        default:
            break
        }
        self.runMotion()
    }

    @objc private func handleScrollPan(_ recognizer: UIPanGestureRecognizer) {
        guard let scrollView = recognizer.view as? UIScrollView, let geometry = self.geometry, self.motion.isOpen else {
            return
        }
        let top = -scrollView.adjustedContentInset.top
        let y = recognizer.translation(in: self).y
        let wasPulling = self.isScrollPulling
        switch recognizer.state {
        case .began:
            self.isScrollPulling = false
            self.scrollPullAnchor = scrollView.contentOffset.y <= top + 0.5 ? y : nil
        case .changed:
            if self.scrollPullAnchor == nil && scrollView.contentOffset.y <= top + 0.5 {
                self.scrollPullAnchor = y
            }
            guard let anchor = self.scrollPullAnchor else {
                return
            }
            let amount = y - anchor
            if amount > 0.0 {
                self.isScrollPulling = true
                scrollView.contentOffset.y = top
                self.syncPlayback()
                self.motion.drag(amount)
            } else if self.isScrollPulling {
                self.isScrollPulling = false
                self.syncPlayback()
                self.motion.drag(0.0)
            } else if scrollView.contentOffset.y > top + 0.5 {
                self.scrollPullAnchor = nil
            }
        case .ended, .cancelled, .failed:
            if self.isScrollPulling {
                scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: top), animated: false)
                self.syncPlayback()
                self.motion.release(velocity: recognizer.velocity(in: self).y, travel: self.releaseTravel(geometry: geometry))
            }
            self.isScrollPulling = false
            self.scrollPullAnchor = nil
        default:
            break
        }
        if wasPulling || self.isScrollPulling {
            self.runMotion()
        }
    }

    func windowFrame(sample: QrStudioSheetMotion.Sample) -> CGRect? {
        guard let geometry = self.geometry else {
            return nil
        }
        return self.frame(geometry: geometry, sample: sample)
    }

    private func frame(geometry: QrStudioSheetGeometry, sample: QrStudioSheetMotion.Sample) -> CGRect {
        return geometry.frame(rise: sample.rise, spread: sample.spread, pull: sample.pull, lift: self.searchLift(sample), height: sample.height)
    }

    private func layout(geometry: QrStudioSheetGeometry, sample: QrStudioSheetMotion.Sample) -> Layout {
        let frame = self.frame(geometry: geometry, sample: sample)
        let corners = geometry.corners(rise: sample.rise, frame: frame)
        let phases = QrStudioSheetGeometry.phases(grown: min(sample.rise, sample.spread))
        let sheetSize = geometry.sheet.size
        let zoom = min(1.08, max(frame.width / max(sheetSize.width, 1.0), frame.height / max(sheetSize.height, 1.0)))
        return Layout(frame: frame, top: corners.top, bottom: corners.bottom, glassAlpha: phases.glass, iconsAlpha: phases.icons, backgroundAlpha: phases.background, contentAlpha: phases.content, zoom: zoom)
    }

    private func removeMotionAnimations() {
        let layers: [CALayer] = [self.clipView.layer, self.clipView.contentLayer, self.clipView.topClipLayer, self.backgroundContainer.layer, self.contentContainer.layer, self.tintMaskContentView.layer]
        for layer in layers {
            for key in layer.animationKeys() ?? [] where key.hasPrefix(QrStudioSheetView.animationKey) {
                layer.removeAnimation(forKey: key)
            }
        }
    }

    private func syncPlayback() {
        guard let playback = self.playback else {
            return
        }
        let now = CACurrentMediaTime()
        if now - playback.start >= playback.duration {
            self.motion.settle(at: playback.samples[playback.samples.count - 1])
        } else {
            self.motion.adopt(playback.sample(at: now), velocity: playback.velocity(at: now))
        }
        self.playback = nil
        self.playbackToken += 1
        self.glassLink = nil
        self.removeMotionAnimations()
        self.progressInterrupted?()
    }

    private func runMotion() {
        guard let geometry = self.geometry else {
            return
        }
        if self.motion.isSettled {
            self.applyImmediately()
            return
        }
        let samples = self.motion.simulate(dt: QrStudioSheetView.sampleStep, maxDuration: 3.0)
        guard samples.count > 1 else {
            self.motion.settle(at: samples[0])
            self.applyImmediately()
            return
        }
        let layouts = samples.map { self.layout(geometry: geometry, sample: $0) }
        var glassUntil = 0.0
        for (index, layout) in layouts.enumerated() where layout.glassAlpha > 0.001 {
            glassUntil = Double(index) * QrStudioSheetView.sampleStep
        }
        let start = CACurrentMediaTime()
        let playback = Playback(start: start, samples: samples, glassUntil: glassUntil)
        self.playback = playback
        self.playbackToken += 1
        let token = self.playbackToken

        let finalLayout = layouts[layouts.count - 1]
        let isWindowVisible = layouts.contains(where: { $0.backgroundAlpha > 0.001 || $0.contentAlpha > 0.001 })

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.applyWindow(finalLayout, geometry: geometry, isVisible: isWindowVisible)
        if isWindowVisible {
            self.addWindowAnimations(layouts, geometry: geometry, duration: playback.duration)
        }
        self.contentContainer.isUserInteractionEnabled = self.motion.isOpen && (finalLayout.contentAlpha > 0.9 || self.contentContainer.isUserInteractionEnabled)
        CATransaction.commit()

        self.applyGlass(self.layout(geometry: geometry, sample: samples[0]))
        if layouts.contains(where: { $0.glassAlpha > 0.001 }) {
            self.glassLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] _ in
                guard let self, let playback = self.playback, let geometry = self.geometry else {
                    return
                }
                let now = CACurrentMediaTime()
                self.applyGlass(self.layout(geometry: geometry, sample: playback.sample(at: now)))
                if now - playback.start > playback.glassUntil {
                    self.glassLink = nil
                }
            })
        } else {
            self.glassLink = nil
            self.capsuleGlass.isHidden = true
        }

        self.progressAnimated?(samples, playback.duration)

        DispatchQueue.main.asyncAfter(deadline: .now() + playback.duration + 0.02, execute: { [weak self] in
            guard let self, self.playbackToken == token, let playback = self.playback else {
                return
            }
            self.playback = nil
            self.glassLink = nil
            self.motion.settle(at: playback.samples[playback.samples.count - 1])
            self.applyImmediately()
        })
    }

    private func applyImmediately() {
        guard let geometry = self.geometry, self.playback == nil else {
            return
        }
        let layout = self.layout(geometry: geometry, sample: self.motion.sample)
        self.updateAttachedContent()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.applyGlass(layout)
        self.applyWindow(layout, geometry: geometry, isVisible: layout.backgroundAlpha > 0.001 || layout.contentAlpha > 0.001)
        self.contentContainer.isUserInteractionEnabled = self.motion.isOpen && layout.contentAlpha > 0.9
        CATransaction.commit()
        self.progressUpdated?()
    }

    private func applyGlass(_ layout: Layout) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let frame = layout.frame
        let isGlassVisible = layout.glassAlpha > 0.001
        self.capsuleGlass.isHidden = !isGlassVisible
        if isGlassVisible {
            self.capsuleGlass.frame = frame
            self.capsuleGlass.nativeBlurRadius = QrStudioGlass.blurRadius(self.glassTint)
            self.capsuleGlass.update(size: frame.size, cornerRadius: min(layout.top, min(frame.width, frame.height) * 0.5), isDark: QrStudioGlass.glassIsDark(self.isDark, tint: self.glassTint), tintColor: self.glassTint, isInteractive: true, transition: .immediate)
            self.capsuleGlass.alpha = layout.glassAlpha
            self.iconsContainer.center = CGPoint(x: frame.width * 0.5, y: frame.height * 0.5)
            self.iconsContainer.alpha = layout.iconsAlpha
        }
        CATransaction.commit()
    }

    private func applyWindow(_ layout: Layout, geometry: QrStudioSheetGeometry, isVisible: Bool) {
        self.clipView.isHidden = !isVisible
        guard isVisible else {
            return
        }
        let frame = layout.frame
        self.clipView.frame = frame
        self.clipView.update(size: frame.size, top: layout.top, bottom: layout.bottom)
        let sheetSize = geometry.sheet.size
        self.backgroundContainer.center = CGPoint(x: frame.width * 0.5, y: self.backgroundContainer.bounds.height * 0.5)
        self.backgroundContainer.alpha = layout.backgroundAlpha
        self.contentContainer.layer.position = CGPoint(x: frame.width * 0.5, y: 0.0)
        self.contentContainer.transform = CGAffineTransform(scaleX: layout.zoom, y: layout.zoom)
        self.contentContainer.alpha = layout.contentAlpha
        self.tintMaskContentView.layer.position = CGPoint(x: sheetSize.width * 0.5, y: 0.0)
        self.tintMaskContentView.transform = CGAffineTransform(scaleX: layout.zoom, y: layout.zoom)
        self.tintMaskContentView.alpha = layout.contentAlpha
    }

    private func addKeyframes(_ layer: CALayer, _ keyPath: String, _ values: [Any], duration: Double) {
        let animation = CAKeyframeAnimation(keyPath: keyPath)
        animation.values = values
        animation.duration = duration
        animation.calculationMode = .linear
        animation.isRemovedOnCompletion = true
        layer.add(animation, forKey: QrStudioSheetView.animationKey + "." + keyPath)
    }

    private func addWindowAnimations(_ layouts: [Layout], geometry: QrStudioSheetGeometry, duration: Double) {
        let frames = layouts.map { $0.frame }
        self.addKeyframes(self.clipView.layer, "position", frames.map { NSValue(cgPoint: CGPoint(x: $0.midX, y: $0.midY)) }, duration: duration)
        self.addKeyframes(self.clipView.layer, "bounds", frames.map { NSValue(cgRect: CGRect(origin: CGPoint(), size: $0.size)) }, duration: duration)
        self.clipView.addCornerAnimations(sizes: frames.map { $0.size }, tops: layouts.map { $0.top }, bottoms: layouts.map { $0.bottom }, duration: duration, add: { layer, keyPath, values in
            self.addKeyframes(layer, keyPath, values, duration: duration)
        })
        let backgroundHeight = self.backgroundContainer.bounds.height
        self.addKeyframes(self.backgroundContainer.layer, "position", frames.map { NSValue(cgPoint: CGPoint(x: $0.width * 0.5, y: backgroundHeight * 0.5)) }, duration: duration)
        self.addKeyframes(self.backgroundContainer.layer, "opacity", layouts.map { NSNumber(value: Float($0.backgroundAlpha)) }, duration: duration)
        self.addKeyframes(self.contentContainer.layer, "position", frames.map { NSValue(cgPoint: CGPoint(x: $0.width * 0.5, y: 0.0)) }, duration: duration)
        self.addKeyframes(self.contentContainer.layer, "transform", layouts.map { NSValue(caTransform3D: CATransform3DMakeScale($0.zoom, $0.zoom, 1.0)) }, duration: duration)
        self.addKeyframes(self.contentContainer.layer, "opacity", layouts.map { NSNumber(value: Float($0.contentAlpha)) }, duration: duration)
        self.addKeyframes(self.tintMaskContentView.layer, "transform", layouts.map { NSValue(caTransform3D: CATransform3DMakeScale($0.zoom, $0.zoom, 1.0)) }, duration: duration)
        self.addKeyframes(self.tintMaskContentView.layer, "opacity", layouts.map { NSNumber(value: Float($0.contentAlpha)) }, duration: duration)
    }
}
