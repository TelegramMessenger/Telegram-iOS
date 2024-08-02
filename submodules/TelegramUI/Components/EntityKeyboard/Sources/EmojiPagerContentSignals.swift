import Foundation
import UIKit
import AccountContext
import TelegramCore
import Postbox
import SwiftSignalKit
import AnimationCache
import MultiAnimationRenderer
import TelegramNotices

public extension EmojiPagerContentComponent {    
    private static func hasPremium(context: AccountContext, chatPeerId: EnginePeer.Id?, premiumIfSavedMessages: Bool) -> Signal<Bool, NoError> {
        let hasPremium: Signal<Bool, NoError>
        if premiumIfSavedMessages, let chatPeerId = chatPeerId, chatPeerId == context.account.peerId {
            hasPremium = .single(true)
        } else {
            hasPremium = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
            |> map { peer -> Bool in
                guard case let .user(user) = peer else {
                    return false
                }
                return user.isPremium
            }
            |> distinctUntilChanged
        }
        return hasPremium
    }
    
    enum Subject: Equatable {
        case generic
        case status
        case channelStatus
        case reaction(onlyTop: Bool)
        case messageTag
        case emoji
        case topicIcon
        case quickReaction
        case profilePhoto
        case groupPhoto
        case backgroundIcon
        case reactionList
        case stickerAlt
    }
    
