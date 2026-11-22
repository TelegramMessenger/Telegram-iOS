import Foundation
import os.log

enum WebProxyCarrierFailure: String {
    case construction = "webview-construction"
    case initializationTimeout = "initialization-timeout"
    case navigationRejected = "navigation-rejected"
    case responseRejected = "response-rejected"
    case navigationFailed = "navigation-failed"
    case webContentProcessTerminated = "web-content-process-terminated"
    case bridgeMessageRejected = "bridge-message-rejected"
    case bridgeEvaluationFailed = "bridge-evaluation-failed"
    case bridgeUnavailable = "bridge-unavailable"
    case hardeningUnavailable = "hardening-unavailable"
    case invalidControlMessage = "invalid-control-message"
    case invalidInitialization = "invalid-initialization"
    case remoteClose = "remote-close"
    case frameDecode = "frame-decode"
    case protocolViolation = "protocol-violation"
    case streamIdExhausted = "stream-id-exhausted"
}

enum WebProxyDiagnostics {
    private static let log = OSLog(subsystem: "org.telegram.WebProxyTransport", category: "carrier")

    static func info(_ event: StaticString) {
        os_log(event, log: self.log, type: .info)
    }

    static func failure(_ reason: WebProxyCarrierFailure) {
        os_log("carrier failure: %{public}@", log: self.log, type: .error, reason.rawValue)
    }

    static func pageStatus(_ status: WebProxyPageStatus) {
        switch status {
        case .connecting:
            self.info("page status: connecting")
        case .reconnecting:
            self.info("page status: reconnecting")
        case .connected:
            self.info("page status: connected")
        case .failed:
            self.info("page status: failed")
        }
    }

    static func navigationFailure(_ error: Error) {
        let error = error as NSError
        os_log(
            "navigation error: domain=%{public}@ code=%{public}d",
            log: self.log,
            type: .error,
            error.domain,
            error.code
        )
    }

    static func rejectedResponse(statusCode: Int?, mimeType: String?) {
        os_log(
            "response rejected: status=%{public}d mime=%{public}@",
            log: self.log,
            type: .error,
            statusCode ?? -1,
            mimeType ?? "none"
        )
    }
}
