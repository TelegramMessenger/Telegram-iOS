import Foundation
import UIKit
import Display
import AVFoundation
import SwiftSignalKit
import TelegramCore
import TextFormat
import Photos
import MediaEditor
import DrawingUI

extension MediaEditorScreenImpl {
    func requestStoryCompletion(animated: Bool) {
        guard let mediaEditor = self.node.mediaEditor, !self.didComplete else {
            return
        }
        
        self.didComplete = true
        
        self.updateMediaEditorEntities()
        
        mediaEditor.stop()
        mediaEditor.invalidate()
        self.node.entitiesView.invalidate()
        
        if let navigationController = self.navigationController as? NavigationController {
            navigationController.updateRootContainerTransitionOffset(0.0, transition: .immediate)
        }
                
        var multipleItems: [EditingItem] = []
        var isLongVideo = false
        if self.node.items.count > 1 {
            multipleItems = self.node.items.filter({ $0.isEnabled })
        } else if case let .asset(asset) = self.node.subject {
            let duration: Double
            if let playerDuration = mediaEditor.duration {
                duration = playerDuration
            } else {
                duration = asset.duration
            }
            if duration > storyMaxVideoDuration {
                let originalDuration = mediaEditor.originalDuration ?? asset.duration
                let values = mediaEditor.values
                
                let storyCount = min(storyMaxCombinedVideoCount, Int(ceil(duration / storyMaxVideoDuration)))
                var start = values.videoTrimRange?.lowerBound ?? 0
                let end = values.videoTrimRange?.upperBound ?? (min(originalDuration, start + storyMaxCombinedVideoDuration))
                
                for i in 0 ..< storyCount {
                    guard var editingItem = EditingItem(subject: .asset(asset)) else {
                        continue
                    }
                    let trimmedValues = values.withUpdatedVideoTrimRange(start ..< min(end, start + storyMaxVideoDuration))
                    if i == 0 {
                        editingItem.caption = self.node.getCaption()
                    }
                    editingItem.values = trimmedValues
                    multipleItems.append(editingItem)
                    
                    start += storyMaxVideoDuration
                }
                isLongVideo = true
            }
        }
        
        if multipleItems.count > 1 {
            self.processMultipleItems(items: multipleItems, isLongVideo: isLongVideo)
        } else {
            self.processSingleItem()
        }
        
        self.dismissAllTooltips()
    }
    
