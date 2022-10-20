import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import AppBundle
import CoreLocation

private let panelInset: CGFloat = 4.0
private let panelButtonSize = CGSize(width: 46.0, height: 46.0)

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

final class LocationMapHeaderNode: ASDisplayNode {
    private var presentationData: PresentationData
    private let toggleMapModeSelection: () -> Void
    private let goToUserLocation: () -> Void
    private let showPlacesInThisArea: () -> Void
    private let setupProximityNotification: (Bool) -> Void
    
    private var displayingPlacesButton = false
    private var proximityNotification: Bool?
    
    let mapNode: LocationMapNode
    var trackingMode: LocationTrackingMode = .none
    
    private let optionsBackgroundNode: ASImageNode
    private let optionsSeparatorNode: ASDisplayNode
    private let optionsSecondSeparatorNode: ASDisplayNode
    private let infoButtonNode: HighlightableButtonNode
    private let locationButtonNode: HighlightableButtonNode
    private let notificationButtonNode: HighlightableButtonNode
    private let placesBackgroundNode: ASImageNode
    private let placesButtonNode: HighlightableButtonNode
    private let shadowNode: ASImageNode
    
    private var validLayout: (ContainerViewLayout, CGFloat, CGFloat, CGFloat, CGSize)?
    
    init(presentationData: PresentationData, toggleMapModeSelection: @escaping () -> Void, goToUserLocation: @escaping () -> Void, setupProximityNotification: @escaping (Bool) -> Void = { _ in }, showPlacesInThisArea: @escaping () -> Void = {}) {
        self.presentationData = presentationData
        self.toggleMapModeSelection = toggleMapModeSelection
        self.goToUserLocation = goToUserLocation
        self.setupProximityNotification = setupProximityNotification
        self.showPlacesInThisArea = showPlacesInThisArea
        
        self.mapNode = LocationMapNode()
        
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
        
        self.infoButtonNode = HighlightableButtonNode()
        self.infoButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Location/InfoIcon"), color: presentationData.theme.rootController.navigationBar.buttonColor), for: .normal)
        self.infoButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Location/InfoActiveIcon"), color: presentationData.theme.rootController.navigationBar.buttonColor), for: .selected)
        self.infoButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Location/InfoActiveIcon"), color: presentationData.theme.rootController.navigationBar.buttonColor), for: [.selected, .highlighted])
        
        self.locationButtonNode = HighlightableButtonNode()
        self.locationButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Location/TrackIcon"), color: presentationData.theme.rootController.navigationBar.buttonColor), for: .normal)
        
        self.notificationButtonNode = HighlightableButtonNode()
        self.notificationButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Location/NotificationIcon"), color: presentationData.theme.rootController.navigationBar.buttonColor), for: .normal)
        self.notificationButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Title Panels/MuteIcon"), color: presentationData.theme.rootController.navigationBar.buttonColor), for: .selected)
        self.notificationButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Title Panels/MuteIcon"), color: presentationData.theme.rootController.navigationBar.buttonColor), for: [.selected, .highlighted])
        
        self.placesBackgroundNode = ASImageNode()
        self.placesBackgroundNode.contentMode = .scaleToFill
        self.placesBackgroundNode.displaysAsynchronously = false
        self.placesBackgroundNode.displayWithoutProcessing = true
        self.placesBackgroundNode.image = generateBackgroundImage(theme: presentationData.theme)
        self.placesBackgroundNode.isUserInteractionEnabled = true
        
        self.placesButtonNode = HighlightableButtonNode()
        self.placesButtonNode.setTitle(presentationData.strings.Map_PlacesInThisArea, with: Font.regular(17.0), with: presentationData.theme.rootController.navigationBar.buttonColor, for: .normal)
        
        self.shadowNode = ASImageNode()
        self.shadowNode.contentMode = .scaleToFill
        self.shadowNode.displaysAsynchronously = false
        self.shadowNode.displayWithoutProcessing = true
        self.shadowNode.image = generateShadowImage(theme: presentationData.theme, highlighted: false)
        
        super.init()
        
        self.clipsToBounds = true
        
        self.addSubnode(self.mapNode)
        self.addSubnode(self.optionsBackgroundNode)
        self.optionsBackgroundNode.addSubnode(self.optionsSeparatorNode)
        self.optionsBackgroundNode.addSubnode(self.optionsSecondSeparatorNode)
        self.optionsBackgroundNode.addSubnode(self.infoButtonNode)
        self.optionsBackgroundNode.addSubnode(self.locationButtonNode)
        self.optionsBackgroundNode.addSubnode(self.notificationButtonNode)
        self.addSubnode(self.placesBackgroundNode)
        self.placesBackgroundNode.addSubnode(self.placesButtonNode)
        self.addSubnode(self.shadowNode)
        
        self.infoButtonNode.addTarget(self, action: #selector(self.infoPressed), forControlEvents: .touchUpInside)
        self.locationButtonNode.addTarget(self, action: #selector(self.locationPressed), forControlEvents: .touchUpInside)
        self.notificationButtonNode.addTarget(self, action: #selector(self.notificationPressed), forControlEvents: .touchUpInside)
        self.placesButtonNode.addTarget(self, action: #selector(self.placesPressed), forControlEvents: .touchUpInside)
    }
    
    func updateState(mapMode: LocationMapMode, trackingMode: LocationTrackingMode, displayingMapModeOptions: Bool, displayingPlacesButton: Bool, proximityNotification: Bool?, animated: Bool) {
        self.mapNode.mapMode = mapMode
        self.trackingMode = trackingMode
        self.infoButtonNode.isSelected = displayingMapModeOptions
        self.notificationButtonNode.isSelected = proximityNotification ?? false
        
        self.locationButtonNode.setImage(generateTintedImage(image: self.iconForTracking(), color: self.presentationData.theme.rootController.navigationBar.buttonColor), for: .normal)
        
        let updateLayout = self.displayingPlacesButton != displayingPlacesButton || self.proximityNotification != proximityNotification
        self.displayingPlacesButton = displayingPlacesButton
        self.proximityNotification = proximityNotification
        
        if updateLayout, let (layout, navigationBarHeight, topPadding, offset, size) = self.validLayout {
            let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.3, curve: .spring) : .immediate
            self.updateLayout(layout: layout, navigationBarHeight: navigationBarHeight, topPadding: topPadding, offset: offset, size: size, transition: transition)
        }
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.optionsBackgroundNode.image = generateBackgroundImage(theme: presentationData.theme)
        self.optionsSeparatorNode.backgroundColor = presentationData.theme.rootController.navigationBar.separatorColor
        self.optionsSecondSeparatorNode.backgroundColor = presentationData.theme.rootController.navigationBar.separatorColor
        self.infoButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Location/InfoIcon"), color: presentationData.theme.rootController.navigationBar.buttonColor), for: .normal)
        self.infoButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Location/InfoActiveIcon"), color: presentationData.theme.rootController.navigationBar.buttonColor), for: .selected)
        self.infoButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Location/InfoActiveIcon"), color: presentationData.theme.rootController.navigationBar.buttonColor), for: [.selected, .highlighted])
        self.locationButtonNode.setImage(generateTintedImage(image: self.iconForTracking(), color: presentationData.theme.rootController.navigationBar.buttonColor), for: .normal)
        self.notificationButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Location/NotificationIcon"), color: presentationData.theme.rootController.navigationBar.buttonColor), for: .normal)
        self.notificationButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Title Panels/MuteIcon"), color: presentationData.theme.rootController.navigationBar.buttonColor), for: .selected)
        self.notificationButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Chat/Title Panels/MuteIcon"), color: presentationData.theme.rootController.navigationBar.buttonColor), for: [.selected, .highlighted])
        self.placesBackgroundNode.image = generateBackgroundImage(theme: presentationData.theme)
        self.shadowNode.image = generateShadowImage(theme: presentationData.theme, highlighted: false)
    }
    
    private func iconForTracking() -> UIImage? {
        switch self.trackingMode {
            case .none:
                return UIImage(bundleImageName: "Location/TrackIcon")
            case .follow:
                return UIImage(bundleImageName: "Location/TrackActiveIcon")
            case .followWithHeading:
                return UIImage(bundleImageName: "Location/TrackHeadingIcon")
        }
    }
    
    func updateLayout(layout: ContainerViewLayout, navigationBarHeight: CGFloat, topPadding: CGFloat, offset: CGFloat, size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight, topPadding, offset, size)
        
        let mapHeight: CGFloat = floor(layout.size.height * 1.3)
        let mapFrame = CGRect(x: 0.0, y: floorToScreenPixels((size.height - mapHeight + navigationBarHeight) / 2.0) + offset, width: size.width, height: mapHeight)
        transition.updateFrame(node: self.mapNode, frame: mapFrame)
        self.mapNode.updateLayout(size: mapFrame.size)
        
        let inset: CGFloat = 6.0
        
        let placesButtonSize = CGSize(width: 180.0 + panelInset * 2.0, height: 45.0 + panelInset * 2.0)
        let placesButtonFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - placesButtonSize.width) / 2.0), y: self.displayingPlacesButton ? navigationBarHeight + topPadding + inset : 0.0), size: placesButtonSize)
        transition.updateFrame(node: self.placesBackgroundNode, frame: placesButtonFrame)
        transition.updateFrame(node: self.placesButtonNode, frame: CGRect(origin: CGPoint(), size: placesButtonSize))
        
        transition.updateFrame(node: self.shadowNode, frame: CGRect(x: 0.0, y: size.height - 14.0, width: size.width, height: 14.0))
        
        transition.updateFrame(node: self.infoButtonNode, frame: CGRect(x: panelInset, y: panelInset, width: panelButtonSize.width, height: panelButtonSize.height))
        transition.updateFrame(node: self.locationButtonNode, frame: CGRect(x: panelInset, y: panelInset + panelButtonSize.height, width: panelButtonSize.width, height: panelButtonSize.height))
        transition.updateFrame(node: self.notificationButtonNode, frame: CGRect(x: panelInset, y: panelInset + panelButtonSize.height * 2.0, width: panelButtonSize.width, height: panelButtonSize.height))
        transition.updateFrame(node: self.optionsSeparatorNode, frame: CGRect(x: panelInset, y: panelInset + panelButtonSize.height, width: panelButtonSize.width, height: UIScreenPixel))
        transition.updateFrame(node: self.optionsSecondSeparatorNode, frame: CGRect(x: panelInset, y: panelInset + panelButtonSize.height * 2.0, width: panelButtonSize.width, height: UIScreenPixel))
        
        var panelHeight: CGFloat = panelButtonSize.height * 2.0
        if self.proximityNotification != nil {
            panelHeight += panelButtonSize.height
        }
        transition.updateAlpha(node: self.notificationButtonNode, alpha: self.proximityNotification != nil ? 1.0 : 0.0)
        transition.updateAlpha(node: self.optionsSecondSeparatorNode, alpha: self.proximityNotification != nil ? 1.0 : 0.0)
        
        transition.updateFrame(node: self.optionsBackgroundNode, frame: CGRect(x: size.width - inset - panelButtonSize.width - panelInset * 2.0 - layout.safeInsets.right, y: navigationBarHeight + topPadding + inset, width: panelButtonSize.width + panelInset * 2.0, height: panelHeight + panelInset * 2.0))
        
        let alphaTransition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
        let optionsAlpha: CGFloat = size.height > 160.0 + navigationBarHeight && !self.forceIsHidden ? 1.0 : 0.0
        alphaTransition.updateAlpha(node: self.optionsBackgroundNode, alpha: optionsAlpha)
    }
    
    var forceIsHidden: Bool = false {
        didSet {
            if let (layout, navigationBarHeight, topPadding, offset, size) = self.validLayout {
                self.updateLayout(layout: layout, navigationBarHeight: navigationBarHeight, topPadding: topPadding, offset: offset, size: size, transition: .immediate)
            }
        }
    }
    
    func updateHighlight(_ highlighted: Bool) {
        self.shadowNode.image = generateShadowImage(theme: self.presentationData.theme, highlighted: highlighted)
    }
    
    func proximityButtonFrame() -> CGRect? {
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
