import Foundation

final class ChatListPresentationData {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let timeFormat: PresentationTimeFormat
    let nameSortOrder: PresentationPersonNameOrder
    let nameDisplayOrder: PresentationPersonNameOrder
    
    init(theme: PresentationTheme, strings: PresentationStrings, timeFormat: PresentationTimeFormat, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder) {
        self.theme = theme
        self.strings = strings
        self.timeFormat = timeFormat
        self.nameSortOrder = nameSortOrder
        self.nameDisplayOrder = nameDisplayOrder
    }
}
