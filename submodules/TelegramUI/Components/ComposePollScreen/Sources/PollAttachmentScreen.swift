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

public func presentPollAttachmentScreen(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?,
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
//    attachmentController.getSourceRect = { [weak self] in
//        if let strongSelf = self {
//            return strongSelf.chatDisplayNode.frameForAttachmentButton()?.offsetBy(dx: strongSelf.chatDisplayNode.supernode?.frame.minX ?? 0.0, dy: 0.0)
//        } else {
//            return nil
//        }
//    }
    attachmentController.requestController = { [weak attachmentController] type, controllerCompletion in
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
                subject: .assets(nil, .poll(.option))
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
            let controller = context.sharedContext.makeAttachmentFileController(context: context, updatedPresentationData: updatedPresentationData, audio: false, bannedSendMedia: nil, presentGallery: { [weak attachmentController] in
                attachmentController?.dismiss(animated: true)
                //self?.presentFileGallery()
            }, presentFiles: { [weak attachmentController] in
                attachmentController?.dismiss(animated: true)
                //self?.presentICloudFileGallery()
            }, presentDocumentScanner: {
                //self?.presentDocumentScanner()
            }, send: { mediaReferences in
                completion(mediaReferences.first!)
            })
            guard let controller = controller as? AttachmentFileControllerImpl else {
                return false
            }
            controllerCompletion(controller, controller.mediaPickerContext)
            return true
        case .location:
            let controller = LocationPickerController(context: context, style: .glass, updatedPresentationData: updatedPresentationData, mode: .share(peer: nil, selfPeer: nil, hasLiveLocation: false), completion: { location, _, _, _, _ in
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
                let controller = StickerAttachmentScreen(context: context, mode: .stickers(content), completion: { sticker in
                    completion(sticker)
                })
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
                let controller = StickerAttachmentScreen(context: context, mode: .emoji(content), completion: { sticker in
                    completion(sticker)
                })
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
