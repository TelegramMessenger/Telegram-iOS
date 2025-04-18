import Foundation
import TelegramPresentationData
import AccountContext
import Display
import SwiftSignalKit
import TelegramCore
import Postbox
import UIKit
import OverlayStatusController
import PresentationDataUtils

extension ChatControllerImpl {    
    func scrollToEndOfHistory() {
        let locationInput = ChatHistoryLocationInput(content: .Scroll(subject: MessageHistoryScrollToSubject(index: .upperBound, quote: nil), anchorIndex: .upperBound, sourceIndex: .lowerBound, scrollPosition: .top(0.0), animated: true, highlight: false, setupReply: false), id: 0)
        
        let historyView = preloadedChatHistoryViewForLocation(locationInput, context: self.context, chatLocation: self.chatLocation, subject: self.subject, chatLocationContextHolder: self.chatLocationContextHolder, fixedCombinedReadStates: nil, tag: nil, additionalData: [])
        let signal = historyView
        |> mapToSignal { historyView -> Signal<(MessageIndex?, Bool), NoError> in
            switch historyView {
            case .Loading:
                return .single((nil, true))
            case .HistoryView:
                return .single((nil, false))
            }
        }
        |> take(until: { index in
            return SignalTakeAction(passthrough: true, complete: !index.1)
        })
        
        var cancelImpl: (() -> Void)?
        let presentationData = self.presentationData
        let displayTime = CACurrentMediaTime()
        let progressSignal = Signal<Never, NoError> { [weak self] subscriber in
            let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                if CACurrentMediaTime() - displayTime > 1.5 {
                    cancelImpl?()
                }
            }))
            self?.present(controller, in: .window(.root))
            return ActionDisposable { [weak controller] in
                Queue.mainQueue().async() {
                    controller?.dismiss()
                }
            }
        }
        |> runOn(Queue.mainQueue())
        |> delay(0.05, queue: Queue.mainQueue())
        let progressDisposable = MetaDisposable()
        var progressStarted = false
        self.messageIndexDisposable.set((signal
        |> afterDisposed {
            Queue.mainQueue().async {
                progressDisposable.dispose()
            }
        }
        |> deliverOnMainQueue).startStrict(next: { index in
            if index.1 {
                if !progressStarted {
                    progressStarted = true
                    progressDisposable.set(progressSignal.startStrict())
                }
            }
        }, completed: { [weak self] in
            if let strongSelf = self {
                strongSelf.loadingMessage.set(.single(nil))
                strongSelf.chatDisplayNode.historyNode.scrollToEndOfHistory()
            }
        }))
        cancelImpl = { [weak self] in
            if let strongSelf = self {
                strongSelf.loadingMessage.set(.single(nil))
                strongSelf.messageIndexDisposable.set(nil)
            }
        }
    }
    
    func scrollToStartOfHistory() {
        let locationInput = ChatHistoryLocationInput(content: .Scroll(subject: MessageHistoryScrollToSubject(index: .lowerBound, quote: nil), anchorIndex: .lowerBound, sourceIndex: .upperBound, scrollPosition: .bottom(0.0), animated: true, highlight: false, setupReply: false), id: 0)
        
        let historyView = preloadedChatHistoryViewForLocation(locationInput, context: self.context, chatLocation: self.chatLocation, subject: self.subject, chatLocationContextHolder: self.chatLocationContextHolder, fixedCombinedReadStates: nil, tag: nil, additionalData: [])
        let signal = historyView
        |> mapToSignal { historyView -> Signal<(MessageIndex?, Bool), NoError> in
            switch historyView {
            case .Loading:
                return .single((nil, true))
            case .HistoryView:
                return .single((nil, false))
            }
        }
        |> take(until: { index in
            return SignalTakeAction(passthrough: true, complete: !index.1)
        })
        
        var cancelImpl: (() -> Void)?
        let presentationData = self.presentationData
        let displayTime = CACurrentMediaTime()
        let progressSignal = Signal<Never, NoError> { [weak self] subscriber in
            let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                if CACurrentMediaTime() - displayTime > 1.5 {
                    cancelImpl?()
                }
            }))
            self?.present(controller, in: .window(.root))
            return ActionDisposable { [weak controller] in
                Queue.mainQueue().async() {
                    controller?.dismiss()
                }
            }
        }
        |> runOn(Queue.mainQueue())
        |> delay(0.05, queue: Queue.mainQueue())
        let progressDisposable = MetaDisposable()
        var progressStarted = false
        self.messageIndexDisposable.set((signal
        |> afterDisposed {
            Queue.mainQueue().async {
                progressDisposable.dispose()
            }
        }
        |> deliverOnMainQueue).startStrict(next: { index in
            if index.1 {
                if !progressStarted {
                    progressStarted = true
                    progressDisposable.set(progressSignal.startStrict())
                }
            }
        }, completed: { [weak self] in
            if let strongSelf = self {
                strongSelf.loadingMessage.set(.single(nil))
                strongSelf.chatDisplayNode.historyNode.scrollToStartOfHistory()
            }
        }))
        cancelImpl = { [weak self] in
            if let strongSelf = self {
                strongSelf.loadingMessage.set(.single(nil))
                strongSelf.messageIndexDisposable.set(nil)
            }
        }
    }
}
