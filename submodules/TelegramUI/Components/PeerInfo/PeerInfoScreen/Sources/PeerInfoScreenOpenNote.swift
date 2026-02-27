import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import Postbox
import TelegramCore
import AsyncDisplayKit
import ContextUI
import Pasteboard
import UndoUI

extension PeerInfoScreenNode {
    func openNoteContextMenu(node: ASDisplayNode, gesture: ContextGesture?) {
        guard let sourceNode = node as? ContextExtractedContentContainingNode else {
            return
        }
        guard let cachedData = self.data?.cachedData else {
            return
        }
        
        var noteText: String?
        var noteEntities: [MessageTextEntity]?
        if let cachedData = cachedData as? CachedUserData {
            noteText = cachedData.note?.text
            noteEntities = cachedData.note?.entities
        }
        
        guard let noteText, !noteText.isEmpty else {
            return
        }
        
        let copyAction = { [weak self] in
            guard let self else {
                return
            }
            storeMessageTextInPasteboard(noteText, entities: noteEntities ?? [])
            
            let toastText = self.presentationData.strings.PeerInfo_ToastNoteCopied
            self.controller?.present(UndoOverlayController(presentationData: self.presentationData, content: .copy(text: toastText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
        }
        
        var items: [ContextMenuItem] = []
        items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.PeerInfo_NoteActionEdit, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
            c?.dismiss {
                guard let self else {
                    return
                }
                self.headerNode.navigationButtonContainer.performAction?(.edit, nil, nil)
                
                for (_, section) in self.editingSections {
                    for (id, itemNode) in section.itemNodes {
                        if id == AnyHashable("note_edit") {
                            if let itemNode = itemNode as? PeerInfoScreenNoteListItemNode {
                                itemNode.focus()
                            }
                            break
                        }
                    }
                }
            }
        })))
        
        let copyText = self.presentationData.strings.PeerInfo_NoteActionCopy
        items.append(.action(ContextMenuActionItem(text: copyText, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
            c?.dismiss {
                copyAction()
            }
        })))
        
        let actions = ContextController.Items(content: .list(items))
        
        let contextController = makeContextController(presentationData: self.presentationData, source: .extracted(PeerInfoContextExtractedContentSource(sourceNode: sourceNode)), items: .single(actions), gesture: gesture)
        self.controller?.present(contextController, in: .window(.root))
    }
}
