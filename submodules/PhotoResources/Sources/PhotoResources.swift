import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import Display
import AVFoundation
import ImageIO
import TelegramCore
import WebPBinding
import TelegramUIPreferences
import MediaResources
import AccountContext
import Tuples
import ImageBlur
import FastBlur
import TinyThumbnail
import ImageTransparency
import AppBundle
import MusicAlbumArtResources
import Svg
import RangeSet

private enum ResourceFileData {
    case data(Data)
    case file(path: String, size: Int)
}

public func largestRepresentationForPhoto(_ photo: TelegramMediaImage) -> TelegramMediaImageRepresentation? {
    if let progressiveRepresentation = progressiveImageRepresentation(photo.representations) {
        return progressiveRepresentation
    }
    return photo.representationForDisplayAtSize(PixelDimensions(width: 1280, height: 1280))
}

private let progressiveRangeMap: [(Int, [Int])] = [
    (100, [0]),
    (400, [3]),
    (600, [4]),
    (Int(Int32.max), [2, 3, 4])
]

public func representationFetchRangeForDisplayAtSize(representation: TelegramMediaImageRepresentation, dimension: Int?) -> Range<Int64>? {
    if representation.progressiveSizes.count > 1, let dimension = dimension {
        var largestByteSize = Int64(representation.progressiveSizes[0])
        for (maxDimension, byteSizes) in progressiveRangeMap {
            largestByteSize = Int64(representation.progressiveSizes[min(representation.progressiveSizes.count - 1, byteSizes.last!)])
            if maxDimension >= dimension {
                break
            }
        }
        return 0 ..< largestByteSize
    }
    return nil
}

public func chatMessagePhotoDatas(postbox: Postbox, photoReference: ImageMediaReference, fullRepresentationSize: CGSize = CGSize(width: 1280.0, height: 1280.0), autoFetchFullSize: Bool = false, tryAdditionalRepresentations: Bool = false, synchronousLoad: Bool = false, useMiniThumbnailIfAvailable: Bool = false) -> Signal<Tuple4<Data?, Data?, ChatMessagePhotoQuality, Bool>, NoError> {
    if let progressiveRepresentation = progressiveImageRepresentation(photoReference.media.representations), progressiveRepresentation.progressiveSizes.count > 1 {
        enum SizeSource {
            case miniThumbnail(data: Data)
            case image(size: Int64)
        }
        
        var sources: [SizeSource] = []
        let thumbnailByteSize = Int(progressiveRepresentation.progressiveSizes[0])
        var largestByteSize = Int(progressiveRepresentation.progressiveSizes[0])
        for (maxDimension, byteSizes) in progressiveRangeMap {
            if Int(fullRepresentationSize.width) > 100 && maxDimension <= 100 {
                continue
            }
            sources.append(contentsOf: byteSizes.compactMap { sizeIndex -> SizeSource? in
                if progressiveRepresentation.progressiveSizes.count - 1 < sizeIndex {
                    return nil
                }
                return .image(size: Int64(progressiveRepresentation.progressiveSizes[sizeIndex]))
            })
            largestByteSize = Int(progressiveRepresentation.progressiveSizes[min(progressiveRepresentation.progressiveSizes.count - 1, byteSizes.last!)])
            if maxDimension >= Int(fullRepresentationSize.width) {
                break
            }
        }
        if sources.isEmpty {
            sources.append(.image(size: Int64(largestByteSize)))
        }
        if let miniThumbnail = photoReference.media.immediateThumbnailData.flatMap(decodeTinyThumbnail) {
            sources.insert(.miniThumbnail(data: miniThumbnail), at: 0)
        }
        
        return Signal { subscriber in
            let signals: [Signal<(SizeSource, Data?), NoError>] = sources.map { source -> Signal<(SizeSource, Data?), NoError> in
                switch source {
                case let .miniThumbnail(data):
                    return .single((source, data))
                case let .image(size):
                    return postbox.mediaBox.resourceData(progressiveRepresentation.resource, size: Int64(progressiveRepresentation.progressiveSizes.last!), in: 0 ..< size, mode: .incremental, notifyAboutIncomplete: true, attemptSynchronously: synchronousLoad)
                    |> map { (data, _) -> (SizeSource, Data?) in
                        return (source, data)
                    }
                }
            }
            
            let dataDisposable = combineLatest(signals).start(next: { results in
                var foundData = false
                loop: for i in (0 ..< results.count).reversed() {
                    let isLastSize = i == results.count - 1
                    switch results[i].0 {
                    case .image:
                        if let data = results[i].1, data.count != 0 {
                            if Int(fullRepresentationSize.width) > 100 && i <= 1 && !isLastSize {
                                continue
                            }
                            
                            subscriber.putNext(Tuple4(nil, data, .full, isLastSize))
                            foundData = true
                            if isLastSize {
                                subscriber.putCompletion()
                            }
                            break loop
                        }
                    case let .miniThumbnail(thumbnailData):
                        subscriber.putNext(Tuple4(thumbnailData, nil, .blurred, false))
                        foundData = true
                        break loop
                    }
                }
                if !foundData {
                    subscriber.putNext(Tuple4(nil, nil, .blurred, false))
                }
            })
            var fetchDisposable: Disposable?
            if autoFetchFullSize {
                fetchDisposable = fetchedMediaResource(mediaBox: postbox.mediaBox, reference: photoReference.resourceReference(progressiveRepresentation.resource), range: (0 ..< Int64(largestByteSize), .default), statsCategory: .image).start()
            } else if useMiniThumbnailIfAvailable {
                fetchDisposable = fetchedMediaResource(mediaBox: postbox.mediaBox, reference: photoReference.resourceReference(progressiveRepresentation.resource), range: (0 ..< Int64(thumbnailByteSize), .default), statsCategory: .image).start()
            }
            
            return ActionDisposable {
                dataDisposable.dispose()
                fetchDisposable?.dispose()
            }
        }
    }
    
    if let smallestRepresentation = smallestImageRepresentation(photoReference.media.representations), let largestRepresentation = photoReference.media.representationForDisplayAtSize(PixelDimensions(width: Int32(fullRepresentationSize.width), height: Int32(fullRepresentationSize.height))), let fullRepresentation = largestImageRepresentation(photoReference.media.representations) {
        let maybeFullSize = postbox.mediaBox.resourceData(largestRepresentation.resource, option: .complete(waitUntilFetchStatus: false), attemptSynchronously: synchronousLoad)
        let maybeLargestSize = postbox.mediaBox.resourceData(fullRepresentation.resource, option: .complete(waitUntilFetchStatus: false), attemptSynchronously: synchronousLoad)
        
        let signal = combineLatest(maybeFullSize, maybeLargestSize)
        |> take(1)
        |> mapToSignal { maybeData, maybeLargestData -> Signal<Tuple4<Data?, Data?, ChatMessagePhotoQuality, Bool>, NoError> in
            if maybeData.complete {
                let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [])
                return .single(Tuple(nil, loadedData, .full, true))
            } else if maybeLargestData.complete {
                let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: maybeLargestData.path), options: [])
                return .single(Tuple(nil, loadedData, .full, true))
            } else {
                let decodedThumbnailData = photoReference.media.immediateThumbnailData.flatMap(decodeTinyThumbnail)
                let fetchedThumbnail: Signal<FetchResourceSourceType, FetchResourceError>
                if let _ = decodedThumbnailData {
                    fetchedThumbnail = .complete()
                } else {
                    fetchedThumbnail = fetchedMediaResource(mediaBox: postbox.mediaBox, reference: photoReference.resourceReference(smallestRepresentation.resource), statsCategory: .image)
                }
                let fetchedFullSize = fetchedMediaResource(mediaBox: postbox.mediaBox, reference: photoReference.resourceReference(largestRepresentation.resource), statsCategory: .image)
                
                let anyThumbnail: [Signal<(MediaResourceData, ChatMessagePhotoQuality), NoError>]
                if tryAdditionalRepresentations {
                    anyThumbnail = photoReference.media.representations.filter({ representation in
                        return representation != largestRepresentation
                    }).map({ representation -> Signal<(MediaResourceData, ChatMessagePhotoQuality), NoError> in
                        return postbox.mediaBox.resourceData(representation.resource)
                        |> take(1)
                        |> map { data -> (MediaResourceData, ChatMessagePhotoQuality) in
                            if representation.dimensions.width > 200 || representation.dimensions.height > 200 {
                                return (data, .medium)
                            } else {
                                return (data, .blurred)
                            }
                        }
                    })
                } else {
                    anyThumbnail = []
                }
                
                let mainThumbnail = Signal<Data?, NoError> { subscriber in
                    if let decodedThumbnailData = decodedThumbnailData {
                        subscriber.putNext(decodedThumbnailData)
                        subscriber.putCompletion()
                        return EmptyDisposable
                    } else {
                        let fetchedDisposable = fetchedThumbnail.start()
                        let thumbnailDisposable = postbox.mediaBox.resourceData(smallestRepresentation.resource, attemptSynchronously: synchronousLoad).start(next: { next in
                            subscriber.putNext(next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []))
                        }, error: subscriber.putError, completed: subscriber.putCompletion)
                        
                        return ActionDisposable {
                            fetchedDisposable.dispose()
                            thumbnailDisposable.dispose()
                        }
                    }
                }
                
                let thumbnail = combineLatest(anyThumbnail)
                |> mapToSignal { thumbnails -> Signal<(Data, ChatMessagePhotoQuality)?, NoError> in
                    for (thumbnail, quality) in thumbnails {
                        if thumbnail.size != 0, let data = try? Data(contentsOf: URL(fileURLWithPath: thumbnail.path), options: []) {
                            return .single((data, quality))
                        }
                    }
                    return mainThumbnail
                    |> map { data -> (Data, ChatMessagePhotoQuality)? in
                        return data.flatMap { ($0, .blurred) }
                    }
                }
                
                let fullSizeData: Signal<Tuple2<Data?, Bool>, NoError>
                
                if autoFetchFullSize && !useMiniThumbnailIfAvailable {
                    fullSizeData = Signal<Tuple2<Data?, Bool>, NoError> { subscriber in
                        let fetchedFullSizeDisposable = fetchedFullSize.start()
                        let fullSizeDisposable = postbox.mediaBox.resourceData(largestRepresentation.resource, option: .complete(waitUntilFetchStatus: false), attemptSynchronously: synchronousLoad).start(next: { next in
                            subscriber.putNext(Tuple(next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []), next.complete))
                        }, error: subscriber.putError, completed: subscriber.putCompletion)
                        
                        return ActionDisposable {
                            fetchedFullSizeDisposable.dispose()
                            fullSizeDisposable.dispose()
                        }
                    }
                } else {
                    fullSizeData = postbox.mediaBox.resourceData(largestRepresentation.resource, option: .complete(waitUntilFetchStatus: false), attemptSynchronously: synchronousLoad)
                    |> map { next -> Tuple2<Data?, Bool> in
                        return Tuple(next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []), next.complete)
                    }
                }
                
                return thumbnail
                |> mapToSignal { thumbnailData in
                    if let (thumbnailData, thumbnailQuality) = thumbnailData {
                        return fullSizeData
                        |> map { value in
                            return Tuple(thumbnailData, value._0, value._1 ? .full : thumbnailQuality, value._1)
                        }
                    } else {
                        return .single(Tuple(nil, nil, .none, false))
                    }
                }
            }
        }
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            if (lhs._0 == nil && lhs._1 == nil) && (rhs._0 == nil && rhs._1 == nil) {
                return true
            } else {
                return false
            }
        })
        
        return signal
    } else if let decodedThumbnailData = photoReference.media.immediateThumbnailData.flatMap(decodeTinyThumbnail) {
        return .single(Tuple(decodedThumbnailData, nil, .blurred, false))
    } else {
        return .never()
    }
}

private func chatMessageFileDatas(account: Account, fileReference: FileMediaReference, pathExtension: String? = nil, progressive: Bool = false, fetched: Bool = false) -> Signal<Tuple3<Data?, String?, Bool>, NoError> {
    let thumbnailResource = fetched ? nil : smallestImageRepresentation(fileReference.media.previewRepresentations)?.resource
    let fullSizeResource = fileReference.media.resource
    
    let maybeFullSize = account.postbox.mediaBox.resourceData(fullSizeResource, pathExtension: pathExtension)
    let decodedThumbnailData = fileReference.media.immediateThumbnailData.flatMap(decodeTinyThumbnail)
    
    let signal = maybeFullSize
    |> take(1)
    |> mapToSignal { maybeData -> Signal<Tuple3<Data?, String?, Bool>, NoError> in
        if maybeData.complete {
            return .single(Tuple(nil, maybeData.path, true))
        } else {
            let fetchedThumbnail: Signal<FetchResourceSourceType, FetchResourceError>
            if !fetched, let _ = decodedThumbnailData {
                fetchedThumbnail = .single(.local)
            } else if let thumbnailResource = thumbnailResource {
                fetchedThumbnail = fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: fileReference.resourceReference(thumbnailResource), statsCategory: statsCategoryForFileWithAttributes(fileReference.media.attributes))
            } else {
                fetchedThumbnail = .complete()
            }
            
            let thumbnail: Signal<Data?, NoError>
            if !fetched, let decodedThumbnailData = decodedThumbnailData {
                thumbnail = .single(decodedThumbnailData)
            } else if let thumbnailResource = thumbnailResource {
                thumbnail = Signal { subscriber in
                    let fetchedDisposable = fetchedThumbnail.start()
                    let thumbnailDisposable = account.postbox.mediaBox.resourceData(thumbnailResource, pathExtension: pathExtension).start(next: { next in
                        if next.size != 0, let data = try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []) {
                            subscriber.putNext(data)
                        } else {
                            subscriber.putNext(nil)
                        }
                    }, error: subscriber.putError, completed: subscriber.putCompletion)
                    
                    return ActionDisposable {
                        fetchedDisposable.dispose()
                        thumbnailDisposable.dispose()
                    }
                }
            } else {
                thumbnail = .single(nil)
            }
            
            let fullSizeDataAndPath = account.postbox.mediaBox.resourceData(fullSizeResource, option: !progressive ? .complete(waitUntilFetchStatus: false) : .incremental(waitUntilFetchStatus: false)) |> map { next -> Tuple2<String?, Bool> in
                return Tuple(next.size == 0 ? nil : next.path, next.complete)
            }
            
            return thumbnail
            |> mapToSignal { thumbnailData in
                return fullSizeDataAndPath
                |> map { value -> Tuple3<Data?, String?, Bool> in
                    return Tuple3<Data?, String?, Bool>(thumbnailData, value._0, value._1)
                }
            }
        }
    }
    |> filter({ $0._0 != nil || $0._1 != nil })
    
    return signal
}

private let thumbnailGenerationMimeTypes: Set<String> = Set([
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/gif",
    "image/heic"
])

