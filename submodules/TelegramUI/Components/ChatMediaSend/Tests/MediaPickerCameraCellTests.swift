import Foundation
import UIKit
import XCTest
import ChatMediaSend

final class MediaPickerCameraCellTests: XCTestCase {
    func testCellBranchSelection() {
        let table: [(flagOn: Bool, subject: MediaPickerCameraCellSubject, isIpad: Bool, isSimulator: Bool, expected: MediaPickerCameraCellBranch)] = [
            (false, .chatAssets, false, false, .legacyAttachmentCamera),
            (false, .chatAssets, false, true, .legacyAttachmentCamera),
            (false, .chatAssets, true, false, .legacyAttachmentCamera),
            (false, .chatAssets, true, true, .legacyAttachmentCamera),
            (true, .chatAssets, false, false, .chatCamera),
            (true, .chatAssets, false, true, .chatCamera),
            (true, .chatAssets, true, false, .chatCamera),
            (true, .chatAssets, true, true, .chatCamera),
            (false, .sticker, false, false, .editorCamera),
            (false, .sticker, false, true, .none),
            (false, .sticker, true, false, .none),
            (false, .sticker, true, true, .none),
            (true, .sticker, false, false, .editorCamera),
            (true, .sticker, false, true, .none),
            (true, .sticker, true, false, .none),
            (true, .sticker, true, true, .none),
            (false, .avatar, false, false, .editorCamera),
            (false, .avatar, false, true, .none),
            (false, .avatar, true, false, .none),
            (false, .avatar, true, true, .none),
            (true, .avatar, false, false, .editorCamera),
            (true, .avatar, false, true, .none),
            (true, .avatar, true, false, .none),
            (true, .avatar, true, true, .none),
            (false, .other, false, false, .none),
            (false, .other, false, true, .none),
            (false, .other, true, false, .none),
            (false, .other, true, true, .none),
            (true, .other, false, false, .none),
            (true, .other, false, true, .none),
            (true, .other, true, false, .none),
            (true, .other, true, true, .none)
        ]
        XCTAssertEqual(table.count, 32)
        for row in table {
            XCTAssertEqual(
                mediaPickerCameraCellBranch(flagOn: row.flagOn, subject: row.subject, isIpad: row.isIpad, isSimulator: row.isSimulator),
                row.expected,
                "\(row)"
            )
        }
    }

    func testCameralessSubjectHasNoCellAndNeverRequestsAccess() {
        for flagOn in [false, true] {
            for isIpad in [false, true] {
                for isSimulator in [false, true] {
                    XCTAssertEqual(mediaPickerCameraCellBranch(flagOn: flagOn, subject: .noCamera, isIpad: isIpad, isSimulator: isSimulator), .none)
                }
            }
        }
        XCTAssertFalse(mediaPickerRequestsCameraAccess(subject: .noCamera))
        XCTAssertTrue(mediaPickerRequestsCameraAccess(subject: .chatAssets))
        XCTAssertTrue(mediaPickerRequestsCameraAccess(subject: .sticker))
        XCTAssertTrue(mediaPickerRequestsCameraAccess(subject: .avatar))
        XCTAssertTrue(mediaPickerRequestsCameraAccess(subject: .other))
    }

    func testChatCellCaptureAction() {
        let table: [(isActive: Bool, hasLivePreview: Bool, isInvalidated: Bool, isInWindow: Bool, isHandedOff: Bool, expected: MediaPickerCameraCellCaptureAction)] = [
            (true, true, false, true, false, .start),
            (false, true, false, true, false, .stop),
            (true, false, false, true, false, .stop),
            (true, true, true, true, false, .stop),
            (true, true, false, false, false, .stop),
            (true, true, false, true, true, .none),
            (false, true, false, true, true, .none),
            (true, false, false, true, true, .none),
            (true, true, true, false, true, .none),
            (true, true, false, false, true, .none)
        ]
        for row in table {
            XCTAssertEqual(
                mediaPickerChatCameraCellCaptureAction(isActive: row.isActive, hasLivePreview: row.hasLivePreview, isInvalidated: row.isInvalidated, isInWindow: row.isInWindow, isHandedOff: row.isHandedOff),
                row.expected,
                "\(row)"
            )
        }
    }

    func testCellPreviewSizeFollowsFeedAspect() {
        let chat = mediaPickerCameraCellPreviewSize(branch: .chatCamera, layoutWidth: 402.0, screenWidth: 402.0)
        XCTAssertEqual(chat.width, 402.0)
        XCTAssertEqual(chat.height, 536.0)

        let editor = mediaPickerCameraCellPreviewSize(branch: .editorCamera, layoutWidth: 402.0, screenWidth: 402.0)
        XCTAssertEqual(editor.width, 402.0)
        XCTAssertEqual(editor.height, floor(402.0 * 1.77778 * UIScreen.main.scale) / UIScreen.main.scale)

        let landscapeChat = mediaPickerCameraCellPreviewSize(branch: .chatCamera, layoutWidth: 874.0, screenWidth: 402.0)
        XCTAssertEqual(landscapeChat.width, 402.0)
        XCTAssertEqual(landscapeChat.height, 536.0)
    }
}
