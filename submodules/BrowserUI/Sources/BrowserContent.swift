import Foundation
import UIKit
import ComponentFlow
import SwiftSignalKit

final class BrowserContentState: Equatable {
    enum ContentType: Equatable {
        case webPage
        case instantPage
    }
    
    let title: String
    let url: String
    let estimatedProgress: Double
    let contentType: ContentType
    
    var canGoBack: Bool
    var canGoForward: Bool
    
    init(
        title: String,
        url: String,
        estimatedProgress: Double,
        contentType: ContentType,
        canGoBack: Bool = false,
        canGoForward: Bool = false
    ) {
        self.title = title
        self.url = url
        self.estimatedProgress = estimatedProgress
        self.contentType = contentType
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
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
        if lhs.contentType != rhs.contentType {
            return false
        }
        if lhs.canGoBack != rhs.canGoBack {
            return false
        }
        if lhs.canGoForward != rhs.canGoForward {
            return false
        }
        return true
    }
    
    func withUpdatedTitle(_ title: String) -> BrowserContentState {
        return BrowserContentState(title: title, url: self.url, estimatedProgress: self.estimatedProgress, contentType: self.contentType, canGoBack: self.canGoBack, canGoForward: self.canGoForward)
    }
    
    func withUpdatedUrl(_ url: String) -> BrowserContentState {
        return BrowserContentState(title: self.title, url: url, estimatedProgress: self.estimatedProgress, contentType: self.contentType, canGoBack: self.canGoBack, canGoForward: self.canGoForward)
    }
    
    func withUpdatedEstimatedProgress(_ estimatedProgress: Double) -> BrowserContentState {
        return BrowserContentState(title: self.title, url: self.url, estimatedProgress: estimatedProgress, contentType: self.contentType, canGoBack: self.canGoBack, canGoForward: self.canGoForward)
    }
    
    func withUpdatedCanGoBack(_ canGoBack: Bool) -> BrowserContentState {
        return BrowserContentState(title: self.title, url: self.url, estimatedProgress: self.estimatedProgress, contentType: self.contentType, canGoBack: canGoBack, canGoForward: self.canGoForward)
    }
    
    func withUpdatedCanGoForward(_ canGoForward: Bool) -> BrowserContentState {
        return BrowserContentState(title: self.title, url: self.url, estimatedProgress: self.estimatedProgress, contentType: self.contentType, canGoBack: self.canGoBack, canGoForward: canGoForward)
    }
}

protocol BrowserContent: UIView {
    var state: Signal<BrowserContentState, NoError> { get }
    
    var onScrollingUpdate: (ContentScrollingUpdate) -> Void { get set }
        
    func navigateBack()
    func navigateForward()
    
    func setFontSize(_ fontSize: CGFloat)
    func setForceSerif(_ force: Bool)
    
    func setSearch(_ query: String?, completion: ((Int) -> Void)?)
    func scrollToPreviousSearchResult(completion: ((Int, Int) -> Void)?)
    func scrollToNextSearchResult(completion: ((Int, Int) -> Void)?)
    
    func scrollToTop()
    
    func updateLayout(size: CGSize, insets: UIEdgeInsets, transition: Transition)
}

struct ContentScrollingUpdate {
    public var relativeOffset: CGFloat
    public var absoluteOffsetToTopEdge: CGFloat?
    public var absoluteOffsetToBottomEdge: CGFloat?
    public var isReset: Bool
    public var isInteracting: Bool
    public var transition: Transition
    
    public init(
        relativeOffset: CGFloat,
        absoluteOffsetToTopEdge: CGFloat?,
        absoluteOffsetToBottomEdge: CGFloat?,
        isReset: Bool,
        isInteracting: Bool,
        transition: Transition
    ) {
        self.relativeOffset = relativeOffset
        self.absoluteOffsetToTopEdge = absoluteOffsetToTopEdge
        self.absoluteOffsetToBottomEdge = absoluteOffsetToBottomEdge
        self.isReset = isReset
        self.isInteracting = isInteracting
        self.transition = transition
    }
}
