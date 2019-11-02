import Foundation
import sqlcipher

private final class SqliteInterfaceStatement {
    let statement: OpaquePointer?
    
    init(statement: OpaquePointer?) {
        self.statement = statement
    }
    
    func bind(_ index: Int, data: UnsafeRawPointer, length: Int) {
        sqlite3_bind_blob(statement, Int32(index), data, Int32(length), nil)
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
    
    func step() -> Bool {
        let result = sqlite3_step(statement)
        if result != SQLITE_ROW && result != SQLITE_DONE {
            assertionFailure("Sqlite error \(result)")
        }
        return result == SQLITE_ROW
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

public final class SqliteStatementCursor {
    private let statement: SqliteInterfaceStatement
    
    fileprivate init(statement: SqliteInterfaceStatement) {
        self.statement = statement
    }
    
    public func getInt32(at index: Int) -> Int32 {
        return self.statement.int32At(index)
    }
    
    public func getInt64(at index: Int) -> Int64 {
        return self.statement.int64At(index)
    }
    
    public func getString(at index: Int) -> String {
        let value = self.statement.valueAt(index)
        if let string = String(data: value.makeData(), encoding: .utf8) {
            return string
        } else {
            return ""
        }
    }
    
    public func getData(at index: Int) -> Data {
        return self.statement.valueAt(index).makeData()
    }
}

public enum SqliteInterfaceStatementKey {
    case int32(Int32)
    case int64(Int64)
    case data(Data)
}

public final class SqliteInterface {
    private let database: Database
    
    public init?(databasePath: String) {
        if let database = Database(databasePath) {
            self.database = database
        } else {
            return nil
        }
    }
    
    public func unlock(password: Data) -> Bool {
        return password.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> Bool in
            if sqlite3_key(self.database.handle, bytes, Int32(password.count)) != SQLITE_OK {
                return false
            }
            var statement: OpaquePointer? = nil
            let status = sqlite3_prepare_v2(self.database.handle, "SELECT * FROM SQLITE_MASTER", -1, &statement, nil)
            if status != SQLITE_OK {
                return false
            }
            let preparedStatement = SqlitePreparedStatement(statement: statement)
            if !preparedStatement.step(handle: self.database.handle, true, path: "") {
                return false
            }
            preparedStatement.destroy()
            return true
        }
    }
    
    public func withStatement(_ query: String, _ f: (([SqliteInterfaceStatementKey], (SqliteStatementCursor) -> Bool) -> Void) -> Void) {
        var statement: OpaquePointer? = nil
        if sqlite3_prepare_v2(database.handle, query, -1, &statement, nil) != SQLITE_OK {
            return
        }
        let preparedStatement = SqliteInterfaceStatement(statement: statement)
        
        f({ keys, iterate in
            preparedStatement.reset()
            var index = 1
            for key in keys {
                switch key {
                    case let .data(data):
                        let dataCount = data.count
                        data.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> Void in
                            preparedStatement.bind(index, data: bytes, length: dataCount)
                        }
                    case let .int32(value):
                        preparedStatement.bind(index, number: value)
                    case let .int64(value):
                        preparedStatement.bind(index, number: value)
                }
                index += 1
            }
            let cursor = SqliteStatementCursor(statement: preparedStatement)
            while preparedStatement.step() {
                if !iterate(cursor) {
                    break
                }
            }
        })
        
        preparedStatement.reset()
        preparedStatement.destroy()
    }
    
    public func selectWithKeys(_ query: String, keys: [(Int, Data)], _ f: (SqliteStatementCursor) -> Bool) {
        var statement: OpaquePointer? = nil
        if sqlite3_prepare_v2(database.handle, query, -1, &statement, nil) != SQLITE_OK {
            return
        }
        let preparedStatement = SqliteInterfaceStatement(statement: statement)
        for (index, key) in keys {
            key.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> Void in
                preparedStatement.bind(index, data: bytes, length: key.count)
            }
        }
        let cursor = SqliteStatementCursor(statement: preparedStatement)
        while preparedStatement.step() {
            if !f(cursor) {
                break
            }
        }
        preparedStatement.reset()
        preparedStatement.destroy()
    }
    
    public func select(_ query: String, _ f: (SqliteStatementCursor) -> Bool) {
        var statement: OpaquePointer? = nil
        if sqlite3_prepare_v2(database.handle, query, -1, &statement, nil) != SQLITE_OK {
            return
        }
        if statement == nil {
            return
        }
        let preparedStatement = SqliteInterfaceStatement(statement: statement)
        let cursor = SqliteStatementCursor(statement: preparedStatement)
        while preparedStatement.step() {
            if !f(cursor) {
                break
            }
        }
        preparedStatement.reset()
        preparedStatement.destroy()
    }
    
    public func explain(_ query: String) -> String {
        var result = ""
        self.select("EXPLAIN QUERY PLAN \(query)", { cursor in
            if !result.isEmpty {
                result.append("\n")
            }
            result.append("\(cursor.getInt32(at: 0)) \(cursor.getInt32(at: 1)) \(cursor.getInt32(at: 2)) \(cursor.getString(at: 3))")
            return true
        })
        return result
    }
}