    private func processSingleItem() {
        guard let mediaEditor = self.node.mediaEditor, let subject = self.node.subject, let actualSubject = self.node.actualSubject else {
            return
        }
        
        var caption = self.node.getCaption()
        caption = convertMarkdownToAttributes(caption)
        
        var hasEntityChanges = false
        let randomId: Int64
        if case let .draft(_, id) = actualSubject, let id {
            randomId = id
        } else {
            randomId = Int64.random(in: .min ... .max)
        }
        
        let codableEntities = mediaEditor.values.entities
        var mediaAreas: [MediaArea] = []
        if case let .draft(draft, _) = actualSubject {
            if draft.values.entities != codableEntities {
                hasEntityChanges = true
            }
        } else {
            mediaAreas = self.initialMediaAreas ?? []
        }
        
        var stickers: [TelegramMediaFile] = []
        for entity in codableEntities {
            switch entity {
            case let .sticker(stickerEntity):
                if case let .file(file, fileType) = stickerEntity.content, case .sticker = fileType {
                    stickers.append(file.media)
                }
            case let .text(textEntity):
                if let subEntities = textEntity.renderSubEntities {
                    for entity in subEntities {
                        if let stickerEntity = entity as? DrawingStickerEntity, case let .file(file, fileType) = stickerEntity.content, case .sticker = fileType {
                            stickers.append(file.media)
                        }
                    }
                }
            default:
                break
            }
            if let mediaArea = entity.mediaArea {
                mediaAreas.append(mediaArea)
            }
        }
        
        var hasAnyChanges = self.node.hasAnyChanges
        if self.isEditingStoryCover {
            hasAnyChanges = false
        }
        
        if self.isEmbeddedEditor && !(hasAnyChanges || hasEntityChanges) {
            self.saveDraft(id: randomId, isEdit: true)
            
            self.completion([MediaEditorScreenImpl.Result(media: nil, mediaAreas: [], caption: caption, coverTimestamp: mediaEditor.values.coverImageTimestamp, options: self.state.privacy, stickers: stickers, randomId: randomId)], { [weak self] finished in
                self?.node.animateOut(finished: true, saveDraft: false, completion: { [weak self] in
                    self?.dismiss()
                    Queue.mainQueue().justDispatch {
                        finished()
                    }
                })
            })
            return
        }
        
        if !(self.isEditingStory || self.isEditingStoryCover) {
            let privacy = self.state.privacy
            let _ = updateMediaEditorStoredStateInteractively(engine: self.context.engine, { current in
                if let current {
                    return current.withUpdatedPrivacy(privacy)
                } else {
                    return MediaEditorStoredState(privacy: privacy, textSettings: nil)
                }
            }).start()
        }
        
        if mediaEditor.resultIsVideo {
            self.saveDraft(id: randomId)
            
            var firstFrame: Signal<(UIImage?, UIImage?), NoError>
            let firstFrameTime: CMTime
            if let coverImageTimestamp = mediaEditor.values.coverImageTimestamp {
                firstFrameTime = CMTime(seconds: coverImageTimestamp, preferredTimescale: CMTimeScale(60))
            } else {
                firstFrameTime = CMTime(seconds: mediaEditor.values.videoTrimRange?.lowerBound ?? 0.0, preferredTimescale: CMTimeScale(60))
            }
            let videoResult: Signal<MediaResult.VideoResult, NoError>
            var videoIsMirrored = false
            let duration: Double
            switch subject {
            case let .empty(dimensions):
                let image = generateImage(dimensions.cgSize, opaque: false, scale: 1.0, rotatedContext: { size, context in
                    context.clear(CGRect(origin: .zero, size: size))
                })!
                let tempImagePath = NSTemporaryDirectory() + "\(Int64.random(in: Int64.min ... Int64.max)).jpg"
                if let data = image.jpegData(compressionQuality: 0.85) {
                    try? data.write(to: URL(fileURLWithPath: tempImagePath))
                }
                videoResult = .single(.imageFile(path: tempImagePath))
                duration = 3.0
                
                firstFrame = .single((image, nil))
            case let .image(image, _, _, _, _):
                let tempImagePath = NSTemporaryDirectory() + "\(Int64.random(in: Int64.min ... Int64.max)).jpg"
                if let data = image.jpegData(compressionQuality: 0.85) {
                    try? data.write(to: URL(fileURLWithPath: tempImagePath))
                }
                videoResult = .single(.imageFile(path: tempImagePath))
                duration = 5.0
                
                firstFrame = .single((image, nil))
            case let .video(path, _, mirror, additionalPath, _, _, durationValue, _, _, _):
                videoIsMirrored = mirror
                videoResult = .single(.videoFile(path: path))
                if let videoTrimRange = mediaEditor.values.videoTrimRange {
                    duration = videoTrimRange.upperBound - videoTrimRange.lowerBound
                } else {
                    duration = durationValue
                }
                
                var additionalPath = additionalPath
                if additionalPath == nil, let valuesAdditionalPath = mediaEditor.values.additionalVideoPath {
                    additionalPath = valuesAdditionalPath
                }
                                
                firstFrame = Signal<(UIImage?, UIImage?), NoError> { subscriber in
                    let avAsset = AVURLAsset(url: URL(fileURLWithPath: path))
                    let avAssetGenerator = AVAssetImageGenerator(asset: avAsset)
                    avAssetGenerator.appliesPreferredTrackTransform = true
                    avAssetGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: firstFrameTime)], completionHandler: { _, cgImage, _, _, _ in
                        if let cgImage {
                            if let additionalPath {
                                let avAsset = AVURLAsset(url: URL(fileURLWithPath: additionalPath))
                                let avAssetGenerator = AVAssetImageGenerator(asset: avAsset)
                                avAssetGenerator.appliesPreferredTrackTransform = true
                                avAssetGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: firstFrameTime)], completionHandler: { _, additionalCGImage, _, _, _ in
                                    if let additionalCGImage {
                                        subscriber.putNext((UIImage(cgImage: cgImage), UIImage(cgImage: additionalCGImage)))
                                        subscriber.putCompletion()
                                    } else {
                                        subscriber.putNext((UIImage(cgImage: cgImage), nil))
                                        subscriber.putCompletion()
                                    }
                                })
                            } else {
                                subscriber.putNext((UIImage(cgImage: cgImage), nil))
                                subscriber.putCompletion()
                            }
                        }
                    })
                    return ActionDisposable {
                        avAssetGenerator.cancelAllCGImageGeneration()
                    }
                }
            case let .videoCollage(items):
                var maxDurationItem: (Double, Subject.VideoCollageItem)?
                for item in items {
                    switch item.content {
                    case .image:
                        break
                    case let .video(_, duration):
                        if let (maxDuration, _) = maxDurationItem {
                            if duration > maxDuration {
                                maxDurationItem = (duration, item)
                            }
                        } else {
                            maxDurationItem = (duration, item)
                        }
                    case let .asset(asset):
                        if let (maxDuration, _) = maxDurationItem {
                            if asset.duration > maxDuration {
                                maxDurationItem = (asset.duration, item)
                            }
                        } else {
                            maxDurationItem = (asset.duration, item)
                        }
                    }
                }
                guard let (maxDuration, mainItem) = maxDurationItem else {
                    fatalError()
                }
                switch mainItem.content {
                case let .video(path, _):
                    videoResult = .single(.videoFile(path: path))
                case let .asset(asset):
                    videoResult = .single(.asset(localIdentifier: asset.localIdentifier))
                default:
                    fatalError()
                }
                let image = generateImage(storyDimensions, opaque: false, scale: 1.0, rotatedContext: { size, context in
                    context.clear(CGRect(origin: .zero, size: size))
                })!
                firstFrame = .single((image, nil))
                if let videoTrimRange = mediaEditor.values.videoTrimRange {
                    duration = videoTrimRange.upperBound - videoTrimRange.lowerBound
                } else {
                    duration = min(maxDuration, storyMaxVideoDuration)
                }
            case let .asset(asset):
                videoResult = .single(.asset(localIdentifier: asset.localIdentifier))
                if asset.mediaType == .video {
                    if let videoTrimRange = mediaEditor.values.videoTrimRange {
                        duration = videoTrimRange.upperBound - videoTrimRange.lowerBound
                    } else {
                        duration = min(asset.duration, storyMaxVideoDuration)
                    }
                } else {
                    duration = 5.0
                }
                
                var additionalPath: String?
                if let valuesAdditionalPath = mediaEditor.values.additionalVideoPath {
                    additionalPath = valuesAdditionalPath
                }
                
                firstFrame = Signal<(UIImage?, UIImage?), NoError> { subscriber in
                    if asset.mediaType == .video {
                        PHImageManager.default().requestAVAsset(forVideo: asset, options: nil) { avAsset, _, _ in
                            if let avAsset {
                                let avAssetGenerator = AVAssetImageGenerator(asset: avAsset)
                                avAssetGenerator.appliesPreferredTrackTransform = true
                                avAssetGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: firstFrameTime)], completionHandler: { _, cgImage, _, _, _ in
                                    if let cgImage {
                                        if let additionalPath {
                                            let avAsset = AVURLAsset(url: URL(fileURLWithPath: additionalPath))
                                            let avAssetGenerator = AVAssetImageGenerator(asset: avAsset)
                                            avAssetGenerator.appliesPreferredTrackTransform = true
                                            avAssetGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: firstFrameTime)], completionHandler: { _, additionalCGImage, _, _, _ in
                                                if let additionalCGImage {
                                                    subscriber.putNext((UIImage(cgImage: cgImage), UIImage(cgImage: additionalCGImage)))
                                                    subscriber.putCompletion()
                                                } else {
                                                    subscriber.putNext((UIImage(cgImage: cgImage), nil))
                                                    subscriber.putCompletion()
                                                }
                                            })
                                        } else {
                                            subscriber.putNext((UIImage(cgImage: cgImage), nil))
                                            subscriber.putCompletion()
                                        }
                                    }
                                })
                            }
                        }
                    } else {
                        let options = PHImageRequestOptions()
                        options.deliveryMode = .highQualityFormat
                        PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: options) { image, _ in
                            if let image {
                                if let additionalPath {
                                    let avAsset = AVURLAsset(url: URL(fileURLWithPath: additionalPath))
                                    let avAssetGenerator = AVAssetImageGenerator(asset: avAsset)
                                    avAssetGenerator.appliesPreferredTrackTransform = true
                                    avAssetGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: firstFrameTime)], completionHandler: { _, additionalCGImage, _, _, _ in
                                        if let additionalCGImage {
                                            subscriber.putNext((image, UIImage(cgImage: additionalCGImage)))
                                            subscriber.putCompletion()
                                        } else {
                                            subscriber.putNext((image, nil))
                                            subscriber.putCompletion()
                                        }
                                    })
                                } else {
                                    subscriber.putNext((image, nil))
                                    subscriber.putCompletion()
                                }
                            }
                        }
                    }
                    return EmptyDisposable
                }
            case let .draft(draft, _):
                let draftPath = draft.fullPath(engine: context.engine)
                if draft.isVideo {
                    videoResult = .single(.videoFile(path: draftPath))
                    if let videoTrimRange = mediaEditor.values.videoTrimRange {
                        duration = videoTrimRange.upperBound - videoTrimRange.lowerBound
                    } else {
                        duration = min(draft.duration ?? 5.0, storyMaxVideoDuration)
                    }
                    firstFrame = Signal<(UIImage?, UIImage?), NoError> { subscriber in
                        let avAsset = AVURLAsset(url: URL(fileURLWithPath: draftPath))
                        let avAssetGenerator = AVAssetImageGenerator(asset: avAsset)
                        avAssetGenerator.appliesPreferredTrackTransform = true
                        avAssetGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: firstFrameTime)], completionHandler: { _, cgImage, _, _, _ in
                            if let cgImage {
                                subscriber.putNext((UIImage(cgImage: cgImage), nil))
                                subscriber.putCompletion()
                            }
                        })
                        return ActionDisposable {
                            avAssetGenerator.cancelAllCGImageGeneration()
                        }
                    }
                } else {
                    videoResult = .single(.imageFile(path: draftPath))
                    duration = 5.0
                    
                    if let image = UIImage(contentsOfFile: draftPath) {
                        firstFrame = .single((image, nil))
                    } else {
                        firstFrame = .single((UIImage(), nil))
                    }
                }
            case .message, .gift:
                let peerId: EnginePeer.Id
                if case let .message(messageIds) = subject {
                    peerId = messageIds.first!.peerId
                } else {
                    peerId = self.context.account.peerId
                }
                
                let isNightTheme = mediaEditor.values.nightTheme
                let wallpaper = getChatWallpaperImage(context: self.context, peerId: peerId)
                |> map { _, image, nightImage -> UIImage? in
                    if isNightTheme {
                        return nightImage ?? image
                    } else {
                        return image
                    }
                }
                
                videoResult = wallpaper
                |> mapToSignal { image in
                    if let image {
                        let tempImagePath = NSTemporaryDirectory() + "\(Int64.random(in: Int64.min ... Int64.max)).jpg"
                        if let data = image.jpegData(compressionQuality: 0.85) {
                            try? data.write(to: URL(fileURLWithPath: tempImagePath))
                        }
                        return .single(.imageFile(path: tempImagePath))
                    } else {
                        return .complete()
                    }
                }
                
                firstFrame = wallpaper
                |> map { image in
                    return (image, nil)
                }
                duration = 5.0
            case .sticker:
                let image = generateImage(storyDimensions, contextGenerator: { size, context in
                    context.clear(CGRect(origin: .zero, size: size))
                }, opaque: false, scale: 1.0)
                let tempImagePath = NSTemporaryDirectory() + "\(Int64.random(in: Int64.min ... Int64.max)).png"
                if let data = image?.pngData() {
                    try? data.write(to: URL(fileURLWithPath: tempImagePath))
                }
                videoResult = .single(.imageFile(path: tempImagePath))
                duration = 3.0
                
                firstFrame = .single((image, nil))
            case .multiple:
                fatalError()
            }
            
            let _ = combineLatest(queue: Queue.mainQueue(), firstFrame, videoResult)
            .start(next: { [weak self] images, videoResult in
                if let self {
                    let (image, additionalImage) = images
                    var currentImage = mediaEditor.resultImage
                    if let image {
                        mediaEditor.replaceSource(image, additionalImage: additionalImage, time: firstFrameTime, mirror: true)
                        if let updatedImage = mediaEditor.getResultImage(mirror: videoIsMirrored) {
                            currentImage = updatedImage
                        }
                    }
                    
                    var inputImage: UIImage
                    if let currentImage {
                        inputImage = currentImage
                    } else if let image {
                        inputImage = image
                    } else {
                        inputImage = UIImage()
                    }
                    
                    var values = mediaEditor.values
                    if case .avatarEditor = self.mode, values.videoTrimRange == nil && duration > avatarMaxVideoDuration {
                        values = values.withUpdatedVideoTrimRange(0 ..< avatarMaxVideoDuration)
                    }

                    makeEditorImageComposition(context: self.node.ciContext, postbox: self.context.account.postbox, inputImage: inputImage, dimensions: storyDimensions, values: values, time: firstFrameTime, textScale: 2.0, completion: { [weak self] coverImage in
                        if let self {
                            self.willComplete(coverImage, true, { [weak self] in
                                guard let self else {
                                    return
                                }
                                Logger.shared.log("MediaEditor", "Completed with video \(videoResult)")
                                self.completion([MediaEditorScreenImpl.Result(media: .video(video: videoResult, coverImage: coverImage, values: values, duration: duration, dimensions: values.resultDimensions), mediaAreas: mediaAreas, caption: caption, coverTimestamp: values.coverImageTimestamp, options: self.state.privacy, stickers: stickers, randomId: randomId)], { [weak self] finished in
                                    self?.node.animateOut(finished: true, saveDraft: false, completion: { [weak self] in
                                        self?.dismiss()
                                        Queue.mainQueue().justDispatch {
                                            finished()
                                        }
                                    })
                                })
                            })
                        }
                    })
                }
            })
        
            if case let .draft(draft, id) = actualSubject, id == nil {
                removeStoryDraft(engine: self.context.engine, path: draft.path, delete: false)
            }
        } else if let image = mediaEditor.resultImage {
            self.saveDraft(id: randomId)
            
            var values = mediaEditor.values
            var outputDimensions: CGSize?
            if case .avatarEditor = self.mode {
                outputDimensions = CGSize(width: 640.0, height: 640.0)
                values = values.withUpdatedQualityPreset(.profile)
            }
            makeEditorImageComposition(
                context: self.node.ciContext,
                postbox: self.context.account.postbox,
                inputImage: image,
                dimensions: storyDimensions,
                outputDimensions: outputDimensions,
                values: values,
                time: .zero,
                textScale: 2.0,
                completion: { [weak self] resultImage in
                if let self, let resultImage {
                    self.willComplete(resultImage, false, { [weak self] in
                        guard let self else {
                            return
                        }
                        Logger.shared.log("MediaEditor", "Completed with image \(resultImage)")
                        self.completion([MediaEditorScreenImpl.Result(media: .image(image: resultImage, dimensions: PixelDimensions(resultImage.size)), mediaAreas: mediaAreas, caption: caption, coverTimestamp: nil, options: self.state.privacy, stickers: stickers, randomId: randomId)], { [weak self] finished in
                            self?.node.animateOut(finished: true, saveDraft: false, completion: { [weak self] in
                                self?.dismiss()
                                Queue.mainQueue().justDispatch {
                                    finished()
                                }
                            })
                        })
                        if case let .draft(draft, id) = actualSubject, id == nil {
                            removeStoryDraft(engine: self.context.engine, path: draft.path, delete: true)
                        }
                    })
                }
            })
        }
    }
    
    private func processMultipleItems(items: [EditingItem], isLongVideo: Bool) {
        guard !items.isEmpty else {
            return
        }
        
        var items = items
        if !isLongVideo, let mediaEditor = self.node.mediaEditor, let subject = self.node.subject, let currentItemIndex = items.firstIndex(where: { $0.source.identifier == subject.sourceIdentifier }) {
            var updatedCurrentItem = items[currentItemIndex]
            updatedCurrentItem.caption = self.node.getCaption()
            updatedCurrentItem.values = mediaEditor.values
            items[currentItemIndex] = updatedCurrentItem
        }
        
        let multipleResults = Atomic<[MediaEditorScreenImpl.Result]>(value: [])
        let totalItems = items.count
        
        let dispatchGroup = DispatchGroup()
        
        let privacy = self.state.privacy
        
        if !(self.isEditingStory || self.isEditingStoryCover) {
            let _ = updateMediaEditorStoredStateInteractively(engine: self.context.engine, { current in
                if let current {
                    return current.withUpdatedPrivacy(privacy)
                } else {
                    return MediaEditorStoredState(privacy: privacy, textSettings: nil)
                }
            }).start()
        }
        
        var order: [Int64] = []
        for (index, item) in items.enumerated() {
            guard item.isEnabled else {
                continue
            }
            
            dispatchGroup.enter()
            
            let randomId = Int64.random(in: .min ... .max)
            order.append(randomId)
            
            if item.source.isVideo {
                processVideoItem(item: item, index: index, randomId: randomId, isLongVideo: isLongVideo) { result in
                    let _ = multipleResults.modify { results in
                        var updatedResults = results
                        updatedResults.append(result)
                        return updatedResults
                    }
                                                    
                    dispatchGroup.leave()
                }
            } else {
                processImageItem(item: item, index: index, randomId: randomId) { result in
                    let _ = multipleResults.modify { results in
                        var updatedResults = results
                        updatedResults.append(result)
                        return updatedResults
                    }
                                        
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            let results = multipleResults.with { $0 }
            if results.count == totalItems {
                var orderedResults: [MediaEditorScreenImpl.Result] = []
                for id in order {
                    if let item = results.first(where: { $0.randomId == id }) {
                        orderedResults.append(item)
                    }
                }
                self.completion(orderedResults, { [weak self] finished in
                    self?.node.animateOut(finished: true, saveDraft: false, completion: { [weak self] in
                        self?.dismiss()
                        Queue.mainQueue().justDispatch {
                            finished()
                        }
                    })
                })
            }
        }
    }
    
    private func processVideoItem(item: EditingItem, index: Int, randomId: Int64, isLongVideo: Bool, completion: @escaping (MediaEditorScreenImpl.Result) -> Void) {
        let itemMediaEditor = setupMediaEditorForItem(item: item)
            
        var mediaAreas: [MediaArea] = []
        var stickers: [TelegramMediaFile] = []
        
        if let entities = item.values?.entities {
            for entity in entities {
                if let mediaArea = entity.mediaArea {
                    mediaAreas.append(mediaArea)
                }
                extractStickersFromEntity(entity, into: &stickers)
            }
        }
        
        let firstFrameTime: CMTime
        if let coverImageTimestamp = item.values?.coverImageTimestamp, !isLongVideo || index == 0 {
            firstFrameTime = CMTime(seconds: coverImageTimestamp, preferredTimescale: CMTimeScale(60))
        } else {
            firstFrameTime = CMTime(seconds: item.values?.videoTrimRange?.lowerBound ?? 0.0, preferredTimescale: CMTimeScale(60))
        }
        
        let process: (AVAsset?, MediaResult.VideoResult) -> Void = { [weak self] avAsset, videoResult in
            guard let self else {
                return
            }
            guard let avAsset else {
                Queue.mainQueue().async {
                    completion(self.createEmptyResult(randomId: randomId))
                }
                return
            }
            
            let duration: Double
            if let videoTrimRange = item.values?.videoTrimRange {
                duration = videoTrimRange.upperBound - videoTrimRange.lowerBound
            } else {
                duration = min(avAsset.duration.seconds, storyMaxVideoDuration)
            }
                        
            let avAssetGenerator = AVAssetImageGenerator(asset: avAsset)
            avAssetGenerator.appliesPreferredTrackTransform = true
            avAssetGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: firstFrameTime)]) { [weak self] _, cgImage, _, _, _ in
                guard let self else {
                    return
                }
                Queue.mainQueue().async {
                    if let cgImage {
                        let image = UIImage(cgImage: cgImage)
                        itemMediaEditor.replaceSource(image, additionalImage: nil, time: firstFrameTime, mirror: false)
                        
                        if let resultImage = itemMediaEditor.resultImage {
                            makeEditorImageComposition(
                                context: self.node.ciContext,
                                postbox: self.context.account.postbox,
                                inputImage: resultImage,
                                dimensions: storyDimensions,
                                values: itemMediaEditor.values,
                                time: firstFrameTime,
                                textScale: 2.0
                            ) { coverImage in
                                if let coverImage = coverImage {
                                    let result = MediaEditorScreenImpl.Result(
                                        media: .video(
                                            video: videoResult,
                                            coverImage: coverImage,
                                            values: itemMediaEditor.values,
                                            duration: duration,
                                            dimensions: itemMediaEditor.values.resultDimensions
                                        ),
                                        mediaAreas: mediaAreas,
                                        caption: convertMarkdownToAttributes(item.caption),
                                        coverTimestamp: itemMediaEditor.values.coverImageTimestamp,
                                        options: self.state.privacy,
                                        stickers: stickers,
                                        randomId: randomId
                                    )
                                    completion(result)
                                } else {
                                    completion(self.createEmptyResult(randomId: randomId))
                                }
                            }
                        } else {
                            completion(self.createEmptyResult(randomId: randomId))
                        }
                    } else {
                        completion(self.createEmptyResult(randomId: randomId))
                    }
                }
            }
        }
        
        switch item.source {
        case let .video(videoPath, _, _, _):
            let avAsset = AVURLAsset(url: URL(fileURLWithPath: videoPath))
            process(avAsset, .videoFile(path: videoPath))
        case let .asset(asset):
            PHImageManager.default().requestAVAsset(forVideo: asset, options: nil) { avAsset, _, _ in
                process(avAsset, .asset(localIdentifier: asset.localIdentifier))
            }
        default:
            fatalError()
        }
    }

    private func processImageItem(item: EditingItem, index: Int, randomId: Int64, completion: @escaping (MediaEditorScreenImpl.Result) -> Void) {
        let itemMediaEditor = setupMediaEditorForItem(item: item)
        
        var caption = item.caption
        caption = convertMarkdownToAttributes(caption)
        
        var mediaAreas: [MediaArea] = []
        var stickers: [TelegramMediaFile] = []
        
        if let entities = item.values?.entities {
            for entity in entities {
                if let mediaArea = entity.mediaArea {
                    mediaAreas.append(mediaArea)
                }
                extractStickersFromEntity(entity, into: &stickers)
            }
        }
        
        let process: (UIImage?) -> Void = { [weak self] image in
            guard let self else {
                return
            }
            guard let image else {
                completion(self.createEmptyResult(randomId: randomId))
                return
            }
            itemMediaEditor.replaceSource(image, additionalImage: nil, time: .zero, mirror: false)
            if itemMediaEditor.values.gradientColors == nil {
                itemMediaEditor.setGradientColors(mediaEditorGetGradientColors(from: image))
            }
            
            if let resultImage = itemMediaEditor.resultImage {
                makeEditorImageComposition(
                    context: self.node.ciContext,
                    postbox: self.context.account.postbox,
                    inputImage: resultImage,
                    dimensions: storyDimensions,
                    values: itemMediaEditor.values,
                    time: .zero,
                    textScale: 2.0
                ) { resultImage in
                    if let resultImage = resultImage {
                        let result = MediaEditorScreenImpl.Result(
                            media: .image(
                                image: resultImage,
                                dimensions: PixelDimensions(resultImage.size)
                            ),
                            mediaAreas: mediaAreas,
                            caption: caption,
                            coverTimestamp: nil,
                            options: self.state.privacy,
                            stickers: stickers,
                            randomId: randomId
                        )
                        completion(result)
                    } else {
                        completion(self.createEmptyResult(randomId: randomId))
                    }
                }
            } else {
                completion(self.createEmptyResult(randomId: randomId))
            }
        }
        
        switch item.source {
        case let .image(image, _):
            process(image)
        case let .asset(asset):
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: options) { image, _ in
                Queue.mainQueue().async {
                    process(image)
                }
            }
        default:
            fatalError()
        }
    }

    private func setupMediaEditorForItem(item: EditingItem) -> MediaEditor {
        var values = item.values
        if values?.videoTrimRange == nil {
            values = values?.withUpdatedVideoTrimRange(0 ..< storyMaxVideoDuration)
        }
        
        let editorSubject: MediaEditor.Subject
        switch item.source {
        case let .image(image, dimensions):
            editorSubject = .image(image, dimensions)
        case let .video(videoPath, thumbnailImage, dimensions, duration):
            editorSubject = .video(videoPath, thumbnailImage, false, nil, dimensions, duration)
        case let .asset(asset):
            editorSubject = .asset(asset)
        }
        
        return MediaEditor(
            context: self.context,
            mode: .default,
            subject: editorSubject,
            values: values,
            hasHistogram: false,
            isStandalone: true
        )
    }

    private func extractStickersFromEntity(_ entity: CodableDrawingEntity, into stickers: inout [TelegramMediaFile]) {
        switch entity {
        case let .sticker(stickerEntity):
            if case let .file(file, fileType) = stickerEntity.content, case .sticker = fileType {
                stickers.append(file.media)
            }
        case let .text(textEntity):
            if let subEntities = textEntity.renderSubEntities {
                for entity in subEntities {
                    if let stickerEntity = entity as? DrawingStickerEntity, case let .file(file, fileType) = stickerEntity.content, case .sticker = fileType {
                        stickers.append(file.media)
                    }
                }
            }
        default:
            break
        }
    }

    private func createEmptyResult(randomId: Int64) -> MediaEditorScreenImpl.Result {
        let emptyImage = UIImage()
        return MediaEditorScreenImpl.Result(
            media: .image(
                image: emptyImage,
                dimensions: PixelDimensions(emptyImage.size)
            ),
            mediaAreas: [],
            caption: NSAttributedString(),
            coverTimestamp: nil,
            options: self.state.privacy,
            stickers: [],
            randomId: randomId
        )
    }
    
    
    
    func updateMediaEditorEntities() {
        guard let mediaEditor = self.node.mediaEditor else {
            return
        }
        let entities = self.node.entitiesView.entities.filter { !($0 is DrawingMediaEntity) }
        let codableEntities = DrawingEntitiesView.encodeEntities(entities, entitiesView: self.node.entitiesView)
        mediaEditor.setDrawingAndEntities(data: nil, image: mediaEditor.values.drawing, entities: codableEntities)
    }
}
