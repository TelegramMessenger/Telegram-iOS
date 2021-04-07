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
    var hsb: (CGFloat, CGFloat, CGFloat) = (0.0, 0.0, 1.0) {
        didSet {
            if self.hsb != oldValue {
                let color = UIColor(hue: hsb.0, saturation: hsb.1, brightness: hsb.2, alpha: 1.0)
                self.colorNode.backgroundColor = color
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

final class WallpaperColorPickerNode: ASDisplayNode {
    private let brightnessNode: WallpaperColorBrightnessNode
    private let brightnessKnobNode: ASImageNode
    private let colorNode: WallpaperColorHueSaturationNode
    private let colorKnobNode: WallpaperColorKnobNode
    
    private var validLayout: CGSize?
    
    var colorHsb: (CGFloat, CGFloat, CGFloat) = (0.0, 1.0, 1.0)
    var color: UIColor {
        get {
            return UIColor(hue: self.colorHsb.0, saturation: self.colorHsb.1, brightness: self.colorHsb.2, alpha: 1.0)
        }
        set {
            let newHsb = newValue.hsb
            if newHsb != self.colorHsb {
                self.colorHsb = newHsb
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
        self.backgroundColor = .white
        self.colorNode.value = self.colorHsb.2
        self.brightnessNode.hsb = self.colorHsb
        self.colorKnobNode.hsb = self.colorHsb
    }
    
    private func updateKnobLayout(size: CGSize, panningColor: Bool, transition: ContainedViewLayoutTransition) {
        let knobSize = CGSize(width: 45.0, height: 45.0)
        
        let colorHeight = size.height - 66.0
        var colorKnobFrame = CGRect(x: floorToScreenPixels(-knobSize.width / 2.0 + size.width * self.colorHsb.0), y: floorToScreenPixels(-knobSize.height / 2.0 + (colorHeight * (1.0 - self.colorHsb.1))), width: knobSize.width, height: knobSize.height)
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
        let brightnessKnobFrame = CGRect(x: inset - brightnessKnobSize.width / 2.0 + (size.width - inset * 2.0) * (1.0 - self.colorHsb.2), y: size.height - 65.0, width: brightnessKnobSize.width, height: brightnessKnobSize.height)
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
    
    @objc private func colorTap(_ recognizer: UITapGestureRecognizer) {
        guard let size = self.validLayout, recognizer.state == .recognized else {
            return
        }
        
        let colorHeight = size.height - 66.0
        
        let location = recognizer.location(in: recognizer.view)
        let newHue = max(0.0, min(1.0, location.x / size.width))
        let newSaturation = max(0.0, min(1.0, (1.0 - location.y / colorHeight)))
        self.colorHsb.0 = newHue
        self.colorHsb.1 = newSaturation
        
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
            self.colorHsb.0 = newHue
            self.colorHsb.1 = newSaturation
        } else {
            let newHue = max(0.0, min(1.0, self.colorHsb.0 + transition.x / size.width))
            let newSaturation = max(0.0, min(1.0, self.colorHsb.1 - transition.y / (size.height - 66.0)))
            self.colorHsb.0 = newHue
            self.colorHsb.1 = newSaturation
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
        let newValue = max(0.0, min(1.0, self.colorHsb.2 - transition.x / brightnessWidth))
        self.colorHsb.2 = newValue
        
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
