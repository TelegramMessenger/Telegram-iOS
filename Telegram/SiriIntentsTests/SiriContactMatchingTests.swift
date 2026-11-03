import Foundation
import Contacts
import XCTest
import Postbox
@testable import TelegramCore
@testable import IntentsExtensionLib

/// Which Telegram user a contact Siri picked from the address book stands for
/// (bugs.telegram.org/c/251). Siri hands over the device contact; its numbers are compared with
/// the Telegram contacts', and a number saved in national format ("600 00 00 00" rather than
/// "+34 600 00 00 00") carries no country code for any comparison of digits to find.
final class SiriContactMatchingTests: XCTestCase {
    private var store: TestPostbox!
    private let juan = IntentMessageFixtures.user(1001, firstName: "Juan", phone: "34600000000")
    private let marie = IntentMessageFixtures.user(1002, firstName: "Marie", phone: "33612345678")
    private let alice = IntentMessageFixtures.user(1003, firstName: "Alice", phone: "15551234567")
    /// Once a contact, since removed. Deleting a contact leaves its import record in place.
    private let ex = IntentMessageFixtures.user(1004, firstName: "Ex", phone: "34600000002")
    /// Holds the number Juan had when contact sync imported it.
    private let pedro = IntentMessageFixtures.user(1005, firstName: "Pedro", phone: "34600000003")

    override func setUpWithError() throws {
        try super.setUpWithError()
        self.store = try TestPostbox(name: "siri-contact-matching")
        self.store.transaction { transaction in
            transaction.updatePeersInternal([self.juan, self.marie, self.alice, self.ex, self.pedro], update: { _, updated in updated })
            transaction.replaceContactPeerIds(Set([self.juan.id, self.marie.id, self.alice.id, self.pedro.id]))
        }
    }

    override func tearDownWithError() throws {
        self.store?.close()
        self.store = nil
        try super.tearDownWithError()
    }

    /// What contact sync leaves behind for a number it imported: keyed by the number as the
    /// device stores it, holding the user the server answered with.
    private func recordImport(of number: String, as peerId: PeerId?, localIdentifiers: [String]) {
        self.store.transaction { transaction in
            transaction.setDeviceContactImportInfo(
                TelegramDeviceContactImportIdentifier.phoneNumber(DeviceContactNormalizedPhoneNumber(rawValue: number)).key,
                value: TelegramDeviceContactImportedData.imported(data: ImportableDeviceContactData(firstName: "", lastName: "", localIdentifiers: localIdentifiers), importedByCount: 0, peerId: peerId)
            )
        }
    }

    private func match(_ contact: MatchingDeviceContact) -> [(String, PeerId)] {
        let result = self.store.transaction { transaction in
            return matchingCloudContacts(transaction: transaction, contacts: [contact])
        }
        return (result ?? []).map { ($0.0, $0.1.id) }
    }

    private func match(_ stableId: String, numbers: [String]) -> [(String, PeerId)] {
        return self.match(MatchingDeviceContact(stableId: stableId, firstName: "", lastName: "", phoneNumbers: numbers, peerId: nil))
    }

