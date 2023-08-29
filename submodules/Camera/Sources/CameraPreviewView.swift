import Foundation
import UIKit
import Display
import AVFoundation
import SwiftSignalKit
import Metal
import MetalKit
import CoreMedia
import Vision
import ImageBlur

private extension UIInterfaceOrientation {
   var videoOrientation: AVCaptureVideoOrientation {
       switch self {
       case .portraitUpsideDown: return .portraitUpsideDown
       case .landscapeRight: return .landscapeRight
       case .landscapeLeft: return .landscapeLeft
       case .portrait: return .portrait
       default: return .portrait
       }
   }
}

public class CameraSimplePreviewView: UIView {
    func updateOrientation() {
        guard self.videoPreviewLayer.connection?.isVideoOrientationSupported == true else {
            return
        }
        let statusBarOrientation: UIInterfaceOrientation
        if #available(iOS 13.0, *) {
            statusBarOrientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation ?? .portrait
        } else {
            statusBarOrientation = UIApplication.shared.statusBarOrientation
        }
        let videoOrientation = statusBarOrientation.videoOrientation
        self.videoPreviewLayer.connection?.videoOrientation = videoOrientation
        self.videoPreviewLayer.removeAllAnimations()
    }
    
    static func lastBackImage() -> UIImage {
        let imagePath = NSTemporaryDirectory() + "backCameraImage.jpg"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: imagePath)), let image = UIImage(data: data) {
            return image
        } else {
            return UIImage(bundleImageName: "Camera/Placeholder")!
        }
    }
    
    static func saveLastBackImage(_ image: UIImage) {
        let imagePath = NSTemporaryDirectory() + "backCameraImage.jpg"
        if let data = image.jpegData(compressionQuality: 0.6) {
            try? data.write(to: URL(fileURLWithPath: imagePath))
        }
    }
    
    static func lastFrontImage() -> UIImage {
        let imagePath = NSTemporaryDirectory() + "frontCameraImage.jpg"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: imagePath)), let image = UIImage(data: data) {
            return image
        } else {
            return UIImage(bundleImageName: "Camera/SelfiePlaceholder")!
        }
    }
    
    static func saveLastFrontImage(_ image: UIImage) {
        let imagePath = NSTemporaryDirectory() + "frontCameraImage.jpg"
        if let data = image.jpegData(compressionQuality: 0.6) {
            try? data.write(to: URL(fileURLWithPath: imagePath))
        }
    }
        
    private var previewingDisposable: Disposable?
    private let placeholderView = UIImageView()
    
    public init(frame: CGRect, main: Bool) {
        super.init(frame: frame)
        
        self.videoPreviewLayer.videoGravity = main ? .resizeAspectFill : .resizeAspect
        self.placeholderView.contentMode =  main ? .scaleAspectFill : .scaleAspectFit
        
        self.addSubview(self.placeholderView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.previewingDisposable?.dispose()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        self.updateOrientation()
        self.placeholderView.frame = self.bounds.insetBy(dx: -1.0, dy: -1.0)
    }
    
    public func removePlaceholder(delay: Double = 0.0) {
        UIView.animate(withDuration: 0.3, delay: delay) {
            self.placeholderView.alpha = 0.0
        }
    }
    
    public func resetPlaceholder(front: Bool) {
        self.placeholderView.image = front ? CameraSimplePreviewView.lastFrontImage() : CameraSimplePreviewView.lastBackImage()
        self.placeholderView.alpha = 1.0
    }
        
    private var _videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        if let layer = self._videoPreviewLayer {
            return layer
        }
        guard let layer = self.layer as? AVCaptureVideoPreviewLayer else {
            fatalError()
        }
        self._videoPreviewLayer = layer
        return layer
    }
    
    func invalidate() {
        self.videoPreviewLayer.session = nil
    }
    
    func setSession(_ session: AVCaptureSession, autoConnect: Bool) {
        if autoConnect {
            self.videoPreviewLayer.session = session
        } else {
            self.videoPreviewLayer.setSessionWithNoConnection(session)
        }
    }
    
    public var isEnabled: Bool = true {
        didSet {
            self.videoPreviewLayer.connection?.isEnabled = self.isEnabled
        }
    }
    
    public override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    @available(iOS 13.0, *)
    public var isPreviewing: Signal<Bool, NoError> {
        return Signal { [weak self] subscriber in
            guard let self else {
                return EmptyDisposable
            }
            subscriber.putNext(self.videoPreviewLayer.isPreviewing)
            let observer = self.videoPreviewLayer.observe(\.isPreviewing, options: [.new], changeHandler: { view, _ in
                subscriber.putNext(view.isPreviewing)
            })
            return ActionDisposable {
                observer.invalidate()
            }
        }
        |> distinctUntilChanged
    }
    
    public func cameraPoint(for location: CGPoint) -> CGPoint {
        return self.videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: location)
    }
}

