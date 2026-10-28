import XCTest
import UIKit
import ComponentFlow
import LiquidLens

/// The punch-out that cuts the regular content where the lens is (so that the content under the glass shows only as the
/// lens's lifted content) must cover exactly the glass. UIKit's own punch-out follows the lens layer's rect, which a
/// size change used to snap while the glass inside kept animating (the "snapping pill mask", iOS 26 chat folder tabs).
final class LiquidLensPunchoutTests: XCTestCase {
    private let size = CGSize(width: 364.0, height: 34.0)

    private func makeLens() throws -> LiquidLensView {
        guard #available(iOS 26.0, *), NSClassFromString("_UILiquidLensView") != nil else {
            throw XCTSkip("UIKit's lens exists on iOS 26 and later")
        }
        let lensView = LiquidLensView(kind: .noContainer)
        lensView.frame = CGRect(origin: CGPoint(), size: self.size)
        lensView.update(size: self.size, selectionOrigin: CGPoint(), selectionSize: CGSize(width: 48.0, height: 34.0), inset: 0.0, liftedInset: 6.0, isDark: false, isLifted: false, transition: .immediate)
        return lensView
    }

    private func subviews(of view: UIView, where predicate: (UIView) -> Bool) -> [UIView] {
        var result: [UIView] = []
        var stack: [UIView] = [view]
        while let current = stack.popLast() {
            if predicate(current) {
                result.append(current)
            }
            stack.append(contentsOf: current.subviews)
        }
        return result
    }

    private func isVisible(_ view: UIView, in root: UIView) -> Bool {
        var current: UIView? = view
        while let value = current, value !== root {
            if value.isHidden {
                return false
            }
            current = value.superview
        }
        return true
    }

    private func uikitLens(in view: LiquidLensView) throws -> UIView {
        return try XCTUnwrap(self.subviews(of: view, where: { NSStringFromClass(type(of: $0)) == "_UILiquidLensView" }).first)
    }

    private func visiblePunchouts(in view: LiquidLensView) -> [UIView] {
        return self.subviews(of: view, where: { ($0.layer.compositingFilter as? String) == "destOut" && self.isVisible($0, in: view) })
    }

    /// Both layers have the animation for `key` with the same timing and values, or neither has it.
    private func assertSameAnimation(_ key: String, _ lhs: CALayer, _ rhs: CALayer, file: StaticString = #filePath, line: UInt = #line) {
        guard let lhsAnimation = lhs.animation(forKey: key), let rhsAnimation = rhs.animation(forKey: key) else {
            XCTAssertEqual(lhs.animation(forKey: key) != nil, rhs.animation(forKey: key) != nil, "\(key): lens, punch-out", file: file, line: line)
            return
        }
        XCTAssertEqual(lhsAnimation.duration, rhsAnimation.duration, accuracy: 0.0001, key, file: file, line: line)
        XCTAssertEqual(lhsAnimation.beginTime, rhsAnimation.beginTime, accuracy: 0.0001, key, file: file, line: line)
        XCTAssertEqual(lhsAnimation.speed, rhsAnimation.speed, key, file: file, line: line)
        if let lhsAnimation = lhsAnimation as? CAKeyframeAnimation, let rhsAnimation = rhsAnimation as? CAKeyframeAnimation {
            XCTAssertEqual(lhsAnimation.values as? [NSValue], rhsAnimation.values as? [NSValue], key, file: file, line: line)
            XCTAssertEqual(lhsAnimation.keyTimes, rhsAnimation.keyTimes, key, file: file, line: line)
        } else if let lhsAnimation = lhsAnimation as? CABasicAnimation, let rhsAnimation = rhsAnimation as? CABasicAnimation {
            XCTAssertEqual(lhsAnimation.fromValue as? NSValue, rhsAnimation.fromValue as? NSValue, key, file: file, line: line)
            XCTAssertEqual(lhsAnimation.toValue as? NSValue, rhsAnimation.toValue as? NSValue, key, file: file, line: line)
            XCTAssertEqual(lhsAnimation.isAdditive, rhsAnimation.isAdditive, key, file: file, line: line)
        } else {
            XCTFail("\(key): \(type(of: lhsAnimation)) vs \(type(of: rhsAnimation))", file: file, line: line)
        }
    }

    func testOnePunchoutAboveTheContent() throws {
        let lensView = try self.makeLens()
        let punchouts = self.visiblePunchouts(in: lensView)
        XCTAssertEqual(punchouts.count, 1)
        guard let punchout = punchouts.first, let superview = lensView.contentView.superview else {
            return
        }
        XCTAssertTrue(punchout.superview === superview)
        let subviews = superview.subviews
        XCTAssertGreaterThan(subviews.firstIndex(of: punchout) ?? -1, subviews.firstIndex(of: lensView.contentView) ?? Int.max)
        let lens = try self.uikitLens(in: lensView)
        XCTAssertEqual(punchout.bounds, lens.bounds)
        XCTAssertEqual(punchout.center, lens.center)
    }

    /// A move to a tab of another width while the lens rests: the lens and its glass grow along the move, and the
    /// punch-out with them.
    func testPunchoutFollowsTheLensThroughASizeChange() throws {
        let lensView = try self.makeLens()
        lensView.update(size: self.size, selectionOrigin: CGPoint(x: 47.0, y: 0.0), selectionSize: CGSize(width: 160.0, height: 34.0), inset: 0.0, liftedInset: 6.0, isDark: false, isLifted: false, transition: .spring(duration: 0.35))

        let lens = try self.uikitLens(in: lensView)
        let punchout = try XCTUnwrap(self.visiblePunchouts(in: lensView).first)
        XCTAssertEqual(lens.bounds.size, CGSize(width: 160.0, height: 34.0))
        XCTAssertEqual(punchout.bounds, lens.bounds)
        XCTAssertEqual(punchout.center, lens.center)

        // The lens animates its size, as the glass UIKit lays out inside it does, rather than snapping to it (UIKit
        // animates the change additively, from the old size minus the new one).
        let lensSizeAnimation = try XCTUnwrap(lens.layer.animation(forKey: "bounds.size") as? CABasicAnimation)
        XCTAssertTrue(lensSizeAnimation.isAdditive)
        XCTAssertEqual((lensSizeAnimation.fromValue as? NSValue)?.cgSizeValue.width ?? 0.0, 48.0 - 160.0, accuracy: 0.001)
        XCTAssertNotNil(lens.layer.animation(forKey: "liquidLensPosition"))

        for key in ["bounds.size", "liquidLensPosition", "liquidLensFlex"] {
            self.assertSameAnimation(key, lens.layer, punchout.layer)
        }
    }

    /// The same while the lens is lifted (a tab tapped during the previous move): the lifted lens changes size too.
    func testPunchoutFollowsTheLiftedLensThroughASizeChange() throws {
        let lensView = try self.makeLens()
        // Lifted at once: UIKit's animated lift needs an application, which a test process does not have.
        lensView.update(size: self.size, selectionOrigin: CGPoint(x: 206.0, y: 0.0), selectionSize: CGSize(width: 159.0, height: 34.0), inset: 0.0, liftedInset: 6.0, isDark: false, isLifted: true, transition: .immediate)
        lensView.update(size: self.size, selectionOrigin: CGPoint(), selectionSize: CGSize(width: 48.0, height: 34.0), inset: 0.0, liftedInset: 6.0, isDark: false, isLifted: true, transition: .spring(duration: 0.35))

        let lens = try self.uikitLens(in: lensView)
        let punchout = try XCTUnwrap(self.visiblePunchouts(in: lensView).first)
        XCTAssertEqual(lens.bounds.size, CGSize(width: 60.0, height: 46.0))
        XCTAssertEqual(punchout.bounds, lens.bounds)
        XCTAssertEqual(punchout.center, lens.center)
        XCTAssertNotNil(lens.layer.animation(forKey: "bounds.size"))
        for key in ["bounds.size", "liquidLensPosition", "liquidLensFlex"] {
            self.assertSameAnimation(key, lens.layer, punchout.layer)
        }
    }
}
