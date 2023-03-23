import Foundation
import UIKit
import ComponentFlow
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import WebKit
import AppBundle

final class BrowserWebContent: UIView, BrowserContent, UIScrollViewDelegate {
    private let webView: WKWebView
    
    private var _state: BrowserContentState
    private let statePromise: Promise<BrowserContentState>
    
    var state: Signal<BrowserContentState, NoError> {
        return self.statePromise.get()
    }
    
    var onScrollingUpdate: (ContentScrollingUpdate) -> Void = { _ in }
    
    init(url: String) {
        let configuration = WKWebViewConfiguration()
        
        self.webView = WKWebView(frame: CGRect(), configuration: configuration)
        self.webView.allowsLinkPreview = false
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.webView.scrollView.contentInsetAdjustmentBehavior = .never
        }
        
        var title: String = ""
        if let parsedUrl = URL(string: url) {
            let request = URLRequest(url: parsedUrl)
            self.webView.load(request)
            
            title = parsedUrl.host ?? ""
        }
        
        self._state = BrowserContentState(title: title, url: url, estimatedProgress: 0.0, contentType: .webPage)
        self.statePromise = Promise<BrowserContentState>(self._state)
        
        super.init(frame: .zero)
        
        self.webView.allowsBackForwardNavigationGestures = true
        self.webView.scrollView.delegate = self
        self.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: [], context: nil)
        self.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: [], context: nil)
        self.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: [], context: nil)
        self.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack), options: [], context: nil)
        self.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward), options: [], context: nil)
        
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
    }
    
    func setFontSize(_ fontSize: CGFloat) {
        let js = "document.getElementsByTagName('body')[0].style.webkitTextSizeAdjust='\(Int(fontSize * 100.0))%'"
        self.webView.evaluateJavaScript(js, completionHandler: nil)
    }
    
    func setForceSerif(_ force: Bool) {
        let js: String
        if force {
            js = "document.getElementsByTagName(\'body\')[0].style.fontFamily = 'Georgia, serif';"
        } else {
            js = "document.getElementsByTagName(\'body\')[0].style.fontFamily = '\"Lucida Grande\", \"Lucida Sans Unicode\", Arial, Helvetica, Verdana, sans-serif';"
        }
        self.webView.evaluateJavaScript(js) { _, _ in
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
    
    private var previousQuery: String?
    func setSearch(_ query: String?, completion: ((Int) -> Void)?) {
        guard self.previousQuery != query else {
            return
        }
        self.previousQuery = query
        self.setupSearch { [weak self] in
            if let query = query {
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
    
    private var currentSearchResult: Int = 0
    private var searchResultsCount: Int = 0
    
    func scrollToPreviousSearchResult(completion: ((Int, Int) -> Void)?) {
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
    
    func scrollToNextSearchResult(completion: ((Int, Int) -> Void)?) {
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
    
    func navigateBack() {
        self.webView.goBack()
    }
    
    func navigateForward() {
        self.webView.goForward()
    }
    
    func scrollToTop() {
        self.webView.scrollView.setContentOffset(CGPoint(x: 0.0, y: -self.webView.scrollView.contentInset.top), animated: true)
    }
    
    func updateLayout(size: CGSize, insets: UIEdgeInsets, transition: Transition) {
        var scrollInsets = insets
        scrollInsets.top = 0.0
        if self.webView.scrollView.contentInset != insets {
            self.webView.scrollView.contentInset = scrollInsets
            self.webView.scrollView.scrollIndicatorInsets = scrollInsets
        }
        self.previousScrollingOffset = ScrollingOffsetState(value: self.webView.scrollView.contentOffset.y, isDraggingOrDecelerating: self.webView.scrollView.isDragging || self.webView.scrollView.isDecelerating)
        transition.setFrame(view: self.webView, frame: CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: size.width, height: size.height - insets.top)))
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        let updateState: ((BrowserContentState) -> BrowserContentState) -> Void = { f in
            let updated = f(self._state)
            self._state = updated
            self.statePromise.set(.single(self._state))
        }
        
        if keyPath == "title" {
            updateState { $0.withUpdatedTitle(self.webView.title ?? "") }
        } else if keyPath == "URL" {
            updateState { $0.withUpdatedUrl(self.webView.url?.absoluteString ?? "") }
            self.didSetupSearch = false
        }  else if keyPath == "estimatedProgress" {
            updateState { $0.withUpdatedEstimatedProgress(self.webView.estimatedProgress) }
        } else if keyPath == "canGoBack" {
            updateState { $0.withUpdatedCanGoBack(self.webView.canGoBack) }
            self.webView.disablesInteractiveTransitionGestureRecognizer = self.webView.canGoBack
        }  else if keyPath == "canGoForward" {
            updateState { $0.withUpdatedCanGoForward(self.webView.canGoForward) }
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
        let transition = Transition(animation: .curve(duration: 0.4, curve: .spring))
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
    
    private func updateScrollingOffset(isReset: Bool, transition: Transition) {
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
    }
}