private func chatMessageImageFileThumbnailDatas(account: Account, fileReference: FileMediaReference, pathExtension: String? = nil, progressive: Bool = false, autoFetchFullSizeThumbnail: Bool = false) -> Signal<Tuple3<Data?, String?, Bool>, NoError> {
    let thumbnailRepresentation = smallestImageRepresentation(fileReference.media.previewRepresentations)
    let thumbnailResource = thumbnailRepresentation?.resource
    let decodedThumbnailData = fileReference.media.immediateThumbnailData.flatMap(decodeTinyThumbnail)
    
    if !thumbnailGenerationMimeTypes.contains(fileReference.media.mimeType) {
        if let decodedThumbnailData = decodedThumbnailData {
            if autoFetchFullSizeThumbnail, let thumbnailRepresentation = thumbnailRepresentation, (thumbnailRepresentation.dimensions.width > 200 || thumbnailRepresentation.dimensions.height > 200) {
                return Signal { subscriber in
                    let fetchedDisposable = fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: fileReference.resourceReference(thumbnailRepresentation.resource), statsCategory: .video).start()
                    let thumbnailDisposable = account.postbox.mediaBox.resourceData(thumbnailRepresentation.resource, attemptSynchronously: false).start(next: { next in
                        let data: Data? = next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: [])
                        subscriber.putNext(Tuple(data ?? decodedThumbnailData, nil, false))
                    }, error: subscriber.putError, completed: subscriber.putCompletion)
                    
                    return ActionDisposable {
                        fetchedDisposable.dispose()
                        thumbnailDisposable.dispose()
                    }
                }
            } else {
                return .single(Tuple(decodedThumbnailData, nil, false))
            }
        } else if let thumbnailResource = thumbnailResource {
            let fetchedThumbnail: Signal<FetchResourceSourceType, FetchResourceError> = fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: fileReference.resourceReference(thumbnailResource))
            return Signal { subscriber in
                let fetchedDisposable = fetchedThumbnail.start()
                let thumbnailDisposable = account.postbox.mediaBox.resourceData(thumbnailResource, pathExtension: pathExtension).start(next: { next in
                    if next.size != 0, let data = try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []) {
                        subscriber.putNext(Tuple(data, nil, false))
                    } else {
                        subscriber.putNext(Tuple(nil, nil, false))
                    }
                }, error: subscriber.putError, completed: subscriber.putCompletion)
                
                return ActionDisposable {
                    fetchedDisposable.dispose()
                    thumbnailDisposable.dispose()
                }
            }
        } else {
            return .single(Tuple(nil, nil, false))
        }
    }
    
    let fullSizeResource: MediaResource = fileReference.media.resource
    
    let maybeFullSize = account.postbox.mediaBox.cachedResourceRepresentation(fullSizeResource, representation: CachedScaledImageRepresentation(size: CGSize(width: 180.0, height: 180.0), mode: .aspectFit), complete: false, fetch: false)
    let fetchedFullSize = account.postbox.mediaBox.cachedResourceRepresentation(fullSizeResource, representation: CachedScaledImageRepresentation(size: CGSize(width: 180.0, height: 180.0), mode: .aspectFit), complete: false, fetch: true)
    
    let signal = maybeFullSize
    |> take(1)
    |> mapToSignal { maybeData -> Signal<Tuple3<Data?, String?, Bool>, NoError> in
        if maybeData.complete {
            return .single(Tuple(nil, maybeData.path, true))
        } else {
            let fetchedThumbnail: Signal<FetchResourceSourceType, FetchResourceError>
            if let _ = fileReference.media.immediateThumbnailData {
                fetchedThumbnail = .complete()
            } else if let thumbnailResource = thumbnailResource {
                fetchedThumbnail = fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: fileReference.resourceReference(thumbnailResource))
            } else {
                fetchedThumbnail = .complete()
            }
            
            let thumbnail: Signal<Data?, NoError>
            if let decodedThumbnailData = decodedThumbnailData {
                thumbnail = .single(decodedThumbnailData)
            } else if let thumbnailResource = thumbnailResource {
                thumbnail = Signal { subscriber in
                    let fetchedDisposable = fetchedThumbnail.start()
                    let thumbnailDisposable = account.postbox.mediaBox.resourceData(thumbnailResource, pathExtension: pathExtension).start(next: { next in
                        if next.size != 0, let data = try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []) {
                            subscriber.putNext(data)
                        } else {
                            subscriber.putNext(nil)
                        }
                    }, error: subscriber.putError, completed: subscriber.putCompletion)
                    
                    return ActionDisposable {
                        fetchedDisposable.dispose()
                        thumbnailDisposable.dispose()
                    }
                }
            } else {
                thumbnail = .single(nil)
            }
            
            let fullSizeDataAndPath = fetchedFullSize
            |> map { next -> Tuple2<String?, Bool>in
                return Tuple(next.size == 0 ? nil : next.path, next.complete)
            }
            
            return thumbnail
            |> mapToSignal { thumbnailData in
                return fullSizeDataAndPath
                |> map { value in
                    return Tuple(thumbnailData, value._0, value._1)
                }
            }
        }
    } |> filter({ $0._0 != nil || $0._1 != nil })
    
    return signal
}

private func chatMessageVideoDatas(postbox: Postbox, fileReference: FileMediaReference, thumbnailSize: Bool = false, onlyFullSize: Bool = false, useLargeThumbnail: Bool = false, synchronousLoad: Bool = false, autoFetchFullSizeThumbnail: Bool = false) -> Signal<Tuple3<Data?, Tuple2<Data, String>?, Bool>, NoError> {
    let fullSizeResource = fileReference.media.resource
    var reducedSizeResource: MediaResource?
    if let videoThumbnail = fileReference.media.videoThumbnails.first {
        reducedSizeResource = videoThumbnail.resource
    }
    
    let thumbnailRepresentation = useLargeThumbnail ? largestImageRepresentation(fileReference.media.previewRepresentations) : smallestImageRepresentation(fileReference.media.previewRepresentations)
    let thumbnailResource = thumbnailRepresentation?.resource
    
    let maybeFullSize = postbox.mediaBox.cachedResourceRepresentation(fullSizeResource, representation: thumbnailSize ? CachedScaledVideoFirstFrameRepresentation(size: CGSize(width: 160.0, height: 160.0)) : CachedVideoFirstFrameRepresentation(), complete: false, fetch: false, attemptSynchronously: synchronousLoad)
    let fetchedFullSize = postbox.mediaBox.cachedResourceRepresentation(fullSizeResource, representation: thumbnailSize ? CachedScaledVideoFirstFrameRepresentation(size: CGSize(width: 160.0, height: 160.0)) : CachedVideoFirstFrameRepresentation(), complete: false, fetch: true, attemptSynchronously: synchronousLoad)
    var fetchedReducedSize: Signal<MediaResourceData, NoError> = .single(MediaResourceData(path: "", offset: 0, size: 0, complete: false))
    if let reducedSizeResource = reducedSizeResource {
        fetchedReducedSize = postbox.mediaBox.cachedResourceRepresentation(reducedSizeResource, representation: thumbnailSize ? CachedScaledVideoFirstFrameRepresentation(size: CGSize(width: 160.0, height: 160.0)) : CachedVideoFirstFrameRepresentation(), complete: false, fetch: true, attemptSynchronously: synchronousLoad)
    }
    
    let signal = maybeFullSize
    |> take(1)
    |> mapToSignal { maybeData -> Signal<Tuple3<Data?, Tuple2<Data, String>?, Bool>, NoError> in
        if maybeData.complete {
            let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [])
            return .single(Tuple(nil, loadedData == nil ? nil : Tuple(loadedData!, maybeData.path), true))
        } else {
            let thumbnail: Signal<Data?, NoError>
            if onlyFullSize {
                thumbnail = .single(nil)
            } else if let decodedThumbnailData = fileReference.media.immediateThumbnailData.flatMap(decodeTinyThumbnail) {
                if autoFetchFullSizeThumbnail, let thumbnailRepresentation = thumbnailRepresentation, (thumbnailRepresentation.dimensions.width > 200 || thumbnailRepresentation.dimensions.height > 200) {
                    thumbnail = Signal { subscriber in
                        let fetchedDisposable = fetchedMediaResource(mediaBox: postbox.mediaBox, reference: fileReference.resourceReference(thumbnailRepresentation.resource), statsCategory: .video).start()
                        let thumbnailDisposable = postbox.mediaBox.resourceData(thumbnailRepresentation.resource, attemptSynchronously: synchronousLoad).start(next: { next in
                            let data: Data? = next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: [])
                            subscriber.putNext(data ?? decodedThumbnailData)
                        }, error: subscriber.putError, completed: subscriber.putCompletion)
                        
                        return ActionDisposable {
                            fetchedDisposable.dispose()
                            thumbnailDisposable.dispose()
                        }
                    }
                } else {
                    thumbnail = .single(decodedThumbnailData)
                }
            } else if let thumbnailResource = thumbnailResource {
                thumbnail = Signal { subscriber in
                    let fetchedDisposable = fetchedMediaResource(mediaBox: postbox.mediaBox, reference: fileReference.resourceReference(thumbnailResource), statsCategory: .video).start()
                    let thumbnailDisposable = postbox.mediaBox.resourceData(thumbnailResource, attemptSynchronously: synchronousLoad).start(next: { next in
                        subscriber.putNext(next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []))
                    }, error: subscriber.putError, completed: subscriber.putCompletion)
                    
                    return ActionDisposable {
                        fetchedDisposable.dispose()
                        thumbnailDisposable.dispose()
                    }
                }
            } else {
                thumbnail = .single(nil)
            }
            
            let fullSizeDataAndPath = Signal<MediaResourceData, NoError> { subscriber in
                let dataDisposable = fetchedFullSize.start(next: { next in
                    subscriber.putNext(next)
                }, completed: {
                    subscriber.putCompletion()
                })
                //let fetchedDisposable = fetchedPartialVideoThumbnailData(postbox: postbox, fileReference: fileReference).start()
                return ActionDisposable {
                    dataDisposable.dispose()
                    //fetchedDisposable.dispose()
                }
            }
            |> map { next -> Tuple2<Tuple2<Data, String>?, Bool> in
                let data = next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: .mappedIfSafe)
                return Tuple(data == nil ? nil : Tuple(data!, next.path), next.complete)
            }
            
            let reducedSizeDataAndPath = Signal<MediaResourceData, NoError> { subscriber in
                let dataDisposable = fetchedReducedSize.start(next: { next in
                    subscriber.putNext(next)
                }, completed: {
                    subscriber.putCompletion()
                })
                return ActionDisposable {
                    dataDisposable.dispose()
                }
            }
            |> map { next -> Tuple2<Tuple2<Data, String>?, Bool> in
                let data = next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: .mappedIfSafe)
                return Tuple(data == nil ? nil : Tuple(data!, next.path), next.complete)
            }
            
            return thumbnail
            |> mapToSignal { thumbnailData in
                if synchronousLoad, let thumbnailData = thumbnailData {
                    return .single(Tuple(thumbnailData, nil, false))
                    |> then(
                        combineLatest(fullSizeDataAndPath, reducedSizeDataAndPath)
                        |> map { fullSize, reducedSize in
                            if !fullSize._1 && reducedSize._1 {
                                return Tuple(thumbnailData, reducedSize._0, false)
                            }
                            return Tuple(thumbnailData, fullSize._0, fullSize._1)
                        }
                    )
                } else {
                    return combineLatest(fullSizeDataAndPath, reducedSizeDataAndPath)
                    |> map { fullSize, reducedSize in
                        if !fullSize._1 && reducedSize._1 {
                            return Tuple(thumbnailData, reducedSize._0, false)
                        }
                        return Tuple(thumbnailData, fullSize._0, fullSize._1)
                    }
                }
            }
        }
    } |> filter({
        if onlyFullSize {
            return $0._1 != nil || $0._2
        } else {
            return true//$0.0 != nil || $0.1 != nil || $0.2
        }
    })
    
    return signal
}

public func rawMessagePhoto(postbox: Postbox, photoReference: ImageMediaReference) -> Signal<UIImage?, NoError> {
    return chatMessagePhotoDatas(postbox: postbox, photoReference: photoReference, autoFetchFullSize: true)
    |> map { value -> UIImage? in
        let thumbnailData = value._0
        let fullSizeData = value._1
        let fullSizeComplete = value._3
        if let fullSizeData = fullSizeData {
            if fullSizeComplete {
                return UIImage(data: fullSizeData)?.precomposed()
            }
        }
        if let thumbnailData = thumbnailData {
            return UIImage(data: thumbnailData)?.precomposed()
        }
        return nil
    }
}

public func chatMessagePhoto(postbox: Postbox, photoReference: ImageMediaReference, synchronousLoad: Bool = false, highQuality: Bool = false) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    return chatMessagePhotoInternal(photoData: chatMessagePhotoDatas(postbox: postbox, photoReference: photoReference, tryAdditionalRepresentations: true, synchronousLoad: synchronousLoad), synchronousLoad: synchronousLoad)
    |> map { _, _, generate in
        return generate
    }
}

public enum ChatMessagePhotoQuality {
    case none
    case blurred
    case medium
    case full
}

