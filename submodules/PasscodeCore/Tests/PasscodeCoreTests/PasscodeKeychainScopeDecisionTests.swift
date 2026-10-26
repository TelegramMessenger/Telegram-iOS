#if os(macOS)
import XCTest
import Security
@testable import PasscodeCore

final class PasscodeKeychainScopeDecisionTests: XCTestCase {
    private final class FakeKeychain {
        var unlocked = true
        var items: [String: PasscodeKeychainScope.Read] = [:]
        var listStatus: OSStatus = errSecSuccess
        var addStatuses: [String: OSStatus] = [:]
        var reads: [String] = []
        var added: [String] = []

        static func key(_ service: String, _ account: String) -> String {
            return service + "|" + account
        }

        func set(_ read: PasscodeKeychainScope.Read, _ service: String, _ account: String) {
            self.items[Self.key(service, account)] = read
        }

        var keychain: PasscodeKeychainScope.Keychain {
            return PasscodeKeychainScope.Keychain(isUnlocked: {
                return self.unlocked
            }, read: { service, account in
                self.reads.append(Self.key(service, account))
                return self.items[Self.key(service, account)] ?? .absent
            }, listGenericPasswords: {
                return (self.listStatus, self.items.keys.sorted().map { key in
                    let parts = key.components(separatedBy: "|")
                    return (parts[0], parts[1])
                })
            }, add: { data, service, account in
                let key = Self.key(service, account)
                if let status = self.addStatuses[key] {
                    return status
                }
                if self.items[key] != nil {
                    return errSecDuplicateItem
                }
                self.items[key] = .found(data)
                self.added.append(key)
                return errSecSuccess
            })
        }
    }

    private let passcode = "passcode"
    private let prefixes = ["wallet.descriptor.", "wallet.envelope.", "wallet.journal."]
    private var environment: PasscodeEnvironment!
    private var fake: FakeKeychain!

    override func setUpWithError() throws {
        try super.setUpWithError()
        self.environment = PasscodeEnvironment()
        try self.environment.configure(PasscodeConfiguration(appGroupIdentifier: "6N38VWS5BX.org.telegram.tests", processRole: .mainApp, keychainScope: "debug"), privateAccessGroup: { "6N38VWS5BX.org.telegram.tests" })
        self.fake = FakeKeychain()
    }

    private func scoped(_ service: String) -> String {
        return "org.telegram.scoped.debug/" + service
    }

    private func key(_ service: String, _ account: String) -> String {
        return FakeKeychain.key(service, account)
    }

    private func migrate() -> PasscodeKeychainScope.Migration {
        return PasscodeKeychainScope.migrateLegacyItems(passcodeService: self.passcode, walletServicePrefixes: self.prefixes, environment: self.environment, keychain: self.fake.keychain)
    }

    private func addCredentialSet() {
        self.fake.set(.found(Data("credential".utf8)), self.passcode, "credential")
        self.fake.set(.found(Data("device".utf8)), self.passcode, "device")
    }

    func testWithoutAScopeNothingIsRead() throws {
        let environment = PasscodeEnvironment()
        try environment.configure(PasscodeConfiguration(appGroupIdentifier: "6N38VWS5BX.org.telegram.tests", processRole: .mainApp), privateAccessGroup: { "6N38VWS5BX.org.telegram.tests" })
        self.addCredentialSet()
        XCTAssertEqual(PasscodeKeychainScope.migrateLegacyItems(passcodeService: self.passcode, walletServicePrefixes: self.prefixes, environment: environment, keychain: self.fake.keychain), .nothingToMigrate)
        XCTAssertEqual(self.fake.reads, [])
        XCTAssertEqual(self.fake.added, [])
    }

    func testALockedKeychainStopsBeforeReading() {
        self.addCredentialSet()
        self.fake.unlocked = false
        XCTAssertEqual(self.migrate(), .keychainLocked)
        XCTAssertEqual(self.fake.reads, [])
        XCTAssertEqual(self.fake.added, [])
    }

