import Foundation
import UIKit
import AccountContext
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Camera
import CoreImage
import TelegramPresentationData
import TelegramCore
import Markdown
import TextFormat
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import Vision
import AVFoundation
import AppBundle
import ZipArchive
import PlainButtonComponent
import MultilineTextComponent

final class FaceScanScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let availability: Signal<AgeVerificationAvailability, NoError>
    
    init(
        context: AccountContext,
        availability: Signal<AgeVerificationAvailability, NoError>
    ) {
        self.context = context
        self.availability = availability
    }

    static func ==(lhs: FaceScanScreenComponent, rhs: FaceScanScreenComponent) -> Bool {
        return true
    }
    
    final class View: UIView, AVCaptureVideoDataOutputSampleBufferDelegate {
        private let captureSession = AVCaptureSession()
        private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
        private let videoDataOutput = AVCaptureVideoDataOutput()
        private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
        private var faceDetectionRequest: VNDetectFaceRectanglesRequest!
        
        private let overlayView = UIView()
        private let cutoutLayer = CAShapeLayer()
        private let frameView = FrameView()
        
        private let numberOfStripes = 16
        private var completedAngles: Set<Int> = []
        
        private let instruction = ComponentView<Empty>()
        private let cancel = ComponentView<Empty>()
                
        private var currentFaceImage: CIImage?
        
        private enum State {
            case waitingForFace
            case positioning
            case readyToStart
            case tracking
            case completed
        }
        private var processState: State = .waitingForFace
        private var transitioningToViewFinder = false
        
        private var lastFaceYaw: NSNumber?
        private var lastFacePitch: NSNumber?
        private var lastFaceRoll: NSNumber?
        private var centerYaw: Double = 0
        private var centerPitch: Double = 0
        private var centerRoll: Double = 0
        private let motionThreshold: Double = 0.07
        
        private var faceDetectionTimer: Foundation.Timer?
        private var segmentTimer: Foundation.Timer?
        private var currentSegment: Int?
        private let segmentDwellTime: TimeInterval = 0.05
        private let positioningTime: TimeInterval = 1.0
        
        private var horizontalGuideLines: [CAShapeLayer] = []
        private var verticalGuideLines: [CAShapeLayer] = []
        private let maxGuideLines = 30
        private let guideLineFadeDuration: TimeInterval = 0.3
        private var lastGuideLineUpdate: Date = Date()
        private let guideLineUpdateInterval: TimeInterval = 0.01
        private var lastGuideLineYaw: Double = 0
        private var lastGuideLinePitch: Double = 0
        private let angleThreshold: Double = 0.01
        
        private var ageModel: VNCoreMLModel?
        private var ages: [Double] = []
        
        private var availabilityDisposable: Disposable?
        
        private var isUpdating: Bool = false
        
        private var component: FaceScanScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.backgroundColor = .black
            
            //self.previewLayer.backgroundColor = UIColor.red.cgColor
            self.previewLayer.videoGravity = .resizeAspectFill
            self.layer.addSublayer(previewLayer)
            
            self.overlayView.backgroundColor = UIColor.black
            self.addSubview(overlayView)
            
            self.cutoutLayer.fillRule = .evenOdd
            self.overlayView.layer.mask = self.cutoutLayer
            
            self.addSubview(self.frameView)
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        deinit {
            self.availabilityDisposable?.dispose()
        }
        
        private func setupModel(availability: Signal<AgeVerificationAvailability, NoError>) {
            self.availabilityDisposable = (availability
            |> deliverOnMainQueue).start(next: { [weak self] availability in
                guard let self else {
                    return
                }
                if case let .available(path, isLegacy) = availability {
                    if isLegacy {
                        if let model = try? AgeNetLegacy(contentsOf: URL(fileURLWithPath: path)).model {
                            self.ageModel = try? VNCoreMLModel(for: model)
                        }
                    } else if #available(iOS 15.0, *) {
                        if let model = try? AgeNet(contentsOf: URL(fileURLWithPath: path)).model {
                            self.ageModel = try? VNCoreMLModel(for: model)
                        }
                    }
                }
            })
        }
        
        private func extractFaceImage(from pixelBuffer: CVPixelBuffer, faceObservation: VNFaceObservation) -> CIImage? {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let imageSize = ciImage.extent.size
            let visionRect = faceObservation.boundingBox
            
            let boundingBox = CGRect(x: 1.0 - visionRect.maxY, y: 1.0 - visionRect.maxX, width: visionRect.height, height: visionRect.width)
            let faceRect = CGRect(
                x: boundingBox.minX * imageSize.width,
                y: boundingBox.minY * imageSize.height,
                width: boundingBox.width * imageSize.width,
                height: boundingBox.height * imageSize.height
            )
            
            let padding: CGFloat = 0.1
            let paddingX = faceRect.width * padding
            let paddingY = faceRect.height * padding
            
            let paddedRect = CGRect(
                x: max(0, faceRect.minX - paddingX),
                y: max(0, faceRect.minY - paddingY),
                width: min(imageSize.width - max(0, faceRect.minX - paddingX), faceRect.width + 2 * paddingX),
                height: min(imageSize.height - max(0, faceRect.minY - paddingY), faceRect.height + 2 * paddingY)
            )
            
            let croppedImage = ciImage.cropped(to: paddedRect)
            let rotatedImage = croppedImage.oriented(.leftMirrored)
                        
            return rotatedImage
        }
        
        private func setupCamera() {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
                return
            }
            
            do {
                let input = try AVCaptureDeviceInput(device: device)
                
                self.captureSession.beginConfiguration()
                self.captureSession.sessionPreset = .high
                
                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                }
                
                if self.captureSession.canAddOutput(self.videoDataOutput) {
                    self.captureSession.addOutput(self.videoDataOutput)
                    self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
                    self.videoDataOutput.setSampleBufferDelegate(self, queue: self.videoDataOutputQueue)
                }
                
                self.captureSession.commitConfiguration()
            } catch {
                print("Failed to setup camera: \(error)")
            }
            
            Queue.concurrentDefaultQueue().async {
                self.captureSession.startRunning()
            }
        }
        
        private func setupVision() {
            self.faceDetectionRequest = VNDetectFaceRectanglesRequest { [weak self] request, error in
                guard error == nil else { return }
                Queue.mainQueue().async {
                    self?.handleFaceDetection(request)
                }
            }
        }

        private func handleFaceDetection(_ request: VNRequest) {
            guard #available(iOS 15.0, *) else {
                return
            }
            guard let observations = request.results as? [VNFaceObservation], let face = observations.first else {
                if self.processState == .tracking || self.processState == .readyToStart {
                    self.resetTracking()
                }
                self.currentFaceImage = nil
                return
            }
                        
            guard let yaw = face.yaw,
                  let pitch = face.pitch,
                  let roll = face.roll else { return }
            
            let faceCenter = CGPoint(x: face.boundingBox.midX, y: face.boundingBox.midY)
            let targetCenter = CGPoint(x: 0.5, y: 0.5)
            let distance = sqrt(pow(faceCenter.x - targetCenter.x, 2) + pow(faceCenter.y - targetCenter.y, 2))
            
            if distance < 0.24 {
                switch processState {
                case .waitingForFace:
                    self.processState = .positioning
                    self.faceDetectionTimer = Timer.scheduledTimer(withTimeInterval: self.positioningTime, repeats: false) { [weak self] _ in
                        self?.processState = .readyToStart
                        
                        self?.state?.updated(transition: .spring(duration: 0.3))
                    }
                case .positioning:
                    break
                case .readyToStart:
                    self.centerYaw = yaw.doubleValue
                    self.centerPitch = pitch.doubleValue
                    self.centerRoll = roll.doubleValue
                    self.processState = .tracking
                case .tracking:
                    self.trackHeadOrientation(yaw: yaw, pitch: pitch, roll: roll)
                case .completed:
                    break
                }
            } else if self.processState == .tracking {
                self.resetTracking()
            }
        }
        
        private func trackHeadOrientation(yaw: NSNumber, pitch: NSNumber, roll: NSNumber) {
            let relativeYaw = yaw.doubleValue - self.centerYaw
            let relativePitch = pitch.doubleValue - self.centerPitch
            
            //self.updateTrailingGuideLines(yaw: relativeYaw, pitch: relativePitch)
                        
            if let lastYaw = self.lastFaceYaw, let lastPitch = self.lastFacePitch {
                let yawChange = abs(yaw.doubleValue - lastYaw.doubleValue)
                let pitchChange = abs(pitch.doubleValue - lastPitch.doubleValue)
                
                if yawChange < 0.02 && pitchChange < 0.02 {
                    return
                }
            }
                
            let mirroredYaw = -relativeYaw
            let flippedPitch = relativePitch
            
            let angle = atan2(mirroredYaw, flippedPitch) + .pi
            let normalizedAngle = angle / (2 * .pi)
            let segmentIndex = Int(normalizedAngle * Double(self.numberOfStripes)) % self.numberOfStripes
            
            let rotationMagnitude = sqrt(relativeYaw * relativeYaw + relativePitch * relativePitch)
            if rotationMagnitude > self.motionThreshold {
                if self.currentSegment != segmentIndex {
                    self.currentSegment = segmentIndex
                                        
                    self.segmentTimer?.invalidate()
                    self.segmentTimer = Timer.scheduledTimer(withTimeInterval: self.segmentDwellTime, repeats: false) { _ in
                        self.fillSegment(segmentIndex)
                    }
                }
            }
            
            self.lastFaceYaw = yaw
            self.lastFacePitch = pitch
            self.lastFaceRoll = roll
        }
        
        private func fillSegment(_ segmentIndex: Int) {
            guard !self.completedAngles.contains(segmentIndex) else {
                return
            }
            self.completedAngles.insert(segmentIndex)
            
            if self.completedAngles.count >= self.numberOfStripes {
                Queue.mainQueue().after(0.3, {
                    self.processState = .completed
                    self.state?.updated(transition: .spring(duration: 0.3))
                    
                    Queue.mainQueue().after(1.0) {
                        if !self.ages.isEmpty {
                            let averageAge = self.ages.reduce(0, +) / Double(self.ages.count)
                            if let environment = self.environment, let controller = environment.controller() as? FaceScanScreen {
                                controller.completion(Int(averageAge))
                                controller.dismiss(animated: true)
                            }
                        } else {
                            self.completedAngles.removeAll()
                            self.processState = .tracking
                            self.state?.updated(transition: .spring(duration: 0.3))
                        }
                    }
                })
            }
            self.state?.updated(transition: .spring(duration: 0.3))
        }
        
        private func resetTracking() {
            self.faceDetectionTimer?.invalidate()
            self.segmentTimer?.invalidate()
            
            if self.processState != .waitingForFace && self.processState != .positioning {
                self.transitioningToViewFinder = true
            }
            self.processState = .waitingForFace
            self.completedAngles.removeAll()
            self.currentSegment = nil
            self.lastFaceYaw = nil
            self.lastFacePitch = nil
            self.lastFaceRoll = nil
            
            self.currentFaceImage = nil
            
            self.state?.updated(transition: .spring(duration: 0.3))
        }
        
        private var tick = 0
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored)
            do {
                try requestHandler.perform([self.faceDetectionRequest])
                
                if let observations = self.faceDetectionRequest.results, let faceObservation = observations.first {
                    tick += 1
                    if tick < 33 {
                        return
                    }
                    tick = 0
                    
                    self.currentFaceImage = self.extractFaceImage(from: pixelBuffer, faceObservation: faceObservation)
                    self.processFace()
                }
            } catch {
                print("Failed to perform request: \(error)")
            }
        }
                
        public func processFace() {
            guard let faceImage = self.currentFaceImage else {
                return
            }
            
            guard let model = self.ageModel else {
                return
            }
            
            let request = VNCoreMLRequest(model: model) { [weak self] request, error in
                if let results =  request.results as? [VNCoreMLFeatureValueObservation], let ageObservation = results.last {
                    let age = ageObservation.featureValue.multiArrayValue?[0].doubleValue ?? 0
                    
                    Queue.mainQueue().async {
                        self?.ages.append(age)
                    }
                }
            }
            
            let handler = VNImageRequestHandler(ciImage: faceImage)
            DispatchQueue.global(qos: .userInteractive).async {
                do {
                    try handler.perform([request])
                } catch {
                    print(error)
                }
            }
        }
        
        func update(component: FaceScanScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            if self.component == nil {
                self.setupModel(availability: component.availability)
                self.setupCamera()
                self.setupVision()
            }
            
            self.component = component
            self.state = state
            let environment = environment[EnvironmentType.self].value
            self.environment = environment
            
            let theme = environment.theme
            let strings = environment.strings
            
            self.overlayView.frame = CGRect(origin: .zero, size: availableSize)
            self.cutoutLayer.frame = CGRect(origin: .zero, size: availableSize)
            
            let path = CGMutablePath(rect: overlayView.bounds, transform: nil)
            let radius: CGFloat = 130.0
            
            let widthRadius = ceil(radius * 1.05)
            let heightRadius = widthRadius //radius //floor(widthRadius * 1.17778)
            
            let center = CGPoint(x: availableSize.width / 2, y: environment.statusBarHeight + 10.0 + widthRadius * 1.3)
            
            var previewScale = 0.85
            if self.processState == .tracking || self.processState == .readyToStart || self.processState == .completed || self.transitioningToViewFinder {
                let circlePath = CGPath(roundedRect: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2), cornerWidth: radius, cornerHeight: radius, transform: nil)
                path.addPath(circlePath)
                
                previewScale = 0.75
            } else {
                let rectanglePath = CGPath(roundedRect: CGRect(x: center.x - widthRadius, y: center.y - heightRadius, width: widthRadius * 2, height: heightRadius * 2), cornerWidth: 20, cornerHeight: 20, transform: nil)
                path.addPath(rectanglePath)
            }
            transition.setShapeLayerPath(layer: self.cutoutLayer, path: path)
            
            self.previewLayer.bounds = CGRect(origin: .zero, size: availableSize)
            self.previewLayer.position = CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0 - 200)
            transition.setTransform(layer: self.previewLayer, transform: CATransform3DMakeScale(previewScale, previewScale, 1.0))
            
            let frameViewSize = CGSize(width: 330.0, height: 330.0)
            let frameViewFrame = CGRect(x: (availableSize.width - frameViewSize.width) / 2.0, y: center.y - frameViewSize.height * 0.5, width: frameViewSize.width, height: frameViewSize.height)
            self.frameView.frame = frameViewFrame
            self.frameView.update(size: frameViewFrame.size)
            
            var instructionString = environment.strings.FaceScan_Instruction_Position
            switch self.processState {
            case .waitingForFace, .positioning:
                self.frameView.update(state: .viewFinder, intermediateCompletion: { [weak self] in
                    if let self {
                        self.transitioningToViewFinder = false
                        self.state?.updated(transition: .spring(duration: 0.3))
                    }
                }, transition: .spring(duration: 0.3))
                instructionString = environment.strings.FaceScan_Instruction_Position
            case .readyToStart:
                self.frameView.update(state: .segments(Set()), transition: .spring(duration: 0.3))
                instructionString = environment.strings.FaceScan_Instruction_Rotate
            case .tracking:
                self.frameView.update(state: .segments(self.completedAngles), transition: .spring(duration: 0.3))
                instructionString = environment.strings.FaceScan_Instruction_Rotate
            case .completed:
                self.frameView.update(state: .success, transition: .spring(duration: 0.3))
                instructionString = ""
            }
            
            let instructionSize = self.instruction.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: instructionString, font: Font.semibold(20.0), textColor: .white)),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 3,
                        lineSpacing: 0.1
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            let instructionFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - instructionSize.width) / 2.0), y: 484.0), size: instructionSize)
            if let instructionView = self.instruction.view {
                if instructionView.superview == nil {
                    self.addSubview(instructionView)
                }
                instructionView.frame = instructionFrame
            }
            
            let cancelSize = self.cancel.update(
                transition: .immediate,
                component: AnyComponent(
                    PlainButtonComponent(
                        content: AnyComponent(
                            MultilineTextComponent(
                                text: .plain(NSAttributedString(string: strings.Common_Cancel, font: Font.regular(17.0), textColor: theme.list.itemAccentColor))
                            )
                        ),
                        action: { [weak self] in
                            guard let self, let environment = self.environment, let controller = environment.controller() as? FaceScanScreen else {
                                return
                            }
                            controller.dismiss(animated: true)
                        },
                        animateScale: false
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            let cancelFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - cancelSize.width) / 2.0), y: availableSize.height - cancelSize.height - environment.safeInsets.bottom - 22.0), size: cancelSize)
            if let cancelView = self.cancel.view {
                if cancelView.superview == nil {
                    self.addSubview(cancelView)
                }
                cancelView.frame = cancelFrame
                transition.setAlpha(view: cancelView, alpha: self.processState == .completed ? 0.0 : 1.0)
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View()
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class FaceScanScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    fileprivate let completion: (Int) -> Void
    
    public init(
        context: AccountContext,
        availability: Signal<AgeVerificationAvailability, NoError>,
        completion: @escaping (Int) -> Void
    ) {
        self.context = context
        self.completion = completion
        
        super.init(context: context, component: FaceScanScreenComponent(
            context: context,
            availability: availability
        ), navigationBarAppearance: .none, theme: .default, updatedPresentationData: nil)
        
        self.title = ""
        
        self.statusBar.statusBarStyle = .White
        self.navigationPresentation = .standaloneFlatModal
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.animateIn()
    }
    
    private func animateIn() {
        guard let layout = self.validLayout else {
            return
        }
        self.view.clipsToBounds = true
        self.view.layer.cornerRadius = layout.deviceMetrics.screenCornerRadius
        
        self.view.layer.animatePosition(from: CGPoint(x: self.view.layer.position.x, y: self.view.layer.position.y + self.view.layer.bounds.size.height), to: self.view.layer.position, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, completion: { _ in
            self.view.clipsToBounds = false
        })
    }
    
    private func animateOut(completion: (() -> Void)? = nil) {
        guard let layout = self.validLayout else {
            return
        }
        self.view.clipsToBounds = true
        self.view.layer.cornerRadius = layout.deviceMetrics.screenCornerRadius
        
        self.view.layer.animatePosition(from: self.view.layer.position, to: CGPoint(x: self.view.layer.position.x, y: self.view.layer.position.y + self.view.layer.bounds.size.height), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { _ in
            completion?()
        })
    }
    
    public override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        if flag {
            self.animateOut(completion: {
                super.dismiss(animated: false, completion: completion)
            })
        } else {
            super.dismiss(animated: flag, completion: completion)
        }
    }
}

