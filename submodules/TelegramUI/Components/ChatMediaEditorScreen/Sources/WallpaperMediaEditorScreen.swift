import Foundation
import UIKit
import Photos
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import MediaEditor
import MediaEditorScreen
import MediaAssetsContext

public struct WallpaperMediaEditorState {
    public let toolValues: [EditorToolKey: Any]
}

private let wallpaperMediaEditorPeerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(0))
private let wallpaperMediaEditorFullSizeMaxSide: CGFloat = 2048.0

public func wallpaperMediaEditorHiddenTools() -> [EditorToolKey] {
    return [.blur, .vignette]
}

public func wallpaperMediaEditorHasChanges(_ values: MediaEditorValues) -> Bool {
    return values.hasAdjustments || values.hasTint || values.hasBlur || values.hasCurves
}

public func wallpaperMediaEditorState(values: MediaEditorValues) -> Any {
    return WallpaperMediaEditorState(toolValues: values.toolValues)
}

public func wallpaperMediaEditorInitialValues(previousState: Any?, dimensions: PixelDimensions) -> MediaEditorValues {
    let toolValues = (previousState as? WallpaperMediaEditorState)?.toolValues ?? [:]
    return MediaEditorValues(
        peerId: wallpaperMediaEditorPeerId,
        originalDimensions: dimensions,
        cropOffset: .zero,
        cropRect: nil,
        cropScale: 1.0,
        cropRotation: 0.0,
        cropMirroring: false,
        cropOrientation: nil,
        cropPerspective: .zero,
        gradientColors: nil,
        videoTrimRange: nil,
        videoBounce: false,
        videoIsMuted: false,
        videoIsFullHd: false,
        videoIsMirrored: false,
        videoVolume: 1.0,
        additionalVideoPath: nil,
        additionalVideoIsDual: false,
        additionalVideoMirroringChanges: [],
        additionalVideoPosition: nil,
        additionalVideoScale: nil,
        additionalVideoRotation: nil,
        additionalVideoPositionChanges: [],
        additionalVideoTrimRange: nil,
        additionalVideoOffset: nil,
        additionalVideoVolume: nil,
        collage: [],
        nightTheme: false,
        drawing: nil,
        maskDrawing: nil,
        entities: [],
        toolValues: toolValues,
        audioTrack: nil,
        audioTrackTrimRange: nil,
        audioTrackOffset: nil,
        audioTrackVolume: nil,
        audioTrackSamples: nil,
        collageTrackSamples: nil,
        coverImageTimestamp: nil,
        coverDimensions: nil,
        qualityPreset: .compressedVeryHigh
    )
}

public func wallpaperMediaEditorShouldApply(initialValues: MediaEditorValues, finalValues: MediaEditorValues) -> Bool {
    let changed = wallpaperMediaEditorHasChanges(finalValues) || wallpaperMediaEditorHasChanges(initialValues)
    let dimensions = initialValues.originalDimensions
    let initialTools = wallpaperMediaEditorInitialValues(previousState: wallpaperMediaEditorState(values: initialValues), dimensions: dimensions)
    let finalTools = wallpaperMediaEditorInitialValues(previousState: wallpaperMediaEditorState(values: finalValues), dimensions: dimensions)
    return changed && finalTools != initialTools
}

public func wallpaperMediaEditorReferenceImageFrame(referenceFrame: CGRect, cropRect: CGRect, imageSize: CGSize) -> CGRect {
    guard cropRect.width > 0.0, cropRect.height > 0.0 else {
        return referenceFrame
    }
    let scale = referenceFrame.width / cropRect.width
    return CGRect(
        x: referenceFrame.minX - cropRect.minX * scale,
        y: referenceFrame.minY - cropRect.minY * scale,
        width: imageSize.width * scale,
        height: imageSize.height * scale
    )
}

public func wallpaperMediaEditorFullSizeTarget(dimensions: PixelDimensions) -> CGSize {
    return dimensions.cgSize.aspectFittedOrSmaller(CGSize(width: wallpaperMediaEditorFullSizeMaxSide, height: wallpaperMediaEditorFullSizeMaxSide))
}

public enum WallpaperMediaEditorFullSize {
    case rendered(UIImage)
    case notNeeded
    case unavailable
}

public enum WallpaperMediaEditorDelivery: Equatable {
    case fullSizeApply(UIImage?)
    case apply
}

