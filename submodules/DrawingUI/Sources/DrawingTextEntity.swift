import Foundation
import UIKit
import Display
import AccountContext

final class DrawingTextEntity: DrawingEntity {
    enum Style {
        case regular
        case filled
        case semi
        case stroke
        
        init(style: DrawingTextEntity.Style) {
            switch style {
            case .regular:
                self = .regular
            case .filled:
                self = .filled
            case .semi:
                self = .semi
            case .stroke:
                self = .stroke
            }
        }
    }
    
    enum Font {
        case sanFrancisco
        case newYork
        case monospaced
        case round
        
        init(font: DrawingTextEntity.Font) {
            switch font {
            case .sanFrancisco:
                self = .sanFrancisco
            case .newYork:
                self = .newYork
            case .monospaced:
                self = .monospaced
            case .round:
                self = .round
            }
        }
    }
    
    enum Alignment {
        case left
        case center
        case right
        
        init(font: DrawingTextEntity.Alignment) {
            switch font {
            case .left:
                self = .left
            case .center:
                self = .center
            case .right:
                self = .right
            }
        }
        
        var alignment: NSTextAlignment {
            switch self {
            case .left:
                return .left
            case .center:
                return .center
            case .right:
                return .right
            }
        }
    }
    
    var uuid: UUID
    let isAnimated: Bool
    
    var text: String
    var style: Style
    var font: Font
    var alignment: Alignment
    var fontSize: CGFloat
    var color: DrawingColor
    var lineWidth: CGFloat = 0.0
    
    var referenceDrawingSize: CGSize
    var position: CGPoint
    var width: CGFloat
    var rotation: CGFloat
    
    init(text: String, style: Style, font: Font, alignment: Alignment, fontSize: CGFloat, color: DrawingColor) {
        self.uuid = UUID()
        self.isAnimated = false
        
        self.text = text
        self.style = style
        self.font = font
        self.alignment = alignment
        self.fontSize = fontSize
        self.color = color
        
        self.referenceDrawingSize = .zero
        self.position = .zero
        self.width = 100.0
        self.rotation = 0.0
    }
    
    var center: CGPoint {
        return self.position
    }
    
    func duplicate() -> DrawingEntity {
        let newEntity = DrawingTextEntity(text: self.text, style: self.style, font: self.font, alignment: self.alignment, fontSize: self.fontSize, color: self.color)
        newEntity.referenceDrawingSize = self.referenceDrawingSize
        newEntity.position = self.position
        newEntity.width = self.width
        newEntity.rotation = self.rotation
        return newEntity
    }
    
    weak var currentEntityView: DrawingEntityView?
    func makeView(context: AccountContext) -> DrawingEntityView {
        let entityView = DrawingTextEntityView(context: context, entity: self)
        self.currentEntityView = entityView
        return entityView
    }
}

final class DrawingTextEntityView: DrawingEntityView, UITextViewDelegate {
    private var textEntity: DrawingTextEntity {
        return self.entity as! DrawingTextEntity
    }
    
    private let textView: DrawingTextView
    
    init(context: AccountContext, entity: DrawingTextEntity) {
        self.textView = DrawingTextView(frame: .zero)
        self.textView.clipsToBounds = false
        
        self.textView.backgroundColor = .clear
        self.textView.text = entity.text
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
        self.textView.autocorrectionType = .no
        self.textView.spellCheckingType = .no
        
        super.init(context: context, entity: entity)
        
        self.textView.delegate = self
        self.addSubview(self.textView)
        
        self.update(animated: false)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var isSuspended = false
    private var _isEditing = false
    var isEditing: Bool {
        return self._isEditing || self.isSuspended
    }
    
    private var previousEntity: DrawingTextEntity?
    private var fadeView: UIView?
    
    @objc private func fadePressed() {
        self.endEditing()
    }
    
    func beginEditing(accessoryView: UIView?) {
        self._isEditing = true
        if !self.textEntity.text.isEmpty {
            let previousEntity = self.textEntity.duplicate() as? DrawingTextEntity
            previousEntity?.uuid = self.textEntity.uuid
            self.previousEntity = previousEntity
        }
        
        self.update(animated: false)
        
        if let superview = self.superview {
            let fadeView = UIButton(frame: CGRect(origin: .zero, size: superview.frame.size))
            fadeView.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.4)
            fadeView.addTarget(self, action: #selector(self.fadePressed), for: .touchUpInside)
            superview.insertSubview(fadeView, belowSubview: self)
            self.fadeView = fadeView
            fadeView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        }
        
        self.textView.inputAccessoryView = accessoryView
        
        self.textView.isEditable = true
        self.textView.isSelectable = true
        
        self.textView.window?.makeKey()
        self.textView.becomeFirstResponder()
        
        UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.0) {
            self.transform = .identity
            if let superview = self.superview {
                self.center = CGPoint(x: superview.bounds.width / 2.0, y: superview.bounds.height / 2.0)
            }
        }

        if let selectionView = self.selectionView as? DrawingTextEntititySelectionView {
            selectionView.alpha = 0.0
            if !self.textEntity.text.isEmpty {
                selectionView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
            }
        }
    }
    
