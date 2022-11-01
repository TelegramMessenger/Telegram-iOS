import FileStorage
import Foundation

struct ChatStatsMeta: Codable {
    let id: Int64
    let sharedAt: Date
}

class ChatStatsMetaStorage {
    
    //  MARK: - Dependencies
    
    private let storage = FileStorage<[Int64: ChatStatsMeta]>(path: "chat-stats-meta")
    
    //  MARK: - Lifecycle
    
    init() {}
    
    //  MARK: - Public Functions

    func getSharedAt(peerId: Int64) -> Date? {
        var dict = storage.read() ?? [:]
        return dict[peerId]?.sharedAt
    }

    func setSharedAt(_ sharedAt: Date, peerId: Int64) {
        var dict = storage.read() ?? [:]
        dict[peerId] = ChatStatsMeta(id: peerId, sharedAt: sharedAt)
        storage.save(dict)
    }
    
    public func removeItems(whereSharedAt: (Date) -> Bool) {
        var dict = storage.read() ?? [:]
        for (id, meta) in dict {
            if whereSharedAt(meta.sharedAt) {
                dict.removeValue(forKey: id)
            }
        }
        storage.save(dict)
    }
}
