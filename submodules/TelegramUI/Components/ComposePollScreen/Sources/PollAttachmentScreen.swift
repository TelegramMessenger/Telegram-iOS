import Foundation
import UIKit
import Display
import AccountContext
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import LegacyComponents
import LegacyUI
import AttachmentUI
import MediaPickerUI
import LegacyCamera
import LegacyMediaPickerUI
import LocationUI
import AttachmentFileController
import ChatEntityKeyboardInputNode
import ICloudResources

public enum PollAttachmentSubject {
    case description
    case quizAnswer
    case option
}

public func presentPollAttachmentScreen(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?,
    subject: PollAttachmentSubject,
    availableButtons: [AttachmentButtonType],
    inputMediaNodeData: Signal<ChatEntityKeyboardInputNode.InputData?, NoError>? = nil,
    present: @escaping (ViewController, Bool) -> Void,
    completion: @escaping (AnyMediaReference) -> Void
) {
    let attachmentController = AttachmentController(
        context: context,
        updatedPresentationData: updatedPresentationData,
        style: .glass,
        chatLocation: nil,
        isScheduledMessages: false,
        buttons: availableButtons,
        initialButton: .gallery,
        makeEntityInputView: {
            return nil
        }
    )
    let inputMediaNodeDataPromise = Promise<ChatEntityKeyboardInputNode.InputData?>(nil)
    if let inputMediaNodeData {
        inputMediaNodeDataPromise.set(inputMediaNodeData)
    } else if availableButtons.contains(.sticker) || availableButtons.contains(.emoji) {
        inputMediaNodeDataPromise.set(.single(nil) |> then(
            ChatEntityKeyboardInputNode.inputData(
                context: context,
                chatPeerId: nil,
                areCustomEmojiEnabled: true,
                hasTrending: false,
                hasSearch: true,
                hasStickers: true,
                hasGifs: false,
                hideBackground: true,
                maskEdge: .fade,
                sendGif: nil
            )
            |> map(Optional.init)
        ))
    }
    
    attachmentController.requestController = { [weak attachmentController] type, controllerCompletion in
        let mediaPickerPollSubject: MediaPickerScreenImpl.Subject.AssetsMode.PollMode
        let filePickerPollSubject: AttachmentFileControllerSource.PollMode
        let locationPickerPollSubject: LocationPickerController.Source.PollMode
        let stickerPickerPollSubject: StickerAttachmentScreen.Source.PollMode
        switch subject {
        case .description:
            mediaPickerPollSubject = .description
            filePickerPollSubject = .description
            locationPickerPollSubject = .description
            stickerPickerPollSubject = .description
        case .quizAnswer:
            mediaPickerPollSubject = .quizAnswer
            filePickerPollSubject = .quizAnswer
            locationPickerPollSubject = .quizAnswer
            stickerPickerPollSubject = .quizAnswer
        default:
            mediaPickerPollSubject = .option
            filePickerPollSubject = .description
            locationPickerPollSubject = .option
            stickerPickerPollSubject = .option
        }
        
        switch type {
        case .gallery:
            let controller = MediaPickerScreenImpl(
                context: context,
                updatedPresentationData: updatedPresentationData,
                style: .glass,
                peer: nil,
                threadTitle: nil,
                chatLocation: nil,
                enableMultiselection: false,
                subject: .assets(nil, .poll(mode: mediaPickerPollSubject, asFile: false))
            )
            controller.getCaptionPanelView = {
                return nil
            }
            controller.legacyCompletion = { _, signals, _, _, _, _, sendCompletion in
                let _ = (legacyAssetPickerEnqueueMessages(context: context, account: context.account, signals: signals)
                |> deliverOnMainQueue).start(next: { items in
                    if let item = items.first, case let .message(_, _, _, mediaReference, _, _, _, _, _, _) = item.message, let mediaReference {
                        completion(mediaReference)
                        sendCompletion()
                    }
                })
            }
            controllerCompletion(controller, controller.mediaPickerContext)
            return true
        case .file:
            let controller = makeAttachmentFileControllerImpl(
                context: context,
                updatedPresentationData: updatedPresentationData,
                source: .poll(filePickerPollSubject),
                bannedSendMedia: nil,
                presentGallery: { [weak attachmentController] in
                    attachmentController?.dismiss(animated: true)
                    
                    let controller = MediaPickerScreenImpl(
                        context: context,
                        updatedPresentationData: updatedPresentationData,
                        style: .glass,
                        peer: nil,
                        threadTitle: nil,
                        chatLocation: nil,
                        enableMultiselection: false,
                        subject: .assets(nil, .poll(mode: mediaPickerPollSubject, asFile: true))
                    )
                    controller.getCaptionPanelView = {
                        return nil
                    }
                    controller.legacyCompletion = { _, signals, _, _, _, _, sendCompletion in
                        let _ = (legacyAssetPickerEnqueueMessages(context: context, account: context.account, signals: signals)
                        |> deliverOnMainQueue).start(next: { items in
                            if let item = items.first, case let .message(_, _, _, mediaReference, _, _, _, _, _, _) = item.message, let mediaReference {
                                completion(mediaReference)
                                sendCompletion()
                            }
                        })
                    }
                    controller.navigationPresentation = .modal
                    present(controller, true)
                },
                presentFiles: { [weak attachmentController] in
                    attachmentController?.dismiss(animated: true)
                    
                    let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
                    let controller = legacyICloudFilePicker(theme: presentationData.theme, documentTypes: ["public.item"], completion: { urls in
                        guard let url = urls.first else {
                            return
                        }
                        let _ = (iCloudFileDescription(url)
                        |> deliverOnMainQueue).start(next: { item in
                            guard let item else {
                                return
                            }
                            let fileId = Int64.random(in: Int64.min ... Int64.max)
                            let mimeType = guessMimeTypeByFileExtension((item.fileName as NSString).pathExtension)
                            var previewRepresentations: [TelegramMediaImageRepresentation] = []
                            if mimeType.hasPrefix("image/") || mimeType == "application/pdf" {
                                previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 320, height: 320), resource: ICloudFileResource(urlData: item.urlData, thumbnail: true), progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false))
                            }
                            var attributes: [TelegramMediaFileAttribute] = []
                            attributes.append(.FileName(fileName: item.fileName))
                            if let audioMetadata = item.audioMetadata {
                                attributes.append(.Audio(isVoice: false, duration: audioMetadata.duration, title: audioMetadata.title, performer: audioMetadata.performer, waveform: nil))
                            }
                            
                            let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: fileId), partialReference: nil, resource: ICloudFileResource(urlData: item.urlData, thumbnail: false), previewRepresentations: previewRepresentations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: mimeType, size: Int64(item.fileSize), attributes: attributes, alternativeRepresentations: [])
                            completion(.standalone(media: file))
                        })
                    })
                    present(controller, false)
                },
                presentDocumentScanner: nil,
                send: { mediaReferences, _, _, _ in
                    completion(mediaReferences.first!)
                }
            ) as! AttachmentFileControllerImpl
            controllerCompletion(controller, controller.mediaPickerContext)
            return true
        case .location:
            let controller = LocationPickerController(
                context: context,
                style: .glass,
                updatedPresentationData: updatedPresentationData,
                mode: .share(peer: nil, selfPeer: nil, hasLiveLocation: false),
                source: .poll(locationPickerPollSubject),
                completion: { location, _, _, _, _ in
                completion(.standalone(media: location))
            })
            controllerCompletion(controller, controller.mediaPickerContext)
            return true
        case .sticker:
            let _ = (inputMediaNodeDataPromise.get()
            |> filter { $0 != nil }
            |> take(1)
            |> deliverOnMainQueue).start(next: { content in
                guard let content = content?.stickers else {
                    return
                }
                let controller = StickerAttachmentScreen(
                    context: context,
                    mode: .stickers(content),
                    source: .poll(stickerPickerPollSubject),
                    completion: { sticker in
                        completion(sticker)
                    }
                )
                controllerCompletion(controller, controller.mediaPickerContext)
            })
            return true
        case .emoji:
            let _ = (inputMediaNodeDataPromise.get()
            |> filter { $0 != nil }
            |> take(1)
            |> deliverOnMainQueue).start(next: { content in
                guard let content = content?.emoji else {
                    return
                }
                let controller = StickerAttachmentScreen(
                    context: context,
                    mode: .emoji(content),
                    source: .poll(stickerPickerPollSubject),
                    completion: { sticker in
                        completion(sticker)
                    }
                )
                controllerCompletion(controller, controller.mediaPickerContext)
            })
            return true
        default:
            return false
        }
    }
    attachmentController.navigationPresentation = .flatModal
    present(attachmentController, true)
}
