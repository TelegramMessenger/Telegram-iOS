import Foundation
import UIKit
import Display
import SwiftSignalKit
import AccountContext
import TextFormat
import EmojiTextAttachmentView

public final class DrawingTextEntity: DrawingEntity, Codable {
    final class CustomEmojiAttribute: Codable {
        private enum CodingKeys: String, CodingKey {
            case attribute
            case rangeOrigin
            case rangeLength
        }
        let attribute: ChatTextInputTextCustomEmojiAttribute
        let range: NSRange
        
        init(attribute: ChatTextInputTextCustomEmojiAttribute, range: NSRange) {
            self.attribute = attribute
            self.range = range
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.attribute = try container.decode(ChatTextInputTextCustomEmojiAttribute.self, forKey: .attribute)
            
            let rangeOrigin = try container.decode(Int.self, forKey: .rangeOrigin)
            let rangeLength = try container.decode(Int.self, forKey: .rangeLength)
            self.range = NSMakeRange(rangeOrigin, rangeLength)
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.attribute, forKey: .attribute)
            try container.encode(self.range.location, forKey: .rangeOrigin)
            try container.encode(self.range.length, forKey: .rangeLength)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case uuid
        case text
        case textAttributes
        case style
        case font
        case alignment
        case fontSize
        case color
        case referenceDrawingSize
        case position
        case width
        case scale
        case rotation
        case renderImage
        case renderSubEntities
    }
    
    enum Style: Codable {
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
    
    enum Font: Codable {
        case sanFrancisco
        case other(String, String)
    }
    
    enum Alignment: Codable {
        case left
        case center
        case right
        
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
    
    public var uuid: UUID
    public var isAnimated: Bool {
        var isAnimated = false
        self.text.enumerateAttributes(in: NSMakeRange(0, self.text.length), options: [], using: { attributes, range, _ in
            if let _ = attributes[ChatTextInputAttributes.customEmoji] as? ChatTextInputTextCustomEmojiAttribute {
                isAnimated = true
            }
        })
        return isAnimated
    }
    
    var text: NSAttributedString
    var style: Style
    var font: Font
    var alignment: Alignment
    var fontSize: CGFloat
    public var color: DrawingColor
    public var lineWidth: CGFloat = 0.0
    
    var referenceDrawingSize: CGSize
    public var position: CGPoint
    var width: CGFloat
    public var scale: CGFloat
    public var rotation: CGFloat
    
    public var center: CGPoint {
        return self.position
    }
    
    public var renderImage: UIImage?
    public var renderSubEntities: [DrawingStickerEntity]?
    
    init(text: NSAttributedString, style: Style, font: Font, alignment: Alignment, fontSize: CGFloat, color: DrawingColor) {
        self.uuid = UUID()
        
        self.text = text
        self.style = style
        self.font = font
        self.alignment = alignment
        self.fontSize = fontSize
        self.color = color
        
        self.referenceDrawingSize = .zero
        self.position = .zero
        self.width = 100.0
        self.scale = 1.0
        self.rotation = 0.0
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.uuid = try container.decode(UUID.self, forKey: .uuid)
        let text = try container.decode(String.self, forKey: .text)
        
        let attributedString = NSMutableAttributedString(string: text)
        let textAttributes = try container.decode([CustomEmojiAttribute].self, forKey: .textAttributes)
        for attribute in textAttributes {
            attributedString.addAttribute(ChatTextInputAttributes.customEmoji, value: attribute.attribute, range: attribute.range)
        }
        self.text = attributedString

        self.style = try container.decode(Style.self, forKey: .style)
        self.font = try container.decode(Font.self, forKey: .font)
        self.alignment = try container.decode(Alignment.self, forKey: .alignment)
        self.fontSize = try container.decode(CGFloat.self, forKey: .fontSize)
        self.color = try container.decode(DrawingColor.self, forKey: .color)
        self.referenceDrawingSize = try container.decode(CGSize.self, forKey: .referenceDrawingSize)
        self.position = try container.decode(CGPoint.self, forKey: .position)
        self.width = try container.decode(CGFloat.self, forKey: .width)
        self.scale = try container.decode(CGFloat.self, forKey: .scale)
        self.rotation = try container.decode(CGFloat.self, forKey: .rotation)
        if let renderImageData = try? container.decodeIfPresent(Data.self, forKey: .renderImage) {
            self.renderImage = UIImage(data: renderImageData)
        }
        if let renderSubEntities = try? container.decodeIfPresent([CodableDrawingEntity].self, forKey: .renderSubEntities) {
            self.renderSubEntities = renderSubEntities.compactMap { $0.entity as? DrawingStickerEntity }
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.uuid, forKey: .uuid)
        try container.encode(self.text.string, forKey: .text)
        
        var textAttributes: [CustomEmojiAttribute] = []
        self.text.enumerateAttributes(in: NSMakeRange(0, self.text.length), options: [], using: { attributes, range, _ in
            if let value = attributes[ChatTextInputAttributes.customEmoji] as? ChatTextInputTextCustomEmojiAttribute {
                textAttributes.append(CustomEmojiAttribute(attribute: value, range: range))
            }
        })
        try container.encode(textAttributes, forKey: .textAttributes)
        
        try container.encode(self.style, forKey: .style)
        try container.encode(self.font, forKey: .font)
        try container.encode(self.alignment, forKey: .alignment)
        try container.encode(self.fontSize, forKey: .fontSize)
        try container.encode(self.color, forKey: .color)
        try container.encode(self.referenceDrawingSize, forKey: .referenceDrawingSize)
        try container.encode(self.position, forKey: .position)
        try container.encode(self.width, forKey: .width)
        try container.encode(self.scale, forKey: .scale)
        try container.encode(self.rotation, forKey: .rotation)
        if let renderImage, let data = renderImage.pngData() {
            try container.encode(data, forKey: .renderImage)
        }
        if let renderSubEntities = self.renderSubEntities {
            let codableEntities: [CodableDrawingEntity] = renderSubEntities.map { .sticker($0) }
            try container.encode(codableEntities, forKey: .renderSubEntities)
        }
    }

