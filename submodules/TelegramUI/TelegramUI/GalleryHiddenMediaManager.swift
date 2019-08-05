import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import AsyncDisplayKit
import AccountContext

private final class GalleryHiddenMediaContext {
    private var ids = Set<Int32>()
    
    func add(id: Int32) {
        self.ids.insert(id)
    }
    
    func remove(id: Int32) {
        self.ids.remove(id)
    }
    
    var isEmpty: Bool {
        return self.ids.isEmpty
    }
}

private final class GalleryHiddenMediaTargetHolder {
    weak var target: GalleryHiddenMediaTarget?
    
    init(target: GalleryHiddenMediaTarget?) {
        self.target = target
    }
}

final class GalleryHiddenMediaManagerImpl: GalleryHiddenMediaManager {
    private var nextId: Int32 = 0
    private var contexts: [GalleryHiddenMediaId: GalleryHiddenMediaContext] = [:]
    
    private var sourcesDisposables = Bag<Disposable>()
    private var subscribers = Bag<(Set<GalleryHiddenMediaId>) -> Void>()
    
    private var targets: [GalleryHiddenMediaTargetHolder] = []
    
    func hiddenIds() -> Signal<Set<GalleryHiddenMediaId>, NoError> {
        return Signal { [weak self] subscriber in
            let disposable = MetaDisposable()
            Queue.mainQueue().async {
                if let strongSelf = self {
                    subscriber.putNext(Set(strongSelf.contexts.keys))
                    let index = strongSelf.subscribers.add({ next in
                        subscriber.putNext(next)
                    })
                    disposable.set(ActionDisposable {
                        Queue.mainQueue().async {
                            if let strongSelf = self {
                                strongSelf.subscribers.remove(index)
                            }
                        }
                    })
                }
            }
            return disposable
        }
    }
    
    private func withContext(id: GalleryHiddenMediaId, _ f: (GalleryHiddenMediaContext) -> Void) {
        let context: GalleryHiddenMediaContext
        if let current = self.contexts[id] {
            context = current
        } else {
            context = GalleryHiddenMediaContext()
            self.contexts[id] = context
        }
        
        let wasEmpty = context.isEmpty
        
        f(context)
        
        if context.isEmpty {
            self.contexts.removeValue(forKey: id)
        }
        
        if context.isEmpty != wasEmpty {
            let allIds = Set(self.contexts.keys)
            for subscriber in self.subscribers.copyItems() {
                subscriber(allIds)
            }
        }
    }
    
    func addSource(_ signal: Signal<GalleryHiddenMediaId?, NoError>) -> Int {
        var state: (GalleryHiddenMediaId, Int32)?
        let index = self.sourcesDisposables.add((signal |> deliverOnMainQueue).start(next: { [weak self] id in
            if let strongSelf = self {
                if id != state?.0 {
                    if let (previousId, previousIndex) = state {
                        strongSelf.removeHiddenMedia(id: previousId, index: previousIndex)
                        state = nil
                    }
                    if let id = id {
                        state = (id, strongSelf.addHiddenMedia(id: id))
                    }
                }
            }
        }))
        return index
    }
    
    func removeSource(_ index: Int) {
        if let disposable = self.sourcesDisposables.get(index) {
            self.sourcesDisposables.remove(index)
            disposable.dispose()
        }
    }
    
    func addTarget(_ target: GalleryHiddenMediaTarget) {
        self.targets.append(GalleryHiddenMediaTargetHolder(target: target))
    }
    
    func removeTarget(_ target: GalleryHiddenMediaTarget) {
        for i in (0 ..< self.targets.count).reversed() {
            let holderTarget = self.targets[i].target
            if holderTarget == nil || holderTarget === target {
                self.targets.remove(at: i)
            }
        }
    }
    
    func findTarget(messageId: MessageId, media: Media) -> ((UIView) -> Void, ASDisplayNode, () -> (UIView?, UIView?))? {
        for i in (0 ..< self.targets.count).reversed() {
            if let holderTarget = self.targets[i].target {
                if let result = holderTarget.getTransitionInfo(messageId: messageId, media: media) {
                    return result
                }
            } else {
                self.targets.remove(at: i)
            }
        }
        return nil
    }
    
    private func addHiddenMedia(id: GalleryHiddenMediaId) -> Int32 {
        let itemId = self.nextId
        self.nextId += 1
        self.withContext(id: id, { context in
            context.add(id: itemId)
        })
        return itemId
    }
    
    private func removeHiddenMedia(id: GalleryHiddenMediaId, index: Int32) {
        self.withContext(id: id, { context in
            context.remove(id: index)
        })
    }
}
