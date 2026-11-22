import XCTest
import Postbox
import SwiftSignalKit
@testable import TelegramCore

/// The pack an emoji status comes from, which a tap on the status waits for before it opens
/// the Premium screen. A pack its owner deleted never loads, and an answer that waits for a
/// loaded pack leaves the tap doing nothing (bugs.telegram.org/c/62283).
final class CustomEmojiPackTests: XCTestCase {
    private func emojiFile(packReference: StickerPackReference?) -> TelegramMediaFile {
        return TelegramMediaFile(
            fileId: MediaId(namespace: Namespaces.Media.CloudFile, id: 1),
            partialReference: nil,
            resource: LocalFileMediaResource(fileId: 1),
            previewRepresentations: [],
            videoThumbnails: [],
            immediateThumbnailData: nil,
            mimeType: "application/x-tgsticker",
            size: nil,
            attributes: [.CustomEmoji(isPremium: true, isSingleColor: false, alt: "✅", packReference: packReference)],
            alternativeRepresentations: []
        )
    }

    private func loadedPack(id: Int64) -> LoadedStickerPack {
        let info = StickerPackCollectionInfo(
            id: ItemCollectionId(namespace: Namespaces.ItemCollection.CloudEmojiPacks, id: id),
            flags: [.isEmoji],
            accessHash: 1,
            title: "Pack \(id)",
            shortName: "pack\(id)",
            thumbnail: nil,
            thumbnailFileId: nil,
            immediateThumbnailData: nil,
            hash: 0,
            count: 0
        )
        return .result(info: StickerPackCollectionInfo.Accessor(info), items: [], installed: false)
    }

    /// What `loadedStickerPack` emits, in order, before it completes.
    private func loader(_ states: [LoadedStickerPack]) -> (StickerPackReference) -> Signal<LoadedStickerPack, NoError> {
        return { _ in
            return Signal { subscriber in
                for state in states {
                    subscriber.putNext(state)
                }
                subscriber.putCompletion()
                return EmptyDisposable
            }
        }
    }

    private func describe(_ pack: LoadedStickerPack?) -> String {
        switch pack {
        case nil:
            return "no pack"
        case .some(.fetching):
            return "fetching"
        case .some(.none):
            return "not found"
        case let .some(.result(info, _, _)):
            return "pack \(info.id.id)"
        }
    }

    /// Every emission, then whether the signal completed.
    private func resolve(_ file: TelegramMediaFile, loadPack: @escaping (StickerPackReference) -> Signal<LoadedStickerPack, NoError>) -> [String] {
        var events: [String] = []
        let _ = _internal_customEmojiPack(file: file, loadPack: loadPack).start(next: { pack in
            events.append(self.describe(pack))
        }, completed: {
            events.append("completed")
        })
        return events
    }

    private let packReference: StickerPackReference = .id(id: 7, accessHash: 1)

    /// A deleted pack: the loader reports fetching, then that no such pack exists.
    func testADeletedPackResolvesToNoPack() {
        let events = self.resolve(self.emojiFile(packReference: self.packReference), loadPack: self.loader([.fetching, .none]))

        XCTAssertEqual(events, ["no pack", "completed"])
    }

    /// The server can also strip the pack from the emoji (`inputStickerSetEmpty`). Nothing is
    /// asked of a loader then, so one that never answers must not hold the result back.
    func testAnEmojiThatNamesNoPackResolvesToNoPack() {
        let events = self.resolve(self.emojiFile(packReference: nil), loadPack: { _ in .never() })

        XCTAssertEqual(events, ["no pack", "completed"])
    }

    func testAPackThatLoadsResolvesToThatPack() {
        let events = self.resolve(self.emojiFile(packReference: self.packReference), loadPack: self.loader([.fetching, self.loadedPack(id: 7)]))

        XCTAssertEqual(events, ["pack 7", "completed"])
    }

    /// A cached pack is followed by its refreshed copy. A second answer would open the Premium
    /// screen a second time for one tap.
    func testOnlyTheFirstLoadedPackIsReported() {
        let events = self.resolve(self.emojiFile(packReference: self.packReference), loadPack: self.loader([self.loadedPack(id: 7), self.loadedPack(id: 8)]))

        XCTAssertEqual(events, ["pack 7", "completed"])
    }

    func testALoaderThatEndsWithoutAnAnswerResolvesToNoPack() {
        let events = self.resolve(self.emojiFile(packReference: self.packReference), loadPack: self.loader([.fetching]))

        XCTAssertEqual(events, ["no pack", "completed"])
    }
}
