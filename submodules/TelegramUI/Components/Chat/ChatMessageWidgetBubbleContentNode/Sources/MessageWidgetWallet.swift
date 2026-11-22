import Foundation
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import PresentationDataUtils
import WalletContext
import MessageWidget

/// A message widget's wallet calls (widget-sandbox v0.5.0, sdk-v1 §2.18, §5.13; the user's decisions of 2026-10-30):
/// the client's TON Connect window over the chat, the message's bot in its header; a confirmed transaction is sent
/// through the wallet's own transfer path (`wallet.sendTransfer`), a confirmed signature made for `bot<bot_id>`; then the
/// bot gets the outcome as a widget query with the call's `data`, and the widget the bot's answer.
public enum MessageWidgetWallet {
    /// What the wallet did with a confirmed call, with the wallet the bot's query carries: a transaction the server
    /// accepted (its message hash as the server returned it), or a signature (TON Connect's result as JSON).
    public enum Outcome: Equatable {
        case sent(msgHash: String, wallet: EngineUserWallet)
        case signed(json: String, wallet: EngineUserWallet)
    }

    /// A wallet call to perform: the window with `bot` in its header, presented over the chat by `present` (false when
    /// there is no chat to present it over any more).
    public struct Request {
        public let context: AccountContext
        public let bot: EnginePeer
        public let call: MessageWidgetWalletCall
        public let present: (ViewController) -> Bool

        public init(context: AccountContext, bot: EnginePeer, call: MessageWidgetWalletCall, present: @escaping (ViewController) -> Bool) {
            self.context = context
            self.bot = bot
            self.call = call
            self.present = present
        }
    }

    /// Shows the window and, confirmed, sends or signs; calls `completion` once, on main, with what the wallet did or
    /// why not. The widget harness replaces it with a mock wallet.
    public static var perform: (Request, @escaping (Result<Outcome, WalletContext.WidgetWalletFailure>) -> Void) -> Void = { request, completion in
        MessageWidgetWalletWindow.perform(request, completion: completion)
    }
}

/// The bot of a widget's message, the one that asks (sdk-v1 §5.13: never anything the widget says about itself): the
/// bot it was sent via, else its author if a bot, else the original author of a forward if a bot.
func messageWidgetBot(_ message: EngineMessage) -> EnginePeer? {
    func bot(_ peer: EnginePeer?) -> EnginePeer? {
        if case let .user(user)? = peer, user.botInfo != nil {
            return peer
        }
        return nil
    }
    for attribute in message.attributes {
        if let attribute = attribute as? InlineBotMessageAttribute, let peerId = attribute.peerId, let peer = bot(message.peers[peerId].flatMap(EnginePeer.init)) {
            return peer
        }
    }
    return bot(message.author) ?? bot(message.forwardInfo?.author.flatMap(EnginePeer.init))
}

/// The bubbles' wallet calls, held outside any bubble: a payment that went out must reach the bot even when the bubble
/// shows another message or the chat closes, so the bot's query is never cancelled with them; an answer that comes back
/// after the widget went reaches nothing (the instance ignores it). One wallet window at a time in the app: a call while
/// one is up is declined. Main thread only.
final class MessageWidgetWalletCalls {
    static let shared = MessageWidgetWalletCalls()

    private var windowIsUp = false
    private let queries = DisposableSet()

    /// `perform`: the wallet's part (`MessageWidgetWallet.perform` bound to the request); `query`: the bot's query
    /// (`MessageWidgetNetwork.requestAnswer` bound to the message). `completion` once, on main.
    func handle(
        call: MessageWidgetWalletCall,
        hasBot: Bool,
        perform: (@escaping (Result<MessageWidgetWallet.Outcome, WalletContext.WidgetWalletFailure>) -> Void) -> Void,
        query: @escaping (BotWidgetQueryType, Data) -> Signal<Data?, BotWidgetQueryError>,
        completion: @escaping (MessageWidgetRequestOutcome) -> Void
    ) {
        guard hasBot else {
            completion(.failed)
            return
        }
        guard !self.windowIsUp else {
            completion(.rejected)
            return
        }
        self.windowIsUp = true
        perform { [weak self] result in
            guard let self else {
                return
            }
            self.windowIsUp = false
            switch result {
            case let .failure(failure):
                completion(messageWidgetWalletOutcome(failure))
            case let .success(outcome):
                let queryType: BotWidgetQueryType
                switch outcome {
                case let .sent(msgHash, wallet):
                    queryType = .sentTransaction(wallet: wallet, msgHash: msgHash)
                case let .signed(json, wallet):
                    queryType = .signData(wallet: wallet, json: json)
                }
                let disposable = MetaDisposable()
                self.queries.add(disposable)
                let finished: () -> Void = { [weak self] in
                    self?.queries.remove(disposable)
                    disposable.dispose()
                }
                disposable.set((query(queryType, call.data) |> deliverOnMainQueue).startStrict(next: { result in
                    completion(.answered(result))
                }, error: { error in
                    completion(messageWidgetRequestOutcome(error))
                    finished()
                }, completed: {
                    finished()
                }))
            }
        }
    }
}

