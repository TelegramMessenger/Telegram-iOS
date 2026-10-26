import XCTest
import UIKit
import Display
import GlassBackgroundComponent

final class GlassShapeKeyframesTests: XCTestCase {
    private func layers(_ layer: CALayer) -> [CALayer] {
        return [layer] + (layer.sublayers ?? []).flatMap { self.layers($0) }
    }

    // The card's corners: capsule while short, the screen's once tall — keyframed as given, not half the shorter side.
    func test_animateShape_keyframesTheGivenRadii() {
        let glass = GlassBackgroundView()
        glass.frame = CGRect(x: 0.0, y: 0.0, width: 140.0, height: 44.0)
        let timing = NavigationKeyframeTiming(origin: .explicit(CACurrentMediaTime()), duration: 0.1, factor: 1.0)
        let sizes = timing.sampleTimes.map { t in CGSize(width: 140.0 + 2000.0 * CGFloat(t), height: 44.0 + 4000.0 * CGFloat(t)) }
        let radii = sizes.map { min(min($0.width, $0.height) * 0.5, 55.0) }
        glass.animateShape(sizes: sizes, cornerRadii: radii, timing: timing, isDark: false, tintColor: .init(kind: .panel))
        let animations = self.layers(glass.layer).compactMap { $0.animation(forKey: "navigationGlass.cornerRadius") as? CAKeyframeAnimation }
        XCTAssertFalse(animations.isEmpty)
        for animation in animations {
            let values = (animation.values ?? []).compactMap { ($0 as? NSNumber)?.doubleValue }
            XCTAssertEqual(values.count, radii.count)
            XCTAssertEqual(values.last ?? 0.0, 55.0, accuracy: 0.001, "capped at the screen's corner")
        }
    }

    // Four radii per sample (iPhone Duo's cover screen, 8 pt on the hinge side): keyframed as the layer's own per-corner
    // radii, and the model (a custom shape) is the last of them.
    func test_animateShape_fourRadii_keyframesTheLayersCornerRadii() throws {
        try XCTSkipUnless(CALayer.cornerRadiiSupported)
        let glass = GlassBackgroundView()
        glass.frame = CGRect(x: 0.0, y: 0.0, width: 140.0, height: 44.0)
        let timing = NavigationKeyframeTiming(origin: .explicit(CACurrentMediaTime()), duration: 0.1, factor: 1.0)
        let sizes = timing.sampleTimes.map { t in CGSize(width: 140.0 + 2000.0 * CGFloat(t), height: 44.0 + 4000.0 * CGFloat(t)) }
        let radii = sizes.map { size -> GlassBackgroundView.CornerRadii in
            let capsule = min(size.width, size.height) * 0.5
            return GlassBackgroundView.CornerRadii(topLeft: min(capsule, 8.0), topRight: min(capsule, 59.0), bottomLeft: min(capsule, 8.0), bottomRight: min(capsule, 59.0))
        }
        glass.animateShape(sizes: sizes, cornerRadii: radii, timing: timing, isDark: false, tintColor: .init(kind: .panel))
        let animated = self.layers(glass.layer).filter { $0.animation(forKey: "navigationGlass.cornerRadii") != nil }
        XCTAssertFalse(animated.isEmpty)
        for layer in animated {
            let animation = layer.animation(forKey: "navigationGlass.cornerRadii") as? CAKeyframeAnimation
            let values = (animation?.values ?? []).compactMap { ($0 as? NSValue).flatMap { CornerRadii(boxedValue: $0) } }
            XCTAssertEqual(values.count, radii.count)
            XCTAssertEqual(values.last, CornerRadii(topLeft: 8.0, topRight: 59.0, bottomLeft: 8.0, bottomRight: 59.0))
            XCTAssertEqual(layer.cornerRadii, values.last, "the model is the last keyframe")
        }
    }
}
