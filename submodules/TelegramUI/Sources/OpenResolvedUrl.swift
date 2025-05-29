import Foundation
import UIKit
import AVFoundation
import AsyncDisplayKit
import TelegramCore
import Postbox
import Display
import SwiftSignalKit
import TelegramUIPreferences
import TelegramPresentationData
import AccountContext
import OverlayStatusController
import AlertUI
import PresentationDataUtils
import PassportUI
import InstantPageUI
import StickerPackPreviewUI
import JoinLinkPreviewUI
import LanguageLinkPreviewUI
import SettingsUI
import UrlHandling
import ShareController
import ChatInterfaceState
import TelegramCallsUI
import UndoUI
import ImportStickerPackUI
import PeerInfoUI
import Markdown
import WebUI
import BotPaymentsUI
import PremiumUI
import AuthorizationUI
import ChatFolderLinkPreviewScreen
import StoryContainerScreen
import WallpaperGalleryScreen
import TelegramStringFormatting
import TextFormat
import BrowserUI
import MediaEditorScreen

private func defaultNavigationForPeerId(_ peerId: PeerId?, navigation: ChatControllerInteractionNavigateToPeer) -> ChatControllerInteractionNavigateToPeer {
    if case .default = navigation {
        if let peerId = peerId {
            if peerId.namespace == Namespaces.Peer.CloudUser {
                return .chat(textInputState: nil, subject: nil, peekData: nil)
            } else {
                return .chat(textInputState: nil, subject: nil, peekData: nil)
            }
        } else {
            return .info(nil)
        }
    } else {
        return navigation
    }
}

