import Foundation
import UIKit
import XCTest
import TelegramCore
@testable import MediaEditor
import DrawingUI
@testable import ChatMediaEditorScreen

private let handOverPeerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))

final class ChatMediaEditorToolHandOverTests: XCTestCase {
    private func values() -> MediaEditorValues {
        return chatMediaEditorValues(peerId: handOverPeerId, originalDimensions: PixelDimensions(width: 4032, height: 3024), qualityPreset: .compressedVeryHigh)
    }

    func testUneditedValuesHighlightNoTool() {
        XCTAssertEqual(chatMediaEditorHighlightedToolsTabs(values: values()), [])
    }

    func testEachEditedToolIsHighlighted() {
        XCTAssertEqual(chatMediaEditorHighlightedToolsTabs(values: values().withUpdatedToolValues([.brightness: Float(0.4)])), [.adjustments])
        XCTAssertEqual(chatMediaEditorHighlightedToolsTabs(values: values().withUpdatedToolValues([.shadowsTint: TintValue(color: .red, intensity: 0.5)])), [.tint])
        XCTAssertEqual(chatMediaEditorHighlightedToolsTabs(values: values().withUpdatedToolValues([.curves: CurvesValue.initial.withUpdatedAll(CurvesValue.CurveValue(blacks: 0.2, shadows: 0.25, midtones: 0.5, highlights: 0.75, whites: 1.0))])), [.curves])
        XCTAssertEqual(chatMediaEditorHighlightedToolsTabs(values: values().withUpdatedToolValues([.brightness: Float(0.0)])), [])
    }

    func testGalleryHidesForTheKeyboardAndCaptionEditing() {
        XCTAssertFalse(chatMediaEditorBottomControlsAreHidden(mode: .gallery(activeTab: []), keyboardHeight: 0.0, isEditingCaption: false, paintControlsVisible: true))
        XCTAssertTrue(chatMediaEditorBottomControlsAreHidden(mode: .gallery(activeTab: []), keyboardHeight: 300.0, isEditingCaption: false, paintControlsVisible: true))
        XCTAssertTrue(chatMediaEditorBottomControlsAreHidden(mode: .gallery(activeTab: []), keyboardHeight: 0.0, isEditingCaption: true, paintControlsVisible: true))
    }

    func testCropQualityAndToolsNeverHide() {
        for mode in [ChatMediaEditorBottomControlsMode.crop(highlightedTabs: []), .quality, .tools(selected: .adjustments, highlighted: [])] {
            XCTAssertFalse(chatMediaEditorBottomControlsAreHidden(mode: mode, keyboardHeight: 300.0, isEditingCaption: true, paintControlsVisible: false))
        }
    }

    func testPaintHidesWhileDrawingAndForTheKeyboard() {
        XCTAssertFalse(chatMediaEditorBottomControlsAreHidden(mode: .paint(selected: .draw), keyboardHeight: 0.0, isEditingCaption: true, paintControlsVisible: true))
        XCTAssertTrue(chatMediaEditorBottomControlsAreHidden(mode: .paint(selected: .draw), keyboardHeight: 0.0, isEditingCaption: false, paintControlsVisible: false))
        XCTAssertTrue(chatMediaEditorBottomControlsAreHidden(mode: .paint(selected: .text), keyboardHeight: 300.0, isEditingCaption: false, paintControlsVisible: true))
    }

    func testPaintReportsHiddenControlsWhileDrawingInteractingOrEditingText() {
        XCTAssertTrue(drawingScreenExternalControlsAreVisible(isDrawing: false, isInteractingWithEntities: false, isEditingText: false))
        XCTAssertFalse(drawingScreenExternalControlsAreVisible(isDrawing: true, isInteractingWithEntities: false, isEditingText: false))
        XCTAssertFalse(drawingScreenExternalControlsAreVisible(isDrawing: false, isInteractingWithEntities: true, isEditingText: false))
        XCTAssertFalse(drawingScreenExternalControlsAreVisible(isDrawing: false, isInteractingWithEntities: false, isEditingText: true))
        XCTAssertTrue(chatMediaEditorBottomControlsAreHidden(mode: .paint(selected: .text), keyboardHeight: 0.0, isEditingCaption: false, paintControlsVisible: drawingScreenExternalControlsAreVisible(isDrawing: false, isInteractingWithEntities: false, isEditingText: true)))
    }

    func testPaintTextEditingButtonsAreIconsInBothEditorsButNotLegacy() {
        XCTAssertTrue(drawingScreenUsesIconTextEditingButtons(sourceHint: .chatMediaEditor))
        XCTAssertTrue(drawingScreenUsesIconTextEditingButtons(sourceHint: .storyEditor))
        XCTAssertFalse(drawingScreenUsesIconTextEditingButtons(sourceHint: nil))
    }

    func testPaintBottomControlsAreSkippedOnlyWithExternalControls() {
        XCTAssertTrue(drawingScreenSkipsBottomControls(sourceHint: .chatMediaEditor, externalControls: true))
        XCTAssertTrue(drawingScreenSkipsBottomControls(sourceHint: .storyEditor, externalControls: true))
        XCTAssertFalse(drawingScreenSkipsBottomControls(sourceHint: .storyEditor, externalControls: false))
        XCTAssertFalse(drawingScreenSkipsBottomControls(sourceHint: nil, externalControls: false))
        XCTAssertFalse(drawingScreenSkipsBottomControls(sourceHint: .chatMediaEditor, externalControls: false))
    }

    func testSideTapsWaitForTheModeSwitch() {
        XCTAssertTrue(chatMediaEditorBottomControlsSideTapAllowed(now: 10.0, lastSideItemsChange: nil))
        XCTAssertFalse(chatMediaEditorBottomControlsSideTapAllowed(now: 10.1, lastSideItemsChange: 10.0))
        XCTAssertFalse(chatMediaEditorBottomControlsSideTapAllowed(now: 10.34, lastSideItemsChange: 10.0))
        XCTAssertTrue(chatMediaEditorBottomControlsSideTapAllowed(now: 10.36, lastSideItemsChange: 10.0))
    }

    func testToolbarSitsAboveEmbeddedToolsOnly() {
        XCTAssertEqual(chatMediaEditorBottomControlsPlacement(hasEmbeddedTool: true), .aboveEmbeddedTool)
        XCTAssertEqual(chatMediaEditorBottomControlsPlacement(hasEmbeddedTool: false), .belowCaptionDim)
    }
}
