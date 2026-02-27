import Foundation
import UIKit
import AsyncDisplayKit
import TelegramPresentationData
import ComponentFlow
import AccountContext
import ViewControllerComponent
import TelegramCore
import SwiftSignalKit
import Display
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import ButtonComponent
import PlainButtonComponent
import Markdown
import BundleIconComponent
import TextFormat
import TelegramStringFormatting
import GlassBarButtonComponent
import GiftItemComponent
import EdgeEffect
import AnimatedTextComponent
import SegmentControlComponent
import GiftAnimationComponent
import GlassBackgroundComponent

private final class GiftUpgradeVariantsScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let gift: StarGift
    let crafted: Bool
    let attributes: [StarGift.UniqueGift.Attribute]
    let selectedAttributes: [StarGift.UniqueGift.Attribute]?
    let focusedAttribute: StarGift.UniqueGift.Attribute?
    
    init(
        context: AccountContext,
        gift: StarGift,
        crafted: Bool,
        attributes: [StarGift.UniqueGift.Attribute],
        selectedAttributes: [StarGift.UniqueGift.Attribute]?,
        focusedAttribute: StarGift.UniqueGift.Attribute?
    ) {
        self.context = context
        self.gift = gift
        self.crafted = crafted
        self.attributes = attributes
        self.selectedAttributes = selectedAttributes
        self.focusedAttribute = focusedAttribute
    }
    
    static func ==(lhs: GiftUpgradeVariantsScreenComponent, rhs: GiftUpgradeVariantsScreenComponent) -> Bool {
        return true
    }
    
    private struct ItemLayout: Equatable {
        var containerSize: CGSize
        var containerInset: CGFloat
        var containerCornerRadius: CGFloat
        var bottomInset: CGFloat
        var topInset: CGFloat
        
        init(containerSize: CGSize, containerInset: CGFloat, containerCornerRadius: CGFloat, bottomInset: CGFloat, topInset: CGFloat) {
            self.containerSize = containerSize
            self.containerInset = containerInset
            self.containerCornerRadius = containerCornerRadius
            self.bottomInset = bottomInset
            self.topInset = topInset
        }
    }
    
    enum SelectedSection {
        case models
        case backdrops
        case symbols
    }
    
    private final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let dimView: UIView
        private let containerView: UIView
        private let backgroundLayer: SimpleLayer
        private let navigationBarContainer: SparseContainerView
        private let closeGlassContainerView: GlassBackgroundContainerView
        private let playbackGlassContainerView: GlassBackgroundContainerView
        private let scrollView: ScrollView
        private let scrollContentClippingView: SparseContainerView
        private let scrollContentView: UIView
                
        private let backgroundHandleView: UIImageView
        
        private let header = ComponentView<Empty>()
        private let closeButton = ComponentView<Empty>()
        private let playbackButton = ComponentView<Empty>()
        
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        
        private var attributeInfos: [ComponentView<Empty>] = []
        
        private let topEdgeSolidView = UIView()
        private let topEdgeEffectView: EdgeEffectView
        private let segmentControl = ComponentView<Empty>()
        private let descriptionText = ComponentView<Empty>()
        
        private var giftItems: [AnyHashable: ComponentView<Empty>] = [:]
        
        private var selectedSection: SelectedSection = .models
        private var displayCraftableModels = false
        
        private let giftCompositionExternalState = GiftCompositionComponent.ExternalState()
                        
        private var isPlaying = true
        private var showRandomizeTip = false
        private var previewTimer: SwiftSignalKit.Timer?
        private var previewModelIndex: Int = 0
        private var previewBackdropIndex: Int = 0
        private var previewSymbolIndex: Int = 0
        
        private var previewPrimaryModels: [StarGift.UniqueGift.Attribute] = []
        private var previewCraftableModels: [StarGift.UniqueGift.Attribute] = []
        private var previewBackdrops: [StarGift.UniqueGift.Attribute] = []
        private var previewSymbols: [StarGift.UniqueGift.Attribute] = []
        
        private var selectedModel: StarGift.UniqueGift.Attribute?
        private var selectedBackdrop: StarGift.UniqueGift.Attribute?
        private var selectedSymbol: StarGift.UniqueGift.Attribute?
        
        private var craftableModelCount: Int32 = 0
        private var primaryModelCount: Int32 = 0
        private var backdropCount: Int32 = 0
        private var symbolCount: Int32 = 0
        
        private var currentDescriptionHeight: CGFloat = 0.0
        
        private var cachedSmallChevronImage: (UIImage, PresentationTheme)?
        
        private var ignoreScrolling: Bool = false
                
        private var component: GiftUpgradeVariantsScreenComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        private var environment: ViewControllerComponentContainer.Environment?
        private var itemLayout: ItemLayout?
                
        override init(frame: CGRect) {
            self.dimView = UIView()
            self.containerView = UIView()
            
            self.containerView.clipsToBounds = true
            self.containerView.layer.cornerRadius = 40.0
            self.containerView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            
            self.backgroundLayer = SimpleLayer()
            self.backgroundLayer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            self.backgroundLayer.cornerRadius = 40.0
                        
            self.backgroundHandleView = UIImageView()
            
            self.navigationBarContainer = SparseContainerView()
            
            self.topEdgeEffectView = EdgeEffectView()
            self.topEdgeEffectView.alpha = 0.0
            
            self.closeGlassContainerView = GlassBackgroundContainerView()
            self.playbackGlassContainerView = GlassBackgroundContainerView()
            
            self.scrollView = ScrollView()
            
            self.scrollContentClippingView = SparseContainerView()
            self.scrollContentClippingView.clipsToBounds = true
            
            self.scrollContentView = UIView()
                                                
            super.init(frame: frame)
            
            self.addSubview(self.dimView)
            self.addSubview(self.containerView)
            self.containerView.layer.addSublayer(self.backgroundLayer)
                        
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
            
            self.containerView.addSubview(self.navigationBarContainer)
            
            self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
            
            self.alpha = 0.0
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            if !self.backgroundLayer.frame.contains(point) {
                return self.dimView
            }
            
            if let result = self.navigationBarContainer.hitTest(self.convert(point, to: self.navigationBarContainer), with: event) {
                return result
            }
            let result = super.hitTest(point, with: event)
            return result
        }
        
        @objc private func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                guard let environment = self.environment, let controller = environment.controller() else {
                    return
                }
                controller.dismiss()
            }
        }
        
        private func updateScrolling(transition: ComponentTransition) {
            guard let itemLayout = self.itemLayout else {
                return
            }
            var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
            topOffset = max(0.0, topOffset)
            transition.setTransform(layer: self.backgroundLayer, transform: CATransform3DMakeTranslation(0.0, topOffset + itemLayout.containerInset, 0.0))
            
            transition.setPosition(view: self.navigationBarContainer, position: CGPoint(x: 0.0, y: topOffset + itemLayout.containerInset))
            
            var topOffsetFraction = self.scrollView.bounds.minY / 100.0
            topOffsetFraction = max(0.0, min(1.0, topOffsetFraction))
            
            self.topEdgeEffectView.alpha = max(0.0, min(1.0, self.scrollView.bounds.minY / 8.0))
            
            let minScale: CGFloat = (itemLayout.containerSize.width - 6.0 * 2.0) / itemLayout.containerSize.width
            let minScaledTranslation: CGFloat = (itemLayout.containerSize.height - itemLayout.containerSize.height * minScale) * 0.5 - 6.0
            let minScaledCornerRadius: CGFloat = itemLayout.containerCornerRadius
            
            let scale = minScale * (1.0 - topOffsetFraction) + 1.0 * topOffsetFraction
            let scaledTranslation = minScaledTranslation * (1.0 - topOffsetFraction)
            let scaledCornerRadius = minScaledCornerRadius * (1.0 - topOffsetFraction) + itemLayout.containerCornerRadius * topOffsetFraction
            
            var containerTransform = CATransform3DIdentity
            containerTransform = CATransform3DTranslate(containerTransform, 0.0, scaledTranslation, 0.0)
            containerTransform = CATransform3DScale(containerTransform, scale, scale, scale)
            transition.setTransform(view: self.containerView, transform: containerTransform)
            transition.setCornerRadius(layer: self.containerView.layer, cornerRadius: scaledCornerRadius)
            
            self.updateItems(transition: transition)
        }
        
        func animateIn() {
            self.alpha = 1.0
            self.dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            let animateOffset: CGFloat = self.bounds.height - self.backgroundLayer.frame.minY
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.backgroundLayer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.navigationBarContainer.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
        }
        
        func animateOut(completion: @escaping () -> Void) {
            let animateOffset: CGFloat = self.bounds.height - self.backgroundLayer.frame.minY
            
            self.dimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true, completion: { _ in
                completion()
            })
            self.backgroundLayer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            self.navigationBarContainer.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
        }
        
        private func previewTimerTick() {
            let previewModels = self.displayCraftableModels ? self.previewCraftableModels : self.previewPrimaryModels
            guard !previewModels.isEmpty else { return }
            self.previewModelIndex = (self.previewModelIndex + 1) % previewModels.count
            
            let previousSymbolIndex = self.previewSymbolIndex
            var randomSymbolIndex = previousSymbolIndex
            while randomSymbolIndex == previousSymbolIndex && !self.previewSymbols.isEmpty {
                randomSymbolIndex = Int.random(in: 0 ..< self.previewSymbols.count)
            }
            if !self.previewSymbols.isEmpty { self.previewSymbolIndex = randomSymbolIndex }
            
            let previousBackdropIndex = self.previewBackdropIndex
            var randomBackdropIndex = previousBackdropIndex
            while randomBackdropIndex == previousBackdropIndex && !self.previewBackdrops.isEmpty {
                randomBackdropIndex = Int.random(in: 0 ..< self.previewBackdrops.count)
            }
            if !self.previewBackdrops.isEmpty { self.previewBackdropIndex = randomBackdropIndex }
            
            self.state?.updated(transition: .easeInOut(duration: 0.25))
        }
        
        private func updateTimer() {
            if self.isPlaying {
                self.previewTimer = SwiftSignalKit.Timer(timeout: 3.0, repeat: true, completion: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.previewTimerTick()
                }, queue: Queue.mainQueue())
                self.previewTimer?.start()
            } else {
                self.previewTimer?.invalidate()
                self.previewTimer = nil
            }
        }
        
        private var effectiveGifts: [[StarGift.UniqueGift.Attribute]] = []
        private func updateEffectiveGifts(attributes: [StarGift.UniqueGift.Attribute]) {
            var effectiveGifts: [[StarGift.UniqueGift.Attribute]] = []
            switch self.selectedSection {
            case .models:
                let models = Array(attributes.filter({ attribute in
                    if case let .model(_, _, _, crafted) = attribute {
                        if self.displayCraftableModels && !crafted {
                            return false
                        } else if !self.displayCraftableModels && crafted {
                            return false
                        }
                        return true
                    } else {
                        return false
                    }
                }))
                for model in models {
                    effectiveGifts.append([model])
                }
            case .backdrops:
                let previewModels = self.displayCraftableModels ? self.previewCraftableModels : previewPrimaryModels
                let selectedModel = self.selectedModel ?? previewModels[self.previewModelIndex]
                let selectedSymbol = self.selectedSymbol ?? self.previewSymbols[self.previewSymbolIndex]
                let backdrops = Array(attributes.filter({ attribute in
                    if case .backdrop = attribute {
                        return true
                    } else {
                        return false
                    }
                }))
                for backdrop in backdrops {
                    effectiveGifts.append([
                        selectedModel,
                        backdrop,
                        selectedSymbol
                    ])
                }
            case .symbols:
                let selectedBackdrop = self.selectedBackdrop ?? self.previewBackdrops[self.previewBackdropIndex]
                let symbols = Array(attributes.filter({ attribute in
                    if case .pattern = attribute {
                        return true
                    } else {
                        return false
                    }
                }))
                for symbol in symbols {
                    effectiveGifts.append([
                        selectedBackdrop,
                        symbol
                    ])
                }
            }
            self.effectiveGifts = effectiveGifts
        }
        
        private func updateItems(transition: ComponentTransition) {
            guard let component = self.component, let environment = self.environment, let itemLayout = self.itemLayout else {
                return
            }
        
            let visibleBounds = self.scrollView.bounds.insetBy(dx: 0.0, dy: -10.0)
            
            let fillingSize: CGFloat
            if case .regular = environment.metrics.widthClass {
                fillingSize = min(itemLayout.containerSize.width, 414.0) - environment.safeInsets.left * 2.0
            } else {
                fillingSize = min(itemLayout.containerSize.width, environment.deviceMetrics.screenSize.width) - environment.safeInsets.left * 2.0
            }
            
            let rawSideInset: CGFloat = floor((itemLayout.containerSize.width - fillingSize) * 0.5)
            let sideInset: CGFloat = rawSideInset + 16.0
            
            let optionSpacing: CGFloat = 10.0
            let optionWidth = (fillingSize - 16.0 * 2.0 - optionSpacing * 2.0) / 3.0
            let optionSize = CGSize(width: optionWidth, height: 126.0)
            
            let topInset: CGFloat = 375.0 + self.currentDescriptionHeight
            
            var validIds: [AnyHashable] = []
            var itemFrame = CGRect(origin: CGPoint(x: sideInset, y: topInset + 9.0), size: optionSize)
            
            for attributeList in self.effectiveGifts {
                var isVisible = false
                if visibleBounds.intersects(itemFrame) {
                    isVisible = true
                }
                
                var itemId = ""
                var title = ""
                var rarity: StarGift.UniqueGift.Attribute.Rarity?
                
                var modelAttribute: StarGift.UniqueGift.Attribute?
                var backdropAttribute: StarGift.UniqueGift.Attribute?
                var symbolAttribute: StarGift.UniqueGift.Attribute?
                
                switch self.selectedSection {
                case .models:
                    itemId += "models_"
                case .backdrops:
                    itemId += "backdrops_"
                case .symbols:
                    itemId += "symbols_"
                }
                
                var isSelected = false
                for attribute in attributeList {
                    switch attribute {
                    case let .model(name, file, rarityValue, _):
                        itemId += "\(file.fileId.id)"
                        if self.selectedSection == .models {
                            title = name
                            rarity = rarityValue
                            modelAttribute = attribute
                            
                            if case let .model(_, selectedFile, _, _) = self.selectedModel {
                                isSelected = file.fileId == selectedFile.fileId
                            } else {
                                isSelected = false
                            }
                        }
                    case let .backdrop(name, id, _, _, _, _, rarityValue):
                        itemId += "\(id)"
                        if self.selectedSection == .backdrops {
                            title = name
                            rarity = rarityValue
                            backdropAttribute = attribute
                            
                            if case let .backdrop(_, selectedId, _, _, _, _, _) = self.selectedBackdrop {
                                isSelected = id == selectedId
                            } else {
                                isSelected = false
                            }
                        }
                    case let .pattern(name, file, rarityValue):
                        itemId += "\(file.fileId.id)"
                        if self.selectedSection == .symbols {
                            title = name
                            rarity = rarityValue
                            symbolAttribute = attribute
                            
                            if case let .pattern(_, selectedFile, _) = self.selectedSymbol {
                                isSelected = file.fileId == selectedFile.fileId
                            } else {
                                isSelected = false
                            }
                        }
                    default:
                        break
                    }
                }
                
                if isVisible {
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
                    
                    let subject: GiftItemComponent.Subject = .preview(attributes: attributeList, rarity: rarity)
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
                                        title: title,
                                        ribbon: nil,
                                        isSelected: isSelected,
                                        mode: .upgradePreview,
                                        allowAnimations: self.selectedSection != .backdrops
                                    )
                                ),
                                effectAlignment: .center,
                                action: { [weak self] in
                                    guard let self, let state = self.state else {
                                        return
                                    }
                                    if self.isPlaying {
                                        self.isPlaying = false
                                        self.showRandomizeTip = true
                                        Queue.mainQueue().after(2.0) {
                                            if self.showRandomizeTip {
                                                self.showRandomizeTip = false
                                                self.state?.updated(transition: .easeInOut(duration: 0.25))
                                            }
                                        }
                                    }
                                    
                                    switch self.selectedSection {
                                    case .models:
                                        self.selectedModel = modelAttribute
                                    case .backdrops:
                                        self.selectedBackdrop = backdropAttribute
                                    case .symbols:
                                        self.selectedSymbol = symbolAttribute
                                    }
                                    
                                    state.updated(transition: .easeInOut(duration: 0.25))
                                },
                                animateAlpha: false
                            )
                        ),
                        environment: {},
                        containerSize: optionSize
                    )
                    if let itemView = visibleItem.view {
                        if itemView.superview == nil {
                            self.scrollContentView.addSubview(itemView)
                            
                            if !transition.animation.isImmediate {
                                itemView.layer.animateScale(from: 0.01, to: 1.0, duration: 0.25)
                                itemView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                            }
                        }
                        itemTransition.setFrame(view: itemView, frame: itemFrame)
                    }
                }
                itemFrame.origin.x += itemFrame.width + optionSpacing
                if itemFrame.maxX > rawSideInset + fillingSize {
                    itemFrame.origin.x = sideInset
                    itemFrame.origin.y += optionSize.height + optionSpacing
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
      
        func update(component: GiftUpgradeVariantsScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.updateTimer()
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            
            let resetScrolling = self.scrollView.bounds.width != availableSize.width
            
            let fillingSize: CGFloat
            if case .regular = environment.metrics.widthClass {
                fillingSize = min(availableSize.width, 414.0) - environment.safeInsets.left * 2.0
            } else {
                fillingSize = min(availableSize.width, environment.deviceMetrics.screenSize.width) - environment.safeInsets.left * 2.0
            }
            let rawSideInset: CGFloat = floor((availableSize.width - fillingSize) * 0.5)
            let sideInset: CGFloat = rawSideInset + 16.0
            
            if self.component == nil {
                self.displayCraftableModels = component.crafted
                
                var primaryModelCount: Int32 = 0
                var craftableModelCount: Int32 = 0
                var backdropCount: Int32 = 0
                var symbolCount: Int32 = 0
                for attribute in component.attributes {
                    switch attribute {
                    case let .model(_, _, _, crafted):
                        if crafted {
                            craftableModelCount += 1
                        } else {
                            primaryModelCount += 1
                        }
                    case .backdrop:
                        backdropCount += 1
                    case .pattern:
                        symbolCount += 1
                    default:
                        break
                    }
                }
                self.primaryModelCount = primaryModelCount
                self.craftableModelCount = craftableModelCount
                self.backdropCount = backdropCount
                self.symbolCount = symbolCount
                
                let randomPrimaryModels = Array(component.attributes.filter({ attribute in
                    if case let .model(_, _, _, crafted) = attribute {
                        if crafted {
                            return false
                        }
                        return true
                    } else {
                        return false
                    }
                }).shuffled().prefix(15))
                self.previewPrimaryModels = randomPrimaryModels
                
                let randomCraftableModels = Array(component.attributes.filter({ attribute in
                    if case let .model(_, _, _, crafted) = attribute {
                        if !crafted {
                            return false
                        }
                        return true
                    } else {
                        return false
                    }
                }).shuffled().prefix(15))
                self.previewCraftableModels = randomCraftableModels
                
                let randomBackdrops = Array(component.attributes.filter({ attribute in
                    if case .backdrop = attribute {
                        return true
                    } else {
                        return false
                    }
                }).shuffled())
                self.previewBackdrops = randomBackdrops
                
                let randomSymbols = Array(component.attributes.filter({ attribute in
                    if case .pattern = attribute {
                        return true
                    } else {
                        return false
                    }
                }).shuffled().prefix(15))
                self.previewSymbols = randomSymbols
                
                if let selectedAttributes = component.selectedAttributes {
                    self.isPlaying = false
                    for attribute in selectedAttributes {
                        switch attribute {
                        case .model:
                            self.selectedModel = attribute
                        case .pattern:
                            self.selectedSymbol = attribute
                        case .backdrop:
                            self.selectedBackdrop = attribute
                        default:
                            break
                        }
                    }
                }
                if let focusedAttribute = component.focusedAttribute {
                    switch focusedAttribute {
                    case .model:
                        self.selectedSection = .models
                    case .pattern:
                        self.selectedSection = .symbols
                    case .backdrop:
                        self.selectedSection = .backdrops
                    default:
                        break
                    }
                }
                
                self.updateEffectiveGifts(attributes: component.attributes)
            }
            
            self.component = component
            self.state = state
            self.environment = environment
            
            let theme = environment.theme.withModalBlocksBackground()
            
            if themeUpdated {
                self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
                self.backgroundLayer.backgroundColor = theme.list.blocksBackgroundColor.cgColor
            }
            
            transition.setFrame(view: self.dimView, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            var buttonColor: UIColor = .white.withAlphaComponent(0.1)
            var secondaryTextColor: UIColor = .white.withAlphaComponent(0.4)
            var badgeColor: UIColor = .white.withAlphaComponent(0.4)
            
            var attributes: [StarGift.UniqueGift.Attribute] = []
            let previewModels = self.displayCraftableModels ? self.previewCraftableModels : self.previewPrimaryModels
            if !previewModels.isEmpty {
                if self.isPlaying {
                    attributes.append(previewModels[self.previewModelIndex])
                    attributes.append(self.previewBackdrops[self.previewBackdropIndex])
                    attributes.append(self.previewSymbols[self.previewSymbolIndex])
                } else {
                    if self.selectedModel == nil {
                        self.selectedModel = previewModels[self.previewModelIndex]
                    }
                    if self.selectedBackdrop == nil {
                        self.selectedBackdrop = self.previewBackdrops[self.previewBackdropIndex]
                    }
                    if self.selectedSymbol == nil {
                        self.selectedSymbol = self.previewSymbols[self.previewSymbolIndex]
                    }
                    if let model = self.selectedModel {
                        attributes.append(model)
                    }
                    if let backdrop = self.selectedBackdrop {
                        attributes.append(backdrop)
                    }
                    if let symbol = self.selectedSymbol {
                        attributes.append(symbol)
                    }
                }
            }
            
            if let backdropAttribute = attributes.first(where: { attribute in
                if case .backdrop = attribute {
                    return true
                } else {
                    return false
                }
            }), case let .backdrop(_, _, innerColor, outerColor, _, _, _) = backdropAttribute {
                buttonColor = UIColor(rgb: UInt32(bitPattern: outerColor)).mixedWith(.white, alpha: 0.2)
                
                badgeColor = UIColor(rgb: UInt32(bitPattern: innerColor)).withMultipliedBrightnessBy(1.05)
                let outer = UIColor(rgb: UInt32(bitPattern: outerColor))
                if outer.lightness < 0.06 {
                    badgeColor = UIColor(rgb: UInt32(bitPattern: innerColor)).withMultipliedBrightnessBy(1.45)
                } else if outer.lightness < 0.295 {
                    badgeColor = UIColor(rgb: UInt32(bitPattern: innerColor)).withMultipliedBrightnessBy(1.19)
                }
                secondaryTextColor = UIColor(rgb: UInt32(bitPattern: innerColor)).withMultiplied(hue: 1.0, saturation: 1.02, brightness: 1.25).mixedWith(UIColor.white, alpha: 0.3)
            }
            
            var contentHeight: CGFloat = 0.0
            let headerSize = self.header.update(
                transition: transition,
                component: AnyComponent(GiftCompositionComponent(
                    context: component.context,
                    theme: environment.theme,
                    subject: .preview(attributes),
                    animationOffset: CGPoint(x: 0.0, y: 20.0),
                    animationScale: nil,
                    displayAnimationStars: false,
                    alwaysAnimateTransition: true,
                    revealedAttributes: Set(),
                    externalState: self.giftCompositionExternalState,
                    requestUpdate: { [weak state] transition in
                        state?.updated(transition: transition)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: fillingSize, height: 300.0),
            )
            let headerFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - headerSize.width) * 0.5), y: 0.0), size: headerSize)
            if let headerView = self.header.view {
                if headerView.superview == nil {
                    headerView.isUserInteractionEnabled = false
                    headerView.clipsToBounds = true
                    headerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                    headerView.layer.cornerRadius = 38.0
                    self.navigationBarContainer.addSubview(headerView)
                }
                transition.setFrame(view: headerView, frame: headerFrame)
            }
            
            contentHeight += headerSize.height
            
            var titleText: String = ""
            switch component.gift {
            case let .generic(gift):
                titleText = gift.title ?? ""
            case let .unique(gift):
                titleText = gift.title
            }
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleText, font: Font.semibold(20.0), textColor: .white))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: contentHeight - 124.0), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.navigationBarContainer.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            var subtitleItems: [AnimatedTextComponent.Item] = []
            let subtitleString = self.isPlaying ? environment.strings.Gift_Variants_RandomTraits : environment.strings.Gift_Variants_SelectedTraits
            let words = subtitleString.components(separatedBy: " ")
            for i in 0 ..< words.count {
                var text = words[i]
                if i > 0 {
                    text = " \(text)"
                }
                subtitleItems.append(AnimatedTextComponent.Item(id: text.lowercased(), content: .text(text)))
            }
            
            let subtitleSize = self.subtitle.update(
                transition: .spring(duration: 0.2),
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.regular(14.0),
                    color: secondaryTextColor,
                    items: subtitleItems,
                    noDelay: true,
                    blur: true
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
            let subtitleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - subtitleSize.width) * 0.5), y: contentHeight - 97.0), size: subtitleSize)
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    self.navigationBarContainer.addSubview(subtitleView)
                }
                transition.setFrame(view: subtitleView, frame: subtitleFrame)
            }
            
            let attributeSpacing: CGFloat = 10.0
            let attributeWidth: CGFloat = floor((fillingSize - 32.0 - attributeSpacing * CGFloat(attributes.count - 1)) / CGFloat(attributes.count))
            let attributeHeight: CGFloat = 45.0
            
            for i in 0 ..< attributes.count {
                var attributeFrame = CGRect(origin: CGPoint(x: sideInset + CGFloat(i) * (attributeWidth + attributeSpacing), y: contentHeight - 60.0), size: CGSize(width: attributeWidth, height: attributeHeight))
                if i == attributes.count - 1 {
                    attributeFrame.size.width = max(0.0, availableSize.width - sideInset - attributeFrame.minX)
                }
                let attributeInfo: ComponentView<Empty>
                if self.attributeInfos.count > i {
                    attributeInfo = self.attributeInfos[i]
                } else {
                    attributeInfo = ComponentView()
                    self.attributeInfos.append(attributeInfo)
                }
                let attribute = attributes[i]
                let _ = attributeInfo.update(
                    transition: transition,
                    component: AnyComponent(AttributeInfoComponent(
                        strings: environment.strings,
                        backgroundColor: UIColor.white.withAlphaComponent(0.16),
                        secondaryTextColor: secondaryTextColor.mixedWith(.white, alpha: 0.3),
                        badgeColor: badgeColor,
                        attribute: attribute
                    )),
                    environment: {},
                    containerSize: attributeFrame.size
                )
                if let attributeInfoView = attributeInfo.view {
                    if attributeInfoView.superview == nil {
                        self.navigationBarContainer.addSubview(attributeInfoView)
                    }
                    transition.setFrame(view: attributeInfoView, frame: attributeFrame)
                }
            }
            
            let edgeEffectHeight: CGFloat = 44.0
            let edgeEffectFrame = CGRect(origin: CGPoint(x: rawSideInset, y: contentHeight + 44.0), size: CGSize(width: fillingSize, height: edgeEffectHeight))
            let edgeSolidFrame = CGRect(origin: CGPoint(x: rawSideInset, y: contentHeight), size: CGSize(width: fillingSize, height: 44.0))
            transition.setFrame(view: self.topEdgeSolidView, frame: edgeSolidFrame)
            transition.setFrame(view: self.topEdgeEffectView, frame: edgeEffectFrame)
            self.topEdgeSolidView.backgroundColor = theme.list.blocksBackgroundColor
            self.topEdgeEffectView.update(content: theme.list.blocksBackgroundColor, blur: true, alpha: 1.0, rect: edgeEffectFrame, edge: .top, edgeSize: edgeEffectFrame.height, transition: transition)
            
            contentHeight += 16.0
            
            let selectedId: AnyHashable
            switch self.selectedSection {
            case .models:
                selectedId = AnyHashable(SelectedSection.models)
            case .backdrops:
                selectedId = AnyHashable(SelectedSection.backdrops)
            case .symbols:
                selectedId = AnyHashable(SelectedSection.symbols)
            }
            
            let segmentedSize = self.segmentControl.update(
                transition: transition,
                component: AnyComponent(SegmentControlComponent(
                    theme: environment.theme,
                    items: [
                        SegmentControlComponent.Item(id: AnyHashable(SelectedSection.models), title: environment.strings.Gift_Variants_Models),
                        SegmentControlComponent.Item(id: AnyHashable(SelectedSection.backdrops), title: environment.strings.Gift_Variants_Backdrops),
                        SegmentControlComponent.Item(id: AnyHashable(SelectedSection.symbols), title: environment.strings.Gift_Variants_Symbols)
                    ],
                    selectedId: selectedId,
                    action: { [weak self] id in
                        guard let self, let component = self.component, let id = id.base as? SelectedSection else {
                            return
                        }
                        self.selectedSection = id
                        self.isPlaying = false
                        
                        self.updateEffectiveGifts(attributes: component.attributes)
                        self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                    })),
                environment: {},
                containerSize: CGSize(width: fillingSize - 8.0 * 2.0, height: 100.0)
            )
            let segmentedControlFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - segmentedSize.width) * 0.5), y: contentHeight), size: segmentedSize)
            if let segmentedControlComponentView = self.segmentControl.view {
                if segmentedControlComponentView.superview == nil {
                    self.navigationBarContainer.addSubview(self.topEdgeSolidView)
                    self.navigationBarContainer.addSubview(self.topEdgeEffectView)
                    self.navigationBarContainer.addSubview(segmentedControlComponentView)
                }
                transition.setFrame(view: segmentedControlComponentView, frame: segmentedControlFrame)
            }
            contentHeight += segmentedSize.height
            contentHeight += 18.0
            
            let itemHeight: CGFloat = 126.0
            let itemSpacing: CGFloat = 10.0
            
            var descriptionText: String
            let itemCount: Int32
            switch self.selectedSection {
            case .models:
                if self.displayCraftableModels {
                    descriptionText = environment.strings.Gift_Variants_CollectionInfo(environment.strings.Gift_Variants_CollectionInfo_CraftableModel(self.craftableModelCount)).string
                    itemCount = self.craftableModelCount
                    descriptionText += "\n[\(environment.strings.Gift_Variants_ViewPrimaryModels) >]()"
                } else {
                    descriptionText = environment.strings.Gift_Variants_CollectionInfo(environment.strings.Gift_Variants_CollectionInfo_Model(self.primaryModelCount)).string
                    itemCount = self.primaryModelCount
                    
                    if self.craftableModelCount > 0 {
                        descriptionText += "\n[\(environment.strings.Gift_Variants_ViewCraftableModels) >]()"
                    }
                }
            case .backdrops:
                descriptionText = environment.strings.Gift_Variants_CollectionInfo(environment.strings.Gift_Variants_CollectionInfo_Backdrop(self.backdropCount)).string
                itemCount = self.backdropCount
            case .symbols:
                descriptionText = environment.strings.Gift_Variants_CollectionInfo(environment.strings.Gift_Variants_CollectionInfo_Symbol(self.symbolCount)).string
                itemCount = self.symbolCount
            }
            
            let descriptionFont = Font.regular(13.0)
            let descriptionBoldFont = Font.semibold(13.0)
            let descriptionTextColor = theme.list.itemSecondaryTextColor
            let descriptionLinkColor = theme.list.itemAccentColor
            let descriptionMarkdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: descriptionFont, textColor: descriptionTextColor), bold: MarkdownAttributeSet(font: descriptionBoldFont, textColor: descriptionTextColor), link: MarkdownAttributeSet(font: descriptionFont, textColor: descriptionLinkColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            
            if self.cachedSmallChevronImage == nil || self.cachedSmallChevronImage?.1 !== environment.theme {
                self.cachedSmallChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextRightArrow"), color: descriptionLinkColor)!, theme)
            }
            
            let descriptionAttributedString = parseMarkdownIntoAttributedString(descriptionText, attributes: descriptionMarkdownAttributes, textAlignment: .center).mutableCopy() as! NSMutableAttributedString
            if let range = descriptionAttributedString.string.range(of: ">"), let chevronImage = self.cachedSmallChevronImage?.0 {
                descriptionAttributedString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: descriptionAttributedString.string))
            }
            
            let descriptionSize = self.descriptionText.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(descriptionAttributedString),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 3,
                    lineSpacing: 0.2,
                    highlightColor: descriptionLinkColor.withAlphaComponent(0.1),
                    highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                            return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                        } else {
                            return nil
                        }
                    },
                    tapAction: { [weak self] attributes, _ in
                        if let self, let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                            self.displayCraftableModels = !self.displayCraftableModels
                            self.isPlaying = false
                            
                            self.updateEffectiveGifts(attributes: component.attributes)
                            self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
            )
            let descriptionFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - descriptionSize.width) * 0.5), y: contentHeight), size: descriptionSize)
            if let descriptionView = self.descriptionText.view {
                if descriptionView.superview == nil {
                    self.scrollContentView.addSubview(descriptionView)
                }
                descriptionView.frame = descriptionFrame
            }
            self.currentDescriptionHeight = descriptionSize.height
            contentHeight += descriptionSize.height
            contentHeight += 26.0
            
            contentHeight += (itemHeight + itemSpacing) * ceil(CGFloat(itemCount) / 3.0)
            
            if self.backgroundHandleView.image == nil {
                self.backgroundHandleView.image = generateStretchableFilledCircleImage(diameter: 5.0, color: .white)?.withRenderingMode(.alwaysTemplate)
            }
            self.backgroundHandleView.tintColor = UIColor.white.withAlphaComponent(0.4)
            let backgroundHandleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - 36.0) * 0.5), y: 5.0), size: CGSize(width: 36.0, height: 5.0))
            if self.backgroundHandleView.superview == nil {
                self.navigationBarContainer.addSubview(self.backgroundHandleView)
            }
            transition.setFrame(view: self.backgroundHandleView, frame: backgroundHandleFrame)
            
            self.playbackGlassContainerView.update(size: CGSize(width: fillingSize, height: 64.0), isDark: false, transition: .immediate)
            self.playbackGlassContainerView.frame = CGRect(origin: CGPoint(x: rawSideInset, y: 0.0), size: CGSize(width: fillingSize, height: 64.0))
            
            self.closeGlassContainerView.update(size: CGSize(width: 64.0, height: 64.0), isDark: false, transition: .immediate)
            self.closeGlassContainerView.frame = CGRect(origin: CGPoint(x: rawSideInset, y: 0.0), size: CGSize(width: 64.0, height: 64.0))
            
            let closeButtonSize = self.closeButton.update(
                transition: transition,
                component: AnyComponent(GlassBarButtonComponent(
                    size: CGSize(width: 40.0, height: 40.0),
                    backgroundColor: buttonColor,
                    isDark: false,
                    state: .tintedGlass,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Back",
                            tintColor: .white
                        )
                    )),
                    action: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.environment?.controller()?.dismiss()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 40.0, height: 40.0)
            )
            let closeButtonFrame = CGRect(origin: CGPoint(x: 16.0, y: 16.0), size: closeButtonSize)
            if let closeButtonView = self.closeButton.view {
                if closeButtonView.superview == nil {
                    self.navigationBarContainer.addSubview(self.playbackGlassContainerView)
                    self.navigationBarContainer.addSubview(self.closeGlassContainerView)
                    self.closeGlassContainerView.contentView.addSubview(closeButtonView)
                }
                transition.setFrame(view: closeButtonView, frame: closeButtonFrame)
            }
    
            let playbackButtonSize = self.playbackButton.update(
                transition: transition,
                component: AnyComponent(GlassBarButtonComponent(
                    size: nil,
                    backgroundColor: buttonColor,
                    isDark: false,
                    state: .tintedGlass,
                    component: AnyComponentWithIdentity(id: "content", component: AnyComponent(
                        PlayButtonComponent(isPlay: !self.isPlaying, title: !self.isPlaying && self.showRandomizeTip ? environment.strings.Gift_Variants_Randomize : nil)
                    )),
                    action: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.isPlaying = !self.isPlaying
                        
                        if !self.isPlaying {
                            self.showRandomizeTip = true
                            Queue.mainQueue().after(2.0) {
                                if self.showRandomizeTip {
                                    self.showRandomizeTip = false
                                    self.state?.updated(transition: .easeInOut(duration: 0.25))
                                }
                            }
                        } else {
                            self.selectedModel = nil
                            self.selectedBackdrop = nil
                            self.selectedSymbol = nil
                            
                            self.showRandomizeTip = false
                            
                            self.previewTimerTick()
                        }
                        self.state?.updated(transition: .easeInOut(duration: 0.25))
                        
                        if let buttonView = self.playbackButton.view {
                            buttonView.isUserInteractionEnabled = false
                            Queue.mainQueue().after(0.3, {
                                buttonView.isUserInteractionEnabled = true
                            })
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 160.0, height: 40.0)
            )
            let playbackButtonFrame = CGRect(origin: CGPoint(x: fillingSize - 16.0 - playbackButtonSize.width, y: 16.0), size: playbackButtonSize)
            if let playbackButtonView = self.playbackButton.view {
                if playbackButtonView.superview == nil {
                    self.playbackGlassContainerView.contentView.addSubview(playbackButtonView)
                }
                transition.setFrame(view: playbackButtonView, frame: playbackButtonFrame)
            }
            
            let containerInset: CGFloat = environment.statusBarHeight + 10.0
            contentHeight += environment.safeInsets.bottom
            
            var initialContentHeight = contentHeight
            let clippingY: CGFloat
             
            initialContentHeight = contentHeight
            
            clippingY = availableSize.height
            
            let topInset: CGFloat = max(0.0, availableSize.height - containerInset - initialContentHeight)
            
            let scrollContentHeight = max(topInset + contentHeight + containerInset, availableSize.height - containerInset)
            
            self.scrollContentClippingView.layer.cornerRadius = 38.0
            
            self.itemLayout = ItemLayout(containerSize: availableSize, containerInset: containerInset, containerCornerRadius: environment.deviceMetrics.screenCornerRadius, bottomInset: environment.safeInsets.bottom, topInset: topInset)
            
            transition.setFrame(view: self.scrollContentView, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset + containerInset), size: CGSize(width: availableSize.width, height: contentHeight)))
            
            transition.setPosition(layer: self.backgroundLayer, position: CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0))
            transition.setBounds(layer: self.backgroundLayer, bounds: CGRect(origin: CGPoint(), size: CGSize(width: fillingSize, height: availableSize.height)))
            
            let scrollClippingFrame = CGRect(origin: CGPoint(x: 0.0, y: containerInset), size: CGSize(width: availableSize.width, height: clippingY - containerInset))
            transition.setPosition(view: self.scrollContentClippingView, position: scrollClippingFrame.center)
            transition.setBounds(view: self.scrollContentClippingView, bounds: CGRect(origin: CGPoint(x: scrollClippingFrame.minX, y: scrollClippingFrame.minY), size: scrollClippingFrame.size))
            
            self.ignoreScrolling = true
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: availableSize.height)))
            let contentSize = CGSize(width: availableSize.width, height: scrollContentHeight)
            if contentSize != self.scrollView.contentSize {
                self.scrollView.contentSize = contentSize
            }
            if resetScrolling {
                self.scrollView.bounds = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: availableSize)
            }
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
            transition.setPosition(view: self.containerView, position: CGRect(origin: CGPoint(), size: availableSize).center)
            transition.setBounds(view: self.containerView, bounds: CGRect(origin: CGPoint(), size: availableSize))
                        
            if let controller = environment.controller(), !controller.automaticallyControlPresentationContextLayout {
                let bottomInset: CGFloat = contentHeight - 12.0
            
                let layout = ContainerViewLayout(
                    size: availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomInset, right: 0.0),
                    safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0),
                    additionalInsets: .zero,
                    statusBarHeight: environment.statusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(layout, transition: transition.containedViewLayoutTransition)
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

public class GiftUpgradeVariantsScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    
    private var didPlayAppearAnimation: Bool = false
    private var isDismissed: Bool = false
    
    public init(
        context: AccountContext,
        gift: StarGift,
        crafted: Bool = false,
        attributes: [StarGift.UniqueGift.Attribute],
        selectedAttributes: [StarGift.UniqueGift.Attribute]?,
        focusedAttribute: StarGift.UniqueGift.Attribute?
    ) {
        self.context = context
        
        super.init(context: context, component: GiftUpgradeVariantsScreenComponent(
            context: context,
            gift: gift,
            crafted: crafted,
            attributes: attributes,
            selectedAttributes: selectedAttributes,
            focusedAttribute: focusedAttribute
        ), navigationBarAppearance: .none, theme: .default)
        
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
        self.automaticallyControlPresentationContextLayout = false
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.view.disablesInteractiveModalDismiss = true
        
        if !self.didPlayAppearAnimation {
            self.didPlayAppearAnimation = true
            
            if let componentView = self.node.hostView.componentView as? GiftUpgradeVariantsScreenComponent.View {
                Queue.mainQueue().justDispatch {
                    componentView.animateIn()
                }
            }
        }
    }
        
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            
            if let componentView = self.node.hostView.componentView as? GiftUpgradeVariantsScreenComponent.View {
                componentView.animateOut(completion: { [weak self] in
                    completion?()
                    self?.dismiss(animated: false)
                })
            } else {
                self.dismiss(animated: false)
            }
        }
    }
}

