import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import MtProtoKit
import Display
import AccountContext
import Pdf
import LocalMediaResources
import AVFoundation
import LegacyComponents
import ShareItemsImpl

public enum UnpreparedShareItemContent {
    case contact(DeviceContactExtendedData)
}

public enum PreparedShareItemContent {
    case text(String)
    case media(StandaloneUploadMediaResult)
}

public enum PreparedShareItem {
    case preparing
    case progress(Float)
    case userInteractionRequired(UnpreparedShareItemContent)
    case done(PreparedShareItemContent)
}

public enum PreparedShareItems {
    case preparing
    case progress(Float)
    case userInteractionRequired([UnpreparedShareItemContent])
    case done([PreparedShareItemContent])
}

private func scalePhotoImage(_ image: UIImage, dimensions: CGSize) -> UIImage? {
    if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: dimensions, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: dimensions))
        }
    } else {
        return TGScaleImageToPixelSize(image, dimensions)
    }
}

private func preparedShareItem(account: Account, to peerId: PeerId, value: [String: Any]) -> Signal<PreparedShareItem, Void> {
    if let imageData = value["scaledImageData"] as? Data, let dimensions = value["scaledImageDimensions"] as? NSValue {
        let diminsionsSize = dimensions.cgSizeValue
        return .single(.preparing)
        |> then(
            standaloneUploadedImage(account: account, peerId: peerId, text: "", data: imageData, dimensions: PixelDimensions(width: Int32(diminsionsSize.width), height: Int32(diminsionsSize.height)))
            |> mapError { _ -> Void in
                return Void()
            }
            |> mapToSignal { event -> Signal<PreparedShareItem, Void> in
                switch event {
                    case let .progress(value):
                        return .single(.progress(value))
                    case let .result(media):
                        return .single(.done(.media(media)))
                }
            }
        )
    } else if let image = value["image"] as? UIImage {
        let nativeImageSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let dimensions = nativeImageSize.fitted(CGSize(width: 1280.0, height: 1280.0))
        if let scaledImage = scalePhotoImage(image, dimensions: dimensions), let imageData = scaledImage.jpegData(compressionQuality: 0.52) {
            return .single(.preparing)
                |> then(standaloneUploadedImage(account: account, peerId: peerId, text: "", data: imageData, dimensions: PixelDimensions(width: Int32(dimensions.width), height: Int32(dimensions.height)))
                |> mapError { _ -> Void in
                    return Void()
                }
                |> mapToSignal { event -> Signal<PreparedShareItem, Void> in
                    switch event {
                        case let .progress(value):
                            return .single(.progress(value))
                        case let .result(media):
                            return .single(.done(.media(media)))
                    }
                }
            )
        } else {
            return .never()
        }
    } else if let asset = value["video"] as? AVURLAsset {
        var flags: TelegramMediaVideoFlags = [.supportsStreaming]
        let sendAsInstantRoundVideo = value["isRoundMessage"] as? Bool ?? false
        var adjustments: TGVideoEditAdjustments? = nil
        if sendAsInstantRoundVideo {
            flags.insert(.instantRoundVideo)
            
            if let width = value["width"] as? CGFloat, let height = value["height"] as? CGFloat {
                let size = CGSize(width: width, height: height)
                
                var cropRect = CGRect(origin: CGPoint(), size: size)
                if abs(width - height) < CGFloat.ulpOfOne {
                    cropRect = cropRect.insetBy(dx: 13.0, dy: 13.0)
                    cropRect = cropRect.offsetBy(dx: 2.0, dy: 3.0)
                } else {
                    let shortestSide = min(size.width, size.height)
                    cropRect = CGRect(x: (size.width - shortestSide) / 2.0, y: (size.height - shortestSide) / 2.0, width: shortestSide, height: shortestSide)
                }

                adjustments = TGVideoEditAdjustments(originalSize: size, cropRect: cropRect, cropOrientation: .up, cropRotation: 0.0, cropLockedAspectRatio: 1.0, cropMirrored: false, trimStartValue: 0.0, trimEndValue: 0.0, toolValues: nil, paintingData: nil, sendAsGif: false, preset: TGMediaVideoConversionPresetVideoMessage)
            }
        }
        var finalDuration: Double = CMTimeGetSeconds(asset.duration)
        
        func loadValues(_ avAsset: AVURLAsset) -> Signal<AVURLAsset, Void> {
            return Signal { subscriber in
                avAsset.loadValuesAsynchronously(forKeys: ["tracks", "duration", "playable"]) {
                    subscriber.putNext(avAsset)
                }
                return EmptyDisposable
            }
        }
        
        return loadValues(asset)
        |> mapToSignal { asset -> Signal<PreparedShareItem, Void> in
            let preset = adjustments?.preset ?? TGMediaVideoConversionPresetCompressedMedium
            let finalDimensions = TGMediaVideoConverter.dimensions(for: asset.originalSize, adjustments: adjustments, preset: preset)
            
            var resourceAdjustments: VideoMediaResourceAdjustments?
            if let adjustments = adjustments {
                if adjustments.trimApplied() {
                    finalDuration = adjustments.trimEndValue - adjustments.trimStartValue
                }
                
                let adjustmentsData = MemoryBuffer(data: NSKeyedArchiver.archivedData(withRootObject: adjustments.dictionary()!))
                let digest = MemoryBuffer(data: adjustmentsData.md5Digest())
                resourceAdjustments = VideoMediaResourceAdjustments(data: adjustmentsData, digest: digest)
            }
            
            let estimatedSize = TGMediaVideoConverter.estimatedSize(for: preset, duration: finalDuration, hasAudio: true)
            
            let resource = LocalFileVideoMediaResource(randomId: Int64.random(in: Int64.min ... Int64.max), path: asset.url.path, adjustments: resourceAdjustments)
            return standaloneUploadedFile(account: account, peerId: peerId, text: "", source: .resource(.standalone(resource: resource)), mimeType: "video/mp4", attributes: [.Video(duration: Int(finalDuration), size: PixelDimensions(width: Int32(finalDimensions.width), height: Int32(finalDimensions.height)), flags: flags)], hintFileIsLarge: estimatedSize > 10 * 1024 * 1024)
            |> mapError { _ -> Void in
                return Void()
            }
            |> mapToSignal { event -> Signal<PreparedShareItem, Void> in
                switch event {
                    case let .progress(value):
                        return .single(.progress(value))
                    case let .result(media):
                        return .single(.done(.media(media)))
                }
            }
        }
    } else if let data = value["data"] as? Data {
        let fileName = value["fileName"] as? String
        let mimeType = (value["mimeType"] as? String) ?? "application/octet-stream"
        
        var treatAsFile = false
        if let boolValue = value["treatAsFile"] as? Bool, boolValue {
            treatAsFile = true
        }
        
        if !treatAsFile, let image = UIImage(data: data) {
            var isGif = false
            if data.count > 4 {
                data.withUnsafeBytes { buffer -> Void in
                    guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                        return
                    }
                    if bytes.advanced(by: 0).pointee == 71 // G
                    && bytes.advanced(by: 1).pointee == 73 // I
                    && bytes.advanced(by: 2).pointee == 70 // F
                    && bytes.advanced(by: 3).pointee == 56 // 8
                    {
                        isGif = true
                    }
                }
            }
            if isGif {
                let convertedData = Signal<(Data, CGSize, Double, Bool), NoError> { subscriber in
                    let disposable = MetaDisposable()
                    let signalDisposable = TGGifConverter.convertGif(toMp4: data).start(next: { next in
                        if let result = next as? NSDictionary, let path = result["path"] as? String, let convertedData = try? Data(contentsOf: URL(fileURLWithPath: path)), let duration = result["duration"] as? Double {
                            subscriber.putNext((convertedData, image.size, duration, true))
                            subscriber.putCompletion()
                        }
                    }, error: { _ in
                        subscriber.putNext((data, image.size, 0, false))
                        subscriber.putCompletion()
                    }, completed: nil)
                    disposable.set(ActionDisposable {
                        signalDisposable?.dispose()
                    })
                    return disposable
                }
                
                return convertedData
                |> castError(Void.self)
                |> mapToSignal { data, dimensions, duration, converted in
                    var attributes: [TelegramMediaFileAttribute] = []
                    let mimeType: String
                    if converted {
                        mimeType = "video/mp4"
                        attributes = [.Video(duration: Int(duration), size: PixelDimensions(width: Int32(dimensions.width), height: Int32(dimensions.height)), flags: [.supportsStreaming]), .Animated, .FileName(fileName: "animation.mp4")]
                    } else {
                        mimeType = "animation/gif"
                        attributes = [.ImageSize(size: PixelDimensions(width: Int32(dimensions.width), height: Int32(dimensions.height))), .Animated, .FileName(fileName: fileName ?? "animation.gif")]
                    }
                    return standaloneUploadedFile(account: account, peerId: peerId, text: "", source: .data(data), mimeType: mimeType, attributes: attributes, hintFileIsLarge: data.count > 10 * 1024 * 1024)
                    |> mapError { _ -> Void in return Void() }
                    |> mapToSignal { event -> Signal<PreparedShareItem, Void> in
                        switch event {
                            case let .progress(value):
                                return .single(.progress(value))
                            case let .result(media):
                                return .single(.done(.media(media)))
                        }
                    }
                }
            } else {
                let scaledImage = TGScaleImageToPixelSize(image, CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale).fitted(CGSize(width: 1280.0, height: 1280.0)))!
                let imageData = scaledImage.jpegData(compressionQuality: 0.54)!
                return standaloneUploadedImage(account: account, peerId: peerId, text: "", data: imageData, dimensions: PixelDimensions(width: Int32(scaledImage.size.width), height: Int32(scaledImage.size.height)))
                |> mapError { _ -> Void in return Void() }
                |> mapToSignal { event -> Signal<PreparedShareItem, Void> in
                    switch event {
                        case let .progress(value):
                            return .single(.progress(value))
                        case let .result(media):
                            return .single(.done(.media(media)))
                    }
                }
            }
        } else {
            var thumbnailData: Data?
            if mimeType == "application/pdf", let image = generatePdfPreviewImage(data: data, size: CGSize(width: 256.0, height: 256.0)), let jpegData = image.jpegData(compressionQuality: 0.5) {
                thumbnailData = jpegData
            }
            
            return standaloneUploadedFile(account: account, peerId: peerId, text: "", source: .data(data), thumbnailData: thumbnailData, mimeType: mimeType, attributes: [.FileName(fileName: fileName ?? "file")], hintFileIsLarge: data.count > 10 * 1024 * 1024)
            |> mapError { _ -> Void in return Void() }
            |> mapToSignal { event -> Signal<PreparedShareItem, Void> in
                switch event {
                    case let .progress(value):
                        return .single(.progress(value))
                    case let .result(media):
                        return .single(.done(.media(media)))
                }
            }
        }
    } else if let url = value["audio"] as? URL {
        if let audioData = try? Data(contentsOf: url, options: [.mappedIfSafe]) {
            let fileName = url.lastPathComponent
            let duration = (value["duration"] as? NSNumber)?.doubleValue ?? 0.0
            let isVoice = ((value["isVoice"] as? NSNumber)?.boolValue ?? false)
            let title = value["title"] as? String
            let artist = value["artist"] as? String
            let mimeType = value["mimeType"] as? String ?? "audio/ogg"
            
            var waveform: MemoryBuffer?
            if let waveformData = TGItemProviderSignals.audioWaveform(url) {
                waveform = MemoryBuffer(data: waveformData)
            }
            
            return standaloneUploadedFile(account: account, peerId: peerId, text: "", source: .data(audioData), mimeType: mimeType, attributes: [.Audio(isVoice: isVoice, duration: Int(duration), title: title, performer: artist, waveform: waveform?.makeData()), .FileName(fileName: fileName)], hintFileIsLarge: audioData.count > 10 * 1024 * 1024)
            |> mapError { _ -> Void in return Void() }
            |> mapToSignal { event -> Signal<PreparedShareItem, Void> in
                switch event {
                    case let .progress(value):
                        return .single(.progress(value))
                    case let .result(media):
                        return .single(.done(.media(media)))
                }
            }
        } else {
            return .never()
        }
    } else if let text = value["text"] as? String {
        return .single(.done(.text(text)))
    } else if let url = value["url"] as? URL {
        if TGShareLocationSignals.isLocationURL(url) {
            return Signal<PreparedShareItem, Void> { subscriber in
                subscriber.putNext(.preparing)
                let disposable = TGShareLocationSignals.locationMessageContent(for: url).start(next: { value in
                    if let value = value as? TGShareLocationResult {
                        if let title = value.title {
                            subscriber.putNext(.done(.media(.media(.standalone(media: TelegramMediaMap(latitude: value.latitude, longitude: value.longitude, heading: nil, accuracyRadius: nil, geoPlace: nil, venue: MapVenue(title: title, address: value.address, provider: value.provider, id: value.venueId, type: value.venueType), liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil))))))
                        } else {
                            subscriber.putNext(.done(.media(.media(.standalone(media: TelegramMediaMap(latitude: value.latitude, longitude: value.longitude, heading: nil, accuracyRadius: nil, geoPlace: nil, venue: nil, liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil))))))
                        }
                        subscriber.putCompletion()
                    } else if let value = value as? String {
                        subscriber.putNext(.done(.text(value)))
                        subscriber.putCompletion()
                    }
                })
                return ActionDisposable {
                    disposable?.dispose()
                }
            }
        } else {
            return .single(.done(.text(url.absoluteString)))
        }
    } else if let vcard = value["contact"] as? Data, let contactData = DeviceContactExtendedData(vcard: vcard) {
        return .single(.userInteractionRequired(.contact(contactData)))
    } else {
        return .never()
    }
}

