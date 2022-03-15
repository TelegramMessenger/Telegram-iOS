import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit

final class BrowserContentState {
    let title: String
    let url: String
    let estimatedProgress: Double
    let isInstant: Bool
    
    var canGoBack: Bool
    var canGoForward: Bool
    
    init(title: String, url: String, estimatedProgress: Double, isInstant: Bool, canGoBack: Bool = false, canGoForward: Bool = false) {
        self.title = title
        self.url = url
        self.estimatedProgress = estimatedProgress
        self.isInstant = isInstant
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
    }
    
    func withUpdatedTitle(_ title: String) -> BrowserContentState {
        return BrowserContentState(title: title, url: self.url, estimatedProgress: self.estimatedProgress, isInstant: self.isInstant, canGoBack: self.canGoBack, canGoForward: self.canGoForward)
    }
    
    func withUpdatedUrl(_ url: String) -> BrowserContentState {
        return BrowserContentState(title: self.title, url: url, estimatedProgress: self.estimatedProgress, isInstant: self.isInstant, canGoBack: self.canGoBack, canGoForward: self.canGoForward)
    }
    
    func withUpdatedEstimatedProgress(_ estimatedProgress: Double) -> BrowserContentState {
        return BrowserContentState(title: self.title, url: self.url, estimatedProgress: estimatedProgress, isInstant: self.isInstant, canGoBack: self.canGoBack, canGoForward: self.canGoForward)
    }
    
    func withUpdatedCanGoBack(_ canGoBack: Bool) -> BrowserContentState {
        return BrowserContentState(title: self.title, url: self.url, estimatedProgress: self.estimatedProgress, isInstant: self.isInstant, canGoBack: canGoBack, canGoForward: self.canGoForward)
    }
    
    func withUpdatedCanGoForward(_ canGoForward: Bool) -> BrowserContentState {
        return BrowserContentState(title: self.title, url: self.url, estimatedProgress: self.estimatedProgress, isInstant: self.isInstant, canGoBack: self.canGoBack, canGoForward: canGoForward)
    }
}

protocol BrowserContent: ASDisplayNode {    
    var state: Signal<BrowserContentState, NoError> { get }
    
    func navigateBack()
    func navigateForward()
    
    func setFontSize(_ fontSize: CGFloat)
    func setForceSerif(_ force: Bool)
    
    func setSearch(_ query: String?, completion: ((Int) -> Void)?)
    func scrollToPreviousSearchResult(completion: ((Int, Int) -> Void)?)
    func scrollToNextSearchResult(completion: ((Int, Int) -> Void)?)
    
    func scrollToTop()
    
    func updateLayout(size: CGSize, insets: UIEdgeInsets, transition: ContainedViewLayoutTransition)
}
