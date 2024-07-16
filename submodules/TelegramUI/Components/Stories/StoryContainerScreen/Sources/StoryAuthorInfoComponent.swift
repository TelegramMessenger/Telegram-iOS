import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import TelegramCore
import TelegramStringFormatting
import MultilineTextComponent
import TelegramPresentationData
import AvatarNode

final class StoryAuthorInfoComponent: Component {
    struct Counters: Equatable {
        var position: Int
        var totalCount: Int
    }
    
	let context: AccountContext
    let strings: PresentationStrings
	let peer: EnginePeer?
    let forwardInfo: EngineStoryItem.ForwardInfo?
    let author: EnginePeer?
    let timestamp: Int32
    let counters: Counters?
    let isEdited: Bool
    
    init(context: AccountContext, strings: PresentationStrings, peer: EnginePeer?, forwardInfo: EngineStoryItem.ForwardInfo?, author: EnginePeer?, timestamp: Int32, counters: Counters?, isEdited: Bool) {
        self.context = context
        self.strings = strings
        self.peer = peer
        self.forwardInfo = forwardInfo
        self.author = author
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
        if lhs.forwardInfo != rhs.forwardInfo {
            return false
        }
        if lhs.author != rhs.author {
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
        private var repostIconView: UIImageView?
        private var avatarNode: AvatarNode?
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
        
        func update(component: StoryAuthorInfoComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
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
            
            let titleColor = UIColor.white
            let subtitleColor = UIColor(white: 1.0, alpha: 0.8)
            let subtitle: NSAttributedString
            let subtitleTruncationType: CTLineTruncationType
            if let forwardInfo = component.forwardInfo {
                let authorName: String
                switch forwardInfo {
                case let .known(peer, _, _):
                    authorName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                case let .unknown(name, _):
                    authorName = name
                }
                let timeString = stringForStoryActivityTimestamp(strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, preciseTime: true, relativeTimestamp: component.timestamp, relativeTo: timestamp, short: true)
                let combinedString = NSMutableAttributedString()
                combinedString.append(NSAttributedString(string: authorName, font: Font.medium(11.0), textColor: titleColor))
                if timeString.count < 6 {
                    combinedString.append(NSAttributedString(string: " • \(timeString)", font: Font.regular(11.0), textColor: subtitleColor))
                }
                subtitle = combinedString
                subtitleTruncationType = .middle
            } else if let author = component.author {
                let authorName = author.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                let combinedString = NSMutableAttributedString()
                combinedString.append(NSAttributedString(string: authorName, font: Font.medium(11.0), textColor: titleColor))
                if component.timestamp != 0 {
                    let timeString = stringForStoryActivityTimestamp(strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, preciseTime: true, relativeTimestamp: component.timestamp, relativeTo: timestamp, short: true)
                    if timeString.count < 6 {
                        combinedString.append(NSAttributedString(string: " • \(timeString)", font: Font.regular(11.0), textColor: subtitleColor))
                    }
                }
                if component.isEdited {
                    combinedString.append(NSAttributedString(string: " • \(component.strings.Story_HeaderEdited)", font: Font.regular(11.0), textColor: subtitleColor))
                }
                subtitle = combinedString
                subtitleTruncationType = .middle
            } else if component.timestamp != 0 {
                var subtitleString = stringForStoryActivityTimestamp(strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, preciseTime: true, relativeTimestamp: component.timestamp, relativeTo: timestamp)
                if component.isEdited {
                    subtitleString.append(" • ")
                    subtitleString.append(component.strings.Story_HeaderEdited)
                }
                subtitle = NSAttributedString(string: subtitleString, font: Font.regular(11.0), textColor: subtitleColor)
                subtitleTruncationType = .end
            } else {
                var subtitleString = ""
                if component.isEdited {
                    subtitleString.append(component.strings.Story_HeaderEdited)
                }
                subtitle = NSAttributedString(string: subtitleString, font: Font.regular(11.0), textColor: subtitleColor)
                subtitleTruncationType = .end
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
                    text: .plain(subtitle),
                    truncationType: subtitleTruncationType,
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset, height: availableSize.height)
            )
            
            var contentHeight: CGFloat = titleSize.height
            if subtitle.length != 0 {
                contentHeight += spacing + subtitleSize.height
            }
            let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: 2.0 + floor((availableSize.height - contentHeight) * 0.5)), size: titleSize)
            
            var subtitleOffset: CGFloat = 0.0
            if let _ = component.forwardInfo {
                let iconView: UIImageView
                if let current = self.repostIconView {
                    iconView = current
                } else {
                    iconView = UIImageView(image: UIImage(bundleImageName: "Stories/HeaderRepost")?.withRenderingMode(.alwaysTemplate))
                    iconView.tintColor = .white
                    self.addSubview(iconView)
                    self.repostIconView = iconView
                }
                
                let iconSize = CGSize(width: 13.0, height: 13.0)
                let iconFrame = CGRect(origin: CGPoint(x: leftInset + subtitleOffset - 2.0 + UIScreenPixel, y: titleFrame.minY + contentHeight - iconSize.height + 1.0), size: iconSize)
                transition.setFrame(view: iconView, frame: iconFrame)
                
                subtitleOffset += iconSize.width + 1.0
            } else if let repostIconView = self.repostIconView {
                self.repostIconView = nil
                repostIconView.removeFromSuperview()
            }
            
            
            var authorPeer: EnginePeer?
            if let forwardInfo = component.forwardInfo, case let .known(peer, _, _) = forwardInfo {
                authorPeer = peer
            } else if let author = component.author {
                authorPeer = author
            }
            
            if let peer = authorPeer {
                let avatarNode: AvatarNode
                if let current = self.avatarNode {
                    avatarNode = current
                } else {
                    avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 8.0))
                    self.addSubview(avatarNode.view)
                    self.avatarNode = avatarNode
                }
                
                let avatarSize = CGSize(width: 16.0, height: 16.0)
                let theme = component.context.sharedContext.currentPresentationData.with { $0 }.theme
                avatarNode.setPeer(context: component.context, theme: theme, peer: peer, synchronousLoad: true, displayDimensions: avatarSize)
                
                let avatarFrame = CGRect(origin: CGPoint(x: leftInset + subtitleOffset, y: titleFrame.minY + contentHeight - avatarSize.height + 3.0 - UIScreenPixel), size: avatarSize)
                avatarNode.frame = avatarFrame
                
                subtitleOffset += avatarSize.width + 4.0
            } else if let avatarNode = self.avatarNode {
                self.avatarNode = nil
                avatarNode.view.removeFromSuperview()
            }
            
            let subtitleFrame = CGRect(origin: CGPoint(x: leftInset + subtitleOffset, y: titleFrame.maxY + spacing + UIScreenPixel), size: subtitleSize)
            
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

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
