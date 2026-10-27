import Foundation
import UIKit
import Photos
import XCTest
import TelegramCore
import MediaEditor
import ChatMediaEditorScreen

private final class StubAsset: PHAsset {
    private let stubPixelWidth: Int
    private let stubPixelHeight: Int
    private let stubMediaType: PHAssetMediaType

    init(pixelWidth: Int, pixelHeight: Int, mediaType: PHAssetMediaType) {
        self.stubPixelWidth = pixelWidth
        self.stubPixelHeight = pixelHeight
        self.stubMediaType = mediaType
        super.init()
    }

    override var pixelWidth: Int {
        return self.stubPixelWidth
    }

    override var pixelHeight: Int {
        return self.stubPixelHeight
    }

    override var mediaType: PHAssetMediaType {
        return self.stubMediaType
    }
}

final class ChatMediaEditorItemTests: XCTestCase {
    private let peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))

    func testAssetOriginalDimensionsFullPixelSize() {
        let photo = StubAsset(pixelWidth: 4032, pixelHeight: 3024, mediaType: .image)
        let photoSetup = chatMediaEditorEditorSetup(subject: .asset(photo), peerId: self.peerId)
        XCTAssertEqual(photoSetup.values.originalDimensions, PixelDimensions(width: 4032, height: 3024))
        XCTAssertEqual(photoSetup.values.qualityPreset, .compressedVeryHigh)
        XCTAssertFalse(photoSetup.isVideo)
        if case let .asset(asset) = photoSetup.subject {
            XCTAssertTrue(asset === photo)
        } else {
            XCTFail()
        }

        let video = StubAsset(pixelWidth: 3840, pixelHeight: 2160, mediaType: .video)
        let videoSetup = chatMediaEditorEditorSetup(subject: .asset(video), peerId: self.peerId)
        XCTAssertEqual(videoSetup.values.originalDimensions, PixelDimensions(width: 3840, height: 2160))
        XCTAssertTrue(videoSetup.isVideo)
        XCTAssertNotEqual(videoSetup.values.qualityPreset, .compressedVeryHigh)

        let source = ChatMediaEditorItemSource.asset(photo)
        XCTAssertEqual(source, .asset(photo))
        let item = ChatMediaEditorItem(uniqueId: "id", source: source)
        XCTAssertEqual(item.uniqueId, "id")
    }

    func testUnavailableSourceReported() {
        XCTAssertEqual(chatMediaEditorSourceIndicatorState(.unavailable), .unavailable)
        XCTAssertEqual(chatMediaEditorSourceIndicatorState(.loading(0.4)), .progress(0.4))
        XCTAssertEqual(chatMediaEditorSourceIndicatorState(.loading(nil)), .hidden)
        XCTAssertEqual(chatMediaEditorSourceIndicatorState(.ready), .hidden)
    }
}