public func wallpaperMediaEditorDeliveries(shouldApply: Bool, fullSize: WallpaperMediaEditorFullSize) -> [WallpaperMediaEditorDelivery] {
    guard shouldApply else {
        return []
    }
    switch fullSize {
    case let .rendered(image):
        return [.fullSizeApply(image), .apply]
    case .notNeeded:
        return [.fullSizeApply(nil), .apply]
    case .unavailable:
        return []
    }
}

public func wallpaperMediaEditorNormalizedImage(_ image: UIImage, maxPixelSide: CGFloat?) -> UIImage {
    let pixelSize = CGSize(width: (image.size.width * image.scale).rounded(), height: (image.size.height * image.scale).rounded())
    var target = pixelSize
    if let maxPixelSide {
        target = pixelSize.aspectFittedOrSmaller(CGSize(width: maxPixelSide, height: maxPixelSide))
        target = CGSize(width: max(1.0, target.width.rounded()), height: max(1.0, target.height.rounded()))
    }
    if image.scale == 1.0 && image.imageOrientation == .up && target == pixelSize && image.cgImage != nil {
        return image
    }
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    format.opaque = true
    return UIGraphicsImageRenderer(size: target, format: format).image { _ in
        image.draw(in: CGRect(origin: .zero, size: target))
    }
}

private let wallpaperMediaEditorRenderQueue = Queue(name: "WallpaperMediaEditorRender")

private func wallpaperMediaEditorRenderedImage(context: AccountContext, image: UIImage, values: MediaEditorValues) -> UIImage? {
    let dimensions = PixelDimensions(width: Int32((image.size.width * image.scale).rounded()), height: Int32((image.size.height * image.scale).rounded()))
    let renderValues = wallpaperMediaEditorInitialValues(previousState: wallpaperMediaEditorState(values: values), dimensions: dimensions)
    let editor = MediaEditor(context: context, mode: .default, subject: .image(image, dimensions), values: renderValues, isStandalone: true)
    editor.replaceSource(image, additionalImage: nil, time: .zero, mirror: false)
    let result = editor.resultImage
    editor.invalidate()
    return result
}

public final class WallpaperMediaEditorScreen: ViewController {
    final class Node: ASDisplayNode {
        private weak var controller: WallpaperMediaEditorScreen?
        private let context: AccountContext
        private let backgroundView = UIView()
        private let previewView = MediaEditorPreviewView(frame: .zero)
        private let referenceSnapshotView: UIView?
        let mediaEditor: MediaEditor
        let initialValues: MediaEditorValues
        private var validLayout: ContainerViewLayout?
        private var isDisplayed = false
        private var didAnimateIn = false
        private var isDismissing = false

        init(controller: WallpaperMediaEditorScreen) {
            self.controller = controller
            self.context = controller.context
            self.referenceSnapshotView = controller.referenceSnapshotView
            let image = controller.normalizedScreenImage
            let dimensions = PixelDimensions(width: Int32((image.size.width * image.scale).rounded()), height: Int32((image.size.height * image.scale).rounded()))
            self.initialValues = wallpaperMediaEditorInitialValues(previousState: controller.previousState, dimensions: dimensions)
            self.mediaEditor = MediaEditor(context: controller.context, mode: .default, subject: .image(image, dimensions), values: self.initialValues, hasHistogram: chatMediaEditorHasCurvesHistogram(.wallpaper))

            super.init()

            self.backgroundView.backgroundColor = .black
            self.backgroundView.alpha = 0.0
        }

        override func didLoad() {
            super.didLoad()

            self.view.disablesInteractiveTransitionGestureRecognizer = true
            self.view.disablesInteractiveModalDismiss = true

            if let referenceSnapshotView = self.referenceSnapshotView {
                self.view.addSubview(referenceSnapshotView)
            }
            self.view.addSubview(self.backgroundView)
            self.previewView.alpha = 0.0
            self.view.addSubview(self.previewView)

            let mediaEditor = self.mediaEditor
            mediaEditor.onFirstDisplay = { [weak self, weak mediaEditor] in
                Queue.mainQueue().async {
                    guard let self, let mediaEditor, self.mediaEditor === mediaEditor else {
                        return
                    }
                    self.isDisplayed = true
                    self.animateInIfReady()
                }
            }
            mediaEditor.attachPreviewView(self.previewView, andPlay: false)
            Queue.mainQueue().after(0.5) { [weak self] in
                guard let self else {
                    return
                }
                self.isDisplayed = true
                self.animateInIfReady()
            }
        }

