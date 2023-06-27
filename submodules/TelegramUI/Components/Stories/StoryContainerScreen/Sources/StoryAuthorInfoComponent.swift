import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import TelegramCore
import TelegramStringFormatting

final class StoryAuthorInfoComponent: Component {
	let context: AccountContext
	let peer: EnginePeer?
    let timestamp: Int32
    
    init(context: AccountContext, peer: EnginePeer?, timestamp: Int32) {
        self.context = context
        self.peer = peer
        self.timestamp = timestamp
    }

	convenience init(context: AccountContext, message: EngineMessage) {
        self.init(context: context, peer: message.author, timestamp: message.timestamp)
	}

	static func ==(lhs: StoryAuthorInfoComponent, rhs: StoryAuthorInfoComponent) -> Bool {
		if lhs.context !== rhs.context {
			return false
		}
		if lhs.peer != rhs.peer {
			return false
		}
        if lhs.timestamp != rhs.timestamp {
            return false
        }
		return true
	}

	final class View: UIView {
		private let title = ComponentView<Empty>()
		private let subtitle = ComponentView<Empty>()

        private var component: StoryAuthorInfoComponent?
        private weak var state: EmptyComponentState?
        
		override init(frame: CGRect) {
			super.init(frame: frame)
            
            self.isUserInteractionEnabled = false
		}
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: StoryAuthorInfoComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            let size = availableSize
            let spacing: CGFloat = 0.0
            
            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })

            let title: String
            if component.peer?.id == component.context.account.peerId {
                //TODO:localize
                title = "Your story"
            } else {
                title = component.peer?.debugDisplayTitle ?? ""
            }
            
            let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
            let subtitle = stringForRelativeActivityTimestamp(strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, relativeTimestamp: component.timestamp, relativeTo: timestamp)
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(Text(text: title, font: Font.medium(14.0), color: .white)),
                environment: {},
                containerSize: availableSize
            )
            let subtitleSize = self.subtitle.update(
                transition: .immediate,
                component: AnyComponent(Text(text: subtitle, font: Font.regular(11.0), color: UIColor(white: 1.0, alpha: 0.8))),
                environment: {},
                containerSize: availableSize
            )
            
            let contentHeight: CGFloat = titleSize.height + spacing + subtitleSize.height
            let titleFrame = CGRect(origin: CGPoint(x: 54.0, y: 2.0 + floor((availableSize.height - contentHeight) * 0.5)), size: titleSize)
            let subtitleFrame = CGRect(origin: CGPoint(x: 54.0, y: titleFrame.maxY + spacing + UIScreenPixel), size: subtitleSize)
            
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    subtitleView.isUserInteractionEnabled = false
                    self.addSubview(subtitleView)
                }
                transition.setFrame(view: subtitleView, frame: subtitleFrame)
            }

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
