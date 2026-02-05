import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import PresentationDataUtils
import AccountContext
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import BalancedTextComponent
import BundleIconComponent
import Markdown
import TelegramStringFormatting
import PlainButtonComponent
import BlurredBackgroundComponent
import PremiumStarComponent
import TextFormat
import GiftItemComponent
import InAppPurchaseManager
import GiftViewScreen
import UndoUI
import ContextUI
import LottieComponent
import GiftLoadingShimmerView
import EdgeEffect
import GlassBackgroundComponent
import ContextUI

private let minimumCountToDisplayFilters = 18

public final class GiftStoreContentComponent: Component {
    let context: AccountContext
    let resaleGiftsContext: ResaleGiftsContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let dateTimeFormat: PresentationDateTimeFormat
    let safeInsets: UIEdgeInsets
    let statusBarHeight: CGFloat
    let navigationHeight: CGFloat
    let overNavigationContainer: UIView
    let starsContext: StarsContext
    let peerId: EnginePeer.Id
    let gift: StarGift.Gift
    let isPlain: Bool
    let confirmPurchaseImmediately: Bool
    let starsTopUpOptions: Signal<[StarsTopUpOption]?, NoError>?
    let scrollToTop: () -> Void
    let controller: () -> ViewController?
    let completion: ((StarGift.UniqueGift) -> Void)?
    
    public init(
        context: AccountContext,
        resaleGiftsContext: ResaleGiftsContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        dateTimeFormat: PresentationDateTimeFormat,
        safeInsets: UIEdgeInsets,
        statusBarHeight: CGFloat,
        navigationHeight: CGFloat,
        overNavigationContainer: UIView,
        starsContext: StarsContext,
        peerId: EnginePeer.Id,
        gift: StarGift.Gift,
        isPlain: Bool,
        confirmPurchaseImmediately: Bool,
        starsTopUpOptions: Signal<[StarsTopUpOption]?, NoError>?,
        scrollToTop: @escaping () -> Void,
        controller: @escaping () -> ViewController?,
        completion: ((StarGift.UniqueGift) -> Void)?
    ) {
        self.context = context
        self.resaleGiftsContext = resaleGiftsContext
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.safeInsets = safeInsets
        self.statusBarHeight = statusBarHeight
        self.navigationHeight = navigationHeight
        self.overNavigationContainer = overNavigationContainer
        self.starsContext = starsContext
        self.peerId = peerId
        self.gift = gift
        self.isPlain = isPlain
        self.confirmPurchaseImmediately = confirmPurchaseImmediately
        self.starsTopUpOptions = starsTopUpOptions
        self.scrollToTop = scrollToTop
        self.controller = controller
        self.completion = completion
    }

