import Foundation
import sqlcipher
#if os(macOS)
    import SwiftSignalKitMac
#else
    import SwiftSignalKit
#endif

private func checkTableKey(_ table: ValueBoxTable, _ key: ValueBoxKey) {
    switch table.keyType {
        case .binary:
            break
        case .int64:
            assert(key.length == 8)
    }
}

struct SqlitePreparedStatement {
    let statement: OpaquePointer?
    
    func bind(_ index: Int, data: UnsafeRawPointer, length: Int) {
        sqlite3_bind_blob(statement, Int32(index), data, Int32(length), nil)
    }
    
    func bindText(_ index: Int, data: UnsafeRawPointer, length: Int) {
        sqlite3_bind_text(statement, Int32(index), data.assumingMemoryBound(to: Int8.self), Int32(length), SQLITE_VAR_TRANSIENT)
    }
    
    func bind(_ index: Int, number: Int64) {
        sqlite3_bind_int64(statement, Int32(index), number)
    }
    
    func bindNull(_ index: Int) {
        sqlite3_bind_null(statement, Int32(index))
    }
    
    func bind(_ index: Int, number: Int32) {
        sqlite3_bind_int(statement, Int32(index), number)
    }
    
    func reset() {
        sqlite3_reset(statement)
        sqlite3_clear_bindings(statement)
    }
    
    func step(handle: OpaquePointer?, _ initial: Bool = false, path: String?) -> Bool {
        let res = sqlite3_step(statement)
        if res != SQLITE_ROW && res != SQLITE_DONE {
            if let error = sqlite3_errmsg(handle), let str = NSString(utf8String: error) {
                print("SQL error \(res): \(str) on step")
            } else {
                print("SQL error \(res) on step")
            }
            
            if res == SQLITE_CORRUPT {
                if let path = path {
                    postboxLog("Corrupted DB at step, dropping")
                    try? FileManager.default.removeItem(atPath: path)
                    preconditionFailure()
                }
            }
        }
        return res == SQLITE_ROW
    }
    
    func int64At(_ index: Int) -> Int64 {
        return sqlite3_column_int64(statement, Int32(index))
    }
    
    func valueAt(_ index: Int) -> ReadBuffer {
        let valueLength = sqlite3_column_bytes(statement, Int32(index))
        let valueData = sqlite3_column_blob(statement, Int32(index))
        
        let valueMemory = malloc(Int(valueLength))!
        memcpy(valueMemory, valueData, Int(valueLength))
        return ReadBuffer(memory: valueMemory, length: Int(valueLength), freeWhenDone: true)
    }
    
    func stringAt(_ index: Int) -> String? {
        let valueLength = sqlite3_column_bytes(statement, Int32(index))
        if let valueData = sqlite3_column_blob(statement, Int32(index)) {
            return String(data: Data(bytes: valueData, count: Int(valueLength)), encoding: .utf8)
        } else {
            return nil
        }
    }
    
    func keyAt(_ index: Int) -> ValueBoxKey {
        let valueLength = sqlite3_column_bytes(statement, Int32(index))
        let valueData = sqlite3_column_blob(statement, Int32(index))
        
        let key = ValueBoxKey(length: Int(valueLength))
        memcpy(key.memory, valueData, Int(valueLength))
        return key
    }
    
    func int64KeyAt(_ index: Int) -> ValueBoxKey {
        let value = sqlite3_column_int64(statement, Int32(index))
        
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: value)
        return key
    }
    
    func int64KeyValueAt(_ index: Int) -> Int64 {
        return sqlite3_column_int64(statement, Int32(index))
    }
    
    func destroy() {
        sqlite3_finalize(statement)
    }
}

final class SqliteValueBox: ValueBox {
    private let lock = NSRecursiveLock()
    
    fileprivate let basePath: String
    private let databasePath: String
    private var database: Database!
    private var tables: [Int32: ValueBoxTable] = [:]
    private var fullTextTables: [Int32: ValueBoxFullTextTable] = [:]
    private var getStatements: [Int32 : SqlitePreparedStatement] = [:]
    private var rangeKeyAscStatementsLimit: [Int32 : SqlitePreparedStatement] = [:]
    private var rangeKeyAscStatementsNoLimit: [Int32 : SqlitePreparedStatement] = [:]
    private var rangeKeyDescStatementsLimit: [Int32 : SqlitePreparedStatement] = [:]
    private var rangeKeyDescStatementsNoLimit: [Int32 : SqlitePreparedStatement] = [:]
    private var deleteRangeStatements: [Int32 : SqlitePreparedStatement] = [:]
    private var rangeValueAscStatementsLimit: [Int32 : SqlitePreparedStatement] = [:]
    private var rangeValueAscStatementsNoLimit: [Int32 : SqlitePreparedStatement] = [:]
    private var rangeValueDescStatementsLimit: [Int32 : SqlitePreparedStatement] = [:]
    private var rangeValueDescStatementsNoLimit: [Int32 : SqlitePreparedStatement] = [:]
    private var scanStatements: [Int32 : SqlitePreparedStatement] = [:]
    private var scanKeysStatements: [Int32 : SqlitePreparedStatement] = [:]
    private var existsStatements: [Int32 : SqlitePreparedStatement] = [:]
    private var updateStatements: [Int32 : SqlitePreparedStatement] = [:]
    private var insertStatements: [Int32 : SqlitePreparedStatement] = [:]
    private var insertOrReplaceStatements: [Int32 : SqlitePreparedStatement] = [:]
    private var deleteStatements: [Int32 : SqlitePreparedStatement] = [:]
    private var moveStatements: [Int32 : SqlitePreparedStatement] = [:]
    private var fullTextInsertStatements: [Int32 : SqlitePreparedStatement] = [:]
    private var fullTextDeleteStatements: [Int32 : SqlitePreparedStatement] = [:]
    private var fullTextMatchGlobalStatements: [Int32 : SqlitePreparedStatement] = [:]
    private var fullTextMatchCollectionStatements: [Int32 : SqlitePreparedStatement] = [:]
    private var fullTextMatchCollectionTagsStatements: [Int32 : SqlitePreparedStatement] = [:]
    
    private var secureDeleteEnabled: Bool = false
    
    private var readQueryTime: CFAbsoluteTime = 0.0
    private var writeQueryTime: CFAbsoluteTime = 0.0
    private var commitTime: CFAbsoluteTime = 0.0
    
    private let checkpoints = MetaDisposable()
    
    private let queue: Queue
    
