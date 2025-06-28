import Foundation
import UIKit
import Postbox
import SSignalKit
import SwiftSignalKit
import TelegramCore
import LegacyComponents
import FFMpegBinding
import LocalMediaResources
import LegacyMediaPickerUI
import MediaEditor
import Photos

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

public func fetchVideoLibraryMediaResource(postbox: Postbox, resource: VideoLibraryMediaResource, alwaysUseModernPipeline: Bool = true) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    let signal = Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> { subscriber in
        subscriber.putNext(.reset)
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [resource.localIdentifier], options: nil)
        var requestId: PHImageRequestID?
        let disposable = MetaDisposable()
        if fetchResult.count != 0 {
            let asset = fetchResult.object(at: 0)
            
            let alreadyReceivedAsset = Atomic<Bool>(value: false)
            if asset.mediaType == .image {
                Logger.shared.log("FetchVideoResource", "Getting asset image \(asset.localIdentifier)")
                
                let options = PHImageRequestOptions()
                options.isNetworkAccessAllowed = true
                options.deliveryMode = .highQualityFormat
                requestId = PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: options, resultHandler: { image, _ in
                    if alreadyReceivedAsset.swap(true) {
                        return
                    }
                    guard let image else {
                        return
                    }
                    
                    Logger.shared.log("FetchVideoResource", "Got asset image \(asset.localIdentifier)")
                    
                    var mediaEditorValues: MediaEditorValues?
                    if case let .compress(adjustmentsValue) = resource.conversion, let adjustmentsValue, adjustmentsValue.isStory {
                        if let values = try? JSONDecoder().decode(MediaEditorValues.self, from: adjustmentsValue.data.makeData()) {
                            mediaEditorValues = values
                        }
                    } else {
                        fatalError()
                    }
                    let tempFile = EngineTempBox.shared.tempFile(fileName: "video.mp4")
                    let updatedSize = Atomic<Int64>(value: 0)
                    if let mediaEditorValues {
                        Logger.shared.log("FetchVideoResource", "Requesting video export")
                        
                        let configuration = recommendedVideoExportConfiguration(values: mediaEditorValues, duration: 5.0, image: true, frameRate: 30.0)
                        let videoExport = MediaEditorVideoExport(postbox: postbox, subject: .image(image: image), configuration: configuration, outputPath: tempFile.path)
                                                
                        let statusDisposable = videoExport.status.start(next: { status in
                            switch status {
                            case .completed:
                                var value = stat()
                                if stat(tempFile.path, &value) == 0 {
                                    let remuxedTempFile = TempBox.shared.tempFile(fileName: "video.mp4")
                                    if !"".isEmpty, let size = fileSize(tempFile.path), size <= 32 * 1024 * 1024, FFMpegRemuxer.remux(tempFile.path, to: remuxedTempFile.path) {
                                        TempBox.shared.dispose(tempFile)
                                        subscriber.putNext(.moveTempFile(file: remuxedTempFile))
                                    } else {
                                        TempBox.shared.dispose(remuxedTempFile)
                                        if let data = try? Data(contentsOf: URL(fileURLWithPath: tempFile.path), options: [.mappedRead]) {
                                            var range: Range<Int64>?
                                            let _ = updatedSize.modify { updatedSize in
                                                range = updatedSize ..< value.st_size
                                                return value.st_size
                                            }
                                            //print("finish size = \(Int(value.st_size)), range: \(range!)")
                                            subscriber.putNext(.dataPart(resourceOffset: range!.lowerBound, data: data, range: range!, complete: false))
                                            subscriber.putNext(.replaceHeader(data: data, range: 0 ..< 1024))
                                            subscriber.putNext(.dataPart(resourceOffset: Int64(data.count), data: Data(), range: 0 ..< 0, complete: true))
                                        }
                                    }
                                } else {
                                    subscriber.putError(.generic)
                                }
                                subscriber.putCompletion()
                                
                                EngineTempBox.shared.dispose(tempFile)
                            case .failed:
                                subscriber.putError(.generic)
                            case let .progress(progress):
                                subscriber.putNext(.progressUpdated(progress))
                            default:
                                break
                            }
                        })
                        
                        disposable.set(ActionDisposable {
                            statusDisposable.dispose()
                            videoExport.cancel()
                        })
                    }
                })
            } else {
                let options = PHVideoRequestOptions()
                options.isNetworkAccessAllowed = true
                options.deliveryMode = .highQualityFormat
//                let dimensions = PixelDimensions(width: Int32(asset.pixelWidth), height: Int32(asset.pixelHeight))
                requestId = PHImageManager.default().requestAVAsset(forVideo: asset, options: options, resultHandler: { avAsset, _, _ in
                    if alreadyReceivedAsset.swap(true) {
                        return
                    }
                    guard let avAsset else {
                        return
                    }
                    
                    var isStory = false
                    var adjustments: TGVideoEditAdjustments?
                    var mediaEditorValues: MediaEditorValues?
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
                        let defaultPreset = TGMediaVideoConversionPreset(rawValue: UInt32(UserDefaults.standard.integer(forKey: "TG_preferredVideoPreset_v0")))
                        let qualityPreset = MediaQualityPreset(preset: defaultPreset)
                        if let adjustmentsValue = adjustmentsValue {
                            if adjustmentsValue.isStory {
                                isStory = true
                                if let values = try? JSONDecoder().decode(MediaEditorValues.self, from: adjustmentsValue.data.makeData()) {
                                    mediaEditorValues = values
                                }
                            } else if let dict = legacy_unarchiveDeprecated(data: adjustmentsValue.data.makeData()) as? [AnyHashable : Any], let legacyAdjustments = TGVideoEditAdjustments(dictionary: dict) {
                                if alwaysUseModernPipeline {
                                    mediaEditorValues = MediaEditorValues(legacyAdjustments: legacyAdjustments, defaultPreset: qualityPreset)
                                } else {
                                    adjustments = legacyAdjustments
                                }
                            }
                        } else {
//                            if alwaysUseModernPipeline {
//                                mediaEditorValues = MediaEditorValues(dimensions: dimensions, qualityPreset: qualityPreset)
//                            }
                        }
                    }
                    let tempFile = EngineTempBox.shared.tempFile(fileName: "video.mp4")
                    let updatedSize = Atomic<Int64>(value: 0)
                    if let mediaEditorValues {
                        let duration: Double = avAsset.duration.seconds
                        let configuration = recommendedVideoExportConfiguration(values: mediaEditorValues, duration: duration, frameRate: 30.0)
                        let videoExport = MediaEditorVideoExport(postbox: postbox, subject: .video(asset: avAsset, isStory: isStory), configuration: configuration, outputPath: tempFile.path)
                        
                        let statusDisposable = videoExport.status.start(next: { status in
                            switch status {
                            case .completed:
                                var value = stat()
                                if stat(tempFile.path, &value) == 0 {
                                    let remuxedTempFile = TempBox.shared.tempFile(fileName: "video.mp4")
                                    if !"".isEmpty, let size = fileSize(tempFile.path), size <= 32 * 1024 * 1024, FFMpegRemuxer.remux(tempFile.path, to: remuxedTempFile.path) {
                                        TempBox.shared.dispose(tempFile)
                                        subscriber.putNext(.moveTempFile(file: remuxedTempFile))
                                    } else {
                                        TempBox.shared.dispose(remuxedTempFile)
                                        if let data = try? Data(contentsOf: URL(fileURLWithPath: tempFile.path), options: [.mappedRead]) {
                                            var range: Range<Int64>?
                                            let _ = updatedSize.modify { updatedSize in
                                                range = updatedSize ..< value.st_size
                                                return value.st_size
                                            }
                                            //print("finish size = \(Int(value.st_size)), range: \(range!)")
                                            subscriber.putNext(.dataPart(resourceOffset: range!.lowerBound, data: data, range: range!, complete: false))
                                            subscriber.putNext(.replaceHeader(data: data, range: 0 ..< 1024))
                                            subscriber.putNext(.dataPart(resourceOffset: Int64(data.count), data: Data(), range: 0 ..< 0, complete: true))
                                        }
                                    }
                                } else {
                                    subscriber.putError(.generic)
                                }
                                subscriber.putCompletion()
                                
                                EngineTempBox.shared.dispose(tempFile)
                            case .failed:
                                subscriber.putError(.generic)
                            case let .progress(progress):
                                subscriber.putNext(.progressUpdated(progress))
                            default:
                                break
                            }
                        })
                        
                        disposable.set(ActionDisposable {
                            statusDisposable.dispose()
                            videoExport.cancel()
                        })
                    } else {
                        let entityRenderer: LegacyPaintEntityRenderer? = adjustments.flatMap { adjustments in
                            if let paintingData = adjustments.paintingData, paintingData.hasAnimation {
                                return LegacyPaintEntityRenderer(postbox: postbox, adjustments: adjustments)
                            } else {
                                return nil
                            }
                        }
                        
                        let signal = TGMediaVideoConverter.convert(avAsset, adjustments: adjustments, path: tempFile.path, watcher: VideoConversionWatcher(update: { path, size in
                            /*var value = stat()
                             if stat(path, &value) == 0 {
                             let remuxedTempFile = TempBox.shared.tempFile(fileName: "video.mp4")
                             if FFMpegRemuxer.remux(path, to: remuxedTempFile.path) {
                             TempBox.shared.dispose(tempFile)
                             subscriber.putNext(.moveTempFile(file: remuxedTempFile))
                             } else {
                             TempBox.shared.dispose(remuxedTempFile)
                             if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedRead]) {
                             var range: Range<Int64>?
                             let _ = updatedSize.modify { updatedSize in
                             range = updatedSize ..< value.st_size
                             return value.st_size
                             }
                             //print("size = \(Int(value.st_size)), range: \(range!)")
                             subscriber.putNext(.dataPart(resourceOffset: range!.lowerBound, data: data, range: range!, complete: false))
                             }
                             }
                             }*/
                        }), entityRenderer: entityRenderer)!
                        let signalDisposable = signal.start(next: { next in
                            if let result = next as? TGMediaVideoConversionResult {
                                var value = stat()
                                if stat(result.fileURL.path, &value) == 0 {
                                    let remuxedTempFile = TempBox.shared.tempFile(fileName: "video.mp4")
                                    if !"".isEmpty, let size = fileSize(result.fileURL.path), size <= 32 * 1024 * 1024, FFMpegRemuxer.remux(result.fileURL.path, to: remuxedTempFile.path) {
                                        TempBox.shared.dispose(tempFile)
                                        subscriber.putNext(.moveTempFile(file: remuxedTempFile))
                                    } else {
                                        TempBox.shared.dispose(remuxedTempFile)
                                        if let data = try? Data(contentsOf: result.fileURL, options: [.mappedRead]) {
                                            var range: Range<Int64>?
                                            let _ = updatedSize.modify { updatedSize in
                                                range = updatedSize ..< value.st_size
                                                return value.st_size
                                            }
                                            //print("finish size = \(Int(value.st_size)), range: \(range!)")
                                            subscriber.putNext(.dataPart(resourceOffset: range!.lowerBound, data: data, range: range!, complete: false))
                                            subscriber.putNext(.replaceHeader(data: data, range: 0 ..< 1024))
                                            subscriber.putNext(.dataPart(resourceOffset: Int64(data.count), data: Data(), range: 0 ..< 0, complete: true))
                                        }
                                    }
                                } else {
                                    subscriber.putError(.generic)
                                }
                                subscriber.putCompletion()
                                
                                EngineTempBox.shared.dispose(tempFile)
                            }
                        }, error: { _ in
                            subscriber.putError(.generic)
                        }, completed: nil)
                        disposable.set(ActionDisposable {
                            signalDisposable?.dispose()
                        })
                    }
                })
            }
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