    func testTheUnscopedCredentialSetDecidesWhetherToCopy() {
        let found = PasscodeKeychainScope.Read.found(Data("value".utf8))
        let cases: [(PasscodeKeychainScope.Read, PasscodeKeychainScope.Read, PasscodeKeychainScope.Migration)] = [
            (.locked, found, .keychainLocked),
            (found, .locked, .keychainLocked),
            (.locked, .failed(-1), .keychainLocked),
            (.failed(-1), found, .failed(-1)),
            (found, .failed(-2), .failed(-2)),
            (.notReadable, found, .nothingToMigrate),
            (found, .notReadable, .nothingToMigrate),
            (found, .absent, .nothingToMigrate),
            (.absent, found, .nothingToMigrate),
            (.absent, .absent, .nothingToMigrate)
        ]
        for (credential, device, expected) in cases {
            self.fake = FakeKeychain()
            self.fake.set(credential, self.passcode, "credential")
            self.fake.set(device, self.passcode, "device")
            self.fake.set(.found(Data("descriptor".utf8)), "wallet.descriptor.ns", "wallet")
            XCTAssertEqual(self.migrate(), expected, "\(credential), \(device)")
            XCTAssertEqual(self.fake.added, [], "\(credential), \(device)")
        }
    }

    func testTheScopedCredentialSetDecidesWhetherToCopy() {
        let cases: [(PasscodeKeychainScope.Read, PasscodeKeychainScope.Migration)] = [
            (.notReadable, .nothingToMigrate),
            (.locked, .keychainLocked),
            (.failed(-3), .failed(-3)),
            (.found(Data("other".utf8)), .nothingToMigrate)
        ]
        for account in ["credential", "device"] {
            for (scoped, expected) in cases {
                self.fake = FakeKeychain()
                self.addCredentialSet()
                self.fake.set(.found(Data("descriptor".utf8)), "wallet.descriptor.ns", "wallet")
                self.fake.set(scoped, self.scoped(self.passcode), account)
                XCTAssertEqual(self.migrate(), expected, "\(account): \(scoped)")
                XCTAssertEqual(self.fake.added, [], "\(account): \(scoped)")
            }
        }
    }

    func testAMatchingScopedCredentialSetResumesTheCopy() {
        self.addCredentialSet()
        self.fake.set(.found(Data("credential".utf8)), self.scoped(self.passcode), "credential")
        self.fake.set(.found(Data("descriptor".utf8)), "wallet.descriptor.ns", "wallet")
        XCTAssertEqual(self.migrate(), .migrated(2))
        XCTAssertEqual(self.fake.added, [self.key(self.scoped("wallet.descriptor.ns"), "wallet"), self.key(self.scoped(self.passcode), "device")])
    }

    func testAWalletIsCopiedWholeOrNotAtAll() {
        self.addCredentialSet()
        self.fake.set(.found(Data("a".utf8)), "wallet.descriptor.a", "wallet")
        self.fake.set(.notReadable, "wallet.envelope.a", "secret")
        self.fake.set(.found(Data("a".utf8)), "wallet.journal.a", "journal")
        self.fake.set(.found(Data("b".utf8)), "wallet.descriptor.b", "wallet")
        self.fake.set(.found(Data("b".utf8)), "wallet.envelope.b", "secret")
        XCTAssertEqual(self.migrate(), .migrated(4))
        XCTAssertEqual(self.fake.added, [
            self.key(self.scoped("wallet.descriptor.b"), "wallet"),
            self.key(self.scoped("wallet.envelope.b"), "secret"),
            self.key(self.scoped(self.passcode), "device"),
            self.key(self.scoped(self.passcode), "credential")
        ])
        XCTAssertFalse(self.fake.reads.contains(self.key("wallet.journal.a", "journal")))
    }

