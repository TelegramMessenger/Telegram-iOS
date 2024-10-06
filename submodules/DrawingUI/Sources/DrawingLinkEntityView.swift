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

private func generateIcon(style: DrawingLinkEntity.Style) -> UIImage? {
    guard let image = UIImage(bundleImageName: "Premium/Link") else {
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
                green = UIColor(rgb: 0x64d2ff)
                blue = UIColor(rgb: 0x64d2ff)
            } else {
                green = UIColor(rgb: 0x0a84ff)
                blue = UIColor(rgb: 0x0a84ff)
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

public final class DrawingLinkEntityView: DrawingEntityView, UITextViewDelegate {
    private var linkEntity: DrawingLinkEntity {
        return self.entity as! DrawingLinkEntity
    }
    
    let imageView: UIImageView
    
    let backgroundView: UIView
    let blurredBackgroundView: BlurredBackgroundView
    
    let textView: DrawingTextView
    let iconView: UIImageView
    private let imageNode: TransformImageNode
    
    private let cachedDisposable = MetaDisposable()
    
    init(context: AccountContext, entity: DrawingLinkEntity) {
        self.imageView = UIImageView()
        
        self.backgroundView = UIView()
        self.backgroundView.clipsToBounds = true
        
        self.blurredBackgroundView = BlurredBackgroundView(color: UIColor(white: 0.0, alpha: 0.25), enableBlur: true)
        self.blurredBackgroundView.clipsToBounds = true
        
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
        self.addSubview(self.imageView)
        self.addSubview(self.backgroundView)
        self.addSubview(self.blurredBackgroundView)
        self.addSubview(self.textView)
        self.addSubview(self.iconView)
        
        self.update(animated: false)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var textSize: CGSize = .zero
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        if self.linkEntity.webpage != nil, let image = self.linkEntity.whiteImage {
            self.imageView.frame = CGRect(origin: .zero, size: image.size)
            return image.size
        } else {
            var result = self.textView.sizeThatFits(CGSize(width: self.linkEntity.width, height: .greatestFiniteMagnitude))
            self.textSize = result
            
            let widthExtension = result.height * 0.65
            result.width = floorToScreenPixels(max(104.0, ceil(result.width) + 20.0) + widthExtension)
            result.height = ceil(result.height * 1.2);
            return result;
        }
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
        
        let iconSize: CGFloat
        let iconOffset: CGFloat
        iconSize = min(76.0, floor(self.bounds.height * 0.6))
        iconOffset = 0.3
        
        self.iconView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels(iconSize * iconOffset), y: floorToScreenPixels((self.bounds.height - iconSize) / 2.0)), size: CGSize(width: iconSize, height: iconSize))
        self.imageNode.frame = self.iconView.frame.offsetBy(dx: 0.0, dy: 2.0)
        
        let imageSize = CGSize(width: iconSize, height: iconSize)
        self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))()
        
        self.textView.frame = CGRect(origin: CGPoint(x: self.bounds.width - self.textSize.width - 6.0, y: floorToScreenPixels((self.bounds.height - self.textSize.height) / 2.0)), size: self.textSize)
        self.backgroundView.frame = self.bounds
        self.blurredBackgroundView.frame = self.bounds
        self.blurredBackgroundView.update(size: self.bounds.size, transition: .immediate)
    }
    
    override func selectedTapAction() -> Bool {
        let values = [self.entity.scale, self.entity.scale * 0.93, self.entity.scale]
        let keyTimes = [0.0, 0.33, 1.0]
        self.layer.animateKeyframes(values: values as [NSNumber], keyTimes: keyTimes as [NSNumber], duration: 0.3, keyPath: "transform.scale")
        
        let updatedStyle: DrawingLinkEntity.Style
        if self.linkEntity.webpage != nil {
            switch self.linkEntity.style {
            case .white:
                updatedStyle = .black
            default:
                updatedStyle = .white
            }
        } else {
            switch self.linkEntity.style {
            case .white:
                updatedStyle = .black
            case .black:
                updatedStyle = .transparent
            case .transparent:
                if self.linkEntity.hasCustomColor {
                    updatedStyle = .custom
                } else {
                    updatedStyle = .white
                }
            case .custom:
                updatedStyle = .white
            case .blur:
                updatedStyle = .white
            }
        }
        self.linkEntity.style = updatedStyle

        self.update()
        
        return true
    }
            
    private var displayFontSize: CGFloat {
        var textFontSize: CGFloat = 0.07
        let textLength = self.linkEntity.url.count
        if textLength > 10 {
            textFontSize = max(0.01, 0.07 - CGFloat(textLength - 10) / 100.0)
        }
        
        let minFontSize = max(10.0, max(self.linkEntity.referenceDrawingSize.width, self.linkEntity.referenceDrawingSize.height) * 0.025)
        let maxFontSize = max(10.0, max(self.linkEntity.referenceDrawingSize.width, self.linkEntity.referenceDrawingSize.height) * 0.25)
        let fontSize = minFontSize + (maxFontSize - minFontSize) * textFontSize
        return fontSize
    }
    
    private func updateText() {
        let string: String
        if !self.linkEntity.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            string = self.linkEntity.name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        } else {
            string = self.linkEntity.url.uppercased().replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "tonsite://", with: "")
        }
        let text = NSMutableAttributedString(string: string)
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
        switch self.linkEntity.style {
        case .white:
            textColor = UIColor(rgb: 0x0a84ff)
        case .black, .blur:
            textColor = UIColor(rgb: 0x64d2ff)
        case .transparent:
            textColor = .white
        case .custom:
            let color = self.linkEntity.color.toUIColor()
            if color.lightness > 0.705 {
                textColor = .black
            } else {
                textColor = .white
            }
        }
        
        text.addAttribute(.foregroundColor, value: textColor, range: range)
        
        self.textView.attributedText = text
        self.textView.visualText = text
    }
        
    private var currentStyle: DrawingLinkEntity.Style?
    public override func update(animated: Bool = false) {
        self.center = self.linkEntity.position
        self.transform = CGAffineTransformScale(CGAffineTransformMakeRotation(self.linkEntity.rotation), self.linkEntity.scale, self.linkEntity.scale)
        
        if self.linkEntity.webpage != nil {
            self.textView.isHidden = true
            self.backgroundView.isHidden = true
            self.blurredBackgroundView.isHidden = true
            self.iconView.isHidden = true
            
            if self.linkEntity.style == .white && self.imageView.image !== self.linkEntity.whiteImage {
                self.imageView.image = self.linkEntity.whiteImage
            } else if self.linkEntity.style == .black && self.imageView.image !== self.linkEntity.blackImage {
                self.imageView.image = self.linkEntity.blackImage
            }
        } else {
            self.textView.isHidden = false
            self.textView.frameInsets = UIEdgeInsets(top: 0.15, left: 0.0, bottom: 0.15, right: 0.0)
            switch self.linkEntity.style {
            case .white:
                self.textView.textColor = UIColor(rgb: 0x0a84ff)
                self.backgroundView.backgroundColor = .white
                self.backgroundView.isHidden = false
                self.blurredBackgroundView.isHidden = true
            case .black:
                self.textView.textColor = UIColor(rgb: 0x64d2ff)
                self.backgroundView.backgroundColor = .black
                self.backgroundView.isHidden = false
                self.blurredBackgroundView.isHidden = true
            case .transparent:
                self.textView.textColor = .white
                self.backgroundView.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.2)
                self.backgroundView.isHidden = false
                self.blurredBackgroundView.isHidden = true
            case .custom:
                let color = self.linkEntity.color.toUIColor()
                let textColor: UIColor
                if color.lightness > 0.705 {
                    textColor = .black
                } else {
                    textColor = .white
                }
                self.textView.textColor = textColor
                self.backgroundView.backgroundColor = color
                self.backgroundView.isHidden = false
                self.blurredBackgroundView.isHidden = true
            case .blur:
                self.textView.textColor = .white
                self.backgroundView.isHidden = true
                self.backgroundView.backgroundColor = UIColor(rgb: 0xffffff)
                self.blurredBackgroundView.isHidden = false
            }
            self.textView.textAlignment = .left
            
            self.updateText()
            
            self.iconView.isHidden = false
            if self.currentStyle != self.linkEntity.style {
                self.currentStyle = self.linkEntity.style
                self.iconView.image = generateIcon(style: self.linkEntity.style)
            }
            
            self.backgroundView.layer.cornerRadius = self.textSize.height * 0.2
            self.blurredBackgroundView.layer.cornerRadius = self.backgroundView.layer.cornerRadius
            if #available(iOS 13.0, *) {
                self.backgroundView.layer.cornerCurve = .continuous
                self.blurredBackgroundView.layer.cornerCurve = .continuous
            }
        }
        
        self.sizeToFit()
        
        super.update(animated: animated)
    }
    
    override func updateSelectionView() {
        guard let selectionView = self.selectionView as? DrawingLinkEntitySelectionView else {
            return
        }
        self.pushIdentityTransformForMeasurement()
     
        selectionView.transform = .identity
        let bounds = self.selectionBounds
        let center = bounds.center
        
        let scale = self.superview?.superview?.layer.value(forKeyPath: "transform.scale.x") as? CGFloat ?? 1.0
        selectionView.center = self.convert(center, to: selectionView.superview)
        
        selectionView.bounds = CGRect(origin: .zero, size: CGSize(width: (bounds.width * self.linkEntity.scale) * scale + selectionView.selectionInset * 2.0, height: (bounds.height * self.linkEntity.scale) * scale + selectionView.selectionInset * 2.0))
        selectionView.transform = CGAffineTransformMakeRotation(self.linkEntity.rotation)
        
        self.popIdentityTransformForMeasurement()
    }
        
    override func makeSelectionView() -> DrawingEntitySelectionView? {
        if let selectionView = self.selectionView {
            return selectionView
        }
        let selectionView = DrawingLinkEntitySelectionView()
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

final class DrawingLinkEntitySelectionView: DrawingEntitySelectionView {
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
        guard let entityView = self.entityView, let entity = entityView.entity as? DrawingLinkEntity else {
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
        guard let entityView = self.entityView as? DrawingLinkEntityView, let entity = entityView.entity as? DrawingLinkEntity else {
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
        guard let entityView = self.entityView as? DrawingLinkEntityView, let entity = entityView.entity as? DrawingLinkEntity else {
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
