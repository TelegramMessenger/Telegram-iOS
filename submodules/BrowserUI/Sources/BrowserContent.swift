import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import WebKit
import TelegramPresentationData

final class BrowserContentState: Equatable {
    enum ContentType: Equatable {
        case webPage
        case instantPage
        case document
    }
    
    struct HistoryItem: Equatable {
        let url: String
        let title: String
        let uuid: UUID?
        let webItem: WKBackForwardListItem?
        
        init(url: String, title: String, uuid: UUID) {
            self.url = url
            self.title = title
            self.uuid = uuid
            self.webItem = nil
        }
        
        init(webItem: WKBackForwardListItem) {
            self.url = webItem.url.absoluteString
            self.title = webItem.title ?? ""
            self.uuid = nil
            self.webItem = webItem
        }
    }
    
    let title: String
    let url: String
    let estimatedProgress: Double
    let readingProgress: Double
    let contentType: ContentType
    let favicon: UIImage?
    let isSecure: Bool
    let hasInstantView: Bool
    let isInnerInstantViewEnabled: Bool
    
    let canGoBack: Bool
    let canGoForward: Bool
    
    let backList: [HistoryItem]
    let forwardList: [HistoryItem]
    
    init(
        title: String,
        url: String,
        estimatedProgress: Double,
        readingProgress: Double,
        contentType: ContentType,
        favicon: UIImage? = nil,
        isSecure: Bool = false,
        hasInstantView: Bool = false,
        isInnerInstantViewEnabled: Bool = false,
        canGoBack: Bool = false,
        canGoForward: Bool = false,
        backList: [HistoryItem] = [],
        forwardList: [HistoryItem] = []
    ) {
        self.title = title
        self.url = url
        self.estimatedProgress = estimatedProgress
        self.readingProgress = readingProgress
        self.contentType = contentType
        self.favicon = favicon
        self.isSecure = isSecure
        self.hasInstantView = hasInstantView
        self.isInnerInstantViewEnabled = isInnerInstantViewEnabled
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.backList = backList
        self.forwardList = forwardList
    }
    
