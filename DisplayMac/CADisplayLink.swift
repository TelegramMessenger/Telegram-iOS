import Foundation
import CoreVideo
import SwiftSignalKitMac

private final class CADisplayLinkContext {
    weak var impl: CADisplayLink?
    
    init(_ impl: CADisplayLink) {
        self.impl = impl
    }
}

private final class CADisplayLinkContexts {
    private var nextId: Int32 = 0
    var contexts: [Int32: CADisplayLinkContext] = [:]
    
    func add(_ impl: CADisplayLink) -> Int32 {
        let id = self.nextId
        self.nextId += 1
        self.contexts[id] = CADisplayLinkContext(impl)
        return id
    }
    
    func remove(_ id: Int32) {
        self.contexts.removeValue(forKey: id)
    }
    
    func get(id: Int32) -> CADisplayLink? {
        return self.contexts[id]?.impl
    }
}

private let contexts = Atomic<CADisplayLinkContexts>(value: CADisplayLinkContexts())

public final class CADisplayLink {
    private var id: Int32?
    private var displayLink: CVDisplayLink?
    
    public var isPaused: Bool = true {
        didSet {
            if self.isPaused != oldValue {
                
            }
        }
    }
    
    private let target: Any?
    private let action: Selector?
    
    init(target: Any?, selector: Selector?) {
        self.target = target
        self.action = selector
        
        let id = contexts.with { contexts in
            return contexts.add(self)
        }
        self.id = id
        CVDisplayLinkCreateWithActiveCGDisplays(&self.displayLink)
        if let displayLink = self.displayLink {
            CVDisplayLinkSetOutputCallback(displayLink, { _, _, _, _, _, ref in
                let id: Int32 = Int32(unsafeBitCast(ref, to: intptr_t.self))
                if let impl = (contexts.with { contexts in
                    return contexts.get(id: id)
                }) {
                    impl.performAction()
                }
                return kCVReturnSuccess
            }, UnsafeMutableRawPointer(bitPattern: Int(id)))
        }
    }
    
    deinit {
        if let id = self.id {
            contexts.with { contexts in
                contexts.remove(id)
            }
        }
    }
    
    public func invalidate() {
        
    }
    
    private func performAction() {
        if let target = self.target, let action = self.action {
            let _ = (target as? AnyObject)?.perform(action)
        }
    }
}
