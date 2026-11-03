#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// A framework-agnostic description of the table row/column structural menu the editor wants shown.
/// The editor hands this to its host (via `RichTextEditorView.onRequestTableStructuralMenu`); the host
/// presents its own menu (a Telegram `ContextController`) however it sees fit. The editor owns WHAT the
/// menu contains (adapted to the table state); the host owns HOW it is presented (title strings, icons,
/// styling, coordinate conversion). References only UIKit + Core — never ContextUI/Display.
@available(iOS 13.0, *)
public final class TableStructuralMenuRequest {
    /// The view whose coordinate space `sourceRect` is expressed in — the editor's canvas. Weak so the
    /// host does not retain editor internals past presentation.
    public weak var view: UIView?
    /// The tapped handle's rect in `view` coordinates — the anchor the host presents the menu from.
    public let sourceRect: CGRect
    /// Add/Delete actions, already adapted to the table state (header row → no Add-Above/Delete;
    /// all-columns range → no Delete Column). Ordered for display.
    public let actions: [Action]
    /// The alignment control for the selected cells (present for both row and column selections): the
    /// data is carried now, the host renders it as a custom control (deferred).
    public let alignment: Alignment?
    /// The header/highlight toggle for the selected cells (present for both row and column selections).
    public let header: Header?

    public init(view: UIView?, sourceRect: CGRect, actions: [Action], alignment: Alignment?, header: Header?) {
        self.view = view
        self.sourceRect = sourceRect
        self.actions = actions
        self.alignment = alignment
        self.header = header
    }

    /// One menu action. `kind` is a stable semantic identity from which the host derives the (localizable)
    /// title, destructive styling, and icon — no presentation state is carried here. `perform` runs the
    /// edit AND clears the structural selection.
    public struct Action {
        public let kind: Kind
        public let perform: () -> Void
        public init(kind: Kind, perform: @escaping () -> Void) {
            self.kind = kind
            self.perform = perform
        }
    }

    public enum Kind: Equatable {
        case addColumnLeft, addColumnRight, deleteColumn
        case addRowAbove, addRowBelow, deleteRow
        /// Merge the `.cells` selection's covered cells into one spanning cell (offered when the
        /// selection covers ≥2 anchors); split a single merged cell back into a dense grid (offered
        /// when the selection resolves to exactly one already-merged anchor). Phase 2c.
        case mergeCells, splitCell
    }

    /// The alignment control for the selected cells: the uniform current value per axis (nil = the selected
    /// cells disagree, "mixed"), and `apply` to set one or both axes on all selected cells (a nil argument
    /// leaves that axis unchanged). Present for both row and column selections.
    public struct Alignment {
        public let horizontal: TextAlignment?
        public let vertical: VerticalAlignment?
        public let apply: (TextAlignment?, VerticalAlignment?) -> Void
        public init(horizontal: TextAlignment?, vertical: VerticalAlignment?, apply: @escaping (TextAlignment?, VerticalAlignment?) -> Void) {
            self.horizontal = horizontal
            self.vertical = vertical
            self.apply = apply
        }
    }

    /// The header/highlight toggle for the selected cells: the uniform current value (nil = the cells
    /// disagree, "mixed"/indeterminate), and `apply` to toggle every selected cell. Present for both
    /// row and column selections.
    public struct Header {
        public let isHeader: Bool?
        public let apply: () -> Void
        public init(isHeader: Bool?, apply: @escaping () -> Void) {
            self.isHeader = isHeader
            self.apply = apply
        }
    }
}
#endif
