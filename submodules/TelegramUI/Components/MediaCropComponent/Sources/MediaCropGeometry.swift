import Foundation
import CoreGraphics
import MediaEditor

public let mediaCropMinimumFrameSide: CGFloat = 44.0

private let mediaCropMaximumZoomScale: CGFloat = 10.0
private let mediaCropContainerInset: CGFloat = 9.0
private let mediaCropFloatEpsilon: CGFloat = CGFloat(Float.ulpOfOne)

public struct MediaCropState: Equatable {
    public var originalSize: CGSize
    public var cropRect: CGRect
    public var rotation: CGFloat
    public var orientation: MediaCropOrientation
    public var mirrored: Bool
    public var lockedAspectRatio: CGFloat?
    public var perspective: MediaEditorCropPerspective

    public init(originalSize: CGSize) {
        self.originalSize = originalSize
        self.cropRect = CGRect(origin: .zero, size: originalSize)
        self.rotation = 0.0
        self.orientation = .up
        self.mirrored = false
        self.lockedAspectRatio = nil
        self.perspective = .zero
    }

    public var isDefault: Bool {
        if !mediaCropRectsEqual(self.cropRect, CGRect(origin: .zero, size: self.originalSize), epsilon: 1.0) {
            return false
        }
        if self.orientation != .up {
            return false
        }
        if abs(self.rotation) > mediaCropFloatEpsilon {
            return false
        }
        if self.mirrored {
            return false
        }
        if !self.perspective.isZero {
            return false
        }
        return true
    }

    fileprivate var effectiveLockedAspectRatio: CGFloat? {
        if let lockedAspectRatio = self.lockedAspectRatio, lockedAspectRatio > mediaCropFloatEpsilon {
            return lockedAspectRatio
        }
        return nil
    }
}

public func mediaCropRectsEqual(_ lhs: CGRect, _ rhs: CGRect, epsilon: CGFloat) -> Bool {
    let epsilon = abs(epsilon)
    return abs(lhs.origin.x - rhs.origin.x) < epsilon
        && abs(lhs.origin.y - rhs.origin.y) < epsilon
        && abs(lhs.size.width - rhs.size.width) < epsilon * 2.0
        && abs(lhs.size.height - rhs.size.height) < epsilon * 2.0
}

public enum MediaCropAspectPreset: Equatable {
    case original
    case square
    case ratio(Int, Int)
}

public let mediaCropAspectPresets: [MediaCropAspectPreset] = [
    .original,
    .square,
    .ratio(3, 2),
    .ratio(5, 3),
    .ratio(4, 3),
    .ratio(5, 4),
    .ratio(7, 5),
    .ratio(16, 9)
]

public enum MediaCropHandle {
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
    case left
}

public func mediaCropRotatedContentSize(_ size: CGSize, rotation: CGFloat) -> CGSize {
    var transform = CGAffineTransform(translationX: size.width / 2.0, y: size.height / 2.0)
    transform = transform.rotated(by: rotation)
    transform = transform.translatedBy(x: -size.width / 2.0, y: -size.height / 2.0)
    return CGRect(origin: .zero, size: size).applying(transform).size
}

public func mediaCropDisplayedSize(_ state: MediaCropState) -> CGSize {
    let size = state.cropRect.size
    if state.orientation.isSideward {
        return CGSize(width: size.height, height: size.width)
    }
    return size
}

private func mediaCropOrientedComponents(_ first: Int, _ second: Int, displayedSize: CGSize) -> (width: Int, height: Int) {
    if displayedSize.width >= displayedSize.height {
        return (first, second)
    } else {
        return (second, first)
    }
}

public func mediaCropPresetTitle(_ preset: MediaCropAspectPreset, displayedSize: CGSize, strings: (original: String, square: String)) -> String {
    switch preset {
    case .original:
        return strings.original
    case .square:
        return strings.square
    case let .ratio(first, second):
        let components = mediaCropOrientedComponents(first, second, displayedSize: displayedSize)
        return "\(components.width):\(components.height)"
    }
}

public func mediaCropLockedRatio(for preset: MediaCropAspectPreset, state: MediaCropState) -> CGFloat {
    let ratio: CGFloat
    switch preset {
    case .original:
        return state.originalSize.height / state.originalSize.width
    case .square:
        ratio = 1.0
    case let .ratio(first, second):
        let components = mediaCropOrientedComponents(first, second, displayedSize: mediaCropDisplayedSize(state))
        ratio = CGFloat(components.height) / CGFloat(components.width)
    }
    if state.orientation.isSideward {
        return 1.0 / ratio
    }
    return ratio
}

private func mediaCropAvailableRect(_ state: MediaCropState) -> CGRect {
    if abs(state.rotation) < mediaCropFloatEpsilon && state.perspective.isZero {
        return CGRect(origin: .zero, size: state.originalSize)
    } else {
        return state.cropRect
    }
}

