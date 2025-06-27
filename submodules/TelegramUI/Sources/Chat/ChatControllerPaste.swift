import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramUIPreferences
import AccountContext
import MediaPickerUI
import MediaPasteboardUI
import LegacyMediaPickerUI
import MediaEditor
import ChatEntityKeyboardInputNode

extension ChatControllerImpl {
    func displayPasteMenu(_ subjects: [MediaPickerScreenImpl.Subject.Media]) {
        let _ = (self.context.sharedContext.accountManager.transaction { transaction -> GeneratedMediaStoreSettings in
            let entry = transaction.getSharedData(ApplicationSpecificSharedDataKeys.generatedMediaStoreSettings)?.get(GeneratedMediaStoreSettings.self)
            return entry ?? GeneratedMediaStoreSettings.defaultSettings
        }
        |> deliverOnMainQueue).startStandalone(next: { [weak self] settings in
            if let strongSelf = self, let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer {
                var enableMultiselection = true
                if strongSelf.presentationInterfaceState.interfaceState.postSuggestionState != nil {
                    enableMultiselection = false
                }
                
                strongSelf.chatDisplayNode.dismissInput()
                let controller = mediaPasteboardScreen(
                    context: strongSelf.context,
                    updatedPresentationData: strongSelf.updatedPresentationData,
                    peer: EnginePeer(peer),
                    subjects: subjects,
                    presentMediaPicker: { [weak self] subject, saveEditedPhotos, bannedSendPhotos, bannedSendVideos, present in
                        if let strongSelf = self {
                            strongSelf.presentMediaPicker(subject: subject, saveEditedPhotos: saveEditedPhotos, bannedSendPhotos: bannedSendPhotos, bannedSendVideos: bannedSendVideos, enableMultiselection: enableMultiselection, present: present, updateMediaPickerContext: { _ in }, completion: { [weak self] fromGallery, signals, silentPosting, scheduleTime, parameters, getAnimatedTransitionSource, completion in
                                self?.enqueueMediaMessages(fromGallery: fromGallery, signals: signals, silentPosting: silentPosting, scheduleTime: scheduleTime, parameters: parameters, getAnimatedTransitionSource: getAnimatedTransitionSource, completion: completion)
                            })
                        }
                    },
                    getSourceRect: nil,
                    makeEntityInputView: { [weak self] in
                        guard let self else {
                            return nil
                        }
                        return EntityInputView(context: self.context, isDark: false, areCustomEmojiEnabled: self.presentationInterfaceState.customEmojiAvailable)
                    }
                )
                controller.navigationPresentation = .flatModal
                strongSelf.push(controller)
            }
        })
    }
    
