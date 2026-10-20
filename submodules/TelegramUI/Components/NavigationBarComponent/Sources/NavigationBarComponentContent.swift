import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow

/// What a bar button's renderer reads from the bar: its theme.
public final class NavigationButtonEnvironment: Equatable {
    public let theme: NavigationBarTheme

    public init(theme: NavigationBarTheme) {
        self.theme = theme
    }

    public static func ==(lhs: NavigationButtonEnvironment, rhs: NavigationButtonEnvironment) -> Bool {
        return lhs.theme === rhs.theme
    }
}

/// What a `.custom` title reads. It is laid out over the whole row, so it gets where the buttons end.
public final class NavigationBarTitleEnvironment: Equatable {
    public let theme: NavigationBarTheme
    /// From the row's left edge to the end of the left buttons, inset included.
    public let leftButtonsExtent: CGFloat
    /// From the row's right edge to the start of the right buttons, inset included.
    public let rightButtonsExtent: CGFloat

    public init(theme: NavigationBarTheme, leftButtonsExtent: CGFloat, rightButtonsExtent: CGFloat) {
        self.theme = theme
        self.leftButtonsExtent = leftButtonsExtent
        self.rightButtonsExtent = rightButtonsExtent
    }

    public static func ==(lhs: NavigationBarTitleEnvironment, rhs: NavigationBarTitleEnvironment) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.leftButtonsExtent != rhs.leftButtonsExtent {
            return false
        }
        if lhs.rightButtonsExtent != rhs.rightButtonsExtent {
            return false
        }
        return true
    }
}

extension NavigationBarComponent {
    /// The content a two-content bar shows: the secondary one from halfway into its slide (an inline forum over the
    /// chat list), else the primary.
    public static func visibleContent(primary: Content?, secondary: Content?, secondaryTransition: CGFloat) -> Content? {
        if let secondary, secondaryTransition >= 0.5 {
            return secondary
        }
        return primary
    }

    /// iPhone Duo: how a button behaves in the side column. Its title also labels the button for
    /// VoiceOver (Apple: always provide titles for icon items).
    public struct OverflowInfo: Equatable {
        public var title: String
        public var iconName: String?
        /// Higher overflows later; nil never overflows.
        public var priority: Int?
        /// The menu item's image when the button has one of its own (a bar button item's image); `iconName` names a
        /// bundle image instead.
        public var image: UIImage?

        public init(title: String, iconName: String?, priority: Int?, image: UIImage? = nil) {
            self.title = title
            self.iconName = iconName
            self.priority = priority
            self.image = image
        }
    }

    /// An item of the side column's "…" menu: a button that did not fit.
    public struct OverflowItem {
        public let id: AnyHashable
        public let title: String
        public let iconName: String?
        public let image: UIImage?
        /// The button's own action; it gets the "…" button as its source view.
        public let action: (UIView) -> Void

        public init(id: AnyHashable, title: String, iconName: String?, image: UIImage? = nil, action: @escaping (UIView) -> Void) {
            self.id = id
            self.title = title
            self.iconName = iconName
            self.image = image
            self.action = action
        }
    }

    /// A button in the row (or, on iPhone Duo, the side column).
    public struct Button: Equatable {
        public enum Content: Equatable {
            /// A text button; `___done` draws the Done checkmark. Text buttons stay in the row on iPhone Duo.
            case text(title: String, isBold: Bool)
            /// A bundle image tinted with the button color.
            case icon(imageName: String)
            /// An image as given: tinted with the button color when it is a template image, else drawn as is.
            case image(UIImage)
            case more
            /// A node the screen owns (`UIBarButtonItem(customDisplayNode:)`), hosted as is. A
            /// `HighlightableButtonNode` keeps its own touches; any other node's touches press the button. Goes into
            /// iPhone Duo's column like an icon.
            case node(ASDisplayNode)
            /// Content the bar does not know (the chat list's proxy status); the bar still handles taps and highlight.
            case custom(AnyComponent<NavigationButtonEnvironment>)

            var isText: Bool {
                if case .text = self {
                    return true
                }
                return false
            }
        }

        /// The capsule a button asks for. A capsule takes a non-generic tint only when all its buttons share it.
        public enum Tint: Equatable {
            case generic
            /// The accent capsule of a confirming button (the Done checkmark).
            case accent
            /// The same while the button is disabled.
            case accentDisabled
        }

