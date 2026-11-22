import Foundation
import MessageWidget

/// The bot the conformance runner plays (widget-sandbox v0.2.1, CLIENTS.md "The message context": "the runner plays the
/// bot"), from a test's `bot` table: each request is answered by its exact data, as upstream's
/// scripts/conformance/test-bot.ts answers a widget_query. Main thread only.
public final class ConformanceMockBot {
    public struct Reply: Equatable {
        /// The answer's `result` bytes; nil for none (and for data the table lacks).
        public var result: Data?
        /// The message's state after the bot's edits, nil when it edits nothing.
        public var edit: MessageWidgetState?
        public var `repeat`: ConformanceBotAction.Repeat?
    }

    private let table: [String: ConformanceBotAction]
    private let viewer: MessageWidgetViewer
    /// `{n}`: the requests with each data so far.
    private var counts: [String: Int] = [:]

    public init(table: [String: ConformanceBotAction], viewer: MessageWidgetViewer) {
        self.table = table
        self.viewer = viewer
    }

    /// The bot's reply to a request with `data`, given the message's state `current`: an edit sets the fields it names
    /// (an unnamed one stays as it was, "" clears it: the runtime reads "" as none), and a shared edit sets the shared
    /// state. Data the table lacks gets an empty answer and no edit, as upstream's test bot does.
    public func answer(_ data: Data, current: MessageWidgetState) -> Reply {
        guard let key = String(data: data, encoding: .utf8), let action = self.table[key] else {
            return Reply(result: nil, edit: nil, repeat: nil)
        }
        let n = (self.counts[key] ?? 0) + 1
        self.counts[key] = n
        return Reply(result: action.result.map { Data(self.expand($0, n: n).utf8) }, edit: self.edited(action, current: current, n: n), repeat: action.repeat)
    }

    /// The state after `action`'s edits again (a `repeat` of them), `{n}` counting on.
    public func repeated(_ data: Data, current: MessageWidgetState) -> MessageWidgetState? {
        guard let key = String(data: data, encoding: .utf8), let action = self.table[key] else {
            return nil
        }
        let n = (self.counts[key] ?? 0) + 1
        self.counts[key] = n
        return self.edited(action, current: current, n: n)
    }

    private func edited(_ action: ConformanceBotAction, current: MessageWidgetState, n: Int) -> MessageWidgetState? {
        guard action.edit != nil || action.editShared != nil else {
            return nil
        }
        var state = current
        if let edit = action.edit {
            if let chatData = edit.chatData {
                state.chatData = Data(self.expand(chatData, n: n).utf8)
            }
            if let publicData = edit.publicData {
                state.publicData = Data(self.expand(publicData, n: n).utf8)
            }
        }
        if let shared = action.editShared {
            state.publicData = Data(self.expand(shared, n: n).utf8)
        }
        return state
    }

    private func expand(_ template: String, n: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return template
            .replacingOccurrences(of: "{n}", with: String(n))
            .replacingOccurrences(of: "{from}", with: self.viewer.firstName ?? "")
            .replacingOccurrences(of: "{time}", with: formatter.string(from: Date()))
    }
}
