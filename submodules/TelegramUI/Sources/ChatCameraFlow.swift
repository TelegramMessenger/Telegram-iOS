import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import LegacyComponents
import LegacyMediaPickerUI
import Camera
import CameraScreen
import ChatMediaSend
import ChatMediaEditorScreen

public typealias ChatCameraFlowCompletion = (_ fromGallery: Bool, _ messages: Signal<[LegacyAssetPickerEnqueueMessage], Void>, _ count: Int32, _ silently: Bool, _ scheduleTime: Int32?, _ parameters: ChatSendMessageActionSheetController.SendParameters?, _ getAnimatedTransitionSource: @escaping (String) -> UIView?, _ completion: @escaping () -> Void) -> Void

public struct ChatCameraFlowParameters {
    public var camera: ChatCameraParams
    public var peer: EnginePeer?
    public var threadTitle: String?
    public var isEditingMessage: Bool
    public var mediaGrouping: Bool
    public var initialCaption: NSAttributedString
    public var hasSchedule: Bool
    public var sendPaidMessageStars: Int64
    public var getCaptionPanelView: () -> TGCaptionPanelView?
    public var presentSchedulePicker: (@escaping (Int32, Bool) -> Void) -> Void
    public var presentTimerPicker: (@escaping (Int32) -> Void) -> Void

    public init(
        camera: ChatCameraParams,
        peer: EnginePeer?,
        threadTitle: String? = nil,
        isEditingMessage: Bool,
        mediaGrouping: Bool,
        initialCaption: NSAttributedString,
        hasSchedule: Bool,
        sendPaidMessageStars: Int64 = 0,
        getCaptionPanelView: @escaping () -> TGCaptionPanelView?,
        presentSchedulePicker: @escaping (@escaping (Int32, Bool) -> Void) -> Void,
        presentTimerPicker: @escaping (@escaping (Int32) -> Void) -> Void
    ) {
        self.camera = camera
        self.peer = peer
        self.threadTitle = threadTitle
        self.isEditingMessage = isEditingMessage
        self.mediaGrouping = mediaGrouping
        self.initialCaption = initialCaption
        self.hasSchedule = hasSchedule
        self.sendPaidMessageStars = sendPaidMessageStars
        self.getCaptionPanelView = getCaptionPanelView
        self.presentSchedulePicker = presentSchedulePicker
        self.presentTimerPicker = presentTimerPicker
    }

    var isSecretChat: Bool {
        return self.peer?.id.namespace == Namespaces.Peer.SecretChat
    }
}

public func makeChatCameraScreen(context: AccountContext, parameters: ChatCameraFlowParameters, holder: CameraHolder? = nil, transitionIn: CameraScreenImpl.TransitionIn? = nil, transitionOut: @escaping (Bool) -> CameraScreenImpl.TransitionOut? = { _ in nil }, completion: @escaping ChatCameraFlowCompletion) -> CameraScreenImpl {
    var cameraMode: CameraScreenImpl.CameraMode = .photo
    if case .video = chatCameraInitialMode(allowPhoto: parameters.camera.allowPhoto, allowVideo: parameters.camera.allowVideo) {
        cameraMode = .video
    }
    let camera = CameraScreenImpl(
        context: context,
        mode: .chat(parameters.camera),
        cameraMode: cameraMode,
        holder: holder,
        transitionIn: transitionIn,
        transitionOut: transitionOut,
        completion: { _, _, _, _ in
        }
    )
    let flow = ChatCameraFlow(context: context, parameters: parameters, completion: completion)
    flow.attach(camera: camera)
    return camera
}

public func makePassportCameraScreen(context: AccountContext, intent: PassportCaptureIntent, holder: CameraHolder? = nil, transitionIn: CameraScreenImpl.TransitionIn? = nil, transitionOut: @escaping (Bool) -> CameraScreenImpl.TransitionOut? = { _ in nil }, completion: @escaping ([TelegramMediaResource]) -> Void) -> CameraScreenImpl {
    let parameters = ChatCameraFlowParameters(
        camera: passportChatCameraParams(intent: intent),
        peer: nil,
        isEditingMessage: false,
        mediaGrouping: false,
        initialCaption: NSAttributedString(),
        hasSchedule: false,
        getCaptionPanelView: {
            return nil
        },
        presentSchedulePicker: { _ in
        },
        presentTimerPicker: { _ in
        }
    )
    let camera = CameraScreenImpl(
        context: context,
        mode: .chat(parameters.camera),
        cameraMode: .photo,
        holder: holder,
        transitionIn: transitionIn,
        transitionOut: transitionOut,
        completion: { _, _, _, _ in
        }
    )
    let flow = ChatCameraFlow(context: context, parameters: parameters, output: .passportImages(completion))
    flow.attach(camera: camera)
    return camera
}

