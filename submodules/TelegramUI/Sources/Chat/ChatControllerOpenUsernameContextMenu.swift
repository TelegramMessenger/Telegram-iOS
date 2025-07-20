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
import AvatarNode
import ChatControllerInteraction

extension ChatControllerImpl {
    func openMentionContextMenu(username: String, peerId: EnginePeer.Id?, params: ChatControllerInteraction.LongTapParams) -> Void {
        guard let _ = params.message, let contentNode = params.contentNode else {
            return
        }
    
        let recognizer: TapLongTapOrDoubleTapGestureRecognizer? = nil// anyRecognizer as? TapLongTapOrDoubleTapGestureRecognizer
        let gesture: ContextGesture? = nil // anyRecognizer as? ContextGesture
        
        let source: ContextContentSource
//                if let location = location {
//                    source = .location(ChatMessageContextLocationContentSource(controller: self, location: messageNode.view.convert(messageNode.bounds, to: nil).origin.offsetBy(dx: location.x, dy: location.y)))
//                } else {
            source = .extracted(ChatMessageLinkContextExtractedContentSource(chatNode: self.chatDisplayNode, contentNode: contentNode))
//                }
        
        params.progress?.set(.single(true))
                
        let peer: Signal<EnginePeer?, NoError>
        if let peerId {
            peer = self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        } else {
            peer = self.context.engine.peers.resolvePeerByName(name: username, referrer: nil)
            |> mapToSignal { value in
                switch value {
                case .progress:
                    return .complete()
                case let .result(result):
                    return .single(result)
                }
            }
        }
        
        let _ = (peer
        |> deliverOnMainQueue).start(next: { [weak self] peer in
            guard let self else {
                return
            }
            params.progress?.set(.single(false))
                         
            var items: [ContextMenuItem] = []
            if let peer {
                if case .user = peer {
                    items.append(
                        .action(ContextMenuActionItem(text: self.presentationData.strings.Chat_Context_Username_SendMessage, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/MessageBubble"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                            f(.default)
                            guard let self else {
                                return
                            }
                            self.openPeer(peer: peer, navigation: .chat(textInputState: nil, subject: nil, peekData: nil), fromMessage: nil)
                        }))
                    )
                } else {
                    var isGroup = true
                    if case let .channel(channel) = peer, case .broadcast = channel.info {
                        isGroup = false
                    }
                    
                    let openTitle: String
                    let openIcon: UIImage?
                    
                    if isGroup {
                        openTitle = self.presentationData.strings.Chat_Context_Username_OpenGroup
                        openIcon = UIImage(bundleImageName: "Chat/Context Menu/Groups")
                    } else {
                        openTitle = self.presentationData.strings.Chat_Context_Username_OpenChannel
                        openIcon = UIImage(bundleImageName: "Chat/Context Menu/Channels")
                    }
                    items.append(
                        .action(ContextMenuActionItem(text: openTitle, icon: { theme in return generateTintedImage(image: openIcon, color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                            f(.default)
                            guard let self else {
                                return
                            }
                            self.openPeer(peer: peer, navigation: .chat(textInputState: nil, subject: nil, peekData: nil), fromMessage: nil)
                        }))
                    )
                }
            }
            
            items.append(
                .action(ContextMenuActionItem(text: self.presentationData.strings.Chat_Context_Username_Copy, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { [weak self]  _, f in
                    f(.default)

                    guard let self else {
                        return
                    }
                    
                    UIPasteboard.general.string = username

                    self.present(UndoOverlayController(presentationData: self.presentationData, content: .copy(text: presentationData.strings.Conversation_UsernameCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                }))
            )
            
            items.append(.separator)
            if let peer {
                let avatarSize = CGSize(width: 28.0, height: 28.0)
                let avatarSignal = peerAvatarCompleteImage(account: self.context.account, peer: peer, size: avatarSize)
                
                let subtitle = NSMutableAttributedString(string: self.presentationData.strings.Chat_Context_Phone_ViewProfile + " >")
                if let range = subtitle.string.range(of: ">"), let arrowImage = UIImage(bundleImageName: "Item List/InlineTextRightArrow") {
                    subtitle.addAttribute(.attachment, value: arrowImage, range: NSRange(range, in: subtitle.string))
                    subtitle.addAttribute(.baselineOffset, value: 1.0, range: NSRange(range, in: subtitle.string))
                }
                
                items.append(
                    .action(ContextMenuActionItem(text: peer.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder), textLayout: .secondLineWithAttributedValue(subtitle), icon: { theme in return nil }, iconSource: ContextMenuActionItemIconSource(size: avatarSize, signal: avatarSignal), iconPosition: .left, action: { [weak self]  _, f in
                        f(.default)
                        
                        guard let self else {
                            return
                        }
                        self.openPeer(peer: peer, navigation: .info(ChatControllerInteractionNavigateToPeer.InfoParams(ignoreInSavedMessages: true)), fromMessage: nil)
                    }))
                )
            } else {
                let emptyAction: ((ContextMenuActionItem.Action) -> Void)? = nil
                items.append(
                    .action(ContextMenuActionItem(text: self.presentationData.strings.Chat_Context_Username_NotOnTelegram, textLayout: .multiline, textFont: .small, icon: { _ in return nil }, action: emptyAction))
                )
            }
            
            self.canReadHistory.set(false)
            
            let controller = ContextController(presentationData: self.presentationData, source: source, items: .single(ContextController.Items(content: .list(items))), recognizer: recognizer, gesture: gesture, disableScreenshots: false)
            controller.dismissed = { [weak self] in
                self?.canReadHistory.set(true)
            }
            
            self.window?.presentInGlobalOverlay(controller)
        })
    }
}
