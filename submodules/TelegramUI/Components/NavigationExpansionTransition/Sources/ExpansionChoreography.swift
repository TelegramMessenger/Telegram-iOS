import Foundation
import UIKit
import Display

/// A press still lifting the origin or the companion when the transition starts: 0…1 with the release spring's
/// overshoot (the prototype's `pill`/`avatar` channels).
public struct ExpansionPress: Equatable {
    public var origin: CGFloat
    public var companion: CGFloat

    public static let none = ExpansionPress(origin: 0.0, companion: 0.0)

    public init(origin: CGFloat, companion: CGFloat) {
        self.origin = origin
        self.companion = companion
    }
}

extension CornerRadii {
    /// The roundest of the four.
    var maximum: CGFloat {
        return max(max(self.topLeft, self.topRight), max(self.bottomLeft, self.bottomRight))
    }
}

/// One label at one moment: where its two layouts stand (one centre), how each is scaled to the common width, and how
/// visible each is.
public struct ExpansionLabelFrame: Equatable {
    public var center: CGPoint
    public var sourceScale: CGFloat
    public var destinationScale: CGFloat
    public var sourceAlpha: CGFloat
    public var destinationAlpha: CGFloat

    public init(center: CGPoint, sourceScale: CGFloat, destinationScale: CGFloat, sourceAlpha: CGFloat, destinationAlpha: CGFloat) {
        self.center = center
        self.sourceScale = sourceScale
        self.destinationScale = destinationScale
        self.sourceAlpha = sourceAlpha
        self.destinationAlpha = destinationAlpha
    }
}

/// One appearing item at one moment: alpha, scale and how far below its resting place it still is.
public struct ExpansionAppearFrame: Equatable {
    public var alpha: CGFloat
    public var scale: CGFloat
    public var offset: CGFloat

    public init(alpha: CGFloat, scale: CGFloat, offset: CGFloat) {
        self.alpha = alpha
        self.scale = scale
        self.offset = offset
    }
}

/// Everything an expansion draws at one moment, in screen coordinates (`Stage`, ProfileMorph.swift:1193).
public struct ExpansionFrame: Equatable {
    /// The origin's glass growing into the card that shows the upper screen.
    public var card: CGRect
    /// The card's corners: the pill's capsule turning into the screen's corners.
    public var cardCornerRadii: CornerRadii
    /// The companion's glass ring; nil without a companion.
    public var circle: CGRect?
    /// The upper screen's avatar (or photo) view's frame; nil without a companion.
    public var photo: CGRect?
    /// The photo's corners: the circle's, square at the bottom once it is expanded, the top ones keeping the screen's.
    public var photoCornerRadii: CornerRadii
    public var labels: [ExpansionLabelFrame]
    /// The upper screen's background seen through the card (`paint`).
    public var background: CGFloat
    /// The labels' and bar glyphs' colour, 0 the lower screen's, 1 the upper's (`ink`).
    public var ink: CGFloat
    /// The upper bar's own items (`more`).
    public var more: CGFloat
    /// The drops' glass (`glass`).
    public var glass: CGFloat
    /// The drops' tint toward the upper screen's colour.
    public var tint: CGFloat
    public var appearing: [ExpansionAppearFrame]
    /// The upper screen's content below its header (`infoAppear`).
    public var list: CGFloat
    /// How far below its resting place the page under the header (its buttons and list) stands: as far as the status
    /// stands from its own, so the page rides the status in, its spring's overshoot included, as the prototype's actions
    /// and info card hang off `seenY` (ProfileMorph.swift:964-971, 1506). Without the press's lift and the close's
    /// landing, which only the labels take there too.
    public var page: CGFloat
    /// The upper screen's background pattern (`giftsShown`).
    public var pattern: CGFloat
    /// The card covers the screen: its mask can go (`flooded`).
    public var flooded: CGFloat
    /// The press's light still on the origin's and the companion's glass (`light`).
    public var originLight: CGFloat
    public var companionLight: CGFloat
    /// The companion's own photo (the chat's live avatar) in the flying circle, above the upper screen's: 1 at the lower
    /// screen's end of the clock, gone from 0.3, so the two avatars cross-fade instead of one replacing the other.
    public var companionContent: CGFloat
    public var originContent: CGFloat
    public var flight: CGFloat
    public var flightAlpha: CGFloat
}

