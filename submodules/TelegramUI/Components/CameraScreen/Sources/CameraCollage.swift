import Foundation
import AVFoundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import Camera
import ContextUI
import AccountContext
import MetalEngine
import TelegramPresentationData
import Photos

final class CameraCollage {
    final class CaptureResult {
        enum Content {
            case pending(CameraCollage.State.Item.Content.Placeholder?)
            case image(UIImage)
            case video(asset: AVAsset, thumbnail: UIImage?, duration: Double, source: CameraCollage.State.Item.Content.VideoSource)
            case failed
        }
        
        private var internalContent: Content
        private var disposable: Disposable?
        
        init(result: Signal<CameraScreenImpl.Result, NoError>, snapshotView: UIView?, contentUpdated: @escaping () -> Void) {
            self.internalContent = .pending(snapshotView.flatMap { .view($0) })
            self.disposable = (result
            |> deliverOnMainQueue).start(next: { [weak self] value in
                guard let self else {
                    return
                }
                switch value {
                case .pendingImage:
                    contentUpdated()
                case let .image(image):
                    self.internalContent = .image(image.image)
                    contentUpdated()
                case let .video(video):
                    self.internalContent = .pending(video.coverImage.flatMap { .image($0) })
                    contentUpdated()
                    Queue.mainQueue().after(0.05, {
                        let asset = AVURLAsset(url: URL(fileURLWithPath: video.videoPath))
                        self.internalContent = .video(asset: asset, thumbnail: video.coverImage, duration: video.duration, source: .file(video.videoPath))
                        contentUpdated()
                    })
               case let .asset(asset):
                    let targetSize = CGSize(width: 256.0, height: 256.0)
                    let options = PHImageRequestOptions()
                    let deliveryMode: PHImageRequestOptionsDeliveryMode = .highQualityFormat
                    options.deliveryMode = deliveryMode
                    options.isNetworkAccessAllowed = true
                    
                    PHImageManager.default().requestImage(
                        for: asset,
                        targetSize: targetSize,
                        contentMode: .aspectFit,
                        options: options,
                        resultHandler: { [weak self] image, info in
                            if let image, let self {
                                if let info {
                                    if let cancelled = info[PHImageCancelledKey] as? Bool, cancelled {
                                        return
                                    }
                                }
                                self.internalContent = .pending(.image(image))
                                contentUpdated()
                                
                                PHImageManager.default().requestAVAsset(forVideo: asset, options: nil, resultHandler: { [weak self] avAsset, _, _ in
                                    if let avAsset, let self {
                                        Queue.mainQueue().async {
                                            self.internalContent = .video(asset: avAsset, thumbnail: nil, duration: 0.0, source: .asset(asset))
                                            contentUpdated()
                                        }
                                    }
                                })
                            }
                        }
                    )
                default:
                    break
                }
            })
        }
                  
        deinit {
            self.disposable?.dispose()
        }
        
        var content: State.Item.Content? {
            switch self.internalContent {
            case let .pending(placeholder):
                return .pending(placeholder)
            case let .image(image):
                return .image(image)
            case let .video(asset, thumbnail, duration, source):
                return .video(asset, thumbnail, duration, source)
            case .failed:
                return nil
            }
        }
    }
    
    struct State {
        struct Item {
            enum Content {
                enum VideoSource {
                    case file(String)
                    case asset(PHAsset)
                }
                
                enum Placeholder {
                    case view(UIView)
                    case image(UIImage)
                }
                
                case empty
                case camera
                case pending(Placeholder?)
                case image(UIImage)
                case video(AVAsset, UIImage?, Double, VideoSource)
            }
            
            var uniqueId: Int64
            var content: Content
            
            var isReady: Bool {
                switch self.content {
                case .image, .video:
                    return true
                default:
                    return false
                }
            }
            
            var isAlmostReady: Bool {
                switch self.content {
                case .image, .video, .pending:
                    return true
                default:
                    return false
                }
            }
        }
        
        struct Row {
            let items: [Item]
        }
        
        var grid: Camera.CollageGrid
        var progress: Float
        var innerProgress: Float
        var rows: [Row]
    }
    private var _state: State
    private var _statePromise = Promise<State>()
    var state: Signal<State, NoError> {
        return self._statePromise.get()
    }
    
    var grid: Camera.CollageGrid {
        didSet {
            if self.grid != oldValue {
                self._state.grid = self.grid
                self.updateState()
            }
        }
    }
    var results: [CaptureResult]
    var uniqueIds: [Int64]
    
    private(set) var cameraIndex: Int?
            
    init(grid: Camera.CollageGrid) {
        self.grid = grid
        self.results = []
        self.uniqueIds = (0 ..< 6).map { _ in Int64.random(in: .min ... .max) }
        
        self._state = State(
            grid: grid,
            progress: 0.0,
            innerProgress: 0.0,
            rows: CameraCollage.computeRows(grid: grid, results: [], uniqueIds: self.uniqueIds, cameraIndex: self.cameraIndex)
        )
        self.updateState()
    }
        
    func addResult(_ signal: Signal<CameraScreenImpl.Result, NoError>, snapshotView: UIView?) {
        guard self.results.count < self.grid.count else {
            return
        }
        let result = CaptureResult(result: signal, snapshotView: snapshotView, contentUpdated: { [weak self] in
            self?.checkResults()
            self?.updateState()
        })
        if let cameraIndex = self.cameraIndex {
            self.cameraIndex = nil
            self.results.insert(result, at: cameraIndex)
        } else {
            self.results.append(result)
        }
        self.updateState()
    }
    
