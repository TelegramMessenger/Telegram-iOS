import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI

/// Unified row for every template row in all three Templates surfaces - the chat-mode
/// merged browser, the Settings "Official" tab, and the Settings "Mine" tab (generalized
/// from a Mine-tab-only swipeable row). `ItemListDisclosureItem` (used everywhere templates
/// used to be listed) has two real, confirmed bugs when given both `titleBadge` and `label`
/// together - a badge/label overlap (its `labelConstrain`/`labelFrame` are computed
/// independent of the badge's reserved width) and a "ghost" badge-text leak (the `TextNode`
/// `badgeTextApply()` returns is never written back to `self.titleBadgeTextNode`, so it's
/// always `nil` and every relayout creates one more node instead of reusing one). Per this
/// project's established precedent (ai-docs/tsupport/30-pitfalls.md - never retrofit a
/// widely-shared foundation type for a support-only feature), this row avoids both bugs by
/// construction instead of patching `ItemListDisclosureItem`:
///  1. Two structurally separate lines - Line 1 is the Question + an optional badge pill
///     (its measured width reserved out of the title's constrained width *before* the title
///     is measured); Line 2 is the value preview, laid out independent of the badge
///     entirely. There is no layout this row can produce where they overlap.
///  2. The badge's own `TextNode` is reassigned to its stored property every layout pass
///     (see the `apply` closure below), so relayout reuses one node instead of leaking one.
///
/// It also owns swipe-to-delete (Mine tab only, `deleteAction != nil`) via
/// `ItemListRevealOptionsItemNode`, and a long-press "peek" preview (all rows, "like 3D
/// touch" per the owner) via `ContextControllerSourceNode` wrapping
/// `ContextExtractedContentContainingNode` - modeled directly on
/// `InviteLinksUI/Sources/ItemListInviteLinkItem.swift`. `ItemListPeerItem.swift` already
/// proves reveal-options + a context source node safely coexist elsewhere in this codebase.
final class SupportTemplateRowItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    /// Full Question text - shown truncated to one line here, in full in the long-press
    /// preview.
    let title: String
    /// Full Value - line 2 below shows a one-line preview of it (`supportTemplateValuePreview`);
    /// the long-press preview shows it in full.
    let value: SupportTemplateValue
    let keys: [String]
    /// "Official"/"Mine", or `nil` on the Mine tab (D34: you already know which tab you're
    /// on, so Mine-tab rows never show a badge).
    let badgeText: String?
    let sectionId: ItemListSectionId
    let action: () -> Void
    /// The long-press preview's primary action label ("Use Template"/"View Details"/"Edit") -
    /// supplied by the entry-building code in `SupportTemplatesController.swift`, since only
    /// it knows which mode/tab produced this row.
    let contextActionTitle: String
    /// Non-nil only for Mine-tab rows: enables both swipe-to-delete and a destructive
    /// "Delete" entry in the long-press menu.
    let deleteAction: (() -> Void)?
    let contextAction: ((SupportTemplatePreviewPayload, ASDisplayNode, ContextGesture?) -> Void)?
    // `ListViewItem.selectable` defaults to `false` in its protocol extension - without this
    // override, taps on the row are silently never routed to `selected(listView:)` at all
    // (`ListView.swift`'s tap handling gates on `items[index].selectable && itemNode.canBeSelected`).
    let selectable: Bool = true
    var tag: ItemListItemTag? { return nil }

    init(presentationData: ItemListPresentationData, title: String, value: SupportTemplateValue, keys: [String], badgeText: String?, sectionId: ItemListSectionId, action: @escaping () -> Void, contextActionTitle: String, deleteAction: (() -> Void)?, contextAction: ((SupportTemplatePreviewPayload, ASDisplayNode, ContextGesture?) -> Void)?) {
        self.presentationData = presentationData
        self.title = title
        self.value = value
        self.keys = keys
        self.badgeText = badgeText
        self.sectionId = sectionId
        self.action = action
        self.contextActionTitle = contextActionTitle
        self.deleteAction = deleteAction
        self.contextAction = contextAction
    }

    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = SupportTemplateRowItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            Queue.mainQueue().async {
                completion(node, { return (nil, { _ in apply() }) })
            }
        }
    }

    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            guard let nodeValue = node() as? SupportTemplateRowItemNode else { return }
            let makeLayout = nodeValue.asyncLayout()
            async {
                let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))
                Queue.mainQueue().async {
                    completion(layout, { _ in apply() })
                }
            }
        }
    }

    func selected(listView: ListView) {
        listView.clearHighlightAnimated(true)
        self.action()
    }
}