        private func editorSafeInsets(layout: ContainerViewLayout) -> UIEdgeInsets {
            var safeInsets = layout.safeInsets
            if layout.intrinsicInsets.bottom > 0.0 {
                safeInsets.bottom = layout.intrinsicInsets.bottom
            }
            return safeInsets
        }

        private func previewFrame(layout: ContainerViewLayout) -> CGRect {
            let mediaSize = self.initialValues.originalDimensions.cgSize
            return chatMediaEditorToolPreviewFrame(kind: .tools, size: layout.size, safeInsets: self.editorSafeInsets(layout: layout), mediaSize: mediaSize, toolbarHeight: chatMediaEditorToolbarHeight)
        }

        private func referenceImageFrame() -> CGRect? {
            guard let controller = self.controller, let superview = controller.referenceView.superview else {
                return nil
            }
            let referenceFrame = superview.convert(controller.referenceView.frame, to: self.view)
            let imageSize = CGSize(width: controller.asset.pixelWidth, height: controller.asset.pixelHeight)
            return wallpaperMediaEditorReferenceImageFrame(referenceFrame: referenceFrame, cropRect: controller.cropRect, imageSize: imageSize)
        }

        func containerLayoutUpdated(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
            self.validLayout = layout
            transition.updateFrame(view: self.backgroundView, frame: CGRect(origin: .zero, size: layout.size))
            if let referenceSnapshotView = self.referenceSnapshotView, let controller = self.controller, let superview = controller.referenceView.superview {
                referenceSnapshotView.frame = superview.convert(controller.referenceView.frame, to: self.view)
            }
            if !self.isDismissing {
                transition.updateFrame(view: self.previewView, frame: self.previewFrame(layout: layout))
            }
            self.animateInIfReady()
        }

        private func animateInIfReady() {
            guard !self.didAnimateIn, self.isDisplayed, let layout = self.validLayout, let controller = self.controller else {
                return
            }
            self.didAnimateIn = true

            let previewFrame = self.previewFrame(layout: layout)
            self.previewView.frame = previewFrame
            self.previewView.alpha = 1.0
            if let sourceFrame = self.referenceImageFrame(), previewFrame.width > 0.0 {
                let scale = sourceFrame.width / previewFrame.width
                self.previewView.layer.animatePosition(from: CGPoint(x: sourceFrame.midX, y: sourceFrame.midY), to: CGPoint(x: previewFrame.midX, y: previewFrame.midY), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                self.previewView.layer.animateScale(from: scale, to: 1.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
            }
            UIView.animate(withDuration: 0.25, delay: 0.15, options: [.curveLinear], animations: {
                self.backgroundView.alpha = 1.0
            }, completion: { [weak self] _ in
                self?.referenceSnapshotView?.removeFromSuperview()
            })

            let toolsScreen = MediaToolsScreen(
                context: self.context,
                mediaEditor: self.mediaEditor,
                hiddenTools: wallpaperMediaEditorHiddenTools(),
                layoutStyle: .chat(previewFrame: previewFrame, mediaGeometry: nil, sidePanelFrame: nil)
            )
            toolsScreen.dismissed = { [weak self] in
                self?.toolsDismissed()
            }
            controller.present(toolsScreen, in: .current)
        }

        private func toolsDismissed() {
            guard !self.isDismissing, let controller = self.controller else {
                return
            }
            self.isDismissing = true
            let finalValues = self.mediaEditor.values
            let saving = wallpaperMediaEditorShouldApply(initialValues: self.initialValues, finalValues: finalValues)

            controller.beginTransitionOut(saving)

            if saving {
                let apply = controller.apply
                let fullSizeApply = controller.fullSizeApply
                let state = wallpaperMediaEditorState(values: finalValues)
                let _ = (self.results(values: finalValues)
                |> deliverOnMainQueue).startStandalone(next: { preview, fullSize in
                    for delivery in wallpaperMediaEditorDeliveries(shouldApply: true, fullSize: fullSize) {
                        switch delivery {
                        case let .fullSizeApply(image):
                            fullSizeApply(image)
                        case .apply:
                            apply(preview, state)
                        }
                    }
                })
            }

            self.animateOut(completion: { [weak self] in
                guard let self, let controller = self.controller else {
                    return
                }
                controller.finishTransitionOut()
                self.mediaEditor.invalidate()
                controller.dismiss()
            })
        }

        private func results(values: MediaEditorValues) -> Signal<(UIImage, WallpaperMediaEditorFullSize), NoError> {
            guard let controller = self.controller else {
                return .complete()
            }
            let context = self.context
            let screenImage = controller.normalizedScreenImage
            let hasChanges = wallpaperMediaEditorHasChanges(values)
            let preview: Signal<UIImage, NoError> = Signal { subscriber in
                if hasChanges {
                    subscriber.putNext(wallpaperMediaEditorRenderedImage(context: context, image: screenImage, values: values) ?? screenImage)
                } else {
                    subscriber.putNext(screenImage)
                }
                subscriber.putCompletion()
                return EmptyDisposable
            }
            |> runOn(wallpaperMediaEditorRenderQueue)

            let fullSize: Signal<WallpaperMediaEditorFullSize, NoError>
            if hasChanges {
                let asset = controller.asset
                let target = wallpaperMediaEditorFullSizeTarget(dimensions: PixelDimensions(width: Int32(asset.pixelWidth), height: Int32(asset.pixelHeight)))
                fullSize = assetFullImage(asset, targetSize: target, contentMode: .aspectFit)
                |> mapToSignal { result -> Signal<UIImage?, NoError> in
                    switch result {
                    case let .result(image):
                        return .single(image)
                    case .unavailable:
                        return .single(nil)
                    case .progress:
                        return .complete()
                    }
                }
                |> take(1)
                |> deliverOn(wallpaperMediaEditorRenderQueue)
                |> map { image -> WallpaperMediaEditorFullSize in
                    guard let image else {
                        return .unavailable
                    }
                    let normalized = wallpaperMediaEditorNormalizedImage(image, maxPixelSide: wallpaperMediaEditorFullSizeMaxSide)
                    guard let rendered = wallpaperMediaEditorRenderedImage(context: context, image: normalized, values: values) else {
                        return .unavailable
                    }
                    return .rendered(rendered)
                }
            } else {
                fullSize = .single(.notNeeded)
            }
            return combineLatest(preview, fullSize)
            |> take(1)
        }

        private func animateOut(completion: @escaping () -> Void) {
            UIView.animate(withDuration: 0.1, animations: {
                self.backgroundView.alpha = 0.0
            })
            let previewFrame = self.previewView.frame
            guard let targetFrame = self.referenceImageFrame(), previewFrame.width > 0.0 else {
                self.previewView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
                    completion()
                })
                return
            }
            let scale = targetFrame.width / previewFrame.width
            self.previewView.layer.animatePosition(from: CGPoint(x: previewFrame.midX, y: previewFrame.midY), to: CGPoint(x: targetFrame.midX, y: targetFrame.midY), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
            self.previewView.layer.animateScale(from: 1.0, to: scale, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
                completion()
            })
        }
    }

