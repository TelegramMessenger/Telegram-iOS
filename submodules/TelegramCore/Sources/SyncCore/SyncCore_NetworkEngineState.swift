import Postbox

/// Whether the Rust engine may run, shared by every account of the app and kept across launches
/// (accountManager shared data), for the networks that have no app configuration of their own: a login
/// (`UnauthorizedAccount`) and an account that has not fetched one yet. It holds:
/// - `mtproto_engine_rust_disabled` as each production account last got it from the server (`false`
///   too, so turning the server switch off enables Rust again at the next start); any `true` counts;
/// - a local fallback after the engine crashed repeatedly (`recordRustEngineCrash`), for every network.
/// Each part counts only for the app build that wrote it, so a fixed build never inherits it.
public struct NetworkEngineState: Codable, Equatable {
    public struct ServerFlag: Codable, Equatable {
        public var accountId: Int64
        public var rustDisabled: Bool
        public var build: String
        public var updatedAt: Int32

        public init(accountId: Int64, rustDisabled: Bool, build: String, updatedAt: Int32) {
            self.accountId = accountId
            self.rustDisabled = rustDisabled
            self.build = build
            self.updatedAt = updatedAt
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: StringCodingKey.self)

            self.accountId = try container.decode(Int64.self, forKey: "accountId")
            self.rustDisabled = try container.decode(Bool.self, forKey: "rustDisabled")
            self.build = try container.decode(String.self, forKey: "build")
            self.updatedAt = try container.decode(Int32.self, forKey: "updatedAt")
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: StringCodingKey.self)

            try container.encode(self.accountId, forKey: "accountId")
            try container.encode(self.rustDisabled, forKey: "rustDisabled")
            try container.encode(self.build, forKey: "build")
            try container.encode(self.updatedAt, forKey: "updatedAt")
        }
    }

    public static let crashLoopCrashCount = 2
    public static let crashLoopWindow: Int32 = 24 * 60 * 60
    public static let crashLoopFallbackDuration: Int32 = 24 * 60 * 60
    public static let crashLoopClockTolerance: Int32 = 60 * 60

    public var serverFlags: [ServerFlag]
    public var engineCrashes: [Int32]
    public var engineCrashBuild: String?
    public var rustLocallyDisabledUntil: Int32?

    public init(serverFlags: [ServerFlag] = [], engineCrashes: [Int32] = [], engineCrashBuild: String? = nil, rustLocallyDisabledUntil: Int32? = nil) {
        self.serverFlags = serverFlags
        self.engineCrashes = engineCrashes
        self.engineCrashBuild = engineCrashBuild
        self.rustLocallyDisabledUntil = rustLocallyDisabledUntil
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.serverFlags = try container.decodeIfPresent([ServerFlag].self, forKey: "serverFlags") ?? []
        self.engineCrashes = try container.decodeIfPresent([Int32].self, forKey: "engineCrashes") ?? []
        self.engineCrashBuild = try container.decodeIfPresent(String.self, forKey: "engineCrashBuild")
        self.rustLocallyDisabledUntil = try container.decodeIfPresent(Int32.self, forKey: "rustLocallyDisabledUntil")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.serverFlags, forKey: "serverFlags")
        try container.encode(self.engineCrashes, forKey: "engineCrashes")
        try container.encodeIfPresent(self.engineCrashBuild, forKey: "engineCrashBuild")
        try container.encodeIfPresent(self.rustLocallyDisabledUntil, forKey: "rustLocallyDisabledUntil")
    }

    public func serverDisabledRust(build: String) -> Bool {
        return self.serverFlags.contains(where: { $0.build == build && $0.rustDisabled })
    }

    /// A clock set back does not stretch the fallback: once `until` is further ahead than the fallback
    /// could be (plus `crashLoopClockTolerance` for clock corrections), the fallback is over.
    public func locallyDisabledRust(build: String, timestamp: Int32) -> Bool {
        guard let until = self.rustLocallyDisabledUntil else {
            return false
        }
        return until > timestamp && Int64(until) - Int64(timestamp) <= Int64(NetworkEngineState.crashLoopFallbackDuration + NetworkEngineState.crashLoopClockTolerance) && self.engineCrashBuild == build
    }

    /// The server flags that still count with these accounts live: a removed or logged-out account's
    /// flag is dropped once a live account has a flag of the same build. While none has, the flags stay,
    /// so a login after the last account logged out still honours the last `true`.
    public func keepingServerFlags(of accountIds: Set<Int64>) -> NetworkEngineState {
        let liveBuilds = Set(self.serverFlags.filter { accountIds.contains($0.accountId) }.map { $0.build })
        var updated = self
        updated.serverFlags = self.serverFlags.filter { accountIds.contains($0.accountId) || !liveBuilds.contains($0.build) }
        return updated
    }

    /// Records what the server told one live account. After it, this build has a live flag, so the flags
    /// of accounts that are gone are dropped, as are other builds' flags; an unchanged value keeps its
    /// time. An account that is gone (a fetch that ended after its logout) records nothing and drops
    /// nothing.
    public func withServerFlag(accountId: Int64, rustDisabled: Bool, build: String, timestamp: Int32, accountIds: Set<Int64>) -> NetworkEngineState {
        if !accountIds.contains(accountId) {
            return self
        }
        var flags = self.serverFlags.filter { $0.accountId != accountId && $0.build == build && accountIds.contains($0.accountId) }
        if let current = self.serverFlags.first(where: { $0.accountId == accountId && $0.build == build && $0.rustDisabled == rustDisabled }) {
            flags.append(current)
        } else {
            flags.append(ServerFlag(accountId: accountId, rustDisabled: rustDisabled, build: build, updatedAt: timestamp))
        }
        var updated = self
        updated.serverFlags = flags.sorted(by: { $0.accountId < $1.accountId })
        return updated
    }

    /// Two engine crashes of the same build within `crashLoopWindow` turn the engine off on this device
    /// for `crashLoopFallbackDuration`; the crashes before a fallback do not count towards the next one.
    public func withEngineCrash(build: String, timestamp: Int32) -> NetworkEngineState {
        var updated = self
        if updated.engineCrashBuild != build {
            updated.engineCrashBuild = build
            updated.engineCrashes = []
            updated.rustLocallyDisabledUntil = nil
        }
        updated.engineCrashes = updated.engineCrashes.filter { $0 > timestamp - NetworkEngineState.crashLoopWindow && $0 <= timestamp } + [timestamp]
        if updated.engineCrashes.count >= NetworkEngineState.crashLoopCrashCount {
            updated.rustLocallyDisabledUntil = timestamp + NetworkEngineState.crashLoopFallbackDuration
            updated.engineCrashes = []
        }
        return updated
    }
}
