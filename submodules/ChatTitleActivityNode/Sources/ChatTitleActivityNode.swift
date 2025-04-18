import Foundation
import UIKit
import AsyncDisplayKit
import Display

public enum ChatTitleActivityAnimationStyle {
    case none
    case crossfade
    case slide
}

public enum ChatTitleActivityInfoType {
    case online
    case lastSeenTime
    case generic
}

public enum ChatTitleActivityNodeState: Equatable {
    case none
    case info(NSAttributedString, ChatTitleActivityInfoType)
    case typingText(NSAttributedString, UIColor)
    case uploading(NSAttributedString, UIColor)
    case recordingVoice(NSAttributedString, UIColor)
    case recordingVideo(NSAttributedString, UIColor)
    case playingGame(NSAttributedString, UIColor)
    case choosingSticker(NSAttributedString, UIColor)
    case interactingWithEmoji(NSAttributedString, UIColor)
    
    func contentNode() -> ChatTitleActivityContentNode? {
        switch self {
            case .none:
                return nil
            case let .info(text, _):
                return ChatTitleActivityContentNode(text: text)
            case let .typingText(text, color):
                return ChatTypingActivityContentNode(text: text, color: color)
            case let .uploading(text, color):
                return ChatUploadingActivityContentNode(text: text, color: color)
            case let .recordingVoice(text, color):
                return ChatRecordingVoiceActivityContentNode(text: text, color: color)
            case let .recordingVideo(text, color):
                return ChatRecordingVideoActivityContentNode(text: text, color: color)
            case let .playingGame(text, color):
                return ChatPlayingActivityContentNode(text: text, color: color)
            case let .choosingSticker(text, color):
                return ChatChoosingStickerActivityContentNode(text: text, color: color)
            case let .interactingWithEmoji(text, _):
                return ChatTitleActivityContentNode(text: text)
        }
    }
    
    public var string: String? {
        if case let .info(text, _) = self {
            return text.string
        }
        return nil
    }
}

public class ChatTitleActivityNode: ASDisplayNode {
    public private(set) var state: ChatTitleActivityNodeState = .none
    
    private var contentNode: ChatTitleActivityContentNode?
    private var nextContentNode: ChatTitleActivityContentNode?
    
    override public init() {
        super.init()
    }
    
    public func makeCopy() -> ASDisplayNode {
        let node = ASDisplayNode()
        if let contentNode = self.contentNode {
            node.addSubnode(contentNode.makeCopy())
        }
        node.frame = self.frame
        return node
    }
    
    public func transitionToState(_ state: ChatTitleActivityNodeState, animation: ChatTitleActivityAnimationStyle = .crossfade, completion: @escaping () -> Void = {}) -> Bool {
        if self.state != state {
            let currentState = self.state
            self.state = state
            
            let contentNode = state.contentNode()
            if contentNode !== self.contentNode {
                self.transitionToContentNode(contentNode, state: state, fromState: currentState, animation: animation, completion: completion)
            }
            
            return true
        } else {
            completion()
            return false
        }
    }
    
    private func transitionToContentNode(_ node: ChatTitleActivityContentNode?, state: ChatTitleActivityNodeState, fromState: ChatTitleActivityNodeState, animation: ChatTitleActivityAnimationStyle = .crossfade, completion: @escaping () -> Void) {
        if let previousContentNode = self.contentNode {
            if case .none = animation {
                previousContentNode.removeFromSupernode()
                self.contentNode = node
                if let contentNode = self.contentNode {
                    self.addSubnode(contentNode)
                }
            } else {
                var animation = animation
                if case let .info(_, fromType) = fromState, case let .info(_, toType) = state, fromType == toType {
                    animation = .none
                }
                if case .typingText = fromState, case .typingText = state {
                    animation = .none
                }
                    
                self.contentNode = node
                if let contentNode = self.contentNode {
                    self.addSubnode(contentNode)
                    if self.isNodeLoaded {
                        contentNode.animateIn(from: fromState, style: animation)
                    }
                }
                previousContentNode.animateOut(to: state, style: animation) {
                    previousContentNode.removeFromSupernode()
                }
            }
        } else {
            self.contentNode = node
            if let contentNode = self.contentNode {
                self.addSubnode(contentNode)
            }
        }
    }
    
    public func updateLayout(_ constrainedSize: CGSize, offset: CGFloat = 0.0, alignment: NSTextAlignment) -> CGSize {
        return CGSize(width: 0.0, height: self.contentNode?.updateLayout(constrainedSize, offset: offset, alignment: alignment).height ?? 0.0)
    }
}
