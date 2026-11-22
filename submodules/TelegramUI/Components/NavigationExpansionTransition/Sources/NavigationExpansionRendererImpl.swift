import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import GlassBackgroundComponent

/// Draws an expansion (spec: docs/superpowers/specs/2026-10-16-navigation-expansion-transition-design.md): the
/// origin's and the companion's glass drops in one merging container under the upper screen; the upper screen through
/// the card; the photo and the labels above it, lent live from both screens; everything sampled from the choreography
/// onto keyframes along the coordinator's timeline, apart from the drops' tint, which glass cannot keyframe.
public final class NavigationExpansionRendererImpl: NavigationExpansionRenderer {
    public static func make(source: NavigationExpansionSource, destination: NavigationExpansionDestination, operation: NavigationExpansionOperation) -> NavigationExpansionRenderer? {
        guard let source = source as? NavigationExpansionSourceProviding, let destination = destination as? NavigationExpansionDestinationProviding else {
            return nil
        }
        return NavigationExpansionRendererImpl(source: source, destination: destination)
    }

    private static let keyPrefix = "navigationExpansion."

    private let source: NavigationExpansionSourceProviding
    private let destination: NavigationExpansionDestinationProviding
    public let view: UIView
    public let underView: UIView
    public let barExclusions: NavigationBarTransitionExclusions
    public let barGlassStart: CGFloat = 0.25
    /// How long a new merging glass container is given before glass shown in it must draw (it draws nothing for its
    /// first frames on screen: ~50 ms measured on the simulator; margin for slower devices).
    static let glassContainerWarmUp: Double = 0.1
    public let openSpring: NavigationTransitionSpring
    public let closeSpring: NavigationTransitionSpring
    public private(set) var backButtonFrame: CGRect?

    private var sourceLoan: NavigationExpansionSourceLoan?
    private var destinationLoan: NavigationExpansionDestinationLoan?
    private var choreography: ExpansionChoreography?
    private weak var topView: UIView?
    private var size = CGSize()

    /// Built again in `begin` when the drops must merge closer (`ExpansionGeometry.dropMergeSpacing`).
    private var glassContainer = GlassBackgroundContainerView(spacing: 30.0)
    private let originDrop = GlassBackgroundView()
    /// When the drops' container went on screen (`glassContainerWarmUp`).
    private var glassContainerShownAt: Double = 0.0
    /// The origin drop's model shape, as last given to it: its view's own layer has no corner radius, the glass inside
    /// it does.
    private var originDropCornerRadii = CornerRadii(uniform: 0.0)
    /// The screen's corners differ (iPhone Duo's cover screen): the card's shapes take four radii. Elsewhere they take
    /// one, as they always have.
    private var cornersDiffer = false
    private let companionDrop = GlassBackgroundView()
    private let shadowView = UIView()
    private let cardMask = CALayer()
    /// The upper screen's lent parts, which ride the card under a swipe.
    private let cardContentView = UIView()
    /// Content lifted above the photo (`overlayViews`), cut by a copy of the card's mask.
    private let overlayHost = UIView()
    private let overlayMask = CALayer()
    private let photoWrapper = UIView()
    /// Where the chat's avatar lives while it rides the flying circle (`companionContent`), to put it back.
    private var companionHome: (superview: UIView?, index: Int, center: CGPoint, bounds: CGRect, transform: CGAffineTransform)?
    /// The photo's screen-sized host: it carries the swipe card's pose, as the card's content does.
    private let photoHost = UIView()
    private let photoMask = CAShapeLayer()
    private var originContentHome: CGRect?

    private final class LabelHost {
        let source: NavigationExpansionLabel?
        let destination: NavigationExpansionLabel?
        let sourceHost = UIView()
        let destinationHost = UIView()
        /// The chat label's group: the label and a colour layer composited source-atop over it, rendered on their own
        /// (a mask over the group isolates the compositing from what is behind).
        let sourceGroup = UIView()
        let sourceColorLayer = CALayer()
        let sourceColor: UIColor
        let destinationColor: UIColor
        /// The layers whose multiply colour the ink runs on: a `.multiply` label's on either side (its text layer, emoji
        /// drawn apart and untouched).
        var multiplyLayers: [CALayer] {
            var layers: [CALayer] = []
            if case let .multiply(sourceLayers, _)? = self.source?.coloring {
                layers.append(contentsOf: sourceLayers)
            }
            if case let .multiply(destinationLayers, _)? = self.destination?.coloring {
                layers.append(contentsOf: destinationLayers)
            }
            return layers
        }

        init(source: NavigationExpansionLabel?, destination: NavigationExpansionLabel?, destinationColor: UIColor) {
            self.source = source
            self.destination = destination
            self.destinationColor = destinationColor
            switch source?.coloring {
            case let .recolor(color)?, let .multiply(_, color)?:
                self.sourceColor = color
            default:
                self.sourceColor = destinationColor
            }
        }
    }
    private var labelHosts: [LabelHost] = []
    /// A destination label's follower (`NavigationExpansionLabel.followers`), measured before anything is lent: its anchor
    /// point on screen, how many screen points one of its superlayer's points is, and its own transform.
    private struct Follower {
        let layer: CALayer
        let label: Int
        let anchor: CGPoint
        let unit: CGSize
        let rest: CATransform3D
    }
    private var followers: [Follower] = []
    /// A view of the page below the header (`NavigationExpansionDestinationLoan.pageViews`, `pageEdgeViews`,
    /// `landingViews`), measured before anything is lent: how many screen points one of its superlayer's points is,
    /// vertically, and its own transform.
    private struct PageRider {
        let layer: CALayer
        let unit: CGFloat
        let rest: CATransform3D
        /// A landing view's (`landingViews`): it takes only the page's overshoot past its resting place.
        let landsOnly: Bool
        /// An edge's (`pageEdgeViews`): how many screen points one of its own points is, vertically, and its own sublayer
        /// transform, which takes its content back to where it stands.
        let content: (unit: CGFloat, rest: CATransform3D)?
    }
    private var pageRiders: [PageRider] = []
    private struct Flyer {
        let layer: CALayer
        let restCenter: CGPoint
        let restSize: CGSize
        let unit: CGSize
        let rest: CATransform3D
    }
    private var flyers: [Flyer] = []
    private var tintLink: SharedDisplayLinkDriver.Link?
    private var tintTimeline: (timeline: NavigationExpansionTimeline, fills: [CGFloat])?
    private var appliedTintFill: CGFloat = -1.0
    private var appliedTintTime: Double = -Double.infinity
    private var touchedLayers: [CALayer] = []

