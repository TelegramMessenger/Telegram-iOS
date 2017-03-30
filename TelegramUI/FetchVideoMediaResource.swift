import Foundation
import Postbox
import SwiftSignalKit
import TelegramLegacyComponents

private final class VideoConversionWatcher: TGMediaVideoFileWatcher {
    private let update: (String, Int) -> Void
    private var path: String?
    
    init(update: @escaping (String, Int) -> Void) {
        self.update = update
        
        super.init()
    }
    
    override func setup(withFileURL fileURL: URL!) {
        self.path = fileURL?.path
        super.setup(withFileURL: fileURL)
    }
    
    override func fileUpdated(_ completed: Bool) -> Any! {
        if let path = self.path {
            var value = stat()
            if stat(path, &value) == 0 {
                self.update(path, Int(value.st_size))
            }
        }
        
        return super.fileUpdated(completed)
    }
}

func fetchVideoLibraryMediaResource(resource: VideoLibraryMediaResource) -> Signal<MediaResourceDataFetchResult, NoError> {
    return Signal { subscriber in
        subscriber.putNext(.reset)
        
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [resource.localIdentifier], options: nil)
        var requestId: PHImageRequestID?
        let disposable = MetaDisposable()
        if fetchResult.count != 0 {
            let asset = fetchResult.object(at: 0)
            let option = PHVideoRequestOptions()
            option.deliveryMode = .highQualityFormat
            
            let alreadyReceivedAsset = Atomic<Bool>(value: false)
            requestId = PHImageManager.default().requestAVAsset(forVideo: asset, options: option, resultHandler: { avAsset, _, _ in
                if alreadyReceivedAsset.swap(true) {
                    return
                }
                
                var adjustments: TGVideoEditAdjustments?
                if let videoAdjustments = resource.adjustments {
                    if let dict = NSKeyedUnarchiver.unarchiveObject(with: videoAdjustments.data.makeData()) as? [AnyHashable : Any] {
                        adjustments = TGVideoEditAdjustments(dictionary: dict)
                    }
                }
                let updatedSize = Atomic<Int>(value: 0)
                let signal = TGMediaVideoConverter.convert(avAsset, adjustments: adjustments, watcher: VideoConversionWatcher(update: { path, size in
                    var value = stat()
                    if stat(path, &value) == 0 {
                        if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedRead]) {
                            var range: Range<Int>?
                            let _ = updatedSize.modify { updatedSize in
                                range = updatedSize ..< Int(value.st_size)
                                return Int(value.st_size)
                            }
                            //print("size = \(Int(value.st_size)), range: \(range!)")
                            subscriber.putNext(.dataPart(data: data, range: range!, complete: false))
                        }
                    }
                }))!
                let signalDisposable = signal.start(next: { next in
                    if let result = next as? TGMediaVideoConversionResult {
                        var value = stat()
                        if stat(result.fileURL.path, &value) == 0 {
                            if let data = try? Data(contentsOf: result.fileURL, options: [.mappedRead]) {
                                var range: Range<Int>?
                                let _ = updatedSize.modify { updatedSize in
                                    range = updatedSize ..< Int(value.st_size)
                                    return Int(value.st_size)
                                }
                                //print("finish size = \(Int(value.st_size)), range: \(range!)")
                                subscriber.putNext(.dataPart(data: data, range: range!, complete: false))
                                subscriber.putNext(.replaceHeader(data: data, range: 0 ..< 1024))
                                subscriber.putNext(.dataPart(data: Data(), range: 0 ..< 0, complete: true))
                            }
                        }
                        subscriber.putCompletion()
                    }
                }, error: { _ in
                }, completed: nil)
                disposable.set(ActionDisposable {
                    signalDisposable?.dispose()
                })
            })
        }
        
        return ActionDisposable {
            if let requestId = requestId {
                PHImageManager.default().cancelImageRequest(requestId)
            }
            disposable.dispose()
        }
    }
}

func fetchLocalFileVideoMediaResource(resource: LocalFileVideoMediaResource) -> Signal<MediaResourceDataFetchResult, NoError> {
    return Signal { subscriber in
        subscriber.putNext(.reset)
        
        let avAsset = AVURLAsset(url: URL(fileURLWithPath: resource.path))
        var adjustments: TGVideoEditAdjustments?
        if let videoAdjustments = resource.adjustments {
            if let dict = NSKeyedUnarchiver.unarchiveObject(with: videoAdjustments.data.makeData()) as? [AnyHashable : Any] {
                adjustments = TGVideoEditAdjustments(dictionary: dict)
            }
        }
        let updatedSize = Atomic<Int>(value: 0)
        let signal = TGMediaVideoConverter.convert(avAsset, adjustments: adjustments, watcher: VideoConversionWatcher(update: { path, size in
            var value = stat()
            if stat(path, &value) == 0 {
                if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedRead]) {
                    var range: Range<Int>?
                    let _ = updatedSize.modify { updatedSize in
                        range = updatedSize ..< Int(value.st_size)
                        return Int(value.st_size)
                    }
                    //print("size = \(Int(value.st_size)), range: \(range!)")
                    subscriber.putNext(.dataPart(data: data, range: range!, complete: false))
                }
            }
        }))!
        let signalDisposable = signal.start(next: { next in
            if let result = next as? TGMediaVideoConversionResult {
                var value = stat()
                if stat(result.fileURL.path, &value) == 0 {
                    if let data = try? Data(contentsOf: result.fileURL, options: [.mappedRead]) {
                        var range: Range<Int>?
                        let _ = updatedSize.modify { updatedSize in
                            range = updatedSize ..< Int(value.st_size)
                            return Int(value.st_size)
                        }
                        //print("finish size = \(Int(value.st_size)), range: \(range!)")
                        subscriber.putNext(.dataPart(data: data, range: range!, complete: false))
                        subscriber.putNext(.replaceHeader(data: data, range: 0 ..< 1024))
                        subscriber.putNext(.dataPart(data: Data(), range: 0 ..< 0, complete: true))
                    }
                }
                subscriber.putCompletion()
            }
        }, error: { _ in
        }, completed: nil)
        
        let disposable = ActionDisposable {
            signalDisposable?.dispose()
        }
        
        return ActionDisposable {
            disposable.dispose()
        }
    }
}
