import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import ContextUI
import ContextControllerImpl
import WalletContext

typealias WalletCurrencyListItem = (currency: WalletContext.FiatCurrency, name: String)

func walletCurrencyListItems(
    selectedCurrency: WalletContext.FiatCurrency,
    appLanguageCode: String,
    fallbackAppLanguageCode: String,
    systemLanguageCode: String?,
    keyboardLanguageCodes: [String]
) -> [WalletCurrencyListItem] {
    var currencies: [WalletContext.FiatCurrency] = [.usd, .eur]
    let appLocale = walletCurrencyLanguageLocale(appLanguageCode) ?? walletCurrencyLanguageLocale(fallbackAppLanguageCode)
    let systemLocale = systemLanguageCode.flatMap { walletCurrencyLanguageLocale($0) }

    if #available(iOS 16.0, *) {
        var locales = [appLocale, systemLocale].compactMap { $0 }
        locales.append(contentsOf: keyboardLanguageCodes.compactMap { walletCurrencyLanguageLocale($0) })
        for locale in locales {
            if let currency = walletCurrencyForLocale(locale), !currencies.contains(currency) {
                currencies.append(currency)
            }
        }
    } else {
        if appLocale.map({ ($0 as NSLocale).languageCode }) == "ru" || systemLocale.map({ ($0 as NSLocale).languageCode }) == "ru" {
            currencies.append(.rub)
        }
        currencies.append(.cny)
    }

    var includedCurrencies = Set(currencies)
    if includedCurrencies.insert(selectedCurrency).inserted {
        currencies.insert(selectedCurrency, at: 0)
    }
    currencies.append(contentsOf: WalletContext.FiatCurrency.allCases.filter {
        !includedCurrencies.contains($0)
    }.sorted { $0.code < $1.code })

    return currencies.map { currency in
        return (currency, walletCurrencyName(currency, locale: appLocale))
    }
}

private let walletCurrencyLanguageCodes: Set<String> = Set(Locale.availableIdentifiers.map {
    (Locale(identifier: $0) as NSLocale).languageCode
})

private func walletCurrencyLanguageLocale(_ languageCode: String) -> Locale? {
    let languageCode = languageCode.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !languageCode.isEmpty else {
        return nil
    }
    let locale = Locale(identifier: Locale.canonicalIdentifier(from: languageCode))
    let language = (locale as NSLocale).languageCode
    guard language != "und", walletCurrencyLanguageCodes.contains(language) else {
        return nil
    }
    return locale
}

@available(iOS 16.0, *)
private func walletCurrencyForLocale(_ locale: Locale) -> WalletContext.FiatCurrency? {
    let nsLocale = locale as NSLocale
    let regionCode: String?
    if let explicitRegionCode = nsLocale.object(forKey: .countryCode) as? String {
        regionCode = explicitRegionCode
    } else {
        let identifier = Locale.Language(identifier: locale.identifier).maximalIdentifier
        regionCode = Locale(identifier: identifier).region?.identifier
    }
    guard let regionCode, let currencyCode = NSLocale(localeIdentifier: "und_\(regionCode)").currencyCode else {
        return nil
    }
    return WalletContext.FiatCurrency.allCases.first(where: { $0.code == currencyCode })
}

private func walletCurrencyName(_ currency: WalletContext.FiatCurrency, locale: Locale?) -> String {
    let code = currency.code
    if let name = locale?.localizedString(forCurrencyCode: code)?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty, name.caseInsensitiveCompare(code) != .orderedSame {
        return name
    }
    return Locale(identifier: "en").localizedString(forCurrencyCode: code) ?? code
}

final class WalletCurrencyListContextItem: ContextMenuCustomItem {
    let context: AccountContext
    let currencies: [WalletCurrencyListItem]
    let selectedCurrency: WalletContext.FiatCurrency
    let searchQuery: Signal<String, NoError>
    let currencySelected: (WalletContext.FiatCurrency) -> Void

    init(
        context: AccountContext,
        currencies: [WalletCurrencyListItem],
        selectedCurrency: WalletContext.FiatCurrency,
        searchQuery: Signal<String, NoError>,
        currencySelected: @escaping (WalletContext.FiatCurrency) -> Void
    ) {
        self.context = context
        self.currencies = currencies
        self.selectedCurrency = selectedCurrency
        self.searchQuery = searchQuery
        self.currencySelected = currencySelected
    }

    func node(
        presentationData: PresentationData,
        getController: @escaping () -> ContextControllerProtocol?,
        actionSelected: @escaping (ContextMenuActionResult) -> Void
    ) -> ContextMenuCustomNode {
        return WalletCurrencyListContextItemNode(
            presentationData: presentationData,
            item: self,
            getController: getController,
            actionSelected: actionSelected
        )
    }
}

private func walletCurrencySearchTokens(_ value: String) -> [String] {
    let normalizedValue = value
        .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
        .lowercased()
    return normalizedValue.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
}

