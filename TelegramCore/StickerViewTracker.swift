import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

final class StickerViewTracker {
    private let postbox: Postbox
    private let mediaBox: MediaBox
    
    init(postbox: Postbox, mediaBox: MediaBox) {
        self.postbox = postbox
        self.mediaBox = mediaBox
    }
    
    func wrappedStickerInfosView() -> Signal<CombinedView, NoError> {
        return self.postbox.combinedView(keys: [.itemCollectionInfos(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])])
    }
}
