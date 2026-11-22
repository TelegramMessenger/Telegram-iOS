import Foundation
import XCTest
@testable import MediaEditorExportTestSupport

final class MediaEditorExportTests: XCTestCase {
    private func makeSuite() throws -> MediaEditorExportSuite {
        self.continueAfterFailure = true
        return try XCTUnwrap(MediaEditorExportSuite(), "cannot open a temporary Postbox")
    }

    func testBenchmark() throws {
        let suite = try self.makeSuite()
        suite.runBenchmark()
        for failure in suite.failures {
            XCTFail(failure)
        }
    }

    func testExport() throws {
        let suite = try self.makeSuite()
        suite.runExport()
        for failure in suite.failures {
            XCTFail(failure)
        }
    }

    func testStreamingWriterVariableFrameRate() throws {
        let suite = try self.makeSuite()
        suite.runExport(scenarios: mediaEditorStreamingWriterExportScenarios)
        for failure in suite.failures {
            XCTFail(failure)
        }
    }
}

final class MediaEditorFrameCompositorTests: XCTestCase {
    private func run(_ name: String) throws {
        let suite = try XCTUnwrap(MediaEditorFrameCompositorSuite(), "no Metal device or compositor")
        let result = suite.run(name)
        for measurement in result.measurements {
            print("\(name): \(measurement)")
        }
        for failure in result.failures {
            XCTFail(failure)
        }
    }

    func testIdentityLayerMatchesSource() throws {
        try self.run("testIdentityLayerMatchesSource")
    }

    func testRotatedScaledLayerMatchesCoreImage() throws {
        try self.run("testRotatedScaledLayerMatchesCoreImage")
    }

    func testLayerSampledOutsideTextureIsTransparent() throws {
        try self.run("testLayerSampledOutsideTextureIsTransparent")
    }

    func testLayerOutsideOutputIsClipped() throws {
        try self.run("testLayerOutsideOutputIsClipped")
    }

    func testAlphaMaskMatchesBlendWithAlphaMask() throws {
        try self.run("testAlphaMaskMatchesBlendWithAlphaMask")
    }

    func testFinalMaskMatchesBlendWithMask() throws {
        try self.run("testFinalMaskMatchesBlendWithMask")
    }

    func testBottomLeftOriginLayerIsFlipped() throws {
        try self.run("testBottomLeftOriginLayerIsFlipped")
    }

    func testYuvPixelBufferTextureMatchesCoreImage() throws {
        try self.run("testYuvPixelBufferTextureMatchesCoreImage")
    }
}

final class MediaEditorComposerEntityFrameTests: XCTestCase {
    private func run(_ name: String) throws {
        let suite = try XCTUnwrap(MediaEditorComposerEntityFrameSuite(), "no Metal device, compositor or Postbox")
        let result = suite.run(name)
        for measurement in result.measurements {
            print("\(name): \(measurement)")
        }
        for failure in result.failures {
            XCTFail(failure)
        }
    }

    func testStaticImageFrameMatchesPreview() throws {
        try self.run("testStaticImageFrameMatchesPreview")
    }

    func testAnimatedImageFrameMatchesPreview() throws {
        try self.run("testAnimatedImageFrameMatchesPreview")
    }

    func testLottieFrameMatchesPreview() throws {
        try self.run("testLottieFrameMatchesPreview")
    }

    func testTintedLottieFrameMatchesPreview() throws {
        try self.run("testTintedLottieFrameMatchesPreview")
    }

    func testVideoStickerFrameMatchesPreview() throws {
        try self.run("testVideoStickerFrameMatchesPreview")
    }

    func testVideoFrameWithMaskMatchesPreview() throws {
        try self.run("testVideoFrameWithMaskMatchesPreview")
    }

    func testPixelBufferColorConversionPaths() throws {
        try self.run("testPixelBufferColorConversionPaths")
    }
}

final class MediaEditorComposerTests: XCTestCase {
    private func run(_ name: String) {
        let result = MediaEditorComposerSuite().run(name)
        for measurement in result.measurements {
            print("\(name): \(measurement)")
        }
        for failure in result.failures {
            XCTFail(failure)
        }
    }

    func testNilEntityFrameStillCompletesFrame() {
        self.run("testNilEntityFrameStillCompletesFrame")
    }

    func testCompositionUsesNoCoreImage() {
        self.run("testCompositionUsesNoCoreImage")
    }
}

final class MediaEditorPhotoCompositionTests: XCTestCase {
    private func run(_ name: String) {
        let result = MediaEditorPhotoCompositionSuite().run(name)
        for measurement in result.measurements {
            print("\(name): \(measurement)")
        }
        for failure in result.failures {
            XCTFail(failure)
        }
    }

    func testReadbackMatchesCoreImage() {
        self.run("testReadbackMatchesCoreImage")
    }

    func testPanoramaPhotoComposes() {
        self.run("testPanoramaPhotoComposes")
    }

    func testOversizedPhotoIsDownscaledBeforeUpload() {
        self.run("testOversizedPhotoIsDownscaledBeforeUpload")
    }

    func testEditorResultMatchesImageInput() {
        self.run("testEditorResultMatchesImageInput")
    }

    func testIdentityUnchanged() {
        self.run("testIdentityUnchanged")
    }

    func testCropRectTopLeftQuadrant() {
        self.run("testCropRectTopLeftQuadrant")
    }

    func testOrientationLeft() {
        self.run("testOrientationLeft")
    }

    func testMirrorFlipsMediaOnly() {
        self.run("testMirrorFlipsMediaOnly")
    }

    func testRotatedCropOrientedPixels() {
        self.run("testRotatedCropOrientedPixels")
    }

    func testChatCompositionRendersTightCropFromSourcePixels() {
        self.run("testChatCompositionRendersTightCropFromSourcePixels")
    }

    func testOrientedOddCropEdgesAreOpaque() {
        self.run("testOrientedOddCropEdgesAreOpaque")
    }
}
