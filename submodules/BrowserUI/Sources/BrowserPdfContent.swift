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
import AppBundle
import PromptUI
import SafariServices
import ShareController
import UndoUI
import UrlEscaping
import PDFKit

final class BrowserPdfContent: UIView, BrowserContent, UIScrollViewDelegate, PDFDocumentDelegate {
    private let context: AccountContext
    private var presentationData: PresentationData
    let file: FileMediaReference
    
    private let pdfView: PDFView
    private let scrollView: UIScrollView!
    
    private let pageIndicatorBackgorund: UIVisualEffectView
    private let pageIndicator = ComponentView<Empty>()
    private var pageNumber: (Int, Int)?
    private var pageTimer: SwiftSignalKit.Timer?
    
    let uuid: UUID
    
    private var _state: BrowserContentState
    private let statePromise: Promise<BrowserContentState>
    
    var currentState: BrowserContentState {
        return self._state
    }
    var state: Signal<BrowserContentState, NoError> {
        return self.statePromise.get()
    }
    
    var pushContent: (BrowserScreen.Subject, BrowserContent?) -> Void = { _, _ in }
    var openAppUrl: (String) -> Void = { _ in }
    var onScrollingUpdate: (ContentScrollingUpdate) -> Void = { _ in }
    var minimize: () -> Void = { }
    var close: () -> Void = { }
    var present: (ViewController, Any?) -> Void = { _, _ in }
    var presentInGlobalOverlay: (ViewController) -> Void = { _ in }
    var getNavigationController: () -> NavigationController? = { return nil }
    
    private var tempFile: TempBoxFile?
    
    init(context: AccountContext, presentationData: PresentationData, file: FileMediaReference) {
        self.context = context
        self.uuid = UUID()
        self.presentationData = presentationData
        self.file = file
        
        self.pdfView = PDFView()
        self.pdfView.clipsToBounds = false
        
        self.pageIndicatorBackgorund = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        self.pageIndicatorBackgorund.clipsToBounds = true
        self.pageIndicatorBackgorund.layer.cornerRadius = 10.0
        
        var scrollView: UIScrollView?
        for view in self.pdfView.subviews {
            if let view = view as? UIScrollView {
                scrollView = view
            } else {
                for subview in view.subviews {
                    if let subview = subview as? UIScrollView {
                        scrollView = subview
                    }
                }
            }
        }
        self.scrollView = scrollView
        scrollView?.clipsToBounds = false
        
        self.pdfView.displayDirection = .vertical
        self.pdfView.autoScales = true
        
        var title = "file"
        var url = ""
        if let path = self.context.account.postbox.mediaBox.completedResourcePath(file.media.resource) {
            var updatedPath = path
            if let fileName = file.media.fileName {
                let tempFile = TempBox.shared.file(path: path, fileName: fileName)
                updatedPath = tempFile.path
                self.tempFile = tempFile
                title = fileName
                url = updatedPath
            }
            self.pdfView.document = PDFDocument(url: URL(fileURLWithPath: updatedPath))
        }
         
        self._state = BrowserContentState(title: title, url: url, estimatedProgress: 0.0, readingProgress: 0.0, contentType: .document)
        self.statePromise = Promise<BrowserContentState>(self._state)
        
        super.init(frame: .zero)
        
        if #available(iOS 15.0, *) {
            self.backgroundColor = presentationData.theme.list.plainBackgroundColor
        }
        self.addSubview(self.pdfView)
        
        Queue.mainQueue().after(1.0) {
            if let scrollView = self.scrollView {
                scrollView.delegate = self
            }
        }
        
        self.pageNumber = (1, self.pdfView.document?.pageCount ?? 1)
        
        self.startPageIndicatorTimer()
        
