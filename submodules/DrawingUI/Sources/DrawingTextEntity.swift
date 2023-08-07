import Foundation
import UIKit
import Display
import SwiftSignalKit
import AccountContext
import TextFormat
import EmojiTextAttachmentView
import MediaEditor
import MobileCoreServices
import ImageTransparency

extension DrawingTextEntity.Alignment {
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

public final class DrawingTextEntityView: DrawingEntityView, UITextViewDelegate {
    private var textEntity: DrawingTextEntity {
        return self.entity as! DrawingTextEntity
    }
    
    let textView: DrawingTextView
    var customEmojiContainerView: CustomEmojiContainerView?
    var emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?
    
    var textChanged: () -> Void = {}
    var replaceWithImage: (UIImage, Bool) -> Void = { _, _ in }
    
    init(context: AccountContext, entity: DrawingTextEntity) {
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
        
        super.init(context: context, entity: entity)
        
        self.textView.delegate = self
        self.addSubview(self.textView)
        
        self.emojiViewProvider = { emoji in
            let pointSize: CGFloat = 128.0
            return EmojiTextAttachmentView(context: context, userLocation: .other, emoji: emoji, file: emoji.file, cache: context.animationCache, renderer: context.animationRenderer, placeholderColor: UIColor.white.withAlphaComponent(0.12), pointSize: CGSize(width: pointSize, height: pointSize))
        }
        
        self.textView.onPaste = { [weak self] in
            return self?.onPaste() ?? false
        }
        
        self.update(animated: false)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.displayLink?.invalidate()
    }
    
    override func animateInsertion() {
        
    }
    
    private var isSuspended = false
    private var _isEditing = false
    public var isEditing: Bool {
        return self._isEditing || self.isSuspended
    }
    
    private var previousEntity: DrawingTextEntity?
    private var fadeView: UIView?
    
    @objc private func fadePressed() {
        self.endEditing()
    }
    
    private func onPaste() -> Bool {
        let pasteboard = UIPasteboard.general

        var images: [UIImage] = []
        var isPNG = false
        var isMemoji = false
        for item in pasteboard.items {
            if let image = item["com.apple.png-sticker"] as? UIImage {
                images.append(image)
                isPNG = true
                isMemoji = true
            } else if let image = item[kUTTypePNG as String] as? UIImage {
                images.append(image)
                isPNG = true
            } else if let image = item["com.apple.uikit.image"] as? UIImage {
                images.append(image)
                isPNG = true
            } else if let image = item[kUTTypeJPEG as String] as? UIImage {
                images.append(image)
            } else if let image = item[kUTTypeGIF as String] as? UIImage {
                images.append(image)
            }
        }
        
        if isPNG && images.count == 1, let image = images.first, let cgImage = image.cgImage {
            let maxSide = max(image.size.width, image.size.height)
            if maxSide.isZero {
                return false
            }
            let aspectRatio = min(image.size.width, image.size.height) / maxSide
            if isMemoji || (imageHasTransparency(cgImage) && aspectRatio > 0.2) {
                self.endEditing(reset: true)
                self.replaceWithImage(image, true)
                return false
            }
        }
        
        if !images.isEmpty, let image = images.first {
            self.endEditing(reset: true)
            self.replaceWithImage(image, false)
            return false
        }
        
        return true
    }
    
