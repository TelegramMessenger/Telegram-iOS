import Foundation
import UIKit

public struct AttachmentMainButtonState {
    public enum Background {
        case color(UIColor)
        case premium
        
        public var colorValue: UIColor? {
            if case let .color(color) = self {
                return color
            }
            return nil
        }
    }
    
    public enum Progress: Equatable {
        case none
        case side
        case center
    }
    
    public enum Font: Equatable {
        case regular
        case bold
    }
    
    public enum Position: String, Equatable {
        case top
        case bottom
        case left
        case right
    }
    
    public let text: String?
    public let badge: String?
    public let font: Font
    public let background: Background
    public let textColor: UIColor
    public let isVisible: Bool
    public let progress: Progress
    public let isEnabled: Bool
    public let hasShimmer: Bool
    public let position: Position?
    
    public init(
        text: String?,
        badge: String? = nil,
        font: Font,
        background: Background,
        textColor: UIColor,
        isVisible: Bool,
        progress: Progress,
        isEnabled: Bool,
        hasShimmer: Bool,
        position: Position? = nil
    ) {
        self.text = text
        self.badge = badge
        self.font = font
        self.background = background
        self.textColor = textColor
        self.isVisible = isVisible
        self.progress = progress
        self.isEnabled = isEnabled
        self.hasShimmer = hasShimmer
        self.position = position
    }
    
    public static var initial: AttachmentMainButtonState {
        return AttachmentMainButtonState(text: nil, font: .bold, background: .color(.clear), textColor: .clear, isVisible: false, progress: .none, isEnabled: false, hasShimmer: false)
    }
}
