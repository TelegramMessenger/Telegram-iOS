import Foundation
import SwiftSignalKit
import TelegramCore
import Postbox

@available(macOS 10.15, *)
public extension WalletContext {
    func updateCardStickers(_ stickers: [CardSticker], walletAddress: String) {
        Task { await self.impl.updateCardStickers(stickers, walletAddress: walletAddress) }
    }
}

@available(macOS 10.15, *)
extension WalletContextImpl {
    func updateCardStickers(_ stickers: [WalletContext.CardSticker], walletAddress: String) {
        guard !self.isShutdown, case let .wallet(info) = self.currentState.phase,
              info.address == walletAddress else { return }
        let value = WalletContext.CardSticker.validated(stickers)
        let before = (self.cardStickersByWallet[walletAddress] ?? []).map(\.serverSticker)
        let after = value.map(\.serverSticker)
        if !walletCardStickerLayoutsEqual(before, after) {
            let saved = self.serverCardsByWallet[walletAddress]?.stickers.map { WalletCard.InputSticker(coordinates: $0.coordinates, nftAddress: $0.nft.address) } ?? []
            if self.cardStickerSavingAddress != walletAddress && walletCardStickerLayoutsEqual(saved, after) { self.cardStickerDirtyWallets.remove(walletAddress) }
            else { self.cardStickerDirtyWallets.insert(walletAddress) }
            self.cardStickerSaveError = nil
        }
        self.cardStickersByWallet[walletAddress] = value
        self.replaceState(
            phase: self.currentState.phase, balance: self.currentState.balance,
            transactions: self.currentState.transactions, pendingTransfers: self.currentState.pendingTransfers,
            activeOperation: self.currentState.activeOperation
        )
        if !walletCardStickerLayoutsEqual(before, after) {
            self.scheduleCardStickerSave(immediate: self.walletScreenCount == 0)
        }
    }

    func reconcileCardStickers(_ collectibles: WalletContext.CollectiblesState) {
        guard !collectibles.isRefreshing, !collectibles.isLoadingMore,
              collectibles.error == nil, collectibles.nextOffset == nil,
              let address = self.currentState.walletAddress else { return }
        let stickers = walletCardStickersAfterInventory(self.currentState.cardStickers, inventory: collectibles)
        if stickers != self.currentState.cardStickers {
            self.updateCardStickers(stickers, walletAddress: address)
        }
    }
}

@available(macOS 10.15, *)
func walletCardStickersAfterInventory(_ stickers: [WalletContext.CardSticker], inventory: WalletContext.CollectiblesState) -> [WalletContext.CardSticker] {
    guard !inventory.isRefreshing, !inventory.isLoadingMore, inventory.error == nil, inventory.nextOffset == nil else {
        return stickers
    }
    let owned = Set(inventory.items.filter { $0.kind == .gift }.map { walletCollectibleAddressKey($0.address) })
    return stickers.filter { owned.contains(walletCollectibleAddressKey($0.gift.address)) }
}

@available(macOS 10.15, *)
public extension WalletContext.CardSticker {
    var serverSticker: WalletCard.InputSticker {
        let width = self.renderedWidthFraction * 100
        return WalletCard.InputSticker(coordinates: .init(x: self.x * 100, y: self.y * 100,
            width: width, height: width * 370 / 220 * (self.aspectRatio ?? 1),
            rotation: self.angle * 180 / .pi, cornerRadius: self.cornerRadius), nftAddress: self.gift.address)
    }

