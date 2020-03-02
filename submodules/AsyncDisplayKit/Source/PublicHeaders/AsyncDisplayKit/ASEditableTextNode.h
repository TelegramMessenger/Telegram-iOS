//
//  ASEditableTextNode.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASDisplayNode.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ASEditableTextNodeDelegate;
@class ASTextKitComponents;

@interface ASEditableTextNodeTargetForAction: NSObject

@property (nonatomic, strong, readonly) id _Nullable target;

- (instancetype)initWithTarget:(id _Nullable)target;

@end

/**
 @abstract Implements a node that supports text editing.
 @discussion Does not support layer backing.
 */
@interface ASEditableTextNode : ASDisplayNode <UITextInputTraits>

/**
 * @abstract Initializes an editable text node using default TextKit components.
 *
 * @return An initialized ASEditableTextNode.
 */
- (instancetype)init;

/**
 * @abstract Initializes an editable text node using the provided TextKit components.
 *
 * @param textKitComponents The TextKit stack used to render text.
 * @param placeholderTextKitComponents The TextKit stack used to render placeholder text.
 *
 * @return An initialized ASEditableTextNode.
 */
- (instancetype)initWithTextKitComponents:(ASTextKitComponents *)textKitComponents
             placeholderTextKitComponents:(ASTextKitComponents *)placeholderTextKitComponents;

//! @abstract The text node's delegate, which must conform to the <ASEditableTextNodeDelegate> protocol.
@property (nullable, weak) id <ASEditableTextNodeDelegate> delegate;

#pragma mark - Configuration

/**
 @abstract Enable scrolling on the textView
 @default true
 */
@property (nonatomic) BOOL scrollEnabled;
@property (nonatomic, strong) UIFont *baseFont;

/**
  @abstract Access to underlying UITextView for more configuration options.
  @warning This property should only be used on the main thread and should not be accessed before the editable text node's view is created.
 */
@property (nonatomic, readonly) UITextView *textView;

//! @abstract The attributes to apply to new text being entered by the user.
@property (nullable, nonatomic, copy) NSDictionary<NSString *, id> *typingAttributes;

//! @abstract The range of text currently selected. If length is zero, the range is the cursor location.
@property NSRange selectedRange;

@property (readonly) CGRect selectionRect;

#pragma mark - Placeholder
/**
  @abstract Indicates if the receiver is displaying the placeholder text.
  @discussion To update the placeholder, see the <attributedPlaceholderText> property.
  @result YES if the placeholder is currently displayed; NO otherwise.
 */
- (BOOL)isDisplayingPlaceholder AS_WARN_UNUSED_RESULT;

/**
  @abstract The styled placeholder text displayed by the text node while no text is entered
  @discussion The placeholder is displayed when the user has not entered any text and the keyboard is not visible.
 */
@property (nullable, nonatomic, copy) NSAttributedString *attributedPlaceholderText;

#pragma mark - Modifying User Text
/**
  @abstract The styled text displayed by the receiver.
  @discussion When the placeholder is displayed (as indicated by -isDisplayingPlaceholder), this value is nil. Otherwise, this value is the attributed text the user has entered. This value can be modified regardless of whether the receiver is the first responder (and thus, editing) or not. Changing this value from nil to non-nil will result in the placeholder being hidden, and the new value being displayed.
 */
@property (nullable, nonatomic, copy) NSAttributedString *attributedText;

#pragma mark - Managing The Keyboard
//! @abstract The text input mode used by the receiver's keyboard, if it is visible. This value is undefined if the receiver is not the first responder.
@property (nonatomic, readonly) UITextInputMode *textInputMode;

/**
 @abstract The textContainerInset of both the placeholder and typed textView. This value defaults to UIEdgeInsetsZero.
 */
@property (nonatomic) UIEdgeInsets textContainerInset;

/**
 @abstract The maximum number of lines to display. Additional lines will require scrolling.
 @default 0 (No limit)
 */
@property (nonatomic) NSUInteger maximumLinesToDisplay;

/**
  @abstract Indicates whether the receiver's text view is the first responder, and thus has the keyboard visible and is prepared for editing by the user.
  @result YES if the receiver's text view is the first-responder; NO otherwise.
 */
- (BOOL)isFirstResponder AS_WARN_UNUSED_RESULT;

//! @abstract Makes the receiver's text view the first responder.
- (BOOL)becomeFirstResponder;

//! @abstract Resigns the receiver's text view from first-responder status, if it has it.
- (BOOL)resignFirstResponder;

#pragma mark - Geometry
/**
  @abstract Returns the frame of the given range of characters.
  @param textRange A range of characters.
  @discussion This method raises an exception if `textRange` is not a valid range of characters within the receiver's attributed text.
  @result A CGRect that is the bounding box of the glyphs covered by the given range of characters, in the coordinate system of the receiver.
 */
- (CGRect)frameForTextRange:(NSRange)textRange AS_WARN_UNUSED_RESULT;

/**
 @abstract <UITextInputTraits> properties.
 */
