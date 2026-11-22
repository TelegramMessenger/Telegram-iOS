import Foundation
import CoreGraphics
import AVFoundation

public enum CameraCaptureMode: Equatable {
    case photo
    case video
}

public struct CameraFormatDescriptor: Equatable {
    public struct Dimensions: Equatable {
        public var width: Int32
        public var height: Int32

        public init(width: Int32, height: Int32) {
            self.width = width
            self.height = height
        }

        var area: Int64 {
            return Int64(self.width) * Int64(self.height)
        }

        func fits(in limit: Dimensions) -> Bool {
            return self.width <= limit.width && self.height <= limit.height
        }
    }

    public let index: Int
    public let dimensions: Dimensions
    public let isVideoRange420: Bool
    public let maxFrameRates: [Double]
    public let hasSecondaryZoomLevels: Bool
    public let isHighPhotoQualitySupported: Bool
    public let maxPhotoDimensions: [Dimensions]

    public init(
        index: Int,
        dimensions: Dimensions,
        isVideoRange420: Bool,
        maxFrameRates: [Double],
        hasSecondaryZoomLevels: Bool,
        isHighPhotoQualitySupported: Bool,
        maxPhotoDimensions: [Dimensions]
    ) {
        self.index = index
        self.dimensions = dimensions
        self.isVideoRange420 = isVideoRange420
        self.maxFrameRates = maxFrameRates
        self.hasSecondaryZoomLevels = hasSecondaryZoomLevels
        self.isHighPhotoQualitySupported = isHighPhotoQualitySupported
        self.maxPhotoDimensions = maxPhotoDimensions
    }
}

public enum CameraFormatRule: Equatable {
    case legacy(maxDimensions: CameraFormatDescriptor.Dimensions)
    case photo
    case video
}

public let cameraPhotoModeMaxPhotoDimensions = CameraFormatDescriptor.Dimensions(width: 4032, height: 3024)
public let cameraVideoModeMaxDimensions = CameraFormatDescriptor.Dimensions(width: 1920, height: 1080)
private let cameraPhotoModePreviewDimensions = CameraFormatDescriptor.Dimensions(width: 1920, height: 1440)

public func cameraFormatRule(captureMode: CameraCaptureMode?, legacyMaxDimensions: CameraFormatDescriptor.Dimensions) -> CameraFormatRule {
    switch captureMode {
    case .none:
        return .legacy(maxDimensions: legacyMaxDimensions)
    case .photo:
        return .photo
    case .video:
        return .video
    }
}

public func cameraAttachesAudio(captureMode: CameraCaptureMode?, configuredAudio: Bool) -> Bool {
    switch captureMode {
    case .none:
        return configuredAudio
    case .photo:
        return false
    case .video:
        return true
    }
}

public func cameraPreferredFormat(formats: [CameraFormatDescriptor], rule: CameraFormatRule, maxFramerate: Double = 30.0) -> CameraFormatDescriptor? {
    switch rule {
    case let .legacy(maxDimensions):
        return cameraPreferredFormat(formats: formats, maxDimensions: maxDimensions, maxFramerate: maxFramerate)
    case .photo:
        return cameraPreferredFormat(formats: formats, mode: .photo, maxFramerate: maxFramerate)
    case .video:
        return cameraPreferredFormat(formats: formats, mode: .video, maxFramerate: maxFramerate)
    }
}

public func cameraPreferredFormat(formats: [CameraFormatDescriptor], mode: CameraCaptureMode, maxFramerate: Double = 30.0) -> CameraFormatDescriptor? {
    switch mode {
    case .video:
        return cameraPreferredFormat(formats: formats, maxDimensions: cameraVideoModeMaxDimensions, maxFramerate: maxFramerate)
    case .photo:
        var best: (format: CameraFormatDescriptor, photoArea: Int64, fitsPreview: Bool)?
        for format in formats {
            let dimensions = format.dimensions
            if !format.isVideoRange420 || dimensions.width * 3 != dimensions.height * 4 || !dimensions.fits(in: cameraPhotoModeMaxPhotoDimensions) {
                continue
            }
            if format.maxFrameRates.contains(where: { $0 > 60.0 }) {
                continue
            }
            guard let photoDimensions = cameraPreferredPhotoDimensions(for: format) else {
                continue
            }
            let photoArea = photoDimensions.area
            let fitsPreview = dimensions.fits(in: cameraPhotoModePreviewDimensions)
            if let current = best {
                if photoArea != current.photoArea {
                    if photoArea < current.photoArea {
                        continue
                    }
                } else if format.isHighPhotoQualitySupported != current.format.isHighPhotoQualitySupported {
                    if !format.isHighPhotoQualitySupported {
                        continue
                    }
                } else if fitsPreview != current.fitsPreview {
                    if !fitsPreview {
                        continue
                    }
                } else if dimensions.area <= current.format.dimensions.area {
                    continue
                }
            }
            best = (format, photoArea, fitsPreview)
        }
        if let best {
            return best.format
        }
        return cameraPreferredFormat(formats: formats, maxDimensions: cameraPhotoModePreviewDimensions, maxFramerate: maxFramerate)
    }
}