    func testALockOrFailureWhileReadingWalletsCopiesNothing() {
        let cases: [(PasscodeKeychainScope.Read, PasscodeKeychainScope.Migration)] = [
            (.locked, .keychainLocked),
            (.failed(-4), .failed(-4))
        ]
        for (read, expected) in cases {
            self.fake = FakeKeychain()
            self.addCredentialSet()
            self.fake.set(.found(Data("a".utf8)), "wallet.descriptor.a", "wallet")
            self.fake.set(read, "wallet.descriptor.b", "wallet")
            XCTAssertEqual(self.migrate(), expected, "\(read)")
            XCTAssertEqual(self.fake.added, [], "\(read)")
        }
    }

    func testAListingFailureCopiesNothing() {
        self.addCredentialSet()
        self.fake.listStatus = errSecIO
        XCTAssertEqual(self.migrate(), .failed(errSecIO))
        XCTAssertEqual(self.fake.added, [])
    }

    func testAFailedCopyLeavesTheCredentialForTheNextRun() {
        for failing in [self.key(self.scoped("wallet.descriptor.a"), "wallet"), self.key(self.scoped(self.passcode), "device")] {
            self.fake = FakeKeychain()
            self.addCredentialSet()
            self.fake.set(.found(Data("a".utf8)), "wallet.descriptor.a", "wallet")
            self.fake.addStatuses[failing] = errSecIO
            XCTAssertEqual(self.migrate(), .failed(errSecIO), failing)
            XCTAssertNil(self.fake.items[self.key(self.scoped(self.passcode), "credential")], failing)
        }
    }

    func testOnlyUnscopedItemsUnderTheWalletPrefixesAreCopied() {
        self.addCredentialSet()
        self.fake.set(.found(Data("a".utf8)), "wallet.descriptor.a", "wallet")
        self.fake.set(.found(Data("stale".utf8)), "wallet.metadata.a", "wallet")
        self.fake.set(.found(Data("other".utf8)), "other.service", "wallet")
        self.fake.set(.found(Data("scoped".utf8)), self.scoped("wallet.descriptor.b"), "wallet")
        XCTAssertEqual(self.migrate(), .migrated(3))
        XCTAssertEqual(self.fake.added, [
            self.key(self.scoped("wallet.descriptor.a"), "wallet"),
            self.key(self.scoped(self.passcode), "device"),
            self.key(self.scoped(self.passcode), "credential")
        ])
    }

    func testAWalletTheScopeAlreadyHoldsIsNotMixedIn() {
        let cases: [(String, PasscodeKeychainScope.Read)] = [
            ("wallet.descriptor.a", .found(Data("watch-only".utf8))),
            ("wallet.descriptor.a", .notReadable),
            ("wallet.journal.a", .found(Data("own".utf8)))
        ]
        for (service, scoped) in cases {
            self.fake = FakeKeychain()
            self.addCredentialSet()
            self.fake.set(.found(Data("a".utf8)), "wallet.descriptor.a", "wallet")
            self.fake.set(.found(Data("a".utf8)), "wallet.envelope.a", "secret")
            self.fake.set(.found(Data("b".utf8)), "wallet.descriptor.b", "wallet")
            self.fake.set(scoped, self.scoped(service), "wallet")
            XCTAssertEqual(self.migrate(), .migrated(3), "\(service): \(scoped)")
            XCTAssertEqual(self.fake.added, [
                self.key(self.scoped("wallet.descriptor.b"), "wallet"),
                self.key(self.scoped(self.passcode), "device"),
                self.key(self.scoped(self.passcode), "credential")
            ], "\(service): \(scoped)")
        }
    }

    func testALockOrFailureWhileReadingTheScopeCopiesNothing() {
        let cases: [(PasscodeKeychainScope.Read, PasscodeKeychainScope.Migration)] = [
            (.locked, .keychainLocked),
            (.failed(-5), .failed(-5))
        ]
        for (read, expected) in cases {
            self.fake = FakeKeychain()
            self.addCredentialSet()
            self.fake.set(.found(Data("a".utf8)), "wallet.descriptor.a", "wallet")
            self.fake.set(.found(Data("b".utf8)), "wallet.descriptor.b", "wallet")
            self.fake.set(read, self.scoped("wallet.descriptor.b"), "wallet")
            XCTAssertEqual(self.migrate(), expected, "\(read)")
            XCTAssertEqual(self.fake.added, [], "\(read)")
        }
    }

