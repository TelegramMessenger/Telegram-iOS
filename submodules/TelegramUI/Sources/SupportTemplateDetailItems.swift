import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI

/// Three purpose-built rows for Template Detail (user feedback: the generic
/// `ItemListTextItem` renders everything in `theme.list.freeTextColor` - this codebase's
/// muted footer/description style - which read as "too small and basic" for what should be
/// the main readable content of the screen). These use `itemPrimaryTextColor` at a proper
/// reading size, a full-width unlimited-line title (so a long Question is never truncated -
/// the nav bar title still gets a copy, but is no longer the only place to read it), a
/// wrapping key-chip row, and a distinctly-styled card for the Value so it reads like a
/// preview of the message that will actually be sent.

private func chipFont(_ presentationData: ItemListPresentationData) -> UIFont {
    return Font.medium(floor(presentationData.fontSize.itemListBaseFontSize * 14.0 / 17.0))
}

// MARK: - Title (Question)

final class SupportTemplateDetailTitleItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let title: String
    let sectionId: ItemListSectionId
    
    init(presentationData: ItemListPresentationData, title: String, sectionId: ItemListSectionId) {
        self.presentationData = presentationData
        self.title = title
        self.sectionId = sectionId
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = SupportTemplateDetailTitleItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            Queue.mainQueue().async {
                completion(node, { return (nil, { _ in apply() }) })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            guard let nodeValue = node() as? SupportTemplateDetailTitleItemNode else { return }
            let makeLayout = nodeValue.asyncLayout()
            async {
                let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                Queue.mainQueue().async {
                    completion(layout, { _ in apply() })
                }
            }
        }
    }
}

final class SupportTemplateDetailTitleItemNode: ListViewItemNode, ItemListItemNode {
    private let titleNode: TextNode
    var tag: ItemListItemTag? { return nil }
    
    init() {
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        super.init(layerBacked: false)
        self.addSubnode(self.titleNode)
    }
    
    func asyncLayout() -> (_ item: SupportTemplateDetailTitleItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        return { [weak self] item, params, neighbors in
            let leftInset: CGFloat = 16.0 + params.leftInset
            let rightInset: CGFloat = 16.0 + params.rightInset
            let topInset: CGFloat = 14.0
            let bottomInset: CGFloat = 10.0
            
            let titleFont = Font.bold(floor(item.presentationData.fontSize.itemListBaseFontSize * 21.0 / 17.0))
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: titleFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: .greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var insets = itemListNeighborsGroupedInsets(neighbors, params)
            insets.top = 0.0
            let contentSize = CGSize(width: params.width, height: titleLayout.size.height + topInset + bottomInset)
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, {
                guard let strongSelf = self else { return }
                let _ = titleApply()
                strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: topInset), size: titleLayout.size)
            })
        }
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = item as? SupportTemplateDetailTitleItem {
            let (layout, apply) = self.asyncLayout()(item, params, itemListNeighbors(item: item, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            self.contentSize = layout.contentSize
            self.insets = layout.insets
            apply()
        }
    }
}

// MARK: - Keys (wrapping chip row)

final class SupportTemplateDetailKeysItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let label: String
    let keys: [String]
    /// Keys that conflict with a *different* User Template (D34) - rendered as red chips.
    let highlightedKeys: Set<String>
    /// Quiet, non-red aggregate note for keys that only overlap an Official template -
    /// informational, not a conflict ("yours takes priority").
    let note: String?
    let sectionId: ItemListSectionId
    /// Invoked on tap anywhere in the row, only when `highlightedKeys` is non-empty - shows
    /// which other User Template(s) share a key, "jump to them" (D34). Whole-row tap rather
    /// than per-chip hit testing: simpler, and the row's only interactive affordance anyway.
    let collisionTapped: (() -> Void)?
    /// Owner feedback (Round B polish): the My Templates editor renders each chip with a
    /// trailing "✕" and makes it individually tappable to remove, instead of the old
    /// newline-separated free-text field. View mode (official/read-only user) leaves this
    /// false and keeps the single whole-row `collisionTapped` affordance.
    let editable: Bool
    let removeKey: ((String) -> Void)?
    
    init(presentationData: ItemListPresentationData, label: String, keys: [String], highlightedKeys: Set<String> = [], note: String? = nil, sectionId: ItemListSectionId, collisionTapped: (() -> Void)? = nil, editable: Bool = false, removeKey: ((String) -> Void)? = nil) {
        self.presentationData = presentationData
        self.label = label
        self.keys = keys
        self.highlightedKeys = highlightedKeys
        self.note = note
        self.sectionId = sectionId
        self.collisionTapped = collisionTapped
        self.editable = editable
        self.removeKey = removeKey
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = SupportTemplateDetailKeysItemNode()
            let (layout, apply) = node.layout(item: self, params: params, neighbors: itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            Queue.mainQueue().async {
                completion(node, { return (nil, { _ in apply() }) })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            guard let nodeValue = node() as? SupportTemplateDetailKeysItemNode else { return }
            let (layout, apply) = nodeValue.layout(item: self, params: params, neighbors: itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            Queue.mainQueue().async {
                completion(layout, { _ in apply() })
            }
        }
    }
}

final class SupportTemplateDetailKeysItemNode: ListViewItemNode, ItemListItemNode {
    private let labelNode: TextNode
    private var chipBackgrounds: [ASImageNode] = []
    private var chipTexts: [TextNode] = []
    private let noteNode: TextNode
    private var rowTapped: (() -> Void)?
    /// Placed chip frames + the key each one represents, captured at the end of every
    /// layout pass so `handleTap` can hit-test a tap location against them without
    /// re-deriving layout math (the chips are laid out with simple left-to-right wrapping,
    /// not one gesture recognizer per chip).
    private var placedChipFrames: [(key: String, frame: CGRect)] = []
    private var removeKey: ((String) -> Void)?
    var tag: ItemListItemTag? { return nil }
    
    init() {
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        self.noteNode = TextNode()
        self.noteNode.isUserInteractionEnabled = false
        super.init(layerBacked: false)
        self.addSubnode(self.labelNode)
        self.addSubnode(self.noteNode)
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:))))
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        if let removeKey = self.removeKey {
            let location = gesture.location(in: self.view)
            for entry in self.placedChipFrames {
                if entry.frame.contains(location) {
                    removeKey(entry.key)
                    return
                }
            }
            // Editable mode has no separate whole-row affordance - a tap that misses every
            // chip is a no-op, not a fallthrough to `rowTapped`.
            return
        }
        self.rowTapped?()
    }
    
    func layout(item: SupportTemplateDetailKeysItem, params: ListViewItemLayoutParams, neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let leftInset: CGFloat = 16.0 + params.leftInset
        let rightInset: CGFloat = 16.0 + params.rightInset
        let topInset: CGFloat = 8.0
        
        let labelFont = Font.semibold(floor(item.presentationData.fontSize.itemListBaseFontSize * 12.0 / 17.0))
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.label.uppercased(), font: labelFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        
        let chipFontValue = chipFont(item.presentationData)
        let chipHeight: CGFloat = 28.0
        let chipSpacingX: CGFloat = 8.0
        let chipSpacingY: CGFloat = 8.0
        let chipHorizontalPadding: CGFloat = 12.0
        let availableWidth = params.width - leftInset - rightInset
        
        var chipFrames: [CGRect] = []
        var chipTextNodes: [TextNode] = []
        var chipTextLayoutsAndApply: [(TextNodeLayout, () -> Void)] = []
        var currentX: CGFloat = 0.0
        var currentY: CGFloat = labelLayout.size.height + 10.0
        for key in item.keys {
            let isHighlighted = item.highlightedKeys.contains(key)
            // Editable chips show a trailing "✕" as part of the same text run - the whole
            // chip is the tap target (hit-tested against the placed frame in `handleTap`),
            // so there's no separate button subview to manage.
            let displayText = item.editable ? "\(key)  ✕" : key
            let textSize = (displayText as NSString).size(withAttributes: [.font: chipFontValue])
            let chipWidth = textSize.width + chipHorizontalPadding * 2.0
            if currentX > 0.0 && currentX + chipWidth > availableWidth {
                currentX = 0.0
                currentY += chipHeight + chipSpacingY
            }
            chipFrames.append(CGRect(x: currentX, y: currentY, width: chipWidth, height: chipHeight))
            currentX += chipWidth + chipSpacingX
            
            let chipTextColor = isHighlighted ? item.presentationData.theme.list.itemDestructiveColor : item.presentationData.theme.list.itemAccentColor
            let chipTextNode = TextNode()
            let (chipLayout, chipApply) = TextNode.asyncLayout(chipTextNode)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: displayText, font: chipFontValue, textColor: chipTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: availableWidth, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            chipTextNodes.append(chipTextNode)
            chipTextLayoutsAndApply.append((chipLayout, { let _ = chipApply() }))
        }
        
        let chipsBottom = item.keys.isEmpty ? labelLayout.size.height : (currentY + chipHeight)
        
        let noteFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 13.0 / 17.0))
        let makeNoteLayout = TextNode.asyncLayout(self.noteNode)
        let (noteLayout, noteApply) = makeNoteLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.note ?? "", font: noteFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: availableWidth, height: .greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        
        let noteTop = item.note != nil ? chipsBottom + 10.0 : chipsBottom
        let contentHeight = item.note != nil ? noteTop + noteLayout.size.height : chipsBottom
        
        var insets = itemListNeighborsGroupedInsets(neighbors, params)
        insets.top = 0.0
        let contentSize = CGSize(width: params.width, height: contentHeight + topInset + 12.0)
        let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
        
        let normalChipColor = item.presentationData.theme.list.itemAccentColor.withAlphaComponent(0.12)
        let highlightedChipColor = item.presentationData.theme.list.itemDestructiveColor.withAlphaComponent(0.12)
        
        return (layout, { [weak self] in
            guard let strongSelf = self else { return }
            let _ = labelApply()
            strongSelf.labelNode.frame = CGRect(origin: CGPoint(x: leftInset, y: topInset), size: labelLayout.size)
            
            let _ = noteApply()
            strongSelf.noteNode.frame = CGRect(origin: CGPoint(x: leftInset, y: topInset + noteTop), size: noteLayout.size)
            strongSelf.noteNode.isHidden = item.note == nil
            
            for node in strongSelf.chipBackgrounds { node.removeFromSupernode() }
            for node in strongSelf.chipTexts { node.removeFromSupernode() }
            strongSelf.chipBackgrounds = []
            strongSelf.chipTexts = []
            
            for (index, frame) in chipFrames.enumerated() {
                let isHighlighted = item.highlightedKeys.contains(item.keys[index])
                let backgroundNode = ASImageNode()
                backgroundNode.image = generateFilledRoundedRectImage(size: frame.size, cornerRadius: chipHeight / 2.0, color: isHighlighted ? highlightedChipColor : normalChipColor)
                backgroundNode.frame = frame.offsetBy(dx: leftInset, dy: topInset)
                strongSelf.addSubnode(backgroundNode)
                strongSelf.chipBackgrounds.append(backgroundNode)
                
                let (textLayout, textApply) = chipTextLayoutsAndApply[index]
                textApply()
                let textNode = chipTextNodes[index]
                textNode.frame = CGRect(origin: CGPoint(x: frame.minX + leftInset + chipHorizontalPadding, y: frame.minY + topInset + floor((chipHeight - textLayout.size.height) / 2.0)), size: textLayout.size)
                strongSelf.addSubnode(textNode)
                strongSelf.chipTexts.append(textNode)
            }
            
            strongSelf.placedChipFrames = item.editable ? zip(item.keys, chipFrames.map { $0.offsetBy(dx: leftInset, dy: topInset) }).map { (key: $0, frame: $1) } : []
            strongSelf.removeKey = item.editable ? item.removeKey : nil
            strongSelf.rowTapped = item.editable ? nil : (item.highlightedKeys.isEmpty ? nil : item.collisionTapped)
        })
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = item as? SupportTemplateDetailKeysItem {
            let (layout, apply) = self.layout(item: item, params: params, neighbors: itemListNeighbors(item: item, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            self.contentSize = layout.contentSize
            self.insets = layout.insets
            apply()
        }
    }
}

