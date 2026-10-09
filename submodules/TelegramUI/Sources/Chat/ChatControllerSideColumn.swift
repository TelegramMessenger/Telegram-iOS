import Foundation
import UIKit
import Display
import ChatNavigationButton
import ChatSideColumnLayout

/// iPhone Duo: the chat's navigation bar split into a top row and a side column
/// (docs/iphone-duo-layout.md).
extension ChatControllerImpl {
    private var rightNavigationButtonsInBarOrder: [ChatNavigationButton] {
        return [self.rightNavigationButton, self.secondaryRightNavigationButton].compactMap { $0 }
    }

    private func sideColumnKind(_ button: ChatNavigationButton) -> ChatSideColumnItemKind {
        let item = button.buttonItem
        var isSearch = false
        if case .search = button.action {
            isSearch = true
        }
        return chatSideColumnItemKind(title: item.title, hasImage: item.image != nil, hasCustomNode: item.customDisplayNode != nil, isAvatar: item === self.chatInfoNavigationButton?.buttonItem, isSearch: isSearch)
    }

    /// The assignment while the layout has a strip, else nil.
    func sideColumnAssignment() -> ChatSideColumnAssignment? {
        guard self.sideColumnStripEdge != nil else {
            return nil
        }
        let navigation: ChatSideColumnNavigation
        switch self.navigationBar?.previousItem {
        case .none:
            navigation = .none
        case .close?:
            navigation = .close
        case .item?:
            navigation = .back
        }
        return chatSideColumnAssignment(navigation: navigation, left: self.leftNavigationButton.map { self.sideColumnKind($0) }, right: self.rightNavigationButtonsInBarOrder.map { self.sideColumnKind($0) })
    }

    /// The left item the bar shows: none when it is in the column.
    func barLeftItem() -> UIBarButtonItem? {
        guard let leftNavigationButton = self.leftNavigationButton else {
            return nil
        }
        if let assignment = self.sideColumnAssignment(), !assignment.keepsLeftInTopRow {
            return nil
        }
        return leftNavigationButton.buttonItem
    }

    /// The right items the bar shows: the top row's while there is a strip.
    func barRightItems() -> [UIBarButtonItem] {
        let right = self.rightNavigationButtonsInBarOrder
        guard let assignment = self.sideColumnAssignment() else {
            return right.map { $0.buttonItem }
        }
        return assignment.topRowRightIndices.map { right[$0].buttonItem }
    }

    /// Hands the column its items and tells the bar whether to hide its own back button. Call after the
    /// bar's items were applied, so a custom node the bar released is free to move into the column.
    func updateSideColumn() {
        guard self.isNodeLoaded else {
            return
        }
        let right = self.rightNavigationButtonsInBarOrder
        var items: [ChatSideColumnNode.Item] = []
        let assignment = self.sideColumnAssignment()
        if let assignment {
            for entry in assignment.column {
                switch entry {
                case .back:
                    items.append(.back)
                case .close:
                    items.append(.close)
                case .left:
                    if let leftNavigationButton = self.leftNavigationButton {
                        items.append(.barItem(leftNavigationButton.buttonItem))
                    }
                case .addedSearch:
                    items.append(.search)
                case let .right(index):
                    items.append(.barItem(right[index].buttonItem))
                }
            }
        }
        self.navigationBar?.hidesBackButton = assignment.map { !$0.keepsLeftInTopRow } ?? false
        let itemsUpdated = self.chatDisplayNode.sideColumnNode.update(items: items, badgeText: self.navigationItem.badge ?? "", theme: self.presentationInterfaceState.theme)
        // New slots have no frames until the chat lays out; a change outside a layout pass (a
        // non-interactive state update adding the "more" button, say) must request one.
        if itemsUpdated && !self.isUpdatingSideColumnInLayout && self.validLayout != nil {
            self.requestLayout(transition: .immediate)
        }
    }
}
