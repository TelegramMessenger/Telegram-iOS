import Foundation
import sqlcipher

private struct LmdbTable {
    var dbi: MDB_dbi
}

private struct LmdbCursor {
    var cursor: OpaquePointer!
    
    func seekTo(_ key: ValueBoxKey, forward: Bool) -> (ValueBoxKey, ReadBuffer)? {
        var mdbKey = MDB_val()
        var mdbData = MDB_val()
        
        mdbKey.mv_data = key.memory
        mdbKey.mv_size = key.length
        mdbData.mv_data = nil
        mdbData.mv_size = 0
    
        let result = mdb_cursor_get(self.cursor, &mdbKey, &mdbData, forward ? MDB_SET_RANGE : MDB_SET_KEY)
    
        if result == MDB_SUCCESS {
            let actualKey = ValueBoxKey(length: mdbKey.mv_size)
            memcpy(actualKey.memory, mdbKey.mv_data, mdbKey.mv_size)
            
            let value = malloc(mdbData.mv_size)!
            memcpy(value, mdbData.mv_data, mdbData.mv_size)
            
            return (actualKey, ReadBuffer(memory: value, length: mdbData.mv_size, freeWhenDone: true))
        } else if result == MDB_NOTFOUND {
            if !forward {
                return self.previous()
            } else {
                return nil
            }
        } else {
            print("(LmdbValueBox mdb_cursor_get failed with \(result))")
            return nil
        }
    }
    
    func previous() -> (ValueBoxKey, ReadBuffer)? {
        var mdbKey = MDB_val()
        var mdbData = MDB_val()
        
        mdbKey.mv_data = nil
        mdbKey.mv_size = 0
        mdbData.mv_data = nil
        mdbData.mv_size = 0
        
        let result = mdb_cursor_get(self.cursor, &mdbKey, &mdbData, MDB_PREV)
        if result == MDB_SUCCESS {
            let actualKey = ValueBoxKey(length: mdbKey.mv_size)
            memcpy(actualKey.memory, mdbKey.mv_data, mdbKey.mv_size)
            
            let value = malloc(mdbData.mv_size)!
            memcpy(value, mdbData.mv_data, mdbData.mv_size)
            
            return (actualKey, ReadBuffer(memory: value, length: mdbData.mv_size, freeWhenDone: true))
        } else if result == MDB_NOTFOUND {
            return nil
        } else {
            print("(LmdbValueBox mdb_cursor_get failed with \(result))")
            return nil
        }
    }
    
    func next() -> (ValueBoxKey, ReadBuffer)? {
        var mdbKey = MDB_val()
        var mdbData = MDB_val()
        
        mdbKey.mv_data = nil
        mdbKey.mv_size = 0
        mdbData.mv_data = nil
        mdbData.mv_size = 0
        
        let result = mdb_cursor_get(self.cursor, &mdbKey, &mdbData, MDB_NEXT)
        if result == MDB_SUCCESS {
            let actualKey = ValueBoxKey(length: mdbKey.mv_size)
            memcpy(actualKey.memory, mdbKey.mv_data, mdbKey.mv_size)
            
            let value = malloc(mdbData.mv_size)!
            memcpy(value, mdbData.mv_data, mdbData.mv_size)
            
            return (actualKey, ReadBuffer(memory: value, length: mdbData.mv_size, freeWhenDone: true))
        } else if result == MDB_NOTFOUND {
            return nil
        } else {
            print("(LmdbValueBox mdb_cursor_get failed with \(result))")
            return nil
        }
    }
}

public final class LmdbValueBox: ValueBox {
    private var env: OpaquePointer? = nil
    private var tables: [Int32 : LmdbTable] = [:]
    
    private var sharedTxn: OpaquePointer? = nil
    
    private var readQueryTime: CFAbsoluteTime = 0.0
    private var writeQueryTime: CFAbsoluteTime = 0.0
    private var commitTime: CFAbsoluteTime = 0.0
    
    public init?(basePath: String) {
        var result = mdb_env_create(&self.env)
        if result != MDB_SUCCESS {
            print("(LmdbValueBox mdb_env_create failed with \(result))")
            return nil
        }
        
        let path = basePath + "/lmdb"
        
        var createDirectory = false
        var isDirectory: ObjCBool = false as ObjCBool
        if FileManager.default().fileExists(atPath: path, isDirectory: &isDirectory) {
            if !isDirectory {
                do {
                    try FileManager.default().removeItem(atPath: path)
                } catch _ { }
                createDirectory = true
            }
        }
        else {
            createDirectory = true
        }
        
        if createDirectory {
            do {
                try FileManager.default().createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            } catch _ { }
        }
        
        mdb_env_set_mapsize(self.env, 500 * 1024 * 1024);
        mdb_env_set_maxdbs(self.env, 64)
        
        path.withCString { string in
            result = mdb_env_open(self.env, string, UInt32(MDB_NOSYNC), 0o664)
        }
        if result != MDB_SUCCESS {
            print("(LmdbValueBox mdb_env_open failed with \(result))")
            return nil
        }
        
        var removedReaders: Int32 = 0
        result = mdb_reader_check(self.env, &removedReaders)
        
        if removedReaders != 0 {
            print("(LmdbValueBox removed \(removedReaders) stale readers)")
        }
    }
    
