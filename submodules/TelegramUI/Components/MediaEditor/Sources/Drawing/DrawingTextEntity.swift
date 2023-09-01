import Foundation
import UIKit
import Display
import AccountContext
import TextFormat

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
        case animation
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
        case renderAnimationFrames
    }
    
    public enum Style: Codable, Equatable {
        case regular
        case filled
        case semi
        case stroke
    }
    
    public enum Animation: Codable, Equatable {
        case none
        case typing
        case wiggle
        case zoomIn
    }
    
    public enum Font: Codable, Equatable {
        case sanFrancisco
        case other(String, String)
    }
    
    public enum Alignment: Codable, Equatable {
        case left
        case center
        case right
    }
    
    public var uuid: UUID
    public var isAnimated: Bool {
        if self.animation != .none {
            return true
        }
        var isAnimated = false
        self.text.enumerateAttributes(in: NSMakeRange(0, self.text.length), options: [], using: { attributes, range, _ in
            if let _ = attributes[ChatTextInputAttributes.customEmoji] as? ChatTextInputTextCustomEmojiAttribute {
                isAnimated = true
            }
        })
        return isAnimated
    }
    
    public var text: NSAttributedString
    public var style: Style
    public var animation: Animation
    public var font: Font
    public var alignment: Alignment
    public var fontSize: CGFloat
    public var color: DrawingColor
    public var lineWidth: CGFloat = 0.0
    
    public var referenceDrawingSize: CGSize
    public var position: CGPoint
    public var width: CGFloat
    public var scale: CGFloat
    public var rotation: CGFloat
    
    public var center: CGPoint {
        return self.position
    }
    
    public var renderImage: UIImage?
    public var renderSubEntities: [DrawingEntity]?
    
    public var isMedia: Bool {
        return false
    }
    
    public class AnimationFrame: Codable {
        private enum CodingKeys: String, CodingKey {
            case timestamp
            case duration
            case image
        }
        
        public let timestamp: Double
        public let duration: Double
        public let image: UIImage
        
        public init(timestamp: Double, duration: Double, image: UIImage) {
            self.timestamp = timestamp
            self.duration = duration
            self.image = image
        }
        
        required public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.timestamp = try container.decode(Double.self, forKey: .timestamp)
            self.duration = try container.decode(Double.self, forKey: .duration)
            if let renderImageData = try? container.decodeIfPresent(Data.self, forKey: .image) {
                self.image = UIImage(data: renderImageData)!
            } else {
                fatalError()
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
          
            try container.encode(self.timestamp, forKey: .timestamp)
            try container.encode(self.duration, forKey: .duration)
            if let data = self.image.pngData() {
                try container.encode(data, forKey: .image)
            }
        }
    }
    public var renderAnimationFrames: [AnimationFrame]?
    
    public init(text: NSAttributedString, style: Style, animation: Animation, font: Font, alignment: Alignment, fontSize: CGFloat, color: DrawingColor) {
        self.uuid = UUID()
        
        self.text = text
        self.style = style
        self.animation = animation
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
        self.animation = try container.decode(Animation.self, forKey: .animation)
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
        self.renderAnimationFrames = try container.decodeIfPresent([AnimationFrame].self, forKey: .renderAnimationFrames)
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
        try container.encode(self.animation, forKey: .animation)
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
            let codableEntities: [CodableDrawingEntity] = renderSubEntities.compactMap { CodableDrawingEntity(entity: $0) }
            try container.encode(codableEntities, forKey: .renderSubEntities)
        }
        if let renderAnimationFrames = self.renderAnimationFrames {
            try container.encode(renderAnimationFrames, forKey: .renderAnimationFrames)
        }
    }

    public func duplicate() -> DrawingEntity {
        let newEntity = DrawingTextEntity(text: self.text, style: self.style, animation: self.animation, font: self.font, alignment: self.alignment, fontSize: self.fontSize, color: self.color)
        newEntity.referenceDrawingSize = self.referenceDrawingSize
        newEntity.position = self.position
        newEntity.width = self.width
        newEntity.scale = self.scale
        newEntity.rotation = self.rotation
        return newEntity
    }
    
    public func isEqual(to other: DrawingEntity) -> Bool {
        guard let other = other as? DrawingTextEntity else {
            return false
        }
        if self.uuid != other.uuid {
            return false
        }
        if self.text != other.text {
            return false
        }
        if self.style != other.style {
            return false
        }
        if self.animation != other.animation {
            return false
        }
        if self.font != other.font {
            return false
        }
        if self.alignment != other.alignment {
            return false
        }
        if self.fontSize != other.fontSize {
            return false
        }
        if self.color != other.color {
            return false
        }
        if self.referenceDrawingSize != other.referenceDrawingSize {
            return false
        }
        if self.position != other.position {
            return false
        }
        if self.width != other.width {
            return false
        }
        if self.scale != other.scale {
            return false
        }
        if self.rotation != other.rotation {
            return false
        }
        return true
    }
}
