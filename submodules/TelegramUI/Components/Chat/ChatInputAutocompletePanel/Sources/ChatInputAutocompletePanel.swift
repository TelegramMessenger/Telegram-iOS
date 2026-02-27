import Foundation
import UIKit
import TelegramPresentationData
import TelegramUIPreferences
import GlassBackgroundComponent

public final class ChatInputAutocompletePanelEnvironment: Equatable {
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let nameDisplayOrder: PresentationPersonNameOrder
    public let dateTimeFormat: PresentationDateTimeFormat
    
    public init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        nameDisplayOrder: PresentationPersonNameOrder,
        dateTimeFormat: PresentationDateTimeFormat
    ) {
        self.theme = theme
        self.strings = strings
        self.nameDisplayOrder = nameDisplayOrder
        self.dateTimeFormat = dateTimeFormat
    }

    public static func ==(lhs: ChatInputAutocompletePanelEnvironment, rhs: ChatInputAutocompletePanelEnvironment) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.nameDisplayOrder != rhs.nameDisplayOrder {
            return false
        }
        if lhs.dateTimeFormat != rhs.dateTimeFormat {
            return false
        }
        return true
    }
}

public protocol ChatInputAutocompletePanelView: UIView {
    var contentTintView: UIView { get }
}