public class CameraPreviewView: MTKView {
    private let queue = DispatchQueue(label: "CameraPreview", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    private let commandQueue: MTLCommandQueue
    private var textureCache: CVMetalTextureCache?
    private var sampler: MTLSamplerState!
    private var renderPipelineState: MTLRenderPipelineState!
    private var vertexCoordBuffer: MTLBuffer!
    private var texCoordBuffer: MTLBuffer!
    
    private var textureWidth: Int = 0
    private var textureHeight: Int = 0
    private var textureMirroring = false
    private var textureRotation: Rotation = .rotate0Degrees
    
    private var textureTranform: CGAffineTransform?
    private var _bounds = CGRectNull
    
    public enum Rotation: Int {
        case rotate0Degrees
        case rotate90Degrees
        case rotate180Degrees
        case rotate270Degrees
    }
    
    private var _mirroring: Bool?
    private var _scheduledMirroring: Bool?
    public var mirroring = false {
        didSet {
            self.queue.sync {
                if self._mirroring != nil {
                    self._scheduledMirroring = self.mirroring
                } else {
                    self._mirroring = self.mirroring
                }
            }
        }
    }
    
    private var _rotation: Rotation = .rotate0Degrees
    public var rotation: Rotation = .rotate0Degrees {
        didSet {
            self.queue.sync {
                self._rotation = rotation
            }
        }
    }
    
    private var _pixelBuffer: CVPixelBuffer?
    var pixelBuffer: CVPixelBuffer? {
        didSet {
            self.queue.sync {
                if let scheduledMirroring = self._scheduledMirroring {
                    self._scheduledMirroring = nil
                    self._mirroring = scheduledMirroring
                }
                self._pixelBuffer = pixelBuffer
            }
        }
    }
    
    public init?(test: Bool) {
        let mainBundle = Bundle(for: CameraPreviewView.self)
        
        guard let path = mainBundle.path(forResource: "CameraBundle", ofType: "bundle") else {
            return nil
        }
        
        guard let bundle = Bundle(path: path) else {
            return nil
        }
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            return nil
        }

        guard let defaultLibrary = try? device.makeDefaultLibrary(bundle: bundle) else {
            return nil
        }

        guard let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        self.commandQueue = commandQueue

        super.init(frame: .zero, device: device)
    
        self.colorPixelFormat = .bgra8Unorm
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.vertexFunction = defaultLibrary.makeFunction(name: "vertexPassThrough")
        pipelineDescriptor.fragmentFunction = defaultLibrary.makeFunction(name: "fragmentPassThrough")
        
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        self.sampler = device.makeSamplerState(descriptor: samplerDescriptor)
        
        do {
            self.renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("\(error)")
        }
        
        self.setupTextureCache()
    }
    