    fileprivate let context: AccountContext
    fileprivate let asset: PHAsset
    fileprivate let cropRect: CGRect
    fileprivate let previousState: Any?
    fileprivate let referenceView: UIView
    fileprivate let apply: (UIImage?, Any?) -> Void
    fileprivate let fullSizeApply: (UIImage?) -> Void
    fileprivate let beginTransitionOut: (Bool) -> Void
    fileprivate let finishTransitionOut: () -> Void
    fileprivate let normalizedScreenImage: UIImage
    fileprivate let referenceSnapshotView: UIView?

    private var node: Node {
        return self.displayNode as! Node
    }

    public init(context: AccountContext, asset: PHAsset, screenImage: UIImage, cropRect: CGRect, previousState: Any?, referenceView: UIView, apply: @escaping (UIImage?, Any?) -> Void, fullSizeApply: @escaping (UIImage?) -> Void, beginTransitionOut: @escaping (Bool) -> Void, finishTransitionOut: @escaping () -> Void) {
        self.context = context
        self.asset = asset
        self.cropRect = cropRect
        self.previousState = previousState
        self.referenceView = referenceView
        self.apply = apply
        self.fullSizeApply = fullSizeApply
        self.beginTransitionOut = beginTransitionOut
        self.finishTransitionOut = finishTransitionOut
        self.referenceSnapshotView = referenceView.snapshotView(afterScreenUpdates: false)
        self.normalizedScreenImage = wallpaperMediaEditorNormalizedImage(screenImage, maxPixelSide: nil)

        super.init(navigationBarPresentationData: nil)

        self.statusBar.statusBarStyle = .White
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.blocksBackgroundWhenInOverlay = true
        self.acceptsFocusWhenInOverlay = true
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        self.displayNode = Node(controller: self)

        super.displayNodeDidLoad()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.node.containerLayoutUpdated(layout: layout, transition: transition)
    }
}
