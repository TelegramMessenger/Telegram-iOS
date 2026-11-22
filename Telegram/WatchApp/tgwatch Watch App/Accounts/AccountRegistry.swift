import Foundation
import OSLog

/// On-disk shape of `accounts.json`. The single source of truth for which
/// accounts exist and which is active. TDLib state lives inside each
/// account's own subdirectory and is never duplicated here.
struct AccountRegistryState: Codable, Equatable {
    var version: Int
    var activeAccountId: UUID?
    var accounts: [Account]

    static let empty = AccountRegistryState(version: 1, activeAccountId: nil, accounts: [])
}

/// Pure persistence layer for the account registry. I/O is closure-injected
/// so unit tests stay off-disk; the production wiring writes to
/// `applicationSupport/tdlib/accounts.json` atomically.
struct AccountRegistry {
    let readData: () throws -> Data
    let writeData: (Data, Data.WritingOptions) throws -> Void

    private static let logger = Logger(subsystem: "com.isaac.tgwatch", category: "accounts")

    /// Returns the empty state if the file is absent or corrupt. The smaller
    /// recovery surface keeps a single bad write from bricking the app.
    func load() throws -> AccountRegistryState {
        let data: Data
        do {
            data = try readData()
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            // File absent on first run — not an error condition.
            return .empty
        }
        // Any other read error (permission denied, I/O failure) propagates to the
        // caller — AccountManager.bootstrap() decides how to surface it.
        do {
            return try JSONDecoder().decode(AccountRegistryState.self, from: data)
        } catch {
            Self.logger.warning("accounts.json decode failed: \(error.localizedDescription, privacy: .public) — treating as empty")
            return .empty
        }
    }

    func save(_ state: AccountRegistryState) throws {
        let data = try JSONEncoder().encode(state)
        try writeData(data, [.atomic])
    }

    /// Production wiring: reads/writes `<applicationSupport>/tdlib/accounts.json`.
    static func defaultProduction() -> AccountRegistry {
        let baseDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("tdlib", isDirectory: true)
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        let fileURL = baseDir.appendingPathComponent("accounts.json")
        return AccountRegistry(
            readData: { try Data(contentsOf: fileURL) },
            writeData: { data, options in try data.write(to: fileURL, options: options) }
        )
    }
}
