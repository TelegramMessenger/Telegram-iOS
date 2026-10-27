import Foundation
import UIKit
import CoreMedia
import XCTest
import TelegramCore
@testable import MediaEditor

private let cropTestPeerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))

private func rotatedSize(_ size: CGSize, rotation: CGFloat) -> CGSize {
    var transform = CGAffineTransform(translationX: size.width / 2.0, y: size.height / 2.0)
    transform = transform.rotated(by: rotation)
    transform = transform.translatedBy(x: -size.width / 2.0, y: -size.height / 2.0)
    return CGRect(origin: .zero, size: size).applying(transform).size
}

final class ChatMediaEditorCropCompositionTests: XCTestCase {
    private func baseValues(width: Int32 = 400, height: Int32 = 300) -> MediaEditorValues {
        return chatMediaEditorValues(peerId: cropTestPeerId, originalDimensions: PixelDimensions(width: width, height: height), qualityPreset: .compressedHigh)
    }

    func testExportScaleForTightCrop() {
        let values = self.baseValues(width: 4032, height: 3024)
        let tight = values.withUpdatedCrop(rect: CGRect(x: 0.0, y: 0.0, width: 1008.0, height: 756.0), rotation: 0.0, orientation: nil, mirroring: false, perspective: .zero)
        XCTAssertEqual(mediaEditorChatExportScale(values: tight, maxOutputSide: 1280.0), 1008.0 / (1920.0 * 1008.0 / 4032.0), accuracy: 0.01)
        XCTAssertEqual(mediaEditorChatExportScale(values: values, maxOutputSide: 1280.0), 1.0, accuracy: 0.0001)
        XCTAssertEqual(mediaEditorChatExportScale(values: values, maxOutputSide: 2560.0), 2560.0 / 1920.0, accuracy: 0.01)
        let medium = values.withUpdatedCrop(rect: CGRect(x: 0.0, y: 0.0, width: 2016.0, height: 1512.0), rotation: 0.0, orientation: nil, mirroring: false, perspective: .zero)
        XCTAssertEqual(mediaEditorChatExportScale(values: medium, maxOutputSide: 1280.0), 1280.0 / 960.0, accuracy: 0.01)
        XCTAssertEqual(mediaEditorChatExportScale(values: medium, maxOutputSide: 2560.0), 2016.0 / 960.0, accuracy: 0.01)
    }

    func testCropGeometryUnrotatedMatchesLegacyFormula() {
        let values = self.baseValues().withUpdatedCrop(rect: CGRect(x: 0.0, y: 0.0, width: 200.0, height: 150.0), rotation: 0.0, orientation: nil, mirroring: false, perspective: .zero)
        let canvas = mediaEditorNonStoryCanvasSize(originalDimensions: values.originalDimensions)
        let rect = mediaEditorNonStoryScaledCropRect(values: values, dimensions: canvas)
        XCTAssertEqual(rect, CGRect(x: 0.0, y: canvas.height - 150.0 * canvas.width / 400.0, width: canvas.width / 2.0, height: 150.0 * canvas.width / 400.0))
        let full = mediaEditorNonStoryScaledCropRect(values: self.baseValues(), dimensions: canvas)
        XCTAssertEqual(full, CGRect(x: 0.0, y: canvas.height - 300.0 * canvas.width / 400.0, width: canvas.width, height: 300.0 * canvas.width / 400.0))
    }

    func testChatCropSnapsInwardToComposedPixels() {
        let values = self.baseValues().withUpdatedCrop(rect: CGRect(x: 10.3, y: 20.7, width: 150.45, height: 101.2), rotation: 0.21, orientation: .left, mirroring: true, perspective: .zero)
        let dimensions = CGSize(width: 1234.5, height: 925.875)
        let original = mediaEditorNonStoryScaledCropRect(values: values, dimensions: dimensions)
        let aligned = mediaEditorChatPixelAlignedValues(values, dimensions: dimensions)
        let snapped = mediaEditorNonStoryScaledCropRect(values: aligned, dimensions: dimensions)
        for value in [snapped.minX, snapped.minY, snapped.maxX, snapped.maxY] {
            XCTAssertEqual(value, value.rounded(), accuracy: 0.0001)
        }
        XCTAssertGreaterThanOrEqual(snapped.minX, original.minX - 0.0001)
        XCTAssertGreaterThanOrEqual(snapped.minY, original.minY - 0.0001)
        XCTAssertLessThanOrEqual(snapped.maxX, original.maxX + 0.0001)
        XCTAssertLessThanOrEqual(snapped.maxY, original.maxY + 0.0001)
        XCTAssertLessThan(original.width - snapped.width, 2.0)
        XCTAssertLessThan(original.height - snapped.height, 2.0)
        XCTAssertEqual(aligned.cropRotation, values.cropRotation)
        XCTAssertEqual(aligned.cropOrientation, values.cropOrientation)
        XCTAssertEqual(aligned.cropMirroring, values.cropMirroring)
    }