    func moveItem(fromId: Int64, toId: Int64) {
        guard let fromIndex = self.uniqueIds.firstIndex(where: { $0 == fromId }), let toIndex = self.uniqueIds.firstIndex(where: { $0 == toId }), toIndex < self.results.count else {
            return
        }
        let fromItem = self.results[fromIndex]
        let toItem = self.results[toIndex]
        self.results[fromIndex] = toItem
        self.uniqueIds[fromIndex] = toId
        self.results[toIndex] = fromItem
        self.uniqueIds[toIndex] = fromId
        self.updateState()
    }
    
    func retakeItem(id: Int64) {
        guard let index = self.uniqueIds.firstIndex(where: { $0 == id }) else {
            return
        }
        self.cameraIndex = index
        
        self.results.remove(at: index)
        self.updateState()
    }
    
    func deleteItem(id: Int64) {
        guard let index = self.uniqueIds.firstIndex(where: { $0 == id }) else {
            return
        }
        self.results.remove(at: index)
        self.uniqueIds.removeAll(where: { $0 == id })
        self.uniqueIds.append(Int64.random(in: .min ... .max))
    }
    
    func getItem(id: Int64) -> CaptureResult? {
        guard let index = self.uniqueIds.firstIndex(where: { $0 == id }) else {
            return nil
        }
        return self.results[index]
    }
    
    private func checkResults() {
        self.results = self.results.filter { $0.content != nil }
    }
    
    private static func computeRows(grid: Camera.CollageGrid, results: [CaptureResult], uniqueIds: [Int64], cameraIndex: Int?) -> [State.Row] {
        var rows: [State.Row] = []
        var index = 0
        var contentIndex = 0
        var addedCamera = false
        for row in grid.rows {
            var items: [State.Item] = []
            for _ in 0 ..< row.columns {
                if index == cameraIndex {
                    items.append(State.Item(uniqueId: uniqueIds[index], content: .camera))
                    addedCamera = true
                    contentIndex -= 1
                } else if contentIndex < results.count {
                    if let content = results[contentIndex].content {
                        items.append(State.Item(uniqueId: uniqueIds[index], content: content))
                    } else {
                        items.append(State.Item(uniqueId: uniqueIds[index], content: .empty))
                    }
                } else if index == results.count && !addedCamera {
                    items.append(State.Item(uniqueId: uniqueIds[index], content: .camera))
                } else {
                    items.append(State.Item(uniqueId: uniqueIds[index], content: .empty))
                }
                index += 1
                contentIndex += 1
            }
            rows.append(State.Row(items: items))
        }
        return rows
    }
    
    private static func computeProgress(rows: [State.Row], inner: Bool) -> Float {
        var readyCount: Int = 0
        var totalCount: Int = 0
        for row in rows {
            for item in row.items {
                if inner {
                    if item.isAlmostReady {
                        readyCount += 1
                    }
                } else {
                    if item.isReady {
                        readyCount += 1
                    }
                }
                totalCount += 1
            }
        }
        guard totalCount > 0 else {
            return 0.0
        }
        return Float(readyCount) / Float(totalCount)
    }
    
    private func updateState() {
        self._state.rows = CameraCollage.computeRows(grid: self._state.grid, results: self.results, uniqueIds: self.uniqueIds, cameraIndex: self.cameraIndex)
        self._state.progress = CameraCollage.computeProgress(rows: self._state.rows, inner: false)
        self._state.innerProgress = CameraCollage.computeProgress(rows: self._state.rows, inner: true)
        self._statePromise.set(.single(self._state))
    }
    
    var isComplete: Bool {
        return self._state.progress > 1.0 - .ulpOfOne
    }
    
    var result: Signal<CameraScreenImpl.Result, NoError> {
        guard self.isComplete else {
            return .complete()
        }
        
        var hasVideo = false
        let state = self._state
        
outer:  for row in state.rows {
            for item in row.items {
                if case .video = item.content {
                    hasVideo = true
                    break outer
                }
            }
        }
        
        let size = CGSize(width: 1080.0, height: 1920.0)
        let rowHeight: CGFloat = ceil(size.height / CGFloat(state.rows.count))
        
        if hasVideo {
            var items: [CameraScreenImpl.Result.VideoCollage.Item] = []
            var itemFrame: CGRect = .zero
            for row in state.rows {
                let columnWidth: CGFloat = floor(size.width / CGFloat(row.items.count))
                itemFrame = CGRect(origin: itemFrame.origin, size: CGSize(width: columnWidth, height: rowHeight))
                for item in row.items {
                    let content: CameraScreenImpl.Result.VideoCollage.Item.Content
                    switch item.content {
                    case let .image(image):
                        content = .image(image)
                    case let .video(_, _, duration, source):
                        switch source {
                        case let .file(path):
                            content = .video(path, duration)
                        case let .asset(asset):
                            content = .asset(asset)
                        }
                    default:
                        fatalError()
                    }
                    items.append(CameraScreenImpl.Result.VideoCollage.Item(content: content, frame: itemFrame))
                    itemFrame.origin.x += columnWidth
                }
                itemFrame.origin.x = 0.0
                itemFrame.origin.y += rowHeight
            }
            return .single(.videoCollage(CameraScreenImpl.Result.VideoCollage(items: items)))
        } else {
            let image = generateImage(size, contextGenerator: { size, context in
                var itemFrame: CGRect = .zero
                for row in state.rows {
                    let columnWidth: CGFloat = floor(size.width / CGFloat(row.items.count))
                    itemFrame = CGRect(origin: itemFrame.origin, size: CGSize(width: columnWidth, height: rowHeight))
                    for item in row.items {
                        let mappedItemFrame = CGRect(origin: CGPoint(x: itemFrame.minX, y: size.height - itemFrame.origin.y - rowHeight), size: CGSize(width: columnWidth, height: rowHeight))
                        if case let .image(image) = item.content {
                            context.clip(to: mappedItemFrame)
                            let drawingSize = image.size.aspectFilled(mappedItemFrame.size)
                            let imageFrame = drawingSize.centered(around: mappedItemFrame.center)
                            if let cgImage = image.cgImage {
                                context.draw(cgImage, in: imageFrame, byTiling: false)
                            }
                            context.resetClip()
                        }
                        itemFrame.origin.x += columnWidth
                    }
                    itemFrame.origin.x = 0.0
                    itemFrame.origin.y += rowHeight
                }
            }, opaque: true, scale: 1.0)
            if let image {
                return .single(.image(CameraScreenImpl.Result.Image(image: image, additionalImage: nil, additionalImagePosition: .topLeft)))
            } else {
                return .single(.pendingImage)
            }
        }
    }
}

