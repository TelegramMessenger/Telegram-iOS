import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import TelegramCore
import TelegramStringFormatting
import MultilineTextComponent
import TelegramPresentationData

final class StoryAuthorInfoComponent: Component {
    struct Counters: Equatable {
        var position: Int
        var totalCount: Int
    }
    
	let context: AccountContext
    let strings: PresentationStrings
	let peer: EnginePeer?
    let timestamp: Int32
    let counters: Counters?
    let isEdited: Bool
    
    init(context: AccountContext, strings: PresentationStrings, peer: EnginePeer?, timestamp: Int32, counters: Counters?, isEdited: Bool) {
        self.context = context
        self.strings = strings
        self.peer = peer
        self.timestamp = timestamp
        self.counters = counters
        self.isEdited = isEdited
    }

	static func ==(lhs: StoryAuthorInfoComponent, rhs: StoryAuthorInfoComponent) -> Bool {
		if lhs.context !== rhs.context {
			return false
		}
        if lhs.strings !== rhs.strings {
            return false
        }
		if lhs.peer != rhs.peer {
			return false
		}
        if lhs.timestamp != rhs.timestamp {
            return false
        }
        if lhs.counters != rhs.counters {
            return false
        }
        if lhs.isEdited != rhs.isEdited {
            return false
        }
		return true
	}

	final class View: UIView {
		private let title = ComponentView<Empty>()
		private let subtitle = ComponentView<Empty>()
        private var counterLabel: ComponentView<Empty>?

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
            let leftInset: CGFloat = 54.0
            
            let presentationData = component.context.sharedContext.currentPresentationData.with({ $0 })

            let title: String
            if component.peer?.id == component.context.account.peerId {
                title = component.strings.Story_HeaderYourStory
            } else {
                if let _ = component.counters {
                    title = component.peer?.compactDisplayTitle ?? ""
                } else {
                    title = component.peer?.debugDisplayTitle ?? ""
                }
            }
            
            let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
            var subtitle = stringForStoryActivityTimestamp(strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, preciseTime: true, relativeTimestamp: component.timestamp, relativeTo: timestamp)
            
            if component.isEdited {
                subtitle.append(" • ")
                subtitle.append(component.strings.Story_HeaderEdited)
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: title, font: Font.medium(14.0), textColor: .white)),
                    truncationType: .end,
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset, height: availableSize.height)
            )
            let subtitleSize = self.subtitle.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: subtitle, font: Font.regular(11.0), textColor: UIColor(white: 1.0, alpha: 0.8))),
                    truncationType: .end,
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset, height: availableSize.height)
            )
            
            let contentHeight: CGFloat = titleSize.height + spacing + subtitleSize.height
            let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: 2.0 + floor((availableSize.height - contentHeight) * 0.5)), size: titleSize)
            let subtitleFrame = CGRect(origin: CGPoint(x: leftInset, y: titleFrame.maxY + spacing + UIScreenPixel), size: subtitleSize)
            
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
            
            let countersSpacing: CGFloat = 5.0
            if let counters = component.counters {
                let counterLabel: ComponentView<Empty>
                if let current = self.counterLabel {
                    counterLabel = current
                } else {
                    counterLabel = ComponentView()
                    self.counterLabel = counterLabel
                }
                let counterSize = counterLabel.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: "\(counters.position + 1)/\(counters.totalCount)", font: Font.regular(11.0), textColor: UIColor(white: 1.0, alpha: 0.43))),
                        truncationType: .end,
                        maximumNumberOfLines: 1
                    )),
                    environment: {},
                    containerSize: CGSize(width: max(1.0, availableSize.width - titleSize.width - countersSpacing), height: 100.0)
                )
                if let counterLabelView = counterLabel.view {
                    if counterLabelView.superview == nil {
                        self.addSubview(counterLabelView)
                    }
                    counterLabelView.frame = CGRect(origin: CGPoint(x: titleFrame.maxX + countersSpacing, y: titleFrame.minY + 1.0 + floorToScreenPixels((titleFrame.height - counterSize.height) * 0.5)), size: counterSize)
                }
            } else if let counterLabel = self.counterLabel {
                self.counterLabel = nil
                counterLabel.view?.removeFromSuperview()
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
