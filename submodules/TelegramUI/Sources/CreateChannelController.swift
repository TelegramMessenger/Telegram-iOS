import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import LegacyComponents
import ItemListUI
import PresentationDataUtils
import AccountContext
import AlertUI
import PresentationDataUtils
import LegacyUI
import ItemListAvatarAndNameInfoItem
import WebSearchUI
import PeerInfoUI
import MapResourceToAvatarSizes
import LegacyMediaPickerUI
import TextFormat
import AvatarEditorScreen

private struct CreateChannelArguments {
    let context: AccountContext
    
    let updateEditingName: (ItemListAvatarAndNameInfoItemName) -> Void
    let updateEditingDescriptionText: (String) -> Void
    let done: () -> Void
    let changeProfilePhoto: () -> Void
    let focusOnDescription: () -> Void
    let updatePublicLinkText: (String) -> Void
    let openAuction: (String) -> Void
}

private enum CreateChannelSection: Int32 {
    case info
    case description
    case username
}

private enum CreateChannelEntryTag: ItemListItemTag {
    case info
    case description
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? CreateChannelEntryTag {
            switch self {
                case .info:
                    if case .info = other {
                        return true
                    } else {
                        return false
                    }
                case .description:
                    if case .description = other {
                        return true
                    } else {
                        return false
                    }
            }
        } else {
            return false
        }
    }
}

private enum CreateChannelEntry: ItemListNodeEntry {
    case channelInfo(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, Peer?, ItemListAvatarAndNameInfoItemState, ItemListAvatarAndNameInfoItemUpdatingAvatar?)
    case setProfilePhoto(PresentationTheme, String)
        
    case descriptionSetup(PresentationTheme, String, String)
    case descriptionInfo(PresentationTheme, String)
    
