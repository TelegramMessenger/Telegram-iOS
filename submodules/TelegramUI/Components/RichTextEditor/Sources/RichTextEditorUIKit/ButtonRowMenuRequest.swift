#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// The editor asking its host to present a button-row menu (alignment + delete). Mirrors
/// `TableStructuralMenuRequest`: the editor owns WHAT the menu offers, the host owns HOW it is
/// presented — titles, icons, styling. References only UIKit + Core, never ContextUI/Display.
@available(iOS 13.0, *)
public final class ButtonRowMenuRequest {
    /// The view `sourceRect` is expressed in — the editor's canvas. Weak so the host does not retain
    /// editor internals past presentation.
    public weak var view: UIView?
    /// The row's rect in `view` coordinates, for menu anchoring.
    public let sourceRect: CGRect
    /// The row's current alignment, so the host can show which is selected.
    public let alignment: ButtonRowAlignment
    /// Appends a pill to the row (one undo step) and asks the host to edit it straight away, so a new
    /// button is never left blank.
    public let addButton: () -> Void
    /// Applies a new alignment as one undo step.
    public let setAlignment: (ButtonRowAlignment) -> Void
    /// Removes the whole row as one undo step.
    public let deleteRow: () -> Void

    public init(view: UIView?, sourceRect: CGRect, alignment: ButtonRowAlignment,
                addButton: @escaping () -> Void,
                setAlignment: @escaping (ButtonRowAlignment) -> Void, deleteRow: @escaping () -> Void) {
        self.view = view
        self.sourceRect = sourceRect
        self.alignment = alignment
        self.addButton = addButton
        self.setAlignment = setAlignment
        self.deleteRow = deleteRow
    }
}
#endif
