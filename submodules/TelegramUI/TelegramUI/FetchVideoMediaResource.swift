import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import TelegramCore
import SyncCore
import LegacyComponents
import FFMpeg
import LocalMediaResources

private final class AVURLAssetCopyItem: MediaResourceDataFetchCopyLocalItem {
    private let url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    func copyTo(url: URL) -> Bool {
        var success = true
        do {
            try FileManager.default.copyItem(at: self.url, to: url)
        } catch {
            success = false
        }
        return success
    }
}

class VideoConversionWatcher: TGMediaVideoFileWatcher {
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

struct VideoConversionConfiguration {
    static var defaultValue: VideoConversionConfiguration {
        return VideoConversionConfiguration(remuxToFMp4: false)
    }
    
    public let remuxToFMp4: Bool
    
    fileprivate init(remuxToFMp4: Bool) {
        self.remuxToFMp4 = remuxToFMp4
    }
    
    static func with(appConfiguration: AppConfiguration) -> VideoConversionConfiguration {
        if let data = appConfiguration.data, let conversion = data["video_conversion"] as? [String: Any] {
            let remuxToFMp4 = conversion["remux_fmp4"] as? Bool ?? VideoConversionConfiguration.defaultValue.remuxToFMp4
            return VideoConversionConfiguration(remuxToFMp4: remuxToFMp4)
        } else {
            return .defaultValue
        }
    }
}

private final class FetchVideoLibraryMediaResourceItem {
    let priority: MediaBoxFetchPriority
    let signal: Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError>
    let next: (MediaResourceDataFetchResult) -> Void
    let error: (MediaResourceDataFetchError) -> Void
    let completion: () -> Void
    var isActive: Bool = false
    var disposable: Disposable?
    
    init(priority: MediaBoxFetchPriority, signal: Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError>, next: @escaping (MediaResourceDataFetchResult) -> Void, error: @escaping (MediaResourceDataFetchError) -> Void, completion: @escaping () -> Void) {
        self.priority = priority
        self.signal = signal
        self.next = next
        self.error = error
        self.completion = completion
    }
    
    deinit {
        self.disposable?.dispose()
    }
}

private let fetchVideoLimit: Int = 2

private final class FetchVideoLibraryMediaResourceContextImpl {
    private let queue: Queue
    var items: [FetchVideoLibraryMediaResourceItem] = []
    
    init(queue: Queue) {
        self.queue = queue
    }
    
    func add(priority: MediaBoxFetchPriority, signal: Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError>, next: @escaping (MediaResourceDataFetchResult) -> Void, error: @escaping (MediaResourceDataFetchError) -> Void, completion: @escaping () -> Void) -> Disposable {
        let queue = self.queue
        
        let item = FetchVideoLibraryMediaResourceItem(priority: priority, signal: signal, next: next, error: error, completion: completion)
        self.items.append(item)
        
        self.update()
        
        return ActionDisposable { [weak self, weak item] in
            queue.async {
                guard let strongSelf = self, let item = item else {
                    return
                }
                for i in 0 ..< strongSelf.items.count {
                    if strongSelf.items[i] === item {
                        strongSelf.items[i].disposable?.dispose()
                        strongSelf.items.remove(at: i)
                        strongSelf.update()
                        break
                    }
                }
            }
        }
    }
    