    static func == (lhs: BrowserContentState, rhs: BrowserContentState) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.url != rhs.url {
            return false
        }
        if lhs.estimatedProgress != rhs.estimatedProgress {
            return false
        }
        if lhs.readingProgress != rhs.readingProgress {
            return false
        }
        if lhs.contentType != rhs.contentType {
            return false
        }
        if (lhs.favicon == nil) != (rhs.favicon == nil) {
            return false
        }
        if lhs.isSecure != rhs.isSecure {
            return false
        }
        if lhs.hasInstantView != rhs.hasInstantView {
            return false
        }
        if lhs.canGoBack != rhs.canGoBack {
            return false
        }
        if lhs.canGoForward != rhs.canGoForward {
            return false
        }
        if lhs.backList != rhs.backList {
            return false
        }
        if lhs.forwardList != rhs.forwardList {
            return false
        }
        return true
    }
    
    func withUpdatedTitle(_ title: String) -> BrowserContentState {
        return BrowserContentState(title: title, url: self.url, estimatedProgress: self.estimatedProgress, readingProgress: self.readingProgress, contentType: self.contentType, favicon: self.favicon, isSecure: self.isSecure, hasInstantView: self.hasInstantView, isInnerInstantViewEnabled: self.isInnerInstantViewEnabled, canGoBack: self.canGoBack, canGoForward: self.canGoForward, backList: self.backList, forwardList: self.forwardList)
    }
    
    func withUpdatedUrl(_ url: String) -> BrowserContentState {
        return BrowserContentState(title: self.title, url: url, estimatedProgress: self.estimatedProgress, readingProgress: self.readingProgress, contentType: self.contentType, favicon: self.favicon, isSecure: self.isSecure, hasInstantView: self.hasInstantView, isInnerInstantViewEnabled: self.isInnerInstantViewEnabled, canGoBack: self.canGoBack, canGoForward: self.canGoForward, backList: self.backList, forwardList: self.forwardList)
    }
    
    func withUpdatedIsSecure(_ isSecure: Bool) -> BrowserContentState {
        return BrowserContentState(title: self.title, url: self.url, estimatedProgress: self.estimatedProgress, readingProgress: self.readingProgress, contentType: self.contentType, favicon: self.favicon, isSecure: isSecure, hasInstantView: self.hasInstantView, isInnerInstantViewEnabled: self.isInnerInstantViewEnabled, canGoBack: self.canGoBack, canGoForward: self.canGoForward, backList: self.backList, forwardList: self.forwardList)
    }
    
    func withUpdatedHasInstantView(_ hasInstantView: Bool) -> BrowserContentState {
        return BrowserContentState(title: self.title, url: self.url, estimatedProgress: self.estimatedProgress, readingProgress: self.readingProgress, contentType: self.contentType, favicon: self.favicon, isSecure: self.isSecure, hasInstantView: hasInstantView, isInnerInstantViewEnabled: self.isInnerInstantViewEnabled, canGoBack: self.canGoBack, canGoForward: self.canGoForward, backList: self.backList, forwardList: self.forwardList)
    }
    
    func withUpdatedIsInnerInstantViewEnabled(_ isInnerInstantViewEnabled: Bool) -> BrowserContentState {
        return BrowserContentState(title: self.title, url: self.url, estimatedProgress: self.estimatedProgress, readingProgress: self.readingProgress, contentType: self.contentType, favicon: self.favicon, isSecure: self.isSecure, hasInstantView: self.hasInstantView, isInnerInstantViewEnabled: isInnerInstantViewEnabled, canGoBack: self.canGoBack, canGoForward: self.canGoForward, backList: self.backList, forwardList: self.forwardList)
    }
    
    func withUpdatedEstimatedProgress(_ estimatedProgress: Double) -> BrowserContentState {
        return BrowserContentState(title: self.title, url: self.url, estimatedProgress: estimatedProgress, readingProgress: self.readingProgress, contentType: self.contentType, favicon: self.favicon, isSecure: self.isSecure, hasInstantView: self.hasInstantView, isInnerInstantViewEnabled: self.isInnerInstantViewEnabled, canGoBack: self.canGoBack, canGoForward: self.canGoForward, backList: self.backList, forwardList: self.forwardList)
    }
    
    func withUpdatedReadingProgress(_ readingProgress: Double) -> BrowserContentState {
        return BrowserContentState(title: self.title, url: self.url, estimatedProgress: self.estimatedProgress, readingProgress: readingProgress, contentType: self.contentType, favicon: self.favicon, isSecure: self.isSecure, hasInstantView: self.hasInstantView, isInnerInstantViewEnabled: self.isInnerInstantViewEnabled, canGoBack: self.canGoBack, canGoForward: self.canGoForward, backList: self.backList, forwardList: self.forwardList)
    }
    
    func withUpdatedFavicon(_ favicon: UIImage?) -> BrowserContentState {
        return BrowserContentState(title: self.title, url: self.url, estimatedProgress: self.estimatedProgress, readingProgress: self.readingProgress, contentType: self.contentType, favicon: favicon, isSecure: self.isSecure, hasInstantView: self.hasInstantView, isInnerInstantViewEnabled: self.isInnerInstantViewEnabled, canGoBack: self.canGoBack, canGoForward: self.canGoForward, backList: self.backList, forwardList: self.forwardList)
    }
    
    func withUpdatedCanGoBack(_ canGoBack: Bool) -> BrowserContentState {
        return BrowserContentState(title: self.title, url: self.url, estimatedProgress: self.estimatedProgress, readingProgress: self.readingProgress, contentType: self.contentType, favicon: self.favicon, isSecure: self.isSecure, hasInstantView: self.hasInstantView, isInnerInstantViewEnabled: self.isInnerInstantViewEnabled, canGoBack: canGoBack, canGoForward: self.canGoForward, backList: self.backList, forwardList: self.forwardList)
    }
    
    func withUpdatedCanGoForward(_ canGoForward: Bool) -> BrowserContentState {
        return BrowserContentState(title: self.title, url: self.url, estimatedProgress: self.estimatedProgress, readingProgress: self.readingProgress, contentType: self.contentType, favicon: self.favicon, isSecure: self.isSecure, hasInstantView: self.hasInstantView, isInnerInstantViewEnabled: self.isInnerInstantViewEnabled, canGoBack: self.canGoBack, canGoForward: canGoForward, backList: self.backList, forwardList: self.forwardList)
    }
    
    func withUpdatedBackList(_ backList: [HistoryItem]) -> BrowserContentState {
        return BrowserContentState(title: self.title, url: self.url, estimatedProgress: self.estimatedProgress, readingProgress: self.readingProgress, contentType: self.contentType, favicon: self.favicon, isSecure: self.isSecure, hasInstantView: self.hasInstantView, isInnerInstantViewEnabled: self.isInnerInstantViewEnabled, canGoBack: self.canGoBack, canGoForward: self.canGoForward, backList: backList, forwardList: self.forwardList)
    }
    
    func withUpdatedForwardList(_ forwardList: [HistoryItem]) -> BrowserContentState {
        return BrowserContentState(title: self.title, url: self.url, estimatedProgress: self.estimatedProgress, readingProgress: self.readingProgress, contentType: self.contentType, favicon: self.favicon, isSecure: self.isSecure, hasInstantView: self.hasInstantView, isInnerInstantViewEnabled: self.isInnerInstantViewEnabled, canGoBack: self.canGoBack, canGoForward: self.canGoForward, backList: self.backList, forwardList: forwardList)
    }
}

