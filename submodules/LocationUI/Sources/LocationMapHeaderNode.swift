import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AppBundle
import CoreLocation
import ComponentFlow
import GlassBackgroundComponent
import PlainButtonComponent
import BundleIconComponent
import MultilineTextComponent
import LottieComponent
import LottieComponentResourceContent

private let panelInset: CGFloat = 4.0
private let panelButtonSize = CGSize(width: 46.0, height: 46.0)
private let glassPanelButtonSize = CGSize(width: 40.0, height: 40.0)

private func generateBackgroundImage(theme: PresentationTheme) -> UIImage? {
    let cornerRadius: CGFloat = 9.0
    return generateImage(CGSize(width: (cornerRadius + panelInset) * 2.0, height: (cornerRadius + panelInset) * 2.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setShadow(offset: CGSize(), blur: 10.0, color: UIColor(rgb: 0x000000, alpha: 0.2).cgColor)
        context.setFillColor(theme.rootController.navigationBar.opaqueBackgroundColor.cgColor)
        let path = UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: panelInset, y: panelInset), size: CGSize(width: cornerRadius * 2.0, height: cornerRadius * 2.0)), cornerRadius: cornerRadius)
        context.addPath(path.cgPath)
        context.fillPath()
    })?.stretchableImage(withLeftCapWidth: Int(cornerRadius + panelInset), topCapHeight: Int(cornerRadius + panelInset))
}

private func generateShadowImage(theme: PresentationTheme, highlighted: Bool) -> UIImage? {
    return generateImage(CGSize(width: 26.0, height: 14.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setShadow(offset: CGSize(), blur: 10.0, color: UIColor(rgb: 0x000000, alpha: 0.2).cgColor)
        context.setFillColor(highlighted ? theme.list.itemHighlightedBackgroundColor.cgColor : theme.list.plainBackgroundColor.cgColor)
        let path = UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: 0.0, y: 4.0), size: CGSize(width: 26.0, height: 20.0)), cornerRadius: 9.0)
        context.addPath(path.cgPath)
        context.fillPath()
    })?.stretchableImage(withLeftCapWidth: 13, topCapHeight: 0)
}

public final class LocationMapHeaderNode: ASDisplayNode {
    private var presentationData: PresentationData
    private let glass: Bool
    private let toggleMapModeSelection: () -> Void
    private let updateMapMode: (LocationMapMode) -> Void
    private let goToUserLocation: () -> Void
    private let showPlacesInThisArea: () -> Void
    private let setupProximityNotification: (Bool) -> Void
    private let weatherPressed: () -> Void
    
    private var displayingPlacesButton = false
    private var proximityNotification: Bool?
    
    public let mapNode: LocationMapNode
    public var trackingMode: LocationTrackingMode = .none
        
    private let options: ComponentView<Empty>?
    
    private let optionsBackgroundView: GlassContextExtractableContainer?
    private let optionsBackgroundNode: ASImageNode
    private let optionsSeparatorNode: ASDisplayNode
    private let optionsSecondSeparatorNode: ASDisplayNode
    private let infoButtonNode: HighlightableButtonNode
    private let locationButtonNode: HighlightableButtonNode
    private let notificationButtonNode: HighlightableButtonNode
    private let placesBackgroundView: GlassBackgroundView?
    private let placesBackgroundNode: ASImageNode
    private let placesButtonNode: HighlightTrackingButtonNode
    
    private let weatherBackgroundView: GlassBackgroundView?
    private let weatherIcon = ComponentView<Empty>()
    private let weatherEmojiLabel = ComponentView<Empty>()
    private let weatherTemperatureLabel = ComponentView<Empty>()
    private let weatherButton: HighlightTrackingButton
    private var weatherEmoji: String?
    private var weatherTemperature: String?
    private var weatherEmojiFile: TelegramMediaFile?
    private weak var weatherContext: AccountContext?
    private let weatherEmojiLoadDisposable = MetaDisposable()

    private var validLayout: (ContainerViewLayout, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGSize)?