private func filteredWalletCurrencies(_ currencies: [WalletCurrencyListItem], query: String) -> [WalletCurrencyListItem] {
    if query.isEmpty {
        return currencies
    }
    let queryTokens = walletCurrencySearchTokens(query)
    if queryTokens.isEmpty {
        return []
    }

    return currencies.filter { item in
        let itemTokens = walletCurrencySearchTokens("\(item.currency.code) \(item.name)")
        return queryTokens.allSatisfy { queryToken in
            return itemTokens.contains(where: { itemToken in
                return itemToken.hasPrefix(queryToken)
            })
        }
    }
}

private func walletCurrencyAction(
    item: WalletCurrencyListContextItem,
    currency: WalletCurrencyListItem
) -> ContextMenuActionItem {
    return ContextMenuActionItem(
        text: currency.currency.code,
        textLayout: .secondLineWithValue(currency.name),
        icon: { _ in
            return nil
        },
        additionalLeftIcon: { theme in
            if currency.currency == item.selectedCurrency {
                return generateTintedImage(
                    image: UIImage(bundleImageName: "Chat/Context Menu/Check"),
                    color: theme.contextMenu.primaryColor
                )
            } else {
                return UIImage()
            }
        },
        action: { _, dismiss in
            item.currencySelected(currency.currency)
            dismiss(.default)
        }
    )
}

private final class WalletCurrencyListContextItemNode: ASDisplayNode, ContextMenuCustomNode, ContextActionNodeProtocol, ASScrollViewDelegate {
    private enum ItemType {
        case currency(WalletCurrencyListItem)
        case noResults
    }

    private let item: WalletCurrencyListContextItem
    private let presentationData: PresentationData
    private let getController: () -> ContextControllerProtocol?
    private let actionSelected: (ContextMenuActionResult) -> Void

    private let scrollNode: ASScrollNode
    private let scrollMaskView: UIImageView
    private var actionNodes: [AnyHashable: ContextControllerActionsListActionItemNode] = [:]

    private var searchDisposable: Disposable?
    private var searchQuery = ""

    private var currencyItemHeight: CGFloat?
    private var noResultsItemHeight: CGFloat?
    private var totalContentHeight: CGFloat = 0.0
    private var maxWidth: CGFloat?

    let needsPadding: Bool = false

    init(
        presentationData: PresentationData,
        item: WalletCurrencyListContextItem,
        getController: @escaping () -> ContextControllerProtocol?,
        actionSelected: @escaping (ContextMenuActionResult) -> Void
    ) {
        self.item = item
        self.presentationData = presentationData.withUpdate(listsFontSize: .regular)
        self.getController = getController
        self.actionSelected = actionSelected
        self.scrollNode = ASScrollNode()
        self.scrollMaskView = UIImageView()

        let gradientHeight: CGFloat = 12.0
        let maskHeight = gradientHeight * 2.0 + 1.0
        self.scrollMaskView.image = generateGradientImage(
            size: CGSize(width: 1.0, height: maskHeight),
            colors: [
                UIColor(white: 1.0, alpha: 0.0),
                UIColor(white: 1.0, alpha: 1.0),
                UIColor(white: 1.0, alpha: 1.0),
                UIColor(white: 1.0, alpha: 0.0)
            ],
            locations: [0.0, gradientHeight / maskHeight, (gradientHeight + 1.0) / maskHeight, 1.0]
        )?.resizableImage(withCapInsets: UIEdgeInsets(top: gradientHeight, left: 0.0, bottom: gradientHeight, right: 0.0), resizingMode: .stretch)

        super.init()

        self.addSubnode(self.scrollNode)

        self.searchDisposable = (item.searchQuery
        |> deliverOnMainQueue).start(next: { [weak self] searchQuery in
            guard let self else {
                return
            }
            let updatedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard self.searchQuery != updatedQuery else {
                return
            }
            self.searchQuery = updatedQuery
            self.totalContentHeight = 0.0
            if self.scrollNode.view.contentOffset != .zero {
                self.scrollNode.view.setContentOffset(.zero, animated: false)
            }
            self.getController()?.requestLayout(transition: .immediate)
        })
    }

    deinit {
        self.searchDisposable?.dispose()
    }

