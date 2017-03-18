import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

#if os(macOS)
    private typealias SignalKitTimer = SwiftSignalKitMac.Timer
#else
    private typealias SignalKitTimer = SwiftSignalKit.Timer
#endif

struct MediaPoolDownloadPart {
    let location: Api.InputFileLocation
    let offset: Int
    let length: Int
}

private final class DownloadRequest {
    
}

final class MediaPool {
    private let queue = Queue()
    
    private var downloads: [Int32: Download] = [:]
    private var inactiveDownloads = Set<Int32>()
    private var nextDownloadId: Int32 = 0
    private var collectInactiveDownloadsTimer: SignalKitTimer?
    
    private var requests = Bag<DownloadRequest>()
    
    private var interfaces = Bag<MediaPoolInterface>()
    
    init() {
        
    }
    
    private func takeInactiveDownload() {
        
    }
    
    func part(_ part: MediaPoolDownloadPart) -> Signal<Data, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                let index = self.requests.add(DownloadRequest())
                disposable.set(ActionDisposable {
                    self.queue.async {
                        self.requests.remove(index)
                    }
                })
            }
            return disposable
        }
    }
    
    func poolInterface() -> Signal<MediaPoolInterface, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                let index = self.interfaces.add(MediaPoolInterface())
                disposable.set(ActionDisposable {
                    self.queue.async {
                        self.interfaces.remove(index)
                        self.update()
                    }
                })
            }
            return disposable
        }
    }
    
    private func update() {
        
    }
}

final class MediaPoolInterface {
    func part(_ part: MediaPoolDownloadPart) -> Signal<Data, NoError> {
        return Signal { _ in
            return EmptyDisposable
        }
    }
}
