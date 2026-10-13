import Foundation
import SwiftSignalKit
import TelegramApi

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

public struct WalletNftItem: Codable, Equatable, Sendable {
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

    public init(collectionAddress: String?, address: String, ownerAddress: String, index: String, name: String?, description: String?, image: WalletNftFile?, imageSmall: WalletNftFile?, contentUrl: WalletNftFile?, lottie: WalletNftFile?, attributes: [WalletNftAttribute]?, extra: String?) {
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
                extra: extra
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