final class CameraCollageView: UIView, UIGestureRecognizerDelegate {
    final class PreviewLayer: SimpleLayer {
        var dispose: () -> Void = {}
        
        let contentLayer: MetalEngineSubjectLayer
        init(contentLayer: MetalEngineSubjectLayer) {
            self.contentLayer = contentLayer
            super.init()
            self.addSublayer(contentLayer)
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        func update(size: CGSize, transition: ComponentTransition) {
            let filledSize = CGSize(width: 320.0, height: 568.0).aspectFilled(size)
            transition.setFrame(layer: self.contentLayer, frame: filledSize.centered(around: CGPoint(x: size.width / 2.0, y: size.height / 2.0)))
        }
    }
    
    final class ItemView: ContextControllerSourceView {
        private let extractedContainerView = ContextExtractedContentContainingView()
        
        private let clippingView = UIView()
        private var snapshotView: UIView?
        private var cameraContainerView: UIView?
        private var imageView: UIImageView?
        private var previewLayer: PreviewLayer?
        
        private var videoPlayer: AVPlayer?
        private var videoLayer: AVPlayerLayer?
        private var didPlayToEndTimeObserver: NSObjectProtocol?
        
        private var originalCameraTransform: CATransform3D?
        private var originalCameraFrame: CGRect?
        
        var contextAction: ((Int64, ContextExtractedContentContainingView, ContextGesture?) -> Void)?
        
        var isCamera: Bool {
            if case .camera = self.item?.content {
                return true
            }
            return false
        }
        
        var isReady: Bool {
            if case .image = self.item?.content {
                return true
            }
            if case .video = self.item?.content {
                return true
            }
            return false
        }
        
        var isPlaying: Bool {
            if let videoPlayer = self.videoPlayer {
                return videoPlayer.rate > 0.0
            } else {
                return false
            }
        }
        
        var didPlayToEnd: (() -> Void) = {}
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.clippingView.clipsToBounds = true
            
            self.addSubview(self.extractedContainerView)
            
            self.isGestureEnabled = false
            self.targetViewForActivationProgress = self.extractedContainerView.contentView
            
            self.clipsToBounds = true
            self.extractedContainerView.contentView.clipsToBounds = true
            self.extractedContainerView.contentView.addSubview(self.clippingView)
            
            self.extractedContainerView.willUpdateIsExtractedToContextPreview = { [weak self] value, _ in
                guard let self else {
                    return
                }
                let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut)
                if value {
                    self.clippingView.layer.cornerRadius = 12.0
                    transition.updateSublayerTransformScale(layer: self.extractedContainerView.contentView.layer, scale: CGPoint(x: 0.9, y: 0.9))
                } else {
                    self.clippingView.layer.cornerRadius = 0.0
                    self.clippingView.layer.animate(from: NSNumber(value: Float(12.0)), to: NSNumber(value: Float(0.0)), keyPath: "cornerRadius", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
                    transition.updateSublayerTransformScale(layer: self.extractedContainerView.contentView.layer, scale: CGPoint(x: 1.0, y: 1.0))
                }
            }
            
            self.activated = { [weak self] gesture, _ in
                guard let self, let item = self.item else {
                    gesture.cancel()
                    return
                }
                self.contextAction?(item.uniqueId, self.extractedContainerView, gesture)
            }
        }
        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }
               
        func requestContextAction() {
            guard let item = self.item, self.isReady else {
                return
            }
            self.contextAction?(item.uniqueId, self.extractedContainerView, nil)
        }
        
        func stopPlayback() {
            self.videoPlayer?.pause()
        }
        
        func resetPlayback() {
            self.videoPlayer?.seek(to: .zero)
            self.videoPlayer?.play()
        }
        
        var getPreviewLayer: () -> PreviewLayer? = { return nil }
        