    func testIdenticalScopedCopiesResumeTheWallet() {
        self.addCredentialSet()
        self.fake.set(.found(Data("a".utf8)), "wallet.descriptor.a", "wallet")
        self.fake.set(.found(Data("s".utf8)), "wallet.envelope.a", "secret")
        self.fake.set(.found(Data("s".utf8)), self.scoped("wallet.envelope.a"), "secret")
        XCTAssertEqual(self.migrate(), .migrated(3))
        XCTAssertEqual(self.fake.added, [
            self.key(self.scoped("wallet.descriptor.a"), "wallet"),
            self.key(self.scoped(self.passcode), "device"),
            self.key(self.scoped(self.passcode), "credential")
        ])
    }

    func testWalletItemsAreCopiedInPrefixOrder() {
        self.addCredentialSet()
        self.fake.set(.found(Data("d".utf8)), "wallet.descriptor.a", "wallet")
        self.fake.set(.found(Data("e".utf8)), "wallet.envelope.a", "secret")
        self.fake.set(.found(Data("j".utf8)), "wallet.journal.a", "journal")
        let migration = PasscodeKeychainScope.migrateLegacyItems(passcodeService: self.passcode, walletServicePrefixes: ["wallet.envelope.", "wallet.journal.", "wallet.descriptor."], environment: self.environment, keychain: self.fake.keychain)
        XCTAssertEqual(migration, .migrated(5))
        XCTAssertEqual(self.fake.added, [
            self.key(self.scoped("wallet.envelope.a"), "secret"),
            self.key(self.scoped("wallet.journal.a"), "journal"),
            self.key(self.scoped("wallet.descriptor.a"), "wallet"),
            self.key(self.scoped(self.passcode), "device"),
            self.key(self.scoped(self.passcode), "credential")
        ])
    }

    func testItemGroupsIgnoreScopedNames() {
        let groups = PasscodeKeychainScope.itemGroups([
            (service: "org.telegram.scoped.debug/org.telegram.x.a", account: "scoped"),
            (service: "org.telegram.x.a", account: "wallet"),
            (service: "org.telegram.y", account: "other")
        ], servicePrefixes: ["org.telegram.x.", "org.telegram."])
        XCTAssertEqual(groups.map { group in group.name + ": " + group.items.map { $0.service + "|" + $0.account }.joined(separator: ",") }, [
            "a: org.telegram.x.a|wallet",
            "y: org.telegram.y|other"
        ])
    }

    func testReadStatusesAreClassified() {
        let data = Data("value".utf8) as CFData
        XCTAssertEqual(PasscodeKeychainScope.classify(errSecSuccess, result: data, isUnlocked: { true }), .found(Data("value".utf8)))
        XCTAssertEqual(PasscodeKeychainScope.classify(errSecSuccess, result: nil, isUnlocked: { true }), .failed(errSecDecode))
        XCTAssertEqual(PasscodeKeychainScope.classify(errSecSuccess, result: "value" as CFString, isUnlocked: { true }), .failed(errSecDecode))
        XCTAssertEqual(PasscodeKeychainScope.classify(errSecItemNotFound, result: nil, isUnlocked: { true }), .absent)
        for status in [errSecAuthFailed, errSecInteractionNotAllowed] {
            XCTAssertEqual(PasscodeKeychainScope.classify(status, result: nil, isUnlocked: { true }), .notReadable, "\(status)")
            XCTAssertEqual(PasscodeKeychainScope.classify(status, result: nil, isUnlocked: { false }), .locked, "\(status)")
        }
        XCTAssertEqual(PasscodeKeychainScope.classify(errSecIO, result: nil, isUnlocked: { true }), .failed(errSecIO))
    }
}
#endif
