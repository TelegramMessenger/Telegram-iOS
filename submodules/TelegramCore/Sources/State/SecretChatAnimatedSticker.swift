import Foundation
import Postbox

func secretChatAnimatedStickerPackReferences(_ files: [TelegramMediaFile]) -> Set<StickerPackReference> {
    var result = Set<StickerPackReference>()
    for file in files {
        guard file.fileId.namespace == Namespaces.Media.CloudFile, file.isAnimatedSticker else {
            continue
        }
        for attribute in file.attributes {
            if case let .Sticker(_, packReference?, _) = attribute {
                switch packReference {
                case .id, .name:
                    result.insert(packReference)
                default:
                    break
                }
            }
        }
    }
    return result
}

// Only call with documents returned by getStickerSet, never with the peer's unverified metadata.
func validatedSecretChatAnimatedSticker(_ file: TelegramMediaFile, requestedFileIds: Set<MediaId>) -> TelegramMediaFile? {
    guard file.fileId.namespace == Namespaces.Media.CloudFile, requestedFileIds.contains(file.fileId), file.isSticker, file.isAnimatedSticker else {
        return nil
    }
    var attributes = file.attributes
    if !attributes.contains(where: { attribute in
        if case .hintIsValidated = attribute {
            return true
        }
        return false
    }) {
        attributes.append(.hintIsValidated)
    }
    return file.withUpdatedAttributes(attributes)
}
