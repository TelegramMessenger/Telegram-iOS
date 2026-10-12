import UIKit
import Display
import AccountContext
import TelegramPresentationData
import ComponentFlow
import WalletContext
import WalletCollectibleHeaderComponent

final class WalletCollectiblesGridView: UIView {
    private final class ItemView: UIControl {
        let media = WalletCollectibleMediaView(frame: .zero)
        var action: (() -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.addSubview(self.media)
            self.isAccessibilityElement = true
            self.accessibilityTraits = .button
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var isHighlighted: Bool {
            didSet {
                self.alpha = self.isHighlighted ? 0.7 : 1.0
            }
        }

        @objc private func pressed() {
            self.action?()
        }
    }

    private var items: [WalletContext.Collectible] = []
    private var itemViews: [String: ItemView] = [:]
    private var context: AccountContext?
    private var theme: PresentationTheme?
    private var openCollectible: ((WalletContext.Collectible) -> Void)?
    private var itemSide: CGFloat = 0.0
    private let spacing: CGFloat = 10.0

    func update(context: AccountContext, theme: PresentationTheme, items: [WalletContext.Collectible], width: CGFloat, visibleBounds: CGRect, transition: ComponentTransition, openCollectible: @escaping (WalletContext.Collectible) -> Void) -> CGSize {
        self.context = context
        self.theme = theme
        self.items = items
        self.openCollectible = openCollectible
        self.itemSide = floorToScreenPixels(max(0.0, width - self.spacing * 2.0) / 3.0)
        self.updateVisibleBounds(visibleBounds, transition: transition)
        let rowCount = (items.count + 2) / 3
        return CGSize(width: width, height: CGFloat(rowCount) * self.itemSide + CGFloat(max(0, rowCount - 1)) * self.spacing)
    }

    func updateVisibleBounds(_ visibleBounds: CGRect, transition: ComponentTransition) {
        guard let context = self.context, let theme = self.theme, self.itemSide > 0.0 else { return }
        // Preload nearby cells, but only play animations inside the actual viewport.
        let preloadBounds = visibleBounds.insetBy(dx: 0.0, dy: -100.0)
        let stride = self.itemSide + self.spacing
        let firstRow = max(0, Int(floor(preloadBounds.minY / stride)))
        let lastRow = max(firstRow, Int(ceil(preloadBounds.maxY / stride)))
        let firstIndex = min(self.items.count, firstRow * 3)
        let lastIndex = min(self.items.count, lastRow * 3)
        var validIds = Set<String>()
        for index in firstIndex ..< lastIndex {
            let item = self.items[index]
            let frame = CGRect(x: CGFloat(index % 3) * stride, y: CGFloat(index / 3) * stride, width: self.itemSide, height: self.itemSide)
            validIds.insert(item.address)
            let view: ItemView
            let itemTransition: ComponentTransition
            if let current = self.itemViews[item.address] {
                view = current
                itemTransition = transition
            } else {
                view = ItemView(frame: .zero)
                self.itemViews[item.address] = view
                self.addSubview(view)
                itemTransition = .immediate
            }
            view.accessibilityLabel = item.name
            view.accessibilityValue = item.subtitle
            view.action = { [weak self] in self?.openCollectible?(item) }
            view.media.update(context: context, theme: theme, image: item.image ?? item.thumbnail, lottie: item.kind == .gift ? item.lottie : nil, size: frame.size, transition: itemTransition)
            itemTransition.setFrame(view: view.media, frame: CGRect(origin: .zero, size: frame.size))
            itemTransition.setFrame(view: view, frame: frame)
            view.media.setAnimationVisible(frame.intersects(visibleBounds))
        }
        for id in Array(self.itemViews.keys) where !validIds.contains(id) {
            if let view = self.itemViews.removeValue(forKey: id) {
                view.media.setAnimationVisible(false)
                view.removeFromSuperview()
            }
        }
    }

    func clearVisibleItems() {
        for view in self.itemViews.values {
            view.media.setAnimationVisible(false)
            view.removeFromSuperview()
        }
        self.itemViews.removeAll()
    }
}