    deinit {
        mdb_env_close(self.env)
    }
    
    private func createTableWithName(_ name: Int32) -> LmdbTable? {
        var dbi = MDB_dbi()
        let result = mdb_dbi_open(self.sharedTxn, "\(name)", UInt32(MDB_CREATE), &dbi)
    
        if result != MDB_SUCCESS {
            print("(LmdbValueBox mdb_dbi_open failed with \(result))")
            
            return nil
        }
        
        return LmdbTable(dbi: dbi)
    }
    
    public func beginStats() {
        self.readQueryTime = 0.0
        self.writeQueryTime = 0.0
        self.commitTime = 0.0
    }
    
    public func endStats() {
        print("(LmdbValueBox stats read: \(self.readQueryTime * 1000.0) ms, write: \(self.writeQueryTime * 1000.0) ms, commit: \(self.commitTime * 1000.0) ms")
    }
    
    public func begin() {
        if self.sharedTxn != nil {
            print("(LmdbValueBox already in transaction)")
        } else {
            let result = mdb_txn_begin(self.env, nil, 0, &sharedTxn)
            if result != MDB_SUCCESS {
                print("(LmdbValueBox txn_begin failed with \(result))")
                return
            }
        }
    }
    
    public func commit() {
        let startTime = CFAbsoluteTimeGetCurrent()
        if self.sharedTxn == nil {
            print("(LmdbValueBox already no current transaction)")
        } else {
            let result = mdb_txn_commit(self.sharedTxn)
            self.sharedTxn = nil
            self.commitTime += CFAbsoluteTimeGetCurrent() - startTime
            if result != MDB_SUCCESS {
                print("(LmdbValueBox txn_commit failed with \(result))")
                return
            }
        }
    }
    
    public func range(_ table: Int32, start: ValueBoxKey, end: ValueBoxKey, values: @noescape(ValueBoxKey, ReadBuffer) -> Bool, limit: Int) {
        if start == end || limit == 0 {
            return
        }
        
        var commit = false
        if self.sharedTxn == nil {
            self.begin()
            commit = true
        }
        
        var nativeTable: LmdbTable?
        if let existingTable = self.tables[table] {
            nativeTable = existingTable
        } else if let createdTable = self.createTableWithName(table) {
            nativeTable = createdTable
            self.tables[table] = createdTable
        }
        
        if let nativeTable = nativeTable {
            var startTime = CFAbsoluteTimeGetCurrent()
            var cursorPtr: OpaquePointer? = nil
            let result = mdb_cursor_open(self.sharedTxn, nativeTable.dbi, &cursorPtr)
            if result != MDB_SUCCESS {
                print("(LmdbValueBox mdb_cursor_open failed with \(result))")
            } else {
                let cursor = LmdbCursor(cursor: cursorPtr)
                
                if start < end {
                    var value = cursor.seekTo(start, forward: true)
                    if value != nil {
                        if value!.0 == start {
                            value = cursor.next()
                        }
                    }
                    
                    var currentTime = CFAbsoluteTimeGetCurrent()
                    readQueryTime += currentTime - startTime
                    startTime = currentTime
                    
                    var count = 0
                    if value != nil && value!.0 < end {
                        count += 1
                        let _ = values(value!.0, value!.1)
                    }
                    
                    while value != nil && value!.0 < end && count < limit {
                        startTime = CFAbsoluteTimeGetCurrent()
                        
                        value = cursor.next()
                        
                        currentTime = CFAbsoluteTimeGetCurrent()
                        readQueryTime += currentTime - startTime
                        startTime = currentTime
                        
                        if value != nil && value!.0 < end {
                            count += 1
                            let _ = values(value!.0, value!.1)
                        }
                    }
                } else {
                    var startTime = CFAbsoluteTimeGetCurrent()
                    var value = cursor.seekTo(start, forward: false)
                    if value != nil {
                        if value!.0 == start {
                            value = cursor.previous()
                        }
                    }
                    
                    var currentTime = CFAbsoluteTimeGetCurrent()
                    readQueryTime += currentTime - startTime
                    startTime = currentTime
                    
                    var count = 0
                    if value != nil && value!.0 > end {
                        count += 1
                        let _ = values(value!.0, value!.1)
                    }
                    
                    while value != nil && value!.0 > end && count < limit {
                        startTime = CFAbsoluteTimeGetCurrent()
                        
                        value = cursor.previous()
                        
                        currentTime = CFAbsoluteTimeGetCurrent()
                        readQueryTime += currentTime - startTime
                        startTime = currentTime
                        
                        if value != nil && value!.0 > end {
                            count += 1
                            let _ = values(value!.0, value!.1)
                        }
                    }
                }
                    
                mdb_cursor_close(cursorPtr)
            }
        }
        
        if commit {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            self.commit()
            
            readQueryTime += CFAbsoluteTimeGetCurrent() - startTime
        }
    }
    
