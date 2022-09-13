import Foundation
import FileStorage

protocol QuickRepliesRepository {
    func getItems(telegramUserId: Int64) -> [QuickReply]
    func getItemWith(id: String) -> QuickReply?
    func add(_: QuickReply)
    func update(_: QuickReply)
    func delete(_: String)
    func delete(_: [String])
}

class QuickRepliesRepositoryImpl {
    
    //  MARK: - Dependencies
    
    private let database: QuickRepliesDatabase
    
    //  MARK: - Lifecycle
    
    init() {
        if #available(iOS 10.0, *) {
            database = QuickRepliesDatabaseImpl()
        } else {
            database = QuickRepliesDatabaseMock()
        }
    }
}

extension QuickRepliesRepositoryImpl: QuickRepliesRepository {
    func getItems(telegramUserId: Int64) -> [QuickReply] {
        do {
            return try database.getQuickRepliesWith(telegramUserId: telegramUserId)
        } catch {
            debugPrint(error)
            return []
        }
    }
    
    func getItemWith(id: String) -> QuickReply? {
        do {
            return try database.getItemWith(id: id)
        } catch {
            debugPrint(error)
            return nil
        }
    }
    
    func add(_ item: QuickReply) {
        do {
            try database.insertOrUpdate(quickReply: item)
        } catch {
            debugPrint(error)
        }
    }
    
    func update(_ item: QuickReply) {
        do {
            try database.insertOrUpdate(quickReply: item)
        } catch {
            debugPrint(error)
        }
    }
    
    func delete(_ id: String) {
        delete([id])
    }
    
    func delete(_ ids: [String]) {
        do {
            try database.delete(ids: ids)
        } catch {
            debugPrint(error)
        }
    }
}


