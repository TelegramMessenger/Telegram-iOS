import Foundation
import XCTest
import SwiftSignalKit
import sqlcipher
@testable import Postbox

/// `SqliteValueBox` self-heals a database it owns by deleting it. The app and its
/// extensions share one WAL database, so that deletion must (1) only ever happen from
/// the owning read-write connection, (2) remove the main file together with `-wal` and
/// `-shm` — a lone `db_sqlite` deletion leaves another process's WAL/shm pair behind for
/// the next opener to mistake for its own — and (3) never be triggered by a transient
/// result such as `SQLITE_BUSY`, which only means another process holds a lock.
final class SqliteValueBoxRecoveryPolicyTests: XCTestCase {
    private var queue: Queue!
    private var basePath: String!
    /// Keeps every opened box alive until tearDown: `SqliteValueBox.deinit` must run on its queue.
    private var openedBoxes: [SqliteValueBox] = []

    override func setUp() {
        super.setUp()
        self.queue = Queue(name: "SqliteValueBoxRecoveryPolicyTests")
        self.basePath = NSTemporaryDirectory() + "SqliteValueBoxRecoveryPolicyTests-" + UUID().uuidString
    }

    override func tearDown() {
        self.queue.sync {
            for box in self.openedBoxes {
                box.internalClose()
            }
            self.openedBoxes.removeAll()
        }
        let _ = try? FileManager.default.removeItem(atPath: self.basePath)
        super.tearDown()
    }

    private var databasePath: String {
        return self.basePath + "/db_sqlite"
    }

    private func open(isTemporary: Bool, isReadOnly: Bool, removeDatabaseOnError: Bool, encryptionParameters: ValueBoxEncryptionParameters? = nil) -> SqliteValueBox? {
        var result: SqliteValueBox?
        self.queue.sync {
            result = SqliteValueBox(basePath: self.basePath, queue: self.queue, isTemporary: isTemporary, isReadOnly: isReadOnly, useCaches: false, removeDatabaseOnError: removeDatabaseOnError, encryptionParameters: encryptionParameters, upgradeProgress: { _ in })
            if let result = result {
                self.openedBoxes.append(result)
            }
        }
        return result
    }

    private func close(_ valueBox: SqliteValueBox?) {
        self.queue.sync {
            valueBox?.internalClose()
        }
    }

    private let table = ValueBoxTable(id: 1000, keyType: .int64, compactValuesOnCreation: false)

