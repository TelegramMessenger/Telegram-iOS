import Foundation
import sqlcipher
import SwiftSignalKit
import Buffers

private struct SqliteValueBoxTable {
    let table: ValueBoxTable
    let hasPrimaryKey: Bool
}

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private func checkTableKey(_ table: ValueBoxTable, _ key: ValueBoxKey) {
    switch table.keyType {
        case .binary:
            break
        case .int64:
            precondition(key.length == 8)
    }
}

struct SqlitePreparedStatement {
    let logger: ValueBoxLogger
    let statement: OpaquePointer?
    
    func bind(_ index: Int, data: UnsafeRawPointer, length: Int) {
        sqlite3_bind_blob(statement, Int32(index), data, Int32(length), SQLITE_TRANSIENT)
    }
    
    func bindText(_ index: Int, data: UnsafeRawPointer, length: Int) {
        sqlite3_bind_text(statement, Int32(index), data.assumingMemoryBound(to: Int8.self), Int32(length), SQLITE_TRANSIENT)
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
                self.logger.log("SQL error \(res): \(str) on step")
            } else {
                self.logger.log("SQL error \(res) on step")
            }
            
            if res == SQLITE_CORRUPT {
                if let path = path {
                    self.logger.log("Corrupted DB at step, dropping")
                    try? FileManager.default.removeItem(atPath: path)
                    preconditionFailure()
                }
            }
        }
        return res == SQLITE_ROW
    }
    
    func tryStep(handle: OpaquePointer?, _ initial: Bool = false, path: String?) -> Bool {
        let res = sqlite3_step(statement)
        if res != SQLITE_ROW && res != SQLITE_DONE {
            if res != SQLITE_MISUSE {
                if let error = sqlite3_errmsg(handle), let str = NSString(utf8String: error) {
                    self.logger.log("SQL error \(res): \(str) on step")
                } else {
                    self.logger.log("SQL error \(res) on step")
                }
            }
            
            if res == SQLITE_CORRUPT {
                if let path = path {
                    self.logger.log("Corrupted DB at step, dropping")
                    try? FileManager.default.removeItem(atPath: path)
                    preconditionFailure()
                }
            }
        }
        return res == SQLITE_ROW || res == SQLITE_DONE
    }
    
    func int32At(_ index: Int) -> Int32 {
        return sqlite3_column_int(statement, Int32(index))
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

private let dabaseFileNames: [String] = [
    "db_sqlite",
    "db_sqlite-shm",
    "db_sqlite-wal"
]

private struct TablePairKey: Hashable {
    let table1: Int32
    let table2: Int32
}

public final class SqliteValueBox: ValueBox {
    private let lock = NSRecursiveLock()
    
    fileprivate let basePath: String
    private let logger: ValueBoxLogger
    private let inMemory: Bool
    private let disableCache: Bool
    private let encryptionParameters: ValueBoxEncryptionParameters?
    private let databasePath: String
    private var database: Database!
    private var tables: [Int32: SqliteValueBoxTable] = [:]
    private var fullTextTables: [Int32: ValueBoxFullTextTable] = [:]
    private var getStatements: [Int32 : SqlitePreparedStatement] = [:]
    private var getRowIdStatements: [Int32 : SqlitePreparedStatement] = [:]
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
    private var insertOrReplacePrimaryKeyStatements: [Int32 : SqlitePreparedStatement] = [:]
    private var insertOrReplaceIndexKeyStatements: [Int32 : SqlitePreparedStatement] = [:]
    private var deleteStatements: [Int32 : SqlitePreparedStatement] = [:]
    private var moveStatements: [Int32 : SqlitePreparedStatement] = [:]
    private var copyStatements: [TablePairKey : SqlitePreparedStatement] = [:]
    private var fullTextInsertStatements: [Int32 : SqlitePreparedStatement] = [:]
    private var fullTextDeleteStatements: [Int32 : SqlitePreparedStatement] = [:]
    private var fullTextMatchGlobalStatements: [Int32 : SqlitePreparedStatement] = [:]
    private var fullTextMatchCollectionStatements: [Int32 : SqlitePreparedStatement] = [:]
    private var fullTextMatchCollectionTagsStatements: [Int32 : SqlitePreparedStatement] = [:]
    
    private var secureDeleteEnabled: Bool = false
    
    private let checkpoints = MetaDisposable()
    
    private let queue: Queue
    
    public init(basePath: String, queue: Queue, logger: ValueBoxLogger, encryptionParameters: ValueBoxEncryptionParameters?, disableCache: Bool = false, upgradeProgress: (Float) -> Void, inMemory: Bool = false) {
        self.basePath = basePath
        self.logger = logger
        self.inMemory = inMemory
        self.disableCache = disableCache
        self.encryptionParameters = encryptionParameters
        self.databasePath = basePath + "/db_sqlite"
        self.queue = queue
        self.database = self.openDatabase(encryptionParameters: encryptionParameters, upgradeProgress: upgradeProgress)
    }
    
    deinit {
        precondition(self.queue.isCurrent())
        self.clearStatements()
        checkpoints.dispose()
    }
    
    func internalClose() {
        self.database = nil
    }
    
    private func openDatabase(encryptionParameters: ValueBoxEncryptionParameters?, upgradeProgress: (Float) -> Void) -> Database {
        precondition(self.queue.isCurrent())
        
        checkpoints.set(nil)
        lock.lock()
        
        let _ = try? FileManager.default.createDirectory(atPath: basePath, withIntermediateDirectories: true, attributes: nil)
        let path = basePath + "/db_sqlite"
        
        #if DEBUG
        let exists = FileManager.default.fileExists(atPath: path)
        self.logger.log("Opening \(path), exists: \(exists)")
        if exists {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
                self.logger.log("\(path) size: \(data.count)")
            } catch let e {
                self.logger.log("Couldn't open database: \(e)")
            }
        }
        let walExists = FileManager.default.fileExists(atPath: path + "-wal")
        self.logger.log("Opening \(path)-wal, exists: \(walExists)")
        if walExists {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path + "-wal"), options: .mappedIfSafe)
                self.logger.log("\(path)-wal size: \(data.count)")
            } catch let e {
                self.logger.log("Couldn't open database: \(e)")
            }
        }
        #endif
        
        var database: Database
        if let result = Database(logger: self.logger, location: self.inMemory ? ":memory:" : path) {
            database = result
        } else {
            self.logger.log("Couldn't open DB")
            
            let tempPath = basePath + "_test\(arc4random())"
            enum TempError: Error {
                case generic
            }
            do {
                try FileManager.default.createDirectory(atPath: tempPath, withIntermediateDirectories: true, attributes: nil)
                let testDatabase = Database(logger: self.logger, location: tempPath + "/test_db")!
                var resultCode = testDatabase.execute("PRAGMA journal_mode=WAL")
                if !resultCode {
                    throw TempError.generic
                }
                resultCode = testDatabase.execute("PRAGMA user_version=123")
                if !resultCode {
                    throw TempError.generic
                }
            } catch {
                let _ = try? FileManager.default.removeItem(atPath: tempPath)
                self.logger.log("Don't have write access to database folder")
                preconditionFailure("Don't have write access to database folder")
            }
            
            let _ = try? FileManager.default.removeItem(atPath: path)
            preconditionFailure("Couldn't open database")
        }
        
        var resultCode: Bool = true
        
        resultCode = database.execute("PRAGMA cipher_plaintext_header_size=32")
        assert(resultCode)
        resultCode = database.execute("PRAGMA cipher_default_plaintext_header_size=32")
        assert(resultCode)
        
        if self.isEncrypted(database) {
            if let encryptionParameters = encryptionParameters {
                precondition(encryptionParameters.salt.data.count == 16)
                precondition(encryptionParameters.key.data.count == 32)
                
                let hexKey = hexString(encryptionParameters.key.data + encryptionParameters.salt.data)
                
                resultCode = database.execute("PRAGMA key=\"x'\(hexKey)'\"")
                assert(resultCode)
                
                if self.isEncrypted(database) {
                    self.logger.log("Encryption key is invalid")
                    
                    for fileName in dabaseFileNames {
                        let _ = try? FileManager.default.removeItem(atPath: basePath + "/\(fileName)")
                    }
                    database = Database(logger: self.logger, location: path)!
                    
                    resultCode = database.execute("PRAGMA cipher_plaintext_header_size=32")
                    assert(resultCode)
                    resultCode = database.execute("PRAGMA cipher_default_plaintext_header_size=32")
                    assert(resultCode)
                    
                    resultCode = database.execute("PRAGMA key=\"x'\(hexKey)'\"")
                    assert(resultCode)
                }
            } else {
                self.logger.log("Encryption key is required")
                assert(false)
                for fileName in dabaseFileNames {
                    let _ = try? FileManager.default.removeItem(atPath: basePath + "/\(fileName)")
                }
                database = Database(logger: self.logger, location: path)!
                
                resultCode = database.execute("PRAGMA cipher_plaintext_header_size=32")
                assert(resultCode)
                resultCode = database.execute("PRAGMA cipher_default_plaintext_header_size=32")
                assert(resultCode)
            }
        } else if let encryptionParameters = encryptionParameters, encryptionParameters.forceEncryptionIfNoSet {
            let hexKey = hexString(encryptionParameters.key.data + encryptionParameters.salt.data)
            
            if FileManager.default.fileExists(atPath: path) {
                self.logger.log("Reencrypting database")
                database = self.reencryptInPlace(database: database, encryptionParameters: encryptionParameters)
                
                if self.isEncrypted(database) {
                    self.logger.log("Reencryption failed")
                    
                    for fileName in dabaseFileNames {
                        let _ = try? FileManager.default.removeItem(atPath: basePath + "/\(fileName)")
                    }
                    database = Database(logger: self.logger, location: path)!
                    
                    resultCode = database.execute("PRAGMA cipher_plaintext_header_size=32")
                    assert(resultCode)
                    resultCode = database.execute("PRAGMA cipher_default_plaintext_header_size=32")
                    assert(resultCode)
                    
                    resultCode = database.execute("PRAGMA key=\"x'\(hexKey)'\"")
                    assert(resultCode)
                }
            } else {
                precondition(encryptionParameters.salt.data.count == 16)
                precondition(encryptionParameters.key.data.count == 32)
                resultCode = database.execute("PRAGMA key=\"x'\(hexKey)'\"")
                assert(resultCode)
                
                if self.isEncrypted(database) {
                    self.logger.log("Encryption setup failed")
                    //assert(false)
                    
                    for fileName in dabaseFileNames {
                        let _ = try? FileManager.default.removeItem(atPath: basePath + "/\(fileName)")
                    }
                    database = Database(logger: self.logger, location: path)!
                    
                    resultCode = database.execute("PRAGMA cipher_plaintext_header_size=32")
                    assert(resultCode)
                    resultCode = database.execute("PRAGMA cipher_default_plaintext_header_size=32")
                    assert(resultCode)
                    
                    resultCode = database.execute("PRAGMA key=\"x'\(hexKey)'\"")
                    assert(resultCode)
                }
            }
        }
        
        sqlite3_busy_timeout(database.handle, 1000 * 10000)
        
        if self.disableCache {
            database.execute("PRAGMA cache_size=32")
        }
        
        resultCode = database.execute("PRAGMA mmap_size=0")
        assert(resultCode)
        resultCode = database.execute("PRAGMA synchronous=NORMAL")
        assert(resultCode)
        resultCode = database.execute("PRAGMA temp_store=MEMORY")
        assert(resultCode)
        resultCode = database.execute("PRAGMA journal_mode=WAL")
        assert(resultCode)
        resultCode = database.execute("PRAGMA cipher_memory_security = OFF")
        assert(resultCode)
        //resultCode = database.execute("PRAGMA wal_autocheckpoint=500")
        //database.execute("PRAGMA journal_size_limit=1536")
        
        /*#if DEBUG
        var statement: OpaquePointer? = nil
        sqlite3_prepare_v2(database.handle, "PRAGMA integrity_check", -1, &statement, nil)
        let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
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
        
        self.beginInternal(database: database)
        
        let result = self.getUserVersion(database)
        
        if result < 3 {
            resultCode = database.execute("CREATE TABLE __meta_fulltext_tables (name INTEGER)")
            assert(resultCode)
        }
        
        if result < 4 {
            resultCode = database.execute("PRAGMA user_version=4")
            assert(resultCode)
        }
        
        for table in self.listTables(database) {
            self.tables[table.table.id] = table
        }
        for table in self.listFullTextTables(database) {
            self.fullTextTables[table.id] = table
        }
        
        self.commitInternal(database: database)
        
        lock.unlock()
        
        return database
    }
    
    public func beginStats() {
    }
    
    public func endStats() {
    }
    
    public func begin() {
        precondition(self.queue.isCurrent())
        let resultCode = self.database.execute("BEGIN IMMEDIATE")
        assert(resultCode)
    }
    
    public func commit() {
        precondition(self.queue.isCurrent())
        let resultCode = self.database.execute("COMMIT")
        assert(resultCode)
    }
    
    public func checkpoint() {
        precondition(self.queue.isCurrent())
        let resultCode = self.database.execute("PRAGMA wal_checkpoint(PASSIVE)")
        assert(resultCode)
    }
    
    private func beginInternal(database: Database) {
        precondition(self.queue.isCurrent())
        let resultCode = database.execute("BEGIN IMMEDIATE")
        assert(resultCode)
    }
    
    private func commitInternal(database: Database) {
        precondition(self.queue.isCurrent())
        let resultCode = database.execute("COMMIT")
        assert(resultCode)
    }
    
    private func isEncrypted(_ database: Database) -> Bool {
        var statement: OpaquePointer? = nil
        let status = sqlite3_prepare_v2(database.handle, "SELECT * FROM sqlite_master LIMIT 1", -1, &statement, nil)
        if status == SQLITE_NOTADB {
            return true
        }
        let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
        if !preparedStatement.tryStep(handle: database.handle, path: self.databasePath) {
            preparedStatement.destroy()
            return true
        }
        preparedStatement.destroy()
        return status == SQLITE_NOTADB
    }
    
    private func getUserVersion(_ database: Database) -> Int64 {
        precondition(self.queue.isCurrent())
        var statement: OpaquePointer? = nil
        let status = sqlite3_prepare_v2(database.handle, "PRAGMA user_version", -1, &statement, nil)
        precondition(status == SQLITE_OK)
        let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
        let _ = preparedStatement.step(handle: database.handle, path: self.databasePath)
        let value = preparedStatement.int64At(0)
        preparedStatement.destroy()
        return value
    }
    
    private func runPragma(_ database: Database, _ pragma: String) -> String {
        precondition(self.queue.isCurrent())
        var statement: OpaquePointer? = nil
        let status = sqlite3_prepare_v2(database.handle, "PRAGMA \(pragma)", -1, &statement, nil)
        precondition(status == SQLITE_OK)
        let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
        var result: String?
        if preparedStatement.step(handle: database.handle, path: self.databasePath) {
            result = preparedStatement.stringAt(0)
        }
        preparedStatement.destroy()
        return result ?? ""
    }
    
    private func listTables(_ database: Database) -> [SqliteValueBoxTable] {
        precondition(self.queue.isCurrent())
        var statement: OpaquePointer? = nil
        let status = sqlite3_prepare_v2(database.handle, "SELECT name, type, sql FROM sqlite_master", -1, &statement, nil)
        precondition(status == SQLITE_OK)
        let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
        var tables: [SqliteValueBoxTable] = []
        
        while preparedStatement.step(handle: database.handle, true, path: self.databasePath) {
            guard let name = preparedStatement.stringAt(0) else {
                assertionFailure()
                continue
            }
            guard let type = preparedStatement.stringAt(1), type == "table" else {
                continue
            }
            guard let sql = preparedStatement.stringAt(2) else {
                assertionFailure()
                continue
            }
            
            if name.hasPrefix("t") {
                if let intName = Int(String(name[name.index(after: name.startIndex)...])) {
                    let keyType: ValueBoxKeyType
                    var hasPrimaryKey = false
                    if sql.range(of: "(key INTEGER") != nil {
                        keyType = .int64
                        hasPrimaryKey = true
                    } else if sql.range(of: "(key BLOB") != nil {
                        keyType = .binary
                        if sql.range(of: "(key BLOB PRIMARY KEY") != nil {
                            hasPrimaryKey = true
                        }
                    } else {
                        assertionFailure()
                        continue
                    }
                    let isCompact = sql.range(of: "WITHOUT ROWID") != nil
                    tables.append(SqliteValueBoxTable(table: ValueBoxTable(id: Int32(intName), keyType: keyType, compactValuesOnCreation: isCompact), hasPrimaryKey: hasPrimaryKey))
                }
            }
        }
        preparedStatement.destroy()
        
        return tables
    }
    
    private func listFullTextTables(_ database: Database) -> [ValueBoxFullTextTable] {
        precondition(self.queue.isCurrent())
        var statement: OpaquePointer? = nil
        let status = sqlite3_prepare_v2(database.handle, "SELECT name FROM __meta_fulltext_tables", -1, &statement, nil)
        assert(status == SQLITE_OK)
        let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
        var tables: [ValueBoxFullTextTable] = []
        
        while preparedStatement.step(handle: database.handle, true, path: self.databasePath) {
            let value = preparedStatement.int64At(0)
            tables.append(ValueBoxFullTextTable(id: Int32(value)))
        }
        preparedStatement.destroy()
        return tables
    }
    
    private func checkTable(_ table: ValueBoxTable) -> SqliteValueBoxTable {
        precondition(self.queue.isCurrent())
        if let currentTable = self.tables[table.id] {
            precondition(currentTable.table.keyType == table.keyType)
            return currentTable
        } else {
            self.createTable(database: self.database, table: table)
            let resultTable = SqliteValueBoxTable(table: table, hasPrimaryKey: true)
            self.tables[table.id] = resultTable
            return resultTable
        }
    }
    
    private func createTable(database: Database, table: ValueBoxTable) {
        switch table.keyType {
            case .binary:
                var resultCode: Bool
                var createStatement = "CREATE TABLE t\(table.id) (key BLOB PRIMARY KEY, value BLOB)"
                if table.compactValuesOnCreation {
                    createStatement += " WITHOUT ROWID"
                }
                resultCode = database.execute(createStatement)
                assert(resultCode)
            case .int64:
                let resultCode = database.execute("CREATE TABLE t\(table.id) (key INTEGER PRIMARY KEY, value BLOB)")
                assert(resultCode)
        }
    }
    
    private func checkFullTextTable(_ table: ValueBoxFullTextTable) {
        precondition(self.queue.isCurrent())
        if let _ = self.fullTextTables[table.id] {
        } else {
            var resultCode = self.database.execute("CREATE VIRTUAL TABLE ft\(table.id) USING fts5(collectionId, itemId, contents, tags)")
            precondition(resultCode)
            self.fullTextTables[table.id] = table
            resultCode = self.database.execute("INSERT INTO __meta_fulltext_tables(name) VALUES (\(table.id))")
            precondition(resultCode)
        }
    }
    
    private func getStatement(_ table: ValueBoxTable, key: ValueBoxKey) -> SqlitePreparedStatement {
        precondition(self.queue.isCurrent())
        checkTableKey(table, key)
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.getStatements[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "SELECT value FROM t\(table.id) WHERE key=?", -1, &statement, nil)
            precondition(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
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
    
    private func getRowIdStatement(_ table: ValueBoxTable, key: ValueBoxKey) -> SqlitePreparedStatement {
        precondition(self.queue.isCurrent())
        checkTableKey(table, key)
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.getRowIdStatements[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "SELECT rowid FROM t\(table.id) WHERE key=?", -1, &statement, nil)
            precondition(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
            self.getRowIdStatements[table.id] = preparedStatement
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
        precondition(self.queue.isCurrent())
        checkTableKey(table, start)
        checkTableKey(table, end)
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.rangeKeyAscStatementsLimit[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "SELECT key FROM t\(table.id) WHERE key > ? AND key < ? ORDER BY key ASC LIMIT ?", -1, &statement, nil)
            precondition(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
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
        precondition(self.queue.isCurrent())
        checkTableKey(table, start)
        checkTableKey(table, end)
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.rangeKeyAscStatementsNoLimit[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "SELECT key FROM t\(table.id) WHERE key > ? AND key < ? ORDER BY key ASC", -1, &statement, nil)
            precondition(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
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
        precondition(self.queue.isCurrent())
        let resultStatement: SqlitePreparedStatement
        checkTableKey(table, start)
        checkTableKey(table, end)
        
        if let statement = self.rangeKeyDescStatementsLimit[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "SELECT key FROM t\(table.id) WHERE key > ? AND key < ? ORDER BY key DESC LIMIT ?", -1, &statement, nil)
            precondition(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
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
        precondition(self.queue.isCurrent())
        let resultStatement: SqlitePreparedStatement
        checkTableKey(table, start)
        checkTableKey(table, end)
        
        if let statement = self.rangeKeyDescStatementsNoLimit[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "SELECT key FROM t\(table.id) WHERE key > ? AND key < ? ORDER BY key DESC", -1, &statement, nil)
            precondition(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
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
        precondition(self.queue.isCurrent())
        let resultStatement: SqlitePreparedStatement
        checkTableKey(table, start)
        checkTableKey(table, end)
        precondition(start <= end)
        
        if let statement = self.deleteRangeStatements[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "DELETE FROM t\(table.id) WHERE key >= ? AND key <= ?", -1, &statement, nil)
            precondition(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
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
        precondition(self.queue.isCurrent())
        checkTableKey(table, start)
        checkTableKey(table, end)
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.rangeValueAscStatementsLimit[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "SELECT key, value FROM t\(table.id) WHERE key > ? AND key < ? ORDER BY key ASC LIMIT ?", -1, &statement, nil)
            precondition(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
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
        precondition(self.queue.isCurrent())
        checkTableKey(table, start)
        checkTableKey(table, end)
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.rangeValueAscStatementsNoLimit[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "SELECT key, value FROM t\(table.id) WHERE key > ? AND key < ? ORDER BY key ASC", -1, &statement, nil)
            precondition(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
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
        precondition(self.queue.isCurrent())
        checkTableKey(table, start)
        checkTableKey(table, end)
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.rangeValueDescStatementsLimit[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "SELECT key, value FROM t\(table.id) WHERE key > ? AND key < ? ORDER BY key DESC LIMIT ?", -1, &statement, nil)
            precondition(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
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
        precondition(self.queue.isCurrent())
        checkTableKey(table, start)
        checkTableKey(table, end)
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.rangeValueDescStatementsNoLimit[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "SELECT key, value FROM t\(table.id) WHERE key > ? AND key < ? ORDER BY key DESC", -1, &statement, nil)
            precondition(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
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
        precondition(self.queue.isCurrent())
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.scanStatements[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "SELECT key, value FROM t\(table.id) ORDER BY key ASC", -1, &statement, nil)
            precondition(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
            self.scanStatements[table.id] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        return resultStatement
    }
    
    private func scanKeysStatement(_ table: ValueBoxTable) -> SqlitePreparedStatement {
        precondition(self.queue.isCurrent())
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.scanKeysStatements[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "SELECT key FROM t\(table.id) ORDER BY key ASC", -1, &statement, nil)
            precondition(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
            self.scanKeysStatements[table.id] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        return resultStatement
    }
    
    private func existsStatement(_ table: ValueBoxTable, key: ValueBoxKey) -> SqlitePreparedStatement {
        precondition(self.queue.isCurrent())
        checkTableKey(table, key)
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.existsStatements[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "SELECT rowid FROM t\(table.id) WHERE key=?", -1, &statement, nil)
            precondition(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
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
        precondition(self.queue.isCurrent())
        checkTableKey(table, key)
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.updateStatements[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "UPDATE t\(table.id) SET value=? WHERE key=?", -1, &statement, nil)
            precondition(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
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
    
    private func insertOrReplaceStatement(_ table: SqliteValueBoxTable, key: ValueBoxKey, value: MemoryBuffer) -> SqlitePreparedStatement {
        precondition(self.queue.isCurrent())
        checkTableKey(table.table, key)
        
        let resultStatement: SqlitePreparedStatement
        
        if table.table.keyType == .int64 || table.hasPrimaryKey {
            if let statement = self.insertOrReplacePrimaryKeyStatements[table.table.id] {
                resultStatement = statement
            } else {
                var statement: OpaquePointer? = nil
                let status = sqlite3_prepare_v2(self.database.handle, "INSERT INTO t\(table.table.id) (key, value) VALUES(?, ?) ON CONFLICT(key) DO UPDATE SET value=excluded.value", -1, &statement, nil)
                if status != SQLITE_OK {
                    let errorText = self.database.currentError() ?? "Unknown error"
                    preconditionFailure(errorText)
                }
                let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
                self.insertOrReplacePrimaryKeyStatements[table.table.id] = preparedStatement
                resultStatement = preparedStatement
            }
        } else {
            if let statement = self.insertOrReplaceIndexKeyStatements[table.table.id] {
                resultStatement = statement
            } else {
                var statement: OpaquePointer? = nil
                let status = sqlite3_prepare_v2(self.database.handle, "INSERT INTO t\(table.table.id) (key, value) VALUES(?, ?)", -1, &statement, nil)
                if status != SQLITE_OK {
                    let errorText = self.database.currentError() ?? "Unknown error"
                    preconditionFailure(errorText)
                }
                let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
                self.insertOrReplacePrimaryKeyStatements[table.table.id] = preparedStatement
                resultStatement = preparedStatement
            }
        }
        
        resultStatement.reset()
        
        switch table.table.keyType {
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
        precondition(self.queue.isCurrent())
        checkTableKey(table, key)
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.deleteStatements[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "DELETE FROM t\(table.id) WHERE key=?", -1, &statement, nil)
            precondition(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
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
        precondition(self.queue.isCurrent())
        checkTableKey(table, previousKey)
        checkTableKey(table, updatedKey)
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.moveStatements[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "UPDATE t\(table.id) SET key=? WHERE key=?", -1, &statement, nil)
            precondition(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
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
    
    private func copyStatement(fromTable: ValueBoxTable, fromKey: ValueBoxKey, toTable: ValueBoxTable, toKey: ValueBoxKey) -> SqlitePreparedStatement {
        precondition(self.queue.isCurrent())
        let _ = checkTable(fromTable)
        let _ = checkTable(toTable)
        checkTableKey(fromTable, fromKey)
        checkTableKey(toTable, toKey)
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.copyStatements[TablePairKey(table1: fromTable.id, table2: toTable.id)] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "INSERT INTO t\(toTable.id) (key, value) SELECT ?, t\(fromTable.id).value FROM t\(fromTable.id) WHERE t\(fromTable.id).key=?", -1, &statement, nil)
            precondition(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
            self.copyStatements[TablePairKey(table1: fromTable.id, table2: toTable.id)] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        switch toTable.keyType {
            case .binary:
                resultStatement.bind(1, data: toKey.memory, length: toKey.length)
            case .int64:
                resultStatement.bind(1, number: toKey.getInt64(0))
        }
        
        switch fromTable.keyType {
            case .binary:
                resultStatement.bind(2, data: fromKey.memory, length: fromKey.length)
            case .int64:
                resultStatement.bind(2, number: fromKey.getInt64(0))
        }
        
        return resultStatement
    }
    
    private func fullTextInsertStatement(_ table: ValueBoxFullTextTable, collectionId: Data, itemId: Data, contents: Data, tags: Data) -> SqlitePreparedStatement {
        precondition(self.queue.isCurrent())
        
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.fullTextInsertStatements[table.id] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "INSERT INTO ft\(table.id) (collectionId, itemId, contents, tags) VALUES(?, ?, ?, ?)", -1, &statement, nil)
            precondition(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
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
            precondition(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
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
            let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
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
            precondition(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
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
            precondition(status == SQLITE_OK)
            let preparedStatement = SqlitePreparedStatement(logger: self.logger, statement: statement)
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
        precondition(self.queue.isCurrent())
        if let _ = self.tables[table.id] {
            let statement = self.getStatement(table, key: key)
            
            var buffer: ReadBuffer?
            
            while statement.step(handle: self.database.handle, path: self.databasePath) {
                buffer = statement.valueAt(0)
                break
            }
            
            statement.reset()
            
            return buffer
        }
        
        withExtendedLifetime(key, {})
        
        return nil
    }
    
    public func read(_ table: ValueBoxTable, key: ValueBoxKey, _ process: (Int, (UnsafeMutableRawPointer, Int, Int) -> Void) -> Void) {
        precondition(self.queue.isCurrent())
        if let _ = self.tables[table.id] {
            let statement = self.getRowIdStatement(table, key: key)
            
            if statement.step(handle: self.database.handle, path: self.databasePath) {
                let rowId = statement.int64At(0)
                var blobHandle: OpaquePointer?
                sqlite3_blob_open(database.handle, "main", "t\(table.id)", "value", rowId, 0, &blobHandle)
                if let blobHandle = blobHandle {
                    let length = sqlite3_blob_bytes(blobHandle)
                    process(Int(length), { buffer, offset, length in
                        sqlite3_blob_read(blobHandle, buffer, Int32(length), Int32(offset))
                    })
                    sqlite3_blob_close(blobHandle)
                }
            }
            statement.reset()
        }
    }
    
    public func readWrite(_ table: ValueBoxTable, key: ValueBoxKey, _ process: (Int, (UnsafeMutableRawPointer, Int, Int) -> Void, (UnsafeRawPointer, Int, Int) -> Void) -> Void) {
        if let _ = self.tables[table.id] {
            let statement = self.getRowIdStatement(table, key: key)
            
            if statement.step(handle: self.database.handle, path: self.databasePath) {
                let rowId = statement.int64At(0)
                var blobHandle: OpaquePointer?
                sqlite3_blob_open(database.handle, "main", "t\(table.id)", "value", rowId, 1, &blobHandle)
                if let blobHandle = blobHandle {
                    let length = sqlite3_blob_bytes(blobHandle)
                    process(Int(length), { buffer, offset, length in
                        sqlite3_blob_read(blobHandle, buffer, Int32(length), Int32(offset))
                    }, { buffer, offset, length in
                        sqlite3_blob_write(blobHandle, buffer, Int32(length), Int32(offset))
                    })
                    sqlite3_blob_close(blobHandle)
                }
            }
            statement.reset()
        }
    }
    
    public func exists(_ table: ValueBoxTable, key: ValueBoxKey) -> Bool {
        precondition(self.queue.isCurrent())
        if let _ = self.get(table, key: key) {
            return true
        }
        return false
    }
    
    public func range(_ table: ValueBoxTable, start: ValueBoxKey, end: ValueBoxKey, values: (ValueBoxKey, ReadBuffer) -> Bool, limit: Int) {
        precondition(self.queue.isCurrent())
        if start == end {
            return
        }
        
        if let _ = self.tables[table.id] {
            let statement: SqlitePreparedStatement
            
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
                    
                    while statement.step(handle: self.database.handle, path: self.databasePath) {
                        let key = statement.keyAt(0)
                        let value = statement.valueAt(1)
                        
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
                    
                    while statement.step(handle: self.database.handle, path: self.databasePath) {
                        let key = statement.int64KeyAt(0)
                        let value = statement.valueAt(1)
                        
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
        precondition(self.queue.isCurrent())
        if let _ = self.tables[table.id] {
            let statement: SqlitePreparedStatement
            
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
                    
                    while statement.step(handle: self.database.handle, path: self.databasePath) {
                        let key = statement.keyAt(0)
                        
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
                    
                    while statement.step(handle: self.database.handle, path: self.databasePath) {
                        let key = statement.int64KeyAt(0)
                        
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
        precondition(self.queue.isCurrent())
        
        if let _ = self.tables[table.id] {
            let statement: SqlitePreparedStatement = self.scanStatement(table)
            
            while statement.step(handle: self.database.handle, path: self.databasePath) {
                let key = statement.keyAt(0)
                let value = statement.valueAt(1)
                
                if !values(key, value) {
                    break
                }
            }
            
            statement.reset()
        }
    }
    
    public func scan(_ table: ValueBoxTable, keys: (ValueBoxKey) -> Bool) {
        precondition(self.queue.isCurrent())
        
        if let _ = self.tables[table.id] {
            let statement: SqlitePreparedStatement = self.scanKeysStatement(table)
            
            while statement.step(handle: self.database.handle, path: self.databasePath) {
                let key = statement.keyAt(0)
                
                if !keys(key) {
                    break
                }
            }
            
            statement.reset()
        }
    }
    
    public func scanInt64(_ table: ValueBoxTable, values: (Int64, ReadBuffer) -> Bool) {
        precondition(self.queue.isCurrent())
        
        if let _ = self.tables[table.id] {
            let statement: SqlitePreparedStatement = self.scanStatement(table)
            
            while statement.step(handle: self.database.handle, path: self.databasePath) {
                let key = statement.int64KeyValueAt(0)
                let value = statement.valueAt(1)
                
                if !values(key, value) {
                    break
                }
            }
            
            statement.reset()
        }
    }
    
    public func scanInt64(_ table: ValueBoxTable, keys: (Int64) -> Bool) {
        precondition(self.queue.isCurrent())
        
        if let _ = self.tables[table.id] {
            let statement: SqlitePreparedStatement = self.scanKeysStatement(table)
            
            while statement.step(handle: self.database.handle, path: self.databasePath) {
                let key = statement.int64KeyValueAt(0)
                
                if !keys(key) {
                    break
                }
            }
            
            statement.reset()
        }
    }
    
    public func set(_ table: ValueBoxTable, key: ValueBoxKey, value: MemoryBuffer) {
        precondition(self.queue.isCurrent())
        let sqliteTable = self.checkTable(table)
        
        if sqliteTable.hasPrimaryKey {
            let statement = self.insertOrReplaceStatement(sqliteTable, key: key, value: value)
            while statement.step(handle: self.database.handle, path: self.databasePath) {
            }
            statement.reset()
        } else {
            if self.exists(table, key: key) {
                let statement = self.updateStatement(table, key: key, value: value)
                while statement.step(handle: self.database.handle, path: self.databasePath) {
                }
                statement.reset()
            } else {
                let statement = self.insertOrReplaceStatement(sqliteTable, key: key, value: value)
                while statement.step(handle: self.database.handle, path: self.databasePath) {
                }
                statement.reset()
            }
        }
    }
    
    public func remove(_ table: ValueBoxTable, key: ValueBoxKey, secure: Bool) {
        precondition(self.queue.isCurrent())
        if let _ = self.tables[table.id] {
            if secure != self.secureDeleteEnabled {
                self.secureDeleteEnabled = secure
                let result = database.execute("PRAGMA secure_delete=\(secure ? 1 : 0)")
                precondition(result)
            }
            
            let statement = self.deleteStatement(table, key: key)
            while statement.step(handle: self.database.handle, path: self.databasePath) {
            }
            statement.reset()
        }
    }
    
    public func removeRange(_ table: ValueBoxTable, start: ValueBoxKey, end: ValueBoxKey) {
        precondition(self.queue.isCurrent())
        if let _ = self.tables[table.id] {
            let statement = self.rangeDeleteStatement(table, start: min(start, end), end: max(start, end))
            while statement.step(handle: self.database.handle, path: self.databasePath) {
            }
            statement.reset()
        }
    }
    
    public func move(_ table: ValueBoxTable, from previousKey: ValueBoxKey, to updatedKey: ValueBoxKey) {
        precondition(self.queue.isCurrent())
        if let _ = self.tables[table.id] {
            let statement = self.moveStatement(table, from: previousKey, to: updatedKey)
            while statement.step(handle: self.database.handle, path: self.databasePath) {
            }
            statement.reset()
        }
    }
    
    public func copy(fromTable: ValueBoxTable, fromKey: ValueBoxKey, toTable: ValueBoxTable, toKey: ValueBoxKey) {
        precondition(self.queue.isCurrent())
        if let _ = self.tables[fromTable.id] {
            let statement = self.copyStatement(fromTable: fromTable, fromKey: fromKey, toTable: toTable, toKey: toKey)
            while statement.step(handle: self.database.handle, path: self.databasePath) {
            }
            statement.reset()
        }
    }
    
    public func renameTable(_ table: ValueBoxTable, to toTable: ValueBoxTable) {
        let sqliteTable = self.checkTable(table)
        let resultCode = database.execute("ALTER TABLE t\(table.id) RENAME TO t\(toTable.id)")
        precondition(resultCode)
        self.tables[toTable.id] = SqliteValueBoxTable(table: ValueBoxTable(id: toTable.id, keyType: sqliteTable.table.keyType, compactValuesOnCreation: sqliteTable.table.compactValuesOnCreation), hasPrimaryKey: sqliteTable.hasPrimaryKey)
        self.tables.removeValue(forKey: table.id)
    }
    
    public func fullTextMatch(_ table: ValueBoxFullTextTable, collectionId: String?, query: String, tags: String?, values: (String, String) -> Bool) {
        if let _ = self.fullTextTables[table.id] {
            guard let queryData = query.data(using: .utf8) else {
                return
            }
            
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
        }
    }
    
    public func fullTextSet(_ table: ValueBoxFullTextTable, collectionId: String, itemId: String, contents: String, tags: String) {
        self.checkFullTextTable(table)
        
        guard let collectionIdData = collectionId.data(using: .utf8), let itemIdData = itemId.data(using: .utf8), let contentsData = contents.data(using: .utf8), let tagsData = tags.data(using: .utf8) else {
            return
        }
        
        let statement = self.fullTextInsertStatement(table, collectionId: collectionIdData, itemId: itemIdData, contents: contentsData, tags: tagsData)
        while statement.step(handle: self.database.handle, path: self.databasePath) {
        }
        statement.reset()
    }
    
    public func fullTextRemove(_ table: ValueBoxFullTextTable, itemId: String, secure: Bool) {
        if let _ = self.fullTextTables[table.id] {
            if secure != self.secureDeleteEnabled {
                self.secureDeleteEnabled = secure
                let result = database.execute("PRAGMA secure_delete=\(secure ? 1 : 0)")
                precondition(result)
            }
            
            guard let itemIdData = itemId.data(using: .utf8) else {
                return
            }
            
            let statement = self.fullTextDeleteStatement(table, itemId: itemIdData)
            while statement.step(handle: self.database.handle, path: self.databasePath) {
            }
            statement.reset()
        }
    }
    
    public func count(_ table: ValueBoxTable, start: ValueBoxKey, end: ValueBoxKey) -> Int {
        let _ = self.checkTable(table)
        
        var statementImpl: OpaquePointer? = nil
        let status = sqlite3_prepare_v2(self.database.handle, "SELECT COUNT(*) FROM t\(table.id) WHERE key > ? AND key < ?", -1, &statementImpl, nil)
        precondition(status == SQLITE_OK)
        let statement = SqlitePreparedStatement(logger: self.logger, statement: statementImpl)
        switch table.keyType {
            case .binary:
                statement.bind(1, data: start.memory, length: start.length)
            case .int64:
                statement.bind(1, number: start.getInt64(0))
        }
        switch table.keyType {
            case .binary:
                statement.bind(2, data: end.memory, length: end.length)
            case .int64:
                statement.bind(2, number: end.getInt64(0))
        }
        
        var result = 0
        while statement.step(handle: database.handle, true, path: self.databasePath) {
            let value = statement.int32At(0)
            result = Int(value)
        }
        statement.reset()
        statement.destroy()
        return result
    }
    
    public func count(_ table: ValueBoxTable) -> Int {
        let _ = self.checkTable(table)
        
        var statementImpl: OpaquePointer? = nil
        let status = sqlite3_prepare_v2(self.database.handle, "SELECT COUNT(*) FROM t\(table.id)", -1, &statementImpl, nil)
        precondition(status == SQLITE_OK)
        let statement = SqlitePreparedStatement(logger: self.logger, statement: statementImpl)
        
        var result = 0
        while statement.step(handle: database.handle, true, path: self.databasePath) {
            let value = statement.int32At(0)
            result = Int(value)
        }
        statement.reset()
        statement.destroy()
        return result
    }
    
    private func clearStatements() {
        precondition(self.queue.isCurrent())
        for (_, statement) in self.getStatements {
            statement.destroy()
        }
        self.getStatements.removeAll()
        
        for (_, statement) in self.getRowIdStatements {
            statement.destroy()
        }
        self.getRowIdStatements.removeAll()
        
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
        
        for (_, statement) in self.insertOrReplaceIndexKeyStatements {
            statement.destroy()
        }
        self.insertOrReplaceIndexKeyStatements.removeAll()
        
        for (_, statement) in self.insertOrReplacePrimaryKeyStatements {
            statement.destroy()
        }
        self.insertOrReplacePrimaryKeyStatements.removeAll()
        
        for (_, statement) in self.deleteStatements {
            statement.destroy()
        }
        self.deleteStatements.removeAll()
        
        for (_, statement) in self.moveStatements {
            statement.destroy()
        }
        self.moveStatements.removeAll()
        
        for (_, statement) in self.copyStatements {
            statement.destroy()
        }
        self.copyStatements.removeAll()
        
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
    
    public func removeAllFromTable(_ table: ValueBoxTable) {
        let _ = self.database.execute("DELETE FROM t\(table.id)")
    }
    
    public func removeTable(_ table: ValueBoxTable) {
        let _ = self.database.execute("DROP TABLE t\(table.id)")
        self.tables.removeValue(forKey: table.id)
    }
    
    public func drop() {
        precondition(self.queue.isCurrent())
        self.clearStatements()

        self.lock.lock()
        self.database = nil
        self.lock.unlock()
        
        self.logger.log("dropping DB")
        
        for fileName in dabaseFileNames {
            let _ = try? FileManager.default.removeItem(atPath: self.basePath + "/\(fileName)")
        }
        
        self.database = self.openDatabase(encryptionParameters: self.encryptionParameters, upgradeProgress: { _ in })
        
        tables.removeAll()
    }
    
    private func printError() {
        if let error = sqlite3_errmsg(self.database.handle), let str = NSString(utf8String: error) {
            print("SQL error \(str)")
        }
    }
    
    public func exportEncrypted(to exportBasePath: String, encryptionParameters: ValueBoxEncryptionParameters) {
        self.exportEncrypted(database: self.database, to: exportBasePath, encryptionParameters: encryptionParameters)
    }
        
    private func exportEncrypted(database: Database, to exportBasePath: String, encryptionParameters: ValueBoxEncryptionParameters) {
        let _ = try? FileManager.default.createDirectory(atPath: exportBasePath, withIntermediateDirectories: true, attributes: nil)
        let exportFilePath = "\(exportBasePath)/db_sqlite"
        
        let hexKey = hexString(encryptionParameters.key.data + encryptionParameters.salt.data)
        
        precondition(encryptionParameters.salt.data.count == 16)
        precondition(encryptionParameters.key.data.count == 32)
        
        var resultCode = database.execute("ATTACH DATABASE '\(exportFilePath)' AS encrypted KEY \"x'\(hexKey)'\"")
        assert(resultCode)
        resultCode = database.execute("SELECT sqlcipher_export('encrypted')")
        assert(resultCode)
        let userVersion = self.getUserVersion(database)
        resultCode = database.execute("PRAGMA encrypted.user_version=\(userVersion)")
        resultCode = database.execute("DETACH DATABASE encrypted")
        assert(resultCode)
    }
    
    private func reencryptInPlace(database: Database, encryptionParameters: ValueBoxEncryptionParameters) -> Database {
        let targetPath = self.basePath + "/db_export"
        let _ = try? FileManager.default.removeItem(atPath: targetPath)
        
        self.exportEncrypted(database: database, to: targetPath, encryptionParameters: encryptionParameters)
        
        for name in dabaseFileNames {
            let _ = try? FileManager.default.removeItem(atPath: self.basePath + "/\(name)")
            let _ = try? FileManager.default.moveItem(atPath: targetPath + "/\(name)", toPath: self.basePath + "/\(name)")
        }
        let _ = try? FileManager.default.removeItem(atPath: targetPath)
        
        let updatedDatabase = Database(logger: self.logger, location: self.databasePath)!
        
        var resultCode = updatedDatabase.execute("PRAGMA cipher_plaintext_header_size=32")
        assert(resultCode)
        resultCode = updatedDatabase.execute("PRAGMA cipher_default_plaintext_header_size=32")
        assert(resultCode)
        
        let hexKey = hexString(encryptionParameters.key.data + encryptionParameters.salt.data)
        
        resultCode = updatedDatabase.execute("PRAGMA key=\"x'\(hexKey)'\"")
        assert(resultCode)
        
        return updatedDatabase
    }
    
    public func vacuum() {
        var resultCode = self.database.execute("VACUUM")
        precondition(resultCode)
        resultCode = self.database.execute("PRAGMA wal_checkpoint(TRUNCATE)")
        precondition(resultCode)
    }
}

private func hexString(_ data: Data) -> String {
    let hexString = NSMutableString()
    data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
        for i in 0 ..< data.count {
            hexString.appendFormat("%02x", UInt(bytes.advanced(by: i).pointee))
        }
    }
    
    return hexString as String
}