    /// An address-book entry, read the way the extension reads the one Siri picked.
    private func deviceContact(numbers: [String], telegramLink: String? = nil) -> MatchingDeviceContact {
        let contact = CNMutableContact()
        contact.phoneNumbers = numbers.map { CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: $0)) }
        if let telegramLink {
            contact.urlAddresses = [CNLabeledValue(label: "Telegram", value: telegramLink as NSString)]
        }
        return matchingDeviceContact(contact)
    }

    func testNationalNumberResolvesToTheUserItWasImportedAs() {
        self.recordImport(of: "600 00 00 00", as: self.juan.id, localIdentifiers: ["juan"])

        let result = self.match("juan", numbers: ["600 00 00 00"])

        XCTAssertEqual(result.map(\.0), ["juan"])
        XCTAssertEqual(result.map(\.1), [self.juan.id])
    }

    /// A trunk "0" keeps a nine-digit national number at ten digits, and its last ten then
    /// differ from the international number's.
    func testTrunkPrefixedNationalNumberResolves() {
        self.recordImport(of: "06 12 34 56 78", as: self.marie.id, localIdentifiers: ["marie"])

        XCTAssertEqual(self.match("marie", numbers: ["06 12 34 56 78"]).map(\.1), [self.marie.id])
    }

    /// Sync lists only some of the device contacts sharing a number in `localIdentifiers`,
    /// depending on the order it meets them; the number itself identifies the record.
    func testSharedNumberResolvesForAContactTheRecordDoesNotList() {
        self.recordImport(of: "600 00 00 00", as: self.juan.id, localIdentifiers: ["juan-home"])

        XCTAssertEqual(self.match("juan-mobile", numbers: ["600 00 00 00"]).map(\.1), [self.juan.id])
    }

    /// Without a record (sync off, or not run yet) an international number still matches.
    func testInternationalNumberWithoutARecordStillMatchesByDigits() {
        XCTAssertEqual(self.match("alice", numbers: ["+1 (555) 123-4567"]).map(\.1), [self.alice.id])
    }

    func testRecordAndDigitsNamingTheSameUserYieldOneCandidate() {
        self.recordImport(of: "+34 600 00 00 00", as: self.juan.id, localIdentifiers: ["juan"])

        XCTAssertEqual(self.match("juan", numbers: ["+34 600 00 00 00"]).map(\.1), [self.juan.id])
    }

    /// The person the contact was imported as has moved to another number, and someone else now
    /// holds this one. The record still names the former, the digits the latter, and Siri asks
    /// rather than picking either.
    func testRecordAndDigitsNamingDifferentUsersOfferBoth() {
        self.recordImport(of: "+34 600 00 00 03", as: self.juan.id, localIdentifiers: ["juan"])

        XCTAssertEqual(self.match("juan", numbers: ["+34 600 00 00 03"]).map(\.1), [self.juan.id, self.pedro.id])
    }

    func testEveryNumberOfTheContactContributesACandidate() {
        self.recordImport(of: "600 00 00 00", as: self.juan.id, localIdentifiers: ["both"])

        let result = self.match("both", numbers: ["600 00 00 00", "+1 555 123 4567"])

        XCTAssertEqual(Set(result.map(\.1)), Set([self.juan.id, self.alice.id]))
    }

    /// The record is keyed by the number as the device stores it, so reading the address book
    /// must not clean the number up first.
    func testNumberIsLookedUpAsTheDeviceStoresIt() {
        self.recordImport(of: "600 00 00 00", as: self.juan.id, localIdentifiers: [])

        XCTAssertEqual(self.match(self.deviceContact(numbers: ["600 00 00 00"])).map(\.1), [self.juan.id])
    }

    /// The contact's own link to a Telegram user outranks what its numbers suggest.
    func testExplicitTelegramLinkIsTheFirstCandidate() {
        self.recordImport(of: "600 00 00 00", as: self.juan.id, localIdentifiers: [])

        let result = self.match(self.deviceContact(numbers: ["600 00 00 00"], telegramLink: "https://t.me/@id\(self.marie.id.id._internalGetInt64Value())"))

        XCTAssertEqual(result.map(\.1), [self.marie.id, self.juan.id])
    }

    /// Deleting a contact leaves its import record behind, and that leftover alone must not make
    /// the user a candidate again. A national number, so that the record is the only way to them.
    func testRecordOfAUserNoLongerInContactsDoesNotResolve() {
        self.recordImport(of: "600 00 00 02", as: self.ex.id, localIdentifiers: ["ex"])

        XCTAssertTrue(self.match("ex", numbers: ["600 00 00 02"]).isEmpty)

        self.store.transaction { transaction in
            transaction.replaceContactPeerIds(transaction.getContactPeerIds().union([self.ex.id]))
        }
        XCTAssertEqual(self.match("ex", numbers: ["600 00 00 02"]).map(\.1), [self.ex.id], "the same record resolves once the user is a contact again")
    }

    func testNumberImportedAsNobodyDoesNotResolve() {
        self.recordImport(of: "600 00 00 01", as: nil, localIdentifiers: ["stranger"])

        XCTAssertTrue(self.match("stranger", numbers: ["600 00 00 01"]).isEmpty)
    }
}