public func fetchLocalFileVideoMediaResource(postbox: Postbox, resource: LocalFileVideoMediaResource, alwaysUseModernPipeline: Bool = true) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    let signal = Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> { subscriber in
        subscriber.putNext(.reset)
        
        let filteredPaths = resource.paths.map { path in
            if path.hasPrefix("file://") {
                return path.replacingOccurrences(of: "file://", with: "")
            } else {
                return path
            }
        }
        let filteredPath = filteredPaths.first ?? ""
        
        let defaultPreset = TGMediaVideoConversionPreset(rawValue: UInt32(UserDefaults.standard.integer(forKey: "TG_preferredVideoPreset_v0")))
        let qualityPreset = MediaQualityPreset(preset: defaultPreset)
        
        let isImage = filteredPath.contains(".jpg")
        var isStory = false
        let avAsset: AVAsset?
        
        if isImage {
            avAsset = nil
        } else if filteredPaths.count > 1 {
            let composition = AVMutableComposition()
            var currentTime = CMTime.zero
            
            for path in filteredPaths {
                let asset = AVURLAsset(url: URL(fileURLWithPath: path))
                let duration = asset.duration
                do {
                    try composition.insertTimeRange(
                        CMTimeRangeMake(start: .zero, duration: duration),
                        of: asset,
                        at: currentTime
                    )
                    currentTime = CMTimeAdd(currentTime, duration)
                } catch {
                }
            }
            avAsset = composition
        } else {
            avAsset = AVURLAsset(url: URL(fileURLWithPath: filteredPath))
        }
        
        var adjustments: TGVideoEditAdjustments?
        var mediaEditorValues: MediaEditorValues?
        if let videoAdjustments = resource.adjustments {
            if videoAdjustments.isStory {
                isStory = true
                if let values = try? JSONDecoder().decode(MediaEditorValues.self, from: videoAdjustments.data.makeData()) {
                    mediaEditorValues = values
                }
            } else {
                if let values = try? JSONDecoder().decode(MediaEditorValues.self, from: videoAdjustments.data.makeData()) {
                    mediaEditorValues = values
                } else if let dict = legacy_unarchiveDeprecated(data: videoAdjustments.data.makeData()) as? [AnyHashable : Any], let legacyAdjustments = TGVideoEditAdjustments(dictionary: dict) {
                    if alwaysUseModernPipeline && !isImage {
                        mediaEditorValues = MediaEditorValues(legacyAdjustments: legacyAdjustments, defaultPreset: qualityPreset)
                    } else {
                        adjustments = legacyAdjustments
                    }
                }
            }
        }
        let tempFile = EngineTempBox.shared.tempFile(fileName: "video.mp4")
        let updatedSize = Atomic<Int64>(value: 0)
        if let mediaEditorValues {
            let duration: Double
            let subject: MediaEditorVideoExport.Subject
            if isImage, let data = try? Data(contentsOf: URL(fileURLWithPath: filteredPath), options: [.mappedRead]), let image = UIImage(data: data) {
                duration = 5.0
                subject = .image(image: image)
            } else if let avAsset {
                duration = avAsset.duration.seconds
                subject = .video(asset: avAsset, isStory: isStory)
            } else {
                return EmptyDisposable
            }
            
            let configuration = recommendedVideoExportConfiguration(values: mediaEditorValues, duration: duration, frameRate: 30.0)
            let videoExport = MediaEditorVideoExport(postbox: postbox, subject: subject, configuration: configuration, outputPath: tempFile.path)
            
            let statusDisposable = videoExport.status.start(next: { status in
                switch status {
                case .completed:
                    var value = stat()
                    if stat(tempFile.path, &value) == 0 {
                        let remuxedTempFile = TempBox.shared.tempFile(fileName: "video.mp4")
                        if !"".isEmpty, let size = fileSize(tempFile.path), size <= 32 * 1024 * 1024, FFMpegRemuxer.remux(tempFile.path, to: remuxedTempFile.path) {
                            TempBox.shared.dispose(tempFile)
                            subscriber.putNext(.moveTempFile(file: remuxedTempFile))
                        } else {
                            TempBox.shared.dispose(remuxedTempFile)
                            if let data = try? Data(contentsOf: URL(fileURLWithPath: tempFile.path), options: [.mappedRead]) {
                                var range: Range<Int64>?
                                let _ = updatedSize.modify { updatedSize in
                                    range = updatedSize ..< value.st_size
                                    return value.st_size
                                }
                                //print("finish size = \(Int(value.st_size)), range: \(range!)")
                                subscriber.putNext(.dataPart(resourceOffset: range!.lowerBound, data: data, range: range!, complete: false))
                                subscriber.putNext(.replaceHeader(data: data, range: 0 ..< 1024))
                                subscriber.putNext(.dataPart(resourceOffset: Int64(data.count), data: Data(), range: 0 ..< 0, complete: true))
                            }
                        }
                    } else {
                        subscriber.putError(.generic)
                    }
                    subscriber.putCompletion()
                    
                    EngineTempBox.shared.dispose(tempFile)
                case .failed:
                    subscriber.putError(.generic)
                case let .progress(progress):
                    subscriber.putNext(.progressUpdated(progress))
                default:
                    break
                }
            })
            
            let disposable = MetaDisposable()
            disposable.set(ActionDisposable {
                statusDisposable.dispose()
                videoExport.cancel()
            })
            
            return ActionDisposable {
                disposable.dispose()
            }
        } else {
            let entityRenderer: LegacyPaintEntityRenderer? = adjustments.flatMap { adjustments in
                if let paintingData = adjustments.paintingData, paintingData.hasAnimation {
                    return LegacyPaintEntityRenderer(postbox: postbox, adjustments: adjustments)
                } else {
                    return nil
                }
            }
            let signal: SSignal
            if isImage, let entityRenderer = entityRenderer {
                if let data = try? Data(contentsOf: URL(fileURLWithPath: filteredPath), options: [.mappedRead]), let image = UIImage(data: data) {
                    let durationSignal: SSignal = SSignal(generator: { subscriber in
                        let disposable = (entityRenderer.duration()).start(next: { duration in
                            subscriber.putNext(duration)
                            subscriber.putCompletion()
                        })
                        
                        return SBlockDisposable(block: {
                            disposable.dispose()
                        })
                    })
                    
                    signal = durationSignal.map(toSignal: { duration -> SSignal in
                        if let duration = duration as? Double {
                            return TGMediaVideoConverter.renderUIImage(image, duration: duration, adjustments: adjustments, path: tempFile.path, watcher: VideoConversionWatcher(update: { path, size in
                                var value = stat()
                                if stat(path, &value) == 0 {
                                    if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedRead]) {
                                        var range: Range<Int64>?
                                        let _ = updatedSize.modify { updatedSize in
                                            range = updatedSize ..< value.st_size
                                            return value.st_size
                                        }
                                        //print("size = \(Int(value.st_size)), range: \(range!)")
                                        subscriber.putNext(.dataPart(resourceOffset: range!.lowerBound, data: data, range: range!, complete: false))
                                    }
                                }
                            }), entityRenderer: entityRenderer)!
                        } else {
                            return SSignal.single(nil)
                        }
                    })
                } else {
                    signal = SSignal.single(nil)
                }
            } else {
                signal = TGMediaVideoConverter.convert(avAsset, adjustments: adjustments, path: tempFile.path, watcher: VideoConversionWatcher(update: { path, size in
                    var value = stat()
                    if stat(path, &value) == 0 {
                        if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedRead]) {
                            var range: Range<Int64>?
                            let _ = updatedSize.modify { updatedSize in
                                range = updatedSize ..< Int64(value.st_size)
                                return value.st_size
                            }
                            //print("size = \(Int(value.st_size)), range: \(range!)")
                            subscriber.putNext(.dataPart(resourceOffset: range!.lowerBound, data: data, range: range!, complete: false))
                        }
                    }
                }), entityRenderer: entityRenderer)!
            }
            
            let signalDisposable = signal.start(next: { next in
                if let result = next as? TGMediaVideoConversionResult {
                    var value = stat()
                    if stat(result.fileURL.path, &value) == 0 {
//                        if config.remuxToFMp4 {
//                            let tempFile = TempBox.shared.tempFile(fileName: "video.mp4")
//                            if FFMpegRemuxer.remux(result.fileURL.path, to: tempFile.path) {
//                                let _ = try? FileManager.default.removeItem(atPath: result.fileURL.path)
//                                subscriber.putNext(.moveTempFile(file: tempFile))
//                            } else {
//                                TempBox.shared.dispose(tempFile)
//                                subscriber.putNext(.moveLocalFile(path: result.fileURL.path))
//                            }
//                        } else {
//                            subscriber.putNext(.moveLocalFile(path: result.fileURL.path))
//                        }
                        if let data = try? Data(contentsOf: result.fileURL, options: [.mappedRead]) {
                            var range: Range<Int64>?
                            let _ = updatedSize.modify { updatedSize in
                                range = updatedSize ..< value.st_size
                                return value.st_size
                            }
                            //print("finish size = \(Int(value.st_size)), range: \(range!)")
                            subscriber.putNext(.dataPart(resourceOffset: range!.lowerBound, data: data, range: range!, complete: false))
                            subscriber.putNext(.replaceHeader(data: data, range: 0 ..< 1024))
                            subscriber.putNext(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: true))
                            
                            EngineTempBox.shared.dispose(tempFile)
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
    return throttlingContext.wrap(priority: .default, signal: signal)
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
                            if let dict = legacy_unarchiveDeprecated(data: adjustmentsValue.data.makeData()) as? [AnyHashable : Any], let legacyAdjustments = TGVideoEditAdjustments(dictionary: dict) {
                                adjustments = legacyAdjustments
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
                        #if DEBUG
                        if "".isEmpty {
                            subscriber.putNext(nil)
                        }
                        #endif
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

public func fetchLocalFileGifMediaResource(resource: LocalFileGifMediaResource) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return Signal { subscriber in
        subscriber.putNext(.reset)
        
        let disposable = MetaDisposable()
        if let data = try? Data(contentsOf: URL(fileURLWithPath: resource.path), options: Data.ReadingOptions.mappedIfSafe) {
            let signal = TGGifConverter.convertGif(toMp4: data)
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

private extension MediaQualityPreset {
    init(preset: TGMediaVideoConversionPreset) {
        var qualityPreset: MediaQualityPreset
        switch preset {
        case TGMediaVideoConversionPresetCompressedDefault:
            qualityPreset = .compressedDefault
        case TGMediaVideoConversionPresetCompressedVeryLow:
            qualityPreset = .compressedVeryLow
        case TGMediaVideoConversionPresetCompressedLow:
            qualityPreset = .compressedLow
        case TGMediaVideoConversionPresetCompressedMedium:
            qualityPreset = .compressedMedium
        case TGMediaVideoConversionPresetCompressedHigh:
            qualityPreset = .compressedHigh
        case TGMediaVideoConversionPresetCompressedVeryHigh:
            qualityPreset = .compressedVeryHigh
        case TGMediaVideoConversionPresetProfileLow:
            qualityPreset = .profileLow
        case TGMediaVideoConversionPresetProfile:
            qualityPreset = .profile
        case TGMediaVideoConversionPresetProfileHigh:
            qualityPreset = .profileHigh
        case TGMediaVideoConversionPresetProfileVeryHigh:
            qualityPreset = .profileVeryHigh
        case TGMediaVideoConversionPresetAnimation:
            qualityPreset = .animation
        case TGMediaVideoConversionPresetVideoMessage:
            qualityPreset = .videoMessage
        default:
            qualityPreset = .compressedMedium
        }
        self = qualityPreset
    }
}

private extension UIImage.Orientation {
    var cropOrientation: MediaCropOrientation {
        switch self {
        case .up:
            return .up
        case .down:
            return .down
        case .left:
            return .left
        case .right:
            return .right
        default:
            return .up
        }
    }
}

private extension MediaEditorValues {
    convenience init(dimensions: PixelDimensions, qualityPreset: MediaQualityPreset) {
        self.init(
            peerId: EnginePeer.Id(0),
            originalDimensions: dimensions,
            cropOffset: .zero,
            cropRect: nil,
            cropScale: 1.0,
            cropRotation: 0.0,
            cropMirroring: false,
            cropOrientation: nil,
            gradientColors: nil,
            videoTrimRange: nil,
            videoIsMuted: false,
            videoIsFullHd: true,
            videoIsMirrored: false,
            videoVolume: 1.0,
            additionalVideoPath: nil,
            additionalVideoIsDual: false,
            additionalVideoPosition: nil,
            additionalVideoScale: nil,
            additionalVideoRotation: nil,
            additionalVideoPositionChanges: [],
            additionalVideoTrimRange: nil,
            additionalVideoOffset: nil,
            additionalVideoVolume: nil,
            collage: [],
            nightTheme: false,
            drawing: nil,
            maskDrawing: nil,
            entities: [],
            toolValues: [:],
            audioTrack: nil,
            audioTrackTrimRange: nil,
            audioTrackOffset: nil,
            audioTrackVolume: nil,
            audioTrackSamples: nil,
            collageTrackSamples: nil,
            coverImageTimestamp: nil,
            coverDimensions: nil,
            qualityPreset: qualityPreset
        )
    }
    
    convenience init(legacyAdjustments: TGVideoEditAdjustments, defaultPreset: MediaQualityPreset) {
        var videoTrimRange: Range<Double>?
        if legacyAdjustments.trimStartValue > 0.0 || !legacyAdjustments.trimEndValue.isZero {
            videoTrimRange = legacyAdjustments.trimStartValue ..< legacyAdjustments.trimEndValue
        }
        
        var entities: [CodableDrawingEntity] = []
        var drawing: UIImage?
        
        if let paintingData = legacyAdjustments.paintingData {
            if let entitiesData = paintingData.entitiesData {
                entities = decodeCodableDrawingEntities(data: entitiesData)
                
                let hasAnimation = entities.first(where: { $0.entity.isAnimated }) != nil
                if !hasAnimation {
                    entities = []
                }
            }
            if let imagePath = paintingData.imagePath, let image = UIImage(contentsOfFile: imagePath) {
                drawing = image
            }
        }
                
        var toolValues: [EditorToolKey: Any] = [:]
        if let tools = legacyAdjustments.toolValues {
            for (key, value) in tools {
                if let floatValue = (value as? NSNumber)?.floatValue {
                    if key == AnyHashable("enhance") {
                        toolValues[.enhance] = floatValue / 100.0
                    }
                    if key == AnyHashable("exposure") {
                        toolValues[.brightness] = floatValue / 100.0
                    }
                    if key == AnyHashable("contrast") {
                        toolValues[.contrast] = floatValue / 100.0
                    }
                    if key == AnyHashable("saturation") {
                        toolValues[.saturation] = floatValue / 100.0
                    }
                    if key == AnyHashable("warmth") {
                        toolValues[.warmth] = floatValue / 100.0
                    }
                    if key == AnyHashable("fade") {
                        toolValues[.fade] = floatValue / 100.0
                    }
                    if key == AnyHashable("vignette") {
                        toolValues[.vignette] = floatValue / 100.0
                    }
                    if key == AnyHashable("grain") {
                        toolValues[.grain] = floatValue / 100.0
                    }
                    if key == AnyHashable("highlights") {
                        toolValues[.highlights] = floatValue / 100.0
                    }
                    if key == AnyHashable("shadows") {
                        toolValues[.shadows] = floatValue / 100.0
                    }
                }
            }
        }
        if let value = legacyAdjustments.tintValue() {
            let shadowsColor = value["shadowsColor"] as? UIColor
            let shadowsIntensity = (value["shadowsIntensity"] as? NSNumber)?.floatValue
            let highlightsColor = value["highlightsColor"] as? UIColor
            let highlightsIntensity = (value["highlightsIntensity"] as? NSNumber)?.floatValue
            
            if let shadowsColor, let shadowsIntensity, shadowsColor.alpha > 0.0 {
                let shadowsTintValue = TintValue(color: shadowsColor, intensity: shadowsIntensity / 100.0)
                toolValues[.shadowsTint] = shadowsTintValue
            }
            if let highlightsColor, let highlightsIntensity, highlightsColor.alpha > 0.0 {
                let highlightsTintValue = TintValue(color: highlightsColor, intensity: highlightsIntensity / 100.0)
                toolValues[.highlightsTint] = highlightsTintValue
            }
        }
        if let value = legacyAdjustments.curvesValue() {
            func readValue(_ key: String) -> CurvesValue.CurveValue? {
                if let values = value[key] as? [AnyHashable: Any] {
                    if let blacks = values["blacks"] as? NSNumber, let shadows = values["shadows"] as? NSNumber, let midtones = values["midtones"] as? NSNumber, let highlights = values["highlights"] as? NSNumber, let whites = values["whites"] as? NSNumber {
                        return CurvesValue.CurveValue(
                            blacks: blacks.floatValue / 100.0,
                            shadows: shadows.floatValue / 100.0,
                            midtones: midtones.floatValue / 100.0,
                            highlights: highlights.floatValue / 100.0,
                            whites: whites.floatValue / 100.0
                        )
                    }
                }
                return nil
            }
            if let all = readValue("luminance"), let red = readValue("red"), let green = readValue("green"), let blue = readValue("blue") {
                toolValues[.curves] = CurvesValue(
                    all: all,
                    red: red,
                    green: green,
                    blue: blue
                )
            }
        }
        
        var qualityPreset = MediaQualityPreset(preset: legacyAdjustments.preset)
        if qualityPreset == .compressedDefault {
            qualityPreset = defaultPreset
        }
        
        self.init(
            peerId: EnginePeer.Id(0),
            originalDimensions: PixelDimensions(legacyAdjustments.originalSize),
            cropOffset: .zero,
            cropRect: legacyAdjustments.cropRect,
            cropScale: 1.0,
            cropRotation: legacyAdjustments.cropRotation,
            cropMirroring: legacyAdjustments.cropMirrored,
            cropOrientation: legacyAdjustments.cropOrientation.cropOrientation,
            gradientColors: nil,
            videoTrimRange: videoTrimRange,
            videoIsMuted: legacyAdjustments.sendAsGif,
            videoIsFullHd: true,
            videoIsMirrored: false,
            videoVolume: 1.0,
            additionalVideoPath: nil,
            additionalVideoIsDual: false,
            additionalVideoPosition: nil,
            additionalVideoScale: nil,
            additionalVideoRotation: nil,
            additionalVideoPositionChanges: [],
            additionalVideoTrimRange: nil,
            additionalVideoOffset: nil,
            additionalVideoVolume: nil,
            collage: [],
            nightTheme: false,
            drawing: drawing,
            maskDrawing: nil,
            entities: entities,
            toolValues: toolValues,
            audioTrack: nil,
            audioTrackTrimRange: nil,
            audioTrackOffset: nil,
            audioTrackVolume: nil,
            audioTrackSamples: nil,
            collageTrackSamples: nil,
            coverImageTimestamp: nil,
            coverDimensions: nil,
            qualityPreset: qualityPreset
        )
    }
}
