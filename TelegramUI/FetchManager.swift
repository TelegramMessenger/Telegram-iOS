import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

private struct FetchManagerLocationEntryId: Hashable {
    let resourceId: MediaResourceId
    let locationKey: FetchManagerLocationKey
    
    static func ==(lhs: FetchManagerLocationEntryId, rhs: FetchManagerLocationEntryId) -> Bool {
        if !lhs.resourceId.isEqual(to: rhs.resourceId) {
            return false
        }
        if !lhs.locationKey.isEqual(to: rhs.locationKey) {
            return false
        }
        return true
    }
    
    var hashValue: Int {
        return self.resourceId.hashValue &* 31 &+ self.locationKey.hashValue
    }
}

private final class FetchManagerLocationEntry {
    let id: FetchManagerLocationEntryId
    let resource: MediaResource
    
    var referenceCount: Int32 = 0
    var elevatedPriorityReferenceCount: Int32 = 0
    var userInitiatedPriorityIndices: [Int32] = []
    
    var priorityKey: FetchManagerPriorityKey? {
        if self.referenceCount > 0 {
            return FetchManagerPriorityKey(locationKey: self.id.locationKey, hasElevatedPriority: self.elevatedPriorityReferenceCount > 0, userInitiatedPriority: userInitiatedPriorityIndices.last)
        } else {
            return nil
        }
    }
    
    init(id: FetchManagerLocationEntryId, resource: MediaResource) {
        self.id = id
        self.resource = resource
    }
}

private final class FetchManagerCategoryLocationContext {
    private var topEntryIdAndPriority: (FetchManagerLocationEntryId, FetchManagerPriorityKey)?
    private var entries: [FetchManagerLocationEntryId: FetchManagerLocationEntry] = [:]
    
    func withEntry(id: FetchManagerLocationEntryId, resource: MediaResource, _ f: (FetchManagerLocationEntry) -> Void) {
        let entry: FetchManagerLocationEntry
        let previousPriorityKey: FetchManagerPriorityKey?
        if let current = self.entries[id] {
            entry = current
            previousPriorityKey = entry.priorityKey
        } else {
            previousPriorityKey = nil
            entry = FetchManagerLocationEntry(id: id, resource: resource)
            self.entries[id] = entry
        }
        
        f(entry)
        
        let updatedPriorityKey = entry.priorityKey
        if previousPriorityKey != updatedPriorityKey {
            if let updatedPriorityKey = updatedPriorityKey {
                if let (topId, topPriority) = self.topEntryIdAndPriority {
                    if updatedPriorityKey < topPriority {
                        self.topEntryIdAndPriority = (entry.id, updatedPriorityKey)
                    } else if updatedPriorityKey > topPriority && topId == id {
                        self.topEntryIdAndPriority = nil
                    }
                } else {
                    self.topEntryIdAndPriority = (entry.id, updatedPriorityKey)
                }
            } else {
                if self.topEntryIdAndPriority?.0 == id {
                    self.topEntryIdAndPriority = nil
                }
                self.entries.removeValue(forKey: id)
            }
        }
        
        if self.topEntryIdAndPriority == nil && !self.entries.isEmpty {
            var topEntryIdAndPriority: (FetchManagerLocationEntryId, FetchManagerPriorityKey)?
            for (id, entry) in self.entries {
                if let entryPriorityKey = entry.priorityKey {
                    if let (_, topKey) = topEntryIdAndPriority {
                        if entryPriorityKey < topKey {
                            topEntryIdAndPriority = (id, entryPriorityKey)
                        }
                    } else {
                        topEntryIdAndPriority = (id, entryPriorityKey)
                    }
                } else {
                    assertionFailure()
                }
            }
            
            self.topEntryIdAndPriority = topEntryIdAndPriority
        }
    }
    
    var isEmpty: Bool {
        return self.entries.isEmpty
    }
}

final class FetchManager {
    private let queue = Queue()
    private let network: Network
    
    private var categoryLocationContexts: [FetchManagerCategoryLocationKey: FetchManagerCategoryLocationContext] = [:]
    
    init(network: Network) {
        self.network = network
    }
    
    private func withLocationContext(_ key: FetchManagerCategoryLocationKey, _ f: (FetchManagerCategoryLocationContext) -> Void) {
        assert(self.queue.isCurrent())
        let context: FetchManagerCategoryLocationContext
        if let current = self.categoryLocationContexts[key] {
            context = current
        } else {
            context = FetchManagerCategoryLocationContext()
            self.categoryLocationContexts[key] = context
        }
        
        f(context)
        
        if context.isEmpty {
            self.categoryLocationContexts.removeValue(forKey: key)
        }
    }
    
    func interactivelyFetched(category: FetchManagerCategory, location: FetchManagerLocation, locationKey: FetchManagerLocationKey, resource: MediaResource, elevatedPriority: Bool, userInitiated: Bool) -> Signal<Void, NoError> {
        let queue = self.queue
        return Signal { [weak self] subscriber in
            if let strongSelf = self {
                strongSelf.withLocationContext(FetchManagerCategoryLocationKey(location: location, category: category), { context in
                    context.withEntry(id: FetchManagerLocationEntryId(resourceId: resource.id, locationKey: locationKey), resource: resource, { entry in
                        
                    })
                })
                
                return ActionDisposable {
                    queue.async {
                        if let strongSelf = self {
                            
                        }
                    }
                }
            } else {
                return EmptyDisposable
            }
        } |> runOn(self.queue)
    }
}
