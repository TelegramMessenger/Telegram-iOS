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
            self.image = generateImage(size, rotatedContext: { size, context in
                let path: CGPath
                if size.width == size.height {
                    path = CGPath(ellipseIn: CGRect(origin: .zero, size: size), transform: nil)
                } else {
                    path = CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: size.height / 2.0, cornerHeight: size.height / 2.0, transform: nil)
                }
                
                context.addPath(path)
                context.clip()
                
                var locations: [CGFloat] = [0.0, 1.0]
                let colors: [CGColor]
                let icon: UIImage
                
                switch component.privacy {
                case .everyone:
                    colors = [UIColor(rgb: 0x4faaff).cgColor, UIColor(rgb: 0x017aff).cgColor]
                    icon = UIImage()
                case .closeFriends:
                    colors = [UIColor(rgb: 0x87d93a).cgColor, UIColor(rgb: 0x31b73b).cgColor]
                    icon = UIImage()
                case .contacts:
                    colors = [UIColor(rgb: 0xc36eff).cgColor, UIColor(rgb: 0x8c61fa).cgColor]
                    icon = UIImage()
                case .selectedContacts:
                    colors = [UIColor(rgb: 0xffb643).cgColor, UIColor(rgb: 0xf69a36).cgColor]
                    icon = UIImage()
                }
                
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
                context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
                
                if let cgImage = icon.cgImage {
                    context.draw(cgImage, in: CGRect(origin: .zero, size: icon.size))
                }
                
                if component.isEditable {
                    let arrowIcon = UIImage()
                    if let cgImage = arrowIcon.cgImage {
                        context.draw(cgImage, in: CGRect(origin: .zero, size: icon.size))
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