private final class AttributeInfoComponent: Component {
    let strings: PresentationStrings
    let backgroundColor: UIColor
    let secondaryTextColor: UIColor
    let badgeColor: UIColor
    let attribute: StarGift.UniqueGift.Attribute
    
    init(
        strings: PresentationStrings,
        backgroundColor: UIColor,
        secondaryTextColor: UIColor,
        badgeColor: UIColor,
        attribute: StarGift.UniqueGift.Attribute
    ) {
        self.strings = strings
        self.backgroundColor = backgroundColor
        self.secondaryTextColor = secondaryTextColor
        self.badgeColor = badgeColor
        self.attribute = attribute
    }
    
    static func ==(lhs: AttributeInfoComponent, rhs: AttributeInfoComponent) -> Bool {
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.secondaryTextColor != rhs.secondaryTextColor {
            return false
        }
        if lhs.badgeColor != rhs.badgeColor {
            return false
        }
        if lhs.attribute != rhs.attribute {
            return false
        }
        return true
    }
    
    final class View: UIView {
        let background = SimpleLayer()
        let title = ComponentView<Empty>()
        let subtitle = ComponentView<Empty>()
        
        let badgeBackground = SimpleLayer()
        let badge = ComponentView<Empty>()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: AttributeInfoComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let backgroundFrame = CGRect(origin: CGPoint(), size: availableSize)
            if self.background.superlayer == nil {
                self.background.cornerRadius = 16.0
                self.background.cornerCurve = .continuous
                self.layer.addSublayer(self.background)
                
                self.badgeBackground.cornerRadius = 9.5
                self.badgeBackground.cornerCurve = .continuous
                self.layer.addSublayer(self.badgeBackground)
            }
            self.background.frame = backgroundFrame
            transition.setBackgroundColor(layer: self.background, color: component.backgroundColor)
            
