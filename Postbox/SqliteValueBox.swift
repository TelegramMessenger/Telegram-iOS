import Foundation
import sqlcipher
import SwiftSignalKit

private struct SqlitePreparedStatement {
    let statement: OpaquePointer?
    
    func bind(_ index: Int, data: UnsafeRawPointer, length: Int) {
        sqlite3_bind_blob(statement, Int32(index), data, Int32(length), nil)
    }
    
    func bindNull(_ index: Int) {
        sqlite3_bind_null(statement, Int32(index))
    }
    
    func bind(_ index: Int, number: Int32) {
        sqlite3_bind_int(statement, Int32(index), number)
    }
    
    func bind(_ index: Int, number: Int64) {
        sqlite3_bind_int64(statement, Int32(index), number)
    }
    
    func reset() {
        sqlite3_reset(statement)
        sqlite3_clear_bindings(statement)
    }
    
    func step() -> Bool {
        let result = sqlite3_step(statement)
        if result != SQLITE_ROW && result != SQLITE_DONE {
            assertionFailure("Sqlite error \(result)")
        }
        return result == SQLITE_ROW
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
    
    func keyAt(_ index: Int) -> ValueBoxKey {
        let valueLength = sqlite3_column_bytes(statement, Int32(index))
        let valueData = sqlite3_column_blob(statement, Int32(index))
        
        let key = ValueBoxKey(length: Int(valueLength))
        memcpy(key.memory, valueData, Int(valueLength))
        return key
    }
    
    func destroy() {
        sqlite3_finalize(statement)
    }
}

public final class SqliteValueBox: ValueBox {
    private let lock = NSRecursiveLock()
    
    private let basePath: String
    private var database: Database!
    private var tables = Set<Int32>()
    private var getStatements: [Int32 : SqlitePreparedStatement] = [:]
    private var rangeKeyAscStatementsLimit: [Int32 : SqlitePreparedStatement] = [:]
    private var rangeKeyAscStatementsNoLimit: [Int32 : SqlitePreparedStatement] = [:]
    private var rangeKeyDescStatementsLimit: [Int32 : SqlitePreparedStatement] = [:]
    private var rangeKeyDescStatementsNoLimit: [Int32 : SqlitePreparedStatement] = [:]
    private var rangeValueAscStatementsLimit: [Int32 : SqlitePreparedStatement] = [:]
    private var rangeValueAscStatementsNoLimit: [Int32 : SqlitePreparedStatement] = [:]
    private var rangeValueDescStatementsLimit: [Int32 : SqlitePreparedStatement] = [:]
    private var rangeValueDescStatementsNoLimit: [Int32 : SqlitePreparedStatement] = [:]
    private var existsStatements: [Int32 : SqlitePreparedStatement] = [:]
    private var updateStatements: [Int32 : SqlitePreparedStatement] = [:]
    private var insertStatements: [Int32 : SqlitePreparedStatement] = [:]
    private var deleteStatements: [Int32 : SqlitePreparedStatement] = [:]
    
    private var readQueryTime: CFAbsoluteTime = 0.0
    private var writeQueryTime: CFAbsoluteTime = 0.0
    private var commitTime: CFAbsoluteTime = 0.0
    
    private let checkpoints = MetaDisposable()
    
    public init(basePath: String) {
        self.basePath = basePath
        self.database = self.openDatabase()
    }
    
    deinit {
        self.clearStatements()
        checkpoints.dispose()
    }
    