    func endEditing(reset: Bool = false) {
        self._isEditing = false
        self.textView.resignFirstResponder()
        
        self.textView.isEditable = false
        self.textView.isSelectable = false
        
        if reset {
            if let previousEntity = self.previousEntity {
                self.textEntity.color = previousEntity.color
                self.textEntity.style = previousEntity.style
                self.textEntity.alignment = previousEntity.alignment
                self.textEntity.font = previousEntity.font
                self.textEntity.text = previousEntity.text
                
                self.previousEntity = nil
            } else {
                self.containerView?.remove(uuid: self.textEntity.uuid)
            }
        } else {
            self.textEntity.text = self.textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if self.textEntity.text.isEmpty {
                self.containerView?.remove(uuid: self.textEntity.uuid)
            }
        }
        
        self.textView.text = self.textEntity.text
        
        if let fadeView = self.fadeView {
            self.fadeView = nil
            fadeView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak fadeView] _ in
                fadeView?.removeFromSuperview()
            })
        }
        
        UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.0) {
            self.transform = CGAffineTransformMakeRotation(self.textEntity.rotation)
            self.center = self.textEntity.position
        }
        self.update(animated: false)
        
        if let selectionView = self.selectionView as? DrawingTextEntititySelectionView {
            selectionView.alpha = 1.0
            selectionView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        }
    }
    
    func suspendEditing() {
        self.isSuspended = true
        self.textView.resignFirstResponder()
        
        if let fadeView = self.fadeView {
            fadeView.alpha = 0.0
            fadeView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
        }
    }
    
    func resumeEditing() {
        self.isSuspended = false
        self.textView.becomeFirstResponder()
        
        if let fadeView = self.fadeView {
            fadeView.alpha = 1.0
            fadeView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        }
    }
    
    func textViewDidChange(_ textView: UITextView) {
        self.sizeToFit()
        self.textView.setNeedsDisplay()
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        var result = self.textView.sizeThatFits(CGSize(width: self.textEntity.width, height: .greatestFiniteMagnitude))
        result.width = max(224.0, ceil(result.width) + 20.0)
        result.height = ceil(result.height) //+ 20.0 + (self.textView.font?.pointSize ?? 0.0) // * _font.sizeCorrection;
        return result;
    }
    
    override func sizeToFit() {
        let center = self.center
        let transform = self.transform
        self.transform = .identity
        super.sizeToFit()
        self.center = center
        self.transform = transform
        
        //entity changed
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        var rect = self.bounds
//        CGFloat correction = _textView.font.pointSize * _font.sizeCorrection;
//        rect.origin.y += correction;
//        rect.size.height -= correction;
        rect = rect.offsetBy(dx: 0.0, dy: 10.0) // CGRectOffset(rect, 0.0f, 10.0f);
        self.textView.frame = rect
    }
        
    override func update(animated: Bool = false) {
        if !self.isEditing {
            self.center = self.textEntity.position
            self.transform = CGAffineTransformMakeRotation(self.textEntity.rotation)
        }
        
        let minFontSize = max(10.0, min(self.textEntity.referenceDrawingSize.width, self.textEntity.referenceDrawingSize.height) * 0.05)
        let maxFontSize = max(10.0, min(self.textEntity.referenceDrawingSize.width, self.textEntity.referenceDrawingSize.height) * 0.45)
        let fontSize = minFontSize + (maxFontSize - minFontSize) * self.textEntity.fontSize
                
        switch self.textEntity.font {
        case .sanFrancisco:
            self.textView.font = Font.with(size: fontSize, design: .regular, weight: .semibold)
        case .newYork:
            self.textView.font = Font.with(size: fontSize, design: .serif, weight: .semibold)
        case .monospaced:
            self.textView.font = Font.with(size: fontSize, design: .monospace, weight: .semibold)
        case .round:
            self.textView.font = Font.with(size: fontSize, design: .round, weight: .semibold)
        }
        self.textView.textAlignment = self.textEntity.alignment.alignment
        
        let color = self.textEntity.color.toUIColor()
        switch self.textEntity.style {
        case .regular:
            self.textView.textColor = color
            self.textView.strokeColor = nil
            self.textView.frameColor = nil
        case .filled:
            self.textView.textColor = color.lightness > 0.99 ? UIColor.black : UIColor.white
            self.textView.strokeColor = nil
            self.textView.frameColor = color
        case .semi:
            self.textView.textColor = color
            self.textView.strokeColor = nil
            self.textView.frameColor = UIColor(rgb: 0xffffff, alpha: 0.75)
        case .stroke:
            self.textView.textColor =  color.lightness > 0.99 ? UIColor.black : UIColor.white
            self.textView.strokeColor = color
            self.textView.frameColor = nil
        }
        
        if case .regular = self.textEntity.style {
            self.textView.layer.shadowColor = UIColor.black.cgColor
            self.textView.layer.shadowOffset = CGSize(width: 0.0, height: 4.0)
            self.textView.layer.shadowOpacity = 0.4
            self.textView.layer.shadowRadius = 4.0
        } else {
            self.textView.layer.shadowColor = nil
            self.textView.layer.shadowOffset = .zero
            self.textView.layer.shadowOpacity = 0.0
            self.textView.layer.shadowRadius = 0.0
        }
        
        self.sizeToFit()
        
        super.update(animated: animated)
    }
    
    override func updateSelectionView() {
        super.updateSelectionView()
        
        guard let selectionView = self.selectionView as? DrawingTextEntititySelectionView else {
            return
        }
        
//        let scale = self.superview?.superview?.layer.value(forKeyPath: "transform.scale.x") as? CGFloat ?? 1.0
//        selectionView.scale = scale
        
        selectionView.transform = CGAffineTransformMakeRotation(self.textEntity.rotation)
    }
        
    override func makeSelectionView() -> DrawingEntitySelectionView {
        if let selectionView = self.selectionView {
            return selectionView
        }
        let selectionView = DrawingTextEntititySelectionView()
        selectionView.entityView = self
        return selectionView
    }
    
    func getRenderImage() -> UIImage? {
        let rect = self.bounds
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 1.0)
        self.drawHierarchy(in: rect, afterScreenUpdates: false)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}

