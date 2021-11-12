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
    private final class SourceContext {
        let disposable: Disposable
        var state: (GalleryHiddenMediaId, Int32)? = nil

        init(disposable: Disposable) {
            self.disposable = disposable
        }
    }

    private var sources = Bag<Void>()
    private var sourceContexts: [Int: SourceContext] = [:]

    private var nextId: Int32 = 0
    private var contexts: [GalleryHiddenMediaId: GalleryHiddenMediaContext] = [:]

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
        let index = self.sources.add(Void())
        let disposable = MetaDisposable()
        let context = SourceContext(disposable: disposable)
        self.sourceContexts[index] = context

        disposable.set((signal |> deliverOnMainQueue).start(next: { [weak self, weak context] id in
            guard let strongSelf = self, let context = context else {
                return
            }
            if id != context.state?.0 {
                if let (previousId, previousIndex) = context.state {
                    strongSelf.removeHiddenMedia(id: previousId, index: previousIndex)
                    context.state = nil
                }
                if let id = id {
                    context.state = (id, strongSelf.addHiddenMedia(id: id))
                }
            }
        }))

        return index

        /*let index = self.sourcesDisposables.add((signal |> deliverOnMainQueue).start(next: { [weak self] id in
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
        return index*/
    }
    
    func removeSource(_ index: Int) {
        self.sources.remove(index)

        if let context = self.sourceContexts.removeValue(forKey: index) {
            context.disposable.dispose()
            if let (previousId, previousIndex) = context.state {
                self.removeHiddenMedia(id: previousId, index: previousIndex)
            }
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
