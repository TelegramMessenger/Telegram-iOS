import Foundation
import CoreGraphics

/// The drop now (Refresh.swift:416-466).
public struct NewsRefreshDropPose: Equatable {
    public var isVisible: Bool = false
    public var diameter: CGFloat = 0.0
    /// The drop's top below the island's bottom edge; negative overlaps the island.
    public var top: CGFloat = 0.0
    public var iconScale: CGFloat = 1.0
    public var iconAlpha: CGFloat = 0.0
    /// Seconds into the sticker's 60 fps file.
    public var iconTime: Double = 0.0
    /// Radians.
    public var iconAngle: CGFloat = 0.0

    public init() {
    }
}

public extension NewsRefreshModel {
    func dropPose(now: Double, input: NewsRefreshInput) -> NewsRefreshDropPose {
        let M = NewsRefreshMetrics.self
        let C = NewsRefreshCurves.self
        var pose = NewsRefreshDropPose()
        let g = input.gap
        let p = min(g / M.threshold, 1.0)
        func pullTop(_ d: CGFloat) -> CGFloat {
            return g <= M.threshold ? -d + (M.pullSpacing + d) * p : M.pullSpacing + (g - M.threshold) * 0.45
        }
        // While loading the drop sits centred between the island and the search field, which moves down with the pull
        // (user decision, 2026-10-15).
        let centredTop = (input.restingSearchFieldTop + g - input.islandFrame.maxY - M.dropSize) * 0.5

        switch self.phase {
        case .idle:
            guard g > 0.5, input.canPull else {
                return pose
            }
            pose.isVisible = true
            pose.diameter = C.mix(M.dropMinSize, M.dropSize, C.outQuad(min(g / 56.0, 1.0)))
            pose.top = pullTop(pose.diameter)
            pose.iconScale = pose.diameter / M.dropSize
            pose.iconAlpha = C.ramp(p, 0.12, 0.45)
            pose.iconTime = Double(C.smooth(C.ramp(p, 0.3, 1.0))) * M.popFrames / M.stickerFramesPerSecond
        case let .loading(since):
            let t = now - since
            pose.isVisible = true
            pose.diameter = M.dropSize
            let k = C.inOutCubic(C.ramp(t, 0.0, 0.3))
            let bob = 1.5 * CGFloat(sin(t * 2.0 * Double.pi / 1.6)) * C.smooth(C.ramp(t, 0.2, 0.6))
            pose.top = C.mix(pullTop(M.dropSize), centredTop, k) + bob
            pose.iconScale = 1.0
            pose.iconAlpha = 1.0
            pose.iconTime = t.truncatingRemainder(dividingBy: M.loopDuration)
            pose.iconAngle = CGFloat(4.0 * Double.pi / 180.0 * sin(t * 2.0 * Double.pi / 1.5)) * C.smooth(C.ramp(t, 0.3, 0.8))
        case let .retracting(since, fromTop, fromDiameter):
            let e = C.smooth(C.ramp(now - since, 0.0, M.retractDuration))
            guard e < 1.0 else {
                return pose
            }
            pose.isVisible = true
            pose.diameter = C.mix(fromDiameter, M.dropMinSize, e)
            pose.top = C.mix(fromTop, -pose.diameter, e)
            pose.iconScale = pose.diameter / M.dropSize
            pose.iconAlpha = 1.0 - e
            pose.iconTime = M.loopDuration - 1.0 / M.stickerFramesPerSecond
        }
        return pose
    }
}