    required public init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupTextureCache() {
        var newTextureCache: CVMetalTextureCache?
        if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device!, nil, &newTextureCache) == kCVReturnSuccess {
            self.textureCache = newTextureCache
        } else {
            assertionFailure("Unable to allocate texture cache")
        }
    }
    
    private func setupTransform(width: Int, height: Int, rotation: Rotation, mirroring: Bool) {
        var scaleX: Float = 1.0
        var scaleY: Float = 1.0
        var resizeAspect: Float = 1.0
        
        self._bounds = self.bounds
        self.textureWidth = width
        self.textureHeight = height
        self.textureMirroring = mirroring
        self.textureRotation = rotation
        
        if self.textureWidth > 0 && self.textureHeight > 0 {
            switch self.textureRotation {
            case .rotate0Degrees, .rotate180Degrees:
                scaleX = Float(self._bounds.width / CGFloat(self.textureWidth))
                scaleY = Float(self._bounds.height / CGFloat(self.textureHeight))
                
            case .rotate90Degrees, .rotate270Degrees:
                scaleX = Float(self._bounds.width / CGFloat(self.textureHeight))
                scaleY = Float(self._bounds.height / CGFloat(self.textureWidth))
            }
        }
        resizeAspect = min(scaleX, scaleY)
        if scaleX < scaleY {
            scaleY = scaleX / scaleY
            scaleX = 1.0
        } else {
            scaleX = scaleY / scaleX
            scaleY = 1.0
        }
        
        if self.textureMirroring {
            scaleX *= -1.0
        }
        
        let vertexData: [Float] = [
            -scaleX, -scaleY, 0.0, 1.0,
            scaleX, -scaleY, 0.0, 1.0,
            -scaleX, scaleY, 0.0, 1.0,
            scaleX, scaleY, 0.0, 1.0
        ]
        self.vertexCoordBuffer = device!.makeBuffer(bytes: vertexData, length: vertexData.count * MemoryLayout<Float>.size, options: [])
        
        var texCoordBufferData: [Float]
        switch self.textureRotation {
        case .rotate0Degrees:
            texCoordBufferData = [
                0.0, 1.0,
                1.0, 1.0,
                0.0, 0.0,
                1.0, 0.0
            ]
        case .rotate180Degrees:
            texCoordBufferData = [
                1.0, 0.0,
                0.0, 0.0,
                1.0, 1.0,
                0.0, 1.0
            ]
        case .rotate90Degrees:
            texCoordBufferData = [
                1.0, 1.0,
                1.0, 0.0,
                0.0, 1.0,
                0.0, 0.0
            ]
        case .rotate270Degrees:
            texCoordBufferData = [
                0.0, 0.0,
                0.0, 1.0,
                1.0, 0.0,
                1.0, 1.0
            ]
        }
        self.texCoordBuffer = device?.makeBuffer(bytes: texCoordBufferData, length: texCoordBufferData.count * MemoryLayout<Float>.size, options: [])
        
        var transform = CGAffineTransform.identity
        if self.textureMirroring {
            transform = transform.concatenating(CGAffineTransform(scaleX: -1, y: 1))
            transform = transform.concatenating(CGAffineTransform(translationX: CGFloat(self.textureWidth), y: 0))
        }
        
        switch self.textureRotation {
        case .rotate0Degrees:
            transform = transform.concatenating(CGAffineTransform(rotationAngle: CGFloat(0)))
        case .rotate180Degrees:
            transform = transform.concatenating(CGAffineTransform(rotationAngle: CGFloat(Double.pi)))
            transform = transform.concatenating(CGAffineTransform(translationX: CGFloat(self.textureWidth), y: CGFloat(self.textureHeight)))
        case .rotate90Degrees:
            transform = transform.concatenating(CGAffineTransform(rotationAngle: CGFloat(Double.pi) / 2))
            transform = transform.concatenating(CGAffineTransform(translationX: CGFloat(self.textureHeight), y: 0))
        case .rotate270Degrees:
            transform = transform.concatenating(CGAffineTransform(rotationAngle: 3 * CGFloat(Double.pi) / 2))
            transform = transform.concatenating(CGAffineTransform(translationX: 0, y: CGFloat(self.textureWidth)))
        }
        transform = transform.concatenating(CGAffineTransform(scaleX: CGFloat(resizeAspect), y: CGFloat(resizeAspect)))
        
        let tranformRect = CGRect(origin: .zero, size: CGSize(width: self.textureWidth, height: self.textureHeight)).applying(transform)
        let xShift = (self._bounds.size.width - tranformRect.size.width) / 2
        let yShift = (self._bounds.size.height - tranformRect.size.height) / 2
        transform = transform.concatenating(CGAffineTransform(translationX: xShift, y: yShift))
        
        self.textureTranform = transform.inverted()
    }
    
    public override func draw(_ rect: CGRect) {
        var pixelBuffer: CVPixelBuffer?
        var mirroring = false
        var rotation: Rotation = .rotate0Degrees
        
        self.queue.sync {
            pixelBuffer = self._pixelBuffer
            if let mirroringValue = self._mirroring {
                mirroring = mirroringValue
            }
            rotation = self._rotation
        }
        
        guard let drawable = currentDrawable, let currentRenderPassDescriptor = currentRenderPassDescriptor, let previewPixelBuffer = pixelBuffer else {
            return
        }
        
        let width = CVPixelBufferGetWidth(previewPixelBuffer)
        let height = CVPixelBufferGetHeight(previewPixelBuffer)
        
        if self.textureCache == nil {
            self.setupTextureCache()
        }
        var cvTextureOut: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache!,
            previewPixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTextureOut)
        guard let cvTexture = cvTextureOut, let texture = CVMetalTextureGetTexture(cvTexture) else {
            CVMetalTextureCacheFlush(self.textureCache!, 0)
            return
        }
        
        if texture.width != self.textureWidth ||
            texture.height != self.textureHeight ||
            self.bounds != self._bounds ||
            rotation != self.textureRotation ||
            mirroring != self.textureMirroring {
            self.setupTransform(width: texture.width, height: texture.height, rotation: rotation, mirroring: mirroring)
        }
        
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            CVMetalTextureCacheFlush(self.textureCache!, 0)
            return
        }
        
        guard let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor) else {
            CVMetalTextureCacheFlush(self.textureCache!, 0)
            return
        }
        
        commandEncoder.setRenderPipelineState(self.renderPipelineState!)
        commandEncoder.setVertexBuffer(self.vertexCoordBuffer, offset: 0, index: 0)
        commandEncoder.setVertexBuffer(self.texCoordBuffer, offset: 0, index: 1)
        commandEncoder.setFragmentTexture(texture, index: 0)
        commandEncoder.setFragmentSamplerState(self.sampler, index: 0)
        commandEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        commandEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    
    var captureDeviceResolution: CGSize = CGSize() {
        didSet {
            if oldValue.width.isZero, !self.captureDeviceResolution.width.isZero {
                Queue.mainQueue().async {
                    self.setupVisionDrawingLayers()
                }
            }
        }
    }
    var detectionOverlayLayer: CALayer?
    var detectedFaceRectangleShapeLayer: CAShapeLayer?
    var detectedFaceLandmarksShapeLayer: CAShapeLayer?
    
    func drawFaceObservations(_ faceObservations: [VNFaceObservation]) {
        guard let faceRectangleShapeLayer = self.detectedFaceRectangleShapeLayer,
            let faceLandmarksShapeLayer = self.detectedFaceLandmarksShapeLayer
            else {
            return
        }
        
        CATransaction.begin()
        
        CATransaction.setValue(NSNumber(value: true), forKey: kCATransactionDisableActions)
        
        self.detectionOverlayLayer?.isHidden = faceObservations.isEmpty
        
        let faceRectanglePath = CGMutablePath()
        let faceLandmarksPath = CGMutablePath()
        
        for faceObservation in faceObservations {
            self.addIndicators(to: faceRectanglePath,
                               faceLandmarksPath: faceLandmarksPath,
                               for: faceObservation)
        }
        
        faceRectangleShapeLayer.path = faceRectanglePath
        faceLandmarksShapeLayer.path = faceLandmarksPath
        
        self.updateLayerGeometry()
        
        CATransaction.commit()
    }
    
    fileprivate func addPoints(in landmarkRegion: VNFaceLandmarkRegion2D, to path: CGMutablePath, applying affineTransform: CGAffineTransform, closingWhenComplete closePath: Bool) {
        let pointCount = landmarkRegion.pointCount
        if pointCount > 1 {
            let points: [CGPoint] = landmarkRegion.normalizedPoints
            path.move(to: points[0], transform: affineTransform)
            path.addLines(between: points, transform: affineTransform)
            if closePath {
                path.addLine(to: points[0], transform: affineTransform)
                path.closeSubpath()
            }
        }
    }
    
    fileprivate func addIndicators(to faceRectanglePath: CGMutablePath, faceLandmarksPath: CGMutablePath, for faceObservation: VNFaceObservation) {
        let displaySize = self.captureDeviceResolution
        
        let faceBounds = VNImageRectForNormalizedRect(faceObservation.boundingBox, Int(displaySize.width), Int(displaySize.height))
        faceRectanglePath.addRect(faceBounds)
        
        if let landmarks = faceObservation.landmarks {
            let affineTransform = CGAffineTransform(translationX: faceBounds.origin.x, y: faceBounds.origin.y)
                .scaledBy(x: faceBounds.size.width, y: faceBounds.size.height)
            
            let openLandmarkRegions: [VNFaceLandmarkRegion2D?] = [
                landmarks.leftEyebrow,
                landmarks.rightEyebrow,
                landmarks.faceContour,
                landmarks.noseCrest,
                landmarks.medianLine
            ]
            for openLandmarkRegion in openLandmarkRegions where openLandmarkRegion != nil {
                self.addPoints(in: openLandmarkRegion!, to: faceLandmarksPath, applying: affineTransform, closingWhenComplete: false)
            }
            
            let closedLandmarkRegions: [VNFaceLandmarkRegion2D?] = [
                landmarks.leftEye,
                landmarks.rightEye,
                landmarks.outerLips,
                landmarks.innerLips,
                landmarks.nose
            ]
            for closedLandmarkRegion in closedLandmarkRegions where closedLandmarkRegion != nil {
                self.addPoints(in: closedLandmarkRegion!, to: faceLandmarksPath, applying: affineTransform, closingWhenComplete: true)
            }
        }
    }
    
    fileprivate func radiansForDegrees(_ degrees: CGFloat) -> CGFloat {
        return CGFloat(Double(degrees) * Double.pi / 180.0)
    }
    
    fileprivate func updateLayerGeometry() {
        guard let overlayLayer = self.detectionOverlayLayer else {
            return
        }
        
        CATransaction.setValue(NSNumber(value: true), forKey: kCATransactionDisableActions)
        
        let videoPreviewRect = self.bounds
        
        var rotation: CGFloat
        var scaleX: CGFloat
        var scaleY: CGFloat
        
        // Rotate the layer into screen orientation.
        switch UIDevice.current.orientation {
        case .portraitUpsideDown:
            rotation = 180
            scaleX = videoPreviewRect.width / captureDeviceResolution.width
            scaleY = videoPreviewRect.height / captureDeviceResolution.height
            
        case .landscapeLeft:
            rotation = 90
            scaleX = videoPreviewRect.height / captureDeviceResolution.width
            scaleY = scaleX
            
        case .landscapeRight:
            rotation = -90
            scaleX = videoPreviewRect.height / captureDeviceResolution.width
            scaleY = scaleX
            
        default:
            rotation = 0
            scaleX = videoPreviewRect.width / captureDeviceResolution.width
            scaleY = videoPreviewRect.height / captureDeviceResolution.height
        }
        
        // Scale and mirror the image to ensure upright presentation.
        let affineTransform = CGAffineTransform(rotationAngle: radiansForDegrees(rotation))
            .scaledBy(x: scaleX, y: -scaleY)
        overlayLayer.setAffineTransform(affineTransform)
        
        // Cover entire screen UI.
        let rootLayerBounds = self.bounds
        overlayLayer.position = CGPoint(x: rootLayerBounds.midX, y: rootLayerBounds.midY)
    }
    
    fileprivate func setupVisionDrawingLayers() {
        let captureDeviceResolution = self.captureDeviceResolution
        let rootLayer = self.layer
        
        let captureDeviceBounds = CGRect(x: 0,
                                         y: 0,
                                         width: captureDeviceResolution.width,
                                         height: captureDeviceResolution.height)
        
        let captureDeviceBoundsCenterPoint = CGPoint(x: captureDeviceBounds.midX,
                                                     y: captureDeviceBounds.midY)
        
        let normalizedCenterPoint = CGPoint(x: 0.5, y: 0.5)
        
        let overlayLayer = CALayer()
        overlayLayer.name = "DetectionOverlay"
        overlayLayer.masksToBounds = true
        overlayLayer.anchorPoint = normalizedCenterPoint
        overlayLayer.bounds = captureDeviceBounds
        overlayLayer.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        
        let faceRectangleShapeLayer = CAShapeLayer()
        faceRectangleShapeLayer.name = "RectangleOutlineLayer"
        faceRectangleShapeLayer.bounds = captureDeviceBounds
        faceRectangleShapeLayer.anchorPoint = normalizedCenterPoint
        faceRectangleShapeLayer.position = captureDeviceBoundsCenterPoint
        faceRectangleShapeLayer.fillColor = nil
        faceRectangleShapeLayer.strokeColor = UIColor.green.withAlphaComponent(0.2).cgColor
        faceRectangleShapeLayer.lineWidth = 2
        
        let faceLandmarksShapeLayer = CAShapeLayer()
        faceLandmarksShapeLayer.name = "FaceLandmarksLayer"
        faceLandmarksShapeLayer.bounds = captureDeviceBounds
        faceLandmarksShapeLayer.anchorPoint = normalizedCenterPoint
        faceLandmarksShapeLayer.position = captureDeviceBoundsCenterPoint
        faceLandmarksShapeLayer.fillColor = nil
        faceLandmarksShapeLayer.strokeColor = UIColor.white.withAlphaComponent(0.7).cgColor
        faceLandmarksShapeLayer.lineWidth = 2
        faceLandmarksShapeLayer.shadowOpacity = 0.7
        faceLandmarksShapeLayer.shadowRadius = 2
        
        overlayLayer.addSublayer(faceRectangleShapeLayer)
        faceRectangleShapeLayer.addSublayer(faceLandmarksShapeLayer)
        self.layer.addSublayer(overlayLayer)
        
        self.detectionOverlayLayer = overlayLayer
        self.detectedFaceRectangleShapeLayer = faceRectangleShapeLayer
        self.detectedFaceLandmarksShapeLayer = faceLandmarksShapeLayer
        
        self.updateLayerGeometry()
    }

}
