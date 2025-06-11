import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import PresentationDataUtils
import AccountContext
@preconcurrency import WebKit
import AppBundle
import PromptUI
import SafariServices
import ShareController
import UndoUI
import LottieComponent
import MultilineTextComponent
import UrlEscaping
import UrlHandling
import SaveProgressScreen
import DeviceModel
import LegacyMediaPickerUI
import PassKit

private final class TonSchemeHandler: NSObject, WKURLSchemeHandler {
    private final class PendingTask {
        let sourceTask: any WKURLSchemeTask
        var urlSessionTask: URLSessionTask?
        let isCompleted = Atomic<Bool>(value: false)
        
        init(proxyServerHost: String, sourceTask: any WKURLSchemeTask) {
            self.sourceTask = sourceTask
            
            final class BoxedSourceTask: @unchecked Sendable {
                let value: any WKURLSchemeTask
                
                init(value: any WKURLSchemeTask) {
                    self.value = value
                }
            }
            let sourceTaskReference = BoxedSourceTask(value: sourceTask)
            
            let requestUrl = sourceTask.request.url
            
            var mappedHost: String = ""
            if let host = sourceTask.request.url?.host {
                mappedHost = host
                mappedHost = mappedHost.replacingOccurrences(of: "-", with: "-h")
                mappedHost = mappedHost.replacingOccurrences(of: ".", with: "-d")
            }
            
            var mappedPath = ""
            if let path = sourceTask.request.url?.path, !path.isEmpty {
                mappedPath = path
                if !path.hasPrefix("/") {
                    mappedPath = "/\(mappedPath)"
                }
            }
            let mappedUrl = "https://\(mappedHost).\(proxyServerHost)\(mappedPath)"
            let isCompleted = self.isCompleted
            self.urlSessionTask = URLSession.shared.dataTask(with: URLRequest(url: URL(string: mappedUrl)!), completionHandler: { data, response, error in
                if isCompleted.swap(true) {
                    return
                }
                
                if let error {
                    sourceTaskReference.value.didFailWithError(error)
                } else {
                    if let response {
                        if let response = response as? HTTPURLResponse, let requestUrl {
                            if let updatedResponse = HTTPURLResponse(
                                url: requestUrl,
                                statusCode: response.statusCode,
                                httpVersion: "HTTP/1.1",
                                headerFields: response.allHeaderFields as? [String: String] ?? [:]
                            ) {
                                sourceTaskReference.value.didReceive(updatedResponse)
                            } else {
                                sourceTaskReference.value.didReceive(response)
                            }
                        } else {
                            sourceTaskReference.value.didReceive(response)
                        }
                    }
                    if let data {
                        sourceTaskReference.value.didReceive(data)
                    }
                    sourceTaskReference.value.didFinish()
                }
            })
            self.urlSessionTask?.resume()
        }
        
        func cancel() {
            if let urlSessionTask = self.urlSessionTask {
                self.urlSessionTask = nil
                if !self.isCompleted.swap(true) {
                    switch urlSessionTask.state {
                    case .running, .suspended:
                        urlSessionTask.cancel()
                    default:
                        break
                    }
                }
            }
        }
    }
    
    private let proxyServerHost: String
    
    private var pendingTasks: [PendingTask] = []
    
    init(proxyServerHost: String) {
        self.proxyServerHost = proxyServerHost
    }
    
    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        self.pendingTasks.append(PendingTask(proxyServerHost: self.proxyServerHost, sourceTask: urlSchemeTask))
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        if let index = self.pendingTasks.firstIndex(where: { $0.sourceTask === urlSchemeTask }) {
            let task = self.pendingTasks[index]
            self.pendingTasks.remove(at: index)
            task.cancel()
        }
    }
}

final class WebView: WKWebView {
    var customBottomInset: CGFloat = 0.0 {
        didSet {
            if self.customBottomInset != oldValue {
                self.setNeedsLayout()
            }
        }
    }
    
    override var safeAreaInsets: UIEdgeInsets {
        return UIEdgeInsets(top: 0.0, left: 0.0, bottom: self.customBottomInset, right: 0.0)
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        var result = super.point(inside: point, with: event)
        if !result && point.x > 0.0 && point.y < self.frame.width && point.y > 0.0 && point.y < self.frame.height + 83.0 {
            result = true
        }
        return result
    }
}

private class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private let f: (WKScriptMessage) -> ()
    
    init(_ f: @escaping (WKScriptMessage) -> ()) {
        self.f = f
        
        super.init()
    }
    
    func userContentController(_ controller: WKUserContentController, didReceive scriptMessage: WKScriptMessage) {
        self.f(scriptMessage)
    }
}

private func computedUserAgent() -> String {
    func getFirmwareVersion() -> String? {
        var size = 0
        sysctlbyname("kern.osversion", nil, &size, nil, 0)
        
        var str = [CChar](repeating: 0, count: size)
        sysctlbyname("kern.osversion", &str, &size, nil, 0)
        
        return String(cString: str)
    }
    
    let osVersion = UIDevice.current.systemVersion
    let firmwareVersion = getFirmwareVersion() ?? "15E148"
    return DeviceModel.current.isIpad ? "Version/\(osVersion) Safari/605.1.15" : "Version/\(osVersion) Mobile/\(firmwareVersion) Safari/604.1"
}

final class BrowserWebContent: UIView, BrowserContent, WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate, WKDownloadDelegate {
    private let context: AccountContext
    private var presentationData: PresentationData
    
    let webView: WebView
    var readability: Readability?
    
    private let errorView: ComponentHostView<Empty>
    private var currentError: Error?
    
    let uuid: UUID
    
    private var _state: BrowserContentState
    private let statePromise: Promise<BrowserContentState>
    
    var currentState: BrowserContentState {
        return self._state
    }
    var state: Signal<BrowserContentState, NoError> {
        return self.statePromise.get()
    }
    
    private let faviconDisposable = MetaDisposable()
    
    var pushContent: (BrowserScreen.Subject, BrowserContent?) -> Void = { _, _ in }
    var openAppUrl: (String) -> Void = { _ in }
    var onScrollingUpdate: (ContentScrollingUpdate) -> Void = { _ in }
    var minimize: () -> Void = { }
    var close: () -> Void = { }
    var present: (ViewController, Any?) -> Void = { _, _ in }
    var presentInGlobalOverlay: (ViewController) -> Void = { _ in }
    var getNavigationController: () -> NavigationController? = { return nil }
    var cancelInteractiveTransitionGestures: () -> Void = {}
    
    private var tempFile: TempBoxFile?
    