    static func emojiInputData(
        context: AccountContext,
        animationCache: AnimationCache,
        animationRenderer: MultiAnimationRenderer,
        isStandalone: Bool,
        subject: Subject,
        hasTrending: Bool,
        topReactionItems: [EmojiComponentReactionItem],
        topEmojiItems: [String] = [],
        areUnicodeEmojiEnabled: Bool,
        areCustomEmojiEnabled: Bool,
        chatPeerId: EnginePeer.Id?,
        selectedItems: Set<AnyHashable> = Set(),
        topStatusTitle: String? = nil,
        topicTitle: String? = nil,
        topicColor: Int32? = nil,
        backgroundIconColor: UIColor? = nil,
        hasSearch: Bool = true,
        hasRecent: Bool = true,
        forceHasPremium: Bool = false,
        premiumIfSavedMessages: Bool = true,
        hideBackground: Bool = false
    ) -> Signal<EmojiPagerContentComponent, NoError> {
        let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
        let isPremiumDisabled = premiumConfiguration.isPremiumDisabled
        
        let strings = context.sharedContext.currentPresentationData.with({ $0 }).strings
        
        struct PeerSpecificPackData: Equatable {
            var info: StickerPackCollectionInfo
            var items: [StickerPackItem]
            var peer: EnginePeer
            
            static func ==(lhs: PeerSpecificPackData, rhs: PeerSpecificPackData) -> Bool {
                if lhs.info.id != rhs.info.id {
                    return false
                }
                if lhs.items != rhs.items {
                    return false
                }
                if lhs.peer != rhs.peer {
                    return false
                }
                
                return true
            }
        }
        
        let peerSpecificPack: Signal<PeerSpecificPackData?, NoError>
        if let chatPeerId = chatPeerId {
            peerSpecificPack = combineLatest(
                context.engine.peers.peerSpecificEmojiPack(peerId: chatPeerId),
                context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: chatPeerId))
            )
            |> map { packData, peer -> PeerSpecificPackData? in
                guard let peer = peer else {
                    return nil
                }
                
                guard let (info, items) = packData.packInfo else {
                    return nil
                }
                
                return PeerSpecificPackData(info: info, items: items.compactMap { $0 as? StickerPackItem }, peer: peer)
            }
            |> distinctUntilChanged
        } else {
            peerSpecificPack = .single(nil)
        }
        
        var orderedItemListCollectionIds: [Int32] = []
        
        switch subject {
        case .backgroundIcon, .reactionList:
            break
        default:
            orderedItemListCollectionIds.append(Namespaces.OrderedItemList.LocalRecentEmoji)
        }
        
        var iconStatusEmoji: Signal<[TelegramMediaFile], NoError> = .single([])
        
        if case .status = subject {
            orderedItemListCollectionIds.append(Namespaces.OrderedItemList.CloudFeaturedStatusEmoji)
            orderedItemListCollectionIds.append(Namespaces.OrderedItemList.CloudRecentStatusEmoji)
            
            iconStatusEmoji = context.engine.stickers.loadedStickerPack(reference: .iconStatusEmoji, forceActualized: false)
            |> map { result -> [TelegramMediaFile] in
                switch result {
                case let .result(_, items, _):
                    return items.map(\.file)
                default:
                    return []
                }
            }
            |> take(1)
        } else if case .channelStatus = subject {
            orderedItemListCollectionIds.append(Namespaces.OrderedItemList.CloudFeaturedChannelStatusEmoji)
            orderedItemListCollectionIds.append(Namespaces.OrderedItemList.CloudDisabledChannelStatusEmoji)
            
            iconStatusEmoji = context.engine.stickers.loadedStickerPack(reference: .iconChannelStatusEmoji, forceActualized: false)
            |> map { result -> [TelegramMediaFile] in
                switch result {
                case let .result(_, items, _):
                    return items.map(\.file)
                default:
                    return []
                }
            }
            |> take(1)
        } else if [.reaction(onlyTop: false), .quickReaction].contains(subject) {
            orderedItemListCollectionIds.append(Namespaces.OrderedItemList.CloudTopReactions)
            orderedItemListCollectionIds.append(Namespaces.OrderedItemList.CloudRecentReactions)
        } else if case .messageTag = subject {
            orderedItemListCollectionIds.append(Namespaces.OrderedItemList.CloudDefaultTagReactions)
        } else if case .topicIcon = subject {
            iconStatusEmoji = context.engine.stickers.loadedStickerPack(reference: .iconTopicEmoji, forceActualized: false)
            |> map { result -> [TelegramMediaFile] in
                switch result {
                case let .result(_, items, _):
                    return items.map(\.file)
                default:
                    return []
                }
            }
            |> take(1)
        } else if case .profilePhoto = subject {
            orderedItemListCollectionIds.append(Namespaces.OrderedItemList.CloudFeaturedProfilePhotoEmoji)
        } else if case .groupPhoto = subject {
            orderedItemListCollectionIds.append(Namespaces.OrderedItemList.CloudFeaturedGroupPhotoEmoji)
        } else if case .backgroundIcon = subject {
            orderedItemListCollectionIds.append(Namespaces.OrderedItemList.CloudFeaturedBackgroundIconEmoji)
        }
        
        let availableReactions: Signal<AvailableReactions?, NoError>
        if [.reaction(onlyTop: false), .quickReaction, .reactionList].contains(subject) {
            availableReactions = context.engine.stickers.availableReactions()
        } else {
            availableReactions = .single(nil)
        }
        
        let searchCategories: Signal<EmojiSearchCategories?, NoError>
        if [.emoji, .reaction(onlyTop: false), .reactionList, .messageTag].contains(subject) {
            searchCategories = context.engine.stickers.emojiSearchCategories(kind: .emoji)
        } else if case .status = subject {
            searchCategories = context.engine.stickers.emojiSearchCategories(kind: .status)
        } else if case .channelStatus = subject {
            searchCategories = .single(nil)
        } else if [.profilePhoto, .groupPhoto].contains(subject) {
            searchCategories = context.engine.stickers.emojiSearchCategories(kind: .avatar)
        } else {
            searchCategories = .single(nil)
        }
        
        let emojiItems: Signal<EmojiPagerContentComponent, NoError> = combineLatest(
            context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: orderedItemListCollectionIds, namespaces: [Namespaces.ItemCollection.CloudEmojiPacks], aroundIndex: nil, count: 10000000),
            forceHasPremium ? .single(true) : hasPremium(context: context, chatPeerId: chatPeerId, premiumIfSavedMessages: premiumIfSavedMessages),
            context.account.viewTracker.featuredEmojiPacks(),
            availableReactions,
            searchCategories,
            iconStatusEmoji,
            peerSpecificPack,
            ApplicationSpecificNotice.dismissedTrendingEmojiPacks(accountManager: context.sharedContext.accountManager)
        )
        |> map { view, hasPremium, featuredEmojiPacks, availableReactions, searchCategories, iconStatusEmoji, peerSpecificPack, dismissedTrendingEmojiPacks -> EmojiPagerContentComponent in
            struct ItemGroup {
                var supergroupId: AnyHashable
                var id: AnyHashable
                var title: String?
                var subtitle: String?
                var badge: String?
                var isPremiumLocked: Bool
                var isFeatured: Bool
                var collapsedLineCount: Int?
                var isClearable: Bool
                var headerItem: EntityKeyboardAnimationData?
                var items: [EmojiPagerContentComponent.Item]
            }
            var itemGroups: [ItemGroup] = []
            var itemGroupIndexById: [AnyHashable: Int] = [:]
            
            let maybeAppendUnicodeEmoji = {
                let groupId: AnyHashable = "static"
                
                if itemGroupIndexById[groupId] != nil {
                    return
                }
                
                if areUnicodeEmojiEnabled {
                    for (subgroupId, list) in staticEmojiMapping {
                        for emojiString in list {
                            let resultItem = EmojiPagerContentComponent.Item(
                                animationData: nil,
                                content: .staticEmoji(emojiString),
                                itemFile: nil,
                                subgroupId: subgroupId.rawValue,
                                icon: .none,
                                tintMode: .none
                            )
                            
                            if let groupIndex = itemGroupIndexById[groupId] {
                                itemGroups[groupIndex].items.append(resultItem)
                            } else {
                                itemGroupIndexById[groupId] = itemGroups.count
                                                                
                                let title: String?
                                if case .stickerAlt = subject {
                                    title = nil
                                } else {
                                    title = strings.EmojiInput_SectionTitleEmoji
                                }
                                itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: title, subtitle: nil, badge: nil, isPremiumLocked: false, isFeatured: false, collapsedLineCount: nil, isClearable: false, headerItem: nil, items: [resultItem]))
                            }
                        }
                    }
                }
            }
            
            var installedCollectionIds = Set<ItemCollectionId>()
            for (id, _, _) in view.collectionInfos {
                installedCollectionIds.insert(id)
            }
            
            let dismissedTrendingEmojiPacksSet = Set(dismissedTrendingEmojiPacks ?? [])
            let featuredEmojiPacksSet = Set(featuredEmojiPacks.map(\.info.id.id))
            
            if dismissedTrendingEmojiPacksSet != featuredEmojiPacksSet && hasTrending {
                for featuredEmojiPack in featuredEmojiPacks {
                    if installedCollectionIds.contains(featuredEmojiPack.info.id) {
                        continue
                    }
                    
                    guard let item = featuredEmojiPack.topItems.first else {
                        continue
                    }
                    
                    let animationData: EntityKeyboardAnimationData
                    
                    if let thumbnail = featuredEmojiPack.info.thumbnail {
                        let type: EntityKeyboardAnimationData.ItemType
                        if item.file.isAnimatedSticker {
                            type = .lottie
                        } else if item.file.isVideoEmoji || item.file.isVideoSticker {
                            type = .video
                        } else {
                            type = .still
                        }
                        
                        animationData = EntityKeyboardAnimationData(
                            id: .stickerPackThumbnail(featuredEmojiPack.info.id),
                            type: type,
                            resource: .stickerPackThumbnail(stickerPack: .id(id: featuredEmojiPack.info.id.id, accessHash: featuredEmojiPack.info.accessHash), resource: thumbnail.resource),
                            dimensions: thumbnail.dimensions.cgSize,
                            immediateThumbnailData: featuredEmojiPack.info.immediateThumbnailData,
                            isReaction: false,
                            isTemplate: false
                        )
                    } else {
                        animationData = EntityKeyboardAnimationData(file: item.file)
                    }
                    
                    var tintMode: Item.TintMode = .none
                    if item.file.isCustomTemplateEmoji {
                        tintMode = .primary
                    }
                    
                    let resultItem = EmojiPagerContentComponent.Item(
                        animationData: animationData,
                        content: .animation(animationData),
                        itemFile: item.file,
                        subgroupId: nil,
                        icon: .none,
                        tintMode: tintMode
                    )
                    
                    let supergroupId = "featuredTop"
                    let groupId: AnyHashable = supergroupId
                    let isPremiumLocked: Bool = item.file.isPremiumSticker && !hasPremium
                    if isPremiumLocked && isPremiumDisabled {
                        continue
                    }
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                    } else {
                        itemGroupIndexById[groupId] = itemGroups.count
                        
                        let title = context.sharedContext.currentPresentationData.with({ $0 }).strings.EmojiInput_TrendingEmoji
                        itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: title, subtitle: nil, badge: nil, isPremiumLocked: false, isFeatured: false, collapsedLineCount: 0, isClearable: false, headerItem: nil, items: [resultItem]))
                    }
                }
            }
            
            var recentEmoji: OrderedItemListView?
            var featuredStatusEmoji: OrderedItemListView?
            var featuredChannelStatusEmoji: OrderedItemListView?
            var disabledChannelStatusEmoji: OrderedItemListView?
            var recentStatusEmoji: OrderedItemListView?
            var topReactions: OrderedItemListView?
            var recentReactions: OrderedItemListView?
            var featuredAvatarEmoji: OrderedItemListView?
            var featuredBackgroundIconEmoji: OrderedItemListView?
            var defaultTagReactions: OrderedItemListView?
            for orderedView in view.orderedItemListsViews {
                if orderedView.collectionId == Namespaces.OrderedItemList.LocalRecentEmoji {
                    recentEmoji = orderedView
                } else if orderedView.collectionId == Namespaces.OrderedItemList.CloudFeaturedStatusEmoji {
                    featuredStatusEmoji = orderedView
                } else if orderedView.collectionId == Namespaces.OrderedItemList.CloudFeaturedChannelStatusEmoji {
                    featuredChannelStatusEmoji = orderedView
                } else if orderedView.collectionId == Namespaces.OrderedItemList.CloudDisabledChannelStatusEmoji {
                    disabledChannelStatusEmoji = orderedView
                } else if orderedView.collectionId == Namespaces.OrderedItemList.CloudRecentStatusEmoji {
                    recentStatusEmoji = orderedView
                } else if orderedView.collectionId == Namespaces.OrderedItemList.CloudRecentReactions {
                    recentReactions = orderedView
                } else if orderedView.collectionId == Namespaces.OrderedItemList.CloudTopReactions {
                    topReactions = orderedView
                } else if orderedView.collectionId == Namespaces.OrderedItemList.CloudFeaturedProfilePhotoEmoji {
                    featuredAvatarEmoji = orderedView
                } else if orderedView.collectionId == Namespaces.OrderedItemList.CloudFeaturedGroupPhotoEmoji {
                    featuredAvatarEmoji = orderedView
                } else if orderedView.collectionId == Namespaces.OrderedItemList.CloudFeaturedBackgroundIconEmoji {
                    featuredBackgroundIconEmoji = orderedView
                } else if orderedView.collectionId == Namespaces.OrderedItemList.CloudDefaultTagReactions {
                    defaultTagReactions = orderedView
                }
            }
            
            if case .stickerAlt = subject {
                for emoji in topEmojiItems {
                    let resultItem = EmojiPagerContentComponent.Item(
                        animationData: nil,
                        content: .staticEmoji(emoji),
                        itemFile: nil,
                        subgroupId: nil,
                        icon: .none,
                        tintMode: .none
                    )
                    
                    let groupId = "recent"
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                    } else {
                        itemGroupIndexById[groupId] = itemGroups.count
                        itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: nil, subtitle: nil, badge: nil, isPremiumLocked: false, isFeatured: false, collapsedLineCount: 5, isClearable: false, headerItem: nil, items: [resultItem]))
                    }
                }
                
            } else if case .topicIcon = subject {
                let resultItem = EmojiPagerContentComponent.Item(
                    animationData: nil,
                    content: .icon(.topic(String((topicTitle ?? "").prefix(1)), topicColor ?? 0)),
                    itemFile: nil,
                    subgroupId: nil,
                    icon: .none,
                    tintMode: .none
                )
                
                let groupId = "recent"
                if let groupIndex = itemGroupIndexById[groupId] {
                    itemGroups[groupIndex].items.append(resultItem)
                } else {
                    itemGroupIndexById[groupId] = itemGroups.count
                    itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: nil, subtitle: nil, badge: nil, isPremiumLocked: false, isFeatured: false, collapsedLineCount: 5, isClearable: false, headerItem: nil, items: [resultItem]))
                }
                
                var existingIds = Set<MediaId>()
                
                for file in iconStatusEmoji {
                    if existingIds.contains(file.fileId) {
                        continue
                    }
                    existingIds.insert(file.fileId)
                    
                    var tintMode: Item.TintMode = .none
                    if file.isCustomTemplateEmoji {
                        tintMode = .accent
                    }
                    for attribute in file.attributes {
                        if case let .CustomEmoji(_, _, _, packReference) = attribute {
                            switch packReference {
                            case let .id(id, _):
                                if id == 773947703670341676 || id == 2964141614563343 {
                                    tintMode = .accent
                                }
                            default:
                                break
                            }
                        }
                    }
                    
                    let resultItem: EmojiPagerContentComponent.Item
                    
                    let animationData = EntityKeyboardAnimationData(file: file)
                    resultItem = EmojiPagerContentComponent.Item(
                        animationData: animationData,
                        content: .animation(animationData),
                        itemFile: file,
                        subgroupId: nil,
                        icon: .none,
                        tintMode: tintMode
                    )
                    
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                    }
                }
            } else if case .status = subject {
                let resultItem = EmojiPagerContentComponent.Item(
                    animationData: nil,
                    content: .icon(.premiumStar),
                    itemFile: nil,
                    subgroupId: nil,
                    icon: .none,
                    tintMode: .none
                )
                
                let groupId = "recent"
                if let groupIndex = itemGroupIndexById[groupId] {
                    itemGroups[groupIndex].items.append(resultItem)
                } else {
                    itemGroupIndexById[groupId] = itemGroups.count
                    itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: topStatusTitle?.uppercased(), subtitle: nil, badge: nil, isPremiumLocked: false, isFeatured: false, collapsedLineCount: 5, isClearable: false, headerItem: nil, items: [resultItem]))
                }
                
                var existingIds = Set<MediaId>()
                
                for file in iconStatusEmoji.prefix(7) {
                    if existingIds.contains(file.fileId) {
                        continue
                    }
                    existingIds.insert(file.fileId)
                    
                    var tintMode: Item.TintMode = .none
                    if file.isCustomTemplateEmoji {
                        tintMode = .accent
                    }
                    for attribute in file.attributes {
                        if case let .CustomEmoji(_, _, _, packReference) = attribute {
                            switch packReference {
                            case let .id(id, _):
                                if id == 773947703670341676 || id == 2964141614563343 {
                                    tintMode = .accent
                                }
                            default:
                                break
                            }
                        }
                    }
                    
                    let resultItem: EmojiPagerContentComponent.Item
                    
                    let animationData = EntityKeyboardAnimationData(file: file)
                    resultItem = EmojiPagerContentComponent.Item(
                        animationData: animationData,
                        content: .animation(animationData),
                        itemFile: file,
                        subgroupId: nil,
                        icon: .none,
                        tintMode: tintMode
                    )
                    
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                    }
                }
                
                if let recentStatusEmoji = recentStatusEmoji {
                    for item in recentStatusEmoji.items {
                        guard let item = item.contents.get(RecentMediaItem.self) else {
                            continue
                        }
                        
                        let file = item.media
                        if existingIds.contains(file.fileId) {
                            continue
                        }
                        existingIds.insert(file.fileId)
                        
                        var tintMode: Item.TintMode = .none
                        if file.isCustomTemplateEmoji {
                            tintMode = .accent
                        }
                        for attribute in file.attributes {
                            if case let .CustomEmoji(_, _, _, packReference) = attribute {
                                switch packReference {
                                case let .id(id, _):
                                    if id == 773947703670341676 || id == 2964141614563343 {
                                        tintMode = .accent
                                    }
                                default:
                                    break
                                }
                            }
                        }
                        
                        let resultItem: EmojiPagerContentComponent.Item
                        
                        let animationData = EntityKeyboardAnimationData(file: file)
                        resultItem = EmojiPagerContentComponent.Item(
                            animationData: animationData,
                            content: .animation(animationData),
                            itemFile: file,
                            subgroupId: nil,
                            icon: .none,
                            tintMode: tintMode
                        )
                        
                        if let groupIndex = itemGroupIndexById[groupId] {
                            if itemGroups[groupIndex].items.count >= (5 + 8) * 8 {
                                break
                            }
                            
                            itemGroups[groupIndex].items.append(resultItem)
                        }
                    }
                }
                if let featuredStatusEmoji = featuredStatusEmoji {
                    for item in featuredStatusEmoji.items {
                        guard let item = item.contents.get(RecentMediaItem.self) else {
                            continue
                        }
                        
                        let file = item.media
                        if existingIds.contains(file.fileId) {
                            continue
                        }
                        existingIds.insert(file.fileId)
                        
                        let resultItem: EmojiPagerContentComponent.Item
                        
                        var tintMode: Item.TintMode = .none
                        if file.isCustomTemplateEmoji {
                            tintMode = .accent
                        }
                        for attribute in file.attributes {
                            if case let .CustomEmoji(_, _, _, packReference) = attribute {
                                switch packReference {
                                case let .id(id, _):
                                    if id == 773947703670341676 || id == 2964141614563343 {
                                        tintMode = .accent
                                    }
                                default:
                                    break
                                }
                            }
                        }
                        
                        let animationData = EntityKeyboardAnimationData(file: file)
                        resultItem = EmojiPagerContentComponent.Item(
                            animationData: animationData,
                            content: .animation(animationData),
                            itemFile: file,
                            subgroupId: nil,
                            icon: .none,
                            tintMode: tintMode
                        )
                        
                        if let groupIndex = itemGroupIndexById[groupId] {
                            if itemGroups[groupIndex].items.count >= (5 + 8) * 8 {
                                break
                            }
                            
                            itemGroups[groupIndex].items.append(resultItem)
                        }
                    }
                }
            } else if case .channelStatus = subject {
                let resultItem = EmojiPagerContentComponent.Item(
                    animationData: nil,
                    content: .icon(.stop),
                    itemFile: nil,
                    subgroupId: nil,
                    icon: .none,
                    tintMode: .accent
                )
                
                let groupId = "recent"
                if let groupIndex = itemGroupIndexById[groupId] {
                    itemGroups[groupIndex].items.append(resultItem)
                } else {
                    itemGroupIndexById[groupId] = itemGroups.count
                    itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: topStatusTitle?.uppercased(), subtitle: nil, badge: nil, isPremiumLocked: false, isFeatured: false, collapsedLineCount: 5, isClearable: false, headerItem: nil, items: [resultItem]))
                }
                
                var existingIds = Set<MediaId>()
                
                if let disabledChannelStatusEmoji {
                    for item in disabledChannelStatusEmoji.items {
                        guard let item = item.contents.get(RecentMediaItem.self) else {
                            continue
                        }
                        let file = item.media
                        existingIds.insert(file.fileId)
                    }
                }
                
                for file in iconStatusEmoji.prefix(7) {
                    if existingIds.contains(file.fileId) {
                        continue
                    }
                    existingIds.insert(file.fileId)
                    
                    var tintMode: Item.TintMode = .none
                    if file.isCustomTemplateEmoji {
                        tintMode = .accent
                    }
                    for attribute in file.attributes {
                        if case let .CustomEmoji(_, _, _, packReference) = attribute {
                            switch packReference {
                            case let .id(id, _):
                                if id == 773947703670341676 || id == 2964141614563343 {
                                    tintMode = .accent
                                }
                            default:
                                break
                            }
                        }
                    }
                    
                    let resultItem: EmojiPagerContentComponent.Item
                    
                    let animationData = EntityKeyboardAnimationData(file: file)
                    resultItem = EmojiPagerContentComponent.Item(
                        animationData: animationData,
                        content: .animation(animationData),
                        itemFile: file,
                        subgroupId: nil,
                        icon: .none,
                        tintMode: tintMode
                    )
                    
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                    }
                }
                
                if let featuredChannelStatusEmoji {
                    for item in featuredChannelStatusEmoji.items {
                        guard let item = item.contents.get(RecentMediaItem.self) else {
                            continue
                        }
                        
                        let file = item.media
                        if existingIds.contains(file.fileId) {
                            continue
                        }
                        existingIds.insert(file.fileId)
                        
                        let resultItem: EmojiPagerContentComponent.Item
                        
                        var tintMode: Item.TintMode = .none
                        if file.isCustomTemplateEmoji {
                            tintMode = .accent
                        }
                        for attribute in file.attributes {
                            if case let .CustomEmoji(_, _, _, packReference) = attribute {
                                switch packReference {
                                case let .id(id, _):
                                    if id == 773947703670341676 || id == 2964141614563343 {
                                        tintMode = .accent
                                    }
                                default:
                                    break
                                }
                            }
                        }
                        
                        let animationData = EntityKeyboardAnimationData(file: file)
                        resultItem = EmojiPagerContentComponent.Item(
                            animationData: animationData,
                            content: .animation(animationData),
                            itemFile: file,
                            subgroupId: nil,
                            icon: .none,
                            tintMode: tintMode
                        )
                        
                        if let groupIndex = itemGroupIndexById[groupId] {
                            /*if itemGroups[groupIndex].items.count >= (5 + 8) * 8 {
                                break
                            }*/
                            
                            itemGroups[groupIndex].items.append(resultItem)
                        }
                    }
                }
            } else if case .reactionList = subject {
                var existingIds = Set<MessageReaction.Reaction>()
                
                if let availableReactions = availableReactions {
                    for reactionItem in availableReactions.reactions {
                        if !reactionItem.isEnabled {
                            continue
                        }
                        if existingIds.contains(reactionItem.value) {
                            continue
                        }
                        existingIds.insert(reactionItem.value)
                        
                        let icon: EmojiPagerContentComponent.Item.Icon
                        if !hasPremium, case .custom = reactionItem.value {
                            icon = .locked
                        } else {
                            icon = .none
                        }
                        
                        var tintMode: Item.TintMode = .none
                        if reactionItem.selectAnimation.isCustomTemplateEmoji {
                            tintMode = .primary
                        }
                        
                        let animationFile = reactionItem.selectAnimation
                        let animationData = EntityKeyboardAnimationData(file: animationFile, isReaction: true)
                        let resultItem = EmojiPagerContentComponent.Item(
                            animationData: animationData,
                            content: .animation(animationData),
                            itemFile: animationFile,
                            subgroupId: nil,
                            icon: icon,
                            tintMode: tintMode
                        )
                        
                        let groupId = "liked"
                        if let groupIndex = itemGroupIndexById[groupId] {
                            itemGroups[groupIndex].items.append(resultItem)
                        } else {
                            itemGroupIndexById[groupId] = itemGroups.count
                            itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: nil, subtitle: nil, badge: nil, isPremiumLocked: false, isFeatured: false, collapsedLineCount: nil, isClearable: false, headerItem: nil, items: [resultItem]))
                        }
                    }
                }
            } else if [.reaction(onlyTop: true), .reaction(onlyTop: false), .quickReaction].contains(subject) {
                var existingIds = Set<MessageReaction.Reaction>()
                
                var topReactionItems = topReactionItems
                if topReactionItems.isEmpty {
                    if let topReactions = topReactions {
                        for item in topReactions.items {
                            guard let topReaction = item.contents.get(RecentReactionItem.self) else {
                                continue
                            }
                            
                            switch topReaction.content {
                            case let .builtin(value):
                                if let reaction = availableReactions?.reactions.first(where: { $0.value == .builtin(value) }) {
                                    topReactionItems.append(EmojiComponentReactionItem(reaction: .builtin(value), file: reaction.selectAnimation))
                                } else {
                                    continue
                                }
                            case let .custom(file):
                                topReactionItems.append(EmojiComponentReactionItem(reaction: .custom(file.fileId.id), file: file))
                            case .stars:
                                if let reaction = availableReactions?.reactions.first(where: { $0.value == .stars }) {
                                    topReactionItems.append(EmojiComponentReactionItem(reaction: .stars, file: reaction.selectAnimation))
                                }
                            }
                        }
                    }
                }
                
                let maxTopLineCount: Int
                if case .reaction(onlyTop: true) = subject {
                    maxTopLineCount = 1000
                } else if hasPremium {
                    maxTopLineCount = 2
                } else {
                    maxTopLineCount = 6
                }
                
                for reactionItem in topReactionItems {
                    if existingIds.contains(reactionItem.reaction) {
                        continue
                    }
                    existingIds.insert(reactionItem.reaction)
                    
                    let icon: EmojiPagerContentComponent.Item.Icon
                    if case .reaction(onlyTop: true) = subject {
                        icon = .none
                    } else if !hasPremium, case .custom = reactionItem.reaction {
                        icon = .locked
                    } else {
                        icon = .none
                    }
                    
                    var tintMode: Item.TintMode = .none
                    if reactionItem.file.isCustomTemplateEmoji {
                        tintMode = .primary
                    }
                    
                    let animationFile = reactionItem.file
                    let animationData = EntityKeyboardAnimationData(file: animationFile, isReaction: true)
                    let resultItem = EmojiPagerContentComponent.Item(
                        animationData: animationData,
                        content: .animation(animationData),
                        itemFile: animationFile,
                        subgroupId: nil,
                        icon: icon,
                        tintMode: tintMode
                    )
                    
                    let groupId = "recent"
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                        
                        if itemGroups[groupIndex].items.count >= 8 * maxTopLineCount {
                            break
                        }
                    } else {
                        itemGroupIndexById[groupId] = itemGroups.count
                        itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: nil, subtitle: nil, badge: nil, isPremiumLocked: false, isFeatured: false, collapsedLineCount: nil, isClearable: false, headerItem: nil, items: [resultItem]))
                    }
                }
                
                if case .reaction(onlyTop: false) = subject {
                    var hasRecent = false
                    if let recentReactions = recentReactions, !recentReactions.items.isEmpty {
                        hasRecent = true
                    }
                    
                    let maxRecentLineCount: Int
                    if hasPremium {
                        maxRecentLineCount = 10
                    } else {
                        maxRecentLineCount = 10
                    }
                    
                    let popularTitle = hasRecent ? strings.Chat_ReactionSection_Recent : strings.Chat_ReactionSection_Popular
                    
                    if let availableReactions = availableReactions {
                        for reactionItem in availableReactions.reactions {
                            if !reactionItem.isEnabled {
                                continue
                            }
                            if existingIds.contains(reactionItem.value) {
                                continue
                            }
                            existingIds.insert(reactionItem.value)
                            
                            let icon: EmojiPagerContentComponent.Item.Icon
                            if !hasPremium, case .custom = reactionItem.value {
                                icon = .locked
                            } else {
                                icon = .none
                            }
                            
                            var tintMode: Item.TintMode = .none
                            if reactionItem.selectAnimation.isCustomTemplateEmoji {
                                tintMode = .primary
                            }
                            
                            let animationFile = reactionItem.selectAnimation
                            let animationData = EntityKeyboardAnimationData(file: animationFile, isReaction: true)
                            let resultItem = EmojiPagerContentComponent.Item(
                                animationData: animationData,
                                content: .animation(animationData),
                                itemFile: animationFile,
                                subgroupId: nil,
                                icon: icon,
                                tintMode: tintMode
                            )
                            
                            if hasPremium {
                                let groupId = "popular"
                                if let groupIndex = itemGroupIndexById[groupId] {
                                    itemGroups[groupIndex].items.append(resultItem)
                                } else {
                                    itemGroupIndexById[groupId] = itemGroups.count
                                    itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: popularTitle, subtitle: nil, badge: nil, isPremiumLocked: false, isFeatured: false, collapsedLineCount: nil, isClearable: hasRecent && subject != .quickReaction, headerItem: nil, items: [resultItem]))
                                }
                            } else {
                                let groupId = "recent"
                                if let groupIndex = itemGroupIndexById[groupId] {
                                    itemGroups[groupIndex].items.append(resultItem)
                                    
                                    if itemGroups[groupIndex].items.count >= maxRecentLineCount * 8 {
                                        break
                                    }
                                } else {
                                    itemGroupIndexById[groupId] = itemGroups.count
                                    itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: nil, subtitle: nil, badge: nil, isPremiumLocked: false, isFeatured: false, collapsedLineCount: nil, isClearable: false, headerItem: nil, items: [resultItem]))
                                }
                            }
                        }
                    }
                    
                    if let recentReactions = recentReactions {
                        var popularInsertIndex = 0
                        for item in recentReactions.items {
                            guard let item = item.contents.get(RecentReactionItem.self) else {
                                continue
                            }
                            
                            let animationFile: TelegramMediaFile
                            let icon: EmojiPagerContentComponent.Item.Icon
                            
                            switch item.content {
                            case let .builtin(value):
                                if existingIds.contains(.builtin(value)) {
                                    continue
                                }
                                existingIds.insert(.builtin(value))
                                if let availableReactions = availableReactions, let availableReaction = availableReactions.reactions.first(where: { $0.value == .builtin(value) }) {
                                    if let centerAnimation = availableReaction.centerAnimation {
                                        animationFile = centerAnimation
                                    } else {
                                        continue
                                    }
                                } else {
                                    continue
                                }
                                
                                icon = .none
                            case let .custom(file):
                                if existingIds.contains(.custom(file.fileId.id)) {
                                    continue
                                }
                                existingIds.insert(.custom(file.fileId.id))
                                animationFile = file
                                
                                if !hasPremium {
                                    icon = .locked
                                } else {
                                    icon = .none
                                }
                            case .stars:
                                if existingIds.contains(.stars) {
                                    continue
                                }
                                existingIds.insert(.stars)
                                if let availableReactions = availableReactions, let availableReaction = availableReactions.reactions.first(where: { $0.value == .stars }) {
                                    if let centerAnimation = availableReaction.centerAnimation {
                                        animationFile = centerAnimation
                                    } else {
                                        continue
                                    }
                                } else {
                                    continue
                                }
                                
                                icon = .none
                            }
                            
                            var tintMode: Item.TintMode = .none
                            if animationFile.isCustomTemplateEmoji {
                                tintMode = .primary
                            }
                            
                            let animationData = EntityKeyboardAnimationData(file: animationFile, isReaction: true)
                            let resultItem = EmojiPagerContentComponent.Item(
                                animationData: animationData,
                                content: .animation(animationData),
                                itemFile: animationFile,
                                subgroupId: nil,
                                icon: icon,
                                tintMode: tintMode
                            )
                            
                            let groupId = "popular"
                            if let groupIndex = itemGroupIndexById[groupId] {
                                if itemGroups[groupIndex].items.count + 1 >= maxRecentLineCount * 8 {
                                    break
                                }
                                
                                itemGroups[groupIndex].items.insert(resultItem, at: popularInsertIndex)
                                popularInsertIndex += 1
                            } else {
                                itemGroupIndexById[groupId] = itemGroups.count
                                itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: popularTitle, subtitle: nil, badge: nil, isPremiumLocked: false, isFeatured: false, collapsedLineCount: nil, isClearable: hasRecent && subject != .quickReaction, headerItem: nil, items: [resultItem]))
                            }
                        }
                    }
                }
            } else if case .messageTag = subject {
                var existingIds = Set<MessageReaction.Reaction>()
                
                var topReactionItems = topReactionItems
                if topReactionItems.isEmpty {
                    if let defaultTagReactions {
                        for item in defaultTagReactions.items {
                            guard let topReaction = item.contents.get(RecentReactionItem.self) else {
                                continue
                            }
                            
                            switch topReaction.content {
                            case let .builtin(value):
                                if let reaction = availableReactions?.reactions.first(where: { $0.value == .builtin(value) }) {
                                    topReactionItems.append(EmojiComponentReactionItem(reaction: .builtin(value), file: reaction.selectAnimation))
                                } else {
                                    continue
                                }
                            case let .custom(file):
                                topReactionItems.append(EmojiComponentReactionItem(reaction: .custom(file.fileId.id), file: file))
                            case .stars:
                                if let reaction = availableReactions?.reactions.first(where: { $0.value == .stars }) {
                                    topReactionItems.append(EmojiComponentReactionItem(reaction: .stars, file: reaction.selectAnimation))
                                } else {
                                    continue
                                }
                            }
                        }
                    }
                }
                
                let maxTopLineCount: Int = 1000
                
                for reactionItem in topReactionItems {
                    if existingIds.contains(reactionItem.reaction) {
                        continue
                    }
                    existingIds.insert(reactionItem.reaction)
                    
                    let icon: EmojiPagerContentComponent.Item.Icon = .none
                    
                    var tintMode: Item.TintMode = .none
                    if reactionItem.file.isCustomTemplateEmoji {
                        tintMode = .primary
                    }
                    
                    let animationFile = reactionItem.file
                    let animationData = EntityKeyboardAnimationData(file: animationFile, isReaction: true)
                    let resultItem = EmojiPagerContentComponent.Item(
                        animationData: animationData,
                        content: .animation(animationData),
                        itemFile: animationFile,
                        subgroupId: nil,
                        icon: icon,
                        tintMode: tintMode
                    )
                    
                    let groupId = "recent"
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                        
                        if itemGroups[groupIndex].items.count >= 8 * maxTopLineCount {
                            break
                        }
                    } else {
                        itemGroupIndexById[groupId] = itemGroups.count
                        itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: nil, subtitle: nil, badge: nil, isPremiumLocked: false, isFeatured: false, collapsedLineCount: nil, isClearable: false, headerItem: nil, items: [resultItem]))
                    }
                }
            } else if [.profilePhoto, .groupPhoto].contains(subject) {
                var existingIds = Set<MediaId>()
                
                let groupId = "recent"
                itemGroupIndexById[groupId] = itemGroups.count
                itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: topStatusTitle?.uppercased(), subtitle: nil, badge: nil, isPremiumLocked: false, isFeatured: false, collapsedLineCount: 5, isClearable: false, headerItem: nil, items: []))
                                
                if let featuredAvatarEmoji = featuredAvatarEmoji {
                    for item in featuredAvatarEmoji.items {
                        guard let item = item.contents.get(RecentMediaItem.self) else {
                            continue
                        }
                        
                        let file = item.media
                        if existingIds.contains(file.fileId) {
                            continue
                        }
                        existingIds.insert(file.fileId)
                        
                        let resultItem: EmojiPagerContentComponent.Item
                        
                        var tintMode: Item.TintMode = .none
                        if file.isCustomTemplateEmoji {
                            tintMode = .accent
                        }
                        for attribute in file.attributes {
                            if case let .CustomEmoji(_, _, _, packReference) = attribute {
                                switch packReference {
                                case let .id(id, _):
                                    if id == 773947703670341676 || id == 2964141614563343 {
                                        tintMode = .accent
                                    }
                                default:
                                    break
                                }
                            }
                        }
                        
                        let animationData = EntityKeyboardAnimationData(file: file)
                        resultItem = EmojiPagerContentComponent.Item(
                            animationData: animationData,
                            content: .animation(animationData),
                            itemFile: file,
                            subgroupId: nil,
                            icon: .none,
                            tintMode: tintMode
                        )
                        
                        if let groupIndex = itemGroupIndexById[groupId] {
                            if itemGroups[groupIndex].items.count >= (5 + 8) * 8 {
                                break
                            }
                            
                            itemGroups[groupIndex].items.append(resultItem)
                        }
                    }
                }
            } else if case .backgroundIcon = subject {
                var existingIds = Set<MediaId>()
                
                let resultItem = EmojiPagerContentComponent.Item(
                    animationData: nil,
                    content: .icon(.stop),
                    itemFile: nil,
                    subgroupId: nil,
                    icon: .none,
                    tintMode: .accent
                )
                
                let groupId = "recent"
                if let groupIndex = itemGroupIndexById[groupId] {
                    itemGroups[groupIndex].items.append(resultItem)
                } else {
                    itemGroupIndexById[groupId] = itemGroups.count
                    itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: nil, subtitle: nil, badge: nil, isPremiumLocked: false, isFeatured: false, collapsedLineCount: 5, isClearable: false, headerItem: nil, items: [resultItem]))
                }
                                
                if let featuredBackgroundIconEmoji {
                    for item in featuredBackgroundIconEmoji.items {
                        guard let item = item.contents.get(RecentMediaItem.self) else {
                            continue
                        }
                        
                        let file = item.media
                        if existingIds.contains(file.fileId) {
                            continue
                        }
                        existingIds.insert(file.fileId)
                        
                        let resultItem: EmojiPagerContentComponent.Item
                        
                        var tintMode: Item.TintMode = .none
                        if file.isCustomTemplateEmoji {
                            if let backgroundIconColor {
                                tintMode = .custom(backgroundIconColor)
                            } else {
                                tintMode = .accent
                            }
                        }
                        for attribute in file.attributes {
                            if case let .CustomEmoji(_, _, _, packReference) = attribute {
                                switch packReference {
                                case let .id(id, _):
                                    if id == 773947703670341676 || id == 2964141614563343 {
                                        tintMode = .accent
                                    }
                                default:
                                    break
                                }
                            }
                        }
                        
                        let animationData = EntityKeyboardAnimationData(file: file)
                        resultItem = EmojiPagerContentComponent.Item(
                            animationData: animationData,
                            content: .animation(animationData),
                            itemFile: file,
                            subgroupId: nil,
                            icon: .none,
                            tintMode: tintMode
                        )
                        
                        if let groupIndex = itemGroupIndexById[groupId] {
                            if itemGroups[groupIndex].items.count >= (5 + 8) * 8 {
                                break
                            }
                            
                            itemGroups[groupIndex].items.append(resultItem)
                        }
                    }
                }
            }
            
            let hasRecentEmoji = ![.reaction(onlyTop: true), .reaction(onlyTop: false), .quickReaction, .status, .profilePhoto, .groupPhoto, .topicIcon, .backgroundIcon, .reactionList, .messageTag, .stickerAlt].contains(subject)
            
            if let recentEmoji = recentEmoji, hasRecentEmoji {
                for item in recentEmoji.items {
                    guard let item = item.contents.get(RecentEmojiItem.self) else {
                        continue
                    }
                    
                    if case let .file(file) = item.content, isPremiumDisabled, file.isPremiumEmoji {
                        continue
                    }
                    
                    if !areCustomEmojiEnabled, case .file = item.content {
                        continue
                    }
                    
                    let resultItem: EmojiPagerContentComponent.Item
                    switch item.content {
                    case let .file(file):
                        var tintMode: Item.TintMode = .none
                        if file.isCustomTemplateEmoji {
                            tintMode = .primary
                        }
                        
                        let animationData = EntityKeyboardAnimationData(file: file)
                        resultItem = EmojiPagerContentComponent.Item(
                            animationData: animationData,
                            content: .animation(animationData),
                            itemFile: file,
                            subgroupId: nil,
                            icon: .none,
                            tintMode: tintMode
                        )
                    case let .text(text):
                        resultItem = EmojiPagerContentComponent.Item(
                            animationData: nil,
                            content: .staticEmoji(text),
                            itemFile: nil,
                            subgroupId: nil,
                            icon: .none,
                            tintMode: .none
                        )
                    }
                    
                    let groupId = "recent"
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                    } else {
                        itemGroupIndexById[groupId] = itemGroups.count
                        itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: strings.Emoji_FrequentlyUsed, subtitle: nil, badge: nil, isPremiumLocked: false, isFeatured: false, collapsedLineCount: nil, isClearable: true, headerItem: nil, items: [resultItem]))
                    }
                }
            }
                        
            var itemCollectionMapping: [ItemCollectionId: StickerPackCollectionInfo] = [:]
            for (id, info, _) in view.collectionInfos {
                if let info = info as? StickerPackCollectionInfo {
                    itemCollectionMapping[id] = info
                }
            }
            
            var skippedCollectionIds = Set<AnyHashable>()
            
            var avatarPeer: EnginePeer?
            if let peerSpecificPack = peerSpecificPack {
                avatarPeer = peerSpecificPack.peer
                
                var processedIds = Set<MediaId>()
                for item in peerSpecificPack.items {
                    if isPremiumDisabled && item.file.isPremiumSticker {
                        continue
                    }
                    if processedIds.contains(item.file.fileId) {
                        continue
                    }
                    processedIds.insert(item.file.fileId)
                    
                    var tintMode: Item.TintMode = .none
                    if item.file.isCustomTemplateEmoji {
                        tintMode = .primary
                    }
                    
                    let animationData = EntityKeyboardAnimationData(file: item.file)
                    let resultItem = EmojiPagerContentComponent.Item(
                        animationData: animationData,
                        content: .animation(animationData),
                        itemFile: item.file,
                        subgroupId: nil,
                        icon: .none,
                        tintMode: tintMode
                    )
                    
                    let groupId = "peerSpecific"
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                    } else {
                        itemGroupIndexById[groupId] = itemGroups.count
                        itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: peerSpecificPack.info.title, subtitle: nil, badge: strings.Emoji_GroupEmoji, isPremiumLocked: false, isFeatured: false, collapsedLineCount: nil, isClearable: false, headerItem: nil, items: [resultItem]))
                    }
                }
                
                let supergroupId: AnyHashable = peerSpecificPack.info.id
                skippedCollectionIds.insert(supergroupId)
            }
            
            if !hasPremium {
                maybeAppendUnicodeEmoji()
            }
                        
            if areCustomEmojiEnabled {
                for entry in view.entries {
                    guard let item = entry.item as? StickerPackItem else {
                        continue
                    }
                    
                    var icon: EmojiPagerContentComponent.Item.Icon = .none
                    if [.reaction(onlyTop: false), .quickReaction].contains(subject), !hasPremium {
                        icon = .locked
                    }
                    
                    let supergroupId = entry.index.collectionId
                    let groupId: AnyHashable = supergroupId
                    
                    if skippedCollectionIds.contains(groupId) {
                        continue
                    }
                    
                    if case .channelStatus = subject {
                        guard let collection = itemCollectionMapping[entry.index.collectionId] else {
                            continue
                        }
                        if !collection.flags.contains(.isAvailableAsChannelStatus) {
                            continue
                        }
                    }
                    
                    var isTemplate = false
                    var tintMode: Item.TintMode = .none
                    if item.file.isCustomTemplateEmoji {
                        if [.status, .channelStatus, .backgroundIcon].contains(subject) {
                            if let backgroundIconColor {
                                tintMode = .custom(backgroundIconColor)
                            } else {
                                tintMode = .accent
                            }
                        } else {
                            tintMode = .primary
                        }
                        if case .backgroundIcon = subject {
                            isTemplate = true
                        }
                    } else if case .backgroundIcon = subject {
                        skippedCollectionIds.insert(groupId)
                        continue
                    }
                    
                    let animationData = EntityKeyboardAnimationData(file: item.file)
                    let resultItem = EmojiPagerContentComponent.Item(
                        animationData: animationData,
                        content: .animation(animationData),
                        itemFile: item.file,
                        subgroupId: nil,
                        icon: icon,
                        tintMode: tintMode
                    )
                    
                    let isPremiumLocked: Bool = item.file.isPremiumEmoji && !hasPremium
                    if isPremiumLocked && isPremiumDisabled {
                        continue
                    }
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                    } else {
                        itemGroupIndexById[groupId] = itemGroups.count
                        
                        var title = ""
                        var headerItem: EntityKeyboardAnimationData?
                        inner: for (id, info, _) in view.collectionInfos {
                            if id == entry.index.collectionId, let info = info as? StickerPackCollectionInfo {
                                title = info.title
                                
                                if let thumbnail = info.thumbnail {
                                    let type: EntityKeyboardAnimationData.ItemType
                                    if item.file.isAnimatedSticker {
                                        type = .lottie
                                    } else if item.file.isVideoEmoji || item.file.isVideoSticker {
                                        type = .video
                                    } else {
                                        type = .still
                                    }
                                    
                                    headerItem = EntityKeyboardAnimationData(
                                        id: .stickerPackThumbnail(info.id),
                                        type: type,
                                        resource: .stickerPackThumbnail(stickerPack: .id(id: info.id.id, accessHash: info.accessHash), resource: thumbnail.resource),
                                        dimensions: thumbnail.dimensions.cgSize,
                                        immediateThumbnailData: info.immediateThumbnailData,
                                        isReaction: false,
                                        isTemplate: isTemplate
                                    )
                                }
                                
                                break inner
                            }
                        }
                        itemGroups.append(ItemGroup(supergroupId: supergroupId, id: groupId, title: title, subtitle: nil, badge: nil, isPremiumLocked: isPremiumLocked, isFeatured: false, collapsedLineCount: nil, isClearable: false, headerItem: headerItem, items: [resultItem]))
                    }
                }
                
                if !isStandalone {
                    for featuredEmojiPack in featuredEmojiPacks {
                        if installedCollectionIds.contains(featuredEmojiPack.info.id) {
                            continue
                        }
                                                
                        let supergroupId = featuredEmojiPack.info.id
                        let groupId: AnyHashable = supergroupId
                        
                        if skippedCollectionIds.contains(groupId) {
                            continue
                        }
                        
                        if case .channelStatus = subject {
                            if !featuredEmojiPack.info.flags.contains(.isAvailableAsChannelStatus) {
                                continue
                            }
                        }
                        
                        for item in featuredEmojiPack.topItems {
                            var tintMode: Item.TintMode = .none
                            if item.file.isCustomTemplateEmoji {
                                if [.status, .channelStatus, .backgroundIcon].contains(subject) {
                                    if let backgroundIconColor {
                                        tintMode = .custom(backgroundIconColor)
                                    } else {
                                        tintMode = .accent
                                    }
                                } else {
                                    tintMode = .primary
                                }
                            } else if case .backgroundIcon = subject {
                                skippedCollectionIds.insert(groupId)
                                continue
                            }
                            
                            let animationData = EntityKeyboardAnimationData(file: item.file)
                            let resultItem = EmojiPagerContentComponent.Item(
                                animationData: animationData,
                                content: .animation(animationData),
                                itemFile: item.file,
                                subgroupId: nil,
                                icon: .none,
                                tintMode: tintMode
                            )
                            
                            let isPremiumLocked: Bool = item.file.isPremiumEmoji && !hasPremium
                            if isPremiumLocked && isPremiumDisabled {
                                continue
                            }
                            if let groupIndex = itemGroupIndexById[groupId] {
                                itemGroups[groupIndex].items.append(resultItem)
                            } else {
                                itemGroupIndexById[groupId] = itemGroups.count
                                
                                var headerItem: EntityKeyboardAnimationData?
                                if let thumbnailFileId = featuredEmojiPack.info.thumbnailFileId, let file = featuredEmojiPack.topItems.first(where: { $0.file.fileId.id == thumbnailFileId }) {
                                    headerItem = EntityKeyboardAnimationData(file: file.file)
                                } else if let thumbnail = featuredEmojiPack.info.thumbnail {
                                    let info = featuredEmojiPack.info
                                    let type: EntityKeyboardAnimationData.ItemType
                                    if item.file.isAnimatedSticker {
                                        type = .lottie
                                    } else if item.file.isVideoEmoji || item.file.isVideoSticker {
                                        type = .video
                                    } else {
                                        type = .still
                                    }
                                    
                                    headerItem = EntityKeyboardAnimationData(
                                        id: .stickerPackThumbnail(info.id),
                                        type: type,
                                        resource: .stickerPackThumbnail(stickerPack: .id(id: info.id.id, accessHash: info.accessHash), resource: thumbnail.resource),
                                        dimensions: thumbnail.dimensions.cgSize,
                                        immediateThumbnailData: info.immediateThumbnailData,
                                        isReaction: false,
                                        isTemplate: false
                                    )
                                }
                                
                                var isFeatured = true
                                if case .reactionList = subject {
                                    isFeatured = false
                                }
                                
                                itemGroups.append(ItemGroup(supergroupId: supergroupId, id: groupId, title: featuredEmojiPack.info.title, subtitle: nil, badge: nil, isPremiumLocked: isPremiumLocked, isFeatured: isFeatured, collapsedLineCount: 3, isClearable: false, headerItem: headerItem, items: [resultItem]))
                            }
                        }
                    }
                }
            }
            
            if hasPremium {
                maybeAppendUnicodeEmoji()
            }
                        
            var displaySearchWithPlaceholder: String?
            let searchInitiallyHidden = true
            if hasSearch {
                if [.reaction(onlyTop: false), .quickReaction, .messageTag].contains(subject) {
                    displaySearchWithPlaceholder = strings.EmojiSearch_SearchReactionsPlaceholder
                } else if case .status = subject {
                    displaySearchWithPlaceholder = strings.EmojiSearch_SearchStatusesPlaceholder
                } else if case .emoji = subject {
                    displaySearchWithPlaceholder = strings.EmojiSearch_SearchEmojiPlaceholder
                } else if [.profilePhoto, .groupPhoto].contains(subject) {
                    displaySearchWithPlaceholder = strings.Common_Search
                } else if case .stickerAlt = subject {
                    displaySearchWithPlaceholder = strings.Common_Search
                }
            }
            
            let allItemGroups = itemGroups.map { group -> EmojiPagerContentComponent.ItemGroup in
                var hasClear = group.isClearable
                var isEmbedded = false
                if group.id == AnyHashable("featuredTop") {
                    hasClear = true
                    isEmbedded = true
                }
                
                var headerItem = group.headerItem
                
                if let groupId = group.id.base as? ItemCollectionId {
                    outer: for (id, info, _) in view.collectionInfos {
                        if id == groupId, let info = info as? StickerPackCollectionInfo {
                            if let thumbnailFileId = info.thumbnailFileId {
                                for item in group.items {
                                    if let itemFile = item.itemFile, itemFile.fileId.id == thumbnailFileId {
                                        headerItem = EntityKeyboardAnimationData(file: itemFile)
                                        break outer
                                    }
                                }
                            }
                        }
                    }
                }
                
                return EmojiPagerContentComponent.ItemGroup(
                    supergroupId: group.supergroupId,
                    groupId: group.id,
                    title: group.title,
                    subtitle: group.subtitle,
                    badge: group.badge,
                    actionButtonTitle: nil,
                    isFeatured: group.isFeatured,
                    isPremiumLocked: group.isPremiumLocked,
                    isEmbedded: isEmbedded,
                    hasClear: hasClear,
                    hasEdit: false,
                    collapsedLineCount: group.collapsedLineCount,
                    displayPremiumBadges: false,
                    headerItem: headerItem,
                    fillWithLoadingPlaceholders: false,
                    customTintColor: backgroundIconColor,
                    items: group.items
                )
            }
            
            let warpContentsOnEdges = [.reaction(onlyTop: true), .reaction(onlyTop: false), .quickReaction, .status, .channelStatus, .profilePhoto, .groupPhoto, .backgroundIcon, .messageTag].contains(subject)
            let enableLongPress = [.reaction(onlyTop: true), .reaction(onlyTop: false), .status, .channelStatus].contains(subject)
                        
            return EmojiPagerContentComponent(
                id: "emoji",
                context: context,
                avatarPeer: avatarPeer,
                animationCache: animationCache,
                animationRenderer: animationRenderer,
                inputInteractionHolder: EmojiPagerContentComponent.InputInteractionHolder(),
                panelItemGroups: allItemGroups,
                contentItemGroups: allItemGroups,
                itemLayoutType: .compact,
                itemContentUniqueId: nil,
                searchState: .empty(hasResults: false),
                warpContentsOnEdges: warpContentsOnEdges,
                hideBackground: hideBackground,
                displaySearchWithPlaceholder: displaySearchWithPlaceholder,
                searchCategories: searchCategories,
                searchInitiallyHidden: searchInitiallyHidden,
                searchAlwaysActive: false,
                searchIsPlaceholderOnly: false,
                searchUnicodeEmojiOnly: subject == .stickerAlt,
                emptySearchResults: nil,
                enableLongPress: enableLongPress,
                selectedItems: selectedItems,
                customTintColor: backgroundIconColor
            )
        }
        return emojiItems
    }
    
    enum StickersSubject {
        case profilePhotoEmojiSelection
        case groupPhotoEmojiSelection
        case chatStickers
        case greetingStickers
    }
    
    static func stickerInputData(
        context: AccountContext,
        animationCache: AnimationCache,
        animationRenderer: MultiAnimationRenderer,
        stickerNamespaces: [ItemCollectionId.Namespace],
        stickerOrderedItemListCollectionIds: [Int32],
        chatPeerId: EnginePeer.Id?,
        hasSearch: Bool,
        hasTrending: Bool,
        forceHasPremium: Bool,
        hasEdit: Bool = false,
        hasAdd: Bool = false,
        searchIsPlaceholderOnly: Bool = true,
        subject: StickersSubject = .chatStickers,
        hideBackground: Bool = false
    ) -> Signal<EmojiPagerContentComponent, NoError> {
        let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
        let isPremiumDisabled = premiumConfiguration.isPremiumDisabled
        
        struct PeerSpecificPackData: Equatable {
            var info: StickerPackCollectionInfo
            var items: [StickerPackItem]
            var peer: EnginePeer
            
            static func ==(lhs: PeerSpecificPackData, rhs: PeerSpecificPackData) -> Bool {
                if lhs.info.id != rhs.info.id {
                    return false
                }
                if lhs.items != rhs.items {
                    return false
                }
                if lhs.peer != rhs.peer {
                    return false
                }
                
                return true
            }
        }
        
        let peerSpecificPack: Signal<PeerSpecificPackData?, NoError>
        if let chatPeerId = chatPeerId {
            peerSpecificPack = combineLatest(
                context.engine.peers.peerSpecificStickerPack(peerId: chatPeerId),
                context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: chatPeerId))
            )
            |> map { packData, peer -> PeerSpecificPackData? in
                guard let peer = peer else {
                    return nil
                }
                
                guard let (info, items) = packData.packInfo else {
                    return nil
                }
                
                return PeerSpecificPackData(info: info, items: items.compactMap { $0 as? StickerPackItem }, peer: peer)
            }
            |> distinctUntilChanged
        } else {
            peerSpecificPack = .single(nil)
        }
        
        let strings = context.sharedContext.currentPresentationData.with({ $0 }).strings
        
        let searchCategories: Signal<EmojiSearchCategories?, NoError>
        switch subject {
        case .groupPhotoEmojiSelection, .profilePhotoEmojiSelection:
            searchCategories = context.engine.stickers.emojiSearchCategories(kind: .avatar)
        case .chatStickers, .greetingStickers:
            searchCategories = context.engine.stickers.emojiSearchCategories(kind: .combinedChatStickers)
            |> map { result -> EmojiSearchCategories? in
                guard let result else {
                    return nil
                }
                
                var groups: [EmojiSearchCategories.Group] = []
                groups = result.groups
                if case .greetingStickers = subject {
                    if let index = groups.firstIndex(where: { group in
                        return group.kind == .greeting
                    }) {
                        let group = groups.remove(at: index)
                        groups.insert(group, at: 0)
                    }
                } else if case .chatStickers = subject {
                    if let index = groups.firstIndex(where: { group in
                        return group.kind == .premium
                    }) {
                        let group = groups.remove(at: index)
                        groups.append(group)
                    }
                }
                
                return EmojiSearchCategories(
                    hash: result.hash,
                    groups: groups
                )
            }
        }
        
        return combineLatest(
            context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: stickerOrderedItemListCollectionIds, namespaces: stickerNamespaces, aroundIndex: nil, count: 10000000),
            hasPremium(context: context, chatPeerId: chatPeerId, premiumIfSavedMessages: false),
            hasTrending ? context.account.viewTracker.featuredStickerPacks() : .single([]),
            context.engine.data.get(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: Namespaces.CachedItemCollection.featuredStickersConfiguration, id: ValueBoxKey(length: 0))),
            ApplicationSpecificNotice.dismissedTrendingStickerPacks(accountManager: context.sharedContext.accountManager),
            peerSpecificPack,
            searchCategories
        )
        |> map { view, hasPremium, featuredStickerPacks, featuredStickersConfiguration, dismissedTrendingStickerPacks, peerSpecificPack, searchCategories -> EmojiPagerContentComponent in
            let hasPremium = forceHasPremium || hasPremium
            struct ItemGroup {
                var supergroupId: AnyHashable
                var id: AnyHashable
                var title: String
                var subtitle: String?
                var actionButtonTitle: String?
                var isPremiumLocked: Bool
                var isFeatured: Bool
                var displayPremiumBadges: Bool
                var hasEdit: Bool
                var headerItem: EntityKeyboardAnimationData?
                var items: [EmojiPagerContentComponent.Item]
            }
            var itemGroups: [ItemGroup] = []
            var itemGroupIndexById: [AnyHashable: Int] = [:]
            
            var savedStickers: OrderedItemListView?
            var recentStickers: OrderedItemListView?
            for orderedView in view.orderedItemListsViews {
                if orderedView.collectionId == Namespaces.OrderedItemList.CloudRecentStickers {
                    recentStickers = orderedView
                } else if orderedView.collectionId == Namespaces.OrderedItemList.CloudSavedStickers {
                    savedStickers = orderedView
                }
            }
            
            var installedCollectionIds = Set<ItemCollectionId>()
            for (id, _, _) in view.collectionInfos {
                installedCollectionIds.insert(id)
            }
            
            let dismissedTrendingStickerPacksSet = Set(dismissedTrendingStickerPacks ?? [])
            let featuredStickerPacksSet = Set(featuredStickerPacks.map(\.info.id.id))
            
            if dismissedTrendingStickerPacksSet != featuredStickerPacksSet {
                let featuredStickersConfiguration = featuredStickersConfiguration?.get(FeaturedStickersConfiguration.self)
                for featuredStickerPack in featuredStickerPacks {
                    if installedCollectionIds.contains(featuredStickerPack.info.id) {
                        continue
                    }
                    
                    guard let item = featuredStickerPack.topItems.first else {
                        continue
                    }
                    
                    let animationData: EntityKeyboardAnimationData
                    
                    if let thumbnail = featuredStickerPack.info.thumbnail {
                        let type: EntityKeyboardAnimationData.ItemType
                        if item.file.isAnimatedSticker {
                            type = .lottie
                        } else if item.file.isVideoEmoji || item.file.isVideoSticker {
                            type = .video
                        } else {
                            type = .still
                        }
                        
                        animationData = EntityKeyboardAnimationData(
                            id: .stickerPackThumbnail(featuredStickerPack.info.id),
                            type: type,
                            resource: .stickerPackThumbnail(stickerPack: .id(id: featuredStickerPack.info.id.id, accessHash: featuredStickerPack.info.accessHash), resource: thumbnail.resource),
                            dimensions: thumbnail.dimensions.cgSize,
                            immediateThumbnailData: featuredStickerPack.info.immediateThumbnailData,
                            isReaction: false,
                            isTemplate: false
                        )
                    } else {
                        animationData = EntityKeyboardAnimationData(file: item.file)
                    }
                    
                    var tintMode: Item.TintMode = .none
                    if item.file.isCustomTemplateEmoji {
                        tintMode = .primary
                    }
                    
                    let resultItem = EmojiPagerContentComponent.Item(
                        animationData: animationData,
                        content: .animation(animationData),
                        itemFile: item.file,
                        subgroupId: nil,
                        icon: .none,
                        tintMode: tintMode
                    )
                    
                    let supergroupId = "featuredTop"
                    let groupId: AnyHashable = supergroupId
                    let isPremiumLocked: Bool = item.file.isPremiumSticker && !hasPremium
                    if isPremiumLocked && isPremiumDisabled {
                        continue
                    }
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                    } else {
                        itemGroupIndexById[groupId] = itemGroups.count
                        
                        let trendingIsPremium = featuredStickersConfiguration?.isPremium ?? false
                        let title = trendingIsPremium ? strings.Stickers_TrendingPremiumStickers : strings.StickerPacksSettings_FeaturedPacks
                        
                        itemGroups.append(
                            ItemGroup(
                                supergroupId: groupId,
                                id: groupId,
                                title: title,
                                subtitle: nil,
                                actionButtonTitle: nil,
                                isPremiumLocked: false,
                                isFeatured: false,
                                displayPremiumBadges: false,
                                hasEdit: false,
                                headerItem: nil,
                                items: [resultItem]
                            )
                        )
                    }
                }
            }
            
            if let savedStickers = savedStickers {
                let groupId = "saved"
                for item in savedStickers.items {
                    guard let item = item.contents.get(SavedStickerItem.self) else {
                        continue
                    }
                    if isPremiumDisabled && item.file.isPremiumSticker {
                        continue
                    }
                    
                    var tintMode: Item.TintMode = .none
                    if item.file.isCustomTemplateEmoji {
                        tintMode = .primary
                    }
                    
                    let animationData = EntityKeyboardAnimationData(file: item.file, partialReference: .savedSticker)
                    let resultItem = EmojiPagerContentComponent.Item(
                        animationData: animationData,
                        content: .animation(animationData),
                        itemFile: item.file,
                        subgroupId: nil,
                        icon: .none,
                        tintMode: tintMode
                    )
                    
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                    } else {
                        itemGroupIndexById[groupId] = itemGroups.count
                        itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: strings.EmojiInput_SectionTitleFavoriteStickers, subtitle: nil, actionButtonTitle: nil, isPremiumLocked: false, isFeatured: false, displayPremiumBadges: false, hasEdit: false, headerItem: nil, items: [resultItem]))
                    }
                }
            }
            
            var addedCreateStickerButton = false
            if let recentStickers = recentStickers {
                let groupId = "recent"
                for item in recentStickers.items {
                    guard let item = item.contents.get(RecentMediaItem.self) else {
                        continue
                    }
                    if isPremiumDisabled && item.media.isPremiumSticker {
                        continue
                    }
                    
                    var tintMode: Item.TintMode = .none
                    if item.media.isCustomTemplateEmoji {
                        tintMode = .primary
                    }
                    
                    let animationData = EntityKeyboardAnimationData(file: item.media, partialReference: .recentSticker)
                    let resultItem = EmojiPagerContentComponent.Item(
                        animationData: animationData,
                        content: .animation(animationData),
                        itemFile: item.media,
                        subgroupId: nil,
                        icon: .none,
                        tintMode: tintMode
                    )
                    
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                    } else {
                        itemGroupIndexById[groupId] = itemGroups.count
                        itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: strings.Stickers_FrequentlyUsed, subtitle: nil, actionButtonTitle: nil, isPremiumLocked: false, isFeatured: false, displayPremiumBadges: false, hasEdit: false, headerItem: nil, items: [resultItem]))
                    }
                }
                
                if hasAdd && !addedCreateStickerButton, let groupIndex = itemGroupIndexById[groupId] {
                    let resultItem = EmojiPagerContentComponent.Item(
                        animationData: nil,
                        content: .icon(.add),
                        itemFile: nil,
                        subgroupId: nil,
                        icon: .none,
                        tintMode: .none
                    )
                    itemGroups[groupIndex].items.insert(resultItem, at: 0)
                    addedCreateStickerButton = true
                }
            }
              
            var avatarPeer: EnginePeer?
            if let peerSpecificPack = peerSpecificPack {
                avatarPeer = peerSpecificPack.peer
                
                var processedIds = Set<MediaId>()
                let groupId = "peerSpecific"
                for item in peerSpecificPack.items {
                    if isPremiumDisabled && item.file.isPremiumSticker {
                        continue
                    }
                    if processedIds.contains(item.file.fileId) {
                        continue
                    }
                    processedIds.insert(item.file.fileId)
                    
                    var tintMode: Item.TintMode = .none
                    if item.file.isCustomTemplateEmoji {
                        tintMode = .primary
                    }
                    
                    let animationData = EntityKeyboardAnimationData(file: item.file)
                    let resultItem = EmojiPagerContentComponent.Item(
                        animationData: animationData,
                        content: .animation(animationData),
                        itemFile: item.file,
                        subgroupId: nil,
                        icon: .none,
                        tintMode: tintMode
                    )
                    
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                    } else {
                        itemGroupIndexById[groupId] = itemGroups.count
                        itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: peerSpecificPack.peer.compactDisplayTitle, subtitle: nil, actionButtonTitle: nil, isPremiumLocked: false, isFeatured: false, displayPremiumBadges: false, hasEdit: false, headerItem: nil, items: [resultItem]))
                    }
                }
                
                if hasEdit && !addedCreateStickerButton, let groupIndex = itemGroupIndexById[groupId] {
                    let resultItem = EmojiPagerContentComponent.Item(
                        animationData: nil,
                        content: .icon(.add),
                        itemFile: nil,
                        subgroupId: nil,
                        icon: .none,
                        tintMode: .none
                    )
                    itemGroups[groupIndex].items.insert(resultItem, at: 0)
                    addedCreateStickerButton = true
                }
            }
            
            for entry in view.entries {
                guard let item = entry.item as? StickerPackItem else {
                    continue
                }
                
                var tintMode: Item.TintMode = .none
                if item.file.isCustomTemplateEmoji {
                    tintMode = .primary
                }
                
                let animationData = EntityKeyboardAnimationData(file: item.file)
                let resultItem = EmojiPagerContentComponent.Item(
                    animationData: animationData,
                    content: .animation(animationData),
                    itemFile: item.file,
                    subgroupId: nil,
                    icon: .none,
                    tintMode: tintMode
                )
                let groupId = entry.index.collectionId
                if let groupIndex = itemGroupIndexById[groupId] {
                    itemGroups[groupIndex].items.append(resultItem)
                } else {
                    itemGroupIndexById[groupId] = itemGroups.count
                    
                    var title = ""
                    var headerItem: EntityKeyboardAnimationData?
                    var groupHasEdit = false
                    inner: for (id, info, _) in view.collectionInfos {
                        if id == groupId, let info = info as? StickerPackCollectionInfo {
                            title = info.title
                            groupHasEdit = info.flags.contains(.isCreator)
                            
                            if let thumbnail = info.thumbnail {
                                let type: EntityKeyboardAnimationData.ItemType
                                if item.file.isAnimatedSticker {
                                    type = .lottie
                                } else if item.file.isVideoEmoji || item.file.isVideoSticker {
                                    type = .video
                                } else {
                                    type = .still
                                }
                                
                                headerItem = EntityKeyboardAnimationData(
                                    id: .stickerPackThumbnail(info.id),
                                    type: type,
                                    resource: .stickerPackThumbnail(stickerPack: .id(id: info.id.id, accessHash: info.accessHash), resource: thumbnail.resource),
                                    dimensions: thumbnail.dimensions.cgSize,
                                    immediateThumbnailData: info.immediateThumbnailData,
                                    isReaction: false,
                                    isTemplate: false
                                )
                            }
                            
                            break inner
                        }
                    }
                    itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: title, subtitle: nil, actionButtonTitle: nil, isPremiumLocked: false, isFeatured: false, displayPremiumBadges: true, hasEdit: hasEdit && groupHasEdit, headerItem: headerItem, items: [resultItem]))
                    
                    if hasEdit && !addedCreateStickerButton, let groupIndex = itemGroupIndexById[groupId] {
                        let resultItem = EmojiPagerContentComponent.Item(
                            animationData: nil,
                            content: .icon(.add),
                            itemFile: nil,
                            subgroupId: nil,
                            icon: .none,
                            tintMode: .none
                        )
                        itemGroups[groupIndex].items.insert(resultItem, at: 0)
                        addedCreateStickerButton = true
                    }
                }
            }
            
            for featuredStickerPack in featuredStickerPacks {
                if installedCollectionIds.contains(featuredStickerPack.info.id) {
                    continue
                }
                
                for item in featuredStickerPack.topItems {
                    var tintMode: Item.TintMode = .none
                    if item.file.isCustomTemplateEmoji {
                        tintMode = .primary
                    }
                    
                    let animationData = EntityKeyboardAnimationData(file: item.file)
                    let resultItem = EmojiPagerContentComponent.Item(
                        animationData: animationData,
                        content: .animation(animationData),
                        itemFile: item.file,
                        subgroupId: nil,
                        icon: .none,
                        tintMode: tintMode
                    )
                    
                    let supergroupId = featuredStickerPack.info.id
                    let groupId: AnyHashable = supergroupId
                    let isPremiumLocked: Bool = item.file.isPremiumSticker && !hasPremium
                    if isPremiumLocked && isPremiumDisabled {
                        continue
                    }
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                    } else {
                        itemGroupIndexById[groupId] = itemGroups.count
                        
                        let subtitle: String = strings.StickerPack_StickerCount(Int32(featuredStickerPack.info.count))
                        var headerItem: EntityKeyboardAnimationData?
                        
                        if let thumbnailFileId = featuredStickerPack.info.thumbnailFileId, let file = featuredStickerPack.topItems.first(where: { $0.file.fileId.id == thumbnailFileId }) {
                            headerItem = EntityKeyboardAnimationData(file: file.file)
                        } else if let thumbnail = featuredStickerPack.info.thumbnail {
                            let info = featuredStickerPack.info
                            let type: EntityKeyboardAnimationData.ItemType
                            if item.file.isAnimatedSticker {
                                type = .lottie
                            } else if item.file.isVideoEmoji || item.file.isVideoSticker {
                                type = .video
                            } else {
                                type = .still
                            }
                            
                            headerItem = EntityKeyboardAnimationData(
                                id: .stickerPackThumbnail(info.id),
                                type: type,
                                resource: .stickerPackThumbnail(stickerPack: .id(id: info.id.id, accessHash: info.accessHash), resource: thumbnail.resource),
                                dimensions: thumbnail.dimensions.cgSize,
                                immediateThumbnailData: info.immediateThumbnailData,
                                isReaction: false,
                                isTemplate: false
                            )
                        }
                        
                        itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: featuredStickerPack.info.title, subtitle: subtitle, actionButtonTitle: strings.Stickers_Install, isPremiumLocked: isPremiumLocked, isFeatured: true, displayPremiumBadges: false, hasEdit: false, headerItem: headerItem, items: [resultItem]))
                    }
                }
            }
            
            let isMasks = stickerNamespaces.contains(Namespaces.ItemCollection.CloudMaskPacks)
            
            let allItemGroups = itemGroups.map { group -> EmojiPagerContentComponent.ItemGroup in
                var hasClear = false
                var isEmbedded = false
                if group.id == AnyHashable("recent") {
                    hasClear = true
                } else if group.id == AnyHashable("featuredTop") {
                    hasClear = true
                    isEmbedded = true
                } else if group.id == AnyHashable("saved") {
                }
                
                return EmojiPagerContentComponent.ItemGroup(
                    supergroupId: group.supergroupId,
                    groupId: group.id,
                    title: group.title,
                    subtitle: group.subtitle,
                    badge: nil,
                    actionButtonTitle: group.actionButtonTitle,
                    isFeatured: group.isFeatured,
                    isPremiumLocked: group.isPremiumLocked,
                    isEmbedded: isEmbedded,
                    hasClear: hasClear,
                    hasEdit: group.hasEdit,
                    collapsedLineCount: nil,
                    displayPremiumBadges: group.displayPremiumBadges,
                    headerItem: group.headerItem,
                    fillWithLoadingPlaceholders: false,
                    items: group.items
                )
            }
            
            let warpContentsOnEdges: Bool
            switch subject {
            case .profilePhotoEmojiSelection, .groupPhotoEmojiSelection:
                warpContentsOnEdges = true
            default:
                warpContentsOnEdges = false
            }
            
            return EmojiPagerContentComponent(
                id: isMasks ? "masks" : "stickers",
                context: context,
                avatarPeer: avatarPeer,
                animationCache: animationCache,
                animationRenderer: animationRenderer,
                inputInteractionHolder: EmojiPagerContentComponent.InputInteractionHolder(),
                panelItemGroups: allItemGroups,
                contentItemGroups: allItemGroups,
                itemLayoutType: .detailed,
                itemContentUniqueId: nil,
                searchState: .empty(hasResults: false),
                warpContentsOnEdges: warpContentsOnEdges,
                hideBackground: hideBackground,
                displaySearchWithPlaceholder: hasSearch ? strings.StickersSearch_SearchStickersPlaceholder : nil,
                searchCategories: searchCategories,
                searchInitiallyHidden: true,
                searchAlwaysActive: false,
                searchIsPlaceholderOnly: searchIsPlaceholderOnly,
                searchUnicodeEmojiOnly: false,
                emptySearchResults: nil,
                enableLongPress: false,
                selectedItems: Set(),
                customTintColor: nil
            )
        }
    }
    
    static func messageEffectsInputData(
        context: AccountContext,
        animationCache: AnimationCache,
        animationRenderer: MultiAnimationRenderer,
        hasSearch: Bool,
        hideBackground: Bool = false
    ) -> Signal<EmojiPagerContentComponent, NoError> {
        let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
        let isPremiumDisabled = premiumConfiguration.isPremiumDisabled
        
        let strings = context.sharedContext.currentPresentationData.with({ $0 }).strings
        
        let searchCategories: Signal<EmojiSearchCategories?, NoError> = context.engine.stickers.emojiSearchCategories(kind: .emoji)
        
        return combineLatest(
            hasPremium(context: context, chatPeerId: nil, premiumIfSavedMessages: false),
            context.engine.stickers.availableMessageEffects(),
            searchCategories
        )
        |> map { hasPremium, availableMessageEffects, searchCategories -> EmojiPagerContentComponent in
            struct ItemGroup {
                var supergroupId: AnyHashable
                var id: AnyHashable
                var title: String?
                var subtitle: String?
                var actionButtonTitle: String?
                var isPremiumLocked: Bool
                var isFeatured: Bool
                var displayPremiumBadges: Bool
                var hasEdit: Bool
                var headerItem: EntityKeyboardAnimationData?
                var items: [EmojiPagerContentComponent.Item]
            }
            var itemGroups: [ItemGroup] = []
            var itemGroupIndexById: [AnyHashable: Int] = [:]
            
            if let availableMessageEffects {
                var reactionEffects: [AvailableMessageEffects.MessageEffect] = []
                var stickerEffects: [AvailableMessageEffects.MessageEffect] = []
                for messageEffect in availableMessageEffects.messageEffects {
                    if messageEffect.effectAnimation != nil {
                        reactionEffects.append(messageEffect)
                    } else {
                        stickerEffects.append(messageEffect)
                    }
                }
                
                for i in 0 ..< 2 {
                    let groupId = i == 0 ? "reactions" : "stickers"
                    for item in i == 0 ? reactionEffects : stickerEffects {
                        if item.isPremium && isPremiumDisabled {
                            continue
                        }
                        
                        let itemFile: TelegramMediaFile = item.effectSticker
                        
                        var tintMode: Item.TintMode = .none
                        if itemFile.isCustomTemplateEmoji {
                            tintMode = .primary
                        }
                        
                        let icon: EmojiPagerContentComponent.Item.Icon
                        if i == 0 {
                            if !hasPremium && item.isPremium {
                                icon = .locked
                            } else {
                                icon = .none
                            }
                        } else {
                            if !hasPremium && item.isPremium {
                                icon = .locked
                            } else if let staticIcon = item.staticIcon {
                                icon = .customFile(staticIcon)
                            } else {
                                icon = .text(item.emoticon)
                            }
                        }
                        
                        let animationData = EntityKeyboardAnimationData(file: itemFile, partialReference: .none)
                        let resultItem = EmojiPagerContentComponent.Item(
                            animationData: animationData,
                            content: .animation(animationData),
                            itemFile: itemFile,
                            subgroupId: nil,
                            icon: icon,
                            tintMode: tintMode
                        )
                        
                        if let groupIndex = itemGroupIndexById[groupId] {
                            itemGroups[groupIndex].items.append(resultItem)
                        } else {
                            itemGroupIndexById[groupId] = itemGroups.count
                            itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: i == 0 ? nil : strings.Chat_MessageEffectMenu_SectionMessageEffects, subtitle: nil, actionButtonTitle: nil, isPremiumLocked: false, isFeatured: false, displayPremiumBadges: false, hasEdit: false, headerItem: nil, items: [resultItem]))
                        }
                    }
                }
            }
            
            let warpContentsOnEdges: Bool = true
            
            let allItemGroups = itemGroups.map { group -> EmojiPagerContentComponent.ItemGroup in
                let hasClear = false
                let isEmbedded = false
                
                return EmojiPagerContentComponent.ItemGroup(
                    supergroupId: group.supergroupId,
                    groupId: group.id,
                    title: group.title,
                    subtitle: group.subtitle,
                    badge: nil,
                    actionButtonTitle: group.actionButtonTitle,
                    isFeatured: group.isFeatured,
                    isPremiumLocked: group.isPremiumLocked,
                    isEmbedded: isEmbedded,
                    hasClear: hasClear,
                    hasEdit: group.hasEdit,
                    collapsedLineCount: nil,
                    displayPremiumBadges: group.displayPremiumBadges,
                    headerItem: group.headerItem,
                    fillWithLoadingPlaceholders: false,
                    items: group.items
                )
            }
            
            return EmojiPagerContentComponent(
                id: "stickers",
                context: context,
                avatarPeer: nil,
                animationCache: animationCache,
                animationRenderer: animationRenderer,
                inputInteractionHolder: EmojiPagerContentComponent.InputInteractionHolder(),
                panelItemGroups: [],
                contentItemGroups: allItemGroups,
                itemLayoutType: .detailed,
                itemContentUniqueId: nil,
                searchState: .empty(hasResults: false),
                warpContentsOnEdges: warpContentsOnEdges,
                hideBackground: hideBackground,
                displaySearchWithPlaceholder: hasSearch ? strings.StickersSearch_SearchStickersPlaceholder : nil,
                searchCategories: searchCategories,
                searchInitiallyHidden: true,
                searchAlwaysActive: false,
                searchIsPlaceholderOnly: false,
                searchUnicodeEmojiOnly: false,
                emptySearchResults: nil,
                enableLongPress: false,
                selectedItems: Set(),
                customTintColor: nil
            )
        }
    }
}