protocol BrowserContent: UIView {
    var uuid: UUID { get }
    
    var currentState: BrowserContentState { get }
    var state: Signal<BrowserContentState, NoError> { get }
    
    var pushContent: (BrowserScreen.Subject, BrowserContent?) -> Void { get set }
    var present: (ViewController, Any?) -> Void { get set }
    var presentInGlobalOverlay: (ViewController) -> Void { get set }
    var getNavigationController: () -> NavigationController? { get set }
    var openAppUrl: (String) -> Void { get set }
    
    var minimize: () -> Void { get set }
    var close: () -> Void { get set }
    
    var onScrollingUpdate: (ContentScrollingUpdate) -> Void { get set }
    func resetScrolling()
    
    func reload()
    func stop()
    
    func navigateBack()
    func navigateForward()
    func navigateTo(historyItem: BrowserContentState.HistoryItem)
    
    func toggleInstantView(_ enabled: Bool)
    
    func updatePresentationData(_ presentationData: PresentationData)
    func updateFontState(_ state: BrowserPresentationState.FontState)
    
    func setSearch(_ query: String?, completion: ((Int) -> Void)?)
    func scrollToPreviousSearchResult(completion: ((Int, Int) -> Void)?)
    func scrollToNextSearchResult(completion: ((Int, Int) -> Void)?)
    
    func scrollToTop()
    
    func addToRecentlyVisited()
    
    func updateLayout(size: CGSize, insets: UIEdgeInsets, fullInsets: UIEdgeInsets, safeInsets: UIEdgeInsets, transition: ComponentTransition)
    
    func makeContentSnapshotView() -> UIView?
}

struct ContentScrollingUpdate {
    public var relativeOffset: CGFloat
    public var absoluteOffsetToTopEdge: CGFloat?
    public var absoluteOffsetToBottomEdge: CGFloat?
    public var isReset: Bool
    public var isInteracting: Bool
    public var transition: ComponentTransition
    
    public init(
        relativeOffset: CGFloat,
        absoluteOffsetToTopEdge: CGFloat?,
        absoluteOffsetToBottomEdge: CGFloat?,
        isReset: Bool,
        isInteracting: Bool,
        transition: ComponentTransition
    ) {
        self.relativeOffset = relativeOffset
        self.absoluteOffsetToTopEdge = absoluteOffsetToTopEdge
        self.absoluteOffsetToBottomEdge = absoluteOffsetToBottomEdge
        self.isReset = isReset
        self.isInteracting = isInteracting
        self.transition = transition
    }
}
