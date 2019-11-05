import Foundation

public struct ImageRepresentationWithReference: Equatable {
    public let representation: TelegramMediaImageRepresentation
    public let reference: MediaResourceReference
    
    public init(representation: TelegramMediaImageRepresentation, reference: MediaResourceReference) {
        self.representation = representation
        self.reference = reference
    }
}
