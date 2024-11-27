import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import UndoUI
import EntityKeyboard
import PremiumUI
import PeerNameColorItem

private final class PeerNameColorScreenArguments {
    let context: AccountContext
    let updateNameColor: (PeerNameColor?) -> Void
    let updateBackgroundEmojiId: (Int64?, TelegramMediaFile?) -> Void
    let resetColor: () -> Void
    
    init(
        context: AccountContext,
        updateNameColor: @escaping (PeerNameColor?) -> Void,
        updateBackgroundEmojiId: @escaping (Int64?, TelegramMediaFile?) -> Void,
        resetColor: @escaping () -> Void
    ) {
        self.context = context
        self.updateNameColor = updateNameColor
        self.updateBackgroundEmojiId = updateBackgroundEmojiId
        self.resetColor = resetColor
    }
}

private enum PeerNameColorScreenSection: Int32 {
    case nameColor
    case backgroundEmoji
}

private enum PeerNameColorScreenEntry: ItemListNodeEntry {
    enum StableId: Hashable {
        case colorHeader
        case colorMessage
        case colorProfile
        case colorPicker
        case removeColor
        case colorDescription
        case backgroundEmojiHeader
        case backgroundEmoji
    }
    
    case colorHeader(String)
    case colorMessage(wallpaper: TelegramWallpaper, fontSize: PresentationFontSize, bubbleCorners: PresentationChatBubbleCorners, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, items: [PeerNameColorChatPreviewItem.MessageItem])
    case colorProfile(peer: EnginePeer?, files: [Int64: TelegramMediaFile], nameDisplayOrder: PresentationPersonNameOrder)
    case colorPicker(colors: PeerNameColors, currentColor: PeerNameColor?, isProfile: Bool)
    case removeColor
    case colorDescription(String)
    case backgroundEmojiHeader(String, String?)
    case backgroundEmoji(EmojiPagerContentComponent, UIColor, Bool, Bool)
    
    var section: ItemListSectionId {
        switch self {
        case .colorHeader, .colorMessage, .colorProfile, .colorPicker, .removeColor, .colorDescription:
            return PeerNameColorScreenSection.nameColor.rawValue
        case .backgroundEmojiHeader, .backgroundEmoji:
            return PeerNameColorScreenSection.backgroundEmoji.rawValue
        }
    }
    
    var stableId: StableId {
        switch self {
        case .colorHeader:
            return .colorHeader
        case .colorMessage:
            return .colorMessage
        case .colorProfile:
            return .colorProfile
        case .colorPicker:
            return .colorPicker
        case .removeColor:
            return.removeColor
        case .colorDescription:
            return .colorDescription
        case .backgroundEmojiHeader:
            return .backgroundEmojiHeader
        case .backgroundEmoji:
            return .backgroundEmoji
        }
    }
    
    var sortId: Int {
        switch self {
        case .colorHeader:
            return 0
        case .colorMessage:
            return 1
        case .colorProfile:
            return 2
        case .colorPicker:
            return 3
        case .removeColor:
            return 4
        case .colorDescription:
            return 5
        case .backgroundEmojiHeader:
            return 6
        case .backgroundEmoji:
            return 7
        }
    }
    