final class DrawingTextEntititySelectionView: DrawingEntitySelectionView, UIGestureRecognizerDelegate {
    private let border = SimpleShapeLayer()
    private let leftHandle = SimpleShapeLayer()
    private let rightHandle = SimpleShapeLayer()
    
    private var panGestureRecognizer: UIPanGestureRecognizer!
    
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
        self.border.strokeColor = UIColor(rgb: 0xffffff, alpha: 0.5).cgColor
        self.layer.addSublayer(self.border)
        
        for handle in handles {
            handle.bounds = handleBounds
            handle.fillColor = UIColor(rgb: 0x0a60ff).cgColor
            handle.strokeColor = UIColor(rgb: 0xffffff).cgColor
            handle.rasterizationScale = UIScreen.main.scale
            handle.shouldRasterize = true
            
            self.layer.addSublayer(handle)
        }
        
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
        panGestureRecognizer.delegate = self
        self.addGestureRecognizer(panGestureRecognizer)
        self.panGestureRecognizer = panGestureRecognizer
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
    
    private var currentHandle: CALayer?
    @objc private func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let entityView = self.entityView, let entity = entityView.entity as? DrawingTextEntity else {
            return
        }
        let location = gestureRecognizer.location(in: self)
        
        switch gestureRecognizer.state {
        case .began:
            if let sublayers = self.layer.sublayers {
                for layer in sublayers {
                    if layer.frame.contains(location) {
                        self.currentHandle = layer
                        return
                    }
                }
            }
            self.currentHandle = self.layer
        case .changed:
            let delta = gestureRecognizer.translation(in: entityView.superview)
            let parentLocation = gestureRecognizer.location(in: self.superview)
            
            var updatedFontSize = entity.fontSize
            var updatedPosition = entity.position
            var updatedRotation = entity.rotation
            
            if self.currentHandle === self.leftHandle || self.currentHandle === self.rightHandle {
                var deltaX = gestureRecognizer.translation(in: self).x
                if self.currentHandle === self.leftHandle {
                    deltaX *= -1.0
                }
                let scaleDelta = (self.bounds.size.width + deltaX * 2.0) / self.bounds.size.width
                updatedFontSize = max(0.0, min(1.0, updatedFontSize * scaleDelta))
                
                let deltaAngle: CGFloat
                if self.currentHandle === self.leftHandle {
                    deltaAngle = atan2(self.center.y - parentLocation.y, self.center.x - parentLocation.x)
                } else {
                    deltaAngle = atan2(parentLocation.y - self.center.y, parentLocation.x - self.center.x)
                }
                updatedRotation = deltaAngle
            } else if self.currentHandle === self.layer {
                updatedPosition.x += delta.x
                updatedPosition.y += delta.y
            }
            
            entity.fontSize = updatedFontSize
            entity.position = updatedPosition
            entity.rotation = updatedRotation
            entityView.update()
            
            gestureRecognizer.setTranslation(.zero, in: entityView)
        case .ended:
            break
        default:
            break
        }
    }
    
    override func handlePinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
        guard let entityView = self.entityView, let entity = entityView.entity as? DrawingTextEntity else {
            return
        }

        switch gestureRecognizer.state {
        case .began, .changed:
            let scale = gestureRecognizer.scale
            entity.fontSize = max(0.0, min(1.0, entity.fontSize * scale))
            entityView.update()

            gestureRecognizer.scale = 1.0
        default:
            break
        }
    }
    
    override func handleRotate(_ gestureRecognizer: UIRotationGestureRecognizer) {
        guard let entityView = self.entityView, let entity = entityView.entity as? DrawingTextEntity else {
            return
        }
        
        switch gestureRecognizer.state {
        case .began, .changed:
            let rotation = gestureRecognizer.rotation
            entity.rotation += rotation
            entityView.update()
            
            gestureRecognizer.rotation = 0.0
        default:
            break
        }
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
        
        self.border.lineDashPattern = [12.0 / self.scale as NSNumber, 12.0 / self.scale as NSNumber]
        self.border.lineWidth = 2.0 / self.scale
        self.border.path = UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: inset, y: inset), size: CGSize(width: self.bounds.width - inset * 2.0, height: self.bounds.height - inset * 2.0)), cornerRadius: 12.0 / self.scale).cgPath
    }
}