public func mediaCropApplyingLockedRatio(_ ratio: CGFloat, to state: MediaCropState) -> MediaCropState {
    var result = state
    result.lockedAspectRatio = ratio

    let currentCenter = CGPoint(x: state.cropRect.midX, y: state.cropRect.midY)
    let availableRect = mediaCropAvailableRect(state)
    var rect = state.cropRect
    rect.size.height = rect.size.width * ratio

    if rect.size.height > availableRect.size.height {
        rect.size.height = availableRect.size.height
        rect.size.width = rect.size.height / ratio
    }

    rect.origin.x = currentCenter.x - rect.size.width / 2.0
    rect.origin.y = currentCenter.y - rect.size.height / 2.0

    if rect.origin.x < availableRect.origin.x {
        rect.origin.x = availableRect.origin.x
    }
    if rect.origin.y < availableRect.origin.y {
        rect.origin.y = availableRect.origin.y
    }
    if rect.maxX > availableRect.maxX {
        rect.origin.x = availableRect.maxX - rect.size.width
    }
    if rect.maxY > availableRect.maxY {
        rect.origin.y = availableRect.maxY - rect.size.height
    }

    result.cropRect = rect
    return result
}

public func mediaCropRotatedCCW(_ state: MediaCropState) -> MediaCropState {
    var result = state
    result.orientation = state.orientation.rotatedCCW
    return result
}

public func mediaCropAvailableArea(container: CGRect) -> CGRect {
    return container.insetBy(dx: mediaCropContainerInset, dy: mediaCropContainerInset)
}

public func mediaCropAreaFrame(cropSize: CGSize, orientation: MediaCropOrientation, container: CGRect) -> CGRect {
    let bounds = container.insetBy(dx: mediaCropContainerInset, dy: mediaCropContainerInset)
    var displayedSize = cropSize
    if orientation.isSideward {
        displayedSize = CGSize(width: cropSize.height, height: cropSize.width)
    }
    guard displayedSize.width > 0.0, displayedSize.height > 0.0, bounds.width > 0.0, bounds.height > 0.0 else {
        return CGRect(origin: CGPoint(x: bounds.midX, y: bounds.midY), size: .zero)
    }
    var size = CGSize(width: bounds.width, height: floor(bounds.width * displayedSize.height / displayedSize.width))
    if size.height > bounds.height {
        size.height = bounds.height
        size.width = floor(size.height * displayedSize.width / displayedSize.height)
    }
    return CGRect(x: bounds.midX - size.width / 2.0, y: bounds.midY - size.height / 2.0, width: size.width, height: size.height)
}

public func mediaCropClampedCropRect(_ rect: CGRect, state: MediaCropState) -> CGRect {
    let minimumSize = CGSize(width: state.originalSize.width / mediaCropMaximumZoomScale, height: state.originalSize.height / mediaCropMaximumZoomScale)
    var result = rect
    if rect.width < minimumSize.width && rect.height < minimumSize.height {
        if rect.width > rect.height {
            result.size.width = minimumSize.width
            result.size.height = rect.height * result.width / rect.width
        } else {
            result.size.height = minimumSize.height
            result.size.width = rect.width * result.height / rect.height
        }
    }

    if !state.perspective.isZero {
        return mediaCropQuadClampedRect(result, state: state)
    }

    let contentSize = mediaCropRotatedContentSize(state.originalSize, rotation: state.rotation)
    if result.width > contentSize.width || result.height > contentSize.height {
        let factor = min(contentSize.width / result.width, contentSize.height / result.height)
        result.size = CGSize(width: result.width * factor, height: result.height * factor)
    }
    if result.maxX > contentSize.width {
        result.origin.x = contentSize.width - result.width
    }
    if result.maxY > contentSize.height {
        result.origin.y = contentSize.height - result.height
    }
    if result.minX < 0.0 {
        result.origin.x = 0.0
    }
    if result.minY < 0.0 {
        result.origin.y = 0.0
    }
    return result
}

private func mediaCropConstrainedByWidth(_ rect: CGRect, aspectRatio: CGFloat) -> CGRect {
    var rect = rect
    rect.size.height = rect.size.width * aspectRatio
    return rect
}

private func mediaCropConstrainedByHeight(_ rect: CGRect, aspectRatio: CGFloat) -> CGRect {
    var rect = rect
    rect.size.width = rect.size.height / aspectRatio
    return rect
}

