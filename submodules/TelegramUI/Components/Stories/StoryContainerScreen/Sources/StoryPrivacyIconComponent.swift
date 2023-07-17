import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import TelegramCore
import AsyncDisplayKit
import AvatarNode

final class StoryPrivacyIconComponent: Component {
    enum Privacy {
        case everyone
        case closeFriends
        case contacts
        case selectedContacts
    }
    let privacy: Privacy
    let isEditable: Bool
    
    init(privacy: Privacy, isEditable: Bool) {
        self.privacy = privacy
        self.isEditable = isEditable
    }

    static func ==(lhs: StoryPrivacyIconComponent, rhs: StoryPrivacyIconComponent) -> Bool {
        if lhs.privacy != rhs.privacy {
            return false
        }
        if lhs.isEditable != rhs.isEditable {
            return false
        }
        return true
    }

    final class View: UIImageView {
        private var component: StoryPrivacyIconComponent?
        private weak var state: EmptyComponentState?
                
        func update(component: StoryPrivacyIconComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            let size = CGSize(width: component.isEditable ? 40.0 : 24.0, height: 24.0)
            self.image = generateImage(size, contextGenerator: { size, context in
                let bounds = CGRect(origin: .zero, size: size)
                context.clear(bounds)
                
                let path: CGPath
                if size.width == size.height {
                    path = CGPath(ellipseIn: bounds, transform: nil)
                } else {
                    path = CGPath(roundedRect: bounds, cornerWidth: size.height / 2.0, cornerHeight: size.height / 2.0, transform: nil)
                }
                
                context.addPath(path)
                context.clip()
                
                var locations: [CGFloat] = [1.0, 0.0]
                let colors: [CGColor]
                var icon: UIImage?
                
                switch component.privacy {
                case .everyone:
                    colors = [UIColor(rgb: 0x4faaff).cgColor, UIColor(rgb: 0x017aff).cgColor]
                    icon = UIImage(bundleImageName: "Stories/PrivacyEveryone")
                case .closeFriends:
                    colors = [UIColor(rgb: 0x87d93a).cgColor, UIColor(rgb: 0x31b73b).cgColor]
                    icon = UIImage(bundleImageName: "Stories/PrivacyCloseFriends")
                case .contacts:
                    colors = [UIColor(rgb: 0xc36eff).cgColor, UIColor(rgb: 0x8c61fa).cgColor]
                    icon = UIImage(bundleImageName: "Stories/PrivacyContacts")
                case .selectedContacts:
                    colors = [UIColor(rgb: 0xffb643).cgColor, UIColor(rgb: 0xf69a36).cgColor]
                    icon = UIImage(bundleImageName: "Stories/PrivacySelectedContacts")
                }
                
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
                context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
                
                if let icon, let cgImage = icon.cgImage {
                    context.draw(cgImage, in: CGRect(origin: CGPoint(x: component.isEditable ? 1.0 : 0.0, y: 0.0), size: icon.size))
                }
                
                if component.isEditable {
                    if let arrowIcon = UIImage(bundleImageName: "Stories/PrivacyDownArrow"), let cgImage = arrowIcon.cgImage {
                        context.draw(cgImage, in: CGRect(origin: CGPoint(x: size.width - arrowIcon.size.width - 6.0, y: floorToScreenPixels((size.height - arrowIcon.size.height) / 2.0)), size: arrowIcon.size))
                    }
                }
            })
                
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
