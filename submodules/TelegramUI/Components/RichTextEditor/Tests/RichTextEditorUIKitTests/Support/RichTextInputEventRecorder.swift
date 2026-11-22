#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit

enum RichTextInputRecordedEventKind: String, Equatable {
    case textWillChange, selectionWillChange, selectionDidChange, textDidChange
    case canvasContentSizeChanged, canvasSelectionChanged
    case canvasBecameFirstResponder, canvasResignedFirstResponder
    case facadeOnChange, facadeBecameFirstResponder, facadeResignedFirstResponder
}

struct RichTextInputRecordedEvent: Equatable {
    let ordinal: Int
    let kind: RichTextInputRecordedEventKind
    let revision: UInt64
    let layoutGeneration: UInt64
    let anchor: Int
    let head: Int
    let markedRange: NSRange?
    let undoRegistrationCount: Int
    let deliveredAsynchronously: Bool
}

/// One recorder is simultaneously the `UITextInputDelegate` AND the wrapper for the four canvas
/// hooks and the three facade hooks. Because all of those are synchronous main-thread closures, a
/// single shared ordinal yields a TOTAL order across delegate and facade events — the thing no
/// existing test can express. The one asynchronous producer is
/// `RichTextEditorView.scheduleSelectionDrivenOnChange()` (RichTextEditorView.swift:725-733), so
/// events carry `deliveredAsynchronously` and `drainMainQueue` flushes it.
@available(iOS 16.0, *)
final class RichTextInputEventRecorder: NSObject, UITextInputDelegate {
    private(set) var events: [RichTextInputRecordedEvent] = []
    var kinds: [RichTextInputRecordedEventKind] { events.map(\.kind) }

    private weak var canvas: DocumentCanvasView?
    private var ordinal = 0
    private var isDrainingAsync = false

    // Chained-through originals. `simulateParentLayout()` overwrites `onContentSizeChange` and 18
    // test files depend on it, so the recorder must re-invoke whatever was installed before it.
    private var chainedContentSize: (() -> Void)?
    private var chainedSelection: (() -> Void)?
    private var chainedBecameFR: (() -> Void)?
    private var chainedResignedFR: (() -> Void)?
    private var chainedFacadeChange: (() -> Void)?
    private var chainedFacadeBecameFR: (() -> Void)?
    private var chainedFacadeResignedFR: (() -> Void)?

    func attach(canvas: DocumentCanvasView) {
        self.canvas = canvas
        canvas.inputDelegate = self
        chainedContentSize = canvas.onContentSizeChange
        chainedSelection = canvas.onSelectionChange
        chainedBecameFR = canvas.onBecameFirstResponder
        chainedResignedFR = canvas.onResignedFirstResponder
        canvas.onContentSizeChange = { [weak self] in
            self?.record(.canvasContentSizeChanged); self?.chainedContentSize?()
        }
        canvas.onSelectionChange = { [weak self] in
            self?.record(.canvasSelectionChanged); self?.chainedSelection?()
        }
        canvas.onBecameFirstResponder = { [weak self] in
            self?.record(.canvasBecameFirstResponder); self?.chainedBecameFR?()
        }
        canvas.onResignedFirstResponder = { [weak self] in
            self?.record(.canvasResignedFirstResponder); self?.chainedResignedFR?()
        }
    }

    func attach(facade: RichTextEditorView) {
        if canvas == nil { canvas = facade.canvas }
        chainedFacadeChange = facade.onChange
        chainedFacadeBecameFR = facade.onBecameFirstResponder
        chainedFacadeResignedFR = facade.onResignedFirstResponder
        facade.onChange = { [weak self] in
            self?.record(.facadeOnChange); self?.chainedFacadeChange?()
        }
        facade.onBecameFirstResponder = { [weak self] in
            self?.record(.facadeBecameFirstResponder); self?.chainedFacadeBecameFR?()
        }
        facade.onResignedFirstResponder = { [weak self] in
            self?.record(.facadeResignedFirstResponder); self?.chainedFacadeResignedFR?()
        }
    }

    func reset() { events.removeAll(); ordinal = 0 }

    /// Flushes the facade's coalesced `onChange` (a trailing `DispatchQueue.main.async`).
    /// Events recorded during the drain are flagged `deliveredAsynchronously`.
    func drainMainQueue(_ testCase: XCTestCase, timeout: TimeInterval = 1.0) {
        isDrainingAsync = true
        let expectation = testCase.expectation(description: "main queue drained")
        DispatchQueue.main.async { expectation.fulfill() }
        testCase.wait(for: [expectation], timeout: timeout)
        isDrainingAsync = false
    }

    /// Human-readable rendering used by golden-trace failure messages.
    func trace() -> String {
        events.map { e in
            "\(e.ordinal). \(e.kind.rawValue) rev=\(e.revision) sel=(\(e.anchor),\(e.head))"
                + (e.markedRange.map { " marked=\($0.location),\($0.length)" } ?? "")
                + (e.deliveredAsynchronously ? " [async]" : "")
        }.joined(separator: "\n")
    }

    private func record(_ kind: RichTextInputRecordedEventKind) {
        let c = canvas
        // `c` is Optional and `markedRange` is itself `(from: Int, to: Int)?`
        // (DocumentCanvasView.swift:465), so `c?.markedRange.map { … }` would be NSRange?? — which
        // does not type-check against the NSRange? parameter below. Flatten first.
        let marked = (c?.markedRange ?? nil).map { NSRange(location: $0.from, length: $0.to - $0.from) }
        events.append(RichTextInputRecordedEvent(
            ordinal: ordinal,
            kind: kind,
            revision: c?.documentRevision ?? 0,
            layoutGeneration: c?.layoutGeneration ?? 0,
            anchor: c?.anchor ?? -1,
            head: c?.head ?? -1,
            markedRange: marked,
            undoRegistrationCount: c?.undoRegistrationCount ?? -1,
            deliveredAsynchronously: isDrainingAsync))
        ordinal += 1
    }

    // MARK: UITextInputDelegate

    func textWillChange(_ ti: UITextInput?) { record(.textWillChange) }
    func textDidChange(_ ti: UITextInput?) { record(.textDidChange) }
    func selectionWillChange(_ ti: UITextInput?) { record(.selectionWillChange) }
    func selectionDidChange(_ ti: UITextInput?) { record(.selectionDidChange) }
    @available(iOS 18.4, *)
    func conversationContext(_ context: UIConversationContext?, didChange ti: UITextInput?) {}
}
#endif
