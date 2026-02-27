import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext
import TelegramCore
import Postbox
import MultilineTextComponent
import PresentationDataUtils
import ButtonComponent
import AnimatedCounterComponent
import TokenListTextField
import TelegramStringFormatting
import LottieComponent
import UndoUI
import CountrySelectionUI

final class CountriesMultiselectionScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let stateContext: CountriesMultiselectionScreen.StateContext
    let completion: ([String]) -> Void
    
    init(
        context: AccountContext,
        stateContext: CountriesMultiselectionScreen.StateContext,
        completion: @escaping ([String]) -> Void
    ) {
        self.context = context
        self.stateContext = stateContext
        self.completion = completion
    }
    
    static func ==(lhs: CountriesMultiselectionScreenComponent, rhs: CountriesMultiselectionScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.stateContext !== rhs.stateContext {
            return false
        }
        return true
    }
    
    private struct ItemLayout: Equatable {
        struct Section: Equatable {
            var id: Int
            var insets: UIEdgeInsets
            var itemHeight: CGFloat
            var itemCount: Int
            
            var totalHeight: CGFloat
            
            init(
                id: Int,
                insets: UIEdgeInsets,
                itemHeight: CGFloat,
                itemCount: Int
            ) {
                self.id = id
                self.insets = insets
                self.itemHeight = itemHeight
                self.itemCount = itemCount
                
                self.totalHeight = insets.top + itemHeight * CGFloat(itemCount) + insets.bottom
            }
        }
        
        var containerSize: CGSize
        var containerInset: CGFloat
        var bottomInset: CGFloat
        var topInset: CGFloat
        var sideInset: CGFloat
        var navigationHeight: CGFloat
        var sections: [Section]
        
        var contentHeight: CGFloat
        
        init(containerSize: CGSize, containerInset: CGFloat, bottomInset: CGFloat, topInset: CGFloat, sideInset: CGFloat, navigationHeight: CGFloat, sections: [Section]) {
            self.containerSize = containerSize
            self.containerInset = containerInset
            self.bottomInset = bottomInset
            self.topInset = topInset
            self.sideInset = sideInset
            self.navigationHeight = navigationHeight
            self.sections = sections
            
            var contentHeight: CGFloat = 0.0
            contentHeight += navigationHeight
            for section in sections {
                contentHeight += section.totalHeight
            }
            contentHeight += bottomInset
            self.contentHeight = contentHeight
        }
    }
    
    private final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
        
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    final class AnimationHint {
        let contentReloaded: Bool
        
        init(
            contentReloaded: Bool
        ) {
            self.contentReloaded = contentReloaded
        }
    }
        
    final class View: UIView, UIScrollViewDelegate {
        private let containerView: UIView
        private let backgroundView: UIImageView
        
        private let navigationContainerView: UIView
        private let navigationBackgroundView: BlurredBackgroundView
        private let navigationTitle = ComponentView<Empty>()
        private let navigationLeftButton = ComponentView<Empty>()
        private let navigationRightButton = ComponentView<Empty>()
        private let navigationSeparatorLayer: SimpleLayer
        private let navigationTextFieldState = TokenListTextField.ExternalState()
        private let navigationTextField = ComponentView<Empty>()
        private let textFieldSeparatorLayer: SimpleLayer
        
        private let emptyResultsTitle = ComponentView<Empty>()
        private let emptyResultsText = ComponentView<Empty>()
        private let emptyResultsAnimation = ComponentView<Empty>()
        
        private let scrollView: ScrollView
        private let scrollContentClippingView: SparseContainerView
        private let scrollContentView: UIView
        
        private let indexNode: CollectionIndexNode
        
        private let bottomBackgroundView: BlurredBackgroundView
        private let bottomSeparatorLayer: SimpleLayer
        private let actionButton = ComponentView<Empty>()
        
        private let countryTemplateItem = ComponentView<Empty>()
        
        private let itemContainerView: UIView
        private var visibleSectionHeaders: [Int: ComponentView<Empty>] = [:]
        private var visibleItems: [AnyHashable: ComponentView<Empty>] = [:]
        
        private var ignoreScrolling: Bool = false
        private var isDismissed: Bool = false
                
        private var selectedCountries: [String] = []
        
        private var component: CountriesMultiselectionScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?
        private var itemLayout: ItemLayout?
        
        private var topOffsetDistance: CGFloat?
        
        private var defaultStateValue: CountriesMultiselectionScreen.State?
        private var stateDisposable: Disposable?
        
        private var searchStateContext: CountriesMultiselectionScreen.StateContext?
        private var searchStateDisposable: Disposable?
        
        private let postingAvailabilityDisposable = MetaDisposable()
        
        private let hapticFeedback = HapticFeedback()
        
        private var effectiveStateValue: CountriesMultiselectionScreen.State? {
            return self.searchStateContext?.stateValue ?? self.defaultStateValue
        }
        
        override init(frame: CGRect) {
            self.containerView = SparseContainerView()
            
            self.backgroundView = UIImageView()
            
            self.navigationContainerView = SparseContainerView()
            self.navigationBackgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            self.navigationSeparatorLayer = SimpleLayer()
            self.textFieldSeparatorLayer = SimpleLayer()
            
            self.bottomBackgroundView = BlurredBackgroundView(color: .clear, enableBlur: true)
            self.bottomSeparatorLayer = SimpleLayer()
            
            self.scrollView = ScrollView()
            
            self.scrollContentClippingView = SparseContainerView()
            self.scrollContentClippingView.clipsToBounds = true
            
            self.scrollContentView = UIView()
            
            self.itemContainerView = UIView()
            self.itemContainerView.clipsToBounds = true
            self.itemContainerView.layer.cornerRadius = 10.0
            
            self.indexNode = CollectionIndexNode()
            
            super.init(frame: frame)
            
            self.addSubview(self.containerView)
            self.containerView.addSubview(self.backgroundView)
            
            self.scrollView.delaysContentTouches = true
            self.scrollView.canCancelContentTouches = true
            self.scrollView.clipsToBounds = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.alwaysBounceVertical = true
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = true
            
            self.containerView.addSubview(self.scrollContentClippingView)
            self.scrollContentClippingView.addSubview(self.scrollView)
            
            self.scrollView.addSubview(self.scrollContentView)
            
            self.scrollContentView.addSubview(self.itemContainerView)
            
            self.containerView.addSubview(self.navigationContainerView)
            self.navigationContainerView.addSubview(self.navigationBackgroundView)
            self.navigationContainerView.layer.addSublayer(self.navigationSeparatorLayer)
            
            self.containerView.addSubview(self.bottomBackgroundView)
            self.containerView.layer.addSublayer(self.bottomSeparatorLayer)
            
            self.containerView.addSubnode(self.indexNode)
            
            self.indexNode.indexSelected = { [weak self] section in
                guard let self, let sections = self.effectiveStateValue?.sections, let itemLayout = self.itemLayout else {
                    return
                }
                
                guard let index = sections.firstIndex(where: { $0.0 == section }) else {
                    return
                }
                
                var contentOffset: CGFloat = 0.0
                for i in 0 ..< index {
                    let section = itemLayout.sections[i]
                    contentOffset += section.totalHeight
                }
                
                self.scrollView.setContentOffset(CGPoint(x: 0.0, y: min(contentOffset, self.scrollView.contentSize.height - self.scrollView.bounds.height + self.scrollView.contentInset.bottom)), animated: false)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.stateDisposable?.dispose()
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            guard let itemLayout = self.itemLayout, let topOffsetDistance = self.topOffsetDistance else {
                return
            }
            
            if scrollView.contentOffset.y <= -100.0 && velocity.y <= -2.0 {
            } else {
                var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
                if topOffset > 0.0 {
                    topOffset = max(0.0, topOffset)
                    
                    if topOffset < topOffsetDistance {
                        //targetContentOffset.pointee.y = scrollView.contentOffset.y
                        //scrollView.setContentOffset(CGPoint(x: 0.0, y: itemLayout.topInset), animated: true)
                    }
                }
            }
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            
            if let result = self.navigationContainerView.hitTest(self.convert(point, to: self.navigationContainerView), with: event) {
                return result
            }
            
            let result = super.hitTest(point, with: event)
            return result
        }
        
        @objc private func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                guard let environment = self.environment, let controller = environment.controller() as? CountriesMultiselectionScreen else {
                    return
                }
                controller.requestDismiss()
            }
        }
                        
        private func updateScrolling(transition: ComponentTransition) {
            guard let component = self.component, let environment = self.environment, let itemLayout = self.itemLayout else {
                return
            }
            guard let stateValue = self.effectiveStateValue else {
                return
            }
                        
            var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
            topOffset = max(0.0, topOffset)
            transition.setTransform(layer: self.backgroundView.layer, transform: CATransform3DMakeTranslation(0.0, topOffset + itemLayout.containerInset, 0.0))
            transition.setPosition(view: self.navigationContainerView, position: CGPoint(x: 0.0, y: topOffset + itemLayout.containerInset))
            
            let bottomDistance = itemLayout.contentHeight - self.scrollView.bounds.maxY
            let bottomAlphaDistance: CGFloat = 30.0
            var bottomAlpha: CGFloat = bottomDistance / bottomAlphaDistance
            bottomAlpha = max(0.0, min(1.0, bottomAlpha))
            
            var visibleBounds = self.scrollView.bounds
            visibleBounds.origin.y -= itemLayout.topInset
            visibleBounds.size.height += itemLayout.topInset
            
            var visibleFrame = self.scrollView.frame
            visibleFrame.origin.x = 0.0
            visibleFrame.origin.y -= itemLayout.topInset
            visibleFrame.size.height += itemLayout.topInset
            
            var validIds: [AnyHashable] = []
            var validSectionHeaders: [AnyHashable] = []
            var sectionOffset: CGFloat = itemLayout.navigationHeight
            
            for sectionIndex in 0 ..< itemLayout.sections.count {
                let section = itemLayout.sections[sectionIndex]
                
                var minSectionHeader: UIView?
                do {
                    var sectionHeaderFrame = CGRect(origin: CGPoint(x: itemLayout.sideInset, y: itemLayout.containerInset + sectionOffset - self.scrollView.bounds.minY + itemLayout.topInset), size: CGSize(width: itemLayout.containerSize.width, height: section.insets.top))
      
                    let sectionHeaderMinY = topOffset + itemLayout.containerInset + itemLayout.navigationHeight
                    let sectionHeaderMaxY = itemLayout.containerInset + sectionOffset - self.scrollView.bounds.minY + itemLayout.topInset + section.totalHeight - 28.0
                    
                    sectionHeaderFrame.origin.y = max(sectionHeaderFrame.origin.y, sectionHeaderMinY)
                    sectionHeaderFrame.origin.y = min(sectionHeaderFrame.origin.y, sectionHeaderMaxY)
                    
                    if visibleFrame.intersects(sectionHeaderFrame), self.searchStateContext == nil {
                        validSectionHeaders.append(section.id)
                        let sectionHeader: ComponentView<Empty>
                        var sectionHeaderTransition = transition
                        if let current = self.visibleSectionHeaders[section.id] {
                            sectionHeader = current
                        } else {
                            if !transition.animation.isImmediate {
                                sectionHeaderTransition = .immediate
                            }
                            sectionHeader = ComponentView()
                            self.visibleSectionHeaders[section.id] = sectionHeader
                        }
                        
                        let sectionTitle = stateValue.sections[sectionIndex].0
                        let _ = sectionHeader.update(
                            transition: sectionHeaderTransition,
                            component: AnyComponent(SectionHeaderComponent(
                                theme: environment.theme,
                                style: .plain,
                                title: sectionTitle,
                                actionTitle: nil,
                                action: nil
                            )),
                            environment: {},
                            containerSize: sectionHeaderFrame.size
                        )
                        if let sectionHeaderView = sectionHeader.view {
                            if sectionHeaderView.superview == nil {
                                self.scrollContentClippingView.addSubview(sectionHeaderView)
                                
                                if !transition.animation.isImmediate {
                                    sectionHeaderView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                                }
                            }
                            let sectionXOffset = self.scrollView.frame.minX
                            if minSectionHeader == nil {
                                minSectionHeader = sectionHeaderView
                            }
                            sectionHeaderTransition.setFrame(view: sectionHeaderView, frame: sectionHeaderFrame.offsetBy(dx: sectionXOffset, dy: 0.0))
                        }
                    }
                }
                 
                let (_, countries) = stateValue.sections[sectionIndex]
                for i in 0 ..< countries.count {
                    let itemFrame = CGRect(origin: CGPoint(x: itemLayout.sideInset, y: sectionOffset + section.insets.top + CGFloat(i) * section.itemHeight), size: CGSize(width: itemLayout.containerSize.width, height: section.itemHeight))
                    if !visibleBounds.intersects(itemFrame) {
                        continue
                    }
                    
                    let country = countries[i]
                    let itemId = AnyHashable(country.id)
                    validIds.append(itemId)
                    
                    var itemTransition = transition
                    let visibleItem: ComponentView<Empty>
                    if let current = self.visibleItems[itemId] {
                        visibleItem = current
                    } else {
                        visibleItem = ComponentView()
                        if !transition.animation.isImmediate {
                            itemTransition = .immediate
                        }
                        self.visibleItems[itemId] = visibleItem
                    }
                    
                    let isSelected = self.selectedCountries.contains(country.id)
                    let _ = visibleItem.update(
                        transition: itemTransition,
                        component: AnyComponent(CountryListItemComponent(
                            context: component.context,
                            theme: environment.theme,
                            title: "\(country.flag)     \(country.name)",
                            selectionState: .editing(isSelected: isSelected, isTinted: false),
                            hasNext: true,
                            action: { [weak self] in
                                guard let self, let environment = self.environment, let controller = environment.controller() as? CountriesMultiselectionScreen else {
                                    return
                                }
                                let update = {
                                    let transition = ComponentTransition(animation: .curve(duration: 0.35, curve: .spring))
                                    self.state?.updated(transition: transition)
                                    
                                    if self.searchStateContext != nil {
                                        if let navigationTextFieldView = self.navigationTextField.view as? TokenListTextField.View {
                                            navigationTextFieldView.clearText()
                                        }
                                    }
                                }
                                
                                let index = self.selectedCountries.firstIndex(of: country.id)
                                let toggleCountry = {
                                    if let index {
                                        self.selectedCountries.remove(at: index)
                                    } else {
                                        self.selectedCountries.append(country.id)
                                    }
                                    update()
                                }
                                
                                let limit = component.context.userLimits.maxGiveawayCountriesCount
                                if self.selectedCountries.count >= limit, index == nil {
                                    self.hapticFeedback.error()
                                    
                                    let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                                    let countriesValue = environment.strings.CountriesList_MaximumReached_Countries(limit)
                                    controller.present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: environment.strings.CountriesList_MaximumReached(countriesValue).string, timeout: nil, customUndoText: nil), elevatedLayout: false, position: .bottom, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                                    return
                                }
                                toggleCountry()
                            })
                        ),
                        environment: {},
                        containerSize: itemFrame.size
                    )
                    if let itemView = visibleItem.view {
                        if itemView.superview == nil {
                            self.itemContainerView.addSubview(itemView)
                        }
                        itemTransition.setFrame(view: itemView, frame: itemFrame)
                    }
                }
                sectionOffset += section.totalHeight
            }
            
            var removeIds: [AnyHashable] = []
            for (id, item) in self.visibleItems {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    if let itemView = item.view {
                        if !transition.animation.isImmediate {
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
                self.visibleItems.removeValue(forKey: id)
            }
            
            var removeSectionHeaderIds: [Int] = []
            for (id, item) in self.visibleSectionHeaders {
                if !validSectionHeaders.contains(id) {
                    removeSectionHeaderIds.append(id)
                    if let itemView = item.view {
                        if !transition.animation.isImmediate {
                            itemView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                                itemView.removeFromSuperview()
                            })
                        } else {
                            itemView.removeFromSuperview()
                        }
                    }
                }
            }
            for id in removeSectionHeaderIds {
                self.visibleSectionHeaders.removeValue(forKey: id)
            }
            
            let fadeTransition = ComponentTransition.easeInOut(duration: 0.25)
            if let searchStateContext = self.searchStateContext, case let .countriesSearch(query) = searchStateContext.subject, let value = searchStateContext.stateValue, value.sections.isEmpty {
                let sideInset: CGFloat = 44.0
                let emptyAnimationHeight = 148.0
                let topInset: CGFloat = topOffset + itemLayout.containerInset + 40.0
                let bottomInset: CGFloat = max(environment.safeInsets.bottom, environment.inputHeight)
                let visibleHeight = visibleFrame.height
                let emptyAnimationSpacing: CGFloat = 8.0
                let emptyTextSpacing: CGFloat = 8.0
                
                let emptyResultsTitleSize = self.emptyResultsTitle.update(
                    transition: .immediate,
                    component: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(NSAttributedString(string: environment.strings.Contacts_Search_NoResults, font: Font.semibold(17.0), textColor: environment.theme.list.itemSecondaryTextColor)),
                            horizontalAlignment: .center
                        )
                    ),
                    environment: {},
                    containerSize: visibleFrame.size
                )
                let emptyResultsTextSize = self.emptyResultsText.update(
                    transition: .immediate,
                    component: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(NSAttributedString(string: environment.strings.Contacts_Search_NoResultsQueryDescription(query).string, font: Font.regular(15.0), textColor: environment.theme.list.itemSecondaryTextColor)),
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 0
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: visibleFrame.width - sideInset * 2.0, height: visibleFrame.height)
                )
                let emptyResultsAnimationSize = self.emptyResultsAnimation.update(
                    transition: .immediate,
                    component: AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(name: "ChatListNoResults")
                    )),
                    environment: {},
                    containerSize: CGSize(width: emptyAnimationHeight, height: emptyAnimationHeight)
                )
      
                let emptyTotalHeight = emptyAnimationHeight + emptyAnimationSpacing + emptyResultsTitleSize.height + emptyResultsTextSize.height + emptyTextSpacing
                let emptyAnimationY = topInset + floorToScreenPixels((visibleHeight - topInset - bottomInset - emptyTotalHeight) / 2.0)
                
                let emptyResultsAnimationFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((visibleFrame.width - emptyResultsAnimationSize.width) / 2.0), y: emptyAnimationY), size: emptyResultsAnimationSize)
                
                let emptyResultsTitleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((visibleFrame.width - emptyResultsTitleSize.width) / 2.0), y: emptyResultsAnimationFrame.maxY + emptyAnimationSpacing), size: emptyResultsTitleSize)
                
                let emptyResultsTextFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((visibleFrame.width - emptyResultsTextSize.width) / 2.0), y: emptyResultsTitleFrame.maxY + emptyTextSpacing), size: emptyResultsTextSize)
                
                if let view = self.emptyResultsAnimation.view as? LottieComponent.View {
                    if view.superview == nil {
                        view.alpha = 0.0
                        fadeTransition.setAlpha(view: view, alpha: 1.0)
                        self.scrollView.addSubview(view)
                        view.playOnce()
                    }
                    view.bounds = CGRect(origin: .zero, size: emptyResultsAnimationFrame.size)
                    transition.setPosition(view: view, position: emptyResultsAnimationFrame.center)
                }
                if let view = self.emptyResultsTitle.view {
                    if view.superview == nil {
                        view.alpha = 0.0
                        fadeTransition.setAlpha(view: view, alpha: 1.0)
                        self.scrollView.addSubview(view)
                    }
                    view.bounds = CGRect(origin: .zero, size: emptyResultsTitleFrame.size)
                    transition.setPosition(view: view, position: emptyResultsTitleFrame.center)
                }
                if let view = self.emptyResultsText.view {
                    if view.superview == nil {
                        view.alpha = 0.0
                        fadeTransition.setAlpha(view: view, alpha: 1.0)
                        self.scrollView.addSubview(view)
                    }
                    view.bounds = CGRect(origin: .zero, size: emptyResultsTextFrame.size)
                    transition.setPosition(view: view, position: emptyResultsTextFrame.center)
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
                if let view = self.emptyResultsText.view {
                    fadeTransition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                        view.removeFromSuperview()
                    })
                }
            }
        }
        
        func update(component: CountriesMultiselectionScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            guard !self.isDismissed else {
                return availableSize
            }
            let animationHint = transition.userData(AnimationHint.self)
            
            var contentTransition = transition
            if let animationHint, animationHint.contentReloaded, !transition.animation.isImmediate {
                contentTransition = .immediate
            }
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            
            let resetScrolling = self.scrollView.bounds.width != availableSize.width
            
            let sideInset: CGFloat = 0.0
            
            let containerWidth: CGFloat
            if environment.metrics.isTablet {
                containerWidth = 414.0
            } else {
                containerWidth = availableSize.width
            }
            let containerSideInset = floorToScreenPixels((availableSize.width - containerWidth) / 2.0)
            
            if self.component == nil {
                var applyState = false
                self.defaultStateValue = component.stateContext.stateValue
                self.selectedCountries = Array(component.stateContext.initialSelectedCountries)
            
                self.stateDisposable = (component.stateContext.state
                |> deliverOnMainQueue).start(next: { [weak self] stateValue in
                    guard let self else {
                        return
                    }
                    self.defaultStateValue = stateValue
                    if applyState {
                        self.state?.updated(transition: .immediate)
                    }
                })
                applyState = true
            }
            
            self.component = component
            self.state = state
            self.environment = environment
            
            if themeUpdated {
                self.scrollView.indicatorStyle = environment.theme.overallDarkAppearance ? .white : .black
                
                self.backgroundView.image = generateImage(CGSize(width: 20.0, height: 20.0), rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    
                    context.setFillColor(environment.theme.list.plainBackgroundColor.cgColor)
                    context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
                    context.fill(CGRect(origin: CGPoint(x: 0.0, y: size.height * 0.5), size: CGSize(width: size.width, height: size.height * 0.5)))
                })?.stretchableImage(withLeftCapWidth: 10, topCapHeight: 19)
                
                self.navigationBackgroundView.updateColor(color: environment.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
                self.navigationSeparatorLayer.backgroundColor = environment.theme.rootController.navigationBar.separatorColor.cgColor
                self.bottomBackgroundView.updateColor(color: environment.theme.rootController.navigationBar.blurredBackgroundColor, transition: .immediate)
                self.bottomSeparatorLayer.backgroundColor = environment.theme.rootController.navigationBar.separatorColor.cgColor
                
                self.textFieldSeparatorLayer.backgroundColor = environment.theme.rootController.navigationBar.separatorColor.cgColor
            }
            

            let itemsContainerWidth = containerWidth
            
            var tokens: [TokenListTextField.Token] = []
            for countryId in self.selectedCountries {
                guard let stateValue = self.defaultStateValue else {
                    continue
                }
                
                var tokenCountry: CountriesMultiselectionScreen.CountryItem?
                outer: for (_, countries) in stateValue.sections {
                    for country in countries {
                        if country.id == countryId {
                            tokenCountry = country
                            break outer
                        }
                    }
                }

                guard let tokenCountry else {
                    continue
                }
                
                tokens.append(TokenListTextField.Token(
                    id: AnyHashable(countryId),
                    title: tokenCountry.name,
                    fixedPosition: nil,
                    content: .emoji(tokenCountry.flag)
                ))
            }
            
            let placeholder: String = environment.strings.CountriesList_Search
            self.navigationTextField.parentState = state
            let navigationTextFieldSize = self.navigationTextField.update(
                transition: transition,
                component: AnyComponent(TokenListTextField(
                    externalState: self.navigationTextFieldState,
                    context: component.context,
                    theme: environment.theme,
                    placeholder: placeholder,
                    tokens: tokens,
                    sideInset: sideInset,
                    deleteToken: { [weak self] tokenId in
                        guard let self else {
                            return
                        }
                        if let countryId = tokenId.base as? String {
                            self.selectedCountries.removeAll(where: { $0 == countryId })
                        }
                        self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.35, curve: .spring)))
                    }
                )),
                environment: {},
                containerSize: CGSize(width: containerWidth, height: 1000.0)
            )
            
            if !self.navigationTextFieldState.text.isEmpty {
                if let searchStateContext = self.searchStateContext, searchStateContext.subject == .countriesSearch(query: self.navigationTextFieldState.text) {
                } else {
                    self.searchStateDisposable?.dispose()
                    let searchStateContext = CountriesMultiselectionScreen.StateContext(context: component.context, subject: .countriesSearch(query: self.navigationTextFieldState.text))
                    var applyState = false
                    self.searchStateDisposable = (searchStateContext.ready |> filter { $0 } |> take(1) |> deliverOnMainQueue).start(next: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.searchStateContext = searchStateContext
                        if applyState {
                            self.state?.updated(transition: ComponentTransition(animation: .none).withUserData(AnimationHint(contentReloaded: true)))
                        }
                    })
                    applyState = true
                }
            } else if let _ = self.searchStateContext {
                self.searchStateContext = nil
                self.searchStateDisposable?.dispose()
                self.searchStateDisposable = nil
                
                contentTransition = contentTransition.withUserData(AnimationHint(contentReloaded: true))
            }
                
            let countryItemSize = self.countryTemplateItem.update(
                transition: transition,
                component: AnyComponent(CountryListItemComponent(
                    context: component.context,
                    theme: environment.theme,
                    title: "Title",
                    selectionState: .editing(isSelected: false, isTinted: false),
                    hasNext: true,
                    action: {}
                )),
                environment: {},
                containerSize: CGSize(width: itemsContainerWidth, height: 1000.0)
            )
                        
            var sections: [ItemLayout.Section] = []
            if let stateValue = self.effectiveStateValue {
                 
                var id: Int = 0
                for (_, countries) in stateValue.sections {
                    sections.append(ItemLayout.Section(
                        id: id,
                        insets: UIEdgeInsets(top: self.searchStateContext != nil ? 0.0 : 28.0, left: 0.0, bottom: 0.0, right: 0.0),
                        itemHeight: countryItemSize.height,
                        itemCount: countries.count
                    ))
                    id += 1
                }
            }
            
            let containerInset: CGFloat = environment.statusBarHeight
            
            var navigationHeight: CGFloat = 56.0
            let navigationSideInset: CGFloat = 16.0
            var navigationButtonsWidth: CGFloat = 0.0
            
            let navigationLeftButtonSize = self.navigationLeftButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(Text(text: environment.strings.Common_Cancel, font: Font.regular(17.0), color: environment.theme.rootController.navigationBar.accentTextColor)),
                    action: { [weak self] in
                        guard let self, let environment = self.environment, let controller = environment.controller() as? CountriesMultiselectionScreen else {
                            return
                        }
                        controller.requestDismiss()
                    }
                ).minSize(CGSize(width: navigationHeight, height: navigationHeight))),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: navigationHeight)
            )
            let navigationLeftButtonFrame = CGRect(origin: CGPoint(x: containerSideInset + navigationSideInset, y: floor((navigationHeight - navigationLeftButtonSize.height) * 0.5)), size: navigationLeftButtonSize)
            if let navigationLeftButtonView = self.navigationLeftButton.view {
                if navigationLeftButtonView.superview == nil {
                    self.navigationContainerView.addSubview(navigationLeftButtonView)
                }
                transition.setFrame(view: navigationLeftButtonView, frame: navigationLeftButtonFrame)
            }
            navigationButtonsWidth += navigationLeftButtonSize.width + navigationSideInset
            
            let actionButtonTitle = environment.strings.CountriesList_SaveCountries
            let title = environment.strings.CountriesList_SelectCountries
            let subtitle = environment.strings.CountriesList_SelectUpTo(component.context.userLimits.maxGiveawayCountriesCount)
            
            let titleComponent = AnyComponent<Empty>(
                List([
                    AnyComponentWithIdentity(
                        id: "title",
                        component: AnyComponent(Text(text: title, font: Font.semibold(17.0), color: environment.theme.rootController.navigationBar.primaryTextColor))
                    ),
                    AnyComponentWithIdentity(
                        id: "subtitle",
                        component: AnyComponent(Text(text: subtitle, font: Font.regular(13.0), color: environment.theme.rootController.navigationBar.secondaryTextColor))
                    )
                ],
                centerAlignment: true)
            )
            
            let navigationTitleSize = self.navigationTitle.update(
                transition: .immediate,
                component: titleComponent,
                environment: {},
                containerSize: CGSize(width: containerWidth - navigationButtonsWidth, height: navigationHeight)
            )
            let navigationTitleFrame = CGRect(origin: CGPoint(x: containerSideInset + floor((containerWidth - navigationTitleSize.width) * 0.5), y: floor((navigationHeight - navigationTitleSize.height) * 0.5)), size: navigationTitleSize)
            if let navigationTitleView = self.navigationTitle.view {
                if navigationTitleView.superview == nil {
                    self.navigationContainerView.addSubview(navigationTitleView)
                }
                transition.setPosition(view: navigationTitleView, position: navigationTitleFrame.center)
                navigationTitleView.bounds = CGRect(origin: CGPoint(), size: navigationTitleFrame.size)
            }
            
            let navigationTextFieldFrame = CGRect(origin: CGPoint(x: containerSideInset, y: navigationHeight), size: navigationTextFieldSize)
            if let navigationTextFieldView = self.navigationTextField.view {
                if navigationTextFieldView.superview == nil {
                    self.navigationContainerView.addSubview(navigationTextFieldView)
                    self.navigationContainerView.layer.addSublayer(self.textFieldSeparatorLayer)
                }
                transition.setFrame(view: navigationTextFieldView, frame: navigationTextFieldFrame)
                transition.setFrame(layer: self.textFieldSeparatorLayer, frame: CGRect(origin: CGPoint(x: containerSideInset, y: navigationTextFieldFrame.maxY), size: CGSize(width: navigationTextFieldFrame.width, height: UIScreenPixel)))
            }
            navigationHeight += navigationTextFieldFrame.height
            
            self.navigationBackgroundView.update(size: CGSize(width: containerWidth, height: navigationHeight), cornerRadius: 10.0, maskedCorners: [.layerMinXMinYCorner, .layerMaxXMinYCorner], transition: transition.containedViewLayoutTransition)
            transition.setFrame(view: self.navigationBackgroundView, frame: CGRect(origin: CGPoint(x: containerSideInset, y: 0.0), size: CGSize(width: containerWidth, height: navigationHeight)))
            
            transition.setFrame(layer: self.navigationSeparatorLayer, frame: CGRect(origin: CGPoint(x: containerSideInset, y: navigationHeight), size: CGSize(width: containerWidth, height: UIScreenPixel)))
            
            var bottomPanelHeight: CGFloat = 0.0
            var bottomPanelInset: CGFloat = 0.0

            let badge = self.selectedCountries.count
            
            let actionButtonSize = self.actionButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        color: environment.theme.list.itemCheckColors.fillColor,
                        foreground: environment.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: actionButtonTitle,
                        component: AnyComponent(ButtonTextContentComponent(
                            text: actionButtonTitle,
                            badge: badge,
                            textColor: environment.theme.list.itemCheckColors.foregroundColor,
                            badgeBackground: environment.theme.list.itemCheckColors.foregroundColor,
                            badgeForeground: environment.theme.list.itemCheckColors.fillColor,
                            combinedAlignment: true
                        ))
                    ),
                    isEnabled: true,
                    displaysProgress: false,
                    action: { [weak self] in
                        guard let self, let component = self.component, let controller = self.environment?.controller() as? CountriesMultiselectionScreen else {
                            return
                        }
                        
                        component.completion(self.selectedCountries)
                        
                        controller.dismissAllTooltips()
                        controller.dismiss()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: containerWidth - navigationSideInset * 2.0, height: 50.0)
            )
            
            if environment.inputHeight != 0.0 {
                bottomPanelHeight += environment.inputHeight + 8.0 + actionButtonSize.height
            } else {
                bottomPanelHeight += 10.0 + environment.safeInsets.bottom + actionButtonSize.height
            }
            let actionButtonFrame = CGRect(origin: CGPoint(x: containerSideInset + navigationSideInset, y: availableSize.height - bottomPanelHeight), size: actionButtonSize)
            if let actionButtonView = self.actionButton.view {
                if actionButtonView.superview == nil {
                    self.containerView.addSubview(actionButtonView)
                }
                transition.setFrame(view: actionButtonView, frame: actionButtonFrame)
            }
            
            bottomPanelInset = 8.0
            transition.setFrame(view: self.bottomBackgroundView, frame: CGRect(origin: CGPoint(x: containerSideInset, y: availableSize.height - bottomPanelHeight - 8.0), size: CGSize(width: containerWidth, height: bottomPanelHeight + bottomPanelInset)))
            self.bottomBackgroundView.update(size: self.bottomBackgroundView.bounds.size, transition: transition.containedViewLayoutTransition)
            transition.setFrame(layer: self.bottomSeparatorLayer, frame: CGRect(origin: CGPoint(x: containerSideInset + sideInset, y: availableSize.height - bottomPanelHeight - bottomPanelInset - UIScreenPixel), size: CGSize(width: containerWidth, height: UIScreenPixel)))
                        
            let itemContainerSize = CGSize(width: itemsContainerWidth, height: availableSize.height)
            let itemLayout = ItemLayout(containerSize: itemContainerSize, containerInset: containerInset, bottomInset: 0.0, topInset: 0.0, sideInset: sideInset, navigationHeight: navigationHeight, sections: sections)
            self.itemLayout = itemLayout
            
            contentTransition.setFrame(view: self.itemContainerView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: containerWidth, height: itemLayout.contentHeight)))
            
            let scrollContentHeight = max(itemLayout.contentHeight + containerInset, availableSize.height - containerInset)
            
            transition.setFrame(view: self.scrollContentView, frame: CGRect(origin: CGPoint(x: 0.0, y: containerInset), size: CGSize(width: containerWidth, height: itemLayout.contentHeight)))
            
            transition.setPosition(view: self.backgroundView, position: CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0))
            transition.setBounds(view: self.backgroundView, bounds: CGRect(origin: CGPoint(x: containerSideInset, y: 0.0), size: CGSize(width: containerWidth, height: availableSize.height)))
            
            let scrollClippingInset: CGFloat = 0.0
            let scrollClippingFrame = CGRect(origin: CGPoint(x: 0.0, y: containerInset + scrollClippingInset), size: CGSize(width: availableSize.width, height: availableSize.height - scrollClippingInset))
            transition.setPosition(view: self.scrollContentClippingView, position: scrollClippingFrame.center)
            transition.setBounds(view: self.scrollContentClippingView, bounds: CGRect(origin: CGPoint(x: scrollClippingFrame.minX, y: scrollClippingFrame.minY), size: scrollClippingFrame.size))
            
            transition.setFrame(view: self.containerView, frame: CGRect(origin: .zero, size: availableSize))
            
            self.ignoreScrolling = true
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: containerSideInset, y: 0.0), size: CGSize(width: containerWidth, height: availableSize.height)))
            let contentSize = CGSize(width: containerWidth, height: scrollContentHeight)
            if contentSize != self.scrollView.contentSize {
                self.scrollView.contentSize = contentSize
            }
            let contentInset: UIEdgeInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomPanelHeight + bottomPanelInset, right: 0.0)
            let indicatorInset = UIEdgeInsets(top: max(itemLayout.containerInset, environment.safeInsets.top + navigationHeight), left: 0.0, bottom: contentInset.bottom, right: 0.0)
            if indicatorInset != self.scrollView.verticalScrollIndicatorInsets {
                self.scrollView.verticalScrollIndicatorInsets = indicatorInset
            }
            if contentInset != self.scrollView.contentInset {
                self.scrollView.contentInset = contentInset
            }
            if resetScrolling {
                self.scrollView.bounds = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: containerWidth, height: availableSize.height))
            }
            self.ignoreScrolling = false
            self.updateScrolling(transition: contentTransition)
             
            let indexNodeFrame = CGRect(origin: CGPoint(x: availableSize.width - environment.safeInsets.right - 20.0, y: navigationHeight), size: CGSize(width: 20.0, height: availableSize.height - navigationHeight - contentInset.bottom))
            self.indexNode.frame = indexNodeFrame

            if let stateValue = self.effectiveStateValue {
                let indexSections = stateValue.sections.map { $0.0 }
                self.indexNode.update(size: CGSize(width: indexNodeFrame.width, height: indexNodeFrame.height), color: environment.theme.list.itemAccentColor, sections: indexSections, transition: .animated(duration: 0.2, curve: .easeInOut))
                self.indexNode.isUserInteractionEnabled = !indexSections.isEmpty
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class CountriesMultiselectionScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    
    private var isCustomModal = true
    private var isDismissed: Bool = false
    
    public var dismissed: () -> Void = {}
    
    public init(
        context: AccountContext,
        stateContext: StateContext,
        completion: @escaping ([String]) -> Void
    ) {
        self.context = context
                        
        super.init(context: context, component: CountriesMultiselectionScreenComponent(
            context: context,
            stateContext: stateContext,
            completion: completion
        ), navigationBarAppearance: .none, theme: .default)
        
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .modal
        self.blocksBackgroundWhenInOverlay = true
        self.automaticallyControlPresentationContextLayout = false
        self.lockOrientation = true
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if !self.isDismissed {
            self.isDismissed = true
            self.dismissed()
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        var updatedLayout = layout
        updatedLayout.intrinsicInsets.bottom += 66.0
        self.presentationContext.containerLayoutUpdated(updatedLayout, transition: transition)
    }
    
    fileprivate func dismissAllTooltips() {
        self.window?.forEachController { controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
        }
        self.forEachController { controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
            return true
        }
    }
    
    func requestDismiss() {
        self.dismissAllTooltips()
        self.dismissed()
        self.dismiss()
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            
            self.view.endEditing(true)
           
            self.dismiss(animated: true)
        }
    }
}

