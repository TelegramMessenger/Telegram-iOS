import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import AsyncDisplayKit
import Display
import TelegramNotices
import ContextUI
import AccountContext
import ChatMessageItemView
import ChatMessageItemCommon
import AvatarNode
import UndoUI
import MessageUI
import PeerInfoUI
import ChatControllerInteraction

extension ChatControllerImpl: MFMessageComposeViewControllerDelegate {
    func openPhoneContextMenu(number: String, params: ChatControllerInteraction.LongTapParams) -> Void {
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
        
        params.progress?.set(.single(true))
        
        let _ = (self.context.engine.peers.resolvePeerByPhone(phone: number)
        |> deliverOnMainQueue).start(next: { [weak self] peer in
            guard let self else {
                return
            }
            params.progress?.set(.single(false))
            
            var firstName = ""
            var lastName = ""
            let phoneNumber: String
            if let peer, case let .user(user) = peer, let phone = user.phone {
                phoneNumber = "+\(phone)"
            } else {
                phoneNumber = number
            }
            
            if case let .user(user) = peer {
                firstName = user.firstName ?? ""
                lastName = user.lastName ?? ""
            }
            
            var items: [ContextMenuItem] = []
            items.append(
                .action(ContextMenuActionItem(text: self.presentationData.strings.Chat_Context_Phone_AddToContacts, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/AddUser"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                    guard let self, let c else {
                        return
                    }
                    let basicData = DeviceContactBasicData(firstName: firstName, lastName: lastName, phoneNumbers: [
                        DeviceContactPhoneNumberData(label: "", value: phoneNumber)
                    ])
                    let contactData = DeviceContactExtendedData(basicData: basicData, middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [], note: "")
                    
                    pushContactContextOptionsController(context: self.context, contextController: c, presentationData: self.presentationData, peer: nil, contactData: contactData, parentController: self, push: { [weak self] c in
                        self?.push(c)
                    })
                }))
            )
            items.append(.separator)
            if let peer {
                if peer.id == self.context.account.peerId {
                    
                } else {
                    items.append(
                        .action(ContextMenuActionItem(text: self.presentationData.strings.Chat_Context_Phone_SendMessage, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/MessageBubble"), color: theme.contextMenu.primaryColor) }, action: { [weak self]  _, f in
                            f(.default)
                            guard let self else {
                                return
                            }
                            self.openPeer(peer: peer, navigation: .chat(textInputState: nil, subject: nil, peekData: nil), fromMessage: nil)
                        }))
                    )
                    items.append(
                        .action(ContextMenuActionItem(text: self.presentationData.strings.Chat_Context_Phone_TelegramVoiceCall, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Call"), color: theme.contextMenu.primaryColor) }, action: { [weak self]  _, f in
                            f(.default)
                            
                            guard let self else {
                                return
                            }
                            self.controllerInteraction?.callPeer(peer.id, false)
                        }))
                    )
                    items.append(
                        .action(ContextMenuActionItem(text: self.presentationData.strings.Chat_Context_Phone_TelegramVideoCall, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/VideoCall"), color: theme.contextMenu.primaryColor) }, action: { [weak self]  _, f in
                            f(.default)
                            
                            guard let self else {
                                return
                            }
                            self.controllerInteraction?.callPeer(peer.id, true)
                        }))
                    )
                }
            } else {
                items.append(
                    .action(ContextMenuActionItem(text: self.presentationData.strings.Chat_Context_Phone_InviteToTelegram, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Telegram"), color: theme.contextMenu.primaryColor) }, action: { [weak self]  _, f in
                        f(.default)
                        
                        guard let self else {
                            return
                        }
                        self.inviteToTelegram(numbers: [number])
                    }))
                )
            }
            if number.hasPrefix("+888") {
                
            } else {
                items.append(
                    .action(ContextMenuActionItem(text: self.presentationData.strings.Chat_Context_Phone_CallViaCarrier, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/PhoneCall"), color: theme.contextMenu.primaryColor) }, action: { [weak self]  _, f in
                        f(.default)
                        
                        guard let self else {
                            return
                        }
                        self.openUrl("tel:\(phoneNumber)", concealed: false)
                    }))
                )
            }
            
            items.append(
                .action(ContextMenuActionItem(text: self.presentationData.strings.Chat_Context_Phone_CopyNumber, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { [weak self]  _, f in
                    f(.default)

                    guard let self else {
                        return
                    }
                    
                    UIPasteboard.general.string = number

                    self.present(UndoOverlayController(presentationData: self.presentationData, content: .copy(text: presentationData.strings.Conversation_PhoneCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
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
                    .action(ContextMenuActionItem(text: self.presentationData.strings.Chat_Context_Phone_NotOnTelegram, textLayout: .multiline, textFont: .small, icon: { _ in return nil }, action: emptyAction))
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
    
    private func inviteToTelegram(numbers: [String]) {
        if MFMessageComposeViewController.canSendText() {
            let composer = MFMessageComposeViewController()
            composer.messageComposeDelegate = self
            composer.recipients = Array(Set(numbers))
            let url = self.presentationData.strings.InviteText_URL
            let body = self.presentationData.strings.InviteText_SingleContact(url).string
            composer.body = body
            self.messageComposeController = composer
            if let window = self.view.window {
                window.rootViewController?.present(composer, animated: true)
            }
        }
    }
    
    @objc public func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        self.messageComposeController = nil
        
        controller.dismiss(animated: true, completion: nil)
    }
}

final class ChatMessageLinkContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = false
    let ignoreContentTouches: Bool = true
    let blurBackground: Bool = true
    let adjustContentHorizontally = true
    
    private weak var chatNode: ChatControllerNode?
    private let contentNode: ContextExtractedContentContainingNode
    
    var shouldBeDismissed: Signal<Bool, NoError> {
        return .single(false)
    }
    
    init(chatNode: ChatControllerNode, contentNode: ContextExtractedContentContainingNode) {
        self.chatNode = chatNode
        self.contentNode = contentNode
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        guard let chatNode = self.chatNode else {
            return nil
        }
        
        let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
        transition.updateAlpha(node: self.contentNode.contentNode, alpha: 1.0)
        
        return ContextControllerTakeViewInfo(containingItem: .node(self.contentNode), contentAreaInScreenSpace: chatNode.convert(chatNode.frameForVisibleArea(), to: nil))
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        guard let chatNode = self.chatNode else {
            return nil
        }
        
        let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
        transition.updateAlpha(node: self.contentNode.contentNode, alpha: 0.0, completion: { _ in
            self.contentNode.removeFromSupernode()
        })
        
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: chatNode.convert(chatNode.frameForVisibleArea(), to: nil))
    }
}