extension FaceScanScreenComponent.View {
    private func updateTrailingGuideLines(yaw: Double, pitch: Double) {
        let now = Date()
        
        guard now.timeIntervalSince(lastGuideLineUpdate) >= guideLineUpdateInterval else {
            return
        }
        self.lastGuideLineUpdate = now
        
        let radius: CGFloat = 128.0
        let center = CGPoint(x: self.bounds.width / 2, y: self.frameView.center.y)
        
        let maxRotation: Double = 0.5
        let normalizedYaw = min(max(yaw / maxRotation, -1.0), 1.0) * 1.5
        let normalizedPitch = min(max(pitch / maxRotation, -1.0), 1.0) * 1.5
        
        let yawChange = abs(yaw - lastGuideLineYaw)
        let pitchChange = abs(pitch - lastGuideLinePitch)
        
        let rotationMagnitude = sqrt(yaw * yaw + pitch * pitch)
        if rotationMagnitude > 0.01 && (yawChange > angleThreshold || pitchChange > angleThreshold) {
            if abs(pitch) > 0.01 {
                createHorizontalGuideLine(center: center, radius: radius, curvature: normalizedPitch)
            }
            
            if abs(yaw) > 0.01 {
                createVerticalGuideLine(center: center, radius: radius, curvature: normalizedYaw)
            }
            
            lastGuideLineYaw = yaw
            lastGuideLinePitch = pitch
        }
        
        cleanupOldGuideLines()
    }
    
