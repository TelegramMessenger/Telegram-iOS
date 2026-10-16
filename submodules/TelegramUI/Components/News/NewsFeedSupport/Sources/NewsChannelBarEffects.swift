import Foundation

/// The toasts the channel bar shows after the user's own actions (spec §1.5), with the mockup's icons.
public enum NewsChannelToast: Equatable, CaseIterable {
    case addedToNews
    case addedToChats
    case removedFromNews
    case removedFromChats
    case notificationsOn
    case notificationsOff
    case archived
    case unarchived

    public var iconName: String {
        switch self {
        case .addedToNews:
            return "News/Channel/ToastNews"
        case .addedToChats:
            return "News/Channel/ToastChats"
        case .removedFromNews:
            return "News/Channel/ToastNewsCrossed"
        case .removedFromChats:
            return "News/Channel/ToastChatsCrossed"
        case .notificationsOn:
            return NewsChannelMenuItem.notify.iconName
        case .notificationsOff:
            return NewsChannelMenuItem.doNotNotify.iconName
        case .archived:
            return NewsChannelMenuItem.archive.iconName
        case .unarchived:
            return NewsChannelMenuItem.unarchive.iconName
        }
    }

    /// Only the deferred leave can be undone.
    public var hasUndo: Bool {
        return self == .removedFromChats
    }

    /// 5 s for the deferred leave (the chat list's delete-with-undo); the app's default otherwise.
    public var timeout: Double? {
        return self.hasUndo ? 5.0 : nil
    }
}

/// A request that waits for its toast (spec §1.4): performed once, on the first `commit`, unless `cancel` (Undo) came
/// first. The toast's timeout, a newer toast and the bar's teardown all commit, so this is what keeps the leave to one.
public final class NewsDeferredAction {
    public enum State: Equatable {
        case pending
        case performing
        case done
        case cancelled
    }

    public private(set) var state: State = .pending
    private let perform: (@escaping () -> Void) -> Void
    private var completions: [() -> Void] = []

    /// `perform` starts the request and calls its argument once the request has ended.
    public init(perform: @escaping (@escaping () -> Void) -> Void) {
        self.perform = perform
    }

    /// Starts the request if it is still pending. `completion` runs once the request has ended, at once if it already
    /// has. A cancelled action does nothing and drops `completion`.
    public func commit(completion: (() -> Void)? = nil) {
        switch self.state {
        case .cancelled:
            return
        case .done:
            completion?()
        case .performing:
            if let completion {
                self.completions.append(completion)
            }
        case .pending:
            self.state = .performing
            if let completion {
                self.completions.append(completion)
            }
            // Strong: the request keeps the action alive until it ends, so the completions run even after the bar and
            // the toast have let go of it. `perform` does not keep this closure, so there is no cycle.
            self.perform {
                self.state = .done
                let completions = self.completions
                self.completions = []
                for completion in completions {
                    completion()
                }
            }
        }
    }

    /// Undo: cancels the action if it has not been committed. Returns false once it has.
    @discardableResult
    public func cancel() -> Bool {
        guard self.state == .pending else {
            return false
        }
        self.state = .cancelled
        return true
    }
}
