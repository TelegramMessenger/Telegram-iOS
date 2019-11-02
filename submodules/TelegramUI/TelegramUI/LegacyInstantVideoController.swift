import Foundation
import UIKit
import Display
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import MediaResources
import LegacyComponents
import AccountContext
import LegacyUI
import ImageCompression
import LocalMediaResources
import AppBundle

final class InstantVideoControllerRecordingStatus {
    let micLevel: Signal<Float, NoError>
    
    init(micLevel: Signal<Float, NoError>) {
        self.micLevel = micLevel
    }
}

final class InstantVideoController: LegacyController, StandalonePresentableController {
    private var captureController: TGVideoMessageCaptureController?
    
    var onDismiss: (() -> Void)?
    var onStop: (() -> Void)?
    
    private let micLevelValue = ValuePromise<Float>(0.0)
    let audioStatus: InstantVideoControllerRecordingStatus
    
    private var dismissedVideo = false
    
    override init(presentation: LegacyControllerPresentation, theme: PresentationTheme?, strings: PresentationStrings? = nil, initialLayout: ContainerViewLayout? = nil) {
        self.audioStatus = InstantVideoControllerRecordingStatus(micLevel: self.micLevelValue.get())
        
        super.init(presentation: presentation, theme: theme, initialLayout: initialLayout)
        
        self.lockOrientation = true
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func bindCaptureController(_ captureController: TGVideoMessageCaptureController?) {
        self.captureController = captureController
        if let captureController = captureController {
            captureController.micLevel = { [weak self] (level: CGFloat) -> Void in
                self?.micLevelValue.set(Float(level))
            }
            captureController.onDismiss = { [weak self] _ in
                self?.onDismiss?()
            }
            captureController.onStop = { [weak self] in
                self?.onStop?()
            }
        }
    }
    
    func dismissVideo() {
        if let captureController = self.captureController, !self.dismissedVideo {
            self.dismissedVideo = true
            captureController.dismiss()
        }
    }
    
    func completeVideo() {
        if let captureController = self.captureController, !self.dismissedVideo {
            self.dismissedVideo = true
            captureController.complete()
        }
    }
    
    func stopVideo() -> Bool {
        if let captureController = self.captureController {
            return captureController.stop()
        }
        return false
    }
    
    func lockVideo() {
        if let captureController = self.captureController {
            return captureController.setLocked()
        }
    }
    
    func updateRecordButtonInteraction(_ value: CGFloat) {
        if let captureController = self.captureController {
            captureController.buttonInteractionUpdate(CGPoint(x: value, y: 0.0))
        }
    }
}

func legacyInputMicPalette(from theme: PresentationTheme) -> TGModernConversationInputMicPallete {
    let inputPanelTheme = theme.chat.inputPanel
    return TGModernConversationInputMicPallete(dark: theme.overallDarkAppearance, buttonColor: inputPanelTheme.actionControlFillColor, iconColor: inputPanelTheme.actionControlForegroundColor, backgroundColor: inputPanelTheme.panelBackgroundColor, borderColor: inputPanelTheme.panelSeparatorColor, lock: inputPanelTheme.panelControlAccentColor, textColor: inputPanelTheme.primaryTextColor, secondaryTextColor: inputPanelTheme.secondaryTextColor, recording: inputPanelTheme.mediaRecordingDotColor)
}

func legacyInstantVideoController(theme: PresentationTheme, panelFrame: CGRect, context: AccountContext, peerId: PeerId, slowmodeState: ChatSlowmodeState?, send: @escaping (EnqueueMessage) -> Void, displaySlowmodeTooltip: @escaping (ASDisplayNode, CGRect) -> Void) -> InstantVideoController {
    let legacyController = InstantVideoController(presentation: .custom, theme: theme)
    legacyController.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .all)
    legacyController.lockOrientation = true
    legacyController.statusBar.statusBarStyle = .Hide
    let baseController = TGViewController(context: legacyController.context)!
    legacyController.bind(controller: baseController)
    legacyController.presentationCompleted = { [weak legacyController, weak baseController] in
        if let legacyController = legacyController, let baseController = baseController {
            legacyController.view.disablesInteractiveTransitionGestureRecognizer = true
            var uploadInterface: LegacyLiveUploadInterface?
            if peerId.namespace != Namespaces.Peer.SecretChat {
                uploadInterface = LegacyLiveUploadInterface(account: context.account)
            }
            
            var slowmodeValidUntil: Int32 = 0
            if let slowmodeState = slowmodeState, case let .timestamp(timestamp) = slowmodeState.variant {
                slowmodeValidUntil = timestamp
            }
            
            let controller = TGVideoMessageCaptureController(context: legacyController.context, assets: TGVideoMessageCaptureControllerAssets(send: PresentationResourcesChat.chatInputPanelSendButtonImage(theme)!, slideToCancel: PresentationResourcesChat.chatInputPanelMediaRecordingCancelArrowImage(theme)!, actionDelete: generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionTrash"), color: theme.chat.inputPanel.panelControlAccentColor))!, transitionInView: {
                return nil
            }, parentController: baseController, controlsFrame: panelFrame, isAlreadyLocked: {
                return false
            }, liveUploadInterface: uploadInterface, pallete: legacyInputMicPalette(from: theme), slowmodeTimestamp: slowmodeValidUntil, slowmodeView: {
                let node = ChatSendButtonRadialStatusView(color: theme.chat.inputPanel.panelControlAccentColor)
                node.slowmodeState = slowmodeState
                return node
            })!
            controller.finishedWithVideo = { videoUrl, previewImage, _, duration, dimensions, liveUploadData, adjustments in
                guard let videoUrl = videoUrl else {
                    return
                }
                
                var finalDimensions: CGSize = dimensions
                var finalDuration: Double = duration
                
                var previewRepresentations: [TelegramMediaImageRepresentation] = []
                if let previewImage = previewImage {
                    let resource = LocalFileMediaResource(fileId: arc4random64())
                    let thumbnailSize = finalDimensions.aspectFitted(CGSize(width: 320.0, height: 320.0))
                    let thumbnailImage = TGScaleImageToPixelSize(previewImage, thumbnailSize)!
                    if let thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.4) {
                        context.account.postbox.mediaBox.storeResourceData(resource.id, data: thumbnailData)
                        previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(thumbnailSize), resource: resource))
                    }
                }
                