    func update() {
        let queue = self.queue
        
        var activeCount = 0
        for item in self.items {
            if item.isActive {
                activeCount += 1
            }
        }
        
        while activeCount < fetchVideoLimit {
            var maxPriorityIndex: Int?
            for i in 0 ..< self.items.count {
                if !self.items[i].isActive {
                    if let maxPriorityIndexValue = maxPriorityIndex {
                        if self.items[i].priority.rawValue > self.items[maxPriorityIndexValue].priority.rawValue {
                            maxPriorityIndex = i
                        }
                    } else {
                        maxPriorityIndex = i
                    }
                }
            }
            if let maxPriorityIndex = maxPriorityIndex {
                let item = self.items[maxPriorityIndex]
                item.isActive = true
                activeCount += 1
                assert(item.disposable == nil)
                item.disposable = self.items[maxPriorityIndex].signal.start(next: { [weak item] value in
                    queue.async {
                        item?.next(value)
                    }
                }, error: { [weak self, weak item] value in
                    queue.async {
                        guard let strongSelf = self, let item = item else {
                            return
                        }
                        for i in 0 ..< strongSelf.items.count {
                            if strongSelf.items[i] === item {
                                strongSelf.items.remove(at: i)
                                item.error(value)
                                strongSelf.update()
                                break
                            }
                        }
                    }
                }, completed: { [weak self, weak item] in
                    queue.async {
                        guard let strongSelf = self, let item = item else {
                            return
                        }
                        for i in 0 ..< strongSelf.items.count {
                            if strongSelf.items[i] === item {
                                strongSelf.items.remove(at: i)
                                item.completion()
                                strongSelf.update()
                                break
                            }
                        }
                    }
                })
            } else {
                break
            }
        }
    }
}

private final class FetchVideoLibraryMediaResourceContext {
    private let queue = Queue()
    private let impl: QueueLocalObject<FetchVideoLibraryMediaResourceContextImpl>
    
    init() {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return FetchVideoLibraryMediaResourceContextImpl(queue: queue)
        })
    }
    
    func wrap(priority: MediaBoxFetchPriority, signal: Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError>) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.add(priority: priority, signal: signal, next: { value in
                    subscriber.putNext(value)
                }, error: { error in
                    subscriber.putError(error)
                }, completion: {
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }
}

private let throttlingContext = FetchVideoLibraryMediaResourceContext()

