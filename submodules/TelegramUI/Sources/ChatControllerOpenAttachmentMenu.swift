import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import TelegramNotices
import PresentationDataUtils
import TextFormat
import UrlHandling
import AccountContext
import ShareController
import ChatPresentationInterfaceState
import LegacyComponents
import LegacyUI
import AttachmentUI
import MediaPickerUI
import LegacyCamera
import LegacyMediaPickerUI
import LocationUI
import WebUI
import UndoUI
import ICloudResources
import PhoneNumberFormat
import ChatEntityKeyboardInputNode
import PremiumUI
import PremiumGiftAttachmentScreen
import TelegramCallsUI
import AutomaticBusinessMessageSetupScreen
import MediaEditorScreen
import CameraScreen
import ComposeTodoScreen
import ComposePollScreen
import Photos
import AttachmentFileController
import RichTextAttachmentScreen
import RichTextEditorMessageConversion
import ChatRichTextEditorComposer
import Postbox
import WalletContext
import WalletSendScreen

extension ChatControllerImpl {
    enum AttachMenuSubject {
        case `default`
        /// The menu replaces (or, for a text-only message, adds) the media of the message being edited.
        /// `mediaOptions` is nil when the message has no media yet, in which case every kind is offered;
        /// `mediaReference` is the current photo or video, when there is one, which enables editing it in place.
        case edit(mediaOptions: MessageMediaEditingOptions?, mediaReference: AnyMediaReference?)
        case bot(id: EnginePeer.Id, payload: String?, justInstalled: Bool)
        case gift
    }

    func presentAttachmentMenu(subject: AttachMenuSubject) {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
        
            guard self.audioRecorderValue == nil && self.videoRecorderValue == nil else {
                return
            }

            var editingSubject: (mediaOptions: MessageMediaEditingOptions?, mediaReference: AnyMediaReference?)?
            if case let .edit(mediaOptions, mediaReference) = subject {
                editingSubject = (mediaOptions, mediaReference)
            }
            let isEditingMessage = editingSubject != nil

            struct RichTextDraft: Codable {
                enum LoadError: Error {
                    case generic
                }

                private enum CodingKeys: String, CodingKey {
                    case document
                    case mediaKeys
                    case mediaValues
                    case emojiFilesKeys
                    case emojiFilesValues
                }

                let document: RichTextAttachmentScreen.Document
                let media: [String: Media]
                let emojiFiles: [Int64: TelegramMediaFile]

                init(document: RichTextAttachmentScreen.Document, media: [String: Media], emojiFiles: [Int64: TelegramMediaFile]) {
                    self.document = document
                    self.media = media
                    self.emojiFiles = emojiFiles
                }

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    let documentData = try container.decode(Data.self, forKey: .document)
                    self.document = try JSONDecoder().decode(RichTextAttachmentScreen.Document.self, from: documentData)

                    // `Media`/`TelegramMediaFile` are Postbox-coded (not `Codable`), so each value is stored as a
                    // self-describing root object (its concrete type is recovered from the embedded type hash).
                    let mediaKeys = try container.decode([String].self, forKey: .mediaKeys)
                    let mediaValues = try container.decode([Data].self, forKey: .mediaValues)
                    if mediaKeys.count != mediaValues.count {
                        throw LoadError.generic
                    }
                    var media: [String: Media] = [:]
                    for i in 0 ..< mediaKeys.count {
                        guard let mediaValue = PostboxDecoder(buffer: MemoryBuffer(data: mediaValues[i])).decodeRootObject() as? Media else {
                            throw LoadError.generic
                        }
                        media[mediaKeys[i]] = mediaValue
                    }
                    self.media = media

                    let emojiFilesKeys = try container.decode([Int64].self, forKey: .emojiFilesKeys)
                    let emojiFilesValues = try container.decode([Data].self, forKey: .emojiFilesValues)
                    if emojiFilesKeys.count != emojiFilesValues.count {
                        throw LoadError.generic
                    }
                    var emojiFiles: [Int64: TelegramMediaFile] = [:]
                    for i in 0 ..< emojiFilesKeys.count {
                        guard let emojiFileValue = PostboxDecoder(buffer: MemoryBuffer(data: emojiFilesValues[i])).decodeRootObject() as? TelegramMediaFile else {
                            throw LoadError.generic
                        }
                        emojiFiles[emojiFilesKeys[i]] = emojiFileValue
                    }
                    self.emojiFiles = emojiFiles
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    let documentData = try JSONEncoder().encode(self.document)
                    try container.encode(documentData, forKey: .document)

                    var mediaKeys: [String] = []
                    var mediaValues: [Data] = []
                    for (key, value) in self.media {
                        let mediaEncoder = PostboxEncoder()
                        mediaEncoder.encodeRootObject(value)
                        mediaKeys.append(key)
                        mediaValues.append(mediaEncoder.makeData())
                    }
                    try container.encode(mediaKeys, forKey: .mediaKeys)
                    try container.encode(mediaValues, forKey: .mediaValues)

                    var emojiFilesKeys: [Int64] = []
                    var emojiFilesValues: [Data] = []
                    for (key, value) in self.emojiFiles {
                        let fileEncoder = PostboxEncoder()
                        fileEncoder.encodeRootObject(value)
                        emojiFilesKeys.append(key)
                        emojiFilesValues.append(fileEncoder.makeData())
                    }
                    try container.encode(emojiFilesKeys, forKey: .emojiFilesKeys)
                    try container.encode(emojiFilesValues, forKey: .emojiFilesValues)
                }
            }

            var richTextDraft: RichTextDraft?