        private var item: CameraCollage.State.Item?
        func update(item: CameraCollage.State.Item, size: CGSize, cameraContainerView: UIView?, transition: ComponentTransition) {
            self.item = item
            
            let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
            
            switch item.content {
            case let .pending(placeholder):
                if let placeholder {
                    let snapshotView: UIView
                    switch placeholder {
                    case let .view(view):
                        snapshotView = view
                    case let .image(image):
                        if let current = self.snapshotView as? UIImageView {
                            snapshotView = current
                        } else {
                            snapshotView = UIImageView(image: image)
                            snapshotView.contentMode = .scaleAspectFill
                            snapshotView.isUserInteractionEnabled = false
                            snapshotView.frame = image.size.aspectFilled(size).centered(in: CGRect(origin: .zero, size: size))
                        }
                    }
                    
                    self.snapshotView = snapshotView
                    var snapshotTransition = transition
                    if snapshotView.superview !== self.clippingView {
                        snapshotTransition = .immediate
                        self.clippingView.addSubview(snapshotView)
                        
                        let shutterLayer = SimpleLayer()
                        shutterLayer.backgroundColor = UIColor.white.cgColor
                        shutterLayer.frame = CGRect(origin: .zero, size: size)
                        self.layer.addSublayer(shutterLayer)
                        shutterLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                            shutterLayer.removeFromSuperlayer()
                        })
                    }
                    let scale = max(size.width / snapshotView.bounds.width, size.height / snapshotView.bounds.height)
                    snapshotTransition.setPosition(layer: snapshotView.layer, position: center)
                    snapshotTransition.setTransform(layer: snapshotView.layer, transform: CATransform3DMakeScale(scale, scale, 1.0))
                    
                    if let previewLayer = self.previewLayer {
                        previewLayer.dispose()
                        previewLayer.removeFromSuperlayer()
                        self.previewLayer = nil
                    }
                    if let cameraContainerView = self.cameraContainerView {
                        cameraContainerView.removeFromSuperview()
                        self.cameraContainerView = nil
                    }
                }
            case .camera:
                if let cameraContainerView {
                    self.cameraContainerView = cameraContainerView
                    if cameraContainerView.superview !== self.extractedContainerView.contentView {
                        self.originalCameraTransform = CATransform3DIdentity
                        self.originalCameraFrame = cameraContainerView.bounds
                        self.clippingView.addSubview(cameraContainerView)
                    }
                    if let originalCameraFrame = self.originalCameraFrame {
                        let scale = max(size.width / originalCameraFrame.width, size.height / originalCameraFrame.height)
                        transition.setPosition(layer: cameraContainerView.layer, position: center)
                        transition.setTransform(layer: cameraContainerView.layer, transform: CATransform3DMakeScale(scale, scale, 1.0))
                    }
                }
                if let imageView = self.imageView {
                    imageView.superview?.bringSubviewToFront(imageView)
                    imageView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                        imageView.removeFromSuperview()
                    })
                    self.imageView = nil
                }
                if let videoLayer = self.videoLayer {
                    self.videoPlayer?.pause()
                    self.videoPlayer = nil
                    
                    videoLayer.superlayer?.addSublayer(videoLayer)
                    videoLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                        videoLayer.removeFromSuperlayer()
                    })
                    self.videoLayer = nil
                }
                if let snapshotView = self.snapshotView {
                    snapshotView.removeFromSuperview()
                    self.snapshotView = nil
                }
                if let previewLayer = self.previewLayer {
                    cameraContainerView?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, completion: { _ in
                        previewLayer.removeFromSuperlayer()
                    })
                    self.previewLayer = nil
                }
            case .empty:
                if let cameraContainerView = self.cameraContainerView {
                    cameraContainerView.removeFromSuperview()
                    self.cameraContainerView = nil
                }
                if let snapshotView = self.snapshotView {
                    snapshotView.removeFromSuperview()
                    self.snapshotView = nil
                }
                var imageTransition = transition
                if self.previewLayer == nil, let previewLayer = self.getPreviewLayer() {
                    imageTransition = .immediate
                    self.previewLayer = previewLayer
                    
                    self.clippingView.layer.addSublayer(previewLayer)
                }
                if let imageView = self.imageView {
                    imageView.superview?.bringSubviewToFront(imageView)
                    imageView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                        imageView.removeFromSuperview()
                    })
                    self.imageView = nil
                }
                if let videoLayer = self.videoLayer {
                    self.videoPlayer?.pause()
                    self.videoPlayer = nil
                    
                    videoLayer.superlayer?.addSublayer(videoLayer)
                    videoLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                        videoLayer.removeFromSuperlayer()
                    })
                    self.videoLayer = nil
                }
                if let previewLayer = self.previewLayer {
                    previewLayer.update(size: size, transition: imageTransition)
                    imageTransition.setFrame(layer: previewLayer, frame: CGRect(origin: .zero, size: size))
                }
            case let .image(image):
                if let cameraContainerView = self.cameraContainerView {
                    cameraContainerView.removeFromSuperview()
                    self.cameraContainerView = nil
                }
                if let snapshotView = self.snapshotView {
                    snapshotView.removeFromSuperview()
                    self.snapshotView = nil
                }
                if let previewLayer = self.previewLayer {
                    previewLayer.dispose()
                    previewLayer.removeFromSuperlayer()
                    self.previewLayer = nil
                }
                
                var imageTransition = transition
                var imageView: UIImageView
                if let current = self.imageView {
                    imageView = current
                } else {
                    imageTransition = .immediate
                    imageView = UIImageView()
                    imageView.contentMode = .scaleAspectFill
                    self.imageView = imageView
                    self.clippingView.addSubview(imageView)
                }
                imageView.image = image
                imageTransition.setFrame(view: imageView, frame: CGRect(origin: .zero, size: size))
            case let .video(asset, _, _, _):
                if let cameraContainerView = self.cameraContainerView {
                    cameraContainerView.removeFromSuperview()
                    self.cameraContainerView = nil
                }
                var delayAppearance = false
                if let snapshotView = self.snapshotView {
                    if snapshotView is UIImageView {
      
                    } else {
                        delayAppearance = true
                    }
                    Queue.mainQueue().after(0.2, {
                        snapshotView.removeFromSuperview()
                    })
                    self.snapshotView = nil
                }
                if let previewLayer = self.previewLayer {
                    previewLayer.dispose()
                    previewLayer.removeFromSuperlayer()
                    self.previewLayer = nil
                }
                
                var imageTransition = transition
                if self.videoLayer == nil {
                    imageTransition = .immediate
                    let playerItem = AVPlayerItem(asset: asset)
                    let player = AVPlayer(playerItem: playerItem)
                    player.isMuted = true
                    if self.didPlayToEndTimeObserver == nil {
                        self.didPlayToEndTimeObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: nil, using: { [weak self] notification in
                            if let self {
                                self.didPlayToEnd()
                            }
                        })
                    }
                    
                    let videoLayer = AVPlayerLayer(player: player)
                    videoLayer.videoGravity = .resizeAspectFill
                    
                    if delayAppearance {
                        videoLayer.opacity = 0.0
                        Queue.mainQueue().after(0.15, {
                            videoLayer.opacity = 1.0
                        })
                    }
                                            
                    self.videoLayer = videoLayer
                    self.videoPlayer = player
                    
                    self.clippingView.layer.addSublayer(videoLayer)
                    
                    player.playImmediately(atRate: 1.0)
                }
                
                if let videoLayer = self.videoLayer {
                    imageTransition.setFrame(layer: videoLayer, frame: CGRect(origin: .zero, size: size))
                }
            }
                        
            let bounds = CGRect(origin: .zero, size: size)
            transition.setFrame(view: self.extractedContainerView, frame: bounds)
            transition.setFrame(view: self.extractedContainerView.contentView, frame: bounds)
            transition.setBounds(view: self.clippingView, bounds: bounds)
            transition.setPosition(view: self.clippingView, position: bounds.center)
            self.extractedContainerView.contentRect = bounds
        }
        
        func animateIn(from size: CGSize, transition: ComponentTransition) {
            guard let cameraContainerView = self.cameraContainerView, let originalCameraFrame = self.originalCameraFrame  else {
                return
            }
            
            self.extractedContainerView.contentView.clipsToBounds = false
            self.clippingView.clipsToBounds = false
            
            let scale = self.bounds.width / originalCameraFrame.width
            transition.animateScale(view: cameraContainerView, from: 1.0, to: scale)
            transition.animatePosition(view: cameraContainerView, from: originalCameraFrame.center, to: cameraContainerView.center, completion: { _ in
                self.extractedContainerView.contentView.clipsToBounds = true
                self.clippingView.clipsToBounds = true
            })
        }
        
        func animateOut(to size: CGSize, transition: ComponentTransition, completion: @escaping () -> Void) {
            guard let cameraContainerView = self.cameraContainerView, let originalCameraFrame = self.originalCameraFrame  else {
                return
            }
            
            self.extractedContainerView.contentView.clipsToBounds = false
            self.clippingView.clipsToBounds = false
            
            let scale = max(self.frame.width / originalCameraFrame.width, self.frame.height / originalCameraFrame.height)
            cameraContainerView.transform = CGAffineTransform.identity
            transition.animateScale(view: cameraContainerView, from: scale, to: 1.0)
            transition.setPosition(view: cameraContainerView, position: CGPoint(x: size.width / 2.0, y: size.height / 2.0), completion: { _ in
                self.extractedContainerView.contentView.clipsToBounds = true
                self.clippingView.clipsToBounds = true
                completion()
            })
        }
    }
    
    private let context: AccountContext
    private let collage: CameraCollage
    private weak var camera: Camera?
    private weak var cameraContainerView: UIView?
    
    private var cameraVideoSource: CameraVideoSource?
    private var cameraVideoDisposable: Disposable?
    
    private let cameraVideoLayer = CameraVideoLayer()
    private let cloneLayers: [MetalEngineSubjectLayer]
    
    private var itemViews: [Int64: ItemView] = [:]
    
    private var state: CameraCollage.State?
    private var disposable: Disposable?
    
    private var reorderRecognizer: ReorderGestureRecognizer?
    private var reorderingItem: (id: Int64, initialPosition: CGPoint, position: CGPoint)?
    
    private var tapRecognizer: UITapGestureRecognizer?
    
    private var validLayout: CGSize?
    
    var getOverlayViews: (() -> [UIView])?
    
    var requestGridReduce: (() -> Void)?
    
    var isEnabled: Bool = true
    
    init(context: AccountContext, collage: CameraCollage, camera: Camera?, cameraContainerView: UIView?) {
        self.context = context
        self.collage = collage
        self.cameraContainerView = cameraContainerView
        
        self.cloneLayers = (0 ..< 6).map { _ in MetalEngineSubjectLayer() }
        self.cameraVideoLayer.blurredLayer.cloneLayers = self.cloneLayers
        
        super.init(frame: .zero)
        
        self.backgroundColor = .black
        
        self.disposable = (collage.state
        |> deliverOnMainQueue).start(next: { [weak self] state in
            guard let self else {
                return
            }
            let previousState = self.state
            self.state = state
            if let size = self.validLayout {
                var transition: ComponentTransition = .spring(duration: 0.3)
                if let previousState, previousState.grid == state.grid && previousState.innerProgress != state.innerProgress {
                    transition = .immediate
                }
                var progressUpdated = false
                if let previousState, previousState.progress != state.progress {
                    progressUpdated = true
                }
                self.updateLayout(size: size, transition: transition)
                
                if progressUpdated {
                    self.resetPlayback()
                }
            }
        })
        
        let reorderRecognizer = ReorderGestureRecognizer(
            shouldBegin: { [weak self] point in
                guard let self, let item = self.item(at: point) else {
                    return (allowed: false, requiresLongPress: false, item: nil)
                }
                
                return (allowed: true, requiresLongPress: true, item: item)
            },
            willBegin: { point in
            },
            began: { [weak self] item in
                guard let self else {
                    return
                }
                self.setReorderingItem(item: item)
            },
            ended: { [weak self] in
                guard let self else {
                    return
                }
                self.setReorderingItem(item: nil)
            },
            moved: { [weak self] distance in
                guard let self else {
                    return
                }
                self.moveReorderingItem(distance: distance)
            },
            isActiveUpdated: { _ in
            }
        )
        reorderRecognizer.delegate = self
        self.reorderRecognizer = reorderRecognizer
        self.addGestureRecognizer(reorderRecognizer)
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleTap))
        self.tapRecognizer = tapRecognizer
        self.addGestureRecognizer(tapRecognizer)
        
        if let cameraVideoSource = CameraVideoSource() {
            self.cameraVideoLayer.video = cameraVideoSource.currentOutput
            camera?.setPreviewOutput(cameraVideoSource.cameraVideoOutput)
            self.cameraVideoSource = cameraVideoSource
            
            self.cameraVideoDisposable = cameraVideoSource.addOnUpdated { [weak self] in
                guard let self, let videoSource = self.cameraVideoSource, self.isEnabled else {
                    return
                }
                self.cameraVideoLayer.video = videoSource.currentOutput
            }
        }
        
        let videoSize = CGSize(width: 160.0 * 2.0, height: 284.0 * 2.0)
        self.cameraVideoLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: videoSize)
        self.cameraVideoLayer.blurredLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: videoSize)
        self.cameraVideoLayer.renderSpec = RenderLayerSpec(size: RenderSize(width: Int(videoSize.width), height: Int(videoSize.height)), edgeInset: 2)
    }
    
    required init?(coder: NSCoder) {
        preconditionFailure()
    }
    
    deinit {
        self.disposable?.dispose()
        self.cameraVideoDisposable?.dispose()
        self.camera?.setPreviewOutput(nil)
    }
    
    func getPreviewLayer() -> PreviewLayer {
        var contentLayer = MetalEngineSubjectLayer()
        for layer in self.cloneLayers {
            if layer.superlayer?.superlayer == nil {
                contentLayer = layer
                break
            }
        }
        return PreviewLayer(contentLayer: contentLayer)
    }
    
    @objc private func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        self.reorderRecognizer?.isEnabled = false
        self.reorderRecognizer?.isEnabled = true
        
        let location = gestureRecognizer.location(in: self)
        if let itemView = self.item(at: location) {
            itemView.requestContextAction()
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if otherGestureRecognizer is UITapGestureRecognizer {
            return true
        }
        return false
    }
    
    func item(at point: CGPoint) -> ItemView? {
        for (_, itemView) in self.itemViews {
            if itemView.frame.contains(point), itemView.isReady {
                return itemView
            }
        }
        return nil
    }
    
    func setReorderingItem(item: ItemView?) {
        self.tapRecognizer?.isEnabled = false
        self.tapRecognizer?.isEnabled = true
        
        var mappedItem: (Int64, ItemView)?
        if let item {
            for (id, visibleItem) in self.itemViews {
                if visibleItem === item {
                    mappedItem = (id, visibleItem)
                    break
                }
            }
        }
        
        if self.reorderingItem?.id != mappedItem?.0 {
            if let (id, itemView) = mappedItem {
                self.addSubview(itemView)
                self.reorderingItem = (id, itemView.center, itemView.center)
            } else {
                self.reorderingItem = nil
            }
            if let size = self.validLayout {
                self.updateLayout(size: size, transition: .spring(duration: 0.4))
            }
        }
    }
    
    func moveReorderingItem(distance: CGPoint) {
        if let (id, initialPosition, _) = self.reorderingItem {
            let targetPosition = CGPoint(x: initialPosition.x + distance.x, y: initialPosition.y + distance.y)
            self.reorderingItem = (id, initialPosition, targetPosition)
            if let size = self.validLayout {
                self.updateLayout(size: size, transition: .immediate)
            }
            
            if let visibleReorderingItem = self.itemViews[id] {
                for (visibleId, visibleItem) in self.itemViews {
                    if visibleItem === visibleReorderingItem {
                        continue
                    }
                    if visibleItem.frame.contains(targetPosition) {
                        self.collage.moveItem(fromId: id, toId: visibleId)
                        break
                    }
                }
            }
        }
    }
    
    func stopPlayback() {
        for (_, itemView) in self.itemViews {
            itemView.stopPlayback()
        }
    }
    
    func resetPlayback() {
        for (_, itemView) in self.itemViews {
            itemView.resetPlayback()
        }
    }
    
    func maybeResetPlayback() {
        var shouldResetPlayback = true
        for (_, itemView) in self.itemViews {
            if itemView.isPlaying {
                shouldResetPlayback = false
                break
            }
        }
        if shouldResetPlayback {
            self.resetPlayback()
        }
    }
    
    func animateIn(transition: ComponentTransition) {
        guard let size = self.validLayout, let (_, cameraItemView) = self.itemViews.first(where: { $0.value.isCamera }) else {
            return
        }
        
        let targetFrame = cameraItemView.frame
        let sourceFrame = CGRect(origin: .zero, size: size)
        
        cameraItemView.frame = sourceFrame
        transition.setFrame(view: cameraItemView, frame: targetFrame)
        cameraItemView.animateIn(from: sourceFrame.size, transition: transition)
    }
    
    func animateOut(transition: ComponentTransition, completion: @escaping () -> Void) {
        guard let size = self.validLayout else {
            completion()
            return
        }
        guard let (_, cameraItemView) = self.itemViews.first(where: { $0.value.isCamera }) else {
            if let cameraContainerView = self.cameraContainerView {
                cameraContainerView.transform = CGAffineTransform.identity
                cameraContainerView.frame = CGRect(origin: .zero, size: size)
                cameraContainerView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                cameraContainerView.layer.animateScale(from: 0.02, to: 1.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, completion: { _ in
                    completion()
                })
                self.addSubview(cameraContainerView)
            }
            return
        }
        
        cameraItemView.superview?.bringSubviewToFront(cameraItemView)
        
        let targetFrame = CGRect(origin: .zero, size: size)
        cameraItemView.animateOut(to: targetFrame.size, transition: transition, completion: completion)
        transition.setFrame(view: cameraItemView, frame: targetFrame)
    }
    
    var presentController: ((ViewController) -> Void)?
    func contextGesture(id: Int64, sourceView: ContextExtractedContentContainingView, gesture: ContextGesture?) {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        
        var itemList: [ContextMenuItem] = []
        if self.collage.cameraIndex == nil {
            itemList.append(.action(ContextMenuActionItem(text: presentationData.strings.Camera_CollageRetake, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Camera"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, f in
                f(.default)
                
                self?.collage.retakeItem(id: id)
            })))
        }
        
        if self.itemViews.count > 2 {
            itemList.append(.separator)
            
            itemList.append(.action(ContextMenuActionItem(text: presentationData.strings.Camera_CollageDelete, textColor: .destructive, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
            }, action: { [weak self] _, f in
                f(.dismissWithoutContent)
                
                self?.collage.deleteItem(id: id)
                self?.requestGridReduce?()
            })))
        }
        
        guard !itemList.isEmpty else {
            return
        }
        
        let items = ContextController.Items(content: .list(itemList), tip: .collageReordering)
        let controller = ContextController(
            presentationData: presentationData.withUpdated(theme: defaultDarkColorPresentationTheme),
            source: .extracted(CollageContextExtractedContentSource(contentView: sourceView)),
            items: .single(items),
            recognizer: nil,
            gesture: gesture
        )
        controller.getOverlayViews = self.getOverlayViews
        self.presentController?(controller)
    }
    
    func updateLayout(size: CGSize, transition: ComponentTransition) {
        self.validLayout = size
        guard let state = self.state else {
            return
        }
        
        var validIds = Set<Int64>()
        
        let rowHeight: CGFloat = ceil(size.height / CGFloat(state.rows.count))
        
        var previousItemFrame: CGRect?
        
        var itemFrame: CGRect = .zero
        for row in state.rows {
            let columnWidth: CGFloat = floor(size.width / CGFloat(row.items.count))
            itemFrame = CGRect(origin: itemFrame.origin, size: CGSize(width: columnWidth, height: rowHeight))
                        
            for item in row.items {
                let id = item.uniqueId
                validIds.insert(id)
            
                var effectiveItemFrame = itemFrame
                let itemScale: CGFloat
                let itemCornerRadius: CGFloat
                if let reorderingItem = self.reorderingItem, item.uniqueId == reorderingItem.id {
                    itemScale = 0.9
                    itemCornerRadius = 12.0
                    effectiveItemFrame = itemFrame.size.centered(around: reorderingItem.position)
                } else {
                    itemScale = 1.0
                    itemCornerRadius = 0.0
                }
                
                var itemTransition = transition
                let itemView: ItemView
                if let current = self.itemViews[id] {
                    itemView = current
                    previousItemFrame = itemFrame
                } else {
                    itemView = ItemView(frame: effectiveItemFrame)
                    itemView.clipsToBounds = true
                    itemView.getPreviewLayer = { [weak self] in
                        return self?.getPreviewLayer()
                    }
                    itemView.didPlayToEnd = { [weak self] in
                        self?.maybeResetPlayback()
                    }
                    self.insertSubview(itemView, at: 0)
                    self.itemViews[id] = itemView
                    
                    if !transition.animation.isImmediate, let previousItemFrame {
                        itemView.frame = previousItemFrame
                    } else {
                        itemTransition = .immediate
                    }
                }
                itemView.update(item: item, size: effectiveItemFrame.size, cameraContainerView: self.cameraContainerView, transition: itemTransition)
                itemView.contextAction = { [weak self] id, sourceView, gesture in
                    guard let self else {
                        return
                    }
                    self.contextGesture(id: id, sourceView: sourceView, gesture: gesture)
                }
                
                itemTransition.setBounds(view: itemView, bounds: CGRect(origin: .zero, size: effectiveItemFrame.size))
                itemTransition.setPosition(view: itemView, position: effectiveItemFrame.center)
                itemTransition.setScale(view: itemView, scale: itemScale)
                
                if !itemTransition.animation.isImmediate {
                    let cornerTransition: ComponentTransition
                    if itemCornerRadius > 0.0 {
                        cornerTransition = ComponentTransition(animation: .curve(duration: 0.1, curve: .linear))
                    } else {
                        cornerTransition = .easeInOut(duration: 0.4)
                    }
                    cornerTransition.setCornerRadius(layer: itemView.layer, cornerRadius: itemCornerRadius)
                } else {
                    itemTransition.setCornerRadius(layer: itemView.layer, cornerRadius: itemCornerRadius)
                }
                
                itemFrame.origin.x += columnWidth
            }
            itemFrame.origin.x = 0.0
            itemFrame.origin.y += rowHeight
        }
        
        var removeIds: [Int64] = []
        for (id, itemView) in self.itemViews {
            if !validIds.contains(id) {
                removeIds.append(id)
                transition.setAlpha(view: itemView, alpha: 0.0, completion: { [weak itemView] _ in
                    itemView?.removeFromSuperview()
                })
            }
        }
        for id in removeIds {
            self.itemViews.removeValue(forKey: id)
        }
    }
}

