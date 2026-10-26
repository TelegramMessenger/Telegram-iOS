import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import ContextUI

/// Everything a template row's long-press preview needs, bundled by
/// `SupportTemplateRowItemNode` at long-press time (`containerNode.activated`) and consumed
/// both by `SupportTemplatePreviewContextItem` below (the read-only preview block) and by
/// `SupportTemplatesController.swift`'s `showTemplatePreviewImpl` (the action list under it).
struct SupportTemplatePreviewPayload {
    let title: String
    let value: SupportTemplateValue
    let keys: [String]
    /// "Use Template" / "View Details" / "Edit" - which one depends on the mode/tab that
    /// produced this row, so it's supplied by the entry-building code in
    /// `SupportTemplatesController.swift`, not decided here.
    let primaryActionTitle: String
    /// Mirrors the row's own tap `action` exactly (same closure) so the menu entry does
    /// precisely what tapping the row would have done.
    let primaryAction: () -> Void
    /// Non-nil only for Mine-tab rows - adds a destructive "Delete" entry below the primary
    /// action, reusing the same callback already wired for swipe-to-delete (no confirmation
    /// dialog; see `SupportTemplatesController.swift`'s `deleteUserTemplate` for the
    /// established rationale).
    let deleteAction: (() -> Void)?
}

/// Full Value text for the long-press preview. Unlike `supportTemplateValuePreview` (which
/// truncates `.text` to one 60-char line for list rows), `.text` is shown here in full;
/// `.contact` has no "fuller" form than its existing one-line "👤 name" rendering, so that's
/// reused as-is (per the owner's ask - no need for multi-line there).
private func supportTemplatePreviewValueText(_ value: SupportTemplateValue) -> String {
    switch value {
    case let .text(text):
        return text
    case .contact:
        return supportTemplateValuePreview(value)
    }
}

/// Non-interactive context-menu content showing a template's FULL Question/Value/Keys -
/// list rows truncate all of these to one line each for density, so a long-press ("like 3D
/// touch", per the owner) is the only way to read a long template without opening Detail.
/// Modeled directly on `SectionTitleContextItem` (the established minimal custom-item
/// precedent in this codebase), with `ImmediateTextNode`s since this is a one-shot layout,
/// not a reusable list row.
final class SupportTemplatePreviewContextItem: ContextMenuCustomItem {
    let payload: SupportTemplatePreviewPayload

    init(payload: SupportTemplatePreviewPayload) {
        self.payload = payload
    }

    func node(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) -> ContextMenuCustomNode {
        return SupportTemplatePreviewContextItemNode(presentationData: presentationData, payload: self.payload)
    }
}

private final class SupportTemplatePreviewContextItemNode: ASDisplayNode, ContextMenuCustomNode {
    private var presentationData: PresentationData
    private let payload: SupportTemplatePreviewPayload

    private let questionNode: ImmediateTextNode
    private let valueNode: ImmediateTextNode
    private let keysNode: ImmediateTextNode?

    var needsSeparator: Bool {
        return true
    }

    var needsPadding: Bool {
        // This node manages its own top/bottom insets (see `updateLayout`); the system's
        // default extra padding (reserved for plain action rows) would double up with them.
        return false
    }

