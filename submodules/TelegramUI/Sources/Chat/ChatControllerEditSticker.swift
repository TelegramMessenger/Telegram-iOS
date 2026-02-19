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
    func openStickerEditing(file: TelegramMediaFile) {
        var emoji: [String] = []
        for attribute in file.attributes {
            if case let .Sticker(displayText, _, _) = attribute {
                emoji = [displayText]
            }
        }

        let controller = self.context.sharedContext.makeStickerEditorScreen(
            context: self.context,
            source: (file, emoji),
            mode: .generic,
            transitionArguments: nil,
            completion: { file, _, commit in
                commit()
                let _ = self.controllerInteraction?.sendSticker(.standalone(media: file), false, false, nil, false, nil, nil, nil, [])
            },
            cancelled: {}
        )
        self.push(controller)
    }
}
