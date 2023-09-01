import Foundation
import UIKit
import Display
import ComponentFlow
import AccountContext
import TelegramPresentationData
import AsyncDisplayKit
import TelegramCore
import ComponentDisplayAdapters

public final class TokenListTextField: Component {
    public final class ExternalState {
        public fileprivate(set) var isFocused: Bool = false
        public fileprivate(set) var text: String = ""
        
        public init() {
        }
    }
    
    public final class Token: Equatable {
        public enum Content: Equatable {
            case peer(EnginePeer)
            case category(UIImage?)
            
            public static func ==(lhs: Content, rhs: Content) -> Bool {
                switch lhs {
                case let .peer(peer):
                    if case .peer(peer) = rhs {
                        return true
                    } else {
                        return false
                    }
                case let .category(lhsImage):
                    if case let .category(rhsImage) = rhs, lhsImage === rhsImage {
                        return true
                    } else {
                        return false
                    }
                }
            }
        }
        
        public let id: AnyHashable
        public let title: String
        public let fixedPosition: Int?
        public let content: Content
        
        public init(
            id: AnyHashable,
            title: String,
            fixedPosition: Int?,
            content: Content
        ) {
            self.id = id
            self.title = title
            self.fixedPosition = fixedPosition
            self.content = content
        }
        
        public static func ==(lhs: Token, rhs: Token) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.title != rhs.title {
                return false
            }
            if lhs.fixedPosition != rhs.fixedPosition {
                return false
            }
            if lhs.content != rhs.content {
                return false
            }
            return true
        }
    }
    
    public let externalState: ExternalState
    public let context: AccountContext
    public let theme: PresentationTheme
    public let placeholder: String
    public let tokens: [Token]
    public let sideInset: CGFloat
    public let deleteToken: (AnyHashable) -> Void
    
    public init(
        externalState: ExternalState,
        context: AccountContext,
        theme: PresentationTheme,
        placeholder: String,
        tokens: [Token],
        sideInset: CGFloat,
        deleteToken: @escaping (AnyHashable) -> Void
    ) {
        self.externalState = externalState
        self.context = context
        self.theme = theme
        self.placeholder = placeholder
        self.tokens = tokens
        self.sideInset = sideInset
        self.deleteToken = deleteToken
    }

    public static func ==(lhs: TokenListTextField, rhs: TokenListTextField) -> Bool {
        if lhs.externalState !== rhs.externalState {
            return false
        }
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.placeholder != rhs.placeholder {
            return false
        }
        if lhs.tokens != rhs.tokens {
            return false
        }
        if lhs.sideInset != rhs.sideInset {
            return false
        }
        return true
    }

    public final class View: UIView {
        private var tokenListNode: EditableTokenListNode?
        
        private var tokenListText: String = ""
        
        private var component: TokenListTextField?
        private weak var componentState: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init(coder: NSCoder) {
            preconditionFailure()
        }
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)
            if result != nil {
                return result
            }
            
            return nil
        }
        
        public func clearText() {
            if let tokenListNode = self.tokenListNode {
                tokenListNode.setText("")
            }
        }

        func update(component: TokenListTextField, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.componentState = state
            
            let tokenListNode: EditableTokenListNode
            if let current = self.tokenListNode {
                tokenListNode = current
            } else {
                tokenListNode = EditableTokenListNode(
                    context: component.context,
                    presentationTheme: component.theme,
                    theme: EditableTokenListNodeTheme(
                        backgroundColor: .clear,
                        separatorColor: component.theme.rootController.navigationBar.separatorColor,
                        placeholderTextColor: component.theme.list.itemPlaceholderTextColor,
                        primaryTextColor: component.theme.list.itemPrimaryTextColor,
                        tokenBackgroundColor: component.theme.list.itemCheckColors.strokeColor.withAlphaComponent(0.25),
                        selectedTextColor: component.theme.list.itemCheckColors.foregroundColor,
                        selectedBackgroundColor: component.theme.list.itemCheckColors.fillColor,
                        accentColor: component.theme.list.itemAccentColor,
                        keyboardColor: component.theme.rootController.keyboardColor
                    ),
                    placeholder: component.placeholder
                )
                self.tokenListNode = tokenListNode
                self.addSubnode(tokenListNode)
                
                tokenListNode.isFirstResponderChanged = { [weak self] in
                    guard let self else {
                        return
                    }
                    self.componentState?.updated(transition: Transition(animation: .curve(duration: 0.35, curve: .spring)))
                }
                
                tokenListNode.textUpdated = { [weak self] text in
                    guard let self else {
                        return
                    }
                    self.tokenListText = text
                    self.componentState?.updated(transition: .immediate)
                }
                
                tokenListNode.textReturned = { [weak self] in
                    guard let self else {
                        return
                    }
                    self.tokenListNode?.view.endEditing(true)
                }
                
                tokenListNode.deleteToken = { [weak self] id in
                    guard let self, let component = self.component else {
                        return
                    }
                    component.deleteToken(id)
                }
            }
            
            let mappedTokens = component.tokens.map { token -> EditableTokenListToken in
                let mappedSubject: EditableTokenListToken.Subject
                switch token.content {
                case let .peer(peer):
                    mappedSubject = .peer(peer)
                case let .category(image):
                    mappedSubject = .category(image)
                }
                
                return EditableTokenListToken(
                    id: token.id,
                    title: token.title,
                    fixedPosition: token.fixedPosition,
                    subject: mappedSubject
                )
            }
            
            let height = tokenListNode.updateLayout(
                tokens: mappedTokens,
                width: availableSize.width,
                leftInset: component.sideInset,
                rightInset: component.sideInset,
                transition: transition.containedViewLayoutTransition
            )
            let size = CGSize(width: availableSize.width, height: height)
            transition.containedViewLayoutTransition.updateFrame(node: tokenListNode, frame: CGRect(origin: CGPoint(), size: size))
            
            component.externalState.isFocused = tokenListNode.isFocused
            component.externalState.text = self.tokenListText
            
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