public func fetchVideoLibraryMediaResource(postbox: Postbox, resource: VideoLibraryMediaResource) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return postbox.preferencesView(keys: [PreferencesKeys.appConfiguration])
    |> take(1)
    |> map { view in
        return view.values[PreferencesKeys.appConfiguration] as? AppConfiguration ?? .defaultValue
    }
    |> castError(MediaResourceDataFetchError.self)
    |> mapToSignal { appConfiguration -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> in
        let config = VideoConversionConfiguration.with(appConfiguration: appConfiguration)
        let signal = Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> { subscriber in
            subscriber.putNext(.reset)
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [resource.localIdentifier], options: nil)
            var requestId: PHImageRequestID?
            let disposable = MetaDisposable()
            if fetchResult.count != 0 {
                let asset = fetchResult.object(at: 0)
                let option = PHVideoRequestOptions()
                option.isNetworkAccessAllowed = true
                option.deliveryMode = .highQualityFormat
                
                let alreadyReceivedAsset = Atomic<Bool>(value: false)
                requestId = PHImageManager.default().requestAVAsset(forVideo: asset, options: option, resultHandler: { avAsset, _, _ in
                    if avAsset == nil {
                        return
                    }
                    
                    if alreadyReceivedAsset.swap(true) {
                        return
                    }
                    
                    var adjustments: TGVideoEditAdjustments?
                    switch resource.conversion {
                        case .passthrough:
                            if let asset = avAsset as? AVURLAsset {
                                var value = stat()
                                if stat(asset.url.path, &value) == 0 {
                                    subscriber.putNext(.copyLocalItem(AVURLAssetCopyItem(url: asset.url)))
                                    subscriber.putCompletion()
                                } else {
                                    subscriber.putError(.generic)
                                }
                                return
                            } else {
                                adjustments = nil
                            }
                        case let .compress(adjustmentsValue):
                            if let adjustmentsValue = adjustmentsValue {
                                if let dict = NSKeyedUnarchiver.unarchiveObject(with: adjustmentsValue.data.makeData()) as? [AnyHashable : Any] {
                                    adjustments = TGVideoEditAdjustments(dictionary: dict)
                                }
                            }
                    }
                    let updatedSize = Atomic<Int>(value: 0)
                    let signal = TGMediaVideoConverter.convert(avAsset, adjustments: adjustments, watcher: VideoConversionWatcher(update: { path, size in
                        var value = stat()
                        if stat(path, &value) == 0 {
                            /*if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedRead]) {
                                var range: Range<Int>?
                                let _ = updatedSize.modify { updatedSize in
                                    range = updatedSize ..< Int(value.st_size)
                                    return Int(value.st_size)
                                }
                                //print("size = \(Int(value.st_size)), range: \(range!)")
                                subscriber.putNext(.dataPart(resourceOffset: range!.lowerBound, data: data, range: range!, complete: false))
                            }*/
                        }
                    }))!
                    let signalDisposable = signal.start(next: { next in
                        if let result = next as? TGMediaVideoConversionResult {
                            var value = stat()
                            if stat(result.fileURL.path, &value) == 0 {
                                if config.remuxToFMp4 {
                                    let tempFile = TempBox.shared.tempFile(fileName: "video.mp4")
                                    if FFMpegRemuxer.remux(result.fileURL.path, to: tempFile.path) {
                                        let _ = try? FileManager.default.removeItem(atPath: result.fileURL.path)
                                        subscriber.putNext(.moveTempFile(file: tempFile))
                                    } else {
                                        TempBox.shared.dispose(tempFile)
                                        subscriber.putNext(.moveLocalFile(path: result.fileURL.path))
                                    }
                                } else {
                                    subscriber.putNext(.moveLocalFile(path: result.fileURL.path))
                                }
                                /*if let data = try? Data(contentsOf: result.fileURL, options: [.mappedRead]) {
                                    var range: Range<Int>?
                                    let _ = updatedSize.modify { updatedSize in
                                        range = updatedSize ..< Int(value.st_size)
                                        return Int(value.st_size)
                                    }
                                    //print("finish size = \(Int(value.st_size)), range: \(range!)")
                                    subscriber.putNext(.dataPart(resourceOffset: range!.lowerBound, data: data, range: range!, complete: false))
                                    subscriber.putNext(.replaceHeader(data: data, range: 0 ..< 1024))
                                    subscriber.putNext(.dataPart(resourceOffset: data.count, data: Data(), range: 0 ..< 0, complete: true))
                                }*/
                            } else {
                                subscriber.putError(.generic)
                            }
                            subscriber.putCompletion()
                        }
                    }, error: { _ in
                        subscriber.putError(.generic)
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
        return throttlingContext.wrap(priority: .default, signal: signal)
    }
}

func fetchLocalFileVideoMediaResource(postbox: Postbox, resource: LocalFileVideoMediaResource) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return postbox.preferencesView(keys: [PreferencesKeys.appConfiguration])
    |> take(1)
    |> map { view in
        return view.values[PreferencesKeys.appConfiguration] as? AppConfiguration ?? .defaultValue
    }
    |> castError(MediaResourceDataFetchError.self)
    |> mapToSignal { appConfiguration -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> in
        let config = VideoConversionConfiguration.with(appConfiguration: appConfiguration)
        let signal = Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> { subscriber in
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
                    /*if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedRead]) {
                        var range: Range<Int>?
                        let _ = updatedSize.modify { updatedSize in
                            range = updatedSize ..< Int(value.st_size)
                            return Int(value.st_size)
                        }
                        //print("size = \(Int(value.st_size)), range: \(range!)")
                        subscriber.putNext(.dataPart(resourceOffset: range!.lowerBound, data: data, range: range!, complete: false))
                    }*/
                }
            }))!
            let signalDisposable = signal.start(next: { next in
                if let result = next as? TGMediaVideoConversionResult {
                    var value = stat()
                    if stat(result.fileURL.path, &value) == 0 {
                        if config.remuxToFMp4 {
                            let tempFile = TempBox.shared.tempFile(fileName: "video.mp4")
                            if FFMpegRemuxer.remux(result.fileURL.path, to: tempFile.path) {
                                let _ = try? FileManager.default.removeItem(atPath: result.fileURL.path)
                                subscriber.putNext(.moveTempFile(file: tempFile))
                            } else {
                                TempBox.shared.dispose(tempFile)
                                subscriber.putNext(.moveLocalFile(path: result.fileURL.path))
                            }
                        } else {
                            subscriber.putNext(.moveLocalFile(path: result.fileURL.path))
                        }
                        /*if let data = try? Data(contentsOf: result.fileURL, options: [.mappedRead]) {
                            var range: Range<Int>?
                            let _ = updatedSize.modify { updatedSize in
                                range = updatedSize ..< Int(value.st_size)
                                return Int(value.st_size)
                            }
                            //print("finish size = \(Int(value.st_size)), range: \(range!)")
                            subscriber.putNext(.dataPart(resourceOffset: range!.lowerBound, data: data, range: range!, complete: false))
                            subscriber.putNext(.replaceHeader(data: data, range: 0 ..< 1024))
                            subscriber.putNext(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: true))
                        }*/
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
        return throttlingContext.wrap(priority: .default, signal: signal)
    }
}

public func fetchVideoLibraryMediaResourceHash(resource: VideoLibraryMediaResource) -> Signal<Data?, NoError> {
    return Signal { subscriber in
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [resource.localIdentifier], options: nil)
        var requestId: PHImageRequestID?
        let disposable = MetaDisposable()
        if fetchResult.count != 0 {
            let asset = fetchResult.object(at: 0)
            let option = PHVideoRequestOptions()
            option.isNetworkAccessAllowed = true
            option.deliveryMode = .highQualityFormat
            
            let alreadyReceivedAsset = Atomic<Bool>(value: false)
            requestId = PHImageManager.default().requestAVAsset(forVideo: asset, options: option, resultHandler: { avAsset, _, info in
                if avAsset == nil {
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                    return
                }
                
                if alreadyReceivedAsset.swap(true) {
                    return
                }
                
                var adjustments: TGVideoEditAdjustments?
                var isPassthrough = false
                switch resource.conversion {
                    case .passthrough:
                        isPassthrough = true
                        adjustments = nil
                    case let .compress(adjustmentsValue):
                        if let adjustmentsValue = adjustmentsValue {
                            if let dict = NSKeyedUnarchiver.unarchiveObject(with: adjustmentsValue.data.makeData()) as? [AnyHashable : Any] {
                                adjustments = TGVideoEditAdjustments(dictionary: dict)
                            }
                        }
                }
                let signal = TGMediaVideoConverter.hash(for: avAsset, adjustments: adjustments)!
                let signalDisposable = signal.start(next: { next in
                    if let next = next as? String, let data = next.data(using: .utf8) {
                        var updatedData = data
                        if isPassthrough {
                            updatedData.reverse()
                        }
                        subscriber.putNext(updatedData)
                    } else {
                        subscriber.putNext(nil)
                    }
                    subscriber.putCompletion()
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

func fetchLocalFileGifMediaResource(resource: LocalFileGifMediaResource) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return Signal { subscriber in
        subscriber.putNext(.reset)
        
        let disposable = MetaDisposable()
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resource.path), options: Data.ReadingOptions.mappedIfSafe) {
            let updatedSize = Atomic<Int>(value: 0)
            let signal = TGGifConverter.convertGif(toMp4: data)!
            let signalDisposable = signal.start(next: { next in
                if let result = next as? NSDictionary, let path = result["path"] as? String {
                    var value = stat()
                    if stat(path, &value) == 0 {
                        subscriber.putNext(.moveLocalFile(path: path))
                        /*if let data = try? Data(contentsOf: result.fileURL, options: [.mappedRead]) {
                         var range: Range<Int>?
                         let _ = updatedSize.modify { updatedSize in
                         range = updatedSize ..< Int(value.st_size)
                         return Int(value.st_size)
                         }
                         //print("finish size = \(Int(value.st_size)), range: \(range!)")
                         subscriber.putNext(.dataPart(resourceOffset: range!.lowerBound, data: data, range: range!, complete: false))
                         subscriber.putNext(.replaceHeader(data: data, range: 0 ..< 1024))
                         subscriber.putNext(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: true))
                         }*/
                    }
                    subscriber.putCompletion()
                }
            }, error: { _ in
            }, completed: nil)
            
            disposable.set(ActionDisposable {
                signalDisposable?.dispose()
            })
        }
        
        return ActionDisposable {
            disposable.dispose()
        }
    }
}
