import Foundation

public enum ActionSheetButtonColor {
    case accent
    case destructive
}

public class ActionSheetButtonItem: ActionSheetItem {
    public let title: String
    public let color: ActionSheetButtonColor
    public let action: () -> Void
    
    public init(title: String, color: ActionSheetButtonColor = .accent, action: @escaping () -> Void) {
        self.title = title
        self.color = color
        self.action = action
    }
    
    public func node() -> ActionSheetItemNode {
        let textColorIsAccent = self.color == ActionSheetButtonColor.accent
        let textColor = textColorIsAccent ? UIColor(0x007ee5) : UIColor.red
        return ActionSheetButtonNode(title: NSAttributedString(string: title, font: ActionSheetButtonNode.defaultFont, textColor: textColor), action: self.action)
    }
}