private func mediaCropResizedFrame(_ frame: CGRect, handle: MediaCropHandle, translation: CGPoint, aspectRatio: CGFloat?) -> CGRect {
    var rect = frame
    let followsHeight = abs(translation.x) < abs(translation.y)

    switch handle {
    case .topLeft:
        rect = CGRect(x: frame.minX + translation.x, y: frame.minY + translation.y, width: frame.width - translation.x, height: frame.height - translation.y)
        if let aspectRatio {
            var constrained = followsHeight ? mediaCropConstrainedByHeight(rect, aspectRatio: aspectRatio) : mediaCropConstrainedByWidth(rect, aspectRatio: aspectRatio)
            constrained.origin.x -= constrained.width - rect.width
            constrained.origin.y -= constrained.height - rect.height
            rect = constrained
        }
    case .topRight:
        rect = CGRect(x: frame.minX, y: frame.minY + translation.y, width: frame.width + translation.x, height: frame.height - translation.y)
        if let aspectRatio {
            var constrained = followsHeight ? mediaCropConstrainedByHeight(rect, aspectRatio: aspectRatio) : mediaCropConstrainedByWidth(rect, aspectRatio: aspectRatio)
            constrained.origin.y -= constrained.height - rect.height
            rect = constrained
        }
    case .bottomLeft:
        rect = CGRect(x: frame.minX + translation.x, y: frame.minY, width: frame.width - translation.x, height: frame.height + translation.y)
        if let aspectRatio {
            var constrained = followsHeight ? mediaCropConstrainedByHeight(rect, aspectRatio: aspectRatio) : mediaCropConstrainedByWidth(rect, aspectRatio: aspectRatio)
            constrained.origin.x -= constrained.width - rect.width
            rect = constrained
        }
    case .bottomRight:
        rect = CGRect(x: frame.minX, y: frame.minY, width: frame.width + translation.x, height: frame.height + translation.y)
        if let aspectRatio {
            rect = followsHeight ? mediaCropConstrainedByHeight(rect, aspectRatio: aspectRatio) : mediaCropConstrainedByWidth(rect, aspectRatio: aspectRatio)
        }
    case .top:
        rect = CGRect(x: frame.minX, y: frame.minY + translation.y, width: frame.width, height: frame.height - translation.y)
        if let aspectRatio {
            rect = mediaCropConstrainedByHeight(rect, aspectRatio: aspectRatio)
        }
    case .left:
        rect = CGRect(x: frame.minX + translation.x, y: frame.minY, width: frame.width - translation.x, height: frame.height)
        if let aspectRatio {
            rect = mediaCropConstrainedByWidth(rect, aspectRatio: aspectRatio)
        }
    case .bottom:
        rect = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height + translation.y)
        if let aspectRatio {
            rect = mediaCropConstrainedByHeight(rect, aspectRatio: aspectRatio)
        }
    case .right:
        rect = CGRect(x: frame.minX, y: frame.minY, width: frame.width + translation.x, height: frame.height)
        if let aspectRatio {
            rect = mediaCropConstrainedByWidth(rect, aspectRatio: aspectRatio)
        }
    }

    if rect.size.width < mediaCropMinimumFrameSide {
        rect.size.width = mediaCropMinimumFrameSide
    }
    if rect.size.height < mediaCropMinimumFrameSide {
        rect.size.height = mediaCropMinimumFrameSide
    }

    if let aspectRatio {
        if aspectRatio > 1.0 {
            if rect.size.width <= mediaCropMinimumFrameSide {
                rect.size.width = mediaCropMinimumFrameSide
                rect.size.height = rect.size.width * aspectRatio
            }
        } else {
            if rect.size.height <= mediaCropMinimumFrameSide {
                rect.size.height = mediaCropMinimumFrameSide
                rect.size.width = rect.size.height / aspectRatio
            }
        }
    }

    return rect
}

private func mediaCropUnrotatedRect(_ displayed: CGRect, orientation: MediaCropOrientation, unrotatedSize: CGSize) -> CGRect {
    switch orientation {
    case .up:
        return displayed
    case .down:
        return CGRect(x: unrotatedSize.width - displayed.maxX, y: unrotatedSize.height - displayed.maxY, width: displayed.width, height: displayed.height)
    case .left:
        return CGRect(x: unrotatedSize.width - displayed.maxY, y: displayed.minX, width: displayed.height, height: displayed.width)
    case .right:
        return CGRect(x: displayed.minY, y: unrotatedSize.height - displayed.maxX, width: displayed.height, height: displayed.width)
    }
}

public func mediaCropResized(_ state: MediaCropState, corner: MediaCropHandle, translation: CGPoint, scale: CGFloat) -> MediaCropState {
    guard scale > 0.0 else {
        return state
    }
    var displayedRatio = state.effectiveLockedAspectRatio
    if let ratio = displayedRatio, state.orientation.isSideward {
        displayedRatio = 1.0 / ratio
    }

    let displayedSize = mediaCropDisplayedSize(state)
    let frame = CGRect(x: 0.0, y: 0.0, width: displayedSize.width * scale, height: displayedSize.height * scale)
    let resized = mediaCropResizedFrame(frame, handle: corner, translation: translation, aspectRatio: displayedRatio)

    let unrotatedSize = CGSize(width: state.cropRect.width * scale, height: state.cropRect.height * scale)
    let unrotated = mediaCropUnrotatedRect(resized, orientation: state.orientation, unrotatedSize: unrotatedSize)

    var result = state
    result.cropRect = CGRect(
        x: state.cropRect.minX + unrotated.minX / scale,
        y: state.cropRect.minY + unrotated.minY / scale,
        width: unrotated.width / scale,
        height: unrotated.height / scale
    )
    return result
}

public struct MediaCropSpring: Equatable {
    public var mass: CGFloat
    public var stiffness: CGFloat
    public var damping: CGFloat

    public init(mass: CGFloat, stiffness: CGFloat, damping: CGFloat) {
        self.mass = mass
        self.stiffness = stiffness
        self.damping = damping
    }
}