    private func openDatabase() -> Database {
        checkpoints.set(nil)
        lock.lock()
        
        let _ = try? FileManager.default.createDirectory(atPath: basePath, withIntermediateDirectories: true, attributes: nil)
        let path = basePath + "/db_sqlite"
        let database = Database(path)
        
        database.adjustChunkSize()
        database.execute("PRAGMA page_size=1024")
        database.execute("PRAGMA cache_size=-2097152")
        database.execute("PRAGMA synchronous=NORMAL")
        database.execute("PRAGMA journal_mode=WAL")
        database.execute("PRAGMA temp_store=MEMORY")
        database.execute("PRAGMA wal_autocheckpoint=200")
        database.execute("PRAGMA journal_size_limit=1536")
        
        /*var statement: OpaquePointer? = nil
        sqlite3_prepare_v2(database.handle, "PRAGMA integrity_check", -1, &statement, nil)
        let preparedStatement = SqlitePreparedStatement(statement: statement)
        if preparedStatement.step() {
            let value = preparedStatement.stringAt(0)
            print("integrity_check: \(value)")
        }
        preparedStatement.destroy()*/
        
        sqlite3_busy_timeout(database.handle, 10000000)
        
        let result = self.getUserVersion(database)
        if result != 1 {
            database.execute("PRAGMA user_version=1")
            database.execute("CREATE TABLE __meta_tables (name INTEGER)")
        }
        
        for table in self.listTables(database).map({Int32($0)}) {
            self.tables.insert(table)
        }
        lock.unlock()
        
        checkpoints.set((Signal<Void, NoError>.single(Void()) |> delay(10.0, queue: Queue.concurrentDefaultQueue()) |> restart).start(next: { [weak self] _ in
            if let strongSelf = self , strongSelf.database != nil {
                strongSelf.lock.lock()
                var nLog: Int32 = 0
                var nFrames: Int32 = 0
                sqlite3_wal_checkpoint_v2(strongSelf.database.handle, nil, SQLITE_CHECKPOINT_PASSIVE, &nLog, &nFrames)
                strongSelf.lock.unlock()
                //print("(SQLite WAL size \(nLog) removed \(nFrames))")
            }
        }))
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
        self.database.execute("BEGIN IMMEDIATE")
    }
    
    public func commit() {
        let startTime = CFAbsoluteTimeGetCurrent()
        self.database.execute("COMMIT")
        self.commitTime += CFAbsoluteTimeGetCurrent() - startTime
    }
    
    private func getUserVersion(_ database: Database) -> Int64 {
        var statement: OpaquePointer? = nil
        sqlite3_prepare_v2(database.handle, "PRAGMA user_version", -1, &statement, nil)
        let preparedStatement = SqlitePreparedStatement(statement: statement)
        let _ = preparedStatement.step()
        let value = preparedStatement.int64At(0)
        preparedStatement.destroy()
        return value
    }
    
    private func listTables(_ database: Database) -> [Int64] {
        var statement: OpaquePointer? = nil
        sqlite3_prepare_v2(database.handle, "SELECT name FROM __meta_tables", -1, &statement, nil)
        let preparedStatement = SqlitePreparedStatement(statement: statement)
        var tables: [Int64] = []
        while preparedStatement.step() {
            let value = preparedStatement.int64At(0)
            tables.append(value)
        }
        preparedStatement.destroy()
        return tables
    }
    
    private func getStatement(_ table: Int32, key: ValueBoxKey) -> SqlitePreparedStatement {
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.getStatements[table] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            sqlite3_prepare_v2(self.database.handle, "SELECT value FROM t\(table) WHERE key=?", -1, &statement, nil)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.getStatements[table] = preparedStatement
            resultStatement =  preparedStatement
        }
        
        resultStatement.reset()
        
        resultStatement.bind(1, data: key.memory, length: key.length)
        
        return resultStatement
    }
    
    private func rangeKeyAscStatementLimit(_ table: Int32, start: ValueBoxKey, end: ValueBoxKey, limit: Int) -> SqlitePreparedStatement {
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.rangeKeyAscStatementsLimit[table] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            sqlite3_prepare_v2(self.database.handle, "SELECT key FROM t\(table) WHERE key > ? AND key < ? ORDER BY key ASC LIMIT ?", -1, &statement, nil)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.rangeKeyAscStatementsLimit[table] = preparedStatement
            resultStatement = preparedStatement
        }
        resultStatement.reset()
        
        resultStatement.bind(1, data: start.memory, length: start.length)
        resultStatement.bind(2, data: end.memory, length: end.length)
        resultStatement.bind(3, number: Int32(limit))
        
