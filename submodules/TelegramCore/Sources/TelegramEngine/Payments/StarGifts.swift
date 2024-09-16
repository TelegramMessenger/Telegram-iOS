import Foundation
import Postbox
import MtProtoKit
import SwiftSignalKit
import TelegramApi

public final class StarGiftsList: Codable, Equatable {
    public let items: [StarGift]
    public let hashValue: Int32

    public init(items: [StarGift], hashValue: Int32) {
        self.items = items
        self.hashValue = hashValue
    }

    public static func ==(lhs: StarGiftsList, rhs: StarGiftsList) -> Bool {
        if lhs === rhs {
            return true
        }
        if lhs.items != rhs.items {
            return false
        }
        if lhs.hashValue != rhs.hashValue {
            return false
        }
        return true
    }
}

public struct StarGift: Equatable, Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case file
        case price
        case availability
    }
    
    public struct Availability: Equatable, Codable {
        enum CodingKeys: String, CodingKey {
            case remains
            case total
        }

        public let remains: Int32
        public let total: Int32
    }
    
    public enum DecodingError: Error {
        case generic
    }
    
    public let id: Int64
    public let file: TelegramMediaFile
    public let price: Int64
    public let availability: Availability?
    
    public init(id: Int64, file: TelegramMediaFile, price: Int64, availability: Availability?) {
        self.id = id
        self.file = file
        self.price = price
        self.availability = availability
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int64.self, forKey: .id)
        
        if let fileData = try container.decodeIfPresent(Data.self, forKey: .file), let file = PostboxDecoder(buffer: MemoryBuffer(data: fileData)).decodeRootObject() as? TelegramMediaFile {
            self.file = file
        } else {
            throw DecodingError.generic
        }
        
        self.price = try container.decode(Int64.self, forKey: .price)
        self.availability = try container.decodeIfPresent(Availability.self, forKey: .availability)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
    
        let encoder = PostboxEncoder()
        encoder.encodeRootObject(self.file)
        let fileData = encoder.makeData()
        try container.encode(fileData, forKey: .file)
        
        try container.encode(self.price, forKey: .price)
        try container.encodeIfPresent(self.availability, forKey: .availability)
    }
}

extension StarGift {
    init?(apiStarGift: Api.StarGift) {
        switch apiStarGift {
        case let .starGift(_, id, sticker, stars, availabilityRemains, availabilityTotal):
            var availability: Availability?
            if let availabilityRemains, let availabilityTotal {
                availability = Availability(remains: availabilityRemains, total: availabilityTotal)
            }
            guard let file = telegramMediaFileFromApiDocument(sticker) else {
                return nil
            }
            self.init(id: id, file: file, price: stars, availability: availability)
        }
    }
}

func _internal_cachedStarGifts(postbox: Postbox) -> Signal<StarGiftsList?, NoError> {
    let viewKey: PostboxViewKey = .preferences(keys: Set([PreferencesKeys.starGifts()]))
    return postbox.combinedView(keys: [viewKey])
    |> map { views -> StarGiftsList? in
        guard let view = views.views[viewKey] as? PreferencesView else {
            return nil
        }
        guard let value = view.values[PreferencesKeys.starGifts()]?.get(StarGiftsList.self) else {
            return nil
        }
        return value
    }
}

func _internal_keepCachedStarGiftsUpdated(postbox: Postbox, network: Network) -> Signal<Never, NoError> {
    let updateSignal = _internal_cachedStarGifts(postbox: postbox)
    |> take(1)
    |> mapToSignal { list -> Signal<Never, NoError> in
        return network.request(Api.functions.payments.getStarGifts(hash: 0))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.payments.StarGifts?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<Never, NoError> in
            guard let result else {
                return .complete()
            }
            
            return postbox.transaction { transaction in
                switch result {
                case let .starGifts(hash, gifts):
                    let starGiftsLists = StarGiftsList(items: gifts.compactMap { StarGift(apiStarGift: $0) }, hashValue: hash)
                    transaction.setPreferencesEntry(key: PreferencesKeys.starGifts(), value: PreferencesEntry(starGiftsLists))
                case .starGiftsNotModified:
                    break
                }
            }
            |> ignoreValues
        }
    }
    
    return updateSignal
}

func managedStarGiftsUpdates(postbox: Postbox, network: Network) -> Signal<Never, NoError> {
    let poll = _internal_keepCachedStarGiftsUpdated(postbox: postbox, network: network)
    return (poll |> then(.complete() |> suspendAwareDelay(2.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}
