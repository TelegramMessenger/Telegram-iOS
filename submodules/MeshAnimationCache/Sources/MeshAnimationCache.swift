import Foundation
import LottieMeshSwift
import Postbox
import SwiftSignalKit
import GZip
import AppBundle

public final class MeshAnimationCache {
    private final class Item {
        var isPending: Bool = false
        let disposable = MetaDisposable()
        var readyPath: String?
        var animation: MeshAnimation?
    }

    private let mediaBox: MediaBox

    private var items: [String: Item] = [:]

    public init(mediaBox: MediaBox) {
        self.mediaBox = mediaBox
    }

    public func get(resource: MediaResource) -> MeshAnimation? {
        if let item = self.items[resource.id.stringRepresentation] {
            if let animation = item.animation {
                return animation
            } else if let readyPath = item.readyPath, let data = try? Data(contentsOf: URL(fileURLWithPath: readyPath), options: [.alwaysMapped]) {
                let buffer = MeshReadBuffer(data: data)
                let animation = MeshAnimation.read(buffer: buffer)
                item.animation = animation
                return animation
            } else {
                return nil
            }
        } else {
            let item = Item()
            self.items[resource.id.stringRepresentation] = item

            let path = self.mediaBox.cachedRepresentationPathForId(resource.id.stringRepresentation, representationId: "mesh-animation", keepDuration: .general)
            if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.alwaysMapped]) {
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
    
    public func get(bundleName: String) -> MeshAnimation? {
        if let item = self.items[bundleName] {
            if let animation = item.animation {
                return animation
            } else if let readyPath = item.readyPath, let data = try? Data(contentsOf: URL(fileURLWithPath: readyPath), options: [.alwaysMapped]) {
                let buffer = MeshReadBuffer(data: data)
                let animation = MeshAnimation.read(buffer: buffer)
                item.animation = animation
                return animation
            } else {
                return nil
            }
        } else {
            let item = Item()
            self.items[bundleName] = item

            let path = self.mediaBox.cachedRepresentationPathForId(bundleName, representationId: "mesh-animation", keepDuration: .general)
            if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.alwaysMapped]) {
                let animation = MeshAnimation.read(buffer: MeshReadBuffer(data: data))
                item.readyPath = path
                item.animation = animation
                return animation
            } else {
                self.cache(item: item, bundleName: bundleName)
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
                guard let zippedData = try? Data(contentsOf: URL(fileURLWithPath: data.path), options: [.alwaysMapped]) else {
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                    return EmptyDisposable
                }
                let jsonData = TGGUnzipData(zippedData, 1 * 1024 * 1024) ?? zippedData
                if let tempFile = generateMeshAnimation(data: jsonData) {
                    mediaBox.storeCachedResourceRepresentation(resource.id.stringRepresentation, representationId: "mesh-animation", keepDuration: .general, tempFile: tempFile, completion: { path in
                        if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.alwaysMapped]) {
                            let animation = MeshAnimation.read(buffer: MeshReadBuffer(data: data))
                            subscriber.putNext((animation, path))
                            subscriber.putCompletion()
                        } else {
                            subscriber.putNext(nil)
                            subscriber.putCompletion()
                        }
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
                if let item = strongSelf.items[resource.id.stringRepresentation] {
                    item.isPending = false
                    item.animation = animationAndPath.0
                    item.readyPath = animationAndPath.1
                }
            }
        }))
    }
    
    private func cache(item: Item, bundleName: String) {
        let mediaBox = self.mediaBox
        item.isPending = true
        item.disposable.set((Signal<(MeshAnimation, String)?, NoError> { subscriber in
            guard let path = getAppBundle().path(forResource: bundleName, ofType: "tgs") else {
                subscriber.putNext(nil)
                subscriber.putCompletion()
                return EmptyDisposable
            }
            
            guard let zippedData = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.alwaysMapped]) else {
                subscriber.putNext(nil)
                subscriber.putCompletion()
                return EmptyDisposable
            }
            let jsonData = TGGUnzipData(zippedData, 1 * 1024 * 1024) ?? zippedData
            if let tempFile = generateMeshAnimation(data: jsonData) {
                mediaBox.storeCachedResourceRepresentation(bundleName, representationId: "mesh-animation", keepDuration: .general, tempFile: tempFile, completion: { path in
                    if let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: [.alwaysMapped]) {
                        let animation = MeshAnimation.read(buffer: MeshReadBuffer(data: data))
                        subscriber.putNext((animation, path))
                        subscriber.putCompletion()
                    } else {
                        subscriber.putNext(nil)
                        subscriber.putCompletion()
                    }
                })
            } else {
                subscriber.putNext(nil)
                subscriber.putCompletion()
                return EmptyDisposable
            }

            return EmptyDisposable
        }
        |> runOn(Queue.concurrentDefaultQueue())
        |> deliverOnMainQueue).start(next: { [weak self] animationAndPath in
            guard let strongSelf = self else {
                return
            }
            if let animationAndPath = animationAndPath {
                if let item = strongSelf.items[bundleName] {
                    item.isPending = false
                    item.animation = animationAndPath.0
                    item.readyPath = animationAndPath.1
                }
            }
        }))
    }
}
