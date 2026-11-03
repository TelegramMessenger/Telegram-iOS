import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import Display

public func mapResourceToAvatarSizes(engine: TelegramEngine, resource: EngineMediaResource, representations: [TelegramMediaImageRepresentation]) -> Signal<[Int: Data], NoError> {
    return engine.resources.data(id: resource.id)
    |> take(1)
    |> map { data -> [Int: Data] in
        guard data.isComplete, let image = UIImage(contentsOfFile: data.path) else {
            return [:]
        }
        var result: [Int: Data] = [:]
        for i in 0 ..< representations.count {
            let size: CGSize
            if representations[i].dimensions.width == 80 {
                size = CGSize(width: 160.0, height: 160.0)
            } else {
                size = representations[i].dimensions.cgSize
            }
            if let scaledImage = generateScaledImage(image: image, size: size, scale: 1.0), let scaledData = scaledImage.jpegData(compressionQuality: 0.8) {
                result[i] = scaledData
            }
        }
        return result
    }
}
