import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import TextFormat
import SaveToCameraRoll
import ImageCompression
import LocalMediaResources

public extension MediaEditorScreenImpl {
    static func makeEditStoryController(
        context: AccountContext,
        peer: EnginePeer,
        storyItem: EngineStoryItem,
        videoPlaybackPosition: Double?,
        cover: Bool,
        repost: Bool,
        transitionIn: MediaEditorScreenImpl.TransitionIn,
        transitionOut: MediaEditorScreenImpl.TransitionOut?,
        completed: @escaping () -> Void = {},
        willDismiss: @escaping () -> Void = {},
        update: @escaping (Disposable?) -> Void
    ) -> MediaEditorScreenImpl? {
        guard let peerReference = PeerReference(peer._asPeer()) else {
            return nil
        }
        let subject: Signal<MediaEditorScreenImpl.Subject?, NoError>
        subject = getStorySource(engine: context.engine, peerId: peer.id, id: Int64(storyItem.id))
        |> mapToSignal { source in
            if !repost, let source {
                return .single(.draft(source, Int64(storyItem.id)))
            } else {
                let media = storyItem.media._asMedia()
                return fetchMediaData(context: context, postbox: context.account.postbox, userLocation: .peer(peerReference.id), customUserContentType: .story, mediaReference: .story(peer: peerReference, id: storyItem.id, media: media))
                |> mapToSignal { (value, isImage) -> Signal<MediaEditorScreenImpl.Subject?, NoError> in
                    guard case let .data(data) = value, data.complete else {
                        return .complete()
                    }
                    if let image = UIImage(contentsOfFile: data.path) {
                        return .single(nil)
                        |> then(
                            .single(.image(image: image, dimensions: PixelDimensions(image.size), additionalImage: nil, additionalImagePosition: .bottomRight, fromCamera: false))
                            |> delay(0.1, queue: Queue.mainQueue())
                        )
                    } else {
                        var duration: Double?
                        if let file = media as? TelegramMediaFile {
                            duration = file.duration
                        }
                        let symlinkPath = data.path + ".mp4"
                        if fileSize(symlinkPath) == nil {
                            let _ = try? FileManager.default.linkItem(atPath: data.path, toPath: symlinkPath)
                        }
                        return .single(nil)
                        |> then(
                            .single(.video(videoPath: symlinkPath, thumbnail: nil, mirror: false, additionalVideoPath: nil, additionalThumbnail: nil, dimensions: PixelDimensions(width: 720, height: 1280), duration: duration ?? 0.0, videoPositionChanges: [], additionalVideoPosition: .bottomRight, fromCamera: false))
                        )
                    }
                }
            }
        }
        
        let initialCaption: NSAttributedString?
        let initialPrivacy: EngineStoryPrivacy?
        let initialMediaAreas: [MediaArea]
        if repost {
            initialCaption = nil
            initialPrivacy = nil
            initialMediaAreas = []
        } else {
            initialCaption = chatInputStateStringWithAppliedEntities(storyItem.text, entities: storyItem.entities)
            initialPrivacy = storyItem.privacy
            initialMediaAreas = storyItem.mediaAreas
        }
        
        let externalState = MediaEditorTransitionOutExternalState(
            storyTarget: nil,
            isForcedTarget: false,
            isPeerArchived: false,
            transitionOut: nil
        )
        
        var videoPlaybackPosition = videoPlaybackPosition
        if cover, case let .file(file) = storyItem.media {
            videoPlaybackPosition = 0.0
            for attribute in file.attributes {
                if case let .Video(_, _, _, _, coverTime, _) = attribute {
                    videoPlaybackPosition = coverTime
                    break
                }
            }
        }
        
        var updateProgressImpl: ((Float) -> Void)?
        let controller = MediaEditorScreenImpl(
            context: context,
            mode: .storyEditor(remainingCount: 1),
            subject: subject,
            isEditing: !repost,
            isEditingCover: cover,
            forwardSource: repost ? (peer, storyItem) : nil,
            initialCaption: initialCaption,
            initialPrivacy: initialPrivacy,
            initialMediaAreas: initialMediaAreas,
            initialVideoPosition: videoPlaybackPosition,
            transitionIn: transitionIn,
            transitionOut: { finished, isNew in
                if repost && finished {
                    if let transitionOut = externalState.transitionOut?(externalState.storyTarget, externalState.isPeerArchived), let destinationView = transitionOut.destinationView {
                        return MediaEditorScreenImpl.TransitionOut(
                            destinationView: destinationView,
                            destinationRect: transitionOut.destinationRect,
                            destinationCornerRadius: transitionOut.destinationCornerRadius
                        )
                    } else {
                        return nil
                    }
                } else {
                    return transitionOut
                }
            },
            completion: { results, commit in
                guard let result = results.first else {
                    return
                }
                let entities = generateChatInputTextEntities(result.caption)
                
                if repost {
                    let target: Stories.PendingTarget
                    let targetPeerId: EnginePeer.Id
                    if let sendAsPeerId = result.options.sendAsPeerId {
                        target = .peer(sendAsPeerId)
                        targetPeerId = sendAsPeerId
                    } else {
                        target = .myStories
                        targetPeerId = context.account.peerId
                    }
                    externalState.storyTarget = target
                    
                    completed()
                    
                    let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: targetPeerId))
                    |> deliverOnMainQueue).startStandalone(next: { peer in
                        guard let peer else {
                            return
                        }
                        
                        if case let .user(user) = peer {
                            externalState.isPeerArchived = user.storiesHidden ?? false
                            
                        } else if case let .channel(channel) = peer {
                            externalState.isPeerArchived = channel.storiesHidden ?? false
                        }
                        
                        let forwardInfo = Stories.PendingForwardInfo(peerId: peerReference.id, storyId: storyItem.id, isModified: result.media != nil)
                        
                        if let rootController = context.sharedContext.mainWindow?.viewController as? TelegramRootControllerInterface {
                            var existingMedia: EngineMedia?
                            if let _ = result.media {
                            } else {
                                existingMedia = storyItem.media
                            }
                            rootController.proceedWithStoryUpload(target: target, results: [result as! MediaEditorScreenResult], existingMedia: existingMedia, forwardInfo: forwardInfo, externalState: externalState, commit: commit)
                        }
                    })
                } else {
                    var updatedText: String?
                    var updatedCoverTimestamp: Double?
                    var updatedEntities: [MessageTextEntity]?
                    if result.caption.string != storyItem.text || entities != storyItem.entities {
                        updatedText = result.caption.string
                        updatedEntities = entities
                    }
                    if let coverTimestamp = result.coverTimestamp {
                        updatedCoverTimestamp = coverTimestamp
                    }
                    
                    if let mediaResult = result.media {
                        switch mediaResult {
                        case let .image(image, dimensions):
                            updateProgressImpl?(0.0)
                            
                            let tempFile = TempBox.shared.tempFile(fileName: "file")
                            defer {
                                TempBox.shared.dispose(tempFile)
                            }
                            if let imageData = compressImageToJPEG(image, quality: 0.7, tempFilePath: tempFile.path) {
                                update((context.engine.messages.editStory(peerId: peer.id, id: storyItem.id, media: .image(dimensions: dimensions, data: imageData, stickers: result.stickers), mediaAreas: result.mediaAreas, text: updatedText, entities: updatedEntities, privacy: nil)
                                |> deliverOnMainQueue).startStrict(next: { result in
                                    switch result {
                                    case let .progress(progress):
                                        updateProgressImpl?(progress)
                                    case .completed:
                                        Queue.mainQueue().after(0.1) {
                                            willDismiss()
                                            
                                            HapticFeedback().success()
                                            
                                            commit({})
                                        }
                                    }
                                }))
                            }
                        case let .video(content, firstFrameImage, values, duration, dimensions):
                            updateProgressImpl?(0.0)
                            
                            if let valuesData = try? JSONEncoder().encode(values) {
                                let data = MemoryBuffer(data: valuesData)
                                let digest = MemoryBuffer(data: data.md5Digest())
                                let adjustments = VideoMediaResourceAdjustments(data: data, digest: digest, isStory: true)
                                
                                let resource: TelegramMediaResource
                                switch content {
                                case let .imageFile(path):
                                    resource = LocalFileVideoMediaResource(randomId: Int64.random(in: .min ... .max), path: path, adjustments: adjustments)
                                case let .videoFile(path):
                                    resource = LocalFileVideoMediaResource(randomId: Int64.random(in: .min ... .max), path: path, adjustments: adjustments)
                                case let .asset(localIdentifier):
                                    resource = VideoLibraryMediaResource(localIdentifier: localIdentifier, conversion: .compress(adjustments))
                                }
                                
                                let tempFile = TempBox.shared.tempFile(fileName: "file")
                                defer {
                                    TempBox.shared.dispose(tempFile)
                                }
                                let firstFrameImageData = firstFrameImage.flatMap { compressImageToJPEG($0, quality: 0.6, tempFilePath: tempFile.path) }
                                let firstFrameFile = firstFrameImageData.flatMap { data -> TempBoxFile? in
                                    let file = TempBox.shared.tempFile(fileName: "image.jpg")
                                    if let _ = try? data.write(to: URL(fileURLWithPath: file.path)) {
                                        return file
                                    } else {
                                        return nil
                                    }
                                }
                                
                                update((context.engine.messages.editStory(peerId: peer.id, id: storyItem.id, media: .video(dimensions: dimensions, duration: duration, resource: resource, firstFrameFile: firstFrameFile, stickers: result.stickers, coverTime: nil), mediaAreas: result.mediaAreas, text: updatedText, entities: updatedEntities, privacy: nil)
                                |> deliverOnMainQueue).startStrict(next: { result in
                                    switch result {
                                    case let .progress(progress):
                                        updateProgressImpl?(progress)
                                    case .completed:
                                        Queue.mainQueue().after(0.1) {
                                            willDismiss()
                                            
                                            HapticFeedback().success()
                                            
                                            commit({})
                                        }
                                    }
                                }))
                            }
                        default:
                            break
                        }
                    } else if updatedText != nil || updatedCoverTimestamp != nil {
                        var media: EngineStoryInputMedia?
                        if let updatedCoverTimestamp {
                            if case let .file(file) = storyItem.media {
                                var updatedAttributes: [TelegramMediaFileAttribute] = []
                                for attribute in file.attributes {
                                    if case let .Video(duration, size, flags, preloadSize, _, videoCodec) = attribute {
                                        updatedAttributes.append(.Video(duration: duration, size: size, flags: flags, preloadSize: preloadSize, coverTime: min(duration, updatedCoverTimestamp), videoCodec: videoCodec))
                                    } else {
                                        updatedAttributes.append(attribute)
                                    }
                                }
                                media = .existing(media: file.withUpdatedAttributes(updatedAttributes))
                            }
                        }
                        let _ = (context.engine.messages.editStory(peerId: peer.id, id: storyItem.id, media: media, mediaAreas: nil, text: updatedText, entities: updatedEntities, privacy: nil)
                        |> deliverOnMainQueue).startStandalone(next: { result in
                            switch result {
                            case .completed:
                                Queue.mainQueue().after(0.1) {
                                    willDismiss()
                                        
                                    HapticFeedback().success()
                                    commit({})
                                }
                            default:
                                break
                            }
                        })
                    } else {
                        willDismiss()
                        
                        HapticFeedback().success()
                        
                        commit({})
                    }
                }
            }
        )
        controller.willDismiss = willDismiss
        controller.navigationPresentation = .flatModal
        
        updateProgressImpl = { [weak controller] progress in
            controller?.updateEditProgress(progress, cancel: {
                update(nil)
            })
        }
        
        return controller
    }
}
