import Foundation
import UIKit
import XCTest
import TelegramCore
@testable import MediaEditor
import ChatMediaEditorScreen

final class WallpaperMediaEditorTests: XCTestCase {
    private let dimensions = PixelDimensions(width: 1170, height: 2532)

    func testHiddenToolsDropRegionalTools() {
        XCTAssertEqual(Set(wallpaperMediaEditorHiddenTools()), Set([EditorToolKey.blur, .vignette]))
        XCTAssertEqual(wallpaperMediaEditorHiddenTools().count, 2)
    }

    func testNoChangesNoCompletion() {
        let values = wallpaperMediaEditorInitialValues(previousState: nil, dimensions: self.dimensions)
        XCTAssertFalse(wallpaperMediaEditorHasChanges(values))
        XCTAssertTrue(values.toolValues.isEmpty)
        XCTAssertEqual(values.originalDimensions, self.dimensions)
        XCTAssertFalse(wallpaperMediaEditorShouldApply(initialValues: values, finalValues: values))
        let touchedBack = values.withUpdatedToolValues([.brightness: Float(0.0)])
        XCTAssertFalse(wallpaperMediaEditorHasChanges(touchedBack))
        XCTAssertFalse(wallpaperMediaEditorShouldApply(initialValues: values, finalValues: touchedBack))
    }

    func testToolChangeIsChange() {
        let values = wallpaperMediaEditorInitialValues(previousState: nil, dimensions: self.dimensions)
        let brightness = values.withUpdatedToolValues([.brightness: Float(0.4)])
        XCTAssertTrue(wallpaperMediaEditorHasChanges(brightness))
        XCTAssertTrue(wallpaperMediaEditorShouldApply(initialValues: values, finalValues: brightness))
        let curves = values.withUpdatedToolValues([.curves: CurvesValue.initial.withUpdatedAll(CurvesValue.CurveValue(blacks: 0.2, shadows: 0.25, midtones: 0.5, highlights: 0.75, whites: 1.0))])
        XCTAssertTrue(wallpaperMediaEditorHasChanges(curves))
        let tint = values.withUpdatedToolValues([.shadowsTint: TintValue(color: .red, intensity: 0.5)])
        XCTAssertTrue(wallpaperMediaEditorHasChanges(tint))
    }

    func testReentryRestoresToolValues() {
        let first = wallpaperMediaEditorInitialValues(previousState: nil, dimensions: self.dimensions)
        let edited = first.withUpdatedToolValues([.brightness: Float(0.4), .grain: Float(0.2)])
        let state = wallpaperMediaEditorState(values: edited)
        let reentered = wallpaperMediaEditorInitialValues(previousState: state, dimensions: self.dimensions)
        XCTAssertEqual(reentered, edited)
        XCTAssertEqual(reentered.toolValues[.brightness] as? Float, 0.4)
        XCTAssertEqual(reentered.toolValues[.grain] as? Float, 0.2)
        XCTAssertTrue(wallpaperMediaEditorHasChanges(reentered))
        XCTAssertFalse(wallpaperMediaEditorShouldApply(initialValues: reentered, finalValues: reentered))

        let reset = reentered.withUpdatedToolValues([:])
        XCTAssertFalse(wallpaperMediaEditorHasChanges(reset))
        XCTAssertTrue(wallpaperMediaEditorShouldApply(initialValues: reentered, finalValues: reset))

        let loaded = reentered.withUpdatedGradientColors(gradientColors: [.red, .blue])
        XCTAssertFalse(wallpaperMediaEditorShouldApply(initialValues: reentered, finalValues: loaded))
        XCTAssertTrue(wallpaperMediaEditorShouldApply(initialValues: reentered, finalValues: loaded.withUpdatedToolValues([.brightness: Float(0.4), .grain: Float(0.2), .contrast: Float(-0.7)])))

        let foreign = wallpaperMediaEditorInitialValues(previousState: NSObject(), dimensions: self.dimensions)
        XCTAssertTrue(foreign.toolValues.isEmpty)
    }

    func testReferenceImageFrameMapsCropToReference() {
        let frame = wallpaperMediaEditorReferenceImageFrame(referenceFrame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 844.0), cropRect: CGRect(x: 100.0, y: 200.0, width: 1170.0, height: 2532.0), imageSize: CGSize(width: 1500.0, height: 3000.0))
        XCTAssertEqual(frame.minX, -100.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(frame.minY, -200.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(frame.width, 500.0, accuracy: 0.001)
        XCTAssertEqual(frame.height, 1000.0, accuracy: 0.001)
    }

    func testFullSizeIsFittedLikeLegacy() {
        XCTAssertEqual(wallpaperMediaEditorFullSizeTarget(dimensions: PixelDimensions(width: 4032, height: 3024)), CGSize(width: 2048.0, height: 1536.0))
        XCTAssertEqual(wallpaperMediaEditorFullSizeTarget(dimensions: PixelDimensions(width: 1000, height: 800)), CGSize(width: 1000.0, height: 800.0))
    }

    func testDeliveryOrderAndCancelAppliesNothing() {
        let full = UIImage()
        XCTAssertEqual(wallpaperMediaEditorDeliveries(shouldApply: false, fullSize: .rendered(full)), [])
        XCTAssertEqual(wallpaperMediaEditorDeliveries(shouldApply: false, fullSize: .notNeeded), [])
        XCTAssertEqual(wallpaperMediaEditorDeliveries(shouldApply: true, fullSize: .rendered(full)), [.fullSizeApply(full), .apply])
        XCTAssertEqual(wallpaperMediaEditorDeliveries(shouldApply: true, fullSize: .notNeeded), [.fullSizeApply(nil), .apply])
    }

    func testUnavailableFullSizeAppliesNothing() {
        XCTAssertEqual(wallpaperMediaEditorDeliveries(shouldApply: true, fullSize: .unavailable), [])
    }

    func testNormalizedImageIsUprightScaleOnePixels() {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3.0
        let scaled = UIGraphicsImageRenderer(size: CGSize(width: 100.0, height: 50.0), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0.0, y: 0.0, width: 100.0, height: 50.0))
        }
        let normalized = wallpaperMediaEditorNormalizedImage(scaled, maxPixelSide: nil)
        XCTAssertEqual(normalized.scale, 1.0)
        XCTAssertEqual(normalized.size, CGSize(width: 300.0, height: 150.0))
        XCTAssertEqual(normalized.imageOrientation, .up)

        let rotated = UIImage(cgImage: normalized.cgImage!, scale: 1.0, orientation: .right)
        let upright = wallpaperMediaEditorNormalizedImage(rotated, maxPixelSide: nil)
        XCTAssertEqual(upright.imageOrientation, .up)
        XCTAssertEqual(upright.size, CGSize(width: 150.0, height: 300.0))
        XCTAssertEqual(upright.cgImage?.width, 150)

        let fitted = wallpaperMediaEditorNormalizedImage(normalized, maxPixelSide: 120.0)
        XCTAssertEqual(fitted.size, CGSize(width: 120.0, height: 60.0))
        XCTAssertEqual(fitted.scale, 1.0)

        XCTAssertTrue(wallpaperMediaEditorNormalizedImage(normalized, maxPixelSide: 2048.0) === normalized)
    }
}
