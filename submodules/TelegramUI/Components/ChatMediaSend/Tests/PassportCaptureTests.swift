import Foundation
import UIKit
import XCTest
import AccountContext
import ChatMediaSend

final class PassportCaptureTests: XCTestCase {
    func testPassportIntentCameraParams() {
        let intents: [PassportCaptureIntent] = [.document, .multiple, .idCard, .selfie]
        for intent in intents {
            let params = passportChatCameraParams(intent: intent)
            XCTAssertTrue(params.allowPhoto, "\(intent)")
            XCTAssertFalse(params.allowVideo, "\(intent)")
            XCTAssertFalse(params.hasAudio, "\(intent)")
            XCTAssertFalse(params.saveCapturedMedia, "\(intent)")
            XCTAssertFalse(params.recognizedQRCode("https://t.me/telegram"), "\(intent)")
            XCTAssertEqual(params.isSingleShot, intent != .multiple, "\(intent)")
            XCTAssertEqual(params.maxCount, intent == .multiple ? 10 : 1, "\(intent)")
            XCTAssertTrue(params.fixesCameraPosition, "\(intent)")
        }

        let document = passportChatCameraParams(intent: .document)
        XCTAssertFalse(document.prefersFrontCamera)
        XCTAssertTrue(document.mirrorsFrontResult)
        XCTAssertNil(document.documentFrame)
        XCTAssertFalse(document.locksPortrait)

        let multiple = passportChatCameraParams(intent: .multiple)
        XCTAssertFalse(multiple.prefersFrontCamera)
        XCTAssertTrue(multiple.mirrorsFrontResult)
        XCTAssertNil(multiple.documentFrame)
        XCTAssertFalse(multiple.locksPortrait)

        let idCard = passportChatCameraParams(intent: .idCard)
        XCTAssertFalse(idCard.prefersFrontCamera)
        XCTAssertTrue(idCard.mirrorsFrontResult)
        XCTAssertEqual(idCard.documentFrame, .idCard)
        XCTAssertTrue(idCard.locksPortrait)

        let selfie = passportChatCameraParams(intent: .selfie)
        XCTAssertTrue(selfie.prefersFrontCamera)
        XCTAssertFalse(selfie.mirrorsFrontResult)
        XCTAssertNil(selfie.documentFrame)
        XCTAssertFalse(selfie.locksPortrait)
    }

    func testIdCardCropBand() {
        XCTAssertEqual(passportIdCardCropRect(imageSize: CGSize(width: 3000.0, height: 4000.0)), CGRect(x: 0.0, y: (4000.0 - 2112.0) / 2.0, width: 3000.0, height: 2112.0))
        XCTAssertEqual(passportIdCardCropRect(imageSize: CGSize(width: 1080.0, height: 1440.0)), CGRect(x: 0.0, y: floor((1440.0 - 760.32) / 2.0), width: 1080.0, height: 760.32))
    }

    func testPassportOutputFits2048() {
        XCTAssertEqual(passportOutputImageSize(CGSize(width: 4032.0, height: 3024.0)), CGSize(width: 2048.0, height: 1536.0))
        XCTAssertEqual(passportOutputImageSize(CGSize(width: 3024.0, height: 4032.0)), CGSize(width: 1536.0, height: 2048.0))
        XCTAssertEqual(passportOutputImageSize(CGSize(width: 1000.0, height: 800.0)), CGSize(width: 1000.0, height: 800.0))
        XCTAssertEqual(passportOutputImageSize(CGSize(width: 2048.0, height: 2048.0)), CGSize(width: 2048.0, height: 2048.0))
        XCTAssertEqual(passportImageCompressionQuality, 0.84)
    }

    func testChatCameraParamsDefaultsUnchanged() {
        let params = ChatCameraParams(allowPhoto: true, allowVideo: true, isSingleShot: false, hasAudio: true, saveCapturedMedia: true, recognizedQRCode: { _ in
            return true
        })
        XCTAssertFalse(params.prefersFrontCamera)
        XCTAssertTrue(params.mirrorsFrontResult)
        XCTAssertNil(params.documentFrame)
        XCTAssertFalse(params.locksPortrait)
        XCTAssertFalse(params.fixesCameraPosition)
        XCTAssertEqual(params.maxCount, 100)
    }

    func testPassportAssetImageTargetSize() {
        XCTAssertEqual(passportAssetImageTargetSize, CGSize(width: 2048.0, height: 2048.0))
    }

    func testPassportFittedImage() {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let large = UIGraphicsImageRenderer(size: CGSize(width: 4032.0, height: 3024.0), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0.0, y: 0.0, width: 4032.0, height: 3024.0))
        }
        let fitted = passportFittedImage(large)
        XCTAssertEqual(fitted.size, CGSize(width: 2048.0, height: 1536.0))
        XCTAssertEqual(fitted.scale, 1.0)

        let small = UIGraphicsImageRenderer(size: CGSize(width: 1000.0, height: 800.0), format: format).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0.0, y: 0.0, width: 1000.0, height: 800.0))
        }
        XCTAssertTrue(passportFittedImage(small) === small)

        let rotated = UIImage(cgImage: small.cgImage!, scale: 1.0, orientation: .right)
        let upright = passportFittedImage(rotated)
        XCTAssertEqual(upright.imageOrientation, .up)
        XCTAssertEqual(upright.size, CGSize(width: 800.0, height: 1000.0))

        let retina = UIImage(cgImage: large.cgImage!, scale: 3.0, orientation: .up)
        let retinaFitted = passportFittedImage(retina)
        XCTAssertEqual(retinaFitted.scale, 1.0)
        XCTAssertEqual(retinaFitted.size, CGSize(width: 2048.0, height: 1536.0))
    }
}
