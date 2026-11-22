import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import AccountContext
import ContextUI

public class ListMessageNode: ListViewItemNode {
    var item: ListMessageItem?
    var interaction: ListMessageItemInteraction?
    
    required init() {
        super.init(layerBacked: false)
    }
    
    func setupItem(_ item: ListMessageItem) {
        self.item = item
    }
    
    override public func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, neighbors: ListViewItemNeighbors) {
    }
    
    public func asyncLayout() -> (_ item: ListMessageItem, _ params: ListViewItemLayoutParams, _ mergedTop: Bool, _ mergedBottom: Bool, _ dateAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        return { _, params, _, _, _ in
            return (ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: 1.0), insets: UIEdgeInsets()), { _ in
                
            })
        }
    }
    
    public func transitionNode(id: EngineMessage.Id, media: EngineRawMedia, adjustRect: Bool) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return nil
    }
    
    public func updateHiddenMedia() {
    }
    
    public func updateSelectionState(animated: Bool) {
    }
    
    private var accessibilityMoreKey: (messageId: EngineMessage.Id, name: String)?
    
    /// VoiceOver: the row is one button reading what it shows (activation is a tap at its centre, as on screen); its
    /// long-press menu is a "More" custom action while the gesture is enabled. Called from apply; the action is rebuilt
    /// only when the message changes.
    func applyListMessageAccessibility(label: String, value: String?, item: ListMessageItem, contextSourceNode: ContextExtractedContentContainingNode, isContextMenuEnabled: Bool) {
        self.isAccessibilityElement = true
        self.accessibilityLabel = label
        self.accessibilityValue = value
        self.accessibilityTraits = item.message == nil ? .staticText : .button
        guard isContextMenuEnabled, let message = item.message else {
            self.accessibilityMoreKey = nil
            self.accessibilityCustomActions = nil
            return
        }
        let name = item.presentationData.strings.Common_More
        if let key = self.accessibilityMoreKey, key.messageId == message.id, key.name == name {
            return
        }
        self.accessibilityMoreKey = (message.id, name)
        self.accessibilityCustomActions = [UIAccessibilityCustomAction(name: name, actionHandler: { [weak self, weak contextSourceNode] _ in
            guard let self, let item = self.item, let message = item.message, let contextSourceNode else {
                return false
            }
            item.interaction.openMessageContextMenu(message, false, contextSourceNode, contextSourceNode.bounds, nil)
            return true
        })]
    }
}

/// VoiceOver: the visible texts of a row, in reading order, without empty parts.
func listMessageAccessibilityText(_ parts: [String?]) -> String {
    return parts.compactMap { part -> String? in
        guard let part = part?.trimmingCharacters(in: .whitespacesAndNewlines), !part.isEmpty else {
            return nil
        }
        return part
    }.joined(separator: ", ")
}
