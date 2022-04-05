import Foundation

final class BrowserInteraction {
    let navigateBack: () -> Void
    let navigateForward: () -> Void
    let share: () -> Void
    let minimize: () -> Void
    
    let openSearch: () -> Void
    let updateSearchQuery: (String) -> Void
    let dismissSearch: () -> Void
    let scrollToPreviousSearchResult: () -> Void
    let scrollToNextSearchResult: () -> Void
    
    let decreaseFontSize: () -> Void
    let increaseFontSize: () -> Void
    let resetFontSize: () -> Void
    let updateForceSerif: (Bool) -> Void
    
    init(navigateBack: @escaping () -> Void, navigateForward: @escaping () -> Void, share: @escaping () -> Void, minimize: @escaping () -> Void, openSearch: @escaping () -> Void, updateSearchQuery: @escaping (String) -> Void, dismissSearch: @escaping () -> Void, scrollToPreviousSearchResult: @escaping () -> Void, scrollToNextSearchResult: @escaping () -> Void, decreaseFontSize: @escaping () -> Void, increaseFontSize: @escaping () -> Void, resetFontSize: @escaping () -> Void, updateForceSerif: @escaping (Bool) -> Void) {
        self.navigateBack = navigateBack
        self.navigateForward = navigateForward
        self.share = share
        self.minimize = minimize
        self.openSearch = openSearch
        self.updateSearchQuery = updateSearchQuery
        self.dismissSearch = dismissSearch
        self.scrollToPreviousSearchResult = scrollToPreviousSearchResult
        self.scrollToNextSearchResult = scrollToNextSearchResult
        self.decreaseFontSize = decreaseFontSize
        self.increaseFontSize = increaseFontSize
        self.resetFontSize = resetFontSize
        self.updateForceSerif = updateForceSerif
    }
}