/// The prototype's scene as a function: one geometry, one path, one clock value → one frame.
public struct ExpansionChoreography {
    /// A pressed glass button's lift across its width (measured: pill 128 → ×1.125, circle 44 → ×1.36).
    public static let liftPoints: CGFloat = 16.0
    /// How far the card rises per unit of the close's overshoot past 0.
    public static let swing: CGFloat = 140.0
    /// Without a companion, how far above the title's text the avatar starts, as a point.
    public static let titleRiseGap: CGFloat = 4.0
    /// A pressed glass's light and the content's wash under it.
    public static let glassLight: CGFloat = 0.1
    public static let originWash: CGFloat = 0.3
    public static let companionWash: CGFloat = 0.55

    public let geometry: ExpansionGeometry
    public let path: ExpansionPath
    /// The open spring's duration: seconds per unit of the clock for the impact's oscillation.
    public let duration: CGFloat

    /// The clock value at which the circle comes within 6 pt of the pill on opening (`Impact`, ProfileMorph.swift:1738);
    /// nil on the photo path or without a companion.
    public let impactMoment: CGFloat?

    public init(geometry: ExpansionGeometry, path: ExpansionPath, duration: CGFloat) {
        self.geometry = geometry
        self.path = path
        self.duration = duration
        var moment: CGFloat?
        if path == .origin, geometry.companion != nil, geometry.avatar != nil {
            let probe = ExpansionChoreography(geometry: geometry, path: path, duration: duration, impactMoment: nil)
            for i in 0 ... 600 {
                let time = CGFloat(i) / 600.0
                let frame = probe.frame(ExpansionClock(time: time, isOpening: true), press: .none, wobble: 0.0)
                if let circle = frame.circle, circle.minX - frame.card.maxX <= 6.0 {
                    // Only a circle beside the pill hits it. One below it (iPhone Duo's side column) comes within 6 pt
                    // across while it is still far away, and the card then grows over it: no knock.
                    if circle.maxY > frame.card.minY && circle.minY < frame.card.maxY {
                        moment = time
                    }
                    break
                }
            }
        }
        self.impactMoment = moment
    }

    private init(geometry: ExpansionGeometry, path: ExpansionPath, duration: CGFloat, impactMoment: CGFloat?) {
        self.geometry = geometry
        self.path = path
        self.duration = duration
        self.impactMoment = impactMoment
    }

    /// The pill's knock from the circle: a damped oscillation in points, opening only (the circle hits from the right,
    /// so it is knocked left).
    func wobble(_ clock: ExpansionClock) -> CGFloat {
        guard clock.isOpening, let moment = self.impactMoment else {
            return 0.0
        }
        let tau = (clock.time - moment) * self.duration
        guard tau > 0.0 else {
            return 0.0
        }
        return -7.0 * exp(-7.0 * tau) * sin(26.0 * tau)
    }

    /// The card's and the labels' landing scale per unit of overshoot past 0, the circle's growth ratio.
    var landing: CGFloat {
        guard let avatar = self.geometry.avatar, self.geometry.companionPhotoDiameter > 0.0 else {
            return 0.0
        }
        return (avatar.width - self.geometry.companionPhotoDiameter) / self.geometry.companionPhotoDiameter
    }

    var originLift: CGFloat {
        return ExpansionChoreography.liftPoints / max(1.0, self.geometry.origin.width)
    }

    var companionLift: CGFloat {
        return ExpansionChoreography.liftPoints / max(1.0, self.geometry.companion?.width ?? 44.0)
    }

    public func frame(_ clock: ExpansionClock, press: ExpansionPress = .none) -> ExpansionFrame {
        return self.frame(clock, press: press, wobble: self.wobble(clock))
    }

