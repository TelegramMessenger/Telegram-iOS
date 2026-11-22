import Foundation
import UIKit
import XCTest
import TelegramCore
import LegacyComponents
import LocalMediaResources
import MediaEditor
import FetchVideoMediaResource
import ChatMediaSend

private let hashTestPeerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))

final class VideoLibraryMediaResourceHashTests: XCTestCase {
    private func editedValues(muted: Bool) -> MediaEditorValues {
        var values = chatMediaEditorValues(peerId: hashTestPeerId, originalDimensions: PixelDimensions(width: 3840, height: 2160), qualityPreset: .compressedVeryHigh)
        values = values.withUpdatedVideoIsMuted(muted)
        return values
    }

    func testEditorAdjustmentsSaltTheHash() throws {
        let adjustments = try XCTUnwrap(chatMediaEditorVideoAdjustments(values: self.editedValues(muted: true)))
        let salt = videoLibraryMediaResourceHashSalt(conversion: .compress(adjustments))
        XCTAssertEqual(salt, adjustments.digest.makeData())
    }

    func testDifferentEditorValuesGiveDifferentSalts() throws {
        let muted = try XCTUnwrap(chatMediaEditorVideoAdjustments(values: self.editedValues(muted: true)))
        let unmuted = try XCTUnwrap(chatMediaEditorVideoAdjustments(values: self.editedValues(muted: false)))
        let mutedSalt = try XCTUnwrap(videoLibraryMediaResourceHashSalt(conversion: .compress(muted)))
        let unmutedSalt = try XCTUnwrap(videoLibraryMediaResourceHashSalt(conversion: .compress(unmuted)))
        XCTAssertNotEqual(mutedSalt, unmutedSalt)
    }

    func testUneditedAndPassthroughAreNotSalted() {
        XCTAssertNil(videoLibraryMediaResourceHashSalt(conversion: .compress(nil)))
        XCTAssertNil(videoLibraryMediaResourceHashSalt(conversion: .passthrough))
    }

    func testLegacyArchiveIsNotSalted() throws {
        let adjustments = TGVideoEditAdjustments(originalSize: CGSize(width: 400.0, height: 300.0), cropRect: CGRect(x: 0.0, y: 0.0, width: 400.0, height: 300.0), cropOrientation: .up, cropRotation: 0.0, cropLockedAspectRatio: 0.0, cropMirrored: false, trimStartValue: 1.0, trimEndValue: 3.0, toolValues: nil, paintingData: nil, sendAsGif: true, preset: TGMediaVideoConversionPresetCompressedMedium)!
        let dict = try XCTUnwrap(adjustments.dictionary())
        let data = EngineMemoryBuffer(data: try NSKeyedArchiver.archivedData(withRootObject: dict, requiringSecureCoding: false))
        let resourceAdjustments = VideoMediaResourceAdjustments(data: data, digest: EngineMemoryBuffer(data: data.md5Digest()), isStory: false)
        XCTAssertNil(videoLibraryMediaResourceHashSalt(conversion: .compress(resourceAdjustments)))
    }

    func testStoryAdjustmentsAreNotSalted() throws {
        let data = EngineMemoryBuffer(data: try JSONEncoder().encode(self.editedValues(muted: true)))
        let adjustments = VideoMediaResourceAdjustments(data: data, digest: EngineMemoryBuffer(data: data.md5Digest()), isStory: true)
        XCTAssertNil(videoLibraryMediaResourceHashSalt(conversion: .compress(adjustments)))
    }
}
