import Foundation
import UIKit
import Display
import MediaEditor
import DrawingUI
import ChatPresentationInterfaceState
import PresentationDataUtils
import TelegramPresentationData

extension MediaEditorScreen {
    final class Recording {
        private weak var controller: MediaEditorScreen?
        
        private var recorder: EntityVideoRecorder?
        
        init(controller: MediaEditorScreen) {
            self.controller = controller
        }
        
        func setMediaRecordingActive(_ isActive: Bool, finished: Bool, sourceView: UIView?) {
            guard let controller, let mediaEditor = controller.node.mediaEditor else {
                return
            }
            let entitiesView = controller.node.entitiesView
            if mediaEditor.values.additionalVideoPath != nil {
                let presentationData = controller.context.sharedContext.currentPresentationData.with { $0 }
                let alertController = textAlertController(
                    context: controller.context,
                    forceTheme: defaultDarkColorPresentationTheme,
                    title: nil,
                    text: "Are you sure you want to delete video message?",
                    actions: [
                        TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                        }),
                        TextAlertAction(type: .destructiveAction, title: presentationData.strings.Common_Delete, action: { [weak mediaEditor, weak entitiesView] in
                            mediaEditor?.setAdditionalVideo(nil, positionChanges: [])
                            if let entityView = entitiesView?.getView(where: { entityView in
                                if let entity = entityView.entity as? DrawingStickerEntity, case .dualVideoReference = entity.content {
                                    return true
                                } else {
                                    return false
                                }
                            }) {
                                entitiesView?.remove(uuid: entityView.entity.uuid, animated: false)
                            }
                        })
                    ]
                )
                controller.present(alertController, in: .window(.root))
                return
            }
            
            if isActive {
                guard self.recorder == nil else {
                    return
                }
                HapticFeedback().impact(.light)
                
                let recorder = EntityVideoRecorder(mediaEditor: mediaEditor, entitiesView: controller.node.entitiesView)
                recorder.setup(
                    referenceDrawingSize: storyDimensions,
                    scale: 1.625,
                    position: PIPPosition.topRight.getPosition(storyDimensions)
                )
                recorder.onAutomaticStop = { [weak self] in
                    if let self {
                        self.recorder = nil
                        self.controller?.node.requestLayout(forceUpdate: true, transition: .easeInOut(duration: 0.2))
                    }
                }
                self.recorder = recorder
                controller.node.requestLayout(forceUpdate: true, transition: .easeInOut(duration: 0.2))
            } else {
                if let recorder = self.recorder {
                    recorder.stopRecording(save: finished, completion: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.recorder = nil
                        self.controller?.node.requestLayout(forceUpdate: true, transition: .easeInOut(duration: 0.2))
                    })
                    
                    controller.node.requestLayout(forceUpdate: true, transition: .easeInOut(duration: 0.2))
                } else {
                    guard self.tooltipController == nil, let sourceView else {
                        return
                    }
                    let rect = sourceView.convert(sourceView.bounds, to: nil)
                    let presentationData = controller.context.sharedContext.currentPresentationData.with { $0 }
                    let text = presentationData.strings.MediaEditor_HoldToRecordVideo
                    let tooltipController = TooltipController(content: .text(text), baseFontSize: presentationData.listsFontSize.baseDisplaySize, padding: 2.0)
                    tooltipController.dismissed = { [weak self] _ in
                        if let self {
                            self.tooltipController = nil
                        }
                    }
                    controller.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceViewAndRect: { [weak self] in
                        if let view = self?.controller?.view {
                            return (view, rect)
                        }
                        return nil
                    }))
                    self.tooltipController = tooltipController
                }
            }
        }
        private var tooltipController: TooltipController?
        
        func togglePosition() {
            if let recorder = self.recorder {
                recorder.togglePosition()
            }
        }
        
        var status: InstantVideoControllerRecordingStatus? {
            if let recorder = self.recorder {
                return InstantVideoControllerRecordingStatus(
                    micLevel: recorder.micLevel,
                    duration: recorder.duration
                )
            } else {
                return nil
            }
        }
    }
}
