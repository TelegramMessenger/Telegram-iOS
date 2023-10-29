#ifndef ChatInputTextViewImpl_h
#define ChatInputTextViewImpl_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ChatInputTextViewImplTargetForAction: NSObject

@property (nonatomic, strong, readonly) id _Nullable target;

- (instancetype _Nonnull)initWithTarget:(id _Nullable)target;

@end

@interface ChatInputTextViewImpl : UITextView

@property (nonatomic, copy) bool (^ _Nullable shouldCopy)();
@property (nonatomic, copy) bool (^ _Nullable shouldPaste)();
@property (nonatomic, copy) bool (^ _Nullable shouldRespondToAction)(SEL _Nullable);
@property (nonatomic, copy) ChatInputTextViewImplTargetForAction * _Nullable (^ _Nullable targetForAction)(SEL _Nullable);
@property (nonatomic, copy) bool (^ _Nullable shouldReturn)();
@property (nonatomic, copy) void (^ _Nullable backspaceWhileEmpty)();
@property (nonatomic, copy) void (^ _Nullable dropAutocorrectioniOS16)();

- (instancetype _Nonnull)initWithFrame:(CGRect)frame textContainer:(NSTextContainer * _Nullable)textContainer disableTiling:(bool)disableTiling;

@end

#endif /* Lottie_h */