@property (nonatomic) UITextAutocapitalizationType autocapitalizationType; // default is UITextAutocapitalizationTypeSentences
@property (nonatomic) UITextAutocorrectionType autocorrectionType;         // default is UITextAutocorrectionTypeDefault
@property (nonatomic) UITextSpellCheckingType spellCheckingType;           // default is UITextSpellCheckingTypeDefault;
@property (nonatomic) UIKeyboardType keyboardType;                         // default is UIKeyboardTypeDefault
@property (nonatomic) UIKeyboardAppearance keyboardAppearance;             // default is UIKeyboardAppearanceDefault
@property (nonatomic) UIReturnKeyType returnKeyType;                       // default is UIReturnKeyDefault (See note under UIReturnKeyType enum)
@property (nonatomic) BOOL enablesReturnKeyAutomatically;                  // default is NO (when YES, will automatically disable return key when text widget has zero-length contents, and will automatically enable when text widget has non-zero-length contents)
@property (nonatomic, getter=isSecureTextEntry) BOOL secureTextEntry;      // default is NO

@property (nonatomic, strong) NSString * _Nullable initialPrimaryLanguage;

- (void)resetInitialPrimaryLanguage;
- (void)dropAutocorrection;
- (bool)isCurrentlyEmoji;

@end

@interface ASEditableTextNode (Unavailable)

- (instancetype)initWithLayerBlock:(ASDisplayNodeLayerBlock)viewBlock didLoadBlock:(nullable ASDisplayNodeDidLoadBlock)didLoadBlock NS_UNAVAILABLE;

- (instancetype)initWithViewBlock:(ASDisplayNodeViewBlock)viewBlock didLoadBlock:(nullable ASDisplayNodeDidLoadBlock)didLoadBlock NS_UNAVAILABLE;

@end

#pragma mark -
/**
 * The methods declared by the ASEditableTextNodeDelegate protocol allow the adopting delegate to 
 * respond to notifications such as began and finished editing, selection changed and text updated;
 * and manage whether a specified text should be replaced.
 */
@protocol ASEditableTextNodeDelegate <NSObject>

@optional
/**
 @abstract Asks the delegate if editing should begin for the text node.
 @param editableTextNode An editable text node.
 @discussion YES if editing should begin; NO if editing should not begin -- the default returns YES.
 */
- (BOOL)editableTextNodeShouldBeginEditing:(ASEditableTextNode *)editableTextNode;

/**
  @abstract Indicates to the delegate that the text node began editing.
  @param editableTextNode An editable text node.
  @discussion The invocation of this method coincides with the keyboard animating to become visible.
 */
- (void)editableTextNodeDidBeginEditing:(ASEditableTextNode *)editableTextNode;

/**
  @abstract Asks the delegate whether the specified text should be replaced in the editable text node.
  @param editableTextNode An editable text node.
  @param range The current selection range. If the length of the range is 0, range reflects the current insertion point. If the user presses the Delete key, the length of the range is 1 and an empty string object replaces that single character.
  @param text The text to insert.
  @discussion YES if the old text should be replaced by the new text; NO if the replacement operation should be aborted.
  @result The text node calls this method whenever the user types a new character or deletes an existing character. Implementation of this method is optional -- the default implementation returns YES.
 */
- (BOOL)editableTextNode:(ASEditableTextNode *)editableTextNode shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text;

/**
  @abstract Indicates to the delegate that the text node's selection has changed.
  @param editableTextNode An editable text node.
  @param fromSelectedRange The previously selected range.
  @param toSelectedRange The current selected range. Equivalent to the <selectedRange> property.
  @param dueToEditing YES if the selection change was due to editing; NO otherwise.
  @discussion You can access the selection of the receiver via <selectedRange>.
 */
- (void)editableTextNodeDidChangeSelection:(ASEditableTextNode *)editableTextNode fromSelectedRange:(NSRange)fromSelectedRange toSelectedRange:(NSRange)toSelectedRange dueToEditing:(BOOL)dueToEditing;

/**
  @abstract Indicates to the delegate that the text node's text was updated.
  @param editableTextNode An editable text node.
  @discussion This method is called each time the user updated the text node's text. It is not called for programmatic changes made to the text via the <attributedText> property.
 */
- (void)editableTextNodeDidUpdateText:(ASEditableTextNode *)editableTextNode;

/**
  @abstract Indicates to the delegate that the text node has finished editing.
  @param editableTextNode An editable text node.
  @discussion The invocation of this method coincides with the keyboard animating to become hidden.
 */
- (void)editableTextNodeDidFinishEditing:(ASEditableTextNode *)editableTextNode;

- (BOOL)editableTextNodeShouldCopy:(ASEditableTextNode *)editableTextNode;
- (BOOL)editableTextNodeShouldPaste:(ASEditableTextNode *)editableTextNode;
- (ASEditableTextNodeTargetForAction * _Nullable)editableTextNodeTargetForAction:(SEL)action;
- (BOOL)editableTextNodeShouldReturn:(ASEditableTextNode *)editableTextNode;
- (void)editableTextNodeBackspaceWhileEmpty:(ASEditableTextNode *)editableTextNode;

@end

NS_ASSUME_NONNULL_END
