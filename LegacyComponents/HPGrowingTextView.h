

//
//  HPTextView.h
//
//  Created by Hans Pinckaers on 29-06-10.
//
//	MIT License
//
//	Copyright (c) 2011 Hans Pinckaers
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights
//	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//	copies of the Software, and to permit persons to whom the Software is
//	furnished to do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in
//	all copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//	THE SOFTWARE.

#import <UIKit/UIKit.h>

@class HPGrowingTextView;
@class HPTextViewInternal;

extern NSString *TGMentionUidAttributeName;
extern NSString *TGMentionBoldAttributeName;
@class TGMessageEntity;

@class TGKeyCommandController;

@protocol HPGrowingTextViewDelegate <NSObject>

@optional

- (BOOL)growingTextViewShouldBeginEditing:(HPGrowingTextView *)growingTextView;
- (void)growingTextViewDidBeginEditing:(HPGrowingTextView *)growingTextView;
- (void)growingTextViewDidEndEditing:(HPGrowingTextView *)growingTextView;
- (BOOL)growingTextViewEnabled:(HPGrowingTextView *)growingTextView;

- (BOOL)growingTextView:(HPGrowingTextView *)growingTextView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text;
- (void)growingTextViewDidChange:(HPGrowingTextView *)growingTextView afterSetText:(bool)afterSetText afterPastingText:(bool)afterPastingText;

- (void)growingTextView:(HPGrowingTextView *)growingTextView willChangeHeight:(CGFloat)height duration:(NSTimeInterval)duration animationCurve:(int)animationCurve;

- (void)growingTextViewDidChangeSelection:(HPGrowingTextView *)growingTextView;
- (BOOL)growingTextViewShouldReturn:(HPGrowingTextView *)growingTextView;

- (void)growingTextView:(HPGrowingTextView *)growingTextView didPasteImages:(NSArray *)images andText:(NSString *)text;
- (void)growingTextView:(HPGrowingTextView *)growingTextView didPasteData:(NSData *)data;

- (void)growingTextView:(HPGrowingTextView *)growingTextView receivedReturnKeyCommandWithModifierFlags:(UIKeyModifierFlags)flags;

@end

@interface TGAttributedTextRange : NSObject

@property (nonatomic, strong, readonly) id attachment;

- (instancetype)initWithAttachment:(id)attachment;

@end

@interface HPGrowingTextView : UIView <UITextViewDelegate>

@property (nonatomic, strong) UIView *placeholderView;
@property (nonatomic, assign) bool showPlaceholderWhenFocussed;

@property (nonatomic) int minNumberOfLines;
@property (nonatomic) int maxNumberOfLines;
@property (nonatomic) CGFloat maxHeight;
@property (nonatomic) CGFloat minHeight;
@property (nonatomic) BOOL animateHeightChange;
@property (nonatomic) NSTimeInterval animationDuration;
@property (nonatomic, strong) HPTextViewInternal *internalTextView;
@property (nonatomic, assign) bool disableFormatting;

@property (nonatomic) bool oneTimeLongAnimation;

@property (nonatomic, weak) id<HPGrowingTextViewDelegate> delegate;
@property (nonatomic, strong) NSString *text;
@property (nonatomic, strong) NSAttributedString *attributedText;
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic, strong) UIColor *accentColor;
@property (nonatomic) NSTextAlignment textAlignment;

@property (nonatomic, readonly) bool ignoreChangeNotification;

@property (nonatomic, assign) bool receiveKeyCommands;

- (instancetype)initWithKeyCommandController:(TGKeyCommandController *)keyCommandController;

- (void)refreshHeight:(bool)textChanged;
- (void)notifyHeight;

- (void)setText:(NSString *)newText animated:(bool)animated;
- (void)setAttributedText:(NSAttributedString *)newText animated:(bool)animated;
- (void)setAttributedText:(NSAttributedString *)newText keepFormatting:(bool)keepFormatting animated:(bool)animated;
- (void)selectRange:(NSRange)range force:(bool)force;

- (NSString *)textWithEntities:(__autoreleasing NSArray<TGMessageEntity *> **)entities;

+ (void)replaceMention:(NSString *)mention inputField:(HPGrowingTextView *)inputField username:(bool)username userId:(int32_t)userId;
+ (void)replaceHashtag:(NSString *)hashtag inputField:(HPGrowingTextView *)inputField;

@end
