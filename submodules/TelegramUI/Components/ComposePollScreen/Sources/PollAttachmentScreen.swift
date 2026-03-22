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
    inputMediaNodeData: Signal<ChatEntityKeyboardInputNode.InputData?, NoError> = .single(nil),
    present: @escaping (ViewController) -> Void,
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
    attachmentController.requestController = { [weak attachmentController] type, controllerCompletion in
        switch type {
        case .gallery:
            let mediaPickerPollSubject: MediaPickerScreenImpl.Subject.AssetsMode.PollMode
            switch subject {
            case .description:
                mediaPickerPollSubject = .description
            case .quizAnswer:
                mediaPickerPollSubject = .quizAnswer
            case .option:
                mediaPickerPollSubject = .option
            }
            let controller = MediaPickerScreenImpl(
                context: context,
                updatedPresentationData: updatedPresentationData,
                style: .glass,
                peer: nil,
                threadTitle: nil,
                chatLocation: nil,
                enableMultiselection: false,
                subject: .assets(nil, .poll(mediaPickerPollSubject))
            )
            controller.getCaptionPanelView = {
                return nil
            }
            controller.legacyCompletion = { fromGallery, signals, silently, scheduleTime, parameters, getAnimatedTransitionSource, sendCompletion in
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
            let filePickerPollSubject: AttachmentFileControllerSource.PollMode
            switch subject {
            case .description:
                filePickerPollSubject = .description
            case .quizAnswer:
                filePickerPollSubject = .quizAnswer
            default:
                filePickerPollSubject = .description
            }
            let controller = makeAttachmentFileControllerImpl(
                context: context,
                updatedPresentationData: updatedPresentationData,
                source: .poll(filePickerPollSubject),
                bannedSendMedia: nil,
                presentGallery: {},
                presentFiles: { [weak attachmentController] in
                    attachmentController?.dismiss(animated: true)
                    //TODO
                },
                presentDocumentScanner: nil,
                send: { mediaReferences in
                    completion(mediaReferences.first!)
                }
            ) as! AttachmentFileControllerImpl
            controllerCompletion(controller, controller.mediaPickerContext)
            return true
        case .location:
            let locationPickerPollSubject: LocationPickerController.Source.PollMode
            switch subject {
            case .description:
                locationPickerPollSubject = .description
            case .quizAnswer:
                locationPickerPollSubject = .quizAnswer
            case .option:
                locationPickerPollSubject = .option
            }
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
            let _ = (inputMediaNodeData
            |> take(1)
            |> deliverOnMainQueue).start(next: { content in
                guard let content = content?.stickers else {
                    return
                }
                let stickerPickerPollSubject: StickerAttachmentScreen.Source.PollMode
                switch subject {
                case .description:
                    stickerPickerPollSubject = .description
                case .quizAnswer:
                    stickerPickerPollSubject = .quizAnswer
                case .option:
                    stickerPickerPollSubject = .option
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
            let _ = (inputMediaNodeData
            |> take(1)
            |> deliverOnMainQueue).start(next: { content in
                guard let content = content?.emoji else {
                    return
                }
                let stickerPickerPollSubject: StickerAttachmentScreen.Source.PollMode
                switch subject {
                case .description:
                    stickerPickerPollSubject = .description
                case .quizAnswer:
                    stickerPickerPollSubject = .quizAnswer
                case .option:
                    stickerPickerPollSubject = .option
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
    present(attachmentController)
}
