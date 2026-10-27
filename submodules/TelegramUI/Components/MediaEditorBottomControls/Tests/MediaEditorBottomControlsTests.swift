import Foundation
import UIKit
import XCTest
import Display
import ComponentFlow
import ContextReferenceButtonComponent
@testable import MediaEditorBottomControls

final class MediaEditorBottomControlsLayoutTests: XCTestCase {
    func testLayoutBetweenSideButtonsCentring() {
        let spec = MediaEditorBottomControlsLayoutSpec(sideInset: 16.0, middleCentering: .betweenSideButtons)
        let layout = mediaEditorBottomControlsLocalLayout(width: 402.0, spec: spec, middleItemWidths: [44.0, 44.0, 44.0, 44.0], middleSpacing: 10.0, leftWidth: 44.0, rightWidth: 83.0)
        XCTAssertEqual(layout.leftFrame, CGRect(x: 16.0, y: 0.0, width: 44.0, height: 44.0))
        XCTAssertEqual(layout.rightFrame, CGRect(x: 303.0, y: 0.0, width: 83.0, height: 44.0))
        XCTAssertEqual(layout.middleFrame!.minX, 78.3, accuracy: 0.5)
        XCTAssertEqual(layout.middleFrame!.width, 206.0)
        XCTAssertEqual(layout.middleFrame!.minX - layout.leftFrame.maxX, layout.rightFrame.minX - layout.middleFrame!.maxX, accuracy: 1.0)
    }

    func testLayoutBetweenSideButtonsFollowsTheRightWidth() {
        let spec = MediaEditorBottomControlsLayoutSpec(sideInset: 16.0, middleCentering: .betweenSideButtons)
        let wide = mediaEditorBottomControlsLocalLayout(width: 402.0, spec: spec, middleItemWidths: [44.0, 44.0, 44.0, 44.0], middleSpacing: 10.0, leftWidth: 44.0, rightWidth: 83.0)
        let narrow = mediaEditorBottomControlsLocalLayout(width: 402.0, spec: spec, middleItemWidths: [44.0, 44.0, 44.0, 44.0], middleSpacing: 10.0, leftWidth: 44.0, rightWidth: 44.0)
        XCTAssertEqual(narrow.rightFrame.minX, 342.0)
        XCTAssertGreaterThan(narrow.middleFrame!.minX, wide.middleFrame!.minX)
    }

    func testLayoutScreenBandCentringMatchesChat() {
        let spec = MediaEditorBottomControlsLayoutSpec(sideInset: 26.0, middleCentering: .screenBand(inset: 44.0))
        let gallery = mediaEditorBottomControlsLocalLayout(width: 402.0, spec: spec, middleItemWidths: [44.0, 44.0, 44.0, 44.0], middleSpacing: 10.0, leftWidth: 44.0, rightWidth: 46.0)
        XCTAssertEqual(gallery.leftFrame.minX, 26.0)
        XCTAssertEqual(gallery.middleFrame?.minX, 98.0)
        XCTAssertEqual(gallery.middleFrame?.maxX, 304.0)
        XCTAssertEqual(gallery.rightFrame.minX, 330.0)
        let crop = mediaEditorBottomControlsLocalLayout(width: 402.0, spec: spec, middleItemWidths: [44.0, 44.0, 44.0], middleSpacing: 10.0, leftWidth: 44.0, rightWidth: 44.0)
        XCTAssertEqual(crop.middleFrame?.minX, 125.0)
        XCTAssertEqual(crop.rightFrame.minX, 332.0)
    }

    func testRightExtraInsetMovesOnlyTheRightButton() {
        let spec = MediaEditorBottomControlsLayoutSpec(sideInset: 30.0, rightExtraInset: 20.0, middleCentering: .betweenSideButtons)
        let layout = mediaEditorBottomControlsLocalLayout(width: 800.0, spec: spec, middleItemWidths: [44.0], middleSpacing: 10.0, leftWidth: 44.0, rightWidth: 44.0)
        XCTAssertEqual(layout.leftFrame.minX, 30.0)
        XCTAssertEqual(layout.rightFrame.maxX, 800.0 - 30.0 - 20.0)
        XCTAssertEqual(layout.middleFrame!.midX, (layout.leftFrame.maxX + layout.rightFrame.minX) / 2.0, accuracy: 1.0)
    }

