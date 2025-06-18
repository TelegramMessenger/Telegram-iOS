import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import Display
import AsyncDisplayKit
import TelegramCore
import SafariServices
import MobileCoreServices
import Intents
import LegacyComponents
import TelegramPresentationData
import TelegramUIPreferences
import DeviceAccess
import TextFormat
import TelegramBaseController
import AccountContext
import TelegramStringFormatting
import OverlayStatusController
import DeviceLocationManager
import ShareController
import UrlEscaping
import ContextUI
import ComposePollUI
import AlertUI
import PresentationDataUtils
import UndoUI
import TelegramCallsUI
import TelegramNotices
import GameUI
import ScreenCaptureDetection
import GalleryUI
import OpenInExternalAppUI
import LegacyUI
import InstantPageUI
import LocationUI
import BotPaymentsUI
import DeleteChatPeerActionSheetItem
import HashtagSearchUI
import LegacyMediaPickerUI
import Emoji
import PeerAvatarGalleryUI
import PeerInfoUI
import RaiseToListen
import UrlHandling
import AvatarNode
import AppBundle
import LocalizedPeerData
import PhoneNumberFormat
import SettingsUI
import UrlWhitelist
import TelegramIntents
import TooltipUI
import StatisticsUI
import MediaResources
import LocalMediaResources
import GalleryData
import ChatInterfaceState
import InviteLinksUI
import Markdown
import TelegramPermissionsUI
import Speak
import TranslateUI
import UniversalMediaPlayer
import WallpaperBackgroundNode
import ChatListUI
import CalendarMessageScreen
import ReactionSelectionNode
import ReactionListContextMenuContent
import AttachmentUI
import AttachmentTextInputPanelNode
import MediaPickerUI
import ChatPresentationInterfaceState
import Pasteboard
import ChatSendMessageActionUI
import ChatTextLinkEditUI
import WebUI
import PremiumUI
import ImageTransparency
import StickerPackPreviewUI
import TextNodeWithEntities
import EntityKeyboard
import ChatTitleView
import EmojiStatusComponent
import ChatTimerScreen
import MediaPasteboardUI
import ChatListHeaderComponent
import ChatControllerInteraction
import FeaturedStickersScreen
import ChatEntityKeyboardInputNode
import StorageUsageScreen
import AvatarEditorScreen
import ChatScheduleTimeController
import ICloudResources
import StoryContainerScreen
import MoreHeaderButton
import VolumeButtons
import ChatAvatarNavigationNode
import ChatContextQuery
import PeerReportScreen
import PeerSelectionController
import SaveToCameraRoll
import ChatMessageDateAndStatusNode
import ReplyAccessoryPanelNode
import TextSelectionNode
import ChatMessagePollBubbleContentNode
import ChatMessageItem
import ChatMessageItemImpl
import ChatMessageItemView
import ChatMessageItemCommon
import ChatMessageAnimatedStickerItemNode
import ChatMessageBubbleItemNode
import ChatNavigationButton
import WebsiteType
import PeerInfoScreen
import MediaEditorScreen
import WallpaperGalleryScreen
import WallpaperGridScreen
import VideoMessageCameraScreen
import TopMessageReactions
import AudioWaveform
import PeerNameColorScreen
import ChatEmptyNode
import ChatMediaInputStickerGridItem
import AdsInfoScreen

extension ChatControllerImpl {
    func requestAudioRecorder(beginWithTone: Bool, existingDraft: ChatInterfaceMediaDraftState.Audio? = nil) {
        if self.audioRecorderValue == nil {
            if self.recorderFeedback == nil && existingDraft == nil {
                self.recorderFeedback = HapticFeedback()
                self.recorderFeedback?.prepareImpact(.light)
            }
            
            var resumeData: AudioRecorderResumeData?
            if let existingDraft, let path = self.context.account.postbox.mediaBox.completedResourcePath(existingDraft.resource), let compressedData = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedIfSafe]), let recorderResumeData = existingDraft.resumeData {
                resumeData = AudioRecorderResumeData(compressedData: compressedData, resumeData: recorderResumeData)
            }
            
