import Foundation
import UIKit
import XCTest
import AccountContext

final class ChatMediaAvatarRoutingTests: XCTestCase {
    func testSuggestedSubjectPrefersVideo() {
        XCTAssertEqual(suggestedAvatarSubject(hasVideoRepresentation: true), .video)
        XCTAssertEqual(suggestedAvatarSubject(hasVideoRepresentation: false), .photo)
    }

    func testSuggestedVideoCoverFallsBackToThumbnail() {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let cover = UIGraphicsImageRenderer(size: CGSize(width: 2.0, height: 2.0), format: format).image { _ in }
        let thumbnail = UIGraphicsImageRenderer(size: CGSize(width: 4.0, height: 4.0), format: format).image { _ in }
        XCTAssertTrue(suggestedAvatarVideoCover(coverImage: cover, thumbnail: thumbnail) === cover)
        XCTAssertTrue(suggestedAvatarVideoCover(coverImage: nil, thumbnail: thumbnail) === thumbnail)
        XCTAssertNil(suggestedAvatarVideoCover(coverImage: nil, thumbnail: nil))
    }

    func testVideoChatAvatarCanDelete() {
        XCTAssertTrue(videoChatAvatarCanDelete(hasPhotos: true, fromGallery: false))
        XCTAssertFalse(videoChatAvatarCanDelete(hasPhotos: true, fromGallery: true))
        XCTAssertFalse(videoChatAvatarCanDelete(hasPhotos: false, fromGallery: false))
        XCTAssertFalse(videoChatAvatarCanDelete(hasPhotos: false, fromGallery: true))
    }

    func testUploadProgressMapping() {
        XCTAssertEqual(videoChatAvatarUploadProgress(.progress(0.0)), 0.0)
        XCTAssertEqual(videoChatAvatarUploadProgress(.progress(0.5)), 0.5)
        XCTAssertEqual(videoChatAvatarUploadProgress(.progress(1.0)), 1.0)
        XCTAssertNil(videoChatAvatarUploadProgress(.done))
    }

    func testSetPhotoOptionsDefaultKeepsUnsplitProgress() {
        XCTAssertFalse(SetPhotoOptions(forceDark: false, allowsEmojiAvatar: true).splitsVideoExportProgress)
        XCTAssertTrue(SetPhotoOptions(forceDark: true, allowsEmojiAvatar: false, splitsVideoExportProgress: true).splitsVideoExportProgress)
    }

    func testVideoProgressSplitsExportAndUpload() {
        XCTAssertEqual(avatarVideoSplitProgress(.export(0.0)), 0.0, accuracy: 0.0001)
        XCTAssertEqual(avatarVideoSplitProgress(.export(0.5)), 0.125, accuracy: 0.0001)
        XCTAssertEqual(avatarVideoSplitProgress(.export(1.0)), 0.25, accuracy: 0.0001)
        XCTAssertEqual(avatarVideoSplitProgress(.upload(0.0)), 0.25, accuracy: 0.0001)
        XCTAssertEqual(avatarVideoSplitProgress(.upload(0.5)), 0.625, accuracy: 0.0001)
        XCTAssertEqual(avatarVideoSplitProgress(.upload(1.0)), 1.0, accuracy: 0.0001)
    }
}
