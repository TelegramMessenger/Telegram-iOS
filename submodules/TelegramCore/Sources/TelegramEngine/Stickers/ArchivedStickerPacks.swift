import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit


public enum ArchivedStickerPacksNamespace: Int32 {
    case stickers = 0
    case masks = 1
    case emoji = 2
    
    var itemCollectionNamespace: ItemCollectionId.Namespace {
        switch self {
            case .stickers:
                return Namespaces.ItemCollection.CloudStickerPacks
            case .masks:
                return Namespaces.ItemCollection.CloudMaskPacks
            case .emoji:
                return Namespaces.ItemCollection.CloudEmojiPacks
        }
    }
}

public final class ArchivedStickerPackItem {
    public let info: StickerPackCollectionInfo
    public let topItems: [StickerPackItem]
    
    public init(info: StickerPackCollectionInfo, topItems: [StickerPackItem]) {
        self.info = info
        self.topItems = topItems
    }
}

func _internal_archivedStickerPacks(account: Account, namespace: ArchivedStickerPacksNamespace = .stickers) -> Signal<[ArchivedStickerPackItem], NoError> {
    var flags: Int32 = 0
    if case .masks = namespace {
        flags |= 1 << 0
    } else if case .emoji = namespace {
        flags |= 1 << 1
    }
    return account.network.request(Api.functions.messages.getArchivedStickers(flags: flags, offsetId: 0, limit: 200))
    |> map { result -> [ArchivedStickerPackItem] in
        var archivedItems: [ArchivedStickerPackItem] = []
        switch result {
            case let .archivedStickers(_, sets):
                for set in sets {
                    let (info, items) = parsePreviewStickerSet(set, namespace: namespace.itemCollectionNamespace)
                    archivedItems.append(ArchivedStickerPackItem(info: info, topItems: items))
                }
        }
        return archivedItems
    } |> `catch` { _ in
        return .single([])
    }
}

func _internal_removeArchivedStickerPack(account: Account, info: StickerPackCollectionInfo) -> Signal<Void, NoError> {
    return account.network.request(Api.functions.messages.uninstallStickerSet(stickerset: Api.InputStickerSet.inputStickerSetID(id: info.id.id, accessHash: info.accessHash)))
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .single(.boolFalse)
    }
    |> mapToSignal { _ -> Signal<Void, NoError> in
        return .complete()
    }
}