    private func key(_ value: Int64) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: value)
        return key
    }

    private func writeRow(_ valueBox: SqliteValueBox, key: Int64, value: [UInt8]) {
        self.queue.sync {
            valueBox.begin()
            valueBox.set(self.table, key: self.key(key), value: MemoryBuffer(data: Data(value)))
            valueBox.commit()
        }
    }

    private func readRow(_ valueBox: SqliteValueBox, key: Int64) -> [UInt8]? {
        var result: [UInt8]?
        self.queue.sync {
            valueBox.begin()
            if let buffer = valueBox.get(self.table, key: self.key(key)) {
                result = [UInt8](Data(bytes: buffer.memory, count: buffer.length))
            }
            valueBox.commit()
        }
        return result
    }

    private func makeEncryptionParameters(seed: UInt8) -> ValueBoxEncryptionParameters {
        return ValueBoxEncryptionParameters(
            forceEncryptionIfNoSet: true,
            key: ValueBoxEncryptionParameters.Key(data: Data(repeating: seed, count: 32))!,
            salt: ValueBoxEncryptionParameters.Salt(data: Data(repeating: seed &+ 1, count: 16))!
        )
    }

    // MARK: - Transient results are not an encryption verdict

    func testTransientResultCodesAreNotTreatedAsAnEncryptionVerdict() {
        let transient: [Int32] = [
            SQLITE_BUSY,
            SQLITE_LOCKED,
            SQLITE_IOERR,
            SQLITE_IOERR | (2 << 8), // SQLITE_IOERR_SHORT_READ: extended codes carry the primary code in the low byte
            SQLITE_CANTOPEN,
            SQLITE_PROTOCOL,
            SQLITE_NOMEM,
            SQLITE_FULL,
            SQLITE_INTERRUPT,
        ]
        for code in transient {
            XCTAssertTrue(isTransientSqliteResultCode(code), "\(code) means the database is momentarily unavailable, not that the key is wrong")
        }

        let verdicts: [Int32] = [SQLITE_OK, SQLITE_ROW, SQLITE_DONE, SQLITE_ERROR, SQLITE_CORRUPT, SQLITE_NOTADB]
        for code in verdicts {
            XCTAssertFalse(isTransientSqliteResultCode(code), "\(code) is a definitive answer about the file's content")
        }
    }

    func testOnlyLockContentionIsWorthRetrying() {
        let contention: [Int32] = [
            SQLITE_BUSY,
            SQLITE_BUSY | (1 << 8), // SQLITE_BUSY_RECOVERY
            SQLITE_LOCKED,
            SQLITE_PROTOCOL,
        ]
        for code in contention {
            XCTAssertTrue(isLockContentionSqliteResultCode(code), "\(code): another connection holds the file, a second attempt can succeed")
        }

        let notWorthRetrying: [Int32] = [SQLITE_FULL, SQLITE_NOMEM, SQLITE_CANTOPEN, SQLITE_IOERR, SQLITE_CORRUPT, SQLITE_NOTADB, SQLITE_OK]
        for code in notWorthRetrying {
            XCTAssertFalse(isLockContentionSqliteResultCode(code), "\(code) will not change within the open; retrying only delays the failure")
        }
    }

    // MARK: - Only the owning connection may delete

    func testReadOnlyAndTemporaryConnectionsNeverRemoveTheDatabase() {
        let owner = self.open(isTemporary: false, isReadOnly: false, removeDatabaseOnError: true)
        XCTAssertNotNil(owner)
        XCTAssertEqual(owner?.removeDatabaseOnError, true, "the owning read-write connection keeps the self-heal it asked for")
        self.close(owner)

        let readOnly = self.open(isTemporary: true, isReadOnly: true, removeDatabaseOnError: true)
        XCTAssertNotNil(readOnly)
        XCTAssertEqual(readOnly?.removeDatabaseOnError, false, "a read-only connection (widget, Siri) must never delete the live database, whatever the caller passed")
        self.close(readOnly)

        let temporary = self.open(isTemporary: true, isReadOnly: false, removeDatabaseOnError: true)
        XCTAssertNotNil(temporary)
        XCTAssertEqual(temporary?.removeDatabaseOnError, false, "a temporary connection does not own the file and must not delete it")
        self.close(temporary)
    }

    // MARK: - Deletion removes the whole file set

    func testRemoveDatabaseFilesRemovesMainWalAndShmTogether() {
        let owner = self.open(isTemporary: false, isReadOnly: false, removeDatabaseOnError: true)
        XCTAssertNotNil(owner)
        self.writeRow(owner!, key: 1, value: [1, 2, 3])
        self.close(owner)

        // SQLite may clean up -wal/-shm on the last close; the test is about the file set
        // the helper targets, so make sure all three exist.
        for suffix in ["", "-wal", "-shm"] {
            let path = self.databasePath + suffix
            if !FileManager.default.fileExists(atPath: path) {
                XCTAssertTrue(FileManager.default.createFile(atPath: path, contents: Data([0]), attributes: nil))
            }
        }

        SqliteValueBox.removeDatabaseFiles(databasePath: self.databasePath)

        XCTAssertFalse(FileManager.default.fileExists(atPath: self.databasePath))
        XCTAssertFalse(FileManager.default.fileExists(atPath: self.databasePath + "-wal"), "a leftover -wal would be replayed into, or shared with, the next database created at this path")
        XCTAssertFalse(FileManager.default.fileExists(atPath: self.databasePath + "-shm"), "a leftover -shm still mapped by another process would be shared with a different WAL file")
    }

    func testRemoveDatabaseFilesDerivesTheSetFromTheGivenPath() {
        XCTAssertTrue((try? FileManager.default.createDirectory(atPath: self.basePath, withIntermediateDirectories: true)) != nil)
        let other = self.basePath + "/other"
        for path in [other, other + "-wal", other + "-shm", self.databasePath] {
            XCTAssertTrue(FileManager.default.createFile(atPath: path, contents: Data([0]), attributes: nil))
        }

        XCTAssertTrue(FileManager.default.createFile(atPath: other + "-open-failures", contents: Data("2".utf8), attributes: nil))

        SqliteValueBox.removeDatabaseFiles(databasePath: other)

        XCTAssertFalse(FileManager.default.fileExists(atPath: other))
        XCTAssertFalse(FileManager.default.fileExists(atPath: other + "-wal"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: other + "-shm"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: other + "-open-failures"), "a recreated database starts with a clean failure count")
        XCTAssertTrue(FileManager.default.fileExists(atPath: self.databasePath), "the helper acts on the path it is handed, not on a fixed file name")
    }

    // MARK: - Open-failure valve

    /// A failed `sqlite3_open_v2` never says anything about the file's content, so the owner
    /// does not delete on the first failure. It does keep a counter, and wipes after the third
    /// consecutive failure that deleting could plausibly fix, so a file that has become
    /// unopenable does not lock the user out forever.
    func testOpenFailuresThatDeletionCannotFixAreNotCounted() {
        // EACCES sits with EPERM on purpose: iOS data protection is documented loosely enough
        // that either may come back for a protected file opened before first unlock, and a
        // locked device must never advance the valve. Nothing in the sandbox breaks a file's
        // permission bits, so excluding EACCES gives up no real recovery.
        let notFixableByDeleting: [Int32] = [EPERM, EACCES, EMFILE, ENFILE, ENOMEM, ENOSPC, EAGAIN, EINTR]
        for systemErrno in notFixableByDeleting {
            XCTAssertFalse(shouldCountOpenFailure(systemErrno: systemErrno), "errno \(systemErrno): data protection while locked, or a resource limit; deleting changes nothing")
        }
        let plausiblyFileSpecific: [Int32] = [EISDIR, EIO, 0]
        for systemErrno in plausiblyFileSpecific {
            XCTAssertTrue(shouldCountOpenFailure(systemErrno: systemErrno), "errno \(systemErrno) can be a problem with this file itself")
        }
    }

    func testOpenFailureValveWipesOnlyAfterRepeatedCountedFailures() {
        XCTAssertTrue((try? FileManager.default.createDirectory(atPath: self.basePath, withIntermediateDirectories: true)) != nil)

        for _ in 0 ..< SqliteValueBox.openFailureWipeThreshold + 1 {
            XCTAssertFalse(SqliteValueBox.shouldWipeAfterOpenFailure(databasePath: self.databasePath, systemErrno: EPERM), "a locked device must never advance the valve")
        }
        XCTAssertEqual(SqliteValueBox.consecutiveOpenFailures(databasePath: self.databasePath), 0)

        for attempt in 1 ..< SqliteValueBox.openFailureWipeThreshold {
            XCTAssertFalse(SqliteValueBox.shouldWipeAfterOpenFailure(databasePath: self.databasePath, systemErrno: EIO), "failure \(attempt) is not yet enough to give up on the file")
            XCTAssertEqual(SqliteValueBox.consecutiveOpenFailures(databasePath: self.databasePath), attempt)
        }
        XCTAssertTrue(SqliteValueBox.shouldWipeAfterOpenFailure(databasePath: self.databasePath, systemErrno: EIO), "failure \(SqliteValueBox.openFailureWipeThreshold) in a row trips the valve")
    }

    func testSuccessfulOwnerOpenResetsTheOpenFailureCounter() {
        XCTAssertTrue((try? FileManager.default.createDirectory(atPath: self.basePath, withIntermediateDirectories: true)) != nil)
        XCTAssertTrue(FileManager.default.createFile(atPath: self.databasePath + "-open-failures", contents: Data("2".utf8), attributes: nil))
        XCTAssertEqual(SqliteValueBox.consecutiveOpenFailures(databasePath: self.databasePath), 2)

        let owner = self.open(isTemporary: false, isReadOnly: false, removeDatabaseOnError: true)
        XCTAssertNotNil(owner)

        XCTAssertEqual(SqliteValueBox.consecutiveOpenFailures(databasePath: self.databasePath), 0, "one good open proves the file is fine; earlier failures no longer count")
    }

    func testFailedOpenReportsTheSystemErrno() {
        XCTAssertTrue((try? FileManager.default.createDirectory(atPath: self.databasePath, withIntermediateDirectories: true)) != nil)
        defer {
            let _ = try? FileManager.default.removeItem(atPath: self.databasePath + "-guard")
        }

        switch Database.open(self.databasePath, readOnly: false) {
        case .success:
            XCTFail("a directory is not an openable database")
        case let .failure(error):
            XCTAssertEqual(error.code, SQLITE_CANTOPEN)
            XCTAssertEqual(error.systemErrno, EISDIR, "the errno is what tells the valve whether deleting could help")
        }
    }

    // MARK: - Encrypted databases (SQLCipher upgrade regression guards)

    func testEncryptedDatabaseRoundTripsThroughCloseAndReopen() {
        let parameters = self.makeEncryptionParameters(seed: 7)

        let writer = self.open(isTemporary: false, isReadOnly: false, removeDatabaseOnError: true, encryptionParameters: parameters)
        XCTAssertNotNil(writer)
        self.writeRow(writer!, key: 42, value: [9, 8, 7, 6])
        self.close(writer)

        let reader = self.open(isTemporary: true, isReadOnly: false, removeDatabaseOnError: false, encryptionParameters: parameters)
        XCTAssertNotNil(reader, "the same key and salt must reopen the database")
        XCTAssertEqual(reader.flatMap { self.readRow($0, key: 42) }, [9, 8, 7, 6])
        self.close(reader)
    }

    func testWrongKeyOnANonOwningConnectionFailsWithoutDeletingFiles() {
        let writer = self.open(isTemporary: false, isReadOnly: false, removeDatabaseOnError: true, encryptionParameters: self.makeEncryptionParameters(seed: 7))
        XCTAssertNotNil(writer)
        self.writeRow(writer!, key: 1, value: [1])
        self.close(writer)

        let intruder = self.open(isTemporary: true, isReadOnly: false, removeDatabaseOnError: true, encryptionParameters: self.makeEncryptionParameters(seed: 99))
        XCTAssertNil(intruder, "a wrong key is a definitive verdict: the open fails")
        XCTAssertTrue(FileManager.default.fileExists(atPath: self.databasePath), "and a non-owning connection leaves the file alone")
    }

    /// The owner treats a wrong key as a verdict and recreates the database. This is also
    /// what proves the wrong key is not classified as transient: a transient result would
    /// make the owner crash here instead of recreating.
    func testWrongKeyOnTheOwningConnectionRecreatesTheDatabase() {
        let writer = self.open(isTemporary: false, isReadOnly: false, removeDatabaseOnError: true, encryptionParameters: self.makeEncryptionParameters(seed: 7))
        XCTAssertNotNil(writer)
        self.writeRow(writer!, key: 1, value: [1])
        self.close(writer)

        let rekeyedOwner = self.open(isTemporary: false, isReadOnly: false, removeDatabaseOnError: true, encryptionParameters: self.makeEncryptionParameters(seed: 99))
        XCTAssertNotNil(rekeyedOwner, "the owner self-heals by recreating the database under its key")
        XCTAssertNil(rekeyedOwner.flatMap { self.readRow($0, key: 1) }, "the recreated database is empty")
    }

    func testNonOwnerNeverReencryptsAPlaintextDatabaseInPlace() {
        let plaintextOwner = self.open(isTemporary: false, isReadOnly: false, removeDatabaseOnError: true, encryptionParameters: nil)
        XCTAssertNotNil(plaintextOwner)
        self.writeRow(plaintextOwner!, key: 5, value: [5, 5])
        self.close(plaintextOwner)

        // A temporary read-write connection asking for encryption must not rewrite the
        // owner's live file from another process.
        let migrator = self.open(isTemporary: true, isReadOnly: false, removeDatabaseOnError: true, encryptionParameters: self.makeEncryptionParameters(seed: 3))
        XCTAssertNil(migrator, "a non-owning connection cannot migrate the file it does not own")

        let plaintextReader = self.open(isTemporary: true, isReadOnly: false, removeDatabaseOnError: false, encryptionParameters: nil)
        XCTAssertNotNil(plaintextReader, "the file is still the owner's plaintext database")
        XCTAssertEqual(plaintextReader.flatMap { self.readRow($0, key: 5) }, [5, 5])
    }
}

