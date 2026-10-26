#if os(macOS)
import XCTest
import Security
@testable import PasscodeCore

final class PasscodeKeychainScopeTests: XCTestCase {
    private var scope = ""
    private var account = ""
    private var passcodeService = ""
    private var walletPrefix = ""
    private var biometricService = ""
    private var environment: PasscodeEnvironment!
    private var created: [(String, String)] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        let id = UUID().uuidString
        self.scope = "tests-\(id)"
        self.account = "tests-\(id)"
        self.passcodeService = "org.telegram.tests.\(id).passcode"
        self.walletPrefix = "org.telegram.tests.\(id).wallet."
        self.biometricService = "org.telegram.tests.\(id).biometric"
        try XCTSkipUnless(PasscodeKeychainScope.isDefaultKeychainUnlocked(), "The default keychain is locked")
        self.environment = try self.makeEnvironment(scope: self.scope)
    }

    override func tearDown() {
        guard self.environment != nil else {
            super.tearDown()
            return
        }
        var deletions = [self.query(service: PasscodeKeychainScope.legacyPasscodeService, account: self.account)]
        for service in [self.scoped(PasscodeKeychainScope.legacyPasscodeService), self.passcodeService, self.scoped(self.passcodeService)] {
            for account in [self.account, "credential", "device", "attempts"] {
                deletions.append(self.query(service: service, account: account))
            }
        }
        for (service, account) in self.created {
            deletions.append(self.query(service: service, account: account))
            deletions.append(self.query(service: self.scoped(service), account: account))
        }
        for deletion in deletions {
            let status = SecItemDelete(deletion as CFDictionary)
            XCTAssertTrue(status == errSecSuccess || status == errSecItemNotFound, "\(deletion[kSecAttrService as String] ?? "") deletion: \(status)")
        }
        super.tearDown()
    }

    private func makeEnvironment(scope: String?) throws -> PasscodeEnvironment {
        let environment = PasscodeEnvironment()
        try environment.configure(PasscodeConfiguration(appGroupIdentifier: "6N38VWS5BX.org.telegram.tests", processRole: .mainApp, biometricKeychainService: self.biometricService, keychainScope: scope), privateAccessGroup: { "6N38VWS5BX.org.telegram.tests" })
        return environment
    }

    private func query(service: String, account: String) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false,
            kSecUseDataProtectionKeychain as String: false
        ]
    }

    private func add(_ value: String, service: String, account: String) {
        var insert = self.query(service: service, account: account)
        insert[kSecValueData as String] = Data(value.utf8)
        XCTAssertEqual(SecItemAdd(insert as CFDictionary, nil), errSecSuccess)
        self.created.append((service, account))
    }

    private func addNeedingConfirmation(_ value: String, service: String, account: String) throws {
        var access: SecAccess?
        XCTAssertEqual(SecAccessCreate("tests" as CFString, [] as CFArray, &access), errSecSuccess)
        var insert = self.query(service: service, account: account)
        insert[kSecValueData as String] = Data(value.utf8)
        insert[kSecAttrAccess as String] = try XCTUnwrap(access)
        XCTAssertEqual(SecItemAdd(insert as CFDictionary, nil), errSecSuccess)
        self.created.append((service, account))
    }

    private func exists(service: String, account: String) -> Bool {
        var search = self.query(service: service, account: account)
        search[kSecReturnAttributes as String] = true
        search[kSecMatchLimit as String] = kSecMatchLimitOne
        return SecItemCopyMatching(search as CFDictionary, nil) == errSecSuccess
    }

    private func value(service: String, account: String) -> String? {
        var search = self.query(service: service, account: account)
        search[kSecReturnData as String] = true
        search[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(search as CFDictionary, &result) == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func scoped(_ service: String) -> String {
        return "org.telegram.scoped.\(self.scope)/" + service
    }

    private func migrate(environment: PasscodeEnvironment? = nil) -> PasscodeKeychainScope.Migration {
        return PasscodeKeychainScope.migrateLegacyItems(passcodeService: self.passcodeService, walletServicePrefixes: [self.walletPrefix + "descriptor.", self.walletPrefix + "vault."], environment: environment ?? self.environment)
    }

    func testServicesCarryTheScope() throws {
        XCTAssertEqual(PasscodeKeychainScope.service("svc", environment: self.environment), "org.telegram.scoped.\(self.scope)/svc")
        XCTAssertEqual(PasscodeKeychainScope.service("svc", environment: try self.makeEnvironment(scope: nil)), "svc")
        XCTAssertEqual(PasscodeKeychainScope.service("svc", environment: try self.makeEnvironment(scope: "")), "svc")
        XCTAssertFalse(PasscodeKeychainScope.service("org.telegram.ton-wallet.vault", environment: self.environment).hasPrefix("org.telegram.ton-wallet."))
    }

    func testScopedNamesNeverMatchAnotherScopesFilter() throws {
        let debug = try self.makeEnvironment(scope: "debug")
        let release = try self.makeEnvironment(scope: nil)
        let debugItem = PasscodeKeychainScope.service("org.telegram.ton-wallet.vault.v1.envelope.ns", environment: debug)
        let releaseItem = PasscodeKeychainScope.service("org.telegram.ton-wallet.vault.v1.envelope.ns", environment: release)
        let otherScopeItem = "org.telegram.scoped.other/org.telegram.ton-wallet.vault.v1.envelope.ns"
        let debugFilter = PasscodeKeychainScope.service("org.telegram.ton-wallet.", environment: debug)
        let releaseFilter = PasscodeKeychainScope.service("org.telegram.ton-wallet.", environment: release)
        XCTAssertTrue(debugItem.hasPrefix(debugFilter))
        XCTAssertFalse(releaseItem.hasPrefix(debugFilter))
        XCTAssertFalse(otherScopeItem.hasPrefix(debugFilter))
        XCTAssertTrue(releaseItem.hasPrefix(releaseFilter))
        XCTAssertFalse(debugItem.hasPrefix(releaseFilter))
        XCTAssertFalse(otherScopeItem.hasPrefix(releaseFilter))
        XCTAssertFalse(PasscodeKeychainScope.service(PasscodeKeychainScope.legacyPasscodeService, environment: debug) == PasscodeKeychainScope.legacyPasscodeService)
    }

    func testPasscodeItemsUseTheScopedService() throws {
        let keychain = PasscodeKeychain(environment: self.environment)
        try keychain.write(Data("scoped".utf8), account: self.account)
        XCTAssertEqual(self.value(service: self.scoped(PasscodeKeychainScope.legacyPasscodeService), account: self.account), "scoped")
        XCTAssertNil(self.value(service: PasscodeKeychainScope.legacyPasscodeService, account: self.account))
        XCTAssertEqual(try keychain.read(self.account), Data("scoped".utf8))
        try keychain.remove(self.account)
        XCTAssertNil(self.value(service: self.scoped(PasscodeKeychainScope.legacyPasscodeService), account: self.account))
    }

    func testBiometricItemsUseTheScopedService() throws {
        let scopedQuery = try PasscodeKeychain(environment: self.environment).query("biometric.\(self.account)")
        XCTAssertEqual(scopedQuery[kSecAttrService as String] as? String, self.scoped(self.biometricService))
        let unscopedQuery = try PasscodeKeychain(environment: try self.makeEnvironment(scope: nil)).query("biometric.\(self.account)")
        XCTAssertEqual(unscopedQuery[kSecAttrService as String] as? String, self.biometricService)
    }

    func testScopedReadNeverFallsBackToUnscopedItems() throws {
        self.add("legacy", service: PasscodeKeychainScope.legacyPasscodeService, account: self.account)
        let keychain = PasscodeKeychain(environment: self.environment)
        XCTAssertNil(try keychain.read(self.account))
        try keychain.write(Data("scoped".utf8), account: self.account)
        try keychain.remove(self.account)
        XCTAssertNil(try keychain.read(self.account))
        XCTAssertEqual(self.value(service: PasscodeKeychainScope.legacyPasscodeService, account: self.account), "legacy")
    }

    func testMigrationCopiesTheCredentialSetAndWalletItemsAndKeepsTheOriginals() {
        self.add("credential", service: self.passcodeService, account: "credential")
        self.add("device", service: self.passcodeService, account: "device")
        self.add("attempts", service: self.passcodeService, account: "attempts")
        self.add("descriptor", service: self.walletPrefix + "descriptor.ns", account: "wallet")
        self.add("envelope", service: self.walletPrefix + "vault.ns", account: "secret")
        self.add("metadata", service: self.walletPrefix + "metadata.ns", account: "wallet")
        XCTAssertEqual(self.migrate(), .migrated(4))
        XCTAssertEqual(self.value(service: self.scoped(self.passcodeService), account: "credential"), "credential")
        XCTAssertEqual(self.value(service: self.scoped(self.passcodeService), account: "device"), "device")
        XCTAssertEqual(self.value(service: self.scoped(self.walletPrefix + "descriptor.ns"), account: "wallet"), "descriptor")
        XCTAssertEqual(self.value(service: self.scoped(self.walletPrefix + "vault.ns"), account: "secret"), "envelope")
        XCTAssertNil(self.value(service: self.scoped(self.passcodeService), account: "attempts"))
        XCTAssertNil(self.value(service: self.scoped(self.walletPrefix + "metadata.ns"), account: "wallet"))
        XCTAssertEqual(self.value(service: self.passcodeService, account: "credential"), "credential")
        XCTAssertEqual(self.value(service: self.passcodeService, account: "device"), "device")
        XCTAssertEqual(self.value(service: self.passcodeService, account: "attempts"), "attempts")
        XCTAssertEqual(self.value(service: self.walletPrefix + "descriptor.ns", account: "wallet"), "descriptor")
        XCTAssertEqual(self.value(service: self.walletPrefix + "vault.ns", account: "secret"), "envelope")
        XCTAssertEqual(self.migrate(), .migrated(0))
    }

    func testMigrationLeavesAScopeWithItsOwnCredential() {
        self.add("scoped", service: self.scoped(self.passcodeService), account: "credential")
        self.add("credential", service: self.passcodeService, account: "credential")
        self.add("device", service: self.passcodeService, account: "device")
        self.add("envelope", service: self.walletPrefix + "vault.ns", account: "secret")
        XCTAssertEqual(self.migrate(), .nothingToMigrate)
        XCTAssertEqual(self.value(service: self.scoped(self.passcodeService), account: "credential"), "scoped")
        XCTAssertNil(self.value(service: self.scoped(self.passcodeService), account: "device"))
        XCTAssertNil(self.value(service: self.scoped(self.walletPrefix + "vault.ns"), account: "secret"))
        XCTAssertEqual(self.value(service: self.walletPrefix + "vault.ns", account: "secret"), "envelope")
    }

    func testMigrationResumesAnInterruptedCopy() {
        self.add("credential", service: self.passcodeService, account: "credential")
        self.add("device", service: self.passcodeService, account: "device")
        self.add("descriptor", service: self.walletPrefix + "descriptor.ns", account: "wallet")
        self.add("envelope", service: self.walletPrefix + "vault.ns", account: "secret")
        self.add("descriptor", service: self.scoped(self.walletPrefix + "descriptor.ns"), account: "wallet")
        self.add("device", service: self.scoped(self.passcodeService), account: "device")
        XCTAssertEqual(self.migrate(), .migrated(2))
        XCTAssertEqual(self.value(service: self.scoped(self.passcodeService), account: "credential"), "credential")
        XCTAssertEqual(self.value(service: self.scoped(self.walletPrefix + "vault.ns"), account: "secret"), "envelope")
    }

    func testMigrationLeavesAWalletTheScopeAlreadyHolds() {
        self.add("credential", service: self.passcodeService, account: "credential")
        self.add("device", service: self.passcodeService, account: "device")
        self.add("descriptor", service: self.walletPrefix + "descriptor.ns", account: "wallet")
        self.add("envelope", service: self.walletPrefix + "vault.ns", account: "secret")
        self.add("watch-only", service: self.scoped(self.walletPrefix + "descriptor.ns"), account: "wallet")
        XCTAssertEqual(self.migrate(), .migrated(2))
        XCTAssertEqual(self.value(service: self.scoped(self.walletPrefix + "descriptor.ns"), account: "wallet"), "watch-only")
        XCTAssertFalse(self.exists(service: self.scoped(self.walletPrefix + "vault.ns"), account: "secret"))
        XCTAssertEqual(self.value(service: self.walletPrefix + "descriptor.ns", account: "wallet"), "descriptor")
        XCTAssertEqual(self.value(service: self.walletPrefix + "vault.ns", account: "secret"), "envelope")
    }

    func testMigrationLeavesADifferentScopedDeviceAlone() {
        self.add("credential", service: self.passcodeService, account: "credential")
        self.add("device", service: self.passcodeService, account: "device")
        self.add("other", service: self.scoped(self.passcodeService), account: "device")
        XCTAssertEqual(self.migrate(), .nothingToMigrate)
        XCTAssertNil(self.value(service: self.scoped(self.passcodeService), account: "credential"))
        XCTAssertEqual(self.value(service: self.scoped(self.passcodeService), account: "device"), "other")
    }

    func testAWalletWithAnItemThatNeedsConfirmationIsNotCopiedOrTouched() throws {
        self.add("credential", service: self.passcodeService, account: "credential")
        self.add("device", service: self.passcodeService, account: "device")
        self.add("descriptor", service: self.walletPrefix + "descriptor.ns", account: "wallet")
        try self.addNeedingConfirmation("envelope", service: self.walletPrefix + "vault.ns", account: "secret")
        self.add("other", service: self.walletPrefix + "descriptor.other", account: "wallet")
        XCTAssertEqual(self.migrate(), .migrated(3))
        XCTAssertFalse(self.exists(service: self.scoped(self.walletPrefix + "descriptor.ns"), account: "wallet"))
        XCTAssertFalse(self.exists(service: self.scoped(self.walletPrefix + "vault.ns"), account: "secret"))
        XCTAssertEqual(self.value(service: self.scoped(self.walletPrefix + "descriptor.other"), account: "wallet"), "other")
        XCTAssertEqual(self.value(service: self.walletPrefix + "descriptor.ns", account: "wallet"), "descriptor")
        XCTAssertTrue(self.exists(service: self.walletPrefix + "vault.ns", account: "secret"))
    }

    func testMigrationNeedsBothTheCredentialAndTheDevice() {
        self.add("credential", service: self.passcodeService, account: "credential")
        self.add("envelope", service: self.walletPrefix + "vault.ns", account: "secret")
        XCTAssertEqual(self.migrate(), .nothingToMigrate)
        XCTAssertNil(self.value(service: self.scoped(self.passcodeService), account: "credential"))
        XCTAssertNil(self.value(service: self.scoped(self.walletPrefix + "vault.ns"), account: "secret"))
        XCTAssertEqual(self.value(service: self.passcodeService, account: "credential"), "credential")
        XCTAssertEqual(self.value(service: self.walletPrefix + "vault.ns", account: "secret"), "envelope")
    }

    func testMigrationWithoutAScopeDoesNothing() throws {
        self.add("credential", service: self.passcodeService, account: "credential")
        self.add("device", service: self.passcodeService, account: "device")
        XCTAssertEqual(self.migrate(environment: try self.makeEnvironment(scope: nil)), .nothingToMigrate)
        XCTAssertEqual(self.value(service: self.passcodeService, account: "credential"), "credential")
    }

    func testMigrationRestoresUserInteraction() {
        self.add("credential", service: self.passcodeService, account: "credential")
        self.add("device", service: self.passcodeService, account: "device")
        var before: DarwinBoolean = false
        XCTAssertEqual(SecKeychainGetUserInteractionAllowed(&before), errSecSuccess)
        XCTAssertEqual(self.migrate(), .migrated(2))
        var after: DarwinBoolean = false
        XCTAssertEqual(SecKeychainGetUserInteractionAllowed(&after), errSecSuccess)
        XCTAssertEqual(before.boolValue, after.boolValue)
    }
}
#endif
