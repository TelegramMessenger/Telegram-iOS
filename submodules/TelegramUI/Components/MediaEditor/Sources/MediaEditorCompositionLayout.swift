import Foundation
import UIKit
import Metal
import simd

func mediaEditorCompositionRoundedSize(_ size: CGSize) -> CGSize {
    let tolerance: CGFloat = 1.0 / 1024.0
    return CGSize(width: max(0.0, (size.width - tolerance).rounded(.up)), height: max(0.0, (size.height - tolerance).rounded(.up)))
}

private func mediaEditorCompositionTail(dimensions: CGSize, outputDimensions: CGSize?, values: MediaEditorValues) -> (transform: CGAffineTransform, size: CGSize, clip: CGRect) {
    var transform = CGAffineTransform(translationX: dimensions.width / 2.0, y: dimensions.height / 2.0)
    var cropSize: CGSize
    if values.isSticker {
        let minSize = min(dimensions.width, dimensions.height)
        cropSize = CGSize(width: floor(minSize * 0.97), height: floor(minSize * 0.97))
        transform = transform.concatenating(CGAffineTransform(translationX: -(dimensions.width - cropSize.width) / 2.0, y: -(dimensions.height - cropSize.height) / 2.0))
    } else if values.isAvatar {
        let minSize = min(dimensions.width, dimensions.height)
        cropSize = CGSize(width: minSize, height: minSize)
        transform = transform.concatenating(CGAffineTransform(translationX: -(dimensions.width - cropSize.width) / 2.0, y: -(dimensions.height - cropSize.height) / 2.0))
    } else if values.isCover, let outputDimensions {
        cropSize = outputDimensions.aspectFitted(dimensions)
        transform = transform.concatenating(CGAffineTransform(translationX: -(dimensions.width - cropSize.width) / 2.0, y: -(dimensions.height - cropSize.height) / 2.0))
    } else if values.isStory {
        cropSize = dimensions
    } else {
        if !values.cropRotation.isZero {
            transform = transform.concatenating(CGAffineTransform(translationX: -dimensions.width / 2.0, y: -dimensions.height / 2.0))
            transform = transform.concatenating(CGAffineTransform(rotationAngle: -values.cropRotation))
            transform = transform.concatenating(CGAffineTransform(translationX: dimensions.width / 2.0, y: dimensions.height / 2.0))
        }
        let scaledCropRect = mediaEditorNonStoryScaledCropRect(values: values, dimensions: dimensions)
        transform = transform.concatenating(CGAffineTransformMakeTranslation(-scaledCropRect.minX, -scaledCropRect.minY))
        cropSize = scaledCropRect.size
        let roundedSize = mediaEditorCompositionRoundedSize(cropSize)
        if let orientation = values.cropOrientation, orientation != .up {
            let orientationTransform = mediaEditorOrientationTransform(orientation, size: roundedSize)
            transform = transform.concatenating(orientationTransform)
            let clip = CGRect(origin: .zero, size: cropSize).applying(orientationTransform)
            return (transform, CGRect(origin: .zero, size: roundedSize).applying(orientationTransform).size, clip)
        }
        return (transform, roundedSize, CGRect(origin: .zero, size: cropSize))
    }
    return (transform, mediaEditorCompositionRoundedSize(cropSize), CGRect(origin: .zero, size: cropSize))
}

private func mediaEditorCompositionPerspective(_ perspective: MediaEditorCropPerspective, dimensions: CGSize, preTransform: CGAffineTransform) -> MediaEditorPerspectiveHomography {
    let flip = simd_double3x3(diagonal: simd_double3(1.0, -1.0, 1.0))
    let homography = MediaEditorPerspectiveHomography(perspective: perspective, size: dimensions)
    let pre = simd_double3x3(rows: [
        simd_double3(Double(preTransform.a), Double(preTransform.c), Double(preTransform.tx)),
        simd_double3(Double(preTransform.b), Double(preTransform.d), Double(preTransform.ty)),
        simd_double3(0.0, 0.0, 1.0)
    ])
    return MediaEditorPerspectiveHomography(m: flip * homography.m * flip * pre)
}

func mediaEditorCompositionResultSize(dimensions: CGSize, outputDimensions: CGSize?, values: MediaEditorValues) -> CGSize {
    return mediaEditorCompositionTail(dimensions: dimensions, outputDimensions: outputDimensions, values: values).size
}