    override func didLoad() {
        super.didLoad()

        self.view.mask = self.scrollMaskView

        self.scrollNode.view.delegate = self.wrappedScrollViewDelegate
        self.scrollNode.view.alwaysBounceVertical = false
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.scrollIndicatorInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 5.0, right: 0.0)
        self.scrollNode.view.scrollsToTop = false
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let maxWidth = self.maxWidth {
            self.updateScrolling(maxWidth: maxWidth)
        }
    }

    private func visibleItems(in scrollView: UIScrollView, constrainedWidth: CGFloat) -> [(id: AnyHashable, type: ItemType, frame: CGRect)] {
        let currencies = filteredWalletCurrencies(self.item.currencies, query: self.searchQuery)
        var items: [(id: AnyHashable, type: ItemType, frame: CGRect)] = []
        var yOffset: CGFloat = 0.0

        for currency in currencies {
            let height = self.currencyItemHeight ?? 60.0
            let frame = CGRect(x: 0.0, y: yOffset, width: constrainedWidth, height: height)
            items.append((AnyHashable(currency.currency.code), .currency(currency), frame))
            yOffset += height
        }

        if !self.searchQuery.isEmpty && currencies.isEmpty {
            let height = self.noResultsItemHeight ?? 42.0
            let frame = CGRect(x: 0.0, y: yOffset, width: constrainedWidth, height: height)
            items.append((AnyHashable("noResults"), .noResults, frame))
            yOffset += height
        }

        self.totalContentHeight = yOffset

        let visibleBounds = scrollView.bounds.insetBy(dx: 0.0, dy: -100.0)
        return items.filter { visibleBounds.intersects($0.frame) }
    }

    private func updateScrolling(maxWidth: CGFloat) {
        let scrollView = self.scrollNode.view
        let visibleItems = self.visibleItems(in: scrollView, constrainedWidth: scrollView.bounds.width)
        var validNodeIds = Set<AnyHashable>()
        var measuredNewHeight = false

        for (itemId, itemType, frame) in visibleItems {
            validNodeIds.insert(itemId)

            let action: ContextMenuActionItem
            switch itemType {
            case let .currency(currency):
                action = walletCurrencyAction(item: self.item, currency: currency)
            case .noResults:
                let noAction: ((ContextControllerProtocol?, @escaping (ContextMenuActionResult) -> Void) -> Void)? = nil
                action = ContextMenuActionItem(
                    text: self.presentationData.strings.Conversation_SearchNoResults,
                    textFont: .small,
                    icon: { _ in
                        return nil
                    },
                    action: noAction
                )
            }

            let actionNode: ContextControllerActionsListActionItemNode
            if let current = self.actionNodes[itemId] {
                actionNode = current
                actionNode.setItem(item: action)
            } else {
                actionNode = ContextControllerActionsListActionItemNode(
                    context: self.item.context,
                    getController: self.getController,
                    requestDismiss: self.actionSelected,
                    requestUpdateAction: { _, _ in },
                    item: action
                )
                self.actionNodes[itemId] = actionNode
                self.scrollNode.addSubnode(actionNode)
            }

            actionNode.frame = frame
            let (minSize, complete) = actionNode.update(
                presentationData: self.presentationData,
                constrainedSize: frame.size
            )
            switch itemType {
            case .currency:
                if self.currencyItemHeight == nil {
                    self.currencyItemHeight = minSize.height
                    measuredNewHeight = true
                }
            case .noResults:
                if self.noResultsItemHeight == nil {
                    self.noResultsItemHeight = minSize.height
                    measuredNewHeight = true
                }
            }
            complete(CGSize(width: maxWidth, height: minSize.height), .immediate)
        }

        var nodesToRemove: [AnyHashable] = []
        for (nodeId, node) in self.actionNodes {
            if !validNodeIds.contains(nodeId) {
                nodesToRemove.append(nodeId)
                node.removeFromSupernode()
            }
        }
        for nodeId in nodesToRemove {
            self.actionNodes.removeValue(forKey: nodeId)
        }

        self.scrollNode.view.contentSize = CGSize(width: scrollView.bounds.width, height: self.totalContentHeight)

        if measuredNewHeight {
            self.getController()?.requestLayout(transition: .animated(duration: 0.45, curve: .spring))
        }
    }

    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let minActionsWidth: CGFloat = 270.0
        let maxActionsWidth: CGFloat = 300.0
        let constrainedWidth = min(constrainedWidth, maxActionsWidth)
        let maxWidth = max(constrainedWidth, minActionsWidth)
        let maxHeight = min(280.0, max(0.0, constrainedHeight - 150.0))

        if self.totalContentHeight == 0.0 {
            let _ = self.visibleItems(in: UIScrollView(), constrainedWidth: constrainedWidth)
        }

        return (CGSize(width: maxWidth, height: min(maxHeight, self.totalContentHeight)), { size, transition in
            self.maxWidth = maxWidth
            transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: .zero, size: size))
            transition.updateFrame(view: self.scrollMaskView, frame: CGRect(origin: .zero, size: size))
            self.scrollNode.view.contentSize = CGSize(width: size.width, height: self.totalContentHeight)
            self.updateScrolling(maxWidth: maxWidth)
        })
    }

    func updateTheme(presentationData: PresentationData) {
    }

    var isActionEnabled: Bool {
        return true
    }

    func performAction() {
    }

    func setIsHighlighted(_ value: Bool) {
    }

    func canBeHighlighted() -> Bool {
        return false
    }

    func updateIsHighlighted(isHighlighted: Bool) {
    }

    func actionNode(at point: CGPoint) -> ContextActionNodeProtocol {
        return self
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        for actionNode in self.actionNodes.values {
            actionNode.updateIsHighlighted(isHighlighted: false)
        }
    }
}