/// A wallet window's hold on its call (the final review's #1). The window keeps it: released any way but through the
/// window's own buttons (an account switch, a navigation stack replaced), it ends a call the window had not ended, as
/// declined, which frees the one-window flag and the widget's gate. Once the confirmation has begun it ends nothing:
/// the send's or the signature's own outcome does, so a payment in flight is never reported as declined.
final class MessageWidgetWalletWindowLifetime {
    private let end: () -> Void
    private var isConfirming = false

    init(end: @escaping () -> Void) {
        self.end = end
    }

    deinit {
        guard !self.isConfirming else {
            return
        }
        if Thread.isMainThread {
            self.end()
        } else {
            DispatchQueue.main.async(execute: self.end)
        }
    }

    func beginConfirmation() {
        self.isConfirming = true
    }
}

private var walletWindowLifetimeKey: UInt8 = 0

extension MessageWidgetWalletWindowLifetime {
    /// Builds the window with its Confirm hook and attaches the lifetime to it, its only strong hold. The hook begins the
    /// confirmation and answers true while the window lives; false means the call already ended, and Confirm sends nothing.
    static func attach<Window: AnyObject>(end: @escaping () -> Void, to makeWindow: (_ beginConfirmation: @escaping () -> Bool) -> Window) -> Window {
        let lifetime = MessageWidgetWalletWindowLifetime(end: end)
        let window = makeWindow({ [weak lifetime] in
            guard let lifetime else {
                return false
            }
            lifetime.beginConfirmation()
            return true
        })
        objc_setAssociatedObject(window, &walletWindowLifetimeKey, lifetime, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return window
    }
}

/// What the widget's promise rejects with for the wallet's failure (sdk-v1 §2.18): a short balance is the wallet's
/// refusal, BAD_REQUEST, once the client has offered the top-up.
func messageWidgetWalletOutcome(_ failure: WalletContext.WidgetWalletFailure) -> MessageWidgetRequestOutcome {
    switch failure {
    case .rejected:
        return .rejected
    case .badRequest, .insufficientBalance:
        return .badRequest
    case .failed:
        return .failed
    }
}

/// The real wallet: prepares the call (no window when the wallet refuses it; for a short balance, the top-up offered
/// instead), shows the TON Connect window over the chat with the bot, and sends or signs on the confirmation.
enum MessageWidgetWalletWindow {
    /// sdk-v1 §5.13: the second tap of a double tap over the widget must not land on Confirm (0.5–1 s). Counted from the
    /// push: the sheet slides in for about 0.22 s (measured on the iOS 27 simulator), so 0.8 s keeps it untouchable for
    /// about 0.58 s once it is in place (upstream's dev app, with no slide-in, keeps its buttons off for 600 ms).
    static let ignoresTouchesFor: Double = 0.8

    private final class WeakController {
        weak var value: ViewController?
    }

    /// sdk-v1 §5.13, "if the wallet is empty, offer the top-up over the chat before sending": the wallet's alert for a
    /// short balance, as an NFT transfer's; Top Up opens the wallet's receive screen over the chat. The call has ended by
    /// then, so the user pays with a new tap once the Grams arrive.
    static func offerTopUp(_ request: MessageWidgetWallet.Request, walletContext: WalletContext) {
        let strings = request.context.sharedContext.currentPresentationData.with { $0 }.strings
        let alert = textAlertController(context: request.context, title: strings.Wallet_Backup_InsufficientFundsTitle, text: strings.Wallet_Transfer_TopUpText, actions: [
            TextAlertAction(type: .genericAction, title: strings.Common_Cancel, action: {}),
            TextAlertAction(type: .defaultAction, title: strings.Wallet_Backup_TopUp, action: {
                guard case let .wallet(info) = walletContext.stateValue.phase else {
                    return
                }
                let _ = request.present(request.context.sharedContext.makeWalletReceiveScreen(context: request.context, address: info.address))
            })
        ])
        request.context.sharedContext.presentGlobalController(alert, nil)
    }

