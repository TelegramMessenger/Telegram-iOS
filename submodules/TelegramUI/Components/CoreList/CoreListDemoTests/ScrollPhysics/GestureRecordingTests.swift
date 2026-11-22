import XCTest
import CoreGraphics
@testable import CoreListDemo

final class GestureRecordingTests: XCTestCase {
    private func sample() -> GestureRecording {
        GestureRecording(
            name: "unit",
            geometry: .init(contentWidth: 320, contentHeight: 2000,
                            boundsWidth: 320, boundsHeight: 800,
                            insetTop: 0, insetLeft: 0, insetBottom: 0, insetRight: 0,
                            scale: 2, decelerationRate: 0.998),
            frames: [
                .init(t: 0.0, phase: .dragging, translation: CGPoint(x: 0, y: -10),
                      recognizerVelocity: CGPoint(x: 0, y: -1000), groundTruthOffset: CGPoint(x: 5, y: 10)),
                .init(t: 0.016, phase: .decelerating, translation: .zero,
                      recognizerVelocity: .zero, groundTruthOffset: CGPoint(x: 0, y: 26)),
            ],
            rubberBandSamples: [
                .init(offset: -20, min: 0, max: 1200, range: 800, out: -10.7056),
            ],
            touches: [
                .init(t: 0.0, centroid: CGPoint(x: 100, y: 400), phase: .began,
                      translation: .zero, velocity: .zero, state: 1),
                .init(t: 0.016, centroid: CGPoint(x: 100, y: 390), phase: .moved,
                      translation: CGPoint(x: 0, y: -10), velocity: CGPoint(x: 0, y: -625), state: 2),
            ],
            releaseTime: 0.0125)
    }

    func testCodableRoundTrip() throws {
        let original = sample()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GestureRecording.self, from: data)
        XCTAssertEqual(decoded.name, "unit")
        XCTAssertEqual(decoded.geometry.decelerationRate, 0.998, accuracy: 1e-12)
        XCTAssertEqual(decoded.frames.count, 2)
        XCTAssertEqual(decoded.frames[1].phase, .decelerating)
        // exercise both CGPoint components and both drag-input fields through the codec
        XCTAssertEqual(decoded.frames[0].groundTruthOffset.x, 5, accuracy: 1e-12)
        XCTAssertEqual(decoded.frames[0].groundTruthOffset.y, 10, accuracy: 1e-12)
        XCTAssertEqual(decoded.frames[0].translation.y, -10, accuracy: 1e-12)
        XCTAssertEqual(decoded.frames[0].recognizerVelocity.y, -1000, accuracy: 1e-12)
        let rb = try XCTUnwrap(decoded.rubberBandSamples.first)
        XCTAssertEqual(rb.out, -10.7056, accuracy: 1e-4)
        XCTAssertEqual(try XCTUnwrap(decoded.releaseTime), 0.0125, accuracy: 1e-12)
        XCTAssertEqual(decoded.touches.count, 2)
        XCTAssertEqual(decoded.touches[1].phase, .moved)
        XCTAssertEqual(decoded.touches[1].centroid.y, 390, accuracy: 1e-12)
        XCTAssertEqual(decoded.touches[1].velocity.y, -625, accuracy: 1e-12)
        XCTAssertEqual(decoded.touches[0].state, 1)
    }

    func testOlderFixturesWithoutTouchesOrReleaseTimeStillDecode() throws {
        let json = #"{"name":"old","geometry":{"contentWidth":0,"contentHeight":0,"boundsWidth":0,"boundsHeight":0,"insetTop":0,"insetLeft":0,"insetBottom":0,"insetRight":0,"scale":2,"decelerationRate":0.998},"frames":[],"rubberBandSamples":[]}"#
        let decoded = try JSONDecoder().decode(GestureRecording.self, from: Data(json.utf8))
        XCTAssertNil(decoded.releaseTime)   // backward-compatible
        XCTAssertTrue(decoded.touches.isEmpty)
    }
}
