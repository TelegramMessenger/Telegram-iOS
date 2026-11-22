import Foundation
import UIKit
import Photos
import AVFoundation
import CoreImage
import SwiftSignalKit
import AccountContext
import MediaEditor
import MediaAssetsContext

public let chatMediaSendEditedVideoThumbnailMaxSide: CGFloat = 512.0
public let chatMediaSendEditedVideoFrameMaxSide: CGFloat = 1024.0
public let chatMediaSendMaxConcurrentVideoThumbnails = 2

public func chatMediaSendVideoThumbnailGenerator(asset: AVAsset) -> AVAssetImageGenerator {
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    generator.maximumSize = CGSize(width: chatMediaSendEditedVideoFrameMaxSide, height: chatMediaSendEditedVideoFrameMaxSide)
    return generator
}

public func chatMediaSendDeliverOnBackground<T, E>(_ signal: Signal<T, E>) -> Signal<T, E> {
    return signal |> deliverOn(Queue())
}

public func chatMediaSendBoundedCombine<T>(_ signals: [Signal<T, NoError>], maxConcurrent: Int) -> Signal<[T?], NoError> {
    guard !signals.isEmpty else {
        return .single([])
    }
    let laneCount = max(1, min(maxConcurrent, signals.count))
    var lanes: [Signal<[(Int, T?)], NoError>] = []
    for lane in 0 ..< laneCount {
        var laneSignal: Signal<[(Int, T?)], NoError> = .single([])
        for index in stride(from: lane, to: signals.count, by: laneCount) {
            let signal = signals[index]
            laneSignal = laneSignal
            |> mapToSignal { results -> Signal<[(Int, T?)], NoError> in
                return (signal
                |> map { value -> T? in
                    return value
                }
                |> then(.single(nil))
                |> take(1))
                |> map { value -> [(Int, T?)] in
                    return results + [(index, value)]
                }
            }
        }
        lanes.append(laneSignal)
    }
    return combineLatest(lanes)
    |> map { laneResults -> [T?] in
        return laneResults.flatMap { $0 }.sorted(by: { $0.0 < $1.0 }).map { $0.1 }
    }
}

public func chatMediaSendEditedVideoThumbnail(context: AccountContext, identifier: String, values: MediaEditorValues) -> Signal<UIImage?, NoError> {
    return Signal { subscriber in
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject else {
            subscriber.putNext(nil)
            subscriber.putCompletion()
            return EmptyDisposable
        }
        let isDisposed = Atomic<Bool>(value: false)
        let currentGenerator = Atomic<AVAssetImageGenerator?>(value: nil)
        let finish: (UIImage?) -> Void = { image in
            subscriber.putNext(image)
            subscriber.putCompletion()
        }
        let disposable = assetVideoAsset(asset).start(next: { result in
            switch result {
            case .progress:
                break
            case .unavailable:
                finish(nil)
            case let .result(avAsset):
                let time = CMTime(seconds: values.videoTrimRange?.lowerBound ?? 0.0, preferredTimescale: CMTimeScale(60))
                let generator = chatMediaSendVideoThumbnailGenerator(asset: avAsset)
                let _ = currentGenerator.swap(generator)
                if isDisposed.with({ $0 }) {
                    generator.cancelAllCGImageGeneration()
                    finish(nil)
                    return
                }
                generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)], completionHandler: { _, cgImage, _, _, _ in
                    let _ = generator
                    guard let cgImage else {
                        finish(nil)
                        return
                    }
                    Queue.mainQueue().async {
                        if isDisposed.with({ $0 }) {
                            finish(nil)
                            return
                        }
                        let frame = UIImage(cgImage: cgImage)
                        let input: MediaEditorCompositionInput = chatMediaSendStandaloneEditorImage(context: context, image: frame, values: values).flatMap { .editorResult($0) } ?? .image(frame)
                        makeChatEditorImageComposition(accountContext: context, input: input, values: values, time: time, maxOutputSide: chatMediaSendEditedVideoThumbnailMaxSide, completion: { image in
                            finish(image)
                        })
                    }
                })
            }
        })
        return ActionDisposable {
            let _ = isDisposed.swap(true)
            disposable.dispose()
            currentGenerator.swap(nil)?.cancelAllCGImageGeneration()
        }
    }
}
