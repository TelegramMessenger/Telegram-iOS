import Foundation
import UIKit
import Display
import SwiftSignalKit
import AccountContext
import TelegramCore
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import StickerResources
import MediaEditor
import TelegramStringFormatting

private func generateIcon(style: DrawingWeatherEntity.Style) -> UIImage? {
    guard let image = UIImage(bundleImageName: "Chat/Attach Menu/Location") else {
        return nil
    }
    return generateImage(image.size, contextGenerator: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        
        if let cgImage = image.cgImage {
            context.clip(to: CGRect(origin: .zero, size: size), mask: cgImage)
        }
        if [.black, .white].contains(style) {
            let green: UIColor
            let blue: UIColor
            
            if case .black = style {
                green = UIColor(rgb: 0x3EF588)
                blue = UIColor(rgb: 0x4FAAFF)
            } else {
                green = UIColor(rgb: 0x1EBD5E)
                blue = UIColor(rgb: 0x1C92FF)
            }
            
            var locations: [CGFloat] = [0.0, 1.0]
            let colorsArray = [green.cgColor, blue.cgColor] as NSArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colorsArray, locations: &locations)!
            
            context.drawLinearGradient(gradient, start: CGPoint(x: size.width, y: size.height), end: CGPoint(x: 0.0, y: 0.0), options: CGGradientDrawingOptions())
        } else {
            context.setFillColor(UIColor.white.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
        }
    })
}

public final class DrawingWeatherEntityView: DrawingEntityView, UITextViewDelegate {
    private var weatherEntity: DrawingWeatherEntity {
        return self.entity as! DrawingWeatherEntity
    }
    
    let backgroundView: UIView
    
    let textView: DrawingTextView
    let iconView: UIImageView
    private let imageNode: TransformImageNode
    private var animationNode: AnimatedStickerNode?
    
    private var didSetUpAnimationNode = false
    private let stickerFetchedDisposable = MetaDisposable()
    private let cachedDisposable = MetaDisposable()
    
    let temperature: String
    
    init(context: AccountContext, entity: DrawingWeatherEntity) {
        self.temperature = stringForTemperature(entity.temperature)
        
        self.backgroundView = UIView()
        self.backgroundView.clipsToBounds = true
        
        self.textView = DrawingTextView(frame: .zero)
        self.textView.clipsToBounds = false
        
        self.textView.backgroundColor = .clear
        self.textView.isEditable = false
        self.textView.isSelectable = false
        self.textView.contentInset = .zero
        self.textView.showsHorizontalScrollIndicator = false
        self.textView.showsVerticalScrollIndicator = false
        self.textView.scrollsToTop = false
        self.textView.isScrollEnabled = false
        self.textView.textContainerInset = .zero
        self.textView.minimumZoomScale = 1.0
        self.textView.maximumZoomScale = 1.0
        self.textView.keyboardAppearance = .dark
        self.textView.autocorrectionType = .default
        self.textView.spellCheckingType = .no
        self.textView.textContainer.maximumNumberOfLines = 2
        self.textView.textContainer.lineBreakMode = .byTruncatingTail
        
        self.iconView = UIImageView()
        self.imageNode = TransformImageNode()
        
        super.init(context: context, entity: entity)
                
        self.textView.delegate = self
        self.addSubview(self.backgroundView)
        self.addSubview(self.textView)
        self.addSubview(self.iconView)
        
        self.update(animated: false)
        
        self.setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var textSize: CGSize = .zero
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        var result = self.textView.sizeThatFits(CGSize(width: self.weatherEntity.width, height: .greatestFiniteMagnitude))
        self.textSize = result
        
        let widthExtension: CGFloat = result.height * 0.7
        result.width = floorToScreenPixels(max(224.0, ceil(result.width) + 20.0) + widthExtension)
        result.height = ceil(result.height * 1.2);
        return result;
    }
    
