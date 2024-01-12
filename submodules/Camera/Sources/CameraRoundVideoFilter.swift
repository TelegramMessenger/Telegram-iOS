import Foundation
import UIKit
import CoreImage
import CoreMedia
import CoreVideo
import Metal
import Display

func allocateOutputBufferPool(with inputFormatDescription: CMFormatDescription, outputRetainedBufferCountHint: Int) -> (
    outputBufferPool: CVPixelBufferPool?,
    outputColorSpace: CGColorSpace?,
    outputFormatDescription: CMFormatDescription?) {
        let inputMediaSubType = CMFormatDescriptionGetMediaSubType(inputFormatDescription)
        if inputMediaSubType != kCVPixelFormatType_32BGRA {
            return (nil, nil, nil)
        }
        
        let inputDimensions = CMVideoFormatDescriptionGetDimensions(inputFormatDescription)
        var pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: UInt(inputMediaSubType),
            kCVPixelBufferWidthKey as String: Int(inputDimensions.width),
            kCVPixelBufferHeightKey as String: Int(inputDimensions.height),
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as NSDictionary
        ]
        
        var cgColorSpace = CGColorSpaceCreateDeviceRGB()
        if let inputFormatDescriptionExtension = CMFormatDescriptionGetExtensions(inputFormatDescription) as Dictionary? {
            let colorPrimaries = inputFormatDescriptionExtension[kCVImageBufferColorPrimariesKey]
            
            if let colorPrimaries = colorPrimaries {
                var colorSpaceProperties: [String: AnyObject] = [kCVImageBufferColorPrimariesKey as String: colorPrimaries]
                
                if let yCbCrMatrix = inputFormatDescriptionExtension[kCVImageBufferYCbCrMatrixKey] {
                    colorSpaceProperties[kCVImageBufferYCbCrMatrixKey as String] = yCbCrMatrix
                }
                
                if let transferFunction = inputFormatDescriptionExtension[kCVImageBufferTransferFunctionKey] {
                    colorSpaceProperties[kCVImageBufferTransferFunctionKey as String] = transferFunction
                }
                
                pixelBufferAttributes[kCVBufferPropagatedAttachmentsKey as String] = colorSpaceProperties
            }
            
            if let cvColorspace = inputFormatDescriptionExtension[kCVImageBufferCGColorSpaceKey] {
                cgColorSpace = cvColorspace as! CGColorSpace
            } else if (colorPrimaries as? String) == (kCVImageBufferColorPrimaries_P3_D65 as String) {
                cgColorSpace = CGColorSpace(name: CGColorSpace.displayP3)!
            }
        }
        
        let poolAttributes = [kCVPixelBufferPoolMinimumBufferCountKey as String: outputRetainedBufferCountHint]
        var cvPixelBufferPool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(kCFAllocatorDefault, poolAttributes as NSDictionary?, pixelBufferAttributes as NSDictionary?, &cvPixelBufferPool)
        guard let pixelBufferPool = cvPixelBufferPool else {
            return (nil, nil, nil)
        }
        
        preallocateBuffers(pool: pixelBufferPool, allocationThreshold: outputRetainedBufferCountHint)
        
        var pixelBuffer: CVPixelBuffer?
        var outputFormatDescription: CMFormatDescription?
        let auxAttributes = [kCVPixelBufferPoolAllocationThresholdKey as String: outputRetainedBufferCountHint] as NSDictionary
        CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, pixelBufferPool, auxAttributes, &pixelBuffer)
        if let pixelBuffer = pixelBuffer {
            CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                         imageBuffer: pixelBuffer,
                                                         formatDescriptionOut: &outputFormatDescription)
        }
        pixelBuffer = nil
        
        return (pixelBufferPool, cgColorSpace, outputFormatDescription)
}

private func preallocateBuffers(pool: CVPixelBufferPool, allocationThreshold: Int) {
    var pixelBuffers = [CVPixelBuffer]()
    var error: CVReturn = kCVReturnSuccess
    let auxAttributes = [kCVPixelBufferPoolAllocationThresholdKey as String: allocationThreshold] as NSDictionary
    var pixelBuffer: CVPixelBuffer?
    while error == kCVReturnSuccess {
        error = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, pool, auxAttributes, &pixelBuffer)
        if let pixelBuffer = pixelBuffer {
            pixelBuffers.append(pixelBuffer)
        }
        pixelBuffer = nil
    }
    pixelBuffers.removeAll()
}

