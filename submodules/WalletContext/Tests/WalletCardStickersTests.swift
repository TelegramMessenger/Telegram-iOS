import XCTest
import TelegramCore
@testable import WalletContext

final class WalletCardStickersTests: XCTestCase {
    private func sticker(_ id: String, x: Double = 0.5, scale: Double = 1) -> WalletContext.CardSticker {
        WalletContext.CardSticker(gift: WalletContext.Collectible(address: id, name: "Gift", kind: .gift),
            x: x, y: 1.04, angle: -0.25, scale: scale)
    }

    func testStoredLayoutRoundTripPreservesWalletsAndStackingOrder() throws {
        var state = WalletStoredState()
        state.walletAddress = "wallet-a"
        state.cardStickersByWallet = ["wallet-a": [self.sticker("first"), self.sticker("second", x: -0.05, scale: 1.8)],
            "wallet-b": [self.sticker("third", scale: 0.55)]]
        state.balance = 123
        let restored = try JSONDecoder().decode(WalletStoredState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(restored, state)
        XCTAssertEqual(restored.cardStickersByWallet["wallet-a"]?.map { $0.gift.address }, ["first", "second"])
        XCTAssertEqual(restored.cardStickersByWallet["wallet-b"]?.count, 1)
    }

    func testOldStateWithoutDecorationFieldStillDecodes() throws {
        let encoded = try JSONEncoder().encode(WalletStoredState())
        var envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let payload = try XCTUnwrap(Data(base64Encoded: try XCTUnwrap(envelope["payload"] as? String)))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        object.removeValue(forKey: "cardStickersByWallet")
        envelope["payload"] = try JSONSerialization.data(withJSONObject: object).base64EncodedString()
        let restored = try JSONDecoder().decode(WalletStoredState.self, from: JSONSerialization.data(withJSONObject: envelope))
        XCTAssertTrue(restored.cardStickersByWallet.isEmpty)
    }

    func testModelReferenceRoundTripAndLegacySticker() throws {
        let old = self.sticker("gift")
        let legacyData = try JSONEncoder().encode(old)
        let legacy = try JSONDecoder().decode(WalletContext.CardSticker.self, from: legacyData)
        XCTAssertNil(legacy.modelFile)
        let upgraded = WalletContext.CardSticker(gift: old.gift, x: old.x, y: old.y,
            angle: old.angle, scale: old.scale, modelFile: Data([1, 2, 3, 4]))
        var state = WalletStoredState()
        state.cardStickersByWallet = ["wallet": [upgraded]]
        let restored = try JSONDecoder().decode(WalletStoredState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(restored.cardStickersByWallet["wallet"], [upgraded])
    }

    func testInvalidAndDuplicateStickersCannotReachPresentation() {
        let notGift = WalletContext.CardSticker(gift: WalletContext.Collectible(address: "username", name: "Name", kind: .username),
            x: 0.5, y: 0.5, angle: 0, scale: 1)
        let values = [self.sticker("same", x: 0.1), self.sticker("second"), self.sticker("same", x: 0.8),
            self.sticker("nan", x: .nan), self.sticker("scale", scale: 10), notGift]
        let validated = WalletContext.CardSticker.validated(values)
        XCTAssertEqual(validated.map { $0.gift.address }, ["second", "same"])
        XCTAssertEqual(validated.last?.x, 0.8)
    }

    func testIncompleteOrFailedInventoryDoesNotRemoveStickers() {
        let stickers = [self.sticker("one"), self.sticker("two")]
        let partial = WalletContext.CollectiblesState(items: [stickers[0].gift], nextOffset: "next", isLoadingMore: false, error: nil)
        XCTAssertEqual(walletCardStickersAfterInventory(stickers, inventory: partial), stickers)
        let refreshing = WalletContext.CollectiblesState(items: [], nextOffset: nil, isRefreshing: true, isLoadingMore: false, error: nil)
        XCTAssertEqual(walletCardStickersAfterInventory(stickers, inventory: refreshing), stickers)
        let failed = WalletContext.CollectiblesState(items: [], nextOffset: nil, isLoadingMore: false, error: .invalidData)
        XCTAssertEqual(walletCardStickersAfterInventory(stickers, inventory: failed), stickers)
        let complete = WalletContext.CollectiblesState(items: [stickers[1].gift], nextOffset: nil, isLoadingMore: false, error: nil)
        XCTAssertEqual(walletCardStickersAfterInventory(stickers, inventory: complete), [stickers[1]])
    }

    func testGeometryMigrationKeepsVisibleModelSize() throws {
        let old = self.sticker("legacy", scale: 1.8)
        XCTAssertEqual(old.renderedWidthFraction * (298.0 / 320.0), 80.0 / 370.0 * 1.8 * (276.0 / 320.0), accuracy: 0.000001)
        XCTAssertEqual(WalletContext.CardSticker.validated([old]), [old])
        let edited = old.updated(scale: WalletContext.CardSticker.maximumScale, geometryVersion: 1)
        XCTAssertEqual(edited.renderedWidthFraction, 83.4 / 361.0 * 1.1, accuracy: 0.000001)
        let minimum = edited.updated(scale: WalletContext.CardSticker.minimumScale)
        XCTAssertEqual(WalletContext.CardSticker.validated([minimum]), [minimum])
        XCTAssertTrue(WalletContext.CardSticker.validated([edited.updated(scale: 1.11)]).isEmpty)
        XCTAssertTrue(WalletContext.CardSticker.validated([edited.updated(scale: 0.38)]).isEmpty)
        XCTAssertEqual(try JSONDecoder().decode(WalletContext.CardSticker.self, from: JSONEncoder().encode(edited)), edited)
    }

    func testDecorationIsAtomicAndOnlyOneGiftCanStyleCard() throws {
        let style = WalletContext.CardGiftStyle(innerColor: 0xffaa00, outerColor: 0x884400, patternColor: 0x663300, patternFile: Data([9, 8, 7]))
        let first = self.sticker("first").withStyle(style)
        let second = self.sticker("second").withStyle(style)
        let values = WalletContext.CardSticker.validated([first, second])
        XCTAssertNil(values[0].style)
        XCTAssertEqual(values[0].giftStyle, style)
        XCTAssertEqual(values[1].style, style)
        var state = WalletStoredState()
        state.cardStickersByWallet = ["a": values, "b": [first]]
        state.balance = 9988
        let restored = try JSONDecoder().decode(WalletStoredState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(restored.cardStickersByWallet, state.cardStickersByWallet)
        XCTAssertEqual(restored.balance, 9988)
        XCTAssertEqual(second.updated(x: 0.7, modelFile: Data([1])).style, style)
        let remaining = walletCardStickersAfterInventory(values,
            inventory: WalletContext.CollectiblesState(items: [first.gift], nextOffset: nil, isLoadingMore: false, error: nil))
        XCTAssertEqual(remaining.map { $0.gift.address }, ["first"])
        XCTAssertNil(remaining.first?.style)
    }

    func testLegacyStickerWithoutStyleOrGeometryDecodes() throws {
        let encoded = try JSONEncoder().encode(self.sticker("legacy"))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        for key in ["geometryVersion", "style", "giftStyle"] { object.removeValue(forKey: key) }
        let decoded = try JSONDecoder().decode(WalletContext.CardSticker.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(decoded.style)
        XCTAssertNil(decoded.giftStyle)
        XCTAssertNil(decoded.geometryVersion)
        XCTAssertEqual(decoded.scale, 1)
    }
    private func nft(_ address: String = "gift") -> WalletNftItem {
        let gift = StarGift.UniqueGift(id: 1, giftId: 2, title: "Cake", number: 42, slug: "Cake-42",
            owner: nil, attributes: [.backdrop(name: "Gold", id: 1, innerColor: 0xffaa00, outerColor: 0x884400,
                patternColor: 0x663300, textColor: 0xffffff, rarity: .permille(10))], availability: .init(issued: 1, total: 100), giftAddress: address,
            resellAmounts: nil, resellForTonOnly: false, releasedBy: nil, valueAmount: nil,
            valueCurrency: nil, valueUsdAmount: nil, flags: [], themePeerId: nil, peerColor: nil,
            hostPeerId: nil, minOfferStars: nil, craftChancePermille: nil)
        return WalletNftItem(collectionAddress: nil, address: address, ownerAddress: "wallet", index: "42",
            name: "Cake", description: nil, image: nil, imageSmall: nil, contentUrl: nil, lottie: nil,
            attributes: nil, extra: nil, gift: gift)
    }

    func testServerGeometryRoundTripIncludingAspectAndRadius() throws {
        let input = WalletCard.Sticker(coordinates: .init(x: 19, y: 71, width: 31, height: 24,
            rotation: -75, cornerRadius: 3), nft: self.nft())
        let local = try XCTUnwrap(WalletContext.CardSticker(serverSticker: input))
        XCTAssertEqual(local.x, 0.19, accuracy: 0.000001)
        XCTAssertEqual(local.angle, -75 * Double.pi / 180, accuracy: 0.000001)
        XCTAssertEqual(local.renderedWidthFraction, 0.31, accuracy: 0.000001)
        XCTAssertEqual(local.renderedWidthFraction * 370 * (local.aspectRatio ?? 1) / 220, 0.24, accuracy: 0.000001)
        XCTAssertTrue(walletCardStickerLayoutsEqual([local.serverSticker], [.init(coordinates: input.coordinates, nftAddress: input.nft.address)]))
        // Other clients may use a larger sticker than the local editor's new limit.
        XCTAssertEqual(WalletContext.CardSticker.validated([local]), [local])
    }

    func testInvalidServerGeometryCannotReachRendering() {
        for coordinates in [
            MediaArea.Coordinates(x: .nan, y: 50, width: 20, height: 20, rotation: 0, cornerRadius: nil),
            .init(x: 50, y: 50, width: 0, height: 20, rotation: 0, cornerRadius: nil),
            .init(x: 50, y: 50, width: 20, height: 101, rotation: 0, cornerRadius: nil),
            .init(x: 50, y: 50, width: 20, height: 20, rotation: 0, cornerRadius: .infinity)
        ] {
            XCTAssertNil(WalletContext.CardSticker(serverSticker: .init(coordinates: coordinates, nft: self.nft())))
        }
    }

    func testOldPrivateLayoutsBecomeUnpublishedDrafts() throws {
        var stored = WalletStoredState()
        stored.cardStickersByWallet = ["wallet-a": [self.sticker("one")], "wallet-b": []]
        var envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(stored)) as? [String: Any])
        let payload = try XCTUnwrap(Data(base64Encoded: try XCTUnwrap(envelope["payload"] as? String)))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        object.removeValue(forKey: "cardStickerDirtyWallets")
        object.removeValue(forKey: "serverCardsByWallet")
        envelope["payload"] = try JSONSerialization.data(withJSONObject: object).base64EncodedString()
        let restored = try JSONDecoder().decode(WalletStoredState.self, from: JSONSerialization.data(withJSONObject: envelope))
        XCTAssertEqual(restored.cardStickerDirtyWallets, ["wallet-a"])
        XCTAssertEqual(restored.cardStickersByWallet, stored.cardStickersByWallet)
        XCTAssertTrue(restored.serverCardsByWallet.isEmpty)
    }

    func testDraftAndPublishedLayoutsAreStoredSeparatelyAcrossWallets() throws {
        var stored = WalletStoredState()
        let published = WalletCard.Sticker(coordinates: self.sticker("one").serverSticker.coordinates, nft: self.nft("one"))
        stored.serverCardsByWallet = ["wallet-a": .init(address: "wallet-a", balance: 500, stickers: [published]),
            "wallet-b": .init(address: "wallet-b", balance: 0, stickers: [])]
        stored.cardStickersByWallet = ["wallet-a": [], "wallet-b": [self.sticker("two")]]
        stored.cardStickerDirtyWallets = ["wallet-a", "wallet-b"]
        stored.balance = 999
        let restored = try JSONDecoder().decode(WalletStoredState.self, from: JSONEncoder().encode(stored))
        XCTAssertEqual(restored, stored)
        XCTAssertEqual(restored.serverCardsByWallet["wallet-a"]?.stickers.count, 1)
        XCTAssertEqual(restored.cardStickersByWallet["wallet-a"], [])
    }

    func testLayoutComparisonDetectsEditsDuringSaveAndKeepsOrder() {
        let first = self.sticker("one"), second = self.sticker("two")
        let submitted = [first.serverSticker, second.serverSticker]
        XCTAssertFalse(walletCardStickerLayoutsEqual(submitted, [second.serverSticker, first.serverSticker]))
        XCTAssertFalse(walletCardStickerLayoutsEqual(submitted, [first.updated(x: 0.4).serverSticker, second.serverSticker]))
        XCTAssertFalse(walletCardStickerLayoutsEqual(submitted, []))
        XCTAssertTrue(walletCardStickerLayoutsEqual([], []))
        let style = WalletContext.CardGiftStyle(innerColor: 1, outerColor: 2, patternColor: 3, patternFile: nil)
        XCTAssertTrue(walletCardStickerLayoutsEqual(submitted, [first.withStyle(style).serverSticker, second.serverSticker]))
        let raw = "0:" + String(repeating: "0", count: 64)
        let rawInput = WalletCard.InputSticker(coordinates: first.serverSticker.coordinates, nftAddress: raw)
        let friendlyInput = WalletCard.InputSticker(coordinates: first.serverSticker.coordinates,
            nftAddress: "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c")
        XCTAssertTrue(walletCardStickerLayoutsEqual([rawInput], [friendlyInput]))
    }

    func testColorChangesDuringSaveRemainPending() {
        let layout = [self.sticker("one").serverSticker, self.sticker("two").serverSticker]
        XCTAssertFalse(walletCardStickerLayoutsEqual(layout, layout, backgroundA: nil, backgroundB: "one"))
        XCTAssertFalse(walletCardStickerLayoutsEqual(layout, layout, backgroundA: "one", backgroundB: nil))
        XCTAssertFalse(walletCardStickerLayoutsEqual(layout, layout, backgroundA: "one", backgroundB: "two"))
        XCTAssertTrue(walletCardStickerLayoutsEqual(layout, layout, backgroundA: "one", backgroundB: "one"))
        XCTAssertTrue(walletCardStickerLayoutsEqual(layout, layout,
            backgroundA: "0:" + String(repeating: "0", count: 64),
            backgroundB: "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"))
    }

    func testServerSelectsAndClearsBackgroundStyle() throws {
        let sticker = WalletCard.Sticker(coordinates: .init(x: 50, y: 50, width: 20, height: 30,
            rotation: 0, cornerRadius: nil), nft: self.nft("one"))
        let selected = try XCTUnwrap(WalletContext.CardSticker(serverSticker: sticker, backgroundNftAddress: "one"))
        XCTAssertNotNil(selected.style)
        XCTAssertEqual(selected.style, selected.giftStyle)
        let cleared = try XCTUnwrap(WalletContext.CardSticker(serverSticker: sticker))
        XCTAssertNil(cleared.style)
        XCTAssertEqual(cleared.giftStyle, selected.giftStyle)
        XCTAssertNil(WalletContext.CardSticker(serverSticker: sticker, backgroundNftAddress: "two")?.style)
    }

    func testBackgroundSurvivesCacheAndOldCardsDecodeWithoutIt() throws {
        let nft = self.nft()
        let sticker = WalletCard.Sticker(coordinates: .init(x: 50, y: 50, width: 20, height: 30,
            rotation: 0, cornerRadius: nil), nft: nft)
        let card = WalletCard(address: "wallet", balance: 50, stickers: [sticker], backgroundNft: nft)
        let data = try JSONEncoder().encode(card)
        XCTAssertEqual(try JSONDecoder().decode(WalletCard.self, from: data), card)
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        old.removeValue(forKey: "backgroundNft")
        let restored = try JSONDecoder().decode(WalletCard.self, from: JSONSerialization.data(withJSONObject: old))
        XCTAssertNil(restored.backgroundNft)
        XCTAssertEqual(restored.stickers, card.stickers)
    }

    func testInlineGiftSurvivesCacheAndTransactionConversion() throws {
        let nft = self.nft()
        let restored = try JSONDecoder().decode(WalletNftItem.self, from: JSONEncoder().encode(nft))
        XCTAssertEqual(restored.gift, nft.gift)
        XCTAssertNil(restored.gift?.owner)
        let collectible = WalletContext.Collectible(nft: restored)
        XCTAssertEqual(collectible.kind, .gift)
        XCTAssertEqual(collectible.giftSlug, "Cake-42")
        XCTAssertEqual(WalletContext.Transaction.CollectibleTransfer(collectible: collectible).nft, nft)
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(nft)) as? [String: Any])
        old.removeValue(forKey: "gift")
        XCTAssertNil(try JSONDecoder().decode(WalletNftItem.self, from: JSONSerialization.data(withJSONObject: old)).gift)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        old["giftData"] = try encoder.encode(XCTUnwrap(nft.gift)).base64EncodedString()
        let legacy = try XCTUnwrap(JSONDecoder().decode(WalletNftItem.self, from: JSONSerialization.data(withJSONObject: old)).gift)
        XCTAssertEqual(legacy.slug, nft.gift?.slug)
        XCTAssertEqual(legacy.attributes, nft.gift?.attributes)
    }

