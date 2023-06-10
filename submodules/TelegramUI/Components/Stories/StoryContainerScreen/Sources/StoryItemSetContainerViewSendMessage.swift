import Foundation
import SwiftSignalKit
import TelegramCore
import AccountContext
import Display
import ComponentFlow
import MessageInputPanelComponent
import UndoUI
import AttachmentUI
import TelegramUIPreferences
import MediaPickerUI
import LegacyMediaPickerUI
import LocationUI
import ChatEntityKeyboardInputNode
import WebUI
import ChatScheduleTimeController
import TextFormat
import PhoneNumberFormat
import ComposePollUI
import TelegramIntents
import LegacyUI
import WebSearchUI
import ChatTimerScreen
import PremiumUI
import ICloudResources
import LegacyComponents
import LegacyCamera
import StoryFooterPanelComponent
import TelegramPresentationData
import LegacyInstantVideoController
import TelegramPresentationData
import ShareController
import ChatPresentationInterfaceState
import Postbox

final class StoryItemSetContainerSendMessage {
    weak var attachmentController: AttachmentController?
    weak var shareController: ShareController?
    
    var audioRecorderValue: ManagedAudioRecorder?
    var audioRecorder = Promise<ManagedAudioRecorder?>()
    var recordedAudioPreview: ChatRecordedMediaPreview?
    
    var videoRecorderValue: InstantVideoController?
    var tempVideoRecorderValue: InstantVideoController?
    var videoRecorder = Promise<InstantVideoController?>()
    let controllerNavigationDisposable = MetaDisposable()
    let enqueueMediaMessageDisposable = MetaDisposable()
    
    private(set) var isMediaRecordingLocked: Bool = false
    var wasRecordingDismissed: Bool = false
    
    deinit {
        self.controllerNavigationDisposable.dispose()
        self.enqueueMediaMessageDisposable.dispose()
    }
    