public func presentChatCamera(context: AccountContext, parameters: ChatCameraFlowParameters, parentController: ViewController, holder: CameraHolder? = nil, transitionIn: CameraScreenImpl.TransitionIn? = nil, transitionOut: @escaping (Bool) -> CameraScreenImpl.TransitionOut? = { _ in nil }, completion: @escaping ChatCameraFlowCompletion) {
    let camera = makeChatCameraScreen(context: context, parameters: parameters, holder: holder, transitionIn: transitionIn, transitionOut: transitionOut, completion: completion)
    parentController.push(camera)
}

func chatCameraCapturedItem(_ item: CameraBatch.Item) -> ChatMediaEditorCapturedItem {
    switch item.content {
    case let .image(path, dimensions):
        return ChatMediaEditorCapturedItem(uniqueId: item.uniqueId, content: .image(path: path, dimensions: dimensions), thumbnail: item.thumbnail)
    case let .video(path, dimensions, duration, mirror, cover):
        return ChatMediaEditorCapturedItem(uniqueId: item.uniqueId, content: .video(path: path, dimensions: dimensions, duration: duration, mirror: mirror), thumbnail: item.thumbnail ?? cover)
    }
}

func chatCameraItemPath(_ item: CameraBatch.Item) -> String {
    switch item.content {
    case let .image(path, _):
        return path
    case let .video(path, _, _, _, _):
        return path
    }
}

private let chatCameraFileQueue = Queue(name: "ChatCameraFlowFiles", qos: .utility)

private func chatCameraDeleteFiles(_ paths: [String]) {
    if paths.isEmpty {
        return
    }
    chatCameraFileQueue.async {
        for path in paths {
            let _ = try? FileManager.default.removeItem(atPath: path)
        }
    }
}

private enum ChatCameraFlowOutput {
    case messages(ChatCameraFlowCompletion)
    case passportImages(([TelegramMediaResource]) -> Void)
}

final class ChatCameraFlow {
    private let context: AccountContext
    private let parameters: ChatCameraFlowParameters
    private let output: ChatCameraFlowOutput
    private let session: ChatMediaEditorCaptureSession
    private weak var camera: CameraScreenImpl?
    private var batchDisposable: Disposable?
    private weak var review: ChatMediaEditorScreen?
    private var reviewSource: ChatMediaEditorMutableListSource?
    private var detachedItems: [CameraBatch.Item] = []
    private var isSending = false
    private var sendAttempt = 0
    private var inFlightIds = Set<String>()
    private let sendInProgress = ValuePromise<Bool>(false, ignoreRepeated: true)
    private let sendDisposable = MetaDisposable()

    convenience init(context: AccountContext, parameters: ChatCameraFlowParameters, completion: @escaping ChatCameraFlowCompletion) {
        self.init(context: context, parameters: parameters, output: .messages(completion))
    }

    fileprivate init(context: AccountContext, parameters: ChatCameraFlowParameters, output: ChatCameraFlowOutput) {
        self.context = context
        self.parameters = parameters
        self.output = output

        let editingContext = TGMediaEditingContext()
        editingContext.sendPaidMessageStars = parameters.sendPaidMessageStars
        if parameters.initialCaption.length > 0 {
            editingContext.setForcedCaption(parameters.initialCaption)
        }
        self.session = ChatMediaEditorCaptureSession(selectionLimit: parameters.camera.isSingleShot ? 1 : parameters.camera.maxCount, allowsGrouping: parameters.mediaGrouping, editingContext: editingContext)
    }

    deinit {
        self.batchDisposable?.dispose()
        self.sendDisposable.dispose()
        let inFlight = self.inFlightIds
        chatCameraDeleteFiles(self.detachedItems.filter { !inFlight.contains($0.uniqueId) }.map { chatCameraItemPath($0) })
    }

    func attach(camera: CameraScreenImpl) {
        self.camera = camera
        camera.openChatReview = { [self] batch, focusItemId in
            self.openReview(batch: batch, focusItemId: focusItemId)
        }
        if let batch = camera.chatBatch {
            self.batchDisposable = batch.addListener { [weak self] in
                self?.syncBatch()
            }
        }
    }

