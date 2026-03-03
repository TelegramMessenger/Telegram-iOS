import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import AsyncDisplayKit
import Display
import AccountContext
import ChatControllerInteraction
import LegacyMediaPickerUI

extension ChatControllerImpl {
    func openGifEditing(file: FileMediaReference, addCaption: Bool) {
        guard let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return
        }
        legacyMediaEditor(
            context: self.context,
            peer: peer,
            threadTitle: nil,
            media: file.abstract,
            mode: addCaption ? .caption : .default,
            initialCaption: NSAttributedString(),
            snapshots: [],
            transitionCompletion: {
            },
            getCaptionPanelView: { [weak self] in
                return self?.getCaptionPanelView(isFile: false, hasTimer: false)
            },
            sendMessagesWithSignals: { [weak self] signals, _, _, isCaptionAbove in
                guard let self else {
                    return
                }
                let parameters = ChatSendMessageActionSheetController.SendParameters(
                    effect: nil,
                    textIsAboveMedia: isCaptionAbove
                )
                self.enqueueMediaMessages(
                    fromGallery: false,
                    signals: signals,
                    originalMediaReference: file.abstract,
                    silentPosting: false,
                    scheduleTime: nil,
                    replyToSubject: nil,
                    parameters: parameters,
                    getAnimatedTransitionSource: nil,
                    completion: {}
                )
            },
            present: { [weak self] c, a in
                self?.present(c, in: .window(.root), with: a)
            }
        )
    }
}
