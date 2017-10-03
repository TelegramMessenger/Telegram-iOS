import Foundation
import Display
import TelegramCore
import Postbox
import SwiftSignalKit

import LegacyComponents

final class InstantVideoControllerRecordingStatus {
    let micLevel: Signal<Float, NoError>
    
    init(micLevel: Signal<Float, NoError>) {
        self.micLevel = micLevel
    }
}

final class InstantVideoController: LegacyController {
    private var captureController: TGVideoMessageCaptureController?
    
    var onDismiss: (() -> Void)?
    
    private let micLevelValue = ValuePromise<Float>(0.0)
    let audioStatus: InstantVideoControllerRecordingStatus
    
    private var dismissedVideo = false
    
    override init(presentation: LegacyControllerPresentation) {
        self.audioStatus = InstantVideoControllerRecordingStatus(micLevel: self.micLevelValue.get())
        
        super.init(presentation: presentation)
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
                if let strongSelf = self {
                    strongSelf.onDismiss?()
                }
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

func legacyInstantVideoController(theme: PresentationTheme, panelFrame: CGRect, account: Account, peerId: PeerId) -> InstantVideoController {
    let legacyController = InstantVideoController(presentation: .custom)
    legacyController.statusBar.statusBarStyle = .Hide
    let baseController = TGViewController(context: legacyController.context)!
    legacyController.bind(controller: baseController)
    legacyController.presentationCompleted = { [weak legacyController, weak baseController] in
        if let legacyController = legacyController, let baseController = baseController {
            let controllerTheme = TGVideoMessageCaptureControllerTheme(darkBackground: theme.rootController.statusBar.style.style == .White, panelSeparatorColor: theme.chat.inputPanel.panelStrokeColor, panelTime: theme.chat.inputPanel.primaryTextColor, panelDotColor: theme.chat.inputPanel.mediaRecordingDotColor, panelAccentColor: theme.chat.inputPanel.panelControlAccentColor)
            let controller = TGVideoMessageCaptureController(context: legacyController.context, assets: TGVideoMessageCaptureControllerAssets(send: PresentationResourcesChat.chatInputPanelSendButtonImage(theme)!, slideToCancel:PresentationResourcesChat.chatInputPanelMediaRecordingCancelArrowImage(theme)!, actionDelete: generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Acessory Panels/MessageSelectionThrash"), color: theme.chat.inputPanel.panelControlAccentColor), theme: controllerTheme)!, transitionInView: {
                return nil
            }, parentController: baseController, controlsFrame: panelFrame, isAlreadyLocked: {
                return false
            }, liveUploadInterface: nil)!
            /*controller.finishedWithVideo = ^(NSURL *videoURL, UIImage *previewImage, __unused NSUInteger fileSize, NSTimeInterval duration, CGSize dimensions, TGLiveUploadActorData *liveUploadData, TGVideoEditAdjustments *adjustments)
            {
                __strong TGModernConversationController *strongSelf = weakSelf;
                if (strongSelf != nil)
                {
                    NSDictionary *desc = [strongSelf->_companion videoDescriptionFromVideoURL:videoURL previewImage:previewImage dimensions:dimensions duration:duration adjustments:adjustments stickers:nil caption:nil roundMessage:true liveUploadData:liveUploadData timer:0];
                    [strongSelf->_companion controllerWantsToSendImagesWithDescriptions:@[ desc ] asReplyToMessageId:[strongSelf currentReplyMessageId] botReplyMarkup:nil];
                }
            }*/
            controller.finishedWithVideo = { videoUrl, previewImage, _, duration, dimensions, liveUploadData, adjustments in
                guard let videoUrl = videoUrl else {
                    return
                }
                
                var finalDimensions: CGSize = dimensions
                var finalDuration: Double = duration
                
                var previewRepresentations: [TelegramMediaImageRepresentation] = []
                if let previewImage = previewImage {
                    let resource = LocalFileMediaResource(fileId: arc4random64())
                    let thumbnailSize = finalDimensions.aspectFitted(CGSize(width: 90.0, height: 90.0))
                    let thumbnailImage = TGScaleImageToPixelSize(previewImage, thumbnailSize)!
                    if let thumbnailData = UIImageJPEGRepresentation(thumbnailImage, 0.4) {
                        account.postbox.mediaBox.storeResourceData(resource.id, data: thumbnailData)
                        previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: thumbnailSize, resource: resource))
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
                
                let resource = LocalFileVideoMediaResource(randomId: arc4random64(), path: videoUrl.path, adjustments: resourceAdjustments)
                
                let media = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: arc4random64()), resource: resource, previewRepresentations: previewRepresentations, mimeType: "video/mp4", size: nil, attributes: [.FileName(fileName: "video.mp4"), .Video(duration: Int(finalDuration), size: finalDimensions, flags: [.instantRoundVideo])])
                var attributes: [MessageAttribute] = []
                /*if let timer = item.timer, timer > 0 && timer <= 60 {
                    attributes.append(AutoremoveTimeoutMessageAttribute(timeout: Int32(timer), countdownBeginTime: nil))
                }*/
                let _ = enqueueMessages(account: account, peerId: peerId, messages: [.message(text: "", attributes: attributes, media: media, replyToMessageId: nil)]).start()
            }
            controller.didDismiss = { [weak legacyController] in
                if let legacyController = legacyController {
                    legacyController.dismiss()
                }
            }
            legacyController.bindCaptureController(controller)
        }
    }
    return legacyController
}
