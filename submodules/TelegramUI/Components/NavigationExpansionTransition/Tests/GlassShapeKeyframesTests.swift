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
}
