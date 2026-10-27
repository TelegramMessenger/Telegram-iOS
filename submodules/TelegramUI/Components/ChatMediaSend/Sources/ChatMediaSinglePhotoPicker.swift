import Foundation
import UIKit
import Photos
import SwiftSignalKit
import MediaAssetsContext

public enum ChatMediaSinglePhotoPurpose {
    case wallpaper
    case addImage
    case qrCode
}

public struct ChatMediaSinglePhotoPickerPolicy: Equatable {
    public let photoOnly: Bool
    public let selectionLimit: Int
    public let opensPreviewGallery: Bool

    public init(photoOnly: Bool, selectionLimit: Int, opensPreviewGallery: Bool) {
        self.photoOnly = photoOnly
        self.selectionLimit = selectionLimit
        self.opensPreviewGallery = opensPreviewGallery
    }
}

public func chatMediaSinglePhotoPickerPolicy(_ purpose: ChatMediaSinglePhotoPurpose) -> ChatMediaSinglePhotoPickerPolicy {
    switch purpose {
    case .wallpaper, .addImage, .qrCode:
        return ChatMediaSinglePhotoPickerPolicy(photoOnly: true, selectionLimit: 1, opensPreviewGallery: false)
    }
}

public let chatMediaQrPhotoImageSize = CGSize(width: 1280.0, height: 1280.0)

public func chatMediaQrPhotoImage(asset: PHAsset) -> Signal<UIImage?, NoError> {
    return assetFullImage(asset, targetSize: chatMediaQrPhotoImageSize, contentMode: .aspectFit)
    |> mapToSignal { result -> Signal<UIImage?, NoError> in
        switch result {
        case .progress:
            return .complete()
        case let .result(image):
            return .single(image)
        case .unavailable:
            return .single(nil)
        }
    }
    |> take(1)
}
