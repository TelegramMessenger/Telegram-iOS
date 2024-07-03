import Foundation
import TelegramPresentationData
import AccountContext
import Postbox
import TelegramCore
import SwiftSignalKit
import PresentationDataUtils
import Display

extension ChatControllerImpl {    
    func openMessageReplies(messageId: MessageId, displayProgressInMessage: MessageId?, isChannelPost: Bool, atMessage atMessageId: MessageId?, displayModalProgress: Bool) {
        guard let navigationController = self.effectiveNavigationController else {
            return
        }
        
        if let displayProgressInMessage = displayProgressInMessage, self.controllerInteraction?.currentMessageWithLoadingReplyThread == displayProgressInMessage {
            return
        }
        
        let _ = self.presentVoiceMessageDiscardAlert(action: {
            let progressSignal: Signal<Never, NoError> = Signal { [weak self] _ in
                guard let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction else {
                    return EmptyDisposable
                }
                
                if let displayProgressInMessage = displayProgressInMessage, controllerInteraction.currentMessageWithLoadingReplyThread != displayProgressInMessage {
                    let previousId = controllerInteraction.currentMessageWithLoadingReplyThread
                    controllerInteraction.currentMessageWithLoadingReplyThread = displayProgressInMessage
                    strongSelf.chatDisplayNode.historyNode.requestMessageUpdate(displayProgressInMessage)
                    if let previousId = previousId {
                        strongSelf.chatDisplayNode.historyNode.requestMessageUpdate(previousId)
                    }
                }
                
                return ActionDisposable {
                    Queue.mainQueue().async {
                        guard let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction else {
                            return
                        }
                        if let displayProgressInMessage = displayProgressInMessage, controllerInteraction.currentMessageWithLoadingReplyThread == displayProgressInMessage {
                            controllerInteraction.currentMessageWithLoadingReplyThread = nil
                            strongSelf.chatDisplayNode.historyNode.requestMessageUpdate(displayProgressInMessage)
                        }
                    }
                }
            }
            |> runOn(.mainQueue())
            
            let progress = (progressSignal
            |> delay(0.15, queue: .mainQueue())).startStrict()
            
            self.navigationActionDisposable.set((ChatControllerImpl.openMessageReplies(context: self.context, updatedPresentationData: self.updatedPresentationData, navigationController: navigationController, present: { [weak self] c, a in
                self?.present(c, in: .window(.root), with: a)
            }, messageId: messageId, isChannelPost: isChannelPost, atMessage: atMessageId, displayModalProgress: displayModalProgress)
            |> afterDisposed {
                progress.dispose()
            }).startStrict())
        })
    }
    
    static func openMessageReplies(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, navigationController: NavigationController, present: @escaping (ViewController, Any?) -> Void, messageId: MessageId, isChannelPost: Bool, atMessage atMessageId: MessageId?, displayModalProgress: Bool) -> Signal<Never, NoError> {
        return Signal { subscriber in
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            var cancelImpl: (() -> Void)?
            let statusController = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                cancelImpl?()
            }))
            
            if displayModalProgress {
                present(statusController, nil)
            }
            
            let disposable = (fetchAndPreloadReplyThreadInfo(context: context, subject: isChannelPost ? .channelPost(messageId) : .groupMessage(messageId), atMessageId: atMessageId, preload: true)
            |> deliverOnMainQueue).startStrict(next: { [weak statusController] result in
                if displayModalProgress {
                    statusController?.dismiss()
                }
                
                let chatLocation: NavigateToChatControllerParams.Location = .replyThread(result.message)
                
                let subject: ChatControllerSubject?
                if let atMessageId = atMessageId {
                    subject = .message(id: .id(atMessageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false)
                } else if let index = result.scrollToLowerBoundMessage {
                    subject = .message(id: .id(index.id), highlight: nil, timecode: nil, setupReply: false)
                } else {
                    subject = nil
                }
                
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: chatLocation, chatLocationContextHolder: result.contextHolder, subject: subject, activateInput: result.isEmpty ? .text : nil, keepStack: .always))
                subscriber.putCompletion()
            }, error: { _ in
                let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
                present(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Channel_DiscussionMessageUnavailable, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
            })
            
            cancelImpl = { [weak statusController] in
                disposable.dispose()
                statusController?.dismiss()
                subscriber.putCompletion()
            }
            
            return ActionDisposable {
                cancelImpl?()
            }
        }
        |> runOn(.mainQueue())
    }
}
