import Foundation
import UIKit
import Display
import AccountContext
import TextFormat
import Postbox
import TelegramCore

public final class DrawingWeatherEntity: DrawingEntity, Codable {
    private enum CodingKeys: String, CodingKey {
        case uuid
        case style
        case color
        case hasCustomColor
        case emoji
        case temperature
        case icon
        case referenceDrawingSize
        case position
        case width
        case scale
        case rotation
        case renderImage
    }
    
    public enum Style: Codable, Equatable {
        case white
        case black
        case transparent
        case custom
    }
    
    public var uuid: UUID
    public var isAnimated: Bool {
        return false
    }
    
    
    public var style: Style
    public var icon: TelegramMediaFile?
    public var emoji: String
    public var temperature: Double
    
    public var color: DrawingColor = DrawingColor(color: .white)  {
        didSet {
            if self.color.toUIColor().argb == UIColor.white.argb {
                self.style = .white
                self.hasCustomColor = false
            } else {
                self.style = .custom
                self.hasCustomColor = true
            }
        }
    }
    public var hasCustomColor = false
    public var lineWidth: CGFloat = 0.0
    
    public var referenceDrawingSize: CGSize
    public var position: CGPoint
    public var width: CGFloat
    public var scale: CGFloat {
        didSet {
            self.scale = min(2.5, self.scale)
        }
    }
    public var rotation: CGFloat
    
    public var center: CGPoint {
        return self.position
    }
    
    public var renderImage: UIImage?
    public var renderSubEntities: [DrawingEntity]?
    
    public var isMedia: Bool {
        return false
    }
    
    public init(emoji: String, emojiFile: TelegramMediaFile?, temperature: Double, style: Style) {
        self.uuid = UUID()
        
        self.emoji = emoji
        self.icon = emojiFile
        self.temperature = temperature
        self.style = style

        self.referenceDrawingSize = .zero
        self.position = .zero
        self.width = 100.0
        self.scale = 1.0
        self.rotation = 0.0
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.uuid = try container.decode(UUID.self, forKey: .uuid)
        self.emoji = try container.decode(String.self, forKey: .emoji)
        self.temperature = try container.decode(Double.self, forKey: .temperature)
        self.style = try container.decode(Style.self, forKey: .style)
        self.color = try container.decodeIfPresent(DrawingColor.self, forKey: .color) ?? DrawingColor(color: .white)
        self.hasCustomColor = try container.decodeIfPresent(Bool.self, forKey: .hasCustomColor) ?? false
        
        if let iconData = try container.decodeIfPresent(Data.self, forKey: .icon) {
            self.icon = PostboxDecoder(buffer: MemoryBuffer(data: iconData)).decodeRootObject() as? TelegramMediaFile
        }

        self.referenceDrawingSize = try container.decode(CGSize.self, forKey: .referenceDrawingSize)
        self.position = try container.decode(CGPoint.self, forKey: .position)
        self.width = try container.decode(CGFloat.self, forKey: .width)
        self.scale = try container.decode(CGFloat.self, forKey: .scale)
        self.rotation = try container.decode(CGFloat.self, forKey: .rotation)
        if let renderImageData = try? container.decodeIfPresent(Data.self, forKey: .renderImage) {
            self.renderImage = UIImage(data: renderImageData)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.uuid, forKey: .uuid)
        try container.encode(self.emoji, forKey: .emoji)
        try container.encode(self.temperature, forKey: .temperature)
        try container.encode(self.style, forKey: .style)
        try container.encode(self.color, forKey: .color)
        try container.encode(self.hasCustomColor, forKey: .hasCustomColor)
        
        var encoder = PostboxEncoder()
        if let icon = self.icon {
            encoder = PostboxEncoder()
            encoder.encodeRootObject(icon)
            let iconData = encoder.makeData()
            try container.encode(iconData, forKey: .icon)
        }
        
        try container.encode(self.referenceDrawingSize, forKey: .referenceDrawingSize)
        try container.encode(self.position, forKey: .position)
        try container.encode(self.width, forKey: .width)
        try container.encode(self.scale, forKey: .scale)
        try container.encode(self.rotation, forKey: .rotation)
        if let renderImage, let data = renderImage.pngData() {
            try container.encode(data, forKey: .renderImage)
        }
    }

    public func duplicate(copy: Bool) -> DrawingEntity {
        let newEntity = DrawingWeatherEntity(emoji: self.emoji, emojiFile: self.icon, temperature: self.temperature, style: self.style)
        if copy {
            newEntity.uuid = self.uuid
        }
        newEntity.referenceDrawingSize = self.referenceDrawingSize
        newEntity.position = self.position
        newEntity.width = self.width
        newEntity.scale = self.scale
        newEntity.rotation = self.rotation
        return newEntity
    }
    
    public func isEqual(to other: DrawingEntity) -> Bool {
        guard let other = other as? DrawingWeatherEntity else {
            return false
        }
        if self.uuid != other.uuid {
            return false
        }
        if self.emoji != other.emoji {
            return false
        }
        if self.temperature != other.temperature {
            return false
        }
        if self.style != other.style {
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
