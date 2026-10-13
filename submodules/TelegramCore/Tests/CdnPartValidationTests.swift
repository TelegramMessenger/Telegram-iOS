import XCTest
@testable import TelegramCore

final class CdnPartValidationTests: XCTestCase {
    func testRedirectKeyMaterialMustBeAes256CtrSized() {
        XCTAssertTrue(cdnRedirectKeyMaterialIsValid(encryptionKey: Data(count: 32), encryptionIv: Data(count: 16)))
        XCTAssertFalse(cdnRedirectKeyMaterialIsValid(encryptionKey: Data(count: 32), encryptionIv: Data(count: 2)))
        XCTAssertFalse(cdnRedirectKeyMaterialIsValid(encryptionKey: Data(count: 32), encryptionIv: Data()))
        XCTAssertFalse(cdnRedirectKeyMaterialIsValid(encryptionKey: Data(count: 32), encryptionIv: Data(count: 32)))
        XCTAssertFalse(cdnRedirectKeyMaterialIsValid(encryptionKey: Data(count: 16), encryptionIv: Data(count: 16)))
    }

    func testFullPartsAreAcceptedAndOversizedPartsAreNot() {
        XCTAssertTrue(cdnPartLengthIsAcceptable(offset: 0, requestedLength: 131072, receivedLength: 131072, knownSize: nil))
        XCTAssertTrue(cdnPartLengthIsAcceptable(offset: 131072, requestedLength: 131072, receivedLength: 131072, knownSize: 1_000_000))
        XCTAssertFalse(cdnPartLengthIsAcceptable(offset: 0, requestedLength: 131072, receivedLength: 131073, knownSize: nil))
    }

    func testPartsRunningPastTheDeclaredEndAreRejected() {
        XCTAssertFalse(cdnPartLengthIsAcceptable(offset: 917504, requestedLength: 131072, receivedLength: 131072, knownSize: 1_000_000))
        XCTAssertFalse(cdnPartLengthIsAcceptable(offset: 917504, requestedLength: 131072, receivedLength: 82497, knownSize: 1_000_000))
    }

    func testShortPartIsAcceptedOnlyAtTheDeclaredEnd() {
        XCTAssertTrue(cdnPartLengthIsAcceptable(offset: 917504, requestedLength: 131072, receivedLength: 82496, knownSize: 1_000_000))
        XCTAssertTrue(cdnPartLengthIsAcceptable(offset: 1_048_576, requestedLength: 131072, receivedLength: 0, knownSize: 1_048_576))
        XCTAssertFalse(cdnPartLengthIsAcceptable(offset: 1_048_576, requestedLength: 131072, receivedLength: 0, knownSize: 4_000_000))
        XCTAssertFalse(cdnPartLengthIsAcceptable(offset: 0, requestedLength: 262144, receivedLength: 131072, knownSize: 4_000_000))
        XCTAssertFalse(cdnPartLengthIsAcceptable(offset: 917504, requestedLength: 131072, receivedLength: 65536, knownSize: 1_000_000))
    }

    func testShortPartOfAFileOfUnknownSizeMustEndInsideAHashBlock() {
        XCTAssertFalse(cdnPartLengthIsAcceptable(offset: 1_048_576, requestedLength: 131072, receivedLength: 0, knownSize: nil))
        XCTAssertFalse(cdnPartLengthIsAcceptable(offset: 0, requestedLength: 262144, receivedLength: 131072, knownSize: nil))
        XCTAssertTrue(cdnPartLengthIsAcceptable(offset: 0, requestedLength: 131072, receivedLength: 1000, knownSize: nil))
        XCTAssertTrue(cdnPartLengthIsAcceptable(offset: 131072, requestedLength: 262144, receivedLength: 131073, knownSize: nil))
    }
}
