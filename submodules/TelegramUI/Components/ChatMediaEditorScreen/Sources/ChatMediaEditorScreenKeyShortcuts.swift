import Foundation
import UIKit
import Display

extension ChatMediaEditorScreen: KeyShortcutResponder {
    public var keyShortcuts: [KeyShortcut] {
        guard self.isNodeLoaded, let layout = self.node.validLayout else {
            return []
        }
        let node = self.node
        guard chatMediaEditorReturnFocusesCaption(
            hasCaptionPanel: node.captionPanelView != nil,
            hasFirstResponder: UIResponder.currentFirst() != nil,
            toolbarSide: node.toolbarSide(layout: layout),
            isToolActive: node.activeTool != nil,
            isSending: node.isSending,
            isDismissing: self.isDismissing
        ) else {
            return []
        }
        let strings = self.context.sharedContext.currentPresentationData.with { $0 }.strings
        return [
            KeyShortcut(title: strings.MediaPicker_AddCaption, input: "\r", action: { [weak self] in
                self?.node.activateCaptionInput()
            })
        ]
    }
}
