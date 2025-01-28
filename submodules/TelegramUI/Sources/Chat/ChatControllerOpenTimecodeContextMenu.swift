import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import AsyncDisplayKit
import Display
import ContextUI
import UndoUI
import AccountContext
import ChatMessageItemView
import ChatMessageItemCommon
import ChatControllerInteraction

extension ChatControllerImpl {
    func openTimecodeContextMenu(timecode: String, value: Double, params: ChatControllerInteraction.LongTapParams) -> Void {
        guard let message = params.message, let contentNode = params.contentNode else {
            return
        }
        
        guard let messages = self.chatDisplayNode.historyNode.messageGroupInCurrentHistoryView(message.id) else {
            return
        }
            
        var updatedMessages = messages
        for i in 0 ..< updatedMessages.count {
            if updatedMessages[i].id == message.id {
                let message = updatedMessages.remove(at: i)
                updatedMessages.insert(message, at: 0)
                break
            }
        }
               
        let recognizer: TapLongTapOrDoubleTapGestureRecognizer? = nil// anyRecognizer as? TapLongTapOrDoubleTapGestureRecognizer
        let gesture: ContextGesture? = nil // anyRecognizer as? ContextGesture
        
        let source: ContextContentSource
//                if let location = location {
//                    source = .location(ChatMessageContextLocationContentSource(controller: self, location: messageNode.view.convert(messageNode.bounds, to: nil).origin.offsetBy(dx: location.x, dy: location.y)))
//                } else {
            source = .extracted(ChatMessageLinkContextExtractedContentSource(chatNode: self.chatDisplayNode, contentNode: contentNode))
//                }
        
        var items: [ContextMenuItem] = []
        
        items.append(
            .action(ContextMenuActionItem(text: self.presentationData.strings.Chat_Context_Timecode_Copy, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { [weak self]  _, f in
                f(.default)

                guard let self else {
                    return
                }
                
                if message.id.namespace == Namespaces.Message.Cloud, let channel = message.peers[message.id.peerId] as? TelegramChannel, let addressName = channel.addressName {
                    var timestampSuffix = ""
                    let startAtTimestamp = parseTimeString(timecode)
                    
                    var startAtTimestampString = ""
                    let hours = startAtTimestamp / 3600
                    let minutes = startAtTimestamp / 60 % 60
                    let seconds = startAtTimestamp % 60
                    if hours == 0 && minutes == 0 {
                        startAtTimestampString = "\(startAtTimestamp)"
                    } else {
                        if hours != 0 {
                            startAtTimestampString += "\(hours)h"
                        }
                        if minutes != 0 {
                            startAtTimestampString += "\(minutes)m"
                        }
                        if seconds != 0 {
                            startAtTimestampString += "\(seconds)s"
                        }
                    }
                    timestampSuffix = "?t=\(startAtTimestampString)"
                    let inputCopyText = "https://t.me/\(addressName)/\(message.id.id)\(timestampSuffix)"
                    UIPasteboard.general.string = inputCopyText
                } else {
                    UIPasteboard.general.string = timecode
                }

                self.present(UndoOverlayController(presentationData: self.presentationData, content: .copy(text: presentationData.strings.Conversation_TextCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
            }))
        )
         
        self.canReadHistory.set(false)
        
        let controller = ContextController(presentationData: self.presentationData, source: source, items: .single(ContextController.Items(content: .list(items))), recognizer: recognizer, gesture: gesture, disableScreenshots: false)
        controller.dismissed = { [weak self] in
            self?.canReadHistory.set(true)
        }
        
        self.window?.presentInGlobalOverlay(controller)
    }
}

private func parseTimeString(_ timeString: String) -> Int {
    let parts = timeString.split(separator: ":").map(String.init)
    
    switch parts.count {
    case 1:
        // Single component (e.g. "1", "10") => seconds
        return Int(parts[0]) ?? 0
        
    case 2:
        // Two components (e.g. "1:01", "10:30") => minutes:seconds
        let minutes = Int(parts[0]) ?? 0
        let seconds = Int(parts[1]) ?? 0
        return minutes * 60 + seconds
        
    case 3:
        // Three components (e.g. "1:01:01", "10:00:00") => hours:minutes:seconds
        let hours = Int(parts[0]) ?? 0
        let minutes = Int(parts[1]) ?? 0
        let seconds = Int(parts[2]) ?? 0
        return hours * 3600 + minutes * 60 + seconds
        
    default:
        // Fallback to 0 or handle invalid format
        return 0
    }
}
