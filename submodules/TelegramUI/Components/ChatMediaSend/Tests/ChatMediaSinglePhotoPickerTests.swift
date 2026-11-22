import Foundation
import UIKit
import XCTest
import ChatMediaSend

final class ChatMediaSinglePhotoPickerTests: XCTestCase {
    func testSinglePhotoPickerIsPhotoOnlySingleNoGallery() {
        let purposes: [ChatMediaSinglePhotoPurpose] = [.wallpaper, .addImage, .qrCode]
        for purpose in purposes {
            let policy = chatMediaSinglePhotoPickerPolicy(purpose)
            XCTAssertTrue(policy.photoOnly, "\(purpose)")
            XCTAssertEqual(policy.selectionLimit, 1, "\(purpose)")
            XCTAssertFalse(policy.opensPreviewGallery, "\(purpose)")
        }
    }

    func testQrImageSize() {
        XCTAssertEqual(chatMediaQrPhotoImageSize, CGSize(width: 1280.0, height: 1280.0))
    }
}
