import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import TelegramPresentationData

private let shadowImage: UIImage = {
    return generateImage(CGSize(width: 45.0, height: 45.0), opaque: false, scale: nil, rotatedContext: { size, context in
        context.setBlendMode(.clear)
        context.setFillColor(UIColor.clear.cgColor)
        context.fill(CGRect(origin: CGPoint(), size: size))
        context.setBlendMode(.normal)
        context.setShadow(offset: CGSize(width: 0.0, height: 1.5), blur: 4.5, color: UIColor(rgb: 0x000000, alpha: 0.5).cgColor)
        context.setFillColor(UIColor(rgb: 0x000000, alpha: 0.5).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: 3.0 + UIScreenPixel, dy: 3.0 + UIScreenPixel))
    })!
}()

private let pointerImage: UIImage = {
    return generateImage(CGSize(width: 12.0, height: 42.0), opaque: false, scale: nil, rotatedContext: { size, context in
        context.setBlendMode(.clear)
        context.setFillColor(UIColor.clear.cgColor)
        context.fill(CGRect(origin: CGPoint(), size: size))
        context.setBlendMode(.normal)
        
        let lineWidth: CGFloat = 1.0
        context.setFillColor(UIColor.black.cgColor)
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        
        let pointerHeight: CGFloat = 6.0
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
    })!
}()

private final class HSVParameter: NSObject {
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
    var hsv: (CGFloat, CGFloat, CGFloat) = (0.0, 0.0, 1.0) {
        didSet {
            if self.hsv != oldValue {
                self.setNeedsDisplay()
            }
        }
    }
    
    override init() {
        super.init()
        
        self.isOpaque = false
        self.displaysAsynchronously = false
        self.isUserInteractionEnabled = false
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return HSVParameter(hue: self.hsv.0, saturation: self.hsv.1, value: self.hsv.2)
    }
    
    @objc override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        guard let parameters = parameters as? HSVParameter else {
            return
        }
        let context = UIGraphicsGetCurrentContext()!
        
        if !isRasterizing {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fill(bounds)
        }
        
        context.draw(shadowImage.cgImage!, in: bounds)
        
        context.setBlendMode(.normal)
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: bounds.insetBy(dx: 3.0, dy: 3.0))
        
        let color = UIColor(hue: parameters.hue, saturation: parameters.saturation, brightness: parameters.value, alpha: 1.0)
        context.setFillColor(color.cgColor)
        
        let borderWidth: CGFloat = bounds.width > 30.0 ? 5.0 : 5.0
        context.fillEllipse(in: bounds.insetBy(dx: borderWidth - UIScreenPixel, dy: borderWidth - UIScreenPixel))
    }
}

private final class WallpaperColorHueSaturationNode: ASDisplayNode {
    var value: CGFloat = 1.0 {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    override init() {
        super.init()
        
        self.isOpaque = true
        self.displaysAsynchronously = false
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return HSVParameter(hue: 1.0, saturation: 1.0, value: self.value)
    }
    
    @objc override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        guard let parameters = parameters as? HSVParameter else {
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
}

private final class WallpaperColorBrightnessNode: ASDisplayNode {
    var hsv: (CGFloat, CGFloat, CGFloat) = (0.0, 1.0, 1.0) {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    override init() {
        super.init()
        
        self.isOpaque = true
        self.displaysAsynchronously = false
    }
    
    override func drawParameters(forAsyncLayer layer: _ASDisplayLayer) -> NSObjectProtocol? {
        return HSVParameter(hue: self.hsv.0, saturation: self.hsv.1, value: self.hsv.2)
    }
    
    @objc override class func draw(_ bounds: CGRect, withParameters parameters: Any?, isCancelled: () -> Bool, isRasterizing: Bool) {
        guard let parameters = parameters as? HSVParameter else {
            return
        }
        let context = UIGraphicsGetCurrentContext()!
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        context.setFillColor(UIColor(white: parameters.value, alpha: 1.0).cgColor)
        context.fill(bounds)
        
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: bounds.height / 2.0)
        context.addPath(path.cgPath)
        context.setFillColor(UIColor.white.cgColor)
        context.fillPath()
        
        let innerPath = UIBezierPath(roundedRect: bounds.insetBy(dx: 1.0, dy: 1.0), cornerRadius: bounds.height / 2.0)
        context.addPath(innerPath.cgPath)
        context.clip()
        
        let color = UIColor(hue: parameters.hue, saturation: parameters.saturation, brightness: 1.0, alpha: 1.0)
        let colors = [color.cgColor, UIColor.black.cgColor]
        var locations: [CGFloat] = [0.0, 1.0]
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: bounds.width, y: 0.0), options: CGGradientDrawingOptions())
    }
}

