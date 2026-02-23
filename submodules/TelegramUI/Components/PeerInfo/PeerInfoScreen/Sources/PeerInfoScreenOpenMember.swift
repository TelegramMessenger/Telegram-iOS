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
        guard let controller = self.controller, let enclosingPeer = self.data?.peer else {
            return
        }
        var items: [ContextMenuItem] = []
        
        let actions = availableActionsForMemberOfPeer(accountPeerId: self.context.account.peerId, peer: enclosingPeer, member: member)
        
        //TODO:localize
        if member.id != self.context.account.peerId {
            items.append(.action(ContextMenuActionItem(text: "Send Message", icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/MessageBubble"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                c?.dismiss {
                    guard let self, let navigationController = self.controller?.navigationController as? NavigationController else {
                        return
                    }
                    self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(EnginePeer(member.peer))))
                }
            })))
        }
        
        if actions.contains(.editRank) {
            items.append(.action(ContextMenuActionItem(text: "Edit Member Tag", icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Tag"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                c?.dismiss {
                    guard let self else {
                        return
                    }
                    self.performMemberAction(member: member, action: .editRank)
                }
            })))
        }
        
        if actions.contains(.promote) && enclosingPeer is TelegramChannel {
            items.append(.action(ContextMenuActionItem(text: "Promote", icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Promote"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                c?.dismiss {
                    guard let self else {
                        return
                    }
                    self.performMemberAction(member: member, action: .promote)
                }
            })))
        }
        
        if actions.contains(.restrict) {
            if enclosingPeer is TelegramChannel {
                items.append(.action(ContextMenuActionItem(text: "Restrict", icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Restrict"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                    c?.dismiss {
                        guard let self else {
                            return
                        }
                        self.performMemberAction(member: member, action: .restrict)
                    }
                })))
            }
            
            items.append(.action(ContextMenuActionItem(text: "Remove", textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { [weak self] c, _ in
                c?.dismiss {
                    guard let self else {
                        return
                    }
                    self.performMemberAction(member: member, action: .remove)
                }
            })))
        }
        
        if items.isEmpty {
            gesture?.cancel()
            return
        }
        
        let source: ContextContentSource
        if let node = node as? ContextExtractedContentContainingNode {
            source = .extracted(PeerInfoMemberExtractedContentSource(sourceNode: node, keepInPlace: false, blurBackground: true, centerVertically: false, shouldBeDismissed: .single(false)))
        } else {
            source = .reference(PeerInfoContextReferenceContentSource(controller: controller, sourceView: node.view))
        }
        let contextController = makeContextController(presentationData: self.presentationData, source: source, items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
        self.controller?.present(contextController, in: .window(.root))
    }
}