final class SupportTemplateRowItemNode: ItemListRevealOptionsItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode

    // `containerNode` is `controlsContainer`: the base class adds the Delete reveal node into
    // it, already positioned at `size.width + revealOffset` - so it must never be shifted
    // itself, or that button moves twice. Only `offsetContainerNode` (the visible content)
    // slides on reveal - the same parent/content split as `ItemListCheckboxItemNode`
    // (`contentParentNode`/`contentContainerNode`). `contextSourceNode` is what long-press
    // "pops out" of the list on activation.
    private let containerNode: ContextControllerSourceNode
    private let contextSourceNode: ContextExtractedContentContainingNode
    private let extractedBackgroundImageNode: ASImageNode
    private let offsetContainerNode: ASDisplayNode

    private let titleNode: TextNode
    private var titleBadgeNode: ASImageNode?
    private var titleBadgeTextNode: TextNode?
    private let labelNode: TextNode
    private let arrowNode: ASImageNode

    private var extractedRect: CGRect?
    private var nonExtractedRect: CGRect?

    private var item: SupportTemplateRowItem?
    var tag: ItemListItemTag? { return nil }

    override var controlsContainer: ASDisplayNode {
        return self.containerNode
    }

    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true

        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true

        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true

        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true

        self.containerNode = ContextControllerSourceNode()
        self.contextSourceNode = ContextExtractedContentContainingNode()

        self.extractedBackgroundImageNode = ASImageNode()
        self.extractedBackgroundImageNode.displaysAsynchronously = false
        self.extractedBackgroundImageNode.alpha = 0.0

        self.offsetContainerNode = ASDisplayNode()

        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false

        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false

        self.arrowNode = ASImageNode()
        self.arrowNode.isLayerBacked = true
        self.arrowNode.displaysAsynchronously = false

        super.init(layerBacked: false, rotated: false, seeThrough: false)

        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.contextSourceNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode

        self.contextSourceNode.contentNode.addSubnode(self.extractedBackgroundImageNode)
        self.contextSourceNode.contentNode.addSubnode(self.offsetContainerNode)

        self.offsetContainerNode.addSubnode(self.titleNode)
        self.offsetContainerNode.addSubnode(self.labelNode)
        self.offsetContainerNode.addSubnode(self.arrowNode)

        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let item = strongSelf.item, let contextAction = item.contextAction else {
                gesture.cancel()
                return
            }
            let payload = SupportTemplatePreviewPayload(title: item.title, value: item.value, keys: item.keys, primaryActionTitle: item.contextActionTitle, primaryAction: item.action, deleteAction: item.deleteAction)
            contextAction(payload, strongSelf.contextSourceNode, gesture)
        }

        self.contextSourceNode.willUpdateIsExtractedToContextPreview = { [weak self] isExtracted, transition in
            guard let strongSelf = self, let item = strongSelf.item else {
                return
            }
            if isExtracted {
                strongSelf.extractedBackgroundImageNode.image = generateStretchableFilledCircleImage(diameter: 28.0, color: item.presentationData.theme.list.plainBackgroundColor)
            }
            if let extractedRect = strongSelf.extractedRect, let nonExtractedRect = strongSelf.nonExtractedRect {
                let rect = isExtracted ? extractedRect : nonExtractedRect
                transition.updateFrame(node: strongSelf.extractedBackgroundImageNode, frame: rect)
            }
            transition.updateSublayerTransformOffset(layer: strongSelf.offsetContainerNode.layer, offset: CGPoint(x: isExtracted ? 12.0 : 0.0, y: 0.0))
            transition.updateAlpha(node: strongSelf.extractedBackgroundImageNode, alpha: isExtracted ? 1.0 : 0.0, completion: { [weak self] _ in
                if !isExtracted {
                    self?.extractedBackgroundImageNode.image = nil
                }
            })
        }
    }

    func asyncLayout() -> (_ item: SupportTemplateRowItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let makeTitleBadgeTextLayout = TextNode.asyncLayout(self.titleBadgeTextNode)

        return { [weak self] item, params, neighbors in
            let leftInset: CGFloat = 16.0 + params.leftInset
            let rightInset: CGFloat = 16.0 + params.rightInset
            let arrowWidth: CGFloat = 8.0

            let titleFont = Font.regular(item.presentationData.fontSize.itemListBaseFontSize)
            let labelFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 15.0 / 17.0))
            let badgeFont = Font.medium(11.0)

            let titleColor = item.presentationData.theme.list.itemPrimaryTextColor
            let labelColor = item.presentationData.theme.list.itemSecondaryTextColor

            let arrowImage = PresentationResourcesItemList.disclosureArrowImage(item.presentationData.theme)
            let arrowSpace: CGFloat = arrowWidth + (arrowImage?.size.width ?? 0.0)
            let availableWidth = params.width - leftInset - rightInset - arrowSpace

            // Badge measured FIRST, so its width can be reserved out of the title's
            // constrained width before the title itself is measured - this is the actual
            // fix for the overlap bug: in `ItemListDisclosureItem`, the label's constrained
            // width is computed independent of the badge's reserved width entirely. Here,
            // only the *title* (line 1) ever shares horizontal space with the badge; the
            // label (line 2, below) is a structurally separate line and never reserves or
            // avoids badge width, because it never needs to.
            let badgeSideInset: CGFloat = 5.0
            let badgeVerticalInset: CGFloat = 2.0
            var badgeLayoutAndApply: (TextNodeLayout, () -> TextNode)?
            var badgeSize = CGSize()
            if let badgeText = item.badgeText {
                let badgeTextLayoutAndApply = makeTitleBadgeTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: badgeText, font: badgeFont, textColor: item.presentationData.theme.list.itemCheckColors.foregroundColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 100.0, height: .greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                badgeLayoutAndApply = badgeTextLayoutAndApply
                badgeSize = CGSize(width: badgeTextLayoutAndApply.0.size.width + badgeSideInset * 2.0, height: badgeTextLayoutAndApply.0.size.height + badgeVerticalInset * 2.0)
            }
            let badgeReservedWidth: CGFloat = badgeLayoutAndApply != nil ? 5.0 + badgeSize.width : 0.0

            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: titleFont, textColor: titleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(0.0, availableWidth - badgeReservedWidth), height: .greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))

            // Line 2 (value preview): constrained to the same `availableWidth` as line 1, but
            // never reduced by badge width - it's a separate line below the title, so the
            // badge can structurally never reach it.
            let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: supportTemplateValuePreview(item.value), font: labelFont, textColor: labelColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: availableWidth, height: .greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))

            let titleSpacing: CGFloat = 3.0
            let verticalInset: CGFloat = 11.0
            let line1Height = max(titleLayout.size.height, badgeLayoutAndApply != nil ? badgeSize.height : 0.0)
            let centralContentHeight = line1Height + titleSpacing + labelLayout.size.height
            let contentHeight = verticalInset * 2.0 + centralContentHeight

            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            let contentSize = CGSize(width: params.width, height: contentHeight)
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)

            return (layout, { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.item = item

                strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: contentSize)
                strongSelf.containerNode.isGestureEnabled = item.contextAction != nil
                strongSelf.contextSourceNode.frame = CGRect(origin: CGPoint(), size: contentSize)
                strongSelf.contextSourceNode.contentNode.frame = CGRect(origin: CGPoint(), size: contentSize)
                // Keep the current reveal offset across relayouts (e.g. a list update while
                // the Delete button is showing) rather than snapping the content back to 0.
                strongSelf.offsetContainerNode.frame = CGRect(origin: CGPoint(x: strongSelf.offsetContainerNode.frame.minX, y: 0.0), size: contentSize)

                let nonExtractedRect = CGRect(origin: CGPoint(), size: CGSize(width: contentSize.width - 16.0, height: contentSize.height))
                let extractedRect = CGRect(origin: CGPoint(), size: contentSize).insetBy(dx: 16.0 + params.leftInset, dy: 0.0)
                strongSelf.extractedRect = extractedRect
                strongSelf.nonExtractedRect = nonExtractedRect
                if strongSelf.contextSourceNode.isExtractedToContextPreview {
                    strongSelf.extractedBackgroundImageNode.frame = extractedRect
                } else {
                    strongSelf.extractedBackgroundImageNode.frame = nonExtractedRect
                }
                strongSelf.contextSourceNode.contentRect = extractedRect

                strongSelf.backgroundNode.backgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                strongSelf.topStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                strongSelf.bottomStripeNode.backgroundColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor

                if strongSelf.backgroundNode.supernode == nil {
                    strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                }
                if strongSelf.topStripeNode.supernode == nil {
                    strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                }
                if strongSelf.bottomStripeNode.supernode == nil {
                    strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                }

                strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(), size: contentSize)
                strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: params.width, height: UIScreenPixel))
                strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: contentSize.height - UIScreenPixel), size: CGSize(width: params.width, height: UIScreenPixel))
                strongSelf.highlightedBackgroundNode.frame = strongSelf.backgroundNode.frame

                let _ = titleApply()
                let _ = labelApply()

                let topY = floorToScreenPixels((contentSize.height - centralContentHeight) / 2.0)
                let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: topY + floor((line1Height - titleLayout.size.height) / 2.0)), size: titleLayout.size)
                strongSelf.titleNode.frame = titleFrame
                strongSelf.labelNode.frame = CGRect(origin: CGPoint(x: leftInset, y: topY + line1Height + titleSpacing), size: labelLayout.size)

                strongSelf.arrowNode.image = arrowImage
                strongSelf.arrowNode.frame = CGRect(origin: CGPoint(x: params.width - rightInset - (arrowImage?.size.width ?? 0.0), y: floor((contentSize.height - (arrowImage?.size.height ?? 0.0)) / 2.0)), size: arrowImage?.size ?? CGSize())

                if let (badgeTextLayout, badgeTextApply) = badgeLayoutAndApply {
                    let titleBadgeNode: ASImageNode
                    if let current = strongSelf.titleBadgeNode {
                        titleBadgeNode = current
                    } else {
                        titleBadgeNode = ASImageNode()
                        titleBadgeNode.image = generateFilledRoundedRectImage(size: CGSize(width: 16.0, height: 16.0), cornerRadius: 5.0, color: item.presentationData.theme.list.itemCheckColors.fillColor)?.stretchableImage(withLeftCapWidth: 6, topCapHeight: 6)
                        strongSelf.titleBadgeNode = titleBadgeNode
                        strongSelf.offsetContainerNode.insertSubnode(titleBadgeNode, belowSubnode: strongSelf.titleNode)
                    }

                    // Unlike `ItemListDisclosureItem` (where the node `badgeTextApply()`
                    // returns is never written back to `self.titleBadgeTextNode`, so it
                    // stays `nil` forever and every relayout leaks one more node), reassign
                    // the stored property here every pass so relayout reuses this node.
                    let titleBadgeTextNode = badgeTextApply()
                    if strongSelf.titleBadgeTextNode !== titleBadgeTextNode {
                        strongSelf.titleBadgeTextNode?.removeFromSupernode()
                        strongSelf.titleBadgeTextNode = titleBadgeTextNode
                        strongSelf.offsetContainerNode.addSubnode(titleBadgeTextNode)
                    }

                    let titleBadgeFrame = CGRect(origin: CGPoint(x: titleFrame.maxX + 5.0, y: titleFrame.minY + floorToScreenPixels((titleFrame.height - badgeSize.height) * 0.5)), size: badgeSize)
                    titleBadgeNode.frame = titleBadgeFrame
                    titleBadgeTextNode.frame = CGRect(origin: CGPoint(x: titleBadgeFrame.minX + badgeSideInset, y: titleBadgeFrame.minY + badgeVerticalInset), size: badgeTextLayout.size)
                } else {
                    if let titleBadgeTextNode = strongSelf.titleBadgeTextNode {
                        strongSelf.titleBadgeTextNode = nil
                        titleBadgeTextNode.removeFromSupernode()
                    }
                    if let titleBadgeNode = strongSelf.titleBadgeNode {
                        strongSelf.titleBadgeNode = nil
                        titleBadgeNode.removeFromSupernode()
                    }
                }

                if item.deleteAction != nil {
                    strongSelf.setRevealOptions((left: [], right: [ItemListRevealOption(key: 0, title: item.presentationData.strings.Common_Delete, icon: .none, color: item.presentationData.theme.list.itemDisclosureActions.destructive.fillColor, iconColor: item.presentationData.theme.list.itemDisclosureActions.destructive.foregroundColor, textColor: item.presentationData.theme.list.itemSecondaryTextColor)]))
                } else {
                    strongSelf.setRevealOptions((left: [], right: []))
                }
            })
        }
    }

    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, neighbors: ListViewItemNeighbors) {
        if let item = item as? SupportTemplateRowItem {
            let (layout, apply) = self.asyncLayout()(item, params, itemListNeighbors(item: item, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))
            self.contentSize = layout.contentSize
            self.insets = layout.insets
            apply()
        }
    }

    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        if highlighted {
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: self.bottomStripeNode)
            }
        } else {
            if self.highlightedBackgroundNode.supernode != nil {
                if animated {
                    self.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.4, completion: { [weak self] finished in
                        if finished {
                            self?.highlightedBackgroundNode.removeFromSupernode()
                        }
                    })
                } else {
                    self.highlightedBackgroundNode.removeFromSupernode()
                }
            }
        }
    }

    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        transition.updateFrame(node: self.offsetContainerNode, frame: CGRect(origin: CGPoint(x: offset, y: self.offsetContainerNode.frame.minY), size: self.offsetContainerNode.bounds.size))
    }

    override func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()
        self.item?.deleteAction?()
    }
}