    init?(serverSticker: WalletCard.Sticker) {
        let c = serverSticker.coordinates
        guard [c.x, c.y, c.width, c.height, c.rotation].allSatisfy({ $0.isFinite }),
              (0...100).contains(c.x), (0...100).contains(c.y),
              c.width > 0, c.width <= 100, c.height > 0, c.height <= 100,
              c.cornerRadius.map({ $0.isFinite && $0 >= 0 }) ?? true else { return nil }
        let gift = WalletContext.Collectible(nft: serverSticker.nft)
        guard gift.kind == .gift else { return nil }
        var model: Data?, pattern: Data?
        let unique = serverSticker.nft.gift
        for attribute in unique?.attributes ?? [] {
            switch attribute {
            case let .model(_, file, _, _):
                let encoder = PostboxEncoder(); encoder.encodeRootObject(file); model = encoder.makeData()
            case let .pattern(_, file, _):
                let encoder = PostboxEncoder(); encoder.encodeRootObject(file); pattern = encoder.makeData()
            default: break
            }
        }
        var style: WalletContext.CardGiftStyle?
        for case let .backdrop(_, _, inner, outer, color, _, _) in unique?.attributes ?? [] {
            style = .init(innerColor: inner, outerColor: outer, patternColor: color, patternFile: pattern)
        }
        self.init(gift: gift, x: c.x / 100, y: c.y / 100, angle: c.rotation * .pi / 180,
            scale: c.width / 100 / Self.widthFraction, modelFile: model, geometryVersion: 2,
            giftStyle: style, aspectRatio: c.height * 220 / (c.width * 370), cornerRadius: c.cornerRadius)
    }
}

@available(macOS 10.15, *)
func walletCardStickerLayoutsEqual(_ a: [WalletCard.InputSticker], _ b: [WalletCard.InputSticker]) -> Bool {
    guard a.count == b.count else { return false }
    return zip(a, b).allSatisfy { a, b in
        let x = a.coordinates, y = b.coordinates
        return walletCollectibleAddressKey(a.nftAddress) == walletCollectibleAddressKey(b.nftAddress) && zip([x.x, x.y, x.width, x.height, x.rotation, x.cornerRadius ?? 0],
            [y.x, y.y, y.width, y.height, y.rotation, y.cornerRadius ?? 0]).allSatisfy { abs($0 - $1) < 0.000001 }
    }
}

@available(macOS 10.15, *)
extension WalletContextImpl {
    func refreshCard(afterCurrentRequest: Bool = false) {
        guard !self.isShutdown else { return }
        if self.cardRefreshTask != nil {
            self.cardRefreshAgain = self.cardRefreshAgain || afterCurrentRequest
            return
        }
        self.cardRefreshTask = Task { [weak self] in
            guard let self else { return }
            _ = try? await WalletSignalRequestContext<Bool>().run(self.engine.wallet.refreshCard() |> castError(WalletCardUpdateError.self))
            await self.completeCardRefresh()
        }
    }

    private func completeCardRefresh() {
        self.cardRefreshTask = nil
        if self.cardRefreshAgain {
            self.cardRefreshAgain = false
            self.refreshCard()
        }
    }

    func receiveServerCard(_ card: WalletCard?, revision: UInt64) {
        guard !self.isShutdown, revision > self.latestCardRevision else { return }
        self.latestCardRevision = revision
        self.latestServerCard = card
        guard self.isStoredStateRestored else { return }
        self.publishCardState()
    }

    func mergeLatestServerCard(address: String?) {
        guard let address, let card = self.latestServerCard,
              walletEngineAddressesEqual(card.address, address), self.serverCardsByWallet[address] != card else { return }
        self.serverCardsByWallet[address] = card
        if !self.cardStickerDirtyWallets.contains(address) && self.cardStickerSavingAddress != address {
            self.applyServerCard(card, address: address)
        }
    }

    private func applyServerCard(_ card: WalletCard, address: String) {
        let previous = self.cardStickersByWallet[address] ?? []
        self.cardStickersByWallet[address] = card.stickers.compactMap { item in
            guard let sticker = WalletContext.CardSticker(serverSticker: item) else { return nil }
            let old = previous.first(where: { walletEngineAddressesEqual($0.gift.address, sticker.gift.address) })
            return sticker.withStyle(old?.style)
        }
    }

    private func publishCardState() {
        let previous = self.currentState
        self.replaceState(phase: self.currentState.phase, balance: self.currentState.balance,
            transactions: self.currentState.transactions, pendingTransfers: self.currentState.pendingTransfers,
            activeOperation: self.currentState.activeOperation)
        // A changed server baseline may not change the visible local draft.
        if previous == self.currentState { self.persistStoredState(self.currentState) }
    }