    init(context: AccountContext, presentationData: PresentationData, url: String, preferredConfiguration: WKWebViewConfiguration? = nil) {
        self.context = context
        self.uuid = UUID()
        self.presentationData = presentationData
        
        var handleScriptMessageImpl: ((WKScriptMessage) -> Void)?
        var handleContentMessageImpl: ((WKScriptMessage) -> Void)?
        var handleBlobMessageImpl: ((WKScriptMessage) -> Void)?
        
        let configuration: WKWebViewConfiguration
        if let preferredConfiguration {
            configuration = preferredConfiguration
        } else {
            configuration = WKWebViewConfiguration()
            var proxyServerHost = "magic.org"
            if let data = context.currentAppConfiguration.with({ $0 }).data, let hostValue = data["ton_proxy_address"] as? String {
                proxyServerHost = hostValue
            }
            configuration.setURLSchemeHandler(TonSchemeHandler(proxyServerHost: proxyServerHost), forURLScheme: "tonsite")
            configuration.allowsInlineMediaPlayback = true
            if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                configuration.mediaTypesRequiringUserActionForPlayback = []
            } else {
                configuration.mediaPlaybackRequiresUserAction = false
            }
            
            let contentController = WKUserContentController()
            let videoScript = WKUserScript(source: videoSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            contentController.addUserScript(videoScript)
            let touchScript = WKUserScript(source: setupTouchObservers, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            contentController.addUserScript(touchScript)
            
            let eventProxyScript = WKUserScript(source: eventProxySource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            contentController.addUserScript(eventProxyScript)
            contentController.add(WeakScriptMessageHandler { message in
                handleScriptMessageImpl?(message)
            }, name: "performAction")
            contentController.add(WeakScriptMessageHandler { message in
                handleContentMessageImpl?(message)
            }, name: "contentInterface")
            contentController.add(WeakScriptMessageHandler { message in
                handleBlobMessageImpl?(message)
            }, name: "blobInterface")
            configuration.userContentController = contentController
            configuration.applicationNameForUserAgent = computedUserAgent()
        }
                
        self.webView = WebView(frame: CGRect(), configuration: configuration)
        self.webView.allowsLinkPreview = true
                
        if #available(iOS 11.0, *) {
            self.webView.scrollView.contentInsetAdjustmentBehavior = .never
        }
        
        var title: String = ""
        if url.hasPrefix("file://") {
            var updatedPath = url
            let tempFile = TempBox.shared.file(path: url.replacingOccurrences(of: "file://", with: ""), fileName: "file.xlsx")
            updatedPath = tempFile.path
            self.tempFile = tempFile
            
            let request = URLRequest(url: URL(fileURLWithPath: updatedPath))
            self.webView.load(request)
        } else if let parsedUrl = URL(string: url) {
            let request = URLRequest(url: parsedUrl)
            self.webView.load(request)
            
            title = getDisplayUrl(url, hostOnly: true)
        }
        
        self.errorView = ComponentHostView()
        
        self._state = BrowserContentState(title: title, url: url, estimatedProgress: 0.1, readingProgress: 0.0, contentType: .webPage)
        self.statePromise = Promise<BrowserContentState>(self._state)
        
        super.init(frame: .zero)
        
        self.backgroundColor = presentationData.theme.list.plainBackgroundColor
        self.webView.backgroundColor = presentationData.theme.list.plainBackgroundColor
        self.webView.alpha = 0.0
        
        self.webView.allowsBackForwardNavigationGestures = true
        self.webView.scrollView.delegate = self
        self.webView.scrollView.clipsToBounds = false

        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self
        self.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: [], context: nil)
        self.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: [], context: nil)
        self.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: [], context: nil)
        self.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack), options: [], context: nil)
        self.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward), options: [], context: nil)
        self.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.hasOnlySecureContent), options: [], context: nil)
        if #available(iOS 16.4, *) {
            self.webView.isInspectable = true
        }
        self.addSubview(self.webView)
        
        self.webView.disablesInteractiveTransitionGestureRecognizerNow = { [weak self] in
            if let self, self.webView.canGoBack {
                return true
            } else {
                return false
            }
        }
        
        self.webView.interactiveTransitionGestureRecognizerTest = { [weak self] point in
            if let self {
                if let result = self.webView.hitTest(point, with: nil), let scrollView = findScrollView(view: result), scrollView.isDescendant(of: self.webView) {
                    if scrollView.contentSize.width > scrollView.frame.width, scrollView.contentOffset.x > -scrollView.contentInset.left {
                        return true
                    }
                }
            }
            return false
        }
        
        handleScriptMessageImpl = { [weak self] message in
            self?.handleScriptMessage(message)
        }
        handleContentMessageImpl = { [weak self] message in
            self?.handleContentRequest(message)
        }
        handleBlobMessageImpl = { [weak self] message in
            self?.handleBlobRequest(message)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.title))
        self.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.url))
        self.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
        self.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack))
        self.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward))
        self.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.hasOnlySecureContent))
        
        self.faviconDisposable.dispose()
        self.instantPageDisposable.dispose()
    }
    
    private func handleScriptMessage(_ message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let eventName = body["eventName"] as? String else {
            return
        }
        switch eventName {
        case "cancellingTouch":
            self.cancelInteractiveTransitionGestures()
        default:
            break
        }
    }
    
    private func handleContentRequest(_ message: WKScriptMessage) {
        guard let string = message.body as? String else {
            return
        }
        guard let data = Data(base64Encoded: string, options: [.ignoreUnknownCharacters]) else {
            return
        }
        guard let url = URL(string: self._state.url) else {
            return
        }
        let path = NSTemporaryDirectory() + NSUUID().uuidString
        let _ = try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
        
        let fileName: String
        if !url.lastPathComponent.isEmpty {
            fileName = url.lastPathComponent
        } else {
            fileName = "default"
        }
        
        let tempFile = TempBox.shared.file(path: path, fileName: fileName)
        let fileUrl = URL(fileURLWithPath: tempFile.path)
        
        let controller = legacyICloudFilePicker(theme: self.presentationData.theme, mode: .export, url: fileUrl, documentTypes: [], forceDarkTheme: false, dismissed: {}, completion: { _ in
            
        })
        self.present(controller, nil)
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        if #available(iOS 15.0, *) {
            self.backgroundColor = presentationData.theme.list.plainBackgroundColor
        }
        if let (size, insets, fullInsets, safeInsets) = self.validLayout {
            self.updateLayout(size: size, insets: insets, fullInsets: fullInsets, safeInsets: safeInsets, transition: .immediate)
        }
    }
        
    var currentFontState = BrowserPresentationState.FontState(size: 100, isSerif: false)
    func updateFontState(_ state: BrowserPresentationState.FontState) {
        self.updateFontState(state, force: false)
    }
    
    func updateFontState(_ state: BrowserPresentationState.FontState, force: Bool) {
        self.currentFontState = state
        
        let fontFamily = state.isSerif ? "'Georgia, serif'" : "null"
        let textSizeAdjust = state.size != 100 ? "'\(state.size)%'" : "null"
        let js = "\(setupFontFunctions) setTelegramFontOverrides(\(fontFamily), \(textSizeAdjust))";
        self.webView.evaluateJavaScript(js) { _, _ in }
    }
    
    func toggleInstantView(_ enabled: Bool) {
        if enabled {
            if let instantPage = self.instantPage {
                self.pushContent(.instantPage(webPage: instantPage, anchor: nil, sourceLocation: InstantPageSourceLocation(userLocation: .other, peerType: .channel), preloadedResources: self.instantPageResources), self)
            } else if let readability = self.readability {
                readability.webView.frame = self.webView.frame
                self.addSubview(readability.webView)
                
                var collapsedFrame = readability.webView.frame
                collapsedFrame.size.height = 0.0
                readability.webView.clipsToBounds = true
                readability.webView.layer.animateFrame(from: collapsedFrame, to: readability.webView.frame, duration: 0.3)
            }
        } else if let readability = self.readability {
            var collapsedFrame = readability.webView.frame
            collapsedFrame.size.height = 0.0
            readability.webView.layer.animateFrame(from: readability.webView.frame, to: collapsedFrame, duration: 0.3, removeOnCompletion: false, completion: { _ in
                readability.webView.removeFromSuperview()
                readability.webView.layer.removeAllAnimations()
            })
        }
    }
    
    private var didSetupSearch = false
    private func setupSearch(completion: @escaping () -> Void) {
        guard !self.didSetupSearch else {
            completion()
            return
        }
                
        let bundle = getAppBundle()
        guard let scriptPath = bundle.path(forResource: "UIWebViewSearch", ofType: "js") else {
            return
        }
        guard let scriptData = try? Data(contentsOf: URL(fileURLWithPath: scriptPath)) else {
            return
        }
        guard let script = String(data: scriptData, encoding: .utf8) else {
            return
        }
        self.didSetupSearch = true
        self.webView.evaluateJavaScript(script, completionHandler: { _, error in
            if error != nil {
                print()
            }
            completion()
        })
    }
    
    private var findSession: Any?
    private var previousQuery: String?
    func setSearch(_ query: String?, completion: ((Int) -> Void)?) {
        guard self.previousQuery != query else {
            return
        }
        
        if #available(iOS 16.0, *), !"".isEmpty {
            if let query {
                var findSession: UIFindSession?
                if let current = self.findSession as? UIFindSession {
                    findSession = current
                } else {
                    self.webView.isFindInteractionEnabled = true

                    if let findInteraction = self.webView.findInteraction, let webView = self.webView as? UIFindInteractionDelegate, let session = webView.findInteraction(findInteraction, sessionFor: self.webView) {
//                        session.setValue(findInteraction, forKey: "_parentInteraction")
//                        findInteraction.setValue(session, forKey: "_activeFindSession")
                        findSession = session
                        self.findSession = session
                        
                        webView.findInteraction?(findInteraction, didBegin: session)
                    }
                }
                if let findSession {
                    findSession.performSearch(query: query, options: BrowserSearchOptions())
                    self.webView.findInteraction?.updateResultCount()
                    completion?(findSession.resultCount)
                }
            } else {
                if let findInteraction = self.webView.findInteraction, let webView = self.webView as? UIFindInteractionDelegate, let session = self.findSession as? UIFindSession {
                    webView.findInteraction?(findInteraction, didEnd: session)
                    self.findSession = nil
                    self.webView.isFindInteractionEnabled = false
                }
            }
        } else {
            self.setupSearch { [weak self] in
                if let query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let js = "uiWebview_HighlightAllOccurencesOfString('\(query)')"
                    self?.webView.evaluateJavaScript(js, completionHandler: { [weak self] _, _ in
                        let js = "uiWebview_SearchResultCount"
                        self?.webView.evaluateJavaScript(js, completionHandler: { [weak self] result, _ in
                            if let result = result as? NSNumber {
                                self?.searchResultsCount = result.intValue
                                completion?(result.intValue)
                            } else {
                                completion?(0)
                            }
                        })
                    })
                } else {
                    let js = "uiWebview_RemoveAllHighlights()"
                    self?.webView.evaluateJavaScript(js, completionHandler: nil)
                    
                    self?.currentSearchResult = 0
                    self?.searchResultsCount = 0
                    completion?(0)
                }
            }
        }
        
        self.previousQuery = query
    }
    
    private var currentSearchResult: Int = 0
    private var searchResultsCount: Int = 0
    
    func scrollToPreviousSearchResult(completion: ((Int, Int) -> Void)?) {
        if #available(iOS 16.0, *), !"".isEmpty {
            if let session = self.findSession as? UIFindSession {
                session.highlightNextResult(in: .backward)
                completion?(session.highlightedResultIndex, session.resultCount)
            }
        } else {
            let searchResultsCount = self.searchResultsCount
            var index = self.currentSearchResult - 1
            if index < 0 {
                index = searchResultsCount - 1
            }
            self.currentSearchResult = index
            
            let js = "uiWebview_ScrollTo('\(searchResultsCount - index - 1)')"
            self.webView.evaluateJavaScript(js, completionHandler: { _, _ in
                completion?(index, searchResultsCount)
            })
        }
    }
    
    func scrollToNextSearchResult(completion: ((Int, Int) -> Void)?) {
        if #available(iOS 16.0, *), !"".isEmpty {
            if let session = self.findSession as? UIFindSession {
                session.highlightNextResult(in: .forward)
                completion?(session.highlightedResultIndex, session.resultCount)
            }
        } else {
            let searchResultsCount = self.searchResultsCount
            var index = self.currentSearchResult + 1
            if index >= searchResultsCount {
                index = 0
            }
            self.currentSearchResult = index
            
            let js = "uiWebview_ScrollTo('\(searchResultsCount - index - 1)')"
            self.webView.evaluateJavaScript(js, completionHandler: { _, _ in
                completion?(index, searchResultsCount)
            })
        }
    }
    
    func stop() {
        self.webView.stopLoading()
    }
    
    func reload() {
        self.webView.reload()
    }
    
    func navigateBack() {
        self.webView.goBack()
    }
    
    func navigateForward() {
        self.webView.goForward()
    }
    
    func navigateTo(historyItem: BrowserContentState.HistoryItem) {
        if let webItem = historyItem.webItem {
            self.webView.go(to: webItem)
        }
    }
    
    func navigateTo(address: String) {
        let finalUrl = explicitUrl(address)
        guard let url = URL(string: finalUrl) else {
            return
        }
        self.webView.load(URLRequest(url: url))
    }
    
    func scrollToTop() {
        self.webView.scrollView.setContentOffset(CGPoint(x: 0.0, y: -self.webView.scrollView.contentInset.top), animated: true)
    }
    
    private var validLayout: (CGSize, UIEdgeInsets, UIEdgeInsets, UIEdgeInsets)?
    func updateLayout(size: CGSize, insets: UIEdgeInsets, fullInsets: UIEdgeInsets, safeInsets: UIEdgeInsets, transition: ComponentTransition) {
        self.validLayout = (size, insets, fullInsets, safeInsets)
        
        self.previousScrollingOffset = ScrollingOffsetState(value: self.webView.scrollView.contentOffset.y, isDraggingOrDecelerating: self.webView.scrollView.isDragging || self.webView.scrollView.isDecelerating)
        
        let currentBounds = self.webView.scrollView.bounds
        let offsetToBottomEdge = max(0.0, self.webView.scrollView.contentSize.height - currentBounds.maxY)
        var bottomInset = insets.bottom
        if offsetToBottomEdge < 128.0 {
            bottomInset = fullInsets.bottom
        }
        
        let webViewFrame = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: CGSize(width: size.width - insets.left - insets.right, height: size.height - insets.top - bottomInset))
        var refresh = false
        if self.webView.frame.width > 0 && webViewFrame.width != self.webView.frame.width {
            refresh = true
        }
        transition.setFrame(view: self.webView, frame: webViewFrame)
        
        if refresh {
            self.webView.reloadInputViews()
        }
        
        if fullInsets.bottom.isZero {
            self.webView.customBottomInset = safeInsets.bottom
        } else {
            self.webView.customBottomInset = safeInsets.bottom * (1.0 - insets.bottom / fullInsets.bottom)
        }
