import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import AccountContext
import ChatPresentationInterfaceState
import ComponentFlow
import EntityKeyboard
import AnimationCache
import MultiAnimationRenderer
import Postbox
import TelegramCore
import ComponentDisplayAdapters
import SettingsUI
import TextFormat
import PagerComponent
import AppBundle
import PremiumUI
import AudioToolbox
import UndoUI
import ContextUI
import GalleryUI
import AttachmentTextInputPanelNode
import TelegramPresentationData

private let staticEmojiMapping: [(EmojiPagerContentComponent.StaticEmojiSegment, [String])] = {
    guard let path = getAppBundle().path(forResource: "emoji1016", ofType: "txt") else {
        return []
    }
    guard let string = try? String(contentsOf: URL(fileURLWithPath: path)) else {
        return []
    }
    
    var result: [(EmojiPagerContentComponent.StaticEmojiSegment, [String])] = []
    
    let orderedSegments = EmojiPagerContentComponent.StaticEmojiSegment.allCases
    
    let segments = string.components(separatedBy: "\n\n")
    for i in 0 ..< min(segments.count, orderedSegments.count) {
        let list = segments[i].components(separatedBy: " ")
        result.append((orderedSegments[i], list))
    }
    
    return result
}()

final class ChatEntityKeyboardInputNode: ChatInputNode {
    struct InputData: Equatable {
        var emoji: EmojiPagerContentComponent
        var stickers: EmojiPagerContentComponent?
        var gifs: GifPagerContentComponent?
        var availableGifSearchEmojies: [EntityKeyboardComponent.GifSearchEmoji]
        
        init(
            emoji: EmojiPagerContentComponent,
            stickers: EmojiPagerContentComponent?,
            gifs: GifPagerContentComponent?,
            availableGifSearchEmojies: [EntityKeyboardComponent.GifSearchEmoji]
        ) {
            self.emoji = emoji
            self.stickers = stickers
            self.gifs = gifs
            self.availableGifSearchEmojies = availableGifSearchEmojies
        }
    }
    