// MARK: - Value (styled preview card)

final class SupportTemplateDetailValueItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let label: String
    let text: String
    let sectionId: ItemListSectionId
    
    init(presentationData: ItemListPresentationData, label: String, text: String, sectionId: ItemListSectionId) {
        self.presentationData = presentationData
        self.label = label
        self.text = text
        self.sectionId = sectionId
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = SupportTemplateDetailValueItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            Queue.mainQueue().async {
                completion(node, { return (nil, { _ in apply() }) })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            guard let nodeValue = node() as? SupportTemplateDetailValueItemNode else { return }
            let makeLayout = nodeValue.asyncLayout()
            async {
                let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                Queue.mainQueue().async {
                    completion(layout, { _ in apply() })
                }
            }
        }
    }
}

final class SupportTemplateDetailValueItemNode: ListViewItemNode, ItemListItemNode {
    private let labelNode: TextNode
    private let cardBackgroundNode: ASImageNode
    private let textNode: TextNode
    var tag: ItemListItemTag? { return nil }
    
    init() {
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        self.cardBackgroundNode = ASImageNode()
        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        super.init(layerBacked: false)
        self.addSubnode(self.labelNode)
        self.addSubnode(self.cardBackgroundNode)
        self.addSubnode(self.textNode)
    }
    
