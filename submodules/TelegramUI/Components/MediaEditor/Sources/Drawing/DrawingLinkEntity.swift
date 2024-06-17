import Foundation
import UIKit
import Display
import AccountContext
import TextFormat
import Postbox
import TelegramCore

public final class DrawingLinkEntity: DrawingEntity, Codable {
    private enum CodingKeys: String, CodingKey {
        case uuid
        case url
        case name
        case webpage
        case positionBelowText
        case largeMedia
        case expandedSize
        case style
        case color
        case hasCustomColor
        case referenceDrawingSize
        case position
        case width
        case scale
        case rotation
        case renderImage
        case whiteImage
        case blackImage
    }
    
    public enum Style: Codable, Equatable {
        case white
        case black
        case transparent
        case custom
        case blur
    }
    
    public var uuid: UUID
    public var isAnimated: Bool {
        return false
    }
        
    public var url: String
    public var name: String
    public var webpage: TelegramMediaWebpage?
    public var positionBelowText: Bool
    public var largeMedia: Bool?
    public var expandedSize: CGSize?
    public var style: Style
    
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
    
    public var whiteImage: UIImage?
    public var blackImage: UIImage?
    
    public var renderImage: UIImage?
    public var renderSubEntities: [DrawingEntity]?
    
    public var isMedia: Bool {
        return false
    }
    
    public init(
        url: String,
        name: String,
        webpage: TelegramMediaWebpage?,
        positionBelowText: Bool,
        largeMedia: Bool?,
        style: Style
    ) {
        self.uuid = UUID()
        
        self.url = url
        self.name = name
        self.webpage = webpage
        self.positionBelowText = positionBelowText
        self.largeMedia = largeMedia
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
        self.url = try container.decode(String.self, forKey: .url)
        self.name = try container.decode(String.self, forKey: .name)
        self.positionBelowText = try container.decode(Bool.self, forKey: .positionBelowText)
        self.largeMedia = try container.decodeIfPresent(Bool.self, forKey: .largeMedia)
        self.style = try container.decode(Style.self, forKey: .style)
        
        if let webpageData = try container.decodeIfPresent(Data.self, forKey: .webpage) {
            self.webpage = PostboxDecoder(buffer: MemoryBuffer(data: webpageData)).decodeRootObject() as? TelegramMediaWebpage
        } else {
            self.webpage = nil
        }
        
        self.color = try container.decodeIfPresent(DrawingColor.self, forKey: .color) ?? DrawingColor(color: .white)
        self.hasCustomColor = try container.decodeIfPresent(Bool.self, forKey: .hasCustomColor) ?? false
                
        self.referenceDrawingSize = try container.decode(CGSize.self, forKey: .referenceDrawingSize)
        self.position = try container.decode(CGPoint.self, forKey: .position)
        self.width = try container.decode(CGFloat.self, forKey: .width)
        self.scale = try container.decode(CGFloat.self, forKey: .scale)
        self.rotation = try container.decode(CGFloat.self, forKey: .rotation)
        
        if let imagePath = try container.decodeIfPresent(String.self, forKey: .whiteImage), let image = UIImage(contentsOfFile: fullEntityMediaPath(imagePath)) {
            self.whiteImage = image
        }
        
        if let imagePath = try container.decodeIfPresent(String.self, forKey: .blackImage), let image = UIImage(contentsOfFile: fullEntityMediaPath(imagePath)) {
            self.blackImage = image
        }
                
        if let renderImageData = try? container.decodeIfPresent(Data.self, forKey: .renderImage) {
            self.renderImage = UIImage(data: renderImageData)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.uuid, forKey: .uuid)
        try container.encode(self.url, forKey: .url)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.positionBelowText, forKey: .positionBelowText)
        try container.encodeIfPresent(self.largeMedia, forKey: .largeMedia)
        
        if let webpage = self.webpage {
            let encoder = PostboxEncoder()
            encoder.encodeRootObject(webpage)
            let webpageData = encoder.makeData()
            try container.encode(webpageData, forKey: .webpage)
        } else {
            try container.encodeNil(forKey: .webpage)
        }
        
        try container.encode(self.style, forKey: .style)
        try container.encode(self.color, forKey: .color)
        try container.encode(self.hasCustomColor, forKey: .hasCustomColor)
        
        try container.encode(self.referenceDrawingSize, forKey: .referenceDrawingSize)
        try container.encode(self.position, forKey: .position)
        try container.encode(self.width, forKey: .width)
        try container.encode(self.scale, forKey: .scale)
        try container.encode(self.rotation, forKey: .rotation)    
        
        if let image = self.whiteImage {
            let imagePath = "\(self.uuid)_white.png"
            let fullImagePath = fullEntityMediaPath(imagePath)
            if let imageData = image.pngData() {
                try? FileManager.default.createDirectory(atPath: entitiesPath(), withIntermediateDirectories: true)
                try? imageData.write(to: URL(fileURLWithPath: fullImagePath))
                try container.encodeIfPresent(imagePath, forKey: .whiteImage)
            }
        }
        
        if let image = self.blackImage {
            let imagePath = "\(self.uuid)black.png"
            let fullImagePath = fullEntityMediaPath(imagePath)
            if let imageData = image.pngData() {
                try? FileManager.default.createDirectory(atPath: entitiesPath(), withIntermediateDirectories: true)
                try? imageData.write(to: URL(fileURLWithPath: fullImagePath))
                try container.encodeIfPresent(imagePath, forKey: .blackImage)
            }
        }
        
        if let renderImage = self.renderImage, let data = renderImage.pngData() {
            try container.encode(data, forKey: .renderImage)
        }
    }

    public func duplicate(copy: Bool) -> DrawingEntity {
        let newEntity = DrawingLinkEntity(url: self.url, name: self.name, webpage: self.webpage, positionBelowText: self.positionBelowText, largeMedia: self.largeMedia, style: self.style)
        if copy {
            newEntity.uuid = self.uuid
        }
        newEntity.referenceDrawingSize = self.referenceDrawingSize
        newEntity.position = self.position
        newEntity.width = self.width
        newEntity.scale = self.scale
        newEntity.rotation = self.rotation
        newEntity.whiteImage = self.whiteImage
        newEntity.blackImage = self.blackImage
        return newEntity
    }
    
    public func isEqual(to other: DrawingEntity) -> Bool {
        guard let other = other as? DrawingLinkEntity else {
            return false
        }
        if self.uuid != other.uuid {
            return false
        }
        if self.url != other.url {
            return false
        }
        if self.name != other.name {
            return false
        }
        if self.webpage != other.webpage {
            return false
        }
        if self.positionBelowText != other.positionBelowText {
            return false
        }
        if self.largeMedia != other.largeMedia {
            return false
        }
        if self.style != other.style {
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
