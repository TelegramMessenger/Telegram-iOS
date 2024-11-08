import Foundation
import UIKit
import JavaScriptCore
import TelegramCore
import SwiftSignalKit

private var ObjCKey_ContextReference: Int?

@objc private protocol JsCorePolyfillsExport: JSExport {
    func postMessage(_ object: JSValue)
    func consoleLog(_ object: JSValue)
    func consoleLog(_ object: JSValue, _ arg1: JSValue)
    func consoleLog(_ object: JSValue, _ arg1: JSValue, _ arg2: JSValue)
    func performanceNow() -> Double
}

@objc private final class JsCorePolyfills: NSObject, JsCorePolyfillsExport {
    private let queue: Queue
    private let context: WebViewNativeJSContextImpl.Reference
    
    init(queue: Queue, context: WebViewNativeJSContextImpl.Reference) {
        self.queue = queue
        self.context = context
        
        super.init()
    }
    
    @objc func postMessage(_ object: JSValue) {
        guard object.isObject else {
            return
        }
        guard let message = object.toDictionary() as? [String: Any] else {
            return
        }
        let context = self.context
        self.queue.async {
            guard let context = context.context else {
                return
            }
            let handleScriptMessage = context.handleScriptMessage
            
            Queue.mainQueue().async {
                handleScriptMessage(message)
            }
        }
    }
    
    @objc func consoleLog(_ object: JSValue) {
        #if DEBUG
        print("\(object)")
        #endif
    }
    
    @objc func consoleLog(_ object: JSValue, _ arg1: JSValue) {
        #if DEBUG
        print("\(object) \(arg1)")
        #endif
    }
    
    @objc func consoleLog(_ object: JSValue, _ arg1: JSValue, _ arg2: JSValue) {
        #if DEBUG
        print("\(object) \(arg1) \(arg2)")
        #endif
    }
    
    @objc func performanceNow() -> Double {
        return CFAbsoluteTimeGetCurrent()
    }
}

@objc private protocol TimerJSExport: JSExport {
    func setTimeout(_ callback: JSValue, _ ms: Double) -> Int32
    func setInterval(_ callback: JSValue, _ ms: Double) -> Int32
    
    func clearTimeout(_ id: Int32)
}

@objc private class TimeoutPolyfill: NSObject, TimerJSExport {
    private let queue: Queue
    
    private var timers: [Int32: SwiftSignalKit.Timer] = [:]
    private var nextId: Int32 = 0

    init(queue: Queue) {
        self.queue = queue
    }
    
    deinit {
        for (_, timer) in self.timers {
            timer.invalidate()
        }
    }
    
    func register(jsContext: JSContext) {
        jsContext.evaluateScript("""
        function setTimeout(...args) {
            if (args.length === 0) {
                return -1;
            }

            const [callback, delay = 0, ...callbackArgs] = args;

            return _timeoutPolyfill.setTimeout(() => {
                callback(...callbackArgs);
            }, delay);
        }
        
        function setInterval(...args) {
            if (args.length === 0) {
                return -1;
            }

            const [callback, delay = 0, ...callbackArgs] = args;

            return _timeoutPolyfill.setInterval(() => {
                callback(...callbackArgs);
            }, delay);
        }
        
        function clearTimeout(indentifier) {
            _timeoutPolyfill.clearTimeout(indentifier)
        }
        
        function clearInterval(indentifier) {
            _timeoutPolyfill.clearTimeout(indentifier)
        }
        """
        )
    }

    func clearTimeout(_ id: Int32) {
        let timer = self.timers.removeValue(forKey: id)
        timer?.invalidate()
    }

    func setTimeout(_ callback: JSValue, _ ms: Double) -> Int32 {
        return self.createTimer(callback: callback, ms: ms, repeats: false)
    }
    
    func setInterval(_ callback: JSValue, _ ms: Double) -> Int32 {
        return self.createTimer(callback: callback, ms: ms, repeats: true)
    }

    func createTimer(callback: JSValue, ms: Double, repeats: Bool) -> Int32 {
        let timeInterval = ms / 1000.0
        
        let id = self.nextId
        self.nextId += 1
        let timer = SwiftSignalKit.Timer(timeout: timeInterval, repeat: repeats, completion: { [weak self] in
            guard let self else {
                return
            }
            callback.call(withArguments: nil)
            
            if !repeats {
                self.timers.removeValue(forKey: id)
            }
        }, queue: self.queue)
        self.timers[id] = timer
        timer.start()
        
        return id
    }
}

final class WebViewNativeJSContextImpl: HLSJSContext {
    fileprivate final class Reference {
        weak var context: WebViewNativeJSContextImpl.Impl?
        
        init(context: WebViewNativeJSContextImpl.Impl) {
            self.context = context
        }
    }
    
    fileprivate final class Impl {
        let queue: Queue
        let context: JSContext
        let handleScriptMessage: ([String: Any]) -> Void
        
        init(queue: Queue, handleScriptMessage: @escaping ([String: Any]) -> Void) {
            self.queue = queue
            self.context = JSContext()
            self.handleScriptMessage = handleScriptMessage
            
            #if DEBUG
            if #available(iOS 16.4, *) {
                self.context.isInspectable = true
            }
            #endif
            
            self.context.exceptionHandler = { context, exception in
                if let exception {
                    Logger.shared.log("WebViewNativeJSContextImpl", "JS exception: \(exception)")
                    #if DEBUG
                    print("JS exception: \(exception)")
                    #endif
                }
            }
            
            let timeoutPolyfill = TimeoutPolyfill(queue: self.queue)
            self.context.setObject(timeoutPolyfill, forKeyedSubscript: "_timeoutPolyfill" as (NSCopying & NSObjectProtocol))
            timeoutPolyfill.register(jsContext: self.context)
            
            self.context.setObject(JsCorePolyfills(queue: self.queue, context: Reference(context: self)), forKeyedSubscript: "_JsCorePolyfills" as (NSCopying & NSObjectProtocol))
            
            let bundle = Bundle(for: WebViewHLSJSContextImpl.self)
            let bundlePath = bundle.bundlePath + "/HlsBundle.bundle"
            if let indexJsString = try? String(contentsOf: URL(fileURLWithPath: bundlePath + "/headless_prologue.js"), encoding: .utf8) {
                self.context.evaluateScript(indexJsString, withSourceURL: URL(fileURLWithPath: "index/index.bundle.js"))
            } else {
                assertionFailure()
            }
            
            if let indexJsString = try? String(contentsOf: URL(fileURLWithPath: bundlePath + "/index.bundle.js"), encoding: .utf8) {
                self.context.evaluateScript(indexJsString, withSourceURL: URL(fileURLWithPath: "index.bundle.js"))
            } else {
                assertionFailure()
            }
        }
        
        deinit {
            print("WebViewNativeJSContextImpl.deinit")
        }
        
        func evaluateJavaScript(_ string: String) {
            self.context.evaluateScript(string)
        }
    }
    
    static let sharedQueue = Queue(name: "WebViewNativeJSContextImpl", qos: .default)
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    init(handleScriptMessage: @escaping ([String: Any]) -> Void) {
        let queue = WebViewNativeJSContextImpl.sharedQueue
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, handleScriptMessage: handleScriptMessage)
        })
    }
    
    func evaluateJavaScript(_ string: String) {
        self.impl.with { impl in
            impl.evaluateJavaScript(string)
        }
    }
}
