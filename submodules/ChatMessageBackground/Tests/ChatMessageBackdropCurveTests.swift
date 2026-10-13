import XCTest
import UIKit
import Display
@testable import ChatMessageBackground

/// `ChatMessageBubbleItemNode` drives the whole bubble from ONE `ListViewItemUpdateAnimation`, so
/// every layer it touches should end up carrying the same curve. These replay the real call pair
/// and compare the animations the backdrop, its mask and the mask's silhouette actually receive.
final class ChatMessageBackdropCurveTests: XCTestCase {
    private let initialSize = CGSize(width: 200.0, height: 100.0)
    private let targetSize = CGSize(width: 200.0, height: 160.0)

    private func makeBackdrop() -> (ChatMessageBubbleBackdrop, BubbleBackdropMaskView) {
        let backdrop = ChatMessageBubbleBackdrop()
        let maskView = BubbleBackdropMaskView()
        backdrop.maskView = maskView
        backdrop.view.mask = maskView
        backdrop.frame = CGRect(origin: CGPoint(), size: self.initialSize)
        maskView.layoutIfNeeded()
        return (backdrop, maskView)
    }

    /// Everything that defines the SHAPE of the motion, with the from/to values left out — those
    /// legitimately differ per layer.
    private func curveShape(_ layer: CALayer, _ keyPath: String) -> String {
        guard let animation = layer.animation(forKey: keyPath) else {
            return "none"
        }
        var parts: [String] = [String(describing: type(of: animation))]
        parts.append("dur=\(String(format: "%.4f", animation.duration))")
        parts.append("speed=\(String(format: "%.4f", animation.speed))")
        parts.append("begin=\(String(format: "%.4f", animation.beginTime))")
        parts.append("additive=\((animation as? CAPropertyAnimation)?.isAdditive ?? false)")
        if let spring = animation as? CASpringAnimation {
            parts.append("mass=\(spring.mass) stiff=\(spring.stiffness) damp=\(spring.damping) v0=\(spring.initialVelocity)")
        }
        if let timing = animation.timingFunction {
            var points: [Float] = []
            for index in 0 ..< 4 {
                var pair: [Float] = [0.0, 0.0]
                timing.getControlPoint(at: index, values: &pair)
                points.append(contentsOf: pair)
            }
            parts.append("timing=\(points.map { String(format: "%.3f", $0) }.joined(separator: ","))")
        } else {
            parts.append("timing=nil")
        }
        return parts.joined(separator: " ")
    }

    /// Replays `ChatMessageBubbleItemNode.swift:5538` + `:5540` — the node's own layer first, then
    /// the backdrop's internals — for one curve.
    private func replayBubblePass(curve: ContainedViewLayoutTransitionCurve, duration: Double) -> [String: String] {
        let (backdrop, maskView) = self.makeBackdrop()
        let animator = ControlledTransition(duration: duration, curve: curve, interactive: false).animator
        let target = CGRect(origin: CGPoint(), size: self.targetSize)

        animator.updateFrame(layer: backdrop.layer, frame: target, completion: nil)
        backdrop.updateFrame(target, animator: animator)

        var result: [String: String] = [:]
        for keyPath in ["bounds", "position"] {
            result["backdrop.\(keyPath)"] = self.curveShape(backdrop.layer, keyPath)
            result["mask.\(keyPath)"] = self.curveShape(maskView.layer, keyPath)
            result["shape.\(keyPath)"] = self.curveShape(maskView.shapeView.layer, keyPath)
        }
        return result
    }

    /// `.spring` at 0.4 is what a chat insertion pass produces on both backends
    /// (`insertionAnimationDuration`, and CoreList's `.AnimateInsertion` fallback).
    func testSpringPassGivesTheMaskAndShapeTheBackdropsOwnCurve() {
        let shapes = self.replayBubblePass(curve: .spring, duration: 0.4)

        for keyPath in ["bounds", "position"] {
            XCTAssertNotEqual(shapes["backdrop.\(keyPath)"], "none", keyPath)
            XCTAssertEqual(shapes["mask.\(keyPath)"], shapes["backdrop.\(keyPath)"], keyPath)
            XCTAssertEqual(shapes["shape.\(keyPath)"], shapes["backdrop.\(keyPath)"], keyPath)
        }
    }

    /// `.easeInOut` at 0.15 is the streaming path (`requestFullUpdate`).
    func testEaseInOutPassGivesTheMaskAndShapeTheBackdropsOwnCurve() {
        let shapes = self.replayBubblePass(curve: .easeInOut, duration: 0.15)

        for keyPath in ["bounds", "position"] {
            XCTAssertNotEqual(shapes["backdrop.\(keyPath)"], "none", keyPath)
            XCTAssertEqual(shapes["mask.\(keyPath)"], shapes["backdrop.\(keyPath)"], keyPath)
            XCTAssertEqual(shapes["shape.\(keyPath)"], shapes["backdrop.\(keyPath)"], keyPath)
        }
    }

    /// The silhouette must travel to the same place the bubble's own image does. The background
    /// node frames its image at `bounds.insetBy(-1, -1)` in ITS space; the shape sits at (0,0)
    /// inside a mask that sits at (-1, -1) in the backdrop — the same rect, and the same size.
    func testTheShapeLandsWhereTheBubbleImageLands() {
        let (backdrop, maskView) = self.makeBackdrop()
        let animator = ControlledTransition(duration: 0.4, curve: .spring, interactive: false).animator
        let target = CGRect(origin: CGPoint(), size: self.targetSize)

        backdrop.updateFrame(target, animator: animator)

        let shapeInBackdrop = maskView.shapeView.frame.offsetBy(dx: maskView.frame.minX, dy: maskView.frame.minY)
        XCTAssertEqual(shapeInBackdrop, CGRect(origin: CGPoint(), size: self.targetSize).insetBy(dx: -1.0, dy: -1.0))
    }
}

