import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import TelegramCore
import AttachmentUI
import MediaPickerUI
import AccountContext
import LegacyComponents

public func mediaPasteboardScreen(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
    peer: EnginePeer,
    subjects: [MediaPickerScreen.Subject.Media],
    presentMediaPicker: @escaping (_ subject: MediaPickerScreen.Subject, _ saveEditedPhotos: Bool, _ bannedSendMedia: (Int32, Bool)?, _ present: @escaping (MediaPickerScreen, AttachmentMediaPickerContext?) -> Void) -> Void,
    getSourceRect: (() -> CGRect?)? = nil
) -> ViewController {
    let controller = AttachmentController(context: context, updatedPresentationData: updatedPresentationData, chatLocation: .peer(id: peer.id), buttons: [.standalone], initialButton: .standalone)
    controller.requestController = { _, present in
        presentMediaPicker(.media(subjects), false, nil, { mediaPicker, mediaPickerContext in
            present(mediaPicker, mediaPickerContext)
        })
    }
    controller.updateSelectionCount(subjects.count)
    controller.getSourceRect = getSourceRect
    return controller
}
