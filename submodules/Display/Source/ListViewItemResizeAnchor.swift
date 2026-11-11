import Foundation

/// The edge of a list item that stays put on screen when its height changes, in screen terms whatever the list's
/// orientation: `top` grows and shrinks the item downward (what follows it on screen moves), `bottom` upward (what
/// precedes it moves). A message widget chooses it (`TelegramWidget.setResizeAnchor`, widget-sandbox v0.1.3).
public enum ListViewItemResizeAnchor: Equatable {
    case top
    case bottom
}
