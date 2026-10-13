import Foundation
import UIKit
import Display
import ContextUI
import TelegramPresentationData
import RichTextEditorCore
import RichTextEditorUIKit
import TelegramCore

/// Presents the editor's table row/column structural menu as a Telegram `ContextController`, anchored to
/// the tapped handle described by `request`. Shared by both editor hosts (the chat composer and the
/// attachment screen); they differ only in HOW the built controller is presented, injected via `present`.
/// This is the ONE place that maps the editor's framework-agnostic `TableStructuralMenuRequest` to ContextUI.
@available(iOS 13.0, *)
public func presentTableStructuralMenu(
    _ request: TableStructuralMenuRequest,
    presentationData: PresentationData,
    present: (ViewController) -> Void
) {
    guard let anchorView = request.view else { return }
    // A transient zero-interaction anchor at the handle's rect (in the canvas's coordinate space); the
    // reference source converts it to window space. Removed when the controller is dismissed.
    let anchor = UIView(frame: request.sourceRect)
    anchor.isUserInteractionEnabled = false
    anchorView.addSubview(anchor)

    // The top "attributes" group (alignment + header) applies to the selected cells directly, as opposed
    // to the Add/Delete structural actions below. Built up front so the separator logic stays coherent
    // regardless of which of the two (if either) is present.
    var attributeItems: [ContextMenuItem] = []
    if let alignment = request.alignment {
        attributeItems.append(.custom(TableStructuralMenuAlignmentItem(
            initialHorizontal: alignment.horizontal.map(tableHAlign(fromCore:)),
            initialVertical: alignment.vertical.map(tableVAlign(fromCore:)),
            action: { h, v in
                alignment.apply(h.map(coreHAlign(from:)), v.map(coreVAlign(from:)))
            }), false))
    }

    var items: [ContextMenuItem] = attributeItems
    if !attributeItems.isEmpty && (!request.actions.isEmpty || request.header != nil) {
        items.append(.separator)
    }
    if let header = request.header {
        items.append(.action(ContextMenuActionItem(
            text: header.isHeader == true ? presentationData.strings.RichText_Menu_Table_HighlightOff : presentationData.strings.RichText_Menu_Table_HighlightOn,
            icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: header.isHeader == true ? "Chat/Context Menu/CellHighlightRemove" : "Chat/Context Menu/CellHighlightAdd"), color: theme.contextMenu.primaryColor)
            },
            action: { _, f in f(.default); header.apply() }
        )))
    }
    items.append(contentsOf: request.actions.map { action in
        let (title, icon) = tableStructuralMenuTitleAndIcon(action.kind, strings: presentationData.strings)
        return .action(ContextMenuActionItem(
            text: title,
            textColor: tableStructuralMenuIsDestructive(action.kind) ? .destructive : .primary,
            icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: icon), color: tableStructuralMenuIsDestructive(action.kind) ? theme.contextMenu.destructiveColor : theme.contextMenu.primaryColor)
            },
            action: { _, f in f(.default); action.perform() }
        ))
    })

    let controller = makeContextController(
        presentationData: presentationData,
        source: .reference(RichTextStructuralMenuReferenceSource(sourceView: anchor)),
        items: .single(ContextController.Items(content: .list(items))),
        gesture: nil
    )
    controller.dismissed = { [weak anchor] in anchor?.removeFromSuperview() }
    present(controller)
}

private func tableStructuralMenuTitleAndIcon(_ kind: TableStructuralMenuRequest.Kind, strings: PresentationStrings) -> (title: String, icon: String) {
    switch kind {
    case .addColumnLeft: return (strings.RichText_Menu_Table_AddColumnLeft, "Chat/Context Menu/CellAddLeft")
    case .addColumnRight: return (strings.RichText_Menu_Table_AddColumnRight, "Chat/Context Menu/CellAddRight")
    case .deleteColumn: return (strings.RichText_Menu_Table_DeleteColumn, "Chat/Context Menu/CellDelete")
    case .addRowAbove: return (strings.RichText_Menu_Table_AddRowAbove, "Chat/Context Menu/CellAddTop")
    case .addRowBelow: return (strings.RichText_Menu_Table_AddRowBelow, "Chat/Context Menu/CellAddBottom")
    case .deleteRow: return (strings.RichText_Menu_Table_DeleteRow, "Chat/Context Menu/CellDelete")
    case .mergeCells: return (strings.RichText_Menu_Table_MergeCells, "Chat/Context Menu/CellMergeH")
    case .splitCell: return (strings.RichText_Menu_Table_SplitCell, "Chat/Context Menu/CellSplitH")
    }
}

private func tableStructuralMenuIsDestructive(_ kind: TableStructuralMenuRequest.Kind) -> Bool {
    switch kind {
    case .deleteColumn, .deleteRow: return true
    default: return false
    }
}

private func tableHAlign(fromCore a: TextAlignment) -> TableHorizontalAlignment {
    switch a { case .left, .natural, .justified: return .left; case .center: return .center; case .right: return .right }
}
private func coreHAlign(from a: TableHorizontalAlignment) -> TextAlignment {
    switch a { case .left: return .left; case .center: return .center; case .right: return .right }
}
private func tableVAlign(fromCore a: VerticalAlignment) -> TableVerticalAlignment {
    switch a { case .top: return .top; case .middle: return .middle; case .bottom: return .bottom }
}
private func coreVAlign(from a: TableVerticalAlignment) -> VerticalAlignment {
    switch a { case .top: return .top; case .middle: return .middle; case .bottom: return .bottom }
}

/// Anchors a `ContextController` to a sub-rect view (the transient handle anchor). Mirrors the attachment
/// screen's `RichTextActionContextReferenceSource`, generalized to any anchor view.
@available(iOS 13.0, *)
private final class RichTextStructuralMenuReferenceSource: ContextReferenceContentSource {
    private let sourceView: UIView
    init(sourceView: UIView) { self.sourceView = sourceView }
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView,
            contentAreaInScreenSpace: UIScreen.main.bounds,
            insets: UIEdgeInsets(top: -4.0, left: 0.0, bottom: -4.0, right: 0.0), actionsPosition: .bottom)
    }
}