private class DrawingTextLayoutManager: NSLayoutManager {
    var radius: CGFloat
    var maxIndex: Int = 0
    
    private(set) var path: UIBezierPath?
    var rectArray: [CGRect] = []
    
    var strokeColor: UIColor?
    var strokeWidth: CGFloat = 0.0
    var strokeOffset: CGPoint = .zero
    
    var frameColor: UIColor?
    var frameWidthInset: CGFloat = 0.0
    
    override init() {
        self.radius = 8.0
        
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    private func prepare() {
        self.path = nil
        self.rectArray.removeAll()
        
        self.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: ((self.textStorage?.string ?? "") as NSString).length)) { rect, usedRect, textContainer, glyphRange, _ in
            var ignoreRange = false
            let charecterRange = self.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            let substring = ((self.textStorage?.string ?? "") as NSString).substring(with: charecterRange)
            if substring.trimmingCharacters(in: .newlines).isEmpty {
                ignoreRange = true
            }
            
            if !ignoreRange {
                let newRect = CGRect(origin: CGPoint(x: usedRect.minX - self.frameWidthInset, y: usedRect.minY), size: CGSize(width: usedRect.width + self.frameWidthInset * 2.0, height: usedRect.height))
                self.rectArray.append(newRect)
            }
        }
        
