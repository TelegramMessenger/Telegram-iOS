#if canImport(UIKit)
import UIKit
@testable import RichTextEditorUIKit

@MainActor
@available(iOS 16.0, *)
final class FakeInputCommandClient: RichTextInputCommandClient {
    let log: RichTextInputEventLog
    init(log: RichTextInputEventLog) { self.log = log }

    var canPerformResult = true
    /// TASK 30 — the manager `RichTextInputCommandClient.undoManager` vends. A fresh instance per fake,
    /// so a test asserting a backend forwarded to THIS client can check identity rather than non-nil.
    var undoManager: UndoManager? = UndoManager()
    /// Set to make the NEXT `prepare` terminal (mirrors `FakeInputDocumentClient.nextPreparationRejection`).
    var nextPreparationTerminalResult: RichTextInputCommandResult? = nil
    var commitResult = RichTextInputCommandResult(
        performed: true, revision: 1, selection: .caret(at: .downstream(0)),
        contentChanged: false, selectionChanged: false)

    private(set) var canPerformCallCount = 0
    private(set) var issuedTokens: [UUID] = []
    private(set) var consumedTokens: [UUID] = []
    private(set) var sawDoubleCommit = false

    /// TASK C2 ADDITION. Every command the backend asked about via `canPerform(_:)`, in order.
    private(set) var canPerformQueries: [RichTextInputCommand] = []
    /// TASK C2 ADDITION. Every command passed to `prepare(_:sender:)`, TYPED — the shared log stores
    /// only `commandPrepare(command: String)`, a description, which cannot be pattern-matched.
    private(set) var prepared: [RichTextInputCommand] = []
    /// TASK C2 ADDITION. Every command whose PREPARED TOKEN was later passed to `commit(_:)`, TYPED,
    /// in commit order. `RichTextInputPreparedCommand` carries only a token (no command back-reference),
    /// so this is resolved through `pendingCommands`, populated at `prepare(_:sender:)` time — the
    /// brief's literal "append at the top of `commit(_:)`" cannot work as written, since `commit`'s
    /// parameter alone does not identify which command was prepared.
    private(set) var committed: [RichTextInputCommand] = []
    private var pendingCommands: [UUID: RichTextInputCommand] = [:]

    func canPerform(_ command: RichTextInputCommand, sender: Any?) -> Bool {
        canPerformQueries.append(command)
        canPerformCallCount += 1
        return canPerformResult
    }
    func prepare(_ command: RichTextInputCommand, sender: Any?) -> RichTextInputCommandPreparation {
        prepared.append(command)
        log.record(.commandPrepare(command: "\(command)"))
        if let terminal = nextPreparationTerminalResult {
            nextPreparationTerminalResult = nil
            return .terminal(terminal)
        }
        let token = UUID()
        issuedTokens.append(token)
        pendingCommands[token] = command
        return .ready(RichTextInputPreparedCommand(token: token, contentWillChange: true,
                                                   selectionWillChange: true))
    }
    func commit(_ prepared: RichTextInputPreparedCommand) -> RichTextInputCommandResult {
        log.record(.commandCommit(token: prepared.token))
        if consumedTokens.contains(prepared.token) { sawDoubleCommit = true }
        consumedTokens.append(prepared.token)
        if let command = pendingCommands[prepared.token] {
            committed.append(command)
        }
        return commitResult
    }
}
#endif
