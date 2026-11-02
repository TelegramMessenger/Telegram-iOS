import Foundation
import UIKit
import Photos
import Metal
import ImageIO
import SwiftSignalKit
import TelegramCore
import AccountContext
import LegacyMediaPickerUI
import MediaEditor
import MediaAssetsContext

public enum ChatMediaSendRenderEvent {
    case progress(Float)
    case result(UIImage?)
}

public protocol ChatMediaSendRendering {
    func renderPhoto(item: ChatMediaSendItem, forceHd: Bool) -> Signal<ChatMediaSendRenderEvent, NoError>
    func exportAnimatedPhoto(item: ChatMediaSendItem) -> Signal<ChatMediaSendPreparedAnimatedPhoto?, NoError>
}

public extension ChatMediaSendRendering {
    func exportAnimatedPhoto(item: ChatMediaSendItem) -> Signal<ChatMediaSendPreparedAnimatedPhoto?, NoError> {
        return .single(nil)
    }
}

public final class ChatMediaSendDefaultRenderer: ChatMediaSendRendering {
    private let context: AccountContext

    public init(context: AccountContext) {
        self.context = context
    }

    public func renderPhoto(item: ChatMediaSendItem, forceHd: Bool) -> Signal<ChatMediaSendRenderEvent, NoError> {
        guard let values = item.values else {
            return .single(.result(nil))
        }
        let sourceImage: Signal<ChatMediaSendRenderEvent, NoError>
        switch item.source {
        case let .libraryAsset(identifier, _, isVideo, _):
            if isVideo {
                return .single(.result(nil))
            }
            sourceImage = chatMediaSendFullAssetImage(identifier: identifier)
        case let .livePhoto(identifier, _, _):
            sourceImage = chatMediaSendFullAssetImage(identifier: identifier)
        case let .image(image):
            sourceImage = .single(.result(image))
        case let .imageFile(path, _):
            sourceImage = chatMediaSendFileImage(path: path)
        case .tempVideo, .gifAsset, .prebuilt:
            return .single(.result(nil))
        }

        let maxOutputSide = chatMediaEditorImageMaxSide(forceHd: forceHd)
        return sourceImage
        |> deliverOnMainQueue
        |> mapToSignal { [self] event -> Signal<ChatMediaSendRenderEvent, NoError> in
            guard case let .result(image) = event else {
                return .single(event)
            }
            guard let image else {
                return .single(.result(nil))
            }
            return self.composedImage(image: image, values: values, maxOutputSide: maxOutputSide)
            |> map { result -> ChatMediaSendRenderEvent in
                return .result(result)
            }
        }
    }

    public func exportAnimatedPhoto(item: ChatMediaSendItem) -> Signal<ChatMediaSendPreparedAnimatedPhoto?, NoError> {
        guard let values = item.values, chatMediaSendItemIsAnimatedPhoto(item) else {
            return .single(nil)
        }
        let sourceImage: Signal<ChatMediaSendRenderEvent, NoError>
        switch item.source {
        case let .libraryAsset(identifier, _, _, _):
            sourceImage = chatMediaSendFullAssetImage(identifier: identifier)
        case let .image(image):
            sourceImage = .single(.result(image))
        case let .imageFile(path, _):
            sourceImage = chatMediaSendFileImage(path: path)
        case .tempVideo, .gifAsset, .livePhoto, .prebuilt:
            return .single(nil)
        }
        let maxOutputSide = chatMediaEditorImageMaxSide(forceHd: false)
        let base: Signal<(path: String, preview: UIImage)?, NoError> = chatMediaSendFirstResultImage(sourceImage)
        |> deliverOnMainQueue
        |> mapToSignal { [self] image -> Signal<(path: String, preview: UIImage)?, NoError> in
            guard let image else {
                return .single(nil)
            }
            return self.composedImage(image: image, values: values, maxOutputSide: maxOutputSide)
            |> chatMediaSendDeliverOnBackground
            |> map { preview -> (path: String, preview: UIImage)? in
                guard let preview, let path = chatMediaSendAnimatedPhotoBaseImagePath(image: image) else {
                    return nil
                }
                return (path, preview)
            }
        }
        let duration = mediaEditorAnimatedStickerDurations(accountContext: self.context, entities: values.entities)
        |> take(1)
        |> map { durations -> Double in
            return chatMediaSendAnimatedPhotoDuration(stickerDurations: durations)
        }
        return combineLatest(base, duration)
        |> take(1)
        |> map { base, duration -> ChatMediaSendPreparedAnimatedPhoto? in
            guard let base else {
                return nil
            }
            return ChatMediaSendPreparedAnimatedPhoto(path: base.path, duration: duration, preview: base.preview)
        }
    }