    func testEqualityIgnoresClosuresButSeesContent() {
        let make = { (title: String) -> MediaEditorBottomControlsComponent in
            return MediaEditorBottomControlsComponent(
                spec: MediaEditorBottomControlsLayoutSpec(sideInset: 16.0, middleCentering: .betweenSideButtons),
                left: MediaEditorBottomControlsSideItem(id: "back", content: .icon("Navigation/Back", flipped: false), tint: .panel),
                right: MediaEditorBottomControlsSideItem(id: "check", content: .icon("Navigation/Done", flipped: false), width: 44.0, tint: .panel),
                middle: [MediaEditorBottomControlsMiddleItem(id: "a", content: .text(title, font: Font.regular(15.0), horizontalInset: 16.0), action: {})],
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
            )
        }
        XCTAssertTrue(make("Draw") == make("Draw"))
        XCTAssertFalse(make("Draw") == make("Text"))
    }

    func testSelectionAndScreenStableHelpers() {
        XCTAssertEqual(mediaEditorBottomControlsSelectionFrame(itemFrame: CGRect(x: 0.0, y: 0.0, width: 68.0, height: 44.0)), CGRect(x: 3.0, y: 3.0, width: 62.0, height: 38.0))
        XCTAssertEqual(mediaEditorBottomControlsScreenStableFrame(CGRect(x: 0.0, y: 0.0, width: 44.0, height: 44.0), fromCapsuleOrigin: CGPoint(x: 98.0, y: 0.0), toCapsuleOrigin: CGPoint(x: 125.0, y: 0.0)).minX, -27.0)
        XCTAssertFalse(mediaEditorBottomControlsSideTapAllowed(now: 10.2, lastSideItemsChange: 10.0))
        XCTAssertTrue(mediaEditorBottomControlsSideTapAllowed(now: 10.4, lastSideItemsChange: 10.0))
    }
}

final class MediaEditorBottomControlsComponentTests: XCTestCase {
    private let storySpec = MediaEditorBottomControlsLayoutSpec(sideInset: 16.0, middleCentering: .betweenSideButtons)