    public override func sizeToFit() {
        let center = self.center
        let transform = self.transform
        self.transform = .identity
        super.sizeToFit()
        self.center = center
        self.transform = transform
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        let iconSize = min(80.0, floor(self.bounds.height * 0.7))
        let iconOffset: CGFloat = 0.3
   
        self.iconView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels(iconSize * iconOffset), y: floorToScreenPixels((self.bounds.height - iconSize) / 2.0)), size: CGSize(width: iconSize, height: iconSize))
        self.imageNode.frame = self.iconView.frame.offsetBy(dx: 0.0, dy: 2.0)
        
        if let animationNode = self.animationNode {
            animationNode.frame = self.iconView.frame
            animationNode.updateLayout(size: self.iconView.frame.size)
        }
        
        let imageSize = CGSize(width: iconSize, height: iconSize)
        self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))()
        
        self.textView.frame = CGRect(origin: CGPoint(x: self.bounds.width - self.textSize.width - 6.0, y: floorToScreenPixels((self.bounds.height - self.textSize.height) / 2.0)), size: self.textSize)
        self.backgroundView.frame = self.bounds
    }
    
    override func selectedTapAction() -> Bool {
        let values = [self.entity.scale, self.entity.scale * 0.93, self.entity.scale]
        let keyTimes = [0.0, 0.33, 1.0]
        self.layer.animateKeyframes(values: values as [NSNumber], keyTimes: keyTimes as [NSNumber], duration: 0.3, keyPath: "transform.scale")
        
        let updatedStyle: DrawingWeatherEntity.Style
        switch self.weatherEntity.style {
        case .white:
            updatedStyle = .black
        case .black:
            updatedStyle = .white
        }
        self.weatherEntity.style = updatedStyle

        self.update()
        
        return true
    }
        
    private var displayFontSize: CGFloat {
        var textFontSize: CGFloat = 0.07
        let textLength = self.temperature.count
        if textLength > 10 {
            textFontSize = max(0.01, 0.07 - CGFloat(textLength - 10) / 100.0)
        }
        
        let minFontSize = max(10.0, max(self.weatherEntity.referenceDrawingSize.width, self.weatherEntity.referenceDrawingSize.height) * 0.025)
        let maxFontSize = max(10.0, max(self.weatherEntity.referenceDrawingSize.width, self.weatherEntity.referenceDrawingSize.height) * 0.25)
        let fontSize = minFontSize + (maxFontSize - minFontSize) * textFontSize
        return fontSize
    }
    
    private func updateText() {
        let text = NSMutableAttributedString(string: self.temperature.uppercased())
        let range = NSMakeRange(0, text.length)
        let fontSize = self.displayFontSize
    
        self.textView.drawingLayoutManager.textContainers.first?.lineFragmentPadding = floor(fontSize * 0.24)
            
        let font = Font.with(size: fontSize, design: .camera, weight: .semibold)
        text.addAttribute(.font, value: font, range: range)
        text.addAttribute(.kern, value: -3.5 as NSNumber, range: range)
        self.textView.font = font
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        text.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        
        let textColor: UIColor
        switch self.weatherEntity.style {
        case .white:
            textColor = .black
        case .black:
            textColor = .white
        }
        
        text.addAttribute(.foregroundColor, value: textColor, range: range)
        
        self.textView.attributedText = text
        self.textView.visualText = text
    }
        
    private var currentStyle: DrawingWeatherEntity.Style?
    public override func update(animated: Bool = false) {
        self.center = self.weatherEntity.position
        self.transform = CGAffineTransformScale(CGAffineTransformMakeRotation(self.weatherEntity.rotation), self.weatherEntity.scale, self.weatherEntity.scale)
        
        self.textView.frameInsets = UIEdgeInsets(top: 0.15, left: 0.0, bottom: 0.15, right: 0.0)
        switch self.weatherEntity.style {
        case .white:
            self.textView.textColor = .black
            self.backgroundView.backgroundColor = .white
            self.backgroundView.isHidden = false
        case .black:
            self.textView.textColor = .white
            self.backgroundView.backgroundColor = .black
            self.backgroundView.isHidden = false
        }
        self.textView.textAlignment = .left
        
        self.updateText()
        
        self.sizeToFit()
        
        if self.currentStyle != self.weatherEntity.style {
            self.currentStyle = self.weatherEntity.style
            self.iconView.image = generateIcon(style: self.weatherEntity.style)
        }
        
        self.backgroundView.layer.cornerRadius = self.textSize.height * 0.2
        if #available(iOS 13.0, *) {
            self.backgroundView.layer.cornerCurve = .continuous
        }
        
        super.update(animated: animated)
    }
    
    private func setup() {
        if let file = self.weatherEntity.icon {
            self.iconView.isHidden = true
            self.addSubnode(self.imageNode)
            if let dimensions = file.dimensions {
                if file.isAnimatedSticker || file.isVideoSticker || file.mimeType == "video/webm" {
                    let fittedDimensions = dimensions.cgSize.aspectFitted(CGSize(width: 256.0, height: 256.0))
                    if self.animationNode == nil {
                        let animationNode = DefaultAnimatedStickerNodeImpl()
                        animationNode.autoplay = true
                        self.animationNode = animationNode
                        animationNode.started = { [weak self] in
                            self?.imageNode.isHidden = true
                        }
                        animationNode.setup(source: AnimatedStickerResourceSource(account: self.context.account, resource: file.resource, isVideo: file.isVideoSticker), width: Int(fittedDimensions.width), height: Int(fittedDimensions.height), playbackMode: .loop, mode: .direct(cachePathPrefix: nil))
                        
                        self.addSubnode(animationNode)
                    }
                    self.imageNode.setSignal(chatMessageAnimatedSticker(postbox: self.context.account.postbox, userLocation: .other, file: file, small: false, size: fittedDimensions))
                    self.stickerFetchedDisposable.set(freeMediaFileResourceInteractiveFetched(account: self.context.account, userLocation: .other, fileReference: stickerPackFileReference(file), resource: file.resource).start())
                } else {
                    if let animationNode = self.animationNode {
                        animationNode.visibility = false
                        self.animationNode = nil
                        animationNode.removeFromSupernode()
                        self.imageNode.isHidden = false
                        self.didSetUpAnimationNode = false
                    }
                    self.imageNode.setSignal(chatMessageSticker(account: self.context.account, userLocation: .other, file: file, small: false, synchronousLoad: false))
                    self.stickerFetchedDisposable.set(freeMediaFileResourceInteractiveFetched(account: self.context.account, userLocation: .other, fileReference: stickerPackFileReference(file), resource: chatMessageStickerResource(file: file, small: false)).start())
                }
                self.setNeedsLayout()
            }
        }
    }
    
    override func updateSelectionView() {
        guard let selectionView = self.selectionView as? DrawingWeatherEntitySelectionView else {
            return
        }
        self.pushIdentityTransformForMeasurement()
     
        selectionView.transform = .identity
        let bounds = self.selectionBounds
        let center = bounds.center
        
        let scale = self.superview?.superview?.layer.value(forKeyPath: "transform.scale.x") as? CGFloat ?? 1.0
        selectionView.center = self.convert(center, to: selectionView.superview)
        
        selectionView.bounds = CGRect(origin: .zero, size: CGSize(width: (bounds.width * self.weatherEntity.scale) * scale + selectionView.selectionInset * 2.0, height: (bounds.height * self.weatherEntity.scale) * scale + selectionView.selectionInset * 2.0))
        selectionView.transform = CGAffineTransformMakeRotation(self.weatherEntity.rotation)
        
        self.popIdentityTransformForMeasurement()
    }
        
    override func makeSelectionView() -> DrawingEntitySelectionView? {
        if let selectionView = self.selectionView {
            return selectionView
        }
        let selectionView = DrawingWeatherEntitySelectionView()
        selectionView.entityView = self
        return selectionView
    }
    
    func getRenderImage() -> UIImage? {
        let rect = self.bounds
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 2.0)
        self.drawHierarchy(in: rect, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    func getRenderSubEntities() -> [DrawingEntity] {
        return []
    }
}

