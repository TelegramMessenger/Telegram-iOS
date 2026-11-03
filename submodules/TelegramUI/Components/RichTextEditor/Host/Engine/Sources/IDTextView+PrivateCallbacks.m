#import "IDTextView.h"
#import "IDTextViewInternal.h"

@implementation IDTextView (PrivateCallbacks)

- (NSTextLayoutManager *)textLayoutManager {
    return self.id_textLayoutManager;
}

- (NSTextContainer *)textContainer {
    return self.id_textContainer;
}

- (void)setTextContainer:(NSTextContainer *)textContainer {
    if (textContainer != self.id_textContainer) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:@"The private TextKit 2 container host cannot be replaced"
                                     userInfo:nil];
    }
}

- (void)invalidateTextContainerOrigin {
    [self setNeedsLayout];
}

- (CGPoint)textContainerOrigin {
    return CGPointMake(self.textContainerInset.left, self.textContainerInset.top);
}

- (CGRect)_clipRectForFadedEdges {
    return CGRectNull;
}

- (NSTextStorage *)textStorage {
    return self.id_textContentStorage.textStorage;
}

- (NSRange)_nsRangeForTextKitRanges:(NSArray<NSTextRange *> *)ranges {
    return [self id_NSRangeForTextKitRanges:ranges];
}

- (UIView *)textInputView {
    return self.id_canvasView;
}

- (id)textLayoutController {
    return self.id_layoutController;
}

- (id)_internalTextLayoutController {
    return self.id_layoutController;
}

- (id)_inputController {
    return self.id_inputController;
}

- (NSArray<Class> *)_implicitPasteConfigurationClasses {
    return self.isEditable ? @[NSString.class] : @[];
}

@end