    private func composedImage(image: UIImage, values: MediaEditorValues, maxOutputSide: CGFloat) -> Signal<UIImage?, NoError> {
        let context = self.context
        return Signal { subscriber in
            let inputTexture = chatMediaSendStandaloneEditorImage(context: context, image: image, values: values)
            guard let inputTexture else {
                subscriber.putNext(nil)
                subscriber.putCompletion()
                return EmptyDisposable
            }
            makeChatEditorImageComposition(accountContext: context, input: .editorResult(inputTexture), values: values, time: .zero, maxOutputSide: maxOutputSide, completion: { result in
                subscriber.putNext(result)
                subscriber.putCompletion()
            })
            return EmptyDisposable
        }
    }
}

func chatMediaSendStandaloneEditorImage(context: AccountContext, image: UIImage, values: MediaEditorValues) -> MTLTexture? {
    let dimensions = PixelDimensions(width: Int32((image.size.width * image.scale).rounded()), height: Int32((image.size.height * image.scale).rounded()))
    let editor = MediaEditor(context: context, mode: .default, subject: .image(image, dimensions), values: values, isStandalone: true)
    editor.replaceSource(image, additionalImage: nil, time: .zero, mirror: false)
    let result = editor.resultTexture()
    editor.invalidate()
    return result
}

func chatMediaSendFileImage(path: String) -> Signal<ChatMediaSendRenderEvent, NoError> {
    return Signal { subscriber in
        subscriber.putNext(.result(UIImage(contentsOfFile: path)))
        subscriber.putCompletion()
        return EmptyDisposable
    }
    |> runOn(Queue.concurrentDefaultQueue())
}

func chatMediaSendScaledFileImage(path: String, maxPixelSide: CGFloat) -> UIImage? {
    guard maxPixelSide >= 1.0, let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else {
        return nil
    }
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceShouldCacheImmediately: true,
        kCGImageSourceThumbnailMaxPixelSize: Int(maxPixelSide.rounded(.up))
    ]
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
        return nil
    }
    return UIImage(cgImage: cgImage)
}

func chatMediaSendFullAssetImage(identifier: String) -> Signal<ChatMediaSendRenderEvent, NoError> {
    return Signal { subscriber in
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject else {
            subscriber.putNext(.result(nil))
            subscriber.putCompletion()
            return EmptyDisposable
        }
        var delivered = false
        return assetFullImage(asset).start(next: { result in
            switch result {
            case let .result(image):
                delivered = true
                subscriber.putNext(.result(image))
                subscriber.putCompletion()
            case .unavailable:
                delivered = true
                subscriber.putNext(.result(nil))
                subscriber.putCompletion()
            case let .progress(progress):
                if !delivered {
                    subscriber.putNext(.progress(progress))
                }
            }
        }, completed: {
            if !delivered {
                subscriber.putNext(.result(nil))
            }
            subscriber.putCompletion()
        })
    }
}

public struct ChatMediaSendOutcome {
    public var messages: [LegacyAssetPickerEnqueueMessage]
    public var droppedUniqueIds: [String]
    public var cameraRollImagePaths: [String]

    public init(messages: [LegacyAssetPickerEnqueueMessage], droppedUniqueIds: [String], cameraRollImagePaths: [String] = []) {
        self.messages = messages
        self.droppedUniqueIds = droppedUniqueIds
        self.cameraRollImagePaths = cameraRollImagePaths
    }
}

