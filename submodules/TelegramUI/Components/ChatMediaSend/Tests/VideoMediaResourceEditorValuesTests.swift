import Foundation
import UIKit
import XCTest
import TelegramCore
import LegacyComponents
import LocalMediaResources
import MediaEditor
import FetchVideoMediaResource

private let testPeerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))

final class VideoMediaResourceEditorValuesTests: XCTestCase {
    private func jsonAdjustments(isStory: Bool) throws -> VideoMediaResourceAdjustments {
        var values = chatMediaEditorValues(peerId: testPeerId, originalDimensions: PixelDimensions(width: 400, height: 300), qualityPreset: .compressedVeryHigh)
        values = values.withUpdatedVideoTrimRange(2.0 ..< 5.0)
        let data = EngineMemoryBuffer(data: try JSONEncoder().encode(values))
        return VideoMediaResourceAdjustments(data: data, digest: EngineMemoryBuffer(data: Data(count: 16)), isStory: isStory)
    }

    private func legacyAdjustments() throws -> VideoMediaResourceAdjustments {
        let adjustments = TGVideoEditAdjustments(originalSize: CGSize(width: 400.0, height: 300.0), cropRect: CGRect(x: 0.0, y: 0.0, width: 400.0, height: 300.0), cropOrientation: .up, cropRotation: 0.0, cropLockedAspectRatio: 0.0, cropMirrored: false, trimStartValue: 1.0, trimEndValue: 3.0, toolValues: nil, paintingData: nil, sendAsGif: false, preset: TGMediaVideoConversionPresetCompressedMedium)!
        let dict = try XCTUnwrap(adjustments.dictionary())
        let data = EngineMemoryBuffer(data: try NSKeyedArchiver.archivedData(withRootObject: dict, requiringSecureCoding: false))
        return VideoMediaResourceAdjustments(data: data, digest: EngineMemoryBuffer(data: Data(count: 16)), isStory: false)
    }

    func testJSONNonStoryDecodes() throws {
        let result = videoMediaResourceEditorValues(adjustments: try jsonAdjustments(isStory: false), alwaysUseModernPipeline: true, defaultPreset: .compressedMedium)
        let values = try XCTUnwrap(result.values)
        XCTAssertNil(result.legacy)
        XCTAssertEqual(values.videoTrimRange, 2.0 ..< 5.0)
        XCTAssertEqual(values.qualityPreset, .compressedVeryHigh)
    }

    func testJSONNonStoryDecodesWithoutModernPipeline() throws {
        let result = videoMediaResourceEditorValues(adjustments: try jsonAdjustments(isStory: false), alwaysUseModernPipeline: false, defaultPreset: .compressedMedium)
        XCTAssertNotNil(result.values)
        XCTAssertNil(result.legacy)
    }

    func testLegacyArchiveStillDecodes() throws {
        let modern = videoMediaResourceEditorValues(adjustments: try legacyAdjustments(), alwaysUseModernPipeline: true, defaultPreset: .compressedMedium)
        let values = try XCTUnwrap(modern.values)
        XCTAssertNil(modern.legacy)
        XCTAssertEqual(values.videoTrimRange, 1.0 ..< 3.0)

        let legacy = videoMediaResourceEditorValues(adjustments: try legacyAdjustments(), alwaysUseModernPipeline: false, defaultPreset: .compressedMedium)
        XCTAssertNil(legacy.values)
        let adjustments = try XCTUnwrap(legacy.legacy)
        XCTAssertEqual(adjustments.trimStartValue, 1.0)
        XCTAssertEqual(adjustments.trimEndValue, 3.0)
    }

    func testStoryJSONDecodes() throws {
        let result = videoMediaResourceEditorValues(adjustments: try jsonAdjustments(isStory: true), alwaysUseModernPipeline: false, defaultPreset: .compressedMedium)
        XCTAssertEqual(result.values?.videoTrimRange, 2.0 ..< 5.0)
        XCTAssertNil(result.legacy)
    }

    func testStoryGarbageReturnsNil() {
        let data = EngineMemoryBuffer(data: Data([1, 2, 3, 4]))
        let adjustments = VideoMediaResourceAdjustments(data: data, digest: EngineMemoryBuffer(data: Data(count: 16)), isStory: true)
        let result = videoMediaResourceEditorValues(adjustments: adjustments, alwaysUseModernPipeline: true, defaultPreset: .compressedMedium)
        XCTAssertNil(result.values)
        XCTAssertNil(result.legacy)
    }

    func testGarbageReturnsNil() {
        let data = EngineMemoryBuffer(data: Data([1, 2, 3, 4]))
        let adjustments = VideoMediaResourceAdjustments(data: data, digest: EngineMemoryBuffer(data: Data(count: 16)), isStory: false)
        let result = videoMediaResourceEditorValues(adjustments: adjustments, alwaysUseModernPipeline: true, defaultPreset: .compressedMedium)
        XCTAssertNil(result.values)
        XCTAssertNil(result.legacy)
    }
}
