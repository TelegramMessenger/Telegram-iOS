import Foundation
import TelegramCore
import SwiftSignalKit
import Postbox

func fetchOpenInAppIconResource(resource: OpenInAppIconResource) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return Signal { subscriber in
        subscriber.putNext(.reset)

        let metaUrl = "https://itunes.apple.com/lookup?id=\(resource.appStoreId)"
        
        let fetchDisposable = MetaDisposable()
        
        let disposable = fetchHttpResource(url: metaUrl).start(next: { result in
            if case let .dataPart(_, data, _, complete) = result, complete {
                guard let dict = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
                    subscriber.putNext(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: true))
                    subscriber.putCompletion()
                    return
                }
                
                guard let results = dict["results"] as? [Any] else {
                    subscriber.putNext(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: true))
                    subscriber.putCompletion()
                    return
                }
                
                guard let result = results.first as? [String: Any] else {
                    subscriber.putNext(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: true))
                    subscriber.putCompletion()
                    return
                }
                
                guard let artworkUrl = result["artworkUrl100"] as? String else {
                    subscriber.putNext(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: true))
                    subscriber.putCompletion()
                    return
                }
                
                if artworkUrl.isEmpty {
                    subscriber.putNext(.dataPart(resourceOffset: 0, data: Data(), range: 0 ..< 0, complete: true))
                    subscriber.putCompletion()
                    return
                } else {
                    fetchDisposable.set(fetchHttpResource(url: artworkUrl).start(next: { next in
                        subscriber.putNext(next)
                    }, completed: {
                        subscriber.putCompletion()
                    }))
                }
            }
        })
        
        return ActionDisposable {
            disposable.dispose()
            fetchDisposable.dispose()
        }
    }
}
