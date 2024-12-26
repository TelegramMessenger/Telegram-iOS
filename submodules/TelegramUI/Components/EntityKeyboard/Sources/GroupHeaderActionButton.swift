import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData

final class GroupHeaderActionButton: UIButton {
    override static var layerClass: AnyClass {
        return PassthroughLayer.self
    }
    
    let tintContainerLayer: SimpleLayer
    
    private var currentTextLayout: (string: String, color: UIColor, constrainedWidth: CGFloat, size: CGSize)?
    private let backgroundLayer: SimpleLayer
    private let tintBackgroundLayer: SimpleLayer
    private let textLayer: SimpleLayer
    private let tintTextLayer: SimpleLayer
    private let pressed: () -> Void
    
    init(pressed: @escaping () -> Void) {
        self.pressed = pressed
        
        self.tintContainerLayer = SimpleLayer()
        
        self.backgroundLayer = SimpleLayer()
        self.backgroundLayer.masksToBounds = true
        
        self.tintBackgroundLayer = SimpleLayer()
        self.tintBackgroundLayer.masksToBounds = true
        
        self.textLayer = SimpleLayer()
        self.tintTextLayer = SimpleLayer()
        
        super.init(frame: CGRect())
        
        (self.layer as? PassthroughLayer)?.mirrorLayer = self.tintContainerLayer
        
        self.layer.addSublayer(self.backgroundLayer)
        self.layer.addSublayer(self.textLayer)
        
        self.addTarget(self, action: #selector(self.onPressed), for: .touchUpInside)
        
        self.tintContainerLayer.addSublayer(self.tintBackgroundLayer)
        self.tintContainerLayer.addSublayer(self.tintTextLayer)
    }
    
    required init(coder: NSCoder) {
        preconditionFailure()
    }
    
    @objc private func onPressed() {
        self.pressed()
    }
    
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        self.alpha = 0.6
        
        return super.beginTracking(touch, with: event)
    }
    
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        let alpha = self.alpha
        self.alpha = 1.0
        self.layer.animateAlpha(from: alpha, to: 1.0, duration: 0.25)
        
        super.endTracking(touch, with: event)
    }
    
    override func cancelTracking(with event: UIEvent?) {
        let alpha = self.alpha
        self.alpha = 1.0
        self.layer.animateAlpha(from: alpha, to: 1.0, duration: 0.25)
        
        super.cancelTracking(with: event)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        let alpha = self.alpha
        self.alpha = 1.0
        self.layer.animateAlpha(from: alpha, to: 1.0, duration: 0.25)
        
        super.touchesCancelled(touches, with: event)
    }
    
    func update(theme: PresentationTheme, title: String, compact: Bool) -> CGSize {
        let textConstrainedWidth: CGFloat = 100.0
        
        let needsVibrancy = !theme.overallDarkAppearance && compact
        
        let foregroundColor: UIColor
        let backgroundColor: UIColor
        
        if compact {
            foregroundColor = theme.chat.inputMediaPanel.panelContentVibrantOverlayColor
            backgroundColor = foregroundColor.withMultipliedAlpha(0.2)
        } else {
            foregroundColor = theme.list.itemCheckColors.foregroundColor
            backgroundColor = theme.list.itemCheckColors.fillColor
        }
        
        self.backgroundLayer.backgroundColor = backgroundColor.cgColor
        self.tintBackgroundLayer.backgroundColor = UIColor.black.withAlphaComponent(0.2).cgColor
        
        self.tintContainerLayer.isHidden = !needsVibrancy
        
        let textSize: CGSize
        if let currentTextLayout = self.currentTextLayout, currentTextLayout.string == title, currentTextLayout.color == foregroundColor, currentTextLayout.constrainedWidth == textConstrainedWidth {
            textSize = currentTextLayout.size
        } else {
            let font: UIFont = compact ? Font.medium(11.0) : Font.semibold(15.0)
            let string = NSAttributedString(string: title.uppercased(), font: font, textColor: foregroundColor)
            let tintString = NSAttributedString(string: title.uppercased(), font: font, textColor: .black)
            let stringBounds = string.boundingRect(with: CGSize(width: textConstrainedWidth, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
            textSize = CGSize(width: ceil(stringBounds.width), height: ceil(stringBounds.height))
            self.textLayer.contents = generateImage(textSize, opaque: false, scale: 0.0, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                UIGraphicsPushContext(context)
                
                string.draw(in: stringBounds)
                
                UIGraphicsPopContext()
            })?.cgImage
            self.tintTextLayer.contents = generateImage(textSize, opaque: false, scale: 0.0, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                UIGraphicsPushContext(context)
                
                tintString.draw(in: stringBounds)
                
                UIGraphicsPopContext()
            })?.cgImage
            self.currentTextLayout = (title, foregroundColor, textConstrainedWidth, textSize)
        }
        
        let size = CGSize(width: textSize.width + (compact ? 6.0 : 16.0) * 2.0, height: compact ? 16.0 : 28.0)
        
        let textFrame = CGRect(origin: CGPoint(x: floor((size.width - textSize.width) / 2.0), y: floorToScreenPixels((size.height - textSize.height) / 2.0)), size: textSize)
        self.textLayer.frame = textFrame
        self.tintTextLayer.frame = textFrame
        
        self.backgroundLayer.frame = CGRect(origin: CGPoint(), size: size)
        self.backgroundLayer.cornerRadius = min(size.width, size.height) / 2.0
        
        self.tintBackgroundLayer.frame = self.backgroundLayer.frame
        self.tintBackgroundLayer.cornerRadius = self.backgroundLayer.cornerRadius
        
        return size
    }
}