    func testOrientationTransformKeepsRotationSense() {
        let size = CGSize(width: 400.0, height: 300.0)
        for orientation in [MediaCropOrientation.left, .right, .down] {
            let rotatedSize = orientation.isSideward ? CGSize(width: size.height, height: size.width) : size
            let reference = CGAffineTransform(translationX: -size.width / 2.0, y: -size.height / 2.0)
                .concatenating(CGAffineTransform(rotationAngle: orientation.rotation))
                .concatenating(CGAffineTransform(translationX: rotatedSize.width / 2.0, y: rotatedSize.height / 2.0))
            let exact = mediaEditorOrientationTransform(orientation, size: size)
            for point in [CGPoint(x: 0.0, y: 0.0), CGPoint(x: 400.0, y: 0.0), CGPoint(x: 0.0, y: 300.0), CGPoint(x: 400.0, y: 300.0), CGPoint(x: 37.0, y: 211.0)] {
                let expected = point.applying(reference)
                let actual = point.applying(exact)
                XCTAssertEqual(actual.x, expected.x, accuracy: 0.000001, "\(orientation) \(point)")
                XCTAssertEqual(actual.y, expected.y, accuracy: 0.000001, "\(orientation) \(point)")
            }
            XCTAssertEqual(CGRect(origin: .zero, size: size).applying(exact), CGRect(origin: .zero, size: rotatedSize))
        }
    }

    func testOrientedOddCropExtentsAreExact() {
        let original = CGSize(width: 1920.0, height: 1440.0)
        let canvas = mediaEditorNonStoryCanvasSize(originalDimensions: PixelDimensions(width: 1920, height: 1440))
        XCTAssertEqual(canvas, original)
        let cropRect = CGRect(x: 101.0, y: 77.0, width: 715.0, height: 551.0)
        let expected: [(MediaCropOrientation, CGSize)] = [
            (.up, CGSize(width: 715.0, height: 551.0)),
            (.left, CGSize(width: 551.0, height: 715.0)),
            (.right, CGSize(width: 551.0, height: 715.0)),
            (.down, CGSize(width: 715.0, height: 551.0))
        ]
        for (orientation, size) in expected {
            let values = self.baseValues(width: 1920, height: 1440).withUpdatedCrop(rect: cropRect, rotation: 0.0, orientation: orientation, mirroring: false, perspective: .zero)
            let resultSize = mediaEditorCompositionResultSize(dimensions: canvas, outputDimensions: nil, values: values)
            XCTAssertEqual(resultSize, size, "\(orientation)")
            XCTAssertEqual(mediaEditorChatOutputRect(extent: CGRect(origin: .zero, size: resultSize)), CGRect(origin: .zero, size: size), "\(orientation)")
        }
    }

