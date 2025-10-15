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
import CoreLocation
import Geocoding

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
        private let deleteSection = ComponentView<Empty>()
        
        private var isUpdating: Bool = false
        
        private var component: BusinessLocationSetupScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        private let addressTextInputState = ListMultilineTextFieldItemComponent.ExternalState()
        private let textFieldTag = NSObject()
        private var resetAddressText: String?
        
        private var isLoadingGeocodedAddress: Bool = false
        private var geocodeDisposable: Disposable?
        
        private var mapCoordinates: TelegramBusinessLocation.Coordinates?
        private var mapCoordinatesManuallySet: Bool = false
        
        private var applyButtonItem: UIBarButtonItem?
        
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
            self.geocodeDisposable?.dispose()
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }
        
        func attemptNavigation(complete: @escaping () -> Void) -> Bool {
            guard let component = self.component, let environment = self.environment else {
                return true
            }
            
            let businessLocation = self.currentBusinessLocation()
            
            if businessLocation != component.initialValue {
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                self.environment?.controller()?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: environment.strings.BusinessLocationSetup_AlertUnsavedChanges_Text, actions: [
                    TextAlertAction(type: .genericAction, title: environment.strings.Common_Cancel, action: {
                    }),
                    TextAlertAction(type: .destructiveAction, title: environment.strings.BusinessLocationSetup_AlertUnsavedChanges_ResetAction, action: {
                        complete()
                    })
                ]), in: .window(.root))
                
                return false
            }
            
            return true
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            self.updateScrolling(transition: .immediate)
        }
        
        var scrolledUp = true
        private func updateScrolling(transition: ComponentTransition) {
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
        
        private func currentBusinessLocation() -> TelegramBusinessLocation? {
            var address = ""
            if let textView = self.addressSection.findTaggedView(tag: self.textFieldTag) as? ListMultilineTextFieldItemComponent.View {
                address = textView.currentText
            }
            
            var businessLocation: TelegramBusinessLocation?
            if !address.isEmpty || self.mapCoordinates != nil {
                businessLocation = TelegramBusinessLocation(address: address, coordinates: self.mapCoordinates)
            }
            return businessLocation
        }
        
        private func openLocationPicker() {
            var initialLocation: CLLocationCoordinate2D?
            var initialGeocodedLocation: String?
            if let mapCoordinates = self.mapCoordinates {
                initialLocation = CLLocationCoordinate2D(latitude: mapCoordinates.latitude, longitude: mapCoordinates.longitude)
            } else if let textView = self.addressSection.findTaggedView(tag: self.textFieldTag) as? ListMultilineTextFieldItemComponent.View, textView.currentText.count >= 2 {
                initialGeocodedLocation = textView.currentText
            }
            
            if let initialGeocodedLocation {
                self.isLoadingGeocodedAddress = true
                self.state?.updated(transition: .immediate)
                
                self.geocodeDisposable?.dispose()
                self.geocodeDisposable = (geocodeLocation(address: initialGeocodedLocation)
                |> deliverOnMainQueue).startStrict(next: { [weak self] venues in
                    guard let self else {
                        return
                    }
                    self.isLoadingGeocodedAddress = false
                    self.state?.updated(transition: .immediate)
                    self.presentLocationPicker(initialLocation: venues?.first?.location?.coordinate)
                })
            } else {
                self.presentLocationPicker(initialLocation: initialLocation)
            }
        }
            
        private func presentLocationPicker(initialLocation: CLLocationCoordinate2D?) {
            guard let component = self.component else {
                return
            }
            let controller = LocationPickerController(context: component.context, updatedPresentationData: nil, mode: .pick, initialLocation: initialLocation, completion: { [weak self] location, _, _, address, _ in
                guard let self else {
                    return
                }
                
                self.mapCoordinates = TelegramBusinessLocation.Coordinates(latitude: location.latitude, longitude: location.longitude)
                self.mapCoordinatesManuallySet = true
                if let textView = self.addressSection.findTaggedView(tag: self.textFieldTag) as? ListMultilineTextFieldItemComponent.View, textView.currentText.isEmpty {
                    self.resetAddressText = address
                }
                
                self.state?.updated(transition: .immediate)
            })
            self.environment?.controller()?.push(controller)
        }
        
        @objc private func savePressed() {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            
            var address = ""
            if let textView = self.addressSection.findTaggedView(tag: self.textFieldTag) as? ListMultilineTextFieldItemComponent.View {
                address = textView.currentText
            }
            
            let businessLocation = self.currentBusinessLocation()
            
            if businessLocation != nil && address.isEmpty {
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                self.environment?.controller()?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: environment.strings.BusinessLocationSetup_ErrorAddressEmpty_Text, actions: [
                    TextAlertAction(type: .genericAction, title: environment.strings.Common_OK, action: {
                    })
                ]), in: .window(.root))
                
                return
            }
            
            let _ = component.context.engine.accountData.updateAccountBusinessLocation(businessLocation: businessLocation).startStandalone()
            environment.controller()?.dismiss()
        }
        
        func update(component: BusinessLocationSetupScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            if self.component == nil {
                if let initialValue = component.initialValue {
                    self.mapCoordinates = initialValue.coordinates
                    if self.mapCoordinates != nil {
                        self.mapCoordinatesManuallySet = true
                    }
                    self.resetAddressText = initialValue.address
                }
            }
            
            let environment = environment[EnvironmentType.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            self.environment = environment
            
            self.component = component
            self.state = state
            
            let alphaTransition: ComponentTransition
            if !transition.animation.isImmediate {
                alphaTransition = .easeInOut(duration: 0.25)
            } else {
                alphaTransition = .immediate
            }
            
            if themeUpdated {
                self.backgroundColor = environment.theme.list.blocksBackgroundColor
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            let navigationTitleSize = self.navigationTitle.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: environment.strings.BusinessLocationSetup_Title, font: Font.semibold(17.0), textColor: environment.theme.rootController.navigationBar.primaryTextColor)),
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
            let sectionSpacing: CGFloat = 24.0
            
            var contentHeight: CGFloat = 0.0
            
            contentHeight += environment.navigationHeight
            
            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: "MapEmoji"),
                    loop: false
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            let iconFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - iconSize.width) * 0.5), y: contentHeight + 11.0), size: iconSize)
            if let iconView = self.icon.view as? LottieComponent.View {
                if iconView.superview == nil {
                    self.scrollView.addSubview(iconView)
                    iconView.playOnce()
                }
                transition.setPosition(view: iconView, position: iconFrame.center)
                iconView.bounds = CGRect(origin: CGPoint(), size: iconFrame.size)
            }
            
            contentHeight += 129.0
            
            let subtitleString = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(environment.strings.BusinessLocationSetup_Text, attributes: MarkdownAttributes(
                body: MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.freeTextColor),
                bold: MarkdownAttributeSet(font: Font.semibold(15.0), textColor: environment.theme.list.freeTextColor),
                link: MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.itemAccentColor),
                linkAttribute: { attributes in
                    return ("URL", "")
                }), textAlignment: .center
            ))
            
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
                externalState: self.addressTextInputState,
                context: component.context,
                theme: environment.theme,
                strings: environment.strings,
                initialText: "",
                resetText: self.resetAddressText.flatMap { resetAddressText in
                    return ListMultilineTextFieldItemComponent.ResetText(value: resetAddressText)
                },
                placeholder: environment.strings.BusinessLocationSetup_AddressPlaceholder,
                autocapitalizationType: .none,
                autocorrectionType: .no,
                characterLimit: 256,
                emptyLineHandling: .oneConsecutive,
                updated: { _ in
                },
                textUpdateTransition: .spring(duration: 0.4),
                tag: self.textFieldTag
            ))))
            self.resetAddressText = nil
            
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
            
            let mapSelectionAccessory: ListActionItemComponent.Accessory?
            if self.isLoadingGeocodedAddress {
                mapSelectionAccessory = .activity
            } else {
                mapSelectionAccessory = .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: self.mapCoordinates != nil, isInteractive: self.mapCoordinates != nil))
            }
            
            mapSectionItems.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                theme: environment.theme,
                title: AnyComponent(VStack([
                    AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: environment.strings.BusinessLocationSetup_SetLocationOnMap,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: environment.theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    ))),
                ], alignment: .left, spacing: 2.0)),
                accessory: mapSelectionAccessory,
                action: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    if self.mapCoordinates == nil {
                        self.openLocationPicker()
                    } else {
                        self.mapCoordinates = nil
                        self.mapCoordinatesManuallySet = false
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
            
            var deleteSectionHeight: CGFloat = 0.0
            deleteSectionHeight += sectionSpacing
            let deleteSectionSize = self.deleteSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: environment.theme,
                    header: nil,
                    footer: nil,
                    items: [
                        AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                            theme: environment.theme,
                            title: AnyComponent(VStack([
                                AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: environment.strings.BusinessLocationSetup_DeleteLocation,
                                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                                        textColor: environment.theme.list.itemDestructiveColor
                                    )),
                                    maximumNumberOfLines: 1
                                ))),
                            ], alignment: .left, spacing: 2.0)),
                            accessory: nil,
                            action: { [weak self] _ in
                                guard let self else {
                                    return
                                }
                                
                                self.resetAddressText = ""
                                self.mapCoordinates = nil
                                self.mapCoordinatesManuallySet = false
                                self.state?.updated(transition: .spring(duration: 0.4))
                            }
                        )))
                    ],
                    displaySeparators: false
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 10000.0)
            )
            let deleteSectionFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight + deleteSectionHeight), size: deleteSectionSize)
            if let deleteSectionView = self.deleteSection.view {
                if deleteSectionView.superview == nil {
                    self.scrollView.addSubview(deleteSectionView)
                }
                transition.setFrame(view: deleteSectionView, frame: deleteSectionFrame)
                
                if self.mapCoordinates != nil || self.addressTextInputState.hasText {
                    alphaTransition.setAlpha(view: deleteSectionView, alpha: 1.0)
                } else {
                    alphaTransition.setAlpha(view: deleteSectionView, alpha: 0.0)
                }
            }
            deleteSectionHeight += deleteSectionSize.height
            
            if self.mapCoordinates != nil || self.addressTextInputState.hasText {
                contentHeight += deleteSectionHeight
            }
            
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
            
            if let controller = environment.controller() as? BusinessLocationSetupScreen {
                let businessLocation = self.currentBusinessLocation()
                
                if businessLocation == component.initialValue {
                    if controller.navigationItem.rightBarButtonItem != nil {
                        controller.navigationItem.setRightBarButton(nil, animated: true)
                    }
                } else {
                    let applyButtonItem: UIBarButtonItem
                    if let current = self.applyButtonItem {
                        applyButtonItem = current
                    } else {
                        applyButtonItem = UIBarButtonItem(title: environment.strings.Common_Save, style: .done, target: self, action: #selector(self.savePressed))
                    }
                    if controller.navigationItem.rightBarButtonItem !== applyButtonItem {
                        controller.navigationItem.setRightBarButton(applyButtonItem, animated: true)
                    }
                }
            }
            
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