private func mediaCropPopNoBounceFriction(_ tension: CGFloat) -> CGFloat {
    if tension <= 18.0 {
        return 0.0007 * pow(tension, 3.0) - 0.031 * pow(tension, 2.0) + 0.64 * tension + 1.28
    } else if tension <= 44.0 {
        return 0.000044 * pow(tension, 3.0) - 0.006 * pow(tension, 2.0) + 0.36 * tension + 2.0
    } else {
        return 0.00000045 * pow(tension, 3.0) - 0.000332 * pow(tension, 2.0) + 0.1078 * tension + 5.84
    }
}

public func mediaCropPopSpring(speed: CGFloat, bounciness: CGFloat) -> MediaCropSpring {
    let normalizedBounciness = (bounciness / 1.7) / 20.0 * 0.8
    let normalizedSpeed = (speed / 1.7) / 20.0
    let tension = 0.5 + normalizedSpeed * (200.0 - 0.5)
    let progress = 2.0 * normalizedBounciness - normalizedBounciness * normalizedBounciness
    let friction = progress * 0.01 + (1.0 - progress) * mediaCropPopNoBounceFriction(tension)
    return MediaCropSpring(
        mass: 1.0,
        stiffness: 194.0 + ((tension - 30.0) / 50.0) * (375.0 - 194.0),
        damping: 25.0 + ((friction - 8.0) / 2.0) * (25.0 - 19.0)
    )
}

public struct MediaCropContentPlacement: Equatable {
    public var center: CGPoint
    public var scale: CGFloat

    public init(center: CGPoint, scale: CGFloat) {
        self.center = center
        self.scale = scale
    }
}

private func mediaCropRotatedVector(_ vector: CGPoint, by angle: CGFloat) -> CGPoint {
    let cosine = cos(angle)
    let sine = sin(angle)
    return CGPoint(x: vector.x * cosine - vector.y * sine, y: vector.x * sine + vector.y * cosine)
}

private func mediaCropUnrotatedFrameSize(_ size: CGSize, orientation: MediaCropOrientation) -> CGSize {
    if orientation.isSideward {
        return CGSize(width: size.height, height: size.width)
    }
    return size
}

public func mediaCropContentAngle(_ state: MediaCropState) -> CGFloat {
    return state.rotation - state.orientation.rotation
}

public func mediaCropContentPlacement(cropRect: CGRect, state: MediaCropState, frame: CGRect) -> MediaCropContentPlacement {
    let frameSize = mediaCropUnrotatedFrameSize(frame.size, orientation: state.orientation)
    guard cropRect.width > 0.0, cropRect.height > 0.0, frameSize.width > 0.0, frameSize.height > 0.0 else {
        return MediaCropContentPlacement(center: CGPoint(x: frame.midX, y: frame.midY), scale: 1.0)
    }
    let scale: CGFloat
    if cropRect.height / cropRect.width > frameSize.height / frameSize.width {
        scale = frameSize.width / cropRect.width
    } else {
        scale = frameSize.height / cropRect.height
    }
    let rotatedSize = mediaCropRotatedContentSize(state.originalSize, rotation: state.rotation)
    let offset = CGPoint(x: (cropRect.midX - rotatedSize.width / 2.0) * scale, y: (cropRect.midY - rotatedSize.height / 2.0) * scale)
    let screenOffset = mediaCropRotatedVector(offset, by: -state.orientation.rotation)
    return MediaCropContentPlacement(center: CGPoint(x: frame.midX - screenOffset.x, y: frame.midY - screenOffset.y), scale: scale)
}

public func mediaCropRect(frame: CGRect, placement: MediaCropContentPlacement, state: MediaCropState) -> CGRect {
    guard placement.scale > 0.0 else {
        return state.cropRect
    }
    let screenOffset = CGPoint(x: frame.midX - placement.center.x, y: frame.midY - placement.center.y)
    let offset = mediaCropRotatedVector(screenOffset, by: state.orientation.rotation)
    let rotatedSize = mediaCropRotatedContentSize(state.originalSize, rotation: state.rotation)
    let frameSize = mediaCropUnrotatedFrameSize(frame.size, orientation: state.orientation)
    let size = CGSize(width: frameSize.width / placement.scale, height: frameSize.height / placement.scale)
    let center = CGPoint(x: rotatedSize.width / 2.0 + offset.x / placement.scale, y: rotatedSize.height / 2.0 + offset.y / placement.scale)
    return CGRect(x: center.x - size.width / 2.0, y: center.y - size.height / 2.0, width: size.width, height: size.height)
}

private func mediaCropScaleToSize(_ size: CGSize, _ maxSize: CGSize) -> CGSize {
    var result = CGSize(width: maxSize.width, height: floor(maxSize.width * size.height / size.width))
    if result.height > maxSize.height {
        result.height = maxSize.height
        result.width = floor(result.height * size.width / size.height)
    }
    return result
}

public func mediaCropContentQuad(_ state: MediaCropState) -> [CGPoint] {
    return mediaEditorCropContentQuad(originalSize: state.originalSize, rotation: state.rotation, perspective: state.perspective)
}

