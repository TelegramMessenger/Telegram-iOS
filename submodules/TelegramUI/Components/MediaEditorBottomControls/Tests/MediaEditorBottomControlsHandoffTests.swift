import XCTest
import UIKit
import Display
import ComponentFlow
@testable import MediaEditorBottomControls

final class MediaEditorBottomControlsHandoffTests: XCTestCase {
    func testStoryCameraSlotsMorphIntoTheEditorBar() {
        let cameraLeft = CGRect(x: 16.0, y: 779.0, width: 48.0, height: 48.0)
        let editorLeft = CGRect(x: 16.0, y: 781.7, width: 44.0, height: 44.0)
        XCTAssertEqual(mediaEditorBottomControlsHandoffSlotPlan(source: cameraLeft, target: editorLeft, reduceMotion: false), .morph(from: cameraLeft))
        let cameraMiddle = CGRect(x: 90.0, y: 779.0, width: 222.0, height: 48.0)
        let editorMiddle = CGRect(x: 78.3, y: 781.7, width: 206.0, height: 44.0)
        XCTAssertEqual(mediaEditorBottomControlsHandoffSlotPlan(source: cameraMiddle, target: editorMiddle, reduceMotion: false), .morph(from: cameraMiddle))
    }

    func testMissingOrEmptySlotsAppearInPlace() {
        let target = CGRect(x: 303.0, y: 781.7, width: 83.0, height: 44.0)
        XCTAssertEqual(mediaEditorBottomControlsHandoffSlotPlan(source: nil, target: target, reduceMotion: false), .inPlace)
        XCTAssertEqual(mediaEditorBottomControlsHandoffSlotPlan(source: CGRect(x: 338.0, y: 779.0, width: 0.0, height: 48.0), target: target, reduceMotion: false), .inPlace)
        XCTAssertEqual(mediaEditorBottomControlsHandoffSlotPlan(source: CGRect(x: 338.0, y: 779.0, width: 48.0, height: 48.0), target: target, reduceMotion: true), .inPlace)
    }

    func testCentreAnchoredContentKeepsItsOffsetFromTheCapsuleCentre() {
        let icon = CGRect(x: 12.0, y: 12.0, width: 24.0, height: 24.0)
        let moved = mediaEditorBottomControlsCentreAnchoredFrame(icon, fromCapsuleSize: CGSize(width: 48.0, height: 48.0), toCapsuleSize: CGSize(width: 83.0, height: 44.0))
        XCTAssertEqual(moved.midX - 83.0 * 0.5, icon.midX - 48.0 * 0.5, accuracy: 0.001)
        XCTAssertEqual(moved.midY - 44.0 * 0.5, icon.midY - 48.0 * 0.5, accuracy: 0.001)
        XCTAssertEqual(moved.size, icon.size)
    }

    func testPreviewMorphMapsTheContentOntoTheViewfinder() {
        let viewCenter = CGPoint(x: 201.0, y: 437.0)
        let photo = CGRect(x: 0.0, y: 155.0 * 402.0 / 368.0, width: 402.0, height: 536.0)
        let viewfinder = CGRect(x: 0.0, y: 147.0, width: 402.0, height: 536.0)
        let morph = mediaEditorPreviewMorph(viewCenter: viewCenter, contentFrame: photo, targetFrame: viewfinder)
        XCTAssertEqual(morph.scale, 1.0, accuracy: 0.0001)
        XCTAssertEqual(morph.position.y - viewCenter.y, viewfinder.midY - photo.midY, accuracy: 0.001)

        let small = CGRect(x: 20.0, y: 200.0, width: 201.0, height: 268.0)
        let scaled = mediaEditorPreviewMorph(viewCenter: viewCenter, contentFrame: photo, targetFrame: small)
        XCTAssertEqual(scaled.scale, 0.5, accuracy: 0.0001)
        let mappedMidX = scaled.position.x + (photo.midX - viewCenter.x) * scaled.scale
        let mappedMidY = scaled.position.y + (photo.midY - viewCenter.y) * scaled.scale
        XCTAssertEqual(mappedMidX, small.midX, accuracy: 0.001)
        XCTAssertEqual(mappedMidY, small.midY, accuracy: 0.001)
    }

    func testCompactPhoneMoveIsStillAMorph() {
        let source = CGRect(x: 16.0, y: 709.0, width: 48.0, height: 48.0)
        let target = CGRect(x: 16.0, y: 719.7, width: 44.0, height: 44.0)
        XCTAssertEqual(mediaEditorBottomControlsHandoffSlotPlan(source: source, target: target, reduceMotion: false), .morph(from: source))
    }
}