    private var isPassport: Bool {
        if case .passportImages = self.output {
            return true
        }
        return false
    }

    private var hasCameraButton: Bool {
        return chatCameraReviewHasCameraButton(isEditingMessage: self.parameters.isEditingMessage, isSingleShot: self.parameters.camera.isSingleShot)
    }

    private func syncBatch() {
        guard !self.isSending, let batch = self.camera?.chatBatch else {
            return
        }
        let batchItems = batch.items
        let batchIds = Set(batchItems.map { $0.uniqueId })
        for item in self.session.items where !batchIds.contains(item.uniqueId) {
            self.session.remove(uniqueId: item.uniqueId)
        }
        for item in batchItems where !self.session.contains(uniqueId: item.uniqueId) {
            let captured = chatCameraCapturedItem(item)
            if self.parameters.camera.documentFrame == .idCard, case let .image(_, dimensions) = captured.content {
                let peerId = self.context.account.peerId
                self.session.store.update(captured.uniqueId) { entry in
                    entry.values = chatMediaEditorIdCardInitialValues(peerId: peerId, dimensions: dimensions)
                }
            }
            self.reviewSource?.append(captured.editorItem)
            self.session.add(captured)
        }
    }

    private func canPresentReview(camera: CameraScreenImpl) -> Bool {
        guard camera.view.window != nil, !camera.isPresentingChatDiscardSheet else {
            return false
        }
        if let navigationController = camera.navigationController as? NavigationController, navigationController.viewControllers.last !== camera {
            return false
        }
        return true
    }

    private func openReview(batch: CameraBatch, focusItemId: String?) {
        guard let camera = self.camera else {
            return
        }
        if self.review != nil {
            return
        }
        guard !self.isSending, self.canPresentReview(camera: camera) else {
            camera.returnFromChatReview()
            return
        }
        self.syncBatch()
        let items = self.session.items
        guard !items.isEmpty else {
            camera.returnFromChatReview()
            return
        }

        let source = ChatMediaEditorMutableListSource(items: items.map { $0.editorItem })
        self.reviewSource = source
        let initialIndex = focusItemId.flatMap { source.index(of: $0) } ?? (items.count - 1)
        let resolver = self.session.makeResolver()

        let context = self.context
        let parameters = self.parameters
        let peer = parameters.peer
        let isSavedMessages = peer?.id == context.account.peerId
        let hasSilentPosting = peer != nil && !isSavedMessages && !parameters.isEditingMessage

        var selection: ChatMediaEditorSelectionAdapter?
        if chatMediaGalleryUsesSelection(selectionLimit: Int(self.session.selectionContext.selectionLimit)) {
            selection = ChatMediaEditorLegacySelectionAdapter(selectionContext: self.session.selectionContext, resolver: resolver)
        }
        guard let editingContext = self.session.editingContext else {
            camera.returnFromChatReview()
            return
        }
        let captions = ChatMediaEditorLegacyCaptionAdapter(editingContext: editingContext, resolver: resolver)
        let timers = ChatMediaEditorLegacyTimerAdapter(editingContext: editingContext, resolver: resolver)

        var hasTimer = false
        if let peer, case .user = peer, !isSavedMessages {
            hasTimer = parameters.hasSchedule
        }
        let isPassport = self.isPassport

        let sendWhenOnlineAvailable: Signal<Bool, NoError>
        if let peer, case .user = peer, !(peer.id.namespace == Namespaces.Peer.CloudUser && peer.id.id._internalGetInt64Value() == 777000) {
            sendWhenOnlineAvailable = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Presence(id: peer.id))
            |> map { presence -> Bool in
                guard let presence, case let .present(until) = presence.status else {
                    return false
                }
                let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                return currentTime > until
            }
        } else {
            sendWhenOnlineAvailable = .single(false)
        }

