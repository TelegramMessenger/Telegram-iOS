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
import UrlEscaping

final class BrowserDocumentContent: UIView, BrowserContent, WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate {
    private let context: AccountContext
    private var presentationData: PresentationData
    
    private let webView: WKWebView
        
    let uuid: UUID
    
    private var _state: BrowserContentState
    private let statePromise: Promise<BrowserContentState>
    
    var currentState: BrowserContentState {
        return self._state
    }
    var state: Signal<BrowserContentState, NoError> {
        return self.statePromise.get()
    }
    
    var pushContent: (BrowserScreen.Subject) -> Void = { _ in }
    var openAppUrl: (String) -> Void = { _ in }
    var onScrollingUpdate: (ContentScrollingUpdate) -> Void = { _ in }
    var minimize: () -> Void = { }
    var close: () -> Void = { }
    var present: (ViewController, Any?) -> Void = { _, _ in }
    var presentInGlobalOverlay: (ViewController) -> Void = { _ in }
    var getNavigationController: () -> NavigationController? = { return nil }
    
    private var tempFile: TempBoxFile?
    
    init(context: AccountContext, presentationData: PresentationData, file: TelegramMediaFile) {
        self.context = context
        self.uuid = UUID()
        self.presentationData = presentationData
        
        let configuration = WKWebViewConfiguration()
        self.webView = WKWebView(frame: CGRect(), configuration: configuration)
        self.webView.allowsLinkPreview = true
        
        if #available(iOS 11.0, *) {
            self.webView.scrollView.contentInsetAdjustmentBehavior = .never
        }
        
        var title: String = "file"
        if let path = self.context.account.postbox.mediaBox.completedResourcePath(file.resource) {
            var updatedPath = path
            if let fileName = file.fileName {
                let tempFile = TempBox.shared.file(path: path, fileName: fileName)
                updatedPath = tempFile.path
                self.tempFile = tempFile
                title = fileName
            }

            let request = URLRequest(url: URL(fileURLWithPath: updatedPath))
            self.webView.load(request)
        }
         
        self._state = BrowserContentState(title: title, url: "", estimatedProgress: 0.0, readingProgress: 0.0, contentType: .document)
        self.statePromise = Promise<BrowserContentState>(self._state)
        
        super.init(frame: .zero)
        
        self.webView.allowsBackForwardNavigationGestures = true
        self.webView.scrollView.delegate = self
        self.webView.scrollView.clipsToBounds = false
        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self
        if #available(iOS 15.0, *) {
            self.backgroundColor = presentationData.theme.list.plainBackgroundColor
            self.webView.underPageBackgroundColor = presentationData.theme.list.plainBackgroundColor
        }
        self.addSubview(self.webView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        if #available(iOS 15.0, *) {
            self.backgroundColor = presentationData.theme.list.plainBackgroundColor
            self.webView.underPageBackgroundColor = presentationData.theme.list.plainBackgroundColor
        }
        if let (size, insets, fullInsets) = self.validLayout {
            self.updateLayout(size: size, insets: insets, fullInsets: fullInsets, safeInsets: .zero, transition: .immediate)
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
    
    private var validLayout: (CGSize, UIEdgeInsets, UIEdgeInsets)?
    func updateLayout(size: CGSize, insets: UIEdgeInsets, fullInsets: UIEdgeInsets, safeInsets: UIEdgeInsets, transition: ComponentTransition) {
        self.validLayout = (size, insets, fullInsets)
        
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
        
//        if let error = self.currentError {
//            let errorSize = self.errorView.update(
//                transition: .immediate,
//                component: AnyComponent(
//                    ErrorComponent(
//                        theme: self.presentationData.theme,
//                        title: self.presentationData.strings.Browser_ErrorTitle,
//                        text: error.localizedDescription
//                    )
//                ),
//                environment: {},
//                containerSize: CGSize(width: size.width - insets.left - insets.right - 72.0, height: size.height)
//            )
//            if self.errorView.superview == nil {
//                self.addSubview(self.errorView)
//                self.errorView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
//            }
//            self.errorView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - errorSize.width) / 2.0), y: insets.top + floorToScreenPixels((size.height - insets.top - insets.bottom - errorSize.height) / 2.0)), size: errorSize)
//        } else if self.errorView.superview != nil {
//            self.errorView.removeFromSuperview()
//        }
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
        }  else if keyPath == "canGoForward" {
            self.updateState { $0.withUpdatedCanGoForward(self.webView.canGoForward) }
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
    
    func resetScrolling() {
        self.updateScrollingOffset(isReset: true, transition: .spring(duration: 0.4))
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
//        self.currentError = nil
        self.updateFontState(self.currentFontState, force: true)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.updateState {
            $0
                .withUpdatedBackList(webView.backForwardList.backList.map { BrowserContentState.HistoryItem(webItem: $0) })
                .withUpdatedForwardList(webView.backForwardList.forwardList.map { BrowserContentState.HistoryItem(webItem: $0) })
        }
    }
    
//    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
//        if (error as NSError).code != -999 {
//            self.currentError = error
//        } else {
//            self.currentError = nil
//        }
//        if let (size, insets) = self.validLayout {
//            self.updateLayout(size: size, insets: insets, transition: .immediate)
//        }
//    }
//    
//    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
//        if (error as NSError).code != -999 {
//            self.currentError = error
//        } else {
//            self.currentError = nil
//        }
//        if let (size, insets) = self.validLayout {
//            self.updateLayout(size: size, insets: insets, transition: .immediate)
//        }
//    }
    
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
    
    
//    @available(iOS 13.0, *)
//    func webView(_ webView: WKWebView, contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo, completionHandler: @escaping (UIContextMenuConfiguration?) -> Void) {
//        guard let url = elementInfo.linkURL else {
//            completionHandler(nil)
//            return
//        }
//        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
//        let configuration = UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
//            return UIMenu(title: "", children: [
//                UIAction(title: presentationData.strings.Browser_ContextMenu_Open, image: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Browser"), color: presentationData.theme.contextMenu.primaryColor), handler: { [weak self] _ in
//                    self?.open(url: url.absoluteString, new: false)
//                }),
//                UIAction(title: presentationData.strings.Browser_ContextMenu_OpenInNewTab, image: generateTintedImage(image: UIImage(bundleImageName: "Instant View/NewTab"), color: presentationData.theme.contextMenu.primaryColor), handler: { [weak self] _ in
//                    self?.open(url: url.absoluteString, new: true)
//                }),
//                UIAction(title: presentationData.strings.Browser_ContextMenu_AddToReadingList, image: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/ReadingList"), color: presentationData.theme.contextMenu.primaryColor), handler: { _ in
//                    let _ = try? SSReadingList.default()?.addItem(with: url, title: nil, previewText: nil)
//                }),
//                UIAction(title: presentationData.strings.Browser_ContextMenu_CopyLink, image: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: presentationData.theme.contextMenu.primaryColor), handler: { [weak self] _ in
//                    UIPasteboard.general.string = url.absoluteString
//                    self?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
//                }),
//                UIAction(title: presentationData.strings.Browser_ContextMenu_Share, image: generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: presentationData.theme.contextMenu.primaryColor), handler: { [weak self] _ in
//                    self?.share(url: url.absoluteString)
//                })
//            ])
//        }
//        completionHandler(configuration)
//    }
    
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
    
    func addToRecentlyVisited() {
    }
    
    func makeContentSnapshotView() -> UIView? {
        return nil
    }
}
