import Foundation
import SwiftSignalKit
import UIKit

public enum ScreenCaptureEvent {
    case still
    case video
}

private final class ScreenRecordingObserver: NSObject {
    let f: (Bool) -> Void
    
    init(_ f: @escaping (Bool) -> Void) {
        self.f = f
        
        super.init()
        
        UIScreen.main.addObserver(self, forKeyPath: "captured", options: [.new], context: nil)
    }
    
    func clear() {
        UIScreen.main.removeObserver(self, forKeyPath: "captured")
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "captured" {
            if let value = change?[.newKey] as? Bool {
                self.f(value)
            }
        }
    }
}

private func screenRecordingActive() -> Signal<Bool, NoError> {
    return Signal { subscriber in
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            subscriber.putNext(UIScreen.main.isCaptured)
            let observer = ScreenRecordingObserver({ value in
                subscriber.putNext(value)
            })
            return ActionDisposable {
                Queue.mainQueue().async {
                    observer.clear()
                }
            }
        } else {
            subscriber.putNext(false)
            return EmptyDisposable
        }
    } |> runOn(Queue.mainQueue())
}

// UIKit can deliver userDidTakeScreenshotNotification more than once for a single screenshot
// (observed: two back-to-back deliveries to the same observer), which reported every secret-chat
// screenshot twice. Each observer drops a repeat that arrives within this interval of the previous
// one. The state is per observer, never shared: a shared stamp would make the second of two
// legitimate observers (a chat and a gallery over it) discard the same screenshot.
private let screenshotRepeatInterval: CFAbsoluteTime = 0.5

private final class ScreenshotNotificationObserver {
    private var observer: NSObjectProtocol?
    private var lastTimestamp: CFAbsoluteTime?
    
    init(_ f: @escaping () -> Void) {
        self.observer = NotificationCenter.default.addObserver(forName: UIApplication.userDidTakeScreenshotNotification, object: nil, queue: .main, using: { [weak self] _ in
            guard let self else {
                return
            }
            let timestamp = CFAbsoluteTimeGetCurrent()
            if let lastTimestamp = self.lastTimestamp, timestamp - lastTimestamp < screenshotRepeatInterval {
                return
            }
            self.lastTimestamp = timestamp
            f()
        })
    }
    
    func clear() {
        if let observer = self.observer {
            self.observer = nil
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    deinit {
        self.clear()
    }
}

public func screenCaptureEvents() -> Signal<ScreenCaptureEvent, NoError> {
    return Signal { subscriber in
        let observer = ScreenshotNotificationObserver({
            subscriber.putNext(.still)
        })
        
        var previous = false
        let screenRecordingDisposable = screenRecordingActive().start(next: { value in
            if value != previous {
                previous = value
                if value {
                    subscriber.putNext(.video)
                }
            }
        })
        
        return ActionDisposable {
            Queue.mainQueue().async {
                observer.clear()
                screenRecordingDisposable.dispose()
            }
        }
    }
    |> runOn(Queue.mainQueue())
}

public final class ScreenCaptureDetectionManager {
    private var observer: ScreenshotNotificationObserver?
    private var screenRecordingDisposable: Disposable?
    private var screenRecordingCheckTimer: SwiftSignalKit.Timer?
    
    public var isRecordingActive = false
    
    public init(check: @escaping () -> Bool) {
        self.observer = ScreenshotNotificationObserver({ [weak self] in
            guard let _ = self else {
                return
            }
            let _ = check()
        })
        
        self.screenRecordingDisposable = screenRecordingActive().start(next: { [weak self] value in
            Queue.mainQueue().async {
                guard let strongSelf = self else {
                    return
                }
                var value = value
#if DEBUG
                value = !"".isEmpty
#endif          
                strongSelf.isRecordingActive = value
                if value {
                    if strongSelf.screenRecordingCheckTimer == nil {
                        strongSelf.screenRecordingCheckTimer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: {
                            guard let strongSelf = self else {
                                return
                            }
                            if check() {
                                strongSelf.screenRecordingCheckTimer?.invalidate()
                                strongSelf.screenRecordingCheckTimer = nil
                            }
                        }, queue: Queue.mainQueue())
                        strongSelf.screenRecordingCheckTimer?.start()
                    }
                } else if strongSelf.screenRecordingCheckTimer != nil {
                    strongSelf.screenRecordingCheckTimer?.invalidate()
                    strongSelf.screenRecordingCheckTimer = nil
                }
            }
        })
    }
    
    deinit {
        self.observer?.clear()
        self.screenRecordingDisposable?.dispose()
        self.screenRecordingCheckTimer?.invalidate()
        self.screenRecordingCheckTimer = nil
    }
}
