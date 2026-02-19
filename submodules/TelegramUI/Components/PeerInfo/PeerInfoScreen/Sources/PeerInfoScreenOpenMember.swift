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
    func openMemberContextMenu(member: PeerInfoMember, node: ASDisplayNode, gesture: ContextGesture?) {
        guard let controller = self.controller else {
            return
        }
        var items: [ContextMenuItem] = []
        
        items.append(.action(ContextMenuActionItem(text: "Send Message", icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/MessageBubble"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
            c?.dismiss {
                guard let self, let navigationController = self.controller?.navigationController as? NavigationController else {
                    return
                }
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(EnginePeer(member.peer))))
            }
        })))
        
        items.append(.action(ContextMenuActionItem(text: "Edit Member Tag", icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Tag"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
            c?.dismiss {
                guard let self else {
                    return
                }
                self.performMemberAction(member: member, action: .editRank)
            }
        })))
        
        items.append(.action(ContextMenuActionItem(text: "Promote", icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Promote"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
            c?.dismiss {
                guard let self else {
                    return
                }
                self.performMemberAction(member: member, action: .promote)
            }
        })))
        
        items.append(.action(ContextMenuActionItem(text: "Restrict", icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Restrict"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
            c?.dismiss {
                guard let self else {
                    return
                }
                self.performMemberAction(member: member, action: .restrict)
            }
        })))
        
        items.append(.action(ContextMenuActionItem(text: "Remove", textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { [weak self] c, _ in
            c?.dismiss {
                guard let self else {
                    return
                }
                self.performMemberAction(member: member, action: .remove)
            }
        })))
        
        let actions = ContextController.Items(content: .list(items))
        
        let contextController = makeContextController(presentationData: self.presentationData, source: .reference(PeerInfoContextReferenceContentSource(controller: controller, sourceView: node.view)), items: .single(actions), gesture: gesture)
        self.controller?.present(contextController, in: .window(.root))
    }
}
