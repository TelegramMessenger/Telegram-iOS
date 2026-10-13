import Foundation
import Postbox

public extension InstantPage {
    /// Returns a copy of the page with the checkbox list item at `path` set to `value`.
    /// `path` is a sequence of child-indices from the page root to the target list item
    /// (see InstantPageCheckboxToggle path semantics). If the path does not resolve to a
    /// checkbox list item, the page is returned unchanged.
    func togglingCheckbox(at path: [Int], to value: Bool) -> InstantPage {
        guard !path.isEmpty else {
            return self
        }
        let newBlocks = togglingCheckboxInBlocks(self.blocks, path: path, value: value)
        return InstantPage(
            blocks: newBlocks,
            rawMedia: self.rawMedia,
            isComplete: self.isComplete,
            rtl: self.rtl,
            url: self.url,
            views: self.views
        )
    }
}

/// Descends a block array following `path[0]`, recursing into container blocks.
private func togglingCheckboxInBlocks(_ blocks: [InstantPageBlock], path: [Int], value: Bool) -> [InstantPageBlock] {
    guard let index = path.first, index >= 0, index < blocks.count else {
        return blocks
    }
    let remainder = Array(path.dropFirst())
    var result = blocks
    result[index] = togglingCheckboxInBlock(blocks[index], path: remainder, value: value)
    return result
}

/// Applies the remaining path to a single block. `path` is the sub-path *after* the index
/// that selected this block from its parent array.
private func togglingCheckboxInBlock(_ block: InstantPageBlock, path: [Int], value: Bool) -> InstantPageBlock {
    switch block {
    case let .list(items, ordered):
        // The next hop selects the list item; it is the checkbox target (or a container to descend).
        guard let itemIndex = path.first, itemIndex >= 0, itemIndex < items.count else {
            return block
        }
        let remainder = Array(path.dropFirst())
        var newItems = items
        newItems[itemIndex] = togglingCheckboxInListItem(items[itemIndex], path: remainder, value: value)
        return .list(items: newItems, ordered: ordered)
    case let .details(title, blocks, expanded):
        return .details(title: title, blocks: togglingCheckboxInBlocks(blocks, path: path, value: value), expanded: expanded)
    case let .blockQuote(blocks, caption, collapsed):
        return .blockQuote(blocks: togglingCheckboxInBlocks(blocks, path: path, value: value), caption: caption, collapsed: collapsed)
    case let .cover(inner):
        return .cover(togglingCheckboxInBlock(inner, path: path, value: value))
    default:
        return block
    }
}

/// Applies the remaining path to a list item. An empty remainder means this item IS the target;
/// a non-empty remainder means the item is `.blocks` and we descend into its blocks.
private func togglingCheckboxInListItem(_ item: InstantPageListItem, path: [Int], value: Bool) -> InstantPageListItem {
    if path.isEmpty {
        switch item {
        case let .text(text, num, checked):
            // Only flip an item that is actually a checkbox (checked != nil).
            return checked == nil ? item : .text(text, num, value)
        case let .blocks(blocks, num, checked):
            return checked == nil ? item : .blocks(blocks, num, value)
        case .unknown:
            return item
        }
    } else {
        // Descend into a `.blocks` item's nested blocks.
        if case let .blocks(blocks, num, checked) = item {
            return .blocks(togglingCheckboxInBlocks(blocks, path: path, value: value), num, checked)
        }
        return item
    }
}
