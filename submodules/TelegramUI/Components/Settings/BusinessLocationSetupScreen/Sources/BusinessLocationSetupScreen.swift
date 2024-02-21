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
import ListSectionComponent
import ListActionItemComponent
import ListMultilineTextFieldItemComponent
import BundleIconComponent
import LottieComponent
import Markdown
import LocationUI

final class BusinessLocationSetupScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let initialValue: TelegramBusinessLocation?
    let completion: (TelegramBusinessLocation?) -> Void

    init(
        context: AccountContext,
        initialValue: TelegramBusinessLocation?,
        completion: @escaping (TelegramBusinessLocation?) -> Void
    ) {
        self.context = context
        self.initialValue = initialValue
        self.completion = completion
    }

    static func ==(lhs: BusinessLocationSetupScreenComponent, rhs: BusinessLocationSetupScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.initialValue != rhs.initialValue {
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
        
        private let navigationTitle = ComponentView<Empty>()
        private let icon = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        private let addressSection = ComponentView<Empty>()
        private let mapSection = ComponentView<Empty>()
        
        private var isUpdating: Bool = false
        
        private var component: BusinessLocationSetupScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private let textFieldTag = NSObject()
        private var resetAddressText: String?
        
        private var mapCoordinates: TelegramBusinessLocation.Coordinates?
        
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
            
            super.init(frame: frame)
            
            self.scrollView.delegate = self
            self.addSubview(self.scrollView)
            
            self.scrollView.layer.addSublayer(self.topOverscrollLayer)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }
        
        func attemptNavigation(complete: @escaping () -> Void) -> Bool {
            if let component = self.component {
                var address = ""
                if let textView = self.addressSection.findTaggedView(tag: self.textFieldTag) as? ListMultilineTextFieldItemComponent.View {
                    address = textView.currentText
                }
                
                var businessLocation: TelegramBusinessLocation?
                if !address.isEmpty || self.mapCoordinates != nil {
                    businessLocation = TelegramBusinessLocation(address: address, coordinates: self.mapCoordinates)
                }
                
                let _ = component.context.engine.accountData.updateAccountBusinessLocation(businessLocation: businessLocation).startStandalone()
            }
            
            return true
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            self.updateScrolling(transition: .immediate)
        }
        
        var scrolledUp = true
        private func updateScrolling(transition: Transition) {
            let navigationRevealOffsetY: CGFloat = 0.0
            
            let navigationAlphaDistance: CGFloat = 16.0
            let navigationAlpha: CGFloat = max(0.0, min(1.0, (self.scrollView.contentOffset.y - navigationRevealOffsetY) / navigationAlphaDistance))
            if let controller = self.environment?.controller(), let navigationBar = controller.navigationBar {
                transition.setAlpha(layer: navigationBar.backgroundNode.layer, alpha: navigationAlpha)
                transition.setAlpha(layer: navigationBar.stripeNode.layer, alpha: navigationAlpha)
            }
            
            var scrolledUp = false
            if navigationAlpha < 0.5 {
                scrolledUp = true
            } else if navigationAlpha > 0.5 {
                scrolledUp = false
            }
            
            if self.scrolledUp != scrolledUp {
                self.scrolledUp = scrolledUp
                if !self.isUpdating {
                    self.state?.updated()
                }
            }
            
            if let navigationTitleView = self.navigationTitle.view {
                transition.setAlpha(view: navigationTitleView, alpha: 1.0)
            }
        }
        
        private func openLocationPicker() {
            guard let component = self.component else {
                return
            }
            
            let controller = LocationPickerController(context: component.context, updatedPresentationData: nil, mode: .pick, completion: { [weak self] location, _, _, address, _ in
                guard let self else {
                    return
                }
                
                self.mapCoordinates = TelegramBusinessLocation.Coordinates(latitude: location.latitude, longitude: location.longitude)
                if let textView = self.addressSection.findTaggedView(tag: self.textFieldTag) as? ListMultilineTextFieldItemComponent.View, textView.currentText.isEmpty {
                    self.resetAddressText = address
                }
                
                self.state?.updated(transition: .immediate)
            })
            self.environment?.controller()?.push(controller)
        }
        
        func update(component: BusinessLocationSetupScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            if self.component == nil {
                if let initialValue = component.initialValue {
                    self.mapCoordinates = initialValue.coordinates
                    self.resetAddressText = initialValue.address
                }
            }
            
            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
            
            self.component = component
            self.state = state
            
            if themeUpdated {
                self.backgroundColor = environment.theme.list.blocksBackgroundColor
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            //TODO:localize
            let navigationTitleSize = self.navigationTitle.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: "Location", font: Font.semibold(17.0), textColor: environment.theme.rootController.navigationBar.primaryTextColor)),
                    horizontalAlignment: .center
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 100.0)
            )
            let navigationTitleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - navigationTitleSize.width) / 2.0), y: environment.statusBarHeight + floor((environment.navigationHeight - environment.statusBarHeight - navigationTitleSize.height) / 2.0)), size: navigationTitleSize)
            if let navigationTitleView = self.navigationTitle.view {
                if navigationTitleView.superview == nil {
                    if let controller = self.environment?.controller(), let navigationBar = controller.navigationBar {
                        navigationBar.view.addSubview(navigationTitleView)
                    }
                }
                transition.setFrame(view: navigationTitleView, frame: navigationTitleFrame)
            }
            
            let bottomContentInset: CGFloat = 24.0
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let sectionSpacing: CGFloat = 32.0
            
            let _ = bottomContentInset
            let _ = sectionSpacing
            
            var contentHeight: CGFloat = 0.0
            
            contentHeight += environment.navigationHeight
            
            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: "🗺", font: Font.semibold(90.0), textColor: environment.theme.rootController.navigationBar.primaryTextColor)),
                    horizontalAlignment: .center
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            let iconFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - iconSize.width) * 0.5), y: contentHeight + 2.0), size: iconSize)
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    self.scrollView.addSubview(iconView)
                }
                transition.setPosition(view: iconView, position: iconFrame.center)
                iconView.bounds = CGRect(origin: CGPoint(), size: iconFrame.size)
            }
            
            contentHeight += 129.0
            
            //TODO:localize
            let subtitleString = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString("Display the location of your business on your account.", attributes: MarkdownAttributes(
                body: MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.freeTextColor),
                bold: MarkdownAttributeSet(font: Font.semibold(15.0), textColor: environment.theme.list.freeTextColor),
                link: MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.itemAccentColor),
                linkAttribute: { attributes in
                    return ("URL", "")
                }), textAlignment: .center
            ))
            
            //TODO:localize
            let subtitleSize = self.subtitle.update(
                transition: .immediate,
                component: AnyComponent(BalancedTextComponent(
                    text: .plain(subtitleString),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.25,
                    highlightColor: environment.theme.list.itemAccentColor.withMultipliedAlpha(0.1),
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: "URL")] {
                            return NSAttributedString.Key(rawValue: "URL")
                        } else {
                            return nil
                        }
                    },
                    tapAction: { [weak self] _, _ in
                        guard let self, let component = self.component else {
                            return
                        }
                        let _ = component
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
            )
            let subtitleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - subtitleSize.width) * 0.5), y: contentHeight), size: subtitleSize)
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    self.scrollView.addSubview(subtitleView)
                }
                transition.setPosition(view: subtitleView, position: subtitleFrame.center)
                subtitleView.bounds = CGRect(origin: CGPoint(), size: subtitleFrame.size)
            }
            contentHeight += subtitleSize.height
            contentHeight += 27.0
            
            var addressSectionItems: [AnyComponentWithIdentity<Empty>] = []
            addressSectionItems.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(ListMultilineTextFieldItemComponent(
                context: component.context,
                theme: environment.theme,
                strings: environment.strings,
                initialText: "",
                resetText: self.resetAddressText.flatMap { resetAddressText in
                    return ListMultilineTextFieldItemComponent.ResetText(value: resetAddressText)
                },
                placeholder: "Enter Address",
                autocapitalizationType: .none,
                autocorrectionType: .no,
                characterLimit: 64,
                updated: { [weak self] value in
                    guard let self else {
                        return
                    }
                    let _ = self
                    let _ = value
                },
                tag: self.textFieldTag
            ))))
            self.resetAddressText = nil
            
            //TODO:localize
            let addressSectionSize = self.addressSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: nil,
                    footer: nil,
                    items: addressSectionItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let addressSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: addressSectionSize)
            if let addressSectionView = self.addressSection.view {
                if addressSectionView.superview == nil {
                    self.scrollView.addSubview(addressSectionView)
                    self.addressSection.parentState = state
                }
                transition.setFrame(view: addressSectionView, frame: addressSectionFrame)
            }
            contentHeight += addressSectionSize.height
            contentHeight += sectionSpacing
            
            var mapSectionItems: [AnyComponentWithIdentity<Empty>] = []
            //TODO:localize
            mapSectionItems.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                theme: environment.theme,
                title: AnyComponent(VStack([
                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: "Set Location on Map",
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: environment.theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    ))),
                ], alignment: .left, spacing: 2.0)),
                accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: self.mapCoordinates != nil, isInteractive: self.mapCoordinates != nil)),
                action: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    if self.mapCoordinates == nil {
                        self.openLocationPicker()
                    } else {
                        self.mapCoordinates = nil
                        self.state?.updated(transition: .spring(duration: 0.4))
                    }
                }
            ))))
            if let mapCoordinates = self.mapCoordinates {
                mapSectionItems.append(AnyComponentWithIdentity(id: 1, component: AnyComponent(MapPreviewComponent(
                    theme: environment.theme,
                    location: MapPreviewComponent.Location(
                        latitude: mapCoordinates.latitude,
                        longitude: mapCoordinates.longitude
                    ),
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.openLocationPicker()
                    }
                ))))
            }
            
            //TODO:localize
            let mapSectionSize = self.mapSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: nil,
                    footer: nil,
                    items: mapSectionItems,
                    displaySeparators: false
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let mapSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: mapSectionSize)
            if let mapSectionView = self.mapSection.view {
                if mapSectionView.superview == nil {
                    self.scrollView.addSubview(mapSectionView)
                }
                transition.setFrame(view: mapSectionView, frame: mapSectionFrame)
            }
            contentHeight += mapSectionSize.height
            
            contentHeight += bottomContentInset
            contentHeight += environment.safeInsets.bottom
            
            let previousBounds = self.scrollView.bounds
            
            let contentSize = CGSize(width: availableSize.width, height: contentHeight)
            if self.scrollView.frame != CGRect(origin: CGPoint(), size: availableSize) {
                self.scrollView.frame = CGRect(origin: CGPoint(), size: availableSize)
            }
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollInsets = UIEdgeInsets(top: environment.navigationHeight, left: 0.0, bottom: 0.0, right: 0.0)
            if self.scrollView.scrollIndicatorInsets != scrollInsets {
                self.scrollView.scrollIndicatorInsets = scrollInsets
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
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class BusinessLocationSetupScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    
    public init(
        context: AccountContext,
        initialValue: TelegramBusinessLocation?,
        completion: @escaping (TelegramBusinessLocation?) -> Void
    ) {
        self.context = context
        
        super.init(context: context, component: BusinessLocationSetupScreenComponent(
            context: context,
            initialValue: initialValue,
            completion: completion
        ), navigationBarAppearance: .default, theme: .default, updatedPresentationData: nil)
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.title = ""
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? BusinessLocationSetupScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
        
        self.attemptNavigation = { [weak self] complete in
            guard let self, let componentView = self.node.hostView.componentView as? BusinessLocationSetupScreenComponent.View else {
                return true
            }
            
            return componentView.attemptNavigation(complete: complete)
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    }
}
