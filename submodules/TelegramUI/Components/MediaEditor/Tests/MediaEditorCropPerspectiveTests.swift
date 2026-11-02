import Foundation
import UIKit
import XCTest
import TelegramCore
import MediaEditor

private let perspectiveTestSize = CGSize(width: 400.0, height: 300.0)

private func perspectiveTestHomography(vertical: CGFloat, horizontal: CGFloat, size: CGSize = perspectiveTestSize) -> MediaEditorPerspectiveHomography {
    return MediaEditorPerspectiveHomography(perspective: MediaEditorCropPerspective(vertical: vertical, horizontal: horizontal), size: size)
}

private func perspectiveTestDistance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
    return hypot(lhs.x - rhs.x, lhs.y - rhs.y)
}

private func perspectiveTestApplyLayerTransform(_ transform: CATransform3D, _ point: CGPoint) -> CGPoint {
    let x = point.x * transform.m11 + point.y * transform.m21 + transform.m41
    let y = point.x * transform.m12 + point.y * transform.m22 + transform.m42
    let w = point.x * transform.m14 + point.y * transform.m24 + transform.m44
    return CGPoint(x: x / w, y: y / w)
}

final class MediaEditorCropPerspectiveTests: XCTestCase {
    func testZeroIsIdentity() {
        let homography = perspectiveTestHomography(vertical: 0.0, horizontal: 0.0)
        let point = homography.apply(CGPoint(x: 123.0, y: -45.0))
        XCTAssertEqual(point.x, 123.0, accuracy: 1e-9)
        XCTAssertEqual(point.y, -45.0, accuracy: 1e-9)
        XCTAssertTrue(MediaEditorCropPerspective.zero.isZero)
        XCTAssertFalse(MediaEditorCropPerspective(vertical: 0.01, horizontal: 0.0).isZero)
    }

    func testCentreIsFixed() {
        for (vertical, horizontal) in [(0.3, 0.0), (0.0, -0.4), (-0.2, 0.25)] as [(CGFloat, CGFloat)] {
            let center = perspectiveTestHomography(vertical: vertical, horizontal: horizontal).apply(.zero)
            XCTAssertEqual(center.x, 0.0, accuracy: 1e-9)
            XCTAssertEqual(center.y, 0.0, accuracy: 1e-9)
        }
    }

    func testPositiveVerticalNarrowsTop() {
        let quad = perspectiveTestHomography(vertical: 0.3, horizontal: 0.0).quad(size: perspectiveTestSize)
        XCTAssertLessThan(quad[1].x - quad[0].x, quad[2].x - quad[3].x)
        XCTAssertEqual(quad[0].x, -quad[1].x, accuracy: 1e-6)
        XCTAssertEqual(quad[3].x, -quad[2].x, accuracy: 1e-6)
        XCTAssertEqual(quad[0].y, quad[1].y, accuracy: 1e-6)
    }

    func testPositiveHorizontalNarrowsLeft() {
        let quad = perspectiveTestHomography(vertical: 0.0, horizontal: 0.3).quad(size: perspectiveTestSize)
        XCTAssertLessThan(quad[3].y - quad[0].y, quad[2].y - quad[1].y)
        XCTAssertEqual(quad[0].y, -quad[3].y, accuracy: 1e-6)
        XCTAssertEqual(quad[1].y, -quad[2].y, accuracy: 1e-6)
        XCTAssertEqual(quad[0].x, quad[3].x, accuracy: 1e-6)
    }

    func testWarpKeepsArea() {
        let quad = perspectiveTestHomography(vertical: 0.35, horizontal: -0.2).quad(size: perspectiveTestSize)
        var area: CGFloat = 0.0
        for index in 0 ..< 4 {
            let a = quad[index]
            let b = quad[(index + 1) % 4]
            area += a.x * b.y - b.x * a.y
        }
        XCTAssertEqual(abs(area) / 2.0, perspectiveTestSize.width * perspectiveTestSize.height, accuracy: perspectiveTestSize.width * perspectiveTestSize.height * 1e-6)
    }

    func testInverseRoundTrips() {
        let homography = perspectiveTestHomography(vertical: 0.2, horizontal: -0.25)
        for point in [CGPoint(x: 0.0, y: 0.0), CGPoint(x: 150.0, y: -90.0), CGPoint(x: -200.0, y: 150.0), CGPoint(x: 37.0, y: 12.0)] {
            let roundTrip = homography.apply(homography.inverse.apply(point))
            XCTAssertLessThan(perspectiveTestDistance(roundTrip, point), 1e-6)
        }
    }