    func enqueueGifData(_ data: Data) {
        self.enqueueMediaMessageDisposable.set((legacyEnqueueGifMessage(account: self.context.account, data: data) |> deliverOnMainQueue).startStrict(next: { [weak self] message in
            if let strongSelf = self {
                strongSelf.presentPaidMessageAlertIfNeeded(completion: { [weak self] postpone in
                    guard let strongSelf = self else {
                        return
                    }
                    let replyMessageSubject = strongSelf.presentationInterfaceState.interfaceState.replyMessageSubject
                    strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                        if let strongSelf = self {
                            strongSelf.chatDisplayNode.collapseInput()
                            
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil).withUpdatedPostSuggestionState(nil) }
                            })
                        }
                    }, nil)
                    strongSelf.sendMessages([message].map { $0.withUpdatedReplyToMessageId(replyMessageSubject?.subjectModel) })
                })
            }
        }))
    }
    
    func enqueueVideoData(_ data: Data) {
        self.enqueueMediaMessageDisposable.set((legacyEnqueueGifMessage(account: self.context.account, data: data) |> deliverOnMainQueue).startStrict(next: { [weak self] message in
            if let strongSelf = self {
                strongSelf.presentPaidMessageAlertIfNeeded(completion: { [weak self] postpone in
                    guard let strongSelf = self else {
                        return
                    }
                    let replyMessageSubject = strongSelf.presentationInterfaceState.interfaceState.replyMessageSubject
                    strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                        if let strongSelf = self {
                            strongSelf.chatDisplayNode.collapseInput()
                            
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil).withUpdatedPostSuggestionState(nil) }
                            })
                        }
                    }, nil)
                    strongSelf.sendMessages([message].map { $0.withUpdatedReplyToMessageId(replyMessageSubject?.subjectModel) })
                })
            }
        }))
    }
    
    func enqueueStickerImage(_ image: UIImage, isMemoji: Bool) {
        let size = image.size.aspectFitted(CGSize(width: 512.0, height: 512.0))
        self.enqueueMediaMessageDisposable.set((convertToWebP(image: image, targetSize: size, targetBoundingSize: size, quality: 0.9) |> deliverOnMainQueue).startStrict(next: { [weak self] data in
            if let strongSelf = self, !data.isEmpty {
                let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                strongSelf.context.account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                
                var fileAttributes: [TelegramMediaFileAttribute] = []
                fileAttributes.append(.FileName(fileName: "sticker.webp"))
                fileAttributes.append(.Sticker(displayText: "", packReference: nil, maskData: nil))
                fileAttributes.append(.ImageSize(size: PixelDimensions(size)))
                
                let media = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: Int64.random(in: Int64.min ... Int64.max)), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "image/webp", size: Int64(data.count), attributes: fileAttributes, alternativeRepresentations: [])
                let message = EnqueueMessage.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: media), threadId: strongSelf.chatLocation.threadId, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                
                strongSelf.presentPaidMessageAlertIfNeeded(completion: { [weak self] postpone in
                    guard let strongSelf = self else {
                        return
                    }
                    let replyMessageSubject = strongSelf.presentationInterfaceState.interfaceState.replyMessageSubject
                    strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                        if let strongSelf = self {
                            strongSelf.chatDisplayNode.collapseInput()
                            
                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil).withUpdatedPostSuggestionState(nil) }
                            })
                        }
                    }, nil)
                    strongSelf.sendMessages([message].map { $0.withUpdatedReplyToMessageId(replyMessageSubject?.subjectModel) }, postpone: postpone)
                })
            }
        }))
    }
    
    func enqueueStickerFile(_ file: TelegramMediaFile) {
        let message = EnqueueMessage.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: self.chatLocation.threadId, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
        
        self.presentPaidMessageAlertIfNeeded(completion: { [weak self] postpone in
            guard let self else {
                return
            }
            let replyMessageSubject = self.presentationInterfaceState.interfaceState.replyMessageSubject
            self.chatDisplayNode.setupSendActionOnViewUpdate({ [weak self] in
                if let strongSelf = self {
                    strongSelf.chatDisplayNode.collapseInput()
                    
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                        $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil).withUpdatedPostSuggestionState(nil) }
                    })
                }
            }, nil)
            self.sendMessages([message].map { $0.withUpdatedReplyToMessageId(replyMessageSubject?.subjectModel) })
            
            Queue.mainQueue().after(3.0) {
                if let message = self.chatDisplayNode.historyNode.lastVisbleMesssage(), let file = message.media.first(where: { $0 is TelegramMediaFile }) as? TelegramMediaFile, file.isSticker {
                    self.context.engine.stickers.addRecentlyUsedSticker(fileReference: .message(message: MessageReference(message), media: file))
                }
            }
        })
    }
    
    func enqueueAnimatedStickerData(_ data: Data) {
        guard let animatedImage = UIImage.animatedImageFromData(data: data), let thumbnailImage = animatedImage.images.first else {
            return
        }
        
        let dimensions = PixelDimensions(width: 1080, height: 1920)
        let image = generateImage(dimensions.cgSize, opaque: false, scale: 1.0, rotatedContext: { size, context in
            context.clear(CGRect(origin: .zero, size: size))
        })!
        
        let blackImage = generateImage(dimensions.cgSize, opaque: true, scale: 1.0, rotatedContext: { size, context in
            context.setFillColor(UIColor.black.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
        })!
        
        let stickerEntity = DrawingStickerEntity(content: .animatedImage(data, thumbnailImage))
        stickerEntity.referenceDrawingSize = dimensions.cgSize
        stickerEntity.position = CGPoint(x: dimensions.cgSize.width / 2.0, y: dimensions.cgSize.height / 2.0)
        stickerEntity.scale = 3.5
        
        let entities: [CodableDrawingEntity] = [
            .sticker(stickerEntity)
        ]
        
        let values = MediaEditorValues(
            peerId: self.context.account.peerId,
            originalDimensions: dimensions,
            cropOffset: .zero,
            cropRect: nil,
            cropScale: 1.0,
            cropRotation: 1.0,
            cropMirroring: false,
            cropOrientation: .up,
            gradientColors: [.clear, .clear],
            videoTrimRange: nil,
            videoIsMuted: false,
            videoIsFullHd: false,
            videoIsMirrored: false,
            videoVolume: nil,
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
            maskDrawing: blackImage,
            entities: entities,
            toolValues: [:],
            audioTrack: nil,
            audioTrackTrimRange: nil,
            audioTrackOffset: nil,
            audioTrackVolume: nil,
            audioTrackSamples: nil,
            collageTrackSamples: nil,
            coverImageTimestamp: nil,
            coverDimensions: nil,
            qualityPreset: nil
        )
        
        let configuration = recommendedVideoExportConfiguration(values: values, duration: animatedImage.duration, frameRate: 30.0, isSticker: true)
        
        let path = NSTemporaryDirectory() + "\(Int64.random(in: Int64.min ... Int64.max)).webm"
        let videoExport = MediaEditorVideoExport(
            postbox: self.context.account.postbox,
            subject: .image(image: image),
            configuration: configuration,
            outputPath: path
        )
        
        let _ = (videoExport.status
        |> deliverOnMainQueue).startStandalone(next: { [weak self] status in
            guard let self else {
                return
            }
            switch status {
            case .completed:
                var fileAttributes: [TelegramMediaFileAttribute] = []
                fileAttributes.append(.FileName(fileName: "sticker.webm"))
                fileAttributes.append(.Sticker(displayText: "", packReference: nil, maskData: nil))
                fileAttributes.append(.Video(duration: animatedImage.duration, size: PixelDimensions(width: 512, height: 512), flags: [], preloadSize: nil, coverTime: nil, videoCodec: nil))
                
                let previewRepresentations: [TelegramMediaImageRepresentation] = []

                let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                self.context.account.postbox.mediaBox.copyResourceData(resource.id, fromTempPath: path)
                
                let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: Int64.random(in: Int64.min ... Int64.max)), partialReference: nil, resource: resource, previewRepresentations: previewRepresentations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/webm", size: 0, attributes: fileAttributes, alternativeRepresentations: [])
                self.enqueueStickerFile(file)
            default:
                break
            }
        })
    }
}
