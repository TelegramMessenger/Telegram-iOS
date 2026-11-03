#if SSK_LEGACY
import SwiftSignalKitLegacy
#else
import SwiftSignalKit2
#endif
import Foundation

final class ProbeDisposable: Disposable {
    let trace: Trace

    init(_ trace: Trace) {
        self.trace = trace
    }

    deinit {
        self.trace.log("deinit D")
    }

    func dispose() {
        self.trace.log("D dispose")
    }
}

public func releaseOrderProbe() -> [String: [String]] {
    var result: [String: [String]] = [:]

    enum Terminate {
        case completion
        case error
        case dispose
        case releaseSubscriber
    }

    for terminate in [Terminate.completion, .error, .dispose, .releaseSubscriber] {
        for keepHandle in [true, false] {
            for keepAlive in [true, false] {
                let trace = Trace()
                var captured: Subscriber<Int, Int>?
                var handle: Disposable?
                do {
                    let n = Sentinel("N", trace)
                    let e = Sentinel("E", trace)
                    let c = Sentinel("C", trace)
                    let signal = Signal<Int, Int> { subscriber in
                        if keepAlive {
                            subscriber.keepAlive(Sentinel("K", trace))
                        }
                        captured = subscriber
                        return ProbeDisposable(trace)
                    }
                    handle = signal.start(next: { _ in
                        n.touch()
                        trace.log("next")
                    }, error: { _ in
                        e.touch()
                        trace.log("error")
                    }, completed: {
                        c.touch()
                        trace.log("completed")
                    })
                }
                if !keepHandle {
                    handle = nil
                }
                trace.log("begin")
                switch terminate {
                case .completion:
                    captured?.putCompletion()
                case .error:
                    captured?.putError(1)
                case .dispose:
                    handle?.dispose()
                case .releaseSubscriber:
                    captured = nil
                }
                trace.log("end")
                captured = nil
                trace.log("subscriber released")
                handle = nil
                trace.log("handle released")
                result["\(terminate) keepHandle=\(keepHandle) keepAlive=\(keepAlive)"] = trace.events
            }
        }
    }

    for keepAlive in [true, false] {
        let trace = Trace()
        var captured: Subscriber<Int, Int>?
        let box = HandleBox()
        do {
            let n = Sentinel("N", trace)
            let c = Sentinel("C", trace)
            let signal = Signal<Int, Int> { subscriber in
                if keepAlive {
                    subscriber.keepAlive(Sentinel("K", trace))
                }
                captured = subscriber
                return ProbeDisposable(trace)
            }
            box.disposable = signal.start(next: { _ in
                n.touch()
                trace.log("next")
                box.disposable?.dispose()
                trace.log("after self-dispose")
            }, completed: {
                c.touch()
                trace.log("completed")
                box.disposable?.dispose()
                trace.log("after self-dispose in completed")
            })
        }
        trace.log("begin next")
        captured?.putNext(1)
        trace.log("begin completion")
        captured?.putCompletion()
        trace.log("end")
        captured = nil
        trace.log("subscriber released")
        box.disposable = nil
        trace.log("handle released")
        result["self-dispose keepAlive=\(keepAlive)"] = trace.events
    }

    do {
        let trace = Trace()
        var captured: Subscriber<Int, Int>?
        let box = HandleBox()
        do {
            let c = Sentinel("C", trace)
            let signal = Signal<Int, Int> { subscriber in
                subscriber.keepAlive(Sentinel("K", trace))
                captured = subscriber
                return ProbeDisposable(trace)
            }
            box.disposable = signal.start(completed: {
                c.touch()
                trace.log("completed")
                box.disposable?.dispose()
                trace.log("after self-dispose in completed")
            })
        }
        trace.log("begin completion")
        captured?.putCompletion()
        trace.log("end")
        captured = nil
        box.disposable = nil
        trace.log("released")
        result["complete-then-self-dispose"] = trace.events
    }

    return result
}