        public let id: AnyHashable
        public let content: Content
        public let isEnabled: Bool
        public let tint: Tint
        public let overflow: OverflowInfo?
        /// A pill of its own even where UIKit's rule would put it with its neighbours (an icon beside icons): UIKit's
        /// `sharesBackground = false` (`navigationBarRightSections`).
        public let requiresOwnSection: Bool
        /// iPhone Duo: stays in the row rather than moving into the side column (`navigationBarIsColumnItem`), for a
        /// button that takes turns with a text button in the same place (Done after Edit).
        public let staysInRow: Bool
        public let action: (UIView) -> Void
        public let contextAction: ((UIView, ContextGesture?) -> Void)?

        public init(id: AnyHashable, content: Content, isEnabled: Bool = true, tint: Tint = .generic, overflow: OverflowInfo? = nil, requiresOwnSection: Bool = false, staysInRow: Bool = false, action: @escaping (UIView) -> Void, contextAction: ((UIView, ContextGesture?) -> Void)? = nil) {
            self.id = id
            self.content = content
            self.isEnabled = isEnabled
            self.tint = tint
            self.overflow = overflow
            self.requiresOwnSection = requiresOwnSection
            self.staysInRow = staysInRow
            self.action = action
            self.contextAction = contextAction
        }

        public func withOverflow(_ overflow: OverflowInfo?) -> Button {
            return Button(id: self.id, content: self.content, isEnabled: self.isEnabled, tint: self.tint, overflow: overflow, requiresOwnSection: self.requiresOwnSection, staysInRow: self.staysInRow, action: self.action, contextAction: self.contextAction)
        }

        /// Actions are not compared: they are recreated on every update.
        public static func ==(lhs: Button, rhs: Button) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.content != rhs.content {
                return false
            }
            if lhs.isEnabled != rhs.isEnabled {
                return false
            }
            if lhs.tint != rhs.tint {
                return false
            }
            if lhs.overflow != rhs.overflow {
                return false
            }
            if lhs.requiresOwnSection != rhs.requiresOwnSection {
                return false
            }
            if lhs.staysInRow != rhs.staysInRow {
                return false
            }
            return true
        }
    }

    public enum Back: Equatable {
        case back
        /// The close X of a modal stack's first screen.
        case close
    }

    public enum Title: Equatable {
        /// Semibold 17 in the theme's primary text color, centered between the buttons.
        case text(String)
        /// Centered in the band between the buttons.
        case component(AnyComponent<Empty>)
        /// Laid out over the whole row; the environment says where the buttons end.
        case custom(AnyComponent<NavigationBarTitleEnvironment>)
    }

    /// One content of the bar: the primary, or the secondary sliding in over it.
    public final class Content: Equatable {
        public let title: Title
        public let back: Back?
        /// Shown after the back button when both exist.
        public let leftButton: Button?
        /// `rightButtons[0]` is the rightmost.
        public let rightButtons: [Button]
        public let backPressed: () -> Void
        /// The back button's badge (the chat's unread count).
        public let badge: String?
        /// A long press on the back button (the chat's navigation stack); nil leaves it a plain button.
        public let backContextAction: ((UIView, ContextGesture) -> Void)?

        public init(title: Title, back: Back?, leftButton: Button?, rightButtons: [Button], backPressed: @escaping () -> Void, badge: String? = nil, backContextAction: ((UIView, ContextGesture) -> Void)? = nil) {
            self.title = title
            self.back = back
            self.leftButton = leftButton
            self.rightButtons = rightButtons
            self.backPressed = backPressed
            self.badge = badge
            self.backContextAction = backContextAction
        }

        public static func ==(lhs: Content, rhs: Content) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.title != rhs.title {
                return false
            }
            if lhs.back != rhs.back {
                return false
            }
            if lhs.leftButton != rhs.leftButton {
                return false
            }
            if lhs.rightButtons != rhs.rightButtons {
                return false
            }
            if lhs.badge != rhs.badge {
                return false
            }
            if (lhs.backContextAction == nil) != (rhs.backContextAction == nil) {
                return false
            }
            return true
        }
    }
}