        let gallery = ChatMediaEditorGalleryConfiguration(
            doneButton: chatMediaEditorGalleryDoneButton(isScheduledMessages: false, isActionButtonDone: isPassport),
            hasSendMenu: !isPassport && (hasSilentPosting || parameters.hasSchedule),
            hasTimer: hasTimer,
            timers: timers,
            presentTimerPicker: parameters.presentTimerPicker,
            sendWhenOnlineAvailable: sendWhenOnlineAvailable,
            sendInProgress: self.sendInProgress.get(),
            keepsDeselectedItems: true,
            immediateThumbnail: items[max(0, min(items.count - 1, initialIndex))].thumbnail,
            transitionHostView: {
                return nil
            },
            transitionView: { _ in
                return nil
            },
            updateHiddenMedia: { _ in
            },
            finishedTransitionIn: {
            },
            willTransitionOut: { [weak self] in
                self?.reviewWillClose()
            },
            send: { [weak self] uniqueId, silently, scheduleTime, completion in
                return self?.send(currentId: uniqueId, silently: silently, scheduleTime: scheduleTime, completion: completion) ?? false
            },
            dismissAll: { [weak self] in
                self?.dismissCameraAfterSend()
            },
            camera: ChatMediaEditorGalleryCamera(
                hasCameraButton: self.hasCameraButton,
                returnToCamera: {
                },
                discard: { [weak self] in
                    self?.discardAll()
                },
                bottomHandoff: { [weak camera] in
                    return camera?.makeChatReviewBottomHandoff().map { [weak camera] handoff in ChatMediaEditorCameraHandoff(bottomControls: mediaEditorBottomControlsHandoff(handoff), previewFrame: handoff.previewFrame, moveViewfinder: { frame, toEditor in
                        camera?.moveViewfinder(editorFrame: frame, toEditor: toEditor)
                    }) }
                },
                bottomHandBack: { [weak camera] in
                    return camera?.editorReturnTargets().map(mediaEditorBottomControlsHandBack)
                },
                returnPreviewFrame: { [weak camera] in
                    return camera?.editorReturnTargets()?.previewFrame
                },
                moveViewfinder: { [weak camera] frame, toEditor in
                    camera?.moveViewfinder(editorFrame: frame, toEditor: toEditor)
                }
            ),
            tabPolicy: isPassport ? .cropOnly : .standard
        )

