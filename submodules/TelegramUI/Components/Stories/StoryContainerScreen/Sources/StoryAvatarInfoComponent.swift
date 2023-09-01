import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import TelegramCore
import AsyncDisplayKit
import AvatarNode

final class StoryAvatarInfoComponent: Component {
	let context: AccountContext
	let peer: EnginePeer

	init(context: AccountContext, peer: EnginePeer) {
		self.context = context
		self.peer = peer
	}

	static func ==(lhs: StoryAvatarInfoComponent, rhs: StoryAvatarInfoComponent) -> Bool {
		if lhs.context !== rhs.context {
			return false
		}
		if lhs.peer != rhs.peer {
			return false
		}
		return true
	}

	final class View: UIView {
        private let avatarNode: AvatarNode
        
        private var component: StoryAvatarInfoComponent?
        private weak var state: EmptyComponentState?
        
		override init(frame: CGRect) {
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 18.0))
            
			super.init(frame: frame)
            
            self.addSubnode(self.avatarNode)
		}
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: StoryAvatarInfoComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            let size = CGSize(width: 32.0, height: 32.0)

            self.avatarNode.frame = CGRect(origin: CGPoint(), size: size)
            self.avatarNode.setPeer(
                context: component.context,
                theme: component.context.sharedContext.currentPresentationData.with({ $0 }).theme,
                peer: component.peer,
                synchronousLoad: true
            )
            
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