    public func range(_ table: Int32, start: ValueBoxKey, end: ValueBoxKey, keys: @noescape(ValueBoxKey) -> Bool, limit: Int) {
        self.range(table, start: start, end: end, values: { key, _ in
            return keys(key)
        }, limit: limit)
    }
    
    public func get(_ table: Int32, key: ValueBoxKey) -> ReadBuffer? {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        var commit = false
        if self.sharedTxn == nil {
            self.begin()
            commit = true
        }
        
        var nativeTable: LmdbTable?
        if let existingTable = self.tables[table] {
            nativeTable = existingTable
        } else if let createdTable = self.createTableWithName(table) {
            nativeTable = createdTable
            self.tables[table] = createdTable
        }
        
        var resultValue: ReadBuffer?
        
        if let nativeTable = nativeTable {
            var mdbKey = MDB_val()
            var mdbData = MDB_val()
            
            mdbKey.mv_data = key.memory
            mdbKey.mv_size = key.length
            
            let result = mdb_get(self.sharedTxn, nativeTable.dbi, &mdbKey, &mdbData)
            
            if result == MDB_SUCCESS {
                let value = malloc(mdbData.mv_size)!
                memcpy(value, mdbData.mv_data, mdbData.mv_size)
                resultValue = ReadBuffer(memory: value, length: mdbData.mv_size, freeWhenDone: true)
            } else {
                if result != MDB_NOTFOUND {
                    print("(LmdbValueBox mdb_get failed with \(result))")
                }
            }
        }
        
        if commit {
            self.commit()
        }
        
        readQueryTime += CFAbsoluteTimeGetCurrent() - startTime
        
        return resultValue
    }
    
    public func exists(_ table: Int32, key: ValueBoxKey) -> Bool {
        return self.get(table, key: key) != nil
    }
    
    public func set(_ table: Int32, key: ValueBoxKey, value: MemoryBuffer) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        var commit = false
        if self.sharedTxn == nil {
            self.begin()
            commit = true
        }
        
        var nativeTable: LmdbTable?
        if let existingTable = self.tables[table] {
            nativeTable = existingTable
        } else if let createdTable = self.createTableWithName(table) {
            nativeTable = createdTable
            self.tables[table] = createdTable
        }
        
        if let nativeTable = nativeTable {
            var mdbKey = MDB_val()
            var mdbData = MDB_val()
            
            mdbKey.mv_data = key.memory
            mdbKey.mv_size = key.length
            mdbData.mv_data = value.memory
            mdbData.mv_size = value.length
            
            let result = mdb_put(self.sharedTxn, nativeTable.dbi, &mdbKey, &mdbData, 0)
            if result != MDB_SUCCESS {
                print("(LmdbValueBox mdb_set failed with \(result))")
            }
        }
        
        if commit {
            self.commit()
        }
        
        writeQueryTime += CFAbsoluteTimeGetCurrent() - startTime
    }
    
    public func remove(_ table: Int32, key: ValueBoxKey) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        var commit = false
        if self.sharedTxn == nil {
            self.begin()
            commit = true
        }
        
        var nativeTable: LmdbTable?
        if let existingTable = self.tables[table] {
            nativeTable = existingTable
        } else if let createdTable = self.createTableWithName(table) {
            nativeTable = createdTable
            self.tables[table] = createdTable
        }
        
        if let nativeTable = nativeTable {
            var mdbKey = MDB_val()
            
            mdbKey.mv_data = key.memory
            mdbKey.mv_size = key.length
            
            let result = mdb_del(self.sharedTxn, nativeTable.dbi, &mdbKey, nil)
            if result != MDB_SUCCESS {
                print("(LmdbValueBox mdb_set failed with \(result))")
            }
        }
        
        if commit {
            self.commit()
        }
        
        writeQueryTime += CFAbsoluteTimeGetCurrent() - startTime
    }
    
    public func drop() {
        
    }
}