    static func ==(lhs: PeerNameColorScreenEntry, rhs: PeerNameColorScreenEntry) -> Bool {
        switch lhs {
        case let .colorHeader(text):
            if case .colorHeader(text) = rhs {
                return true
            } else {
                return false
            }
        case let .colorMessage(lhsWallpaper, lhsFontSize, lhsBubbleCorners, lhsDateTimeFormat, lhsNameDisplayOrder, lhsItems):
            if case let .colorMessage(rhsWallpaper, rhsFontSize, rhsBubbleCorners, rhsDateTimeFormat, rhsNameDisplayOrder, rhsItems) = rhs, lhsWallpaper == rhsWallpaper, lhsFontSize == rhsFontSize, lhsBubbleCorners == rhsBubbleCorners, lhsDateTimeFormat == rhsDateTimeFormat, lhsNameDisplayOrder == rhsNameDisplayOrder, lhsItems == rhsItems {
                return true
            } else {
                return false
            }
        case let .colorProfile(lhsPeer, lhsFiles, lhsNameDisplayOrder):
            if case let .colorProfile(rhsPeer, rhsFiles, rhsNameDisplayOrder) = rhs {
                if lhsPeer != rhsPeer {
                    return false
                }
                if lhsFiles != rhsFiles {
                    return false
                }
                if lhsNameDisplayOrder != rhsNameDisplayOrder {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .colorPicker(lhsColors, lhsCurrentColor, lhsIsProfile):
            if case let .colorPicker(rhsColors, rhsCurrentColor, rhsIsProfile) = rhs, lhsColors == rhsColors, lhsCurrentColor == rhsCurrentColor, lhsIsProfile == rhsIsProfile {
                return true
            } else {
                return false
            }
        case .removeColor:
            if case .removeColor = rhs {
                return true
            } else {
                return false
            }
        case let .colorDescription(text):
            if case .colorDescription(text) = rhs {
                return true
            } else {
                return false
            }
        case let .backgroundEmojiHeader(text, action):
            if case .backgroundEmojiHeader(text, action) = rhs {
                return true
            } else {
                return false
            }
        case let .backgroundEmoji(lhsEmojiContent, lhsBackgroundIconColor, lhsIsProfile, lhsHasRemoveButton):
            if case let .backgroundEmoji(rhsEmojiContent, rhsBackgroundIconColor, rhsIsProfile, rhsHasRemoveButton) = rhs, lhsEmojiContent == rhsEmojiContent, lhsBackgroundIconColor == rhsBackgroundIconColor, lhsIsProfile == rhsIsProfile, lhsHasRemoveButton == rhsHasRemoveButton {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: PeerNameColorScreenEntry, rhs: PeerNameColorScreenEntry) -> Bool {
        return lhs.sortId < rhs.sortId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! PeerNameColorScreenArguments
        switch self {
        case let .colorHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .colorMessage(wallpaper, fontSize, chatBubbleCorners, dateTimeFormat, nameDisplayOrder, items):
            return PeerNameColorChatPreviewItem(
                context: arguments.context,
                theme: presentationData.theme,
                componentTheme: presentationData.theme,
                strings: presentationData.strings,
                sectionId: self.section,
                fontSize: fontSize,
                chatBubbleCorners: chatBubbleCorners,
                wallpaper: wallpaper,
                dateTimeFormat: dateTimeFormat,
                nameDisplayOrder: nameDisplayOrder,
                messageItems: items
            )
        case let .colorProfile(peer, files, nameDisplayOrder):
            return PeerNameColorProfilePreviewItem(
                context: arguments.context,
                theme: presentationData.theme,
                componentTheme: presentationData.theme,
                strings: presentationData.strings,
                topInset: 0.0,
                sectionId: self.section,
                peer: peer,
                files: files,
                nameDisplayOrder: nameDisplayOrder
            )
        case let .colorPicker(colors, currentColor, isProfile):
            return PeerNameColorItem(
                theme: presentationData.theme,
                colors: colors,
                mode: isProfile ? .profile : .name,
                currentColor: currentColor,
                updated: { color in
                    if let color {
                        arguments.updateNameColor(color)
                    }
                },
                sectionId: self.section
            )
        case .removeColor:
            return ItemListActionItem(presentationData: presentationData, title: presentationData.strings.ProfileColorSetup_ResetAction, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.resetColor()
            })
        case let .colorDescription(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .backgroundEmojiHeader(text, action):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, actionText: action, action: action != nil ? {
                arguments.updateBackgroundEmojiId(0, nil)
            } : nil, sectionId: self.section)
        case let .backgroundEmoji(emojiContent, backgroundIconColor, isProfileColor, hasRemoveButton):
            return EmojiPickerItem(context: arguments.context, theme: presentationData.theme, strings: presentationData.strings, emojiContent: emojiContent, backgroundIconColor: backgroundIconColor, isProfileColor: isProfileColor, hasRemoveButton: hasRemoveButton, sectionId: self.section)
        }
    }
}

private struct PeerNameColorScreenState: Equatable {
    var updatedNameColor: PeerNameColor?
    var updatedBackgroundEmojiId: Int64?
    var inProgress: Bool = false
    var needsBoosts: Bool = false
    
    var updatedProfileColor: PeerNameColor?
    var hasUpdatedProfileColor: Bool = false
    var updatedProfileBackgroundEmojiId: Int64?
    var hasUpdatedProfileBackgroundEmojiId: Bool = false
    
    var selectedTabIndex: Int = 0
    
    var files: [Int64: TelegramMediaFile] = [:]
}

private func peerNameColorScreenEntries(
    nameColors: PeerNameColors,
    presentationData: PresentationData,
    state: PeerNameColorScreenState,
    peer: EnginePeer?,
    isPremium: Bool,
    emojiContent: EmojiPagerContentComponent?
) -> [PeerNameColorScreenEntry] {
    var entries: [PeerNameColorScreenEntry] = []
    
    if let peer {
        let nameColor: PeerNameColor
        if let updatedNameColor = state.updatedNameColor {
            nameColor = updatedNameColor
        } else if let peerNameColor = peer.nameColor {
            nameColor = peerNameColor
        } else {
            nameColor = .blue
        }
        
        let colors = nameColors.get(nameColor, dark: presentationData.theme.overallDarkAppearance)
        
        let backgroundEmojiId: Int64?
        if let updatedBackgroundEmojiId = state.updatedBackgroundEmojiId {
            if updatedBackgroundEmojiId == 0 {
                backgroundEmojiId = nil
            } else {
                backgroundEmojiId = updatedBackgroundEmojiId
            }
        } else if let emojiId = peer.backgroundEmojiId {
            backgroundEmojiId = emojiId
        } else {
            backgroundEmojiId = nil
        }
        
        let profileColor: PeerNameColor?
        if state.hasUpdatedProfileColor {
            profileColor = state.updatedProfileColor
        } else {
            profileColor = peer.profileColor
        }
        var selectedProfileEmojiId: Int64?
        if state.hasUpdatedProfileBackgroundEmojiId {
            selectedProfileEmojiId = state.updatedProfileBackgroundEmojiId
        } else {
            selectedProfileEmojiId = peer.profileBackgroundEmojiId
        }
        let profileColors = profileColor.flatMap { profileColor in nameColors.getProfile(profileColor, dark: presentationData.theme.overallDarkAppearance) }
        
        let replyText: String
        let messageText: String
        if case .channel = peer {
            replyText = presentationData.strings.NameColor_ChatPreview_ReplyText_Channel
            messageText = presentationData.strings.NameColor_ChatPreview_MessageText_Channel
        } else {
            replyText = presentationData.strings.NameColor_ChatPreview_ReplyText_Account
            messageText = presentationData.strings.NameColor_ChatPreview_MessageText_Account
        }
        let messageItem = PeerNameColorChatPreviewItem.MessageItem(
            outgoing: false,
            peerId: PeerId(namespace: peer.id.namespace, id: PeerId.Id._internalFromInt64Value(0)),
            author: peer.compactDisplayTitle,
            photo: peer.profileImageRepresentations,
            nameColor: nameColor,
            backgroundEmojiId: backgroundEmojiId,
            reply: (peer.compactDisplayTitle, replyText, nameColor),
            linkPreview: (presentationData.strings.NameColor_ChatPreview_LinkSite, presentationData.strings.NameColor_ChatPreview_LinkTitle, presentationData.strings.NameColor_ChatPreview_LinkText),
            text: messageText
        )
        if state.selectedTabIndex == 0 {
            entries.append(.colorMessage(
                wallpaper: presentationData.chatWallpaper,
                fontSize: presentationData.chatFontSize,
                bubbleCorners: presentationData.chatBubbleCorners,
                dateTimeFormat: presentationData.dateTimeFormat,
                nameDisplayOrder: presentationData.nameDisplayOrder,
                items: [messageItem]
            ))
        } else {
            var updatedPeer = peer
            switch updatedPeer {
            case let .user(user):
                updatedPeer = .user(user.withUpdatedNameColor(nameColor).withUpdatedBackgroundEmojiId(backgroundEmojiId).withUpdatedProfileColor(profileColor).withUpdatedProfileBackgroundEmojiId(selectedProfileEmojiId))
            case let .channel(channel):
                updatedPeer = .channel(channel.withUpdatedNameColor(nameColor).withUpdatedBackgroundEmojiId(backgroundEmojiId).withUpdatedProfileColor(profileColor).withUpdatedProfileBackgroundEmojiId(selectedProfileEmojiId))
            default:
                break
            }
            var files: [Int64: TelegramMediaFile] = [:]
            if let fileId = updatedPeer.profileBackgroundEmojiId, let file = state.files[fileId] {
                files[fileId] = file
            }
            entries.append(.colorProfile(
                peer: updatedPeer,
                files: files,
                nameDisplayOrder: presentationData.nameDisplayOrder
            ))
        }
        if state.selectedTabIndex == 0 {
            entries.append(.colorPicker(
                colors: nameColors,
                currentColor: nameColor,
                isProfile: false
            ))
        } else {
            entries.append(.colorPicker(
                colors: nameColors,
                currentColor: profileColor,
                isProfile: true
            ))
        }
        if state.selectedTabIndex == 1 && profileColor != nil {
            entries.append(.removeColor)
        }
        
        if state.selectedTabIndex == 0 {
            if case .channel = peer {
                entries.append(.colorDescription(presentationData.strings.NameColor_ChatPreview_Description_Channel))
            } else {
                entries.append(.colorDescription(presentationData.strings.NameColor_ChatPreview_Description_Account))
            }
            
            if let emojiContent {
                var selectedItems = Set<MediaId>()
                if let backgroundEmojiId {
                    selectedItems.insert(MediaId(namespace: Namespaces.Media.CloudFile, id: backgroundEmojiId))
                }
                let emojiContent = emojiContent.withSelectedItems(selectedItems).withCustomTintColor(colors.main)
                
                entries.append(.backgroundEmojiHeader(presentationData.strings.NameColor_BackgroundEmoji_Title, (backgroundEmojiId != nil && backgroundEmojiId != 0) ? presentationData.strings.NameColor_BackgroundEmoji_Remove : nil))
                entries.append(.backgroundEmoji(emojiContent, colors.main, false, false))
            }
        } else {
            if let emojiContent {
                var selectedItems = Set<MediaId>()
                if let selectedProfileEmojiId {
                    selectedItems.insert(MediaId(namespace: Namespaces.Media.CloudFile, id: selectedProfileEmojiId))
                }
                let emojiContent = emojiContent.withSelectedItems(selectedItems).withCustomTintColor(profileColors?.main ?? presentationData.theme.list.itemSecondaryTextColor)
                
                entries.append(.backgroundEmojiHeader(presentationData.strings.ProfileColorSetup_IconSectionTitle, (selectedProfileEmojiId != nil && selectedProfileEmojiId != 0) ? presentationData.strings.NameColor_BackgroundEmoji_Remove : nil))
                entries.append(.backgroundEmoji(emojiContent, profileColors?.main ?? presentationData.theme.list.itemSecondaryTextColor, true, profileColor != nil))
            } else {
                if case .channel = peer {
                    entries.append(.colorDescription(presentationData.strings.ProfileColorSetup_ChannelColorInfoLabel))
                } else {
                    entries.append(.colorDescription(presentationData.strings.ProfileColorSetup_AccountColorInfoLabel))
                }
            }
        }
    }
    
    return entries
}

public enum PeerNameColorScreenSubject {
    case account
    case channel(EnginePeer.Id)
}

public func PeerNameColorScreen(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
    subject: PeerNameColorScreenSubject
) -> ViewController {
    let statePromise = ValuePromise(PeerNameColorScreenState(), ignoreRepeated: true)
    let stateValue = Atomic(value: PeerNameColorScreenState())
    let updateState: ((PeerNameColorScreenState) -> PeerNameColorScreenState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
    
    var presentImpl: ((ViewController) -> Void)?
    var pushImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    var attemptNavigationImpl: ((@escaping () -> Void) -> Bool)?
    var applyChangesImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let arguments = PeerNameColorScreenArguments(
        context: context,
        updateNameColor: { color in
            updateState { state in
                var updatedState = state
                
                if state.selectedTabIndex == 0 {
                    if let color {
                        updatedState.updatedNameColor = color
                    }
                } else {
                    updatedState.updatedProfileColor = color
                    updatedState.hasUpdatedProfileColor = true
                }
                return updatedState
            }
        },
        updateBackgroundEmojiId: { emojiId, file in
            updateState { state in
                var updatedState = state
                if state.selectedTabIndex == 0 {
                    updatedState.updatedBackgroundEmojiId = emojiId
                } else {
                    updatedState.hasUpdatedProfileBackgroundEmojiId = true
                    updatedState.updatedProfileBackgroundEmojiId = emojiId
                }
                if let file {
                    updatedState.files[file.fileId.id] = file
                }
                return updatedState
            }
        },
        resetColor: {
            updateState { state in
                var updatedState = state
                
                if state.selectedTabIndex == 1 {
                    updatedState.updatedProfileColor = nil
                    updatedState.hasUpdatedProfileColor = true
                    updatedState.updatedProfileBackgroundEmojiId = nil
                    updatedState.hasUpdatedProfileBackgroundEmojiId = true
                }
                return updatedState
            }
        }
    )
    
    let peerId: EnginePeer.Id
    switch subject {
    case .account:
        peerId = context.account.peerId
    case let .channel(channelId):
        peerId = channelId
    }
    
    let emojiContent = EmojiPagerContentComponent.emojiInputData(
        context: context,
        animationCache: context.animationCache,
        animationRenderer: context.animationRenderer,
        isStandalone: false,
        subject: .backgroundIcon,
        hasTrending: false,
        topReactionItems: [],
        areUnicodeEmojiEnabled: false,
        areCustomEmojiEnabled: true,
        chatPeerId: context.account.peerId,
        selectedItems: Set(),
        backgroundIconColor: nil
    )
    /*let emojiContent: Signal<EmojiPagerContentComponent, NoError> = combineLatest(
        context.sharedContext.presentationData
    )
    |> mapToSignal { presentationData, state, peer -> Signal<(EmojiPagerContentComponent, EmojiPagerContentComponent), NoError> in
        var selectedEmojiId: Int64?
        if let updatedBackgroundEmojiId = state.updatedBackgroundEmojiId {
            selectedEmojiId = updatedBackgroundEmojiId
        } else {
            selectedEmojiId = peer?.backgroundEmojiId
        }
        let nameColor: PeerNameColor
        if let updatedNameColor = state.updatedNameColor {
            nameColor = updatedNameColor
        } else {
            nameColor = (peer?.nameColor ?? .blue)
        }
        
        var selectedProfileEmojiId: Int64?
        if state.hasUpdatedProfileBackgroundEmojiId {
            selectedProfileEmojiId = state.updatedProfileBackgroundEmojiId
        } else {
            selectedProfileEmojiId = peer?.profileBackgroundEmojiId
        }
        let profileColor: PeerNameColor?
        if state.hasUpdatedProfileColor {
            profileColor = state.updatedProfileColor
        } else {
            profileColor = peer?.profileColor
        }
        
        let color = context.peerNameColors.get(nameColor, dark: presentationData.theme.overallDarkAppearance)
        let profileColorValue: UIColor? = profileColor.flatMap { profileColor in context.peerNameColors.getProfile(profileColor, dark: presentationData.theme.overallDarkAppearance).main }
        
        let selectedItems: [EngineMedia.Id]
        if let selectedEmojiId, selectedEmojiId != 0 {
            selectedItems = [EngineMedia.Id(namespace: Namespaces.Media.CloudFile, id: selectedEmojiId)]
        } else {
            selectedItems = []
        }
        
        let selectedProfileItems: [EngineMedia.Id]
        if let selectedProfileEmojiId, selectedProfileEmojiId != 0 {
            selectedProfileItems = [EngineMedia.Id(namespace: Namespaces.Media.CloudFile, id: selectedProfileEmojiId)]
        } else {
            selectedProfileItems = []
        }
    }*/
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(queue: .mainQueue(),
        presentationData,
        statePromise.get(),
        context.engine.stickers.availableReactions(),
        context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)),
        emojiContent
    )
    |> deliverOnMainQueue
    |> map { presentationData, state, availableReactions, peer, emojiContent -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let isPremium = peer?.isPremium ?? false
        let buttonTitle: String
        let isLocked: Bool
        switch subject {
        case .account:
            isLocked = !isPremium
        case .channel:
            isLocked = false
        }
        let _ = isLocked
        
        let backgroundEmojiId: Int64
        if let updatedBackgroundEmojiId = state.updatedBackgroundEmojiId {
            backgroundEmojiId = updatedBackgroundEmojiId
        } else if let emojiId = peer?.backgroundEmojiId {
            backgroundEmojiId = emojiId
        } else {
            backgroundEmojiId = 0
        }
        if backgroundEmojiId != 0 {
            buttonTitle = presentationData.strings.NameColor_ApplyColorAndBackgroundEmoji
        } else {
            buttonTitle = presentationData.strings.NameColor_ApplyColor
        }
        let _ = buttonTitle
        
        /*let footerItem = ApplyColorFooterItem(
            theme: presentationData.theme,
            title: buttonTitle,
            locked: isLocked,
            inProgress: state.inProgress,
            action: {
                if !isLocked {
                    applyChangesImpl?()
                } else {
                    HapticFeedback().impact(.light)
                    let controller = UndoOverlayController(
                        presentationData: presentationData,
                        content: .premiumPaywall(
                            title: nil,
                            text: presentationData.strings.NameColor_TooltipPremium_Account,
                            customUndoText: nil,
                            timeout: nil,
                            linkAction: nil
                        ),
                        elevatedLayout: false,
                        action: { action in
                            if case .info = action {
                                let controller = context.sharedContext.makePremiumIntroController(context: context, source: .nameColor, forceDark: false, dismissed: nil)
                                pushImpl?(controller)
                            }
                            return true
                        }
                    )
                    presentImpl?(controller)
                }
            }
        )*/
    
        emojiContent.inputInteractionHolder.inputInteraction = EmojiPagerContentComponent.InputInteraction(
            performItemAction: { _, item, _, _, _, _ in
                var selectedFileId: Int64?
                var selectedFile: TelegramMediaFile?
                if let fileId = item.itemFile?.fileId.id {
                    selectedFileId = fileId
                    selectedFile = item.itemFile
                } else {
                    selectedFileId = 0
                }
                arguments.updateBackgroundEmojiId(selectedFileId, selectedFile)
            },
            deleteBackwards: {
            },
            openStickerSettings: {
            },
            openFeatured: {
            },
            openSearch: {
            },
            addGroupAction: { groupId, isPremiumLocked, _ in
                guard let collectionId = groupId.base as? ItemCollectionId else {
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
            clearGroup: { _ in
            },
            editAction: { _ in
            },
            pushController: { c in
            },
            presentController: { c in
            },
            presentGlobalOverlayController: { c in
            },
            navigationController: {
                return nil
            },
            requestUpdate: { _ in
            },
            updateSearchQuery: { _ in
            },
            updateScrollingToItemGroup: {
            },
            onScroll: {},
            chatPeerId: nil,
            peekBehavior: nil,
            customLayout: nil,
            externalBackground: nil,
            externalExpansionView: nil,
            customContentView: nil,
            useOpaqueTheme: true,
            hideBackground: false,
            stateContext: nil,
            addImage: nil
        )
        
        let entries = peerNameColorScreenEntries(
            nameColors: context.peerNameColors,
            presentationData: presentationData,
            state: state,
            peer: peer,
            isPremium: isPremium,
            emojiContent: emojiContent
        )
        
        let title: ItemListControllerTitle = .sectionControl([presentationData.strings.ProfileColorSetup_TitleName, presentationData.strings.ProfileColorSetup_TitleProfile], state.selectedTabIndex)
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: title,
            leftNavigationButton: nil,
            rightNavigationButton: ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                if !isLocked {
                    applyChangesImpl?()
                } else {
                    HapticFeedback().impact(.light)
                    let controller = UndoOverlayController(
                        presentationData: presentationData,
                        content: .premiumPaywall(
                            title: nil,
                            text: presentationData.strings.NameColor_TooltipPremium_Account,
                            customUndoText: nil,
                            timeout: nil,
                            linkAction: nil
                        ),
                        elevatedLayout: false,
                        action: { action in
                            if case .info = action {
                                var replaceImpl: ((ViewController) -> Void)?
                                let controller = context.sharedContext.makePremiumDemoController(context: context, subject: .colors, forceDark: false, action: {
                                    let controller = context.sharedContext.makePremiumIntroController(context: context, source: .settings, forceDark: false, dismissed: nil)
                                    replaceImpl?(controller)
                                }, dismissed: nil)
                                replaceImpl = { [weak controller] c in
                                    controller?.replace(with: c)
                                }
                                pushImpl?(controller)
                            }
                            return true
                        }
                    )
                    presentImpl?(controller)
                }
            }),
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: false
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks,
            footerItem: nil,
            animateChanges: false
        )
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    controller.titleControlValueChanged = { value in
        updateState { state in
            var state = state
            state.selectedTabIndex = value
            return state
        }
    }
    presentImpl = { [weak controller] c in
        guard let controller else {
            return
        }
        if c is UndoOverlayController {
            controller.present(c, in: .current)
        } else {
            controller.present(c, in: .window(.root))
        }
    }
    pushImpl = { [weak controller] c in
        guard let controller else {
            return
        }
        controller.push(c)
    }
    dismissImpl = { [weak controller] in
        guard let controller else {
            return
        }
        controller.dismiss()
    }
    controller.attemptNavigation = { f in
        return attemptNavigationImpl?(f) ?? true
    }
    attemptNavigationImpl = { f in
        if case .account = subject, !context.isPremium {
            return true
        }
        let state = stateValue.with({ $0 })
        if case .channel = subject, state.needsBoosts {
            return true
        }
        var hasChanges = false
        if state.updatedNameColor != nil || state.updatedBackgroundEmojiId != nil {
            hasChanges = true
        }
        if hasChanges {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            presentImpl?(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: presentationData.strings.NameColor_UnsavedChanges_Title, text: presentationData.strings.NameColor_UnsavedChanges_Text, actions: [
                TextAlertAction(type: .genericAction, title: presentationData.strings.NameColor_UnsavedChanges_Discard, action: {
                    f()
                    dismissImpl?()
                }),
                TextAlertAction(type: .defaultAction, title: presentationData.strings.NameColor_UnsavedChanges_Apply, action: {
                    applyChangesImpl?()
                })
            ]))
            return false
        } else {
            return true
        }
    }
    applyChangesImpl = { [weak controller] in
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        |> deliverOnMainQueue).startStandalone(next: { peer in
            guard let peer else {
                return
            }
            let state = stateValue.with { $0 }
            if state.updatedNameColor == nil && state.updatedBackgroundEmojiId == nil && !state.hasUpdatedProfileColor && !state.hasUpdatedProfileBackgroundEmojiId {
                dismissImpl?()
                return
            }
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }

            let nameColor = state.updatedNameColor ?? peer.nameColor
            let backgroundEmojiId = state.updatedBackgroundEmojiId ?? peer.backgroundEmojiId
            let colors = context.peerNameColors.get(nameColor ?? .blue, dark: presentationData.theme.overallDarkAppearance)
            
            let profileColor = state.hasUpdatedProfileColor ? state.updatedProfileColor : peer.profileColor
            let profileBackgroundEmojiId = state.hasUpdatedProfileBackgroundEmojiId ? state.updatedProfileBackgroundEmojiId : peer.profileBackgroundEmojiId
            
            switch subject {
            case .account:
                let _ = context.engine.accountData.updateNameColorAndEmoji(nameColor: nameColor ?? .blue, backgroundEmojiId: backgroundEmojiId ?? 0, profileColor: profileColor, profileBackgroundEmojiId: profileBackgroundEmojiId ?? 0).startStandalone()
                
                if let navigationController = controller?.navigationController as? NavigationController {
                    Queue.mainQueue().after(0.25) {
                        if let lastController = navigationController.viewControllers.last as? ViewController {
                            var colorList: [PeerNameColors.Colors] = []
                            if let nameColor {
                                colorList.append(context.peerNameColors.get(nameColor, dark: presentationData.theme.overallDarkAppearance))
                            }
                            if let profileColor {
                                colorList.append(context.peerNameColors.getProfile(profileColor, dark: presentationData.theme.overallDarkAppearance, subject: .palette))
                            }

                            let colorImage = generateSettingsMenuPeerColorsLabelIcon(colors: colorList)
                            
                            let tipController = UndoOverlayController(presentationData: presentationData, content: .image(image: colorImage, title: nil, text: presentationData.strings.ProfileColorSetup_ToastAccountColorUpdated, round: false, undoText: nil), elevatedLayout: false, position: .bottom, animateInAsReplacement: false, action: { _ in return false })
                            lastController.present(tipController, in: .window(.root))
                        }
                    }
                }
                
                dismissImpl?()
            case let .channel(peerId):
                updateState { state in
                    var updatedState = state
                    updatedState.inProgress = true
                    return updatedState
                }
                let _ = (context.engine.peers.updatePeerNameColorAndEmoji(peerId: peerId, nameColor: nameColor ?? .blue, backgroundEmojiId: backgroundEmojiId ?? 0, profileColor: profileColor, profileBackgroundEmojiId: profileBackgroundEmojiId ?? 0)
                |> deliverOnMainQueue).startStandalone(next: {
                }, error: { error in
                    if case .channelBoostRequired = error {
                        updateState { state in
                            var updatedState = state
                            updatedState.needsBoosts = true
                            return updatedState
                        }
                        
                        let _ = combineLatest(
                            queue: Queue.mainQueue(),
                            context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)),
                            context.engine.peers.getChannelBoostStatus(peerId: peerId)
                        ).startStandalone(next: { peer, status in
                            guard let peer, let status else {
                                return
                            }
                            
                            updateState { state in
                                var updatedState = state
                                updatedState.inProgress = false
                                return updatedState
                            }
                            
                            let link = status.url
                            let controller = PremiumLimitScreen(context: context, subject: .storiesChannelBoost(peer: peer, boostSubject: .nameColors(colors: .blue), isCurrent: true, level: Int32(status.level), currentLevelBoosts: Int32(status.currentLevelBoosts), nextLevelBoosts: status.nextLevelBoosts.flatMap(Int32.init), link: link, myBoostCount: 0, canBoostAgain: false), count: Int32(status.boosts), action: {
                                UIPasteboard.general.string = link
                                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                presentImpl?(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.ChannelBoost_BoostLinkCopied), elevatedLayout: false, position: .bottom, animateInAsReplacement: false, action: { _ in return false }))
                                return true
                            }, openStats: nil, openGift: premiumConfiguration.giveawayGiftsPurchaseAvailable ? {
                                let controller = createGiveawayController(context: context, peerId: peerId, subject: .generic)
                                pushImpl?(controller)
                            } : nil)
                            pushImpl?(controller)
                            
                            HapticFeedback().impact(.light)
                        })
                    } else {
                        updateState { state in
                            var updatedState = state
                            updatedState.inProgress = false
                            return updatedState
                        }
                    }
                }, completed: {
                    if let navigationController = controller?.navigationController as? NavigationController {
                        Queue.mainQueue().after(0.25) {
                            if let lastController = navigationController.viewControllers.last as? ViewController {
                                let tipController = UndoOverlayController(presentationData: presentationData, content: .image(image: generatePeerNameColorImage(nameColor: colors, isDark: presentationData.theme.overallDarkAppearance, bounds: CGSize(width: 32.0, height: 32.0), size: CGSize(width: 22.0, height: 22.0))!, title: nil, text: presentationData.strings.NameColor_ChannelColorUpdated, round: false, undoText: nil), elevatedLayout: false, position: .bottom, animateInAsReplacement: false, action: { _ in return false })
                                lastController.present(tipController, in: .window(.root))
                            }
                        }
                    }
                    
                    dismissImpl?()
                })
            }
        })
    }
    return controller
}
