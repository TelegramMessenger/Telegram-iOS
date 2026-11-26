import XCTest
import Postbox
import TelegramApi
@testable import TelegramCore

final class SecretChatAnimatedStickerTests: XCTestCase {
    private func makeFile(namespace: Int32 = Namespaces.Media.CloudFile, id: Int64 = 1, mimeType: String = "application/x-tgsticker", packReference: StickerPackReference? = .name("UncachedPack"), isSticker: Bool = true, isValidated: Bool = false) -> TelegramMediaFile {
        var attributes: [TelegramMediaFileAttribute] = [.FileName(fileName: "sticker.tgs")]
        if isSticker {
            attributes.append(.Sticker(displayText: "", packReference: packReference, maskData: nil))
        }
        if isValidated {
            attributes.append(.hintIsValidated)
        }
        return TelegramMediaFile(fileId: MediaId(namespace: namespace, id: id), partialReference: nil, resource: CloudDocumentMediaResource(datacenterId: 1, fileId: id, accessHash: 2, size: 1024, fileReference: Data([1, 2, 3]), fileName: nil), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: mimeType, size: 1024, attributes: attributes, alternativeRepresentations: [])
    }

    func testShortNameFromSecretChatWireAttributesIsRefreshed() throws {
        let attribute = try XCTUnwrap(TelegramMediaFileAttribute(SecretApi144.DocumentAttribute.documentAttributeSticker(alt: "", stickerset: .inputStickerSetShortName(shortName: "UncachedPack"))))
        let file = self.makeFile().withUpdatedAttributes([.FileName(fileName: "sticker.tgs"), attribute])
        XCTAssertEqual(secretChatAnimatedStickerPackReferences([file]), Set([.name("UncachedPack")]))
    }

    func testNumericPackReferencesStillWork() {
        let reference = StickerPackReference.id(id: 123, accessHash: 456)
        XCTAssertEqual(secretChatAnimatedStickerPackReferences([self.makeFile(packReference: reference)]), Set([reference]))
    }

    func testPackRequestsAreDeduplicated() {
        let files = [self.makeFile(id: 1), self.makeFile(id: 2), self.makeFile(id: 3, packReference: .id(id: 123, accessHash: 456))]
        XCTAssertEqual(secretChatAnimatedStickerPackReferences(files), Set([.name("UncachedPack"), .id(id: 123, accessHash: 456)]))
    }

    func testOtherFilesDoNotRequestStickerPacks() {
        let files = [
            self.makeFile(namespace: Namespaces.Media.CloudSecretFile),
            self.makeFile(mimeType: "image/webp"),
            self.makeFile(packReference: nil),
            self.makeFile(packReference: .animatedEmoji),
            self.makeFile(isSticker: false)
        ]
        XCTAssertTrue(secretChatAnimatedStickerPackReferences(files).isEmpty)
    }

    func testMatchingServerStickerBecomesDisplayable() throws {
        let peerId = PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(1))
        let incoming = self.makeFile()
        XCTAssertFalse(incoming.isValidForDisplay(chatPeerId: peerId))

        // The response supplies the authoritative file reference and pack ID, not the peer's metadata.
        let serverFile = self.makeFile(packReference: .id(id: 123, accessHash: 456))
        let updated = try XCTUnwrap(validatedSecretChatAnimatedSticker(serverFile, requestedFileIds: Set([incoming.fileId])))
        XCTAssertTrue(updated.isValidForDisplay(chatPeerId: peerId))
        XCTAssertEqual(updated.fileId, incoming.fileId)
        XCTAssertTrue(updated.resource.isEqual(to: serverFile.resource))
        XCTAssertEqual(secretChatAnimatedStickerPackReferences([updated]), Set([.id(id: 123, accessHash: 456)]))
    }

    func testUnrequestedPackDocumentsAreNotUpdated() {
        XCTAssertNil(validatedSecretChatAnimatedSticker(self.makeFile(id: 2), requestedFileIds: Set([self.makeFile(id: 1).fileId])))
    }

    func testNonStickerServerDocumentIsNotValidated() {
        let file = self.makeFile(isSticker: false)
        XCTAssertNil(validatedSecretChatAnimatedSticker(file, requestedFileIds: Set([file.fileId])))
    }

    func testNonAnimatedServerStickerIsNotValidated() {
        let file = self.makeFile(mimeType: "image/webp")
        XCTAssertNil(validatedSecretChatAnimatedSticker(file, requestedFileIds: Set([file.fileId])))
    }

    func testEncryptedTgsRestrictionIsPreserved() {
        let file = self.makeFile(namespace: Namespaces.Media.CloudSecretFile)
        XCTAssertFalse(file.isSticker)
        XCTAssertFalse(file.isAnimatedSticker)
        XCTAssertFalse(TelegramMediaFile.Accessor(file).isAnimatedSticker)
        XCTAssertNil(validatedSecretChatAnimatedSticker(file, requestedFileIds: Set([file.fileId])))
    }

    func testValidationHintIsNotDuplicated() throws {
        let file = self.makeFile(isValidated: true)
        let updated = try XCTUnwrap(validatedSecretChatAnimatedSticker(file, requestedFileIds: Set([file.fileId])))
        let hintCount = updated.attributes.filter { attribute in
            if case .hintIsValidated = attribute {
                return true
            }
            return false
        }.count
        XCTAssertEqual(hintCount, 1)
    }
}