    init(presentationData: PresentationData, payload: SupportTemplatePreviewPayload) {
        self.presentationData = presentationData
        self.payload = payload

        let questionFont = Font.bold(presentationData.listsFontSize.baseDisplaySize)
        let valueFont = Font.regular(presentationData.listsFontSize.baseDisplaySize)
        let keysFont = Font.regular(floor(presentationData.listsFontSize.baseDisplaySize * 14.0 / 17.0))

        self.questionNode = ImmediateTextNode()
        self.questionNode.maximumNumberOfLines = 6
        self.questionNode.isUserInteractionEnabled = false
        self.questionNode.displaysAsynchronously = false
        self.questionNode.attributedText = NSAttributedString(string: payload.title, font: questionFont, textColor: presentationData.theme.contextMenu.primaryColor)

        self.valueNode = ImmediateTextNode()
        if case .contact = payload.value {
            self.valueNode.maximumNumberOfLines = 1
        } else {
            self.valueNode.maximumNumberOfLines = 10
        }
        self.valueNode.isUserInteractionEnabled = false
        self.valueNode.displaysAsynchronously = false
        self.valueNode.attributedText = NSAttributedString(string: supportTemplatePreviewValueText(payload.value), font: valueFont, textColor: presentationData.theme.contextMenu.primaryColor)

        if !payload.keys.isEmpty {
            let keysNode = ImmediateTextNode()
            keysNode.maximumNumberOfLines = 1
            keysNode.truncationType = .end
            keysNode.isUserInteractionEnabled = false
            keysNode.displaysAsynchronously = false
            // Reuses the Detail screen's existing "Keys" label rather than adding a new
            // string just for this prefix.
            keysNode.attributedText = NSAttributedString(string: "\(presentationData.strings.SupportTemplates_DetailKeysLabel): \(payload.keys.joined(separator: ", "))", font: keysFont, textColor: presentationData.theme.contextMenu.secondaryColor)
            self.keysNode = keysNode
        } else {
            self.keysNode = nil
        }

        super.init()

        self.addSubnode(self.questionNode)
        self.addSubnode(self.valueNode)
        if let keysNode = self.keysNode {
            self.addSubnode(keysNode)
        }
    }

    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let sideInset: CGFloat = 16.0
        let topInset: CGFloat = 10.0
        let bottomInset: CGFloat = 10.0
        let spacing: CGFloat = 6.0
        // No internal scrolling - the maximumNumberOfLines caps set in `init` are what keep
        // this within a reasonable height; there is no further height-based clipping here.
        let maxTextWidth = max(1.0, constrainedWidth - sideInset * 2.0)

        let questionSize = self.questionNode.updateLayout(CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude))
        let valueSize = self.valueNode.updateLayout(CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude))
        let keysSize = self.keysNode?.updateLayout(CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude)) ?? CGSize()

        var height = topInset + questionSize.height + spacing + valueSize.height + bottomInset
        if self.keysNode != nil {
            height += spacing + keysSize.height
        }

        let size = CGSize(width: constrainedWidth, height: height)
        return (size, { [weak self] _, transition in
            guard let strongSelf = self else {
                return
            }
            var originY = topInset
            transition.updateFrame(node: strongSelf.questionNode, frame: CGRect(origin: CGPoint(x: sideInset, y: originY), size: questionSize))
            originY += questionSize.height + spacing
            transition.updateFrame(node: strongSelf.valueNode, frame: CGRect(origin: CGPoint(x: sideInset, y: originY), size: valueSize))
            originY += valueSize.height
            if let keysNode = strongSelf.keysNode {
                originY += spacing
                transition.updateFrame(node: keysNode, frame: CGRect(origin: CGPoint(x: sideInset, y: originY), size: keysSize))
            }
        })
    }

    func updateTheme(presentationData: PresentationData) {
        self.presentationData = presentationData

        let questionFont = Font.bold(presentationData.listsFontSize.baseDisplaySize)
        let valueFont = Font.regular(presentationData.listsFontSize.baseDisplaySize)
        let keysFont = Font.regular(floor(presentationData.listsFontSize.baseDisplaySize * 14.0 / 17.0))

        self.questionNode.attributedText = NSAttributedString(string: self.questionNode.attributedText?.string ?? "", font: questionFont, textColor: presentationData.theme.contextMenu.primaryColor)
        self.valueNode.attributedText = NSAttributedString(string: self.valueNode.attributedText?.string ?? "", font: valueFont, textColor: presentationData.theme.contextMenu.primaryColor)
        if let keysNode = self.keysNode {
            keysNode.attributedText = NSAttributedString(string: keysNode.attributedText?.string ?? "", font: keysFont, textColor: presentationData.theme.contextMenu.secondaryColor)
        }
    }

    func canBeHighlighted() -> Bool {
        return false
    }

    func updateIsHighlighted(isHighlighted: Bool) {
    }

    func performAction() {
    }
}