private final class ReorderGestureRecognizer: UIGestureRecognizer {
    private let shouldBegin: (CGPoint) -> (allowed: Bool, requiresLongPress: Bool, item: CameraCollageView.ItemView?)
    private let willBegin: (CGPoint) -> Void
    private let began: (CameraCollageView.ItemView) -> Void
    private let ended: () -> Void
    private let moved: (CGPoint) -> Void
    private let isActiveUpdated: (Bool) -> Void
    
    private var initialLocation: CGPoint?
    private var longTapTimer: SwiftSignalKit.Timer?
    private var longPressTimer: SwiftSignalKit.Timer?
    
    private var itemView: CameraCollageView.ItemView?
    
    public init(shouldBegin: @escaping (CGPoint) -> (allowed: Bool, requiresLongPress: Bool, item: CameraCollageView.ItemView?), willBegin: @escaping (CGPoint) -> Void, began: @escaping (CameraCollageView.ItemView) -> Void, ended: @escaping () -> Void, moved: @escaping (CGPoint) -> Void, isActiveUpdated: @escaping (Bool) -> Void) {
        self.shouldBegin = shouldBegin
        self.willBegin = willBegin
        self.began = began
        self.ended = ended
        self.moved = moved
        self.isActiveUpdated = isActiveUpdated
        
        super.init(target: nil, action: nil)
    }
    
