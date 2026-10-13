import Foundation
import XCTest
import TelegramCore
@testable import IntentsExtensionLib

/// Which account the extension answers from. It follows the app's current account record,
/// and a record that has been logged out is no account at all: logging out marks the record
/// before the app moves its selection, and a request in that window (or a cached account for
/// that record) must not read or send with the revoked session.
final class UsableAccountRecordTests: XCTestCase {
    private let id = AccountRecordId(rawValue: -3039772842040732916)

    func testTheCurrentRecordIsUsable() {
        let record = AccountRecord<TelegramAccountManagerTypes.Attribute>(id: self.id, attributes: [], temporarySessionId: nil)

        XCTAssertEqual(usableAccountRecordId(record), self.id)
    }

    func testALoggedOutRecordIsNotUsable() {
        let record = AccountRecord<TelegramAccountManagerTypes.Attribute>(id: self.id, attributes: [.loggedOut(LoggedOutAccountAttribute())], temporarySessionId: nil)

        XCTAssertNil(usableAccountRecordId(record))
    }

    func testNoCurrentRecordIsNoAccount() {
        XCTAssertNil(usableAccountRecordId(nil))
    }
}
