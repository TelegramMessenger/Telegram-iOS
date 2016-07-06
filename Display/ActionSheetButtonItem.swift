import Foundation

public enum ActionSheetButtonColor {
    case accent
    case destructive
}

public class ActionSheetButtonItem: ActionSheetItem {
    public let title: String
    public let color: ActionSheetButtonColor
    public let action: () -> Void
    
    public init(title: String, color: ActionSheetButtonColor = .accent, action: () -> Void) {
        self.title = title
        self.color = color
        self.action = action
    }
    
    public func node() -> ActionSheetItemNode {
        return ActionSheetButtonNode(title: AttributedString(string: title, font: ActionSheetButtonNode.defaultFont, textColor: self.color == .accent ? UIColor(0x1195f2) : UIColor.red()), action: self.action)
    }
}
