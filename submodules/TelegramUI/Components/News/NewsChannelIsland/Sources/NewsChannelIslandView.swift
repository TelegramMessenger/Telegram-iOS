import Foundation
import UIKit
import Display
import ComponentFlow
import AppBundle
import TelegramPresentationData
import GlassBackgroundComponent
import NewsFeedSupport

/// The channel bar's island (spec §2): one glass capsule whose paint, shine and label change on the Feed2 mockup's
/// clocks. The parent sets this view's frame to the whole panel; the capsule is laid out inside it, between
/// `leftLimit` and `rightLimit`, and only the capsule takes touches. It sits outside the panel's glass container: inside
/// the mockup's equivalent the press scaled the glass about the container's origin.
public final class NewsChannelIslandView: UIView {
    public enum Content: Equatable {
        case addToNews
        case addedToNews
        case addedToChats(muted: Bool)

        var isPaint: Bool {
            if case .addToNews = self {
                return true
            }
            return false
        }
    }

    public struct Labels: Equatable {
        public var addToNews: String
        public var addedToNews: String
        public var addedToChats: String
        public var menuHint: String

        public init(addToNews: String, addedToNews: String, addedToChats: String, menuHint: String) {
            self.addToNews = addToNews
            self.addedToNews = addedToNews
            self.addedToChats = addedToChats
            self.menuHint = menuHint
        }
    }

    public var action: (() -> Void)?

    /// The capsule: it carries the press.
    public let capsuleView = UIView()

    /// The menu's source: the native glass itself, so UIKit's liquid morph (iOS 26+) grows the menu out of the island
    /// with its backdrop and contents, as the navigation bar's single-button capsules do. Targeting a wrapper leaves
    /// the glass behind on screen.
    public var menuSourceView: UIView {
        return self.glassView.transitionView
    }

    /// The menu is about to morph out of the island: its own motion (the press's bounce, a width change, a paint, a
    /// roll) finishes at once, so the morph reads the island at rest. UIKit takes the source's geometry, transform
    /// included, when the menu opens and again when it closes back into the island; a spring still running at either
    /// moment made the menu close into a slightly wrong size.
    public func settleForMenu() {
        let now = CACurrentMediaTime()
        self.press = nil
        if let width = self.width {
            self.width = (width.to, width.to, now)
        }
        self.dye = nil
        self.rollStart = nil
        self.outgoing?.layer.removeFromSuperlayer()
        self.outgoing = nil
        self.layoutCapsule(now: now)
        self.updateLink(now: now)
    }
    private var glassView = GlassBackgroundView()
    private let paintLayer = SimpleLayer()
    private let shineLayer = SimpleLayer()
    private let shineMaskLayer = SimpleShapeLayer()
    private let bandLayers: [SimpleGradientLayer]
    private let labelContainer = SimpleLayer()
    private let button = HighlightTrackingButton()
    private let haptic = HapticFeedback()

    private var content: Content?
    private var labels: Labels?
    private var theme: PresentationTheme?
    private var preferClearGlass = false
    private var leftLimit: CGFloat = 0.0
    private var rightLimit: CGFloat = 0.0

    private var incoming: NewsIslandLabel?
    private var outgoing: NewsIslandLabel?
    private var rollStart: Double?
    private var dye: (start: Double, toPaint: Bool)?
    private var width: (from: CGFloat, to: CGFloat, start: Double)?
    private var press: (from: CGFloat, to: CGFloat, start: Double, spring: NewsSpring, settle: Double)?
    private var link: SharedDisplayLinkDriver.Link?

    private static let morphSettle = NewsSpring.islandMorph.settlingDuration
    private static let pressDownSettle = NewsSpring.islandPressDown.settlingDuration
    private static let pressUpSettle = NewsSpring.islandPressUp.settlingDuration