class CameraRoundVideoFilter {
    private let ciContext: CIContext
    
    private var resizeFilter: CIFilter?
    private var compositeFilter: CIFilter?
    
    private var outputColorSpace: CGColorSpace?
    private var outputPixelBufferPool: CVPixelBufferPool?
    private(set) var outputFormatDescription: CMFormatDescription?
    private(set) var inputFormatDescription: CMFormatDescription?
    
    private(set) var isPrepared = false
    
    let semaphore = DispatchSemaphore(value: 1)
    
    init(ciContext: CIContext) {
        self.ciContext = ciContext
    }
    
    func prepare(with formatDescription: CMFormatDescription, outputRetainedBufferCountHint: Int) {
        self.reset()
        
        (self.outputPixelBufferPool, self.outputColorSpace, self.outputFormatDescription) = allocateOutputBufferPool(with: formatDescription, outputRetainedBufferCountHint: outputRetainedBufferCountHint)
        if self.outputPixelBufferPool == nil {
            return
        }
        self.inputFormatDescription = formatDescription
        
        let diameter: CGFloat = 400.0
        let circleImage = generateImage(CGSize(width: diameter, height: diameter), opaque: false, scale: 1.0, rotatedContext: { size, context in
            let bounds = CGRect(origin: .zero, size: size)
            context.clear(bounds)
            context.setFillColor(UIColor.white.cgColor)
            context.fill(bounds)
            context.setBlendMode(.clear)
            context.fillEllipse(in: bounds)
        })!
                
        self.resizeFilter = CIFilter(name: "CILanczosScaleTransform")
        
        self.compositeFilter = CIFilter(name: "CISourceOverCompositing")
        self.compositeFilter?.setValue(CIImage(image: circleImage), forKey: kCIInputImageKey)
        
        self.isPrepared = true
    }
    
    func reset() {
        self.resizeFilter = nil
        self.compositeFilter = nil
        self.outputColorSpace = nil
        self.outputPixelBufferPool = nil
        self.outputFormatDescription = nil
        self.inputFormatDescription = nil
        self.isPrepared = false
    }
    
    func render(pixelBuffer: CVPixelBuffer, mirror: Bool) -> CVPixelBuffer? {
        self.semaphore.wait()
        
        guard let resizeFilter = self.resizeFilter, let compositeFilter = self.compositeFilter, self.isPrepared else {
            return nil
        }
        
        var sourceImage = CIImage(cvImageBuffer: pixelBuffer)
        sourceImage = sourceImage.oriented(mirror ? .leftMirrored : .right)
        let scale = 400.0 / min(sourceImage.extent.width, sourceImage.extent.height)
        
        resizeFilter.setValue(sourceImage, forKey: kCIInputImageKey)
        resizeFilter.setValue(scale, forKey: kCIInputScaleKey)
        
        if let resizedImage = resizeFilter.outputImage {
            sourceImage = resizedImage
        } else {
            sourceImage = sourceImage.transformed(by: CGAffineTransformMakeScale(scale, scale), highQualityDownsample: true)
        }
        
        sourceImage = sourceImage.transformed(by: CGAffineTransformMakeTranslation(0.0, -(sourceImage.extent.height - sourceImage.extent.width) / 2.0))
        
        sourceImage = sourceImage.cropped(to: CGRect(x: 0.0, y: 0.0, width: sourceImage.extent.width, height: sourceImage.extent.width))
        
        compositeFilter.setValue(sourceImage, forKey: kCIInputBackgroundImageKey)
        
        let finalImage = compositeFilter.outputImage
        guard let finalImage else {
            return nil
        }
        
        var pbuf: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, outputPixelBufferPool!, &pbuf)
        guard let outputPixelBuffer = pbuf else {
            return nil
        }
        
        self.ciContext.render(finalImage, to: outputPixelBuffer, bounds: CGRect(origin: .zero, size: CGSize(width: 400, height: 400)), colorSpace: outputColorSpace)
        
        self.semaphore.signal()
        
        return outputPixelBuffer
    }
}
