import SwiftSignalKit
import Postbox

public extension TelegramEngine.EngineData.Item {
    enum Collections {
        public struct FeaturedStickerPacks: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = [FeaturedStickerPackItem]
            
            public init() {
            }
            
            var key: PostboxViewKey {
                return .orderedItemList(id: Namespaces.OrderedItemList.CloudFeaturedStickerPacks)
            }
            
            func extract(view: PostboxView) -> Result {
                guard let view = view as? OrderedItemListView else {
                    preconditionFailure()
                }
                return view.items.compactMap { item in
                    return item.contents.get(FeaturedStickerPackItem.self)
                }
            }
        }
        
        public struct FeaturedEmojiPacks: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = [FeaturedStickerPackItem]
            
            public init() {
            }
            
            var key: PostboxViewKey {
                return .orderedItemList(id: Namespaces.OrderedItemList.CloudFeaturedEmojiPacks)
            }
            
            func extract(view: PostboxView) -> Result {
                guard let view = view as? OrderedItemListView else {
                    preconditionFailure()
                }
                return view.items.compactMap { item in
                    return item.contents.get(FeaturedStickerPackItem.self)
                }
            }
        }
    }
    
    enum OrderedLists {
        public struct NewBotConnectionReviews: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = [NewBotConnectionReview]

            public init() {
            }

            var key: PostboxViewKey {
                return .orderedItemList(id: Namespaces.OrderedItemList.NewBotConnectionReviews)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? OrderedItemListView else {
                    preconditionFailure()
                }
                return view.items.compactMap { item in
                    return item.contents.get(NewBotConnectionReview.self)
                }
            }
        }

        public struct ListItems: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = [OrderedItemListEntry]

            private let collectionId: Int32

            public init(collectionId: Int32) {
                self.collectionId = collectionId
            }

            var key: PostboxViewKey {
                return .orderedItemList(id: self.collectionId)
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? OrderedItemListView else {
                    preconditionFailure()
                }
                return view.items
            }
        }
    }

    enum ItemCollections {
        public struct InstalledPackInfos: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = [EngineRawItemCollectionInfoEntry]

            private let namespace: ItemCollectionId.Namespace

            public init(namespace: ItemCollectionId.Namespace) {
                self.namespace = namespace
            }

            var key: PostboxViewKey {
                return .itemCollectionInfos(namespaces: [self.namespace])
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? ItemCollectionInfosView else {
                    preconditionFailure()
                }
                return view.entriesByNamespace[self.namespace] ?? []
            }
        }

        public struct InstalledPackIds: TelegramEngineDataItem, PostboxViewDataItem {
            public typealias Result = [ItemCollectionId]

            private let namespace: ItemCollectionId.Namespace

            public init(namespace: ItemCollectionId.Namespace) {
                self.namespace = namespace
            }

            var key: PostboxViewKey {
                return .itemCollectionIds(namespaces: [self.namespace])
            }

            func extract(view: PostboxView) -> Result {
                guard let view = view as? ItemCollectionIdsView else {
                    preconditionFailure()
                }
                return Array(view.idsByNamespace[self.namespace] ?? [])
            }
        }
    }
}
