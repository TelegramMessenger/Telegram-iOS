import Postbox

public final class TelegramMediaGame: Media {
    public let gameId: Int64
    public let accessHash: Int64
    public let name: String
    public let title: String
    public let description: String
    public let image: TelegramMediaImage?
    public let file: TelegramMediaFile?
    
    public var id: MediaId? {
        return MediaId(namespace: Namespaces.Media.CloudGame, id: self.gameId)
    }
    public let peerIds: [PeerId] = []
    
    public init(gameId: Int64, accessHash: Int64, name: String, title: String, description: String, image: TelegramMediaImage?, file: TelegramMediaFile?) {
        self.gameId = gameId
        self.accessHash = accessHash
        self.name = name
        self.title = title
        self.description = description
        self.image = image
        self.file = file
    }
    
    public init(decoder: PostboxDecoder) {
        self.gameId = decoder.decodeInt64ForKey("i", orElse: 0)
        self.accessHash = decoder.decodeInt64ForKey("h", orElse: 0)
        self.name = decoder.decodeStringForKey("n", orElse: "")
        self.title = decoder.decodeStringForKey("t", orElse: "")
        self.description = decoder.decodeStringForKey("d", orElse: "")
        self.image = decoder.decodeObjectForKey("p") as? TelegramMediaImage
        self.file = decoder.decodeObjectForKey("f") as? TelegramMediaFile
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.gameId, forKey: "i")
        encoder.encodeInt64(self.accessHash, forKey: "h")
        encoder.encodeString(self.name, forKey: "n")
        encoder.encodeString(self.title, forKey: "t")
        encoder.encodeString(self.description, forKey: "d")
        if let image = self.image {
            encoder.encodeObject(image, forKey: "p")
        } else {
            encoder.encodeNil(forKey: "p")
        }
        if let file = self.file {
            encoder.encodeObject(file, forKey: "f")
        } else {
            encoder.encodeNil(forKey: "f")
        }
    }
    
    public func isEqual(to other: Media) -> Bool {
        guard let other = other as? TelegramMediaGame else {
            return false
        }
        
        if self.gameId != other.gameId {
            return false
        }
        
        if self.accessHash != other.accessHash {
            return false
        }
        
        if self.name != other.name {
            return false
        }
        
        if self.title != other.title {
            return false
        }
        
        if self.description != other.description {
            return false
        }
        
        if let lhsImage = self.image, let rhsImage = other.image {
            if !lhsImage.isEqual(to: rhsImage) {
                return false
            }
        } else if (self.image != nil) != (other.image != nil) {
            return false
        }
        
        if let lhsFile = self.file, let rhsFile = other.file {
            if !lhsFile.isEqual(to: rhsFile) {
                return false
            }
        } else if (self.file != nil) != (other.file != nil) {
            return false
        }
        
        return true
    }
    
    public func isSemanticallyEqual(to other: Media) -> Bool {
        return self.isEqual(to: other)
    }
}