    static func emojiInputData(context: AccountContext, inputInteraction: EmojiPagerContentComponent.InputInteraction, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer) -> Signal<EmojiPagerContentComponent, NoError> {
        let hasPremium = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
        |> map { peer -> Bool in
            guard case let .user(user) = peer else {
                return false
            }
            return user.isPremium
        }
        |> distinctUntilChanged
        
        let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
        let isPremiumDisabled = premiumConfiguration.isPremiumDisabled
        
        let emojiItems: Signal<EmojiPagerContentComponent, NoError> = combineLatest(
            context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.LocalRecentEmoji], namespaces: [Namespaces.ItemCollection.CloudEmojiPacks], aroundIndex: nil, count: 10000000),
            hasPremium,
            context.account.viewTracker.featuredEmojiPacks()
        )
        |> map { view, hasPremium, featuredEmojiPacks -> EmojiPagerContentComponent in
            struct ItemGroup {
                var supergroupId: AnyHashable
                var id: AnyHashable
                var title: String
                var isPremiumLocked: Bool
                var isFeatured: Bool
                var items: [EmojiPagerContentComponent.Item]
            }
            var itemGroups: [ItemGroup] = []
            var itemGroupIndexById: [AnyHashable: Int] = [:]
            
            var recentEmoji: OrderedItemListView?
            for orderedView in view.orderedItemListsViews {
                if orderedView.collectionId == Namespaces.OrderedItemList.LocalRecentEmoji {
                    recentEmoji = orderedView
                }
            }
            
            if let recentEmoji = recentEmoji {
                for item in recentEmoji.items {
                    guard let item = item.contents.get(RecentEmojiItem.self) else {
                        continue
                    }
                    
                    if case let .file(file) = item.content, isPremiumDisabled, file.isPremiumEmoji {
                        continue
                    }
                    
                    let resultItem: EmojiPagerContentComponent.Item
                    switch item.content {
                    case let .file(file):
                        resultItem = EmojiPagerContentComponent.Item(
                            file: file,
                            staticEmoji: nil,
                            subgroupId: nil
                        )
                    case let .text(text):
                        resultItem = EmojiPagerContentComponent.Item(
                            file: nil,
                            staticEmoji: text,
                            subgroupId: nil
                        )
                    }
                    
                    let groupId = "recent"
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                    } else {
                        itemGroupIndexById[groupId] = itemGroups.count
                        //TODO:localize
                        itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: "Recently Used", isPremiumLocked: false, isFeatured: false, items: [resultItem]))
                    }
                }
            }
            
            for (subgroupId, list) in staticEmojiMapping {
                let groupId: AnyHashable = "static"
                for emojiString in list {
                    let resultItem = EmojiPagerContentComponent.Item(
                        file: nil,
                        staticEmoji: emojiString,
                        subgroupId: subgroupId.rawValue
                    )
                    
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                    } else {
                        itemGroupIndexById[groupId] = itemGroups.count
                        //TODO:localize
                        itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: "Emoji", isPremiumLocked: false, isFeatured: false, items: [resultItem]))
                    }
                }
            }
            
            var installedCollectionIds = Set<ItemCollectionId>()
            for (id, _, _) in view.collectionInfos {
                installedCollectionIds.insert(id)
            }
            
            for entry in view.entries {
                guard let item = entry.item as? StickerPackItem else {
                    continue
                }
                let resultItem = EmojiPagerContentComponent.Item(
                    file: item.file,
                    staticEmoji: nil,
                    subgroupId: nil
                )
                
                let supergroupId = entry.index.collectionId
                let groupId: AnyHashable = supergroupId
                let isPremiumLocked: Bool = item.file.isPremiumEmoji && !hasPremium
                if isPremiumLocked && isPremiumDisabled {
                    continue
                }
                if let groupIndex = itemGroupIndexById[groupId] {
                    itemGroups[groupIndex].items.append(resultItem)
                } else {
                    itemGroupIndexById[groupId] = itemGroups.count
                    
                    var title = ""
                    inner: for (id, info, _) in view.collectionInfos {
                        if id == entry.index.collectionId, let info = info as? StickerPackCollectionInfo {
                            title = info.title
                            break inner
                        }
                    }
                    itemGroups.append(ItemGroup(supergroupId: supergroupId, id: groupId, title: title, isPremiumLocked: isPremiumLocked, isFeatured: false, items: [resultItem]))
                }
            }
            
            for featuredEmojiPack in featuredEmojiPacks {
                if installedCollectionIds.contains(featuredEmojiPack.info.id) {
                    continue
                }
                
                for item in featuredEmojiPack.topItems {
                    let resultItem = EmojiPagerContentComponent.Item(
                        file: item.file,
                        staticEmoji: nil,
                        subgroupId: nil
                    )
                    
                    let supergroupId = featuredEmojiPack.info.id
                    let groupId: AnyHashable = supergroupId
                    let isPremiumLocked: Bool = item.file.isPremiumEmoji && !hasPremium
                    if isPremiumLocked && isPremiumDisabled {
                        continue
                    }
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                    } else {
                        itemGroupIndexById[groupId] = itemGroups.count
                        itemGroups.append(ItemGroup(supergroupId: supergroupId, id: groupId, title: featuredEmojiPack.info.title, isPremiumLocked: isPremiumLocked, isFeatured: true, items: [resultItem]))
                    }
                }
            }
            
            return EmojiPagerContentComponent(
                id: "emoji",
                context: context,
                animationCache: animationCache,
                animationRenderer: animationRenderer,
                inputInteraction: inputInteraction,
                itemGroups: itemGroups.map { group -> EmojiPagerContentComponent.ItemGroup in
                    var hasClear = false
                    if group.id == AnyHashable("recent") {
                        hasClear = true
                    }
                    
                    return EmojiPagerContentComponent.ItemGroup(supergroupId: group.supergroupId, groupId: group.id, title: group.title, isFeatured: group.isFeatured, isPremiumLocked: group.isPremiumLocked, hasClear: hasClear, displayPremiumBadges: false, items: group.items)
                },
                itemLayoutType: .compact
            )
        }
        return emojiItems
    }
    
    static func inputData(context: AccountContext, interfaceInteraction: ChatPanelInterfaceInteraction, controllerInteraction: ChatControllerInteraction?, chatPeerId: PeerId?) -> Signal<InputData, NoError> {
        let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
        let isPremiumDisabled = premiumConfiguration.isPremiumDisabled
        
        let hasPremium = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
        |> map { peer -> Bool in
            guard case let .user(user) = peer else {
                return false
            }
            return user.isPremium
        }
        |> distinctUntilChanged
        
        let emojiInputInteraction = EmojiPagerContentComponent.InputInteraction(
            performItemAction: { [weak interfaceInteraction, weak controllerInteraction] item, _, _, _ in
                let _ = (hasPremium |> take(1) |> deliverOnMainQueue).start(next: { hasPremium in
                    guard let controllerInteraction = controllerInteraction, let interfaceInteraction = interfaceInteraction else {
                        return
                    }
                    
                    if let file = item.file {
                        var text = "."
                        var emojiAttribute: ChatTextInputTextCustomEmojiAttribute?
                        loop: for attribute in file.attributes {
                            switch attribute {
                            case let .CustomEmoji(_, displayText, packReference):
                                text = displayText
                                emojiAttribute = ChatTextInputTextCustomEmojiAttribute(stickerPack: packReference, fileId: file.fileId.id, file: file)
                                break loop
                            default:
                                break
                            }
                        }
                        
                        if file.isPremiumEmoji && !hasPremium {
                            //TODO:localize
                                                        
                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                            controllerInteraction.presentController(UndoOverlayController(presentationData: presentationData, content: .sticker(context: context, file: file, title: nil, text: "Subscribe to Telegram Premium to unlock this emoji.", undoText: "More", customAction: { [weak controllerInteraction] in
                                guard let controllerInteraction = controllerInteraction else {
                                    return
                                }
                                
                                var replaceImpl: ((ViewController) -> Void)?
                                let controller = PremiumDemoScreen(context: context, subject: .animatedEmoji, action: {
                                    let controller = PremiumIntroScreen(context: context, source: .stickers)
                                    replaceImpl?(controller)
                                })
                                replaceImpl = { [weak controller] c in
                                    controller?.replace(with: c)
                                }
                                controllerInteraction.navigationController()?.pushViewController(controller)
                                
                                /*let controller = PremiumIntroScreen(context: context, source: .stickers)
                                controllerInteraction.navigationController()?.pushViewController(controller)*/
                            }), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
                            return
                        }
                        
                        if let emojiAttribute = emojiAttribute {
                            AudioServicesPlaySystemSound(0x450)
                            interfaceInteraction.insertText(NSAttributedString(string: text, attributes: [ChatTextInputAttributes.customEmoji: emojiAttribute]))
                        }
                    } else if let staticEmoji = item.staticEmoji {
                        AudioServicesPlaySystemSound(0x450)
                        interfaceInteraction.insertText(NSAttributedString(string: staticEmoji, attributes: [:]))
                    }
                })
            },
            deleteBackwards: { [weak interfaceInteraction] in
                guard let interfaceInteraction = interfaceInteraction else {
                    return
                }
                interfaceInteraction.backwardsDeleteText()
            },
            openStickerSettings: {
            },
            addGroupAction: { [weak controllerInteraction] groupId, isPremiumLocked in
                guard let controllerInteraction = controllerInteraction, let collectionId = groupId.base as? ItemCollectionId else {
                    return
                }
                
                if isPremiumLocked {
                    let controller = PremiumIntroScreen(context: context, source: .stickers)
                    controllerInteraction.navigationController()?.pushViewController(controller)
                    
                    return
                }
                
                let viewKey = PostboxViewKey.orderedItemList(id: Namespaces.OrderedItemList.CloudFeaturedEmojiPacks)
                let _ = (context.account.postbox.combinedView(keys: [viewKey])
                |> take(1)
                |> deliverOnMainQueue).start(next: { views in
                    guard let view = views.views[viewKey] as? OrderedItemListView else {
                        return
                    }
                    for featuredEmojiPack in view.items.lazy.map({ $0.contents.get(FeaturedStickerPackItem.self)! }) {
                        if featuredEmojiPack.info.id == collectionId {
                            let _ = context.engine.stickers.addStickerPackInteractively(info: featuredEmojiPack.info, items: featuredEmojiPack.topItems).start()
                            
                            break
                        }
                    }
                })
            },
            clearGroup: { [weak controllerInteraction] groupId in
                guard let controllerInteraction = controllerInteraction else {
                    return
                }
                if groupId == AnyHashable("recent") {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    let actionSheet = ActionSheetController(theme: ActionSheetControllerTheme(presentationTheme: presentationData.theme, fontSize: presentationData.listsFontSize))
                    var items: [ActionSheetItem] = []
                    items.append(ActionSheetButtonItem(title: presentationData.strings.Emoji_ClearRecent, color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        let _ = context.engine.stickers.clearRecentlyUsedEmoji().start()
                    }))
                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    controllerInteraction.presentController(actionSheet, nil)
                }
            },
            pushController: { [weak controllerInteraction] controller in
                guard let controllerInteraction = controllerInteraction else {
                    return
                }
                controllerInteraction.navigationController()?.pushViewController(controller)
            },
            presentController: { [weak controllerInteraction] controller in
                guard let controllerInteraction = controllerInteraction else {
                    return
                }
                controllerInteraction.presentController(controller, nil)
            },
            presentGlobalOverlayController: { [weak controllerInteraction] controller in
                guard let controllerInteraction = controllerInteraction else {
                    return
                }
                controllerInteraction.presentGlobalOverlayController(controller, nil)
            },
            navigationController: { [weak controllerInteraction] in
                return controllerInteraction?.navigationController()
            },
            sendSticker: { [weak controllerInteraction] fileReference, silentPosting, schedule, query, clearInput, sourceView, sourceRect, sourceLayer in
                guard let controllerInteraction = controllerInteraction else {
                    return
                }
                let _ = controllerInteraction.sendSticker(fileReference, silentPosting, schedule, query, clearInput, sourceView, sourceRect, sourceLayer)
            },
            chatPeerId: chatPeerId
        )
        let stickerInputInteraction = EmojiPagerContentComponent.InputInteraction(
            performItemAction: { [weak controllerInteraction, weak interfaceInteraction] item, view, rect, layer in
                let _ = (hasPremium |> take(1) |> deliverOnMainQueue).start(next: { hasPremium in
                    guard let controllerInteraction = controllerInteraction, let interfaceInteraction = interfaceInteraction else {
                        return
                    }
                    if let file = item.file {
                        if file.isPremiumSticker && !hasPremium {
                            let controller = PremiumIntroScreen(context: context, source: .stickers)
                            controllerInteraction.navigationController()?.pushViewController(controller)
                            
                            return
                        }
                        let _ = interfaceInteraction.sendSticker(.standalone(media: file), false, view, rect, layer)
                    }
                })
            },
            deleteBackwards: { [weak interfaceInteraction] in
                guard let interfaceInteraction = interfaceInteraction else {
                    return
                }
                interfaceInteraction.backwardsDeleteText()
            },
            openStickerSettings: { [weak controllerInteraction] in
                guard let controllerInteraction = controllerInteraction else {
                    return
                }
                let controller = installedStickerPacksController(context: context, mode: .modal)
                controller.navigationPresentation = .modal
                controllerInteraction.navigationController()?.pushViewController(controller)
            },
            addGroupAction: { _, _ in
            },
            clearGroup: { [weak controllerInteraction] groupId in
                guard let controllerInteraction = controllerInteraction else {
                    return
                }
                if groupId == AnyHashable("recent") {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    let actionSheet = ActionSheetController(theme: ActionSheetControllerTheme(presentationTheme: presentationData.theme, fontSize: presentationData.listsFontSize))
                    var items: [ActionSheetItem] = []
                    items.append(ActionSheetButtonItem(title: presentationData.strings.Stickers_ClearRecent, color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        let _ = context.engine.stickers.clearRecentlyUsedStickers().start()
                    }))
                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    controllerInteraction.presentController(actionSheet, nil)
                }
            },
            pushController: { [weak controllerInteraction] controller in
                guard let controllerInteraction = controllerInteraction else {
                    return
                }
                controllerInteraction.navigationController()?.pushViewController(controller)
            },
            presentController: { [weak controllerInteraction] controller in
                guard let controllerInteraction = controllerInteraction else {
                    return
                }
                controllerInteraction.presentController(controller, nil)
            },
            presentGlobalOverlayController: { [weak controllerInteraction] controller in
                guard let controllerInteraction = controllerInteraction else {
                    return
                }
                controllerInteraction.presentGlobalOverlayController(controller, nil)
            },
            navigationController: { [weak controllerInteraction] in
                return controllerInteraction?.navigationController()
            },
            sendSticker: { [weak controllerInteraction] fileReference, silentPosting, schedule, query, clearInput, sourceView, sourceRect, sourceLayer in
                guard let controllerInteraction = controllerInteraction else {
                    return
                }
                let _ = controllerInteraction.sendSticker(fileReference, silentPosting, schedule, query, clearInput, sourceView, sourceRect, sourceLayer)
            },
            chatPeerId: chatPeerId
        )
        
        let animationCache = AnimationCacheImpl(basePath: context.account.postbox.mediaBox.basePath + "/animation-cache", allocateTempFile: {
            return TempBox.shared.tempFile(fileName: "file").path
        })
        let animationRenderer: MultiAnimationRenderer
        /*if #available(iOS 13.0, *) {
            animationRenderer = MultiAnimationMetalRendererImpl()
        } else {*/
            animationRenderer = MultiAnimationRendererImpl()
        //}
        
        let emojiItems = emojiInputData(context: context, inputInteraction: emojiInputInteraction, animationCache: animationCache, animationRenderer: animationRenderer)
        
        let stickerNamespaces: [ItemCollectionId.Namespace] = [Namespaces.ItemCollection.CloudStickerPacks]
        let stickerOrderedItemListCollectionIds: [Int32] = [Namespaces.OrderedItemList.CloudSavedStickers, Namespaces.OrderedItemList.CloudRecentStickers, Namespaces.OrderedItemList.PremiumStickers, Namespaces.OrderedItemList.CloudPremiumStickers]
        
        let stickerItems: Signal<EmojiPagerContentComponent, NoError> = combineLatest(
            context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: stickerOrderedItemListCollectionIds, namespaces: stickerNamespaces, aroundIndex: nil, count: 10000000),
            hasPremium,
            context.account.viewTracker.featuredStickerPacks()
        )
        |> map { view, hasPremium, featuredStickerPacks -> EmojiPagerContentComponent in
            struct ItemGroup {
                var supergroupId: AnyHashable
                var id: AnyHashable
                var title: String
                var isPremiumLocked: Bool
                var isFeatured: Bool
                var displayPremiumBadges: Bool
                var items: [EmojiPagerContentComponent.Item]
            }
            var itemGroups: [ItemGroup] = []
            var itemGroupIndexById: [AnyHashable: Int] = [:]
            
            var savedStickers: OrderedItemListView?
            var recentStickers: OrderedItemListView?
            var premiumStickers: OrderedItemListView?
            var cloudPremiumStickers: OrderedItemListView?
            for orderedView in view.orderedItemListsViews {
                if orderedView.collectionId == Namespaces.OrderedItemList.CloudRecentStickers {
                    recentStickers = orderedView
                } else if orderedView.collectionId == Namespaces.OrderedItemList.CloudSavedStickers {
                    savedStickers = orderedView
                } else if orderedView.collectionId == Namespaces.OrderedItemList.PremiumStickers {
                    premiumStickers = orderedView
                } else if orderedView.collectionId == Namespaces.OrderedItemList.CloudPremiumStickers {
                    cloudPremiumStickers = orderedView
                }
            }
            
            if let savedStickers = savedStickers {
                for item in savedStickers.items {
                    guard let item = item.contents.get(SavedStickerItem.self) else {
                        continue
                    }
                    if isPremiumDisabled && item.file.isPremiumSticker {
                        continue
                    }
                    
                    let resultItem = EmojiPagerContentComponent.Item(
                        file: item.file,
                        staticEmoji: nil,
                        subgroupId: nil
                    )
                    
                    let groupId = "saved"
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                    } else {
                        itemGroupIndexById[groupId] = itemGroups.count
                        //TODO:localize
                        itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: "Saved", isPremiumLocked: false, isFeatured: false, displayPremiumBadges: false, items: [resultItem]))
                    }
                }
            }
            
            if let recentStickers = recentStickers {
                var count = 0
                for item in recentStickers.items {
                    guard let item = item.contents.get(RecentMediaItem.self) else {
                        continue
                    }
                    if isPremiumDisabled && item.media.isPremiumSticker {
                        continue
                    }
                    
                    let resultItem = EmojiPagerContentComponent.Item(
                        file: item.media,
                        staticEmoji: nil,
                        subgroupId: nil
                    )
                    
                    let groupId = "recent"
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                    } else {
                        itemGroupIndexById[groupId] = itemGroups.count
                        //TODO:localize
                        itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: "Recently Used", isPremiumLocked: false, isFeatured: false, displayPremiumBadges: false, items: [resultItem]))
                    }
                    
                    count += 1
                    if count >= 5 {
                        break
                    }
                }
            }
            
            var hasPremiumStickers = false
            if hasPremium {
                if let premiumStickers = premiumStickers, !premiumStickers.items.isEmpty {
                    hasPremiumStickers = true
                } else if let cloudPremiumStickers = cloudPremiumStickers, !cloudPremiumStickers.items.isEmpty {
                    hasPremiumStickers = true
                }
            }
            
            if hasPremiumStickers {
                var premiumStickers = premiumStickers?.items ?? []
                if let cloudPremiumStickers = cloudPremiumStickers {
                    premiumStickers.append(contentsOf: cloudPremiumStickers.items)
                }
                
                var processedIds = Set<MediaId>()
                for item in premiumStickers {
                    guard let item = item.contents.get(RecentMediaItem.self) else {
                        continue
                    }
                    if isPremiumDisabled && item.media.isPremiumSticker {
                        continue
                    }
                    if processedIds.contains(item.media.fileId) {
                        continue
                    }
                    processedIds.insert(item.media.fileId)
                    
                    let resultItem = EmojiPagerContentComponent.Item(
                        file: item.media,
                        staticEmoji: nil,
                        subgroupId: nil
                    )
                    
                    let groupId = "premium"
                    if let groupIndex = itemGroupIndexById[groupId] {
                        itemGroups[groupIndex].items.append(resultItem)
                    } else {
                        itemGroupIndexById[groupId] = itemGroups.count
                        //TODO:localize
                        itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: "Premium", isPremiumLocked: false, isFeatured: false, displayPremiumBadges: false, items: [resultItem]))
                    }
                }
            }
            
            var installedCollectionIds = Set<ItemCollectionId>()
            for (id, _, _) in view.collectionInfos {
                installedCollectionIds.insert(id)
            }
            
            for entry in view.entries {
                guard let item = entry.item as? StickerPackItem else {
                    continue
                }
                let resultItem = EmojiPagerContentComponent.Item(
                    file: item.file,
                    staticEmoji: nil,
                    subgroupId: nil
                )
                let groupId = entry.index.collectionId
                if let groupIndex = itemGroupIndexById[groupId] {
                    itemGroups[groupIndex].items.append(resultItem)
                } else {
                    itemGroupIndexById[groupId] = itemGroups.count
                    
                    var title = ""
                    inner: for (id, info, _) in view.collectionInfos {
                        if id == groupId, let info = info as? StickerPackCollectionInfo {
                            title = info.title
                            break inner
                        }
                    }
                    itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: title, isPremiumLocked: false, isFeatured: false, displayPremiumBadges: true, items: [resultItem]))
                }
            }
            
            for featuredStickerPack in featuredStickerPacks {
                if installedCollectionIds.contains(featuredStickerPack.info.id) {
                    continue
                }
                
                for item in featuredStickerPack.topItems {
                    let resultItem = EmojiPagerContentComponent.Item(
                        file: item.file,
                        staticEmoji: nil,
                        subgroupId: nil
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
                        itemGroups.append(ItemGroup(supergroupId: groupId, id: groupId, title: featuredStickerPack.info.title, isPremiumLocked: isPremiumLocked, isFeatured: true, displayPremiumBadges: false, items: [resultItem]))
                    }
                }
            }
            
            return EmojiPagerContentComponent(
                id: "stickers",
                context: context,
                animationCache: animationCache,
                animationRenderer: animationRenderer,
                inputInteraction: stickerInputInteraction,
                itemGroups: itemGroups.map { group -> EmojiPagerContentComponent.ItemGroup in
                    var hasClear = false
                    if group.id == AnyHashable("recent") {
                        hasClear = true
                    }
                    
                    return EmojiPagerContentComponent.ItemGroup(supergroupId: group.supergroupId, groupId: group.id, title: group.title, isFeatured: group.isFeatured, isPremiumLocked: group.isPremiumLocked, hasClear: hasClear, displayPremiumBadges: group.displayPremiumBadges, items: group.items)
                },
                itemLayoutType: .detailed
            )
        }
        
        let reactions: Signal<[String], NoError> = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.App())
        |> map { appConfiguration -> [String] in
            let defaultReactions: [String] = ["👍", "👎", "😍", "😂", "😯", "😕", "😢", "😡", "💪", "👏", "🙈", "😒"]
            
            guard let data = appConfiguration.data, let emojis = data["gif_search_emojies"] as? [String] else {
                return defaultReactions
            }
            return emojis
        }
        |> distinctUntilChanged
        
        let animatedEmojiStickers = context.engine.stickers.loadedStickerPack(reference: .animatedEmoji, forceActualized: false)
        |> map { animatedEmoji -> [String: [StickerPackItem]] in
            var animatedEmojiStickers: [String: [StickerPackItem]] = [:]
            switch animatedEmoji {
                case let .result(_, items, _):
                    for item in items {
                        if let emoji = item.getStringRepresentationsOfIndexKeys().first {
                            animatedEmojiStickers[emoji.basicEmoji.0] = [item]
                            let strippedEmoji = emoji.basicEmoji.0.strippedEmoji
                            if animatedEmojiStickers[strippedEmoji] == nil {
                                animatedEmojiStickers[strippedEmoji] = [item]
                            }
                        }
                    }
                default:
                    break
            }
            return animatedEmojiStickers
        }
        
        let gifInputInteraction = GifPagerContentComponent.InputInteraction(
            performItemAction: { [weak controllerInteraction] item, view, rect in
                guard let controllerInteraction = controllerInteraction else {
                    return
                }
                let _ = controllerInteraction.sendGif(.savedGif(media: item.file), view, rect, false, false)
            },
            openGifContextMenu: { _, _, _, _, _ in
            },
            loadMore: { _ in
            }
        )
        
        // We are going to subscribe to the actual data when the view is loaded
        let gifItems: Signal<GifPagerContentComponent, NoError> = .single(GifPagerContentComponent(
            context: context,
            inputInteraction: gifInputInteraction,
            subject: .recent,
            items: [],
            isLoading: false,
            loadMoreToken: nil
        ))
        
        let strings = context.sharedContext.currentPresentationData.with({ $0 }).strings
        return combineLatest(queue: .mainQueue(),
            emojiItems,
            stickerItems,
            gifItems,
            reactions,
            animatedEmojiStickers
        )
        |> map { emoji, stickers, gifs, reactions, animatedEmojiStickers -> InputData in
            var availableGifSearchEmojies: [EntityKeyboardComponent.GifSearchEmoji] = []
            for reaction in reactions {
                if let file = animatedEmojiStickers[reaction]?.first?.file {
                    var title: String?
                    switch reaction {
                        case "😡":
                            title = strings.Gif_Emotion_Angry
                        case "😮":
                            title = strings.Gif_Emotion_Surprised
                        case "😂":
                            title = strings.Gif_Emotion_Joy
                        case "😘":
                            title = strings.Gif_Emotion_Kiss
                        case "😍":
                            title = strings.Gif_Emotion_Hearts
                        case "👍":
                            title = strings.Gif_Emotion_ThumbsUp
                        case "👎":
                            title = strings.Gif_Emotion_ThumbsDown
                        case "🙄":
                            title = strings.Gif_Emotion_RollEyes
                        case "😎":
                            title = strings.Gif_Emotion_Cool
                        case "🥳":
                            title = strings.Gif_Emotion_Party
                        default:
                            break
                    }
                    
                    guard let title = title else {
                        continue
                    }
                    
                    availableGifSearchEmojies.append(EntityKeyboardComponent.GifSearchEmoji(emoji: reaction, file: file, title: title))
                }
            }
            
            return InputData(
                emoji: emoji,
                stickers: stickers,
                gifs: gifs,
                availableGifSearchEmojies: availableGifSearchEmojies
            )
        }
    }
    
    private let context: AccountContext
    private let entityKeyboardView: ComponentHostView<Empty>
    
    private let defaultToEmojiTab: Bool
    private var currentInputData: InputData
    private var inputDataDisposable: Disposable?
    
    private let controllerInteraction: ChatControllerInteraction?
    
    private var inputNodeInteraction: ChatMediaInputNodeInteraction?
    
    private let trendingGifsPromise = Promise<ChatMediaInputGifPaneTrendingState?>(nil)
    
    private var isMarkInputCollapsed: Bool = false
    
    var externalTopPanelContainerImpl: PagerExternalTopPanelContainer?
    override var externalTopPanelContainer: UIView? {
        return self.externalTopPanelContainerImpl
    }
    
    var switchToTextInput: (() -> Void)?
    
    private var currentState: (width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, standardInputHeight: CGFloat, inputHeight: CGFloat, maximumHeight: CGFloat, inputPanelHeight: CGFloat, interfaceState: ChatPresentationInterfaceState, deviceMetrics: DeviceMetrics, isVisible: Bool, isExpanded: Bool)?
    
    private var gifMode: GifPagerContentComponent.Subject = .recent {
        didSet {
            if self.gifMode != oldValue {
                self.reloadGifContext()
            }
        }
    }
    
    var canSwitchToTextInputAutomatically: Bool {
        if let pagerView = self.entityKeyboardView.componentView as? EntityKeyboardComponent.View, let centralId = pagerView.centralId {
            if centralId == AnyHashable("emoji") {
                return false
            }
        }
        return true
    }
    
    private final class GifContext {
        private var componentValue: GifPagerContentComponent? {
            didSet {
                if let componentValue = self.componentValue {
                    self.componentResult.set(.single(componentValue))
                }
            }
        }
        private let componentPromise = Promise<GifPagerContentComponent>()
        
        private let componentResult = Promise<GifPagerContentComponent>()
        var component: Signal<GifPagerContentComponent, NoError> {
            return self.componentResult.get()
        }
        private var componentDisposable: Disposable?
        
        private let context: AccountContext
        private let subject: GifPagerContentComponent.Subject
        private let gifInputInteraction: GifPagerContentComponent.InputInteraction
        
        private var loadingMoreToken: String?
        
        init(context: AccountContext, subject: GifPagerContentComponent.Subject, gifInputInteraction: GifPagerContentComponent.InputInteraction, trendingGifs: Signal<ChatMediaInputGifPaneTrendingState?, NoError>) {
            self.context = context
            self.subject = subject
            self.gifInputInteraction = gifInputInteraction
            
            let gifItems: Signal<GifPagerContentComponent, NoError>
            switch subject {
            case .recent:
                gifItems = context.engine.data.subscribe(TelegramEngine.EngineData.Item.OrderedLists.ListItems(collectionId: Namespaces.OrderedItemList.CloudRecentGifs))
                |> map { savedGifs -> GifPagerContentComponent in
                    var items: [GifPagerContentComponent.Item] = []
                    for gifItem in savedGifs {
                        items.append(GifPagerContentComponent.Item(
                            file: gifItem.contents.get(RecentMediaItem.self)!.media
                        ))
                    }
                    return GifPagerContentComponent(
                        context: context,
                        inputInteraction: gifInputInteraction,
                        subject: subject,
                        items: items,
                        isLoading: false,
                        loadMoreToken: nil
                    )
                }
            case .trending:
                gifItems = trendingGifs
                |> map { trendingGifs -> GifPagerContentComponent in
                    var items: [GifPagerContentComponent.Item] = []
                    
                    var isLoading = false
                    if let trendingGifs = trendingGifs {
                        for file in trendingGifs.files {
                            items.append(GifPagerContentComponent.Item(
                                file: file.file.media
                            ))
                        }
                    } else {
                        isLoading = true
                    }
                    
                    return GifPagerContentComponent(
                        context: context,
                        inputInteraction: gifInputInteraction,
                        subject: subject,
                        items: items,
                        isLoading: isLoading,
                        loadMoreToken: nil
                    )
                }
            case let .emojiSearch(query):
                gifItems = paneGifSearchForQuery(context: context, query: query, offset: nil, incompleteResults: true, staleCachedResults: true, delayRequest: false, updateActivity: nil)
                |> map { result -> GifPagerContentComponent in
                    var items: [GifPagerContentComponent.Item] = []
                    
                    var loadMoreToken: String?
                    var isLoading = false
                    if let result = result {
                        for file in result.files {
                            items.append(GifPagerContentComponent.Item(
                                file: file.file.media
                            ))
                        }
                        loadMoreToken = result.nextOffset
                    } else {
                        isLoading = true
                    }
                    
                    return GifPagerContentComponent(
                        context: context,
                        inputInteraction: gifInputInteraction,
                        subject: subject,
                        items: items,
                        isLoading: isLoading,
                        loadMoreToken: loadMoreToken
                    )
                }
            }
            
            self.componentPromise.set(gifItems)
            self.componentDisposable = (self.componentPromise.get()
            |> deliverOnMainQueue).start(next: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.componentValue = result
            })
        }
        
        deinit {
            self.componentDisposable?.dispose()
        }
        
        func loadMore(token: String) {
            if self.loadingMoreToken == token {
                return
            }
            self.loadingMoreToken = token
            
            guard let componentValue = self.componentValue else {
                return
            }
            
            let context = self.context
            let subject = self.subject
            let gifInputInteraction = self.gifInputInteraction
            
            switch self.subject {
            case let .emojiSearch(query):
                let gifItems: Signal<GifPagerContentComponent, NoError>
                gifItems = paneGifSearchForQuery(context: context, query: query, offset: token, incompleteResults: true, staleCachedResults: true, delayRequest: false, updateActivity: nil)
                |> map { result -> GifPagerContentComponent in
                    var items: [GifPagerContentComponent.Item] = []
                    var existingIds = Set<MediaId>()
                    for item in componentValue.items {
                        items.append(item)
                        existingIds.insert(item.file.fileId)
                    }
                    
                    var loadMoreToken: String?
                    var isLoading = false
                    if let result = result {
                        for file in result.files {
                            if existingIds.contains(file.file.media.fileId) {
                                continue
                            }
                            existingIds.insert(file.file.media.fileId)
                            items.append(GifPagerContentComponent.Item(file: file.file.media))
                        }
                        if !result.isComplete {
                            loadMoreToken = result.nextOffset
                        }
                    } else {
                        isLoading = true
                    }
                    
                    return GifPagerContentComponent(
                        context: context,
                        inputInteraction: gifInputInteraction,
                        subject: subject,
                        items: items,
                        isLoading: isLoading,
                        loadMoreToken: loadMoreToken
                    )
                }
                
                self.componentPromise.set(gifItems)
            default:
                break
            }
        }
    }
    private var gifContext: GifContext? {
        didSet {
            if let gifContext = self.gifContext {
                self.gifComponent.set(gifContext.component)
            }
        }
    }
    private let gifComponent = Promise<GifPagerContentComponent>()
    private var gifInputInteraction: GifPagerContentComponent.InputInteraction?
    
    init(context: AccountContext, currentInputData: InputData, updatedInputData: Signal<InputData, NoError>, defaultToEmojiTab: Bool, controllerInteraction: ChatControllerInteraction?) {
        self.context = context
        self.currentInputData = currentInputData
        self.defaultToEmojiTab = defaultToEmojiTab
        
        self.controllerInteraction = controllerInteraction
        
        self.entityKeyboardView = ComponentHostView<Empty>()
        
        super.init()
        
        self.topBackgroundExtension = 41.0
        self.followsDefaultHeight = true
        
        self.view.addSubview(self.entityKeyboardView)
        
        self.externalTopPanelContainerImpl = PagerExternalTopPanelContainer()
        
        self.inputDataDisposable = (combineLatest(queue: .mainQueue(),
            updatedInputData,
            self.gifComponent.get()
        )
        |> deliverOnMainQueue).start(next: { [weak self] inputData, gifs in
            guard let strongSelf = self else {
                return
            }
            var inputData = inputData
            inputData.gifs = gifs
            
            strongSelf.currentInputData = inputData
            strongSelf.performLayout()
        })
        
        self.inputNodeInteraction = ChatMediaInputNodeInteraction(
            navigateToCollectionId: { _ in
            },
            navigateBackToStickers: {
            },
            setGifMode: { _ in
            },
            openSettings: {
            },
            openTrending: { _ in
            },
            dismissTrendingPacks: { _ in
            },
            toggleSearch: { _, _, _ in
            },
            openPeerSpecificSettings: {
            },
            dismissPeerSpecificSettings: {
            },
            clearRecentlyUsedStickers: {
            }
        )
        
        self.trendingGifsPromise.set(.single(nil))
        self.trendingGifsPromise.set(paneGifSearchForQuery(context: context, query: "", offset: nil, incompleteResults: true, delayRequest: false, updateActivity: nil)
        |> map { items -> ChatMediaInputGifPaneTrendingState? in
            if let items = items {
                return ChatMediaInputGifPaneTrendingState(files: items.files, nextOffset: items.nextOffset)
            } else {
                return nil
            }
        })
        
        self.gifInputInteraction = GifPagerContentComponent.InputInteraction(
            performItemAction: { [weak controllerInteraction] item, view, rect in
                guard let controllerInteraction = controllerInteraction else {
                    return
                }
                let _ = controllerInteraction.sendGif(.savedGif(media: item.file), view, rect, false, false)
            },
            openGifContextMenu: { [weak self] file, sourceView, sourceRect, gesture, isSaved in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.openGifContextMenu(file: file, sourceView: sourceView, sourceRect: sourceRect, gesture: gesture, isSaved: isSaved)
            },
            loadMore: { [weak self] token in
                guard let strongSelf = self, let gifContext = strongSelf.gifContext else {
                    return
                }
                gifContext.loadMore(token: token)
            }
        )
        
        self.switchToTextInput = { [weak self] in
            guard let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction else {
                return
            }
            controllerInteraction.updateInputMode { _ in
                return .text
            }
        }
        
        self.reloadGifContext()
    }
    
    deinit {
        self.inputDataDisposable?.dispose()
    }
    
    private func reloadGifContext() {
        if let gifInputInteraction = self.gifInputInteraction {
            self.gifContext = GifContext(context: self.context, subject: self.gifMode, gifInputInteraction: gifInputInteraction, trendingGifs: self.trendingGifsPromise.get())
        }
    }
    
    func markInputCollapsed() {
        self.isMarkInputCollapsed = true
    }
    
    private func performLayout() {
        guard let (width, leftInset, rightInset, bottomInset, standardInputHeight, inputHeight, maximumHeight, inputPanelHeight, interfaceState, deviceMetrics, isVisible, isExpanded) = self.currentState else {
            return
        }
        let _ = self.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, standardInputHeight: standardInputHeight, inputHeight: inputHeight, maximumHeight: maximumHeight, inputPanelHeight: inputPanelHeight, transition: .immediate, interfaceState: interfaceState, deviceMetrics: deviceMetrics, isVisible: isVisible, isExpanded: isExpanded)
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, standardInputHeight: CGFloat, inputHeight: CGFloat, maximumHeight: CGFloat, inputPanelHeight: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, deviceMetrics: DeviceMetrics, isVisible: Bool, isExpanded: Bool) -> (CGFloat, CGFloat) {
        self.currentState = (width, leftInset, rightInset, bottomInset, standardInputHeight, inputHeight, maximumHeight, inputPanelHeight, interfaceState, deviceMetrics, isVisible, isExpanded)
        
        let wasMarkedInputCollapsed = self.isMarkInputCollapsed
        self.isMarkInputCollapsed = false
        
        let expandedHeight = standardInputHeight
        
        var hiddenInputHeight: CGFloat = 0.0
        if self.hideInput && !self.adjustLayoutForHiddenInput {
            hiddenInputHeight = inputPanelHeight
        }
        
        let context = self.context
        let controllerInteraction = self.controllerInteraction
        let inputNodeInteraction = self.inputNodeInteraction!
        let trendingGifsPromise = self.trendingGifsPromise
        
        var mappedTransition = Transition(transition)
        
        if wasMarkedInputCollapsed || !isExpanded {
            mappedTransition = mappedTransition.withUserData(EntityKeyboardComponent.MarkInputCollapsed())
        }
        
        var stickerContent: EmojiPagerContentComponent? = self.currentInputData.stickers
        var gifContent: GifPagerContentComponent? = self.currentInputData.gifs
        
        var stickersEnabled = true
        if let peer = interfaceState.renderedPeer?.peer as? TelegramChannel {
            if peer.hasBannedPermission(.banSendStickers) != nil {
                stickersEnabled = false
            }
        } else if let peer = interfaceState.renderedPeer?.peer as? TelegramGroup {
            if peer.hasBannedPermission(.banSendStickers) {
                stickersEnabled = false
            }
        }
        
        if !stickersEnabled || interfaceState.interfaceState.editMessage != nil {
            stickerContent = nil
            gifContent = nil
        }
        
        if let gifContentValue = gifContent {
            if gifContentValue.items.isEmpty {
                gifContent = nil
            }
        }
        
        let entityKeyboardSize = self.entityKeyboardView.update(
            transition: mappedTransition,
            component: AnyComponent(EntityKeyboardComponent(
                theme: interfaceState.theme,
                bottomInset: bottomInset,
                emojiContent: self.currentInputData.emoji,
                stickerContent: stickerContent,
                gifContent: gifContent,
                availableGifSearchEmojies: self.currentInputData.availableGifSearchEmojies,
                defaultToEmojiTab: self.defaultToEmojiTab,
                externalTopPanelContainer: self.externalTopPanelContainerImpl,
                topPanelExtensionUpdated: { [weak self] topPanelExtension, transition in
                    guard let strongSelf = self else {
                        return
                    }
                    if strongSelf.topBackgroundExtension != topPanelExtension {
                        strongSelf.topBackgroundExtension = topPanelExtension
                        strongSelf.topBackgroundExtensionUpdated?(transition.containedViewLayoutTransition)
                    }
                },
                hideInputUpdated: { [weak self] hideInput, adjustLayout, transition in
                    guard let strongSelf = self else {
                        return
                    }
                    if strongSelf.hideInput != hideInput || strongSelf.adjustLayoutForHiddenInput != adjustLayout {
                        strongSelf.hideInput = hideInput
                        strongSelf.adjustLayoutForHiddenInput = adjustLayout
                        strongSelf.hideInputUpdated?(transition.containedViewLayoutTransition)
                    }
                },
                switchToTextInput: { [weak self] in
                    self?.switchToTextInput?()
                },
                switchToGifSubject: { [weak self] subject in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.gifMode = subject
                },
                makeSearchContainerNode: { [weak controllerInteraction] content in
                    guard let controllerInteraction = controllerInteraction else {
                        return nil
                    }

                    let mappedMode: ChatMediaInputSearchMode
                    switch content {
                    case .stickers:
                        mappedMode = .sticker
                    case .gifs:
                        mappedMode = .gif
                    }
                    
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    return PaneSearchContainerNode(
                        context: context,
                        theme: presentationData.theme,
                        strings: presentationData.strings,
                        controllerInteraction: controllerInteraction,
                        inputNodeInteraction: inputNodeInteraction,
                        mode: mappedMode,
                        trendingGifsPromise: trendingGifsPromise,
                        cancel: {
                        }
                    )
                },
                deviceMetrics: deviceMetrics,
                hiddenInputHeight: hiddenInputHeight,
                isExpanded: isExpanded
            )),
            environment: {},
            containerSize: CGSize(width: width, height: expandedHeight)
        )
        transition.updateFrame(view: self.entityKeyboardView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: entityKeyboardSize))
        
        return (expandedHeight, 0.0)
    }
    
    private func openGifContextMenu(file: TelegramMediaFile, sourceView: UIView, sourceRect: CGRect, gesture: ContextGesture, isSaved: Bool) {
        let canSaveGif: Bool
        if file.fileId.namespace == Namespaces.Media.CloudFile {
            canSaveGif = true
        } else {
            canSaveGif = false
        }
        
        let _ = (self.context.engine.stickers.isGifSaved(id: file.fileId)
        |> deliverOnMainQueue).start(next: { [weak self] isGifSaved in
            guard let strongSelf = self else {
                return
            }
            var isGifSaved = isGifSaved
            if !canSaveGif {
                isGifSaved = false
            }
            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
            
            let message = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: PeerId(0), namespace: Namespaces.Message.Local, id: 0), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: nil, text: "", attributes: [], media: [file], peers: SimpleDictionary(), associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:])
            
            let gallery = GalleryController(context: strongSelf.context, source: .standaloneMessage(message), streamSingleVideo: true, replaceRootController: { _, _ in
            }, baseNavigationController: nil)
            gallery.setHintWillBePresentedInPreviewingContext(true)
            
            var items: [ContextMenuItem] = []
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.MediaPicker_Send, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Resend"), color: theme.actionSheet.primaryTextColor)
            }, action: { _, f in
                f(.default)
                if isSaved {
                    let _ = self?.controllerInteraction?.sendGif(FileMediaReference.savedGif(media: file), sourceView, sourceRect, false, false)
                }/* else if let (collection, result) = file.contextResult {
                    let _ = self?.controllerInteraction.sendBotContextResultAsGif(collection, result, sourceNode, sourceRect, false)
                }*/
            })))
            
            /*if let (_, _, _, _, _, _, _, _, interfaceState, _, _, _) = strongSelf.validLayout {
                var isScheduledMessages = false
                if case .scheduledMessages = interfaceState.subject {
                    isScheduledMessages = true
                }
                if !isScheduledMessages {
                    if case let .peer(peerId) = interfaceState.chatLocation {
                        if peerId != self?.context.account.peerId && peerId.namespace != Namespaces.Peer.SecretChat  {
                            items.append(.action(ContextMenuActionItem(text: strongSelf.strings.Conversation_SendMessage_SendSilently, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Menu/SilentIcon"), color: theme.actionSheet.primaryTextColor)
                            }, action: { _, f in
                                f(.default)
                                if isSaved {
                                    let _ = self?.controllerInteraction.sendGif(file.file, sourceNode.view, sourceRect, true, false)
                                } else if let (collection, result) = file.contextResult {
                                    let _ = self?.controllerInteraction.sendBotContextResultAsGif(collection, result, sourceNode, sourceRect, true)
                                }
                            })))
                        }
                    
                        if isSaved {
                            items.append(.action(ContextMenuActionItem(text: strongSelf.strings.Conversation_SendMessage_ScheduleMessage, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Menu/ScheduleIcon"), color: theme.actionSheet.primaryTextColor)
                            }, action: { _, f in
                                f(.default)
                                
                                let _ = self?.controllerInteraction.sendGif(file.file, sourceNode.view, sourceRect, false, true)
                            })))
                        }
                    }
                }
            }*/
            
            if isSaved || isGifSaved {
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_ContextMenuDelete, textColor: .destructive, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.actionSheet.destructiveActionTextColor)
                }, action: { _, f in
                    f(.dismissWithoutContent)
                    
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = removeSavedGif(postbox: strongSelf.context.account.postbox, mediaId: file.fileId).start()
                })))
            } else if canSaveGif && !isGifSaved {
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.Preview_SaveGif, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Save"), color: theme.actionSheet.primaryTextColor)
                }, action: { _, f in
                    f(.dismissWithoutContent)
                    
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let context = strongSelf.context
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    let controllerInteraction = strongSelf.controllerInteraction
                    let _ = (toggleGifSaved(account: context.account, fileReference: FileMediaReference.savedGif(media: file), saved: true)
                    |> deliverOnMainQueue).start(next: { result in
                        switch result {
                            case .generic:
                                controllerInteraction?.presentController(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_gif", scale: 0.075, colors: [:], title: nil, text: presentationData.strings.Gallery_GifSaved), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
                            case let .limitExceeded(limit, premiumLimit):
                                let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
                                let text: String
                                if limit == premiumLimit || premiumConfiguration.isPremiumDisabled {
                                    text = presentationData.strings.Premium_MaxSavedGifsFinalText
                                } else {
                                    text = presentationData.strings.Premium_MaxSavedGifsText("\(premiumLimit)").string
                                }
                                controllerInteraction?.presentController(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_gif", scale: 0.075, colors: [:], title: presentationData.strings.Premium_MaxSavedGifsTitle("\(limit)").string, text: text), elevatedLayout: false, animateInAsReplacement: false, action: { action in
                                    if case .info = action {
                                        let controller = PremiumIntroScreen(context: context, source: .savedGifs)
                                        controllerInteraction?.navigationController()?.pushViewController(controller)
                                        return true
                                    }
                                    return false
                                }), nil)
                        }
                    })
                })))
            }
            
            let contextController = ContextController(account: strongSelf.context.account, presentationData: presentationData, source: .controller(ContextControllerContentSourceImpl(controller: gallery, sourceView: sourceView, sourceRect: sourceRect)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
            strongSelf.controllerInteraction?.presentGlobalOverlayController(contextController, nil)
        })
    }
}