    init(source: NavigationExpansionSourceProviding, destination: NavigationExpansionDestinationProviding) {
        self.source = source
        self.destination = destination
        self.view = UIView()
        self.view.isUserInteractionEnabled = false
        self.underView = UIView()
        self.underView.isUserInteractionEnabled = false
        self.barExclusions = source.expansionBarExclusions
        self.openSpring = destination.expansionOpenSpring ?? (destination.expansionPath == .photo ? NavigationTransitionSpring(duration: 0.48, bounce: 0.2) : NavigationTransitionSpring(duration: 0.44, bounce: 0.28))
        self.closeSpring = destination.expansionCloseSpring ?? NavigationTransitionSpring(duration: 0.4, bounce: 0.22)
        self.cardMask.backgroundColor = UIColor.black.cgColor
        self.overlayMask.backgroundColor = UIColor.black.cgColor
        if #available(iOS 13.0, *) {
            self.cardMask.cornerCurve = .continuous
            self.overlayMask.cornerCurve = .continuous
        }
        self.overlayHost.isUserInteractionEnabled = false
        self.photoMask.fillColor = UIColor.black.cgColor
        self.shadowView.isUserInteractionEnabled = false
        self.shadowView.layer.shadowColor = UIColor.black.cgColor
        self.shadowView.layer.shadowRadius = 24.0
        self.shadowView.layer.shadowOffset = CGSize(width: 0.0, height: 10.0)
        self.shadowView.layer.shadowOpacity = 0.0
    }

    // MARK: Begin

    public func begin(topView: UIView, bottomView: UIView, size: CGSize, time: CGFloat, isOpening: Bool) {
        self.topView = topView
        self.size = size
        guard let container = topView.superview else {
            return
        }
        // Measured where the renderer draws (its screen-sized view in the screens' container), not in the container: a
        // conversion into the container includes the container's own sublayer transform, which shifts the screens
        // beneath a modal and is still in place when a pop that also removes the modal begins. Measured so, the
        // geometry keeps no shift, and the renderer's views follow the container's transform as it animates away.
        let screen: UIView = self.view.superview === container ? self.view : container
        guard let sourceLoan = self.source.lendExpansionSource(in: screen) else {
            return
        }
        guard let destinationLoan = self.destination.lendExpansionDestination(in: screen) else {
            self.source.returnExpansionSource()
            return
        }
        self.sourceLoan = sourceLoan
        self.destinationLoan = destinationLoan
        self.backButtonFrame = destinationLoan.backButtonFrame
        for (index, label) in destinationLoan.labels.enumerated() {
            for view in label.followers {
                guard let superlayer = view.layer.superlayer else {
                    continue
                }
                let unit = superlayer.convert(CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0), to: screen.layer).size
                self.followers.append(Follower(layer: view.layer, label: index, anchor: superlayer.convert(view.layer.position, to: screen.layer), unit: unit, rest: view.layer.transform))
                self.touchedLayers.append(view.layer)
            }
        }
        for view in destinationLoan.flyingViews {
            guard let superlayer = view.layer.superlayer else {
                continue
            }
            let unit = superlayer.convert(CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0), to: screen.layer).size
            let restFrame = view.convert(view.bounds, to: screen)
            self.flyers.append(Flyer(layer: view.layer, restCenter: CGPoint(x: restFrame.midX, y: restFrame.midY), restSize: restFrame.size, unit: unit, rest: view.layer.transform))
            self.touchedLayers.append(view.layer)
        }
        for (view, isEdge, landsOnly) in destinationLoan.pageViews.map({ ($0, false, false) }) + destinationLoan.pageEdgeViews.map({ ($0, true, false) }) + destinationLoan.landingViews.map({ ($0, false, true) }) {
            guard let superlayer = view.layer.superlayer else {
                continue
            }
            let point = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
            let unit = superlayer.convert(point, to: screen.layer).height
            let content = isEdge ? (unit: view.layer.convert(point, to: screen.layer).height, rest: view.layer.sublayerTransform) : nil
            self.pageRiders.append(PageRider(layer: view.layer, unit: unit, rest: view.layer.transform, landsOnly: landsOnly, content: content))
            self.touchedLayers.append(view.layer)
        }

        var labels: [ExpansionLabelGeometry] = []
        for (index, sourceLabel) in sourceLoan.labels.enumerated() where index < destinationLoan.labels.count {
            let destinationLabel = destinationLoan.labels[index]
            labels.append(ExpansionLabelGeometry(sourceCenter: sourceLabel.screenCenter, sourceSize: sourceLabel.textSize, destinationCenter: destinationLabel.screenCenter, destinationSize: destinationLabel.textSize, photoCenter: destinationLabel.screenCenter, photoSize: destinationLabel.textSize))
        }
        // A label the lower screen does not show (a channel's title without a status line) comes from where it would
        // stand there: under the label above it, at that label's scale. It fades in as the labels cross; without a place
        // it was never shown until the upper screen had it back.
        for index in labels.count ..< destinationLoan.labels.count {
            guard let above = labels.last else {
                break
            }
            let destinationLabel = destinationLoan.labels[index]
            let scale = above.sourceSize.height / max(1.0, above.destinationSize.height)
            let size = CGSize(width: destinationLabel.textSize.width * scale, height: destinationLabel.textSize.height * scale)
            let center = CGPoint(x: above.sourceCenter.x, y: above.sourceCenter.y + (above.sourceSize.height + size.height) * 0.5)
            labels.append(ExpansionLabelGeometry(sourceCenter: center, sourceSize: size, destinationCenter: destinationLabel.screenCenter, destinationSize: destinationLabel.textSize, photoCenter: destinationLabel.screenCenter, photoSize: destinationLabel.textSize))
        }
        var geometry = ExpansionGeometry(screenSize: size, screenCornerRadii: destinationLoan.screenCornerRadii, origin: sourceLoan.origin, companion: sourceLoan.companion, companionPhotoDiameter: sourceLoan.companionPhotoDiameter, avatar: destinationLoan.avatar, photo: destinationLoan.photo, labels: labels, carriedEdge: destinationLoan.carriedEdge, appearing: destinationLoan.appearingViews.map { $0.convert($0.bounds, to: screen) })
        if let backgroundOpening = destinationLoan.backgroundOpening {
            geometry.backgroundOpening = backgroundOpening
        }
        geometry.avatarCornerFraction = destinationLoan.avatarCornerFraction
        if let backgroundClosing = destinationLoan.backgroundClosing {
            geometry.backgroundClosing = backgroundClosing
        }
        self.choreography = ExpansionChoreography(geometry: geometry, path: self.destination.expansionPath, duration: self.openSpring.response)
        self.cornersDiffer = !geometry.screenCornerRadii.isUniform

        // Under the upper screen: the drops, merging.
        if self.glassContainer.spacing != geometry.dropMergeSpacing {
            self.glassContainer = GlassBackgroundContainerView(spacing: geometry.dropMergeSpacing)
        }
        self.glassContainer.frame = CGRect(origin: CGPoint(), size: size)
        self.glassContainer.update(size: size, isDark: sourceLoan.isDark, transition: .immediate)
        self.shadowView.frame = CGRect(origin: CGPoint(), size: size)
        let screenRadii = destinationLoan.screenCornerRadii
        if self.cornersDiffer {
            func corner(_ radius: CGFloat) -> CGSize {
                return CGSize(width: radius, height: radius)
            }
            self.shadowView.layer.shadowPath = navigationExpansionRoundedPath(rect: CGRect(origin: CGPoint(), size: size), topLeft: corner(screenRadii.topLeft), topRight: corner(screenRadii.topRight), bottomLeft: corner(screenRadii.bottomLeft), bottomRight: corner(screenRadii.bottomRight))
        } else {
            self.shadowView.layer.shadowPath = UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), cornerRadius: screenRadii.topLeft).cgPath
        }
        self.underView.addSubview(self.shadowView)
        self.underView.addSubview(self.glassContainer)
        // A new merging container draws nothing for its first frames on screen: drops that show from the start (the
        // open's) begin outside it, apart as the chat's own pill and capsule are, and join it once it is up.
        self.glassContainerShownAt = CACurrentMediaTime()
        let dropsShowAtOnce = (self.choreography?.frame(ExpansionClock(time: time, isOpening: isOpening), press: .none).glass ?? 0.0) > 0.001
        let dropsHost: UIView = dropsShowAtOnce ? self.underView : self.glassContainer.contentView
        dropsHost.addSubview(self.originDrop)
        if sourceLoan.companion != nil {
            dropsHost.addSubview(self.companionDrop)
        }
        // The chat's avatar is lent to the flying circle once it is set up (below); without a circle it just hides.
        sourceLoan.companionView?.alpha = 0.0

        // The upper screen through the card.
        topView.layer.mask = self.cardMask

        // Above: the photo and the labels.
        self.cardContentView.frame = CGRect(origin: CGPoint(), size: size)
        self.view.addSubview(self.cardContentView)
        if !destinationLoan.overlayViews.isEmpty {
            self.overlayHost.frame = CGRect(origin: CGPoint(), size: size)
            self.overlayHost.layer.mask = self.overlayMask
            self.cardContentView.addSubview(self.overlayHost)
            for overlay in destinationLoan.overlayViews {
                let frame = overlay.convert(overlay.bounds, to: screen)
                overlay.removeFromSuperview()
                overlay.frame = frame
                self.overlayHost.addSubview(overlay)
            }
        }
        if let avatarView = destinationLoan.avatarView {
            let rest = destinationLoan.avatarRestFrame
            self.photoWrapper.bounds = CGRect(origin: CGPoint(), size: rest.size)
            self.photoWrapper.layer.mask = self.photoMask
            self.photoMask.frame = self.photoWrapper.bounds
            let frame = avatarView.convert(avatarView.bounds, to: screen)
            avatarView.removeFromSuperview()
            avatarView.frame = frame.offsetBy(dx: -rest.minX, dy: -rest.minY)
            self.photoWrapper.addSubview(avatarView)
            // Under the labels (the prototype's titles lie on the photo), above the card-cut upper screen.
            self.photoHost.frame = CGRect(origin: CGPoint(), size: size)
            self.photoHost.isUserInteractionEnabled = false
            self.photoHost.addSubview(self.photoWrapper)
            self.view.insertSubview(self.photoHost, belowSubview: self.cardContentView)

            // The chat's own avatar (live: an animated avatar keeps playing) rides the circle above the profile's and
            // cross-fades with it, placed so that where the clock is at the chat's end it is exactly where it was.
            if let companionView = sourceLoan.companionView, let choreography = self.choreography, let start = choreography.frame(ExpansionClock(time: 0.0, isOpening: isOpening), press: sourceLoan.press).photo, start.width > 0.0, start.height > 0.0 {
                let screenFrame = companionView.convert(companionView.bounds, to: screen)
                let scaleX = rest.width / start.width
                let scaleY = rest.height / start.height
                self.companionHome = (companionView.superview, companionView.superview?.subviews.firstIndex(of: companionView) ?? 0, companionView.center, companionView.bounds, companionView.transform)
                companionView.removeFromSuperview()
                companionView.transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
                companionView.center = CGPoint(x: rest.width * 0.5 + (screenFrame.midX - start.midX) * scaleX, y: rest.height * 0.5 + (screenFrame.midY - start.midY) * scaleY)
                companionView.alpha = choreography.frame(ExpansionClock(time: time, isOpening: isOpening), press: sourceLoan.press).companionContent
                self.photoWrapper.addSubview(companionView)
            }
        }
        if let originContent = sourceLoan.originContent {
            self.originContentHome = originContent.frame
            originContent.isUserInteractionEnabled = false
            self.view.addSubview(originContent)
        }
        for (index, label) in sourceLoan.labels.enumerated() {
            let destinationLabel = index < destinationLoan.labels.count ? destinationLoan.labels[index] : nil
            let destinationColor = index < destinationLoan.labelColors.count ? destinationLoan.labelColors[index] : .white
            let host = LabelHost(source: label, destination: destinationLabel, destinationColor: destinationColor)
            self.mount(label, in: host.sourceHost, group: host.sourceGroup, colorLayer: host.sourceColorLayer)
            self.view.addSubview(host.sourceHost)
            if let destinationLabel {
                self.mount(destinationLabel, in: host.destinationHost, group: nil, colorLayer: nil)
                self.cardContentView.addSubview(host.destinationHost)
            }
            self.labelHosts.append(host)
        }
        // The upper screen's labels the lower screen does not show, on the places measured for them above.
        for index in sourceLoan.labels.count ..< destinationLoan.labels.count {
            let destinationLabel = destinationLoan.labels[index]
            let destinationColor = index < destinationLoan.labelColors.count ? destinationLoan.labelColors[index] : .white
            let host = LabelHost(source: nil, destination: destinationLabel, destinationColor: destinationColor)
            self.view.addSubview(host.sourceHost)
            self.mount(destinationLabel, in: host.destinationHost, group: nil, colorLayer: nil)
            self.cardContentView.addSubview(host.destinationHost)
            self.labelHosts.append(host)
        }
        for view in destinationLoan.appearingViews + destinationLoan.appearingCompanions.flatMap({ $0 }) + destinationLoan.backgroundViews + destinationLoan.listViews + destinationLoan.patternViews {
            self.touchedLayers.append(view.layer)
        }

        if let frame = self.frame(time: time, isOpening: isOpening, sampleTime: 0.0) {
            self.apply(frame, pose: .none)
        }
    }

    /// A label's view in its host, its text's centre at the host's origin. A `.recolor` label sits in a group with a
    /// colour layer composited source-atop over it (measured, Task 1: a node lent as a MASK drops its rendered contents
    /// out of the window; in the window it keeps them). Its accessories ride beside the group, not recoloured.
    private func mount(_ label: NavigationExpansionLabel, in host: UIView, group: UIView?, colorLayer: CALayer?) {
        // The host's position is its centre, so its bounds are centred on its origin; the label stands with its text's
        // centre there.
        let size = label.view.bounds.size
        let labelFrame = CGRect(origin: CGPoint(x: -label.textCenter.x, y: -label.textCenter.y), size: size)
        host.bounds = CGRect(x: -size.width * 0.5, y: -size.height * 0.5, width: size.width, height: size.height)
        label.view.removeFromSuperview()
        if case let .recolor(color) = label.coloring, let group, let colorLayer {
            label.view.frame = CGRect(origin: CGPoint(), size: size)
            group.frame = labelFrame
            let isolation = CALayer()
            isolation.frame = group.bounds
            isolation.backgroundColor = UIColor.black.cgColor
            group.layer.mask = isolation
            group.addSubview(label.view)
            colorLayer.frame = group.bounds
            colorLayer.backgroundColor = color.cgColor
            colorLayer.compositingFilter = "sourceAtop"
            group.layer.addSublayer(colorLayer)
            host.addSubview(group)
        } else {
            label.view.frame = labelFrame
            host.addSubview(label.view)
        }
        for accessory in label.accessories {
            accessory.view.removeFromSuperview()
            accessory.view.frame = accessory.frame.offsetBy(dx: labelFrame.minX, dy: labelFrame.minY)
            host.addSubview(accessory.view)
        }
    }

    // MARK: A frame

    private func press(at sampleTime: Double) -> ExpansionPress {
        guard let press = self.sourceLoan?.press else {
            return .none
        }
        let origin = NavigationSpringCurve(from: press.origin, target: 0.0, spring: NavigationTransitionSpring(duration: 0.4, bounce: 0.5), overshoots: true, rest: .expansion)
        let companion = NavigationSpringCurve(from: press.companion, target: 0.0, spring: NavigationTransitionSpring(duration: 0.37, bounce: 0.6), overshoots: true, rest: .expansion)
        return ExpansionPress(origin: origin.value(at: sampleTime), companion: companion.value(at: sampleTime))
    }

    private func frame(time: CGFloat, isOpening: Bool, sampleTime: Double) -> ExpansionFrame? {
        return self.choreography?.frame(ExpansionClock(time: time, isOpening: isOpening), press: self.press(at: sampleTime))
    }

    /// The photo's shape in its view's own points, which the wrapper scales on each axis apart (the expanded photo, taller
    /// than wide, into the flying circle): a corner round on screen is an ellipse there.
    private func photoPath(_ frame: ExpansionFrame, rest: CGRect) -> CGPath? {
        guard let photo = frame.photo, rest.width > 0.0, rest.height > 0.0 else {
            return nil
        }
        let scaleX = max(0.0001, photo.width / rest.width)
        let scaleY = max(0.0001, photo.height / rest.height)
        func corner(_ radius: CGFloat) -> CGSize {
            return CGSize(width: radius / scaleX, height: radius / scaleY)
        }
        let radii = frame.photoCornerRadii
        return navigationExpansionRoundedPath(rect: CGRect(origin: CGPoint(), size: rest.size), topLeft: corner(radii.topLeft), topRight: corner(radii.topRight), bottomLeft: corner(radii.bottomLeft), bottomRight: corner(radii.bottomRight))
    }

    private func photoTransform(_ frame: ExpansionFrame, rest: CGRect) -> (center: CGPoint, transform: CATransform3D)? {
        guard let photo = frame.photo, rest.width > 0.0, rest.height > 0.0 else {
            return nil
        }
        return (CGPoint(x: photo.midX, y: photo.midY), CATransform3DMakeScale(photo.width / rest.width, photo.height / rest.height, 1.0))
    }

    /// A follower's transform when its label stands at `label`: its label's motion from rest (to the frame's centre,
    /// scaled about it), in its superlayer's points, after its own transform.
    private func followerTransform(_ follower: Follower, _ label: ExpansionLabelFrame) -> CATransform3D {
        guard let rest = self.destinationLoan.flatMap({ follower.label < $0.labels.count ? $0.labels[follower.label].screenCenter : nil }) else {
            return follower.rest
        }
        let scale = label.destinationScale
        let target = CGPoint(x: label.center.x + (follower.anchor.x - rest.x) * scale, y: label.center.y + (follower.anchor.y - rest.y) * scale)
        let dx = (target.x - follower.anchor.x) / max(follower.unit.width, 0.0001)
        let dy = (target.y - follower.anchor.y) / max(follower.unit.height, 0.0001)
        return CATransform3DConcat(CATransform3DConcat(follower.rest, CATransform3DMakeScale(scale, scale, 1.0)), CATransform3DMakeTranslation(dx, dy, 0.0))
    }

    /// A page view's transform with the page `page` points below its resting place: after its own, in its superlayer's
    /// points. A landing view takes only the overshoot past its resting place.
    private func pageTransform(_ rider: PageRider, page: CGFloat) -> CATransform3D {
        let offset = rider.landsOnly ? max(page, 0.0) : page
        return CATransform3DConcat(rider.rest, CATransform3DMakeTranslation(0.0, offset / max(rider.unit, 0.0001), 0.0))
    }

    /// An edge's sublayer transform with the page `page` points below its resting place: while the page is above it, its
    /// content as far back, in its own points, so only the edge moves; past it, none, so the content lands with the page.
    private func pageContentTransform(_ rider: PageRider, page: CGFloat) -> CATransform3D? {
        return rider.content.map { CATransform3DConcat($0.rest, CATransform3DMakeTranslation(0.0, -min(page, 0.0) / max($0.unit, 0.0001), 0.0)) }
    }

    private func originContentPlacement(_ frame: ExpansionFrame) -> (center: CGPoint, transform: CATransform3D)? {
        guard let home = self.originContentHome, let origin = self.sourceLoan?.origin, origin.width > 0.0, origin.height > 0.0 else {
            return nil
        }
        let scale = min(frame.card.height / origin.height, 1.3)
        let center = CGPoint(x: frame.card.midX + (home.midX - origin.midX) * scale, y: frame.card.midY + (home.midY - origin.midY) * scale)
        return (center, CATransform3DMakeScale(scale, scale, 1.0))
    }

    private func flyerTransform(_ flyer: Flyer, _ frame: ExpansionFrame) -> CATransform3D {
        guard let origin = self.sourceLoan?.origin, let lead = self.flyers.first, lead.restSize.width > 0.0, lead.restSize.height > 0.0 else {
            return flyer.rest
        }
        let p = frame.flight
        let startScale = min(origin.width / lead.restSize.width, origin.height / lead.restSize.height)
        let scale = ExpansionCurve.mix(startScale, 1.0, p)
        let leadCenter = ExpansionCurve.mix(CGPoint(x: origin.midX, y: origin.midY), lead.restCenter, p)
        let center = CGPoint(x: leadCenter.x + (flyer.restCenter.x - lead.restCenter.x) * scale, y: leadCenter.y + (flyer.restCenter.y - lead.restCenter.y) * scale)
        let dx = (center.x - flyer.restCenter.x) / max(flyer.unit.width, 0.0001)
        let dy = (center.y - flyer.restCenter.y) / max(flyer.unit.height, 0.0001)
        return CATransform3DConcat(CATransform3DConcat(flyer.rest, CATransform3DMakeScale(scale, scale, 1.0)), CATransform3DMakeTranslation(dx, dy, 0.0))
    }

    private func holdOpacity(_ layer: CALayer, _ value: CGFloat) {
        let key = NavigationExpansionRendererImpl.keyPrefix + "opacity"
        if !self.touchedLayers.contains(where: { $0 === layer }) {
            self.touchedLayers.append(layer)
        }
        let fraction = Float(min(max(value, 0.0), 1.0))
        if fraction >= 0.9999 {
            layer.removeAnimation(forKey: key)
            return
        }
        let opacity = layer.opacity * fraction
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = NSNumber(value: opacity)
        animation.toValue = NSNumber(value: opacity + 0.0001)
        animation.duration = 1000.0
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        layer.add(animation, forKey: key)
    }

    private func color(_ host: LabelHost, ink: CGFloat) -> UIColor {
        return host.sourceColor.mixedWith(host.destinationColor, alpha: min(max(ink, 0.0), 1.0))
    }

    private func dropTint(fill: CGFloat) -> GlassBackgroundView.TintColor {
        guard let sourceLoan = self.sourceLoan else {
            return .init(kind: .panel)
        }
        guard let glassTint = self.destinationLoan?.glassTint else {
            return sourceLoan.originTint
        }
        return GlassBackgroundView.TintColor.blended(from: sourceLoan.originTint, to: .init(kind: .custom(style: .default, color: glassTint.withAlphaComponent(0.55))), fraction: min(max(fill, 0.0), 1.0), isDark: sourceLoan.isDark)
    }

    private func updateOriginDrop(size: CGSize, radii: CornerRadii, isDark: Bool, tintColor: GlassBackgroundView.TintColor) {
        if self.cornersDiffer {
            self.originDrop.update(size: size, cornerRadii: glassCornerRadii(radii), isDark: isDark, tintColor: tintColor, transition: .immediate)
        } else {
            self.originDrop.update(size: size, cornerRadius: radii.topLeft, isDark: isDark, tintColor: tintColor, transition: .immediate)
        }
    }

    /// Whether the card's masks take four radii: where the screen's corners differ and the OS has per-corner radii. Else
    /// one, the roundest.
    private var masksTakeCornerRadii: Bool {
        return self.cornersDiffer && CALayer.cornerRadiiSupported
    }

    /// One frame, set directly.
    private func apply(_ f: ExpansionFrame, pose: NavigationExpansionCardPose) {
        guard let sourceLoan = self.sourceLoan, let destinationLoan = self.destinationLoan else {
            return
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let fill = min(max(f.tint / 0.55, 0.0), 1.0)
        self.appliedTintFill = fill
        self.originDrop.frame = f.card
        self.originDropCornerRadii = f.cardCornerRadii
        self.updateOriginDrop(size: f.card.size, radii: f.cardCornerRadii, isDark: sourceLoan.isDark, tintColor: self.dropTint(fill: fill))
        if let circle = f.circle {
            self.companionDrop.frame = circle
            self.companionDrop.update(size: circle.size, cornerRadius: circle.width * 0.5, isDark: sourceLoan.isDark, tintColor: self.dropTint(fill: fill), transition: .immediate)
        }
        self.glassContainer.alpha = f.glass
        // The card follows the clock (the screen at 1, while a finger holds the swipe); the pose carries it.
        for mask in [self.cardMask, self.overlayMask] {
            mask.frame = f.card
            if self.masksTakeCornerRadii {
                mask.setCornerRadii(f.cardCornerRadii)
            } else {
                mask.cornerRadius = f.cardCornerRadii.maximum
            }
        }
        if let (center, transform) = self.photoTransform(f, rest: destinationLoan.avatarRestFrame) {
            self.photoWrapper.layer.position = center
            self.photoWrapper.layer.transform = transform
            self.photoMask.path = self.photoPath(f, rest: destinationLoan.avatarRestFrame)
        }
        if self.companionHome != nil {
            sourceLoan.companionView?.alpha = f.companionContent
        }
        if let originContent = sourceLoan.originContent, let placement = self.originContentPlacement(f) {
            originContent.layer.position = placement.center
            originContent.layer.transform = placement.transform
            originContent.alpha = f.originContent
        }
        for (index, host) in self.labelHosts.enumerated() where index < f.labels.count {
            let label = f.labels[index]
            host.sourceHost.layer.position = label.center
            host.sourceHost.layer.transform = CATransform3DMakeScale(label.sourceScale, label.sourceScale, 1.0)
            host.sourceHost.alpha = label.sourceAlpha
            host.destinationHost.layer.position = label.center
            host.destinationHost.layer.transform = CATransform3DMakeScale(label.destinationScale, label.destinationScale, 1.0)
            host.destinationHost.alpha = label.destinationAlpha
            let color = self.color(host, ink: f.ink)
            host.sourceColorLayer.backgroundColor = color.cgColor
            for layer in host.multiplyLayers {
                layer.layerTintColor = color.cgColor
            }
        }
        for follower in self.followers where follower.label < f.labels.count {
            follower.layer.transform = self.followerTransform(follower, f.labels[follower.label])
        }
        for (index, view) in destinationLoan.appearingViews.enumerated() where index < f.appearing.count {
            let a = f.appearing[index]
            let companions = index < destinationLoan.appearingCompanions.count ? destinationLoan.appearingCompanions[index] : []
            for view in [view] + companions {
                self.holdOpacity(view.layer, a.alpha)
                view.layer.transform = CATransform3DScale(CATransform3DMakeTranslation(0.0, a.offset, 0.0), a.scale, a.scale, 1.0)
            }
        }
        for flyer in self.flyers {
            flyer.layer.transform = self.flyerTransform(flyer, f)
            self.holdOpacity(flyer.layer, f.flightAlpha)
        }
        for rider in self.pageRiders {
            rider.layer.transform = self.pageTransform(rider, page: f.page)
            if let content = self.pageContentTransform(rider, page: f.page) {
                rider.layer.sublayerTransform = content
            }
        }
        for view in destinationLoan.backgroundViews {
            self.holdOpacity(view.layer, f.background)
        }
        for view in destinationLoan.listViews {
            self.holdOpacity(view.layer, f.list)
        }
        for view in destinationLoan.patternViews {
            self.holdOpacity(view.layer, f.pattern)
        }
        let transform = self.viewTransform(pose)
        self.topView?.transform = transform
        self.cardContentView.transform = transform
        self.photoHost.transform = transform
        self.glassContainer.transform = transform
        self.shadowView.transform = transform
        self.shadowView.layer.shadowOpacity = Float(0.3 * pose.fade(width: self.size.width))
        CATransaction.commit()
    }

    // MARK: NavigationExpansionRenderer

    public func update(time: CGFloat, isOpening: Bool, pose: NavigationExpansionCardPose) {
        guard let frame = self.frame(time: time, isOpening: isOpening, sampleTime: 10.0) else {
            return
        }
        self.removeKeyframes()
        // A frame set directly carries its own tint: the timeline's tint (and its clock, stopped when a transition is
        // ended early) no longer applies.
        self.stopTint()
        self.apply(frame, pose: pose)
    }

    /// The drops move into their container, keeping their keyframes (both hosts fill the screen at the same origin).
    private func dropsJoinContainer() {
        guard self.sourceLoan != nil, self.originDrop.superview === self.underView else {
            return
        }
        self.glassContainer.contentView.addSubview(self.originDrop)
        if self.companionDrop.superview === self.underView {
            self.glassContainer.contentView.addSubview(self.companionDrop)
        }
    }

    private func stopTint() {
        self.tintLink?.invalidate()
        self.tintLink = nil
        self.tintTimeline = nil
    }

    /// The pose's transform is in screen coordinates (about the touch point); a view's transform applies about its centre.
    /// For the screen-sized views it moves: v -> M(v + c) - c.
    private func viewTransform(_ pose: NavigationExpansionCardPose) -> CGAffineTransform {
        let center = CGPoint(x: self.size.width * 0.5, y: self.size.height * 0.5)
        return CGAffineTransform(translationX: center.x, y: center.y).concatenating(pose.transform(width: self.size.width)).concatenating(CGAffineTransform(translationX: -center.x, y: -center.y))
    }

    public func barFraction(time: CGFloat, isOpening: Bool) -> CGFloat {
        return ExpansionClock(time: time, isOpening: isOpening).phase((0.10, 0.45), (0.30, 0.80))
    }

    public func animate(timeline: NavigationExpansionTimeline) {
        guard let sourceLoan = self.sourceLoan, let destinationLoan = self.destinationLoan else {
            return
        }
        let timing = timeline.timing
        let frames = zip(timeline.times, timing.sampleTimes).compactMap { self.frame(time: $0.0, isOpening: timeline.isOpening, sampleTime: $0.1) }
        guard let last = frames.last, frames.count == timing.sampleTimes.count else {
            return
        }
        let poses = timeline.poses.count == frames.count ? timeline.poses : frames.map { _ in NavigationExpansionCardPose.none }
        self.apply(last, pose: poses.last ?? .none)

        func add(_ layer: CALayer, _ keyPath: String, _ values: [Any]) {
            addNavigationKeyframes(to: layer, key: NavigationExpansionRendererImpl.keyPrefix + keyPath, keyPath: keyPath, values: values, timing: timing)
            if !self.touchedLayers.contains(where: { $0 === layer }) {
                self.touchedLayers.append(layer)
            }
        }
        func point(_ p: CGPoint) -> NSValue {
            return NSValue(cgPoint: p)
        }
        func bounds(_ r: CGRect) -> NSValue {
            return NSValue(cgRect: CGRect(origin: CGPoint(), size: r.size))
        }
        func number(_ v: CGFloat) -> NSNumber {
            return NSNumber(value: Float(v))
        }
        func heldOpacity(_ layer: CALayer, _ values: [CGFloat]) {
            if !self.touchedLayers.contains(where: { $0 === layer }) {
                self.touchedLayers.append(layer)
            }
            guard let first = values.first, values.contains(where: { abs($0 - first) > 0.0001 }) else {
                self.holdOpacity(layer, values.last ?? 1.0)
                return
            }
            let animation = makeNavigationKeyframeAnimation(keyPath: "opacity", values: values.map { NSNumber(value: layer.opacity * Float($0)) }, timing: timing, layer: layer)
            animation.isRemovedOnCompletion = false
            layer.add(animation, forKey: NavigationExpansionRendererImpl.keyPrefix + "opacity")
        }

        // The drops. Their glass is laid out from each drop's top-left, so the drops' own bounds move with their shape.
        add(self.originDrop.layer, "position", frames.map { point(CGPoint(x: $0.card.midX, y: $0.card.midY)) })
        add(self.originDrop.layer, "bounds", frames.map { bounds($0.card) })
        self.originDropCornerRadii = last.cardCornerRadii
        let lastDropTint = self.dropTint(fill: min(max(last.tint / 0.55, 0.0), 1.0))
        if self.cornersDiffer {
            self.originDrop.animateShape(sizes: frames.map { $0.card.size }, cornerRadii: frames.map { glassCornerRadii($0.cardCornerRadii) }, timing: timing, isDark: sourceLoan.isDark, tintColor: lastDropTint)
        } else {
            self.originDrop.animateShape(sizes: frames.map { $0.card.size }, cornerRadii: frames.map { $0.cardCornerRadii.topLeft }, timing: timing, isDark: sourceLoan.isDark, tintColor: lastDropTint)
        }
        if last.circle != nil {
            add(self.companionDrop.layer, "position", frames.map { point(CGPoint(x: $0.circle?.midX ?? 0.0, y: $0.circle?.midY ?? 0.0)) })
            add(self.companionDrop.layer, "bounds", frames.map { bounds($0.circle ?? CGRect()) })
            self.companionDrop.animateShape(sizes: frames.map { $0.circle?.size ?? CGSize() }, timing: timing, isDark: sourceLoan.isDark, tintColor: self.dropTint(fill: min(max(last.tint / 0.55, 0.0), 1.0)))
        }
        add(self.glassContainer.layer, "opacity", frames.map { number($0.glass) })

        // The card, on the clock: a released swipe's card shrinks into the pill while its pose lets go.
        let cardRects = frames.map { $0.card }
        let cardRadii = frames.map { $0.cardCornerRadii }
        for mask in destinationLoan.overlayViews.isEmpty ? [self.cardMask] : [self.cardMask, self.overlayMask] {
            add(mask, "position", cardRects.map { point(CGPoint(x: $0.midX, y: $0.midY)) })
            add(mask, "bounds", cardRects.map { bounds($0) })
            if self.masksTakeCornerRadii {
                add(mask, mask.cornerRadiiKeyPath, cardRadii.map { $0.boxedValue })
            } else {
                add(mask, "cornerRadius", cardRadii.map { number($0.maximum) })
            }
        }

        // The photo.
        let rest = destinationLoan.avatarRestFrame
        let photo = frames.compactMap { self.photoTransform($0, rest: rest) }
        if photo.count == frames.count {
            add(self.photoWrapper.layer, "position", photo.map { point($0.center) })
            add(self.photoWrapper.layer, "transform", photo.map { NSValue(caTransform3D: $0.transform) })
            add(self.photoMask, "path", frames.compactMap { self.photoPath($0, rest: rest) })
        }
        if self.companionHome != nil, let companionView = sourceLoan.companionView {
            add(companionView.layer, "opacity", frames.map { number($0.companionContent) })
        }
        if let originContent = sourceLoan.originContent {
            let placements = frames.compactMap { self.originContentPlacement($0) }
            if placements.count == frames.count {
                add(originContent.layer, "position", placements.map { point($0.center) })
                add(originContent.layer, "transform", placements.map { NSValue(caTransform3D: $0.transform) })
            }
            add(originContent.layer, "opacity", frames.map { number($0.originContent) })
        }

        // The labels.
        for (index, host) in self.labelHosts.enumerated() {
            let labels = frames.map { $0.labels[index] }
            add(host.sourceHost.layer, "position", labels.map { point($0.center) })
            add(host.sourceHost.layer, "transform", labels.map { NSValue(caTransform3D: CATransform3DMakeScale($0.sourceScale, $0.sourceScale, 1.0)) })
            add(host.sourceHost.layer, "opacity", labels.map { number($0.sourceAlpha) })
            add(host.destinationHost.layer, "position", labels.map { point($0.center) })
            add(host.destinationHost.layer, "transform", labels.map { NSValue(caTransform3D: CATransform3DMakeScale($0.destinationScale, $0.destinationScale, 1.0)) })
            add(host.destinationHost.layer, "opacity", labels.map { number($0.destinationAlpha) })
            let colors = frames.map { self.color(host, ink: $0.ink).cgColor }
            add(host.sourceColorLayer, "backgroundColor", colors)
            for layer in host.multiplyLayers {
                add(layer, "contentsMultiplyColor", colors)
            }
        }
        for follower in self.followers where frames.allSatisfy({ follower.label < $0.labels.count }) {
            add(follower.layer, "transform", frames.map { NSValue(caTransform3D: self.followerTransform(follower, $0.labels[follower.label])) })
        }

        // The upper screen's own parts.
        for (index, view) in destinationLoan.appearingViews.enumerated() {
            let appear = frames.map { $0.appearing[index] }
            let companions = index < destinationLoan.appearingCompanions.count ? destinationLoan.appearingCompanions[index] : []
            for view in [view] + companions {
                heldOpacity(view.layer, appear.map { $0.alpha })
                add(view.layer, "transform", appear.map { NSValue(caTransform3D: CATransform3DScale(CATransform3DMakeTranslation(0.0, $0.offset, 0.0), $0.scale, $0.scale, 1.0)) })
            }
        }
        for flyer in self.flyers {
            add(flyer.layer, "transform", frames.map { NSValue(caTransform3D: self.flyerTransform(flyer, $0)) })
            heldOpacity(flyer.layer, frames.map { $0.flightAlpha })
        }
        for rider in self.pageRiders {
            add(rider.layer, "transform", frames.map { NSValue(caTransform3D: self.pageTransform(rider, page: $0.page)) })
            if rider.content != nil {
                add(rider.layer, "sublayerTransform", frames.compactMap { self.pageContentTransform(rider, page: $0.page).map { NSValue(caTransform3D: $0) } })
            }
        }
        for view in destinationLoan.backgroundViews {
            heldOpacity(view.layer, frames.map { $0.background })
        }
        for view in destinationLoan.listViews {
            heldOpacity(view.layer, frames.map { $0.list })
        }
        for view in destinationLoan.patternViews {
            heldOpacity(view.layer, frames.map { $0.pattern })
        }

        // The swipe's card.
        if poses.contains(where: { $0.isActive }) {
            let transforms = poses.map { NSValue(caTransform3D: CATransform3DMakeAffineTransform(self.viewTransform($0))) }
            if let topView = self.topView {
                add(topView.layer, "transform", transforms)
            }
            add(self.cardContentView.layer, "transform", transforms)
            add(self.photoHost.layer, "transform", transforms)
            add(self.glassContainer.layer, "transform", transforms)
            add(self.shadowView.layer, "transform", transforms)
            add(self.shadowView.layer, "shadowOpacity", zip(poses, timeline.times).map { number(0.3 * $0.0.fade(width: self.size.width) * ExpansionCurve.smooth(ExpansionCurve.ramp($0.1, 0.8, 1.0))) })
        }

        if self.originDrop.superview === self.underView {
            let remaining = max(0.0, NavigationExpansionRendererImpl.glassContainerWarmUp - (CACurrentMediaTime() - self.glassContainerShownAt))
            timeline.schedule(timeline.animationTime() + remaining, { [weak self] in
                self?.dropsJoinContainer()
            })
        }
        self.startTint(timeline: timeline, fills: frames.map { min(max($0.tint / 0.55, 0.0), 1.0) })
        if !timeline.isOpening || timeline.times.last.map({ $0 < 0.5 }) == true, let index = timeline.times.firstIndex(where: { $0 <= 0.05 }), index < timing.sampleTimes.count {
            let destination = self.destination
            timeline.schedule(timing.sampleTimes[index], {
                destination.expansionDidLand()
            })
        }
    }

    // MARK: The drops' tint, per frame

    private func startTint(timeline: NavigationExpansionTimeline, fills: [CGFloat]) {
        self.tintTimeline = (timeline, fills)
        self.appliedTintFill = -1.0
        self.appliedTintTime = -Double.infinity
        if self.tintLink == nil {
            self.tintLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] _ in
                self?.applyTint()
            })
        }
        self.applyTint()
    }

    func applyTint(atAnimationTime time: Double? = nil) {
        guard let (timeline, fills) = self.tintTimeline, let sourceLoan = self.sourceLoan else {
            return
        }
        // At the timeline's end the tint stays and the link goes: the renderer can outlive the transition's clock (while
        // the bars' glass lingers), and a stopped clock reads 0.
        let end = timeline.timing.sampleTimes.last ?? 0.0
        let now = min(time ?? timeline.animationTime(), end)
        // The clock only goes forward; one that went back has stopped.
        guard now >= self.appliedTintTime else {
            self.stopTint()
            return
        }
        self.appliedTintTime = now
        if now >= end {
            self.stopTint()
        }
        let fill = NavigationTransitionTimeline.interpolate(fills, times: timeline.timing.sampleTimes, at: now)
        guard abs(fill - self.appliedTintFill) > 0.001 else {
            return
        }
        self.appliedTintFill = fill
        let tint = self.dropTint(fill: fill)
        self.updateOriginDrop(size: self.originDrop.bounds.size, radii: self.originDropCornerRadii, isDark: sourceLoan.isDark, tintColor: tint)
        self.companionDrop.update(size: self.companionDrop.bounds.size, cornerRadius: self.companionDrop.bounds.width * 0.5, isDark: sourceLoan.isDark, tintColor: tint, transition: .immediate)
    }

    // MARK: End

    private func removeKeyframes() {
        for layer in self.touchedLayers {
            for key in layer.animationKeys() ?? [] where key.hasPrefix(NavigationExpansionRendererImpl.keyPrefix) {
                layer.removeAnimation(forKey: key)
            }
        }
    }

    public func end(atTop: Bool) {
        self.tintLink?.invalidate()
        self.tintLink = nil
        self.tintTimeline = nil
        self.removeKeyframes()
        for follower in self.followers {
            follower.layer.transform = follower.rest
        }
        self.followers = []
        for rider in self.pageRiders {
            rider.layer.transform = rider.rest
            if let content = rider.content {
                rider.layer.sublayerTransform = content.rest
            }
        }
        self.pageRiders = []
        for flyer in self.flyers {
            flyer.layer.transform = flyer.rest
        }
        self.flyers = []
        self.topView?.layer.mask = nil
        self.topView?.transform = .identity
        if let destinationLoan = self.destinationLoan {
            for view in destinationLoan.appearingViews + destinationLoan.appearingCompanions.flatMap({ $0 }) {
                view.layer.transform = CATransform3DIdentity
            }
            for host in self.labelHosts {
                if case let .multiply(layers, color)? = host.destination?.coloring {
                    for layer in layers {
                        layer.layerTintColor = color.cgColor
                    }
                }
            }
            if let avatarView = destinationLoan.avatarView {
                avatarView.removeFromSuperview()
            }
        }
        for host in self.labelHosts {
            // A chat label tinted through its text layer is the chat's own colour again.
            if case let .multiply(layers, color)? = host.source?.coloring {
                for layer in layers {
                    layer.layerTintColor = color.cgColor
                }
            }
        }
        for host in self.labelHosts {
            host.sourceColorLayer.removeFromSuperlayer()
            host.sourceGroup.layer.mask = nil
            host.sourceGroup.removeFromSuperview()
            host.source?.view.removeFromSuperview()
            for accessory in host.source?.accessories ?? [] {
                accessory.view.removeFromSuperview()
            }
            host.destination?.view.removeFromSuperview()
            host.sourceHost.removeFromSuperview()
            host.destinationHost.removeFromSuperview()
        }
        self.labelHosts = []
        for overlay in self.destinationLoan?.overlayViews ?? [] {
            overlay.removeFromSuperview()
        }
        self.overlayHost.layer.mask = nil
        self.overlayHost.removeFromSuperview()
        if let companionView = self.sourceLoan?.companionView, let home = self.companionHome {
            companionView.removeFromSuperview()
            companionView.transform = home.transform
            companionView.bounds = home.bounds
            companionView.center = home.center
            if let superview = home.superview {
                superview.insertSubview(companionView, at: min(home.index, superview.subviews.count))
            }
        }
        self.companionHome = nil
        self.sourceLoan?.companionView?.alpha = 1.0
        self.sourceLoan?.originContent?.removeFromSuperview()
        self.originContentHome = nil
        if self.sourceLoan != nil {
            self.source.returnExpansionSource()
        }
        if self.destinationLoan != nil {
            self.destination.returnExpansionDestination()
        }
        self.sourceLoan = nil
        self.destinationLoan = nil
        self.photoWrapper.removeFromSuperview()
        self.photoHost.removeFromSuperview()
        self.photoHost.transform = .identity
        self.glassContainer.transform = .identity
        self.cardContentView.removeFromSuperview()
        self.originDrop.removeFromSuperview()
        self.companionDrop.removeFromSuperview()
        self.glassContainer.removeFromSuperview()
        self.shadowView.removeFromSuperview()
    }

    // Tests.
    var labelHostCentersForTesting: [CGPoint] {
        return self.labelHosts.map { $0.sourceHost.layer.position }
    }
    var destinationLabelHostsForTesting: [UIView] {
        return self.labelHosts.map { $0.destinationHost }
    }
    var destinationLabelAlphasForTesting: [CGFloat] {
        return self.labelHosts.map { $0.destinationHost.alpha }
    }
    var appliedTintFillForTesting: CGFloat {
        return self.appliedTintFill
    }
    var photoIsBelowLabelsForTesting: Bool {
        guard self.photoWrapper.superview === self.photoHost, let photo = self.view.subviews.firstIndex(of: self.photoHost) else {
            return false
        }
        return self.labelHosts.allSatisfy { host in
            let source = self.view.subviews.firstIndex(of: host.sourceHost) ?? -1
            let destination = self.view.subviews.firstIndex(where: { $0 === host.destinationHost || host.destinationHost.isDescendant(of: $0) }) ?? -1
            return source > photo && destination > photo
        }
    }
    var photoIsBelowOverlaysForTesting: Bool {
        guard self.photoWrapper.superview === self.photoHost, let photo = self.view.subviews.firstIndex(of: self.photoHost), let content = self.view.subviews.firstIndex(of: self.cardContentView) else {
            return false
        }
        return photo < content && self.overlayHost.superview === self.cardContentView
    }
    /// The photo's mask's path, in the coordinates of the layer it masks.
    var photoMaskForTesting: (wrapper: CALayer, path: CGPath?) {
        return (self.photoWrapper.layer, self.photoMask.path)
    }
    var overlayMaskFrameForTesting: CGRect {
        return self.overlayMask.frame
    }
    /// The merge spacing of the drops' container on screen (nan without one).
    var glassContainerSpacingForTesting: CGFloat {
        return (self.underView.subviews.first(where: { $0 is GlassBackgroundContainerView }) as? GlassBackgroundContainerView)?.spacing ?? .nan
    }
    var dropsInContainerForTesting: Bool {
        return self.originDrop.superview === self.glassContainer.contentView
    }
    var dropLayersForTesting: (origin: CALayer, companion: CALayer) {
        return (self.originDrop.layer, self.companionDrop.layer)
    }
}