    private func update(_ view: ComponentView<Empty>, right: MediaEditorBottomControlsSideItem, middle: [MediaEditorBottomControlsMiddleItem], transition: ComponentTransition = .immediate) -> MediaEditorBottomControlsComponent.View {
        let _ = view.update(
            transition: transition,
            component: AnyComponent(MediaEditorBottomControlsComponent(
                spec: self.storySpec,
                left: MediaEditorBottomControlsSideItem(id: "back", content: .icon("Navigation/Back", flipped: false), tint: .panel),
                right: right,
                middle: middle,
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

    private func icons(_ ids: [String]) -> [MediaEditorBottomControlsMiddleItem] {
        return ids.map { MediaEditorBottomControlsMiddleItem(id: $0, content: .icon("Media Editor/Crop"), action: {}) }
    }

    func testLabelRightItemIsMeasuredAndKeepsTheSideInset() {
        let view = ComponentView<Empty>()
        let controls = update(view, right: MediaEditorBottomControlsSideItem(id: "next", content: .label("NEXT", icon: "Media Editor/Next"), tint: .accent(.blue)), middle: icons(["a", "b", "c", "d"]))
        let frame = controls.rightButtonFrame(in: controls)!
        XCTAssertEqual(frame.maxX, 386.0)
        XCTAssertGreaterThan(frame.width, 60.0)
        let middle = controls.middleCapsuleView.frame
        XCTAssertEqual(middle.minX - 60.0, frame.minX - middle.maxX, accuracy: 1.0)
    }

    func testCustomContentKeepsIdentityAcrossUpdates() {
        let view = ComponentView<Empty>()
        let custom = { (alpha: CGFloat) -> [MediaEditorBottomControlsMiddleItem] in
            return [MediaEditorBottomControlsMiddleItem(id: "x", content: .custom(AnyComponent(Rectangle(color: UIColor(white: 1.0, alpha: alpha), width: 20.0, height: 20.0))), action: {})]
        }
        let first = update(view, right: MediaEditorBottomControlsSideItem(id: "check", content: .icon("Navigation/Done", flipped: false), width: 44.0, tint: .panel), middle: custom(1.0)).middleItemView(id: "x")
        let second = update(view, right: MediaEditorBottomControlsSideItem(id: "check", content: .icon("Navigation/Done", flipped: false), width: 44.0, tint: .panel), middle: custom(0.5)).middleItemView(id: "x")
        XCTAssertNotNil(first)
        XCTAssertTrue(first === second)
    }

    func testMiddleItemViewsFollowTheItemOrder() {
        let view = ComponentView<Empty>()
        let controls = update(view, right: MediaEditorBottomControlsSideItem(id: "check", content: .icon("Navigation/Done", flipped: false), width: 44.0, tint: .panel), middle: icons(["a", "b", "c"]))
        XCTAssertEqual(controls.middleItemViews.map { $0.frame.minX }, ["a", "b", "c"].compactMap { controls.middleItemView(id: $0)?.frame.minX })
        XCTAssertEqual(controls.middleItemViews.map { $0.frame.minX }.sorted(), controls.middleItemViews.map { $0.frame.minX })
    }

    func testLongPressItemsUseAContextReferenceButton() {
        let view = ComponentView<Empty>()
        var items = icons(["a", "sticker"])
        items[1].longPress = { _, _ in }
        let controls = update(view, right: MediaEditorBottomControlsSideItem(id: "check", content: .icon("Navigation/Done", flipped: false), width: 44.0, tint: .panel), middle: items)
        XCTAssertTrue(controls.middleItemView(id: "sticker") is ContextReferenceButtonComponent.View)
        XCTAssertFalse(controls.middleItemView(id: "a") is ContextReferenceButtonComponent.View)
    }

    func testDismissFadesTheCapsulesAsWholesAndLeavesTheIconsStill() {
        let view = ComponentView<Empty>()
        let controls = update(view, right: MediaEditorBottomControlsSideItem(id: "check", content: .icon("Navigation/Done", flipped: false), width: 44.0, tint: .panel), middle: icons(["a", "b", "c"]))
        controls.animateOutAsWhole(duration: mediaEditorBottomControlsDismissFadeDuration)
        XCTAssertTrue((controls.layer.animationKeys() ?? []).contains("opacity"))
        XCTAssertTrue((controls.layer.animationKeys() ?? []).contains(where: { $0.contains("gaussianBlur") }))
        for capsule in [controls.leftCapsuleView, controls.middleCapsuleView, controls.rightCapsuleView] {
            XCTAssertEqual(capsule.layer.animationKeys() ?? [], [])
        }
        for item in controls.middleItemViews {
            XCTAssertEqual(item.layer.animationKeys() ?? [], [])
        }
    }

    func testContentAlphaDimsEveryCapsule() {
        let view = ComponentView<Empty>()
        let _ = view.update(
            transition: .immediate,
            component: AnyComponent(MediaEditorBottomControlsComponent(
                spec: self.storySpec,
                left: MediaEditorBottomControlsSideItem(id: "back", content: .icon("Navigation/Back", flipped: false), tint: .panel),
                right: MediaEditorBottomControlsSideItem(id: "check", content: .icon("Navigation/Done", flipped: false), width: 44.0, tint: .panel),
                middle: icons(["a"]),
                selectedId: nil,
                middleSpacing: 10.0,
                isHidden: false,
                isMiddleEnabled: true,
                areSideButtonsEnabled: true,
                isRightEnabled: true,
                contentAlpha: 0.3,
                infoString: nil,
                leftPressed: {},
                rightPressed: {},
                rightLongPressed: nil
            )),
            environment: {},
            forceUpdate: true,
            containerSize: CGSize(width: 402.0, height: 49.0)
        )
        let controls = view.view as! MediaEditorBottomControlsComponent.View
        XCTAssertEqual(controls.leftCapsuleView.alpha, 0.3, accuracy: 0.001)
        XCTAssertEqual(controls.rightCapsuleView.alpha, 0.3, accuracy: 0.001)
        XCTAssertEqual(controls.middleCapsuleView.alpha, 0.3, accuracy: 0.001)
    }
}