final class WallpaperColorPickerNode: ASDisplayNode {
    private let brightnessNode: WallpaperColorBrightnessNode
    private let brightnessKnobNode: ASImageNode
    private let colorNode: WallpaperColorHueSaturationNode
    private let colorKnobNode: WallpaperColorKnobNode
    
    private var validLayout: CGSize?
    
    var colorHSV: (CGFloat, CGFloat, CGFloat) = (0.0, 1.0, 1.0)
    var color: UIColor {
        get {
            return UIColor(hue: self.colorHSV.0, saturation: self.colorHSV.1, brightness: self.colorHSV.2, alpha: 1.0)
        }
        set {
            var hue: CGFloat = 0.0
            var saturation: CGFloat = 0.0
            var value: CGFloat = 0.0
            
            let newHSV: (CGFloat, CGFloat, CGFloat)
            if newValue.getHue(&hue, saturation: &saturation, brightness: &value, alpha: nil) {
                newHSV = (hue, saturation, value)
            } else {
                newHSV = (0.0, 0.0, 1.0)
            }
            
            if newHSV != self.colorHSV {
                self.colorHSV = newHSV
                self.update()
            }
        }
    }
    var colorChanged: ((UIColor) -> Void)?
    var colorChangeEnded: ((UIColor) -> Void)?
    
    init(strings: PresentationStrings) {
        self.brightnessNode = WallpaperColorBrightnessNode()
        self.brightnessNode.hitTestSlop = UIEdgeInsets(top: -16.0, left: -16.0, bottom: -16.0, right: -16.0)
        self.brightnessKnobNode = ASImageNode()
        self.brightnessKnobNode.image = pointerImage
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
    }
    