        let getCaptionPanelView = parameters.getCaptionPanelView
        let review = ChatMediaEditorScreen(
            context: context,
            itemsSource: source,
            initialIndex: initialIndex,
            store: self.session.store,
            selection: selection,
            captions: captions,
            recipientName: peer.flatMap { chatMediaEditorRecipientName(context: context, peer: $0, threadTitle: parameters.threadTitle) },
            getCaptionPanelView: {
                return getCaptionPanelView()
            },
            hasSilentPosting: hasSilentPosting,
            hasSchedule: parameters.hasSchedule,
            reminder: isSavedMessages,
            presentSchedulePicker: parameters.presentSchedulePicker,
            gallery: gallery,
            completion: { _, _, _, _ in
            }
        )
        self.review = review
        camera.present(review, in: .window(.root))
    }

    private func reviewWillClose() {
        self.review = nil
        self.reviewSource = nil
        if !self.isSending {
            self.camera?.returnFromChatReview()
        }
    }

    private func discardAll() {
        guard let batch = self.camera?.chatBatch else {
            self.session.removeAll()
            return
        }
        for item in batch.items {
            batch.remove(id: item.uniqueId)
        }
        self.session.removeAll()
    }

    private func dismissCameraAfterSend() {
        self.camera?.requestChatDismiss(animated: true)
    }

    private func send(currentId: String, silently: Bool, scheduleTime: Int32?, completion: @escaping () -> Void) -> Bool {
        if case let .passportImages(output) = self.output {
            return self.sendPassportImages(currentId: currentId, output: output, completion: completion)
        }
        guard !self.isSending, let camera = self.camera, let editingContext = self.session.editingContext else {
            return false
        }
        let peerId = self.parameters.peer?.id ?? self.context.account.peerId
        let uniqueIds = self.session.sendUniqueIds(currentId: currentId)
        let items = uniqueIds.compactMap { self.session.sendItem(uniqueId: $0, peerId: peerId) }
        guard !items.isEmpty else {
            return false
        }
        let timers: [String: Int32] = Dictionary(uniqueKeysWithValues: uniqueIds.compactMap { uniqueId in
            return self.session.timer(uniqueId: uniqueId).flatMap { (uniqueId, $0) }
        })

        self.isSending = true
        self.sendInProgress.set(true)
        self.detachedItems.append(contentsOf: camera.chatBatch?.detachAll() ?? [])

        let isSecretChat = self.parameters.isSecretChat
        let saveEdited = chatMediaSendSavesEditedPhotos(saveEditedPhotos: self.parameters.camera.saveCapturedMedia, isSecretChat: isSecretChat, isPasteboard: false)
        let global = ChatMediaSendGlobalOptions(
            grouping: self.session.selectionContext.grouping,
            forcedCaption: self.parameters.initialCaption.length > 0 ? self.parameters.initialCaption : nil,
            forceHd: editingContext.isHighQualityPhoto(),
            saveEditedPhotosToCameraRoll: saveEdited
        )
        let sendParameters = ChatSendMessageActionSheetController.SendParameters(effect: nil, textIsAboveMedia: editingContext.isCaptionAbove())

        let context = self.context
        let receivedOutcome = Atomic<Bool>(value: false)
        self.sendDisposable.set((chatMediaSendMessages(context: context, items: items, global: global, renderer: ChatMediaSendDefaultRenderer(context: context))
        |> deliverOnMainQueue).startStrict(next: { [weak self] event in
            guard case let .outcome(outcome) = event else {
                return
            }
            let _ = receivedOutcome.swap(true)
            guard let self, self.isSending else {
                chatMediaSendDiscardCameraRollImages(outcome.cameraRollImagePaths)
                return
            }
            self.handleOutcome(outcome, sentIds: uniqueIds, timers: timers, silently: silently, scheduleTime: scheduleTime, parameters: sendParameters, completion: completion)
        }, completed: { [weak self] in
            guard let self, self.isSending, !receivedOutcome.with({ $0 }) else {
                return
            }
            self.restoreDetachedItems()
        }))
        return true
    }

    private func sendPassportImages(currentId: String, output: @escaping ([TelegramMediaResource]) -> Void, completion: @escaping () -> Void) -> Bool {
        guard !self.isSending, let camera = self.camera else {
            return false
        }
        let store = self.session.store
        let uniqueIds = self.session.sendUniqueIds(currentId: currentId)
        let items: [PassportImageItem] = uniqueIds.compactMap { uniqueId in
            guard let captured = self.session.item(uniqueId: uniqueId), case let .image(path, dimensions) = captured.content else {
                return nil
            }
            return PassportImageItem(uniqueId: uniqueId, source: .imageFile(path: path, dimensions: dimensions), values: mediaPickerChatMediaSendEditedValues(store: store, uniqueId: uniqueId))
        }
        guard !items.isEmpty else {
            return false
        }

        self.isSending = true
        self.sendInProgress.set(true)
        self.detachedItems.append(contentsOf: camera.chatBatch?.detachAll() ?? [])

        self.sendDisposable.set((passportRenderedResources(context: self.context, items: items)
        |> deliverOnMainQueue).startStrict(next: { [weak self] resources in
            guard let self, self.isSending else {
                return
            }
            if resources.isEmpty {
                self.restoreDetachedItems()
                return
            }
            let paths = self.detachedItems.map { chatCameraItemPath($0) }
            self.detachedItems.removeAll()
            self.session.removeAll()
            completion()
            self.dismissCameraAfterSend()
            output(resources)
            chatCameraDeleteFiles(paths)
        }))
        return true
    }

    private func restoreDetachedItems() {
        self.isSending = false
        self.sendInProgress.set(false)
        let inFlight = self.inFlightIds
        let items = self.detachedItems.filter { !inFlight.contains($0.uniqueId) }
        self.detachedItems.removeAll(where: { !inFlight.contains($0.uniqueId) })
        guard let batch = self.camera?.chatBatch, !batch.isClosed else {
            chatCameraDeleteFiles(items.map { chatCameraItemPath($0) })
            return
        }
        for item in items {
            batch.append(item)
        }
    }

    private func handleOutcome(_ outcome: ChatMediaSendOutcome, sentIds: [String], timers: [String: Int32], silently: Bool, scheduleTime: Int32?, parameters: ChatSendMessageActionSheetController.SendParameters, completion: @escaping () -> Void) {
        if outcome.droppedUniqueIds.isEmpty {
            self.commit(outcome, sentIds: sentIds, timers: timers, silently: silently, scheduleTime: scheduleTime, parameters: parameters, completion: completion)
            return
        }
        guard let review = self.review else {
            chatMediaSendDiscardCameraRollImages(outcome.cameraRollImagePaths)
            self.restoreDetachedItems()
            return
        }
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let strings = presentationData.strings
        let isEmpty = outcome.messages.isEmpty
        let text = isEmpty ? strings.Story_Editor_MediaUnavailable : strings.Story_Editor_MediaUnavailableSomeSkipped
        review.present(textAlertController(context: self.context, forceTheme: defaultDarkColorPresentationTheme, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strings.Common_OK, action: { [weak self] in
            guard let self else {
                chatMediaSendDiscardCameraRollImages(outcome.cameraRollImagePaths)
                return
            }
            if isEmpty {
                chatMediaSendDiscardCameraRollImages(outcome.cameraRollImagePaths)
                self.restoreDetachedItems()
            } else {
                self.commit(outcome, sentIds: sentIds, timers: timers, silently: silently, scheduleTime: scheduleTime, parameters: parameters, completion: completion)
            }
        })]), in: .window(.root))
    }

    private func commit(_ outcome: ChatMediaSendOutcome, sentIds: [String], timers: [String: Int32], silently: Bool, scheduleTime: Int32?, parameters: ChatSendMessageActionSheetController.SendParameters, completion: @escaping () -> Void) {
        let dropped = Set(outcome.droppedUniqueIds)
        let sent = Set(sentIds).subtracting(dropped)
        self.inFlightIds.formUnion(sent)

        self.sendAttempt += 1
        let attempt = self.sendAttempt
        let editedPaths = outcome.cameraRollImagePaths
        guard case let .messages(flowCompletion) = self.output else {
            return
        }
        flowCompletion(true, .single(outcome.messages), Int32(outcome.messages.count), silently, scheduleTime, parameters, { _ in
            return nil
        }, { [weak self] in
            if let self {
                self.finishSend(attempt: attempt, sent: sent, timers: timers, editedPaths: editedPaths)
            } else {
                chatMediaSendDiscardCameraRollImages(editedPaths)
            }
            completion()
        })
        Queue.mainQueue().after(1.5) { [weak self] in
            guard let self, self.isSending, self.sendAttempt == attempt else {
                return
            }
            self.inFlightIds.subtract(sent)
            chatMediaSendDiscardCameraRollImages(editedPaths)
            self.restoreDetachedItems()
        }
    }

    private func finishSend(attempt: Int, sent: Set<String>, timers: [String: Int32], editedPaths: [String]) {
        let editedPaths = editedPaths.filter { FileManager.default.fileExists(atPath: $0) }
        if self.sendAttempt == attempt {
            self.sendAttempt += 1
        }
        self.isSending = true
        var sentItems = self.detachedItems.filter { sent.contains($0.uniqueId) }
        self.detachedItems.removeAll(where: { sent.contains($0.uniqueId) })
        let found = Set(sentItems.map { $0.uniqueId })
        if let batch = self.camera?.chatBatch {
            for uniqueId in sent where !found.contains(uniqueId) {
                if let item = batch.detach(id: uniqueId) {
                    sentItems.append(item)
                }
            }
        }
        self.inFlightIds.subtract(sent)
        let inFlight = self.inFlightIds
        let leftovers = self.detachedItems.filter { !inFlight.contains($0.uniqueId) }
        self.detachedItems.removeAll(where: { !inFlight.contains($0.uniqueId) })
        chatCameraDeleteFiles(leftovers.map { chatCameraItemPath($0) })

        var sentPhotoPaths: [String] = []
        var originals: [ChatMediaSendCapturedOriginal] = []
        for item in sentItems {
            let savesOriginal = chatMediaSendSavesCapturedOriginal(saveCapturedMedia: self.parameters.camera.saveCapturedMedia, isSecretChat: self.parameters.isSecretChat, timer: timers[item.uniqueId])
            switch item.content {
            case let .image(path, _):
                sentPhotoPaths.append(path)
                if savesOriginal {
                    originals.append(.photo(URL(fileURLWithPath: path)))
                }
            case let .video(path, _, _, _, _):
                if savesOriginal {
                    originals.append(.video(URL(fileURLWithPath: path)))
                }
            }
            self.session.remove(uniqueId: item.uniqueId)
        }

        chatMediaSendPreparePhotoLibraryAccess(hasMediaToSave: !originals.isEmpty || !editedPaths.isEmpty, completion: {
            Queue.mainQueue().async {
                chatMediaSendSaveCapturedOriginals(originals, completion: {
                    Queue.mainQueue().async {
                        chatMediaSendSaveToCameraRoll(paths: editedPaths, completion: {
                            chatCameraDeleteFiles(sentPhotoPaths)
                        })
                    }
                })
            }
        })
    }
}
