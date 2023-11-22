import Foundation
import UIKit
import SwiftSignalKit
import Camera
import MediaEditor

public final class EntityVideoRecorder {
    private weak var mediaEditor: MediaEditor?
    private weak var entitiesView: DrawingEntitiesView?
    
    private let maxDuration: Double
    
    private let camera: Camera
    private let previewView: CameraSimplePreviewView
    private let entity: DrawingStickerEntity
    
    private var recordingDisposable = MetaDisposable()
    private let durationPromise = ValuePromise<Double>()
    private let micLevelPromise = Promise<Float>()
    
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
        
        self.maxDuration = mediaEditor.duration ?? 60.0
        self.previewView = CameraSimplePreviewView(frame: .zero, main: true)
        
        self.entity = DrawingStickerEntity(content: .dualVideoReference)
        
        self.camera = Camera(
            configuration: Camera.Configuration(
                preset: .hd1920x1080,
                position: .front,
                isDualEnabled: false,
                audio: true,
                photo: false,
                metadata: false,
                preferredFps: 60.0,
                preferWide: true
            ),
            previewView: self.previewView,
            secondaryPreviewView: nil
        )
        self.camera.startCapture()
        
        let action = { [weak self] in
            self?.previewView.removePlaceholder(delay: 0.15)
            Queue.mainQueue().after(0.1) {
                self?.startRecording()
                self?.mediaEditor?.play()
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
        
        self.micLevelPromise.set(.single(0.0))
        
        self.mediaEditor?.stop()
        self.mediaEditor?.seek(0.0, andPlay: false)
    }
    
    deinit {
        self.recordingDisposable.dispose()
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
        }
    }

    var start: Double = 0.0
    private func startRecording() {
        self.start = CACurrentMediaTime()
        self.recordingDisposable.set((self.camera.startRecording()
        |> deliverOnMainQueue).startStrict(next: { [weak self] duration in
            guard let self else {
                return
            }
            self.durationPromise.set(duration)
            if duration >= self.maxDuration {
                let onAutomaticStop = self.onAutomaticStop
                self.stopRecording(save: true, completion: {
                    onAutomaticStop()
                })
            }
        }))
    }
    
    public func stopRecording(save: Bool, completion: @escaping () -> Void = {}) {
        var save = save
        var remove = false
        let duration = CACurrentMediaTime() - self.start
        if duration < 0.2 {
            save = false
            remove = true
        }
        self.recordingDisposable.set((self.camera.stopRecording()
        |> deliverOnMainQueue).startStrict(next: { [weak self] result in
            guard let self, let mediaEditor = self.mediaEditor, let entitiesView = self.entitiesView, case let .finished(mainResult, _, duration, _, _) = result else {
                return
            }
            if save {
                mediaEditor.setAdditionalVideo(mainResult.path, positionChanges: [])
                mediaEditor.setAdditionalVideoTrimRange(0..<duration, apply: true)
                mediaEditor.seek(0.0, andPlay: true)
                if let entityView = entitiesView.getView(for: self.entity.uuid) as? DrawingStickerEntityView {
                    entityView.invalidateCameraPreviewView()
                    
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
            } else {
                self.entitiesView?.remove(uuid: self.entity.uuid, animated: true)
                if remove {
                    mediaEditor.setAdditionalVideo(nil, positionChanges: [])
                }
            }
            self.camera.stopCapture(invalidate: true)
            
            completion()
        }))
    }
    
    public func togglePosition() {
        self.camera.togglePosition()
    }
}
