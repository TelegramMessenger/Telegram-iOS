import Foundation
import UIKit
import SwiftSignalKit
import Camera
import MediaEditor
import AVFoundation

public final class EntityVideoRecorder {
    private weak var mediaEditor: MediaEditor?
    private weak var entitiesView: DrawingEntitiesView?
    
    private let maxDuration: Double
    
    private let camera: Camera
    private let previewView: CameraSimplePreviewView
    private let entity: DrawingStickerEntity
    private weak var entityView: DrawingStickerEntityView?
    
    private var recordingDisposable = MetaDisposable()
    private let durationPromise = ValuePromise<Double>()
    private let micLevelPromise = Promise<Float>()
    
    private var changingPositionDisposable: Disposable?
    
    public var duration: Signal<Double, NoError> {
        return self.durationPromise.get()
    }
    
    public var micLevel: Signal<Float, NoError> {
        return self.micLevelPromise.get()
    }
    
    public var onAutomaticStop: () -> Void = {}
    
    public init(mediaEditor: MediaEditor, entitiesView: DrawingEntitiesView) {
        self.mediaEditor = mediaEditor
        self.entitiesView = entitiesView
        
        self.maxDuration = min(60.0, mediaEditor.duration ?? 60.0)
        self.previewView = CameraSimplePreviewView(frame: .zero, main: true)
        
        self.entity = DrawingStickerEntity(content: .dualVideoReference(true))
        
        var preferLowerFramerate = false
        if let mainFramerate = mediaEditor.mainFramerate {
            let frameRate = Int(round(mainFramerate / 30.0) * 30.0)
            if frameRate == 30 {
                preferLowerFramerate = true
            }
        }
        
        self.camera = Camera(
            configuration: Camera.Configuration(
                preset: .hd1920x1080,
                position: .front,
                isDualEnabled: false,
                audio: true,
                photo: false,
                metadata: false,
                preferWide: true,
                preferLowerFramerate: preferLowerFramerate,
                reportAudioLevel: true
            ),
            previewView: self.previewView,
            secondaryPreviewView: nil
        )
        self.camera.startCapture()
        
        let action = { [weak self] in
            self?.previewView.removePlaceholder(delay: 0.15)
            Queue.mainQueue().after(0.1) {
                self?.startRecording()
            }
        }
        if #available(iOS 13.0, *) {
            let _ = (self.previewView.isPreviewing
            |> filter { $0 }
            |> take(1)
            |> deliverOnMainQueue).startStandalone(next: { _ in
                action()
            })
        } else {
            Queue.mainQueue().after(0.35) {
                action()
            }
        }
        
        self.micLevelPromise.set(camera.audioLevel)
        
        let start = mediaEditor.values.videoTrimRange?.lowerBound ?? 0.0
        mediaEditor.stop()
        mediaEditor.seek(start, andPlay: false)
        
        self.changingPositionDisposable = (camera.modeChange
        |> deliverOnMainQueue).start(next: { [weak self] modeChange in
            guard let self else {
                return
            }
            if case .position = modeChange {
                self.entityView?.beginCameraSwitch()
            } else {
                self.entityView?.commitCameraSwitch()
            }
        })
    }
    
    deinit {
        self.recordingDisposable.dispose()
        self.changingPositionDisposable?.dispose()
    }
    
    public func setup(
        referenceDrawingSize: CGSize,
        scale: CGFloat,
        position: CGPoint
    ) {
        self.entity.referenceDrawingSize = referenceDrawingSize
        self.entity.scale = scale
        self.entity.position = position
        self.entitiesView?.add(self.entity)
        
        if let entityView = self.entitiesView?.getView(for: self.entity.uuid) as? DrawingStickerEntityView {
            let maxDuration = self.maxDuration
            entityView.setupCameraPreviewView(
                self.previewView,
                progress: self.durationPromise.get() |> map {
                    Float(max(0.0, min(1.0, $0 / maxDuration)))
                }
            )
            self.previewView.resetPlaceholder(front: true)
            entityView.animateInsertion()
            
            self.entityView = entityView
        }
        
        self.entitiesView?.selectEntity(nil)
    }

    var start: Double = 0.0
    private func startRecording() {
        guard let mediaEditor = self.mediaEditor else {
            self.onAutomaticStop()
            return
        }
        mediaEditor.maybeMuteVideo()
        mediaEditor.play()
        
        self.start = CACurrentMediaTime()
        self.recordingDisposable.set((self.camera.startRecording()
        |> deliverOnMainQueue).startStrict(next: { [weak self] recordingData in
            guard let self else {
                return
            }
            self.durationPromise.set(recordingData.duration)
            if recordingData.duration >= self.maxDuration {
                let onAutomaticStop = self.onAutomaticStop
                self.stopRecording(save: true, completion: {
                    onAutomaticStop()
                })
            }
        }))
    }
    
    public func stopRecording(save: Bool, completion: @escaping () -> Void = {}) {
        var save = save
        let duration = CACurrentMediaTime() - self.start
        if duration < 0.2 {
            save = false
        }
        self.recordingDisposable.set((self.camera.stopRecording()
        |> deliverOnMainQueue).startStrict(next: { [weak self] result in
            guard let self, let mediaEditor = self.mediaEditor, let entitiesView = self.entitiesView, case let .finished(mainResult, _, _, _, _) = result else {
                return
            }
            if save {
                let duration = AVURLAsset(url: URL(fileURLWithPath: mainResult.path)).duration
                
                let start = mediaEditor.values.videoTrimRange?.lowerBound ?? 0.0
                mediaEditor.setAdditionalVideoOffset(-start, apply: false)
                mediaEditor.setAdditionalVideoTrimRange(0 ..< duration.seconds, apply: true)
                mediaEditor.setAdditionalVideo(mainResult.path, positionChanges: [])
                
                mediaEditor.stop()
                Queue.mainQueue().justDispatch {
                    mediaEditor.seek(start, andPlay: true)
                }
                
                if let entityView = entitiesView.getView(for: self.entity.uuid) as? DrawingStickerEntityView {
                    entityView.snapshotCameraPreviewView()
                    
                    mediaEditor.setOnNextAdditionalDisplay { [weak entityView] in
                        Queue.mainQueue().async {
                            entityView?.invalidateCameraPreviewView()
                        }
                    }
                 
                    let entity = self.entity
                    let update = { [weak mediaEditor, weak entity] in
                        if let mediaEditor, let entity {
                            mediaEditor.setAdditionalVideoPosition(entity.position, scale: entity.scale, rotation: entity.rotation)
                        }
                    }
                    entityView.updated = {
                        update()
                    }
                    update()
                }
                
                self.camera.stopCapture(invalidate: true)
                self.mediaEditor?.maybeUnmuteVideo()
                completion()
            }
        }))
        
        if !save {
            self.camera.stopCapture(invalidate: true)
            self.mediaEditor?.maybeUnmuteVideo()
            
            self.entitiesView?.remove(uuid: self.entity.uuid, animated: true)
            self.mediaEditor?.setAdditionalVideo(nil, positionChanges: [])
            
            completion()
        }
    }
    
    public func togglePosition() {
        self.camera.togglePosition()
    }
}