public func chatMessagePhotoInternal(photoData: Signal<Tuple4<Data?, Data?, ChatMessagePhotoQuality, Bool>, NoError>, synchronousLoad: Bool = false) -> Signal<(() -> CGSize?, ChatMessagePhotoQuality, (TransformImageArguments) -> DrawingContext?), NoError> {
    return photoData
    |> map { value in
        let thumbnailData = value._0
        let fullSizeData = value._1
        let quality = value._2
        let fullSizeComplete = value._3
        return ({
            return nil
        }, quality, { arguments in            
            let drawingRect = arguments.drawingRect
            var fittedSize = arguments.imageSize
            if abs(fittedSize.width - arguments.boundingSize.width).isLessThanOrEqualTo(CGFloat(1.0)) {
                fittedSize.width = arguments.boundingSize.width
            }
            if abs(fittedSize.height - arguments.boundingSize.height).isLessThanOrEqualTo(CGFloat(1.0)) {
                fittedSize.height = arguments.boundingSize.height
            }
            
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            
            var fullSizeImage: CGImage?
            var imageOrientation: UIImage.Orientation = .up
            if let fullSizeData = fullSizeData {
                if fullSizeComplete {
                    let options = NSMutableDictionary()
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                    if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                        imageOrientation = imageOrientationFromSource(imageSource)
                        fullSizeImage = image
                    }
                } else {
                    let imageSource = CGImageSourceCreateIncremental(nil)
                    CGImageSourceUpdateData(imageSource, fullSizeData as CFData, fullSizeComplete)
                    
                    let options = NSMutableDictionary()
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                    if let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                        imageOrientation = imageOrientationFromSource(imageSource)
                        fullSizeImage = image
                    }
                }
            }
            
            var thumbnailImage: CGImage?
            if let thumbnailData = thumbnailData, let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                thumbnailImage = image
            }
            
            if quality == .blurred && fullSizeImage != nil {
                thumbnailImage = fullSizeImage
                fullSizeImage = nil
            }
                        
            var blurredThumbnailImage: UIImage?
            if let thumbnailImage = thumbnailImage {
                let thumbnailSize = CGSize(width: thumbnailImage.width, height: thumbnailImage.height)
                
                if thumbnailSize.width > 200.0 && thumbnailSize.height > 200.0 {
                    blurredThumbnailImage = UIImage(cgImage: thumbnailImage)
                } else {
                    let initialThumbnailContextFittingSize = fittedSize.fitted(CGSize(width: 90.0, height: 90.0))
                    
                    let thumbnailContextSize = thumbnailSize.aspectFitted(initialThumbnailContextFittingSize)
                    let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                    thumbnailContext.withFlippedContext { c in
                        c.draw(thumbnailImage, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                    }
                    telegramFastBlurMore(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                    
                    var thumbnailContextFittingSize = CGSize(width: floor(arguments.drawingSize.width * 0.5), height: floor(arguments.drawingSize.width * 0.5))
                    if thumbnailContextFittingSize.width < 150.0 || thumbnailContextFittingSize.height < 150.0 {
                        thumbnailContextFittingSize = thumbnailContextFittingSize.aspectFilled(CGSize(width: 150.0, height: 150.0))
                    }
                    
                    if thumbnailContextFittingSize.width > thumbnailContextSize.width {
                        let additionalContextSize = thumbnailContextFittingSize
                        let additionalBlurContext = DrawingContext(size: additionalContextSize, scale: 1.0)
                        additionalBlurContext.withFlippedContext { c in
                            c.interpolationQuality = .default
                            if let image = thumbnailContext.generateImage()?.cgImage {
                                c.draw(image, in: CGRect(origin: CGPoint(), size: additionalContextSize))
                            }
                        }
                        imageFastBlur(Int32(additionalContextSize.width), Int32(additionalContextSize.height), Int32(additionalBlurContext.bytesPerRow), additionalBlurContext.bytes)
                        blurredThumbnailImage = additionalBlurContext.generateImage()
                    } else {
                        blurredThumbnailImage = thumbnailContext.generateImage()
                    }
                }
            }
            
            if let blurredThumbnailImage = blurredThumbnailImage, fullSizeImage == nil, arguments.corners.isEmpty {
                let context = DrawingContext(size: blurredThumbnailImage.size, scale: blurredThumbnailImage.scale, clear: true)
                context.withFlippedContext { c in
                    c.setBlendMode(.copy)
                    if let cgImage = blurredThumbnailImage.cgImage {
                        c.interpolationQuality = .none
                        drawImage(context: c, image: cgImage, orientation: imageOrientation, in: CGRect(origin: CGPoint(), size: blurredThumbnailImage.size))
                        c.setBlendMode(.normal)
                    }
                }
                return context
            }
            
            let context = DrawingContext(size: arguments.drawingSize, scale: arguments.scale ?? 0.0, clear: true)
            
            context.withFlippedContext { c in
                c.setBlendMode(.copy)
                if thumbnailImage == nil && fullSizeImage == nil {
                    let color = arguments.emptyColor ?? UIColor.white
                    c.setFillColor(color.cgColor)
                    c.fill(drawingRect)
                } else {
                    if arguments.imageSize.width < arguments.boundingSize.width || arguments.imageSize.height < arguments.boundingSize.height {
                        let blurSourceImage = thumbnailImage ?? fullSizeImage
                        
                        if let fullSizeImage = blurSourceImage {
                            let thumbnailSize = CGSize(width: fullSizeImage.width, height: fullSizeImage.height)
                            
                            var sideBlurredImage: UIImage?
                            let initialThumbnailContextFittingSize = fittedSize.fitted(CGSize(width: 100.0, height: 100.0))
                            
                            let thumbnailContextSize = thumbnailSize.aspectFitted(initialThumbnailContextFittingSize)
                            let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                            thumbnailContext.withFlippedContext { c in
                                c.interpolationQuality = .none
                                c.draw(fullSizeImage, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                            }
                            imageFastBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                            
                            var thumbnailContextFittingSize = CGSize(width: floor(arguments.drawingSize.width * 0.5), height: floor(arguments.drawingSize.width * 0.5))
                            if thumbnailContextFittingSize.width < 150.0 || thumbnailContextFittingSize.height < 150.0 {
                                thumbnailContextFittingSize = thumbnailContextFittingSize.aspectFilled(CGSize(width: 150.0, height: 150.0))
                            }
                            
                            if thumbnailContextFittingSize.width > thumbnailContextSize.width {
                                let additionalContextSize = thumbnailContextFittingSize
                                let additionalBlurContext = DrawingContext(size: additionalContextSize, scale: 1.0)
                                additionalBlurContext.withFlippedContext { c in
                                    c.interpolationQuality = .default
                                    if let image = thumbnailContext.generateImage()?.cgImage {
                                        c.draw(image, in: CGRect(origin: CGPoint(), size: additionalContextSize))
                                    }
                                }
                                imageFastBlur(Int32(additionalContextSize.width), Int32(additionalContextSize.height), Int32(additionalBlurContext.bytesPerRow), additionalBlurContext.bytes)
                                sideBlurredImage = additionalBlurContext.generateImage()
                            } else {
                                sideBlurredImage = thumbnailContext.generateImage()
                            }
                                
                                
                            if let blurredImage = sideBlurredImage {
                                let filledSize = thumbnailSize.aspectFilled(arguments.drawingRect.size)
                                c.interpolationQuality = .medium
                                c.draw(blurredImage.cgImage!, in: CGRect(origin: CGPoint(x:arguments.drawingRect.minX + (arguments.drawingRect.width - filledSize.width) / 2.0, y: arguments.drawingRect.minY + (arguments.drawingRect.height - filledSize.height) / 2.0), size: filledSize))
                                c.setBlendMode(.normal)
                                c.setFillColor((arguments.emptyColor ?? UIColor.white).withAlphaComponent(0.05).cgColor)
                                c.fill(arguments.drawingRect)
                                c.setBlendMode(.copy)
                            }
                        } else {
                            c.setFillColor((arguments.emptyColor ?? UIColor.white).cgColor)
                            c.fill(arguments.drawingRect)
                        }
                    }
                    
                    c.setBlendMode(.copy)
                    if let blurredThumbnailImage = blurredThumbnailImage, let cgImage = blurredThumbnailImage.cgImage {
                        c.interpolationQuality = .low
                        drawImage(context: c, image: cgImage, orientation: imageOrientation, in: fittedRect)
                        c.setBlendMode(.normal)
                    }
                    
                    if let fullSizeImage = fullSizeImage {
                        c.interpolationQuality = .medium
                        drawImage(context: c, image: fullSizeImage, orientation: imageOrientation, in: fittedRect)
                    }
                }
            }
            
            addCorners(context, arguments: arguments)
            
            return context
        })
    }
}

private func chatMessagePhotoThumbnailDatas(account: Account, photoReference: ImageMediaReference, onlyFullSize: Bool = false) -> Signal<Tuple3<Data?, Data?, Bool>, NoError> {
    let fullRepresentationSize: CGSize = CGSize(width: 1280.0, height: 1280.0)
    if let smallestRepresentation = smallestImageRepresentation(photoReference.media.representations), let largestRepresentation = photoReference.media.representationForDisplayAtSize(PixelDimensions(width: Int32(fullRepresentationSize.width), height: Int32(fullRepresentationSize.height))) {
        
        let maybeFullSize = account.postbox.mediaBox.cachedResourceRepresentation(largestRepresentation.resource, representation: CachedScaledImageRepresentation(size: CGSize(width: 180.0, height: 180.0), mode: .aspectFit), complete: onlyFullSize, fetch: false)
        let fetchedFullSize = account.postbox.mediaBox.cachedResourceRepresentation(largestRepresentation.resource, representation: CachedScaledImageRepresentation(size: CGSize(width: 180.0, height: 180.0), mode: .aspectFit), complete: onlyFullSize, fetch: true)
        
        let signal = maybeFullSize
        |> take(1)
        |> mapToSignal { maybeData -> Signal<Tuple3<Data?, Data?, Bool>, NoError> in
            if maybeData.complete {
                let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [])
                return .single(Tuple(nil, loadedData, true))
            } else {
                let fetchedThumbnail = fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: photoReference.resourceReference(smallestRepresentation.resource), statsCategory: .image)
                
                let thumbnail = Signal<Data?, NoError> { subscriber in
                    let fetchedDisposable = fetchedThumbnail.start()
                    let thumbnailDisposable = account.postbox.mediaBox.resourceData(smallestRepresentation.resource).start(next: { next in
                        subscriber.putNext(next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []))
                    }, error: subscriber.putError, completed: subscriber.putCompletion)
                    
                    return ActionDisposable {
                        fetchedDisposable.dispose()
                        thumbnailDisposable.dispose()
                    }
                }
                
                let fullSizeData: Signal<Tuple2<Data?, Bool>, NoError> = fetchedFullSize
                |> map { next -> Tuple2<Data?, Bool> in
                    return Tuple(next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []), next.complete)
                }
                
                return thumbnail
                |> mapToSignal { thumbnailData in
                    return fullSizeData
                    |> map { value in
                        return Tuple(thumbnailData, value._0, value._1)
                    }
                }
            }
        }
        |> filter({ $0._0 != nil || $0._1 != nil })
        
        return signal
    } else {
        return .never()
    }
}

public func chatMessagePhotoThumbnail(account: Account, photoReference: ImageMediaReference, onlyFullSize: Bool = false) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    let signal = chatMessagePhotoThumbnailDatas(account: account, photoReference: photoReference, onlyFullSize: onlyFullSize)
    return signal
    |> map { value in
        let thumbnailData = value._0
        let fullSizeData = value._1
        let fullSizeComplete = value._2
        return { arguments in
            let context = DrawingContext(size: arguments.drawingSize, scale: arguments.scale ?? 0.0, clear: true)
            
            let drawingRect = arguments.drawingRect
            var fittedSize = arguments.imageSize
            if abs(fittedSize.width - arguments.boundingSize.width).isLessThanOrEqualTo(CGFloat(1.0)) {
                fittedSize.width = arguments.boundingSize.width
            }
            if abs(fittedSize.height - arguments.boundingSize.height).isLessThanOrEqualTo(CGFloat(1.0)) {
                fittedSize.height = arguments.boundingSize.height
            }
            
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            
            var fullSizeImage: CGImage?
            var imageOrientation: UIImage.Orientation = .up
            if let fullSizeData = fullSizeData {
                if fullSizeComplete {
                    let options = NSMutableDictionary()
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                    if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                        imageOrientation = imageOrientationFromSource(imageSource)
                        fullSizeImage = image
                    }
                } else {
                    let imageSource = CGImageSourceCreateIncremental(nil)
                    CGImageSourceUpdateData(imageSource, fullSizeData as CFData, fullSizeComplete)
                    
                    let options = NSMutableDictionary()
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                    if let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                        imageOrientation = imageOrientationFromSource(imageSource)
                        fullSizeImage = image
                    }
                }
            }
            
            var thumbnailImage: CGImage?
            if let thumbnailData = thumbnailData, let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                thumbnailImage = image
            }
            
            var blurredThumbnailImage: UIImage?
            if let thumbnailImage = thumbnailImage {
                let thumbnailSize = CGSize(width: thumbnailImage.width, height: thumbnailImage.height)
                let thumbnailContextSize = thumbnailSize.aspectFitted(CGSize(width: 150.0, height: 150.0))
                let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                thumbnailContext.withFlippedContext { c in
                    c.interpolationQuality = .none
                    c.draw(thumbnailImage, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                }
                imageFastBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                
                blurredThumbnailImage = thumbnailContext.generateImage()
            }
            
            context.withFlippedContext { c in
                c.setBlendMode(.copy)
                if arguments.imageSize.width < arguments.boundingSize.width || arguments.imageSize.height < arguments.boundingSize.height {
                    c.setFillColor((arguments.emptyColor ?? UIColor.white).cgColor)
                    c.fill(arguments.drawingRect)
                }
                
                c.setBlendMode(.copy)
                if let blurredThumbnailImage = blurredThumbnailImage, let cgImage = blurredThumbnailImage.cgImage {
                    c.interpolationQuality = .low
                    drawImage(context: c, image: cgImage, orientation: imageOrientation, in: fittedRect)
                    c.setBlendMode(.normal)
                }
                
                if let fullSizeImage = fullSizeImage {
                    c.interpolationQuality = .medium
                    drawImage(context: c, image: fullSizeImage, orientation: imageOrientation, in: fittedRect)
                }
            }
            
            addCorners(context, arguments: arguments)
            
            return context
        }
    }
}

public func chatMessageVideoThumbnail(account: Account, fileReference: FileMediaReference) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    let signal = chatMessageVideoDatas(postbox: account.postbox, fileReference: fileReference, thumbnailSize: true, autoFetchFullSizeThumbnail: true)
    
    return signal
    |> map { value in
        let thumbnailData = value._0
        let fullSizeData = value._1
        let fullSizeComplete = value._2
        return { arguments in
            let context = DrawingContext(size: arguments.drawingSize, scale: arguments.scale ?? 0.0, clear: true)
            
            let drawingRect = arguments.drawingRect
            var fittedSize = arguments.imageSize
            if abs(fittedSize.width - arguments.boundingSize.width).isLessThanOrEqualTo(CGFloat(1.0)) {
                fittedSize.width = arguments.boundingSize.width
            }
            if abs(fittedSize.height - arguments.boundingSize.height).isLessThanOrEqualTo(CGFloat(1.0)) {
                fittedSize.height = arguments.boundingSize.height
            }
            
            if arguments.intrinsicInsets != UIEdgeInsets.zero {
                fittedSize.width -= arguments.intrinsicInsets.left + arguments.intrinsicInsets.right
                fittedSize.height -= arguments.intrinsicInsets.top + arguments.intrinsicInsets.bottom
            }
            
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            
            var fullSizeImage: CGImage?
            var imageOrientation: UIImage.Orientation = .up
            if let fullSizeData = fullSizeData?._0 {
                if fullSizeComplete {
                    let options = NSMutableDictionary()
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                    if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                        imageOrientation = imageOrientationFromSource(imageSource)
                        fullSizeImage = image
                    }
                } else {
                    let imageSource = CGImageSourceCreateIncremental(nil)
                    CGImageSourceUpdateData(imageSource, fullSizeData as CFData, fullSizeComplete)
                    
                    let options = NSMutableDictionary()
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                    if let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                        imageOrientation = imageOrientationFromSource(imageSource)
                        fullSizeImage = image
                    }
                }
            }
            
            var thumbnailImage: CGImage?
            if let thumbnailData = thumbnailData, let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                thumbnailImage = image
            }
            
            var blurredThumbnailImage: UIImage?
            if let thumbnailImage = thumbnailImage {
                if max(thumbnailImage.width, thumbnailImage.height) > 200 {
                    blurredThumbnailImage = UIImage(cgImage: thumbnailImage)
                } else {
                    let thumbnailSize = CGSize(width: thumbnailImage.width, height: thumbnailImage.height)
                    let thumbnailContextSize = thumbnailSize.aspectFitted(CGSize(width: 150.0, height: 150.0))
                    let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                    thumbnailContext.withFlippedContext { c in
                        c.interpolationQuality = .none
                        c.draw(thumbnailImage, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                    }
                    imageFastBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                    
                    blurredThumbnailImage = thumbnailContext.generateImage()
                }
            }
            
            context.withFlippedContext { c in
                c.setBlendMode(.copy)
                if arguments.imageSize.width < arguments.boundingSize.width || arguments.imageSize.height < arguments.boundingSize.height {
                    c.setFillColor((arguments.emptyColor ?? UIColor.white).cgColor)
                    c.fill(arguments.drawingRect)
                }
                
                c.setBlendMode(.copy)
                if let blurredThumbnailImage = blurredThumbnailImage, let cgImage = blurredThumbnailImage.cgImage {
                    c.interpolationQuality = .low
                    drawImage(context: c, image: cgImage, orientation: imageOrientation, in: fittedRect)
                    c.setBlendMode(.normal)
                }
                
                if let fullSizeImage = fullSizeImage {
                    c.interpolationQuality = .medium
                    drawImage(context: c, image: fullSizeImage, orientation: imageOrientation, in: fittedRect)
                }
            }
            
            addCorners(context, arguments: arguments)
            
            return context
        }
    }
}