//        self.webView.scrollView.verticalScrollIndicatorInsets = UIEdgeInsets(top: 0.0, left: -insets.left, bottom: 0.0, right: -insets.right)
//        self.webView.scrollView.horizontalScrollIndicatorInsets = UIEdgeInsets(top: 0.0, left: -insets.left, bottom: 0.0, right: -insets.right)
        
        if let error = self.currentError {
            let errorSize = self.errorView.update(
                transition: .immediate,
                component: AnyComponent(
                    ErrorComponent(
                        theme: self.presentationData.theme,
                        title: self.presentationData.strings.Browser_ErrorTitle,
                        text: error.localizedDescription,
                        insets: insets
                    )
                ),
                environment: {},
                containerSize: CGSize(width: size.width, height: size.height)
            )
            if self.errorView.superview == nil {
                self.addSubview(self.errorView)
                self.errorView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
            }
            self.errorView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - errorSize.width) / 2.0), y: insets.top + floorToScreenPixels((size.height - insets.top - insets.bottom - errorSize.height) / 2.0)), size: errorSize)
        } else if self.errorView.superview != nil {
            self.errorView.removeFromSuperview()
        }
    }
    
    private func updateState(_ f: (BrowserContentState) -> BrowserContentState) {
        let updated = f(self._state)
        self._state = updated
        self.statePromise.set(.single(self._state))
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "title" {
            self.updateState { $0.withUpdatedTitle(self.webView.title ?? "") }
        } else if keyPath == "URL" {
            if let url = self.webView.url {
                self.updateState { $0.withUpdatedUrl(url.absoluteString) }
            }
            self.didSetupSearch = false
        }  else if keyPath == "estimatedProgress" {
            if self.webView.estimatedProgress >= 0.1 && self.webView.alpha.isZero {
                self.webView.alpha = 1.0
                self.webView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
            self.updateState { $0.withUpdatedEstimatedProgress(self.webView.estimatedProgress) }
        } else if keyPath == "canGoBack" {
            self.updateState { $0.withUpdatedCanGoBack(self.webView.canGoBack) }
        } else if keyPath == "canGoForward" {
            self.updateState { $0.withUpdatedCanGoForward(self.webView.canGoForward) }
        } else if keyPath == "hasOnlySecureContent" {
            self.updateState { $0.withUpdatedIsSecure(self.webView.hasOnlySecureContent) }
        }
    }
    
    private struct ScrollingOffsetState: Equatable {
        var value: CGFloat
        var isDraggingOrDecelerating: Bool
    }
    
    private var previousScrollingOffset: ScrollingOffsetState?
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateScrollingOffset(isReset: false, transition: .immediate)
    }
    
    private func snapScrollingOffsetToInsets() {
        let transition = ComponentTransition(animation: .curve(duration: 0.4, curve: .spring))
        self.updateScrollingOffset(isReset: false, transition: transition)
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            self.snapScrollingOffsetToInsets()
            
            if self.ignoreUpdatesUntilScrollingStopped {
                self.ignoreUpdatesUntilScrollingStopped = false
            }
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.snapScrollingOffsetToInsets()
        
        if self.ignoreUpdatesUntilScrollingStopped {
            self.ignoreUpdatesUntilScrollingStopped = false
        }
    }
    
    private func updateScrollingOffset(isReset: Bool, transition: ComponentTransition) {
        guard !self.ignoreUpdatesUntilScrollingStopped else {
            return
        }
        let scrollView = self.webView.scrollView
        let isInteracting = scrollView.isDragging || scrollView.isDecelerating
        if let previousScrollingOffsetValue = self.previousScrollingOffset {
            let currentBounds = scrollView.bounds
            let offsetToTopEdge = max(0.0, currentBounds.minY - 0.0)
            let offsetToBottomEdge = max(0.0, scrollView.contentSize.height - currentBounds.maxY)
            
            let relativeOffset = scrollView.contentOffset.y - previousScrollingOffsetValue.value
            self.onScrollingUpdate(ContentScrollingUpdate(
                relativeOffset: relativeOffset,
                absoluteOffsetToTopEdge: offsetToTopEdge,
                absoluteOffsetToBottomEdge: offsetToBottomEdge,
                isReset: isReset,
                isInteracting: isInteracting,
                transition: transition
            ))
        }
        self.previousScrollingOffset = ScrollingOffsetState(value: scrollView.contentOffset.y, isDraggingOrDecelerating: isInteracting)
        
        var readingProgress: CGFloat = 0.0
        if !scrollView.contentSize.height.isZero {
            let value = (scrollView.contentOffset.y + scrollView.contentInset.top) / (scrollView.contentSize.height - scrollView.bounds.size.height + scrollView.contentInset.top)
            readingProgress = max(0.0, min(1.0, value))
        }
        self.updateState {
            $0.withUpdatedReadingProgress(readingProgress)
        }
    }
    
    private var ignoreUpdatesUntilScrollingStopped = false
    func resetScrolling() {
        self.updateScrollingOffset(isReset: true, transition: .spring(duration: 0.4))
        if self.webView.scrollView.isDecelerating {
            self.ignoreUpdatesUntilScrollingStopped = true
        }
    }
    
    @available(iOS 13.0, *)
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        if #available(iOS 14.5, *), navigationAction.shouldPerformDownload {
            if navigationAction.request.url?.scheme == "blob" {
                decisionHandler(.allow, preferences)
            } else {
                self.presentDownloadConfirmation(fileName: navigationAction.request.mainDocumentURL?.lastPathComponent ?? "file", proceed: { download in
                    if download {
                        decisionHandler(.download, preferences)
                    } else {
                        decisionHandler(.cancel, preferences)
                    }
                })
            }
        } else {
            if let url = navigationAction.request.url?.absoluteString {
                if (navigationAction.targetFrame == nil || navigationAction.targetFrame?.isMainFrame == true) && (isTelegramMeLink(url) || isTelegraPhLink(url) || url.hasPrefix("tg://")) && !url.contains("/auth/push?") && !self._state.url.contains("/auth/push?") {
                    decisionHandler(.cancel, preferences)
                    self.minimize()
                    self.openAppUrl(url)
                } else {
                    if let scheme = navigationAction.request.url?.scheme, !["http", "https", "tonsite", "about"].contains(scheme.lowercased()) {
                        decisionHandler(.cancel, preferences)
                        self.context.sharedContext.openExternalUrl(context: self.context, urlContext: .generic, url: url, forceExternal: true, presentationData: self.presentationData, navigationController: nil, dismissInput: {})
                    } else {
                        decisionHandler(.allow, preferences)
                    }
                }
            } else {
                decisionHandler(.allow, preferences)
            }
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if navigationResponse.canShowMIMEType || navigationResponse.response.url?.scheme == "tonsite" {
            decisionHandler(.allow)
        } else if #available(iOS 14.5, *) {
            if navigationResponse.response.suggestedFilename?.lowercased().hasSuffix(".pkpass") == true {
                decisionHandler(.download)
            } else {
                if let url = navigationResponse.response.url, url.scheme == "blob" {
                    decisionHandler(.cancel)
                    self.requestBlobSaveToFiles(url: url)
                } else {
                    self.presentDownloadConfirmation(fileName: navigationResponse.response.suggestedFilename ?? "file", proceed: { download in
                        if download {
                            decisionHandler(.download)
                        } else {
                            decisionHandler(.cancel)
                        }
                    })
                }
            }
        } else {
            decisionHandler(.cancel)
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url?.absoluteString {
            if (navigationAction.targetFrame == nil || navigationAction.targetFrame?.isMainFrame == true) && (isTelegramMeLink(url) || isTelegraPhLink(url) || url.hasPrefix("tg://")) {
                decisionHandler(.cancel)
                self.minimize()
                self.openAppUrl(url)
            } else {
                decisionHandler(.allow)
            }
        } else {
            decisionHandler(.allow)
        }
    }

    private var downloadArguments: (String, String)?
    private var downloadController: (AlertController, (Int64, Int64) -> Void)?
    private var downloadProgressObserver: Any?
    
    @available(iOS 14.5, *)
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }
    
    @available(iOS 14.5, *)
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }
        
    @available(iOS 14.5, *)
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let path = NSTemporaryDirectory() + NSUUID().uuidString
        self.downloadArguments = (path, suggestedFilename)
        completionHandler(URL(fileURLWithPath: path))
        
        let downloadController = progressAlertController(sharedContext: self.context.sharedContext, title: "", cancel: { [weak download] in
            download?.cancel()
        })
        self.downloadController = downloadController
        self.present(downloadController.0, nil)
        downloadController.1(download.progress.completedUnitCount, download.progress.totalUnitCount)
        
        self.downloadProgressObserver = download.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            if let (_, update) = self?.downloadController {
                update(progress.completedUnitCount, progress.totalUnitCount)
            }
        }
    }
    
    @available(iOS 14.5, *)
    func downloadDidFinish(_ download: WKDownload) {
        if let (controller, _ ) = self.downloadController {
            controller.dismissAnimated()
            self.downloadController = nil
        }
        
        if let (path, fileName) = self.downloadArguments {
            let tempFile = TempBox.shared.file(path: path, fileName: fileName)
            let url = URL(fileURLWithPath: tempFile.path)
            
            if fileName.hasSuffix(".pkpass") {
                if let data = try? Data(contentsOf: url), let pass = try? PKPass(data: data) {
                    let passLibrary = PKPassLibrary()
                    if passLibrary.containsPass(pass) {
                        let alertController = textAlertController(context: self.context, updatedPresentationData: nil, title: nil, text: self.presentationData.strings.WebBrowser_PassExistsError, actions: [TextAlertAction(type: .genericAction, title: self.presentationData.strings.Common_OK, action: {})])
                        self.present(alertController, nil)
                    } else if let controller = PKAddPassesViewController(pass: pass) {
                        self.getNavigationController()?.view.window?.rootViewController?.present(controller, animated: true)
                    }
                }
            } else {
                let controller = legacyICloudFilePicker(theme: self.presentationData.theme, mode: .export, url: url, documentTypes: [], forceDarkTheme: false, dismissed: {}, completion: { _ in
                    let _ = tempFile
                })
                self.present(controller, nil)
            }
            
            self.downloadArguments = nil
            self.downloadProgressObserver = nil
        }
    }
    
    @available(iOS 14.5, *)
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        self.downloadArguments = nil
        self.downloadProgressObserver = nil
    }
        
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard [NSURLAuthenticationMethodDefault, NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodHTTPDigest].contains(challenge.protectionSpace.authenticationMethod) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        var completed = false
                
        let host = webView.url?.host ?? ""
        
        let authController = authController(
            sharedContext: self.context.sharedContext,
            updatedPresentationData: nil,
            title: self.presentationData.strings.WebBrowser_AuthChallenge_Title(host).string,
            text: self.presentationData.strings.WebBrowser_AuthChallenge_Text,
            apply: { result in
                if !completed {
                    completed = true
                    if let (login, password) = result {
                        let credential = URLCredential(
                            user: login,
                            password: password,
                            persistence: .permanent
                        )
                        completionHandler(.useCredential, credential)
                    } else {
                        completionHandler(.cancelAuthenticationChallenge, nil)
                    }
                }
            }
        )
        authController.dismissed = { byOutsideTap in
            if byOutsideTap {
                if !completed {
                    completed = true
                    completionHandler(.cancelAuthenticationChallenge, nil)
                }
            }
        }
        self.present(authController, nil)
    }
    
    private let isLoaded = ValuePromise<Bool>(false)
    private var instantPageDisposable = MetaDisposable()
    private var instantPage: TelegramMediaWebpage?
    private var instantPageResources: [Any]?
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if let _ = self.currentError {
            self.currentError = nil
            if let (size, insets, fullInsets, safeInsets) = self.validLayout {
                self.updateLayout(size: size, insets: insets, fullInsets: fullInsets, safeInsets: safeInsets, transition: .immediate)
            }
        }
        self.updateFontState(self.currentFontState, force: true)
        
        self.readability = nil
        self.instantPage = nil
        self.instantPageResources = nil
        self.isLoaded.set(false)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.updateState {$0
            .withUpdatedBackList(webView.backForwardList.backList.map { BrowserContentState.HistoryItem(webItem: $0) })
            .withUpdatedForwardList(webView.backForwardList.forwardList.map { BrowserContentState.HistoryItem(webItem: $0) })
        }
        self.parseFavicon()
        
        self.isLoaded.set(true)
    }
    
    func releaseInstantView() {
        self.instantPageDisposable.set(nil)
    }
        
    func requestInstantView() {
        guard self.readability == nil else {
            return
        }
        
        self.instantPageDisposable.set(
            (self.isLoaded.get()
            |> filter { $0 }
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] _ in
                guard let self else {
                    return
                }
                guard let url = URL(string: self._state.url) else {
                    return
                }
                
                if #available(iOS 14.5, *) {
                    self.webView.createWebArchiveData { [weak self] result in
                        guard let self, case let .success(data) = result else {
                            return
                        }
                        let readability = Readability(url: url, archiveData: data, completionHandler: { [weak self] result, error in
                            guard let self else {
                                return
                            }
                            if let (webPage, resources) = result {
                                self.updateState {$0
                                    .withUpdatedHasInstantView(true)
                                }
                                self.instantPage = webPage
                                self.instantPageResources = resources
                                let _ = (updatedRemoteWebpage(postbox: self.context.account.postbox, network: self.context.account.network, accountPeerId: self.context.account.peerId, webPage: WebpageReference(TelegramMediaWebpage(webpageId: MediaId(namespace: 0, id: 0), content: .Loaded(TelegramMediaWebpageLoadedContent(url: self._state.url, displayUrl: "", hash: 0, type: nil, websiteName: nil, title: nil, text: nil, embedUrl: nil, embedType: nil, embedSize: nil, duration: nil, author: nil, isMediaLargeByDefault: nil, imageIsVideoCover: false, image: nil, file: nil, story: nil, attributes: [], instantPage: nil)))))
                                |> deliverOnMainQueue).start(next: { [weak self] webPage in
                                    guard let self, let webPage, case let .Loaded(result) = webPage.content, let _ = result.instantPage else {
                                        return
                                    }
                                    self.instantPage = webPage
                                })
                            } else {
                                self.instantPage = nil
                                self.instantPageResources = nil
                                self.updateState {$0
                                    .withUpdatedHasInstantView(false)
                                }
                            }
                        })
                        self.readability = readability
                    }
                }
            })
        )
    }
    
    func requestSaveToFiles() {
        self.webView.evaluateJavaScript("document.contentType") { result, _ in
            guard let contentType = result as? String else {
                return
            }
            if #available(iOS 14.0, *), contentType == "text/html" {
                self.webView.createWebArchiveData { [weak self] result in
                    guard let self, case let .success(data) = result else {
                        return
                    }
                    let path = NSTemporaryDirectory() + NSUUID().uuidString
                    let _ = try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
                    
                    let tempFile = TempBox.shared.file(path: path, fileName: "\(self._state.title).webarchive")
                    let url = URL(fileURLWithPath: tempFile.path)
                    
                    let controller = legacyICloudFilePicker(theme: self.presentationData.theme, mode: .export, url: url, documentTypes: [], forceDarkTheme: false, dismissed: {}, completion: { _ in
                        
                    })
                    self.present(controller, nil)
                }
            } else {
                let s = """
                        var xhr = new XMLHttpRequest();
                        xhr.open('GET', "\(self._state.url)", true);
                        xhr.responseType = 'arraybuffer';
                        xhr.onload = function(e) {
                        if (this.status == 200) {
                        var uInt8Array = new Uint8Array(this.response);
                        var i = uInt8Array.length;
                        var binaryString = new Array(i);
                        while (i--){
                        binaryString[i] = String.fromCharCode(uInt8Array[i]);
                        }
                        var data = binaryString.join('');
                        var base64 = window.btoa(data);
                        
                        window.webkit.messageHandlers.contentInterface.postMessage(base64);
                        }
                        };
                        xhr.send();
                        """
                self.webView.evaluateJavaScript(s)
            }
        }
    }
    
    struct BlobComponents: Codable {
        let mimeType: String
        let size: Int64
        let dataString: String
    }
    
    func requestBlobSaveToFiles(url: URL) {
        guard #available(iOS 14.0, *) else {
            return
        }
        let script = """
                       async function createBlobFromUrl(url) {
                         const response = await fetch(url);
                         const blob = await response.blob();
                         return blob;
                       }
                   
                       function blobToDataURLAsync(blob) {
                         return new Promise((resolve, reject) => {
                           const reader = new FileReader();
                           reader.onload = () => {
                             resolve(reader.result);
                           };
                           reader.onerror = reject;
                           reader.readAsDataURL(blob);
                         });
                       }
                   
                       const url = await createBlobFromUrl(blobUrl)
                       return await blobToDataURLAsync(url)
                   """
        
        self.webView.callAsyncJavaScript(script,
                                    arguments: ["blobUrl": url.absoluteString],
                                    in: nil,
                                    in: WKContentWorld.defaultClient) { result in
            switch result {
            case .success(let dataUrl):
                guard let url = URL(string: dataUrl as! String) else {
                    print("Failed to get data")
                    return
                }
                guard let data = try? Data(contentsOf: url) else {
                    print("Failed to decode data URL")
                    return
                }
                
                print(data)
                // Do anything with the data. It was a pdf on my case.
                //So I used UIDocumentInteractionController to show the pdf
            case .failure(let error):
                print("Failed with: \(error)")
            }
        }
        