public enum ChatMediaSendEvent {
    case progress(Float)
    case outcome(ChatMediaSendOutcome)
}

let chatMediaSendMaxConcurrentRenders = 2

func chatMediaSendItemNeedsRender(_ item: ChatMediaSendItem) -> Bool {
    guard item.values != nil, item.renderedImage == nil, !chatMediaSendItemIsAnimatedPhoto(item) else {
        return false
    }
    switch item.source {
    case let .libraryAsset(_, _, isVideo, _):
        return !isVideo
    case .image, .imageFile:
        return true
    case .tempVideo, .gifAsset, .livePhoto, .prebuilt:
        return false
    }
}

private final class ChatMediaSendRenderPool {
    private let lock = NSLock()
    private let items: [ChatMediaSendItem]
    private let renderForceHd: (ChatMediaSendItem) -> Bool
    private let renderer: ChatMediaSendRendering
    private let maxConcurrent: Int
    private let prepare: (ChatMediaSendItem, UIImage) -> TelegramMediaImage?
    private let progress: (Float) -> Void
    private let completion: ([TelegramMediaImage?]) -> Void
    private let disposables = DisposableSet()
    private var isDisposed = false
    private var nextIndex = 0
    private var active = 0
    private var finished = 0
    private var results: [TelegramMediaImage?]
    private var fractions: [Float]

    init(items: [ChatMediaSendItem], renderForceHd: @escaping (ChatMediaSendItem) -> Bool, renderer: ChatMediaSendRendering, maxConcurrent: Int, prepare: @escaping (ChatMediaSendItem, UIImage) -> TelegramMediaImage?, progress: @escaping (Float) -> Void, completion: @escaping ([TelegramMediaImage?]) -> Void) {
        self.items = items
        self.renderForceHd = renderForceHd
        self.renderer = renderer
        self.maxConcurrent = maxConcurrent
        self.prepare = prepare
        self.progress = progress
        self.completion = completion
        self.results = Array(repeating: nil, count: items.count)
        self.fractions = Array(repeating: 0.0, count: items.count)
    }

    func start() {
        if self.items.isEmpty {
            self.completion([])
            return
        }
        self.pump()
    }

    func dispose() {
        self.lock.lock()
        self.isDisposed = true
        self.lock.unlock()
        self.disposables.dispose()
    }

    private func overallProgress() -> Float {
        return min(1.0, self.fractions.reduce(0.0, +) / Float(self.items.count))
    }

    private func update(index: Int, fraction: Float) {
        self.lock.lock()
        if self.isDisposed || self.fractions[index] >= 1.0 {
            self.lock.unlock()
            return
        }
        self.fractions[index] = max(self.fractions[index], min(fraction, 0.99))
        let value = self.overallProgress()
        self.lock.unlock()
        self.progress(value)
    }

    private func finish(index: Int, media: TelegramMediaImage?) {
        self.lock.lock()
        if self.isDisposed {
            self.lock.unlock()
            return
        }
        self.results[index] = media
        self.fractions[index] = 1.0
        self.active -= 1
        self.finished += 1
        let value = self.overallProgress()
        let results: [TelegramMediaImage?]? = self.finished == self.items.count ? self.results : nil
        self.lock.unlock()
        self.progress(results != nil ? 1.0 : value)
        if let results {
            self.completion(results)
        } else {
            self.pump()
        }
    }