            var richTextDraftKey: EngineDataBuffer?
            if !isEditingMessage, let peerId = self.chatLocation.peerId {
                let key = EngineDataBuffer(length: 8 + 8)
                key.setInt64(0, value: peerId.toInt64())
                key.setInt64(8, value: self.chatLocation.threadId ?? 0)
                richTextDraftKey = key
                if let entry = await self.context.engine.data.get(
                    TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: Namespaces.CachedItemCollection.richTextComposerDrafts, id: key)
                ).get() {
                    richTextDraft = entry.get(RichTextDraft.self)
                }
            }
            
            let context = self.context
            let inputIsActive = self.presentationInterfaceState.inputMode == .text
            
            self.chatDisplayNode.dismissInput()
            
            let canByPassRestrictions = canBypassRestrictions(chatPresentationInterfaceState: self.presentationInterfaceState)
            
            var banSendText: (Int32, Bool)?
            var bannedSendPhotos: (Int32, Bool)?
            var bannedSendVideos: (Int32, Bool)?
            var bannedSendFiles: (Int32, Bool)?
            
            var enableMultiselection = true
            if self.presentationInterfaceState.interfaceState.postSuggestionState != nil {
                enableMultiselection = false
            }
            if isEditingMessage {
                enableMultiselection = false
            }
            
            var canSendPolls = true
            var canSendTodos = true
            if case let .customChatContents(customChatContents) = self.presentationInterfaceState.subject, case .welcomeMessages = customChatContents.kind {
                canSendTodos = false
            }
            if let peer = self.presentationInterfaceState.renderedPeer?.peer {
                if let peer = peer as? TelegramUser {
                    if peer.botInfo == nil && peer.id != self.context.account.peerId {
                        canSendPolls = false
                    }
                } else if peer is TelegramSecretChat {
                    canSendPolls = false
                    canSendTodos = false
                } else if let channel = peer as? TelegramChannel {
                    if case .broadcast = channel.info {
                        canSendTodos = false
                    }
                    if let value = channel.hasBannedPermission(.banSendPhotos, ignoreDefault: canByPassRestrictions) {
                        bannedSendPhotos = value
                    }
                    if let value = channel.hasBannedPermission(.banSendVideos, ignoreDefault: canByPassRestrictions) {
                        bannedSendVideos = value
                    }
                    if let value = channel.hasBannedPermission(.banSendFiles, ignoreDefault: canByPassRestrictions) {
                        bannedSendFiles = value
                    }
                    if let value = channel.hasBannedPermission(.banSendText, ignoreDefault: canByPassRestrictions) {
                        banSendText = value
                    }
                    if channel.hasBannedPermission(.banSendPolls, ignoreDefault: canByPassRestrictions) != nil || channel.isMonoForum {
                        canSendPolls = false
                    }
                } else if let group = peer as? TelegramGroup {
                    if group.hasBannedPermission(.banSendPhotos) {
                        bannedSendPhotos = (Int32.max, false)
                    }
                    if group.hasBannedPermission(.banSendVideos) {
                        bannedSendVideos = (Int32.max, false)
                    }
                    if group.hasBannedPermission(.banSendFiles) {
                        bannedSendFiles = (Int32.max, false)
                    }
                    if group.hasBannedPermission(.banSendText) {
                        banSendText = (Int32.max, false)
                    }
                    if group.hasBannedPermission(.banSendPolls) {
                        canSendPolls = false
                    }
                }
            } else {
                canSendPolls = false
            }
            
            var availableButtons: [AttachmentButtonType] = []
            if let editingSubject {
                // Only what can become the edited message's media. Everything that would send a new
                // message (location, contact, poll, todo, money, gifts, bots, rich text) is left out.
                if editingSubject.mediaOptions?.contains(.imageOrVideo) ?? true {
                    availableButtons.append(.gallery)
                }
                if editingSubject.mediaOptions?.contains(.file) ?? true {
                    availableButtons.append(.file)
                }
                if availableButtons.isEmpty {
                    return
                }
            } else {
                availableButtons = [.gallery, .file]
                if banSendText == nil {
                    availableButtons.append(.location)
                    availableButtons.append(.contact)
                }

                if canSendPolls {
                    availableButtons.insert(.poll, at: max(0, availableButtons.count - 1))
                }

                if canSendTodos {
                    availableButtons.insert(.todo, at: max(0, availableButtons.count - 1))
                }

                if "".isEmpty {
                    availableButtons.insert(.audio, at: max(0, availableButtons.count - 1))
                }
            }
            
            let presentationData = self.presentationData
            
            var isScheduledMessages = false
            if case .scheduledMessages = self.presentationInterfaceState.subject {
                isScheduledMessages = true
            }

            switch subject {
            case .default, .gift:
                if WalletConfiguration.with(appConfiguration: self.context.currentAppConfiguration.with { $0 }).isAvailable, !isScheduledMessages, banSendText == nil, let user = self.presentationInterfaceState.renderedPeer?.peer as? TelegramUser, user.id != self.context.account.peerId, !user.isDeleted, !isServicePeer(user), user.botInfo == nil, !user.flags.contains(.isSupport), let fileIndex = availableButtons.firstIndex(of: .file) {
                    availableButtons.insert(.money, at: fileIndex + 1)
                }
            case .edit, .bot:
                break
            }

            var isPaidMessages = false
            if let _ = self.presentationInterfaceState.sendPaidMessageStars {
                isPaidMessages = true
            }
            
            var peerType: AttachMenuBots.Bot.PeerFlags = []
            if let peer = self.presentationInterfaceState.renderedPeer?.peer {
                if let user = peer as? TelegramUser {
                    if let _ = user.botInfo {
                        peerType.insert(.bot)
                    } else {
                        peerType.insert(.user)
                    }
                } else if let _ = peer as? TelegramGroup {
                    peerType = .group
                } else if let channel = peer as? TelegramChannel {
                    if case .broadcast = channel.info {
                        peerType = .channel
                    } else {
                        peerType = .group
                    }
                }
            }
            
            let buttons: Signal<([AttachmentButtonType], [AttachmentButtonType], AttachmentButtonType?), NoError>
            if isEditingMessage {
                buttons = .single((availableButtons, availableButtons, availableButtons.contains(.gallery) ? .gallery : availableButtons[0]))
            } else if let peer = self.presentationInterfaceState.renderedPeer?.peer, !isScheduledMessages, !peer.isDeleted {
                buttons = combineLatest(
                    self.context.engine.messages.attachMenuBots(),
                    self.context.engine.accountData.shortcutMessageList(onlyRemote: true) |> take(1)
                )
                |> map { attachMenuBots, shortcutMessageList in
                    var buttons = availableButtons
                    var allButtons = availableButtons
                    var initialButton: AttachmentButtonType?
                    switch subject {
                    case .default:
                        initialButton = .gallery
                    case .gift:
                        initialButton = .gift
                    default:
                        break
                    }
                    
                    if !isPaidMessages {
                        if context.isPremium, shortcutMessageList.items.count > 0, let user = peer as? TelegramUser, user.botInfo == nil {
                            if let index = buttons.firstIndex(where: { $0 == .location }) {
                                buttons.insert(.quickReply, at: index + 1)
                            } else {
                                buttons.append(.quickReply)
                            }
                            if let index = allButtons.firstIndex(where: { $0 == .location }) {
                                allButtons.insert(.quickReply, at: index + 1)
                            } else {
                                allButtons.append(.quickReply)
                            }
                        }
                    }

                    for bot in attachMenuBots {
                        var peerType = peerType
                        if bot.peer.id == peer.id {
                            peerType.insert(.sameBot)
                            peerType.remove(.bot)
                        }
                        let button: AttachmentButtonType = .app(bot)
                        if !bot.peerTypes.intersection(peerType).isEmpty {
                            buttons.append(button)
                            
                            if case let .bot(botId, _, _) = subject {
                                if initialButton == nil && bot.peer.id == botId {
                                    initialButton = button
                                }
                            }
                        }
                        allButtons.append(button)
                    }
                    
                    return (buttons, allButtons, initialButton)
                }
            } else {
                buttons = .single((availableButtons, availableButtons, .gallery))
            }
            
            let dataSettings = self.context.sharedContext.accountManager.transaction { transaction -> GeneratedMediaStoreSettings in
                let entry = transaction.getSharedData(ApplicationSpecificSharedDataKeys.generatedMediaStoreSettings)?.get(GeneratedMediaStoreSettings.self)
                return entry ?? GeneratedMediaStoreSettings.defaultSettings
            }
            
            let premiumConfiguration = PremiumConfiguration.with(appConfiguration: self.context.currentAppConfiguration.with { $0 })
            let premiumGiftOptions: [CachedPremiumGiftOption]
            
            var showPremiumGift = false
            if !premiumConfiguration.isPremiumDisabled && self.presentationInterfaceState.disallowedGifts != TelegramDisallowedGifts.All {
                if self.presentationInterfaceState.alwaysShowGiftButton {
                    showPremiumGift = true
                } else if self.presentationInterfaceState.hasBirthdayToday {
                    showPremiumGift = true
                } else if premiumConfiguration.showPremiumGiftInAttachMenu || premiumConfiguration.showPremiumGiftInTextField {
                    showPremiumGift = true
                }
            }
            
            if let peer = self.presentationInterfaceState.renderedPeer?.peer, showPremiumGift, let user = peer as? TelegramUser, !user.isDeleted && user.botInfo == nil && !user.flags.contains(.isSupport) {
                premiumGiftOptions = self.presentationInterfaceState.premiumGiftOptions
            } else {
                premiumGiftOptions = []
            }
            
            let _ = combineLatest(queue: Queue.mainQueue(), buttons, dataSettings).startStandalone(next: { [weak self] buttonsAndInitialButton, dataSettings in
                guard let strongSelf = self else {
                    return
                }
                
                var (buttons, allButtons, initialButton) = buttonsAndInitialButton
                if !isEditingMessage {
                    if !premiumGiftOptions.isEmpty {
                        buttons.insert(.gift, at: 1)
                    }
                    let firstBotIndex = buttons.firstIndex(where: { button in
                        if case .app = button {
                            return true
                        }
                        return false
                    }) ?? buttons.endIndex
                    buttons.insert(.richText, at: firstBotIndex)
                }
                
                guard let initialButton = initialButton else {
                    if case let .bot(botId, botPayload, botJustInstalled) = subject {
                        if let button = allButtons.first(where: { button in
                            if case let .app(bot) = button, bot.peer.id == botId {
                                return true
                            } else {
                                return false
                            }
                        }), case let .app(bot) = button {
                            let content: UndoOverlayContent
                            if botJustInstalled {
                                if bot.flags.contains(.showInSettings) {
                                    content = .succeed(text: strongSelf.presentationData.strings.WebApp_ShortcutsSettingsAdded(bot.shortName).string, timeout: 5.0, customUndoText: nil)
                                } else {
                                    content = .succeed(text: strongSelf.presentationData.strings.WebApp_ShortcutsAdded(bot.shortName).string, timeout: 5.0, customUndoText: nil)
                                }
                            } else {
                                content = .info(title: nil, text: strongSelf.presentationData.strings.WebApp_AddToAttachmentAlreadyAddedError, timeout: nil, customUndoText: nil)
                            }
                            strongSelf.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, position: .top, action: { _ in return false }), in: .current)
                        } else {
                            let _ = (context.engine.messages.getAttachMenuBot(botId: botId)
                                     |> deliverOnMainQueue).startStandalone(next: { bot in
                                let controller = webAppTermsAlertController(context: context, updatedPresentationData: strongSelf.updatedPresentationData, completion: { allowWrite in
                                    let _ = (context.engine.messages.addBotToAttachMenu(botId: botId, allowWrite: allowWrite)
                                             |> deliverOnMainQueue).startStandalone(error: { _ in
                                        
                                    }, completed: {
                                        strongSelf.presentAttachmentBot(botId: botId, payload: botPayload, justInstalled: true)
                                    })
                                })
                                strongSelf.present(controller, in: .window(.root))
                            }, error: { _ in
                                strongSelf.present(textAlertController(context: context, updatedPresentationData: strongSelf.updatedPresentationData, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                            })
                        }
                    }
                    return
                }
                
                let inputText = strongSelf.presentationInterfaceState.interfaceState.effectiveInputState.inputText
                
                let currentMediaController = Atomic<MediaPickerScreenImpl?>(value: nil)
                let currentFilesController = Atomic<AttachmentFileControllerImpl?>(value: nil)
                let currentAudioController = Atomic<AttachmentFileControllerImpl?>(value: nil)
                let currentLocationController = Atomic<LocationPickerController?>(value: nil)
                
                strongSelf.canReadHistory.set(false)
                
                let attachmentController = AttachmentController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, style: .glass, chatLocation: strongSelf.chatLocation, isScheduledMessages: isScheduledMessages, isEditingMessage: isEditingMessage, buttons: buttons, initialButton: initialButton, customEmojiAvailable: strongSelf.presentationInterfaceState.customEmojiAvailable)
                attachmentController.attachmentButton = strongSelf.chatDisplayNode.getAttachmentButton()
                attachmentController.shouldMinimizeOnSwipe = { [weak attachmentController] button in
                    if case .app = button {
                        attachmentController?.convertToStandalone()
                        return true
                    }
                    return false
                }
                attachmentController.didDismiss = { [weak self] in
                    self?.attachmentController = nil
                    self?.canReadHistory.set(true)
                }
                attachmentController.getSourceRect = { [weak self] in
                    if let strongSelf = self {
                        return strongSelf.chatDisplayNode.frameForAttachmentButton()?.offsetBy(dx: strongSelf.chatDisplayNode.supernode?.frame.minX ?? 0.0, dy: 0.0)
                    } else {
                        return nil
                    }
                }
                attachmentController.requestController = { [weak self, weak attachmentController] type, completion in
                    guard let strongSelf = self else {
                        return true
                    }
                    switch type {
                    case .gallery:
                        strongSelf.controllerNavigationDisposable.set(nil)
                        let existingController = currentMediaController.with { $0 }
                        if let controller = existingController {
                            completion(controller, controller.mediaPickerContext)
                            controller.prepareForReuse()
                            return true
                        }
                        var editCurrentMediaButton: (state: AttachmentMainButtonState, action: () -> Void)?
                        if let currentMediaReference = editingSubject?.mediaReference {
                            let title: String
                            if currentMediaReference.media is TelegramMediaImage {
                                title = presentationData.strings.Conversation_EditingMessageMediaEditCurrentPhoto
                            } else {
                                title = presentationData.strings.Conversation_EditingMessageMediaEditCurrentVideo
                            }
                            let state = AttachmentMainButtonState(text: title, badge: nil, font: .bold, background: .color(presentationData.theme.actionSheet.controlAccentColor), textColor: presentationData.theme.list.itemCheckColors.foregroundColor, isVisible: true, progress: .none, isEnabled: true, hasShimmer: false, keepsTabRow: true)
                            editCurrentMediaButton = (state, { [weak self, weak attachmentController] in
                                attachmentController?.dismiss(animated: true)
                                self?.presentCurrentMediaEditor(mediaReference: currentMediaReference)
                            })
                        }
                        strongSelf.presentMediaPicker(saveEditedPhotos: dataSettings.storeEditedPhotos, bannedSendPhotos: bannedSendPhotos, bannedSendVideos: bannedSendVideos, enableMultiselection: enableMultiselection, isEditingMessage: isEditingMessage, mainButton: editCurrentMediaButton, present: { controller, mediaPickerContext in
                            let _ = currentMediaController.swap(controller)
                            if !inputText.string.isEmpty {
                                mediaPickerContext?.setCaption(inputText)
                            }
                            completion(controller, mediaPickerContext)
                        }, updateMediaPickerContext: { [weak attachmentController] mediaPickerContext in
                            attachmentController?.mediaPickerContext = mediaPickerContext
                        }, completion: { [weak self] fromGallery, signals, silentPosting, scheduleTime, parameters, getAnimatedTransitionSource, completion in
                            if !inputText.string.isEmpty {
                                self?.clearInputText()
                            }
                            if isEditingMessage {
                                self?.editMessageMediaWithLegacySignals(signals)
                                completion()
                            } else {
                                self?.enqueueMediaMessages(fromGallery: fromGallery, signals: signals, silentPosting: silentPosting, scheduleTime: scheduleTime, parameters: parameters, getAnimatedTransitionSource: getAnimatedTransitionSource, completion: completion)
                            }
                        })
                        return true
                    case .file:
                        strongSelf.controllerNavigationDisposable.set(nil)
                        let existingController = currentFilesController.with { $0 }
                        if let controller = existingController {
                            completion(controller, controller.mediaPickerContext)
                            controller.prepareForReuse()
                            return true
                        }
                        // The document scanner always sends a new message, so it is not offered while editing.
                        let presentDocumentScanner: (() -> Void)? = isEditingMessage ? nil : { [weak self] in
                            self?.presentDocumentScanner()
                        }
                        let controller = strongSelf.context.sharedContext.makeAttachmentFileController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, audio: false, bannedSendMedia: bannedSendFiles, presentGallery: { [weak self, weak attachmentController] in
                            attachmentController?.dismiss(animated: true)
                            self?.presentFileGallery(editingMessage: isEditingMessage)
                        }, presentFiles: { [weak self, weak attachmentController] in
                            attachmentController?.dismiss(animated: true)
                            self?.presentICloudFileGallery(editingMessage: isEditingMessage)
                        }, presentDocumentScanner: presentDocumentScanner, send: { [weak self, weak attachmentController] mediaReferences, silentPosting, scheduleTime, caption in
                            guard let self else {
                                return
                            }
                            var messages: [EnqueueMessage] = []
                            var groupingKey: Int64?
                            if mediaReferences.count > 1 {
                                groupingKey = Int64.random(in: .min ..< .max)
                            }

                            var attributes: [EngineMessage.Attribute] = []
                            var text = ""
                            if let caption {
                                text = caption.string
                                let entities = generateTextEntities(text, enabledTypes: .all, currentEntities: generateChatInputTextEntities(caption))
                                if !entities.isEmpty {
                                    attributes.append(TextEntitiesMessageAttribute(entities: entities))
                                }
                            }

                            if isEditingMessage {
                                // An edit takes exactly one media, and the file list allows multi-selection.
                                guard mediaReferences.count == 1, let mediaReference = mediaReferences.first else {
                                    self.present(textAlertController(context: self.context, title: nil, text: self.presentationData.strings.Chat_AttachmentMultipleFilesDisabled, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                    return
                                }
                                // A tap on a single file reports no caption at all (only the multi-selection panel does),
                                // and no caption means the message keeps its text; a caption replaces it.
                                if caption != nil, !inputText.string.isEmpty {
                                    self.clearInputText()
                                }
                                self.editMessageMediaWithMessages([.message(text: text, attributes: attributes, inlineStickers: [:], mediaReference: mediaReference, threadId: self.chatLocation.threadId, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])])
                                attachmentController?.dismiss(animated: true)
                                return
                            }

                            for mediaReference in mediaReferences {
                                if messages.count == 10 {
                                    groupingKey = Int64.random(in: .min ..< .max)
                                }
                                let isLast = mediaReference == mediaReferences.last
                                
                                messages.append(.message(text: isLast ? text : "", attributes: isLast ? attributes : [], inlineStickers: [:], mediaReference: mediaReference, threadId: strongSelf.chatLocation.threadId, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: groupingKey, correlationId: nil, bubbleUpEmojiOrStickersets: []))
                            }
                            messages = self.transformEnqueueMessages(messages, silentPosting: silentPosting, scheduleTime: scheduleTime, repeatPeriod: nil, postpone: false)
                            self.presentPaidMessageAlertIfNeeded(completion: { [weak self] postpone in
                                self?.sendMessages(messages, media: true, postpone: postpone)
                            })
                        })
                        if let controller = controller as? AttachmentFileControllerImpl {
                            let _ = currentFilesController.swap(controller)
                            if isEditingMessage, !inputText.string.isEmpty {
                                controller.mediaPickerContext?.setCaption(inputText)
                            }
                            completion(controller, controller.mediaPickerContext)
                        }
                        return true
                    case .money:
                        guard let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer.flatMap(EnginePeer.init) else {
                            return true
                        }
                        guard let walletContext = strongSelf.context.walletContext else {
                            return true
                        }
                        var acceptedTransferAnimation = false
                        let controller = WalletSendScreen(
                            context: strongSelf.context,
                            updatedPresentationData: strongSelf.updatedPresentationData,
                            useDefaultAccent: false,
                            peer: peer,
                            walletContext: walletContext,
                            allowOpenRecipientChat: false,
                            transferAnimation: { [weak self] id, source in
                                guard let self else { return false }
                                acceptedTransferAnimation = self.walletTransferAnimationCoordinator().receive(id: id, source: source)
                                return acceptedTransferAnimation
                            },
                            completed: { [weak self, weak attachmentController] in
                                attachmentController?.attachmentButton = nil
                                if !acceptedTransferAnimation {
                                    self?.scrollToEndOfHistory()
                                }
                            }
                        )
                        controller.transferAnimationWillStart = { [weak self] id in
                            self?.walletTransferAnimationCoordinator().prepare(id: id)
                        }
                        completion(controller, controller.mediaPickerContext)
                        strongSelf.controllerNavigationDisposable.set(nil)
                        return true
                    case .audio:
                        strongSelf.controllerNavigationDisposable.set(nil)
                        let existingController = currentAudioController.with { $0 }
                        if let controller = existingController {
                            completion(controller, controller.mediaPickerContext)
                            controller.prepareForReuse()
                            return true
                        }
                        let controller = strongSelf.context.sharedContext.makeAttachmentFileController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, audio: true, bannedSendMedia: bannedSendFiles, presentGallery: {
                        }, presentFiles: { [weak self, weak attachmentController] in
                            attachmentController?.dismiss(animated: true)
                            self?.presentICloudFileGallery(documentTypes: ["public.mp3", "public.mpeg-4-audio", "public.aac-audio", "org.xiph.flac"])
                        }, presentDocumentScanner: nil, send: { [weak self] mediaReferences, silentPosting, scheduleTime, caption in
                            guard let self else {
                                return
                            }
                            var messages: [EnqueueMessage] = []
                            var groupingKey: Int64?
                            if mediaReferences.count > 1 {
                                groupingKey = Int64.random(in: .min ..< .max)
                            }
                            
                            var attributes: [EngineMessage.Attribute] = []
                            var text = ""
                            if let caption {
                                text = caption.string
                                let entities = generateTextEntities(text, enabledTypes: .all, currentEntities: generateChatInputTextEntities(caption))
                                if !entities.isEmpty {
                                    attributes.append(TextEntitiesMessageAttribute(entities: entities))
                                }
                            }
                            
                            for mediaReference in mediaReferences {
                                if messages.count == 10 {
                                    groupingKey = Int64.random(in: .min ..< .max)
                                }
                                let isLast = mediaReference == mediaReferences.last
                                
                                messages.append(.message(text: isLast ? text : "", attributes: isLast ? attributes : [], inlineStickers: [:], mediaReference: mediaReference, threadId: strongSelf.chatLocation.threadId, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: groupingKey, correlationId: nil, bubbleUpEmojiOrStickersets: []))
                            }
                            messages = self.transformEnqueueMessages(messages, silentPosting: silentPosting, scheduleTime: scheduleTime, repeatPeriod: nil, postpone: false)
                            self.presentPaidMessageAlertIfNeeded(completion: { [weak self] postpone in
                                self?.sendMessages(messages, media: true, postpone: postpone)
                            })
                        })
                        if let controller = controller as? AttachmentFileControllerImpl {
                            let _ = currentAudioController.swap(controller)
                            completion(controller, controller.mediaPickerContext)
                        }
                        return true
                    case .location:
                        strongSelf.controllerNavigationDisposable.set(nil)
                        let existingController = currentLocationController.with { $0 }
                        if let controller = existingController {
                            completion(controller, controller.mediaPickerContext)
                            controller.prepareForReuse()
                            return true
                        }
                        let selfPeerId: EnginePeer.Id
                        if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer {
                            if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                                selfPeerId = peer.id
                            } else if let peer = peer as? TelegramChannel, case .group = peer.info, peer.hasPermission(.canBeAnonymous) {
                                selfPeerId = peer.id
                            } else {
                                selfPeerId = strongSelf.context.account.peerId
                            }
                        } else {
                            selfPeerId = strongSelf.context.account.peerId
                        }
                        let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: selfPeerId))
                                 |> deliverOnMainQueue).startStandalone(next: { selfPeer in
                            guard let strongSelf = self, let selfPeer = selfPeer else {
                                return
                            }
                            let hasLiveLocation: Bool
                            if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer {
                                hasLiveLocation = peer.id.namespace != Namespaces.Peer.SecretChat && peer.id != strongSelf.context.account.peerId && strongSelf.presentationInterfaceState.subject != .scheduledMessages
                            } else {
                                hasLiveLocation = false
                            }
                            let sharePeer = (strongSelf.presentationInterfaceState.renderedPeer?.peer).flatMap(EnginePeer.init)
                            let controller = LocationPickerController(context: strongSelf.context, style: .glass, updatedPresentationData: strongSelf.updatedPresentationData, mode: .share(peer: sharePeer, selfPeer: selfPeer, hasLiveLocation: hasLiveLocation), completion: { location, _, _, _, _ in
                                guard let strongSelf = self else {
                                    return
                                }
                                let replyMessageSubject = strongSelf.presentationInterfaceState.interfaceState.replyMessageSubject
                                let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: location), threadId: strongSelf.chatLocation.threadId, replyToMessageId: replyMessageSubject?.subjectModel, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                                
                                strongSelf.presentPaidMessageAlertIfNeeded(completion: { [weak self] postpone in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                        if let strongSelf = self {
                                            strongSelf.chatDisplayNode.collapseInput()
                                            
                                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                                $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil).withUpdatedPostSuggestionState(nil) }
                                            })
                                        }
                                    }, nil)
                                    strongSelf.sendMessages([message], postpone: postpone)
                                })
                            })
                            completion(controller, controller.mediaPickerContext)
                            
                            let _ = currentLocationController.swap(controller)
                        })
                        return true
                    case .contact:
                        let contactsController = ContactSelectionControllerImpl(ContactSelectionControllerParams(context: strongSelf.context, style: .glass, updatedPresentationData: strongSelf.updatedPresentationData, title: { $0.Contacts_Title }, displayDeviceContacts: true, multipleSelection: .always, requirePhoneNumbers: true))
                        contactsController.presentScheduleTimePicker = { [weak self] completion in
                            if let strongSelf = self {
                                strongSelf.presentScheduleTimePicker(completion: { result in
                                    completion(result.time, result.repeatPeriod, result.silentPosting)
                                })
                            }
                        }
                        contactsController.navigationPresentation = .modal
                        completion(contactsController, contactsController.mediaPickerContext)
                        strongSelf.controllerNavigationDisposable.set((contactsController.result
                                                                       |> deliverOnMainQueue).startStrict(next: { [weak self] peers in
                            if let strongSelf = self, let (peers, _, silent, scheduleTime, text, parameters) = peers {
                                var textEnqueueMessage: EnqueueMessage?
                                if let text = text, text.length > 0 {
                                    var attributes: [EngineMessage.Attribute] = []
                                    let entities = generateTextEntities(text.string, enabledTypes: .all, currentEntities: generateChatInputTextEntities(text))
                                    if !entities.isEmpty {
                                        attributes.append(TextEntitiesMessageAttribute(entities: entities))
                                    }
                                    textEnqueueMessage = .message(text: text.string, attributes: attributes, inlineStickers: [:], mediaReference: nil, threadId: strongSelf.chatLocation.threadId, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                                }
                                if peers.count > 1 {
                                    var enqueueMessages: [EnqueueMessage] = []
                                    if let textEnqueueMessage = textEnqueueMessage {
                                        enqueueMessages.append(textEnqueueMessage)
                                    }
                                    for peer in peers {
                                        var media: TelegramMediaContact?
                                        switch peer {
                                        case let .peer(contact, _, _):
                                            guard case let .user(contact) = contact, let phoneNumber = contact.phone else {
                                                continue
                                            }
                                            let contactData = DeviceContactExtendedData(basicData: DeviceContactBasicData(firstName: contact.firstName ?? "", lastName: contact.lastName ?? "", phoneNumbers: [DeviceContactPhoneNumberData(label: "_$!<Mobile>!$_", value: phoneNumber)]), middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [], note: "")
                                            
                                            let phone = contactData.basicData.phoneNumbers[0].value
                                            media = TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: contact.id, vCardData: nil)
                                        case let .deviceContact(_, basicData):
                                            guard !basicData.phoneNumbers.isEmpty else {
                                                continue
                                            }
                                            let contactData = DeviceContactExtendedData(basicData: basicData, middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [], note: "")
                                            
                                            let phone = contactData.basicData.phoneNumbers[0].value
                                            media = TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: nil, vCardData: nil)
                                        }
                                        
                                        if let media = media {
                                            let replyMessageSubject = strongSelf.presentationInterfaceState.interfaceState.replyMessageSubject
                                            strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                                if let strongSelf = self {
                                                    strongSelf.chatDisplayNode.collapseInput()
                                                    
                                                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                                        $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil).withUpdatedPostSuggestionState(nil) }
                                                    })
                                                }
                                            }, nil)
                                            let message = EnqueueMessage.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: media), threadId: strongSelf.chatLocation.threadId, replyToMessageId: replyMessageSubject?.subjectModel, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                                            enqueueMessages.append(message)
                                        }
                                    }
                                    if !enqueueMessages.isEmpty {
                                        enqueueMessages[enqueueMessages.count - 1] = enqueueMessages[enqueueMessages.count - 1].withUpdatedAttributes { attributes in
                                            var attributes = attributes
                                            if let parameters {
                                                if let effect = parameters.effect {
                                                    attributes.append(EffectMessageAttribute(id: effect.id))
                                                }
                                            }
                                            return attributes
                                        }
                                    }
                                    strongSelf.presentPaidMessageAlertIfNeeded(completion: { [weak self] postpone in
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        strongSelf.sendMessages(strongSelf.transformEnqueueMessages(enqueueMessages, silentPosting: silent, scheduleTime: scheduleTime))
                                    })
                                } else if let peer = peers.first {
                                    let dataSignal: Signal<(EngineRawPeer?,  DeviceContactExtendedData?), NoError>
                                    switch peer {
                                    case let .peer(contact, _, _):
                                        guard case let .user(contact) = contact, let phoneNumber = contact.phone else {
                                            return
                                        }
                                        let contactData = DeviceContactExtendedData(basicData: DeviceContactBasicData(firstName: contact.firstName ?? "", lastName: contact.lastName ?? "", phoneNumbers: [DeviceContactPhoneNumberData(label: "_$!<Mobile>!$_", value: phoneNumber)]), middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [], note: "")
                                        let context = strongSelf.context
                                        dataSignal = (strongSelf.context.sharedContext.contactDataManager?.basicData() ?? .single([:]))
                                        |> take(1)
                                        |> mapToSignal { basicData -> Signal<(EngineRawPeer?,  DeviceContactExtendedData?), NoError> in
                                            var stableId: String?
                                            let queryPhoneNumber = formatPhoneNumber(context: context, number: phoneNumber)
                                            outer: for (id, data) in basicData {
                                                for phoneNumber in data.phoneNumbers {
                                                    if formatPhoneNumber(context: context, number: phoneNumber.value) == queryPhoneNumber {
                                                        stableId = id
                                                        break outer
                                                    }
                                                }
                                            }
                                            
                                            if let stableId = stableId {
                                                return (context.sharedContext.contactDataManager?.extendedData(stableId: stableId) ?? .single(nil))
                                                |> take(1)
                                                |> map { extendedData -> (EngineRawPeer?,  DeviceContactExtendedData?) in
                                                    return (contact, extendedData)
                                                }
                                            } else {
                                                return .single((contact, contactData))
                                            }
                                        }
                                    case let .deviceContact(id, _):
                                        dataSignal = (strongSelf.context.sharedContext.contactDataManager?.extendedData(stableId: id) ?? .single(nil))
                                        |> take(1)
                                        |> map { extendedData -> (EngineRawPeer?,  DeviceContactExtendedData?) in
                                            return (nil, extendedData)
                                        }
                                    }
                                    strongSelf.controllerNavigationDisposable.set((dataSignal
                                                                                   |> deliverOnMainQueue).startStrict(next: { peerAndContactData in
                                        if let strongSelf = self, let contactData = peerAndContactData.1, contactData.basicData.phoneNumbers.count != 0 {
                                            if contactData.isPrimitive {
                                                let phone = contactData.basicData.phoneNumbers[0].value
                                                let media = TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: peerAndContactData.0?.id, vCardData: nil)
                                                let replyMessageSubject = strongSelf.presentationInterfaceState.interfaceState.replyMessageSubject
                                                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                                    if let strongSelf = self {
                                                        strongSelf.chatDisplayNode.collapseInput()
                                                        
                                                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                                            $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil).withUpdatedPostSuggestionState(nil) }
                                                        })
                                                    }
                                                }, nil)
                                                
                                                var enqueueMessages: [EnqueueMessage] = []
                                                if let textEnqueueMessage = textEnqueueMessage {
                                                    enqueueMessages.append(textEnqueueMessage)
                                                }
                                                var attributes: [EngineMessage.Attribute] = []
                                                if let parameters {
                                                    if let effect = parameters.effect {
                                                        attributes.append(EffectMessageAttribute(id: effect.id))
                                                    }
                                                }
                                                enqueueMessages.append(.message(text: "", attributes: attributes, inlineStickers: [:], mediaReference: .standalone(media: media), threadId: strongSelf.chatLocation.threadId, replyToMessageId: replyMessageSubject?.subjectModel, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))
                                                strongSelf.presentPaidMessageAlertIfNeeded(count: Int32(enqueueMessages.count), completion: { [weak self] postpone in
                                                    guard let strongSelf = self else {
                                                        return
                                                    }
                                                    strongSelf.sendMessages(strongSelf.transformEnqueueMessages(enqueueMessages, silentPosting: silent, scheduleTime: scheduleTime, postpone: postpone), postpone: postpone)
                                                })
                                            } else {
                                                let contactController = strongSelf.context.sharedContext.makeDeviceContactInfoController(context: ShareControllerAppAccountContext(context: strongSelf.context), environment: ShareControllerAppEnvironment(sharedContext: strongSelf.context.sharedContext), subject: .filter(peer: peerAndContactData.0.flatMap(EnginePeer.init), contactId: nil, contactData: contactData, completion: { peer, contactData in
                                                    guard let strongSelf = self, !contactData.basicData.phoneNumbers.isEmpty else {
                                                        return
                                                    }
                                                    let phone = contactData.basicData.phoneNumbers[0].value
                                                    if let vCardData = contactData.serializedVCard() {
                                                        let media = TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: peer?.id, vCardData: vCardData)
                                                        let replyMessageSubject = strongSelf.presentationInterfaceState.interfaceState.replyMessageSubject
                                                        strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                                            if let strongSelf = self {
                                                                strongSelf.chatDisplayNode.collapseInput()
                                                                
                                                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                                                    $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil).withUpdatedPostSuggestionState(nil) }
                                                                })
                                                            }
                                                        }, nil)
                                                        
                                                        var enqueueMessages: [EnqueueMessage] = []
                                                        if let textEnqueueMessage = textEnqueueMessage {
                                                            enqueueMessages.append(textEnqueueMessage)
                                                        }
                                                        enqueueMessages.append(.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: media), threadId: strongSelf.chatLocation.threadId, replyToMessageId: replyMessageSubject?.subjectModel, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))
                                                        strongSelf.presentPaidMessageAlertIfNeeded(count: Int32(enqueueMessages.count), completion: { [weak self] postpone in
                                                            guard let strongSelf = self else {
                                                                return
                                                            }
                                                            strongSelf.sendMessages(strongSelf.transformEnqueueMessages(enqueueMessages, silentPosting: silent, scheduleTime: scheduleTime, postpone: postpone), postpone: postpone)
                                                        })
                                                    }
                                                }), completed: nil, cancelled: nil)
                                                strongSelf.effectiveNavigationController?.pushViewController(contactController)
                                            }
                                        }
                                    }))
                                }
                            }
                        }))
                        return true
                    case .poll:
                        if let controller = strongSelf.configurePollCreation() as? AttachmentContainable {
                            completion(controller, controller.mediaPickerContext)
                            strongSelf.controllerNavigationDisposable.set(nil)
                        }
                        return true
                    case .todo:
                        if strongSelf.context.isPremium {
                            if let controller = strongSelf.configureTodoCreation() as? AttachmentContainable {
                                completion(controller, controller.mediaPickerContext)
                                strongSelf.controllerNavigationDisposable.set(nil)
                            }
                            return true
                        } else {
                            var replaceImpl: ((ViewController) -> Void)?
                            let demoController = strongSelf.context.sharedContext.makePremiumDemoController(context: strongSelf.context, subject: .todo, forceDark: false, action: {
                                let controller = context.sharedContext.makePremiumIntroController(context: context, source: .todo, forceDark: false, dismissed: nil)
                                replaceImpl?(controller)
                            }, dismissed: nil)
                            replaceImpl = { [weak self, weak demoController] c in
                                Queue.mainQueue().after(0.4) {
                                    self?.attachmentController?.dismiss(animated: false)
                                }
                                demoController?.replace(with: c)
                            }
                            strongSelf.push(demoController)
                            return false
                        }
                    case .gift:
                        if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer, let starsContext = context.starsContext {
                            let premiumGiftOptions = strongSelf.presentationInterfaceState.premiumGiftOptions
                            if !premiumGiftOptions.isEmpty {
                                let controller = PremiumGiftAttachmentScreen(context: context, starsContext: starsContext, peerId: peer.id, premiumOptions: premiumGiftOptions, hasBirthday: strongSelf.presentationInterfaceState.hasBirthdayToday, completion: { [weak self] in
                                    guard let self else {
                                        return
                                    }
                                    self.hintPlayNextOutgoingGift()
                                    self.attachmentController?.dismiss(animated: true)
                                })
                                completion(controller, controller.mediaPickerContext)
                                strongSelf.controllerNavigationDisposable.set(nil)
                                
                                let _ = ApplicationSpecificNotice.incrementDismissedPremiumGiftSuggestion(accountManager: context.sharedContext.accountManager, peerId: peer.id, timestamp: Int32(Date().timeIntervalSince1970)).startStandalone()
                            }
                        }
                        return true
                    case let .app(bot):
                        if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer {
                            var payload: String?
                            var fromAttachMenu = true
                            if case let .bot(_, botPayload, _) = subject {
                                payload = botPayload
                                fromAttachMenu = false
                            }
                            let params = WebAppParameters(source: fromAttachMenu ? .attachMenu : .generic, peerId: peer.id, botId: bot.peer.id, botName: bot.shortName, botVerified: bot.peer.isVerified, botAddress: bot.peer.addressName ?? "", appName: "", url: nil, queryId: nil, payload: payload, buttonText: nil, keepAliveSignal: nil, forceHasSettings: false, fullSize: false, isFullscreen: false)
                            let replyMessageSubject = strongSelf.presentationInterfaceState.interfaceState.replyMessageSubject
                            let controller = WebAppController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, params: params, replyToMessageId: replyMessageSubject?.messageId, threadId: strongSelf.chatLocation.threadId)
                            controller.openUrl = { [weak self] url, concealed, forceUpdate, commit in
                                self?.openUrl(url, concealed: concealed, forceExternal: true, forceUpdate: forceUpdate, commit: commit)
                            }
                            controller.getNavigationController = { [weak self] in
                                return self?.effectiveNavigationController
                            }
                            controller.completion = { [weak self] in
                                if let strongSelf = self {
                                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                        $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil).withUpdatedPostSuggestionState(nil) }
                                    })
                                    strongSelf.chatDisplayNode.historyNode.scrollToEndOfHistory()
                                }
                            }
                            completion(controller, controller.mediaPickerContext)
                            strongSelf.controllerNavigationDisposable.set(nil)
                            
                            if bot.flags.contains(.notActivated) {
                                let alertController = webAppTermsAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, completion: { [weak self, controller] allowWrite in
                                    guard let self else {
                                        return
                                    }
                                    if bot.flags.contains(.showInSettingsDisclaimer) {
                                        let _ = self.context.engine.messages.acceptAttachMenuBotDisclaimer(botId: bot.peer.id).startStandalone()
                                    }
                                    let _ = (self.context.engine.messages.addBotToAttachMenu(botId: bot.peer.id, allowWrite: allowWrite)
                                             |> deliverOnMainQueue).startStandalone(error: { _ in
                                    }, completed: { [weak controller] in
                                        controller?.refresh()
                                    })
                                },
                                                                                 dismissed: {
                                    strongSelf.attachmentController?.dismiss(animated: true)
                                })
                                strongSelf.present(alertController, in: .window(.root))
                            }
                        }
                        return true
                    case .quickReply:
                        let _ = (strongSelf.context.sharedContext.makeQuickReplySetupScreenInitialData(context: strongSelf.context)
                                 |> take(1)
                                 |> deliverOnMainQueue).start(next: { [weak strongSelf] initialData in
                            guard let strongSelf else {
                                return
                            }
                            
                            let controller = QuickReplySetupScreen(context: strongSelf.context, initialData: initialData as! QuickReplySetupScreen.InitialData, mode: .select(completion: { [weak strongSelf] shortcutId in
                                guard let strongSelf else {
                                    return
                                }
                                strongSelf.attachmentController?.dismiss(animated: true)
                                strongSelf.interfaceInteraction?.sendShortcut(shortcutId)
                            }))
                            completion(controller, controller.mediaPickerContext)
                            strongSelf.controllerNavigationDisposable.set(nil)
                        })
                        return true
                    case .richText:
                        let buildRichTextContent: (ChatControllerImpl, RichTextAttachmentScreen.Document, [String: Media], [Int64: TelegramMediaFile], Bool) -> (text: String, attributes: [EngineMessage.Attribute])? = { strongSelf, document, media, emojiFiles, sendWithoutFormatting in
                            let text: String
                            let attributes: [EngineMessage.Attribute]
                            if sendWithoutFormatting {
                                let peerSpecificEmojiPack = (strongSelf.contentData?.state.peerView?.cachedData as? CachedChannelData)?.emojiPack
                                let content = chatInputContent(fromDocument: document, media: media, emojiFiles: emojiFiles)
                                let inputText = trimChatInputText(entityPreservingFallbackAttributedString(from: content, preserveCustomEmoji: { _, file in
                                    if strongSelf.context.isPremium {
                                        return true
                                    }
                                    guard let file else {
                                        return false
                                    }
                                    if !file.isPremiumEmoji {
                                        return true
                                    }
                                    for attribute in file.attributes {
                                        if case let .CustomEmoji(_, _, _, packReference) = attribute, case let .id(id, _) = packReference {
                                            return id == peerSpecificEmojiPack?.id.id
                                        }
                                    }
                                    return false
                                }))
                                if inputText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    return nil
                                }
                                let entities = generateTextEntities(inputText.string, enabledTypes: .all, currentEntities: generateChatInputTextEntities(inputText))
                                text = inputText.string
                                attributes = entities.isEmpty ? [] : [TextEntitiesMessageAttribute(entities: entities)]
                            } else {
                                // Send a quote-bearing document as a rich message (InstantPage) too, even though a
                                // blockquote is entity-expressible — the rich preview renders the quote faithfully.
                                switch composeRichMessage(from: document, media: media, forSendPreview: true) {
                                case let .rich(instantPage):
                                    text = ""
                                    attributes = [RichTextMessageAttribute(instantPage: instantPage, fullInstantPage: nil)]
                                case let .plain(plainText, entities):
                                    text = plainText
                                    attributes = entities.isEmpty ? [] : [TextEntitiesMessageAttribute(entities: entities)]
                                case .empty:
                                    return nil
                                }
                            }
                            return (text, attributes)
                        }
                        let performRichTextSend: (ChatControllerImpl, [EnqueueMessage]) -> Void = { strongSelf, messages in
                            strongSelf.presentPaidMessageAlertIfNeeded(completion: { [weak strongSelf] postpone in
                                guard let strongSelf else {
                                    return
                                }
                                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({ [weak strongSelf] in
                                    guard let strongSelf else {
                                        return
                                    }
                                    strongSelf.chatDisplayNode.collapseInput()
                                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                        $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil).withUpdatedPostSuggestionState(nil) }
                                    })
                                }, nil)
                                strongSelf.sendMessages(messages, postpone: postpone)
                            })
                        }
                        let controller = RichTextAttachmentScreen(
                            context: context,
                            mode: .standalone(savedDraft: richTextDraft?.document, media: richTextDraft?.media ?? [:], emojiFiles: richTextDraft?.emojiFiles ?? [:]),
                            sendMessage: { [weak self] document, media, emojiFiles, sendWithoutFormatting in
                                guard let strongSelf = self else {
                                    return
                                }

                                richTextDraft = nil
                                if let richTextDraftKey {
                                    let _ = strongSelf.context.engine.itemCache.remove(collectionId: Namespaces.CachedItemCollection.richTextComposerDrafts, id: richTextDraftKey).start()
                                }

                                guard let (text, attributes) = buildRichTextContent(strongSelf, document, media, emojiFiles, sendWithoutFormatting) else {
                                    return
                                }
                                let replyMessageSubject = strongSelf.presentationInterfaceState.interfaceState.replyMessageSubject
                                let message: EnqueueMessage = .message(text: text, attributes: attributes, inlineStickers: [:], mediaReference: nil, threadId: strongSelf.chatLocation.threadId, replyToMessageId: replyMessageSubject?.subjectModel, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                                performRichTextSend(strongSelf, [message])
                            },
                            syncContent: { [weak self] document, media, emojiFiles in
                                guard let self else {
                                    return
                                }
                                let draft = RichTextDraft(document: document, media: media, emojiFiles: emojiFiles)
                                richTextDraft = draft
                                if let richTextDraftKey {
                                    let _ = self.context.engine.itemCache.put(collectionId: Namespaces.CachedItemCollection.richTextComposerDrafts, id: richTextDraftKey, item: draft).start()
                                }
                            },
                            sendContextActions: (strongSelf.presentationInterfaceState.interfaceState.editMessage == nil ? strongSelf.chatLocation.peerId.flatMap { peerId in
                                return RichTextAttachmentScreenSendContextActions(
                                    peerId: peerId,
                                    send: { [weak self] document, media, emojiFiles, sendWithoutFormatting, mode, _ in
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        richTextDraft = nil
                                        if let richTextDraftKey {
                                            let _ = strongSelf.context.engine.itemCache.remove(collectionId: Namespaces.CachedItemCollection.richTextComposerDrafts, id: richTextDraftKey).start()
                                        }
                                        guard let (text, attributes) = buildRichTextContent(strongSelf, document, media, emojiFiles, sendWithoutFormatting) else {
                                            return
                                        }
                                        let replyMessageSubject = strongSelf.presentationInterfaceState.interfaceState.replyMessageSubject
                                        let message: EnqueueMessage = .message(text: text, attributes: attributes, inlineStickers: [:], mediaReference: nil, threadId: strongSelf.chatLocation.threadId, replyToMessageId: replyMessageSubject?.subjectModel, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                                        let silentPosting: Bool
                                        let scheduleTime: Int32?
                                        switch mode {
                                        case .generic:
                                            silentPosting = false
                                            scheduleTime = nil
                                        case .silently:
                                            silentPosting = true
                                            scheduleTime = nil
                                        case .whenOnline:
                                            silentPosting = false
                                            scheduleTime = scheduleWhenOnlineTimestamp
                                        }
                                        let transformedMessages = strongSelf.transformEnqueueMessages([message], silentPosting: silentPosting, scheduleTime: scheduleTime)
                                        performRichTextSend(strongSelf, transformedMessages)
                                    },
                                    schedule: { [weak self] document, media, emojiFiles, sendWithoutFormatting, _ in
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        guard let (text, attributes) = buildRichTextContent(strongSelf, document, media, emojiFiles, sendWithoutFormatting) else {
                                            return
                                        }
                                        let replyMessageSubject = strongSelf.presentationInterfaceState.interfaceState.replyMessageSubject
                                        let message: EnqueueMessage = .message(text: text, attributes: attributes, inlineStickers: [:], mediaReference: nil, threadId: strongSelf.chatLocation.threadId, replyToMessageId: replyMessageSubject?.subjectModel, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                                        strongSelf.presentScheduleTimePicker(completion: { [weak self] time, _ in
                                            guard let strongSelf = self else {
                                                return
                                            }
                                            richTextDraft = nil
                                            if let richTextDraftKey {
                                                let _ = strongSelf.context.engine.itemCache.remove(collectionId: Namespaces.CachedItemCollection.richTextComposerDrafts, id: richTextDraftKey).start()
                                            }
                                            let transformedMessages = strongSelf.transformEnqueueMessages([message], silentPosting: false, scheduleTime: time)
                                            performRichTextSend(strongSelf, transformedMessages)
                                        })
                                    }
                                )
                            } : nil),
                            preuploadPeerId: strongSelf.chatLocation.peerId,
                            presentAttachmentMenu: { [weak self] request, completion in
                                guard let self else {
                                    return
                                }
                                self.presentRichTextAttachmentMenu(request: request, completion: completion)
                            },
                            presentFormulaEditor: { [weak self] initialValue, completion in
                                guard let self else {
                                    return
                                }
                                self.presentFormulaEditor(initialValue: initialValue, completion: completion)
                            },
                            pastedMarkdownParser: { context, text in
                                return chatInputContentFromPastedMarkdown(context: context, plainText: text)
                            }
                        )
                        completion(controller, controller.mediaPickerContext)
                        strongSelf.controllerNavigationDisposable.set(nil)
                        return true
                    default:
                        break
                    }
                    return true
                }
                let present = {
                    attachmentController.navigationPresentation = .flatModal
                    strongSelf.push(attachmentController)
                    strongSelf.attachmentController = attachmentController
                    
                    if case let .bot(botId, _, botJustInstalled) = subject, botJustInstalled {
                        if let button = allButtons.first(where: { button in
                            if case let .app(bot) = button, bot.peer.id == botId {
                                return true
                            } else {
                                return false
                            }
                        }), case let .app(bot) = button {
                            Queue.mainQueue().after(0.3) {
                                let content: UndoOverlayContent
                                if bot.flags.contains(.showInSettings) {
                                    content = .succeed(text: strongSelf.presentationData.strings.WebApp_ShortcutsSettingsAdded(bot.shortName).string, timeout: 5.0, customUndoText: nil)
                                } else {
                                    content = .succeed(text: strongSelf.presentationData.strings.WebApp_ShortcutsAdded(bot.shortName).string, timeout: 5.0, customUndoText: nil)
                                }
                                attachmentController.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, position: .top, action: { _ in return false }), in: .current)
                            }
                        }
                    }
                }
                
                if inputIsActive {
                    Queue.mainQueue().after(0.15, {
                        present()
                    })
                } else {
                    present()
                }
            })
        }
    }
    
    @available(iOS 13.0, *)
    func presentRichTextAttachmentMenu(request: RichTextAttachmentScreen.MediaRequest, completion: @escaping ([RichTextAttachmentScreen.RichTextAttachment]) -> Void) {
        // The gallery tab is inherently photos/videos only; audio + location are the only tabs that surface
        // non-photo/video media, so restricting to just `.gallery` yields a photo/video-only picker (used when
        // creating or extending a mosaic group).
        var availableButtons: [AttachmentButtonType] = []
        var photoVideoSelectionLimit = 1
        if let imageOrVideo = request.imageOrVideo {
            photoVideoSelectionLimit = imageOrVideo.limit
            availableButtons.append(.gallery)
        }
        if request.music {
            availableButtons.append(.audio)
        }
        if request.file {
            availableButtons.append(.file)
        }
        if request.location {
            availableButtons.append(.location)
        }
        presentPollAttachmentScreen(context: self.context, updatedPresentationData: self.updatedPresentationData, subject: .richText(PollAttachmentSubject.RichText(photoVideoSelectionLimit: photoVideoSelectionLimit)), availableButtons: availableButtons, inputMediaNodeData: nil, present: { [weak self] c, push in
            guard let self else {
                return
            }
            if push {
                self.push(c)
            } else {
                self.present(c, in: .window(.root))
            }
        }, completion: { results in
            let attachments: [RichTextAttachmentScreen.RichTextAttachment] = results.compactMap { result in
                if let image = result.concrete(TelegramMediaImage.self) {
                    return .image(image)
                } else if let file = result.concrete(TelegramMediaFile.self) {
                    return .file(file)
                } else if let mapReference = result.concrete(TelegramMediaMap.self) {
                    return .location(mapReference.media)
                }
                return nil
            }
            completion(attachments)
        })
    }

    func presentFormulaEditor(initialValue: String?, completion: @escaping (String) -> Void) {
        let controller = FormulaEditorScreen(
            context: self.context,
            initialValue: initialValue,
            completion: completion
        )
        self.present(controller, in: .window(.root))
    }

    /// Opens the legacy photo/video editor on the media of the message being edited, so it can be
    /// cropped, painted on or adjusted without picking a replacement. The result goes through the same
    /// path as a picked replacement (`editMessageMediaWithLegacySignals`).
    func presentCurrentMediaEditor(mediaReference: AnyMediaReference) {
        guard let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return
        }
        self.chatDisplayNode.dismissInput()
        
        // `.default` is the animated (GIF) editor; a photo or a regular video gets the plain editor.
        var mode: LegacyMediaEditorMode = .plain
        if let file = mediaReference.media as? TelegramMediaFile, file.isAnimated {
            mode = .default
        }
        let initialCaption = self.presentationInterfaceState.interfaceState.effectiveInputState.inputText
        legacyMediaEditor(context: self.context, peer: EnginePeer(peer), threadTitle: self.contentData?.state.threadInfo?.title, media: mediaReference, mode: mode, initialCaption: initialCaption, snapshots: [], transitionCompletion: nil, getCaptionPanelView: { [weak self] in
            return self?.getCaptionPanelView(isFile: false, hasTimer: false)
        }, photoToolbarView: { [context = self.context] backButton, doneButton, solidBackground, hasSendStarsButton in
            return makeMediaPickerPhotoToolbarView(context: context, backButton: backButton, doneButton: doneButton, solidBackground: solidBackground, hasSendStarsButton: hasSendStarsButton)
        }, sendMessagesWithSignals: { [weak self] signals, _, _, _ in
            guard let self, let signals else {
                return
            }
            if !initialCaption.string.isEmpty {
                self.clearInputText()
            }
            self.editMessageMediaWithLegacySignals(signals)
        }, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        })
    }

    func presentFileGallery(editingMessage: Bool = false) {
        self.presentOldMediaPicker(fileMode: true, editingMedia: editingMessage, completion: { [weak self] signals, silentPosting, scheduleTime in
            if editingMessage {
                self?.editMessageMediaWithLegacySignals(signals)
            } else {
                self?.enqueueMediaMessages(signals: signals, silentPosting: silentPosting, scheduleTime: scheduleTime > 0 ? scheduleTime : nil)
            }
        })
    }

    func presentICloudFileGallery(editingMessage: Bool = false, documentTypes: [String] = ["public.item"]) {
        let _ = (self.context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId),
            TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: false),
            TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: true)
        )
        |> deliverOnMainQueue).startStandalone(next: { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            let (accountPeer, limits, premiumLimits) = result
            let isPremium = accountPeer?.isPremium ?? false

            strongSelf.present(legacyICloudFilePicker(theme: strongSelf.presentationData.theme, hasMultiselection: !editingMessage, documentTypes: documentTypes, completion: { [weak self] urls in
                if let strongSelf = self, !urls.isEmpty {
                    var signals: [Signal<ICloudFileDescription?, NoError>] = []
                    for url in urls {
                        signals.append(iCloudFileDescription(url))
                    }
                    strongSelf.enqueueMediaMessageDisposable.set((combineLatest(signals)
                    |> deliverOnMainQueue).startStrict(next: { results in
                        if let strongSelf = self {
                            let replyMessageSubject = strongSelf.presentationInterfaceState.interfaceState.replyMessageSubject

                            for item in results {
                                if let item = item {
                                    if item.fileSize > Int64(premiumLimits.maxUploadFileParts) * 512 * 1024 {
                                        let controller = PremiumLimitScreen(context: strongSelf.context, subject: .files, count: 4, action: {
                                            return true
                                        })
                                        strongSelf.push(controller)
                                        return
                                    } else if item.fileSize > Int64(limits.maxUploadFileParts) * 512 * 1024 && !isPremium {
                                        let context = strongSelf.context
                                        var replaceImpl: ((ViewController) -> Void)?
                                        let controller = PremiumLimitScreen(context: context, subject: .files, count: 2, action: {
                                            replaceImpl?(PremiumIntroScreen(context: context, source: .upload))
                                            return true
                                        })
                                        replaceImpl = { [weak controller] c in
                                            controller?.replace(with: c)
                                        }
                                        strongSelf.push(controller)
                                        return
                                    }
                                }
                            }

                            var groupingKey: Int64?
                            var fileTypes: (music: Bool, other: Bool) = (false, false)
                            if results.count > 1 {
                                for item in results {
                                    if let item = item {
                                        let pathExtension = (item.fileName as NSString).pathExtension.lowercased()
                                        if ["mp3", "m4a"].contains(pathExtension) {
                                            fileTypes.music = true
                                        } else {
                                            fileTypes.other = true
                                        }
                                    }
                                }
                            }
                            if fileTypes.music != fileTypes.other {
                                groupingKey = Int64.random(in: Int64.min ... Int64.max)
                            }

                            var messages: [EnqueueMessage] = []
                            for item in results {
                                if let item = item {
                                    let fileId = Int64.random(in: Int64.min ... Int64.max)
                                    let mimeType = guessMimeTypeByFileExtension((item.fileName as NSString).pathExtension)
                                    var previewRepresentations: [TelegramMediaImageRepresentation] = []
                                    if mimeType.hasPrefix("image/") || mimeType == "application/pdf" || item.audioMetadata?.hasAudioArtwork == true {
                                        previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 320, height: 320), resource: ICloudFileResource(urlData: item.urlData, thumbnail: true), progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false))
                                    }
                                    var attributes: [TelegramMediaFileAttribute] = []
                                    attributes.append(.FileName(fileName: item.fileName))
                                    if let audioMetadata = item.audioMetadata {
                                        attributes.append(.Audio(isVoice: false, duration: audioMetadata.duration, title: audioMetadata.title, performer: audioMetadata.performer, waveform: nil))
                                    }

                                    let file = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: fileId), partialReference: nil, resource: ICloudFileResource(urlData: item.urlData, thumbnail: false), previewRepresentations: previewRepresentations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: mimeType, size: Int64(item.fileSize), attributes: attributes, alternativeRepresentations: [])
                                    let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: strongSelf.chatLocation.threadId, replyToMessageId: replyMessageSubject?.subjectModel, replyToStoryId: nil, localGroupingKey: groupingKey, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                                    messages.append(message)
                                }
                                if let _ = groupingKey, messages.count % 10 == 0 {
                                    groupingKey = Int64.random(in: Int64.min ... Int64.max)
                                }
                            }

                            if !messages.isEmpty {
                                if editingMessage {
                                    strongSelf.editMessageMediaWithMessages(messages)
                                } else {
                                    strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                        if let strongSelf = self {
                                            strongSelf.chatDisplayNode.collapseInput()

                                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                                $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil).withUpdatedPostSuggestionState(nil) }
                                            })
                                        }
                                    }, nil)
                                    strongSelf.presentPaidMessageAlertIfNeeded(completion: { [weak self] postpone in
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        strongSelf.sendMessages(messages, postpone: postpone)
                                    })
                                }
                            }
                        }
                    }))
                }
            }), in: .window(.root))
        })
    }

    func presentFileMediaPickerOptions(editingMessage: Bool) {
        let actionSheet = ActionSheetController(presentationData: self.presentationData)
        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: self.presentationData.strings.Conversation_FilePhotoOrVideo, action: { [weak self, weak actionSheet] in
                actionSheet?.dismissAnimated()
                if let strongSelf = self {
                    strongSelf.presentFileGallery(editingMessage: editingMessage)
                }
            }),
            ActionSheetButtonItem(title: self.presentationData.strings.Conversation_FileICloudDrive, action: { [weak self, weak actionSheet] in
                actionSheet?.dismissAnimated()
                if let strongSelf = self {
                    strongSelf.presentICloudFileGallery(editingMessage: editingMessage)
                }
            })
        ]), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        self.chatDisplayNode.dismissInput()
        self.present(actionSheet, in: .window(.root))
    }

    func presentMediaPicker(subject: MediaPickerScreenImpl.Subject = .assets(nil, .default), saveEditedPhotos: Bool, bannedSendPhotos: (Int32, Bool)?, bannedSendVideos: (Int32, Bool)?, enableMultiselection: Bool, isEditingMessage: Bool = false, mainButton: (state: AttachmentMainButtonState, action: () -> Void)? = nil, present: @escaping (MediaPickerScreenImpl, AttachmentMediaPickerContext?) -> Void, updateMediaPickerContext: @escaping (AttachmentMediaPickerContext?) -> Void, completion: @escaping (Bool, [Any], Bool, Int32?, ChatSendMessageActionSheetController.SendParameters?, @escaping (String) -> UIView?, @escaping () -> Void) -> Void) {
        var isScheduledMessages = false
        if case .scheduledMessages = self.presentationInterfaceState.subject {
            isScheduledMessages = true
        }
        var paidMediaAllowed = false
        if let cachedData = self.contentData?.state.peerView?.cachedData as? CachedChannelData, cachedData.flags.contains(.paidMediaAllowed) {
            paidMediaAllowed = true
        }
        let controller = MediaPickerScreenImpl(
            context: self.context,
            updatedPresentationData: self.updatedPresentationData,
            style: .glass,
            warpContentsOnEdges: false,
            peer: (self.presentationInterfaceState.renderedPeer?.peer).flatMap(EnginePeer.init),
            threadTitle: self.contentData?.state.threadInfo?.title,
            chatLocation: self.chatLocation,
            isScheduledMessages: isScheduledMessages,
            isActionButtonDone: isEditingMessage,
            bannedSendPhotos: bannedSendPhotos,
            bannedSendVideos: bannedSendVideos,
            enableMultiselection: enableMultiselection,
            canBoostToUnrestrict: (self.presentationInterfaceState.boostsToUnrestrict ?? 0) > 0 && bannedSendPhotos?.1 != true && bannedSendVideos?.1 != true,
            paidMediaAllowed: paidMediaAllowed,
            subject: subject,
            sendPaidMessageStars: self.presentationInterfaceState.sendPaidMessageStars?.value,
            saveEditedPhotos: saveEditedPhotos,
            mainButtonState: mainButton?.state,
            mainButtonHidesOnSelection: mainButton != nil,
            mainButtonAction: mainButton?.action
        )
        controller.openBoost = { [weak self, weak controller] in
            if let self {
                controller?.dismiss()
                self.interfaceInteraction?.openBoostToUnrestrict()
            }
        }
        let mediaPickerContext = controller.mediaPickerContext
        controller.openCamera = { [weak self] cameraView in
            self?.openCamera(cameraView: cameraView as? TGAttachmentCameraView, isEditingMessage: isEditingMessage)
        }
        controller.presentSchedulePicker = { [weak self] media, done in
            if let strongSelf = self {
                strongSelf.presentScheduleTimePicker(style: media ? .media : .default, completion: { [weak self] result in
                    if let strongSelf = self {
                        done(result.time, result.silentPosting)
                        if strongSelf.presentationInterfaceState.subject != .scheduledMessages && result.time != scheduleWhenOnlineTimestamp {
                            strongSelf.openScheduledMessages()
                        }
                    }
                })
            }
        }
        controller.presentTimerPicker = { [weak self] done in
            if let strongSelf = self {
                strongSelf.presentTimerPicker(style: .media, completion: { time in
                    done(time)
                })
            }
        }
        controller.getCaptionPanelView = { [weak self] in
            return self?.getCaptionPanelView(isFile: false)
        }
        controller.legacyCompletion = { fromGallery, signals, silently, scheduleTime, parameters, getAnimatedTransitionSource, sendCompletion in
            completion(fromGallery, signals, silently, scheduleTime, parameters, getAnimatedTransitionSource, sendCompletion)
        }
        controller.editCover = { [weak self] dimensions, completion in
            guard let self else {
                return
            }
            var dismissImpl: (() -> Void)?
            let mainController = coverMediaPickerController(
                context: self.context,
                completion: { result, transitionView, transitionRect, transitionImage, fromCamera, transitionOut, cancelled in
                    let subject: Signal<MediaEditorScreenImpl.Subject?, NoError>
                    if let asset = result as? PHAsset {
                        subject = .single(.asset(asset))
                    } else {
                        return
                    }

                    let editorController = MediaEditorScreenImpl(
                        context: self.context,
                        mode: .coverEditor(dimensions: dimensions),
                        subject: subject,
                        transitionIn: fromCamera ? .camera : transitionView.flatMap({ .gallery(
                            MediaEditorScreenImpl.TransitionIn.GalleryTransitionIn(
                                sourceView: $0,
                                sourceRect: transitionRect,
                                sourceImage: transitionImage
                            )
                        ) }),
                        transitionOut: { finished, isNew in
                            if !finished, let transitionView {
                                return MediaEditorScreenImpl.TransitionOut(
                                    destinationView: transitionView,
                                    destinationRect: transitionView.bounds,
                                    destinationCornerRadius: 0.0
                                )
                            }
                            return nil
                        }, completion: { results, commit in
                            if case let .image(image, _) = results.first?.media {
                                completion(image)
                                commit({})
                            }
                            dismissImpl?()
                        } as ([MediaEditorScreenImpl.Result], @escaping (@escaping () -> Void) -> Void) -> Void
                    )
                    editorController.cancelled = { _ in
                        cancelled()
                    }
                    self.push(editorController)
                }, dismissed: {

                }
            )
            (self.navigationController as? NavigationController)?.pushViewController(mainController, animated: true)
            dismissImpl = { [weak self, weak mainController] in
                if let self, let navigationController = self.navigationController, let mainController {
                    var viewControllers = navigationController.viewControllers
                    viewControllers = viewControllers.filter { c in
                        return c !== mainController
                    }
                    navigationController.setViewControllers(viewControllers, animated: false)
                }

            }
        }
        present(controller, mediaPickerContext)
    }

    func presentOldMediaPicker(fileMode: Bool, editingMedia: Bool, completion: @escaping ([Any], Bool, Int32) -> Void) {
        let engine = self.context.engine
        let _ = (self.context.sharedContext.accountManager.transaction { transaction -> Signal<(GeneratedMediaStoreSettings, EngineConfiguration.SearchBots), NoError> in
            let entry = transaction.getSharedData(ApplicationSpecificSharedDataKeys.generatedMediaStoreSettings)?.get(GeneratedMediaStoreSettings.self)

            return engine.data.get(TelegramEngine.EngineData.Item.Configuration.SearchBots())
            |> map { configuration -> (GeneratedMediaStoreSettings, EngineConfiguration.SearchBots) in
                return (entry ?? GeneratedMediaStoreSettings.defaultSettings, configuration)
            }
        }
        |> switchToLatest
        |> deliverOnMainQueue).startStandalone(next: { [weak self] settings, searchBotsConfiguration in
            guard let strongSelf = self, let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer else {
                return
            }
            let inputText = strongSelf.presentationInterfaceState.interfaceState.effectiveInputState.inputText
            var selectionLimit: Int = 100
            var slowModeEnabled = false
            if let channel = peer as? TelegramChannel, channel.isRestrictedBySlowmode {
                selectionLimit = 10
                slowModeEnabled = true
            }

            let _ = legacyAssetPicker(context: strongSelf.context, presentationData: strongSelf.presentationData, editingMedia: editingMedia, fileMode: fileMode, peer: peer, threadTitle: strongSelf.contentData?.state.threadInfo?.title, saveEditedPhotos: settings.storeEditedPhotos, allowGrouping: true, selectionLimit: selectionLimit).startStandalone(next: { generator in
                if let strongSelf = self {
                    let legacyController = LegacyController(presentation: fileMode ? .navigation : .custom, theme: strongSelf.presentationData.theme, initialLayout: strongSelf.validLayout)
                    legacyController.navigationPresentation = .modal
                    legacyController.statusBar.statusBarStyle = strongSelf.presentationData.theme.rootController.statusBarStyle.style
                    legacyController.controllerLoaded = { [weak legacyController] in
                        legacyController?.view.disablesInteractiveTransitionGestureRecognizer = true
                        legacyController?.view.disablesInteractiveModalDismiss = true
                    }
                    let controller = generator(legacyController.context)

                    legacyController.bind(controller: controller)
                    legacyController.deferScreenEdgeGestures = [.top]

                    configureLegacyAssetPicker(controller, context: strongSelf.context, peer: peer, chatLocation: strongSelf.chatLocation, initialCaption: inputText, hasSchedule: strongSelf.presentationInterfaceState.subject != .scheduledMessages && peer.id.namespace != Namespaces.Peer.SecretChat && !editingMedia, hasSilentPosting: !editingMedia, presentWebSearch: nil, presentSelectionLimitExceeded: {
                        guard let strongSelf = self else {
                            return
                        }

                        let text: String
                        if slowModeEnabled {
                            text = strongSelf.presentationData.strings.Chat_SlowmodeAttachmentLimitReached
                        } else {
                            text = strongSelf.presentationData.strings.Chat_AttachmentLimitReached
                        }

                        strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    }, presentSchedulePicker: { [weak self] media, done in
                        if let strongSelf = self {
                            strongSelf.presentScheduleTimePicker(style: media ? .media : .default, completion: { [weak self] result in
                                if let strongSelf = self {
                                     done(result.time, result.silentPosting)
                                     if strongSelf.presentationInterfaceState.subject != .scheduledMessages && result.time != scheduleWhenOnlineTimestamp {
                                         strongSelf.openScheduledMessages()
                                     }
                                 }
                            })
                        }
                    }, presentTimerPicker: { [weak self] done in
                        if let strongSelf = self {
                            strongSelf.presentTimerPicker(style: .media, completion: { time in
                                done(time)
                            })
                        }
                    }, getCaptionPanelView: { [weak self] in
                        return self?.getCaptionPanelView(isFile: fileMode)
                    })
                    controller.descriptionGenerator = legacyAssetPickerItemGenerator()
                    controller.completionBlock = { [weak legacyController] signals, silentPosting, scheduleTime in
                        if let legacyController = legacyController {
                            legacyController.dismiss(animated: true)
                            completion(signals!, silentPosting, scheduleTime)
                        }
                    }
                    controller.dismissalBlock = { [weak legacyController] in
                        if let legacyController = legacyController {
                            legacyController.dismiss(animated: true)
                        }
                    }
                    strongSelf.chatDisplayNode.dismissInput()
                    strongSelf.effectiveNavigationController?.pushViewController(legacyController)
                }
            })
        })
    }

    func presentLocationPicker() {
        guard let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return
        }
        let selfPeerId: EnginePeer.Id
        if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
            selfPeerId = peer.id
        } else if let peer = peer as? TelegramChannel, case .group = peer.info, peer.hasPermission(.canBeAnonymous) {
            selfPeerId = peer.id
        } else {
            selfPeerId = self.context.account.peerId
        }
        let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: selfPeerId))
        |> deliverOnMainQueue).startStandalone(next: { [weak self] selfPeer in
            guard let strongSelf = self, let selfPeer = selfPeer else {
                return
            }
            let hasLiveLocation = peer.id.namespace != Namespaces.Peer.SecretChat && peer.id != strongSelf.context.account.peerId && strongSelf.presentationInterfaceState.subject != .scheduledMessages
            let controller = LocationPickerController(context: strongSelf.context, style: .glass, updatedPresentationData: strongSelf.updatedPresentationData, mode: .share(peer: EnginePeer(peer), selfPeer: selfPeer, hasLiveLocation: hasLiveLocation), completion: { [weak self] location, _, _, _, _ in
                guard let strongSelf = self else {
                    return
                }
                let replyMessageSubject = strongSelf.presentationInterfaceState.interfaceState.replyMessageSubject
                let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: location), threadId: strongSelf.chatLocation.threadId, replyToMessageId: replyMessageSubject?.subjectModel, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                strongSelf.presentPaidMessageAlertIfNeeded(completion: { [weak self] postpone in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                        if let strongSelf = self {
                            strongSelf.chatDisplayNode.collapseInput()

                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil).withUpdatedPostSuggestionState(nil) }
                            })
                        }
                    }, nil)
                    strongSelf.sendMessages([message], postpone: postpone)
                })
            })
            strongSelf.effectiveNavigationController?.pushViewController(controller)
            strongSelf.chatDisplayNode.dismissInput()
        })
    }

    func presentContactPicker() {
        let contactsController = ContactSelectionControllerImpl(ContactSelectionControllerParams(context: self.context, updatedPresentationData: self.updatedPresentationData, title: { $0.Contacts_Title }, displayDeviceContacts: true, multipleSelection: .always))
        contactsController.navigationPresentation = .modal
        self.chatDisplayNode.dismissInput()
        self.effectiveNavigationController?.pushViewController(contactsController)
        self.controllerNavigationDisposable.set((contactsController.result
        |> deliverOnMainQueue).startStrict(next: { [weak self] peers in
            if let strongSelf = self, let (peers, _, _, _, _, _) = peers {
                if peers.count > 1 {
                    var enqueueMessages: [EnqueueMessage] = []
                    for peer in peers {
                        var media: TelegramMediaContact?
                        switch peer {
                            case let .peer(contact, _, _):
                                guard case let .user(contact) = contact, let phoneNumber = contact.phone else {
                                    continue
                                }
                                let contactData = DeviceContactExtendedData(basicData: DeviceContactBasicData(firstName: contact.firstName ?? "", lastName: contact.lastName ?? "", phoneNumbers: [DeviceContactPhoneNumberData(label: "_$!<Mobile>!$_", value: phoneNumber)]), middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [], note: "")

                                let phone = contactData.basicData.phoneNumbers[0].value
                                media = TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: contact.id, vCardData: nil)
                            case let .deviceContact(_, basicData):
                                guard !basicData.phoneNumbers.isEmpty else {
                                    continue
                                }
                                let contactData = DeviceContactExtendedData(basicData: basicData, middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [], note: "")

                                let phone = contactData.basicData.phoneNumbers[0].value
                                media = TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: nil, vCardData: nil)
                        }

                        if let media = media {
                            let replyMessageSubject = strongSelf.presentationInterfaceState.interfaceState.replyMessageSubject
                            strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                if let strongSelf = self {
                                    strongSelf.chatDisplayNode.collapseInput()

                                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                        $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil).withUpdatedPostSuggestionState(nil) }
                                    })
                                }
                            }, nil)
                            let message = EnqueueMessage.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: media), threadId: strongSelf.chatLocation.threadId, replyToMessageId: replyMessageSubject?.subjectModel, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                            enqueueMessages.append(message)
                        }
                    }
                    strongSelf.presentPaidMessageAlertIfNeeded(completion: { [weak self] postpone in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.sendMessages(enqueueMessages, postpone: postpone)
                    })
                } else if let peer = peers.first {
                    let dataSignal: Signal<(EngineRawPeer?,  DeviceContactExtendedData?), NoError>
                    switch peer {
                        case let .peer(contact, _, _):
                            guard case let .user(contact) = contact, let phoneNumber = contact.phone else {
                                return
                            }
                            let contactData = DeviceContactExtendedData(basicData: DeviceContactBasicData(firstName: contact.firstName ?? "", lastName: contact.lastName ?? "", phoneNumbers: [DeviceContactPhoneNumberData(label: "_$!<Mobile>!$_", value: phoneNumber)]), middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [], note: "")
                            let context = strongSelf.context
                            dataSignal = (strongSelf.context.sharedContext.contactDataManager?.basicData() ?? .single([:]))
                            |> take(1)
                            |> mapToSignal { basicData -> Signal<(EngineRawPeer?,  DeviceContactExtendedData?), NoError> in
                                var stableId: String?
                                let queryPhoneNumber = formatPhoneNumber(context: context, number: phoneNumber)
                                outer: for (id, data) in basicData {
                                    for phoneNumber in data.phoneNumbers {
                                        if formatPhoneNumber(context: context, number: phoneNumber.value) == queryPhoneNumber {
                                            stableId = id
                                            break outer
                                        }
                                    }
                                }

                                if let stableId = stableId {
                                    return (context.sharedContext.contactDataManager?.extendedData(stableId: stableId) ?? .single(nil))
                                    |> take(1)
                                    |> map { extendedData -> (EngineRawPeer?,  DeviceContactExtendedData?) in
                                        return (contact, extendedData)
                                    }
                                } else {
                                    return .single((contact, contactData))
                                }
                            }
                        case let .deviceContact(id, _):
                            dataSignal = (strongSelf.context.sharedContext.contactDataManager?.extendedData(stableId: id) ?? .single(nil))
                            |> take(1)
                            |> map { extendedData -> (EngineRawPeer?,  DeviceContactExtendedData?) in
                                return (nil, extendedData)
                            }
                    }
                    strongSelf.controllerNavigationDisposable.set((dataSignal
                    |> deliverOnMainQueue).startStrict(next: { peerAndContactData in
                        if let strongSelf = self, let contactData = peerAndContactData.1, contactData.basicData.phoneNumbers.count != 0 {
                            if contactData.isPrimitive {
                                let phone = contactData.basicData.phoneNumbers[0].value
                                let media = TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: peerAndContactData.0?.id, vCardData: nil)
                                let replyMessageSubject = strongSelf.presentationInterfaceState.interfaceState.replyMessageSubject
                                strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                    if let strongSelf = self {
                                        strongSelf.chatDisplayNode.collapseInput()

                                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                            $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil).withUpdatedPostSuggestionState(nil) }
                                        })
                                    }
                                }, nil)
                                let message = EnqueueMessage.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: media), threadId: strongSelf.chatLocation.threadId, replyToMessageId: replyMessageSubject?.subjectModel, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                                strongSelf.presentPaidMessageAlertIfNeeded(completion: { [weak self] postpone in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.sendMessages([message], postpone: postpone)
                                })
                            } else {
                                let contactController = strongSelf.context.sharedContext.makeDeviceContactInfoController(context: ShareControllerAppAccountContext(context: strongSelf.context), environment: ShareControllerAppEnvironment(sharedContext: strongSelf.context.sharedContext), subject: .filter(peer: peerAndContactData.0.flatMap(EnginePeer.init), contactId: nil, contactData: contactData, completion: { peer, contactData in
                                    guard let strongSelf = self, !contactData.basicData.phoneNumbers.isEmpty else {
                                        return
                                    }
                                    let phone = contactData.basicData.phoneNumbers[0].value
                                    if let vCardData = contactData.serializedVCard() {
                                        let media = TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: peer?.id, vCardData: vCardData)
                                        let replyMessageSubject = strongSelf.presentationInterfaceState.interfaceState.replyMessageSubject
                                        strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                            if let strongSelf = self {
                                                strongSelf.chatDisplayNode.collapseInput()

                                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                                    $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil).withUpdatedPostSuggestionState(nil) }
                                                })
                                            }
                                        }, nil)
                                        let message = EnqueueMessage.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: media), threadId: strongSelf.chatLocation.threadId, replyToMessageId: replyMessageSubject?.subjectModel, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                                        strongSelf.presentPaidMessageAlertIfNeeded(completion: { [weak self] postpone in
                                            guard let strongSelf = self else {
                                                return
                                            }
                                            strongSelf.sendMessages([message], postpone: postpone)
                                        })
                                    }
                                }), completed: nil, cancelled: nil)
                                strongSelf.effectiveNavigationController?.pushViewController(contactController)
                            }
                        }
                    }))
                }
            }
        }))
    }

    func getCaptionPanelView(isFile: Bool, hasTimer: Bool = true) -> TGCaptionPanelView? {
        var isScheduledMessages = false
        if case .scheduledMessages = self.presentationInterfaceState.subject {
            isScheduledMessages = true
        }
        return self.context.sharedContext.makeGalleryCaptionPanelView(context: self.context, chatLocation: self.presentationInterfaceState.chatLocation, isScheduledMessages: isScheduledMessages, isFile: isFile, hasTimer: hasTimer, customEmojiAvailable: self.presentationInterfaceState.customEmojiAvailable, pushViewController: { [weak self] c in
            self?.push(c)
        }, present: { [weak self] c in
            self?.present(c, in: .window(.root))
        }, presentInGlobalOverlay: { [weak self] c in
            guard let self else {
                return
            }
            self.presentInGlobalOverlay(c)
        }, getNavigationController: { [weak self] in
            return self?.navigationController as? NavigationController
        }) as? TGCaptionPanelView
    }

    /// `isEditingMessage` comes from the attachment menu that hosts the camera: a capture then replaces
    /// the edited message's media instead of sending a new message.
    func openCamera(cameraView: TGAttachmentCameraView? = nil, isEditingMessage: Bool = false) {
        let _ = (self.context.sharedContext.accountManager.transaction { transaction -> GeneratedMediaStoreSettings in
            let entry = transaction.getSharedData(ApplicationSpecificSharedDataKeys.generatedMediaStoreSettings)?.get(GeneratedMediaStoreSettings.self)
            return entry ?? GeneratedMediaStoreSettings.defaultSettings
        }
        |> deliverOnMainQueue).startStandalone(next: { [weak self] settings in
            guard let strongSelf = self else {
                return
            }

            var enablePhoto = true
            var enableVideo = true

            if let callManager = strongSelf.context.sharedContext.callManager as? PresentationCallManagerImpl, callManager.hasActiveCall {
                enableVideo = false
            }

            var bannedSendPhotos: (Int32, Bool)?
            var bannedSendVideos: (Int32, Bool)?

            if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer {
                if let channel = peer as? TelegramChannel {
                    if let value = channel.hasBannedPermission(.banSendPhotos) {
                        bannedSendPhotos = value
                    }
                    if let value = channel.hasBannedPermission(.banSendVideos) {
                        bannedSendVideos = value
                    }
                } else if let group = peer as? TelegramGroup {
                    if group.hasBannedPermission(.banSendPhotos) {
                        bannedSendPhotos = (Int32.max, false)
                    }
                    if group.hasBannedPermission(.banSendVideos) {
                        bannedSendVideos = (Int32.max, false)
                    }
                }
            }

            if bannedSendPhotos != nil {
                enablePhoto = false
            }
            if bannedSendVideos != nil {
                enableVideo = false
            }

            var storeCapturedMedia = false
            var hasSchedule = false
            if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer {
                storeCapturedMedia = peer.id.namespace != Namespaces.Peer.SecretChat
                hasSchedule = strongSelf.presentationInterfaceState.subject != .scheduledMessages && peer.id.namespace != Namespaces.Peer.SecretChat && strongSelf.presentationInterfaceState.sendPaidMessageStars == nil && !isEditingMessage
            }
            let inputText = strongSelf.presentationInterfaceState.interfaceState.effectiveInputState.inputText

            let cameraPeer: EnginePeer? = strongSelf.presentationInterfaceState.renderedPeer?.peer.map { EnginePeer($0) }
            presentedLegacyCamera(context: strongSelf.context, peer: cameraPeer, chatLocation: strongSelf.chatLocation, cameraView: cameraView, menuController: nil, parentController: strongSelf, attachmentController: self?.attachmentController, editingMedia: isEditingMessage, saveCapturedPhotos: storeCapturedMedia, mediaGrouping: !isEditingMessage, initialCaption: inputText, hasSchedule: hasSchedule, enablePhoto: enablePhoto, enableVideo: enableVideo, sendPaidMessageStars: strongSelf.presentationInterfaceState.sendPaidMessageStars?.value ?? 0, sendMessagesWithSignals: { [weak self] signals, silentPosting, scheduleTime, parameters in
                if let strongSelf = self {
                    if isEditingMessage {
                        if let signals {
                            strongSelf.editMessageMediaWithLegacySignals(signals)
                        }
                    } else {
                        strongSelf.enqueueMediaMessages(signals: signals, silentPosting: silentPosting, scheduleTime: scheduleTime > 0 ? scheduleTime : nil, parameters: parameters)
                    }
                    if !inputText.string.isEmpty {
                        strongSelf.clearInputText()
                    }
                }
            }, recognizedQRCode: { [weak self] code in
                if let strongSelf = self {
                    if let webSettings = parseWebProxySettingsLink(code), case let .web(secret, path) = webSettings.connection {
                        strongSelf.openResolved(result: ResolvedUrl.webProxy(host: webSettings.host, path: path, secret: secret), sourceMessageId: nil)
                    } else if let (host, port, username, password, secret) = parseProxyUrl(sharedContext: strongSelf.context.sharedContext, url: code) {
                        strongSelf.openResolved(result: ResolvedUrl.proxy(host: host, port: port, username: username, password: password, secret: secret), sourceMessageId: nil)
                    }
                }
            }, presentSchedulePicker: { [weak self] _, done in
                if let strongSelf = self {
                    strongSelf.presentScheduleTimePicker(style: .media, presentInOverlay: true, completion: { [weak self] result in
                        if let strongSelf = self {
                            done(result.time, result.silentPosting)
                            if strongSelf.presentationInterfaceState.subject != .scheduledMessages && result.time != scheduleWhenOnlineTimestamp {
                                strongSelf.openScheduledMessages()
                            }
                        }
                    })
                }
            }, presentTimerPicker: { [weak self] done in
                if let strongSelf = self {
                    strongSelf.presentTimerPicker(style: .media, completion: { time in
                        done(time)
                    })
                }
            }, getCaptionPanelView: { [weak self] in
                return self?.getCaptionPanelView(isFile: false)
            }, photoToolbarView: { [context = strongSelf.context] backButton, doneButton, solidBackground, hasSendStarsButton in
                return makeMediaPickerPhotoToolbarView(context: context, backButton: backButton, doneButton: doneButton, solidBackground: solidBackground, hasSendStarsButton: hasSendStarsButton)
            }, dismissedWithResult: { [weak self] in
                self?.attachmentController?.dismiss(animated: false, completion: nil)
            }, finishedTransitionIn: { [weak self] in
                self?.attachmentController?.scrollToTop?()
            })
        })
    }

    func openStickerEditor() {
        self.chatDisplayNode.dismissInput()

        var dismissImpl: (() -> Void)?
        let mainController = self.context.sharedContext.makeStickerMediaPickerScreen(
            context: self.context,
            getSourceRect: { return nil },
            completion: { [weak self] result, transitionView, transitionRect, transitionImage, fromCamera, transitionOut, cancelled in
                guard let self else {
                    return
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
                        default:
                            return nil
                        }
                    }
                } else {
                    subject = .single(.empty(PixelDimensions(width: 1080, height: 1920)))
                }

                let editorController = MediaEditorScreenImpl(
                    context: self.context,
                    mode: .stickerEditor(mode: .generic(canSend: true)),
                    subject: subject,
                    transitionIn: fromCamera ? .camera : transitionView.flatMap({ .gallery(
                        MediaEditorScreenImpl.TransitionIn.GalleryTransitionIn(
                            sourceView: $0,
                            sourceRect: transitionRect,
                            sourceImage: transitionImage
                        )
                    ) }),
                    transitionOut: { finished, isNew in
                        if !finished, let transitionView {
                            return MediaEditorScreenImpl.TransitionOut(
                                destinationView: transitionView,
                                destinationRect: transitionView.bounds,
                                destinationCornerRadius: 0.0
                            )
                        }
                        return nil
                    }, completion: { [weak self] results, commit in
                        dismissImpl?()
                        self?.chatDisplayNode.dismissInput()

                        Queue.mainQueue().after(0.1) {
                            commit({})
                            if case let .sticker(file, _) = results.first?.media {
                                self?.enqueueStickerFile(file)
                            }
                        }
                    } as ([MediaEditorScreenImpl.Result], @escaping (@escaping () -> Void) -> Void) -> Void
                )
                editorController.cancelled = { _ in
                    cancelled()
                }
                editorController.sendSticker = { [weak self] file, sourceView, sourceRect in
                    return self?.interfaceInteraction?.sendSticker(file, true, sourceView, sourceRect, nil, []) ?? false
                }
                self.push(editorController)
            },
            dismissed: {}
        )
        dismissImpl = { [weak mainController] in
            if let mainController, let navigationController = mainController.navigationController {
                var viewControllers = navigationController.viewControllers
                viewControllers = viewControllers.filter { c in
                    return !(c is CameraScreen) && c !== mainController
                }
                navigationController.setViewControllers(viewControllers, animated: false)
            }
        }
        mainController.navigationPresentation = .flatModal
        mainController.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.push(mainController)
    }

    func configurePollCreation(sourceMessageId: EngineMessage.Id? = nil, isQuiz: Bool? = nil) -> ViewController? {
        guard let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return nil
        }
        return ComposePollScreen(
            context: self.context,
            initialData: ComposePollScreen.initialData(context: self.context),
            peer: EnginePeer(peer),
            isQuiz: isQuiz,
            completion: { [weak self] poll in
                guard let self else {
                    return
                }
                self.presentPaidMessageAlertIfNeeded(completion: { [weak self] postpone in
                    guard let self else {
                        return
                    }
                    let replyMessageSubject = sourceMessageId.flatMap {
                        EngineMessageReplySubject(messageId: $0, quote: nil, innerSubject: nil)
                    } ?? self.presentationInterfaceState.interfaceState.replyMessageSubject?.subjectModel
                    self.chatDisplayNode.setupSendActionOnViewUpdate({ [weak self] in
                        if let self {
                            self.chatDisplayNode.collapseInput()

                            self.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil).withUpdatedPostSuggestionState(nil) }
                            })
                        }
                    }, nil)

                    var attributes: [EngineMessage.Attribute] = []
                    if !poll.description.entities.isEmpty {
                        attributes.append(TextEntitiesMessageAttribute(entities: poll.description.entities))
                    }

                    let message: EnqueueMessage = .message(
                        text: poll.description.string,
                        attributes: attributes,
                        inlineStickers: [:],
                        mediaReference: .standalone(media: TelegramMediaPoll(
                            pollId: EngineMedia.Id(namespace: Namespaces.Media.LocalPoll, id: Int64.random(in: Int64.min...Int64.max)),
                            publicity: poll.publicity,
                            kind: poll.kind,
                            text: poll.text.string,
                            textEntities: poll.text.entities,
                            options: poll.options,
                            correctAnswers: poll.correctAnswers,
                            results: poll.results,
                            isClosed: false,
                            deadlineTimeout: poll.deadlineTimeout,
                            deadlineDate: poll.deadlineDate,
                            pollHash: 0,
                            openAnswers: poll.openAnswers,
                            revotingDisabled: poll.revotingDisabled,
                            shuffleAnswers: poll.shuffleAnswers,
                            hideResultsUntilClose: poll.hideResultsUntilClose,
                            isCreator: true,
                            attachedMedia: poll.media?.media,
                            restrictToSubscribers: poll.restrictToSubscribers,
                            countries: poll.limitToCountries
                        )),
                        threadId: self.chatLocation.threadId,
                        replyToMessageId: nil,
                        replyToStoryId: nil,
                        localGroupingKey: nil,
                        correlationId: nil,
                        bubbleUpEmojiOrStickersets: []
                    )
                    self.sendMessages([message.withUpdatedReplyToMessageId(replyMessageSubject)])
                })
            }
        )
    }

    func configureTodoCreation() -> ViewController? {
        guard let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return nil
        }
        return ComposeTodoScreen(
            context: self.context,
            initialData: ComposeTodoScreen.initialData(
                context: self.context
            ),
            peer: EnginePeer(peer),
            completion: { [weak self] todo in
                guard let self else {
                    return
                }
                self.presentPaidMessageAlertIfNeeded(completion: { [weak self] postpone in
                    guard let self else {
                        return
                    }
                    let replyMessageSubject = self.presentationInterfaceState.interfaceState.replyMessageSubject
                    self.chatDisplayNode.setupSendActionOnViewUpdate({ [weak self] in
                        if let self {
                            self.chatDisplayNode.collapseInput()

                            self.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil).withUpdatedPostSuggestionState(nil) }
                            })
                        }
                    }, nil)
                    let message: EnqueueMessage = .message(
                        text: "",
                        attributes: [],
                        inlineStickers: [:],
                        mediaReference: .standalone(media: todo),
                        threadId: self.chatLocation.threadId,
                        replyToMessageId: nil,
                        replyToStoryId: nil,
                        localGroupingKey: nil,
                        correlationId: nil,
                        bubbleUpEmojiOrStickersets: []
                    )
                    self.sendMessages([message.withUpdatedReplyToMessageId(replyMessageSubject?.subjectModel)])
                })
            }
        )
    }

    func openTodoEditing(messageId: EngineMessage.Id, itemId: Int32?, append: Bool) {
        guard let message = self.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId)?._asMessage(), let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return
        }
        guard let existingTodo = message.media.first(where: { $0 is TelegramMediaTodo }) as? TelegramMediaTodo else {
            return
        }

        guard self.context.isPremium else {
            let context = self.context
            var replaceImpl: ((ViewController) -> Void)?
            let demoController = context.sharedContext.makePremiumDemoController(context: context, subject: .todo, forceDark: false, action: {
                let controller = context.sharedContext.makePremiumIntroController(context: context, source: .todo, forceDark: false, dismissed: nil)
                replaceImpl?(controller)
            }, dismissed: nil)
            replaceImpl = { [weak demoController] c in
                demoController?.replace(with: c)
            }
            self.push(demoController)
            return
        }

        let canEdit = canEditMessage(context: self.context, limitsConfiguration: self.context.currentLimitsConfiguration.with { EngineConfiguration.Limits($0) }, message: message)

        let controller = ComposeTodoScreen(
            context: self.context,
            initialData: ComposeTodoScreen.initialData(
                context: self.context,
                existingTodo: existingTodo,
                focusedId: itemId,
                append: append,
                canEdit: canEdit
            ),
            peer: EnginePeer(peer),
            completion: { [weak self] todo in
                guard let self else {
                    return
                }
                func hasSameMetadata(existing: TelegramMediaTodo, updated: TelegramMediaTodo) -> Bool {
                    return existing.flags == updated.flags
                        && existing.text == updated.text
                        && existing.textEntities == updated.textEntities
                }

                func appendedItemsIfOnlyAppended(existing: TelegramMediaTodo, updated: TelegramMediaTodo) -> [TelegramMediaTodo.Item]? {
                    guard hasSameMetadata(existing: existing, updated: updated), updated.items.count > existing.items.count else {
                        return nil
                    }
                    for (index, existingItem) in existing.items.enumerated() {
                        if updated.items[index] != existingItem {
                            return nil
                        }
                    }
                    return Array(updated.items.dropFirst(existing.items.count))
                }

                if hasSameMetadata(existing: existingTodo, updated: todo) && existingTodo.items == todo.items {
                    return
                } else if let appendedItems = appendedItemsIfOnlyAppended(existing: existingTodo, updated: todo) {
                    let _ = self.context.engine.messages.appendTodoMessageItems(messageId: messageId, items: appendedItems).start()
                } else if canEdit {
                    let _ = self.context.engine.messages.requestEditMessage(
                        messageId: messageId,
                        text: "",
                        media: .update(.standalone(media: todo)),
                        entities: nil,
                        richText: nil,
                        inlineStickers: [:]
                    ).start()
                }
            }
        )
        controller.navigationPresentation = .modal
        self.push(controller)
    }
}