//        let urlString = url.absoluteString
//        let s = """
//        function blobToDataURL(blob, callback) {
//            var reader = new FileReader()
//            reader.onload = function(e) {callback(e.target.result.split(",")[1])}
//            reader.readAsDataURL(blob)
//        }
//        async function run() {
//            const url = "\(urlString)"
//            const blob = await fetch(url).then(r => r.blob())
//
//            blobToDataURL(blob, datauri => {
//                const responseObj = {
//                    mimeType: blob.type,
//                    size: blob.size,
//                    dataString: datauri
//                }
//                window.webkit.messageHandlers.jsListener.postMessage(JSON.stringify(responseObj))
//            })
//        }
//        run()
//        """
//        self.webView.evaluateJavaScript(s)
    }
    
    private func handleBlobRequest(_ message: WKScriptMessage) {
        guard let jsonString = message.body as? String, let jsonData = jsonString.data(using: .utf8) else {
            return
        }
        
        let decoder = JSONDecoder()
        guard let file = try? decoder.decode(BlobComponents.self, from: jsonData) else {
            return
        }
        guard let data = Data(base64Encoded: file.dataString, options: [.ignoreUnknownCharacters]) else {
            return
        }
        guard let url = URL(string: self._state.url) else {
            return
        }
        let path = NSTemporaryDirectory() + NSUUID().uuidString
        let _ = try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
        
        let fileName: String
        if !url.lastPathComponent.isEmpty {
            fileName = url.lastPathComponent
        } else {
            fileName = "default"
        }
        
        let tempFile = TempBox.shared.file(path: path, fileName: fileName)
        let fileUrl = URL(fileURLWithPath: tempFile.path)
        
        let controller = legacyICloudFilePicker(theme: self.presentationData.theme, mode: .export, url: fileUrl, documentTypes: [], forceDarkTheme: false, dismissed: {}, completion: { _ in
            
        })
        self.present(controller, nil)
    }
    
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if [-1003, -1100].contains((error as NSError).code) {
            if let url = (error as NSError).userInfo["NSErrorFailingURLKey"] as? URL, url.absoluteString.hasPrefix("itms-appss:") {
            } else {
                self.currentError = error
            }
        } else {
            self.currentError = nil
        }
        if let (size, insets, fullInsets, safeInsets) = self.validLayout {
            self.updateLayout(size: size, insets: insets, fullInsets: fullInsets, safeInsets: safeInsets, transition: .immediate)
        }
    }
        
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            if let url = navigationAction.request.url?.absoluteString {
                if isTelegramMeLink(url) || isTelegraPhLink(url) || url.hasPrefix("tg://") {
                    self.minimize()
                    self.openAppUrl(url)
                } else {
                    return self.open(url: url, configuration: configuration, new: true)
                }
            }
        }
        return nil
    }
    
    func webViewDidClose(_ webView: WKWebView) {
        Queue.mainQueue().after(0.5, {
            self.close()
        })
    }
    
    @available(iOS 15.0, *)
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.prompt)
    }
    
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        var completed = false
        let alertController = textAlertController(context: self.context, updatedPresentationData: nil, title: nil, text: message, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
            if !completed {
                completed = true
                completionHandler()
            }
        })])
        alertController.dismissed = { byOutsideTap in
            if byOutsideTap {
                if !completed {
                    completed = true
                    completionHandler()
                }
            }
        }
        self.present(alertController, nil)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        var completed = false
        let alertController = textAlertController(context: self.context, updatedPresentationData: nil, title: nil, text: message, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
            if !completed {
                completed = true
                completionHandler(false)
            }
        }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
            if !completed {
                completed = true
                completionHandler(true)
            }
        })])
        alertController.dismissed = { byOutsideTap in
            if byOutsideTap {
                if !completed {
                    completed = true
                    completionHandler(false)
                }
            }
        }
        self.present(alertController, nil)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        var completed = false
        let promptController = promptController(sharedContext: self.context.sharedContext, updatedPresentationData: nil, text: prompt, value: defaultText, apply: { value in
            if !completed {
                completed = true
                if let value = value {
                    completionHandler(value)
                } else {
                    completionHandler(nil)
                }
            }
        })
        promptController.dismissed = { byOutsideTap in
            if byOutsideTap {
                if !completed {
                    completed = true
                    completionHandler(nil)
                }
            }
        }
        self.present(promptController, nil)
    }
    
    @available(iOS 13.0, *)
    func webView(_ webView: WKWebView, contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo, completionHandler: @escaping (UIContextMenuConfiguration?) -> Void) {
        guard let url = elementInfo.linkURL else {
            completionHandler(nil)
            return
        }
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let configuration = UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            return UIMenu(title: "", children: [
                UIAction(title: presentationData.strings.Browser_ContextMenu_Open, image: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Browser"), color: presentationData.theme.contextMenu.primaryColor), handler: { [weak self] _ in
                    self?.open(url: url.absoluteString, new: false)
                }),
                UIAction(title: presentationData.strings.Browser_ContextMenu_OpenInNewTab, image: generateTintedImage(image: UIImage(bundleImageName: "Instant View/NewTab"), color: presentationData.theme.contextMenu.primaryColor), handler: { [weak self] _ in
                    self?.open(url: url.absoluteString, new: true)
                }),
                UIAction(title: presentationData.strings.Browser_ContextMenu_AddToReadingList, image: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ReadingList"), color: presentationData.theme.contextMenu.primaryColor), handler: { _ in
                    let _ = try? SSReadingList.default()?.addItem(with: url, title: nil, previewText: nil)
                }),
                UIAction(title: presentationData.strings.Browser_ContextMenu_CopyLink, image: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: presentationData.theme.contextMenu.primaryColor), handler: { [weak self] _ in
                    UIPasteboard.general.string = url.absoluteString
                    self?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
                }),
                UIAction(title: presentationData.strings.Browser_ContextMenu_Share, image: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: presentationData.theme.contextMenu.primaryColor), handler: { [weak self] _ in
                    self?.share(url: url.absoluteString)
                })
            ])
        }
        completionHandler(configuration)
    }
    
    private func presentDownloadConfirmation(fileName: String, proceed: @escaping (Bool) -> Void) {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        var completed = false
        let alertController = textAlertController(context: self.context, updatedPresentationData: nil, title: nil, text: presentationData.strings.WebBrowser_Download_Confirmation(fileName).string, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
            if !completed {
                completed = true
                proceed(false)
            }
        }), TextAlertAction(type: .defaultAction, title: presentationData.strings.WebBrowser_Download_Download, action: {
            if !completed {
                completed = true
                proceed(true)
            }
        })])
        alertController.dismissed = { byOutsideTap in
            if byOutsideTap {
                if !completed {
                    completed = true
                    proceed(false)
                }
            }
        }
        self.present(alertController, nil)
    }
    
    @discardableResult private func open(url: String, configuration: WKWebViewConfiguration? = nil, new: Bool) -> WKWebView? {
        let subject: BrowserScreen.Subject = .webPage(url: url)
        if new, let navigationController = self.getNavigationController() {
            navigationController._keepModalDismissProgress = true
            self.minimize()
            let controller = BrowserScreen(context: self.context, subject: subject, preferredConfiguration: configuration, openPreviousOnClose: true)
            navigationController._keepModalDismissProgress = true
            navigationController.pushViewController(controller)
            return (controller.node.content.last as? BrowserWebContent)?.webView
        } else {
            self.pushContent(subject, nil)
        }
        return nil
    }
    
    private func share(url: String) {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let shareController = ShareController(context: self.context, subject: .url(url))
        shareController.actionCompleted = { [weak self] in
            self?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
        }
        self.present(shareController, nil)
    }
    
    private func parseFavicon() {
        let addToRecentsWhenReady = self.addToRecentsWhenReady
        self.addToRecentsWhenReady = false
        
        struct Favicon: Equatable, Hashable {
            let url: String
            let dimensions: PixelDimensions?
            
            func hash(into hasher: inout Hasher) {
                hasher.combine(self.url)
                if let dimensions = self.dimensions {
                    hasher.combine(dimensions.width)
                    hasher.combine(dimensions.height)
                }
            }
        }
        
        let js = """
            (function() {
                var favicons = [];
                var nodeList = document.getElementsByTagName('link');
                for (var i = 0; i < nodeList.length; i++)
                {
                    if((nodeList[i].getAttribute('rel') == 'icon')||(nodeList[i].getAttribute('rel') == 'shortcut icon')||(nodeList[i].getAttribute('rel').startsWith('apple-touch-icon')))
                    {
                        const node = nodeList[i];
                        favicons.push({
                            url: node.getAttribute('href'),
                            sizes: node.getAttribute('sizes')
                        });
                    }
                }
                return favicons;
            })();
        """
        self.webView.evaluateJavaScript(js, completionHandler: { [weak self] jsResult, _ in
            guard let self, let favicons = jsResult as? [Any] else {
                return
            }
            var result = Set<Favicon>();
            for favicon in favicons {
                if let faviconDict = favicon as? [String: Any], let urlString = faviconDict["url"] as? String {
                    if let url = URL(string: urlString, relativeTo: self.webView.url) {
                        let sizesString = faviconDict["sizes"] as? String;
                        let sizeStrings = sizesString?.components(separatedBy: "x") ?? []
                        if (sizeStrings.count == 2) {
                            let width = Int(sizeStrings[0])
                            let height = Int(sizeStrings[1])
                            let dimensions: PixelDimensions?
                            if let width, let height {
                                dimensions = PixelDimensions(width: Int32(width), height: Int32(height))
                            } else {
                                dimensions = nil
                            }
                            result.insert(Favicon(url: url.absoluteString, dimensions: dimensions))
                        } else {
                            result.insert(Favicon(url: url.absoluteString, dimensions: nil))
                        }
                    }
                }
            }
            
            if result.isEmpty, let webViewUrl = self.webView.url,  let schemeAndHostUrl = URL(string: "/", relativeTo: webViewUrl) {
                let url = schemeAndHostUrl.appendingPathComponent("favicon.ico")
                result.insert(Favicon(url: url.absoluteString, dimensions: nil))
            }
            
            var largestIcon: Favicon? // = result.first(where: { $0.url.lowercased().contains(".svg") })
            if largestIcon == nil {
                largestIcon = result.first
                for icon in result {
                    let maxSize = largestIcon?.dimensions?.width ?? 0
                    if let width = icon.dimensions?.width, width > maxSize {
                        largestIcon = icon
                    }
                }
            }
                                                
            if let favicon = largestIcon {
                self.faviconDisposable.set((fetchFavicon(context: self.context, url: favicon.url, size: CGSize(width: 20.0, height: 20.0))
                |> deliverOnMainQueue).startStrict(next: { [weak self] favicon in
                    guard let self else {
                        return
                    }
                    self.updateState { $0.withUpdatedFavicon(favicon) }
                    
                    if addToRecentsWhenReady {
                        var image: TelegramMediaImage?
                        
                        if let favicon, let imageData = favicon.pngData() {
                            let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                            self.context.account.postbox.mediaBox.storeResourceData(resource.id, data: imageData)
                            image = TelegramMediaImage(
                                imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: Int64.random(in: Int64.min ... Int64.max)),
                                representations: [
                                    TelegramMediaImageRepresentation(
                                        dimensions: PixelDimensions(width: Int32(favicon.size.width), height: Int32(favicon.size.height)),
                                        resource: resource,
                                        progressiveSizes: [],
                                        immediateThumbnailData: nil,
                                        hasVideo: false,
                                        isPersonal: false
                                    )
                                ],
                                immediateThumbnailData: nil,
                                reference: nil,
                                partialReference: nil,
                                flags: []
                            )
                        }
                        
                        let webPage = TelegramMediaWebpage(webpageId: MediaId(namespace: 0, id: 0), content: .Loaded(TelegramMediaWebpageLoadedContent(
                            url: self._state.url,
                            displayUrl: self._state.url,
                            hash: 0,
                            type: "",
                            websiteName: self._state.title,
                            title: self._state.title,
                            text: nil,
                            embedUrl: nil,
                            embedType: nil,
                            embedSize: nil,
                            duration: nil,
                            author: nil,
                            isMediaLargeByDefault: nil,
                            imageIsVideoCover: false,
                            image: image,
                            file: nil,
                            story: nil,
                            attributes: [],
                            instantPage: nil))
                        )
                        
                        let _ = addRecentlyVisitedLink(engine: self.context.engine, webPage: webPage).startStandalone()
                    }
                }))
            }
        })
    }
    
    private var addToRecentsWhenReady = false
    func addToRecentlyVisited() {
        self.addToRecentsWhenReady = true
    }
    
    func makeContentSnapshotView() -> UIView? {
        let configuration = WKSnapshotConfiguration()
        configuration.rect = CGRect(origin: .zero, size: self.webView.frame.size)

        let imageView = UIImageView()
        imageView.frame = CGRect(origin: .zero, size: self.webView.frame.size)
        self.webView.takeSnapshot(with: configuration, completionHandler: { image, _ in
            imageView.image = image
        })
        return imageView
    }
}

