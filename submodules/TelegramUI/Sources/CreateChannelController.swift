import Foundation
import UIKit
import Display
import SSignalKit
import SwiftSignalKit
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
import PeerInfoUI
import MapResourceToAvatarSizes
import LegacyMediaPickerUI
import TextFormat
import MediaEditor
import MediaEditorScreen
import CameraScreen
import AvatarEditorScreen
import OldChannelsController
import Photos
import AVFoundation

private struct CreateChannelArguments {
    let context: AccountContext
    let displayDescription: Bool
    
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
    case channelInfo(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, EnginePeer?, ItemListAvatarAndNameInfoItemState, ItemListAvatarAndNameInfoItemUpdatingAvatar?)
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
                    if lhsPeer != rhsPeer {
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
                return ItemListAvatarAndNameInfoItem(itemContext: .accountContext(arguments.context), presentationData: presentationData, systemStyle: .glass, dateTimeFormat: dateTimeFormat, mode: .editSettings, peer: peer, presence: nil, memberCount: nil, state: state, sectionId: ItemListSectionId(self.section), style: .blocks(withTopInset: false, withExtendedBottomInset: false), editingNameUpdated: { editingName in
                    arguments.updateEditingName(editingName)
                }, editingNameCompleted: {
                    if arguments.displayDescription {
                        arguments.focusOnDescription()
                    } else {
                        arguments.done()
                    }
                }, avatarTapped: {
                    arguments.changeProfilePhoto()
                }, updatingImage: avatar, tag: CreateChannelEntryTag.info)
            case let .setProfilePhoto(_, text):
                return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: .generic, alignment: .natural, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    arguments.changeProfilePhoto()
                })
            case let .descriptionSetup(_, text, value):
                return ItemListMultilineInputItem(presentationData: presentationData, systemStyle: .glass, text: value, placeholder: text, maxLength: ItemListMultilineInputItemTextLimit(value: 255, display: true), sectionId: self.section, style: .blocks, textUpdated: { updatedText in
                    arguments.updateEditingDescriptionText(updatedText)
                }, tag: CreateChannelEntryTag.description)
            case let .descriptionInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .usernameHeader(_, title):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
            case let .username(theme, placeholder, text):
                return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: "t.me/", textColor: theme.list.itemPrimaryTextColor), text: text, placeholder: placeholder, type: .username, clearType: .always, tag: nil, sectionId: self.section, textUpdated: { updatedText in
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

private func CreateChannelEntries(presentationData: PresentationData, state: CreateChannelState, requestPeer: ReplyMarkupButtonRequestPeerType.Channel?, displayDescription: Bool) -> [CreateChannelEntry] {
    var entries: [CreateChannelEntry] = []
    
    let groupInfoState = ItemListAvatarAndNameInfoItemState(editingName: state.editingName, updatingName: nil)
    
    let peer = TelegramGroup(id: EnginePeer.Id(namespace: .max, id: EnginePeer.Id.Id._internalFromInt64Value(0)), title: state.editingName.composedTitle, photo: [], participantCount: 0, role: .creator(rank: nil), membership: .Member, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0)

    entries.append(.channelInfo(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, EnginePeer(peer), groupInfoState, state.avatar))
    
    if displayDescription {
        entries.append(.descriptionSetup(presentationData.theme, presentationData.strings.Channel_Edit_AboutItem, state.editingDescriptionText))
        entries.append(.descriptionInfo(presentationData.theme, presentationData.strings.Channel_About_Help))
    }
    
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
    case community
    case requestPeer(ReplyMarkupButtonRequestPeerType.Channel)
}

public func createChannelController(context: AccountContext, mode: CreateChannelMode = .generic, willComplete: @escaping (String, @escaping () -> Void) -> Void = { _, complete in complete() }, completion: ((EnginePeer.Id, @escaping () -> Void) -> Void)? = nil) -> ViewController {
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
    
    var avatarPickerHolder: Any?
    var pendingAvatar: CreatePendingPeerAvatar?
    let applyPendingAvatar: (CreatePendingPeerAvatar) -> Void = { avatar in
        pendingAvatar = avatar
        updateState { current in
            var current = current
            current.avatar = avatar.updatingAvatar
            return current
        }
    }
    let updatePendingAvatarIfCurrent: (CreatePendingPeerAvatar) -> Void = { avatar in
        if pendingAvatar?.previewRepresentation.resource.id == avatar.previewRepresentation.resource.id {
            applyPendingAvatar(avatar)
        }
    }
    let clearPendingAvatar: () -> Void = {
        pendingAvatar = nil
        updateState { current in
            var current = current
            current.avatar = nil
            return current
        }
    }
    
    let checkAddressNameDisposable = MetaDisposable()
    actionsDisposable.add(checkAddressNameDisposable)
    
    var requestPeer: ReplyMarkupButtonRequestPeerType.Channel?
    if case let .requestPeer(peerType) = mode {
        requestPeer = peerType
    }

    let displayDescription: Bool
    if case .community = mode {
        displayDescription = false
    } else {
        displayDescription = true
    }
    
    let arguments = CreateChannelArguments(context: context, displayDescription: displayDescription, updateEditingName: { editingName in
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
                
                var createSignal: Signal<EnginePeer.Id, CreateChannelError> = context.engine.peers.createChannel(title: title, description: description.isEmpty ? nil : description)
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
                    if let pendingAvatar {
                        let _ = context.engine.peers.updatePeerPhoto(peerId: peerId, photo: pendingAvatar.uploadedPhoto, video: pendingAvatar.uploadedVideo, videoStartTimestamp: pendingAvatar.videoStartTimestamp, markup: pendingAvatar.markup, mapResourceToAvatarSizes: { resource, representations in
                            return mapResourceToAvatarSizes(engine: context.engine, resource: resource, representations: representations)
                        }).start()
                    }
                    
                    switch mode {
                    case .requestPeer:
                        completion?(peerId, {
                            dismissImpl?()
                        })
                    case .community:
                        completion?(peerId, {
                            dismissImpl?()
                        })
                    case .generic:
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
        
        let keyboardInputData = Promise<AvatarKeyboardInputData>()
        keyboardInputData.set(AvatarEditorScreen.inputData(context: context, isGroup: true))
        
        var dismissPickerImpl: (() -> Void)?
        let (mainController, pickerHolder) = context.sharedContext.makeAvatarMediaPickerScreen(context: context, peerType: .channel, getSourceRect: { return nil }, canDelete: pendingAvatar != nil, performDelete: {
            clearPendingAvatar()
        }, completion: { result, transitionView, transitionRect, transitionImage, fromCamera, _, cancelled in
            avatarPickerHolder = nil
            
            let applyPhoto: (UIImage) -> Void = { image in
                if let avatar = CreatePeerAvatarSetup.photo(context: context, image: image) {
                    applyPendingAvatar(avatar)
                }
            }
            let applyVideo: (UIImage, MediaEditorScreenImpl.MediaResult.VideoResult?, MediaEditorValues?, UploadPeerPhotoMarkup?) -> Void = { image, video, values, markup in
                if let avatar = CreatePeerAvatarSetup.video(context: context, image: image, video: video, values: values, markup: markup, didCompleteLoadingPreview: { avatar in
                    updatePendingAvatarIfCurrent(avatar)
                }) {
                    applyPendingAvatar(avatar)
                }
            }
            
            let subject: Signal<MediaEditorScreenImpl.Subject?, NoError>
            if let asset = result as? PHAsset {
                subject = .single(.asset(asset))
            } else if let image = result as? UIImage {
                subject = .single(.image(image: image, dimensions: PixelDimensions(image.size), additionalImage: nil, additionalImagePosition: .bottomRight, fromCamera: false))
            } else if let result = result as? Signal<CameraScreenImpl.Result, NoError> {
                subject = result
                |> map { value -> MediaEditorScreenImpl.Subject? in
                    switch value {
                    case .pendingImage:
                        return nil
                    case let .image(image):
                        return .image(image: image.image, dimensions: PixelDimensions(image.image.size), additionalImage: nil, additionalImagePosition: .topLeft, fromCamera: false)
                    case let .video(video):
                        return .video(videoPath: video.videoPath, thumbnail: video.coverImage, mirror: video.mirror, additionalVideoPath: nil, additionalThumbnail: nil, dimensions: video.dimensions, duration: video.duration, videoPositionChanges: [], additionalVideoPosition: .topLeft, fromCamera: false)
                    default:
                        return nil
                    }
                }
            } else {
                let controller = AvatarEditorScreen(context: context, inputData: keyboardInputData.get(), peerType: .channel, markup: nil)
                controller.imageCompletion = { image, commit in
                    applyPhoto(image)
                    commit()
                }
                controller.videoCompletion = { image, _, _, markup, commit in
                    applyVideo(image, nil, nil, markup)
                    commit()
                }
                pushControllerImpl?(controller)
                return
            }
            
            let editorController = MediaEditorScreenImpl(
                context: context,
                mode: .avatarEditor(clipStyle: .round),
                subject: subject,
                transitionIn: fromCamera ? .camera : transitionView.flatMap({ .gallery(
                    MediaEditorScreenImpl.TransitionIn.GalleryTransitionIn(
                        sourceView: $0,
                        sourceRect: transitionRect,
                        sourceImage: transitionImage
                    )
                ) }),
                transitionOut: { finished, _ in
                    if !finished, let transitionView {
                        return MediaEditorScreenImpl.TransitionOut(
                            destinationView: transitionView,
                            destinationRect: transitionView.bounds,
                            destinationCornerRadius: 0.0
                        )
                    }
                    return nil
                },
                completion: { results, commit in
                    guard let result = results.first else {
                        return
                    }
                    switch result.media {
                    case let .image(image, _):
                        applyPhoto(image)
                        commit({})
                    case let .video(video, coverImage, values, _, _):
                        if let coverImage {
                            applyVideo(coverImage, video, values, nil)
                        }
                        commit({})
                    default:
                        break
                    }
                    dismissPickerImpl?()
                } as ([MediaEditorScreenImpl.Result], @escaping (@escaping () -> Void) -> Void) -> Void
            )
            editorController.cancelled = { _ in
                cancelled()
            }
            pushControllerImpl?(editorController)
        }, dismissed: {
            avatarPickerHolder = nil
        })
        avatarPickerHolder = pickerHolder
        if let mainController {
            dismissPickerImpl = { [weak mainController] in
                if let mainController, let navigationController = mainController.navigationController {
                    var viewControllers = navigationController.viewControllers
                    viewControllers = viewControllers.filter { controller in
                        return !(controller is CameraScreen) && controller !== mainController
                    }
                    navigationController.setViewControllers(viewControllers, animated: false)
                }
            }
            if mainController is ActionSheetController {
                presentControllerImpl?(mainController, nil)
            } else {
                mainController.navigationPresentation = .flatModal
                mainController.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
                pushControllerImpl?(mainController)
            }
        }
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
            
            checkAddressNameDisposable.set((context.engine.peers.validateAddressNameInteractive(domain: .peer(EnginePeer.Id(namespace: Namespaces.Peer.CloudGroup, id: EnginePeer.Id.Id._internalFromInt64Value(0))), name: text)
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
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: CreateChannelEntries(presentationData: presentationData, state: state, requestPeer: requestPeer, displayDescription: displayDescription), style: .blocks, focusItemTag: CreateChannelEntryTag.info)
        
        return (controllerState, (listState, arguments))
    } |> afterDisposed {
        actionsDisposable.dispose()
        
        let _ = avatarPickerHolder
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
