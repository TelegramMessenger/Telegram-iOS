import Foundation
import CoreGraphics
import MediaEditor

public let mediaCropDialTickSpacing: CGFloat = 9.0
public let mediaCropDialDegreesPerTick: CGFloat = 2.25
public let mediaCropDialMajorTickInterval: Int = 10
public let mediaCropDialPointsPerDegree: CGFloat = mediaCropDialTickSpacing / mediaCropDialDegreesPerTick
public let mediaCropDialZeroSnapDegrees: CGFloat = 1.0

public let mediaCropRotationDialHeight: CGFloat = 28.0

public let mediaCropCornerHandleLength: CGFloat = 20.0
public let mediaCropMidEdgeHandleLength: CGFloat = 25.0
public let mediaCropHandleThickness: CGFloat = 3.0

public let mediaCropMirrorDuration: Double = 0.5
private let mediaCropMirrorAngularFrequency: Double = 20.0

public struct MediaCropDialTick: Equatable {
    public let degrees: CGFloat
    public let position: CGFloat
    public let isMajor: Bool

    public init(degrees: CGFloat, position: CGFloat, isMajor: Bool) {
        self.degrees = degrees
        self.position = position
        self.isMajor = isMajor
    }
}

public func mediaCropDialTicks() -> [MediaCropDialTick] {
    let count = Int((mediaCropMaximumWheelAngle / mediaCropDialDegreesPerTick).rounded())
    return (-count ... count).map { index in
        MediaCropDialTick(
            degrees: CGFloat(index) * mediaCropDialDegreesPerTick,
            position: CGFloat(index) * mediaCropDialTickSpacing,
            isMajor: index % mediaCropDialMajorTickInterval == 0
        )
    }
}

public func mediaCropDialDegrees(dialDegrees: CGFloat, limit: CGFloat) -> CGFloat {
    return dialDegrees * limit / mediaCropMaximumWheelAngle
}

public func mediaCropDialDegrees(value: CGFloat, limit: CGFloat) -> CGFloat {
    guard limit > 0.0 else {
        return 0.0
    }
    return value * mediaCropMaximumWheelAngle / limit
}

public func mediaCropDialRulerOffset(degrees: CGFloat) -> CGFloat {
    return -degrees * mediaCropDialPointsPerDegree
}

public func mediaCropDialDraggedDegrees(rawDegrees: CGFloat, translation: CGFloat) -> CGFloat {
    return rawDegrees - translation / mediaCropDialPointsPerDegree
}

public func mediaCropDialValue(rawDegrees: CGFloat) -> CGFloat {
    return mediaCropDialSnappedDegrees(min(mediaCropMaximumWheelAngle, max(-mediaCropMaximumWheelAngle, rawDegrees)))
}

public func mediaCropDialRubberBand(offset: CGFloat, dimension: CGFloat) -> CGFloat {
    guard dimension > 0.0 else {
        return 0.0
    }
    let magnitude = (1.0 - 1.0 / (abs(offset) * 0.55 / dimension + 1.0)) * dimension
    return offset < 0.0 ? -magnitude : magnitude
}

public func mediaCropDialVisualDegrees(rawDegrees: CGFloat, dimension: CGFloat) -> CGFloat {
    let limit = mediaCropMaximumWheelAngle
    if rawDegrees > limit {
        return limit + mediaCropDialRubberBand(offset: (rawDegrees - limit) * mediaCropDialPointsPerDegree, dimension: dimension) / mediaCropDialPointsPerDegree
    }
    if rawDegrees < -limit {
        return -limit + mediaCropDialRubberBand(offset: (rawDegrees + limit) * mediaCropDialPointsPerDegree, dimension: dimension) / mediaCropDialPointsPerDegree
    }
    return mediaCropDialSnappedDegrees(rawDegrees)
}

public func mediaCropDialSelectedTickIndex(visualDegrees: CGFloat) -> Int {
    let count = Int((mediaCropMaximumWheelAngle / mediaCropDialDegreesPerTick).rounded())
    let index = Int(floor(visualDegrees / mediaCropDialDegreesPerTick + 0.000001))
    return min(count, max(-count, index))
}

public func mediaCropDialMarkerOffset(visualDegrees: CGFloat) -> CGFloat {
    let index = mediaCropDialSelectedTickIndex(visualDegrees: visualDegrees)
    return (CGFloat(index) * mediaCropDialDegreesPerTick - visualDegrees) * mediaCropDialPointsPerDegree
}

