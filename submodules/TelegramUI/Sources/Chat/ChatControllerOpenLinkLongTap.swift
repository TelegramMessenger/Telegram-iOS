import Foundation
import Display
import ChatControllerInteraction
import AccountContext

extension ChatControllerImpl {
    func openLinkLongTap(_ action: ChatControllerInteractionLongTapAction, params: ChatControllerInteraction.LongTapParams?) {
        if self.presentationInterfaceState.interfaceState.selectionState != nil {
            return
        }
        
        self.dismissAllTooltips()
        
        (self.view.window as? WindowHost)?.cancelInteractiveKeyboardGestures()
        self.chatDisplayNode.cancelInteractiveKeyboardGestures()
        self.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
        
        guard let params else {
            return
        }
        switch action {
        case let .url(url):
            self.openLinkContextMenu(url: url, params: params)
        case let .mention(mention):
            self.openMentionContextMenu(username: mention, peerId: nil, params: params)
        case let .peerMention(peerId, mention):
            self.openMentionContextMenu(username: mention, peerId: peerId, params: params)
        case let .command(command):
            let _ = command
            break
//            self.openBotCommandContextMenu(command: command, params: params)
        case let .hashtag(hashtag):
            self.openHashtagContextMenu(hashtag: hashtag, params: params)
        case let .timecode(value, timecode):
            let _ = value
            let _ = timecode
            break
//            self.openTimecodeContextMenu(timecode: timecode, params: params)
        case let .bankCard(number):
            self.openBankCardContextMenu(number: number, params: params)
        case let .phone(number):
            self.openPhoneContextMenu(number: number, params: params)
        }
    }
}

