//
//  File.swift
//  
//
//  Created by Mikhail Filimonov on 25.01.2024.
//

import Foundation
import Postbox
import SwiftSignalKit

public struct TelegramApplicationIcons : PostboxCoding, Equatable {
    public init(decoder: PostboxDecoder) {
        self.icons = (try? decoder.decodeObjectArrayWithCustomDecoderForKey("i", decoder: { Icon(decoder: $0) })) ?? []
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.icons, forKey: "i")
    }
    
    public struct Icon : PostboxCoding, Equatable {
        public init(decoder: PostboxDecoder) {
            self.file = decoder.decodeObjectForKey("f") as! TelegramMediaFile
            self.reference = decoder.decodeObjectForKey("r", decoder: { MessageReference(decoder: $0) }) as! MessageReference
        }
        
        public func encode(_ encoder: PostboxEncoder) {
            encoder.encodeObject(self.file, forKey: "f")
            encoder.encodeObject(self.reference, forKey: "r")
        }
        
        public let file: TelegramMediaFile
        public let reference: MessageReference
        init(file: TelegramMediaFile, reference: MessageReference) {
            self.file = file
            self.reference = reference
        }
    }
    public var icons: [Icon]
    
    init(icons: [Icon]) {
        self.icons = icons
    }
    
    static var entryId: ItemCacheEntryId {
        let cacheKey = ValueBoxKey(length: 1)
        cacheKey.setInt8(0, value: 0)
        return ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.applicationIcons, key: cacheKey)
    }
}


func _internal_applicationIcons(account: Account) -> Signal<TelegramApplicationIcons, NoError> {
    let key = PostboxViewKey.cachedItem(TelegramApplicationIcons.entryId)
    return account.postbox.combinedView(keys: [key])
    |> mapToSignal { views -> Signal<TelegramApplicationIcons, NoError> in
        guard let icons = (views.views[key] as? CachedItemView)?.value?.getLegacy(TelegramApplicationIcons.self) as? TelegramApplicationIcons else {
            return .single(.init(icons: []))
        }
        return .single(icons)
    }
}

func _internal_updateApplicationIcons(postbox: Postbox, icons: TelegramApplicationIcons) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        let entry = CodableEntry(legacyValue: icons)
        transaction.putItemCacheEntry(id: TelegramApplicationIcons.entryId, entry: entry)
    }
}