    private var emojiRects: [(CGRect, ChatTextInputTextCustomEmojiAttribute)] = []
    func updateEntities() {
        self.textView.drawingLayoutManager.ensureLayout(for: self.textView.textContainer)
        
        var customEmojiRects: [(CGRect, ChatTextInputTextCustomEmojiAttribute)] = []
        
        var shouldRepeat = false
        if let attributedText = self.textView.attributedText {
            let beginning = self.textView.beginningOfDocument
            attributedText.enumerateAttributes(in: NSMakeRange(0, attributedText.length), options: [], using: { attributes, range, _ in
                if let value = attributes[ChatTextInputAttributes.customEmoji] as? ChatTextInputTextCustomEmojiAttribute {
                    if let start = self.textView.position(from: beginning, offset: range.location), let end = self.textView.position(from: start, offset: range.length), let textRange = self.textView.textRange(from: start, to: end) {
                        let rect = self.textView.firstRect(for: textRange)
                        customEmojiRects.append((rect, value))
                        if rect.origin.x.isInfinite {
                            shouldRepeat = true
                        }
                    }
                }
            })
        }
        
        let color = self.textEntity.color.toUIColor()
        let textColor: UIColor
        switch self.textEntity.style {
        case .regular:
            textColor = color
        case .filled:
            textColor = color.lightness > 0.99 ? UIColor.black : UIColor.white
        case .semi:
            textColor = color
        case .stroke:
            textColor = color.lightness > 0.99 ? UIColor.black : UIColor.white
        }
        
        self.emojiRects = customEmojiRects
        if !customEmojiRects.isEmpty && !shouldRepeat {
            let customEmojiContainerView: CustomEmojiContainerView
            if let current = self.customEmojiContainerView {
                customEmojiContainerView = current
            } else {
                customEmojiContainerView = CustomEmojiContainerView(emojiViewProvider: { [weak self] emoji in
                    guard let strongSelf = self, let emojiViewProvider = strongSelf.emojiViewProvider else {
                        return nil
                    }
                    return emojiViewProvider(emoji)
                })
                customEmojiContainerView.isUserInteractionEnabled = false
                customEmojiContainerView.center = customEmojiContainerView.center
                self.addSubview(customEmojiContainerView)
                self.customEmojiContainerView = customEmojiContainerView
            }
            
            customEmojiContainerView.update(fontSize: self.displayFontSize * 0.78, textColor: textColor, emojiRects: customEmojiRects)
        } else if let customEmojiContainerView = self.customEmojiContainerView {
            customEmojiContainerView.removeFromSuperview()
            self.customEmojiContainerView = nil
        }
        
        if shouldRepeat {
            Queue.mainQueue().after(0.01) {
                self.updateEntities()
            }
        }
    }
    
    func beginEditing(accessoryView: UIView?) {
        self._isEditing = true
        if !self.textEntity.text.string.isEmpty {
            let previousEntity = self.textEntity.duplicate() as? DrawingTextEntity
            previousEntity?.uuid = self.textEntity.uuid
            self.previousEntity = previousEntity
        }
        
        self.update(animated: false, updateEditingPosition: false)
        
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
        
        self.updateEditingPosition(animated: true)
        
        if let selectionView = self.selectionView as? DrawingTextEntititySelectionView {
            selectionView.alpha = 0.0
            if !self.textEntity.text.string.isEmpty {
                selectionView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
            }
        }
    }
    
    func updateEditingPosition(animated: Bool) {
        guard let parentView = self.superview as? DrawingEntitiesView else {
            return
        }
        
        var position = parentView.getEntityCenterPosition()
        if parentView.frame.width == 1080 && parentView.frame.height == 1920 {
            let width = self.bounds.width
            switch self.textEntity.alignment {
            case .left:
                position = CGPoint(x: 80.0 + width / 2.0, y: position.y)
            case .right:
                position = CGPoint(x: parentView.bounds.width - 80.0 - width / 2.0, y: position.y)
            default:
                break
            }
        }
        
        let scale = parentView.getEntityAdditionalScale() / (parentView.drawingView?.zoomScale ?? 1.0)
        let rotation = parentView.getEntityInitialRotation()
        if animated {
            UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.0) {
                self.transform = CGAffineTransformMakeRotation(rotation).scaledBy(x: scale, y: scale)
                self.center = position
            }
        } else {
            self.transform = CGAffineTransformMakeRotation(rotation).scaledBy(x: scale, y: scale)
            self.center = position
        }
    }
    
    func endEditing(reset: Bool = false) {
        guard let parentView = self.superview as? DrawingEntitiesView else {
            return
        }
        
        self._isEditing = false
        self.textView.inputView = nil
        self.textView.inputAccessoryView = nil
        self.textView.reloadInputViews()
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
            if self.textEntity.text.string.isEmpty {
                self.containerView?.remove(uuid: self.textEntity.uuid)
            }
        }
                
