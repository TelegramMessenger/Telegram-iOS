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
}

public final class SqliteInterface {
    private let database: Database
    
    init(databasePath: String) {
        self.database = Database(databasePath)
    }
    
    public func unlock(password: Data) -> Bool {
        return password.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> Bool in
            return sqlite3_key(self.database.handle, bytes, Int32(password.count)) == SQLITE_OK
        }
    }
    
    public func select(_ query: String, _ f: (SqliteStatementCursor) -> Bool) {
        var statement: OpaquePointer? = nil
        sqlite3_prepare_v2(database.handle, query, -1, &statement, nil)
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
}
