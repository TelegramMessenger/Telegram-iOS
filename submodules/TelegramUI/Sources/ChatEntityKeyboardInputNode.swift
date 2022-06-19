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

final class ChatEntityKeyboardInputNode: ChatInputNode {
    struct InputData: Equatable {
        let emoji: EmojiPagerContentComponent
        let stickers: EmojiPagerContentComponent
        
        init(
            emoji: EmojiPagerContentComponent,
            stickers: EmojiPagerContentComponent
        ) {
            self.emoji = emoji
            self.stickers = stickers
        }
    }
    
    static func inputData(context: AccountContext, interfaceInteraction: ChatPanelInterfaceInteraction) -> Signal<InputData, NoError> {
        let emojiInputInteraction = EmojiPagerContentComponent.InputInteraction(
            performItemAction: { [weak interfaceInteraction] item, _, _ in
                guard let interfaceInteraction = interfaceInteraction else {
                    return
                }
                interfaceInteraction.insertText(item.emoji)
            },
            deleteBackwards: { [weak interfaceInteraction] in
                guard let interfaceInteraction = interfaceInteraction else {
                    return
                }
                interfaceInteraction.backwardsDeleteText()
            }
        )
        let stickerInputInteraction = EmojiPagerContentComponent.InputInteraction(
            performItemAction: { [weak interfaceInteraction] item, view, rect in
                guard let interfaceInteraction = interfaceInteraction else {
                    return
                }
                let _ = interfaceInteraction.sendSticker(.standalone(media: item.file), false, view, rect)
            },
            deleteBackwards: { [weak interfaceInteraction] in
                guard let interfaceInteraction = interfaceInteraction else {
                    return
                }
                interfaceInteraction.backwardsDeleteText()
            }
        )
        
        let animationCache = AnimationCacheImpl(basePath: context.account.postbox.mediaBox.basePath + "/animation-cache", allocateTempFile: {
            return TempBox.shared.tempFile(fileName: "file").path
        })
        let animationRenderer = MultiAnimationRendererImpl()
        
        let emojiItems: Signal<EmojiPagerContentComponent, NoError> = context.engine.stickers.loadedStickerPack(reference: .animatedEmoji, forceActualized: false)
        |> map { animatedEmoji -> EmojiPagerContentComponent in
            var emojiItems: [EmojiPagerContentComponent.Item] = []
            
            switch animatedEmoji {
            case let .result(_, items, _):
                for item in items {
                    if let emoji = item.getStringRepresentationsOfIndexKeys().first {
                        let strippedEmoji = emoji.basicEmoji.0.strippedEmoji
                        emojiItems.append(EmojiPagerContentComponent.Item(
                            emoji: strippedEmoji,
                            file: item.file
                        ))
                    }
                }
            default:
                break
            }
            
            var itemGroups: [EmojiPagerContentComponent.ItemGroup] = []
            itemGroups.append(EmojiPagerContentComponent.ItemGroup(
                id: "all",
                title: nil,
                items: emojiItems
            ))
            return EmojiPagerContentComponent(
                context: context,
                animationCache: animationCache,
                animationRenderer: animationRenderer,
                inputInteraction: emojiInputInteraction,
                itemGroups: itemGroups,
                itemLayoutType: .compact
            )
        }
        
        let orderedItemListCollectionIds: [Int32] = [Namespaces.OrderedItemList.CloudSavedStickers]
        let namespaces: [ItemCollectionId.Namespace] = [Namespaces.ItemCollection.CloudStickerPacks]
        let stickerItems: Signal<EmojiPagerContentComponent, NoError> = context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: orderedItemListCollectionIds, namespaces: namespaces, aroundIndex: nil, count: 10000000)
        |> map { view -> EmojiPagerContentComponent in
            struct ItemGroup {
                var id: ItemCollectionId
                var items: [EmojiPagerContentComponent.Item]
            }
            var itemGroups: [ItemGroup] = []
            var itemGroupIndexById: [AnyHashable: Int] = [:]
            
            for entry in view.entries {
                guard let item = entry.item as? StickerPackItem else {
                    continue
                }
                if !item.file.isAnimatedSticker {
                    continue
                }
                let resultItem = EmojiPagerContentComponent.Item(
                    emoji: "",
                    file: item.file
                )
                let groupId = entry.index.collectionId
                if let groupIndex = itemGroupIndexById[groupId] {
                    itemGroups[groupIndex].items.append(resultItem)
                } else {
                    itemGroupIndexById[groupId] = itemGroups.count
                    itemGroups.append(ItemGroup(id: groupId, items: [resultItem]))
                }
            }
            
            return EmojiPagerContentComponent(
                context: context,
                animationCache: animationCache,
                animationRenderer: animationRenderer,
                inputInteraction: stickerInputInteraction,
                itemGroups: itemGroups.map { group -> EmojiPagerContentComponent.ItemGroup in
                    var title: String?
                    for (id, info, _) in view.collectionInfos {
                        if id == group.id, let info = info as? StickerPackCollectionInfo {
                            title = info.title.uppercased()
                            break
                        }
                    }
                    
                    return EmojiPagerContentComponent.ItemGroup(id: group.id, title: title, items: group.items)
                },
                itemLayoutType: .detailed
            )
        }
        
        return combineLatest(queue: .mainQueue(),
            emojiItems,
            stickerItems
        )
        |> map { emoji, stickers -> InputData in
            return InputData(
                emoji: emoji,
                stickers: stickers
            )
        }
    }
    
    private let entityKeyboardView: ComponentHostView<Empty>
    
    private var currentInputData: InputData
    private var inputDataDisposable: Disposable?
    
    init(context: AccountContext, currentInputData: InputData, updatedInputData: Signal<InputData, NoError>) {
        self.currentInputData = currentInputData
        self.entityKeyboardView = ComponentHostView<Empty>()
        
        super.init()
        
        self.view.addSubview(self.entityKeyboardView)
        
        self.externalTopPanelContainer = SparseContainerView()
        
        self.inputDataDisposable = (updatedInputData
        |> deliverOnMainQueue).start(next: { [weak self] inputData in
            guard let strongSelf = self else {
                return
            }
            strongSelf.currentInputData = inputData
        })
    }
    
    deinit {
        self.inputDataDisposable?.dispose()
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, standardInputHeight: CGFloat, inputHeight: CGFloat, maximumHeight: CGFloat, inputPanelHeight: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, deviceMetrics: DeviceMetrics, isVisible: Bool) -> (CGFloat, CGFloat) {
        let entityKeyboardSize = self.entityKeyboardView.update(
            transition: Transition(transition),
            component: AnyComponent(EntityKeyboardComponent(
                theme: interfaceState.theme,
                bottomInset: bottomInset,
                emojiContent: self.currentInputData.emoji,
                stickerContent: self.currentInputData.stickers,
                externalTopPanelContainer: self.externalTopPanelContainer,
                topPanelExtensionUpdated: { [weak self] topPanelExtension, transition in
                    guard let strongSelf = self else {
                        return
                    }
                    if strongSelf.topBackgroundExtension != topPanelExtension {
                        strongSelf.topBackgroundExtension = topPanelExtension
                        strongSelf.topBackgroundExtensionUpdated?(transition.containedViewLayoutTransition)
                    }
                }
            )),
            environment: {},
            containerSize: CGSize(width: width, height: standardInputHeight)
        )
        transition.updateFrame(view: self.entityKeyboardView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: entityKeyboardSize))
        
        return (standardInputHeight, 0.0)
    }
}
