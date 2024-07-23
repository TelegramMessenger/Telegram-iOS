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
import WebKit
import AppBundle
import PromptUI
import SafariServices
import ShareController
import UndoUI
import LottieComponent
import MultilineTextComponent
import UrlEscaping

private final class TonSchemeHandler: NSObject, WKURLSchemeHandler {
    private final class PendingTask {
        let sourceTask: any WKURLSchemeTask
        var urlSessionTask: URLSessionTask?
        let isCompleted = Atomic<Bool>(value: false)
        
        init(proxyServerHost: String, sourceTask: any WKURLSchemeTask) {
            self.sourceTask = sourceTask
            
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
                    sourceTask.didFailWithError(error)
                } else {
                    if let response {
                        if let response = response as? HTTPURLResponse, let requestUrl {
                            if let updatedResponse = HTTPURLResponse(
                                url: requestUrl,
                                statusCode: response.statusCode,
                                httpVersion: "HTTP/1.1",
                                headerFields: response.allHeaderFields as? [String: String] ?? [:]
                            ) {
                                sourceTask.didReceive(updatedResponse)
                            } else {
                                sourceTask.didReceive(response)
                            }
                        } else {
                            sourceTask.didReceive(response)
                        }
                    }
                    if let data {
                        sourceTask.didReceive(data)
                    }
                    sourceTask.didFinish()
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

final class BrowserWebContent: UIView, BrowserContent, WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate {
    private let context: AccountContext
    private var presentationData: PresentationData
    
    private let webView: WKWebView
    
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
    
    var pushContent: (BrowserScreen.Subject) -> Void = { _ in }
    var onScrollingUpdate: (ContentScrollingUpdate) -> Void = { _ in }
    var minimize: () -> Void = { }
    var close: () -> Void = { }
    var present: (ViewController, Any?) -> Void = { _, _ in }
    var presentInGlobalOverlay: (ViewController) -> Void = { _ in }
    var getNavigationController: () -> NavigationController? = { return nil }
    
    private var tempFile: TempBoxFile?
    
    init(context: AccountContext, presentationData: PresentationData, url: String) {
        self.context = context
        self.uuid = UUID()
        self.presentationData = presentationData
        
        let configuration = WKWebViewConfiguration()
        
//        let bundle = Bundle.main
//        let bundleVersion = bundle.infoDictionary?["CFBundleShortVersionString"] ?? ""
//        
        var proxyServerHost = "magic.org"
        if let data = context.currentAppConfiguration.with({ $0 }).data, let hostValue = data["ton_proxy_address"] as? String {
            proxyServerHost = hostValue
        }
        configuration.setURLSchemeHandler(TonSchemeHandler(proxyServerHost: proxyServerHost), forURLScheme: "tonsite")
        configuration.allowsInlineMediaPlayback = true
//        configuration.applicationNameForUserAgent = "Telegram-iOS/\(bundleVersion)"
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            configuration.mediaTypesRequiringUserActionForPlayback = []
        } else {
            configuration.mediaPlaybackRequiresUserAction = false
        }
        
        self.webView = WKWebView(frame: CGRect(), configuration: configuration)
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
            
            title = parsedUrl.host ?? ""
        }
        
        self.errorView = ComponentHostView()
        
        self._state = BrowserContentState(title: title, url: url, estimatedProgress: 0.0, readingProgress: 0.0, contentType: .webPage)
        self.statePromise = Promise<BrowserContentState>(self._state)
        
        super.init(frame: .zero)
        
        self.webView.allowsBackForwardNavigationGestures = true
        self.webView.scrollView.delegate = self
        self.webView.scrollView.clipsToBounds = false
//        self.webView.translatesAutoresizingMaskIntoConstraints = false
        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self
        self.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: [], context: nil)
        self.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: [], context: nil)
        self.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: [], context: nil)
        self.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack), options: [], context: nil)
        self.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward), options: [], context: nil)
        self.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.hasOnlySecureContent), options: [], context: nil)
        if #available(iOS 15.0, *) {
            self.backgroundColor = presentationData.theme.list.plainBackgroundColor
            self.webView.underPageBackgroundColor = presentationData.theme.list.plainBackgroundColor
        }
        if #available(iOS 16.4, *) {
            self.webView.isInspectable = true
        }
        self.addSubview(self.webView)
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
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        if #available(iOS 15.0, *) {
            self.backgroundColor = presentationData.theme.list.plainBackgroundColor
            self.webView.underPageBackgroundColor = presentationData.theme.list.plainBackgroundColor
        }
        if let (size, insets) = self.validLayout {
            self.updateLayout(size: size, insets: insets, transition: .immediate)
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
    
    private var validLayout: (CGSize, UIEdgeInsets)?
    func updateLayout(size: CGSize, insets: UIEdgeInsets, transition: ComponentTransition) {
        self.validLayout = (size, insets)
        
        self.previousScrollingOffset = ScrollingOffsetState(value: self.webView.scrollView.contentOffset.y, isDraggingOrDecelerating: self.webView.scrollView.isDragging || self.webView.scrollView.isDecelerating)
        
        let webViewFrame = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: CGSize(width: size.width - insets.left - insets.right, height: size.height - insets.top - insets.bottom))
        var refresh = false
        if self.webView.frame.width > 0 && webViewFrame.width != self.webView.frame.width {
            refresh = true
        }
        transition.setFrame(view: self.webView, frame: webViewFrame)
        
        if refresh {
            self.webView.reloadInputViews()
        }
        
        self.webView.scrollView.scrollIndicatorInsets = UIEdgeInsets(top: 0.0, left: -insets.left, bottom: 0.0, right: -insets.right)
        self.webView.scrollView.horizontalScrollIndicatorInsets = UIEdgeInsets(top: 0.0, left: -insets.left, bottom: 0.0, right: -insets.right)
        
        if let error = self.currentError {
            let errorSize = self.errorView.update(
                transition: .immediate,
                component: AnyComponent(
                    ErrorComponent(
                        theme: self.presentationData.theme,
                        title: self.presentationData.strings.Browser_ErrorTitle,
                        text: error.localizedDescription
                    )
                ),
                environment: {},
                containerSize: CGSize(width: size.width - insets.left - insets.right - 72.0, height: size.height)
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
            self.updateState { $0.withUpdatedUrl(self.webView.url?.absoluteString ?? "") }
            self.didSetupSearch = false
        }  else if keyPath == "estimatedProgress" {
            self.updateState { $0.withUpdatedEstimatedProgress(self.webView.estimatedProgress) }
        } else if keyPath == "canGoBack" {
            self.updateState { $0.withUpdatedCanGoBack(self.webView.canGoBack) }
            self.webView.disablesInteractiveTransitionGestureRecognizer = self.webView.canGoBack
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
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.snapScrollingOffsetToInsets()
    }
    
    private func updateScrollingOffset(isReset: Bool, transition: ComponentTransition) {
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
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        self.currentError = nil
        self.updateFontState(self.currentFontState, force: true)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.updateState {
            $0
                .withUpdatedBackList(webView.backForwardList.backList.map { BrowserContentState.HistoryItem(webItem: $0) })
                .withUpdatedForwardList(webView.backForwardList.forwardList.map { BrowserContentState.HistoryItem(webItem: $0) })
        }
        self.parseFavicon()
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != -999 {
            self.currentError = error
        } else {
            self.currentError = nil
        }
        if let (size, insets) = self.validLayout {
            self.updateLayout(size: size, insets: insets, transition: .immediate)
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != -999 {
            self.currentError = error
        } else {
            self.currentError = nil
        }
        if let (size, insets) = self.validLayout {
            self.updateLayout(size: size, insets: insets, transition: .immediate)
        }
    }
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            if let url = navigationAction.request.url?.absoluteString {
                self.open(url: url, new: true)
            }
        }
        return nil
    }
    
    func webViewDidClose(_ webView: WKWebView) {
        self.close()
    }
    
    @available(iOSApplicationExtension 15.0, iOS 15.0, *)
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
                    self?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
                }),
                UIAction(title: presentationData.strings.Browser_ContextMenu_Share, image: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: presentationData.theme.contextMenu.primaryColor), handler: { [weak self] _ in
                    self?.share(url: url.absoluteString)
                })
            ])
        }
        completionHandler(configuration)
    }
    
    private func open(url: String, new: Bool) {
        let subject: BrowserScreen.Subject = .webPage(url: url)
        if new, let navigationController = self.getNavigationController() {
            navigationController._keepModalDismissProgress = true
            self.minimize()
            let controller = BrowserScreen(context: self.context, subject: subject)
            navigationController._keepModalDismissProgress = true
            navigationController.pushViewController(controller)
        } else {
            self.pushContent(subject)
        }
    }
    
    private func share(url: String) {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let shareController = ShareController(context: self.context, subject: .url(url))
        shareController.actionCompleted = { [weak self] in
            self?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
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
            var favicons = [];
            var nodeList = document.getElementsByTagName('link');
            for (var i = 0; i < nodeList.length; i++)
            {
                if((nodeList[i].getAttribute('rel') == 'icon')||(nodeList[i].getAttribute('rel') == 'shortcut icon'))
                {
                    const node = nodeList[i];
                    favicons.push({
                        url: node.getAttribute('href'),
                        sizes: node.getAttribute('sizes')
                    });
                }
            }
            favicons;
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
            
            if result.isEmpty, let webViewUrl = self.webView.url {
                let schemeAndHostUrl = webViewUrl.deletingPathExtension()
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
}

private final class ErrorComponent: CombinedComponent {
    let theme: PresentationTheme
    let title: String
    let text: String
  
    init(
        theme: PresentationTheme,
        title: String,
        text: String
    ) {
        self.theme = theme
        self.title = title
        self.text = text
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
        return true
    }
    
    static var body: Body {
        let animation = Child(LottieComponent.self)
        let title = Child(MultilineTextComponent.self)
        let text = Child(MultilineTextComponent.self)

        return { context in
            var contentHeight: CGFloat = 0.0
            let animationSize = 148.0
            let animationSpacing: CGFloat = 8.0
            let textSpacing: CGFloat = 8.0
            
            let animation = animation.update(
                component: LottieComponent(
                    content: LottieComponent.AppBundleContent(name: "ChatListNoResults")
                ),
                environment: {},
                availableSize: CGSize(width: animationSize, height: animationSize),
                transition: .immediate
            )
            context.add(animation
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + animation.size.height / 2.0))
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
                availableSize: context.availableSize,
                transition: .immediate
            )
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight +  title.size.height / 2.0))
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
                availableSize: context.availableSize,
                transition: .immediate
            )
            context.add(text
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + text.size.height / 2.0))
            )
            contentHeight += text.size.height

            return CGSize(width: context.availableSize.width, height: contentHeight)
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

@available(iOS 16.0, *)
final class BrowserSearchOptions: UITextSearchOptions {
    override var wordMatchMethod: UITextSearchOptions.WordMatchMethod {
        return .contains
    }

    override var stringCompareOptions: NSString.CompareOptions {
        return .caseInsensitive
    }
}
