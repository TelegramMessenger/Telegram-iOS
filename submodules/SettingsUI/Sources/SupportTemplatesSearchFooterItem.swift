import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ItemListUI
import ComponentFlow
import SearchBarNode
import GlassBackgroundComponent
import TabBarComponent
import TabBarLayout

final class SupportTemplatesSearchFooterItem: ItemListControllerFooterItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let updateQuery: (String) -> Void
    let updateIsActive: (Bool) -> Void
    let requestLayout: (ContainedViewLayoutTransition) -> Void

    init(theme: PresentationTheme, strings: PresentationStrings, updateQuery: @escaping (String) -> Void, updateIsActive: @escaping (Bool) -> Void, requestLayout: @escaping (ContainedViewLayoutTransition) -> Void) {
        self.theme = theme
        self.strings = strings
        self.updateQuery = updateQuery
        self.updateIsActive = updateIsActive
        self.requestLayout = requestLayout
    }

    func isEqual(to: ItemListControllerFooterItem) -> Bool {
        if let item = to as? SupportTemplatesSearchFooterItem {
            return self.theme === item.theme && self.strings === item.strings
        } else {
            return false
        }
    }

    func node(current: ItemListControllerFooterItemNode?) -> ItemListControllerFooterItemNode {
        if let current = current as? SupportTemplatesSearchFooterItemNode {
            current.item = self
            return current
        } else {
            return SupportTemplatesSearchFooterItemNode(item: self)
        }
    }
}

final class SupportTemplatesSearchFooterItemNode: ItemListControllerFooterItemNode {
    private let backgroundContainer = GlassBackgroundContainerView()
    private var searchView: NavigationSearchView?
    private weak var connectedSearchBarNode: SearchBarNode?
    private var isActive = false
    private var validLayout: ContainerViewLayout?

    var item: SupportTemplatesSearchFooterItem {
        didSet {
            if let layout = self.validLayout, self.item.theme !== oldValue.theme || self.item.strings !== oldValue.strings {
                let _ = self.updateLayout(layout: layout, transition: .immediate)
            }
        }
    }

    init(item: SupportTemplatesSearchFooterItem) {
        self.item = item
        super.init()
        self.view.addSubview(self.backgroundContainer)
    }

    private func setIsActive(_ isActive: Bool) {
        if self.isActive == isActive {
            return
        }
        self.isActive = isActive
        if !isActive {
            self.connectedSearchBarNode?.deactivate(clear: true)
            self.connectedSearchBarNode = nil
            self.item.updateQuery("")
        }
        self.item.updateIsActive(isActive)
        self.item.requestLayout(.animated(duration: 0.4, curve: .spring))
    }

    override func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = layout
        let componentTransition = ComponentTransition(transition)

        var bottomInset = max(21.0, layout.insets(options: []).bottom - 13.0)
        if self.isActive, let inputHeight = layout.inputHeight, inputHeight != 0.0 {
            bottomInset = max(bottomInset, inputHeight + 8.0)
        }
        let sideInset: CGFloat = 21.0
        let barHeight = tabBarSystemBarThickness
        let containerFrame = CGRect(x: layout.safeInsets.left + sideInset, y: layout.size.height - bottomInset - barHeight, width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - sideInset * 2.0, height: barHeight)

        let searchFrame: CGRect
        if self.isActive {
            searchFrame = CGRect(x: 0.0, y: barHeight - 48.0, width: containerFrame.width, height: 48.0)
        } else {
            searchFrame = CGRect(x: containerFrame.width - barHeight, y: 0.0, width: barHeight, height: barHeight)
        }

        let searchView: NavigationSearchView
        var searchViewTransition = componentTransition
        if let current = self.searchView {
            searchView = current
        } else {
            searchViewTransition = searchViewTransition.withAnimation(.none)
            searchView = NavigationSearchView(action: { [weak self] in
                self?.setIsActive(true)
            }, closeAction: { [weak self] in
                self?.setIsActive(false)
            })
            self.searchView = searchView
            self.backgroundContainer.contentView.addSubview(searchView)
            searchView.frame = searchFrame
        }
        searchView.update(size: searchFrame.size, theme: self.item.theme, strings: self.item.strings, isActive: self.isActive, transition: searchViewTransition)
        searchViewTransition.setFrame(view: searchView, frame: searchFrame)

        componentTransition.setFrame(view: self.backgroundContainer, frame: containerFrame)
        self.backgroundContainer.update(size: containerFrame.size, isDark: self.item.theme.overallDarkAppearance, transition: componentTransition)

        if self.isActive, let searchBarNode = searchView.searchBarNode, searchBarNode !== self.connectedSearchBarNode {
            self.connectedSearchBarNode = searchBarNode
            searchBarNode.textUpdated = { [weak self] query, _ in
                self?.item.updateQuery(query)
            }
            searchBarNode.cancel = { [weak self] in
                self?.setIsActive(false)
            }
            searchBarNode.activate()
        }

        return bottomInset + barHeight + 8.0
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = super.hitTest(point, with: event), let searchView = self.searchView else {
            return nil
        }
        if result === searchView || result.isDescendant(of: searchView) {
            return result
        }
        return nil
    }
}