    deinit {
        self.longTapTimer?.invalidate()
        self.longPressTimer?.invalidate()
    }
    
    private func startLongTapTimer() {
        self.longTapTimer?.invalidate()
        let longTapTimer = SwiftSignalKit.Timer(timeout: 0.25, repeat: false, completion: { [weak self] in
            self?.longTapTimerFired()
        }, queue: Queue.mainQueue())
        self.longTapTimer = longTapTimer
        longTapTimer.start()
    }
    
    private func stopLongTapTimer() {
        self.itemView = nil
        self.longTapTimer?.invalidate()
        self.longTapTimer = nil
    }
    
    private func startLongPressTimer() {
        self.longPressTimer?.invalidate()
        let longPressTimer = SwiftSignalKit.Timer(timeout: 0.6, repeat: false, completion: { [weak self] in
            self?.longPressTimerFired()
        }, queue: Queue.mainQueue())
        self.longPressTimer = longPressTimer
        longPressTimer.start()
    }
    
    private func stopLongPressTimer() {
        self.itemView = nil
        self.longPressTimer?.invalidate()
        self.longPressTimer = nil
    }
    
    override public func reset() {
        super.reset()
        
        self.itemView = nil
        self.stopLongTapTimer()
        self.stopLongPressTimer()
        self.initialLocation = nil
        
        self.isActiveUpdated(false)
    }
    
