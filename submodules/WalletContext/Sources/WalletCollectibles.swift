import Foundation
import TelegramCore
import WalletEngineFFI

let walletCollectiblesFetchLimit: Int32 = 20
private let walletTelegramAnonymousNumbersCollection = "0:0e41dc1dc3c9067ed24248580e12b3359818d83dee0304fabcf80845eafafdb2"
private let walletTelegramUsernamesCollection = "0:80d78a35f955a14b679faa887ff4cd5bfc0f43b4a4eea2a7e6927f3701b273c2"

@available(macOS 10.15, *)
public extension WalletContext.Transaction.CollectibleTransfer {
    init(collectible: WalletContext.Collectible) {
        let kind: Kind
        switch collectible.kind {
        case .gift:
            kind = .gift
        case .username:
            kind = .username
        case .anonymousNumber:
            kind = .anonymousNumber
        case .other:
            kind = .other
        }
        self.init(
            address: collectible.address,
            name: collectible.name,
            image: collectible.image,
            thumbnail: collectible.thumbnail,
            lottie: collectible.lottie,
            collectionName: collectible.collectionName,
            collectionUrl: collectible.collectionUrl,
            kind: kind
        )
    }
}

@available(macOS 10.15, *)
func walletCollectible(from nft: WalletNftItem) -> WalletContext.Collectible {
    let extra = nft.extra.flatMap { $0.data(using: .utf8) }.flatMap {
        (try? JSONSerialization.jsonObject(with: $0)) as? [String: Any]
    } ?? [:]
    let collection = extra["collection"] as? [String: Any] ?? [:]
    let collectionName = nonEmptyCollectibleString(extra["collection_name"] as? String)
        ?? nonEmptyCollectibleString(collection["name"] as? String)
    let collectionUrl = normalizedFragmentCollectibleUrl(extra["collection_url"] as? String)
        ?? normalizedFragmentCollectibleUrl(collection["external_link"] as? String)
        ?? normalizedFragmentCollectibleUrl(collection["url"] as? String)
    let name = nonEmptyCollectibleString(nft.name) ?? shortenedCollectibleAddress(nft.address)

    let urlKeys = ["uri", "metadata_url", "content_uri", "external_link", "url"]
    let urls = (urlKeys.compactMap { extra[$0] as? String }
        + extra.keys.sorted().filter { !urlKeys.contains($0) }.compactMap { extra[$0] as? String }
        + [nft.lottie, nft.image, nft.imageSmall, nft.contentUrl].compactMap { $0?.url })
        .compactMap(fragmentCollectibleUrl)
    let collectionAddress = nft.collectionAddress.map(collectibleAddressKey)
    let kind: WalletContext.Collectible.Kind
    if collectionAddress == walletTelegramUsernamesCollection {
        kind = .username
    } else if collectionAddress == walletTelegramAnonymousNumbersCollection {
        kind = .anonymousNumber
    } else if urls.contains(where: { $0.path.lowercased().hasPrefix("/gift/") }) {
        kind = .gift
    } else if urls.contains(where: { $0.path.lowercased().hasPrefix("/username/") }) {
        kind = .username
    } else if urls.contains(where: { $0.path.lowercased().hasPrefix("/number/") }) {
        kind = .anonymousNumber
    } else {
        kind = .other
    }

    var attributes: [String: String] = [:]
    for attribute in nft.attributes ?? [] {
        if let key = nonEmptyCollectibleString(attribute.traitType)?.lowercased(),
           let value = nonEmptyCollectibleString(attribute.value) {
            attributes[key] = value
        }
    }
    let subtitle: String
    if kind == .gift, let model = attributes["model"], let backdrop = attributes["backdrop"] {
        subtitle = "\(model) on \(backdrop)"
    } else {
        switch kind {
        case .username: subtitle = "Username"
        case .anonymousNumber: subtitle = "Anonymous Number"
        case .gift, .other: subtitle = collectionName ?? "NFT"
        }
    }
    return WalletContext.Collectible(
        address: collectibleAddressKey(nft.address),
        name: name,
        subtitle: subtitle,
        kind: kind,
        description: nft.description,
        collectionName: collectionName,
        collectionUrl: collectionUrl,
        attributes: attributes,
        giftSlug: kind == .gift ? walletCollectibleGiftSlug(name: name, urls: urls) : nil,
        nft: nft
    )
}

@available(macOS 10.15, *)
private func walletCollectibleGiftSlug(name: String, urls: [URL]) -> String? {
    if let hash = name.lastIndex(of: "#") {
        let title = name[..<hash].filter { $0.isLetter || $0.isNumber }
        let number = name[name.index(after: hash)...].trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty, !number.isEmpty, number.allSatisfy(\.isNumber) {
            return String(title) + "-" + number
        }
    }
    guard let url = urls.first(where: { $0.path.lowercased().hasPrefix("/gift/") }) else { return nil }
    let path = url.path.split(separator: "/")
    guard path.count >= 2 else { return nil }
    return nonEmptyCollectibleString((String(path[1]) as NSString).deletingPathExtension)
}

private func nonEmptyCollectibleString(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
    return value
}

private func fragmentCollectibleUrl(_ value: String) -> URL? {
    guard let url = URL(string: value), url.scheme?.lowercased() == "https",
          let host = url.host?.lowercased(), ["fragment.com", "nft.fragment.com"].contains(host) else {
        return nil
    }
    return url
}

private func normalizedFragmentCollectibleUrl(_ value: String?) -> String? {
    guard let value, let url = fragmentCollectibleUrl(value), url.host?.lowercased() == "fragment.com" else { return nil }
    return url.absoluteString
}

@available(macOS 10.15, *)
private func collectibleAddressKey(_ address: String) -> String {
    return (try? convertTonAddress(value: address, format: .raw).lowercased()) ?? address
}

func shortenedCollectibleAddress(_ address: String) -> String {
    return address.count > 14 ? "\(address.prefix(6))…\(address.suffix(6))" : address
}

@available(macOS 10.15, *)
extension WalletContext.CollectiblesState {
    func acceptsPage(_ page: PageId) -> Bool {
        return !self.isRefreshing && self.nextPage == page
    }

    func startingRefresh() -> Self {
        return Self(items: self.items, nextOffset: self.nextOffset, generation: self.generation &+ 1,
                    isRefreshing: true, isLoadingMore: false, error: nil)
    }

    func cancellingRequests() -> Self {
        return Self(items: self.items, nextOffset: self.nextOffset, generation: self.generation &+ 1,
                    isLoadingMore: false, error: self.error)
    }

    func applying(_ page: WalletNfts, offset: String, refresh: Bool) throws -> Self {
        guard page.nextOffset != offset else { throw WalletContext.SynchronizationError.invalidData }
        var items = refresh ? [] : self.items
        var indices: [String: Int] = [:]
        for (index, item) in items.enumerated() {
            indices[collectibleAddressKey(item.address)] = index
        }
        for nft in page.items {
            let item = walletCollectible(from: nft)
            let key = collectibleAddressKey(item.address)
            if let index = indices[key] {
                items[index] = item
            } else {
                indices[key] = items.count
                items.append(item)
            }
        }
        return Self(items: items, nextOffset: page.nextOffset, generation: self.generation,
                    isLoadingMore: false, error: nil)
    }

    func failing(_ error: Error) -> Self {
        return Self(items: self.items, nextOffset: self.nextOffset, generation: self.generation,
                    isLoadingMore: false,
                    error: error is CancellationError ? self.error : synchronizationError(error))
    }
}