private final class ContextControllerContentSourceImpl: ContextControllerContentSource {
    let controller: ViewController
    weak var sourceView: UIView?
    let sourceRect: CGRect
    
    let navigationController: NavigationController? = nil
    
    let passthroughTouches: Bool = false
    
    init(controller: ViewController, sourceView: UIView?, sourceRect: CGRect) {
        self.controller = controller
        self.sourceView = sourceView
        self.sourceRect = sourceRect
    }
    
    func transitionInfo() -> ContextControllerTakeControllerInfo? {
        let sourceView = self.sourceView
        let sourceRect = self.sourceRect
        return ContextControllerTakeControllerInfo(contentAreaInScreenSpace: CGRect(origin: CGPoint(), size: CGSize(width: 10.0, height: 10.0)), sourceNode: { [weak sourceView] in
            if let sourceView = sourceView {
                return (sourceView, sourceRect)
            } else {
                return nil
            }
        })
    }
    
    func animatedIn() {
        if let controller = self.controller as? GalleryController {
            controller.viewDidAppear(false)
        }
    }
}

final class EntityInputView: UIView, AttachmentTextInputPanelInputView, UIInputViewAudioFeedback {
    private let context: AccountContext
    
    public var insertText: ((NSAttributedString) -> Void)?
    public var deleteBackwards: (() -> Void)?
    public var switchToKeyboard: (() -> Void)?
    public var presentController: ((ViewController) -> Void)?
    