private struct MediaCropHalfPlane {
    var normal: CGPoint
    var offset: CGFloat

    func value(_ point: CGPoint) -> CGFloat {
        return self.normal.x * point.x + self.normal.y * point.y
    }
}

private func mediaCropHalfPlanes(_ polygon: [CGPoint]) -> [MediaCropHalfPlane] {
    var area: CGFloat = 0.0
    for index in 0 ..< polygon.count {
        let a = polygon[index]
        let b = polygon[(index + 1) % polygon.count]
        area += a.x * b.y - b.x * a.y
    }
    let sign: CGFloat = area < 0.0 ? -1.0 : 1.0
    return (0 ..< polygon.count).map { index in
        let a = polygon[index]
        let b = polygon[(index + 1) % polygon.count]
        let normal = CGPoint(x: -(b.y - a.y) * sign, y: (b.x - a.x) * sign)
        return MediaCropHalfPlane(normal: normal, offset: normal.x * a.x + normal.y * a.y)
    }
}

public func mediaCropRectFits(_ rect: CGRect, state: MediaCropState) -> Bool {
    return mediaEditorCropRectFits(rect, originalSize: state.originalSize, rotation: state.rotation, perspective: state.perspective)
}

private func mediaCropScreenAxisCoefficients(_ orientation: MediaCropOrientation) -> (vertical: (CGFloat, CGFloat), horizontal: (CGFloat, CGFloat)) {
    let angle = -orientation.rotation
    let top = mediaCropRotatedVector(CGPoint(x: 0.0, y: -1.0), by: angle)
    let left = mediaCropRotatedVector(CGPoint(x: -1.0, y: 0.0), by: angle)
    func rounded(_ value: CGFloat) -> CGFloat {
        return value.rounded()
    }
    return (
        vertical: (-rounded(top.y), -rounded(left.y)),
        horizontal: (-rounded(top.x), -rounded(left.x))
    )
}

public func mediaCropScreenPerspective(_ state: MediaCropState) -> MediaEditorCropPerspective {
    let coefficients = mediaCropScreenAxisCoefficients(state.orientation)
    let stored = state.perspective
    return MediaEditorCropPerspective(
        vertical: coefficients.vertical.0 * stored.vertical + coefficients.vertical.1 * stored.horizontal,
        horizontal: coefficients.horizontal.0 * stored.vertical + coefficients.horizontal.1 * stored.horizontal
    )
}

public func mediaCropSettingScreenPerspective(_ state: MediaCropState, _ screen: MediaEditorCropPerspective) -> MediaCropState {
    let coefficients = mediaCropScreenAxisCoefficients(state.orientation)
    let limit = mediaEditorCropMaximumPerspectiveAngle * .pi / 180.0
    func clamped(_ value: CGFloat) -> CGFloat {
        return min(limit, max(-limit, value))
    }
    var result = state
    result.perspective = MediaEditorCropPerspective(
        vertical: clamped(coefficients.vertical.0 * screen.vertical + coefficients.horizontal.0 * screen.horizontal),
        horizontal: clamped(coefficients.vertical.1 * screen.vertical + coefficients.horizontal.1 * screen.horizontal)
    )
    return result
}

private func mediaCropQuadClampedRect(_ rect: CGRect, state: MediaCropState) -> CGRect {
    let planes = mediaCropHalfPlanes(mediaCropContentQuad(state))
    let bounds = max(state.originalSize.width, state.originalSize.height) * 10.0
    func centerPlanes(_ size: CGSize) -> [MediaCropHalfPlane] {
        let corners = [CGPoint(x: -size.width / 2.0, y: -size.height / 2.0), CGPoint(x: size.width / 2.0, y: -size.height / 2.0), CGPoint(x: size.width / 2.0, y: size.height / 2.0), CGPoint(x: -size.width / 2.0, y: size.height / 2.0)]
        return planes.map { plane in
            let minimum = corners.map { plane.value($0) }.min() ?? 0.0
            return MediaCropHalfPlane(normal: plane.normal, offset: plane.offset - minimum)
        }
    }
    var size = rect.size
    if mediaCropClippedRegion(centerPlanes(size), bounds: bounds).isEmpty {
        var low: CGFloat = 0.0
        var high: CGFloat = 1.0
        for _ in 0 ..< 50 {
            let middle = (low + high) / 2.0
            if mediaCropClippedRegion(centerPlanes(CGSize(width: rect.width * middle, height: rect.height * middle)), bounds: bounds).isEmpty {
                high = middle
            } else {
                low = middle
            }
        }
        size = CGSize(width: rect.width * low, height: rect.height * low)
    }
    let sizePlanes = centerPlanes(size)
    let center = mediaCropProjected(CGPoint(x: rect.midX, y: rect.midY), onto: mediaCropClippedRegion(sizePlanes, bounds: bounds), planes: sizePlanes)
    return CGRect(x: center.x - size.width / 2.0, y: center.y - size.height / 2.0, width: size.width, height: size.height)
}