private final class ErrorComponent: CombinedComponent {
    let theme: PresentationTheme
    let title: String
    let text: String
    let insets: UIEdgeInsets
  
    init(
        theme: PresentationTheme,
        title: String,
        text: String,
        insets: UIEdgeInsets
    ) {
        self.theme = theme
        self.title = title
        self.text = text
        self.insets = insets
    }
    
    static func ==(lhs: ErrorComponent, rhs: ErrorComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.insets != rhs.insets {
            return false
        }
        return true
    }
    
    static var body: Body {
        let background = Child(Rectangle.self)
        let animation = Child(LottieComponent.self)
        let title = Child(MultilineTextComponent.self)
        let text = Child(MultilineTextComponent.self)

        return { context in
            var contentHeight: CGFloat = 0.0
            let animationSize = 148.0
            let animationSpacing: CGFloat = 8.0
            let textSpacing: CGFloat = 8.0
            
            let constrainedWidth = context.availableSize.width - 76.0 - context.component.insets.left - context.component.insets.right
            
            let background = background.update(
                component: Rectangle(color: context.component.theme.list.plainBackgroundColor),
                availableSize: context.availableSize,
                transition: .immediate
            )
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            let animation = animation.update(
                component: LottieComponent(
                    content: LottieComponent.AppBundleContent(name: "ChatListNoResults")
                ),
                environment: {},
                availableSize: CGSize(width: animationSize, height: animationSize),
                transition: .immediate
            )
            contentHeight += animation.size.height + animationSpacing
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: context.component.title,
                        font: Font.semibold(17.0),
                        textColor: context.component.theme.list.itemSecondaryTextColor
                    )),
                    horizontalAlignment: .center
                ),
                environment: {},
                availableSize: CGSize(width: constrainedWidth, height: context.availableSize.height),
                transition: .immediate
            )
            contentHeight += title.size.height + textSpacing
            
            let text = text.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: context.component.text,
                        font: Font.regular(15.0),
                        textColor: context.component.theme.list.itemSecondaryTextColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0
                ),
                environment: {},
                availableSize: CGSize(width: constrainedWidth, height: context.availableSize.height),
                transition: .immediate
            )
            contentHeight += text.size.height
            
            var originY = floor((context.availableSize.height - contentHeight) / 2.0)
            context.add(animation
                .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + animation.size.height / 2.0))
            )
            originY += animation.size.height + animationSpacing
            
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + title.size.height / 2.0))
            )
            originY += title.size.height + textSpacing
            
            context.add(text
                .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + text.size.height / 2.0))
            )
            
            return context.availableSize
        }
    }
}

