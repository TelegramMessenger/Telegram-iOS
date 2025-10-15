import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import FileMediaResourceStatus
import ZipArchive

private let queue = Queue()

public enum AgeVerificationAvailability {
    case available(String, Bool)
    case progress(Float)
    case unavailable
}

private var forceCoreMLVariant: Bool {
#if targetEnvironment(simulator)
    return true
#else
    return false
#endif
}

private func modelPath() -> String {
    return NSTemporaryDirectory() + "AgeNet.mlmodelc"
}
private let modelPeer = "agecomputation"

private func legacyModelPath() -> String {
    return NSTemporaryDirectory() + "AgeNetLegacy.mlmodelc"
}
private let legacyModelPeer = "agelegacycomputation"

public func ageVerificationAvailability(context: AccountContext) -> Signal<AgeVerificationAvailability, NoError> {
    let compiledModelPath: String
    let modelPeerName: String
    let isLegacy: Bool
    if #available(iOS 15.0, *) {
        compiledModelPath = modelPath()
        modelPeerName = modelPeer
        isLegacy = false
    } else {
        compiledModelPath = legacyModelPath()
        modelPeerName = legacyModelPeer
        isLegacy = true
    }
    if FileManager.default.fileExists(atPath: compiledModelPath) {
        return .single(.available(compiledModelPath, isLegacy))
    }
    return context.engine.peers.resolvePeerByName(name: modelPeerName, referrer: nil)
    |> mapToSignal { result -> Signal<AgeVerificationAvailability, NoError> in
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
        |> mapToSignal { maybeFileAndMessage -> Signal<AgeVerificationAvailability, NoError> in
            if let (file, message) = maybeFileAndMessage {
                let fetchedData = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .other, userContentType: .file, reference: FileMediaReference.message(message: MessageReference(message._asMessage()), media: file).resourceReference(file.resource))
                
                enum FetchStatus {
                    case completed(String)
                    case progress(Float)
                    case failed
                }
                                    
                let fetchStatus = Signal<FetchStatus, NoError> { subscriber in
                    let fetchedDisposable = fetchedData.start()
                    let resourceDataDisposable = context.account.postbox.mediaBox.resourceData(file.resource, attemptSynchronously: false).start(next: { next in
                        if next.complete {
                            SSZipArchive.unzipFile(atPath: next.path, toDestination: NSTemporaryDirectory())
                            subscriber.putNext(.completed(compiledModelPath))
                            subscriber.putCompletion()
                        }
                    }, error: subscriber.putError, completed: subscriber.putCompletion)
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
                return fetchStatus
                |> mapToSignal { status -> Signal<AgeVerificationAvailability, NoError> in
                    switch status {
                    case .completed:
                        return .single(.available(compiledModelPath, isLegacy))
                    case let .progress(progress):
                        return .single(.progress(progress))
                    case .failed:
                        return .single(.unavailable)
                    }
                }
            } else {
                return .single(.unavailable)
            }
        }
    }
}