public func chatSecretPhoto(account: Account, photoReference: ImageMediaReference) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    let signal = chatMessagePhotoDatas(postbox: account.postbox, photoReference: photoReference)
    return signal
    |> map { value in
        let thumbnailData = value._0
        let fullSizeData = value._1
        let fullSizeComplete = value._3
        return { arguments in
            let context = DrawingContext(size: arguments.drawingSize, clear: true)
            
            let drawingRect = arguments.drawingRect
            var fittedSize = arguments.imageSize
            if abs(fittedSize.width - arguments.boundingSize.width).isLessThanOrEqualTo(CGFloat(1.0)) {
                fittedSize.width = arguments.boundingSize.width
            }
            if abs(fittedSize.height - arguments.boundingSize.height).isLessThanOrEqualTo(CGFloat(1.0)) {
                fittedSize.height = arguments.boundingSize.height
            }
            
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            
            var blurredImage: UIImage?
            
            if let fullSizeData = fullSizeData {
                if fullSizeComplete {
                    let options = NSMutableDictionary()
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                    if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                        let thumbnailSize = CGSize(width: image.width, height: image.height)
                        let thumbnailContextSize = thumbnailSize.aspectFilled(CGSize(width: 20.0, height: 20.0))
                        let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                        thumbnailContext.withFlippedContext { c in
                            c.interpolationQuality = .none
                            c.draw(image, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                        }
                        imageFastBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                        
                        let thumbnailContext2Size = thumbnailSize.aspectFitted(CGSize(width: 100.0, height: 100.0))
                        let thumbnailContext2 = DrawingContext(size: thumbnailContext2Size, scale: 1.0)
                        thumbnailContext2.withFlippedContext { c in
                            c.interpolationQuality = .none
                            if let image = thumbnailContext.generateImage()?.cgImage {
                                c.draw(image, in: CGRect(origin: CGPoint(), size: thumbnailContext2Size))
                            }
                        }
                        imageFastBlur(Int32(thumbnailContext2Size.width), Int32(thumbnailContext2Size.height), Int32(thumbnailContext2.bytesPerRow), thumbnailContext2.bytes)
                        
                        blurredImage = thumbnailContext2.generateImage()
                    }
                }
            }
            
            if blurredImage == nil {
                if let thumbnailData = thumbnailData, let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                    let thumbnailSize = CGSize(width: image.width, height: image.height)
                    let thumbnailContextSize = thumbnailSize.aspectFilled(CGSize(width: 20.0, height: 20.0))
                    let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                    thumbnailContext.withFlippedContext { c in
                        c.interpolationQuality = .none
                        c.draw(image, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                    }
                    imageFastBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                    
                    let thumbnailContext2Size = thumbnailSize.aspectFitted(CGSize(width: 100.0, height: 100.0))
                    let thumbnailContext2 = DrawingContext(size: thumbnailContext2Size, scale: 1.0)
                    thumbnailContext2.withFlippedContext { c in
                        c.interpolationQuality = .none
                        if let image = thumbnailContext.generateImage()?.cgImage {
                            c.draw(image, in: CGRect(origin: CGPoint(), size: thumbnailContext2Size))
                        }
                    }
                    imageFastBlur(Int32(thumbnailContext2Size.width), Int32(thumbnailContext2Size.height), Int32(thumbnailContext2.bytesPerRow), thumbnailContext2.bytes)
                    
                    blurredImage = thumbnailContext2.generateImage()
                }
            }
            
            context.withFlippedContext { c in
                c.setBlendMode(.copy)
                if arguments.imageSize.width < arguments.boundingSize.width || arguments.imageSize.height < arguments.boundingSize.height {
                    c.setFillColor((arguments.emptyColor ?? UIColor.white).cgColor)
                    c.fill(arguments.drawingRect)
                }
                
                c.setBlendMode(.copy)
                if let blurredImage = blurredImage, let cgImage = blurredImage.cgImage {
                    c.interpolationQuality = .low
                    drawImage(context: c, image: cgImage, orientation: .up, in: fittedRect)
                }
                
                if !arguments.insets.left.isEqual(to: 0.0) {
                    c.clear(CGRect(origin: CGPoint(), size: CGSize(width: arguments.insets.left, height: context.size.height)))
                }
                if !arguments.insets.right.isEqual(to: 0.0) {
                    c.clear(CGRect(origin: CGPoint(x: context.size.width - arguments.insets.right, y: 0.0), size: CGSize(width: arguments.insets.right, height: context.size.height)))
                }
            }
            
            addCorners(context, arguments: arguments)
            
            return context
        }
    }
}

private func avatarGalleryThumbnailDatas(postbox: Postbox, representations: [ImageRepresentationWithReference], fullRepresentationSize: CGSize = CGSize(width: 1280.0, height: 1280.0), autoFetchFullSize: Bool = false, synchronousLoad: Bool) -> Signal<Tuple3<Data?, Data?, Bool>, NoError> {
    if let smallestRepresentation = smallestImageRepresentation(representations.map({ $0.representation })), let largestRepresentation = imageRepresentationLargerThan(representations.map({ $0.representation }), size: PixelDimensions(width: Int32(fullRepresentationSize.width), height: Int32(fullRepresentationSize.height))), let smallestIndex = representations.firstIndex(where: { $0.representation == smallestRepresentation }), let largestIndex = representations.firstIndex(where: { $0.representation == largestRepresentation }) {
        let maybeFullSize = postbox.mediaBox.resourceData(largestRepresentation.resource, attemptSynchronously: synchronousLoad)
        
        let signal = maybeFullSize
        |> take(1)
        |> mapToSignal { maybeData -> Signal<Tuple3<Data?, Data?, Bool>, NoError> in
            if maybeData.complete {
                let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [])
                return .single(Tuple(nil, loadedData, true))
            } else {
                let fetchedThumbnail = fetchedMediaResource(mediaBox: postbox.mediaBox, reference: representations[smallestIndex].reference, statsCategory: .image)
                let fetchedFullSize = fetchedMediaResource(mediaBox: postbox.mediaBox, reference: representations[largestIndex].reference, statsCategory: .image)
                
                let thumbnail = Signal<Data?, NoError> { subscriber in
                    let fetchedDisposable = fetchedThumbnail.start()
                    let thumbnailDisposable = postbox.mediaBox.resourceData(smallestRepresentation.resource).start(next: { next in
                        subscriber.putNext(next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []))
                    }, error: subscriber.putError, completed: subscriber.putCompletion)
                    
                    return ActionDisposable {
                        fetchedDisposable.dispose()
                        thumbnailDisposable.dispose()
                    }
                }
                
                let fullSizeData: Signal<Tuple2<Data?, Bool>, NoError>
                
                if autoFetchFullSize {
                    fullSizeData = Signal<Tuple2<Data?, Bool>, NoError> { subscriber in
                        let fetchedFullSizeDisposable = fetchedFullSize.start()
                        let fullSizeDisposable = postbox.mediaBox.resourceData(largestRepresentation.resource).start(next: { next in
                            subscriber.putNext(Tuple(next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []), next.complete))
                        }, error: subscriber.putError, completed: subscriber.putCompletion)
                        
                        return ActionDisposable {
                            fetchedFullSizeDisposable.dispose()
                            fullSizeDisposable.dispose()
                        }
                    }
                } else {
                    fullSizeData = postbox.mediaBox.resourceData(largestRepresentation.resource)
                    |> map { next -> Tuple2<Data?, Bool> in
                        return Tuple(next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []), next.complete)
                    }
                }
                
                
                return thumbnail
                |> mapToSignal { thumbnailData in
                    return fullSizeData
                    |> map { value in
                        return Tuple(thumbnailData, value._0, value._1)
                    }
                }
            }
            } |> distinctUntilChanged(isEqual: { lhs, rhs in
                if (lhs._0 == nil && lhs._1 == nil) && (rhs._0 == nil && rhs._1 == nil) {
                    return true
                } else {
                    return false
                }
            })
        
        return signal
    } else {
        return .never()
    }
}

public func avatarGalleryThumbnailPhoto(account: Account, representations: [ImageRepresentationWithReference], synchronousLoad: Bool) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    let signal = avatarGalleryThumbnailDatas(postbox: account.postbox, representations: representations, fullRepresentationSize: CGSize(width: 127.0, height: 127.0), autoFetchFullSize: true, synchronousLoad: synchronousLoad)
    return signal
    |> map { value in
        let thumbnailData = value._0
        let fullSizeData = value._1
        let fullSizeComplete = value._2
        
        return { arguments in
            let context = DrawingContext(size: arguments.drawingSize, clear: true)
            
            let drawingRect = arguments.drawingRect
            let fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize).fitted(arguments.imageSize)
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            
            var fullSizeImage: CGImage?
            var imageOrientation: UIImage.Orientation = .up
            if let fullSizeData = fullSizeData {
                if fullSizeComplete {
                    let options = NSMutableDictionary()
                    options.setValue(max(fittedSize.width * context.scale, fittedSize.height * context.scale) as NSNumber, forKey: kCGImageSourceThumbnailMaxPixelSize as String)
                    options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailFromImageAlways as String)
                    if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, nil), let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) {
                        imageOrientation = imageOrientationFromSource(imageSource)
                        fullSizeImage = image
                    }
                } else {
                    let imageSource = CGImageSourceCreateIncremental(nil)
                    CGImageSourceUpdateData(imageSource, fullSizeData as CFData, fullSizeComplete)
                    
                    let options = NSMutableDictionary()
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                    if let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                        imageOrientation = imageOrientationFromSource(imageSource)
                        fullSizeImage = image
                    }
                }
            }
            
            var thumbnailImage: CGImage?
            if let thumbnailData = thumbnailData, let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                thumbnailImage = image
            }
            
            var blurredThumbnailImage: UIImage?
            if let thumbnailImage = thumbnailImage {
                let thumbnailSize = CGSize(width: thumbnailImage.width, height: thumbnailImage.height)
                let thumbnailContextSize = thumbnailSize.aspectFitted(CGSize(width: 150.0, height: 150.0))
                let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                thumbnailContext.withFlippedContext { c in
                    c.interpolationQuality = .none
                    c.draw(thumbnailImage, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                }
                imageFastBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                
                blurredThumbnailImage = thumbnailContext.generateImage()
            }
            
            context.withFlippedContext { c in
                c.setBlendMode(.copy)
                if arguments.boundingSize != arguments.imageSize {
                    c.fill(arguments.drawingRect)
                }
                
                c.setBlendMode(.copy)
                if let blurredThumbnailImage = blurredThumbnailImage, let cgImage = blurredThumbnailImage.cgImage {
                    c.interpolationQuality = .low
                    drawImage(context: c, image: cgImage, orientation: imageOrientation, in: fittedRect)
                    c.setBlendMode(.normal)
                }
                
                if let fullSizeImage = fullSizeImage {
                    c.interpolationQuality = .medium
                    drawImage(context: c, image: fullSizeImage, orientation: imageOrientation, in: fittedRect)
                }
            }
            
            addCorners(context, arguments: arguments)
            
            return context
        }
    }
}

public func mediaGridMessagePhoto(account: Account, photoReference: ImageMediaReference, fullRepresentationSize: CGSize = CGSize(width: 127.0, height: 127.0), synchronousLoad: Bool = false) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    let useMiniThumbnailIfAvailable: Bool = fullRepresentationSize.width < 40.0
    var updatedFullRepresentationSize = fullRepresentationSize
    if useMiniThumbnailIfAvailable, let largest = largestImageRepresentation(photoReference.media.representations) {
        if progressiveImageRepresentation(photoReference.media.representations) == nil {
            updatedFullRepresentationSize = largest.dimensions.cgSize
        }
    }
    let signal = chatMessagePhotoDatas(postbox: account.postbox, photoReference: photoReference, fullRepresentationSize: updatedFullRepresentationSize, autoFetchFullSize: true, tryAdditionalRepresentations: useMiniThumbnailIfAvailable, synchronousLoad: synchronousLoad, useMiniThumbnailIfAvailable: useMiniThumbnailIfAvailable)
    
    return signal
    |> map { value in
        let thumbnailData = value._0
        let fullSizeData = value._1
        let fullSizeComplete = value._3
        return { arguments in
            let context = DrawingContext(size: arguments.drawingSize, clear: true)
            
            let drawingRect = arguments.drawingRect
            let fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize).fitted(arguments.imageSize)
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            
            var fullSizeImage: CGImage?
            var imageOrientation: UIImage.Orientation = .up
            if let fullSizeData = fullSizeData {
                if fullSizeComplete {
                    let options = NSMutableDictionary()
                    options.setValue(400 as NSNumber, forKey: kCGImageSourceThumbnailMaxPixelSize as String)
                    options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailFromImageAlways as String)
                    if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, nil), let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) {
                        imageOrientation = imageOrientationFromSource(imageSource)
                        fullSizeImage = image
                    }
                } else {
                    let imageSource = CGImageSourceCreateIncremental(nil)
                    CGImageSourceUpdateData(imageSource, fullSizeData as CFData, fullSizeComplete)
                    
                    let options = NSMutableDictionary()
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                    if let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                        imageOrientation = imageOrientationFromSource(imageSource)
                        fullSizeImage = image
                    }
                }
            }
            
            var thumbnailImage: CGImage?
            if let thumbnailData = thumbnailData, let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                thumbnailImage = image
            }
            
            var blurredThumbnailImage: UIImage?
            if let thumbnailImage = thumbnailImage {
                if useMiniThumbnailIfAvailable {
                    blurredThumbnailImage = UIImage(cgImage: thumbnailImage)
                } else {
                    let thumbnailSize = CGSize(width: thumbnailImage.width, height: thumbnailImage.height)
                    let thumbnailContextSize = thumbnailSize.aspectFilled(CGSize(width: 90.0, height: 90.0))
                    let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                    thumbnailContext.withFlippedContext { c in
                        c.interpolationQuality = .none
                        c.draw(thumbnailImage, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                    }
                    if !useMiniThumbnailIfAvailable {
                        telegramFastBlurMore(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                    }
                    
                    blurredThumbnailImage = thumbnailContext.generateImage()
                }
            }
            
            context.withFlippedContext { c in
                c.setBlendMode(.copy)
                if arguments.boundingSize != arguments.imageSize {
                    c.setFillColor((arguments.emptyColor ?? UIColor.white).cgColor)
                    c.fill(arguments.drawingRect)
                }
                
                c.setBlendMode(.copy)
                if let blurredThumbnailImage = blurredThumbnailImage, let cgImage = blurredThumbnailImage.cgImage {
                    c.interpolationQuality = .low
                    drawImage(context: c, image: cgImage, orientation: imageOrientation, in: fittedRect)
                    c.setBlendMode(.normal)
                }
                
                if let fullSizeImage = fullSizeImage {
                    c.interpolationQuality = .medium
                    drawImage(context: c, image: fullSizeImage, orientation: imageOrientation, in: fittedRect)
                }
            }
            
            addCorners(context, arguments: arguments)
            
            return context
        }
    }
}