    override public init(frame: CGRect) {
        self.bandLayers = NewsIslandDye.bands.map { _ in SimpleGradientLayer() }

        super.init(frame: frame)

        self.addSubview(self.capsuleView)
        self.capsuleView.addSubview(self.glassView)
        let contentView = self.glassView.contentView
        contentView.layer.addSublayer(self.paintLayer)
        self.shineLayer.mask = self.shineMaskLayer
        // Plus-lighter over the paint: the masked group composites as one.
        self.shineLayer.compositingFilter = "plusL"
        for band in self.bandLayers {
            band.startPoint = CGPoint(x: 0.0, y: 0.5)
            band.endPoint = CGPoint(x: 1.0, y: 0.5)
            self.shineLayer.addSublayer(band)
        }
        contentView.layer.addSublayer(self.shineLayer)
        contentView.layer.addSublayer(self.labelContainer)
        contentView.addSubview(self.button)

        self.button.highligthedChanged = { [weak self] highlighted in
            self?.setPressed(highlighted)
        }
        self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.link?.invalidate()
    }

    @objc private func buttonPressed() {
        self.action?()
    }

    override public func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return newsIslandHitFrame(capsuleFrame: self.capsuleView.frame, leftLimit: self.leftLimit, rightLimit: self.rightLimit).contains(point)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        self.layoutCapsule(now: CACurrentMediaTime())
    }

    /// `animated: false` puts a changed content in place at once, without the paint, the roll or the width spring: a
    /// menu item is applied before its menu closes, and the menu morphs back into the island already showing it.
    public func update(content: Content, labels: Labels, theme: PresentationTheme, preferClearGlass: Bool, leftLimit: CGFloat, rightLimit: CGFloat, animated: Bool = true) {
        let now = CACurrentMediaTime()
        let previous = self.content
        let labelsChanged = self.labels != labels
        self.labels = labels
        self.theme = theme
        self.preferClearGlass = preferClearGlass
        self.leftLimit = leftLimit
        self.rightLimit = rightLimit

        if let previous, previous != content, !animated {
            self.press = nil
            self.dye = nil
            self.rollStart = nil
            self.outgoing?.layer.removeFromSuperlayer()
            self.outgoing = nil
            self.incoming?.layer.removeFromSuperlayer()
            self.incoming = self.makeLabel(content: content, labels: labels)
        } else if let previous, previous != content {
            if previous.isPaint != content.isPaint {
                self.dye = (now, content.isPaint)
                DispatchQueue.main.asyncAfter(deadline: .now() + NewsIslandMetrics.settleHapticDelay, execute: { [weak self] in
                    self?.haptic.impact(.soft, intensity: NewsIslandMetrics.settleHapticIntensity)
                })
            }
            // A change during a roll rolls on from the label that was arriving (`startRoll(to:)`).
            self.outgoing?.layer.removeFromSuperlayer()
            self.outgoing = self.incoming
            self.incoming = self.makeLabel(content: content, labels: labels)
            self.rollStart = now
        } else if previous == nil || labelsChanged {
            self.incoming?.layer.removeFromSuperlayer()
            self.incoming = self.makeLabel(content: content, labels: labels)
        }
        self.content = content

        let target = newsIslandWidth(labelWidth: self.incoming?.size.width ?? 0.0, available: rightLimit - leftLimit)
        if let previous, previous != content, !animated, let width = self.width, abs(width.to - target) >= 0.5 {
            self.moveToNewGlassView()
        }
        if previous == nil || !animated {
            self.width = (target, target, now)
        } else if let width = self.width, width.to != target {
            self.width = (self.currentWidth(now: now), target, now)
        }

        switch content {
        case .addToNews:
            self.button.accessibilityLabel = labels.addToNews
            self.button.accessibilityHint = nil
        case .addedToNews:
            self.button.accessibilityLabel = labels.addedToNews
            self.button.accessibilityHint = labels.menuHint
        case .addedToChats:
            self.button.accessibilityLabel = labels.addedToChats
            self.button.accessibilityHint = labels.menuHint
        }

        self.layoutCapsule(now: now)
        self.updateLink(now: now)
    }

    /// A width change applied while the menu is open (`animated: false`) moves the island's contents into a new glass
    /// view. The menu closes by morphing into the island's glass, and a close that takes over the still-running opening
    /// keeps UIKit's morph item for the glass the opening started from: it lands where that glass was, at its old width,
    /// and UIKit keeps that glass hidden until the morph ends. A new glass is a destination the morph has not seen.
    /// Nothing is copied: the paint, the shine, the label and the button move.
    private func moveToNewGlassView() {
        let previous = self.glassView
        let glassView = GlassBackgroundView()
        self.capsuleView.insertSubview(glassView, aboveSubview: previous)
        let contentView = glassView.contentView
        contentView.layer.addSublayer(self.paintLayer)
        contentView.layer.addSublayer(self.shineLayer)
        contentView.layer.addSublayer(self.labelContainer)
        contentView.addSubview(self.button)
        previous.removeFromSuperview()
        self.glassView = glassView
    }

    private func makeLabel(content: Content, labels: Labels) -> NewsIslandLabel {
        let M = NewsIslandMetrics.self
        let symbol = UIImage.SymbolConfiguration(pointSize: M.symbolSize, weight: .semibold)
        let chevron = UIImage(systemName: "chevron.down", withConfiguration: symbol) ?? UIImage()
        let pieces: [NewsIslandLabel.Piece]
        switch content {
        case .addToNews:
            let plus = UIImage(systemName: "plus", withConfiguration: symbol) ?? UIImage()
            pieces = [.icon(plus, baselineOffset: 0.0), .text(" " + labels.addToNews)]
        case .addedToNews:
            pieces = [.text(labels.addedToNews + " "), .icon(chevron, baselineOffset: 0.0)]
        case let .addedToChats(muted):
            let bell = UIImage(bundleImageName: muted ? "News/Channel/PillBellSlash" : "News/Channel/PillBell") ?? UIImage()
            pieces = [.icon(bell, baselineOffset: M.bellBaselineOffset), .text(" " + labels.addedToChats + " "), .icon(chevron, baselineOffset: 0.0)]
        }
        return NewsIslandLabel(pieces: pieces, font: Font.semibold(M.fontSize))
    }

    private func currentWidth(now: Double) -> CGFloat {
        guard let width = self.width else {
            return NewsIslandMetrics.minWidth
        }
        let t = now - width.start
        if t >= Self.morphSettle {
            return width.to
        }
        return width.from + (width.to - width.from) * NewsSpring.islandMorph.progress(at: t)
    }

    private func currentScale(now: Double) -> CGFloat {
        guard let press = self.press else {
            return 1.0
        }
        let t = now - press.start
        if t >= press.settle {
            return press.to
        }
        return press.from + (press.to - press.from) * press.spring.progress(at: t)
    }

    private func setPressed(_ pressed: Bool) {
        let now = CACurrentMediaTime()
        let from = self.currentScale(now: now)
        if pressed {
            self.press = (from, NewsIslandMetrics.pressScale, now, .islandPressDown, Self.pressDownSettle)
        } else {
            self.press = (from, 1.0, now, .islandPressUp, Self.pressUpSettle)
        }
        self.layoutCapsule(now: now)
        self.updateLink(now: now)
    }

    private func isMoving(now: Double) -> Bool {
        if let dye = self.dye, now - dye.start < NewsIslandDye.duration {
            return true
        }
        if let rollStart = self.rollStart, now - rollStart < NewsLabelRoll.duration {
            return true
        }
        if let width = self.width, width.from != width.to, now - width.start < Self.morphSettle {
            return true
        }
        if let press = self.press, now - press.start < press.settle {
            return true
        }
        return false
    }

    private func updateLink(now: Double) {
        if self.isMoving(now: now) {
            if self.link == nil {
                self.link = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] _ in
                    self?.tick()
                })
            }
            self.link?.isPaused = false
        } else {
            self.link?.isPaused = true
        }
    }

    private func tick() {
        let now = CACurrentMediaTime()
        self.layoutCapsule(now: now)
        self.updateLink(now: now)
    }

    private func layoutCapsule(now: Double) {
        guard let content = self.content, let theme = self.theme, let incoming = self.incoming else {
            return
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let frame = newsIslandCapsuleFrame(boundsWidth: self.bounds.width, height: self.bounds.height, width: self.currentWidth(now: now), leftLimit: self.leftLimit, rightLimit: self.rightLimit)
        let size = frame.size
        // Bounds and centre, not frame: the capsule carries the press as a transform.
        self.capsuleView.bounds = CGRect(origin: CGPoint(), size: size)
        self.capsuleView.center = CGPoint(x: frame.midX, y: frame.midY)
        let scale = self.currentScale(now: now)
        self.capsuleView.transform = scale == 1.0 ? .identity : CGAffineTransform(scaleX: scale, y: scale)
        self.glassView.frame = CGRect(origin: CGPoint(), size: size)
        self.glassView.update(size: size, cornerRadius: size.height * 0.5, isDark: theme.overallDarkAppearance, tintColor: .init(kind: self.preferClearGlass ? .clear : .panel), isInteractive: true, transition: .immediate)
        // Set on every layout: the glass may replace its native view.
        self.glassView.transitionView.morphsIntoContextMenu = true
        self.button.frame = CGRect(origin: CGPoint(), size: size)

        let dye: NewsIslandDye
        if let current = self.dye, now - current.start < NewsIslandDye.duration {
            dye = NewsIslandDye.at(now - current.start, toPaint: current.toPaint)
        } else {
            self.dye = nil
            dye = NewsIslandDye.still(paint: content.isPaint)
        }
        let inset = NewsIslandMetrics.paintInset
        let inner = CGRect(origin: CGPoint(), size: size).insetBy(dx: inset, dy: inset)
        self.paintLayer.frame = inner
        self.paintLayer.cornerRadius = inner.height * 0.5
        self.paintLayer.backgroundColor = theme.list.itemCheckColors.fillColor.cgColor
        self.paintLayer.opacity = Float(dye.fill)

        self.shineLayer.frame = inner
        self.shineMaskLayer.frame = CGRect(origin: CGPoint(), size: inner.size)
        self.shineMaskLayer.path = UIBezierPath(roundedRect: self.shineMaskLayer.bounds, cornerRadius: inner.height * 0.5).cgPath
        self.shineLayer.opacity = Float(dye.shineAlpha)
        self.shineLayer.isHidden = dye.shineAlpha < 0.001
        let shineCentre = CGPoint(x: dye.shine * inner.width, y: inner.height * 0.5)
        for (band, spec) in zip(self.bandLayers, NewsIslandDye.bands) {
            let halfWidth = spec.halfWidth * inner.width
            band.colors = [UIColor(white: 1.0, alpha: 0.0).cgColor, UIColor(white: 1.0, alpha: spec.peak).cgColor, UIColor(white: 1.0, alpha: 0.0).cgColor]
            // Tall enough to cross the capsule at the tilt; the gradient runs along its x-axis, turned to the normal.
            band.bounds = CGRect(x: 0.0, y: 0.0, width: 2.0 * halfWidth, height: inner.width + inner.height)
            band.position = shineCentre
            band.transform = CATransform3DMakeRotation(-NewsIslandMetrics.shineAngle, 0.0, 0.0, 1.0)
        }

        // White on paint, the panel's control colour on glass.
        let color = theme.chat.inputPanel.panelControlColor.mixedWith(theme.list.itemCheckColors.foregroundColor, alpha: dye.fill).cgColor
        var rollProgress: CGFloat?
        if let rollStart = self.rollStart, now - rollStart < NewsLabelRoll.duration {
            rollProgress = NewsLabelRoll.progress((now - rollStart) / NewsLabelRoll.duration)
        } else {
            self.rollStart = nil
            self.outgoing?.layer.removeFromSuperlayer()
            self.outgoing = nil
        }
        self.labelContainer.frame = CGRect(origin: CGPoint(), size: size)
        for label in [self.outgoing, incoming].compactMap({ $0 }) {
            if label.layer.superlayer == nil {
                self.labelContainer.addSublayer(label.layer)
            }
            // Centred on its line box.
            let origin = CGPoint(x: floorToScreenPixels((size.width - label.size.width) * 0.5), y: floorToScreenPixels((size.height - label.lineHeight) * 0.5) - label.lineTop)
            label.layer.frame = CGRect(origin: origin, size: label.size)
        }
        incoming.apply(color: color, rollProgress: rollProgress, isIncoming: true)
        self.outgoing?.apply(color: color, rollProgress: rollProgress, isIncoming: false)

        CATransaction.commit()
    }
}