                finalDimensions = TGMediaVideoConverter.dimensions(for: finalDimensions, adjustments: adjustments, preset: TGMediaVideoConversionPresetVideoMessage)
                
                var resourceAdjustments: VideoMediaResourceAdjustments?
                if let adjustments = adjustments {
                    if adjustments.trimApplied() {
                        finalDuration = adjustments.trimEndValue - adjustments.trimStartValue
                    }
                    
                    let adjustmentsData = MemoryBuffer(data: NSKeyedArchiver.archivedData(withRootObject: adjustments.dictionary()))
                    let digest = MemoryBuffer(data: adjustmentsData.md5Digest())
                    resourceAdjustments = VideoMediaResourceAdjustments(data: adjustmentsData, digest: digest)
                }
                
                if finalDuration.isZero || finalDuration.isNaN {
                    return
                }
                
                let resource: TelegramMediaResource
                if let liveUploadData = liveUploadData as? LegacyLiveUploadInterfaceResult, resourceAdjustments == nil, let data = try? Data(contentsOf: videoUrl) {
                    resource = LocalFileMediaResource(fileId: liveUploadData.id)
                    context.account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                } else {
                    resource = LocalFileVideoMediaResource(randomId: arc4random64(), path: videoUrl.path, adjustments: resourceAdjustments)
                }
                
                if let previewImage = previewImage {
                    if let data = compressImageToJPEG(previewImage, quality: 0.7) {
                    context.account.postbox.mediaBox.storeCachedResourceRepresentation(resource, representation: CachedVideoFirstFrameRepresentation(), data: data)
                    }
                }
                
                let media = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: arc4random64()), partialReference: nil, resource: resource, previewRepresentations: previewRepresentations, immediateThumbnailData: nil, mimeType: "video/mp4", size: nil, attributes: [.FileName(fileName: "video.mp4"), .Video(duration: Int(finalDuration), size: PixelDimensions(finalDimensions), flags: [.instantRoundVideo])])
                let attributes: [MessageAttribute] = []
                send(.message(text: "", attributes: attributes, mediaReference: .standalone(media: media), replyToMessageId: nil, localGroupingKey: nil))
            }
            controller.didDismiss = { [weak legacyController] in
                if let legacyController = legacyController {
                    legacyController.dismiss()
                }
            }
            controller.displaySlowmodeTooltip = { [weak legacyController, weak controller] in
                if let legacyController = legacyController, let controller = controller {
                    let rect = controller.frameForSendButton()
                    displaySlowmodeTooltip(legacyController.displayNode, rect)
                }
            }
            legacyController.bindCaptureController(controller)
            
            let presentationDisposable = context.sharedContext.presentationData.start(next: { [weak controller] presentationData in
                if let controller = controller {
                    controller.pallete = legacyInputMicPalette(from: presentationData.theme)
                }
            })
            legacyController.disposables.add(presentationDisposable)
        }
    }
    return legacyController
}
