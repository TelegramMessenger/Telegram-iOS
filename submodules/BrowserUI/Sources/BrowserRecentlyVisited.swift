import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramUIPreferences

private struct RecentlyVisitedLinkItemId {
    public let rawValue: MemoryBuffer
    
    var value: String {
        return String(data: self.rawValue.makeData(), encoding: .utf8) ?? ""
    }
    
    init(_ rawValue: MemoryBuffer) {
        self.rawValue = rawValue
    }
    
    init?(_ value: String) {
        if let data = value.data(using: .utf8) {
            self.rawValue = MemoryBuffer(data: data)
        } else {
            return nil
        }
    }
}

public final class RecentVisitedLinkItem: Codable {
    private enum CodingKeys: String, CodingKey {
        case webPage
    }
    
    public let webPage: TelegramMediaWebpage
    
    public init(webPage: TelegramMediaWebpage) {
        self.webPage = webPage
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let webPageData = try container.decodeIfPresent(Data.self, forKey: .webPage) {
            self.webPage = PostboxDecoder(buffer: MemoryBuffer(data: webPageData)).decodeRootObject() as! TelegramMediaWebpage
        } else {
            fatalError()
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        let encoder = PostboxEncoder()
        encoder.encodeRootObject(self.webPage)
        let webPageData = encoder.makeData()
        try container.encode(webPageData, forKey: .webPage)
    }
}

func addRecentlyVisitedLink(engine: TelegramEngine, webPage: TelegramMediaWebpage) -> Signal<Never, NoError> {
    if let url = webPage.content.url, let itemId = RecentlyVisitedLinkItemId(url) {
        return engine.orderedLists.addOrMoveToFirstPosition(collectionId: ApplicationSpecificOrderedItemListCollectionId.browserRecentlyVisited, id: itemId.rawValue, item: RecentVisitedLinkItem(webPage: webPage), removeTailIfCountExceeds: 10)
    } else {
        return .complete()
    }
}

func removeRecentlyVisitedLink(engine: TelegramEngine, url: String) -> Signal<Never, NoError> {
    if let itemId = RecentlyVisitedLinkItemId(url) {
        return engine.orderedLists.removeItem(collectionId: ApplicationSpecificOrderedItemListCollectionId.browserRecentlyVisited, id: itemId.rawValue)
    } else {
        return .complete()
    }
}

func clearRecentlyVisitedLinks(engine: TelegramEngine) -> Signal<Never, NoError> {
    return engine.orderedLists.clear(collectionId: ApplicationSpecificOrderedItemListCollectionId.browserRecentlyVisited)
}

func recentlyVisitedLinks(engine: TelegramEngine) -> Signal<[TelegramMediaWebpage], NoError> {
    return engine.data.subscribe(TelegramEngine.EngineData.Item.OrderedLists.ListItems(collectionId: ApplicationSpecificOrderedItemListCollectionId.browserRecentlyVisited))
    |> map { items -> [TelegramMediaWebpage] in
        var result: [TelegramMediaWebpage] = []
        for item in items {
            if let link = item.contents.get(RecentVisitedLinkItem.self) {
                result.append(link.webPage)
            }
        }
        return result
    }
}
