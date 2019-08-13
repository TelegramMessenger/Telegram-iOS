import Foundation
import UIKit
import TelegramPresentationData
import TelegramUIPreferences

public final class ChatListPresentationData {
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let dateTimeFormat: PresentationDateTimeFormat
    public let nameSortOrder: PresentationPersonNameOrder
    public let nameDisplayOrder: PresentationPersonNameOrder
    public let disableAnimations: Bool
    
    public init(theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameSortOrder: PresentationPersonNameOrder, nameDisplayOrder: PresentationPersonNameOrder, disableAnimations: Bool) {
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.nameSortOrder = nameSortOrder
        self.nameDisplayOrder = nameDisplayOrder
        self.disableAnimations = disableAnimations
    }
}