    public func duplicate() -> DrawingEntity {
        let newEntity = DrawingTextEntity(text: self.text, style: self.style, font: self.font, alignment: self.alignment, fontSize: self.fontSize, color: self.color)
        newEntity.referenceDrawingSize = self.referenceDrawingSize
        newEntity.position = self.position
        newEntity.width = self.width
        newEntity.scale = self.scale
        newEntity.rotation = self.rotation
        return newEntity
    }
    
    public weak var currentEntityView: DrawingEntityView?
    public func makeView(context: AccountContext) -> DrawingEntityView {
        let entityView = DrawingTextEntityView(context: context, entity: self)
        self.currentEntityView = entityView
        return entityView
    }
    
    public func prepareForRender() {
        self.renderImage = (self.currentEntityView as? DrawingTextEntityView)?.getRenderImage()
        self.renderSubEntities = (self.currentEntityView as? DrawingTextEntityView)?.getRenderSubEntities()
    }
}

final class DrawingTextEntityView: DrawingEntityView, UITextViewDelegate {
    private var textEntity: DrawingTextEntity {
        return self.entity as! DrawingTextEntity
    }
    
    let textView: DrawingTextView
    var customEmojiContainerView: CustomEmojiContainerView?
    var emojiViewProvider: ((ChatTextInputTextCustomEmojiAttribute) -> UIView)?
    
    var textChanged: () -> Void = {}
    
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
        self.textView.autocorrectionType = .no
        self.textView.spellCheckingType = .no
        
        super.init(context: context, entity: entity)
        
        self.textView.delegate = self
        self.addSubview(self.textView)
        
        self.emojiViewProvider = { [weak self] emoji in
            guard let strongSelf = self else {
                return UIView()
            }
                        
            let pointSize: CGFloat = 128.0
            return EmojiTextAttachmentView(context: context, userLocation: .other, emoji: emoji, file: emoji.file, cache: strongSelf.context.animationCache, renderer: strongSelf.context.animationRenderer, placeholderColor: UIColor.white.withAlphaComponent(0.12), pointSize: CGSize(width: pointSize, height: pointSize))
        }
        
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
            if !self.textEntity.text.string.isEmpty {
                selectionView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
            }
        }
    }
    
