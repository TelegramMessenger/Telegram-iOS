import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import AnimationCache
import MultiAnimationRenderer
import EmojiTextAttachmentView
import GenerateStickerPlaceholderImage

func qrStudioCrossfadeContents(_ layer: CALayer) {
    let transition = CATransition()
    transition.type = .fade
    transition.duration = 0.25
    transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    layer.add(transition, forKey: "contents")
}

private final class QrStudioWeakFrames {
    weak var value: QrStudioExportSticker?

    init(_ value: QrStudioExportSticker) {
        self.value = value
    }
}

private var qrStudioPhasedFrames: [String: QrStudioWeakFrames] = [:]

private let qrStudioPhasedEpoch = CACurrentMediaTime()

private final class QrStudioPhaseMember {
    weak var layer: CALayer?
    let group: Int

    init(layer: CALayer, group: Int) {
        self.layer = layer
        self.group = group
    }
}

final class QrStudioPhasedAnimation {
    static let groupCount = 6
    private static let animationKey = "qrPhasedFrames"

    private let context: AccountContext
    let file: TelegramMediaFile
    private let pixelSize: CGSize
    private let customColor: UIColor?
    private var members: [ObjectIdentifier: QrStudioPhaseMember] = [:]
    private var firstFrameDisposable: Disposable?
    private var framesDisposable: Disposable?
    private var placeholder: CGImage?
    private var frames: QrStudioExportSticker?

    private(set) var hasFrames = false
    var hasPlaceholder: Bool {
        return self.placeholder != nil
    }
    var onFirstFrame: (() -> Void)?

    init(context: AccountContext, file: TelegramMediaFile, pointSize: CGSize, hostLayer: CALayer, placeholderColor: UIColor? = nil) {
        self.context = context
        self.file = file
        self.customColor = file.isCustomTemplateEmoji ? UIColor.white : nil
        self.pixelSize = CGSize(width: floor(pointSize.width * UIScreenScale), height: floor(pointSize.height * UIScreenScale))

        if let placeholderColor, let data = file.immediateThumbnailData {
            let color = file.isCustomTemplateEmoji ? UIColor(white: 1.0, alpha: 0.3) : placeholderColor
            self.placeholder = generateStickerPlaceholderImage(data: data, size: pointSize, scale: min(2.0, UIScreenScale), imageSize: file.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0), backgroundColor: nil, foregroundColor: color)?.cgImage
        }

        let framesKey = "\(file.fileId.id)-\(Int(self.pixelSize.width))"
        if let frames = qrStudioPhasedFrames[framesKey]?.value {
            self.frames = frames
            self.hasFrames = true
            return
        }

        self.framesDisposable = (qrStudioDecodeExportSticker(context: context, file: file, pixelSide: Int(self.pixelSize.width), tint: nil, firstFrameOnly: false)
        |> deliverOnMainQueue).start(next: { [weak self] frames in
            guard let self, let frames else {
                return
            }
            qrStudioPhasedFrames[framesKey] = QrStudioWeakFrames(frames)
            self.frames = frames
            for (_, member) in self.members {
                if let layer = member.layer {
                    qrStudioCrossfadeContents(layer)
                    self.apply(layer, group: member.group)
                }
            }
            if !self.hasFrames {
                self.hasFrames = true
                self.onFirstFrame?()
            }
        })
    }

    deinit {
        self.firstFrameDisposable?.dispose()
        self.framesDisposable?.dispose()
    }

    func setPaused(_ isPaused: Bool) {
    }

    private func apply(_ layer: CALayer, group: Int) {
        guard let frames = self.frames else {
            layer.contents = self.placeholder
            return
        }
        let offset = frames.period * Double(group) / Double(QrStudioPhasedAnimation.groupCount)
        layer.removeAnimation(forKey: QrStudioPhasedAnimation.animationKey)
        if frames.isAnimated {
            let local = (CACurrentMediaTime() - qrStudioPhasedEpoch + offset).truncatingRemainder(dividingBy: frames.period)
            let index = min(frames.frames.count - 1, max(0, Int(Double(frames.frames.count) * local / frames.period)))
            layer.contents = frames.frames[index]
            let animation = CAKeyframeAnimation(keyPath: "contents")
            animation.values = frames.frames
            animation.duration = frames.period
            animation.calculationMode = .discrete
            animation.repeatCount = .infinity
            animation.isRemovedOnCompletion = false
            animation.timeOffset = offset
            animation.beginTime = layer.convertTime(qrStudioPhasedEpoch, from: nil)
            layer.add(animation, forKey: QrStudioPhasedAnimation.animationKey)
        } else {
            layer.contents = frames.frames.first
        }
    }

    func attach(_ layer: CALayer, group: Int) {
        let key = ObjectIdentifier(layer)
        if let current = self.members[key], current.layer === layer, current.group == group {
            return
        }
        self.members[key] = QrStudioPhaseMember(layer: layer, group: group)
        self.apply(layer, group: group)
    }

    func detach(_ layer: CALayer) {
        guard self.members.removeValue(forKey: ObjectIdentifier(layer)) != nil else {
            return
        }
        layer.removeAnimation(forKey: QrStudioPhasedAnimation.animationKey)
    }

    func firstFrameImage(completion: @escaping (CGImage?) -> Void) {
        self.firstFrameDisposable?.dispose()
        self.firstFrameDisposable = self.context.animationRenderer.loadFirstFrameAsImage(cache: self.context.animationCache, itemId: self.itemId, size: self.pixelSize, fetch: self.fetch(), completion: { image in
            Queue.mainQueue().async {
                completion(image)
            }
        })
    }

    private var itemId: String {
        return self.file.resource.id.stringRepresentation
    }

    private func fetch() -> (AnimationCacheFetchOptions) -> Disposable {
        return animationCacheFetchFile(context: self.context, userLocation: .other, userContentType: .sticker, resource: .media(media: .standalone(media: self.file), resource: self.file.resource), type: AnimationCacheAnimationType(file: self.file), keyframeOnly: false, customColor: self.customColor)
    }
}