public func gifPaneVideoThumbnail(account: Account, videoReference: FileMediaReference) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    if let smallestRepresentation = smallestImageRepresentation(videoReference.media.previewRepresentations) {
        let thumbnailResource = smallestRepresentation.resource
        
        let thumbnail = Signal<MediaResourceData, NoError> { subscriber in
            let data = account.postbox.mediaBox.resourceData(thumbnailResource).start(next: { data in
                subscriber.putNext(data)
            }, completed: {
                subscriber.putCompletion()
            })
            let fetched = fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: videoReference.resourceReference(thumbnailResource)).start()
            return ActionDisposable {
                data.dispose()
                fetched.dispose()
            }
        }
        
        return thumbnail
        |> map { data in
            let thumbnailData = try? Data(contentsOf: URL(fileURLWithPath: data.path))
            return { arguments in
                let context = DrawingContext(size: arguments.drawingSize, clear: true)
                let drawingRect = arguments.drawingRect
                let fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize).fitted(arguments.imageSize)
                let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
                
                var thumbnailImage: CGImage?
                if let thumbnailData = thumbnailData, let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                    thumbnailImage = image
                }
                
                var blurredThumbnailImage: UIImage?
                if let thumbnailImage = thumbnailImage {
                    let thumbnailSize = CGSize(width: thumbnailImage.width, height: thumbnailImage.height)
                    let thumbnailContextSize = thumbnailSize.aspectFitted(CGSize(width: 150.0, height: 150.0))
                    let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                    thumbnailContext.withFlippedContext { c in
                        c.interpolationQuality = .none
                        c.draw(thumbnailImage, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                    }
                    imageFastBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                    
                    blurredThumbnailImage = thumbnailContext.generateImage()
                }
                
                context.withFlippedContext { c in
                    c.setBlendMode(.copy)
                    if arguments.boundingSize != arguments.imageSize {
                        c.fill(arguments.drawingRect)
                    }
                    
                    c.setBlendMode(.copy)
                    if let blurredThumbnailImage = blurredThumbnailImage, let cgImage = blurredThumbnailImage.cgImage {
                        c.interpolationQuality = .low
                        drawImage(context: c, image: cgImage, orientation: .up, in: fittedRect)
                        c.setBlendMode(.normal)
                    }
                }
                
                addCorners(context, arguments: arguments)
                
                return context
            }
        }
    } else {
        return .never()
    }
}

public func mediaGridMessageVideo(postbox: Postbox, videoReference: FileMediaReference, onlyFullSize: Bool = false, useLargeThumbnail: Bool = false, synchronousLoad: Bool = false, autoFetchFullSizeThumbnail: Bool = false, overlayColor: UIColor? = nil, nilForEmptyResult: Bool = false, useMiniThumbnailIfAvailable: Bool = false) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    return internalMediaGridMessageVideo(postbox: postbox, videoReference: videoReference, onlyFullSize: onlyFullSize, useLargeThumbnail: useLargeThumbnail, synchronousLoad: synchronousLoad, autoFetchFullSizeThumbnail: autoFetchFullSizeThumbnail, overlayColor: overlayColor, nilForEmptyResult: nilForEmptyResult, useMiniThumbnailIfAvailable: useMiniThumbnailIfAvailable)
    |> map {
        return $0.1
    }
}

public func internalMediaGridMessageVideo(postbox: Postbox, videoReference: FileMediaReference, imageReference: ImageMediaReference? = nil, onlyFullSize: Bool = false, useLargeThumbnail: Bool = false, synchronousLoad: Bool = false, autoFetchFullSizeThumbnail: Bool = false, overlayColor: UIColor? = nil, nilForEmptyResult: Bool = false, useMiniThumbnailIfAvailable: Bool = false) -> Signal<(() -> CGSize?, (TransformImageArguments) -> DrawingContext?), NoError> {
    let signal: Signal<Tuple3<Data?, Tuple2<Data, String>?, Bool>, NoError>
    if let imageReference = imageReference {
        signal = chatMessagePhotoDatas(postbox: postbox, photoReference: imageReference, tryAdditionalRepresentations: true, synchronousLoad: synchronousLoad)
        |> map { value -> Tuple3<Data?, Tuple2<Data, String>?, Bool> in
            let thumbnailData = value._0
            let fullSizeData = value._1
            let fullSizeComplete = value._3
            return Tuple(thumbnailData, fullSizeData.flatMap({ Tuple($0, "") }), fullSizeComplete)
        }
    } else {
        signal = chatMessageVideoDatas(postbox: postbox, fileReference: videoReference, onlyFullSize: onlyFullSize, useLargeThumbnail: useLargeThumbnail, synchronousLoad: synchronousLoad, autoFetchFullSizeThumbnail: autoFetchFullSizeThumbnail)
    }
    
    return signal
    |> map { value in
        let thumbnailData = value._0
        let fullSizeData = value._1
        let fullSizeComplete = value._2
        return ({
            var fullSizeImage: CGImage?
            if let fullSizeData = fullSizeData {
                if fullSizeComplete {
                    let options = NSMutableDictionary()
                    if let imageSource = CGImageSourceCreateWithData(fullSizeData._0 as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                        fullSizeImage = image
                    }
                }
            }
            if let fullSizeImage = fullSizeImage {
                return CGSize(width: CGFloat(fullSizeImage.width), height: CGFloat(fullSizeImage.height))
            }
            return nil
        }, { arguments in
            if nilForEmptyResult {
                if thumbnailData == nil && fullSizeData == nil {
                    return nil
                }
            }
            
            let context = DrawingContext(size: arguments.drawingSize, clear: true)
            
            let drawingRect = arguments.drawingRect
            var drawingSize: CGSize
            if case .aspectFill = arguments.resizeMode {
                drawingSize = arguments.imageSize.aspectFilled(arguments.boundingSize)
            } else {
                drawingSize = arguments.imageSize.aspectFilled(arguments.boundingSize).fitted(arguments.imageSize)
            }
            if drawingSize.width < drawingRect.size.width && drawingSize.width >= drawingRect.size.width - 2.0 {
                drawingSize.width = drawingRect.size.width
            }
            if drawingSize.height < drawingRect.size.height && drawingSize.height >= drawingRect.size.height - 2.0 {
                drawingSize.height = drawingRect.size.height
            }
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - drawingSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - drawingSize.height) / 2.0), size: drawingSize)
            
            var fullSizeImage: CGImage?
            var imageOrientation: UIImage.Orientation = .up
            if let fullSizeData = fullSizeData {
                if fullSizeComplete {
                    let options = NSMutableDictionary()
                    if let imageSource = CGImageSourceCreateWithData(fullSizeData._0 as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                        imageOrientation = imageOrientationFromSource(imageSource)
                        fullSizeImage = image
                    }
                } else {
                    let imageSource = CGImageSourceCreateIncremental(nil)
                    CGImageSourceUpdateData(imageSource, fullSizeData._0 as CFData, fullSizeComplete)
                    
                    let options = NSMutableDictionary()
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                    if let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                        imageOrientation = imageOrientationFromSource(imageSource)
                        fullSizeImage = image
                    }
                }
            }
            
            var thumbnailImage: CGImage?
            if let thumbnailData = thumbnailData, let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                thumbnailImage = image
            }
            
            var blurredThumbnailImage: UIImage?
            if let thumbnailImage = thumbnailImage {
                if max(thumbnailImage.width, thumbnailImage.height) > Int(min(200.0, min(drawingSize.width, drawingSize.height))) || useMiniThumbnailIfAvailable {
                    blurredThumbnailImage = UIImage(cgImage: thumbnailImage)
                } else {
                    let thumbnailSize = CGSize(width: thumbnailImage.width, height: thumbnailImage.height)
                    let initialThumbnailContextFittingSize = drawingSize.fitted(CGSize(width: 90.0, height: 90.0))
                    
                    let thumbnailContextSize = thumbnailSize.aspectFitted(initialThumbnailContextFittingSize)
                    let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                    thumbnailContext.withFlippedContext { c in
                        c.draw(thumbnailImage, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                    }
                    telegramFastBlurMore(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                    
                    var thumbnailContextFittingSize = CGSize(width: floor(arguments.drawingSize.width * 0.5), height: floor(arguments.drawingSize.width * 0.5))
                    if thumbnailContextFittingSize.width < 150.0 || thumbnailContextFittingSize.height < 150.0 {
                        thumbnailContextFittingSize = thumbnailContextFittingSize.aspectFilled(CGSize(width: 150.0, height: 150.0))
                    }
                    
                    if thumbnailContextFittingSize.width > thumbnailContextSize.width {
                        let additionalContextSize = thumbnailContextFittingSize
                        let additionalBlurContext = DrawingContext(size: additionalContextSize, scale: 1.0)
                        additionalBlurContext.withFlippedContext { c in
                            c.interpolationQuality = .default
                            if let image = thumbnailContext.generateImage()?.cgImage {
                                c.draw(image, in: CGRect(origin: CGPoint(), size: additionalContextSize))
                            }
                        }
                        imageFastBlur(Int32(additionalContextSize.width), Int32(additionalContextSize.height), Int32(additionalBlurContext.bytesPerRow), additionalBlurContext.bytes)
                        blurredThumbnailImage = additionalBlurContext.generateImage()
                    } else {
                        blurredThumbnailImage = thumbnailContext.generateImage()
                    }
                }
            }
            
            context.withFlippedContext { c in
                c.setBlendMode(.copy)
                if arguments.boundingSize != arguments.imageSize {
                    switch arguments.resizeMode {
                        case .blurBackground:
                            let blurSourceImage = thumbnailImage ?? fullSizeImage
                            
                            if let fullSizeImage = blurSourceImage {
                                var sideBlurredImage: UIImage?
                                let thumbnailSize = CGSize(width: fullSizeImage.width, height: fullSizeImage.height)
                                let initialThumbnailContextFittingSize = drawingSize.fitted(CGSize(width: 100.0, height: 100.0))
                                
                                let thumbnailContextSize = thumbnailSize.aspectFitted(initialThumbnailContextFittingSize)
                                let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                                thumbnailContext.withFlippedContext { c in
                                    c.interpolationQuality = .none
                                    c.draw(fullSizeImage, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                                }
                                imageFastBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                                
                                var thumbnailContextFittingSize = CGSize(width: floor(arguments.drawingSize.width * 0.5), height: floor(arguments.drawingSize.width * 0.5))
                                if thumbnailContextFittingSize.width < 150.0 || thumbnailContextFittingSize.height < 150.0 {
                                    thumbnailContextFittingSize = thumbnailContextFittingSize.aspectFilled(CGSize(width: 150.0, height: 150.0))
                                }
                                
                                if thumbnailContextFittingSize.width > thumbnailContextSize.width {
                                    let additionalContextSize = thumbnailContextFittingSize
                                    let additionalBlurContext = DrawingContext(size: additionalContextSize, scale: 1.0)
                                    additionalBlurContext.withFlippedContext { c in
                                        c.interpolationQuality = .default
                                        if let image = thumbnailContext.generateImage()?.cgImage {
                                            c.draw(image, in: CGRect(origin: CGPoint(), size: additionalContextSize))
                                        }
                                    }
                                    imageFastBlur(Int32(additionalContextSize.width), Int32(additionalContextSize.height), Int32(additionalBlurContext.bytesPerRow), additionalBlurContext.bytes)
                                    sideBlurredImage = additionalBlurContext.generateImage()
                                } else {
                                    sideBlurredImage = thumbnailContext.generateImage()
                                }
                                
                                if let blurredImage = sideBlurredImage {
                                    let filledSize = thumbnailSize.aspectFilled(arguments.drawingRect.size)
                                    c.interpolationQuality = .medium
                                    c.draw(blurredImage.cgImage!, in: CGRect(origin: CGPoint(x: arguments.drawingRect.minX + (arguments.drawingRect.width - filledSize.width) / 2.0, y: arguments.drawingRect.minY + (arguments.drawingRect.height - filledSize.height) / 2.0), size: filledSize))
                                    c.setBlendMode(.normal)
                                    c.setFillColor((arguments.emptyColor ?? UIColor.white).withAlphaComponent(0.05).cgColor)
                                    c.fill(arguments.drawingRect)
                                    c.setBlendMode(.copy)
                                }
                            } else {
                                c.fill(arguments.drawingRect)
                            }
                        case let .fill(color):
                            c.setFillColor((arguments.emptyColor ?? color).cgColor)
                            c.fill(arguments.drawingRect)
                        case .aspectFill:
                            break
                    }
                }
                
                c.setBlendMode(.copy)
                
                if blurredThumbnailImage == nil, fullSizeImage == nil, let emptyColor = arguments.emptyColor {
                    c.setFillColor(emptyColor.cgColor)
                    c.fill(arguments.drawingRect)
                }
                
                if let blurredThumbnailImage = blurredThumbnailImage, let cgImage = blurredThumbnailImage.cgImage {
                    c.interpolationQuality = .default
                    drawImage(context: c, image: cgImage, orientation: imageOrientation, in: fittedRect)
                    c.setBlendMode(.normal)
                }
                
                if let fullSizeImage = fullSizeImage {
                    c.interpolationQuality = .medium
                    drawImage(context: c, image: fullSizeImage, orientation: imageOrientation, in: fittedRect)
                }
            }
            
            if let overlayColor = overlayColor {
                context.withFlippedContext { c in
                    c.setBlendMode(.normal)
                    c.setFillColor(overlayColor.cgColor)
                    c.fill(arguments.drawingRect)
                }
            }
            
            addCorners(context, arguments: arguments)
            
            return context
        })
    }
}

public func chatMessagePhotoStatus(context: AccountContext, messageId: MessageId, photoReference: ImageMediaReference, displayAtSize: Int? = nil) -> Signal<MediaResourceStatus, NoError> {
    if let largestRepresentation = largestRepresentationForPhoto(photoReference.media) {
        if let range = representationFetchRangeForDisplayAtSize(representation: largestRepresentation, dimension: displayAtSize) {
            return combineLatest(
                context.fetchManager.fetchStatus(category: .image, location: .chat(messageId.peerId), locationKey: .messageId(messageId), resource: largestRepresentation.resource),
                context.account.postbox.mediaBox.resourceRangesStatus(largestRepresentation.resource)
            )
            |> map { status, rangeStatus -> MediaResourceStatus in
                if rangeStatus.isSuperset(of: RangeSet<Int64>(range)) {
                    return .Local
                }
                
                switch status {
                case .Local:
                    return .Local
                case let .Remote(progress):
                    return .Remote(progress: progress)
                case let .Fetching(isActive, progress):
                    return .Fetching(isActive: isActive, progress: max(progress, 0.0))
                case let .Paused(progress):
                    return .Paused(progress: progress)
                }
            }
            |> distinctUntilChanged
        } else {
            return context.fetchManager.fetchStatus(category: .image, location: .chat(messageId.peerId), locationKey: .messageId(messageId), resource: largestRepresentation.resource)
        }
    } else {
        return .never()
    }
}

public func standaloneChatMessagePhotoInteractiveFetched(account: Account, photoReference: ImageMediaReference) -> Signal<FetchResourceSourceType, FetchResourceError> {
    if let largestRepresentation = largestRepresentationForPhoto(photoReference.media) {
        return fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: photoReference.resourceReference(largestRepresentation.resource), statsCategory: .image, reportResultStatus: true)
        |> mapToSignal { type -> Signal<FetchResourceSourceType, FetchResourceError> in
            return .single(type)
        }
    } else {
        return .never()
    }
}

public func chatMessagePhotoInteractiveFetched(context: AccountContext, photoReference: ImageMediaReference, displayAtSize: Int?, storeToDownloadsPeerType: MediaAutoDownloadPeerType?) -> Signal<Never, NoError> {
    if let largestRepresentation = largestRepresentationForPhoto(photoReference.media) {
        var fetchRange: (Range<Int64>, MediaBoxFetchPriority)?
        if let displayAtSize = displayAtSize, let range = representationFetchRangeForDisplayAtSize(representation: largestRepresentation, dimension: displayAtSize) {
            fetchRange = (range, .default)
        }

        return fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: photoReference.resourceReference(largestRepresentation.resource), range: fetchRange, statsCategory: .image, reportResultStatus: true)
        |> mapToSignal { type -> Signal<FetchResourceSourceType, FetchResourceError> in
            if case .remote = type, let peerType = storeToDownloadsPeerType {
                return storeDownloadedMedia(storeManager: context.downloadedMediaStoreManager, media: photoReference.abstract, peerType: peerType)
                |> castError(FetchResourceError.self)
                |> mapToSignal { _ -> Signal<FetchResourceSourceType, FetchResourceError> in
                }
                |> then(.single(type))
            }
            return .single(type)
        }
        |> ignoreValues
        |> `catch` { _ -> Signal<Never, NoError> in
            return .complete()
        }
    } else {
        return .never()
    }
}