    func endEditing(reset: Bool = false) {
        self._isEditing = false
        self.textView.resignFirstResponder()
        self.textView.inputView = nil
        self.textView.inputAccessoryView = nil
        
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
//            self.textEntity.text = self.textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
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
    
        self.textView.drawingLayoutManager.textContainers.first?.lineFragmentPadding = floor(fontSize * 0.24)
    
        if let (font, name) = availableFonts[text.string.lowercased()] {
            self.textEntity.font = .other(font, name)
        }
        
        var font: UIFont
        switch self.textEntity.font {
        case .sanFrancisco:
            font = Font.with(size: fontSize, design: .round, weight: .semibold)
        case let .other(fontName, _):
            font = UIFont(name: fontName, size: fontSize) ?? Font.with(size: fontSize, design: .round, weight: .semibold)
        }
        
        text.addAttribute(.font, value: font, range: range)
        self.textView.font = font
        
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
        text.addAttribute(.foregroundColor, value: textColor, range: range)
        
        text.enumerateAttributes(in: range) { attributes, subrange, _ in
            if let _ = attributes[ChatTextInputAttributes.customEmoji] {
                text.addAttribute(.foregroundColor, value: UIColor.clear, range: subrange)
            }
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = self.textEntity.alignment.alignment
        text.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        
        let previousRange = self.textView.selectedRange
        self.textView.attributedText = text
        if keepSelectedRange {
            self.textView.selectedRange = previousRange
        }
    }
    
    override func update(animated: Bool = false) {
        self.update(animated: animated, afterAppendingEmoji: false)
    }
    
    func update(animated: Bool = false, afterAppendingEmoji: Bool = false) {
        if !self.isEditing {
            self.center = self.textEntity.position
            self.transform = CGAffineTransformScale(CGAffineTransformMakeRotation(self.textEntity.rotation), self.textEntity.scale, self.textEntity.scale)
        }
        
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
            self.textView.frameColor = color.lightness > 0.7 ? UIColor(rgb: 0x000000, alpha: 0.75) : UIColor(rgb: 0xffffff, alpha: 0.75)
        case .stroke:
            self.textView.textColor = color.lightness > 0.99 ? UIColor.black : UIColor.white
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
        
        self.updateText(keepSelectedRange: afterAppendingEmoji)
        
        self.sizeToFit()
        
        Queue.mainQueue().after(afterAppendingEmoji ? 0.01 : 0.001) {
            self.updateEntities()
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
        self.textView.drawHierarchy(in: rect, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    func getRenderSubEntities() -> [DrawingStickerEntity] {
        let textSize = self.textView.bounds.size
        let textPosition = self.textEntity.position
        let scale = self.textEntity.scale
        let rotation = self.textEntity.rotation
        
        let itemSize: CGFloat = floor(24.0 * self.displayFontSize * 0.78 / 17.0)
        
        var entities: [DrawingStickerEntity] = []
        for (emojiRect, emojiAttribute) in self.emojiRects {
            guard let file = emojiAttribute.file else {
                continue
            }
            let emojiTextPosition = emojiRect.center.offsetBy(dx: -textSize.width / 2.0, dy: -textSize.height / 2.0)
                        
            let entity = DrawingStickerEntity(file: file)
            entity.referenceDrawingSize = CGSize(width: itemSize * 2.5, height: itemSize * 2.5)
            entity.scale = scale
            entity.position = textPosition.offsetBy(
                dx: (emojiTextPosition.x * cos(rotation) + emojiTextPosition.y * sin(rotation)) * scale,
                dy: (emojiTextPosition.y * cos(rotation) + emojiTextPosition.x * sin(rotation)) * scale
            )
            entity.rotation = rotation
            entities.append(entity)
        }
        return entities
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
        
        self.snapTool.onSnapXUpdated = { [weak self] snapped in
            if let strongSelf = self, let entityView = strongSelf.entityView {
                entityView.onSnapToXAxis(snapped)
            }
        }
        
        self.snapTool.onSnapYUpdated = { [weak self] snapped in
            if let strongSelf = self, let entityView = strongSelf.entityView {
                entityView.onSnapToYAxis(snapped)
            }
        }
        
        self.snapTool.onSnapRotationUpdated = { [weak self] snappedAngle in
            if let strongSelf = self, let entityView = strongSelf.entityView {
                entityView.onSnapToAngle(snappedAngle)
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
    @objc private func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
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
                        return
                    }
                }
            }
            self.currentHandle = self.layer
        case .changed:
            let delta = gestureRecognizer.translation(in: entityView.superview)
            let parentLocation = gestureRecognizer.location(in: self.superview)
            let velocity = gestureRecognizer.velocity(in: entityView.superview)
            
            var updatedScale = entity.scale
            var updatedPosition = entity.position
            var updatedRotation = entity.rotation
            
            if self.currentHandle === self.leftHandle || self.currentHandle === self.rightHandle {
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
                
                //let delta = newAngle - updatedRotation
                updatedRotation = newAngle //" self.snapTool.update(entityView: entityView, velocity: 0.0, delta: delta, updatedRotation: newAngle)
            } else if self.currentHandle === self.layer {
                updatedPosition.x += delta.x
                updatedPosition.y += delta.y
                
                updatedPosition = self.snapTool.update(entityView: entityView, velocity: velocity, delta: delta, updatedPosition: updatedPosition)
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
            let scale = gestureRecognizer.scale
            entity.scale = max(0.1, entity.scale * scale)
            entityView.update()

            gestureRecognizer.scale = 1.0
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
        case .changed:
            rotation = gestureRecognizer.rotation
            updatedRotation += rotation
            
            gestureRecognizer.rotation = 0.0
        case .ended, .cancelled:
            self.snapTool.rotationReset()
        default:
            break
        }
        
        updatedRotation = self.snapTool.update(entityView: entityView, velocity: velocity, delta: rotation, updatedRotation: updatedRotation)
        entity.rotation = updatedRotation
        entityView.update()
        
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
                        
            context.setBlendMode(.copy)
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

class DrawingTextView: UITextView {
    fileprivate var drawingLayoutManager: DrawingTextLayoutManager {
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
