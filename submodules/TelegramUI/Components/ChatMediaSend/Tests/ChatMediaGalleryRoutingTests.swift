import Foundation
import XCTest
import ChatMediaSend

final class ChatMediaGalleryRoutingTests: XCTestCase {
    func testNonFileRouteUnchanged() {
        let table: [(galleryOn: Bool, customSelection: Bool, explicitMultiple: Bool, expected: ChatMediaGalleryRoute)] = [
            (false, false, false, .legacy),
            (false, false, true, .legacy),
            (false, true, false, .legacy),
            (false, true, true, .legacy),
            (true, false, false, .chat),
            (true, false, true, .legacy),
            (true, true, false, .legacy),
            (true, true, true, .legacy)
        ]
        for row in table {
            for filePickerOn in [false, true] {
                XCTAssertEqual(
                    chatMediaGalleryRoute(galleryOn: row.galleryOn, filePickerOn: filePickerOn, asFile: false, hasPreparedCompletion: true, hasCustomSelection: row.customSelection, explicitMultipleSelection: row.explicitMultiple),
                    row.expected,
                    "\(row) \(filePickerOn)"
                )
                XCTAssertEqual(
                    chatMediaGalleryRoute(galleryOn: row.galleryOn, filePickerOn: filePickerOn, asFile: false, hasPreparedCompletion: false, hasCustomSelection: row.customSelection, explicitMultipleSelection: row.explicitMultiple),
                    .legacy,
                    "\(row) \(filePickerOn)"
                )
            }
        }
    }

    func testFileSubjectRoutesToFilePreviewWithoutPreparedCompletion() {
        for galleryOn in [false, true] {
            for hasPreparedCompletion in [false, true] {
                XCTAssertEqual(
                    chatMediaGalleryRoute(galleryOn: galleryOn, filePickerOn: true, asFile: true, hasPreparedCompletion: hasPreparedCompletion, hasCustomSelection: false, explicitMultipleSelection: false),
                    .filePreview
                )
            }
        }
    }

    func testFileSubjectLegacyWhenFilePickerOff() {
        for galleryOn in [false, true] {
            for hasPreparedCompletion in [false, true] {
                XCTAssertEqual(
                    chatMediaGalleryRoute(galleryOn: galleryOn, filePickerOn: false, asFile: true, hasPreparedCompletion: hasPreparedCompletion, hasCustomSelection: false, explicitMultipleSelection: false),
                    .legacy
                )
            }
        }
    }

    func testGallerySelectionOffWhenLimitIsOne() {
        XCTAssertFalse(chatMediaGalleryUsesSelection(selectionLimit: 1))
        XCTAssertTrue(chatMediaGalleryUsesSelection(selectionLimit: 2))
        XCTAssertTrue(chatMediaGalleryUsesSelection(selectionLimit: 100))
    }

    func testLegacySelectionIndexIsZeroBased() {
        XCTAssertEqual(chatMediaGalleryZeroBasedSelectionIndex(legacyIndex: 1), 0)
        XCTAssertEqual(chatMediaGalleryZeroBasedSelectionIndex(legacyIndex: 3), 2)
        XCTAssertNil(chatMediaGalleryZeroBasedSelectionIndex(legacyIndex: 0))
        XCTAssertNil(chatMediaGalleryZeroBasedSelectionIndex(legacyIndex: NSNotFound))
    }
}
