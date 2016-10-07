import TelegramCore

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