public func preparedShareItems(account: Account, to peerId: PeerId, dataItems: [MTSignal], additionalText: String) -> Signal<PreparedShareItems, Void> {
    var dataSignals: Signal<[String: Any], Void> = .complete()
    for dataItem in dataItems {
        let wrappedSignal: Signal<[String: Any], NoError> = Signal { subscriber in
            let disposable = dataItem.start(next: { value in
                subscriber.putNext(value as! [String : Any])
            }, error: { _ in
            }, completed: {
                subscriber.putCompletion()
            })
            return ActionDisposable {
                disposable?.dispose()
            }
        }
        dataSignals = dataSignals
        |> then(
            wrappedSignal
            |> castError(Void.self)
            |> take(1)
        )
    }
    
    let shareItems = dataSignals
    |> map { [$0] }
    |> reduceLeft(value: [[String: Any]](), f: { list, rest in
        return list + rest
    })
    |> mapToSignal { items -> Signal<[PreparedShareItem], Void> in
        return combineLatest(items.map {
            preparedShareItem(account: account, to: peerId, value: $0)
        })
    }
        
    return shareItems
    |> map { items -> PreparedShareItems in
        var result: [PreparedShareItemContent] = []
        var progresses: [Float] = []
        for item in items {
            switch item {
                case .preparing:
                    return .preparing
                case let .progress(value):
                    progresses.append(value)
                case let .userInteractionRequired(value):
                    return .userInteractionRequired([value])
                case let .done(content):
                    result.append(content)
                    progresses.append(1.0)
            }
        }
        if result.count == items.count {
            if !additionalText.isEmpty {
                result.insert(PreparedShareItemContent.text(additionalText), at: 0)
            }
            return .done(result)
        } else {
            let value = progresses.reduce(0.0, +) / Float(progresses.count)
            return .progress(value)
        }
    }
    |> distinctUntilChanged(isEqual: { lhs, rhs in
        if case .preparing = lhs, case .preparing = rhs {
            return true
        } else {
            return false
        }
    })
}