    private func pump() {
        while true {
            self.lock.lock()
            guard !self.isDisposed, self.nextIndex < self.items.count, self.active < self.maxConcurrent else {
                self.lock.unlock()
                return
            }
            let index = self.nextIndex
            self.nextIndex += 1
            self.active += 1
            self.lock.unlock()

            let item = self.items[index]
            let prepare = self.prepare
            let isClaimed = Atomic<Bool>(value: false)
            self.disposables.add(self.renderer.renderPhoto(item: item, forceHd: self.renderForceHd(item)).start(next: { [self] event in
                let image: UIImage?
                switch event {
                case let .progress(fraction):
                    if !isClaimed.with({ $0 }) {
                        self.update(index: index, fraction: fraction)
                    }
                    return
                case let .result(result):
                    image = result
                }
                if isClaimed.swap(true) {
                    return
                }
                Queue.concurrentDefaultQueue().async {
                    let media = image.flatMap { prepare(item, $0) }
                    self.finish(index: index, media: media)
                }
            }, completed: { [self] in
                if isClaimed.swap(true) {
                    return
                }
                Queue.concurrentDefaultQueue().async {
                    self.finish(index: index, media: nil)
                }
            }))
        }
    }
}

func chatMediaSendItemHasUnencodableVideoValues(_ item: ChatMediaSendItem) -> Bool {
    guard let values = item.values else {
        return false
    }
    switch item.source {
    case let .libraryAsset(_, _, isVideo, _):
        return isVideo && chatMediaEditorVideoAdjustments(values: values) == nil
    case .tempVideo:
        return chatMediaEditorVideoAdjustments(values: values) == nil
    case .gifAsset, .livePhoto, .prebuilt:
        return false
    case .image, .imageFile:
        return false
    }
}

func chatMediaSendPreparedRenderedImage(item: ChatMediaSendItem, image: UIImage, forceHd: Bool, storeResourceData: (EngineMediaResource.Id, Data) -> Void) -> TelegramMediaImage? {
    let nominalDimensions: PixelDimensions
    if let values = item.values {
        nominalDimensions = chatMediaEditorCroppedNominalDimensions(values: values)
    } else {
        nominalDimensions = PixelDimensions(image.size)
    }
    return chatMediaSendRenderedImageMedia(image: image, nominalDimensions: nominalDimensions, thumbnail: image, stickerFiles: item.stickers, forceHd: forceHd, storeResourceData: storeResourceData)
}