            func formatPercentage(_ value: Float) -> String {
                return String(format: "%0.1f", value).replacingOccurrences(of: ".0", with: "").replacingOccurrences(of: ",0", with: "") + "%"
            }
            
            let title: String
            let subtitle: String
            let rarity: StarGift.UniqueGift.Attribute.Rarity?
            switch component.attribute {
            case let .model(name, _, rarityValue, _):
                title = name
                subtitle = component.strings.Gift_Variants_Model
                rarity = rarityValue
            case let .backdrop(name, _, _, _, _, _, rarityValue):
                title = name
                subtitle = component.strings.Gift_Variants_Backdrop
                rarity = rarityValue
            case let .pattern(name, _, rarityValue):
                title = name
                subtitle = component.strings.Gift_Variants_Symbol
                rarity = rarityValue
            default:
                title = ""
                subtitle = ""
                rarity = nil
            }
                    
            let titleSize = self.title.update(
                transition: .spring(duration: 0.2),
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.semibold(13.0),
                    color: UIColor.white,
                    items: [AnimatedTextComponent.Item(id: "title", content: .text(title))],
                    noDelay: true,
                    blur: true
                )),
                environment: {},
                containerSize: CGSize(width: backgroundFrame.size.width - 8.0, height: backgroundFrame.size.height)
            )
            let subtitleSize = self.subtitle.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: subtitle, font: Font.regular(11.0), textColor: .white)),
                    tintColor: component.secondaryTextColor
                )),
                environment: {},
                containerSize: backgroundFrame.size
            )
            
            let spacing: CGFloat = 0.0
            let titleFrame = CGRect(origin: CGPoint(x: floor((backgroundFrame.width - titleSize.width) * 0.5), y: floor((backgroundFrame.height - titleSize.height - spacing - subtitleSize.height) * 0.5)), size: titleSize)
            let subtitleFrame = CGRect(origin: CGPoint(x: floor((backgroundFrame.width - subtitleSize.width) * 0.5), y: titleFrame.maxY + spacing), size: subtitleSize)
            
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    self.addSubview(subtitleView)
                }
                transition.setFrame(view: subtitleView, frame: subtitleFrame)
            }
            
            var badgeString = ""
            var badgeColor = component.badgeColor
            if let rarity {
                switch rarity {
                case let .permille(value):
                    if value == 0 {
                        badgeString = "<\(formatPercentage(0.1))"
                    } else {
                        badgeString = formatPercentage(Float(value) * 0.1)
                    }
                case .epic:
                    badgeString = component.strings.Gift_Attribute_Epic
                    badgeColor = UIColor(rgb: 0xaf52de)
                case .legendary:
                    badgeString = component.strings.Gift_Attribute_Legendary
                    badgeColor = UIColor(rgb: 0xd57e32)
                case .rare:
                    badgeString = component.strings.Gift_Attribute_Rare
                    badgeColor = UIColor(rgb: 0x25a3b9)
                case .uncommon:
                    badgeString = component.strings.Gift_Attribute_Uncommon
                    badgeColor = UIColor(rgb: 0x22b447)
                }
            }
            
            var badgeItems: [AnimatedTextComponent.Item] = []
            if badgeString.contains("%") {
                var clippedRarity = badgeString
                clippedRarity.removeLast()
                badgeItems = [
                    AnimatedTextComponent.Item(id: "value", content: .text(clippedRarity)),
                    AnimatedTextComponent.Item(id: "percent", content: .text("%")),
                ]
            } else {
                badgeItems = [
                    AnimatedTextComponent.Item(id: "rarity", content: .text(badgeString))
                ]
            }
            
            let badgeSize = self.badge.update(
                transition: .spring(duration: 0.2),
                component: AnyComponent(AnimatedTextComponent(
                    font: Font.with(size: 12.0, weight: .semibold, traits: .monospacedNumbers),
                    color: UIColor.white,
                    items: badgeItems,
                    noDelay: true,
                    blur: true
                )),
                environment: {},
                containerSize: backgroundFrame.size
            )
            let badgeFrame = CGRect(origin: CGPoint(x: backgroundFrame.width - badgeSize.width - 2.0, y: backgroundFrame.minY - 8.0), size: badgeSize)
            if let badgeView = self.badge.view {
                if badgeView.superview == nil {
                    self.addSubview(badgeView)
                }
                transition.setFrame(view: badgeView, frame: badgeFrame)
            }
            
            let badgeBackgroundFrame = badgeFrame.insetBy(dx: -5.5, dy: -2.0)
            transition.setFrame(layer: self.badgeBackground, frame: badgeBackgroundFrame)
            transition.setBackgroundColor(layer: self.badgeBackground, color: badgeColor)
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}


