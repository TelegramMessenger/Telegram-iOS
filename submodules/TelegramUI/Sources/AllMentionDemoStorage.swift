import Foundation

/// Only locates the isolated demo database. Messages and settings stay in Postbox.
enum AllMentionDemoStorage {
    private struct Session: Codable {
        let version: Int32
        let directory: String
    }

    enum StorageError: Error {
        case invalidSession
        case missingStore
    }

    static func root(in appGroupPath: String, reset: Bool = false, showcase: Bool = false) throws -> String {
        let manager = FileManager.default
        let group = URL(fileURLWithPath: appGroupPath, isDirectory: true).standardizedFileURL.resolvingSymlinksInPath()
        let container = group.appendingPathComponent("all-mention-demo", isDirectory: true)
        guard container.resolvingSymlinksInPath() == container else { throw StorageError.invalidSession }
        try manager.createDirectory(at: container, withIntermediateDirectories: true)
        // The presentation has its own persistent session. Never replace the
        // accumulated QA store just to prepare a clean feature walkthrough.
        let manifest = container.appendingPathComponent(showcase ? "showcase-session.json" : "session.json")

        if !reset && manager.fileExists(atPath: manifest.path) {
            guard manifest.resolvingSymlinksInPath().deletingLastPathComponent() == container,
                  let data = try? Data(contentsOf: manifest),
                  let session = try? JSONDecoder().decode(Session.self, from: data),
                  session.version == 1, isSessionName(session.directory) else { throw StorageError.invalidSession }
            let root = container.appendingPathComponent(session.directory, isDirectory: true)
            var isDirectory: ObjCBool = false
            guard root.resolvingSymlinksInPath().deletingLastPathComponent() == container else { throw StorageError.invalidSession }
            guard manager.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else { throw StorageError.missingStore }
            return root.path
        }

        // Adopt the latest complete old launch in place, preserving its encryption
        // key and media paths. Never search the normal account-manager directory.
        let legacy: URL?
        if reset || showcase { legacy = nil } else { legacy = try latestLegacyStore(in: container) }
        // Directory enumeration can return a different /var alias on Simulator.
        // Build both adopted and reopened paths from the same canonical parent.
        let directory = legacy?.lastPathComponent ?? "store-" + UUID().uuidString
        let root = container.appendingPathComponent(directory, isDirectory: true)
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        if legacy == nil {
            // The protected account manager refuses missing metadata even on a
            // new demo. Initialize only the directory we have just created;
            // existing sessions must never be silently repaired or recreated.
            let metadata = root.appendingPathComponent("accounts-metadata", isDirectory: true)
            try manager.createDirectory(at: metadata, withIntermediateDirectories: true)
            let atomicState = metadata.appendingPathComponent("atomic-state")
            try Data("{\"records\":[]}".utf8).write(to: atomicState, options: .atomic)
            try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: atomicState.path)
        }
        if reset && manager.fileExists(atPath: manifest.path) {
            try manager.copyItem(at: manifest, to: container.appendingPathComponent("session-backup-" + UUID().uuidString + ".json"))
        }
        let session = Session(version: 1, directory: root.lastPathComponent)
        try JSONEncoder().encode(session).write(to: manifest, options: .atomic)
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: manifest.path)
        return root.path
    }

    static func contains(rootPath: String, in appGroupPath: String) -> Bool {
        let group = URL(fileURLWithPath: appGroupPath, isDirectory: true).standardizedFileURL.resolvingSymlinksInPath()
        let root = URL(fileURLWithPath: rootPath, isDirectory: true).standardizedFileURL.resolvingSymlinksInPath()
        return isSessionName(root.lastPathComponent) && root.deletingLastPathComponent() == group.appendingPathComponent("all-mention-demo", isDirectory: true)
    }

    private static func isSessionName(_ name: String) -> Bool {
        for prefix in ["launch-", "store-"] where name.hasPrefix(prefix) {
            if UUID(uuidString: String(name.dropFirst(prefix.count))) != nil { return true }
        }
        return false
    }

    private static func latestLegacyStore(in container: URL) throws -> URL? {
        let manager = FileManager.default
        let entries = try manager.contentsOfDirectory(at: container, includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey, .isSymbolicLinkKey])
        return try entries.filter { url in
            guard url.lastPathComponent.hasPrefix("launch-"), isSessionName(url.lastPathComponent) else { return false }
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            return values.isDirectory == true && values.isSymbolicLink != true
                && manager.fileExists(atPath: url.appendingPathComponent(".tempkey").path)
                && manager.fileExists(atPath: url.appendingPathComponent("accounts-metadata/atomic-state").path)
        }.sorted { lhs, rhs in
            let left = try lhs.resourceValues(forKeys: [.creationDateKey]).creationDate ?? .distantPast
            let right = try rhs.resourceValues(forKeys: [.creationDateKey]).creationDate ?? .distantPast
            return left == right ? lhs.lastPathComponent > rhs.lastPathComponent : left > right
        }.first
    }
}

enum AllMentionDemoLaunchMode: String {
    case sender
    case recipient

    static func selected(arguments: [String], previous: String?) -> Self {
        if arguments.contains("--all-mention-demo-recipient") { return .recipient }
        if arguments.contains("--all-mention-demo-sender") { return .sender }
        return previous.flatMap(Self.init(rawValue:)) ?? .sender
    }
}

struct AllMentionDemoStoreState: Codable, Equatable {
    var version: Int32 = 1
    var recipientIntroDelivered: Bool = false

    func recordingRecipientIntro() -> Self {
        var result = self
        result.recipientIntroDelivered = true
        return result
    }
}