    public init(basePath: String, queue: Queue) {
        self.basePath = basePath
        self.databasePath = basePath + "/db_sqlite"
        self.queue = queue
        self.database = self.openDatabase()
    }
    
    deinit {
        assert(self.queue.isCurrent())
        self.clearStatements()
        checkpoints.dispose()
    }
    
    private func openDatabase() -> Database {
        assert(self.queue.isCurrent())
        
        checkpoints.set(nil)
        lock.lock()
        
        let _ = try? FileManager.default.createDirectory(atPath: basePath, withIntermediateDirectories: true, attributes: nil)
        let path = basePath + "/db_sqlite"
        let database: Database
        if let result = Database(path) {
            database = result
        } else {
            postboxLog("Couldn't open DB")
            preconditionFailure("Couldn't open database")
            //let _ = try? FileManager.default.removeItem(atPath: path)
            //database = Database(path)!
        }
        
        sqlite3_busy_timeout(database.handle, 1000 * 10000)
        
        var resultCode: Bool
        
        //database.execute("PRAGMA cache_size=-2097152")
        resultCode = database.execute("PRAGMA mmap_size=0")
        assert(resultCode)
        resultCode = database.execute("PRAGMA synchronous=NORMAL")
        assert(resultCode)
        resultCode = database.execute("PRAGMA journal_mode=WAL")
        assert(resultCode)
        resultCode = database.execute("PRAGMA temp_store=MEMORY")
        assert(resultCode)
        //resultCode = database.execute("PRAGMA wal_autocheckpoint=500")
        //database.execute("PRAGMA journal_size_limit=1536")
        
        /*#if DEBUG
        var statement: OpaquePointer? = nil
        sqlite3_prepare_v2(database.handle, "PRAGMA integrity_check", -1, &statement, nil)
        let preparedStatement = SqlitePreparedStatement(statement: statement)
        while preparedStatement.step(handle: database.handle, path: self.databasePath) {
            let value = preparedStatement.valueAt(0)
            let text = String(data: Data(bytes: value.memory.assumingMemoryBound(to: UInt8.self), count: value.length), encoding: .utf8)
            print("integrity_check: \(text ?? "")")
            assert(text == "ok")
            //let value = preparedStatement.stringAt(0)
            //print("integrity_check: \(value)")
        }
        preparedStatement.destroy()
        #endif*/
        
        let _ = self.runPragma(database, "checkpoint_fullfsync = 1")
        assert(self.runPragma(database, "checkpoint_fullfsync") == "1")
        
        let result = self.getUserVersion(database)
        if result < 2 {
            resultCode = database.execute("PRAGMA user_version=3")
            assert(resultCode)
            resultCode = database.execute("DROP TABLE IF EXISTS __meta_tables")
            assert(resultCode)
            resultCode = database.execute("CREATE TABLE __meta_tables (name INTEGER, keyType INTEGER)")
            assert(resultCode)
            resultCode = database.execute("CREATE TABLE __meta_fulltext_tables (name INTEGER)")
            assert(resultCode)
        } else if result < 3 {
            resultCode = database.execute("PRAGMA user_version=3")
            assert(resultCode)
            resultCode = database.execute("CREATE TABLE __meta_fulltext_tables (name INTEGER)")
            assert(resultCode)
        }
        
        for table in self.listTables(database) {
            self.tables[table.id] = table
        }
        for table in self.listFullTextTables(database) {
            self.fullTextTables[table.id] = table
        }
        lock.unlock()
        
        /*checkpoints.set((Signal<Void, NoError>.single(Void()) |> delay(10.0, queue: self.queue) |> restart).start(next: { [weak self] _ in
            if let strongSelf = self, strongSelf.database != nil {
                assert(strongSelf.queue.isCurrent())
                strongSelf.lock.lock()
                var nLog: Int32 = 0
                var nFrames: Int32 = 0
                let result = sqlite3_wal_checkpoint_v2(strongSelf.database.handle, nil, SQLITE_CHECKPOINT_PASSIVE, &nLog, &nFrames)
                assert(result == SQLITE_OK)
                strongSelf.lock.unlock()
                print("(SQLite WAL size \(nLog) removed \(nFrames))")
            }
        }))*/
        return database
    }
    
    public func beginStats() {
        self.readQueryTime = 0.0
        self.writeQueryTime = 0.0
        self.commitTime = 0.0
    }
    
    public func endStats() {
        print("(SqliteValueBox stats read: \(self.readQueryTime * 1000.0) ms, write: \(self.writeQueryTime * 1000.0) ms, commit: \(self.commitTime * 1000.0) ms")
    }
    
    public func begin() {
        assert(self.queue.isCurrent())
        let resultCode = self.database.execute("BEGIN IMMEDIATE")
        assert(resultCode)
    }
    
    public func commit() {
        assert(self.queue.isCurrent())
        let startTime = CFAbsoluteTimeGetCurrent()
        let resultCode = self.database.execute("COMMIT")
        assert(resultCode)
        self.commitTime += CFAbsoluteTimeGetCurrent() - startTime
    }
    
    private func getUserVersion(_ database: Database) -> Int64 {
        assert(self.queue.isCurrent())
        var statement: OpaquePointer? = nil
        let status = sqlite3_prepare_v2(database.handle, "PRAGMA user_version", -1, &statement, nil)
        assert(status == SQLITE_OK)
        let preparedStatement = SqlitePreparedStatement(statement: statement)
        let _ = preparedStatement.step(handle: database.handle, path: self.databasePath)
        let value = preparedStatement.int64At(0)
        preparedStatement.destroy()
        return value
    }
    
    private func runPragma(_ database: Database, _ pragma: String) -> String {
        assert(self.queue.isCurrent())
        var statement: OpaquePointer? = nil
        let status = sqlite3_prepare_v2(database.handle, "PRAGMA \(pragma)", -1, &statement, nil)
        assert(status == SQLITE_OK)
        let preparedStatement = SqlitePreparedStatement(statement: statement)
        var result: String?
        if preparedStatement.step(handle: database.handle, path: self.databasePath) {
            result = preparedStatement.stringAt(0)
        }
        preparedStatement.destroy()
        return result ?? ""
    }
    
    private func listTables(_ database: Database) -> [ValueBoxTable] {
        assert(self.queue.isCurrent())
        var statement: OpaquePointer? = nil
        let status = sqlite3_prepare_v2(database.handle, "SELECT name, keyType FROM __meta_tables", -1, &statement, nil)
        assert(status == SQLITE_OK)
        let preparedStatement = SqlitePreparedStatement(statement: statement)
        var tables: [ValueBoxTable] = []
        
        while preparedStatement.step(handle: database.handle, true, path: self.databasePath) {
            let value = preparedStatement.int64At(0)
            let keyType = preparedStatement.int64At(1)
            tables.append(ValueBoxTable(id: Int32(value), keyType: ValueBoxKeyType(rawValue: Int32(keyType))!))
        }
        preparedStatement.destroy()
        return tables
    }
    