        self.pdfView.interactiveTransitionGestureRecognizerTest = { [weak self] point in
            if let self {
                if let result = self.pdfView.hitTest(point, with: nil), let scrollView = findScrollView(view: result), scrollView.isDescendant(of: self.pdfView) {
                    if scrollView.contentSize.width > scrollView.frame.width, scrollView.contentOffset.x > -scrollView.contentInset.left {
                        return true
                    }
                }
            }
            return false
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.pageChangeHandler(_:)), name: .PDFViewPageChanged, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .PDFViewPageChanged, object: nil)
    }
    
    @objc func pageChangeHandler(_ notification: Notification) {
        if let document = self.pdfView.document, let page = self.pdfView.currentPage {
            let number = document.index(for: page) + 1
            if number != self.pageNumber?.0 {
                self.pageNumber = (number, document.pageCount)
                if let (size, insets, fullInsets) = self.validLayout {
                    self.updateLayout(size: size, insets: insets, fullInsets: fullInsets, safeInsets: .zero, transition: .immediate)
                }
            }
        }
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        if #available(iOS 15.0, *) {
            self.backgroundColor = presentationData.theme.list.plainBackgroundColor
        }
        if let (size, insets, fullInsets) = self.validLayout {
            self.updateLayout(size: size, insets: insets, fullInsets: fullInsets, safeInsets: .zero, transition: .immediate)
        }
    }
            
    func startPageIndicatorTimer() {
        self.pageTimer?.invalidate()
        
        self.pageTimer = SwiftSignalKit.Timer(timeout: 2.0, repeat: false, completion: { [weak self] in
            guard let self else {
                return
            }
            let transition = ComponentTransition.easeInOut(duration: 0.25)
            transition.setAlpha(view: self.pageIndicatorBackgorund, alpha: 0.0)
        }, queue: Queue.mainQueue())
        self.pageTimer?.start()
    }
    
    func updateFontState(_ state: BrowserPresentationState.FontState) {
        
    }
    func updateFontState(_ state: BrowserPresentationState.FontState, force: Bool) {
    }
    
    func toggleInstantView(_ enabled: Bool) {
    }
        
    private var findSession: Any?
    private var previousQuery: String?
    private var currentSearchResult: Int = 0
    private var searchResultsCount: Int = 0
    private var searchResults: [PDFSelection] = []
    private var searchCompletion: ((Int) -> Void)?
    
    private let matchColor = UIColor(rgb: 0xd4d4d, alpha: 0.2)
    private let selectedColor = UIColor(rgb: 0xffe438)
    
    func didMatchString(_ instance: PDFSelection) {
        instance.color = self.matchColor
        self.searchResults.append(instance)
    }
    
    func documentDidEndDocumentFind(_ notification: Notification) {
        self.searchResultsCount = self.searchResults.count
        
        if let searchCompletion = self.searchCompletion {
            self.searchCompletion = nil
            searchCompletion(self.searchResultsCount)
        }
        
        self.updateSearchHighlights(highlightedSelection: self.searchResults.first)
    }
    
    func updateSearchHighlights(highlightedSelection: PDFSelection?) {
        self.pdfView.highlightedSelections = nil
        if let highlightedSelection {
            for selection in self.searchResults {
                if selection === highlightedSelection {
                    selection.color = self.selectedColor
                } else {
                    selection.color = self.matchColor
                }
            }
            self.pdfView.highlightedSelections = self.searchResults
        }
    }
    
    func setSearch(_ query: String?, completion: ((Int) -> Void)?) {
        guard let document = self.pdfView.document, self.previousQuery != query else {
            return
        }
        self.previousQuery = query
        
        if #available(iOS 16.0, *), !"".isEmpty {
            if let query {
                var findSession: UIFindSession?
                if let current = self.findSession as? UIFindSession {
                    findSession = current
                } else {
                    self.pdfView.isFindInteractionEnabled = true

                    if let session = self.pdfView.findInteraction(self.pdfView.findInteraction, sessionFor: self.pdfView) {
                        findSession = session
                        self.findSession = session
                        
                        self.pdfView.findInteraction(self.pdfView.findInteraction, didBegin: session)
                    }
                }
                if let findSession {
                    findSession.performSearch(query: query, options: BrowserSearchOptions())
                    self.pdfView.findInteraction.updateResultCount()
                    completion?(findSession.resultCount)
                }
            } else {
                if let session = self.findSession as? UIFindSession {
                    self.pdfView.findInteraction(self.pdfView.findInteraction, didEnd: session)
                    self.findSession = nil
                    self.pdfView.isFindInteractionEnabled = false
                }
            }
        } else {
            if let query {
                self.currentSearchResult = 0
                self.searchCompletion = completion
                
                document.cancelFindString()
                document.delegate = self
                document.beginFindString(query, withOptions: .caseInsensitive)
            } else {
                self.searchResults = []
                self.currentSearchResult = 0
                self.searchResultsCount = 0
                
                self.updateSearchHighlights(highlightedSelection: nil)
                
                document.cancelFindString()
                document.delegate = nil
                
                completion?(0)
            }
        }
    }
    
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
            
            if index >= 0 && index < self.searchResults.count {
                self.updateSearchHighlights(highlightedSelection: self.searchResults[index])
                
                self.pdfView.go(to: self.searchResults[index])
                completion?(index, searchResultsCount)
            }
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
            
            if index >= 0 && index < self.searchResults.count {
                self.updateSearchHighlights(highlightedSelection: self.searchResults[index])
                
                self.pdfView.go(to: self.searchResults[index])
                completion?(index, searchResultsCount)
            }
        }
    }
    
    func stop() {
    }
    
    func reload() {
    }
    
    func navigateBack() {
    }
    
    func navigateForward() {
    }
    
    func navigateTo(historyItem: BrowserContentState.HistoryItem) {
    }
    
    func navigateTo(address: String) {
    }
    
    func scrollToTop() {
        self.scrollView.setContentOffset(CGPoint(x: 0.0, y: -self.scrollView.contentInset.top), animated: true)
    }
    
    private var validLayout: (CGSize, UIEdgeInsets, UIEdgeInsets)?
    func updateLayout(size: CGSize, insets: UIEdgeInsets, fullInsets: UIEdgeInsets, safeInsets: UIEdgeInsets, transition: ComponentTransition) {
        let isFirstTime = self.validLayout == nil
        self.validLayout = (size, insets, fullInsets)
        
        self.previousScrollingOffset = ScrollingOffsetState(value: self.scrollView.contentOffset.y, isDraggingOrDecelerating: self.scrollView.isDragging || self.scrollView.isDecelerating)
        
        let currentBounds = self.scrollView.bounds
        let offsetToBottomEdge = max(0.0, self.scrollView.contentSize.height - currentBounds.maxY)
        var bottomInset = insets.bottom
        if offsetToBottomEdge < 128.0 {
            bottomInset = fullInsets.bottom
        }
        
        let pdfViewFrame = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: CGSize(width: size.width - insets.left - insets.right, height: size.height - insets.top - bottomInset))
        transition.setFrame(view: self.pdfView, frame: pdfViewFrame)
        
        let pageIndicatorSize = self.pageIndicator.update(
            transition: .immediate,
            component: AnyComponent(
                Text(text: "\(self.pageNumber?.0 ?? 1) of \(self.pageNumber?.1 ?? 1)", font: Font.with(size: 15.0, weight: .semibold, traits: .monospacedNumbers), color: self.presentationData.theme.list.itemSecondaryTextColor)
            ),
            environment: {},
            containerSize: size
        )
        if let view = self.pageIndicator.view {
            if view.superview == nil {
                self.addSubview(self.pageIndicatorBackgorund)
                self.pageIndicatorBackgorund.contentView.addSubview(view)
            }
            
            let horizontalPadding: CGFloat = 10.0
            let verticalPadding: CGFloat = 8.0
            let pageBackgroundFrame = CGRect(origin: CGPoint(x: insets.left + 20.0, y: insets.top + 16.0), size: CGSize(width: horizontalPadding * 2.0 + pageIndicatorSize.width, height: verticalPadding * 2.0 + pageIndicatorSize.height))
            
            self.pageIndicatorBackgorund.bounds = CGRect(origin: .zero, size: pageBackgroundFrame.size)
            transition.setPosition(view: self.pageIndicatorBackgorund, position: pageBackgroundFrame.center)
            view.frame = CGRect(origin: CGPoint(x: horizontalPadding, y: verticalPadding), size: pageIndicatorSize)
        }
                
        if isFirstTime {
            self.pdfView.setNeedsLayout()
            self.pdfView.layoutIfNeeded()
            self.pdfView.minScaleFactor = self.pdfView.scaleFactorForSizeToFit
        }
    }
    
    private func updateState(_ f: (BrowserContentState) -> BrowserContentState) {
        let updated = f(self._state)
        self._state = updated
        self.statePromise.set(.single(self._state))
    }
        
    private struct ScrollingOffsetState: Equatable {
        var value: CGFloat
        var isDraggingOrDecelerating: Bool
    }
    
    private var previousScrollingOffset: ScrollingOffsetState?
    
    private func snapScrollingOffsetToInsets() {
        let transition = ComponentTransition(animation: .curve(duration: 0.4, curve: .spring))
        self.updateScrollingOffset(isReset: false, transition: transition)
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        if let scrollViewDelegate = scrollView as? UIScrollViewDelegate {
            return scrollViewDelegate.viewForZooming?(in: scrollView)
        }
        return nil
    }
    
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        if let scrollViewDelegate = scrollView as? UIScrollViewDelegate {
            scrollViewDelegate.scrollViewWillBeginZooming?(scrollView, with: view)
        }
        self.resetScrolling()
        self.wasZooming = true
    }
    
    private var wasZooming = false
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        if let scrollViewDelegate = scrollView as? UIScrollViewDelegate {
            scrollViewDelegate.scrollViewDidEndZooming?(scrollView, with: view, atScale: scale)
        }
        Queue.mainQueue().after(0.1, {
            self.wasZooming = false
        })
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        if let scrollViewDelegate = scrollView as? UIScrollViewDelegate {
            scrollViewDelegate.scrollViewDidZoom?(scrollView)
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let scrollViewDelegate = scrollView as? UIScrollViewDelegate {
            scrollViewDelegate.scrollViewDidScroll?(scrollView)
        }
        if !scrollView.isZooming && !self.wasZooming {
            self.updateScrollingOffset(isReset: false, transition: .immediate)
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if let scrollViewDelegate = scrollView as? UIScrollViewDelegate {
            scrollViewDelegate.scrollViewWillBeginDragging?(scrollView)
        }
        
        let transition = ComponentTransition.easeInOut(duration: 0.1)
        transition.setAlpha(view: self.pageIndicatorBackgorund, alpha: 1.0)
        
        self.pageTimer?.invalidate()
        self.pageTimer = nil
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if let scrollViewDelegate = scrollView as? UIScrollViewDelegate {
            scrollViewDelegate.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
        }
        if !decelerate {
            self.snapScrollingOffsetToInsets()
            
            if self.ignoreUpdatesUntilScrollingStopped {
                self.ignoreUpdatesUntilScrollingStopped = false
            }
            
            self.startPageIndicatorTimer()
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if let scrollViewDelegate = scrollView as? UIScrollViewDelegate {
            scrollViewDelegate.scrollViewDidEndDecelerating?(scrollView)
        }
        self.snapScrollingOffsetToInsets()
        
        if self.ignoreUpdatesUntilScrollingStopped {
            self.ignoreUpdatesUntilScrollingStopped = false
        }
        
        self.startPageIndicatorTimer()
    }
    
    private func updateScrollingOffset(isReset: Bool, transition: ComponentTransition) {
        guard !self.ignoreUpdatesUntilScrollingStopped else {
            return
        }
        guard let scrollView = self.scrollView else {
            return
        }
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
        if self.scrollView.isDecelerating {
            self.ignoreUpdatesUntilScrollingStopped = true
        }
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
            self.pushContent(subject, nil)
        }
    }
    
    private func share(url: String) {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let shareController = ShareController(context: self.context, subject: .url(url))
        shareController.actionCompleted = { [weak self] in
            self?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), nil)
        }
        self.present(shareController, nil)
    }
    
    func addToRecentlyVisited() {
    }
    
    func makeContentSnapshotView() -> UIView? {
        return nil
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
