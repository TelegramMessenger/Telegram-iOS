import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AppBundle
import LegacyComponents

final class InstantPageSettingsFontSizeItemNode: InstantPageSettingsItemNode {
    private let updated: (Int) -> Void
    
    private let sliderView: TGPhotoEditorSliderView
    private let leftIconNode: ASImageNode
    private let rightIconNode: ASImageNode
    
    init(theme: InstantPageSettingsItemTheme, fontSizeVariant: Int, updated: @escaping (Int) -> Void) {
        self.updated = updated
        
        self.sliderView = TGPhotoEditorSliderView()
        self.sliderView.enablePanHandling = true
        self.sliderView.trackCornerRadius = 1.0
        self.sliderView.lineSize = 2.0
        self.sliderView.dotSize = 5.0
        self.sliderView.minimumValue = 0.0
        self.sliderView.maximumValue = 4.0
        self.sliderView.startValue = 0.0
        self.sliderView.value = CGFloat(fontSizeVariant)
        self.sliderView.positionsCount = 5
        self.sliderView.disablesInteractiveTransitionGestureRecognizer = true
        
        self.leftIconNode = ASImageNode()
        self.leftIconNode.displaysAsynchronously = false
        self.leftIconNode.displayWithoutProcessing = true
        
        self.rightIconNode = ASImageNode()
        self.rightIconNode.displaysAsynchronously = false
        self.rightIconNode.displayWithoutProcessing = true
        
        super.init(theme: theme, selectable: false)
        
        self.updateTheme(theme)
        
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
        
        self.leftIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Instant View/SettingsFontMinIcon"), color: theme.primaryColor)
        self.rightIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Instant View/SettingsFontMaxIcon"), color: theme.primaryColor)
    }
    
    override func updateInternalLayout(width: CGFloat, insets: UIEdgeInsets, previousItem: (InstantPageSettingsItemNodeStatus, InstantPageSettingsItemNode?), nextItem: (InstantPageSettingsItemNodeStatus, InstantPageSettingsItemNode?)) -> (height: CGFloat, separatorInset: CGFloat?) {
        self.sliderView.frame = CGRect(origin: CGPoint(x: 38.0, y: 8.0), size: CGSize(width: width - 38.0 * 2.0, height: 44.0))
        if let image = self.leftIconNode.image {
            self.leftIconNode.frame = CGRect(origin: CGPoint(x: 18.0, y: 25.0), size: CGSize(width:  image.size.width, height: image.size.height))
        }
        if let image = self.rightIconNode.image {
            self.rightIconNode.frame = CGRect(origin: CGPoint(x: width - 14.0 - image.size.width, y: 21.0), size: CGSize(width:  image.size.width, height: image.size.height))
        }
        return (62.0 + insets.top + insets.bottom, nil)
    }
    
    @objc func sliderChanged() {
        self.updated(max(0, min(4, Int(self.sliderView.value))))
    }
}
