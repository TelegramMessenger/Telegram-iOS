import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import TelegramPresentationData

private let knobBackgroundImage: UIImage? = {
    return generateImage(CGSize(width: 45.0, height: 45.0), contextGenerator: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        context.setShadow(offset: CGSize(width: 0.0, height: -1.5), blur: 4.5, color: UIColor(rgb: 0x000000, alpha: 0.4).cgColor)
        context.setFillColor(UIColor(rgb: 0x000000, alpha: 0.4).cgColor)
        context.fillEllipse(in: bounds.insetBy(dx: 3.0 + UIScreenPixel, dy: 3.0 + UIScreenPixel))
        
        context.setBlendMode(.normal)
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: bounds.insetBy(dx: 3.0, dy: 3.0))
    }, opaque: false, scale: nil)
}()

private let pointerImage: UIImage? = {
    return generateImage(CGSize(width: 12.0, height: 55.0), opaque: false, scale: nil, rotatedContext: { size, context in
        context.setBlendMode(.clear)
        context.setFillColor(UIColor.clear.cgColor)
        context.fill(CGRect(origin: CGPoint(), size: size))
        context.setBlendMode(.normal)
        
        let lineWidth: CGFloat = 1.0
        context.setFillColor(UIColor.black.cgColor)
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        let pointerHeight: CGFloat = 7.0
        context.move(to: CGPoint(x: lineWidth / 2.0, y: lineWidth / 2.0))
        context.addLine(to: CGPoint(x: size.width - lineWidth / 2.0, y: lineWidth / 2.0))
        context.addLine(to: CGPoint(x: size.width / 2.0, y: lineWidth / 2.0 + pointerHeight))
        context.closePath()
        context.drawPath(using: .fillStroke)
        
        context.move(to: CGPoint(x: lineWidth / 2.0, y: size.height - lineWidth / 2.0))
        context.addLine(to: CGPoint(x: size.width / 2.0, y: size.height - lineWidth / 2.0 - pointerHeight))
        context.addLine(to: CGPoint(x: size.width - lineWidth / 2.0, y: size.height - lineWidth / 2.0))
        context.closePath()
        context.drawPath(using: .fillStroke)
    })
}()

private let brightnessMaskImage: UIImage? = {
    return generateImage(CGSize(width: 36.0, height: 36.0), opaque: false, scale: nil, rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        
        context.setFillColor(UIColor.white.cgColor)
        context.fill(bounds)
        
        context.setBlendMode(.clear)
        context.setFillColor(UIColor.clear.cgColor)
        context.fillEllipse(in: bounds)
    })?.stretchableImage(withLeftCapWidth: 18, topCapHeight: 18)
}()

private let brightnessGradientImage: UIImage? = {
    return generateImage(CGSize(width: 160.0, height: 1.0), opaque: false, scale: nil, rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let gradientColors = [UIColor.black.withAlphaComponent(0.0), UIColor.black].map { $0.cgColor } as CFArray
        var locations: [CGFloat] = [0.0, 1.0]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: size.width, y: 0.0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    })
}()

private final class HSBParameter: NSObject {
    let hue: CGFloat
    let saturation: CGFloat
    let value: CGFloat
    
    init(hue: CGFloat, saturation: CGFloat, value: CGFloat) {
        self.hue = hue
        self.saturation = saturation
        self.value = value
        super.init()
    }
}

private final class WallpaperColorKnobNode: ASDisplayNode {
    var color: HSBColor = HSBColor(hue: 0.0, saturation: 0.0, brightness: 1.0) {
        didSet {
            if self.color != oldValue {
                self.colorNode.backgroundColor = self.color.color
            }
        }
    }
    
    private let backgroundNode: ASImageNode
    private let colorNode: ASDisplayNode
    
    override init() {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.image = knobBackgroundImage
        
        self.colorNode = ASDisplayNode()
        
        super.init()
        
        self.isUserInteractionEnabled = false
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.colorNode)
    }
    
    override func layout() {
        super.layout()
        
        self.backgroundNode.frame = self.bounds
        self.colorNode.frame = self.bounds.insetBy(dx: 7.0 - UIScreenPixel, dy: 7.0 - UIScreenPixel)
        self.colorNode.cornerRadius = self.colorNode.frame.width / 2.0
    }
}

private final class WallpaperColorHueSaturationNode: ASDisplayNode {
    var value: CGFloat = 1.0 {
        didSet {
            if self.value != oldValue {
                self.setNeedsDisplay()
            }
        }
    }
    