public let mediaCropDialTickExcitationDuration: Double = 0.22

public func mediaCropDialTickExcitation(elapsed: Double) -> CGFloat {
    if elapsed <= 0.0 {
        return 1.0
    }
    if elapsed >= mediaCropDialTickExcitationDuration {
        return 0.0
    }
    let x = elapsed / mediaCropDialTickExcitationDuration
    return CGFloat(1.0 - x * x * (3.0 - 2.0 * x))
}

public struct MediaCropDialTickAppearance: Equatable {
    public let height: CGFloat
    public let alpha: CGFloat

    public init(height: CGFloat, alpha: CGFloat) {
        self.height = height
        self.alpha = alpha
    }
}

public func mediaCropDialTickAppearance(excitation: CGFloat, isMajor: Bool) -> MediaCropDialTickAppearance {
    let restAlpha: CGFloat = isMajor ? 0.75 : 0.4
    let e = min(1.0, max(0.0, excitation))
    return MediaCropDialTickAppearance(height: 14.0 + 14.0 * e, alpha: restAlpha + (1.0 - restAlpha) * e)
}

public func mediaCropDialPassedTickIndices(from previous: Int, to current: Int) -> [Int] {
    if previous < current {
        return Array(previous ..< current)
    }
    if previous > current {
        return Array(stride(from: previous, to: current, by: -1))
    }
    return []
}

private let mediaCropDialDecelerationRate: Double = 0.99
private let mediaCropDialInertiaRestDistance: CGFloat = 0.25

public func mediaCropDialInertiaDistance(velocity: CGFloat) -> CGFloat {
    return velocity / 1000.0 * CGFloat(mediaCropDialDecelerationRate / (1.0 - mediaCropDialDecelerationRate))
}

public func mediaCropDialInertiaFraction(time: Double) -> CGFloat {
    if time <= 0.0 {
        return 0.0
    }
    return CGFloat(1.0 - pow(mediaCropDialDecelerationRate, time * 1000.0))
}

public func mediaCropDialInertiaDuration(distance: CGFloat) -> Double {
    if abs(distance) <= mediaCropDialInertiaRestDistance {
        return 0.0
    }
    return log(Double(mediaCropDialInertiaRestDistance / abs(distance))) / log(mediaCropDialDecelerationRate) / 1000.0
}

public func mediaCropDialSnappedDegrees(_ degrees: CGFloat) -> CGFloat {
    if abs(degrees) < mediaCropDialZeroSnapDegrees {
        return 0.0
    }
    return degrees
}

public func mediaCropDialDetentReached(from previous: CGFloat, to current: CGFloat) -> Bool {
    if current == 0.0 && previous != 0.0 {
        return true
    }
    if abs(current) >= mediaCropMaximumWheelAngle && abs(previous) < mediaCropMaximumWheelAngle {
        return true
    }
    return false
}

public func mediaCropDialShowsZeroDot(visualDegrees: CGFloat) -> Bool {
    return abs(visualDegrees) > CGFloat(Float.ulpOfOne)
}

public func mediaCropDialPlaysTickHaptic(previousIndex: Int, currentIndex: Int, detentReached: Bool) -> Bool {
    return previousIndex != currentIndex && !detentReached
}

public func mediaCropShowsMidEdgeHandle(sideLength: CGFloat) -> Bool {
    return sideLength >= 2.0 * (mediaCropCornerHandleLength + mediaCropHandleThickness) + mediaCropMidEdgeHandleLength
}

public func mediaCropMirrored(_ state: MediaCropState) -> MediaCropState {
    var result = state
    result.mirrored = !state.mirrored
    result.rotation = -state.rotation
    result.perspective.horizontal = -state.perspective.horizontal
    switch state.orientation {
    case .left:
        result.orientation = .right
    case .right:
        result.orientation = .left
    case .up, .down:
        result.orientation = state.orientation
    }
    let rotatedSize = mediaCropRotatedContentSize(state.originalSize, rotation: state.rotation)
    result.cropRect.origin.x = rotatedSize.width - state.cropRect.maxX
    return result
}

public func mediaCropMirrorFlipProgress(time: Double) -> CGFloat {
    if time <= 0.0 {
        return 0.0
    }
    if time >= mediaCropMirrorDuration {
        return 1.0
    }
    let x = mediaCropMirrorAngularFrequency * time
    return CGFloat(1.0 - (1.0 + x) * exp(-x))
}
