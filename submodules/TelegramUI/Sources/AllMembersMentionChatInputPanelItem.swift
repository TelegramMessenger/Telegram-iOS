import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI

struct AllMembersMentionSuggestion: Equatable {
    let memberCount: Int
    let isEnabled: Bool
}

/// A genuine input-context list row, not a synthetic user/peer.
final class AllMembersMentionChatInputPanelItem: ListViewItem {
    var neighborDescriptor: AnyEquatable { return .noNeighborInfluence }
    let presentationData: ItemListPresentationData
    let suggestion: AllMembersMentionSuggestion
    let action: () -> Void
    var selectable: Bool { return self.suggestion.isEnabled }

    init(presentationData: ItemListPresentationData, suggestion: AllMembersMentionSuggestion, action: @escaping () -> Void) {
        self.presentationData = presentationData
        self.suggestion = suggestion
        self.action = action
    }

    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = AllMembersMentionChatInputPanelItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, neighbors.next != nil)
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            Queue.mainQueue().async {
                completion(node, { return (nil, { _ in apply() }) })
            }
        }
    }

    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            guard let node = node() as? AllMembersMentionChatInputPanelItemNode else { return }
            let makeLayout = node.asyncLayout()
            async {
                let (layout, apply) = makeLayout(self, params, neighbors.next != nil)
                Queue.mainQueue().async {
                    completion(layout, { _ in apply() })
                }
            }
        }
    }

    func selected(listView: ListView) {
        if self.suggestion.isEnabled { self.action() }
    }
}

private final class AllMembersMentionChatInputPanelItemNode: ListViewItemNode {
    private let iconBackgroundNode = ASDisplayNode()
    private let iconTextNode = TextNode()
    private let titleNode = TextNode()
    private let subtitleNode = TextNode()
    private let separatorNode = ASDisplayNode()
    private let highlightedBackgroundNode = ASDisplayNode()
    private let activateAreaNode = AccessibilityAreaNode()

    init() {
        super.init(layerBacked: false)
        self.iconBackgroundNode.isLayerBacked = true
        self.iconBackgroundNode.cornerRadius = 15.0
        self.separatorNode.isLayerBacked = true
        self.highlightedBackgroundNode.isLayerBacked = true
        self.highlightedBackgroundNode.alpha = 0.0
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.iconBackgroundNode)
        self.addSubnode(self.iconTextNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.activateAreaNode)
    }

    func asyncLayout() -> (AllMembersMentionChatInputPanelItem, ListViewItemLayoutParams, Bool) -> (ListViewItemNodeLayout, () -> Void) {
        let makeIconLayout = TextNode.asyncLayout(self.iconTextNode)
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeSubtitleLayout = TextNode.asyncLayout(self.subtitleNode)
        return { [weak self] item, params, hasNext in
            let theme = item.presentationData.theme
            let strings = item.presentationData.strings
            let title = strings.AllMention_SuggestionTitle
            let subtitle = strings.Conversation_StatusMembers(Int32(clamping: item.suggestion.memberCount))
            let accentColor = item.suggestion.isEnabled ? theme.list.itemAccentColor : theme.list.itemSecondaryTextColor
            let leftInset = params.leftInset + 55.0
            let fontScale = item.presentationData.fontSize.baseDisplaySize / 17.0
            func arguments(_ string: NSAttributedString, width: CGFloat, lines: Int = 1) -> TextNodeLayoutArguments {
                return TextNodeLayoutArguments(attributedString: string, backgroundColor: nil, maximumNumberOfLines: lines, truncationType: .end, constrainedSize: CGSize(width: width, height: 1000.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets())
            }
            let (iconLayout, applyIcon) = makeIconLayout(arguments(NSAttributedString(string: "@", font: Font.medium(20.0), textColor: .white), width: 30.0))
            let availableWidth = max(1.0, params.width - leftInset - params.rightInset - 12.0)
            let (titleLayout, applyTitle) = makeTitleLayout(arguments(NSAttributedString(string: title, font: Font.medium(floor(14.0 * fontScale)), textColor: theme.list.itemPrimaryTextColor), width: availableWidth, lines: 0))
            let (subtitleLayout, applySubtitle) = makeSubtitleLayout(arguments(NSAttributedString(string: subtitle, font: Font.regular(floor(12.0 * fontScale)), textColor: theme.list.itemSecondaryTextColor), width: availableWidth, lines: 0))
            let textHeight = titleLayout.size.height + 3.0 + subtitleLayout.size.height
            let height = max(52.0, ceil(textHeight + 16.0))
            let textTop = floor((height - textHeight) / 2.0)
            let layout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: height), insets: UIEdgeInsets())
            return (layout, {
                guard let self else { return }
                self.iconBackgroundNode.backgroundColor = accentColor
                self.iconBackgroundNode.frame = CGRect(x: params.leftInset + 12.0, y: floor((height - 30.0) / 2.0), width: 30.0, height: 30.0)
                let _ = applyIcon()
                let _ = applyTitle()
                let _ = applySubtitle()
                self.iconTextNode.frame = CGRect(origin: CGPoint(x: params.leftInset + 12.0 + floor((30.0 - iconLayout.size.width) / 2.0), y: floor((height - iconLayout.size.height) / 2.0)), size: iconLayout.size)
                self.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: textTop), size: titleLayout.size)
                self.subtitleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: textTop + titleLayout.size.height + 3.0), size: subtitleLayout.size)
                self.separatorNode.backgroundColor = theme.list.itemPlainSeparatorColor
                self.separatorNode.frame = CGRect(x: leftInset, y: height - UIScreenPixel, width: params.width - leftInset, height: UIScreenPixel)
                self.separatorNode.isHidden = !hasNext
                self.highlightedBackgroundNode.backgroundColor = theme.list.itemHighlightedBackgroundColor
                self.highlightedBackgroundNode.frame = CGRect(origin: .zero, size: layout.contentSize)
                self.activateAreaNode.frame = CGRect(origin: .zero, size: layout.contentSize)
                self.activateAreaNode.accessibilityLabel = title
                self.activateAreaNode.accessibilityValue = subtitle
                self.activateAreaNode.accessibilityIdentifier = "AllMentionSuggestion"
                self.activateAreaNode.accessibilityTraits = item.suggestion.isEnabled ? [.button] : [.button, .notEnabled]
                self.activateAreaNode.activate = {
                    guard item.suggestion.isEnabled else { return false }
                    item.action()
                    return true
                }
            })
        }
    }

    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, neighbors: ListViewItemNeighbors) {
        guard let item = item as? AllMembersMentionChatInputPanelItem else { return }
        let (layout, apply) = self.asyncLayout()(item, params, neighbors.next != nil)
        self.contentSize = layout.contentSize
        self.insets = layout.insets
        apply()
    }

    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        if !highlighted && animated {
            self.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25)
        }
        self.highlightedBackgroundNode.alpha = highlighted ? 1.0 : 0.0
    }
}
