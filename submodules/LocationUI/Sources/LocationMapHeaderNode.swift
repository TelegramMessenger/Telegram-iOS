import Foundation
import Display
import TelegramPresentationData
import AppBundle

private let panelInset: CGFloat = 4.0
private let panelSize = CGSize(width: 46.0, height: 90.0)

private func generateBackgroundImage(theme: PresentationTheme) -> UIImage? {
    return generateImage(CGSize(width: panelSize.width + panelInset * 2.0, height: panelSize.height + panelInset * 2.0)) { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setShadow(offset: CGSize(), blur: 10.0, color: UIColor(rgb: 0x000000, alpha: 0.2).cgColor)
        context.setFillColor(theme.rootController.navigationBar.backgroundColor.cgColor)
        let path = UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: panelInset, y: panelInset), size: panelSize), cornerRadius: 9.0)
        context.addPath(path.cgPath)
        context.fillPath()
    
        context.setShadow(offset: CGSize(), blur: 0.0, color: nil)
        context.setFillColor(theme.rootController.navigationBar.separatorColor.cgColor)
        context.fill(CGRect(x: panelInset, y: panelInset + floorToScreenPixels(panelSize.height / 2.0), width: panelSize.width, height: UIScreenPixel))
    }
}

private func generateShadowImage(theme: PresentationTheme, highlighted: Bool) -> UIImage? {
    return generateImage(CGSize(width: 26.0, height: 14.0)) { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setShadow(offset: CGSize(), blur: 10.0, color: UIColor(rgb: 0x000000, alpha: 0.2).cgColor)
        context.setFillColor(highlighted ? theme.list.itemHighlightedBackgroundColor.cgColor : theme.list.plainBackgroundColor.cgColor)
        let path = UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: 0.0, y: 4.0), size: CGSize(width: 26.0, height: 20.0)), cornerRadius: 9.0)
        context.addPath(path.cgPath)
        context.fillPath()
    }?.stretchableImage(withLeftCapWidth: 13, topCapHeight: 0)
}

final class LocationMapHeaderNode: ASDisplayNode {
    private var presentationData: PresentationData
    private let interaction: LocationPickerInteraction
    
    let mapNode: LocationMapNode
    private let optionsBackgroundNode: ASImageNode
    private let infoButtonNode: HighlightableButtonNode
    private let locationButtonNode: HighlightableButtonNode
    private let shadowNode: ASImageNode
    
    init(presentationData: PresentationData, interaction: LocationPickerInteraction) {
        self.presentationData = presentationData
        self.interaction = interaction
        
        self.mapNode = LocationMapNode()
        
        self.optionsBackgroundNode = ASImageNode()
        self.optionsBackgroundNode.displaysAsynchronously = false
        self.optionsBackgroundNode.displayWithoutProcessing = true
        self.optionsBackgroundNode.image = generateBackgroundImage(theme: presentationData.theme)
        self.optionsBackgroundNode.isUserInteractionEnabled = true
        
        self.infoButtonNode = HighlightableButtonNode()
        self.infoButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Location/InfoIcon"), color: presentationData.theme.rootController.navigationBar.buttonColor), for: .normal)
        self.infoButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Location/InfoActiveIcon"), color: presentationData.theme.rootController.navigationBar.buttonColor), for: .selected)
        self.infoButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Location/InfoActiveIcon"), color: presentationData.theme.rootController.navigationBar.buttonColor), for: [.selected, .highlighted])
        
        self.locationButtonNode = HighlightableButtonNode()
        self.locationButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Location/TrackIcon"), color: presentationData.theme.rootController.navigationBar.buttonColor), for: .normal)
        
        self.shadowNode = ASImageNode()
        self.shadowNode.contentMode = .scaleToFill
        self.shadowNode.displaysAsynchronously = false
        self.shadowNode.displayWithoutProcessing = true
        self.shadowNode.image = generateShadowImage(theme: presentationData.theme, highlighted: false)
        
        super.init()
        
        self.clipsToBounds = true
        
        self.addSubnode(self.mapNode)
        self.addSubnode(self.optionsBackgroundNode)
        self.optionsBackgroundNode.addSubnode(self.infoButtonNode)
        self.optionsBackgroundNode.addSubnode(self.locationButtonNode)
        self.addSubnode(self.shadowNode)
        
        self.infoButtonNode.addTarget(self, action: #selector(self.infoPressed), forControlEvents: .touchUpInside)
        self.locationButtonNode.addTarget(self, action: #selector(self.locationPressed), forControlEvents: .touchUpInside)
    }
    
    func updateState(_ state: LocationPickerState) {
        self.mapNode.mapMode = state.mapMode
        self.infoButtonNode.isSelected = state.displayingMapModeOptions
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.optionsBackgroundNode.image = generateBackgroundImage(theme: presentationData.theme)
        self.infoButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Location/InfoIcon"), color: presentationData.theme.rootController.navigationBar.buttonColor), for: .normal)
        self.infoButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Location/InfoActiveIcon"), color: presentationData.theme.rootController.navigationBar.buttonColor), for: .selected)
        self.infoButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Location/InfoActiveIcon"), color: presentationData.theme.rootController.navigationBar.buttonColor), for: [.selected, .highlighted])
        self.locationButtonNode.setImage(generateTintedImage(image: UIImage(bundleImageName: "Location/TrackIcon"), color: presentationData.theme.rootController.navigationBar.buttonColor), for: .normal)
        self.shadowNode.image = generateShadowImage(theme: presentationData.theme, highlighted: false)
    }
    
    func updateLayout(layout: ContainerViewLayout, navigationBarHeight: CGFloat, padding: CGFloat, size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.mapNode, frame: CGRect(x: 0.0, y: floorToScreenPixels((size.height - layout.size.height + navigationBarHeight) / 2.0), width: size.width, height: layout.size.height))
        
        transition.updateFrame(node: self.shadowNode, frame: CGRect(x: 0.0, y: size.height - 14.0, width: size.width, height: 14.0))
        
        let inset: CGFloat = 6.0
        transition.updateFrame(node: self.optionsBackgroundNode, frame: CGRect(x: size.width - inset - panelSize.width - panelInset * 2.0, y: navigationBarHeight + padding + inset, width: panelSize.width + panelInset * 2.0, height: panelSize.height + panelInset * 2.0))
        
        transition.updateFrame(node: self.infoButtonNode, frame: CGRect(x: panelInset, y: panelInset, width: panelSize.width, height: panelSize.height / 2.0))
        transition.updateFrame(node: self.locationButtonNode, frame: CGRect(x: panelInset, y: panelInset + panelSize.height / 2.0, width: panelSize.width, height: panelSize.height / 2.0))
        
        let alphaTransition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
        let optionsAlpha: CGFloat = size.height > 110.0 + navigationBarHeight ? 1.0 : 0.0
        alphaTransition.updateAlpha(node: self.optionsBackgroundNode, alpha: optionsAlpha)
    }
    
    func updateHighlight(_ highlighted: Bool) {
        self.shadowNode.image = generateShadowImage(theme: self.presentationData.theme, highlighted: highlighted)
    }
    
    @objc private func infoPressed() {
        self.interaction.toggleMapModeSelection()
    }
    
    @objc private func locationPressed() {
        self.interaction.goToUserLocation()
    }
}