    func saveCardStickers(walletAddress: String) async {
        guard !self.isShutdown, case let .wallet(info) = self.currentState.phase,
              walletEngineAddressesEqual(info.address, walletAddress), self.cardStickerSavingAddress == nil,
              self.cardStickerDirtyWallets.contains(walletAddress) else { return }
        let submitted = (self.cardStickersByWallet[walletAddress] ?? []).map(\.serverSticker)
        self.cardStickerSavingAddress = walletAddress
        self.cardStickerSaveError = nil
        self.publishCardState()
        defer {
            if !self.isShutdown {
                if !self.cardStickerDirtyWallets.contains(walletAddress), self.cardStickerSaveSchedule.pending?.walletAddress == walletAddress {
                    self.cardStickerSaveSchedule.update(walletAddress: walletAddress, hasChanges: false, now: ProcessInfo.processInfo.systemUptime)
                }
                self.publishCardState()
                self.armCardStickerSave()
            }
        }
        do {
            let card = try await WalletSignalRequestContext<WalletCard>().run(self.engine.wallet.setCardStickers(submitted))
            self.cardStickerSavingAddress = nil
            guard !self.isShutdown, case let .wallet(current) = self.currentState.phase,
                  walletEngineAddressesEqual(current.address, walletAddress), walletEngineAddressesEqual(card.address, walletAddress) else { return }
            self.serverCardsByWallet[walletAddress] = card
            self.latestServerCard = card
            self.refreshCard(afterCurrentRequest: true)
            let currentLayout = (self.cardStickersByWallet[walletAddress] ?? []).map(\.serverSticker)
            if walletCardStickerLayoutsEqual(currentLayout, submitted) {
                self.cardStickerDirtyWallets.remove(walletAddress)
                self.applyServerCard(card, address: walletAddress)
            }
        } catch {
            self.cardStickerSavingAddress = nil
            guard !self.isShutdown, self.currentState.walletAddress == walletAddress else { return }
            self.cardStickerSaveError = (error as? WalletCardUpdateError) ?? .generic
        }
    }
}

struct WalletCardStickerSaveSchedule {
    struct Pending: Equatable {
        let walletAddress: String
        let deadline: TimeInterval
    }
    private(set) var pending: Pending?

    mutating func update(walletAddress: String, hasChanges: Bool, now: TimeInterval, immediate: Bool = false) {
        self.pending = hasChanges ? Pending(walletAddress: walletAddress, deadline: now + (immediate ? 0 : 15)) : nil
    }

    mutating func takeDue(walletAddress: String?, now: TimeInterval, requestInFlight: Bool) -> String? {
        guard let pending = self.pending else { return nil }
        guard pending.walletAddress == walletAddress else {
            self.pending = nil
            return nil
        }
        guard pending.deadline <= now, !requestInFlight else { return nil }
        self.pending = nil
        return pending.walletAddress
    }
}

@available(macOS 10.15, *)
extension WalletContextImpl {
    func scheduleCardStickerSave(immediate: Bool) {
        guard !self.isShutdown, case let .wallet(info) = self.currentState.phase else { return }
        self.cardStickerSaveSchedule.update(walletAddress: info.address,
            hasChanges: self.cardStickerDirtyWallets.contains(info.address),
            now: ProcessInfo.processInfo.systemUptime, immediate: immediate)
        self.armCardStickerSave()
    }

    func armCardStickerSave() {
        self.cardStickerSaveTask?.cancel()
        self.cardStickerSaveTask = nil
        self.cardStickerSaveRevision &+= 1
        guard !self.isShutdown, let pending = self.cardStickerSaveSchedule.pending else { return }
        let revision = self.cardStickerSaveRevision
        let delay = UInt64(ceil(max(0, pending.deadline - ProcessInfo.processInfo.systemUptime) * 1_000_000_000))
        self.cardStickerSaveTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: delay) } catch { return }
            await self?.performScheduledCardStickerSave(revision: revision)
        }
    }

    private func performScheduledCardStickerSave(revision: UInt64) async {
        guard !self.isShutdown, revision == self.cardStickerSaveRevision else { return }
        self.cardStickerSaveTask = nil
        guard let address = self.cardStickerSaveSchedule.takeDue(walletAddress: self.currentState.walletAddress,
            now: ProcessInfo.processInfo.systemUptime, requestInFlight: self.cardStickerSavingAddress != nil) else { return }
        await self.saveCardStickers(walletAddress: address)
    }
}
