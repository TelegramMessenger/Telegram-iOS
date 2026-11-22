import Foundation
import UIKit
import TelegramPresentationData
import TelegramUIPreferences
import GlassBackgroundComponent

public final class ChatInputAccessoryPanelEnvironment: Equatable {
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

    public static func ==(lhs: ChatInputAccessoryPanelEnvironment, rhs: ChatInputAccessoryPanelEnvironment) -> Bool {
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

public final class ChatInputAccessoryPanelTransitionData {
    public let titleView: UIView
    public let textView: UIView
    public let lineView: UIView
    public let imageView: UIView?
    
    public init(titleView: UIView, textView: UIView, lineView: UIView, imageView: UIView?) {
        self.titleView = titleView
        self.textView = textView
        self.lineView = lineView
        self.imageView = imageView
    }
}

public protocol ChatInputAccessoryPanelView: UIView {
    var contentTintView: UIView { get }
    var storedFrameBeforeDismissed: CGRect? { get set }
    var transitionData: ChatInputAccessoryPanelTransitionData? { get }
}