public func chatMessagePhotoCancelInteractiveFetch(account: Account, photoReference: ImageMediaReference) {
    if let largestRepresentation = largestRepresentationForPhoto(photoReference.media) {
        return account.postbox.mediaBox.cancelInteractiveResourceFetch(largestRepresentation.resource)
    }
}

public func chatMessageWebFileInteractiveFetched(account: Account, image: TelegramMediaWebFile) -> Signal<FetchResourceSourceType, FetchResourceError> {
    return fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: .standalone(resource: image.resource), statsCategory: .image)
}

public func chatMessageWebFileCancelInteractiveFetch(account: Account, image: TelegramMediaWebFile) {
    return account.postbox.mediaBox.cancelInteractiveResourceFetch(image.resource)
}

public func chatWebpageSnippetFileData(account: Account, mediaReference: AnyMediaReference, resource: MediaResource) -> Signal<Data?, NoError> {
    let resourceData = account.postbox.mediaBox.resourceData(resource)
        |> map { next in
            return next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: .mappedIfSafe)
    }
    
    return Signal { subscriber in
        let disposable = DisposableSet()
        disposable.add(resourceData.start(next: { data in
            subscriber.putNext(data)
        }, error: { _ in
        }, completed: {
            subscriber.putCompletion()
        }))
        disposable.add(fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: mediaReference.resourceReference(resource)).start())
        return disposable
    }
}

public func chatWebpageSnippetPhotoData(account: Account, photoReference: ImageMediaReference) -> Signal<Data?, NoError> {
    if let closestRepresentation = photoReference.media.representationForDisplayAtSize(PixelDimensions(width: 120, height: 120)) {
        let resourceData = account.postbox.mediaBox.resourceData(closestRepresentation.resource)
        |> map { next in
            return next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: .mappedIfSafe)
        }
        
        return Signal { subscriber in
            let disposable = DisposableSet()
            disposable.add(resourceData.start(next: { data in
                subscriber.putNext(data)
            }, error: { _ in
            }, completed: {
                subscriber.putCompletion()
            }))
            disposable.add(fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: photoReference.resourceReference(closestRepresentation.resource)).start())
            return disposable
        }
    } else {
        return .never()
    }
}

public func chatWebpageSnippetFile(account: Account, mediaReference: AnyMediaReference, representation: TelegramMediaImageRepresentation) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    let signal = chatWebpageSnippetFileData(account: account, mediaReference: mediaReference, resource: representation.resource)
    
    return signal |> map { fullSizeData in
        return { arguments in
            var fullSizeImage: CGImage?
            var imageOrientation: UIImage.Orientation = .up
            if let fullSizeData = fullSizeData {
                let options = NSMutableDictionary()
                if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                    imageOrientation = imageOrientationFromSource(imageSource)
                    fullSizeImage = image
                }
            }
            
            if let fullSizeImage = fullSizeImage {
                let context = DrawingContext(size: arguments.drawingSize, clear: true)
                
                let fittedSize = CGSize(width: fullSizeImage.width, height: fullSizeImage.height).aspectFilled(arguments.boundingSize)
                let drawingRect = arguments.drawingRect
                
                let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
                
                context.withFlippedContext { c in
                    c.setBlendMode(.copy)
                    if let emptyColor = arguments.emptyColor {
                        c.setFillColor(emptyColor.cgColor)
                        c.fill(arguments.drawingRect)
                    }
                    
                    if arguments.boundingSize.width > arguments.imageSize.width || arguments.boundingSize.height > arguments.imageSize.height {
                        c.fill(arguments.drawingRect)
                    }
                    
                    c.interpolationQuality = .medium
                    drawImage(context: c, image: fullSizeImage, orientation: imageOrientation, in: fittedRect)
                }
                
                addCorners(context, arguments: arguments)
                
                return context
            } else {
                if let emptyColor = arguments.emptyColor {
                    let context = DrawingContext(size: arguments.drawingSize, clear: true)
                    
                    context.withFlippedContext { c in
                        c.setBlendMode(.copy)
                        c.setFillColor(emptyColor.cgColor)
                        c.fill(arguments.drawingRect)
                    }
                    
                    addCorners(context, arguments: arguments)
                    
                    return context
                } else {
                    return nil
                }
            }
        }
    }
}

public func chatWebpageSnippetPhoto(account: Account, photoReference: ImageMediaReference) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    let signal = chatWebpageSnippetPhotoData(account: account, photoReference: photoReference)
    
    return signal |> map { fullSizeData in
        return { arguments in
            var fullSizeImage: CGImage?
            var imageOrientation: UIImage.Orientation = .up
            if let fullSizeData = fullSizeData {
                let options = NSMutableDictionary()
                if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                    imageOrientation = imageOrientationFromSource(imageSource)
                    fullSizeImage = image
                }
            }
            
            if let fullSizeImage = fullSizeImage {
                let context = DrawingContext(size: arguments.drawingSize, scale: arguments.scale ?? 0.0, clear: true)
                
                let fittedSize = CGSize(width: fullSizeImage.width, height: fullSizeImage.height).aspectFilled(arguments.boundingSize)
                let drawingRect = arguments.drawingRect
                
                let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
                
                context.withFlippedContext { c in
                    c.setBlendMode(.copy)
                    if arguments.boundingSize.width > arguments.imageSize.width || arguments.boundingSize.height > arguments.imageSize.height {
                        c.fill(arguments.drawingRect)
                    }
                    
                    c.interpolationQuality = .medium
                    drawImage(context: c, image: fullSizeImage, orientation: imageOrientation, in: fittedRect)
                }
                
                addCorners(context, arguments: arguments)
                
                return context
            } else {
                return nil
            }
        }
    }
}

public func chatMessageVideo(postbox: Postbox, videoReference: FileMediaReference) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    return mediaGridMessageVideo(postbox: postbox, videoReference: videoReference)
}

private func chatSecretMessageVideoData(account: Account, fileReference: FileMediaReference) -> Signal<Data?, NoError> {
    if let smallestRepresentation = smallestImageRepresentation(fileReference.media.previewRepresentations) {
        let thumbnailResource = smallestRepresentation.resource
        
        let fetchedThumbnail = fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: fileReference.resourceReference(thumbnailResource))
        
        let decodedThumbnailData = fileReference.media.immediateThumbnailData.flatMap(decodeTinyThumbnail)
        
        let thumbnail = Signal<Data?, NoError> { subscriber in
            let fetchedDisposable = fetchedThumbnail.start()
            let thumbnailDisposable = account.postbox.mediaBox.resourceData(thumbnailResource).start(next: { next in
                let data = next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: [])
                subscriber.putNext(data ?? decodedThumbnailData)
            }, error: subscriber.putError, completed: subscriber.putCompletion)
            
            return ActionDisposable {
                fetchedDisposable.dispose()
                thumbnailDisposable.dispose()
            }
        }
        return thumbnail
    } else {
        return .single(nil)
    }
}

public func chatSecretMessageVideo(account: Account, videoReference: FileMediaReference) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    let signal = chatSecretMessageVideoData(account: account, fileReference: videoReference)
    
    return signal
    |> map { thumbnailData in
        return { arguments in
            let context = DrawingContext(size: arguments.drawingSize, clear: true)
            if arguments.drawingSize.width.isLessThanOrEqualTo(0.0) || arguments.drawingSize.height.isLessThanOrEqualTo(0.0) {
                return context
            }
            
            let drawingRect = arguments.drawingRect
            let fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize).fitted(arguments.imageSize)
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            
            var blurredImage: UIImage?
            
            if blurredImage == nil {
                if let thumbnailData = thumbnailData, let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                    let thumbnailSize = CGSize(width: image.width, height: image.height)
                    let thumbnailContextSize = thumbnailSize.aspectFilled(CGSize(width: 20.0, height: 20.0))
                    let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                    thumbnailContext.withFlippedContext { c in
                        c.interpolationQuality = .none
                        c.draw(image, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                    }
                    imageFastBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                    
                    let thumbnailContext2Size = thumbnailSize.aspectFitted(CGSize(width: 100.0, height: 100.0))
                    let thumbnailContext2 = DrawingContext(size: thumbnailContext2Size, scale: 1.0)
                    thumbnailContext2.withFlippedContext { c in
                        c.interpolationQuality = .none
                        if let image = thumbnailContext.generateImage()?.cgImage {
                            c.draw(image, in: CGRect(origin: CGPoint(), size: thumbnailContext2Size))
                        }
                    }
                    imageFastBlur(Int32(thumbnailContext2Size.width), Int32(thumbnailContext2Size.height), Int32(thumbnailContext2.bytesPerRow), thumbnailContext2.bytes)
                    
                    blurredImage = thumbnailContext2.generateImage()
                }
            }
            
            context.withFlippedContext { c in
                c.setBlendMode(.copy)
                if arguments.imageSize.width < arguments.boundingSize.width || arguments.imageSize.height < arguments.boundingSize.height {
                    c.fill(arguments.drawingRect)
                }
                
                c.setBlendMode(.copy)
                if let blurredImage = blurredImage, let cgImage = blurredImage.cgImage {
                    c.interpolationQuality = .low
                    drawImage(context: c, image: cgImage, orientation: .up, in: fittedRect)
                }
                
                if !arguments.insets.left.isEqual(to: 0.0) {
                    c.clear(CGRect(origin: CGPoint(), size: CGSize(width: arguments.insets.left, height: context.size.height)))
                }
                if !arguments.insets.right.isEqual(to: 0.0) {
                    c.clear(CGRect(origin: CGPoint(x: context.size.width - arguments.insets.right, y: 0.0), size: CGSize(width: arguments.insets.right, height: context.size.height)))
                }
            }
            
            addCorners(context, arguments: arguments)
            
            return context
        }
    }
}

private func orientationFromExif(orientation: Int) -> UIImage.Orientation {
    switch orientation {
        case 1:
            return .up;
        case 3:
            return .down;
        case 8:
            return .left;
        case 6:
            return .right;
        case 2:
            return .upMirrored;
        case 4:
            return .downMirrored;
        case 5:
            return .leftMirrored;
        case 7:
            return .rightMirrored;
        default:
            return .up
    }
}

public func imageOrientationFromSource(_ source: CGImageSource) -> UIImage.Orientation {
    if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) {
        let dict = properties as NSDictionary
        if let value = dict.object(forKey: kCGImagePropertyOrientation) as? NSNumber {
            return orientationFromExif(orientation: value.intValue)
        }
    }
    
    return .up
}

private func rotationFor(_ orientation: UIImage.Orientation) -> CGFloat {
    switch orientation {
        case .left:
            return CGFloat.pi / 2.0
        case .right:
            return -CGFloat.pi / 2.0
        case .down:
            return -CGFloat.pi
        default:
            return 0.0
    }
}

public func drawImage(context: CGContext, image: CGImage, orientation: UIImage.Orientation, in rect: CGRect) {
    var restore = true
    var drawRect = rect
    switch orientation {
        case .left:
            fallthrough
        case .right:
            fallthrough
        case .down:
            let angle = rotationFor(orientation)
            context.saveGState()
            context.translateBy(x: rect.midX, y: rect.midY)
            context.rotate(by: angle)
            context.translateBy(x: -rect.midX, y: -rect.midY)
            var t = CGAffineTransform(translationX: rect.midX, y: rect.midY)
            t = t.rotated(by: angle)
            t = t.translatedBy(x: -rect.midX, y: -rect.midY)
            
            drawRect = rect.applying(t)
        case .leftMirrored:
            context.saveGState()
            context.translateBy(x: rect.midX, y: rect.midY)
            context.rotate(by: -CGFloat.pi / 2.0)
            context.translateBy(x: -rect.midX, y: -rect.midY)
            var t = CGAffineTransform(translationX: rect.midX, y: rect.midY)
            t = t.rotated(by: -CGFloat.pi / 2.0)
            t = t.translatedBy(x: -rect.midX, y: -rect.midY)
            
            drawRect = rect.applying(t)
        default:
            restore = false
    }
    context.draw(image, in: drawRect)
    if restore {
        context.restoreGState()
    }
}

public func chatMessageImageFile(account: Account, fileReference: FileMediaReference, thumbnail: Bool, fetched: Bool = false, autoFetchFullSizeThumbnail: Bool = false) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    let signal: Signal<Tuple3<Data?, String?, Bool>, NoError>
    if thumbnail {
        signal = chatMessageImageFileThumbnailDatas(account: account, fileReference: fileReference, autoFetchFullSizeThumbnail: true)
    } else {
        signal = chatMessageFileDatas(account: account, fileReference: fileReference, progressive: false, fetched: fetched)
    }
    
    return signal
    |> map { value in
        let thumbnailData = value._0
        let fullSizePath = value._1
        let fullSizeComplete = value._2
        return { arguments in
            assertNotOnMainThread()
            let context = DrawingContext(size: arguments.drawingSize, clear: true)
            
            let drawingRect = arguments.drawingRect
            var fittedSize: CGSize
            if thumbnail {
                fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize)
            } else {
                fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize).fitted(arguments.imageSize)
            }
            
            var fullSizeImage: CGImage?
            var imageOrientation: UIImage.Orientation = .up
            if let fullSizePath = fullSizePath {
                if fullSizeComplete {
                    let options = NSMutableDictionary()
                    options.setValue(max(fittedSize.width * context.scale, fittedSize.height * context.scale) as NSNumber, forKey: kCGImageSourceThumbnailMaxPixelSize as String)
                    options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailFromImageAlways as String)
                    if let imageSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: fullSizePath) as CFURL, nil), let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options) {
                        imageOrientation = imageOrientationFromSource(imageSource)
                        fullSizeImage = image
                        if thumbnail {
                            fittedSize = CGSize(width: CGFloat(image.width), height: CGFloat(image.height)).aspectFilled(arguments.boundingSize)
                        }
                    }
                }
            }
            
            var thumbnailImage: CGImage?
            var clearContext = false
            if let thumbnailData = thumbnailData {
                if let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                    if fullSizeImage == nil {
                        imageOrientation = imageOrientationFromSource(imageSource)
                    }
                    thumbnailImage = image
                    if thumbnail {
                        fittedSize = CGSize(width: CGFloat(image.width), height: CGFloat(image.height)).aspectFilled(arguments.boundingSize)
                    }
                } else if let image = WebP.convert(fromWebP: thumbnailData) {
                    thumbnailImage = image.cgImage
                    clearContext = true
                    if thumbnail {
                        fittedSize = CGSize(width: CGFloat(image.size.width), height: CGFloat(image.size.height)).aspectFilled(arguments.boundingSize)
                    }
                }
            }
            
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            
            var blurredThumbnailImage: UIImage?
            if let thumbnailImage = thumbnailImage {
                if max(thumbnailImage.width, thumbnailImage.height) > 200 {
                    blurredThumbnailImage = UIImage(cgImage: thumbnailImage)
                } else {
                    let thumbnailSize = CGSize(width: thumbnailImage.width, height: thumbnailImage.height)
                    
                    let initialThumbnailContextFittingSize = fittedSize.fitted(CGSize(width: 100.0, height: 100.0))
                    
                    let thumbnailContextSize = thumbnailSize.aspectFitted(initialThumbnailContextFittingSize)
                    let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0, clear: clearContext)
                    thumbnailContext.withFlippedContext { c in
                        c.interpolationQuality = .none
                        c.draw(thumbnailImage, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                    }
                    imageFastBlur(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                    
                    var thumbnailContextFittingSize = CGSize(width: floor(arguments.drawingSize.width * 0.5), height: floor(arguments.drawingSize.width * 0.5))
                    if thumbnailContextFittingSize.width < 150.0 || thumbnailContextFittingSize.height < 150.0 {
                        thumbnailContextFittingSize = thumbnailContextFittingSize.aspectFilled(CGSize(width: 150.0, height: 150.0))
                    }
                    
                    if thumbnailContextFittingSize.width > thumbnailContextSize.width {
                        let additionalContextSize = thumbnailContextFittingSize
                        let additionalBlurContext = DrawingContext(size: additionalContextSize, scale: 1.0, clear: clearContext)
                        additionalBlurContext.withFlippedContext { c in
                            c.interpolationQuality = .default
                            if let image = thumbnailContext.generateImage()?.cgImage {
                                c.draw(image, in: CGRect(origin: CGPoint(), size: additionalContextSize))
                            }
                        }
                        imageFastBlur(Int32(additionalContextSize.width), Int32(additionalContextSize.height), Int32(additionalBlurContext.bytesPerRow), additionalBlurContext.bytes)
                        blurredThumbnailImage = additionalBlurContext.generateImage()
                    } else {
                        blurredThumbnailImage = thumbnailContext.generateImage()
                    }
                }
            }
            
            context.withFlippedContext { c in
                if let emptyColor = arguments.emptyColor {
                    c.setFillColor(emptyColor.cgColor)
                    c.fill(drawingRect)
                }
                
                c.setBlendMode(.copy)
                if arguments.boundingSize != fittedSize && !fetched {
                    c.fill(drawingRect)
                }
                
                c.setBlendMode(.copy)
                if let blurredThumbnailImage = blurredThumbnailImage, let cgImage = blurredThumbnailImage.cgImage {
                    c.interpolationQuality = .low
                    drawImage(context: c, image: cgImage, orientation: imageOrientation, in: fittedRect)
                }
                
                if let fullSizeImage = fullSizeImage {
                    c.setBlendMode(.normal)
                    c.interpolationQuality = .medium
                    drawImage(context: c, image: fullSizeImage, orientation: imageOrientation, in: fittedRect)
                }
            }
            
            addCorners(context, arguments: arguments)
            
            return context
        }
    }
}

