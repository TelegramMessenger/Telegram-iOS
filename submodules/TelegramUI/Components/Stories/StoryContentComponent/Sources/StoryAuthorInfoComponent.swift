import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import TelegramCore
import TelegramStringFormatting

final class StoryAuthorInfoComponent: Component {
	let context: AccountContext
	let message: EngineMessage

	init(context: AccountContext, message: EngineMessage) {
		self.context = context
		self.message = message
	}

	static func ==(lhs: StoryAuthorInfoComponent, rhs: StoryAuthorInfoComponent) -> Bool {
		if lhs.context !== rhs.context {
			return false
		}
		if lhs.message != rhs.message {
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

            let title = component.message.author?.debugDisplayTitle ?? ""
            let subtitle = humanReadableStringForTimestamp(strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, timestamp: component.message.timestamp).string
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(Text(text: title, font: Font.semibold(17.0), color: .white)),
                environment: {},
                containerSize: availableSize
            )
            let subtitleSize = self.subtitle.update(
                transition: .immediate,
                component: AnyComponent(Text(text: subtitle, font: Font.regular(12.0), color: UIColor(white: 1.0, alpha: 0.8))),
                environment: {},
                containerSize: availableSize
            )
            
            let contentHeight: CGFloat = titleSize.height + spacing + subtitleSize.height
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: floor((availableSize.height - contentHeight) * 0.5)), size: titleSize)
            let subtitleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - subtitleSize.width) * 0.5), y: titleFrame.maxY + spacing), size: subtitleSize)
            
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
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
