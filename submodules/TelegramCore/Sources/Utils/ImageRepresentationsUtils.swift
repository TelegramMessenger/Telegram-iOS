import Postbox
import TelegramApi
import MtProtoKit

public func smallestVideoRepresentation(_ representations: [TelegramMediaImage.VideoRepresentation]) -> TelegramMediaImage.VideoRepresentation? {
    if representations.count == 0 {
        return nil
    } else {
        var dimensions = representations[0].dimensions
        var index = 0
        
        for i in 1 ..< representations.count {
            let representationDimensions = representations[i].dimensions
            if representationDimensions.width < dimensions.width && representationDimensions.height < dimensions.height {
                dimensions = representationDimensions
                index = i
            }
        }
        
        return representations[index]
    }
}

public func smallestImageRepresentation(_ representations: [TelegramMediaImageRepresentation]) -> TelegramMediaImageRepresentation? {
    if representations.count == 0 {
        return nil
    } else {
        var dimensions = representations[0].dimensions
        var index = 0
        
        for i in 1 ..< representations.count {
            let representationDimensions = representations[i].dimensions
            if representationDimensions.width < dimensions.width && representationDimensions.height < dimensions.height {
                dimensions = representationDimensions
                index = i
            }
        }
        
        return representations[index]
    }
}

public func largestImageRepresentation(_ representations: [TelegramMediaImageRepresentation]) -> TelegramMediaImageRepresentation? {
    if representations.count == 0 {
        return nil
    } else {
        var dimensions = representations[0].dimensions
        var index = 0
        
        for i in 1 ..< representations.count {
            let representationDimensions = representations[i].dimensions
            if representationDimensions.width > dimensions.width && representationDimensions.height > dimensions.height {
                dimensions = representationDimensions
                index = i
            }
        }
        
        return representations[index]
    }
}

public func imageRepresentationLargerThan(_ representations: [TelegramMediaImageRepresentation], size: PixelDimensions) -> TelegramMediaImageRepresentation? {
    if representations.count == 0 {
        return nil
    } else {
        var index: Int?
        
        for i in 0 ..< representations.count {
            let representationDimensions = representations[i].dimensions
            if let rindex = index {
                let dimensions = representations[rindex].dimensions
                if representationDimensions.width > size.width && representationDimensions.height > size.height && representationDimensions.width < dimensions.width && representationDimensions.height < dimensions.height {
                    index = i
                }
            } else {
                if representationDimensions.width > size.width && representationDimensions.height > size.height {
                    index = i
                }
            }
        }
        
        if let index = index {
            return representations[index]
        } else {
            return largestImageRepresentation(representations)
        }
    }
}

public func progressiveImageRepresentation(_ representations: [TelegramMediaImageRepresentation]) -> TelegramMediaImageRepresentation? {
    for representation in representations {
        if representation.progressiveSizes.count > 1 {
            return representation
        }
    }
    return nil
}

public func parseMediaData(data: Data) -> Media? {
    let buffer = BufferReader(Buffer(data: data))
    var parseBuffer: Buffer?
    guard let signature = buffer.readInt32() else {
        return nil
    }
    if signature == 0x3072cfa1 {
        parseBuffer = parseBytes(buffer).flatMap({ $0.makeData() }).flatMap(MTGzip.decompress).flatMap(Buffer.init(data:))
    } else {
        parseBuffer = Buffer(data: data)
    }
    
    if let parseBuffer = parseBuffer, let object = Api.parse(parseBuffer) {
        if let photo = object as? Api.Photo {
            return telegramMediaImageFromApiPhoto(photo)
        } else if let document = object as? Api.Document {
            return telegramMediaFileFromApiDocument(document)
        }
    }
    return nil
}
