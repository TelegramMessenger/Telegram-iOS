import Foundation
import CoreML
import SwiftSignalKit
import TelegramCore
import AccountContext
import FileMediaResourceStatus
import ZipArchive

public enum ImageInpaintingAvailability {
    case available
    case progress(Float)
    case unavailable
}

private let modelChannelName = "drawingcleanup"
private let modelDirectoryName = "migan512_v1.mlmodelc"

let imageInpaintingQueue = Queue(name: "ImageInpainting")

private func modelsDirectoryPath() -> String {
    let cachesPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first ?? NSTemporaryDirectory()
    return cachesPath + "/image-inpainting"
}

func imageInpaintingModelPath() -> String {
    return modelsDirectoryPath() + "/" + modelDirectoryName
}

private func installModel(fromArchiveAt archivePath: String) -> Bool {
    let fileManager = FileManager.default
    let unpackPath = NSTemporaryDirectory() + "image-inpainting-\(UInt64.random(in: 0 ... UInt64.max))"
    defer {
        try? fileManager.removeItem(atPath: unpackPath)
    }
    guard SSZipArchive.unzipFile(atPath: archivePath, toDestination: unpackPath) else {
        return false
    }
    let unpackedModelPath = unpackPath + "/" + modelDirectoryName
    guard fileManager.fileExists(atPath: unpackedModelPath + "/model.mil") else {
        return false
    }
    do {
        try fileManager.createDirectory(atPath: modelsDirectoryPath(), withIntermediateDirectories: true)
        try? fileManager.removeItem(atPath: imageInpaintingModelPath())
        try fileManager.moveItem(atPath: unpackedModelPath, toPath: imageInpaintingModelPath())
        return true
    } catch {
        return false
    }
}

public func removeDownloadedImageInpaintingModel() {
    try? FileManager.default.removeItem(atPath: modelsDirectoryPath())
    if #available(iOS 17.0, *) {
        ImageInpainter.resetShared()
    }
}

public func imageInpaintingAvailability(context: AccountContext) -> Signal<ImageInpaintingAvailability, NoError> {
    guard #available(iOS 17.0, *) else {
        return .single(.unavailable)
    }
    if FileManager.default.fileExists(atPath: imageInpaintingModelPath() + "/model.mil") {
        return .single(.available)
    }
    return context.engine.peers.resolvePeerByName(name: modelChannelName, referrer: nil)
    |> mapToSignal { result -> Signal<ImageInpaintingAvailability, NoError> in
        guard case let .result(maybePeer) = result else {
            return .complete()
        }
        guard let peer = maybePeer else {
            return .single(.unavailable)
        }

        return context.account.viewTracker.aroundMessageHistoryViewForLocation(.peer(peerId: peer.id, threadId: nil), index: .lowerBound, anchorIndex: .lowerBound, count: 5, fixedCombinedReadStates: nil)
        |> mapToSignal { view -> Signal<(TelegramMediaFile, EngineMessage)?, NoError> in
            if !view.0.isLoading {
                if let message = view.0.entries.last?.message, let file = message.media.first(where: { $0 is TelegramMediaFile }) as? TelegramMediaFile {
                    return .single((file, EngineMessage(message)))
                } else {
                    return .single(nil)
                }
            } else {
                return .complete()
            }
        }
        |> take(1)
        |> mapToSignal { maybeFileAndMessage -> Signal<ImageInpaintingAvailability, NoError> in
            guard let (file, message) = maybeFileAndMessage else {
                return .single(.unavailable)
            }
            let fetchedData = context.engine.resources.fetch(reference: FileMediaReference.message(message: MessageReference(message._asMessage()), media: file).resourceReference(file.resource), userLocation: .other, userContentType: .file)

            return Signal<ImageInpaintingAvailability, NoError> { subscriber in
                let fetchedDisposable = fetchedData.start()
                let resourceDataDisposable = (context.engine.resources.data(resource: EngineMediaResource(file.resource))
                |> filter { $0.isComplete }
                |> take(1)
                |> deliverOn(imageInpaintingQueue)).start(next: { data in
                    if installModel(fromArchiveAt: data.path) {
                        subscriber.putNext(.available)
                    } else {
                        subscriber.putNext(.unavailable)
                    }
                    subscriber.putCompletion()
                })
                let progressDisposable = messageFileMediaResourceStatus(context: context, file: file, message: message, isRecentActions: false).start(next: { status in
                    switch status.fetchStatus {
                    case let .Remote(progress), let .Fetching(_, progress), let .Paused(progress):
                        subscriber.putNext(.progress(progress))
                    default:
                        break
                    }
                })
                return ActionDisposable {
                    fetchedDisposable.dispose()
                    resourceDataDisposable.dispose()
                    progressDisposable.dispose()
                }
            }
        }
    }
}
