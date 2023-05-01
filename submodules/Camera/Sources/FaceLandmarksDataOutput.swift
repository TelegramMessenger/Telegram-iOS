import Foundation
import AVKit
import Vision

final class FaceLandmarksDataOutput {
    private var ciContext: CIContext?
    
    private var detectionRequests: [VNDetectFaceRectanglesRequest]?
    private var trackingRequests: [VNTrackObjectRequest]?
    
    lazy var sequenceRequestHandler = VNSequenceRequestHandler()
    
    var outputFaceObservations: (([VNFaceObservation]) -> Void)?
    
    private var outputColorSpace: CGColorSpace?
    private var outputPixelBufferPool: CVPixelBufferPool?
    private(set) var outputFormatDescription: CMFormatDescription?
    
    init() {
        self.ciContext = CIContext()
        self.prepareVisionRequest()
    }
    
    fileprivate func prepareVisionRequest() {
        var requests = [VNTrackObjectRequest]()
        
        let faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: { (request, error) in
            if error != nil {
                print("FaceDetection error: \(String(describing: error)).")
            }
            guard let faceDetectionRequest = request as? VNDetectFaceRectanglesRequest, let results = faceDetectionRequest.results else {
                return
            }
            DispatchQueue.main.async {
                for observation in results {
                    let faceTrackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
                    requests.append(faceTrackingRequest)
                }
                self.trackingRequests = requests
            }
        })
        
        self.detectionRequests = [faceDetectionRequest]
        self.sequenceRequestHandler = VNSequenceRequestHandler()
    }
    
    func exifOrientationForCurrentDeviceOrientation() -> CGImagePropertyOrientation {
        return exifOrientationForDeviceOrientation(UIDevice.current.orientation)
    }
    
    func process(sampleBuffer: CMSampleBuffer) {
        var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
        
        let cameraIntrinsicData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil)
        if cameraIntrinsicData != nil {
            requestHandlerOptions[VNImageOption.cameraIntrinsics] = cameraIntrinsicData
        }
        
        guard let inputPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to obtain a CVPixelBuffer for the current output frame.")
            return
        }
        let width = CGFloat(CVPixelBufferGetWidth(inputPixelBuffer))
        let height = CGFloat(CVPixelBufferGetHeight(inputPixelBuffer))
        
        if #available(iOS 13.0, *), outputPixelBufferPool == nil, let formatDescription = try? CMFormatDescription(videoCodecType: .pixelFormat_32BGRA, width: Int(width / 3.0), height: Int(height / 3.0)) {
            (outputPixelBufferPool,
                outputColorSpace,
                outputFormatDescription) = allocateOutputBufferPool(with: formatDescription, outputRetainedBufferCountHint: 3)
        }
        
        var pbuf: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, outputPixelBufferPool!, &pbuf)
        guard let pixelBuffer = pbuf, let ciContext = self.ciContext else {
            print("Allocation failure")
            return
        }
        
        resizePixelBuffer(inputPixelBuffer, width: Int(width / 3.0), height: Int(height / 3.0), output: pixelBuffer, context: ciContext)
        
        let exifOrientation = self.exifOrientationForCurrentDeviceOrientation()
        
        guard let requests = self.trackingRequests, !requests.isEmpty else {
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: requestHandlerOptions)
            do {
                guard let detectRequests = self.detectionRequests else {
                    return
                }
                try imageRequestHandler.perform(detectRequests)
            } catch let error as NSError {
                print("Failed to perform FaceRectangleRequest: \(String(describing: error)).")
            }
            return
        }
        
        do {
            try self.sequenceRequestHandler.perform(requests, on: pixelBuffer, orientation: exifOrientation)
        } catch let error as NSError {
            print("Failed to perform SequenceRequest: \(String(describing: error)).")
        }
        
        var newTrackingRequests = [VNTrackObjectRequest]()
        for trackingRequest in requests {
            guard let results = trackingRequest.results else {
                return
            }
            guard let observation = results[0] as? VNDetectedObjectObservation else {
                return
            }
            if !trackingRequest.isLastFrame {
                if observation.confidence > 0.3 {
                    trackingRequest.inputObservation = observation
                } else {
                    trackingRequest.isLastFrame = true
                }
                newTrackingRequests.append(trackingRequest)
            }
        }
        self.trackingRequests = newTrackingRequests
        
        if newTrackingRequests.isEmpty {
            DispatchQueue.main.async {
                self.outputFaceObservations?([])
            }
            return
        }
        
        var faceLandmarkRequests = [VNDetectFaceLandmarksRequest]()
        for trackingRequest in newTrackingRequests {
            let faceLandmarksRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request, error) in
                if error != nil {
                    print("FaceLandmarks error: \(String(describing: error)).")
                }
                
                guard let landmarksRequest = request as? VNDetectFaceLandmarksRequest, let results = landmarksRequest.results else {
                    return
                }
                
                DispatchQueue.main.async {
                    self.outputFaceObservations?(results)
                }
            })
            
            guard let trackingResults = trackingRequest.results else {
                return
            }
            
            guard let observation = trackingResults[0] as? VNDetectedObjectObservation else {
                return
            }
            let faceObservation = VNFaceObservation(boundingBox: observation.boundingBox)
            faceLandmarksRequest.inputFaceObservations = [faceObservation]
            faceLandmarkRequests.append(faceLandmarksRequest)
            
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: requestHandlerOptions)
            do {
                try imageRequestHandler.perform(faceLandmarkRequests)
            } catch let error as NSError {
                print("Failed to perform FaceLandmarkRequest: \(String(describing: error)).")
            }
        }
    }
}