public func sentShareItems(account: Account, to peerIds: [PeerId], items: [PreparedShareItemContent], silently: Bool) -> Signal<Float, Void> {
    var messages: [EnqueueMessage] = []
    var groupingKey: Int64?
    var mediaTypes: (photo: Int, video: Int, music: Int, other: Int) = (0, 0, 0, 0)
    if items.count > 1 {
        for item in items {
            if case let .media(result) = item, case let .media(media) = result {
                if media.media is TelegramMediaImage {
                    mediaTypes.photo += 1
                } else if let media = media.media as? TelegramMediaFile {
                    if media.isVideo {
                        mediaTypes.video += 1
                    } else if media.isVoice || media.isAnimated || media.isSticker {
                        mediaTypes = (0, 0, 0, 0)
                        break
                    } else if media.isMusic {
                        mediaTypes.music += 1
                    } else if let fileName = media.fileName?.lowercased(), fileName.hasPrefix(".mp3") || fileName.hasPrefix("m4a") {
                        mediaTypes.music += 1
                    } else {
                        mediaTypes.other += 1
                    }
                } else {
                    mediaTypes = (0, 0, 0, 0)
                    break
                }
            }
        }
    }
    
    if ((mediaTypes.photo + mediaTypes.video) > 1) && (mediaTypes.music == 0 && mediaTypes.other == 0) {
        groupingKey = Int64.random(in: Int64.min ... Int64.max)
    } else if ((mediaTypes.photo + mediaTypes.video) == 0) && ((mediaTypes.music > 1 && mediaTypes.other == 0) || (mediaTypes.music == 0 && mediaTypes.other > 1)) {
        groupingKey = Int64.random(in: Int64.min ... Int64.max)
    }
    
    var attributes: [MessageAttribute] = []
    if silently {
        attributes.append(NotificationInfoMessageAttribute(flags: .muted))
    }
    
    var mediaMessages: [EnqueueMessage] = []
    for item in items {
        switch item {
            case let .text(text):
                messages.append(.message(text: text, attributes: attributes, mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil, correlationId: nil))
            case let .media(media):
                switch media {
                    case let .media(reference):
                        let message: EnqueueMessage = .message(text: "", attributes: attributes, mediaReference: reference, replyToMessageId: nil, localGroupingKey: groupingKey, correlationId: nil)
                        messages.append(message)
                        mediaMessages.append(message)
                        
                }
                if let _ = groupingKey, mediaMessages.count % 10 == 0 {
                    groupingKey = Int64.random(in: Int64.min ... Int64.max)
                }
        }
    }
    
    return enqueueMessagesToMultiplePeers(account: account, peerIds: peerIds, messages: messages)
    |> castError(Void.self)
    |> mapToSignal { messageIds -> Signal<Float, Void> in
        let key: PostboxViewKey = .messages(Set(messageIds))
        return account.postbox.combinedView(keys: [key])
        |> castError(Void.self)
        |> mapToSignal { view -> Signal<Float, Void> in
            if let messagesView = view.views[key] as? MessagesView {
                for (_, message) in messagesView.messages {
                    if message.flags.contains(.Unsent) {
                        return .complete()
                    }
                }
            }
            return .single(1.0)
        }
        |> take(1)
    }
}