    public init(
        presentationData: PresentationData,
        glass: Bool,
        isPreview: Bool = false,
        toggleMapModeSelection: @escaping () -> Void,
        updateMapMode: @escaping (LocationMapMode) -> Void,
        goToUserLocation: @escaping () -> Void,
        setupProximityNotification: @escaping (Bool) -> Void = { _ in },
        showPlacesInThisArea: @escaping () -> Void = {},
        weatherPressed: @escaping () -> Void = {}
    ) {
        self.presentationData = presentationData
        self.glass = glass
        self.toggleMapModeSelection = toggleMapModeSelection
        self.updateMapMode = updateMapMode
        self.goToUserLocation = goToUserLocation
        self.setupProximityNotification = setupProximityNotification
        self.showPlacesInThisArea = showPlacesInThisArea
        self.weatherPressed = weatherPressed
        
        self.mapNode = LocationMapNode()
        
        if glass {
            self.options = ComponentView()
        } else {
            self.options = nil
        }
        
        self.optionsBackgroundNode = ASImageNode()
        self.optionsBackgroundNode.contentMode = .scaleToFill
        self.optionsBackgroundNode.displaysAsynchronously = false
        self.optionsBackgroundNode.displayWithoutProcessing = true
        self.optionsBackgroundNode.image = generateBackgroundImage(theme: presentationData.theme)
        self.optionsBackgroundNode.isUserInteractionEnabled = true
                
        self.optionsSeparatorNode = ASDisplayNode()
        self.optionsSeparatorNode.backgroundColor = presentationData.theme.rootController.navigationBar.separatorColor
        
        self.optionsSecondSeparatorNode = ASDisplayNode()
        self.optionsSecondSeparatorNode.backgroundColor = presentationData.theme.rootController.navigationBar.separatorColor
        
        let buttonColor = self.glass ? presentationData.theme.rootController.navigationBar.primaryTextColor.withAlphaComponent(0.62) : presentationData.theme.rootController.navigationBar.buttonColor
        
        self.infoButtonNode = HighlightableButtonNode()
        self.infoButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: self.glass ? "Location/OptionMap" : "Location/InfoIcon"), color: buttonColor), for: .normal)
        self.infoButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Location/InfoActiveIcon"), color: buttonColor), for: .selected)
        self.infoButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Location/InfoActiveIcon"), color: buttonColor), for: [.selected, .highlighted])
        
        self.locationButtonNode = HighlightableButtonNode()
        self.locationButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Location/TrackIcon"), color: buttonColor), for: .normal)
        
        self.notificationButtonNode = HighlightableButtonNode()
        self.notificationButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Location/NotificationIcon"), color: buttonColor), for: .normal)
        self.notificationButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Title Panels/MuteIcon"), color: buttonColor), for: .selected)
        self.notificationButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Title Panels/MuteIcon"), color: buttonColor), for: [.selected, .highlighted])
        
        self.placesBackgroundNode = ASImageNode()
        self.placesBackgroundNode.contentMode = .scaleToFill
        self.placesBackgroundNode.displaysAsynchronously = false
        self.placesBackgroundNode.displayWithoutProcessing = true
        self.placesBackgroundNode.image = generateBackgroundImage(theme: presentationData.theme)
        self.placesBackgroundNode.isUserInteractionEnabled = true

        self.placesButtonNode = HighlightTrackingButtonNode()
        self.placesButtonNode.setTitle(presentationData.strings.Map_PlacesInThisArea, with: Font.medium(17.0), with: self.glass ? presentationData.theme.rootController.navigationBar.primaryTextColor : buttonColor, for: .normal)

        self.weatherButton = HighlightTrackingButton()

        if glass {
            self.optionsBackgroundView = GlassContextExtractableContainer()
            self.optionsBackgroundNode.image = nil
            
            self.placesBackgroundView = GlassBackgroundView()
            self.placesBackgroundNode.image = nil

            self.weatherBackgroundView = GlassBackgroundView()
        } else {
            self.optionsBackgroundView = nil
            self.placesBackgroundView = nil
            self.weatherBackgroundView = nil
        }

        super.init()

        self.mapNode.visibleRegionDidChange = { [weak self] in
            guard let self, self.glass, self.mapNode.mapMode == .satellite else {
                return
            }
            self.requestLayout(transition: .immediate)
        }

        self.clipsToBounds = true
        
        self.addSubnode(self.mapNode)
                
        if !isPreview {
            if glass {
                if let placesBackgroundView = self.placesBackgroundView {
                    self.placesBackgroundNode.view.addSubview(placesBackgroundView)
                }
            } else {
                if let optionsBackgroundView = self.optionsBackgroundView {
                    self.optionsSeparatorNode.isHidden = true
                    self.view.addSubview(optionsBackgroundView)
                }
                self.addSubnode(self.optionsBackgroundNode)
                self.optionsBackgroundView?.contentView.addSubview(self.optionsSeparatorNode.view)
                self.optionsBackgroundView?.contentView.addSubview(self.optionsSecondSeparatorNode.view)
                self.optionsBackgroundView?.contentView.addSubview(self.infoButtonNode.view)
                self.optionsBackgroundView?.contentView.addSubview(self.locationButtonNode.view)
                self.optionsBackgroundView?.contentView.addSubview(self.notificationButtonNode.view)
            }
        }

        self.addSubnode(self.placesBackgroundNode)
        self.placesBackgroundView?.contentView.addSubview(self.placesButtonNode.view)
        if let weatherBackgroundView = self.weatherBackgroundView {
            weatherBackgroundView.isHidden = true
            self.view.addSubview(weatherBackgroundView)
        }

        self.infoButtonNode.addTarget(self, action: #selector(self.infoPressed), forControlEvents: .touchUpInside)
        self.locationButtonNode.addTarget(self, action: #selector(self.locationPressed), forControlEvents: .touchUpInside)
        self.notificationButtonNode.addTarget(self, action: #selector(self.notificationPressed), forControlEvents: .touchUpInside)
        self.placesButtonNode.addTarget(self, action: #selector(self.placesPressed), forControlEvents: .touchUpInside)

        self.weatherButton.addTarget(self, action: #selector(self.weatherButtonPressed), for: .touchUpInside)
    }

    deinit {
        self.weatherEmojiLoadDisposable.dispose()
    }

    @objc private func weatherButtonPressed() {
        self.weatherPressed()
    }
    
    public func updateState(mapMode: LocationMapMode, trackingMode: LocationTrackingMode, displayingMapModeOptions: Bool, displayingPlacesButton: Bool, proximityNotification: Bool?, animated: Bool) {
        let mapModeUpdated = self.mapNode.mapMode != mapMode
        let displayingMapModesUpdated = self.infoButtonNode.isSelected != displayingMapModeOptions
        self.mapNode.mapMode = mapMode
        self.trackingMode = trackingMode
        self.infoButtonNode.isSelected = displayingMapModeOptions
        self.notificationButtonNode.isSelected = proximityNotification ?? false
        
        let buttonColor = self.glass ? presentationData.theme.rootController.navigationBar.primaryTextColor.withAlphaComponent(0.62) : presentationData.theme.rootController.navigationBar.buttonColor
        
        self.locationButtonNode.setImage(generateTintedImage(image: self.iconForTracking(), color: buttonColor), for: .normal)
        
        let updateLayout = self.displayingPlacesButton != displayingPlacesButton || self.proximityNotification != proximityNotification || mapModeUpdated || displayingMapModesUpdated
        self.displayingPlacesButton = displayingPlacesButton
        self.proximityNotification = proximityNotification
        
        if updateLayout, let (layout, navigationBarHeight, topPadding, controlsTopPadding, controlsBottomPadding, offset, size) = self.validLayout {
            let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.3, curve: .spring) : .immediate
            self.updateLayout(layout: layout, navigationBarHeight: navigationBarHeight, topPadding: topPadding, controlsTopPadding: controlsTopPadding, controlsBottomPadding: controlsBottomPadding, offset: offset, size: size, transition: transition)
        }
    }
    
    public func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        let buttonColor = self.glass ? presentationData.theme.rootController.navigationBar.primaryTextColor.withAlphaComponent(0.62) : presentationData.theme.rootController.navigationBar.buttonColor
        
        self.mapNode.isDark = presentationData.theme.overallDarkAppearance
        self.optionsBackgroundNode.image = generateBackgroundImage(theme: presentationData.theme)
        self.optionsSeparatorNode.backgroundColor = presentationData.theme.rootController.navigationBar.separatorColor
        self.optionsSecondSeparatorNode.backgroundColor = presentationData.theme.rootController.navigationBar.separatorColor
        self.infoButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: self.glass ? "Location/OptionMap" : "Location/InfoIcon"), color: buttonColor), for: .normal)
        self.infoButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Location/InfoActiveIcon"), color: buttonColor), for: .selected)
        self.infoButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Location/InfoActiveIcon"), color: buttonColor), for: [.selected, .highlighted])
        self.locationButtonNode.setImage(generateTintedImage(image: self.iconForTracking(), color: buttonColor), for: .normal)
        self.notificationButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Location/NotificationIcon"), color: buttonColor), for: .normal)
        self.notificationButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Title Panels/MuteIcon"), color: buttonColor), for: .selected)
        self.notificationButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Title Panels/MuteIcon"), color: buttonColor), for: [.selected, .highlighted])
        if !self.glass {
            self.placesBackgroundNode.image = generateBackgroundImage(theme: presentationData.theme)
        }
    }
    
    func updateWeatherData(context: AccountContext, emoji: String, temperature: String, animated: Bool) {
        let emojiFile = context.animatedEmojiStickersValue[emoji]?.first?.file._parse()
        if self.weatherEmoji == emoji && self.weatherTemperature == temperature && self.weatherEmojiFile?.fileId == emojiFile?.fileId {
            return
        }

        if self.weatherEmojiFile?.fileId != emojiFile?.fileId {
            if let emojiFile {
                self.weatherEmojiLoadDisposable.set(context.engine.resources.fetch(reference: .standalone(resource: emojiFile.resource), userLocation: .other, userContentType: .sticker).start())
            } else {
                self.weatherEmojiLoadDisposable.set(nil)
            }
        }

        self.weatherContext = context
        self.weatherEmoji = emoji
        self.weatherTemperature = temperature
        self.weatherEmojiFile = emojiFile
        self.requestLayout(transition: animated ? .animated(duration: 0.2, curve: .easeInOut) : .immediate)
    }

    func clearWeatherData(animated: Bool) {
        if self.weatherEmoji == nil && self.weatherTemperature == nil {
            return
        }
        self.weatherEmoji = nil
        self.weatherTemperature = nil
        self.weatherEmojiFile = nil
        self.weatherContext = nil
        self.weatherEmojiLoadDisposable.set(nil)
        if let weatherIconView = self.weatherIcon.view as? LottieComponent.View {
            weatherIconView.externalShouldPlay = false
        }
        self.weatherIcon.view?.removeFromSuperview()
        self.requestLayout(transition: animated ? .animated(duration: 0.2, curve: .easeInOut) : .immediate)
    }

    private func iconForTracking() -> UIImage? {
        switch self.trackingMode {
            case .none:
                return UIImage(bundleImageName: self.glass ? "Location/OptionLocate" : "Location/TrackIcon")
            case .follow:
                return UIImage(bundleImageName: "Location/TrackActiveIcon")
            case .followWithHeading:
                return UIImage(bundleImageName: "Location/TrackHeadingIcon")
        }
    }
    
    func requestLayout(transition: ContainedViewLayoutTransition) {
        guard let (layout, navigationBarHeight, topPadding, controlsTopPadding, controlsBottomPadding, offset, size) = self.validLayout else {
            return
        }
        self.updateLayout(layout: layout, navigationBarHeight: navigationBarHeight, topPadding: topPadding, controlsTopPadding: controlsTopPadding, controlsBottomPadding: controlsBottomPadding, offset: offset, size: size, transition: transition)
    }

    public func updateLayout(
        layout: ContainerViewLayout,
        navigationBarHeight: CGFloat,
        topPadding: CGFloat,
        controlsTopPadding: CGFloat,
        controlsBottomPadding: CGFloat,
        offset: CGFloat,
        size: CGSize,
        transition: ContainedViewLayoutTransition
    ) {
        self.validLayout = (layout, navigationBarHeight, topPadding, controlsTopPadding, controlsBottomPadding, offset, size)
        
        let mapHeight: CGFloat = floor(layout.size.height * 1.3) + layout.intrinsicInsets.top * 2.0
        let mapFrame = CGRect(x: 0.0, y: floorToScreenPixels((size.height - mapHeight + navigationBarHeight) / 2.0) + offset + floor(layout.intrinsicInsets.top * 0.5), width: size.width, height: mapHeight)
        transition.updateFrame(node: self.mapNode, frame: mapFrame)
        self.mapNode.updateLayout(size: mapFrame.size, topPadding: topPadding, inset: mapFrame.origin.y * -1.0 + navigationBarHeight, transition: transition)
        
        let inset: CGFloat = 6.0
        
        let placesButtonSize = CGSize(width: 180.0 + panelInset * 2.0, height: 45.0 + panelInset * 2.0)
        let placesButtonFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - placesButtonSize.width) / 2.0), y: navigationBarHeight + topPadding - 6.0), size: placesButtonSize).insetBy(dx: 5.0, dy: 6.0)
        transition.updateFrame(node: self.placesBackgroundNode, frame: placesButtonFrame)
        
        if let placesBackgroundView = self.placesBackgroundView {
            let backgroundViewFrame = CGRect(origin: .zero, size: placesButtonFrame.size)
            transition.updateFrame(view: placesBackgroundView, frame: backgroundViewFrame)
            placesBackgroundView.update(size: backgroundViewFrame.size, cornerRadius: backgroundViewFrame.height * 0.5, isDark: self.presentationData.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: .immediate)
        }
        
        transition.updateFrame(node: self.placesButtonNode, frame: CGRect(origin: CGPoint(), size: placesButtonFrame.size))
        transition.updateAlpha(node: self.placesBackgroundNode, alpha: self.displayingPlacesButton ? 1.0 : 0.0)
        transition.updateAlpha(node: self.placesButtonNode, alpha: self.displayingPlacesButton ? 1.0 : 0.0)
        
        if let weatherBackgroundView = self.weatherBackgroundView {
            let panelHeight: CGFloat = 36.0
            let horizontalInset: CGFloat = 10.0
            let labelSpacing: CGFloat = 5.0
            let iconSize = CGSize(width: floor(panelHeight * 0.71), height: floor(panelHeight * 0.71))
            let componentTransition = ComponentTransition(transition)
            let temperatureSize = self.weatherTemperatureLabel.update(
                transition: componentTransition,
                component: AnyComponent(Text(
                    text: self.weatherTemperature ?? "",
                    font: Font.semibold(15.0),
                    color: self.presentationData.theme.rootController.navigationBar.primaryTextColor
                )),
                environment: {},
                containerSize: CGSize(width: 72.0, height: panelHeight)
            )
            let emojiSize = self.weatherEmojiLabel.update(
                transition: componentTransition,
                component: AnyComponent(Text(
                    text: self.weatherEmoji ?? "",
                    font: Font.regular(18.0),
                    color: self.presentationData.theme.rootController.navigationBar.primaryTextColor
                )),
                environment: {},
                containerSize: iconSize
            )
            let panelWidth = max(62.0, ceil(horizontalInset * 2.0 + iconSize.width + labelSpacing + temperatureSize.width))
            let panelFrame = CGRect(
                x: layout.safeInsets.left + 16.0,
                y: navigationBarHeight + topPadding + 14.0,
                width: panelWidth,
                height: panelHeight
            )
            transition.updateFrame(view: weatherBackgroundView, frame: panelFrame)

            let weatherAlpha: CGFloat = self.weatherEmoji != nil && self.weatherTemperature != nil && size.height > 160.0 + navigationBarHeight && !self.forceIsHidden ? 1.0 : 0.0
            if weatherBackgroundView.isHidden && weatherAlpha > 0.0 {
                weatherBackgroundView.isHidden = false
            }
            weatherBackgroundView.update(size: panelFrame.size, cornerRadius: panelFrame.height * 0.5, isDark: self.presentationData.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, isVisible: weatherAlpha > 0.0, transition: ComponentTransition(transition))

            let iconFrame = CGRect(
                x: horizontalInset,
                y: floorToScreenPixels((panelHeight - iconSize.height) / 2.0),
                width: iconSize.width,
                height: iconSize.height
            )
            let temperatureFrame = CGRect(
                x: iconFrame.maxX + labelSpacing,
                y: floorToScreenPixels((panelHeight - temperatureSize.height) / 2.0),
                width: temperatureSize.width,
                height: temperatureSize.height
            )
            let emojiFrame = CGRect(
                x: iconFrame.minX + floorToScreenPixels((iconFrame.width - emojiSize.width) / 2.0),
                y: iconFrame.minY + floorToScreenPixels((iconFrame.height - emojiSize.height) / 2.0),
                width: emojiSize.width,
                height: emojiSize.height
            )
            if let weatherEmojiView = self.weatherEmojiLabel.view {
                if weatherEmojiView.superview == nil {
                    weatherBackgroundView.contentView.addSubview(weatherEmojiView)
                }
                transition.updateFrame(view: weatherEmojiView, frame: emojiFrame)
            }
            if let weatherTemperatureView = self.weatherTemperatureLabel.view {
                if weatherTemperatureView.superview == nil {
                    weatherBackgroundView.contentView.addSubview(weatherTemperatureView)
                }
                transition.updateFrame(view: weatherTemperatureView, frame: temperatureFrame)
            }

            if let weatherContext = self.weatherContext, let weatherEmojiFile = self.weatherEmojiFile {
                var weatherIconTransition = transition
                let _ = self.weatherIcon.update(
                    transition: ComponentTransition(transition),
                    component: AnyComponent(
                        LottieComponent(
                            content: LottieComponent.ResourceContent(context: weatherContext, file: weatherEmojiFile, attemptSynchronously: false, providesPlaceholder: true),
                            placeholderColor: self.presentationData.theme.rootController.navigationBar.primaryTextColor.withAlphaComponent(0.1),
                            renderingScale: 2.0,
                            loop: true
                        )
                    ),
                    environment: {},
                    containerSize: iconSize
                )
                if let weatherIconView = self.weatherIcon.view {
                    if weatherIconView.superview == nil {
                        weatherIconTransition = .immediate
                        weatherBackgroundView.contentView.addSubview(weatherIconView)
                    }
                    weatherIconTransition.updateFrame(view: weatherIconView, frame: iconFrame)
                    ComponentTransition(transition).setAlpha(view: weatherIconView, alpha: 1.0)
                    if let weatherIconView = weatherIconView as? LottieComponent.View {
                        weatherIconView.externalShouldPlay = weatherAlpha > 0.0
                    }
                }
                if let weatherEmojiView = self.weatherEmojiLabel.view {
                    componentTransition.setAlpha(view: weatherEmojiView, alpha: 0.0)
                }
            } else {
                if let weatherIconView = self.weatherIcon.view {
                    componentTransition.setAlpha(view: weatherIconView, alpha: 0.0)
                    if let weatherIconView = weatherIconView as? LottieComponent.View {
                        weatherIconView.externalShouldPlay = false
                    }
                }
                if let weatherEmojiView = self.weatherEmojiLabel.view {
                    componentTransition.setAlpha(view: weatherEmojiView, alpha: 1.0)
                }
            }
            componentTransition.setAlpha(view: weatherBackgroundView, alpha: weatherAlpha)

            if self.weatherButton.superview == nil {
                weatherBackgroundView.contentView.addSubview(self.weatherButton)
            }
            self.weatherButton.frame = CGRect(origin: .zero, size: panelFrame.size)
        }

        if let options = self.options {
            let optionsSize = options.update(
                transition: ComponentTransition(transition),
                component: AnyComponent(
                    LocationOptionsComponent(
                        theme: self.presentationData.theme,
                        strings: self.presentationData.strings,
                        mapMode: self.mapNode.mapMode,
                        currentCoordinate: self.mapNode.mapCenterCoordinate,
                        trackingMode: self.mapNode.trackingMode,
                        showMapModes: self.infoButtonNode.isSelected,
                        proximityNotification: self.proximityNotification,
                        updateMapMode: { [weak self] mode in
                            guard let self else {
                                return
                            }
                            self.updateMapMode(mode)
                            self.requestLayout(transition: .immediate)
                        },
                        goToUserLocation: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.goToUserLocation()
                            self.requestLayout(transition: .immediate)
                        },
                        requestedMapModes: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.toggleMapModeSelection()
                        },
                        setupProximityNotification: { [weak self] reset in
                            guard let self else {
                                return
                            }
                            self.setupProximityNotification(reset)
                        }
                    )
                ),
                environment: {},
                containerSize: layout.size
            )
            if let optionsView = options.view {
                if optionsView.superview == nil {
                    self.view.addSubview(optionsView)
                }
                transition.updateFrame(view: optionsView, frame: CGRect(origin: CGPoint(x: size.width - optionsSize.width - inset - 10.0, y: size.height - optionsSize.height - inset - controlsBottomPadding - 10.0), size: optionsSize))
                ComponentTransition(animation: .curve(duration: 0.2, curve: .easeInOut)).setAlpha(view: optionsView, alpha: size.height < 180.0 ? 0.0 : 1.0)
            }
        } else {
            let buttonSize = self.glass ? glassPanelButtonSize : panelButtonSize
            
            transition.updateFrame(node: self.infoButtonNode, frame: CGRect(x: panelInset, y: panelInset, width: buttonSize.width, height: buttonSize.height))
            transition.updateFrame(node: self.locationButtonNode, frame: CGRect(x: panelInset, y: panelInset + buttonSize.height, width: buttonSize.width, height: buttonSize.height))
            transition.updateFrame(node: self.notificationButtonNode, frame: CGRect(x: panelInset, y: panelInset + buttonSize.height * 2.0, width: buttonSize.width, height: buttonSize.height))
            transition.updateFrame(node: self.optionsSeparatorNode, frame: CGRect(x: panelInset, y: panelInset + buttonSize.height, width: buttonSize.width, height: UIScreenPixel))
            transition.updateFrame(node: self.optionsSecondSeparatorNode, frame: CGRect(x: panelInset, y: panelInset + buttonSize.height * 2.0, width: buttonSize.width, height: UIScreenPixel))
            
            var panelHeight: CGFloat = buttonSize.height * 2.0
            if self.proximityNotification != nil {
                panelHeight += buttonSize.height
            }
            transition.updateAlpha(node: self.notificationButtonNode, alpha: self.proximityNotification != nil ? 1.0 : 0.0)
            transition.updateAlpha(node: self.optionsSecondSeparatorNode, alpha: self.proximityNotification != nil ? 1.0 : 0.0)
            
            let backgroundFrame = CGRect(x: size.width - inset - buttonSize.width - panelInset * 2.0 - layout.safeInsets.right - 6.0, y: size.height - panelHeight - inset - 14.0 - controlsBottomPadding, width: buttonSize.width + panelInset * 2.0, height: panelHeight + panelInset * 2.0)
            transition.updateFrame(node: self.optionsBackgroundNode, frame: backgroundFrame)
            if let optionsBackgroundView = self.optionsBackgroundView {
                let backgroundViewFrame = backgroundFrame.insetBy(dx: 4.0, dy: 4.0)
                transition.updateFrame(view: optionsBackgroundView, frame: backgroundViewFrame)
                optionsBackgroundView.update(size: backgroundViewFrame.size, cornerRadius: backgroundViewFrame.width * 0.5, isDark: self.presentationData.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: .immediate)
            }
            
            let alphaTransition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
            let optionsAlpha: CGFloat = size.height > 160.0 + navigationBarHeight && !self.forceIsHidden ? 1.0 : 0.0
            alphaTransition.updateAlpha(node: self.optionsBackgroundNode, alpha: optionsAlpha)
        }
    }
    
    public var forceIsHidden: Bool = false {
        didSet {
            if let (layout, navigationBarHeight, topPadding, controlsTopPadding, controlsBottomPadding, offset, size) = self.validLayout {
                self.updateLayout(layout: layout, navigationBarHeight: navigationBarHeight, topPadding: topPadding, controlsTopPadding: controlsTopPadding, controlsBottomPadding: controlsBottomPadding, offset: offset, size: size, transition: .immediate)
            }
        }
    }
        
    public func proximityButtonFrame() -> CGRect? {
        if let options = self.options {
            guard let optionsView = options.view as? LocationOptionsComponent.View else {
                return nil
            }
            return optionsView.proximityButtonFrame().flatMap { frame in
                return optionsView.convert(frame, to: self.view)
            }
        }

        if self.notificationButtonNode.alpha > 0.0 {
            return self.optionsBackgroundNode.view.convert(self.notificationButtonNode.frame, to: self.view)
        } else {
            return nil
        }
    }
    
    @objc private func infoPressed() {
        self.toggleMapModeSelection()
    }
    
    @objc private func locationPressed() {
        self.goToUserLocation()
    }
    
    @objc private func notificationPressed() {
        if let proximityNotification = self.proximityNotification {
            self.setupProximityNotification(proximityNotification)
        }
    }
    
    @objc private func placesPressed() {
        self.showPlacesInThisArea()
    }
}