        self.preprocess()
    }
    
    private func preprocess() {
        self.maxIndex = 0
        if self.rectArray.count < 2 {
            return
        }
        for i in 1 ..< self.rectArray.count {
            self.maxIndex = i
            self.processRectIndex(i)
        }
    }
    
    private func processRectIndex(_ index: Int) {
        guard self.rectArray.count >= 2 && index > 0 && index <= self.maxIndex else {
            return
        }
        
        let last = self.rectArray[index - 1]
        let cur = self.rectArray[index]
        
        self.radius = cur.height * 0.18
        
        let t1 = ((cur.minX - last.minX < 2.0 * self.radius) && (cur.minX > last.minX)) || ((cur.maxX - last.maxX > -2.0 * self.radius) && (cur.maxX < last.maxX))
        let t2 = ((last.minX - cur.minX < 2.0 * self.radius) && (last.minX > cur.minX)) || ((last.maxX - cur.maxX > -2.0 * self.radius) && (last.maxX < cur.maxX))
        
        if t2 {
            let newRect = CGRect(origin: CGPoint(x: cur.minX, y: last.minY), size: CGSize(width: cur.width, height: last.height))
            self.rectArray[index - 1] = newRect
            self.processRectIndex(index - 1)
        }
        if t1 {
            let newRect = CGRect(origin: CGPoint(x: last.minX, y: cur.minY), size: CGSize(width: last.width, height: cur.height))
            self.rectArray[index] = newRect
            self.processRectIndex(index + 1)
        }
    }
    
    override func showCGGlyphs(_ glyphs: UnsafePointer<CGGlyph>, positions: UnsafePointer<CGPoint>, count glyphCount: Int, font: UIFont, matrix textMatrix: CGAffineTransform, attributes: [NSAttributedString.Key : Any] = [:], in graphicsContext: CGContext) {
        if let strokeColor = self.strokeColor {
            graphicsContext.setStrokeColor(strokeColor.cgColor)
            graphicsContext.setLineJoin(.round)
            
            let lineWidth = self.strokeWidth > 0.0 ? self.strokeWidth : font.pointSize / 9.0
            graphicsContext.setLineWidth(lineWidth)
            graphicsContext.setTextDrawingMode(.stroke)
            
            graphicsContext.saveGState()
            graphicsContext.translateBy(x: self.strokeOffset.x, y: self.strokeOffset.y)
            
            super.showCGGlyphs(glyphs, positions: positions, count: glyphCount, font: font, matrix: textMatrix, attributes: attributes, in: graphicsContext)
            
            graphicsContext.restoreGState()
            
            let textColor: UIColor = attributes[NSAttributedString.Key.foregroundColor] as? UIColor ?? UIColor.white
            
            graphicsContext.setFillColor(textColor.cgColor)
            graphicsContext.setTextDrawingMode(.fill)
        }
        super.showCGGlyphs(glyphs, positions: positions, count: glyphCount, font: font, matrix: textMatrix, attributes: attributes, in: graphicsContext)
    }
    
    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        if let frameColor = self.frameColor, let context = UIGraphicsGetCurrentContext() {
            context.saveGState()
            
            context.translateBy(x: origin.x, y: origin.y)
            
            context.setBlendMode(.normal)
            context.setFillColor(frameColor.cgColor)
            context.setStrokeColor(frameColor.cgColor)
            
            self.prepare()
            self.preprocess()
            
            let path = UIBezierPath()
            
            var last: CGRect = .null
            for i in 0 ..< self.rectArray.count {
                let cur = self.rectArray[i]
                self.radius = cur.height * 0.18
                
                path.append(UIBezierPath(roundedRect: cur, cornerRadius: self.radius))
                if i == 0 {
                    last = cur
                } else if i > 0 && abs(last.maxY -  cur.minY) < 10.0 {
                    let a = cur.origin
                    let b = CGPoint(x: cur.maxX, y: cur.minY)
                    let c = CGPoint(x: last.minX, y: last.maxY)
                    let d = CGPoint(x: last.maxX, y: last.maxY)
                    
                    if a.x - c.x >= 2.0 * self.radius {
                        let addPath = UIBezierPath(arcCenter: CGPoint(x: a.x - self.radius, y: a.y + self.radius), radius: self.radius, startAngle: .pi * 0.5 * 3.0, endAngle: 0.0, clockwise: true)
                        addPath.append(
                            UIBezierPath(arcCenter: CGPoint(x: a.x + self.radius, y: a.y + self.radius), radius: self.radius, startAngle: .pi, endAngle: 3.0 * .pi * 0.5, clockwise: true)
                        )
                        addPath.addLine(to: CGPoint(x: a.x - self.radius, y: a.y))
                        path.append(addPath)
                    }
                    if a.x == c.x {
                        path.move(to: CGPoint(x: a.x, y: a.y - self.radius))
                        path.addLine(to: CGPoint(x: a.x, y: a.y + self.radius))
                        path.addArc(withCenter: CGPoint(x: a.x + self.radius, y: a.y + self.radius), radius: self.radius, startAngle: .pi, endAngle: .pi * 0.5 * 3.0, clockwise: true)
                        path.addArc(withCenter: CGPoint(x: a.x + self.radius, y: a.y - self.radius), radius: self.radius, startAngle: .pi * 0.5, endAngle: .pi, clockwise: true)
                    }
                    if d.x - b.x >= 2.0 * self.radius {
                        let addPath = UIBezierPath(arcCenter: CGPoint(x: b.x + self.radius, y: b.y + self.radius), radius: self.radius, startAngle: .pi * 0.5 * 3.0, endAngle: .pi, clockwise: false)
                        addPath.append(
                            UIBezierPath(arcCenter: CGPoint(x: b.x - self.radius, y: b.y + self.radius), radius: self.radius, startAngle: 0.0, endAngle: 3.0 * .pi * 0.5, clockwise: false)
                        )
                        addPath.addLine(to: CGPoint(x: b.x + self.radius, y: b.y))
                        path.append(addPath)
                    }
                    if d.x == b.x {
                        path.move(to: CGPoint(x: b.x, y: b.y - self.radius))
                        path.addLine(to: CGPoint(x: b.x, y: b.y + self.radius))
                        path.addArc(withCenter: CGPoint(x: b.x - self.radius, y: b.y + self.radius), radius: self.radius, startAngle: 0.0, endAngle: 3.0 * .pi * 0.5, clockwise: false)
                        path.addArc(withCenter: CGPoint(x: b.x - self.radius, y: b.y - self.radius), radius: self.radius, startAngle: .pi * 0.5, endAngle: 0.0, clockwise: false)
                    }
                    if c.x - a.x >= 2.0 * self.radius {
                        let addPath = UIBezierPath(arcCenter: CGPoint(x: c.x - self.radius, y: c.y - self.radius), radius: self.radius, startAngle: .pi * 0.5, endAngle: 0.0, clockwise: false)
                        addPath.append(
                            UIBezierPath(arcCenter: CGPoint(x: c.x + self.radius, y: c.y - self.radius), radius: self.radius, startAngle: .pi, endAngle: .pi * 0.5, clockwise: false)
                        )
                        addPath.addLine(to: CGPoint(x: c.x - self.radius, y: c.y))
                        path.append(addPath)
                    }
                    if b.x  - d.x >= 2.0 * self.radius {
                        let addPath = UIBezierPath(arcCenter: CGPoint(x: d.x + self.radius, y: d.y - self.radius), radius: self.radius, startAngle: .pi * 0.5, endAngle: .pi, clockwise: true)
                        addPath.append(
                            UIBezierPath(arcCenter: CGPoint(x: d.x - self.radius, y: d.y - self.radius), radius: self.radius, startAngle: 0.0, endAngle: .pi * 0.5, clockwise: true)
                        )
                        addPath.addLine(to: CGPoint(x: d.x + self.radius, y: d.y))
                        path.append(addPath)
                    }

                    last = cur
                }
            }
            self.path = path
            
            self.path?.fill()
            self.path?.stroke()
            
            context.restoreGState()
        }
    }
}