public extension CountriesMultiselectionScreen {
    struct CountryItem {
        let id: String
        let flag: String
        let name: String
    }
    
    final class State {
        let sections: [(String, [CountryItem])]
    
        fileprivate init(
            sections: [(String, [CountryItem])]
        ) {
            self.sections = sections
        }
    }
    
    final class StateContext {
        public enum Subject: Equatable {
            case countries
            case countriesSearch(query: String)
        }
        
        var stateValue: State?
        
        public let subject: Subject
        public let initialSelectedCountries: [String]
        
        private var stateDisposable: Disposable?
        private let stateSubject = Promise<State>()
        public var state: Signal<State, NoError> {
            return self.stateSubject.get()
        }
        
        private let readySubject = ValuePromise<Bool>(false, ignoreRepeated: true)
        public var ready: Signal<Bool, NoError> {
            return self.readySubject.get()
        }
        
        public init(
            context: AccountContext,
            subject: Subject = .countries,
            initialSelectedCountries: [String] = []
        ) {
            self.subject = subject
            self.initialSelectedCountries = initialSelectedCountries
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let countries = localizedCountryNamesAndCodes(strings: presentationData.strings).sorted { lhs, rhs in
                return lhs.0.1.lowercased() < rhs.0.1.lowercased()
            }
            
            switch subject {
            case .countries:
                var sections: [(String, [CountryItem])] = []
                
                var currentSection: String?
                var currentCountries: [CountryItem] = []
                for country in countries {
                    let section = String(country.0.1.prefix(1))
                    if currentSection != section {
                        if let currentSection {
                            sections.append((currentSection, currentCountries))
                        }
                        currentSection = section
                        currentCountries = []
                    }
                    
                    currentCountries.append(CountryItem(
                        id: country.1,
                        flag: flagEmoji(countryCode: country.1),
                        name: country.0.1
                    ))
                }
                
                if let currentSection {
                    sections.append((currentSection, currentCountries))
                }
                
                let state = State(
                    sections: sections
                )
                self.stateValue = state
                self.stateSubject.set(.single(state))
                
                self.readySubject.set(true)
            case let .countriesSearch(query):
                let results = searchCountries(items: countries, query: query)
                
                var resultCountries: [CountryItem] = []
                var existingIds = Set<String>()
                for country in results {
                    guard !existingIds.contains(country.1) else {
                        continue
                    }
                    resultCountries.append(CountryItem(
                        id: country.1,
                        flag: flagEmoji(countryCode: country.1),
                        name: country.0.1
                    ))
                    existingIds.insert(country.1)
                }
                let state = State(
                    sections: [("", resultCountries)]
                )
                self.stateValue = state
                self.stateSubject.set(.single(state))
                
                self.readySubject.set(true)
            }
        }
        
        deinit {
            self.stateDisposable?.dispose()
        }
    }
}