private final class PlayButtonComponent: Component {
    let isPlay: Bool
    let title: String?
    
    public init(
        isPlay: Bool,
        title: String?
    ) {
        self.isPlay = isPlay
        self.title = title
    }
    
    static func ==(lhs: PlayButtonComponent, rhs: PlayButtonComponent) -> Bool {
        if lhs.isPlay != rhs.isPlay {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        return true
    }

    final class View: UIView {
        private var component: PlayButtonComponent?
        private weak var componentState: EmptyComponentState?
        
        private let containerView = UIView()
        private let titleContainerView = UIView()
        private let title = ComponentView<Empty>()
        private let play = ComponentView<Empty>()
        private let pause = ComponentView<Empty>()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.containerView.clipsToBounds = true
            self.containerView.layer.cornerRadius = 20.0
            self.addSubview(self.containerView)
            
            self.titleContainerView.clipsToBounds = true
            self.containerView.addSubview(self.titleContainerView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: PlayButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.componentState = state
            
            var contentSize = CGSize(width: 15.0, height: 21.0)
            
            var titleSize = CGSize()
            if let titleString = component.title {
                titleSize = self.title.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: titleString, font: Font.semibold(17.0), textColor: .white)))),
                    environment: {},
                    containerSize: availableSize
                )
                let titleFrame = CGRect(origin: CGPoint(x: 9.0, y: 10.0), size: titleSize)
                if let titleView = self.title.view {
                    titleView.alpha = 1.0
                    if titleView.superview == nil {
                        self.titleContainerView.addSubview(titleView)
                        transition.animateAlpha(view: titleView, from: 0.0, to: 1.0)
                    }
                    titleView.frame = titleFrame
                }
                contentSize.width += titleSize.width + 4.0
            } else if let titleView = self.title.view {
                transition.setAlpha(view: titleView, alpha: 0.0, completion: { finished in
                    if finished {
                        titleView.removeFromSuperview()
                    }
                })
            }
            transition.setFrame(view: self.titleContainerView, frame: CGRect(origin: .zero, size: CGSize(width: titleSize.width + 14.0, height: 40.0)))
            
            if component.isPlay {
                let iconSize = self.play.update(
                    transition: .immediate,
                    component: AnyComponent(BundleIconComponent(name: "Media Gallery/PlayButton", tintColor: .white)),
                    environment: {},
                    containerSize: availableSize
                )
                let iconFrame = CGRect(origin: CGPoint(x: contentSize.width - iconSize.width + 21.0, y: 5.0), size: iconSize)
                if let iconView = self.play.view {
                    iconView.alpha = 1.0
                    if iconView.superview == nil {
                        self.containerView.addSubview(iconView)
                        transition.animateAlpha(view: iconView, from: 0.0, to: 1.0)
                        transition.animateScale(view: iconView, from: 0.01, to: 1.0)
                    }
                    transition.setFrame(view: iconView, frame: iconFrame)
                }
            } else if let iconView = self.play.view {
                transition.setAlpha(view: iconView, alpha: 0.0, completion: { finished in
                    if finished {
                        iconView.removeFromSuperview()
                    }
                })
                transition.animateScale(view: iconView, from: 1.0, to: 0.01)
            }
            
            if !component.isPlay {
                let iconSize = self.pause.update(
                    transition: .immediate,
                    component: AnyComponent(BundleIconComponent(name: "Media Gallery/PictureInPicturePause", tintColor: .white)),
                    environment: {},
                    containerSize: availableSize
                )
                let iconFrame = CGRect(origin: CGPoint(x: contentSize.width - iconSize.width + 12.0 - UIScreenPixel, y: 13.0 - UIScreenPixel), size: iconSize)
                if let iconView = self.pause.view {
                    iconView.alpha = 1.0
                    if iconView.superview == nil {
                        self.containerView.addSubview(iconView)
                        transition.animateAlpha(view: iconView, from: 0.0, to: 1.0)
                        transition.animateScale(view: iconView, from: 0.01, to: 1.0)
                    }
                    transition.setFrame(view: iconView, frame: iconFrame)
                }
            } else if let iconView = self.pause.view {
                transition.setAlpha(view: iconView, alpha: 0.0, completion: { finished in
                    if finished {
                        iconView.removeFromSuperview()
                    }
                })
                transition.animateScale(view: iconView, from: 1.0, to: 0.01)
            }
            
            let containerWidth: CGFloat = contentSize.width + 26.0
            let containerFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((contentSize.width - containerWidth) / 2.0), y: floorToScreenPixels((contentSize.height - 40.0) / 2.0)), size: CGSize(width: containerWidth, height: 40.0))
            transition.setFrame(view: self.containerView, frame: containerFrame)
            
            return contentSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

