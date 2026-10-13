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

    func canPerform(_ command: RichTextInputCommand, sender: Any?) -> Bool {
        canPerformCallCount += 1
        return canPerformResult
    }
    func prepare(_ command: RichTextInputCommand, sender: Any?) -> RichTextInputCommandPreparation {
        log.record(.commandPrepare(command: "\(command)"))
        if let terminal = nextPreparationTerminalResult {
            nextPreparationTerminalResult = nil
            return .terminal(terminal)
        }
        let token = UUID()
        issuedTokens.append(token)
        return .ready(RichTextInputPreparedCommand(token: token, contentWillChange: true,
                                                   selectionWillChange: true))
    }
    func commit(_ prepared: RichTextInputPreparedCommand) -> RichTextInputCommandResult {
        log.record(.commandCommit(token: prepared.token))
        if consumedTokens.contains(prepared.token) { sawDoubleCommit = true }
        consumedTokens.append(prepared.token)
        return commitResult
    }
}
#endif
