import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public final class ArchivedStickerPackItem {
    public let info: StickerPackCollectionInfo
    public let topItems: [StickerPackItem]
    
    public init(info: StickerPackCollectionInfo, topItems: [StickerPackItem]) {
        self.info = info
        self.topItems = topItems
    }
}

public func archivedStickerPacks(account: Account) -> Signal<[ArchivedStickerPackItem], NoError> {
    return account.network.request(Api.functions.messages.getArchivedStickers(flags: 0, offsetId: 0, limit: 100))
        |> map { result -> [ArchivedStickerPackItem] in
            var archivedItems: [ArchivedStickerPackItem] = []
            switch result {
                case let .archivedStickers(count, sets):
                    for set in sets {
                        let (info, items) = parsePreviewStickerSet(set)
                        archivedItems.append(ArchivedStickerPackItem(info: info, topItems: items))
                    }
            }
            return archivedItems
        } |> `catch` { _ in
            return .single([])
        }
}

public func removeArchivedStickerPack(account: Account, info: StickerPackCollectionInfo) -> Signal<Void, NoError> {
    return account.network.request(Api.functions.messages.uninstallStickerSet(stickerset: Api.InputStickerSet.inputStickerSetID(id: info.id.id, accessHash: info.accessHash)))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> mapToSignal { _ -> Signal<Void, NoError> in
            return .complete()
        }
}
