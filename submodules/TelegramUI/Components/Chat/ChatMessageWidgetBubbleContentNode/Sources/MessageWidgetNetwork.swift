import Foundation
import SwiftSignalKit
import TelegramCore
import AccountContext
import MessageWidget

/// The bubble's two network paths for a widget (widget-sandbox v0.2, W2; design §4.A): its queries to the bot and the
/// polling of a shared widget's state. Both go only to Telegram's server through the engine; the widget harness replaces
/// them in its tests. Main thread only.
public enum MessageWidgetNetwork {
    /// A query to the bot of the message `messageId`: a request the widget's gate admitted (`.data`, with the wallet when
    /// it asked for it), or a wallet call's outcome (v0.5.0); the answer's `result`, or why there is none.
    public static var requestAnswer: (AccountContext, EngineMessage.Id, BotWidgetQueryType, Data) -> Signal<Data?, BotWidgetQueryError> = { context, messageId, queryType, data in
        return context.engine.messages.requestBotWidgetQueryAnswer(messageId: messageId, queryType: queryType, data: data)
    }
    /// Polls the shared state of the widget `widgetId` while subscribed, with `messageId` as a carrier.
    public static var pollPublicData: (AccountContext, EngineMessage.Id, Int64) -> Signal<Never, NoError> = { context, messageId, widgetId in
        return context.engine.messages.pollWidgetPublicData(messageId: messageId, widgetId: widgetId)
    }
}

/// The requests a bubble's widget has on their way to its bot (W2), each on a disposable of its own, by its id, until its
/// outcome is delivered (once: the engine's guard gives every request one). `cancelAll()` when the bubble shows another
/// message (its widget is destroyed then); releasing it cancels them too. Main thread only.
public final class MessageWidgetRequests {
    private var disposables = DisposableDict<Int64>()

    public init() {
    }

    deinit {
        self.disposables.dispose()
    }

    /// Sends the request `id` and hands its outcome to `deliver` on the main queue.
    public func send(id: Int64, _ signal: Signal<Data?, BotWidgetQueryError>, deliver: @escaping (MessageWidgetRequestOutcome) -> Void) {
        let disposables = self.disposables
        disposables.set((signal |> deliverOnMainQueue).startStrict(next: { result in
            deliver(.answered(result))
        }, error: { error in
            deliver(messageWidgetRequestOutcome(error))
            disposables.set(nil, forKey: id)
        }, completed: {
            disposables.set(nil, forKey: id)
        }), forKey: id)
    }

    /// Cancels every request in flight; later ones are sent as usual.
    public func cancelAll() {
        self.disposables.dispose()
        self.disposables = DisposableDict<Int64>()
    }
}

/// What the widget's promise rejects with for `error` (sdk-v1 §5.11).
func messageWidgetRequestOutcome(_ error: BotWidgetQueryError) -> MessageWidgetRequestOutcome {
    switch error {
    case .timeout:
        return .timeout
    case .rateLimited:
        return .rateLimited
    case .failed:
        return .failed
    }
}
