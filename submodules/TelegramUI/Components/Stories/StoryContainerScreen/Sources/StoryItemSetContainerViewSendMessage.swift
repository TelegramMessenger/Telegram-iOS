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
import OverlayStatusController
import PresentationDataUtils
import TextFieldComponent
import StickerPackPreviewUI
import OpenInExternalAppUI
import SafariServices
import MediaPasteboardUI
import WebPBinding
import ContextUI
import ChatScheduleTimeController
import StoryStealthModeSheetScreen
import Speak
import TranslateUI
import TelegramNotices
import ObjectiveC
import LocationUI

private var ObjCKey_DeinitWatcher: Int?

final class StoryItemSetContainerSendMessage {
    enum InputMode {
        case text
        case media
    }
    
    private var context: AccountContext?
    private weak var view: StoryItemSetContainerComponent.View?
    private var inputPanelExternalState: MessageInputPanelComponent.ExternalState?
    
    weak var attachmentController: AttachmentController?
    weak var shareController: ShareController?
    weak var tooltipScreen: ViewController?
    weak var actionSheet: ViewController?
    weak var statusController: ViewController?
    weak var lookupController: UIViewController?
    weak var menuController: ViewController?
    var isViewingAttachedStickers = false
    
    var currentTooltipUpdateTimer: Foundation.Timer?
    
    var currentInputMode: InputMode = .text
    private var needsInputActivation = false
    
    var audioRecorderValue: ManagedAudioRecorder?
    var audioRecorder = Promise<ManagedAudioRecorder?>()
    var recordedAudioPreview: ChatRecordedMediaPreview?
    
    var videoRecorderValue: InstantVideoController?
    var videoRecorder = Promise<InstantVideoController?>()
    var hasRecordedVideoPreview = false
    
    var inputMediaNodeData: ChatEntityKeyboardInputNode.InputData?
    var inputMediaNodeDataDisposable: Disposable?
    var inputMediaNodeStateContext = ChatEntityKeyboardInputNode.StateContext()
    var inputMediaInteraction: ChatEntityKeyboardInputNode.Interaction?
    var inputMediaNode: ChatEntityKeyboardInputNode?
    var inputMediaNodeBackground = SimpleLayer()
    
    let controllerNavigationDisposable = MetaDisposable()
    let enqueueMediaMessageDisposable = MetaDisposable()
    let navigationActionDisposable = MetaDisposable()
    let resolvePeerByNameDisposable = MetaDisposable()
    
    var currentSpeechHolder: SpeechSynthesizerHolder?
    
    private(set) var isMediaRecordingLocked: Bool = false
    var wasRecordingDismissed: Bool = false
    
    init() {
    }
    
    deinit {
        self.controllerNavigationDisposable.dispose()
        self.enqueueMediaMessageDisposable.dispose()
        self.navigationActionDisposable.dispose()
        self.resolvePeerByNameDisposable.dispose()
        self.inputMediaNodeDataDisposable?.dispose()
        self.currentTooltipUpdateTimer?.invalidate()
    }
    
    func setup(context: AccountContext, view: StoryItemSetContainerComponent.View, inputPanelExternalState: MessageInputPanelComponent.ExternalState, keyboardInputData: Signal<ChatEntityKeyboardInputNode.InputData, NoError>) {
        self.context = context
        self.inputPanelExternalState = inputPanelExternalState
        self.view = view
        
        if self.inputMediaNodeDataDisposable == nil {
            self.inputMediaNodeDataDisposable = (keyboardInputData
            |> deliverOnMainQueue).start(next: { [weak self] value in
                guard let self else {
                    return
                }
                self.inputMediaNodeData = value
            })
        }
        
        self.inputMediaInteraction = ChatEntityKeyboardInputNode.Interaction(
            sendSticker: { [weak self] fileReference, _, _, _, _, _, _, _, _ in
                if let self, let view = self.view {
                    self.performSendStickerAction(view: view, fileReference: fileReference)
                }
                return false
            },
            sendEmoji: { [weak self] text, attribute, _ in
                if let self {
                    let _ = self
                }
            },
            sendGif: { [weak self] fileReference, _, _, _, _ in
                if let self, let view = self.view {
                    self.performSendStickerAction(view: view, fileReference: fileReference)
                }
                return false
            },
            sendBotContextResultAsGif: { [weak self] results, result, _, _, _, _ in
                if let self, let view = self.view {
                    self.performSendContextResultAction(view: view, results: results, result: result)
                }
                return false
            },
            updateChoosingSticker: { _ in },
            switchToTextInput: { [weak self] in
                if let self {
                    self.currentInputMode = .text
                    if let view = self.view, !hasFirstResponder(view) {
                        let _ = view.activateInput()
                    } else {
                        self.view?.state?.updated(transition: .immediate)
                    }
                }
            },
            dismissTextInput: {
                
            },
            insertText: { [weak self] text in
                if let self {
                    self.inputPanelExternalState?.insertText(text)
                }
            },
            backwardsDeleteText: { [weak self] in
                if let self {
                    self.inputPanelExternalState?.deleteBackward()
                }
            },
            presentController: { [weak self] c, a in
                if let self {
                    self.view?.component?.controller()?.present(c, in: .window(.root), with: a)
                }
            },
            presentGlobalOverlayController: { [weak self] c, a in
                if let self {
                    self.view?.component?.controller()?.presentInGlobalOverlay(c, with: a)
                }
            },
            getNavigationController: { [weak self] in
                if let self {
                    return self.view?.component?.controller()?.navigationController as? NavigationController
                } else {
                    return nil
                }
            },
            requestLayout: { [weak self] transition in
                if let self {
                    self.view?.state?.updated(transition: Transition(transition))
                }
            }
        )
        self.inputMediaInteraction?.forceTheme = defaultDarkColorPresentationTheme
    }
    
    func toggleInputMode() {
        guard let view = self.view else {
            return
        }
        if case .text = self.currentInputMode {
            if !hasFirstResponder(view) {
                self.needsInputActivation = true
            }
            self.currentInputMode = .media
        } else {
            self.currentInputMode = .text
        }
    }
    
    func updateInputMediaNode(view: StoryItemSetContainerComponent.View, availableSize: CGSize, bottomInset: CGFloat, bottomContainerInset: CGFloat, inputHeight: CGFloat, effectiveInputHeight: CGFloat, metrics: LayoutMetrics, deviceMetrics: DeviceMetrics, transition: Transition) -> CGFloat {
        guard let context = self.context, let inputPanelView = view.inputPanel.view as? MessageInputPanelComponent.View else {
            return 0.0
        }
                       
        var height: CGFloat = 0.0
        if let component = self.view?.component, case .media = self.currentInputMode, let inputData = self.inputMediaNodeData {
            let inputMediaNode: ChatEntityKeyboardInputNode
            if let current = self.inputMediaNode {
                inputMediaNode = current
            } else {
                inputMediaNode = ChatEntityKeyboardInputNode(
                    context: context,
                    currentInputData: inputData,
                    updatedInputData: component.keyboardInputData,
                    defaultToEmojiTab: self.inputPanelExternalState?.hasText ?? false,
                    opaqueTopPanelBackground: false,
                    interaction: self.inputMediaInteraction,
                    chatPeerId: nil,
                    stateContext: self.inputMediaNodeStateContext
                )
                inputMediaNode.externalTopPanelContainerImpl = nil
                inputMediaNode.useExternalSearchContainer = true
                if inputMediaNode.view.superview == nil {
                    self.inputMediaNodeBackground.removeAllAnimations()
                    self.inputMediaNodeBackground.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.7).cgColor
                    view.inputPanelContainer.addSubview(inputMediaNode.view)
                }
                self.inputMediaNode = inputMediaNode
            }
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkPresentationTheme)
            let presentationInterfaceState = ChatPresentationInterfaceState(
                chatWallpaper: .builtin(WallpaperSettings()),
                theme: presentationData.theme,
                strings: presentationData.strings,
                dateTimeFormat: presentationData.dateTimeFormat,
                nameDisplayOrder: presentationData.nameDisplayOrder,
                limitsConfiguration: context.currentLimitsConfiguration.with { $0 },
                fontSize: presentationData.chatFontSize,
                bubbleCorners: presentationData.chatBubbleCorners,
                accountPeerId: context.account.peerId,
                mode: .standard(previewing: false),
                chatLocation: .peer(id: context.account.peerId),
                subject: nil,
                peerNearbyData: nil,
                greetingData: nil,
                pendingUnpinnedAllMessages: false,
                activeGroupCallInfo: nil,
                hasActiveGroupCall: false,
                importState: nil,
                threadData: nil,
                isGeneralThreadClosed: nil
            )
            
