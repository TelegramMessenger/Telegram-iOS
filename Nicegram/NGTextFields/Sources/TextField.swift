import UIKit

extension String {
    /**
    true if self contains characters.
    */
    var isNotEmpty: Bool {
        return !isEmpty
    }
}

/**
A TextFieldEffects object is a control that displays editable text and contains the boilerplates to setup unique animations for text entry and display. You typically use this class the same way you use UITextField.
*/
open class TextField: UITextField {
    /**
     The type of animation a TextFieldEffect can perform.

     - TextEntry: animation that takes effect when the textfield has focus.
     - TextDisplay: animation that takes effect when the textfield loses focus.
     */
    public enum AnimationType: Int {
        case textEntry
        case textDisplay
    }

    /**
    Closure executed when an animation has been completed.
     */
    public typealias AnimationCompletionHandler = (_ type: AnimationType)->()

    /**
    UILabel that holds all the placeholder information
    */
    public let placeholderLabel = UILabel()

    public let errorLabel = UILabel()

    /**
    Creates all the animations that are used to leave the textfield in the "entering text" state.
    */
    open func animateViewsForTextEntry() {
        fatalError("\(#function) must be overridden")
    }

    /**
    Creates all the animations that are used to leave the textfield in the "display input text" state.
    */
    open func animateViewsForTextDisplay() {
        fatalError("\(#function) must be overridden")
    }

    /**
     The animation completion handler is the best place to be notified when the text field animation has ended.
     */
    open var animationCompletionHandler: AnimationCompletionHandler?

    /**
    Draws the receiver’s image within the passed-in rectangle.

    - parameter rect:    The portion of the view’s bounds that needs to be updated.
    */
    open func drawViewsForRect(_ rect: CGRect) {
        fatalError("\(#function) must be overridden")
    }

    open func updateViewsForBoundsChange(_ bounds: CGRect) {
        fatalError("\(#function) must be overridden")
    }

    // MARK: - Overrides

    override open func draw(_ rect: CGRect) {
        // FIXME: Short-circuit if the view is currently selected. iOS 11 introduced
        // a setNeedsDisplay when you focus on a textfield, calling this method again
        // and messing up some of the effects due to the logic contained inside these
        // methods.
        // This is just a "quick fix", something better needs to come along.
        guard isFirstResponder == false else { return }
        drawViewsForRect(rect)
    }

    override open func drawPlaceholder(in rect: CGRect) {
        // Don't draw any placeholders
    }

    override open var text: String? {
        didSet {
            if let text = text, text.isNotEmpty || isFirstResponder {
                animateViewsForTextEntry()
            } else {
                animateViewsForTextDisplay()
            }
        }
    }

    // MARK: - UITextField Observing

    override open func willMove(toSuperview newSuperview: UIView!) {
        if newSuperview != nil {
            NotificationCenter.default.addObserver(self, selector: #selector(textFieldDidEndEditing), name: UITextField.textDidEndEditingNotification, object: self)

            NotificationCenter.default.addObserver(self, selector: #selector(textFieldDidBeginEditing), name: UITextField.textDidBeginEditingNotification, object: self)
        } else {
            NotificationCenter.default.removeObserver(self)
        }
    }

    /**
    The textfield has started an editing session.
    */
    @objc open func textFieldDidBeginEditing() {
        animateViewsForTextEntry()
    }

    /**
    The textfield has ended an editing session.
    */
    @objc open func textFieldDidEndEditing() {
        animateViewsForTextDisplay()
    }

    // MARK: - Interface Builder

    override open func prepareForInterfaceBuilder() {
        drawViewsForRect(frame)
    }
}
