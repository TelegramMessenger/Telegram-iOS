import XCTest
import Postbox
@testable import TelegramCore

final class MediaResourceDebugInfoTests: XCTestCase {
    // "Send Logs" on a message lists this for each of its media; it has to identify the resource,
    // as the FetchV2 log lines do, rather than just name the kind of input location.
    func testCloudResourceDebugInfoIsTheResourceId() {
        let resource = CloudDocumentMediaResource(datacenterId: 2, fileId: 1234567, accessHash: 89, size: nil, fileReference: Data([1]), fileName: nil)
        XCTAssertEqual(extractMediaResourceDebugInfo(resource: resource), resource.id.stringRepresentation)
    }

    func testNonCloudResourceHasNoDebugInfo() {
        XCTAssertNil(extractMediaResourceDebugInfo(resource: LocalFileMediaResource(fileId: 1)))
    }
}