func chatMediaSendMessages(items: [ChatMediaSendItem], global: ChatMediaSendGlobalOptions, renderer: ChatMediaSendRendering, gifConverter: ChatMediaSendGifConverting = ChatMediaSendGifConverter.shared, livePhotoPreparer: ChatMediaSendLivePhotoPreparing = ChatMediaSendLivePhotoPreparer.shared, makeGroupingKey: @escaping () -> Int64, storeResourceData: @escaping (EngineMediaResource.Id, Data) -> Void, buildMessages: @escaping ([ChatMediaSendItem], [ChatMediaSendPlannedItem], Bool, (EngineMediaResource.Id, Data) -> Void) -> (messages: [LegacyAssetPickerEnqueueMessage], skippedIndices: [Int]) = { items, plan, forceHd, storeResourceData in
    return chatMediaSendBuildMessagesReportingSkipped(items: items, plan: plan, forceHd: forceHd, storeResourceData: storeResourceData)
}) -> Signal<ChatMediaSendEvent, NoError> {
    var gifIndices: [Int] = []
    var liveIndices: [Int] = []
    var animatedIndices: [Int] = []
    for (index, item) in items.enumerated() {
        if chatMediaSendItemIsAnimatedPhoto(item), item.preparedAnimatedPhoto == nil {
            animatedIndices.append(index)
        }
        if case .gifAsset = item.source, item.convertedGif == nil {
            gifIndices.append(index)
        }
        if case .livePhoto = item.source, item.preparedLivePhoto == nil {
            liveIndices.append(index)
        }
    }
    if gifIndices.isEmpty && liveIndices.isEmpty && animatedIndices.isEmpty {
        return chatMediaSendRenderedMessages(items: items, global: global, renderer: renderer, makeGroupingKey: makeGroupingKey, storeResourceData: storeResourceData, buildMessages: buildMessages)
    }
    var items = items
    for index in liveIndices {
        items[index].rendersCameraRollStill = chatMediaSendItemSavesToCameraRoll(items[index], global: global)
    }
    let preparedItems = items
    let conversions: [Signal<ChatMediaSendConvertedGif?, NoError>] = gifIndices.map { index in
        guard case let .gifAsset(identifier, _) = items[index].source else {
            return .single(nil)
        }
        return gifConverter.convertGif(identifier: identifier)
        |> take(1)
    }
    let preparations: [Signal<ChatMediaSendPreparedLivePhoto?, NoError>] = liveIndices.map { index in
        return livePhotoPreparer.prepareLivePhoto(item: preparedItems[index], renderer: renderer)
        |> take(1)
    }
    let exports: [Signal<ChatMediaSendPreparedAnimatedPhoto?, NoError>] = animatedIndices.map { index in
        return renderer.exportAnimatedPhoto(item: items[index])
        |> take(1)
    }
    return combineLatest(chatMediaSendBoundedCombine(conversions, maxConcurrent: chatMediaSendMaxConcurrentRenders), chatMediaSendBoundedCombine(preparations, maxConcurrent: chatMediaSendMaxConcurrentRenders), chatMediaSendBoundedCombine(exports, maxConcurrent: chatMediaSendMaxConcurrentRenders))
    |> take(1)
    |> mapToSignal { results, preparedLivePhotos, preparedAnimatedPhotos -> Signal<ChatMediaSendEvent, NoError> in
        var updatedItems = preparedItems
        for (position, index) in gifIndices.enumerated() {
            updatedItems[index].convertedGif = results[position] ?? nil
        }
        var cameraRollPaths: [String: String] = [:]
        for (position, index) in liveIndices.enumerated() {
            updatedItems[index].preparedLivePhoto = preparedLivePhotos[position] ?? nil
            if updatedItems[index].rendersCameraRollStill, let prepared = preparedLivePhotos[position] ?? nil, let path = chatMediaSendWriteCameraRollImage(prepared.image) {
                cameraRollPaths[updatedItems[index].uniqueId] = path
            }
        }
        for (position, index) in animatedIndices.enumerated() {
            updatedItems[index].preparedAnimatedPhoto = preparedAnimatedPhotos[position] ?? nil
        }
        return chatMediaSendRenderedMessages(items: updatedItems, global: global, renderer: renderer, makeGroupingKey: makeGroupingKey, storeResourceData: storeResourceData, buildMessages: buildMessages, initialCameraRollPaths: cameraRollPaths)
    }
}

func chatMediaSendItemSavesToCameraRoll(_ item: ChatMediaSendItem, global: ChatMediaSendGlobalOptions) -> Bool {
    return global.saveEditedPhotosToCameraRoll && item.options.timer == nil && chatMediaSendItemIsCameraRollCandidate(item)
}

