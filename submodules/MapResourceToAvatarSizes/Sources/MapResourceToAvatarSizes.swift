import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import Display

public func mapResourceToAvatarSizes(postbox: Postbox, resource: MediaResource, representations: [TelegramMediaImageRepresentation]) -> Signal<[Int: Data], NoError> {
    return postbox.mediaBox.resourceData(resource)
    |> take(1)
    |> map { data -> [Int: Data] in
        guard data.complete, let image = UIImage(contentsOfFile: data.path) else {
            return [:]
        }
        var result: [Int: Data] = [:]
        for i in 0 ..< representations.count {
            if let scaledImage = generateScaledImage(image: image, size: representations[i].dimensions, scale: 1.0), let scaledData = scaledImage.jpegData(compressionQuality: 0.8) {
                result[i] = scaledData
            }
        }
        return result
    }
}
