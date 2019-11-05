import Foundation
#if os(macOS)
import PostboxMac
#else
import Postbox
#endif

func processRemovedMedia(_ mediaBox: MediaBox, _ media: Media) {
    if let image = media as? TelegramMediaImage {
        let _ = mediaBox.removeCachedResources(Set(image.representations.map({ WrappedMediaResourceId($0.resource.id) }))).start()
    } else if let file = media as? TelegramMediaFile {
        let _ = mediaBox.removeCachedResources(Set(file.previewRepresentations.map({ WrappedMediaResourceId($0.resource.id) }))).start()
        let _ = mediaBox.removeCachedResources(Set([WrappedMediaResourceId(file.resource.id)])).start()
    }
}
