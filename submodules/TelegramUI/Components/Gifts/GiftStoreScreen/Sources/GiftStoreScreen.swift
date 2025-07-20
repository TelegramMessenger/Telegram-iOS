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

private let minimumCountToDisplayFilters = 18

final class GiftStoreScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let starsContext: StarsContext
    let peerId: EnginePeer.Id
    let gift: StarGift.Gift
    
    init(
        context: AccountContext,
        starsContext: StarsContext,
        peerId: EnginePeer.Id,
        gift: StarGift.Gift
    ) {
        self.context = context
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
        private let topOverscrollLayer = SimpleLayer()
        private let scrollView: ScrollView
        private let loadingNode: LoadingShimmerNode
        private let emptyResultsAnimation = ComponentView<Empty>()
        private let emptyResultsTitle = ComponentView<Empty>()
        private let clearFilters = ComponentView<Empty>()
        
        private let topPanel = ComponentView<Empty>()
        private let topSeparator = ComponentView<Empty>()
        private let cancelButton = ComponentView<Empty>()
        private let sortButton = ComponentView<Empty>()
                
        private let balanceTitle = ComponentView<Empty>()
        private let balanceValue = ComponentView<Empty>()
        private let balanceIcon = ComponentView<Empty>()
        
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        
        private var starsItems: [AnyHashable: ComponentView<Empty>] = [:]
        private let filterSelector = ComponentView<Empty>()

        private var isUpdating: Bool = false
        
        private var starsStateDisposable: Disposable?
        private var starsState: StarsContext.State?
        private var initialCount: Int32?
        private var showLoading = true
        
        private var selectedFilterId: AnyHashable?
        
        private var component: GiftStoreScreenComponent?
        private(set) weak var state: State?
        private var environment: EnvironmentType?
        
        override init(frame: CGRect) {
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
            
            self.loadingNode = LoadingShimmerNode()
            
            super.init(frame: frame)
            
            self.scrollView.delegate = self
            self.addSubview(self.scrollView)
            self.addSubview(self.loadingNode.view)
            
            self.scrollView.layer.addSublayer(self.topOverscrollLayer)
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
            self.updateScrolling(interactive: true, transition: self.nextScrollTransition ?? .immediate)
        }
        
        private var currentGifts: ([StarGift], Set<String>, Set<String>, Set<String>)?
        private var effectiveGifts: [StarGift]? {
            if let gifts = self.state?.starGiftsState?.gifts {
                return gifts
            } else {
                return nil
            }
        }
        
        private var effectiveIsLoading: Bool {
            if self.state?.starGiftsState?.gifts == nil || self.state?.starGiftsState?.dataState == .loading {
                return true
            }
            return false
        }
        
        private func updateScrolling(interactive: Bool = false, transition: ComponentTransition) {
            guard let environment = self.environment, let component = self.component, self.state?.starGiftsState?.dataState != .loading else {
                return
            }
               
            let availableWidth = self.scrollView.bounds.width
            let availableHeight = self.scrollView.bounds.height
            let contentOffset = self.scrollView.contentOffset.y
                        
            let topPanelAlpha = min(20.0, max(0.0, contentOffset)) / 20.0
            if let topPanelView = self.topPanel.view, let topSeparator = self.topSeparator.view {
                transition.setAlpha(view: topPanelView, alpha: topPanelAlpha)
                transition.setAlpha(view: topSeparator, alpha: topPanelAlpha)
            }
            
            var topInset = environment.navigationHeight + 39.0
            if let initialCount = self.initialCount, initialCount < minimumCountToDisplayFilters {
                topInset = environment.navigationHeight
            }
            
            let visibleBounds = self.scrollView.bounds.insetBy(dx: 0.0, dy: -10.0)
            if let starGifts = self.effectiveGifts {
                let sideInset: CGFloat = 16.0 + environment.safeInsets.left
                
                let optionSpacing: CGFloat = 10.0
                let optionWidth = (availableWidth - sideInset * 2.0 - optionSpacing * 2.0) / 3.0
                let starsOptionSize = CGSize(width: optionWidth, height: 154.0)
                
                var validIds: [AnyHashable] = []
                var itemFrame = CGRect(origin: CGPoint(x: sideInset, y: topInset + 9.0), size: starsOptionSize)
                
                let controller = environment.controller
                
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
                        if let current = self.starsItems[itemId] {
                            visibleItem = current
                        } else {
                            visibleItem = ComponentView()
                            if !transition.animation.isImmediate {
                                itemTransition = .immediate
                            }
                            self.starsItems[itemId] = visibleItem
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
                                                
                        let subject: GiftItemComponent.Subject = .uniqueGift(gift: uniqueGift, price: "# \(presentationStringsFormattedNumber(Int32(uniqueGift.resellStars ?? 0), environment.dateTimeFormat.groupingSeparator))")
                        let _ = visibleItem.update(
                            transition: itemTransition,
                            component: AnyComponent(
                                PlainButtonComponent(
                                    content: AnyComponent(
                                        GiftItemComponent(
                                            context: component.context,
                                            theme: environment.theme,
                                            strings: environment.strings,
                                            peer: nil,
                                            subject: subject,
                                            ribbon: ribbon
                                        )
                                    ),
                                    effectAlignment: .center,
                                    action: { [weak self] in
                                        if let self, let component = self.component, let state = self.state {
                                            if let controller = controller() as? GiftStoreScreen {
                                                let mainController: ViewController
                                                if let parentController = controller.parentController() {
                                                    mainController = parentController
                                                } else {
                                                    mainController = controller
                                                }
                                                
                                                let allSubjects: [GiftViewScreen.Subject] = (self.effectiveGifts ?? []).compactMap { gift in
                                                    if case let .unique(uniqueGift) = gift {
                                                        return .uniqueGift(uniqueGift, state.peerId)
                                                    }
                                                    return nil
                                                }
                                                let index = self.effectiveGifts?.firstIndex(where: { $0 == .unique(uniqueGift) }) ?? 0
                                                
                                                let giftController = GiftViewScreen(
                                                    context: component.context,
                                                    subject: .uniqueGift(uniqueGift, state.peerId),
                                                    allSubjects: allSubjects,
                                                    index: index,
                                                    buyGift: { slug, peerId, price in
                                                        return self.state?.starGiftsContext.buyStarGift(slug: slug, peerId: peerId, price: price) ?? .complete()
                                                    },
                                                    updateResellStars: { price in
                                                        return self.state?.starGiftsContext.updateStarGiftResellPrice(slug: uniqueGift.slug, price: price) ?? .complete()
                                                    }
                                                )
                                                mainController.push(giftController)
                                            }
                                        }
                                    },
                                    animateAlpha: false
                                )
                            ),
                            environment: {},
                            containerSize: starsOptionSize
                        )
                        if let itemView = visibleItem.view {
                            if itemView.superview == nil {
                                self.scrollView.addSubview(itemView)
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
                for (id, item) in self.starsItems {
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
                    self.starsItems.removeValue(forKey: id)
                }
            }
            
            let fadeTransition = ComponentTransition.easeInOut(duration: 0.25)
            let emptyResultsActionSize = self.clearFilters.update(
                transition: .immediate,
                component: AnyComponent(
                    PlainButtonComponent(
                        content: AnyComponent(
                            MultilineTextComponent(
                                text: .plain(NSAttributedString(string: environment.strings.Gift_Store_ClearFilters, font: Font.regular(17.0), textColor: environment.theme.list.itemAccentColor)),
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
                            self.state?.starGiftsContext.updateFilterAttributes([])
                            self.scrollToTop()
                        },
                        animateScale: false
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableWidth - 44.0 * 2.0, height: 100.0)
            )
            
            var showClearFilters = false
            if let filterAttributes = self.state?.starGiftsState?.filterAttributes, !filterAttributes.isEmpty {
                showClearFilters = true
            }
            
            let bottomInset: CGFloat = environment.safeInsets.bottom
            
            var emptyResultsActionFrame = CGRect(
                origin: CGPoint(
                    x: floorToScreenPixels((availableWidth - emptyResultsActionSize.width) / 2.0),
                    y: max(self.scrollView.contentSize.height - 70.0, availableHeight - bottomInset - emptyResultsActionSize.height - 16.0)
                ),
                size: emptyResultsActionSize
            )
            
            if let effectiveGifts = self.effectiveGifts, effectiveGifts.isEmpty && self.state?.starGiftsState?.dataState != .loading {
                let emptyAnimationHeight = 148.0
                let visibleHeight = availableHeight
                let emptyAnimationSpacing: CGFloat = 20.0
                let emptyTextSpacing: CGFloat = 18.0
                                                                
                let emptyResultsTitleSize = self.emptyResultsTitle.update(
                    transition: .immediate,
                    component: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(NSAttributedString(string: environment.strings.Gift_Store_EmptyResults, font: Font.semibold(17.0), textColor: environment.theme.list.itemPrimaryTextColor)),
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
                        self.insertSubview(view, belowSubview: self.loadingNode.view)
                        view.playOnce()
                    }
                    view.bounds = CGRect(origin: .zero, size: emptyResultsAnimationFrame.size)
                    ComponentTransition.immediate.setPosition(view: view, position: emptyResultsAnimationFrame.center)
                }
                if let view = self.emptyResultsTitle.view {
                    if view.superview == nil {
                        view.alpha = 0.0
                        fadeTransition.setAlpha(view: view, alpha: 1.0)
                        self.insertSubview(view, belowSubview: self.loadingNode.view)
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
                        self.scrollView.addSubview(view)
                    }
                    view.bounds = CGRect(origin: .zero, size: emptyResultsActionFrame.size)
                    ComponentTransition.immediate.setPosition(view: view, position: emptyResultsActionFrame.center)
                    
                    view.alpha = self.state?.starGiftsState?.attributes.isEmpty == true ? 0.0 : 1.0
                }
            } else {
                if let view = self.clearFilters.view {
                    fadeTransition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                        view.removeFromSuperview()
                    })
                }
            }
            
            let bottomContentOffset = max(0.0, self.scrollView.contentSize.height - self.scrollView.contentOffset.y - self.scrollView.frame.height)
            if interactive, bottomContentOffset < 1000.0 {
                self.state?.starGiftsContext.loadMore()
            }
        }
        
        func openSortContextMenu(sourceView: UIView) {
            guard let component = self.component, let controller = self.environment?.controller(), !self.effectiveIsLoading else {
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
                self.state?.starGiftsContext.updateSorting(.value)
                self.scrollToTop()
            })))
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Gift_Store_SortByDate, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Peer Info/SortDate"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, f in
                f(.default)
                guard let self else {
                    return
                }
                self.showLoading = true
                self.state?.starGiftsContext.updateSorting(.date)
                self.scrollToTop()
            })))
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Gift_Store_SortByNumber, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Peer Info/SortNumber"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, f in
                f(.default)
                guard let self else {
                    return
                }
                self.showLoading = true
                self.state?.starGiftsContext.updateSorting(.number)
                self.scrollToTop()
            })))
            
            let contextController = ContextController(presentationData: presentationData, source: .reference(GiftStoreReferenceContentSource(controller: controller, sourceView: sourceView)), items: .single(ContextController.Items(content: .list(items))), gesture: nil)
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
            guard let component = self.component, let controller = self.environment?.controller(), !self.effectiveIsLoading else {
                return
            }
                        
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let searchQueryPromise = ValuePromise<String>("")
            
            let attributes = self.state?.starGiftsState?.attributes ?? []
            let modelAttributes = attributes.filter { attribute in
                if case .model = attribute {
                    return true
                } else {
                    return false
                }
            }.sorted(by: { lhs, rhs in
                if case let .model(_, lhsFile, _) = lhs, case let .model(_, rhsFile, _) = rhs, let lhsCount = self.state?.starGiftsState?.attributeCount[.model(lhsFile.fileId.id)], let rhsCount = self.state?.starGiftsState?.attributeCount[.model(rhsFile.fileId.id)] {
                    return lhsCount > rhsCount
                } else {
                    return false
                }
            })
            
            let currentFilterAttributes = self.state?.starGiftsState?.filterAttributes ?? []
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
                attributeCount: self.state?.starGiftsState?.attributeCount ?? [:],
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
                    self.state?.starGiftsContext.updateFilterAttributes(updatedFilterAttributes)
                    self.scrollToTop()
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
                    self.state?.starGiftsContext.updateFilterAttributes(updatedFilterAttributes)
                    self.scrollToTop()
                }
            ), false))
            
            let contextController = ContextController(
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
            guard let component = self.component, let controller = self.environment?.controller(), !self.effectiveIsLoading else {
                return
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let searchQueryPromise = ValuePromise<String>("")
            
            let attributes = self.state?.starGiftsState?.attributes ?? []
            let backdropAttributes = attributes.filter { attribute in
                if case .backdrop = attribute {
                    return true
                } else {
                    return false
                }
            }.sorted(by: { lhs, rhs in
                if case let .backdrop(_, lhsId, _, _, _, _, _) = lhs, case let .backdrop(_, rhsId, _, _, _, _, _) = rhs, let lhsCount = self.state?.starGiftsState?.attributeCount[.backdrop(lhsId)], let rhsCount = self.state?.starGiftsState?.attributeCount[.backdrop(rhsId)] {
                    return lhsCount > rhsCount
                } else {
                    return false
                }
            })
            
            let currentFilterAttributes = self.state?.starGiftsState?.filterAttributes ?? []
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
                attributeCount: self.state?.starGiftsState?.attributeCount ?? [:],
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
                    self.state?.starGiftsContext.updateFilterAttributes(updatedFilterAttributes)
                    self.scrollToTop()
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
                    self.state?.starGiftsContext.updateFilterAttributes(updatedFilterAttributes)
                    self.scrollToTop()
                }
            ), false))
            
            let contextController = ContextController(
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
            guard let component = self.component, let controller = self.environment?.controller(), !self.effectiveIsLoading else {
                return
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let searchQueryPromise = ValuePromise<String>("")
            
            let attributes = self.state?.starGiftsState?.attributes ?? []
            let patternAttributes = attributes.filter { attribute in
                if case .pattern = attribute {
                    return true
                } else {
                    return false
                }
            }.sorted(by: { lhs, rhs in
                if case let .pattern(_, lhsFile, _) = lhs, case let .pattern(_, rhsFile, _) = rhs, let lhsCount = self.state?.starGiftsState?.attributeCount[.pattern(lhsFile.fileId.id)], let rhsCount = self.state?.starGiftsState?.attributeCount[.pattern(rhsFile.fileId.id)] {
                    return lhsCount > rhsCount
                } else {
                    return false
                }
            })
            
            let currentFilterAttributes = self.state?.starGiftsState?.filterAttributes ?? []
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
                attributeCount: self.state?.starGiftsState?.attributeCount ?? [:],
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
                    self.state?.starGiftsContext.updateFilterAttributes(updatedFilterAttributes)
                    self.scrollToTop()
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
                    self.state?.starGiftsContext.updateFilterAttributes(updatedFilterAttributes)
                    self.scrollToTop()
                }
            ), false))
            
            let contextController = ContextController(
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
            
            let isLoading = self.effectiveIsLoading
            if case let .ready(loadMore, nextOffset) = self.state?.starGiftsState?.dataState {
                if loadMore && nextOffset == nil {
                } else {
                    self.showLoading = false
                }
            }
            
            let theme = environment.theme
            let strings = environment.strings
            
            if themeUpdated {
                self.backgroundColor = environment.theme.list.blocksBackgroundColor
            }
                        
            let bottomContentInset: CGFloat = 56.0
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let headerSideInset: CGFloat = 24.0 + environment.safeInsets.left
                        
            var contentHeight: CGFloat = 0.0
            contentHeight += environment.navigationHeight
            
            var topPanelHeight = environment.navigationHeight + 39.0
            if let initialCount = self.initialCount, initialCount < minimumCountToDisplayFilters {
                topPanelHeight = environment.navigationHeight
            }

            let topPanelSize = self.topPanel.update(
                transition: transition,
                component: AnyComponent(BlurredBackgroundComponent(
                    color: theme.rootController.navigationBar.blurredBackgroundColor
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: topPanelHeight)
            )
            
            let topSeparatorSize = self.topSeparator.update(
                transition: transition,
                component: AnyComponent(Rectangle(
                    color: theme.rootController.navigationBar.separatorColor
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: UIScreenPixel)
            )
            let topPanelFrame = CGRect(origin: .zero, size: CGSize(width: availableSize.width, height: topPanelSize.height))
            let topSeparatorFrame = CGRect(origin: CGPoint(x: 0.0, y: topPanelSize.height), size: CGSize(width: topSeparatorSize.width, height: topSeparatorSize.height))
            if let topPanelView = self.topPanel.view, let topSeparatorView = self.topSeparator.view {
                if topPanelView.superview == nil {
                    topPanelView.alpha = 0.0
                    topSeparatorView.alpha = 0.0
                    
                    self.addSubview(topPanelView)
                    self.addSubview(topSeparatorView)
                }
                transition.setFrame(view: topPanelView, frame: topPanelFrame)
                transition.setFrame(view: topSeparatorView, frame: topSeparatorFrame)
            }
                                    
            let balanceTitleSize = self.balanceTitle.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: strings.Stars_Purchase_Balance,
                        font: Font.regular(14.0),
                        textColor: environment.theme.actionSheet.primaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: availableSize
            )
            
            let formattedBalance = formatStarsAmountText(self.starsState?.balance ?? StarsAmount.zero, dateTimeFormat: environment.dateTimeFormat)
            let smallLabelFont = Font.regular(11.0)
            let labelFont = Font.semibold(14.0)
            let balanceText = tonAmountAttributedString(formattedBalance, integralFont: labelFont, fractionalFont: smallLabelFont, color: environment.theme.actionSheet.primaryTextColor, decimalSeparator: environment.dateTimeFormat.decimalSeparator)
            
            let balanceValueSize = self.balanceValue.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(balanceText),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: availableSize
            )
            let balanceIconSize = self.balanceIcon.update(
                transition: .immediate,
                component: AnyComponent(BundleIconComponent(name: "Premium/Stars/StarSmall", tintColor: nil)),
                environment: {},
                containerSize: availableSize
            )
            
            if let balanceTitleView = self.balanceTitle.view, let balanceValueView = self.balanceValue.view, let balanceIconView = self.balanceIcon.view {
                if balanceTitleView.superview == nil {
                    self.addSubview(balanceTitleView)
                    self.addSubview(balanceValueView)
                    self.addSubview(balanceIconView)
                }
                let navigationHeight = environment.navigationHeight - environment.statusBarHeight
                let topBalanceOriginY = environment.statusBarHeight + (navigationHeight - balanceTitleSize.height - balanceValueSize.height) / 2.0
                balanceTitleView.center = CGPoint(x: availableSize.width - 16.0 - environment.safeInsets.right - balanceTitleSize.width / 2.0, y: topBalanceOriginY + balanceTitleSize.height / 2.0)
                balanceTitleView.bounds = CGRect(origin: .zero, size: balanceTitleSize)
                balanceValueView.center = CGPoint(x: availableSize.width - 16.0 - environment.safeInsets.right - balanceValueSize.width / 2.0, y: topBalanceOriginY + balanceTitleSize.height + balanceValueSize.height / 2.0)
                balanceValueView.bounds = CGRect(origin: .zero, size: balanceValueSize)
                balanceIconView.center = CGPoint(x: availableSize.width - 16.0 - environment.safeInsets.right - balanceValueSize.width - balanceIconSize.width / 2.0 - 2.0, y: topBalanceOriginY + balanceTitleSize.height + balanceValueSize.height / 2.0 - UIScreenPixel)
                balanceIconView.bounds = CGRect(origin: .zero, size: balanceIconSize)
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
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) / 2.0), y: topInset + 10.0), size: titleSize))
            }
            
            let effectiveCount: Int32
            if let count = self.state?.starGiftsState?.count, count > 0 || self.initialCount != nil {
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
            let subtitleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - subtitleSize.width) / 2.0), y: topInset + 31.0), size: subtitleSize)
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    self.addSubview(subtitleView)
                }
                transition.setFrame(view: subtitleView, frame: subtitleFrame)
            }
            
            let optionSpacing: CGFloat = 10.0
            let optionWidth = (availableSize.width - sideInset * 2.0 - optionSpacing * 2.0) / 3.0
                         
            var sortingTitle = environment.strings.Gift_Store_Sort_Date
            var sortingIcon: String = "GiftFilterDate"
            var sortingIndex: Int = 0
            if let sorting = self.state?.starGiftsState?.sorting {
                switch sorting {
                case .value:
                    sortingTitle = environment.strings.Gift_Store_Sort_Price
                    sortingIcon = "GiftFilterPrice"
                    sortingIndex = 0
                case .date:
                    sortingTitle = environment.strings.Gift_Store_Sort_Date
                    sortingIcon = "GiftFilterDate"
                    sortingIndex = 1
                case .number:
                    sortingTitle = environment.strings.Gift_Store_Sort_Number
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
            
            var modelTitle = environment.strings.Gift_Store_Filter_Model
            var backdropTitle = environment.strings.Gift_Store_Filter_Backdrop
            var symbolTitle = environment.strings.Gift_Store_Filter_Symbol
            var modelCount: Int32 = 0
            var backdropCount: Int32 = 0
            var symbolCount: Int32 = 0
            if let filterAttributes = self.state?.starGiftsState?.filterAttributes {
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
                    modelTitle = environment.strings.Gift_Store_Filter_Selected_Model(modelCount)
                }
                if backdropCount > 0 {
                    backdropTitle = environment.strings.Gift_Store_Filter_Selected_Backdrop(backdropCount)
                }
                if symbolCount > 0 {
                    symbolTitle = environment.strings.Gift_Store_Filter_Selected_Symbol(symbolCount)
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
                    colors: FilterSelectorComponent.Colors(
                        foreground: theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.65),
                        background: theme.list.itemSecondaryTextColor.mixedWith(theme.list.blocksBackgroundColor, alpha: 0.85)
                    ),
                    items: filterItems,
                    selectedItemId: self.selectedFilterId
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 10.0 * 2.0, height: 50.0)
            )
            if let filterSelectorView = self.filterSelector.view {
                if filterSelectorView.superview == nil {
                    filterSelectorView.alpha = 0.0
                    self.addSubview(filterSelectorView)
                }
                transition.setFrame(view: filterSelectorView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - filterSize.width) / 2.0), y: topInset + 56.0), size: filterSize))
                
                if let initialCount = self.initialCount, initialCount >= minimumCountToDisplayFilters {
                    loadingTransition.setAlpha(view: filterSelectorView, alpha: 1.0)
                    showingFilters = true
                }
            }
            
            if let starGifts = self.state?.starGiftsState?.gifts {
                let starsOptionSize = CGSize(width: optionWidth, height: 154.0)
                let optionSpacing: CGFloat = 10.0
                contentHeight += ceil(CGFloat(starGifts.count) / 3.0) * (starsOptionSize.height + optionSpacing)
                contentHeight += -optionSpacing + 66.0
            }
            
            contentHeight += bottomContentInset
            contentHeight += environment.safeInsets.bottom
            
            let previousBounds = self.scrollView.bounds
            
            let contentSize = CGSize(width: availableSize.width, height: contentHeight)
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
            
            self.topOverscrollLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: -3000.0), size: CGSize(width: availableSize.width, height: 3000.0))
            
            self.updateScrolling(transition: transition)
                        
            if isLoading && self.showLoading {
                self.loadingNode.update(size: availableSize, theme: environment.theme, showFilters: !showingFilters, transition: .immediate)
                loadingTransition.setAlpha(view: self.loadingNode.view, alpha: 1.0)
            } else {
                loadingTransition.setAlpha(view: self.loadingNode.view, alpha: 0.0)
            }
            transition.setFrame(view: self.loadingNode.view, frame: CGRect(origin: CGPoint(x: 0.0, y: environment.navigationHeight), size: availableSize))
                
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        var peerId: EnginePeer.Id
        private let gift: StarGift.Gift
        
        private var disposable: Disposable?
        
        fileprivate let starGiftsContext: ResaleGiftsContext
        fileprivate var starGiftsState: ResaleGiftsContext.State?
                
        init(
            context: AccountContext,
            peerId: EnginePeer.Id,
            gift: StarGift.Gift
        ) {
            self.context = context
            self.peerId = peerId
            self.gift = gift
            self.starGiftsContext = ResaleGiftsContext(account: context.account, giftId: gift.id)
            
            super.init()
            
            self.disposable = (self.starGiftsContext.state
            |> deliverOnMainQueue).start(next: { [weak self] state in
                guard let self else {
                    return
                }
                let previousFilterAttributes = self.starGiftsState?.filterAttributes
                let previousSorting = self.starGiftsState?.sorting
                self.starGiftsState = state
                
                var transition: ComponentTransition = .immediate
                if let previousFilterAttributes, previousFilterAttributes != state.filterAttributes {
                    transition = .easeInOut(duration: 0.25)
                } else if let previousSorting, previousSorting != state.sorting {
                    transition = .easeInOut(duration: 0.25)
                }
                self.updated(transition: transition)
            })
        }
        
        deinit {
            self.disposable?.dispose()
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, peerId: self.peerId, gift: self.gift)
    }
    
    func update(view: View, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class GiftStoreScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    
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
        
        super.init(context: context, component: GiftStoreScreenComponent(
            context: context,
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