let setupFontFunctions = """
(function() {
  const styleId = 'telegram-font-overrides';

  function setTelegramFontOverrides(font, textSizeAdjust) {
    let style = document.getElementById(styleId);

    if (!style) {
      style = document.createElement('style');
      style.id = styleId;
      document.head.appendChild(style);
    }

    let cssRules = '* {';
    if (font !== null) {
        cssRules += `
        font-family: ${font} !important;
        `;
    }
    if (textSizeAdjust !== null) {
        cssRules += `
        -webkit-text-size-adjust: ${textSizeAdjust} !important;
        `;
    }
    cssRules += '}';

    style.innerHTML = cssRules;

    if (font === null && textSizeAdjust === null) {
      style.parentNode.removeChild(style);
    }
  }
  window.setTelegramFontOverrides = setTelegramFontOverrides;
})();
"""

private let videoSource = """
document.addEventListener('DOMContentLoaded', () => {
function tgBrowserDisableWebkitEnterFullscreen(videoElement) {
  if (videoElement && videoElement.webkitEnterFullscreen) {
    videoElement.setAttribute('playsinline', '');
  }
}

function tgBrowserDisableFullscreenOnExistingVideos() {
  document.querySelectorAll('video').forEach(tgBrowserDisableWebkitEnterFullscreen);
}

function tgBrowserHandleMutations(mutations) {
  mutations.forEach((mutation) => {
    if (mutation.addedNodes && mutation.addedNodes.length > 0) {
      mutation.addedNodes.forEach((newNode) => {
        if (newNode.tagName === 'VIDEO') {
          tgBrowserDisableWebkitEnterFullscreen(newNode);
        }
        if (newNode.querySelectorAll) {
          newNode.querySelectorAll('video').forEach(tgBrowserDisableWebkitEnterFullscreen);
        }
      });
    }
  });
}

tgBrowserDisableFullscreenOnExistingVideos();

const _tgbrowser_observer = new MutationObserver(tgBrowserHandleMutations);

_tgbrowser_observer.observe(document.body, {
  childList: true,
  subtree: true
});

function tgBrowserDisconnectObserver() {
  _tgbrowser_observer.disconnect();
}
});
"""