final class DrawingWeatherEntitySelectionView: DrawingEntitySelectionView {
    private let border = SimpleShapeLayer()
    private let leftHandle = SimpleShapeLayer()
    private let rightHandle = SimpleShapeLayer()
    
    private var longPressGestureRecognizer: UILongPressGestureRecognizer?
    
    override init(frame: CGRect) {
        let handleBounds = CGRect(origin: .zero, size: entitySelectionViewHandleSize)
        let handles = [
            self.leftHandle,
            self.rightHandle
        ]
        
        super.init(frame: frame)
        
        self.backgroundColor = .clear
        self.isOpaque = false
        
        self.border.lineCap = .round
        self.border.fillColor = UIColor.clear.cgColor
        self.border.strokeColor = UIColor(rgb: 0xffffff, alpha: 0.75).cgColor
        self.layer.addSublayer(self.border)
        
        for handle in handles {
            handle.bounds = handleBounds
            handle.fillColor = UIColor(rgb: 0x0a60ff).cgColor
            handle.strokeColor = UIColor(rgb: 0xffffff).cgColor
            handle.rasterizationScale = UIScreen.main.scale
            handle.shouldRasterize = true
            
            self.layer.addSublayer(handle)
        }
                
        self.snapTool.onSnapUpdated = { [weak self] type, snapped in
            if let self, let entityView = self.entityView {
                entityView.onSnapUpdated(type, snapped)
            }
        }
        
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handleLongPress(_:)))
        self.addGestureRecognizer(longPressGestureRecognizer)
        self.longPressGestureRecognizer = longPressGestureRecognizer
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var scale: CGFloat = 1.0 {
        didSet {
            self.setNeedsLayout()
        }
    }
    
    override var selectionInset: CGFloat {
        return 15.0
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    private let snapTool = DrawingEntitySnapTool()
    
    @objc private func handleLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        if case .began = gestureRecognizer.state {
            self.longPressed()
        }
    }
    
    private var currentHandle: CALayer?
    override func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let entityView = self.entityView, let entity = entityView.entity as? DrawingWeatherEntity else {
            return
        }
        let location = gestureRecognizer.location(in: self)
        switch gestureRecognizer.state {
        case .began:
            self.tapGestureRecognizer?.isEnabled = false
            self.tapGestureRecognizer?.isEnabled = true
            
            self.longPressGestureRecognizer?.isEnabled = false
            self.longPressGestureRecognizer?.isEnabled = true
            
            self.snapTool.maybeSkipFromStart(entityView: entityView, position: entity.position)
            
            if let sublayers = self.layer.sublayers {
                for layer in sublayers {
                    if layer.frame.contains(location) {
                        self.currentHandle = layer
                        self.snapTool.maybeSkipFromStart(entityView: entityView, rotation: entity.rotation)
                        entityView.onInteractionUpdated(true)
                        return
                    }
                }
            }
            self.currentHandle = self.layer
            entityView.onInteractionUpdated(true)
        case .changed:
            if self.currentHandle == nil {
                self.currentHandle = self.layer
            }
            
            let delta = gestureRecognizer.translation(in: entityView.superview)
            let parentLocation = gestureRecognizer.location(in: self.superview)
            let velocity = gestureRecognizer.velocity(in: entityView.superview)
            
            var updatedScale = entity.scale
            var updatedPosition = entity.position
            var updatedRotation = entity.rotation
            
            if self.currentHandle === self.leftHandle || self.currentHandle === self.rightHandle {
                if gestureRecognizer.numberOfTouches > 1 {
                    return
                }
                var deltaX = gestureRecognizer.translation(in: self).x
                if self.currentHandle === self.leftHandle {
                    deltaX *= -1.0
                }
                let scaleDelta = (self.bounds.size.width + deltaX * 2.0) / self.bounds.size.width
                updatedScale = max(0.01, updatedScale * scaleDelta)
                
                let newAngle: CGFloat
                if self.currentHandle === self.leftHandle {
                    newAngle = atan2(self.center.y - parentLocation.y, self.center.x - parentLocation.x)
                } else {
                    newAngle = atan2(parentLocation.y - self.center.y, parentLocation.x - self.center.x)
                }
                var delta = newAngle - updatedRotation
                if delta < -.pi {
                    delta = 2.0 * .pi + delta
                }
                let velocityValue = sqrt(velocity.x * velocity.x + velocity.y * velocity.y) / 1000.0
                updatedRotation = self.snapTool.update(entityView: entityView, velocity: velocityValue, delta: delta, updatedRotation: newAngle, skipMultiplier: 1.0)
            } else if self.currentHandle === self.layer {
                updatedPosition.x += delta.x
                updatedPosition.y += delta.y
                
                updatedPosition = self.snapTool.update(entityView: entityView, velocity: velocity, delta: delta, updatedPosition: updatedPosition, size: entityView.frame.size)
            }
            
            entity.scale = updatedScale
            entity.position = updatedPosition
            entity.rotation = updatedRotation
            entityView.update()
            
            gestureRecognizer.setTranslation(.zero, in: entityView)
        case .ended, .cancelled:
            self.snapTool.reset()
            if self.currentHandle != nil {
                self.snapTool.rotationReset()
            }
            entityView.onInteractionUpdated(false)
        default:
            break
        }
        
        entityView.onPositionUpdated(entity.position)
    }
    
    override func handlePinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
        guard let entityView = self.entityView as? DrawingWeatherEntityView, let entity = entityView.entity as? DrawingWeatherEntity else {
            return
        }
        
        switch gestureRecognizer.state {
        case .began, .changed:
            if case .began = gestureRecognizer.state {
                entityView.onInteractionUpdated(true)
            }
            let scale = gestureRecognizer.scale
            entity.scale = max(0.1, entity.scale * scale)
            entityView.update()

            gestureRecognizer.scale = 1.0
        case .ended, .cancelled:
            entityView.onInteractionUpdated(false)
        default:
            break
        }
    }
    
    override func handleRotate(_ gestureRecognizer: UIRotationGestureRecognizer) {
        guard let entityView = self.entityView as? DrawingWeatherEntityView, let entity = entityView.entity as? DrawingWeatherEntity else {
            return
        }
        
        let velocity = gestureRecognizer.velocity
        var updatedRotation = entity.rotation
        var rotation: CGFloat = 0.0
        
        switch gestureRecognizer.state {
        case .began:
            self.snapTool.maybeSkipFromStart(entityView: entityView, rotation: entity.rotation)
            entityView.onInteractionUpdated(true)
        case .changed:
            rotation = gestureRecognizer.rotation
            updatedRotation += rotation
            
            updatedRotation = self.snapTool.update(entityView: entityView, velocity: velocity, delta: rotation, updatedRotation: updatedRotation)
            entity.rotation = updatedRotation
            entityView.update()
            
            gestureRecognizer.rotation = 0.0
        case .ended, .cancelled:
            self.snapTool.rotationReset()
            entityView.onInteractionUpdated(false)
        default:
            break
        }
        
        entityView.onPositionUpdated(entity.position)
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return self.bounds.insetBy(dx: -22.0, dy: -22.0).contains(point)
    }
    
    override func layoutSubviews() {
        let inset = self.selectionInset - 10.0

        let bounds = CGRect(origin: .zero, size: CGSize(width: entitySelectionViewHandleSize.width / self.scale, height: entitySelectionViewHandleSize.height / self.scale))
        let handleSize = CGSize(width: 9.0 / self.scale, height: 9.0 / self.scale)
        let handlePath = CGPath(ellipseIn: CGRect(origin: CGPoint(x: (bounds.width - handleSize.width) / 2.0, y: (bounds.height - handleSize.height) / 2.0), size: handleSize), transform: nil)
        let lineWidth = (1.0 + UIScreenPixel) / self.scale

        let handles = [
            self.leftHandle,
            self.rightHandle
        ]
        
        for handle in handles {
            handle.path = handlePath
            handle.bounds = bounds
            handle.lineWidth = lineWidth
        }
        
        self.leftHandle.position = CGPoint(x: inset, y: self.bounds.midY)
        self.rightHandle.position = CGPoint(x: self.bounds.maxX - inset, y: self.bounds.midY)
                
        let width: CGFloat = self.bounds.width - inset * 2.0
        let height: CGFloat = self.bounds.height - inset * 2.0
        let cornerRadius: CGFloat = 12.0 - self.scale
        
        let perimeter: CGFloat = 2.0 * (width + height - cornerRadius * (4.0 - .pi))
        let count = 12
        let relativeDashLength: CGFloat = 0.25
        let dashLength = perimeter / CGFloat(count)
        self.border.lineDashPattern = [dashLength * relativeDashLength, dashLength * relativeDashLength] as [NSNumber]
        
        self.border.lineWidth = 2.0 / self.scale
        self.border.path = UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: inset, y: inset), size: CGSize(width: width, height: height)), cornerRadius: cornerRadius).cgPath
    }
}
