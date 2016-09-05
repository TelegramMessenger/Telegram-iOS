
public enum ContextMenuActionContent {
    case text(String)
}

public struct ContextMenuAction {
    public let content: ContextMenuActionContent
    public let action: () -> Void
    
    public init(content: ContextMenuActionContent, action: @escaping () -> Void) {
        self.content = content
        self.action = action
    }
}
