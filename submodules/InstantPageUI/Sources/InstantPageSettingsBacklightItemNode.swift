import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AppBundle
import LegacyComponents

func generateKnobImage() -> UIImage? {
    return generateImage(CGSize(width: 40.0, height: 40.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setShadow(offset: CGSize(width: 0.0, height: -3.0), blur: 12.0, color: UIColor(white: 0.0, alpha: 0.25).cgColor)
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 6.0, y: 6.0), size: CGSize(width: 28.0, height: 28.0)))
    })
}

final class InstantPageSettingsBacklightItemNode: InstantPageSettingsItemNode {
    private let sliderView: TGPhotoEditorSliderView
    private let leftIconNode: ASImageNode
    private let rightIconNode: ASImageNode
    
    init(theme: InstantPageSettingsItemTheme) {
        self.sliderView = TGPhotoEditorSliderView()
        self.sliderView.enablePanHandling = true
        self.sliderView.trackCornerRadius = 1.0
        self.sliderView.lineSize = 2.0
        self.sliderView.minimumValue = 0.0
        self.sliderView.startValue = 0.0
        self.sliderView.maximumValue = 100.0
        self.sliderView.disablesInteractiveTransitionGestureRecognizer = true
        
        self.leftIconNode = ASImageNode()
        self.leftIconNode.displaysAsynchronously = false
        self.leftIconNode.displayWithoutProcessing = true
        
        self.rightIconNode = ASImageNode()
        self.rightIconNode.displaysAsynchronously = false
        self.rightIconNode.displayWithoutProcessing = true
        
        super.init(theme: theme, selectable: false)
        
        self.updateTheme(theme)
        
        self.sliderView.value = UIScreen.main.brightness * 100.0
        self.sliderView.addTarget(self, action: #selector(self.sliderChanged), for: .valueChanged)
        self.view.addSubview(self.sliderView)
        
        self.addSubnode(self.leftIconNode)
        self.addSubnode(self.rightIconNode)
    }
    
    override func updateTheme(_ theme: InstantPageSettingsItemTheme) {
        super.updateTheme(theme)
        
        self.sliderView.backgroundColor = theme.itemBackgroundColor
        self.sliderView.backColor = theme.secondaryColor
        self.sliderView.trackColor = theme.accentColor
        self.sliderView.knobImage = generateKnobImage()
        
        self.leftIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Instant View/SettingsBrightnessMinIcon"), color: theme.primaryColor)
        self.rightIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Instant View/SettingsBrightnessMaxIcon"), color: theme.primaryColor)
    }
    
    override func updateInternalLayout(width: CGFloat, insets: UIEdgeInsets, previousItem: (InstantPageSettingsItemNodeStatus, InstantPageSettingsItemNode?), nextItem: (InstantPageSettingsItemNodeStatus, InstantPageSettingsItemNode?)) -> (height: CGFloat, separatorInset: CGFloat?) {
        self.sliderView.frame = CGRect(origin: CGPoint(x: 38.0, y: 8.0), size: CGSize(width: width - 38.0 * 2.0, height: 44.0))
        if let image = self.leftIconNode.image {
            self.leftIconNode.frame = CGRect(origin: CGPoint(x: 16.0, y: 24.0), size: CGSize(width:  image.size.width, height: image.size.height))
        }
        if let image = self.rightIconNode.image {
            self.rightIconNode.frame = CGRect(origin: CGPoint(x: width - 13.0 - image.size.width, y: 21.0), size: CGSize(width:  image.size.width, height: image.size.height))
        }
        return (62.0 + insets.top + insets.bottom, nil)
    }
    
    @objc func sliderChanged() {
        UIScreen.main.brightness = self.sliderView.value / 100.0
    }
}