            self.audioRecorder.set(
                self.context.sharedContext.mediaManager.audioRecorder(
                    resumeData: resumeData,
                    beginWithTone: beginWithTone,
                    applicationBindings: self.context.sharedContext.applicationBindings,
                    beganWithTone: { _ in
                    }
                )
            )
        }
    }
    
    func requestVideoRecorder() {
        if self.videoRecorderValue == nil {
            if let currentInputPanelFrame = self.chatDisplayNode.currentInputPanelFrame() {
                if self.recorderFeedback == nil {
                    self.recorderFeedback = HapticFeedback()
                    self.recorderFeedback?.prepareImpact(.light)
                }
                
                var isScheduledMessages = false
                if case .scheduledMessages = self.presentationInterfaceState.subject {
                    isScheduledMessages = true
                }
                
                var isBot = false
                
                var allowLiveUpload = false
                var viewOnceAvailable = false
                if let peerId = self.chatLocation.peerId {
                    allowLiveUpload = peerId.namespace != Namespaces.Peer.SecretChat
                    viewOnceAvailable = !isScheduledMessages && peerId.namespace == Namespaces.Peer.CloudUser && peerId != self.context.account.peerId && !isBot && self.presentationInterfaceState.sendPaidMessageStars == nil
                } else if case .customChatContents = self.chatLocation {
                    allowLiveUpload = true
                }
                
                if let user = self.presentationInterfaceState.renderedPeer?.peer as? TelegramUser, user.botInfo != nil {
                    isBot = true
                }
                
                let controller = VideoMessageCameraScreen(
                    context: self.context,
                    updatedPresentationData: self.updatedPresentationData,
                    allowLiveUpload: allowLiveUpload,
                    viewOnceAvailable: viewOnceAvailable,
                    inputPanelFrame: (currentInputPanelFrame, self.chatDisplayNode.inputNode != nil),
                    chatNode: self.chatDisplayNode.historyNode,
                    completion: { [weak self] message, silentPosting, scheduleTime in
                        guard let self, let videoController = self.videoRecorderValue else {
                            return
                        }
                        
                        guard var message else {
                            self.recorderFeedback?.error()
                            self.recorderFeedback = nil
                            self.videoRecorder.set(.single(nil))
                            return
                        }
                        
                        let replyMessageSubject = self.presentationInterfaceState.interfaceState.replyMessageSubject
                        let correlationId = Int64.random(in: 0 ..< Int64.max)
                        message = message
                            .withUpdatedReplyToMessageId(replyMessageSubject?.subjectModel)
                            .withUpdatedCorrelationId(correlationId)
                        
                        var shouldAnimateMessageTransition = self.chatDisplayNode.shouldAnimateMessageTransition
                        if self.chatLocation.threadId == nil, let channel = self.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.isMonoForum, let linkedMonoforumId = channel.linkedMonoforumId, let mainChannel = self.presentationInterfaceState.renderedPeer?.peers[linkedMonoforumId] as? TelegramChannel, mainChannel.hasPermission(.manageDirect) {
                            shouldAnimateMessageTransition = false
                        }
                        
                        var usedCorrelationId = false
                        if scheduleTime == nil, shouldAnimateMessageTransition, let extractedView = videoController.extractVideoSnapshot() {
                            usedCorrelationId = true
                            self.chatDisplayNode.messageTransitionNode.add(correlationId: correlationId, source:  .videoMessage(ChatMessageTransitionNodeImpl.Source.VideoMessage(view: extractedView)), initiated: { [weak videoController, weak self] in
                                videoController?.hideVideoSnapshot()
                                guard let self else {
                                    return
                                }
                                self.videoRecorder.set(.single(nil))
                            })
                        } else {
                            self.videoRecorder.set(.single(nil))
                        }
                        
                        self.chatDisplayNode.setupSendActionOnViewUpdate({ [weak self] in
                            if let self {
                                self.chatDisplayNode.collapseInput()
                                
                                self.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                    $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil).withUpdatedMediaDraftState(nil).withUpdatedPostSuggestionState(nil) }
                                })
                            }
                        }, usedCorrelationId ? correlationId : nil)
                        
                        let messages = [message]
                        let transformedMessages: [EnqueueMessage]
                        if let silentPosting {
                            transformedMessages = self.transformEnqueueMessages(messages, silentPosting: silentPosting)
                        } else if let scheduleTime {
                            transformedMessages = self.transformEnqueueMessages(messages, silentPosting: false, scheduleTime: scheduleTime)
                        } else {
                            transformedMessages = self.transformEnqueueMessages(messages)
                        }
                        
                        self.sendMessages(transformedMessages)
                    }
                )
                controller.onResume = { [weak self] in
                    guard let self else {
                        return
                    }
                    self.resumeMediaRecorder()
                }
                self.videoRecorder.set(.single(controller))
            }
        }
    }
    
    func dismissMediaRecorder(_ action: ChatFinishMediaRecordingAction) {
        var updatedAction = action
        var isScheduledMessages = false
        if case .scheduledMessages = self.presentationInterfaceState.subject {
            isScheduledMessages = true
        }
        
        if let _ = self.presentationInterfaceState.slowmodeState, !isScheduledMessages {
            updatedAction = .preview
        }
        
        var sendImmediately = false
        if let _ = self.presentationInterfaceState.sendPaidMessageStars, case .send = action {
            updatedAction = .preview
            sendImmediately = true
        }
        
        if let audioRecorderValue = self.audioRecorderValue {
            switch action {
            case .pause:
                audioRecorderValue.pause()
            default:
                audioRecorderValue.stop()
            }
            
            self.dismissAllTooltips()
            
            switch updatedAction {
            case .dismiss:
                self.recorderDataDisposable.set(nil)
                self.chatDisplayNode.updateRecordedMediaDeleted(true)
                self.audioRecorder.set(.single(nil))
            case .preview, .pause:
                self.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                    $0.updatedInputTextPanelState { panelState in
                        return panelState.withUpdatedMediaRecordingState(.waitingForPreview)
                    }
                })
                
                var resource: LocalFileMediaResource?
                self.recorderDataDisposable.set(
                    (audioRecorderValue.takenRecordedData()
                     |> deliverOnMainQueue).startStrict(
                        next: { [weak self] data in
                            if let strongSelf = self, let data = data {
                                if data.duration < 0.5 {
                                    strongSelf.recorderFeedback?.error()
                                    strongSelf.recorderFeedback = nil
                                    strongSelf.audioRecorder.set(.single(nil))
                                    strongSelf.recorderDataDisposable.set(nil)
                                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                        $0.updatedInputTextPanelState { panelState in
                                            return panelState.withUpdatedMediaRecordingState(nil)
                                        }
                                    })
                                } else if let waveform = data.waveform {
                                    if resource == nil {
                                        resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max), size: Int64(data.compressedData.count))
                                        strongSelf.context.account.postbox.mediaBox.storeResourceData(resource!.id, data: data.compressedData)
                                    }
                                    
                                    let audioWaveform: AudioWaveform
                                    if let recordedMediaPreview = strongSelf.presentationInterfaceState.interfaceState.mediaDraftState, case let .audio(audio) = recordedMediaPreview {
                                        audioWaveform = audio.waveform
                                    } else {
                                        audioWaveform = AudioWaveform(bitstream: waveform, bitsPerSample: 5)
                                    }
                                    
                                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                        $0.updatedInterfaceState {
                                            $0.withUpdatedMediaDraftState(.audio(
                                                ChatInterfaceMediaDraftState.Audio(
                                                    resource: resource!,
                                                    fileSize: Int32(data.compressedData.count),
                                                    duration: data.duration,
                                                    waveform: audioWaveform,
                                                    trimRange: data.trimRange,
                                                    resumeData: data.resumeData
                                                )
                                            ))
                                        }.updatedInputTextPanelState { panelState in
                                            return panelState.withUpdatedMediaRecordingState(nil)
                                        }
                                    })
                                    strongSelf.recorderFeedback = nil
                                    strongSelf.updateDownButtonVisibility()
                                    
                                    if sendImmediately {
                                        strongSelf.interfaceInteraction?.sendRecordedMedia(false, false)
                                    }
                                }
                            }
                        })
                )
            case let .send(viewOnce):
                self.chatDisplayNode.updateRecordedMediaDeleted(false)
                self.recorderDataDisposable.set((audioRecorderValue.takenRecordedData()
                |> deliverOnMainQueue).startStrict(next: { [weak self] data in
                    if let strongSelf = self, let data = data {
                        if data.duration < 0.5 {
                            strongSelf.recorderFeedback?.error()
                            strongSelf.recorderFeedback = nil
                            strongSelf.audioRecorder.set(.single(nil))
                            strongSelf.recorderDataDisposable.set(nil)
                        } else {
                            let randomId = Int64.random(in: Int64.min ... Int64.max)
                            
                            let resource = LocalFileMediaResource(fileId: randomId)
                            strongSelf.context.account.postbox.mediaBox.storeResourceData(resource.id, data: data.compressedData)
                            
                            let waveformBuffer: Data? = data.waveform
                            
                            let correlationId = Int64.random(in: 0 ..< Int64.max)
                            var usedCorrelationId = false
                            
                            var shouldAnimateMessageTransition = strongSelf.chatDisplayNode.shouldAnimateMessageTransition
                            if strongSelf.chatLocation.threadId == nil, let channel = strongSelf.presentationInterfaceState.renderedPeer?.peer as? TelegramChannel, channel.isMonoForum, let linkedMonoforumId = channel.linkedMonoforumId, let mainChannel = strongSelf.presentationInterfaceState.renderedPeer?.peers[linkedMonoforumId] as? TelegramChannel, mainChannel.hasPermission(.manageDirect) {
                                shouldAnimateMessageTransition = false
                            }
                            
                            if shouldAnimateMessageTransition, let textInputPanelNode = strongSelf.chatDisplayNode.textInputPanelNode, let micButton = textInputPanelNode.micButton {
                                usedCorrelationId = true
                                strongSelf.chatDisplayNode.messageTransitionNode.add(correlationId: correlationId, source: .audioMicInput(ChatMessageTransitionNodeImpl.Source.AudioMicInput(micButton: micButton)), initiated: {
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.audioRecorder.set(.single(nil))
                                })
                            } else {
                                strongSelf.audioRecorder.set(.single(nil))
                            }
                            
                            strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                if let strongSelf = self {
                                    strongSelf.chatDisplayNode.collapseInput()
                                    
                                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                        $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil).withUpdatedPostSuggestionState(nil) }
                                    })
                                }
                            }, usedCorrelationId ? correlationId : nil)
                            
                            var attributes: [MessageAttribute] = []
                            if viewOnce {
                                attributes.append(AutoremoveTimeoutMessageAttribute(timeout: viewOnceTimeout, countdownBeginTime: nil))
                            }
                            
                            strongSelf.sendMessages([.message(text: "", attributes: attributes, inlineStickers: [:], mediaReference: .standalone(media: TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: Int64(data.compressedData.count), attributes: [.Audio(isVoice: true, duration: Int(data.duration), title: nil, performer: nil, waveform: waveformBuffer)], alternativeRepresentations: [])), threadId: strongSelf.chatLocation.threadId, replyToMessageId: strongSelf.presentationInterfaceState.interfaceState.replyMessageSubject?.subjectModel, replyToStoryId: nil, localGroupingKey: nil, correlationId: correlationId, bubbleUpEmojiOrStickersets: [])])
                            
                            strongSelf.recorderFeedback?.tap()
                            strongSelf.recorderFeedback = nil
                            strongSelf.recorderDataDisposable.set(nil)
                        }
                    }
                }))
            }
        } else if let videoRecorderValue = self.videoRecorderValue {
            if case .send = updatedAction {
                self.chatDisplayNode.updateRecordedMediaDeleted(false)
                videoRecorderValue.sendVideoRecording()
                self.recorderDataDisposable.set(nil)
            } else {
                if case .dismiss = updatedAction {
                    self.chatDisplayNode.updateRecordedMediaDeleted(true)
                    self.recorderDataDisposable.set(nil)
                }
                
                switch updatedAction {
                case .preview, .pause:
                    if videoRecorderValue.stopVideoRecording() {
                        self.recorderDataDisposable.set((videoRecorderValue.takenRecordedData()
                        |> deliverOnMainQueue).startStrict(next: { [weak self] data in
                            if let strongSelf = self, let data = data {
                                if data.duration < 1.0 {
                                    strongSelf.recorderFeedback?.error()
                                    strongSelf.recorderFeedback = nil
                                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                        $0.updatedInputTextPanelState { panelState in
                                            return panelState.withUpdatedMediaRecordingState(nil)
                                        }
                                    })
                                    strongSelf.recorderDataDisposable.set(nil)
                                    strongSelf.videoRecorder.set(.single(nil))
                                } else {
                                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                        $0.updatedInterfaceState {
                                            $0.withUpdatedMediaDraftState(.video(
                                                ChatInterfaceMediaDraftState.Video(
                                                    duration: data.duration,
                                                    frames: data.frames,
                                                    framesUpdateTimestamp: data.framesUpdateTimestamp,
                                                    trimRange: data.trimRange
                                                )
                                            ))
                                        }.updatedInputTextPanelState { panelState in
                                            return panelState.withUpdatedMediaRecordingState(nil)
                                        }
                                    })
                                    strongSelf.recorderFeedback = nil
                                    strongSelf.updateDownButtonVisibility()
                                }
                            }
                        }))
                    }
                default:
                    self.recorderDataDisposable.set(nil)
                    self.videoRecorder.set(.single(nil))
                }
            }
        }
    }
    
    func stopMediaRecorder(pause: Bool = false) {
        if let audioRecorderValue = self.audioRecorderValue {
            if let _ = self.presentationInterfaceState.inputTextPanelState.mediaRecordingState {
                self.dismissMediaRecorder(pause ? .pause : .preview)
            } else {
                audioRecorderValue.stop()
                self.audioRecorder.set(.single(nil))
            }
        } else if let _ = self.videoRecorderValue {
            if let _ = self.presentationInterfaceState.inputTextPanelState.mediaRecordingState {
                self.dismissMediaRecorder(pause ? .pause : .preview)
            } else {
                self.videoRecorder.set(.single(nil))
            }
        }
    }
    
    func resumeMediaRecorder() {
        self.recorderDataDisposable.set(nil)
        
        self.context.sharedContext.mediaManager.playlistControl(.playback(.pause), type: nil)
        
        if let videoRecorderValue = self.videoRecorderValue {
            self.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                $0.updatedInputTextPanelState { panelState in
                    let recordingStatus = videoRecorderValue.recordingStatus
                    return panelState.withUpdatedMediaRecordingState(.video(status: .recording(InstantVideoControllerRecordingStatus(micLevel: recordingStatus.micLevel, duration: recordingStatus.duration)), isLocked: true))
                }.updatedInterfaceState { $0.withUpdatedMediaDraftState(nil) }
            })
        } else {
            let proceed = {
                self.withAudioRecorder(resuming: true, { audioRecorder in
                    audioRecorder.resume()
                    
                    self.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                        $0.updatedInputTextPanelState { panelState in
                            return panelState.withUpdatedMediaRecordingState(.audio(recorder: audioRecorder, isLocked: true))
                        }.updatedInterfaceState { $0.withUpdatedMediaDraftState(nil) }
                    })
                })
            }
            
            let _ = (ApplicationSpecificNotice.getVoiceMessagesResumeTrimWarning(accountManager: self.context.sharedContext.accountManager)
            |> deliverOnMainQueue).start(next: { [weak self] count in
                guard let self else {
                    return
                }
                if count > 0 {
                    proceed()
                    return
                }
                if let recordedMediaPreview = self.presentationInterfaceState.interfaceState.mediaDraftState, case let .audio(audio) = recordedMediaPreview, let trimRange = audio.trimRange, trimRange.lowerBound > 0.1 || trimRange.upperBound < audio.duration {
                    self.present(
                        textAlertController(
                            context: self.context,
                            title: self.presentationData.strings.Chat_TrimVoiceMessageToResume_Title,
                            text: self.presentationData.strings.Chat_TrimVoiceMessageToResume_Text,
                            actions: [
                                TextAlertAction(type: .genericAction, title: self.presentationData.strings.Common_Cancel, action: {}),
                                TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Chat_TrimVoiceMessageToResume_Proceed, action: {
                                    proceed()
                                    let _ = ApplicationSpecificNotice.incrementVoiceMessagesResumeTrimWarning(accountManager: self.context.sharedContext.accountManager).start()
                                })
                            ]
                        ), in: .window(.root)
                    )
                } else {
                    proceed()
                }
            })
        }
    }
    
    func lockMediaRecorder() {
        if self.presentationInterfaceState.inputTextPanelState.mediaRecordingState != nil {
            self.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                return $0.updatedInputTextPanelState { panelState in
                    return panelState.withUpdatedMediaRecordingState(panelState.mediaRecordingState?.withLocked(true))
                }
            })
        }
        
        if let _ = self.audioRecorderValue {
            self.maybePresentAudioPauseTooltip()
        } else if let videoRecorderValue = self.videoRecorderValue {
            videoRecorderValue.lockVideoRecording()
        }
    }
    
    func deleteMediaRecording() {
        if let _ = self.audioRecorderValue {
            self.audioRecorder.set(.single(nil))
        } else if let _ = self.videoRecorderValue {
            self.videoRecorder.set(.single(nil))
        }
        
        self.recorderDataDisposable.set(nil)
        self.chatDisplayNode.updateRecordedMediaDeleted(true)
        self.updateChatPresentationInterfaceState(animated: true, interactive: true, {
            $0.updatedInterfaceState { $0.withUpdatedMediaDraftState(nil) }
        })
        self.updateDownButtonVisibility()
        
        self.dismissAllTooltips()
    }
    
    private func maybePresentAudioPauseTooltip() {
        let _ = (ApplicationSpecificNotice.getVoiceMessagesPauseSuggestion(accountManager: self.context.sharedContext.accountManager)
        |> deliverOnMainQueue).startStandalone(next: { [weak self] pauseCounter in
            guard let self else {
                return
            }
            
            if pauseCounter >= 3 {
                return
            } else {
                Queue.mainQueue().after(0.3) {
                    self.displayPauseTooltip(text: self.presentationData.strings.Chat_PauseVoiceMessageTooltip)
                }
                let _ = ApplicationSpecificNotice.incrementVoiceMessagesPauseSuggestion(accountManager: self.context.sharedContext.accountManager).startStandalone()
            }
        })
    }
    
    private func displayPauseTooltip(text: String) {
        guard let layout = self.validLayout else {
            return
        }
        
        self.dismissAllTooltips()
        
        let insets = layout.insets(options: [.input])
        var screenWidth = layout.size.width
        if layout.metrics.isTablet {
            if layout.size.height == layout.deviceMetrics.screenSize.width {
                screenWidth = layout.deviceMetrics.screenSize.height
            } else {
                screenWidth = layout.deviceMetrics.screenSize.width
            }
        }
        
        let location = CGRect(origin: CGPoint(x: screenWidth - layout.safeInsets.right - 42.0 - UIScreenPixel, y: layout.size.height - insets.bottom - 122.0), size: CGSize())
        
        let tooltipController = TooltipScreen(
            account: self.context.account,
            sharedContext: self.context.sharedContext,
            text: .markdown(text: text),
            balancedTextLayout: true,
            constrainWidth: 240.0,
            style: .customBlur(UIColor(rgb: 0x18181a), 0.0),
            arrowStyle: .small,
            icon: nil,
            location: .point(location, .right),
            displayDuration: .default,
            inset: 8.0,
            cornerRadius: 8.0,
            shouldDismissOnTouch: { _, _ in
                return .ignore
            }
        )
        self.present(tooltipController, in: .window(.root))
    }
    
    private func withAudioRecorder(resuming: Bool, _ f: (ManagedAudioRecorder) -> Void) {
        if let audioRecorder = self.audioRecorderValue {
            f(audioRecorder)
        } else if let recordedMediaPreview = self.presentationInterfaceState.interfaceState.mediaDraftState, case let .audio(audio) = recordedMediaPreview {
            self.requestAudioRecorder(beginWithTone: false, existingDraft: audio)
            if let audioRecorder = self.audioRecorderValue {
                f(audioRecorder)
                
                if !resuming {
                    self.recorderDataDisposable.set(
                        (audioRecorder.takenRecordedData()
                         |> deliverOnMainQueue).startStrict(
                            next: { [weak self] data in
                                if let strongSelf = self, let data = data {
                                    let audioWaveform = audio.waveform
                                   
                                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                        $0.updatedInterfaceState {
                                            $0.withUpdatedMediaDraftState(.audio(
                                                ChatInterfaceMediaDraftState.Audio(
                                                    resource: audio.resource,
                                                    fileSize: Int32(data.compressedData.count),
                                                    duration: data.duration,
                                                    waveform: audioWaveform,
                                                    trimRange: data.trimRange,
                                                    resumeData: data.resumeData
                                                )
                                            ))
                                        }.updatedInputTextPanelState { panelState in
                                            return panelState.withUpdatedMediaRecordingState(nil)
                                        }
                                    })
                                    strongSelf.updateDownButtonVisibility()
                                }
                            })
                    )
                }
            }
        }
    }
    
    func updateTrimRange(start: Double, end: Double, updatedEnd: Bool, apply: Bool) {
        if let videoRecorder = self.videoRecorderValue {
            videoRecorder.updateTrimRange(start: start, end: end, updatedEnd: updatedEnd, apply: apply)
        } else {
            self.withAudioRecorder(resuming: false, { audioRecorder in
                audioRecorder.updateTrimRange(start: start, end: end, updatedEnd: updatedEnd, apply: apply)
            })
        }
    }
    
    func sendMediaRecording(
        silentPosting: Bool? = nil,
        scheduleTime: Int32? = nil,
        viewOnce: Bool = false,
        messageEffect: ChatSendMessageEffect? = nil,
        postpone: Bool = false
    ) {
        self.chatDisplayNode.updateRecordedMediaDeleted(false)
        
        guard let recordedMediaPreview = self.presentationInterfaceState.interfaceState.mediaDraftState else {
            return
        }
        
        switch recordedMediaPreview {
        case let .audio(audio):
            self.audioRecorder.set(.single(nil))
            
            var isScheduledMessages = false
            if case .scheduledMessages = self.presentationInterfaceState.subject {
                isScheduledMessages = true
            }
            
            if let _ = self.presentationInterfaceState.slowmodeState, !isScheduledMessages {
                if let rect = self.chatDisplayNode.frameForInputActionButton() {
                    self.interfaceInteraction?.displaySlowmodeTooltip(self.chatDisplayNode.view, rect)
                }
                return
            }
            
            
            
            self.chatDisplayNode.setupSendActionOnViewUpdate({ [weak self] in
                if let strongSelf = self {
                    strongSelf.chatDisplayNode.collapseInput()
                    
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                        $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedMediaDraftState(nil).withUpdatedSendMessageEffect(nil).withUpdatedPostSuggestionState(nil) }
                    })

                    strongSelf.updateDownButtonVisibility()
                }
            }, nil)
            
            var attributes: [MessageAttribute] = []
            if viewOnce {
                attributes.append(AutoremoveTimeoutMessageAttribute(timeout: viewOnceTimeout, countdownBeginTime: nil))
            }
            if let messageEffect {
                attributes.append(EffectMessageAttribute(id: messageEffect.id))
            }
            
            let resource: TelegramMediaResource
            var waveform = audio.waveform
            var finalDuration: Int = Int(audio.duration)
            if let trimRange = audio.trimRange, trimRange.lowerBound > 0.0 || trimRange.upperBound < Double(audio.duration)  {
                let randomId = Int64.random(in: Int64.min ... Int64.max)
                let tempPath = NSTemporaryDirectory() + "\(Int64.random(in: 0 ..< .max)).ogg"
                resource = LocalFileAudioMediaResource(randomId: randomId, path: tempPath, trimRange: trimRange)
                self.context.account.postbox.mediaBox.moveResourceData(audio.resource.id, toTempPath: tempPath)
                waveform = waveform.subwaveform(from: trimRange.lowerBound / Double(audio.duration), to: trimRange.upperBound / Double(audio.duration))
                finalDuration = Int(trimRange.upperBound - trimRange.lowerBound)
            } else {
                resource = audio.resource
            }
            
            let waveformBuffer = waveform.makeBitstream()
            
            let messages: [EnqueueMessage] = [.message(text: "", attributes: attributes, inlineStickers: [:], mediaReference: .standalone(media: TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: Int64.random(in: Int64.min ... Int64.max)), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: Int64(audio.fileSize), attributes: [.Audio(isVoice: true, duration: finalDuration, title: nil, performer: nil, waveform: waveformBuffer)], alternativeRepresentations: [])), threadId: self.chatLocation.threadId, replyToMessageId: self.presentationInterfaceState.interfaceState.replyMessageSubject?.subjectModel, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])]
            
            let transformedMessages: [EnqueueMessage]
            if let silentPosting = silentPosting {
                transformedMessages = self.transformEnqueueMessages(messages, silentPosting: silentPosting, postpone: postpone)
            } else if let scheduleTime = scheduleTime {
                transformedMessages = self.transformEnqueueMessages(messages, silentPosting: false, scheduleTime: scheduleTime, postpone: postpone)
            } else {
                transformedMessages = self.transformEnqueueMessages(messages)
            }
            
            guard let peerId = self.chatLocation.peerId else {
                return
            }
            
            let _ = (enqueueMessages(account: self.context.account, peerId: peerId, messages: transformedMessages)
            |> deliverOnMainQueue).startStandalone(next: { [weak self] _ in
                if let strongSelf = self, strongSelf.presentationInterfaceState.subject != .scheduledMessages {
                    strongSelf.chatDisplayNode.historyNode.scrollToEndOfHistory()
                }
            })
            
            donateSendMessageIntent(account: self.context.account, sharedContext: self.context.sharedContext, intentContext: .chat, peerIds: [peerId])
        case .video:
            self.videoRecorderValue?.sendVideoRecording(silentPosting: silentPosting, scheduleTime: scheduleTime, messageEffect: messageEffect)
        }
    }
}