    private func createHorizontalGuideLine(center: CGPoint, radius: CGFloat, curvature: Double) {
        let lineLayer = CAShapeLayer()
        let path = createCurvedHorizontalPath(center: center, radius: radius, curvature: curvature)
        
        lineLayer.path = path.cgPath
        lineLayer.strokeColor = UIColor(rgb: 0xb4f5ff).cgColor
        lineLayer.lineWidth = 3.0
        lineLayer.fillColor = UIColor.clear.cgColor
        lineLayer.lineCap = .round
        lineLayer.opacity = 0.3
        
        lineLayer.shadowColor = UIColor(rgb: 0xb4f5ff).cgColor
        lineLayer.shadowRadius = 2
        lineLayer.shadowOpacity = 0.5
        lineLayer.shadowOffset = .zero
        
        self.layer.addSublayer(lineLayer)
        horizontalGuideLines.append(lineLayer)
        
        animateLinefadeOut(lineLayer)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + guideLineFadeDuration + 0.1) { [weak self] in
            if let index = self?.horizontalGuideLines.firstIndex(of: lineLayer) {
                self?.horizontalGuideLines.remove(at: index)
            }
            lineLayer.removeFromSuperlayer()
        }
    }
    
    private func createVerticalGuideLine(center: CGPoint, radius: CGFloat, curvature: Double) {
        let lineLayer = CAShapeLayer()
        let path = createCurvedVerticalPath(center: center, radius: radius, curvature: curvature)
        
        lineLayer.path = path.cgPath
        lineLayer.strokeColor = UIColor(rgb: 0xb4f5ff).cgColor
        lineLayer.lineWidth = 3.0
        lineLayer.fillColor = UIColor.clear.cgColor
        lineLayer.lineCap = .round
        lineLayer.opacity = 0.3
        
        lineLayer.shadowColor = UIColor(rgb: 0xb4f5ff).cgColor
        lineLayer.shadowRadius = 2
        lineLayer.shadowOpacity = 0.5
        lineLayer.shadowOffset = .zero
        
        self.layer.addSublayer(lineLayer)
        verticalGuideLines.append(lineLayer)
        
        animateLinefadeOut(lineLayer)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + guideLineFadeDuration + 0.1) { [weak self] in
            if let index = self?.verticalGuideLines.firstIndex(of: lineLayer) {
                self?.verticalGuideLines.remove(at: index)
            }
            lineLayer.removeFromSuperlayer()
        }
    }
    
    private func createCurvedHorizontalPath(center: CGPoint, radius: CGFloat, curvature: Double) -> UIBezierPath {
        let path = UIBezierPath()
        
        let startPoint = CGPoint(x: center.x - radius, y: center.y)
        let endPoint = CGPoint(x: center.x + radius, y: center.y)
        
        if abs(curvature) < 0.05 {
            path.move(to: startPoint)
            path.addLine(to: endPoint)
        } else {
            let curveOffset = CGFloat(curvature) * radius * 0.6
            let controlPoint = CGPoint(x: center.x, y: center.y + curveOffset)
            
            path.move(to: startPoint)
            path.addQuadCurve(to: endPoint, controlPoint: controlPoint)
        }
        
        return path
    }
    
    private func createCurvedVerticalPath(center: CGPoint, radius: CGFloat, curvature: Double) -> UIBezierPath {
        let path = UIBezierPath()
        
        let startPoint = CGPoint(x: center.x, y: center.y - radius)
        let endPoint = CGPoint(x: center.x, y: center.y + radius)
        
        if abs(curvature) < 0.05 {
            path.move(to: startPoint)
            path.addLine(to: endPoint)
        } else {
            let curveOffset = CGFloat(curvature) * radius * 0.6
            let controlPoint = CGPoint(x: center.x + curveOffset, y: center.y)
            
            path.move(to: startPoint)
            path.addQuadCurve(to: endPoint, controlPoint: controlPoint)
        }
        
        return path
    }
    
    private func animateLinefadeOut(_ layer: CAShapeLayer) {
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 0.5
        opacityAnimation.toValue = 0.0
        opacityAnimation.duration = guideLineFadeDuration
        opacityAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        opacityAnimation.fillMode = .forwards
        opacityAnimation.isRemovedOnCompletion = false
        
        let shadowAnimation = CABasicAnimation(keyPath: "shadowOpacity")
        shadowAnimation.fromValue = 0.5
        shadowAnimation.toValue = 0.0
        shadowAnimation.duration = guideLineFadeDuration
        shadowAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        shadowAnimation.fillMode = .forwards
        shadowAnimation.isRemovedOnCompletion = false
        
        layer.add(opacityAnimation, forKey: "fadeOut")
        layer.add(shadowAnimation, forKey: "shadowFadeOut")
    }

    private func cleanupOldGuideLines() {
        while horizontalGuideLines.count > maxGuideLines {
            let oldestLine = horizontalGuideLines.removeFirst()
            oldestLine.removeFromSuperlayer()
        }
        
        while verticalGuideLines.count > maxGuideLines {
            let oldestLine = verticalGuideLines.removeFirst()
            oldestLine.removeFromSuperlayer()
        }
    }

    private func clearAllGuideLines() {
        for line in horizontalGuideLines {
            line.removeFromSuperlayer()
        }
        self.horizontalGuideLines.removeAll()
        
        for line in verticalGuideLines {
            line.removeFromSuperlayer()
        }
        self.verticalGuideLines.removeAll()
    }
}
