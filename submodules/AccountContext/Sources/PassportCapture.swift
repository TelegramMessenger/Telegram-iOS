import Foundation
import UIKit

public enum ChatCameraDocumentFrame: Equatable {
    case idCard
}

public enum PassportCaptureIntent: Equatable {
    case document
    case multiple
    case idCard
    case selfie
}

public let passportImageCompressionQuality: CGFloat = 0.84
public let passportOutputMaxSide: CGFloat = 2048.0
public let passportIdCardBandRatio: CGFloat = 0.704
public let passportSelectionLimit: Int = 10

public func passportChatCameraParams(intent: PassportCaptureIntent) -> ChatCameraParams {
    return ChatCameraParams(
        allowPhoto: true,
        allowVideo: false,
        isSingleShot: intent != .multiple,
        maxCount: intent == .multiple ? passportSelectionLimit : 1,
        hasAudio: false,
        saveCapturedMedia: false,
        recognizedQRCode: { _ in
            return false
        },
        prefersFrontCamera: intent == .selfie,
        mirrorsFrontResult: intent != .selfie,
        documentFrame: intent == .idCard ? .idCard : nil,
        locksPortrait: intent == .idCard,
        fixesCameraPosition: true
    )
}

public func passportIdCardCropRect(imageSize: CGSize) -> CGRect {
    let height = imageSize.width * 704.0 / 1000.0
    return CGRect(x: 0.0, y: floor((imageSize.height - height) / 2.0), width: imageSize.width, height: height)
}

public func passportOutputImageSize(_ size: CGSize) -> CGSize {
    guard size.width > passportOutputMaxSide || size.height > passportOutputMaxSide else {
        return size
    }
    if size.width >= size.height {
        return CGSize(width: passportOutputMaxSide, height: floor(size.height * passportOutputMaxSide / size.width))
    } else {
        return CGSize(width: floor(size.width * passportOutputMaxSide / size.height), height: passportOutputMaxSide)
    }
}
