import Foundation

final class ChatListPresentationData {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let timeFormat: PresentationTimeFormat
    
    init(theme: PresentationTheme, strings: PresentationStrings, timeFormat: PresentationTimeFormat) {
        self.theme = theme
        self.strings = strings
        self.timeFormat = timeFormat
    }
}