//if let strongSelf = self {
//    let presentationData = strongSelf.presentationData
//    switch action {
//        case let .url(url):
//            var (cleanUrl, _) = parseUrl(url: url, wasConcealed: false)
//            var canAddToReadingList = true
//            var canOpenIn = availableOpenInOptions(context: strongSelf.context, item: .url(url: url)).count > 1
//            let mailtoString = "mailto:"
//            let telString = "tel:"
//            var openText = strongSelf.presentationData.strings.Conversation_LinkDialogOpen
//            var phoneNumber: String?
//            
//            var isPhoneNumber = false
//            var isEmail = false
//            var hasOpenAction = true
//            
//            if cleanUrl.hasPrefix(mailtoString) {
//                canAddToReadingList = false
//                cleanUrl = String(cleanUrl[cleanUrl.index(cleanUrl.startIndex, offsetBy: mailtoString.distance(from: mailtoString.startIndex, to: mailtoString.endIndex))...])
//                isEmail = true
//            } else if cleanUrl.hasPrefix(telString) {
//                canAddToReadingList = false
//                phoneNumber = String(cleanUrl[cleanUrl.index(cleanUrl.startIndex, offsetBy: telString.distance(from: telString.startIndex, to: telString.endIndex))...])
//                cleanUrl = phoneNumber!
//                openText = strongSelf.presentationData.strings.UserInfo_PhoneCall
//                canOpenIn = false
//                isPhoneNumber = true
//                
//                if cleanUrl.hasPrefix("+888") {
//                    hasOpenAction = false
//                }
//            } else if canOpenIn {
//                openText = strongSelf.presentationData.strings.Conversation_FileOpenIn
//            }
//            let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
//            
//            var items: [ActionSheetItem] = []
//            items.append(ActionSheetTextItem(title: cleanUrl))
//            if hasOpenAction {
//                items.append(ActionSheetButtonItem(title: openText, color: .accent, action: { [weak actionSheet] in
//                    actionSheet?.dismissAnimated()
//                    if let strongSelf = self {
//                        if canOpenIn {
//                            strongSelf.openUrlIn(url)
//                        } else {
//                            strongSelf.openUrl(url, concealed: false)
//                        }
//                    }
//                }))
//            }
//            if let phoneNumber = phoneNumber {
//                items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_AddContact, color: .accent, action: { [weak actionSheet] in
//                    actionSheet?.dismissAnimated()
//                    if let strongSelf = self {
//                        strongSelf.controllerInteraction?.addContact(phoneNumber)
//                    }
//                }))
//            }
//            items.append(ActionSheetButtonItem(title: canAddToReadingList ? strongSelf.presentationData.strings.ShareMenu_CopyShareLink : strongSelf.presentationData.strings.Conversation_ContextMenuCopy, color: .accent, action: { [weak actionSheet, weak self] in
//                actionSheet?.dismissAnimated()
//                UIPasteboard.general.string = cleanUrl
//                
//                let content: UndoOverlayContent
//                if isPhoneNumber {
//                    content = .copy(text: presentationData.strings.Conversation_PhoneCopied)
//                } else if isEmail {
//                    content = .copy(text: presentationData.strings.Conversation_EmailCopied)
//                } else if canAddToReadingList {
//                    content = .linkCopied(text: presentationData.strings.Conversation_LinkCopied)
//                } else {
//                    content = .copy(text: presentationData.strings.Conversation_TextCopied)
//                }
//                self?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
//            }))
//            if canAddToReadingList {
//                items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_AddToReadingList, color: .accent, action: { [weak actionSheet] in
//                    actionSheet?.dismissAnimated()
//                    if let link = URL(string: url) {
//                        let _ = try? SSReadingList.default()?.addItem(with: link, title: nil, previewText: nil)
//                    }
//                }))
//            }
//            actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
//                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
//                    actionSheet?.dismissAnimated()
//                })
//            ])])
//            strongSelf.chatDisplayNode.dismissInput()
//            strongSelf.present(actionSheet, in: .window(.root))
//        case let .peerMention(peerId, mention):
//            let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
//            var items: [ActionSheetItem] = []
//            if !mention.isEmpty {
//                items.append(ActionSheetTextItem(title: mention))
//            }
//            items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogOpen, color: .accent, action: { [weak actionSheet] in
//                actionSheet?.dismissAnimated()
//                if let strongSelf = self {
//                    let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
//                    |> deliverOnMainQueue).startStandalone(next: { peer in
//                        if let strongSelf = self, let peer = peer {
//                            strongSelf.openPeer(peer: peer, navigation: .chat(textInputState: nil, subject: nil, peekData: nil), fromMessage: nil)
//                        }
//                    })
//                }
//            }))
//            if !mention.isEmpty {
//                items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet] in
//                    actionSheet?.dismissAnimated()
//                    UIPasteboard.general.string = mention
//                    
//                    let content: UndoOverlayContent = .copy(text: presentationData.strings.Conversation_TextCopied)
//                    self?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
//                }))
//            }
//            actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
//                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
//                    actionSheet?.dismissAnimated()
//                })
//            ])])
//            strongSelf.chatDisplayNode.dismissInput()
//            strongSelf.present(actionSheet, in: .window(.root))
//        case let .mention(mention):
//            let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
//            actionSheet.setItemGroups([ActionSheetItemGroup(items: [
//                ActionSheetTextItem(title: mention),
//                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogOpen, color: .accent, action: { [weak actionSheet] in
//                    actionSheet?.dismissAnimated()
//                    if let strongSelf = self {
//                        strongSelf.openPeerMention(mention, sourceMessageId: message?.id)
//                    }
//                }),
//                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet] in
//                    actionSheet?.dismissAnimated()
//                    UIPasteboard.general.string = mention
//                    
//                    let content: UndoOverlayContent = .copy(text: presentationData.strings.Conversation_UsernameCopied)
//                    self?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
//                })
//            ]), ActionSheetItemGroup(items: [
//                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
//                    actionSheet?.dismissAnimated()
//                })
//            ])])
//            strongSelf.chatDisplayNode.dismissInput()
//            strongSelf.present(actionSheet, in: .window(.root))
//        case let .command(command):
//            let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
//            var items: [ActionSheetItem] = []
//            items.append(ActionSheetTextItem(title: command))
//            if canSendMessagesToChat(strongSelf.presentationInterfaceState) {
//                items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.ShareMenu_Send, color: .accent, action: { [weak actionSheet] in
//                    actionSheet?.dismissAnimated()
//                    if let strongSelf = self {
//                        strongSelf.sendMessages([.message(text: command, attributes: [], inlineStickers: [:], mediaReference: nil, threadId: strongSelf.chatLocation.threadId, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])])
//                    }
//                }))
//            }
//            items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet] in
//                actionSheet?.dismissAnimated()
//                UIPasteboard.general.string = command
//                
//                let content: UndoOverlayContent = .copy(text: presentationData.strings.Conversation_TextCopied)
//                self?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
//            }))
//            actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
//                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
//                    actionSheet?.dismissAnimated()
//                })
//            ])])
//            strongSelf.chatDisplayNode.dismissInput()
//            strongSelf.present(actionSheet, in: .window(.root))
//        case let .hashtag(hashtag):
//            let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
//            actionSheet.setItemGroups([ActionSheetItemGroup(items: [
//                ActionSheetTextItem(title: hashtag),
//                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogOpen, color: .accent, action: { [weak actionSheet] in
//                    actionSheet?.dismissAnimated()
//                    if let strongSelf = self {
//                        strongSelf.openHashtag(hashtag, peerName: nil)
//                    }
//                }),
//                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet] in
//                    actionSheet?.dismissAnimated()
//                    UIPasteboard.general.string = hashtag
//                    
//                    let content: UndoOverlayContent = .copy(text: presentationData.strings.Conversation_HashtagCopied)
//                    self?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
//                })
//            ]), ActionSheetItemGroup(items: [
//                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
//                    actionSheet?.dismissAnimated()
//                })
//            ])])
//            strongSelf.chatDisplayNode.dismissInput()
//            strongSelf.present(actionSheet, in: .window(.root))
//        case let .timecode(timecode, text):
//            guard let message = message else {
//                return
//            }
//        
//            let context = strongSelf.context
//            let chatPresentationInterfaceState = strongSelf.presentationInterfaceState
//            let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
//            
//            var isCopyLink = false
//            var isForward = false
//            if message.id.namespace == Namespaces.Message.Cloud, let _ = message.peers[message.id.peerId] as? TelegramChannel, !(message.media.first is TelegramMediaAction) {
//                isCopyLink = true
//            } else if let forwardInfo = message.forwardInfo, let _ = forwardInfo.author as? TelegramChannel {
//                isCopyLink = true
//                isForward = true
//            }
//            
//            actionSheet.setItemGroups([ActionSheetItemGroup(items: [
//                ActionSheetTextItem(title: text),
//                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogOpen, color: .accent, action: { [weak actionSheet] in
//                    actionSheet?.dismissAnimated()
//                    if let strongSelf = self {
//                        strongSelf.controllerInteraction?.seekToTimecode(message, timecode, true)
//                    }
//                }),
//                ActionSheetButtonItem(title: isCopyLink ? strongSelf.presentationData.strings.Conversation_ContextMenuCopyLink : strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet] in
//                    actionSheet?.dismissAnimated()
//                    
//                    var messageId = message.id
//                    var channel = message.peers[message.id.peerId]
//                    if isForward, let forwardMessageId = message.forwardInfo?.sourceMessageId, let forwardAuthor = message.forwardInfo?.author as? TelegramChannel {
//                        messageId = forwardMessageId
//                        channel = forwardAuthor
//                    }
//                    
//                    if isCopyLink, let channel = channel as? TelegramChannel {
//                        var threadId: Int64?
//                       
//                        if case let .replyThread(replyThreadMessage) = chatPresentationInterfaceState.chatLocation {
//                            threadId = replyThreadMessage.threadId
//                        }
//                        let _ = (context.engine.messages.exportMessageLink(peerId: messageId.peerId, messageId: messageId, isThread: threadId != nil)
//                        |> map { result -> String? in
//                            return result
//                        }
//                        |> deliverOnMainQueue).startStandalone(next: { link in
//                            if let link = link {
//                                UIPasteboard.general.string = link + "?t=\(Int32(timecode))"
//                                
//                                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
//                                
//                                var warnAboutPrivate = false
//                                if case .peer = chatPresentationInterfaceState.chatLocation {
//                                    if channel.addressName == nil {
//                                        warnAboutPrivate = true
//                                    }
//                                }
//                                Queue.mainQueue().after(0.2, {
//                                    let content: UndoOverlayContent
//                                    if warnAboutPrivate {
//                                        content = .linkCopied(text: presentationData.strings.Conversation_PrivateMessageLinkCopiedLong)
//                                    } else {
//                                        content = .linkCopied(text: presentationData.strings.Conversation_LinkCopied)
//                                    }
//                                    self?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
//                                })
//                            } else {
//                                UIPasteboard.general.string = text
//                                
//                                let content: UndoOverlayContent = .copy(text: presentationData.strings.Conversation_TextCopied)
//                                self?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
//                            }
//                        })
//                    } else {
//                        UIPasteboard.general.string = text
//                        
//                        let content: UndoOverlayContent = .copy(text: presentationData.strings.Conversation_TextCopied)
//                        self?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
//                    }
//                })
//                ]), ActionSheetItemGroup(items: [
//                    ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
//                        actionSheet?.dismissAnimated()
//                    })
//                ])])
//            strongSelf.chatDisplayNode.dismissInput()
//            strongSelf.present(actionSheet, in: .window(.root))
//        case let .bankCard(number):
//            guard let message = message else {
//                return
//            }
//            
//            var signal = strongSelf.context.engine.payments.getBankCardInfo(cardNumber: number)
//            let disposable: MetaDisposable
//            if let current = strongSelf.bankCardDisposable {
//                disposable = current
//            } else {
//                disposable = MetaDisposable()
//                strongSelf.bankCardDisposable = disposable
//            }
//            
//            var cancelImpl: (() -> Void)?
//            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
//            let progressSignal = Signal<Never, NoError> { subscriber in
//                let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
//                    cancelImpl?()
//                }))
//                strongSelf.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
//                return ActionDisposable { [weak controller] in
//                    Queue.mainQueue().async() {
//                        controller?.dismiss()
//                    }
//                }
//            }
//            |> runOn(Queue.mainQueue())
//            |> delay(0.15, queue: Queue.mainQueue())
//            let progressDisposable = progressSignal.startStrict()
//            
//            signal = signal
//            |> afterDisposed {
//                Queue.mainQueue().async {
//                    progressDisposable.dispose()
//                }
//            }
//            cancelImpl = {
//                disposable.set(nil)
//            }
//            disposable.set((signal
//            |> deliverOnMainQueue).startStrict(next: { [weak self] info in
//                if let strongSelf = self, let info = info {
//                    let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
//                    var items: [ActionSheetItem] = []
//                    items.append(ActionSheetTextItem(title: info.title))
//                    for url in info.urls {
//                        items.append(ActionSheetButtonItem(title: url.title, color: .accent, action: { [weak actionSheet] in
//                            actionSheet?.dismissAnimated()
//                            if let strongSelf = self {
//                                strongSelf.controllerInteraction?.openUrl(ChatControllerInteraction.OpenUrl(url: url.url, concealed: false, external: false, message: message))
//                            }
//                        }))
//                    }
//                    items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_LinkDialogCopy, color: .accent, action: { [weak actionSheet] in
//                        actionSheet?.dismissAnimated()
//                        UIPasteboard.general.string = number
//                        
//                        let content: UndoOverlayContent = .copy(text: presentationData.strings.Conversation_CardNumberCopied)
//                        self?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
//                    }))
//                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
//                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
//                            actionSheet?.dismissAnimated()
//                        })
//                    ])])
//                    strongSelf.present(actionSheet, in: .window(.root))
//                }
//            }))
//            
//            strongSelf.chatDisplayNode.dismissInput()
//    }
