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

import sqlcipher

/// A connection (handle) to SQLite.
public final class Database {

    /// The location of a SQLite database.
    public enum Location {

        /// An in-memory database (equivalent to `.URI(":memory:")`).
        ///
        /// See: <https://www.sqlite.org/inmemorydb.html#sharedmemdb>
        case InMemory

        /// A temporary, file-backed database (equivalent to `.URI("")`).
        ///
        /// See: <https://www.sqlite.org/inmemorydb.html#temp_db>
        case Temporary

        /// A database located at the given URI filename (or path).
        ///
        /// See: <https://www.sqlite.org/uri.html>
        ///
        /// - parameter filename: A URI filename
        case URI(String)

    }

    internal var handle: OpaquePointer? = nil

    /// Whether or not the database was opened in a read-only state.
    public var readonly: Bool { return sqlite3_db_readonly(handle, nil) == 1 }

    /// Initializes a new connection to a database.
    ///
    /// - parameter location: The location of the database. Creates a new database if
    ///                  it doesn’t already exist (unless in read-only mode).
    ///
    ///                  Default: `.InMemory`.
    ///
    /// - parameter readonly: Whether or not to open the database in a read-only
    ///                  state.
    ///
    ///                  Default: `false`.
    ///
    /// - returns: A new database connection.
    public init?(_ location: Location = .InMemory, readonly: Bool = false) {
        let flags = readonly ? SQLITE_OPEN_READONLY : SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE
        let res = sqlite3_open_v2(location.description, &self.handle, flags | SQLITE_OPEN_FULLMUTEX, nil)
        if res != SQLITE_OK {
            return nil
        }
    }

    /// Initializes a new connection to a database.
    ///
    /// - parameter filename: The location of the database. Creates a new database if
    ///                  it doesn’t already exist (unless in read-only mode).
    ///
    /// - parameter readonly: Whether or not to open the database in a read-only
    ///                  state.
    ///
    ///                  Default: `false`.
    ///
    /// - returns: A new database connection.
    public convenience init?(_ filename: String, readonly: Bool = false) {
        self.init(.URI(filename), readonly: readonly)
    }

    deinit { sqlite3_close(self.handle) } // sqlite3_close_v2 in Yosemite/iOS 8?

    // MARK: - Execute

    /// Executes a batch of SQL statements.
    ///
    /// - parameter SQL: A batch of zero or more semicolon-separated SQL statements.
    public func execute(_ SQL: String) -> Bool {
        return sqlite3_exec(self.handle, SQL, nil, nil, nil) == SQLITE_OK
    }
}

extension Database.Location: CustomStringConvertible {

    public var description: String {
        switch self {
        case .InMemory:
            return ":memory:"
        case .Temporary:
            return ""
        case .URI(let URI):
            return URI
        }
    }

}