        if let fadeView = self.fadeView {
            self.fadeView = nil
            fadeView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak fadeView] _ in
                fadeView?.removeFromSuperview()
            })
        }
        
        if self.previousEntity == nil && self.textEntity.alignment != .center, parentView.frame.width == 1080 && parentView.frame.height == 1920 {
            let width = self.bounds.width
            switch self.textEntity.alignment {
            case .left:
                self.textEntity.position = CGPoint(x: 80.0 + width / 2.0, y: self.textEntity.position.y)
            case .right:
                self.textEntity.position = CGPoint(x: parentView.bounds.width - 80.0 - width / 2.0, y: self.textEntity.position.y)
            default:
                break
            }
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
    
    public func textViewDidChange(_ textView: UITextView) {
        guard let updatedText = self.textView.attributedText.mutableCopy() as? NSMutableAttributedString else {
            return
        }
        let range = NSMakeRange(0, updatedText.length)
        updatedText.removeAttribute(.font, range: range)
        updatedText.removeAttribute(.paragraphStyle, range: range)
        updatedText.removeAttribute(.foregroundColor, range: range)
        
        self.textEntity.text = updatedText
        
        self.sizeToFit()
        self.update(afterAppendingEmoji: true)
        
        self.textChanged()
    }
    
    func insertText(_ text: NSAttributedString) {
        guard let updatedText = self.textView.attributedText.mutableCopy() as? NSMutableAttributedString else {
            return
        }
        let range = NSMakeRange(0, updatedText.length)
        updatedText.removeAttribute(.font, range: range)
        updatedText.removeAttribute(.paragraphStyle, range: range)
        updatedText.removeAttribute(.foregroundColor, range: range)
        
        let previousSelectedRange = self.textView.selectedRange
        updatedText.replaceCharacters(in: self.textView.selectedRange, with: text)
        
        self.textEntity.text = updatedText
        
        self.update(animated: false, afterAppendingEmoji: true)
        
        self.textView.selectedRange = NSMakeRange(previousSelectedRange.location + previousSelectedRange.length + text.length, 0)
    }
    
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        self.textView.setNeedsLayersUpdate()
        var result = self.textView.sizeThatFits(CGSize(width: self.textEntity.width, height: .greatestFiniteMagnitude))
        result.width = max(224.0, ceil(result.width) + 20.0)
        result.height = ceil(result.height);
        return result;
    }
    
    public override func sizeToFit() {
        let center = self.center
        let transform = self.transform
        self.transform = .identity
        super.sizeToFit()
        self.center = center
        self.transform = transform
        
        //entity changed
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        self.textView.frame = self.bounds
    }
        
    private var displayFontSize: CGFloat {
        let minFontSize = max(10.0, max(self.textEntity.referenceDrawingSize.width, self.textEntity.referenceDrawingSize.height) * 0.025)
        let maxFontSize = max(10.0, max(self.textEntity.referenceDrawingSize.width, self.textEntity.referenceDrawingSize.height) * 0.25)
        let fontSize = minFontSize + (maxFontSize - minFontSize) * self.textEntity.fontSize
        return fontSize
    }
    
    private func updateText(keepSelectedRange: Bool = false) {
        guard let text = self.textEntity.text.mutableCopy() as? NSMutableAttributedString else {
            return
        }
        let range = NSMakeRange(0, text.length)
        let fontSize = self.displayFontSize
    
        self.textView.hasTextLayers = [.typing, .wiggle].contains(self.textEntity.animation)
        self.textView.drawingLayoutManager.textContainers.first?.lineFragmentPadding = floor(fontSize * 0.24)
    
        if let (font, name) = availableFonts[text.string.lowercased()] {
            self.textEntity.font = .other(font, name)
        }
        
        var font: UIFont
        switch self.textEntity.font {
        case .sanFrancisco:
            font = Font.with(size: fontSize, design: .regular, weight: .semibold)
        case let .other(fontName, _):
            font = UIFont(name: fontName, size: fontSize) ?? Font.with(size: fontSize, design: .regular, weight: .semibold)
        }
        
        text.addAttribute(.font, value: font, range: range)
        self.textView.font = font
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = self.textEntity.alignment.alignment
        text.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        
        let color = self.textEntity.color.toUIColor()
        let textColor: UIColor
        switch self.textEntity.style {
        case .regular:
            textColor = color
        case .filled:
            textColor = color.lightness > 0.99 ? UIColor.black : UIColor.white
        case .semi:
            textColor = color
        case .stroke:
            textColor = color.lightness > 0.99 ? UIColor.black : UIColor.white
        }
        
        guard let visualText = text.mutableCopy() as? NSMutableAttributedString else {
            return
        }
        if self.textView.hasTextLayers {
            text.addAttribute(.foregroundColor, value: UIColor.clear, range: range)
        } else {
            text.addAttribute(.foregroundColor, value: textColor, range: range)
        }
        visualText.addAttribute(.foregroundColor, value: textColor, range: range)
        
        text.enumerateAttributes(in: range) { attributes, subrange, _ in
            if let _ = attributes[ChatTextInputAttributes.customEmoji] {
                text.addAttribute(.foregroundColor, value: UIColor.clear, range: subrange)
                visualText.addAttribute(.foregroundColor, value: UIColor.clear, range: subrange)
            }
        }
        
        let previousRange = self.textView.selectedRange
        self.textView.attributedText = text
        self.textView.visualText = visualText
        
        if keepSelectedRange {
            self.textView.selectedRange = previousRange
        }
        
        if self.textView.hasTextLayers {
            self.textView.onLayersUpdate = { [weak self] in
                self?.updateTextAnimations()
            }
        } else {
            self.updateTextAnimations()
        }
    }
    
    private var previousDisplayLinkTime: Double?
    
    private var displayLinkStart: Double?
    private var displayLink: SharedDisplayLinkDriver.Link?
    
    private var pendingImage: (Double, UIImage)?
    private var cachedFrames: [DrawingTextEntity.AnimationFrame] = []
    
    private func setupRecorder(delta: Double, duration: Double) {
        self.cachedFrames.removeAll()
        
        self.displayLink?.invalidate()
        self.displayLink = nil
        
        self.previousDisplayLinkTime = nil
        let displayLinkStart = CACurrentMediaTime()
        self.displayLinkStart = displayLinkStart
        
        self.displayLink = SharedDisplayLinkDriver.shared.add { [weak self] in
            if let strongSelf = self {
                let currentTime = CACurrentMediaTime()
                if let previousDisplayLinkTime = strongSelf.previousDisplayLinkTime, currentTime < previousDisplayLinkTime + delta {
                    return
                }
                if currentTime >= displayLinkStart + duration {
                    strongSelf.displayLink?.invalidate()
                    strongSelf.displayLink = nil
                }
                if let (timestamp, image) = strongSelf.pendingImage, let previousDisplayLinkTime = strongSelf.previousDisplayLinkTime {
                    strongSelf.cachedFrames.append(DrawingTextEntity.AnimationFrame(timestamp: timestamp - displayLinkStart, duration: currentTime - previousDisplayLinkTime, image: image))
                }
                if let image = strongSelf.getPresentationRenderImage() {
                    strongSelf.pendingImage = (currentTime, image)
                }
                if strongSelf.previousDisplayLinkTime == nil {
                    strongSelf.previousDisplayLinkTime = displayLinkStart
                } else {
                    strongSelf.previousDisplayLinkTime = currentTime
                }
            }
        }
        self.displayLink?.isPaused = false
    }

    func updateTextAnimations() {
        for layer in self.textView.characterLayers {
            layer.removeAllAnimations()
        }
        self.textView.layer.removeAllAnimations()
        
        guard self.textView.characterLayers.count > 0 || self.textEntity.animation == .zoomIn else {
            return
        }
        
        switch self.textEntity.animation {
        case .typing:
            let delta: CGFloat = 1.0 / CGFloat(self.textView.characterLayers.count + 3)
            let duration = Double(self.textView.characterLayers.count + 3) * 0.28
            var offset = delta
            for layer in self.textView.characterLayers {
                let animation = CAKeyframeAnimation(keyPath: "opacity")
                animation.calculationMode = .discrete
                animation.values = [0.0, 1.0]
                animation.keyTimes = [0.0, offset as NSNumber, 1.0]
                animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animation.duration = duration
                animation.repeatCount = .infinity
                layer.add(animation, forKey: "opacity")
                offset += delta
            }
            self.setupRecorder(delta: delta, duration: duration)
        case .wiggle:
            for layer in self.textView.characterLayers {
                let animation = CABasicAnimation(keyPath: "transform.rotation.z")
                animation.fromValue = (-.pi / 10.0) as NSNumber
                animation.toValue = (.pi / 10.0) as NSNumber
                animation.autoreverses = true
                animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animation.duration = 0.6
                animation.repeatCount = .infinity
                layer.add(animation, forKey: "transform.rotation.z")
            }
            self.setupRecorder(delta: 0.033, duration: 1.2)
        case .zoomIn:
            let animation = CABasicAnimation(keyPath: "transform.scale")
            animation.fromValue = 0.001 as NSNumber
            animation.toValue = 1.0 as NSNumber
            animation.autoreverses = true
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.duration = 0.8
            animation.repeatCount = .infinity
            self.textView.layer.add(animation, forKey: "transform.scale")
        default:
            break
        }
    }
    
    public override func update(animated: Bool = false) {
        self.update(animated: animated, afterAppendingEmoji: false, updateEditingPosition: true)
    }
    
    func update(animated: Bool = false, afterAppendingEmoji: Bool = false, updateEditingPosition: Bool = true) {
        if !self.isEditing {
            self.center = self.textEntity.position
            self.transform = CGAffineTransformScale(CGAffineTransformMakeRotation(self.textEntity.rotation), self.textEntity.scale, self.textEntity.scale)
        }
        
        var cursorColor = UIColor.white
        let color = self.textEntity.color.toUIColor()
        switch self.textEntity.style {
        case .regular:
            self.textView.textColor = color
            self.textView.strokeColor = nil
            self.textView.frameColor = nil
        case .filled:
            self.textView.textColor = color.lightness > 0.99 ? UIColor.black : UIColor.white
            cursorColor = color.lightness > 0.99 ? UIColor(rgb: 0x007aff) : UIColor.white
            self.textView.strokeColor = nil
            self.textView.frameColor = color
        case .semi:
            self.textView.textColor = color
            self.textView.strokeColor = nil
            self.textView.frameColor = color.lightness > 0.7 ? UIColor(rgb: 0x000000, alpha: 0.75) : UIColor(rgb: 0xffffff, alpha: 0.75)
        case .stroke:
            self.textView.textColor = color.lightness > 0.99 ? UIColor.black : UIColor.white
            self.textView.strokeColor = color
            self.textView.frameColor = nil
        }
        self.textView.tintColor = self.textView.text.isEmpty ? .white : cursorColor
        
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
        self.textView.textAlignment = self.textEntity.alignment.alignment
        
        self.updateText(keepSelectedRange: afterAppendingEmoji)
        
        self.sizeToFit()
        
        if updateEditingPosition && self.isEditing {
            self.updateEditingPosition(animated: animated)
        }
        
        self.textView.onLayoutUpdate = { [weak self] in
            self?.updateEntities()
        }
        
        super.update(animated: animated)
    }
    
    override func updateSelectionView() {
        guard let selectionView = self.selectionView as? DrawingTextEntititySelectionView else {
            return
        }
        self.pushIdentityTransformForMeasurement()
     
        selectionView.transform = .identity
        let bounds = self.selectionBounds
        let center = bounds.center
        
        let scale = self.superview?.superview?.layer.value(forKeyPath: "transform.scale.x") as? CGFloat ?? 1.0
        selectionView.center = self.convert(center, to: selectionView.superview)
        
        selectionView.bounds = CGRect(origin: .zero, size: CGSize(width: (bounds.width * self.textEntity.scale) * scale + selectionView.selectionInset * 2.0, height: (bounds.height * self.textEntity.scale) * scale + selectionView.selectionInset * 2.0))
        selectionView.transform = CGAffineTransformMakeRotation(self.textEntity.rotation)
        
        self.popIdentityTransformForMeasurement()
    }
        
    override func makeSelectionView() -> DrawingEntitySelectionView? {
        if let selectionView = self.selectionView {
            return selectionView
        }
        let selectionView = DrawingTextEntititySelectionView()
        selectionView.entityView = self
        return selectionView
    }
    
    func getRenderImage() -> UIImage? {
        let rect = self.bounds
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 2.0)
        self.textView.drawHierarchy(in: rect, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    func getPresentationRenderImage() -> UIImage? {
        let rect = self.bounds
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 1.0)
        if let context = UIGraphicsGetCurrentContext() {
            for layer in self.textView.characterLayers {
                if let presentation = layer.presentation() {
                    context.saveGState()
                    context.translateBy(x: presentation.position.x - presentation.bounds.width / 2.0, y: 0.0)
                    if let rotation = (presentation.value(forKeyPath: "transform.rotation.z") as? NSNumber)?.floatValue {
                        context.translateBy(x: presentation.bounds.width / 2.0, y: presentation.bounds.height)
                        context.rotate(by: CGFloat(rotation))
                        context.translateBy(x: -presentation.bounds.width / 2.0, y: -presentation.bounds.height)
                    }
                    presentation.render(in: context)
                    context.restoreGState()
                }
            }
        }
        //self.textView.drawHierarchy(in: rect, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    func getRenderSubEntities() -> [DrawingEntity] {
        let textSize = self.textView.bounds.size
        let textPosition = self.textEntity.position
        let scale = self.textEntity.scale
        let rotation = self.textEntity.rotation
        
        let itemSize: CGFloat = floor(24.0 * self.displayFontSize * 0.78 / 17.0)
        
        var entities: [DrawingEntity] = []
        for (emojiRect, emojiAttribute) in self.emojiRects {
            guard let file = emojiAttribute.file else {
                continue
            }
            let emojiTextPosition = emojiRect.center.offsetBy(dx: -textSize.width / 2.0, dy: -textSize.height / 2.0)
                        
            let entity = DrawingStickerEntity(content: .file(file))
            entity.referenceDrawingSize = CGSize(width: itemSize * 4.0, height: itemSize * 4.0)
            entity.scale = scale
            entity.position = textPosition.offsetBy(
                dx: (emojiTextPosition.x * cos(rotation) - emojiTextPosition.y * sin(rotation)) * scale,
                dy: (emojiTextPosition.y * cos(rotation) + emojiTextPosition.x * sin(rotation)) * scale
            )
            entity.rotation = rotation
            entities.append(entity)
        }
        return entities
    }
    
    func getRenderAnimationFrames() -> [DrawingTextEntity.AnimationFrame]? {
        return self.cachedFrames
    }
}