    case usernameHeader(PresentationTheme, String)
    case username(PresentationTheme, String, String)
    case usernameStatus(PresentationTheme, String, AddressNameValidationStatus, String, String)
    case usernameInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .channelInfo, .setProfilePhoto:
                return CreateChannelSection.info.rawValue
            case .descriptionSetup, .descriptionInfo:
                return CreateChannelSection.description.rawValue
            case .usernameHeader, .username, .usernameStatus, .usernameInfo:
                return CreateChannelSection.username.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .channelInfo:
                return 0
            case .setProfilePhoto:
                return 1
            case .descriptionSetup:
                return 2
            case .descriptionInfo:
                return 3
            case .usernameHeader:
                return 4
            case .username:
                return 5
            case .usernameStatus:
                return 6
            case .usernameInfo:
                return 7
        }
    }
    
    static func ==(lhs: CreateChannelEntry, rhs: CreateChannelEntry) -> Bool {
        switch lhs {
            case let .channelInfo(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsPeer, lhsEditingState, lhsAvatar):
                if case let .channelInfo(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsPeer, rhsEditingState, rhsAvatar) = rhs {
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
                        return false
                    }
                    if lhsDateTimeFormat != rhsDateTimeFormat {
                        return false
                    }
                    if let lhsPeer = lhsPeer, let rhsPeer = rhsPeer {
                        if !lhsPeer.isEqual(rhsPeer) {
                            return false
                        }
                    } else if (lhsPeer != nil) != (rhsPeer != nil) {
                        return false
                    }
                    if lhsEditingState != rhsEditingState {
                        return false
                    }
                    if lhsAvatar != rhsAvatar {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .setProfilePhoto(lhsTheme, lhsText):
                if case let .setProfilePhoto(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .descriptionSetup(lhsTheme, lhsText, lhsValue):
                if case let .descriptionSetup(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .descriptionInfo(lhsTheme, lhsText):
                if case let .descriptionInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .usernameHeader(lhsTheme, lhsText):
                if case let .usernameHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .username(lhsTheme, lhsText, lhsValue):
                if case let .username(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .usernameStatus(lhsTheme, lhsAddressName, lhsStatus, lhsText, lhsUsername):
                if case let .usernameStatus(rhsTheme, rhsAddressName, rhsStatus, rhsText, rhsUsername) = rhs, lhsTheme === rhsTheme, lhsAddressName == rhsAddressName, lhsStatus == rhsStatus, lhsText == rhsText, lhsUsername == rhsUsername {
                    return true
                } else {
                    return false
                }
            case let .usernameInfo(lhsTheme, lhsText):
                if case let .usernameInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: CreateChannelEntry, rhs: CreateChannelEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! CreateChannelArguments
        switch self {
            case let .channelInfo(_, _, dateTimeFormat, peer, state, avatar):
                return ItemListAvatarAndNameInfoItem(accountContext: arguments.context, presentationData: presentationData, dateTimeFormat: dateTimeFormat, mode: .editSettings, peer: peer.flatMap(EnginePeer.init), presence: nil, memberCount: nil, state: state, sectionId: ItemListSectionId(self.section), style: .blocks(withTopInset: false, withExtendedBottomInset: false), editingNameUpdated: { editingName in
                    arguments.updateEditingName(editingName)
                }, editingNameCompleted: {
                    arguments.focusOnDescription()
                }, avatarTapped: {
                    arguments.changeProfilePhoto()
                }, updatingImage: avatar, tag: CreateChannelEntryTag.info)
            case let .setProfilePhoto(_, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.changeProfilePhoto()
                })
            case let .descriptionSetup(_, text, value):
                return ItemListMultilineInputItem(presentationData: presentationData, text: value, placeholder: text, maxLength: ItemListMultilineInputItemTextLimit(value: 255, display: true), sectionId: self.section, style: .blocks, textUpdated: { updatedText in
                    arguments.updateEditingDescriptionText(updatedText)
                }, tag: CreateChannelEntryTag.description)
            case let .descriptionInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .usernameHeader(_, title):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
            case let .username(theme, placeholder, text):
                return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: "t.me/", textColor: theme.list.itemPrimaryTextColor), text: text, placeholder: placeholder, type: .username, clearType: .always, tag: nil, sectionId: self.section, textUpdated: { updatedText in
                    arguments.updatePublicLinkText(updatedText)
                }, action: {
                })
            case let .usernameStatus(_, _, status, text, username):
                var displayActivity = false
                let textColor: ItemListActivityTextItem.TextColor
                switch status {
                case .invalidFormat:
                    textColor = .destructive
                case let .availability(availability):
                    switch availability {
                    case .available:
                        textColor = .constructive
                    case .purchaseAvailable:
                        textColor = .generic
                    case .invalid, .taken:
                        textColor = .destructive
                    }
                case .checking:
                    textColor = .generic
                    displayActivity = true
                }
                return ItemListActivityTextItem(displayActivity: displayActivity, presentationData: presentationData, text: text, color: textColor, linkAction: { _ in
                    arguments.openAuction(username)
                }, sectionId: self.section)
            case let .usernameInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
        }
    }
}

private struct CreateChannelState: Equatable {
    var creating: Bool
    var editingName: ItemListAvatarAndNameInfoItemName
    var editingDescriptionText: String
    var avatar: ItemListAvatarAndNameInfoItemUpdatingAvatar?
    var editingPublicLinkText: String?
    var addressNameValidationStatus: AddressNameValidationStatus?
    
    static func ==(lhs: CreateChannelState, rhs: CreateChannelState) -> Bool {
        if lhs.creating != rhs.creating {
            return false
        }
        if lhs.editingName != rhs.editingName {
            return false
        }
        if lhs.editingDescriptionText != rhs.editingDescriptionText {
            return false
        }
        if lhs.avatar != rhs.avatar {
            return false
        }
        if lhs.editingPublicLinkText != rhs.editingPublicLinkText {
            return false
        }
        if lhs.addressNameValidationStatus != rhs.addressNameValidationStatus {
            return false
        }
        return true
    }
}

private func CreateChannelEntries(presentationData: PresentationData, state: CreateChannelState, requestPeer: ReplyMarkupButtonRequestPeerType.Channel?) -> [CreateChannelEntry] {
    var entries: [CreateChannelEntry] = []
    
    let groupInfoState = ItemListAvatarAndNameInfoItemState(editingName: state.editingName, updatingName: nil)
    
    let peer = TelegramGroup(id: PeerId(namespace: .max, id: PeerId.Id._internalFromInt64Value(0)), title: state.editingName.composedTitle, photo: [], participantCount: 0, role: .creator(rank: nil), membership: .Member, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0)
    
    entries.append(.channelInfo(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, peer, groupInfoState, state.avatar))
    
    entries.append(.descriptionSetup(presentationData.theme, presentationData.strings.Channel_Edit_AboutItem, state.editingDescriptionText))
    entries.append(.descriptionInfo(presentationData.theme, presentationData.strings.Channel_About_Help))
    
    if let requestPeer {
        if let hasUsername = requestPeer.hasUsername, hasUsername {
            let currentUsername = state.editingPublicLinkText ?? ""
            entries.append(.usernameHeader(presentationData.theme, presentationData.strings.CreateGroup_PublicLinkTitle.uppercased()))
            entries.append(.username(presentationData.theme, presentationData.strings.Group_PublicLink_Placeholder, currentUsername))
            
            if let status = state.addressNameValidationStatus {
                let statusText: String
                switch status {
                case let .invalidFormat(error):
                    switch error {
                    case .startsWithDigit:
                        statusText = presentationData.strings.Username_InvalidStartsWithNumber
                    case .startsWithUnderscore:
                        statusText = presentationData.strings.Username_InvalidStartsWithUnderscore
                    case .endsWithUnderscore:
                        statusText = presentationData.strings.Username_InvalidEndsWithUnderscore
                    case .invalidCharacters:
                        statusText = presentationData.strings.Username_InvalidCharacters
                    case .tooShort:
                        statusText = presentationData.strings.Username_InvalidTooShort
                    }
                case let .availability(availability):
                    switch availability {
                    case .available:
                        statusText = presentationData.strings.Username_UsernameIsAvailable(currentUsername).string
                    case .invalid:
                        statusText = presentationData.strings.Username_InvalidCharacters
                    case .taken:
                        statusText = presentationData.strings.Username_InvalidTaken
                    case .purchaseAvailable:
                        var markdownString = presentationData.strings.Username_UsernamePurchaseAvailable
                        let entities = generateTextEntities(markdownString, enabledTypes: [.mention])
                        if let entity = entities.first {
                            markdownString.insert(contentsOf: "]()", at: markdownString.index(markdownString.startIndex, offsetBy: entity.range.upperBound))
                            markdownString.insert(contentsOf: "[", at: markdownString.index(markdownString.startIndex, offsetBy: entity.range.lowerBound))
                        }
                        statusText = markdownString
                    }
                case .checking:
                    statusText = presentationData.strings.Username_CheckingUsername
                }
                entries.append(.usernameStatus(presentationData.theme, currentUsername, status, statusText, currentUsername))
            }
            
            entries.append(.usernameInfo(presentationData.theme, presentationData.strings.CreateGroup_PublicLinkInfo))
        }
    }
    
    return entries
}

public enum CreateChannelMode {
    case generic
    case requestPeer(ReplyMarkupButtonRequestPeerType.Channel)
}

public func createChannelController(context: AccountContext, mode: CreateChannelMode = .generic, willComplete: @escaping (String, @escaping () -> Void) -> Void = { _, complete in complete() }, completion: ((PeerId, @escaping () -> Void) -> Void)? = nil) -> ViewController {
    let initialState = CreateChannelState(creating: false, editingName: ItemListAvatarAndNameInfoItemName.title(title: "", type: .channel), editingDescriptionText: "", avatar: nil)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((CreateChannelState) -> CreateChannelState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var replaceControllerImpl: ((ViewController) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var dismissImpl: (() -> Void)?
    var endEditingImpl: (() -> Void)?
    var focusOnDescriptionImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let currentAvatarMixin = Atomic<TGMediaAvatarMenuMixin?>(value: nil)
    
    let uploadedAvatar = Promise<UploadedPeerPhotoData>()
    var uploadedVideoAvatar: (Promise<UploadedPeerPhotoData?>, Double?)? = nil
    
    let checkAddressNameDisposable = MetaDisposable()
    actionsDisposable.add(checkAddressNameDisposable)
    
    var requestPeer: ReplyMarkupButtonRequestPeerType.Channel?
    if case let .requestPeer(peerType) = mode {
        requestPeer = peerType
    }
    
    let arguments = CreateChannelArguments(context: context, updateEditingName: { editingName in
        updateState { current in
            var current = current
            switch editingName {
            case let .title(title, type):
                current.editingName = .title(title: String(title.prefix(255)), type: type)
            case let  .personName(firstName, lastName, _):
                current.editingName = .personName(firstName: String(firstName.prefix(255)), lastName: String(lastName.prefix(255)), phone: "")
            }
            return current
        }
    }, updateEditingDescriptionText: { text in
        updateState { current in
            var current = current
            current.editingDescriptionText = String(text.prefix(255))
            return current
        }
    }, done: {
        let (creating, title, description, publicLink) = stateValue.with { state -> (Bool, String, String, String?) in
            return (state.creating, state.editingName.composedTitle, state.editingDescriptionText, state.editingPublicLinkText)
        }
        
        if !creating && !title.isEmpty {
            willComplete(title, {
                updateState { current in
                    var current = current
                    current.creating = true
                    return current
                }
                
                endEditingImpl?()
                
                var createSignal: Signal<PeerId, CreateChannelError> = context.engine.peers.createChannel(title: title, description: description.isEmpty ? nil : description)
                if case .requestPeer = mode {
                    if let publicLink, !publicLink.isEmpty {
                        createSignal = createSignal
                        |> mapToSignal { peerId in
                            return context.engine.peers.updateAddressName(domain: .peer(peerId), name: publicLink)
                            |> mapError { _ in
                                return .generic
                            }
                            |> map { _ in
                                return peerId
                            }
                        }
                    }
                }
                actionsDisposable.add((createSignal
                |> deliverOnMainQueue
                |> afterDisposed {
                    Queue.mainQueue().async {
                        updateState { current in
                            var current = current
                            current.creating = false
                            return current
                        }
                    }
                }).start(next: { peerId in
                    let updatingAvatar = stateValue.with {
                        return $0.avatar
                    }
                    if let _ = updatingAvatar {
                        let _ = context.engine.peers.updatePeerPhoto(peerId: peerId, photo: uploadedAvatar.get(), video: uploadedVideoAvatar?.0.get(), videoStartTimestamp: uploadedVideoAvatar?.1, mapResourceToAvatarSizes: { resource, representations in
                            return mapResourceToAvatarSizes(postbox: context.account.postbox, resource: resource, representations: representations)
                        }).start()
                    }
                    
                    if case .requestPeer = mode {
                        completion?(peerId, {
                            dismissImpl?()
                        })
                    } else {
                        let controller = channelVisibilityController(context: context, peerId: peerId, mode: .initialSetup, upgradedToSupergroup: { _, f in f() })
                        replaceControllerImpl?(controller)
                    }
                }, error: { error in
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    let text: String?
                    switch error {
                        case .generic, .tooMuchLocationBasedGroups:
                            text = presentationData.strings.Login_UnknownError
                        case .tooMuchJoined:
                            pushControllerImpl?(oldChannelsController(context: context, intent: .create))
                            return
                        case .restricted:
                            text = presentationData.strings.Common_ActionNotAllowedError
                        default:
                            text = nil
                    }
                    if let text = text {
                        presentControllerImpl?(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                    }
                }))
            })
        }
    }, changeProfilePhoto: {
        endEditingImpl?()
        
        let title = stateValue.with { state -> String in
            return state.editingName.composedTitle
        }
        
        let _ = (context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId),
            TelegramEngine.EngineData.Item.Configuration.SearchBots()
        )
        |> deliverOnMainQueue).start(next: { peer, searchBotsConfiguration in
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            
            let legacyController = LegacyController(presentation: .custom, theme: presentationData.theme)
            legacyController.statusBar.statusBarStyle = .Ignore
            
            let emptyController = LegacyEmptyController(context: legacyController.context)!
            let navigationController = makeLegacyNavigationController(rootController: emptyController)
            navigationController.setNavigationBarHidden(true, animated: false)
            navigationController.navigationBar.transform = CGAffineTransform(translationX: -1000.0, y: 0.0)
            
            legacyController.bind(controller: navigationController)
            
            endEditingImpl?()
            presentControllerImpl?(legacyController, nil)
            
            let completedChannelPhotoImpl: (UIImage) -> Void = { image in
                if let data = image.jpegData(compressionQuality: 0.6) {
                    let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                    context.account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                    let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 640, height: 640), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)
                    uploadedAvatar.set(context.engine.peers.uploadedPeerPhoto(resource: resource))
                    uploadedVideoAvatar = nil
                    updateState { current in
                        var current = current
                        current.avatar = .image(representation, false)
                        return current
                    }
                }
            }
            
            let completedChannelVideoImpl: (UIImage, Any?, TGVideoEditAdjustments?) -> Void = { image, asset, adjustments in
                if let data = image.jpegData(compressionQuality: 0.6) {
                    let photoResource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                    context.account.postbox.mediaBox.storeResourceData(photoResource.id, data: data)
                    let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 640, height: 640), resource: photoResource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)
                    updateState { state in
                        var state = state
                        state.avatar = .image(representation, true)
                        return state
                    }
                    
                    var videoStartTimestamp: Double? = nil
                    if let adjustments = adjustments, adjustments.videoStartValue > 0.0 {
                        videoStartTimestamp = adjustments.videoStartValue - adjustments.trimStartValue
                    }
                    
                    let signal = Signal<TelegramMediaResource?, UploadPeerPhotoError> { subscriber in
                        let entityRenderer: LegacyPaintEntityRenderer? = adjustments.flatMap { adjustments in
                            if let paintingData = adjustments.paintingData, paintingData.hasAnimation {
                                return LegacyPaintEntityRenderer(account: context.account, adjustments: adjustments)
                            } else {
                                return nil
                            }
                        }
                        
                        let tempFile = EngineTempBox.shared.tempFile(fileName: "video.mp4")
                        let uploadInterface = LegacyLiveUploadInterface(context: context)
                        let signal: SSignal
                        if let url = asset as? URL, url.absoluteString.hasSuffix(".jpg"), let data = try? Data(contentsOf: url, options: [.mappedRead]), let image = UIImage(data: data), let entityRenderer = entityRenderer {
                            let durationSignal: SSignal = SSignal(generator: { subscriber in
                                let disposable = (entityRenderer.duration()).start(next: { duration in
                                    subscriber.putNext(duration)
                                    subscriber.putCompletion()
                                })
                                
                                return SBlockDisposable(block: {
                                    disposable.dispose()
                                })
                            })
                            signal = durationSignal.map(toSignal: { duration -> SSignal in
                                if let duration = duration as? Double {
                                    return TGMediaVideoConverter.renderUIImage(image, duration: duration, adjustments: adjustments, path: tempFile.path, watcher: nil, entityRenderer: entityRenderer)!
                                } else {
                                    return SSignal.single(nil)
                                }
                            })
                           
                        } else if let asset = asset as? AVAsset {
                            signal = TGMediaVideoConverter.convert(asset, adjustments: adjustments, path: tempFile.path, watcher: uploadInterface, entityRenderer: entityRenderer)!
                        } else {
                            signal = SSignal.complete()
                        }
                        
                        let signalDisposable = signal.start(next: { next in
                            if let result = next as? TGMediaVideoConversionResult {
                                if let image = result.coverImage, let data = image.jpegData(compressionQuality: 0.7) {
                                    context.account.postbox.mediaBox.storeResourceData(photoResource.id, data: data)
                                }
                                
                                if let timestamp = videoStartTimestamp {
                                    videoStartTimestamp = max(0.0, min(timestamp, result.duration - 0.05))
                                }
                                
                                var value = stat()
                                if stat(result.fileURL.path, &value) == 0 {
                                    if let data = try? Data(contentsOf: result.fileURL) {
                                        let resource: TelegramMediaResource
                                        if let liveUploadData = result.liveUploadData as? LegacyLiveUploadInterfaceResult {
                                            resource = LocalFileMediaResource(fileId: liveUploadData.id)
                                        } else {
                                            resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                                        }
                                        context.account.postbox.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
                                        subscriber.putNext(resource)
                                        
                                        EngineTempBox.shared.dispose(tempFile)
                                    }
                                }
                                subscriber.putCompletion()
                            }
                        }, error: { _ in
                        }, completed: nil)
                        
                        let disposable = ActionDisposable {
                            signalDisposable?.dispose()
                        }
                        
                        return ActionDisposable {
                            disposable.dispose()
                        }
                    }
                    
                    uploadedAvatar.set(context.engine.peers.uploadedPeerPhoto(resource: photoResource))
                    
                    let promise = Promise<UploadedPeerPhotoData?>()
                    promise.set(signal
                    |> `catch` { _ -> Signal<TelegramMediaResource?, NoError> in
                        return .single(nil)
                    }
                    |> mapToSignal { resource -> Signal<UploadedPeerPhotoData?, NoError> in
                        if let resource = resource {
                            return context.engine.peers.uploadedPeerVideo(resource: resource) |> map(Optional.init)
                        } else {
                            return .single(nil)
                        }
                    } |> afterNext { next in
                        if let next = next, next.isCompleted {
                            updateState { state in
                                var state = state
                                state.avatar = .image(representation, false)
                                return state
                            }
                        }
                    })
                    uploadedVideoAvatar = (promise, videoStartTimestamp)
                }
            }
            
            let keyboardInputData = Promise<AvatarKeyboardInputData>()
            keyboardInputData.set(AvatarEditorScreen.inputData(context: context, isGroup: true))
            
            let mixin = TGMediaAvatarMenuMixin(context: legacyController.context, parentController: emptyController, hasSearchButton: true, hasDeleteButton: stateValue.with({ $0.avatar }) != nil, hasViewButton: false, personalPhoto: false, isVideo: false, saveEditedPhotos: false, saveCapturedMedia: false, signup: false, forum: false, title: nil, isSuggesting: false)!
            mixin.stickersContext = LegacyPaintStickersContext(context: context)
            let _ = currentAvatarMixin.swap(mixin)
            mixin.requestSearchController = { assetsController in
                let controller = WebSearchController(context: context, peer: peer, chatLocation: nil, configuration: searchBotsConfiguration, mode: .avatar(initialQuery: title, completion: { result in
                    assetsController?.dismiss()
                    completedChannelPhotoImpl(result)
                }))
                presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }
            mixin.requestAvatarEditor = { imageCompletion, videoCompletion in
                guard let imageCompletion, let videoCompletion else {
                    return
                }
                let controller = AvatarEditorScreen(context: context, inputData: keyboardInputData.get(), peerType: .channel, markup: nil)
                controller.imageCompletion = imageCompletion
                controller.videoCompletion = videoCompletion
                pushControllerImpl?(controller)
            }
            mixin.didFinishWithImage = { image in
                if let image = image {
                    completedChannelPhotoImpl(image)
                }
            }
            mixin.didFinishWithVideo = { image, asset, adjustments in
                if let image = image, let asset = asset {
                    completedChannelVideoImpl(image, asset, adjustments)
                }
            }
            if stateValue.with({ $0.avatar }) != nil {
                mixin.didFinishWithDelete = {
                    updateState { current in
                        var current = current
                        current.avatar = nil
                        return current
                    }
                    uploadedAvatar.set(.never())
                }
            }
            mixin.didDismiss = { [weak legacyController] in
                let _ = currentAvatarMixin.swap(nil)
                legacyController?.dismiss()
            }
            let menuController = mixin.present()
            if let menuController = menuController {
                menuController.customRemoveFromParentViewController = { [weak legacyController] in
                    legacyController?.dismiss()
                }
            }
        })
    }, focusOnDescription: {
        focusOnDescriptionImpl?()
    }, updatePublicLinkText: { text in
        if text.isEmpty {
            checkAddressNameDisposable.set(nil)
            updateState { state in
                var updated = state
                updated.editingPublicLinkText = text
                updated.addressNameValidationStatus = nil
                return updated
            }
        } else {
            updateState { state in
                var updated = state
                updated.editingPublicLinkText = text
                return updated
            }
            
            checkAddressNameDisposable.set((context.engine.peers.validateAddressNameInteractive(domain: .peer(PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(0))), name: text)
            |> deliverOnMainQueue).start(next: { result in
                updateState { state in
                    var updated = state
                    updated.addressNameValidationStatus = result
                    return updated
                }
            }))
        }
    }, openAuction: { username in
        endEditingImpl?()
        
        context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: "https://fragment.com/username/\(username)", forceExternal: true, presentationData: context.sharedContext.currentPresentationData.with { $0 }, navigationController: nil, dismissInput: {})
    })
        
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let rightNavigationButton: ItemListNavigationButton
        if state.creating {
            rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
        } else {
            var isEnabled = true
            if state.editingName.composedTitle.isEmpty {
                isEnabled = false
            }
            if case let .requestPeer(peerType) = mode, let hasUsername = peerType.hasUsername, hasUsername, (state.editingPublicLinkText ?? "").isEmpty {
                isEnabled = false
            }
            rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Next), style: .bold, enabled: isEnabled, action: {
                arguments.done()
            })
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.ChannelIntro_CreateChannel), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: CreateChannelEntries(presentationData: presentationData, state: state, requestPeer: requestPeer), style: .blocks, focusItemTag: CreateChannelEntryTag.info)
        
        return (controllerState, (listState, arguments))
    } |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    replaceControllerImpl = { [weak controller] value in
        (controller?.navigationController as? NavigationController)?.replaceAllButRootController(value, animated: true)
    }
    pushControllerImpl = { [weak controller] value in
        controller?.push(value)
    }
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    controller.willDisappear = { _ in
        endEditingImpl?()
    }
    endEditingImpl = { [weak controller] in
        controller?.view.endEditing(true)
    }
    focusOnDescriptionImpl = { [weak controller] in
        guard let controller = controller else {
            return
        }
        controller.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ItemListMultilineInputItemNode, let itemTag = itemNode.tag, itemTag.isEqual(to: CreateChannelEntryTag.description) {
                itemNode.focus()
            }
        }
    }
    return controller
}
