import Foundation
import UIKit
import Display
import AccountContext
import TelegramCore
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
import ChatTextLinkEditUI

public enum PollAttachmentSubject {
    public struct RichText: Equatable {
        public var photoVideoSelectionLimit: Int
        
        public init(photoVideoSelectionLimit: Int) {
            self.photoVideoSelectionLimit = photoVideoSelectionLimit
        }
    }
    
    case description
    case quizAnswer
    case option
    case richText(RichText)
}

func makePollAttachmentLinkWebpage(link: String) -> TelegramMediaWebpage {
    let mediaId = Int64.random(in: Int64.min ... Int64.max)
    return TelegramMediaWebpage(
        webpageId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: mediaId),
        content: .Loaded(TelegramMediaWebpageLoadedContent(
            url: link,
            displayUrl: link,
            hash: 0,
            type: nil,
            websiteName: nil,
            title: nil,
            text: nil,
            embedUrl: nil,
            embedType: nil,
            embedSize: nil,
            duration: nil,
            author: nil,
            isMediaLargeByDefault: nil,
            imageIsVideoCover: false,
            image: nil,
            file: nil,
            story: nil,
            attributes: [],
            instantPage: nil
        ))
    )
}

public func presentPollAttachmentScreen(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?,
    subject: PollAttachmentSubject,
    availableButtons: [AttachmentButtonType],
    inputMediaNodeData: Signal<ChatEntityKeyboardInputNode.InputData?, NoError>? = nil,
    present: @escaping (ViewController, Bool) -> Void,
    completion: @escaping ([AnyMediaReference]) -> Void
) {
    let attachmentController = AttachmentController(
        context: context,
        updatedPresentationData: updatedPresentationData,
        style: .glass,
        chatLocation: nil,
        isScheduledMessages: false,
        buttons: availableButtons,
        initialButton: .gallery
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
                maskEdge: .clip,
                sendGif: nil
            )
            |> map(Optional.init)
        ))
    }

    attachmentController.requestController = { [weak attachmentController] type, controllerCompletion in
        let mediaPickerAssetsMode: MediaPickerScreenImpl.Subject.AssetsMode
        let filePickerSource: AttachmentFileControllerSource
        let filePickerAssetsMode: MediaPickerScreenImpl.Subject.AssetsMode
        
        let locationPickerPollSubject: LocationPickerController.Source.PollMode
        let stickerPickerPollSubject: StickerAttachmentScreen.Source.PollMode
        
        var multiselectionLimit: Int?
        
        switch subject {
        case .description:
            mediaPickerAssetsMode = .poll(mode: .description, asFile: false)
            filePickerAssetsMode = .poll(mode: .description, asFile: true)
            filePickerSource = .poll(.description)
            
            locationPickerPollSubject = .description
            stickerPickerPollSubject = .description
        case .quizAnswer:
            mediaPickerAssetsMode = .poll(mode: .quizAnswer, asFile: false)
            filePickerAssetsMode = .poll(mode: .quizAnswer, asFile: true)
            filePickerSource = .poll(.quizAnswer)
            
            locationPickerPollSubject = .quizAnswer
            stickerPickerPollSubject = .quizAnswer
        case .option:
            mediaPickerAssetsMode = .poll(mode: .option, asFile: false)
            filePickerAssetsMode = .poll(mode: .option, asFile: true)
            filePickerSource = .poll(.quizAnswer)
            
            locationPickerPollSubject = .option
            stickerPickerPollSubject = .option
        case let .richText(richText):
            mediaPickerAssetsMode = .richText(asFile: false)
            filePickerAssetsMode = .richText(asFile: true)
            filePickerSource = .richText
            
            locationPickerPollSubject = .richText
            stickerPickerPollSubject = .richText
            
            if richText.photoVideoSelectionLimit > 1 {
                multiselectionLimit = richText.photoVideoSelectionLimit
            }
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
                isActionButtonDone: true,
                enableMultiselection: multiselectionLimit != nil && multiselectionLimit != 1,
                selectionLimit: multiselectionLimit,
                subject: .assets(nil, mediaPickerAssetsMode)
            )
            controller.getCaptionPanelView = {
                return nil
            }
            controller.legacyCompletion = { _, signals, _, _, _, _, sendCompletion in
                let _ = (legacyAssetPickerEnqueueMessages(context: context, account: context.account, signals: signals)
                |> deliverOnMainQueue).start(next: { items in
                    var references: [AnyMediaReference] = []
                    for item in items {
                        if case let .message(_, _, _, mediaReference, _, _, _, _, _, _) = item.message, let mediaReference {
                            references.append(mediaReference)
                        }
                    }
                    if !references.isEmpty {
                        completion(references)
                        sendCompletion()
                    }
                })
            }
            controllerCompletion(controller, controller.mediaPickerContext)
            return true
        case .file, .audio:
            let controller = makeAttachmentFileControllerImpl(
                context: context,
                updatedPresentationData: updatedPresentationData,
                mode: type == .audio ? .audio(.story) : .recent,
                source: filePickerSource,
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
                        subject: .assets(nil, filePickerAssetsMode)
                    )
                    controller.getCaptionPanelView = {
                        return nil
                    }
                    controller.legacyCompletion = { _, signals, _, _, _, _, sendCompletion in
                        let _ = (legacyAssetPickerEnqueueMessages(context: context, account: context.account, signals: signals)
                        |> deliverOnMainQueue).start(next: { items in
                            if let item = items.first, case let .message(_, _, _, mediaReference, _, _, _, _, _, _) = item.message, let mediaReference {
                                completion([mediaReference])
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

                            let file = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: fileId), partialReference: nil, resource: ICloudFileResource(urlData: item.urlData, thumbnail: false), previewRepresentations: previewRepresentations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: mimeType, size: Int64(item.fileSize), attributes: attributes, alternativeRepresentations: [])
                            completion([.standalone(media: file)])
                        })
                    })
                    present(controller, false)
                },
                presentDocumentScanner: nil,
                send: { mediaReferences, _, _, _ in
                    completion([mediaReferences.first!])
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
                completion([.standalone(media: location)])
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
                        completion([sticker])
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
                        completion([sticker])
                    }
                )
                controllerCompletion(controller, controller.mediaPickerContext)
            })
            return true
        case .link:
            attachmentController?.dismiss(animated: true)

            let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
            let controller = chatTextLinkEditController(
                context: context,
                updatedPresentationData: updatedPresentationData,
                text: presentationData.strings.CreatePoll_Link_Description,
                link: nil,
                preview: true,
                apply: { link, webpage in
                    guard let link else {
                        return
                    }
                    if let webpage {
                        completion([.standalone(media: webpage)])
                        return
                    }
                    completion([.standalone(media: makePollAttachmentLinkWebpage(link: link))])
                }
            )
            present(controller, false)
            return false
        default:
            return false
        }
    }
    attachmentController.navigationPresentation = .flatModal
    present(attachmentController, true)
}
