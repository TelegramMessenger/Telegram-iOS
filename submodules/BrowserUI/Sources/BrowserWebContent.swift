import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore
import Postbox
import SwiftSignalKit
import Display
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import WebKit
import AppBundle

final class BrowserWebContent: ASDisplayNode, BrowserContent {
    private let webView: WKWebView
    
    private var _state: BrowserContentState
    private let statePromise: Promise<BrowserContentState>
    
    var state: Signal<BrowserContentState, NoError> {
        return self.statePromise.get()
    }
    
    init(url: String) {
        let configuration = WKWebViewConfiguration()
        
        self.webView = WKWebView(frame: CGRect(), configuration: configuration)
        if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
            self.webView.allowsLinkPreview = false
        }
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.webView.scrollView.contentInsetAdjustmentBehavior = .never
        }
        
        var title: String = ""
        if let parsedUrl = URL(string: url) {
            let request = URLRequest(url: parsedUrl)
            self.webView.load(request)
            
            title = parsedUrl.host ?? ""
        }
        
        self._state = BrowserContentState(title: title, url: url, estimatedProgress: 0.0, isInstant: false)
        self.statePromise = Promise<BrowserContentState>(self._state)
        
        super.init()
        
        self.webView.allowsBackForwardNavigationGestures = true
        self.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: [], context: nil)
        self.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: [], context: nil)
        self.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: [], context: nil)
        self.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack), options: [], context: nil)
        self.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward), options: [], context: nil)
    }
    
    deinit {
        self.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.title))
        self.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.url))
        self.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
        self.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack))
        self.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward))
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addSubview(self.webView)
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
    
    var previousQuery: String?
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
    
    func updateLayout(size: CGSize, insets: UIEdgeInsets, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: self.webView, frame: CGRect(origin: CGPoint(x: 0.0, y: 56.0), size: CGSize(width: size.width, height: size.height - 56.0)))
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        let updateState: ((BrowserContentState) -> BrowserContentState) -> Void = { f in
            let updated = f(self._state)
            self._state = updated
            self.statePromise.set(.single(self._state))
        }
        
        if keyPath == "title" {
            updateState { $0.withUpdatedTitle(self.webView.title ?? "") }
        } else if keyPath == "url" {
            updateState { $0.withUpdatedUrl(self.webView.url?.absoluteString ?? "") }
            self.didSetupSearch = false
        }  else if keyPath == "estimatedProgress" {
            updateState { $0.withUpdatedEstimatedProgress(self.webView.estimatedProgress) }
        } else if keyPath == "canGoBack" {
            updateState { $0.withUpdatedCanGoBack(self.webView.canGoBack) }
        }  else if keyPath == "canGoForward" {
            updateState { $0.withUpdatedCanGoForward(self.webView.canGoForward) }
        }
    }
}
