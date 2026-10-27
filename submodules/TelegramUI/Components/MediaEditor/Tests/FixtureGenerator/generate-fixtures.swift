import Foundation
import AVFoundation
import CoreGraphics
import CoreVideo
import ImageIO
import UniformTypeIdentifiers

let outputDirectory = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath
let colorSpace = CGColorSpaceCreateDeviceRGB()

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> CGColor {
    return CGColor(colorSpace: colorSpace, components: [r, g, b, a])!
}

func drawPattern(context: CGContext, size: CGSize, phase: CGFloat, checkerSize: CGFloat, markerSize: CGFloat) {
    let stops: [(CGFloat, CGFloat, CGFloat)] = [(0.12, 0.25, 0.75), (0.85, 0.35, 0.2), (0.2, 0.8, 0.45), (0.12, 0.25, 0.75)]
    let bandHeight: CGFloat = 8.0
    let bandCount = Int(ceil(size.height / bandHeight))
    for band in 0 ..< bandCount {
        var t = (CGFloat(band) * bandHeight / size.height + phase).truncatingRemainder(dividingBy: 1.0)
        t *= CGFloat(stops.count - 1)
        let index = min(stops.count - 2, Int(floor(t)))
        let f = t - CGFloat(index)
        let a = stops[index]
        let b = stops[index + 1]
        context.setFillColor(color(a.0 + (b.0 - a.0) * f, a.1 + (b.1 - a.1) * f, a.2 + (b.2 - a.2) * f))
        context.fill(CGRect(x: 0.0, y: CGFloat(band) * bandHeight, width: size.width, height: bandHeight))
    }

    context.setFillColor(color(1.0, 1.0, 1.0, 0.22))
    let columns = Int(ceil(size.width / checkerSize))
    let rows = Int(ceil(size.height / checkerSize))
    for row in 0 ..< rows {
        for column in 0 ..< columns where (row + column) % 2 == 0 {
            context.fill(CGRect(x: CGFloat(column) * checkerSize, y: CGFloat(row) * checkerSize, width: checkerSize, height: checkerSize))
        }
    }

    context.setFillColor(color(0.0, 0.0, 0.0, 0.6))
    context.fillEllipse(in: CGRect(x: size.width * 0.5 - size.width * 0.15, y: size.height * 0.5 - size.width * 0.15, width: size.width * 0.3, height: size.width * 0.3))

    let markers: [(CGPoint, CGColor)] = [
        (CGPoint(x: 0.0, y: 0.0), color(1.0, 0.0, 0.0)),
        (CGPoint(x: size.width - markerSize, y: 0.0), color(0.0, 1.0, 0.0)),
        (CGPoint(x: 0.0, y: size.height - markerSize), color(0.0, 0.0, 1.0)),
        (CGPoint(x: size.width - markerSize, y: size.height - markerSize), color(1.0, 1.0, 0.0))
    ]
    for (origin, markerColor) in markers {
        context.setFillColor(markerColor)
        context.fill(CGRect(origin: origin, size: CGSize(width: markerSize, height: markerSize)))
    }
}

func makeContext(width: Int, height: Int, opaque: Bool) -> CGContext {
    let alphaInfo: CGImageAlphaInfo = opaque ? .noneSkipFirst : .premultipliedFirst
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | alphaInfo.rawValue)!
    context.translateBy(x: 0.0, y: CGFloat(height))
    context.scaleBy(x: 1.0, y: -1.0)
    return context
}

func writeImage(_ image: CGImage, name: String, type: UTType) {
    let url = URL(fileURLWithPath: outputDirectory).appendingPathComponent(name)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    precondition(CGImageDestinationFinalize(destination))
    print("wrote \(url.path)")
}

func writePhoto(name: String, width: Int, height: Int) {
    let context = makeContext(width: width, height: height, opaque: true)
    let size = CGSize(width: width, height: height)
    drawPattern(context: context, size: size, phase: 0.0, checkerSize: 64.0, markerSize: CGFloat(min(width, height)) * 0.08)
    writeImage(context.makeImage()!, name: name, type: .png)
}

func writeVideo(name: String, width: Int, height: Int, duration: Double, frameRate: Int32, bitrate: Int) {
    let url = URL(fileURLWithPath: outputDirectory).appendingPathComponent(name)
    try? FileManager.default.removeItem(at: url)
    let writer = try! AVAssetWriter(outputURL: url, fileType: .mp4)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: bitrate,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoMaxKeyFrameIntervalKey: Int(frameRate)
        ]
    ])
    input.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height
    ])
    writer.add(input)
    precondition(writer.startWriting())
    writer.startSession(atSourceTime: .zero)

    let frameCount = Int(duration * Double(frameRate))
    let size = CGSize(width: width, height: height)
    for index in 0 ..< frameCount {
        while !input.isReadyForMoreMediaData {
            Thread.sleep(forTimeInterval: 0.005)
        }
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pixelBuffer)
        let buffer = pixelBuffer!
        CVPixelBufferLockBaseAddress(buffer, [])
        let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: colorSpace, bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue)!
        context.translateBy(x: 0.0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        drawPattern(context: context, size: size, phase: CGFloat(index) / CGFloat(frameCount), checkerSize: 64.0, markerSize: 96.0)
        CVPixelBufferUnlockBaseAddress(buffer, [])
        precondition(adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(index), timescale: frameRate)))
    }
    input.markAsFinished()
    let semaphore = DispatchSemaphore(value: 0)
    writer.finishWriting {
        semaphore.signal()
    }
    semaphore.wait()
    precondition(writer.status == .completed, "\(String(describing: writer.error))")
    print("wrote \(url.path)")
}

func writeAnimation(name: String) {
    let url = URL(fileURLWithPath: outputDirectory).appendingPathComponent(name)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.heics.identifier as CFString, 3, nil)!
    CGImageDestinationSetProperties(destination, [kCGImagePropertyHEICSDictionary as String: [kCGImagePropertyHEICSLoopCount as String: 0]] as CFDictionary)
    let colors = [color(1.0, 0.2, 0.2), color(0.2, 0.9, 0.3), color(0.25, 0.4, 1.0)]
    for index in 0 ..< 3 {
        let context = makeContext(width: 256, height: 256, opaque: false)
        context.setShouldAntialias(false)
        context.clear(CGRect(x: 0.0, y: 0.0, width: 256.0, height: 256.0))
        context.setFillColor(colors[index])
        context.fillEllipse(in: CGRect(x: 32.0, y: 32.0, width: 192.0, height: 192.0))
        context.setFillColor(color(1.0, 1.0, 1.0))
        context.fill(CGRect(x: 48.0 + CGFloat(index) * 56.0, y: 112.0, width: 48.0, height: 32.0))
        CGImageDestinationAddImage(destination, context.makeImage()!, [kCGImagePropertyHEICSDictionary as String: [kCGImagePropertyHEICSDelayTime as String: 0.2]] as CFDictionary)
    }
    precondition(CGImageDestinationFinalize(destination))
    print("wrote \(url.path)")
}

try? FileManager.default.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)
writeVideo(name: "video-portrait.mp4", width: 1080, height: 1920, duration: 3.0, frameRate: 30, bitrate: 4_000_000)
writeVideo(name: "video-square.mp4", width: 512, height: 512, duration: 2.0, frameRate: 30, bitrate: 1_000_000)
writePhoto(name: "photo.png", width: 3024, height: 4032)
writePhoto(name: "photo-panorama.png", width: 12000, height: 2000)
writeAnimation(name: "animation.heics")
