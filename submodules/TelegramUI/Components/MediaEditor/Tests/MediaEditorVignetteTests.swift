import Foundation
import XCTest
import TelegramCore
@testable import MediaEditor
@testable import MediaEditorExportTestSupport

final class MediaEditorVignetteCodingTests: XCTestCase {
    private func values(vignette: Float?) -> MediaEditorValues {
        let base = chatMediaEditorValues(peerId: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1)), originalDimensions: PixelDimensions(width: 1000, height: 800), qualityPreset: .compressedHigh)
        if let vignette {
            return base.withUpdatedToolValues([.vignette: vignette])
        }
        return base
    }

    func testVignetteValuesSurviveCoding() throws {
        for value: Float in [-1.0, -0.37, -0.01, 0.42, 1.0] {
            let data = try JSONEncoder().encode(self.values(vignette: value))
            let decoded = try JSONDecoder().decode(MediaEditorValues.self, from: data)
            XCTAssertEqual(decoded.toolValues[.vignette] as? Float, value)
        }
    }

    func testAnyNonZeroVignetteIsAnAdjustment() {
        XCTAssertFalse(self.values(vignette: nil).hasAdjustments)
        XCTAssertFalse(self.values(vignette: 0.0).hasAdjustments)
        XCTAssertTrue(self.values(vignette: 0.3).hasAdjustments)
        XCTAssertTrue(self.values(vignette: -0.3).hasAdjustments)
        XCTAssertTrue(self.values(vignette: -1.0).hasAdjustments)
    }

    func testVignetteSliderIsCentred() {
        let range = mediaEditorAdjustmentToolRange(.vignette)
        XCTAssertEqual(range.minValue, -1.0)
        XCTAssertEqual(range.maxValue, 1.0)
        XCTAssertEqual(range.startValue, 0.0)
    }
}

final class MediaEditorVignetteRenderTests: XCTestCase {
    private func run(_ name: String) {
        let result = MediaEditorVignetteSuite().run(name)
        for measurement in result.measurements {
            print("\(name): \(measurement)")
        }
        for failure in result.failures {
            XCTFail(failure)
        }
    }

    func testPositiveVignetteIsUnchanged() {
        self.run("testPositiveVignetteIsUnchanged")
    }

    func testZeroVignetteIsIdentity() {
        self.run("testZeroVignetteIsIdentity")
    }

    func testNegativeVignetteLightensEdges() {
        self.run("testNegativeVignetteLightensEdges")
    }

    func testNegativeVignetteMirrorsPositive() {
        self.run("testNegativeVignetteMirrorsPositive")
    }
}
