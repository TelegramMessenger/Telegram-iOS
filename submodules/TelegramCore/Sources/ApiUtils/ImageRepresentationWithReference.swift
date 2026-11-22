import Foundation

public struct ImageRepresentationWithReference: Equatable {
    public let representation: TelegramMediaImageRepresentation
    public let reference: MediaResourceReference
    
    public init(representation: TelegramMediaImageRepresentation, reference: MediaResourceReference) {
        self.representation = representation
        self.reference = reference
    }
}


public struct VideoRepresentationWithReference: Equatable {
    public let representation: TelegramMediaImage.VideoRepresentation
    public let reference: MediaResourceReference
    
    public init(representation: TelegramMediaImage.VideoRepresentation, reference: MediaResourceReference) {
        self.representation = representation
        self.reference = reference
    }
}
