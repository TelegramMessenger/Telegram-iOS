import Foundation
import SwiftSignalKit
import Postbox
internal import TelegramApi

public struct WalletNftFile: Codable, Equatable, Sendable {
    public let url: String
    public let accessHash: Int64
    public let size: Int32
    public let mimeType: String

    public init(url: String, accessHash: Int64, size: Int32, mimeType: String) {
        self.url = url
        self.accessHash = accessHash
        self.size = size
        self.mimeType = mimeType
    }

    init?(apiDocument: Api.WebDocument) {
        guard case let .webDocument(data) = apiDocument else { return nil }
        self.init(url: data.url, accessHash: data.accessHash, size: data.size, mimeType: data.mimeType)
    }

    public var resource: WebFileReferenceMediaResource {
        return WebFileReferenceMediaResource(url: self.url, size: Int64(self.size), accessHash: self.accessHash)
    }
}

public struct WalletNftAttribute: Codable, Equatable, Sendable {
    public let traitType: String
    public let value: String

    public init(traitType: String, value: String) {
        self.traitType = traitType
        self.value = value
    }
}

public struct WalletNftItem: Codable, Equatable, @unchecked Sendable {
    private enum CodingKeys: String, CodingKey {
        case collectionAddress
        case address
        case ownerAddress
        case index
        case name
        case description
        case image
        case imageSmall
        case contentUrl
        case lottie
        case attributes
        case extra
        case gift
        case giftData
    }

    public let collectionAddress: String?
    public let address: String
    public let ownerAddress: String
    public let index: String
    public let name: String?
    public let description: String?
    public let image: WalletNftFile?
    public let imageSmall: WalletNftFile?
    public let contentUrl: WalletNftFile?
    public let lottie: WalletNftFile?
    public let attributes: [WalletNftAttribute]?
    public let extra: String?
    public let gift: StarGift.UniqueGift?

    public init(collectionAddress: String?, address: String, ownerAddress: String, index: String, name: String?, description: String?, image: WalletNftFile?, imageSmall: WalletNftFile?, contentUrl: WalletNftFile?, lottie: WalletNftFile?, attributes: [WalletNftAttribute]?, extra: String?, gift: StarGift.UniqueGift? = nil) {
        self.collectionAddress = collectionAddress
        self.address = address
        self.ownerAddress = ownerAddress
        self.index = index
        self.name = name
        self.description = description
        self.image = image
        self.imageSmall = imageSmall
        self.contentUrl = contentUrl
        self.lottie = lottie
        self.attributes = attributes
        self.extra = extra
        self.gift = gift
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.collectionAddress = try container.decodeIfPresent(String.self, forKey: .collectionAddress)
        self.address = try container.decode(String.self, forKey: .address)
        self.ownerAddress = try container.decode(String.self, forKey: .ownerAddress)
        self.index = try container.decode(String.self, forKey: .index)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.image = try container.decodeIfPresent(WalletNftFile.self, forKey: .image)
        self.imageSmall = try container.decodeIfPresent(WalletNftFile.self, forKey: .imageSmall)
        self.contentUrl = try container.decodeIfPresent(WalletNftFile.self, forKey: .contentUrl)
        self.lottie = try container.decodeIfPresent(WalletNftFile.self, forKey: .lottie)
        self.attributes = try container.decodeIfPresent([WalletNftAttribute].self, forKey: .attributes)
        self.extra = try container.decodeIfPresent(String.self, forKey: .extra)
        if let data = try container.decodeIfPresent(Data.self, forKey: .gift) {
            self.gift = PostboxDecoder(buffer: MemoryBuffer(data: data)).decodeObjectForKey("_", decoder: { StarGift.UniqueGift(decoder: $0) }) as? StarGift.UniqueGift
        } else if let data = try container.decodeIfPresent(Data.self, forKey: .giftData) {
            self.gift = try? JSONDecoder().decode(StarGift.UniqueGift.self, from: data)
        } else {
            self.gift = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(self.collectionAddress, forKey: .collectionAddress)
        try container.encode(self.address, forKey: .address)
        try container.encode(self.ownerAddress, forKey: .ownerAddress)
        try container.encode(self.index, forKey: .index)
        try container.encodeIfPresent(self.name, forKey: .name)
        try container.encodeIfPresent(self.description, forKey: .description)
        try container.encodeIfPresent(self.image, forKey: .image)
        try container.encodeIfPresent(self.imageSmall, forKey: .imageSmall)
        try container.encodeIfPresent(self.contentUrl, forKey: .contentUrl)
        try container.encodeIfPresent(self.lottie, forKey: .lottie)
        try container.encodeIfPresent(self.attributes, forKey: .attributes)
        try container.encodeIfPresent(self.extra, forKey: .extra)
        if let gift = self.gift {
            let giftEncoder = PostboxEncoder()
            giftEncoder.encodeObject(gift, forKey: "_")
            try container.encode(giftEncoder.makeData(), forKey: .gift)
        }
    }

    init(apiItem: Api.wallet.NftItem) {
        switch apiItem {
        case let .nftItem(data):
            let extra: String?
            if case let .dataJSON(json)? = data.extra {
                extra = json.data
            } else {
                extra = nil
            }
            self.init(
                collectionAddress: data.collectionAddress, address: data.address,
                ownerAddress: data.ownerAddress, index: data.index,
                name: data.name, description: data.description,
                image: data.image.flatMap(WalletNftFile.init(apiDocument:)),
                imageSmall: data.imageSmall.flatMap(WalletNftFile.init(apiDocument:)),
                contentUrl: data.contentUrl.flatMap(WalletNftFile.init(apiDocument:)),
                lottie: data.lottie.flatMap(WalletNftFile.init(apiDocument:)),
                attributes: data.attributes.map { attributes in
                    attributes.map { attribute in
                        switch attribute {
                        case let .nftAttribute(value):
                            return WalletNftAttribute(traitType: value.traitType, value: value.value)
                        }
                    }
                },
                extra: extra,
                gift: data.gift.flatMap { apiGift in
                    guard case let .unique(gift) = StarGift(apiStarGift: apiGift) else { return nil }
                    return gift
                }
            )
        }
    }
}

public struct WalletNfts: Equatable, Sendable {
    public let items: [WalletNftItem]
    public let nextOffset: String?

    public init(items: [WalletNftItem], nextOffset: String?) {
        self.items = items
        self.nextOffset = nextOffset
    }
}

public enum WalletGetNftsError: Error, Equatable, Sendable {
    case generic
}

func _internal_getWalletNfts(account: Account, offset: String, limit: Int32) -> Signal<WalletNfts, WalletGetNftsError> {
    return account.network.request(Api.functions.wallet.getNfts(offset: offset, limit: min(20, max(1, limit))), automaticFloodWait: false)
    |> mapError { _ -> WalletGetNftsError in .generic }
    |> map { result -> WalletNfts in
        switch result {
        case let .nftItems(data):
            return WalletNfts(items: data.items.map(WalletNftItem.init(apiItem:)), nextOffset: data.nextOffset)
        }
    }
}