    func testTransform3DMatchesApply() {
        let homography = perspectiveTestHomography(vertical: -0.3, horizontal: 0.2)
        let transform = homography.transform3D()
        for point in [CGPoint(x: -200.0, y: -150.0), CGPoint(x: 200.0, y: -150.0), CGPoint(x: 50.0, y: 75.0), CGPoint(x: -120.0, y: 140.0)] {
            XCTAssertLessThan(perspectiveTestDistance(perspectiveTestApplyLayerTransform(transform, point), homography.apply(point)), 1e-6)
        }
    }

    func testWarpedQuadIsConvexAtLimits() {
        let limit = mediaEditorCropMaximumPerspectiveAngle * .pi / 180.0
        for vertical in [-limit, limit] {
            for horizontal in [-limit, limit] {
                let quad = perspectiveTestHomography(vertical: vertical, horizontal: horizontal).quad(size: perspectiveTestSize)
                var signs: [Bool] = []
                for index in 0 ..< 4 {
                    let a = quad[index]
                    let b = quad[(index + 1) % 4]
                    let c = quad[(index + 2) % 4]
                    let first: CGFloat = (b.x - a.x) * (c.y - b.y)
                    let second: CGFloat = (b.y - a.y) * (c.x - b.x)
                    let cross = first - second
                    XCTAssertGreaterThan(abs(cross), 1e-6)
                    signs.append(cross > 0.0)
                }
                XCTAssertEqual(Set(signs).count, 1)
            }
        }
    }

    func testCodableRoundTrip() throws {
        let value = MediaEditorCropPerspective(vertical: 0.12, horizontal: -0.34)
        let data = try JSONEncoder().encode(value)
        XCTAssertEqual(try JSONDecoder().decode(MediaEditorCropPerspective.self, from: data), value)
    }

    private func valuesForPerspectiveTests() -> MediaEditorValues {
        let peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))
        return chatMediaEditorValues(peerId: peerId, originalDimensions: PixelDimensions(width: 400, height: 300), qualityPreset: .compressedHigh)
    }

    func testValuesWithoutPerspectiveKeyDecodeToZero() throws {
        let values = self.valuesForPerspectiveTests().withUpdatedCrop(rect: nil, rotation: 0.1, orientation: nil, mirroring: false, perspective: MediaEditorCropPerspective(vertical: 0.2, horizontal: 0.1))
        var dictionary = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(values)) as? [String: Any])
        XCTAssertNotNil(dictionary["cropPerspective"])
        dictionary.removeValue(forKey: "cropPerspective")
        let decoded = try JSONDecoder().decode(MediaEditorValues.self, from: JSONSerialization.data(withJSONObject: dictionary))
        XCTAssertEqual(decoded.cropPerspective, .zero)
        XCTAssertEqual(decoded.cropRotation, 0.1, accuracy: 1e-9)
    }

    func testZeroPerspectiveIsNotEncoded() throws {
        let values = self.valuesForPerspectiveTests()
        let dictionary = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(values)) as? [String: Any])
        XCTAssertNil(dictionary["cropPerspective"])
    }

    func testValuesPerspectiveRoundTrips() throws {
        let perspective = MediaEditorCropPerspective(vertical: 0.1, horizontal: -0.2)
        let values = self.valuesForPerspectiveTests().withUpdatedCrop(rect: nil, rotation: 0.0, orientation: .left, mirroring: true, perspective: perspective)
        let decoded = try JSONDecoder().decode(MediaEditorValues.self, from: JSONEncoder().encode(values))
        XCTAssertEqual(decoded.cropPerspective, perspective)
        XCTAssertEqual(decoded, values)
        XCTAssertNotEqual(values, values.withUpdatedCrop(rect: nil, rotation: 0.0, orientation: .left, mirroring: true, perspective: .zero))
    }

    func testPerspectiveSurvivesUnrelatedWithCopies() {
        let perspective = MediaEditorCropPerspective(vertical: -0.15, horizontal: 0.05)
        let values = self.valuesForPerspectiveTests()
            .withUpdatedCrop(rect: nil, rotation: 0.0, orientation: nil, mirroring: false, perspective: perspective)
            .withUpdatedVideoIsMuted(true)
            .withUpdatedQualityPreset(.compressedMedium)
        XCTAssertEqual(values.cropPerspective, perspective)
    }
}
