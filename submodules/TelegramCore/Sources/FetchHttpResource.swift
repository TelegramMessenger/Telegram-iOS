import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit

public func fetchHttpResource(url: String) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    if let url = URL(string: url) {
        let signal = MTHttpRequestOperation.data(forHttpUrl: url)!
        return Signal { subscriber in
            subscriber.putNext(.reset)
            let disposable = signal.start(next: { next in
                let data = next as! Data
                let fetchResult: MediaResourceDataFetchResult = .dataPart(resourceOffset: 0, data: data, range: 0 ..< data.count, complete: true)
                subscriber.putNext(fetchResult)
                subscriber.putCompletion()
            }, error: { _ in
                subscriber.putError(.generic)
            }, completed: {
            })
            
            return ActionDisposable {
                disposable?.dispose()
            }
        }
    } else {
        return .never()
    }
}