private class DrawingTextStorage: NSTextStorage {
    let impl: NSTextStorage
    
    override init() {
        self.impl = NSTextStorage()
        
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var string: String {
        return self.impl.string
    }
    
    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key : Any] {
        return self.impl.attributes(at: location, effectiveRange: range)
    }
    
    override func replaceCharacters(in range: NSRange, with str: String) {
        self.beginEditing()
        self.impl.replaceCharacters(in: range, with: str)
        self.edited(.editedCharacters, range: range, changeInLength: (str as NSString).length - range.length)
        self.endEditing()
    }
    
    override func setAttributes(_ attrs: [NSAttributedString.Key : Any]?, range: NSRange) {
        self.beginEditing()
        self.impl.setAttributes(attrs, range: range)
        self.edited(.editedAttributes, range: range, changeInLength: 0)
        self.endEditing()
    }
}

private class DrawingTextView: UITextView {
    var drawingLayoutManager: DrawingTextLayoutManager {
        return self.layoutManager as! DrawingTextLayoutManager
    }
    
    var strokeColor: UIColor? {
        didSet {
            self.drawingLayoutManager.strokeColor = self.strokeColor
            self.setNeedsDisplay()
        }
    }
    var strokeWidth: CGFloat = 0.0 {
        didSet {
            self.drawingLayoutManager.strokeWidth = self.strokeWidth
            self.setNeedsDisplay()
        }
    }
    var strokeOffset: CGPoint = .zero {
        didSet {
            self.drawingLayoutManager.strokeOffset = self.strokeOffset
            self.setNeedsDisplay()
        }
    }
    var frameColor: UIColor? {
        didSet {
            self.drawingLayoutManager.frameColor = self.frameColor
            self.setNeedsDisplay()
        }
    }
    var frameWidthInset: CGFloat = 0.0 {
        didSet {
            self.drawingLayoutManager.frameWidthInset = self.frameWidthInset
            self.setNeedsDisplay()
        }
    }
    
