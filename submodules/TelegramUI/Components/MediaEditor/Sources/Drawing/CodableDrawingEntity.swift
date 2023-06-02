import Foundation

public enum CodableDrawingEntity: Equatable {
    public static func == (lhs: CodableDrawingEntity, rhs: CodableDrawingEntity) -> Bool {
        return lhs.entity.isEqual(to: rhs.entity)
    }
    
    case sticker(DrawingStickerEntity)
    case text(DrawingTextEntity)
    case simpleShape(DrawingSimpleShapeEntity)
    case bubble(DrawingBubbleEntity)
    case vector(DrawingVectorEntity)
    
    public init?(entity: DrawingEntity) {
        if let entity = entity as? DrawingStickerEntity {
            self = .sticker(entity)
        } else if let entity = entity as? DrawingTextEntity {
            self = .text(entity)
        } else if let entity = entity as? DrawingSimpleShapeEntity {
            self = .simpleShape(entity)
        } else if let entity = entity as? DrawingBubbleEntity {
            self = .bubble(entity)
        } else if let entity = entity as? DrawingVectorEntity {
            self = .vector(entity)
        } else {
            return nil
        }
    }
    
    public var entity: DrawingEntity {
        switch self {
        case let .sticker(entity):
            return entity
        case let .text(entity):
            return entity
        case let .simpleShape(entity):
            return entity
        case let .bubble(entity):
            return entity
        case let .vector(entity):
            return entity
        }
    }
}

extension CodableDrawingEntity: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case entity
    }

    private enum EntityType: Int, Codable {
        case sticker
        case text
        case simpleShape
        case bubble
        case vector
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(EntityType.self, forKey: .type)
        switch type {
        case .sticker:
            self = .sticker(try container.decode(DrawingStickerEntity.self, forKey: .entity))
        case .text:
            self = .text(try container.decode(DrawingTextEntity.self, forKey: .entity))
        case .simpleShape:
            self = .simpleShape(try container.decode(DrawingSimpleShapeEntity.self, forKey: .entity))
        case .bubble:
            self = .bubble(try container.decode(DrawingBubbleEntity.self, forKey: .entity))
        case .vector:
            self = .vector(try container.decode(DrawingVectorEntity.self, forKey: .entity))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .sticker(payload):
            try container.encode(EntityType.sticker, forKey: .type)
            try container.encode(payload, forKey: .entity)
        case let .text(payload):
            try container.encode(EntityType.text, forKey: .type)
            try container.encode(payload, forKey: .entity)
        case let .simpleShape(payload):
            try container.encode(EntityType.simpleShape, forKey: .type)
            try container.encode(payload, forKey: .entity)
        case let .bubble(payload):
            try container.encode(EntityType.bubble, forKey: .type)
            try container.encode(payload, forKey: .entity)
        case let .vector(payload):
            try container.encode(EntityType.vector, forKey: .type)
            try container.encode(payload, forKey: .entity)
        }
    }
}