    func testProfileCachePreservesCardDuringOtherUpdates() throws {
        let card = WalletCard(address: "wallet", balance: 0, stickers: [])
        let cached = CachedUserData().withUpdatedWalletCard(card).withUpdatedAbout("About")
        XCTAssertEqual(cached.walletCard, card)
        let encoder = EnginePostboxEncoder()
        cached.encode(encoder)
        let restored = CachedUserData(decoder: EnginePostboxDecoder(buffer: EngineMemoryBuffer(data: encoder.makeData())))
        XCTAssertEqual(restored.walletCard, card)
        XCTAssertNil(CachedUserData().walletCard)
    }

    func testAutosaveWaitsFifteenSecondsAfterLastChange() {
        var schedule = WalletCardStickerSaveSchedule()
        schedule.update(walletAddress: "a", hasChanges: true, now: 0)
        schedule.update(walletAddress: "a", hasChanges: true, now: 10)
        XCTAssertNil(schedule.takeDue(walletAddress: "a", now: 24.99, requestInFlight: false))
        XCTAssertEqual(schedule.takeDue(walletAddress: "a", now: 25, requestInFlight: false), "a")
        XCTAssertNil(schedule.takeDue(walletAddress: "a", now: 100, requestInFlight: false))
    }

    func testClosingScreenFlushesButDoesNotOverlapRequest() {
        var schedule = WalletCardStickerSaveSchedule()
        schedule.update(walletAddress: "a", hasChanges: true, now: 0)
        schedule.update(walletAddress: "a", hasChanges: true, now: 5, immediate: true)
        XCTAssertNil(schedule.takeDue(walletAddress: "a", now: 5, requestInFlight: true))
        XCTAssertEqual(schedule.takeDue(walletAddress: "a", now: 6, requestInFlight: false), "a")
        XCTAssertNil(schedule.pending)
    }