/// Runs after `SqliteValueBoxRecoveryPolicyTests` (XCTest orders classes by name); kept
/// separate because it holds a lock for the whole 5 s busy timeout per attempt.
final class SqliteValueBoxUnavailableDatabaseTests: XCTestCase {
    private var queue: Queue!
    private var basePath: String!
    private var owner: SqliteValueBox?
    private var contender: SqliteValueBox?

    override func setUp() {
        super.setUp()
        self.queue = Queue(name: "SqliteValueBoxUnavailableDatabaseTests")
        self.basePath = NSTemporaryDirectory() + "SqliteValueBoxUnavailableDatabaseTests-" + UUID().uuidString
    }

    override func tearDown() {
        self.queue.sync {
            self.owner?.internalClose()
            self.owner = nil
            self.contender?.internalClose()
            self.contender = nil
        }
        let _ = try? FileManager.default.removeItem(atPath: self.basePath)
        super.tearDown()
    }

    func testBusyDatabaseIsNotRemovedByATemporaryConnection() {
        let databasePath = self.basePath + "/db_sqlite"

        self.queue.sync {
            self.owner = SqliteValueBox(basePath: self.basePath, queue: self.queue, isTemporary: false, isReadOnly: false, useCaches: false, removeDatabaseOnError: true, encryptionParameters: nil, upgradeProgress: { _ in })
            self.owner?.internalClose()
        }
        XCTAssertNotNil(self.owner)
        XCTAssertTrue(FileManager.default.fileExists(atPath: databasePath))

        // Another "process": an exclusive-mode connection holding a write transaction makes
        // every other connection's first read fail with SQLITE_BUSY after the busy timeout.
        guard let holder = Database(databasePath, readOnly: false) else {
            XCTFail("could not open the lock-holding connection")
            return
        }
        XCTAssertTrue(holder.execute("PRAGMA locking_mode=EXCLUSIVE"))
        XCTAssertTrue(holder.execute("BEGIN IMMEDIATE"))
        XCTAssertTrue(holder.execute("CREATE TABLE lock_holder (x INTEGER)"))

        self.queue.sync {
            self.contender = SqliteValueBox(basePath: self.basePath, queue: self.queue, isTemporary: true, isReadOnly: false, useCaches: false, removeDatabaseOnError: true, encryptionParameters: nil, upgradeProgress: { _ in })
        }
        XCTAssertNil(self.contender, "a busy database is unavailable, not unreadable: the open fails instead of guessing at the key")
        XCTAssertTrue(FileManager.default.fileExists(atPath: databasePath), "and the file the other process is using is left in place")

        XCTAssertTrue(holder.execute("ROLLBACK"))
    }
}
