import Foundation
import TelegramPresentationData
import AccountContext
import TelegramCore
import SwiftSignalKit
import PresentationDataUtils
import Display

extension ChatControllerImpl {    
    func openMessageReplies(messageId: EngineMessage.Id, displayProgressInMessage: EngineMessage.Id?, isChannelPost: Bool, atMessage atMessageId: EngineMessage.Id?, displayModalProgress: Bool) {
        guard let navigationController = self.effectiveNavigationController else {
            return
        }
        
        if let displayProgressInMessage = displayProgressInMessage, self.controllerInteraction?.currentMessageWithLoadingReplyThread == displayProgressInMessage {
            return
        }
        
        let _ = self.presentVoiceMessageDiscardAlert(action: { [weak self] in
            guard let self else {
                return
            }

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
    
    // `progress` is the tapped link's inline progress (the shimmer on the link text). When it is given it replaces
    // the modal `OverlayStatusController` while the thread is fetched, so a topic link in a message never puts a
    // spinner over the whole chat; `displayModalProgress` is then ignored. Callers without a link to shimmer
    // (peer info, instant view) keep passing nil and get the modal as before.
    static func openMessageReplies(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, navigationController: NavigationController, present: @escaping (ViewController, Any?) -> Void, messageId: EngineMessage.Id, isChannelPost: Bool, atMessage atMessageId: EngineMessage.Id?, displayModalProgress: Bool, progress: Promise<Bool>? = nil) -> Signal<Never, NoError> {
        return Signal { subscriber in
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }

            var cancelImpl: (() -> Void)?
            let statusController = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                cancelImpl?()
            }))

            let inlineProgressDisposable = MetaDisposable()
            if let progress {
                inlineProgressDisposable.set(startInlineLinkProgress(progress))
            } else if displayModalProgress {
                present(statusController, nil)
            }

            let disposable = (fetchAndPreloadReplyThreadInfo(context: context, subject: isChannelPost ? .channelPost(messageId) : .groupMessage(messageId), atMessageId: atMessageId, preload: true)
            |> deliverOnMainQueue).startStrict(next: { [weak statusController] result in
                inlineProgressDisposable.dispose()
                if progress == nil && displayModalProgress {
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
            }, error: { [weak statusController] _ in
                inlineProgressDisposable.dispose()
                if progress == nil && displayModalProgress {
                    statusController?.dismiss()
                }
                let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
                present(textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Channel_DiscussionMessageUnavailable, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
            })

            cancelImpl = { [weak statusController] in
                disposable.dispose()
                inlineProgressDisposable.dispose()
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

// Arms a tapped link's inline progress and returns the disposable that clears it. The URL resolver
// (`openUserGeneratedUrl`) clears the same promise with a `Queue.mainQueue().async` right before it hands over the
// resolved URL, so re-arming synchronously would be undone by that pending hop; the delay puts this after it and
// also avoids a blink when the thread is local and resolves immediately. Same shape as the `.join` case in
// `openResolvedUrlImpl`.
func startInlineLinkProgress(_ progress: Promise<Bool>) -> Disposable {
    let progressSignal = Signal<Never, NoError> { _ in
        progress.set(.single(true))
        return ActionDisposable {
            Queue.mainQueue().async {
                progress.set(.single(false))
            }
        }
    }
    |> runOn(Queue.mainQueue())
    |> delay(0.1, queue: Queue.mainQueue())
    return progressSignal.startStrict()
}