    func testNewEditsDuringRequestKeepTheirOwnDebounce() {
        var schedule = WalletCardStickerSaveSchedule()
        schedule.update(walletAddress: "a", hasChanges: true, now: 0)
        XCTAssertEqual(schedule.takeDue(walletAddress: "a", now: 15, requestInFlight: false), "a")
        schedule.update(walletAddress: "a", hasChanges: true, now: 18)
        XCTAssertNil(schedule.takeDue(walletAddress: "a", now: 25, requestInFlight: false))
        XCTAssertNil(schedule.takeDue(walletAddress: "a", now: 33, requestInFlight: true))
        XCTAssertEqual(schedule.takeDue(walletAddress: "a", now: 35, requestInFlight: false), "a")
    }

    func testUnchangedAndReplacementWalletNeverSendQueuedLayout() {
        var schedule = WalletCardStickerSaveSchedule()
        schedule.update(walletAddress: "a", hasChanges: true, now: 0)
        XCTAssertNil(schedule.takeDue(walletAddress: "b", now: 15, requestInFlight: false))
        XCTAssertNil(schedule.pending)
        schedule.update(walletAddress: "a", hasChanges: true, now: 20)
        schedule.update(walletAddress: "a", hasChanges: false, now: 25, immediate: true)
        XCTAssertNil(schedule.takeDue(walletAddress: "a", now: 40, requestInFlight: false))
    }

}