        return resultStatement
    }
    
    private func rangeKeyAscStatementNoLimit(_ table: Int32, start: ValueBoxKey, end: ValueBoxKey) -> SqlitePreparedStatement {
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.rangeKeyAscStatementsNoLimit[table] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            sqlite3_prepare_v2(self.database.handle, "SELECT key FROM t\(table) WHERE key > ? AND key < ? ORDER BY key ASC", -1, &statement, nil)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.rangeKeyAscStatementsNoLimit[table] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        resultStatement.bind(1, data: start.memory, length: start.length)
        resultStatement.bind(2, data: end.memory, length: end.length)
        
        return resultStatement
    }
    
    private func rangeKeyDescStatementLimit(_ table: Int32, start: ValueBoxKey, end: ValueBoxKey, limit: Int) -> SqlitePreparedStatement {
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.rangeKeyDescStatementsLimit[table] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            sqlite3_prepare_v2(self.database.handle, "SELECT key FROM t\(table) WHERE key > ? AND key < ? ORDER BY key DESC LIMIT ?", -1, &statement, nil)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.rangeKeyDescStatementsLimit[table] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        resultStatement.bind(1, data: start.memory, length: start.length)
        resultStatement.bind(2, data: end.memory, length: end.length)
        resultStatement.bind(3, number: Int32(limit))
        
        return resultStatement
    }
    
    private func rangeKeyDescStatementNoLimit(_ table: Int32, start: ValueBoxKey, end: ValueBoxKey) -> SqlitePreparedStatement {
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.rangeKeyDescStatementsNoLimit[table] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            sqlite3_prepare_v2(self.database.handle, "SELECT key FROM t\(table) WHERE key > ? AND key < ? ORDER BY key DESC", -1, &statement, nil)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.rangeKeyDescStatementsNoLimit[table] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        resultStatement.bind(1, data: start.memory, length: start.length)
        resultStatement.bind(2, data: end.memory, length: end.length)
        
        return resultStatement
    }
    
    private func rangeValueAscStatementLimit(_ table: Int32, start: ValueBoxKey, end: ValueBoxKey, limit: Int) -> SqlitePreparedStatement {
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.rangeValueAscStatementsLimit[table] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            sqlite3_prepare_v2(self.database.handle, "SELECT key, value FROM t\(table) WHERE key > ? AND key < ? ORDER BY key ASC LIMIT ?", -1, &statement, nil)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.rangeValueAscStatementsLimit[table] = preparedStatement
            resultStatement = preparedStatement
        }
        resultStatement.reset()
        
        resultStatement.bind(1, data: start.memory, length: start.length)
        resultStatement.bind(2, data: end.memory, length: end.length)
        resultStatement.bind(3, number: Int32(limit))
        
        return resultStatement
    }
    
    private func rangeValueAscStatementNoLimit(_ table: Int32, start: ValueBoxKey, end: ValueBoxKey) -> SqlitePreparedStatement {
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.rangeValueAscStatementsNoLimit[table] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            sqlite3_prepare_v2(self.database.handle, "SELECT key, value FROM t\(table) WHERE key > ? AND key < ? ORDER BY key ASC", -1, &statement, nil)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.rangeValueAscStatementsNoLimit[table] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        resultStatement.bind(1, data: start.memory, length: start.length)
        resultStatement.bind(2, data: end.memory, length: end.length)
        
        return resultStatement
    }
    
    private func rangeValueDescStatementLimit(_ table: Int32, start: ValueBoxKey, end: ValueBoxKey, limit: Int) -> SqlitePreparedStatement {
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.rangeValueDescStatementsLimit[table] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            sqlite3_prepare_v2(self.database.handle, "SELECT key, value FROM t\(table) WHERE key > ? AND key < ? ORDER BY key DESC LIMIT ?", -1, &statement, nil)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.rangeValueDescStatementsLimit[table] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        resultStatement.bind(1, data: start.memory, length: start.length)
        resultStatement.bind(2, data: end.memory, length: end.length)
        resultStatement.bind(3, number: Int32(limit))
        
        return resultStatement
    }
    
    private func rangeValueDescStatementNoLimit(_ table: Int32, start: ValueBoxKey, end: ValueBoxKey) -> SqlitePreparedStatement {
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.rangeKeyDescStatementsNoLimit[table] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            sqlite3_prepare_v2(self.database.handle, "SELECT key, value FROM t\(table) WHERE key > ? AND key < ? ORDER BY key DESC", -1, &statement, nil)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.rangeValueDescStatementsNoLimit[table] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        resultStatement.bind(1, data: start.memory, length: start.length)
        resultStatement.bind(2, data: end.memory, length: end.length)
        
        return resultStatement
    }
    
    private func existsStatement(_ table: Int32, key: ValueBoxKey) -> SqlitePreparedStatement {
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.existsStatements[table] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            sqlite3_prepare_v2(self.database.handle, "SELECT rowid FROM t\(table) WHERE key=?", -1, &statement, nil)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.existsStatements[table] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        resultStatement.bind(1, data: key.memory, length: key.length)
        
        return resultStatement
    }
    
    private func updateStatement(_ table: Int32, key: ValueBoxKey, value: MemoryBuffer) -> SqlitePreparedStatement {
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.updateStatements[table] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            sqlite3_prepare_v2(self.database.handle, "UPDATE t\(table) SET value=? WHERE key=?", -1, &statement, nil)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.updateStatements[table] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()

        resultStatement.bind(1, data: value.memory, length: value.length)
        resultStatement.bind(2, data: key.memory, length: key.length)
        
        return resultStatement
    }
    
    private func insertStatement(_ table: Int32, key: ValueBoxKey, value: MemoryBuffer) -> SqlitePreparedStatement {
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.insertStatements[table] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            sqlite3_prepare_v2(self.database.handle, "INSERT INTO t\(table) (key, value) VALUES(?, ?)", -1, &statement, nil)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.insertStatements[table] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        resultStatement.bind(1, data: key.memory, length: key.length)
        if value.length == 0 {
            resultStatement.bindNull(2)
        } else {
            resultStatement.bind(2, data: value.memory, length: value.length)
        }
        
        return resultStatement
    }
    
    private func deleteStatement(_ table: Int32, key: ValueBoxKey) -> SqlitePreparedStatement {
        let resultStatement: SqlitePreparedStatement
        
        if let statement = self.deleteStatements[table] {
            resultStatement = statement
        } else {
            var statement: OpaquePointer? = nil
            sqlite3_prepare_v2(self.database.handle, "DELETE FROM t\(table) WHERE key=?", -1, &statement, nil)
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            self.deleteStatements[table] = preparedStatement
            resultStatement = preparedStatement
        }
        
        resultStatement.reset()
        
        resultStatement.bind(1, data: key.memory, length: key.length)
        
        return resultStatement
    }
    
    public func get(_ table: Int32, key: ValueBoxKey) -> ReadBuffer? {
        let startTime = CFAbsoluteTimeGetCurrent()
        if self.tables.contains(table) {
            let statement = self.getStatement(table, key: key)
            
            var buffer: ReadBuffer?
            
            while statement.step() {
                buffer = statement.valueAt(0)
                break
            }
            
            statement.reset()
            
            self.readQueryTime += CFAbsoluteTimeGetCurrent() - startTime
            
            return buffer
        }
        
        return nil
    }
    
    public func exists(_ table: Int32, key: ValueBoxKey) -> Bool {
        if let _ = self.get(table, key: key) {
            return true
        }
        return false
    }
    
    public func range(_ table: Int32, start: ValueBoxKey, end: ValueBoxKey, values: @noescape(ValueBoxKey, ReadBuffer) -> Bool, limit: Int) {
        if start == end {
            return
        }
        
        if self.tables.contains(table) {
            let statement: SqlitePreparedStatement
            
            var startTime = CFAbsoluteTimeGetCurrent()
            
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
            
            while statement.step() {
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
    
    public func range(_ table: Int32, start: ValueBoxKey, end: ValueBoxKey, keys: @noescape(ValueBoxKey) -> Bool, limit: Int) {
        if self.tables.contains(table) {
            let statement: SqlitePreparedStatement
            
            var startTime = CFAbsoluteTimeGetCurrent()
            
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
            
            while statement.step() {
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
    
    public func set(_ table: Int32, key: ValueBoxKey, value: MemoryBuffer) {
        if !self.tables.contains(table) {
            self.database.execute("CREATE TABLE t\(table) (key BLOB, value BLOB)")
            self.database.execute("CREATE INDEX t\(table)_key ON t\(table) (key)")
            self.tables.insert(table)
            self.database.execute("INSERT INTO __meta_tables(name) VALUES (\(table))")
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        var exists = false
        let existsStatement = self.existsStatement(table, key: key)
        if existsStatement.step() {
            exists = true
        }
        existsStatement.reset()
        
        if exists {
            let statement = self.updateStatement(table, key: key, value: value)
            while statement.step() {
            }
            statement.reset()
        } else {
            let statement = self.insertStatement(table, key: key, value: value)
            while statement.step() {
            }
            statement.reset()
        }
        
        self.writeQueryTime += CFAbsoluteTimeGetCurrent() - startTime
    }
    
    public func remove(_ table: Int32, key: ValueBoxKey) {
        if self.tables.contains(table) {
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            let statement = self.deleteStatement(table, key: key)
            while statement.step() {
            }
            statement.reset()
            
            self.writeQueryTime += CFAbsoluteTimeGetCurrent() - startTime
        }
    }
    
    private func clearStatements() {
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
        
        for (_, statement) in self.deleteStatements {
            statement.destroy()
        }
        self.deleteStatements.removeAll()
    }
    
    public func drop() {
        self.clearStatements()

        self.lock.lock()
        self.database = nil
        self.lock.unlock()
        
        let _ = try? FileManager.default.removeItem(atPath: self.basePath)
        self.database = self.openDatabase()
        
        tables.removeAll()
    }
}
