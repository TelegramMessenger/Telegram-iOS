import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit

public func fetchHttpResource(url: String, preserveExactUrl: Bool = false) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    var urlString: String? = url
    if !preserveExactUrl {
        urlString = url.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
    }
    if let urlString, let url = URL(string: urlString) {
        let signal = MTHttpRequestOperation.data(forHttpUrl: url)!
        return Signal { subscriber in
            subscriber.putNext(.reset)
            let disposable = signal.start(next: { next in
                if let response = next as? MTHttpResponse {
                    let fetchResult: MediaResourceDataFetchResult = .dataPart(resourceOffset: 0, data: response.data, range: 0 ..< Int64(response.data.count), complete: true)
                    subscriber.putNext(fetchResult)
                    subscriber.putCompletion()
                } else {
                    subscriber.putError(.generic)
                }
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
