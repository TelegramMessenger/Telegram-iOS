import Foundation
import UIKit

/// The sender's third-party verification icon (a bot-verification custom emoji) on a bubble's author line. It sits left
/// of the name, as the chat header draws it left of the title: a 20pt icon, 4pt before the name.
public enum ChatMessageAuthorVerificationIcon {
    public static let size = CGSize(width: 20.0, height: 20.0)
    public static let spacing: CGFloat = 4.0

    /// What the icon takes from the name's line, its spacing included; zero without an icon.
    public static func leadingWidth(iconSize: CGSize?) -> CGFloat {
        guard let iconSize else {
            return 0.0
        }
        return iconSize.width + self.spacing
    }

    /// The icon takes the place `nameFrame` would have had, centred on the name's line, and the name follows it. Without
    /// an icon the name keeps `nameFrame`.
    public static func layout(nameFrame: CGRect, iconSize: CGSize?) -> (name: CGRect, icon: CGRect?) {
        guard let iconSize else {
            return (nameFrame, nil)
        }
        let icon = CGRect(origin: CGPoint(x: nameFrame.minX, y: nameFrame.minY + floor((nameFrame.height - iconSize.height) / 2.0)), size: iconSize)
        return (nameFrame.offsetBy(dx: self.leadingWidth(iconSize: iconSize), dy: 0.0), icon)
    }
}