    private func longTapTimerFired() {
        guard let location = self.initialLocation else {
            return
        }
        
        self.longTapTimer?.invalidate()
        self.longTapTimer = nil
        
        self.willBegin(location)
    }
    
    private func longPressTimerFired() {
        guard let _ = self.initialLocation else {
            return
        }
        
        self.isActiveUpdated(true)
        self.state = .began
        self.longPressTimer?.invalidate()
        self.longPressTimer = nil
        self.longTapTimer?.invalidate()
        self.longTapTimer = nil
        if let itemView = self.itemView {
            self.began(itemView)
        }
        self.isActiveUpdated(true)
    }
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if self.numberOfTouches > 1 {
            self.isActiveUpdated(false)
            self.state = .failed
            self.ended()
            return
        }
        
        if self.state == .possible {
            if let location = touches.first?.location(in: self.view) {
                let (allowed, requiresLongPress, itemView) = self.shouldBegin(location)
                if allowed {
                    self.isActiveUpdated(true)
                    
                    self.itemView = itemView
                    self.initialLocation = location
                    if requiresLongPress {
                        self.startLongTapTimer()
                        self.startLongPressTimer()
                    } else {
                        self.state = .began
                        if let itemView = self.itemView {
                            self.began(itemView)
                        }
                    }
                } else {
                    self.isActiveUpdated(false)
                    self.state = .failed
                }
            } else {
                self.isActiveUpdated(false)
                self.state = .failed
            }
        }
    }
    
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        self.initialLocation = nil
        
        self.stopLongTapTimer()
        if self.longPressTimer != nil {
            self.stopLongPressTimer()
            self.isActiveUpdated(false)
            self.state = .failed
        }
        if self.state == .began || self.state == .changed {
            self.isActiveUpdated(false)
            self.ended()
            self.state = .failed
        }
    }
    
    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        self.initialLocation = nil
        
        self.stopLongTapTimer()
        if self.longPressTimer != nil {
            self.isActiveUpdated(false)
            self.stopLongPressTimer()
            self.state = .failed
        }
        if self.state == .began || self.state == .changed {
            self.isActiveUpdated(false)
            self.ended()
            self.state = .failed
        }
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        if (self.state == .began || self.state == .changed), let initialLocation = self.initialLocation, let location = touches.first?.location(in: self.view) {
            self.state = .changed
            let offset = CGPoint(x: location.x - initialLocation.x, y: location.y - initialLocation.y)
            self.moved(offset)
        } else if let touch = touches.first, let initialTapLocation = self.initialLocation, self.longPressTimer != nil {
            let touchLocation = touch.location(in: self.view)
            let dX = touchLocation.x - initialTapLocation.x
            let dY = touchLocation.y - initialTapLocation.y
            
            if dX * dX + dY * dY > 3.0 * 3.0 {
                self.stopLongTapTimer()
                self.stopLongPressTimer()
                self.initialLocation = nil
                self.isActiveUpdated(false)
                self.state = .failed
            }
        }
    }
}

private final class CollageContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = false
    let ignoreContentTouches: Bool = false
    let blurBackground: Bool = true
    
    private let contentView: ContextExtractedContentContainingView
    
    init(contentView: ContextExtractedContentContainingView) {
        self.contentView = contentView
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(containingItem: .view(self.contentView), contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