public func instantPageImageFile(account: Account, fileReference: FileMediaReference, fetched: Bool = false) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    return chatMessageFileDatas(account: account, fileReference: fileReference, progressive: false, fetched: fetched)
    |> map { value in
        let fullSizePath = value._1
        let fullSizeComplete = value._2
        return { arguments in
            assertNotOnMainThread()
            let context = DrawingContext(size: arguments.drawingSize, clear: true)
            
            let drawingRect = arguments.drawingRect
            let fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize).fitted(arguments.imageSize)
            
            var fullSizeImage: CGImage?
            var imageOrientation: UIImage.Orientation = .up
            if let fullSizePath = fullSizePath {
                if fullSizeComplete {
                    let options = NSMutableDictionary()
                    options.setValue(max(fittedSize.width * context.scale, fittedSize.height * context.scale) as NSNumber, forKey: kCGImageSourceThumbnailMaxPixelSize as String)
                    options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailFromImageAlways as String)
                    if let imageSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: fullSizePath) as CFURL, nil), let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options) {
                        imageOrientation = imageOrientationFromSource(imageSource)
                        fullSizeImage = image
                    }
                }
            }
            
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            
            context.withFlippedContext { c in
                if var fullSizeImage = fullSizeImage {
                    if let color = arguments.emptyColor, imageRequiresInversion(fullSizeImage), let tintedImage = generateTintedImage(image: UIImage(cgImage: fullSizeImage), color: color)?.cgImage {
                        fullSizeImage = tintedImage
                    }
                    
                    c.setBlendMode(.normal)
                    c.interpolationQuality = .medium
                    drawImage(context: c, image: fullSizeImage, orientation: imageOrientation, in: fittedRect)
                }
            }
            
            addCorners(context, arguments: arguments)
            
            return context
        }
    }
}

public func svgIconImageFile(account: Account, fileReference: FileMediaReference?, stickToTop: Bool = false) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    let data: Signal<MediaResourceData, NoError>
    if let fileReference = fileReference {
        data = account.postbox.mediaBox.cachedResourceRepresentation(fileReference.media.resource, representation: CachedPreparedSvgRepresentation(), complete: false, fetch: true)
    } else {
        data = Signal { subscriber in
            if let url = getAppBundle().url(forResource: "durgerking", withExtension: "placeholder"), let data = try? Data(contentsOf: url, options: .mappedRead) {
                subscriber.putNext(MediaResourceData(path: url.path, offset: 0, size: Int64(data.count), complete: true))
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }
    
    return data
    |> map { value in
        let fullSizePath = value.path
        let fullSizeComplete = value.complete
        return { arguments in
            let context = DrawingContext(size: arguments.drawingSize, clear: true)
            
            let drawingRect = arguments.drawingRect
            var fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize).fitted(arguments.imageSize)
            
            var fullSizeImage: UIImage?
            let imageOrientation: UIImage.Orientation = .up
            
            if fullSizeComplete, let data = try? Data(contentsOf: URL(fileURLWithPath: fullSizePath)) {
                let renderSize: CGSize
                if stickToTop {
                    renderSize = .zero
                } else {
                    renderSize = CGSize(width: 90.0, height: 90.0)
                }
                fullSizeImage = renderPreparedImage(data, renderSize, .clear, UIScreenScale)
                if let image = fullSizeImage {
                    fittedSize = image.size.aspectFitted(arguments.boundingSize)
                }
            }
            
            var fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            if stickToTop {
                fittedRect.origin.y = drawingRect.size.height - fittedSize.height
            }
            
            context.withFlippedContext { c in
                if let fullSizeImage = fullSizeImage?.cgImage {
                    c.setBlendMode(.normal)
                    c.interpolationQuality = .medium
                    drawImage(context: c, image: fullSizeImage, orientation: imageOrientation, in: fittedRect)
                }
            }
            
            addCorners(context, arguments: arguments)
            
            return context
        }
    }
}

private func avatarGalleryPhotoDatas(account: Account, fileReference: FileMediaReference? = nil, representations: [ImageRepresentationWithReference], immediateThumbnailData: Data?, autoFetchFullSize: Bool = false, attemptSynchronously: Bool = false, skipThumbnail: Bool = false) -> Signal<Tuple3<Data?, Data?, Bool>, NoError> {
    if let smallestRepresentation = smallestImageRepresentation(representations.map({ $0.representation })), let largestRepresentation = largestImageRepresentation(representations.map({ $0.representation })), let smallestIndex = representations.firstIndex(where: { $0.representation == smallestRepresentation }), let largestIndex = representations.firstIndex(where: { $0.representation == largestRepresentation }) {
       
        let maybeFullSize = account.postbox.mediaBox.resourceData(largestRepresentation.resource, attemptSynchronously: attemptSynchronously)
    
        let signal = maybeFullSize
        |> take(1)
        |> mapToSignal { maybeData -> Signal<Tuple3<Data?, Data?, Bool>, NoError> in
            if maybeData.complete {
                let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [])
                return .single(Tuple(nil, loadedData, true))
            } else {
                let decodedThumbnailData = immediateThumbnailData.flatMap(decodeTinyThumbnail)
                let fetchedThumbnail: Signal<FetchResourceSourceType, FetchResourceError>
                if let _ = decodedThumbnailData {
                    fetchedThumbnail = .complete()
                } else {
                    fetchedThumbnail = fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: representations[smallestIndex].reference)
                }
                let fetchedFullSize = fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: representations[largestIndex].reference)
                
                let thumbnail = Signal<Data?, NoError> { subscriber in
                    if let decodedThumbnailData = decodedThumbnailData {
                        subscriber.putNext(decodedThumbnailData)
                        subscriber.putCompletion()
                        return EmptyDisposable
                    } else {
                        let fetchedDisposable = fetchedThumbnail.start()
                        let thumbnailDisposable = account.postbox.mediaBox.resourceData(smallestRepresentation.resource, attemptSynchronously: attemptSynchronously).start(next: { next in
                            subscriber.putNext(next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []))
                        }, error: subscriber.putError, completed: subscriber.putCompletion)
                        
                        return ActionDisposable {
                            fetchedDisposable.dispose()
                            thumbnailDisposable.dispose()
                        }
                    }
                }
    
                let fullSizeData: Signal<Tuple2<Data?, Bool>, NoError>
                
                if autoFetchFullSize {
                    fullSizeData = Signal<Tuple2<Data?, Bool>, NoError> { subscriber in
                        let fetchedFullSizeDisposable = fetchedFullSize.start()
                        let fullSizeDisposable = account.postbox.mediaBox.resourceData(largestRepresentation.resource, attemptSynchronously: attemptSynchronously).start(next: { next in
                            subscriber.putNext(Tuple(next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []), next.complete))
                        }, error: subscriber.putError, completed: subscriber.putCompletion)
                        
                        return ActionDisposable {
                            fetchedFullSizeDisposable.dispose()
                            fullSizeDisposable.dispose()
                        }
                    }
                } else {
                    fullSizeData = account.postbox.mediaBox.resourceData(largestRepresentation.resource)
                    |> map { next -> Tuple2<Data?, Bool> in
                        return Tuple(next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []), next.complete)
                    }
                }
                
                if skipThumbnail {
                    return fullSizeData |> mapToSignal { value -> Signal <Tuple3<Data?, Data?, Bool>, NoError> in
                        if value._1 {
                            return .single(Tuple(nil, value._0, value._1))
                        } else {
                            return .complete()
                        }
                    }
                } else {
                    return thumbnail |> mapToSignal { thumbnailData in
                        return fullSizeData |> map { value in
                            return Tuple(thumbnailData, value._0, value._1)
                        }
                    }
                }
            }
        }
        
        return signal
    } else {
        return .never()
    }
}

public func chatAvatarGalleryPhoto(account: Account, representations: [ImageRepresentationWithReference], immediateThumbnailData: Data?, autoFetchFullSize: Bool = false, attemptSynchronously: Bool = false, skipThumbnail: Bool = false, skipBlurIfLarge: Bool = false) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    let signal = avatarGalleryPhotoDatas(account: account, representations: representations, immediateThumbnailData: immediateThumbnailData, autoFetchFullSize: autoFetchFullSize, attemptSynchronously: attemptSynchronously, skipThumbnail: skipThumbnail)
    
    return signal
    |> map { value in
        let thumbnailData = value._0
        let fullSizeData = value._1
        let fullSizeComplete = value._2
        return { arguments in
            let drawingRect = arguments.drawingRect
            var fittedSize = arguments.imageSize
            if abs(fittedSize.width - arguments.boundingSize.width).isLessThanOrEqualTo(CGFloat(1.0)) {
                fittedSize.width = arguments.boundingSize.width
            }
            if abs(fittedSize.height - arguments.boundingSize.height).isLessThanOrEqualTo(CGFloat(1.0)) {
                fittedSize.height = arguments.boundingSize.height
            }
            
            let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
            
            var fullSizeImage: CGImage?
            var imageOrientation: UIImage.Orientation = .up
            if let fullSizeData = fullSizeData {
                if fullSizeComplete {
                    let options = NSMutableDictionary()
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                    if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                        imageOrientation = imageOrientationFromSource(imageSource)
                        fullSizeImage = image
                    }
                } else {
                    let imageSource = CGImageSourceCreateIncremental(nil)
                    CGImageSourceUpdateData(imageSource, fullSizeData as CFData, fullSizeComplete)
                    
                    let options = NSMutableDictionary()
                    options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                    if let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                        imageOrientation = imageOrientationFromSource(imageSource)
                        fullSizeImage = image
                    }
                }
            }
            
            var thumbnailImage: CGImage?
            if let thumbnailData = thumbnailData, let imageSource = CGImageSourceCreateWithData(thumbnailData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                thumbnailImage = image
            }
            
            var blurredThumbnailImage: UIImage?
            if let thumbnailImage = thumbnailImage, !skipThumbnail {
                let maxThumbnailSide = max(thumbnailImage.width, thumbnailImage.height)
                if maxThumbnailSide > 200 || (maxThumbnailSide > 120 && maxThumbnailSide < 200 && skipBlurIfLarge)  {
                    blurredThumbnailImage = UIImage(cgImage: thumbnailImage)
                } else {
                    let thumbnailSize = CGSize(width: thumbnailImage.width, height: thumbnailImage.height)
                    let initialThumbnailContextFittingSize = fittedSize.fitted(CGSize(width: 90.0, height: 90.0))
                    
                    let thumbnailContextSize = thumbnailSize.aspectFitted(initialThumbnailContextFittingSize)
                    let thumbnailContext = DrawingContext(size: thumbnailContextSize, scale: 1.0)
                    thumbnailContext.withFlippedContext { c in
                        c.draw(thumbnailImage, in: CGRect(origin: CGPoint(), size: thumbnailContextSize))
                    }
                    telegramFastBlurMore(Int32(thumbnailContextSize.width), Int32(thumbnailContextSize.height), Int32(thumbnailContext.bytesPerRow), thumbnailContext.bytes)
                    
                    var thumbnailContextFittingSize = CGSize(width: floor(arguments.drawingSize.width * 0.5), height: floor(arguments.drawingSize.width * 0.5))
                    if thumbnailContextFittingSize.width < 150.0 || thumbnailContextFittingSize.height < 150.0 {
                        thumbnailContextFittingSize = thumbnailContextFittingSize.aspectFilled(CGSize(width: 150.0, height: 150.0))
                    }
                    
                    if thumbnailContextFittingSize.width > thumbnailContextSize.width {
                        let additionalContextSize = thumbnailContextFittingSize
                        let additionalBlurContext = DrawingContext(size: additionalContextSize, scale: 1.0)
                        additionalBlurContext.withFlippedContext { c in
                            c.interpolationQuality = .default
                            if let image = thumbnailContext.generateImage()?.cgImage {
                                c.draw(image, in: CGRect(origin: CGPoint(), size: additionalContextSize))
                            }
                        }
                        imageFastBlur(Int32(additionalContextSize.width), Int32(additionalContextSize.height), Int32(additionalBlurContext.bytesPerRow), additionalBlurContext.bytes)
                        blurredThumbnailImage = additionalBlurContext.generateImage()
                    } else {
                        blurredThumbnailImage = thumbnailContext.generateImage()
                    }
                }
            }
            
            let context = DrawingContext(size: arguments.drawingSize, clear: true)
            
            context.withFlippedContext { c in
                c.setBlendMode(.copy)
                if arguments.imageSize.width < arguments.boundingSize.width || arguments.imageSize.height < arguments.boundingSize.height {
                    c.fill(arguments.drawingRect)
                }
                
                c.setBlendMode(.copy)
                if let blurredThumbnailImage = blurredThumbnailImage, let cgImage = blurredThumbnailImage.cgImage {
                    c.interpolationQuality = .default
                    drawImage(context: c, image: cgImage, orientation: imageOrientation, in: fittedRect)
                    c.setBlendMode(.normal)
                }
                
                if let fullSizeImage = fullSizeImage {
                    c.interpolationQuality = .medium
                    drawImage(context: c, image: fullSizeImage, orientation: imageOrientation, in: fittedRect)
                }
            }
            
            addCorners(context, arguments: arguments)
            
            return context
        }
    }
}

