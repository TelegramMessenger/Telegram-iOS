import Foundation
import UIKit
import SwiftSignalKit
import Photos
import AVFoundation

class MediaAssetsContext: NSObject, PHPhotoLibraryChangeObserver {
    private var registeredChangeObserver = false
    private let changeSink = ValuePipe<PHChange>()
    private let mediaAccessSink = ValuePipe<PHAuthorizationStatus>()
    private let cameraAccessSink = ValuePipe<AVAuthorizationStatus?>()
    
    override init() {
        super.init()
        
        if PHPhotoLibrary.authorizationStatus() == .authorized {
            PHPhotoLibrary.shared().register(self)
            self.registeredChangeObserver = true
        }
    }
    
    deinit {
        if self.registeredChangeObserver {
            PHPhotoLibrary.shared().unregisterChangeObserver(self)
        }
    }
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        self.changeSink.putNext(changeInstance)
    }
    
    func fetchAssets(_ collection: PHAssetCollection) -> Signal<PHFetchResult<PHAsset>, NoError> {
        let initialFetchResult = PHAsset.fetchAssets(in: collection, options: nil)
        let fetchResult = Atomic<PHFetchResult<PHAsset>>(value: initialFetchResult)
        return .single(initialFetchResult)
        |> then(
            self.changeSink.signal()
            |> mapToSignal { change in
                if let updatedFetchResult = change.changeDetails(for: fetchResult.with { $0 })?.fetchResultAfterChanges {
                    let _ = fetchResult.modify { _ in return updatedFetchResult }
                    return .single(updatedFetchResult)
                } else {
                    return .complete()
                }
            }
        )
    }
    
    func fetchAssetsCollections(_ type: PHAssetCollectionType) -> Signal<PHFetchResult<PHAssetCollection>, NoError> {
        let initialFetchResult = PHAssetCollection.fetchAssetCollections(with: type, subtype: .any, options: nil)
        let fetchResult = Atomic<PHFetchResult<PHAssetCollection>>(value: initialFetchResult)
        return .single(initialFetchResult)
        |> then(
            self.changeSink.signal()
            |> mapToSignal { change in
                if let updatedFetchResult = change.changeDetails(for: fetchResult.with { $0 })?.fetchResultAfterChanges {
                    let _ = fetchResult.modify { _ in return updatedFetchResult }
                    return .single(updatedFetchResult)
                } else {
                    return .complete()
                }
            }
        )
    }
    
    func recentAssets() -> Signal<PHFetchResult<PHAsset>?, NoError> {
        let collections = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil)
        if let collection = collections.firstObject {
            return fetchAssets(collection)
            |> map(Optional.init)
        } else {
            return .single(nil)
        }
    }
        
    func mediaAccess() -> Signal<PHAuthorizationStatus, NoError> {
        let initialStatus: PHAuthorizationStatus
        if #available(iOS 14.0, *) {
            initialStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        } else {
            initialStatus = PHPhotoLibrary.authorizationStatus()
        }
        return .single(initialStatus)
        |> then(
            self.mediaAccessSink.signal()
        )
    }
    
    func requestMediaAccess() -> Void {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            self?.mediaAccessSink.putNext(status)
        }
    }
    
    func cameraAccess() -> Signal<AVAuthorizationStatus?, NoError> {
#if targetEnvironment(simulator)
        return .single(.authorized)
#else
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            return .single(AVCaptureDevice.authorizationStatus(for: .video))
            |> then(
                self.cameraAccessSink.signal()
            )
        } else {
            return .single(nil)
        }
#endif
    }
    
    func requestCameraAccess() -> Void {
        AVCaptureDevice.requestAccess(for: .video, completionHandler: { [weak self] result in
            if result {
                self?.cameraAccessSink.putNext(.authorized)
            } else {
                self?.cameraAccessSink.putNext(.denied)
            }
        })
    }
}