    func performSendMessageAction(
        view: StoryItemSetContainerComponent.View
    ) {
        guard let component = view.component else {
            return
        }
        let focusedItem = component.slice.item
        guard let peerId = focusedItem.peerId else {
            return
        }
        let focusedStoryId = StoryId(peerId: peerId, id: focusedItem.storyItem.id)
        guard let inputPanelView = view.inputPanel.view as? MessageInputPanelComponent.View else {
            return
        }
        
        if let recordedAudioPreview = self.recordedAudioPreview {
            self.recordedAudioPreview = nil
            
            let waveformBuffer = recordedAudioPreview.waveform.makeBitstream()
            
            let messages: [EnqueueMessage] = [.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: Int64.random(in: Int64.min ... Int64.max)), partialReference: nil, resource: recordedAudioPreview.resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: Int64(recordedAudioPreview.fileSize), attributes: [.Audio(isVoice: true, duration: Int(recordedAudioPreview.duration), title: nil, performer: nil, waveform: waveformBuffer)])), replyToMessageId: nil, replyToStoryId: focusedStoryId, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])]
            
            let _ = enqueueMessages(account: component.context.account, peerId: peerId, messages: messages).start()
            
            view.state?.updated(transition: Transition(animation: .curve(duration: 0.3, curve: .spring)))
        } else {
            switch inputPanelView.getSendMessageInput() {
            case let .text(text):
                if !text.isEmpty {
                    component.context.engine.messages.enqueueOutgoingMessage(
                        to: peerId,
                        replyTo: nil,
                        storyId: StoryId(peerId: component.slice.peer.id, id: component.slice.item.storyItem.id),
                        content: .text(text)
                    )
                    inputPanelView.clearSendMessageInput()
                    view.endEditing(true)
                    
                    if let controller = component.controller() {
                        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                        controller.present(UndoOverlayController(
                            presentationData: presentationData,
                            content: .succeed(text: "Message Sent"),
                            elevatedLayout: false,
                            animateInAsReplacement: false,
                            action: { _ in return false }
                        ), in: .current)
                    }
                }
            }
        }
    }
    
    func setMediaRecordingActive(
        view: StoryItemSetContainerComponent.View,
        isActive: Bool,
        isVideo: Bool,
        sendAction: Bool
    ) {
        self.isMediaRecordingLocked = false
        
        guard let component = view.component else {
            return
        }
        let focusedItem = component.slice.item
        guard let peerId = focusedItem.peerId else {
            return
        }
        let focusedStoryId = StoryId(peerId: peerId, id: focusedItem.storyItem.id)
        let _ = (component.context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
        )
        |> deliverOnMainQueue).start(next: { [weak view] peer in
            guard let view, let component = view.component, let peer else {
                return
            }
            
            if isActive {
                if isVideo {
                    if self.videoRecorderValue == nil {
                        if let currentInputPanelFrame = view.inputPanel.view?.frame {
                            self.videoRecorder.set(.single(legacyInstantVideoController(theme: component.theme, panelFrame: view.convert(currentInputPanelFrame, to: nil), context: component.context, peerId: peer.id, slowmodeState: nil, hasSchedule: peer.id.namespace != Namespaces.Peer.SecretChat, send: { [weak self, weak view] videoController, message in
                                guard let self, let view, let component = view.component else {
                                    return
                                }
                                guard let message = message else {
                                    self.videoRecorder.set(.single(nil))
                                    return
                                }

                                let correlationId = Int64.random(in: 0 ..< Int64.max)
                                let updatedMessage = message
                                    .withUpdatedCorrelationId(correlationId)

                                self.videoRecorder.set(.single(nil))

                                self.sendMessages(view: view, peer: peer, messages: [updatedMessage])
                                
                                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                                view.component?.controller()?.present(UndoOverlayController(
                                    presentationData: presentationData,
                                    content: .succeed(text: "Message Sent"),
                                    elevatedLayout: false,
                                    animateInAsReplacement: false,
                                    action: { _ in return false }
                                ), in: .current)
                            }, displaySlowmodeTooltip: { [weak self] view, rect in
                                //self?.interfaceInteraction?.displaySlowmodeTooltip(view, rect)
                                let _ = self
                            }, presentSchedulePicker: { [weak self, weak view] done in
                                guard let self, let view else {
                                    return
                                }
                                self.presentScheduleTimePicker(view: view, peer: peer, completion: { time in
                                    done(time)
                                })
                            })))
                        }
                    }
                } else {
                    if self.audioRecorderValue == nil {
                        self.audioRecorder.set(component.context.sharedContext.mediaManager.audioRecorder(beginWithTone: false, applicationBindings: component.context.sharedContext.applicationBindings, beganWithTone: { _ in
                        }))
                    }
                }
            } else {
                if let audioRecorderValue = self.audioRecorderValue {
                    let _ = (audioRecorderValue.takenRecordedData()
                    |> deliverOnMainQueue).start(next: { [weak self, weak view] data in
                        guard let self, let view, let component = view.component else {
                            return
                        }
                        
                        self.wasRecordingDismissed = !sendAction
                        self.audioRecorder.set(.single(nil))
                        
                        guard let data else {
                            return
                        }
                        
                        if data.duration < 0.5 || !sendAction {
                            HapticFeedback().error()
                        } else {
                            let randomId = Int64.random(in: Int64.min ... Int64.max)
                            
                            let resource = LocalFileMediaResource(fileId: randomId)
                            component.context.account.postbox.mediaBox.storeResourceData(resource.id, data: data.compressedData)
                            
                            let waveformBuffer: Data? = data.waveform
                            
                            self.sendMessages(view: view, peer: peer, messages: [.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: randomId), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: Int64(data.compressedData.count), attributes: [.Audio(isVoice: true, duration: Int(data.duration), title: nil, performer: nil, waveform: waveformBuffer)])), replyToMessageId: nil, replyToStoryId: focusedStoryId, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])])
                            
                            HapticFeedback().tap()
                            
                            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                            view.component?.controller()?.present(UndoOverlayController(
                                presentationData: presentationData,
                                content: .succeed(text: "Message Sent"),
                                elevatedLayout: false,
                                animateInAsReplacement: false,
                                action: { _ in return false }
                            ), in: .current)
                        }
                    })
                } else if let videoRecorderValue = self.videoRecorderValue {
                    let _ = videoRecorderValue
                    self.videoRecorder.set(.single(nil))
                }
            }
        })
    }
    
    func lockMediaRecording() {
        self.isMediaRecordingLocked = true
    }
    
    func stopMediaRecording(view: StoryItemSetContainerComponent.View) {
        if let audioRecorderValue = self.audioRecorderValue {
            let _ = (audioRecorderValue.takenRecordedData() |> deliverOnMainQueue).start(next: { [weak self, weak view] data in
                guard let self, let view, let component = view.component else {
                    return
                }
                self.audioRecorder.set(.single(nil))
                
                guard let data else {
                    return
                }
                if data.duration < 0.5 {
                    HapticFeedback().error()
                } else if let waveform = data.waveform {
                    let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max), size: Int64(data.compressedData.count))
                    
                    component.context.account.postbox.mediaBox.storeResourceData(resource.id, data: data.compressedData)
                    self.recordedAudioPreview = ChatRecordedMediaPreview(resource: resource, duration: Int32(data.duration), fileSize: Int32(data.compressedData.count), waveform: AudioWaveform(bitstream: waveform, bitsPerSample: 5))
                    view.state?.updated(transition: Transition(animation: .curve(duration: 0.3, curve: .spring)))
                }
            })
        } else if let videoRecorderValue = self.videoRecorderValue {
            if videoRecorderValue.stopVideo() {
                /*self.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                    $0.updatedInputTextPanelState { panelState in
                        return panelState.withUpdatedMediaRecordingState(.video(status: .editing, isLocked: false))
                    }
                })*/
            } else {
                self.videoRecorder.set(.single(nil))
            }
        }
    }
    
    func discardMediaRecordingPreview(view: StoryItemSetContainerComponent.View) {
        if self.recordedAudioPreview != nil {
            self.recordedAudioPreview = nil
            self.wasRecordingDismissed = true
            view.state?.updated(transition: Transition(animation: .curve(duration: 0.3, curve: .spring)))
        }
    }
    
    func performShareAction(view: StoryItemSetContainerComponent.View) {
        guard let component = view.component else {
            return
        }
        guard let controller = component.controller() else {
            return
        }
        let focusedItem = component.slice.item
        guard let peerId = focusedItem.peerId else {
            return
        }
        
        /*let linkPromise = Promise<String?, NoError>()
        linkPromise.set(component.context.engine.messages.exportStoryLink(peerId: peerId, id: focusedItem.storyItem.id))*/
        
        let shareController = ShareController(
            context: component.context,
            subject: .media(AnyMediaReference.standalone(media: TelegramMediaStory(storyId: StoryId(peerId: peerId, id: focusedItem.storyItem.id)))),
            externalShare: false,
            immediateExternalShare: false,
            updatedPresentationData: (component.context.sharedContext.currentPresentationData.with({ $0 }),
            component.context.sharedContext.presentationData)
        )
        
        self.shareController = shareController
        view.updateIsProgressPaused()
        
        shareController.dismissed = { [weak self, weak view] _ in
            guard let self, let view else {
                return
            }
            self.shareController = nil
            view.updateIsProgressPaused()
        }
        
        controller.present(shareController, in: .window(.root))
    }
    
    private func clearInputText(view: StoryItemSetContainerComponent.View) {
        guard let inputPanelView = view.inputPanel.view as? MessageInputPanelComponent.View else {
            return
        }
        inputPanelView.clearSendMessageInput()
    }
    
    enum AttachMenuSubject {
        case `default`
    }
    
    func presentAttachmentMenu(
        view: StoryItemSetContainerComponent.View,
        subject: AttachMenuSubject
    ) {
        guard let component = view.component else {
            return
        }
        let focusedItem = component.slice.item
        guard let peerId = focusedItem.peerId else {
            return
        }
        let focusedStoryId = StoryId(peerId: peerId, id: focusedItem.storyItem.id)
        guard let inputPanelView = view.inputPanel.view as? MessageInputPanelComponent.View else {
            return
        }
        
        var inputText = NSAttributedString(string: "")
        switch inputPanelView.getSendMessageInput() {
        case let .text(text):
            inputText = NSAttributedString(string: text)
        }
        
        let _ = (component.context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
        )
        |> deliverOnMainQueue).start(next: { [weak self, weak view] peer in
            guard let self, let view, let component = view.component else {
                return
            }
            guard let peer else {
                return
            }
            
            let inputIsActive = !"".isEmpty
            
            view.endEditing(true)
                    
            var banSendText: (Int32, Bool)?
            var bannedSendPhotos: (Int32, Bool)?
            var bannedSendVideos: (Int32, Bool)?
            var bannedSendFiles: (Int32, Bool)?
            
            let _ = bannedSendFiles
            
            var canSendPolls = true
            if case let .user(peer) = peer, peer.botInfo == nil {
                canSendPolls = false
            } else if case .secretChat = peer {
                canSendPolls = false
            } else if case let .channel(channel) = peer {
                if let value = channel.hasBannedPermission(.banSendPhotos) {
                    bannedSendPhotos = value
                }
                if let value = channel.hasBannedPermission(.banSendVideos) {
                    bannedSendVideos = value
                }
                if let value = channel.hasBannedPermission(.banSendFiles) {
                    bannedSendFiles = value
                }
                if let value = channel.hasBannedPermission(.banSendText) {
                    banSendText = value
                }
                if channel.hasBannedPermission(.banSendPolls) != nil {
                    canSendPolls = false
                }
            } else if case let .legacyGroup(group) = peer {
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
            
            var availableButtons: [AttachmentButtonType] = [.gallery, .file]
            if banSendText == nil {
                availableButtons.append(.location)
                availableButtons.append(.contact)
            }
            if canSendPolls {
                availableButtons.insert(.poll, at: max(0, availableButtons.count - 1))
            }
            
            let isScheduledMessages = !"".isEmpty
            
            var peerType: AttachMenuBots.Bot.PeerFlags = []
            if case let .user(user) = peer {
                if let _ = user.botInfo {
                    peerType.insert(.bot)
                } else {
                    peerType.insert(.user)
                }
            } else if case .legacyGroup = peer {
                peerType = .group
            } else if case let .channel(channel) = peer {
                if case .broadcast = channel.info {
                    peerType = .channel
                } else {
                    peerType = .group
                }
            }
            
            let buttons: Signal<([AttachmentButtonType], [AttachmentButtonType], AttachmentButtonType?), NoError>
            if !isScheduledMessages {
                buttons = component.context.engine.messages.attachMenuBots()
                |> map { attachMenuBots in
                    var buttons = availableButtons
                    var allButtons = availableButtons
                    var initialButton: AttachmentButtonType?
                    switch subject {
                    case .default:
                        initialButton = .gallery
                    /*case .edit:
                        break
                    case .gift:
                        initialButton = .gift*/
                    }
                    
                    if !"".isEmpty {
                        for bot in attachMenuBots.reversed() {
                            var peerType = peerType
                            if bot.peer.id == peer.id {
                                peerType.insert(.sameBot)
                                peerType.remove(.bot)
                            }
                            let button: AttachmentButtonType = .app(bot.peer, bot.shortName, bot.icons)
                            if !bot.peerTypes.intersection(peerType).isEmpty {
                                buttons.insert(button, at: 1)
                                
                                /*if case let .bot(botId, _, _) = subject {
                                 if initialButton == nil && bot.peer.id == botId {
                                 initialButton = button
                                 }
                                 }*/
                            }
                            allButtons.insert(button, at: 1)
                        }
                    }
                    
                    return (buttons, allButtons, initialButton)
                }
            } else {
                buttons = .single((availableButtons, availableButtons, .gallery))
            }
                        
            let dataSettings = component.context.sharedContext.accountManager.transaction { transaction -> GeneratedMediaStoreSettings in
                let entry = transaction.getSharedData(ApplicationSpecificSharedDataKeys.generatedMediaStoreSettings)?.get(GeneratedMediaStoreSettings.self)
                return entry ?? GeneratedMediaStoreSettings.defaultSettings
            }
            
            let premiumConfiguration = PremiumConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
            let premiumGiftOptions: [CachedPremiumGiftOption]
            if !premiumConfiguration.isPremiumDisabled && premiumConfiguration.showPremiumGiftInAttachMenu, case let .user(user) = peer, !user.isPremium && !user.isDeleted && user.botInfo == nil && !user.flags.contains(.isSupport) {
                premiumGiftOptions = []//self.presentationInterfaceState.premiumGiftOptions
                //TODO:premium gift options
            } else {
                premiumGiftOptions = []
            }
            
            let _ = combineLatest(queue: Queue.mainQueue(), buttons, dataSettings).start(next: { [weak self, weak view] buttonsAndInitialButton, dataSettings in
                guard let self, let view, let component = view.component else {
                    return
                }
                
                var (buttons, allButtons, initialButton) = buttonsAndInitialButton
                if !premiumGiftOptions.isEmpty {
                    buttons.insert(.gift, at: 1)
                }
                let _ = allButtons
                
                guard let initialButton = initialButton else {
                    return
                }
                
                let currentMediaController = Atomic<MediaPickerScreen?>(value: nil)
                let currentFilesController = Atomic<AttachmentFileController?>(value: nil)
                let currentLocationController = Atomic<LocationPickerController?>(value: nil)
                
                let theme = component.theme
                let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>) = (component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: theme), component.context.sharedContext.presentationData |> map { $0.withUpdated(theme: theme) })
                
                let attachmentController = AttachmentController(
                    context: component.context,
                    updatedPresentationData: updatedPresentationData,
                    chatLocation: .peer(id: peer.id),
                    buttons: buttons,
                    initialButton: initialButton,
                    makeEntityInputView: { [weak view] in
                        guard let view, let component = view.component else {
                            return nil
                        }
                        return EntityInputView(
                            context: component.context,
                            isDark: true,
                            areCustomEmojiEnabled: true //TODO:check custom emoji
                        )
                    }
                )
                attachmentController.didDismiss = { [weak self, weak view] in
                    guard let self, let view else {
                        return
                    }
                    self.attachmentController = nil
                    view.updateIsProgressPaused()
                }
                attachmentController.getSourceRect = { [weak view] in
                    guard let view else {
                        return nil
                    }
                    guard let inputPanelView = view.inputPanel.view as? MessageInputPanelComponent.View else {
                        return nil
                    }
                    guard let attachmentButtonView = inputPanelView.getAttachmentButtonView() else {
                        return nil
                    }
                    return attachmentButtonView.convert(attachmentButtonView.bounds, to: nil)
                }
                attachmentController.requestController = { [weak self, weak view, weak attachmentController] type, completion in
                    guard let self, let view, let component = view.component else {
                        return
                    }
                    switch type {
                    case .gallery:
                        self.controllerNavigationDisposable.set(nil)
                        let existingController = currentMediaController.with { $0 }
                        if let controller = existingController {
                            completion(controller, controller.mediaPickerContext)
                            controller.prepareForReuse()
                            return
                        }
                        self.presentMediaPicker(
                            view: view,
                            peer: peer,
                            replyToMessageId: nil,
                            replyToStoryId: focusedStoryId,
                            saveEditedPhotos: dataSettings.storeEditedPhotos,
                            bannedSendPhotos: bannedSendPhotos,
                            bannedSendVideos: bannedSendVideos,
                            present: { controller, mediaPickerContext in
                                let _ = currentMediaController.swap(controller)
                                if !inputText.string.isEmpty {
                                    mediaPickerContext?.setCaption(inputText)
                                }
                                completion(controller, mediaPickerContext)
                            }, updateMediaPickerContext: { [weak attachmentController] mediaPickerContext in
                                attachmentController?.mediaPickerContext = mediaPickerContext
                            }, completion: { [weak self, weak view] signals, silentPosting, scheduleTime, getAnimatedTransitionSource, completion in
                                guard let self, let view else {
                                    return
                                }
                                if !inputText.string.isEmpty {
                                    self.clearInputText(view: view)
                                }
                                self.enqueueMediaMessages(view: view, peer: peer, replyToMessageId: nil, replyToStoryId: focusedStoryId, signals: signals, silentPosting: silentPosting, scheduleTime: scheduleTime, getAnimatedTransitionSource: getAnimatedTransitionSource, completion: completion)
                            }
                        )
                    case .file:
                        self.controllerNavigationDisposable.set(nil)
                        let existingController = currentFilesController.with { $0 }
                        if let controller = existingController as? AttachmentContainable, let mediaPickerContext = controller.mediaPickerContext {
                            completion(controller, mediaPickerContext)
                            controller.prepareForReuse()
                            return
                        }
                        let theme = component.theme
                        let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>) = (component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: theme), component.context.sharedContext.presentationData |> map { $0.withUpdated(theme: theme) })
                        
                        let controller = component.context.sharedContext.makeAttachmentFileController(context: component.context, updatedPresentationData: updatedPresentationData, bannedSendMedia: bannedSendFiles, presentGallery: { [weak self, weak view, weak attachmentController] in
                            guard let self, let view else {
                                return
                            }
                            attachmentController?.dismiss(animated: true)
                            self.presentFileGallery(view: view, peer: peer, replyMessageId: nil, replyToStoryId: focusedStoryId)
                        }, presentFiles: { [weak self, weak view, weak attachmentController] in
                            guard let self, let view else {
                                return
                            }
                            attachmentController?.dismiss(animated: true)
                            self.presentICloudFileGallery(view: view, peer: peer, replyMessageId: nil, replyToStoryId: focusedStoryId)
                        }, send: { [weak view] mediaReference in
                            guard let view, let component = view.component else {
                                return
                            }
                            let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: mediaReference, replyToMessageId: nil, replyToStoryId: focusedStoryId, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                            let _ = (enqueueMessages(account: component.context.account, peerId: peer.id, messages: [message.withUpdatedReplyToMessageId(nil)])
                            |> deliverOnMainQueue).start()
                            
                            if let controller = component.controller() {
                                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                                controller.present(UndoOverlayController(
                                    presentationData: presentationData,
                                    content: .succeed(text: "Message Sent"),
                                    elevatedLayout: false,
                                    animateInAsReplacement: false,
                                    action: { _ in return false }
                                ), in: .current)
                            }
                        })
                        let _ = currentFilesController.swap(controller)
                        if let controller = controller as? AttachmentContainable, let mediaPickerContext = controller.mediaPickerContext {
                            completion(controller, mediaPickerContext)
                        }
                    case .location:
                        self.controllerNavigationDisposable.set(nil)
                        let existingController = currentLocationController.with { $0 }
                        if let controller = existingController {
                            completion(controller, controller.mediaPickerContext)
                            controller.prepareForReuse()
                            return
                        }
                        let selfPeerId: EnginePeer.Id
                        if case let .channel(peer) = peer, case .broadcast = peer.info {
                            selfPeerId = peer.id
                        } else if case let .channel(peer) = peer, case .group = peer.info, peer.hasPermission(.canBeAnonymous) {
                            selfPeerId = peer.id
                        } else {
                            selfPeerId = component.context.account.peerId
                        }
                        let _ = (component.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: selfPeerId))
                        |> deliverOnMainQueue).start(next: { [weak self, weak view] selfPeer in
                            guard let self, let view, let component = view.component, let selfPeer else {
                                return
                            }
                            let hasLiveLocation = peer.id.namespace != Namespaces.Peer.SecretChat && peer.id != component.context.account.peerId
                            let theme = component.theme
                            let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>) = (component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: theme), component.context.sharedContext.presentationData |> map { $0.withUpdated(theme: theme) })
                            let controller = LocationPickerController(context: component.context, updatedPresentationData: updatedPresentationData, mode: .share(peer: peer, selfPeer: selfPeer, hasLiveLocation: hasLiveLocation), completion: { [weak self, weak view] location, _ in
                                guard let self, let view else {
                                    return
                                }
                                let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: location), replyToMessageId: nil, replyToStoryId: focusedStoryId, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                                self.sendMessages(view: view, peer: peer, messages: [message])
                            })
                            completion(controller, controller.mediaPickerContext)
                            
                            let _ = currentLocationController.swap(controller)
                        })
                    case .contact:
                        let theme = component.theme
                        let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>) = (component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: theme), component.context.sharedContext.presentationData |> map { $0.withUpdated(theme: theme) })
                        let contactsController = component.context.sharedContext.makeContactSelectionController(ContactSelectionControllerParams(context: component.context, updatedPresentationData: updatedPresentationData, title: { $0.Contacts_Title }, displayDeviceContacts: true, multipleSelection: true))
                        contactsController.presentScheduleTimePicker = { [weak self, weak view] completion in
                            guard let self, let view else {
                                return
                            }
                            self.presentScheduleTimePicker(view: view, peer: peer, completion: completion)
                        }
                        contactsController.navigationPresentation = .modal
                        if let contactsController = contactsController as? AttachmentContainable, let mediaPickerContext = contactsController.mediaPickerContext {
                            completion(contactsController, mediaPickerContext)
                        }
                        self.controllerNavigationDisposable.set((contactsController.result
                        |> deliverOnMainQueue).start(next: { [weak self, weak view] peers in
                            guard let self, let view, let (peers, _, silent, scheduleTime, text) = peers else {
                                return
                            }
                            
                            let targetPeer = peer
                            
                            var textEnqueueMessage: EnqueueMessage?
                            if let text = text, text.length > 0 {
                                var attributes: [EngineMessage.Attribute] = []
                                let entities = generateTextEntities(text.string, enabledTypes: .all, currentEntities: generateChatInputTextEntities(text))
                                if !entities.isEmpty {
                                    attributes.append(TextEntitiesMessageAttribute(entities: entities))
                                }
                                textEnqueueMessage = .message(text: text.string, attributes: attributes, inlineStickers: [:], mediaReference: nil, replyToMessageId: nil, replyToStoryId: focusedStoryId, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
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
                                        let message = EnqueueMessage.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: media), replyToMessageId: nil, replyToStoryId: focusedStoryId, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                                        enqueueMessages.append(message)
                                    }
                                }
                                
                                self.sendMessages(view: view, peer: peer, messages: self.transformEnqueueMessages(view: view, messages: enqueueMessages, silentPosting: silent, scheduleTime: scheduleTime))
                            } else if let peer = peers.first {
                                let dataSignal: Signal<(EnginePeer?, DeviceContactExtendedData?), NoError>
                                switch peer {
                                case let .peer(contact, _, _):
                                    guard let contact = contact as? TelegramUser, let phoneNumber = contact.phone else {
                                        return
                                    }
                                    let contactData = DeviceContactExtendedData(basicData: DeviceContactBasicData(firstName: contact.firstName ?? "", lastName: contact.lastName ?? "", phoneNumbers: [DeviceContactPhoneNumberData(label: "_$!<Mobile>!$_", value: phoneNumber)]), middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [], note: "")
                                    let context = component.context
                                    dataSignal = (component.context.sharedContext.contactDataManager?.basicData() ?? .single([:]))
                                    |> take(1)
                                    |> mapToSignal { basicData -> Signal<(EnginePeer?,  DeviceContactExtendedData?), NoError> in
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
                                            |> map { extendedData -> (EnginePeer?,  DeviceContactExtendedData?) in
                                                return (EnginePeer(contact), extendedData)
                                            }
                                        } else {
                                            return .single((EnginePeer(contact), contactData))
                                        }
                                    }
                                case let .deviceContact(id, _):
                                    dataSignal = (component.context.sharedContext.contactDataManager?.extendedData(stableId: id) ?? .single(nil))
                                    |> take(1)
                                    |> map { extendedData -> (EnginePeer?,  DeviceContactExtendedData?) in
                                        return (nil, extendedData)
                                    }
                                }
                                self.controllerNavigationDisposable.set((dataSignal
                                |> deliverOnMainQueue).start(next: { [weak self, weak view] peerAndContactData in
                                    guard let self, let view, let contactData = peerAndContactData.1, contactData.basicData.phoneNumbers.count != 0 else {
                                        return
                                    }
                                    if contactData.isPrimitive {
                                        let phone = contactData.basicData.phoneNumbers[0].value
                                        let media = TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: peerAndContactData.0?.id, vCardData: nil)
                                        var enqueueMessages: [EnqueueMessage] = []
                                        if let textEnqueueMessage = textEnqueueMessage {
                                            enqueueMessages.append(textEnqueueMessage)
                                        }
                                        enqueueMessages.append(.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: media), replyToMessageId: nil, replyToStoryId: focusedStoryId, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))
                                        
                                        self.sendMessages(view: view, peer: targetPeer, messages: self.transformEnqueueMessages(view: view, messages: enqueueMessages, silentPosting: silent, scheduleTime: scheduleTime))
                                    } else {
                                        let contactController = component.context.sharedContext.makeDeviceContactInfoController(context: component.context, subject: .filter(peer: peerAndContactData.0?._asPeer(), contactId: nil, contactData: contactData, completion: { [weak self, weak view] peer, contactData in
                                            guard let self, let view else {
                                                return
                                            }
                                            if contactData.basicData.phoneNumbers.isEmpty {
                                                return
                                            }
                                            let phone = contactData.basicData.phoneNumbers[0].value
                                            if let vCardData = contactData.serializedVCard() {
                                                let media = TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: peer?.id, vCardData: vCardData)
                                                
                                                var enqueueMessages: [EnqueueMessage] = []
                                                if let textEnqueueMessage = textEnqueueMessage {
                                                    enqueueMessages.append(textEnqueueMessage)
                                                }
                                                enqueueMessages.append(.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: media), replyToMessageId: nil, replyToStoryId: focusedStoryId, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))
                                                
                                                self.sendMessages(view: view, peer: targetPeer, messages: self.transformEnqueueMessages(view: view, messages: enqueueMessages, silentPosting: silent, scheduleTime: scheduleTime))
                                            }
                                        }), completed: nil, cancelled: nil)
                                        component.controller()?.push(contactController)
                                    }
                                }))
                            }
                        }))
                    case .poll:
                        let controller = self.configurePollCreation(view: view, peer: peer, targetMessageId: nil)
                        completion(controller, controller?.mediaPickerContext)
                        self.controllerNavigationDisposable.set(nil)
                    case .gift:
                        /*let premiumGiftOptions = strongSelf.presentationInterfaceState.premiumGiftOptions
                        if !premiumGiftOptions.isEmpty {
                            let controller = PremiumGiftScreen(context: context, peerId: peer.id, options: premiumGiftOptions, source: .attachMenu, pushController: { [weak self] c in
                                if let strongSelf = self {
                                    strongSelf.push(c)
                                }
                            }, completion: { [weak self] in
                                if let strongSelf = self {
                                    strongSelf.hintPlayNextOutgoingGift()
                                    strongSelf.attachmentController?.dismiss(animated: true)
                                }
                            })
                            completion(controller, controller.mediaPickerContext)
                            strongSelf.controllerNavigationDisposable.set(nil)
                            
                            let _ = ApplicationSpecificNotice.incrementDismissedPremiumGiftSuggestion(accountManager: context.sharedContext.accountManager, peerId: peer.id).start()
                        }*/
                        //TODO:gift controller
                        break
                    case let .app(bot, botName, _):
                        var payload: String?
                        var fromAttachMenu = true
                        /*if case let .bot(_, botPayload, _) = subject {
                            payload = botPayload
                            fromAttachMenu = false
                        }*/
                        payload = nil
                        fromAttachMenu = true
                        let params = WebAppParameters(peerId: peer.id, botId: bot.id, botName: botName, url: nil, queryId: nil, payload: payload, buttonText: nil, keepAliveSignal: nil, fromMenu: false, fromAttachMenu: fromAttachMenu, isInline: false, isSimple: false)
                        let theme = component.theme
                        let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>) = (component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: theme), component.context.sharedContext.presentationData |> map { $0.withUpdated(theme: theme) })
                        let controller = WebAppController(context: component.context, updatedPresentationData: updatedPresentationData, params: params, replyToMessageId: nil, threadId: nil)
                        controller.openUrl = { [weak self] url in
                            guard let self else {
                                return
                            }
                            let _ = self
                            //self?.openUrl(url, concealed: true, forceExternal: true)
                        }
                        controller.getNavigationController = { [weak view] in
                            guard let view, let controller = view.component?.controller() else {
                                return nil
                            }
                            return controller.navigationController as? NavigationController
                        }
                        controller.completion = { [weak self] in
                            guard let self else {
                                return
                            }
                            let _ = self
                            /*if let strongSelf = self {
                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                    $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                                })
                                strongSelf.chatDisplayNode.historyNode.scrollToEndOfHistory()
                            }*/
                        }
                        completion(controller, controller.mediaPickerContext)
                        self.controllerNavigationDisposable.set(nil)
                    default:
                        break
                    }
                }
                let present = { [weak self, weak view] in
                    guard let self, let view, let controller = view.component?.controller() else {
                        return
                    }
                    attachmentController.navigationPresentation = .flatModal
                    controller.push(attachmentController)
                    self.attachmentController = attachmentController
                    view.updateIsProgressPaused()
                }
                
                if inputIsActive {
                    Queue.mainQueue().after(0.15, {
                        present()
                    })
                } else {
                    present()
                }
            })
        })
    }
    
    private func presentMediaPicker(
        view: StoryItemSetContainerComponent.View,
        peer: EnginePeer,
        replyToMessageId: EngineMessage.Id?,
        replyToStoryId: StoryId?,
        subject: MediaPickerScreen.Subject = .assets(nil, .default),
        saveEditedPhotos: Bool,
        bannedSendPhotos: (Int32, Bool)?,
        bannedSendVideos: (Int32, Bool)?,
        present: @escaping (MediaPickerScreen, AttachmentMediaPickerContext?) -> Void,
        updateMediaPickerContext: @escaping (AttachmentMediaPickerContext?) -> Void,
        completion: @escaping ([Any], Bool, Int32?, @escaping (String) -> UIView?, @escaping () -> Void) -> Void
    ) {
        guard let component = view.component else {
            return
        }
        let theme = component.theme
        let controller = MediaPickerScreen(context: component.context, updatedPresentationData: (component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: theme), component.context.sharedContext.presentationData |> map { $0.withUpdated(theme: theme) }), peer: peer, threadTitle: nil, chatLocation: .peer(id: peer.id), bannedSendPhotos: bannedSendPhotos, bannedSendVideos: bannedSendVideos, subject: subject, saveEditedPhotos: saveEditedPhotos)
        let mediaPickerContext = controller.mediaPickerContext
        controller.openCamera = { [weak self, weak view] cameraView in
            guard let self, let view else {
                return
            }
            self.openCamera(view: view, peer: peer, replyToMessageId: replyToMessageId, replyToStoryId: replyToStoryId, cameraView: cameraView)
        }
        controller.presentWebSearch = { [weak self, weak view, weak controller] mediaGroups, activateOnDisplay in
            guard let self, let view, let controller else {
                return
            }
            self.presentWebSearch(view: view, editingMessage: false, attachment: true, activateOnDisplay: activateOnDisplay, present: { [weak controller] c, a in
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
        controller.presentSchedulePicker = { [weak self, weak view] media, done in
            guard let self, let view else {
                return
            }
            self.presentScheduleTimePicker(view: view, peer: peer, style: media ? .media : .default, completion: { time in
                done(time)
            })
        }
        controller.presentTimerPicker = { [weak self, weak view] done in
            guard let self, let view else {
                return
            }
            self.presentTimerPicker(view: view, peer: peer, style: .media, completion: { time in
                done(time)
            })
        }
        controller.getCaptionPanelView = { [weak self, weak view] in
            guard let self, let view else {
                return nil
            }
            return self.getCaptionPanelView(view: view, peer: peer)
        }
        controller.legacyCompletion = { signals, silently, scheduleTime, getAnimatedTransitionSource, sendCompletion in
            completion(signals, silently, scheduleTime, getAnimatedTransitionSource, sendCompletion)
        }
        present(controller, mediaPickerContext)
    }
    
    private func presentOldMediaPicker(view: StoryItemSetContainerComponent.View, peer: EnginePeer, replyMessageId: EngineMessage.Id?, replyToStoryId: StoryId?, fileMode: Bool, editingMedia: Bool, present: @escaping (AttachmentContainable, AttachmentMediaPickerContext) -> Void, completion: @escaping ([Any], Bool, Int32) -> Void) {
        guard let component = view.component else {
            return
        }
        guard let inputPanelView = view.inputPanel.view as? MessageInputPanelComponent.View else {
            return
        }
        var inputText = NSAttributedString(string: "")
        switch inputPanelView.getSendMessageInput() {
        case let .text(text):
            inputText = NSAttributedString(string: text)
        }
        
        let engine = component.context.engine
        let _ = (component.context.sharedContext.accountManager.transaction { transaction -> Signal<(GeneratedMediaStoreSettings, EngineConfiguration.SearchBots), NoError> in
            let entry = transaction.getSharedData(ApplicationSpecificSharedDataKeys.generatedMediaStoreSettings)?.get(GeneratedMediaStoreSettings.self)
            
            return engine.data.get(TelegramEngine.EngineData.Item.Configuration.SearchBots())
            |> map { configuration -> (GeneratedMediaStoreSettings, EngineConfiguration.SearchBots) in
                return (entry ?? GeneratedMediaStoreSettings.defaultSettings, configuration)
            }
        }
        |> switchToLatest
        |> deliverOnMainQueue).start(next: { [weak self, weak view] settings, searchBotsConfiguration in
            guard let self, let view, let component = view.component else {
                return
            }
            var selectionLimit: Int = 100
            var slowModeEnabled = false
            if case let .channel(channel) = peer, channel.isRestrictedBySlowmode {
                selectionLimit = 10
                slowModeEnabled = true
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            let _ = legacyAssetPicker(context: component.context, presentationData: presentationData, editingMedia: editingMedia, fileMode: fileMode, peer: peer._asPeer(), threadTitle: nil, saveEditedPhotos: settings.storeEditedPhotos, allowGrouping: true, selectionLimit: selectionLimit).start(next: { [weak self, weak view] generator in
                if let view, let component = view.component, let controller = component.controller() {
                    let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                    
                    let legacyController = LegacyController(presentation: fileMode ? .navigation : .custom, theme: presentationData.theme, initialLayout: controller.currentlyAppliedLayout)
                    legacyController.navigationPresentation = .modal
                    legacyController.statusBar.statusBarStyle = presentationData.theme.rootController.statusBarStyle.style
                    legacyController.controllerLoaded = { [weak legacyController] in
                        legacyController?.view.disablesInteractiveTransitionGestureRecognizer = true
                        legacyController?.view.disablesInteractiveModalDismiss = true
                    }
                    let controller = generator(legacyController.context)
                    
                    legacyController.bind(controller: controller)
                    legacyController.deferScreenEdgeGestures = [.top]
                                        
                    configureLegacyAssetPicker(controller, context: component.context, peer: peer._asPeer(), chatLocation: .peer(id: peer.id), initialCaption: inputText, hasSchedule: peer.id.namespace != Namespaces.Peer.SecretChat, presentWebSearch: editingMedia ? nil : { [weak view, weak legacyController] in
                        if let view, let component = view.component {
                            let theme = component.theme
                            let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>) = (component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: theme), component.context.sharedContext.presentationData |> map { $0.withUpdated(theme: theme) })
                            let controller = WebSearchController(context: component.context, updatedPresentationData: updatedPresentationData, peer: peer, chatLocation: .peer(id: peer.id), configuration: searchBotsConfiguration, mode: .media(attachment: false, completion: { [weak view] results, selectionState, editingState, silentPosting in
                                if let legacyController = legacyController {
                                    legacyController.dismiss()
                                }
                                guard let view else {
                                    return
                                }
                                legacyEnqueueWebSearchMessages(selectionState, editingState, enqueueChatContextResult: { [weak view] result in
                                    if let strongSelf = self, let view {
                                        strongSelf.enqueueChatContextResult(view: view, peer: peer, replyMessageId: replyMessageId, storyId: replyToStoryId, results: results, result: result, hideVia: true)
                                    }
                                }, enqueueMediaMessages: { [weak view] signals in
                                    if let strongSelf = self, let view {
                                        if editingMedia {
                                            strongSelf.editMessageMediaWithLegacySignals(view: view, signals: signals)
                                        } else {
                                            strongSelf.enqueueMediaMessages(view: view, peer: peer, replyToMessageId: replyMessageId, replyToStoryId: replyToStoryId, signals: signals, silentPosting: silentPosting)
                                        }
                                    }
                                })
                            }))
                            controller.getCaptionPanelView = { [weak view] in
                                guard let self, let view else {
                                    return nil
                                }
                                return self.getCaptionPanelView(view: view, peer: peer)
                            }
                            component.controller()?.push(controller)
                        }
                    }, presentSelectionLimitExceeded: { [weak view] in
                        guard let view else {
                            return
                        }
                        
                        let text: String
                        if slowModeEnabled {
                            text = presentationData.strings.Chat_SlowmodeAttachmentLimitReached
                        } else {
                            text = presentationData.strings.Chat_AttachmentLimitReached
                        }
                        
                        view.component?.controller()?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    }, presentSchedulePicker: { [weak view] media, done in
                        if let strongSelf = self, let view {
                            strongSelf.presentScheduleTimePicker(view: view, peer: peer, style: media ? .media : .default, completion: { time in
                                 done(time)
                            })
                        }
                    }, presentTimerPicker: { [weak view] done in
                        if let strongSelf = self, let view {
                            strongSelf.presentTimerPicker(view: view, peer: peer, style: .media, completion: { time in
                                done(time)
                            })
                        }
                    }, getCaptionPanelView: { [weak view] in
                        guard let self, let view else {
                            return nil
                        }
                        return self.getCaptionPanelView(view: view, peer: peer)
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
                    view.endEditing(true)
                    present(legacyController, LegacyAssetPickerContext(controller: controller))
                }
            })
        })
    }
    
    private func presentFileGallery(view: StoryItemSetContainerComponent.View, peer: EnginePeer, replyMessageId: EngineMessage.Id?, replyToStoryId: StoryId?, editingMessage: Bool = false) {
        self.presentOldMediaPicker(view: view, peer: peer, replyMessageId: replyMessageId, replyToStoryId: replyToStoryId, fileMode: true, editingMedia: editingMessage, present: { [weak view] c, _ in
            view?.component?.controller()?.push(c)
        }, completion: { [weak self, weak view] signals, silentPosting, scheduleTime in
            guard let self, let view else {
                return
            }
            if editingMessage {
                self.editMessageMediaWithLegacySignals(view: view, signals: signals)
            } else {
                self.enqueueMediaMessages(view: view, peer: peer, replyToMessageId: replyMessageId, replyToStoryId: replyToStoryId, signals: signals, silentPosting: silentPosting, scheduleTime: scheduleTime > 0 ? scheduleTime : nil)
            }
        })
    }
    
    private func presentICloudFileGallery(view: StoryItemSetContainerComponent.View, peer: EnginePeer, replyMessageId: EngineMessage.Id?, replyToStoryId: StoryId?) {
        guard let component = view.component else {
            return
        }
        let _ = (component.context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: component.context.account.peerId),
            TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: false),
            TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: true)
        )
        |> deliverOnMainQueue).start(next: { [weak self, weak view] result in
            guard let self, let view, let component = view.component else {
                return
            }
            let (accountPeer, limits, premiumLimits) = result
            let isPremium = accountPeer?.isPremium ?? false
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            component.controller()?.present(legacyICloudFilePicker(theme: presentationData.theme, completion: { [weak self, weak view] urls in
                if let strongSelf = self, let view, !urls.isEmpty {
                    var signals: [Signal<ICloudFileDescription?, NoError>] = []
                    for url in urls {
                        signals.append(iCloudFileDescription(url))
                    }
                    strongSelf.enqueueMediaMessageDisposable.set((combineLatest(signals)
                    |> deliverOnMainQueue).start(next: { [weak view] results in
                        if let strongSelf = self, let view, let component = view.component {
                            for item in results {
                                if let item = item {
                                    if item.fileSize > Int64(premiumLimits.maxUploadFileParts) * 512 * 1024 {
                                        let controller = PremiumLimitScreen(context: component.context, subject: .files, count: 4, action: {
                                        })
                                        component.controller()?.push(controller)
                                        return
                                    } else if item.fileSize > Int64(limits.maxUploadFileParts) * 512 * 1024 && !isPremium {
                                        let context = component.context
                                        var replaceImpl: ((ViewController) -> Void)?
                                        let controller = PremiumLimitScreen(context: context, subject: .files, count: 2, action: {
                                            replaceImpl?(PremiumIntroScreen(context: context, source: .upload))
                                        })
                                        replaceImpl = { [weak controller] c in
                                            controller?.replace(with: c)
                                        }
                                        component.controller()?.push(controller)
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
                                    
                                    let file = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: fileId), partialReference: nil, resource: ICloudFileResource(urlData: item.urlData, thumbnail: false), previewRepresentations: previewRepresentations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: mimeType, size: Int64(item.fileSize), attributes: attributes)
                                    let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), replyToMessageId: replyMessageId, replyToStoryId: replyToStoryId, localGroupingKey: groupingKey, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                                    messages.append(message)
                                }
                                if let _ = groupingKey, messages.count % 10 == 0 {
                                    groupingKey = Int64.random(in: Int64.min ... Int64.max)
                                }
                            }
                            
                            if !messages.isEmpty {
                                strongSelf.sendMessages(view: view, peer: peer, messages: messages)
                            }
                        }
                    }))
                }
            }), in: .window(.root))
        })
    }
    
    private func enqueueChatContextResult(view: StoryItemSetContainerComponent.View, peer: EnginePeer, replyMessageId: EngineMessage.Id?, storyId: StoryId?, results: ChatContextResultCollection, result: ChatContextResult, hideVia: Bool = false, closeMediaInput: Bool = false, silentPosting: Bool = false, resetTextInputState: Bool = true) {
        if !canSendMessagesToPeer(peer._asPeer()) {
            return
        }
        
        let sendMessage: (Int32?) -> Void = { [weak self, weak view] scheduleTime in
            guard let self, let view, let component = view.component else {
                return
            }
            if component.context.engine.messages.enqueueOutgoingMessageWithChatContextResult(to: peer.id, threadId: nil, botId: results.botId, result: result, replyToMessageId: replyMessageId, replyToStoryId: storyId, hideVia: hideVia, silentPosting: silentPosting, scheduleTime: scheduleTime) {
            }
            
            if let attachmentController = self.attachmentController {
                attachmentController.dismiss(animated: true)
            }
        }
        
        sendMessage(nil)
    }
    
    private func presentWebSearch(view: StoryItemSetContainerComponent.View, editingMessage: Bool, attachment: Bool, activateOnDisplay: Bool = true, present: @escaping (ViewController, Any?) -> Void) {
        /*guard let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return
        }
        
        let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Configuration.SearchBots())
        |> deliverOnMainQueue).start(next: { [weak self] configuration in
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
                    return strongSelf?.getCaptionPanelView()
                }
                present(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }
        })*/
    }
    
    private func getCaptionPanelView(view: StoryItemSetContainerComponent.View, peer: EnginePeer) -> TGCaptionPanelView? {
        guard let component = view.component else {
            return nil
        }
        //TODO:self.presentationInterfaceState.customEmojiAvailable
        return component.context.sharedContext.makeGalleryCaptionPanelView(context: component.context, chatLocation: .peer(id: peer.id), customEmojiAvailable: true, present: { [weak view] c in
            guard let view else {
                return
            }
            view.component?.controller()?.present(c, in: .window(.root))
        }, presentInGlobalOverlay: { [weak view] c in
            guard let view else {
                return
            }
            view.component?.controller()?.presentInGlobalOverlay(c)
        }) as? TGCaptionPanelView
    }
    
    private func openCamera(view: StoryItemSetContainerComponent.View, peer: EnginePeer, replyToMessageId: EngineMessage.Id?, replyToStoryId: StoryId?, cameraView: TGAttachmentCameraView? = nil) {
        guard let component = view.component else {
            return
        }
        guard let inputPanelView = view.inputPanel.view as? MessageInputPanelComponent.View else {
            return
        }
        
        var inputText = NSAttributedString(string: "")
        switch inputPanelView.getSendMessageInput() {
        case let .text(text):
            inputText = NSAttributedString(string: text)
        }
        
        let _ = (component.context.sharedContext.accountManager.transaction { transaction -> GeneratedMediaStoreSettings in
            let entry = transaction.getSharedData(ApplicationSpecificSharedDataKeys.generatedMediaStoreSettings)?.get(GeneratedMediaStoreSettings.self)
            return entry ?? GeneratedMediaStoreSettings.defaultSettings
        }
        |> deliverOnMainQueue).start(next: { [weak self, weak view] settings in
            guard let self, let view, let component = view.component, let parentController = component.controller() else {
                return
            }
            
            var enablePhoto = true
            var enableVideo = true
            
            if let callManager = component.context.sharedContext.callManager, callManager.hasActiveCall {
                enableVideo = false
            }
            
            var bannedSendPhotos: (Int32, Bool)?
            var bannedSendVideos: (Int32, Bool)?
            
            if case let .channel(channel) = peer {
                if let value = channel.hasBannedPermission(.banSendPhotos) {
                    bannedSendPhotos = value
                }
                if let value = channel.hasBannedPermission(.banSendVideos) {
                    bannedSendVideos = value
                }
            } else if case let .legacyGroup(group) = peer {
                if group.hasBannedPermission(.banSendPhotos) {
                    bannedSendPhotos = (Int32.max, false)
                }
                if group.hasBannedPermission(.banSendVideos) {
                    bannedSendVideos = (Int32.max, false)
                }
            }
            
            if bannedSendPhotos != nil {
                enablePhoto = false
            }
            if bannedSendVideos != nil {
                enableVideo = false
            }
            
            let storeCapturedMedia = peer.id.namespace != Namespaces.Peer.SecretChat
            
            presentedLegacyCamera(context: component.context, peer: peer._asPeer(), chatLocation: .peer(id: peer.id), cameraView: cameraView, menuController: nil, parentController: parentController, attachmentController: self.attachmentController, editingMedia: false, saveCapturedPhotos: storeCapturedMedia, mediaGrouping: true, initialCaption: inputText, hasSchedule: peer.id.namespace != Namespaces.Peer.SecretChat, enablePhoto: enablePhoto, enableVideo: enableVideo, sendMessagesWithSignals: { [weak self, weak view] signals, silentPosting, scheduleTime in
                guard let self, let view else {
                    return
                }
                self.enqueueMediaMessages(view: view, peer: peer, replyToMessageId: replyToMessageId, replyToStoryId: replyToStoryId, signals: signals, silentPosting: silentPosting, scheduleTime: scheduleTime > 0 ? scheduleTime : nil)
                if !inputText.string.isEmpty {
                    self.clearInputText(view: view)
                }
            }, recognizedQRCode: { _ in
            }, presentSchedulePicker: { [weak self, weak view] _, done in
                guard let self, let view else {
                    return
                }
                self.presentScheduleTimePicker(view: view, peer: peer, style: .media, completion: { time in
                    done(time)
                })
            }, presentTimerPicker: { [weak self, weak view] done in
                guard let self, let view else {
                    return
                }
                self.presentTimerPicker(view: view, peer: peer, style: .media, completion: { time in
                    done(time)
                })
            }, getCaptionPanelView: { [weak self, weak view] in
                guard let self, let view else {
                    return nil
                }
                return self.getCaptionPanelView(view: view, peer: peer)
            }, dismissedWithResult: { [weak self] in
                guard let self else {
                    return
                }
                self.attachmentController?.dismiss(animated: false, completion: nil)
            }, finishedTransitionIn: { [weak self] in
                guard let self else {
                    return
                }
                self.attachmentController?.scrollToTop?()
            })
        })
    }
    
    private func presentScheduleTimePicker(
        view: StoryItemSetContainerComponent.View,
        peer: EnginePeer,
        style: ChatScheduleTimeControllerStyle = .default,
        selectedTime: Int32? = nil,
        dismissByTapOutside: Bool = true,
        completion: @escaping (Int32) -> Void
    ) {
        guard let component = view.component else {
            return
        }
        let _ = (component.context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Presence(id: peer.id)
        )
        |> deliverOnMainQueue).start(next: { [weak view] presence in
            guard let view, let component = view.component else {
                return
            }
            
            var sendWhenOnlineAvailable = false
            if let presence, case .present = presence.status {
                sendWhenOnlineAvailable = true
            }
            if peer.id.namespace == Namespaces.Peer.CloudUser && peer.id.id._internalGetInt64Value() == 777000 {
                sendWhenOnlineAvailable = false
            }
            
            let mode: ChatScheduleTimeControllerMode
            if peer.id == component.context.account.peerId {
                mode = .reminders
            } else {
                mode = .scheduledMessages(sendWhenOnlineAvailable: sendWhenOnlineAvailable)
            }
            let theme = component.theme
            let controller = ChatScheduleTimeController(context: component.context, updatedPresentationData: (component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: theme), component.context.sharedContext.presentationData |> map { $0.withUpdated(theme: theme) }), peerId: peer.id, mode: mode, style: style, currentTime: selectedTime, minimalTime: nil, dismissByTapOutside: dismissByTapOutside, completion: { time in
                completion(time)
            })
            view.endEditing(true)
            view.component?.controller()?.present(controller, in: .window(.root))
        })
    }
    
    private func presentTimerPicker(view: StoryItemSetContainerComponent.View, peer: EnginePeer, style: ChatTimerScreenStyle = .default, selectedTime: Int32? = nil, dismissByTapOutside: Bool = true, completion: @escaping (Int32) -> Void) {
        guard let component = view.component else {
            return
        }
        let theme = component.theme
        let controller = ChatTimerScreen(context: component.context, updatedPresentationData: (component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: theme), component.context.sharedContext.presentationData |> map { $0.withUpdated(theme: theme) }), style: style, currentTime: selectedTime, dismissByTapOutside: dismissByTapOutside, completion: { time in
            completion(time)
        })
        view.endEditing(true)
        component.controller()?.present(controller, in: .window(.root))
    }
    
    private func configurePollCreation(view: StoryItemSetContainerComponent.View, peer: EnginePeer, targetMessageId: EngineMessage.Id?, isQuiz: Bool? = nil) -> CreatePollControllerImpl? {
        guard let component = view.component else {
            return nil
        }
        let focusedItem = component.slice.item
        guard let peerId = focusedItem.peerId else {
            return nil
        }
        let focusedStoryId = StoryId(peerId: peerId, id: focusedItem.storyItem.id)
        
        let theme = component.theme
        return createPollController(context: component.context, updatedPresentationData: (component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: theme), component.context.sharedContext.presentationData |> map { $0.withUpdated(theme: theme) }), peer: peer, isQuiz: isQuiz, completion: { [weak self, weak view] poll in
            guard let self, let view else {
                return
            }
            let replyMessageId = targetMessageId
            /*strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                if let strongSelf = self {
                    strongSelf.chatDisplayNode.collapseInput()
                    
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                        $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                    })
                }
            }, nil)*/
            let message: EnqueueMessage = .message(
                text: "",
                attributes: [],
                inlineStickers: [:],
                mediaReference: .standalone(media: TelegramMediaPoll(
                    pollId: EngineMedia.Id(namespace: Namespaces.Media.LocalPoll, id: Int64.random(in: Int64.min ... Int64.max)),
                    publicity: poll.publicity,
                    kind: poll.kind,
                    text: poll.text,
                    options: poll.options,
                    correctAnswers: poll.correctAnswers,
                    results: poll.results,
                    isClosed: false,
                    deadlineTimeout: poll.deadlineTimeout
                )),
                replyToMessageId: nil,
                replyToStoryId: focusedStoryId,
                localGroupingKey: nil,
                correlationId: nil,
                bubbleUpEmojiOrStickersets: []
            )
            self.sendMessages(view: view, peer: peer, messages: [message.withUpdatedReplyToMessageId(replyMessageId)])
        })
    }
    
    private func transformEnqueueMessages(view: StoryItemSetContainerComponent.View, messages: [EnqueueMessage], silentPosting: Bool, scheduleTime: Int32? = nil) -> [EnqueueMessage] {
        var focusedStoryId: StoryId?
        if let component = view.component, let peerId = component.slice.item.peerId {
            focusedStoryId = StoryId(peerId: peerId, id: component.slice.item.storyItem.id)
        }
        
        return messages.map { message in
            var message = message
            
            if let focusedStoryId {
                switch message {
                case let .message(text, attributes, inlineStickers, mediaReference, replyToMessageId, _, localGroupingKey, correlationId, bubbleUpEmojiOrStickersets):
                    if replyToMessageId == nil {
                        message = .message(text: text, attributes: attributes, inlineStickers: inlineStickers, mediaReference: mediaReference, replyToMessageId: replyToMessageId, replyToStoryId: focusedStoryId, localGroupingKey: localGroupingKey, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)
                    }
                case .forward:
                    break
                }
            }
            
            return message.withUpdatedAttributes { attributes in
                var attributes = attributes
                if silentPosting || scheduleTime != nil {
                    for i in (0 ..< attributes.count).reversed() {
                        if attributes[i] is NotificationInfoMessageAttribute {
                            attributes.remove(at: i)
                        } else if let _ = scheduleTime, attributes[i] is OutgoingScheduleInfoMessageAttribute {
                            attributes.remove(at: i)
                        }
                    }
                    if silentPosting {
                        attributes.append(NotificationInfoMessageAttribute(flags: .muted))
                    }
                    if let scheduleTime = scheduleTime {
                         attributes.append(OutgoingScheduleInfoMessageAttribute(scheduleTime: scheduleTime))
                    }
                }
                return attributes
            }
        }
    }
    
    private func sendMessages(view: StoryItemSetContainerComponent.View, peer: EnginePeer, messages: [EnqueueMessage], media: Bool = false, commit: Bool = false) {
        guard let component = view.component else {
            return
        }
        let _ = (enqueueMessages(account: component.context.account, peerId: peer.id, messages: self.transformEnqueueMessages(view: view, messages: messages, silentPosting: false))
        |> deliverOnMainQueue).start()
        
        donateSendMessageIntent(account: component.context.account, sharedContext: component.context.sharedContext, intentContext: .chat, peerIds: [peer.id])
        
        if let attachmentController = self.attachmentController {
            attachmentController.dismiss(animated: true)
        }
        
        if let controller = component.controller() {
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            controller.present(UndoOverlayController(
                presentationData: presentationData,
                content: .succeed(text: "Message Sent"),
                elevatedLayout: false,
                animateInAsReplacement: false,
                action: { _ in return false }
            ), in: .current)
        }
    }
    
    private func enqueueMediaMessages(view: StoryItemSetContainerComponent.View, peer: EnginePeer, replyToMessageId: EngineMessage.Id?, replyToStoryId: StoryId?, signals: [Any]?, silentPosting: Bool, scheduleTime: Int32? = nil, getAnimatedTransitionSource: ((String) -> UIView?)? = nil, completion: @escaping () -> Void = {}) {
        guard let component = view.component else {
            return
        }
        
        self.enqueueMediaMessageDisposable.set((legacyAssetPickerEnqueueMessages(context: component.context, account: component.context.account, signals: signals!)
        |> deliverOnMainQueue).start(next: { [weak self, weak view] items in
            if let strongSelf = self, let view {
                var mappedMessages: [EnqueueMessage] = []
                var addedTransitions: [(Int64, [String], () -> Void)] = []
                
                var groupedCorrelationIds: [Int64: Int64] = [:]
                
                var skipAddingTransitions = false
                
                for item in items {
                    var message = item.message
                    if message.groupingKey != nil {
                        if items.count > 10 {
                            skipAddingTransitions = true
                        }
                    } else if items.count > 3 {
                        skipAddingTransitions = true
                    }
                    
                    if let uniqueId = item.uniqueId, !item.isFile && !skipAddingTransitions {
                        let correlationId: Int64
                        var addTransition = scheduleTime == nil
                        if let groupingKey = message.groupingKey {
                            if let existing = groupedCorrelationIds[groupingKey] {
                                correlationId = existing
                                addTransition = false
                            } else {
                                correlationId = Int64.random(in: 0 ..< Int64.max)
                                groupedCorrelationIds[groupingKey] = correlationId
                            }
                        } else {
                            correlationId = Int64.random(in: 0 ..< Int64.max)
                        }
                        message = message.withUpdatedCorrelationId(correlationId)

                        if addTransition {
                            addedTransitions.append((correlationId, [uniqueId], addedTransitions.isEmpty ? completion : {}))
                        } else {
                            if let index = addedTransitions.firstIndex(where: { $0.0 == correlationId }) {
                                var (correlationId, uniqueIds, completion) = addedTransitions[index]
                                uniqueIds.append(uniqueId)
                                addedTransitions[index] = (correlationId, uniqueIds, completion)
                            }
                        }
                    }
                    mappedMessages.append(message)
                }
                                                    
                let messages = strongSelf.transformEnqueueMessages(view: view, messages: mappedMessages, silentPosting: silentPosting, scheduleTime: scheduleTime)

                strongSelf.sendMessages(view: view, peer: peer, messages: messages.map { $0.withUpdatedReplyToMessageId(replyToMessageId).withUpdatedReplyToStoryId(replyToStoryId) }, media: true)
                
                if let _ = scheduleTime {
                    completion()
                }
            }
        }))
    }
    
    private func editMessageMediaWithLegacySignals(view: StoryItemSetContainerComponent.View, signals: [Any]) {
        guard let component = view.component else {
            return
        }
        let _ = (legacyAssetPickerEnqueueMessages(context: component.context, account: component.context.account, signals: signals)
        |> deliverOnMainQueue).start()
    }
}