func openResolvedUrlImpl(
    _ resolvedUrl: ResolvedUrl,
    context: AccountContext,
    urlContext: OpenURLContext,
    navigationController: NavigationController?,
    forceExternal: Bool,
    forceUpdate: Bool,
    openPeer: @escaping (EnginePeer, ChatControllerInteractionNavigateToPeer) -> Void,
    sendFile: ((FileMediaReference) -> Void)?,
    sendSticker: ((FileMediaReference, UIView, CGRect) -> Bool)?,
    sendEmoji: ((String, ChatTextInputTextCustomEmojiAttribute) -> Void)?,
    requestMessageActionUrlAuth: ((MessageActionUrlSubject) -> Void)? = nil,
    joinVoiceChat: ((PeerId, String?, CachedChannelData.ActiveCall) -> Void)?,
    present: @escaping (ViewController, Any?) -> Void,
    dismissInput: @escaping () -> Void,
    contentContext: Any?,
    progress: Promise<Bool>?,
    completion: (() -> Void)?
) {
    let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    if case let .chat(_, _, maybeUpdatedPresentationData) = urlContext {
        updatedPresentationData = maybeUpdatedPresentationData
    } else {
        updatedPresentationData = nil
    }
    let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
    switch resolvedUrl {
        case let .externalUrl(url):
            context.sharedContext.openExternalUrl(context: context, urlContext: urlContext, url: url, forceExternal: forceExternal, presentationData: context.sharedContext.currentPresentationData.with { $0 }, navigationController: navigationController, dismissInput: dismissInput)
        case let .urlAuth(url):
            requestMessageActionUrlAuth?(.url(url))
            dismissInput()
            break
        case let .peer(peer, navigation):
            if let peer = peer {
                openPeer(EnginePeer(peer), defaultNavigationForPeerId(peer.id, navigation: navigation))
            } else {
                present(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Resolve_ErrorNotFound, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
            }
        case .inaccessiblePeer:
            present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: presentationData.strings.Conversation_ErrorInaccessibleMessage, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
        case let .botStart(peer, payload):
            openPeer(EnginePeer(peer), .withBotStartPayload(ChatControllerInitialBotStart(payload: payload, behavior: .interactive)))
        case let .groupBotStart(botPeerId, payload, adminRights):
            let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyGroupsAndChannels, .onlyManageable, .excludeDisabled, .excludeRecent, .doNotSearchMessages], hasContactSelector: false, title: presentationData.strings.Bot_AddToChat_Title, selectForumThreads: true))
            controller.peerSelected = { [weak controller] peer, _ in
                let peerId = peer.id
                
                let addMemberImpl = {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    let theme = AlertControllerTheme(presentationData: presentationData)
                    let attributedTitle = NSAttributedString(string: presentationData.strings.Bot_AddToChat_Add_MemberAlertTitle, font: Font.semibold(presentationData.listsFontSize.baseDisplaySize), textColor: theme.primaryColor, paragraphAlignment: .center)
                  
                    var isGroup: Bool = false
                    var peerTitle: String = ""
                    if case let .legacyGroup(peer) = peer {
                        isGroup = true
                        peerTitle = peer.title
                    } else if case let .channel(peer) = peer {
                        if case .group = peer.info {
                            isGroup = true
                        }
                        peerTitle = peer.title
                    }
                    
                    let text = isGroup ? presentationData.strings.Bot_AddToChat_Add_MemberAlertTextGroup(peerTitle).string : presentationData.strings.Bot_AddToChat_Add_MemberAlertTextChannel(peerTitle).string
                    
                    let body = MarkdownAttributeSet(font: Font.regular(presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0), textColor: theme.primaryColor)
                    let bold = MarkdownAttributeSet(font: Font.semibold(presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0), textColor: theme.primaryColor)
                    let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .center)
                    
                    let controller = richTextAlertController(context: context, title: attributedTitle, text: attributedText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Bot_AddToChat_Add_MemberAlertAdd, action: {
                        if payload.isEmpty {
                            if peerId.namespace == Namespaces.Peer.CloudGroup {
                                let _ = (context.engine.peers.addGroupMember(peerId: peerId, memberId: botPeerId)
                                |> deliverOnMainQueue).startStandalone(completed: {
                                    controller?.dismiss()
                                })
                            } else {
                                let _ = (context.engine.peers.addChannelMember(peerId: peerId, memberId: botPeerId)
                                |> deliverOnMainQueue).startStandalone(completed: {
                                    controller?.dismiss()
                                })
                            }
                        } else {
                            let _ = (context.engine.messages.requestStartBotInGroup(botPeerId: botPeerId, groupPeerId: peerId, payload: payload)
                            |> deliverOnMainQueue).startStandalone(next: { result in
                                let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                                |> deliverOnMainQueue).startStandalone(next: { peer in
                                    guard let peer = peer else {
                                        return
                                    }
                                    if let navigationController = navigationController {
                                        context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer)))
                                    }
                                    switch result {
                                    case let .channelParticipant(participant):
                                        context.peerChannelMemberCategoriesContextsManager.externallyAdded(peerId: peerId, participant: participant)
                                    case .none:
                                        break
                                    }
                                    controller?.dismiss()
                                })
                            }, error: { _ in
                                
                            })
                        }
                    }), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                    })], actionLayout: .vertical)
                    present(controller, nil)
                }
                
                if case let .channel(peer) = peer {
                    if peer.flags.contains(.isCreator) || peer.adminRights?.rights.contains(.canAddAdmins) == true {
                        let controller = channelAdminController(context: context, peerId: peerId, adminId: botPeerId, initialParticipant: nil, invite: true, initialAdminRights: adminRights?.chatAdminRights, updated: { _ in
                            controller?.dismiss()
                        }, upgradedToSupergroup: { _, _ in }, transferedOwnership: { _ in })
                        navigationController?.pushViewController(controller)
                    } else {
                        addMemberImpl()
                    }
                } else if case let .legacyGroup(peer) = peer {
                    if case .member = peer.role {
                        addMemberImpl()
                    } else {
                        let controller = channelAdminController(context: context, peerId: peerId, adminId: botPeerId, initialParticipant: nil, invite: true, initialAdminRights: adminRights?.chatAdminRights, updated: { _ in
                            controller?.dismiss()
                        }, upgradedToSupergroup: { _, _ in }, transferedOwnership: { _ in })
                        navigationController?.pushViewController(controller)
                    }
                }
            }
            dismissInput()
            navigationController?.pushViewController(controller)
        case let .gameStart(botPeerId, game):
            let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyManageable, .excludeDisabled, .excludeRecent, .doNotSearchMessages], hasContactSelector: false, title: presentationData.strings.Bot_AddToChat_Title, selectForumThreads: true))
            controller.peerSelected = { [weak controller] peer, _ in
                let _ = peer.id
                let _ = botPeerId
                let _ = game
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let text: String
                if case .user = peer {
                    text = presentationData.strings.Target_ShareGameConfirmationPrivate(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string
                } else {
                    text = presentationData.strings.Target_ShareGameConfirmationGroup(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string
                }
                
                let alertController = textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.RequestPeer_SelectionConfirmationSend, action: {
                    controller?.dismiss()
                }), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                })])
                present(alertController, nil)
            }
            dismissInput()
            navigationController?.pushViewController(controller)
        case let .channelMessage(peer, messageId, timecode):
            openPeer(EnginePeer(peer), .chat(textInputState: nil, subject: .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: timecode, setupReply: false), peekData: nil))
        case let .replyThreadMessage(replyThreadMessage, messageId):
            if let navigationController = navigationController, let effectiveMessageId = replyThreadMessage.effectiveMessageId {
                let _ = ChatControllerImpl.openMessageReplies(context: context, navigationController: navigationController, present: { c, a in
                    present(c, a)
                }, messageId: effectiveMessageId, isChannelPost: replyThreadMessage.isChannelPost, atMessage: messageId, displayModalProgress: true).startStandalone()
            }
        case let .replyThread(messageId):
            if let navigationController = navigationController {
                let _ = context.sharedContext.navigateToForumThread(context: context, peerId: messageId.peerId, threadId: Int64(messageId.id), messageId: nil, navigationController: navigationController, activateInput: nil, scrollToEndIfExists: false, keepStack: .always, animated: true).startStandalone()
            }
        case let .stickerPack(name, _):
            dismissInput()

            let controller = StickerPackScreen(
                context: context,
                updatedPresentationData: updatedPresentationData,
                mainStickerPack: .name(name),
                stickerPacks: [.name(name)],
                ignoreCache: forceUpdate,
                parentNavigationController: navigationController,
                sendSticker: sendSticker,
                sendEmoji: sendEmoji,
                actionPerformed: { actions in
                if actions.count > 1, let first = actions.first {
                    if case .add = first.2 {
                        present(UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: presentationData.strings.EmojiPackActionInfo_AddedTitle, text: presentationData.strings.EmojiPackActionInfo_MultipleAddedText(Int32(actions.count)), undo: false, info: first.0, topItem: first.1.first, context: context), elevatedLayout: true, animateInAsReplacement: false, action: { _ in
                            return true
                        }), nil)
                    }
                } else if let (info, items, action) = actions.first {
                    let isEmoji = info.id.namespace == Namespaces.ItemCollection.CloudEmojiPacks
                    
                    switch action {
                    case .add:
                        present(UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: isEmoji ? presentationData.strings.EmojiPackActionInfo_AddedTitle : presentationData.strings.StickerPackActionInfo_AddedTitle, text: isEmoji ? presentationData.strings.EmojiPackActionInfo_AddedText(info.title).string : presentationData.strings.StickerPackActionInfo_AddedText(info.title).string, undo: false, info: info, topItem: items.first, context: context), elevatedLayout: false, animateInAsReplacement: false, action: { _ in
                            return true
                        }), nil)
                    case let .remove(positionInList):
                        present(UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: isEmoji ? presentationData.strings.EmojiPackActionInfo_RemovedTitle : presentationData.strings.StickerPackActionInfo_RemovedTitle, text: isEmoji ? presentationData.strings.EmojiPackActionInfo_RemovedText(info.title).string : presentationData.strings.StickerPackActionInfo_RemovedText(info.title).string, undo: true, info: info, topItem: items.first, context: context), elevatedLayout: false, animateInAsReplacement: false, action: { action in
                            if case .undo = action {
                                let _ = context.engine.stickers.addStickerPackInteractively(info: info, items: items, positionInList: positionInList).startStandalone()
                            }
                            return true
                        }), nil)
                    }
                }
            })
                present(controller, nil)
        case let .instantView(webPage, anchor):
            let sourceLocation = InstantPageSourceLocation(userLocation: .other, peerType: .channel)
            let browserController = context.sharedContext.makeInstantPageController(context: context, webPage: webPage, anchor: anchor, sourceLocation: sourceLocation)
            navigationController?.pushViewController(browserController)
        case let .join(link):
            dismissInput()
        
            if let progress {
                let progressSignal = Signal<Never, NoError> { subscriber in
                    progress.set(.single(true))
                    return ActionDisposable {
                        Queue.mainQueue().async() {
                            progress.set(.single(false))
                        }
                    }
                }
                |> runOn(Queue.mainQueue())
                |> delay(0.1, queue: Queue.mainQueue())
                let progressDisposable = progressSignal.startStrict()
                
                var signal = context.engine.peers.joinLinkInformation(link)
                signal = signal
                |> afterDisposed {
                    Queue.mainQueue().async {
                        progressDisposable.dispose()
                    }
                }
            
                let _ = (signal
                |> deliverOnMainQueue).startStandalone(next: { [weak navigationController] resolvedState in
                    switch resolvedState {
                    case let .alreadyJoined(peer):
                        openPeer(peer, .chat(textInputState: nil, subject: nil, peekData: nil))
                    case let .peek(peer, deadline):
                        openPeer(peer, .chat(textInputState: nil, subject: nil, peekData: ChatPeekTimeout(deadline: deadline, linkData: link)))
                    case let .invite(invite):
                        if let subscriptionPricing = invite.subscriptionPricing, let subscriptionFormId = invite.subscriptionFormId, let starsContext = context.starsContext {
                            let inputData = Promise<BotCheckoutController.InputData?>()
                            var photo: [TelegramMediaImageRepresentation] = []
                            if let photoRepresentation = invite.photoRepresentation {
                                photo.append(photoRepresentation)
                            }
                            let channel = TelegramChannel(id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(0)), accessHash: .genericPublic(0), title: invite.title, username: nil, photo: photo, creationDate: 0, version: 0, participationStatus: .left, info: .broadcast(TelegramChannelBroadcastInfo(flags: [])), flags: [], restrictionInfo: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil, usernames: [], storiesHidden: nil, nameColor: invite.nameColor, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, emojiStatus: nil, approximateBoostLevel: nil, subscriptionUntilDate: nil, verificationIconFileId: nil, sendPaidMessageStars: nil, linkedMonoforumId: nil)
                            let invoice = TelegramMediaInvoice(title: "", description: "", photo: nil, receiptMessageId: nil, currency: "XTR", totalAmount: subscriptionPricing.amount.value, startParam: "", extendedMedia: nil, subscriptionPeriod: nil, flags: [], version: 0)
                            
                            inputData.set(.single(BotCheckoutController.InputData(
                                form: BotPaymentForm(
                                    id: subscriptionFormId,
                                    canSaveCredentials: false,
                                    passwordMissing: false,
                                    invoice: BotPaymentInvoice(isTest: false, requestedFields: [], currency: "XTR", prices: [BotPaymentPrice(label: "", amount: subscriptionPricing.amount.value)], tip: nil, termsInfo: nil, subscriptionPeriod: subscriptionPricing.period),
                                    paymentBotId: channel.id,
                                    providerId: nil,
                                    url: nil,
                                    nativeProvider: nil,
                                    savedInfo: nil,
                                    savedCredentials: [],
                                    additionalPaymentMethods: []
                                ),
                                validatedFormInfo: nil,
                                botPeer: EnginePeer(channel)
                            )))
                            
                            let starsInputData = combineLatest(
                                inputData.get(),
                                starsContext.state
                            )
                            |> map { data, state -> (StarsContext.State, BotPaymentForm, EnginePeer?, EnginePeer?)? in
                                if let data, let state {
                                    return (state, data.form, data.botPeer, nil)
                                } else {
                                    return nil
                                }
                            }
                            let _ = (starsInputData |> filter { $0 != nil } |> take(1) |> deliverOnMainQueue).start(next: { _ in
                                let controller = context.sharedContext.makeStarsSubscriptionTransferScreen(context: context, starsContext: starsContext, invoice: invoice, link: link, inputData: starsInputData, navigateToPeer: { peer in
                                    openPeer(peer, .chat(textInputState: nil, subject: nil, peekData: nil))
                                })
                                navigationController?.pushViewController(controller)
                            })
                        } else {
                            let joinLinkPreviewController = JoinLinkPreviewController(context: context, link: link, navigateToPeer: { peer, peekData in
                                openPeer(peer, .chat(textInputState: nil, subject: nil, peekData: peekData))
                            }, parentNavigationController: navigationController, resolvedState: resolvedState)
                            if joinLinkPreviewController.navigationPresentation == .flatModal {
                                navigationController?.pushViewController(joinLinkPreviewController)
                            } else {
                                present(joinLinkPreviewController, nil)
                            }
                        }
                    default:
                        let joinLinkPreviewController = JoinLinkPreviewController(context: context, link: link, navigateToPeer: { peer, peekData in
                            openPeer(peer, .chat(textInputState: nil, subject: nil, peekData: peekData))
                        }, parentNavigationController: navigationController, resolvedState: resolvedState)
                        if joinLinkPreviewController.navigationPresentation == .flatModal {
                            navigationController?.pushViewController(joinLinkPreviewController)
                        } else {
                            present(joinLinkPreviewController, nil)
                        }
                    }
                })
            } else {
                let joinLinkPreviewController = JoinLinkPreviewController(context: context, link: link, navigateToPeer: { peer, peekData in
                    openPeer(peer, .chat(textInputState: nil, subject: nil, peekData: peekData))
                }, parentNavigationController: navigationController, resolvedState: nil)
                if joinLinkPreviewController.navigationPresentation == .flatModal {
                    navigationController?.pushViewController(joinLinkPreviewController)
                } else {
                    present(joinLinkPreviewController, nil)
                }
            }
        case let .joinCall(link):
            dismissInput()
        
            let progressSignal = Signal<Never, NoError> { subscriber in
                progress?.set(.single(true))
                return ActionDisposable {
                    Queue.mainQueue().async() {
                        progress?.set(.single(false))
                    }
                }
            }
            |> runOn(Queue.mainQueue())
            |> delay(0.1, queue: Queue.mainQueue())
            let progressDisposable = progressSignal.startStrict()
            
            var signal = context.engine.peers.joinCallLinkInformation(link)
            signal = signal
            |> afterDisposed {
                Queue.mainQueue().async {
                    progressDisposable.dispose()
                }
            }
        
            let _ = (signal
            |> deliverOnMainQueue).startStandalone(next: { [weak navigationController] resolvedCallLink in
                if let currentGroupCallController = context.sharedContext.currentGroupCallController as? VoiceChatController, case let .group(groupCall) = currentGroupCallController.call, let currentCallId = groupCall.callId, currentCallId == resolvedCallLink.id {
                    context.sharedContext.navigateToCurrentCall()
                    return
                }
                
                navigationController?.pushViewController(context.sharedContext.makeJoinSubjectScreen(context: context, mode: JoinSubjectScreenMode.groupCall(JoinSubjectScreenMode.GroupCall(
                    id: resolvedCallLink.id,
                    accessHash: resolvedCallLink.accessHash,
                    slug: link,
                    inviter: resolvedCallLink.inviter,
                    members: resolvedCallLink.members,
                    totalMemberCount: resolvedCallLink.totalMemberCount,
                    info: resolvedCallLink
                ))))
            }, error: { _ in
                var elevatedLayout = true
                if case .chat = urlContext {
                    elevatedLayout = false
                }
                present(UndoOverlayController(presentationData: presentationData, content: .linkRevoked(text: presentationData.strings.Chat_ToastCallLinkExpired_Text), elevatedLayout: elevatedLayout, animateInAsReplacement: false, action: { _ in
                    return true
                }), nil)
            })
        case let .localization(identifier):
            dismissInput()
            present(LanguageLinkPreviewController(context: context, identifier: identifier), nil)
        case let .proxy(host, port, username, password, secret):
            let server: ProxyServerSettings
            if let secret = secret {
                server = ProxyServerSettings(host: host, port: abs(port), connection: .mtp(secret: secret))
            } else {
                server = ProxyServerSettings(host: host, port: abs(port), connection: .socks5(username: username, password: password))
            }

            dismissInput()
            present(ProxyServerActionSheetController(context: context, server: server), nil)
        case let .confirmationCode(code):
            if let topController = navigationController?.topViewController as? AuthorizationSequenceCodeEntryController {
                topController.applyConfirmationCode(code)
            } else if let topController = navigationController?.topViewController as? ChangePhoneNumberCodeController {
                topController.applyCode(code)
            } else {
                var found = false
                navigationController?.currentWindow?.forEachController({ controller in
                    if let controller = controller as? SecureIdPlaintextFormController {
                        controller.applyPhoneCode(code)
                        found = true
                    }
                })
                if !found {
                    present(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.AuthCode_Alert(formattedConfirmationCode(code)).string, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                }
            }
        case let .cancelAccountReset(phone, hash):
            let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
            present(controller, nil)
            let _ = (context.engine.auth.requestCancelAccountResetData(hash: hash)
            |> deliverOnMainQueue).startStandalone(next: { [weak controller] data in
                controller?.dismiss()
                present(confirmPhoneNumberCodeController(context: context, phoneNumber: phone, codeData: data), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }, error: { [weak controller] error in
                controller?.dismiss()
                
                let text: String
                switch error {
                    case .limitExceeded:
                        text = presentationData.strings.Login_CodeFloodError
                    case .generic:
                        text = presentationData.strings.Login_UnknownError
                }
                present(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
            })
            dismissInput()
        case let .share(url, text, to):
            let continueWithPeer: (PeerId, Int64?) -> Void = { peerId, threadId in
                let textInputState: ChatTextInputState?
                if let text = text, !text.isEmpty {
                    if let url = url, !url.isEmpty {
                        let urlString = NSMutableAttributedString(string: "\(url)\n")
                        let textString = NSAttributedString(string: "\(text)")
                        let selectionRange: Range<Int> = urlString.length ..< (urlString.length + textString.length)
                        urlString.append(textString)
                        textInputState = ChatTextInputState(inputText: urlString, selectionRange: selectionRange)
                    } else {
                        textInputState = ChatTextInputState(inputText: NSAttributedString(string: "\(text)"))
                    }
                } else if let url = url, !url.isEmpty {
                    textInputState = ChatTextInputState(inputText: NSAttributedString(string: "\(url)"))
                } else {
                    textInputState = nil
                }
                
                let updateControllers = { [weak navigationController] in
                    guard let navigationController else {
                        return
                    }
                    let chatController: Signal<ChatController, NoError>
                    if let threadId {
                        chatController = chatControllerForForumThreadImpl(context: context, peerId: peerId, threadId: threadId)
                    } else {
                        chatController = .single(ChatControllerImpl(context: context, chatLocation: .peer(id: peerId)))
                    }
                    
                    let _ = (chatController
                    |> deliverOnMainQueue).start(next: { [weak navigationController] chatController in
                        guard let navigationController else {
                            return
                        }  
                        var controllers = navigationController.viewControllers.filter { controller in
                            if controller is PeerSelectionController {
                                return false
                            }
                            return true
                        }
                        controllers.append(chatController)
                        navigationController.setViewControllers(controllers, animated: true)
                    })
                }
                
                if let textInputState = textInputState {
                    let _ = (ChatInterfaceState.update(engine: context.engine, peerId: peerId, threadId: threadId, { currentState in
                        return currentState.withUpdatedComposeInputState(textInputState)
                    })
                    |> deliverOnMainQueue).startStandalone(completed: {
                        updateControllers()
                    })
                } else {
                    updateControllers()
                }
            }
            
            if let to = to {
                if to.hasPrefix("@") {
                    let _ = (context.engine.peers.resolvePeerByName(name: String(to[to.index(to.startIndex, offsetBy: 1)...]), referrer: nil)
                    |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
                        guard case let .result(result) = result else {
                            return .complete()
                        }
                        return .single(result)
                    }
                    |> deliverOnMainQueue).startStandalone(next: { peer in
                        if let peer = peer {
                            context.sharedContext.applicationBindings.dismissNativeController()
                            continueWithPeer(peer.id, nil)
                        }
                    })
                } else {
                    let _ = (context.engine.peers.resolvePeerByPhone(phone: to)
                    |> deliverOnMainQueue).startStandalone(next: { peer in
                        if let peer = peer {
                            context.sharedContext.applicationBindings.dismissNativeController()
                            continueWithPeer(peer.id, nil)
                        }
                    })
                    /*let query = to.trimmingCharacters(in: CharacterSet(charactersIn: "0123456789").inverted)
                    let _ = (context.account.postbox.searchContacts(query: query)
                    |> deliverOnMainQueue).startStandalone(next: { (peers, _) in
                        for case let peer as TelegramUser in peers {
                            if peer.phone == query {
                                context.sharedContext.applicationBindings.dismissNativeController()
                                continueWithPeer(peer.id)
                                break
                            }
                        }
                    })*/
                }
            } else {
                if let url = url, !url.isEmpty {
                    let shareController = ShareController(context: context, subject: .url(url), presetText: text, externalShare: false, immediateExternalShare: false)
                    shareController.actionCompleted = {
                        present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
                    }
                    present(shareController, nil)
                    context.sharedContext.applicationBindings.dismissNativeController()
                } else {
                    let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled], selectForumThreads: true))
                    controller.peerSelected = { peer, threadId in
                        continueWithPeer(peer.id, threadId)
                    }
                    context.sharedContext.applicationBindings.dismissNativeController()
                    navigationController?.pushViewController(controller)
                }
            }
        case let .wallpaper(parameter):
            var controller: ViewController?
            
            let signal: Signal<TelegramWallpaper, GetWallpaperError>
            var options: WallpaperPresentationOptions?
            var colors: [UInt32] = []
            var intensity: Int32?
            var rotation: Int32?
            switch parameter {
                case let .slug(slug, wallpaperOptions, colorsValue, intensityValue, rotationValue):
                    signal = getWallpaper(network: context.account.network, slug: slug)
                    options = wallpaperOptions
                    colors = colorsValue
                    intensity = intensityValue
                    rotation = rotationValue
                    controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                    present(controller!, nil)
                case let .color(color):
                    signal = .single(.color(color.argb))
                case let .gradient(colors, rotation):
                    signal = .single(.gradient(TelegramWallpaper.Gradient(id: nil, colors: colors, settings: WallpaperSettings(rotation: rotation))))
            }
            
            let _ = (signal
            |> deliverOnMainQueue).startStandalone(next: { [weak controller] wallpaper in
                controller?.dismiss()
                let galleryController = WallpaperGalleryController(context: context, source: .wallpaper(wallpaper, options, colors, intensity, rotation, nil))
                navigationController?.pushViewController(galleryController)
            }, error: { [weak controller] error in
                controller?.dismiss()
            })
            dismissInput()
        case let .theme(slug):
            let signal = getTheme(account: context.account, slug: slug)
            |> mapToSignal { themeInfo -> Signal<(Data?, TelegramThemeSettings?, TelegramTheme), GetThemeError> in
                return Signal<(Data?, TelegramThemeSettings?, TelegramTheme), GetThemeError> { subscriber in
                    let disposables = DisposableSet()
                    if let settings = themeInfo.settings?.first {
                        subscriber.putNext((nil, settings, themeInfo))
                        subscriber.putCompletion()
                    } else if let resource = themeInfo.file?.resource {
                        disposables.add(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .other, userContentType: .other, reference: .standalone(resource: resource)).start())
                        
                        let maybeFetched = context.sharedContext.accountManager.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false), attemptSynchronously: false)
                        |> mapToSignal { maybeData -> Signal<Data?, NoError> in
                            if maybeData.complete {
                                let loadedData = try? Data(contentsOf: URL(fileURLWithPath: maybeData.path), options: [])
                                return .single(loadedData)
                            } else {
                                return context.account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: false), attemptSynchronously: false)
                                |> map { next -> Data? in
                                    if next.size > 0, let data = try? Data(contentsOf: URL(fileURLWithPath: next.path), options: []) {
                                        context.sharedContext.accountManager.mediaBox.storeResourceData(resource.id, data: data)
                                        return data
                                    } else {
                                        return nil
                                    }
                                }
                            }
                        }
                   
                        disposables.add(maybeFetched.start(next: { data in
                            if let data = data {
                                subscriber.putNext((data, nil, themeInfo))
                                subscriber.putCompletion()
                            }
                        }))
                    } else {
                        subscriber.putError(.unsupported)
                    }
                    
                    return disposables
                }
            }
            
            var cancelImpl: (() -> Void)?
            let progressSignal = Signal<Never, NoError> { subscriber in
                let controller = OverlayStatusController(theme: presentationData.theme,  type: .loading(cancelled: {
                    cancelImpl?()
                }))
                present(controller, nil)
                return ActionDisposable { [weak controller] in
                    Queue.mainQueue().async() {
                        controller?.dismiss()
                    }
                }
            }
            |> runOn(Queue.mainQueue())
            |> delay(0.35, queue: Queue.mainQueue())
            
            let disposable = MetaDisposable()
            let progressDisposable = progressSignal.start()
            cancelImpl = {
                disposable.set(nil)
            }
            disposable.set((signal
            |> afterDisposed {
                Queue.mainQueue().async {
                    progressDisposable.dispose()
                }
            }
            |> deliverOnMainQueue).start(next: { dataAndTheme in
                if let data = dataAndTheme.0 {
                    if let theme = makePresentationTheme(data: data) {
                        let previewController = ThemePreviewController(context: context, previewTheme: theme, source: .theme(dataAndTheme.2))
                        navigationController?.pushViewController(previewController)
                    }
                } else if let settings = dataAndTheme.1 {
                    if let theme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: .builtin(PresentationBuiltinThemeReference(baseTheme: settings.baseTheme)), accentColor: UIColor(argb: settings.accentColor), backgroundColors: [], bubbleColors: settings.messageColors, wallpaper: settings.wallpaper) {
                        let previewController = ThemePreviewController(context: context, previewTheme: theme, source: .theme(dataAndTheme.2))
                        navigationController?.pushViewController(previewController)
                    }
                }
            }, error: { error in
                let errorText: String
                switch error {
                    case .generic, .slugInvalid:
                        errorText = presentationData.strings.Theme_ErrorNotFound
                    case .unsupported:
                        errorText = presentationData.strings.Theme_Unsupported
                }
                present(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
            }))
            dismissInput()
        case let .settings(section):
            dismissInput()
            switch section {
            case .theme:
                if let navigationController = navigationController {
                    let controller = themeSettingsController(context: context)
                    controller.navigationPresentation = .modal
                    
                    var controllers = navigationController.viewControllers
                    controllers = controllers.filter { !($0 is ThemeSettingsController) }
                    controllers.append(controller)
                    
                    navigationController.setViewControllers(controllers, animated: true)
                }
            case .devices:
                if let navigationController = navigationController {
                    let activeSessions = deferred { () -> Signal<(ActiveSessionsContext, Int, WebSessionsContext), NoError> in
                        let activeSessionsContext = context.engine.privacy.activeSessions()
                        let webSessionsContext = context.engine.privacy.webSessions()
                        let otherSessionCount = activeSessionsContext.state
                        |> map { state -> Int in
                            return state.sessions.filter({ !$0.isCurrent }).count
                        }
                        |> distinctUntilChanged
                        
                        return otherSessionCount
                        |> map { value in
                            return (activeSessionsContext, value, webSessionsContext)
                        }
                    }
                    
                    let _ = (activeSessions
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { activeSessionsContext, count, webSessionsContext in
                        let controller = recentSessionsController(context: context, activeSessionsContext: activeSessionsContext, webSessionsContext: webSessionsContext, websitesOnly: false)
                        controller.navigationPresentation = .modal
                        
                        var controllers = navigationController.viewControllers
                        controllers = controllers.filter { !($0 is RecentSessionsController) }
                        controllers.append(controller)
                        
                        navigationController.setViewControllers(controllers, animated: true)
                    })
                }
            case .autoremoveMessages:
                let _ = (context.engine.privacy.requestAccountPrivacySettings()
                |> take(1)
                |> deliverOnMainQueue).start(next: { settings in
                    navigationController?.pushViewController(globalAutoremoveScreen(context: context, initialValue: settings.messageAutoremoveTimeout ?? 0, updated: { _ in }), animated: true)
                })
            case .twoStepAuth:
                break
            case .enableLog:
                if let navigationController = navigationController {
                    let _ = updateLoggingSettings(accountManager: context.sharedContext.accountManager, {
                        $0.withUpdatedLogToFile(true)
                    }).start()
                    
                    if let controller = context.sharedContext.makeDebugSettingsController(context: context) {
                        var controllers = navigationController.viewControllers
                        controllers.append(controller)
                        
                        navigationController.setViewControllers(controllers, animated: true)
                    }
                }
            case .phonePrivacy:
                let privacySignal = context.engine.privacy.requestAccountPrivacySettings()
                let _ = (privacySignal
                |> deliverOnMainQueue).start(next: { info in
                    let current: SelectivePrivacySettings = info.phoneNumber
                    if let navigationController = navigationController {
                        let controller = selectivePrivacySettingsController(context: context, kind: .phoneNumber, current: current, phoneDiscoveryEnabled: info.phoneDiscoveryEnabled, updated: { _, _, _, _ in
                        })
                        controller.navigationPresentation = .modal
                        navigationController.pushViewController(controller)
                    }
                })
            }
        case let .premiumOffer(reference):
            dismissInput()
            let controller = context.sharedContext.makePremiumIntroController(context: context, source: .deeplink(reference), forceDark: false, dismissed: nil)
            if let navigationController = navigationController {
                navigationController.pushViewController(controller, animated: true)
            }
        case let .premiumMultiGift(reference):
            dismissInput()
            let controller = context.sharedContext.makePremiumGiftController(context: context, source: .deeplink(reference), completion: nil)
            if let navigationController = navigationController {
                navigationController.pushViewController(controller, animated: true)
            }
        case let .starsTopup(amount, purpose):
            dismissInput()
            if let starsContext = context.starsContext {
                let proceed = {
                    let controller = context.sharedContext.makeStarsPurchaseScreen(context: context, starsContext: starsContext, options: [], purpose: .topUp(requiredStars: amount, purpose: purpose), completion: { _ in })
                    if let navigationController = navigationController {
                        navigationController.pushViewController(controller, animated: true)
                    }
                }
                if let currentState = starsContext.currentState, currentState.balance >= StarsAmount(value: amount, nanos: 0) {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    let controller = UndoOverlayController(
                        presentationData: presentationData,
                        content: .universal(
                            animation: "StarsBuy",
                            scale: 0.066,
                            colors: [:],
                            title: nil,
                            text: presentationData.strings.Stars_Purchase_EnoughStars,
                            customUndoText: presentationData.strings.Stars_Purchase_BuyAnyway,
                            timeout: nil
                        ),
                        elevatedLayout: true,
                        action: { action in
                            if case .undo = action {
                                proceed()
                            }
                            return true
                        })
                    present(controller, nil)
                } else {
                    proceed()
                }
            }
        case .stars:
            dismissInput()
            if let starsContext = context.starsContext {
                let controller = context.sharedContext.makeStarsTransactionsScreen(context: context, starsContext: starsContext)
                controller.navigationPresentation = .modal
                if let navigationController {
                    navigationController.pushViewController(controller, animated: true)
                }
            }
        case let .joinVoiceChat(peerId, invite):
            let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
            |> deliverOnMainQueue).start(next: { peer in
                guard let peer = peer else {
                    return
                }
                dismissInput()
                if let navigationController = navigationController {
                    context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), completion: { chatController in
                        guard let chatController = chatController as? ChatControllerImpl else {
                            return
                        }
                        navigationController.currentWindow?.present(VoiceChatJoinScreen(context: context, peerId: peerId, invite: invite, join: { [weak chatController] call in
                            chatController?.joinGroupCall(peerId: peerId, invite: invite, activeCall: EngineGroupCallDescription(call))
                        }), on: .root, blockInteraction: false, completion: {})
                    }))
                }
            })
        case .importStickers:
            dismissInput()
            if let navigationController = navigationController, let data = UIPasteboard.general.data(forPasteboardType: "org.telegram.third-party.stickerset"), let stickerPack = ImportStickerPack(data: data), !stickerPack.stickers.isEmpty {
                for controller in navigationController.overlayControllers {
                    if controller is ImportStickerPackController {
                        controller.dismiss()
                    }
                }
                let controller = ImportStickerPackController(context: context, stickerPack: stickerPack, parentNavigationController: navigationController)
                Queue.mainQueue().after(0.3) {
                    present(controller, nil)
                }
            }
        case let .shareStory(sessionId):
            dismissInput()
        
            let rootPath = context.sharedContext.applicationBindings.containerPath + "/telegram-data"
            let storiesPath = rootPath + "/share/stories/\(sessionId)"
        
            var filePaths: [String] = []
            do {
                let directoryContents = try FileManager.default.contentsOfDirectory(atPath: storiesPath)
                
                for item in directoryContents {
                    let fullPath = storiesPath + "/" + item
                    
                    var isDirectory: ObjCBool = false
                    if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory) && !isDirectory.boolValue {
                        filePaths.append(fullPath)
                    }
                }
                filePaths.sort { lhs, rhs in
                    let lhsName = ((lhs as NSString).lastPathComponent as NSString).deletingPathExtension
                    let rhsName = ((rhs as NSString).lastPathComponent as NSString).deletingPathExtension
                    if let lhsValue = Int(lhsName), let rhsValue = Int(rhsName) {
                        return lhsValue < rhsValue
                    }
                    return lhsName < rhsName
                }
            } catch {
            }
        
            func subject(for path: String) -> MediaEditorScreenImpl.Subject? {
                if path.hasSuffix(".jpg") {
                    if let image = UIImage(contentsOfFile: path)?.fixedOrientation() {
                        return .image(image: image, dimensions: PixelDimensions(image.size), additionalImage: nil, additionalImagePosition: .topLeft, fromCamera: false)
                    }
                } else {
                    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
                    var dimensions = PixelDimensions(width: 1080, height: 1920)
                    if let videoTrack = asset.tracks(withMediaType: .video).first {
                        dimensions = PixelDimensions(videoTrack.naturalSize)
                    }
                    return .video(videoPath: path, thumbnail: nil, mirror: false, additionalVideoPath: nil, additionalThumbnail: nil, dimensions: dimensions, duration: asset.duration.seconds, videoPositionChanges: [], additionalVideoPosition: .bottomLeft, fromCamera: false)
                }
                return nil
            }
    
            var source: Any?
            if filePaths.count > 1 {
                var subjects: [MediaEditorScreenImpl.Subject] = []
                for path in filePaths {
                    if let subject = subject(for: path) {
                        subjects.append(subject)
                    }
                }
                source = subjects
            } else if let path = filePaths.first {
                if let subject = subject(for: path) {
                    source = subject
                }
            }
        
            if let navigationController = context.sharedContext.mainWindow?.viewController as? NavigationController {
                for controller in navigationController.overlayControllers {
                    controller.dismiss()
                }
                for controller in navigationController.globalOverlayControllers {
                    controller.dismiss()
                }
            }
        
            let _ = (context.engine.messages.checkStoriesUploadAvailability(target: .myStories)
            |> deliverOnMainQueue).start(next: { availability in
                if case let .available(remainingCount) = availability {
                    let controller = context.sharedContext.makeStoryMediaEditorScreen(context: context, source: source, text: nil, link: nil, remainingCount: remainingCount, completion: { results, externalState, commit in
                        let target: Stories.PendingTarget = results.first!.target
                        externalState.storyTarget = target
                        
                        if let rootController = context.sharedContext.mainWindow?.viewController as? TelegramRootControllerInterface {
                            rootController.popToRoot(animated: false)
                            rootController.proceedWithStoryUpload(target: target, results: results, existingMedia: nil, forwardInfo: nil, externalState: externalState, commit: commit)
                        }
                    })
                    if let navigationController {
                        navigationController.pushViewController(controller)
                    }
                } else {
                    let subject: PremiumLimitSubject
                    switch availability {
                    case .expiringLimit:
                        subject = .expiringStories
                    case .weeklyLimit:
                        subject = .storiesWeekly
                    case .monthlyLimit:
                        subject = .storiesMonthly
                    default:
                        subject = .expiringStories
                    }
                    var replaceImpl: ((ViewController) -> Void)?
                    let controller = context.sharedContext.makePremiumLimitController(context: context, subject: subject, count: 10, forceDark: false, cancel: {
                    }, action: {
                        let controller = context.sharedContext.makePremiumIntroController(context: context, source: .stories, forceDark: true, dismissed: {
                        })
                        replaceImpl?(controller)
                        return true
                    })
                    replaceImpl = { [weak controller] c in
                        controller?.replace(with: c)
                    }
                    if let navigationController {
                        navigationController.pushViewController(controller)
                    }
                }
            })
        case let .startAttach(peerId, payload, choose):
            let presentError: (String) -> Void = { errorText in
                present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: errorText, timeout: nil, customUndoText: nil), elevatedLayout: true, animateInAsReplacement: false, action: { _ in
                    return true
                }), nil)
            }
            let _ = (context.engine.messages.attachMenuBots()
            |> deliverOnMainQueue).start(next: { attachMenuBots in
                func filterChooseTypes(_ chooseTypes: ResolvedBotChoosePeerTypes?, peerTypes: AttachMenuBots.Bot.PeerFlags) -> ResolvedBotChoosePeerTypes? {
                    var chooseTypes = chooseTypes
                    if chooseTypes != nil {
                        if !peerTypes.contains(.user) {
                            chooseTypes?.remove(.users)
                        }
                        if !peerTypes.contains(.bot) {
                            chooseTypes?.remove(.bots)
                        }
                        if !peerTypes.contains(.group) {
                            chooseTypes?.remove(.groups)
                        }
                        if !peerTypes.contains(.channel) {
                            chooseTypes?.remove(.channels)
                        }
                    }
                    return (chooseTypes?.isEmpty ?? true) ? nil : chooseTypes
                }
                
                if let bot = attachMenuBots.first(where: { $0.peer.id == peerId }), !bot.flags.contains(.notActivated) {
                    let choose = filterChooseTypes(choose, peerTypes: bot.peerTypes)
                    
                    if let choose = choose {
                        var filters: ChatListNodePeersFilter = []
                        filters.insert(.onlyWriteable)
                        filters.insert(.excludeDisabled)

                        if !choose.contains(.users) {
                            filters.insert(.excludeUsers)
                        }
                        if !choose.contains(.bots) {
                            filters.insert(.excludeBots)
                        }
                        if !choose.contains(.groups) {
                            filters.insert(.excludeGroups)
                        }
                        if !choose.contains(.channels) {
                            filters.insert(.excludeChannels)
                        }
                        
                        if let navigationController = navigationController {
                            let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, updatedPresentationData: updatedPresentationData, filter: filters, hasChatListSelector: true, hasContactSelector: false, title: presentationData.strings.WebApp_SelectChat, selectForumThreads: true))
                            controller.peerSelected = { [weak navigationController] peer, _ in
                                guard let navigationController else {
                                    return
                                }
                                let _ = context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), attachBotStart: ChatControllerInitialAttachBotStart(botId: bot.peer.id, payload: payload, justInstalled: false), keepStack: .never, useExisting: true))
                            }
                            navigationController.pushViewController(controller)
                        }
                    } else {
                        if case let .chat(chatPeerId, _, _) = urlContext {
                            let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: chatPeerId))
                            |> deliverOnMainQueue).start(next: { chatPeer in
                                guard let navigationController = navigationController, let chatPeer else {
                                    return
                                }
                                let _ = context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(chatPeer), attachBotStart: ChatControllerInitialAttachBotStart(botId: peerId, payload: payload, justInstalled: false), keepStack: .never, useExisting: true))
                            })
                        } else {
                            presentError(presentationData.strings.WebApp_AddToAttachmentAlreadyAddedError)
                        }
                    }
                } else {
                    let _ = (context.engine.messages.getAttachMenuBot(botId: peerId)
                    |> deliverOnMainQueue).start(next: { bot in
                        let choose = filterChooseTypes(choose, peerTypes: bot.peerTypes)
                        
                        let controller = webAppTermsAlertController(context: context, updatedPresentationData: updatedPresentationData, bot: bot, completion: { allowWrite in
                            let _ = (context.engine.messages.addBotToAttachMenu(botId: peerId, allowWrite: allowWrite)
                            |> deliverOnMainQueue).start(error: { _ in
                                presentError(presentationData.strings.WebApp_AddToAttachmentUnavailableError)
                            }, completed: {
                                if let choose = choose {
                                    var filters: ChatListNodePeersFilter = []
                                    filters.insert(.onlyWriteable)
                                    filters.insert(.excludeDisabled)

                                    if !choose.contains(.users) {
                                        filters.insert(.excludeUsers)
                                    }
                                    if !choose.contains(.bots) {
                                        filters.insert(.excludeBots)
                                    }
                                    if !choose.contains(.groups) {
                                        filters.insert(.excludeGroups)
                                    }
                                    if !choose.contains(.channels) {
                                        filters.insert(.excludeChannels)
                                    }
                                    
                                    if let navigationController = navigationController {
                                        let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, updatedPresentationData: updatedPresentationData, filter: filters, hasChatListSelector: true, hasContactSelector: false, title: presentationData.strings.WebApp_SelectChat, selectForumThreads: true))
                                        controller.peerSelected = { [weak navigationController] peer, _ in
                                            guard let navigationController else {
                                                return
                                            }
                                            let _ = context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), attachBotStart: ChatControllerInitialAttachBotStart(botId: bot.peer.id, payload: payload, justInstalled: true), useExisting: true))
                                        }
                                        navigationController.pushViewController(controller)
                                    }
                                } else {
                                    if case let .chat(chatPeerId, _, _) = urlContext {
                                        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: chatPeerId))
                                        |> deliverOnMainQueue).start(next: { chatPeer in
                                            guard let navigationController = navigationController, let chatPeer else {
                                                return
                                            }
                                            
                                            let _ = context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(chatPeer), attachBotStart: ChatControllerInitialAttachBotStart(botId: bot.peer.id, payload: payload, justInstalled: true), useExisting: true))
                                        })
                                    }
                                }
                            })
                        })
                        present(controller, nil)
                    }, error: { _ in
                        presentError(presentationData.strings.WebApp_AddToAttachmentUnavailableError)
                    })
                }
            })
        case let .invoice(slug, invoice):
            dismissInput()
        
            if let invoice {
                if let navigationController = navigationController {
                    let inputData = Promise<BotCheckoutController.InputData?>()
                    inputData.set(BotCheckoutController.InputData.fetch(context: context, source: .slug(slug))
                    |> map(Optional.init)
                    |> `catch` { _ -> Signal<BotCheckoutController.InputData?, NoError> in
                        return .single(nil)
                    })
                    if invoice.currency == "XTR", let starsContext = context.starsContext {
                        let starsInputData = combineLatest(
                            inputData.get(),
                            starsContext.state
                        )
                        |> map { data, state -> (StarsContext.State, BotPaymentForm, EnginePeer?, EnginePeer?)? in
                            if let data, let state {
                                return (state, data.form, data.botPeer, nil)
                            } else {
                                return nil
                            }
                        }
                        let _ = (starsInputData |> filter { $0 != nil } |> take(1) |> deliverOnMainQueue).start(next: { _ in
                            let controller = context.sharedContext.makeStarsTransferScreen(context: context, starsContext: starsContext, invoice: invoice, source: .slug(slug), extendedMedia: [], inputData: starsInputData, completion: { _ in })
                            navigationController.pushViewController(controller)
                        })
                    } else {
                        let checkoutController = BotCheckoutController(context: context, invoice: invoice, source: .slug(slug), inputData: inputData, completed: { currencyValue, receiptMessageId in
                            /*strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .paymentSent(currencyValue: currencyValue, itemTitle: invoice.title), elevatedLayout: false, action: { action in
                             guard let strongSelf = self, let receiptMessageId = receiptMessageId else {
                             return false
                             }
                             
                             if case .info = action {
                             strongSelf.present(BotReceiptController(context: strongSelf.context, messageId: receiptMessageId), in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                             return true
                             }
                             return false
                             }), in: .current)*/
                        })
                        checkoutController.navigationPresentation = .modal
                        navigationController.pushViewController(checkoutController)
                    }
                }
            } else {
                present(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Chat_ErrorInvoiceNotFound, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
            }
        case let .chatFolder(slug):
            if let navigationController = navigationController {
                let signal = context.engine.peers.checkChatFolderLink(slug: slug)
                
                var cancelImpl: (() -> Void)?
                let progressSignal = Signal<Never, NoError> { subscriber in
                    let controller = OverlayStatusController(theme: presentationData.theme,  type: .loading(cancelled: {
                        cancelImpl?()
                    }))
                    present(controller, nil)
                    return ActionDisposable { [weak controller] in
                        Queue.mainQueue().async() {
                            controller?.dismiss()
                        }
                    }
                }
                |> runOn(Queue.mainQueue())
                |> delay(0.35, queue: Queue.mainQueue())
                
                let disposable = MetaDisposable()
                let progressDisposable = progressSignal.start()
                cancelImpl = {
                    disposable.set(nil)
                }
                disposable.set((signal
                |> afterDisposed {
                    Queue.mainQueue().async {
                        progressDisposable.dispose()
                    }
                }
                |> deliverOnMainQueue).start(next: { [weak navigationController] result in
                    guard let navigationController else {
                        return
                    }
                    navigationController.pushViewController(ChatFolderLinkPreviewScreen(context: context, subject: .slug(slug), contents: result))
                }, error: { error in
                    let errorText: String
                    switch error {
                    case .generic:
                        errorText = presentationData.strings.Chat_ErrorFolderLinkExpired
                    }
                    present(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                }))
                dismissInput()
            }
        case let .story(peerId, id):
            let _ = (context.account.postbox.transaction { transaction -> Bool in
                if let value = transaction.getStory(id: StoryId(peerId: peerId, id: id)), !value.data.isEmpty {
                    return true
                } else {
                    return false
                }
            }
            |> deliverOnMainQueue).startStandalone(next: { exists in
                if exists {
                    let storyContent = SingleStoryContentContextImpl(context: context, storyId: StoryId(peerId: peerId, id: id), readGlobally: true)
                    let _ = (storyContent.state
                    |> take(1)
                    |> deliverOnMainQueue).startStandalone(next: { [weak navigationController] _ in
                        let transitionIn: StoryContainerScreen.TransitionIn? = nil
                        
                        let storyContainerScreen = StoryContainerScreen(
                            context: context,
                            content: storyContent,
                            transitionIn: transitionIn,
                            transitionOut: { _, _ in
                                let transitionOut: StoryContainerScreen.TransitionOut? = nil
                                
                                return transitionOut
                            }
                        )
                        navigationController?.pushViewController(storyContainerScreen)
                        completion?()
                    })
                } else {
                    var elevatedLayout = true
                    if case .chat = urlContext {
                        elevatedLayout = false
                    }
                    present(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "story_expired", scale: 0.066, colors: [:], title: nil, text: presentationData.strings.Story_TooltipExpired, customUndoText: nil, timeout: nil), elevatedLayout: elevatedLayout, animateInAsReplacement: false, action: { _ in
                        return true
                    }), nil)
                }
            })
        case let .boost(peerId, status, myBoostStatus):
            var dismissedImpl: (() -> Void)?
            if let storyProgressPauseContext = contentContext as? StoryProgressPauseContext {
                let updateExternalController = storyProgressPauseContext.update
                dismissedImpl = {
                    updateExternalController(nil)
                }
            }
        
            if let peerId, let status {
                var isCurrent = false
                if case let .chat(chatPeerId, _, _) = urlContext, chatPeerId == peerId {
                    isCurrent = true
                }
                var forceDark = false
                if let updatedPresentationData, updatedPresentationData.initial.theme.overallDarkAppearance {
                    forceDark = true
                }
                let controller = PremiumBoostLevelsScreen(
                    context: context,
                    peerId: peerId,
                    mode: .user(mode: isCurrent ? .current : .external),
                    status: status,
                    myBoostStatus: myBoostStatus,
                    openPeer:  { peer in
                        openPeer(peer, .chat(textInputState: nil, subject: nil, peekData: nil))
                    },
                    forceDark: forceDark
                )
                controller.disposed = {
                    dismissedImpl?()
                }
                navigationController?.pushViewController(controller)
                
                if let storyProgressPauseContext = contentContext as? StoryProgressPauseContext {
                    storyProgressPauseContext.update(controller)
                }
            } else {
                let controller = textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Chat_ErrorCantBoost, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
                present(controller, nil)
                
                controller.dismissed = { _ in
                    dismissedImpl?()
                }
                
                if let storyProgressPauseContext = contentContext as? StoryProgressPauseContext {
                    storyProgressPauseContext.update(controller)
                }
            }
        case let .premiumGiftCode(slug):
            var forceDark = false
            if let updatedPresentationData, updatedPresentationData.initial.theme.overallDarkAppearance {
                forceDark = true
            }
        
            let progressSignal = Signal<Never, NoError> { subscriber in
                if let progress {
                    progress.set(.single(true))
                    return ActionDisposable {
                        Queue.mainQueue().async() {
                            progress.set(.single(false))
                        }
                    }
                } else {
                    return EmptyDisposable
                }
            }
            |> runOn(Queue.mainQueue())
            |> delay(0.25, queue: Queue.mainQueue())
            let progressDisposable = progressSignal.startStrict()
            
            var signal = context.engine.payments.checkPremiumGiftCode(slug: slug)
            signal = signal
            |> afterDisposed {
                Queue.mainQueue().async {
                    progressDisposable.dispose()
                }
            }
        
            let _ = (signal
            |> deliverOnMainQueue).startStandalone(next: { [weak navigationController] giftCode in
                if let giftCode {
                    if giftCode.fromPeerId == nil, let toPeerId = giftCode.toPeerId {
                        let fromPeerId: PeerId
                        if case let .chat(peerId, message, _) = urlContext {
                            fromPeerId = message?.author?.id ?? peerId
                        } else {
                            fromPeerId = context.account.peerId
                        }
                        let controller = PremiumIntroScreen(context: context, source: .gift(from: fromPeerId, to: toPeerId, duration: giftCode.months, giftCode: giftCode))
                        navigationController?.pushViewController(controller)
                    } else {
                        var dismissImpl: (() -> Void)?
                        let controller = PremiumGiftCodeScreen(
                            context: context,
                            subject: .giftCode(giftCode),
                            forceDark: forceDark,
                            action: { [weak navigationController] in
                                let _ = (context.engine.payments.applyPremiumGiftCode(slug: slug)
                                |> deliverOnMainQueue).startStandalone(error: { error in
                                    dismissImpl?()
                                    
                                    if case let .waitForExpiration(date) = error {
                                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                        let dateText = stringForMediumDate(timestamp: date, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat)
                                        (navigationController?.topViewController as? ViewController)?.present(UndoOverlayController(presentationData: presentationData, content: .info(title: presentationData.strings.Premium_Gift_ApplyLink_AlreadyHasPremium_Title, text: presentationData.strings.Premium_Gift_ApplyLink_AlreadyHasPremium_Text(dateText).string, timeout: nil, customUndoText: nil), elevatedLayout: true, position: .bottom, action: { _ in return true }), in: .window(.root))
                                    }
                                }, completed: {
                                    dismissImpl?()
                                    
                                    let controller = PremiumIntroScreen(context: context, source: .settings, forceDark: forceDark, forceHasPremium: true)
                                    navigationController?.pushViewController(controller)
                                    Queue.mainQueue().after(0.3, {
                                        controller.animateSuccess()
                                    })
                                })
                            },
                            openPeer: { peer in
                                if peer.id != context.account.peerId {
                                    openPeer(peer, .chat(textInputState: nil, subject: nil, peekData: nil))
                                    if case let .chat(peerId, _, _) = urlContext, peerId == peer.id {
                                        dismissImpl?()
                                    }
                                }
                            },
                            openMessage: { messageId in
                                let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: messageId.peerId))
                                |> deliverOnMainQueue).startStandalone(next: { peer in
                                    guard let peer else {
                                        return
                                    }
                                    openPeer(peer, .chat(textInputState: nil, subject: .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false), peekData: nil))
                                    if case let .chat(peerId, _, _) = urlContext, peerId == messageId.peerId {
                                        dismissImpl?()
                                    }
                                })
                            },
                            shareLink: { link in
                                let messages: [EnqueueMessage] = [.message(text: link, attributes: [], inlineStickers: [:], mediaReference: nil, threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])]
                                
                                let peerSelectionController = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled], multipleSelection: false, selectForumThreads: true))
                                peerSelectionController.peerSelected = { [weak peerSelectionController] peer, threadId in
                                    if let _ = peerSelectionController {
                                        Queue.mainQueue().after(0.88) {
                                            HapticFeedback().success()
                                        }
                                        
                                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                        (navigationController?.topViewController as? ViewController)?.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: true, text: peer.id == context.account.peerId ? presentationData.strings.GiftLink_LinkSharedToSavedMessages : presentationData.strings.GiftLink_LinkSharedToChat(peer.compactDisplayTitle).string), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .window(.root))
                                        
                                        let _ = (enqueueMessages(account: context.account, peerId: peer.id, messages: messages)
                                        |> deliverOnMainQueue).startStandalone()
                                        if let peerSelectionController = peerSelectionController {
                                            peerSelectionController.dismiss()
                                        }
                                    }
                                }
                                navigationController?.pushViewController(peerSelectionController)
                            }
                        )
                        dismissImpl = { [weak controller] in
                            controller?.dismissAnimated()
                        }
                        navigationController?.pushViewController(controller)
                    }
                } else {
                    present(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                }
            })
        case let .collectible(gift):
            if let gift {
                var dismissedImpl: (() -> Void)?
                if let storyProgressPauseContext = contentContext as? StoryProgressPauseContext {
                    let updateExternalController = storyProgressPauseContext.update
                    dismissedImpl = {
                        updateExternalController(nil)
                    }
                }
                let controller = context.sharedContext.makeGiftViewScreen(context: context, gift: gift, shareStory: { [weak navigationController] uniqueGift in
                    Queue.mainQueue().after(0.15) {
                        if let lastController = navigationController?.viewControllers.last as? ViewController {
                            let controller = context.sharedContext.makeStorySharingScreen(context: context, subject: .gift(gift), parentController: lastController)
                            navigationController?.pushViewController(controller)
                        }
                    }
                }, dismissed: {
                    dismissedImpl?()
                })
                navigationController?.pushViewController(controller)
                
                if let storyProgressPauseContext = contentContext as? StoryProgressPauseContext {
                    storyProgressPauseContext.update(controller)
                }
            } else {
                present(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
            }
        case let .messageLink(link):
            if let link {
                if let navigationController = navigationController {
                    context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                        navigationController: navigationController,
                        context: context,
                        chatLocation: .peer(link.peer),
                        updateTextInputState: ChatTextInputState(inputText: chatInputStateStringWithAppliedEntities(link.message, entities: link.entities)),
                        activateInput: .text,
                        keepStack: .always
                    ))
                }
            } else {
                present(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.BusinessLink_ErrorExpired, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
            }
    }
}
