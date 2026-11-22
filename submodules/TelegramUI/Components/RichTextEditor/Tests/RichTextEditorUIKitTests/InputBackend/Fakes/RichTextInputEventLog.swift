#if canImport(UIKit)
import Foundation
@testable import RichTextEditorUIKit

/// One monotonically ordered record of everything that crossed a boundary during a test. ALL fakes
/// hold the SAME instance, so a test asserts one flat [Event] and thereby pins cross-client
/// ordering — which per-fake counters (the pre-existing InputDelegateSpy at
/// T/MarkedTextTests.swift:7 holds four counters and no order) structurally cannot.
final class RichTextInputEventLog {
    enum Event: Equatable, CustomStringConvertible {
        case documentPrepare(mutation: String, expectedRevision: UInt64)
        case documentCommit(token: UUID)
        case documentRebase(offset: Int, fromRevision: UInt64)
        case documentRead(kind: String, range: NSRange)
        case delegateTextWillChange, delegateSelectionWillChange
        case delegateSelectionDidChange, delegateTextDidChange
        case lifecycleDidAttach, lifecycleWillDetach
        case lifecycleWillBeginEditing(allowed: Bool), lifecycleDidBeginEditing
        case lifecycleShouldEndEditing(allowed: Bool), lifecycleDidEndEditing
        case lifecyclePublish(revision: UInt64, reason: String)
        case lifecycleReject(mutation: String, reason: String)
        case lifecycleRequiresLayout(range: NSRange?, reason: String)
        case presentationApply(revision: UInt64, caretIsNil: Bool, segmentCount: Int)
        case presentationInvalidate(raw: UInt)
        case presentationReveal(target: String, animated: Bool)
        case presentationDismissEditMenu(reason: String)
        case presentationTearDown
        case annotationAdd(range: NSRange, revision: UInt64)
        case annotationRemove(range: NSRange, revision: UInt64)
        case geometryQuery(kind: String, revision: UInt64, purpose: String)
        case commandPrepare(command: String), commandCommit(token: UUID)
        case contractViolation(String)
        case interactionCancelled(reason: String), interactionsInstalled, interactionsRemoved

        /// DEVIATION FROM THE TASK BRIEF'S VERBATIM STEP 1 TEXT — a real bug, not a design choice.
        /// The brief's literal code was `var description: String { "\(self)" }`. `Event` conforms to
        /// `CustomStringConvertible`, so interpolating `self` resolves to `self.description` again —
        /// unconditional infinite recursion, a guaranteed stack overflow the instant ANYTHING calls
        /// `description` (which `kinds`, used by every downstream contract suite, does on every
        /// event). Confirmed by running it: `xcodebuild test -only-testing:…FakeClientSelfTests` hard
        /// crashed with "Crash: xctest at RichTextInputEventLog.Event.description.getter" (captured in
        /// the .xcresult; the test process restarted mid-suite with no assertion ever printed). Fixed
        /// with an explicit per-case switch — same case names/types/no case reordered, only the
        /// `description` body differs from the brief's text. `kinds`' prefix-before-"(" parsing is
        /// unaffected: every payload case still emits "caseName(" and every payload-less case emits a
        /// bare "caseName" with no "(" at all.
        var description: String {
            switch self {
            case .documentPrepare(let mutation, let expectedRevision):
                return "documentPrepare(mutation: \(mutation), expectedRevision: \(expectedRevision))"
            case .documentCommit(let token):
                return "documentCommit(token: \(token))"
            case .documentRebase(let offset, let fromRevision):
                return "documentRebase(offset: \(offset), fromRevision: \(fromRevision))"
            case .documentRead(let kind, let range):
                return "documentRead(kind: \(kind), range: \(String(describing: range)))"
            case .delegateTextWillChange:
                return "delegateTextWillChange"
            case .delegateSelectionWillChange:
                return "delegateSelectionWillChange"
            case .delegateSelectionDidChange:
                return "delegateSelectionDidChange"
            case .delegateTextDidChange:
                return "delegateTextDidChange"
            case .lifecycleDidAttach:
                return "lifecycleDidAttach"
            case .lifecycleWillDetach:
                return "lifecycleWillDetach"
            case .lifecycleWillBeginEditing(let allowed):
                return "lifecycleWillBeginEditing(allowed: \(allowed))"
            case .lifecycleDidBeginEditing:
                return "lifecycleDidBeginEditing"
            case .lifecycleShouldEndEditing(let allowed):
                return "lifecycleShouldEndEditing(allowed: \(allowed))"
            case .lifecycleDidEndEditing:
                return "lifecycleDidEndEditing"
            case .lifecyclePublish(let revision, let reason):
                return "lifecyclePublish(revision: \(revision), reason: \(reason))"
            case .lifecycleReject(let mutation, let reason):
                return "lifecycleReject(mutation: \(mutation), reason: \(reason))"
            case .lifecycleRequiresLayout(let range, let reason):
                return "lifecycleRequiresLayout(range: \(String(describing: range)), reason: \(reason))"
            case .presentationApply(let revision, let caretIsNil, let segmentCount):
                return "presentationApply(revision: \(revision), caretIsNil: \(caretIsNil), segmentCount: \(segmentCount))"
            case .presentationInvalidate(let raw):
                return "presentationInvalidate(raw: \(raw))"
            case .presentationReveal(let target, let animated):
                return "presentationReveal(target: \(target), animated: \(animated))"
            case .presentationDismissEditMenu(let reason):
                return "presentationDismissEditMenu(reason: \(reason))"
            case .presentationTearDown:
                return "presentationTearDown"
            case .annotationAdd(let range, let revision):
                return "annotationAdd(range: \(range), revision: \(revision))"
            case .annotationRemove(let range, let revision):
                return "annotationRemove(range: \(range), revision: \(revision))"
            case .geometryQuery(let kind, let revision, let purpose):
                return "geometryQuery(kind: \(kind), revision: \(revision), purpose: \(purpose))"
            case .commandPrepare(let command):
                return "commandPrepare(command: \(command))"
            case .commandCommit(let token):
                return "commandCommit(token: \(token))"
            case .contractViolation(let message):
                return "contractViolation(\(message))"
            case .interactionCancelled(let reason):
                return "interactionCancelled(reason: \(reason))"
            case .interactionsInstalled:
                return "interactionsInstalled"
            case .interactionsRemoved:
                return "interactionsRemoved"
            }
        }
    }

    private(set) var events: [Event] = []
    func record(_ e: Event) { events.append(e) }
    func reset() { events.removeAll() }

    /// Coarse projection used by most assertions: the case name only, arguments dropped.
    var kinds: [String] {
        events.map { String(describing: $0).prefix { $0 != "(" }.description }
    }
    func index(of kind: String) -> Int? { kinds.firstIndex(of: kind) }
    func count(_ kind: String) -> Int { kinds.filter { $0 == kind }.count }
    func contains(_ kind: String) -> Bool { index(of: kind) != nil }
}
#endif
