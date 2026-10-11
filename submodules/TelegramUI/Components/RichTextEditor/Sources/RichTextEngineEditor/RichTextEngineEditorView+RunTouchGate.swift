#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
import RichTextInputDecUpstream

/// A tap that CATCHES a moving table presses nothing.
///
/// Stopping a scroll view with a finger is not a tap on its content — every scroll view in iOS
/// swallows that touch — and a placed run cannot do it for itself: it never receives the touch, so
/// `touchesShouldBegin:withEvent:inContentView:` is never called on it either (the same gap that
/// made the run unable to catch its own deceleration). The host's chrome inside a run therefore has
/// to refuse the touch on the run's behalf: the button pills, the formula tap targets and the
/// table's own structural grips and knobs.
///
/// **At touch-DOWN, not at touch-up.** A tap fires on release, by which time the catching finger has
/// lifted and the run has been released — so a gate asked at that moment sees a settled run and lets
/// the press through, which is the defect rather than the fix. `shouldReceiveTouch:` is asked as the
/// recogniser is offered the touch, which is the same moment the run decides whether it is being
/// caught.
@available(iOS 18.4, *)
internal final class EngineRunTouchGate: NSObject, UIGestureRecognizerDelegate {
    private weak var editor: RichTextEngineEditorView?

    internal init(editor: RichTextEngineEditorView) {
        self.editor = editor
    }

    internal func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                    shouldReceive touch: UITouch) -> Bool {
        guard let editor, let view = gestureRecognizer.view else { return true }
        // Answers NO for a view that is in no run at all — a list marker, a details chevron, a
        // top-level pill — so attaching this to every host recogniser costs those nothing.
        return !editor.engine.id_isPlacedRunInFlight(for: view)
    }
}

@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    /// The recogniser a host-drawn control inside the engine gets: its action, and the run gate.
    ///
    /// Every interactive overlay this editor owns goes through here, so "a tap that catches a moving
    /// run does nothing" is one decision rather than a habit each site has to remember. A control
    /// outside every run is unaffected, so there is no judgement to make at the call site about
    /// whether this one can end up inside a table.
    internal func gatedTapRecognizer(action: Selector) -> UITapGestureRecognizer {
        let recognizer = UITapGestureRecognizer(target: self, action: action)
        recognizer.delegate = runTouchGate
        return recognizer
    }

    /// Is the run holding the table whose first role is `index` in flight?
    ///
    /// The structural chrome is parented to the ENGINE rather than into the run — the row grip would
    /// otherwise ride the table's horizontal scroll out of the gutter — so walking up from a grip
    /// finds no run and the per-view question cannot answer for it. Its table's own content view
    /// can: that view IS inside the run.
    internal func placedRunIsInFlight(forTableAt index: Int) -> Bool {
        guard let content = engine.id_placedRunContentViewForBlock(at: UInt(index)) else { return false }
        return engine.id_isPlacedRunInFlight(for: content)
    }
}

/// Decides whether the editor's knob pan begins, and remembers WHICH knob it grabbed.
///
/// The knob's drag cannot live on the knob's own view: a view that takes the touch takes the tap
/// with it, and a 44pt box over an 87x34 cell leaves almost nowhere to tap (measured: 77% of the
/// focused cell). So the pan sits on the EDITOR, where it competes for the gesture without owning
/// the touch — the tap still reaches the text interaction, exactly as it does in body text — and
/// this decides at `began` whether the finger started on a knob at all.
@available(iOS 18.4, *)
internal final class EngineTableKnobPanGate: NSObject, UIGestureRecognizerDelegate {
    private weak var editor: RichTextEngineEditorView?
    /// Captured once, at the start of the gesture. A drag must not JUMP knobs mid-flight, which is
    /// what re-resolving the knob under the finger each frame would do.
    internal private(set) var grabbed: (end: TableRangeEnd?, corner: TableCellCorner?)?

    internal init(editor: RichTextEngineEditorView) {
        self.editor = editor
    }

    internal func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let editor, let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
        grabbed = nil
        guard let (table, roles) = editor.structurallyChromedTable(),
              let chrome = editor.tableStructuralChromeViews[table.id] else { return false }
        // A moving run is being CAUGHT, and the catch owns the finger — the same rule the chrome's
        // own hit-testing follows.
        guard !editor.placedRunIsInFlight(forTableAt: roles.lowerBound) else { return false }
        guard let knob = chrome.knob(at: pan.location(in: chrome)) else { return false }
        grabbed = knob
        return true
    }
}

@available(iOS 18.4, *)
extension RichTextEngineEditorView {
    @objc internal func handleTableKnobPan(_ recognizer: UIPanGestureRecognizer) {
        guard let knob = tableKnobPanGate.grabbed else { return }
        dragTableStructuralKnob(recognizer, end: knob.end, corner: knob.corner)
    }
}

#endif