    static func perform(_ request: MessageWidgetWallet.Request, completion: @escaping (Result<MessageWidgetWallet.Outcome, WalletContext.WidgetWalletFailure>) -> Void) {
        guard let walletContext = request.context.walletContext, case let .user(user) = request.bot else {
            completion(.failure(.failed))
            return
        }
        var completed = false
        let finish: (Result<MessageWidgetWallet.Outcome, WalletContext.WidgetWalletFailure>) -> Void = { result in
            guard !completed else {
                return
            }
            completed = true
            completion(result)
        }
        let requester = WalletContext.WidgetWalletRequester(botId: user.id.id._internalGetInt64Value(), name: request.bot.compactDisplayTitle, username: user.addressName)
        let window = WeakController()
        // A short balance, before the window or after it, ends the call with the top-up offered over the chat (§5.13).
        let fail: (WalletContext.WidgetWalletFailure) -> Void = { failure in
            if failure == .insufficientBalance {
                MessageWidgetWalletWindow.offerTopUp(request, walletContext: walletContext)
            }
            finish(.failure(failure))
        }
        // A failure after the confirmation closes the window first, so it shows no alert of its own: the widget says what
        // happened, and a new tap starts again.
        let failAfterConfirmation: (WalletContext.WidgetWalletFailure, @escaping (Result<Void, WalletContext.WalletError>) -> Void) -> Void = { failure, result in
            window.value?.dismiss()
            result(.failure(.unavailable))
            fail(failure)
        }
        switch request.call {
        case let .sendTransaction(json, _):
            let _ = (walletContext.prepareWidgetTransaction(json: json, requester: requester)
            |> deliverOnMainQueue).start(next: { prepared in
                let screen = MessageWidgetWalletWindowLifetime.attach(end: {
                    walletContext.discardWidgetTransaction(prepared)
                    finish(.failure(.rejected))
                }, to: { beginConfirmation in
                    return request.context.sharedContext.makeWalletTransferScreen(context: request.context, walletContext: walletContext, request: prepared.request, requester: request.bot, ignoresTouchesFor: MessageWidgetWalletWindow.ignoresTouchesFor, cancelled: {
                        walletContext.discardWidgetTransaction(prepared)
                        finish(.failure(.rejected))
                    }, confirm: { result in
                        guard beginConfirmation() else {
                            result(.failure(.unavailable))
                            return
                        }
                        let _ = (walletContext.submitWidgetTransaction(prepared)
                        |> deliverOnMainQueue).start(next: { sent in
                            result(.success(()))
                            finish(.success(.sent(msgHash: sent.msgHash, wallet: sent.wallet)))
                        }, error: { failure in
                            failAfterConfirmation(failure, result)
                        })
                    })
                })
                window.value = screen
                if !request.present(screen) {
                    walletContext.discardWidgetTransaction(prepared)
                    finish(.failure(.failed))
                }
            }, error: { failure in
                fail(failure)
            })
        case let .signData(json, _):
            let _ = (walletContext.prepareWidgetSignData(json: json, requester: requester)
            |> deliverOnMainQueue).start(next: { prepared in
                let screen = MessageWidgetWalletWindowLifetime.attach(end: {
                    finish(.failure(.rejected))
                }, to: { beginConfirmation in
                    return request.context.sharedContext.makeWalletTransferScreen(context: request.context, walletContext: walletContext, request: prepared.request, requester: request.bot, ignoresTouchesFor: MessageWidgetWalletWindow.ignoresTouchesFor, cancelled: {
                        finish(.failure(.rejected))
                    }, confirm: { result in
                        guard beginConfirmation() else {
                            result(.failure(.unavailable))
                            return
                        }
                        let _ = (walletContext.signWidgetData(prepared)
                        |> deliverOnMainQueue).start(next: { signed in
                            result(.success(()))
                            finish(.success(.signed(json: signed.responseJson, wallet: signed.wallet)))
                        }, error: { failure in
                            failAfterConfirmation(failure, result)
                        })
                    })
                })
                window.value = screen
                if !request.present(screen) {
                    finish(.failure(.failed))
                }
            }, error: { failure in
                fail(failure)
            })
        }
    }
}