    override func didLoad() {
        super.didLoad()
        
        let colorPanRecognizer = UIPanGestureRecognizer(target: self, action: #selector(WallpaperColorPickerNode.colorPan))
        self.colorNode.view.addGestureRecognizer(colorPanRecognizer)
        
        let colorTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(WallpaperColorPickerNode.colorTap))
        self.colorNode.view.addGestureRecognizer(colorTapRecognizer)
        
        let brightnessPanRecognizer = UIPanGestureRecognizer(target: self, action: #selector(WallpaperColorPickerNode.brightnessPan))
        self.brightnessNode.view.addGestureRecognizer(brightnessPanRecognizer)
    }
    
    private func update() {
        self.backgroundColor = UIColor(white: self.colorHSV.2, alpha: 1.0)
        self.colorNode.value = self.colorHSV.2
        self.brightnessNode.hsv = self.colorHSV
        self.colorKnobNode.hsv = self.colorHSV
    }
    
    func updateKnobLayout(size: CGSize, panningColor: Bool, transition: ContainedViewLayoutTransition) {
        let knobSize = CGSize(width: 45.0, height: 45.0)
        
        let colorHeight = size.height - 66.0
        var colorKnobFrame = CGRect(x: -knobSize.width / 2.0 + size.width * self.colorHSV.0, y: -knobSize.height / 2.0 + (colorHeight * (1.0 - self.colorHSV.1)), width: knobSize.width, height: knobSize.height)
        var origin = colorKnobFrame.origin
        if !panningColor {
            origin = CGPoint(x: max(0.0, min(origin.x, size.width - knobSize.width)), y: max(0.0, min(origin.y, colorHeight - knobSize.height)))
        } else {
            origin = origin.offsetBy(dx: 0.0, dy: -32.0)
        }
        colorKnobFrame.origin = origin
        transition.updateFrame(node: self.colorKnobNode, frame: colorKnobFrame)
        
        let inset: CGFloat = 42.0
        let brightnessKnobSize = CGSize(width: 12.0, height: 42.0)
        let brightnessKnobFrame = CGRect(x: inset - brightnessKnobSize.width / 2.0 + (size.width - inset * 2.0) * (1.0 - self.colorHSV.2), y: size.height - 61.0, width: brightnessKnobSize.width, height: brightnessKnobSize.height)
        transition.updateFrame(node: self.brightnessKnobNode, frame: brightnessKnobFrame)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        let colorHeight = size.height - 66.0
        transition.updateFrame(node: self.colorNode, frame: CGRect(x: 0.0, y: 0.0, width: size.width, height: colorHeight))
        
        let inset: CGFloat = 42.0
        transition.updateFrame(node: self.brightnessNode, frame: CGRect(x: inset, y: size.height - 55.0, width: size.width - inset * 2.0, height: 29.0))
        
        self.updateKnobLayout(size: size, panningColor: false, transition: .immediate)
    }
    
    @objc private func colorTap(_ recognizer: UITapGestureRecognizer) {
        guard let size = self.validLayout, recognizer.state == .recognized else {
            return
        }
        
        let colorHeight = size.height - 66.0
        
        let location = recognizer.location(in: recognizer.view)
        let newHue = max(0.0, min(1.0, location.x / size.width))
        let newSaturation = max(0.0, min(1.0, (1.0 - location.y / colorHeight)))
        self.colorHSV.0 = newHue
        self.colorHSV.1 = newSaturation
        
        self.updateKnobLayout(size: size, panningColor: false, transition: .immediate)
        
        self.update()
        self.colorChangeEnded?(self.color)
    }
    
    @objc private func colorPan(_ recognizer: UIPanGestureRecognizer) {
        guard let size = self.validLayout else {
            return
        }
        
        let previousColor = self.color
        
        let colorHeight = size.height - 66.0
        
        let location = recognizer.location(in: recognizer.view)
        let transition = recognizer.translation(in: recognizer.view)
        if recognizer.state == .began {
            let newHue = max(0.0, min(1.0, location.x / size.width))
            let newSaturation = max(0.0, min(1.0, (1.0 - location.y / colorHeight)))
            self.colorHSV.0 = newHue
            self.colorHSV.1 = newSaturation
        } else {
            let newHue = max(0.0, min(1.0, self.colorHSV.0 + transition.x / size.width))
            let newSaturation = max(0.0, min(1.0, self.colorHSV.1 - transition.y / (size.height - 66.0)))
            self.colorHSV.0 = newHue
            self.colorHSV.1 = newSaturation
        }
        
        var ended = false
        switch recognizer.state {
            case .began:
                self.updateKnobLayout(size: size, panningColor: true, transition: .immediate)
            case .changed:
                self.updateKnobLayout(size: size, panningColor: true, transition: .immediate)
                recognizer.setTranslation(CGPoint(), in: recognizer.view)
            case .ended:
                self.updateKnobLayout(size: size, panningColor: false, transition: .animated(duration: 0.3, curve: .easeInOut))
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
    
    @objc private func brightnessPan(_ recognizer: UIPanGestureRecognizer) {
        guard let size = self.validLayout else {
            return
        }
        
        let previousColor = self.color
        
        let transition = recognizer.translation(in: recognizer.view)
        let brightnessWidth: CGFloat = size.width - 42.0 * 2.0
        let newValue = max(0.0, min(1.0, self.colorHSV.2 - transition.x / brightnessWidth))
        self.colorHSV.2 = newValue
        
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
