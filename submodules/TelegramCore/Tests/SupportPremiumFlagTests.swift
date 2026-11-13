import Foundation
import XCTest
import Postbox
import SwiftSignalKit
import TelegramApi
@testable import TelegramCore

final class SupportPremiumFlagTests: XCTestCase {
    private let accountPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1234))
    private let otherPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(5678))
    private let supportPhone = "42400000"
    private let ordinaryPhone = "15550000"
    private let activeStatus = "Your Premium Subscription is active. \nExtension date is 02.12.2026.\nManage in Premium Bot."
    private let termsStatus = "By subscribing to Telegram Premium you agree to the Terms of Service."

    private var postbox: Postbox!
    private var directory: URL!

    override func setUpWithError() throws {
        initializeAccountManagement()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("support-premium-tests-" + UUID().uuidString)
        let encryption = ValueBoxEncryptionParameters(forceEncryptionIfNoSet: false, key: try XCTUnwrap(.init(data: Data(count: 32))), salt: try XCTUnwrap(.init(data: Data(count: 16))))
        let opened = try value(openPostbox(basePath: directory.path, seedConfiguration: telegramPostboxSeedConfiguration, encryptionParameters: encryption, timestampForAbsoluteTimeBasedOperations: Int32(Date().timeIntervalSince1970), isMainProcess: true, isTemporary: false, isReadOnly: false, useCopy: false, useCaches: true, removeDatabaseOnError: false)
            |> filter { result in
                if case .upgrading = result { return false }
                return true
            })
        guard case let .postbox(postbox) = opened else {
            throw NSError(domain: "SupportPremiumFlagTests", code: 1)
        }
        self.postbox = postbox
    }

    override func tearDownWithError() throws {
        if let postbox = postbox {
            let _ = try value(postbox.transaction { _ in })
            let _ = try value(postbox.mediaBox.storageBox.all())
            let _ = try value(postbox.mediaBox.cacheStorageBox.all())
            postbox.mediaBox.dataQueue.sync {}
        }
        postbox = nil
        Postbox.sharedQueue.sync {}
        if let directory = directory {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private func value<T>(_ signal: Signal<T, NoError>, file: StaticString = #filePath, line: UInt = #line) throws -> T {
        let completed = expectation(description: "signal completed")
        let result = Atomic<T?>(value: nil)
        let disposable = (signal |> take(1)).start(next: { value in
            let _ = result.swap(value)
        }, completed: { completed.fulfill() })
        defer { disposable.dispose() }
        wait(for: [completed], timeout: 15)
        return try XCTUnwrap(result.with { $0 }, file: file, line: line)
    }

    private func apiUser(id: PeerId, isSelf: Bool, premium: Bool = false, phone: String?) -> Api.User {
        var flags: Int32 = 0
        if isSelf {
            flags |= 1 << 10
        }
        if premium {
            flags |= 1 << 28
        }
        return Api.User.user(.init(flags: flags, flags2: 0, id: id.id._internalGetInt64Value(), accessHash: 5678, firstName: "Name", lastName: nil, username: nil, phone: phone, photo: nil, status: nil, botInfoVersion: nil, restrictionReason: nil, botInlinePlaceholder: nil, langCode: nil, emojiStatus: nil, usernames: nil, storiesMaxId: nil, color: nil, profileColor: nil, botActiveUsers: nil, botVerificationIcon: nil, sendPaidMessagesStars: nil, linkedCommunityId: nil))
    }

    private func setStatus(_ status: String, transaction: Transaction) {
        let configuration = PremiumPromoConfiguration(status: status, statusEntities: [], videos: [:], premiumProductOptions: [])
        transaction.setPreferencesEntry(key: PreferencesKeys.premiumPromo, value: PreferencesEntry(configuration))
    }

    private func storedIsPremium(status: String?, user: Api.User, peerId: PeerId, signedInAs account: PeerId? = nil) throws -> Bool {
        let signedIn = account ?? self.accountPeerId
        return try value(postbox.transaction { transaction -> Bool in
            transaction.setState(AuthorizedAccountState(isTestingEnvironment: false, masterDatacenterId: 2, peerId: signedIn, state: nil, invalidatedChannels: []))
            if let status {
                self.setStatus(status, transaction: transaction)
            }
            updatePeers(transaction: transaction, accountPeerId: signedIn, peers: AccumulatedPeers(transaction: transaction, chats: [], users: [user]))
            return transaction.getPeer(peerId)?.isPremium ?? false
        })
    }

    func testDateInStatusCounts() {
        XCTAssertTrue(supportPremiumStatusHasExpiryDate(self.activeStatus))
        XCTAssertTrue(supportPremiumStatusHasExpiryDate("Until 2/12/26"))
    }

    func testStatusWithoutDateDoesNotCount() {
        XCTAssertFalse(supportPremiumStatusHasExpiryDate(""))
        XCTAssertFalse(supportPremiumStatusHasExpiryDate(self.termsStatus))
        XCTAssertFalse(supportPremiumStatusHasExpiryDate("Your Premium Subscription is active."))
    }

    func testParseAloneFollowsTheServer() {
        let user = TelegramUser(user: self.apiUser(id: self.accountPeerId, isSelf: true, phone: self.supportPhone))
        XCTAssertFalse(user.flags.contains(.isPremium))
    }

    func testSupportAccountWithExpiryDateIsPremium() throws {
        XCTAssertTrue(try self.storedIsPremium(status: self.activeStatus, user: self.apiUser(id: self.accountPeerId, isSelf: true, phone: self.supportPhone), peerId: self.accountPeerId))
    }

    func testSupportAccountWithoutExpiryDateIsNotPremium() throws {
        XCTAssertFalse(try self.storedIsPremium(status: self.termsStatus, user: self.apiUser(id: self.accountPeerId, isSelf: true, phone: self.supportPhone), peerId: self.accountPeerId))
    }

    func testSupportAccountBeforeAnyStatusIsNotPremium() throws {
        XCTAssertFalse(try self.storedIsPremium(status: nil, user: self.apiUser(id: self.accountPeerId, isSelf: true, phone: self.supportPhone), peerId: self.accountPeerId))
    }

    func testSupportAccountHidesItsOwnStar() throws {
        XCTAssertTrue(try self.storedIsPremium(status: self.activeStatus, user: self.apiUser(id: self.accountPeerId, isSelf: true, phone: self.supportPhone), peerId: self.accountPeerId))
        let showsStar = try value(postbox.transaction { transaction -> Bool in
            return transaction.getPeer(self.accountPeerId)?.showsPremiumStar ?? true
        })
        XCTAssertFalse(showsStar)
    }

    func testOrdinaryAccountKeepsItsStar() throws {
        XCTAssertTrue(try self.storedIsPremium(status: self.termsStatus, user: self.apiUser(id: self.accountPeerId, isSelf: true, premium: true, phone: self.ordinaryPhone), peerId: self.accountPeerId))
        let showsStar = try value(postbox.transaction { transaction -> Bool in
            return transaction.getPeer(self.accountPeerId)?.showsPremiumStar ?? false
        })
        XCTAssertTrue(showsStar)
    }

    func testOrdinaryAccountFollowsTheServer() throws {
        XCTAssertFalse(try self.storedIsPremium(status: self.activeStatus, user: self.apiUser(id: self.accountPeerId, isSelf: true, phone: self.ordinaryPhone), peerId: self.accountPeerId))
        XCTAssertTrue(try self.storedIsPremium(status: self.termsStatus, user: self.apiUser(id: self.accountPeerId, isSelf: true, premium: true, phone: self.ordinaryPhone), peerId: self.accountPeerId))
    }

    func testSupportUserSeenFromAnotherAccountFollowsTheServer() throws {
        XCTAssertFalse(try self.storedIsPremium(status: self.activeStatus, user: self.apiUser(id: self.otherPeerId, isSelf: false, phone: self.supportPhone), peerId: self.otherPeerId))
    }

    func testStatusChangeUpdatesTheStoredFlag() throws {
        XCTAssertFalse(try self.storedIsPremium(status: self.termsStatus, user: self.apiUser(id: self.accountPeerId, isSelf: true, phone: self.supportPhone), peerId: self.accountPeerId))
        let gained = try value(postbox.transaction { transaction -> Bool in
            self.setStatus(self.activeStatus, transaction: transaction)
            supportRefreshPremiumFromStatus(transaction: transaction, accountPeerId: self.accountPeerId)
            return transaction.getPeer(self.accountPeerId)?.isPremium ?? false
        })
        XCTAssertTrue(gained)
        let lost = try value(postbox.transaction { transaction -> Bool in
            self.setStatus(self.termsStatus, transaction: transaction)
            supportRefreshPremiumFromStatus(transaction: transaction, accountPeerId: self.accountPeerId)
            return transaction.getPeer(self.accountPeerId)?.isPremium ?? false
        })
        XCTAssertFalse(lost)
    }
}