    private var presentationData: PresentationData
    private var inputNode: ChatEntityKeyboardInputNode?
    private let animationCache: AnimationCache
    private let animationRenderer: MultiAnimationRenderer
    
    init(
        context: AccountContext,
        isDark: Bool
    ) {
        self.context = context
        
        self.animationCache = AnimationCacheImpl(basePath: context.account.postbox.mediaBox.basePath + "/animation-cache", allocateTempFile: {
            return TempBox.shared.tempFile(fileName: "file").path
        })
        self.animationRenderer = MultiAnimationRendererImpl()
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        if isDark {
            self.presentationData = self.presentationData.withUpdated(theme: defaultDarkPresentationTheme)
        }
        
        //super.init(frame: CGRect(origin: CGPoint(), size: CGSize(width: 1.0, height: 1.0)), inputViewStyle: .default)
        super.init(frame: CGRect(origin: CGPoint(), size: CGSize(width: 1.0, height: 1.0)))
        
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.clipsToBounds = true
        
        let inputInteraction = EmojiPagerContentComponent.InputInteraction(
            performItemAction: { [weak self] item, _, _, _ in
                guard let strongSelf = self else {
                    return
                }
                let hasPremium = strongSelf.context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: strongSelf.context.account.peerId))
                |> map { peer -> Bool in
                    guard case let .user(user) = peer else {
                        return false
                    }
                    return user.isPremium
                }
                |> distinctUntilChanged
                
                let _ = (hasPremium |> take(1) |> deliverOnMainQueue).start(next: { hasPremium in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    if let file = item.file {
                        var text = "."
                        var emojiAttribute: ChatTextInputTextCustomEmojiAttribute?
                        loop: for attribute in file.attributes {
                            switch attribute {
                            case let .CustomEmoji(_, displayText, packReference):
                                text = displayText
                                emojiAttribute = ChatTextInputTextCustomEmojiAttribute(stickerPack: packReference, fileId: file.fileId.id, file: file)
                                break loop
                            default:
                                break
                            }
                        }
                        
                        if file.isPremiumEmoji && !hasPremium {
                            //TODO:localize
                            
                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                            strongSelf.presentController?(UndoOverlayController(presentationData: presentationData, content: .sticker(context: context, file: file, title: nil, text: "Subscribe to Telegram Premium to unlock this emoji.", undoText: "More", customAction: {
                                guard let strongSelf = self else {
                                    return
                                }
                                
                                var replaceImpl: ((ViewController) -> Void)?
                                let controller = PremiumDemoScreen(context: strongSelf.context, subject: .animatedEmoji, action: {
                                    let controller = PremiumIntroScreen(context: strongSelf.context, source: .stickers)
                                    replaceImpl?(controller)
                                })
                                replaceImpl = { [weak controller] c in
                                    controller?.replace(with: c)
                                }
                                strongSelf.presentController?(controller)
                            }), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }))
                            return
                        }
                        
                        if let emojiAttribute = emojiAttribute {
                            AudioServicesPlaySystemSound(0x450)
                            strongSelf.insertText?(NSAttributedString(string: text, attributes: [ChatTextInputAttributes.customEmoji: emojiAttribute]))
                        }
                    } else if let staticEmoji = item.staticEmoji {
                        AudioServicesPlaySystemSound(0x450)
                        strongSelf.insertText?(NSAttributedString(string: staticEmoji, attributes: [:]))
                    }
                })
            },
            deleteBackwards: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.deleteBackwards?()
            },
            openStickerSettings: {
            },
            addGroupAction: { _, _ in
            },
            clearGroup: { _ in
            },
            pushController: { _ in
            },
            presentController: { _ in
            },
            presentGlobalOverlayController: { _ in
            },
            navigationController: {
                return nil
            },
            sendSticker: nil,
            chatPeerId: nil
        )
        
        let semaphore = DispatchSemaphore(value: 0)
        var emojiComponent: EmojiPagerContentComponent?
        let _ = ChatEntityKeyboardInputNode.emojiInputData(context: context, inputInteraction: inputInteraction, animationCache: self.animationCache, animationRenderer: self.animationRenderer).start(next: { value in
            emojiComponent = value
            semaphore.signal()
        })
        semaphore.wait()
        
        if let emojiComponent = emojiComponent {
            let inputNode = ChatEntityKeyboardInputNode(
                context: self.context,
                currentInputData: ChatEntityKeyboardInputNode.InputData(
                    emoji: emojiComponent,
                    stickers: nil,
                    gifs: nil,
                    availableGifSearchEmojies: []
                ),
                updatedInputData: .never(),
                defaultToEmojiTab: true,
                controllerInteraction: nil
            )
            self.inputNode = inputNode
            inputNode.externalTopPanelContainerImpl = nil
            inputNode.switchToTextInput = { [weak self] in
                self?.switchToKeyboard?()
            }
            self.addSubnode(inputNode)
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        guard let inputNode = self.inputNode else {
            return
        }
        
        for view in self.subviews {
            if view !== inputNode.view {
                view.isHidden = true
            }
        }
        
        let bottomInset: CGFloat
        if #available(iOS 11.0, *) {
            bottomInset = max(0.0, UIScreen.main.bounds.height - (self.window?.safeAreaLayoutGuide.layoutFrame.maxY ?? 10000.0))
        } else {
            bottomInset = 0.0
        }
            
        let presentationInterfaceState = ChatPresentationInterfaceState(
            chatWallpaper: .builtin(WallpaperSettings()),
            theme: self.presentationData.theme,
            strings: self.presentationData.strings,
            dateTimeFormat: self.presentationData.dateTimeFormat,
            nameDisplayOrder: self.presentationData.nameDisplayOrder,
            limitsConfiguration: self.context.currentLimitsConfiguration.with { $0 },
            fontSize: self.presentationData.chatFontSize,
            bubbleCorners: self.presentationData.chatBubbleCorners,
            accountPeerId: self.context.account.peerId,
            mode: .standard(previewing: false),
            chatLocation: .peer(id: self.context.account.peerId),
            subject: nil,
            peerNearbyData: nil,
            greetingData: nil,
            pendingUnpinnedAllMessages: false,
            activeGroupCallInfo: nil,
            hasActiveGroupCall: false,
            importState: nil
        )

        let _ = inputNode.updateLayout(
            width: self.bounds.width,
            leftInset: 0.0,
            rightInset: 0.0,
            bottomInset: bottomInset,
            standardInputHeight: self.bounds.height,
            inputHeight: self.bounds.height,
            maximumHeight: self.bounds.height,
            inputPanelHeight: 0.0,
            transition: .immediate,
            interfaceState: presentationInterfaceState,
            deviceMetrics: DeviceMetrics.iPhone12,
            isVisible: true,
            isExpanded: false
        )
        inputNode.frame = self.bounds
    }
}