final class MediaEditorBottomControlsAdoptionTests: XCTestCase {
    private let barOrigin = CGPoint(x: 0.0, y: 790.0)
    private let root = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 402.0, height: 874.0))

    private func update(_ view: ComponentView<Empty>) -> MediaEditorBottomControlsComponent.View {
        let _ = view.update(
            transition: .immediate,
            component: AnyComponent(MediaEditorBottomControlsComponent(
                spec: MediaEditorBottomControlsLayoutSpec(sideInset: 16.0, middleCentering: .betweenSideButtons),
                left: MediaEditorBottomControlsSideItem(id: "back", content: .icon("Navigation/Back", flipped: false), tint: .panel),
                right: MediaEditorBottomControlsSideItem(id: "next", content: .label("NEXT", icon: nil), tint: .accent(.systemBlue)),
                middle: ["a", "b", "c", "d"].map { MediaEditorBottomControlsMiddleItem(id: $0, content: .icon("Media Editor/Crop"), action: {}) },
                selectedId: nil,
                middleSpacing: 10.0,
                isHidden: false,
                isMiddleEnabled: true,
                areSideButtonsEnabled: true,
                isRightEnabled: true,
                infoString: nil,
                leftPressed: {},
                rightPressed: {},
                rightLongPressed: nil
            )),
            environment: {},
            forceUpdate: true,
            containerSize: CGSize(width: 402.0, height: 49.0)
        )
        return view.view as! MediaEditorBottomControlsComponent.View
    }

    private func host(_ controls: MediaEditorBottomControlsComponent.View) {
        controls.frame = CGRect(origin: self.barOrigin, size: CGSize(width: 402.0, height: 49.0))
        self.root.addSubview(controls)
        controls.testCoordinateRoot = self.root
        controls.setNeedsLayout()
        controls.layoutIfNeeded()
    }

    private func drainMainQueue() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }

    private func restingFrame(_ view: UIView) -> CGRect {
        return CGRect(x: view.center.x - view.bounds.width * 0.5, y: view.center.y - view.bounds.height * 0.5, width: view.bounds.width, height: view.bounds.height)
    }

    private func windowFrame(_ view: UIView) -> CGRect {
        return view.convert(view.bounds, to: self.root)
    }

    func testPendingAdoptionWaitsForTheWindowAndConvertsFromWindowSpace() {
        let view = ComponentView<Empty>()
        let controls = self.update(view)
        let leftSlot = CGRect(x: 16.0, y: self.barOrigin.y - 3.0, width: 48.0, height: 48.0)
        let thumbnail = UIView(frame: CGRect(x: 4.0, y: 4.0, width: 40.0, height: 40.0))
        var adoptions = 0
        controls.adopt(MediaEditorBottomControlsHandoff(left: .init(frame: leftSlot, hasGlass: true, contentViews: [thumbnail]), middle: nil, right: nil, didAdopt: { adoptions += 1 }), reduceMotion: false)
        XCTAssertNil(thumbnail.superview)
        XCTAssertNil(controls.leftCapsuleView.layer.animation(forKey: "position"))

        self.host(controls)
        XCTAssertNotNil(thumbnail.superview)
        XCTAssertNotNil(controls.leftCapsuleView.layer.animation(forKey: "position"))
        let thumbnailInWindow = self.windowFrame(thumbnail)
        let capsuleInWindow = self.windowFrame(controls.leftCapsuleView)
        XCTAssertEqual(thumbnailInWindow.midX, capsuleInWindow.midX, accuracy: 0.001)
        XCTAssertEqual(thumbnailInWindow.midY, capsuleInWindow.midY, accuracy: 0.001)
        XCTAssertEqual(adoptions, 0)
        self.drainMainQueue()
        XCTAssertEqual(adoptions, 1)
    }

    func testAdoptedCapsulesStartOnTheCameraSlotsAndSpringHome() {
        let view = ComponentView<Empty>()
        let controls = self.update(view)
        self.host(controls)
        let leftTarget = self.restingFrame(controls.leftCapsuleView)
        let rightTarget = self.restingFrame(controls.rightCapsuleView)
        let flipSlot = CGRect(x: 338.0, y: self.barOrigin.y - 3.0, width: 48.0, height: 48.0)
        let flipIcon = UIView(frame: CGRect(x: 12.0, y: 12.0, width: 24.0, height: 24.0))
        controls.adopt(MediaEditorBottomControlsHandoff(
            left: .init(frame: CGRect(x: 16.0, y: self.barOrigin.y - 3.0, width: 48.0, height: 48.0), hasGlass: true, contentViews: []),
            middle: nil,
            right: .init(frame: flipSlot, hasGlass: true, contentViews: [flipIcon]),
            didAdopt: {}
        ), reduceMotion: false)

        XCTAssertEqual(self.restingFrame(controls.leftCapsuleView), leftTarget)
        XCTAssertEqual(self.restingFrame(controls.rightCapsuleView), rightTarget)
        XCTAssertNotNil(controls.rightCapsuleView.layer.animation(forKey: "position"))
        XCTAssertEqual(flipIcon.alpha, 0.0)
        XCTAssertTrue((flipIcon.layer.animationKeys() ?? []).contains(where: { $0.contains("gaussianBlur") }))
        XCTAssertEqual(self.windowFrame(flipIcon).midX, self.windowFrame(controls.rightCapsuleView).midX, accuracy: 0.001)
        XCTAssertNotNil(flipIcon.layer.animation(forKey: "position"))
        let nextInCapsule = controls.rightButtonView!
        XCTAssertEqual(self.windowFrame(nextInCapsule).midX, self.windowFrame(controls.rightCapsuleView).midX, accuracy: 0.5)
        XCTAssertNotNil(nextInCapsule.layer.animation(forKey: "position"))
        let backButton = controls.leftButtonView!
        XCTAssertEqual(backButton.alpha, 1.0)
        XCTAssertTrue((backButton.layer.animationKeys() ?? []).contains("opacity"))
        XCTAssertNil(controls.middleCapsuleView.layer.animation(forKey: "position"))
        XCTAssertTrue((controls.middleCapsuleView.layer.animationKeys() ?? []).contains("opacity"))
        XCTAssertEqual(controls.middleCapsuleView.transform, .identity)
    }

    func testReduceMotionAppearsInPlace() {
        let view = ComponentView<Empty>()
        let controls = self.update(view)
        self.host(controls)
        controls.adopt(MediaEditorBottomControlsHandoff(left: .init(frame: CGRect(x: 16.0, y: self.barOrigin.y - 3.0, width: 48.0, height: 48.0), hasGlass: true, contentViews: []), middle: nil, right: nil, didAdopt: {}), reduceMotion: true)
        XCTAssertNil(controls.leftCapsuleView.layer.animation(forKey: "position"))
        XCTAssertTrue((controls.layer.animationKeys() ?? []).contains("opacity"))
        XCTAssertTrue((controls.layer.animationKeys() ?? []).contains(where: { $0.contains("gaussianBlur") }))
        XCTAssertFalse((controls.leftCapsuleView.layer.animationKeys() ?? []).contains("opacity"))
    }

    func testToolSwitchStillKeepsIconsStillOnScreen() {
        let view = ComponentView<Empty>()
        let controls = self.update(view)
        self.host(controls)
        let a = controls.middleItemView(id: "a")!
        let aInWindow = self.windowFrame(a)
        let _ = view.update(
            transition: .spring(duration: 0.4),
            component: AnyComponent(MediaEditorBottomControlsComponent(
                spec: MediaEditorBottomControlsLayoutSpec(sideInset: 16.0, middleCentering: .betweenSideButtons),
                left: MediaEditorBottomControlsSideItem(id: "back", content: .icon("Navigation/Back", flipped: false), tint: .panel),
                right: MediaEditorBottomControlsSideItem(id: "next", content: .label("NEXT", icon: nil), tint: .accent(.systemBlue)),
                middle: ["x"].map { MediaEditorBottomControlsMiddleItem(id: $0, content: .icon("Media Editor/Crop"), action: {}) },
                selectedId: nil,
                middleSpacing: 10.0,
                isHidden: false,
                isMiddleEnabled: true,
                areSideButtonsEnabled: true,
                isRightEnabled: true,
                infoString: nil,
                leftPressed: {},
                rightPressed: {},
                rightLongPressed: nil
            )),
            environment: {},
            forceUpdate: true,
            containerSize: CGSize(width: 402.0, height: 49.0)
        )
        XCTAssertEqual(self.windowFrame(a).minX, aInWindow.minX, accuracy: 0.001)
    }

    func testBothCallbacksFireWhenAdoptedTwiceBeforeTheWindow() {
        let view = ComponentView<Empty>()
        let controls = self.update(view)
        var first = 0
        var second = 0
        controls.adopt(MediaEditorBottomControlsHandoff(left: nil, middle: nil, right: nil, didAdopt: { first += 1 }), reduceMotion: false)
        controls.adopt(MediaEditorBottomControlsHandoff(left: nil, middle: nil, right: nil, didAdopt: { second += 1 }), reduceMotion: false)
        self.host(controls)
        self.drainMainQueue()
        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 1)
    }

    func testHandBackSticksThroughLaterUpdates() {
        let view = ComponentView<Empty>()
        let controls = self.update(view)
        self.host(controls)
        let target = CGRect(x: 338.0, y: self.barOrigin.y - 3.0, width: 48.0, height: 48.0)
        let nextButton = controls.rightButtonView!
        let nextInWindow = self.windowFrame(nextButton)
        let capsuleBefore = self.windowFrame(controls.rightCapsuleView)
        controls.handBack(MediaEditorBottomControlsHandBack(left: nil, middle: nil, right: .init(frame: target, hasGlass: true)), reduceMotion: false)
        XCTAssertEqual(self.windowFrame(controls.rightCapsuleView), target)
        XCTAssertEqual(nextButton.alpha, 0.0)
        XCTAssertEqual(self.windowFrame(nextButton).midX - target.midX, nextInWindow.midX - capsuleBefore.midX, accuracy: 0.001)
        XCTAssertEqual(controls.leftCapsuleView.alpha, 0.0)
        XCTAssertFalse(controls.isUserInteractionEnabled)

        let _ = self.update(view)
        XCTAssertEqual(self.windowFrame(controls.rightCapsuleView), target)
        XCTAssertEqual(nextButton.alpha, 0.0)
        XCTAssertEqual(controls.leftCapsuleView.alpha, 0.0)
    }

    func testInPlaceAppearanceHoldsTheGlassHiddenUntilTheRestore() {
        let view = ComponentView<Empty>()
        let controls = self.update(view)
        self.host(controls)
        controls.adopt(MediaEditorBottomControlsHandoff(left: .init(frame: CGRect(x: 16.0, y: self.barOrigin.y - 3.0, width: 48.0, height: 48.0), hasGlass: true, contentViews: []), middle: nil, right: nil, didAdopt: {}), reduceMotion: false)
        XCTAssertFalse(controls.rightCapsuleIsGlassVisible)
        let _ = self.update(view)
        XCTAssertFalse(controls.rightCapsuleIsGlassVisible)
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        XCTAssertTrue(controls.rightCapsuleIsGlassVisible)
    }

    func testHandBackRightAfterAnInPlaceAppearanceKeepsTheGlassHidden() {
        let view = ComponentView<Empty>()
        let controls = self.update(view)
        self.host(controls)
        controls.adopt(MediaEditorBottomControlsHandoff(left: .init(frame: CGRect(x: 16.0, y: self.barOrigin.y - 3.0, width: 48.0, height: 48.0), hasGlass: true, contentViews: []), middle: nil, right: nil, didAdopt: {}), reduceMotion: false)
        XCTAssertFalse(controls.rightCapsuleIsGlassVisible)
        controls.handBack(MediaEditorBottomControlsHandBack(left: nil, middle: nil, right: nil), reduceMotion: true)
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        XCTAssertFalse(controls.rightCapsuleIsGlassVisible)
    }

    func testHandBackDuringTheAdoptionMovesCameraContentWithItsCapsule() {
        let view = ComponentView<Empty>()
        let controls = self.update(view)
        self.host(controls)
        let slot = CGRect(x: 16.0, y: self.barOrigin.y - 3.0, width: 48.0, height: 48.0)
        let thumbnail = UIView(frame: CGRect(x: 4.0, y: 4.0, width: 40.0, height: 40.0))
        controls.adopt(MediaEditorBottomControlsHandoff(left: .init(frame: slot, hasGlass: true, contentViews: [thumbnail]), middle: nil, right: nil, didAdopt: {}), reduceMotion: false)
        controls.handBack(MediaEditorBottomControlsHandBack(left: .init(frame: slot, hasGlass: true), middle: nil, right: nil), reduceMotion: false)
        self.drainMainQueue()
        XCTAssertNotNil(thumbnail.superview)
        XCTAssertEqual(self.windowFrame(thumbnail).midX, slot.midX, accuracy: 0.001)
        XCTAssertEqual(self.windowFrame(thumbnail).midY, slot.midY, accuracy: 0.001)
    }
}
