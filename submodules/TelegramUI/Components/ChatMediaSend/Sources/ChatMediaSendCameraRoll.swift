import Foundation
import UIKit
import Photos
import MediaEditor

public func chatMediaSendSavesEditedPhotos(saveEditedPhotos: Bool, isSecretChat: Bool, isPasteboard: Bool) -> Bool {
    return saveEditedPhotos && !isSecretChat && !isPasteboard
}

public func chatMediaSendItemIsCameraRollCandidate(_ item: ChatMediaSendItem) -> Bool {
    guard let values = item.values else {
        return false
    }
    switch item.source {
    case let .libraryAsset(_, _, isVideo, _):
        if isVideo {
            return false
        }
    case .image, .imageFile, .livePhoto:
        break
    case .tempVideo, .gifAsset, .prebuilt:
        return false
    }
    if values.entities.contains(where: { $0.entity.isAnimated }) {
        return false
    }
    let toolsApplied = values.hasAdjustments || values.hasTint || values.hasBlur || values.hasCurves
    let hasPainting = values.drawing != nil || !values.entities.isEmpty
    return toolsApplied || hasPainting
}

func chatMediaSendWriteCameraRollImage(_ image: UIImage) -> String? {
    guard let data = image.jpegData(compressionQuality: 0.7) else {
        return nil
    }
    let path = NSTemporaryDirectory() + "camera-roll-\(String(UInt64.random(in: 0 ... UInt64.max), radix: 16)).jpg"
    guard (try? data.write(to: URL(fileURLWithPath: path), options: .atomic)) != nil else {
        return nil
    }
    return path
}

public func chatMediaSendDiscardCameraRollImages(_ paths: [String]) {
    for path in paths {
        let _ = try? FileManager.default.removeItem(atPath: path)
    }
}

public func chatMediaSendSavePhotoToLibrary(url: URL, completion: @escaping () -> Void) {
    PHPhotoLibrary.shared().performChanges({
        let _ = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
    }, completionHandler: { _, _ in
        completion()
    })
}

public func chatMediaSendPhotoLibraryHasFullAccess() -> Bool {
    return PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized
}

public enum ChatMediaSendPhotoLibraryAccess: Equatable {
    case notDetermined
    case authorized
    case limited
    case denied
}

public func chatMediaSendCurrentPhotoLibraryAccess() -> ChatMediaSendPhotoLibraryAccess {
    switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
    case .notDetermined:
        return .notDetermined
    case .authorized:
        return .authorized
    case .limited:
        return .limited
    default:
        return .denied
    }
}

public func chatMediaSendRequestPhotoLibraryAccess(_ completion: @escaping () -> Void) {
    PHPhotoLibrary.requestAuthorization(for: .readWrite, handler: { _ in
        completion()
    })
}

public func chatMediaSendPreparePhotoLibraryAccess(hasMediaToSave: Bool, access: () -> ChatMediaSendPhotoLibraryAccess = chatMediaSendCurrentPhotoLibraryAccess, request: (@escaping () -> Void) -> Void = chatMediaSendRequestPhotoLibraryAccess, completion: @escaping () -> Void) {
    if hasMediaToSave && access() == .notDetermined {
        request(completion)
    } else {
        completion()
    }
}

public func chatMediaSendSaveToCameraRoll(paths: [String], isAuthorized: () -> Bool = chatMediaSendPhotoLibraryHasFullAccess, save: @escaping (URL, @escaping () -> Void) -> Void = chatMediaSendSavePhotoToLibrary, completion: @escaping () -> Void = {}) {
    if paths.isEmpty {
        completion()
        return
    }
    if !isAuthorized() {
        chatMediaSendDiscardCameraRollImages(paths)
        completion()
        return
    }
    chatMediaSendSaveToCameraRollSequentially(paths: paths, save: save, completion: completion)
}

private func chatMediaSendSaveToCameraRollSequentially(paths: [String], save: @escaping (URL, @escaping () -> Void) -> Void, completion: @escaping () -> Void) {
    guard let path = paths.first else {
        completion()
        return
    }
    let remaining = Array(paths.dropFirst())
    save(URL(fileURLWithPath: path), {
        chatMediaSendDiscardCameraRollImages([path])
        chatMediaSendSaveToCameraRollSequentially(paths: remaining, save: save, completion: completion)
    })
}

public func chatMediaSendSavesCapturedOriginal(saveCapturedMedia: Bool, isSecretChat: Bool, timer: Int32?) -> Bool {
    if let timer, timer != 0 {
        return false
    }
    return saveCapturedMedia && !isSecretChat
}

public enum ChatMediaSendCapturedOriginal: Equatable {
    case photo(URL)
    case video(URL)
}

public func chatMediaSendSaveCapturedOriginalToLibrary(_ original: ChatMediaSendCapturedOriginal, completion: @escaping () -> Void) {
    PHPhotoLibrary.shared().performChanges({
        switch original {
        case let .photo(url):
            let _ = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
        case let .video(url):
            let _ = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
    }, completionHandler: { _, _ in
        completion()
    })
}

public func chatMediaSendSaveCapturedOriginals(_ originals: [ChatMediaSendCapturedOriginal], isAuthorized: () -> Bool = chatMediaSendPhotoLibraryHasFullAccess, save: @escaping (ChatMediaSendCapturedOriginal, @escaping () -> Void) -> Void = chatMediaSendSaveCapturedOriginalToLibrary, completion: @escaping () -> Void = {}) {
    if originals.isEmpty || !isAuthorized() {
        completion()
        return
    }
    chatMediaSendSaveCapturedOriginalsSequentially(originals, save: save, completion: completion)
}

private func chatMediaSendSaveCapturedOriginalsSequentially(_ originals: [ChatMediaSendCapturedOriginal], save: @escaping (ChatMediaSendCapturedOriginal, @escaping () -> Void) -> Void, completion: @escaping () -> Void) {
    guard let original = originals.first else {
        completion()
        return
    }
    let remaining = Array(originals.dropFirst())
    save(original, {
        chatMediaSendSaveCapturedOriginalsSequentially(remaining, save: save, completion: completion)
    })
}
