import Foundation
import SwiftSignalKit
import ManagedFile

final class MediaBoxFileManager {
    enum Mode {
        case read
        case readwrite
    }
    
    enum AccessError: Error {
        case generic
    }
    
    final class Item {
        final class Accessor {
            private let file: ManagedFile
            
            init(file: ManagedFile) {
                self.file = file
            }
            
            func write(_ data: UnsafeRawPointer, count: Int) -> Int {
                return self.file.write(data, count: count)
            }
            
            func read(_ data: UnsafeMutableRawPointer, _ count: Int) -> Int {
                return self.file.read(data, count)
            }
            
            func readData(count: Int) -> Data {
                return self.file.readData(count: count)
            }
            
            func seek(position: Int64) -> Bool {
                return self.file.seek(position: position)
            }
        }
        
        weak var manager: MediaBoxFileManager?
        let path: String
        let mode: Mode
        
        weak var context: ItemContext?
        
        init(manager: MediaBoxFileManager, path: String, mode: Mode) {
            self.manager = manager
            self.path = path
            self.mode = mode
        }
        
        deinit {
            if let manager = self.manager, let context = self.context {
                manager.discardItemContext(context: context)
            }
        }
        
        func access(_ f: (Accessor) throws -> Void) throws {
            if let context = self.context {
                try f(Accessor(file: context.file))
            } else {
                if let manager = self.manager {
                    if let context = manager.takeContext(path: self.path, mode: self.mode) {
                        self.context = context
                        try f(Accessor(file: context.file))
                    } else {
                        throw AccessError.generic
                    }
                } else {
                    throw AccessError.generic
                }
            }
        }
        
        func sync() {
            if let context = self.context {
                context.sync()
            }
        }
    }
    
    final class ItemContext {
        let id: Int
        let path: String
        let mode: Mode
        let file: ManagedFile
        
        private var isDisposed: Bool = false
        
        init?(id: Int, path: String, mode: Mode) {
            let mappedMode: ManagedFile.Mode
            switch mode {
            case .read:
                mappedMode = .read
            case .readwrite:
                mappedMode = .readwrite
            }
            
            guard let file = ManagedFile(queue: nil, path: path, mode: mappedMode) else {
                return nil
            }
            self.file = file
            
            self.id = id
            self.path = path
            self.mode = mode
        }
        
        deinit {
            assert(self.isDisposed)
        }
        
        func dispose() {
            if !self.isDisposed {
                self.isDisposed = true
                self.file._unsafeClose()
            } else {
                assertionFailure()
            }
        }
        
        func sync() {
            self.file.sync()
        }
    }
    
    private let queue: Queue?
    private var contexts: [Int: ItemContext] = [:]
    private var nextItemId: Int = 0
    private let maxOpenFiles: Int
    
    init(queue: Queue?) {
        self.queue = queue
        self.maxOpenFiles = 16
    }
    
    func open(path: String, mode: Mode) -> Item? {
        if let queue = self.queue {
            assert(queue.isCurrent())
        }
        
        return Item(manager: self, path: path, mode: mode)
    }
    
    private func takeContext(path: String, mode: Mode) -> ItemContext? {
        if let queue = self.queue {
            assert(queue.isCurrent())
        }
        
        if self.contexts.count > self.maxOpenFiles {
            if let minKey = self.contexts.keys.min(), let context = self.contexts[minKey] {
                self.discardItemContext(context: context)
            }
        }
        
        let id = self.nextItemId
        self.nextItemId += 1
        let context = ItemContext(id: id, path: path, mode: mode)
        self.contexts[id] = context
        return context
    }
    
    private func discardItemContext(context: ItemContext) {
        if let queue = self.queue {
            assert(queue.isCurrent())
        }
        
        if let context = self.contexts.removeValue(forKey: context.id) {
            context.dispose()
        }
    }
}