private func glassCornerRadii(_ radii: CornerRadii) -> GlassBackgroundView.CornerRadii {
    return GlassBackgroundView.CornerRadii(topLeft: radii.topLeft, topRight: radii.topRight, bottomLeft: radii.bottomLeft, bottomRight: radii.bottomRight)
}

/// A rectangle with its own radius at each corner, across and down (elliptical corners), drawn with the same elements
/// whatever the radii (one cubic per corner, zero-radius ones included), so Core Animation can interpolate between two of
/// them.
func navigationExpansionRoundedPath(rect: CGRect, topLeft: CGSize, topRight: CGSize, bottomLeft: CGSize, bottomRight: CGSize) -> CGPath {
    func clamped(_ radius: CGSize) -> CGSize {
        return CGSize(width: min(max(radius.width, 0.0), rect.width * 0.5), height: min(max(radius.height, 0.0), rect.height * 0.5))
    }
    let tl = clamped(topLeft)
    let tr = clamped(topRight)
    let bl = clamped(bottomLeft)
    let br = clamped(bottomRight)
    // A quarter ellipse's control points lie this far along its tangents (a cubic's quarter circle).
    let k: CGFloat = 0.5522847498
    let path = CGMutablePath()
    path.move(to: CGPoint(x: rect.minX + tl.width, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX - tr.width, y: rect.minY))
    path.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY + tr.height), control1: CGPoint(x: rect.maxX - tr.width * (1.0 - k), y: rect.minY), control2: CGPoint(x: rect.maxX, y: rect.minY + tr.height * (1.0 - k)))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br.height))
    path.addCurve(to: CGPoint(x: rect.maxX - br.width, y: rect.maxY), control1: CGPoint(x: rect.maxX, y: rect.maxY - br.height * (1.0 - k)), control2: CGPoint(x: rect.maxX - br.width * (1.0 - k), y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX + bl.width, y: rect.maxY))
    path.addCurve(to: CGPoint(x: rect.minX, y: rect.maxY - bl.height), control1: CGPoint(x: rect.minX + bl.width * (1.0 - k), y: rect.maxY), control2: CGPoint(x: rect.minX, y: rect.maxY - bl.height * (1.0 - k)))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl.height))
    path.addCurve(to: CGPoint(x: rect.minX + tl.width, y: rect.minY), control1: CGPoint(x: rect.minX, y: rect.minY + tl.height * (1.0 - k)), control2: CGPoint(x: rect.minX + tl.width * (1.0 - k), y: rect.minY))
    path.closeSubpath()
    return path
}
