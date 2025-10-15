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
import AttachmentTextInputPanelNode

public func mediaPasteboardScreen(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
    peer: EnginePeer,
    subjects: [MediaPickerScreenImpl.Subject.Media],
    presentMediaPicker: @escaping (_ subject: MediaPickerScreenImpl.Subject, _ saveEditedPhotos: Bool, _ bannedSendPhotos: (Int32, Bool)?, _ bannedSendVideos: (Int32, Bool)?, _ present: @escaping (MediaPickerScreenImpl, AttachmentMediaPickerContext?) -> Void) -> Void,
    getSourceRect: (() -> CGRect?)? = nil,
    makeEntityInputView: @escaping () -> AttachmentTextInputPanelInputView? = { return nil }
) -> ViewController {
    let controller = AttachmentController(context: context, updatedPresentationData: updatedPresentationData, chatLocation: .peer(id: peer.id), buttons: [.standalone], initialButton: .standalone, makeEntityInputView: makeEntityInputView)
    controller.requestController = { _, present in
        presentMediaPicker(.media(subjects), false, nil, nil, { mediaPicker, mediaPickerContext in
            present(mediaPicker, mediaPickerContext)
        })
    }
    controller.updateSelectionCount(subjects.count)
    controller.getSourceRect = getSourceRect
    return controller
}