/// Why the bubble's background and its mask ended up on two different animation clocks.
///
/// `ContainedViewLayoutTransition.updateFrame(layer:)` — and the bubble's own "did the background
/// move" guard — compare a requested rect against `CALayer.frame`, which is DERIVED from `position`
/// and `bounds`. That round-trip is lossy for a non-representable origin, so an exact `equalTo`
/// answers "changed" forever and every repeat pass restarts the animation from the presentation
/// value. Rects with integral origins are unaffected, which is exactly how the mask escaped it.
///
/// The numbers are the ones measured on device (iPhone 18 Pro, 2026-09-15): a bubble at the chat's
/// 7/3 inset, `2.3333333333333335` in and `2.333333333333332` back out.
final class ChatMessageBackdropFrameRoundTripTests: XCTestCase {
    private let bubbleOrigin = CGPoint(x: 314.703125, y: 7.0 / 3.0)
    private let bubbleSize = CGSize(width: 84.296875, height: 35.0)

    func testTheChatsBubbleInsetIsNotRepresentable() {
        XCTAssertEqual(self.bubbleOrigin.y, 2.3333333333333335)
    }

    /// The trap: written and read back on the same layer, the rect is no longer `equalTo` itself.
    func testABubbleFrameDoesNotRoundTripThroughALayer() {
        let layer = CALayer()
        let frame = CGRect(origin: self.bubbleOrigin, size: self.bubbleSize)

        layer.frame = frame

        XCTAssertFalse(layer.frame.equalTo(frame), "if this ever passes, the derived-frame guard is safe again")
        XCTAssertEqual(layer.position.y, 19.833333333333332)
        XCTAssertEqual(layer.frame.origin.y, 2.333333333333332)
        XCTAssertNotEqual(layer.frame.origin.y, frame.origin.y)
    }

    /// And why the mask, its silhouette and the wallpaper portal did NOT re-target: their rects are
    /// `bounds.insetBy(-1, -1)` and `(0, 0, w, h)`, whose origins survive the round-trip exactly.
    func testTheMaskAndShapeRectsRoundTripExactly() {
        for frame in [
            CGRect(origin: CGPoint(), size: self.bubbleSize).insetBy(dx: -1.0, dy: -1.0),
            CGRect(origin: CGPoint(), size: self.bubbleSize)
        ] {
            let layer = CALayer()
            layer.frame = frame
            XCTAssertTrue(layer.frame.equalTo(frame), "\(frame)")
        }
    }
}

/// The guard that decides whether an animated `updateFrame` is a no-op.
///
/// A repeat layout pass over an unchanged bubble must NOT restart the animation — that is what made
/// the bubble's contents wobble while its background sat still. The chat re-applies an identical
/// layout several times per interaction (a reaction fans out as optimistic → pending → confirmed →
/// reaction-list → read-state, six passes in 164ms measured on device), and every one of them
/// reached the animated branch because `CALayer.frame` cannot round-trip a 7/3 origin.
final class ChatMessageBackdropRepeatPassTests: XCTestCase {
    private let bubbleFrame = CGRect(x: 314.703125, y: 7.0 / 3.0, width: 84.296875, height: 35.0)

    private func animator() -> ControlledTransitionAnimator {
        return ControlledTransition(duration: 0.4, curve: .spring, interactive: false).animator
    }

    /// The whole bug in one assertion: same frame twice, second call must add nothing.
    func testARepeatedIdenticalFrameUpdateDoesNotRestartTheAnimation() {
        let layer = CALayer()
        layer.frame = CGRect(origin: self.bubbleFrame.origin, size: CGSize(width: 143.0, height: 69.0))

        self.animator().updateFrame(layer: layer, frame: self.bubbleFrame, completion: nil)
        let firstBounds = layer.animation(forKey: "bounds")
        let firstPosition = layer.animation(forKey: "position")
        XCTAssertNotNil(firstBounds, "the real change must animate")
        XCTAssertNotNil(firstPosition, "the real change must animate")

        self.animator().updateFrame(layer: layer, frame: self.bubbleFrame, completion: nil)

        XCTAssertTrue(layer.animation(forKey: "bounds") === firstBounds, "repeat pass re-targeted bounds")
        XCTAssertTrue(layer.animation(forKey: "position") === firstPosition, "repeat pass re-targeted position")
    }

    /// And the same through the backdrop, which is where it was visible.
    func testARepeatedIdenticalBackdropUpdateDoesNotRestartTheMask() {
        let backdrop = ChatMessageBubbleBackdrop()
        let maskView = BubbleBackdropMaskView()
        backdrop.maskView = maskView
        backdrop.view.mask = maskView
        backdrop.frame = CGRect(origin: self.bubbleFrame.origin, size: CGSize(width: 143.0, height: 69.0))
        maskView.layoutIfNeeded()

        backdrop.updateFrame(self.bubbleFrame, animator: self.animator())
        let node = backdrop.layer.animation(forKey: "bounds")
        let shape = maskView.shapeView.layer.animation(forKey: "bounds")
        XCTAssertNotNil(node)
        XCTAssertNotNil(shape)

        backdrop.updateFrame(self.bubbleFrame, animator: self.animator())

        XCTAssertTrue(backdrop.layer.animation(forKey: "bounds") === node, "backdrop re-targeted")
        XCTAssertTrue(maskView.shapeView.layer.animation(forKey: "bounds") === shape, "silhouette re-targeted")
    }
}