    override init() {
        super.init()
        
        self.isOpaque = true
        self.displaysAsynchronously = false
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return HSBParameter(hue: 1.0, saturation: 1.0, value: 1.0)
    }
    
    @objc override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        guard let parameters = parameters as? HSBParameter else {
            return
        }
        let context = UIGraphicsGetCurrentContext()!
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let colors = [UIColor(rgb: 0xff0000).cgColor, UIColor(rgb: 0xffff00).cgColor, UIColor(rgb: 0x00ff00).cgColor, UIColor(rgb: 0x00ffff).cgColor, UIColor(rgb: 0x0000ff).cgColor, UIColor(rgb: 0xff00ff).cgColor, UIColor(rgb: 0xff0000).cgColor]
        var locations: [CGFloat] = [0.0, 0.16667, 0.33333, 0.5, 0.66667, 0.83334, 1.0]
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: bounds.width, y: 0.0), options: CGGradientDrawingOptions())
        
        let overlayColors = [UIColor(rgb: 0xffffff, alpha: 0.0).cgColor, UIColor(rgb: 0xffffff).cgColor]
        var overlayLocations: [CGFloat] = [0.0, 1.0]
        let overlayGradient = CGGradient(colorsSpace: colorSpace, colors: overlayColors as CFArray, locations: &overlayLocations)!
        context.drawLinearGradient(overlayGradient, start: CGPoint(), end: CGPoint(x: 0.0, y: bounds.height), options: CGGradientDrawingOptions())
        
        context.setFillColor(UIColor(rgb: 0x000000, alpha: 1.0 - parameters.value).cgColor)
        context.fill(bounds)
    }
    
    var tap: ((CGPoint) -> Void)?
    var panBegan: ((CGPoint) -> Void)?
    var panChanged: ((CGPoint, Bool) -> Void)?
    
    var initialTouchLocation: CGPoint?
    var touchMoved = false
    var previousTouchLocation: CGPoint?
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        if let touchLocation = touches.first?.location(in: self.view) {
            self.touchMoved = false
            self.initialTouchLocation = touchLocation
            self.previousTouchLocation = nil
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)

        if let touchLocation = touches.first?.location(in: self.view), let initialLocation = self.initialTouchLocation {
            let dX = touchLocation.x - initialLocation.x
            let dY = touchLocation.y - initialLocation.y
            if !self.touchMoved && dX * dX + dY * dY > 3.0 {
                self.touchMoved = true
                self.panBegan?(touchLocation)
                self.previousTouchLocation = touchLocation
            } else if let previousTouchLocation = self.previousTouchLocation  {
                let dX = touchLocation.x - previousTouchLocation.x
                let dY = touchLocation.y - previousTouchLocation.y
                let translation = CGPoint(x: dX, y: dY)
            
                self.panChanged?(translation, false)
                self.previousTouchLocation = touchLocation
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        if self.touchMoved {
            if let touchLocation = touches.first?.location(in: self.view), let previousTouchLocation = self.previousTouchLocation {
                let dX = touchLocation.x - previousTouchLocation.x
                let dY = touchLocation.y - previousTouchLocation.y
                let translation = CGPoint(x: dX, y: dY)
            
                self.panChanged?(translation, true)
            }
        } else if let touchLocation = self.initialTouchLocation {
            self.tap?(touchLocation)
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
    }
}

private final class WallpaperColorBrightnessNode: ASDisplayNode {
    private let gradientNode: ASImageNode
    private let maskNode: ASImageNode
    
    var hsb: (CGFloat, CGFloat, CGFloat) = (0.0, 1.0, 1.0) {
        didSet {
            if self.hsb.0 != oldValue.0 || self.hsb.1 != oldValue.1 {
                let color = UIColor(hue: hsb.0, saturation: hsb.1, brightness: 1.0, alpha: 1.0)
                self.backgroundColor = color
            }
        }
    }
    
    override init() {
        self.gradientNode = ASImageNode()
        self.gradientNode.displaysAsynchronously = false
        self.gradientNode.displayWithoutProcessing = true
        self.gradientNode.image = brightnessGradientImage
        self.gradientNode.contentMode = .scaleToFill
        
        self.maskNode = ASImageNode()
        self.maskNode.displaysAsynchronously = false
        self.maskNode.displayWithoutProcessing = true
        self.maskNode.image = brightnessMaskImage
        self.maskNode.contentMode = .scaleToFill
        
        super.init()
        
        self.isOpaque = true
        self.addSubnode(self.gradientNode)
        self.addSubnode(self.maskNode)
    }
    
    override func layout() {
        super.layout()
        
        self.gradientNode.frame = self.bounds
        self.maskNode.frame = self.bounds
    }
}

struct HSBColor: Equatable {
    static func == (lhs: HSBColor, rhs: HSBColor) -> Bool {
        return lhs.values.h == rhs.values.h && lhs.values.s == rhs.values.s && lhs.values.b == rhs.values.b
    }
    
    let values: (h: CGFloat, s: CGFloat, b: CGFloat)
    let backingColor: UIColor
    
    var hue: CGFloat {
        return self.values.h
    }
    
    var saturation: CGFloat {
        return self.values.s
    }
    
    var brightness: CGFloat {
        return self.values.b
    }
    
    var rgb: UInt32 {
        return self.color.argb
    }
    
    init(values: (h: CGFloat, s: CGFloat, b: CGFloat)) {
        self.values = values
        self.backingColor = UIColor(hue: values.h, saturation: values.s, brightness: values.b, alpha: 1.0)
    }
    
    init(hue: CGFloat, saturation: CGFloat, brightness: CGFloat) {
        self.values = (h: hue, s: saturation, b: brightness)
        self.backingColor = UIColor(hue: self.values.h, saturation: self.values.s, brightness: self.values.b, alpha: 1.0)
    }
    
    init(color: UIColor) {
        self.values = color.hsb
        self.backingColor = color
    }
    
    init(rgb: UInt32) {
        self.init(color: UIColor(rgb: rgb))
    }
    
    var color: UIColor {
        return self.backingColor
    }
}

final class WallpaperColorPickerNode: ASDisplayNode {
    private let brightnessNode: WallpaperColorBrightnessNode
    private let brightnessKnobNode: ASImageNode
    private let colorNode: WallpaperColorHueSaturationNode
    private let colorKnobNode: WallpaperColorKnobNode
    
    private var validLayout: CGSize?
    
    var color: HSBColor = HSBColor(hue: 0.0, saturation: 1.0, brightness: 1.0) {
        didSet {
            if self.color != oldValue {
                self.update()
            }
        }
    }
    
    var colorChanged: ((HSBColor) -> Void)?
    var colorChangeEnded: ((HSBColor) -> Void)?
    
    init(strings: PresentationStrings) {
        self.brightnessNode = WallpaperColorBrightnessNode()
        self.brightnessNode.hitTestSlop = UIEdgeInsets(top: -16.0, left: -16.0, bottom: -16.0, right: -16.0)
        self.brightnessKnobNode = ASImageNode()
        self.brightnessKnobNode.image = pointerImage
        self.brightnessKnobNode.isUserInteractionEnabled = false
        self.colorNode = WallpaperColorHueSaturationNode()
        self.colorNode.hitTestSlop = UIEdgeInsets(top: -16.0, left: -16.0, bottom: -16.0, right: -16.0)
        self.colorKnobNode = WallpaperColorKnobNode()
        
        super.init()
        
        self.backgroundColor = .white
        
        self.addSubnode(self.brightnessNode)
        self.addSubnode(self.brightnessKnobNode)
        self.addSubnode(self.colorNode)
        self.addSubnode(self.colorKnobNode)
        
        self.update()
                
        self.colorNode.tap = { [weak self] location in
            guard let strongSelf = self, let size = strongSelf.validLayout else {
                return
            }
            
            let colorHeight = size.height - 66.0
            
            let newHue = max(0.0, min(1.0, location.x / size.width))
            let newSaturation = max(0.0, min(1.0, (1.0 - location.y / colorHeight)))
            strongSelf.color = HSBColor(hue: newHue, saturation: newSaturation, brightness: strongSelf.color.brightness)
            
            strongSelf.updateKnobLayout(size: size, panningColor: false, transition: .immediate)
            
            strongSelf.update()
            strongSelf.colorChangeEnded?(strongSelf.color)
        }
        
        self.colorNode.panBegan = { [weak self] location in
            guard let strongSelf = self, let size = strongSelf.validLayout else {
                return
            }
            
            let previousColor = strongSelf.color
            
            let colorHeight = size.height - 66.0

            let newHue = max(0.0, min(1.0, location.x / size.width))
            let newSaturation = max(0.0, min(1.0, (1.0 - location.y / colorHeight)))
            strongSelf.color = HSBColor(hue: newHue, saturation: newSaturation, brightness: strongSelf.color.brightness)
            
            strongSelf.updateKnobLayout(size: size, panningColor: true, transition: .immediate)
            
            if strongSelf.color != previousColor {
                strongSelf.colorChanged?(strongSelf.color)
            }
        }
        
        self.colorNode.panChanged = { [weak self] translation, ended in
            guard let strongSelf = self, let size = strongSelf.validLayout else {
                return
            }
            
            let previousColor = strongSelf.color
            
            let colorHeight = size.height - 66.0
            
            let newHue = max(0.0, min(1.0, strongSelf.color.hue + translation.x / size.width))
            let newSaturation = max(0.0, min(1.0, strongSelf.color.saturation - translation.y / colorHeight))
            strongSelf.color = HSBColor(hue: newHue, saturation: newSaturation, brightness: strongSelf.color.brightness)
            
            if ended {
                strongSelf.updateKnobLayout(size: size, panningColor: false, transition: .animated(duration: 0.3, curve: .easeInOut))
            } else {
                strongSelf.updateKnobLayout(size: size, panningColor: true, transition: .immediate)
            }
                
            if strongSelf.color != previousColor || ended {
                strongSelf.update()
                if ended {
                    strongSelf.colorChangeEnded?(strongSelf.color)
                } else {
                    strongSelf.colorChanged?(strongSelf.color)
                }
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
        self.view.disablesInteractiveModalDismiss = true
        
        let brightnessPanRecognizer = UIPanGestureRecognizer(target: self, action: #selector(WallpaperColorPickerNode.brightnessPan))
        self.brightnessNode.view.addGestureRecognizer(brightnessPanRecognizer)
    }
    
    private func update() {
        self.backgroundColor = .white
        self.colorNode.value = self.color.brightness
        self.brightnessNode.hsb = self.color.values
        self.colorKnobNode.color = self.color
    }
    
    private func updateKnobLayout(size: CGSize, panningColor: Bool, transition: ContainedViewLayoutTransition) {
        let knobSize = CGSize(width: 45.0, height: 45.0)
        
        let colorHeight = size.height - 66.0
        var colorKnobFrame = CGRect(x: floorToScreenPixels(-knobSize.width / 2.0 + size.width * self.color.hue), y: floorToScreenPixels(-knobSize.height / 2.0 + (colorHeight * (1.0 - self.color.saturation))), width: knobSize.width, height: knobSize.height)
        var origin = colorKnobFrame.origin
        if !panningColor {
            origin = CGPoint(x: max(0.0, min(origin.x, size.width - knobSize.width)), y: max(0.0, min(origin.y, colorHeight - knobSize.height)))
        } else {
            origin = origin.offsetBy(dx: 0.0, dy: -32.0)
        }
        colorKnobFrame.origin = origin
        transition.updateFrame(node: self.colorKnobNode, frame: colorKnobFrame)
        
        let inset: CGFloat = 15.0
        let brightnessKnobSize = CGSize(width: 12.0, height: 55.0)
        let brightnessKnobFrame = CGRect(x: inset - brightnessKnobSize.width / 2.0 + (size.width - inset * 2.0) * (1.0 - self.color.brightness), y: size.height - 65.0, width: brightnessKnobSize.width, height: brightnessKnobSize.height)
        transition.updateFrame(node: self.brightnessKnobNode, frame: brightnessKnobFrame)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        let colorHeight = size.height - 66.0
        transition.updateFrame(node: self.colorNode, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: colorHeight))
        
        let inset: CGFloat = 15.0
        transition.updateFrame(node: self.brightnessNode, frame: CGRect(x: inset, y: size.height - 55.0, width: size.width - inset * 2.0, height: 35.0))
        
        self.updateKnobLayout(size: size, panningColor: false, transition: .immediate)
    }
    
    @objc private func brightnessPan(_ recognizer: UIPanGestureRecognizer) {
        guard let size = self.validLayout else {
            return
        }
        
        let previousColor = self.color
        
        let transition = recognizer.translation(in: recognizer.view)
        let brightnessWidth: CGFloat = size.width - 42.0 * 2.0
        let newValue = max(0.0, min(1.0, self.color.brightness - transition.x / brightnessWidth))
        self.color = HSBColor(hue: self.color.hue, saturation: self.color.saturation, brightness: newValue)
                
        var ended = false
        switch recognizer.state {
            case .changed:
                self.updateKnobLayout(size: size, panningColor: false, transition: .immediate)
                recognizer.setTranslation(CGPoint(), in: recognizer.view)
            case .ended:
                self.updateKnobLayout(size: size, panningColor: false, transition: .immediate)
                ended = true
            default:
                break
        }
        
        if self.color != previousColor || ended {
            self.update()
            if ended {
                self.colorChangeEnded?(self.color)
            } else {
                self.colorChanged?(self.color)
            }
        }
    }
}