    private func listFullTextTables(_ database: Database) -> [ValueBoxFullTextTable] {
        assert(self.queue.isCurrent())
        var statement: OpaquePointer? = nil
        let status = sqlite3_prepare_v2(database.handle, "SELECT name FROM __meta_fulltext_tables", -1, &statement, nil)
        assert(status == SQLITE_OK)
        let preparedStatement = SqlitePreparedStatement(statement: statement)
        var tables: [ValueBoxFullTextTable] = []
        
        while preparedStatement.step(handle: database.handle, true, path: self.databasePath) {
            let value = preparedStatement.int64At(0)
            tables.append(ValueBoxFullTextTable(id: Int32(value)))
        }
        preparedStatement.destroy()
        return tables
    }
    
    private func checkTable(_ table: ValueBoxTable) {
        assert(self.queue.isCurrent())
        if let currentTable = self.tables[table.id] {
            precondition(currentTable.keyType == table.keyType)
        } else {
            switch table.keyType {
                case .binary:
                    var resultCode: Bool
                    resultCode = self.database.execute("CREATE TABLE t\(table.id) (key BLOB, value BLOB)")
                    assert(resultCode)
                    resultCode = self.database.execute("CREATE INDEX t\(table.id)_key ON t\(table.id) (key)")
                    assert(resultCode)
                case .int64:
                    let resultCode = self.database.execute("CREATE TABLE t\(table.id) (key INTEGER PRIMARY KEY, value BLOB)")
                    assert(resultCode)
            }
            self.tables[table.id] = table
            let resultCode = self.database.execute("INSERT INTO __meta_tables(name, keyType) VALUES (\(table.id), \(table.keyType.rawValue))")
            assert(resultCode)
        }
    }
    
    private func checkFullTextTable(_ table: ValueBoxFullTextTable) {
        assert(self.queue.isCurrent())
        if let _ = self.fullTextTables[table.id] {
        } else {
            var resultCode = self.database.execute("CREATE VIRTUAL TABLE ft\(table.id) USING fts5(collectionId, itemId, contents, tags)")
            assert(resultCode)
            self.fullTextTables[table.id] = table
            resultCode = self.database.execute("INSERT INTO __meta_fulltext_tables(name) VALUES (\(table.id))")
            assert(resultCode)
        }
    }
    
    private func getStatement(_ table: ValueBoxTable, key: ValueBoxKey) -> SqlitePreparedStatement {
        assert(self.queue.isCurrent())
        checkTableKey(table, key)
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.getStatements[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "SELECT value FROM t\(table.id) WHERE key=?", -1, &statement, nil)
            assert(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.getStatements[table.id] = preparedStatement
            resultStatement =  preparedStatement
        }
        
        resultStatement.reset()
        
        switch table.keyType {
            case .binary:
                resultStatement.bind(1, data: key.memory, length: key.length)
            case .int64:
                resultStatement.bind(1, number: key.getInt64(0))
        }
        
        return resultStatement
    }
    
    private func rangeKeyAscStatementLimit(_ table: ValueBoxTable, start: ValueBoxKey, end: ValueBoxKey, limit: Int) -> SqlitePreparedStatement {
        assert(self.queue.isCurrent())
        checkTableKey(table, start)
        checkTableKey(table, end)
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.rangeKeyAscStatementsLimit[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "SELECT key FROM t\(table.id) WHERE key > ? AND key < ? ORDER BY key ASC LIMIT ?", -1, &statement, nil)
            assert(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.rangeKeyAscStatementsLimit[table.id] = preparedStatement
            resultStatement = preparedStatement
        }
        resultStatement.reset()
        
        switch table.keyType {
            case .binary:
                resultStatement.bind(1, data: start.memory, length: start.length)
                resultStatement.bind(2, data: end.memory, length: end.length)
            case .int64:
                resultStatement.bind(1, number: start.getInt64(0))
                resultStatement.bind(2, number: end.getInt64(0))
        }
        resultStatement.bind(3, number: Int32(limit))
        
        return resultStatement
    }
    
