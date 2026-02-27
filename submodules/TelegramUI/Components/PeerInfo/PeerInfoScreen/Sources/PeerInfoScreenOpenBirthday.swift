import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import Postbox
import TelegramCore
import AsyncDisplayKit
import TelegramStringFormatting
import UndoUI
import ContextUI

extension PeerInfoScreenNode {
    func openBirthdayContextMenu(node: ASDisplayNode, gesture: ContextGesture?) {
        guard let sourceNode = node as? ContextExtractedContentContainingNode else {
            return
        }
        guard let cachedData = self.data?.cachedData else {
            return
        }
        
        var birthday: TelegramBirthday?
        if let cachedData = cachedData as? CachedUserData {
            birthday = cachedData.birthday
        }
        
        guard let birthday else {
            return
        }
        
        let copyAction = { [weak self] in
            guard let self else {
                return
            }
            let presentationData = self.presentationData
            let text = stringForCompactBirthday(birthday, strings: presentationData.strings)
            
            UIPasteboard.general.string = text
            
            self.controller?.present(UndoOverlayController(presentationData: self.presentationData, content: .copy(text: self.presentationData.strings.MyProfile_ToastBirthdayCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
        }
        
        var items: [ContextMenuItem] = []
        
        if self.isMyProfile {
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.MyProfile_BirthdayActionEdit, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                c?.dismiss {
                    guard let self else {
                        return
                    }
                    
                    self.state = self.state.withIsEditingBirthDate(true)
                    self.headerNode.navigationButtonContainer.performAction?(.edit, nil, nil)
                }
            })))
        }
        
        items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.MyProfile_BirthdayActionCopy, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { c, _ in
            c?.dismiss {
                copyAction()
            }
        })))
        
        let actions = ContextController.Items(content: .list(items))
        
        let contextController = makeContextController(presentationData: self.presentationData, source: .extracted(PeerInfoContextExtractedContentSource(sourceNode: sourceNode)), items: .single(actions), gesture: gesture)
        self.controller?.present(contextController, in: .window(.root))
    }
}
