import Foundation
import UIKit
import Display
import ComponentFlow

public final class TextFieldComponent: Component {
    public final class ExternalState {
        public fileprivate(set) var isEditing: Bool = false
        public fileprivate(set) var hasText: Bool = false
        
        public init() {
        }
    }
    
    public final class AnimationHint {
        public enum Kind {
            case textChanged
            case textFocusChanged
        }
        
        public let kind: Kind
        
        fileprivate init(kind: Kind) {
            self.kind = kind
        }
    }
    
    public let externalState: ExternalState
    public let placeholder: String
    public let placeholderAlignment: NSTextAlignment
    
    public init(
        externalState: ExternalState,
        placeholder: String,
        placeholderAlignment: NSTextAlignment
    ) {
        self.externalState = externalState
        self.placeholder = placeholder
        self.placeholderAlignment = placeholderAlignment
    }
    
    public static func ==(lhs: TextFieldComponent, rhs: TextFieldComponent) -> Bool {
        if lhs.externalState !== rhs.externalState {
            return false
        }
        if lhs.placeholder != rhs.placeholder {
            return false
        }
        if lhs.placeholderAlignment != rhs.placeholderAlignment {
            return false
        }
        return true
    }
    
    public final class View: UIView, UITextViewDelegate, UIScrollViewDelegate {
        private let placeholder = ComponentView<Empty>()
        
        private let textContainer: NSTextContainer
        private let textStorage: NSTextStorage
        private let layoutManager: NSLayoutManager
        private let textView: UITextView
        
        private var component: TextFieldComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.textContainer = NSTextContainer(size: CGSize())
            self.textContainer.widthTracksTextView = false
            self.textContainer.heightTracksTextView = false
            self.textContainer.lineBreakMode = .byWordWrapping
            self.textContainer.lineFragmentPadding = 8.0
            
            self.textStorage = NSTextStorage()

            self.layoutManager = NSLayoutManager()
            self.layoutManager.allowsNonContiguousLayout = false
            self.layoutManager.addTextContainer(self.textContainer)
            self.textStorage.addLayoutManager(self.layoutManager)
            
            self.textView = UITextView(frame: CGRect(), textContainer: self.textContainer)
            self.textView.translatesAutoresizingMaskIntoConstraints = false
            self.textView.textContainerInset = UIEdgeInsets(top: 6.0, left: 8.0, bottom: 7.0, right: 8.0)
            self.textView.backgroundColor = nil
            self.textView.layer.isOpaque = false
            self.textView.keyboardAppearance = .dark
            self.textView.indicatorStyle = .white
            self.textView.scrollIndicatorInsets = UIEdgeInsets(top: 9.0, left: 0.0, bottom: 9.0, right: 0.0)
            
            super.init(frame: frame)
            
            self.clipsToBounds = true
            
            self.textView.delegate = self
            self.addSubview(self.textView)
            
            self.textContainer.widthTracksTextView = false
            self.textContainer.heightTracksTextView = false
            
            self.textView.typingAttributes = [
                NSAttributedString.Key.font: Font.regular(17.0),
                NSAttributedString.Key.foregroundColor: UIColor.white
            ]
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func textViewDidChange(_ textView: UITextView) {
            self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)).withUserData(AnimationHint(kind: .textChanged)))
        }
        
        public func textViewDidBeginEditing(_ textView: UITextView) {
            self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)).withUserData(AnimationHint(kind: .textFocusChanged)))
        }
        
        public func textViewDidEndEditing(_ textView: UITextView) {
            self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)).withUserData(AnimationHint(kind: .textFocusChanged)))
        }
        
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            //print("didScroll \(scrollView.bounds)")
        }
        
        public func getText() -> String {
            Keyboard.applyAutocorrection(textView: self.textView)
            return self.textView.text ?? ""
        }
        
        public func setText(string: String) {
            self.textView.text = string
            self.state?.updated(transition: Transition(animation: .curve(duration: 0.4, curve: .spring)).withUserData(AnimationHint(kind: .textChanged)))
        }
        
        func update(component: TextFieldComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
            
            self.textContainer.size = CGSize(width: availableSize.width - self.textView.textContainerInset.left - self.textView.textContainerInset.right, height: 10000000.0)
            self.layoutManager.ensureLayout(for: self.textContainer)
            
            let boundingRect = self.layoutManager.boundingRect(forGlyphRange: NSRange(location: 0, length: self.textStorage.length), in: self.textContainer)
            let size = CGSize(width: availableSize.width, height: min(100.0, ceil(boundingRect.height) + self.textView.textContainerInset.top + self.textView.textContainerInset.bottom))
            
            let refreshScrolling = self.textView.bounds.size != size
            self.textView.frame = CGRect(origin: CGPoint(), size: size)
            
            if refreshScrolling {
                self.textView.setContentOffset(CGPoint(x: 0.0, y: max(0.0, self.textView.contentSize.height - self.textView.bounds.height)), animated: false)
            }
            
            let placeholderSize = self.placeholder.update(
                transition: .immediate,
                component: AnyComponent(Text(text: component.placeholder, font: Font.regular(17.0), color: UIColor(white: 1.0, alpha: 0.4))),
                environment: {},
                containerSize: availableSize
            )
            if let placeholderView = self.placeholder.view {
                if placeholderView.superview == nil {
                    placeholderView.layer.anchorPoint = CGPoint()
                    placeholderView.isUserInteractionEnabled = false
                    self.insertSubview(placeholderView, belowSubview: self.textView)
                }
                
                var placeholderAlignment = component.placeholderAlignment
                if self.textView.isFirstResponder {
                    placeholderAlignment = .natural
                }
                let placeholderOriginX: CGFloat
                switch placeholderAlignment {
                case .left, .natural:
                    placeholderOriginX = self.textView.textContainerInset.left + 5.0
                case .center, .justified:
                    placeholderOriginX = floor((size.width - placeholderSize.width) / 2.0)
                case .right:
                    placeholderOriginX = availableSize.width - self.textView.textContainerInset.left - 5.0 - placeholderSize.width
                @unknown default:
                    placeholderOriginX = self.textView.textContainerInset.left + 5.0
                }
                let placeholderFrame = CGRect(origin: CGPoint(x: placeholderOriginX, y: self.textView.textContainerInset.top), size: placeholderSize)
                placeholderView.bounds = CGRect(origin: CGPoint(), size: placeholderFrame.size)
                transition.setPosition(view: placeholderView, position: placeholderFrame.origin)
                
                placeholderView.isHidden = self.textStorage.length != 0
            }
            
            component.externalState.hasText = self.textStorage.length != 0
            component.externalState.isEditing = self.textView.isFirstResponder
            
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
