import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import TelegramNotices
import PresentationDataUtils
import TextFormat
import UrlHandling
import AccountContext
import ChatPresentationInterfaceState
import LegacyComponents
import LegacyUI
import AttachmentUI
import MediaPickerUI
import LegacyCamera
import LegacyMediaPickerUI
import LocationUI
import WebSearchUI
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
import ShareController
import ComposeTodoScreen
import ComposePollUI

extension ChatControllerImpl {
    enum AttachMenuSubject {
        case `default`
        case edit(mediaOptions: MessageMediaEditingOptions, mediaReference: AnyMediaReference)
        case bot(id: PeerId, payload: String?, justInstalled: Bool)
        case gift
    }
    
    func presentAttachmentMenu(subject: AttachMenuSubject) {
        guard self.audioRecorderValue == nil && self.videoRecorderValue == nil else {
            return
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
        
        var canSendPolls = true
        var canSendTodos = true
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
        
        var availableButtons: [AttachmentButtonType] = [.gallery, .file]
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
        
        let presentationData = self.presentationData
        
        var isScheduledMessages = false
        if case .scheduledMessages = self.presentationInterfaceState.subject {
            isScheduledMessages = true
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
        if let peer = self.presentationInterfaceState.renderedPeer?.peer, !isScheduledMessages, !peer.isDeleted {
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
                case .edit:
                    break
                case .gift:
                    initialButton = .gift
                default:
                    break
                }
                
                if !isPaidMessages {
                    for bot in attachMenuBots.reversed() {
                        var peerType = peerType
                        if bot.peer.id == peer.id {
                            peerType.insert(.sameBot)
                            peerType.remove(.bot)
                        }
                        let button: AttachmentButtonType = .app(bot)
                        if !bot.peerTypes.intersection(peerType).isEmpty {
                            buttons.insert(button, at: 1)
                            
                            if case let .bot(botId, _, _) = subject {
                                if initialButton == nil && bot.peer.id == botId {
                                    initialButton = button
                                }
                            }
                        }
                        allButtons.insert(button, at: 1)
                    }
                
                    if let user = peer as? TelegramUser, user.botInfo == nil {
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
            if !premiumGiftOptions.isEmpty {
                buttons.insert(.gift, at: 1)
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
                            let controller = webAppTermsAlertController(context: context, updatedPresentationData: strongSelf.updatedPresentationData, bot: bot, completion: { allowWrite in
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
            let currentLocationController = Atomic<LocationPickerController?>(value: nil)
            
            strongSelf.canReadHistory.set(false)
            
            let attachmentController = AttachmentController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, chatLocation: strongSelf.chatLocation, isScheduledMessages: isScheduledMessages, buttons: buttons, initialButton: initialButton, makeEntityInputView: { [weak self] in
                guard let strongSelf = self else {
                    return nil
                }
                return EntityInputView(context: strongSelf.context, isDark: false, areCustomEmojiEnabled: strongSelf.presentationInterfaceState.customEmojiAvailable)
            })
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
                    return
                }
                switch type {
                case .gallery:
                    strongSelf.controllerNavigationDisposable.set(nil)
                    let existingController = currentMediaController.with { $0 }
                    if let controller = existingController {
                        completion(controller, controller.mediaPickerContext)
                        controller.prepareForReuse()
                        return
                    }
                    strongSelf.presentMediaPicker(saveEditedPhotos: dataSettings.storeEditedPhotos, bannedSendPhotos: bannedSendPhotos, bannedSendVideos: bannedSendVideos, enableMultiselection: enableMultiselection, present: { controller, mediaPickerContext in
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
                        self?.enqueueMediaMessages(fromGallery: fromGallery, signals: signals, silentPosting: silentPosting, scheduleTime: scheduleTime, parameters: parameters, getAnimatedTransitionSource: getAnimatedTransitionSource, completion: completion)
                    })
                case .file:
                    strongSelf.controllerNavigationDisposable.set(nil)
                    let existingController = currentFilesController.with { $0 }
                    if let controller = existingController {
                        completion(controller, controller.mediaPickerContext)
                        controller.prepareForReuse()
                        return
                    }
                    let controller = strongSelf.context.sharedContext.makeAttachmentFileController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, bannedSendMedia: bannedSendFiles, presentGallery: { [weak self, weak attachmentController] in
                        attachmentController?.dismiss(animated: true)
                        self?.presentFileGallery()
                    }, presentFiles: { [weak self, weak attachmentController] in
                        attachmentController?.dismiss(animated: true)
                        self?.presentICloudFileGallery()
                    }, send: { [weak self] mediaReference in
                        guard let self else {
                            return
                        }
                        let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: mediaReference, threadId: strongSelf.chatLocation.threadId, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                        self.presentPaidMessageAlertIfNeeded(completion: { [weak self] postpone in
                            self?.sendMessages([message], media: true, postpone: postpone)
                        })
                    })
                    if let controller = controller as? AttachmentFileControllerImpl {
                        let _ = currentFilesController.swap(controller)
                        completion(controller, controller.mediaPickerContext)
                    }
                case .location:
                    strongSelf.controllerNavigationDisposable.set(nil)
                    let existingController = currentLocationController.with { $0 }
                    if let controller = existingController {
                        completion(controller, controller.mediaPickerContext)
                        controller.prepareForReuse()
                        return
                    }
                    let selfPeerId: PeerId
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
                    ;let _ = (strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: selfPeerId))
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
                        let controller = LocationPickerController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, mode: .share(peer: sharePeer, selfPeer: selfPeer, hasLiveLocation: hasLiveLocation), completion: { location, _, _, _, _ in
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
                case .contact:
                    let contactsController = ContactSelectionControllerImpl(ContactSelectionControllerParams(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: { $0.Contacts_Title }, displayDeviceContacts: true, multipleSelection: .always, requirePhoneNumbers: true))
                    contactsController.presentScheduleTimePicker = { [weak self] completion in
                        if let strongSelf = self {
                            strongSelf.presentScheduleTimePicker(completion: completion)
                        }
                    }
                    contactsController.navigationPresentation = .modal
                    completion(contactsController, contactsController.mediaPickerContext)
                    strongSelf.controllerNavigationDisposable.set((contactsController.result
                    |> deliverOnMainQueue).startStrict(next: { [weak self] peers in
                        if let strongSelf = self, let (peers, _, silent, scheduleTime, text, parameters) = peers {
                            var textEnqueueMessage: EnqueueMessage?
                            if let text = text, text.length > 0 {
                                var attributes: [MessageAttribute] = []
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
                                        guard let contact = contact as? TelegramUser, let phoneNumber = contact.phone else {
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
                                let dataSignal: Signal<(Peer?,  DeviceContactExtendedData?), NoError>
                                switch peer {
                                case let .peer(contact, _, _):
                                    guard let contact = contact as? TelegramUser, let phoneNumber = contact.phone else {
                                        return
                                    }
                                    let contactData = DeviceContactExtendedData(basicData: DeviceContactBasicData(firstName: contact.firstName ?? "", lastName: contact.lastName ?? "", phoneNumbers: [DeviceContactPhoneNumberData(label: "_$!<Mobile>!$_", value: phoneNumber)]), middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [], note: "")
                                    let context = strongSelf.context
                                    dataSignal = (strongSelf.context.sharedContext.contactDataManager?.basicData() ?? .single([:]))
                                    |> take(1)
                                    |> mapToSignal { basicData -> Signal<(Peer?,  DeviceContactExtendedData?), NoError> in
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
                                            |> map { extendedData -> (Peer?,  DeviceContactExtendedData?) in
                                                return (contact, extendedData)
                                            }
                                        } else {
                                            return .single((contact, contactData))
                                        }
                                    }
                                case let .deviceContact(id, _):
                                    dataSignal = (strongSelf.context.sharedContext.contactDataManager?.extendedData(stableId: id) ?? .single(nil))
                                    |> take(1)
                                    |> map { extendedData -> (Peer?,  DeviceContactExtendedData?) in
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
                                            var attributes: [MessageAttribute] = []
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
                                            let contactController = strongSelf.context.sharedContext.makeDeviceContactInfoController(context: ShareControllerAppAccountContext(context: strongSelf.context), environment: ShareControllerAppEnvironment(sharedContext: strongSelf.context.sharedContext), subject: .filter(peer: peerAndContactData.0, contactId: nil, contactData: contactData, completion: { peer, contactData in
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
                case .poll:
                    if let controller = strongSelf.configurePollCreation() as? AttachmentContainable {
                        completion(controller, controller.mediaPickerContext)
                        strongSelf.controllerNavigationDisposable.set(nil)
                    }
                case .todo:
                    if strongSelf.context.isPremium {
                        if let controller = strongSelf.configureTodoCreation() as? AttachmentContainable {
                            completion(controller, controller.mediaPickerContext)
                            strongSelf.controllerNavigationDisposable.set(nil)
                        }
                    } else {
                        var replaceImpl: ((ViewController) -> Void)?
                        let demoController = strongSelf.context.sharedContext.makePremiumDemoController(context: strongSelf.context, subject: .todo, forceDark: false, action: {
                            let controller = context.sharedContext.makePremiumIntroController(context: context, source: .todo, forceDark: false, dismissed: nil)
                            replaceImpl?(controller)
                        }, dismissed: nil)
                        replaceImpl = { [weak demoController] c in
                            demoController?.replace(with: c)
                        }
                        strongSelf.push(demoController)
                        Queue.mainQueue().after(0.4) {
                            strongSelf.attachmentController?.dismiss(animated: false)
                        }
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
                            let alertController = webAppTermsAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, bot: bot, completion: { [weak self] allowWrite in
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
                default:
                    break
                }
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
    
    func presentEditingAttachmentMenu(editMediaOptions: MessageMediaEditingOptions?, editMediaReference: AnyMediaReference?) {
        let _ = (self.context.sharedContext.accountManager.transaction { transaction -> GeneratedMediaStoreSettings in
            let entry = transaction.getSharedData(ApplicationSpecificSharedDataKeys.generatedMediaStoreSettings)?.get(GeneratedMediaStoreSettings.self)
            return entry ?? GeneratedMediaStoreSettings.defaultSettings
        }
        |> deliverOnMainQueue).startStandalone(next: { [weak self] settings in
            guard let strongSelf = self else {
                return
            }
            strongSelf.chatDisplayNode.dismissInput()

            var bannedSendMedia: (Int32, Bool)?
            var canSendPolls = true
            if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer {
                if let channel = peer as? TelegramChannel {
                    if let value = channel.hasBannedPermission(.banSendMedia) {
                        bannedSendMedia = value
                    }
                    if channel.hasBannedPermission(.banSendPolls) != nil || channel.isMonoForum {
                        canSendPolls = false
                    }
                } else if let group = peer as? TelegramGroup {
                    if group.hasBannedPermission(.banSendMedia) {
                        bannedSendMedia = (Int32.max, false)
                    }
                    if group.hasBannedPermission(.banSendPolls) {
                        canSendPolls = false
                    }
                }
            }
        
            if editMediaOptions == nil, let (untilDate, personal) = bannedSendMedia {
                let banDescription: String
                if untilDate != 0 && untilDate != Int32.max {
                    banDescription = strongSelf.presentationInterfaceState.strings.Conversation_RestrictedMediaTimed(stringForFullDate(timestamp: untilDate, strings: strongSelf.presentationInterfaceState.strings, dateTimeFormat: strongSelf.presentationInterfaceState.dateTimeFormat)).string
                } else if personal {
                    banDescription = strongSelf.presentationInterfaceState.strings.Conversation_RestrictedMedia
                } else {
                    banDescription = strongSelf.presentationInterfaceState.strings.Conversation_DefaultRestrictedMedia
                }
                
                let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                var items: [ActionSheetItem] = []
                items.append(ActionSheetTextItem(title: banDescription))
                items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_Location, color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    self?.presentLocationPicker()
                }))
                if canSendPolls {
                    items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.AttachmentMenu_Poll, color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        if let controller = self?.configurePollCreation() {
                            self?.effectiveNavigationController?.pushViewController(controller)
                        }
                    }))
                }
                items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_Contact, color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    self?.presentContactPicker()
                }))
                actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])])
                strongSelf.present(actionSheet, in: .window(.root))
                
                return
            }
        
            let legacyController = LegacyController(presentation: .custom, theme: strongSelf.presentationData.theme, initialLayout: strongSelf.validLayout)
            legacyController.blocksBackgroundWhenInOverlay = true
            legacyController.acceptsFocusWhenInOverlay = true
            legacyController.statusBar.statusBarStyle = .Ignore
            legacyController.controllerLoaded = { [weak legacyController] in
                legacyController?.view.disablesInteractiveTransitionGestureRecognizer = true
            }
        
            let emptyController = LegacyEmptyController(context: legacyController.context)!
            let navigationController = makeLegacyNavigationController(rootController: emptyController)
            navigationController.setNavigationBarHidden(true, animated: false)
            legacyController.bind(controller: navigationController)
        
            legacyController.enableSizeClassSignal = true
            
            let inputText = strongSelf.presentationInterfaceState.interfaceState.effectiveInputState.inputText
            let menuEditMediaOptions = editMediaOptions.flatMap { options -> LegacyAttachmentMenuMediaEditing in
                var result: LegacyAttachmentMenuMediaEditing = .none
                if options.contains(.imageOrVideo) {
                    result = .imageOrVideo(editMediaReference)
                }
                return result
            }
            
            var slowModeEnabled = false
            var hasSchedule = false
            if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer {
                if let channel = peer as? TelegramChannel, channel.isRestrictedBySlowmode {
                    slowModeEnabled = true
                }
                hasSchedule = strongSelf.presentationInterfaceState.subject != .scheduledMessages && peer.id.namespace != Namespaces.Peer.SecretChat && strongSelf.presentationInterfaceState.sendPaidMessageStars == nil
            }
            
            let controller = legacyAttachmentMenu(
                context: strongSelf.context,
                peer: strongSelf.presentationInterfaceState.renderedPeer?.peer,
                threadTitle: strongSelf.contentData?.state.threadInfo?.title, chatLocation: strongSelf.chatLocation,
                editMediaOptions: menuEditMediaOptions,
                addingMedia: editMediaOptions == nil,
                saveEditedPhotos: settings.storeEditedPhotos,
                allowGrouping: true,
                hasSchedule: hasSchedule,
                canSendPolls: canSendPolls,
                updatedPresentationData: strongSelf.updatedPresentationData,
                parentController: legacyController,
                recentlyUsedInlineBots: strongSelf.recentlyUsedInlineBotsValue,
                initialCaption: inputText,
                openGallery: {
                    self?.presentOldMediaPicker(fileMode: false, editingMedia: true, completion: { signals, silentPosting, scheduleTime in
                        if !inputText.string.isEmpty {
                            strongSelf.clearInputText()
                        }
                        self?.editMessageMediaWithLegacySignals(signals)
                    })
                }, openCamera: { [weak self] cameraView, menuController in
                    if let strongSelf = self {
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
                        
                        var storeCapturedPhotos = false
                        var hasSchedule = false
                        if let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer {
                            storeCapturedPhotos = peer.id.namespace != Namespaces.Peer.SecretChat
                            
                            hasSchedule = strongSelf.presentationInterfaceState.subject != .scheduledMessages && peer.id.namespace != Namespaces.Peer.SecretChat && strongSelf.presentationInterfaceState.sendPaidMessageStars == nil
                        }
                        
                        presentedLegacyCamera(context: strongSelf.context, peer: strongSelf.presentationInterfaceState.renderedPeer?.peer, chatLocation: strongSelf.chatLocation, cameraView: cameraView, menuController: menuController, parentController: strongSelf, editingMedia: editMediaOptions != nil, saveCapturedPhotos: storeCapturedPhotos, mediaGrouping: true, initialCaption: inputText, hasSchedule: hasSchedule, enablePhoto: enablePhoto, enableVideo: enableVideo, sendMessagesWithSignals: { [weak self] signals, _, _, _ in
                            if let strongSelf = self {
                                strongSelf.editMessageMediaWithLegacySignals(signals!)
                                
                                if !inputText.string.isEmpty {
                                    strongSelf.clearInputText()
                                }
                            }
                        }, recognizedQRCode: { [weak self] code in
                            if let strongSelf = self {
                                if let (host, port, username, password, secret) = parseProxyUrl(sharedContext: strongSelf.context.sharedContext, url: code) {
                                    strongSelf.openResolved(result: ResolvedUrl.proxy(host: host, port: port, username: username, password: password, secret: secret), sourceMessageId: nil)
                                }
                            }
                        }, presentSchedulePicker: { [weak self] _, done in
                            if let strongSelf = self {
                                strongSelf.presentScheduleTimePicker(style: .media, completion: { [weak self] time in
                                    if let strongSelf = self {
                                        done(time)
                                        if strongSelf.presentationInterfaceState.subject != .scheduledMessages && time != scheduleWhenOnlineTimestamp {
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
                        })
                    }
                }, openFileGallery: {
                    self?.presentFileMediaPickerOptions(editingMessage: true)
                }, openWebSearch: { [weak self] in
                    self?.presentWebSearch(editingMessage: editMediaOptions != nil, attachment: false, present: { [weak self] c, a in
                        self?.present(c, in: .window(.root), with: a)
                    })
                }, openMap: {
                    self?.presentLocationPicker()
                }, openContacts: {
                    self?.presentContactPicker()
                }, openPoll: {
                    if let controller = self?.configurePollCreation() {
                        self?.effectiveNavigationController?.pushViewController(controller)
                    }
                }, presentSelectionLimitExceeded: {
                    guard let strongSelf = self else {
                        return
                    }
                    let text: String
                    if slowModeEnabled {
                        text = strongSelf.presentationData.strings.Chat_SlowmodeAttachmentLimitReached
                    } else {
                        text = strongSelf.presentationData.strings.Chat_AttachmentLimitReached
                    }
                    strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                }, presentCantSendMultipleFiles: {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: strongSelf.presentationData.strings.Chat_AttachmentMultipleFilesDisabled, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                }, presentJpegConversionAlert: { completion in
                    strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: strongSelf.presentationData.strings.MediaPicker_JpegConversionText, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.MediaPicker_KeepHeic, action: {
                        completion(false)
                    }), TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.MediaPicker_ConvertToJpeg, action: {
                        completion(true)
                    })], actionLayout: .vertical), in: .window(.root))
                }, presentSchedulePicker: { [weak self] _, done in
                    if let strongSelf = self {
                        strongSelf.presentScheduleTimePicker(style: .media, completion: { [weak self] time in
                            if let strongSelf = self {
                                done(time)
                                if strongSelf.presentationInterfaceState.subject != .scheduledMessages && time != scheduleWhenOnlineTimestamp {
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
                }, sendMessagesWithSignals: { [weak self] signals, silentPosting, scheduleTime, getAnimatedTransitionSource, completion in
                    guard let strongSelf = self else {
                        completion()
                        return
                    }
                    if !inputText.string.isEmpty {
                        strongSelf.clearInputText()
                    }
                    strongSelf.editMessageMediaWithLegacySignals(signals!)
                    completion()
                }, selectRecentlyUsedInlineBot: { [weak self] peer in
                    if let strongSelf = self, let addressName = peer.addressName {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                            $0.updatedInterfaceState({ $0.withUpdatedComposeInputState(ChatTextInputState(inputText: NSAttributedString(string: "@" + addressName + " "))) }).updatedInputMode({ _ in
                                return .text
                            })
                        })
                    }
                }, getCaptionPanelView: { [weak self] in
                    return self?.getCaptionPanelView(isFile: false)
                }, present: { [weak self] c, a in
                    self?.present(c, in: .window(.root), with: a)
                }
            )
            controller.didDismiss = { [weak legacyController] _ in
                legacyController?.dismiss()
            }
            controller.customRemoveFromParentViewController = { [weak legacyController] in
                legacyController?.dismiss()
            }
        
            legacyController.blocksBackgroundWhenInOverlay = true
            strongSelf.present(legacyController, in: .window(.root))
            controller.present(in: emptyController, sourceView: nil, animated: true)
            
            let presentationDisposable = strongSelf.updatedPresentationData.1.startStrict(next: { [weak controller] presentationData in
                if let controller = controller {
                    controller.pallete = legacyMenuPaletteFromTheme(presentationData.theme, forceDark: false)
                }
            })
            legacyController.disposables.add(presentationDisposable)
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
    
    func presentICloudFileGallery(editingMessage: Bool = false) {
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
            
            strongSelf.present(legacyICloudFilePicker(theme: strongSelf.presentationData.theme, completion: { [weak self] urls in
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
                                    if mimeType.hasPrefix("image/") || mimeType == "application/pdf" {
                                        previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 320, height: 320), resource: ICloudFileResource(urlData: item.urlData, thumbnail: true), progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false))
                                    }
                                    var attributes: [TelegramMediaFileAttribute] = []
                                    attributes.append(.FileName(fileName: item.fileName))
                                    if let audioMetadata = item.audioMetadata {
                                        attributes.append(.Audio(isVoice: false, duration: audioMetadata.duration, title: audioMetadata.title, performer: audioMetadata.performer, waveform: nil))
                                    }
                                    
                                    let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: fileId), partialReference: nil, resource: ICloudFileResource(urlData: item.urlData, thumbnail: false), previewRepresentations: previewRepresentations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: mimeType, size: Int64(item.fileSize), attributes: attributes, alternativeRepresentations: [])
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
    
    func presentMediaPicker(subject: MediaPickerScreenImpl.Subject = .assets(nil, .default), saveEditedPhotos: Bool, bannedSendPhotos: (Int32, Bool)?, bannedSendVideos: (Int32, Bool)?, enableMultiselection: Bool, present: @escaping (MediaPickerScreenImpl, AttachmentMediaPickerContext?) -> Void, updateMediaPickerContext: @escaping (AttachmentMediaPickerContext?) -> Void, completion: @escaping (Bool, [Any], Bool, Int32?, ChatSendMessageActionSheetController.SendParameters?, @escaping (String) -> UIView?, @escaping () -> Void) -> Void) {
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
            peer: (self.presentationInterfaceState.renderedPeer?.peer).flatMap(EnginePeer.init),
            threadTitle: self.contentData?.state.threadInfo?.title,
            chatLocation: self.chatLocation,
            isScheduledMessages: isScheduledMessages, 
            bannedSendPhotos: bannedSendPhotos,
            bannedSendVideos: bannedSendVideos,
            enableMultiselection: enableMultiselection,
            canBoostToUnrestrict: (self.presentationInterfaceState.boostsToUnrestrict ?? 0) > 0 && bannedSendPhotos?.1 != true && bannedSendVideos?.1 != true,
            paidMediaAllowed: paidMediaAllowed,
            subject: subject,
            sendPaidMessageStars: self.presentationInterfaceState.sendPaidMessageStars?.value,
            saveEditedPhotos: saveEditedPhotos
        )
        controller.openBoost = { [weak self, weak controller] in
            if let self {
                controller?.dismiss()
                self.interfaceInteraction?.openBoostToUnrestrict()
            }
        }
        let mediaPickerContext = controller.mediaPickerContext
        controller.openCamera = { [weak self] cameraView in
            if let cameraView = cameraView as? TGAttachmentCameraView {
                self?.openCamera(cameraView: cameraView)
            } else {
                self?.openCamera(cameraView: nil)
            }
        }
        controller.presentWebSearch = { [weak self, weak controller] mediaGroups, activateOnDisplay in
            self?.presentWebSearch(editingMessage: false, attachment: true, activateOnDisplay: activateOnDisplay, present: { [weak controller] c, a in
                controller?.present(c, in: .current)
                if let webSearchController = c as? WebSearchController {
                    webSearchController.searchingUpdated = { [weak mediaGroups] searching in
                        if let mediaGroups = mediaGroups, mediaGroups.isNodeLoaded {
                            let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
                            transition.updateAlpha(node: mediaGroups.displayNode, alpha: searching ? 0.0 : 1.0)
                            mediaGroups.displayNode.isUserInteractionEnabled = !searching
                        }
                    }
                    webSearchController.present(mediaGroups, in: .current)
                    webSearchController.dismissed = {
                        updateMediaPickerContext(mediaPickerContext)
                    }
                    controller?.webSearchController = webSearchController
                    updateMediaPickerContext(webSearchController.mediaPickerContext)
                }
            })
        }
        controller.presentSchedulePicker = { [weak self] media, done in
            if let strongSelf = self {
                strongSelf.presentScheduleTimePicker(style: media ? .media : .default, completion: { [weak self] time in
                    if let strongSelf = self {
                        done(time)
                        if strongSelf.presentationInterfaceState.subject != .scheduledMessages && time != scheduleWhenOnlineTimestamp {
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
                                        
                    configureLegacyAssetPicker(controller, context: strongSelf.context, peer: peer, chatLocation: strongSelf.chatLocation, initialCaption: inputText, hasSchedule: strongSelf.presentationInterfaceState.subject != .scheduledMessages && peer.id.namespace != Namespaces.Peer.SecretChat, presentWebSearch: editingMedia ? nil : { [weak self, weak legacyController] in
                        if let strongSelf = self {
                            let controller = WebSearchController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, peer: EnginePeer(peer), chatLocation: strongSelf.chatLocation, configuration: searchBotsConfiguration, mode: .media(attachment: false, completion: { results, selectionState, editingState, silentPosting in
                                if let legacyController = legacyController {
                                    legacyController.dismiss()
                                }
                                legacyEnqueueWebSearchMessages(selectionState, editingState, enqueueChatContextResult: { result in
                                    if let strongSelf = self {
                                        strongSelf.enqueueChatContextResult(results, result, hideVia: true)
                                    }
                                }, enqueueMediaMessages: { signals in
                                    if let strongSelf = self {
                                        if editingMedia {
                                            strongSelf.editMessageMediaWithLegacySignals(signals)
                                        } else {
                                            strongSelf.enqueueMediaMessages(signals: signals, silentPosting: silentPosting)
                                        }
                                    }
                                })
                            }))
                            controller.getCaptionPanelView = { [weak self] in
                                return self?.getCaptionPanelView(isFile: fileMode)
                            }
                            strongSelf.effectiveNavigationController?.pushViewController(controller)
                        }
                    }, presentSelectionLimitExceeded: {
                        guard let strongSelf = self else {
                            return
                        }
                        
                        let text: String
                        if slowModeEnabled {
                            text = strongSelf.presentationData.strings.Chat_SlowmodeAttachmentLimitReached
                        } else {
                            text = strongSelf.presentationData.strings.Chat_AttachmentLimitReached
                        }
                        
                        strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    }, presentSchedulePicker: { [weak self] media, done in
                        if let strongSelf = self {
                            strongSelf.presentScheduleTimePicker(style: media ? .media : .default, completion: { [weak self] time in
                                if let strongSelf = self {
                                     done(time)
                                     if strongSelf.presentationInterfaceState.subject != .scheduledMessages && time != scheduleWhenOnlineTimestamp {
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
    
    func presentWebSearch(editingMessage: Bool, attachment: Bool, activateOnDisplay: Bool = true, present: @escaping (ViewController, Any?) -> Void) {
        guard let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return
        }
        
        let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Configuration.SearchBots())
        |> deliverOnMainQueue).startStandalone(next: { [weak self] configuration in
            if let strongSelf = self {
                let controller = WebSearchController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, peer: EnginePeer(peer), chatLocation: strongSelf.chatLocation, configuration: configuration, mode: .media(attachment: attachment, completion: { [weak self] results, selectionState, editingState, silentPosting in
                    self?.attachmentController?.dismiss(animated: true, completion: nil)
                    legacyEnqueueWebSearchMessages(selectionState, editingState, enqueueChatContextResult: { [weak self] result in
                        if let strongSelf = self {
                            strongSelf.enqueueChatContextResult(results, result, hideVia: true)
                        }
                    }, enqueueMediaMessages: { [weak self] signals in
                        if let strongSelf = self, !signals.isEmpty {
                            if editingMessage {
                                strongSelf.editMessageMediaWithLegacySignals(signals)
                            } else {
                                strongSelf.enqueueMediaMessages(signals: signals, silentPosting: silentPosting)
                            }
                        }
                    })
                }), activateOnDisplay: activateOnDisplay)
                controller.attemptItemSelection = { [weak strongSelf] item in
                    guard let strongSelf, let peer = strongSelf.presentationInterfaceState.renderedPeer?.peer else {
                        return false
                    }
                    
                    enum ItemType {
                        case gif
                        case image
                        case video
                    }
                    
                    var itemType: ItemType?
                    switch item {
                    case let .internalReference(reference):
                        if reference.type == "gif" {
                            itemType = .gif
                        } else if reference.type == "photo" {
                            itemType = .image
                        } else if reference.type == "video" {
                            itemType = .video
                        }
                    case let .externalReference(reference):
                        if reference.type == "gif" {
                            itemType = .gif
                        } else if reference.type == "photo" {
                            itemType = .image
                        } else if reference.type == "video" {
                            itemType = .video
                        }
                    }
                    
                    var bannedSendPhotos: (Int32, Bool)?
                    var bannedSendVideos: (Int32, Bool)?
                    var bannedSendGifs: (Int32, Bool)?
                    
                    if let channel = peer as? TelegramChannel {
                        if let value = channel.hasBannedPermission(.banSendPhotos) {
                            bannedSendPhotos = value
                        }
                        if let value = channel.hasBannedPermission(.banSendVideos) {
                            bannedSendVideos = value
                        }
                        if let value = channel.hasBannedPermission(.banSendGifs) {
                            bannedSendGifs = value
                        }
                    } else if let group = peer as? TelegramGroup {
                        if group.hasBannedPermission(.banSendPhotos) {
                            bannedSendPhotos = (Int32.max, false)
                        }
                        if group.hasBannedPermission(.banSendVideos) {
                            bannedSendVideos = (Int32.max, false)
                        }
                        if group.hasBannedPermission(.banSendGifs) {
                            bannedSendGifs = (Int32.max, false)
                        }
                    }
                    
                    if let itemType {
                        switch itemType {
                        case .image:
                            if bannedSendPhotos != nil {
                                strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: strongSelf.restrictedSendingContentsText(), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                
                                return false
                            }
                        case .video:
                            if bannedSendVideos != nil {
                                strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: strongSelf.restrictedSendingContentsText(), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                
                                return false
                            }
                        case .gif:
                            if bannedSendGifs != nil {
                                strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: strongSelf.presentationData), title: nil, text: strongSelf.restrictedSendingContentsText(), actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                
                                return false
                            }
                        }
                    }
                    
                    return true
                }
                controller.getCaptionPanelView = { [weak strongSelf] in
                    return strongSelf?.getCaptionPanelView(isFile: false)
                }
                present(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }
        })
    }
      
    func presentLocationPicker() {
        guard let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return
        }
        let selfPeerId: PeerId
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
            let controller = LocationPickerController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, mode: .share(peer: EnginePeer(peer), selfPeer: selfPeer, hasLiveLocation: hasLiveLocation), completion: { [weak self] location, _, _, _, _ in
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
                                guard let contact = contact as? TelegramUser, let phoneNumber = contact.phone else {
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
                    let dataSignal: Signal<(Peer?,  DeviceContactExtendedData?), NoError>
                    switch peer {
                        case let .peer(contact, _, _):
                            guard let contact = contact as? TelegramUser, let phoneNumber = contact.phone else {
                                return
                            }
                            let contactData = DeviceContactExtendedData(basicData: DeviceContactBasicData(firstName: contact.firstName ?? "", lastName: contact.lastName ?? "", phoneNumbers: [DeviceContactPhoneNumberData(label: "_$!<Mobile>!$_", value: phoneNumber)]), middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [], note: "")
                            let context = strongSelf.context
                            dataSignal = (strongSelf.context.sharedContext.contactDataManager?.basicData() ?? .single([:]))
                            |> take(1)
                            |> mapToSignal { basicData -> Signal<(Peer?,  DeviceContactExtendedData?), NoError> in
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
                                    |> map { extendedData -> (Peer?,  DeviceContactExtendedData?) in
                                        return (contact, extendedData)
                                    }
                                } else {
                                    return .single((contact, contactData))
                                }
                            }
                        case let .deviceContact(id, _):
                            dataSignal = (strongSelf.context.sharedContext.contactDataManager?.extendedData(stableId: id) ?? .single(nil))
                            |> take(1)
                            |> map { extendedData -> (Peer?,  DeviceContactExtendedData?) in
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
                                let contactController = strongSelf.context.sharedContext.makeDeviceContactInfoController(context: ShareControllerAppAccountContext(context: strongSelf.context), environment: ShareControllerAppEnvironment(sharedContext: strongSelf.context.sharedContext), subject: .filter(peer: peerAndContactData.0, contactId: nil, contactData: contactData, completion: { peer, contactData in
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
    
    func getCaptionPanelView(isFile: Bool) -> TGCaptionPanelView? {
        var isScheduledMessages = false
        if case .scheduledMessages = self.presentationInterfaceState.subject {
            isScheduledMessages = true
        }
        return self.context.sharedContext.makeGalleryCaptionPanelView(context: self.context, chatLocation: self.presentationInterfaceState.chatLocation, isScheduledMessages: isScheduledMessages, isFile: isFile, customEmojiAvailable: self.presentationInterfaceState.customEmojiAvailable, present: { [weak self] c in
            self?.present(c, in: .window(.root))
        }, presentInGlobalOverlay: { [weak self] c in
            guard let self else {
                return
            }
            self.presentInGlobalOverlay(c)
        }) as? TGCaptionPanelView
    }
    
    func openCamera(cameraView: TGAttachmentCameraView? = nil) {
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
                hasSchedule = strongSelf.presentationInterfaceState.subject != .scheduledMessages && peer.id.namespace != Namespaces.Peer.SecretChat && strongSelf.presentationInterfaceState.sendPaidMessageStars == nil
            }
            let inputText = strongSelf.presentationInterfaceState.interfaceState.effectiveInputState.inputText
            
            presentedLegacyCamera(context: strongSelf.context, peer: strongSelf.presentationInterfaceState.renderedPeer?.peer, chatLocation: strongSelf.chatLocation, cameraView: cameraView, menuController: nil, parentController: strongSelf, attachmentController: self?.attachmentController, editingMedia: false, saveCapturedPhotos: storeCapturedMedia, mediaGrouping: true, initialCaption: inputText, hasSchedule: hasSchedule, enablePhoto: enablePhoto, enableVideo: enableVideo, sendPaidMessageStars: strongSelf.presentationInterfaceState.sendPaidMessageStars?.value ?? 0, sendMessagesWithSignals: { [weak self] signals, silentPosting, scheduleTime, parameters in
                if let strongSelf = self {
                    strongSelf.enqueueMediaMessages(signals: signals, silentPosting: silentPosting, scheduleTime: scheduleTime > 0 ? scheduleTime : nil, parameters: parameters)
                    if !inputText.string.isEmpty {
                        strongSelf.clearInputText()
                    }
                }
            }, recognizedQRCode: { [weak self] code in
                if let strongSelf = self {
                    if let (host, port, username, password, secret) = parseProxyUrl(sharedContext: strongSelf.context.sharedContext, url: code) {
                        strongSelf.openResolved(result: ResolvedUrl.proxy(host: host, port: port, username: username, password: password, secret: secret), sourceMessageId: nil)
                    }
                }
            }, presentSchedulePicker: { [weak self] _, done in
                if let strongSelf = self {
                    strongSelf.presentScheduleTimePicker(style: .media, completion: { [weak self] time in
                        if let strongSelf = self {
                            done(time)
                            if strongSelf.presentationInterfaceState.subject != .scheduledMessages && time != scheduleWhenOnlineTimestamp {
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
                    mode: .stickerEditor(mode: .generic),
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
    
    func configurePollCreation(isQuiz: Bool? = nil) -> ViewController? {
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
                        mediaReference: .standalone(media: TelegramMediaPoll(
                            pollId: MediaId(namespace: Namespaces.Media.LocalPoll, id: Int64.random(in: Int64.min...Int64.max)),
                            publicity: poll.publicity,
                            kind: poll.kind,
                            text: poll.text.string,
                            textEntities: poll.text.entities,
                            options: poll.options,
                            correctAnswers: poll.correctAnswers,
                            results: poll.results,
                            isClosed: false,
                            deadlineTimeout: poll.deadlineTimeout
                        )),
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
        guard let message = self.chatDisplayNode.historyNode.messageInCurrentHistoryView(messageId), let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return
        }
        guard let existingTodo = message.media.first(where: { $0 is TelegramMediaTodo }) as? TelegramMediaTodo else {
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
                func areItemsOnlyAppended(existing: [TelegramMediaTodo.Item], updated: [TelegramMediaTodo.Item]) -> Bool {
                    guard updated.count >= existing.count else {
                        return false
                    }
                    for (index, existingItem) in existing.enumerated() {
                        if index >= updated.count || updated[index] != existingItem {
                            return false
                        }
                    }
                    return true
                }
                
                if canEdit && !areItemsOnlyAppended(existing: existingTodo.items, updated: todo.items) {
                    let _ = self.context.engine.messages.requestEditMessage(
                        messageId: messageId,
                        text: "",
                        media: .update(.standalone(media: todo)),
                        entities: nil,
                        inlineStickers: [:]
                    ).start()
                } else {
                    let appendedItems = Array(todo.items[existingTodo.items.count ..< todo.items.count])
                    let _ = self.context.engine.messages.appendTodoMessageItems(messageId: messageId, items: appendedItems).start()
                }
            }
        )
        controller.navigationPresentation = .modal
        self.push(controller)
    }
}
