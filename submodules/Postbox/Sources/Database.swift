//
// SQLite.swift
// https://github.com/stephencelis/SQLite.swift
// Copyright (c) 2014-2015 Stephen Celis.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

import Foundation
import sqlcipher

private let ensureInitialized: Void = {
    sqlite3_initialize()
    
    return Void()
}()

public final class Database {
    public struct OpenError: Error {
        public let code: Int32
        public let systemErrno: Int32
    }

    internal var handle: OpaquePointer? = nil

    private init(handle: OpaquePointer?) {
        self.handle = handle
    }

    public convenience init?(_ location: String, readOnly: Bool) {
        switch Database.openHandle(location, readOnly: readOnly) {
        case let .success(handle):
            self.init(handle: handle)
        case .failure:
            return nil
        }
    }

    /// Like `init?`, but reports why the open failed. `systemErrno` is what the caller needs
    /// to tell a problem with the file itself (EISDIR, EIO) from one deleting the file
    /// cannot fix (EPERM/EACCES from data protection while the device is locked, descriptor
    /// exhaustion, out of memory, disk full).
    public static func open(_ location: String, readOnly: Bool) -> Result<Database, OpenError> {
        switch Database.openHandle(location, readOnly: readOnly) {
        case let .success(handle):
            return .success(Database(handle: handle))
        case let .failure(error):
            return .failure(error)
        }
    }

    private static func openHandle(_ location: String, readOnly: Bool) -> Result<OpaquePointer?, OpenError> {
        let _ = ensureInitialized
        
        if location != ":memory:" {
            let guardFd = Darwin.open(location + "-guard", O_WRONLY | O_CREAT | O_APPEND, S_IRUSR | S_IWUSR)
            if guardFd >= 0 {
                close(guardFd)
            }
        }
        let flags: Int32
        if readOnly {
            flags = SQLITE_OPEN_READONLY
        } else {
            flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        }
        var handle: OpaquePointer? = nil
        let res = sqlite3_open_v2(location, &handle, flags, nil)
        if res != SQLITE_OK {
            // SQLite allocates the handle even when the open fails; it carries the errno and
            // must be closed, or it leaks.
            let systemErrno: Int32 = handle != nil ? sqlite3_system_errno(handle) : 0
            postboxLog("sqlite3_open_v2: \(res), errno \(systemErrno)")
            sqlite3_close(handle)
            return .failure(OpenError(code: res, systemErrno: systemErrno))
        }
        return .success(handle)
    }

    deinit {
        sqlite3_close(self.handle)
    } // sqlite3_close_v2 in Yosemite/iOS 8?

    public func execute(_ SQL: String) -> Bool {
        let res = sqlite3_exec(self.handle, SQL, nil, nil, nil)
        if res == SQLITE_OK {
            return true
        } else {
            if let error = sqlite3_errmsg(self.handle), let str = NSString(utf8String: error) {
                print("SQL error \(res): \(str) on SQL")
            } else {
                print("SQL error \(res) on SQL")
            }
            return false
        }
    }
    
    public func currentError() -> String? {
        if let error = sqlite3_errmsg(self.handle), let str = NSString(utf8String: error) {
            return "SQL error \(str)"
        } else {
            return nil
        }
    }
}