    func testCropFollowsMediaPlacementOnUnalignedCanvas() {
        let originalDimensions = PixelDimensions(width: 1179, height: 2556)
        let original = originalDimensions.cgSize
        let canvas = mediaEditorNonStoryCanvasSize(originalDimensions: originalDimensions)
        let exportScale: CGFloat = 2.5
        let dimensions = CGSize(width: canvas.width * exportScale, height: canvas.height * exportScale)
        let mediaHeight = original.height * dimensions.width / original.width
        let mediaRect = CGRect(x: 0.0, y: (dimensions.height - mediaHeight) / 2.0, width: dimensions.width, height: mediaHeight)
        XCTAssertGreaterThan(abs(mediaHeight - dimensions.height), 1.0)
        XCTAssertEqual(mediaEditorNonStoryMediaRect(originalDimensions: original, dimensions: dimensions), mediaRect)

        let values = self.baseValues(width: 1179, height: 2556)
        let full = mediaEditorNonStoryScaledCropRect(values: values, dimensions: dimensions)
        XCTAssertEqual(full.minX, mediaRect.minX, accuracy: 0.0001)
        XCTAssertEqual(full.minY, mediaRect.minY, accuracy: 0.0001)
        XCTAssertEqual(full.maxX, mediaRect.maxX, accuracy: 0.0001)
        XCTAssertEqual(full.maxY, mediaRect.maxY, accuracy: 0.0001)

        let bottom = values.withUpdatedCrop(rect: CGRect(x: 0.0, y: original.height - 600.0, width: original.width, height: 600.0), rotation: 0.0, orientation: nil, mirroring: false, perspective: .zero)
        let scaledBottom = mediaEditorNonStoryScaledCropRect(values: bottom, dimensions: dimensions)
        XCTAssertEqual(scaledBottom.minY, mediaRect.minY, accuracy: 0.0001)
        let snapped = mediaEditorNonStoryScaledCropRect(values: mediaEditorChatPixelAlignedValues(bottom, dimensions: dimensions), dimensions: dimensions)
        XCTAssertGreaterThanOrEqual(snapped.minY, mediaRect.minY - 0.0001)
        XCTAssertLessThan(snapped.minY - mediaRect.minY, 1.0)
        XCTAssertEqual(snapped.height, snapped.height.rounded(), accuracy: 0.0001)

        let top = values.withUpdatedCrop(rect: CGRect(x: 0.0, y: 0.0, width: original.width, height: 600.0), rotation: 0.0, orientation: nil, mirroring: false, perspective: .zero)
        XCTAssertEqual(mediaEditorNonStoryScaledCropRect(values: top, dimensions: dimensions).maxY, mediaRect.maxY, accuracy: 0.0001)
    }

    func testCropGeometryRotatedCenteredCropStaysInsideRotatedImage() {
        let original = CGSize(width: 400.0, height: 300.0)
        let rotation: CGFloat = 12.0 * .pi / 180.0
        let rotated = rotatedSize(original, rotation: rotation)
        let cropSize = CGSize(width: 300.0, height: 225.0)
        let cropRect = CGRect(x: (rotated.width - cropSize.width) / 2.0, y: (rotated.height - cropSize.height) / 2.0, width: cropSize.width, height: cropSize.height)
        let values = self.baseValues().withUpdatedCrop(rect: cropRect, rotation: rotation, orientation: .left, mirroring: false, perspective: .zero)
        let canvas = mediaEditorNonStoryCanvasSize(originalDimensions: values.originalDimensions)
        let scale = canvas.width / original.width
        let rect = mediaEditorNonStoryScaledCropRect(values: values, dimensions: canvas)
        XCTAssertEqual(rect.midX, canvas.width / 2.0, accuracy: 0.001)
        XCTAssertEqual(rect.midY, original.height * scale / 2.0 + (canvas.height - original.height * scale), accuracy: 0.001)
        XCTAssertEqual(rect.width, cropSize.width * scale, accuracy: 0.001)
        XCTAssertEqual(rect.height, cropSize.height * scale, accuracy: 0.001)

        let center = CGPoint(x: canvas.width / 2.0, y: canvas.height / 2.0)
        let toContent = CGAffineTransform(translationX: -center.x, y: -center.y).concatenating(CGAffineTransform(rotationAngle: rotation)).concatenating(CGAffineTransform(translationX: center.x, y: center.y))
        let contentBox = CGRect(x: 0.0, y: canvas.height - original.height * scale, width: canvas.width, height: original.height * scale)
        for corner in [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)] {
            let content = corner.applying(toContent)
            XCTAssertTrue(contentBox.insetBy(dx: -0.001, dy: -0.001).contains(content), "corner \(corner) maps to \(content), outside \(contentBox)")
        }

        let topCenter = CGPoint(x: rect.midX, y: rect.maxY - 10.0 * scale)
        XCTAssertLessThan(topCenter.applying(toContent).x, center.x)
    }
}
