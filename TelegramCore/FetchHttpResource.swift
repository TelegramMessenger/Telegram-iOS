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

public func fetchHttpResource(url: String) -> Signal<MediaResourceDataFetchResult, NoError> {
    if let url = URL(string: url) {
        let signal = MTHttpRequestOperation.data(forHttpUrl: url)!
        return Signal { subscriber in
            subscriber.putNext(.reset)
            let disposable = signal.start(next: { next in
                let data = next as! Data
                let fetchResult: MediaResourceDataFetchResult = .dataPart(data: data, range: 0 ..< data.count, complete: true)
                subscriber.putNext(fetchResult)
                subscriber.putCompletion()
            })
            
            return ActionDisposable {
                disposable?.dispose()
            }
        }
    } else {
        return .never()
    }
}
