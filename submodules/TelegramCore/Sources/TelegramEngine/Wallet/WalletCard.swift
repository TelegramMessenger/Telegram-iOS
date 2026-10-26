import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi

public struct WalletCard: Codable, Equatable, Sendable {
    public struct InputSticker: Codable, Equatable, Sendable {
        public let coordinates: MediaArea.Coordinates
        public let nftAddress: String

        public init(coordinates: MediaArea.Coordinates, nftAddress: String) {
            self.coordinates = coordinates
            self.nftAddress = nftAddress
        }
    }

    public struct Sticker: Codable, Equatable, Sendable {
        public let coordinates: MediaArea.Coordinates
        public let nft: WalletNftItem

        public init(coordinates: MediaArea.Coordinates, nft: WalletNftItem) {
            self.coordinates = coordinates
            self.nft = nft
        }
    }

    public let address: String
    public let balance: Int64
    public let stickers: [Sticker]
    public let backgroundNft: WalletNftItem?

    public init(address: String, balance: Int64, stickers: [Sticker], backgroundNft: WalletNftItem? = nil) {
        self.address = address
        self.balance = balance
        self.stickers = stickers
        self.backgroundNft = backgroundNft
    }

    init(apiCard: Api.wallet.Card) {
        switch apiCard {
        case let .card(data):
            self.init(address: data.address, balance: data.balance, stickers: (data.stickers ?? []).map { sticker in
                switch sticker {
                case let .cardSticker(data):
                    switch data.coordinates {
                    case let .mediaAreaCoordinates(c):
                        return Sticker(coordinates: .init(x: c.x, y: c.y, width: c.w, height: c.h,
                            rotation: c.rotation, cornerRadius: c.radius), nft: WalletNftItem(apiItem: data.nft))
                    }
                }
            }, backgroundNft: data.bgNftItem.map { WalletNftItem(apiItem: $0) })
        }
    }
}

public enum WalletCardUpdateError: Error, Equatable, Sendable {
    case unavailable
    case invalidSticker
    case limitExceeded
    case duplicate
    case invalidAddress
    case notOwned
    case invalidNft
    case savedInProfile
    case backgroundNotAllowed
    case floodWait(Int32)
    case generic

    init(description: String) {
        switch description {
        case "WALLET_UNAVAILABLE": self = .unavailable
        case "WALLET_STICKER_INVALID": self = .invalidSticker
        case "WALLET_STICKER_LIMIT_EXCEEDED": self = .limitExceeded
        case "WALLET_STICKER_DUPLICATE": self = .duplicate
        case "WALLET_ADDRESS_INVALID": self = .invalidAddress
        case "WALLET_NFT_NOT_OWNED": self = .notOwned
        case "WALLET_NFT_INVALID": self = .invalidNft
        case "WALLET_STICKER_SAVED_PROFILE": self = .savedInProfile
        case "WALLET_CARD_BG_NOT_ALLOWED": self = .backgroundNotAllowed
        default:
            if description.hasPrefix("FLOOD_WAIT_"), let seconds = Int32(description.dropFirst("FLOOD_WAIT_".count)) {
                self = .floodWait(seconds)
            } else { self = .generic }
        }
    }
}

func _internal_setWalletCardStickers(account: Account, stickers: [WalletCard.InputSticker], backgroundNftAddress: String?) -> Signal<WalletCard, WalletCardUpdateError> {
    if let backgroundNftAddress, !stickers.contains(where: { $0.nftAddress == backgroundNftAddress }) {
        return .fail(.invalidSticker)
    }
    guard stickers.count <= 10 else { return .fail(.limitExceeded) }
    guard Set(stickers.map(\.nftAddress)).count == stickers.count else { return .fail(.duplicate) }
    guard stickers.allSatisfy({ sticker in
        let c = sticker.coordinates
        return [c.x, c.y, c.width, c.height, c.rotation].allSatisfy { $0.isFinite }
            && (0...100).contains(c.x) && (0...100).contains(c.y)
            && c.width > 0 && c.width <= 100 && c.height > 0 && c.height <= 100
            && (c.cornerRadius.map { $0.isFinite && $0 >= 0 } ?? true)
    }) else { return .fail(.invalidSticker) }
    let input: [Api.InputWalletCardSticker] = stickers.map { sticker in
        let c = sticker.coordinates
        return .inputWalletCardSticker(.init(coordinates: .mediaAreaCoordinates(.init(
            flags: c.cornerRadius == nil ? 0 : 1, x: c.x, y: c.y, w: c.width, h: c.height,
            rotation: c.rotation, radius: c.cornerRadius)), nftAddress: sticker.nftAddress))
    }
    return account.network.request(Api.functions.wallet.setCardStickers(flags: backgroundNftAddress == nil ? 0 : 1, stickers: input, bgNftAddress: backgroundNftAddress), automaticFloodWait: false)
    |> mapError { WalletCardUpdateError(description: $0.errorDescription) }
    |> map { WalletCard(apiCard: $0) }
}
