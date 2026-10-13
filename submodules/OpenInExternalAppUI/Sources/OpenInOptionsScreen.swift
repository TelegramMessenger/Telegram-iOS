import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import MapKit
import TelegramPresentationData
import AccountContext
import AppBundle
import ViewControllerComponent
import SheetComponent
import ButtonComponent
import GlassBarButtonComponent
import BundleIconComponent
import MultilineTextComponent

public struct OpenInControllerAction {
    public let title: String
    public let action: () -> Void
    
    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
}

public final class OpenInOptionsScreen: ViewControllerComponentContainer {
    public init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
        forceTheme: PresentationTheme? = nil,
        item: OpenInItem,
        additionalAction: OpenInControllerAction? = nil,
        openUrl: @escaping (String) -> Void
    ) {
        let invokeAction: (OpenInAction) -> Void = { action in
            switch action {
            case let .openUrl(url):
                openUrl(url)
            case let .openLocation(latitude, longitude, directions):
                let placemark = MKPlacemark(coordinate: CLLocationCoordinate2DMake(latitude, longitude), addressDictionary: [:])
                let mapItem = MKMapItem(placemark: placemark)
                
                if let directions = directions {
                    let options = [MKLaunchOptionsDirectionsModeKey: directions.launchOptions]
                    MKMapItem.openMaps(with: [MKMapItem.forCurrentLocation(), mapItem], launchOptions: options)
                } else {
                    mapItem.openInMaps(launchOptions: nil)
                }
            default:
                break
            }
        }
        
        let effectiveUpdatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
        if let forceTheme {
            let initial = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
            let signal = updatedPresentationData?.signal ?? context.sharedContext.presentationData
            effectiveUpdatedPresentationData = (
                initial: initial.withUpdated(theme: forceTheme),
                signal: signal |> map { presentationData in
                    presentationData.withUpdated(theme: forceTheme)
                }
            )
        } else {
            effectiveUpdatedPresentationData = updatedPresentationData
        }
        
        super.init(
            context: context,
            component: OpenInOptionsScreenComponent(
                context: context,
                options: availableOpenInOptions(context: context, item: item),
                additionalAction: additionalAction,
                invokeAction: invokeAction
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            updatedPresentationData: effectiveUpdatedPresentationData
        )
        
        self.blocksBackgroundWhenInOverlay = true
        self.navigationPresentation = .flatModal
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}

private final class OpenInOptionsScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let options: [OpenInOption]
    let additionalAction: OpenInControllerAction?
    let invokeAction: (OpenInAction) -> Void
    
    init(
        context: AccountContext,
        options: [OpenInOption],
        additionalAction: OpenInControllerAction?,
        invokeAction: @escaping (OpenInAction) -> Void
    ) {
        self.context = context
        self.options = options
        self.additionalAction = additionalAction
        self.invokeAction = invokeAction
    }
    
    static func ==(lhs: OpenInOptionsScreenComponent, rhs: OpenInOptionsScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.options.map(\.identifier) != rhs.options.map(\.identifier) {
            return false
        }
        if lhs.additionalAction?.title != rhs.additionalAction?.title {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let sheet = ComponentView<(ViewControllerComponentContainer.Environment, SheetComponentEnvironment)>()
        private let sheetAnimateOut = ActionSlot<Action<Void>>()
        
        private var environment: EnvironmentType?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func dismiss(animated: Bool) {
            guard let controller = self.environment?.controller() else {
                return
            }
            
            if animated {
                self.sheetAnimateOut.invoke(Action { _ in
                    controller.dismiss(completion: nil)
                })
            } else {
                controller.dismiss(animated: false, completion: nil)
            }
        }
        
        func update(component: OpenInOptionsScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environment
            
            let sheetEnvironment = SheetComponentEnvironment(
                metrics: environment.metrics,
                deviceMetrics: environment.deviceMetrics,
                isDisplaying: environment.isVisible,
                isCentered: environment.metrics.widthClass == .regular,
                hasInputHeight: !environment.inputHeight.isZero,
                regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                dismiss: { [weak self] animated in
                    self?.dismiss(animated: animated)
                }
            )
            
            let _ = self.sheet.update(
                transition: transition,
                component: AnyComponent(SheetComponent(
                    content: AnyComponent(OpenInOptionsSheetContentComponent(
                        context: component.context,
                        options: component.options,
                        additionalAction: component.additionalAction,
                        invokeAction: component.invokeAction,
                        dismiss: { [weak self] in
                            self?.dismiss(animated: true)
                        }
                    )),
                    style: .glass,
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    animateOut: self.sheetAnimateOut
                )),
                environment: {
                    environment
                    sheetEnvironment
                },
                containerSize: availableSize
            )
            
            if let sheetView = self.sheet.view {
                if sheetView.superview == nil {
                    self.addSubview(sheetView)
                }
                transition.setFrame(view: sheetView, frame: CGRect(origin: CGPoint(), size: availableSize))
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

private final class OpenInOptionsSheetContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let options: [OpenInOption]
    let additionalAction: OpenInControllerAction?
    let invokeAction: (OpenInAction) -> Void
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        options: [OpenInOption],
        additionalAction: OpenInControllerAction?,
        invokeAction: @escaping (OpenInAction) -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.options = options
        self.additionalAction = additionalAction
        self.invokeAction = invokeAction
        self.dismiss = dismiss
    }
    
    static func ==(lhs: OpenInOptionsSheetContentComponent, rhs: OpenInOptionsSheetContentComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.options.map(\.identifier) != rhs.options.map(\.identifier) {
            return false
        }
        if lhs.additionalAction?.title != rhs.additionalAction?.title {
            return false
        }
        return true
    }
    
    private final class OptionsScrollView: UIScrollView {
        // The content of this scroll view is made of OpenInAppView, which is a UIControl.
        // UIScrollView's default -touchesShouldCancelInContentView: returns NO for a UIControl, and
        // because delaysContentTouches is NO the control starts tracking the touch immediately — so
        // without this override a horizontal drag that begins on an app icon is never converted
        // into a scroll, and only the gaps between icons can be dragged.
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    final class View: UIView {
        private let closeButton = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let scrollView: OptionsScrollView
        private var optionViews: [String: OpenInAppView] = [:]
        private var shareButton: ComponentView<Empty>?
        
        override init(frame: CGRect) {
            self.scrollView = OptionsScrollView()
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.clipsToBounds = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delaysContentTouches = false
            self.scrollView.alwaysBounceHorizontal = true
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            
            super.init(frame: frame)
            
            self.addSubview(self.scrollView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: OpenInOptionsSheetContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let theme = environment.theme
            let strings = environment.strings
            
            let closeButtonSize = self.closeButton.update(
                transition: transition,
                component: AnyComponent(GlassBarButtonComponent(
                    size: CGSize(width: 44.0, height: 44.0),
                    backgroundColor: nil,
                    isDark: theme.overallDarkAppearance,
                    state: .glass,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Close",
                            tintColor: theme.chat.inputPanel.panelControlColor
                        )
                    )),
                    action: { _ in
                        component.dismiss()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 44.0, height: 44.0)
            )
            if let closeButtonView = self.closeButton.view {
                if closeButtonView.superview == nil {
                    self.addSubview(closeButtonView)
                }
                transition.setFrame(view: closeButtonView, frame: CGRect(origin: CGPoint(x: 16.0, y: 16.0), size: closeButtonSize))
            }
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: strings.Map_OpenIn,
                        font: Font.semibold(17.0),
                        textColor: theme.actionSheet.primaryTextColor,
                        paragraphAlignment: .center
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: max(1.0, availableSize.width - 32.0 - 60.0), height: CGFloat.greatestFiniteMagnitude)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: CGRect(
                    origin: CGPoint(
                        x: floorToScreenPixels((availableSize.width - titleSize.width) / 2.0),
                        y: floorToScreenPixels(38.0 - titleSize.height / 2.0)
                    ),
                    size: titleSize
                ))
            }
            
            let optionInset: CGFloat = 2.0
            var optionSpacing: CGFloat = 8.0
            if component.options.count == 3 {
                optionSpacing = 32.0
            } else if component.options.count == 2 {
                optionSpacing = 64.0
            }
            
            let optionSize = CGSize(width: 80.0, height: 112.0)
            let scrollFrame = CGRect(origin: CGPoint(x: 0.0, y: 82.0), size: CGSize(width: availableSize.width, height: optionSize.height))
            transition.setFrame(view: self.scrollView, frame: scrollFrame)
            
            var validIds = Set<String>()
            for (index, option) in component.options.enumerated() {
                validIds.insert(option.identifier)
                
                let optionView: OpenInAppView
                if let current = self.optionViews[option.identifier] {
                    optionView = current
                } else {
                    optionView = OpenInAppView()
                    self.optionViews[option.identifier] = optionView
                    self.scrollView.addSubview(optionView)
                }
                
                optionView.update(context: component.context, theme: theme, option: option, action: {
                    component.invokeAction(option.action())
                    component.dismiss()
                })
                
                let optionOriginX: CGFloat
                if component.options.count < 5 {
                    optionOriginX = floorToScreenPixels(max(0.0, (availableSize.width - optionSize.width * CGFloat(component.options.count) - optionSpacing * CGFloat(component.options.count - 1)) / 2.0)) + CGFloat(index) * (optionSize.width + optionSpacing)
                } else {
                    optionOriginX = optionInset + CGFloat(index) * (optionSize.width + optionSpacing)
                }
                
                transition.setFrame(view: optionView, frame: CGRect(
                    origin: CGPoint(x: optionOriginX, y: 0.0),
                    size: optionSize
                ))
            }
            
            for id in Array(self.optionViews.keys) {
                if !validIds.contains(id) {
                    let optionView = self.optionViews.removeValue(forKey: id)
                    optionView?.removeFromSuperview()
                }
            }
            
            let optionsContentWidth: CGFloat
            if component.options.isEmpty {
                optionsContentWidth = availableSize.width
            } else {
                optionsContentWidth = optionInset * 2.0 + CGFloat(component.options.count) * (optionSize.width + optionSpacing) - optionSpacing
            }
            self.scrollView.contentSize = CGSize(width: max(availableSize.width, optionsContentWidth), height: optionSize.height)
            
            var contentHeight = scrollFrame.maxY + 22.0
            if let additionalAction = component.additionalAction {
                let shareButton: ComponentView<Empty>
                if let current = self.shareButton {
                    shareButton = current
                } else {
                    shareButton = ComponentView<Empty>()
                    self.shareButton = shareButton
                }
                
                let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: environment.safeInsets.bottom, innerDiameter: 52.0, sideInset: 30.0)
                let buttonSize = shareButton.update(
                    transition: transition,
                    component: AnyComponent(ButtonComponent(
                        background: ButtonComponent.Background(
                            style: .glass,
                            color: theme.list.itemCheckColors.fillColor,
                            foreground: theme.list.itemCheckColors.foregroundColor,
                            pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                        ),
                        content: AnyComponentWithIdentity(
                            id: AnyHashable(additionalAction.title),
                            component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: additionalAction.title,
                                    font: Font.semibold(17.0),
                                    textColor: theme.list.itemCheckColors.foregroundColor,
                                    paragraphAlignment: .center
                                )),
                                horizontalAlignment: .center,
                                maximumNumberOfLines: 1
                            ))
                        ),
                        action: {
                            additionalAction.action()
                            component.dismiss()
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - buttonInsets.left - buttonInsets.right, height: 52.0)
                )
                
                if let shareButtonView = shareButton.view {
                    if shareButtonView.superview == nil {
                        self.addSubview(shareButtonView)
                    }
                    transition.setFrame(view: shareButtonView, frame: CGRect(
                        origin: CGPoint(x: floorToScreenPixels((availableSize.width - buttonSize.width) / 2.0), y: contentHeight),
                        size: buttonSize
                    ))
                }
                contentHeight += buttonSize.height
                contentHeight += buttonInsets.bottom
            } else {
                if let shareButton = self.shareButton {
                    self.shareButton = nil
                    shareButton.view?.removeFromSuperview()
                }
                contentHeight += max(20.0, environment.safeInsets.bottom + 12.0)
            }
            
            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class OpenInAppView: UIControl {
    private let iconView: TransformImageView
    private let titleLabel: UILabel
    
    private var currentIdentifier: String?
    private var action: (() -> Void)?
    
    override init(frame: CGRect) {
        self.iconView = TransformImageView(frame: CGRect(origin: CGPoint(), size: CGSize(width: 64.0, height: 64.0)))
        self.iconView.isUserInteractionEnabled = false
        
        self.titleLabel = UILabel()
        self.titleLabel.isUserInteractionEnabled = false
        
        super.init(frame: frame)
        
        self.titleLabel.textAlignment = .center
        self.titleLabel.numberOfLines = 1
        self.titleLabel.adjustsFontSizeToFitWidth = true
        self.titleLabel.minimumScaleFactor = 0.75
        
        self.isAccessibilityElement = true
        
        self.addSubview(self.iconView)
        self.addSubview(self.titleLabel)
        
        self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(context: AccountContext, theme: PresentationTheme, option: OpenInOption, action: @escaping () -> Void) {
        self.action = action
        self.accessibilityLabel = option.title
        self.titleLabel.attributedText = NSAttributedString(string: option.title, font: Font.medium(12.0), textColor: theme.actionSheet.primaryTextColor, paragraphAlignment: .center)
        
        let iconSize = CGSize(width: 64.0, height: 64.0)
        let makeLayout = self.iconView.asyncLayout()
        let applyLayout = makeLayout(TransformImageArguments(corners: ImageCorners(radius: 16.0), imageSize: iconSize, boundingSize: iconSize, intrinsicInsets: UIEdgeInsets()))
        applyLayout()
        
        if self.currentIdentifier != option.identifier {
            self.currentIdentifier = option.identifier
            
            switch option.application {
            case .safari:
                if let image = UIImage(bundleImageName: "Open In/Safari") {
                    self.iconView.setSignal(openInAppIcon(engine: context.engine, appIcon: .image(image: image)))
                }
            case .maps:
                if let image = UIImage(bundleImageName: "Open In/Maps") {
                    self.iconView.setSignal(openInAppIcon(engine: context.engine, appIcon: .image(image: image)))
                }
            case let .other(_, identifier, _, store):
                self.iconView.setSignal(openInAppIcon(engine: context.engine, appIcon: .resource(resource: OpenInAppIconResource(appStoreId: identifier, store: store))))
            }
        }
    }
    
    @objc private func pressed() {
        self.action?()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.iconView.frame = CGRect(origin: CGPoint(x: 8.0, y: 12.0), size: CGSize(width: 64.0, height: 64.0))
        self.titleLabel.frame = CGRect(origin: CGPoint(x: 0.0, y: 80.0), size: CGSize(width: self.bounds.width, height: 16.0))
    }
}
