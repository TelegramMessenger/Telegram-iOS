import XCTest
import UIKit
import Display
@testable import ChatMessageBackground

/// The backdrop's visible shape is its MASK, and the mask's shape is a stretchable 9-slice image.
/// Animating the backdrop's frame therefore means animating that image's box — animating only the
/// mask container leaves the shape snapping to its destination behind an animating clip.
final class ChatMessageBackdropFrameTests: XCTestCase {
    private let initialSize = CGSize(width: 200.0, height: 100.0)
    private let targetSize = CGSize(width: 200.0, height: 160.0)

    /// The mask is normally created by `setType`, which needs a `PrincipalThemeEssentialGraphics`
    /// this target cannot build. Everything `updateFrame` reads is the mask's own geometry, so the
    /// mask is installed directly instead.
    private func makeBackdrop() -> (ChatMessageBubbleBackdrop, BubbleBackdropMaskView) {
        let backdrop = ChatMessageBubbleBackdrop()
        let maskView = BubbleBackdropMaskView()
        backdrop.maskView = maskView
        backdrop.view.mask = maskView
        backdrop.frame = CGRect(origin: CGPoint(), size: self.initialSize)
        maskView.layoutIfNeeded()
        return (backdrop, maskView)
    }

    private func animatingAnimator() -> ControlledTransitionAnimator {
        return ControlledTransition(duration: 0.3, curve: .easeInOut, interactive: false).animator
    }

    /// Baseline: the node frames the mask at `bounds` inset by the mask inset, and the shape fills
    /// the mask. If this drifts the rest of the file is measuring the wrong thing.
    func testTheMaskAndItsShapeStartSizedToTheBackdrop() {
        let (_, maskView) = self.makeBackdrop()

        XCTAssertEqual(maskView.frame, CGRect(origin: CGPoint(), size: self.initialSize).insetBy(dx: -1.0, dy: -1.0))
        XCTAssertEqual(maskView.shapeView.frame, maskView.bounds)
    }

    /// The container animates today. Kept so a regression here is distinguishable from the shape's.
    func testAnAnimatedFrameUpdateAnimatesTheMaskContainer() {
        let (backdrop, maskView) = self.makeBackdrop()

        backdrop.updateFrame(CGRect(origin: CGPoint(), size: self.targetSize), animator: self.animatingAnimator())

        XCTAssertNotNil(maskView.layer.animation(forKey: "bounds"))
    }

    /// The shape carries the actual bubble outline, so this is the assertion the user sees.
    func testAnAnimatedFrameUpdateAnimatesTheMaskShape() {
        let (backdrop, maskView) = self.makeBackdrop()

        backdrop.updateFrame(CGRect(origin: CGPoint(), size: self.targetSize), animator: self.animatingAnimator())
        maskView.layoutIfNeeded()

        XCTAssertNotNil(maskView.shapeView.layer.animation(forKey: "bounds"))
    }

    /// Same defect through the `ContainedViewLayoutTransition` overload, which the non-list
    /// consumers (`MessageItemView`, `MediaPickerSelectedListNode`, the joined-channel bubble) use.
    func testAnAnimatedTransitionUpdateAnimatesTheMaskShape() {
        let (backdrop, maskView) = self.makeBackdrop()

        backdrop.updateFrame(CGRect(origin: CGPoint(), size: self.targetSize), transition: .animated(duration: 0.3, curve: .easeInOut))
        maskView.layoutIfNeeded()

        XCTAssertNotNil(maskView.shapeView.layer.animation(forKey: "bounds"))
    }

    /// Whatever the animation does, the settled geometry must still be right.
    func testTheMaskShapeSettlesAtTheNewSize() {
        let (backdrop, maskView) = self.makeBackdrop()

        backdrop.updateFrame(CGRect(origin: CGPoint(), size: self.targetSize), animator: self.animatingAnimator())
        maskView.layoutIfNeeded()

        XCTAssertEqual(maskView.frame, CGRect(origin: CGPoint(), size: self.targetSize).insetBy(dx: -1.0, dy: -1.0))
        XCTAssertEqual(maskView.shapeView.frame, maskView.bounds)
    }
}
