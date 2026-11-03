import Foundation
import UIKit
import Display
import SwiftSignalKit

private final class QrStudioWeakSticker {
    weak var value: QrStudioExportSticker?

    init(_ value: QrStudioExportSticker) {
        self.value = value
    }
}

private var qrStudioPlaneFrames: [Int: QrStudioWeakSticker] = [:]

final class QrStudioPlaneLayer: SimpleLayer {
    private static let animationKey = "frames"

    private var pixelSide = 0
    private var sticker: QrStudioExportSticker?
    private var disposable: Disposable?

    override init() {
        super.init()

        self.contentsGravity = .resizeAspect
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.disposable?.dispose()
    }

    func update(pointSize: CGSize) {
        let pixelSide = Int(floor(min(pointSize.width, pointSize.height) * UIScreenScale))
        guard pixelSide != self.pixelSide, pixelSide > 0 else {
            return
        }
        self.pixelSide = pixelSide
        if let sticker = qrStudioPlaneFrames[pixelSide]?.value {
            self.apply(sticker)
            return
        }
        self.disposable?.dispose()
        self.disposable = (Signal<QrStudioExportSticker?, NoError> { subscriber in
            subscriber.putNext(qrStudioDecodeExportPlane(pixelSide: pixelSide))
            subscriber.putCompletion()
            return EmptyDisposable
        }
        |> runOn(Queue.concurrentDefaultQueue())
        |> deliverOnMainQueue).start(next: { [weak self] sticker in
            guard let self, let sticker, self.pixelSide == pixelSide else {
                return
            }
            qrStudioPlaneFrames[pixelSide] = QrStudioWeakSticker(sticker)
            self.apply(sticker)
        })
    }

    private func apply(_ sticker: QrStudioExportSticker) {
        self.sticker = sticker
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.contents = sticker.frames.first
        CATransaction.commit()
        self.removeAnimation(forKey: QrStudioPlaneLayer.animationKey)
        guard sticker.isAnimated else {
            return
        }
        let animation = CAKeyframeAnimation(keyPath: "contents")
        animation.values = sticker.frames
        animation.duration = sticker.period
        animation.calculationMode = .discrete
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        animation.beginTime = self.convertTime(CACurrentMediaTime(), from: nil)
        self.add(animation, forKey: QrStudioPlaneLayer.animationKey)
    }
}
