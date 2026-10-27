import Foundation
import UIKit
import Display
import MediaEditor
import DrawingUI

extension ChatMediaEditorScreen.Node: UIGestureRecognizerDelegate {
    func setupPaintGestures() {
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handleEntityPan(_:)))
        panGestureRecognizer.delegate = self
        panGestureRecognizer.minimumNumberOfTouches = 1
        panGestureRecognizer.maximumNumberOfTouches = 2
        self.previewContainerView.addGestureRecognizer(panGestureRecognizer)

        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(self.handleEntityPinch(_:)))
        pinchGestureRecognizer.delegate = self
        self.previewContainerView.addGestureRecognizer(pinchGestureRecognizer)

        let rotationGestureRecognizer = UIRotationGestureRecognizer(target: self, action: #selector(self.handleEntityRotate(_:)))
        rotationGestureRecognizer.delegate = self
        self.previewContainerView.addGestureRecognizer(rotationGestureRecognizer)

        self.entityGestureRecognizers = [panGestureRecognizer, pinchGestureRecognizer, rotationGestureRecognizer]
        self.updateEntityInteraction()
    }

    func setupEntitiesViewHooks() {
        let canvasSize = self.canvasSize
        self.entitiesView.getEntityCenterPosition = { [weak self] in
            guard let self else {
                return CGPoint(x: canvasSize.width / 2.0, y: canvasSize.height / 2.0)
            }
            let bounds = self.previewContainerView.bounds
            return self.previewContainerView.convert(CGPoint(x: bounds.midX, y: bounds.midY), to: self.entitiesView)
        }
        self.entitiesView.getEntityInitialRotation = { [weak self] in
            guard let self else {
                return 0.0
            }
            return chatMediaEditorPaintEntityInitialRotation(state: chatMediaEditorCropState(values: self.mediaEditor.values))
        }
        self.entitiesView.getEntityAdditionalScale = { [weak self] in
            guard let self else {
                return 1.0
            }
            return chatMediaEditorPaintEntityAdditionalScale(state: chatMediaEditorCropState(values: self.mediaEditor.values))
        }
        self.entitiesView.newEntityPrepared = { [weak self] entity in
            guard let self, self.activeTool == .paint else {
                return
            }
            chatMediaEditorScaleNewPaintEntity(entity, additionalScale: chatMediaEditorPaintEntityAdditionalScale(state: chatMediaEditorCropState(values: self.mediaEditor.values)))
        }
    }

    func updateEntityInteraction() {
        let isPainting = self.activeTool == .paint
        self.entitiesContainerView.isUserInteractionEnabled = isPainting
        for gestureRecognizer in self.entityGestureRecognizers {
            gestureRecognizer.isEnabled = isPainting
        }
    }

    @objc private func handleEntityPan(_ gestureRecognizer: UIPanGestureRecognizer) {
        self.entitiesView.handlePan(gestureRecognizer)
    }

    @objc private func handleEntityPinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
        self.entitiesView.handlePinch(gestureRecognizer)
    }

    @objc private func handleEntityRotate(_ gestureRecognizer: UIRotationGestureRecognizer) {
        self.entitiesView.handleRotate(gestureRecognizer)
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard self.entityGestureRecognizers.contains(where: { $0 === gestureRecognizer }) else {
            return true
        }
        if gestureRecognizer is UIPinchGestureRecognizer && !self.entitiesView.hasSelection {
            return false
        }
        if self.entitiesView.isEditingText {
            return false
        }
        return !self.drawingView.isTracking
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    var hasPaintChanges: Bool {
        let values = self.mediaEditor.values
        return values.drawing != nil || !values.entities.isEmpty
    }

    func openPaint() {
        guard self.activeTool == nil, let layout = self.validLayout else {
            return
        }

        self.previousDrawingData = self.drawingView.drawingData
        self.previousDrawingEntities = self.entitiesView.entities
        self.toolStartValues = self.mediaEditor.values

        self.activeTool = .paint
        self.paintMode = .draw
        self.paintControlsVisible = true
        self.updateEntityInteraction()
        self.drawingView.isUserInteractionEnabled = true
        self.requestLayout(transition: .animated(duration: 0.3, curve: .spring))

        let previewFrame = self.previewFrame(layout: layout)
        let canvasSize = self.canvasSize
        let mediaEditor = self.mediaEditor
        let drawingScreen = DrawingScreen(
            context: self.context,
            sourceHint: .chatMediaEditor,
            externalControls: true,
            size: previewFrame.size,
            originalSize: canvasSize,
            isVideo: self.subject.isVideo,
            isAvatar: false,
            drawingView: self.drawingView,
            entitiesView: self.entitiesView,
            selectionContainerView: self.selectionContainerView
        )
        drawingScreen.getCurrentImage = {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let context = DrawingContext(size: canvasSize, scale: 1.0, opaque: true, colorSpace: colorSpace) else {
                return nil
            }
            context.withFlippedContext { context in
                if let image = mediaEditor.resultImage?.cgImage {
                    context.draw(image, in: CGRect(origin: .zero, size: canvasSize))
                }
            }
            return context.generateImage(colorSpace: colorSpace)
        }
        drawingScreen.updateVideoPlayback = { play in
            if play {
                mediaEditor.play()
            } else {
                mediaEditor.stop()
            }
        }
        drawingScreen.externalControlsStateUpdated = { [weak self] state in
            guard let self, self.activeTool == .paint else {
                return
            }
            let mode: ChatMediaEditorPaintTab
            switch state.mode {
            case .drawing:
                mode = .draw
            case .sticker:
                mode = .sticker
            case .text:
                mode = .text
            }
            if self.paintMode != mode || self.paintControlsVisible != state.controlsAreVisible {
                self.paintMode = mode
                self.paintControlsVisible = state.controlsAreVisible
                self.requestLayout(transition: .animated(duration: 0.2, curve: .easeInOut))
            }
        }
        drawingScreen.requestDismiss = { [weak self, weak drawingScreen] in
            guard let self, let drawingScreen else {
                return
            }
            self.dismissEmbeddedToolController(drawingScreen, animateOut: { completion in
                drawingScreen.animateOut(completion)
            })
            self.drawingView.setup(withDrawing: self.previousDrawingData)
            self.entitiesView.setup(with: self.previousDrawingEntities ?? [])
            self.closePaint()
        }
        drawingScreen.requestApply = { [weak self, weak drawingScreen] in
            guard let self else {
                return
            }
            if let result = drawingScreen?.generateDrawingResultData() {
                self.mediaEditor.setDrawingAndEntities(data: result.data, image: result.drawingImage, entities: result.entities)
            } else {
                self.mediaEditor.setDrawingAndEntities(data: nil, image: nil, entities: [])
            }
            self.selectionEditCommitted()
            if let drawingScreen {
                self.dismissEmbeddedToolController(drawingScreen, animateOut: { completion in
                    drawingScreen.animateOut(completion)
                })
            }
            self.closePaint()
        }
        self.drawingScreen = drawingScreen
        self.embedToolController(drawingScreen)
    }

    func selectPaintMode(_ tab: ChatMediaEditorPaintTab) {
        guard self.activeTool == .paint, let drawingScreen = self.drawingScreen else {
            return
        }
        switch tab {
        case .draw:
            drawingScreen.setMode(.drawing)
        case .sticker:
            drawingScreen.setMode(.sticker)
        case .text:
            drawingScreen.setMode(.text)
        }
    }

    private func closePaint() {
        self.drawingScreen = nil
        self.previousDrawingData = nil
        self.previousDrawingEntities = nil
        self.entitiesView.selectEntity(nil)
        self.drawingView.isUserInteractionEnabled = false
        self.activeTool = nil
        self.updateEntityInteraction()
        self.requestLayout(transition: .animated(duration: 0.3, curve: .spring))
    }
}

public func chatMediaEditorScaleNewPaintEntity(_ entity: DrawingEntity, additionalScale: CGFloat) {
    guard abs(additionalScale - 1.0) > 0.001, abs(entity.scale - 1.0) < 0.001 else {
        return
    }
    entity.scale = additionalScale
}