    func frame(_ clock: ExpansionClock, press: ExpansionPress, wobble: CGFloat) -> ExpansionFrame {
        let g = self.geometry
        let t = min(max(clock.time, -0.06), 1.06)
        let fill = max(t, 0.0)
        let fillC = min(fill, 1.0)
        let bounce = 1.0 + self.landing * min(t, 0.0)
        let rise = ExpansionChoreography.swing * min(t, 0.0)
        let q = 1.0 - t
        let slide = 1.0 - q * q
        let lift = pow(fill, 2.4)

        // The card: sides and top lead, the bottom follows; knocked by the circle, lifted by a press, landing past 0.
        let start = g.origin
        let end = CGRect(origin: CGPoint(), size: g.screenSize)
        let edge = ExpansionCurve.lead(fill)
        let minX = ExpansionCurve.mix(start.minX, end.minX, edge)
        let maxX = ExpansionCurve.mix(start.maxX, end.maxX, edge)
        let minY = ExpansionCurve.mix(start.minY, end.minY, edge)
        let maxY = ExpansionCurve.mix(start.maxY, end.maxY, fill)
        var card = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        let hit = wobble * (1.0 - fillC * 0.7)
        card = card.offsetBy(dx: hit, dy: 0.0).insetBy(dx: abs(hit) * 0.35, dy: -abs(hit) * 0.3)
        let lifted = self.originLift * press.origin * (1.0 - fillC) - (1.0 - bounce)
        card = card.insetBy(dx: -card.width * lifted * 0.5, dy: -card.height * lifted * 0.5).offsetBy(dx: 0.0, dy: rise)
        // Each corner turns from the capsule into its screen corner as the card fills the screen. The screen's corners can
        // differ (iPhone Duo's cover screen: 8 pt on the hinge side, 59 pt outside), so each starts from the roundest of
        // them: the card starts as the pill whatever the screen.
        let capsule = min(card.width, card.height) * 0.5
        let roundest = g.screenCornerRadii.maximum
        let cardCornerRadii = g.screenCornerRadii.mapRadii { min(capsule, ExpansionCurve.mix(roundest, $0, fillC)) }

        // The circle: along the arc, from the companion's photo to the avatar.
        var circle: CGRect?
        var photo: CGRect?
        if let companion = g.companion, let avatar = g.avatar {
            let size = ExpansionCurve.mix(g.companionPhotoDiameter, avatar.width, t)
            let center = CGPoint(x: ExpansionCurve.mix(companion.midX, avatar.midX, slide), y: ExpansionCurve.mix(companion.midY, avatar.midY, lift))
            let photoRect = CGRect(x: center.x - size * 0.5, y: center.y - size * 0.5, width: size, height: size)
            let ringSize = size + 2.0 * g.companionRing * (1.0 - fillC)
            var ringRect = CGRect(x: center.x - ringSize * 0.5, y: center.y - ringSize * 0.5, width: ringSize, height: ringSize)
            let ringLift = self.companionLift * press.companion * (1.0 - fillC)
            ringRect = ringRect.insetBy(dx: -ringRect.width * ringLift * 0.5, dy: -ringRect.height * ringLift * 0.5)
            circle = ringRect
            let photoLift = self.companionLift * press.companion
            photo = photoRect.insetBy(dx: -photoRect.width * photoLift * 0.5, dy: -photoRect.height * photoLift * 0.5)
        }

        // The photo path: everything follows the photo, which grows from the flying circle into the expanded photo by a
        // geometric pace behind a gate (`expand`, `photoGrowth`, ProfileMorph.swift:1263, 1552). The labels follow its
        // growth, so it is known before them; the photo itself grows below, once the circle is known.
        var photoGrowth: CGFloat = 0.0
        var expandC: CGFloat = 0.0
        let growsIntoPhoto = self.path == .photo && g.photo != nil && g.avatar != nil
        if growsIntoPhoto {
            let gate = clock.isOpening ? max(0.0, (clock.time - 0.05) / 0.95) : min(max(clock.time, 0.0), 1.0)
            let expand = gate
            expandC = min(max(expand, 0.0), 1.0)
            photoGrowth = ExpansionCurve.geometric(min(max(expand, 0.0), 1.2), ratio: 6.0) + min(expand, 0.0) * 0.8
        }

        // The labels ride the card's edge (the anchor, the last label, is carried; the others keep their offset from it,
        // mixing between the two layouts' offsets), sway with the knock, and are lifted and landed with the card.
        let text = fill
        let sway = wobble * (1.0 - fillC)
        let carriedEdge = ExpansionCurve.mix(start.maxY, g.carriedEdge, fill) + abs(hit) * 0.3
        var labelFrames: [ExpansionLabelFrame] = []
        var page: CGFloat = 0.0
        if let anchor = g.labels.last {
            let anchorGap = ExpansionCurve.mix(start.maxY - anchor.sourceCenter.y, g.carriedEdge - anchor.destinationCenter.y, fillC)
            let anchorY = carriedEdge - anchorGap
            let pivot = CGPoint(x: card.midX, y: card.midY)
            let held = 1.0 - fillC
            let squeeze = 1.0 + self.originLift * press.origin * held
            let groupScale = squeeze * bounce
            // The photo path: the labels head straight for their places under the photo, by its growth.
            let isPhoto = self.path == .photo
            let sizeT = isPhoto ? photoGrowth : text
            let (sourceAlpha, destinationAlpha) = ExpansionCurve.crossfade(sizeT)
            for label in g.labels {
                let destinationCenter = isPhoto ? (label.photoCenter ?? label.destinationCenter) : label.destinationCenter
                let destinationSize = isPhoto ? (label.photoSize ?? label.destinationSize) : label.destinationSize
                let x: CGFloat
                let y: CGFloat
                if isPhoto {
                    x = ExpansionCurve.mix(label.sourceCenter.x, destinationCenter.x, photoGrowth)
                    y = ExpansionCurve.mix(label.sourceCenter.y, destinationCenter.y, photoGrowth)
                } else if label == anchor {
                    x = ExpansionCurve.mix(label.sourceCenter.x, destinationCenter.x, text) + sway
                    y = anchorY
                } else {
                    x = ExpansionCurve.mix(label.sourceCenter.x, destinationCenter.x, text) + sway
                    y = anchorY - ExpansionCurve.mix(anchor.sourceCenter.y - label.sourceCenter.y, anchor.destinationCenter.y - label.destinationCenter.y, text)
                }
                if label == anchor {
                    page = y - destinationCenter.y
                }
                let width = ExpansionCurve.mix(label.sourceSize.width, destinationSize.width, sizeT)
                var center = CGPoint(x: pivot.x + (x - pivot.x) * groupScale, y: pivot.y + (y - pivot.y) * groupScale)
                center.y += rise
                let wash = 1.0 - ExpansionChoreography.originWash * min(max(press.origin, 0.0), 1.0) * (1.0 - fillC)
                labelFrames.append(ExpansionLabelFrame(
                    center: center,
                    sourceScale: width / max(1.0, label.sourceSize.width) * groupScale,
                    destinationScale: width / max(1.0, destinationSize.width) * groupScale,
                    sourceAlpha: sourceAlpha * wash,
                    destinationAlpha: destinationAlpha * wash
                ))
            }
        }

        // Without a companion (a forum's bar has its menu button where a chat has its avatar) there is no circle to fly
        // from: the avatar rises from a point just above the title and rides it, growing and leaving it to stand where
        // it rests above it, the title's spring (and its overshoot) included.
        if photo == nil, let avatar = g.avatar, let title = g.labels.first, let titleFrame = labelFrames.first {
            let titleRest = self.path == .photo ? (title.photoCenter ?? title.destinationCenter) : title.destinationCenter
            let restOffset = CGPoint(x: avatar.midX - titleRest.x, y: avatar.midY - titleRest.y)
            let start = CGPoint(x: 0.0, y: -(title.sourceSize.height * 0.5 + ExpansionChoreography.titleRiseGap))
            let offset = ExpansionCurve.mix(start, restOffset, text)
            let size = max(0.01, avatar.width * text)
            photo = CGRect(x: titleFrame.center.x + offset.x - size * 0.5, y: titleFrame.center.y + offset.y - size * 0.5, width: size, height: size)
        }
        if growsIntoPhoto, let target = g.photo, let flying = photo {
            let grown = ExpansionCurve.mix(flying, target, photoGrowth)
            photo = grown
            if let ring = circle {
                circle = ExpansionCurve.mix(ring, grown, expandC)
            }
        }
        // The avatar's own corners (a circle's, or a forum's rounded square's), scaled with it as it flies.
        let photoHalf = (photo?.width ?? 0.0) * 0.5
        let photoCorner = (photo?.width ?? 0.0) * min(0.5, max(0.0, g.avatarCornerFraction))
        let photoRadius = photoCorner * (1.0 - expandC)
        let photoCornerRadii = CornerRadii(
            topLeft: ExpansionCurve.mix(photoCorner, min(photoHalf, g.screenCornerRadii.topLeft), expandC),
            topRight: ExpansionCurve.mix(photoCorner, min(photoHalf, g.screenCornerRadii.topRight), expandC),
            bottomLeft: photoRadius,
            bottomRight: photoRadius
        )

        let appearing = g.appearing.indices.map { i -> ExpansionAppearFrame in
            let delay = CGFloat(i) * 0.04
            let a: CGFloat
            if clock.isOpening {
                a = ExpansionCurve.smooth(ExpansionCurve.ramp(clock.time, 0.5 + delay, min(0.92 + delay, 1.0)))
            } else {
                a = 1.0 - ExpansionCurve.smooth(ExpansionCurve.ramp(1.0 - clock.time, 0.0, 0.3))
            }
            return ExpansionAppearFrame(alpha: a, scale: ExpansionCurve.mix(0.7, 1.0, a), offset: 14.0 * (1.0 - a))
        }
        let list: CGFloat
        if clock.isOpening {
            list = ExpansionCurve.smooth(ExpansionCurve.ramp(clock.time, 0.45, 0.9))
        } else {
            list = 1.0 - ExpansionCurve.smooth(ExpansionCurve.ramp(1.0 - clock.time, 0.0, 0.25))
        }

        return ExpansionFrame(
            card: card,
            cardCornerRadii: cardCornerRadii,
            circle: circle,
            photo: photo,
            photoCornerRadii: photoCornerRadii,
            labels: labelFrames,
            background: clock.phase((g.backgroundOpening.lowerBound, g.backgroundOpening.upperBound), (g.backgroundClosing.lowerBound, g.backgroundClosing.upperBound)),
            ink: clock.phase((0.10, 0.45), (0.30, 0.80)),
            more: clock.phase((0.25, 0.60), (0.00, 0.14)),
            glass: 1.0 - ExpansionCurve.smooth(ExpansionCurve.ramp(fill, 0.75, 0.97)),
            tint: 0.55 * fillC,
            appearing: appearing,
            list: list,
            page: page,
            pattern: ExpansionCurve.smooth(ExpansionCurve.ramp(clock.time, 0.6, 1.0)),
            flooded: clock.phase((0.96, 1.00), (0.00, 0.03)),
            originLight: min(max(press.origin, 0.0), 1.0) * (1.0 - fillC),
            companionLight: min(max(press.companion, 0.0), 1.0) * (1.0 - fillC),
            companionContent: 1.0 - ExpansionCurve.smooth(ExpansionCurve.ramp(fill, 0.0, 0.3)),
            originContent: 1.0 - ExpansionCurve.smooth(ExpansionCurve.ramp(fill, 0.0, 0.3)),
            flight: edge,
            flightAlpha: clock.phase((0.05, 0.6), (0.1, 0.6))
        )
    }
}