final class DrawingTextEntititySelectionView: DrawingEntitySelectionView {
    private let border = SimpleShapeLayer()
    private let leftHandle = SimpleShapeLayer()
    private let rightHandle = SimpleShapeLayer()
    
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
                
        self.snapTool.onSnapUpdated = { [weak self] type, snapped in
            if let self, let entityView = self.entityView {
                entityView.onSnapUpdated(type, snapped)
            }
        }
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
        if let entityView = self.entityView as? DrawingTextEntityView, entityView.isEditing {
            return false
        }
        return true
    }
    
    private let snapTool = DrawingEntitySnapTool()
    
    private var currentHandle: CALayer?
    override func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let entityView = self.entityView, let entity = entityView.entity as? DrawingTextEntity else {
            return
        }
        let location = gestureRecognizer.location(in: self)
        
        switch gestureRecognizer.state {
        case .began:
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
        guard let entityView = self.entityView as? DrawingTextEntityView, !entityView.isEditing, let entity = entityView.entity as? DrawingTextEntity else {
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
        guard let entityView = self.entityView as? DrawingTextEntityView, !entityView.isEditing, let entity = entityView.entity as? DrawingTextEntity else {
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

final class DrawingTextLayoutManager: NSLayoutManager {
    var radius: CGFloat
    var maxIndex: Int = 0
    
    private(set) var path: UIBezierPath?
    var rectArray: [CGRect] = []
    
    var strokeColor: UIColor?
    var strokeWidth: CGFloat = 0.0
    var strokeOffset: CGPoint = .zero
    
    var frameColor: UIColor?
    var frameInsets = UIEdgeInsets()
    
    var textAlignment: NSTextAlignment = .natural
    
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
            let characterRange = self.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            let substring = ((self.textStorage?.string ?? "") as NSString).substring(with: characterRange)
            if substring.trimmingCharacters(in: .newlines).isEmpty {
                ignoreRange = true
            }
            
            var usedRect = usedRect
            if substring.hasSuffix(" ") && self.textAlignment != .right {
                usedRect.size.width -= floorToScreenPixels(usedRect.height * 0.145)
            }
            
            if !ignoreRange {
                let newRect = CGRect(origin: CGPoint(x: usedRect.minX - floorToScreenPixels(self.frameInsets.left * usedRect.height), y: usedRect.minY - floorToScreenPixels(self.frameInsets.top * usedRect.height)), size: CGSize(width: usedRect.width + floorToScreenPixels((self.frameInsets.left + self.frameInsets.right) * usedRect.height), height: usedRect.height + floorToScreenPixels((self.frameInsets.top + self.frameInsets.bottom) * usedRect.height)))
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
        
        var last = self.rectArray[index - 1]
        var cur = self.rectArray[index]
        
        self.radius = cur.height * 0.2
        
        let doubleRadius = self.radius * 2.5
        
        var t1 = ((cur.minX - last.minX < doubleRadius) && (cur.minX > last.minX)) || ((cur.maxX - last.maxX > -doubleRadius) && (cur.maxX < last.maxX))
        let t2 = ((last.minX - cur.minX < doubleRadius) && (last.minX > cur.minX)) || ((last.maxX - cur.maxX > -doubleRadius) && (last.maxX < cur.maxX))
        
        if t2 {
            let newRect = CGRect(origin: CGPoint(x: cur.minX, y: last.minY), size: CGSize(width: cur.width, height: last.height))
            self.rectArray[index - 1] = newRect
            self.processRectIndex(index - 1)
        }
        
        last = self.rectArray[index - 1]
        cur = self.rectArray[index]
        
        t1 = ((cur.minX - last.minX < doubleRadius) && (cur.minX > last.minX)) || ((cur.maxX - last.maxX > -doubleRadius) && (cur.maxX < last.maxX))
        
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
                        
            context.setBlendMode(.copy)
            context.setFillColor(frameColor.cgColor)
            context.setStrokeColor(frameColor.cgColor)
            
            self.prepare()
            self.preprocess()
            
            let path = UIBezierPath()
            
            var last: CGRect = .null
            for i in 0 ..< self.rectArray.count {
                let cur = self.rectArray[i]
                self.radius = cur.height * 0.2
                
                path.append(UIBezierPath(roundedRect: cur, cornerRadius: self.radius))
                if i == 0 {
                    last = cur
                } else if i > 0 && abs(last.maxY -  cur.minY) < 15.0 {
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
                } else {
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

final class SimpleTextLayer: CATextLayer {
    override func action(forKey event: String) -> CAAction? {
        return nullAction
    }
}

final class DrawingTextView: UITextView, NSLayoutManagerDelegate {
    var characterLayers: [CALayer] = []
    
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
    var frameInsets: UIEdgeInsets = .zero {
        didSet {
            self.drawingLayoutManager.frameInsets = self.frameInsets
            self.setNeedsDisplay()
        }
    }
        
    override var textAlignment: NSTextAlignment {
        get {
            return super.textAlignment
        }
        set {
            self.drawingLayoutManager.textAlignment = newValue
            super.textAlignment = newValue
        }
    }
    
    override var font: UIFont? {
        get {
            return super.font
        }
        set {
            if self.font != newValue {
                super.font = newValue
                self.fixTypingAttributes()
            }
        }
    }
    
    override var textColor: UIColor? {
        get {
            return super.textColor
        }
        set {
            if self.textColor != newValue {
                super.textColor = newValue
                self.fixTypingAttributes()
            }
        }
    }
    
    var hasTextLayers = false
    var visualText: NSAttributedString?
        
    init(frame: CGRect) {
        let textStorage = DrawingTextStorage()
        let layoutManager = DrawingTextLayoutManager()
        
        let textContainer = NSTextContainer(size: CGSize(width: 0.0, height: .greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        super.init(frame: frame, textContainer: textContainer)
        
        self.tintColor = UIColor.white
        
        layoutManager.delegate = self
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
        
    fileprivate func fixTypingAttributes() {
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

    var onLayoutUpdate: (() -> Void)?
    var onLayersUpdate: (() -> Void)?
    
    private var needsLayersUpdate = false
    func setNeedsLayersUpdate() {
        self.needsLayersUpdate = true
    }
    
    func layoutManager(_ layoutManager: NSLayoutManager, didCompleteLayoutFor textContainer: NSTextContainer?, atEnd layoutFinishedFlag: Bool) {
        self.updateCharLayers()
        if layoutFinishedFlag {
            if let onLayoutUpdate = self.onLayoutUpdate {
                self.onLayoutUpdate = nil
                onLayoutUpdate()
            }
        }
    }
    
    func updateCharLayers() {
        for layer in self.characterLayers {
            layer.removeFromSuperlayer()
        }
        self.characterLayers = []
        
        guard let attributedString = self.visualText, self.hasTextLayers else {
            return
        }
        
        let wordRange = NSMakeRange(0, attributedString.length)
        
        var index = wordRange.location
        while index < wordRange.location + wordRange.length {
            let glyphRange = NSMakeRange(index, 1)
            let characterRange = self.layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange:nil)
            var glyphRect = self.layoutManager.boundingRect(forGlyphRange: glyphRange, in: self.textContainer)
            //let location = self.layoutManager.location(forGlyphAt: index)
            
            glyphRect.origin.y += glyphRect.height / 2.0 //location.y - (glyphRect.height / 2.0);
            let textLayer = SimpleTextLayer()
            textLayer.contentsScale = 1.0
            textLayer.frame = glyphRect
            textLayer.string = attributedString.attributedSubstring(from: characterRange)
            textLayer.anchorPoint = CGPoint(x: 0.5, y: 1.0)
            
            self.layer.addSublayer(textLayer)
            self.characterLayers.append(textLayer)
            
            let stepGlyphRange = self.layoutManager.glyphRange(forCharacterRange: characterRange, actualCharacterRange:nil)
            index += stepGlyphRange.length
        }
        
        self.onLayersUpdate?()
    }
    
    var onPaste: () -> Bool = { return true }
    override func paste(_ sender: Any?) {
        if !self.text.isEmpty || self.onPaste() {
            self.fixTypingAttributes()
            super.paste(sender)
            self.fixTypingAttributes()
        }
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(self.paste(_:)) {
            if UIPasteboard.general.hasImages && self.text.isEmpty {
                return true
            }
        }
        if #available(iOS 15.0, *) {
            if action == #selector(captureTextFromCamera(_:)) {
                return false
            }
        }
        return super.canPerformAction(action, withSender: sender)
    }
}

private var availableFonts: [String: (String, String)] = {
    let familyNames = UIFont.familyNames
    var result: [String: (String, String)] = [:]
    
    for family in familyNames {
        let names = UIFont.fontNames(forFamilyName: family)
        
        var preferredFont: String?
        for name in names {
            let originalName = name
            let name = name.lowercased()
            if (!name.contains("-") || name.contains("regular")) && preferredFont == nil {
                preferredFont = originalName
            }
            if name.contains("bold") && !name.contains("italic") {
                preferredFont = originalName
            }
        }
        
        if let preferredFont {
            let shortname = family.lowercased().replacingOccurrences(of: " ", with: "", options: [])
            result[shortname] = (preferredFont, family)
        }
    }
    return result
}()
