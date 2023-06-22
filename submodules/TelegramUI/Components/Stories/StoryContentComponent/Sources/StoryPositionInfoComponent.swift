import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import TelegramCore
import TelegramStringFormatting

final class StoryPositionInfoComponent: Component {
    let context: AccountContext
    let position: Int
    let totalCount: Int
    
    init(context: AccountContext, position: Int, totalCount: Int) {
        self.context = context
        self.position = position
        self.totalCount = totalCount
    }

    static func ==(lhs: StoryPositionInfoComponent, rhs: StoryPositionInfoComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.position != rhs.position {
            return false
        }
        if lhs.totalCount != rhs.totalCount {
            return false
        }
        return true
    }

    final class View: UIView {
        private let title = ComponentView<Empty>()

        private var component: StoryPositionInfoComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.isUserInteractionEnabled = false
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: StoryPositionInfoComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            let size = availableSize

            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })

            let position = max(0, min(component.position + 1, component.totalCount))
            let title = presentationData.strings.Items_NOfM("\(position)", "\(component.totalCount)").string
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(Text(text: title, font: Font.with(size: 17.0, weight: .semibold, traits: .monospacedNumbers), color: .white)),
                environment: {},
                containerSize: availableSize
            )
 
            let contentHeight: CGFloat = titleSize.height
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: floor((availableSize.height - contentHeight) * 0.5)), size: titleSize)
            
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
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
