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

public func screenCaptureEvents() -> Signal<ScreenCaptureEvent, NoError> {
    return Signal { subscriber in
        let observer = NotificationCenter.default.addObserver(forName: UIApplication.userDidTakeScreenshotNotification, object: nil, queue: .main, using: { _ in
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
                NotificationCenter.default.removeObserver(observer)
                screenRecordingDisposable.dispose()
            }
        }
    }
    |> runOn(Queue.mainQueue())
}

public final class ScreenCaptureDetectionManager {
    private var observer: NSObjectProtocol?
    private var screenRecordingDisposable: Disposable?
    private var screenRecordingCheckTimer: SwiftSignalKit.Timer?
    
    public init(check: @escaping () -> Bool) {
        self.observer = NotificationCenter.default.addObserver(forName: UIApplication.userDidTakeScreenshotNotification, object: nil, queue: .main, using: { [weak self] _ in
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
        if let observer = self.observer {
            NotificationCenter.default.removeObserver(observer)
        }
        self.screenRecordingDisposable?.dispose()
        self.screenRecordingCheckTimer?.invalidate()
        self.screenRecordingCheckTimer = nil
    }
}