private func chatMediaSendRenderedMessages(items: [ChatMediaSendItem], global: ChatMediaSendGlobalOptions, renderer: ChatMediaSendRendering, makeGroupingKey: @escaping () -> Int64, storeResourceData: @escaping (EngineMediaResource.Id, Data) -> Void, buildMessages: @escaping ([ChatMediaSendItem], [ChatMediaSendPlannedItem], Bool, (EngineMediaResource.Id, Data) -> Void) -> (messages: [LegacyAssetPickerEnqueueMessage], skippedIndices: [Int]), initialCameraRollPaths: [String: String] = [:]) -> Signal<ChatMediaSendEvent, NoError> {
    return Signal { subscriber in
        let emitQueue = Queue()
        let lastProgress = Atomic<Float>(value: 0.0)
        var failed = Set<Int>()
        var renderIndices: [Int] = []
        for (index, item) in items.enumerated() {
            if case .prebuilt(.none) = item.source {
                failed.insert(index)
            } else if chatMediaSendItemHasUnencodableVideoValues(item) {
                failed.insert(index)
            } else if chatMediaSendItemNeedsRender(item) {
                renderIndices.append(index)
            }
        }

        let forceHd = global.forceHd
        let cameraRollPaths = Atomic<[String: String]>(value: initialCameraRollPaths)
        let cameraRollReleased = Atomic<Bool>(value: false)
        let isCameraRollCandidate: (ChatMediaSendItem) -> Bool = { item in
            return chatMediaSendItemSavesToCameraRoll(item, global: global)
        }
        let pool = ChatMediaSendRenderPool(items: renderIndices.map { items[$0] }, renderForceHd: { item in
            return (forceHd && item.options.allowsHd) || isCameraRollCandidate(item)
        }, renderer: renderer, maxConcurrent: chatMediaSendMaxConcurrentRenders, prepare: { item, image in
            if isCameraRollCandidate(item), let path = chatMediaSendWriteCameraRollImage(image) {
                let _ = cameraRollPaths.modify { current in
                    var current = current
                    current[item.uniqueId] = path
                    return current
                }
                if cameraRollReleased.with({ $0 }) {
                    chatMediaSendDiscardCameraRollImages([path])
                }
            }
            return chatMediaSendPreparedRenderedImage(item: item, image: image, forceHd: forceHd && item.options.allowsHd, storeResourceData: storeResourceData)
        }, progress: { value in
            emitQueue.async {
                if value > lastProgress.with({ $0 }) {
                    let _ = lastProgress.swap(value)
                    subscriber.putNext(.progress(value))
                }
            }
        }, completion: { preparedImages in
            Queue.concurrentDefaultQueue().async {
                var updatedItems = items
                var failed = failed
                for (position, index) in renderIndices.enumerated() {
                    if let preparedImage = preparedImages[position] {
                        updatedItems[index].preparedImage = preparedImage
                    } else {
                        failed.insert(index)
                    }
                }

                var survivorIndices: [Int] = []
                for index in 0 ..< updatedItems.count where !failed.contains(index) {
                    survivorIndices.append(index)
                }
                let survivors = survivorIndices.map { updatedItems[$0] }

                let plan = chatMediaSendPlan(items: survivors.map { $0.options }, global: global, makeGroupingKey: makeGroupingKey)
                let (messages, skippedIndices) = buildMessages(survivors, plan, forceHd, storeResourceData)
                for skippedIndex in skippedIndices {
                    failed.insert(survivorIndices[skippedIndex])
                }
                let droppedUniqueIds = (0 ..< updatedItems.count).filter { failed.contains($0) }.map { updatedItems[$0].uniqueId }

                let _ = cameraRollReleased.swap(true)
                var writtenCameraRollPaths = cameraRollPaths.swap([:])
                var keptCameraRollPaths: [String] = []
                let skipped = Set(skippedIndices)
                for planned in plan where planned.index >= 0 && planned.index < survivors.count {
                    let uniqueId = survivors[planned.index].uniqueId
                    guard let path = writtenCameraRollPaths[uniqueId] else {
                        continue
                    }
                    if !skipped.contains(planned.index) && !planned.isExcludedFromCameraRoll {
                        keptCameraRollPaths.append(path)
                        writtenCameraRollPaths.removeValue(forKey: uniqueId)
                    }
                }
                chatMediaSendDiscardCameraRollImages(Array(writtenCameraRollPaths.values))

                let outcome = ChatMediaSendOutcome(messages: messages, droppedUniqueIds: droppedUniqueIds, cameraRollImagePaths: keptCameraRollPaths)
                emitQueue.async {
                    subscriber.putNext(.outcome(outcome))
                    subscriber.putCompletion()
                }
            }
        })
        pool.start()
        return ActionDisposable {
            pool.dispose()
            if !cameraRollReleased.swap(true) {
                chatMediaSendDiscardCameraRollImages(Array(cameraRollPaths.swap([:]).values))
            }
        }
    }
}

public func chatMediaSendMessages(context: AccountContext, items: [ChatMediaSendItem], global: ChatMediaSendGlobalOptions, renderer: ChatMediaSendRendering) -> Signal<ChatMediaSendEvent, NoError> {
    let resources = context.engine.resources
    return chatMediaSendMessages(items: items, global: global, renderer: renderer, makeGroupingKey: {
        return Int64.random(in: Int64.min ... Int64.max)
    }, storeResourceData: { id, data in
        resources.storeResourceData(id: id, data: data)
    })
}