    private func rangeKeyAscStatementNoLimit(_ table: ValueBoxTable, start: ValueBoxKey, end: ValueBoxKey) ->
        SqlitePreparedStatement {
        assert(self.queue.isCurrent())
        checkTableKey(table, start)
        checkTableKey(table, end)
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.rangeKeyAscStatementsNoLimit[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "SELECT key FROM t\(table.id) WHERE key > ? AND key < ? ORDER BY key ASC", -1, &statement, nil)
            assert(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.rangeKeyAscStatementsNoLimit[table.id] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        switch table.keyType {
            case .binary:
                resultStatement.bind(1, data: start.memory, length: start.length)
                resultStatement.bind(2, data: end.memory, length: end.length)
            case .int64:
                resultStatement.bind(1, number: start.getInt64(0))
                resultStatement.bind(2, number: end.getInt64(0))
        }
        
        return resultStatement
    }
    
    private func rangeKeyDescStatementLimit(_ table: ValueBoxTable, start: ValueBoxKey, end: ValueBoxKey, limit: Int) -> SqlitePreparedStatement {
        assert(self.queue.isCurrent())
        let resultStatement: SqlitePreparedStatement
        checkTableKey(table, start)
        checkTableKey(table, end)
        
        if let statement = self.rangeKeyDescStatementsLimit[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "SELECT key FROM t\(table.id) WHERE key > ? AND key < ? ORDER BY key DESC LIMIT ?", -1, &statement, nil)
            assert(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.rangeKeyDescStatementsLimit[table.id] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        switch table.keyType {
            case .binary:
                resultStatement.bind(1, data: start.memory, length: start.length)
                resultStatement.bind(2, data: end.memory, length: end.length)
            case .int64:
                resultStatement.bind(1, number: start.getInt64(0))
                resultStatement.bind(2, number: end.getInt64(0))
        }
        resultStatement.bind(3, number: Int32(limit))
        
        return resultStatement
    }
    
    private func rangeKeyDescStatementNoLimit(_ table: ValueBoxTable, start: ValueBoxKey, end: ValueBoxKey) -> SqlitePreparedStatement {
        assert(self.queue.isCurrent())
        let resultStatement: SqlitePreparedStatement
        checkTableKey(table, start)
        checkTableKey(table, end)
        
        if let statement = self.rangeKeyDescStatementsNoLimit[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "SELECT key FROM t\(table.id) WHERE key > ? AND key < ? ORDER BY key DESC", -1, &statement, nil)
            assert(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.rangeKeyDescStatementsNoLimit[table.id] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        switch table.keyType {
            case .binary:
                resultStatement.bind(1, data: start.memory, length: start.length)
                resultStatement.bind(2, data: end.memory, length: end.length)
            case .int64:
                resultStatement.bind(1, number: start.getInt64(0))
                resultStatement.bind(2, number: end.getInt64(0))
        }
        
        return resultStatement
    }
    
    private func rangeDeleteStatement(_ table: ValueBoxTable, start: ValueBoxKey, end: ValueBoxKey) -> SqlitePreparedStatement {
        assert(self.queue.isCurrent())
        let resultStatement: SqlitePreparedStatement
        checkTableKey(table, start)
        checkTableKey(table, end)
        assert(start <= end)
        
        if let statement = self.deleteRangeStatements[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "DELETE FROM t\(table.id) WHERE key >= ? AND key <= ?", -1, &statement, nil)
            assert(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.deleteRangeStatements[table.id] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        switch table.keyType {
            case .binary:
                resultStatement.bind(1, data: start.memory, length: start.length)
                resultStatement.bind(2, data: end.memory, length: end.length)
            case .int64:
                resultStatement.bind(1, number: start.getInt64(0))
                resultStatement.bind(2, number: end.getInt64(0))
        }
        
        return resultStatement
    }
    
    private func rangeValueAscStatementLimit(_ table: ValueBoxTable, start: ValueBoxKey, end: ValueBoxKey, limit: Int) -> SqlitePreparedStatement {
        assert(self.queue.isCurrent())
        checkTableKey(table, start)
        checkTableKey(table, end)
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.rangeValueAscStatementsLimit[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "SELECT key, value FROM t\(table.id) WHERE key > ? AND key < ? ORDER BY key ASC LIMIT ?", -1, &statement, nil)
            assert(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.rangeValueAscStatementsLimit[table.id] = preparedStatement
            resultStatement = preparedStatement
        }
        resultStatement.reset()
        
        switch table.keyType {
            case .binary:
                resultStatement.bind(1, data: start.memory, length: start.length)
                resultStatement.bind(2, data: end.memory, length: end.length)
            case .int64:
                resultStatement.bind(1, number: start.getInt64(0))
                resultStatement.bind(2, number: end.getInt64(0))
        }
        resultStatement.bind(3, number: Int32(limit))
        
        return resultStatement
    }
    
    private func rangeValueAscStatementNoLimit(_ table: ValueBoxTable, start: ValueBoxKey, end: ValueBoxKey) -> SqlitePreparedStatement {
        assert(self.queue.isCurrent())
        checkTableKey(table, start)
        checkTableKey(table, end)
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.rangeValueAscStatementsNoLimit[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "SELECT key, value FROM t\(table.id) WHERE key > ? AND key < ? ORDER BY key ASC", -1, &statement, nil)
            assert(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.rangeValueAscStatementsNoLimit[table.id] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        switch table.keyType {
            case .binary:
                resultStatement.bind(1, data: start.memory, length: start.length)
                resultStatement.bind(2, data: end.memory, length: end.length)
            case .int64:
                resultStatement.bind(1, number: start.getInt64(0))
                resultStatement.bind(2, number: end.getInt64(0))
        }
        
        return resultStatement
    }
    
    private func rangeValueDescStatementLimit(_ table: ValueBoxTable, start: ValueBoxKey, end: ValueBoxKey, limit: Int) -> SqlitePreparedStatement {
        assert(self.queue.isCurrent())
        checkTableKey(table, start)
        checkTableKey(table, end)
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.rangeValueDescStatementsLimit[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "SELECT key, value FROM t\(table.id) WHERE key > ? AND key < ? ORDER BY key DESC LIMIT ?", -1, &statement, nil)
            assert(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.rangeValueDescStatementsLimit[table.id] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        switch table.keyType {
            case .binary:
                resultStatement.bind(1, data: start.memory, length: start.length)
                resultStatement.bind(2, data: end.memory, length: end.length)
            case .int64:
                resultStatement.bind(1, number: start.getInt64(0))
                resultStatement.bind(2, number: end.getInt64(0))
        }
        resultStatement.bind(3, number: Int32(limit))
        
        return resultStatement
    }
    
    private func rangeValueDescStatementNoLimit(_ table: ValueBoxTable, start: ValueBoxKey, end: ValueBoxKey) -> SqlitePreparedStatement {
        assert(self.queue.isCurrent())
        checkTableKey(table, start)
        checkTableKey(table, end)
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.rangeValueDescStatementsNoLimit[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "SELECT key, value FROM t\(table.id) WHERE key > ? AND key < ? ORDER BY key DESC", -1, &statement, nil)
            assert(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.rangeValueDescStatementsNoLimit[table.id] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        switch table.keyType {
            case .binary:
                resultStatement.bind(1, data: start.memory, length: start.length)
                resultStatement.bind(2, data: end.memory, length: end.length)
            case .int64:
                resultStatement.bind(1, number: start.getInt64(0))
                resultStatement.bind(2, number: end.getInt64(0))
        }
        
        return resultStatement
    }
    
    private func scanStatement(_ table: ValueBoxTable) -> SqlitePreparedStatement {
        assert(self.queue.isCurrent())
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.scanStatements[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "SELECT key, value FROM t\(table.id) ORDER BY key ASC", -1, &statement, nil)
            assert(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.scanStatements[table.id] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        return resultStatement
    }
    
    private func scanKeysStatement(_ table: ValueBoxTable) -> SqlitePreparedStatement {
        assert(self.queue.isCurrent())
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.scanKeysStatements[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "SELECT key FROM t\(table.id) ORDER BY key ASC", -1, &statement, nil)
            assert(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.scanKeysStatements[table.id] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        return resultStatement
    }
    
    private func existsStatement(_ table: ValueBoxTable, key: ValueBoxKey) -> SqlitePreparedStatement {
        assert(self.queue.isCurrent())
        checkTableKey(table, key)
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.existsStatements[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "SELECT rowid FROM t\(table.id) WHERE key=?", -1, &statement, nil)
            assert(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.existsStatements[table.id] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        switch table.keyType {
            case .binary:
                resultStatement.bind(1, data: key.memory, length: key.length)
            case .int64:
                resultStatement.bind(1, number: key.getInt64(0))
        }
        
        return resultStatement
    }
    
    private func updateStatement(_ table: ValueBoxTable, key: ValueBoxKey, value: MemoryBuffer) -> SqlitePreparedStatement {
        assert(self.queue.isCurrent())
        checkTableKey(table, key)
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.updateStatements[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "UPDATE t\(table.id) SET value=? WHERE key=?", -1, &statement, nil)
            assert(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.updateStatements[table.id] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()

        resultStatement.bind(1, data: value.memory, length: value.length)
        switch table.keyType {
            case .binary:
                resultStatement.bind(2, data: key.memory, length: key.length)
            case .int64:
                resultStatement.bind(2, number: key.getInt64(0))
        }
        
        return resultStatement
    }
    
    private func insertStatement(_ table: ValueBoxTable, key: ValueBoxKey, value: MemoryBuffer) -> SqlitePreparedStatement {
        assert(self.queue.isCurrent())
        checkTableKey(table, key)
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.insertStatements[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "INSERT INTO t\(table.id) (key, value) VALUES(?, ?)", -1, &statement, nil)
            assert(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.insertStatements[table.id] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        switch table.keyType {
            case .binary:
                resultStatement.bind(1, data: key.memory, length: key.length)
            case .int64:
                resultStatement.bind(1, number: key.getInt64(0))
        }
        if value.length == 0 {
            resultStatement.bindNull(2)
        } else {
            resultStatement.bind(2, data: value.memory, length: value.length)
        }
        
        return resultStatement
    }
    
    private func insertOrReplaceStatement(_ table: ValueBoxTable, key: ValueBoxKey, value: MemoryBuffer) -> SqlitePreparedStatement {
        assert(self.queue.isCurrent())
        checkTableKey(table, key)
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.insertOrReplaceStatements[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "INSERT OR REPLACE INTO t\(table.id) (key, value) VALUES(?, ?)", -1, &statement, nil)
            assert(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.insertOrReplaceStatements[table.id] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        switch table.keyType {
            case .binary:
                resultStatement.bind(1, data: key.memory, length: key.length)
            case .int64:
                resultStatement.bind(1, number: key.getInt64(0))
        }
        if value.length == 0 {
            resultStatement.bindNull(2)
        } else {
            resultStatement.bind(2, data: value.memory, length: value.length)
        }
        
        return resultStatement
    }
    
    private func deleteStatement(_ table: ValueBoxTable, key: ValueBoxKey) -> SqlitePreparedStatement {
        assert(self.queue.isCurrent())
        checkTableKey(table, key)
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.deleteStatements[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "DELETE FROM t\(table.id) WHERE key=?", -1, &statement, nil)
            assert(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.deleteStatements[table.id] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        switch table.keyType {
            case .binary:
                resultStatement.bind(1, data: key.memory, length: key.length)
            case .int64:
                resultStatement.bind(1, number: key.getInt64(0))
        }
        
        return resultStatement
    }
    
    private func moveStatement(_ table: ValueBoxTable, from previousKey: ValueBoxKey, to updatedKey: ValueBoxKey) -> SqlitePreparedStatement {
        assert(self.queue.isCurrent())
        checkTableKey(table, previousKey)
        checkTableKey(table, updatedKey)
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.moveStatements[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "UPDATE t\(table.id) SET key=? WHERE key=?", -1, &statement, nil)
            assert(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.moveStatements[table.id] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        switch table.keyType {
            case .binary:
                resultStatement.bind(1, data: previousKey.memory, length: previousKey.length)
                resultStatement.bind(2, data: updatedKey.memory, length: updatedKey.length)
            case .int64:
                resultStatement.bind(1, number: previousKey.getInt64(0))
                resultStatement.bind(2, number: updatedKey.getInt64(0))
        }
        
        return resultStatement
    }
    
    private func fullTextInsertStatement(_ table: ValueBoxFullTextTable, collectionId: Data, itemId: Data, contents: Data, tags: Data) -> SqlitePreparedStatement {
        assert(self.queue.isCurrent())
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.fullTextInsertStatements[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "INSERT INTO ft\(table.id) (collectionId, itemId, contents, tags) VALUES(?, ?, ?, ?)", -1, &statement, nil)
            assert(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.fullTextInsertStatements[table.id] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        collectionId.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
            resultStatement.bindText(1, data: bytes, length: collectionId.count)
        }
        
        itemId.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
            resultStatement.bindText(2, data: bytes, length: itemId.count)
        }
        
        contents.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
            resultStatement.bindText(3, data: bytes, length: contents.count)
        }
        
        tags.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
            resultStatement.bindText(4, data: bytes, length: tags.count)
        }
        
        return resultStatement
    }
    
    private func fullTextDeleteStatement(_ table: ValueBoxFullTextTable, itemId: Data) -> SqlitePreparedStatement {
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.fullTextDeleteStatements[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "DELETE FROM ft\(table.id) WHERE itemId=?", -1, &statement, nil)
            assert(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.fullTextDeleteStatements[table.id] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        itemId.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
            resultStatement.bindText(1, data: bytes, length: itemId.count)
        }
        
        return resultStatement
    }
    
    private func fullTextMatchGlobalStatement(_ table: ValueBoxFullTextTable, contents: Data) -> SqlitePreparedStatement {
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.fullTextMatchGlobalStatements[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "SELECT collectionId, itemId FROM ft\(table.id) WHERE ft\(table.id) MATCH 'contents:\"' || ? || '\"'", -1, &statement, nil)
            if status != SQLITE_OK {
                self.printError()
                assertionFailure()
            }
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.fullTextMatchGlobalStatements[table.id] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        contents.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
            resultStatement.bindText(1, data: bytes, length: contents.count)
        }
        
        return resultStatement
    }
    
    private func fullTextMatchCollectionStatement(_ table: ValueBoxFullTextTable, collectionId: Data, contents: Data) -> SqlitePreparedStatement {
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.fullTextMatchCollectionStatements[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "SELECT collectionId, itemId FROM ft\(table.id) WHERE ft\(table.id) MATCH 'contents:\"' || ? || '\" AND collectionId:\"' || ? || '\"'", -1, &statement, nil)
            assert(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.fullTextMatchCollectionStatements[table.id] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        contents.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
            resultStatement.bindText(1, data: bytes, length: contents.count)
        }
        
        collectionId.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
            resultStatement.bindText(2, data: bytes, length: collectionId.count)
        }
        
        return resultStatement
    }
    
    private func fullTextMatchCollectionTagsStatement(_ table: ValueBoxFullTextTable, collectionId: Data, contents: Data, tags: Data) -> SqlitePreparedStatement {
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.fullTextMatchCollectionTagsStatements[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "SELECT collectionId, itemId FROM ft\(table.id) WHERE ft\(table.id) MATCH 'contents:\"' || ? || '\" AND collectionId:\"' || ? || '\" AND tags:\"' || ? || '\"'", -1, &statement, nil)
            assert(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.fullTextMatchCollectionTagsStatements[table.id] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        contents.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
            resultStatement.bindText(1, data: bytes, length: contents.count)
        }
        
        collectionId.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
            resultStatement.bindText(2, data: bytes, length: collectionId.count)
        }
        
        tags.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
            resultStatement.bindText(3, data: bytes, length: tags.count)
        }
        
        return resultStatement
    }
    
    public func get(_ table: ValueBoxTable, key: ValueBoxKey) -> ReadBuffer? {
        assert(self.queue.isCurrent())
        let startTime = CFAbsoluteTimeGetCurrent()
        if let _ = self.tables[table.id] {
            let statement = self.getStatement(table, key: key)
            
            var buffer: ReadBuffer?
            
            while statement.step(handle: self.database.handle, path: self.databasePath) {
                buffer = statement.valueAt(0)
                break
            }
            
            statement.reset()
            
            self.readQueryTime += CFAbsoluteTimeGetCurrent() - startTime
            
            return buffer
        }
        
        withExtendedLifetime(key, {})
        
        return nil
    }
    
    public func exists(_ table: ValueBoxTable, key: ValueBoxKey) -> Bool {
        assert(self.queue.isCurrent())
        if let _ = self.get(table, key: key) {
            return true
        }
        return false
    }
    
    public func range(_ table: ValueBoxTable, start: ValueBoxKey, end: ValueBoxKey, values: (ValueBoxKey, ReadBuffer) -> Bool, limit: Int) {
        assert(self.queue.isCurrent())
        if start == end {
            return
        }
        
        if let _ = self.tables[table.id] {
            let statement: SqlitePreparedStatement
            
            var startTime = CFAbsoluteTimeGetCurrent()
            
            switch table.keyType {
                case .binary:
                    if start < end {
                        if limit <= 0 {
                            statement = self.rangeValueAscStatementNoLimit(table, start: start, end: end)
                        } else {
                            statement = self.rangeValueAscStatementLimit(table, start: start, end: end, limit: limit)
                        }
                    } else {
                        if limit <= 0 {
                            statement = self.rangeValueDescStatementNoLimit(table, start: end, end: start)
                        } else {
                            statement = self.rangeValueDescStatementLimit(table, start: end, end: start, limit: limit)
                        }
                    }
                
                    var currentTime = CFAbsoluteTimeGetCurrent()
                    self.readQueryTime += currentTime - startTime
                    
                    startTime = currentTime
                    
                    while statement.step(handle: self.database.handle, path: self.databasePath) {
                        startTime = CFAbsoluteTimeGetCurrent()
                        
                        let key = statement.keyAt(0)
                        let value = statement.valueAt(1)
                        
                        currentTime = CFAbsoluteTimeGetCurrent()
                        self.readQueryTime += currentTime - startTime
                        
                        if !values(key, value) {
                            break
                        }
                    }
                    
                    statement.reset()
                case .int64:
                    if start.reversed < end.reversed {
                        if limit <= 0 {
                            statement = self.rangeValueAscStatementNoLimit(table, start: start, end: end)
                        } else {
                            statement = self.rangeValueAscStatementLimit(table, start: start, end: end, limit: limit)
                        }
                    } else {
                        if limit <= 0 {
                            statement = self.rangeValueDescStatementNoLimit(table, start: end, end: start)
                        } else {
                            statement = self.rangeValueDescStatementLimit(table, start: end, end: start, limit: limit)
                        }
                    }
                
                    var currentTime = CFAbsoluteTimeGetCurrent()
                    self.readQueryTime += currentTime - startTime
                    
                    startTime = currentTime
                    
                    while statement.step(handle: self.database.handle, path: self.databasePath) {
                        startTime = CFAbsoluteTimeGetCurrent()
                        
                        let key = statement.int64KeyAt(0)
                        let value = statement.valueAt(1)
                        
                        currentTime = CFAbsoluteTimeGetCurrent()
                        self.readQueryTime += currentTime - startTime
                        
                        if !values(key, value) {
                            break
                        }
                    }
                    
                    statement.reset()
            }
        }
        
        withExtendedLifetime(start, {})
        withExtendedLifetime(end, {})
    }
    
    public func range(_ table: ValueBoxTable, start: ValueBoxKey, end: ValueBoxKey, keys: (ValueBoxKey) -> Bool, limit: Int) {
        assert(self.queue.isCurrent())
        if let _ = self.tables[table.id] {
            let statement: SqlitePreparedStatement
            
            var startTime = CFAbsoluteTimeGetCurrent()
            
            switch table.keyType {
                case .binary:
                    if start < end {
                        if limit <= 0 {
                            statement = self.rangeKeyAscStatementNoLimit(table, start: start, end: end)
                        } else {
                            statement = self.rangeKeyAscStatementLimit(table, start: start, end: end, limit: limit)
                        }
                    } else {
                        if limit <= 0 {
                            statement = self.rangeKeyDescStatementNoLimit(table, start: end, end: start)
                        } else {
                            statement = self.rangeKeyDescStatementLimit(table, start: end, end: start, limit: limit)
                        }
                    }
                
                    var currentTime = CFAbsoluteTimeGetCurrent()
                    self.readQueryTime += currentTime - startTime
                    
                    startTime = currentTime
                    
                    while statement.step(handle: self.database.handle, path: self.databasePath) {
                        startTime = CFAbsoluteTimeGetCurrent()
                        
                        let key = statement.keyAt(0)
                        
                        currentTime = CFAbsoluteTimeGetCurrent()
                        self.readQueryTime += currentTime - startTime
                        
                        if !keys(key) {
                            break
                        }
                    }
                    
                    statement.reset()
                case .int64:
                    if start.reversed < end.reversed {
                        if limit <= 0 {
                            statement = self.rangeKeyAscStatementNoLimit(table, start: start, end: end)
                        } else {
                            statement = self.rangeKeyAscStatementLimit(table, start: start, end: end, limit: limit)
                        }
                    } else {
                        if limit <= 0 {
                            statement = self.rangeKeyDescStatementNoLimit(table, start: end, end: start)
                        } else {
                            statement = self.rangeKeyDescStatementLimit(table, start: end, end: start, limit: limit)
                        }
                    }
                
                    var currentTime = CFAbsoluteTimeGetCurrent()
                    self.readQueryTime += currentTime - startTime
                    
                    startTime = currentTime
                    
                    while statement.step(handle: self.database.handle, path: self.databasePath) {
                        startTime = CFAbsoluteTimeGetCurrent()
                        
                        let key = statement.int64KeyAt(0)
                        
                        currentTime = CFAbsoluteTimeGetCurrent()
                        self.readQueryTime += currentTime - startTime
                        
                        if !keys(key) {
                            break
                        }
                    }
                    
                    statement.reset()
            }
        }
        
        withExtendedLifetime(start, {})
        withExtendedLifetime(end, {})
    }
    
    public func scan(_ table: ValueBoxTable, values: (ValueBoxKey, ReadBuffer) -> Bool) {
        assert(self.queue.isCurrent())
        
        if let _ = self.tables[table.id] {
            let statement: SqlitePreparedStatement = self.scanStatement(table)
            
            var startTime = CFAbsoluteTimeGetCurrent()
            
            var currentTime = CFAbsoluteTimeGetCurrent()
            self.readQueryTime += currentTime - startTime
            
            startTime = currentTime
            
            while statement.step(handle: self.database.handle, path: self.databasePath) {
                startTime = CFAbsoluteTimeGetCurrent()
                
                let key = statement.keyAt(0)
                let value = statement.valueAt(1)
                
                currentTime = CFAbsoluteTimeGetCurrent()
                self.readQueryTime += currentTime - startTime
                
                if !values(key, value) {
                    break
                }
            }
            
            statement.reset()
        }
    }
    
    public func scan(_ table: ValueBoxTable, keys: (ValueBoxKey) -> Bool) {
        assert(self.queue.isCurrent())
        
        if let _ = self.tables[table.id] {
            let statement: SqlitePreparedStatement = self.scanKeysStatement(table)
            
            var startTime = CFAbsoluteTimeGetCurrent()
            
            var currentTime = CFAbsoluteTimeGetCurrent()
            self.readQueryTime += currentTime - startTime
            
            startTime = currentTime
            
            while statement.step(handle: self.database.handle, path: self.databasePath) {
                startTime = CFAbsoluteTimeGetCurrent()
                
                let key = statement.keyAt(0)
                
                currentTime = CFAbsoluteTimeGetCurrent()
                self.readQueryTime += currentTime - startTime
                
                if !keys(key) {
                    break
                }
            }
            
            statement.reset()
        }
    }
    
    public func scanInt64(_ table: ValueBoxTable, values: (Int64, ReadBuffer) -> Bool) {
        assert(self.queue.isCurrent())
        
        if let _ = self.tables[table.id] {
            let statement: SqlitePreparedStatement = self.scanStatement(table)
            
            var startTime = CFAbsoluteTimeGetCurrent()
            
            var currentTime = CFAbsoluteTimeGetCurrent()
            self.readQueryTime += currentTime - startTime
            
            startTime = currentTime
            
            while statement.step(handle: self.database.handle, path: self.databasePath) {
                startTime = CFAbsoluteTimeGetCurrent()
                
                let key = statement.int64KeyValueAt(0)
                let value = statement.valueAt(1)
                
                currentTime = CFAbsoluteTimeGetCurrent()
                self.readQueryTime += currentTime - startTime
                
                if !values(key, value) {
                    break
                }
            }
            
            statement.reset()
        }
    }
    
    public func set(_ table: ValueBoxTable, key: ValueBoxKey, value: MemoryBuffer) {
        assert(self.queue.isCurrent())
        self.checkTable(table)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        if case .int64 = table.keyType {
            let statement = self.insertOrReplaceStatement(table, key: key, value: value)
            while statement.step(handle: self.database.handle, path: self.databasePath) {
            }
            statement.reset()
        } else {
            var exists = false
            let existsStatement = self.existsStatement(table, key: key)
            if existsStatement.step(handle: self.database.handle, path: self.databasePath) {
                exists = true
            }
            existsStatement.reset()
            
            if exists {
                let statement = self.updateStatement(table, key: key, value: value)
                while statement.step(handle: self.database.handle, path: self.databasePath) {
                }
                statement.reset()
            } else {
                let statement = self.insertStatement(table, key: key, value: value)
                while statement.step(handle: self.database.handle, path: self.databasePath) {
                }
                statement.reset()
            }
        }
        
        self.writeQueryTime += CFAbsoluteTimeGetCurrent() - startTime
    }
    
    public func remove(_ table: ValueBoxTable, key: ValueBoxKey, secure: Bool) {
        assert(self.queue.isCurrent())
        if let _ = self.tables[table.id] {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            if secure != self.secureDeleteEnabled {
                self.secureDeleteEnabled = secure
                let result = database.execute("PRAGMA secure_delete=\(secure ? 1 : 0)")
                assert(result)
            }
            
            let statement = self.deleteStatement(table, key: key)
            while statement.step(handle: self.database.handle, path: self.databasePath) {
            }
            statement.reset()
            
            self.writeQueryTime += CFAbsoluteTimeGetCurrent() - startTime
        }
    }
    
    public func removeRange(_ table: ValueBoxTable, start: ValueBoxKey, end: ValueBoxKey) {
        assert(self.queue.isCurrent())
        if let _ = self.tables[table.id] {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            let statement = self.rangeDeleteStatement(table, start: min(start, end), end: max(start, end))
            while statement.step(handle: self.database.handle, path: self.databasePath) {
            }
            statement.reset()
            
            self.writeQueryTime += CFAbsoluteTimeGetCurrent() - startTime
        }
    }
    
    public func move(_ table: ValueBoxTable, from previousKey: ValueBoxKey, to updatedKey: ValueBoxKey) {
        assert(self.queue.isCurrent())
        if let _ = self.tables[table.id] {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            let statement = self.moveStatement(table, from: previousKey, to: updatedKey)
            while statement.step(handle: self.database.handle, path: self.databasePath) {
            }
            statement.reset()
            
            self.writeQueryTime += CFAbsoluteTimeGetCurrent() - startTime
        }
    }
    
    public func fullTextMatch(_ table: ValueBoxFullTextTable, collectionId: String?, query: String, tags: String?, values: (String, String) -> Bool) {
        if let _ = self.fullTextTables[table.id] {
            guard let queryData = query.data(using: .utf8) else {
                return
            }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            var statement: SqlitePreparedStatement?
            if let collectionId = collectionId {
                if let collectionIdData = collectionId.data(using: .utf8) {
                    if let tags = tags {
                        if let tagsData = tags.data(using: .utf8) {
                            statement = self.fullTextMatchCollectionTagsStatement(table, collectionId: collectionIdData, contents: queryData, tags: tagsData)
                        }
                    } else {
                        statement = self.fullTextMatchCollectionStatement(table, collectionId: collectionIdData, contents: queryData)
                    }
                }
            } else {
                statement = self.fullTextMatchGlobalStatement(table, contents: queryData)
            }
            
            if let statement = statement {
                while statement.step(handle: self.database.handle, path: self.databasePath) {
                    let resultCollectionId = statement.stringAt(0)
                    let resultItemId = statement.stringAt(1)
                    
                    if let resultCollectionId = resultCollectionId, let resultItemId = resultItemId {
                        if !values(resultCollectionId, resultItemId) {
                            break
                        }
                    } else {
                        assertionFailure()
                    }
                }
                
                statement.reset()
            }
            
            let currentTime = CFAbsoluteTimeGetCurrent()
            self.readQueryTime += currentTime - startTime
        }
    }
    
    public func fullTextSet(_ table: ValueBoxFullTextTable, collectionId: String, itemId: String, contents: String, tags: String) {
        self.checkFullTextTable(table)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard let collectionIdData = collectionId.data(using: .utf8), let itemIdData = itemId.data(using: .utf8), let contentsData = contents.data(using: .utf8), let tagsData = tags.data(using: .utf8) else {
            return
        }
        
        let statement = self.fullTextInsertStatement(table, collectionId: collectionIdData, itemId: itemIdData, contents: contentsData, tags: tagsData)
        while statement.step(handle: self.database.handle, path: self.databasePath) {
        }
        statement.reset()
        
        self.writeQueryTime += CFAbsoluteTimeGetCurrent() - startTime
    }
    
    public func fullTextRemove(_ table: ValueBoxFullTextTable, itemId: String) {
        if let _ = self.fullTextTables[table.id] {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            guard let itemIdData = itemId.data(using: .utf8) else {
                return
            }
            
            let statement = self.fullTextDeleteStatement(table, itemId: itemIdData)
            while statement.step(handle: self.database.handle, path: self.databasePath) {
            }
            statement.reset()
            
            self.writeQueryTime += CFAbsoluteTimeGetCurrent() - startTime
        }
    }
    
    private func clearStatements() {
        assert(self.queue.isCurrent())
        for (_, statement) in self.getStatements {
            statement.destroy()
        }
        self.getStatements.removeAll()
        
        for (_, statement) in self.rangeKeyAscStatementsLimit {
            statement.destroy()
        }
        self.rangeKeyAscStatementsLimit.removeAll()
        
        for (_, statement) in self.rangeKeyAscStatementsNoLimit {
            statement.destroy()
        }
        self.rangeKeyAscStatementsNoLimit.removeAll()
        
        for (_, statement) in self.rangeKeyDescStatementsLimit {
            statement.destroy()
        }
        self.rangeKeyDescStatementsLimit.removeAll()
        
        for (_, statement) in self.rangeKeyDescStatementsNoLimit {
            statement.destroy()
        }
        self.rangeKeyDescStatementsNoLimit.removeAll()
        
        for (_, statement) in self.deleteRangeStatements {
            statement.destroy()
        }
        self.deleteRangeStatements.removeAll()
        
        for (_, statement) in self.rangeValueAscStatementsLimit {
            statement.destroy()
        }
        self.rangeValueAscStatementsLimit.removeAll()
        
        for (_, statement) in self.rangeValueAscStatementsNoLimit {
            statement.destroy()
        }
        self.rangeValueAscStatementsNoLimit.removeAll()
        
        for (_, statement) in self.rangeValueDescStatementsLimit {
            statement.destroy()
        }
        self.rangeValueDescStatementsLimit.removeAll()
        
        for (_, statement) in self.rangeValueDescStatementsNoLimit {
            statement.destroy()
        }
        self.rangeValueDescStatementsNoLimit.removeAll()
        
        for (_, statement) in self.scanStatements {
            statement.destroy()
        }
        self.scanStatements.removeAll()
        
        for (_, statement) in self.scanKeysStatements {
            statement.destroy()
        }
        self.scanKeysStatements.removeAll()
        
        for (_, statement) in self.existsStatements {
            statement.destroy()
        }
        self.existsStatements.removeAll()
        
        for (_, statement) in self.updateStatements {
            statement.destroy()
        }
        self.updateStatements.removeAll()
        
        for (_, statement) in self.insertStatements {
            statement.destroy()
        }
        self.insertStatements.removeAll()
        
        for (_, statement) in self.insertOrReplaceStatements {
            statement.destroy()
        }
        self.insertOrReplaceStatements.removeAll()
        
        for (_, statement) in self.deleteStatements {
            statement.destroy()
        }
        self.deleteStatements.removeAll()
        
        for (_, statement) in self.moveStatements {
            statement.destroy()
        }
        self.moveStatements.removeAll()
        
        for (_, statement) in self.fullTextInsertStatements {
            statement.destroy()
        }
        self.fullTextInsertStatements.removeAll()
        
        for (_, statement) in self.fullTextDeleteStatements {
            statement.destroy()
        }
        self.fullTextDeleteStatements.removeAll()
        
        for (_, statement) in self.fullTextMatchGlobalStatements {
            statement.destroy()
        }
        self.fullTextMatchGlobalStatements.removeAll()
        
        for (_, statement) in self.fullTextMatchCollectionStatements {
            statement.destroy()
        }
        self.fullTextMatchCollectionStatements.removeAll()
        
        for (_, statement) in self.fullTextMatchCollectionTagsStatements {
            statement.destroy()
        }
        self.fullTextMatchCollectionTagsStatements.removeAll()
    }
    
    public func dropTable(_ table: ValueBoxTable) {
        let _ = self.database.execute("DELETE FROM t\(table.id)")
    }
    
    public func drop() {
        assert(self.queue.isCurrent())
        self.clearStatements()

        self.lock.lock()
        self.database = nil
        self.lock.unlock()
        
        postboxLog("dropping DB")
        let _ = try? FileManager.default.removeItem(atPath: self.databasePath)
        self.database = self.openDatabase()
        
        tables.removeAll()
    }
    
    private func printError() {
        if let error = sqlite3_errmsg(self.database.handle), let str = NSString(utf8String: error) {
            print("SQL error \(str)")
        }
    }
}