let setupTouchObservers =
"""
(function() {
    function saveOriginalCssProperties(element) {
        while (element) {
            const computedStyle = window.getComputedStyle(element);
            const propertiesToSave = ['transform', 'top', 'left'];
            
            element._originalProperties = {};

            for (const property of propertiesToSave) {
                element._originalProperties[property] = computedStyle.getPropertyValue(property);
            }
            
            element = element.parentElement;
        }
    }

    function checkForCssChanges(element) {
        while (element) {
            if (!element._originalProperties) return false;
            const computedStyle = window.getComputedStyle(element);
            const modifiedProperties = ['transform', 'top', 'left'];

            for (const property of modifiedProperties) {
                if (computedStyle.getPropertyValue(property) !== element._originalProperties[property]) {
                    return true;
                }
            }
            
            element = element.parentElement;
        }
        
        return false;
    }

    function clearOriginalCssProperties(element) {
        while (element) {
            delete element._originalProperties;
            element = element.parentElement;
        }
    }

    let touchedElement = null;

    document.addEventListener('touchstart', function(event) {
        touchedElement = event.target;
        saveOriginalCssProperties(touchedElement);
    }, { passive: true });

    document.addEventListener('touchmove', function(event) {
        if (checkForCssChanges(touchedElement)) {
            TelegramWebviewProxy.postEvent("cancellingTouch", {})
            console.log('CSS properties changed during touchmove');
        }
    }, { passive: true });

    document.addEventListener('touchend', function() {
        clearOriginalCssProperties(touchedElement);
        touchedElement = null;
    }, { passive: true });
})();
"""

private let eventProxySource = "var TelegramWebviewProxyProto = function() {}; " +
    "TelegramWebviewProxyProto.prototype.postEvent = function(eventName, eventData) { " +
    "window.webkit.messageHandlers.performAction.postMessage({'eventName': eventName, 'eventData': eventData}); " +
    "}; " +
"var TelegramWebviewProxy = new TelegramWebviewProxyProto();"

@available(iOS 16.0, *)
final class BrowserSearchOptions: UITextSearchOptions {
    override var wordMatchMethod: UITextSearchOptions.WordMatchMethod {
        return .contains
    }

    override var stringCompareOptions: NSString.CompareOptions {
        return .caseInsensitive
    }
}

private func findScrollView(view: UIView?) -> UIScrollView? {
    if let view = view {
        if let view = view as? UIScrollView {
            return view
        }
        return findScrollView(view: view.superview)
    } else {
        return nil
    }
}