public func cameraPreferredPhotoDimensions(for format: CameraFormatDescriptor) -> CameraFormatDescriptor.Dimensions? {
    let candidates = format.maxPhotoDimensions.isEmpty ? [format.dimensions] : format.maxPhotoDimensions
    var best: CameraFormatDescriptor.Dimensions?
    for candidate in candidates where candidate.fits(in: cameraPhotoModeMaxPhotoDimensions) {
        if let current = best, current.area >= candidate.area {
            continue
        }
        best = candidate
    }
    return best
}

public func cameraPreferredFormat(formats: [CameraFormatDescriptor], maxDimensions: CameraFormatDescriptor.Dimensions, maxFramerate: Double) -> CameraFormatDescriptor? {
    var maxWidth: Int32 = 0
    var maxHeight: Int32 = 0
    var hasSecondaryZoomLevels = false
    var candidates: [CameraFormatDescriptor] = []
    var photoCandidates: [CameraFormatDescriptor] = []
    outer: for format in formats {
        let dimensions = format.dimensions
        if dimensions.width >= maxWidth && dimensions.width <= maxDimensions.width && dimensions.height >= maxHeight && dimensions.height <= maxDimensions.height {
            if dimensions.width > maxWidth {
                hasSecondaryZoomLevels = false
                candidates.removeAll()
            }
            if format.isVideoRange420 {
                for frameRate in format.maxFrameRates {
                    if frameRate > 60 {
                        continue outer
                    }
                }

                maxWidth = dimensions.width
                maxHeight = dimensions.height

                if format.hasSecondaryZoomLevels {
                    hasSecondaryZoomLevels = true
                    candidates.append(format)
                    if format.isHighPhotoQualitySupported {
                        photoCandidates.append(format)
                    }
                } else if !hasSecondaryZoomLevels {
                    candidates.append(format)
                    if format.isHighPhotoQualitySupported {
                        photoCandidates.append(format)
                    }
                }
            }
        }
    }

    if candidates.isEmpty {
        return nil
    }
    var bestFormat: CameraFormatDescriptor?
    photoOuter: for format in photoCandidates {
        for frameRate in format.maxFrameRates {
            if frameRate > maxFramerate {
                continue photoOuter
            }
            bestFormat = format
        }
    }
    if bestFormat == nil {
        outer: for format in candidates {
            for frameRate in format.maxFrameRates {
                if frameRate > maxFramerate {
                    continue outer
                }
                bestFormat = format
            }
        }
    }
    if bestFormat == nil {
        bestFormat = candidates.last
    }
    return bestFormat
}

public func cameraRecordedDimensions(captureMode: CameraCaptureMode?, videoSettings: [String: Any], isLandscape: Bool) -> CGSize {
    let fallback = isLandscape ? CGSize(width: 1920.0, height: 1080.0) : CGSize(width: 1080.0, height: 1920.0)
    guard captureMode != nil else {
        return fallback
    }
    guard let width = (videoSettings[AVVideoWidthKey] as? NSNumber)?.intValue, let height = (videoSettings[AVVideoHeightKey] as? NSNumber)?.intValue, width > 0, height > 0 else {
        return fallback
    }
    let long = CGFloat(max(width, height))
    let short = CGFloat(min(width, height))
    return isLandscape ? CGSize(width: long, height: short) : CGSize(width: short, height: long)
}

public enum CameraCaptureOrientation {
    case portrait
    case portraitUpsideDown
    case landscapeLeft
    case landscapeRight
}

public func cameraPhotoExifOrientation(orientation: CameraCaptureOrientation, mirror: Bool) -> Int32 {
    switch (orientation, mirror) {
    case (.portrait, false):
        return 6
    case (.portrait, true):
        return 5
    case (.portraitUpsideDown, false):
        return 8
    case (.portraitUpsideDown, true):
        return 7
    case (.landscapeLeft, false):
        return 3
    case (.landscapeLeft, true):
        return 2
    case (.landscapeRight, false):
        return 1
    case (.landscapeRight, true):
        return 4
    }
}
