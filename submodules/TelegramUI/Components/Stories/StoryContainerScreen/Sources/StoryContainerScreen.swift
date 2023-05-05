import Foundation
import UIKit
import Display
import ComponentFlow
import ViewControllerComponent
import AccountContext
import SwiftSignalKit
import AppBundle
import MessageInputPanelComponent
import ShareController
import TelegramCore
import Postbox
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
import ReactionSelectionNode
import EntityKeyboard
import AsyncDisplayKit
import simd

func hasFirstResponder(_ view: UIView) -> Bool {
    if view.isFirstResponder {
        return true
    }
    for subview in view.subviews {
        if hasFirstResponder(subview) {
            return true
        }
    }
    return false
}

private final class StoryContainerScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let initialFocusedId: AnyHashable?
    let initialContent: [StoryContentItemSlice]
    let transitionIn: StoryContainerScreen.TransitionIn?
    
    init(
        context: AccountContext,
        initialFocusedId: AnyHashable?,
        initialContent: [StoryContentItemSlice],
        transitionIn: StoryContainerScreen.TransitionIn?
    ) {
        self.context = context
        self.initialFocusedId = initialFocusedId
        self.initialContent = initialContent
        self.transitionIn = transitionIn
    }
    
    static func ==(lhs: StoryContainerScreenComponent, rhs: StoryContainerScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    private final class ItemSetView: UIView {
        let view = ComponentView<Empty>()
        let externalState = StoryItemSetContainerComponent.ExternalState()
        
        let tintLayer = SimpleGradientLayer()
        
        var rotationFraction: CGFloat?
        
        override static var layerClass: AnyClass {
            return CATransformLayer.self
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.tintLayer.opacity = 0.0
            
            let colors: [CGColor] = [
                UIColor.black.withAlphaComponent(1.0).cgColor,
                UIColor.black.withAlphaComponent(0.8).cgColor,
                UIColor.black.withAlphaComponent(0.5).cgColor
            ]
            
            self.tintLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
            self.tintLayer.endPoint = CGPoint(x: 1.0, y: 0.0)
            self.tintLayer.colors = colors
            self.tintLayer.type = .axial
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard let componentView = self.view.view else {
                return nil
            }
            return componentView.hitTest(point, with: event)
        }
    }
    
    private struct ItemSetPanState: Equatable {
        var fraction: CGFloat
        var didBegin: Bool
        
        init(fraction: CGFloat, didBegin: Bool) {
            self.fraction = fraction
            self.didBegin = didBegin
        }
    }
    
    private final class StoryPanRecognizer: UIPanGestureRecognizer {
        private let updateIsActive: (Bool) -> Void
        private var isActive: Bool = false
        private var timer: Foundation.Timer?
        
        init(target: Any?, action: Selector?, updateIsActive: @escaping (Bool) -> Void) {
            self.updateIsActive = updateIsActive
            
            super.init(target: target, action: action)
        }
        
        override func reset() {
            super.reset()
            
            self.isActive = false
            self.timer?.invalidate()
            self.timer = nil
        }
        
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesBegan(touches, with: event)
            
            if !self.isActive {
                if self.timer == nil {
                    self.timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false, block: { [weak self] timer in
                        guard let self, self.timer === timer else {
                            return
                        }
                        self.timer = nil
                        if !self.isActive {
                            self.isActive = true
                            self.updateIsActive(true)
                        }
                    })
                }
            }
        }
        
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
            if self.isActive {
                self.isActive = false
                self.updateIsActive(false)
                
                for touch in touches {
                    if let gestureRecognizers = touch.gestureRecognizers {
                        for gestureRecognizer in gestureRecognizers {
                            if gestureRecognizer is UITapGestureRecognizer {
                                gestureRecognizer.state = .cancelled
                            }
                        }
                    }
                }
            }
            self.timer?.invalidate()
            self.timer = nil
            
            super.touchesEnded(touches, with: event)
        }
        
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
            super.touchesCancelled(touches, with: event)
            
            if self.isActive {
                self.isActive = false
                self.updateIsActive(false)
            }
            self.timer?.invalidate()
            self.timer = nil
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private weak var attachmentController: AttachmentController?
        private let controllerNavigationDisposable = MetaDisposable()
        private let enqueueMediaMessageDisposable = MetaDisposable()
        
        private var component: StoryContainerScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?
        
        private var focusedItemSet: AnyHashable?
        private var itemSets: [StoryContentItemSlice] = []
        private var visibleItemSetViews: [AnyHashable: ItemSetView] = [:]
        
        private var itemSetPanState: ItemSetPanState?
        
        private var audioRecorderValue: ManagedAudioRecorder?
        private var audioRecorder = Promise<ManagedAudioRecorder?>()
        private var audioRecorderDisposable: Disposable?
        private var audioRecorderStatusDisposable: Disposable?
        
        private var videoRecorderValue: InstantVideoController?
        private var tempVideoRecorderValue: InstantVideoController?
        private var videoRecorder = Promise<InstantVideoController?>()
        private var videoRecorderDisposable: Disposable?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.backgroundColor = .black
            
            self.addGestureRecognizer(StoryPanRecognizer(target: self, action: #selector(self.panGesture(_:)), updateIsActive: { [weak self] value in
                guard let self else {
                    return
                }
                if value {
                    if self.itemSetPanState == nil {
                        self.itemSetPanState = ItemSetPanState(fraction: 0.0, didBegin: false)
                        self.state?.updated(transition: Transition(animation: .curve(duration: 0.25, curve: .easeInOut)))
                    }
                } else {
                    if let itemSetPanState = self.itemSetPanState, !itemSetPanState.didBegin {
                        self.itemSetPanState = nil
                        self.state?.updated(transition: Transition(animation: .curve(duration: 0.25, curve: .easeInOut)))
                    }
                }
            }))
            
            self.audioRecorderDisposable = (self.audioRecorder.get()
            |> deliverOnMainQueue).start(next: { [weak self] audioRecorder in
                guard let self else {
                    return
                }
                if self.audioRecorderValue !== audioRecorder {
                    self.audioRecorderValue = audioRecorder
                    self.environment?.controller()?.lockOrientation = audioRecorder != nil
                    
                    /*strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                        $0.updatedInputTextPanelState { panelState in
                            let isLocked = strongSelf.lockMediaRecordingRequestId == strongSelf.beginMediaRecordingRequestId
                            if let audioRecorder = audioRecorder {
                                if panelState.mediaRecordingState == nil {
                                    return panelState.withUpdatedMediaRecordingState(.audio(recorder: audioRecorder, isLocked: isLocked))
                                }
                            } else {
                                if case .waitingForPreview = panelState.mediaRecordingState {
                                    return panelState
                                }
                                return panelState.withUpdatedMediaRecordingState(nil)
                            }
                            return panelState
                        }
                    })*/
                    
                    self.audioRecorderStatusDisposable?.dispose()
                    self.audioRecorderStatusDisposable = nil
                    
                    if let audioRecorder = audioRecorder {
                        if !audioRecorder.beginWithTone {
                            HapticFeedback().impact(.light)
                        }
                        audioRecorder.start()
                        self.audioRecorderStatusDisposable = (audioRecorder.recordingState
                        |> deliverOnMainQueue).start(next: { [weak self] value in
                            guard let self else {
                                return
                            }
                            if case .stopped = value {
                                self.stopMediaRecorder()
                            }
                        })
                    }
                    
                    self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)))
                }
            })
            
            self.videoRecorderDisposable = (self.videoRecorder.get()
            |> deliverOnMainQueue).start(next: { [weak self] videoRecorder in
                guard let self else {
                    return
                }
                if self.videoRecorderValue !== videoRecorder {
                    let previousVideoRecorderValue = self.videoRecorderValue
                    self.videoRecorderValue = videoRecorder
                    
                    if let videoRecorder = videoRecorder {
                        HapticFeedback().impact(.light)
                        
                        videoRecorder.onDismiss = { [weak self] isCancelled in
                            guard let self else {
                                return
                            }
                            //self?.chatDisplayNode.updateRecordedMediaDeleted(isCancelled)
                            //self?.beginMediaRecordingRequestId += 1
                            //self?.lockMediaRecordingRequestId = nil
                            self.videoRecorder.set(.single(nil))
                        }
                        videoRecorder.onStop = { [weak self] in
                            guard let self else {
                                return
                            }
                            /*if let strongSelf = self {
                                strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, {
                                    $0.updatedInputTextPanelState { panelState in
                                        return panelState.withUpdatedMediaRecordingState(.video(status: .editing, isLocked: false))
                                    }
                                })
                            }*/
                            let _ = self
                            //TODO:editing
                        }
                        self.environment?.controller()?.present(videoRecorder, in: .window(.root))
                        
                        /*if strongSelf.lockMediaRecordingRequestId == strongSelf.beginMediaRecordingRequestId {
                            videoRecorder.lockVideo()
                        }*/
                    }
                    
                    if let previousVideoRecorderValue {
                        previousVideoRecorderValue.dismissVideo()
                    }
                    
                    self.state?.updated(transition: .immediate)
                }
            })
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.controllerNavigationDisposable.dispose()
            self.enqueueMediaMessageDisposable.dispose()
            self.audioRecorderDisposable?.dispose()
            self.audioRecorderStatusDisposable?.dispose()
        }
        
        @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                self.layer.removeAnimation(forKey: "panState")
                
                if let itemSetPanState = self.itemSetPanState, !itemSetPanState.didBegin {
                    self.itemSetPanState = ItemSetPanState(fraction: 0.0, didBegin: true)
                    self.state?.updated(transition: Transition(animation: .curve(duration: 0.25, curve: .easeInOut)))
                } else {
                    self.itemSetPanState = ItemSetPanState(fraction: 0.0, didBegin: true)
                    self.state?.updated(transition: .immediate)
                }
            case .changed:
                if var itemSetPanState = self.itemSetPanState, self.bounds.width > 0.0, let focusedItemSet = self.focusedItemSet, let focusedIndex = self.itemSets.firstIndex(where: { $0.id == focusedItemSet }) {
                    var translation = recognizer.translation(in: self)
                    
                    func rubberBandingOffset(offset: CGFloat, bandingStart: CGFloat) -> CGFloat {
                        let bandedOffset = offset - bandingStart
                        let range: CGFloat = 600.0
                        let coefficient: CGFloat = 0.4
                        return bandingStart + (1.0 - (1.0 / ((bandedOffset * coefficient / range) + 1.0))) * range
                    }
                    
                    if translation.x > 0.0 && focusedIndex == 0 {
                        translation.x = rubberBandingOffset(offset: translation.x, bandingStart: 0.0)
                    } else if translation.x < 0.0 && focusedIndex == self.itemSets.count - 1 {
                        translation.x = -rubberBandingOffset(offset: -translation.x, bandingStart: 0.0)
                    }
                    
                    var fraction = translation.x / self.bounds.width
                    fraction = -max(-1.0, min(1.0, fraction))
                    
                    itemSetPanState.fraction = fraction
                    self.itemSetPanState = itemSetPanState
                    
                    self.state?.updated(transition: .immediate)
                }
            case .cancelled, .ended:
                if var itemSetPanState = self.itemSetPanState {
                    if let focusedItemSet = self.focusedItemSet, let focusedIndex = self.itemSets.firstIndex(where: { $0.id == focusedItemSet }) {
                        let velocity = recognizer.velocity(in: self)
                        
                        var switchToIndex = focusedIndex
                        if abs(velocity.x) > 10.0 {
                            if velocity.x < 0.0 {
                                switchToIndex += 1
                            } else {
                                switchToIndex -= 1
                            }
                        }
                        
                        switchToIndex = max(0, min(switchToIndex, self.itemSets.count - 1))
                        if switchToIndex != focusedIndex {
                            self.focusedItemSet = self.itemSets[switchToIndex].id
                            
                            if switchToIndex < focusedIndex {
                                itemSetPanState.fraction = 1.0 + itemSetPanState.fraction
                            } else {
                                itemSetPanState.fraction = itemSetPanState.fraction - 1.0
                            }
                            self.itemSetPanState = itemSetPanState
                            self.state?.updated(transition: .immediate)
                        }
                    }
                    
                    itemSetPanState.fraction = 0.0
                    self.itemSetPanState = itemSetPanState
                    
                    let transition = Transition(animation: .curve(duration: 0.4, curve: .spring))
                    self.state?.updated(transition: transition)
                    
                    transition.attachAnimation(view: self, id: "panState", completion: { [weak self] completed in
                        guard let self, completed else {
                            return
                        }
                        self.itemSetPanState = nil
                        self.state?.updated(transition: .immediate)
                    })
                }
            default:
                break
            }
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            for subview in self.subviews.reversed() {
                if !subview.isUserInteractionEnabled || subview.isHidden || subview.alpha == 0.0 {
                    continue
                }
                if subview is ItemSetView {
                    if let result = subview.hitTest(point, with: event) {
                        return result
                    }
                } else {
                    if let result = subview.hitTest(self.convert(point, to: subview), with: event) {
                        return result
                    }
                }
            }
            
            return nil
        }
        
        func animateIn() {
            if let transitionIn = self.component?.transitionIn, transitionIn.sourceView != nil {
                self.layer.animate(from: UIColor.black.withAlphaComponent(0.0).cgColor, to: self.layer.backgroundColor ?? UIColor.black.cgColor, keyPath: "backgroundColor", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.28)
                
                if let transitionIn = self.component?.transitionIn, let focusedItemSet = self.focusedItemSet, let itemSetView = self.visibleItemSetViews[focusedItemSet] {
                    if let itemSetComponentView = itemSetView.view.view as? StoryItemSetContainerComponent.View {
                        itemSetComponentView.animateIn(transitionIn: transitionIn)
                    }
                }
            } else {
                self.layer.allowsGroupOpacity = true
                self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, completion: { [weak self] _ in
                    self?.layer.allowsGroupOpacity = false
                })
            }
        }
        
        func animateOut(completion: @escaping () -> Void) {
            self.layer.allowsGroupOpacity = true
            self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                completion()
            })
        }
        
        private func performSendMessageAction() {
            /*guard let component = self.component else {
                return
            }
            guard let focusedItemId = self.focusedItemId, let focusedItem = self.currentSlice?.items.first(where: { $0.id == focusedItemId }) else {
                return
            }
            guard let targetMessageId = focusedItem.targetMessageId else {
                return
            }
            guard let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View else {
                return
            }
            
            switch inputPanelView.getSendMessageInput() {
            case let .text(text):
                if !text.isEmpty {
                    component.context.engine.messages.enqueueOutgoingMessage(
                        to: targetMessageId.peerId,
                        replyTo: targetMessageId,
                        content: .text(text)
                    )
                    inputPanelView.clearSendMessageInput()
                    self.endEditing(true)
                    
                    if let controller = self.environment?.controller() {
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
            }*/
        }
        
        private func setMediaRecordingActive(isActive: Bool, isVideo: Bool, sendAction: Bool) {
            /*guard let component = self.component else {
                return
            }
            guard let focusedItemId = self.focusedItemId, let focusedItem = self.currentSlice?.items.first(where: { $0.id == focusedItemId }) else {
                return
            }
            guard let targetMessageId = focusedItem.targetMessageId else {
                return
            }
            let _ = (component.context.engine.data.get(
                TelegramEngine.EngineData.Item.Messages.Message(id: targetMessageId)
            )
            |> deliverOnMainQueue).start(next: { [weak self] targetMessage in
                guard let self, let component = self.component, let environment = self.environment, let targetMessage, let peer = targetMessage.author else {
                    return
                }
                
                if isActive {
                    if isVideo {
                        if self.videoRecorderValue == nil {
                            if let currentInputPanelFrame = self.inputPanel.view?.frame {
                                self.videoRecorder.set(.single(legacyInstantVideoController(theme: environment.theme, panelFrame: self.convert(currentInputPanelFrame, to: nil), context: component.context, peerId: peer.id, slowmodeState: nil, hasSchedule: peer.id.namespace != Namespaces.Peer.SecretChat, send: { [weak self] videoController, message in
                                    if let strongSelf = self {
                                        guard let message = message else {
                                            strongSelf.videoRecorder.set(.single(nil))
                                            return
                                        }

                                        let replyMessageId = targetMessageId
                                        let correlationId = Int64.random(in: 0 ..< Int64.max)
                                        let updatedMessage = message
                                            .withUpdatedReplyToMessageId(replyMessageId)
                                            .withUpdatedCorrelationId(correlationId)

                                        strongSelf.videoRecorder.set(.single(nil))

                                        strongSelf.sendMessages(peer: peer, messages: [updatedMessage])
                                        
                                        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                                        strongSelf.environment?.controller()?.present(UndoOverlayController(
                                            presentationData: presentationData,
                                            content: .succeed(text: "Message Sent"),
                                            elevatedLayout: false,
                                            animateInAsReplacement: false,
                                            action: { _ in return false }
                                        ), in: .current)
                                    }
                                }, displaySlowmodeTooltip: { [weak self] view, rect in
                                    //self?.interfaceInteraction?.displaySlowmodeTooltip(view, rect)
                                    let _ = self
                                }, presentSchedulePicker: { [weak self] done in
                                    guard let self else {
                                        return
                                    }
                                    self.presentScheduleTimePicker(peer: peer, completion: { time in
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
                        |> deliverOnMainQueue).start(next: { [weak self] data in
                            guard let self, let component = self.component else {
                                return
                            }
                            
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
                                
                                self.sendMessages(peer: peer, messages: [.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: randomId), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: Int64(data.compressedData.count), attributes: [.Audio(isVoice: true, duration: Int(data.duration), title: nil, performer: nil, waveform: waveformBuffer)])), replyToMessageId: targetMessageId, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])])
                                
                                HapticFeedback().tap()
                                
                                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                                self.environment?.controller()?.present(UndoOverlayController(
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
            })*/
        }
        
        private func stopMediaRecorder() {
        }
        
        private func performInlineAction(item: StoryActionsComponent.Item) {
            /*guard let component = self.component else {
                return
            }
            guard let focusedItemId = self.focusedItemId, let focusedItem = self.currentSlice?.items.first(where: { $0.id == focusedItemId }) else {
                return
            }
            guard let targetMessageId = focusedItem.targetMessageId else {
                return
            }
            
            switch item.kind {
            case .like:
                if item.isActivated {
                    component.context.engine.messages.setMessageReactions(
                        id: targetMessageId,
                        reactions: [
                        ]
                    )
                } else {
                    component.context.engine.messages.setMessageReactions(
                        id: targetMessageId,
                        reactions: [
                            .builtin("❤")
                        ]
                    )
                }
            case .share:
                let _ = (component.context.engine.data.get(
                    TelegramEngine.EngineData.Item.Messages.Message(id: targetMessageId)
                )
                |> deliverOnMainQueue).start(next: { [weak self] message in
                    guard let self, let message, let component = self.component, let controller = self.environment?.controller() else {
                        return
                    }
                    let shareController = ShareController(
                        context: component.context,
                        subject: .messages([message._asMessage()]),
                        externalShare: false,
                        immediateExternalShare: false,
                        updatedPresentationData: (component.context.sharedContext.currentPresentationData.with({ $0 }),
                        component.context.sharedContext.presentationData)
                    )
                    controller.present(shareController, in: .window(.root))
                })
            }*/
        }
        
        private func clearInputText() {
            /*guard let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View else {
                return
            }
            inputPanelView.clearSendMessageInput()*/
        }
        
        private enum AttachMenuSubject {
            case `default`
        }
        
        /*private func presentAttachmentMenu(subject: AttachMenuSubject) {
            guard let component = self.component else {
                return
            }
            guard let focusedItemId = self.focusedItemId, let focusedItem = self.currentSlice?.items.first(where: { $0.id == focusedItemId }) else {
                return
            }
            guard let targetMessageId = focusedItem.targetMessageId else {
                return
            }
            guard let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View else {
                return
            }
            
            var inputText = NSAttributedString(string: "")
            switch inputPanelView.getSendMessageInput() {
            case let .text(text):
                inputText = NSAttributedString(string: text)
            }
            
            let _ = (component.context.engine.data.get(
                TelegramEngine.EngineData.Item.Messages.Message(id: targetMessageId)
            )
            |> deliverOnMainQueue).start(next: { [weak self] targetMessage in
                guard let self, let component = self.component else {
                    return
                }
                guard let targetMessage, let peer = targetMessage.author else {
                    return
                }
                
                let inputIsActive = !"".isEmpty
                
                self.endEditing(true)
                        
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
                
                let _ = combineLatest(queue: Queue.mainQueue(), buttons, dataSettings).start(next: { [weak self] buttonsAndInitialButton, dataSettings in
                    guard let self, let component = self.component, let environment = self.environment else {
                        return
                    }
                    
                    var (buttons, allButtons, initialButton) = buttonsAndInitialButton
                    if !premiumGiftOptions.isEmpty {
                        buttons.insert(.gift, at: 1)
                    }
                    let _ = allButtons
                    
                    guard let initialButton = initialButton else {
                        /*if case let .bot(botId, botPayload, botJustInstalled) = subject {
                            if let button = allButtons.first(where: { button in
                                if case let .app(botPeer, _, _) = button, botPeer.id == botId {
                                    return true
                                } else {
                                    return false
                                }
                            }), case let .app(_, botName, _) = button {
                                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                                self.environment?.controller().present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: botJustInstalled ? presentationData.strings.WebApp_AddToAttachmentSucceeded(botName).string : presentationData.strings.WebApp_AddToAttachmentAlreadyAddedError, timeout: nil), elevatedLayout: false, action: { _ in return false }), in: .current)
                            } else {
                                let _ = (context.engine.messages.getAttachMenuBot(botId: botId)
                                |> deliverOnMainQueue).start(next: { [weak self] bot in
                                    guard let self, let component = self.component else {
                                        return
                                    }
                                    
                                    let peer = EnginePeer(bot.peer)
                                                       
                                    let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                                    let controller = addWebAppToAttachmentController(context: context, peerName: peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), icons: bot.icons, requestWriteAccess: bot.flags.contains(.requiresWriteAccess), completion: { allowWrite in
                                        let _ = (context.engine.messages.addBotToAttachMenu(botId: botId, allowWrite: allowWrite)
                                        |> deliverOnMainQueue).start(error: { _ in
                                        }, completed: {
                                            //TODO:present attachment bot
                                            //strongSelf.presentAttachmentBot(botId: botId, payload: botPayload, justInstalled: true)
                                        })
                                    })
                                    self.environment?.controller().present(controller, in: .window(.root))
                                }, error: { [weak self] _ in
                                    guard let self, let component = self.component else {
                                        return
                                    }
                                    let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                                    self.environment?.controller().present(textAlertController(context: context, updatedPresentationData: nil, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                })
                            }
                        }*/
                        return
                    }
                    
                    let currentMediaController = Atomic<MediaPickerScreen?>(value: nil)
                    let currentFilesController = Atomic<AttachmentFileController?>(value: nil)
                    let currentLocationController = Atomic<LocationPickerController?>(value: nil)
                    
                    let theme = environment.theme
                    let attachmentController = AttachmentController(
                        context: component.context,
                        updatedPresentationData: (component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: theme), component.context.sharedContext.presentationData |> map { $0.withUpdated(theme: theme) }),
                        chatLocation: .peer(id: peer.id),
                        buttons: buttons,
                        initialButton: initialButton,
                        makeEntityInputView: { [weak self] in
                            guard let self, let component = self.component else {
                                return nil
                            }
                            return EntityInputView(
                                context: component.context,
                                isDark: true,
                                areCustomEmojiEnabled: true //TODO:check custom emoji
                            )
                        }
                    )
                    attachmentController.didDismiss = { [weak self] in
                        guard let self else {
                            return
                        }
                        self.attachmentController = nil
                        self.updateIsProgressPaused()
                    }
                    attachmentController.getSourceRect = { [weak self] in
                        guard let self else {
                            return nil
                        }
                        guard let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View else {
                            return nil
                        }
                        guard let attachmentButtonView = inputPanelView.getAttachmentButtonView() else {
                            return nil
                        }
                        return attachmentButtonView.convert(attachmentButtonView.bounds, to: self)
                    }
                    attachmentController.requestController = { [weak self, weak attachmentController] type, completion in
                        guard let self, let environment = self.environment else {
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
                                peer: peer,
                                replyToMessageId: targetMessageId,
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
                                }, completion: { [weak self] signals, silentPosting, scheduleTime, getAnimatedTransitionSource, completion in
                                    guard let self else {
                                        return
                                    }
                                    if !inputText.string.isEmpty {
                                        self.clearInputText()
                                    }
                                    self.enqueueMediaMessages(peer: peer, replyToMessageId: targetMessageId, signals: signals, silentPosting: silentPosting, scheduleTime: scheduleTime, getAnimatedTransitionSource: getAnimatedTransitionSource, completion: completion)
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
                            let theme = environment.theme
                            let controller = component.context.sharedContext.makeAttachmentFileController(context: component.context, updatedPresentationData: (component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: theme), component.context.sharedContext.presentationData |> map { $0.withUpdated(theme: theme) }), bannedSendMedia: bannedSendFiles, presentGallery: { [weak self, weak attachmentController] in
                                guard let self else {
                                    return
                                }
                                attachmentController?.dismiss(animated: true)
                                self.presentFileGallery(peer: peer, replyMessageId: targetMessageId)
                            }, presentFiles: { [weak self, weak attachmentController] in
                                guard let self else {
                                    return
                                }
                                attachmentController?.dismiss(animated: true)
                                self.presentICloudFileGallery(peer: peer, replyMessageId: targetMessageId)
                            }, send: { [weak self] mediaReference in
                                guard let self, let component = self.component else {
                                    return
                                }
                                let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: mediaReference, replyToMessageId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                                let _ = (enqueueMessages(account: component.context.account, peerId: peer.id, messages: [message.withUpdatedReplyToMessageId(targetMessageId)])
                                |> deliverOnMainQueue).start()
                                
                                if let controller = self.environment?.controller() {
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
                            |> deliverOnMainQueue).start(next: { [weak self] selfPeer in
                                guard let self, let component = self.component, let environment = self.environment, let selfPeer else {
                                    return
                                }
                                let hasLiveLocation = peer.id.namespace != Namespaces.Peer.SecretChat && peer.id != component.context.account.peerId
                                let theme = environment.theme
                                let controller = LocationPickerController(context: component.context, updatedPresentationData: (component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: theme), component.context.sharedContext.presentationData |> map { $0.withUpdated(theme: theme) }), mode: .share(peer: peer, selfPeer: selfPeer, hasLiveLocation: hasLiveLocation), completion: { [weak self] location, _ in
                                    guard let self else {
                                        return
                                    }
                                    let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: location), replyToMessageId: targetMessageId, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                                    self.sendMessages(peer: peer, messages: [message])
                                })
                                completion(controller, controller.mediaPickerContext)
                                
                                let _ = currentLocationController.swap(controller)
                            })
                        case .contact:
                            let theme = environment.theme
                            let contactsController = component.context.sharedContext.makeContactSelectionController(ContactSelectionControllerParams(context: component.context, updatedPresentationData: (component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: theme), component.context.sharedContext.presentationData |> map { $0.withUpdated(theme: theme) }), title: { $0.Contacts_Title }, displayDeviceContacts: true, multipleSelection: true))
                            contactsController.presentScheduleTimePicker = { [weak self] completion in
                                guard let self else {
                                    return
                                }
                                self.presentScheduleTimePicker(peer: peer, completion: completion)
                            }
                            contactsController.navigationPresentation = .modal
                            if let contactsController = contactsController as? AttachmentContainable, let mediaPickerContext = contactsController.mediaPickerContext {
                                completion(contactsController, mediaPickerContext)
                            }
                            self.controllerNavigationDisposable.set((contactsController.result
                            |> deliverOnMainQueue).start(next: { [weak self] peers in
                                guard let self, let (peers, _, silent, scheduleTime, text) = peers else {
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
                                    textEnqueueMessage = .message(text: text.string, attributes: attributes, inlineStickers: [:], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
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
                                            let replyMessageId = targetMessageId
                                            /*strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                                if let strongSelf = self {
                                                    strongSelf.chatDisplayNode.collapseInput()
                                                    
                                                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                                        $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                                                    })
                                                }
                                            }, nil)*/
                                            let message = EnqueueMessage.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: media), replyToMessageId: replyMessageId, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                                            enqueueMessages.append(message)
                                        }
                                    }
                                    
                                    self.sendMessages(peer: peer, messages: self.transformEnqueueMessages(messages: enqueueMessages, silentPosting: silent, scheduleTime: scheduleTime))
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
                                    |> deliverOnMainQueue).start(next: { [weak self] peerAndContactData in
                                        guard let self, let contactData = peerAndContactData.1, contactData.basicData.phoneNumbers.count != 0 else {
                                            return
                                        }
                                        if contactData.isPrimitive {
                                            let phone = contactData.basicData.phoneNumbers[0].value
                                            let media = TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: peerAndContactData.0?.id, vCardData: nil)
                                            let replyMessageId = targetMessageId
                                            /*strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                                if let strongSelf = self {
                                                    strongSelf.chatDisplayNode.collapseInput()
                                                    
                                                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                                        $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                                                    })
                                                }
                                            }, nil)*/
                                            
                                            var enqueueMessages: [EnqueueMessage] = []
                                            if let textEnqueueMessage = textEnqueueMessage {
                                                enqueueMessages.append(textEnqueueMessage)
                                            }
                                            enqueueMessages.append(.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: media), replyToMessageId: replyMessageId, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))
                                            
                                            self.sendMessages(peer: targetPeer, messages: self.transformEnqueueMessages(messages: enqueueMessages, silentPosting: silent, scheduleTime: scheduleTime))
                                        } else {
                                            let contactController = component.context.sharedContext.makeDeviceContactInfoController(context: component.context, subject: .filter(peer: peerAndContactData.0?._asPeer(), contactId: nil, contactData: contactData, completion: { [weak self] peer, contactData in
                                                guard let self else {
                                                    return
                                                }
                                                if contactData.basicData.phoneNumbers.isEmpty {
                                                    return
                                                }
                                                let phone = contactData.basicData.phoneNumbers[0].value
                                                if let vCardData = contactData.serializedVCard() {
                                                    let media = TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: peer?.id, vCardData: vCardData)
                                                    let replyMessageId = targetMessageId
                                                    /*strongSelf.chatDisplayNode.setupSendActionOnViewUpdate({
                                                        if let strongSelf = self {
                                                            strongSelf.chatDisplayNode.collapseInput()
                                                            
                                                            strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                                                                $0.updatedInterfaceState { $0.withUpdatedReplyMessageId(nil) }
                                                            })
                                                        }
                                                    }, nil)*/
                                                    
                                                    var enqueueMessages: [EnqueueMessage] = []
                                                    if let textEnqueueMessage = textEnqueueMessage {
                                                        enqueueMessages.append(textEnqueueMessage)
                                                    }
                                                    enqueueMessages.append(.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: media), replyToMessageId: replyMessageId, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))
                                                    
                                                    self.sendMessages(peer: targetPeer, messages: self.transformEnqueueMessages(messages: enqueueMessages, silentPosting: silent, scheduleTime: scheduleTime))
                                                }
                                            }), completed: nil, cancelled: nil)
                                            self.environment?.controller()?.push(contactController)
                                        }
                                    }))
                                }
                            }))
                        case .poll:
                            let controller = self.configurePollCreation(peer: peer, targetMessageId: targetMessageId)
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
                            let replyMessageId = targetMessageId
                            let theme = environment.theme
                            let controller = WebAppController(context: component.context, updatedPresentationData: (component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: theme), component.context.sharedContext.presentationData |> map { $0.withUpdated(theme: theme) }), params: params, replyToMessageId: replyMessageId, threadId: nil)
                            controller.openUrl = { [weak self] url in
                                guard let self else {
                                    return
                                }
                                let _ = self
                                //self?.openUrl(url, concealed: true, forceExternal: true)
                            }
                            controller.getNavigationController = { [weak self] in
                                guard let self, let controller = self.environment?.controller() else {
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
                    let present = { [weak self] in
                        guard let self, let controller = self.environment?.controller() else {
                            return
                        }
                        attachmentController.navigationPresentation = .flatModal
                        controller.push(attachmentController)
                        self.attachmentController = attachmentController
                        self.updateIsProgressPaused()
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
            peer: EnginePeer,
            replyToMessageId: EngineMessage.Id?,
            subject: MediaPickerScreen.Subject = .assets(nil, .default),
            saveEditedPhotos: Bool,
            bannedSendPhotos: (Int32, Bool)?,
            bannedSendVideos: (Int32, Bool)?,
            present: @escaping (MediaPickerScreen, AttachmentMediaPickerContext?) -> Void,
            updateMediaPickerContext: @escaping (AttachmentMediaPickerContext?) -> Void,
            completion: @escaping ([Any], Bool, Int32?, @escaping (String) -> UIView?, @escaping () -> Void) -> Void
        ) {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            let theme = environment.theme
            let controller = MediaPickerScreen(context: component.context, updatedPresentationData: (component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: theme), component.context.sharedContext.presentationData |> map { $0.withUpdated(theme: theme) }), peer: peer, threadTitle: nil, chatLocation: .peer(id: peer.id), bannedSendPhotos: bannedSendPhotos, bannedSendVideos: bannedSendVideos, subject: subject, saveEditedPhotos: saveEditedPhotos)
            let mediaPickerContext = controller.mediaPickerContext
            controller.openCamera = { [weak self] cameraView in
                guard let self else {
                    return
                }
                self.openCamera(peer: peer, replyToMessageId: replyToMessageId, cameraView: cameraView)
            }
            controller.presentWebSearch = { [weak self, weak controller] mediaGroups, activateOnDisplay in
                guard let self, let controller else {
                    return
                }
                self.presentWebSearch(editingMessage: false, attachment: true, activateOnDisplay: activateOnDisplay, present: { [weak controller] c, a in
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
                guard let self else {
                    return
                }
                self.presentScheduleTimePicker(peer: peer, style: media ? .media : .default, completion: { time in
                    done(time)
                })
            }
            controller.presentTimerPicker = { [weak self] done in
                guard let self else {
                    return
                }
                self.presentTimerPicker(peer: peer, style: .media, completion: { time in
                    done(time)
                })
            }
            controller.getCaptionPanelView = { [weak self] in
                guard let self else {
                    return nil
                }
                return self.getCaptionPanelView(peer: peer)
            }
            controller.legacyCompletion = { signals, silently, scheduleTime, getAnimatedTransitionSource, sendCompletion in
                completion(signals, silently, scheduleTime, getAnimatedTransitionSource, sendCompletion)
            }
            present(controller, mediaPickerContext)
        }
        
        private func presentOldMediaPicker(peer: EnginePeer, replyMessageId: EngineMessage.Id?, fileMode: Bool, editingMedia: Bool, present: @escaping (AttachmentContainable, AttachmentMediaPickerContext) -> Void, completion: @escaping ([Any], Bool, Int32) -> Void) {
            guard let component = self.component else {
                return
            }
            guard let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View else {
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
            |> deliverOnMainQueue).start(next: { [weak self] settings, searchBotsConfiguration in
                guard let strongSelf = self, let component = strongSelf.component else {
                    return
                }
                var selectionLimit: Int = 100
                var slowModeEnabled = false
                if case let .channel(channel) = peer, channel.isRestrictedBySlowmode {
                    selectionLimit = 10
                    slowModeEnabled = true
                }
                
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                
                let _ = legacyAssetPicker(context: component.context, presentationData: presentationData, editingMedia: editingMedia, fileMode: fileMode, peer: peer._asPeer(), threadTitle: nil, saveEditedPhotos: settings.storeEditedPhotos, allowGrouping: true, selectionLimit: selectionLimit).start(next: { generator in
                    if let strongSelf = self, let component = strongSelf.component, let controller = strongSelf.environment?.controller() {
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
                                            
                        configureLegacyAssetPicker(controller, context: component.context, peer: peer._asPeer(), chatLocation: .peer(id: peer.id), initialCaption: inputText, hasSchedule: peer.id.namespace != Namespaces.Peer.SecretChat, presentWebSearch: editingMedia ? nil : { [weak legacyController] in
                            if let strongSelf = self, let component = strongSelf.component, let environment = strongSelf.environment {
                                let theme = environment.theme
                                let controller = WebSearchController(context: component.context, updatedPresentationData: (component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: theme), component.context.sharedContext.presentationData |> map { $0.withUpdated(theme: theme) }), peer: peer, chatLocation: .peer(id: peer.id), configuration: searchBotsConfiguration, mode: .media(attachment: false, completion: { results, selectionState, editingState, silentPosting in
                                    if let legacyController = legacyController {
                                        legacyController.dismiss()
                                    }
                                    legacyEnqueueWebSearchMessages(selectionState, editingState, enqueueChatContextResult: { result in
                                        if let strongSelf = self {
                                            strongSelf.enqueueChatContextResult(peer: peer, replyMessageId: replyMessageId, results: results, result: result, hideVia: true)
                                        }
                                    }, enqueueMediaMessages: { signals in
                                        if let strongSelf = self {
                                            if editingMedia {
                                                strongSelf.editMessageMediaWithLegacySignals(signals)
                                            } else {
                                                strongSelf.enqueueMediaMessages(peer: peer, replyToMessageId: replyMessageId, signals: signals, silentPosting: silentPosting)
                                            }
                                        }
                                    })
                                }))
                                controller.getCaptionPanelView = {
                                    guard let self else {
                                        return nil
                                    }
                                    return self.getCaptionPanelView(peer: peer)
                                }
                                strongSelf.environment?.controller()?.push(controller)
                            }
                        }, presentSelectionLimitExceeded: {
                            guard let strongSelf = self else {
                                return
                            }
                            
                            let text: String
                            if slowModeEnabled {
                                text = presentationData.strings.Chat_SlowmodeAttachmentLimitReached
                            } else {
                                text = presentationData.strings.Chat_AttachmentLimitReached
                            }
                            
                            strongSelf.environment?.controller()?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                        }, presentSchedulePicker: { media, done in
                            if let strongSelf = self {
                                strongSelf.presentScheduleTimePicker(peer: peer, style: media ? .media : .default, completion: { time in
                                     done(time)
                                })
                            }
                        }, presentTimerPicker: { done in
                            if let strongSelf = self {
                                strongSelf.presentTimerPicker(peer: peer, style: .media, completion: { time in
                                    done(time)
                                })
                            }
                        }, getCaptionPanelView: {
                            guard let self else {
                                return nil
                            }
                            return self.getCaptionPanelView(peer: peer)
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
                        strongSelf.endEditing(true)
                        present(legacyController, LegacyAssetPickerContext(controller: controller))
                    }
                })
            })
        }
        
        private func presentFileGallery(peer: EnginePeer, replyMessageId: EngineMessage.Id?, editingMessage: Bool = false) {
            self.presentOldMediaPicker(peer: peer, replyMessageId: replyMessageId, fileMode: true, editingMedia: editingMessage, present: { [weak self] c, _ in
                self?.environment?.controller()?.push(c)
            }, completion: { [weak self] signals, silentPosting, scheduleTime in
                if editingMessage {
                    self?.editMessageMediaWithLegacySignals(signals)
                } else {
                    self?.enqueueMediaMessages(peer: peer, replyToMessageId: replyMessageId, signals: signals, silentPosting: silentPosting, scheduleTime: scheduleTime > 0 ? scheduleTime : nil)
                }
            })
        }
        
        private func presentICloudFileGallery(peer: EnginePeer, replyMessageId: EngineMessage.Id?) {
            guard let component = self.component else {
                return
            }
            let _ = (component.context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: component.context.account.peerId),
                TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: false),
                TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: true)
            )
            |> deliverOnMainQueue).start(next: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                let (accountPeer, limits, premiumLimits) = result
                let isPremium = accountPeer?.isPremium ?? false
                
                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                
                strongSelf.environment?.controller()?.present(legacyICloudFilePicker(theme: presentationData.theme, completion: { [weak self] urls in
                    if let strongSelf = self, !urls.isEmpty {
                        var signals: [Signal<ICloudFileDescription?, NoError>] = []
                        for url in urls {
                            signals.append(iCloudFileDescription(url))
                        }
                        strongSelf.enqueueMediaMessageDisposable.set((combineLatest(signals)
                        |> deliverOnMainQueue).start(next: { results in
                            if let strongSelf = self, let component = strongSelf.component {
                                for item in results {
                                    if let item = item {
                                        if item.fileSize > Int64(premiumLimits.maxUploadFileParts) * 512 * 1024 {
                                            let controller = PremiumLimitScreen(context: component.context, subject: .files, count: 4, action: {
                                            })
                                            strongSelf.environment?.controller()?.push(controller)
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
                                            strongSelf.environment?.controller()?.push(controller)
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
                                        let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), replyToMessageId: replyMessageId, localGroupingKey: groupingKey, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                                        messages.append(message)
                                    }
                                    if let _ = groupingKey, messages.count % 10 == 0 {
                                        groupingKey = Int64.random(in: Int64.min ... Int64.max)
                                    }
                                }
                                
                                if !messages.isEmpty {
                                    strongSelf.sendMessages(peer: peer, messages: messages)
                                }
                            }
                        }))
                    }
                }), in: .window(.root))
            })
        }
        
        private func enqueueChatContextResult(peer: EnginePeer, replyMessageId: EngineMessage.Id?, results: ChatContextResultCollection, result: ChatContextResult, hideVia: Bool = false, closeMediaInput: Bool = false, silentPosting: Bool = false, resetTextInputState: Bool = true) {
            if !canSendMessagesToPeer(peer._asPeer()) {
                return
            }
            
            let sendMessage: (Int32?) -> Void = { [weak self] scheduleTime in
                guard let self, let component = self.component else {
                    return
                }
                if component.context.engine.messages.enqueueOutgoingMessageWithChatContextResult(to: peer.id, threadId: nil, botId: results.botId, result: result, replyToMessageId: replyMessageId, hideVia: hideVia, silentPosting: silentPosting, scheduleTime: scheduleTime) {
                }
                
                if let attachmentController = self.attachmentController {
                    attachmentController.dismiss(animated: true)
                }
            }
            
            sendMessage(nil)
        }
        
        private func presentWebSearch(editingMessage: Bool, attachment: Bool, activateOnDisplay: Bool = true, present: @escaping (ViewController, Any?) -> Void) {
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
        
        private func getCaptionPanelView(peer: EnginePeer) -> TGCaptionPanelView? {
            guard let component = self.component else {
                return nil
            }
            //TODO:self.presentationInterfaceState.customEmojiAvailable
            return component.context.sharedContext.makeGalleryCaptionPanelView(context: component.context, chatLocation: .peer(id: peer.id), customEmojiAvailable: true, present: { [weak self] c in
                guard let self else {
                    return
                }
                self.environment?.controller()?.present(c, in: .window(.root))
            }, presentInGlobalOverlay: { [weak self] c in
                guard let self else {
                    return
                }
                self.environment?.controller()?.presentInGlobalOverlay(c)
            }) as? TGCaptionPanelView
        }
        
        private func openCamera(peer: EnginePeer, replyToMessageId: EngineMessage.Id?, cameraView: TGAttachmentCameraView? = nil) {
            guard let component = self.component else {
                return
            }
            guard let inputPanelView = self.inputPanel.view as? MessageInputPanelComponent.View else {
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
            |> deliverOnMainQueue).start(next: { [weak self] settings in
                guard let self, let component = self.component, let parentController = self.environment?.controller() else {
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
                
                presentedLegacyCamera(context: component.context, peer: peer._asPeer(), chatLocation: .peer(id: peer.id), cameraView: cameraView, menuController: nil, parentController: parentController, attachmentController: self.attachmentController, editingMedia: false, saveCapturedPhotos: storeCapturedMedia, mediaGrouping: true, initialCaption: inputText, hasSchedule: peer.id.namespace != Namespaces.Peer.SecretChat, enablePhoto: enablePhoto, enableVideo: enableVideo, sendMessagesWithSignals: { [weak self] signals, silentPosting, scheduleTime in
                    guard let self else {
                        return
                    }
                    self.enqueueMediaMessages(peer: peer, replyToMessageId: replyToMessageId, signals: signals, silentPosting: silentPosting, scheduleTime: scheduleTime > 0 ? scheduleTime : nil)
                    if !inputText.string.isEmpty {
                        self.clearInputText()
                    }
                }, recognizedQRCode: { _ in
                }, presentSchedulePicker: { [weak self] _, done in
                    guard let self else {
                        return
                    }
                    self.presentScheduleTimePicker(peer: peer, style: .media, completion: { time in
                        done(time)
                    })
                }, presentTimerPicker: { [weak self] done in
                    guard let self else {
                        return
                    }
                    self.presentTimerPicker(peer: peer, style: .media, completion: { time in
                        done(time)
                    })
                }, getCaptionPanelView: { [weak self] in
                    guard let self else {
                        return nil
                    }
                    return self.getCaptionPanelView(peer: peer)
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
            peer: EnginePeer,
            style: ChatScheduleTimeControllerStyle = .default,
            selectedTime: Int32? = nil,
            dismissByTapOutside: Bool = true,
            completion: @escaping (Int32) -> Void
        ) {
            guard let component = self.component else {
                return
            }
            let _ = (component.context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Presence(id: peer.id)
            )
            |> deliverOnMainQueue).start(next: { [weak self] presence in
                guard let self, let component = self.component, let environment = self.environment else {
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
                let theme = environment.theme
                let controller = ChatScheduleTimeController(context: component.context, updatedPresentationData: (component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: theme), component.context.sharedContext.presentationData |> map { $0.withUpdated(theme: theme) }), peerId: peer.id, mode: mode, style: style, currentTime: selectedTime, minimalTime: nil, dismissByTapOutside: dismissByTapOutside, completion: { time in
                    completion(time)
                })
                self.endEditing(true)
                self.environment?.controller()?.present(controller, in: .window(.root))
            })
        }
        
        private func presentTimerPicker(peer: EnginePeer, style: ChatTimerScreenStyle = .default, selectedTime: Int32? = nil, dismissByTapOutside: Bool = true, completion: @escaping (Int32) -> Void) {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            let theme = environment.theme
            let controller = ChatTimerScreen(context: component.context, updatedPresentationData: (component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: theme), component.context.sharedContext.presentationData |> map { $0.withUpdated(theme: theme) }), style: style, currentTime: selectedTime, dismissByTapOutside: dismissByTapOutside, completion: { time in
                completion(time)
            })
            self.endEditing(true)
            self.environment?.controller()?.present(controller, in: .window(.root))
        }
        
        private func configurePollCreation(peer: EnginePeer, targetMessageId: EngineMessage.Id, isQuiz: Bool? = nil) -> CreatePollControllerImpl? {
            guard let component = self.component, let environment = self.environment else {
                return nil
            }
            let theme = environment.theme
            return createPollController(context: component.context, updatedPresentationData: (component.context.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: theme), component.context.sharedContext.presentationData |> map { $0.withUpdated(theme: theme) }), peer: peer, isQuiz: isQuiz, completion: { [weak self] poll in
                guard let self else {
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
                    localGroupingKey: nil,
                    correlationId: nil,
                    bubbleUpEmojiOrStickersets: []
                )
                self.sendMessages(peer: peer, messages: [message.withUpdatedReplyToMessageId(replyMessageId)])
            })
        }
        
        private func transformEnqueueMessages(messages: [EnqueueMessage], silentPosting: Bool, scheduleTime: Int32? = nil) -> [EnqueueMessage] {
            guard let focusedItemId = self.focusedItemId, let focusedItem = self.currentSlice?.items.first(where: { $0.id == focusedItemId }) else {
                return []
            }
            guard let targetMessageId = focusedItem.targetMessageId else {
                return []
            }
            
            let defaultReplyMessageId: EngineMessage.Id? = targetMessageId
            
            return messages.map { message in
                var message = message
                
                if let defaultReplyMessageId = defaultReplyMessageId {
                    switch message {
                    case let .message(text, attributes, inlineStickers, mediaReference, replyToMessageId, localGroupingKey, correlationId, bubbleUpEmojiOrStickersets):
                        if replyToMessageId == nil {
                            message = .message(text: text, attributes: attributes, inlineStickers: inlineStickers, mediaReference: mediaReference, replyToMessageId: defaultReplyMessageId, localGroupingKey: localGroupingKey, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)
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
        
        private func sendMessages(peer: EnginePeer, messages: [EnqueueMessage], media: Bool = false, commit: Bool = false) {
            guard let component = self.component else {
                return
            }
            let _ = (enqueueMessages(account: component.context.account, peerId: peer.id, messages: self.transformEnqueueMessages(messages: messages, silentPosting: false))
            |> deliverOnMainQueue).start()
            
            donateSendMessageIntent(account: component.context.account, sharedContext: component.context.sharedContext, intentContext: .chat, peerIds: [peer.id])
            
            if let attachmentController = self.attachmentController {
                attachmentController.dismiss(animated: true)
            }
            
            if let controller = self.environment?.controller() {
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
        
        private func enqueueMediaMessages(peer: EnginePeer, replyToMessageId: EngineMessage.Id?, signals: [Any]?, silentPosting: Bool, scheduleTime: Int32? = nil, getAnimatedTransitionSource: ((String) -> UIView?)? = nil, completion: @escaping () -> Void = {}) {
            guard let component = self.component else {
                return
            }
            
            self.enqueueMediaMessageDisposable.set((legacyAssetPickerEnqueueMessages(context: component.context, account: component.context.account, signals: signals!)
            |> deliverOnMainQueue).start(next: { [weak self] items in
                if let strongSelf = self {
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
                                                        
                    let messages = strongSelf.transformEnqueueMessages(messages: mappedMessages, silentPosting: silentPosting, scheduleTime: scheduleTime)

                    strongSelf.sendMessages(peer: peer, messages: messages.map { $0.withUpdatedReplyToMessageId(replyToMessageId) }, media: true)
                    
                    if let _ = scheduleTime {
                        completion()
                    }
                }
            }))
        }
        
        private func editMessageMediaWithLegacySignals(_ signals: [Any]) {
            guard let component = self.component else {
                return
            }
            let _ = (legacyAssetPickerEnqueueMessages(context: component.context, account: component.context.account, signals: signals)
            |> deliverOnMainQueue).start()
        }*/
        
        private func updatePreloads() {
            /*var validIds: [AnyHashable] = []
            if let currentSlice = self.currentSlice, let focusedItemId = self.focusedItemId, let currentIndex = currentSlice.items.firstIndex(where: { $0.id == focusedItemId }) {
                for i in 0 ..< 2 {
                    var nextIndex: Int = currentIndex + 1 + i
                    nextIndex = max(0, min(nextIndex, currentSlice.items.count - 1))
                    if nextIndex != currentIndex {
                        let nextItem = currentSlice.items[nextIndex]
                        
                        validIds.append(nextItem.id)
                        if self.preloadContexts[nextItem.id] == nil {
                            if let signal = nextItem.preload {
                                self.preloadContexts[nextItem.id] = signal.start()
                            }
                        }
                    }
                }
            }
            
            var removeIds: [AnyHashable] = []
            for (id, disposable) in self.preloadContexts {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    disposable.dispose()
                }
            }
            for id in removeIds {
                self.preloadContexts.removeValue(forKey: id)
            }*/
        }
        
        func update(component: StoryContainerScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
            let isFirstTime = self.component == nil
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            self.environment = environment
            
            self.component = component
            self.state = state
            
            if isFirstTime {
                if let initialFocusedId = component.initialFocusedId, component.initialContent.contains(where: { $0.id == initialFocusedId }) {
                    self.focusedItemSet = initialFocusedId
                } else {
                    self.focusedItemSet = component.initialContent.first?.id
                }
                self.itemSets = component.initialContent
            }
            
            var isProgressPaused = false
            if self.itemSetPanState != nil {
                isProgressPaused = true
            }
            
            var contentDerivedBottomInset: CGFloat = environment.safeInsets.bottom
            
            var validIds: [AnyHashable] = []
            if let focusedItemSet = self.focusedItemSet, let focusedIndex = self.itemSets.firstIndex(where: { $0.id == focusedItemSet }) {
                for i in max(0, focusedIndex - 1) ... min(focusedIndex + 1, self.itemSets.count - 1) {
                    var isItemVisible = false
                    if i == focusedIndex {
                        isItemVisible = true
                    }
                    
                    let itemSet = self.itemSets[i]
                    
                    if let itemSetPanState = self.itemSetPanState {
                        if self.visibleItemSetViews[itemSet.id] != nil {
                            isItemVisible = true
                        }
                        if itemSetPanState.fraction < 0.0 && i == focusedIndex - 1 {
                            isItemVisible = true
                        }
                        if itemSetPanState.fraction > 0.0 && i == focusedIndex + 1 {
                            isItemVisible = true
                        }
                    }
                    
                    if isItemVisible {
                        validIds.append(itemSet.id)
                        
                        let itemSetView: ItemSetView
                        var itemSetTransition = transition
                        if let current = self.visibleItemSetViews[itemSet.id] {
                            itemSetView = current
                        } else {
                            itemSetTransition = .immediate
                            itemSetView = ItemSetView()
                            self.visibleItemSetViews[itemSet.id] = itemSetView
                        }
                        let _ = itemSetView.view.update(
                            transition: itemSetTransition,
                            component: AnyComponent(StoryItemSetContainerComponent(
                                context: component.context,
                                externalState: itemSetView.externalState,
                                initialItemSlice: itemSet,
                                theme: environment.theme,
                                strings: environment.strings,
                                containerInsets: UIEdgeInsets(top: environment.statusBarHeight, left: 0.0, bottom: environment.inputHeight, right: 0.0),
                                safeInsets: environment.safeInsets,
                                inputHeight: environment.inputHeight,
                                isProgressPaused: isProgressPaused || i != focusedIndex,
                                audioRecorder: i == focusedIndex ? self.audioRecorderValue : nil,
                                videoRecorder: i == focusedIndex ? self.videoRecorderValue : nil,
                                hideUI: i == focusedIndex && self.itemSetPanState?.didBegin == false,
                                presentController: { [weak self] c in
                                    guard let self, let environment = self.environment else {
                                        return
                                    }
                                    if c is UndoOverlayController {
                                        environment.controller()?.present(c, in: .current)
                                    } else {
                                        environment.controller()?.present(c, in: .window(.root))
                                    }
                                },
                                close: { [weak self] in
                                    guard let self, let environment = self.environment else {
                                        return
                                    }
                                    environment.controller()?.dismiss()
                                },
                                navigateToItemSet: { [weak self] direction in
                                    guard let self, let environment = self.environment else {
                                        return
                                    }
                                    
                                    if let focusedItemSet = self.focusedItemSet, let focusedIndex = self.itemSets.firstIndex(where: { $0.id == focusedItemSet }) {
                                        var switchToIndex = focusedIndex
                                        switch direction {
                                        case .previous:
                                            switchToIndex -= 1
                                        case .next:
                                            switchToIndex += 1
                                        }
                                        
                                        switchToIndex = max(0, min(switchToIndex, self.itemSets.count - 1))
                                        if switchToIndex != focusedIndex {
                                            self.focusedItemSet = self.itemSets[switchToIndex].id
                                            self.state?.updated(transition: .immediate)
                                        } else if switchToIndex == self.itemSets.count - 1 {
                                            environment.controller()?.dismiss()
                                        }
                                    } else {
                                        environment.controller()?.dismiss()
                                    }
                                },
                                controller: { [weak self] in
                                    return self?.environment?.controller()
                                }
                            )),
                            environment: {},
                            containerSize: availableSize
                        )
                        
                        if i == focusedIndex {
                            contentDerivedBottomInset = itemSetView.externalState.derivedBottomInset
                        }
                        
                        let itemFrame = CGRect(origin: CGPoint(), size: availableSize)
                        if let itemSetComponentView = itemSetView.view.view {
                            if itemSetView.superview == nil {
                                self.addSubview(itemSetView)
                            }
                            if itemSetComponentView.superview == nil {
                                itemSetComponentView.layer.isDoubleSided = false
                                itemSetView.addSubview(itemSetComponentView)
                                itemSetView.layer.addSublayer(itemSetView.tintLayer)
                            }
                            
                            itemSetTransition.setPosition(view: itemSetView, position: itemFrame.center)
                            itemSetTransition.setBounds(view: itemSetView, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
                            
                            itemSetTransition.setPosition(view: itemSetComponentView, position: CGRect(origin: CGPoint(), size: itemFrame.size).center)
                            itemSetTransition.setBounds(view: itemSetComponentView, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
                            
                            itemSetTransition.setPosition(layer: itemSetView.tintLayer, position: CGRect(origin: CGPoint(), size: itemFrame.size).center)
                            itemSetTransition.setBounds(layer: itemSetView.tintLayer, bounds: CGRect(origin: CGPoint(), size: itemFrame.size))
                            
                            let perspectiveConstant: CGFloat = 500.0
                            let width = itemFrame.width
                            
                            let sideDistance: CGFloat = 40.0
                            
                            let sideAngle_d: CGFloat = -pow(perspectiveConstant, 2)*pow(sideDistance, 2)
                            let sideAngle_e: CGFloat = pow(perspectiveConstant, 2)*pow(width, 2)
                            let sideAngle_f: CGFloat = pow(sideDistance, 2)*pow(width, 2)
                            let sideAngle_c: CGFloat = sqrt(sideAngle_d + sideAngle_e + sideAngle_f + sideDistance*pow(width, 3) + 0.25*pow(width, 4))
                            let sideAngle_a: CGFloat = (2.0*perspectiveConstant*width - 2.0*sideAngle_c)
                            let sideAngle_b: CGFloat = (-2.0*perspectiveConstant*sideDistance + 2.0*sideDistance*width + pow(width, 2))
                            
                            let sideAngle: CGFloat = 2.0*atan(sideAngle_a / sideAngle_b)
                            
                            let faceTransform = CATransform3DMakeTranslation(0, 0, itemFrame.width * 0.5)
                            
                            func calculateCubeTransform(rotationFraction: CGFloat, sideAngle: CGFloat, cubeSize: CGSize) -> CATransform3D {
                                let t = rotationFraction
                                let absT = abs(rotationFraction)
                                let currentAngle = t * (CGFloat.pi * 0.5 + sideAngle)
                                let width = cubeSize.width
                                
                                let cubeDistance_a: CGFloat = -1.4142135623731*absT*cos(sideAngle + 0.785398163397448)
                                let cubeDistance_b: CGFloat = sin(sideAngle*absT + 1.5707963267949*absT + 0.785398163397448)
                                var cubeDistance: CGFloat = 0.5*width*(cubeDistance_a + absT + 1.4142135623731*cubeDistance_b - 1.0)
                                cubeDistance *= 1.0
                                
                                let backDistance_a = sqrt(pow(width, 2.0))
                                let backDistance_b = tan(sideAngle) / 2.0
                                let backDistance_c = sqrt(pow(width, 2.0))
                                let backDistance_d = (2*cos(sideAngle))
                                let backDistance: CGFloat = width / 2.0 + backDistance_a * backDistance_b - backDistance_c / backDistance_d
                                
                                var perspective = CATransform3DIdentity
                                perspective.m34 = -1 / perspectiveConstant
                                let initialCubeTransform = CATransform3DTranslate(perspective, 0.0, 0.0, -cubeSize.width * 0.5)
                                
                                var targetTransform = initialCubeTransform
                                targetTransform = CATransform3DTranslate(targetTransform, 0.0, 0.0, -cubeDistance + backDistance)
                                targetTransform = CATransform3DConcat(CATransform3DMakeRotation(currentAngle, 0, 1, 0), targetTransform)
                                targetTransform = CATransform3DTranslate(targetTransform, 0.0, 0.0, -backDistance)
                                
                                return targetTransform
                            }
                            
                            let cubeAdditionalRotationFraction: CGFloat
                            if i == focusedIndex {
                                cubeAdditionalRotationFraction = 0.0
                            } else if i < focusedIndex {
                                cubeAdditionalRotationFraction = -1.0
                            } else {
                                cubeAdditionalRotationFraction = 1.0
                            }
                            
                            var panFraction: CGFloat = 0.0
                            if let itemSetPanState = self.itemSetPanState {
                                panFraction = -itemSetPanState.fraction
                            }
                            
                            Transition.immediate.setTransform(view: itemSetComponentView, transform: faceTransform)
                            Transition.immediate.setTransform(layer: itemSetView.tintLayer, transform: faceTransform)
                            
                            if let previousRotationFraction = itemSetView.rotationFraction, "".isEmpty {
                                let fromT = previousRotationFraction
                                let toT = panFraction
                                itemSetTransition.setTransformAsKeyframes(view: itemSetView, transform: { sourceT in
                                    let t = fromT * (1.0 - sourceT) + toT * sourceT
                                    
                                    return calculateCubeTransform(rotationFraction: t + cubeAdditionalRotationFraction, sideAngle: sideAngle, cubeSize: itemFrame.size)
                                })
                            } else {
                                itemSetTransition.setTransform(view: itemSetView, transform: calculateCubeTransform(rotationFraction: panFraction + cubeAdditionalRotationFraction, sideAngle: sideAngle, cubeSize: itemFrame.size))
                            }
                            itemSetView.rotationFraction = panFraction
                            
                            var alphaFraction = panFraction + cubeAdditionalRotationFraction
                            
                            if alphaFraction != 0.0 {
                                if alphaFraction < 0.0 {
                                    itemSetView.tintLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
                                    itemSetView.tintLayer.endPoint = CGPoint(x: 1.0, y: 0.0)
                                } else {
                                    itemSetView.tintLayer.startPoint = CGPoint(x: 1.0, y: 0.0)
                                    itemSetView.tintLayer.endPoint = CGPoint(x: 0.0, y: 0.0)
                                }
                            }
                            
                            alphaFraction *= 1.3
                            alphaFraction = max(-1.0, min(1.0, alphaFraction))
                            alphaFraction = abs(alphaFraction)
                            
                            itemSetTransition.setAlpha(layer: itemSetView.tintLayer, alpha: alphaFraction)
                        }
                    }
                }
            }
            var removedIds: [AnyHashable] = []
            for (id, itemSetView) in self.visibleItemSetViews {
                if !validIds.contains(id) {
                    removedIds.append(id)
                    itemSetView.removeFromSuperview()
                }
            }
            for id in removedIds {
                self.visibleItemSetViews.removeValue(forKey: id)
            }
            
            if let controller = environment.controller() {
                let subLayout = ContainerViewLayout(
                    size: availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: contentDerivedBottomInset, right: 0.0),
                    safeInsets: UIEdgeInsets(),
                    additionalInsets: UIEdgeInsets(),
                    statusBarHeight: nil,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(subLayout, transition: transition.containedViewLayoutTransition)
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class StoryContainerScreen: ViewControllerComponentContainer {
    public final class TransitionIn {
        public weak var sourceView: UIView?
        public let sourceRect: CGRect
        public let sourceCornerRadius: CGFloat
        
        public init(
            sourceView: UIView,
            sourceRect: CGRect,
            sourceCornerRadius: CGFloat
        ) {
            self.sourceView = sourceView
            self.sourceRect = sourceRect
            self.sourceCornerRadius = sourceCornerRadius
        }
    }
    
    private let context: AccountContext
    private var isDismissed: Bool = false
    
    public init(
        context: AccountContext,
        initialFocusedId: AnyHashable?,
        initialContent: [StoryContentItemSlice],
        transitionIn: TransitionIn?
    ) {
        self.context = context
        
        super.init(context: context, component: StoryContainerScreenComponent(
            context: context,
            initialFocusedId: initialFocusedId,
            initialContent: initialContent,
            transitionIn: transitionIn
        ), navigationBarAppearance: .none, theme: .dark)
        
        self.statusBar.statusBarStyle = .White
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
        self.automaticallyControlPresentationContextLayout = false
        
        self.context.sharedContext.hasPreloadBlockingContent.set(.single(true))
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.context.sharedContext.hasPreloadBlockingContent.set(.single(false))
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.view.disablesInteractiveModalDismiss = true
        
        if let componentView = self.node.hostView.componentView as? StoryContainerScreenComponent.View {
            componentView.animateIn()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            
            self.statusBar.updateStatusBarStyle(.Ignore, animated: true)
            
            if let componentView = self.node.hostView.componentView as? StoryContainerScreenComponent.View {
                componentView.endEditing(true)
                
                componentView.animateOut(completion: { [weak self] in
                    completion?()
                    self?.dismiss(animated: false)
                })
            } else {
                self.dismiss(animated: false)
            }
        }
    }
}

func allowedStoryReactions(context: AccountContext) -> Signal<[ReactionItem], NoError> {
    let viewKey: PostboxViewKey = .orderedItemList(id: Namespaces.OrderedItemList.CloudTopReactions)
    let topReactions = context.account.postbox.combinedView(keys: [viewKey])
    |> map { views -> [RecentReactionItem] in
        guard let view = views.views[viewKey] as? OrderedItemListView else {
            return []
        }
        return view.items.compactMap { item -> RecentReactionItem? in
            return item.contents.get(RecentReactionItem.self)
        }
    }

    return combineLatest(
        context.engine.stickers.availableReactions(),
        topReactions
    )
    |> take(1)
    |> map { availableReactions, topReactions -> [ReactionItem] in
        guard let availableReactions = availableReactions else {
            return []
        }
        
        var result: [ReactionItem] = []
        
        var existingIds = Set<MessageReaction.Reaction>()
        
        for topReaction in topReactions {
            switch topReaction.content {
            case let .builtin(value):
                if let reaction = availableReactions.reactions.first(where: { $0.value == .builtin(value) }) {
                    guard let centerAnimation = reaction.centerAnimation else {
                        continue
                    }
                    guard let aroundAnimation = reaction.aroundAnimation else {
                        continue
                    }
                    
                    if existingIds.contains(reaction.value) {
                        continue
                    }
                    existingIds.insert(reaction.value)
                    
                    result.append(ReactionItem(
                        reaction: ReactionItem.Reaction(rawValue: reaction.value),
                        appearAnimation: reaction.appearAnimation,
                        stillAnimation: reaction.selectAnimation,
                        listAnimation: centerAnimation,
                        largeListAnimation: reaction.activateAnimation,
                        applicationAnimation: aroundAnimation,
                        largeApplicationAnimation: reaction.effectAnimation,
                        isCustom: false
                    ))
                } else {
                    continue
                }
            case let .custom(file):
                if existingIds.contains(.custom(file.fileId.id)) {
                    continue
                }
                existingIds.insert(.custom(file.fileId.id))
                
                result.append(ReactionItem(
                    reaction: ReactionItem.Reaction(rawValue: .custom(file.fileId.id)),
                    appearAnimation: file,
                    stillAnimation: file,
                    listAnimation: file,
                    largeListAnimation: file,
                    applicationAnimation: nil,
                    largeApplicationAnimation: nil,
                    isCustom: true
                ))
            }
        }
        
        for reaction in availableReactions.reactions {
            guard let centerAnimation = reaction.centerAnimation else {
                continue
            }
            guard let aroundAnimation = reaction.aroundAnimation else {
                continue
            }
            if !reaction.isEnabled {
                continue
            }
            
            if existingIds.contains(reaction.value) {
                continue
            }
            existingIds.insert(reaction.value)
            
            result.append(ReactionItem(
                reaction: ReactionItem.Reaction(rawValue: reaction.value),
                appearAnimation: reaction.appearAnimation,
                stillAnimation: reaction.selectAnimation,
                listAnimation: centerAnimation,
                largeListAnimation: reaction.activateAnimation,
                applicationAnimation: aroundAnimation,
                largeApplicationAnimation: reaction.effectAnimation,
                isCustom: false
            ))
        }

        return result
    }
}

