import Foundation
import NGLogging
import SwiftSignalKit

public enum RequestsError {
    case network
}

public func RequestsDownload(url: URL) -> Signal<(Data, URLResponse?), RequestsError> {
    return Signal { subscriber in
        let completed = Atomic<Bool>(value: false)
        let downloadTask = URLSession.shared.downloadTask(with: url, completionHandler: { location, response, _ in
            _ = completed.swap(true)
            if let location = location, let data = try? Data(contentsOf: location) {
                subscriber.putNext((data, response))
                subscriber.putCompletion()
            } else {
                subscriber.putError(.network)
            }
        })
        downloadTask.resume()

        return ActionDisposable {
            if !completed.with({ $0 }) {
                downloadTask.cancel()
            }
        }
    }
}

public func RequestsGet(url: URL) -> Signal<(Data, URLResponse?), RequestsError> {
    return Signal { subscriber in
        let completed = Atomic<Bool>(value: false)
        let urlTask = URLSession.shared.dataTask(with: url, completionHandler: { data, response, _ in
            _ = completed.swap(true)
            if let strongData = data {
                subscriber.putNext((strongData, response))
                subscriber.putCompletion()
            } else {
                subscriber.putError(.network)
            }
        })
        urlTask.resume()

        return ActionDisposable {
            if !completed.with({ $0 }) {
                urlTask.cancel()
            }
        }
    }
}


public func RequestsCustom(request: URLRequest) -> Signal<(Data, URLResponse?), RequestsError> {
    return Signal { subscriber in
        let completed = Atomic<Bool>(value: false)
        let urlTask = URLSession.shared.dataTask(with: request, completionHandler: { data, response, _ in
            _ = completed.swap(true)
            if let strongData = data {
                subscriber.putNext((strongData, response))
                subscriber.putCompletion()
            } else {
                subscriber.putError(.network)
            }
        })
        urlTask.resume()

        return ActionDisposable {
            if !completed.with({ $0 }) {
                urlTask.cancel()
            }
        }
    }
}

