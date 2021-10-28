import Foundation
import LottieMeshSwift
import Postbox
import SwiftSignalKit
import GZip

#error("Exclude")

public final class MeshAnimationCache {
    private final class Item {
        var isPending: Bool = false
        let disposable = MetaDisposable()
        var readyPath: String?
        var animation: MeshAnimation?
    }

    private let mediaBox: MediaBox

    private var items: [MediaResourceId: Item] = [:]

    public init(mediaBox: MediaBox) {
        self.mediaBox = mediaBox
    }

    public func get(resource: MediaResource) -> MeshAnimation? {
        if let item = self.items[resource.id] {
            if let animation = item.animation {
                return animation
            } else if let readyPath = item.readyPath, let data = try? Data(contentsOf: URL(fileURLWithPath: readyPath)) {
                let buffer = MeshReadBuffer(data: data)
                let animation = MeshAnimation.read(buffer: buffer)
                item.animation = animation
                return animation
            } else {
                return nil
            }
        } else {
            let item = Item()
            self.items[resource.id] = item

            let path = self.mediaBox.cachedRepresentationPathForId(resource.id.stringRepresentation, representationId: "mesh-animation", keepDuration: .general)
            if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                let animation = MeshAnimation.read(buffer: MeshReadBuffer(data: data))
                item.readyPath = path
                item.animation = animation
                return animation
            } else {
                self.cache(item: item, resource: resource)
                return nil
            }
        }
    }

    private func cache(item: Item, resource: MediaResource) {
        let mediaBox = self.mediaBox
        item.isPending = true
        item.disposable.set((self.mediaBox.resourceData(resource)
        |> filter { data in
            return data.complete
        }
        |> take(1)
        |> mapToSignal { data -> Signal<(MeshAnimation, String)?, NoError> in
            return Signal { subscriber in
                guard let zippedData = try? Data(contentsOf: URL(fileURLWithPath: data.path)) else {
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                    return EmptyDisposable
                }
                let jsonData = TGGUnzipData(zippedData, 1 * 1024 * 1024) ?? zippedData
                if let animation = generateMeshAnimation(data: jsonData) {
                    let buffer = MeshWriteBuffer()
                    animation.write(buffer: buffer)
                    mediaBox.storeCachedResourceRepresentation(resource, representationId: "mesh-animation", keepDuration: .general, data: buffer.makeData(), completion: { path in
                        subscriber.putNext((animation, path))
                        subscriber.putCompletion()
                    })
                } else {
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                    return EmptyDisposable
                }

                return EmptyDisposable
            }
            |> runOn(Queue.concurrentBackgroundQueue())
        }
        |> deliverOnMainQueue).start(next: { [weak self] animationAndPath in
            guard let strongSelf = self else {
                return
            }
            if let animationAndPath = animationAndPath {
                if let item = strongSelf.items[resource.id] {
                    item.isPending = false
                    item.animation = animationAndPath.0
                    item.readyPath = animationAndPath.1
                }
            }
        }))
    }
}