    public static func ==(lhs: GiftStoreContentComponent, rhs: GiftStoreContentComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.gift != rhs.gift {
            return false
        }
        if lhs.safeInsets != rhs.safeInsets {
            return false
        }
        if lhs.statusBarHeight != rhs.statusBarHeight {
            return false
        }
        if lhs.navigationHeight != rhs.navigationHeight {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let loadingView = GiftLoadingShimmerView()
        private let emptyResultsAnimation = ComponentView<Empty>()
        private let emptyResultsTitle = ComponentView<Empty>()
        private let clearFilters = ComponentView<Empty>()
        
        private var giftItems: [AnyHashable: ComponentView<Empty>] = [:]
        private let filterSelector = ComponentView<Empty>()
        
        private var initialCount: Int32?
        private var showLoading = true
        
        private var selectedFilterId: AnyHashable?
        
        private var starGiftsDisposable: Disposable?
        fileprivate var starGiftsContext: ResaleGiftsContext?
        fileprivate var starGiftsState: ResaleGiftsContext.State?
        
        private var component: GiftStoreContentComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        private var isUpdating: Bool = false
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addSubview(self.loadingView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.starGiftsDisposable?.dispose()
        }
        
        private var currentGifts: ([StarGift], Set<String>, Set<String>, Set<String>)?
        private var effectiveGifts: [StarGift]? {
            if let gifts = self.starGiftsState?.gifts {
                return gifts
            } else {
                return nil
            }
        }
        
        private var effectiveIsLoading: Bool {
            if self.starGiftsState?.gifts == nil || self.starGiftsState?.dataState == .loading {
                return true
            }
            return false
        }
        
        private var currentBounds: CGRect?
        private var contentHeight: CGFloat = 0.0
        public func updateScrolling(bounds: CGRect, interactive: Bool = false, transition: ComponentTransition) {
            guard let component = self.component else {
                return
            }
            self.currentBounds = bounds
                        
            let availableWidth = bounds.width
            let availableHeight = bounds.height
            
            var topInset = component.navigationHeight + 53.0
            if let initialCount = self.initialCount, initialCount < minimumCountToDisplayFilters {
                topInset = component.navigationHeight
            }
            
            let visibleBounds = bounds.insetBy(dx: 0.0, dy: -10.0)
            if let starGifts = self.effectiveGifts {
                let sideInset: CGFloat = 16.0 + component.safeInsets.left
                
                let optionSpacing: CGFloat = 10.0
                let optionWidth = (availableWidth - sideInset * 2.0 - optionSpacing * 2.0) / 3.0
                let starsOptionSize = CGSize(width: optionWidth, height: 154.0)
                
                var validIds: [AnyHashable] = []
                var itemFrame = CGRect(origin: CGPoint(x: sideInset, y: topInset + 9.0), size: starsOptionSize)
                
                let controller = component.controller
                
                for gift in starGifts {
                    guard case let .unique(uniqueGift) = gift else {
                        continue
                    }
                    var isVisible = false
                    if visibleBounds.intersects(itemFrame) {
                        isVisible = true
                    }
                    
                    if isVisible {
                        let itemId = AnyHashable(gift.id)
                        validIds.append(itemId)
                        
                        var itemTransition = transition
                        let visibleItem: ComponentView<Empty>
                        if let current = self.giftItems[itemId] {
                            visibleItem = current
                        } else {
                            visibleItem = ComponentView()
                            if !transition.animation.isImmediate {
                                itemTransition = .immediate
                            }
                            self.giftItems[itemId] = visibleItem
                        }
                        
                        var ribbon: GiftItemComponent.Ribbon?
                        var ribbonColor: GiftItemComponent.Ribbon.Color = .blue
                        for attribute in uniqueGift.attributes {
                            if case let .backdrop(_, _, innerColor, outerColor, _, _, _) = attribute {
                                ribbonColor = .custom(outerColor, innerColor)
                                break
                            }
                        }
                        ribbon = GiftItemComponent.Ribbon(
                            text: "#\(uniqueGift.number)",
                            font: .monospaced,
                            color: ribbonColor
                        )
                                                
                        let subject: GiftItemComponent.Subject = .uniqueGift(
                            gift: uniqueGift,
                            price: "# \(presentationStringsFormattedNumber(Int32(uniqueGift.resellAmounts?.first(where: { $0.currency == .stars })?.amount.value ?? 0), component.dateTimeFormat.groupingSeparator))"
                        )
                        let _ = visibleItem.update(
                            transition: itemTransition,
                            component: AnyComponent(
                                PlainButtonComponent(
                                    content: AnyComponent(
                                        GiftItemComponent(
                                            context: component.context,
                                            style: .glass,
                                            theme: component.theme,
                                            strings: component.strings,
                                            peer: nil,
                                            subject: subject,
                                            ribbon: ribbon
                                        )
                                    ),
                                    effectAlignment: .center,
                                    action: { [weak self] in
                                        guard let self, let component = self.component else {
                                            return
                                        }
                                        if component.confirmPurchaseImmediately, let starsTopUpOptions = component.starsTopUpOptions {
                                            buyStarGiftImpl(
                                                context: component.context,
                                                recipientPeerId: component.context.account.peerId,
                                                uniqueGift: uniqueGift,
                                                showAttributes: true,
                                                acceptedPrice: nil,
                                                skipConfirmation: false,
                                                starsTopUpOptions: starsTopUpOptions,
                                                buyGift: { [weak self] slug, peerId, price in
                                                    return self?.starGiftsContext?.buyStarGift(slug: slug, peerId: peerId, price: price) ?? .complete()
                                                },
                                                getController: controller,
                                                updateProgress: { _ in },
                                                updateIsBalanceVisible: { _ in },
                                                completion: { [weak self] in
                                                    if let self, let component = self.component {
                                                        component.completion?(uniqueGift)
                                                    }
                                                }
                                            )
                                        } else {
                                            if let controller = controller() {
                                                let mainController: ViewController
                                                if let controller = controller as? GiftStoreScreen,
                                                   let parentController = controller.parentController() {
                                                    mainController = parentController
                                                } else {
                                                    mainController = controller
                                                }
                                                
                                                let allSubjects: [GiftViewScreen.Subject] = (self.effectiveGifts ?? []).compactMap { gift in
                                                    if case let .unique(uniqueGift) = gift {
                                                        return .uniqueGift(uniqueGift, component.peerId)
                                                    }
                                                    return nil
                                                }
                                                let index = self.effectiveGifts?.firstIndex(where: { $0 == .unique(uniqueGift) }) ?? 0
                                                
                                                let giftController = GiftViewScreen(
                                                    context: component.context,
                                                    subject: .uniqueGift(uniqueGift, component.peerId),
                                                    allSubjects: allSubjects,
                                                    index: index,
                                                    buyGift: { slug, peerId, price in
                                                        return self.starGiftsContext?.buyStarGift(slug: slug, peerId: peerId, price: price) ?? .complete()
                                                    },
                                                    updateResellStars: { _, price in
                                                        return self.starGiftsContext?.updateStarGiftResellPrice(slug: uniqueGift.slug, price: price) ?? .complete()
                                                    }
                                                )
                                                mainController.push(giftController)
                                            }
                                        }
                                    },
                                    animateAlpha: false
                                )
                            ),
                            environment: {
                            },
                            containerSize: starsOptionSize
                        )
                        if let itemView = visibleItem.view {
                            if itemView.superview == nil {
                                if let _ = self.loadingView.superview {
                                    self.insertSubview(itemView, belowSubview: self.loadingView)
                                } else {
                                    self.addSubview(itemView)
                                }
                            }
                            itemTransition.setFrame(view: itemView, frame: itemFrame)
                        }
                    }
                    itemFrame.origin.x += itemFrame.width + optionSpacing
                    if itemFrame.maxX > availableWidth {
                        itemFrame.origin.x = sideInset
                        itemFrame.origin.y += starsOptionSize.height + optionSpacing
                    }
                }
                
                var removeIds: [AnyHashable] = []
                for (id, item) in self.giftItems {
                    if !validIds.contains(id) {
                        removeIds.append(id)
                        if let itemView = item.view {
                            if !transition.animation.isImmediate {
                                itemView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.25, removeOnCompletion: false)
                                itemView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                                    itemView.removeFromSuperview()
                                })
                            } else {
                                itemView.removeFromSuperview()
                            }
                        }
                    }
                }
                for id in removeIds {
                    self.giftItems.removeValue(forKey: id)
                }
            }
            
            let fadeTransition = ComponentTransition.easeInOut(duration: 0.25)
            let emptyResultsActionSize = self.clearFilters.update(
                transition: .immediate,
                component: AnyComponent(
                    PlainButtonComponent(
                        content: AnyComponent(
                            MultilineTextComponent(
                                text: .plain(NSAttributedString(string: component.strings.Gift_Store_ClearFilters, font: Font.regular(17.0), textColor: component.theme.list.itemAccentColor)),
                                horizontalAlignment: .center,
                                maximumNumberOfLines: 0
                            )
                        ),
                        effectAlignment: .center,
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.showLoading = true
                            self.starGiftsContext?.updateFilterAttributes([])
                            component.scrollToTop()
                        },
                        animateScale: false
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableWidth - 44.0 * 2.0, height: 100.0)
            )
            
            var showClearFilters = false
            if let filterAttributes = self.starGiftsState?.filterAttributes, !filterAttributes.isEmpty {
                showClearFilters = true
            }
            
            let bottomInset: CGFloat = component.safeInsets.bottom
            
            var emptyResultsActionFrame = CGRect(
                origin: CGPoint(
                    x: floorToScreenPixels((availableWidth - emptyResultsActionSize.width) / 2.0),
                    y: max(self.contentHeight - 70.0, availableHeight - bottomInset - emptyResultsActionSize.height - 16.0)
                ),
                size: emptyResultsActionSize
            )
            