func mediaEditorCompositionScene(
    input: MediaEditorCompositionLayer,
    drawing: MediaEditorCompositionLayer?,
    entities: [(entity: MediaEditorComposerEntity, layer: MediaEditorCompositionLayer)],
    finalMask: MTLTexture?,
    dimensions: CGSize,
    outputDimensions: CGSize?,
    values: MediaEditorValues,
    entityScale: CGFloat,
    outputScale: CGFloat
) -> MediaEditorCompositionScene {
    var isClear = false
    if let gradientColor = values.gradientColors?.first, gradientColor.alpha.isZero {
        isClear = true
    }

    let (tail, resultSize, clip) = mediaEditorCompositionTail(dimensions: dimensions, outputDimensions: outputDimensions, values: values)
    let outputTransform = tail.concatenating(CGAffineTransform(scaleX: outputScale, y: outputScale))

    func placed(_ layer: MediaEditorCompositionLayer, _ transform: CGAffineTransform) -> MediaEditorCompositionLayer {
        return MediaEditorCompositionLayer(texture: layer.texture, origin: layer.origin, transform: layer.transform.concatenating(transform).concatenating(outputTransform), alphaMask: layer.alphaMask)
    }

    var layers: [MediaEditorCompositionLayer] = []

    let inputWidth = CGFloat(input.texture.width)
    let inputHeight = CGFloat(input.texture.height)
    var mediaTransform = CGAffineTransform(translationX: -inputWidth / 2.0, y: -inputHeight / 2.0)
    if !(values.isStory || values.isSticker || values.isAvatar || values.isCover) {
        let initialScale = dimensions.width / inputWidth
        var horizontalScale = initialScale
        if values.cropMirroring {
            horizontalScale *= -1.0
        }
        mediaTransform = mediaTransform.concatenating(CGAffineTransformMakeScale(horizontalScale, initialScale))
    }
    if !(values.isStory || values.isSticker || values.isAvatar || values.isCover) && !values.cropPerspective.isZero {
        layers.append(MediaEditorCompositionLayer(texture: input.texture, origin: input.origin, transform: outputTransform, alphaMask: input.alphaMask, perspective: mediaEditorCompositionPerspective(values.cropPerspective, dimensions: dimensions, preTransform: input.transform.concatenating(mediaTransform))))
    } else {
        layers.append(placed(input, mediaTransform))
    }

    if let drawing {
        layers.append(placed(drawing, CGAffineTransform(translationX: -dimensions.width / 2.0, y: -dimensions.height / 2.0)))
    }

    for (entity, layer) in entities {
        let width = CGFloat(layer.texture.width)
        let height = CGFloat(layer.texture.height)
        let resetTransform = CGAffineTransform(translationX: -width / 2.0, y: -height / 2.0)

        var baseScale: CGFloat = 1.0
        if let scale = entity.baseScale {
            baseScale = scale
        } else if let _ = entity.baseDrawingSize {
        } else if let baseSize = entity.baseSize {
            baseScale = baseSize.width / width
        }

        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: -dimensions.width / 2.0 + entity.position.x * entityScale, y: dimensions.height / 2.0 + entity.position.y * entityScale * -1.0)
        transform = transform.rotated(by: -entity.rotation)
        transform = transform.scaledBy(x: entity.scale * baseScale * entityScale, y: entity.scale * baseScale * entityScale)
        if entity.mirrored {
            transform = transform.scaledBy(x: -1.0, y: 1.0)
        }
        layers.append(placed(layer, resetTransform.concatenating(transform)))
    }

    let outputSize = CGSize(width: resultSize.width * outputScale, height: resultSize.height * outputScale)
    return MediaEditorCompositionScene(
        outputSize: outputSize,
        background: isClear ? nil : SIMD4<Float>(0.0, 0.0, 0.0, 1.0),
        backgroundRect: CGRect(x: -dimensions.width / 2.0, y: -dimensions.height / 2.0, width: dimensions.width, height: dimensions.height),
        layers: layers,
        finalMask: finalMask.flatMap { ($0, CGAffineTransform(scaleX: outputScale, y: outputScale)) },
        backgroundTransform: outputTransform,
        clipRect: clip.applying(CGAffineTransform(scaleX: outputScale, y: outputScale))
    )
}