    func asyncLayout() -> (_ item: SupportTemplateDetailValueItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        
        return { [weak self] item, params, neighbors in
            let leftInset: CGFloat = 16.0 + params.leftInset
            let rightInset: CGFloat = 16.0 + params.rightInset
            let topInset: CGFloat = 8.0
            let cardPadding: CGFloat = 14.0
            
            let labelFont = Font.semibold(floor(item.presentationData.fontSize.itemListBaseFontSize * 12.0 / 17.0))
            let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.label.uppercased(), font: labelFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let textFont = Font.regular(floor(item.presentationData.fontSize.itemListBaseFontSize * 16.0 / 17.0))
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.text, font: textFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset - cardPadding * 2.0, height: .greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let cardHeight = textLayout.size.height + cardPadding * 2.0
            let cardTop = labelLayout.size.height + 10.0
            
            var insets = itemListNeighborsGroupedInsets(neighbors, params)
            insets.top = 0.0
            let contentSize = CGSize(width: params.width, height: topInset + cardTop + cardHeight + 14.0)
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            let cardColor = item.presentationData.theme.list.itemAccentColor.withAlphaComponent(0.08)
            let cardWidth = params.width - leftInset - rightInset
            
            return (layout, {
                guard let strongSelf = self else { return }
                let _ = labelApply()
                let _ = textApply()
                
                strongSelf.labelNode.frame = CGRect(origin: CGPoint(x: leftInset, y: topInset), size: labelLayout.size)
                
                strongSelf.cardBackgroundNode.image = generateFilledRoundedRectImage(size: CGSize(width: cardWidth, height: cardHeight), cornerRadius: 16.0, color: cardColor)
                strongSelf.cardBackgroundNode.frame = CGRect(x: leftInset, y: topInset + cardTop, width: cardWidth, height: cardHeight)
                
                strongSelf.textNode.frame = CGRect(origin: CGPoint(x: leftInset + cardPadding, y: topInset + cardTop + cardPadding), size: textLayout.size)
            })
        }
    }
    
    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = item as? SupportTemplateDetailValueItem {
            let (layout, apply) = self.asyncLayout()(item, params, itemListNeighbors(item: item, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            self.contentSize = layout.contentSize
            self.insets = layout.insets
            apply()
        }
    }
}