            if let effectiveGifts = self.effectiveGifts, effectiveGifts.isEmpty && self.starGiftsState?.dataState != .loading {
                let emptyAnimationHeight = 148.0
                let visibleHeight = availableHeight
                let emptyAnimationSpacing: CGFloat = 20.0
                let emptyTextSpacing: CGFloat = 18.0
                                                                
                let emptyResultsTitleSize = self.emptyResultsTitle.update(
                    transition: .immediate,
                    component: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(NSAttributedString(string: component.strings.Gift_Store_EmptyResults, font: Font.semibold(17.0), textColor: component.theme.list.itemPrimaryTextColor)),
                            horizontalAlignment: .center
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: availableWidth, height: 100.0)
                )
               
                let emptyResultsAnimationSize = self.emptyResultsAnimation.update(
                    transition: .immediate,
                    component: AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(name: "ChatListNoResults")
                    )),
                    environment: {},
                    containerSize: CGSize(width: emptyAnimationHeight, height: emptyAnimationHeight)
                )
      
                let emptyTotalHeight = emptyAnimationHeight + emptyAnimationSpacing + emptyResultsTitleSize.height + emptyResultsActionSize.height + emptyTextSpacing
                let emptyAnimationY = topInset + floorToScreenPixels((visibleHeight - topInset - bottomInset - emptyTotalHeight) / 2.0)
                
                let emptyResultsAnimationFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableWidth - emptyResultsAnimationSize.width) / 2.0), y: emptyAnimationY), size: emptyResultsAnimationSize)
                
                let emptyResultsTitleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableWidth - emptyResultsTitleSize.width) / 2.0), y: emptyResultsAnimationFrame.maxY + emptyAnimationSpacing), size: emptyResultsTitleSize)
                
                emptyResultsActionFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableWidth - emptyResultsActionSize.width) / 2.0), y: emptyResultsTitleFrame.maxY + emptyTextSpacing), size: emptyResultsActionSize)
                
                if let view = self.emptyResultsAnimation.view as? LottieComponent.View {
                    if view.superview == nil {
                        view.alpha = 0.0
                        fadeTransition.setAlpha(view: view, alpha: 1.0)
                        self.addSubview(view)
                        view.playOnce()
                    }
                    view.bounds = CGRect(origin: .zero, size: emptyResultsAnimationFrame.size)
                    ComponentTransition.immediate.setPosition(view: view, position: emptyResultsAnimationFrame.center)
                }
                if let view = self.emptyResultsTitle.view {
                    if view.superview == nil {
                        view.alpha = 0.0
                        fadeTransition.setAlpha(view: view, alpha: 1.0)
                        self.addSubview(view)
                    }
                    view.bounds = CGRect(origin: .zero, size: emptyResultsTitleFrame.size)
                    ComponentTransition.immediate.setPosition(view: view, position: emptyResultsTitleFrame.center)
                }
            } else {
                if let view = self.emptyResultsAnimation.view {
                    fadeTransition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                        view.removeFromSuperview()
                    })
                }
                if let view = self.emptyResultsTitle.view {
                    fadeTransition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                        view.removeFromSuperview()
                    })
                }
            }
            
            if showClearFilters {
                if let view = self.clearFilters.view {
                    if view.superview == nil {
                        view.alpha = 0.0
                        fadeTransition.setAlpha(view: view, alpha: 1.0)
                        self.addSubview(view)
                    }
                    view.bounds = CGRect(origin: .zero, size: emptyResultsActionFrame.size)
                    ComponentTransition.immediate.setPosition(view: view, position: emptyResultsActionFrame.center)
                    
                    view.alpha = self.starGiftsState?.attributes.isEmpty == true ? 0.0 : 1.0
                }
            } else {
                if let view = self.clearFilters.view {
                    fadeTransition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                        view.removeFromSuperview()
                    })
                }
            }
            
            let bottomContentOffset = max(0.0, self.contentHeight - bounds.origin.y - bounds.height)
            if interactive, bottomContentOffset < 800.0 {
                self.starGiftsContext?.loadMore()
            }
        }
        
        func openSortContextMenu(sourceView: UIView) {
            guard let component = self.component, let controller = component.controller(), !self.effectiveIsLoading else {
                return
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            var items: [ContextMenuItem] = []
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Gift_Store_SortByPrice, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Peer Info/SortValue"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, f in
                f(.default)
                guard let self else {
                    return
                }
                self.showLoading = true
                self.starGiftsContext?.updateSorting(.value)
                component.scrollToTop()
            })))
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Gift_Store_SortByDate, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Peer Info/SortDate"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, f in
                f(.default)
                guard let self else {
                    return
                }
                self.showLoading = true
                self.starGiftsContext?.updateSorting(.date)
                component.scrollToTop()
            })))
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Gift_Store_SortByNumber, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Peer Info/SortNumber"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, f in
                f(.default)
                guard let self else {
                    return
                }
                self.showLoading = true
                self.starGiftsContext?.updateSorting(.number)
                component.scrollToTop()
            })))
            
            let contextController = makeContextController(presentationData: presentationData, source: .reference(GiftStoreReferenceContentSource(controller: controller, sourceView: sourceView)), items: .single(ContextController.Items(content: .list(items))), gesture: nil)
            contextController.dismissed = { [weak self] in
                guard let self else {
                    return
                }
                self.selectedFilterId = nil
                self.state?.updated()
            }
            controller.presentInGlobalOverlay(contextController)
        }
        
        func openModelContextMenu(sourceView: UIView) {
            guard let component = self.component, let controller = self.component?.controller(), !self.effectiveIsLoading else {
                return
            }
                        
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let searchQueryPromise = ValuePromise<String>("")
            
            let attributes = self.starGiftsState?.attributes ?? []
            let modelAttributes = attributes.filter { attribute in
                if case let .model(_, _, _, crafted) = attribute {
                    if component.resaleGiftsContext.forCrafting && crafted {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            }.sorted(by: { lhs, rhs in
                if case let .model(_, lhsFile, _, _) = lhs, case let .model(_, rhsFile, _, _) = rhs, let lhsCount = self.starGiftsState?.attributeCount[.model(lhsFile.fileId.id)], let rhsCount = self.starGiftsState?.attributeCount[.model(rhsFile.fileId.id)] {
                    return lhsCount > rhsCount
                } else {
                    return false
                }
            })
            
            let currentFilterAttributes = self.starGiftsState?.filterAttributes ?? []
            let selectedModelAttributes = currentFilterAttributes.filter { attribute in
                if case .model = attribute {
                    return true
                } else {
                    return false
                }
            }
            
            var items: [ContextMenuItem] = []
            if modelAttributes.count >= 8 {
                items.append(.custom(SearchContextItem(
                    context: component.context,
                    placeholder: presentationData.strings.Gift_Store_Search,
                    value: "",
                    valueChanged: { value in
                        searchQueryPromise.set(value)
                    }
                ), false))
                items.append(.separator)
            }
            items.append(.custom(GiftAttributeListContextItem(
                context: component.context,
                attributes: modelAttributes,
                selectedAttributes: selectedModelAttributes,
                attributeCount: self.starGiftsState?.attributeCount ?? [:],
                searchQuery: searchQueryPromise.get(),
                attributeSelected: { [weak self] attribute, exclusive in
                    guard let self else {
                        return
                    }
                    var updatedFilterAttributes: [ResaleGiftsContext.Attribute]
                    if exclusive {
                        updatedFilterAttributes = currentFilterAttributes.filter { attribute in
                            if case .model = attribute {
                                return false
                            }
                            return true
                        }
                        updatedFilterAttributes.append(attribute)
                    } else {
                        updatedFilterAttributes = currentFilterAttributes
                        if selectedModelAttributes.contains(attribute) {
                            updatedFilterAttributes.removeAll(where: { $0 == attribute })
                        } else {
                            updatedFilterAttributes.append(attribute)
                        }
                    }
                    self.showLoading = true
                    self.starGiftsContext?.updateFilterAttributes(updatedFilterAttributes)
                    component.scrollToTop()
                },
                selectAll: { [weak self] in
                    guard let self else {
                        return
                    }
                    let updatedFilterAttributes = currentFilterAttributes.filter { attribute in
                        if case .model = attribute {
                            return false
                        }
                        return true
                    }
                    self.showLoading = true
                    self.starGiftsContext?.updateFilterAttributes(updatedFilterAttributes)
                    component.scrollToTop()
                }
            ), false))
            
            let contextController = makeContextController(
                context: component.context,
                presentationData: presentationData,
                source: .reference(GiftStoreReferenceContentSource(controller: controller, sourceView: sourceView)),
                items: .single(ContextController.Items(content: .list(items))),
                gesture: nil
            )
            contextController.dismissed = { [weak self] in
                guard let self else {
                    return
                }
                self.selectedFilterId = nil
                self.state?.updated()
            }
            controller.presentInGlobalOverlay(contextController)
        }
        
        func openBackdropContextMenu(sourceView: UIView) {
            guard let component = self.component, let controller = self.component?.controller(), !self.effectiveIsLoading else {
                return
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let searchQueryPromise = ValuePromise<String>("")
            
            let attributes = self.starGiftsState?.attributes ?? []
            let backdropAttributes = attributes.filter { attribute in
                if case .backdrop = attribute {
                    return true
                } else {
                    return false
                }
            }.sorted(by: { lhs, rhs in
                if case let .backdrop(_, lhsId, _, _, _, _, _) = lhs, case let .backdrop(_, rhsId, _, _, _, _, _) = rhs, let lhsCount = self.starGiftsState?.attributeCount[.backdrop(lhsId)], let rhsCount = self.starGiftsState?.attributeCount[.backdrop(rhsId)] {
                    return lhsCount > rhsCount
                } else {
                    return false
                }
            })
            
            let currentFilterAttributes = self.starGiftsState?.filterAttributes ?? []
            let selectedBackdropAttributes = currentFilterAttributes.filter { attribute in
                if case .backdrop = attribute {
                    return true
                } else {
                    return false
                }
            }
            
            var items: [ContextMenuItem] = []
            if backdropAttributes.count >= 8 {
                items.append(.custom(SearchContextItem(
                    context: component.context,
                    placeholder: presentationData.strings.Gift_Store_Search,
                    value: "",
                    valueChanged: { value in
                        searchQueryPromise.set(value)
                    }
                ), false))
                items.append(.separator)
            }
            items.append(.custom(GiftAttributeListContextItem(
                context: component.context,
                attributes: backdropAttributes,
                selectedAttributes: selectedBackdropAttributes,
                attributeCount: self.starGiftsState?.attributeCount ?? [:],
                searchQuery: searchQueryPromise.get(),
                attributeSelected: { [weak self] attribute, exclusive in
                    guard let self else {
                        return
                    }
                    var updatedFilterAttributes: [ResaleGiftsContext.Attribute]
                    if exclusive {
                        updatedFilterAttributes = currentFilterAttributes.filter { attribute in
                            if case .backdrop = attribute {
                                return false
                            }
                            return true
                        }
                        updatedFilterAttributes.append(attribute)
                    } else {
                        updatedFilterAttributes = currentFilterAttributes
                        if selectedBackdropAttributes.contains(attribute) {
                            updatedFilterAttributes.removeAll(where: { $0 == attribute })
                        } else {
                            updatedFilterAttributes.append(attribute)
                        }
                    }
                    self.showLoading = true
                    self.starGiftsContext?.updateFilterAttributes(updatedFilterAttributes)
                    component.scrollToTop()
                },
                selectAll: { [weak self] in
                    guard let self else {
                        return
                    }
                    let updatedFilterAttributes = currentFilterAttributes.filter { attribute in
                        if case .backdrop = attribute {
                            return false
                        }
                        return true
                    }
                    self.showLoading = true
                    self.starGiftsContext?.updateFilterAttributes(updatedFilterAttributes)
                    component.scrollToTop()
                }
            ), false))
            
            let contextController = makeContextController(
                context: component.context,
                presentationData: presentationData,
                source: .reference(GiftStoreReferenceContentSource(controller: controller, sourceView: sourceView)),
                items: .single(ContextController.Items(content: .list(items))),
                gesture: nil
            )
            contextController.dismissed = { [weak self] in
                guard let self else {
                    return
                }
                self.selectedFilterId = nil
                self.state?.updated()
            }
            controller.presentInGlobalOverlay(contextController)
        }
        
        func openSymbolContextMenu(sourceView: UIView) {
            guard let component = self.component, let controller = self.component?.controller(), !self.effectiveIsLoading else {
                return
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let searchQueryPromise = ValuePromise<String>("")
            
            let attributes = self.starGiftsState?.attributes ?? []
            let patternAttributes = attributes.filter { attribute in
                if case .pattern = attribute {
                    return true
                } else {
                    return false
                }
            }.sorted(by: { lhs, rhs in
                if case let .pattern(_, lhsFile, _) = lhs, case let .pattern(_, rhsFile, _) = rhs, let lhsCount = self.starGiftsState?.attributeCount[.pattern(lhsFile.fileId.id)], let rhsCount = self.starGiftsState?.attributeCount[.pattern(rhsFile.fileId.id)] {
                    return lhsCount > rhsCount
                } else {
                    return false
                }
            })
            
            let currentFilterAttributes = self.starGiftsState?.filterAttributes ?? []
            let selectedPatternAttributes = currentFilterAttributes.filter { attribute in
                if case .pattern = attribute {
                    return true
                } else {
                    return false
                }
            }
            
            var items: [ContextMenuItem] = []
            if patternAttributes.count >= 8 {
                items.append(.custom(SearchContextItem(
                    context: component.context,
                    placeholder: presentationData.strings.Gift_Store_Search,
                    value: "",
                    valueChanged: { value in
                        searchQueryPromise.set(value)
                    }
                ), false))
                items.append(.separator)
            }
            items.append(.custom(GiftAttributeListContextItem(
                context: component.context,
                attributes: patternAttributes,
                selectedAttributes: selectedPatternAttributes,
                attributeCount: self.starGiftsState?.attributeCount ?? [:],
                searchQuery: searchQueryPromise.get(),
                attributeSelected: { [weak self] attribute, exclusive in
                    guard let self else {
                        return
                    }
                    var updatedFilterAttributes: [ResaleGiftsContext.Attribute]
                    if exclusive {
                        updatedFilterAttributes = currentFilterAttributes.filter { attribute in
                            if case .pattern = attribute {
                                return false
                            }
                            return true
                        }
                        updatedFilterAttributes.append(attribute)
                    } else {
                        updatedFilterAttributes = currentFilterAttributes
                        if selectedPatternAttributes.contains(attribute) {
                            updatedFilterAttributes.removeAll(where: { $0 == attribute })
                        } else {
                            updatedFilterAttributes.append(attribute)
                        }
                    }
                    self.showLoading = true
                    self.starGiftsContext?.updateFilterAttributes(updatedFilterAttributes)
                    component.scrollToTop()
                },
                selectAll: { [weak self] in
                    guard let self else {
                        return
                    }
                    let updatedFilterAttributes = currentFilterAttributes.filter { attribute in
                        if case .pattern = attribute {
                            return false
                        }
                        return true
                    }
                    self.showLoading = true
                    self.starGiftsContext?.updateFilterAttributes(updatedFilterAttributes)
                    component.scrollToTop()
                }
            ), false))
            
            let contextController = makeContextController(
                context: component.context,
                presentationData: presentationData,
                source: .reference(GiftStoreReferenceContentSource(controller: controller, sourceView: sourceView)),
                items: .single(ContextController.Items(content: .list(items))),
                gesture: nil
            )
            contextController.dismissed = { [weak self] in
                guard let self else {
                    return
                }
                self.selectedFilterId = nil
                self.state?.updated()
            }
            controller.presentInGlobalOverlay(contextController)
        }
        
        func update(component: GiftStoreContentComponent, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            self.state = state
            
            if self.component == nil {
                self.starGiftsContext = component.resaleGiftsContext
                self.starGiftsDisposable = (self.starGiftsContext!.state
                |> deliverOnMainQueue).start(next: { [weak self] state in
                    guard let self else {
                        return
                    }
                    let previousFilterAttributes = self.starGiftsState?.filterAttributes
                    let previousSorting = self.starGiftsState?.sorting
                    let previousDataState = self.starGiftsState?.dataState
                    let previousItems = self.starGiftsState?.gifts
                    self.starGiftsState = state
                    
                    var transition: ComponentTransition = .immediate
                    if let previousFilterAttributes, previousFilterAttributes != state.filterAttributes {
                        transition = .easeInOut(duration: 0.25)
                    } else if let previousSorting, previousSorting != state.sorting {
                        transition = .easeInOut(duration: 0.25)
                    }
                    
                    if previousItems?.isEmpty == true, case .loading = previousDataState, component.confirmPurchaseImmediately {
                        transition = .spring(duration: 0.3)
                    }
                    
                    if !self.isUpdating {
                        self.state?.updated(transition: transition)
                    }
                })
            }
            self.component = component
            
            if let count = self.starGiftsState?.count, count > 0 {
                if self.initialCount == nil {
                    self.initialCount = count
                }
            }
            
            let isLoading = self.effectiveIsLoading
            if case let .ready(loadMore, nextOffset) = self.starGiftsState?.dataState {
                if loadMore && nextOffset == nil {
                } else {
                    self.showLoading = false
                }
            }
            
            let theme = component.theme
            let strings = component.strings
                                    
            let bottomContentInset: CGFloat = 56.0
            let sideInset: CGFloat = 16.0 + component.safeInsets.left
                        
            var contentHeight: CGFloat = 0.0
            contentHeight += component.navigationHeight
            
            var topInset: CGFloat = 0.0
            if component.statusBarHeight > 0.0 {
                topInset = component.statusBarHeight - 6.0
            }
            
            let optionSpacing: CGFloat = 10.0
            let optionWidth = (availableSize.width - sideInset * 2.0 - optionSpacing * 2.0) / 3.0
                         
            var sortingTitle = strings.Gift_Store_Sort_Date
            var sortingIcon: String = "GiftFilterDate"
            var sortingIndex: Int = 0
            if let sorting = self.starGiftsState?.sorting {
                switch sorting {
                case .value:
                    sortingTitle = component.strings.Gift_Store_Sort_Price
                    sortingIcon = "GiftFilterPrice"
                    sortingIndex = 0
                case .date:
                    sortingTitle = component.strings.Gift_Store_Sort_Date
                    sortingIcon = "GiftFilterDate"
                    sortingIndex = 1
                case .number:
                    sortingTitle = component.strings.Gift_Store_Sort_Number
                    sortingIcon = "GiftFilterNumber"
                    sortingIndex = 2
                }
            }
            
            enum FilterItemId: Int32 {
                case sort
                case model
                case backdrop
                case symbol
            }
            
            var filterItems: [FilterSelectorComponent.Item] = []
            filterItems.append(FilterSelectorComponent.Item(
                id: AnyHashable(FilterItemId.sort),
                index: sortingIndex,
                iconName: sortingIcon,
                title: sortingTitle,
                action: { [weak self] view in
                    if let self {
                        self.selectedFilterId = AnyHashable(FilterItemId.sort)
                        self.openSortContextMenu(sourceView: view)
                        self.state?.updated()
                    }
                }
            ))
            
            var modelTitle = component.strings.Gift_Store_Filter_Model
            var backdropTitle = component.strings.Gift_Store_Filter_Backdrop
            var symbolTitle = component.strings.Gift_Store_Filter_Symbol
            var modelCount: Int32 = 0
            var backdropCount: Int32 = 0
            var symbolCount: Int32 = 0
            if let filterAttributes = self.starGiftsState?.filterAttributes {
                for attribute in filterAttributes {
                    switch attribute {
                    case .model:
                        modelCount += 1
                    case .backdrop:
                        backdropCount += 1
                    case .pattern:
                        symbolCount += 1
                    }
                }
                
                if modelCount > 0 {
                    modelTitle = component.strings.Gift_Store_Filter_Selected_Model(modelCount)
                }
                if backdropCount > 0 {
                    backdropTitle = component.strings.Gift_Store_Filter_Selected_Backdrop(backdropCount)
                }
                if symbolCount > 0 {
                    symbolTitle = component.strings.Gift_Store_Filter_Selected_Symbol(symbolCount)
                }
            }
            
            filterItems.append(FilterSelectorComponent.Item(
                id: AnyHashable(FilterItemId.model),
                index: Int(modelCount),
                title: modelTitle,
                action: { [weak self] view in
                    if let self {
                        self.selectedFilterId = AnyHashable(FilterItemId.model)
                        self.openModelContextMenu(sourceView: view)
                        self.state?.updated()
                    }
                }
            ))
            filterItems.append(FilterSelectorComponent.Item(
                id: AnyHashable(FilterItemId.backdrop),
                index: Int(backdropCount),
                title: backdropTitle,
                action: { [weak self] view in
                    if let self {
                        self.selectedFilterId = AnyHashable(FilterItemId.backdrop)
                        self.openBackdropContextMenu(sourceView: view)
                        self.state?.updated()
                    }
                }
            ))
            filterItems.append(FilterSelectorComponent.Item(
                id: AnyHashable(FilterItemId.symbol),
                index: Int(symbolCount),
                title: symbolTitle,
                action: { [weak self] view in
                    if let self {
                        self.selectedFilterId = AnyHashable(FilterItemId.symbol)
                        self.openSymbolContextMenu(sourceView: view)
                        self.state?.updated()
                    }
                }
            ))
                        
            let loadingTransition: ComponentTransition = .easeInOut(duration: 0.25)
            
            var showingFilters = false
            let filterSize = self.filterSelector.update(
                transition: transition,
                component: AnyComponent(FilterSelectorComponent(
                    context: component.context,
                    theme: theme,
                    items: filterItems,
                    selectedItemId: self.selectedFilterId
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 10.0 * 2.0, height: 50.0)
            )
            if let filterSelectorView = self.filterSelector.view {
                if filterSelectorView.superview == nil {
                    filterSelectorView.alpha = 0.0
                    component.overNavigationContainer.addSubview(filterSelectorView)
                }
                transition.setFrame(view: filterSelectorView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - filterSize.width) / 2.0), y: topInset + 60.0 + 18.0), size: filterSize))
                
                if let initialCount = self.initialCount, initialCount >= minimumCountToDisplayFilters {
                    loadingTransition.setAlpha(view: filterSelectorView, alpha: 1.0)
                    showingFilters = true
                }
            }
            
            if let starGifts = self.starGiftsState?.gifts {
                let starsOptionSize = CGSize(width: optionWidth, height: 154.0)
                let optionSpacing: CGFloat = 10.0
                contentHeight += ceil(CGFloat(starGifts.count) / 3.0) * (starsOptionSize.height + optionSpacing)
                contentHeight += -optionSpacing + 66.0
            }
            
            contentHeight += bottomContentInset
            contentHeight += component.safeInsets.bottom
            
            self.contentHeight = contentHeight
                        
            self.updateScrolling(bounds: self.currentBounds ?? .zero, transition: transition)
                        
            let loadingSize = CGSize(width: availableSize.width, height: min(1000.0, availableSize.height))
            if isLoading && self.showLoading {
                self.loadingView.update(size: loadingSize, theme: component.theme, showFilters: !showingFilters, isPlain: component.isPlain, transition: .immediate)
                loadingTransition.setAlpha(view: self.loadingView, alpha: 1.0)
            } else {
                loadingTransition.setAlpha(view: self.loadingView, alpha: 0.0)
            }
            transition.setFrame(view: self.loadingView, frame: CGRect(origin: CGPoint(x: 0.0, y: component.navigationHeight + 10.0), size: loadingSize))
                
            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }
    
    public func makeView() -> View {
        return View()
    }
            
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class GiftStoreScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let resaleGiftsContext: ResaleGiftsContext
    let overNavigationContainer: UIView
    let starsContext: StarsContext
    let peerId: EnginePeer.Id
    let gift: StarGift.Gift
    
    init(
        context: AccountContext,
        resaleGiftsContext: ResaleGiftsContext,
        overNavigationContainer: UIView,
        starsContext: StarsContext,
        peerId: EnginePeer.Id,
        gift: StarGift.Gift
    ) {
        self.context = context
        self.resaleGiftsContext = resaleGiftsContext
        self.overNavigationContainer = overNavigationContainer
        self.starsContext = starsContext
        self.peerId = peerId
        self.gift = gift
    }

    static func ==(lhs: GiftStoreScreenComponent, rhs: GiftStoreScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.gift != rhs.gift {
            return false
        }
        return true
    }
    
    private final class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
     
    final class View: UIView, UIScrollViewDelegate {
        private let scrollView: ScrollView
        
        private let edgeEffectView: EdgeEffectView
        
        private let balance = ComponentView<Empty>()
        private let balanceBackgroundView: GlassContextExtractableContainer
        
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        private let content = ComponentView<Empty>()
                
        private var starsStateDisposable: Disposable?
        private var starsState: StarsContext.State?
        
        private var initialCount: Int32?
        
        private var component: GiftStoreScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        private var isUpdating: Bool = false
        
        override init(frame: CGRect) {
            self.balanceBackgroundView = GlassContextExtractableContainer()
            
            self.scrollView = ScrollView()
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.alwaysBounceVertical = true
                        
            self.edgeEffectView = EdgeEffectView()
            
            super.init(frame: frame)
            
            self.scrollView.delegate = self
            self.addSubview(self.scrollView)
            
            self.addSubview(self.edgeEffectView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.starsStateDisposable?.dispose()
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }
        
        var nextScrollTransition: ComponentTransition?
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            self.updateScrolling(bounds: scrollView.bounds, interactive: true, transition: self.nextScrollTransition ?? .immediate)
        }
        
        private func updateScrolling(bounds: CGRect, interactive: Bool = false, transition: ComponentTransition) {
            if let contentView = self.content.view as? GiftStoreContentComponent.View {
                contentView.updateScrolling(bounds: bounds, interactive: interactive, transition: transition)
            }
        }
        
        func presentBalanceMenu() {
            guard let component = self.component, let starsContext = component.context.starsContext, let tonContext = component.context.tonContext, let controller = self.environment?.controller() else {
                return
            }
            let tonBalance = tonContext.currentState?.balance.value ?? 0
            if tonBalance == 0 {
                let controller = component.context.sharedContext.makeStarsTransactionsScreen(context: component.context, starsContext: starsContext)
                controller.push(controller)
                return
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                
            let sourceView = self.balanceBackgroundView
            
            let items: Signal<[ContextMenuItem], NoError> = combineLatest(
                queue: Queue.mainQueue(),
                starsContext.state,
                tonContext.state
            )
            |> take(1)
            |> map { starsState, tonState -> [ContextMenuItem] in
                let starsBalance = starsState?.balance ?? .zero
                let tonBalance = tonState?.balance.value ?? 0
                
                var items: [ContextMenuItem] = []
                
                items.append(.action(ContextMenuActionItem(
                    text: presentationData.strings.Gift_Store_Balance_MyStars,
                    textLayout: .secondLineWithValue(formatStarsAmountText(starsBalance, dateTimeFormat: presentationData.dateTimeFormat)),
                    icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Stars"), color: theme.contextMenu.primaryColor) },
                    action: { [weak self] _, f in
                        f(.dismissWithoutContent)
                        guard let self, let component = self.component, let environment = self.environment else {
                            return
                        }
                        let controller = component.context.sharedContext.makeStarsTransactionsScreen(context: component.context, starsContext: starsContext)
                        environment.controller()?.push(controller)
                    }
                )))
                
                items.append(.action(ContextMenuActionItem(
                    text: presentationData.strings.Gift_Store_Balance_MyTon,
                    textLayout: .secondLineWithValue(formatTonAmountText(tonBalance, dateTimeFormat: presentationData.dateTimeFormat)),
                    icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Ton"), color: theme.contextMenu.primaryColor) },
                    action: { [weak self] _, f in
                        f(.dismissWithoutContent)
                        guard let self, let component = self.component, let environment = self.environment else {
                            return
                        }
                        let controller = component.context.sharedContext.makeStarsTransactionsScreen(context: component.context, starsContext: tonContext)
                        environment.controller()?.push(controller)
                    }
                )))
                
                return items
            }

            let contextController = makeContextController(presentationData: presentationData, source: .reference(GiftStoreReferenceContentSource(controller: controller, sourceView: sourceView)), items: items |> map { ContextController.Items(content: .list($0)) }, gesture: nil)
            controller.presentInGlobalOverlay(contextController)
        }
                
        func update(component: GiftStoreScreenComponent, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
            self.state = state
            
            if self.component == nil {
                self.starsStateDisposable = (component.starsContext.state
                |> deliverOnMainQueue).start(next: { [weak self] state in
                    guard let self else {
                        return
                    }
                    self.starsState = state
                    if !self.isUpdating {
                        self.state?.updated()
                    }
                })
            }
            self.component = component
                        
            let theme = environment.theme
            let strings = environment.strings
            
            if themeUpdated {
                self.backgroundColor = environment.theme.list.blocksBackgroundColor
            }
                        
            let headerSideInset: CGFloat = 24.0 + environment.safeInsets.left
                        
            var topPanelHeight = environment.navigationHeight + 53.0
            if let initialCount = self.initialCount, initialCount < minimumCountToDisplayFilters {
                topPanelHeight = environment.navigationHeight
            }
            
            let edgeEffectHeight: CGFloat = topPanelHeight + 8.0
            let edgeEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: edgeEffectHeight))
            transition.setFrame(view: self.edgeEffectView, frame: edgeEffectFrame)
            self.edgeEffectView.update(content: environment.theme.list.blocksBackgroundColor, blur: true, rect: edgeEffectFrame, edge: .top, edgeSize: min(30, edgeEffectFrame.height), transition: transition)
                              
            
            let balanceSize = self.balance.update(
                transition: .immediate,
                component: AnyComponent(
                    BalanceComponent(
                        context: component.context,
                        theme: environment.theme,
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.presentBalanceMenu()
                        }
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            let balanceFrame = CGRect(origin: .zero, size: balanceSize)
            if let balanceView = self.balance.view {
                if balanceView.superview == nil {
                    self.balanceBackgroundView.contentView.addSubview(balanceView)
                }
                balanceView.frame = balanceFrame

                let balanceBackgroundFrame = CGRect(origin: CGPoint(x: availableSize.width - environment.safeInsets.right - 16.0 - balanceSize.width, y: environment.navigationHeight - 60.0 + 2.0 + floor((60.0 - 44.0) * 0.5)), size: balanceSize)
                
                transition.setFrame(view: self.balanceBackgroundView, frame: balanceBackgroundFrame)
                self.balanceBackgroundView.update(size: balanceBackgroundFrame.size, cornerRadius: balanceBackgroundFrame.height * 0.5, isDark: environment.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: transition)
            }
            if self.balanceBackgroundView.superview == nil {
                component.overNavigationContainer.addSubview(self.balanceBackgroundView)
            }
            
            var topInset: CGFloat = 0.0
            if environment.statusBarHeight > 0.0 {
                topInset = environment.statusBarHeight - 6.0
            }
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.gift.title ?? "Gift", font: Font.semibold(17.0), textColor: theme.rootController.navigationBar.primaryTextColor)),
                    horizontalAlignment: .center
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - headerSideInset * 2.0, height: 100.0)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    component.overNavigationContainer.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) / 2.0), y: topInset + 22.0), size: titleSize))
            }
                            
            let controller = environment.controller
            self.content.parentState = state
            let contentSize = self.content.update(
                transition: transition,
                component: AnyComponent(
                    GiftStoreContentComponent(
                        context: component.context,
                        resaleGiftsContext: component.resaleGiftsContext,
                        theme: theme,
                        strings: strings,
                        dateTimeFormat: environment.dateTimeFormat,
                        safeInsets: environment.safeInsets,
                        statusBarHeight: environment.statusBarHeight,
                        navigationHeight: environment.navigationHeight,
                        overNavigationContainer: component.overNavigationContainer,
                        starsContext: component.starsContext,
                        peerId: component.peerId,
                        gift: component.gift,
                        isPlain: false,
                        confirmPurchaseImmediately: false,
                        starsTopUpOptions: nil,
                        scrollToTop: { [weak self] in
                            self?.scrollToTop()
                        },
                        controller: {
                            return controller()
                        },
                        completion: nil
                    )
                ),
                environment: {
                },
                containerSize: CGSize(width: availableSize.width, height: .greatestFiniteMagnitude)
            )
            let contentFrame = CGRect(origin: .zero, size: contentSize)
            if let contentView = self.content.view {
                if contentView.superview == nil {
                    self.scrollView.addSubview(contentView)
                }
                transition.setFrame(view: contentView, frame: contentFrame)
            }
            

            let effectiveCount: Int32
            if let contentView = self.content.view as? GiftStoreContentComponent.View, let starGiftsState = contentView.starGiftsState, let count = starGiftsState.count, count > 0 || self.initialCount != nil {
                if self.initialCount == nil {
                    self.initialCount = count
                }
                effectiveCount = Int32(count)
            } else if let resale = component.gift.availability?.resale {
                effectiveCount = Int32(resale)
            } else {
                effectiveCount = 0
            }
            
            let subtitleSize = self.subtitle.update(
                transition: transition,
                component: AnyComponent(BalancedTextComponent(
                    text: .plain(NSAttributedString(string: effectiveCount == 0 ? environment.strings.Gift_Store_ForResaleNoResults :  environment.strings.Gift_Store_ForResale(effectiveCount), font: Font.regular(13.0), textColor: theme.rootController.navigationBar.secondaryTextColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - headerSideInset * 2.0, height: 100.0)
            )
            let subtitleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - subtitleSize.width) / 2.0), y: topInset + 43.0), size: subtitleSize)
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    component.overNavigationContainer.addSubview(subtitleView)
                }
                transition.setFrame(view: subtitleView, frame: subtitleFrame)
            }
            
            
            let previousBounds = self.scrollView.bounds
            
            if self.scrollView.frame != CGRect(origin: CGPoint(), size: availableSize) {
                self.scrollView.frame = CGRect(origin: CGPoint(), size: availableSize)
            }
            if self.scrollView.contentSize != contentSize {
                if contentSize.height < self.scrollView.contentSize.height, !transition.animation.isImmediate {
                    self.nextScrollTransition = transition
                }
                self.scrollView.contentSize = contentSize
                self.nextScrollTransition = nil
            }
            let scrollInsets = UIEdgeInsets(top: topPanelHeight, left: 0.0, bottom: 0.0, right: 0.0)
            if self.scrollView.verticalScrollIndicatorInsets != scrollInsets {
                self.scrollView.verticalScrollIndicatorInsets = scrollInsets
            }
                        
            if !previousBounds.isEmpty, !transition.animation.isImmediate {
                let bounds = self.scrollView.bounds
                if bounds.maxY != previousBounds.maxY {
                    let offsetY = previousBounds.maxY - bounds.maxY
                    transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: offsetY), to: CGPoint(), additive: true)
                }
            }
                        
            self.updateScrolling(bounds: self.scrollView.bounds, transition: transition)
                        
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View()
    }
            
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class GiftStoreScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    
    private let overNavigationContainer: UIView
    
    public var parentController: () -> ViewController? = {
        return nil
    }
    
    public init(
        context: AccountContext,
        starsContext: StarsContext,
        peerId: EnginePeer.Id,
        gift: StarGift.Gift
    ) {
        self.context = context
        self.overNavigationContainer = SparseContainerView()
        
        let resaleGiftsContext = ResaleGiftsContext(account: self.context.account, giftId: gift.id, forCrafting: false)
        
        super.init(context: context, component: GiftStoreScreenComponent(
            context: context,
            resaleGiftsContext: resaleGiftsContext,
            overNavigationContainer: self.overNavigationContainer,
            starsContext: starsContext,
            peerId: peerId,
            gift: gift
        ), navigationBarAppearance: .transparent, theme: .default, updatedPresentationData: nil)
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.context.sharedContext.currentPresentationData.with { $0 }.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? GiftStoreScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
        
        if let navigationBar = self.navigationBar {
            navigationBar.customOverBackgroundContentView.insertSubview(self.overNavigationContainer, at: 0)
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    }
}

private extension StarGift {
    var id: String {
        switch self {
        case let .generic(gift):
            return "\(gift.id)"
        case let .unique(gift):
            return gift.slug
        }
    }
}

private final class GiftStoreReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceView: UIView
    
    let forceDisplayBelowKeyboard = true
    
    init(controller: ViewController, sourceView: UIView) {
        self.controller = controller
        self.sourceView = sourceView
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
