#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

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

public func imageRepresentationLargerThan(_ representations: [TelegramMediaImageRepresentation], size: CGSize) -> TelegramMediaImageRepresentation? {
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
