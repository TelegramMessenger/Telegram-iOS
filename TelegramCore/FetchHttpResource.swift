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

func fetchHttpResource(url: String) -> Signal<MediaResourceDataFetchResult, NoError> {
    if let url = URL(string: url) {
        let signal = MTHttpRequestOperation.data(forHttpUrl: url)!
        return Signal { subscriber in
            let disposable = signal.start(next: { next in
                let fetchResult = MediaResourceDataFetchResult(data: next as! Data, complete: true)
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
