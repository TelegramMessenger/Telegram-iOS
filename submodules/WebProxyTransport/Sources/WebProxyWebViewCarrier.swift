import Foundation
import WebKit

enum WebProxyPageMessage {
    case binary(Data)
    case control(String)
}

final class WebProxyWebViewCarrier: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    let nonce: String

    /// The view the transport hands to its `WebProxyCarrierViewHost`.
    var hostedWebView: WKWebView {
        return self.webView
    }

    private let configuration: WebProxyConfiguration
    private let generation: UInt64
    private let handlerName: String
    private let hardeningFlag: String
    private let bridgeURL: URL
    private let received: (UInt64, WebProxyPageMessage) -> Void
    private let failed: (UInt64, WebProxyCarrierFailure) -> Void
    private let webView: WKWebView
    private var initialNavigation = true
    private var invalidated = false
    private var pendingSends: [Data] = []
    private var pendingSendBytes = 0
    private var evaluatingSend = false
    /// The bridge routes the first ArrayBuffer to `createSession`, which must carry
    /// the lone HELLO frame, so the first message is never batched.
    private var hasSentFirstMessage = false

    init?(
        configuration: WebProxyConfiguration,
        generation: UInt64,
        received: @escaping (UInt64, WebProxyPageMessage) -> Void,
        failed: @escaping (UInt64, WebProxyCarrierFailure) -> Void
    ) {
        var nonceData = Data(count: 32)
        let randomResult = nonceData.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, bytes.count, bytes.baseAddress!)
        }
        guard randomResult == errSecSuccess else { return nil }
        let nonce = nonceData.webProxyBase64Url
        guard let bridgeURL = configuration.bridgeURL(nonce: nonce) else { return nil }

        let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        self.configuration = configuration
        self.generation = generation
        self.handlerName = "telegramWebProxy_\(suffix)"
        self.hardeningFlag = "telegramWebProxyPolicy_\(suffix)"
        self.nonce = nonce
        self.bridgeURL = bridgeURL
        self.received = received
        self.failed = failed

        // Both scripts run at document start in the page world, in this order: the
        // execution profile must be in place before the bridge shim and before any
        // provider JavaScript. They carry no reference to `self`, so they are installed
        // before the web view copies the configuration.
        //
        // The profile runs in EVERY frame; the shim only in the main one. A subframe is a
        // separate realm with its own pristine `navigator` and `window`, and a src-less
        // `about:blank` child inherits the CSP but NOT a main-frame-only user script - and
        // `frame-src 'none'` does not stop it, because the initial about:blank is not a
        // fetch. Measured, not assumed: see WebProxyFrameIsolationTests. The shim stays
        // main-frame-only because it is the half that can reach native, which is also why
        // the message handler re-checks `frameInfo.isMainFrame`.
        let hardeningSource = WebProxyWebViewHardening.script(host: configuration.host, flag: self.hardeningFlag)
        let shimSource = Self.injectionScript(handlerName: self.handlerName, nonce: nonce, hardeningFlag: self.hardeningFlag)
        let contentController = WKUserContentController()
        if #available(macOS 11.0, iOS 14.0, *) {
            contentController.addUserScript(WKUserScript(source: hardeningSource, injectionTime: .atDocumentStart, forMainFrameOnly: false, in: .page))
            contentController.addUserScript(WKUserScript(source: shimSource, injectionTime: .atDocumentStart, forMainFrameOnly: true, in: .page))
        } else {
            contentController.addUserScript(WKUserScript(source: hardeningSource, injectionTime: .atDocumentStart, forMainFrameOnly: false))
            contentController.addUserScript(WKUserScript(source: shimSource, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }

        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.userContentController = contentController
        WebProxyWebViewHardening.apply(to: webConfiguration)

        self.webView = WKWebView(frame: .zero, configuration: webConfiguration)
        super.init()

        // Fail closed before navigation: a carrier that could not install the
        // document-start policy must never load the bridge.
        guard contentController.userScripts.count == 2 else {
            return nil
        }

        if #available(macOS 11.0, iOS 14.0, *) {
            contentController.add(self, contentWorld: .page, name: self.handlerName)
        } else {
            contentController.add(self, name: self.handlerName)
        }
        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self
    }

    func start() {
        guard !self.invalidated else { return }
        WebProxyDiagnostics.info("webview load started")
        self.webView.load(URLRequest(url: self.bridgeURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 20.0))
    }

    func invalidate() {
        guard !self.invalidated else { return }
        self.invalidated = true
        self.webView.stopLoading()
        self.webView.navigationDelegate = nil
        self.webView.uiDelegate = nil
        if #available(macOS 11.0, iOS 14.0, *) {
            self.webView.configuration.userContentController.removeScriptMessageHandler(forName: self.handlerName, contentWorld: .page)
        } else {
            self.webView.configuration.userContentController.removeScriptMessageHandler(forName: self.handlerName)
        }
        self.webView.configuration.userContentController.removeAllUserScripts()
        self.pendingSends.removeAll()
        self.pendingSendBytes = 0
        self.evaluatingSend = false
        self.hasSentFirstMessage = false
    }

    func send(data: Data) {
        guard !self.invalidated else { return }
        guard self.pendingSends.count < WebProxyProtocol.maximumQueuedItems,
              self.pendingSendBytes <= WebProxyProtocol.maximumQueuedBytes - data.count else {
            self.failed(self.generation, .bridgeEvaluationFailed)
            return
        }
        self.pendingSends.append(data)
        self.pendingSendBytes += data.count
        self.flushSendQueue()
    }

    private func flushSendQueue() {
        guard !self.invalidated, !self.evaluatingSend, !self.pendingSends.isEmpty else { return }
        let count = WebProxySendBatcher.batchCount(
            pending: self.pendingSends,
            isFirstMessage: !self.hasSentFirstMessage,
            maximumFrames: WebProxyProtocol.maximumBatchFrames,
            maximumBytes: WebProxyProtocol.defaultBatchSize
        )
        guard count > 0 else { return }
        self.evaluatingSend = true

        // Concatenating here is what makes the batch worth it: the bridge walks frame
        // boundaries itself, so one message carries many frames and costs one round trip.
        var batch = Data()
        var batchBytes = 0
        for frame in self.pendingSends.prefix(count) {
            batch.append(frame)
            batchBytes += frame.count
        }
        let base64 = batch.base64EncodedString()

        let completion: (Bool?, Error?) -> Void = { [weak self] value, error in
            guard let self, !self.invalidated else { return }
            if error != nil {
                self.failed(self.generation, .bridgeEvaluationFailed)
                return
            }
            guard value == true else {
                self.failed(self.generation, .bridgeUnavailable)
                return
            }
            self.pendingSends.removeFirst(count)
            self.pendingSendBytes -= batchBytes
            self.hasSentFirstMessage = true
            self.evaluatingSend = false
            self.flushSendQueue()
        }

        if #available(macOS 11.0, iOS 14.0, *) {
            // The payload travels as an argument, not interpolated into source: the
            // function body is constant so WebKit compiles it once instead of parsing
            // a fresh multi-kilobyte script per batch, and nothing needs escaping.
            // The Objective-C method, not the Swift overlay's: an x86_64 build for macOS 10.13 binds the
            // overlay's symbol to WebKit.framework, which has it only from macOS 15.4.
            self.webView.__callAsyncJavaScript(
                Self.deliverFunctionBody,
                arguments: ["payload": base64],
                inFrame: nil,
                in: .page
            ) { value, error in
                completion(error == nil ? value as? Bool : nil, error)
            }
        } else {
            let script = """
            (() => {
              const payload = \(Self.javaScriptString(base64));
              \(Self.deliverFunctionBody)
            })()
            """
            self.webView.evaluateJavaScript(script) { value, error in
                completion(value as? Bool, error)
            }
        }
    }

    /// Body of the delivery function. Constant so it compiles once; the batch arrives
    /// as the `payload` argument.
    private static let deliverFunctionBody = """
    const bridge = globalThis.TelegramWebProxy;
    if (!bridge || typeof bridge.onmessage !== 'function') return false;
    let bytes;
    if (typeof Uint8Array.fromBase64 === 'function') {
      bytes = Uint8Array.fromBase64(payload);
    } else {
      const raw = atob(payload);
      bytes = new Uint8Array(raw.length);
      for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
    }
    const buffer = bytes.byteOffset === 0 && bytes.byteLength === bytes.buffer.byteLength ? bytes.buffer : bytes.slice().buffer;
    bridge.onmessage({data: buffer});
    return true;
    """

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard !self.invalidated,
              message.webView === self.webView,
              message.name == self.handlerName,
              message.frameInfo.isMainFrame,
              message.frameInfo.securityOrigin.protocol == "https",
              message.frameInfo.securityOrigin.host.lowercased() == self.configuration.host,
              message.frameInfo.securityOrigin.port == 0 || message.frameInfo.securityOrigin.port == 443,
              self.isAllowed(url: self.webView.url),
              let body = message.body as? [String: Any],
              body["nonce"] as? String == self.nonce,
              let kind = body["kind"] as? String,
              let value = body["data"] as? String else {
            self.failed(self.generation, .bridgeMessageRejected)
            return
        }
        if kind == "binary", let data = Data(base64Encoded: value), data.count <= WebProxyProtocol.defaultBatchSize {
            self.received(self.generation, .binary(data))
        } else if kind == "control", value.utf8.count <= 4096 {
            self.received(self.generation, .control(value))
        } else if kind == "hardening" {
            self.failed(self.generation, .hardeningUnavailable)
        } else {
            self.failed(self.generation, .bridgeMessageRejected)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Only the first canonical main-frame navigation is allowed. Everything else -
        // redirects, new windows, subframes, downloads, other schemes or hosts - is a
        // carrier failure rather than a quietly cancelled navigation.
        var performsDownload = false
        if #available(macOS 11.3, iOS 14.5, *) {
            performsDownload = navigationAction.shouldPerformDownload
        }
        guard !self.invalidated,
              navigationAction.targetFrame?.isMainFrame == true,
              !performsDownload,
              self.initialNavigation,
              self.isAllowed(url: navigationAction.request.url) else {
            decisionHandler(.cancel)
            if !self.invalidated { self.failed(self.generation, .navigationRejected) }
            return
        }
        self.initialNavigation = false
        WebProxyDiagnostics.info("initial navigation accepted")
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        let httpResponse = navigationResponse.response as? HTTPURLResponse
        guard !self.invalidated,
              navigationResponse.isForMainFrame,
              self.isAllowed(url: navigationResponse.response.url),
              let response = httpResponse,
              response.statusCode == 200,
              response.mimeType == "text/html" else {
            decisionHandler(.cancel)
            if !self.invalidated {
                WebProxyDiagnostics.rejectedResponse(statusCode: httpResponse?.statusCode, mimeType: navigationResponse.response.mimeType)
                self.failed(self.generation, .responseRejected)
            }
            return
        }
        WebProxyDiagnostics.info("bridge response accepted")
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if !self.invalidated {
            WebProxyDiagnostics.navigationFailure(error)
            self.failed(self.generation, .navigationFailed)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if !self.invalidated {
            WebProxyDiagnostics.info("bridge document loaded")
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if !self.invalidated {
            WebProxyDiagnostics.navigationFailure(error)
            self.failed(self.generation, .navigationFailed)
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        if !self.invalidated { self.failed(self.generation, .webContentProcessTerminated) }
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        // `decidePolicyFor` already cancels a redirect, since only the first navigation is
        // allowed. Reaching here at all means the redirect was followed; fail the carrier.
        if !self.invalidated {
            self.failed(self.generation, .navigationRejected)
        }
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Normal system TLS validation, never a trust exception. Any other method - basic,
        // digest, a client certificate - is cancelled rather than prompted or answered.
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            completionHandler(.performDefaultHandling, nil)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    @available(macOS 11.3, iOS 14.5, *)
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.cancel(nil)
        if !self.invalidated {
            self.failed(self.generation, .navigationRejected)
        }
    }

    @available(macOS 11.3, iOS 14.5, *)
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.cancel(nil)
        if !self.invalidated {
            self.failed(self.generation, .responseRejected)
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        return nil
    }

    // MARK: - Refused prompts and permissions
    //
    // The hidden carrier must never present UI. The document-start shims answer the same
    // calls in-page so a provider document does not block on one; these are the boundary.

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(false)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        completionHandler(nil)
    }

    @available(macOS 12.0, iOS 15.0, *)
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.deny)
    }

    #if os(iOS)
    @available(iOS 15.0, *)
    func webView(_ webView: WKWebView, requestDeviceOrientationAndMotionPermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.deny)
    }
    #endif

    /// Geolocation. Public from iOS 27 / macOS 27; below that WebKit decides without
    /// asking the app, and `navigator.geolocation` being shimmed away is what stops the
    /// page from reaching it.
    @available(macOS 27.0, iOS 27.0, *)
    func webView(_ webView: WKWebView, requestGeolocationPermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.deny)
    }

    /// Not macOS-only, and not optional: from iOS 18.4 this delegate exists on iOS too, and
    /// WebKit documents that NOT implementing it there makes the view "match the file upload
    /// behavior of Safari" - i.e. present a picker. Returning no URLs is the documented way
    /// to act as if the user cancelled.
    @available(macOS 10.12, iOS 18.4, *)
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        completionHandler(nil)
    }

    private func isAllowed(url: URL?) -> Bool {
        guard let url,
              url.scheme?.lowercased() == "https",
              url.host?.lowercased() == self.configuration.host,
              url.port == nil || url.port == 443,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.percentEncodedPath == self.configuration.base else { return false }
        return true
    }

    private static func injectionScript(handlerName: String, nonce: String, hardeningFlag: String) -> String {
        return """
        (() => {
          'use strict';
          const native = globalThis.webkit.messageHandlers[\(javaScriptString(handlerName))];
          const nonce = \(javaScriptString(nonce));
          // The document-start policy runs first and records whether it is in place. If it
          // is not, the page never sees TelegramWebProxy and the carrier is failed now
          // rather than after the handshake deadline.
          if (globalThis[\(javaScriptString(hardeningFlag))] !== true) {
            native.postMessage({kind: 'hardening', nonce, data: 'failed'});
            return;
          }
          const bridge = {onmessage: null};
          Object.defineProperty(bridge, 'postMessage', {value: value => {
            if (typeof value === 'string') {
              native.postMessage({kind: 'control', nonce, data: value});
              return;
            }
            let bytes;
            if (value instanceof ArrayBuffer) bytes = new Uint8Array(value);
            else if (ArrayBuffer.isView(value)) bytes = new Uint8Array(value.buffer, value.byteOffset, value.byteLength);
            else throw new TypeError('TelegramWebProxy accepts strings or binary data');
            let binary = '';
            const chunk = 0x8000;
            for (let i = 0; i < bytes.length; i += chunk) {
              binary += String.fromCharCode(...bytes.subarray(i, Math.min(i + chunk, bytes.length)));
            }
            native.postMessage({kind: 'binary', nonce, data: btoa(binary)});
          }, enumerable: true});
          Object.seal(bridge);
          Object.defineProperty(globalThis, 'TelegramWebProxy', {value: bridge, configurable: false, writable: false});
        })();
        """
    }

    private static func javaScriptString(_ value: String) -> String {
        return WebProxyWebViewHardening.javaScriptString(value)
    }
}
