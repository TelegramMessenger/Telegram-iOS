import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import ChatPresentationInterfaceState
import ChatInterfaceState
import TelegramNotices
import PresentationDataUtils
import TelegramCallsUI
import AttachmentUI
import WebUI

func updateChatPresentationInterfaceStateImpl(
    selfController: ChatControllerImpl,
    transition: ContainedViewLayoutTransition,
    interactive: Bool,
    saveInterfaceState: Bool,
    _ f: (ChatPresentationInterfaceState) -> ChatPresentationInterfaceState,
    completion externalCompletion: @escaping (ContainedViewLayoutTransition) -> Void
) {
    var completion = externalCompletion
    var temporaryChatPresentationInterfaceState = f(selfController.presentationInterfaceState)
    
    if selfController.presentationInterfaceState.keyboardButtonsMessage?.visibleButtonKeyboardMarkup != temporaryChatPresentationInterfaceState.keyboardButtonsMessage?.visibleButtonKeyboardMarkup || selfController.presentationInterfaceState.keyboardButtonsMessage?.id != temporaryChatPresentationInterfaceState.keyboardButtonsMessage?.id {
        if let keyboardButtonsMessage = temporaryChatPresentationInterfaceState.keyboardButtonsMessage, let keyboardMarkup = keyboardButtonsMessage.visibleButtonKeyboardMarkup {
            if selfController.presentationInterfaceState.interfaceState.editMessage == nil && selfController.presentationInterfaceState.interfaceState.composeInputState.inputText.length == 0 && keyboardButtonsMessage.id != temporaryChatPresentationInterfaceState.interfaceState.messageActionsState.closedButtonKeyboardMessageId && keyboardButtonsMessage.id != temporaryChatPresentationInterfaceState.interfaceState.messageActionsState.dismissedButtonKeyboardMessageId && temporaryChatPresentationInterfaceState.botStartPayload == nil {
                temporaryChatPresentationInterfaceState = temporaryChatPresentationInterfaceState.updatedInputMode({ _ in
                    return .inputButtons(persistent: keyboardMarkup.flags.contains(.persistent))
                })
            }
            
            if case let .peer(peerId) = selfController.chatLocation, peerId.namespace == Namespaces.Peer.CloudChannel || peerId.namespace == Namespaces.Peer.CloudGroup {
                if temporaryChatPresentationInterfaceState.interfaceState.replyMessageSubject == nil && temporaryChatPresentationInterfaceState.interfaceState.messageActionsState.processedSetupReplyMessageId != keyboardButtonsMessage.id  {
                    temporaryChatPresentationInterfaceState = temporaryChatPresentationInterfaceState.updatedInterfaceState({
                        $0.withUpdatedReplyMessageSubject(ChatInterfaceState.ReplyMessageSubject(
                            messageId: keyboardButtonsMessage.id,
                            quote: nil
                        )).withUpdatedMessageActionsState({ value in
                        var value = value
                        value.processedSetupReplyMessageId = keyboardButtonsMessage.id
                        return value
                    }) })
                }
            }
        } else {
            temporaryChatPresentationInterfaceState = temporaryChatPresentationInterfaceState.updatedInputMode({ mode in
                if case .inputButtons = mode {
                    return .text
                } else {
                    return mode
                }
            })
        }
    }
    
    if let keyboardButtonsMessage = temporaryChatPresentationInterfaceState.keyboardButtonsMessage, keyboardButtonsMessage.requestsSetupReply {
        if temporaryChatPresentationInterfaceState.interfaceState.replyMessageSubject == nil && temporaryChatPresentationInterfaceState.interfaceState.messageActionsState.processedSetupReplyMessageId != keyboardButtonsMessage.id  {
            temporaryChatPresentationInterfaceState = temporaryChatPresentationInterfaceState.updatedInterfaceState({ $0.withUpdatedReplyMessageSubject(ChatInterfaceState.ReplyMessageSubject(
                messageId: keyboardButtonsMessage.id,
                quote: nil
            )).withUpdatedMessageActionsState({ value in
                var value = value
                value.processedSetupReplyMessageId = keyboardButtonsMessage.id
                return value
            }) })
        }
    }
    
    let inputTextPanelState = inputTextPanelStateForChatPresentationInterfaceState(temporaryChatPresentationInterfaceState, context: selfController.context)
    var updatedChatPresentationInterfaceState = temporaryChatPresentationInterfaceState.updatedInputTextPanelState({ _ in return inputTextPanelState })
    
    let contextQueryUpdates = contextQueryResultStateForChatInterfacePresentationState(updatedChatPresentationInterfaceState, context: selfController.context, currentQueryStates: &selfController.contextQueryStates, requestBotLocationStatus: { [weak selfController] peerId in
        guard let selfController else {
            return
        }
        let _ = (ApplicationSpecificNotice.updateInlineBotLocationRequestState(accountManager: selfController.context.sharedContext.accountManager, peerId: peerId, timestamp: Int32(Date().timeIntervalSince1970 + 10 * 60))
        |> deliverOnMainQueue).startStandalone(next: { [weak selfController] value in
            guard let selfController, value else {
                return
            }
            selfController.present(textAlertController(context: selfController.context, updatedPresentationData: selfController.updatedPresentationData, title: nil, text: selfController.presentationData.strings.Conversation_ShareInlineBotLocationConfirmation, actions: [TextAlertAction(type: .defaultAction, title: selfController.presentationData.strings.Common_Cancel, action: {
            }), TextAlertAction(type: .defaultAction, title: selfController.presentationData.strings.Common_OK, action: { [weak selfController] in
                guard let selfController else {
                    return
                }
                let _ = ApplicationSpecificNotice.setInlineBotLocationRequest(accountManager: selfController.context.sharedContext.accountManager, peerId: peerId, value: 0).startStandalone()
            })]), in: .window(.root))
        })
    })
    
    for (kind, update) in contextQueryUpdates {
        switch update {
        case .remove:
            if let (_, disposable) = selfController.contextQueryStates[kind] {
                disposable.dispose()
                selfController.contextQueryStates.removeValue(forKey: kind)
                
                updatedChatPresentationInterfaceState = updatedChatPresentationInterfaceState.updatedInputQueryResult(queryKind: kind, { _ in
                    return nil
                })
            }
            if case .contextRequest = kind {
                selfController.performingInlineSearch.set(false)
            }
        case let .update(query, signal):
            let currentQueryAndDisposable = selfController.contextQueryStates[kind]
            currentQueryAndDisposable?.1.dispose()
            
            var inScope = true
            var inScopeResult: ((ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?)?
            selfController.contextQueryStates[kind] = (query, (signal
            |> deliverOnMainQueue).startStrict(next: { [weak selfController] result in
                guard let selfController else {
                    return
                }
                if Thread.isMainThread && inScope {
                    inScope = false
                    inScopeResult = result
                } else {
                    selfController.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                        $0.updatedInputQueryResult(queryKind: kind, { previousResult in
                            return result(previousResult)
                        })
                    })
                }
            }, error: { [weak selfController] error in
                guard let selfController else {
                    return
                }
                if case .contextRequest = kind {
                    selfController.performingInlineSearch.set(false)
                }
                
                switch error {
                case .generic:
                    break
                case let .inlineBotLocationRequest(peerId):
                    selfController.present(textAlertController(context: selfController.context, updatedPresentationData: selfController.updatedPresentationData, title: nil, text: selfController.presentationData.strings.Conversation_ShareInlineBotLocationConfirmation, actions: [TextAlertAction(type: .defaultAction, title: selfController.presentationData.strings.Common_Cancel, action: { [weak selfController] in
                        guard let selfController else {
                            return
                        }
                        let _ = ApplicationSpecificNotice.setInlineBotLocationRequest(accountManager: selfController.context.sharedContext.accountManager, peerId: peerId, value: Int32(Date().timeIntervalSince1970 + 10 * 60)).startStandalone()
                    }), TextAlertAction(type: .defaultAction, title: selfController.presentationData.strings.Common_OK, action: { [weak selfController] in
                        guard let selfController else {
                            return
                        }
                        let _ = ApplicationSpecificNotice.setInlineBotLocationRequest(accountManager: selfController.context.sharedContext.accountManager, peerId: peerId, value: 0).startStandalone()
                    })]), in: .window(.root))
                }
            }, completed: { [weak selfController] in
                guard let selfController else {
                    return
                }
                if case .contextRequest = kind {
                    selfController.performingInlineSearch.set(false)
                }
            }))
            inScope = false
            if let inScopeResult = inScopeResult {
                updatedChatPresentationInterfaceState = updatedChatPresentationInterfaceState.updatedInputQueryResult(queryKind: kind, { previousResult in
                    return inScopeResult(previousResult)
                })
            } else {
                if case .contextRequest = kind {
                    selfController.performingInlineSearch.set(true)
                }
            }
        
            if case let .peer(peerId) = selfController.chatLocation, peerId.namespace == Namespaces.Peer.SecretChat {
                if case .contextRequest = query {
                    let _ = (ApplicationSpecificNotice.getSecretChatInlineBotUsage(accountManager: selfController.context.sharedContext.accountManager)
                    |> deliverOnMainQueue).startStandalone(next: { [weak selfController] value in
                        guard let selfController, !value else {
                            return
                        }
                        let _ = ApplicationSpecificNotice.setSecretChatInlineBotUsage(accountManager: selfController.context.sharedContext.accountManager).startStandalone()
                        selfController.present(textAlertController(context: selfController.context, updatedPresentationData: selfController.updatedPresentationData, title: nil, text: selfController.presentationData.strings.Conversation_SecretChatContextBotAlert, actions: [TextAlertAction(type: .defaultAction, title: selfController.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    })
                }
            }
        }
    }
    
    var isBot = false
    if let peer = updatedChatPresentationInterfaceState.renderedPeer?.peer as? TelegramUser, peer.botInfo != nil {
        isBot = true
    } else {
        isBot = false
    }
    selfController.chatDisplayNode.historyNode.chatHasBots = updatedChatPresentationInterfaceState.hasBots || isBot
    
    if let (updatedSearchQuerySuggestionState, updatedSearchQuerySuggestionSignal) = searchQuerySuggestionResultStateForChatInterfacePresentationState(updatedChatPresentationInterfaceState, context: selfController.context, currentQuery: selfController.searchQuerySuggestionState?.0) {
        selfController.searchQuerySuggestionState?.1.dispose()
        var inScope = true
        var inScopeResult: ((ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?)?
        selfController.searchQuerySuggestionState = (updatedSearchQuerySuggestionState, (updatedSearchQuerySuggestionSignal |> deliverOnMainQueue).startStrict(next: { [weak selfController] result in
            guard let selfController else {
                return
            }
            if Thread.isMainThread && inScope {
                inScope = false
                inScopeResult = result
            } else {
                selfController.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                    $0.updatedSearchQuerySuggestionResult { previousResult in
                        return result(previousResult)
                    }
                })
            }
        }))
        inScope = false
        if let inScopeResult = inScopeResult {
            updatedChatPresentationInterfaceState = updatedChatPresentationInterfaceState.updatedSearchQuerySuggestionResult { previousResult in
                return inScopeResult(previousResult)
            }
        }
    }
    
    var canHaveUrlPreview = true
    if case let .customChatContents(customChatContents) = updatedChatPresentationInterfaceState.subject {
        switch customChatContents.kind {
        case .hashTagSearch:
            break
        case .quickReplyMessageInput:
            break
        case .businessLinkSetup:
            canHaveUrlPreview = false
        }
    }
    
    if canHaveUrlPreview, let (updatedUrlPreviewState, updatedUrlPreviewSignal) = urlPreviewStateForInputText(updatedChatPresentationInterfaceState.interfaceState.composeInputState.inputText, context: selfController.context, currentQuery: selfController.urlPreviewQueryState?.0, forPeerId: selfController.chatLocation.peerId) {
        selfController.urlPreviewQueryState?.1.dispose()
        var inScope = true
        var inScopeResult: ((TelegramMediaWebpage?) -> (TelegramMediaWebpage, String)?)?
        let linkPreviews: Signal<Bool, NoError>
        if case let .peer(peerId) = selfController.chatLocation, peerId.namespace == Namespaces.Peer.SecretChat {
            linkPreviews = interactiveChatLinkPreviewsEnabled(accountManager: selfController.context.sharedContext.accountManager, displayAlert: { [weak selfController] f in
                guard let selfController else {
                    return
                }
                selfController.present(textAlertController(context: selfController.context, updatedPresentationData: selfController.updatedPresentationData, title: nil, text: selfController.presentationData.strings.Conversation_SecretLinkPreviewAlert, actions: [
                    TextAlertAction(type: .defaultAction, title: selfController.presentationData.strings.Common_Yes, action: {
                    f.f(true)
                }), TextAlertAction(type: .genericAction, title: selfController.presentationData.strings.Common_No, action: {
                    f.f(false)
                })]), in: .window(.root))
            })
        } else {
            var bannedEmbedLinks = false
            if let channel = selfController.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.hasBannedPermission(.banEmbedLinks) != nil {
                bannedEmbedLinks = true
            } else if let group = selfController.presentationInterfaceState.renderedPeer?.peer as? TelegramGroup, group.hasBannedPermission(.banEmbedLinks) {
                bannedEmbedLinks = true
            }
            if bannedEmbedLinks {
                linkPreviews = .single(false)
            } else {
                linkPreviews = .single(true)
            }
        }
        let filteredPreviewSignal = linkPreviews
        |> take(1)
        |> mapToSignal { value -> Signal<(TelegramMediaWebpage?) -> (TelegramMediaWebpage, String)?, NoError> in
            if value {
                return updatedUrlPreviewSignal
            } else {
                return .single({ _ in return nil })
            }
        }
        
        selfController.urlPreviewQueryState = (updatedUrlPreviewState, (filteredPreviewSignal |> deliverOnMainQueue).startStrict(next: { [weak selfController] result in
            guard let selfController else {
                return
            }
            if Thread.isMainThread && inScope {
                inScope = false
                inScopeResult = result
            } else {
                selfController.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                    if let (webpage, webpageUrl) = result($0.urlPreview?.webPage) {
                        let updatedPreview = ChatPresentationInterfaceState.UrlPreview(
                            url: webpageUrl,
                            webPage: webpage,
                            positionBelowText: $0.urlPreview?.positionBelowText ?? true,
                            largeMedia: $0.urlPreview?.largeMedia
                        )
                        return $0.updatedUrlPreview(updatedPreview)
                    } else {
                        return $0.updatedUrlPreview(nil)
                    }
                })
            }
        }))
        inScope = false
        if let inScopeResult = inScopeResult {
            if let (webpage, webpageUrl) = inScopeResult(updatedChatPresentationInterfaceState.urlPreview?.webPage) {
                let updatedPreview = ChatPresentationInterfaceState.UrlPreview(
                    url: webpageUrl,
                    webPage: webpage,
                    positionBelowText: updatedChatPresentationInterfaceState.urlPreview?.positionBelowText ?? true,
                    largeMedia: updatedChatPresentationInterfaceState.urlPreview?.largeMedia
                )
                updatedChatPresentationInterfaceState = updatedChatPresentationInterfaceState.updatedUrlPreview(updatedPreview)
            } else {
                updatedChatPresentationInterfaceState = updatedChatPresentationInterfaceState.updatedUrlPreview(nil)
            }
        }
    }
    
    let isEditingMedia: Bool = updatedChatPresentationInterfaceState.editMessageState?.content != .plaintext
    let editingUrlPreviewText: NSAttributedString? = isEditingMedia ? nil : updatedChatPresentationInterfaceState.interfaceState.editMessage?.inputState.inputText
    if let (updatedEditingUrlPreviewState, updatedEditingUrlPreviewSignal) = urlPreviewStateForInputText(editingUrlPreviewText, context: selfController.context, currentQuery: selfController.editingUrlPreviewQueryState?.0, forPeerId: selfController.chatLocation.peerId) {
        selfController.editingUrlPreviewQueryState?.1.dispose()
        var inScope = true
        var inScopeResult: ((TelegramMediaWebpage?) -> (TelegramMediaWebpage, String)?)?
        selfController.editingUrlPreviewQueryState = (updatedEditingUrlPreviewState, (updatedEditingUrlPreviewSignal |> deliverOnMainQueue).startStrict(next: { [weak selfController] result in
            guard let selfController else {
                return
            }
            if Thread.isMainThread && inScope {
                inScope = false
                inScopeResult = result
            } else {
                selfController.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                    if let (webpage, webpageUrl) = result($0.editingUrlPreview?.webPage) {
                        let updatedPreview = ChatPresentationInterfaceState.UrlPreview(
                            url: webpageUrl,
                            webPage: webpage,
                            positionBelowText: $0.editingUrlPreview?.positionBelowText ?? true,
                            largeMedia: $0.editingUrlPreview?.largeMedia
                        )
                        return $0.updatedEditingUrlPreview(updatedPreview)
                    } else {
                        return $0.updatedEditingUrlPreview(nil)
                    }
                })
            }
        }))
        inScope = false
        if let inScopeResult = inScopeResult {
            if let (webpage, webpageUrl) = inScopeResult(updatedChatPresentationInterfaceState.editingUrlPreview?.webPage) {
                let updatedPreview = ChatPresentationInterfaceState.UrlPreview(
                    url: webpageUrl,
                    webPage: webpage,
                    positionBelowText: updatedChatPresentationInterfaceState.editingUrlPreview?.positionBelowText ?? true,
                    largeMedia: updatedChatPresentationInterfaceState.editingUrlPreview?.largeMedia
                )
                updatedChatPresentationInterfaceState = updatedChatPresentationInterfaceState.updatedEditingUrlPreview(updatedPreview)
            } else {
                updatedChatPresentationInterfaceState = updatedChatPresentationInterfaceState.updatedEditingUrlPreview(nil)
            }
        }
    }
    
    if let replyMessageId = updatedChatPresentationInterfaceState.interfaceState.replyMessageSubject?.messageId {
        if selfController.replyMessageState?.0 != replyMessageId {
            selfController.replyMessageState?.1.dispose()
            updatedChatPresentationInterfaceState = updatedChatPresentationInterfaceState.updatedReplyMessage(nil)
            let disposable = MetaDisposable()
            selfController.replyMessageState = (replyMessageId, disposable)
            disposable.set((selfController.context.engine.data.subscribe(TelegramEngine.EngineData.Item.Messages.Message(id: replyMessageId))
            |> deliverOnMainQueue).start(next: { [weak selfController] message in
                guard let selfController else {
                    return
                }
                if message != selfController.presentationInterfaceState.replyMessage.flatMap(EngineMessage.init) {
                    selfController.updateChatPresentationInterfaceState(interactive: false, { presentationInterfaceState in
                        return presentationInterfaceState.updatedReplyMessage(message?._asMessage())
                    })
                }
            }))
        }
    } else {
        if let replyMessageState = selfController.replyMessageState {
            selfController.replyMessageState = nil
            replyMessageState.1.dispose()
            updatedChatPresentationInterfaceState = updatedChatPresentationInterfaceState.updatedReplyMessage(nil)
        }
    }
    
    if let updated = selfController.updateSearch(updatedChatPresentationInterfaceState) {
        updatedChatPresentationInterfaceState = updated
    }
    
    let recordingActivityValue: ChatRecordingActivity
    if let mediaRecordingState = updatedChatPresentationInterfaceState.inputTextPanelState.mediaRecordingState {
        switch mediaRecordingState {
            case .audio:
                recordingActivityValue = .voice
            case .video(ChatVideoRecordingStatus.recording, _):
                recordingActivityValue = .instantVideo
            default:
                recordingActivityValue = .none
        }
    } else {
        recordingActivityValue = .none
    }
    if recordingActivityValue != selfController.recordingActivityValue {
        selfController.recordingActivityValue = recordingActivityValue
        selfController.recordingActivityPromise.set(recordingActivityValue)
    }
    
    if (selfController.presentationInterfaceState.interfaceState.selectionState == nil) != (updatedChatPresentationInterfaceState.interfaceState.selectionState == nil) {
        selfController.isSelectingMessagesUpdated?(updatedChatPresentationInterfaceState.interfaceState.selectionState != nil)
        selfController.updateNextChannelToReadVisibility()
    }
    
    if updatedChatPresentationInterfaceState.displayHistoryFilterAsList {
        var canDisplayAsList = false
        if updatedChatPresentationInterfaceState.search != nil {
            if updatedChatPresentationInterfaceState.search?.resultsState != nil {
                canDisplayAsList = true
            }
            if updatedChatPresentationInterfaceState.historyFilter != nil {
                canDisplayAsList = true
            }
            if case .peer(selfController.context.account.peerId) = updatedChatPresentationInterfaceState.chatLocation {
                canDisplayAsList = true
            }
        }
        if selfController.alwaysShowSearchResultsAsList {
            canDisplayAsList = true
        }
        
        if !canDisplayAsList {
            updatedChatPresentationInterfaceState = updatedChatPresentationInterfaceState.updatedDisplayHistoryFilterAsList(false)
        }
    }
    
    selfController.presentationInterfaceState = updatedChatPresentationInterfaceState
    
    selfController.updateSlowmodeStatus()
    
    switch updatedChatPresentationInterfaceState.inputMode {
    case .media:
        break
    default:
        selfController.chatDisplayNode.collapseInput()
    }
    
    selfController.tempHideAccessoryPanels = selfController.presentationInterfaceState.search != nil
    
    if selfController.isNodeLoaded {
        selfController.chatDisplayNode.updateChatPresentationInterfaceState(updatedChatPresentationInterfaceState, transition: transition, interactive: interactive, completion: completion)
    } else {
        completion(.immediate)
    }
    
    let updatedServiceTasks = serviceTasksForChatPresentationIntefaceState(context: selfController.context, chatPresentationInterfaceState: updatedChatPresentationInterfaceState, updateState: { [weak selfController] f in
        guard let selfController else {
            return
        }
        selfController.updateChatPresentationInterfaceState(animated: false, interactive: false, f)
        
        //selfController.chatDisplayNode.updateChatPresentationInterfaceState(f(selfController.chatDisplayNode.chatPresentationInterfaceState), transition: transition, interactive: false, completion: { _ in })
    })
    for (id, begin) in updatedServiceTasks {
        if selfController.stateServiceTasks[id] == nil {
            selfController.stateServiceTasks[id] = begin()
        }
    }
    var removedServiceTaskIds: [AnyHashable] = []
    for (id, _) in selfController.stateServiceTasks {
        if updatedServiceTasks[id] == nil {
            removedServiceTaskIds.append(id)
        }
    }
    for id in removedServiceTaskIds {
        selfController.stateServiceTasks.removeValue(forKey: id)?.dispose()
    }
    
    if let button = leftNavigationButtonForChatInterfaceState(updatedChatPresentationInterfaceState, subject: selfController.subject, strings: updatedChatPresentationInterfaceState.strings, currentButton: selfController.leftNavigationButton, target: selfController, selector: #selector(selfController.leftNavigationButtonAction)) {
        if selfController.leftNavigationButton != button {
            var animated = transition.isAnimated
            if let currentButton = selfController.leftNavigationButton?.action, currentButton == button.action {
                animated = false
            }
            animated = false
            selfController.navigationItem.setLeftBarButton(button.buttonItem, animated: animated && selfController.currentChatSwitchDirection == nil)
            selfController.leftNavigationButton = button
        }
    } else if let _ = selfController.leftNavigationButton {
        selfController.navigationItem.setLeftBarButton(nil, animated: transition.isAnimated && selfController.currentChatSwitchDirection == nil)
        selfController.leftNavigationButton = nil
    }
    
    var buttonsAnimated = transition.isAnimated
    if let button = rightNavigationButtonForChatInterfaceState(context: selfController.context, presentationInterfaceState: updatedChatPresentationInterfaceState, strings: updatedChatPresentationInterfaceState.strings, currentButton: selfController.rightNavigationButton, target: selfController, selector: #selector(selfController.rightNavigationButtonAction), chatInfoNavigationButton: selfController.chatInfoNavigationButton, moreInfoNavigationButton: selfController.moreInfoNavigationButton) {
        if selfController.rightNavigationButton != button {
            if let currentButton = selfController.rightNavigationButton?.action, currentButton == button.action {
                buttonsAnimated = false
            }
            selfController.rightNavigationButton = button
        }
    } else if let _ = selfController.rightNavigationButton {
        selfController.rightNavigationButton = nil
    }
    
    if let button = secondaryRightNavigationButtonForChatInterfaceState(context: selfController.context, presentationInterfaceState: updatedChatPresentationInterfaceState, strings: updatedChatPresentationInterfaceState.strings, currentButton: selfController.secondaryRightNavigationButton, target: selfController, selector: #selector(selfController.secondaryRightNavigationButtonAction), chatInfoNavigationButton: selfController.chatInfoNavigationButton, moreInfoNavigationButton: selfController.moreInfoNavigationButton) {
        if selfController.secondaryRightNavigationButton != button {
            if let currentButton = selfController.secondaryRightNavigationButton?.action, currentButton == button.action {
                buttonsAnimated = false
            }
            if case .replyThread = selfController.chatLocation {
                buttonsAnimated = false
            }
            selfController.secondaryRightNavigationButton = button
        }
    } else if let _ = selfController.secondaryRightNavigationButton {
        selfController.secondaryRightNavigationButton = nil
    }
    
    var rightBarButtons: [UIBarButtonItem] = []
    if let rightNavigationButton = selfController.rightNavigationButton {
        rightBarButtons.append(rightNavigationButton.buttonItem)
    }
    if let secondaryRightNavigationButton = selfController.secondaryRightNavigationButton {
        rightBarButtons.append(secondaryRightNavigationButton.buttonItem)
    }
    var rightBarButtonsUpdated = false
    let currentRightBarButtons = selfController.navigationItem.rightBarButtonItems ?? []
    if rightBarButtons.count != currentRightBarButtons.count {
        rightBarButtonsUpdated = true
    } else {
        for i in 0 ..< rightBarButtons.count {
            if rightBarButtons[i] !== currentRightBarButtons[i] {
                rightBarButtonsUpdated = true
                break
            }
        }
    }
    if rightBarButtonsUpdated {
        selfController.navigationItem.setRightBarButtonItems(rightBarButtons, animated: buttonsAnimated)
    }
    
    if let controllerInteraction = selfController.controllerInteraction {
        if updatedChatPresentationInterfaceState.interfaceState.selectionState != controllerInteraction.selectionState {
            controllerInteraction.selectionState = updatedChatPresentationInterfaceState.interfaceState.selectionState
            let isBlackout = controllerInteraction.selectionState != nil
            let previousCompletion = completion
            completion = { [weak selfController] transition in
                previousCompletion(transition)
                
                guard let selfController else {
                    return
                }
                (selfController.navigationController as? NavigationController)?.updateMasterDetailsBlackout(isBlackout ? .master : nil, transition: transition)
            }
            selfController.updateItemNodesSelectionStates(animated: transition.isAnimated)
        }
    }
    
    if saveInterfaceState {
        selfController.saveInterfaceState(includeScrollState: false)
    }
    
    if let navigationController = selfController.navigationController as? NavigationController, isTopmostChatController(selfController) {
        var voiceChatOverlayController: VoiceChatOverlayController?
        for controller in navigationController.globalOverlayControllers {
            if let controller = controller as? VoiceChatOverlayController {
                voiceChatOverlayController = controller
                break
            }
        }
        
        if let controller = voiceChatOverlayController {
            controller.updateVisibility()
        }
    }
     
    selfController.presentationInterfaceStatePromise.set(selfController.presentationInterfaceState)
    
    if case .tag = selfController.chatDisplayNode.historyNode.tag {
    } else {
        if let historyFilter = selfController.presentationInterfaceState.historyFilter, historyFilter.isActive {
            selfController.chatDisplayNode.historyNode.updateTag(tag: .customTag(historyFilter.customTag, nil))
        } else {
            selfController.chatDisplayNode.historyNode.updateTag(tag: nil)
        }
    }
    
    selfController.updateDownButtonVisibility()
    
    if selfController.presentationInterfaceState.hasBirthdayToday {
        selfController.displayBirthdayTooltip()
    }
        
    if case .standard(.embedded) = selfController.presentationInterfaceState.mode, let controllerInteraction = selfController.controllerInteraction, let interfaceInteraction = selfController.interfaceInteraction {
        if let titleAccessoryPanelNode = titlePanelForChatPresentationInterfaceState(selfController.presentationInterfaceState, context: selfController.context, currentPanel: selfController.customNavigationPanelNode as? ChatTitleAccessoryPanelNode, controllerInteraction: controllerInteraction, interfaceInteraction: interfaceInteraction, force: true) {
            selfController.customNavigationPanelNode = titleAccessoryPanelNode as? ChatControllerCustomNavigationPanelNode
        } else {
            selfController.customNavigationPanelNode = nil
        }
    }
    
    selfController.stateUpdated?(transition)
}