            let heightAndOverflow = inputMediaNode.updateLayout(width: availableSize.width, leftInset: 0.0, rightInset: 0.0, bottomInset: bottomInset, standardInputHeight: deviceMetrics.standardInputHeight(inLandscape: false), inputHeight: inputHeight < 100.0 ? inputHeight - bottomContainerInset : inputHeight, maximumHeight: availableSize.height, inputPanelHeight: 0.0, transition: .immediate, interfaceState: presentationInterfaceState, layoutMetrics: metrics, deviceMetrics: deviceMetrics, isVisible: true, isExpanded: false)
            let inputNodeHeight = heightAndOverflow.0
            let inputNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - inputNodeHeight), size: CGSize(width: availableSize.width, height: inputNodeHeight))
            
            if self.needsInputActivation {
                let inputNodeFrame = inputNodeFrame.offsetBy(dx: 0.0, dy: inputNodeHeight)
                Transition.immediate.setFrame(layer: inputMediaNode.layer, frame: inputNodeFrame)
                Transition.immediate.setFrame(layer: self.inputMediaNodeBackground, frame: inputNodeFrame)
            }
            transition.setFrame(layer: inputMediaNode.layer, frame: inputNodeFrame)
            transition.setFrame(layer: self.inputMediaNodeBackground, frame: inputNodeFrame)
            
            height = heightAndOverflow.0
        } else if let inputMediaNode = self.inputMediaNode {
            self.inputMediaNode = nil
            
            var targetFrame = inputMediaNode.frame
            if effectiveInputHeight > 0.0 {
                targetFrame.origin.y = availableSize.height - effectiveInputHeight
            } else {
                targetFrame.origin.y = availableSize.height
            }
            transition.setFrame(view: inputMediaNode.view, frame: targetFrame, completion: { [weak inputMediaNode] _ in
                if let inputMediaNode {
                    Queue.mainQueue().after(0.3) {
                        inputMediaNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.35, removeOnCompletion: false, completion: { [weak inputMediaNode] _ in
                            inputMediaNode?.view.removeFromSuperview()
                        })
                    }
                }
            })
            transition.setFrame(layer: self.inputMediaNodeBackground, frame: targetFrame, completion: { _ in
                Queue.mainQueue().after(0.3) {
                    if self.currentInputMode == .text {
                        self.inputMediaNodeBackground.animateAlpha(from: 1.0, to: 0.0, duration: 0.35, removeOnCompletion: false, completion: { finished in
                            if finished {
                                self.inputMediaNodeBackground.removeFromSuperlayer()
                            }
                            self.inputMediaNodeBackground.removeAllAnimations()
                        })
                    }
                }
            })
        }
        
        if self.needsInputActivation {
            self.needsInputActivation = false
            Queue.mainQueue().justDispatch {
                inputPanelView.activateInput()
            }
        }
        
        return height
    }
    
    func animateOut(bounds: CGRect) {
        if let inputMediaNode = self.inputMediaNode {
            inputMediaNode.layer.animatePosition(
                from: CGPoint(),
                to: CGPoint(x: 0.0, y: bounds.height - inputMediaNode.frame.minY),
                duration: 0.3,
                timingFunction: kCAMediaTimingFunctionSpring,
                removeOnCompletion: false,
                additive: true
            )
            inputMediaNode.layer.animateAlpha(from: inputMediaNode.alpha, to: 0.0, duration: 0.3, removeOnCompletion: false)
            
            self.inputMediaNodeBackground.animatePosition(
                from: CGPoint(),
                to: CGPoint(x: 0.0, y: bounds.height - self.inputMediaNodeBackground.frame.minY),
                duration: 0.3,
                timingFunction: kCAMediaTimingFunctionSpring,
                removeOnCompletion: false,
                additive: true
            )
            self.inputMediaNodeBackground.animateAlpha(from: CGFloat(self.inputMediaNodeBackground.opacity), to: 0.0, duration: 0.3, removeOnCompletion: false)
        }
    }
    
    private func presentMessageSentTooltip(view: StoryItemSetContainerComponent.View, peer: EnginePeer, messageId: EngineMessage.Id?, isScheduled: Bool = false) {
        guard let component = view.component, let controller = component.controller() as? StoryContainerScreen else {
            return
        }
        
        if let tooltipScreen = self.tooltipScreen {
            tooltipScreen.dismiss(animated: true)
        }
        
        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
        
        let text = isScheduled ? presentationData.strings.Story_TooltipMessageScheduled : presentationData.strings.Story_TooltipMessageSent
        
        let tooltipScreen = UndoOverlayController(
            presentationData: presentationData,
            content: .actionSucceeded(title: "", text: text, cancel: messageId != nil ? presentationData.strings.Story_ToastViewInChat : "", destructive: false),
            elevatedLayout: false,
            animateInAsReplacement: false,
            action: { [weak view, weak self] action in
                if case .undo = action, let messageId {
                    view?.navigateToPeer(peer: peer, chat: true, subject: isScheduled ? .scheduledMessages : .message(id: .id(messageId), highlight: false, timecode: nil))
                }
                self?.tooltipScreen = nil
                view?.updateIsProgressPaused()
                return false
            }
        )
        controller.present(tooltipScreen, in: .current)
        self.tooltipScreen = tooltipScreen
        view.updateIsProgressPaused()
        
        HapticFeedback().success()
    }
    
    func presentSendMessageOptions(view: StoryItemSetContainerComponent.View, sourceView: UIView, gesture: ContextGesture?) {
        guard let component = view.component, let controller = component.controller() as? StoryContainerScreen else {
            return
        }
        
        view.dismissAllTooltips()
        
        var sendWhenOnlineAvailable = false
        if let presence = component.slice.additionalPeerData.presence, case .present = presence.status {
            sendWhenOnlineAvailable = true
        }
        
        let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
        var items: [ContextMenuItem] = []
        
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_SendMessage_SendSilently, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Menu/SilentIcon"), color: theme.contextMenu.primaryColor)
        }, action: { [weak self, weak view] _, a in
            a(.default)
            
            guard let self, let view else {
                return
            }
            self.performSendMessageAction(view: view, silentPosting: true)
        })))
        
        if sendWhenOnlineAvailable {
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_SendMessage_SendWhenOnline, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Menu/WhenOnlineIcon"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self, weak view] _, a in
                a(.default)
                
                guard let self, let view else {
                    return
                }
                self.performSendMessageAction(view: view, scheduleTime: scheduleWhenOnlineTimestamp)
            })))
        }
        
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_SendMessage_ScheduleMessage, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Menu/ScheduleIcon"), color: theme.contextMenu.primaryColor)
        }, action: { [weak self, weak view] _, a in
            a(.default)
            
            guard let self, let view else {
                return
            }
            self.presentScheduleTimePicker(view: view)
        })))
        
        
        let contextItems = ContextController.Items(content: .list(items))
        
        let contextController = ContextController(account: component.context.account, presentationData: presentationData, source: .reference(HeaderContextReferenceContentSource(controller: controller, sourceView: sourceView, position: .top)), items: .single(contextItems), gesture: gesture)
        contextController.dismissed = { [weak view] in
            guard let view else {
                return
            }
            view.contextController = nil
            view.updateIsProgressPaused()
        }
        view.contextController = contextController
        view.updateIsProgressPaused()
        controller.present(contextController, in: .window(.root))
    }
    
    func presentScheduleTimePicker(
        view: StoryItemSetContainerComponent.View
    ) {
        guard let component = view.component else {
            return
        }
        let focusedItem = component.slice.item
        guard let peerId = focusedItem.peerId else {
            return
        }
        let controller = component.controller() as? StoryContainerScreen
        
        var sendWhenOnlineAvailable = false
        if let presence = component.slice.additionalPeerData.presence, case .present = presence.status {
            sendWhenOnlineAvailable = true
        }
        
        let timeController = ChatScheduleTimeController(context: component.context, updatedPresentationData: nil, peerId: peerId, mode: .scheduledMessages(sendWhenOnlineAvailable: sendWhenOnlineAvailable), style: .media, currentTime: nil, minimalTime: nil, dismissByTapOutside: true, completion: { [weak self, weak view] time in
            guard let self, let view else {
                return
            }
            self.performSendMessageAction(view: view, scheduleTime: time)
        })
        timeController.dismissed = { [weak self, weak view] in
            guard let self, let view else {
                return
            }
            self.actionSheet = nil
            view.updateIsProgressPaused()
        }
        view.endEditing(true)
        controller?.present(timeController, in: .window(.root))
       
        self.actionSheet = timeController
        view.updateIsProgressPaused()
    }
    
    func performWithPossibleStealthModeConfirmation(view: StoryItemSetContainerComponent.View, action: @escaping () -> Void) {
        guard let component = view.component, component.stealthModeTimeout != nil else {
            action()
            return
        }
        
        let _ = (combineLatest(
            component.context.engine.data.get(
                TelegramEngine.EngineData.Item.Configuration.StoryConfigurationState()
            ),
            ApplicationSpecificNotice.storyStealthModeReplyCount(accountManager: component.context.sharedContext.accountManager)
        )
        |> deliverOnMainQueue).start(next: { [weak self, weak view] data, noticeCount in
            let config = data
            
            guard let self, let view, let component = view.component else {
                return
            }
            
            let timestamp = Int32(Date().timeIntervalSince1970)
            if noticeCount < 1, let activeUntilTimestamp = config.stealthModeState.actualizedNow().activeUntilTimestamp, activeUntilTimestamp > timestamp {
                
                let theme = component.theme
                let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>) = (component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: theme), component.context.sharedContext.presentationData |> map { $0.withUpdated(theme: theme) })
                
                let alertController = textAlertController(
                    context: component.context,
                    updatedPresentationData: updatedPresentationData,
                    title: component.strings.Story_AlertStealthModeActiveTitle,
                    text: component.strings.Story_AlertStealthModeActiveText,
                    actions: [
                        TextAlertAction(type: .defaultAction, title: component.strings.Common_Cancel, action: {}),
                        TextAlertAction(type: .genericAction, title: component.strings.Story_AlertStealthModeActiveAction, action: {
                            action()
                        })
                    ]
                )
                alertController.dismissed = { [weak self, weak view] _ in
                    guard let self, let view else {
                        return
                    }
                    self.actionSheet = nil
                    view.updateIsProgressPaused()
                }
                self.actionSheet = alertController
                view.updateIsProgressPaused()
                
                component.controller()?.presentInGlobalOverlay(alertController)
                
                #if DEBUG
                #else
                let _ = ApplicationSpecificNotice.incrementStoryStealthModeReplyCount(accountManager: component.context.sharedContext.accountManager).start()
                #endif
            } else {
                action()
            }
        })
    }
    
    func performSendMessageAction(
        view: StoryItemSetContainerComponent.View,
        silentPosting: Bool = false,
        scheduleTime: Int32? = nil
    ) {
        self.performWithPossibleStealthModeConfirmation(view: view, action: { [weak self, weak view] in
            guard let self, let view else {
                return
            }
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
            let peer = component.slice.peer
            
            let controller = component.controller() as? StoryContainerScreen
            
            if let recordedAudioPreview = self.recordedAudioPreview {
                self.recordedAudioPreview = nil
                
                let waveformBuffer = recordedAudioPreview.waveform.makeBitstream()
                
                let messages: [EnqueueMessage] = [.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: Int64.random(in: Int64.min ... Int64.max)), partialReference: nil, resource: recordedAudioPreview.resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: Int64(recordedAudioPreview.fileSize), attributes: [.Audio(isVoice: true, duration: Int(recordedAudioPreview.duration), title: nil, performer: nil, waveform: waveformBuffer)])), replyToMessageId: nil, replyToStoryId: focusedStoryId, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])]
                
                let _ = enqueueMessages(account: component.context.account, peerId: peerId, messages: messages).start()
                
                view.state?.updated(transition: Transition(animation: .curve(duration: 0.3, curve: .spring)))
            } else if self.hasRecordedVideoPreview, let videoRecorderValue = self.videoRecorderValue {
                videoRecorderValue.send()
                self.hasRecordedVideoPreview = false
                self.videoRecorder.set(.single(nil))
                view.state?.updated(transition: Transition(animation: .curve(duration: 0.3, curve: .spring)))
            } else {
                switch inputPanelView.getSendMessageInput() {
                case let .text(text):
                    if !text.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let entities = generateChatInputTextEntities(text)
                        let _ = (component.context.engine.messages.enqueueOutgoingMessage(
                            to: peerId,
                            replyTo: nil,
                            storyId: focusedStoryId,
                            content: .text(text.string, entities),
                            silentPosting: silentPosting,
                            scheduleTime: scheduleTime
                        ) |> deliverOnMainQueue).start(next: { [weak self, weak view] messageIds in
                            Queue.mainQueue().after(0.3) {
                                if let self, let view {
                                    self.presentMessageSentTooltip(view: view, peer: peer, messageId: messageIds.first.flatMap { $0 }, isScheduled: scheduleTime != nil)
                                }
                            }
                        })
                        inputPanelView.clearSendMessageInput(updateState: true)
                        
                        self.currentInputMode = .text
                        if hasFirstResponder(view) {
                            view.endEditing(true)
                        } else {
                            view.state?.updated(transition: .spring(duration: 0.3))
                        }
                        controller?.requestLayout(forceUpdate: true, transition: .animated(duration: 0.3, curve: .spring))
                    }
                }
            }
        })
    }
    
    func performSendStickerAction(view: StoryItemSetContainerComponent.View, fileReference: FileMediaReference) {
        self.performWithPossibleStealthModeConfirmation(view: view, action: { [weak self, weak view] in
            guard let self, let view else {
                return
            }
            guard let component = view.component else {
                return
            }
            let focusedItem = component.slice.item
            guard let peerId = focusedItem.peerId else {
                return
            }
            let focusedStoryId = StoryId(peerId: peerId, id: focusedItem.storyItem.id)
            let peer = component.slice.peer
            
            let controller = component.controller() as? StoryContainerScreen
            
            if let navigationController = controller?.navigationController as? NavigationController {
                var controllers = navigationController.viewControllers
                for controller in controllers.reversed() {
                    if !(controller is StoryContainerScreen) {
                        controllers.removeLast()
                    } else {
                        break
                    }
                }
                navigationController.setViewControllers(controllers, animated: true)
                
                controller?.window?.forEachController({ controller in
                    if let controller = controller as? StickerPackScreenImpl {
                        controller.dismiss()
                    }
                })
            }
            
            let _ = (component.context.engine.messages.enqueueOutgoingMessage(
                to: peerId,
                replyTo: nil,
                storyId: focusedStoryId,
                content: .file(fileReference)
            ) |> deliverOnMainQueue).start(next: { [weak self, weak view] messageIds in
                Queue.mainQueue().after(0.3) {
                    if let self, let view {
                        self.presentMessageSentTooltip(view: view, peer: peer, messageId: messageIds.first.flatMap { $0 })
                    }
                }
            })
            
            self.currentInputMode = .text
            if hasFirstResponder(view) {
                view.endEditing(true)
            } else {
                view.state?.updated(transition: .spring(duration: 0.3))
            }
            controller?.requestLayout(forceUpdate: true, transition: .animated(duration: 0.3, curve: .spring))
        })
    }
    
    func performSendContextResultAction(view: StoryItemSetContainerComponent.View, results: ChatContextResultCollection, result: ChatContextResult) {
        guard let component = view.component else {
            return
        }
        let focusedItem = component.slice.item
        guard let peerId = focusedItem.peerId else {
            return
        }
        let focusedStoryId = StoryId(peerId: peerId, id: focusedItem.storyItem.id)
        let peer = component.slice.peer
        
        let controller = component.controller() as? StoryContainerScreen
        
        if let navigationController = controller?.navigationController as? NavigationController {
            var controllers = navigationController.viewControllers
            for controller in controllers.reversed() {
                if !(controller is StoryContainerScreen) {
                    controllers.removeLast()
                } else {
                    break
                }
            }
            navigationController.setViewControllers(controllers, animated: true)
            
            controller?.window?.forEachController({ controller in
                if let controller = controller as? StickerPackScreenImpl {
                    controller.dismiss()
                }
            })
        }
        
        let _ = (component.context.engine.messages.enqueueOutgoingMessage(
            to: peerId,
            replyTo: nil,
            storyId: focusedStoryId,
            content: .contextResult(results, result)
        ) |> deliverOnMainQueue).start(next: { [weak self, weak view] messageIds in
            Queue.mainQueue().after(0.3) {
                if let self, let view {
                    self.presentMessageSentTooltip(view: view, peer: peer, messageId: messageIds.first.flatMap { $0 })
                }
            }
        })
        
        self.currentInputMode = .text
        if hasFirstResponder(view) {
            view.endEditing(true)
        } else {
            view.state?.updated(transition: .spring(duration: 0.3))
        }
        controller?.requestLayout(forceUpdate: true, transition: .animated(duration: 0.3, curve: .spring))
    }
    
    func enqueueGifData(view: StoryItemSetContainerComponent.View, data: Data) {
        guard let component = view.component else {
            return
        }
        let peer = component.slice.peer
        let _ = (legacyEnqueueGifMessage(account: component.context.account, data: data) |> deliverOnMainQueue).start(next: { [weak self, weak view] message in
            if let self, let view {
                self.sendMessages(view: view, peer: peer, messages: [message])
            }
        })
    }
    
    func enqueueStickerImage(view: StoryItemSetContainerComponent.View, image: UIImage, isMemoji: Bool) {
        guard let component = view.component else {
            return
        }
        let peer = component.slice.peer
        
        let size = image.size.aspectFitted(CGSize(width: 512.0, height: 512.0))
        
        func scaleImage(_ image: UIImage, size: CGSize, boundiingSize: CGSize) -> UIImage? {
            if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                let format = UIGraphicsImageRendererFormat()
                format.scale = 1.0
                let renderer = UIGraphicsImageRenderer(size: size, format: format)
                return renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: size))
                }
            } else {
                return TGScaleImageToPixelSize(image, size)
            }
        }

        func convertToWebP(image: UIImage, targetSize: CGSize?, targetBoundingSize: CGSize?, quality: CGFloat) -> Signal<Data, NoError> {
            var image = image
            if let targetSize = targetSize, let scaledImage = scaleImage(image, size: targetSize, boundiingSize: targetSize) {
                image = scaledImage
            }
            
            return Signal { subscriber in
                if let data = try? WebP.convert(toWebP: image, quality: quality * 100.0) {
                    subscriber.putNext(data)
                }
                subscriber.putCompletion()
                
                return EmptyDisposable
            } |> runOn(Queue.concurrentDefaultQueue())
        }

        let _ = (convertToWebP(image: image, targetSize: size, targetBoundingSize: size, quality: 0.9) |> deliverOnMainQueue).start(next: { [weak self, weak view] data in
            if let self, let view, !data.isEmpty {
                let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                component.context.account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                
                var fileAttributes: [TelegramMediaFileAttribute] = []
                fileAttributes.append(.FileName(fileName: "sticker.webp"))
                fileAttributes.append(.Sticker(displayText: "", packReference: nil, maskData: nil))
                fileAttributes.append(.ImageSize(size: PixelDimensions(size)))
                
                let media = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: Int64.random(in: Int64.min ... Int64.max)), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "image/webp", size: Int64(data.count), attributes: fileAttributes)
                let message = EnqueueMessage.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: media), replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                
                self.sendMessages(view: view, peer: peer, messages: [message], silentPosting: false)
            }
        })
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
                            self.videoRecorder.set(.single(legacyInstantVideoController(theme: defaultDarkPresentationTheme, forStory: true, panelFrame: view.convert(currentInputPanelFrame, to: nil), context: component.context, peerId: peer.id, slowmodeState: nil, hasSchedule: true, send: { [weak self, weak view] videoController, message in
                                guard let self, let view else {
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

                                self.performWithPossibleStealthModeConfirmation(view: view, action: { [weak self, weak view] in
                                    guard let self, let view else {
                                        return
                                    }
                                    self.sendMessages(view: view, peer: peer, messages: [updatedMessage])
                                })
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
                            
                            self.performWithPossibleStealthModeConfirmation(view: view, action: { [weak self, weak view] in
                                guard let self, let view else {
                                    return
                                }
                                self.sendMessages(view: view, peer: peer, messages: [.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: randomId), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: Int64(data.compressedData.count), attributes: [.Audio(isVoice: true, duration: Int(data.duration), title: nil, performer: nil, waveform: waveformBuffer)])), replyToMessageId: nil, replyToStoryId: focusedStoryId, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])])
                                
                                HapticFeedback().tap()
                            })
                        }
                    })
                } else if let videoRecorderValue = self.videoRecorderValue {
                    self.wasRecordingDismissed = !sendAction
                    
                    if sendAction {
                        videoRecorderValue.completeVideo()
                    } else {
                        self.videoRecorder.set(.single(nil))
                    }
                    self.hasRecordedVideoPreview = false
                    
                    view.state?.updated(transition: Transition(animation: .curve(duration: 0.3, curve: .spring)))
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
                self.hasRecordedVideoPreview = true
                view.state?.updated(transition: Transition(animation: .curve(duration: 0.3, curve: .spring)))
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
        } else if self.hasRecordedVideoPreview {
            self.videoRecorder.set(.single(nil))
            self.hasRecordedVideoPreview = false
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
        
        if focusedItem.storyItem.isForwardingDisabled {
            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
            let actionSheet = ActionSheetController(presentationData: presentationData)
            
            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Story_Context_CopyLink, color: .accent, action: { [weak self, weak view, weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        
                        guard let self, let view else {
                            return
                        }
                        self.performCopyLinkAction(view: view)
                    })
                ]),
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])
            ])
            
            actionSheet.dismissed = { [weak self, weak view] _ in
                guard let self, let view else {
                    return
                }
                self.actionSheet = nil
                view.updateIsProgressPaused()
            }
            self.actionSheet = actionSheet
            view.updateIsProgressPaused()
            
            component.presentController(actionSheet, nil)
        } else {
            var preferredAction: ShareControllerPreferredAction?
            if focusedItem.storyItem.isPublic && !component.slice.peer.isService {
                preferredAction = .custom(action: ShareControllerAction(title: component.strings.Story_Context_CopyLink, action: {
                    let _ = ((component.context.engine.messages.exportStoryLink(peerId: peerId, id: focusedItem.storyItem.id))
                             |> deliverOnMainQueue).start(next: { link in
                        if let link {
                            UIPasteboard.general.string = link
                            
                            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
                            component.presentController(UndoOverlayController(
                                presentationData: presentationData,
                                content: .linkCopied(text: presentationData.strings.Story_ToastLinkCopied),
                                elevatedLayout: false,
                                animateInAsReplacement: false,
                                action: { _ in return false }
                            ), nil)
                        }
                    })
                }))
            }
            
            let shareController = ShareController(
                context: component.context,
                subject: .media(AnyMediaReference.standalone(media: TelegramMediaStory(storyId: StoryId(peerId: peerId, id: focusedItem.storyItem.id), isMention: false))),
                preferredAction: preferredAction ?? .default,
                externalShare: false,
                immediateExternalShare: false,
                forceTheme: defaultDarkColorPresentationTheme
            )
            
            shareController.completed = { [weak view] peerIds in
                guard let view, let component = view.component else {
                    return
                }
                
                let _ = (component.context.engine.data.get(
                    EngineDataList(
                        peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                    )
                )
                         |> deliverOnMainQueue).start(next: { [weak view] peerList in
                    guard let view, let component = view.component else {
                        return
                    }
                    
                    let peers = peerList.compactMap { $0 }
                    let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                    let text: String
                    var savedMessages = false
                    if peerIds.count == 1, let peerId = peerIds.first, peerId == component.context.account.peerId {
                        text = presentationData.strings.Conversation_StoryForwardTooltip_SavedMessages_One
                        savedMessages = true
                    } else {
                        if peers.count == 1, let peer = peers.first {
                            var peerName = peer.id == component.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            peerName = peerName.replacingOccurrences(of: "**", with: "")
                            text = presentationData.strings.Conversation_StoryForwardTooltip_Chat_One(peerName).string
                        } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                            var firstPeerName = firstPeer.id == component.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            firstPeerName = firstPeerName.replacingOccurrences(of: "**", with: "")
                            var secondPeerName = secondPeer.id == component.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            secondPeerName = secondPeerName.replacingOccurrences(of: "**", with: "")
                            text = presentationData.strings.Conversation_StoryForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string
                        } else if let peer = peers.first {
                            var peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            peerName = peerName.replacingOccurrences(of: "**", with: "")
                            text = presentationData.strings.Conversation_StoryForwardTooltip_ManyChats_One(peerName, "\(peers.count - 1)").string
                        } else {
                            text = ""
                        }
                    }
                    
                    if let controller = component.controller() {
                        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                        controller.present(UndoOverlayController(
                            presentationData: presentationData,
                            content: .forward(savedMessages: savedMessages, text: text),
                            elevatedLayout: false,
                            animateInAsReplacement: false,
                            action: { _ in return false }
                        ), in: .current)
                    }
                })
            }
            
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
    }
    
    func performShareTextAction(view: StoryItemSetContainerComponent.View, text: String) {
        guard let component = view.component else {
            return
        }
        guard let controller = component.controller() else {
            return
        }
        
        let theme = component.theme
        let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>) = (component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: theme), component.context.sharedContext.presentationData |> map { $0.withUpdated(theme: theme) })
        
        let shareController = ShareController(context: component.context, subject: .text(text), externalShare: true, immediateExternalShare: false, updatedPresentationData: updatedPresentationData)
        
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
    
    func performTranslateTextAction(view: StoryItemSetContainerComponent.View, text: String) {
        guard let component = view.component else {
            return
        }
        
        let _ = (component.context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.translationSettings])
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self, weak view] sharedData in
            guard let self, let view else {
                return
            }
            let peer = component.slice.peer
            
            let _ = self
            
            let translationSettings: TranslationSettings
            if let current = sharedData.entries[ApplicationSpecificSharedDataKeys.translationSettings]?.get(TranslationSettings.self) {
                translationSettings = current
            } else {
                translationSettings = TranslationSettings.defaultSettings
            }
            
            var showTranslateIfTopical = false
            if case let .channel(channel) = peer, !(channel.addressName ?? "").isEmpty {
                showTranslateIfTopical = true
            }
            
            let (_, language) = canTranslateText(context: component.context, text: text, showTranslate: translationSettings.showTranslate, showTranslateIfTopical: showTranslateIfTopical, ignoredLanguages: translationSettings.ignoredLanguages)
            
            let _ = ApplicationSpecificNotice.incrementTranslationSuggestion(accountManager: component.context.sharedContext.accountManager, timestamp: Int32(Date().timeIntervalSince1970)).start()
            
            let translateController = TranslateScreen(context: component.context, forceTheme: defaultDarkPresentationTheme, text: text, canCopy: true, fromLanguage: language, ignoredLanguages: translationSettings.ignoredLanguages)
            translateController.pushController = { [weak view] c in
                guard let view, let component = view.component else {
                    return
                }
                component.controller()?.push(c)
            }
            translateController.presentController = { [weak view] c in
                guard let view, let component = view.component else {
                    return
                }
                component.controller()?.present(c, in: .window(.root))
            }
            
            self.actionSheet = translateController
            view.updateIsProgressPaused()
            
            translateController.wasDismissed = { [weak self, weak view] in
                guard let self, let view else {
                    return
                }
                self.actionSheet = nil
                view.updateIsProgressPaused()
            }
            
            component.controller()?.present(translateController, in: .window(.root))
        })
    }
    
    func performLookupTextAction(view: StoryItemSetContainerComponent.View, text: String) {
        guard let component = view.component else {
            return
        }
        let controller = UIReferenceLibraryViewController(term: text)
        if let window = component.controller()?.view.window {
            controller.popoverPresentationController?.sourceView = window
            controller.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: window.bounds.width / 2.0, y: window.bounds.size.height - 1.0), size: CGSize(width: 1.0, height: 1.0))
            window.rootViewController?.present(controller, animated: true)
            
            final class DeinitWatcher: NSObject {
                let f: () -> Void
                
                init(_ f: @escaping () -> Void) {
                    self.f = f
                }
                
                deinit {
                    f()
                }
            }
            
            self.lookupController = controller
            view.updateIsProgressPaused()
            
            objc_setAssociatedObject(controller, &ObjCKey_DeinitWatcher, DeinitWatcher { [weak self, weak view] in
                guard let self, let view else {
                    return
                }
                
                self.lookupController = nil
                view.updateIsProgressPaused()
            }, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    func performCopyLinkAction(view: StoryItemSetContainerComponent.View) {
        guard let component = view.component else {
            return
        }
        
        let _ = (component.context.engine.messages.exportStoryLink(peerId: component.slice.peer.id, id: component.slice.item.storyItem.id)
        |> deliverOnMainQueue).start(next: { [weak view] link in
            guard let view, let component = view.component else {
                return
            }
            if let link {
                UIPasteboard.general.string = link
                
                let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: component.theme)
                component.presentController(UndoOverlayController(
                    presentationData: presentationData,
                    content: .linkCopied(text: presentationData.strings.Story_ToastLinkCopied),
                    elevatedLayout: false,
                    animateInAsReplacement: false,
                    action: { _ in return false }
                ), nil)
            }
        })
    }
    
    private func clearInputText(view: StoryItemSetContainerComponent.View) {
        guard let inputPanelView = view.inputPanel.view as? MessageInputPanelComponent.View else {
            return
        }
        inputPanelView.clearSendMessageInput(updateState: true)
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
            inputText = text
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
            
            self.currentInputMode = .text
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
                            let button: AttachmentButtonType = .app(bot)
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
                            |> deliverOnMainQueue).start(next: { [weak self, weak view] messageIds in
                                if let self, let view {
                                    Queue.mainQueue().after(0.3) {
                                        self.presentMessageSentTooltip(view: view, peer: peer, messageId: messageIds.first.flatMap { $0 })
                                    }
                                }
                            })
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
                            let controller = LocationPickerController(context: component.context, updatedPresentationData: updatedPresentationData, mode: .share(peer: peer, selfPeer: selfPeer, hasLiveLocation: hasLiveLocation), completion: { [weak self, weak view] location, _, _, _, _ in
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
                                
                                self.sendMessages(view: view, peer: peer, messages: enqueueMessages, silentPosting: silent, scheduleTime: scheduleTime)
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
                                        
                                        self.sendMessages(view: view, peer: targetPeer, messages: enqueueMessages, silentPosting: silent, scheduleTime: scheduleTime)
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
                                                
                                                self.sendMessages(view: view, peer: targetPeer, messages: enqueueMessages, silentPosting: silent, scheduleTime: scheduleTime)
                                            }
                                        }), completed: nil, cancelled: nil)
                                        component.controller()?.push(contactController)
                                    }
                                }))
                            }
                        }))
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
                    case let .app(bot):
                        let params = WebAppParameters(source: .attachMenu, peerId: peer.id, botId: bot.peer.id, botName: bot.shortName, url: nil, queryId: nil, payload: nil, buttonText: nil, keepAliveSignal: nil, forceHasSettings: false)
                        let theme = component.theme
                        let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>) = (component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: theme), component.context.sharedContext.presentationData |> map { $0.withUpdated(theme: theme) })
                        let controller = WebAppController(context: component.context, updatedPresentationData: updatedPresentationData, params: params, replyToMessageId: nil, threadId: nil)
                        controller.openUrl = { [weak self] url, _, _ in
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
            self.presentWebSearch(view: view, activateOnDisplay: activateOnDisplay, present: { [weak controller] c, a in
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
        controller.getCaptionPanelView = { [weak self, weak controller, weak view] in
            guard let self, let view, let controller else {
                return nil
            }
            return self.getCaptionPanelView(view: view, peer: peer, mediaPicker: controller)
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
            inputText = text
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
    
    func presentMediaPasteboard(view: StoryItemSetContainerComponent.View, subjects: [MediaPickerScreen.Subject.Media]) {
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
            inputText = text
        }
        
        let peer = component.slice.peer
        let theme = defaultDarkPresentationTheme
        let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>) = (component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: theme), component.context.sharedContext.presentationData |> map { $0.withUpdated(theme: theme) })
        let controller = mediaPasteboardScreen(
            context: component.context,
            updatedPresentationData: updatedPresentationData,
            peer: peer,
            subjects: subjects,
            presentMediaPicker: { [weak self] subject, saveEditedPhotos, bannedSendPhotos, bannedSendVideos, present in
                if let self {
                    self.presentMediaPicker(
                        view: view,
                        peer: peer,
                        replyToMessageId: nil,
                        replyToStoryId: focusedStoryId,
                        subject: subject,
                        saveEditedPhotos: saveEditedPhotos,
                        bannedSendPhotos: bannedSendPhotos,
                        bannedSendVideos: bannedSendVideos,
                        present: { controller, mediaPickerContext in
                            if !inputText.string.isEmpty {
                                mediaPickerContext?.setCaption(inputText)
                            }
                            present(controller, mediaPickerContext)
                        },
                        updateMediaPickerContext: { _ in },
                        completion: { [weak self, weak view] signals, silentPosting, scheduleTime, getAnimatedTransitionSource, completion in
                            guard let self, let view else {
                                return
                            }
                            if !inputText.string.isEmpty {
                                self.clearInputText(view: view)
                            }
                            self.enqueueMediaMessages(view: view, peer: peer, replyToMessageId: nil, replyToStoryId: focusedStoryId, signals: signals, silentPosting: silentPosting, scheduleTime: scheduleTime, getAnimatedTransitionSource: getAnimatedTransitionSource, completion: completion)
                        }
                    )
                }
            },
            getSourceRect: nil
        )
        controller.navigationPresentation = .flatModal
        component.controller()?.push(controller)
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
    
    private func presentWebSearch(view: StoryItemSetContainerComponent.View, activateOnDisplay: Bool = true, present: @escaping (ViewController, Any?) -> Void) {
        guard let component = view.component else {
            return
        }
        let context = component.context
        let peer = component.slice.peer
        let storyId = component.slice.item.storyItem.id
        
        let theme = component.theme
        let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>) = (component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: theme), component.context.sharedContext.presentationData |> map { $0.withUpdated(theme: theme) })
         
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Configuration.SearchBots())
        |> deliverOnMainQueue).start(next: { [weak self, weak view] configuration in
            if let self {
                let controller = WebSearchController(context: context, updatedPresentationData: updatedPresentationData, peer: peer, chatLocation: .peer(id: peer.id), configuration: configuration, mode: .media(attachment: true, completion: { [weak self] results, selectionState, editingState, silentPosting in
                    legacyEnqueueWebSearchMessages(selectionState, editingState, enqueueChatContextResult: { [weak self, weak view] result in
                        if let self, let view {
                            self.performSendContextResultAction(view: view, results: results, result: result)
                        }
                    }, enqueueMediaMessages: { [weak self, weak view] signals in
                        if let self, let view, !signals.isEmpty {
                            self.enqueueMediaMessages(view: view, peer: peer, replyToMessageId: nil, replyToStoryId: StoryId(peerId: peer.id, id: storyId), signals: signals, silentPosting: false)
                        }
                    })
                }), activateOnDisplay: activateOnDisplay)
                controller.getCaptionPanelView = { [weak self, weak view] in
                    if let view {
                        return self?.getCaptionPanelView(view: view, peer: peer)
                    } else {
                        return nil
                    }
                }
                present(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }
        })
    }
    
    private func getCaptionPanelView(view: StoryItemSetContainerComponent.View, peer: EnginePeer, mediaPicker: MediaPickerScreen? = nil) -> TGCaptionPanelView? {
        guard let component = view.component else {
            return nil
        }
        //TODO:self.presentationInterfaceState.customEmojiAvailable
        return component.context.sharedContext.makeGalleryCaptionPanelView(context: component.context, chatLocation: .peer(id: peer.id), isScheduledMessages: false, customEmojiAvailable: true, present: { [weak view] c in
            guard let view else {
                return
            }
            view.component?.controller()?.present(c, in: .window(.root))
        }, presentInGlobalOverlay: { [weak view] c in
            guard let view else {
                return
            }
            if let c = c as? PremiumIntroScreen {
                view.endEditing(true)
                if let mediaPicker {
                    mediaPicker.closeGalleryController()
                }
                if let attachmentController = self.attachmentController {
                    self.attachmentController = nil
                    attachmentController.dismiss(animated: false, completion: nil)
                }
                c.wasDismissed = { [weak view] in
                    guard let view else {
                        return
                    }
                    view.updateIsProgressPaused()
                }
                view.component?.controller()?.push(c)
                
                view.updateIsProgressPaused()
            } else {
                view.component?.controller()?.presentInGlobalOverlay(c)
            }
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
            inputText = text
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
    
    private func sendMessages(view: StoryItemSetContainerComponent.View, peer: EnginePeer, messages: [EnqueueMessage], silentPosting: Bool = false, scheduleTime: Int32? = nil) {
        guard let component = view.component else {
            return
        }
        let _ = (enqueueMessages(account: component.context.account, peerId: peer.id, messages: self.transformEnqueueMessages(view: view, messages: messages, silentPosting: silentPosting, scheduleTime: scheduleTime))
        |> deliverOnMainQueue).start(next: { [weak self, weak view] messageIds in
            Queue.mainQueue().after(0.3) {
                if let view {
                    self?.presentMessageSentTooltip(view: view, peer: peer, messageId: messageIds.first.flatMap { $0 }, isScheduled: scheduleTime != nil)
                }
            }
        })
        
        donateSendMessageIntent(account: component.context.account, sharedContext: component.context.sharedContext, intentContext: .chat, peerIds: [peer.id])
        
        if let attachmentController = self.attachmentController {
            attachmentController.dismiss(animated: true)
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

                strongSelf.sendMessages(view: view, peer: peer, messages: mappedMessages.map { $0.withUpdatedReplyToMessageId(replyToMessageId).withUpdatedReplyToStoryId(replyToStoryId) }, silentPosting: silentPosting, scheduleTime: scheduleTime)
                
                completion()
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
    
    func openResolved(view: StoryItemSetContainerComponent.View, result: ResolvedUrl, forceExternal: Bool = false, concealed: Bool = false) {
        guard let component = view.component, let navigationController = component.controller()?.navigationController as? NavigationController else {
            return
        }
        let peerId = component.slice.peer.id
        component.context.sharedContext.openResolvedUrl(result, context: component.context, urlContext: .chat(peerId: peerId, updatedPresentationData: nil), navigationController: navigationController, forceExternal: forceExternal, openPeer: { [weak self, weak view] peerId, navigation in
            guard let self, let view, let component = view.component, let controller = component.controller() as? StoryContainerScreen else {
                return
            }
            
            switch navigation {
            case let .chat(_, subject, peekData):
                if let navigationController = controller.navigationController as? NavigationController {
                    if case let .channel(channel) = peerId, channel.flags.contains(.isForum) {
                        controller.dismissWithoutTransitionOut()
                        component.context.sharedContext.navigateToForumChannel(context: component.context, peerId: peerId.id, navigationController: navigationController)
                    } else {
                        component.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: component.context, chatLocation: .peer(peerId), subject: subject, keepStack: .always, peekData: peekData, pushController: { [weak controller, weak navigationController] chatController, animated, completion in
                            guard let controller, let navigationController else {
                                return
                            }
                            if "".isEmpty {
                                navigationController.pushViewController(chatController)
                            } else {
                                var viewControllers = navigationController.viewControllers
                                if let index = viewControllers.firstIndex(where: { $0 === controller }) {
                                    viewControllers.insert(chatController, at: index)
                                } else {
                                    viewControllers.append(chatController)
                                }
                                navigationController.setViewControllers(viewControllers, animated: animated)
                            }
                        }))
                    }
                }
            case .info:
                self.navigationActionDisposable.set((component.context.account.postbox.loadedPeerWithId(peerId.id)
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak view] peer in
                    guard let view, let component = view.component else {
                        return
                    }
                    if peer.restrictionText(platform: "ios", contentSettings: component.context.currentContentSettings.with { $0 }) == nil {
                        if let infoController = component.context.sharedContext.makePeerInfoController(context: component.context, updatedPresentationData: nil, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                            component.controller()?.push(infoController)
                        }
                    }
                }))
            case let .withBotStartPayload(startPayload):
                if let navigationController = controller.navigationController as? NavigationController {
                    component.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: component.context, chatLocation: .peer(peerId), botStart: startPayload, keepStack: .always))
                }
            case let .withAttachBot(attachBotStart):
                if let navigationController = controller.navigationController as? NavigationController {
                    component.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: component.context, chatLocation: .peer(peerId), attachBotStart: attachBotStart))
                }
            default:
                break
            }
        },
        sendFile: nil,
        sendSticker: nil,
        requestMessageActionUrlAuth: nil,
        joinVoiceChat: nil,
        present: { [weak view] c, a in
            guard let view, let component = view.component, let controller = component.controller() else {
                return
            }
            controller.present(c, in: .window(.root), with: a)
        }, dismissInput: { [weak view] in
            guard let view else {
                return
            }
            view.endEditing(true)
        },
        contentContext: nil
        )
    }
    
    func navigateToMessage(view: StoryItemSetContainerComponent.View, messageId: EngineMessage.Id, completion: (() -> Void)?) {
        guard let component = view.component else {
            return
        }
        let _ = (component.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: messageId.peerId))
        |> deliverOnMainQueue).start(next: { [weak view] peer in
            guard let view, let component = view.component, let controller = component.controller(), let peer = peer else {
                return
            }
            if let navigationController = controller.navigationController as? NavigationController {
                component.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: component.context, chatLocation: .peer(peer), subject: .message(id: .id(messageId), highlight: true, timecode: nil)))
            }
            completion?()
        })
    }
    
    func openPeerMention(view: StoryItemSetContainerComponent.View, name: String, sourceMessageId: MessageId? = nil) {
        guard let component = view.component, let parentController = component.controller() else {
            return
        }
        let disposable = self.resolvePeerByNameDisposable
        var resolveSignal = component.context.engine.peers.resolvePeerByName(name: name, ageLimit: 10)
        
        var cancelImpl: (() -> Void)?
        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
        let progressSignal = Signal<Never, NoError> { [weak self, weak view, weak parentController] subscriber in
            let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                cancelImpl?()
            }))
            parentController?.present(controller, in: .window(.root))
            
            self?.statusController = controller
            view?.updateIsProgressPaused()
            
            return ActionDisposable { [weak controller] in
                Queue.mainQueue().async() {
                    controller?.dismiss()
                    
                    self?.statusController = nil
                    view?.updateIsProgressPaused()
                }
            }
        }
        |> runOn(Queue.mainQueue())
        |> delay(0.15, queue: Queue.mainQueue())
        let progressDisposable = progressSignal.start()
        
        resolveSignal = resolveSignal
        |> afterDisposed {
            Queue.mainQueue().async {
                progressDisposable.dispose()
            }
        }
        cancelImpl = { [weak self] in
            guard let self else {
                return
            }
            self.resolvePeerByNameDisposable.set(nil)
        }
        disposable.set((resolveSignal
        |> take(1)
        |> mapToSignal { peer -> Signal<Peer?, NoError> in
            return .single(peer?._asPeer())
        }
        |> deliverOnMainQueue).start(next: { [weak view] peer in
            guard let view, let component = view.component else {
                return
            }
            if let peer = peer {
                var navigation: ChatControllerInteractionNavigateToPeer
                if let peer = peer as? TelegramUser, peer.botInfo == nil {
                    navigation = .info
                } else {
                    navigation = .chat(textInputState: nil, subject: nil, peekData: nil)
                }
                self.openResolved(view: view, result: .peer(peer, navigation))
            } else {
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                component.controller()?.present(textAlertController(context: component.context, updatedPresentationData: nil, title: nil, text: presentationData.strings.Resolve_ErrorNotFound, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
            }
        }))
    }
    
    func openHashtag(view: StoryItemSetContainerComponent.View, hashtag: String, peerName: String?) {
        guard let component = view.component, let parentController = component.controller() else {
            return
        }
        
        let peerId = component.slice.peer.id
        
        var resolveSignal: Signal<Peer?, NoError>
        if let peerName = peerName {
            resolveSignal = component.context.engine.peers.resolvePeerByName(name: peerName)
            |> mapToSignal { peer -> Signal<Peer?, NoError> in
                if let peer = peer {
                    return .single(peer._asPeer())
                } else {
                    return .single(nil)
                }
            }
        } else {
            resolveSignal = component.context.account.postbox.loadedPeerWithId(peerId)
            |> map(Optional.init)
        }
        var cancelImpl: (() -> Void)?
        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
        let progressSignal = Signal<Never, NoError> { [weak parentController, weak self, weak view] subscriber in
            let controller = OverlayStatusController(theme: presentationData.theme,  type: .loading(cancelled: {
                cancelImpl?()
            }))
            parentController?.present(controller, in: .window(.root))
            
            self?.statusController = controller
            view?.updateIsProgressPaused()
            
            return ActionDisposable { [weak controller] in
                Queue.mainQueue().async() {
                    controller?.dismiss()
                    
                    self?.statusController = nil
                    view?.updateIsProgressPaused()
                }
            }
        }
        |> runOn(Queue.mainQueue())
        |> delay(0.15, queue: Queue.mainQueue())
        let progressDisposable = progressSignal.start()
        
        resolveSignal = resolveSignal
        |> afterDisposed {
            Queue.mainQueue().async {
                progressDisposable.dispose()
            }
        }
        cancelImpl = { [weak self] in
            guard let self else {
                return
            }
            self.resolvePeerByNameDisposable.set(nil)
        }
        self.resolvePeerByNameDisposable.set((resolveSignal
        |> deliverOnMainQueue).start(next: { [weak view] peer in
            guard let view, let component = view.component else {
                return
            }
            guard let navigationController = component.controller()?.navigationController as? NavigationController else {
                return
            }
            if !hashtag.isEmpty {
                let searchController = component.context.sharedContext.makeHashtagSearchController(context: component.context, peer: peer.flatMap(EnginePeer.init), query: hashtag, all: true)
                navigationController.pushViewController(searchController)
            }
        }))
    }
    
    func openPeerMention(view: StoryItemSetContainerComponent.View, peerId: EnginePeer.Id) {
        guard let component = view.component else {
            return
        }
        let _ = (component.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        |> deliverOnMainQueue).start(next: { [weak self, weak view] peer in
            guard let self, let view, let peer else {
                return
            }
            self.openPeer(view: view, peer: peer)
        })
    }
    
    func openPeer(view: StoryItemSetContainerComponent.View, peer: EnginePeer, expandAvatar: Bool = false, peerTypes: ReplyMarkupButtonAction.PeerTypes? = nil) {
        guard let component = view.component else {
            return
        }
        
        let peerSignal: Signal<Peer?, NoError> = component.context.account.postbox.loadedPeerWithId(peer.id) |> map(Optional.init)
        self.navigationActionDisposable.set((peerSignal |> take(1) |> deliverOnMainQueue).start(next: { [weak view] peer in
            guard let view, let component = view.component, let peer else {
                return
            }
            let mode: PeerInfoControllerMode = .generic
            var expandAvatar = expandAvatar
            if peer.smallProfileImage == nil {
                expandAvatar = false
            }
            if component.metrics.widthClass == .regular {
                expandAvatar = false
            }
            if let infoController = component.context.sharedContext.makePeerInfoController(context: component.context, updatedPresentationData: nil, peer: peer, mode: mode, avatarInitiallyExpanded: expandAvatar, fromChat: false, requestsContext: nil) {
                component.controller()?.push(infoController)
            }
        }))
    }
    
    func presentTextEntityActions(view: StoryItemSetContainerComponent.View, action: StoryContentCaptionComponent.Action, openUrl: @escaping (String, Bool) -> Void) {
        guard let component = view.component else {
            return
        }
                
        let actionSheet = ActionSheetController(theme: ActionSheetControllerTheme(presentationTheme: component.theme, fontSize: .regular), allowInputInset: false)
        
        var canOpenIn = false
        
        let title: String
        let value: String
        var openAction: String? = component.strings.Conversation_LinkDialogOpen
        var copyAction = component.strings.Conversation_ContextMenuCopy
        switch action {
        case let .url(url, _):
            title = url
            value = url
            canOpenIn = availableOpenInOptions(context: component.context, item: .url(url: url)).count > 1
            if canOpenIn {
                openAction = component.strings.Conversation_FileOpenIn
            }
            copyAction = component.strings.Conversation_ContextMenuCopyLink
        case let .hashtag(_, hashtag):
            title = hashtag
            value = hashtag
        case let .bankCard(bankCard):
            title = bankCard
            value = bankCard
            openAction = nil
        case let .peerMention(_, mention):
            title = mention
            value = mention
        case let .textMention(mention):
            title = mention
            value = mention
        case .customEmoji:
            return
        }
        
        var items: [ActionSheetItem] = []
        items.append(ActionSheetTextItem(title: title))
        
        if let openAction {
            items.append(ActionSheetButtonItem(title: openAction, color: .accent, action: { [weak self, weak view, weak actionSheet] in
                actionSheet?.dismissAnimated()
                if let self, let view {
                    switch action {
                    case let .url(url, concealed):
                        if canOpenIn {
                            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                            let actionSheet = OpenInActionSheetController(context: component.context, item: .url(url: url), openUrl: { url in
                                if let navigationController = component.controller()?.navigationController as? NavigationController {
                                    component.context.sharedContext.openExternalUrl(context: component.context, urlContext: .generic, url: url, forceExternal: true, presentationData: presentationData, navigationController: navigationController, dismissInput: {})
                                }
                            })
                            component.controller()?.present(actionSheet, in: .window(.root))
                        } else {
                            openUrl(url, concealed)
                        }
                    case let .hashtag(peerName, value):
                        self.openHashtag(view: view, hashtag: value, peerName: peerName)
                    case let .peerMention(peerId, _):
                        self.openPeerMention(view: view, peerId: peerId)
                    case let .textMention(mention):
                        self.openPeerMention(view: view, name: mention)
                    case .customEmoji, .bankCard:
                        return
                    }
                }
            }))
        }
        
        items.append(ActionSheetButtonItem(title: copyAction, color: .accent, action: { [weak actionSheet] in
            actionSheet?.dismissAnimated()
            UIPasteboard.general.string = value
        }))
        
        if case let .url(url, _) = action, let link = URL(string: url) {
            items.append(ActionSheetButtonItem(title: component.strings.Conversation_AddToReadingList, color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                let _ = try? SSReadingList.default()?.addItem(with: link, title: nil, previewText: nil)
            }))
        }
        
        actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: component.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        actionSheet.dismissed = { [weak self, weak view] _ in
            guard let self, let view else {
                return
            }
            self.actionSheet = nil
            view.updateIsProgressPaused()
        }
        
        component.controller()?.present(actionSheet, in: .window(.root))
        
        self.actionSheet = actionSheet
        view.updateIsProgressPaused()
    }
    
    func openAttachedStickers(view: StoryItemSetContainerComponent.View, packs: Signal<[StickerPackReference], NoError>) {
        guard let component = view.component else {
            return
        }
        
        guard let parentController = component.controller() as? StoryContainerScreen else {
            return
        }
        let context = component.context
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkPresentationTheme)
        let progressSignal = Signal<Never, NoError> { [weak parentController, weak self, weak view] subscriber in
            let progressController = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
            parentController?.present(progressController, in: .window(.root), with: nil)
            
            self?.statusController = progressController
            view?.updateIsProgressPaused()
            
            return ActionDisposable { [weak progressController] in
                Queue.mainQueue().async() {
                    progressController?.dismiss()
                    
                    self?.statusController = nil
                    view?.updateIsProgressPaused()
                }
            }
        }
        |> runOn(Queue.mainQueue())
        |> delay(0.15, queue: Queue.mainQueue())
        let progressDisposable = progressSignal.start()
        
        let signal = packs
        |> afterDisposed {
            Queue.mainQueue().async {
                progressDisposable.dispose()
            }
        }
        let _ = (signal
        |> deliverOnMainQueue).start(next: { [weak parentController] packs in
            guard !packs.isEmpty else {
                return
            }
            let controller = StickerPackScreen(context: context, updatedPresentationData: (presentationData, .single(presentationData)), mainStickerPack: packs[0], stickerPacks: packs, sendSticker: nil, actionPerformed: { actions in
                if let (info, items, action) = actions.first {
                    let animateInAsReplacement = false
                    switch action {
                    case .add:
                        parentController?.present(UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: presentationData.strings.StickerPackActionInfo_AddedTitle, text: presentationData.strings.StickerPackActionInfo_AddedText(info.title).string, undo: false, info: info, topItem: items.first, context: context), elevatedLayout: true, animateInAsReplacement: animateInAsReplacement, action: { _ in
                            return true
                        }), in: .window(.root))
                    case let .remove(positionInList):
                        parentController?.present(UndoOverlayController(presentationData: presentationData, content: .stickersModified(title: presentationData.strings.StickerPackActionInfo_RemovedTitle, text: presentationData.strings.StickerPackActionInfo_RemovedText(info.title).string, undo: true, info: info, topItem: items.first, context: context), elevatedLayout: true, animateInAsReplacement: animateInAsReplacement, action: { action in
                            if case .undo = action {
                                let _ = context.engine.stickers.addStickerPackInteractively(info: info, items: items, positionInList: positionInList).start()
                            }
                            return true
                        }), in: .window(.root))
                    }
                }
            }, dismissed: { [weak self, weak view] in
                guard let self, let view else {
                    return
                }
                self.isViewingAttachedStickers = false
                view.updateIsProgressPaused()
            })
            parentController?.present(controller, in: .window(.root), with: nil)
        })
        
        self.isViewingAttachedStickers = true
        view.updateIsProgressPaused()
    }
    
    func requestStealthMode(view: StoryItemSetContainerComponent.View) {
        guard let component = view.component else {
            return
        }
        
        let _ = (component.context.engine.data.get(
            TelegramEngine.EngineData.Item.Configuration.StoryConfigurationState(),
            TelegramEngine.EngineData.Item.Configuration.App()
        )
        |> deliverOnMainQueue).start(next: { [weak self, weak view] config, appConfig in
            guard let self, let view, let component = view.component, let controller = component.controller() else {
                return
            }
            
            let timestamp = Int32(Date().timeIntervalSince1970)
            if let activeUntilTimestamp = config.stealthModeState.actualizedNow().activeUntilTimestamp, activeUntilTimestamp > timestamp {
                let remainingActiveSeconds = activeUntilTimestamp - timestamp
                
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkPresentationTheme)
                let text = component.strings.Story_ToastStealthModeActiveText(timeIntervalString(strings: presentationData.strings, value: remainingActiveSeconds)).string
                let tooltipScreen = UndoOverlayController(
                    presentationData: presentationData,
                    content: .actionSucceeded(title: component.strings.Story_ToastStealthModeActiveTitle, text: text, cancel: "", destructive: false),
                    elevatedLayout: false,
                    animateInAsReplacement: false,
                    action: { _ in
                        return false
                    }
                )
                tooltipScreen.tag = "no_auto_dismiss"
                weak var tooltipScreenValue: UndoOverlayController? = tooltipScreen
                self.currentTooltipUpdateTimer?.invalidate()
                self.currentTooltipUpdateTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { [weak self, weak view] _ in
                    guard let self, let view, let component = view.component else {
                        return
                    }
                    guard let tooltipScreenValue else {
                        self.currentTooltipUpdateTimer?.invalidate()
                        self.currentTooltipUpdateTimer = nil
                        return
                    }
                    
                    let timestamp = Int32(Date().timeIntervalSince1970)
                    let remainingActiveSeconds = max(1, activeUntilTimestamp - timestamp)
                    
                    let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkPresentationTheme)
                    let text = component.strings.Story_ToastStealthModeActiveText(timeIntervalString(strings: presentationData.strings, value: remainingActiveSeconds)).string
                    tooltipScreenValue.content = .actionSucceeded(title: component.strings.Story_ToastStealthModeActiveTitle, text: text, cancel: "", destructive: false)
                })
                
                self.tooltipScreen?.dismiss(animated: true)
                self.tooltipScreen = tooltipScreen
                controller.present(tooltipScreen, in: .current)
                
                view.updateIsProgressPaused()
                
                return
            }
            
            let pastPeriod: Int32
            let futurePeriod: Int32
            if let data = appConfig.data, let futurePeriodF = data["stories_stealth_future_period"] as? Double, let pastPeriodF = data["stories_stealth_past_period"] as? Double {
                futurePeriod = Int32(futurePeriodF)
                pastPeriod = Int32(pastPeriodF)
            } else {
                pastPeriod = 5 * 60
                futurePeriod = 25 * 60
            }
            
            let sheet = StoryStealthModeSheetScreen(
                context: component.context,
                mode: .control(cooldownUntilTimestamp: config.stealthModeState.actualizedNow().cooldownUntilTimestamp),
                backwardDuration: pastPeriod,
                forwardDuration: futurePeriod,
                buttonAction: { [weak self, weak view] in
                    guard let self, let view, let component = view.component else {
                        return
                    }
                    
                    let _ = (component.context.engine.messages.enableStoryStealthMode()
                    |> deliverOnMainQueue).start(completed: { [weak self, weak view] in
                        guard let self, let view, let component = view.component, let controller = component.controller() else {
                            return
                        }
                        
                        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkPresentationTheme)
                        let text = component.strings.Story_ToastStealthModeActivatedText(timeIntervalString(strings: presentationData.strings, value: pastPeriod), timeIntervalString(strings: presentationData.strings, value: futurePeriod)).string
                        let tooltipScreen = UndoOverlayController(
                            presentationData: presentationData,
                            content: .actionSucceeded(title: component.strings.Story_ToastStealthModeActivatedTitle, text: text, cancel: "", destructive: false),
                            elevatedLayout: false,
                            animateInAsReplacement: false,
                            action: { _ in
                                return false
                            }
                        )
                        self.tooltipScreen?.dismiss(animated: true)
                        self.tooltipScreen = tooltipScreen
                        controller.present(tooltipScreen, in: .current)
                        
                        view.updateIsProgressPaused()
                        
                        HapticFeedback().success()
                    })
                }
            )
            sheet.wasDismissed = { [weak self, weak view] in
                guard let self, let view else {
                    return
                }
                self.actionSheet = nil
                view.updateIsProgressPaused()
            }
            self.actionSheet = sheet
            view.updateIsProgressPaused()
            controller.push(sheet)
        })
    }
    
    func presentStealthModeUpgrade(view: StoryItemSetContainerComponent.View, action: @escaping () -> Void) {
        guard let component = view.component else {
            return
        }
        
        let _ = (component.context.engine.data.get(
            TelegramEngine.EngineData.Item.Configuration.StoryConfigurationState(),
            TelegramEngine.EngineData.Item.Configuration.App()
        )
        |> deliverOnMainQueue).start(next: { [weak self, weak view] config, appConfig in
            guard let self, let view, let component = view.component, let controller = component.controller() else {
                return
            }
            
            let pastPeriod: Int32
            let futurePeriod: Int32
            if let data = appConfig.data, let futurePeriodF = data["stories_stealth_future_period"] as? Double, let pastPeriodF = data["stories_stealth_past_period"] as? Double {
                futurePeriod = Int32(futurePeriodF)
                pastPeriod = Int32(pastPeriodF)
            } else {
                pastPeriod = 5 * 60
                futurePeriod = 25 * 60
            }
            
            let sheet = StoryStealthModeSheetScreen(
                context: component.context,
                mode: .upgrade,
                backwardDuration: pastPeriod,
                forwardDuration: futurePeriod,
                buttonAction: {
                    action()
                }
            )
            sheet.wasDismissed = { [weak self, weak view] in
                guard let self, let view else {
                    return
                }
                self.actionSheet = nil
                view.updateIsProgressPaused()
            }
            self.actionSheet = sheet
            view.updateIsProgressPaused()
            controller.push(sheet)
        })
    }
    
    func activateMediaArea(view: StoryItemSetContainerComponent.View, mediaArea: MediaArea) {
        guard let component = view.component, let controller = component.controller() else {
            return
        }
        
        let theme = defaultDarkColorPresentationTheme
        let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>) = (component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: theme), component.context.sharedContext.presentationData |> map { $0.withUpdated(theme: theme) })
        
        var actions: [ContextMenuAction] = []
        switch mediaArea {
        case let .venue(_, venue):
            let subject = EngineMessage(stableId: 0, stableVersion: 0, id: EngineMessage.Id(peerId: PeerId(0), namespace: 0, id: 0), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: nil, text: "", attributes: [], media: [.geo(TelegramMediaMap(latitude: venue.latitude, longitude: venue.longitude, heading: nil, accuracyRadius: nil, geoPlace: nil, venue: venue.venue, liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil))], peers: [:], associatedMessages: [:], associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
            
            let context = component.context
            actions.append(ContextMenuAction(content: .textWithIcon(title: "View Location", icon: generateTintedImage(image: UIImage(bundleImageName: "Settings/TextArrowRight"), color: .white)), action: { [weak controller, weak view] in
                let locationController = LocationViewController(
                    context: context,
                    updatedPresentationData: updatedPresentationData,
                    subject: subject,
                    isStoryLocation: true,
                    params: LocationViewParams(
                        sendLiveLocation: { _ in },
                        stopLiveLocation: { _ in },
                        openUrl: { url in
                            context.sharedContext.applicationBindings.openUrl(url)
                        },
                        openPeer: { _ in }
                    )
                )
                view?.updateModalTransitionFactor(1.0, transition: .animated(duration: 0.5, curve: .spring))
                locationController.dismissed = { [weak view] in
                    view?.updateModalTransitionFactor(0.0, transition: .animated(duration: 0.5, curve: .spring))
                    Queue.mainQueue().after(0.5, {
                        view?.updateIsProgressPaused()
                    })
                }
                controller?.push(locationController)
            }))
        }
        
        let referenceSize = view.controlsContainerView.frame.size
        let size = CGSize(width: 16.0, height: mediaArea.coordinates.height / 100.0 * referenceSize.height * 1.1)
        var frame = CGRect(x: mediaArea.coordinates.x / 100.0 * referenceSize.width - size.width / 2.0, y: mediaArea.coordinates.y / 100.0 * referenceSize.height - size.height / 2.0, width: size.width, height: size.height)
        frame = view.controlsContainerView.convert(frame, to: nil)
        
        let node = controller.displayNode
        let menuController = ContextMenuController(actions: actions, blurred: true)
        menuController.centerHorizontally = true
        menuController.dismissed = { [weak self, weak view] in
            if let self, let view {
                Queue.mainQueue().after(0.1) {
                    self.menuController = nil
                    view.updateIsProgressPaused()
                }
            }
        }
        controller.present(
            menuController,
            in: .window(.root),
            with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak node] in
                if let node {
                    return (node, frame, node, CGRect(origin: .zero, size: referenceSize).insetBy(dx: 0.0, dy: 64.0))
                } else {
                    return nil
                }
            })
        )
        self.menuController = menuController
        view.updateIsProgressPaused()
    }
}