private func mediaCropClippedRegion(_ planes: [MediaCropHalfPlane], bounds: CGFloat) -> [CGPoint] {
    var polygon = [CGPoint(x: -bounds, y: -bounds), CGPoint(x: bounds, y: -bounds), CGPoint(x: bounds, y: bounds), CGPoint(x: -bounds, y: bounds)]
    for plane in planes {
        var clipped: [CGPoint] = []
        for index in 0 ..< polygon.count {
            let a = polygon[index]
            let b = polygon[(index + 1) % polygon.count]
            let da = plane.value(a) - plane.offset
            let db = plane.value(b) - plane.offset
            if da >= 0.0 {
                clipped.append(a)
            }
            if (da >= 0.0) != (db >= 0.0) {
                let t = da / (da - db)
                clipped.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
            }
        }
        polygon = clipped
        if polygon.isEmpty {
            return []
        }
    }
    return polygon
}

private func mediaCropProjected(_ point: CGPoint, onto polygon: [CGPoint], planes: [MediaCropHalfPlane]) -> CGPoint {
    if polygon.isEmpty || planes.allSatisfy({ $0.value(point) >= $0.offset }) {
        return point
    }
    if polygon.count == 1 {
        return polygon[0]
    }
    var best = polygon[0]
    var bestDistance = CGFloat.greatestFiniteMagnitude
    for index in 0 ..< polygon.count {
        let a = polygon[index]
        let b = polygon[(index + 1) % polygon.count]
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        var t: CGFloat = 0.0
        if lengthSquared > 0.0 {
            t = max(0.0, min(1.0, ((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSquared))
        }
        let candidate = CGPoint(x: a.x + dx * t, y: a.y + dy * t)
        let distance = hypot(candidate.x - point.x, candidate.y - point.y)
        if distance < bestDistance {
            bestDistance = distance
            best = candidate
        }
    }
    return best
}

public func mediaCropCoverFit(_ placement: MediaCropContentPlacement, frame: CGRect, state: MediaCropState, allowScale: Bool, rotationStartScale: CGFloat? = nil) -> MediaCropContentPlacement {
    guard placement.scale > 0.0, frame.width > 0.0, frame.height > 0.0, state.originalSize.width > 0.0, state.originalSize.height > 0.0 else {
        return placement
    }
    if !state.perspective.isZero {
        return mediaCropPerspectiveCoverFit(placement, frame: frame, state: state, allowScale: allowScale, rotationStartScale: rotationStartScale)
    }
    let angle = mediaCropContentAngle(state)
    let frameCenter = CGPoint(x: frame.midX, y: frame.midY)
    var offset = mediaCropRotatedVector(CGPoint(x: frameCenter.x - placement.center.x, y: frameCenter.y - placement.center.y), by: -angle)
    let boundsSize = mediaCropRotatedContentSize(mediaCropUnrotatedFrameSize(frame.size, orientation: state.orientation), rotation: state.rotation)
    var scale = placement.scale
    var contentSize = CGSize(width: state.originalSize.width * scale, height: state.originalSize.height * scale)

    let boundsRect = CGRect(x: offset.x - boundsSize.width / 2.0, y: offset.y - boundsSize.height / 2.0, width: boundsSize.width, height: boundsSize.height)
    let contentRect = CGRect(x: -contentSize.width / 2.0, y: -contentSize.height / 2.0, width: contentSize.width, height: contentSize.height)
    if contentRect.contains(boundsRect) {
        guard let rotationStartScale, rotationStartScale > mediaCropFloatEpsilon else {
            return placement
        }
        let fitted = mediaCropScaleToSize(boundsSize, contentSize)
        if fitted.width > 0.0 {
            var ratio = boundsSize.width / fitted.width
            if scale * ratio < rotationStartScale {
                ratio = 1.0
            }
            scale *= ratio
            contentSize = CGSize(width: contentSize.width * ratio, height: contentSize.height * ratio)
        }
    } else if allowScale && (boundsSize.width > contentSize.width || boundsSize.height > contentSize.height) {
        let fitted = mediaCropScaleToSize(boundsSize, contentSize)
        if fitted.width > 0.0 {
            let ratio = boundsSize.width / fitted.width
            scale *= ratio
            contentSize = CGSize(width: contentSize.width * ratio, height: contentSize.height * ratio)
        }
    }

    var topLeft = CGPoint(x: offset.x - boundsSize.width / 2.0, y: offset.y - boundsSize.height / 2.0)
    let bottomRight = CGPoint(x: offset.x + boundsSize.width / 2.0, y: offset.y + boundsSize.height / 2.0)
    if -contentSize.width / 2.0 > topLeft.x {
        topLeft.x = -contentSize.width / 2.0
    }
    if -contentSize.height / 2.0 > topLeft.y {
        topLeft.y = -contentSize.height / 2.0
    }
    if contentSize.width / 2.0 < bottomRight.x {
        topLeft.x += contentSize.width / 2.0 - bottomRight.x
    }
    if contentSize.height / 2.0 < bottomRight.y {
        topLeft.y += contentSize.height / 2.0 - bottomRight.y
    }
    offset = CGPoint(x: topLeft.x + boundsSize.width / 2.0, y: topLeft.y + boundsSize.height / 2.0)

    let screenOffset = mediaCropRotatedVector(offset, by: angle)
    return MediaCropContentPlacement(center: CGPoint(x: frameCenter.x - screenOffset.x, y: frameCenter.y - screenOffset.y), scale: scale)
}

public func mediaCropCappedFrame(_ frame: CGRect, bounds: CGRect, aspectRatio: CGFloat?) -> CGRect {
    var rect = frame.offsetBy(dx: -bounds.minX, dy: -bounds.minY)
    let width = bounds.width
    let height = bounds.height

    if rect.maxX > width {
        rect.origin.x = min(width - mediaCropMinimumFrameSide, rect.origin.x)
        rect.size.width = max(mediaCropMinimumFrameSide, width - rect.origin.x)
        if let aspectRatio {
            rect.size.height = rect.size.width * aspectRatio
        }
    } else if rect.minX < 0.0 {
        rect.size.width = rect.maxX
        if let aspectRatio {
            rect.size.height = rect.size.width * aspectRatio
        }
        rect.origin.x = 0.0
    }

    if rect.maxY > height {
        rect.origin.y = min(height - mediaCropMinimumFrameSide, rect.origin.y)
        rect.size.height = max(mediaCropMinimumFrameSide, height - rect.origin.y)
        if let aspectRatio {
            rect.size.width = rect.size.height / aspectRatio
        }
    } else if rect.minY < 0.0 {
        rect.size.height = rect.maxY
        if let aspectRatio {
            rect.size.width = rect.size.height / aspectRatio
        }
        rect.origin.y = 0.0
    }

    return rect.offsetBy(dx: bounds.minX, dy: bounds.minY)
}

public func mediaCropDisplayedLockedRatio(_ state: MediaCropState) -> CGFloat? {
    guard let ratio = state.effectiveLockedAspectRatio else {
        return nil
    }
    if state.orientation.isSideward {
        return 1.0 / ratio
    }
    return ratio
}

public func mediaCropMinimumZoomScale(frameSize: CGSize, state: MediaCropState) -> CGFloat {
    let size = mediaCropUnrotatedFrameSize(frameSize, orientation: state.orientation)
    let original = state.originalSize
    guard original.width > 0.0, original.height > 0.0, size.width > 0.0 else {
        return 1.0
    }
    if original.height / original.width > size.height / size.width {
        return size.width / original.width
    } else {
        return size.height / original.height
    }
}

private func mediaCropRubberBandDistance(_ offset: CGFloat, dimension: CGFloat) -> CGFloat {
    let constant: CGFloat = 0.55
    let result = (constant * abs(offset) * dimension) / (dimension + constant * abs(offset))
    return offset < 0.0 ? -result : result
}

public func mediaCropPinchScale(startScale: CGFloat, gestureScale: CGFloat, minimumScale: CGFloat, contentWidth: CGFloat) -> CGFloat {
    guard startScale > 0.0, minimumScale > 0.0, contentWidth > 0.0 else {
        return startScale
    }
    var scale = gestureScale
    if startScale / minimumScale * scale > mediaCropMaximumZoomScale {
        scale = mediaCropMaximumZoomScale / startScale * minimumScale
    }
    let newSize = contentWidth * startScale * scale
    let constrainedSize = max(minimumScale * contentWidth, min(newSize, mediaCropMaximumZoomScale * contentWidth))
    let sizeDimension = mediaCropMaximumZoomScale * contentWidth - minimumScale * contentWidth
    let rubberBandedSize = mediaCropRubberBandDistance(newSize - constrainedSize, dimension: sizeDimension)
    let finalSize = max(minimumScale * contentWidth * 0.25, constrainedSize + rubberBandedSize)
    return finalSize / contentWidth
}

public func mediaCropDisplayedFrame(cropRect: CGRect, placement: MediaCropContentPlacement, state: MediaCropState) -> CGRect {
    let rotatedSize = mediaCropRotatedContentSize(state.originalSize, rotation: state.rotation)
    let offset = CGPoint(x: (cropRect.midX - rotatedSize.width / 2.0) * placement.scale, y: (cropRect.midY - rotatedSize.height / 2.0) * placement.scale)
    let screenOffset = mediaCropRotatedVector(offset, by: -state.orientation.rotation)
    let unrotatedSize = CGSize(width: cropRect.width * placement.scale, height: cropRect.height * placement.scale)
    let size = state.orientation.isSideward ? CGSize(width: unrotatedSize.height, height: unrotatedSize.width) : unrotatedSize
    let center = CGPoint(x: placement.center.x + screenOffset.x, y: placement.center.y + screenOffset.y)
    return CGRect(x: center.x - size.width / 2.0, y: center.y - size.height / 2.0, width: size.width, height: size.height)
}

public let mediaCropMaximumWheelAngle: CGFloat = 45.0

public func mediaCropPlacementRotated(_ placement: MediaCropContentPlacement, around center: CGPoint, by angle: CGFloat) -> MediaCropContentPlacement {
    let offset = mediaCropRotatedVector(CGPoint(x: placement.center.x - center.x, y: placement.center.y - center.y), by: angle)
    return MediaCropContentPlacement(center: CGPoint(x: center.x + offset.x, y: center.y + offset.y), scale: placement.scale)
}

public func mediaCropOrientationScreenAngle(_ orientation: MediaCropOrientation) -> CGFloat {
    return -orientation.rotation
}

public func mediaCropQuarterTurnTargetAngle(current: CGFloat, target: CGFloat) -> CGFloat {
    if abs(current - target) > .pi {
        return target - 2.0 * .pi
    }
    return target
}

private func mediaCropPerspectiveCoverFit(_ placement: MediaCropContentPlacement, frame: CGRect, state: MediaCropState, allowScale: Bool, rotationStartScale: CGFloat?) -> MediaCropContentPlacement {
    let angle = mediaCropContentAngle(state)
    let frameCenter = CGPoint(x: frame.midX, y: frame.midY)
    let offset = mediaCropRotatedVector(CGPoint(x: frameCenter.x - placement.center.x, y: frameCenter.y - placement.center.y), by: -angle)
    let halfWidth = frame.width / 2.0
    let halfHeight = frame.height / 2.0
    let corners = [CGPoint(x: -halfWidth, y: -halfHeight), CGPoint(x: halfWidth, y: -halfHeight), CGPoint(x: halfWidth, y: halfHeight), CGPoint(x: -halfWidth, y: halfHeight)].map { mediaCropRotatedVector($0, by: -angle) }
    let quadPlanes = mediaCropHalfPlanes(MediaEditorPerspectiveHomography(perspective: state.perspective, size: state.originalSize).quad(size: state.originalSize))
    let bounds = max(frame.width, frame.height) * 1000.0 + max(state.originalSize.width, state.originalSize.height) * placement.scale * 10.0

    func centerPlanes(scale: CGFloat) -> [MediaCropHalfPlane] {
        return quadPlanes.map { plane in
            let minimum = corners.map { plane.value($0) }.min() ?? 0.0
            return MediaCropHalfPlane(normal: plane.normal, offset: plane.offset * scale - minimum)
        }
    }
    func region(scale: CGFloat) -> [CGPoint] {
        return mediaCropClippedRegion(centerPlanes(scale: scale), bounds: bounds * max(1.0, scale / placement.scale))
    }
    func minimalFeasibleScale(from lower: CGFloat, to upper: CGFloat) -> CGFloat {
        var low = lower
        var high = upper
        for _ in 0 ..< 50 {
            let middle = (low + high) / 2.0
            if region(scale: middle).isEmpty {
                low = middle
            } else {
                high = middle
            }
        }
        return high
    }

    var scale = placement.scale
    if region(scale: scale).isEmpty {
        var upper = scale
        for _ in 0 ..< 40 {
            upper *= 2.0
            if !region(scale: upper).isEmpty {
                break
            }
        }
        let feasible = minimalFeasibleScale(from: scale, to: upper)
        if allowScale {
            scale = feasible
        } else {
            let target = region(scale: feasible).map { CGPoint(x: $0.x * scale / feasible, y: $0.y * scale / feasible) }
            let projected = mediaCropProjected(offset, onto: target, planes: mediaCropHalfPlanes(target))
            let screenOffset = mediaCropRotatedVector(projected, by: angle)
            return MediaCropContentPlacement(center: CGPoint(x: frameCenter.x - screenOffset.x, y: frameCenter.y - screenOffset.y), scale: scale)
        }
    } else if let rotationStartScale, rotationStartScale > mediaCropFloatEpsilon, centerPlanes(scale: scale).allSatisfy({ $0.value(offset) >= $0.offset - hypot($0.normal.x, $0.normal.y) * max(frame.width, frame.height) * 1e-6 }) {
        let minimal = minimalFeasibleScale(from: 0.0, to: scale)
        if minimal >= rotationStartScale {
            scale = minimal
        }
    }

    let planes = centerPlanes(scale: scale)
    let projected = mediaCropProjected(offset, onto: region(scale: scale), planes: planes)
    let screenOffset = mediaCropRotatedVector(projected, by: angle)
    return MediaCropContentPlacement(center: CGPoint(x: frameCenter.x - screenOffset.x, y: frameCenter.y - screenOffset.y), scale: scale)
}

public func mediaCropAdjustmentFit(_ placement: MediaCropContentPlacement, frame: CGRect, state: MediaCropState, rotationStartScale: CGFloat?) -> MediaCropContentPlacement {
    guard placement.scale > 0.0, frame.width > 0.0, frame.height > 0.0, state.originalSize.width > 0.0, state.originalSize.height > 0.0 else {
        return placement
    }
    let translated = mediaCropPerspectiveCoverFit(placement, frame: frame, state: state, allowScale: true, rotationStartScale: rotationStartScale)
    return mediaCropPerspectiveCoverFit(translated, frame: frame, state: state, allowScale: true, rotationStartScale: rotationStartScale)
}
