import Foundation
import UIKit
import Display
import SwiftSignalKit
import MediaEditor
import DrawingUI
import ChatPresentationInterfaceState
import PresentationDataUtils
import TelegramPresentationData
import DeviceAccess
import AccountContext

extension MediaEditorScreen {
    final class Recording {
        private weak var controller: MediaEditorScreen?
        
        private var recorder: EntityVideoRecorder?
        
        private let idleTimerExtensionDisposable = MetaDisposable()
        
        private var authorizationStatusDisposables = DisposableSet()
        private var cameraAuthorizationStatus: AccessType = .notDetermined
        private var microphoneAuthorizationStatus: AccessType = .notDetermined
        
        fileprivate var cameraIsActive = true {
            didSet {
                guard let context = self.controller?.context else {
                    return
                }
                if self.cameraIsActive {
                    self.idleTimerExtensionDisposable.set(context.sharedContext.applicationBindings.pushIdleTimerExtension())
                } else {
                    self.idleTimerExtensionDisposable.set(nil)
                }
            }
        }
        
        var isLocked = false
        
        init(controller: MediaEditorScreen) {
            self.controller = controller
            
            self.authorizationStatusDisposables.add((DeviceAccess.authorizationStatus(subject: .camera(.video))
            |> deliverOnMainQueue).start(next: { [weak self] status in
                if let self {
                    self.cameraAuthorizationStatus = status
                }
            }))
            
            self.authorizationStatusDisposables.add((DeviceAccess.authorizationStatus(subject: .microphone(.video))
            |> deliverOnMainQueue).start(next: { [weak self] status in
                if let self {
                    self.microphoneAuthorizationStatus = status
                }
            }))
        }
        
        deinit {
            self.idleTimerExtensionDisposable.dispose()
            self.authorizationStatusDisposables.dispose()
        }
        
        func requestDeviceAccess() {
            DeviceAccess.authorizeAccess(to: .camera(.video), { granted in
                if granted {
                    DeviceAccess.authorizeAccess(to: .microphone(.video))
                }
            })
        }
        
        func setMediaRecordingActive(_ isActive: Bool, finished: Bool, sourceView: UIView?) {
            guard let controller, let mediaEditor = controller.node.mediaEditor else {
                return
            }
            if mediaEditor.values.additionalVideoPath != nil {
                controller.node.presentVideoRemoveConfirmation()
                return
            }
            
            if isActive {
                if self.cameraAuthorizationStatus != .allowed || self.microphoneAuthorizationStatus != .allowed {
                    self.requestDeviceAccess()
                    return
                }
                
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
                
                self.cameraIsActive = true
            } else {
                if let recorder = self.recorder {
                    recorder.stopRecording(save: finished, completion: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.recorder = nil
                        self.isLocked = false
                        self.controller?.node.requestLayout(forceUpdate: true, transition: .easeInOut(duration: 0.2))
                    })
                    
                    controller.node.requestLayout(forceUpdate: true, transition: .easeInOut(duration: 0.2))
                    
                    self.cameraIsActive = false
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
        
        var isActive: Bool {
            return self.status != nil
        }
    }
}