public func chatWebFileImage(account: Account, file: TelegramMediaWebFile) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    return account.postbox.mediaBox.resourceData(file.resource)
    |> map { fullSizeData in
        return { arguments in
            let context = DrawingContext(size: arguments.drawingSize, clear: true)
            
            var fullSizeImage: CGImage?
            var imageOrientation: UIImage.Orientation = .up
            if fullSizeData.complete {
                let options = NSMutableDictionary()
                options[kCGImageSourceShouldCache as NSString] = false as NSNumber
                if let imageSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: fullSizeData.path) as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                    imageOrientation = imageOrientationFromSource(imageSource)
                    fullSizeImage = image
                }
                
                if let fullSizeImage = fullSizeImage {
                    let drawingRect = arguments.drawingRect
                    var fittedSize = CGSize(width: CGFloat(fullSizeImage.width), height: CGFloat(fullSizeImage.height)).aspectFilled(drawingRect.size)
                    if abs(fittedSize.width - arguments.boundingSize.width).isLessThanOrEqualTo(CGFloat(1.0)) {
                        fittedSize.width = arguments.boundingSize.width
                    }
                    if abs(fittedSize.height - arguments.boundingSize.height).isLessThanOrEqualTo(CGFloat(1.0)) {
                        fittedSize.height = arguments.boundingSize.height
                    }
                    
                    let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
                    
                    context.withFlippedContext { c in
                        c.setBlendMode(.copy)
                        if arguments.imageSize.width < arguments.boundingSize.width || arguments.imageSize.height < arguments.boundingSize.height {
                            c.fill(arguments.drawingRect)
                        }
                        
                        c.setBlendMode(.copy)
                        
                        c.interpolationQuality = .medium
                        drawImage(context: c, image: fullSizeImage, orientation: imageOrientation, in: fittedRect)
                        
                        c.setBlendMode(.normal)
                    }
                } else {
                    context.withFlippedContext { c in
                        c.setBlendMode(.copy)
                        c.setFillColor((arguments.emptyColor ?? UIColor.white).cgColor)
                        c.fill(arguments.drawingRect)
                        
                        c.setBlendMode(.normal)
                    }
                }
            }
            
            addCorners(context, arguments: arguments)
            
            return context
        }
    }
}

private let precomposedSmallAlbumArt = Atomic<UIImage?>(value: nil)

public func albumArtThumbnailData(engine: TelegramEngine, thumbnail: ExternalMusicAlbumArtResource, attemptSynchronously: Bool = false) -> Signal<Data?, NoError> {
    return engine.resources.custom(
        id: thumbnail.id.stringRepresentation,
        fetch: EngineMediaResource.Fetch {
            return fetchExternalMusicAlbumArtResource(engine: engine, file: thumbnail.file, resource: thumbnail)
        },
        attemptSynchronously: attemptSynchronously
    )
    |> mapToSignal { data in
        if data.isComplete {
            let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: data.path), options: [])
            return .single(loadedData)
        } else {
            return .single(nil)
        }
    }
    |> distinctUntilChanged(isEqual: { lhs, rhs in
        if lhs == nil && rhs == nil {
            return true
        } else {
            return false
        }
    })
}

private func albumArtFullSizeDatas(engine: TelegramEngine, file: FileMediaReference?, thumbnail: ExternalMusicAlbumArtResource, fullSize: ExternalMusicAlbumArtResource, autoFetchFullSize: Bool = true) -> Signal<Tuple3<Data?, Data?, Bool>, NoError> {
    return engine.resources.custom(
        id: fullSize.id.stringRepresentation,
        fetch: nil,
        attemptSynchronously: false
    )
    |> take(1)
    |> mapToSignal { data in
        if data.isComplete {
            let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: data.path), options: [])
            return .single(Tuple(nil, loadedData, true))
        } else {
            return combineLatest(
                engine.resources.custom(
                    id: thumbnail.id.stringRepresentation,
                    fetch: EngineMediaResource.Fetch {
                        return fetchExternalMusicAlbumArtResource(engine: engine, file: file, resource: thumbnail)
                    },
                    attemptSynchronously: false
                ),
                engine.resources.custom(
                    id: fullSize.id.stringRepresentation,
                    fetch: autoFetchFullSize ? EngineMediaResource.Fetch {
                        return fetchExternalMusicAlbumArtResource(engine: engine, file: file, resource: fullSize)
                    } : nil,
                    attemptSynchronously: false
                )
            )
            |> mapToSignal { thumbnail, fullSize in
                if fullSize.isComplete {
                    let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: fullSize.path), options: [])
                    return .single(Tuple(nil, loadedData, true))
                } else if thumbnail.isComplete {
                    let loadedData: Data? = try? Data(contentsOf: URL(fileURLWithPath: thumbnail.path), options: [])
                    return .single(Tuple(loadedData, nil, false))
                } else {
                    return .single(Tuple(nil, nil, false))
                }
            }

        }
    }
    |> distinctUntilChanged(isEqual: { lhs, rhs in
        if (lhs._0 == nil && lhs._1 == nil) && (rhs._0 == nil && rhs._1 == nil) {
            return true
        } else {
            return false
        }
    })
}

private func drawAlbumArtPlaceholder(into c: CGContext, arguments: TransformImageArguments, thumbnail: Bool) {
    c.setBlendMode(.copy)
    c.setFillColor(UIColor(rgb: 0xeeeeee).cgColor)
    c.fill(arguments.drawingRect)
    
    c.setBlendMode(.normal)
    
    if thumbnail {
        var image: UIImage?
        let precomposed = precomposedSmallAlbumArt.with { $0 }
        if let precomposed = precomposed {
            image = precomposed
        } else {
            if let sourceImage = UIImage(bundleImageName: "GlobalMusicPlayer/AlbumArtPlaceholder"), let cgImage = sourceImage.cgImage {
                
                let fittedSize = sourceImage.size.aspectFitted(CGSize(width: 28.0, height: 28.0))
                
                image = generateImage(fittedSize, contextGenerator: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.draw(cgImage, in: CGRect(origin: CGPoint(), size: size))
                })
                
                if let image = image {
                    let _ = precomposedSmallAlbumArt.swap(image)
                }
            }
        }
        if let image = image, let cgImage = image.cgImage {
            c.draw(cgImage, in: CGRect(origin: CGPoint(x: floor(arguments.drawingRect.size.width - image.size.width) / 2.0, y: floor(arguments.drawingRect.size.height - image.size.height) / 2.0), size: image.size))
        }
    } else {
        if let sourceImage = UIImage(bundleImageName: "GlobalMusicPlayer/AlbumArtPlaceholder"), let cgImage = sourceImage.cgImage {
            let fittedSize = sourceImage.size.aspectFitted(CGSize(width: floor(arguments.drawingRect.size.width * 0.66), height: floor(arguments.drawingRect.size.width * 0.66)))
            
            c.draw(cgImage, in: CGRect(origin: CGPoint(x: floor(arguments.drawingRect.size.width - fittedSize.width) / 2.0, y: floor(arguments.drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize))
        }
    }
}

public func playerAlbumArt(postbox: Postbox, engine: TelegramEngine, fileReference: FileMediaReference?, albumArt: SharedMediaPlaybackAlbumArt?, thumbnail: Bool, overlayColor: UIColor? = nil, emptyColor: UIColor? = nil, drawPlaceholderWhenEmpty: Bool = true, attemptSynchronously: Bool = false) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    var fileArtworkData: Signal<Data?, NoError> = .single(nil)
    if let fileReference = fileReference {
        let size = thumbnail ? CGSize(width: 48.0, height: 48.0) : CGSize(width: 320.0, height: 320.0)
        fileArtworkData = fileArtworkData
        |> then(
            postbox.mediaBox.cachedResourceRepresentation(fileReference.media.resource, representation: CachedAlbumArtworkRepresentation(size: size), complete: false, fetch: true)
            |> map { data -> Data? in
                if data.complete, let fileData = try? Data(contentsOf: URL(fileURLWithPath: data.path), options: .mappedRead) {
                    return fileData
                } else {
                    return nil
                }
            }
        )
    }
    
    var immediateArtworkData: Signal<Tuple3<Data?, Data?, Bool>, NoError> = .single(Tuple(nil, nil, false))
    
    if let fileReference = fileReference, let smallestRepresentation = smallestImageRepresentation(fileReference.media.previewRepresentations) {
        let thumbnailResource = smallestRepresentation.resource
        
        let fetchedThumbnail = fetchedMediaResource(mediaBox: postbox.mediaBox, reference: fileReference.resourceReference(thumbnailResource))
        
        let thumbnail = Signal<Data?, NoError> { subscriber in
            let fetchedDisposable = fetchedThumbnail.start()
            let thumbnailDisposable = postbox.mediaBox.resourceData(thumbnailResource, attemptSynchronously: attemptSynchronously).start(next: { next in
                subscriber.putNext(next.size == 0 ? nil : try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []))
            }, error: subscriber.putError, completed: subscriber.putCompletion)
            
            return ActionDisposable {
                fetchedDisposable.dispose()
                thumbnailDisposable.dispose()
            }
        }
        immediateArtworkData = thumbnail
        |> map { thumbnailData in
            return Tuple(thumbnailData, nil, false)
        }
    } else if let albumArt = albumArt {
        if thumbnail {
            immediateArtworkData = albumArtThumbnailData(engine: engine, thumbnail: albumArt.thumbnailResource, attemptSynchronously: attemptSynchronously)
            |> map { thumbnailData in
                return Tuple(thumbnailData, nil, false)
            }
        } else {
            immediateArtworkData = albumArtFullSizeDatas(engine: engine, file: fileReference, thumbnail: albumArt.thumbnailResource, fullSize: albumArt.fullSizeResource)
        }
    }
    
    return combineLatest(fileArtworkData, immediateArtworkData)
    |> map { fileArtworkData, remoteArtworkData in
        let remoteThumbnailData = remoteArtworkData._0
        let remoteFullSizeData = remoteArtworkData._1
        let remoteFullSizeComplete = remoteArtworkData._2
        return { arguments in
            let context = DrawingContext(size: arguments.drawingSize, clear: true)
            
            var sourceImage: UIImage?
            if let fileArtworkData = fileArtworkData, let image = UIImage(data: fileArtworkData) {
                sourceImage = image
            } else if remoteFullSizeComplete, let fullSizeData = remoteFullSizeData, let image = UIImage(data: fullSizeData) {
                sourceImage = image
            } else if let thumbnailData = remoteThumbnailData, let image = UIImage(data: thumbnailData) {
                sourceImage = image
            }
            
            if let sourceImage = sourceImage, let cgImage = sourceImage.cgImage {
                let imageSize = sourceImage.size.aspectFilled(arguments.drawingRect.size)
                context.withFlippedContext { c in
                    c.draw(cgImage, in: CGRect(origin: CGPoint(x: floor((arguments.drawingRect.size.width - imageSize.width) / 2.0), y: floor((arguments.drawingRect.size.height - imageSize.height) / 2.0)), size: imageSize))
                    if let overlayColor = overlayColor {
                        c.setFillColor(overlayColor.cgColor)
                        c.fill(arguments.drawingRect)
                    }
                }
            } else {
                if let emptyColor = emptyColor {
                    context.withFlippedContext { c in
                        let rect = arguments.drawingRect
                        c.setFillColor(emptyColor.cgColor)
                        c.fill(rect)
                    }
                } else if drawPlaceholderWhenEmpty {
                    context.withFlippedContext { c in
                        drawAlbumArtPlaceholder(into: c, arguments: arguments, thumbnail: thumbnail)
                    }
                } else {
                    return nil
                }
            }
            
            addCorners(context, arguments: arguments)
            
            return context
        }
    }
}

public func securePhoto(account: Account, resource: TelegramMediaResource, accessContext: SecureIdAccessContext) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    return securePhotoInternal(account: account, resource: resource, accessContext: accessContext) |> map { $0.1 }
}

public func securePhotoInternal(account: Account, resource: TelegramMediaResource, accessContext: SecureIdAccessContext) -> Signal<(() -> CGSize?, (TransformImageArguments) -> DrawingContext?), NoError> {
    let signal = Signal<MediaResourceData, NoError> { subscriber in
        let fetched = account.postbox.mediaBox.fetchedResource(resource, parameters: nil).start()
        let data = account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false)).start(next: { next in
            subscriber.putNext(next)
        }, completed: {
            subscriber.putCompletion()
        })
        return ActionDisposable {
            fetched.dispose()
            data.dispose()
        }
    }
    |> map { next -> Data? in
        if next.size == 0 {
            return nil
        } else {
            return decryptedResourceData(data: next, resource: resource, params: accessContext)
        }
    }
    
    return signal |> map { fullSizeData in
        return ({
            if let fullSizeData = fullSizeData, let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, nil) {
                let options = NSMutableDictionary()
                options.setObject(true as NSNumber, forKey: kCGImagePropertyPixelWidth as NSString)
                options.setObject(true as NSNumber, forKey: kCGImagePropertyPixelHeight as NSString)
                if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, options as CFDictionary) {
                    let dict = properties as NSDictionary
                    if let width = dict.object(forKey: kCGImagePropertyPixelWidth as NSString), let height = dict.object(forKey: kCGImagePropertyPixelHeight as NSString) {
                        if let width = width as? NSNumber, let height = height as? NSNumber {
                            return CGSize(width: CGFloat(width.floatValue), height: CGFloat(height.floatValue))
                        }
                    }
                }
            }
            return CGSize(width: 128.0, height: 128.0)
        }, { arguments in
            var fullSizeImage: CGImage?
            var imageOrientation: UIImage.Orientation = .up
            if let fullSizeData = fullSizeData {
                let options = NSMutableDictionary()
                if let imageSource = CGImageSourceCreateWithData(fullSizeData as CFData, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) {
                    imageOrientation = imageOrientationFromSource(imageSource)
                    fullSizeImage = image
                }
            }
            
            if let fullSizeImage = fullSizeImage {
                let context = DrawingContext(size: arguments.drawingSize, clear: true)
                
                let fittedSize = CGSize(width: fullSizeImage.width, height: fullSizeImage.height).aspectFilled(arguments.boundingSize)
                let drawingRect = arguments.drawingRect
                
                let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
                
                context.withFlippedContext { c in
                    c.setBlendMode(.copy)
                    if arguments.boundingSize.width > arguments.imageSize.width || arguments.boundingSize.height > arguments.imageSize.height {
                        c.fill(arguments.drawingRect)
                    }
                    
                    c.interpolationQuality = .medium
                    drawImage(context: c, image: fullSizeImage, orientation: imageOrientation, in: fittedRect)
                }
                
                addCorners(context, arguments: arguments)
                
                return context
            } else {
                return nil
            }
        })
    }
}

public func callDefaultBackground() -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    return .single({ arguments in
        let context = DrawingContext(size: arguments.drawingSize, clear: true)
        context.withFlippedContext { c in
            let colors = [UIColor(rgb: 0x466f92).cgColor, UIColor(rgb: 0x244f74).cgColor]
            var locations: [CGFloat] = [1.0, 0.0]
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
            c.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: arguments.drawingSize.height), options: CGGradientDrawingOptions())
        }
        return context
    })
}