    override var font: UIFont? {
        get {
            return super.font
        }
        set {
            super.font = newValue
            if let font = newValue {
                self.drawingLayoutManager.textContainers.first?.lineFragmentPadding = floor(font.pointSize * 0.24)
            }
            
            self.fixTypingAttributes()
        }
    }
    
    override var textColor: UIColor? {
        get {
            return super.textColor
        }
        set {
            super.textColor = newValue
            self.fixTypingAttributes()
        }
    }
    
    init(frame: CGRect) {
        let textStorage = DrawingTextStorage()
        let layoutManager = DrawingTextLayoutManager()
        
        let textContainer = NSTextContainer(size: CGSize(width: 0.0, height: .greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        super.init(frame: frame, textContainer: textContainer)
        
        self.tintColor = UIColor.white
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func caretRect(for position: UITextPosition) -> CGRect {
        var rect = super.caretRect(for: position)
        rect.size.width = floorToScreenPixels(rect.size.height / 25.0)
        return rect
    }
    
    override func insertText(_ text: String) {
        self.fixTypingAttributes()
        super.insertText(text)
        self.fixTypingAttributes()
    }
    
    override func paste(_ sender: Any?) {
        self.fixTypingAttributes()
        super.paste(sender)
        self.fixTypingAttributes()
    }
    
    private func fixTypingAttributes() {
        var attributes: [NSAttributedString.Key: Any] = [:]
        if let font = self.font {
            attributes[NSAttributedString.Key.font] = font
        }
        if let textColor = self.textColor {
            attributes[NSAttributedString.Key.foregroundColor] = textColor
        }
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = self.textAlignment
        attributes[NSAttributedString.Key.paragraphStyle] = paragraphStyle
        self.typingAttributes = attributes
    }
}
