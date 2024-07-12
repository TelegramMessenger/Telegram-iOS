//
//  Created by Adam Stragner
//

import Foundation
import WebKit

// MARK: - URLSchemeHandlerSessionType

public enum URLSchemeHandlerSessionType {
    case `default`
    case proxy(connectionProxyDictionary: [AnyHashable: Any])
}

// MARK: - TonutilsURLSchemeHandlerDelegate

public protocol TonutilsURLSchemeHandlerDelegate: AnyObject {
    func tonutilsURLSchemeHandler(
        _ schemeHandler: TonutilsURLSchemeHandler,
        sessionFor type: URLSchemeHandlerSessionType
    ) -> URLSession
}

// MARK: - TonutilsURLSchemeHandler

open class TonutilsURLSchemeHandler: NSObject, WKURLSchemeHandler {
    // MARK: Lifecycle

    public init(address: String, port: UInt16) {
        self.connectionProxyDictionary = [
            kCFNetworkProxiesHTTPEnable: true,
            kCFNetworkProxiesHTTPProxy: address,
            kCFNetworkProxiesHTTPPort: port,
        ]

        super.init()
    }

    // MARK: Open

    open func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url
        else {
            return
        }

        if url.isTON {
            route(urlSchemeTask, with: .proxy(connectionProxyDictionary: connectionProxyDictionary))
        } else {
            route(urlSchemeTask, with: .default)
        }
    }

    open func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        tasks.removeValue(forKey: urlSchemeTask.identifier)
    }

    // MARK: Public

    public weak var delegate: TonutilsURLSchemeHandlerDelegate?

    // MARK: Internal

    internal static let schemas = ["http"]

    // MARK: Private

    private let connectionProxyDictionary: [AnyHashable: Any]
    private var tasks: [AnyHashable: URLSessionDataTask] = [:]

    private func route(
        _ schemeTask: WKURLSchemeTask,
        with sesstionType: URLSchemeHandlerSessionType
    ) {
        let session = session(for: sesstionType)
        let task = session.dataTask(
            with: schemeTask.request,
            completionHandler: { [weak schemeTask, weak self] data, response, error in
                guard let self, let schemeTask
                else {
                    schemeTask?.didFailWithError(URLError(.cancelled))
                    return
                }

                finish(schemeTask, data: data, response: response, error: error)
            }
        )

        tasks[schemeTask.identifier] = task
        task.resume()
    }

    private func finish(
        _ schemeTask: WKURLSchemeTask,
        data: Data?,
        response: URLResponse?,
        error: Error?
    ) {
        tasks.removeValue(forKey: schemeTask.identifier)
        if let error = error, error._code != NSURLErrorCancelled {
            schemeTask.didFailWithError(error)
        } else {
            if let response = response {
                schemeTask.didReceive(response)
            }
            if let data = data {
                schemeTask.didReceive(data)
            }

            schemeTask.didFinish()
        }
    }
}

private extension TonutilsURLSchemeHandler {
    func session(for type: URLSchemeHandlerSessionType) -> URLSession {
        guard let session = delegate?.tonutilsURLSchemeHandler(self, sessionFor: type)
        else {
            return _session(for: type)
        }
        return session
    }

    private func _session(for type: URLSchemeHandlerSessionType) -> URLSession {
        switch type {
        case .default:
            return .default
        case let .proxy(connectionProxyDictionary):
            if let session = URLSession.proxyable {
                return session
            } else {
                let session: URLSession = .proxyable(with: connectionProxyDictionary)
                URLSession.proxyable = session
                return session
            }
        }
    }
}