final class LocationOptionsComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let mapMode: LocationMapMode
    let currentCoordinate: CLLocationCoordinate2D?
    let trackingMode: LocationTrackingMode
    let showMapModes: Bool
    let proximityNotification: Bool?
    let updateMapMode: (LocationMapMode) -> Void
    let goToUserLocation: () -> Void
    let requestedMapModes: () -> Void
    let setupProximityNotification: (Bool) -> Void
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        mapMode: LocationMapMode,
        currentCoordinate: CLLocationCoordinate2D?,
        trackingMode: LocationTrackingMode,
        showMapModes: Bool,
        proximityNotification: Bool?,
        updateMapMode: @escaping (LocationMapMode) -> Void,
        goToUserLocation: @escaping () -> Void,
        requestedMapModes: @escaping () -> Void,
        setupProximityNotification: @escaping (Bool) -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.mapMode = mapMode
        self.currentCoordinate = currentCoordinate
        self.trackingMode = trackingMode
        self.showMapModes = showMapModes
        self.proximityNotification = proximityNotification
        self.updateMapMode = updateMapMode
        self.goToUserLocation = goToUserLocation
        self.requestedMapModes = requestedMapModes
        self.setupProximityNotification = setupProximityNotification
    }

    static func ==(lhs: LocationOptionsComponent, rhs: LocationOptionsComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.mapMode != rhs.mapMode {
            return false
        }
        if lhs.mapMode == .satellite && LocationOptionsComponent.satelliteIconName(coordinate: lhs.currentCoordinate) != LocationOptionsComponent.satelliteIconName(coordinate: rhs.currentCoordinate) {
            return false
        }
        if lhs.trackingMode != rhs.trackingMode {
            return false
        }
        if lhs.showMapModes != rhs.showMapModes {
            return false
        }
        if lhs.proximityNotification != rhs.proximityNotification {
            return false
        }
        return true
    }

    private static func satelliteIconName(coordinate: CLLocationCoordinate2D?) -> String {
        guard let coordinate else {
            return "Location/OptionGlobeEurope"
        }

        var longitude = coordinate.longitude.truncatingRemainder(dividingBy: 360.0)
        if longitude < -180.0 {
            longitude += 360.0
        } else if longitude > 180.0 {
            longitude -= 360.0
        }

        if longitude >= -170.0 && longitude < -25.0 {
            return "Location/OptionGlobeAmerica"
        } else if longitude >= -25.0 && longitude < 60.0 {
            return "Location/OptionGlobeEurope"
        } else {
            return "Location/OptionGlobeAsia"
        }
    }

    final class View: HighlightTrackingButton {
        private let containerView: GlassBackgroundContainerView
        private let backgroundView: GlassBackgroundView
        private let clippingView: UIView
        
        private let collapsedContainerView = UIView()
        private var mapModeButton = ComponentView<Empty>()
        private var trackingButton = ComponentView<Empty>()
        private var notificationButton = ComponentView<Empty>()
        
        private let expandedContainerView = UIView()
        private let checkIcon = UIImageView()
        private var mapButton = ComponentView<Empty>()
        private var satelliteButton = ComponentView<Empty>()
        private var hybridButton = ComponentView<Empty>()
        
        private var component: LocationOptionsComponent?
        
        public override init(frame: CGRect) {
            self.containerView = GlassBackgroundContainerView()
            self.backgroundView = GlassBackgroundView()
            self.clippingView = UIView()
            self.clippingView.clipsToBounds = true
            
            self.checkIcon.image = UIImage(bundleImageName: "Media Gallery/Check")?.withRenderingMode(.alwaysTemplate)
            
            super.init(frame: frame)
            
            self.addSubview(self.containerView)
            self.containerView.contentView.addSubview(self.backgroundView)
            self.backgroundView.contentView.addSubview(self.clippingView)
            self.clippingView.addSubview(self.collapsedContainerView)
            self.clippingView.addSubview(self.expandedContainerView)
        }
        
        public required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        func update(component: LocationOptionsComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
             
            let mapButtonSize = self.mapButton.update(
                transition: transition,
                component: AnyComponent(
                    PlainButtonComponent(
                        content: AnyComponent(
                            MultilineTextComponent(text: .plain(NSAttributedString(string: component.strings.Map_Map, font: Font.regular(17.0), textColor: component.theme.rootController.navigationBar.primaryTextColor)))
                        ),
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.updateMapMode(.map)
                        },
                        animateScale: false
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            
            let satelliteButtonSize = self.satelliteButton.update(
                transition: transition,
                component: AnyComponent(
                    PlainButtonComponent(
                        content: AnyComponent(
                            MultilineTextComponent(text: .plain(NSAttributedString(string: component.strings.Map_Satellite, font: Font.regular(17.0), textColor: component.theme.rootController.navigationBar.primaryTextColor)))
                        ),
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.updateMapMode(.satellite)
                        },
                        animateScale: false
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            
            let hybridButtonSize = self.hybridButton.update(
                transition: transition,
                component: AnyComponent(
                    PlainButtonComponent(
                        content: AnyComponent(
                            MultilineTextComponent(text: .plain(NSAttributedString(string: component.strings.Map_Hybrid, font: Font.regular(17.0), textColor: component.theme.rootController.navigationBar.primaryTextColor)))
                        ),
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.updateMapMode(.hybrid)
                        },
                        animateScale: false
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            
            self.checkIcon.tintColor = component.theme.rootController.navigationBar.primaryTextColor
            if let image = self.checkIcon.image {
                self.checkIcon.frame = CGRect(origin: CGPoint(x: -34.0, y: floorToScreenPixels((mapButtonSize.height - image.size.height) / 2.0)), size: image.size)
            }
            
            let leftInset: CGFloat = 60.0
            let rightInset: CGFloat = 44.0
            let verticalInset: CGFloat = 23.0
            let maxWidth = max(mapButtonSize.width, max(satelliteButtonSize.width, hybridButtonSize.width))
            let cornerRadius: CGFloat = component.showMapModes ? 27.0 : 20.0
            
            let expandedSize = CGSize(width: leftInset + maxWidth + rightInset, height: 150.0)

            let mapButtonFrame = CGRect(origin: CGPoint(x: leftInset, y: verticalInset), size: mapButtonSize)
            if let mapButtonView = self.mapButton.view {
                if mapButtonView.superview == nil {
                    self.expandedContainerView.addSubview(mapButtonView)
                }
                if component.mapMode == .map && component.showMapModes {
                    mapButtonView.addSubview(self.checkIcon)
                }
                transition.setFrame(view: mapButtonView, frame: mapButtonFrame)
            }
            
            let satelliteButtonFrame = CGRect(origin: CGPoint(x: leftInset, y: floorToScreenPixels((expandedSize.height - satelliteButtonSize.height) / 2.0)), size: satelliteButtonSize)
            if let satelliteButtonView = self.satelliteButton.view {
                if satelliteButtonView.superview == nil {
                    self.expandedContainerView.addSubview(satelliteButtonView)
                }
                if component.mapMode == .satellite && component.showMapModes {
                    satelliteButtonView.addSubview(self.checkIcon)
                }
                transition.setFrame(view: satelliteButtonView, frame: satelliteButtonFrame)
            }
            
            let hybridButtonFrame = CGRect(origin: CGPoint(x: leftInset, y: expandedSize.height - hybridButtonSize.height - verticalInset), size: hybridButtonSize)
            if let hybridButtonView = self.hybridButton.view {
                if hybridButtonView.superview == nil {
                    self.expandedContainerView.addSubview(hybridButtonView)
                }
                if component.mapMode == .hybrid && component.showMapModes {
                    hybridButtonView.addSubview(self.checkIcon)
                }
                transition.setFrame(view: hybridButtonView, frame: hybridButtonFrame)
            }
            
            let normalSize = CGSize(width: 40.0, height: component.proximityNotification != nil ? 120.0 : 80.0)
            
            let expandedFrame = CGRect(origin: .zero, size: expandedSize)
            let collapsedFrame = CGRect(origin: CGPoint(x: expandedSize.width - normalSize.width, y: expandedSize.height - normalSize.height), size: normalSize)
            
            let effectiveBackgroundFrame = component.showMapModes ? expandedFrame : collapsedFrame
            self.backgroundView.update(size: effectiveBackgroundFrame.size, cornerRadius: cornerRadius, isDark: component.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: transition)
            transition.setFrame(view: self.backgroundView, frame: effectiveBackgroundFrame)
            
            transition.setFrame(view: self.clippingView, frame: CGRect(origin: .zero, size: effectiveBackgroundFrame.size))
            
            transition.setFrame(view: self.expandedContainerView, frame: expandedFrame.offsetBy(dx: effectiveBackgroundFrame.width - expandedFrame.width, dy: effectiveBackgroundFrame.height - expandedFrame.height))
            transition.setFrame(view: self.collapsedContainerView, frame: collapsedFrame.offsetBy(dx: -effectiveBackgroundFrame.minX, dy: -effectiveBackgroundFrame.minY))
            
            var mapModeIconName: String
            switch component.mapMode {
            case .map:
                mapModeIconName = "Location/OptionMap"
            case .satellite:
                mapModeIconName = LocationOptionsComponent.satelliteIconName(coordinate: component.currentCoordinate)
            case .hybrid:
                mapModeIconName = "Location/OptionHybrid"
            }
            let mapModeButtonSize = self.mapModeButton.update(
                transition: transition,
                component: AnyComponent(
                    PlainButtonComponent(
                        content: AnyComponent(
                            BundleIconComponent(name: mapModeIconName, tintColor: component.theme.chat.inputPanel.panelControlColor)
                        ),
                        minSize: CGSize(width: 40.0, height: 40.0),
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.requestedMapModes()
                        },
                        animateAlpha: true,
                        animateScale: false
                    )
                ),
                environment: {},
                containerSize: CGSize(width: 40.0, height: 40.0)
            )
            let mapModeButtonFrame = CGRect(origin: .zero, size: mapModeButtonSize)
            if let mapModeButtonView = self.mapModeButton.view {
                if mapModeButtonView.superview == nil {
                    self.collapsedContainerView.addSubview(mapModeButtonView)
                }
                transition.setFrame(view: mapModeButtonView, frame: mapModeButtonFrame)
            }

            let trackingModeIconName: String
            switch component.trackingMode {
            case .none:
                trackingModeIconName = "Location/OptionLocate"
            case .follow:
                trackingModeIconName = "Location/OptionLocating"
            case .followWithHeading:
                trackingModeIconName = "Location/OptionTracking"
            }
            let trackingButtonSize = self.trackingButton.update(
                transition: transition,
                component: AnyComponent(
                    PlainButtonComponent(
                        content: AnyComponent(
                            BundleIconComponent(name: trackingModeIconName, tintColor: component.theme.chat.inputPanel.panelControlColor)
                        ),
                        minSize: CGSize(width: 40.0, height: 40.0),
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.goToUserLocation()
                        },
                        animateAlpha: true,
                        animateScale: false
                    )
                ),
                environment: {},
                containerSize: CGSize(width: 40.0, height: 40.0)
            )
            let trackingButtonFrame = CGRect(origin: CGPoint(x: 0.0, y: 40.0), size: trackingButtonSize)
            if let trackingButtonView = self.trackingButton.view {
                if trackingButtonView.superview == nil {
                    self.collapsedContainerView.addSubview(trackingButtonView)
                }
                transition.setFrame(view: trackingButtonView, frame: trackingButtonFrame)
            }
            
            if let proximityNotification = component.proximityNotification {
                let notificationIconName = proximityNotification ? "Chat/Title Panels/MuteIcon" : "Location/NotificationIcon"
                let notificationButtonSize = self.notificationButton.update(
                    transition: transition,
                    component: AnyComponent(
                        PlainButtonComponent(
                            content: AnyComponent(
                                BundleIconComponent(name: notificationIconName, tintColor: component.theme.chat.inputPanel.panelControlColor)
                            ),
                            minSize: CGSize(width: 40.0, height: 40.0),
                            action: { [weak self] in
                                guard let self, let component = self.component, let proximityNotification = component.proximityNotification else {
                                    return
                                }
                                component.setupProximityNotification(proximityNotification)
                            },
                            animateAlpha: true,
                            animateScale: false
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: 40.0, height: 40.0)
                )
                let notificationButtonFrame = CGRect(origin: CGPoint(x: 0.0, y: 80.0), size: notificationButtonSize)
                if let notificationButtonView = self.notificationButton.view {
                    if notificationButtonView.superview == nil {
                        self.collapsedContainerView.addSubview(notificationButtonView)
                    }
                    transition.setFrame(view: notificationButtonView, frame: notificationButtonFrame)
                    transition.setAlpha(view: notificationButtonView, alpha: 1.0)
                }
            } else if let notificationButtonView = self.notificationButton.view {
                transition.setAlpha(view: notificationButtonView, alpha: 0.0)
            }

            transition.setAlpha(view: self.collapsedContainerView, alpha: component.showMapModes ? 0.0 : 1.0)
            transition.setAlpha(view: self.expandedContainerView, alpha: component.showMapModes ? 1.0 : 0.0)
            
            self.containerView.update(size: expandedSize, isDark: component.theme.overallDarkAppearance, transition: transition)
            transition.setFrame(view: self.containerView, frame: CGRect(origin: .zero, size: expandedSize))
            
            return expandedSize
        }
        
        public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            return self.backgroundView.frame.contains(point)
        }

        func proximityButtonFrame() -> CGRect? {
            guard let component = self.component, component.proximityNotification != nil, !component.showMapModes else {
                return nil
            }
            guard let notificationButtonView = self.notificationButton.view, notificationButtonView.superview != nil, notificationButtonView.alpha > 0.0 else {
                return nil
            }
            return notificationButtonView.convert(notificationButtonView.bounds, to: self)
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
